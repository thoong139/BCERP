#!/usr/bin/env bash
# wf-diagram-mermaid-validate.sh — POST-GATE T2 validator cho Mermaid diagrams
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/wf-diagram-mermaid-validate.sh <md_file>
#
# Exit codes:
#   0 — PASS (no issues found)
#   1 — FAIL (issues found, listed on stderr/stdout)
#   2 — FILE NOT FOUND or unreadable
#
# Checks (Mermaid 8.8.0 Safety Rules — SKILL.md §"Mermaid 8.8.0 Safety Rules"):
#   1. ```mermaid block phải tồn tại
#   2. Em-dash `—` (U+2014) trong label
#   3. Single quote 'label' trong [...] / (...)
#   4. subgraph multi-word không quote
#   5. <br/> trong shape không quote
#   6. Colon `:` trong node label không quote
#   7. & chain: A & B & C --> D
#   8. () trong label không quote
#   9. Reserved keywords làm node ID (END, class, style)
#  10. Emoji + parens chưa quote: [(🗄️ PG)]
#
# Best-effort grep heuristics. False positives possible — caller có thể skip
# warnings nếu false positive (vd: Mermaid 9+ syntax không break).

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="wf-diagram-mermaid-validate"
# shellcheck source=./wf-diagram-common.sh
source "$SCRIPTS_DIR/wf-diagram-common.sh"

set -uo pipefail 2>/dev/null || set -u

FILE="${1:?Usage: $0 <md_file>}"

if [[ ! -f "$FILE" ]]; then
  log_error "File not found: $FILE"
  exit 2
fi

# Read all mermaid blocks; if zero, fail
# grep -c always prints number; exit 1 when 0 matches → catch with set +e behavior
mermaid_block_count=$(grep -c '^```mermaid' "$FILE" 2>/dev/null) || true
mermaid_block_count="${mermaid_block_count:-0}"
if [[ "$mermaid_block_count" -eq 0 ]]; then
  echo "FAIL: $FILE missing \`\`\`mermaid block"
  exit 1
fi

declare -a errors=()

# Extract content giữa ```mermaid và ``` thành 1 buffer tạm để check
# (POST-GATE T2 chỉ check syntax trong mermaid blocks, không check prose Markdown)
tmp_mermaid=$(mktemp)
# Filter out %% comment lines: comments are not rendered → cannot cause parse issues.
# Prevents false positives on examples like `%% E1[(Database)]` in template files.
awk '/^```mermaid$/{flag=1; next} /^```$/{flag=0} flag && !/^[[:space:]]*%%/' "$FILE" > "$tmp_mermaid" 2>/dev/null || true

# Check 1: Em-dash trong label [...]  (U+2014)
# Pattern dùng ANSI-C quote $'...' để byte literal U+2014 (e2 80 94) — tránh -P locale issue.
EM_DASH_PATTERN=$'\[[^]]*\xe2\x80\x94[^]]*\]'
if grep -nE "$EM_DASH_PATTERN" "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE "$EM_DASH_PATTERN" "$tmp_mermaid" | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[em-dash trong label] dòng $lines — thay '—' bằng '--' hoặc '-'")
fi

# Check 2: Single quote trong label [...] hoặc (...)
# Pattern: A['label'] hoặc A('label') — quote đơn không được Mermaid 8.8.0 support đầy đủ
if grep -nE "\[[^]]*'[^']*'[^]]*\]|\([^)]*'[^']*'[^)]*\)" "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE "\[[^]]*'[^']*'[^]]*\]|\([^)]*'[^']*'[^)]*\)" "$tmp_mermaid" | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[single quote trong label] dòng $lines — bỏ quote hoặc dùng backtick")
fi

# Check 3: subgraph multi-word không quote
# Pattern: `subgraph ID Word1 Word2` — multi token không có quotes "..."
# Bỏ qua: subgraph ID["Display"] hoặc subgraph "ID"
if grep -nE '^[[:space:]]*subgraph[[:space:]]+[A-Za-z0-9_]+[[:space:]]+[A-Za-z0-9_]' "$tmp_mermaid" \
   | grep -vE 'subgraph[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\["' \
   | grep -vE 'subgraph[[:space:]]+"' >/dev/null 2>&1; then
  lines=$(grep -nE '^[[:space:]]*subgraph[[:space:]]+[A-Za-z0-9_]+[[:space:]]+[A-Za-z0-9_]' "$tmp_mermaid" \
          | grep -vE 'subgraph[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\["' \
          | grep -vE 'subgraph[[:space:]]+"' \
          | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[subgraph multi-word không quote] dòng $lines — dùng subgraph ID[\"Display Name\"]")
fi

# Check 4: <br/> trong shape không quote — pattern [text<br/>text] (không có quote)
if grep -nE '\[[^"]*<br/?>[^"]*\]' "$tmp_mermaid" >/dev/null 2>&1; then
  # Loại bỏ trường hợp đã quote
  candidates=$(grep -nE '\[[^"]*<br/?>[^"]*\]' "$tmp_mermaid")
  if [[ -n "$candidates" ]]; then
    lines=$(echo "$candidates" | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    errors+=("[<br/> trong shape không quote] dòng $lines — wrap label trong [\"...\"]")
  fi
fi

# Check 5: Colon `:` trong node label không quote
# Pattern: A[key: value] (không có quote) — Mermaid hiểu nhầm là edge label
# Loại trừ classDef, style, click, %% comment (classDiagram class member syntax không match `[...]`)
COLON_PATTERN='[[:space:]]*[A-Za-z0-9_]+\[[^"]*:[^"]*\]'
if grep -nE "$COLON_PATTERN" "$tmp_mermaid" \
   | grep -vE '^[0-9]+:[[:space:]]*(classDef|style|click|%%)' >/dev/null 2>&1; then
  lines=$(grep -nE "$COLON_PATTERN" "$tmp_mermaid" \
          | grep -vE '^[0-9]+:[[:space:]]*(classDef|style|click|%%)' \
          | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[colon trong label không quote] dòng $lines — wrap A[\"key: value\"]")
fi

# Check 6: & chain — `A & B & C --> D` (Mermaid 8.8.0 fragile)
if grep -nE '[A-Za-z0-9_]+[[:space:]]*&[[:space:]]*[A-Za-z0-9_]+[[:space:]]*&' "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE '[A-Za-z0-9_]+[[:space:]]*&[[:space:]]*[A-Za-z0-9_]+[[:space:]]*&' "$tmp_mermaid" \
          | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[& chain] dòng $lines — tách thành nhiều dòng riêng A --> D, B --> D, C --> D")
fi

# Check 7: () trong label không quote — pattern [text (note)] không có "
if grep -nE '\[[^"]*\([^)]*\)[^"]*\]' "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE '\[[^"]*\([^)]*\)[^"]*\]' "$tmp_mermaid" | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[() trong label không quote] dòng $lines — wrap A[\"text (note)\"]")
fi

# Check 8: Reserved keyword làm node ID (END, class, style — case-sensitive)
# Pattern: ^END[\s\[(] hoặc edge target END
# class/style cũng là keyword nhưng valid trong classDef → chỉ check standalone
if grep -nE '(^|[[:space:]])END([[:space:]]*\[|[[:space:]]*\(|[[:space:]]*-->|[[:space:]]*$)' "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE '(^|[[:space:]])END([[:space:]]*\[|[[:space:]]*\(|[[:space:]]*-->|[[:space:]]*$)' "$tmp_mermaid" \
          | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[reserved keyword 'END' làm node ID] dòng $lines — đổi tên: ENDPT hoặc END_NODE")
fi

# Check 9: Emoji + parens không quote: [(🗄️ PG)] hoặc [(emoji label)]
# Pattern: [(...)] với non-ASCII byte trong label — dùng ANSI-C class [^"\x00-\x7f]
EMOJI_PAREN_PATTERN=$'\[\([^"]*[^\x01-\x7f][^)]*\)\]'
if grep -nE "$EMOJI_PAREN_PATTERN" "$tmp_mermaid" >/dev/null 2>&1; then
  lines=$(grep -nE "$EMOJI_PAREN_PATTERN" "$tmp_mermaid" | head -3 | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
  errors+=("[emoji trong shape () không quote] dòng $lines — dùng [(\"PG\")] hoặc bỏ emoji")
fi

rm -f "$tmp_mermaid" 2>/dev/null

# Result
if [[ ${#errors[@]} -eq 0 ]]; then
  echo "PASS: $FILE ($mermaid_block_count mermaid block(s))"
  exit 0
fi

echo "FAIL: $FILE"
for e in "${errors[@]}"; do
  echo "  - $e"
done
exit 1
