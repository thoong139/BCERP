# Phase 3: Design (conditional)

> Cập nhật architecture nếu feature mới ảnh hưởng kiến trúc. Luôn đọc `interface_type` sau phase này.

## PRE-GATE

- Phase 2 completed (`$NEW_FEATURE_IDS.length > 0`)

## Step 3.0 — Hỏi user xác định scope

```
Feature mới có ảnh hưởng đến kiến trúc hệ thống không?
  1. Có → cập nhật kiến trúc (gọi wf-design)
  2. Không, feature nhỏ (nằm trọn trong module hiện tại) → bỏ qua
```

💡 **Hướng dẫn chọn:**

Chọn **"Có"** nếu feature mới có ít nhất 1 trong các dấu hiệu sau:
  - Thêm API endpoint mới hoặc thay đổi contract API hiện có
  - Thêm bảng database mới hoặc thay đổi schema đáng kể (thêm cột bắt buộc, đổi quan hệ)
  - Cần service/component/module mới chưa có trong kiến trúc hiện tại
  - Thay đổi luồng dữ liệu giữa các modules (data flow)
  - Thêm tích hợp với hệ thống bên ngoài (third-party API, message queue, v.v.)
  - Feature ảnh hưởng đến cơ chế xác thực/phân quyền toàn hệ thống

Chọn **"Không"** nếu feature:
  - Chỉ thêm logic/validation trong module hiện có mà không đổi interface
  - Chỉ thêm UI screen/form dùng API đã có sẵn
  - Là cải tiến nhỏ (sorting, filtering, pagination) trên data hiện có
  - Không thêm bảng DB mới và không đổi schema

> Nếu không chắc → chọn "Có" để an toàn. wf-design sẽ tự xác định phạm vi thay đổi cần thiết.

### A. Bỏ qua → SKIP

```
1. Hiển thị: `⏭ Phase 3: Bỏ qua`
2. Ghi $STATUS_FILE:
   - phases_skipped += "phase3"
3. Tiếp tục xuống "Read interface_type" (vẫn luôn chạy)
```

### B. Cập nhật → GỌI wf-design

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Hiển thị: `▶ Phase 3: Cập nhật Architecture` | - | - |
| 3.2 | Verify `.claude/skills/workflow/wf-design/SKILL.md` tồn tại | Read | File exists (else E004) |
| 3.3 | Gọi `Skill("wf-design")` | Skill | Sub-skill POST-GATE pass |

**POST-GATE (chỉ khi chạy nhánh B):**
```bash
test -d .mc-data/docs/phase3-architecture
# Spot-check: ít nhất 1 .md file đã cập nhật/tạo mới liên quan tới NEW_FEATURE_IDS
```
- `$STATUS_FILE.phases_completed += "phase3"`

## Always-run: Read `interface_type`

**Luôn chạy** — kể cả khi skip nhánh B:

```bash
INTERFACE_TYPE=$(jq -r '.interface_type // "web+mobile"' .mc-data/docs/_meta/req-registry.json)
# Fallback nếu jq không có (E005): dùng python3 -c "import json; ..."
```

Ghi `$STATUS_FILE.interface_type = $INTERFACE_TYPE`. Giá trị này là input cho Phase 4 skip logic.

## Transition

- **Skip:** `⏭ Phase 3 bỏ qua → interface_type = [value]` → Phase 4
- **Updated:** `✅ Phase 3 hoàn thành → interface_type = [value]` → hỏi user xác nhận → Phase 4

`$STATUS_FILE.current_phase = "phase4"`.

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-design SKILL.md không tồn tại
- **E005** — `jq` không khả dụng (fallback python)

Chi tiết: `_shared.md §Error Handling Reference`.
