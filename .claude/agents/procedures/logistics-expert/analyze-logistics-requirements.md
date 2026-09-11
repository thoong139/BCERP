# Playbook: Phân tích Logistics Requirements

> **Type**: Agent Skill Playbook
> **Agent**: logistics-expert
> **Triggered by**: /wf-analyze-requirements khi có logistics/XNK/SCM modules
> **Output**: `.mc-data/docs/phase1-business/logistics-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: vận chuyển, xuất nhập khẩu, hải quan, kho bãi, TMS, WMS, cross-border, freight, giao nhận
- Khi cần xác định logistics/supply chain requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại nghiệp vụ logistics (TMS, WMS, Customs/XNK, Last-mile, Cross-border, toàn bộ SCM)
□ Chiều vận chuyển: Xuất khẩu / Nhập khẩu / Nội địa / Cross-border?
□ Quy mô: Bao nhiêu shipment/tháng? Bao nhiêu SKU? Bao nhiêu carrier?
□ Phạm vi địa lý: Nội địa / Quốc tế (ASEAN, TQ, EU, US)?
□ Có hệ thống logistics hiện tại không? Nếu có → đang dùng gì?
□ Incoterm nào đang áp dụng chủ yếu?
```

### Bước 2: Xác định scope logistics cần build

Dựa trên loại nghiệp vụ, xác định modules cần cover:

| Scope | Modules cần xác định requirements |
|-------|----------------------------------|
| TMS (Transport Management) | Shipment booking, Carrier integration, Tracking, PoD |
| WMS (Warehouse Management) | Inbound/Outbound, Putaway, Picking, Cross-docking |
| Customs/XNK | HS Code, VNACCS, Declaration, Duty calculation |
| Cross-border E-commerce | Import regulations, Duties, Last-mile |
| Full SCM | Tất cả modules trên + integration giữa các module |

Sau khi xác định scope → load knowledge files tương ứng:
```
TMS/Tracking      → READ: operations.md (Process 1: Export, Process 2: Import)
Customs/XNK       → READ: operations.md (Process 3: Customs Declaration) + controls.md (Section 2)
Carrier management → READ: controls.md (Section 3: Carrier Management Controls)
Incoterms         → READ: controls.md (Section 4: Incoterms 2020 Controls)
Document retention → READ: controls.md (Section 5: Document Retention)
KPIs & metrics    → READ: operations.md (Section 6: KPIs & Metrics)
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng logistics system:
□ Logistics Coordinator → cần shipment CRUD + tracking + exception handling
□ Customs Specialist / Customs Broker → cần HS Code + VNACCS + duty calc
□ Warehouse Supervisor → cần cross-docking + staging + dock scheduling
□ Fleet Manager → cần route optimization + GPS + driver management (nếu own fleet)
□ Freight Forwarder (3PL) → cần carrier rates + claims + multi-modal tracking
□ Logistics Manager → cần approvals + performance dashboard + carrier evaluation
□ Finance → cần duty payment + cost allocation + freight spend tracking

Với mỗi persona: note down pain points và must-have features từ personas.md
```

### Bước 4: Phân tích regulatory requirements

```
READ: controls.md → Section 1, 2

Checklist regulatory cần xác định:
□ VNACCS/VCIS integration cần không? (Nếu có XNK qua cửa khẩu Việt Nam)
□ HS Code classification scope: Bao nhiêu product categories?
□ Declaration types cần support: A11, A12, E31, E62, A43...?
□ C/O (Certificate of Origin) management: FTA nào áp dụng (ATIGA, EVFTA, RCEP)?
□ IMO dangerous goods compliance cần không?
□ Document retention: 5+ years cho customs docs — cần digital vault?
□ Audit trail: 7 years cho mọi status change, cost change
□ Bonded warehouse / Deferred duty cần không?
```

### Bước 5: Xác định integration points

```
READ: operations.md → Section 5: Integration Touchpoints

Internal integrations cần identify:
□ Sales/CRM → Logistics: Orders, Delivery requirements từ đâu vào?
□ Inventory/WMS: Stock availability, GRN/GI sync như thế nào?
□ Finance/ERP: Duty payment, Freight cost allocation, Invoice matching?
□ Purchasing: Supplier orders, Import documents workflow?

External integrations cần identify:
□ Carriers (API vs EDI vs manual portal): Danh sách carrier cụ thể?
□ VNACCS/VCIS: Khai báo electronic hay thông qua broker?
□ Port/Terminal systems: Có cần tích hợp lịch tàu, terminal status?
□ Insurance providers: Automatic coverage hay manual?
□ Google Maps / HERE Maps: Cho route optimization, last-mile?
```

### Bước 6: Viết requirements

Format mỗi requirement:

```markdown
### REQ-LOG-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần — giảm thời gian/chi phí/rủi ro gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Regulatory**: [Compliance requirement liên quan, nếu có]
```

**REQ-ID Format theo module:**
```
REQ-LOG-TMS-001   → Transport Management (shipment, carrier, booking)
REQ-LOG-TRK-001   → Tracking & Visibility
REQ-LOG-WMS-001   → Warehouse Management
REQ-LOG-CUST-001  → Customs/XNK (khai báo hải quan)
REQ-LOG-HS-001    → HS Code Management
REQ-LOG-DOC-001   → Document Management (BoL, Invoice, Packing list)
REQ-LOG-CARR-001  → Carrier Management
REQ-LOG-KPI-001   → KPI & Reporting
REQ-LOG-INT-001   → Integration (VNACCS, Carrier APIs, ERP)
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/logistics-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope logistics)
2. Supply Chain Stage Coverage (First-mile / Cross-border / Customs / Last-mile / Warehousing)
3. Personas affected (bảng tóm tắt)
4. Regulatory Requirements (VNACCS, HS Code, Incoterms, document retention)
5. Requirements theo module, có REQ-ID đầy đủ
6. Integration Map (internal + external)
7. KPI targets (OTD rate, clearance time, POD capture, v.v.)
8. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-LOG-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng (tiết kiệm thời gian/chi phí/giảm rủi ro compliance)
□ VNACCS/customs requirements đã covered nếu có XNK
□ Document retention 5+ years đã noted
□ Audit trail requirements đã included
□ Integration points với Finance và ERP đã identified
□ Open questions được list ra để stakeholders review
```
