# Procurement - Control Requirements

> **Domain**: Procurement / Internal Controls & Authorization
> **Last Updated**: 2026-03-15
> **Nguồn**: COSO Internal Control Framework, SOX procurement controls, ISO 20400 Sustainable Procurement

---

## 1. Authorization Matrix — Procurement Operations

| Hoạt Động | Requester | Dept Manager | Procurement Officer | Procurement Manager | Finance Director | CFO/CEO |
|-----------|-----------|-------------|--------------------|--------------------|-----------------|---------|
| Tạo Purchase Requisition (PR) | Tạo | — | — | — | — | — |
| Approve PR (< $1,000) | — | Auto-approve | — | — | — | — |
| Approve PR ($1,000–$10,000) | — | Approve | — | — | — | — |
| Approve PR ($10,001–$50,000) | — | Recommend | Approve | — | — | — |
| Approve PR ($50,001–$200,000) | — | Recommend | Recommend | Approve | — | — |
| Approve PR (> $200,000) | — | Recommend | Recommend | Recommend | Approve | CFO |
| Tạo Purchase Order (PO) | — | — | Tạo | Review | — | — |
| Approve PO (< $5,000) | — | — | Auto | — | — | — |
| Approve PO ($5,001–$50,000) | — | — | Approve | — | — | — |
| Approve PO ($50,001–$200,000) | — | — | Recommend | Approve | — | — |
| Approve PO (> $200,000) | — | — | Recommend | Recommend | Approve | CEO (>$500K) |
| Vendor Onboarding | — | — | Initiate | Approve | Finance review | — |
| Contract Signing (< $50K/năm) | — | — | — | Approve | — | — |
| Contract Signing (> $50K/năm) | — | — | — | Recommend | Approve | CEO (>$500K) |
| Vendor Blacklist / Remove | — | — | Propose | Approve | Thông báo | — |

---

## 2. Approval Limits Detail

### Purchase Requisition Thresholds

```
< $1,000       → Auto-approve by system (nếu trong budget)
$1,001–$10,000  → Department Manager (1 business day)
$10,001–$50,000 → Dept. Manager + Procurement Officer (2 business days)
$50,001–$200K  → + Procurement Manager (3 business days)
> $200,000     → + Finance Director + CFO (5 business days)
Capital Expense → Separate CapEx approval process regardless of amount
```

### Điều Kiện Phá Vỡ Threshold Thông Thường

| Tình Huống | Yêu Cầu Thêm |
|-----------|-------------|
| Sole-source (chỉ có 1 vendor) | Procurement Manager + Dept. VP sign-off |
| Emergency purchase | Procurement Manager retroactive approval trong 24h |
| Vendor chưa đăng ký trong system | Không được tạo PO; phải onboard vendor trước |
| Mua ngoài danh mục đã phê duyệt | Category Manager review trước khi tạo PR |
| Hợp đồng có điều khoản bất thường | Legal review bắt buộc |

---

## 3. Vendor Onboarding Controls

### Quy Trình Onboarding

```
┌─────────────────────────────────────────────────────────────┐
│               VENDOR ONBOARDING WORKFLOW                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Vendor Application]                                       │
│   - Business registration                                   │
│   - Tax certificates                                        │
│   - Bank account verification                               │
│   - References (2–3 existing clients)                       │
│        │                                                    │
│        ▼                                                    │
│  [Procurement: Document Review] (2 ngày)                   │
│   - Completeness check                                      │
│   - Sanctions list screening (OFAC, UN)                     │
│        │                                                    │
│        ▼                                                    │
│  [Finance: Credit & Financial Check] (1 ngày)              │
│   - Creditworthiness assessment                             │
│   - Bank account validation                                 │
│   - Payment terms negotiation                               │
│        │                                                    │
│        ▼                                                    │
│  [Procurement Manager: Final Approval]                     │
│        │                                                    │
│   APPROVE ▼          REJECT ▼                              │
│  [Activate in system]  [Notify với reason]                  │
│  [Send Welcome Kit]                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Vendor Offboarding Checklist

- [ ] Tất cả PO đang mở đã được close hoặc transfer
- [ ] Invoice tồn đọng đã được settle
- [ ] Contracts đã được terminate đúng thủ tục
- [ ] Deposits hoặc advance payments đã được thu hồi
- [ ] System access (nếu có) đã bị revoke
- [ ] Blacklist reason được ghi rõ (với evidence)

---

## 4. Three-Way Matching Process

```
┌─────────────────────────────────────────────────────────────┐
│              THREE-WAY MATCHING WORKFLOW                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Document 1: Purchase Order (PO)                            │
│    ← Mua gì, số lượng bao nhiêu, giá bao nhiêu              │
│                                                             │
│  Document 2: Goods Receipt Note (GRN)                       │
│    ← Nhận thực tế: số lượng, chất lượng, ngày nhận          │
│                                                             │
│  Document 3: Vendor Invoice                                  │
│    ← Vendor yêu cầu thanh toán                              │
│                                                             │
│  MATCHING LOGIC:                                            │
│  PO Qty ≈ GRN Qty ≈ Invoice Qty?  → MATCH → Approve payment │
│  Price PO = Invoice Price?         → MATCH → Approve payment │
│  Variance within tolerance?        → MATCH (flag for review) │
│  Significant variance?             → HOLD → Finance review   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Tolerance Matrix cho Three-Way Match

| Loại Sai Lệch | Tolerance | Hành Động |
|--------------|-----------|-----------|
| Quantity variance | ± 2% | Auto-approve; ghi nhận variance |
| Price variance | ± 1% | Auto-approve; ghi nhận |
| Quantity variance 2–5% | — | Finance review |
| Price variance 1–5% | — | Procurement review |
| Variance > 5% | — | Full investigation; hold payment |
| Invoice không có PO | — | Reject; yêu cầu tạo PO trước |

---

## 5. Segregation of Duties Matrix

| Chức Năng | Requester | Procurement | Warehouse | Finance | Accounts Payable |
|-----------|-----------|------------|-----------|---------|-----------------|
| Tạo PR | YES | NO | NO | NO | NO |
| Approve PR | NO | YES | NO | YES (>$50K) | NO |
| Tạo PO | NO | YES | NO | NO | NO |
| Nhận hàng (GRN) | NO | NO | YES | NO | NO |
| Nhập invoice | NO | NO | NO | NO | YES |
| Approve payment | NO | NO | NO | YES | NO |
| Thực hiện payment | NO | NO | NO | NO | YES (với dual control) |

**Nguyên tắc:** Không một người nào được làm hơn 2 bước trong cùng một transaction. Requester không được approve PO. Warehouse không được create PO.

---

## 6. Emergency Procurement Procedures

### Điều Kiện Áp Dụng Emergency Purchase

- Hệ thống sản xuất/vận hành bị ngừng do thiếu vật tư/dịch vụ
- Ảnh hưởng trực tiếp đến giao hàng cho khách hàng
- Thảm họa tự nhiên hoặc sự kiện force majeure

### Quy Trình

```
[Xác nhận tình huống khẩn cấp] ← Dept. Manager
        │
        ▼
[Verbal approval từ Procurement Manager] ← Trong vòng 1 giờ
        │
        ▼
[Thực hiện mua hàng] ← Procurement Officer
        │
        ▼
[Tạo PR + PO trong system TRONG NGÀY] ← Bắt buộc
        │
        ▼
[Retroactive approval trong 24 giờ] ← Procurement Manager chính thức
        │
        ▼
[Post-event review] ← Trong vòng 1 tuần
   - Tại sao xảy ra?
   - Có thể phòng tránh không?
   - Action items để ngăn tái phát
```

**Giới Hạn Emergency:** Không được dùng emergency process thường xuyên. Hơn 3 lần/quý từ cùng một phòng ban → trigger audit.

---

## 7. Vendor Performance Scorecard

### Tiêu Chí Đánh Giá (Đánh Giá Hàng Quý)

| Tiêu Chí | Trọng Số | Điểm Tối Đa | Cách Đo |
|----------|----------|------------|---------|
| Giao hàng đúng hạn (OTD) | 30% | 30 | On-time deliveries / Total deliveries |
| Chất lượng (Quality Pass Rate) | 25% | 25 | Accepted qty / Total received qty |
| Giá cả cạnh tranh | 20% | 20 | So sánh với market benchmark |
| Dịch vụ & phản hồi | 15% | 15 | Resolution time, responsiveness |
| Tuân thủ hợp đồng | 10% | 10 | Document compliance, payment terms |

### Phân Loại Vendor

| Tổng Điểm | Phân Loại | Hành Động |
|-----------|----------|-----------|
| 85–100 | Preferred Vendor | Ưu tiên trong RFQ; có thể tăng share of wallet |
| 70–84 | Approved Vendor | Hoạt động bình thường |
| 55–69 | Probation | Improvement plan 90 ngày; hạn chế PO mới |
| < 55 | At Risk | Review committee; có thể chấm dứt hợp đồng |
