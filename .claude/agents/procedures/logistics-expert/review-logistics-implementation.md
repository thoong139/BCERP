# Playbook: Review Logistics Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: logistics-expert
> **Triggered by**: /wf-implement-feature hoặc post-implementation review khi có logistics code
> **Output**: Logistics implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của logistics module
- Khi cần validate implementation từ business logic và compliance perspective
- Khi cần kiểm tra tính đúng đắn của shipment state machine, duty calculation, VNACCS integration

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Shipment Management (TMS) → check state machine, authorization, audit trail
□ Shipment Tracking → check carrier integration, milestone events, ETA logic
□ Customs Declaration → check VNACCS integration, HS Code, duty calculation
□ Document Management → check retention, access control, immutability
□ Carrier Management → check performance tracking, rate management
□ Proof of Delivery → check PoD capture, validation, retention
```

### Bước 2: Load controls knowledge

```
READ: controls.md → Luôn làm bất kể module nào

Compliance checklist áp dụng cho mọi logistics module:
□ Authorization: Có enforce shipment authorization matrix theo value không?
□ Audit trail: Mọi status change có log (user, timestamp, old→new) không?
□ Document retention: Có implement retention policy 5-7 năm không?
□ Void/Delete control: Shipments trong retention period có bị xóa vật lý không?
□ Carrier credential security: API keys, credentials có được lưu secure không?
```

### Bước 3: Review theo module type

**Shipment Management (TMS):**
```
READ: operations.md → Process 1, 2 (state flows)

State Machine:
□ Đúng states theo playbook design-shipment-tracking.md?
□ Illegal transitions có bị block không? (ví dụ: Draft → InTransit phải bị reject)
□ Rollback logic: Chỉ được rollback khi có exception, có authorization không?
□ State change phải trigger: update audit log + send notification + recalculate ETA

Authorization:
□ Shipment value > 50M VND: Có require Manager approval không? (xem controls.md)
□ Void/Cancel sau Booked: Có require Manager approval không?
□ Cross-border complex: Có require Director + Legal không?

Audit trail:
□ Mỗi status change: log user_id, old_status, new_status, timestamp, location, notes
□ Cost change: log user_id, old_value, new_value, reason
□ Logs phải immutable — KHÔNG có update/delete endpoint cho audit records
```

**Shipment Tracking:**
```
READ: operations.md → Section 5: Integration Touchpoints

Carrier Integration:
□ Carrier adapter pattern đúng không? (abstract interface, không hardcode per-carrier logic)
□ Retry logic: Có exponential backoff không? (không retry vô hạn)
□ Timeout: Có set timeout cho carrier API calls không? (khuyến nghị: 30s)
□ Circuit breaker: Nếu carrier API liên tục fail → có fallback to manual mode không?
□ API credentials: Không được hardcode trong code — phải lấy từ config/secrets manager

Milestone Events:
□ Timestamp: Có phân biệt occurred_at (thực tế) vs recorded_at (system) không?
□ Source tracking: Có ghi source (CARRIER_API / VNACCS / MANUAL / GPS) không?
□ Raw payload: Có lưu raw response từ carrier API không? (cần cho audit)
□ Duplicate milestone: Nếu cùng milestone đến 2 lần → idempotent handling không?

ETA Calculation:
□ ETA update tự động khi nhận milestone mới không?
□ Delay detection: Có tính delay = ETA_predicted - ETA_original không?
□ Notification trigger: Có gửi alert khi delay vượt threshold không?
```

**Customs Declaration:**
```
READ: controls.md → Section 2: Customs Compliance Controls
READ: operations.md → Process 3: Customs Declaration

VNACCS Integration:
□ Request/Response payload: Có lưu đầy đủ để audit không?
□ Error handling: Có parse VNACCS error codes và hiển thị friendly message không?
□ Timeout handling: VNACCS timeout → có retry với exponential backoff không?
□ Fallback: Khi VNACCS down → có export PDF để nộp thủ công không?
□ Declaration status polling: Có xử lý trường hợp status không cập nhật không?

Red/Yellow Channel:
□ Red Channel workflow: Có block thông quan tự động không? (cần physical inspection)
□ Yellow Channel: Có trigger upload docs bổ sung workflow không?
□ KHÔNG được bypass Red Channel theo bất kỳ điều kiện nào

HS Code:
□ Validation: HS Code có được validate format (8 digits Việt Nam) không?
□ Expired HS Code: Có cảnh báo nếu dùng HS Code hết hiệu lực không?
□ Audit: HS Code đã dùng có được log với user_id và timestamp không?

Duty Calculation:
□ Formula đúng không?
  - Import duty = Dutiable value × Import duty rate
  - VAT = (Dutiable value + Import duty) × VAT rate
□ FTA rate selection: Có check C/O validity trước khi áp dụng FTA rate không?
□ Calculation audit: Có lưu input (HS Code, value, rate) + output không?
□ Rounding: Có rule rounding nhất quán không? (làm tròn lên theo luật thuế VN)
```

**Document Management:**
```
READ: controls.md → Section 5, 7

Retention compliance:
□ Delete endpoint: Có kiểm tra retention period trước khi cho xóa không?
□ Documents trong retention period: KHÔNG được xóa vật lý
□ Soft delete cho records <5 năm → block hard delete

Immutability:
□ Document content: Sau khi submit customs → có prevent modification không?
□ Version history: Có lưu tất cả versions không?

Access control:
□ Customs Specialist: Full access
□ Logistics Coordinator: View-only
□ Finance: View customs docs, download invoices
□ External (Customer portal): View own shipment docs only
```

**Proof of Delivery:**
```
PoD capture validation:
□ Required fields: signature + photo + timestamp + recipient_name — tất cả phải có
□ Timestamp: Có prevent chỉnh sửa timestamp sau capture không?
□ GPS: Có capture GPS coordinates tại thời điểm PoD không?
□ Photo: Có kiểm tra file size limit (khuyến nghị max 10MB) không?
□ Partial delivery: Có capture số lượng thực giao không?
□ Rejected delivery: Có capture lý do + evidence không?

PoD retention:
□ Lưu 5+ năm (xem controls.md)
□ Original file (không resize/compress lossily để giữ evidence)
```

### Bước 4: Performance Check

```
READ: operations.md → Section 6: KPIs (volume targets)

□ Shipment list query: Có index trên status, carrier_id, created_at không?
□ Tracking milestone insert: Có batch insert không khi nhiều events cùng lúc?
□ HS Code search: Full-text search có index không? (<1s cho 10,000+ codes)
□ Duty calculation: Có cache rate tables không? (tránh query DB mỗi lần)
□ VNACCS calls: Có async processing không? (không block UI)
□ Document upload: Có streaming upload không? (không load toàn bộ file vào memory)
□ Carrier API calls: Có connection pooling không?
□ Large shipment volume: Test với >10,000 active shipments — list view có lag không?

KPI calculation:
□ OTD rate query: Có được optimize cho period aggregation không?
□ Transit time average: Có pre-aggregate daily không?
```

### Bước 5: Security Check

```
□ Carrier credentials: Không hardcode trong code — lấy từ environment/secrets manager
□ VNACCS credentials: Encrypted at rest, không log trong plain text
□ API rate limiting: Có enforce để tránh DDoS qua logistics endpoints không?
□ Document access: URL-signed (expiring links) cho document downloads không?
□ Audit log tampering: API endpoint để xóa/sửa audit logs phải KHÔNG tồn tại
□ PII in logs: Tên người nhận, địa chỉ không được log ra application logs
```

### Bước 6: Output — Review Report

```markdown
# Logistics Implementation Review: [Module Name]

## Compliance Status: PASS / FAIL / NEEDS ATTENTION

## Critical Issues (block go-live)
- [ ] [Issue]: [Location in code / file path] → [Required fix]

## Important Issues (fix trước sprint tiếp theo)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Compliance Checklist
| Item | Status | Notes |
|------|--------|-------|
| Shipment authorization matrix | OK / ISSUE | |
| State machine — no illegal transitions | OK / ISSUE | |
| Audit trail immutable | OK / ISSUE | |
| Document retention 5+ years | OK / ISSUE | |
| VNACCS error handling + fallback | OK / ISSUE | |
| Red Channel — không bypass | OK / ISSUE | |
| HS Code validation | OK / ISSUE | |
| Duty calculation accuracy | OK / ISSUE | |
| Carrier credentials secured | OK / ISSUE | |
| PoD required fields validation | OK / ISSUE | |

## Performance Concerns
[List các vấn đề performance phát hiện, với estimated impact]

## Security Concerns
[List các vấn đề security phát hiện]

## Sign-off
□ Business logic (state machine, authorization): OK / ISSUE
□ Compliance (retention, audit trail, VNACCS): OK / ISSUE
□ Duty calculation accuracy: OK / ISSUE
□ Security (credentials, access control): OK / ISSUE
□ Performance (indexes, async processing): OK / ISSUE
```

---

## Checklist trước khi submit review

```
□ Đã check state machine — không có illegal transitions
□ Đã verify audit trail immutable
□ Đã check VNACCS error handling và fallback
□ Đã verify Red Channel KHÔNG bị bypass
□ Đã kiểm tra duty calculation formula đúng
□ Đã check carrier credentials không hardcode
□ Đã verify document retention policy được enforce
□ Đã check performance cho large volume scenarios
□ Đã check PoD validation (signature + photo + timestamp required)
```
