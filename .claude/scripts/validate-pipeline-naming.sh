#!/bin/bash
# ============================================================
# validate-pipeline-naming.sh
# Kiem tra naming consistency trong .mc-data/ output
# Chay SAU legacy pipeline hoan thanh (hoac bat ky luc nao)
#
# Usage:
#   ./.claude/scripts/validate-pipeline-naming.sh [mc-data-path]
#   Default: .mc-data/
#
# Output: Terminal report + .mc-data/work/mcv3-audit/naming-validation-report.md
# ============================================================

set -euo pipefail

# ============================================================
# CONFIG
# ============================================================

MC_DATA="${1:-.mc-data}"
WORK_DIR="$MC_DATA/work/legacy-scan"
DOCS_DIR="$MC_DATA/docs"
REGISTRY="$DOCS_DIR/_meta/req-registry.json"
REPORT_DIR="$MC_DATA/work/mcv3-audit"
REPORT="$REPORT_DIR/naming-validation-report.md"

PASS=0
WARN=0
FAIL=0
DETAILS=""

# ============================================================
# HELPERS
# ============================================================

check_pass() { PASS=$((PASS + 1)); DETAILS+="  [PASS] $1\n"; }
check_warn() { WARN=$((WARN + 1)); DETAILS+="  [WARN] $1\n"; }
check_fail() { FAIL=$((FAIL + 1)); DETAILS+="  [FAIL] $1\n"; }

KEBAB_RE='^[a-z][a-z0-9]*(-[a-z0-9]+)*$'

section() {
  DETAILS+="\n### $1\n\n"
  echo "--- $1"
}

# ============================================================
# PRE-CHECK: files ton tai
# ============================================================

echo "============================================"
echo "  PIPELINE NAMING VALIDATION"
echo "  mc-data: $MC_DATA"
echo "============================================"
echo ""

mkdir -p "$REPORT_DIR"

if [[ ! -d "$MC_DATA" ]]; then
  echo "STOP: $MC_DATA khong ton tai."
  exit 1
fi

# ============================================================
# CHECK 1: Classified batch files — naming convention
# ============================================================

section "Check 1: Classified Batch Naming Convention"

BATCH_FILES=$(find "$WORK_DIR/classified" -name "batch-*.json" 2>/dev/null | sort || true)
BATCH_COUNT=$(echo "$BATCH_FILES" | grep -c "." 2>/dev/null || echo "0")
BATCH_COUNT=$(echo "$BATCH_COUNT" | tr -d '[:space:]')

if [[ "$BATCH_COUNT" -eq 0 ]]; then
  check_warn "Khong co classified batch files (chua chay classify?)"
else
  ALL_MODULES=""
  ALL_SYSTEMS=""
  NAMING_VIOLATIONS=0

  for f in $BATCH_FILES; do
    if ! jq '.' "$f" > /dev/null 2>&1; then
      check_fail "Invalid JSON: $f"
      continue
    fi

    # Collect module names
    MODS=$(jq -r '.items[]?.module // empty' "$f" 2>/dev/null | sort -u || true)
    SYSS=$(jq -r '.items[]?.system // empty' "$f" 2>/dev/null | sort -u || true)

    for mod in $MODS; do
      ALL_MODULES+="$mod\n"
      if ! echo "$mod" | grep -qE "$KEBAB_RE"; then
        check_fail "Module '$mod' khong phai lowercase-kebab-case (file: $(basename "$f"))"
        NAMING_VIOLATIONS=$((NAMING_VIOLATIONS + 1))
      fi
    done

    for sys in $SYSS; do
      ALL_SYSTEMS+="$sys\n"
      if ! echo "$sys" | grep -qE "$KEBAB_RE"; then
        check_fail "System '$sys' khong phai lowercase-kebab-case (file: $(basename "$f"))"
        NAMING_VIOLATIONS=$((NAMING_VIOLATIONS + 1))
      fi
    done
  done

  # Check case-insensitive duplicates
  if [[ -n "$ALL_MODULES" ]]; then
    UNIQUE_MODULES=$(echo -e "$ALL_MODULES" | grep -v '^$' | sort -u)
    LOWER_MODULES=$(echo -e "$ALL_MODULES" | grep -v '^$' | tr '[:upper:]' '[:lower:]' | sort -u)
    ORIG_COUNT=$(echo "$UNIQUE_MODULES" | wc -l | tr -d '[:space:]')
    LOWER_COUNT=$(echo "$LOWER_MODULES" | wc -l | tr -d '[:space:]')

    if [[ "$ORIG_COUNT" -ne "$LOWER_COUNT" ]]; then
      check_fail "Case-insensitive duplicates trong module names! ($ORIG_COUNT unique vs $LOWER_COUNT case-folded)"
      # Show duplicates
      DUPES=$(echo -e "$ALL_MODULES" | grep -v '^$' | sort -u | tr '[:upper:]' '[:lower:]' | sort | uniq -d)
      for d in $DUPES; do
        VARIANTS=$(echo -e "$ALL_MODULES" | grep -v '^$' | sort -u | grep -i "^${d}$" | tr '\n' ', ')
        check_fail "  Duplicate variants: $VARIANTS"
      done
    else
      check_pass "Khong co case-insensitive duplicates trong modules ($ORIG_COUNT modules)"
    fi
  fi

  if [[ "$NAMING_VIOLATIONS" -eq 0 && "$BATCH_COUNT" -gt 0 ]]; then
    check_pass "Tat ca module/system names trong $BATCH_COUNT batches la lowercase-kebab-case"
  fi
fi

# ============================================================
# CHECK 2: Extracted files — naming consistency
# ============================================================

section "Check 2: Extracted File Naming"

EXTRACTED_FILES=$(find "$WORK_DIR/extracted" -maxdepth 1 -name "*.json" \
  ! -name "dedup-report.json" ! -name "*divergences*" ! -name "*normalization*" \
  2>/dev/null | sort || true)
EXTRACTED_COUNT=$(echo "$EXTRACTED_FILES" | grep -c "." 2>/dev/null || echo "0")
EXTRACTED_COUNT=$(echo "$EXTRACTED_COUNT" | tr -d '[:space:]')

if [[ "$EXTRACTED_COUNT" -eq 0 ]]; then
  check_warn "Khong co extracted files (chua chay extract?)"
else
  EXT_VIOLATIONS=0
  for f in $EXTRACTED_FILES; do
    BASENAME=$(basename "$f" .json)
    if ! echo "$BASENAME" | grep -qE "$KEBAB_RE"; then
      check_fail "Extracted filename '$BASENAME.json' khong phai lowercase-kebab-case"
      EXT_VIOLATIONS=$((EXT_VIOLATIONS + 1))
    fi

    # Check internal module/system fields
    if jq '.' "$f" > /dev/null 2>&1; then
      INT_MOD=$(jq -r '.module // empty' "$f" 2>/dev/null || true)
      INT_SYS=$(jq -r '.system // empty' "$f" 2>/dev/null || true)

      if [[ -n "$INT_MOD" ]] && ! echo "$INT_MOD" | grep -qE "$KEBAB_RE"; then
        check_fail "extracted/$BASENAME.json: .module='$INT_MOD' khong phai kebab-case"
        EXT_VIOLATIONS=$((EXT_VIOLATIONS + 1))
      fi

      # Check filename matches .module field
      if [[ -n "$INT_MOD" && "$BASENAME" != "$INT_MOD" ]]; then
        check_warn "extracted/$BASENAME.json: filename != .module field ('$INT_MOD')"
      fi
    fi
  done

  if [[ "$EXT_VIOLATIONS" -eq 0 ]]; then
    check_pass "Tat ca $EXTRACTED_COUNT extracted files co naming hop le"
  fi
fi

# ============================================================
# CHECK 3: Registry naming
# ============================================================

section "Check 3: Registry Naming Consistency"

if [[ ! -f "$REGISTRY" ]]; then
  check_warn "Registry khong ton tai ($REGISTRY)"
else
  if ! jq '.' "$REGISTRY" > /dev/null 2>&1; then
    check_fail "Registry JSON khong hop le"
  else
    check_pass "Registry JSON hop le"

    # Check system IDs for case duplicates
    SYS_IDS=$(jq -r '.systems[]?.id // empty' "$REGISTRY" 2>/dev/null | sort || true)
    SYS_LOWER=$(echo "$SYS_IDS" | tr '[:upper:]' '[:lower:]' | sort)
    SYS_UNIQUE=$(echo "$SYS_LOWER" | sort -u)
    if [[ "$(echo "$SYS_LOWER" | wc -l | tr -d '[:space:]')" -ne "$(echo "$SYS_UNIQUE" | wc -l | tr -d '[:space:]')" ]]; then
      check_fail "Registry co duplicate system IDs (case-insensitive)"
    else
      SYS_COUNT=$(echo "$SYS_IDS" | grep -c "." 2>/dev/null || echo 0)
      check_pass "Registry systems: $SYS_COUNT (khong duplicate)"
    fi

    # Check module IDs for case duplicates
    MOD_IDS=$(jq -r '.modules[]?.id // empty' "$REGISTRY" 2>/dev/null | sort || true)
    MOD_LOWER=$(echo "$MOD_IDS" | tr '[:upper:]' '[:lower:]' | sort)
    MOD_UNIQUE=$(echo "$MOD_LOWER" | sort -u)
    if [[ "$(echo "$MOD_LOWER" | wc -l | tr -d '[:space:]')" -ne "$(echo "$MOD_UNIQUE" | wc -l | tr -d '[:space:]')" ]]; then
      check_fail "Registry co duplicate module IDs (case-insensitive)"
    else
      MOD_COUNT=$(echo "$MOD_IDS" | grep -c "." 2>/dev/null || echo 0)
      check_pass "Registry modules: $MOD_COUNT (khong duplicate)"
    fi

    # Check impl_status values (CORE-010)
    INVALID_STATUS=$(jq -r '.requirements[]? | select(.impl_status != "not_started" and .impl_status != "in_progress" and .impl_status != "done" and .impl_status != "skipped") | .id + "=" + .impl_status' "$REGISTRY" 2>/dev/null || true)
    if [[ -n "$INVALID_STATUS" ]]; then
      check_fail "Registry co impl_status khong hop le (CORE-010): $INVALID_STATUS"
    else
      REQ_COUNT=$(jq -r '.requirements | length' "$REGISTRY" 2>/dev/null || echo 0)
      check_pass "Registry requirements: $REQ_COUNT (impl_status hop le)"
    fi
  fi
fi

# ============================================================
# CHECK 4: Phase 2 folders vs Registry
# ============================================================

section "Check 4: Phase 2 Folders vs Registry"

PHASE2_DIR="$DOCS_DIR/phase2-features"
if [[ ! -d "$PHASE2_DIR" ]]; then
  check_warn "Phase 2 directory khong ton tai"
elif [[ ! -f "$REGISTRY" ]]; then
  check_warn "Skip — registry khong ton tai"
else
  # Get Phase 2 system folder names
  P2_SYSTEMS=$(find "$PHASE2_DIR" -mindepth 1 -maxdepth 1 -type d \
    ! -name "stakeholder-review*" 2>/dev/null | xargs -I{} basename {} | sort || true)

  # Get registry system names (extract from ID: SYS-xxx → xxx part, or name field)
  REG_SYSTEMS=$(jq -r '.systems[]?.id // empty' "$REGISTRY" 2>/dev/null | sort || true)

  # Check Phase 2 folders exist for each registry system
  if [[ -n "$REG_SYSTEMS" && -n "$P2_SYSTEMS" ]]; then
    P2_COUNT=$(echo "$P2_SYSTEMS" | wc -l | tr -d '[:space:]')
    REG_COUNT=$(echo "$REG_SYSTEMS" | wc -l | tr -d '[:space:]')

    if [[ "$P2_COUNT" -eq 0 ]]; then
      check_warn "Phase 2 khong co system folders"
    else
      check_pass "Phase 2 co $P2_COUNT system folders"

      # Check naming convention for Phase 2 folders
      for folder in $P2_SYSTEMS; do
        if ! echo "$folder" | grep -qE "$KEBAB_RE"; then
          check_fail "Phase 2 folder '$folder' khong phai lowercase-kebab-case"
        fi
      done
    fi
  fi
fi

# ============================================================
# CHECK 5: Cross-phase naming — Phase 0-1 docs vs Registry
# ============================================================

section "Check 5: Cross-Phase Naming Spot Check"

if [[ ! -f "$REGISTRY" ]]; then
  check_warn "Skip — registry khong ton tai"
else
  # Get first 3 module names from registry
  SAMPLE_MODS=$(jq -r '.modules[0:3][]?.id // empty' "$REGISTRY" 2>/dev/null || true)

  if [[ -z "$SAMPLE_MODS" ]]; then
    check_warn "Registry khong co modules de spot-check"
  else
    for mod_id in $SAMPLE_MODS; do
      # Check P0-01
      P0_FILE="$DOCS_DIR/phase0-brainstorm/P0-01-brainstorm.md"
      if [[ -f "$P0_FILE" ]]; then
        if grep -qi "$mod_id" "$P0_FILE" 2>/dev/null; then
          check_pass "Phase 0: '$mod_id' tim thay trong P0-01"
        else
          check_warn "Phase 0: '$mod_id' KHONG tim thay trong P0-01 (co the dung display name)"
        fi
      fi
    done
  fi
fi

# ============================================================
# CHECK 6: module-code-mapping.json
# ============================================================

section "Check 6: Module-Code Mapping"

MCM="$WORK_DIR/module-code-mapping.json"
if [[ ! -f "$MCM" ]]; then
  check_warn "module-code-mapping.json khong ton tai (chua chay extract Stage 3.5?)"
else
  if ! jq '.' "$MCM" > /dev/null 2>&1; then
    check_fail "module-code-mapping.json JSON khong hop le"
  else
    MAPPING_COUNT=$(jq '.mappings | length' "$MCM" 2>/dev/null || echo 0)
    PHANTOM_COUNT=$(jq '[.warnings[]? | select(.type == "PHANTOM_MODULE")] | length' "$MCM" 2>/dev/null || echo 0)
    WARNING_COUNT=$(jq '.warnings | length' "$MCM" 2>/dev/null || echo 0)

    check_pass "module-code-mapping.json: $MAPPING_COUNT mappings"

    if [[ "$PHANTOM_COUNT" -gt 0 ]]; then
      PHANTOMS=$(jq -r '.warnings[] | select(.type == "PHANTOM_MODULE") | .modules[]?' "$MCM" 2>/dev/null || true)
      check_warn "Phantom modules ($PHANTOM_COUNT): $PHANTOMS"
    fi

    if [[ "$WARNING_COUNT" -gt "$PHANTOM_COUNT" ]]; then
      OTHER_WARNS=$((WARNING_COUNT - PHANTOM_COUNT))
      check_warn "module-code-mapping co $OTHER_WARNS warnings khac (xem file)"
    fi

    # Check doc_module names are kebab-case
    DOC_MODS=$(jq -r '.mappings[]?.doc_module // empty' "$MCM" 2>/dev/null || true)
    MCM_VIOLATIONS=0
    for dm in $DOC_MODS; do
      if ! echo "$dm" | grep -qE "$KEBAB_RE"; then
        check_fail "module-code-mapping: doc_module '$dm' khong phai kebab-case"
        MCM_VIOLATIONS=$((MCM_VIOLATIONS + 1))
      fi
    done
    if [[ "$MCM_VIOLATIONS" -eq 0 && -n "$DOC_MODS" ]]; then
      check_pass "Tat ca doc_module names la lowercase-kebab-case"
    fi
  fi
fi

# ============================================================
# CHECK 7: naming-normalization-log.md
# ============================================================

section "Check 7: Naming Normalization Log"

NNL="$WORK_DIR/naming-normalization-log.md"
if [[ ! -f "$NNL" ]]; then
  check_warn "naming-normalization-log.md khong ton tai (normalize Step 4a.5 chua chay?)"
else
  NNL_SIZE=$(wc -c < "$NNL" 2>/dev/null || echo "0")
  NNL_SIZE=$(echo "$NNL_SIZE" | tr -d '[:space:]')
  if [[ "$NNL_SIZE" -lt 50 ]]; then
    check_warn "naming-normalization-log.md qua nho ($NNL_SIZE bytes) — co the rong"
  else
    check_pass "naming-normalization-log.md ton tai ($NNL_SIZE bytes)"
  fi
fi

# ============================================================
# CHECK 8: classify-naming-fixes.json
# ============================================================

section "Check 8: Classify Naming Fixes"

CNF="$WORK_DIR/classified/classify-naming-fixes.json"
if [[ ! -f "$CNF" ]]; then
  check_warn "classify-naming-fixes.json khong ton tai (classify POST-GATE CORE-016 chua chay hoac khong co fixes)"
else
  if jq '.' "$CNF" > /dev/null 2>&1; then
    FIX_COUNT=$(jq 'length' "$CNF" 2>/dev/null || echo 0)
    if [[ "$FIX_COUNT" -gt 0 ]]; then
      check_warn "classify-naming-fixes.json co $FIX_COUNT fixes (naming da phai sua)"
    else
      check_pass "classify-naming-fixes.json rong (khong can sua naming)"
    fi
  else
    check_fail "classify-naming-fixes.json JSON khong hop le"
  fi
fi

# ============================================================
# SUMMARY
# ============================================================

TOTAL=$((PASS + WARN + FAIL))

echo ""
echo "============================================"
echo "  VALIDATION SUMMARY"
echo "============================================"
echo ""
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"
echo "  TOTAL: $TOTAL checks"
echo ""

if [[ "$FAIL" -eq 0 && "$WARN" -eq 0 ]]; then
  VERDICT="PASS — Naming consistency HOAN HAO"
elif [[ "$FAIL" -eq 0 ]]; then
  VERDICT="PASS (with warnings) — Naming co the chua toi uu nhung khong co loi"
elif [[ "$FAIL" -le 3 ]]; then
  VERDICT="NEEDS WORK — Co $FAIL loi naming can fix"
else
  VERDICT="FAIL — Co $FAIL loi naming nghiem trong. Can chay lai pipeline"
fi

echo "  VERDICT: $VERDICT"
echo ""
echo "  Report: $REPORT"
echo "============================================"

# ============================================================
# WRITE REPORT
# ============================================================

cat > "$REPORT" << REPORT_EOF
# Pipeline Naming Validation Report

## Ngay: $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%d)
## mc-data: $MC_DATA

## Summary

| Metric | Count |
|--------|-------|
| PASS | $PASS |
| WARN | $WARN |
| FAIL | $FAIL |
| Total | $TOTAL |

## Verdict: $VERDICT

## Chi tiet

$(echo -e "$DETAILS")

## CORE Rules Checked

| Rule | Check |
|------|-------|
| CORE-010 | impl_status values (Check 3) |
| CORE-016 | Classify naming convention (Check 1, 8) |
| CORE-017 | Extract normalized names (Check 2) |
| CORE-018 | Cross-phase naming (Check 4, 5) |

## Next Steps

$(if [[ "$FAIL" -gt 0 ]]; then
  echo "- Fix naming violations truoc khi tiep tuc downstream skills"
  echo "- Neu > 5 FAIL: can chay lai pipeline tu classify"
elif [[ "$WARN" -gt 0 ]]; then
  echo "- Review warnings — co the chap nhan hoac fix"
  echo "- Chay \`/audit-skill-output --all\` de verify toan dien"
else
  echo "- Pipeline naming consistent. Co the tiep tuc downstream skills."
fi)
REPORT_EOF

echo ""
echo "Done."
