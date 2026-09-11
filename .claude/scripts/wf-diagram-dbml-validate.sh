#!/usr/bin/env bash
# wf-diagram-dbml-validate.sh — POST-GATE T2 validator cho DBML files
# Sprint 4 bash delegation
#
# Usage:
#   bash .claude/scripts/wf-diagram-dbml-validate.sh <dbml_file>
#
# Exit codes:
#   0 — PASS
#   1 — FAIL (issues listed)
#   2 — FILE NOT FOUND
#
# Checks (DBML Conventions — SKILL.md §"DBML Conventions"):
#   1. File phải có ít nhất 1 `Project ` block (top-level metadata)
#   2. File phải có ≥1 `Table ` block
#   3. Mỗi Table block phải có ≥1 column (không rỗng)
#   4. Khóa ngoại nên dùng `Ref:` cuối file (KHÔNG inline)
#   5. External tables phải có comment `// External: from <module>`

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPT_NAME="wf-diagram-dbml-validate"
# shellcheck source=./wf-diagram-common.sh
source "$SCRIPTS_DIR/wf-diagram-common.sh"

set -uo pipefail 2>/dev/null || set -u

FILE="${1:?Usage: $0 <dbml_file>}"

if [[ ! -f "$FILE" ]]; then
  log_error "File not found: $FILE"
  exit 2
fi

declare -a errors=()
declare -a warnings=()

# Template mode detection: files containing [ALL_CAPS_PLACEHOLDER] sections (e.g. [TABLE_BLOCKS],
# [MODULE_TABLE_BLOCKS]) are template files. Table blocks are populated at generation time.
# Template mode skips Check 2 (Table count) and Check 3 (empty Table) — emit PASS_WITH_WARNINGS.
is_template=false
if grep -qE '^\[([A-Z_]+_BLOCKS?|[A-Z_]+_GROUPS?|REFERENCES|[A-Z_]+_NODES?)\]$' "$FILE"; then
  is_template=true
fi

# Check 1: Project block
project_count=$(grep -cE '^Project[[:space:]]' "$FILE" 2>/dev/null) || true
project_count="${project_count:-0}"
if [[ "$project_count" -eq 0 ]]; then
  errors+=("Missing 'Project' block — DBML phải có top-level Project { ... }")
fi

# Check 2: Table blocks
table_count=$(grep -cE '^Table[[:space:]]' "$FILE" 2>/dev/null) || true
table_count="${table_count:-0}"
if [[ "$table_count" -eq 0 ]] && [[ "$is_template" = false ]]; then
  errors+=("Missing 'Table' blocks — DBML phải có ≥1 Table")
fi

# Check 3: Each Table có ≥1 column
# Skip in template mode (Table blocks are placeholders, not real content)
empty_tables=()
if [[ "$table_count" -gt 0 ]] && [[ "$is_template" = false ]]; then
  awk '
    /^Table[[:space:]]+[A-Za-z0-9_]+/ {
      # Extract table name (sau Table, trước { hoặc as)
      name=$2
      gsub(/[{].*/, "", name)
      gsub(/[[:space:]]/, "", name)
      current=name
      cols=0
      in_table=1
      next
    }
    in_table && /^}/ {
      if (cols==0) print current
      in_table=0
      current=""
      cols=0
      next
    }
    in_table {
      # Skip empty lines, comments (//), Note, Indexes block headers
      line=$0
      gsub(/^[[:space:]]+/, "", line)
      if (line=="" || line ~ /^\/\// || line ~ /^Note:/ || line ~ /^Indexes/) next
      if (line ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[a-zA-Z]/) cols++
    }
  ' "$FILE" > /tmp/dbml-empty-tables.$$ 2>/dev/null

  while IFS= read -r tbl; do
    [[ -z "$tbl" ]] && continue
    empty_tables+=("$tbl")
  done < /tmp/dbml-empty-tables.$$
  rm -f /tmp/dbml-empty-tables.$$
fi

if [[ ${#empty_tables[@]} -gt 0 ]]; then
  errors+=("Empty Table blocks (no columns): ${empty_tables[*]}")
fi

# Check 4: Inline foreign keys (warning, not error)
# Pattern: column_name type [ref:...] — DBML cho phép nhưng SKILL.md prefer Ref: cuối file
inline_refs=$(grep -cE '\[ref:' "$FILE" 2>/dev/null) || true
inline_refs="${inline_refs:-0}"
if [[ "$inline_refs" -gt 0 ]]; then
  warnings+=("Found $inline_refs inline [ref:...] — convention prefer 'Ref:' block ở cuối file")
fi

# Check 5: External tables phải có comment
# Pattern: nếu có "external" trong Table name nhưng không có "// External:" comment trước/trong block
external_tables=$(grep -E '^Table[[:space:]]+[A-Za-z0-9_]*[Ee]xternal' "$FILE" | wc -l) || true
external_tables="${external_tables:-0}"
if [[ "$external_tables" -gt 0 ]]; then
  external_comments=$(grep -cE '^[[:space:]]*//[[:space:]]*External:' "$FILE") || true
  external_comments="${external_comments:-0}"
  if [[ "$external_comments" -lt "$external_tables" ]]; then
    warnings+=("Found $external_tables external Table(s) nhưng chỉ có $external_comments '// External:' comment(s)")
  fi
fi

# Result
if [[ ${#errors[@]} -eq 0 ]]; then
  if [[ "$is_template" = true ]]; then
    warnings+=("Template file — Table blocks are placeholders (populated at generation time)")
  fi
  if [[ ${#warnings[@]} -eq 0 ]]; then
    echo "PASS: $FILE (project=$project_count, tables=$table_count)"
    exit 0
  else
    echo "PASS_WITH_WARNINGS: $FILE (project=$project_count, tables=$table_count)"
    for w in "${warnings[@]}"; do
      echo "  ! $w"
    done
    exit 0
  fi
fi

echo "FAIL: $FILE"
for e in "${errors[@]}"; do
  echo "  - $e"
done
if [[ ${#warnings[@]} -gt 0 ]]; then
  for w in "${warnings[@]}"; do
    echo "  ! $w"
  done
fi
exit 1
