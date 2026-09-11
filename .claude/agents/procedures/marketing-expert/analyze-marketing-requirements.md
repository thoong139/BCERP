# Playbook: Phân tích Marketing Requirements

> **Type**: Agent Skill Playbook
> **Agent**: marketing-expert
> **Triggered by**: /wf-analyze-requirements khi có marketing modules
> **Output**: Requirements docs tại phase1-business/

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: campaign, lead, email, SEO, content, social, growth, analytics
- Khi cần xác định marketing requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm/dịch vụ (SaaS, E-commerce, Marketplace, App, B2B service...)
□ Business model (B2B / B2C / B2B2C)
□ Target market (SMB, Enterprise, Consumer...)
□ Giai đoạn tăng trưởng (Pre-launch / Early stage / Growth / Scale)
□ Đã có marketing platform chưa? Nếu có → đang dùng gì?
```

### Bước 2: Xác định marketing modules cần có

Dựa trên loại business, map ra modules:

| Business Type | Modules thường cần |
|--------------|-------------------|
| B2B SaaS | Lead management, Email automation, Campaign mgmt, Analytics/Attribution |
| B2C E-commerce | Campaign mgmt, Email automation, Social media, SEO/Content, Loyalty |
| Marketplace | Both sides (supply + demand), Referral, Community |
| Mobile App | ASO, Push notifications, In-app messaging, Retention |
| Content platform | SEO/Content, Newsletter, Social, Community |

Sau khi xác định → load knowledge file tương ứng:
```
Lead management → READ: lead-management.md
Campaign → READ: operations.md (Process 1) + digital-channels.md (Section 5)
Email → READ: digital-channels.md (Section 4)
SEO/Content → READ: digital-channels.md (Section 1 + 3)
Social → READ: digital-channels.md (Section 2)
Growth → READ: growth-marketing.md
Analytics → READ: analytics-attribution.md
Metrics → READ: metrics-framework.md
```

### Bước 3: Identify personas bị ảnh hưởng

```
READ: personas.md

Xác định ai sẽ dùng marketing system:
□ Marketing Manager → cần overview + approval
□ Campaign Specialist → cần execution tools
□ Content Manager → cần CMS + editorial workflow
□ Marketing Analyst → cần data + reporting
□ Growth Hacker → cần experimentation tools

Với mỗi persona: note down pain points và must-have features
```

### Bước 4: Map theo Customer Lifecycle

```
READ: customer-lifecycle.md

Với mỗi stage dự án cần cover:
□ ACQUIRE: Channels nào? System gì? KPIs gì?
□ NURTURE: Automation? Lead scoring? Email sequences?
□ CONVERT: Handoff to Sales? MQL criteria?
□ RETAIN: Lifecycle campaigns? Health monitoring?
□ ADVOCATE: Referral? Reviews? Community?
```

### Bước 5: Phân tích controls cần có

```
READ: controls.md

Checklist:
□ Consent management cần không? (Email opt-in, Push, Cookie)
□ GDPR/PDPA compliance level?
□ Budget approval thresholds?
□ Brand guidelines enforcement?
□ Attribution model choice?
```

### Bước 6: Viết requirements

Format mỗi requirement:

```markdown
### REQ-MKT-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-MKT-CAMP-001  → Campaign management
REQ-MKT-LEAD-001  → Lead management
REQ-MKT-EMAIL-001 → Email automation
REQ-MKT-SEO-001   → SEO/Content
REQ-MKT-SOC-001   → Social media
REQ-MKT-GROW-001  → Growth/Experimentation
REQ-MKT-ANA-001   → Analytics/Attribution
REQ-MKT-REF-001   → Referral/Advocacy
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/marketing-requirements.md

Cấu trúc output:
1. Executive Summary (3-5 dòng về scope marketing)
2. Marketing Modules cần build (list)
3. Personas affected (summary)
4. Requirements (theo module, có REQ-ID)
5. Integration requirements với các department khác
6. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format
□ Mỗi REQ có Business Value rõ ràng
□ Consent/Privacy requirements đã covered
□ Integration với Sales (nếu có lead handoff) đã noted
□ Analytics/Tracking requirements đã included
□ Open questions được list ra để stakeholders review
```
