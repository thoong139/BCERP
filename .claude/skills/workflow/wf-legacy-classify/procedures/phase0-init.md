# Phase 0: PRE-GATE + Init

> Entry point của skill. Parse arguments, kiểm tra prerequisites, xử lý `--status`/`--resume`,
> đọc maturity mode, và quyết định route tiếp theo (skip / continue).
> Đọc file này NGAY KHI SKILL.md route vào procedures/.

**PRE-GATE (dual-mode — v5.0 Phase D):**

Chấp nhận 2 nguồn state (theo thứ tự ưu tiên):

1. **v5.0 scan-state.json** — `.mc-data/work/legacy-scan/sessions/<sid>/scan-state.json`:
   - Active session (status ∈ {in_progress, paused}) → đọc `layers.L3.status` (inventory); nếu != `completed` → STOP (E001) với status-specific message.
   - Nếu L3 là `skipped_by_profile` → tiếp tục (maturity skip hợp lệ).

2. **v4.1 ledger.json** (fallback) — `.mc-data/work/legacy-scan/ledger.json`:
   - `test -f` → nếu không có file → STOP (E001): "Chưa có scan data. Chạy `/wf-legacy-scan` trước."
   - `jq -r '.stages.inventory.status' ledger.json == "completed"` — nếu != "completed" → STOP (E001) với message tùy theo status:
     - `"pending"` / `"not_started"`: "Chưa chạy scan. Chạy `/wf-legacy-scan [project-path]`."
     - `"in_progress"`: "Scan bị gián đoạn. Chạy `/wf-legacy-scan --resume`."
     - `"failed"` / khác: "Scan thất bại. Kiểm tra logs và chạy `/wf-legacy-scan --resume`."

> Helper `init_or_load_session()` tự động xử lý fallback (active session → migrate ledger → fail).
> Xem `_shared.md §Scan-State Integration (v5.0 Phase D)`.

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json` (BẮT BUỘC)
- `.mc-data/work/legacy-scan/checkpoint.json` (nếu `--resume`)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (nếu `--resume` hoặc `--status`)
- `$ARGUMENTS` (CLI args)

**OUTPUT:**
- In-memory state: `$ARGS`, `$BATCH_SIZE`, `$MATURITY_MODE`, `$MATURITY_LEVEL`, `$DOCS_ONLY_MODE`, `$BATCH_OFFSET` (nếu resume)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (init/update — chỉ field stages.classify)
- Ledger update (chỉ khi `--status` hoặc skip mode): `stages.classify.status = "completed"` với note `"skipped_maturity"`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Maturity Modes
- `_shared.md` §DOCS_ONLY Mode
- `_shared.md` §Scan-State Integration (v5.0 Phase D)
- `_shared.md` §Checkpoint Protocol
- `_shared.md` §Error Codes

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | **Parse arguments** từ `$ARGUMENTS`: `--resume`, `--batch-size=N` (default 100), `--status`. Set `$ARGS = {resume: bool, batch_size: int, status: bool}`. Validate `batch_size >= 10 && batch_size <= 500` — nếu ngoài range → STOP (E023) | — | Args validated |
| 0.2 | **Đọc ledger.json** — extract `project.name`, `summary.total_items`, `maturity` object. Set `$MATURITY_MODE = ledger.maturity.stage_modes.classify` (`full` / `delta` / `skip`). Set `$MATURITY_LEVEL = ledger.maturity.maturity_level`. Set `$DOCS_ONLY_MODE = (maturity_level == "DOCS_ONLY")` | Read | Ledger loaded, mode determined |
| 0.3 | **Nếu `--status`**: chạy `--status` Handler (xem §--status Handler bên dưới), STOP. KHÔNG thay đổi data | Read | Status displayed |
| 0.4 | **Nếu `--resume`**: chạy Resume Logic (xem §Resume Logic bên dưới). Sau khi resume xong, set `$BATCH_OFFSET` từ reconciliation. Tiếp tục Phase 1 | Read+Write | Checkpoint loaded, batch_offset reconciled |
| 0.5 | **Nếu `$MATURITY_MODE == "skip"`**: chạy Skip Mode Handler (xem §Skip Mode Handler bên dưới), STOP. KHÔNG chạy Phase 1-5 | Read+Write | Stage skipped, ledger marked completed |
| 0.6 | **Set `$BATCH_SIZE`**: ưu tiên args (`$ARGS.batch_size`), fallback `ledger.stages.classify.batch_size`, default `100` | — | `$BATCH_SIZE` set |
| 0.7 | **Init/Update legacy-scan-status.json**: set `stages.classify.status = "in_progress"`, `stages.classify.started_at = ISO_NOW`, `current_stage = "classify"`. Nếu file chưa tồn tại → tạo từ template (xem `wf-legacy-scan` template) | Read+Write | Status file ready |
| 0.8 | **[PHASE D — Scan-state init]** Gọi `init_or_load_session(project_path)` từ helper scan_state_reader; lưu `$SESSION_ID`. Nếu helper raise `RuntimeError("No prior scan")` → STOP E001. Sau đó gọi `update_layer_status("L4", "in_progress")`. **Note:** nếu L4 đã `completed` (idempotent re-run), helper raise ValueError → WARN và tiếp tục (resume path). Xem `_shared.md §Scan-State Integration` | Bash (Python helper) | `$SESSION_ID` set, L4 marked in_progress |
| 0.9 | **Set `$BATCH_OFFSET = 0`** (nếu KHÔNG resume), `$BATCH_OFFSET = ledger.stages.classify.completed_batches` (nếu resume sau reconciliation) | — | Offset ready |

---

## Phase 0 POST-GATE

```
1. Arguments parsed thành công, batch_size trong [10, 500]
2. Ledger đã load, $MATURITY_MODE ∈ {full, delta, skip}
3. Nếu mode != skip: tiếp tục Phase 1
4. Nếu mode == skip: đã hiển thị CLASSIFY SKIPPED report → STOP
5. Nếu --status: đã hiển thị progress → STOP
```

---

## --status Handler

```
1. Đọc ledger.json → extract:
   - project.name
   - stages.classify.{status, batch_size, completed_batches, total_batches, items_classified}
   - summary.{total_items, systems_detected, modules_detected}
   - maturity.stage_modes.classify

2. Đọc legacy-scan-status.json → next_action, error_log

3. Tính:
   - actual_batches = find .mc-data/work/legacy-scan/classified/ -name "batch-*.json" | wc -l
   - percentage = round(items_classified / total_items * 100)

4. Tổng hợp categories từ batch files (sum stats.by_category)

5. Hiển thị format (xem SKILL.md §--status Display Format), STOP
```

---

## Resume Logic

```
1. RECONCILIATION:
   actual_batches = $(find .mc-data/work/legacy-scan/classified/ -name "batch-*.json" 2>/dev/null | wc -l)
   first_missing_batch = N nhỏ nhất mà classified/batch-N.json chưa tồn tại
   (vd: có batch-1.json, batch-2.json, batch-4.json → first_missing_batch = 3)

2. UPDATE ledger:
   stages.classify.completed_batches = actual_batches

3. UPDATE legacy-scan-status.json:
   stages.classify.completed_batches = actual_batches
   next_action = "Resume từ batch " + first_missing_batch

4. VALIDATE existing batch files:
   FOR each classified/batch-*.json:
     IF NOT (jq '.' valid) OR (stats.total < 1):
       → WARNING E020, xóa file, đánh dấu N để re-classify
       → log vào error_log

5. SET in-memory:
   $BATCH_OFFSET = first_missing_batch - 1
   (Loop trong Phase 2 sẽ bắt đầu từ batch_offset + 1 = first_missing_batch)

6. LOG: "Reconciled: [actual_batches] batch files trên disk, tiếp tục từ batch [first_missing_batch]"

7. CONTINUE — fall through Phase 1
```

---

## Skip Mode Handler

```
1. UPDATE ledger.json:
   stages.classify.status = "completed"
   stages.classify.note = "skipped_maturity"
   stages.classify.completed_at = ISO_NOW

2. UPDATE legacy-scan-status.json:
   stages.classify.status = "completed"
   stages.classify.note = "skipped_maturity"
   current_stage = "extract"
   next_action = "Stage 3: Extract"

2b. [PHASE D] UPDATE scan-state (nếu session đã init qua Step 0.8):
   update_layer_status("L4", "skipped_by_profile")
   (Best-effort — nếu helper fail, log WARNING và tiếp tục.)

3. HIỂN THỊ CLASSIFY SKIPPED report:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   CLASSIFY SKIPPED — [project_name]
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Reason:      Maturity level [maturity_level] — classify not needed
   Status:      completed (skipped_maturity)
   Next step:   /wf-legacy-extract

4. STOP — KHÔNG chạy Phase 1-5
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | PRE-GATE fail (ledger missing hoặc inventory not completed) | STOP với message tùy theo inventory status |
| E023 | `--batch-size` ngoài range [10, 500] | STOP, hiển thị valid range |

---

**Next phase:** `phase1-prepare.md` (nếu mode != skip và không phải `--status`)
