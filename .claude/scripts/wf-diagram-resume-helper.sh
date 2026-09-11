#!/usr/bin/env bash
# wf-diagram-resume-helper.sh — --status display 5 latest sessions
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/wf-diagram-resume-helper.sh
#
# Output (stdout): Markdown table với 5 sessions mới nhất, sort theo mtime.
#   Nếu không có session nào → message hướng dẫn.
#
# Used by: procedures/resume-status.md CASE A (--status flag).
# Schema: đọc từ $SESSIONS_DIR/$dir/diagram-status.json.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="wf-diagram-resume-helper"
# shellcheck source=./wf-diagram-common.sh
source "$SCRIPTS_DIR/wf-diagram-common.sh"

set -uo pipefail 2>/dev/null || set -u

# Allow override qua arg (test convenience)
SESSIONS_DIR="${1:-.mc-data/work/wf-diagram/sessions}"

if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "Chưa có session nào. Chạy /wf-diagram --module=<name> để bắt đầu."
  exit 0
fi

if ! has_jq; then
  log_warn "jq không có — chỉ hiển thị session IDs"
  echo "Sessions tìm thấy (latest 5):"
  ls -1t "$SESSIONS_DIR" 2>/dev/null | head -5 | while IFS= read -r d; do
    echo "  - $d"
  done
  exit 0
fi

echo "Trạng thái Sessions — wf-diagram"
echo ""
echo "| Session ID | Module | Scope | Status | Phase | Started |"
echo "|------------|--------|-------|--------|-------|---------|"

count=0
ls -1t "$SESSIONS_DIR" 2>/dev/null | head -5 | while IFS= read -r dir; do
  status_file="$SESSIONS_DIR/$dir/diagram-status.json"
  [[ ! -s "$status_file" ]] && continue

  sid=$(jq -r '.session_id // "(missing)"' "$status_file" 2>/dev/null)
  [[ "$sid" == "(missing)" ]] && sid="$dir"
  mod=$(jq -r '.module // "—"' "$status_file" 2>/dev/null)
  sc=$(jq -r '.scope // "full"' "$status_file" 2>/dev/null)
  st=$(jq -r '.status // "—"' "$status_file" 2>/dev/null)
  started=$(jq -r '.started_at // "—"' "$status_file" 2>/dev/null)

  # Phase hiện tại: ưu tiên in_progress; fallback last completed; default phase_0
  current_phase=$(jq -r '
    [.phases // {} | to_entries[] | select(.value.status == "in_progress")] as $ip
    | if ($ip | length) > 0 then ($ip[0].key)
      else
        [.phases // {} | to_entries[] | select(.value.status == "completed")] as $cp
        | if ($cp | length) > 0 then ($cp[-1].key) else "phase_0" end
      end
  ' "$status_file" 2>/dev/null | sed 's/phase_/P/')
  [[ -z "$current_phase" ]] && current_phase="P0"

  # Truncate started_at to YYYY-MM-DD HH:MM if ISO-8601
  started_short=$(echo "$started" | sed -E 's/T/ /; s/Z$//; s/\.[0-9]+$//' | cut -c1-16)

  echo "| $sid | $mod | $sc | $st | $current_phase | $started_short |"
  count=$((count + 1))
done

echo ""
echo "Tip: Dùng --resume để tiếp tục session in_progress."
echo "     Dùng --module=<name> để bắt đầu session mới."

exit 0
