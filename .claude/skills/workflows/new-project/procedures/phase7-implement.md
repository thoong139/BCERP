# Bước 6 — Phase 5b: Implement Features (loop)

> Delegate đến `wf-implement-feature` trong vòng lặp — mỗi feature 1 iteration.
> Mỗi iteration: hiển thị tên feature, chạy sub-skill, verify `impl_status = "done"`,
> hỏi user tiếp tục/skip/dừng.

**Sub-skill:** `wf-implement-feature` (gọi nhiều lần, 1 lần/feature)
**DEVKIT Phase:** Phase 5b

## PRE-GATE

```bash
test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md || exit_with E010
test -s .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md || exit_with E010
```

## Load Pending Features

```bash
# Đọc danh sách features chưa done
PENDING_FEATURES=$(jq -r '.features[] | select(.impl_status != "done") | .feature_id' .mc-data/docs/_meta/req-registry.json)

# Nếu resume → đọc từ status file: implement_progress.pending_features[]
# Nếu fresh → khởi tạo: implement_progress.total_features, pending_features[], completed_features=0
```

Hiển thị danh sách trước khi vào loop:

```
▶ Bước 6 — Phase 5b: Triển khai Code
Tìm thấy N features cần implement:
  1. [feature-name-1]
  2. [feature-name-2]
  ...

Bắt đầu implement từng feature. Sau mỗi feature bạn có thể dừng và tiếp tục sau.
```

Nếu `$PENDING_FEATURES` rỗng → skip Bước 6 (thông báo "Tất cả features đã done") → chuyển sang Bước 7.

## Loop Steps

```
FOR EACH feature IN $PENDING_FEATURES:
  6.1  Hiển thị: `Implement: [feature-name] ([i]/[total])`
  6.2  VERIFY .claude/skills/workflow/wf-implement-feature/SKILL.md → E004 nếu thiếu
  6.3  Cập nhật $STATUS_FILE.implement_progress.current_feature = feature
  6.4  Gọi Skill("wf-implement-feature", args=[feature-name])
  6.5  Đợi sub-skill POST-GATE nội bộ
  6.6  POST-GATE per-feature:
         jq -e ".features[] | select(.feature_id==\"$feature\") | .impl_status==\"done\"" registry.json
         Nếu FAIL → retry 3 lần → nếu vẫn fail → hỏi user: skip hay dừng? (E008)
  6.7  Cập nhật $STATUS_FILE:
         - implement_progress.completed_features += 1
         - implement_progress.pending_features -= [feature]
         - implement_progress.current_feature = null
  6.8  Hỏi user: "Tiếp tục feature tiếp theo? (yes / no / skip)"
         - yes  → continue loop
         - skip → bỏ qua feature này (nếu chưa done), chuyển feature kế
         - no   → break loop, E005 checkpoint
END FOR
```

## POST-GATE tổng thể (sau loop)

```bash
# Có ít nhất 1 feature đã implement
jq -e '[.features[] | select(.impl_status == "done")] | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E001
```

## Checkpoint Update (sau khi loop kết thúc)

Cập nhật `$STATUS_FILE`:
- `steps_completed += [6]` (chỉ khi ≥1 feature done)
- `current_step = 7`
- `current_phase = "phase8-preflight"`
- `implement_progress.current_feature = null`
- `updated_at = now()`
- `next_action = "Bắt đầu Bước 7 — Phase 5c: Preflight Check"`

## Transition

```
✅ Bước 6 hoàn thành — Phase 5b: Code Implementation (N/M features)

→ Next: Bước 7 — Phase 5c: Preflight Check (phase8-preflight.md)

Tiếp tục? (yes/no)
```

Nếu user dừng giữa loop → E005: lưu `implement_progress.current_feature` + `pending_features[]` → thông báo resume bằng `--resume`.

## Errors liên quan

- **E001** — POST-GATE tổng thể fail (không có feature nào done) → STOP
- **E002** — User dừng sau khi xong loop → checkpoint + resume note
- **E004** — Sub-skill SKILL.md thiếu → STOP
- **E005** — Loop bị gián đoạn giữa chừng → checkpoint per-feature, user resume
- **E008** — Feature individual POST-GATE fail → hỏi skip/retry
- **E010** — Prerequisite fail (thiếu roadmap) → báo user

Chi tiết: `_shared.md §Error Handling Reference`.
