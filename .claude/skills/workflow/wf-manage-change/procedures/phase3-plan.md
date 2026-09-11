# Phase 3: Plan

> Lập kế hoạch thực hiện chi tiết — docs trước, code sau, tests cuối.
> User approve trước khi execute.

> **Shared:** Xem `procedures/_shared.md` — Fix Rules.

---

## PRE-GATE

- Phase 2 đã PASSED
- User đã confirm impact report
- `$SESSION_DIR/impact-report.md` tồn tại

---

## INPUT

- `$SESSION_DIR/impact-report.md`
- `$SESSION_DIR/affected-artifacts.json`

---

## OUTPUT

- `$SESSION_DIR/change-plan.md` (template: `templates/change-plan.md`)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Build ordered task list: sắp xếp theo dependency (docs → code → tests) | — | Tasks ordered |
| 3.2 | Phân loại tasks: `doc_tasks[]`, `code_tasks[]`, `test_tasks[]` | — | Categorized |
| 3.3 | Estimate scope: số files, loại changes | — | Estimated |
| 3.4 | **Tạo change plan:** READ template `templates/change-plan.md` → POPULATE task list + execution order → WRITE `$SESSION_DIR/change-plan.md` | Write | File created |
| 3.5 | ***** USER GATE:**** Present plan → hỏi user approve | AskUserQuestion | Approved |

---

## Task Ordering Rules

```
THỨ TỰ THỰC HIỆN:
1. Registry update (nếu cần thêm/sửa requirements, features)
2. Phase 1-2 doc updates (requirements, feature specs)
3. Phase 3 doc updates (architecture, API — nếu cần)
4. Phase 4 doc updates (UX — nếu cần)
5. Phase 5 doc updates (implementation plan — nếu cần)
6. Code changes
7. Test changes

TRONG MỖI NHÓM:
- Doc updates: theo phụ thuộc (upstream trước downstream)
- Code changes: theo module (module độc lập có thể song song — xem Phase 4b)
- Test changes: theo code file tương ứng
```

---

## Plan Structure

```json
{
  "change_id": "CHG-YYYYMMDD-NNN",
  "total_tasks": N,
  "estimated_duration_minutes": N,
  "execution_order": [
    {
      "phase": "4a",
      "group": "registry_update",
      "tasks": [...]
    },
    {
      "phase": "4a",
      "group": "doc_updates",
      "tasks": [...]
    },
    {
      "phase": "4b",
      "group": "code_changes",
      "parallel_eligible": true/false,
      "tasks": [...]
    },
    {
      "phase": "4c",
      "group": "test_changes",
      "tasks": [...]
    }
  ]
}
```

Full schema: xem `templates/change-plan.md`.

---

## User Gate Logic (Step 3.5)

```
AskUserQuestion: "Plan đã sẵn sàng. Thực hiện thay đổi?"
  Options:
    - "Yes, execute"            → Phase 4a
    - "Điều chỉnh plan"          → quay lại Step 3.1 với điều chỉnh
    - "Dry-run only"             → set $DRY_RUN = true, tiếp tục Phase 4 (sẽ STOP ở DRY-RUN GATE)
    - "Hủy"                       → STOP, đánh dấu session "cancelled"
```

---

## POST-GATE

- `$SESSION_DIR/change-plan.md` tồn tại, non-empty
- User đã approve plan
- `change-status.json.phases.phase3.status = "completed"`
- Nếu user từ chối → điều chỉnh plan và hỏi lại (max 3 lần)

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-plan.md \
  --type=markdown \
  --headings="## Execution Tasks,## Rollback Plan"
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Tiếp tục `procedures/phase4a-registry-docs.md`.

> **LƯU Ý:** Phase 4 được chia thành 3 sub-phases độc lập (4a/4b/4c), mỗi cái có PRE-GATE + POST-GATE riêng. Nếu `$DRY_RUN == true` → Phase 4a đầu file sẽ STOP tại DRY-RUN GATE và nhảy thẳng Phase 6.
