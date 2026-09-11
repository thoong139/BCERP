<!-- Template: phase-summary.md — Tóm tắt kết quả preflight cho non-specialist -->
<!-- Ai viết: AI tự động generate khi hoàn thành Phase 7 của /wf-preflight -->
<!-- Template Usage: READ template này → POPULATE với data từ Phase 7 → WRITE output -->
<!-- Output path (v3.0+): $SESSION_DIR/phase-summary.md (session-scoped) -->

# Tóm tắt Preflight — [PROJECT_NAME]

**Phiên:** {SESSION_ID} | **Ngày:** YYYY-MM-DD | **Phạm vi:** [all / system=X / module=Y / feature=Z] | **Kết quả:** PASS ✅ / WARN ⚠️ / FAIL ❌

## Kết quả chính

**Điểm tổng:** X% — [Mô tả ngắn gọn bằng tiếng Việt cho người không chuyên]

| Kiểm tra | Kết quả |
|----------|---------|
| Registry (cơ sở dữ liệu yêu cầu) | ✅/⚠️/❌ X% |
| Tài liệu | ✅/⚠️/❌ X% |
| Đồng bộ code | ✅/⚠️/❌ X% |
| Chất lượng code | ✅/⚠️/❌ X% |

## Vấn đề cần xử lý

[Nếu không có: "Không có vấn đề nào."]
| # | Mức độ | Mô tả | Cần làm gì |
|---|--------|-------|-----------|
| 1 | CRITICAL/HIGH/MEDIUM | [Mô tả tiếng Việt] | [Hành động cụ thể] |

## Bước tiếp theo

[Nếu PASS:] Hệ thống sẵn sàng. Tiếp tục kiểm tra chi tiết: `/wf-verify-sync`

[Nếu WARN:] Cần xử lý [N] vấn đề trước khi tiếp tục. Khuyến nghị: `/wf-fix-bugs`

[Nếu FAIL:] Có lỗi nghiêm trọng cần sửa ngay. Khuyến nghị mạnh: `/wf-fix-bugs --scope=[scope]`
