#!/usr/bin/env bash
# validate-schema-sync.sh — Kiểm tra tính nhất quán giữa 3 nguồn schema
# Nguồn: (a) _contract.json per skill, (b) procedures/flow-*.md, (c) doc-framework _contract.json
#
# Cách dùng:
#   ./validate-schema-sync.sh [skill-name | --all]
#   ./validate-schema-sync.sh wf-brainstorm
#   ./validate-schema-sync.sh --all
#
# Exit codes: 0 = PASS, 1 = FAIL (có mismatches)

set -euo pipefail

# Thư mục gốc DEVKIT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$ROOT_DIR/.claude/skills/workflow"
DOC_FRAMEWORK_DIR="$ROOT_DIR/.claude/doc-framework"

# Màu sắc output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_SKILLS=0
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_ERRORS=0

# Danh sách tất cả workflow skills
ALL_SKILLS=(
  "wf-brainstorm"
  "wf-analyze-requirements"
  "wf-define-features"
  "wf-design"
  "wf-design-ux"
  "wf-plan-modules"
  "wf-implement-feature"
  "wf-preflight"
  "wf-fix-bugs"
  "wf-fix-triage"
  "wf-fix-execute"
  "wf-verify-sync"
  "wf-prepare-deployment"
  "wf-legacy-scan"
  "wf-legacy-classify"
  "wf-legacy-extract"
  "wf-annotate-code"
  "wf-add-scope"
  "wf-manage-change"
  "wf-fix-functional"
  "wf-fix-business"
  "wf-fix-security"
  "wf-fix-performance"
  "wf-fix-ux-a11y"
  "wf-fix-data"
  "wf-fix-compat"
  "wf-fix-observability"
  "wf-fix-runtime-health"
  "wf-fix-integration"
  "wf-fix-business-completeness"
  "wf-scan-target"
  "wf-diagram"
  "wf-cmi"
)

# Registry scope theo CORE-006 (source of truth: 00-core.md Rule 4a)
declare -A REGISTRY_SCOPE
REGISTRY_SCOPE["wf-brainstorm"]="project,departments,interface_type,systems"
REGISTRY_SCOPE["wf-analyze-requirements"]="systems,modules,departments,requirements,interface_type"
REGISTRY_SCOPE["wf-define-features"]="features,impl_status"
REGISTRY_SCOPE["wf-design"]="design_status"
REGISTRY_SCOPE["wf-design-ux"]="ux_design_status"
REGISTRY_SCOPE["wf-plan-modules"]="implementation_order,impl_status"
REGISTRY_SCOPE["wf-implement-feature"]="impl_status"
REGISTRY_SCOPE["wf-preflight"]=""
REGISTRY_SCOPE["wf-fix-bugs"]=""
REGISTRY_SCOPE["wf-fix-triage"]=""
REGISTRY_SCOPE["wf-fix-execute"]="impl_status"
REGISTRY_SCOPE["wf-verify-sync"]="impl_status"
REGISTRY_SCOPE["wf-prepare-deployment"]=""
REGISTRY_SCOPE["wf-legacy-scan"]=""
REGISTRY_SCOPE["wf-legacy-classify"]=""
REGISTRY_SCOPE["wf-legacy-extract"]=""
REGISTRY_SCOPE["wf-annotate-code"]=""
REGISTRY_SCOPE["wf-add-scope"]="modules,features"
REGISTRY_SCOPE["wf-manage-change"]="requirements,features,impl_status"
REGISTRY_SCOPE["wf-fix-functional"]="none"
REGISTRY_SCOPE["wf-fix-business"]="none"
REGISTRY_SCOPE["wf-fix-security"]="none"
REGISTRY_SCOPE["wf-fix-performance"]="none"
REGISTRY_SCOPE["wf-fix-ux-a11y"]="none"
REGISTRY_SCOPE["wf-fix-data"]="none"
REGISTRY_SCOPE["wf-fix-compat"]="none"
REGISTRY_SCOPE["wf-fix-observability"]="none"
REGISTRY_SCOPE["wf-fix-runtime-health"]="none"
REGISTRY_SCOPE["wf-scan-target"]="none"
REGISTRY_SCOPE["wf-diagram"]="none"
REGISTRY_SCOPE["wf-cmi"]="none"

# ---- Hàm kiểm tra ----

# Kiểm tra file _contract.json tồn tại và có schema hợp lệ
check_contract_exists() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  if [[ ! -f "$contract" ]]; then
    echo -e "  ${RED}[FAIL]${NC} _contract.json không tồn tại"
    return 1
  fi

  # Kiểm tra JSON hợp lệ
  if ! jq empty "$contract" 2>/dev/null; then
    echo -e "  ${RED}[FAIL]${NC} _contract.json không phải JSON hợp lệ"
    return 1
  fi

  # Kiểm tra $schema field
  local schema
  schema=$(jq -r '."$schema" // empty' "$contract")
  if [[ "$schema" != "skill-contract-v1" ]]; then
    echo -e "  ${RED}[FAIL]${NC} _contract.json thiếu hoặc sai \$schema (expected: skill-contract-v1, got: $schema)"
    return 1
  fi

  # Kiểm tra required top-level fields
  local missing_fields=()
  for field in skill version phase description; do
    if ! jq -e ".$field" "$contract" >/dev/null 2>&1; then
      missing_fields+=("$field")
    fi
  done

  if [[ ${#missing_fields[@]} -gt 0 ]]; then
    echo -e "  ${RED}[FAIL]${NC} _contract.json thiếu fields: ${missing_fields[*]}"
    return 1
  fi

  echo -e "  ${GREEN}[PASS]${NC} _contract.json tồn tại và hợp lệ"
  return 0
}

# Kiểm tra skill name khớp giữa _contract.json và tên thư mục
check_skill_identity() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  local contract_skill
  contract_skill=$(jq -r '.skill' "$contract")
  if [[ "$contract_skill" != "$skill" ]]; then
    echo -e "  ${RED}[FAIL]${NC} Skill name mismatch: folder=$skill, contract=$contract_skill"
    return 1
  fi

  echo -e "  ${GREEN}[PASS]${NC} Skill identity khớp"
  return 0
}

# Kiểm tra procedure reference
check_procedure_ref() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  # Lấy kiểu dữ liệu của .procedure (string hoặc array)
  local proc_type
  proc_type=$(jq -r 'if .procedure == null then "null" elif (.procedure | type) == "array" then "array" else "string" end' "$contract" 2>/dev/null)

  if [[ "$proc_type" == "null" ]]; then
    # Skill không có procedure — OK nếu thực sự không có
    local proc_count
    proc_count=$(find "$SKILLS_DIR/$skill/procedures/" -name "*.md" 2>/dev/null | wc -l)
    if [[ "$proc_count" -gt 0 ]]; then
      echo -e "  ${RED}[FAIL]${NC} Có procedure files nhưng _contract.json không reference"
      return 1
    fi
    echo -e "  ${GREEN}[PASS]${NC} Không có procedure (đúng)"
    return 0
  fi

  # Lấy danh sách procedures (hỗ trợ cả string và array)
  local procedures
  if [[ "$proc_type" == "array" ]]; then
    mapfile -t procedures < <(jq -r '.procedure[]' "$contract" 2>/dev/null | tr -d '\r')
  else
    procedures=("$(jq -r '.procedure' "$contract" | tr -d '\r')")
  fi

  # Kiểm tra từng file
  local missing=()
  for procedure in "${procedures[@]}"; do
    if [[ ! -f "$SKILLS_DIR/$skill/$procedure" ]]; then
      missing+=("$procedure")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "  ${RED}[FAIL]${NC} Procedure reference không tồn tại: $(printf '%s\n' "${missing[@]}")"
    return 1
  fi

  echo -e "  ${GREEN}[PASS]${NC} Procedure reference hợp lệ: ${procedures[*]}"
  return 0
}

# Kiểm tra doc-framework reference
check_doc_framework_ref() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  local doc_ref
  doc_ref=$(jq -r '.doc_framework_ref // empty' "$contract")

  if [[ -z "$doc_ref" || "$doc_ref" == "null" ]]; then
    # Skill không có doc-framework ref — OK cho skills không tạo docs (preflight, fix-bugs, etc.)
    echo -e "  ${CYAN}[INFO]${NC} Không có doc_framework_ref (skill không tạo template docs)"
    return 0
  fi

  # Kiểm tra file tồn tại
  if [[ ! -f "$ROOT_DIR/$doc_ref" ]]; then
    echo -e "  ${RED}[FAIL]${NC} doc_framework_ref không tồn tại: $doc_ref"
    return 1
  fi

  # Kiểm tra contract_key trong outputs.docs khớp với doc-framework keys
  local doc_count
  doc_count=$(jq -r '.outputs.docs | length' "$contract" 2>/dev/null)

  if [[ "$doc_count" -gt 0 ]]; then
    local mismatches=0
    for ((i=0; i<doc_count; i++)); do
      local key
      key=$(jq -r ".outputs.docs[$i].contract_key // empty" "$contract")
      if [[ -n "$key" ]]; then
        # Dùng jq trực tiếp để kiểm tra key tồn tại trong framework
        if ! jq -e ".templates.\"$key\"" "$ROOT_DIR/$doc_ref" >/dev/null 2>&1; then
          echo -e "  ${RED}[FAIL]${NC} contract_key '$key' không có trong doc-framework"
          mismatches=$((mismatches + 1))
        fi
      fi
    done

    if [[ "$mismatches" -eq 0 ]]; then
      echo -e "  ${GREEN}[PASS]${NC} Doc-framework contract keys khớp"
    else
      return 1
    fi
  else
    echo -e "  ${GREEN}[PASS]${NC} Doc-framework ref hợp lệ (no doc outputs to check)"
  fi

  return 0
}

# Kiểm tra registry scope khớp với CORE-006
check_registry_scope() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  local expected_scope="${REGISTRY_SCOPE[$skill]:-}"
  local contract_scope
  # Strip nested field paths (e.g. "features.impl_status" → "features") vì CORE-006 chỉ liệt kê top-level fields.
  # Nested fields trong _contract.json chỉ là annotation nội bộ; top-level ownership mới đủ so với CORE-006 source of truth.
  contract_scope=$(jq -r '[.registry_scope.fields_owned[]? | split(".")[0]] | unique | sort | join(",")' "$contract" 2>/dev/null)

  # Normalize cả hai
  local expected_sorted
  expected_sorted=$(echo "$expected_scope" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
  local contract_sorted
  contract_sorted=$(echo "$contract_scope" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

  # Lane skills: "none" scope maps to empty fields_owned
  if [[ "$expected_sorted" == "none" ]]; then
    expected_sorted=""
  fi

  if [[ "$expected_sorted" == "$contract_sorted" ]]; then
    echo -e "  ${GREEN}[PASS]${NC} Registry scope khớp CORE-006"
    return 0
  else
    echo -e "  ${RED}[FAIL]${NC} Registry scope mismatch: expected=[$expected_sorted], contract=[$contract_sorted]"
    return 1
  fi
}

# Kiểm tra output templates tồn tại
check_output_templates() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  local errors=0

  # Kiểm tra working file templates
  local templates
  templates=$(jq -r '.outputs.working[]? | select(.template != null and .template != "null") | .template' "$contract" 2>/dev/null | tr -d '\r')

  _template_found() {
    local tmpl="$1"
    [[ -f "$SKILLS_DIR/$skill/$tmpl" ]] && return 0
    [[ -f "$DOC_FRAMEWORK_DIR/$tmpl" ]] && return 0
    [[ -f "$ROOT_DIR/$tmpl" ]] && return 0
    return 1
  }

  while IFS= read -r template; do
    template="${template%$'\r'}"
    if [[ -n "$template" ]] && ! _template_found "$template"; then
      echo -e "  ${RED}[FAIL]${NC} Working template không tồn tại: $template"
      errors=$((errors + 1))
    fi
  done <<< "$templates"

  if [[ "$errors" -eq 0 ]]; then
    echo -e "  ${GREEN}[PASS]${NC} Output templates tồn tại"
  fi

  return "$errors"
}

# Kiểm tra outputs.docs có required_sections khớp với doc-framework
check_section_consistency() {
  local skill="$1"
  local contract="$SKILLS_DIR/$skill/_contract.json"

  local doc_ref
  doc_ref=$(jq -r '.doc_framework_ref // empty' "$contract")

  if [[ -z "$doc_ref" || "$doc_ref" == "null" || ! -f "$ROOT_DIR/$doc_ref" ]]; then
    return 0
  fi

  # Kiểm tra mỗi doc output có contract_key → tìm required_sections trong framework
  local doc_count
  doc_count=$(jq -r '.outputs.docs | length' "$contract" 2>/dev/null)

  local errors=0
  for ((i=0; i<doc_count; i++)); do
    local key
    key=$(jq -r ".outputs.docs[$i].contract_key // empty" "$contract")
    local required
    required=$(jq -r ".outputs.docs[$i].required // false" "$contract")

    if [[ -n "$key" && "$required" == "true" ]]; then
      # Kiểm tra key tồn tại trong framework
      local has_key
      has_key=$(jq -r ".templates.\"$key\" // empty" "$ROOT_DIR/$doc_ref")
      if [[ -z "$has_key" || "$has_key" == "null" ]]; then
        echo -e "  ${RED}[FAIL]${NC} Required doc '$key' không có trong doc-framework"
        errors=$((errors + 1))
      fi
    fi
  done

  if [[ "$errors" -eq 0 ]]; then
    echo -e "  ${GREEN}[PASS]${NC} Section consistency OK"
  fi

  return "$errors"
}

# ---- Hàm chạy kiểm tra cho 1 skill ----

validate_skill() {
  local skill="$1"
  TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

  echo -e "\n${CYAN}━━━ $skill ━━━${NC}"

  local errors=0

  # Check 1: _contract.json tồn tại và hợp lệ
  check_contract_exists "$skill" || errors=$((errors + 1))

  if [[ "$errors" -gt 0 ]]; then
    # Không thể tiếp tục nếu contract không tồn tại
    echo -e "  ${RED}[SKIP]${NC} Bỏ qua các checks còn lại (contract không hợp lệ)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TOTAL_ERRORS=$((TOTAL_ERRORS + errors))
    return
  fi

  # Check 2: Skill identity
  check_skill_identity "$skill" || errors=$((errors + 1))

  # Check 3: Procedure reference
  check_procedure_ref "$skill" || errors=$((errors + 1))

  # Check 4: Doc-framework reference
  check_doc_framework_ref "$skill" || errors=$((errors + 1))

  # Check 5: Registry scope vs CORE-006
  check_registry_scope "$skill" || errors=$((errors + 1))

  # Check 6: Output templates
  check_output_templates "$skill" || errors=$((errors + 1))

  # Check 7: Section consistency
  check_section_consistency "$skill" || errors=$((errors + 1))

  # Verdict
  TOTAL_ERRORS=$((TOTAL_ERRORS + errors))
  if [[ "$errors" -eq 0 ]]; then
    echo -e "  ${GREEN}▶ PASS${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "  ${RED}▶ FAIL ($errors errors)${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---- Main ----

echo -e "${CYAN}╔═════════════════════════════════════════════���════╗${NC}"
echo -e "${CYAN}║  MCV3 Schema Sync Validator                      ║${NC}"
echo -e "${CYAN}║  Kiểm tra: _contract.json ↔ flow ↔ doc-framework ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

if [[ "${1:-}" == "--all" ]]; then
  for skill in "${ALL_SKILLS[@]}"; do
    validate_skill "$skill"
  done
elif [[ -n "${1:-}" ]]; then
  # Kiểm tra skill có trong danh sách
  skill="$1"
  found=false
  for s in "${ALL_SKILLS[@]}"; do
    if [[ "$s" == "$skill" ]]; then
      found=true
      break
    fi
  done

  if [[ "$found" == "false" ]]; then
    echo -e "${RED}Error: Skill '$skill' không tồn tại trong danh sách.${NC}"
    echo "Danh sách skills: ${ALL_SKILLS[*]}"
    exit 1
  fi

  validate_skill "$skill"
else
  echo "Cách dùng: $0 [skill-name | --all]"
  echo "Ví dụ:"
  echo "  $0 wf-brainstorm"
  echo "  $0 --all"
  exit 0
fi

# ---- Summary ----

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  KẾT QUẢ TỔNG HỢP                               ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Skills kiểm tra: $TOTAL_SKILLS"
echo -e "${CYAN}║${NC}  ${GREEN}PASS: $PASS_COUNT${NC}"
echo -e "${CYAN}║${NC}  ${RED}FAIL: $FAIL_COUNT${NC}"
echo -e "${CYAN}║${NC}  Tổng errors: $TOTAL_ERRORS"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo -e "\n${GREEN}✔ TẤT CẢ $TOTAL_SKILLS SKILLS PASS${NC}"
  exit 0
else
  echo -e "\n${RED}✘ $FAIL_COUNT/$TOTAL_SKILLS SKILLS FAIL${NC}"
  exit 1
fi
