# Phase 0: Orchestrator Init & Routing

> Entry point. Luôn chạy đầu tiên để parse arguments, validate sub-skill paths,
> tạo status file, và route tới flag handler phù hợp.

## PRE-GATE

```bash
# T1: Validate toàn bộ sub-skill paths tồn tại (xem _shared.md §Sub-Skill Paths)
for path in $SUB_SKILLS; do
  test -f "$path" || exit_with E004
done
```

Nếu bất kỳ sub-skill SKILL.md nào thiếu → E004 với path cụ thể → STOP.

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse `$ARGUMENTS`: `$PROJECT_NAME`, `--resume`, `--from-phase N`, `--status` | - | Parsed |
| 0.2 | Validate flag combinations (`--resume` + `--from-phase` → E008) | - | No conflict |
| 0.3 | Route theo flags (xem Flag Routing) | - | Correct routing |
| 0.4 | Tạo tracking dir `.mc-data/work/new-project/` (nếu chưa có) | Bash | `test -d` |
| 0.5 | Tạo `$STATUS_FILE` theo schema (xem `_shared.md §Status File Schema`) nếu chưa tồn tại | Write | `test -f` |
| 0.6 | Nếu `.mc-data/` đã tồn tại (không có flag) → hỏi user: resume hay bắt đầu lại? | - | User confirm |
| 0.7 | Validate tất cả sub-skill paths (xem PRE-GATE) | Bash | All exist |
| 0.8 | Hiển thị overview workflow + hỏi user xác nhận bắt đầu | - | User confirm |

## Flag Routing

```
IF --status:
  → Execute Status Check Protocol (xem _shared.md §Status Check Protocol)
  → DỪNG (không route sang phase khác)

IF --resume:
  → Execute Resume Protocol (xem _shared.md §Resume Protocol)
  → Jump tới file tương ứng với current_step

IF --from-phase N:
  → Validate N ∈ {0, 1, 2, 3, 4, 5a, 5b, 5c, verify, 6} → else E007
  → Execute Prerequisite Validation (xem _shared.md §--from-phase Mapping)
  → Jump tới file tương ứng

IF no flags:
  → Check .mc-data/ existence:
    - Tồn tại → hỏi user: resume/start fresh/cancel
    - Không → bắt đầu fresh từ phase1-brainstorm
  → Hiển thị overview + confirm → jump tới phase1-brainstorm
```

## Overview Display

```
DEVKIT — New Project Workflow
─────────────────────────────────
Sẽ thực hiện 10 bước từ Phase 0 đến Phase 6.
Mỗi bước sẽ hỏi xác nhận trước khi tiếp tục.

  Bước 0  → Phase 0: Brainstorm (wf-brainstorm)
  Bước 1  → Phase 1: Phân tích Requirements (wf-analyze-requirements)
  Bước 2  → Phase 2: Định nghĩa Features (wf-define-features)
  Bước 3  → Phase 3: Thiết kế Kiến trúc (wf-design)
  Bước 4  → Phase 4: Thiết kế UX/UI (wf-design-ux) [conditional]
  Bước 5  → Phase 5a: Lập kế hoạch (wf-plan-modules)
  Bước 6  → Phase 5b: Triển khai Code (wf-implement-feature)
  Bước 7  → Phase 5c: Preflight (wf-preflight)
  Bước 8  → Verify: Sync Check (wf-verify-sync)
  Bước 9  → Phase 6: Deployment Docs (wf-prepare-deployment)

Bạn có muốn bắt đầu không? (yes/no)
```

## POST-GATE

- `$STATUS_FILE` tồn tại, JSON valid
- `project_name`, `started_at` đã ghi
- `current_step = 0`, `current_phase = "phase1-brainstorm"` (sau khi confirm)
- Append `"phase0-init"` vào `steps_completed[]`

## Transition

```
✅ Phase 0 Init hoàn thành — sẵn sàng chạy Bước 0

→ Next: Bước 0 — Phase 0: Brainstorm (phase1-brainstorm.md)
```

## Errors liên quan

- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E007** — `--from-phase` invalid → hiển thị mapping, hỏi lại
- **E008** — `--resume` + `--from-phase` cùng lúc → báo conflict
- **E009** — status.json corrupt → xóa file, fallback file-based detection
- **E010** — `--from-phase` prerequisite missing → đề xuất chạy phase trước
- **E011** — `--resume`/`--status` nhưng `.mc-data/` chưa tồn tại → STOP

Chi tiết: `_shared.md §Error Handling Reference`.
