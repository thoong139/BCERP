#!/usr/bin/env bash
# wf-fix-report-builder.sh — Aggregate signals → fix-report.md
#
# Doc tat ca lanes/QDx/signals.json trong session, build markdown report
# theo template lane-report-v1 (overall) hoac per-lane.
#
# USAGE:
#   bash wf-fix-report-builder.sh --session-dir <path> [--mode=overall|per-lane] [--output <file>]
#
# Modes:
#   overall (default) — 1 file fix-report.md o session root, aggregate 7 lanes
#   per-lane          — 1 file lane-report.md per lane (overrides existing)
#
# OUTPUT: writes markdown file. Stdout: JSON {"path":"...", "lanes":[...], "totals":{...}}
# EXIT CODES: 0 success, 1 error
#
# Author: S5 wf-fix-bugs v7.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

SESSION_DIR=""
MODE="overall"
OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --session-dir=*) SESSION_DIR="${1#*=}"; shift ;;
    --mode) MODE="$2"; shift 2 ;;
    --mode=*) MODE="${1#*=}"; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --output=*) OUTPUT="${1#*=}"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

[ -z "$SESSION_DIR" ] && { echo "ERROR: --session-dir required" >&2; exit 1; }
[ ! -d "$SESSION_DIR" ] && { echo "ERROR: session dir not found: $SESSION_DIR" >&2; exit 1; }

# ============================================================
# Aggregate signals from all lanes
# ============================================================
AGG_TMP="$SESSION_DIR/.report-builder-agg.$$.json"
trap 'rm -f "$AGG_TMP"' EXIT

echo '[]' > "$AGG_TMP"
LANES_JSON='[]'
TOTAL_SIGNALS=0
declare -A SEV_COUNT
SEV_COUNT[critical]=0; SEV_COUNT[high]=0; SEV_COUNT[medium]=0; SEV_COUNT[low]=0; SEV_COUNT[info]=0

for lane_dir in "$SESSION_DIR"/lanes/QD*; do
  [ -d "$lane_dir" ] || continue
  lane_id=$(basename "$lane_dir")  # QD1, QD2, ...
  signals_file="$lane_dir/signals.json"
  status_file="$lane_dir/lane-status.json"

  [ ! -f "$signals_file" ] && continue

  # Aggregate signals
  if jq -e '.signals' "$signals_file" >/dev/null 2>&1; then
    cnt=$(jq '.signals | length' "$signals_file")
    TOTAL_SIGNALS=$((TOTAL_SIGNALS + cnt))

    # Tally severity
    for sev in critical high medium low info; do
      delta=$(jq --arg s "$sev" '[.signals[] | select(.severity == $s)] | length' "$signals_file")
      SEV_COUNT[$sev]=$(( ${SEV_COUNT[$sev]} + delta ))
    done

    # Lane summary entry
    lane_name=$(jq -r '.lane // "unknown"' "$signals_file")
    lane_status="unknown"
    [ -f "$status_file" ] && lane_status=$(jq -r '.status // "unknown"' "$status_file")

    LANES_JSON=$(jq -c \
      --arg id "$lane_id" --arg name "$lane_name" \
      --arg status "$lane_status" --argjson cnt "$cnt" \
      '. + [{id:$id, name:$name, status:$status, signal_count:$cnt}]' <<< "$LANES_JSON")
  fi
done

# ============================================================
# Build markdown
# ============================================================
build_overall_report() {
  local out="$1"
  # F05.004 (Sprint 8): Atomic write — build vào tmp file rồi mv.
  # Tránh partial output nếu process crash mid-write.
  local tmp
  tmp=$(mktemp "${out}.XXXXXX") || { echo "ERROR: mktemp fail for $out" >&2; return 1; }
  cat > "$tmp" <<EOF
# Fix Report — $(basename "$SESSION_DIR")

> **Session:** $(basename "$SESSION_DIR")
> **Generated:** $(iso_now)
> **Schema:** lane-report-v1 (aggregated)

## Tom tat

| Severity | Count |
|----------|-------|
| critical | ${SEV_COUNT[critical]} |
| high     | ${SEV_COUNT[high]} |
| medium   | ${SEV_COUNT[medium]} |
| low      | ${SEV_COUNT[low]} |
| info     | ${SEV_COUNT[info]} |
| **Total** | **${TOTAL_SIGNALS}** |

## Phat hien

EOF

  # Per-lane sections
  echo "$LANES_JSON" | jq -r '.[] | "### \(.id) — \(.name)\n\n- **Status:** \(.status)\n- **Signals:** \(.signal_count)\n"' >> "$tmp"

  cat >> "$tmp" <<EOF

## Ket qua

Aggregated tu $(echo "$LANES_JSON" | jq 'length') lanes. Chi tiet signals: xem \`lanes/QD*/signals.json\`.

## Ket luan

EOF
  if [ "${SEV_COUNT[critical]}" -gt 0 ]; then
    echo "**${SEV_COUNT[critical]} CRITICAL issue(s)** — phai fix truoc release." >> "$tmp"
  elif [ "${SEV_COUNT[high]}" -gt 0 ]; then
    echo "**${SEV_COUNT[high]} HIGH issue(s)** — uu tien fix." >> "$tmp"
  elif [ "$TOTAL_SIGNALS" -gt 0 ]; then
    echo "Co $TOTAL_SIGNALS issue(s) cap thap. Co the fix incremental." >> "$tmp"
  else
    echo "Khong phat hien issue. Lanes da chay sach." >> "$tmp"
  fi

  # Atomic move tmp → final out (replace partial reads safely)
  mv "$tmp" "$out"
}

build_per_lane_report() {
  for lane_dir in "$SESSION_DIR"/lanes/QD*; do
    [ -d "$lane_dir" ] || continue
    lane_id=$(basename "$lane_dir")
    signals_file="$lane_dir/signals.json"
    status_file="$lane_dir/lane-status.json"
    out="$lane_dir/lane-report.md"

    [ ! -f "$signals_file" ] && continue

    lane_name=$(jq -r '.lane // "unknown"' "$signals_file")
    lane_status="unknown"; profile="unknown"; started=""; completed=""
    if [ -f "$status_file" ]; then
      lane_status=$(jq -r '.status // "unknown"' "$status_file")
      profile=$(jq -r '.profile // "unknown"' "$status_file")
      started=$(jq -r '.started_at // ""' "$status_file")
      completed=$(jq -r '.completed_at // ""' "$status_file")
    fi
    cnt=$(jq '.signals | length' "$signals_file")

    # F05.004 (Sprint 8): Atomic write — build vào tmp file rồi mv.
    local tmp
    tmp=$(mktemp "${out}.XXXXXX") || { echo "ERROR: mktemp fail for $out" >&2; continue; }

    cat > "$tmp" <<EOF
# Lane Report — $lane_id

> **Lane:** $lane_name
> **Dimension:** $lane_id
> **Profile:** $profile
> **Status:** $lane_status
> **Started:** $started
> **Completed:** $completed
> **Schema:** lane-report-v1

## Tom tat

- **Signals emitted:** $cnt
EOF
    for sev in critical high medium low info; do
      sev_cnt=$(jq --arg s "$sev" '[.signals[] | select(.severity == $s)] | length' "$signals_file")
      [ "$sev_cnt" -gt 0 ] && echo "- **$sev:** $sev_cnt" >> "$tmp"
    done

    cat >> "$tmp" <<EOF

## Phat hien

EOF
    jq -r '.signals[] | "### \(.id // "?") — \(.title // "untitled")\n\n- **Severity:** \(.severity)\n- **File:** \(.location.file // "?"):\(.location.line // "?")\n- **Description:** \(.description // "—")\n"' "$signals_file" >> "$tmp" 2>/dev/null || true

    cat >> "$tmp" <<EOF

## Ket qua

Probe execution: $(jq '.probes | length' "$status_file" 2>/dev/null || echo "?") probes.
Cache hits: $(jq '.cache.cache_hits // 0' "$status_file" 2>/dev/null || echo 0).

## Ket luan

EOF
    crit=$(jq '[.signals[] | select(.severity == "critical")] | length' "$signals_file")
    if [ "$crit" -gt 0 ]; then
      echo "Lane PHAT HIEN $crit CRITICAL issue(s) — block release." >> "$tmp"
    elif [ "$cnt" -gt 0 ]; then
      echo "Lane phat hien $cnt issue(s). Triage de quyet dinh fix priority." >> "$tmp"
    else
      echo "Lane CLEAN — khong phat hien issue." >> "$tmp"
    fi

    # Atomic move tmp → final out
    mv "$tmp" "$out"
  done
}

# ============================================================
# Execute mode
# ============================================================
case "$MODE" in
  overall)
    OUTPUT_PATH="${OUTPUT:-$SESSION_DIR/fix-report.md}"
    build_overall_report "$OUTPUT_PATH"
    OUTPUT="$OUTPUT_PATH"
    ;;
  per-lane)
    build_per_lane_report
    OUTPUT="${OUTPUT:-$SESSION_DIR/lanes/*/lane-report.md}"
    ;;
  *)
    echo "ERROR: invalid mode: $MODE" >&2
    exit 1
    ;;
esac

# Output JSON summary
jq -nc \
  --arg path "$OUTPUT" --arg mode "$MODE" \
  --argjson total "$TOTAL_SIGNALS" \
  --argjson crit "${SEV_COUNT[critical]}" --argjson high "${SEV_COUNT[high]}" \
  --argjson med "${SEV_COUNT[medium]}" --argjson low "${SEV_COUNT[low]}" --argjson info "${SEV_COUNT[info]}" \
  --argjson lanes "$LANES_JSON" \
  '{
    path: $path, mode: $mode,
    totals: {total: $total, critical: $crit, high: $high, medium: $med, low: $low, info: $info},
    lanes: $lanes
  }'

exit 0
