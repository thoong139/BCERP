# Playbook: Phân tích Business Requirements

> **Type**: Agent Procedure
> **Agent**: business-analyst
> **Triggered by**: /wf-analyze-requirements — Phase 1, khi bắt đầu phân tích requirements dự án
> **Output**: `.mc-data/docs/phase1-business/business-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án bắt đầu Phase 1 và cần tài liệu business requirements chính thức
- Khi cần xác định functional requirements từ ý tưởng dự án hoặc brainstorm document
- Default playbook khi không xác định được phase cụ thể

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, KNOWLEDGE_BASE

Cần xác định:
□ Loại hình doanh nghiệp (SME, Enterprise, Startup, NGO...)
□ Mô hình kinh doanh (B2B / B2C / B2B2C / SaaS / On-premise)
□ Lĩnh vực (ERP, CRM, HR, Logistics, E-commerce, Fintech, Healthcare...)
□ Quy mô (số lượng user, phòng ban, giao dịch/ngày)
□ Hệ thống hiện tại (nếu có) — đang dùng gì?
□ Lý do cần hệ thống mới — pain points chính là gì?
```

Tải knowledge files liên quan:
```
BA Frameworks → READ: .claude/references/team-expert/business-analysis/frameworks.md
                (Dùng mục 5 Gap Analysis, mục 4 Prioritization)
```

### Bước 2: Xác định business domain và mô hình vận hành

Dựa trên thông tin đã đọc, phân tích:

```
□ Core business process là gì? (Bán hàng? Sản xuất? Dịch vụ? Logistics?)
□ Revenue streams từ đâu?
□ Điểm kiểm soát quan trọng nhất trong quy trình?
□ Quy trình nào hiện đang bị "broken" nhất?
□ KPIs doanh nghiệp đang theo dõi hiện tại?
```

Sử dụng Gap Analysis Framework (frameworks.md mục 5):
- Current State: tình trạng quy trình hiện tại
- Future State: kỳ vọng sau khi có hệ thống
- Gap: chênh lệch cần giải quyết

### Bước 3: Identify và phân loại stakeholders

```
READ: .claude/references/team-expert/business-analysis/stakeholder-management.md
      (Mục 1 Stakeholder Identification Checklist)

Phân loại theo hai chiều:
□ Internal stakeholders: C-Level, Manager, End User, IT Team, Finance, Legal, HR, Operations
□ External stakeholders: Khách hàng, Đối tác, Vendor, Cơ quan quản lý

Với mỗi stakeholder group:
□ Vai trò trong hệ thống (Actor/Approver/Reviewer/Informed)
□ Mối quan tâm chính (Concern)
□ Mức độ ảnh hưởng (Power/Interest theo Power-Interest Grid)
□ Yêu cầu đặc thù của nhóm này
```

### Bước 4: Phân tích pain points theo từng stakeholder

Với mỗi stakeholder group quan trọng:

```
□ Hiện tại họ đang làm gì để giải quyết vấn đề? (workaround)
□ Tốn bao nhiêu thời gian/chi phí cho workaround đó?
□ Rủi ro nếu không giải quyết?
□ Success scenario trông như thế nào với họ?
```

Ghi chú: Đặt câu hỏi "Tại sao?" ít nhất 3 lần để tìm root cause thay vì symptom.

### Bước 5: Map các business processes cần hỗ trợ

Với mỗi core process, dùng template BPMN (frameworks.md mục 2):

```
Process [N]: [Tên process]
- Trigger: [Điều gì khởi động process này?]
- Actors: [Ai tham gia?]
- Steps: [Các bước tuần tự]
- Decision points: [Ở đâu cần approve/reject?]
- Output: [Kết quả cuối của process]
- Vấn đề hiện tại: [Pain points trong process này]
```

Xác định:
- Processes nào cần PHẢI có (Must-have)
- Processes nào là ưu tiên cao (Should-have)
- Processes nào có thể làm sau (Could-have)

### Bước 6: Viết requirements với REQ-ID

Sử dụng MoSCoW (frameworks.md mục 4) để phân loại ưu tiên.

Format mỗi requirement:

```markdown
### REQ-[DEPT]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ yêu cầu]
**Stakeholder**: [Ai cần requirement này]
**Business Value**: [Tại sao cần — impact định lượng nếu có]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1 — measurable]
- [ ] [Tiêu chí 2 — measurable]
**Dependencies**: [REQ khác phải có trước]
**Priority**: [Must-have / Should-have / Could-have / Won't-have]
```

REQ-ID Format:
```
REQ-[DEPT]-[NNN]       → Ví dụ: REQ-SALES-001, REQ-HR-001, REQ-FIN-001
REQ-[SYS]-[MOD]-[NNN] → Ví dụ: REQ-ERP-INV-001 (phức tạp, nhiều module)
```

Quan trọng: CHỈ dùng REQ-ID đã có trong `.mc-data/docs/_meta/req-registry.json`.
KHÔNG tự tạo REQ-ID mới ngoài registry.

### Bước 7: Xác định domain experts cần huy động

Dựa trên modules đã identify:

```
□ Có kế toán/tài chính? → Huy động finance-expert
□ Có nhân sự/lương? → Huy động hr-expert
□ Có bán hàng/CRM? → Huy động sales-expert
□ Có kho/vận hành? → Huy động operations-expert
□ Có marketing? → Huy động marketing-expert
□ Có hợp đồng/pháp lý? → Huy động legal-expert
```

Xem `.claude/references/agent-coordination.md` Section 1.1 để biết danh sách đầy đủ.

### Bước 8: Ghi output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/business-requirements.md

Cấu trúc output:
1. Executive Summary — Tóm tắt dự án và mục tiêu (3-5 dòng)
2. Business Context — Current state, desired state, gap analysis table
3. Stakeholders — Bảng stakeholder với role, concerns, power/interest
4. Business Processes — Mô tả các process cần hỗ trợ
5. Functional Requirements — Có REQ-ID, priority, acceptance criteria
6. Non-functional Requirements — Performance, security, usability
7. Business Rules — Các quy tắc nghiệp vụ cụ thể
8. Domain Experts cần huy động tiếp theo
9. Open Questions — Câu hỏi cần stakeholder confirm
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format và tồn tại trong registry
□ Mỗi REQ có Acceptance Criteria measurable (có thể verify được)
□ Mỗi REQ có Business Value rõ ràng (tại sao cần)
□ Gap Analysis đã cover Process / Technology / People
□ Stakeholders đã phân loại đầy đủ Internal + External
□ Domain experts cần huy động đã được list ra
□ Non-functional requirements (performance, security) đã included
□ Open questions được list ra để stakeholders review
□ Không có REQ-ID tự tạo ngoài registry
```
