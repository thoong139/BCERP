# Playbook: Thiết kế Workflow Automation

> **Type**: Agent Skill Playbook
> **Agent**: automation-architect
> **Triggered by**: Sau khi evaluation report được APPROVE — thiết kế automation workflow
> **Output**: `.mc-data/docs/phase3-architecture/automation-design-[process-name].md`

---

## Khi nào dùng playbook này

- Sau khi `evaluate-automation-candidate.md` trả về verdict APPROVE hoặc APPROVE AS PILOT
- Khi cần thiết kế chi tiết một automation workflow đã được approve
- Khi refactoring automation cũ cần redesign

**Điều kiện tiên quyết**: File evaluation report phải tồn tại và có verdict APPROVE. Không thiết kế automation chưa qua evaluation.

---

## Procedure

### Bước 1: Đọc evaluation report

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3
READ: Evaluation report từ evaluate-automation-candidate.md
READ: architecture-patterns.md

Xác nhận từ evaluation:
□ Verdict là APPROVE hoặc APPROVE AS PILOT
□ Steps nào nếu PARTIAL cần giữ manual (không automate)
□ Prerequisites đã đủ chưa?
□ Blast radius level (ảnh hưởng đến design decisions)
□ External dependencies list
□ Edge cases không automatable
□ REQ-ID đã được gán
```

### Bước 2: Trigger event specification

Xác định chính xác điều gì khởi động workflow:

```markdown
## Trigger Specification

### Primary trigger
| Property | Value |
|----------|-------|
| Type | [Webhook / Schedule / Event / Manual / API call] |
| Source | [System tạo ra trigger] |
| Payload format | [JSON schema / CSV / Form data] |
| Authentication | [HMAC signature / API key / Bearer token] |

### Trigger validation
Trước khi bắt đầu xử lý, validate:
```json
{
  "required_fields": ["field1", "field2"],
  "field_constraints": {
    "field1": "string, min:1, max:255",
    "field2": "enum: [value1, value2, value3]"
  },
  "idempotency_key": "event_id"
}
```

**Nếu validation fail**: [Reject với error response / Log và skip / Alert manual review]

### Schedule (nếu trigger là scheduled)
```yaml
schedule:
  cron: "0 8 * * 1-5"  # 8am weekdays
  timezone: "Asia/Ho_Chi_Minh"
  max_runtime: 30m
  overlap_policy: skip  # hoặc queue
```

### Deduplication
Cơ chế đảm bảo cùng một trigger không xử lý 2 lần:
- Idempotency key: [field để identify unique execution]
- Dedup window: [X giờ/ngày]
- Storage: [Redis / DB table / Platform built-in]
```

### Bước 3: Step sequence design

Map toàn bộ automation flow:

```markdown
## Workflow Step Sequence

### Overview diagram (text format)

```
TRIGGER
  ↓
[Step 1: Validate input]
  ↓ valid                    → invalid: [action]
[Step 2: Fetch additional data]
  ↓ found                    → not found: [action]
[Step 3: Transform/Process]
  ↓
[Step 4: Human checkpoint] ← Nếu blast radius High
  ↓ approved                → rejected: [action]
[Step 5: Write output]
  ↓ success                 → fail: [retry/alert]
[Step 6: Notify]
  ↓
END
```

### Chi tiết từng step

#### Step [N]: [Tên rõ ràng — động từ + object]

| Property | Value |
|----------|-------|
| Action | [API call / Transform / Conditional / Wait / Human task] |
| System | [System được tác động] |
| Input | [Fields từ previous steps] |
| Output | [Fields produced] |
| Success condition | [Định nghĩa cụ thể "thành công" là gì] |
| Timeout | [X giây] |
| On timeout | [Retry / Fail / Alert] |

**Implementation note**: [Lý do design decision quan trọng, nếu có]
```

Naming convention cho workflow và steps:
```
Workflow name: [ENV]-[SYSTEM]-[PROCESS]-[ACTION]-v[MAJOR.MINOR]
Ví dụ: PROD-CRM-INVOICE-SEND-v1.2

Step names: [verb]-[object]
Ví dụ: validate-customer-data, fetch-invoice-items, send-email-notification
```

### Bước 4: Error handling per step

Mỗi step PHẢI có error handling được định nghĩa. Không có step "và nếu fail thì xem sau":

```markdown
## Error Handling Matrix

| Step | Error type | Handling strategy | Alert? |
|------|-----------|------------------|--------|
| Step 1: Validate | Validation error | Reject, log, return error response | No — expected |
| Step 2: Fetch data | API timeout | Retry 3x với backoff | No (1-2x), Yes (3x) |
| Step 2: Fetch data | 404 Not Found | Skip và log warning | No |
| Step 2: Fetch data | 500 Server Error | Retry 3x, then fail workflow | Yes |
| Step 3: Transform | Unexpected data format | Fail workflow, quarantine input | Yes |
| Step 5: Write output | Duplicate key | Idempotency check, skip | No |
| Step 5: Write output | DB connection fail | Retry 5x, then alert | Yes |

**Quarantine pattern** (cho data không thể process):
- Lưu vào quarantine table/queue
- Alert on-call với details
- Manual review procedure: [link hoặc mô tả]
```

### Bước 5: Retry strategy

Không dùng uniform retry — design theo error type:

```markdown
## Retry Strategy

### Transient errors (network, temporary unavailability)
```yaml
retry:
  max_attempts: 3
  backoff: exponential
  initial_delay: 1s
  max_delay: 30s
  jitter: true  # Tránh thundering herd
  retryable_status_codes: [429, 500, 502, 503, 504]
```

### Rate limit (429)
```yaml
retry:
  max_attempts: 3
  strategy: respect_retry_after_header
  fallback_delay: 60s  # Nếu không có Retry-After header
```

### Non-retryable errors (client errors)
- 400 Bad Request: Fail ngay, log error, không retry
- 401 Unauthorized: Alert ngay (credential issue)
- 403 Forbidden: Fail ngay, alert (permission issue)
- 404 Not Found: Tùy step — xem Error Handling Matrix

### Dead letter queue
Sau khi exhausted retries:
1. Chuyển item vào dead letter queue
2. Alert với full context (step, input, errors)
3. Manual review workflow được trigger
4. Retention: [X ngày] trong DLQ trước khi purge
```

### Bước 6: Human-in-the-loop checkpoints

Bắt buộc với blast radius High. Tùy chọn với Medium:

```markdown
## Human Checkpoints

### Khi nào cần human approval

| Condition | Checkpoint type | Approver role | SLA |
|-----------|----------------|--------------|-----|
| Amount > [threshold] | Pre-action approval | Finance manager | 4 giờ |
| Customer tier = Enterprise | Pre-action approval | Account manager | 1 giờ |
| Bulk operation > [N] records | Pre-action approval | Team lead | 24 giờ |
| Anomaly detected | Exception review | On-call | 30 phút |

### Approval flow design

```
[Automation pauses]
    ↓
[Send approval request]
    → Email với context + approve/reject links
    → Slack notification với action buttons
    ↓
[Wait — timeout: 4 giờ]
    ↓ approved           → timeout/rejected:
[Continue automation]    [Escalate / Cancel với notification]
```

### Escalation (nếu approver không respond)
- Timeout: [X giờ]
- Escalate to: [Role + contact method]
- Escalate timeout: [Y giờ]
- Final action nếu không ai respond: [Cancel / Escalate to manager / Auto-approve với log]

### Audit trail
Mọi human decision PHẢI được log:
- Who approved/rejected
- Timestamp
- Reason (optional text field)
- Workflow state at time of decision
```

### Bước 7: Tool selection

Chọn platform dựa trên requirements, không dựa trên preference:

```markdown
## Platform Selection

### Criteria matrix

| Criterion | Weight | n8n | Zapier | Power Automate | Custom (code) | Temporal |
|-----------|--------|-----|--------|----------------|---------------|---------|
| Complexity handling | 25% | | | | | |
| Error handling depth | 20% | | | | | |
| Self-hosted option | 15% | | | | | |
| Cost at volume | 15% | | | | | |
| Team familiarity | 10% | | | | | |
| Audit/compliance | 10% | | | | | |
| Human-in-loop support | 5% | | | | | |

**Recommendation**: [Platform]
**Lý do**: [Tại sao platform này phù hợp với requirements cụ thể của workflow này]
**Trade-offs được chấp nhận**: [Nhược điểm và tại sao chấp nhận được]

### Environment configuration
- Development: [local / dev environment]
- Staging: [staging environment]
- Production: [production environment]
- Secrets management: [Vault / env vars / platform secret store]
```

Quy tắc: Nếu không có platform preference, default là option đơn giản nhất satisfy requirements. Không over-engineer.

### Bước 8: Testing strategy

```markdown
## Testing Strategy

### Unit testing (business logic)
- Test từng step independently với mock inputs/outputs
- Test tất cả error branches — không chỉ happy path
- Test edge cases từ evaluation report

### Integration testing
- Test với real external systems trong staging
- Test retry behavior bằng cách mock failures
- Test human checkpoint flow end-to-end

### Load testing
- Volume: [X instances concurrent]
- Rate: [X instances/phút]
- Expected behavior: [No errors, latency < Y seconds]
- Rate limiting response: [Queue và process, không drop]

### Chaos testing
Simulate failure tại mỗi external dependency:
- [System A] down → Verify retry và DLQ behavior
- [System B] slow (timeout) → Verify timeout handling
- [System C] returns invalid data → Verify quarantine behavior

### Acceptance criteria
```
□ Happy path: [N] test instances processed thành công
□ Error handling: All error branches tested và behave as designed
□ Retry: Transient failures recover sau retry
□ DLQ: Non-retryable failures land in DLQ với correct metadata
□ Human checkpoint: Approval flow works end-to-end
□ Idempotency: Duplicate trigger không tạo duplicate output
□ Audit log: Mọi actions có timestamp và actor
```
```

### Bước 9: Monitoring và alerting

```markdown
## Monitoring & Alerting

### Metrics to track
| Metric | Normal range | Alert threshold |
|--------|-------------|----------------|
| Success rate | > 99% | < 95% trong 1 giờ |
| Processing time P95 | < [X]s | > [2X]s |
| Queue depth | < [N] | > [5N] (backpressure) |
| DLQ size | 0 | > 0 (immediate alert) |
| Checkpoint pending | < [N] | > [N] (SLA at risk) |

### Alert channels
| Severity | Channel | Who |
|----------|---------|-----|
| DLQ items | Slack #automation-alerts + PagerDuty | On-call |
| Success rate drop | Slack #automation-alerts | Automation owner |
| Processing time spike | Slack #automation-alerts | Automation owner |
| Auth/credential fail | PagerDuty | On-call + Security |

### Dashboard
Panels bắt buộc:
1. Execution overview: total / success / failed / pending (last 24h)
2. Processing time trend (P50/P95)
3. DLQ status
4. Human checkpoint queue
5. External dependency health
```

### Bước 10: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/automation-design-[process-name].md

Cấu trúc output:
1. Executive Summary — workflow mục đích, scope, platform
2. Trigger Specification
3. Workflow Diagram + Step Details
4. Error Handling Matrix
5. Retry Strategy
6. Human Checkpoints (nếu có)
7. Platform Selection với justification
8. Testing Strategy + Acceptance Criteria
9. Monitoring & Alerting
10. Deployment Checklist
11. REQ-ID reference
```

---

## Checklist trước khi submit

```
□ Evaluation report được reference (verdict = APPROVE)
□ Tất cả steps có error handling — không có step "xử lý sau"
□ Retry strategy phân biệt transient vs non-retryable errors
□ DLQ được define với retention policy
□ Human checkpoint nếu blast radius = High
□ Idempotency được xử lý ở trigger level
□ Naming convention đúng: [ENV]-[SYSTEM]-[PROCESS]-[ACTION]-v[VER]
□ Tool selection có justification
□ Testing strategy cover error branches không chỉ happy path
□ Monitoring có DLQ alert (immediate) và success rate alert
□ REQ-ID reference đầy đủ
```

---

## Lưu ý quan trọng

- **Simplicity first**: Nếu có thể solve bằng cron + script, không cần platform phức tạp
- **Idempotency là bắt buộc**: Mọi step write/update PHẢI idempotent
- **Secrets không hardcode**: Mọi credentials phải từ secret store
- **Design cho failure**: Assume mọi external call sẽ fail — design cho điều đó từ đầu
