# Playbook: Design Shipment Tracking Module

> **Type**: Agent Skill Playbook
> **Agent**: logistics-expert
> **Triggered by**: /wf-design hoặc /wf-define-features khi cần design TMS/shipment tracking
> **Output**: Feature spec cho Shipment Tracking module

---

## Khi nào dùng playbook này

- Khi cần spec module "Quản lý Vận chuyển" hoặc "Shipment Tracking" hoặc "TMS"
- Khi cần thiết kế data model cho shipment lifecycle
- Khi review/audit hệ thống tracking hiện có

---

## Procedure

### Bước 1: Xác định scope

```
Hỏi hoặc suy luận từ context:
□ Shipment directions: Xuất khẩu / Nhập khẩu / Nội địa / Tất cả?
□ Transport modes: Sea / Air / Road / Rail / Multimodal?
□ Carrier integration: Qua API (tự động) hay EDI hay manual update?
□ Own fleet: Có không? Nếu có → cần fleet management module riêng
□ Last-mile delivery: Có cần manage không? Hay chỉ đến cảng/kho?
□ PoD: Hình thức nào? Digital signature / Photo / Scan?
□ Customer visibility: Có cần shipper/consignee portal không?
□ Volume: Bao nhiêu shipment/ngày? (ảnh hưởng architecture)
```

### Bước 2: Thiết kế Shipment Lifecycle

```
READ: operations.md → Process 1 (Export), Process 2 (Import)

Shipment State Machine:

EXPORT:
Draft → Booked → PickedUp → Consolidated → CustomsSubmitted →
CustomsCleared → Loaded → InTransit → ArrivedPOD → Delivered → Closed

IMPORT:
Expected → ArrivalNotice → Unloaded → CustomsSubmitted →
CustomsCleared → DeliveryScheduled → Delivered → GRNConfirmed → Closed

DOMESTIC:
Draft → Booked → PickedUp → InTransit → OutForDelivery → Delivered → Closed

Quy tắc transitions:
□ KHÔNG được skip states (ví dụ: Draft → InTransit là invalid)
□ KHÔNG được rollback trừ exception flow (ví dụ: Delivered → Exception)
□ Mỗi transition phải log: user, timestamp, location, ghi chú
□ Cancel chỉ được ở Draft hoặc Booked — cần manager approval sau Booked
```

### Bước 3: Thiết kế Carrier Integration Strategy

```
READ: controls.md → Section 3: Carrier Management Controls

Phân loại carriers theo integration level:

| Tier | Integration | Tracking update | Use case |
|------|-------------|-----------------|----------|
| Tier 1 (API) | REST/JSON | Real-time / webhook | Major carriers (Maersk, DHL, FedEx) |
| Tier 2 (EDI) | X12/EDIFACT | Batch (4-12h) | Traditional freight forwarders |
| Tier 3 (Manual) | Portal update | Manual | Nhỏ lẻ, local carriers |

Thiết kế Carrier Adapter Layer:
□ Abstract interface: CarrierAdapter với methods: book(), track(), cancelBooking(), requestPoD()
□ Retry logic: Exponential backoff (1s → 2s → 4s → max 3 lần)
□ Fallback: Nếu API fail → chuyển sang manual update với alert
□ Rate limit handling: Queue requests, respect carrier API limits
□ Credential management: Secure storage, per-carrier config (không hardcode)
```

### Bước 4: Thiết kế Milestone Events & Timestamps

```
READ: operations.md → Section 2: Core Logistics Processes

Mỗi shipment cần track các milestones:

| Milestone | Code | Mô tả | Source |
|-----------|------|--------|--------|
| Booking confirmed | BOOK | Carrier xác nhận booking | API / Manual |
| Pickup complete | PICK | Hàng đã được lấy tại origin | API / Manual |
| Departure | DEP | Phương tiện khởi hành | API / Port system |
| In transit update | TRK | Cập nhật vị trí định kỳ | API / GPS |
| Arrival at port | ARR | Tàu/xe tới cảng/trạm | API / Port system |
| Customs submitted | CST-SUB | Tờ khai đã nộp | VNACCS |
| Customs cleared | CST-CLR | Hàng đã thông quan | VNACCS |
| Out for delivery | OFD | Xe đang giao | Driver app / GPS |
| Delivered | DLV | Giao hàng thành công + PoD | Driver app |

Data model cho Milestone Event:
```
ShipmentMilestone:
  - id
  - shipment_id
  - milestone_code (enum từ bảng trên)
  - occurred_at (timestamp thực tế)
  - recorded_at (timestamp system nhận)
  - location (city, country, lat/lng nếu có)
  - source (CARRIER_API | VNACCS | MANUAL | GPS)
  - operator_id (user nhập nếu manual)
  - notes
  - raw_payload (JSON từ API gốc — audit trail)
```
```

### Bước 5: Thiết kế Exception Management

```
Exception types cần handle:

| Exception | Trigger | Auto-action | Notification |
|-----------|---------|-------------|--------------|
| Delay | ETA + buffer vượt quá | Recalculate ETA | Notify coordinator + customer |
| Shipment damage | Report từ carrier/PoD | Open claim | Alert manager, notify insurance |
| Missing PoD | >24h sau Delivered | Flag overdue | Remind coordinator |
| Customs hold | Red/Yellow channel | Flag for customs team | Alert customs specialist |
| Carrier no-show | Pickup miss > 2h | Escalate booking | Alert coordinator + backup carrier |
| Document missing | Pre-customs check | Block declaration | Alert customs specialist |

Exception workflow:
□ Exception tạo ra → assign cho owner (coordinator / customs specialist)
□ Owner xác nhận → set resolution plan + ETA
□ Auto-escalate nếu không xử lý trong SLA (4h critical, 24h normal)
□ Resolution recorded với timestamp và action taken
□ Closed exception → log vào carrier performance history
```

### Bước 6: Thiết kế Proof of Delivery (PoD)

```
PoD Requirements:
□ Digital signature capture (driver app hoặc web)
□ Photo upload (tối thiểu 1 ảnh hàng đã giao)
□ Timestamp auto-captured (không cho phép chỉnh sửa)
□ GPS coordinates tại thời điểm PoD
□ Recipient name + signature
□ Condition note (nếu hàng có dấu hiệu hư hỏng)

PoD Acceptance Rules:
□ PoD hợp lệ khi: có signature + photo + timestamp + recipient name
□ Partial delivery: ghi rõ số lượng giao được / tổng
□ Rejected delivery: ghi lý do + evidence → tạo re-delivery task
□ PoD phải lưu trữ 5+ năm (xem controls.md Section 5)

POD capture rate target: 100% (xem controls.md KPI)
```

### Bước 7: Thiết kế Notification & Alerts

```
Notification triggers:

| Event | Recipient | Channel | SLA |
|-------|-----------|---------|-----|
| Shipment booked | Coordinator + Customer | Email + In-app | Immediate |
| Pickup confirmed | Shipper | Email + SMS | Immediate |
| Departure | Customer | Email | Immediate |
| Delay detected | Coordinator + Customer | Email + In-app | Immediate |
| Customs hold | Customs Specialist | Email + In-app | Immediate |
| Delivered | Customer + Coordinator | Email + SMS | Immediate |
| PoD missing | Coordinator | In-app | After 24h |

Notification preferences: user có thể config kênh và thời điểm nhận.
```

### Bước 8: Thiết kế KPIs & Dashboard

```
READ: operations.md → Section 6: KPIs & Metrics

Dashboard cho Logistics Manager:
□ OTD rate (On-time delivery): On-time / Total × 100 — Target >95%
□ Average transit time (actual vs. estimated)
□ Exception rate (exceptions / total shipments)
□ PoD capture rate — Target 100%
□ Carrier performance comparison (table)
□ Shipment volume trend (daily/weekly/monthly)
□ Cost per shipment (nếu có cost module)

Alerts cho Dashboard:
□ OTD rate < 90% → highlight đỏ
□ Exception rate > 5% → highlight vàng
□ PoD capture rate < 100% → highlight vàng
```

### Bước 9: Feature Spec Output

```markdown
# Feature Spec: Shipment Tracking (TMS)

## Overview
[Mô tả module — scope, personas, business value]

## User Stories
- As a Logistics Coordinator, I want to... [theo personas.md]
- As a Logistics Manager, I want to...
- As a Customer/Consignee, I want to...

## Functional Requirements

### Shipment Management
REQ-LOG-TMS-001: Tạo và quản lý shipment với lifecycle state machine
REQ-LOG-TMS-002: Booking với carriers (Tier 1 API / Tier 2 EDI / Tier 3 manual)
REQ-LOG-TMS-003: Cancellation workflow với authorization theo controls.md

### Tracking
REQ-LOG-TRK-001: Real-time milestone tracking với multi-source ingestion
REQ-LOG-TRK-002: ETA calculation và auto-update khi delay
REQ-LOG-TRK-003: Customer tracking portal (nếu scope có)

### Exception Management
REQ-LOG-TMS-004: Exception detection, assignment và escalation
REQ-LOG-TMS-005: Damage report với insurance notification

### Proof of Delivery
REQ-LOG-TMS-006: Digital PoD capture (signature + photo + GPS + timestamp)
REQ-LOG-TMS-007: Partial delivery và rejected delivery handling

### Carrier Management
REQ-LOG-CARR-001: Carrier adapter với retry và fallback
REQ-LOG-CARR-002: Carrier performance tracking (OTD, damage, response time)

### Notifications
REQ-LOG-TRK-004: Configurable notification per event per recipient

### KPI Dashboard
REQ-LOG-KPI-001: Real-time OTD, transit time, exception rate, PoD capture rate

## Data Model
[Shipment, ShipmentMilestone, Exception, PoD, CarrierIntegration — field definitions]

## API Endpoints
[Nếu cần thiết kế API contract]

## Non-functional Requirements
- Performance: Shipment list load < 2s cho 10,000+ active shipments
- Tracking update latency: < 5 phút từ carrier event đến system
- PoD upload: support file tối đa 10MB
- Availability: 99.5% uptime (logistics hoạt động 24/7)
- Audit trail: Immutable — không được xóa hay sửa milestone records
```

---

## Checklist trước khi submit

```
□ State machine đã cover đủ Export + Import + Domestic flows
□ Illegal state transitions đã được define rõ (KHÔNG skip states)
□ Carrier adapter pattern đã thiết kế cho 3 tiers
□ PoD requirements đầy đủ (signature + photo + timestamp + GPS)
□ Exception types và SLA escalation đã define
□ Document retention 5+ years đã noted trong data model
□ Audit trail cho mọi status change đã included
□ KPI targets theo operations.md đã referenced
```
