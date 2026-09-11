# Tóm Tắt: /wf-implement-feature — [FEATURE_NAME]

**Thời gian:** [TIMESTAMP]
**REQ-ID:** [REQ-ID]
**Session:** [SESSION_ID]
**Profile:** [PROFILE: quick | standard | deep | exhaustive]
**Trạng thái:** HOÀN THÀNH | HOÀN THÀNH CÓ LƯU Ý | THẤT BẠI

---

## Đã làm gì

[Mô tả 2-3 dòng — ngôn ngữ doanh nghiệp, không thuật ngữ kỹ thuật. VD: "Triển khai chức năng Quản lý Khách hàng cho module CRM. Bao gồm tạo/sửa/xóa khách hàng, tìm kiếm, và lịch sử giao dịch."]

## Kết quả

- Tạo [N] file mới, sửa [N] file
- [N] tests viết, [N] pass (coverage [X]%)
- [N] reviews chạy ([code-reviewer]/[qa-lead]/[security]), tất cả issues đã resolve
- [N] decisions kiến trúc đã ghi (per-feature: [F], project/module: [G])

## Thay đổi chính

- [Thay đổi 1 — VD: Thêm entity Customer + repository CustomerRepository theo soft-delete pattern]
- [Thay đổi 2 — VD: API endpoint POST/GET/PATCH/DELETE /api/customers]
- [Thay đổi 3 — VD: Tests phủ valid input + duplicate email + soft-delete idempotent]

## Cần lưu ý

- [Warnings hoặc findings chưa resolve — nếu không có thì ghi "Không có"]
- [DEFERRED items nếu có]
- [Cache hits: HIT/MISS, tiết kiệm ~[N] tokens]

---

## Cho skill kế tiếp (v4.0 Sprint 3)

Implementation này produce machine-readable hints trong `impl-status.json.consumer_hints` (schema v2.0). Tham khảo `impl-report.md § For Downstream Skills` để xem chi tiết.

### Triển khai (deployment)

- `/wf-prepare-deployment --from-impl=[FEATURE_SLUG]` — auto-generate CHANGELOG + release notes từ:
  - Files thay đổi (exclude tests): `consumer_hints["wf-prepare-deployment"].files_for_changelog`
  - Breaking changes: `consumer_hints["wf-prepare-deployment"].breaking_changes`
  - Migrations cần chạy: `consumer_hints["wf-prepare-deployment"].migrations_required`

### Sửa lỗi (fix bugs)

- `/wf-fix-bugs --from-impl=[FEATURE_SLUG]` — focus fix scope vào features mới implement này:
  - Modules trong scope: `consumer_hints["wf-fix-bugs"].scope_modules`
  - Test files thêm mới: `consumer_hints["wf-fix-bugs"].test_files_added`
  - Decisions mới: `consumer_hints["wf-fix-bugs"].decision_ids_new`

### Xác minh đồng bộ (verify sync)

- `/wf-verify-sync --from-impl=[FEATURE_SLUG]` — skip re-scan, chỉ verify REQ-IDs đã hoàn thành:
  - REQ-IDs: `consumer_hints["wf-verify-sync"].req_ids_completed`
  - Files có comment REQ-ID: `consumer_hints["wf-verify-sync"].files_with_req_id`

### Quyết định kiến trúc cross-feature

- [N] decision(s) đã append vào `.mc-data/docs/_meta/decision-registry.global.json` với scope = `project` hoặc `module:[MODULE_SLUG]`
- Future implementations (Phase 0.5b) sẽ tự động consume các decisions này → đảm bảo cross-feature consistency

> **Q1 LOCKED v4.0:** 3 consumer skills (`wf-prepare-deployment`, `wf-fix-bugs`, `wf-verify-sync`) chưa modify trong v4.0. Output đã có sẵn — chờ v5.0 add `--from-impl` flag.

---

## Errors & Warnings (v4.0 Sprint 4)

> Nguồn: `error-ledger.json` per-session — append-only qua `ledger_log` helper. Lazy-init: file không tồn tại nếu zero errors → render section "✅ Không có lỗi/cảnh báo".

### Critical (chặn implementation)

[Liệt kê errors có severity = "critical". Mỗi entry: `[code] phase: message`. Nếu zero → "Không có"]

### Errors

[Liệt kê errors có severity = "error", phân nhóm theo `auto_resolved`:
- Auto-resolved: `[code] phase: message` (hoàn thành)
- Escalated to user: `[code] phase: message` (cần can thiệp thủ công)
Nếu zero → "Không có"]

### Warnings

[Đếm tổng + list ngắn gọn. Format: `[N] warnings — codes: E1xx, E2xx, ...`. Nếu zero → "Không có"]

### Info

[Tổng count info events — chỉ hiển thị nếu > 0]

> Nếu tất cả 4 nhóm trên đều zero → ghi 1 dòng: **"✅ Không có lỗi hoặc cảnh báo trong session này."**
>
> Backward compat: User-facing messages reference cả mã mới và alias cũ (ví dụ: "Error E301 (was E008): Tests failing"). Xem `procedures/_shared.md § Error Codes Reference` cho full mapping.

---

## Bước tiếp theo

1. ✅ Implementation complete
2. 👉 Khuyến nghị: Chạy `/wf-verify-sync` để verify full project sync
3. 👉 Optional: Chạy integration tests nếu có
4. 👉 Optional: Update API documentation nếu endpoints thay đổi
