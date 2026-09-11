# Tóm Tắt: /wf-verify-sync

**Thời gian:** [timestamp]
**Trạng thái:** HOÀN THÀNH | HOÀN THÀNH CÓ LƯU Ý | THẤT BẠI

## Đã làm gì
- Quét [N] requirements, [N] code files — kiểm tra đồng bộ giữa yêu cầu nghiệp vụ và code đã triển khai

## Kết quả
- Sync Rate: [sync_rate]% ([implemented]/[total] requirements đã có code)
- Coverage: [coverage_rate]% code files có REQ-ID
- Verdict: PASS | PARTIAL_FEATURES | NEEDS_ATTENTION | CRITICAL_GAPS

## Thay đổi chính

- Cập nhật impl_status cho [N] REQ-IDs trong registry (safe-update)
- Tạo actionable checklist với [N] mục cho developer

## Cần lưu ý
- [W001 count] requirements đã done nhưng không tìm thấy code
- [W002 count] requirements in_progress chưa có code
- [W003 count] requirements done nhưng thuộc Feature đang in_progress
- [Orphan count] code files không có REQ-ID

## Bước tiếp theo
- Chạy `/wf-prepare-deployment` để chuẩn bị triển khai
- Hoặc `/wf-implement-feature [name]` để implement các features chưa hoàn thành
