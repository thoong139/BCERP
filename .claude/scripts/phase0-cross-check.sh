#!/bin/bash
# =============================================================================
# Phase 0 Cross-Document Verification Script
# Eureka XNK & Thương Mại — DEVKIT
#
# Kiểm tra tính nhất quán giữa các tài liệu Phase 0:
#   - P0-01-brainstorm.md (index chính sách)
#   - P0-02-systems-users.md (hệ thống, roles)
#   - policies/*.md (42 file chính sách)
#   - _meta/req-registry.json (registry)
#   - stakeholder-review.md
#
# Sử dụng: bash .claude/scripts/phase0-cross-check.sh [path-to-mc-data]
# Mặc định: .mc-data/
# =============================================================================

set -euo pipefail

# --- Config ---
MC_DATA="${1:-.mc-data}"
PHASE0_DIR="$MC_DATA/docs/phase0-brainstorm"
POLICY_DIR="$PHASE0_DIR/policies"
REGISTRY="$MC_DATA/docs/_meta/req-registry.json"
P0_01="$PHASE0_DIR/P0-01-brainstorm.md"
P0_02="$PHASE0_DIR/P0-02-systems-users.md"
REVIEW="$PHASE0_DIR/stakeholder-review.md"

ERRORS=0
WARNINGS=0

# --- Helpers ---
err() { echo "  ERROR: $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }
pass() { echo "  PASS:  $1"; }
header() { echo ""; echo "=== $1 ==="; }

# --- Check 1: Required files exist ---
header "CHECK 1: Required Files Exist"

for f in "$P0_01" "$P0_02" "$REGISTRY" "$REVIEW"; do
  if [[ -f "$f" ]]; then
    pass "$f exists"
  else
    err "$f MISSING"
  fi
done

if [[ ! -d "$POLICY_DIR" ]]; then
  err "$POLICY_DIR directory MISSING"
fi

# --- Check 2: Policy file count ---
header "CHECK 2: Policy File Count"

POLICY_COUNT=$(find "$POLICY_DIR" -maxdepth 1 -name "cs-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

# Đọc số từ P0-01 (dòng "Tổng kết theo mức ưu tiên (N chính sách)")
P0_01_COUNT=$(grep 'kết theo mức' "$P0_01" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")

if [[ "$POLICY_COUNT" -eq "$P0_01_COUNT" ]]; then
  pass "Policy files: $POLICY_COUNT matches P0-01 index ($P0_01_COUNT)"
else
  err "Policy files: $POLICY_COUNT but P0-01 says $P0_01_COUNT"
fi

# --- Check 3: Policy IDs — every ID in P0-01 has a corresponding file ---
header "CHECK 3: Policy ID <-> File Mapping"

# Trích xuất tất cả CS-*-NNN từ P0-01 (dùng grep -oE thay vì -oP)
P0_IDS=$(grep -oE 'CS-[A-Z]+-[0-9]{3}' "$P0_01" | sort -u)

for id in $P0_IDS; do
  # Chuyển CS-LOG-001 → cs-log-001
  id_lower=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  # Tìm file khớp pattern
  match=$(find "$POLICY_DIR" -maxdepth 1 -name "${id_lower}-*.md" -type f 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    # Kiểm tra ID trong header file (tìm dòng chứa CS-XXX-NNN gần đầu file)
    file_id=$(head -15 "$match" 2>/dev/null | tr -d '\r' | grep -oE 'CS-[A-Z]+-[0-9]{3}' | head -1 || echo "")
    if [[ "$file_id" == "$id" ]]; then
      : # silent pass — header ID matches
    elif [[ -n "$file_id" ]] && [[ "$file_id" != "$id" ]]; then
      err "$id: file exists but header says $file_id"
    else
      : # No header ID field — filename match is sufficient
    fi
  else
    err "$id: no matching file in policies/"
  fi
done

# Đếm kết quả
TOTAL_IDS=$(echo "$P0_IDS" | wc -l | tr -d ' ')
pass "Checked $TOTAL_IDS policy IDs from P0-01"

# --- Check 4: No orphan files (files without ID in P0-01) ---
header "CHECK 4: No Orphan Policy Files"

ORPHAN_FOUND=0
for f in "$POLICY_DIR"/cs-*.md; do
  fname=$(basename "$f")
  # Trích xuất phần cs-xxx-nnn
  file_prefix=$(echo "$fname" | grep -oE '^cs-[a-z]+-[0-9]{3}' || echo "")
  if [[ -n "$file_prefix" ]]; then
    id_upper=$(echo "$file_prefix" | tr '[:lower:]' '[:upper:]')
    if ! echo "$P0_IDS" | grep -q "$id_upper"; then
      err "Orphan file: $fname — ID $id_upper not in P0-01 index"
      ORPHAN_FOUND=1
    fi
  fi
done
if [[ "$ORPHAN_FOUND" -eq 0 ]]; then
  pass "No orphan policy files found"
fi

# --- Check 5: Priority math ---
header "CHECK 5: Priority Math (MUST + SHOULD + NICE = Total)"

# Dùng grep -oE thay vì grep -oP
# Trích xuất số ngay sau "** " trong dòng tổng kết (e.g. "- **Bắt buộc trước Go-live:** 27")
MUST=$(grep 'Go-live' "$P0_01" 2>/dev/null | sed 's/.*\*\* //' | grep -oE '^[0-9]+' | head -1 || echo "0")
SHOULD=$(grep 'trong 3' "$P0_01" 2>/dev/null | tail -1 | sed 's/.*\*\* //' | grep -oE '^[0-9]+' | head -1 || echo "0")
NICE=$(grep 'chọn' "$P0_01" 2>/dev/null | tail -1 | sed 's/.*\*\* //' | grep -oE '^[0-9]+' | head -1 || echo "0")
SUM=$((MUST + SHOULD + NICE))

if [[ "$SUM" -eq "$POLICY_COUNT" ]]; then
  pass "Priority math: $MUST + $SHOULD + $NICE = $SUM (matches file count $POLICY_COUNT)"
else
  err "Priority math: $MUST + $SHOULD + $NICE = $SUM but file count is $POLICY_COUNT"
fi

# --- Check 6: Registry systems count ---
header "CHECK 6: Registry Systems"

if [[ -f "$REGISTRY" ]]; then
  # Thử python3 trước, rồi python, rồi jq
  REG_SYS_COUNT="ERR"
  REG_DEPT_COUNT="ERR"

  if command -v python3 &>/dev/null; then
    REG_SYS_COUNT=$(python3 -c "import json; d=json.load(open('$REGISTRY')); print(len(d.get('systems',[])))" 2>/dev/null || echo "ERR")
    REG_DEPT_COUNT=$(python3 -c "import json; d=json.load(open('$REGISTRY')); print(len(d.get('departments',[])))" 2>/dev/null || echo "ERR")
  elif command -v python &>/dev/null; then
    REG_SYS_COUNT=$(python -c "import json; d=json.load(open('$REGISTRY')); print(len(d.get('systems',[])))" 2>/dev/null || echo "ERR")
    REG_DEPT_COUNT=$(python -c "import json; d=json.load(open('$REGISTRY')); print(len(d.get('departments',[])))" 2>/dev/null || echo "ERR")
  elif command -v jq &>/dev/null; then
    REG_SYS_COUNT=$(jq '.systems | length' "$REGISTRY" 2>/dev/null || echo "ERR")
    REG_DEPT_COUNT=$(jq '.departments | length' "$REGISTRY" 2>/dev/null || echo "ERR")
  elif command -v node &>/dev/null; then
    REG_SYS_COUNT=$(node -e "const d=require('$REGISTRY'); console.log(d.systems.length)" 2>/dev/null || echo "ERR")
    REG_DEPT_COUNT=$(node -e "const d=require('$REGISTRY'); console.log(d.departments.length)" 2>/dev/null || echo "ERR")
  fi

  if [[ "$REG_SYS_COUNT" != "ERR" ]]; then
    pass "Registry systems: $REG_SYS_COUNT"
    pass "Registry departments: $REG_DEPT_COUNT"
  else
    warn "Could not parse registry (need python3, python, jq, or node)"
  fi
else
  err "Registry file missing"
fi

# --- Check 7: Cross-policy 4-eyes thresholds ---
header "CHECK 7: 4-Eyes Threshold Consistency"

FIN001="$POLICY_DIR/cs-fin-001-kiem-soat-thanh-toan.md"
COMP002="$POLICY_DIR/cs-comp-002-sod-phe-duyet-giao-dich.md"

if [[ -f "$FIN001" ]] && [[ -f "$COMP002" ]]; then
  FIN_500=$(grep -c "500" "$FIN001" 2>/dev/null || echo "0")
  COMP_500=$(grep -c "500" "$COMP002" 2>/dev/null || echo "0")
  if [[ "$FIN_500" -gt 0 ]] && [[ "$COMP_500" -gt 0 ]]; then
    pass "4-eyes 500 threshold present in both CS-FIN-001 and CS-COMP-002"
  else
    err "4-eyes threshold mismatch: CS-FIN-001 mentions=${FIN_500}, CS-COMP-002 mentions=${COMP_500}"
  fi
else
  warn "Could not find CS-FIN-001 or CS-COMP-002 for threshold check"
fi

if [[ -f "$P0_02" ]]; then
  P02_500=$(grep -c "500" "$P0_02" 2>/dev/null || echo "0")
  if [[ "$P02_500" -gt 0 ]]; then
    pass "4-eyes threshold also referenced in P0-02"
  else
    warn "P0-02 does not mention 500 threshold"
  fi
fi

# --- Check 8: No duplicate policy IDs ---
header "CHECK 8: No Duplicate Policy IDs"

DUPES=$(echo "$P0_IDS" | sort | uniq -d)
if [[ -z "$DUPES" ]]; then
  pass "No duplicate policy IDs in P0-01"
else
  err "Duplicate IDs found: $DUPES"
fi

# Kiểm tra không còn file cs-data-001 (đã merge)
if [[ -f "$POLICY_DIR/cs-data-001-bao-ve-du-lieu-ca-nhan-pdpa.md" ]]; then
  err "cs-data-001 still exists — should have been merged into CS-LEGAL-002"
else
  pass "cs-data-001 properly merged into CS-LEGAL-002 (no duplicate)"
fi

# --- Check 9: Agent attribution in policy files ---
header "CHECK 9: Agent Attribution Spot-Check"

AGENT_ERR=0
for f in "$POLICY_DIR"/cs-proc-*.md; do
  fname=$(basename "$f")
  agent_line=$(grep "Agent" "$f" 2>/dev/null | head -1 || echo "")
  if echo "$agent_line" | grep -q "hr-expert"; then
    err "$fname: agent attribution has hr-expert (should be procurement-expert)"
    AGENT_ERR=1
  fi
done
if [[ "$AGENT_ERR" -eq 0 ]]; then
  pass "PROC policy agent attribution correct (no hr-expert)"
fi

# --- Summary ---
header "SUMMARY"
echo ""
echo "  Total errors:   $ERRORS"
echo "  Total warnings: $WARNINGS"
echo ""

if [[ "$ERRORS" -eq 0 ]]; then
  echo "  RESULT: ALL CHECKS PASSED"
  exit 0
else
  echo "  RESULT: $ERRORS ERROR(S) FOUND — fix required"
  exit 1
fi
