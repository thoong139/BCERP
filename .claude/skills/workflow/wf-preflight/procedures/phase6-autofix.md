# Phase 6: Auto-fix + Phase 6.5: Re-score (Conditional — chỉ khi `--fix`)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — Fix Rules, Error Escalation Matrix, Checkpoint Protocol, NULL Redistribution

Tự động sửa các lỗi CÓ THỂ sửa được. Sau khi fix xong, re-score để report phản ánh trạng thái SAU fix.

---

## PRE-GATE

```
test "$HAS_FIX_FLAG" = "true"
```

Nếu `$HAS_FIX_FLAG != "true"` → SKIP toàn bộ Phase 6 + 6.5, nhảy thẳng sang Phase 7.

> **CHECKPOINT BẮT BUỘC:** Trước khi bắt đầu Phase 6, save `checkpoint.json` với `trigger = "pre_fix"`. Checkpoint này PHẢI chứa `file_snapshots` — snapshot nội dung của các files sẽ bị sửa (xem bên dưới). Đây là cơ chế rollback duy nhất cho E010.

---

## CDG Point 1 — Pre-fix Confirmation (CORE-027, D3)

**Áp dụng trước bước 6.0a.** Trước khi thực hiện bất kỳ write nào:

```bash
# Count fixable issues
N_REGISTRY=$(echo "$REGISTRY_ISSUES" | jq '[.[] | select(.fixable==true and .category=="registry_syntax")] | length' 2>/dev/null || echo 0)
N_ORPHAN=$(echo "$SYNC_ISSUES" | jq '[.[] | select(.fixable==true and .category=="code_orphan")] | length' 2>/dev/null || echo 0)
N_TOTAL=$((N_REGISTRY + N_ORPHAN))

if [[ $N_TOTAL -eq 0 ]]; then
  # Không có gì để fix → skip CDG, đi thẳng tới POST-GATE
  FIX_LOG="[]"
else
```

Render CDG banner:
```
╔══════════════════════════════════════════════════════════════╗
║  ⚠️  CRITICAL DECISION: /wf-preflight --fix                  ║
║                                                              ║
║  Sẽ thực hiện:                                               ║
║    Registry syntax fixes:  {N_REGISTRY} items               ║
║    Orphan file fixes:       {N_ORPHAN} items (thêm REQ-ID)  ║
║    Tổng thay đổi:           {N_TOTAL} items                  ║
║                                                              ║
║  Registry backup:                                            ║
║    {SESSION_DIR}/registry.snapshot.pre-fix                   ║
║  Rollback khả dụng nếu fix gây lỗi mới.                     ║
║                                                              ║
║  CI/CD bypass: MCV3_PREFLIGHT_FIX_NO_CONFIRM=1              ║
╚══════════════════════════════════════════════════════════════╝

Xác nhận? (yes/no/dry-run) [default: no]:
```

- **yes** → proceed với bước 6.0a (snapshot + fix loop)
- **no** → abort Phase 6, set `phase_6.status="skipped"`, `phase_6.skip_reason="user declined"` → Phase 7
- **dry-run** → simulate, hiển thị diff dự kiến, KHÔNG ghi file → Phase 7
- **CI/CD:** `MCV3_PREFLIGHT_FIX_NO_CONFIRM=1` → auto-yes

```bash
fi  # end N_TOTAL check
```

---

## File Snapshot (trước khi fix — bắt buộc cho E010 rollback)

```
TRƯỚC KHI sửa bất kỳ file nào trong Phase 6:
  1. Liệt kê tất cả files sẽ bị modify:
     - req-registry.json (nếu có registry_json_invalid hoặc id_format_error)
     - Các orphan code files (nếu có orphan_code_file issues)

  2. Backup registry:
     cp "$REGISTRY_PATH" "$SESSION_DIR/registry.snapshot.pre-fix"

  3. Đọc nội dung gốc của từng file → lưu vào checkpoint.partial_state.file_snapshots:
     {
       ".mc-data/docs/_meta/req-registry.json": "<content>",
       "src/finance/service.ts": "<content>",
       ...
     }

  4. WRITE $SESSION_DIR/checkpoint.json với file_snapshots populated (CORE-031: từ template)

  5. VERIFY: test -s $SESSION_DIR/checkpoint.json

  CHỈ SAU ĐÓ mới bắt đầu thực hiện các fixes.
```

---

## Phase 6: Auto-fix Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.0 | Liệt kê tất cả fixable issues từ `$REGISTRY_ISSUES` + `$SYNC_ISSUES`. Nếu `fixable_count = 0` → SKIP Phase 6 steps 6.1-6.4, nhảy sang Phase 6 POST-GATE với `$FIX_LOG = []`. **KHÔNG lưu checkpoint khi không có gì để fix.** | fixable_count known |
| 6.0a | (Chỉ khi fixable_count > 0, sau CDG Point 1 confirm) Backup registry → lưu file_snapshots vào checkpoint | Checkpoint saved + backup exists |
| 6.0b | **Acquire registry lock:** `bash .claude/scripts/wf-preflight/pf-acquire-lock.sh registry "$SESSION_DIR" 30`. Parse `{status:"acquired"}`. Ghi `lock.registry_lock_acquired=true` vào status.json. | Lock acquired |
| 6.1 | Fix `registry_json_invalid`: sửa syntax lỗi JSON trong `req-registry.json` (chỉ syntax — không thay đổi nội dung semantic) | `jq '.' registry.json` PASS |
| 6.2 | Fix `id_format_error`: chuẩn hóa format REQ-IDs theo `registry.id_format` | Format valid |
| 6.3 | Fix `orphan_code_file`: thêm REQ-ID comment vào đầu file (tìm REQ-ID phù hợp từ registry theo tên file/path). Nếu không xác định được REQ-ID phù hợp → SKIP file này, escalate | Files updated |
| 6.4 | Log tất cả changes vào `$FIX_LOG` với per-fix verify (CDG Point 2 — xem §Per-fix Verify Loop bên dưới) | Fix log populated |
| 6.4a | **Release registry lock:** `bash .claude/scripts/wf-preflight/pf-release-lock.sh registry "$SESSION_DIR"` | Lock released |

---

## CDG Point 2 — Per-fix Verify Loop (D3)

Sau mỗi fix operation, verify ngay:

```bash
FIX_LOG=()
FIX_PASS_COUNT=0
FIX_FAIL_COUNT=0

for fix in "${FIX_PLAN[@]}"; do
  DESCRIPTION="${fix.description}"
  FILE="${fix.file}"
  FIX_TYPE="${fix.type}"

  # Apply fix
  apply_fix "$fix"

  # Verify
  case "$FIX_TYPE" in
    "registry_syntax") VERIFY=$(jq '.' "$FILE" 2>&1 && echo "OK" || echo "FAIL") ;;
    "orphan_file")     VERIFY=$(grep -q "${fix.req_id}" "$FILE" 2>&1 && echo "OK" || echo "FAIL") ;;
  esac

  if [[ "$VERIFY" == "OK" ]]; then
    FIX_LOG+=("{\"fix\":\"$DESCRIPTION\",\"file\":\"$FILE\",\"status\":\"pass\"}")
    FIX_PASS_COUNT=$((FIX_PASS_COUNT + 1))
    echo "✅ Fix $((FIX_PASS_COUNT+FIX_FAIL_COUNT))/${#FIX_PLAN[@]}: $DESCRIPTION — PASS"
  else
    # E010: rollback + log
    rollback_file "$FILE"
    FIX_LOG+=("{\"fix\":\"$DESCRIPTION\",\"file\":\"$FILE\",\"status\":\"failed\",\"rollback\":\"applied\"}")
    FIX_FAIL_COUNT=$((FIX_FAIL_COUNT + 1))
    echo "⚠️ Fix $((FIX_PASS_COUNT+FIX_FAIL_COUNT))/${#FIX_PLAN[@]}: $DESCRIPTION — FAIL (rollback applied)"
  fi
done
```

---

## CDG Point 3 — Post-fix Summary (D3)

Sau khi toàn bộ fix loop xong:

```
═══════════════════════════════════════════════���
✅ /wf-preflight --fix hoàn thành

   Kết quả: {FIX_PASS_COUNT}/{N_TOTAL} thành công
   Rollback: {FIX_FAIL_COUNT} items (xem chi tiết trong report)

   Score trước fix: {PRE_FIX_OVERALL}%
   Score sau fix:   {POST_FIX_OVERALL}%  (tính lại ở Phase 6.5)

════════════════════════════════════════════════
```

Ghi vào `$SESSION_DIR/preflight-status.json`: `phase_6.fixes_succeeded`, `phase_6.fixes_rolled_back`.

---

## KHÔNG Auto-fix (escalate)

- **Missing docs** → quá phức tạp, dùng skill tương ứng (Log + link skill)
- **Test failures** → phải sửa code logic (Log + escalate)
- **Type/compile errors** → phải sửa code (Log + escalate)
- **Duplicate IDs** → cần user quyết định (STOP + hỏi user)
- **impl_status downgrade** → cần user xác nhận (STOP + hỏi user)

> Xem `_shared.md` §Fix Rules để đầy đủ bảng fix strategy + escalation conditions.

---

## Rollback Protection (E010)

Sau mỗi fix operation, verify file vừa sửa không bị lỗi mới:
- registry.json: chạy `jq '.' req-registry.json` → nếu fail → E010
- code files: chạy compile check (nếu TypeScript: `npx tsc --noEmit` trên file đó) → nếu fail → E010

Nếu phát hiện lỗi mới (E010):
1. Đọc nội dung gốc từ `checkpoint.partial_state.file_snapshots["<file_path>"]`
2. WRITE nội dung gốc lại vào file (rollback)
3. Verify: nội dung file sau rollback == nội dung trong snapshot
4. Log "Fix regression — rolled back [file]: [mô tả lỗi mới]"
5. Escalate to user: hiển thị diff (original vs attempted fix) và lý do rollback
6. Tiếp tục với các files khác trong fix list (không abort toàn bộ Phase 6)

---

## Phase 6 POST-GATE

```
test "$HAS_FIX_FLAG" != "true" || test -n "$FIX_LOG"
```

- `$FIX_LOG` = array fixes đã apply (có thể rỗng `[]` nếu không có fixable issues hoặc fixable_count = 0)
- Status file: `phases.phase_6.status = "completed"` với `fixes_applied` count
- Nếu skip vì fixable_count = 0: status = "completed", fixes_applied = 0, skip_reason = "no fixable issues found"

---

## Phase 6.5: Re-score After Fix

> PRE-GATE: `test "$HAS_FIX_FLAG" = "true" && test -n "$FIX_LOG"` (có ít nhất 1 fix đã apply)
> Nếu `$FIX_LOG = []` (không có fix nào) → SKIP Phase 6.5, dùng scores cũ.

| Step | Action | Verify |
|------|--------|--------|
| 6.5.1 | Đọc `$PRE_FIX_SCORES` (đã capture cuối Phase 5b, TRƯỚC Phase 6): `{registry, docs, sync, quality}` | Available |
| 6.5.2 | Re-scan Phase 4 (orphan files đã fix → `sync_score` có thể tăng) | New sync_score |
| 6.5.3 | Re-scan Phase 2 (registry format đã fix → `registry_score` có thể tăng) | New registry_score |
| 6.5.4 | Tính `$POST_FIX_SCORES` mới | Scores updated |
| 6.5.5 | Hiển thị delta trong report: "Before fix: X% → After fix: Y%" | Delta shown |

> **Lý do:** Nếu không re-score, report vẫn hiển thị score cũ dù đã fix xong — gây confusing cho user.

---

## NULL Redistribution (khi re-score)

> Xem `_shared.md` §NULL Redistribution Algorithm — áp dụng giống Phase 7 nếu có phase bị skip.

---

## Phase 6.5 POST-GATE

`$POST_FIX_SCORES` có giá trị (dù = `$PRE_FIX_SCORES` nếu không có thay đổi).

Status file: `phases.phase_6_5.status = "completed"`.

---

## Output → Next Phase

- `$FIX_LOG` (in-memory) — đọc bởi Phase 7 để render "Auto-fixes" section
- `$POST_FIX_SCORES` — đọc bởi Phase 7 thay cho `$SCORES` gốc
- Status file: `phases.phase_6.fixes_applied = N`, `metrics.fixes_applied = N`, `metrics.score_improvement = post - pre`

**Next:** Phase 7 (Generate Report).
