#!/usr/bin/env bash
# wf-fix-merge-non-static-probes.sh — F5 (SB-02 fix v7.4)
#
# Quét `dimension.json` + `lanes/{DIM}/signals.json` cho từng DIM được cung cấp,
# liệt kê probes có `type` ∈ {runtime, runtime+agent, static+runtime, agent}
# MÀ CHƯA XUẤT HIỆN trong `signals.json.signals[].probe_id`.
#
# Output: JSON array tới stdout cho orchestrator drive Agent calls.
#
# Usage:
#   wf-fix-merge-non-static-probes.sh --session-dir <path> --dims=QD1,QD2,QD5
#   hoặc: wf-fix-merge-non-static-probes.sh --session-dir <path> --dim QD1 [--dim QD2]
#   hoặc: wf-fix-merge-non-static-probes.sh --session-dir <path> --dims-file <path>
#
# Output schema (JSON array):
#   [
#     {
#       "dimension": "QD1",
#       "probe_id": "P-QD1-deep-ui-traversal",
#       "probe_name": "Deep UI Traversal + Interaction Smoke",
#       "probe_type": "runtime",
#       "probe_md_path": ".claude/skills/workflow/wf-fix-functional/procedures/probes/P-QD1-deep-ui-traversal.md",
#       "agent_kind": "playwright",
#       "agent": null,
#       "depths": ["standard", "deep", "exhaustive"],
#       "severity_default": "HIGH",
#       "estimated_seconds": 120,
#       "estimated_tokens": 8000
#     },
#     ...
#   ]
#
# Exit codes:
#   0 — success (JSON array printed; có thể empty `[]` nếu không có probe nào thiếu)
#   1 — invalid args / session-dir not found
#   2 — required input missing (dimension.json không tồn tại cho DIM nào đó)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# QD → lane folder mapping (canonical, khớp lane skills directory)
qd_to_lane() {
  case "$1" in
    QD1) echo "wf-fix-functional" ;;
    QD2) echo "wf-fix-business" ;;
    QD3) echo "wf-fix-security" ;;
    QD4) echo "wf-fix-performance" ;;
    QD5) echo "wf-fix-ux-a11y" ;;
    QD6) echo "wf-fix-data" ;;
    QD7) echo "wf-fix-compat" ;;
    QD8) echo "wf-fix-observability" ;;
    QD9) echo "wf-fix-runtime-health" ;;
    QD10) echo "wf-fix-integration" ;;
    *) return 1 ;;
  esac
}

# ============================================================
# ARG PARSING
# ============================================================
SESSION_DIR=""
DIMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --dim)         DIMS+=("$2"); shift 2 ;;
    --dims=*)
      IFS=',' read -ra _D <<< "${1#--dims=}"
      DIMS+=("${_D[@]}")
      shift
      ;;
    --dims)
      IFS=',' read -ra _D <<< "$2"
      DIMS+=("${_D[@]}")
      shift 2
      ;;
    --dims-file)
      [ -s "$2" ] || { echo "ERROR: dims-file empty/missing: $2" >&2; exit 1; }
      while IFS= read -r line; do
        line="${line//[$'\r\n\t ']}"
        [ -n "$line" ] && DIMS+=("$line")
      done < "$2"
      shift 2
      ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }
[ "${#DIMS[@]}" -gt 0 ] || { echo "ERROR: --dims/--dim required" >&2; exit 1; }

# ============================================================
# COLLECT non-static probes per DIM
# ============================================================
RESULT='[]'

for DIM in "${DIMS[@]}"; do
  LANE=""
  if ! LANE=$(qd_to_lane "$DIM"); then
    echo "WARN: unknown dimension '$DIM' — skip" >&2
    continue
  fi

  DIM_FILE="$REPO_ROOT/.claude/skills/workflow/$LANE/dimension.json"
  if [ ! -s "$DIM_FILE" ]; then
    echo "ERROR: dimension.json missing for $DIM at: $DIM_FILE" >&2
    exit 2
  fi

  SIG_FILE="$SESSION_DIR/lanes/$DIM/signals.json"
  # Probes đã có signals — empty array nếu file thiếu/lane chưa chạy
  if [ -s "$SIG_FILE" ]; then
    FOUND=$(jq -c '[.signals[]?.probe_id] | unique' "$SIG_FILE" 2>/dev/null || echo '[]')
  else
    FOUND='[]'
  fi

  # Non-static probes từ dimension.json. PROBE_BASE = path tương đối tới folder probes/
  PROBE_BASE=".claude/skills/workflow/$LANE"
  MISSING=$(jq -c --arg dim "$DIM" --arg base "$PROBE_BASE" --argjson found "$FOUND" '
    [
      .probes[]
      | select(.type == "runtime" or .type == "runtime+agent" or .type == "static+runtime" or .type == "agent")
      | select((.id | IN($found[])) | not)
      | {
          dimension: $dim,
          probe_id: .id,
          probe_name: .name,
          probe_type: .type,
          probe_md_path: ($base + "/" + (.tool.config // ("procedures/probes/" + .id + ".md"))),
          agent_kind: (.tool.kind // null),
          agent: (.tool.agent // null),
          depths: (.depth // []),
          severity_default: (.severity_default // "MEDIUM"),
          estimated_seconds: (.estimated_cost.time_seconds // null),
          estimated_tokens: (.estimated_cost.tokens // null)
        }
    ]
  ' "$DIM_FILE" 2>/dev/null || echo '[]')

  RESULT=$(jq -c --argjson a "$RESULT" --argjson b "$MISSING" -n '$a + $b')
done

# Final output to stdout
echo "$RESULT"
exit 0
