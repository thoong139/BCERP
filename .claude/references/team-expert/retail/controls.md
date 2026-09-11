# Retail - Control Requirements

> **Domain**: Retail / Internal Controls & Authorization
> **Last Updated**: 2026-03-15
> **Nguồn**: NRF (National Retail Federation) guidelines, PCI-DSS standards, retail audit best practices

---

## 1. Authorization Matrix — Retail Operations

| Hoạt Động | Cashier | Senior Cashier | Store Supervisor | Store Manager | Area Manager | Head Office |
|-----------|---------|---------------|-----------------|--------------|-------------|-------------|
| Bán hàng thông thường | YES | YES | YES | YES | — | — |
| Áp dụng discount có sẵn (catalog) | YES | YES | YES | YES | — | — |
| Discount ngoài catalog (< 5%) | Không | YES | YES | YES | — | — |
| Discount ngoài catalog (5–15%) | Không | Không | YES | YES | — | — |
| Discount ngoài catalog (> 15%) | Không | Không | Không | YES | Approve | — |
| Void transaction (trong ca) | Không | YES | YES | YES | — | — |
| Void transaction (sau ca đóng) | Không | Không | Không | YES | — | — |
| Refund tiền mặt (< $50) | Không | YES | YES | YES | — | — |
| Refund tiền mặt ($50–$200) | Không | Không | YES | YES | — | — |
| Refund tiền mặt (> $200) | Không | Không | Không | YES | Thông báo | — |
| Thay đổi giá tại POS | Không | Không | Không | YES | — | HO set giá |
| Điều chỉnh tồn kho (Inventory Adj.) | Không | Không | Không | YES (< $500) | YES ($500–$2K) | >$2K |
| Xóa/Override member points | Không | Không | Không | YES | — | — |
| POS system admin | Không | Không | Không | Không | Không | IT HO |

---

## 2. Cash Handling Controls

### Quy Trình Mở Ca (Opening Procedures)

```
[Ca trước kết thúc] → [Đếm tiền két] → [Ghi nhận số tiền]
        │
        ▼
[Ca mới bắt đầu]
        │
        ▼
[Cashier nhận float tiền mặt] (số tiền cố định: VD $200)
        │
        ▼
[Cashier ký nhận] ← Bắt buộc có chữ ký
        │
        ▼
[Nhập float amount vào POS] ← Mở ca chính thức
```

### Cash Drawer Controls

| Control | Mô Tả | Tần Suất |
|---------|-------|---------|
| Cash drop | Khi drawer > limit ($500), cashier drop tiền vào két nhỏ | Liên tục trong ca |
| Blind cash count | Supervisor đếm tiền mà không xem POS total trước | Mỗi ca |
| Cash reconciliation | So sánh physical cash với POS system total | Mỗi ca |
| Variance log | Ghi nhận mọi variance; > $10 phải giải thích | Mỗi ca |
| Safe count | 2 người cùng đếm két lớn | Hàng ngày |

### Tolerance Policy

| Variance | Hành Động | Escalation |
|---------|-----------|-----------|
| < $5 (over or short) | Ghi nhận; không cần giải trình | Không |
| $5–$20 | Ghi nhận; cashier điền explanation form | Store Manager |
| > $20 | Điều tra ngay; review CCTV | Store Manager + Area Manager |
| > $100 | Điều tra formal; tạm giữ hồ sơ | Area Manager + Loss Prevention |
| Recurring short (≥3 lần/tháng) | PIP (Performance Improvement Plan) | HR notification |

---

## 3. Inventory Adjustment Authorization

### Adjustment Types và Approval

| Loại Adjustment | Giá Trị | Approval | Reason Code Bắt Buộc |
|----------------|---------|----------|----------------------|
| Shrinkage (confirmed theft) | Bất kỳ | Store Manager | YES — với incident report |
| Cycle count variance (< $100) | < $100 | Store Manager | YES — variance explanation |
| Cycle count variance ($100–$500) | $100–$500 | Store Manager + email HO | YES |
| Write-off (damaged, expired) | < $500 | Store Manager | YES — photo evidence |
| Write-off ($500–$2,000) | $500–$2,000 | Area Manager | YES — photo + investigation |
| Write-off (> $2,000) | > $2,000 | HO Operations | YES — full report |
| Transfer In/Out | Bất kỳ | Store Manager (cả hai bên) | YES — transfer order number |

### Inventory Count Controls

- Cycle count phải được thực hiện bởi người không phải người quản lý khu vực đó
- Supervisor phải recount bất kỳ discrepancy > $50
- Annual full count: ngoài giờ hoặc sau giờ đóng cửa; 2 teams cross-count
- Kết quả count phải được submit trong vòng 24 giờ

---

## 4. Store Opening / Closing Procedures

### Opening Checklist

| Bước | Người Thực Hiện | Control |
|------|----------------|---------|
| 1. Mở cửa hàng với 2 người trở lên | Supervisor + 1 staff | Dual custody |
| 2. Kiểm tra an ninh, báo động | Supervisor | Security log |
| 3. Kiểm tra khu vực backroom, fitting room | Supervisor | Safety walk |
| 4. Cash float setup tại từng POS | Cashier + Supervisor | Float sheet signed |
| 5. POS system online và test | Cashier | System check log |
| 6. Kiểm tra hàng hóa, price tags | Floor Staff | Exception report |
| 7. Mở cửa cho khách | Store Manager | Sign off opening |

### Closing Checklist

| Bước | Người Thực Hiện | Control |
|------|----------------|---------|
| 1. Last customer out; lock front door | Supervisor | Time recorded |
| 2. Blind cash count tại từng POS | Cashier (không thấy POS total) | Count sheet |
| 3. Z-report print từ POS | Cashier | Hard copy + digital |
| 4. Reconcile cash vs Z-report | Supervisor | Variance log |
| 5. Cash drop vào két | 2 người | Dual custody; CCTV |
| 6. Daily sales report submit | Store Manager | Email to HO |
| 7. Alarm set + door locked | Last 2 staff | Security log |

---

## 5. Loss Prevention Controls

### High-Risk Transaction Monitoring

| Transaction | Dấu Hiệu Cảnh Báo | Hành Động |
|-------------|------------------|-----------|
| Refund không có receipt | Khách không có hóa đơn gốc | Yêu cầu ID; Store Manager approve |
| Nhiều void liên tiếp (> 3/ca) | Possible internal fraud | Supervisor alert; review CCTV |
| Transaction > $1,000 tiền mặt | Unusual amount | Manager override required; ID check |
| Refund amount = last purchase | Sweethearting pattern | Flag cho Loss Prevention |
| Employee discount sau giờ làm | Policy violation | HR notification |

### Exception Report — Triggers Tự Động

```
Exception Reports chạy hàng ngày và gửi cho Store Manager + Area Manager:

  ✓ Voids > $50
  ✓ Price overrides
  ✓ Discounts > 20%
  ✓ Refunds không có receipt
  ✓ Cash variance > $20
  ✓ No-sale transactions (mở drawer không bán hàng) > 3 lần/ca
  ✓ Transactions trong vòng 5 phút trước và sau ca của nhân viên
  ✓ Manager card swipes (authorization uses)
```

---

## 6. Franchise Compliance Requirements

| Yêu Cầu | Tần Suất Kiểm Tra | Người Thực Hiện | Non-Compliance Action |
|---------|------------------|----------------|----------------------|
| Store layout theo planogram HO | Hàng tháng | Area Manager | 30 ngày để sửa |
| Giá bán đúng theo HO price list | Hàng tuần (mystery shopper) | HO mystery shopper | Immediate correction |
| Đồng phục nhân viên | Mỗi lần visit | Area Manager | Warning → Fine |
| Vệ sinh an toàn thực phẩm (F&B) | Hàng tháng | Health inspector | Có thể đóng cửa |
| Báo cáo tài chính đúng hạn | Hàng tháng | Franchisee | Penalty clause |
| Sử dụng supplier được phê duyệt | Quarterly audit | HO Procurement | Contract violation |

---

## 7. POS System Access Controls

| Role | Quyền Truy Cập POS | Tạo Bởi | Review Tần Suất |
|------|------------------|---------|----------------|
| Cashier | Basic sale, payment, receipt | Store Manager | Hàng quý |
| Senior Cashier | + Void, small refund, basic discount | Store Manager | Hàng quý |
| Supervisor | + All refunds, void after close, inventory lookup | Area Manager | Hàng quý |
| Store Manager | Full access | HO IT | Hàng năm |
| Trainer (temp) | Read-only + training mode | HO IT | 30 ngày; auto-expire |

### POS Security Policies

- Mỗi nhân viên có PIN riêng; không được share
- PIN phải đổi mỗi 90 ngày
- Nhân viên nghỉ việc: revoke access trong vòng 2 giờ sau khi nhận thông báo
- Inactive session tự động logout sau 3 phút
- Failed login 5 lần → tự động lock; Manager phải unlock
- Mọi Manager override phải có Manager PIN riêng biệt
