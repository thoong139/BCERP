#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-cta.sh — Static probe: CTA Keyword Detection (QD1, locale-aware)
#
# IMP-002: Locale-aware CTA detection using _shared/locales/ dictionary.
# IMP-005: MAX_PAGES per profile (quick=10, standard=30, deep=100, exhaustive=300).
#          Emits WARN signal when scan is truncated. Override via --max-pages or
#          --threshold-overrides '{"max_pages":N}'.
# Scans UI source files for Call-To-Action elements (buttons, links, submit controls)
# and reports each detected CTA as a signal for req-registry coverage verification.
#
# Supported locales: en | vi | ja | zh  (default: en)
# Supported UI file types: .tsx .jsx .vue .html .svelte .njk .hbs
#
# USAGE:
#   bash wf-fix-probe-static-cta.sh \
#     --session-dir <path> --lane wf-fix-functional --probe P-QD1-cta-keyword-scan \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/] [--locale vi] \
#     [--max-pages 20] [--threshold-overrides '{"max_pages":50}']
#
# EXIT CODES: 0 success, 1 error
#
# Author: IMP-002 Stage 3 / IMP-005 Stage 3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-cta-keyword-scan"
PROBE_VERSION="v1.1"
PROFILE="standard"
SOURCE_DIR="src/"
LOCALE="en"
MAX_PAGES_CLI=-1
THRESHOLD_OVERRIDES="{}"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane)        LANE="$2";        shift 2 ;;
    --probe)       PROBE_ID="$2";    shift 2 ;;
    --profile)     PROFILE="$2";     shift 2 ;;
    --source-dir)  SOURCE_DIR="$2";  shift 2 ;;
    --locale)      LOCALE="$2";      shift 2 ;;
    --max-pages)   MAX_PAGES_CLI="$2"; shift 2 ;;
    --threshold-overrides) THRESHOLD_OVERRIDES="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# IMP-005: Resolve MAX_PAGES from profile / override / CLI
# ============================================================
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
PROFILES_JSON="$REPO_ROOT/.claude/skills/workflow/_shared/profiles/profiles.json"

_cta_profile_threshold() {
  local key="$1" default="$2"
  if [ -f "$PROFILES_JSON" ]; then
    local val
    val=$(jq -r --arg p "$PROFILE" --arg k "$key" \
      '.profiles[$p].thresholds[$k] // empty' "$PROFILES_JSON" 2>/dev/null || true)
    [ -n "$val" ] && [ "$val" != "null" ] && echo "$val" && return
  fi
  echo "$default"
}

MAX_PAGES=$(_cta_profile_threshold "max_pages" 30)
# --threshold-overrides wins over profile
_ov=$(jq -r '.max_pages // empty' <<< "$THRESHOLD_OVERRIDES" 2>/dev/null || true)
[ -n "$_ov" ] && [ "$_ov" != "null" ] && MAX_PAGES="$_ov"
# explicit --max-pages wins over everything
[ "$MAX_PAGES_CLI" -ge 0 ] 2>/dev/null && MAX_PAGES="$MAX_PAGES_CLI"

# ============================================================
# Locate locale dictionary
# ============================================================
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
LOCALES_DIR="$REPO_ROOT/.claude/skills/workflow/_shared/locales"
LOCALE_FILE="$LOCALES_DIR/$LOCALE/cta-keywords.json"

# Fallback to English if locale file not found
if [ ! -f "$LOCALE_FILE" ]; then
  echo "WARN: locale file not found for '$LOCALE', falling back to 'en'" >&2
  LOCALE="en"
  LOCALE_FILE="$LOCALES_DIR/en/cta-keywords.json"
fi

if [ ! -f "$LOCALE_FILE" ]; then
  echo "ERROR: CTA locale dictionary not found at $LOCALE_FILE (IMP-002 required)" >&2
  exit 1
fi

# ============================================================
# Temporary files (created before pattern extraction)
# ============================================================
MCV3_TMP=""
if [ -n "$SESSION_DIR" ]; then
  MCV3_TMP="$SESSION_DIR/.probe-cta-tmp"
  mkdir -p "$MCV3_TMP" 2>/dev/null || true
else
  MCV3_TMP="$(mktemp -d -t probe-cta-XXXXXX)"
fi
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
: > "$SIGNALS_TMP"
trap 'rm -rf "$MCV3_TMP"' EXIT

# ============================================================
# Build fixed-string patterns from locale file (text field)
# Uses grep -F for reliable Unicode matching across platforms
# ============================================================
CTA_TEXTS_FILE="$MCV3_TMP/cta-texts.txt"
jq -r '.cta_patterns[].text' "$LOCALE_FILE" > "$CTA_TEXTS_FILE"
if [ ! -s "$CTA_TEXTS_FILE" ]; then
  echo "ERROR: no CTA patterns found in $LOCALE_FILE" >&2
  exit 1
fi
PATTERN_COUNT=$(wc -l < "$CTA_TEXTS_FILE")

# ============================================================
# Scan UI source files for CTA patterns
# ============================================================
if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD1", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

UI_EXTS="--include=*.tsx --include=*.jsx --include=*.vue --include=*.html --include=*.svelte --include=*.njk --include=*.hbs"

# ============================================================
# IMP-005: Collect UI files, apply MAX_PAGES limit with WARN
# ============================================================
ALL_UI_FILES_TMP="$MCV3_TMP/ui-files.$$.txt"
: > "$ALL_UI_FILES_TMP"
{
  find "$SOURCE_DIR" -type f \( \
    -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.html' \
    -o -name '*.svelte' -o -name '*.njk' -o -name '*.hbs' \
  \) 2>/dev/null | sort
} > "$ALL_UI_FILES_TMP" || true

TOTAL_UI_FILES=$(wc -l < "$ALL_UI_FILES_TMP" | tr -d ' ')
TRUNCATED=false
if [ "$TOTAL_UI_FILES" -gt "$MAX_PAGES" ]; then
  TRUNCATED=true
  SCANNED_UI_FILES_TMP="$MCV3_TMP/ui-files-scanned.$$.txt"
  head -n "$MAX_PAGES" "$ALL_UI_FILES_TMP" > "$SCANNED_UI_FILES_TMP"
else
  SCANNED_UI_FILES_TMP="$ALL_UI_FILES_TMP"
fi

# Emit truncation WARN signal if needed
if $TRUNCATED; then
  fp_trunc=$(echo -n "QD1|max_pages_truncated|$MAX_PAGES|$TOTAL_UI_FILES|$PROBE_ID" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --argjson max "$MAX_PAGES" \
    --argjson total "$TOTAL_UI_FILES" \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" \
    --arg fp "$fp_trunc" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD1",
      probe_id: $probe,
      probe_version: $pver,
      severity: "warn",
      fixability: "config_change",
      domain: "cta",
      title: ("MAX_PAGES truncation: scanned " + ($max | tostring) + "/" + ($total | tostring) + " UI files (profile=" + $profile + ")"),
      description: ("CTA probe truncated scan to " + ($max | tostring) + " files (MAX_PAGES for profile=" + $profile + "). Total UI files: " + ($total | tostring) + ". Use --profile deep/exhaustive or --max-pages N to increase limit."),
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "spec", path: "N/A", description: ("Scanned " + ($max | tostring) + " of " + ($total | tostring) + " UI files")}],
      cdg_flags: [],
      fingerprint: $fp,
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }' >> "$SIGNALS_TMP"
fi

# Case-insensitive search for CTA patterns in UI files (from scanned list only)
while IFS= read -r match; do
  [[ -z "$match" ]] && continue

  # Parse grep output: file:line:content
  file=$(echo "$match" | cut -d: -f1)
  line=$(echo "$match" | cut -d: -f2)
  context=$(echo "$match" | cut -d: -f3- | xargs 2>/dev/null || echo "")

  # Extract matched CTA text: find which pattern matched via grep -F
  matched_text=$(LANG=C.UTF-8 grep -oiF -f "$CTA_TEXTS_FILE" <<< "$context" | head -1) || true
  [[ -z "$matched_text" ]] && matched_text="[cta]"

  # Find category from locale file by matching text (case-insensitive)
  lc_matched=$(echo "$matched_text" | tr '[:upper:]' '[:lower:]') || true
  category=$(jq -r --arg t "$lc_matched" '
    .cta_patterns[] | select((.text | ascii_downcase) == $t) | .category
  ' "$LOCALE_FILE" | head -1) || true
  [[ -z "$category" ]] && category="general"

  fp=$(echo -n "QD1|$file|$line|$PROBE_ID|cta_detected|$matched_text" | _sha256 | awk '{print "sha256:"$1}')

  jq -nc \
    --arg file "$file" \
    --argjson line "$line" \
    --arg matched "$matched_text" \
    --arg category "$category" \
    --arg locale "$LOCALE" \
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
      severity: "info",
      fixability: "none",
      domain: "cta",
      title: ("CTA detected: “" + $matched + "” (" + $category + ", " + $locale + ")"),
      description: ("Call-To-Action element “" + $matched + "” [category=" + $category + ", locale=" + $locale + "] detected in " + $file + ". Verify CTA is registered in req-registry.json feature spec."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ("CTA keyword found at line " + ($line | tostring))}],
      cdg_flags: [],
      fingerprint: $fp,
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }' >> "$SIGNALS_TMP"
done < <(
  set +euo pipefail
  # IMP-005: grep only scanned files (MAX_PAGES limited list), not full dir
  if [ -s "$SCANNED_UI_FILES_TMP" ]; then
    xargs -a "$SCANNED_UI_FILES_TMP" \
      LANG=C.UTF-8 grep -Fin --line-number \
      -f "$CTA_TEXTS_FILE" \
      2>/dev/null || true
  fi
) || true

# ============================================================
# If no CTAs detected and no source found, emit skip signal
# ============================================================
if [ ! -s "$SIGNALS_TMP" ]; then
  jq -nc \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg locale "$LOCALE" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD1",
      probe_id: $probe,
      probe_version: $pver,
      severity: "info",
      fixability: "none",
      domain: "cta",
      title: ("CTA probe: no CTA elements found (locale=" + $locale + ")"),
      description: "No CTA keywords detected in UI source files. If app has CTAs, check locale configuration or add locale dictionary.",
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "spec", path: "N/A", description: "SPEC-ONLY-PROBE-SKIP: no CTA patterns matched"}],
      cdg_flags: [],
      fingerprint: "spec-only-probe-skip-cta",
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }' >> "$SIGNALS_TMP"
fi

# ============================================================
# Output JSON wrapper (schema lane-signals-v1)
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
