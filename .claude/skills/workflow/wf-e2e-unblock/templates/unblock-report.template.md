# Unblock Report — {SESSION_ID}

**Thời gian:** {ISO_TIMESTAMP}
**FEAT-ID:** {FEAT-ID}
**Tổng block entries:** {TOTAL_BLOCKS}

---

## 1. Kết Quả Tổng Quan

| BLK-ID | Test | Lý do block | Loại | Hành động | Kết quả |
|--------|------|-------------|------|-----------|---------|
| {BLK-NNN} | {test_ref} | {blocking_reason} | {AUTO-FIX \| CHECK-IMPLEMENT \| VERIFY-CODE} | {hành động đã làm} | {✅ Unblocked + PASS \| ❌ Vẫn blocked \| ⚠️ Resolved (SKIPPED)} |

---

## 2. Thống Kê

| Chỉ số | Số lượng |
|--------|----------|
| Unblocked + PASS | {n} |
| Unblocked + FAIL (→ issues.json) | {n} |
| Vẫn blocked (chưa implement) | {n} |
| Vẫn blocked (auto-fix fail) | {n} |
| Resolved (code verified, cần người) | {n} |
| Resolved (SKIPPED — không thuộc e2e scope) | {n} |

---

## 3. Cần Implement (Nhóm 3)

Các tính năng vẫn chưa được code — cần `/wf-implement-feature` để unblock.

| BLK-ID | Tính năng còn thiếu | File liên quan | Ghi chú |
|--------|---------------------|---------------|---------|
| {BLK-NNN} | {tính năng} | {file_path} | {ghi chú} |

---

## 4. Cần Người Dùng (Nhóm 4)

Các test không thể automation — cần người dùng nhìn trực tiếp hoặc test thủ công.

| BLK-ID | Lý do | Hướng dẫn test thủ công |
|--------|-------|------------------------|
| {BLK-NNN} | {blocking_reason}: {blocking_detail} | {hướng dẫn từng bước} |

---

## 5. Đã Unblock + Retest PASS

| BLK-ID | Test | Lý do block ban đầu | Cách unblock | Retest Result |
|--------|------|---------------------|-------------|---------------|
| {BLK-NNN} | {test_ref} | {blocking_reason} | {cách unblock} | PASS |

---

## 6. Đã Unblock + Retest FAIL (→ issues.json)

Các test đã unblock nhưng retest vẫn fail — đây là code bug, đã ghi vào issues.json.

| BLK-ID | Test | ISS-ID mới | Mô tả lỗi |
|--------|------|------------|-----------|
| {BLK-NNN} | {test_ref} | {ISS-NNN} | {mô tả} |

---

## 7. Ghi Chú

{_template_notes: Đây là template cho --unblock-test output. Điền đầy đủ các section.
Section 3 chỉ hiển thị nếu có block thuộc Nhóm 3 (feature_deferred, feature_not_implemented).
Section 4 chỉ hiển thị nếu có block thuộc Nhóm 4 (requires_visual_inspection, requires_manual_interaction, external_dependency).
Section 5 chỉ hiển thị nếu có block được unblock và retest PASS.
Section 6 chỉ hiển thị nếu có block được unblock nhưng retest FAIL.
}
