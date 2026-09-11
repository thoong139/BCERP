#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-deprecated.sh — Static probe: Deprecated API Detection (QD7)
#
# Phat hien deprecated browser/library/Node APIs trong source code:
#  - Browser APIs (document.execCommand, MutationEvent, ...)
#  - React deprecated lifecycle (componentWillMount, ...)
#  - Node.js deprecated (new Buffer, ...)
#  - CSS deprecated properties
#  - Deprecated package dependencies (moment, request, ...)
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed (static, results stable per code state)
#
# USAGE:
#   bash wf-fix-probe-static-deprecated.sh \
#     --session-dir <path> --lane wf-fix-compat --probe P-QD7-deprecated-api-usage \
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
LANE="wf-fix-compat"
PROBE_ID="P-QD7-deprecated-api-usage"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"
PACKAGE_JSON="package.json"
EXCLUDE_OVERRIDES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --package-json) PACKAGE_JSON="$2"; shift 2 ;;
    --exclude-overrides) EXCLUDE_OVERRIDES="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# Deprecated API patterns
# Format: "label|severity|replacement|regex"
# ============================================================
PATTERNS=(
  "document.execCommand('copy')|high|navigator.clipboard.writeText|document\\.execCommand\\(\\s*['\"]copy['\"]"
  "document.execCommand('paste')|high|navigator.clipboard.readText|document\\.execCommand\\(\\s*['\"]paste['\"]"
  "document.execCommand|medium|specific Clipboard/Selection API|document\\.execCommand\\("
  "componentWillMount|high|useEffect or componentDidMount|componentWillMount\\b"
  "componentWillReceiveProps|high|getDerivedStateFromProps|componentWillReceiveProps\\b"
  "componentWillUpdate|high|getSnapshotBeforeUpdate|componentWillUpdate\\b"
  "ReactDOM.render|high|createRoot().render()|ReactDOM\\.render\\("
  "findDOMNode|medium|refs|findDOMNode\\("
  "new Buffer()|critical|Buffer.alloc / Buffer.from|new Buffer\\("
  "MutationEvent|high|MutationObserver|MutationEvent\\b"
  "document.createEvent|low|new CustomEvent / new Event|document\\.createEvent\\("
  "event.returnValue|medium|event.preventDefault()|event\\.returnValue\\b"
  "event.cancelBubble|medium|event.stopPropagation()|event\\.cancelBubble\\b"
  "navigator.platform|low|navigator.userAgentData|navigator\\.platform\\b"
  "document.all|high|modern DOM APIs|document\\.all\\b"
  "showModalDialog|critical|<dialog> element|window\\.showModalDialog\\("
  "punycode (Node)|medium|userland punycode|require\\(['\"]punycode['\"]\\)"
)

# Deprecated CSS patterns
CSS_PATTERNS=(
  "zoom CSS|low|transform: scale()|^[[:space:]]*zoom[[:space:]]*:"
  "-webkit-box-flex|low|flex|-webkit-box-flex[[:space:]]*:"
  "word-break: break-word|low|overflow-wrap: anywhere|word-break[[:space:]]*:[[:space:]]*break-word"
)

# Deprecated packages (check package.json)
DEPRECATED_PACKAGES=(
  "moment|medium|date-fns or dayjs"
  "request|high|node-fetch or axios or undici"
  "node-uuid|low|uuid"
  "jade|medium|pug"
  "babel-preset-es2015|medium|@babel/preset-env"
  "tslint|medium|eslint with @typescript-eslint"
  "core-js@2|medium|core-js@3"
)

EXCLUDE_PATTERN='(node_modules|\.git/|dist/|build/|\.next/|coverage/)'

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

# Fix #7 v8.0: Temp file accumulation tranh "Argument list too long"
MCV3_TMP="$SESSION_DIR/.probe-deprecated-tmp"
mkdir -p "$MCV3_TMP" 2>/dev/null || { echo "ERROR: cannot create tmp dir $MCV3_TMP" >&2; exit 1; }
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
trap 'rm -rf "$MCV3_TMP"' EXIT
: > "$SIGNALS_TMP"
SIG_NUM=0

# ============================================================
# Probe dispatch: nếu PROBE_ID là P-QD7-i18n-key-audit thì
# bỏ qua toàn bộ deprecated-api logic và chỉ chạy i18n audit.
# WHY: script được tái dụng cho cả hai probe trong cùng lane QD7
# để tránh tạo file riêng chỉ cho 1 khối logic nhỏ.
# ============================================================
if [ "$PROBE_ID" = "P-QD7-i18n-key-audit" ] && [ "$PROFILE" = "quick" ]; then
  # Quick profile bỏ qua i18n key audit (tốn I/O, cần jq path traversal)
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "v1.0" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD7", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now, signals: []}'
  exit 0
fi

# ============================================================
# Step 1: Quet deprecated code APIs
# Fix #7 v8.0: Combined regex — single grep scan thay O(N) scans.
# ============================================================
if [ -d "$SOURCE_DIR" ]; then
  # Build combined regex from all API patterns
  COMBINED_API_REGEX=""
  for entry in "${PATTERNS[@]}"; do
    IFS='|' read -r _label _severity _replacement regex <<< "$entry"
    if [ -z "$COMBINED_API_REGEX" ]; then
      COMBINED_API_REGEX="$regex"
    else
      COMBINED_API_REGEX="$COMBINED_API_REGEX|$regex"
    fi
  done

  API_TMP=$(mktemp)
  grep -rEn -e "$COMBINED_API_REGEX" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$API_TMP" || true

  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue

    if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then
      continue
    fi

    # Classify: find which pattern matched (lightweight — single text line)
    found_label=""; found_severity=""; found_replacement=""
    for entry in "${PATTERNS[@]}"; do
      IFS='|' read -r label severity replacement regex <<< "$entry"
      if echo "$match" | grep -qE -e "$regex"; then
        found_label="$label"; found_severity="$severity"; found_replacement="$replacement"
        break
      fi
    done
    [ -z "$found_label" ] && continue

    SIG_NUM=$((SIG_NUM + 1))
    fp=$(echo -n "QD7|$file|$line|$PROBE_ID|deprecated_api|$found_label" | _sha256 | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg label "$found_label" \
      --arg severity "$found_severity" \
      --arg replacement "$found_replacement" \
      --arg file "$file" \
      --argjson line "$line" \
      --arg probe "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" \
      --arg snippet "$(echo "$match" | head -c 100)" \
      --arg fp "$fp" \
      --arg now "$(iso_now)" \
      --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD7",
        probe_id: $probe,
        probe_version: $pver,
        severity: $severity,
        fixability: "agent_fix",
        domain: "frontend",
        title: ("Deprecated API: " + $label),
        description: ("Su dung " + $label + " — replacement: " + $replacement),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ("Snippet: " + $snippet)}],
        cdg_flags: [],
        fingerprint: $fp,
        remediation: {suggested_action: ("Replace with: " + $replacement), suggested_agent: "frontend-developer", estimated_effort: "small"},
        detected_at: $now,
        detected_by: $detector
      }')
    printf '%s\n' "$sig" >> "$SIGNALS_TMP"
  done < "$API_TMP"
  rm -f "$API_TMP"

  # CSS deprecated — Fix #7: combined regex, single grep
  COMBINED_CSS_REGEX=""
  for entry in "${CSS_PATTERNS[@]}"; do
    IFS='|' read -r _label _severity _replacement regex <<< "$entry"
    if [ -z "$COMBINED_CSS_REGEX" ]; then
      COMBINED_CSS_REGEX="$regex"
    else
      COMBINED_CSS_REGEX="$COMBINED_CSS_REGEX|$regex"
    fi
  done

  CSS_TMP=$(mktemp)
  grep -rEn -e "$COMBINED_CSS_REGEX" "$SOURCE_DIR" \
    --include='*.css' --include='*.scss' --include='*.less' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$CSS_TMP" || true

  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi

    found_label=""; found_severity=""; found_replacement=""
    for entry in "${CSS_PATTERNS[@]}"; do
      IFS='|' read -r label severity replacement regex <<< "$entry"
      if echo "$match" | grep -qE -e "$regex"; then
        found_label="$label"; found_severity="$severity"; found_replacement="$replacement"
        break
      fi
    done
    [ -z "$found_label" ] && continue

    SIG_NUM=$((SIG_NUM + 1))
    fp=$(echo -n "QD7|$file|$line|$PROBE_ID|deprecated_css|$found_label" | _sha256 | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg label "$found_label" --arg severity "$found_severity" --arg replacement "$found_replacement" \
      --arg file "$file" --argjson line "$line" \
      --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2", dimension_id: "QD7", probe_id: $probe, probe_version: $pver,
        severity: $severity, fixability: "auto_fix", domain: "frontend",
        title: ("Deprecated CSS: " + $label),
        description: ("Su dung " + $label + " — replacement: " + $replacement),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ("Snippet: " + $snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: ("Replace with: " + $replacement), suggested_agent: "frontend-developer", estimated_effort: "trivial"},
        detected_at: $now, detected_by: $detector
      }')
    printf '%s\n' "$sig" >> "$SIGNALS_TMP"
  done < "$CSS_TMP"
  rm -f "$CSS_TMP"
fi

# ============================================================
# Step 2: Check deprecated packages trong package.json
# ============================================================
if [ -f "$PACKAGE_JSON" ] && jq -e '.' "$PACKAGE_JSON" >/dev/null 2>&1; then
  for entry in "${DEPRECATED_PACKAGES[@]}"; do
    IFS='|' read -r pkg severity replacement <<< "$entry"

    found=$(jq -r --arg p "$pkg" '
      (.dependencies // {}) + (.devDependencies // {})
      | to_entries[] | select(.key == $p) | "\(.key)@\(.value)"
    ' "$PACKAGE_JSON")

    if [ -n "$found" ]; then
      fp=$(echo -n "QD7|$PACKAGE_JSON|0|$PROBE_ID|deprecated_pkg|$pkg" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg pkg "$pkg" --arg severity "$severity" --arg replacement "$replacement" \
        --arg version "$found" --arg file "$PACKAGE_JSON" \
        --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD7", probe_id: $probe, probe_version: $pver,
          severity: $severity, fixability: "agent_fix", domain: "general",
          title: ("Deprecated package: " + $pkg),
          description: ("Package " + $version + " da deprecated. Migrate sang: " + $replacement),
          location: {file: $file, line: null, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: ("Found: " + $version)}],
          cdg_flags: ["CDG-DEPS-DOWN"], fingerprint: $fp,
          remediation: {suggested_action: ("Replace " + $pkg + " with: " + $replacement), suggested_agent: "developer", estimated_effort: "medium"},
          detected_at: $now, detected_by: $detector
        }')
      SIG_NUM=$((SIG_NUM + 1))
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    fi
  done
fi

# ============================================================
# IMP-002: P-QD7-i18n-locale-check
# Grep for hardcoded Date(), currency symbols, and locale strings
# that should come from config / Intl API instead of being hardcoded.
# ============================================================
I18N_PATTERNS=(
  "new Date() no-locale|medium|Use Intl.DateTimeFormat or date-fns with locale|new\\s+Date\\(\\s*\\)\\s*\\.toLocaleDateString\\(\\s*\\)|new\\s+Date\\(\\s*\\)\\.toLocaleString\\(\\s*\\)"
  "hardcoded locale en-US|medium|Use project locale config instead of hardcoded en-US|['\"]en-US['\"]"
  "hardcoded locale vi-VN|medium|Use project locale config instead of hardcoded vi-VN|['\"]vi-VN['\"]"
  "hardcoded locale ja-JP|medium|Use project locale config instead of hardcoded ja-JP|['\"]ja-JP['\"]"
  "hardcoded locale zh-CN|medium|Use project locale config instead of hardcoded zh-CN|['\"]zh-CN['\"]"
  "hardcoded USD currency|medium|Use Intl.NumberFormat with currency option|['\$][0-9]|USD['\"]|\\.toFixed\\(2\\)[^;]"
  "hardcoded VND currency|medium|Use Intl.NumberFormat with currency option|[0-9]\\s*đ\\b|đồng\\b|VND['\"]"
  "toLocaleString no args|low|Pass locale argument: toLocaleString(locale)|\.toLocaleString\\(\\s*\\)"
  "toLocaleDateString no args|low|Pass locale argument: toLocaleDateString(locale)|\.toLocaleDateString\\(\\s*\\)"
  "toLocaleTimeString no args|low|Pass locale argument: toLocaleTimeString(locale)|\.toLocaleTimeString\\(\\s*\\)"
)

if [ -d "$SOURCE_DIR" ]; then
  EXCLUDE_I18N='(node_modules|dist/|build/|\.test\.|\.spec\.|__tests__)'
  # Fix #7 v8.0: Separate greps per i18n pattern (each ~0.5s on apps/).
  # Combined regex produces 10k+ matches and jq-per-signal overhead dominates.
  # Per-pattern cap (200 matches) prevents 6000+ jq spawns for broad patterns.
  # Bash parameter expansion used instead of cut/echo to avoid process spawns.
  MAX_I18N_PER_PATTERN=50
  for pattern_entry in "${I18N_PATTERNS[@]}"; do
    IFS='|' read -r label severity replacement regex <<< "$pattern_entry"
    i18n_count=0

    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      i18n_count=$((i18n_count + 1))
      if [ "$i18n_count" -gt "$MAX_I18N_PER_PATTERN" ]; then break; fi

      file="${match%%:*}"
      rest="${match#*:}"
      line="${rest%%:*}"
      [[ "$file" =~ $EXCLUDE_I18N ]] && continue

      SIG_NUM=$((SIG_NUM + 1))
      fp=$(echo -n "QD7|$file|$line|$PROBE_ID|i18n_hardcode|$label" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg label "$label" --arg severity "$severity" --arg replacement "$replacement" \
        --arg file "$file" --argjson line "$line" \
        --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" \
        --arg now "$(iso_now)" \
        --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2",
          dimension_id: "QD7",
          probe_id: $probe, probe_version: $pver,
          severity: $severity, fixability: "code-change", domain: "i18n",
          title: ("i18n hardcode: " + $label),
          description: ("Hardcoded locale-sensitive value detected: " + $label + ". Recommendation: " + $replacement + ". Found in " + $file + " line " + ($line | tostring) + "."),
          location: {file: $file, line: $line, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: ("Hardcoded i18n value at line " + ($line | tostring))}],
          cdg_flags: [], fingerprint: $fp, registry_refs: {},
          detected_at: $now, detected_by: $detector
        }')
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    done < <(
      set +euo pipefail
      grep -rEn -e "$regex" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
        --include='*.vue' --include='*.py' --include='*.java' --include='*.cs' \
        --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
        "$SOURCE_DIR" 2>/dev/null
    ) || true
  done
fi

# ============================================================
# IMP-NEW: P-QD7-i18n-key-audit — Cross-validate i18n keys
# Detect t('key') calls where key is not defined in translation files.
# Profile: standard+ (skip on quick — được xử lý ở probe dispatch trên)
# WHY: keys dùng t('x.y.z') nhưng thiếu trong vi.json → render fail hoặc
# hiển thị raw key string; cần cross-reference giữa code và translation files.
# ============================================================
if [ "$PROBE_ID" = "P-QD7-i18n-key-audit" ] && [ -d "$SOURCE_DIR" ]; then
  MESSAGES_FILE=""
  # Tìm translation file theo thứ tự ưu tiên (Next.js messages/ pattern)
  for candidate in \
      "${SOURCE_DIR}messages/vi.json" \
      "${SOURCE_DIR}../messages/vi.json" \
      "${SOURCE_DIR}../public/messages/vi.json" \
      "messages/vi.json" "public/messages/vi.json" \
      "${SOURCE_DIR}messages/en.json" "messages/en.json"; do
    if [ -f "$candidate" ]; then
      MESSAGES_FILE="$candidate"
      break
    fi
  done

  if [ -n "$MESSAGES_FILE" ]; then
    # Thu thập tất cả i18n keys được dùng trong code: t('key.path') hoặc t("key.path")
    USED_KEYS_TMP=$(mktemp)
    grep -rEoh --include='*.tsx' --include='*.ts' --include='*.jsx' --include='*.js' \
      "t\(['\"][a-zA-Z][a-zA-Z0-9._-]{3,}['\"]" "$SOURCE_DIR" 2>/dev/null \
      | grep -oE "['\"][a-zA-Z][a-zA-Z0-9._-]+['\"]" | tr -d "'\"" | sort -u \
      > "$USED_KEYS_TMP" || true

    # Collect all defined keys from translation file
    DEFINED_KEYS_TMP=$(mktemp)
    jq -r 'paths(type == "string") | join(".")' "$MESSAGES_FILE" 2>/dev/null | sort -u \
      > "$DEFINED_KEYS_TMP" || true

    # Cross-reference: keys used in code but not defined in translation file
    if [ -s "$USED_KEYS_TMP" ] && [ -s "$DEFINED_KEYS_TMP" ]; then
      while IFS= read -r missing_key; do
        [ -z "$missing_key" ] && continue
        # Find which files use this key for location info
        file_ref=$(grep -rl --include='*.tsx' --include='*.ts' "$missing_key" "$SOURCE_DIR" 2>/dev/null | head -1)
        line_ref=$(grep -n "$missing_key" "$file_ref" 2>/dev/null | head -1 | cut -d: -f1)
        line_ref="${line_ref:-1}"

        fp=$(echo -n "QD7|$file_ref|$line_ref|P-QD7-i18n-key-audit|missing_key|$missing_key" \
          | _sha256 | awk '{print "sha256:"$1}')
        sig=$(jq -nc \
          --arg key "$missing_key" \
          --arg file "${file_ref:-$SOURCE_DIR}" \
          --argjson line "${line_ref:-1}" \
          --arg fp "$fp" --arg now "$(iso_now)" \
          --arg mf "$MESSAGES_FILE" \
          '{
            "$schema": "signal-v2",
            dimension_id: "QD7",
            probe_id: "P-QD7-i18n-key-audit",
            probe_version: "v1.0",
            severity: "high",
            fixability: "agent_fix",
            domain: "i18n",
            title: ("Missing i18n key: " + $key),
            description: ("Key \"" + $key + "\" duoc goi qua t() trong code nhung KHONG co trong translation file " + $mf + ". Render se fail hoac hien thi raw key string."),
            location: {file: $file, line: $line, column: null, selector: null, url: null},
            evidence: [{type: "code", path: $file, description: ("Missing key: " + $key + " in " + $mf)}],
            cdg_flags: [],
            fingerprint: $fp,
            remediation: {
              suggested_action: ("Them key \"" + $key + "\" vao file " + $mf),
              suggested_agent: "frontend-developer",
              estimated_effort: "small"
            },
            detected_at: $now,
            detected_by: "wf-fix-compat/P-QD7-i18n-key-audit"
          }')
        SIG_NUM=$((SIG_NUM + 1))
        printf '%s\n' "$sig" >> "$SIGNALS_TMP"
      done < <(comm -23 "$USED_KEYS_TMP" "$DEFINED_KEYS_TMP" 2>/dev/null || true)
    fi

    rm -f "$USED_KEYS_TMP" "$DEFINED_KEYS_TMP"
  fi
fi

# Output (dung --slurpfile tranh "Argument list too long")
jq -n \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --argjson signal_count "$SIG_NUM" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD7", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}'

exit 0
