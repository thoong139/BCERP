# Phase 3: Inject Annotations

> Phase nặng nhất — đọc từng file, inject comment, verify, checkpoint.
> **Chia batch theo `$BATCH_SIZE`** để tránh context overflow.
> Idempotent: skip file đã có annotation đúng, warn nếu khác target.

**PRE-GATE:**
- [ ] Phase 2 POST-GATE PASS (`$USER_CONFIRMED_MAP` loaded, `user_confirmed: true` trong map)
- [ ] `$DRY_RUN = false` (dry-run đã exit ở Phase 2)
- [ ] `$BATCH_SIZE` đã set (default 50)

**INPUT:**
- `$USER_CONFIRMED_MAP` (từ Phase 2)
- `.mc-data/work/legacy-scan/annotation-map.json`
- `annotate-checkpoint.json` (nếu `$RESUME = true`)

**State initialization:**
- `$E046_BATCH_DECISION = null` (xem `_shared.md §E046 Batch-Confirm Mechanism`)
- `$FILE_BACKUP_CACHE = {}` (xem `_shared.md §E042 Backup Mechanism`)

**OUTPUT:**
- **Source code files annotated** (Edit tool)
- `.mc-data/work/legacy-scan/annotate-checkpoint.json` (update per batch)
- `.mc-data/work/legacy-scan/annotate-status.json` (progress update)
- In-memory: `$BATCH_PROGRESS`

---

## Reference Sections

- `_shared.md` §Comment Format Table (insert format theo language)
- `_shared.md` §Annotation Existence Check (idempotent rule)
- `_shared.md` §Checkpoint Protocol (trigger conditions + template usage)
- `_shared.md` §Resume Logic (filesystem reconciliation)
- `_shared.md` §Fix Rules đặc thù (E041-E046 handling)

---

## Batch Loop Structure

```
IF $RESUME = true:
  Áp dụng _shared.md §Resume Logic → xác định pending[] files
ELSE:
  pending[] = map.entries (toàn bộ)

batches = chunk(pending, $BATCH_SIZE)
FOR batch_idx, batch IN enumerate(batches):
  execute Batch Execution Sequence (xem §Batch Execution)
  execute Post-Batch Checkpoint (xem §Post-Batch)
  
  IF $CONTEXT_PERCENT >= 80%:
    FORCE checkpoint + STOP + prompt --resume
    BREAK batch loop
```

---

## Batch Execution Sequence (mỗi entry trong batch)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Determine language từ file extension (fallback `$TECH_STACK.primary_language`). Nếu không match `_shared.md §Comment Format Table` → skip file, log E045 | — | Language resolved |
| 3.2 | Đọc file (Read — 150 lines đầu đủ để tìm insert position và tạo backup) | Read | File loaded |
| **3.2b** | **[BUG-06 — BACKUP]** Cache nội dung đầu file vào `$FILE_BACKUP_CACHE[file_path]` (150 lines hoặc toàn bộ nếu file < 150 lines) — dùng cho E042 rollback tức thì mà không cần git | — | Backup cached |
| 3.3 | Tìm insert position theo **language-specific rules** từ `_shared.md §Language-specific INSERT POSITION exceptions`: Go → sau `package` declaration; Python → sau shebang/encoding comments; Java/Kotlin → sau `package` declaration; Default → sau file header, trước first import/using. Fallback: dòng 1 | — | Position found (language-aware) |
| 3.4 | **[EXISTENCE CHECK]** Áp dụng `_shared.md §Annotation Existence Check` (Grep per language pattern) | Grep | Check done |
| 3.5 | Theo Decision Matrix (trong §Annotation Existence Check): INJECT / SKIP / E046. **E046:** áp dụng `_shared.md §E046 Batch-Confirm Mechanism` — check `$E046_BATCH_DECISION` trước khi hỏi user | Edit/AskUserQuestion | Decision applied |
| 3.6 | Nếu INJECT: build comment block theo `_shared.md §Comment Format Table`, dùng Edit để insert tại position từ Step 3.3 | Edit | Comment added |
| 3.7 | **[VERIFY POST-EDIT]** Đọc lại file (5 dòng quanh insert position) → verify comment xuất hiện đúng format. Nếu syntax break (`E042`) → ROLLBACK theo `_shared.md §E042 Backup Mechanism` (cache → git → warn), log | Read | File intact + comment verified |
| 3.8 | Cập nhật counters: `$BATCH_PROGRESS.files_done++` (nếu inject), `files_skipped++` (nếu skip), `files_error++` (nếu fail), `annotation_conflicts_count++` (nếu E046). Update `annotate-status.json.phases.phase_3` | — | Counters updated |

---

## Comment Block Format

Lấy từ `_shared.md §Comment Format Table` — ví dụ C#/TS/JS:

```
[existing file header, nếu có]

// REQ-ID: REQ-SALES-001, REQ-SALES-002
// FEAT-ID: FEAT-ERP-CRM-001

[first using/import/namespace statement]
```

**Quy tắc:**
- 1 blank line **trước** comment block (để tách khỏi header)
- Block gồm 2 dòng: REQ-ID (join bằng `, `) + FEAT-ID
- 1 blank line **sau** comment block (trước import/using)
- Nếu file không có file header → insert tại dòng 1

---

## Post-Batch Checkpoint

Sau mỗi batch (Step 3.8 done cho toàn bộ batch):

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.P1 | **[READ-TEMPLATE]** READ `templates/annotate-checkpoint.json` → POPULATE (trigger="batch_completed", position={current_phase:3, current_batch:$idx, next_batch_start_index}, progress=$BATCH_PROGRESS, partial_state={annotation_map_path, pending_files_count}) → WRITE `.mc-data/work/legacy-scan/annotate-checkpoint.json` | Read → Write | Checkpoint saved |
| 3.P2 | Cập nhật `annotate-status.json`: `phases.phase_3.batches_completed++`, `phases.phase_3.files_done`, `files_skipped`, `files_error`, `current_batch`, `progress_pct`, `annotation_stats` | Edit | Status updated |
| 3.P3 | Cập nhật shared pipeline `legacy-scan-status.json`: `stages.annotate.batch_completed`, `stages.annotate.files_done`, `stages.annotate.files_total` | Edit | Shared status updated |
| 3.P4 | Kiểm tra `$CONTEXT_PERCENT`: ≥80% → FORCE STOP sau checkpoint + prompt `--resume` | — | Context checked |

---

## Context Threshold Actions

| Context % | Action trong Phase 3 |
|-----------|----------------------|
| <65% | Tiếp tục batch tiếp theo bình thường |
| 65-80% | Hoàn tất batch hiện tại, lưu checkpoint chắc chắn, cân nhắc STOP nếu batch kế ước tính sẽ push lên 85%+ |
| 80-90% | FORCE checkpoint sau batch hiện tại, STOP skill ngay, prompt user `--resume` |
| ≥90% | FORCE checkpoint NGAY (kể cả giữa batch), STOP |

Khi STOP do context: hiển thị:
```
⚠️ Context threshold reached ($CONTEXT_PERCENT%).
Đã lưu checkpoint sau batch [N]. Files annotated: [files_done]/[files_total].
Chạy `/wf-annotate-code --resume` để tiếp tục.
```

---

## Error Aggregation

| Error | Counter | Action khi vượt threshold |
|-------|---------|---------------------------|
| E041 (file write fail) | `files_error` | >30% → STOP Phase 3, escalate user |
| E042 (file corrupt) | `corrupt_rollbacks` | Log, tiếp tục (không block) |
| E043 (checkpoint fail) | `checkpoint_fails` | ≥2 liên tiếp → STOP Phase 3 |
| E045 (unsupported language) | `files_skipped_language` | >20% → STOP, escalate |
| E046 (annotation conflict) | `annotation_conflicts` | User decision per file (không threshold) |

---

## POST-GATE

```bash
# T1-T3: Checkpoint file valid
test -s .mc-data/work/legacy-scan/annotate-checkpoint.json
jq '.' .mc-data/work/legacy-scan/annotate-checkpoint.json > /dev/null 2>&1

# T4: Tất cả files trong confirmed map đã xử lý (annotated hoặc skipped hoặc error)
# Tổng: files_done + files_skipped + files_error == total_entries trong map
jq -e '(.phases.phase_3.files_done + .phases.phase_3.files_skipped + .phases.phase_3.files_error) as $done
       | ($done == .phases.phase_3.files_total)' \
  .mc-data/work/legacy-scan/annotate-status.json

# T5: Spot-check: 5 files annotated ngẫu nhiên có REQ-ID comment đúng format
# (thực hiện bằng Grep pattern per language từ §Comment Format Table)

# T6: Không có file nào ở trạng thái corrupt (rollback counter logged but not blocking)
```

**Next phase:** `phase4-verify-report.md`

> **Lưu ý resume:** Nếu Phase 3 STOP giữa chừng do context, POST-GATE T4 KHÔNG chạy — Phase 4 chờ resume. Chỉ khi toàn bộ batches done → tiếp Phase 4.
