# Playbook: Review Paid Media Module Implementation

> **Type**: Agent Skill Playbook
> **Agent**: paid-media-expert
> **Triggered by**: /wf-implement-feature khi review code của paid media / ad tracking modules
> **Output**: Paid media implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của paid media module
- Khi cần validate implementation từ paid media domain perspective
- Khi cần check pixel accuracy, CAPI setup, attribution logic, budget enforcement
- Khi cần verify PII compliance trong tracking

---

## Procedure

### Bước 1: Xác định module đang review

```
Identify module type:
□ Campaign Management → check hierarchy, state machine, budget cap logic
□ Budget Management → check cap enforcement, approval workflow, pacing alerts
□ Attribution / ROAS Tracking → check event firing, deduplication, ROAS calculation
□ Pixel / Tag Implementation → check event accuracy, PII compliance, consent gate
□ CAPI (Conversions API) → check server-side events, dedup, match quality
□ Audience Management → check PII hashing, audience refresh logic
□ Reporting Dashboard → check data accuracy, ROAS calculation, refresh cadence
□ Automated Rules Engine → check trigger logic, audit log, conflict resolution
```

### Bước 2: Review theo module type

**Campaign Management:**
```
□ Campaign hierarchy đúng không? (Account → Campaign → AdSet → Ad — mirror platform structure)
□ Status state machine đúng không?
  Valid: Draft → Review → Approved → Scheduled → Active → Paused → Completed → Archived
  Invalid transitions phải bị reject (không được nhảy từ Draft → Active bỏ qua Approved)
□ Budget approval workflow: Thresholds đúng không? Có bypass không?
□ Hard budget cap: Code CÓ gọi platform API để pause khi đạt budget limit không?
□ Budget pacing alerts: 50%/80%/95% thresholds có trigger notification không?
□ Campaign ID: Có lưu external_campaign_id sau khi sync lên platform không?
□ Timezone handling: start_date/end_date có convert đúng timezone của platform không?
□ Dayparting: Ad schedule có được apply đúng không? (UTC conversion)
```

**Pixel / Tag Implementation (Client-Side):**
```
□ Base pixel fire: Có fire trên EVERY page không? (kể cả error pages)
□ Event naming: Có follow event taxonomy đã spec không? (không tự đặt tên mới)
□ Conversion value: purchase event có pass revenue amount không?
□ event_id: Mỗi event có unique event_id không? (cần cho CAPI dedup)
□ Double-firing: Event có fire nhiều hơn 1 lần cho cùng 1 action không?
  Ví dụ: purchase event fire 2 lần do page redirect / SPA routing issue
□ Consent gate: Pixel có bị BLOCK khi user không consent không?
  Bắt buộc: Nếu user reject cookies → Không fire tracking pixels
□ GTM dataLayer: push() có format đúng không? Có missing required fields không?
□ PII in events: KHÔNG được pass raw email/phone/name trong event parameters
  Tìm kiếm: event_data.user_email, properties.email, userData.phone → nếu có = BUG
```

**CAPI (Meta Conversions API / Server-Side Tracking):**
```
□ Event payload có đầy đủ required fields không?
  Bắt buộc: event_name, event_time (Unix timestamp), event_source_url
  Recommended: user_data.em (hashed email), user_data.ph (hashed phone), fbc, fbp

□ PII Hashing: email và phone phải được hash SHA-256 TRƯỚC KHI gửi CAPI
  Test: Hash("test@example.com") = "55502f40dc8b7c769880b10874abc9d0a2b...
  Check: Không gửi raw email/phone qua CAPI dưới bất kỳ hình thức nào

□ Deduplication với pixel:
  event_id trong CAPI PHẢI = event_id trong pixel event cho cùng 1 conversion
  Thời gian CAPI phải đến Meta trong vòng 24 giờ sau pixel event

□ Conversion timestamp: event_time có dùng Unix timestamp (seconds, không phải milliseconds) không?

□ Event Match Quality (EMQ):
  Gửi càng nhiều match keys càng tốt: em + ph + fn + ln + ct + st + zp + country + fbc + fbp
  Target EMQ ≥ 7/10 (check trong Meta Events Manager sau khi deploy)

□ Error handling: Nếu CAPI call fail → có retry logic không? (exponential backoff)
□ Rate limiting: Meta CAPI limit 200 calls/hour per app — có queue/batching không?
  Bắt buộc nếu volume cao: batch events (tối đa 50 events per call)

□ Google Enhanced Conversions:
  Conversion data (hashed email) có được gửi theo Google spec không?
  Có pass order_id / transaction_id để dedup không?
```

**Attribution & ROAS Calculation:**
```
□ Deduplication key: Có dedup_key (order_id / lead_id) unique per conversion không?
□ Cross-platform dedup: 1 conversion chỉ được attributed 1 lần — logic này có hoạt động không?
□ ROAS formula: ROAS = attributed_revenue / ad_spend
  □ Attributed revenue chỉ tính conversions với attributed = true
  □ Ad spend kéo từ platform API theo đúng date range và dimension (campaign/adset/ad)
□ Spend data pull: Có xử lý timezone offset không? (platform timezone vs local timezone)
□ Attribution window: Code có filter conversions theo đúng attribution window không?
□ Historical backfill: Khi thay đổi attribution model, historical data có được recalculate không?

Platform ROAS vs Actual ROAS:
□ Có report cả 2 không? (platform-reported thường cao hơn do view-through + overlap)
□ Discrepancy được note rõ trong UI không? (tránh confuse stakeholders)
```

**Budget Enforcement:**
```
□ Hard cap logic: Khi campaign spend đạt 100% budget → code CÓ gọi API để pause không?
  Test case: Budget = $1000, spend = $1001 → campaign status phải = paused
□ Daily budget guard: Nếu daily spend × remaining days > lifetime budget → tự điều chỉnh
□ Overspend handling: Nếu platform overdelivers vượt cap (happen với Google Ads) → alert + log
□ Budget approval bypass: Không có code path nào cho phép skip approval workflow
□ Concurrent update: Race condition khi 2 người cùng edit budget → optimistic locking?
□ Audit trail: Mọi budget change phải log: user_id, old_value, new_value, timestamp, reason
```

**Automated Rules Engine:**
```
□ Rule conditions: Logic đúng không? (ROAS < 1.5 vs ROAS ≤ 1.5 — ranh giới quan trọng)
□ Rule actions: Pause / bid adjustment có được apply đúng không?
□ Audit log: MỌI automated action phải log rule_id, trigger_condition, action_taken, timestamp, before_after_values
□ Rule conflict: Nếu 2 rules trigger cùng lúc → priority resolution có hoạt động không?
□ Manual override: Sau khi rule auto-pause, human có thể resume không? (không bị re-paused ngay lập tức)
□ Rule scheduling: Cron jobs có chạy đúng interval không? (15 phút, theo spec)
```

### Bước 3: PII Compliance Deep Check

```
BẮT BUỘC cho mọi paid media modules — đây là compliance check quan trọng nhất.

Search trong codebase:
□ Tìm: user.email, user.phone, customer.name, lead.email → check có bị pass vào tracking calls không?
□ Tìm: trackEvent(, pixel.track(, fbq(, gtag( → check parameters có chứa PII không?
□ Tìm: fetch('/capi, axios.post('/conversions → check payload có hash PII trước không?

Hashing verification:
□ Algorithm: SHA-256 (không phải MD5, SHA-1)
□ Preprocessing: lowercase + trim whitespace TRƯỚC KHI hash
  email: toLowerCase().trim() → sha256()
  phone: digits only (strip spaces, dashes, parentheses) → sha256()
□ Test vector: sha256("test@example.com") = "55502f40dc8b7c769880b10874abc9d0a2fb46a53c99a28979eba42e7a50d5b5"

Consent gate:
□ Tracking calls có check consent_status TRƯỚC KHI fire không?
□ Nếu user.consent = false → NO tracking events (zero tolerance)
□ Có unit test cover case: user consent false → events không fire không?

Data retention:
□ Có TTL / expiry logic cho raw conversion event data không? (13 tháng GDPR)
□ Anonymization: IP addresses có bị truncate không? (remove last octet)
```

### Bước 4: Performance & Reliability Check

```
□ API calls to ad platforms: Có timeout setting không? (recommended: 5–10 giây)
□ Retry logic: Transient errors (5xx) có được retry không? (exponential backoff, max 3 retries)
□ Circuit breaker: Nếu platform API down → có fallback không? (queue locally, retry later)
□ Rate limiting compliance:
  Meta Marketing API: 200 calls/hour per app → có rate limiter không?
  Google Ads API: Theo developer token tier → có handling không?
  TikTok Ads API: 100 calls/minute → có queue không?
□ Batch processing: CAPI events có được batch không? (50 events/call thay vì 1 event/call)
□ Pixel performance: Tracking scripts có bị load synchronously (blocking) không?
  → Bắt buộc: async/defer loading, không block page render
□ Database queries: ROAS calculation queries có index đúng columns không?
  → Check: campaign_id, adset_id, event_timestamp, platform được indexed
□ Bulk data import: Spend data pull từ APIs có chạy async không? (không block user requests)
```

### Bước 5: Integration Accuracy Check

```
□ Platform API credentials: Không được hardcode — phải dùng environment variables / secrets manager
□ Access token refresh: OAuth tokens có auto-refresh trước khi expire không?
  Meta tokens expire sau 60 ngày → có refresh mechanism không?
□ Platform ID mapping: external_campaign_id, external_adset_id, external_ad_id có được lưu và maintain không?
□ Spend data reconciliation: Sau khi kéo từ API, có validate total spend match với platform dashboard không?
□ Conversion count reconciliation: System count vs platform count — gap có được monitored không?

Ad Creative specs validation (nếu có creative upload):
□ Meta image: max 30MB, min 600×600px, <20% text
□ Meta video: max 4GB, 9:16 ratio recommended, 4 giây minimum
□ Google RSA: max 30 headlines (15 required), max 4 descriptions
□ TikTok: Vertical video only (9:16), max 500MB
□ System có validate specs trước khi upload không? (tránh rejected creatives)
```

### Bước 6: Output — Review Report

```markdown
# Paid Media Implementation Review: [Module Name]

## Compliance Status: ✅ PASS / ❌ FAIL / ⚠️ NEEDS ATTENTION

## Critical Issues (chặn go-live)
- [ ] [Issue]: [File/Function location] → [Required fix]
  WHY: [Lý do đây là blocker — privacy violation / incorrect data / financial risk]

## Important Issues (sửa trước sprint tiếp theo)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## PII Compliance Checklist
| Check                        | Status | Notes                          |
|------------------------------|--------|--------------------------------|
| Không pass raw email vào events | ✅/❌  |                                |
| SHA-256 hashing đúng          | ✅/❌  |                                |
| Consent gate hoạt động        | ✅/❌  |                                |
| IP anonymization bật          | ✅/❌  |                                |
| Data retention policy         | ✅/❌  |                                |

## Tracking Accuracy Checklist
| Check                              | Status | Notes |
|------------------------------------|--------|-------|
| Pixel fire trên tất cả pages       | ✅/❌  |       |
| event_id unique per conversion     | ✅/❌  |       |
| CAPI dedup với pixel               | ✅/❌  |       |
| Conversion value được pass         | ✅/❌  |       |
| Không double-fire                  | ✅/❌  |       |

## Budget Enforcement Checklist
| Check                              | Status | Notes |
|------------------------------------|--------|-------|
| Hard cap pause logic               | ✅/❌  |       |
| Budget approval workflow           | ✅/❌  |       |
| Pacing alerts (50/80/95%)          | ✅/❌  |       |
| Budget change audit log            | ✅/❌  |       |

## Performance Concerns
[List API timeout, retry logic, rate limiting issues nếu có]

## Sign-off
□ PII compliance: OK / ISSUE
□ Pixel/CAPI accuracy: OK / ISSUE
□ Attribution logic: OK / ISSUE
□ Budget enforcement: OK / ISSUE
□ API security (no hardcoded credentials): OK / ISSUE
```

---

## Checklist trước khi submit

```
□ PII deep check đã được thực hiện (search codebase cho raw email/phone trong tracking)
□ CAPI deduplication logic đã verified (event_id match giữa pixel và server-side)
□ Budget hard cap enforcement đã tested (không chỉ đọc code mà trace execution path)
□ Consent gate đã checked (zero tracking khi user không consent)
□ API credentials không bị hardcode
□ Rate limiting cho platform APIs đã được addressed
□ Critical issues được phân biệt rõ ràng với suggestions
□ WHY được giải thích cho mỗi critical issue (privacy, financial, data accuracy risk)
```
