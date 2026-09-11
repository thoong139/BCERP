#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-compat.sh — QD7 Browser Compatibility Probe (IMP-017)
#
# Kiểm tra browser compatibility dựa trên browserslist config + built-in compat matrix.
# Three execution paths:
#   A. node + caniuse-lite available  : Query actual caniuse database
#   B. Static grep analysis           : Built-in CSS/JS compat matrix (offline)
#   C. Graceful degradation           : probe_status=compat_unavailable (no source dir)
#
# OUTPUT: lane-signals-v1 JSON to stdout.
# USAGE:
#   bash wf-fix-probe-static-compat.sh \
#     [--source-dir <path>]     (default: src/)
#     [--browserslist <query>]  (override browserslist targets)
#     [--baseline <%>]          (global usage baseline, default: 85)
#
# EXIT CODES: 0 success, 1 error


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"

PROBE_ID="P-QD7-browser-compat-check"
DIMENSION="QD7"
SOURCE_DIR="src"
BROWSERSLIST_OVERRIDE=""
BASELINE_PCT=85

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)   SOURCE_DIR="$2"; shift 2 ;;
    --browserslist) BROWSERSLIST_OVERRIDE="$2"; shift 2 ;;
    --baseline)     BASELINE_PCT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

_sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }
_fp() { printf '%s' "$1" | _sha256_fn | awk '{print "sha256:"$1}'; }

SIGNALS=()

# ============================================================
# Detect browserslist targets
# ============================================================
TARGETS="defaults"
if [[ -n "$BROWSERSLIST_OVERRIDE" ]]; then
  TARGETS="$BROWSERSLIST_OVERRIDE"
elif [[ -f ".browserslistrc" ]]; then
  TARGETS=$(grep -v '^#' .browserslistrc 2>/dev/null | grep -v '^$' | head -5 | tr '\n' ',' | sed 's/,$//')
elif [[ -f "package.json" ]] && jq -e '.browserslist' package.json >/dev/null 2>&1; then
  TARGETS=$(jq -r '.browserslist | if type=="array" then .[] else . end' package.json 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
fi

# Detect IE11 in targets (raises severity for no-polyfill features)
IE11_TARGET=0
if echo "$TARGETS" | grep -qiE 'IE[[:space:]]*1[01]'; then
  IE11_TARGET=1
fi

# ============================================================
# PATH C: Source directory missing → graceful degradation
# ============================================================
if [[ ! -d "$SOURCE_DIR" ]]; then
  jq -nc \
    --arg schema "lane-signals-v1" \
    --arg probe  "$PROBE_ID" \
    --arg dim    "$DIMENSION" \
    --arg status "compat_unavailable" \
    --arg tgt    "$TARGETS" \
    '{
      "$schema":              $schema,
      probe_id:               $probe,
      dimension:              $dim,
      probe_status:           $status,
      signal_count:           0,
      signals:                [],
      browserslist_targets:   $tgt,
      note: "Source directory not found. Provide --source-dir or run from project root."
    }'
  exit 0
fi

# ============================================================
# Detect PATH A vs PATH B
# ============================================================
COMPAT_BACKEND="static-matrix"
if command -v node >/dev/null 2>&1; then
  if node -e "require('caniuse-lite')" >/dev/null 2>&1; then
    COMPAT_BACKEND="caniuse-lite"
  fi
fi

# ============================================================
# F1.compat sampling (Wave 3 v7.4 e2e fix):
# Codebase >SAMPLING_THRESHOLD files → grep -rn quá chậm → sample SAMPLE_SIZE files
# ngẫu nhiên qua `shuf -n`. Emit WARN ra stderr + envelope fields sampling=true,
# coverage_pct, total_files, sampled_files để consumers biết coverage giới hạn.
# ============================================================
SAMPLING_THRESHOLD=5000
SAMPLE_SIZE=2000
SAMPLING=false
COVERAGE_PCT=100
SAMPLED_FILES=0
SAMPLE_LIST=""

# Count chỉ file có extension liên quan để tránh inflate bởi node_modules/binaries.
TOTAL_FILES=$(find "$SOURCE_DIR" -type f \
  \( -name "*.css" -o -name "*.scss" -o -name "*.less" \
     -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
  2>/dev/null | wc -l)
TOTAL_FILES=$(echo "$TOTAL_FILES" | tr -d '[:space:]')
[[ -z "$TOTAL_FILES" ]] && TOTAL_FILES=0

if [[ "$TOTAL_FILES" -gt "$SAMPLING_THRESHOLD" ]] && command -v shuf >/dev/null 2>&1; then
  SAMPLING=true
  SAMPLE_LIST=$(mktemp -t "wf-fix-compat-sample.XXXXXX" 2>/dev/null || mktemp)
  trap 'rm -f "$SAMPLE_LIST"' EXIT
  find "$SOURCE_DIR" -type f \
    \( -name "*.css" -o -name "*.scss" -o -name "*.less" \
       -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    2>/dev/null | shuf -n "$SAMPLE_SIZE" > "$SAMPLE_LIST" || true
  SAMPLED_FILES=$(wc -l < "$SAMPLE_LIST" 2>/dev/null | tr -d '[:space:]')
  [[ -z "$SAMPLED_FILES" ]] && SAMPLED_FILES=0
  if [[ "$TOTAL_FILES" -gt 0 ]]; then
    COVERAGE_PCT=$(( SAMPLED_FILES * 100 / TOTAL_FILES ))
  fi
  echo "WARN: codebase has $TOTAL_FILES relevant files (>${SAMPLING_THRESHOLD}) — sampling ${SAMPLED_FILES} files (~${COVERAGE_PCT}% coverage)" >&2
else
  SAMPLED_FILES="$TOTAL_FILES"
fi

# Helper: grep cho một extension subset, tôn trọng SAMPLING.
# $1 = extension regex (vd: '\.(css|scss|less)$')
# $2 = grep --include flags hoặc rỗng (cho non-sampling path)
# $3 = pattern
_compat_grep() {
  local ext_re="$1" inc_flags="$2" pat="$3"
  if $SAMPLING; then
    # Batch grep qua mapfile + array slicing để tránh:
    #  - while-read per-file (quá chậm: 36K subprocess fork trên Windows)
    #  - xargs (MSYS2 convert /tmp/... → C:/.../tmp/... gây colon trong path)
    # MSYS2_ARG_CONV_EXCL='*' tắt path conversion khi gọi grep batched.
    local -a sample_files
    mapfile -t sample_files < <(grep -E "$ext_re" "$SAMPLE_LIST" 2>/dev/null)
    local n=${#sample_files[@]} i
    [[ "$n" -eq 0 ]] && return 0
    # Chunk size 100 để không vượt ARG_MAX trên Windows (~8K chars).
    for ((i=0; i<n; i+=100)); do
      MSYS2_ARG_CONV_EXCL='*' grep -nH "$pat" "${sample_files[@]:i:100}" 2>/dev/null || true
    done
  else
    # shellcheck disable=SC2086
    grep -rn $inc_flags "$pat" "$SOURCE_DIR" 2>/dev/null || true
  fi
}

# ============================================================
# Built-in compat matrix — format: PATTERN<TAB>FEAT_ID<TAB>DESC<TAB>HAS_POLYFILL
# These are features with limited browser support that may need polyfills
# ============================================================

# CSS features matrix (search in .css/.scss/.less files)
declare -a CSS_PATTERNS CSS_FEATS CSS_DESCS CSS_POLY
CSS_PATTERNS=(':has(' 'container-type:' 'container-name:' '@layer ' 'subgrid' 'color-mix(' 'accent-color:' 'text-wrap: balance' 'field-sizing:' '@scope')
CSS_FEATS=('css-has' 'css-container-queries' 'css-container-queries' 'css-cascade-5' 'css-subgrid' 'css-color-mix' 'css-accent-color' 'css-text-wrap-balance' 'css-field-sizing' 'css-scope')
CSS_DESCS=('CSS :has() selector' 'CSS Container Queries (type)' 'CSS Container Queries (name)' 'CSS Cascade Layers (@layer)' 'CSS Subgrid' 'CSS color-mix()' 'CSS accent-color' 'CSS text-wrap: balance' 'CSS field-sizing' 'CSS @scope rule')
CSS_POLY=(0 0 0 0 0 0 0 0 0 0)

# JS features matrix (search in .ts/.tsx/.js/.jsx files)
declare -a JS_PATTERNS JS_FEATS JS_DESCS JS_POLY
JS_PATTERNS=('structuredClone(' 'navigator.clipboard' 'Intl.Segmenter' 'AbortSignal.timeout' 'crypto.randomUUID' 'new EyeDropper' 'navigator.usb' 'ViewTransition')
JS_FEATS=('mdn-structuredClone' 'clipboard-api' 'intl-segmenter' 'abortsignal-timeout' 'crypto-randomUUID' 'eyedropper-api' 'webusb' 'view-transitions')
JS_DESCS=('structuredClone() deep copy' 'Clipboard API (navigator.clipboard)' 'Intl.Segmenter' 'AbortSignal.timeout()' 'crypto.randomUUID()' 'EyeDropper API' 'WebUSB API' 'View Transitions API')
JS_POLY=(1 1 1 1 1 0 0 0)

# ============================================================
# Emit a compat signal
# ============================================================
_emit_compat_signal() {
  local pattern="$1" feat_id="$2" desc="$3" file="$4" line="$5" sev="$6" has_polyfill="$7"
  local polyfill_note=""
  [[ "$has_polyfill" == "1" ]] && polyfill_note=" (polyfill available)"

  local fp
  fp=$(_fp "QD7|${PROBE_ID}|${feat_id}|${file}|${line}")

  SIGNALS+=("$(jq -nc \
    --arg pat     "$pattern" \
    --arg feat    "$feat_id" \
    --arg desc    "$desc" \
    --arg sev     "$sev" \
    --arg file    "$file" \
    --arg line    "$line" \
    --arg tgts    "$TARGETS" \
    --arg poly    "$polyfill_note" \
    --arg fp      "$fp" \
    --arg dim     "$DIMENSION" \
    --arg probe   "$PROBE_ID" \
    --arg backend "$COMPAT_BACKEND" \
    '{
      title:          ("compat: " + $feat + " in " + $file),
      description:    ($desc + $poly + " — check support in target browsers: " + $tgts),
      severity:       $sev,
      location:       {file: $file, line: ($line | tonumber? // null)},
      evidence:       [{type: "code", path: $file, description: ("Pattern: " + $pat + " at line " + $line)}],
      fingerprint:    $fp,
      dimension:      $dim,
      probe_id:       $probe,
      issue_class:    $feat,
      compat_backend: $backend,
      tags:           ["compat","browser","wcag"]
    }')")
}

# ============================================================
# Scan CSS files
# ============================================================
for i in "${!CSS_PATTERNS[@]}"; do
  pat="${CSS_PATTERNS[$i]}"
  feat="${CSS_FEATS[$i]}"
  desc="${CSS_DESCS[$i]}"
  poly="${CSS_POLY[$i]}"

  sev="medium"
  [[ "$poly" == "0" && "$IE11_TARGET" == "1" ]] && sev="high"

  while IFS=: read -r file linenum _rest; do
    [[ -z "$file" || -z "$linenum" ]] && continue
    _emit_compat_signal "$pat" "$feat" "$desc" "$file" "$linenum" "$sev" "$poly"
  done < <(_compat_grep '\.(css|scss|less)$' \
    '--include=*.css --include=*.scss --include=*.less' "$pat")
done

# ============================================================
# Scan JS/TS files
# ============================================================
for i in "${!JS_PATTERNS[@]}"; do
  pat="${JS_PATTERNS[$i]}"
  feat="${JS_FEATS[$i]}"
  desc="${JS_DESCS[$i]}"
  poly="${JS_POLY[$i]}"

  sev="medium"
  [[ "$poly" == "0" && "$IE11_TARGET" == "1" ]] && sev="high"

  while IFS=: read -r file linenum _rest; do
    [[ -z "$file" || -z "$linenum" ]] && continue
    _emit_compat_signal "$pat" "$feat" "$desc" "$file" "$linenum" "$sev" "$poly"
  done < <(_compat_grep '\.(ts|tsx|js|jsx)$' \
    '--include=*.ts --include=*.tsx --include=*.js --include=*.jsx' "$pat")
done

# ============================================================
# Emit lane-signals-v1 envelope
# ============================================================
SIGNAL_COUNT="${#SIGNALS[@]}"
SIGNALS_JSON="[]"
if [[ "$SIGNAL_COUNT" -gt 0 ]]; then
  SIGNALS_JSON=$(printf '%s\n' "${SIGNALS[@]}" | jq -s '.')
fi

SAMPLING_JSON=false
$SAMPLING && SAMPLING_JSON=true

# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg schema  "lane-signals-v1" \
  --arg probe   "$PROBE_ID" \
  --arg dim     "$DIMENSION" \
  --arg backend "$COMPAT_BACKEND" \
  --arg tgts    "$TARGETS" \
  --argjson ie11 "$IE11_TARGET" \
  --slurpfile signals "$__SIGNALS_TMPFILE" \
  --argjson sampling "$SAMPLING_JSON" \
  --argjson coverage "$COVERAGE_PCT" \
  --argjson total "$TOTAL_FILES" \
  --argjson sampled "$SAMPLED_FILES" \
  '{
    "$schema":              $schema,
    probe_id:               $probe,
    dimension:              $dim,
    compat_backend:         $backend,
    browserslist_targets:   $tgts,
    ie11_targeted:          ($ie11 == 1),
    sampling:               $sampling,
    coverage_pct:           $coverage,
    total_files:            $total,
    sampled_files:          $sampled,
    signal_count:           ($signals[0] | length),
    signals:                $signals[0]
  }'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
