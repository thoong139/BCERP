# Playbook: Design Audit Trail & Logging System

> **Type**: Agent Skill Playbook
> **Agent**: compliance-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần spec audit trail, activity logging, immutable log
> **Output**: Feature spec cho Audit Trail module

---

## Khi nào dùng playbook này

- Khi cần thiết kế module "Audit Trail" / "Nhật ký Kiểm toán" / "Activity Log"
- Khi requirements đề cập đến immutability, tamper-evident logs, audit logging
- Khi regulations yêu cầu: SOX (Section 404), PCI-DSS (Requirement 10), SOC 2 (CC7), ISO 27001 (A.12.4), HIPAA
- Khi cần integrate với SIEM hoặc external auditor export

---

## Procedure

### Bước 1: Xác định scope và regulatory drivers

```
Hỏi hoặc suy luận từ context:

□ Regulations applicable: SOX / PCI-DSS Req 10 / SOC 2 CC7 / ISO 27001 A.12.4 / HIPAA / tất cả?
□ Hệ thống nào cần audit trail: chỉ application layer hay cả infra, database, API?
□ Ai cần access audit logs: Internal Auditor / External Auditor / CISO / Security team / All?
□ Search & filter requirements: ad-hoc query hay chỉ cần fixed reports?
□ Export for external auditors: định dạng nào (PDF, CSV, JSON)?
□ Real-time alerting: Cần alert ngay khi anomaly hay chỉ batch report?
□ SIEM integration: Có SIEM (Splunk, Datadog, Elastic) không?
□ Retention: Bao nhiêu năm giữ logs?
```

### Bước 2: Thiết kế Audit Event Taxonomy

```
WHY: Taxonomy nhất quán cho phép search, filter, và correlate events hiệu quả.
Không có taxonomy → logs là noise, không phải intelligence.

Mỗi audit event PHẢI capture đủ 5W + Result:

  WHO:    user_id, user_role, session_id, ip_address, user_agent
  WHAT:   action_type, resource_type, resource_id, resource_name
  WHEN:   timestamp (UTC, millisecond precision), timezone_offset
  WHERE:  service_name, endpoint, environment (prod/staging)
  WHY:    reason_code (optional — user-provided justification cho sensitive actions)
  RESULT: outcome (success/failure/partial), error_code (nếu failure), affected_record_count

Audit Event Categories:

1. Authentication & Authorization
   → login_success, login_failure, logout, mfa_bypass_attempt
   → token_issued, token_revoked, session_expired
   → permission_denied, privilege_escalation

2. Data Access
   → record_read (chỉ log cho sensitive data: PII, financial, health)
   → bulk_export, report_generated, data_search
   → Không log mọi read operation → performance impact và noise

3. Data Modification
   → record_created, record_updated, record_deleted, record_restored
   → bulk_update, bulk_delete (flag riêng — high-risk operations)
   → before_value, after_value (chỉ cho sensitive fields — hash PII nếu cần)

4. Configuration & System
   → setting_changed, role_assigned, role_revoked
   → user_created, user_deactivated, user_deleted
   → integration_configured, api_key_generated, api_key_revoked

5. Compliance-specific
   → control_assessment_submitted, exception_requested, exception_approved
   → finding_created, remediation_closed
   → report_exported_for_auditor, consent_recorded, consent_withdrawn

6. Security Events
   → data_export_large_volume (> threshold)
   → failed_access_sensitive_resource (repeated)
   → unusual_time_access, off_hours_admin_action
```

### Bước 3: Thiết kế Immutability Requirements

```
WHY: Audit logs phải không thể bị sửa đổi — kể cả bởi system administrators.
Đây là yêu cầu bắt buộc của PCI-DSS Req 10.5, SOC 2 CC7.2, SOX.

Immutability Strategy (chọn 1 hoặc kết hợp):

Option A — Append-only storage (khuyến nghị cho most cases):
□ Log table/store chỉ cho phép INSERT, không UPDATE/DELETE
□ Database role cho audit service: chỉ có INSERT privilege
□ Không expose DELETE endpoint trong API (kể cả admin)
□ Soft-delete nếu cần "remove" entry: thêm is_hidden = true, nhưng record vẫn tồn tại

Option B — Cryptographic chaining (khuyến nghị cho high-assurance: PCI-DSS level 1, SOX):
□ Mỗi log entry có: hash = SHA-256(previous_hash + event_data)
□ First entry: hash = SHA-256("GENESIS" + event_data)
□ Chain integrity verification: periodic job check chain không bị break
□ Nếu chain break được detected → alert CISO ngay lập tức

Option C — Write-once external storage:
□ Stream logs sang immutable store: AWS S3 Object Lock / Azure Immutable Blob / Write-once tape
□ Retention lock: không ai có thể xóa trước retention period hết hạn
□ Kết hợp với Option A/B tại application layer

Hash & Integrity Fields:
  - event_hash: SHA-256(event_id + timestamp + actor + action + resource + result)
  - previous_event_hash: hash của event liền trước (nếu dùng chaining)
  - signed_by: service identity (nếu dùng digital signing)

Verification:
□ Daily integrity check job: verify toàn bộ chain không có gaps hoặc tampering
□ Alert nếu hash mismatch hoặc gap được phát hiện
□ Monthly integrity report cho Compliance Officer
```

### Bước 4: Thiết kế Retention Periods

```
READ: .claude/references/team-expert/compliance/regulations.md → Data Retention table

Retention theo loại event và regulation:

| Event Type              | Minimum Retention | Regulation Basis         |
|-------------------------|-------------------|--------------------------|
| Authentication logs     | 1 năm (online), 7 năm (archive) | PCI-DSS 10.7, SOC 2 |
| Financial transactions  | 10 năm            | Tax law (VN), SOX        |
| Data access (PII)       | 5 năm             | GDPR, Decree 13/2023     |
| Configuration changes   | 7 năm             | SOX, ISO 27001           |
| Compliance assessments  | 7 năm             | SOC 2 Type II audit period |
| Security incidents      | 7 năm             | SOX, insurance           |
| Consent records         | Duration of relationship + 5 năm | GDPR Art 7 |

Implementation:
□ Retention policy entity: event_category → retention_days (configurable, không hardcode)
□ Auto-archive: logs > hot_retention_days → move sang cold storage (S3 Glacier, Azure Archive)
□ Auto-delete: logs > retention_days → irreversible deletion với deletion proof record
□ Deletion proof: "log entry [ID] deleted on [date] per retention policy [policy_id]" — keep forever

Lưu ý: KHÔNG xóa logs đang liên quan đến active legal hold hoặc open audit
```

### Bước 5: Thiết kế Search & Filter Capabilities

```
WHY: Logs vô dụng nếu không thể tìm được trong vài phút khi auditor yêu cầu.

Search API phải support:
□ Filter by: user_id, action_type, resource_type, resource_id, date_range, outcome, ip_address
□ Full-text search trong reason_code và error_code
□ Complex query: "Tất cả bulk_delete operations bởi user X trong tháng 3"
□ Aggregation: "Số lượng login_failure per user trong 24h"
□ Pagination: mọi query phải có cursor-based pagination (không offset — performance)

Tìm kiếm nâng cao (cho Security team):
□ Anomaly queries: "Users đăng nhập ngoài giờ làm việc"
□ Sequence detection: "User A access record → 5 phút sau bulk_export"
□ Cross-user correlation: "Ai đã access record này trong khoảng thời gian X?"

Performance requirements:
□ Simple filter query: < 500ms cho 7-day window
□ Complex aggregation: < 5s cho 90-day window
□ Full history search: async job + notify khi done
□ Indexing strategy: timestamp DESC là primary index, (user_id, timestamp) compound index
```

### Bước 6: Thiết kế Export for External Auditors

```
WHY: External auditor cần evidence packages — manual download là fragile và time-consuming.

Auditor Export Portal (nếu cần external access):
□ Read-only access với time-limited credentials (max 30 ngày)
□ Auditor chỉ thấy logs trong audit period và scope được approve
□ Mọi access của auditor cũng được logged (meta-audit)
□ Watermark trên exported files: "CONFIDENTIAL — Audit Evidence — [Auditor Name] — [Date]"

Export Formats:
□ CSV: raw data, máy-readable, cho auditor analysis
□ PDF: human-readable report với digital signature
□ JSON: structured, cho auditor's automated tools
□ SIEM format: Common Event Format (CEF) hoặc LEEF nếu auditor dùng SIEM

Export Package:
□ Manifest file: danh sách tất cả files trong package + hashes
□ Chain of custody: ai export, khi nào, cho ai
□ Hash verification: auditor có thể verify integrity của package

Bulk Evidence Request:
□ Auditor submit request: "Cần toàn bộ access logs cho user group X, Q1 2026"
□ System tạo export job async (có thể mất vài giờ)
□ Notify auditor qua email khi ready, link download valid 48h
```

### Bước 7: Thiết kế Tamper-Evident Storage

```
WHY: Log storage bị compromise mà không detect được = worst case scenario trong audit.

Defense layers (theo depth):
□ Layer 1 — Application: append-only API, no delete endpoint
□ Layer 2 — Database: separate audit DB với restricted permissions, row-level security
□ Layer 3 — Cryptographic: event chain hashing (Bước 3)
□ Layer 4 — Replication: cross-region replica, real-time streaming
□ Layer 5 — External sink: stream tới external SIEM (Splunk/Datadog) — ngoài tầm admin nội bộ

Privileged access monitoring:
□ Database admin access phải trigger alert cho CISO
□ Admin access to log tables: phải có dual approval (4-eyes principle)
□ Infrastructure changes affecting log storage: phải notify Security Officer

Storage integrity checks:
□ Hourly: spot-check random sample (100 records) — verify hashes
□ Daily: full chain integrity scan
□ Weekly: compare record counts với external sink
□ Alert on: hash mismatch, missing records, unexpected gap
```

### Bước 8: Thiết kế SIEM Integration

```
Tại sao SIEM: Audit logs tập trung trong 1 app là chưa đủ — SIEM correlate logs từ nhiều nguồn.

Integration Pattern (push-based, không pull):
□ Application publish events → Message queue (Kafka / AWS SQS / Azure Service Bus)
□ SIEM consumer subscribe → ingest real-time
□ Không dùng batch file transfer (delay tới 24h là quá chậm cho security incidents)

Standard Formats:
□ Syslog RFC 5424 (generic)
□ Common Event Format (CEF) — ArcSight
□ LEEF — IBM QRadar
□ JSON với OCSF schema — OpenCybersecurity Schema Framework (modern standard)

Mapping tới SIEM:
□ authentication events → SIEM authentication category
□ privilege_escalation → SIEM privilege use category
□ bulk_delete, bulk_export → SIEM data exfiltration category
□ Severity mapping: security events → high, data changes → medium, reads → low

Không expose SIEM credentials trong application config → dùng secrets manager
```

### Bước 9: Thiết kế Real-time Alerting

```
WHY: Detect anomaly real-time — không đợi auditor phát hiện trong quarterly review.

Alert Rules (must-have):
□ > 5 login_failure trong 10 phút cho cùng 1 user → account lockout + alert Security
□ bulk_delete > 100 records → alert CISO + pause operation chờ confirm
□ bulk_export > 10,000 records → alert Security team
□ Admin action ngoài giờ làm việc (22:00-06:00) → alert Security
□ Same user login từ 2 IP khác nhau trong 5 phút → alert Security
□ Access tới sensitive resource sau 30 ngày inactive → alert Security + log as anomaly
□ Chain integrity break → alert CISO ngay lập tức

Alert Channels:
□ Email: cho non-critical alerts
□ SMS/Phone: cho critical alerts (chain break, bulk delete)
□ Webhook/PagerDuty: cho security incidents cần immediate response
□ In-app notification: cho Compliance Officer daily summary

Alert Suppression:
□ Maintenance window: suspend alerts trong scheduled maintenance (phải có approval)
□ Tuning period: suppress false positives sau investigation (require justification + audit trail)
```

### Bước 10: Feature Spec Output

```markdown
# Feature Spec: Audit Trail & Logging System

## Overview
[Mô tả module — scope, regulatory basis, business value]

## User Stories
- Là Internal Auditor, tôi muốn tìm kiếm audit logs theo user và time range...
- Là CISO, tôi muốn nhận alert ngay khi bulk_delete operation xảy ra...
- Là External Auditor, tôi muốn download evidence package trong audit scope...
- Là Compliance Officer, tôi muốn verify chain integrity hàng ngày...

## Functional Requirements

### REQ-COMP-AUDIT-001: Audit Event Taxonomy & Capture
[Mô tả, acceptance criteria]

### REQ-COMP-AUDIT-002: Immutable Append-only Storage với Cryptographic Chaining
...

### REQ-COMP-AUDIT-003: Retention Policy Engine
...

### REQ-COMP-AUDIT-004: Search & Filter Interface
...

### REQ-COMP-AUDIT-005: External Auditor Export Portal
...

### REQ-COMP-AUDIT-006: SIEM Integration via Message Queue
...

### REQ-COMP-AUDIT-007: Real-time Anomaly Alerting
...

## Data Model
[AuditEvent entity với đầy đủ fields — xem Bước 2]

## API Design
GET  /audit-logs?filters=...&cursor=...    → Search logs
GET  /audit-logs/{id}                      → Get single event
POST /audit-exports                        → Create export job
GET  /audit-exports/{id}                   → Check export status
GET  /audit-exports/{id}/download          → Download package
GET  /audit-integrity/status               → Chain integrity status
POST /audit-alerts/rules                   → Configure alert rules

## Non-functional Requirements
- Immutability: Zero path to modify or delete log entries
- Performance: Simple query < 500ms, complex < 5s
- Throughput: Handle 10,000 events/second at peak
- Availability: 99.9% — logs phải capture kể cả khi app degraded (write-ahead)
- Retention: Configurable per event type, minimum 1 năm online + 7 năm archive
```

---

## Checklist trước khi submit

```
□ 5W + Result được capture cho mọi event type
□ Immutability strategy được chọn và justified (append-only / chaining / WORM)
□ Cryptographic integrity: hash per event hoặc chain hashing
□ Retention periods cover tất cả applicable regulations
□ Cold storage / archive strategy cho old logs
□ Search interface đáp ứng auditor use cases
□ External auditor access: scoped, time-limited, watermarked
□ SIEM integration: push-based, standard format
□ Real-time alerts cho critical events (bulk delete, chain break, off-hours admin)
□ Privileged access tới log storage được monitored
□ REQ-IDs đúng format REQ-COMP-AUDIT-[NNN]
```
