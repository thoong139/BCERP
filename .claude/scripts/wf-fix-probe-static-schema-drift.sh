#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-schema-drift.sh — QD6 Schema Drift Detection Probe (IMP-019)
#
# Detects schema drift via Atlas diff, EF Core migrations, or static migration file analysis.
# Three execution paths (priority order):
#   A. Atlas diff     : atlas schema diff (requires --atlas-url + DB connection)
#   B. EF Core        : dotnet ef migrations list (requires EF Core project)
#   C. Static analysis: Scan migration SQL files for dangerous pending operations
#   D. Graceful degrad: probe_status=schema_drift_unavailable (no migrations found)
#
# Dangerous operations flagged as HIGH:
#   DROP TABLE, DROP COLUMN, RENAME TABLE/COLUMN, TRUNCATE TABLE
#
# OUTPUT: lane-signals-v1 JSON to stdout.
# USAGE:
#   bash wf-fix-probe-static-schema-drift.sh \
#     [--migrations-dir <path>]           (default: migrations/)
#     [--applied-state <path/state.json>] (list of applied migration names)
#     [--atlas-url <db-url>]              (opt-in Atlas diff mode)
#     [--ef-project <path>]               (opt-in EF Core mode)
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"

PROBE_ID="P-QD6-schema-drift-detect"
DIMENSION="QD6"
MIGRATIONS_DIR="migrations"
APPLIED_STATE_FILE=""
ATLAS_URL=""
EF_PROJECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir)     SESSION_DIR="$2";     shift 2 ;;
    --lane)            LANE="$2";            shift 2 ;;
    --probe)           PROBE_ID="$2";        shift 2 ;;
    --profile)         PROFILE="$2";         shift 2 ;;
    --source-dir)      SOURCE_DIR="$2";      shift 2 ;;
    --migrations-dir)  MIGRATIONS_DIR="$2";  shift 2 ;;
    --applied-state)   APPLIED_STATE_FILE="$2"; shift 2 ;;
    --atlas-url)       ATLAS_URL="$2";       shift 2 ;;
    --ef-project)      EF_PROJECT="$2";      shift 2 ;;
    *) shift ;;
  esac
done

_sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }
_fp() { printf '%s' "$1" | _sha256_fn | awk '{print "sha256:"$1}'; }

SIGNALS=()
DRIFT_BACKEND=""

# Auto-detect applied state file
if [[ -z "$APPLIED_STATE_FILE" ]]; then
  for candidate in \
    "${MIGRATIONS_DIR}/.applied-migrations.json" \
    ".migration-state.json" \
    "${MIGRATIONS_DIR}/migration-state.json"; do
    if [[ -f "$candidate" ]]; then
      APPLIED_STATE_FILE="$candidate"
      break
    fi
  done
fi

# ============================================================
# PATH A: Atlas diff (opt-in, requires --atlas-url)
# ============================================================
if [[ -n "$ATLAS_URL" ]] && command -v atlas >/dev/null 2>&1; then
  DRIFT_BACKEND="atlas"
  TMP_OUT=$(mktemp 2>/dev/null || echo "/tmp/atlas-drift-$$")
  atlas schema diff --url "$ATLAS_URL" --format '{{ sql "  " }}' > "$TMP_OUT" 2>&1 || true

  if [[ -s "$TMP_OUT" ]]; then
    while IFS= read -r stmt; do
      [[ -z "$stmt" ]] && continue
      sev="medium"
      echo "$stmt" | grep -qiE '^(DROP TABLE|TRUNCATE TABLE)' && sev="high"
      echo "$stmt" | grep -qiE '^(DROP COLUMN|RENAME (TABLE|COLUMN))' && sev="high"

      fp=$(_fp "QD6|${PROBE_ID}|atlas|${stmt:0:80}")
      SIGNALS+=("$(jq -nc \
        --arg stmt "$stmt" --arg sev "$sev" \
        --arg fp "$fp" --arg dim "$DIMENSION" --arg probe "$PROBE_ID" \
        '{
          title:       ("schema-drift: " + ($stmt | split("\n")[0] | .[0:60])),
          description: ("Atlas diff detected schema change: " + $stmt),
          severity:    $sev,
          location:    {file: "db-schema", line: null},
          evidence:    [{type: "sql", path: "atlas-diff", description: $stmt}],
          fingerprint: $fp,
          dimension:   $dim, probe_id: $probe,
          issue_class: "schema_drift",
          drift_backend: "atlas",
          tags:        ["schema","drift","database"]
        }')")
    done < "$TMP_OUT"
  fi
  rm -f "$TMP_OUT"

# ============================================================
# PATH B: EF Core migrations list (opt-in, requires --ef-project)
# ============================================================
elif [[ -n "$EF_PROJECT" ]] && command -v dotnet >/dev/null 2>&1; then
  DRIFT_BACKEND="ef-core"
  EF_OUT=$(dotnet ef migrations list --project "$EF_PROJECT" --no-build 2>/dev/null || true)
  PENDING_COUNT=0

  while IFS= read -r line; do
    if echo "$line" | grep -qi '(Pending)'; then
      PENDING_COUNT=$((PENDING_COUNT + 1))
      mig_name=$(echo "$line" | sed 's/(Pending).*//' | tr -d ' ')
      fp=$(_fp "QD6|${PROBE_ID}|ef-core|${mig_name}")
      SIGNALS+=("$(jq -nc \
        --arg name "$mig_name" --arg fp "$fp" \
        --arg dim "$DIMENSION" --arg probe "$PROBE_ID" \
        '{
          title:       ("schema-drift: pending migration " + $name),
          description: ("EF Core migration not yet applied: " + $name),
          severity:    "medium",
          location:    {file: "ef-migrations", line: null},
          evidence:    [{type: "migration", path: "ef-core", description: $name}],
          fingerprint: $fp,
          dimension:   $dim, probe_id: $probe,
          issue_class: "pending_migration",
          drift_backend: "ef-core",
          tags:        ["schema","migration","ef-core"]
        }')")
    fi
  done <<< "$EF_OUT"

# ============================================================
# PATH C: Static migration file analysis
# ============================================================
else
  DRIFT_BACKEND="static-analysis"

  # Collect all migration SQL files
  declare -a ALL_MIGRATIONS=()
  while IFS= read -r f; do
    ALL_MIGRATIONS+=("$f")
  done < <(find "$MIGRATIONS_DIR" -name "*.sql" -type f 2>/dev/null | sort || true)

  if [[ "${#ALL_MIGRATIONS[@]}" -eq 0 ]]; then
    # No migration files found → graceful degradation
    jq -nc \
      --arg schema "lane-signals-v1" \
      --arg probe  "$PROBE_ID" \
      --arg dim    "$DIMENSION" \
      --arg status "schema_drift_unavailable" \
      '{
        "$schema":    $schema,
        probe_id:     $probe,
        dimension:    $dim,
        probe_status: $status,
        signal_count: 0,
        signals:      [],
        note: "No migration files found. Provide --migrations-dir or --atlas-url for DB-connected diff."
      }'
    exit 0
  fi

  # Load applied migrations list (strip CRLF)
  declare -a APPLIED_LIST
  if [[ -n "$APPLIED_STATE_FILE" && -f "$APPLIED_STATE_FILE" ]]; then
    while IFS= read -r name; do
      name="${name%$'\r'}"  # strip Windows CRLF
      [[ -n "$name" ]] && APPLIED_LIST+=("$name")
    done < <(jq -r '.applied[]?' "$APPLIED_STATE_FILE" 2>/dev/null || true)
  fi

  _is_applied() {
    local fname
    fname=$(basename "$1")
    # If no state file: no APPLIED_LIST → can't determine → skip (emit no signals)
    if [[ "${#APPLIED_LIST[@]}" -eq 0 ]]; then
      return 1  # treat all as pending when no state file
    fi
    for applied in "${APPLIED_LIST[@]}"; do
      applied="${applied%$'\r'}"  # extra CRLF guard
      [[ "$applied" == "$fname" || "$applied" == "${fname%.sql}" ]] && return 0
    done
    return 1  # not in applied list → pending
  }

  # Dangerous SQL patterns
  DANGER_PATTERNS=(
    'DROP[[:space:]]+TABLE'
    'TRUNCATE[[:space:]]+TABLE'
    'DROP[[:space:]]+COLUMN'
    'RENAME[[:space:]]+TABLE'
    'RENAME[[:space:]]+COLUMN'
    'ALTER[[:space:]]+TABLE[^;]*DROP[[:space:]]+CONSTRAINT'
  )

  DANGER_LABELS=(
    "DROP TABLE — destroys all table data"
    "TRUNCATE TABLE — removes all rows"
    "DROP COLUMN — loses column data permanently"
    "RENAME TABLE — breaks existing queries"
    "RENAME COLUMN — breaks existing queries"
    "DROP CONSTRAINT — removes data integrity rule"
  )

  for mig_file in "${ALL_MIGRATIONS[@]}"; do
    fname=$(basename "$mig_file")

    # Check if this migration is pending (not applied)
    if _is_applied "$mig_file"; then
      continue  # skip applied migrations
    fi

    # Scan for dangerous operations
    for i in "${!DANGER_PATTERNS[@]}"; do
      pat="${DANGER_PATTERNS[$i]}"
      label="${DANGER_LABELS[$i]}"

      while IFS=: read -r _file linenum content; do
        [[ -z "$linenum" ]] && continue
        content=$(echo "$content" | sed 's/^[[:space:]]*//' | head -c 200)
        fp=$(_fp "QD6|${PROBE_ID}|${fname}|${linenum}|${pat}")
        SIGNALS+=("$(jq -nc \
          --arg fname   "$fname" \
          --arg file    "$mig_file" \
          --arg line    "$linenum" \
          --arg label   "$label" \
          --arg content "$content" \
          --arg fp      "$fp" \
          --arg dim     "$DIMENSION" \
          --arg probe   "$PROBE_ID" \
          '{
            title:       ("schema-drift: " + $label + " in " + $fname),
            description: ("Pending migration " + $fname + " contains: " + $label + ". Review before applying."),
            severity:    "high",
            location:    {file: $file, line: ($line | tonumber? // null)},
            evidence:    [{type: "sql", path: $file,
                           description: ("Line " + $line + ": " + $content)}],
            fingerprint: $fp,
            dimension:   $dim, probe_id: $probe,
            issue_class: "dangerous_migration",
            drift_backend: "static-analysis",
            tags:        ["schema","drift","migration","destructive"]
          }')")
      done < <(grep -niE "$pat" "$mig_file" 2>/dev/null || true)
    done

    # Signal for any pending migration (informational)
    fp=$(_fp "QD6|${PROBE_ID}|pending|${fname}")
    SIGNALS+=("$(jq -nc \
      --arg fname "$fname" \
      --arg file  "$mig_file" \
      --arg fp    "$fp" \
      --arg dim   "$DIMENSION" \
      --arg probe "$PROBE_ID" \
      '{
        title:       ("schema-drift: unapplied migration " + $fname),
        description: ("Migration file " + $fname + " has not been applied to the database."),
        severity:    "medium",
        location:    {file: $file, line: null},
        evidence:    [{type: "migration", path: $file, description: ("Pending: " + $fname)}],
        fingerprint: $fp,
        dimension:   $dim, probe_id: $probe,
        issue_class: "pending_migration",
        drift_backend: "static-analysis",
        tags:        ["schema","migration","pending"]
      }')")
  done
fi

# ============================================================
# Emit lane-signals-v1 envelope
# ============================================================
SIGNAL_COUNT="${#SIGNALS[@]}"
SIGNALS_JSON="[]"
if [[ "$SIGNAL_COUNT" -gt 0 ]]; then
  SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" | jq -s '.')
fi

# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg schema  "lane-signals-v1" \
  --arg probe   "$PROBE_ID" \
  --arg dim     "$DIMENSION" \
  --arg backend "$DRIFT_BACKEND" \
  --arg mdir    "$MIGRATIONS_DIR" \
  --slurpfile signals "$__SIGNALS_TMPFILE" \
  '{
    "$schema":      $schema,
    probe_id:       $probe,
    dimension:      $dim,
    drift_backend:  $backend,
    migrations_dir: $mdir,
    signal_count:   ($signals[0] | length),
    signals:        $signals[0]
  }'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
