# Phase 1: Prepare — Load Context & Batch Planning

> Load inventory + project profile, tính `$UNCLASSIFIED_LIST`, tạo `classify-plan.md` từ template.
> Phase này chỉ chạy khi `$MATURITY_MODE != "skip"`.

**PRE-GATE:**
- Phase 0 POST-GATE PASS (mode != skip)
- `$BATCH_SIZE`, `$MATURITY_MODE`, `$DOCS_ONLY_MODE` đã set từ Phase 0
- `test -f .mc-data/work/legacy-scan/project-profile.json`

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/project-profile.json` (tech stack)
- `.mc-data/work/legacy-scan/inventory/source-files.json` (Source mode) HOẶC `inventory/doc-classified.json` (DOCS_ONLY)
- `.mc-data/work/legacy-scan/classified/batch-*.json` (nếu delta hoặc resume)
- `.claude/skills/workflow/wf-legacy-classify/templates/classify-plan.md`

**OUTPUT:**
- `.mc-data/work/legacy-scan/classify-plan.md` (từ template)
- In-memory state: `$INVENTORY_FILE`, `$UNCLASSIFIED_LIST`, `$TOTAL_BATCHES`, `$TOTAL_ITEMS`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Maturity Modes
- `_shared.md` §DOCS_ONLY Mode

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | **Xác định inventory file**: nếu `$DOCS_ONLY_MODE = true` → `$INVENTORY_FILE = inventory/doc-classified.json`; ngược lại → `$INVENTORY_FILE = inventory/source-files.json`. Verify file tồn tại | Read | `$INVENTORY_FILE` valid |
| 1.2 | **Load inventory** từ `$INVENTORY_FILE` → extract paths array. Set `$TOTAL_ITEMS = ledger.summary.total_items` | Read | Inventory loaded |
| 1.3 | **Compute `$UNCLASSIFIED_LIST`**: <br>• Nếu `$MATURITY_MODE == "full"` AND KHÔNG resume → `$UNCLASSIFIED_LIST = toàn bộ inventory paths` <br>• Nếu `$MATURITY_MODE == "delta"` HOẶC resume → scan tất cả `classified/batch-*.json`, collect classified paths set, compute `$UNCLASSIFIED_LIST = inventory_paths - classified_paths_set` | Read | List ready |
| 1.4 | **Validate `$UNCLASSIFIED_LIST`**: <br>• Nếu `length == 0` AND `$MATURITY_MODE != "skip"` → WARNING E022, AskUserQuestion: "Inventory không có items chưa classify. Tiếp tục (refresh) hay STOP?" <br>• Nếu user chọn STOP → exit gracefully | AskUserQuestion | User confirmed |
| 1.5 | **Tính `$TOTAL_BATCHES`**: <br>• Nếu lần đầu (KHÔNG resume): `unclassified_count = length($UNCLASSIFIED_LIST)`, `$TOTAL_BATCHES = ceil(unclassified_count / $BATCH_SIZE)` <br>• Nếu resume: GIỮ NGUYEN `$TOTAL_BATCHES = ledger.stages.classify.total_batches` (đã set lần đầu) | — | `$TOTAL_BATCHES` set |
| 1.6 | **Update ledger**: `stages.classify.batch_size = $BATCH_SIZE`. Nếu lần đầu (KHÔNG resume): `stages.classify.total_batches = $TOTAL_BATCHES`. Nếu resume: KHÔNG ghi đè total_batches | Write | Ledger updated |
| 1.7 | **Tạo classify-plan.md từ template** (CORE-031): <br>• READ `.claude/skills/workflow/wf-legacy-classify/templates/classify-plan.md` <br>• POPULATE: `[CLASSIFY-YYYYMMDD-NNN]`, `[PROJECT_NAME]`, `[BATCH_SIZE]`, `[TOTAL_ITEMS]`, `[TOTAL_BATCHES]`, `[MATURITY_MODE]`, `[YYYY-MM-DD HH:mm:ss]`, batch breakdown rows, status rows <br>• WRITE `.mc-data/work/legacy-scan/classify-plan.md` | Read+Write | Plan file created |

---

## Phase 1 POST-GATE

```
1. $UNCLASSIFIED_LIST có ít nhất 1 item (hoặc user đã confirm tiếp tục với 0 items)
2. $TOTAL_BATCHES > 0
3. test -s .mc-data/work/legacy-scan/classify-plan.md (file non-empty)
4. Plan có TẤT CẢ required sections (Meta, Scope Overview, Session Breakdown, Batch Planning, Agent Assignment, Context Sources, Expected Outputs, Checkpoint Strategy)
5. Ledger updated: batch_size + total_batches (nếu lần đầu)
```

---

## Partitioning Rule

Items chia vào batches theo thứ tự xuất hiện trong inventory file:
- Items 1 → N vào batch 1
- Items N+1 → 2N vào batch 2
- ...

Thứ tự này đảm bảo resume deterministic — cùng input luôn cho cùng batch assignments.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E022 | 0 unclassified items nhưng mode != skip | WARNING, AskUserQuestion (continue/stop) |

---

**Next phase:** `phase2-classify.md`
