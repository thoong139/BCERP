#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-orm.sh — ORM Model Integrity Probe (QD6)
#
# Phat hien ORM-specific data integrity issues:
#   - Missing HasIndex on FK columns (EF Core)
#   - Missing @@index on relation fields (Prisma)
#   - Missing @Index on @ManyToOne/@OneToOne (TypeORM, Hibernate)
#   - Missing index=True on ForeignKey columns (SQLAlchemy)
#   - Missing index: true on FK attributes (Sequelize)
#
# Tự động detect ORM qua adapter framework (IMP-000).
#
# OUTPUT: JSON trên stdout theo schema lane-signals-v1
# Cache policy: allowed
#
# USAGE:
#   bash wf-fix-probe-static-orm.sh \
#     --session-dir <path> [--profile standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: IMP-010 Stage 3 Sprint 4


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-data"
PROBE_ID="P-QD6-orm-model-sync"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="."

# Adapter root relative to this script
ADAPTER_ROOT="$(cd "$SCRIPT_DIR/../skills/workflow/_shared/adapters" && pwd 2>/dev/null)" \
  || ADAPTER_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/skills/workflow/_shared/adapters"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
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

SIGNALS_JSON='[]'

# ============================================================
# Detect applicable ORM adapters và run scan()
# ============================================================
ORM_ADAPTERS=(ef-core prisma typeorm sqlalchemy hibernate sequelize)

for orm_name in "${ORM_ADAPTERS[@]}"; do
  adapter_file="$ADAPTER_ROOT/orm/${orm_name}.sh"
  [ -f "$adapter_file" ] || continue

  # Detect: run trong subshell để isolate
  if (source "$adapter_file" && detect "$SOURCE_DIR") >/dev/null 2>&1; then
    echo "[orm-probe] Detected ORM: $orm_name" >&2

    # scan(): capture JSON lines output
    while IFS= read -r finding_line; do
      [ -z "$finding_line" ] && continue
      # Validate JSON
      if ! echo "$finding_line" | jq '.' >/dev/null 2>&1; then continue; fi

      # Transform finding → full signal-v2
      file=$(echo "$finding_line" | jq -r '.file // "unknown"')
      line=$(echo "$finding_line" | jq -r '.line // 1')
      title=$(echo "$finding_line" | jq -r '.title // "ORM issue"')
      desc=$(echo "$finding_line" | jq -r '.description // ""')
      sev=$(echo "$finding_line" | jq -r '.severity // "medium"')
      fp=$(echo "$finding_line" | jq -r '.fingerprint // ""')
      issue_class=$(echo "$finding_line" | jq -r '.issue_class // "orm_issue"')
      remediation=$(echo "$finding_line" | jq -r '.remediation // ""')
      agent=$(echo "$finding_line" | jq -r '.suggested_agent // "dba"')

      # Generate fingerprint if missing
      if [ -z "$fp" ]; then
        fp=$(printf '%s' "QD6|${file}|${line}|${PROBE_ID}|${issue_class}" | _sha256 | awk '{print "sha256:"$1}')
      fi

      signal=$(jq -nc \
        --arg t "$title" --arg d "$desc" --arg s "$sev" \
        --arg f "$file" --argjson l "$line" --arg fp "$fp" \
        --arg pid "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg lane "$LANE" --arg now "$(iso_now)" \
        --arg sa "$remediation" --arg agent "$agent" \
        --arg orm "$orm_name" \
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
          evidence: [{ type: "code", path: $f, description: ("ORM: " + $orm + " — line " + ($l|tostring)) }],
          cdg_flags: [],
          fingerprint: $fp,
          tags: ["orm", $orm],
          remediation: { suggested_action: $sa, suggested_agent: $agent, estimated_effort: "low" },
          detected_at: $now,
          detected_by: ($lane + "/" + $pid)
        }')

      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$signal" '. + [$sig]')
    done < <((source "$adapter_file" && scan "$SOURCE_DIR") 2>/dev/null)
  fi
done

# ============================================================
# Emit final envelope
# ============================================================
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
