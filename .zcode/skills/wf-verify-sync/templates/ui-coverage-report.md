# UI-Code Coverage Report

> Tự động tạo bởi /wf-verify-sync Phase 5b
> Chỉ tạo khi `interface_type != "api-only"`

---

## Dashboard

| Metric | Value |
|--------|-------|
| **Total Screens** | {{total_screens}} |
| **Business Screens** | {{total_business_screens}} |
| **Infrastructure Screens** | {{infrastructure_count}} |
| **Matched (có FEAT-ID)** | {{matched_count}} |
| **Partial Match** | {{partial_match_count}} |
| **Missing from Features** | {{missing_from_features_count}} |
| **Missing from Code** | {{missing_from_code_count}} |
| **Coverage (full match)** | **{{coverage_pct}}%** |
| **Coverage (incl. partial)** | **{{partial_coverage_pct}}%** |

> **Formula:** `coverage_pct = (MATCHED / total_business_screens) * 100`
> `partial_coverage_pct = ((MATCHED + PARTIAL_MATCH) / total_business_screens) * 100`
> `total_business_screens = total_screens - infrastructure_count`

---

## Per-Screen Detail

| Path | Route | Type | Category | Matching FEAT-ID | Notes |
|------|-------|------|----------|------------------|-------|
| {{per_screen_rows}} |

### Category Legend

| Category | Mô tả | Severity |
|----------|-------|----------|
| **MATCHED** | Screen có FEAT-ID tương ứng | PASS |
| **PARTIAL_MATCH** | Feature có screen chính nhưng thiếu sub-screens (modal, tab panel) | INFO |
| **MISSING_FROM_FEATURES** | Screen có trong code nhưng KHÔNG có FEAT-ID → code vượt scope | WARNING |
| **MISSING_FROM_CODE** | FEAT-ID có trong registry nhưng KHÔNG tìm thấy screen → chưa implement | WARNING |
| **INFRASTRUCTURE** | Screen match auto-skip list (layout, error, loading...) → loại khỏi coverage | SKIP |

---

## Warnings

### Screens Missing from Features (code vượt scope)

> WARNING: Screens tồn tại trong codebase nhưng không có FEAT-ID tương ứng.
> Có thể là: developer tự thêm, feature chưa được spec, hoặc refactor chưa cập nhật registry.

{{missing_from_features_detail}}

### Features Missing from Code (chưa implement UI)

> WARNING: Features có FEAT-ID trong registry nhưng không tìm thấy UI screen tương ứng.
> Có thể là: chưa implement, screen bị refactor/xóa, hoặc feature là backend-only.

{{missing_from_code_detail}}

---

## Recommendations

{{recommendations}}

---

## Ghi chú

- Report này chỉ tạo khi `interface_type != "api-only"` (từ `req-registry.json`)
- Phase 5b chạy cho **CẢ dự án mới lẫn dự án cũ** (legacy)
- Infrastructure screens (layout, error, loading, etc.) KHÔNG tính vào coverage
- PARTIAL_MATCH screens vẫn tính vào `total_business_screens` (không loại khỏi mẫu số)
- Nếu `total_screens == 0` → Phase 5b bị SKIP, report không được tạo
