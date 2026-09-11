# Block Classification — Appendix (Reference Tables)

**Tài liệu bổ sung** cho `block-classification.md`. Chứa lookup tables calibration — KHÔNG phải quy trình thực thi.

---

## 5. Suggested Action Mapping (Nhóm 3)

| blocking_reason | suggested_action |
|-----------------|------------------|
| `endpoint_missing` / API handler không tồn tại | `implement_endpoint` |
| `ui_screen_missing` / Page/Component không tồn tại | `implement_ui` |
| `validation_missing` / Validator handler thiếu | `implement_validation` |
| `business_rule_missing` / BR chưa code | `implement_feature` |
| `seed_schema_missing` / Bảng/cột chưa migrate | `implement_seed_data` |
| `feature_deferred` / Tính năng hoãn có chủ đích | `implement_feature` (defer P2 priority) |
| `feature_not_implemented` / Code chưa có | `implement_feature` |

---

## 6. Priority Calibration (Nhóm 3)

| Priority | Khi nào | Tác động |
|----------|---------|----------|
| **P0** | Block critical/high test (happy path, BR core, security boundary) | F4 PHẢI implement trước F5 retest |
| **P1** | Block medium test (validation edge, error UX) | F4 nên implement |
| **P2** | Block low test (nice-to-have, deferred designed) | F4 có thể skip nếu deadline gấp |

---

## 7. Manual Reason Calibration (Nhóm 4)

| manual_reason | Khi nào áp dụng | Code verification method gợi ý |
|---------------|------------------|-------------------------------|
| `visual_inspection` | UI rendering, animation, layout phức tạp, responsive, màu sắc | `static_code_review` (đọc CSS/component) |
| `requires_real_payment` | VNPay/MoMo/banking real flow | `static_code_review` + `unit_test` (callback handler) |
| `requires_external_api` | External API không có sandbox | `mock_api_test` (mock client) |
| `requires_3rd_party_login` | OAuth Google/Facebook thật | `static_code_review` (callback exchange logic) |
| `requires_hardware` | Barcode scanner thật, GPS device | `unit_test` (parsing logic) |
| `requires_data_volume` | Test load 10k+ records, performance | `static_code_review` (pagination/query) — defer to perf test |
| `requires_human_judgment` | Quyết định subjective (vd: copy text quality) | `static_code_review` (template review) |
