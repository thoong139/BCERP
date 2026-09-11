#!/usr/bin/env bash
# isg-prompt.sh — Interactive Selection Gate (shell entry point)
#
# Vai trò:
#   Orchestrate phân tích signals + render checklist QD + nhận user response
#   + emit dim-selection.json.
#
# B1 Skeleton (2026-04-20): CHƯA implement logic thật. Mọi nhánh chỉ echo TODO.
#
# Usage:
#   isg-prompt.sh --session-dir <path> --profile <quick|standard|deep|exhaustive> \
#                 [--scope all|system|module] [--name <id>] [--since <git-ref>]
#
# Exit codes:
#   0 = emit dim-selection.json thành công
#   1 = user abort (ESC / Ctrl+C)
#   2 = safety floor violation (profile ≥ standard bỏ toàn bộ QD1+QD2+QD5)
#   3 = invalid args
#   4 = internal error (recommender.py crash)

set -euo pipefail

# ────────────────────────────────────────────────────────────────────
# 1. Parse args (skeleton)
# ────────────────────────────────────────────────────────────────────
SESSION_DIR=""
PROFILE="standard"
SCOPE="all"
SCOPE_NAME=""
SINCE_REF=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-dir) SESSION_DIR="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --scope) SCOPE="$2"; shift 2 ;;
        --name) SCOPE_NAME="$2"; shift 2 ;;
        --since) SINCE_REF="$2"; shift 2 ;;
        *) echo "LỖI: arg không nhận diện: $1" >&2; exit 3 ;;
    esac
done

[[ -z "$SESSION_DIR" ]] && { echo "LỖI: thiếu --session-dir" >&2; exit 3; }

# ────────────────────────────────────────────────────────────────────
# 2. Gọi recommender.py để phân tích signals
# ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOMMENDER="$SCRIPT_DIR/isg_recommender.py"

# TODO(B3): Thực thi recommender và capture recommendations.json
# python3 "$RECOMMENDER" analyze \
#     --session-dir "$SESSION_DIR" \
#     --profile "$PROFILE" \
#     --scope "$SCOPE" \
#     ${SCOPE_NAME:+--name "$SCOPE_NAME"} \
#     ${SINCE_REF:+--since "$SINCE_REF"} \
#     > "$SESSION_DIR/recommendations.json"

echo "[TODO B1] gọi $RECOMMENDER analyze — chưa implement"
echo "[TODO B1] sẽ emit $SESSION_DIR/recommendations.json"

# ────────────────────────────────────────────────────────────────────
# 3. Render markdown checklist cho user
# ────────────────────────────────────────────────────────────────────
# TODO(B3): in ra bảng tick-box
# python3 "$RECOMMENDER" render \
#     --recommendations "$SESSION_DIR/recommendations.json" \
#     --profile "$PROFILE"

echo "[TODO B1] render checklist — chưa implement"

# ────────────────────────────────────────────────────────────────────
# 4. Đọc user input (stdin)
# ────────────────────────────────────────────────────────────────────
# TODO(B3): đọc từ stdin, parse format "QD1,QD2" hoặc "all" hoặc "recommend"
# USER_INPUT=""
# read -r -p "Chọn QD (vd: QD1,QD2,QD5 hoặc 'recommend' hoặc 'all'): " USER_INPUT

echo "[TODO B1] đọc user input — chưa implement"

# ────────────────────────────────────────────────────────────────────
# 5. Enforce safety floor (ADR-22 rule 1) + CDG (CORE-027)
# ────────────────────────────────────────────────────────────────────
# TODO(B3): gọi recommender.py enforce + cdg-check
# python3 "$RECOMMENDER" enforce \
#     --selected "$USER_INPUT" \
#     --profile "$PROFILE" \
#     --session-dir "$SESSION_DIR"

echo "[TODO B1] enforce safety floor + CDG — chưa implement"

# ────────────────────────────────────────────────────────────────────
# 6. Emit dim-selection.json
# ────────────────────────────────────────────────────────────────────
# TODO(B3): final emit
# python3 "$RECOMMENDER" emit \
#     --selected "$USER_INPUT" \
#     --profile "$PROFILE" \
#     --output "$SESSION_DIR/dim-selection.json"

echo "[TODO B1] emit dim-selection.json — chưa implement"
echo ""
echo "isg-prompt.sh: B1 skeleton — không thực sự prompt; trả exit 0 để test wiring"
exit 0
