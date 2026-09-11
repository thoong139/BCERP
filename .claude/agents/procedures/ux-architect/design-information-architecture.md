# Playbook: Thiết kế Information Architecture

> **Type**: Agent Skill Playbook
> **Agent**: ux-architect
> **Triggered by**: `/wf-design-ux` Phase 4 khi cần design navigation/IA cho app
> **Output**: `.mc-data/docs/phase4-ux/information-architecture.md`

---

## Khi nào dùng playbook này

- Khi dự án có UI cần xác lập cấu trúc navigation và content hierarchy
- Khi số lượng features đủ lớn để cần quyết định grouping và routing
- Khi cần design URL patterns và deep linking strategy
- Khi permission-based navigation cần xác lập rules rõ ràng

---

## Procedure

### Bước 1: Đọc feature specs và user personas

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (features), PHASE1 (requirements)

Cần đọc:
□ .mc-data/docs/phase2-features/ — tất cả feature specs
□ .mc-data/docs/phase1-business/ — personas, user roles, permissions
□ req-registry.json — danh sách systems, modules, interface_type

Cần xác định:
□ Số lượng user roles và permissions levels
□ Core user journeys (top 3-5 flows quan trọng nhất)
□ Số lượng primary sections/modules
□ Interface type: Web app / Mobile app / Both?
□ Tần suất sử dụng mỗi feature (daily vs occasional)
```

### Bước 2: Content inventory

```
Liệt kê toàn bộ "content" cần có trong app — mỗi item gồm:

| Content Item | Type | User Role(s) | Frequency | Parent Section |
|-------------|------|-------------|-----------|----------------|
| Dashboard tổng quan | Page | All users | Daily | Home |
| Danh sách đơn hàng | Page | Sales, Manager | Daily | Orders |
| Chi tiết đơn hàng | Page | Sales, Manager | Daily | Orders |
| Tạo đơn hàng mới | Form | Sales | Daily | Orders |
| Báo cáo doanh thu | Page | Manager, Director | Weekly | Reports |
| Cài đặt hệ thống | Page | Admin | Occasional | Settings |

Nhóm content thành clusters dựa trên:
□ Liên quan về chức năng (cùng domain)
□ Cùng user audience (không phải mọi user đều cần mọi thứ)
□ Tần suất sử dụng (daily features nên ít click nhất)
```

### Bước 3: User mental models

```
Đặt câu hỏi: User nghĩ về app này theo cách nào?

Ví dụ mental models phổ biến:
□ Theo workflow: "Tôi muốn xử lý đơn hàng" → Orders → Pending → Process
□ Theo entity: "Tôi muốn xem thông tin khách hàng X" → Customers → Search → Detail
□ Theo role: "Tôi là Manager, muốn approve" → Approvals → Queue → Action
□ Theo time: "Tôi muốn xem hôm nay" → Dashboard → Today view

Từ mental model:
□ Xác định primary navigation labels (dùng ngôn ngữ của user, không phải của dev)
□ Tránh jargon kỹ thuật trong labels
□ Nhóm theo task/goal, không theo database table
□ Validate với personas: "User A sẽ tìm X ở đâu?"
```

### Bước 4: Thiết kế site/app map

```
Tạo app map theo cấu trúc phân cấp:

Level 0 — Entry Points:
□ Login / Authentication
□ Onboarding (nếu có)
□ Home / Dashboard

Level 1 — Primary Navigation (tối đa 7 items — Miller's Law):
□ Chọn grouping dựa trên content clusters từ Bước 2
□ Đặt tên theo mental model của user (Bước 3)
□ Priority order: Tần suất sử dụng cao → trái/trên

Level 2 — Sub-navigation:
□ Dưới mỗi Level 1 item, các sub-sections
□ Nếu > 5 sub-items → cần review lại grouping

Level 3 — Detail Views:
□ Detail pages, forms, modals
□ Không nên có Level 4 trở lên (quá sâu → user lost)

Ví dụ format App Map:
---
Home (Dashboard)
├── Bán hàng
│   ├── Đơn hàng
│   │   ├── Danh sách đơn hàng [Filter: Tất cả / Chờ xử lý / Hoàn thành]
│   │   ├── Chi tiết đơn hàng
│   │   └── Tạo đơn hàng mới
│   ├── Khách hàng
│   │   ├── Danh sách khách hàng
│   │   └── Chi tiết khách hàng
│   └── Sản phẩm (read-only view)
├── Kho vận
│   ├── Tồn kho
│   └── Nhập kho / Xuất kho
├── Báo cáo
│   ├── Doanh thu
│   ├── Tồn kho
│   └── KPIs
└── Cài đặt (Admin only)
    ├── Người dùng & Phân quyền
    ├── Cấu hình hệ thống
    └── Dữ liệu danh mục
---
```

### Bước 5: Navigation patterns

```
Chọn navigation pattern phù hợp với app type và content depth:

WEB APP — Options:
□ Sidebar navigation (Left nav)
  + Hiển thị nhiều items cùng lúc
  + Dễ scan, collapsible
  - Chiếm width trên mobile
  Phù hợp: Dashboard apps, Admin panels, ERP/CRM

□ Top navigation bar
  + Quen thuộc, phổ biến
  + Tốt cho mobile (hamburger menu)
  - Giới hạn ~5-6 items visible
  Phù hợp: Marketing sites, Apps với ít sections

□ Hybrid: Top nav + Left sidebar
  + Top cho primary sections, Sidebar cho sub-sections
  Phù hợp: Complex apps (GitHub, Notion, Figma)

MOBILE APP — Options:
□ Bottom tab bar (iOS/Android native pattern)
  + Thumb-friendly, always visible
  + Tối đa 5 tabs (icon + label)
  Phù hợp: Consumer apps, khi user cần switch nhanh giữa sections

□ Drawer navigation (Hamburger menu)
  + Nhiều items hơn, tiết kiệm screen
  - Ít discoverable hơn bottom bar
  Phù hợp: Khi có nhiều sections, secondary navigation

□ Stack navigation (Push/Pop)
  + Native mobile feel
  - Linear flow, khó cross-navigate
  Phù hợp: Wizard flows, onboarding, detail pages

Breadcrumbs:
□ Sử dụng khi depth > 2 levels
□ Format: Home > Section > Sub-section > Current page
□ Mobile: Chỉ hiện level cha gần nhất (← Back)
```

### Bước 6: Search architecture

```
Xác định search scope và behavior:

Global search (nếu cần):
□ Tìm kiếm across entities: khách hàng, đơn hàng, sản phẩm
□ Trigger: Cmd+K / Ctrl+K (command palette) hoặc search bar
□ Result grouping theo entity type
□ Recent searches, suggested searches
□ Keyboard navigation trong results

Trong-section search / filter:
□ Mỗi list page cần filter/search riêng
□ Filters persistent (không mất khi back)
□ URL query params reflect filter state (deep linking)
□ "Không có kết quả" state có guidance

Search UX rules:
□ Debounce 300ms trước khi trigger search
□ Loading state khi waiting results
□ Highlight matched text trong results
□ Mobile: Search không nên require submit button (realtime search)
```

### Bước 7: Routing design

```
URL Pattern Design:

Nguyên tắc:
□ URL phải readable và predictable
□ Dùng kebab-case (không camelCase, không underscore)
□ Dùng danh từ số nhiều cho collections: /orders, /customers, /products
□ Dùng ID cho detail: /orders/123, /customers/456
□ Dùng sub-resource cho nested: /orders/123/items

Ví dụ URL patterns:
---
/                           → Dashboard
/orders                     → Danh sách đơn hàng
/orders/new                 → Tạo đơn hàng mới
/orders/:id                 → Chi tiết đơn hàng
/orders/:id/edit            → Sửa đơn hàng
/customers                  → Danh sách khách hàng
/customers/:id              → Chi tiết khách hàng
/reports/revenue            → Báo cáo doanh thu
/settings/users             → Quản lý người dùng
/settings/users/:id         → Chi tiết người dùng
---

Deep linking requirements:
□ Mọi "view" có thể bookmark/share được qua URL
□ Filter state → URL query params: /orders?status=pending&from=2026-01-01
□ Modal/drawer state: Tránh dùng URL cho modals (back button behavior phức tạp)
□ Pagination: /orders?page=2 hoặc cursor-based /orders?after=cursor_xyz

State management cho navigation:
□ Đọc URL khi component mount (không hardcode default state)
□ Push history khi state thay đổi (browser back/forward hoạt động đúng)
□ Replace history cho filter changes (không tạo new history entry mỗi keystroke)
```

### Bước 8: Permission-based navigation

```
Ba strategies cho permission-based navigation — chọn approach phù hợp:

Strategy A — Hide (ẩn hoàn toàn):
□ Không hiển thị menu items user không có quyền
+ UX sạch, không gây confusion
- User không biết features đó tồn tại
Phù hợp: Features không liên quan đến role (ví dụ: Admin tools với Sales user)

Strategy B — Disable (hiển thị nhưng disable):
□ Hiển thị menu item với visual disabled state + tooltip giải thích
+ User biết feature tồn tại, có thể yêu cầu quyền
- Có thể gây confusion nếu quá nhiều disabled items
Phù hợp: Features liên quan nhưng cần thêm quyền/subscription

Strategy C — Redirect (dẫn đến trang không đủ quyền):
□ Navigate được nhưng gặp "403 Forbidden" page có context
+ Rõ ràng về lý do, có call-to-action (liên hệ admin, upgrade)
Phù hợp: Direct URL access, không qua navigation menu

Implement permission check:
□ Frontend check: Ẩn/disable UI (UX layer)
□ Backend check: Validate LUÔN LUÔN (security layer)
□ Không bao giờ rely on frontend-only permission check cho data access

Route guard pattern:
```
Route /orders/create
→ Check: user.permissions.includes('orders.create')
→ YES: Render form
→ NO (hide strategy): Redirect to /orders
→ NO (redirect strategy): Render <PermissionDenied> với context
```

Permission inheritance:
□ Document rõ: Role A inherit tất cả permissions của Role B không?
□ Nếu có feature flags: Intersection của permission + feature flag
```

### Bước 9: Mobile navigation adaptation

```
Quy tắc adapt từ desktop sang mobile:

Navigation collapsing:
□ Sidebar → Hamburger + Drawer overlay (không push content)
□ Top nav nhiều items → Priority+ pattern (hiện top 3-4, ẩn còn lại vào "More")
□ Bottom tab bar: Tối đa 5 tabs — chọn 5 most frequent actions

Mobile-specific patterns:
□ Back button: Luôn có, không chỉ rely vào browser back
□ Pull-to-refresh cho lists
□ Floating Action Button (FAB) cho primary action ("+ Tạo mới")
□ Sheet/Drawer thay vì full-page modal cho filters và secondary content

Touch targets:
□ Minimum 44×44px cho mọi interactive element (WCAG 2.5.8)
□ Spacing giữa tap targets: tối thiểu 8px

Gesture navigation (iOS/Android):
□ Swipe back (iOS): Không override bằng swipe gesture khác
□ Swipe down to dismiss: Cho bottom sheets
□ Long press: Chỉ dùng nếu có visual hint (ripple, tooltip)

Content priority trên mobile:
□ Progressive disclosure: Hiện ít thông tin hơn, expand on demand
□ Truncate danh sách dài với "Xem thêm" thay vì infinite scroll không controlled
□ Forms: Một field per screen cho wizard flows phức tạp
```

### Bước 10: Ghi output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/information-architecture.md

Cấu trúc output:
1. Executive Summary — scope IA, số lượng sections, navigation pattern được chọn
2. App Map (full tree với permission indicators)
3. Navigation Pattern Decision (với lý do)
4. URL Pattern Guide (bảng đầy đủ)
5. Search Architecture
6. Permission-Based Navigation Rules
7. Mobile Adaptation Rules
8. Open Questions (nếu có ambiguity cần stakeholder confirm)
```

---

## Checklist trước khi submit

```
□ App map không có node nào sâu hơn Level 3
□ Primary navigation tối đa 7 items (Miller's Law)
□ URL patterns nhất quán, readable, kebab-case
□ Deep linking: mọi view có URL riêng
□ Permission strategy được chọn và documented rõ
□ Mobile adaptation đã address tất cả desktop navigation patterns
□ Search architecture có "không có kết quả" state
□ Labels dùng ngôn ngữ của user, không phải database/dev jargon
□ Open questions được list ra nếu có ambiguity
```
