# Playbook: Thiết kế Feedback Management System

> **Type**: Agent Skill Playbook
> **Agent**: customer-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design NPS/CSAT/feedback system
> **Output**: Feature spec feedback module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Trong `/wf-define-features` khi cần viết feature spec cho feedback/VoC module
- Trong `/wf-design` khi cần tư vấn data model, survey logic, closed-loop workflow
- Keywords kích hoạt: NPS, CSAT, CES, feedback, survey, voice of customer, VoC, detractor, promoter

---

## Procedure

### Bước 1: Đọc context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra req-registry.json → lấy REQ-CX-NPS-* và REQ-CX-* requirements

READ: support-operations.md → Key Metrics, Customer Satisfaction section
READ: journey-mapping.md → Customer Stages (xác định touchpoints để trigger survey)

Xác định:
□ Business model (B2B / B2C): ảnh hưởng đến loại metric ưu tiên
□ Touchpoints cần đo feedback: post-purchase, post-support, periodic, in-app
□ Channels liên lạc với khách: email, SMS, in-app, web widget
□ Team nào xử lý feedback: CS team, product team, marketing?
□ Mục tiêu chính: improve retention? cải thiện product? benchmark với competitors?
□ Đang có tool feedback nào chưa? (Typeform, Qualtrics, Delighted, tự xây)
```

### Bước 2: Chọn feedback metrics phù hợp

```
3 metrics chuẩn ngành — chọn đúng theo mục tiêu:

NPS — Net Promoter Score:
  Câu hỏi: "Khả năng bạn giới thiệu [sản phẩm] cho người khác? (0-10)"
  Tính: % Promoters (9-10) − % Detractors (0-6)
  Mục tiêu: đo loyalty, churn risk, brand advocacy
  Tần suất: periodic (quarterly), hoặc sau milestone quan trọng
  Phù hợp: B2B SaaS, B2C subscription, post-onboarding

CSAT — Customer Satisfaction Score:
  Câu hỏi: "Bạn hài lòng với [trải nghiệm này] như thế nào? (1-5)"
  Tính: % ratings >= 4 / total responses
  Mục tiêu: đo satisfaction tại specific touchpoint
  Tần suất: sau mỗi interaction (support ticket, purchase, onboarding call)
  Phù hợp: post-support, post-purchase, post-training

CES — Customer Effort Score:
  Câu hỏi: "Bạn cảm thấy [tác vụ này] dễ thực hiện không? (1-7)"
  Tính: % ratings >= 6 / total responses
  Mục tiêu: đo ease-of-use, giảm friction
  Tần suất: sau khi khách hoàn thành task cụ thể
  Phù hợp: self-service, checkout flow, onboarding steps

Recommendation:
B2B SaaS → NPS (periodic) + CSAT (post-support)
B2C E-commerce → CSAT (post-purchase) + CES (checkout) + NPS (quarterly)
Marketplace → CSAT (cả buyer + seller) + NPS (periodic)
```

### Bước 3: Thiết kế Feedback Channels

```
In-app widget:
□ Trigger: sau specific action (feature used, task completed)
□ Format: micro-survey (1-2 câu), không interrupt workflow
□ Placement: bottom-right corner, dismissible
□ Opt-out: nhớ preference "Không hỏi trong 30 ngày"

Email survey:
□ Trigger: sau event (purchase, ticket closed, onboarding milestone)
□ Delay: N giờ sau event (không gửi ngay lập tức)
□ Format: embed rating trong email body (1-click) → link đến full form
□ Reminder: 1 reminder sau 3 ngày nếu chưa respond (chỉ 1 lần)
□ Unsubscribe: opt-out khỏi survey emails riêng biệt với marketing emails

SMS (nếu có mobile number):
□ Chỉ dùng cho giao dịch có giá trị cao hoặc B2C critical interactions
□ Consent riêng cho SMS survey
□ Format: link ngắn → mobile-optimized survey page

Web widget (post-session):
□ Trigger: exit intent hoặc sau N phút trên trang
□ Format: rating + optional comment
□ Session detection: không trigger nếu cùng session đã có trigger khác
```

### Bước 4: Trigger Rules

```
Xác định trigger logic để tránh survey fatigue:

TRIGGER CONDITIONS (AND logic — phải đủ tất cả):
□ Event xảy ra (purchase, ticket closed, milestone...)
□ Thời gian chờ đủ (cooldown period sau event)
□ Customer chưa nhận survey trong N ngày (global cooldown)
□ Customer không trong trạng thái at-risk (không survey khi đang có vấn đề nghiêm trọng)
□ Opt-in survey còn hiệu lực (chưa unsubscribe)

COOLDOWN RULES:
□ Global cooldown: không gửi > 1 survey / 30 ngày / khách
□ Channel cooldown: cùng channel không gửi > 1 survey / 14 ngày
□ Exception: CSAT post-support không bị global cooldown ảnh hưởng nếu customer chủ động mở ticket

SUPPRESSION LIST:
□ Khách vừa escalate ticket chưa resolved → suppress
□ Khách đang trong renewal negotiation → suppress
□ Khách đã unsubscribe survey → permanent suppress
```

### Bước 5: Survey Design

```
Nguyên tắc thiết kế survey:

□ Tối đa 3 câu hỏi (1 required + 2 optional)
□ Required: core metric question (NPS/CSAT/CES)
□ Optional 1: "Lý do chính cho điểm số này?" (free-text hoặc multiple choice)
□ Optional 2: "Có điều gì chúng tôi có thể làm tốt hơn?"

RESPONSE CATEGORIES (cho optional multiple choice):
Positive: "Hỗ trợ nhanh chóng" | "Sản phẩm dễ dùng" | "Team nhiệt tình"
Negative: "Xử lý chậm" | "Khó sử dụng" | "Thiếu tính năng" | "Giao tiếp chưa tốt" | "Khác"

MOBILE-FIRST DESIGN:
□ Survey tải trong < 2 giây
□ Touch-friendly rating input (tap, không type)
□ Tối đa 1 màn hình scroll
□ Progress indicator nếu có nhiều hơn 1 câu
```

### Bước 6: Response Categorization & Tagging

```
Automatic categorization từ response:

NPS:
□ 9-10: Promoter
□ 7-8: Passive
□ 0-6: Detractor

CSAT:
□ 4-5: Satisfied
□ 3: Neutral
□ 1-2: Unsatisfied

TAG AUTO-ASSIGNMENT từ free-text (NLP hoặc keyword matching):
□ Keyword "slow" / "chậm" → tag: performance
□ Keyword "bug" / "error" / "lỗi" → tag: product-bug
□ Keyword "price" / "expensive" / "đắt" → tag: pricing
□ Keyword "easy" / "dễ" → tag: usability-positive
□ Keyword "difficult" / "khó" / "confusing" → tag: usability-negative
□ Untagged: queue for manual review
```

### Bước 7: Closed-Loop Alerting

```
Quy trình closed-loop là quy trình QUAN TRỌNG NHẤT:
Nhận feedback xấu → alert đúng người → follow up → ghi nhận kết quả

DETRACTOR ALERT (NPS 0-6 hoặc CSAT 1-2):
□ Trigger: ngay khi submit
□ Notify: CSM phụ trách + Support Manager
□ SLA follow-up: trong 24 giờ làm việc
□ Channel follow-up: email cá nhân hóa từ CSM (không dùng template mass)
□ Ghi nhận kết quả: outcome field (Resolved / Lost / Escalated / No response)
□ Escalation: nếu 24h không có follow-up action → remind manager

PASSIVE ALERT (NPS 7-8):
□ Notify: CSM phụ trách (low priority)
□ SLA follow-up: trong 5 ngày làm việc
□ Action: outreach tìm cơ hội convert thành Promoter

PROMOTER RECOGNITION (NPS 9-10):
□ Auto-trigger: thank you email với offer join testimonial/case study program
□ Flag cho marketing team: referral / review request opportunity
□ Tag account: "advocate" trong CRM
```

### Bước 8: Trend Analysis & Reporting

```
Dashboard bắt buộc:

NPS TREND:
□ NPS score theo thời gian (line chart, 12 tháng)
□ NPS phân rã theo segment (plan type, cohort, region)
□ Distribution chart (% Promoter / Passive / Detractor theo tháng)
□ Response rate trend

CSAT BREAKDOWN:
□ CSAT per touchpoint (post-support vs post-purchase vs periodic)
□ CSAT per agent/team (support context)
□ CSAT trend theo thời gian

TEXT ANALYTICS:
□ Word cloud từ free-text responses
□ Sentiment trend (positive vs negative mentions)
□ Top themes by volume (pricing, performance, support, feature...)

CLOSED-LOOP METRICS:
□ Detractor follow-up rate (% được follow up trong SLA)
□ Detractor recovery rate (% chuyển từ detractor thành neutral/promoter)
□ Outcome distribution (Resolved / Lost / Escalated / No response)

BENCHMARKS:
□ NPS industry benchmark hiển thị cạnh score thực tế
□ Internal trend: MoM change, QoQ change
```

### Bước 9: Action Planning Workflow

```
Kết quả feedback → gắn với action items cụ thể:

INDIVIDUAL LEVEL (per response):
□ Closed-loop follow-up task (assign cho CSM/agent)
□ Link response → support ticket nếu cần escalate
□ Update account health score dựa trên NPS

AGGREGATE LEVEL (per theme):
□ Nhóm responses theo tag/theme → tạo "Feedback Theme"
□ Assign Feedback Theme cho product/CS team owner
□ Status tracking: Open → In Review → Actioned → Closed
□ Notify customers khi action đã được thực hiện (optional: "You said, we did")

PRODUCT INTEGRATION:
□ Feedback tag "product-bug" → auto-create issue trong Jira/Linear
□ Feedback tag "feature-request" → route đến product backlog với vote count
□ Monthly digest gửi cho Product team: top themes + volume
```

### Bước 10: Output — Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/[sys]/cx/feedback-management.md

Cấu trúc output (Feature Spec):
1. Feature Overview (mục tiêu, scope, personas)
2. Feedback Metrics Selection (NPS/CSAT/CES rationale)
3. Survey Design (câu hỏi, format, channel)
4. Trigger Rules (conditions + cooldown logic)
5. Response Categorization (auto-tagging logic)
6. Closed-Loop Process (alert → follow-up → outcome)
7. Trend Analysis & Dashboard requirements
8. Action Planning workflow
9. Integration points (CRM, support system, product tools)
10. Non-functional requirements (response rate target, data retention)
11. REQ-ID mapping (mỗi section → REQ-CX-NPS-NNN)
12. Open questions cho stakeholders
```

---

## Checklist trước khi submit

```
□ Metric selection có justification rõ (tại sao NPS không phải CSAT, hoặc cả hai)
□ Trigger rules có cooldown logic (tránh survey fatigue)
□ Closed-loop quy trình rõ ràng: ai nhận alert, SLA follow-up là bao lâu
□ Detractor alert < 24 giờ làm việc (không được để quá 48h)
□ Text analytics / categorization đã thiết kế
□ Dashboard: NPS trend, CSAT breakdown, closed-loop metrics
□ Action planning workflow đã có (individual + aggregate)
□ Integration với CRM, support, product đã noted
□ Suppression list và opt-out mechanism đã có
□ Mỗi feature section có REQ-ID tương ứng REQ-CX-NPS-NNN
```
