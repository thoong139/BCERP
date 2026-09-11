# P5-00 — Implementation Roadmap

> **Mục đích:** Tổng quan lộ trình triển khai toàn bộ hệ thống, thứ tự thực hiện và tiến độ tổng thể.
>
> **Ai viết:** Tech Lead, Architect sau khi hoàn thành Phase 2 Design
>
> **Khi viết:** Sau khi hoàn thành `/wf-plan-modules` - có implementation order
>
> **Cập nhật:** Liên tục trong quá trình triển khai
>
> READS: `_meta/req-registry.json`, `phase2-features/[sys]/[mod]/[feat].md`, `phase3-architecture/P3-01-architecture.md`, `phase4-ux/[sys]/[mod]/[screen-group].md` (nếu interface_type != api-only)
> USED BY: `sprints/S0X-*.md`, `tasks/[sys]/[mod]/[feat]-impl.md`

---

## 1. Thông Tin Dự Án

| Mục | Giá trị |
|-----|---------|
| **Tên dự án** | *[Tên dự án]* |
| **Ngày bắt đầu** | *[YYYY-MM-DD]* |
| **Ngày dự kiến hoàn thành** | *[YYYY-MM-DD]* |
| **Tech Lead** | *[Tên]* |
| **Số systems** | *[Số lượng]* |
| **Số modules** | *[Số lượng]* |
| **Số features** | *[Số lượng]* |

---

## 2. Thứ Tự Triển Khai (Implementation Order)

> Thiết lập bởi `/wf-plan-modules` dựa trên dependency graph

### 2.1 Dependency Graph Overview

```
*[Vẽ sơ đồ hoặc mô tả dependency giữa các systems]*

Ví dụ:
AUTH (không phụ thuộc ai)
  ↓
CRM (phụ thuộc AUTH)
  ↓
SALES (phụ thuộc CRM)
  ↓
FINANCE (phụ thuộc SALES)
```

### 2.2 Implementation Phases

| Phase | System | Priority | Dependencies | Status | Start Date | End Date |
|-------|--------|----------|--------------|--------|------------|----------|
| 1 | *[SYSTEM-1]* | Critical | - | ⬜ not_started | - | - |
| 2 | *[SYSTEM-2]* | High | *[SYSTEM-1]* | ⬜ not_started | - | - |
| 3 | *[SYSTEM-3]* | High | *[SYSTEM-1]* | ⬜ not_started | - | - |
| 4 | *[SYSTEM-4]* | Medium | *[SYSTEM-2]* | ⬜ not_started | - | - |
| ... | ... | ... | ... | ... | ... | ... |

**Status Legend:**
- ⬜ `not_started` - Chưa bắt đầu
- 🔄 `in_progress` - Đang thực hiện
- ✅ `completed` - Hoàn thành
- ⏸️ `paused` - Tạm dừng
- ❌ `blocked` - Bị block

---

## 3. Module Breakdown

### [SYSTEM-1]: *[Tên System]*

| Module | Features | Complexity | Status | Progress |
|--------|----------|------------|--------|----------|
| *[MOD-1]* | X features | Simple/Medium/Complex | ⬜ | 0% |
| *[MOD-2]* | X features | Simple/Medium/Complex | ⬜ | 0% |

### [SYSTEM-2]: *[Tên System]*

| Module | Features | Complexity | Status | Progress |
|--------|----------|------------|--------|----------|
| ... | ... | ... | ... | ... |

---

## 4. Sprint Planning

> Tổ chức triển khai theo sprint (thường 2 tuần/sprint)

| Sprint | Tên | Focus Systems/Modules | Features | Status | Progress |
|--------|-----|----------------------|----------|--------|----------|
| S01 | Foundation | AUTH, Core | X features | ⬜ | 0% |
| S02 | *[Tên]* | *[Systems]* | X features | ⬜ | 0% |
| S03 | *[Tên]* | *[Systems]* | X features | ⬜ | 0% |
| ... | ... | ... | ... | ... | ... |

**Chi tiết sprint:** Xem thư mục `sprints/`

---

## 5. Feature Queue

> Danh sách tất cả features theo thứ tự ưu tiên triển khai

### 5.1 Critical Priority

| Feature ID | Name | System | Module | Sprint | Status |
|------------|------|--------|--------|--------|--------|
| FEAT-XXX-001 | *[Tên]* | *[SYS]* | *[MOD]* | S01 | ⬜ |
| ... | ... | ... | ... | ... | ... |

### 5.2 High Priority

| Feature ID | Name | System | Module | Sprint | Status |
|------------|------|--------|--------|--------|--------|
| ... | ... | ... | ... | ... | ... |

### 5.3 Medium Priority

| Feature ID | Name | System | Module | Sprint | Status |
|------------|------|--------|--------|--------|--------|
| ... | ... | ... | ... | ... | ... |

### 5.4 Low Priority

| Feature ID | Name | System | Module | Sprint | Status |
|------------|------|--------|--------|--------|--------|
| ... | ... | ... | ... | ... | ... |

---

## 6. Progress Summary

### 6.1 Tổng Quan

| Metric | Count | Percentage |
|--------|-------|------------|
| **Total Features** | *[X]* | 100% |
| ✅ Completed | *[X]* | *[X]%* |
| 🔄 In Progress | *[X]* | *[X]%* |
| ⬜ Not Started | *[X]* | *[X]%* |
| ⏸️ Paused | *[X]* | *[X]%* |
| ❌ Blocked | *[X]* | *[X]%* |

### 6.2 Theo System

| System | Total | Done | Progress |
|--------|-------|------|----------|
| *[SYS-1]* | X | 0 | 0% |
| *[SYS-2]* | X | 0 | 0% |
| ... | ... | ... | ... |

### 6.3 Theo Sprint

| Sprint | Total | Done | Progress | Status |
|--------|-------|------|----------|--------|
| S01 | X | 0 | 0% | ⬜ |
| S02 | X | 0 | 0% | ⬜ |
| ... | ... | ... | ... | ... |

---

## 7. Risk & Blockers

### 7.1 Current Blockers

| ID | Feature/System | Blocker | Impact | Resolution | Owner | Due Date |
|----|----------------|---------|--------|------------|-------|----------|
| B001 | *[FEAT-XXX]* | *[Mô tả]* | High/Medium/Low | *[Giải pháp]* | *[Tên]* | *[Date]* |

### 7.2 Risks

| ID | Risk | Probability | Impact | Mitigation | Owner |
|----|------|-------------|--------|------------|-------|
| R001 | *[Mô tả]* | High/Medium/Low | High/Medium/Low | *[Giảm thiểu]* | *[Tên]* |

---

## 8. Change Log

| Date | Change | Affected Items | Reason |
|------|--------|----------------|--------|
| *[YYYY-MM-DD]* | *[Mô tả]* | *[IDs]* | *[Lý do]* |

---

## 9. Notes

*[Ghi chú thêm về lộ trình triển khai, quyết định quan trọng, v.v.]*

---

## Checklist Before Starting Implementation

- [ ] Đã hoàn thành Phase 2 Technical Design
- [ ] Đã chạy `/wf-plan-modules` để xác định implementation order
- [ ] Đã tạo sprint plans trong `sprints/`
- [ ] Đã tạo feature plans trong `tasks/[system]/[module]/`
- [ ] Đã review với team về lộ trình
- [ ] Đã setup development environment
