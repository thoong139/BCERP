# Playbook: Audit Existing Customer Support Systems

> **Type**: Agent Skill Playbook
> **Agent**: customer-expert
> **Triggered by**: /wf-legacy-scan khi có customer support tools hoặc CX systems hiện có
> **Output**: `.mc-data/docs/phase1-business/customer-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Customer Support / CX
- Khi cần đánh giá current state trước khi thiết kế lại
- Khi cần tìm gaps và pain points của hệ thống hiện tại
- Keywords kích hoạt: Zendesk, Freshdesk, email queue, support portal, helpdesk đang dùng

---

## Procedure

### Bước 1: Inventory thu thập

```
Cần thu thập từ stakeholders hoặc codebase / config hiện có:

TOOLS & PLATFORMS:
□ Helpdesk tool chính: Zendesk / Freshdesk / Intercom / HubSpot Service / tự xây?
□ Live chat: Intercom / Crisp / Tawk.to / trong helpdesk?
□ Phone/Call: Aircall / RingCentral / tổng đài nội bộ?
□ Email support: dedicated mailbox nào? Ai quản?
□ Knowledge base: tích hợp trong helpdesk hay tách riêng?
□ CRM có connect không? Nếu có → dữ liệu nào được sync?
□ CSAT/NPS tool: Delighted / Qualtrics / form thủ công / trong helpdesk?

TEAM & PROCESS:
□ Bao nhiêu support agents? L1 / L2 / L3 phân chia thế nào?
□ Giờ hỗ trợ: business hours (8x5) hay 24/7?
□ Ngôn ngữ hỗ trợ?
□ Có CSM team riêng không? Hay support agent kiêm luôn?
□ Escalation process hiện tại là gì?

VOLUME & LOAD:
□ Số ticket / ngày hoặc / tháng (trung bình)?
□ Channel phân bổ: % email / % chat / % phone?
□ Peak hours thường xảy ra khi nào?
□ Ticket backlog hiện tại: bao nhiêu tickets đang open?
```

### Bước 2: Đo baseline metrics hiện tại

```
READ: support-operations.md → Key Metrics, SLA Framework

Thu thập metrics hiện có (nếu có tool analytics):

RESPONSE TIME:
□ Average First Response Time: ___ phút/giờ
□ Breakdown by channel (email / chat / phone)
□ Breakdown by priority (nếu có priority system)
□ % tickets respond trong SLA: ___ %

RESOLUTION:
□ Average Resolution Time (ART): ___ giờ/ngày
□ FCR — First Contact Resolution rate: ___ % (mục tiêu ngành > 70%)
□ Ticket reopen rate: ___ % (mục tiêu < 5%)
□ Escalation rate: ___ % (tickets phải escalate lên L2/L3)

SATISFACTION:
□ CSAT score hiện tại: ___ /5 (hoặc ___ %)
□ CSAT response rate: ___ %
□ NPS score (nếu đang đo): ___
□ Detractor rate: ___ %

KNOWLEDGE BASE:
□ Số articles hiện có: ___
□ Deflection rate (search → không submit ticket): ___ %
□ Article outdated rate (chưa update > 6 tháng): ___ %

AGENT PERFORMANCE:
□ Average tickets per agent per day: ___
□ Agent satisfaction / attrition rate (nếu có)
□ Utilization rate (% thời gian active xử lý tickets)
```

### Bước 3: Gap Analysis — Ticket Lifecycle

```
So sánh current state vs best practice:

TICKET CREATION:
□ Customers có thể tự submit ticket dễ không? (web portal, in-app, email)
□ Triage tự động đang có không? (auto-categorize, auto-priority)
□ Acknowledgement email được gửi ngay không?
□ Có SLA commitment thông báo cho khách không?

ASSIGNMENT:
□ Assignment tự động hay manual? Logic routing là gì?
□ Có skill-based routing không?
□ Unassigned ticket queue được review tần suất nào?

IN PROGRESS:
□ Agents có access knowledge base trực tiếp không?
□ Internal notes / collaboration giữa agents đang dùng tool gì?
□ Có canned responses / templates không?
□ Có visibility vào customer history (previous tickets, purchases)?

ESCALATION:
□ Escalation rules được document rõ không?
□ Escalation tự động hay chỉ manual?
□ Thông báo escalation đến đúng người không?

CLOSURE:
□ CSAT được collect không? Trigger khi nào?
□ Closed-loop follow-up cho detractors?
□ Root cause analysis được làm không? Tần suất?
```

### Bước 4: Gap Analysis — Customer Success (nếu có CS team)

```
READ: success-framework.md → Health Score Framework, Risk Identification

□ Có customer health score không? Được tính bằng gì?
□ At-risk customers được identify proactively hay chỉ khi churn?
□ Onboarding playbook được document và follow không?
□ CSM có visibility vào support ticket history không?
□ QBR (Quarterly Business Review) đang được làm không?
□ Expansion signals được track không? (upsell, cross-sell triggers)
□ Churn indicators: login drop, usage decline được alert không?
```

### Bước 5: Gap Analysis — Knowledge Base Quality

```
□ Có knowledge base không? Khách có thể tự truy cập?
□ Cấu trúc KB: có phân loại theo category rõ ràng?
□ Search trong KB có hoạt động tốt không?
□ Bao nhiêu % câu hỏi common được covered bởi KB articles?
□ Last updated date của articles: có bài nào > 6 tháng chưa review?
□ Có process tạo article mới khi gặp câu hỏi lặp lại?
□ Analytics KB: có đo deflection rate, article views, search no-result không?
□ Multilingual support nếu cần?
```

### Bước 6: Gap Analysis — Integration & Data

```
CRM INTEGRATION:
□ Customer profile trong support tool có sync với CRM không?
□ Agent có xem được: deal stage, account value, CSM owner từ support tool?
□ Ticket history có visible trong CRM contact record không?
□ Billing information có accessible không?

INTERNAL COLLABORATION:
□ Tickets cần engineering → có bug tracker integration? (Jira, Linear)
□ Feature requests từ tickets → có route đến product team không?
□ Slack/Teams alerts cho urgent tickets có hoạt động?

DATA QUALITY:
□ Ticket categorization có nhất quán không? (có người tag lung tung?)
□ Duplicate tickets: có merge không? Tỷ lệ duplicate bao nhiêu?
□ Customer data: email, tên có đầy đủ không?
□ SLA data: có đủ để báo cáo compliance không?
```

### Bước 7: Process Documentation Assessment

```
□ Escalation runbook đã được viết và cập nhật?
□ Onboarding guide cho support agents mới?
□ SLA policies được share với khách không?
□ Incident response process (khi có outage ảnh hưởng nhiều khách)?
□ Refund/return policy được document rõ không?
□ Agent empowerment limits: agent được approve refund đến bao nhiêu tiền?
```

### Bước 8: Output — As-Is Analysis Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/customer-as-is-analysis.md

Cấu trúc output:

# Customer Support As-Is Analysis

## Executive Summary
[3-5 dòng: tình trạng tổng quát, điểm mạnh chính, gaps nghiêm trọng nhất]

## Current State

### Tool Stack
| Tool | Mục đích | Tình trạng | Vấn đề chính |
|------|---------|-----------|--------------|
| [Tool] | [Purpose] | Active/Unused | [Issues] |

### Channel Distribution
| Channel | % Volume | Avg Response Time | SLA Compliance |
|---------|---------|------------------|----------------|
| Email | % | | |
| Chat | % | | |
| Phone | % | | |

### Performance Baseline
| Metric | Hiện tại | Target ngành | Gap |
|--------|---------|-------------|-----|
| First Response Time | | | |
| Resolution Time | | | |
| FCR Rate | | | |
| CSAT Score | | | |
| NPS Score | | | |

## Gap Analysis

### Critical Gaps (cản trở vận hành)
- [Gap]: [Impact thực tế] → [Khuyến nghị]

### Important Gaps (giảm hiệu quả)
- [Gap]: [Impact] → [Khuyến nghị]

### Nice-to-have Gaps
- [Gap]: [Impact] → [Khuyến nghị]

## Process Assessment
[Danh sách processes: status Có / Chưa có / Cần cải thiện]

## Integration Assessment
[Danh sách integrations: status Active / Broken / Missing]

## Priority Recommendations
1. [Highest impact, nhất thiết phải fix] — Effort: Low/Med/High, Impact: High
2. ...

## Implementation Roadmap đề xuất
Quick wins (< 1 tháng) / Medium term (1-3 tháng) / Long term (3+ tháng)
```

---

## Checklist trước khi submit

```
□ Inventory tool stack đã đầy đủ
□ Performance baseline đã có số liệu thực (hoặc ghi rõ "chưa đo được")
□ FCR, MTTR, SLA compliance, CSAT đều được đánh giá
□ Knowledge base quality đã assess
□ CRM integration gap đã check
□ Escalation process đã review
□ Gap analysis chia rõ Critical / Important / Nice-to-have
□ Priority recommendations có effort-impact estimate
□ Open questions cần hỏi stakeholders được list ra
```
