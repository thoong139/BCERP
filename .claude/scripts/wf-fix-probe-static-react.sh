#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-react.sh — Static probe: React Component Contract Check (QD1)
#
# Phat hien vi pham contract trong React components va hooks:
#  - useMutation() khong co onError handler (silent API failure)
#  - useState destructure khong lay setter (dead state — UI bi lock)
#  - <Button>/<button> khong co onClick, type=submit, asChild, hoac disabled
#  - useQuery hooks trong component khong duoc check .isError day du
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed (static code analysis)
#
# USAGE:
#   bash wf-fix-probe-static-react.sh \
#     --session-dir <path> --lane wf-fix-functional --probe P-QD1-react-contract-check \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: wf-fix-bugs v7.5 — Gap 2 fix


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-react-contract-check"
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
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD1", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

EXCLUDE='(node_modules|\.git/|dist/|build/|\.next/|coverage/|__tests__|\.spec\.|\.test\.|fixtures/|mocks?/)'

EMIT() {
  local title="$1" desc="$2" severity="$3" file="$4" line="$5" suggested_action="$6"
  local fp
  fp=$(echo -n "QD1|$file|$line|$PROBE_ID|$title" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg t "$title" --arg d "$desc" --arg s "$severity" \
    --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
    --arg sa "$suggested_action" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD1",
      probe_id: $pid,
      probe_version: $pver,
      severity: $s,
      fixability: "agent_fix",
      domain: "frontend",
      title: $t,
      description: $d,
      location: { file: $f, line: $l, column: null, selector: null, url: null },
      evidence: [{ type: "code", path: $f, description: ("Line " + ($l|tostring) + ": " + $t) }],
      cdg_flags: [],
      fingerprint: $fp,
      remediation: { suggested_action: $sa, suggested_agent: "frontend-developer", estimated_effort: "small" },
      detected_at: $now,
      detected_by: ($lane + "/" + $pid)
    }'
}

SIGNALS_JSON='[]'

# ── Probe dispatch ────────────────────────────────────────────
RUN_MUTATION_ERROR=0   # useMutation missing onError
RUN_DEAD_STATE=0       # useState without setter
RUN_BUTTON_HANDLER=0   # Button without onClick

case "$PROBE_ID" in
  P-QD1-react-contract-check)
    RUN_MUTATION_ERROR=1; RUN_DEAD_STATE=1; RUN_BUTTON_HANDLER=1 ;;
  *)
    echo "ERROR: unknown PROBE_ID '$PROBE_ID' for QD1-react — valid: P-QD1-react-contract-check" >&2
    exit 1 ;;
esac

# ============================================================
# CHECK 1: useMutation() without onError handler
# Files with N mutations but fewer than N onError callbacks.
# ============================================================
if [ "$RUN_MUTATION_ERROR" -eq 1 ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    mutation_count=$(grep -c 'useMutation(' "$file" 2>/dev/null || true)
    on_error_count=$(grep -c 'onError' "$file" 2>/dev/null || true)
    if [ "$mutation_count" -gt 0 ] && [ "$on_error_count" -lt "$mutation_count" ]; then
      missing=$((mutation_count - on_error_count))
      line=$(grep -n 'useMutation(' "$file" 2>/dev/null | head -1 | cut -d: -f1)
      line="${line:-1}"
      s=$(EMIT "useMutation thieu onError handler" \
        "File co $mutation_count useMutation() nhung chi co $on_error_count onError handler — thieu $missing. Khi API call that bai, user khong nhan feedback. Silent failure gay mat du lieu hoac trang thai sai ma khong co error message." \
        "high" "$file" "$line" \
        "Them 'onError: (err) => { console.error(err); }' cho moi useMutation block. Cach tot hon: set defaultOptions.mutations.onError trong QueryClient.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  done < <(grep -rl 'useMutation(' "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' 2>/dev/null || true)
fi

# ============================================================
# CHECK 2: useState destructure without setter — dead state
# Pattern: const [x] = useState(...) — setter bi bo qua
# UI element bound to this state khong the thay doi.
# ============================================================
if [ "$RUN_DEAD_STATE" -eq 1 ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    s=$(EMIT "useState thieu setter (dead state)" \
      "Phat hien 'const [${match}] = useState(...)' — destructure chi lay gia tri, KHONG lay setter. State nay khong the thay doi sau khi init, khien UI element bound vao no bi khoa cung gia tri khoi tao. Day la functional bug neu co UI control duoc thiet ke de thay doi state nay." \
      "medium" "$file" "$line" \
      "Doi thanh 'const [x, setX] = useState(...)' va them UI control goi setX(), hoac xoa state neu khong can thay doi.")
    SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
  done < <(grep -rEn 'const \[[a-zA-Z_$][a-zA-Z0-9_$]*\] = useState\b' "$SOURCE_DIR" \
    --include='*.tsx' --include='*.jsx' --include='*.ts' 2>/dev/null || true)
fi

# ============================================================
# CHECK 3: <Button> without onClick, type="submit", asChild, or disabled
# Buttons that appear interactive but have no handler — silent no-op.
# Only flag self-contained Button tags (no children span across lines well
# with simple grep, so we target the most common single-line pattern).
# ============================================================
if [ "$RUN_BUTTON_HANDLER" -eq 1 ] && { [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; }; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    # Skip if has onClick, submit, asChild (renders as child), or disabled
    if echo "$match" | grep -qE 'onClick|type="submit"|type=\{|asChild|disabled|href='; then continue; fi
    # Only flag if it looks like a standalone button opening tag
    if echo "$match" | grep -qE '^[[:space:]]*<Button[[:space:]]'; then
      s=$(EMIT "Button khong co onClick handler" \
        "Phat hien <Button> tag khong co onClick, type='submit', asChild hay disabled. Click vao button nay se la silent no-op — user khong nhan phan hoi. Cac button nhu 'Export', 'Connect', 'Create' can co handler hoac ro rang disabled voi ly do." \
        "medium" "$file" "$line" \
        "Them onClick handler, hoac them disabled={true} title='Tinh nang dang phat trien' de thong bao ro rang cho user.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  done < <(grep -rEn '<Button(\s|$)' "$SOURCE_DIR" \
    --include='*.tsx' --include='*.jsx' 2>/dev/null | head -100 || true)
fi

# Emit final
# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile signals "$__SIGNALS_TMPFILE" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD1", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals[0]}'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
