# Manufacturing - Control Requirements

> **Domain**: Manufacturing / Internal Controls & Authorization
> **Last Updated**: 2026-03-15
> **Nguồn**: ISO 9001:2015, GMP guidelines, ERP internal control best practices, SOX compliance frameworks

---

## 1. Authorization Matrix — Manufacturing Operations

| Hoạt Động | Operator | Supervisor | Production Manager | Plant Manager | QA Manager |
|-----------|----------|------------|-------------------|---------------|------------|
| Tạo Work Order (WO) | Không | Tạo | Approve | Approve (>$10K) | — |
| Chỉnh sửa WO đã Release | Không | Không | Approve | Approve | — |
| Hủy WO đang In Progress | Không | Không | Approve | Approve | Thông báo |
| BOM Changes (Engineer) | Không | Không | Không | Approve | Review |
| BOM Changes (Emergency) | Không | Không | Không | Approve + sign | Mandatory review |
| Quality Hold (HOLD status) | Flag only | Initiate | Notified | Notified | **Full authority** |
| Release from HOLD | Không | Không | Không | Không | **Full authority** |
| Scrap Authorization | Ghi nhận | Propose | Approve (<$500) | Approve ($500–$5K) | Sign-off |
| Scrap >$5K | — | — | Không | Approve | Sign-off + CFO |
| Production plan changes | Không | Thông báo | Minor adjustments | Major adjustments | — |

---

## 2. Quality Control Gates

### 2.1 IQC — Incoming Quality Control (Kiểm tra đầu vào)

```
┌─────────────────────────────────────────────────────────┐
│                    IQC WORKFLOW                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Vendor Delivery]                                      │
│        │                                                │
│        ▼                                                │
│  [Receiving Dock Checks]                                │
│    - Đối chiếu PO vs GRN (số lượng, SKU)               │
│    - Kiểm tra bao bì, nhãn mác                         │
│        │                                                │
│        ▼                                                │
│  [QC Sampling] (theo AQL standard)                     │
│        │                                                │
│   PASS ▼              FAIL ▼                           │
│  [Accept to Stock]  [Reject / Hold]                     │
│        │                  │                             │
│        │             [QA Review]                        │
│        │                  │                             │
│        │         Use-As-Is │ Rework │ Return to Vendor  │
│        │                  │                             │
│  [Lot ID Assigned]   [Non-Conformance Report]          │
│  [Inventory Updated] [Vendor Notification]              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.2 IPQC — In-Process Quality Control (Kiểm tra trong quá trình)

| Checkpoint | Thời Điểm | Người Thực Hiện | Tần Suất Sampling | Record |
|-----------|-----------|----------------|------------------|--------|
| Setup verification | Trước khi bắt đầu sản xuất | Operator + QC | 100% first piece | Setup sheet |
| Dimensional check | Mỗi giờ hoặc theo trigger | QC Inspector | AQL sampling | Control chart |
| Visual inspection | Liên tục | Operator | 100% | Defect log |
| Critical parameter check | Mỗi batch | QC Inspector | 100% | Batch record |

### 2.3 OQC — Outgoing Quality Control (Kiểm tra đầu ra)

| Hàng | Sampling Level | Tiêu Chí Chấp Nhận | Khi Fail |
|------|--------------|---------------------|---------|
| Standard product | AQL 2.5 | Zero major defects | Hold + investigation |
| Export / high-value | AQL 1.0 | Zero major defects | Full 100% inspection |
| Custom order | 100% | Per customer spec | Customer notification |

---

## 3. Production Workflow — Approval Levels

```
[MRP Planned Order]
       │
       ▼
[Work Order Created] ← Supervisor creates
       │
       ▼
[WO Review & Release] ← Production Manager approves
       │
       ▼
[Material Reservation] ← Auto từ system (FIFO enforced)
       │
       ▼
[Production Execution] ← Operator records actual
       │
       ▼
[QC Inspection (IPQC)] ← QC Inspector
       │
   PASS ▼      FAIL ▼
[Complete WO]  [QA Hold → NCR Process]
       │
       ▼
[Goods Receipt to FG Inventory] ← System auto sau QC pass
       │
       ▼
[WO Close & Variance Report] ← Production Manager reviews
```

---

## 4. Material Handling Controls

### FIFO Enforcement

| Quy Tắc | Cơ Chế Thực Hiện | Kiểm Soát |
|---------|-----------------|----------|
| FIFO bắt buộc cho mọi vật tư có expiry | System chỉ cho pick lot cũ nhất | Audit trail per pick |
| Lot traceability từ Vendor đến WO | Lot ID gắn vào mọi transaction | Lot history report |
| Không dùng vật tư hết hạn | System block nếu expiry < today | Alert 30 ngày trước expiry |
| Material substitution | Phải có Engineering Change Notice | QA sign-off bắt buộc |

### Kho và Phân Khu

| Khu | Loại Vật Tư | Truy Cập | Điều Kiện |
|-----|------------|----------|----------|
| Raw Material Store | Nguyên vật liệu đầu vào | Warehouse staff + QC | Standard conditions |
| Quarantine Area | IQC fail, expired | QA Manager only | Locked; labeled clearly |
| WIP Area | Hàng đang sản xuất | Production staff | Per WO assignment |
| FG Store | Thành phẩm đã QC pass | Warehouse + Shipping | Access log required |
| Return Area | Hàng trả về | QA + Warehouse | Separate from FG |

---

## 5. Equipment Maintenance Authorization

| Loại Bảo Trì | Người Thực Hiện | Approval | Downtime Notification |
|-------------|----------------|----------|----------------------|
| Autonomous (daily check) | Operator | Không cần | Không cần |
| Preventive (scheduled) | Maintenance Tech | Supervisor | Thông báo 24h trước |
| Corrective (unplanned) | Maintenance Tech | Supervisor immediate | Ngay lập tức |
| Major overhaul | External + internal | Plant Manager + Finance | Lên kế hoạch 2 tuần trước |
| Emergency repair | Bất kỳ Technician available | Supervisor (retroactive) | Ngay lập tức lên hệ thống |

---

## 6. Non-Conformance Handling Process

```
[Defect Detected]  ← Bất kỳ ai có thể báo cáo
        │
        ▼
[Create NCR (Non-Conformance Report)]  ← QC Inspector
   - Mô tả defect
   - Lot/WO number
   - Quantity affected
   - Photo evidence
        │
        ▼
[Containment Action]  ← QA Manager (within 2 hours)
   - Quarantine affected material
   - Check if defect escaped to customer
        │
        ▼
[Root Cause Analysis (RCA)]  ← QA + Production (within 24–48h)
   - 5 Whys or Fishbone Diagram
        │
        ▼
[Corrective Action Plan]  ← QA Manager approves
   - Short-term fix
   - Long-term prevention
        │
        ▼
[Verification]  ← QA Manager (after implementation)
   - Confirm corrective action effective
   - Close NCR
```

---

## 7. Audit Trail Requirements

| Transaction | Phải Ghi Lại | Retention |
|-------------|-------------|-----------|
| WO creation/change | User ID, timestamp, before/after values | 5 năm |
| Material pick | User, lot, quantity, location, WO | 5 năm |
| QC inspection result | Inspector ID, timestamp, result, sample size | 7 năm |
| NCR creation/close | Creator, QA approver, timestamps | 7 năm |
| BOM change | Requester, approver, effective date | 10 năm |
| Equipment calibration | Tech, date, result, next due | 7 năm |
| Scrap authorization | Approver, reason, quantity, value | 5 năm |

**Nguyên tắc audit trail:**
- Không cho phép xóa records; chỉ void/reverse với reason code
- Mọi thay đổi phải hiển thị: ai thay đổi, khi nào, giá trị trước và sau
- Export audit log phải có digital signature hoặc hash verification
