# Procedure: Analyze Quality Management Requirements

> **Type**: Agent Procedure
> **Agent**: quality-excellence-expert
> **Triggered when**: Dự án có QMS/quality management module cần phân tích requirements (Phase 1-2)
> **Output**: Feature requirements REQ-QMS-[MODULE]-[NNN], quality personas mapping, workflow specifications

---

## Khi nào dùng procedure này

- Skill `wf-analyze-requirements` hoặc `wf-define-features` gọi quality-excellence-expert
- Dự án có module: "Quản lý chất lượng", "Quality Management", "QMS", "ISO compliance", "CAPA"
- Onboard project có existing quality system cần được phân tích thành requirements

---

## Procedure

### Bước 1: Đọc project context

Đọc context từ paths do skill cung cấp qua prompt.

Xác định:
- Industry sector (manufacturing, software, healthcare, services?)
- Quality standard target: ISO 9001? IATF 16949? AS9100? Hoặc internal only?
- Scale: bao nhiêu users? bao nhiêu NCRs/tháng? bao nhiêu sites?
- Current maturity: có QMS hiện tại không? Paper-based hay digital?

### Bước 2: Map quality personas trong dự án

READ `.claude/references/team-expert/quality-excellence/personas.md`

Xác định personas nào TỒN TẠI trong dự án này:
- Quality Director / VP Quality → có không?
- Six Sigma Black Belt / Green Belt → có không? Nếu không, skip DMAIC features
- QA/QC Analyst → có không? Đây là core user
- Process Owner (các bộ phận) → ai là Process Owners?
- Internal Auditor → có chương trình audit không?

Output: Danh sách personas với daily tasks và pain points áp dụng cho dự án này.

### Bước 3: Xác định QMS scope và mandatory functions

READ `.claude/references/team-expert/quality-excellence/iso-9001.md`

Với standard target đã xác định ở Bước 1, xác định mandatory functions:
- NCR management (Clause 8.7) — luôn cần
- CAPA management (Clause 10.2) — luôn cần
- Internal audit management (Clause 9.2) — nếu có audit program
- Document control (Clause 7.5) — nếu managing quality documents
- Management review support (Clause 9.3) — nếu muốn automate MR inputs
- Supplier quality management (Clause 8.4) — nếu có supplier relationships

List: Modules cần implement (scope), modules optional (scope extension).

### Bước 4: Map quality activities thành workflow requirements

READ `.claude/references/team-expert/quality-excellence/operations.md`

Với mỗi module trong scope, xác định workflow:
- NCR workflow: Detection → Create → Classify → Contain → RCA → CAPA → Verify → Close
- CAPA workflow: Trigger → Create → RCA → Action Plan → Approve → Implement → Verify → Close
- Audit workflow: Plan → Schedule → Execute → Report → CAR → Follow-up → Close

Ghi nhận: automation opportunities (auto-escalate, auto-notify, aging alerts).

### Bước 5: Xác định KPIs và reporting requirements

READ `.claude/references/team-expert/quality-excellence/quality-metrics.md`

Với Quality Director persona (nếu có):
- Chọn KPIs từ KPI Master Table phù hợp với scope
- Xác định dashboard requirements
- Xác định report frequency (daily alert, monthly report, management review input)

### Bước 6: Produce requirements với REQ-QMS IDs

Viết requirements theo format user story với acceptance criteria.

**REQ-ID pattern:**
- `REQ-QMS-NCR-[NNN]` — Nonconformance management
- `REQ-QMS-CAPA-[NNN]` — Corrective/Preventive Action
- `REQ-QMS-AUDIT-[NNN]` — Internal audit management
- `REQ-QMS-DOC-[NNN]` — Document control
- `REQ-QMS-KPI-[NNN]` — Quality KPI and reporting
- `REQ-QMS-FMEA-[NNN]` — FMEA management (nếu trong scope)

**Requirement format:**
```
REQ-QMS-NCR-001
Title: NCR Creation với Classification
As a: QA Analyst
I want: Tạo NCR với classification (Critical/Major/Minor) và photo attachment
So that: Mọi nonconformance được track từ khi phát hiện với đủ thông tin
Acceptance Criteria:
  - NCR có number auto-generated (NCR-YYYY-NNNN)
  - Classification field: Critical / Major / Minor với guidance tooltip
  - Photo attachment: tối thiểu 5 photos per NCR
  - Detection source: required field (inspection/audit/customer/near-miss)
  - Auto-notify QA Manager khi NCR class = Critical
Priority: Must Have
Persona: QA Analyst (primary), Quality Manager (secondary)
```

### Bước 7: Checklist trước khi submit

- [ ] Mỗi REQ có: ID, title, user story, acceptance criteria, priority, persona owner
- [ ] Coverage: mỗi QMS module trong scope có ít nhất 3 requirements
- [ ] Personas đã verified tồn tại trong dự án
- [ ] Không overlap với operations-expert scope (day-to-day warehouse QC)
- [ ] Requirements linked đến quality standard clause nếu có standard target
- [ ] Priority phân loại rõ: Must Have / Should Have / Nice to Have
