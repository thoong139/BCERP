#!/bin/bash
# skill-compliance-audit.sh v3.0
# Comprehensive compliance audit for DEVKIT skills
# Aligned with workflow-skill.md v3.0 and expert-skill.md v2.0
# Usage: ./skill-compliance-audit.sh [skill-name | path/to/SKILL.md | --all]

set -euo pipefail 2>/dev/null || set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TEMPLATE_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Find skill file
find_skill_file() {
    local input="$1"
    if [[ -f "$input" ]]; then
        echo "$input"
        return 0
    fi
    local locations=(
        "$PROJECT_ROOT/.claude/skills/$input/SKILL.md"
        "$PROJECT_ROOT/.claude/skills/workflow/$input/SKILL.md"
        ".claude/skills/$input/SKILL.md"
        ".claude/skills/workflow/$input/SKILL.md"
        "./.claude/skills/$input/SKILL.md"
        "./.claude/skills/workflow/$input/SKILL.md"
        "$input"
    )
    for loc in "${locations[@]}"; do
        if [[ -f "$loc" ]]; then
            echo "$loc"
            return 0
        fi
    done
    return 1
}

# Detect skill type: workflow or expert
detect_skill_type() {
    local file="$1"
    if grep -qE '## (Phase [0-9]|Capabilities)' "$file" 2>/dev/null; then
        if grep -q '## Capabilities' "$file" 2>/dev/null; then
            echo "expert"
        else
            echo "workflow"
        fi
    else
        echo "workflow"
    fi
}

# Detect duration type: Quick or Multi-session
detect_duration() {
    local file="$1"
    if grep -qiE 'Quick|single.session' "$file" 2>/dev/null; then
        if grep -qiE 'Multi-session|multi.session' "$file" 2>/dev/null; then
            echo "multi"
        else
            echo "quick"
        fi
    else
        echo "multi"
    fi
}

# Detect if skill uses agents
detect_agents() {
    local file="$1"
    if grep -qiE 'subagent_type|Agent.*spawn|spawn.*agent' "$file" 2>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Detect if skill writes registry
detect_registry_write() {
    local file="$1"
    if grep -qiE 'req-registry|registry.*update|registry.*write|Safe-Write' "$file" 2>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "SKILL COMPLIANCE AUDIT v3.0"
    echo "Template: workflow-skill v$TEMPLATE_VERSION / expert-skill v2.0"
    echo "==========================================${NC}"
    echo ""
}

# Counters & tracking
reset_counters() {
    CRITICAL_TOTAL=0
    CRITICAL_PASS=0
    CRITICAL_FAIL_COUNT=0
    REQUIRED_TOTAL=0
    REQUIRED_PASS=0
    REQUIRED_FAIL=0
    CONDITIONAL_TOTAL=0
    CONDITIONAL_PASS=0
    CONDITIONAL_SKIP=0
    FAILED_ITEMS=()
    WARNINGS=()
}

check_pass() {
    echo -e "${GREEN}  PASS${NC} [$1] $2"
    if [[ "$1" == "CRITICAL" ]]; then
        ((CRITICAL_PASS++)) || true
    elif [[ "$1" == "CONDITIONAL" ]]; then
        ((CONDITIONAL_PASS++)) || true
    else
        ((REQUIRED_PASS++)) || true
    fi
}

check_fail() {
    echo -e "${RED}  FAIL${NC} [$1] $2"
    if [[ "$1" == "CRITICAL" ]]; then
        FAILED_ITEMS+=("$2")
        ((CRITICAL_FAIL_COUNT++)) || true
    elif [[ "$1" == "CONDITIONAL" ]]; then
        WARNINGS+=("$2")
    else
        ((REQUIRED_FAIL++)) || true
    fi
}

check_skip() {
    echo -e "${CYAN}  SKIP${NC} [$1] $2 (not applicable)"
    ((CONDITIONAL_SKIP++)) || true
}

check_item() {
    local level="$1"
    local name="$2"
    local cmd="$3"
    if eval "$cmd" > /dev/null 2>&1; then
        check_pass "$level" "$name"
    else
        check_fail "$level" "$name"
    fi
}

check_conditional() {
    local condition="$1"
    local name="$2"
    local cmd="$3"
    if [[ "$condition" == "true" ]]; then
        ((CONDITIONAL_TOTAL++)) || true
        if eval "$cmd" > /dev/null 2>&1; then
            check_pass "CONDITIONAL" "$name"
        else
            check_fail "CONDITIONAL" "$name"
        fi
    else
        check_skip "CONDITIONAL" "$name"
    fi
}

# ====================================================
# Main audit function
# ====================================================
run_audit() {
    local SKILL_FILE="$1"
    local SKILL_NAME
    SKILL_NAME=$(grep -m1 '^name:' "$SKILL_FILE" 2>/dev/null | sed 's/^name:\s*//' || echo "unknown")
    local SKILL_TYPE
    SKILL_TYPE=$(detect_skill_type "$SKILL_FILE")
    local DURATION
    DURATION=$(detect_duration "$SKILL_FILE")
    local USES_AGENTS
    USES_AGENTS=$(detect_agents "$SKILL_FILE")
    local WRITES_REGISTRY
    WRITES_REGISTRY=$(detect_registry_write "$SKILL_FILE")
    local LINE_COUNT
    LINE_COUNT=$(wc -l < "$SKILL_FILE" | tr -d ' ')
    local IS_MULTI="false"
    [[ "$DURATION" == "multi" ]] && IS_MULTI="true"
    local HAS_AGENTS="false"
    [[ "$USES_AGENTS" == "yes" ]] && HAS_AGENTS="true"
    local HAS_REGISTRY="false"
    [[ "$WRITES_REGISTRY" == "yes" ]] && HAS_REGISTRY="true"

    reset_counters

    echo -e "${BLUE}File:${NC} $SKILL_FILE"
    echo -e "${BLUE}Type:${NC} $SKILL_TYPE | ${BLUE}Duration:${NC} $DURATION | ${BLUE}Agents:${NC} $USES_AGENTS | ${BLUE}Registry:${NC} $WRITES_REGISTRY | ${BLUE}Lines:${NC} $LINE_COUNT"
    echo ""

    # ====================================================
    # Section 1: Frontmatter Metadata (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 1: Frontmatter Metadata ---${NC}"
    ((CRITICAL_TOTAL+=3))
    ((REQUIRED_TOTAL+=2))
    check_item "CRITICAL" "1.1 name field" "grep -qE '^name:' '$SKILL_FILE'"
    check_item "CRITICAL" "1.2 description with TRIGGER" "grep -A 20 '^description:' '$SKILL_FILE' | grep -qi 'trigger'"
    check_item "CRITICAL" "1.3 argument-hint field" "grep -qE '^argument-hint:' '$SKILL_FILE'"
    check_item "REQUIRED" "1.4 version field" "grep -qE '^version:' '$SKILL_FILE'"
    check_item "REQUIRED" "1.5 last_updated field" "grep -qE '^last_updated:' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 2: Workflow Position (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 2: Workflow Position ---${NC}"
    ((CRITICAL_TOTAL+=1))
    ((REQUIRED_TOTAL+=1))
    check_item "CRITICAL" "2.1 Workflow Position with YOU ARE HERE" "grep -qE 'Workflow Position|YOU ARE HERE' '$SKILL_FILE'"
    check_item "REQUIRED" "2.2 Next step indicated" "grep -qiE 'next.*:|Next step|next-skill' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 3: Prerequisites & Arguments (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 3: Prerequisites & Arguments ---${NC}"
    ((CRITICAL_TOTAL+=1))
    ((REQUIRED_TOTAL+=1))
    check_item "CRITICAL" "3.1 Prerequisites defined" "grep -qiE 'prerequisite|Prerequisites|entry.point|Khong.*prerequisites' '$SKILL_FILE'"
    # Arguments: table heading OR inline description in frontmatter
    check_item "REQUIRED" "3.2 Arguments (table or inline)" "grep -qE '## Arguments|argument-hint:|Argument.*Description' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 4: Phases with Quality Gates (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 4: Phases with Quality Gates ---${NC}"
    ((CRITICAL_TOTAL+=4))
    ((REQUIRED_TOTAL+=1))
    check_item "CRITICAL" "4.1 At least 1 phase defined" "grep -qE '## (Phase|Stage) [0-9]' '$SKILL_FILE'"
    check_item "CRITICAL" "4.2 PRE-GATE markers" "grep -q 'PRE-GATE' '$SKILL_FILE'"
    check_item "CRITICAL" "4.3 POST-GATE markers" "grep -q 'POST-GATE' '$SKILL_FILE'"
    check_item "CRITICAL" "4.4 Steps table (Step|Action)" "grep -qE '\| Step \| (Action|Hành động)' '$SKILL_FILE'"
    local PHASE_COUNT
    PHASE_COUNT=$(grep -cE '## (Phase|Stage) [0-9]' "$SKILL_FILE" 2>/dev/null || echo "0")
    check_item "REQUIRED" "4.5 Multiple phases (>=2, found: $PHASE_COUNT)" "[ $PHASE_COUNT -ge 2 ]"
    echo ""

    # ====================================================
    # Section 5: Protocols & Execution Strategy (CONDITIONAL)
    # ====================================================
    echo -e "${BLUE}--- Section 5: Protocols & Execution Strategy ---${NC}"
    ((REQUIRED_TOTAL+=1))
    # Fix Rules - 11/13 skills have this, consider REQUIRED
    check_item "REQUIRED" "5.1 Fix Rules table" "grep -qiE 'Fix Rules|Error Type.*Auto-Fix|Auto-Fix Strategy' '$SKILL_FILE'"
    # Execution Strategy - conditional on agents
    check_conditional "$HAS_AGENTS" "5.2 Execution Strategy (uses agents)" \
        "grep -qiE 'PARALLEL|SEQUENTIAL|HYBRID|Execution Strategy|Optimization Strategy' '$SKILL_FILE'"
    # Shared protocols reference - conditional on multi-session
    check_conditional "$IS_MULTI" "5.3 Protocols reference (multi-session)" \
        "grep -qiE 'shared-protocols|Protocol.*Xem|Accuracy Assurance' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 6: Checkpoint & Resume (CONDITIONAL: Multi-session only)
    # ====================================================
    echo -e "${BLUE}--- Section 6: Context & Checkpoint ---${NC}"
    if [[ "$IS_MULTI" == "true" ]]; then
        ((REQUIRED_TOTAL+=2))
        check_item "REQUIRED" "6.1 Checkpoint/Resume mechanism" "grep -qiE 'checkpoint|resume|status.json|Context.*Threshold' '$SKILL_FILE'"
        check_item "REQUIRED" "6.2 --resume or --status flags" "grep -qE '\-\-resume|\-\-status' '$SKILL_FILE'"
    else
        echo -e "${CYAN}  SKIP${NC} [N/A] Quick skill — checkpoint not required"
        # Check that Quick skill explicitly states no resume
        ((REQUIRED_TOTAL+=1))
        check_item "REQUIRED" "6.3 Quick skill declares no resume" "grep -qiE 'Quick|khong.*resume|khong ho tro.*resume|single.session' '$SKILL_FILE'"
    fi
    echo ""

    # ====================================================
    # Section 7: Output (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 7: Output ---${NC}"
    ((CRITICAL_TOTAL+=1))
    ((REQUIRED_TOTAL+=1))
    check_item "CRITICAL" "7.1 Output section/template" "grep -qiE '## Output|Output Report|Output Files|Output:.*\.mc-data' '$SKILL_FILE'"
    check_item "REQUIRED" "7.2 Next step in output" "grep -qiE 'Next.*:.*/' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 8: Error Handling (CRITICAL)
    # ====================================================
    echo -e "${BLUE}--- Section 8: Error Handling ---${NC}"
    ((CRITICAL_TOTAL+=2))
    ((REQUIRED_TOTAL+=1))
    check_item "CRITICAL" "8.1 Error Handling section" "grep -q '## Error Handling' '$SKILL_FILE'"
    local ERROR_COUNT
    ERROR_COUNT=$(grep -cE '\| E[0-9][0-9][0-9]' "$SKILL_FILE" 2>/dev/null || echo "0")
    check_item "CRITICAL" "8.2 Error codes defined (found: $ERROR_COUNT)" "[ $ERROR_COUNT -ge 1 ]"
    check_item "REQUIRED" "8.3 At least 5 error codes" "[ $ERROR_COUNT -ge 5 ]"
    echo ""

    # ====================================================
    # Section 9: Related Skills (REQUIRED)
    # ====================================================
    echo -e "${BLUE}--- Section 9: Related Skills ---${NC}"
    ((REQUIRED_TOTAL+=1))
    check_item "REQUIRED" "9.1 Related Skills table" "grep -q '## Related Skills' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 10: Cross-Validation & Stakeholder Review (CONDITIONAL)
    # ====================================================
    echo -e "${BLUE}--- Section 10: Advanced Patterns ---${NC}"
    # Cross-Validation/Auto-Correction - 10/13 skills have this
    check_conditional "$IS_MULTI" "10.1 Cross-Validation or Auto-Correction phase" \
        "grep -qiE 'Cross-Validation|Auto-Correction|validation.*check|iteration.*MAX' '$SKILL_FILE'"
    # Registry Safe-Write
    check_conditional "$HAS_REGISTRY" "10.2 Registry Safe-Write rules" \
        "grep -qiE 'Safe-Write|CHI MODIFY|fields duoc phep|fields.*update' '$SKILL_FILE'"
    # Agent references exist in agents directory
    if [[ "$HAS_AGENTS" == "true" ]]; then
        ((CONDITIONAL_TOTAL++)) || true
        local MISSING_AGENTS=""
        local AGENT_TYPES
        AGENT_TYPES=$(grep -oE 'subagent_type="[^"]*"' "$SKILL_FILE" 2>/dev/null | sed 's/subagent_type="//;s/"//' | sort -u || true)
        if [[ -n "$AGENT_TYPES" ]]; then
            while IFS= read -r agent; do
                if [[ -n "$agent" ]]; then
                    local found="false"
                    for dir in "$PROJECT_ROOT/.claude/agents" "$PROJECT_ROOT/.claude/agents/business" "$PROJECT_ROOT/.claude/agents/engineering" "$PROJECT_ROOT/.claude/agents/design" "$PROJECT_ROOT/.claude/agents/testing" "$PROJECT_ROOT/.claude/agents/review"; do
                        if [[ -f "$dir/$agent.md" ]]; then
                            found="true"
                            break
                        fi
                    done
                    if [[ "$found" == "false" ]]; then
                        MISSING_AGENTS="$MISSING_AGENTS $agent"
                    fi
                fi
            done <<< "$AGENT_TYPES"
            if [[ -z "$MISSING_AGENTS" ]]; then
                check_pass "CONDITIONAL" "10.3 All agent references valid"
            else
                check_fail "CONDITIONAL" "10.3 Missing agents:$MISSING_AGENTS"
            fi
        else
            check_pass "CONDITIONAL" "10.3 Agent references (no subagent_type= found)"
        fi
    fi
    echo ""

    # ====================================================
    # Section 11: Doc-Framework Output Consistency
    # ====================================================
    echo -e "${BLUE}--- Section 11: Output Path Consistency ---${NC}"
    ((REQUIRED_TOTAL+=1))
    # Check that output paths reference .mc-data/docs/ or known paths
    check_item "REQUIRED" "11.1 Output path references .mc-data/" "grep -qE '\.mc-data/' '$SKILL_FILE'"
    echo ""

    # ====================================================
    # Section 12: Evals (REQUIRED)
    # ====================================================
    echo -e "${BLUE}--- Section 12: Eval Cases ---${NC}"
    ((REQUIRED_TOTAL+=1))
    local SKILL_DIR
    SKILL_DIR=$(dirname "$SKILL_FILE")
    local EVAL_FILE="$SKILL_DIR/evals/evals.json"
    if [[ -f "$EVAL_FILE" ]]; then
        local EVAL_COUNT
        EVAL_COUNT=$(grep -c '"id"' "$EVAL_FILE" 2>/dev/null || echo "0")
        check_pass "REQUIRED" "12.1 Evals file exists ($EVAL_COUNT cases)"
        if [[ $EVAL_COUNT -lt 3 ]]; then
            WARNINGS+=("12.1 Only $EVAL_COUNT eval cases (recommend >=3)")
        fi
    else
        check_fail "REQUIRED" "12.1 Evals file missing: evals/evals.json"
    fi
    echo ""

    # ====================================================
    # Summary
    # ====================================================
    echo ""
    echo -e "${BLUE}=========================================="
    echo "COMPLIANCE SUMMARY: $SKILL_NAME"
    echo "==========================================${NC}"

    CRITICAL_FAIL=$((CRITICAL_TOTAL - CRITICAL_PASS))
    if [[ $REQUIRED_TOTAL -gt 0 ]]; then
        REQUIRED_PCT=$((REQUIRED_PASS * 100 / REQUIRED_TOTAL))
    else
        REQUIRED_PCT=100
    fi
    if [[ $CRITICAL_TOTAL -gt 0 ]]; then
        CRITICAL_PCT=$((CRITICAL_PASS * 100 / CRITICAL_TOTAL))
    else
        CRITICAL_PCT=100
    fi

    echo ""
    echo -e "  Type: $SKILL_TYPE | Duration: $DURATION | Lines: $LINE_COUNT"
    echo -e "  CRITICAL:    ${GREEN}$CRITICAL_PASS/$CRITICAL_TOTAL${NC} ($CRITICAL_PCT%)"
    echo -e "  REQUIRED:    ${YELLOW}$REQUIRED_PASS/$REQUIRED_TOTAL${NC} ($REQUIRED_PCT%)"
    if [[ $CONDITIONAL_TOTAL -gt 0 ]]; then
        echo -e "  CONDITIONAL: ${CYAN}$CONDITIONAL_PASS/$CONDITIONAL_TOTAL${NC} (skipped: $CONDITIONAL_SKIP)"
    fi
    echo ""

    # Determine grade
    if [[ $CRITICAL_FAIL -eq 0 ]] && [[ $REQUIRED_PCT -ge 80 ]]; then
        echo -e "${GREEN}  ========================================${NC}"
        echo -e "${GREEN}          GRADE: PASS                     ${NC}"
        echo -e "${GREEN}  ========================================${NC}"
    elif [[ $CRITICAL_FAIL -eq 0 ]] && [[ $REQUIRED_PCT -ge 50 ]]; then
        echo -e "${YELLOW}  ========================================${NC}"
        echo -e "${YELLOW}          GRADE: WARNING                  ${NC}"
        echo -e "${YELLOW}  ========================================${NC}"
    else
        echo -e "${RED}  ========================================${NC}"
        echo -e "${RED}          GRADE: FAIL                     ${NC}"
        echo -e "${RED}  ========================================${NC}"
    fi

    # Show failed critical items
    if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}  MISSING CRITICAL ITEMS:${NC}"
        for item in "${FAILED_ITEMS[@]}"; do
            echo -e "    ${RED}*${NC} $item"
        done
    fi

    # Show warnings
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}  WARNINGS:${NC}"
        for warn in "${WARNINGS[@]}"; do
            echo -e "    ${YELLOW}*${NC} $warn"
        done
    fi

    # Recommendations
    echo ""
    echo -e "${BLUE}  RECOMMENDATIONS:${NC}"
    if [[ $CRITICAL_FAIL -gt 0 ]]; then
        echo "    1. Fix missing CRITICAL items first"
        echo "    2. Reference: .claude/skills/workflow-skill.md v3.0"
    elif [[ $REQUIRED_PCT -lt 80 ]]; then
        echo "    1. Add missing REQUIRED items to reach 80%"
    else
        echo -e "    ${GREEN}Skill is compliant!${NC}"
    fi

    if [[ $LINE_COUNT -gt 500 ]]; then
        echo -e "    ${YELLOW}* Line count ($LINE_COUNT) exceeds 500 — consider extracting inline content${NC}"
    fi

    echo ""
}

# List available skills
list_skills() {
    echo -e "${BLUE}Available skills:${NC}"
    for dir in "$PROJECT_ROOT"/.claude/skills/*/ "$PROJECT_ROOT"/.claude/skills/workflow/*/ "$PROJECT_ROOT"/.claude/skills/workflows/*/; do
        if [[ -f "$dir/SKILL.md" ]]; then
            name=$(basename "$dir")
            echo "  - $name"
        fi
    done
    echo ""
}

# Audit all skills
run_all() {
    echo -e "${BLUE}Running audit on ALL skills...${NC}"
    echo ""

    local PASS_COUNT=0
    local WARN_COUNT=0
    local FAIL_COUNT=0
    local RESULTS=()

    for dir in "$PROJECT_ROOT"/.claude/skills/*/ "$PROJECT_ROOT"/.claude/skills/workflow/*/ "$PROJECT_ROOT"/.claude/skills/workflows/*/; do
        if [[ -f "$dir/SKILL.md" ]]; then
            name=$(basename "$dir")
            echo -e "${BLUE}=====================================================================${NC}"
            echo -e "${BLUE}SKILL: $name${NC}"
            echo -e "${BLUE}=====================================================================${NC}"
            run_audit "$dir/SKILL.md"

            # Track results for summary
            CRITICAL_FAIL=$((CRITICAL_TOTAL - CRITICAL_PASS))
            if [[ $REQUIRED_TOTAL -gt 0 ]]; then
                REQ_PCT=$((REQUIRED_PASS * 100 / REQUIRED_TOTAL))
            else
                REQ_PCT=100
            fi

            if [[ $CRITICAL_FAIL -eq 0 ]] && [[ $REQ_PCT -ge 80 ]]; then
                RESULTS+=("${GREEN}PASS${NC}  $name (Critical: $CRITICAL_PASS/$CRITICAL_TOTAL, Required: $REQ_PCT%)")
                ((PASS_COUNT++)) || true
            elif [[ $CRITICAL_FAIL -eq 0 ]] && [[ $REQ_PCT -ge 50 ]]; then
                RESULTS+=("${YELLOW}WARN${NC}  $name (Critical: $CRITICAL_PASS/$CRITICAL_TOTAL, Required: $REQ_PCT%)")
                ((WARN_COUNT++)) || true
            else
                RESULTS+=("${RED}FAIL${NC}  $name (Critical: $CRITICAL_PASS/$CRITICAL_TOTAL, Required: $REQ_PCT%)")
                ((FAIL_COUNT++)) || true
            fi
            echo ""
        fi
    done

    # Final summary table
    echo -e "${BLUE}=========================================="
    echo "OVERALL SUMMARY — ALL SKILLS"
    echo "==========================================${NC}"
    echo ""
    for r in "${RESULTS[@]}"; do
        echo -e "  $r"
    done
    echo ""
    echo -e "  Total: $((PASS_COUNT + WARN_COUNT + FAIL_COUNT)) skills"
    echo -e "  ${GREEN}PASS: $PASS_COUNT${NC}  ${YELLOW}WARNING: $WARN_COUNT${NC}  ${RED}FAIL: $FAIL_COUNT${NC}"
    echo ""
}

# Main
main() {
    print_header

    if [[ -z "${1:-}" ]]; then
        echo -e "${RED}Error: No skill specified${NC}"
        echo ""
        echo "Usage: $0 [skill-name | path/to/SKILL.md | --all]"
        echo ""
        list_skills
        exit 1
    fi

    if [[ "$1" == "--all" ]]; then
        run_all
        exit 0
    fi

    SKILL_FILE=$(find_skill_file "$1")

    if [[ -z "$SKILL_FILE" ]]; then
        echo -e "${RED}Error: Skill file not found: $1${NC}"
        echo ""
        list_skills
        exit 1
    fi

    run_audit "$SKILL_FILE"
}

main "$@"
