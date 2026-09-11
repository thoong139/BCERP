# Phase 2: Define Features

> Định nghĩa feature(s) mới và thêm vào registry qua sub-skill `wf-define-features`.

## PRE-GATE

- Phase 1 completed hoặc skipped (`"phase1"` in `phases_completed[]` HOẶC `phases_skipped[]`)
- Module target đã tồn tại trong registry

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Hiển thị: `▶ Phase 2: Định nghĩa Feature mới` | - | - |
| 2.2 | Verify `.claude/skills/workflow/wf-define-features/SKILL.md` tồn tại | Read | File exists (else E004) |
| 2.3 | Gọi `Skill("wf-define-features", args=$FEATURE_NAME)` | Skill | Sub-skill POST-GATE pass |
| 2.4 | Đọc registry → đếm features hiện tại | Read | count > `$FEATURE_COUNT_BEFORE` |
| 2.5 | Extract `$NEW_FEATURE_IDS`: `registry.features[].id - $EXISTING_FEATURE_IDS` | Read | IDs extracted |
| 2.6 | Lưu `new_feature_ids[]` vào `$STATUS_FILE` | Write | Saved |

## POST-GATE

```bash
# Feature count tăng
NEW_COUNT=$(jq '.features | length' .mc-data/docs/_meta/req-registry.json)
test "$NEW_COUNT" -gt "$FEATURE_COUNT_BEFORE"

# NEW_FEATURE_IDS không rỗng
jq -e '.new_feature_ids | length > 0' "$STATUS_FILE"

# Mỗi feature mới phải có file phase2-features/[sys]/[mod]/[feat].md
for feat_id in $(jq -r '.new_feature_ids[]' "$STATUS_FILE"); do
  # Sub-skill phải đã tạo file — chỉ spot-check
  ...
done
```

- `$STATUS_FILE.new_feature_ids.length > 0`
- `$STATUS_FILE.phases_completed += "phase2"`
- `$STATUS_FILE.current_phase = "phase3"`

### POST-GATE fail — 0 features mới (STOP bắt buộc)

Nếu `NEW_COUNT == $FEATURE_COUNT_BEFORE` (không có feature nào được thêm vào registry):

```
❌ DỪNG: Không có feature mới nào được thêm vào registry sau wf-define-features.

Nguyên nhân có thể:
  - wf-define-features bị hủy giữa chừng (user abort hoặc context overflow)
  - Feature đã tồn tại trong registry (duplicate)
  - Lỗi nội bộ trong wf-define-features

Tùy chọn:
  1. Chạy lại Phase 2 (wf-define-features) → gõ "retry"
  2. Kiểm tra registry thủ công rồi tiếp tục → gõ "force-continue"
     (CHỈ dùng khi bạn chắc chắn features đã được thêm đúng cách)
  3. Hủy workflow → gõ "cancel"
```

> Lý do STOP (không phải WARNING): Tiếp tục với `new_feature_ids = []` sẽ khiến toàn bộ pipeline (Phase 3→7) chạy nhưng không tạo ra gì có ý nghĩa. Preflight và Verify sẽ báo PASS sai — **false success**. User sẽ không biết workflow thực ra không làm gì.
>
> `"force-continue"` được ghi vào status file để audit: `"phase2_zero_feature_override": true`.

## Transition

```
✅ Phase 2 hoàn thành — [N] features mới
   IDs: [FEAT-XXX-001, FEAT-XXX-002, ...]

→ Next: Phase 3 (Design) — có cần cập nhật architecture không?
```

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — Sub-skill SKILL.md không tồn tại

Chi tiết: `_shared.md §Error Handling Reference`.
