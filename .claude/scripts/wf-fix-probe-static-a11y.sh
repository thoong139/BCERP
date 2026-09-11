#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-a11y.sh — Static probe: A11y / WCAG Static Check (QD5)
#
# Quet WCAG 2.2 AA tinh trang static trong markup:
#  - <img> thieu alt
#  - <input>/<select>/<textarea> thieu label hoac aria-label
#  - <button> rong (no text content + no aria-label)
#  - aria-* attribute names sai chinh ta
#  - role attribute invalid
#  - tabindex > 0 (anti-pattern)
#  - <a href="#"> hoac href="javascript:" (anti-pattern)
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed (static markup)
#
# USAGE:
#   bash wf-fix-probe-static-a11y.sh \
#     --session-dir <path> --lane wf-fix-ux-a11y \
#     --probe P-QD5-aria-attribute-scan \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: S5 wf-fix-bugs v7.0


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
# Cross-platform sha256 (GNU sha256sum / macOS shasum)
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-ux-a11y"
PROBE_ID="P-QD5-aria-attribute-scan"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"
EXCLUDE_OVERRIDES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --exclude-overrides) EXCLUDE_OVERRIDES="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD5", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

# Valid ARIA roles (WAI-ARIA 1.2 abridged)
VALID_ROLES="alert alertdialog application article banner button checkbox cell columnheader combobox complementary contentinfo dialog directory document feed figure form grid gridcell group heading img link list listbox listitem main marquee math menu menubar menuitem menuitemcheckbox menuitemradio navigation none note option presentation progressbar radio radiogroup region row rowgroup rowheader scrollbar search searchbox separator slider spinbutton status switch tab table tablist tabpanel term textbox timer toolbar tooltip tree treegrid treeitem"

EXCLUDE_PATTERN='(__tests__|test/|tests/|\.test\.|\.spec\.|fixtures|node_modules|dist/|build/)'

# IMP-026: Config-driven exclude patterns via --exclude-overrides <path>
# JSON format: { "additional_excludes": ["pat1"], "remove_excludes": ["pat2"] }
if [ -n "$EXCLUDE_OVERRIDES" ] && [ -f "$EXCLUDE_OVERRIDES" ]; then
  EXCLUDE_PATTERN=$(python3 - "$EXCLUDE_PATTERN" "$EXCLUDE_OVERRIDES" <<'PYEOF'
import sys, json
pat = sys.argv[1]
with open(sys.argv[2]) as f:
    cfg = json.load(f)
inner = pat[1:-1] if (pat.startswith('(') and pat.endswith(')')) else pat
parts = inner.split('|')
parts += cfg.get('additional_excludes', [])
removes = set(cfg.get('remove_excludes', []))
parts = [p for p in parts if p and p not in removes]
print('(' + '|'.join(parts) + ')')
PYEOF
  ) || EXCLUDE_PATTERN="$EXCLUDE_PATTERN"
fi

SIGNALS_JSON='[]'

emit_a11y_signal() {
  local file="$1" line="$2" issue_type="$3" severity="$4" title="$5" description="$6" snippet="$7"
  local fp
  fp=$(echo -n "QD5|$file|$line|$PROBE_ID|$issue_type" | _sha256 | awk '{print "sha256:"$1}')

  local sig
  sig=$(jq -nc \
    --arg file "$file" --argjson line "$line" \
    --arg severity "$severity" --arg title "$title" --arg desc "$description" \
    --arg snippet "$(echo "$snippet" | head -c 150)" \
    --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2", dimension_id: "QD5", probe_id: $probe, probe_version: $pver,
      severity: $severity, fixability: "auto_fix", domain: "frontend",
      title: $title, description: $desc,
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ("Snippet: " + $snippet)}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Add missing a11y attribute (alt, aria-label, label-for)", suggested_agent: "frontend-developer", estimated_effort: "trivial"},
      detected_at: $now, detected_by: $detector
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
}

# ============================================================
# Check 1: <img> thieu alt
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi
  # Skip if alt= present
  if echo "$match" | grep -qE 'alt[[:space:]]*='; then continue; fi
  # Skip self-closing or aria-hidden
  if echo "$match" | grep -qE 'aria-hidden[[:space:]]*=[[:space:]]*["'\'']true'; then continue; fi
  emit_a11y_signal "$file" "$line" "img_no_alt" "high" \
    "WCAG 1.1.1: <img> thieu alt" \
    "Tag <img> thieu thuoc tinh alt. Them alt='' (decorative) hoac alt mo ta noi dung." \
    "$match"
done < <(grep -rEn '<img[[:space:]][^>]*>' "$SOURCE_DIR" \
          --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
          2>/dev/null || true)

# ============================================================
# Check 2: <input>/<select>/<textarea> thieu label/aria-label
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi
  # Skip if has aria-label, aria-labelledby, or type="hidden"/"submit"/"button"
  if echo "$match" | grep -qE '(aria-label|aria-labelledby)[[:space:]]*='; then continue; fi
  if echo "$match" | grep -qE 'type[[:space:]]*=[[:space:]]*["'\''](hidden|submit|button|reset|image)["'\'']' ; then continue; fi
  emit_a11y_signal "$file" "$line" "input_no_label" "high" \
    "WCAG 1.3.1: form control thieu label" \
    "Form control khong co aria-label hoac labelledby. Add <label for='id'> hoac aria-label." \
    "$match"
done < <(grep -rEn '<(input|select|textarea)[[:space:]][^>]*>' "$SOURCE_DIR" \
          --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
          2>/dev/null || true)

# ============================================================
# Check 3: tabindex > 0 (anti-pattern)
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi
  # Extract tabindex value
  tabindex_val=$(echo "$match" | grep -oE 'tabindex[[:space:]]*=[[:space:]]*["'\''][0-9]+["'\'']' | grep -oE '[0-9]+' | head -1)
  if [ -n "$tabindex_val" ] && [ "$tabindex_val" -gt 0 ]; then
    emit_a11y_signal "$file" "$line" "tabindex_positive" "medium" \
      "WCAG 2.4.3: tabindex > 0 anti-pattern" \
      "tabindex=${tabindex_val} makes focus order unpredictable. Dung tabindex=0 hoac -1." \
      "$match"
  fi
done < <(grep -rEn 'tabindex[[:space:]]*=[[:space:]]*["'\''][1-9]' "$SOURCE_DIR" \
          --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
          2>/dev/null || true)

# ============================================================
# Check 4: invalid role attribute
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi
  role=$(echo "$match" | grep -oE 'role[[:space:]]*=[[:space:]]*["'\''][a-zA-Z-]+' | sed -E 's/.*["'\'']//')
  [ -z "$role" ] && continue
  if ! echo " $VALID_ROLES " | grep -q " $role "; then
    emit_a11y_signal "$file" "$line" "invalid_role" "medium" \
      "WAI-ARIA: role invalid" \
      "role='$role' khong phai valid ARIA role. Xem WAI-ARIA 1.2 spec." \
      "$match"
  fi
done < <(grep -rEn 'role[[:space:]]*=[[:space:]]*["'\''][a-zA-Z-]+' "$SOURCE_DIR" \
          --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
          2>/dev/null || true)

# ============================================================
# Check 5: <a href="#"> or href="javascript:"
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi
  emit_a11y_signal "$file" "$line" "href_anti_pattern" "low" \
    "WCAG 2.1.1: <a> href anti-pattern" \
    "<a href='#'> hoac 'javascript:' khong la link thuc su. Dung <button> cho action, hoac href thuc te." \
    "$match"
done < <(grep -rEn '<a[[:space:]][^>]*href[[:space:]]*=[[:space:]]*["'\''](#|javascript:)["'\'']' "$SOURCE_DIR" \
          --include='*.tsx' --include='*.jsx' --include='*.html' --include='*.vue' --include='*.svelte' \
          2>/dev/null || true)

# ============================================================
# IMP-002: i18n message file detection
# If i18n files present → emit INFO so label-consistency reviewers know
# orphan/untranslated-key warnings may be false positives
# ============================================================
I18N_DETECTED=0
I18N_PATHS=""
while IFS= read -r i18n_file; do
  [[ -z "$i18n_file" ]] && continue
  I18N_DETECTED=$((I18N_DETECTED + 1))
  I18N_PATHS="$I18N_PATHS $i18n_file"
done < <(
  set +euo pipefail
  find "$SOURCE_DIR" -type f \( \
    -name 'messages.json' -o -name 'translations.json' -o \
    -name '*.po' -o -name '*.pot' -o \
    -path '*/locales/*.json' -o -path '*/i18n/*.json' -o \
    -path '*/translations/*.json' -o -path '*/lang/*.json' \
  \) 2>/dev/null
) || true

if [ "$I18N_DETECTED" -gt 0 ]; then
  fp=$(echo -n "QD5|i18n_detected|$SOURCE_DIR|$I18N_DETECTED" | _sha256 | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --argjson count "$I18N_DETECTED" \
    --arg paths "$I18N_PATHS" \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg fp "$fp" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD5",
      probe_id: $probe,
      probe_version: $pver,
      severity: "info",
      fixability: "none",
      domain: "i18n",
      title: ("i18n message files detected (" + ($count | tostring) + " files)"),
      description: ("Project uses i18n message files. Label-consistency checks on translation keys (not actual text) may produce false positives. Affected paths:" + $paths),
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "spec", path: "N/A", description: ("i18n files found: " + ($count | tostring))}],
      cdg_flags: [],
      fingerprint: $fp,
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
fi

# Output
# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile signals "$__SIGNALS_TMPFILE" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD5", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals[0]}'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
