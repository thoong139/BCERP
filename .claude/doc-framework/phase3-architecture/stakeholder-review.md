# Stakeholder Review — Phase 3 Architecture & Technical Specs

> Tổng hợp 3 góc đánh giá: Technical Cross-Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo nhất quán, phát hiện xung đột, xác nhận coverage đầy đủ trước Phase 4.
>
> READS: `P3-01-architecture.md`, `technical-specs/api-contract.md`, `technical-specs/database-design.md`, `technical-specs/integration-map.md`, `technical-specs/infra-spec.md`
> USED BY: `phase4-ux/design-system.md`, `.mc-data/work/wf-design/deferred-findings.md`

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 3
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành P3-01, technical-specs/* (api-contract, database-design, integration-map, infra-spec)
2. Stakeholder kỹ thuật thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 3 hoàn thành → Chuyển sang Phase 4 (UX Design)

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả tài liệu Phase 3 đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Kiến trúc tổng thể | `P3-01-architecture.md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | |
| API Contract | `technical-specs/api-contract.md` | ⬜ / 🔄 / ✅ | |
| Database Design | `technical-specs/database-design.md` | ⬜ / 🔄 / ✅ | |
| Integration Map & Cross-System Rules | `technical-specs/integration-map.md` | ⬜ / 🔄 / ✅ | |
| Infra Spec | `technical-specs/infra-spec.md` | ⬜ / 🔄 / ✅ | |
| Feature Specs (Phase 2) | `phase2-features/**/*.md` | ⬜ / 🔄 / ✅ | Từ Phase 2 |

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên specs kỹ thuật | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

> *Chi tiết xem tại: Phần B (Rà soát xuyên specs kỹ thuật), Phần C (Kiểm tra nhất quán), Phần D (Phân tích thiếu sót)*

### A.3. Tổng Hợp Vấn Đề & Hành Động

> *Tổng hợp tất cả vấn đề phát hiện từ 3 góc review — theo dõi việc xử lý.*

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Critical / High / Medium / Low | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |
| 2 | [Mô tả] | [Nguồn] | [Mức độ] | [Hành động] | [File] | [Ai] | [Trạng thái] |

### A.4. Thống Kê Severity

> *Tổng hợp số lượng findings theo mức độ và trạng thái — dùng để đánh giá Phase 3.*

| Mức độ | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Critical | [Số] | [Số] | [Số] | [Tổng] |
| High | [Số] | [Số] | [Số] | [Tổng] |
| Medium | [Số] | [Số] | [Số] | [Tổng] |
| Low | [Số] | [Số] | [Số] | [Tổng] |
| **Tổng** | **[Tổng]** | **[Tổng]** | **[Tổng]** | **[Tổng chung]** |

**Theo nguồn:**

| Review | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Phần B (Technical Review) | [Số] | [Số] | [Số] | [Tổng] |
| Phần C (Consistency Check) | [Số] | [Số] | [Số] | [Tổng] |
| Phần D (Gap Analysis) | [Số] | [Số] | [Số] | [Tổng] |

### A.5. Đánh Giá Tổng Thể & Xác Nhận Phase 3

> *Dựa trên thống kê severity ở mục A.4 để đánh giá.*

#### Tiêu chí đánh giá

| Kết quả | Điều kiện | Hành động tiếp theo |
|---------|-----------|---------------------|
| **APPROVED** | Zero Critical/High open (PENDING) | Chuyển sang Phase 4 |
| **APPROVED_WITH_CONDITIONS** | Zero PENDING Critical/High, nhưng có DEFERRED items | Chuyển Phase 4, DEFERRED items ghi vào `deferred-findings.md` cho `/wf-plan-modules` xử lý |
| **REJECTED** | Có PENDING Critical hoặc High | DỪNG — phải fix hoặc DEFERRED trước khi chuyển Phase 4 |

**Kết quả đánh giá:** ⬜ APPROVED / ⬜ APPROVED_WITH_CONDITIONS / ⬜ REJECTED

#### Checklist xác nhận

```
□ P3-01 Architecture — đã xác nhận bởi Architect Lead
□ API Contract — đã xác nhận bởi Tech Lead (backend + frontend)
□ Database Design — đã xác nhận bởi DBA / Data Lead
□ Integration Map — đã xác nhận bởi Architect
□ Infra Spec — đã xác nhận bởi DevOps Lead
□ Feature Specs — đã xác nhận bởi Tech Lead
□ Phần B (Technical Review) — hoàn thành
□ Phần C (Consistency Check) — hoàn thành
□ Phần D (Gap Analysis) — hoàn thành
□ Thống kê severity (mục A.4) — đã cập nhật
□ Không còn PENDING Critical/High (hoặc đã chuyển DEFERRED có lý do)
□ Tài liệu gốc đã được cập nhật theo kết quả review
□ DEFERRED items (nếu có) đã ghi vào deferred-findings.md
```

**Ngày xác nhận Phase 3 hoàn thành:** [Ngày/Tháng/Năm]

**Người xác nhận:**

| Vai trò | Tên | Chữ ký |
|---------|-----|--------|
| Architect Lead | [Tên] | |
| Tech Lead | [Tên] | |
| Security Lead | [Tên] | |

### A.6. Approval Sign-Off

| Vai trò | Họ tên | Chữ ký / Xác nhận | Ngày | Trạng thái |
|---------|--------|-------------------|------|------------|
| Technical Lead | | | | ☐ Approved / ☐ Rejected |
| Product Owner | | | | ☐ Approved / ☐ Rejected |
| Architecture Review Board | | | | ☐ Approved / ☐ Rejected |

> **Quy tắc:** Tất cả reviewers PHẢI approve trước khi chuyển sang `/wf-design-ux` hoặc `/wf-plan-modules`.

---

## Phần B: Rà Soát Xuyên Specs Kỹ Thuật (Technical Cross-Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc trước khi review:**
- `P3-01-architecture.md` — Kiến trúc tổng thể
- `technical-specs/api-contract.md` — API endpoints
- `technical-specs/database-design.md` — Database schema
- `technical-specs/integration-map.md` — Tích hợp & quy tắc xuyên hệ thống
- `technical-specs/infra-spec.md` — Hạ tầng & môi trường

### B.1. Ma Trận Liên Hệ Giữa Các Technical Specs

> *Đối chiếu các technical specs — kiểm tra xem thông tin giữa API, Database,
> Integration, Infra có khớp nhau không.*

| Spec A | Định nghĩa | Spec B | Định nghĩa tương ứng | Khớp? | Ghi chú |
|--------|-----------|--------|----------------------|-------|---------|
| [API Contract] | [POST /orders — OrderCreateDTO] | [Database Design] | [orders table schema] | ✅ / ❌ | [Fields không khớp] |
| [API Contract] | [GET /customers — pagination] | [Infra Spec] | [Rate limiting config] | ✅ / ❌ | |
| [Integration Map] | [Service A → Service B: REST] | [API Contract] | [Endpoint tương ứng] | ✅ / ❌ | |

### B.2. Kiểm Tra Xung Đột Architecture

> *Phát hiện khi các quyết định kiến trúc mâu thuẫn nhau giữa các specs.*

| Quyết định | Spec A nói | Spec B nói | Điểm xung đột | Đề xuất giải quyết |
|-----------|-----------|-----------|---------------|-------------------|
| [EXAMPLE: Auth strategy] | [API: JWT stateless] | [Infra: Session-based cache] | [Inconsistent auth model] | [Thống nhất JWT + Redis cache] |
| [EXAMPLE: Communication pattern] | [Architecture: Event-driven] | [Integration: Sync REST only] | [Không có event bus] | [Bổ sung async messaging] |

### B.3. Kiểm Tra Trùng Lặp Định Nghĩa

> *Phát hiện entity/model được định nghĩa ở nhiều nơi với thông tin khác nhau.*

| Entity | Spec A | Định nghĩa A | Spec B | Định nghĩa B | Đánh giá | Hành động |
|--------|--------|-------------|--------|-------------|----------|-----------|
| [EXAMPLE: Customer] | [API Contract] | [10 fields] | [Database Design] | [12 fields] | Khác biệt | Đồng bộ fields |
| [EXAMPLE: Order Status] | [Cross-System Rules] | [5 statuses] | [API Contract] | [4 statuses] | Thiếu 1 status | Bổ sung |

### B.4. Kiểm Tra Điểm Tích Hợp

> *So sánh Integration Map với API Contract & Cross-System Rules —
> mỗi điểm tích hợp có được cả 2 phía mô tả đầy đủ không.*

| Điểm tích hợp (từ Integration Map) | Producer mô tả API? | Consumer mô tả handling? | Contract khớp? | Đánh giá |
|-------------------------------------|---------------------|-------------------------|----------------|----------|
| [Service A → Service B: Order sync] | ✅ Có endpoint | ✅ Có handler | ✅ / ❌ | Đầy đủ / Cần bổ sung |
| [Service B → Service C: Event notify] | ✅ Có event schema | ❌ Thiếu consumer | ❌ | Cần bổ sung consumer spec |

### B.5. Tổng Kết Technical Cross-Review

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Xung đột Architecture | [Số] | [Số] | [Số] | [Số] | [Số] |
| Trùng lặp định nghĩa | [Số] | [Số] | [Số] | [Số] | [Số] |
| Mismatch API ↔ DB | [Số] | [Số] | [Số] | [Số] | [Số] |
| Thiếu điểm tích hợp | [Số] | [Số] | [Số] | [Số] | [Số] |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Các specs phối hợp tốt / Cần sửa X điểm trước khi đạt / Cần review lại nghiêm túc]

> ⚠️ **Xóa tất cả dòng `[EXAMPLE: ...]` trong các bảng trên trước khi finalize.** Đây chỉ là ví dụ minh họa format.

---

## Phần C: Kiểm Tra Tính Nhất Quán Phase 3 (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc:**
- Tất cả file trong `phase3-architecture/`
- `phase1-business/stakeholder-review.md` (deferred issues từ Phase 1)
- `_meta/req-registry.json` (REQ-IDs source of truth)

**Thứ tự ưu tiên kiểm tra:**
- 🔴 **CRITICAL (phải check):** Mục C.1 (Nhất quán với Phase 1), Mục C.3 (Data Models)
- 🟠 **HIGH (nên check):** Mục C.4 (Phạm vi)
- 🟡 **MEDIUM:** Mục C.2 (Thuật ngữ), Mục C.5 (Bảo mật)

### C.1. Nhất Quán Với Phase 1

> *Kiểm tra: mỗi REQ-ID từ registry đã được cover trong ít nhất 1 technical spec.
> Các vấn đề deferred từ Phase 1 SO docs đã được xử lý.*

| REQ-ID | Mô tả | Có trong Feature Spec? | Có trong API? | Có trong DB? | Đánh giá |
|--------|-------|----------------------|--------------|-------------|----------|
| [REQ-SALES-001] | [Quản lý khách hàng] | ✅ | ✅ | ✅ | Đầy đủ |
| [REQ-FIN-003] | [Báo cáo tài chính] | ✅ | ❌ Thiếu | ✅ | Cần bổ sung API |
| [REQ-WH-005] | [Kiểm kê tồn kho] | ❌ Thiếu | ❌ | ❌ | Chưa thiết kế |

**Phase 1 Deferred Issues:**

| Issue từ Phase 1 | Nguồn | Đã xử lý trong Phase 2? | Ở đâu | Ghi chú |
|-------------------|-------|------------------------|-------|---------|
| [EXAMPLE: Xung đột invoice trigger] | SO-01 #CON-001 | ✅ / ❌ | [File nào] | |
| [EXAMPLE: Exchange rate source] | SO-01 #CON-002 | ✅ / ❌ | | |

> ⚠️ **Xóa tất cả dòng `[EXAMPLE: ...]` trong bảng này trước khi finalize.**

### C.2. Nhất Quán Về Thuật Ngữ Kỹ Thuật

> *Kiểm tra: entity names, API naming conventions, DB table names nhất quán
> giữa tất cả technical specs.*

| Khái niệm | Architecture gọi là | API gọi là | DB gọi là | Feature Spec gọi là | Thống nhất? | Tên chuẩn |
|-----------|--------------------|-----------|-----------|--------------------|------------|-----------|
| [EXAMPLE: Đơn hàng] | Order | order / sales-order | orders / sales_orders | SalesOrder | ❌ | [orders] |
| [EXAMPLE: Khách hàng] | Customer | customer | customers | Customer | ✅ | customer |

> ⚠️ **Xóa tất cả dòng `[EXAMPLE: ...]` trong bảng này trước khi finalize.**

### C.3. Nhất Quán Về Data Models

> *Kiểm tra: API request/response models khớp với DB schema.*

| Entity | API Fields | DB Columns | Khớp? | Ghi chú |
|--------|-----------|-----------|-------|---------|
| [EXAMPLE: Customer] | [id, name, email, phone, address] | [id, full_name, email, phone, address, created_at] | ❌ | [name vs full_name mismatch] |
| [EXAMPLE: Order] | [id, customer_id, items, total, status] | [id, customer_id, total_amount, status, tax] | ❌ | [API thiếu tax, DB thiếu items] |

> ⚠️ **Xóa tất cả dòng `[EXAMPLE: ...]` trong bảng này trước khi finalize.**

### C.4. Nhất Quán Về Phạm Vi

> *Kiểm tra: architecture scope khớp với registry modules.*

| Module trong Registry | Có trong Architecture? | Có Feature Spec? | Có API? | Có DB Design? | Đánh giá |
|----------------------|----------------------|-------------------|---------|--------------|----------|
| [EXAMPLE: CRM-Customer] | ✅ | ✅ | ✅ | ✅ | Đầy đủ |
| [EXAMPLE: FIN-Reports] | ✅ | ✅ | ❌ | ❌ | Thiếu API + DB |
| [EXAMPLE: Module ngoài registry] | ✅ | ❌ | ❌ | ❌ | Không có trong registry — cần xóa hoặc bổ sung REQ |

### C.5. Nhất Quán Về Bảo Mật & Phân Quyền

> *Kiểm tra: security spec align với account roles đã định nghĩa trong Phase 1 và architecture.*

| Vai trò | Phase 1 định nghĩa | Architecture mô tả | API enforced? | DB có RBAC? | Đánh giá |
|---------|-------------------|--------------------|--------------|------------|----------|
| [Admin] | [Toàn quyền] | [Role: ADMIN] | ✅ | ✅ | Khớp |
| [Sales Rep] | [Xem KH, tạo đơn] | [Role: SALES] | ✅ | ❌ Thiếu | Cần bổ sung DB RBAC |

### C.6. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| REQ-ID chưa cover | [Số] | | | | |
| Thuật ngữ không nhất quán | [Số] | | | | |
| Data model mismatch | [Số] | | | | |
| Phạm vi không khớp | [Số] | | | | |
| Bảo mật/phân quyền không khớp | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu nhất quán / Cần sửa X điểm / Cần review lại nghiêm túc]

---

## Phần D: Phân Tích Thiếu Sót Kỹ Thuật (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Cách thực hiện:**
1. Đọc toàn bộ tài liệu Phase 3
2. Dùng các checklist bên dưới để kiểm tra
3. Ghi lại gap + đề xuất hành động
4. Quay lại sửa tài liệu gốc

### D.1. Gap Về API

> *Kiểm tra: có endpoints nào còn thiếu cho các features đã yêu cầu?*

| STT | Gap | Feature liên quan | Mức ảnh hưởng | Hành động |
|-----|-----|-------------------|--------------|-----------|
| 1 | [EXAMPLE: Thiếu endpoint bulk delete] | [FEAT-CRM-CUST-003] | Medium | Bổ sung vào api-contract.md |
| 2 | [EXAMPLE: Thiếu error codes cho validation] | [Toàn bộ API] | High | Chuẩn hóa error response |
| 3 | [EXAMPLE: Thiếu pagination cho list endpoints] | [Nhiều endpoints] | High | Thêm pagination params |

#### Checklist API thường gặp

| STT | Yêu cầu | Có trong API Contract? | Ghi chú |
|-----|---------|----------------------|---------|
| 1 | CRUD endpoints cho mỗi entity | ✅ / ❌ | |
| 2 | Search / Filter / Sort endpoints | ✅ / ❌ | |
| 3 | Pagination (offset hoặc cursor) | ✅ / ❌ | |
| 4 | Error response format chuẩn | ✅ / ❌ | |
| 5 | Authentication endpoints (login, refresh, logout) | ✅ / ❌ | |
| 6 | File upload / download | ✅ / ❌ | |
| 7 | Webhook / callback endpoints | ✅ / ❌ | |
| 8 | API versioning strategy | ✅ / ❌ | |

### D.2. Gap Về Database

> *Kiểm tra: có tables, indexes, constraints nào còn thiếu?*

| STT | Gap | Entity liên quan | Mức ảnh hưởng | Hành động |
|-----|-----|-----------------|--------------|-----------|
| 1 | [EXAMPLE: Thiếu audit_logs table] | [Toàn hệ thống] | High | Tạo bảng audit trail |
| 2 | [EXAMPLE: Thiếu indexes cho foreign keys] | [Nhiều bảng] | Medium | Thêm indexes |
| 3 | [EXAMPLE: Thiếu migration plan] | [Database] | Critical | Tạo migration strategy |

#### Checklist Database thường gặp

| STT | Yêu cầu | Có trong DB Design? | Ghi chú |
|-----|---------|-------------------|---------|
| 1 | Primary keys cho tất cả tables | ✅ / ❌ | |
| 2 | Foreign key constraints | ✅ / ❌ | |
| 3 | Indexes cho query patterns | ✅ / ❌ | |
| 4 | Soft delete strategy (deleted_at) | ✅ / ❌ | |
| 5 | Audit columns (created_at, updated_at, created_by) | ✅ / ❌ | |
| 6 | Data migration plan (nếu có hệ thống cũ) | ✅ / ❌ / N/A | |
| 7 | Seed data / master data | ✅ / ❌ | |

### D.3. Gap Về Infra

> *Kiểm tra: có thiếu environments, CI/CD steps, monitoring nào không?*

| STT | Gap | Component liên quan | Mức ảnh hưởng | Hành động |
|-----|-----|-------------------|--------------|-----------|
| 1 | [EXAMPLE: Thiếu staging environment spec] | [Deployment] | High | Bổ sung staging config |
| 2 | [EXAMPLE: Thiếu CI/CD pipeline design] | [DevOps] | High | Thiết kế pipeline |
| 3 | [EXAMPLE: Thiếu monitoring/alerting setup] | [Operations] | Medium | Thêm observability spec |

#### Checklist Infra thường gặp

| STT | Yêu cầu | Có trong Infra Spec? | Ghi chú |
|-----|---------|---------------------|---------|
| 1 | Development environment | ✅ / ❌ | |
| 2 | Staging environment | ✅ / ❌ | |
| 3 | Production environment | ✅ / ❌ | |
| 4 | CI/CD pipeline | ✅ / ❌ | |
| 5 | Container/deployment strategy | ✅ / ❌ | |
| 6 | Logging & monitoring | ✅ / ❌ | |
| 7 | Backup strategy | ✅ / ❌ | |

### D.4. Gap Về Bảo Mật

> *Kiểm tra: có thiếu auth flows, rate limiting, encryption specs nào không?*

| STT | Gap | Mức ảnh hưởng | Hành động |
|-----|-----|--------------|-----------|
| 1 | [EXAMPLE: Thiếu rate limiting per endpoint] | High | Định nghĩa rate limits |
| 2 | [EXAMPLE: Thiếu data encryption at rest] | Critical | Thêm encryption spec |
| 3 | [EXAMPLE: Thiếu CORS policy] | Medium | Định nghĩa CORS rules |

#### Checklist Bảo mật thường gặp

| STT | Yêu cầu | Có trong Technical Specs? | Ghi chú |
|-----|---------|--------------------------|---------|
| 1 | Authentication flow (login, MFA, SSO) | ✅ / ❌ | |
| 2 | Authorization model (RBAC, ABAC) | ✅ / ❌ | |
| 3 | Data encryption (at rest + in transit) | ✅ / ❌ | |
| 4 | Rate limiting / throttling | ✅ / ❌ | |
| 5 | Input validation strategy | ✅ / ❌ | |
| 6 | CORS / CSP policies | ✅ / ❌ | |
| 7 | Secrets management | ✅ / ❌ | |
| 8 | Audit logging | ✅ / ❌ | |

### D.5. Gap Về Tình Huống Ngoại Lệ

> *Kiểm tra: error handling, fallback strategies đã đầy đủ chưa?*

| STT | Tình huống | Có được mô tả? | Ở spec nào | Ghi chú |
|-----|-----------|---------------|-----------|---------|
| 1 | [EXAMPLE: External service timeout] | ❌ | | [Cần retry/circuit breaker strategy] |
| 2 | [EXAMPLE: Database connection pool exhausted] | ❌ | | [Cần graceful degradation] |
| 3 | [EXAMPLE: Concurrent write conflicts] | ❌ | | [Cần optimistic locking strategy] |
| 4 | [EXAMPLE: Disk space full] | ❌ | | [Cần alerting + cleanup policy] |
| 5 | [EXAMPLE: Invalid data from external integration] | ❌ | | [Cần validation + error queue] |

### D.6. Gap Về Yêu Cầu Phi Chức Năng

> *Kiểm tra: performance targets, scalability limits, SLA đã được định nghĩa chưa?*

| Yêu cầu | Có đề cập? | Ở đâu | Đủ chi tiết? | Ghi chú |
|---------|-----------|-------|-------------|---------|
| Response time targets (P50, P95, P99) | ✅ / ❌ | | ✅ / ❌ | |
| Throughput targets (RPS) | ✅ / ❌ | | ✅ / ❌ | |
| Concurrent users limit | ✅ / ❌ | | ✅ / ❌ | |
| Data retention policy | ✅ / ❌ | | ✅ / ❌ | |
| Scalability plan (horizontal/vertical) | ✅ / ❌ | | ✅ / ❌ | |
| SLA targets (uptime %) | ✅ / ❌ | | ✅ / ❌ | |
| Disaster recovery (RTO, RPO) | ✅ / ❌ | | ✅ / ❌ | |

### D.7. Tổng Kết Gap Analysis

> ⚠️ **Xóa tất cả dòng `[EXAMPLE: ...]` trong các bảng ở Phần D (D.1–D.5) trước khi finalize.** Đây chỉ là ví dụ minh họa format.

**Tổng số gap phát hiện:**

| Loại gap | Số lượng | Critical | High | Medium | Low |
|----------|----------|----------|------|--------|-----|
| API | [Số] | | | | |
| Database | [Số] | | | | |
| Infra | [Số] | | | | |
| Bảo mật | [Số] | | | | |
| Tình huống ngoại lệ | [Số] | | | | |
| Phi chức năng | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Không có gap nghiêm trọng / Cần bổ sung X điểm / Nhiều gap — cần review lại]

**Hành động ưu tiên cao nhất:**

1. [Gap quan trọng nhất — cần sửa ngay]
2. [Gap quan trọng thứ 2]
3. [Gap quan trọng thứ 3]
