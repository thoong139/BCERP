# Playbook: Kiểm tra cuối cùng trước production

> **Type**: Agent Skill Playbook
> **Agent**: reality-checker
> **Triggered by**: Final gate trước mỗi lần deploy lên production
> **Output**: Final Production Check Report với Go/No-Go decision

---

## Khi nào dùng playbook này

- Cổng cuối cùng bắt buộc trước production deployment
- Khi `integration-certifier` đã cấp integration certificate
- Khi `qa-lead` đã hoàn thành QA cycle
- Khi stakeholders cần sign-off chính thức
- Sau khi tất cả quality gates khác đã pass — đây là final verification

---

## Procedure

### Bước 1: Requirements Traceability Matrix Review

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3, PHASE5

Đọc req-registry.json và trích xuất danh sách tất cả REQ-IDs:
□ Tổng số requirements đã được define
□ Số requirements có impl_status = "done"
□ Số requirements có impl_status = "in_progress"
□ Số requirements có impl_status = "not_started"

Tính coverage: done / total * 100%
□ 100% done → ALL requirements implemented
□ < 100% → liệt kê requirements chưa done
□ Với requirements chưa done: chúng có trong scope của release này không?

Với mỗi REQ-ID "done":
□ Có code file reference REQ-ID này không? (grep codebase)
□ Có test coverage cho REQ-ID này không?
□ QA đã verify chưa?

Ghi nhận:
REQ_ID | STATUS | CODE_FILE | TEST | QA_VERIFIED | NOTES
```

### Bước 2: Kiểm tra tất cả quality gates đã pass

```
Compile evidence từ các QA agents khác:

□ Unit tests — đã chạy và pass?
   Minimum coverage: 80% (xem coding standards)
   Số tests: pass / fail / skip
   Thời điểm chạy gần nhất

□ Integration tests — đã chạy và pass?
   Integration-certifier certificate: READY / NEEDS WORK / FAILED
   Ngày certificate

□ API tests — nếu có api-tester involvement
   Endpoint coverage: bao nhiêu % API đã được tested?
   Contract tests pass không?

□ Performance tests — performance-benchmarker results
   API p95 latency vs. SLA targets
   Frontend Core Web Vitals status

□ Security scan — security agent findings
   Critical/High vulnerabilities còn open không?
   OWASP top 10 checked không?

□ Accessibility audit — nếu có UI
   WCAG 2.1 AA compliance checked không?

⚠️ Nếu BẤT KỲ quality gate nào chưa pass → AUTOMATIC NEEDS WORK
Không thể approve nếu integration certification còn là NEEDS WORK
```

### Bước 3: Smoke test các critical paths

```
Smoke test = quick verification critical user journeys vẫn functional.
Không phải full regression — chỉ test 5-10 critical paths quan trọng nhất.

Xác định critical paths từ business requirements:
□ Path 1: Authentication (login/logout)
□ Path 2: Core business action (ví dụ: tạo order, gửi payment, submit form)
□ Path 3: Data display (ví dụ: dashboard load, list view)
□ Path 4: Critical integration (ví dụ: payment processing end-to-end)
□ Path 5: Role-based access (admin vs. regular user)

Với mỗi critical path:
- PASS: hoàn thành không có error
- FAIL: bất kỳ step nào fail → AUTOMATIC NEEDS WORK cho toàn bộ report

Ghi nhận evidence (screenshots hoặc API response logs):
CRITICAL_PATH | STEPS | RESULT | EVIDENCE | NOTES
```

### Bước 4: Security hardening check

```
READ: .claude/references/team-expert/engineering/security-checklist.md (nếu cần)

Quick security checklist — không phải full audit, chỉ verify critical items:

□ Authentication:
   - Default passwords đã được changed chưa?
   - Admin accounts có MFA không? (production)
   - Session timeout configured chưa?

□ Secrets và configuration:
   - Không có API keys, passwords hardcoded trong code không?
   - Environment variables cho secrets đã được set đúng trên production chưa?
   - Debug mode đã được tắt chưa?

□ HTTPS:
   - SSL/TLS certificate valid không? (không expire trong 30 ngày)
   - HTTP → HTTPS redirect configured chưa?
   - HSTS header present không?

□ Security headers:
   - Content-Security-Policy set không?
   - X-Frame-Options set không?
   - X-Content-Type-Options: nosniff set không?

□ Error handling:
   - Stack traces không bị expose ra user-facing responses không?
   - Generic error messages cho auth failures không?

Mỗi item: PASS / FAIL / N/A (với explanation nếu N/A)
Bất kỳ FAIL nào → NEEDS WORK cho security section
```

### Bước 5: Monitoring active

```
Production không có monitoring = flying blind.
Kiểm tra monitoring đã được thiết lập và đang hoạt động:

Application monitoring:
□ Error tracking active? (Sentry, Datadog, etc.)
□ Performance monitoring active? (APM)
□ Custom business metrics tracked? (key conversion events)

Infrastructure monitoring:
□ CPU/Memory alerts configured?
□ Disk space alerts configured?
□ Database health monitored?

Alerting:
□ PagerDuty/OpsGenie configured cho P1 incidents?
□ Slack notifications cho deployments?
□ On-call rotation active?

Logging:
□ Application logs được collect centrally không? (ELK, CloudWatch, Datadog)
□ Log retention policy set không?
□ Sensitive data (PII, tokens) KHÔNG được log không?

Mỗi item thiếu = NEEDS WORK (không thể deploy production mà không có monitoring)
```

### Bước 6: Runbooks ready

```
Production incidents xảy ra — phải có runbooks để handle:

□ Runbook: Service down (steps để restart, rollback, escalate)
□ Runbook: High error rate (how to diagnose, common causes, fixes)
□ Runbook: Database issues (connection issues, slow queries, storage full)
□ Runbook: External service down (fallback procedures)
□ Runbook: Security incident (breach response, who to contact)

Với mỗi runbook:
- Có tồn tại không?
- Có được review bởi ít nhất 1 người không phải author không?
- Có link đến relevant dashboards/tools không?
- Có contact list (who to call) không?

Không có runbooks → YELLOW (warning, không block nhưng phải ghi nhận)
Không có runbook cho service down → NEEDS WORK
```

### Bước 7: Rollback plan tested

```
⚠️ Rollback plan chưa được test = không phải rollback plan.

□ Có rollback procedure document không?
□ Rollback đã được thực hiện trên staging environment chưa?
□ Thời gian rollback đã được đo chưa? (không chỉ estimate)
□ Database migration rollback đã được test chưa?
□ Feature flags có cho phép rollback mà không cần redeploy không?

Rollback scenarios đã được test:
□ Full application rollback (previous version)
□ Database schema rollback (nếu có migration)
□ Configuration rollback (environment variables)

Nếu rollback chưa được test → NEEDS WORK (mandatory — không thể bypass)
```

### Bước 8: Stakeholder sign-off

```
Production deployment là business decision, không chỉ là kỹ thuật.
Cần xác nhận business stakeholders đã sign-off:

□ Product Owner / Product Manager đã approve release không?
□ Technical Lead đã review và approve không?
□ QA Lead đã confirm quality gates passed không?
□ Security review (nếu có security-sensitive changes) không?

Nếu dự án có SLA/compliance requirements:
□ Compliance officer sign-off (nếu applicable)
□ Legal review (nếu có data processing changes)

Collect sign-off evidence:
ROLE | NAME | SIGN-OFF DATE | CHANNEL (email/Jira/etc.)
```

### Bước 9: Go/No-Go decision

```
Tổng hợp tất cả evidence từ Bước 1-8:

GO điều kiện (TẤT CẢ phải đúng):
□ Requirements traceability: tất cả in-scope REQ-IDs là "done"
□ Tất cả quality gates đã pass
□ Tất cả critical smoke tests PASS
□ Không có open critical/high security vulnerabilities
□ Monitoring đã được setup và active
□ Rollback plan đã được test
□ Stakeholders đã sign-off

NO-GO nếu BẤT KỲ điều nào:
□ Bất kỳ in-scope REQ-ID nào chưa "done"
□ Integration certification còn NEEDS WORK hoặc FAILED
□ Bất kỳ critical smoke test nào FAIL
□ Critical/High security vulnerability còn open
□ Monitoring chưa được setup
□ Rollback plan chưa được test

⚠️ MẶC ĐỊNH LÀ "NEEDS WORK" — chỉ GO khi bằng chứng áp đảo từ tất cả bước trên.
⚠️ Không có "partial GO" — hoặc tất cả pass hoặc NEEDS WORK.
```

### Bước 10: Output Final Production Check Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/final-production-check.md

Cấu trúc output:
1. GO / NO-GO Decision (timestamp, author)
2. Requirements Traceability Summary (% done, list chưa done)
3. Quality Gates Status (table: gate | status | date | evidence)
4. Critical Paths Smoke Test Results
5. Security Hardening Status
6. Monitoring & Alerting Status
7. Runbook Readiness
8. Rollback Plan Status
9. Stakeholder Sign-offs
10. Blocking Issues (nếu NO-GO — phải fix gì để GO)
11. Non-blocking Notes (khuyến nghị cho tương lai)
```

---

## Checklist trước khi submit

```
□ Tất cả 8 categories đã được kiểm tra (không skip bất kỳ)
□ Decision GO/NO-GO rõ ràng ở đầu với evidence
□ Mọi quality gate có status và ngày check
□ Smoke test có evidence (không chỉ "đã test")
□ Rollback plan đã được verify là TESTED (không phải "sẽ test")
□ Stakeholder sign-offs có tên + ngày + channel
□ Blocking issues có action owner cụ thể
□ REQ-IDs traceability hoàn chỉnh
```
