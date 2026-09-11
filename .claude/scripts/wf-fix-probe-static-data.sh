#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-data.sh — Static probe: Data Integrity Audit (QD6)
#
# Phat hien data integrity issues trong:
#  - EF Core Configurations: thieu HasOne/WithMany (FK relationship), thieu IsRequired() cho non-null fields
#  - Domain Entities: thieu validation guard (Result.Failure / Guard / throw ArgumentException) trong factory methods
#  - Migrations: phat hien column type thay doi co the gay data loss
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed
#
# USAGE:
#   bash wf-fix-probe-static-data.sh \
#     --session-dir <path> [--profile standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: CRM fix-bugs session 2026-05-04


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-data"
PROBE_ID="P-QD6-constraint-violation"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD6", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

EXCLUDE='(__tests__|test/|tests/|spec/|\.test\.|\.spec\.|fixtures/|mocks?/|node_modules|\.git/|bin/|obj/|Migrations/)'

EMIT() {
  local title="$1" desc="$2" severity="$3" file="$4" line="$5" suggested_action="$6"
  local fp
  fp=$(echo -n "QD6|$file|$line|$PROBE_ID|$title" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg t "$title" --arg d "$desc" --arg s "$severity" \
    --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
    --arg sa "$suggested_action" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD6",
      probe_id: $pid,
      probe_version: $pver,
      severity: $s,
      fixability: "agent_fix",
      domain: "backend",
      title: $t,
      description: $d,
      location: { file: $f, line: $l, column: null, selector: null, url: null },
      evidence: [{ type: "code", path: $f, description: ("Line " + ($l|tostring)) }],
      cdg_flags: [],
      fingerprint: $fp,
      remediation: { suggested_action: $sa, suggested_agent: "dba", estimated_effort: "moderate" },
      detected_at: $now,
      detected_by: ($lane + "/" + $pid)
    }'
}

SIGNALS_JSON='[]'

# ── Probe dispatch (IMP-025) ──────────────────────────────────────────
RUN_ENTITY_GUARD=0  # entity factory validation (P-QD6-constraint-violation)
RUN_FK_CONFIG=0     # EF Core FK relationships (P-QD6-constraint-violation)
RUN_ALTER_COL=0     # AlterColumn data loss (P-QD6-migration-integrity)

case "$PROBE_ID" in
  P-QD6-constraint-violation)
    RUN_ENTITY_GUARD=1; RUN_FK_CONFIG=1 ;;
  P-QD6-migration-integrity)
    RUN_ALTER_COL=1 ;;
  P-QD6-schema-drift-detect)
    # Handled by wf-fix-probe-static-schema-drift.sh (IMP-019)
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD6", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "delegated_to_wf-fix-probe-static-schema-drift.sh"}'
    exit 0 ;;
  P-QD6-orm-model-sync)
    # Handled by wf-fix-probe-static-orm.sh (IMP-010)
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD6", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "delegated_to_wf-fix-probe-static-orm.sh"}'
    exit 0 ;;
  P-QD6-data-type-mismatch|P-QD6-seed-data-audit)
    # Static-only partial coverage — emit skip signal
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD6", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "requires_agent_runner_for_full_coverage"}'
    exit 0 ;;
  *)
    echo "ERROR: unknown PROBE_ID '$PROBE_ID' for QD6 — valid: P-QD6-constraint-violation, P-QD6-migration-integrity, P-QD6-schema-drift-detect, P-QD6-orm-model-sync, P-QD6-data-type-mismatch, P-QD6-seed-data-audit" >&2
    exit 1 ;;
esac

# ============================================================
# CHECK 1: Domain Entity factory methods (Create) thieu Result.Failure validation
# ============================================================
if [ "$RUN_ENTITY_GUARD" -eq 1 ]; then
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
  # Co Create method?
  if ! grep -qE "public static (Result<|[A-Z][a-zA-Z]+ )Create\(" "$file" 2>/dev/null; then continue; fi
  # Khong co Result.Failure / Guard / throw ArgumentException → likely no validation
  if ! grep -qE "Result\.Failure|Guard\.|throw new ArgumentException|throw new ArgumentNullException" "$file" 2>/dev/null; then
    line=$(grep -nE "public static .*Create\(" "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$line" ] && line=1
    s=$(EMIT "Entity Create thieu validation guard" \
      "Domain entity ($(basename "$file" .cs)) co factory method Create() nhung khong co validation guard (Result.Failure / Guard / throw). Risk: invalid state co the persist xuong DB." \
      "medium" "$file" "$line" \
      "Them Result.Failure<T>(new Error(code, msg)) cho moi invariant: null check, range check, format check. Tra ve Result<Entity> de caller handle.")
    SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
  fi
done < <(find "$SOURCE_DIR" -path "*/Domain/Entities/*.cs" -type f 2>/dev/null)
fi # RUN_ENTITY_GUARD

# ============================================================
# CHECK 2: EF Configurations thieu HasOne/WithMany (FK relationships)
# ============================================================
if [ "$RUN_FK_CONFIG" -eq 1 ] && { [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; }; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    # Co property kieu Guid co name ket thuc bang Id (likely FK)
    if grep -qE "Property\(.*Id\b" "$file" 2>/dev/null; then
      # Khong co HasOne / HasMany config?
      if ! grep -qE "HasOne|HasMany|WithOne|WithMany" "$file" 2>/dev/null; then
        line=$(grep -nE "Property\(.*Id\b" "$file" 2>/dev/null | head -1 | cut -d: -f1)
        [ -z "$line" ] && line=1
        s=$(EMIT "EF Configuration thieu FK relationship" \
          "Configuration ($(basename "$file" .cs)) co property *Id (likely FK) nhung KHONG khai bao HasOne/HasMany. EF Core khong tao FK constraint → orphan rows risk." \
          "medium" "$file" "$line" \
          "Them builder.HasOne(x => x.NavProperty).WithMany(y => y.Children).HasForeignKey(x => x.NavPropertyId).OnDelete(DeleteBehavior.Restrict).")
        SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
      fi
    fi
  done < <(find "$SOURCE_DIR" -path "*/Configurations/*.cs" -type f 2>/dev/null)
fi

# ============================================================
# CHECK 3: Migrations co AlterColumn voi data loss potential
# ============================================================
if [ "$RUN_ALTER_COL" -eq 1 ]; then
  # IMP-024 Phase 1 (P0 CRITICAL): DROP TABLE / TRUNCATE → CDG-DELETE-DATA
  # These SQL patterns cause irreversible data loss → CDG gate required before auto-fix.
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    fp=$(echo -n "QD6|$file|$line|$PROBE_ID|drop_table_data_loss" | _sha256 | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
      --arg match "$match" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD6",
        probe_id: $pid,
        probe_version: $pver,
        severity: "critical",
        fixability: "agent_fix",
        domain: "database",
        title: "Migration contains DATA LOSS operation (DROP/TRUNCATE)",
        description: ("Migration tai " + $f + ":" + ($l|tostring) + " co cau lenh DROP TABLE / TRUNCATE TABLE — gay mat du lieu vinh vien. BAT BUOC: backup + rollback plan truoc khi apply. CDG approval required."),
        location: { file: $f, line: $l, column: null, selector: null, url: null },
        evidence: [{ type: "code", path: $f, description: ("SQL: " + $match) }],
        cdg_flags: ["CDG-DELETE-DATA"],
        fingerprint: $fp,
        remediation: {
          suggested_action: "Tao rollback migration. Backup table truoc khi DROP. CDG-DELETE-DATA approval required.",
          suggested_agent: "dba",
          estimated_effort: "high"
        },
        detected_at: $now,
        detected_by: ($lane + "/" + $pid)
      }')
    SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$sig" '. + [$sig]')
  done < <(grep -rEin "DROP[[:space:]]+TABLE|TRUNCATE[[:space:]]+TABLE" "$SOURCE_DIR" 2>/dev/null | head -20)

  # AlterColumn data loss (profile=exhaustive only — less severe)
  if [ "$PROFILE" = "exhaustive" ]; then
    while IFS=: read -r file line match; do
      [ -z "$file" ] && continue
      s=$(EMIT "Migration AlterColumn co the gay data loss" \
        "AlterColumn voi type=string maxLength shorter, hoac type change → data truncation/loss khi apply. Yeu cau backup + migration plan." \
        "high" "$file" "$line" \
        "Review AlterColumn doi truoc khi deploy: backup table truoc + viet rollback migration. Neu shrink string, validate max length cua existing data truoc.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    done < <(grep -rEn "AlterColumn.*maxLength: [0-9]+" "$SOURCE_DIR" --include="*.cs" 2>/dev/null | head -10)
  fi
fi

# Emit final
# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile sigs "$__SIGNALS_TMPFILE" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD6", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now,
    signals: $sigs[0]}'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
