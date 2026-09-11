# Stakeholder Review — Phase 2 Feature Specifications

> Tổng hợp 3 góc đánh giá: Feature Cross-Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo feature specs đầy đủ, nhất quán với requirements, xác nhận coverage trước Phase 3.
>
> READS: `phase2-features/[sys]/[mod]/[feat].md`, `_meta/req-registry.json`
> USED BY: `phase3-architecture/P3-01-architecture.md`

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 2
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành tất cả feature specs trong `phase2-features/[sys]/[mod]/`
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 2 hoàn thành → Chuyển sang Phase 3 (Architecture)

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả feature specs đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Feature Spec 1 | `[sys]/[mod]/[feat-1].md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | |
| Feature Spec 2 | `[sys]/[mod]/[feat-2].md` | ⬜ / 🔄 / ✅ | |

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên features | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

### A.3. Tổng Hợp Vấn Đề & Hành Động

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Critical / High / Medium / Low | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |

### A.4. Xác Nhận Phase 2 Hoàn Thành

```
□ Tất cả feature specs đã hoàn thành
□ Mỗi REQ-ID trong registry có ít nhất 1 feature spec tương ứng
□ Phần B (Feature Cross-Review) — hoàn thành
□ Phần C (Consistency Check) — hoàn thành
□ Phần D (Gap Analysis) — hoàn thành
□ Tổng hợp vấn đề (mục A.3) — tất cả đã xử lý xong
□ req-registry.json đã cập nhật features[]
```

**Ngày xác nhận Phase 2 hoàn thành:** [Ngày/Tháng/Năm]

---

## Phần B: Rà Soát Xuyên Features (Feature Cross-Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### B.1. Ma Trận REQ → FEAT Coverage

> *Kiểm tra mỗi REQ-ID có ít nhất 1 FEAT-ID tương ứng.*

| REQ-ID | Mô tả | FEAT-ID(s) | Coverage | Ghi chú |
|--------|-------|-----------|----------|---------|
| [REQ-SALES-001] | [Quản lý KH] | [FEAT-CRM-CUST-001] | ✅ Đầy đủ | |
| [REQ-FIN-002] | [Báo cáo TC] | ❌ Thiếu | ❌ Chưa có feature | Cần tạo feature spec |

### B.2. Kiểm Tra Trùng Lặp Feature

> *Phát hiện features giống nhau hoặc chồng chéo scope.*

| Feature A | Feature B | Điểm trùng lặp | Đánh giá | Hành động |
|-----------|-----------|----------------|----------|-----------|
| [FEAT-CRM-CUST-001] | [FEAT-SALES-CUST-001] | [Cùng quản lý KH] | Trùng lặp / Tương tự | Gộp / Giữ riêng |

### B.3. Kiểm Tra Business Rules Xung Đột

> *Phát hiện khi 2 features có business rules mâu thuẫn nhau.*

| Business Rule | Feature A | Feature B | Điểm xung đột | Đề xuất |
|---------------|-----------|-----------|---------------|---------|
| [VD: Giới hạn đơn hàng] | [FEAT-A: max 50 items] | [FEAT-B: max 100 items] | [Khác giới hạn] | [Thống nhất] |

---

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### C.1. Nhất Quán Với Phase 1 Requirements

> *Kiểm tra feature specs phản ánh đúng requirements từ departments.*

| FEAT-ID | REQ-IDs tham chiếu | Dept docs mô tả khớp? | Ghi chú |
|---------|--------------------|-----------------------|---------|
| [FEAT-CRM-CUST-001] | [REQ-SALES-001] | ✅ / ❌ | |

### C.2. Nhất Quán Về Entity & Data Types

> *Kiểm tra entity names, data types nhất quán giữa các feature specs.*

| Entity | Feature A gọi là | Feature B gọi là | Thống nhất? | Tên chuẩn |
|--------|-----------------|-----------------|------------|-----------|
| [VD: Đơn hàng] | Order | SalesOrder | ❌ | [Order] |

### C.3. Nhất Quán Về Permissions

> *Kiểm tra permission matrix nhất quán giữa features liên quan.*

| Vai trò | Feature A cho phép | Feature B cho phép | Khớp? | Ghi chú |
|---------|-------------------|--------------------|-------|---------|
| [Sales Rep] | [Xem + Tạo KH] | [Chỉ Xem KH] | ❌ | [Cần thống nhất] |

### C.4. Nhất Quán Về FEAT-ID Format

> *Kiểm tra tất cả FEAT-ID tuân thủ format chuẩn `FEAT-[SYS]-[MOD]-[NNN]`.*

| FEAT-ID | Format đúng? | Ghi chú |
|---------|-------------|---------|
| [FEAT-CRM-CUST-001] | ✅ / ❌ | |
| [FEAT-SALES-001] | ❌ | Thiếu module segment |

### C.5. Phụ Thuộc Xuyên Feature (Cross-Feature Dependencies)

> *Kiểm tra feature nào phụ thuộc vào feature khác — đảm bảo thứ tự implement hợp lý.*

| Feature | Phụ thuộc vào | Mô tả phụ thuộc | Đã ghi trong spec? | Ghi chú |
|---------|--------------|-----------------|-------------------|---------|
| [FEAT-CRM-ORDER-001] | [FEAT-CRM-CUST-001] | [Cần customer tồn tại trước] | ✅ / ❌ | |

### C.6. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Không khớp Phase 1 requirements | [Số] | | | | |
| Entity / Data type không nhất quán | [Số] | | | | |
| Permissions không nhất quán | [Số] | | | | |
| FEAT-ID format sai | [Số] | | | | |
| Cross-feature dependencies thiếu | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu nhất quán / Cần sửa X điểm / Cần review lại nghiêm túc]

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm]

### D.1. Gap Về Requirements Coverage

> *REQ-IDs chưa có feature spec tương ứng.*

| REQ-ID | Mô tả | Priority | Hành động |
|--------|-------|----------|-----------|
| [REQ-XX-NNN] | [Mô tả] | High/Medium/Low | Tạo feature spec / Defer |

### D.2. Gap Về User Stories

> *Feature specs thiếu user stories hoặc acceptance criteria.*

| FEAT-ID | Thiếu gì | Mức ảnh hưởng | Hành động |
|---------|---------|--------------|-----------|
| [FEAT-XX-NNN] | [Thiếu AC cho edge case X] | Medium | Bổ sung |

### D.3. Gap Về Business Rules

> *Business rules quan trọng chưa được capture trong feature specs.*

| Business Rule | Nguồn (dept doc) | Feature liên quan | Hành động |
|---------------|------------------|-------------------|-----------|
| [VD: Chiết khấu theo cấp KH] | [REQ-SALES-005] | [FEAT-CRM-PRICING-001] | Bổ sung BR |

### D.4. Gap Về REQ → FEAT Mapping Completeness

> *Kiểm tra mỗi REQ-ID đã được map tới ít nhất 1 FEAT-ID hay chưa.*

| REQ-ID | Mô tả | FEAT-ID tương ứng | Ánh xạ đầy đủ? | Hành động |
|--------|-------|------------------|---------------|-----------|
| [REQ-XX-NNN] | [Mô tả] | [FEAT-XX-NNN hoặc ❌ Chưa có] | ✅ / ❌ | Tạo feature spec / Defer |

### D.5. Gap Về Edge Cases & Error Handling

> *Feature specs thiếu mô tả edge cases hoặc error states.*

| FEAT-ID | Edge case thiếu | Mức ảnh hưởng | Hành động |
|---------|----------------|--------------|-----------|
| [FEAT-XX-NNN] | [VD: Thiếu xử lý khi network timeout] | Medium | Bổ sung vào spec |

### D.6. Checklist Tính Năng Ngầm Định

> *Kiểm tra: các tính năng cơ bản thường cần cho mọi module đã được xem xét chưa?*

| STT | Tính năng | Đã có feature spec? | Ghi chú |
|-----|----------|--------------------|-|
| 1 | Phân quyền truy cập per feature | ✅ / ❌ | |
| 2 | Validation đầu vào & thông báo lỗi | ✅ / ❌ | |
| 3 | Empty state (danh sách trống) | ✅ / ❌ | |
| 4 | Loading / skeleton state | ✅ / ❌ | |
| 5 | Audit trail / lịch sử thay đổi | ✅ / ❌ | N/A nếu module không yêu cầu |
| 6 | Export / Import data | ✅ / ❌ / N/A | |

### D.7. Tổng Kết Gap Analysis

**Tổng số gap phát hiện:**

| Loại gap | Số lượng | Critical | High | Medium | Low |
|----------|----------|----------|------|--------|-----|
| REQ chưa cover | [Số] | | | | |
| Thiếu user stories / AC | [Số] | | | | |
| Thiếu business rules | [Số] | | | | |
| REQ → FEAT mapping thiếu | [Số] | | | | |
| Thiếu edge cases / error handling | [Số] | | | | |
| Tính năng ngầm định | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Không có gap nghiêm trọng / Cần bổ sung X điểm / Nhiều gap — cần review lại]

**Hành động ưu tiên cao nhất:**

1. [Gap quan trọng nhất — cần sửa ngay]
2. [Gap quan trọng thứ 2]
3. [Gap quan trọng thứ 3]

---

## Xác Nhận & Sign-Off

### Thống Kê Severity

| Mức độ | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Critical | [Số] | [Số] | [Số] | [Tổng] |
| High | [Số] | [Số] | [Số] | [Tổng] |
| Medium | [Số] | [Số] | [Số] | [Tổng] |
| Low | [Số] | [Số] | [Số] | [Tổng] |
| **Tổng** | **[Tổng]** | **[Tổng]** | **[Tổng]** | **[Tổng chung]** |

### Đánh Giá Tổng Thể

| Kết quả | Điều kiện | Hành động tiếp theo |
|---------|-----------|---------------------|
| **APPROVED** | Zero Critical/High open (PENDING) | Chuyển sang Phase 3 |
| **APPROVED_WITH_CONDITIONS** | Zero PENDING Critical/High, nhưng có DEFERRED | Chuyển Phase 3, DEFERRED ghi vào `deferred-findings.md` |
| **REJECTED** | Có PENDING Critical hoặc High | DỪNG — phải fix trước khi chuyển Phase 3 |

**Kết quả đánh giá:** ⬜ APPROVED / ⬜ APPROVED_WITH_CONDITIONS / ⬜ REJECTED

### Checklist Xác Nhận Phase 2 Hoàn Thành

```
□ Tất cả feature specs đã hoàn thành
□ Mỗi REQ-ID trong registry có ít nhất 1 feature spec tương ứng
□ Phần B (Feature Cross-Review) — hoàn thành
□ Phần C (Consistency Check) — hoàn thành, đã sửa tất cả inconsistency
□ Phần D (Gap Analysis) — hoàn thành, không còn gap nghiêm trọng
□ Tổng hợp vấn đề (mục A.3) — tất cả đã xử lý xong
□ Tài liệu gốc đã được cập nhật theo kết quả review
□ req-registry.json đã cập nhật features[]
□ DEFERRED items (nếu có) đã ghi vào deferred-findings.md
```

**Ngày xác nhận Phase 2 hoàn thành:** [Ngày/Tháng/Năm]

**Người xác nhận:**

| Vai trò | Họ tên | Chữ ký / Xác nhận | Ngày | Trạng thái |
|---------|--------|-------------------|------|------------|
| Product Owner | | | | ☐ Approved / ☐ Rejected |
| Tech Lead | | | | ☐ Approved / ☐ Rejected |

> **Quy tắc:** Tất cả reviewers PHẢI approve trước khi chuyển sang `/wf-design`.
