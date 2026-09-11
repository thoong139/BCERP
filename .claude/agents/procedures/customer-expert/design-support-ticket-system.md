# Playbook: Thiết kế Support Ticket System

> **Type**: Agent Skill Playbook
> **Agent**: customer-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design helpdesk/ticketing module
> **Output**: Feature spec support module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Trong `/wf-define-features` khi cần viết feature spec cho helpdesk module
- Trong `/wf-design` khi cần tư vấn data model, ticket workflow, SLA logic
- Khi cần thiết kế hệ thống hỗ trợ khách hàng từ đầu hoặc mở rộng hệ thống hiện có
- Keywords kích hoạt: helpdesk, ticketing, support queue, SLA, escalation, CSAT

---

## Procedure

### Bước 1: Đọc context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra req-registry.json → lấy REQ-CX-SUP-* requirements

READ: support-operations.md → Channel Strategy, SLA Framework, Escalation Triggers

Xác định:
□ Ticket volume ước tính (low < 100/ngày, medium 100-1000/ngày, high > 1000/ngày)
□ Channels cần hỗ trợ: email, chat, phone, in-app, portal
□ Support tiers cần thiết: chỉ L1? hay L1+L2+L3?
□ B2B hay B2C? (ảnh hưởng đến SLA granularity)
□ Có cần multi-tenant? (nhiều công ty, mỗi công ty config SLA riêng)
□ Integration bắt buộc: CRM, billing, product backlog?
```

### Bước 2: Thiết kế Ticket Lifecycle

Vòng đời của một ticket — mọi status transition phải được model rõ:

```
CREATE (ticket được tạo)
  ↓
OPEN (chờ agent nhận)
  ↓
ASSIGNED (đã giao cho agent)
  ↓
IN PROGRESS (agent đang xử lý)
  ↓ [có thể quay lại IN PROGRESS]
PENDING (chờ phản hồi từ khách)
  ↓
RESOLVED (agent đã giải quyết, chờ confirm từ khách)
  ↓ [auto-close sau N ngày nếu không phản hồi]
CLOSED (hoàn tất)

CANCELLED (khách tự hủy hoặc duplicate)
REOPENED (từ CLOSED quay lại OPEN khi khách reply)
```

**Bắt buộc xác định:**
- Auto-close timeout: bao nhiêu ngày sau RESOLVED → tự động CLOSED?
- Reopen window: cho phép reopen trong bao nhiêu ngày sau CLOSED?
- Merge duplicate: logic detect và merge tickets trùng?

### Bước 3: Priority Matrix

```
READ: support-operations.md → SLA Framework

Thiết kế Priority Matrix dựa trên 2 chiều: Severity × Impact

SEVERITY (mức độ nghiêm trọng):
- Critical: hệ thống không hoạt động, mất dữ liệu, bảo mật bị xâm phạm
- High: tính năng chính bị lỗi, ảnh hưởng workflow chính
- Medium: tính năng phụ bị lỗi, có workaround
- Low: câu hỏi, yêu cầu thông tin, cải tiến nhỏ

IMPACT (số người/quy trình bị ảnh hưởng):
- Enterprise: toàn bộ tổ chức khách hàng bị ảnh hưởng
- Team: một team/department bị ảnh hưởng
- Individual: chỉ 1 người bị ảnh hưởng

Priority = f(Severity, Impact):
| Severity \ Impact | Enterprise | Team     | Individual |
|-------------------|------------|----------|------------|
| Critical          | P0         | P1       | P1         |
| High              | P1         | P1       | P2         |
| Medium            | P2         | P2       | P3         |
| Low               | P3         | P3       | P4         |
```

### Bước 4: SLA Tiers

Dựa trên Priority Matrix, định nghĩa SLA cho từng tier:

```
P0 (Critical Enterprise):
  First Response:  < 15 phút (24/7)
  Resolution:      < 1 giờ (24/7)
  Escalation:      Ngay lập tức → L2 + Management notification

P1 (High):
  First Response:  < 1 giờ (business hours)
  Resolution:      < 4 giờ
  Escalation:      Sau 2 giờ không có progress → L2

P2 (Medium):
  First Response:  < 4 giờ (business hours)
  Resolution:      < 24 giờ
  Escalation:      Sau 8 giờ → reminder, sau 20 giờ → L2

P3 (Low):
  First Response:  < 24 giờ (business hours)
  Resolution:      < 72 giờ
  Escalation:      Sau 48 giờ → reminder

P4 (Minimal):
  First Response:  < 3 ngày làm việc
  Resolution:      < 1 tuần
  Escalation:      Manual only

SLA Clock Rules:
□ SLA chỉ tính trong business hours (trừ P0)
□ SLA pause khi ticket ở trạng thái PENDING (chờ khách)
□ SLA resume khi khách reply
□ Alert tại 80% SLA consumed (warning), 100% (breach)
```

### Bước 5: Escalation Rules

```
Escalation tự động xảy ra khi:
□ SLA breach (response hoặc resolution)
□ Khách yêu cầu supervisor
□ Ticket open > X giờ không có activity
□ Priority escalated bởi agent
□ Khách nhắc đến: legal action, churn, executive contact
□ CSAT score < 3/5 sau khi closed

Routing escalation:
L1 Agent → L2 Specialist: giao ticket + notify L2
L2 Specialist → L3 Engineer: đính kèm technical notes
L3 → Management: khi P0 chưa resolved sau 30 phút

Escalation notification:
□ Kênh: email + in-app + Slack/Teams (tùy config)
□ Bao gồm: ticket ID, customer name, issue summary, SLA status, thời gian còn lại
```

### Bước 6: Assignment & Routing

```
Routing strategies (chọn 1 hoặc kết hợp):

Round-Robin:
□ Giao đều ticket cho agents trong queue
□ Ưu điểm: đơn giản, fair workload
□ Nhược điểm: không xét skill, workload

Skill-Based:
□ Tag ticket với category → route đến team/agent có skill tương ứng
□ Categories: billing, technical, account, general
□ Fallback: nếu không có skill-match → queue chung

Load-Based:
□ Giao cho agent có ít ticket nhất đang xử lý
□ Kết hợp với skill-based

Manual Override:
□ Manager/L2 có thể reassign bất kỳ lúc nào
□ Agent có thể transfer với lý do ghi chú

AUTO-ASSIGNMENT CONDITIONS:
□ Agent phải online (status = available)
□ Agent không vượt quá max concurrent tickets (configurable)
□ Agent có skill phù hợp với category
```

### Bước 7: Knowledge Base Integration

```
READ: support-operations.md → Best Practices

Tích hợp knowledge base trong ticket workflow:

AGENT-FACING:
□ Search KB trực tiếp từ ticket interface
□ Suggest articles dựa trên ticket subject/category (AI-assisted)
□ Insert article link / content vào reply với 1 click
□ Flag article cần update từ ticket context

CUSTOMER-FACING (Self-service):
□ Search KB trước khi submit ticket
□ Suggest articles khi khách đang điền form
□ "Did this article help?" → deflect nếu Yes
□ Link từ ticket response → customer xem KB

KB ARTICLE WORKFLOW:
□ Agent propose article khi gặp câu hỏi lặp
□ L2/Manager review và publish
□ Track article usage và deflection rate
```

### Bước 8: CSAT Collection

```
Trigger CSAT sau:
□ Ticket CLOSED (auto-send sau N giờ)
□ Ticket RESOLVED nếu khách xác nhận

CSAT Survey (tối giản):
□ 1 câu hỏi: "Bạn có hài lòng với cách xử lý không?" (1-5 stars)
□ Optional: comment free-text
□ Deadline: expire sau 7 ngày nếu không respond

CSAT Routing:
□ Score >= 4: auto-close, no action
□ Score = 3: gắn tag "neutral", queue for review
□ Score 1-2: gắn tag "detractor" → alert Manager + CSM → closed-loop follow-up trong 24h
```

### Bước 9: Reporting & Metrics

```
Báo cáo bắt buộc:

REAL-TIME DASHBOARD (agent/manager):
□ Open tickets by status + priority
□ SLA compliance rate (% tickets đúng hạn)
□ Average response time
□ Average resolution time
□ Agent workload (tickets per agent)

PERIODIC REPORTS (daily/weekly/monthly):
□ FCR — First Contact Resolution rate (mục tiêu > 70%)
□ MTTR — Mean Time To Resolve (theo priority tier)
□ SLA compliance % (theo priority tier)
□ CSAT score và trend
□ Ticket volume trend
□ Top issue categories
□ Knowledge base deflection rate
```

### Bước 10: Output — Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/[sys]/support/support-ticket-system.md

Cấu trúc output (Feature Spec):
1. Feature Overview (mục tiêu, scope, personas)
2. Ticket Lifecycle (state machine diagram dạng text)
3. Priority Matrix + SLA Tiers (bảng)
4. Escalation Rules (bảng trigger → action → notification)
5. Assignment & Routing Logic
6. Knowledge Base Integration points
7. CSAT Collection flow
8. Reporting requirements
9. Non-functional requirements (performance, volume, availability)
10. REQ-ID mapping (mỗi feature section → REQ-CX-SUP-NNN)
11. Open questions cho stakeholders
```

---

## Checklist trước khi submit

```
□ Ticket lifecycle có đầy đủ states và transition rules
□ SLA tiers được định nghĩa rõ (response + resolution + escalation)
□ Priority matrix có logic rõ ràng (không chỉ P1-P4 chung chung)
□ CSAT collection và closed-loop flow đã thiết kế
□ Knowledge base integration đã included
□ Reporting: FCR, MTTR, SLA compliance, CSAT đều có
□ Mỗi feature section có REQ-ID tương ứng
□ Performance requirements đã stated (max ticket load, SLA calculation timing)
□ Không thiết kế module ngoài phạm vi req-registry.json
```
