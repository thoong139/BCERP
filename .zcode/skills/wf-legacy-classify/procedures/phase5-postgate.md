# Phase 5: POST-GATE + Naming Consistency

> Tổng hợp các check chất lượng cuối: validate ledger, validate batch files, validate glossary,
> và áp dụng CORE-016 Naming Consistency Check (case-insensitive dedup, fuzzy match, kebab-case enforcement).

**PRE-GATE:**
- Phase 4 POST-GATE PASS (coverage >= 95% hoặc user accept)
- `classified/glossary.json` tồn tại
- Tất cả `classified/batch-*.json` đã validated trong Phase 2

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/classified/batch-*.json` (tất cả)
- `.mc-data/work/legacy-scan/classified/glossary.json`

**OUTPUT:**
- `.mc-data/work/legacy-scan/classified/classify-naming-fixes.json` (chỉ tạo nếu CORE-016 fires)
- Update `classified/batch-*.json` (nếu có naming fixes — vd: rename system/module)
- In-memory state: `$NAMING_FIXES`

---

## Reference Sections

- `_shared.md` §Naming Convention
- `_shared.md` §Fix Rules (Naming inconsistency)
- `00-core.md` §Quick Reference CORE-016, CORE-017

---

## Steps

### 5.1 — POST-GATE Tier 1: Status & File Existence

```
1. jq -r '.stages.classify.status' ledger.json — không cần phải == "completed" tại bước này (Phase 6 sẽ set)
   Status hiện tại có thể là "in_progress" — đó là OK
2. test -f classified/glossary.json
3. test -d classified/ với at least 1 batch-*.json
```

### 5.2 — POST-GATE Tier 2: Glossary Schema

```
jq -e '."$schema" == "legacy-scan-glossary-v1"' classified/glossary.json
jq -e 'has("stats")' classified/glossary.json
NẾU terms.length == 0 → WARNING (acceptable cho project nhỏ)
```

### 5.3 — POST-GATE Tier 3: Coverage

```
items_classified >= 95% * total_items
(đã được verify ở Phase 4, recheck ở đây để chốt)
```

### 5.4 — POST-GATE Tier 4: Batch Files Schema

```
FOR each classified/batch-*.json:
  1. jq '.' file > /dev/null  (JSON valid)
  2. jq -e '.batch_number > 0' file
  3. jq -e '.stats.total > 0' file
  4. jq -e '.items | length > 0' file
  5. Mọi item.type phải hợp lệ:
     - Source mode: ∈ {screen, api, doc, source, config, test, asset, migration, type, UNKNOWN}
     - DOCS_ONLY mode: ∈ {prd, spec, wireframe, meeting_notes, api_spec, user_guide, process_doc, general, UNKNOWN}
```

### 5.5 — CORE-016 Naming Consistency Check

```
Step 5.5.1: Collect unique (system, module) pairs
  pairs = jq -r '.items[] | "\(.system)|\(.module)"' classified/batch-*.json | sort -u

Step 5.5.2: Case-insensitive dedup
  FOR each pair:
    lowercase_key = pair.lower()
    IF có pair khác cùng lowercase_key (vd: "CRM|sales" và "crm|sales"):
      → AUTO-FIX: chọn lowercase-kebab-case version
      → Update tất cả batch files: replace "CRM" → "crm" trong items[].system
      → Append fix vào $NAMING_FIXES: {type: "case_dedup", from: "CRM", to: "crm", batches_affected: [N1, N2]}

Step 5.5.3: Fuzzy match (Levenshtein <= 2)
  FOR each pair (system) hoặc (module) names:
    Compute Levenshtein distance giữa các names
    IF distance <= 2 (vd: "order-management" vs "order-mgmt"):
      → WARNING (KHÔNG auto-fix vì có thể là intentional)
      → AskUserQuestion: "Phát hiện 2 module names tương tự: 'order-management' và 'order-mgmt'. Chọn 1 (canonical) hay giữ cả 2?"
      → Apply user's decision → append vào $NAMING_FIXES

Step 5.5.4: Kebab-case enforcement
  FOR each pair:
    IF NOT match regex /^[a-z0-9]+(-[a-z0-9]+)*$/ (lowercase-kebab-case):
      → AUTO-FIX: convert sang kebab-case
        - PascalCase → kebab: "OrderManagement" → "order-management"
        - camelCase → kebab: "orderManagement" → "order-management"
        - snake_case → kebab: "order_management" → "order-management"
        - UPPERCASE → lowercase: "CRM" → "crm"
      → Update tất cả batch files
      → Append vào $NAMING_FIXES: {type: "kebab_case", from: "OrderManagement", to: "order-management", batches_affected: [N]}

Step 5.5.5: Ghi naming fixes log (chỉ nếu $NAMING_FIXES non-empty)
  WRITE classified/classify-naming-fixes.json:
  {
    "$schema": "naming-fixes-v1",
    "applied_at": ISO_NOW,
    "rule": "CORE-016",
    "fixes": $NAMING_FIXES,
    "stats": {
      "total_fixes": length($NAMING_FIXES),
      "case_dedup": count(type=="case_dedup"),
      "kebab_case": count(type=="kebab_case"),
      "fuzzy_user_choice": count(type=="fuzzy_user_choice")
    }
  }
```

### 5.6 — Re-validate batch files sau naming fixes

Nếu có naming fixes (Step 5.5.2 hoặc 5.5.4 fired):
- Re-run validation Tier 4 (Step 5.4) trên các batch files đã modify
- Verify JSON vẫn valid sau update

### 5.7 — POST-GATE Tier 5: Session Scan-State Layer Check (v5.0)

Khi session v5.0 tồn tại (`sessions/{id}/scan-state.json` có), verify layer status để đảm bảo orchestrator không stale:

```bash
SESSION_DIR=".mc-data/work/legacy-scan/sessions/$SESSION_ID"
if test -f "$SESSION_DIR/scan-state.json"; then
  # Check L4 (classify layer) đã được mark completed hoặc skipped_by_profile
  L4_STATUS=$(jq -r '.layers.L4.status // "unknown"' "$SESSION_DIR/scan-state.json")
  if [ "$L4_STATUS" != "completed" ] && [ "$L4_STATUS" != "skipped_by_profile" ]; then
    echo "⚠️ POST-GATE T5 WARN: scan-state.layers.L4.status = $L4_STATUS (expected: completed/skipped_by_profile)"
    echo "   → Downstream skills có thể stale. Verify update_layer_status('L4') đã được gọi ở Phase 6."
    # KHÔNG FAIL POST-GATE — chỉ WARN để orchestrator biết
  fi
fi
```

> Khi session không tồn tại (v4.1 backward-compat mode) → skip T5. Không FAIL.

---

## Phase 5 POST-GATE

```
1. Glossary schema check PASS
2. Coverage >= 95%
3. Tất cả batch files: JSON valid + types hợp lệ
4. Naming consistency: AUTO-FIXES applied (nếu có), fuzzy matches resolved (nếu có)
5. classify-naming-fixes.json tồn tại (nếu có fixes) HOẶC không có fixes (acceptable)
```

---

## Error Handling

| Tình huống | Xử lý |
|-----------|-------|
| Glossary schema fail | E021 — quay lại Phase 3 retry (max 1 lần) |
| Batch file invalid JSON sau naming fix | Rollback fix đó, log error_log, ASK user |
| Fuzzy match user không trả lời | Skip fix, log NOTE vào error_log |

---

**Next phase:** `phase6-finalize.md`
