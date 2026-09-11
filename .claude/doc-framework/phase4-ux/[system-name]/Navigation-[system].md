# Navigation: [Tên Phân Hệ]

> **System ID:** SYS-[XXX]
> **Ngày:** [Ngày/Tháng/Năm]
>
> READS: `design-system.md`, `phase2-features/[sys]/[mod]/[feat].md`, `phase3-architecture/P3-01-architecture.md`
> USED BY: `[mod]/[screen-group].md`

---

## 1. Sơ Đồ Menu (Menu Tree)

```
[Tên Phân Hệ]
├── 📊 Dashboard
│   └── Tổng quan                 → /dashboard           → dashboard.md
│
├── 👥 CRM
│   ├── Leads                     → /leads               → lead-list.md
│   │   └── Chi tiết Lead         → /leads/:id           → lead-detail.md
│   ├── Khách hàng                → /customers           → customer-list.md
│   │   └── Chi tiết KH           → /customers/:id       → customer-detail.md
│   ├── Pipeline                  → /pipeline            → pipeline.md
│   └── Phân khúc                 → /segments            → segment-list.md
│
├── 📋 Bán hàng
│   ├── Báo giá                   → /quotes              → quote-list.md
│   │   └── Tạo/Sửa Báo giá       → /quotes/:id          → quote-form.md
│   ├── Đơn hàng                  → /orders              → order-list.md
│   │   └── Chi tiết ĐH           → /orders/:id          → order-detail.md
│   └── Giao hàng                 → /delivery            → delivery-list.md
│
├── 📈 Báo cáo
│   ├── Pipeline                  → /reports/pipeline    → pipeline-report.md
│   ├── Hiệu suất team            → /reports/performance → performance-report.md
│   └── Theo kênh                 → /reports/channel     → channel-report.md
│
└── ⚙️ Cài đặt
    ├── Cấu hình Pipeline         → /settings/pipeline   → pipeline-settings.md
    ├── Quy tắc chấm điểm         → /settings/scoring    → scoring-settings.md
    └── Quy tắc phân công         → /settings/assignment → assignment-settings.md
```

*Điền menu tree theo thực tế. Hỗ trợ nhiều cấp: Group → Sub-group → Item → Sub-route.*

---

## 2. Danh Sách Screen Groups

| Screen Group | Route | File | UI-ID | Module |
|-------------|-------|------|-------|--------|
| Dashboard | `/[sys]/dashboard` | `dashboard/dashboard.md` | `UI-[SYS]-DASH-001` | Dashboard |
| Lead List | `/[sys]/leads` | `crm/lead-list.md` | `UI-[SYS]-LEAD-001` | CRM |
| Lead Detail | `/[sys]/leads/:id` | `crm/lead-detail.md` | `UI-[SYS]-LEAD-002` | CRM |
| Customer List | `/[sys]/customers` | `crm/customer-list.md` | `UI-[SYS]-CUST-001` | CRM |
| Customer Detail | `/[sys]/customers/:id` | `crm/customer-detail.md` | `UI-[SYS]-CUST-002` | CRM |
| Pipeline | `/[sys]/pipeline` | `crm/pipeline.md` | `UI-[SYS]-PIPE-001` | CRM |
| Quote List | `/[sys]/quotes` | `sales/quote-list.md` | `UI-[SYS]-QUOT-001` | Sales |
| Quote Form | `/[sys]/quotes/:id` | `sales/quote-form.md` | `UI-[SYS]-QUOT-002` | Sales |
| Order List | `/[sys]/orders` | `sales/order-list.md` | `UI-[SYS]-ORDR-001` | Sales |
| Order Detail | `/[sys]/orders/:id` | `sales/order-detail.md` | `UI-[SYS]-ORDR-002` | Sales |
| ... | ... | ... | ... | ... |

**Screen Group = Main page + Tabs + Dialogs + Sheets + View modes**

---

## 3. Phân Quyền & Hiển Thị Menu

> *Gộp chi tiết menu items, phân quyền, badges, và điều kiện hiển thị.*

| Menu Item | Route | Xem | Sửa | Xóa | Badge | Hiện khi nào |
|-----------|-------|-----|-----|-----|-------|--------------|
| Dashboard | `/dashboard` | All | — | — | — | Luôn |
| Leads | `/leads` | All | Sales, Manager | Owner, Admin | `{new_count}` | Luôn |
| Khách hàng | `/customers` | All | Sales, Manager | Admin | — | Luôn |
| Pipeline | `/pipeline` | All | Sales, Manager | — | `{won_count}` | Luôn |
| Phân khúc | `/segments` | Admin, Manager | Admin, Manager | Admin | — | Role: Admin, Manager |
| Báo giá | `/quotes` | All | Sales, Manager | Admin | `{draft_count}` | Luôn |
| Đơn hàng | `/orders` | All | Sales, Manager | Admin | `{pending_count}` | Luôn |
| Giao hàng | `/delivery` | All | Sales, Manager | — | — | Luôn |
| Báo cáo/* | `/reports/*` | All | — | — | — | Luôn |
| Cài đặt/* | `/settings/*` | Admin | Admin | Admin | — | Role: Admin |

---

## 4. UI Notes

> *Quick Actions, Breadcrumbs, và quy ước đặt tên — gộp thành reference nhanh.*

### 4.1. Quick Actions (Header Bar)

| Action | Icon | Phím tắt | Mở gì |
|--------|------|----------|-------|
| Tạo mới (context-aware) | `Plus` | `Ctrl+N` | Dialog tạo mới theo context |
| Tìm kiếm tổng | `Search` | `Ctrl+K` | Global Search Dialog |
| Tạo Báo giá | `FileText` | `Ctrl+Q` | Route: /quotes/create |
| Thông báo | `Bell` | — | Notification Panel |

### 4.2. Breadcrumb Pattern

```
[Nhóm Menu] > [Menu Item] > [Tên cụ thể hoặc "Tạo mới"]

Ví dụ:
  CRM > Leads > [Lead Name]
  Bán hàng > Báo giá > Tạo mới
  Bán hàng > Đơn hàng > [Order Number]
  Cài đặt > [Tên cài đặt]
```

### 4.3. Quy Ước Đặt Tên File

| Loại màn hình | Filename | Route pattern |
|--------------|----------|---------------|
| Danh sách | `*-list.md` | `/[module]` |
| Chi tiết | `*-detail.md` | `/[module]/:id` |
| Form tạo/sửa | `*-form.md` | `/[module]/create` hoặc `/:id/edit` |
| Dashboard | `*-dashboard.md` | `/dashboard` |
| Báo cáo | `*-report.md` | `/reports/[name]` |
| Cài đặt | `*-settings.md` | `/settings/[name]` |

### 4.4. Icon Library

> **Validation requirement:** Tất cả icons được sử dụng trong section này PHẢI tồn tại trong `phase4-ux/design-system.md § Icon Library`. Sử dụng icon không có trong design-system → INVALID — thêm vào design-system trước.

> Thư viện mặc định: [Lucide / Heroicons / Material Icons]

| Menu | Icon |
|------|------|
| Dashboard | `LayoutDashboard` |
| Leads | `UserPlus` |
| Customers | `Users` |
| Pipeline | `GitBranch` |
| Quotes | `FileText` |
| Orders | `ShoppingCart` |
| Reports | `BarChart3` |
| Settings | `Settings` |

---

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Thiết kế chi tiết màn hình | `[module-name]/[screen-group].md` |
| API endpoints | `../../phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `../../phase3-architecture/technical-specs/integration-map.md` |
| Design system | `../design-system.md` |
| REQ-IDs | `../../_meta/req-registry.json` |
