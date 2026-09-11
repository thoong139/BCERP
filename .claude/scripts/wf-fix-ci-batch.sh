#!/usr/bin/env bash
# wf-fix-ci-batch.sh — Group issues by file, pre-warm CI cache (W3.2 v10-speedup)
#
# Muc dich: Tranh duplicate `gitnexus_impact` calls cho issues cung file trong
# 1 batch. Script gom issues theo primary file (target.file_path // location.file
# // files_modified[0]) → cho moi file lam 1 cache lookup (qua wf-fix-ci-cache.sh).
# Cache HIT → impact da co; MISS → caller (orchestrator/agent) invoke MCP +
# `wf-fix-ci-cache.sh store` cho file do.
#
# Sau khi gom xong, script ghi 1 CI_TOOL_USED log entry PER ISSUE voi:
#   - cache_source = "batch_lookup"
#   - parent_file = <primary file cua issue>
#   - issue_id = ID cua issue
# → Guard rail "1 entry/issue" duoc dam bao, va parent_file ref hop le.
#
# Input:
#   $1 SESSION_DIR — duong dan tuyet doi den session, chua issue-registry.json
#   $2 BATCH_NUM   — 1 | 2 | 3
#   $3 SEVERITY    — CRITICAL | HIGH | MEDIUM | LOW
#
# Output:
#   $SESSION_DIR/phase3-batch{N}/ci-batch-{severity}.json
#   Schema:
#     [
#       {
#         "file": "src/auth/login.ts",
#         "impact": {...}  | null,           // null khi cache MISS (caller handle)
#         "cache_status": "hit" | "miss",
#         "issue_ids": ["ISS-001", "ISS-002"]
#       }
#     ]
#
# Escape hatch:
#   MCV3_FIX_CI_BATCH_DISABLED=1 → exit 0 SOM (khong ghi ci-batch json, khong log
#     batch_lookup entries) → caller fall back hanh vi cu (per-issue CI calls).
#
# Freshness severe → batch script PHAI BYPASS cache (call cache wrapper voi
#   bypass semantics): cache_status="miss" cho moi file, log batch_lookup entries
#   van duoc emit nhung cache_hit=false. Day la guard rail bao toan: stale index
#   khong tra ket qua cache cu.
#
# Exit codes:
#   0 — Thanh cong (ci-batch json created) hoac escape hatch active (silent skip)
#   2 — Invalid arguments (missing args hoac issue-registry.json)
#   3 — Internal error (jq parse fail, atomic write fail, ...)

set -euo pipefail

# ===========================================================================
# Constants & validation
# ===========================================================================

readonly SCRIPT_NAME="wf-fix-ci-batch"
# F05.007 (Sprint 8): Dùng ${BASH_SOURCE[0]} thay $0 để sourced-safe.
# $0 = invoking shell name khi script được sourced (không phải script path).
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CI_CACHE_WRAPPER="$REPO_ROOT/scripts/wf-fix-ci-cache.sh"

usage() {
  cat <<EOF
Usage: bash $0 <SESSION_DIR> <BATCH_NUM> <SEVERITY>

Required:
  SESSION_DIR — Duong dan tuyet doi den session
  BATCH_NUM   — 1 | 2 | 3
  SEVERITY    — CRITICAL | HIGH | MEDIUM | LOW

Output:
  \$SESSION_DIR/phase3-batch{N}/ci-batch-{severity}.json

Env:
  MCV3_FIX_CI_BATCH_DISABLED=1   Escape hatch — skip batching, exit 0 silently.
  MCV3_FIX_CI_CACHE_DISABLED=1   Khi set, cache wrapper bypass cache nhung
                                 script van emit ci-batch json voi cache_status=miss.

Reads:
  \$SESSION_DIR/issue-registry.json   (filter by severity)
  \$SESSION_DIR/ci-context.json       (freshness_level — read qua wrapper)
  \$SESSION_DIR/.ci-cache/impact/     (session cache files — qua wrapper)

Writes:
  \$SESSION_DIR/phase3-batch{N}/ci-batch-{severity}.json  (atomic)
  \$SESSION_DIR/fix-log.json  (APPEND 1 CI_TOOL_USED entry/issue, atomic)
EOF
}

if [ $# -lt 3 ]; then
  echo "[$SCRIPT_NAME] ERROR: thieu arguments" >&2
  usage >&2
  exit 2
fi

SESSION_DIR="$1"
BATCH_NUM="$2"
SEVERITY="$3"

# Escape hatch — silent skip (caller fall back per-issue calls)
if [ "${MCV3_FIX_CI_BATCH_DISABLED:-0}" = "1" ]; then
  echo "[$SCRIPT_NAME] BATCH DISABLED via MCV3_FIX_CI_BATCH_DISABLED=1 — skipping" >&2
  exit 0
fi

if [ ! -d "$SESSION_DIR" ]; then
  echo "[$SCRIPT_NAME] ERROR: SESSION_DIR khong ton tai: $SESSION_DIR" >&2
  exit 2
fi

ISSUES_JSON="$SESSION_DIR/issue-registry.json"
if [ ! -s "$ISSUES_JSON" ]; then
  echo "[$SCRIPT_NAME] ERROR: issue-registry.json khong ton tai/rong: $ISSUES_JSON" >&2
  exit 2
fi

case "$BATCH_NUM" in
  1|2|3) ;;
  *)
    echo "[$SCRIPT_NAME] ERROR: BATCH_NUM phai la 1, 2 hoac 3 (nhan: $BATCH_NUM)" >&2
    exit 2
    ;;
esac

case "$SEVERITY" in
  CRITICAL|HIGH|MEDIUM|LOW) ;;
  *)
    echo "[$SCRIPT_NAME] ERROR: SEVERITY khong hop le: $SEVERITY" >&2
    exit 2
    ;;
esac

if [ ! -x "$CI_CACHE_WRAPPER" ] && [ ! -r "$CI_CACHE_WRAPPER" ]; then
  echo "[$SCRIPT_NAME] ERROR: thieu cache wrapper: $CI_CACHE_WRAPPER" >&2
  exit 3
fi

OUT_DIR="$SESSION_DIR/phase3-batch$BATCH_NUM"
OUT_FILE="$OUT_DIR/ci-batch-$SEVERITY.json"
LOG_FILE="$SESSION_DIR/fix-log.json"
mkdir -p "$OUT_DIR"

# ===========================================================================
# Helpers
# ===========================================================================

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Read freshness_level tu ci-context.json (de check severe — cache se bypass)
read_freshness_level() {
  local ctx_file="$SESSION_DIR/ci-context.json"
  if [ -s "$ctx_file" ]; then
    jq -r '.freshness_level // .freshness.level // "unknown"' "$ctx_file" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

read_freshness_behind() {
  local ctx_file="$SESSION_DIR/ci-context.json"
  if [ -s "$ctx_file" ]; then
    jq -r '.freshness_behind_commits // .freshness.behind // 0' "$ctx_file" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# ===========================================================================
# Step 1: Group issues by primary file
# ===========================================================================
# Primary file resolution (theo thu tu uu tien):
#   1. target.file_path
#   2. location.file
#   3. files_modified[0]
#   4. "unknown" (skip)
#
# Output JSON: [{file: "...", issue_ids: ["ISS-001",...]}, ...]

GROUPS_TMP=$(mktemp -t wf-fix-ci-batch.groups.XXXXXX) || {
  echo "[$SCRIPT_NAME] ERROR: mktemp fail" >&2
  exit 3
}
trap 'rm -f "$GROUPS_TMP" "${OUT_FILE}.tmp.$$" "${LOG_FILE}.tmp.$$" 2>/dev/null || true' EXIT

if ! jq --arg sev "$SEVERITY" '
  [
    .issues[]?
    | select(.severity == $sev)
    | {
        issue_id: .issue_id,
        file: (.target.file_path // .location.file // (.files_modified[0]? // "unknown"))
      }
    | select(.file != "unknown" and .file != null and .file != "")
  ]
  | group_by(.file)
  | map({
      file: .[0].file,
      issue_ids: [.[].issue_id]
    })
' "$ISSUES_JSON" > "$GROUPS_TMP" 2>/dev/null; then
  echo "[$SCRIPT_NAME] ERROR: jq grouping fail tren $ISSUES_JSON" >&2
  exit 3
fi

GROUP_COUNT=$(jq 'length' "$GROUPS_TMP" 2>/dev/null || echo 0)

# Truong hop khong co issue match severity → emit empty array + early exit
if [ "$GROUP_COUNT" -eq 0 ]; then
  TMP_OUT="${OUT_FILE}.tmp.$$"
  echo '[]' > "$TMP_OUT"
  mv "$TMP_OUT" "$OUT_FILE"
  echo "[$SCRIPT_NAME] INFO: khong co issue severity=$SEVERITY trong batch $BATCH_NUM — emit empty ci-batch.json" >&2
  exit 0
fi

# ===========================================================================
# Step 2: Per-file cache lookup → build batch entries
# ===========================================================================
# Voi MOI file:
#   - Call `wf-fix-ci-cache.sh lookup` voi target=<file>
#       (target la file path, direction=upstream — quy uoc batch_lookup)
#   - HIT (exit 0 + stdout JSON) → impact = JSON, cache_status = "hit"
#   - MISS/BYPASS (exit 1) → impact = null, cache_status = "miss"
#       (caller phai invoke MCP + `wf-fix-ci-cache.sh store` cho file do)
#
# Lay freshness de check severe — neu severe, lookup van duoc goi nhung
# wrapper se return MISS (exit 1) → cache_status="miss" cho moi file.

FRESHNESS_LEVEL=$(read_freshness_level)
FRESHNESS_BEHIND=$(read_freshness_behind)

ENTRIES_TMP=$(mktemp -t wf-fix-ci-batch.entries.XXXXXX) || {
  echo "[$SCRIPT_NAME] ERROR: mktemp fail" >&2
  exit 3
}
trap 'rm -f "$GROUPS_TMP" "$ENTRIES_TMP" "${OUT_FILE}.tmp.$$" "${LOG_FILE}.tmp.$$" 2>/dev/null || true' EXIT

echo '[]' > "$ENTRIES_TMP"

# Tinh duration_ms tong cong cho cache lookups (de log)
HIT_COUNT=0
MISS_COUNT=0

# Iterate qua groups bang jq -c (1 dong/group)
while IFS= read -r group_json; do
  FILE=$(printf '%s' "$group_json" | jq -r '.file')
  ISSUE_IDS_JSON=$(printf '%s' "$group_json" | jq -c '.issue_ids')

  # Call cache wrapper lookup (target=file path, direction=upstream)
  # NOTE: Wrapper auto-logs CI_TOOL_USED entry voi cache_source=session_tier
  # khi HIT. Day la BASE log per file — KHONG xung dot voi per-issue
  # batch_lookup entries (entries co schema khac: them parent_file + issue_id).
  CACHED_IMPACT=""
  CACHE_STATUS="miss"
  if CACHED_IMPACT=$(bash "$CI_CACHE_WRAPPER" lookup "$SESSION_DIR" "$FILE" "upstream" 2>/dev/null); then
    if [ -n "$CACHED_IMPACT" ]; then
      CACHE_STATUS="hit"
      HIT_COUNT=$((HIT_COUNT + 1))
    fi
  fi

  if [ "$CACHE_STATUS" != "hit" ]; then
    MISS_COUNT=$((MISS_COUNT + 1))
    CACHED_IMPACT="null"
  fi

  # APPEND entry vao $ENTRIES_TMP (atomic)
  # impact: HIT → JSON object/array tu cache; MISS → JSON null
  if ! jq --arg file "$FILE" \
         --argjson issue_ids "$ISSUE_IDS_JSON" \
         --argjson impact "$CACHED_IMPACT" \
         --arg status "$CACHE_STATUS" \
         '. += [{
            file: $file,
            impact: $impact,
            cache_status: $status,
            issue_ids: $issue_ids
          }]' "$ENTRIES_TMP" > "${ENTRIES_TMP}.new" 2>/dev/null; then
    echo "[$SCRIPT_NAME] WARN: jq append fail cho file=$FILE — skip" >&2
    rm -f "${ENTRIES_TMP}.new"
    continue
  fi
  mv "${ENTRIES_TMP}.new" "$ENTRIES_TMP"
done < <(jq -c '.[]' "$GROUPS_TMP")

# ===========================================================================
# Step 3: Atomic write ci-batch-{severity}.json
# ===========================================================================

TMP_OUT="${OUT_FILE}.tmp.$$"
cp "$ENTRIES_TMP" "$TMP_OUT"

# Validate JSON parse truoc khi move
if ! jq -e '.' "$TMP_OUT" > /dev/null 2>&1; then
  echo "[$SCRIPT_NAME] ERROR: ci-batch JSON khong hop le sau khi build" >&2
  rm -f "$TMP_OUT"
  exit 3
fi

mv "$TMP_OUT" "$OUT_FILE"

# ===========================================================================
# Step 4: Per-issue CI_TOOL_USED log entries (batch_lookup)
# ===========================================================================
# Guard rail: "1 entry/issue" — emit 1 CI_TOOL_USED entry per issue trong batch
# voi cache_source="batch_lookup", parent_file=<file>, issue_id=<id>.
#
# cache_hit = true khi cache_status="hit" (impact da co tu cache pre-populated)
#           = false khi cache_status="miss" (caller se invoke MCP fresh sau)
#
# Note: Wrapper da log 1 entry "session_tier" per file lookup HIT. Per-issue
# entries day la TRACKING khac (de count fixed issues + parent_file ref).
# Wrapper entries khong co `issue_id`/`parent_file` — duoc phan biet ro rang.

# Initialize fix-log.json neu chua co
if [ ! -s "$LOG_FILE" ]; then
  echo '{"entries": []}' > "$LOG_FILE"
fi

# Build entries array tu ci-batch.json (1 entry/issue)
NEW_ENTRIES_TMP=$(mktemp -t wf-fix-ci-batch.logentries.XXXXXX) || {
  echo "[$SCRIPT_NAME] WARN: mktemp fail cho log entries — skip per-issue logging" >&2
  echo "[$SCRIPT_NAME] DONE: hit=$HIT_COUNT miss=$MISS_COUNT severity=$SEVERITY batch=$BATCH_NUM" >&2
  exit 0
}
trap 'rm -f "$GROUPS_TMP" "$ENTRIES_TMP" "$NEW_ENTRIES_TMP" "${OUT_FILE}.tmp.$$" "${LOG_FILE}.tmp.$$" 2>/dev/null || true' EXIT

NOW=$(iso_now)
if ! jq --arg ts "$NOW" \
       --arg severity "$SEVERITY" \
       --argjson batch "$BATCH_NUM" \
       --arg freshness_level "$FRESHNESS_LEVEL" \
       --argjson freshness_behind "$FRESHNESS_BEHIND" '
  [
    .[]
    | . as $g
    | $g.issue_ids[] as $iid
    | {
        event: "CI_TOOL_USED",
        task: "impact_analysis",
        primary: "gitnexus_impact",
        secondary: null,
        fallback_used: false,
        cache_hit: ($g.cache_status == "hit"),
        cache_source: "batch_lookup",
        parent_file: $g.file,
        issue_id: $iid,
        batch: $batch,
        severity: $severity,
        duration_ms: (if $g.cache_status == "hit" then 5 else 0 end),
        result_count: (
          if $g.impact == null then 0
          elif ($g.impact | type) == "array" then ($g.impact | length)
          elif ($g.impact | type) == "object" then
            (($g.impact.impacted_symbols // $g.impact.affected // $g.impact.targets // $g.impact.nodes // []) | length)
          else 0 end
        ),
        freshness_behind_commits: $freshness_behind,
        freshness_level: $freshness_level,
        timestamp: $ts
      }
  ]
' "$OUT_FILE" > "$NEW_ENTRIES_TMP" 2>/dev/null; then
  echo "[$SCRIPT_NAME] WARN: jq build log entries fail — skip per-issue logging" >&2
  exit 0
fi

# APPEND vao fix-log.json (atomic)
TMP_LOG="${LOG_FILE}.tmp.$$"
if jq --slurpfile new "$NEW_ENTRIES_TMP" '.entries += $new[0]' "$LOG_FILE" > "$TMP_LOG" 2>/dev/null; then
  mv "$TMP_LOG" "$LOG_FILE"
else
  echo "[$SCRIPT_NAME] WARN: append fix-log.json fail (jq error) — entries van duoc giu trong ci-batch.json" >&2
  rm -f "$TMP_LOG"
fi

NEW_ENTRY_COUNT=$(jq 'length' "$NEW_ENTRIES_TMP" 2>/dev/null || echo 0)

echo "[$SCRIPT_NAME] DONE: severity=$SEVERITY batch=$BATCH_NUM files=$GROUP_COUNT hit=$HIT_COUNT miss=$MISS_COUNT issues_logged=$NEW_ENTRY_COUNT freshness=$FRESHNESS_LEVEL" >&2
exit 0
