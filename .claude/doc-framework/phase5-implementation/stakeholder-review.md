# Stakeholder Review — Phase 5 Implementation Planning

> **Loại file: OFFICIAL DELIVERABLE** — Tài liệu này dành cho stakeholder review, không phải work file nội bộ.
> Work files (planmod-status.json, planmod-plan.md, checkpoint.json) là nội bộ của tool và **không cần share với stakeholders**.
> Chỉ file này và `P5-00-implementation-roadmap.md` cần stakeholder sign-off trước khi bắt đầu implement.
>
> Tổng hợp 3 góc đánh giá: Plan Cross-Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo kế hoạch khả thi, phát hiện thiếu sót, xác nhận sẵn sàng trước khi implement.
>
> READS: `P5-00-implementation-roadmap.md`, `sprints/S0X-*.md`, `tasks/[sys]/[mod]/[feat]-impl.md`
> USED BY: `/wf-implement-feature` (implementation execution)

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 5
> **Cập nhật bởi:** [Tên người phụ trách]
> **Ngày cập nhật:** [Ngày/Tháng/Năm]

**Quy trình:**
1. Hoàn thành module-plan, dependency-graph, roadmap, sprints/*
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 5 hoàn thành → Bắt đầu implement

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả tài liệu Phase 5 đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Implementation Roadmap | `P5-00-implementation-roadmap.md` | ⬜ Chưa / 🔄 Đang viết / ✅ Xong | |
| Module Plan | *work file — tạo bởi /plan-modules* | ⬜ / 🔄 / ✅ | |
| Dependency Graph | *work file — tạo bởi /plan-modules* | ⬜ / 🔄 / ✅ | |
| Sprint Index | `sprints/_index.md` | ⬜ / 🔄 / ✅ | |
| Sprint Plans | `sprints/S0X-*.md` | ⬜ / 🔄 / ✅ | |
| Feature Implementation Plans | `tasks/[sys]/[mod]/[feat]-impl.md` | ⬜ / 🔄 / ✅ | |

**Sẵn sàng review:** ⬜ Chưa sẵn sàng / ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát kế hoạch triển khai | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Kiểm tra nhất quán | [Tên] | ⬜ / 🔄 / ✅ | [Số] |
| Phân tích thiếu sót | [Tên] | ⬜ / 🔄 / ✅ | [Số] |

> *Chi tiết xem tại: Phần B (Rà soát kế hoạch triển khai), Phần C (Kiểm tra nhất quán), Phần D (Phân tích thiếu sót)*

### A.3. Tổng Hợp Vấn Đề & Hành Động

> *Tổng hợp tất cả vấn đề phát hiện từ 3 góc review — theo dõi việc xử lý.*

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | [Mô tả vấn đề] | Phần B/C/D | Critical / High / Medium / Low | [Sửa gì] | [File nào] | [Ai] | Chờ / Đang sửa / Xong |
| 2 | [Mô tả] | [Nguồn] | [Mức độ] | [Hành động] | [File] | [Ai] | [Trạng thái] |

### A.4. Xác Nhận Phase 5 Hoàn Thành

> *Checklist cuối cùng trước khi bắt đầu implementation.*

```
□ P5-00 Implementation Roadmap — đã xác nhận bởi Tech Lead
□ Module Plan & Dependency Graph — đã xác nhận bởi Architect
□ Sprint Plans — đã xác nhận bởi Team Leads
□ Task Breakdowns — đã xác nhận bởi Developers
□ Phần B (Plan Review) — hoàn thành, không còn vấn đề mở
□ Phần C (Consistency Check) — hoàn thành, đã sửa tất cả inconsistency
□ Phần D (Gap Analysis) — hoàn thành, không còn gap nghiêm trọng
□ Tổng hợp vấn đề (mục A.3) — tất cả đã xử lý xong
□ Tài liệu gốc đã được cập nhật theo kết quả review
```

**Ngày xác nhận Phase 5 hoàn thành:** [Ngày/Tháng/Năm]

**Người xác nhận:**

| Vai trò | Tên | Chữ ký |
|---------|-----|--------|
| Tech Lead | [Tên] | |
| Architect | [Tên] | |
| QA Lead | [Tên] | |

---

## Phần B: Rà Soát Kế Hoạch Triển Khai (Plan Cross-Review)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc trước khi review:**
- `module-plan.md` — Kế hoạch module
- `dependency-graph.md` — Đồ thị phụ thuộc
- `P5-00-implementation-roadmap.md` — Lộ trình tổng thể
- `sprints/S0X-*.md` — Kế hoạch từng sprint

### B.1. Kiểm Tra Thứ Tự Phụ Thuộc

> *Verify: module ở layer N không được scheduled trước dependency ở layer N-1.*

| Module | Layer | Depends On | Dependency Layer | Dependency Scheduled Trước? | Đánh giá |
|--------|-------|-----------|-----------------|---------------------------|----------|
| [VD: CRM-Customer] | 0 | [Không có] | — | — | ✅ OK (foundation) |
| [VD: Sales-Order] | 1 | [CRM-Customer] | 0 | ✅ Sprint 1 trước Sprint 2 | ✅ OK |
| [VD: FIN-Invoice] | 2 | [Sales-Order, WH-Inventory] | 1, 1 | ✅ / ❌ | [Đánh giá] |

### B.2. Kiểm Tra Sprint Dependencies

> *Verify: sprint B không start trước sprint A hoàn thành, khi B phụ thuộc output của A.*

| Sprint B | Phụ thuộc Sprint A | Sprint A kết thúc trước B? | Đánh giá |
|----------|-------------------|--------------------------|----------|
| [VD: S03-Sales] | [S01-Foundation, S02-CRM] | ✅ / ❌ | OK / Cần điều chỉnh |
| [VD: S04-Finance] | [S02-CRM, S03-Sales] | ✅ / ❌ | |

**Xung đột phát hiện:**

| Sprint | Vấn đề | Mức độ | Đề xuất giải quyết |
|--------|--------|--------|-------------------|
| [VD: S03] | [Phụ thuộc S02 chưa xong] | High | [Dời S03 lùi 1 sprint] |

### B.3. Kiểm Tra Khả Năng Song Song

> *Verify: modules marked parallel thực sự independent — không share DB tables, không gọi API lẫn nhau.*

| Module A (parallel) | Module B (parallel) | Share DB? | Share API? | Share Code? | Thực sự independent? |
|--------------------|--------------------|-----------|-----------|-----------|--------------------|
| [VD: CRM-Customer] | [VD: WH-Inventory] | ❌ | ❌ | ✅ shared/types | ✅ Có thể song song |
| [VD: Sales-Order] | [VD: FIN-Invoice] | ✅ orders table | ✅ | ✅ | ❌ KHÔNG song song |

### B.4. Kiểm Tra Phân Bổ Tài Nguyên

> *Verify: không sprint nào overloaded — realistic task counts per sprint.*

| Sprint | Số Features | Số Tasks | Ước lượng effort | Đánh giá |
|--------|------------|----------|-----------------|----------|
| [S01] | [3] | [15] | [2 weeks] | ✅ Hợp lý |
| [S02] | [5] | [35] | [2 weeks] | ❌ Overload |
| [S03] | [2] | [8] | [2 weeks] | ✅ Nhẹ — có thể ghép thêm |

### B.5. Tổng Kết Rà Soát Kế Hoạch

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Sai thứ tự phụ thuộc | [Số] | [Số] | [Số] | [Số] | [Số] |
| Sprint dependency conflict | [Số] | [Số] | [Số] | [Số] | [Số] |
| Không thể song song | [Số] | [Số] | [Số] | [Số] | [Số] |
| Sprint overload | [Số] | [Số] | [Số] | [Số] | [Số] |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Kế hoạch khả thi / Cần điều chỉnh X điểm / Cần lập lại kế hoạch]

---

## Phần C: Kiểm Tra Tính Nhất Quán Phase 5 (Consistency Check)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Tài liệu cần đọc:**
- Tất cả file trong `phase5-implementation/`
- `phase2-features/**/*.md` (feature specs)
- `_meta/req-registry.json` (registry source of truth)

### C.1. Nhất Quán Với Phase 2 Design

> *Kiểm tra: mỗi feature-plan.md traces back to a feature spec trong Phase 2.*

| Feature Plan | Feature Spec Phase 2 | Khớp? | Ghi chú |
|-------------|---------------------|-------|---------|
| [VD: tasks/crm/customer/customer-list-plan.md] | [features/crm/customer/customer-list.md] | ✅ / ❌ | |
| [VD: tasks/sales/order/order-create-plan.md] | [features/sales/order/order-create.md] | ✅ / ❌ | |
| [VD: Plan không có feature spec] | ❌ Thiếu | ❌ | Cần tạo feature spec hoặc xóa plan |

**Feature specs chưa có plan:**

| Feature Spec Phase 2 | Có Plan? | Có Tasks? | Hành động |
|---------------------|---------|----------|-----------|
| [VD: features/fin/reports/monthly-report.md] | ❌ | ❌ | Tạo plan + tasks |

### C.2. Nhất Quán Với Registry

> *Kiểm tra: implementation_order trong registry khớp với module-plan.md và dependency-graph.md.*

| Module trong Registry | implementation_order | Trong module-plan? | Trong dependency-graph? | Trong roadmap? | Đánh giá |
|----------------------|---------------------|-------------------|-----------------------|---------------|----------|
| [VD: MOD-CRM-CUST] | Layer 0, Priority 1 | ✅ | ✅ | ✅ S01 | Khớp |
| [VD: MOD-FIN-RPT] | Layer 2, Priority 3 | ✅ | ❌ Thiếu | ✅ S04 | Cần bổ sung graph |
| [Module trong plan nhưng không trong registry] | — | ✅ | ✅ | ✅ | ❌ Không có trong registry |

### C.3. Nhất Quán Task Breakdown

> *Kiểm tra: mỗi story trong plan.md có corresponding tasks trong tasks.md.*

| Feature | Stories trong Plan | Tasks trong Tasks.md | Khớp? | Ghi chú |
|---------|-------------------|---------------------|-------|---------|
| [VD: customer-list] | [STORY-001, STORY-002, STORY-003] | [T001-T003, T004-T006, T007-T009] | ✅ | Đầy đủ |
| [VD: order-create] | [STORY-001, STORY-002] | [T001-T003] | ❌ | STORY-002 thiếu tasks |

### C.4. Nhất Quán Về Kỹ Thuật

> *Kiểm tra: tech stack trong tasks khớp với architecture decisions từ Phase 2.*

| Quyết định Architecture | Trong Tasks | Khớp? | Ghi chú |
|------------------------|------------|-------|---------|
| [VD: Backend: NestJS] | [Tasks dùng NestJS] | ✅ / ❌ | |
| [VD: DB: PostgreSQL] | [Tasks dùng PostgreSQL] | ✅ / ❌ | |
| [VD: Auth: JWT] | [Tasks implement JWT] | ✅ / ❌ | |
| [VD: API Style: REST] | [Tasks follow REST] | ✅ / ❌ | |

### C.5. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Feature plan ↔ spec không khớp | [Số] | | | | |
| Registry ↔ plan không khớp | [Số] | | | | |
| Story ↔ task không khớp | [Số] | | | | |
| Tech stack không khớp | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Tài liệu nhất quán / Cần sửa X điểm / Cần review lại nghiêm túc]

---

## Phần D: Phân Tích Thiếu Sót Kế Hoạch (Gap Analysis)

> Người thực hiện: [Tên] | Ngày: [Ngày/Tháng/Năm] | Trạng thái: Chưa bắt đầu → Đang review → Hoàn thành

**Cách thực hiện:**
1. Đọc toàn bộ tài liệu Phase 5
2. Dùng các checklist bên dưới để kiểm tra
3. Ghi lại gap + đề xuất hành động
4. Quay lại sửa tài liệu gốc

### D.1. Gap Về Task Coverage

> *Kiểm tra: có features nào chưa có implementation tasks?*

| STT | Feature | Có Plan? | Có Tasks? | Mức ảnh hưởng | Hành động |
|-----|---------|---------|----------|--------------|-----------|
| 1 | [VD: FEAT-CRM-CUST-001 Customer List] | ✅ | ✅ | — | Đầy đủ |
| 2 | [VD: FEAT-FIN-RPT-001 Monthly Report] | ✅ | ❌ | High | Tạo tasks breakdown |
| 3 | [VD: FEAT-WH-INV-003 Stock Alert] | ❌ | ❌ | Medium | Tạo plan + tasks |

### D.2. Gap Về Test Strategy

> *Kiểm tra: có kế hoạch testing cho từng feature/sprint không?*

| STT | Gap | Feature/Sprint liên quan | Mức ảnh hưởng | Hành động |
|-----|-----|-------------------------|--------------|-----------|
| 1 | [VD: Thiếu unit test tasks cho module CRM] | [S02-CRM] | High | Thêm test tasks |
| 2 | [VD: Thiếu integration test plan] | [Toàn hệ thống] | Critical | Tạo integration test strategy |
| 3 | [VD: Thiếu E2E test cho critical flows] | [Order → Invoice → Payment] | High | Thêm E2E test tasks |

#### Checklist Test Strategy

| STT | Yêu cầu | Có trong kế hoạch? | Ghi chú |
|-----|---------|-------------------|---------|
| 1 | Unit test tasks cho mỗi feature | ✅ / ❌ | |
| 2 | Integration test tasks | ✅ / ❌ | |
| 3 | E2E test cho critical user flows | ✅ / ❌ | |
| 4 | Performance/load test tasks | ✅ / ❌ | |
| 5 | Security test tasks | ✅ / ❌ | |
| 6 | UAT (User Acceptance Test) plan | ✅ / ❌ | |

### D.3. Gap Về Infrastructure Tasks

> *Kiểm tra: có tasks cho DB migration, CI/CD setup, environment configuration không?*

| STT | Gap | Mức ảnh hưởng | Hành động |
|-----|-----|--------------|-----------|
| 1 | [VD: Thiếu tasks setup dev environment] | High | Thêm vào S01-Foundation |
| 2 | [VD: Thiếu tasks DB migration scripts] | Critical | Thêm migration tasks cho mỗi sprint |
| 3 | [VD: Thiếu tasks CI/CD pipeline setup] | High | Thêm vào S01-Foundation |
| 4 | [VD: Thiếu tasks seed data / master data] | Medium | Thêm data seeding tasks |

### D.4. Gap Về Data Migration

> *Kiểm tra: nếu có hệ thống cũ, có kế hoạch migrate data không?*

| STT | Gap | Mức ảnh hưởng | Hành động |
|-----|-----|--------------|-----------|
| 1 | [VD: Thiếu data mapping plan (old → new schema)] | Critical | Tạo migration mapping |
| 2 | [VD: Thiếu data validation tasks sau migration] | High | Thêm validation tasks |
| 3 | [VD: Thiếu rollback plan nếu migration lỗi] | High | Tạo rollback procedure |

> *Nếu không có hệ thống cũ: ghi N/A*

### D.5. Gap Về Documentation Tasks

> *Kiểm tra: có tasks cho documentation trong kế hoạch không?*

| STT | Gap | Mức ảnh hưởng | Hành động |
|-----|-----|--------------|-----------|
| 1 | [VD: Thiếu tasks API documentation generation] | Medium | Thêm API docs tasks |
| 2 | [VD: Thiếu tasks changelog / release notes] | Low | Thêm vào sprint retrospective |
| 3 | [VD: Thiếu tasks update README per module] | Low | Thêm vào definition of done |

### D.6. Tổng Kết Gap Analysis

**Tổng số gap phát hiện:**

| Loại gap | Số lượng | Critical | High | Medium | Low |
|----------|----------|----------|------|--------|-----|
| Task Coverage | [Số] | | | | |
| Test Strategy | [Số] | | | | |
| Infrastructure Tasks | [Số] | | | | |
| Data Migration | [Số] | | | | |
| Documentation Tasks | [Số] | | | | |
| **Tổng** | **[Số]** | **[Số]** | **[Số]** | **[Số]** | **[Số]** |

**Kết luận:** [Không có gap nghiêm trọng / Cần bổ sung X điểm / Nhiều gap — cần review lại]

**Hành động ưu tiên cao nhất:**

1. [Gap quan trọng nhất — cần sửa ngay]
2. [Gap quan trọng thứ 2]
3. [Gap quan trọng thứ 3]
