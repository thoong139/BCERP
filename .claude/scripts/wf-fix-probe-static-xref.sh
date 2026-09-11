#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-xref.sh — Static probe: REQ-ID Registry Cross-Reference (QD1)
#
# Doc registry, grep REQ-ID/FEAT-ID annotations trong source code, phat hien:
#  - Coverage gaps: feature impl_status=done nhung khong co REQ-ID/FEAT-ID annotation
#  - Orphan annotations: code REQ-ID/FEAT-ID khong ton tai trong registry
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1 (xem _shared/lane/templates/signals.json)
#  SKILL.md redirect output vao $SESSION_DIR/lanes/QD1/raw/P-QD1-req-registry-xref.json
#  Sau do SKILL.md emit signals via signal-emit.md helper.
#
# USAGE:
#   bash wf-fix-probe-static-xref.sh \
#     --session-dir <path> --lane wf-fix-functional --probe P-QD1-req-registry-xref \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES:
#   0 — success (output JSON valid, signals[] co the rong)
#   1 — error (registry missing, jq fail, invalid args)
#
# DEPENDENCIES: bash >= 4, jq, grep
#
# Author: S5 wf-fix-bugs v7.0


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
# Cross-platform sha256 (GNU sha256sum / macOS shasum)
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

# ============================================================
# Args parsing
# ============================================================
SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-req-registry-xref"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
REGISTRY="$REPO_ROOT/.mc-data/docs/_meta/req-registry.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# Validation
# ============================================================
if [ ! -f "$REGISTRY" ]; then
  echo "ERROR: registry not found: $REGISTRY" >&2
  exit 1
fi

if ! jq -e '.' "$REGISTRY" >/dev/null 2>&1; then
  echo "ERROR: registry invalid JSON: $REGISTRY" >&2
  exit 1
fi

# ============================================================
# Step 1: Doc registry features (impl_status=done OR in_progress)
# ============================================================
FEATURES_JSON=$(jq -c '
  [.features // [] | .[]
   | select(.impl_status == "done" or .impl_status == "in_progress")
   | {id: .id, req_ids: (.requirement_ids // []), impl_status: .impl_status}]
' "$REGISTRY")

REQUIREMENTS_JSON=$(jq -c '[.requirements // [] | .[].id]' "$REGISTRY")

# Deprecated modules → loai khoi scope
DEPRECATED_MODULES=$(jq -c '[.systems // [] | .[] | select(.action == "DEPRECATE") | .id]' "$REGISTRY" 2>/dev/null || echo '[]')

# ============================================================
# Step 2: Grep REQ-ID + FEAT-ID annotations trong source code
# ============================================================
MCV3_TMP="$SESSION_DIR/.probe-xref-tmp"
mkdir -p "$MCV3_TMP" 2>/dev/null || { echo "ERROR: cannot create tmp dir $MCV3_TMP" >&2; exit 1; }
CODE_REQ_IDS_TMP="$MCV3_TMP/req-ids.$$.txt"
CODE_FEAT_IDS_TMP="$MCV3_TMP/feat-ids.$$.txt"
# Fix #4: maps for first-location lookup, build in 1 grep pass (O(N+M) thay O(N×M)).
# Format: "<id>\t<file>:<line>"  — tab-delimited cho lookup nhanh.
CODE_REQ_FIRST_LOC_TMP="$MCV3_TMP/req-first-loc.$$.txt"
CODE_FEAT_FIRST_LOC_TMP="$MCV3_TMP/feat-first-loc.$$.txt"
trap 'rm -rf "$MCV3_TMP"' EXIT
# Init empty files so subsequent `grep -qFx` không fail nếu SOURCE_DIR không tồn tại
: > "$CODE_REQ_IDS_TMP"
: > "$CODE_FEAT_IDS_TMP"
: > "$CODE_REQ_FIRST_LOC_TMP"
: > "$CODE_FEAT_FIRST_LOC_TMP"

if [ -d "$SOURCE_DIR" ]; then
  # Fix #4: 1 grep pass scan toàn bộ source — không grep lại per orphan.
  # Output format: "file:line:matched_text" → parse thành 2 maps:
  #  - sort -u IDs (cho membership check qua grep -qFx)
  #  - first-location map (cho orphan reporting, giữ "first occurrence" qua awk)
  REQ_RAW="$MCV3_TMP/req-raw.$$.txt"
  FEAT_RAW="$MCV3_TMP/feat-raw.$$.txt"

  grep -rEn '(REQ-[A-Z]+(-[A-Z]+)?-[0-9]+)' "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --include='*.py' --include='*.java' --include='*.cs' --include='*.go' --include='*.rs' \
    2>/dev/null > "$REQ_RAW" || true

  grep -rEn '(FEAT-[A-Z]+-[A-Z]+-[0-9]+)' "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --include='*.py' --include='*.java' --include='*.cs' --include='*.go' --include='*.rs' \
    2>/dev/null > "$FEAT_RAW" || true

  # Unique IDs.
  grep -oE '(REQ-[A-Z]+(-[A-Z]+)?-[0-9]+)' "$REQ_RAW" 2>/dev/null | sort -u > "$CODE_REQ_IDS_TMP" || true
  grep -oE '(FEAT-[A-Z]+-[A-Z]+-[0-9]+)' "$FEAT_RAW" 2>/dev/null | sort -u > "$CODE_FEAT_IDS_TMP" || true

  # First-location map: extract "file:line" + ID; awk giữ first occurrence per ID.
  awk -F: '
    {
      file=$1; line=$2;
      rest=$3; for (i=4; i<=NF; i++) rest=rest ":" $i;
      while (match(rest, /REQ-[A-Z]+(-[A-Z]+)?-[0-9]+/)) {
        id=substr(rest, RSTART, RLENGTH);
        if (!(id in seen)) { seen[id]=file ":" line; print id "\t" file ":" line; }
        rest=substr(rest, RSTART+RLENGTH);
      }
    }
  ' "$REQ_RAW" > "$CODE_REQ_FIRST_LOC_TMP" || true

  awk -F: '
    {
      file=$1; line=$2;
      rest=$3; for (i=4; i<=NF; i++) rest=rest ":" $i;
      while (match(rest, /FEAT-[A-Z]+-[A-Z]+-[0-9]+/)) {
        id=substr(rest, RSTART, RLENGTH);
        if (!(id in seen)) { seen[id]=file ":" line; print id "\t" file ":" line; }
        rest=substr(rest, RSTART+RLENGTH);
      }
    }
  ' "$FEAT_RAW" > "$CODE_FEAT_FIRST_LOC_TMP" || true

  rm -f "$REQ_RAW" "$FEAT_RAW"
fi

# ============================================================
# Step 3: Build signals
# ============================================================
# F24 fix v7.0.1: tích lũy signals vào temp file (1 JSON object per line)
# thay vì shell variable + --argjson reduce — tránh "Argument list too long"
# khi dự án có hàng trăm orphan annotations.
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
trap 'rm -rf "$MCV3_TMP"' EXIT
: > "$SIGNALS_TMP"

# 3a: Coverage gaps — features impl_status=done KHONG co annotation trong code
while IFS= read -r feat_id; do
  feat_id=$(echo "$feat_id" | tr -d '\r')  # cross-platform CRLF strip
  [ -z "$feat_id" ] && continue
  if ! grep -qFx "$feat_id" "$CODE_FEAT_IDS_TMP"; then
    # Feat ID khong co trong code → coverage gap
    impl_status=$(jq -r --arg id "$feat_id" '.features[] | select(.id == $id) | .impl_status' "$REGISTRY" | tr -d '\r')
    severity="medium"
    [ "$impl_status" = "done" ] && severity="high"

    fp=$(echo -n "QD1|registry|0|$PROBE_ID|coverage_gap|$feat_id" | _sha256 | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg fid "$feat_id" \
      --arg probe "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" \
      --arg sev "$severity" \
      --arg impl "$impl_status" \
      --arg fp "$fp" \
      --arg now "$(iso_now)" \
      --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD1",
        probe_id: $probe,
        probe_version: $pver,
        severity: $sev,
        fixability: "agent_fix",
        domain: "general",
        title: ("Coverage gap: " + $fid),
        description: ("Feature " + $fid + " (impl_status=" + $impl + ") khong tim thay annotation trong source code."),
        location: {file: "N/A", line: null, column: null, selector: null, url: null},
        evidence: [{type: "code", path: "registry-xref", description: ("Registry feature " + $fid + " thieu code annotation")}],
        cdg_flags: [],
        fingerprint: $fp,
        registry_refs: {feat_ids: [$fid]},
        detected_at: $now,
        detected_by: $detector
      }')
    printf '%s\n' "$sig" >> "$SIGNALS_TMP"
  fi
done < <(jq -r '.[] | .id' <<< "$FEATURES_JSON")

# 3b: Orphan annotations — code REQ-ID/FEAT-ID khong ton tai trong registry
# Fix #4: O(1) lookup per orphan từ pre-built map (CODE_REQ_FIRST_LOC_TMP).
while IFS= read -r req_id; do
  req_id=$(echo "$req_id" | tr -d '\r')
  [ -z "$req_id" ] && continue
  exists=$(jq -r --arg id "$req_id" '[.[] | select(. == $id)] | length' <<< "$REQUIREMENTS_JSON" | tr -d '\r')
  if [ "$exists" -eq 0 ]; then
    # Lookup file:line từ map đã build sẵn (1 lần grep) thay full directory scan
    loc_line=$(awk -F'\t' -v id="$req_id" '$1==id {print $2; exit}' "$CODE_REQ_FIRST_LOC_TMP")
    if [ -n "$loc_line" ]; then
      file_match="${loc_line%:*}"
      line_match="${loc_line##*:}"
    else
      file_match="unknown"
      line_match=0
    fi
    [ -z "$line_match" ] && line_match=0
    case "$line_match" in *[!0-9]*|"") line_match=0 ;; esac

    fp=$(echo -n "QD1|$file_match|$line_match|$PROBE_ID|orphan_annotation|$req_id" | _sha256 | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg rid "$req_id" \
      --arg file "$file_match" \
      --argjson line "$line_match" \
      --arg probe "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" \
      --arg fp "$fp" \
      --arg now "$(iso_now)" \
      --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD1",
        probe_id: $probe,
        probe_version: $pver,
        severity: "medium",
        fixability: "agent_fix",
        domain: "general",
        title: ("Orphan annotation: " + $rid),
        description: ("Source code chua " + $rid + " nhung registry khong co requirement nay. Co the do REQ-ID typo hoac requirement bi xoa."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ("REQ-ID " + $rid + " ton tai trong code nhung khong co trong registry")}],
        cdg_flags: [],
        fingerprint: $fp,
        registry_refs: {req_ids: [$rid]},
        detected_at: $now,
        detected_by: $detector
      }')
    printf '%s\n' "$sig" >> "$SIGNALS_TMP"
  fi
done < "$CODE_REQ_IDS_TMP"

# ============================================================
# Step 4: Output JSON wrapper (schema lane-signals-v1)
# F24 fix v7.0.1: dùng --slurpfile (đọc qua disk) thay vì --argjson
# tránh "Argument list too long" với JSON lớn.
# ============================================================
jq -n \
  --arg lane "$LANE" \
  --arg dim "QD1" \
  --arg probe "$PROBE_ID" \
  --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" \
  --arg now "$(iso_now)" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{
    "$schema": "lane-signals-v1",
    lane: $lane,
    dimension: $dim,
    probe_id: $probe,
    probe_version: $pver,
    profile: $profile,
    generated_at: $now,
    signals: $signals
  }'

exit 0
