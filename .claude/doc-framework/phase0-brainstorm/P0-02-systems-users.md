# Bản Đồ Hệ Thống & Người Dùng — [TÊN DỰ ÁN]

> **Loại tài liệu:** Discovery Phase 0
> **Ngày:** [Ngày/Tháng/Năm]
> **Trạng thái:** Đang khám phá → Đã chốt → Chuyển sang Phase 1
>
> READS: `P0-01-brainstorm.md` (org context, system areas, platform, business policies)
> USED BY: `stakeholder-review.md`, `phase1-business/P1-01-project-overview.md`, `phase1-business/P1-02-business-workflow.md`, `phase3-architecture/P3-01-architecture.md`

---

> ## Hướng Dẫn Sử Dụng File Này
>
> File này do **`architect` + `business-analyst`** soạn thảo dựa trên kết quả từ P0-01.
>
> - **🤖 Section 1:** `architect` vẽ bản đồ hệ thống, quan hệ, thứ tự xây dựng
> - **🤖 Section 2:** `architect` + `business-analyst` xác định roles, phân quyền, xác thực
> - **🤖 Section 3:** `architect` định nghĩa NFR (performance, availability, reliability)
> - **🤖 Section 4:** `architect` đề xuất tech stack với lý do cụ thể theo ngành
>
> User chỉ cần **xác nhận** sau khi agents hoàn thành.
>
> *Xóa phần hướng dẫn này sau khi hoàn thành.*

---

## 1. Bản Đồ Hệ Thống

### 1.1. Danh Sách Hệ Thống

> **🤖 Phân tích bởi `architect`** — dựa trên `platform`, `phân hệ`, `interface_type` từ P0-01

| STT | Tên hệ thống | Loại | Phục vụ nhóm nào | Ưu tiên xây |
|-----|-------------|------|-----------------|-------------|
| 1 | [Agent điền] | [Web/Mobile/...] | [Agent điền] | GĐ1 / GĐ2 / Sau |
| 2 | [Agent điền] | | | |
| 3 | [Agent điền] | | | |

**Loại hệ thống:** `Web` / `Mobile (iOS)` / `Mobile (Android)` / `Mobile (cross-platform)` / `Desktop` / `API-only` / `Bot/Automation`

### 1.2. Quan Hệ Giữa Các Hệ Thống

> **🤖 Phân tích bởi `architect`** — nhóm hệ thống theo shared backend/auth, tích hợp ngang

**Nhóm [A] — [Tên nhóm]:**
- [Hệ thống] → [mô tả quan hệ]

**Tích hợp ngang (Cross-cutting Integrations):**
- [Hệ thống bên ngoài] → [chiều tích hợp, phương thức]

```
[Sơ đồ quan hệ — ASCII art hoặc mô tả]
```

### 1.3. Thứ Tự Xây Dựng & Phụ Thuộc

> **🤖 Phân tích bởi `architect`** — dependency graph, build order

```
GIAI ĐOẠN 1:
  [Module/Service] → [Module/Service phụ thuộc]

GIAI ĐOẠN 2:
  [Module/Service]
```

**Lý do phụ thuộc:**
- [Lý do kỹ thuật / nghiệp vụ]

---

## 2. Users & Roles

### 2.1. Danh Sách Roles Toàn Hệ Thống

> **🤖 Phân tích bởi `architect` + `business-analyst`** — dựa trên phòng ban (P0-01 Section 2) và phân hệ (P0-01 Section 3)

| STT | Role ID | Tên Role | Mô tả ngắn | Dùng hệ thống nào |
|-----|---------|---------|-----------|------------------|
| 1 | [Agent điền] | [Agent điền] | [Agent điền] | [Agent điền] |
| 2 | | | | |

### 2.2. Phân Quyền Tổng Quát

> **🤖 Phân tích bởi `architect`** — quyền chính và giới hạn cho từng role

| Role | Được làm | KHÔNG được làm |
|------|---------|----------------|
| [Role ID] | [Agent điền] | [Agent điền] |

### 2.3. Phân Cấp Quyền

> **🤖 Phân tích bởi `architect`** — hierarchy, approval thresholds, SoD

**Nguyên tắc cấp bậc:**
- [VD: Manager xem được toàn bộ dữ liệu của Staff trong phòng ban mình]

**Nguyên tắc phân cấp phê duyệt:**

| Loại giao dịch | Staff | Manager | BOD |
|---------------|-------|---------|-----|
| [Agent điền] | Tạo | Phê duyệt ≤ [ngưỡng] | Phê duyệt > [ngưỡng] |

### 2.4. Cơ Chế Xác Thực Đề Xuất Per Hệ Thống

> **🤖 Phân tích bởi `architect`** — auth mechanism, IdP, token strategy

| Hệ thống | Cơ chế đề xuất | Lý do |
|----------|----------------|-------|
| [Agent điền] | [Agent điền] | [Agent điền] |

**Identity Provider (IdP) đề xuất:**
- [Agent điền với lý do cụ thể]

### 2.5. Quản Lý Tài Khoản

> **🤖 Phân tích bởi `architect`** — account lifecycle, password policy, session management

| Quy tắc | Nội dung đề xuất |
|---------|-----------------|
| Tạo tài khoản | [Agent điền] |
| Vô hiệu hóa tài khoản | [Agent điền] |
| Password policy | [Agent điền] |

---

## 3. Yêu Cầu Phi Chức Năng (NFR)

### 3.1. Scale & Performance

> **🤖 Phân tích bởi `architect`** — dựa trên quy mô (P0-01 Section 1) và số lượng hệ thống

**Ước tính concurrent users:**

| Phân khúc | Estimate DAU | Concurrent (peak) | Cơ sở |
|-----------|-------------|-------------------|-------|
| [Agent điền] | | | |

**Performance targets:**

| Tiêu chí | Target | Ghi chú |
|---------|--------|---------|
| API response time (P95) | [Agent điền] | |
| Page load time | [Agent điền] | |

### 3.2. Availability & Reliability

> **🤖 Phân tích bởi `architect`**

| Tiêu chí | Đề xuất | Ghi chú |
|---------|---------|---------|
| Uptime target | [Agent điền] | |
| RTO | [Agent điền] | |
| RPO | [Agent điền] | |
| Backup strategy | [Agent điền] | |

---

## 4. Tech Stack Đề Xuất

> **🤖 Phân tích bởi `architect`** — dựa trên: ngành nghề, đặc thù kỹ thuật, quy mô team, yêu cầu pháp lý

### 4.1. Stack Chính (Khuyến Nghị)

| Layer | Công nghệ đề xuất | Lý do |
|-------|------------------|-------|
| Backend API | [Agent điền] | [Agent điền] |
| Frontend Web | [Agent điền] | [Agent điền] |
| Mobile | [Agent điền] | [Agent điền] |
| Database | [Agent điền] | [Agent điền] |
| Auth / SSO | [Agent điền] | [Agent điền] |
| Infrastructure | [Agent điền] | [Agent điền] |

### 4.2. Phương Án Thay Thế (Để Tham Khảo)

[Agent điền nếu có phương án B với trade-off phân tích]

---

**Ngày soạn:** [Ngày/Tháng/Năm]
**Phiên bản:** 1.0

<!-- Ghi chú: Cập nhật Phiên bản khi có thay đổi lớn về systems hoặc users scope -->
