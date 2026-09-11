# wf-diagram v2.0 — Plan directory

**Goal:** Refactor skill `wf-diagram` v1.2.0 (mới triển khai 2026-04-30) cho tuân thủ chuẩn cấu trúc của các skill đã overhaul (wf-scan-target v2.0, wf-add-scope v3.0, wf-verify-sync v3.x).

**Status:** ⚠️ Sprint 1 BLOCKED — chờ user duyệt 4 decisions.
**Estimated:** ~12-15h theo D1=A (chỉ refactor cấu trúc).

---

## Files trong directory này

| File | Mục đích |
|------|----------|
| `00-master-plan.md` | Roadmap tổng thể 6 sprints + Definition of Done |
| `01-compliance-gaps.md` | 10 gaps so với chuẩn skills khác + 14 action items |
| `02-architecture-design.md` | Target structure chi tiết — SKILL.md routing hub, phase files, `_shared.md`, 5 bash scripts |
| `03-decisions-pending.md` | 4 decisions chính cần user duyệt (D1-D4) |
| `progress.md` | Trạng thái sprint hiện tại + notes giữa các phiên |
| `README.md` | File này — overview + how to use |
| `_next-session-prompt.md` | Prompt cho phiên tiếp theo |
| `sprints/` | Sprint-specific plans (sẽ tạo từ Sprint 2 trở đi) |

---

## How to use plan này

### Phiên đầu tiên (sau khi user duyệt decisions)
1. Đọc `progress.md` xem trạng thái các sprint
2. Đọc `_next-session-prompt.md` xem task tiếp theo
3. Đọc `03-decisions-pending.md` — confirm user choices đã update vào file
4. Vào sprint tương ứng (Sprint 2 nếu D1=A và đã unblock)
5. Tạo `sprints/sprint-2-split.md` với cấu trúc chuẩn (xem 00-master-plan.md §6)
6. Implement sprint
7. Update `progress.md` cuối phiên

### Phiên tiếp theo
1. Đọc `progress.md` — biết đang ở sprint nào
2. Đọc sprint file gần nhất trong `sprints/`
3. Continue từ task chưa done
4. Cuối phiên: update progress + tạo prompt cho phiên kế

---

## Quick links

- **Skill hiện tại:** `.claude/skills/workflow/wf-diagram/SKILL.md` (v1.2.0)
- **Current monolith:** `.claude/skills/workflow/wf-diagram/procedures/flow-new.md` (915 dòng)
- **Reference skills (đã overhaul):**
  - `.claude/skills/workflow/wf-scan-target/` — v2.0.1 (tham khảo gần nhất, standalone giống wf-diagram)
  - `.claude/skills/workflow/wf-add-scope/` — v3.0.0 (multi-dev safety pattern)
  - `.claude/skills/workflow/wf-verify-sync/` — v3.x (đang được overhaul song song — KHÔNG đụng)
- **Compliance check:**
  - `.claude/scripts/skill-compliance-audit.sh wf-diagram`
  - `.claude/scripts/validate-schema-sync.sh wf-diagram`
- **Memory entry:** `C:\Users\hanoi\.claude\projects\z--Working-MCV3\memory\project_wf-diagram-v2-improvement-plan.md`

---

## Phiên khác đang làm song song

**Lưu ý:** Memory hiện có entry `project_wf-verify-sync-v3-improvement-plan.md` — phiên khác đang refactor `wf-verify-sync` cũng theo pattern này. Khi làm wf-diagram, KHÔNG đụng vào `.claude/skills/workflow/wf-verify-sync/` và KHÔNG sửa `plans/wf-verify-sync-v3/`.
