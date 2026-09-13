### 4.5. Bố Cục & Responsive (ux-architect)

#### Kiến trúc CSS

**Naming: BEM**, mở rộng từ quy ước §6 design-system. Chọn BEM (không utility-first) vì: (a) team ERP nhỏ, surfaces là component dày đặc (datagrid vài trăm cell, split view, panel) — utility-first làm markup phình, khó review; (b) 12 component nghiệp vụ §4 map 1:1 sang block; (c) tokens đã là CSS custom properties, BEM giữ cascade đoán được. Cú pháp: `bcerp-{block}__{element}--{modifier}` (VD `bcerp-datagrid__cell--money`, `bcerp-side-panel--overlay`). Chỉ cho phép một lớp utility mỏng tiền tố `u-` (spacing, `u-numeric` bật `--font-numeric`, `u-visually-hidden`).

Tổ chức file (import theo thứ tự = thứ tự cascade):

```
src/styles/
├── tokens/        tokens.css — nơi DUY NHẤT chứa giá trị, sinh từ design-system §1–§3
├── base/          reset.css, typography.css, focus.css (focus ring 2px toàn cục)
├── layout/        app-shell.css, grid.css, containers.css
├── components/    1 file/block: datagrid, side-panel, command-bar, approval-card…
├── surfaces/      worklist.css, split-view.css, detail-360.css, dashboard.css, registry.css
└── utilities/     u-*.css
```

Khai báo `@layer tokens, base, layout, components, surfaces, utilities` — surface không bao giờ thắng component bằng specificity, chỉ bằng layer.

**Theming (light-first):** giá trị light đặt ở `:root`; hook `[data-theme="dark"]` chừa sẵn nhưng v1 không triển khai. Density là "theme" duy nhất cần ngay: attribute `data-density="compact|comfortable"` trên surface root đổi `--row-height-*` — toggle per-user trong Settings, persist. **Workspace KHÔNG theme màu riêng** — token trạng thái là bắt buộc, cấm tint tự chế; bản sắc workspace chỉ qua nav rail (active icon + `--color-primary`) và breadcrumb.

#### App shell + breakpoints (desktop-first)

App shell (CSS Grid): `grid-template-columns: 60px 1fr; grid-template-rows: 48px auto auto 1fr` — nav rail (`--color-nav-rail`) | topbar (tìm kiếm toàn cục · bell → notification drawer · user), rồi page-header (breadcrumb + tiêu đề + action), CommandBar, content. Notification là global drawer, không phải page (đúng consolidation S11).

Breakpoints — base styles = desktop, chỉ dùng `max-width` queries:

| Query | Thay đổi |
|---|---|
| Base ≥1280px | Nav rail đầy đủ, split view, side panel 360px đẩy nội dung |
| `max-width: 1279px` | Nav rail thu icon; datagrid ẩn cột phụ (giữ tiền + trạng thái); SidePanel → overlay; split view → master full, detail mở như panel |
| `max-width: 767px` | Chỉ bật cho surface có nghiệp vụ mobile thật (duyệt nhanh manager, ack Alert Center, xem commission); list → card, touch ≥44px; **datagrid data-heavy không render — hiển thị EmptyState "Mở trên web"** |

Container: worklist/approval full-width max 1920px; dashboard max 1600px center; form/edit max 960px. Grid 12 cột, gutter `--space-4`, margin trang `--space-6`.

#### Surface → layout pattern (design-system §5)

| Nhóm surface (inventory) | Pattern | Density / container |
|---|---|---|
| S1 (+Lead 360 detail), S16, S15 | W2 split view 40/60: `minmax(360px, 40%) 1fr` | Compact 32px, full-width |
| S6, S21, S24 (thân escalation inbox), S10 (tabs AR/AP/HĐĐT) | W1 worklist + bulk bar + quick chips | Compact; S6 keyboard-first |
| S7, S9, S5, S17 | W1 variant standard (S7 thêm dải đối trừ 3 số) | Compact (tiền) |
| S3 Deal Desk, S28 Client 360, S14 campaign 360 | W3 content + panel phải 360px (`1fr 360px`): WaitingOn + ProgressTracker + Timeline 3 dòng | Comfortable; panel collapse được |
| S23 Executive BI | W4 dashboard grid (KPI row → widget 12 cột, widget click → worklist đã lọc) | Spacious, max 1600px |
| S24 (khung trên), S22 | W4 cho hàng KPI/SLA + thân W1 | Spacious + compact |
| S18, S19, S20, S26, S27, S25 | Registry/admin: bảng standard + edit qua SidePanel 480px; form cấu hình container 960px | Comfortable |

**CSS isolation:** mọi component chỉ style trong block của nó (cấm selector con xuyên block); surface files chỉ viết bên trong `[data-surface="{tên}"]`; cấm hex ngoài `tokens.css`; z-index theo scale token (`--z-bulk-bar < --z-panel < --z-drawer < --z-modal < --z-toast`); vendor/thư viện thứ ba bọc trong `bcerp-vendor-*`. Không Shadow DOM — phá inheritance token.

#### Keyboard-first Approval Inbox (S6)

Vùng inbox là listbox roving-tabindex: ↑↓ chuyển ApprovalCard, **A** duyệt, **R** từ chối (mở modal, focus thẳng textarea lý do ≥10 ký tự), Enter mở context (SidePanel 480px), Space chọn bulk, `?` mở cheat-sheet phím tắt. Phím tắt vô hiệu khi focus nằm trong input/combobox. Sau duyệt (kể cả MFA step-up): focus chuyển card kế tiếp, không reload danh sách. Esc đóng panel và trả focus về card/hàng vừa mở. Focus luôn visible 2px; processing state khóa nút chống double-submit; mọi đường xử lý tiền không có animation (chỉ state + toast).
