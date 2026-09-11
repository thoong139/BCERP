# Playbook: Review Automation Risk

> **Type**: Agent Skill Playbook
> **Agent**: automation-architect
> **Triggered by**: Review automation trước khi deploy lên production
> **Output**: Automation risk review report tại `.mc-data/docs/phase3-architecture/automation-risk-[process-name].md`

---

## Khi nào dùng playbook này

- Bắt buộc trước khi deploy automation lên production lần đầu
- Khi automation có significant changes (new steps, new external dependencies, logic changes)
- Khi incident xảy ra và cần review lại risk posture
- Định kỳ quarterly cho automations có blast radius High/Medium

**Quy tắc**: Production deployment bị block cho đến khi risk review report được approve.

---

## Procedure

### Bước 1: Blast radius analysis — worst-case failure impact

Đây là phần quan trọng nhất. Phân tích worst case, không optimistic case:

```
INPUT: Design document từ design-workflow-automation.md
       Code/config của automation đang được review
FALLBACK: tra .claude/references/path-registry.md → PHASE3
READ: architecture-patterns.md

Câu hỏi cần trả lời:
□ Nếu automation chạy với corrupt data, điều tệ nhất có thể xảy ra là gì?
□ Nếu automation loop vô hạn, hậu quả là gì?
□ Nếu automation xử lý toàn bộ data trước khi fail, có rollback không?
□ Nếu external API trả về sai data, automation có detect được không?
```

```markdown
## Blast Radius Analysis

### Scenario 1: Silent logic error (automation chạy nhưng output sai)
- Affected records: [Tất cả / % subset — điều kiện nào?]
- Detection time: [Ngay lập tức / X giờ / Chỉ khi user phát hiện]
- Irreversible data changes: [Có / Không / Partial]
- Downstream systems affected: [List]
- Business impact: [Mô tả cụ thể]
- Recovery effort: [X giờ để detect + Y giờ để fix]

### Scenario 2: Runaway execution (duplicate processing)
- Trigger: [Conditions dẫn đến duplicate runs]
- Duplicate output: [X bản copies / X emails gửi / X records tạo]
- Detection: [Monitor có alert không?]
- Mitigation: [Idempotency đã implement chưa?]

### Scenario 3: Rate limit exhaustion (ảnh hưởng shared systems)
- Rate limits của [each external system]
- Worst case consumption: [X requests/phút]
- Impact lên other consumers nếu automation exhaust limits
- Circuit breaker có không?

### Scenario 4: Cascade failure (downstream propagation)
- Nếu [System A] nhận bad data từ automation
- [System A] sẽ propagate đến [System B, C]?
- Contamination scope: [Isolated / Bounded / Unbounded]

### Blast Radius Summary
| Scenario | Likelihood | Impact | Detected | Recoverable |
|----------|-----------|--------|----------|------------|
| Silent logic error | [L/M/H] | [L/M/H] | [Auto/Manual/Late] | [Y/Partial/N] |
| Runaway execution | [L/M/H] | [L/M/H] | [Auto/Manual/Late] | [Y/Partial/N] |
| Rate exhaustion | [L/M/H] | [L/M/H] | [Auto/Manual/Late] | [Y/Partial/N] |
| Cascade failure | [L/M/H] | [L/M/H] | [Auto/Manual/Late] | [Y/Partial/N] |

**Overall blast radius**: [High / Medium / Low]
**Rationale**: [Lý do đánh giá]
```

### Bước 2: Data quality sensitivity

```markdown
## Data Quality Sensitivity

### Data types được xử lý
| Data type | Sensitivity | Validation in place? | Corruption impact |
|-----------|------------|---------------------|------------------|
| [Customer PII] | High | [Yes/Partial/No] | [GDPR violation, customer harm] |
| [Financial records] | High | [Yes/Partial/No] | [Audit failure, financial loss] |
| [Order data] | Medium | [Yes/Partial/No] | [Wrong fulfillment, refunds] |
| [Internal logs] | Low | N/A | [Minimal] |

### Input validation review
Cho mỗi data field được consume:
- [ ] Type validation (string, number, date)
- [ ] Required vs optional enforced
- [ ] Length/range bounds checked
- [ ] Format validation (email, phone, date format)
- [ ] Business rule validation (amount > 0, status in valid set)
- [ ] Cross-field validation (end_date > start_date)

**Gaps identified**: [List fields thiếu validation]

### Output data quality
- Có sanitize PII trước khi log không? [Yes / No → Risk]
- Có mask sensitive fields trong error messages không? [Yes / No → Risk]
- Có validate output trước khi write không? [Yes / No → Risk]

### Data lineage
Với mỗi data write:
- Source: [Input field → transformation → output field]
- Audit trail: [Timestamp, actor, old value, new value được log?]
- Retention: [Bao lâu lưu audit log?]
```

### Bước 3: Idempotency verification

```markdown
## Idempotency Verification

### Idempotency design review

Với mỗi step có side effects (write, send, update):

| Step | Idempotency mechanism | Tested? | Notes |
|------|----------------------|---------|-------|
| [Create record] | Unique constraint on [key] | [Y/N] | |
| [Send email] | Email_sent flag + check before send | [Y/N] | |
| [Call external API] | Request dedup by [idempotency_key] | [Y/N] | |
| [Update status] | Conditional update: only if current_status = X | [Y/N] | |

### Deduplication mechanism

Trigger-level:
- Idempotency key: [field hoặc hash]
- Storage: [Redis / DB / Platform]
- TTL: [X giờ]
- Behavior on duplicate: [Skip với log / Return cached result / Error]

Step-level:
- Mỗi step có idempotency key riêng không?
- Nếu step 3 success nhưng step 4 fail → retry từ step 4 (không re-run step 3)?
- Checkpoint/resume mechanism: [Có / Không / Cần build]

### Test scenarios cho idempotency
- [ ] Duplicate trigger trong 1 phút: Expected behavior tested
- [ ] Retry sau partial failure: Expected behavior tested
- [ ] Network timeout retry: Expected behavior tested — không double-send
```

### Bước 4: Race condition risks

```markdown
## Race Condition Analysis

### Concurrent execution risks

| Scenario | Possible? | Current protection | Sufficient? |
|----------|----------|-------------------|------------|
| 2 automation instances process same record | [Y/N] | [Mutex / DB lock / None] | [Y/N] |
| Automation reads stale data | [Y/N] | [Cache TTL / Read-after-write / None] | [Y/N] |
| Automation và manual process conflict | [Y/N] | [Optimistic lock / None] | [Y/N] |

### Database-level risks
- Transactions sử dụng đúng isolation level không? [Read Committed / Repeatable Read / Serializable]
- N+1 queries có thể gây lock contention không?
- Long-running transactions block other operations không?

### State machine integrity
Nếu automation update state/status:
- Cho phép state transitions: [A→B, A→C, B→D, ...]
- Không cho phép: [B→A (backward), D→B (skip), ...]
- Guard implementation: [Check trước mỗi write / DB constraint / None]

### Mitigation cho race conditions identified
| Race condition | Mitigation | Implementation complexity |
|----------------|-----------|--------------------------|
| [Race 1] | [Distributed lock với TTL X] | [Low/Med/High] |
| [Race 2] | [Optimistic locking] | [Low/Med/High] |
```

### Bước 5: External dependency risks

```markdown
## External Dependency Risk Assessment

### Dependency inventory

| Dependency | Type | Owner | SLA | Auth method | Last auth rotation |
|-----------|------|-------|-----|------------|-------------------|
| [API A] | External API | [Vendor] | 99.9% | API key | [Date] |
| [System B] | Internal service | [Team] | 99.5% | Service token | [Date] |
| [DB C] | Database | [DBA team] | 99.95% | Password | [Date] |

### Per-dependency risks

#### [Dependency Name]
- **Breaking change risk**: [High — no versioning / Low — stable versioned API]
- **Availability risk**: [SLA + historical uptime]
- **Auth expiry risk**: [Token TTL, rotation process, who gets alerted]
- **Rate limit**: [X requests/minute — headroom = Y%]
- **Monitoring**: [Health check in place? / None]

### Cascading failure mitigation

| Dependency | Circuit breaker? | Fallback behavior | Timeout |
|-----------|-----------------|------------------|---------|
| [API A] | [Yes — threshold N failures] | [Queue và retry] | [5s] |
| [System B] | [No → Risk] | [None → Risk] | [30s] |

**Missing mitigations**: [List dependencies không có circuit breaker hoặc fallback]

### Secret rotation risk
- Credentials đang expire khi nào? [Dates]
- Alert 30 ngày trước expiry: [Có / Không → cần setup]
- Rotation procedure có document không? [Link / Not documented → Risk]
- Zero-downtime rotation possible? [Yes / No — sẽ có downtime X phút]
```

### Bước 6: Permission scope — least privilege

```markdown
## Permission Audit

### Current permissions inventory

| System | Permissions granted | Permissions needed | Over-privileged? |
|--------|--------------------|--------------------|-----------------|
| [System A] | [Read, Write, Delete] | [Read, Write] | [Yes — Delete không cần] |
| [System B] | [Admin] | [Read only] | [Yes — should be read-only] |
| [DB C] | [SELECT, INSERT, UPDATE, DELETE] | [SELECT, INSERT, UPDATE] | [Yes — DELETE không cần] |

### Least privilege compliance
- [ ] Mọi permissions được review và đúng mức tối thiểu
- [ ] Admin/superuser credentials KHÔNG được dùng
- [ ] Read-only credentials cho read-only steps
- [ ] Permissions được grant theo role, không theo user
- [ ] Service account được isolate (không share với con người hoặc services khác)

### Over-privileged actions to fix
| System | Current | Should be | Action |
|--------|---------|-----------|--------|
| | | | |

### Network access
- Automation có cần access toàn bộ network hay chỉ specific endpoints?
- IP allowlist có không?
- VPN/private network required?
```

### Bước 7: Rollback plan

```markdown
## Rollback Plan

### Rollback triggers
| Condition | Decision maker | Rollback SLA |
|-----------|---------------|-------------|
| Error rate > [X]% trong 30 phút | On-call + Automation owner | 15 phút |
| Data inconsistency detected | DBA + Automation owner | Immediate |
| External complaints về wrong data | Customer Success + Manager | Immediate |

### Rollback procedure

#### Level 1: Pause automation (non-destructive)
```
1. Disable trigger (không nhận input mới)
2. Let in-flight executions complete hoặc timeout
3. Verify queue drained
Timeline: 5-15 phút
```

#### Level 2: Rollback data changes (nếu cần)
```
1. Identify affected records (timeframe + automation run ID)
2. Verify rollback script trên staging trước
3. Run rollback với DBA oversight
4. Verify data consistency sau rollback
Timeline: 30 phút - 4 giờ tùy volume
```

**Rollback script có sẵn**: [Yes — link / No → Cần viết trước deploy]

#### Level 3: Emergency kill switch
- Kill switch location: [UI / CLI command / Config flag]
- Who can trigger: [Role]
- Effect: [Dừng ngay lập tức, không drain queue]
- Recovery từ kill switch: [Procedure]

### Không rollback-able
Document rõ những gì KHÔNG thể rollback:
- [Emails đã gửi]
- [Webhooks đã fire đến third-party]
- [External API calls đã commit]

Với mỗi item không rollback-able: có compensating action không?
```

### Bước 8: Manual override capability

```markdown
## Manual Override

### Override scenarios
| Scenario | Override mechanism | Time to activate |
|----------|------------------|-----------------|
| Automation stuck | [Admin UI / CLI / DB flag] | [X phút] |
| Need to process single item manually | [Bypass flag per item] | [X phút] |
| Emergency process all pending manually | [Bulk export + manual flow] | [X giờ] |

### Override process documentation
- [ ] Override procedure viết thành runbook
- [ ] Team đã được training
- [ ] Override không require automation knowledge — operations team có thể làm

### Graceful degradation
Nếu automation không available:
- Manual fallback process: [Described và documented]
- Capacity: [Operations team có capacity handle manually không?]
- SLA degradation: [Response time impact khi manual]
- Communication: [Ai notify khi switch to manual?]
```

### Bước 9: Risk summary và sign-off

```markdown
## Risk Summary

### Risk matrix

| Risk | Likelihood | Impact | Mitigation | Residual risk |
|------|-----------|--------|-----------|--------------|
| Silent logic error | [L/M/H] | [L/M/H] | [Audit log + sample review] | [L/M/H] |
| Data corruption | [L/M/H] | [L/M/H] | [Validation + idempotency] | [L/M/H] |
| Runaway execution | [L/M/H] | [L/M/H] | [Rate limiting + DLQ] | [L/M/H] |
| Credential expiry | [L/M/H] | [L/M/H] | [Alert 30d before expiry] | [L/M/H] |
| External API change | [L/M/H] | [L/M/H] | [Versioning + contract tests] | [L/M/H] |
| Race condition | [L/M/H] | [L/M/H] | [DB locks + idempotency] | [L/M/H] |

**Overall residual risk**: [High / Medium / Low]

### Critical issues (BLOCK deployment)
Issues phải fix trước khi deploy:
1. [Issue 1 — ví dụ: No idempotency on email send step]
2. [Issue 2 — ví dụ: Admin credentials being used]
3. [Issue 3 — ví dụ: No rollback script for data changes]

### Non-critical issues (fix in next sprint)
Issues không block nhưng cần track:
1. [Issue 1]
2. [Issue 2]

### Deploy recommendation

**Status**: [APPROVED / BLOCKED]

**Nếu BLOCKED**: Resolve [N] critical issues trước khi re-review.

**Nếu APPROVED**:
- Deploy trong business hours: [Yes — để manual response nếu cần]
- Pilot volume: [Start với X% volume / Full volume OK]
- Monitoring tăng cường sau deploy: [48 giờ]
- Post-deploy review: [1 tuần sau deploy]

**Sign-off required from**:
- [ ] Automation owner: [Role]
- [ ] Business owner: [Role]
- [ ] Security review (nếu handles PII/financial): [Role]
```

---

## Checklist trước khi submit

```
□ Blast radius có tất cả 4 scenarios: logic error, runaway, rate exhaustion, cascade
□ Idempotency verify cho mọi step với side effects
□ Race condition analysis hoàn thành
□ Mọi external dependencies có timeout và circuit breaker
□ Permissions audit — không có over-privileged access
□ Rollback script tồn tại cho data changes (không chỉ "có thể rollback")
□ Manual override documented và team được train
□ Critical issues list rõ ràng — không ambiguous
□ Deploy recommendation có conditions cụ thể
□ Sign-off requirements xác định rõ
```

---

## Lưu ý quan trọng

- **Worst case, not best case**: Risk review phải analyze worst case scenarios
- **No silent failures**: Mọi failure mode phải có detection mechanism
- **Privileged access**: Nếu service account có admin quyền, đó là critical issue bất kể context
- **Governance không optional**: Risk review sign-off không phải formality — là accountability checkpoint
