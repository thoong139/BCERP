#!/usr/bin/env bash
# =============================================================================
# detect-cross-scope.sh — Detect cross-scope issues (Wave 3 G4 — v11.2.0)
# =============================================================================
# Mục đích:
#   Phân tích issue-registry.json để phát hiện issues mà fix scope hiện tại
#   không thể xử lý được (touching modules khác). Emit JSON summary để
#   G-finalize.md decide CDG E096 trigger.
#
# Detection rules (3 layer):
#   L1. file_outside_scope: location.file path không match SCOPE_PATTERN
#         (vd: SCOPE=module=settings, file chứa /customs/ /finance/ → cross)
#   L2. cross_module_flag: issue có field cross_module_dependencies[] non-empty
#   L3. keyword_in_text: title/description chứa "cross-module" / "cross-scope" /
#         "spawn session" / "mở session" / "scope=cross"
#
# Required env vars:
#   SESSION_DIR  (canonical: .mc-data/work/wf-fix-bugs/sessions/{SESSION_ID})
#   SESSION_ID
#
# Optional env vars (đọc từ fix-status.json nếu không set):
#   SCOPE          (all | system | module | feat; default từ fix-status)
#   NAME           (scope target ID, vd: "settings"; default từ fix-status)
#   MCV3_FIX_CROSS_SCOPE_THRESHOLD  (default 3)
#   MCV3_FIX_CROSS_SCOPE_DISABLE    (default false)
#   MCV3_FIX_CROSS_SCOPE_DEBUG=1    (verbose stderr)
#
# Outputs (stdout JSON):
#   {
#     "cross_scope_count": N,
#     "threshold": 3,
#     "should_trigger_cdg": true|false,
#     "scope": "module",
#     "name": "settings",
#     "items": [
#       {
#         "canonical_id": "...",   // = registry id (or mapped if id-mapping exists)
#         "registry_id": "...",
#         "title": "...",
#         "severity": "...",
#         "dimension_id": "...",
#         "file": "...",
#         "reason": "file_outside_scope | cross_module_flag | keyword_match",
#         "target_scope": "module=customs",   // best-guess inferred
#         "scope_command": "/wf-fix-bugs --scope=cross-module --dims=QD10"
#       }
#     ]
#   }
#
# Exit codes:
#   0 — Detection complete (kể cả khi count=0)
#   1 — Missing env vars / source files
#
# Compatibility: Git Bash + WSL. Single jq pass (no per-issue subshells) →
# fork-safe trên Windows.
# =============================================================================

set -eu

DEBUG="${MCV3_FIX_CROSS_SCOPE_DEBUG:-0}"
THRESHOLD="${MCV3_FIX_CROSS_SCOPE_THRESHOLD:-3}"
DISABLE="${MCV3_FIX_CROSS_SCOPE_DISABLE:-false}"

dbg() {
  [ "$DEBUG" = "1" ] && echo "[detect-cross-scope] $*" >&2 || true
}

for var in SESSION_DIR SESSION_ID; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: env var \$$var is empty" >&2
    exit 1
  fi
done

# If disabled, return empty result and bail (exit 0)
if [ "$DISABLE" = "true" ]; then
  jq -n --argjson th "$THRESHOLD" \
    '{cross_scope_count: 0, threshold: $th, should_trigger_cdg: false, scope: "disabled", name: "", items: [], reason: "MCV3_FIX_CROSS_SCOPE_DISABLE=true"}'
  exit 0
fi

REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
FIX_STATUS="$SESSION_DIR/fix-status.json"
ID_MAPPING="$SESSION_DIR/_meta/id-mapping.json"

if [ ! -s "$REGISTRY" ]; then
  echo "ERROR: registry not found: $REGISTRY" >&2
  exit 1
fi

# ─── Resolve SCOPE + NAME ────────────────────────────────────────────────────
if [ -z "${SCOPE:-}" ] && [ -s "$FIX_STATUS" ]; then
  SCOPE=$(jq -r '.scope // "all"' "$FIX_STATUS" 2>/dev/null || echo "all")
fi
if [ -z "${NAME:-}" ] && [ -s "$FIX_STATUS" ]; then
  NAME=$(jq -r '.name // ""' "$FIX_STATUS" 2>/dev/null || echo "")
fi
SCOPE="${SCOPE:-all}"
NAME="${NAME:-}"

dbg "SCOPE=$SCOPE NAME=$NAME THRESHOLD=$THRESHOLD"

# ─── Build scope pattern for jq ──────────────────────────────────────────────
# Only check cross-scope when SCOPE is module/system/feat with NAME.
# For SCOPE=all, file_outside_scope rule is skipped (all files in scope).
DO_FILE_CHECK="false"
if { [ "$SCOPE" = "module" ] || [ "$SCOPE" = "system" ] || [ "$SCOPE" = "feat" ]; } && [ -n "$NAME" ]; then
  DO_FILE_CHECK="true"
fi

# ─── Single jq pass: classify + emit items ───────────────────────────────────
# This avoids per-issue subshell spawn (fork-safe trên Windows).
# v11.2.0: Use temp file instead of process substitution (Cygwin /proc/PID/fd issue).
ID_MAPPING_TMP="$SESSION_DIR/.id-mapping-stub.tmp.$$"
if [ -s "$ID_MAPPING" ]; then
  cp "$ID_MAPPING" "$ID_MAPPING_TMP"
else
  echo '{"mappings":[]}' > "$ID_MAPPING_TMP"
fi

# Build the items array via jq
ITEMS_JSON=$(jq \
  --arg scope "$SCOPE" \
  --arg name "$NAME" \
  --argjson do_file_check "$DO_FILE_CHECK" \
  --slurpfile id_mapping_arr "$ID_MAPPING_TMP" \
  '
  # Build a map from registry_id → canonical_id (from id-mapping if present)
  ($id_mapping_arr[0].mappings // []) as $maps
  | ($maps | map({key: .registry_id, value: .canonical_id}) | from_entries) as $cmap
  | [
      .issues[] |
      . as $issue |
      ($issue.id // "") as $rid |
      ($issue.title // "") as $title |
      ($issue.description // "") as $desc |
      ($issue.severity // "medium") as $sev |
      ($issue.dimension_id // "") as $dim |
      ($issue.location.file // null) as $file |
      ($issue.cross_module_dependencies // []) as $cmdeps |
      # Compute reason
      # File outside scope check: case-insensitive substring match against scope name.
      # File is IN-SCOPE if (a) filename contains scope name (case-insensitive), OR
      # (b) any path segment contains scope name as substring (case-insensitive).
      ($name | ascii_downcase) as $name_lc |
      (
        if ($cmdeps | length) > 0 then "cross_module_flag"
        elif $do_file_check and ($file != null) and ($file | type == "string") and
             ($file | (
               # Skip infra files (not real cross-module — repo-wide configs / shared code)
               (test("(messages/|i18n/|locales/|^e2e/|/e2e/|\\.env|^\\.mc-data/|^docs/|^\\.claude/|/_shared/|package\\.json$|tsconfig\\.json$|globals\\.css$|next\\.config|tailwind\\.config|\\.gitignore$|^README)")) | not
             )) and
             # NOT in scope: case-insensitive substring of scope name in file path
             (($file | ascii_downcase) | (contains($name_lc) | not)) then "file_outside_scope"
        else
          (($title + " " + $desc) | ascii_downcase) as $text |
          if ($text | test("cross-module|cross-scope|cross scope|spawn session|mở session|scope=cross|cross_module")) then "keyword_match"
          else null
          end
        end
      ) as $reason |
      select($reason != null) |
      # Infer target_scope from file path (best-effort)
      (
        if $reason == "file_outside_scope" and $file != null then
          (
            ($file | capture("\\(dashboard\\)/(?<m>[a-z][a-z-]+)/").m // null) //
            (($file | capture("Modules\\.(?<m>[A-Za-z]+)/").m // null) | if . != null then ascii_downcase else null end)
          ) as $target |
          if $target != null then "module=" + $target else "cross-module" end
        else "cross-module"
        end
      ) as $target_scope |
      # Build scope_command suggestion
      (
        if $reason == "file_outside_scope" and ($target_scope | startswith("module=")) then
          "/wf-fix-bugs --scope=module --name=" + ($target_scope | sub("^module="; ""))
        else "/wf-fix-bugs --scope=cross-module"
        end
      ) as $base_cmd |
      (if ($dim == "QD9" or $dim == "QD10") then $base_cmd + " --dims=" + $dim else $base_cmd end) as $cmd |
      # Lookup canonical_id from id-mapping (default to rid)
      ($cmap[$rid] // $rid) as $cid |
      {
        canonical_id: $cid,
        registry_id: $rid,
        title: $title,
        severity: $sev,
        dimension_id: $dim,
        file: $file,
        reason: $reason,
        target_scope: $target_scope,
        scope_command: $cmd
      }
    ]' "$REGISTRY" 2>&1)

JQ_RC=$?
rm -f "$ID_MAPPING_TMP"
if [ "$JQ_RC" -ne 0 ]; then
  echo "ERROR: jq classification fail: $ITEMS_JSON" >&2
  exit 1
fi

# Compute count
CROSS_COUNT=$(echo "$ITEMS_JSON" | jq 'length' 2>/dev/null || echo 0)
CROSS_COUNT=${CROSS_COUNT:-0}

dbg "CROSS_COUNT=$CROSS_COUNT"

# Decide should_trigger_cdg
SHOULD_TRIGGER="false"
if [ "$CROSS_COUNT" -ge "$THRESHOLD" ]; then
  SHOULD_TRIGGER="true"
fi

# Emit summary (use --slurpfile to avoid arg-list-too-long on Windows)
TMP_ITEMS="$SESSION_DIR/.cross-scope-items.tmp.$$"
echo "$ITEMS_JSON" > "$TMP_ITEMS"

jq -n \
  --argjson count "$CROSS_COUNT" \
  --argjson th "$THRESHOLD" \
  --argjson trig "$SHOULD_TRIGGER" \
  --arg sc "$SCOPE" \
  --arg nm "$NAME" \
  --slurpfile items "$TMP_ITEMS" \
  '{
    cross_scope_count: $count,
    threshold: $th,
    should_trigger_cdg: $trig,
    scope: $sc,
    name: $nm,
    items: $items[0]
  }'

rm -f "$TMP_ITEMS"

exit 0
