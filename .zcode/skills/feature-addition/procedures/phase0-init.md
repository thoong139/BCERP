# Phase 0: Context Loading & Init

> Entry point. Luôn chạy đầu tiên (trừ khi `--resume` đã xác định checkpoint).
> Validate prerequisites, detect LEGACY_MODE, tạo status file, parse arguments.

## PRE-GATE (CORE-011 — Forensic Content Validation)

```bash
# T1: File & directory existence
test -d .mc-data/docs/phase3-architecture                        || exit_with E001
test -f .mc-data/docs/_meta/req-registry.json                    || exit_with E002

# T2: File non-empty
test -s .mc-data/docs/_meta/req-registry.json                    || exit_with E002

# T3: Format valid
jq '.' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1    || exit_with E002

# T4: Required content present
jq -e '.systems     | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E002
jq -e '.modules     | length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E002
jq -e '.requirements| length > 0' .mc-data/docs/_meta/req-registry.json || exit_with E002

# T4b: Phase 3 architecture có ít nhất 1 .md file
test -n "$(ls .mc-data/docs/phase3-architecture/*.md 2>/dev/null)" || exit_with E001

# Concurrency guard — kiểm tra lock file (xem _shared.md §Lock File Mechanism)
LOCK_FILE=".mc-data/work/feature-addition/.lock"
if test -f "$LOCK_FILE"; then
  LOCK_TS=$(cat "$LOCK_FILE" 2>/dev/null | grep -o '[0-9]*' | head -1)
  NOW_TS=$(date +%s)
  LOCK_AGE=$(( NOW_TS - ${LOCK_TS:-0} ))
  if [ "$LOCK_AGE" -lt 7200 ]; then  # lock còn trong vòng 2 giờ
    echo "⚠ CẢNH BÁO: Phát hiện lock file từ ${LOCK_AGE} giây trước."
    echo "  Có thể có một phiên /feature-addition khác đang chạy trên project này."
    echo "  Nếu không có phiên nào đang chạy (ví dụ: session trước bị crash), bạn có thể tiếp tục."
    echo "  Tiếp tục? (yes/no)"
    # Nếu user chọn no → STOP tại đây
  fi
fi
```

**Error messages:**
- E001 → *"Dự án chưa có architecture. Dùng `/new-project` hoặc `/existing-project` trước."*
- E002 → *"Registry không tồn tại hoặc không hợp lệ. Chạy `/wf-analyze-requirements` trước."*

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.0 | Tạo tracking dir `.mc-data/work/feature-addition/` + ghi lock file `.mc-data/work/feature-addition/.lock` với timestamp (xem `_shared.md §Lock File Mechanism`) | Bash | `test -f .lock` |
| 0.1 | Đọc registry → đếm `feature_count_before`, extract `existing_feature_ids[]` | Read | Saved |
| 0.2 | Extract `existing_module_ids[]` từ `modules[]` (lấy cả `id` + `name` để hiển thị) | Read | Saved |
| 0.3 | Kiểm tra features đang `in_progress` từ session trước → nếu có, hiển thị cảnh báo + hỏi xác nhận tiếp tục | Read | Displayed |
| 0.4 | Tạo `$STATUS_FILE` theo schema (xem `_shared.md §Status File Schema`) | Write | `test -f` |
| 0.5 | Parse `$ARGUMENTS`: `--resume`, `--from-phase`, `feature-name` | - | Parsed |
| 0.6 | Detect LEGACY_MODE (xem `_shared.md §LEGACY_MODE Detection`) → ghi `legacy_mode` + `deprecated_modules` | Bash | Saved |
| 0.7 | Hiển thị overview + xác nhận với user (bỏ qua khi `--resume` hoặc `--from-phase`) | - | User confirm |

### Step 0.3 — Chi tiết kiểm tra in_progress

```bash
IN_PROGRESS_COUNT=$(jq '[.requirements[] | select(.impl_status == "in_progress")] | length' \
  .mc-data/docs/_meta/req-registry.json)

if [ "$IN_PROGRESS_COUNT" -gt 0 ]; then
  IN_PROGRESS_IDS=$(jq -r '[.requirements[] | select(.impl_status == "in_progress") | .id] | join(", ")' \
    .mc-data/docs/_meta/req-registry.json)
  echo "⚠ Cảnh báo: Có $IN_PROGRESS_COUNT feature đang thực hiện dở từ session trước:"
  echo "  $IN_PROGRESS_IDS"
  echo "  Tiếp tục thêm feature mới có thể tạo xung đột. Bạn muốn tiếp tục không? (yes/no)"
  # Nếu user chọn no → STOP, gợi ý resume session trước hoặc chạy /wf-fix-bugs
fi
```

## Argument Processing

- **Có `--resume`** → chuyển sang Resume Protocol (xem `_shared.md §Resume Protocol`)
- **Có `--from-phase N`** → validate N (xem `_shared.md §--from-phase Mapping`) → nếu invalid → E010 → nhảy đến phase tương ứng
- **Không flag** → hiển thị overview + hỏi yes/no

### Overview hiển thị

```
▶ Feature Addition Workflow
───────────────────────────
Dự án đã có architecture. Sẽ thêm feature mới qua 9 bước:
  Phase 0  → Khởi tạo & kiểm tra prerequisites       ← đang ở đây
  Phase 1  → Thêm scope (nếu cần module mới)
  Phase 2  → Định nghĩa feature
  Phase 3  → Cập nhật kiến trúc (nếu cần)
  Phase 4  → Thiết kế giao diện (nếu có UI)
  Phase 5a → Lập kế hoạch thực hiện
  Phase 5b → Viết code từng feature
  Preflight → Kiểm tra sức khỏe dự án
  Verify   → Kiểm tra đầy đủ yêu cầu

[Chỉ hiển thị khi LEGACY_MODE = true:]
⚠ Dự án có sẵn (đã onboard): Một số modules đã ngưng sử dụng.
  Modules không còn dùng: [list]
  → Features mới sẽ không được thêm vào các modules này.

Bạn có muốn bắt đầu không? (yes/no)
```

## POST-GATE

- `$STATUS_FILE` tồn tại, JSON valid
- `feature_count_before`, `existing_feature_ids`, `existing_module_ids`, `legacy_mode`, `deprecated_modules` đã ghi
- Lock file `.mc-data/work/feature-addition/.lock` tồn tại với timestamp hợp lệ
- `current_phase = "phase1"`
- Append `"phase0"` vào `phases_completed[]`

## Transition

```
✅ Phase 0 hoàn thành — context loaded
  Features hiện có: N
  Modules hiện có: M
  [Chỉ khi LEGACY_MODE=true] Dự án có sẵn — modules ngưng dùng: [list]

→ Next: Phase 1 (Scope Addition) — kiểm tra xem có cần thêm module mới
```

## Errors liên quan

- **E001, E002** — PRE-GATE fail (STOP) — lock file KHÔNG được tạo khi fail ở bước này
- **E010** — `--from-phase` giá trị không hợp lệ
- **E011** — Context overflow giữa chừng
- **E012** — Status file corrupt (trigger rebuild)

> Lock file được xóa sau Phase 7 hoàn thành hoặc khi E001/E002 STOP sớm. Các error codes khác giữ lock để enable `--resume`.

Chi tiết: `_shared.md §Error Handling Reference`, `_shared.md §Lock File Mechanism`.
