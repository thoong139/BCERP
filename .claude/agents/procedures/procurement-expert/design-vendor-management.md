# Playbook: Design Vendor Management Module

> **Type**: Agent Skill Playbook
> **Agent**: procurement-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design vendor/supplier module
> **Output**: Feature spec cho Vendor Management module

---

## Khi nào dùng playbook này

- Khi cần spec module "Vendor Management" / "Quản lý Nhà cung cấp" / "Supplier Management"
- Khi cần thiết kế vendor onboarding, AVL (Approved Vendor List), scorecard
- Khi review/audit hệ thống vendor management hiện có

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ context:
□ Số lượng vendor dự kiến (< 100 / 100–1,000 / > 1,000)?
□ Có cần Vendor Self-Service Portal không?
□ Vendor categorization level: Chỉ Preferred/Approved hay cần Critical/Strategic tier?
□ Performance scoring: Có cần automated scorecard không hay manual evaluation?
□ Contract linkage: Có cần gắn contract với vendor profile không?
□ Sanctions screening: Có cần OFAC/UN screening tự động không?
□ Conflict of interest: Có cần declaration form trên portal không?
```

### Bước 2: Thiết kế Vendor Onboarding Workflow

```
READ: processes.md → Vendor Onboarding (Process 3)
READ: controls.md → Vendor Onboarding Controls

Workflow states:
Draft → Submitted → Under Review → Financial Check → Approved → Active
                                                              ↘ Rejected

Steps:
1. Vendor self-register (hoặc Procurement initiate)
2. Vendor điền thông tin cơ bản + upload documents
3. Procurement review tính đầy đủ và xác minh thông tin
4. Finance review creditworthiness + bank account validation
5. Sanctions screening (OFAC, UN lists) — tự động hoặc manual
6. Procurement Manager approval cuối
7. System activate vendor + gửi Welcome Kit
8. Vendor nhận credentials truy cập Vendor Portal

Document collection checklist:
□ Business registration / Company certificate
□ Tax certificate / VAT registration
□ Bank account details (với bank verification letter)
□ Insurance certificates (liability, workers' comp — nếu applicable)
□ Quality certifications (ISO, GMP, v.v. — nếu applicable)
□ References: 2–3 khách hàng hiện tại
□ Conflict of Interest declaration (signed)
```

### Bước 3: Thiết kế Approved Vendor List (AVL)

```
READ: controls.md → Vendor Performance Scorecard

AVL là danh sách vendor được phép nhận PO.
Khi tạo PO → system chỉ cho chọn vendor có status = Active trong AVL.

Vendor classification tiers:
| Tier | Điều kiện | Ưu tiên trong RFQ |
|------|-----------|-------------------|
| Preferred | Score 85–100, strategic partner | First choice, có thể direct PO dưới threshold |
| Approved | Score 70–84, qualified | Normal RFQ participation |
| Probation | Score 55–69 | Hạn chế PO mới; cần improvement plan |
| Suspended | Score < 55 hoặc có incident | Blocked — không tạo PO mới được |
| Blacklisted | Vi phạm nghiêm trọng / fraud | Vĩnh viễn blocked; ghi nhận lý do |

Business rule:
- Tạo PO với Suspended vendor → system hard-block, yêu cầu override approval
- Tạo PO với Blacklisted vendor → system hard-block, không có override
```

### Bước 4: Thiết kế Vendor Categorization

```
Category dimensions:
1. Spend category: Raw material / MRO / IT / Professional services / Logistics / Utilities
2. Strategic importance: Strategic / Preferred / Transactional
3. Risk level: Critical (single source) / High / Medium / Low
4. Relationship type: Partnership / Approved / Spot buy only

Mapping:
Critical + Strategic → Quarterly review, dedicated relationship manager, joint roadmap
High risk + Preferred → Monthly KPI check, escalation SLA
Medium/Low + Transactional → Annual review, automated scoring

System cần:
□ Tag vendor theo spend category (nhiều category per vendor)
□ Calculate risk score từ: single-source flag, spend concentration, country risk
□ Alert khi single-source vendor score xuống dưới 70 (supply risk)
```

### Bước 5: Thiết kế Performance KPIs và Scorecard

```
READ: controls.md → Vendor Performance Scorecard
READ: processes.md → Vendor Evaluation

Scorecard structure:
| Tiêu chí | Trọng số | Data source |
|----------|----------|-------------|
| Giao hàng đúng hạn (OTD) | 30% | GRN actual vs. PO requested date |
| Chất lượng (Quality Pass Rate) | 25% | Accepted qty / Received qty |
| Giá cả cạnh tranh | 20% | Benchmark so với thị trường / RFQ history |
| Dịch vụ & phản hồi | 15% | RFQ response time, issue resolution time |
| Tuân thủ hợp đồng | 10% | Document compliance, payment term compliance |

Evaluation cycles:
- Automated monthly score calculation từ transaction data
- Quarterly formal review (procurement + relevant dept)
- Annual strategic review (C-level với Preferred vendors)

Alerts:
- Score drops > 10 điểm trong 1 tháng → notify Procurement Manager
- Score xuống dưới 70 → trigger improvement plan workflow
- Score xuống dưới 55 → escalate to review committee
```

### Bước 6: Thiết kế Vendor Portal (Self-Service)

```
Vendor Portal là giao diện external cho vendors truy cập:

Tính năng cần thiết kế:
□ Receive & respond to RFQ (xem RFQ, submit quote với pricing, lead time, terms)
□ Acknowledge PO (xác nhận nhận PO, confirm delivery date)
□ Update shipment status (tracking number, expected delivery)
□ Submit invoice (upload invoice, link với PO)
□ View payment status (invoice approved, payment scheduled, paid)
□ Update company profile (thông tin liên lạc, bank account với re-verification)
□ Conflict of interest declaration (annual renewal)
□ View performance scorecard (own scores, trend, improvement areas)

Security:
□ Vendor chỉ xem data của chính họ (tenant isolation)
□ Two-factor authentication cho portal
□ Session timeout: 30 phút inactive
□ Audit log tất cả actions của vendor
```

### Bước 7: Thiết kế Conflict of Interest và Blacklist Management

```
READ: controls.md → Vendor Offboarding Checklist

Conflict of Interest (CoI):
□ Declaration form: Vendor khai báo có quan hệ với nhân viên công ty không?
□ Procurement staff cũng phải khai báo CoI với vendors mình quản lý
□ Annual renewal bắt buộc
□ System alert nếu CoI declaration quá hạn > 30 ngày

Blacklist Management:
□ Propose to blacklist: Procurement Officer propose với evidence
□ Approval: Procurement Manager approve blacklist
□ Notification: Finance được thông báo để block payment
□ Reason documented: Fraud / Contract breach / Quality failure / Ethical violation
□ Review period: Blacklist có thể appeal sau 2 năm (tùy mức độ vi phạm)
□ Cross-entity sharing: Blacklist được share với toàn tập đoàn (nếu multi-entity)
```

### Bước 8: Feature Spec Output

```markdown
# Feature Spec: Vendor Management

## Overview
[Mô tả module]

## User Stories
- As a Procurement Manager, I want to...
- As a Buyer, I want to...
- As a Vendor, I want to...

## Functional Requirements

### REQ-PROC-VND-001: Vendor Registration & Onboarding
[Chi tiết requirement]

### REQ-PROC-VND-002: Approved Vendor List (AVL) Management
[Chi tiết requirement]

### REQ-PROC-VND-003: Vendor Categorization & Risk Classification
[Chi tiết requirement]

### REQ-PROC-VND-004: Vendor Performance Scorecard (Automated)
[Chi tiết requirement]

### REQ-PROC-VND-005: Vendor Self-Service Portal
[Chi tiết requirement]

### REQ-PROC-VND-006: Conflict of Interest Declaration
[Chi tiết requirement]

### REQ-PROC-VND-007: Blacklist Management
[Chi tiết requirement]

### REQ-PROC-VND-008: Sanctions Screening Integration
[Chi tiết requirement]

## Data Model
[Vendor entity, VendorDocument, VendorScore, ConflictDeclaration, BlacklistRecord]

## API Endpoints
[Vendor CRUD, Onboarding workflow, Scorecard, Portal APIs]

## Non-functional Requirements
- Vendor portal: response time < 3s
- Sanctions screening: auto-check trong quá trình onboarding
- Scorecard recalculation: daily batch job
- Audit log retention: tối thiểu 7 năm
```

---

## Checklist trước khi submit

```
□ Vendor onboarding workflow có đủ document checklist
□ AVL tiers được định nghĩa rõ (Preferred/Approved/Probation/Suspended/Blacklisted)
□ Scorecard formula và data sources đã xác định
□ Vendor portal scope (tính năng nào vendor tự serve được)
□ Conflict of Interest flow đã thiết kế
□ Blacklist management có approval workflow
□ Sanctions screening mechanism đã addressed
□ SoD: Vendor onboarding không do cùng người sau đó tạo PO cho vendor đó
```
