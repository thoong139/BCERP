# Phase 4: Self-Diagnostic Verification

> Đếm tổng items đã classify vs total inventory. Nếu < 95% → auto-fix x3 (re-classify missing files).
> Phase này tách riêng để dễ debug khi coverage thấp — KHÔNG nhồi vào batch loop của Phase 2.

**PRE-GATE:**
- Phase 3 POST-GATE PASS
- `$TOTAL_ITEMS` đã set từ Phase 1
- `$ITEMS_CLASSIFIED` cumulative từ Phase 2
- Có ít nhất 1 file `classified/batch-*.json`

**INPUT:**
- `.mc-data/work/legacy-scan/classified/batch-*.json` (tất cả)
- `.mc-data/work/legacy-scan/ledger.json` (`summary.total_items`)
- `.mc-data/work/legacy-scan/inventory/source-files.json` HOẶC `inventory/doc-classified.json`

**OUTPUT:**
- Auto-fix: thêm `classified/batch-*.json` mới (nếu missing files được phát hiện)
- Update `$ITEMS_CLASSIFIED` (cumulative)
- `error_log[]` append nếu E019

---

## Reference Sections

- `_shared.md` §Fix Rules (E019)
- `_shared.md` §Agent Prompt Templates — code-reviewer Agent (cho re-classify)
- `_shared.md` §Error Codes (E019)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | **Đếm tổng items** từ tất cả batch files: `total_classified = sum(jq '.stats.total' classified/batch-*.json)` | Read | Counted |
| 4.2 | **So sánh vs ledger**: `coverage_pct = total_classified / $TOTAL_ITEMS * 100`. Nếu `coverage_pct >= 95` → SKIP auto-fix, PASS | — | Coverage computed |
| 4.3 | **Identify missing files** (nếu `coverage_pct < 95`): <br>• `classified_paths = jq -r '.items[].path' classified/batch-*.json | sort -u` <br>• `inventory_paths = jq -r '.[].path' $INVENTORY_FILE | sort -u` <br>• `missing_paths = inventory_paths - classified_paths` | Read | Missing list ready |
| 4.4 | **Auto-fix attempt** (max 3 iterations): <br>• Tạo batch mới `batch-${next_N}.json` cho missing files (chia theo `$BATCH_SIZE` nếu nhiều) <br>• Spawn code-reviewer agent (cùng prompt như Phase 2) <br>• Validate output → recount `total_classified` <br>• Nếu coverage >= 95% → PASS | Agent | Coverage tăng |
| 4.5 | **Nếu vẫn < 95% sau 3 attempts**: log E019 vào `.mc-data/work/legacy-scan/error-ledger.json`, AskUserQuestion: "Coverage = X% (< 95%). Continue (accept low coverage) hay STOP để debug?" | AskUserQuestion | User decided |

---

## Special Cases

```
1. Skip mode: KHÔNG chạy Phase 4 (Phase 0 đã skip toàn bộ)
2. DOCS_ONLY mode: Threshold vẫn 95% nhưng tính trên doc files thay vì source
3. Nếu inventory rỗng (0 items): SKIP Phase 4, log NOTE "empty_inventory"
```

---

## Phase 4 POST-GATE

```
1. coverage_pct >= 95% (PASS)
   HOẶC: User confirm continue với coverage thấp hơn
   HOẶC: Skip mode → SKIP toàn bộ Phase 4
2. error_log có entry E019 nếu coverage < 95% (cho audit)
3. Tất cả batch files (cả mới tạo từ auto-fix) đều valid JSON
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E019 | Coverage < 95% sau 3 auto-fix attempts | Log error-ledger.json, AskUserQuestion (continue/stop) |

---

**Next phase:** `phase5-postgate.md`
