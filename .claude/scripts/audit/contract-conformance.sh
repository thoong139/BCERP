#!/usr/bin/env bash
# contract-conformance.sh — Lớp 2 của MCV3 Quality Audit
#
# Kiểm tra tính nhất quán giữa:
#   A) Bidirectional cross-skill symmetry (producer ↔ consumer trong _contract.json)
#   B) registry_scope.fields_owned so với CORE-006 table trong .claude/rules/00-core.md §4a
#   D) Template path existence (outputs.*[].template phải resolve tới file thật)
#   F) Evals coverage (mỗi skill có evals/evals.json với ≥3 cases)
#   G) Contract schema self-check (required top-level fields theo CLAUDE.md)
#
# Output:
#   docs/audit/work/contract-conformance.json    — machine-readable findings
#   docs/audit/reports/contract-conformance.md   — human-readable report
#
# Exit codes: 0 = no critical, 1 = critical findings present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SKILLS_DIR="$ROOT_DIR/.claude/skills/workflow"
DF_DIR="$ROOT_DIR/.claude/doc-framework"
CORE_RULE="$ROOT_DIR/.claude/rules/00-core.md"
OUT_JSON="$ROOT_DIR/docs/audit/work/contract-conformance.json"
OUT_MD="$ROOT_DIR/docs/audit/reports/contract-conformance.md"

mkdir -p "$(dirname "$OUT_JSON")" "$(dirname "$OUT_MD")"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# -------- Collect contracts --------
CONTRACTS=( "$SKILLS_DIR"/*/_contract.json )
SKILL_NAMES=()
for c in "${CONTRACTS[@]}"; do
  SKILL_NAMES+=( "$(jq -r .skill "$c" | tr -d '\r')" )
done

# Start findings array
echo '[]' > "$TMP/findings.json"

add_finding() {
  local severity="$1" check="$2" skill="$3" msg="$4" evidence="${5:-}"
  jq --arg s "$severity" --arg c "$check" --arg sk "$skill" --arg m "$msg" --arg e "$evidence" \
    '. + [{severity:$s, check:$c, skill:$sk, message:$m, evidence:$e}]' \
    "$TMP/findings.json" > "$TMP/findings.json.new" && mv "$TMP/findings.json.new" "$TMP/findings.json"
}

# ============================================================
# CHECK G — Contract schema self-check
# ============================================================
for c in "${CONTRACTS[@]}"; do
  sk=$(jq -r .skill "$c" | tr -d '\r')
  for field in '$schema' skill version phase description; do
    # shellcheck disable=SC2016
    val=$(jq -r --arg f "$field" '.[$f] // empty' "$c")
    if [[ -z "$val" ]]; then
      add_finding "CRITICAL" "G-schema" "$sk" "Missing required field: $field" "$c"
    fi
  done
  if ! jq -e '.registry_scope.fields_owned | type == "array"' "$c" >/dev/null; then
    add_finding "CRITICAL" "G-schema" "$sk" "registry_scope.fields_owned missing or not array" "$c"
  fi
  if ! jq -e '.outputs.working | type == "array"' "$c" >/dev/null; then
    add_finding "HIGH" "G-schema" "$sk" "outputs.working missing or not array" "$c"
  fi
done

# ============================================================
# CHECK A — Bidirectional cross-skill symmetry
# ============================================================
# Build index: skill_name -> contract path
declare -A CONTRACT_OF
for c in "${CONTRACTS[@]}"; do
  CONTRACT_OF[$(jq -r .skill "$c" | tr -d '\r')]="$c"
done

for c in "${CONTRACTS[@]}"; do
  producer=$(jq -r .skill "$c" | tr -d '\r')
  # Loop through each consumer in produces_for
  consumers=$(jq -r '(.cross_skill_contracts.produces_for // {}) | keys[]' "$c" 2>/dev/null | tr -d '\r' || true)
  for consumer in $consumers; do
    # Get the list of paths producer promises to consumer
    paths=$(jq -r --arg k "$consumer" '.cross_skill_contracts.produces_for[$k][]? // empty' "$c" | tr -d '\r')
    # Consumer must exist
    if [[ -z "${CONTRACT_OF[$consumer]:-}" ]]; then
      add_finding "HIGH" "A-symmetry" "$producer" "Declares produces_for → '$consumer' but no such skill contract exists" "$c"
      continue
    fi
    cc="${CONTRACT_OF[$consumer]}"
    # Each path must appear in consumer.consumes_from[producer] OR consumer.inputs[].path
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      in_consumes=$(jq -r --arg pr "$producer" --arg p "$p" \
        '(.cross_skill_contracts.consumes_from[$pr] // []) | index($p)' "$cc")
      in_inputs=$(jq -r --arg p "$p" \
        '(.inputs // []) | map(.path) | index($p)' "$cc")
      if [[ "$in_consumes" == "null" && "$in_inputs" == "null" ]]; then
        add_finding "HIGH" "A-symmetry" "$producer" \
          "Promises '$p' to '$consumer' but consumer contract does not declare it in consumes_from[$producer] nor inputs[]" \
          "$c → $cc"
      fi
    done <<< "$paths"
  done

  # Reverse: each consumes_from[X] entry → X must list this skill as consumer
  producers_cited=$(jq -r '(.cross_skill_contracts.consumes_from // {}) | keys[]' "$c" 2>/dev/null | tr -d '\r' || true)
  for upstream in $producers_cited; do
    if [[ -z "${CONTRACT_OF[$upstream]:-}" ]]; then
      add_finding "HIGH" "A-symmetry" "$producer" "Declares consumes_from ← '$upstream' but no such skill contract exists" "$c"
      continue
    fi
    uc="${CONTRACT_OF[$upstream]}"
    paths=$(jq -r --arg k "$upstream" '.cross_skill_contracts.consumes_from[$k][]? // empty' "$c" | tr -d '\r')
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      found=$(jq -r --arg cn "$producer" --arg p "$p" \
        '(.cross_skill_contracts.produces_for[$cn] // []) | index($p)' "$uc")
      if [[ "$found" == "null" ]]; then
        add_finding "HIGH" "A-symmetry" "$producer" \
          "Claims to consume '$p' from '$upstream' but upstream does not promise it in produces_for[$producer]" \
          "$c ← $uc"
      fi
    done <<< "$paths"
  done
done

# ============================================================
# CHECK B — registry_scope vs CORE-006 table
# ============================================================
# Extract CORE-006 table rows ONLY from §4a section (between "### 4a" and "### 4b")
awk '
  /^### 4a\./ { in_section=1; next }
  /^### 4b\./ { in_section=0 }
  in_section && /^\| `\/wf-/ { print }
' "$CORE_RULE" | tr -d '\r' > "$TMP/core-006-raw.txt"

# Parse each row into skill + comma-separated fields
# Format example: | `/wf-brainstorm` | `project`, `departments[]`, `interface_type` (initial seed — ...) |
> "$TMP/core-006.tsv"
while IFS= read -r line; do
  # extract skill name: first token matching /wf-xxx between backticks in first column
  skill_name=$(printf '%s' "$line" | awk -F '|' '{print $2}' | grep -oE '/wf-[a-z-]+' | head -n1 | sed 's|^/||')
  [[ -z "$skill_name" ]] && continue
  # Skip the "(legacy flow)" variant row — it's a duplicate of base skill with different context
  if echo "$line" | grep -q '(legacy flow)'; then continue; fi
  # extract fields cell (second column), take only backticked tokens
  fields_cell=$(printf '%s' "$line" | awk -F '|' '{print $3}')
  fields=$(printf '%s' "$fields_cell" | grep -oE '`[^`]+`' | tr -d '`' | sed 's/\[\]//g' | tr '\n' ',' | sed 's/,$//' || true)
  printf '%s\t%s\n' "$skill_name" "$fields" >> "$TMP/core-006.tsv"
done < "$TMP/core-006-raw.txt"

# For each skill, compare contract.registry_scope.fields_owned[] with CORE-006 row
for c in "${CONTRACTS[@]}"; do
  sk=$(jq -r .skill "$c" | tr -d '\r')
  contract_fields=$(jq -r '.registry_scope.fields_owned // [] | .[]' "$c" | tr -d '\r' | sort -u || true)
  rule_line=$(awk -F'\t' -v s="$sk" '$1==s {print $2; exit}' "$TMP/core-006.tsv" || true)
  if [[ -z "$rule_line" ]]; then
    # Some skills legitimately not in table (e.g., wf-preflight read-only, wf-prepare-deployment, wf-legacy-*)
    # Only flag if contract declares NON-EMPTY fields_owned
    if [[ -n "$contract_fields" ]]; then
      add_finding "MEDIUM" "B-registry-scope" "$sk" \
        "Contract declares fields_owned but CORE-006 table does not list this skill" \
        "contract=[$(echo $contract_fields | tr '\n' ' ')]"
    fi
    continue
  fi
  rule_fields=$(printf '%s' "$rule_line" | tr ',' '\n' | sed '/^$/d' | sort -u || true)
  missing_in_contract=$(comm -23 <(printf '%s\n' "$rule_fields") <(printf '%s\n' "$contract_fields") 2>/dev/null | sed '/^$/d' | tr '\n' ',' | sed 's/,$//' || true)
  extra_in_contract=$(comm -13 <(printf '%s\n' "$rule_fields") <(printf '%s\n' "$contract_fields") 2>/dev/null | sed '/^$/d' | tr '\n' ',' | sed 's/,$//' || true)
  if [[ -n "$missing_in_contract" ]]; then
    add_finding "HIGH" "B-registry-scope" "$sk" \
      "CORE-006 lists fields not in contract.registry_scope.fields_owned" \
      "missing=[$missing_in_contract]"
  fi
  if [[ -n "$extra_in_contract" ]]; then
    add_finding "HIGH" "B-registry-scope" "$sk" \
      "Contract declares fields not listed in CORE-006 table" \
      "extra=[$extra_in_contract]"
  fi
done

# ============================================================
# CHECK D — Template path existence
# ============================================================
for c in "${CONTRACTS[@]}"; do
  sk=$(jq -r .skill "$c" | tr -d '\r')
  skill_dir="$(dirname "$c")"
  # Collect templates from outputs.docs[] and outputs.working[]
  tmpls=$(jq -r '[(.outputs.docs // []), (.outputs.working // [])] | flatten | map(select(.template != null and .template != "")) | .[] | .template' "$c" | tr -d '\r')
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    # Skip wildcards
    [[ "$t" == *"*"* ]] && continue
    # Two lookup strategies:
    #   (1) relative to skill folder (templates/xxx.json)
    #   (2) relative to .claude/doc-framework
    resolved=""
    if [[ -f "$skill_dir/$t" ]]; then resolved="$skill_dir/$t"; fi
    if [[ -z "$resolved" && -f "$DF_DIR/$t" ]]; then resolved="$DF_DIR/$t"; fi
    if [[ -z "$resolved" ]]; then
      add_finding "HIGH" "D-template" "$sk" "Template path does not resolve to a file" "$t"
    fi
  done <<< "$tmpls"
done

# ============================================================
# CHECK F — Evals coverage
# ============================================================
for c in "${CONTRACTS[@]}"; do
  sk=$(jq -r .skill "$c" | tr -d '\r')
  skill_dir="$(dirname "$c")"
  evals="$skill_dir/evals/evals.json"
  if [[ ! -f "$evals" ]]; then
    add_finding "HIGH" "F-evals" "$sk" "Missing evals/evals.json (CLAUDE.md requires ≥3 cases)" "$evals"
    continue
  fi
  if ! jq -e '.' "$evals" >/dev/null 2>&1; then
    add_finding "HIGH" "F-evals" "$sk" "evals.json is not valid JSON" "$evals"
    continue
  fi
  n=$(jq -r '(.cases // .tests // .evals // [] | length)' "$evals" 2>/dev/null || echo 0)
  if [[ "$n" -lt 3 ]]; then
    add_finding "MEDIUM" "F-evals" "$sk" "Only $n eval case(s) — requirement is ≥3" "$evals"
  fi
done

# ============================================================
# Build summary
# ============================================================
TOTAL=$(jq 'length' "$TMP/findings.json")
CRIT=$(jq '[.[] | select(.severity=="CRITICAL")] | length' "$TMP/findings.json")
HIGH=$(jq '[.[] | select(.severity=="HIGH")] | length' "$TMP/findings.json")
MED=$(jq '[.[] | select(.severity=="MEDIUM")] | length' "$TMP/findings.json")

# Write final JSON
jq -n \
  --slurpfile findings "$TMP/findings.json" \
  --arg generated_at "$(date -Iseconds 2>/dev/null || date)" \
  --arg total "$TOTAL" --arg crit "$CRIT" --arg high "$HIGH" --arg med "$MED" \
  --argjson skills "$(printf '%s\n' "${SKILL_NAMES[@]}" | jq -R . | jq -s .)" \
  '{
     generated_at: $generated_at,
     tool: "contract-conformance.sh",
     version: "1.0.0",
     scope: "MCV3 Layer-2 contract conformance audit",
     skills_checked: $skills,
     summary: {
       total_findings: ($total|tonumber),
       critical: ($crit|tonumber),
       high: ($high|tonumber),
       medium: ($med|tonumber)
     },
     findings: $findings[0]
   }' > "$OUT_JSON"

# ============================================================
# Write Markdown report
# ============================================================
{
  echo "# MCV3 Contract Conformance Report"
  echo
  echo "**Generated:** $(date -Iseconds 2>/dev/null || date)"
  echo "**Scope:** Layer-2 audit — cross-skill contract integrity"
  echo "**Tool:** \`.claude/scripts/audit/contract-conformance.sh\` v1.0.0"
  echo
  echo "## Summary"
  echo
  echo "| Metric | Count |"
  echo "|---|---|"
  echo "| Skills audited | ${#SKILL_NAMES[@]} |"
  echo "| Total findings | $TOTAL |"
  echo "| 🔴 CRITICAL | $CRIT |"
  echo "| 🟠 HIGH | $HIGH |"
  echo "| 🟡 MEDIUM | $MED |"
  echo
  echo "## Checks performed"
  echo
  echo "| ID | Check | Source of truth |"
  echo "|---|---|---|"
  echo "| G | Contract schema self-check | CLAUDE.md §Creating New Skills |"
  echo "| A | Bidirectional cross-skill symmetry | each _contract.json cross_skill_contracts |"
  echo "| B | registry_scope vs CORE-006 | .claude/rules/00-core.md §4a |"
  echo "| D | Template path existence | filesystem |"
  echo "| F | Evals coverage (≥3 cases) | CLAUDE.md §Creating New Skills |"
  echo
  echo "## Findings by severity"
  echo
  for sev in CRITICAL HIGH MEDIUM; do
    n=$(jq --arg s "$sev" '[.[] | select(.severity==$s)] | length' "$TMP/findings.json")
    if [[ "$n" -gt 0 ]]; then
      echo "### $sev ($n)"
      echo
      echo "| # | Check | Skill | Message | Evidence |"
      echo "|---|---|---|---|---|"
      jq -r --arg s "$sev" \
        '[.[] | select(.severity==$s)] | to_entries[] | "| \(.key+1) | \(.value.check) | \(.value.skill) | \(.value.message) | `\(.value.evidence)` |"' \
        "$TMP/findings.json"
      echo
    fi
  done
  if [[ "$TOTAL" -eq 0 ]]; then
    echo
    echo "✅ **No conformance issues found.**"
  fi
  echo
  echo "## Next steps"
  echo
  echo "1. Triage CRITICAL first, then HIGH."
  echo "2. For each finding, open matching _contract.json or rules/00-core.md and fix per-finding."
  echo "3. Re-run \`.claude/scripts/audit/contract-conformance.sh\` until clean."
  echo "4. Proceed to Layer 3 (Behavioral Eval harness) after conformance ≤ MEDIUM."
  echo
  echo "---"
  echo "Machine-readable: [\`docs/audit/work/contract-conformance.json\`](../work/contract-conformance.json)"
} > "$OUT_MD"

echo
echo "Contract Conformance Audit — complete"
echo "  Findings: $TOTAL ($CRIT crit / $HIGH high / $MED med)"
echo "  JSON: $OUT_JSON"
echo "  MD:   $OUT_MD"
echo

if [[ "$CRIT" -gt 0 ]]; then
  exit 1
fi
exit 0
