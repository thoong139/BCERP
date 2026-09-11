# E-commerce - Controls & Access Management

> **Domain**: E-commerce / Thương mại điện tử
> **Last Updated**: 2026-03-19

---

## 1. Approval Matrix

### Price Change Approval (by % deviation from base price)

| Thay đổi giá | Content Manager | Category Manager | Director | VP / C-Level |
|--------------|:--------------:|:----------------:|:--------:|:------------:|
| <5% | ✅ Auto-approve | ✅ | ✅ | ✅ |
| 5–15% | ❌ | ✅ | ✅ | ✅ |
| 15–30% | ❌ | ❌ | ✅ | ✅ |
| >30% | ❌ | ❌ | ❌ | ✅ |
| Flash sale (≤24h, any %) | ❌ | ✅ (với notification Director) | ✅ | ✅ |

### Promotion Launch Approval

| Loại Promotion | Marketing Lead | Category Manager | Director |
|----------------|:--------------:|:----------------:|:--------:|
| Coupon code (<10% discount, capped volume) | ✅ | ✅ | ❌ required |
| Sitewide sale (<15% off) | ❌ | ✅ | ✅ |
| Free shipping campaign | ❌ | ✅ (nếu margin đủ) | ✅ |
| Bundle / BOGO deal | ❌ | ✅ | ✅ |
| Flash sale >15% off | ❌ | ❌ | ✅ |
| Platform-wide event (11.11, 12.12) | ❌ | ❌ | ✅ |

### Refund & Compensation Approval

| Giá trị hoàn tiền | CS Agent | CS Lead | Ops Manager | Director |
|-------------------|:--------:|:-------:|:-----------:|:--------:|
| ≤500,000 VND | ✅ | ✅ | ✅ | ✅ |
| 500K–2,000,000 VND | ❌ | ✅ | ✅ | ✅ |
| 2M–10,000,000 VND | ❌ | ❌ | ✅ | ✅ |
| >10,000,000 VND | ❌ | ❌ | ❌ | ✅ |
| Refund ngoài chính sách | ❌ | ❌ | ✅ (exception log) | ✅ |

### Product Publish Approval

| Sản phẩm | Content Manager | Category Manager | Legal / Compliance |
|----------|:--------------:|:----------------:|:-----------------:|
| Standard product | ✅ (self-approve) | ✅ | ❌ required |
| New category hoặc brand | ❌ | ✅ | ❌ required |
| Sản phẩm nhập khẩu có CO/CQ | ❌ | ✅ | ✅ required |
| Thực phẩm chức năng / mỹ phẩm | ❌ | ❌ | ✅ required |
| Hàng second-hand / refurbished | ❌ | ✅ | ✅ required |

---

## 2. Access Control

### Product Catalog Access Matrix

| Chức năng | CS Agent | Content Mgr | Category Mgr | Ops Manager | Director |
|-----------|:--------:|:-----------:|:------------:|:-----------:|:--------:|
| Xem sản phẩm (tất cả) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tạo / sửa nội dung sản phẩm | ❌ | ✅ | ✅ | ✅ | ✅ |
| Sửa giá | ❌ | ⚠ (<5%) | ✅ | ✅ | ✅ |
| Publish sản phẩm | ❌ | ✅ | ✅ | ✅ | ✅ |
| Archive / xóa sản phẩm | ❌ | ❌ | ✅ | ✅ | ✅ |
| Sửa category / taxonomy | ❌ | ❌ | ✅ | ❌ | ✅ |

### Order Management Access Matrix

| Chức năng | CS Agent | CS Lead | Ops Manager | Finance | Director |
|-----------|:--------:|:-------:|:-----------:|:-------:|:--------:|
| Xem đơn hàng (tất cả) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cập nhật trạng thái đơn | ⚠ (comment only) | ✅ | ✅ | ❌ | ✅ |
| Hủy đơn hàng | ❌ | ✅ (<2M) | ✅ | ❌ | ✅ |
| Hoàn tiền | ⚠ (≤500K) | ✅ (≤2M) | ✅ (≤10M) | ✅ | ✅ |
| Sửa địa chỉ giao hàng | ✅ (trước khi pick) | ✅ | ✅ | ❌ | ✅ |
| Export danh sách đơn hàng | ❌ | ✅ | ✅ | ✅ | ✅ |

### Customer PII Access

| Dữ liệu | CS Agent | CS Lead | Ops Manager | Marketing | IT Admin |
|---------|:--------:|:-------:|:-----------:|:---------:|:--------:|
| Tên, email (masked) | ✅ | ✅ | ✅ | ❌ | ✅ |
| Số điện thoại (masked) | ✅ | ✅ | ✅ | ❌ | ✅ |
| Địa chỉ giao hàng | ✅ (cho đơn cụ thể) | ✅ | ✅ | ❌ | ✅ |
| Lịch sử mua hàng | ✅ | ✅ | ✅ | ⚠ (aggregated) | ✅ |
| Payment method (last 4 digits) | ✅ | ✅ | ❌ | ❌ | ✅ |
| Raw card data | ❌ | ❌ | ❌ | ❌ | ❌ |

> Raw card data không được lưu trữ trong hệ thống (PCI-DSS requirement). Mọi payment data sử dụng tokenization qua payment gateway.

### Pricing & Financial Data Access

| Dữ liệu | Content Mgr | Category Mgr | Ops Manager | Finance | Director |
|---------|:-----------:|:------------:|:-----------:|:-------:|:--------:|
| Giá bán (retail) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Giá vốn (COGS) | ❌ | ✅ | ✅ | ✅ | ✅ |
| Margin theo sản phẩm | ❌ | ✅ | ✅ | ✅ | ✅ |
| Doanh thu tổng | ❌ | ❌ | ✅ | ✅ | ✅ |
| Chi phí vận hành | ❌ | ❌ | ✅ | ✅ | ✅ |

---

## 3. Workflow Controls

### Product State Transitions

| Từ trạng thái | Đến trạng thái | Điều kiện | Validation |
|---------------|----------------|-----------|------------|
| Draft | In Review | Tất cả required fields filled | Completeness check ≥80% |
| In Review | Active | Category Manager approve | Images ≥1, price set, stock allocated |
| Active | Inactive | Manual by Category Manager | Không có đơn hàng đang xử lý |
| Active | Out of Stock | Stock = 0 | System auto-update |
| Out of Stock | Active | Stock > 0 restocked | System auto-update |
| Inactive | Active | Reactivate by Category Manager | Price review required |
| Any | Archived | Category Manager hoặc Ops Manager | Stock = 0, no pending orders |

### Order State Machine

```
Pending Payment → Payment Confirmed → Processing → Shipped → Delivered → Closed
       │                 │                │             │           │
       ▼                 ▼                ▼             ▼           ▼
  Payment          Inventory         Pick & Pack    Carrier     Auto-close
  Timeout          Allocated         Completed      Tracking    T+7 days
  → Cancelled      → Confirmed       → Label        POD         post-delivery
                                      Printed
```

| Từ trạng thái | Đến trạng thái | Người thực hiện | Validation |
|---------------|----------------|-----------------|------------|
| Pending | Confirmed | Payment gateway webhook | Payment reference verified |
| Pending | Cancelled | System (timeout 30 min) | No payment confirmed |
| Confirmed | Processing | Warehouse / OMS | Inventory allocated |
| Processing | Shipped | Warehouse / Carrier | Tracking number assigned |
| Shipped | Delivered | Carrier webhook / Customer | POD captured |
| Delivered | Closed | System auto | T+7 days, no open dispute |
| Any (trước Shipped) | Cancelled | CS Lead / Ops Manager | Refund triggered |
| Delivered | Returned | CS Agent / Customer portal | Return request approved |

### Return State Machine

| Từ trạng thái | Đến trạng thái | Điều kiện |
|---------------|----------------|-----------|
| Requested | Approved | Trong return window, đúng policy |
| Requested | Rejected | Ngoài window, excluded category |
| Approved | In Transit | Pickup scheduled / drop-off confirmed |
| In Transit | Received | Warehouse scan receipt |
| Received | Inspected | Grade assigned (A/B/C/D) |
| Inspected | Refunded | Refund to original payment method |
| Inspected | Replaced | Replacement order created |
| Inspected | Rejected | Grade D — damage claim filed |

### Hygiene Controls

| Control | Frequency | Enforcement |
|---------|-----------|-------------|
| Products với stock < reorder point | Daily | System alert → Ops Manager |
| Đơn hàng ở trạng thái Processing >24h | Daily | Alert → Warehouse Manager |
| Coupon code sắp hết hạn (48h) | Daily | Alert → Marketing |
| Sản phẩm không có ảnh | Weekly | Catalog audit report |
| Giá thấp hơn giá vốn (negative margin) | Realtime | Block publish, alert Category Manager |
| Đơn hàng có refund >3 lần cùng customer | Per transaction | Fraud flag → CS Lead review |

---

## 4. Audit Trail Requirements

### Events to Log

| Event | Data Captured | Retention |
|-------|---------------|-----------|
| Thay đổi giá sản phẩm | user_id, product_id, old_price, new_price, timestamp, reason | 5 năm |
| Publish / unpublish sản phẩm | user_id, product_id, action, timestamp | 3 năm |
| Tạo / sửa promotion / coupon | user_id, promo_id, rules, discount%, validity, timestamp | 5 năm |
| Order status change | user_id, order_id, old_status, new_status, reason, timestamp | 7 năm |
| Refund approved | approver_id, order_id, amount, method, reason, timestamp | 7 năm |
| Hoàn tiền thực hiện | system, order_id, gateway_ref, amount, timestamp | 7 năm |
| Inventory adjustment (manual) | user_id, sku, old_qty, new_qty, reason, timestamp | 3 năm |
| Customer PII access | user_id, customer_id, data_accessed, purpose, timestamp | 3 năm |
| Payment webhook received | gateway, order_id, status, amount, signature_valid, timestamp | 7 năm |
| Export dữ liệu khách hàng | user_id, export_scope, record_count, timestamp | 3 năm |

### Sensitive Data Access Log

| Dữ liệu | Người có thể truy cập | Mục đích ghi log |
|---------|----------------------|-----------------|
| Customer phone (unmasked) | CS Lead, Ops Manager | Xử lý đơn hàng tranh chấp |
| Payment token | System only | Refund processing |
| Order financial summary | Finance, Director | Revenue reporting |
| COGS / margin data | Category Manager, Finance, Director | Pricing decisions |
| Bulk customer export | IT Admin, Director | GDPR/data request compliance |

### E-invoice Compliance Trail

| Yêu cầu | Standard | Retention |
|---------|----------|-----------|
| Hóa đơn điện tử mỗi giao dịch thành công | Nghị định 123/2020/NĐ-CP | 10 năm |
| Serial hóa đơn liên tục | Không được có khoảng trống | 10 năm |
| Trạng thái hóa đơn (issued / cancelled / replaced) | Log mọi thay đổi | 10 năm |

---

## Quick Reference: Approval Checklist

### Trước khi launch Flash Sale
- [ ] Discount % đã được Director approve
- [ ] Margin check: không có SKU nào negative margin
- [ ] Coupon volume cap đã thiết lập
- [ ] Inventory đủ cho dự kiến demand
- [ ] E-invoice template đã cấu hình đúng VAT rate

### Trước khi publish sản phẩm mới
- [ ] Ảnh sản phẩm ≥1 (main) đã upload
- [ ] Giá bán đã set (bao gồm VAT)
- [ ] Category đã assign đúng taxonomy
- [ ] SKU không trùng lặp trong hệ thống
- [ ] Với hàng nhập khẩu: CO/CQ và chứng từ đã được Legal verify

### Trước khi xử lý refund >2,000,000 VND
- [ ] Order history đã review
- [ ] Return package đã nhận và inspected
- [ ] Approval từ Ops Manager / Director đã ghi nhận
- [ ] Refund thực hiện về đúng phương thức thanh toán gốc
