#!/usr/bin/env bash
# =============================================================================
# build-id-mapping.sh — Bridge 3 ID schemes trong wf-fix-bugs session (Wave 3 G4)
# =============================================================================
# Mục đích:
#   Sinh $SESSION_DIR/_meta/id-mapping.json (schema id-mapping-v1) bridge giữa:
#     - registry_id (issue-registry.json): QDx-XX-NNN hoặc SIG-QDx-NNN
#     - plan_id (fix-plan.md): ISS-YYYYMMDD-NNN
#     - report_id (fix-report.md): ISS-NNN hoặc ISS-YYYYMMDD-NNN
#
#   Bridge này cho phép cross-skill consumers (vd: wf-verify-sync, wf-cmi)
#   reference issue qua canonical_id ổn định (= registry_id) thay vì
#   plan_id/report_id thay đổi theo iteration/run.
#
# Logic match:
#   1. registry ↔ plan: by file path (location.file == fix-plan File(s) col).
#      Multi-issue per file → assign theo sequential index theo severity priority.
#   2. registry ↔ report: by title fuzzy (token overlap ≥40% lower-case words).
#   3. Unmapped registry issues → mark unmapped=true, plan_id/report_id=null.
#
# Required env vars:
#   SESSION_DIR (canonical: .mc-data/work/wf-fix-bugs/sessions/{SESSION_ID})
#   SESSION_ID
#
# Optional env vars:
#   MCV3_FIX_ID_MAPPING_DEBUG=1   → verbose stderr (skip in CI)
#
# Outputs:
#   $SESSION_DIR/_meta/id-mapping.json (atomic write)
#   stdout: summary JSON {total_registry, matched_to_plan, matched_to_report, unmapped_count}
#
# Exit codes:
#   0 — Mapping generated (kể cả khi unmapped > 0)
#   1 — Missing env vars / source files
#   2 — Atomic write fail
#   3 — Template missing
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

DEBUG="${MCV3_FIX_ID_MAPPING_DEBUG:-0}"

dbg() {
  [ "$DEBUG" = "1" ] && echo "[id-mapping] $*" >&2 || true
}

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: env var \$$var is empty" >&2
    exit 1
  fi
done

REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
FIX_PLAN="$SESSION_DIR/phase5-triage/fix-plan.md"
FIX_REPORT="$SESSION_DIR/phase6-execute/fix-report.md"

OUT_DIR="$SESSION_DIR/_meta"
OUT_FILE="$OUT_DIR/id-mapping.json"
TEMPLATE=".claude/skills/workflow/wf-fix-bugs/templates/_meta/id-mapping.json"

if [ ! -s "$REGISTRY" ]; then
  echo "ERROR: registry not found or empty: $REGISTRY" >&2
  exit 1
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template missing: $TEMPLATE" >&2
  exit 3
fi

mkdir -p "$OUT_DIR"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─── Pass 1: Parse fix-plan rows ─────────────────────────────────────────────
# Format: | Priority | Issue ID | Action | File(s) | Est. Time | [CDG] Markers |
# Build TSV: plan_id<TAB>priority_lc<TAB>action<TAB>file
PLAN_TSV=""
if [ -s "$FIX_PLAN" ]; then
  PLAN_TSV=$(awk -F'|' '
    /^\| (CRITICAL|HIGH|MEDIUM|LOW) \| ISS-/ {
      pr=$2; gsub(/^[ \t]+|[ \t]+$/,"",pr)
      pid=$3; gsub(/^[ \t]+|[ \t]+$/,"",pid)
      act=$4; gsub(/^[ \t]+|[ \t]+$/,"",act)
      f=$5; gsub(/^[ \t]+|[ \t]+$/,"",f)
      printf "%s\t%s\t%s\t%s\n", pid, tolower(pr), act, f
    }' "$FIX_PLAN" 2>/dev/null || true)
fi
PLAN_ROWS=$(echo "$PLAN_TSV" | grep -c '^ISS-' 2>/dev/null || true)
PLAN_ROWS=${PLAN_ROWS:-0}
dbg "Parsed $PLAN_ROWS fix-plan rows"

# ─── Pass 2: Parse fix-report rows ───────────────────────────────────────────
# Heuristic: rows where col 1 starts with ISS-NNN or ISS-YYYYMMDD-NNN
# Format varies — we extract: report_id<TAB>title (col2 if present)
REPORT_TSV=""
if [ -s "$FIX_REPORT" ]; then
  REPORT_TSV=$(awk -F'|' '
    /^\| ISS-[0-9]/ {
      rid=$2; gsub(/^[ \t]+|[ \t]+$/,"",rid)
      tt=$3; gsub(/^[ \t]+|[ \t]+$/,"",tt)
      if (tt == "") tt = "(no-title)"
      printf "%s\t%s\n", rid, tolower(tt)
    }' "$FIX_REPORT" 2>/dev/null || true)
fi
REPORT_ROWS=$(echo "$REPORT_TSV" | grep -c '^ISS-' 2>/dev/null || true)
REPORT_ROWS=${REPORT_ROWS:-0}
dbg "Parsed $REPORT_ROWS fix-report rows"

# ─── Pass 3: Iterate registry, build mappings ────────────────────────────────
TOTAL_REGISTRY=$(jq '.issues | length' "$REGISTRY" 2>/dev/null || echo 0)
TOTAL_REGISTRY=${TOTAL_REGISTRY:-0}
dbg "Registry has $TOTAL_REGISTRY issues"

MATCHED_PLAN=0
MATCHED_REPORT=0
UNMAPPED=0

# Build temp file with mappings
MAPPINGS_TMP="$OUT_DIR/.mappings.tmp.$$"
: > "$MAPPINGS_TMP"

# Track assigned plan rows (file path → list of plan_id consumed)
# We use a simple per-file consumption counter to handle multi-issue-per-file.
PLAN_CONSUMED_FILE="$OUT_DIR/.plan-consumed.tmp.$$"
: > "$PLAN_CONSUMED_FILE"

# Loop over registry issues
ITER_NO=0
JQ_REGISTRY=$(jq -c '.issues[] | {
  id: .id,
  title: (.title // ""),
  severity: (.severity // "medium"),
  dimension_id: (.dimension_id // ""),
  file: (.location.file // null)
}' "$REGISTRY" 2>/dev/null || echo "")

if [ -z "$JQ_REGISTRY" ]; then
  echo "ERROR: registry parse fail or empty .issues[]" >&2
  exit 1
fi

while IFS= read -r issue_json; do
  [ -z "$issue_json" ] && continue
  ITER_NO=$((ITER_NO + 1))
  [ $((ITER_NO % 20)) -eq 0 ] && dbg "Iter $ITER_NO / $TOTAL_REGISTRY"
  reg_id=$(echo "$issue_json" | jq -r '.id // ""' 2>/dev/null)
  title=$(echo "$issue_json" | jq -r '.title // ""' 2>/dev/null)
  severity=$(echo "$issue_json" | jq -r '.severity // "medium"' 2>/dev/null)
  dim=$(echo "$issue_json" | jq -r '.dimension_id // ""' 2>/dev/null)
  file=$(echo "$issue_json" | jq -r '.file // ""' 2>/dev/null)

  [ -z "$reg_id" ] && continue

  # ── Match plan_id by file path + severity priority ────────────────────────
  plan_id="null"
  match_method="unmapped"

  if [ -n "$file" ] && [ "$file" != "null" ] && [ -n "$PLAN_TSV" ]; then
    # Find plan rows matching file, prefer matching priority/severity
    # Skip already-consumed plan IDs for same file
    consumed_ids=$(grep -F "FILE=$file|" "$PLAN_CONSUMED_FILE" 2>/dev/null | awk -F'PID=' '{print $2}' || true)

    candidate=$(echo "$PLAN_TSV" | awk -F'\t' -v f="$file" -v sev="$severity" -v consumed="$consumed_ids" '
      BEGIN { gsub(/\n/, " ", consumed); n=split(consumed, ca, " "); for (i=1;i<=n;i++) if(ca[i]!="") seen[ca[i]] = 1 }
      $4 == f && !($1 in seen) {
        # Prefer matching severity (lowercase) — exit immediately on first match
        if ($2 == sev) { print $1; found=1; exit }
        if (alt == "") alt = $1
      }
      END { if (!found && alt != "") print alt }
    ')

    if [ -n "$candidate" ] && [ "$candidate" != "" ]; then
      plan_id="$candidate"
      match_method="file_path"
      echo "FILE=$file|PID=$candidate" >> "$PLAN_CONSUMED_FILE"
      MATCHED_PLAN=$((MATCHED_PLAN + 1))
    fi
  fi

  # ── Match report_id by title fuzzy (token overlap) ────────────────────────
  report_id="null"
  if [ -n "$title" ] && [ -n "$REPORT_TSV" ]; then
    # Lowercase + extract first 6 words for matching token
    title_lc=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9 ' ' ')
    first_tokens=$(echo "$title_lc" | awk '{for (i=1; i<=6 && i<=NF; i++) printf "%s ", $i}')

    # Find first report row whose title contains ≥3 of these tokens
    best_rid=$(echo "$REPORT_TSV" | awk -F'\t' -v needles="$first_tokens" '
      BEGIN { n=split(needles, na, " "); for(i=1;i<=n;i++) if(length(na[i])>=4) tk[na[i]]=1 }
      {
        rtitle=$2
        hits=0; total=0
        for (k in tk) { total++; if (index(rtitle, k) > 0) hits++ }
        if (total > 0 && hits * 100 >= total * 40) {
          print $1; exit
        }
      }
    ')

    if [ -n "$best_rid" ]; then
      report_id="$best_rid"
      [ "$match_method" = "unmapped" ] && match_method="title_fuzzy"
      MATCHED_REPORT=$((MATCHED_REPORT + 1))
    fi
  fi

  # ── Build mapping entry ───────────────────────────────────────────────────
  unmapped_flag="false"
  if [ "$plan_id" = "null" ] && [ "$report_id" = "null" ]; then
    unmapped_flag="true"
    UNMAPPED=$((UNMAPPED + 1))
  fi

  jq -nc \
    --arg cid "$reg_id" \
    --arg rid "$reg_id" \
    --arg pid "$plan_id" \
    --arg report "$report_id" \
    --arg title "$title" \
    --arg sev "$severity" \
    --arg dim "$dim" \
    --arg file "${file:-null}" \
    --arg mm "$match_method" \
    --argjson unmapped "$unmapped_flag" \
    '{
      canonical_id: $cid,
      registry_id: $rid,
      plan_id: (if $pid == "null" then null else $pid end),
      report_id: (if $report == "null" then null else $report end),
      title: $title,
      severity: $sev,
      dimension_id: $dim,
      file: (if $file == "null" then null else $file end),
      match_method: $mm,
      unmapped: $unmapped
    }' >> "$MAPPINGS_TMP"

done <<< "$JQ_REGISTRY"

# ─── Compose final JSON from template ────────────────────────────────────────
TMP="$OUT_FILE.tmp.$$"

# v11.2.0 fix: Use --slurpfile to avoid "Argument list too long" on Windows
# when MAPPINGS_TMP exceeds ~8KB (typical for sessions with 100+ issues).
# Validate MAPPINGS_TMP is valid JSONL first.
if ! jq -s '.' "$MAPPINGS_TMP" >/dev/null 2>&1; then
  echo "ERROR: MAPPINGS_TMP contains malformed JSONL" >&2
  [ "$DEBUG" = "1" ] && head -5 "$MAPPINGS_TMP" >&2
  rm -f "$MAPPINGS_TMP" "$PLAN_CONSUMED_FILE"
  exit 2
fi

JQ_ERR=$(jq \
    --arg sid "$SESSION_ID" \
    --arg ts "$NOW" \
    --argjson total "$TOTAL_REGISTRY" \
    --argjson matched_plan "$MATCHED_PLAN" \
    --argjson matched_report "$MATCHED_REPORT" \
    --argjson unmapped "$UNMAPPED" \
    --slurpfile mappings "$MAPPINGS_TMP" \
    '.session_id = $sid
     | .generated_at = $ts
     | .summary.total_registry = $total
     | .summary.matched_to_plan = $matched_plan
     | .summary.matched_to_report = $matched_report
     | .summary.unmapped_count = $unmapped
     | .mappings = $mappings
     | del(._template_notes)
     | del(._schema_notes)' \
    "$TEMPLATE" > "$TMP" 2>&1)
JQ_RC=$?

if [ "$JQ_RC" -eq 0 ] && jq '.' "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$OUT_FILE"
else
  echo "ERROR: id-mapping.json atomic write fail (jq_rc=$JQ_RC)" >&2
  [ "$DEBUG" = "1" ] && echo "JQ_STDERR: $JQ_ERR" >&2
  rm -f "$TMP" "$MAPPINGS_TMP" "$PLAN_CONSUMED_FILE"
  exit 2
fi

# Cleanup
rm -f "$MAPPINGS_TMP" "$PLAN_CONSUMED_FILE"

# ─── Emit summary JSON to stdout ─────────────────────────────────────────────
jq -n \
  --argjson total "$TOTAL_REGISTRY" \
  --argjson mp "$MATCHED_PLAN" \
  --argjson mr "$MATCHED_REPORT" \
  --argjson un "$UNMAPPED" \
  --arg path "$OUT_FILE" \
  '{
    total_registry: $total,
    matched_to_plan: $mp,
    matched_to_report: $mr,
    unmapped_count: $un,
    output_file: $path,
    status: "ok"
  }'

exit 0
