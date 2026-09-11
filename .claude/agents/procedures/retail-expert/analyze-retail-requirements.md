# Playbook: Phân tích Retail Requirements

> **Type**: Agent Skill Playbook
> **Agent**: retail-expert
> **Triggered by**: /wf-analyze-requirements khi có retail, POS, chain store, franchise modules
> **Output**: `.mc-data/docs/phase1-business/retail-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: bán lẻ, POS, quản lý cửa hàng, chuỗi cửa hàng, franchise, omnichannel
- Khi cần xác định retail requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình bán lẻ (specialty store, convenience store, department store, supermarket, F&B)
□ Mô hình vận hành (Single store / Multi-store Chain / Franchise / Omni-channel)
□ Quy mô (số lượng cửa hàng, số SKU, số giao dịch/ngày)
□ Phân khúc thị trường (mass market, mid-range, premium, luxury)
□ Đã có hệ thống POS/ERP nào chưa? Nếu có → đang dùng gì?
□ Thị trường địa lý (Việt Nam, regional, global) → ảnh hưởng payment methods
```

### Bước 2: Xác định scope và mô hình vận hành

Dựa trên loại hình và mô hình, map ra phạm vi cần analyze:

| Mô hình | Modules thường cần |
|---------|-------------------|
| Single store | POS, Inventory, Cash management, Basic reporting |
| Multi-store Chain | POS, Inventory (multi-store), Store management, Centralized reporting, Transfer management |
| Franchise | Tất cả Chain + Franchise fee, Royalty tracking, Brand compliance |
| Omni-channel | Tất cả Chain + Ecommerce integration, Click & Collect, Ship from Store |

```
Load knowledge file tương ứng:
POS + giao dịch → READ: .claude/references/team-expert/retail/operations.md (Section POS Workflow)
Store management → READ: .claude/references/team-expert/retail/operations.md (Section Store Operations)
Controls & phân quyền → READ: .claude/references/team-expert/retail/controls.md
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: .claude/references/team-expert/retail/personas.md

Xác định ai sẽ dùng hệ thống retail:

STORE LEVEL:
□ Cashier (Thu ngân) → dùng POS hàng ngày, cần UI đơn giản, nhanh
□ Store Manager (Quản lý cửa hàng) → quản lý ca, tồn kho, báo cáo ngày
□ Stock Clerk (Nhân viên kho) → nhận hàng, kiểm kho, chuyển kho
□ Security (Bảo vệ) → anti-theft, camera monitoring

AREA / DISTRICT LEVEL:
□ Area Manager → xem dashboard nhiều cửa hàng, so sánh hiệu suất
□ Inventory Planner → phân bổ hàng hóa giữa các stores

HQ LEVEL:
□ HQ Admin / IT → cấu hình hệ thống, phân quyền, master data
□ Merchandiser → quản lý catalog, giá, khuyến mãi toàn chuỗi
□ Finance Controller → reconciliation, báo cáo doanh thu
□ Franchise Manager (nếu có) → quản lý franchisee, royalty

CUSTOMER:
□ Walk-in Customer → checkout nhanh, nhiều hình thức thanh toán
□ Loyalty Member → tích điểm, dùng voucher, xem lịch sử mua hàng

Với mỗi persona: note pain points và must-have features
```

### Bước 4: Identify store operations needs

```
READ: .claude/references/team-expert/retail/operations.md

Phân tích quy trình vận hành cần support:

OPENING PROCEDURES:
□ Mở ca: Kiểm tiền đầu ca, kích hoạt terminal
□ Nhận hàng buổi sáng: Goods receipt, cập nhật tồn kho
□ Price check: Đảm bảo giá đúng trước khi bán

SALES OPERATIONS:
□ Scan & checkout workflow
□ Discount và khuyến mãi (áp dụng luật nào?)
□ Hold transaction (khách tạm dừng mua)
□ Void / Cancel trước khi hoàn thành
□ Refund & exchange sau khi hoàn thành

CLOSING PROCEDURES:
□ Đóng ca: Đếm tiền mặt, reconcile với POS
□ Day-end report: Doanh thu, số giao dịch, thanh toán theo loại
□ Stock count cuối ngày (nếu áp dụng)

INVENTORY:
□ Perpetual inventory (real-time) hay periodic?
□ Reorder point và automatic PO?
□ Transfer between stores?
□ Shrinkage tracking (theft, damage, expiry)?
```

### Bước 5: Payment methods analysis

```
Xác định hình thức thanh toán cần support (thị trường Việt Nam):

CASH:
□ Thanh toán tiền mặt + thối tiền
□ Multiple currencies (nếu tourist area)
□ Cash void / overpayment handling

CARD:
□ Visa/Mastercard (swipe/chip/contactless)
□ JCB, UnionPay (tùy segment)
□ POS terminal integration (EDC machine)

E-WALLET (bắt buộc với thị trường VN):
□ VNPay QR
□ MoMo
□ ZaloPay
□ Shopee Pay
□ VNPT Pay / Viettel Pay

INSTALLMENT & CREDIT:
□ Trả góp qua thẻ tín dụng
□ Buy now pay later (Kredivo, Home Credit)

SPLIT PAYMENT:
□ Thanh toán nhiều phương thức cho 1 đơn hàng
□ Ví dụ: tiền mặt + VNPay, thẻ + điểm loyalty

LOYALTY POINTS:
□ Redeem điểm thay tiền mặt
□ Partial redemption

QUAN TRỌNG - OFFLINE MODE:
□ Khi mất kết nối mạng → POS vẫn phải chạy được
□ Giao dịch offline phải được lưu local và sync khi có mạng trở lại
□ Cash-only khi offline (không thể verify e-wallet/card real-time)
□ Conflict resolution khi sync (duplicate order ID, stock oversell)
```

### Bước 6: Integration points

```
Identify các hệ thống cần integrate:

ECOMMERCE (nếu omni-channel):
□ Catalog sync (sản phẩm, giá, hình ảnh)
□ Inventory sync (tồn kho real-time)
□ Order routing (Click & Collect, Ship from Store)
□ Return online purchase tại store

LOYALTY / CRM:
□ Identify customer at POS (phone, loyalty card, QR)
□ Point accumulation rules
□ Point redemption at POS
□ Tier upgrade triggers

ACCOUNTING / ERP:
□ Daily revenue posting
□ Inventory valuation (FIFO/AVCO/Standard)
□ AP/AR integration

ANALYTICS / BI:
□ Sales data feed
□ Inventory data feed
□ Customer behavior data

HARDWARE:
□ Barcode scanner (1D/2D)
□ Receipt printer (thermal)
□ Cash drawer
□ Customer display (pole display)
□ Scale (nếu sell by weight)
□ EDC terminal (card payment)
□ Camera / NVR (nếu cần anti-theft integration)
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-RETAIL-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-RETAIL-POS-001   → POS và giao dịch bán hàng
REQ-RETAIL-PAY-001   → Payment processing
REQ-RETAIL-STORE-001 → Store management và ca làm việc
REQ-RETAIL-INV-001   → Inventory management tại cửa hàng
REQ-RETAIL-RPT-001   → Reporting và analytics
REQ-RETAIL-LOY-001   → Loyalty và customer management
REQ-RETAIL-CHAIN-001 → Multi-store / chain management
REQ-RETAIL-FRAN-001  → Franchise management
REQ-RETAIL-OMNI-001  → Omnichannel integration
REQ-RETAIL-HW-001    → Hardware integration
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/retail-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope retail)
2. Mô hình vận hành và quy mô (store count, SKU, transaction volume)
3. Personas affected (bảng tóm tắt)
4. Payment methods cần support (list kèm offline mode requirements)
5. Requirements (theo module, có REQ-ID)
6. Integration requirements với các hệ thống khác
7. Hardware requirements
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-RETAIL-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Offline mode requirements đã được cover (REQ-RETAIL-POS hoặc REQ-RETAIL-PAY)
□ Payment methods phù hợp thị trường đã liệt kê
□ Split payment và partial loyalty redemption đã address
□ Cash reconciliation requirements đã included
□ Hardware integration requirements đã noted
□ Open questions được list ra để stakeholders review
□ Franchise fee / royalty requirements đã address (nếu franchise model)
```
