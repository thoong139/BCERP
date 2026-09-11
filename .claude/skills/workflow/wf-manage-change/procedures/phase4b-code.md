# Phase 4b: Code Update

> Thực hiện thay đổi code theo plan. Backup trước, apply, mini-verify sau mỗi file.
> Có thể SEQUENTIAL hoặc PARALLEL giữa modules tùy parallel eligibility.

> **Shared:** Xem `procedures/_shared.md` — Fix Rules, Checkpoint Protocol.

---

## PRE-GATE

- Phase 4a PASSED
- `$DRY_RUN == false`
- `$SESSION_DIR/change-plan.md` chứa `code_changes` group
- `$SESSION_DIR/affected-artifacts.json.code_affected[]` non-empty

---

## INPUT

- `$SESSION_DIR/change-plan.md` — code tasks
- `$SESSION_DIR/affected-artifacts.json` — code files + types
- Source code files

---

## OUTPUT

- Updated code files (với REQ-ID comments được preserve)
- Code file backups: `[file].pre-change-[timestamp]`
- `$SESSION_DIR/checkpoint.json` updated

---

## Parallel Eligibility (CORE-025)

Điều kiện để chạy PARALLEL giữa modules:

| Điều kiện | Mô tả |
|-----------|-------|
| ✅ Owner rõ | Mỗi module có đúng 1 owner (không có file dùng chung) |
| ✅ Không phụ thuộc | Các module không import/sử dụng code của nhau (kiểm tra từ Dependency scan Phase 2.2) |
| ✅ Contract ổn định | API contract giữa các module đã ổn định (không thay đổi interface) |
| ✅ Merge checkpoint | Có merge checkpoint sau khi tất cả modules hoàn thành |

**Nếu không đủ 4 điều kiện → SEQUENTIAL** (an toàn hơn).

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4b.0 | **Parallel check:** Đánh giá các module trong `code_affected[]` có đủ 4 điều kiện parallel không → set strategy (SEQ/PAR) trong change-status.json | — | Strategy set |
| 4b.0.5 | **Code file backup (trước khi modify bất kỳ file nào)** — xem §Backup Protocol | Bash | Backup files exist |
| 4b.1 | **FOR each code task (per module) [SEQ hoặc PAR tùy 4b.0]:** Đọc current code + REQ-ID references | Read | Code loaded |
| 4b.2 | Apply code change (preserve REQ-IDs, update if needed) — xem §Code Change Rules | Edit | Change applied |
| 4b.3 | **Mini-verify:** Check no syntax errors, imports resolve | Grep/Bash | No errors |
| 4b.4 | **Checkpoint** (sau mỗi module hoặc mỗi 3 files): READ template `templates/checkpoint.json` → POPULATE → WRITE | Write | Checkpoint saved |
| 4b.5 | **[NẾU PARALLEL] Merge checkpoint:** Sau khi tất cả modules PAR xong → cross-check không có file bị ghi đè, validate toàn bộ REQ-IDs nhất quán | Grep/Read | No conflicts |
| 4b.6 | **Sync MODIFY_FEATURE impl_status back to "done":** Nếu `$CHANGE_TYPE == MODIFY_FEATURE` và registry đã set `impl_status = "in_progress"` ở 4a.5 → UPDATE back to `"done"` sau khi code xong | Read/Write | Registry synced |

---

## Backup Protocol (Step 4b.0.5)

```bash
for file in code_affected[]; do
  cp "$file" "${file}.pre-change-$(date +%s)"
done
```

**Nếu git không detected:**

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

fail → WARNING:

> ⚠️ Không tìm thấy git repo. Backup thủ công đã tạo: `[file].pre-change-[timestamp]`.
> Khuyến nghị: init git trước khi tiếp tục để có rollback tốt hơn.

Backup paths được log vào `change-status.json.backups[]` để rollback nếu cần.

---

## Code Change Rules

### Mọi code change bắt buộc

1. **Preserve existing REQ-ID comments** — không xóa `// REQ-ID: REQ-XXX`
2. **Thêm REQ-ID mới** nếu code mới thêm (map từ registry)
3. **KHÔNG xóa REQ-IDs** của features không bị thay đổi
4. **Nếu DELETE_FEATURE** → remove code + comment `// DEPRECATED: FEAT-XXX removed by $CHANGE_ID`
5. **VERIFY_ONLY mode** → đọc và xác nhận code, KHÔNG sửa

### REQ-ID format check

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```

Mini-verify (Step 4b.3) phải check format đúng — nếu sai → log warning + continue.

---

## Mini-Verify Protocol (Step 4b.3)

Sau mỗi file code update:

1. **Syntax check** — tùy ngôn ngữ:
   - TypeScript/JavaScript: `grep -c "^\s*\(function\|class\|const\|export\)"` đếm exports khớp
   - Python: `python -m py_compile [file]` nếu available
   - Các ngôn ngữ khác: basic brace/paren matching
2. **Import resolution** — Grep imports → verify mỗi import path tồn tại
3. **REQ-ID preservation** — Grep `REQ-ID:` count trước vs sau — số lượng không giảm (trừ DELETE_FEATURE)

Nếu fail → rollback file từ backup → retry 1 lần → nếu vẫn fail → **ESCALATE (E010) với registry rollback bắt buộc (GAP-3 fix):**

```
ESCALATE PROCEDURE khi Phase 4b fail không thể recover:

1. Rollback tất cả code files từ backup:
   for file in code_affected[]:
     IF backup tồn tại (.pre-change-*): cp backup file
     ELSE: WARNING "Không tìm thấy backup cho $file — không thể rollback tự động"

2. REGISTRY ROLLBACK (BẮT BUỘC nếu Phase 4a đã update registry):
   IF tồn tại req-registry.json.pre-change-*:
     cp req-registry.json.pre-change-[timestamp] req-registry.json
     jq '.' req-registry.json → validate → log trong error_log[]
     Log: "Registry rolled back to pre-change state due to Phase 4b failure"
   ELSE:
     WARNING "Không tìm thấy registry backup — registry có thể ở trạng thái in_progress"
     Log E012-like entry trong error_log[]
     Hướng dẫn user: "Cần manually restore impl_status về giá trị trước thay đổi"

3. Update change-status.json:
   phases.phase4b.status = "failed"
   error_log[].append({phase: "phase4b", code: "E010", registry_rollback: true/false})

4. STOP với message đầy đủ:
   - Files đã rollback
   - Registry đã rollback (hoặc cảnh báo nếu không rollback được)
   - Hướng dẫn user xem xét lỗi và chạy lại
```

---

## Merge Checkpoint (Step 4b.5 — PARALLEL only)

Sau khi tất cả modules PAR xong:

1. **File overlap check:** List tất cả files updated → verify không có file nào được edit bởi 2+ modules
2. **REQ-ID consistency check:** Grep toàn bộ REQ-IDs trong files đã thay đổi → so với registry
3. **Cross-module contract check:** Nếu có interface/type shared → verify signature nhất quán

Nếu có conflict → log vào `change-status.json.error_log[]` + hỏi user decision (rollback hoặc resolve manual).

---

## Checkpoint Save Points

- Sau mỗi module (SEQUENTIAL mode)
- Sau mỗi 3 files (nếu module lớn)
- Bắt buộc tại 4b.4 cuối mỗi module
- Bắt buộc tại 4b.5 nếu PARALLEL
- Bắt buộc khi context > 80%

---

## POST-GATE

- Tất cả code tasks trong `change-plan.md.execution_order[group=code_changes].tasks[]` đã hoàn thành
- Tất cả files đều pass mini-verify (hoặc được log nếu warning)
- Backup files tồn tại cho mọi file đã modify
- `$SESSION_DIR/checkpoint.json` saved với `current_phase = "phase4c"`
- `change-status.json.metrics.files_updated` đã được update

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/checkpoint.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase4b.status = "completed"` → tiếp tục `procedures/phase4c-tests.md`.
