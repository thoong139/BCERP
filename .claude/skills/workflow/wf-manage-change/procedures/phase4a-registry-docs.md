# Phase 4a: Registry & Docs Update

> Thực hiện thay đổi docs + registry TRƯỚC code.
> Mỗi bước có mini-verify để catch inconsistency sớm.

> **Shared:** Xem `procedures/_shared.md` — Registry Safe-Write Rules (CORE-006), Fix Rules, Checkpoint Protocol.

---

## DRY-RUN STOP GATE (chạy trước tiên)

```
IF $DRY_RUN == true:
  → Hiển thị: "Dry-run hoàn tất. Các thay đổi đã được phân tích và lập kế hoạch nhưng KHÔNG được thực hiện."

  → Update $SESSION_DIR/change-status.json:
      status = "completed"
      flags.dry_run = true
      phases 4a/4b/4c/5 → status = "skipped" (ghi rõ là dry-run skip)

  → Tạo $SESSION_DIR/change-report.md: READ template `templates/change-report.md`
    → POPULATE nội dung dry-run (chỉ ghi kế hoạch, không ghi thay đổi thực tế) → WRITE

  → Tạo $SESSION_DIR/phase-summary.md (CORE-028) — tóm tắt kế hoạch thay đổi bằng tiếng Việt
    (những gì SẼ được thay đổi nếu thực hiện)

  → Update index.json: sessions[$CHANGE_ID].status = "completed"

  → [S2] Append sessions.jsonl complete entry:
    `bash .claude/scripts/wf-manage-change/mc-index-append.sh --change-id=$CHANGE_ID --status=completed --summary="$USER_PROMPT" --change-type=$CHANGE_TYPE --risk-level=$RISK_LEVEL`

  → [S2] Cleanup heartbeat + release session lock:
    ① `kill $HEARTBEAT_PID 2>/dev/null || true`
    ② `bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=session --id=$CHANGE_ID`
    ③ `trap - EXIT` (disable EXIT trap — cleanup done explicitly)

  → CORE-026: Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json` (mode: dry_run)

  → STOP — KHÔNG tiếp tục xuống Steps 4a.1+
```

---

## PRE-GATE

- Phase 3 PASSED
- User approved plan
- `$DRY_RUN == false`
- `$SESSION_DIR/change-plan.md` tồn tại

---

## INPUT

- `$SESSION_DIR/change-plan.md`
- `$SESSION_DIR/affected-artifacts.json`
- Registry + doc source files

---

## OUTPUT

- Updated `req-registry.json`
- Updated doc files (theo `docs_affected[]`)
- Registry backup: `req-registry.json.pre-change-[timestamp]`
- `$SESSION_DIR/checkpoint.json`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4a.1 | **Backup registry:** `bash .claude/scripts/wf-manage-change/mc-backup-registry.sh` — tạo backup với timestamp + SHA256 checksum (S1 script). Lưu `$REGISTRY_BACKUP` từ JSON output (`backup_path`) để dùng cho rollback nếu cần (E012). | Bash | Backup exists, checksum logged |
| 4a.2 | **[CDG — DELETE_FEATURE only] Critical Decision Gate (CORE-027)** — xem §CDG Protocol dưới | AskUserQuestion | Confirmed hoặc Cancelled |
| 4a.3 | **FOR each doc task (sequential):** Đọc current → apply change → write | Read/Edit | File updated |
| 4a.4 | **Mini-verify sau mỗi doc:** Check consistency với registry + upstream docs | Grep | Consistent |
| 4a.5a | **[S2] Acquire registry lock:** `bash .claude/scripts/wf-manage-change/mc-acquire-lock.sh --type=registry --id=$CHANGE_ID` — cross-session lock chống concurrent registry write. NẾU lock fail (exit 1) → registry đang được session khác update → STOP với WARNING + log vào `change-status.json.error_log[]`. **BỎ QUA nếu không cần update registry** (Step 4a.5b skip cho doc-only changes). | Bash | `.locks/registry.lock` exists |
| 4a.5b | **Registry update** (nếu cần): ĐỌC registry → apply safe-write theo `_shared.md` §Registry Safe-Write Rules → atomic write → `bash .claude/scripts/wf-manage-change/mc-validate-registry.sh` (S1 — T1-T4 validation: file exists, non-empty, valid JSON, requirements count > 0). NẾU validate fail → rollback từ `$REGISTRY_BACKUP` → release registry lock → E012 STOP. | Read/Write/Bash | JSON valid, validate output `{"valid":true}` |
| 4a.5c | **[S2] Release registry lock:** `bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=registry --id=$CHANGE_ID` — release cross-session lock NGAY sau khi registry update + validate xong. **BỎ QUA nếu Step 4a.5a bị skip.** **LƯU Ý:** Lock PHẢI release dù validate fail (sau rollback) hay pass — tránh stale registry lock chặn các session khác. | Bash | `.locks/registry.lock` không tồn tại |
| 4a.6 | **Checkpoint:** READ template `templates/checkpoint.json` → POPULATE progress + position → WRITE `$SESSION_DIR/checkpoint.json` | Write | Checkpoint saved |

---

## CDG Protocol — DELETE_FEATURE (CORE-027)

NẾU `$CHANGE_TYPE == "DELETE_FEATURE"`:

```
AskUserQuestion:
  "⚠️ Bạn sắp xóa vĩnh viễn [FEAT-ID: tên feature].
   Thao tác này KHÔNG THỂ HOÀN TÁC nếu không có git.

   Để tiếp tục, gõ chính xác:
     CONFIRM DELETE [FEAT-ID]

   Hoặc gõ 'CANCEL' để dừng."

IF input != "CONFIRM DELETE [FEAT-ID]":
  → STOP
  → Hướng dẫn user chạy lại khi sẵn sàng
  → KHÔNG đánh dấu session "cancelled" (cho phép resume)

IF input == "CONFIRM DELETE [FEAT-ID]":
  → Log confirmation trong change-status.json.cdg_confirmations[]
  → Tiếp tục Step 4a.3
```

---

## Registry Safe-Write — Chi tiết theo change_type

Xem `_shared.md` §Registry Safe-Write Rules để nắm nguyên tắc chung.

**Quick reference cho Phase 4a.5:**

| `$CHANGE_TYPE` | Action chi tiết |
|----------------|-----------------|
| `MODIFY_REQUIREMENT` | Tìm REQ-ID trong `requirements[]` → UPDATE description/acceptance_criteria theo user input |
| `CLARIFY_REQ` | APPEND info vào `requirements[].description` hoặc `notes`. KHÔNG đổi REQ-ID. Nếu chỉ là doc-only clarification → **SKIP Step 4a.5** |
| `ADD_FEATURE` | APPEND entry mới vào `features[]`. Generate FEAT-ID mới (không trùng). Set `impl_status = "not_started"` |
| `MODIFY_FEATURE` | Tìm FEAT-ID trong `features[]` → UPDATE description/flow. Nếu `impl_status == "done"` VÀ logic thay đổi thật: SET `impl_status = "in_progress"`, note `"Modified by wf-manage-change $CHANGE_ID"`. Phase 4b sẽ set lại `"done"` sau code update. |
| `DELETE_FEATURE` | Tìm FEAT-ID → SET `impl_status = "skipped"`, thêm `deprecated_at`, `deprecated_by = $CHANGE_ID`. **KHÔNG xóa entry** (giữ audit trail). |

**Validate sau write (Step 4a.5b):**

```bash
bash .claude/scripts/wf-manage-change/mc-validate-registry.sh
# Output: {"valid":true,"requirements_count":N,"size_bytes":N} → exit 0
# Hoặc:   {"valid":false,"error":"<reason>"}                  → exit 1
```

Script thực hiện T1→T4 validation:
- T1 (existence): file tồn tại
- T2 (non-empty): size > 0
- T3 (format): valid JSON
- T4 (content): `requirements[]` length > 0

Nếu validate fail → rollback từ `$REGISTRY_BACKUP` → release registry lock (4a.5c) → E012 → STOP.

---

## Mini-Verify Protocol (Step 4a.4)

Sau mỗi doc update:

1. **Consistency check:** Doc mới reference tới REQ-IDs/FEAT-IDs hợp lệ trong registry
2. **Upstream check:** Nếu doc là Phase 2+, verify REQ-IDs tồn tại trong Phase 1
3. **Heading check:** Required sections của doc-framework vẫn đầy đủ

Nếu fail → log warning vào `change-status.json.error_log[]` → tiếp tục. Nếu 3+ mini-verify fail liên tiếp → STOP (E011).

---

## Checkpoint Save Points

Save checkpoint sau:

- Bước 4a.5 (sau registry update)
- Bước 4a.6 (bắt buộc cuối Phase 4a)
- Mỗi 3 doc files updated trong Step 4a.3

---

## POST-GATE

- Tất cả doc tasks trong `change-plan.md.execution_order[group=doc_updates].tasks[]` đã hoàn thành
- Registry (nếu update) đã pass `mc-validate-registry.sh` (T1-T4)
- Backup registry tồn tại với checksum
- **[S2]** Registry lock đã release (`.locks/registry.lock` không tồn tại sau Phase 4a)
- `$SESSION_DIR/checkpoint.json` saved với `current_phase = "phase4b"`
- Mọi mini-verify fails đã log

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/checkpoint.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase4a.status = "completed"` → tiếp tục `procedures/phase4b-code.md`.
