# DEVKIT — Trích Xuất Ý Tưởng, Mô Tả & Yêu Cầu

> Tài liệu này trích xuất bản chất dự án DEVKIT (MCV3) — ý tưởng, vấn đề giải quyết, kiến trúc tổng quan, quy trình, và các đặc điểm cần chú ý — để làm nền tảng xây dựng lại một dự án tương tự bằng cách tiếp cận khác.

---

## 1. Ý Tưởng Cốt Lõi

**Một bộ công cụ AI biến ý tưởng mơ hồ thành phần mềm hoàn chỉnh.**

Người dùng chỉ cần mô tả ý tưởng bằng ngôn ngữ tự nhiên — hệ thống sẽ tự động huy động một **đội ngũ chuyên gia ảo** (virtual expert team) để:

- Brainstorm và làm rõ yêu cầu
- Phân tích nghiệp vụ chuyên sâu theo lĩnh vực
- Xây dựng tài liệu chuẩn (requirements, features, architecture, UX, deployment)
- Thiết kế kiến trúc và database
- Triển khai code hoàn chỉnh
- Kiểm thử và chuẩn bị triển khai

**Ví dụ đầu vào của người dùng:**

- "Xây dựng phần mềm quản lý vận hành cho công ty xuất nhập khẩu"
- "Triển khai website cho công ty bán lẻ"
- "Tôi có ý tưởng startup về..."
- "Đang dùng Excel quản lý kho, muốn chuyển sang phần mềm"

---

## 2. Vấn Đề Giải Quyết

| # | Vấn đề | Chi tiết |
|---|--------|----------|
| 1 | **Không biết bắt đầu từ đâu** | Người dùng có ý tưởng nhưng chưa biết cần gì cụ thể, không biết cần những module nào, quy trình nào |
| 2 | **Thiếu kiến thức chuyên môn** | Không có chuyên gia tài chính, HR, logistics, pháp lý... để tư vấn định hướng dự án phần mềm |
| 3 | **Nhảy thẳng vào code** | Bỏ qua bước phân tích và thiết kế → code thiếu hệ thống, phải làm lại |
| 4 | **Mất ngữ cảnh** | Dự án phức tạp, AI mất context giữa các session, không nhớ yêu cầu trước đó |
| 5 | **Không có quy trình chuẩn** | Mỗi lần làm dự án mới là một cách làm khác, không có framework tái sử dụng |
| 6 | **Tài liệu rời rạc** | Requirements, features, design nằm rải rác, không truy vết được từ nghiệp vụ đến code |

---

## 3. Quy Trình 7 Phases (Phase 0–6)

Quy trình tuần tự bắt buộc — **không được skip bất kỳ phase nào**:

```
STANDARD PATH (dự án mới):
  Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4* → Phase 5 → Phase 6
                                             (* conditional)

EXISTING PATH (dự án có sẵn):
  /wf-legacy-scan (all-in-one: detect → classify → extract → synthesize) →
  /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
  /wf-annotate-code (nếu có annotation gaps) →
  /wf-design-ux* (nếu có UI) → /wf-plan-modules → Phase 5 → Phase 6

  * = shared skills tự detect legacy mode và inject context
```

### Phase 0: Brainstorm — Chốt khung dự án

- **Đầu vào:** Ý tưởng sơ bộ từ người dùng (ngôn ngữ phi kỹ thuật)
- **Hoạt động:** AI brainstorm cùng người dùng qua hội thoại (~15-20 turns), đặt câu hỏi để làm rõ tổ chức, phòng ban, phạm vi hệ thống, chính sách nghiệp vụ
- **Đầu ra:**
  - Thông tin tổ chức, phòng ban, phân hệ, đối tượng người dùng
  - Bản đồ hệ thống (systems map), users & roles, NFR, tech stack
  - Chính sách nghiệp vụ cần thiết (do domain experts soạn)

### Phase 1: Phân tích yêu cầu nghiệp vụ

- **Đầu vào:** Output Phase 0
- **Hoạt động:** Đội ngũ chuyên gia ảo (AI Agents) đóng vai người vận hành doanh nghiệp — phân tích từng phòng ban, xây dựng requirements chi tiết. Các chuyên gia có thể thảo luận nhóm để hoàn thiện tài liệu
- **Đầu ra:**
  - Tổng quan dự án
  - Quy trình kinh doanh tổng thể
  - Tài liệu từng phòng ban (nhu cầu + workflow)
  - Danh sách REQ-IDs (requirements có mã theo dõi duy nhất)
  - Stakeholder review

### Phase 2: Định nghĩa tính năng

- **Đầu vào:** Requirements từ Phase 1
- **Hoạt động:** Chuyển requirements thành feature specifications chi tiết — mapping REQ-IDs → FEAT-IDs, tạo user stories, business rules, permissions
- **Đầu ra:**
  - Feature specs chi tiết (1 feature = 1 file)
  - Cấu trúc: `[system]/[module]/[feature].md`
  - Stakeholder review

### Phase 3: Thiết kế kiến trúc

- **Đầu vào:** Feature specs từ Phase 2
- **Hoạt động:** Tạo tài liệu thiết kế kỹ thuật toàn diện
- **Đầu ra:**
  - Kiến trúc tổng thể hệ thống
  - API contract (đặc tả API toàn hệ thống)
  - Database design (schema, tables, indexes)
  - Integration map (tích hợp xuyên phân hệ)
  - Infrastructure spec (hạ tầng & môi trường)
  - Stakeholder review

### Phase 4: Thiết kế UX/UI (Conditional)

- **Điều kiện:** Chỉ chạy khi dự án có giao diện (web/mobile) — skip nếu API-only
- **Đầu vào:** Architecture từ Phase 3
- **Hoạt động:** Thiết kế trải nghiệm người dùng và giao diện
- **Đầu ra:**
  - Design system (màu, font, layout, components)
  - Sơ đồ điều hướng (navigation) theo từng hệ thống
  - Thiết kế từng nhóm màn hình (screen groups)
  - Stakeholder review

### Phase 5: Lập kế hoạch & Triển khai code

- **Đầu vào:** Design từ Phase 3 + Phase 4
- **Hoạt động:**
  1. Phân tích dependency, xác định thứ tự implement
  2. Tạo sprint plans và task breakdown
  3. Coding theo TDD (Test-Driven Development)
  4. Testing, security review, code review
  5. Preflight health check (validate registry + docs + code + tests)
  6. Fix bugs (triage → fix → docs sync → verify)
  7. Verify truy vết (requirement → code)
- **Đầu ra:**
  - Implementation roadmap (lộ trình tổng thể)
  - Sprint plans
  - Task files (kế hoạch + checklist cho từng feature)
  - Source code hoàn chỉnh
  - Preflight report + Fix reports
  - Stakeholder review

### Phase 6: Triển khai & Vận hành

- **Đầu vào:** Code hoàn chỉnh từ Phase 5
- **Hoạt động:** Tạo tài liệu vận hành
- **Đầu ra:**
  - Deployment guide (triển khai + quản lý tài khoản + bảo trì)
  - User guide (hướng dẫn sử dụng cho end-user)
  - Incident response runbook (quy trình xử lý sự cố)
  - Stakeholder review

---

## 4. Hệ Thống Đội Ngũ Chuyên Gia Ảo (Multi-Agent)

### 4.1. Tổng quan

62 AI agents được tổ chức thành 5 teams, điều phối bởi 1 Orchestrator trung tâm:

```
                    USER
                      │
                      ▼
                 ORCHESTRATOR
          (Phân tích & Điều phối)
                      │
      ┌───────┬───────┼───────┬───────┐
      ▼       ▼       ▼       ▼       ▼
  BUSINESS  ENGI-   DESIGN  TESTING  REVIEW
  25 agents NEERING 7 agents 9 agents 6 agents
            14 agents
```

### 4.2. Team Business — Phân tích Nghiệp vụ (25 agents)

Đội ngũ chuyên gia nghiệp vụ, mỗi agent chuyên sâu một lĩnh vực.

> **v9.x roster expansion (2026-05):** thêm 5 domain experts — `education-expert`, `insurance-expert`, `investment-expert`, `real-estate-expert`, `strategy-expert`. Bảng chi tiết bên dưới giữ nguyên các nhóm cũ; danh sách đầy đủ và chính xác tại [project-description.md §"Team Business"](project-description.md).

**Enterprise Core (8 agents):**

| Agent | Lĩnh vực | Phạm vi chuyên môn |
|-------|----------|-------------------|
| Business Analyst (BA) | Tổng quát | Luôn tham gia — phân tích yêu cầu, stakeholder, quy trình |
| Finance Expert | Tài chính | Kế toán, ngân sách, báo cáo tài chính, thuế, ERP Finance |
| HR Expert | Nhân sự | Tuyển dụng, lương, chấm công, đánh giá, HRIS |
| Legal Expert | Pháp lý | Hợp đồng, GDPR, compliance, NDA |
| Operations Expert | Vận hành | Kho, chuỗi cung ứng, sản xuất, QC |
| Marketing Expert | Marketing | Campaign, lead gen, content, SEO/SEM, CRM Marketing |
| Sales Expert | Bán hàng | Pipeline, quotation, order, commission, CRM Sales |
| Logistics Expert | Logistics & XNK | Vận chuyển, hải quan, HS Code, Incoterms, TMS, WMS |

**Enterprise Extensions (5 agents):**

| Agent | Lĩnh vực | Phạm vi chuyên môn |
|-------|----------|-------------------|
| Procurement Expert | Thu mua | Vendor management, RFQ, RFP, PO |
| Compliance Expert | Tuân thủ | Audit trail, regulatory, internal controls, AML, GDPR |
| Data Expert | Analytics/BI | Dashboard, reporting, KPI, data warehouse |
| Enterprise Risk Expert | Quản trị rủi ro | ERM framework, COSO/ISO 31000, KRI, BCP/DRP, risk governance |
| Quality Excellence Expert | Chất lượng | QMS, Six Sigma DMAIC, ISO 9001, FMEA, process improvement |

**Industry Specific (4 agents):**

| Agent | Lĩnh vực | Phạm vi chuyên môn |
|-------|----------|-------------------|
| E-commerce Expert | Thương mại điện tử | Marketplace, cart, checkout, payment |
| Manufacturing Expert | Sản xuất | MES, BOM, MRP, work order, dây chuyền |
| Retail Expert | Bán lẻ | POS, store management, franchise, omni-channel |
| Healthcare Expert | Y tế | Hospital, EMR/EHR, patient management |

**Emerging / Digital (3 agents):**

| Agent | Lĩnh vực | Phạm vi chuyên môn |
|-------|----------|-------------------|
| Product Expert | Product Management | Roadmap, MVP, backlog, feature prioritization |
| Customer Expert | Customer Experience | Customer success, support, NPS, CSAT |
| Paid Media Expert | Quảng cáo trả phí | PPC, Google/Meta Ads, ROAS, programmatic |

### 4.3. Team Engineering — Phát triển Kỹ thuật (14 agents)

> **v9.x roster expansion:** thêm `embedded-engineer` (Firmware/Embedded Systems — STM32, ESP32, RTOS, IoT). Bảng cũ bên dưới giữ nguyên 13 mục cũ; danh sách đầy đủ tại [project-description.md §"Team Engineering"](project-description.md).

| Agent | Vai trò | Phạm vi |
|-------|---------|---------|
| Architect | Kiến trúc sư | Thiết kế hệ thống, multi-app platforms, ADR |
| Developer | Lập trình viên | Implement code backend theo technical design |
| Frontend Developer | Frontend | React/Vue/Angular, CSS, responsive, Core Web Vitals |
| Mobile Developer | Mobile | iOS/Android native, React Native, Flutter |
| AI Engineer | AI/ML | ML models, NLP, LLM integration, recommendation |
| AI Data Remediation Engineer | AI Data | Data cleaning, PII removal, semantic dedup |
| Data Engineer | Data Engineering | ETL/ELT pipelines, data lakehouse, streaming |
| DBA | Database | Schema design, migration, query optimization |
| DevOps | DevOps | CI/CD, Docker, Kubernetes, Terraform |
| SRE | Site Reliability | SLO/SLI/SLA, incident management, monitoring |
| Security | Bảo mật | OWASP, vulnerability assessment, threat modeling |
| Tech Writer | Technical Writing | Documentation, API docs, user guides |
| Automation Architect | Automation | Workflow automation governance (n8n, Zapier, RPA) |

### 4.4. Team Design — Thiết kế UX/UI (7 agents)

| Agent | Vai trò | Phạm vi |
|-------|---------|---------|
| UX Designer | UX/UI Design | Wireframes, user flows, prototypes |
| UI Designer | UI Design | Design systems, component libraries, visual design |
| UX Architect | UX Architecture | CSS systems, layout frameworks, design-to-dev handoff |
| Brand Guardian | Brand Strategy | Brand identity, guidelines, consistency |
| UX Researcher | UX Research | User research, personas, usability testing, A/B test |
| Image Prompt Engineer | AI Image | Prompt engineering cho Midjourney, DALL-E, Stable Diffusion |
| Inclusive Visuals Specialist | Inclusive Design | Chống bias, đại diện hình ảnh bao trùm |

### 4.5. Team Testing — Kiểm thử Chất lượng (9 agents)

| Agent | Vai trò | Phạm vi |
|-------|---------|---------|
| QA Lead | Test Lead | Test strategy, planning, quality gates |
| Code Reviewer | Code Review | PR review, code quality, best practices |
| API Tester | API Testing | Contract testing, load testing, security testing |
| Accessibility Auditor | Accessibility | WCAG 2.2, screen reader, keyboard navigation |
| Evidence Collector | Visual QA | Screenshot evidence, visual validation (Playwright) |
| Performance Benchmarker | Performance | Load test, Core Web Vitals, capacity planning |
| Integration Certifier | Integration Gate | Deployment readiness certification |
| Model QA | ML Model QA | Model audit, calibration, bias, SHAP analysis |
| Reality Checker | Final Gate | Mặc định "NEEDS WORK" — yêu cầu bằng chứng áp đảo để approve |

### 4.6. Team Review — Tự kiểm tra Toolkit (6 agents)

| Agent | Vai trò | Phạm vi |
|-------|---------|---------|
| Review Orchestrator | Điều phối review | Coordination toàn bộ review process |
| Skill Auditor | Kiểm tra skills | Verify skill definitions đúng cấu trúc |
| Agent Auditor | Kiểm tra agents | Verify agent definitions hợp lệ |
| Template Auditor | Kiểm tra templates | Verify templates tồn tại và đúng format |
| Cross-Reference Auditor | Kiểm tra references | Verify cross-component dependencies |
| Workflow Auditor | Kiểm tra workflow | Verify workflow integrity, không có gaps |

### 4.7. Orchestrator — Điều phối Trung tâm

Orchestrator là bộ não điều phối, có trách nhiệm:

- **Phân tích yêu cầu** người dùng → xác định lĩnh vực (domain)
- **Tự động chọn experts** phù hợp theo domain routing table
- **Điều phối giữa các teams** (Business → Engineering → Design → Testing)
- **Theo dõi tiến độ** và quality gates
- **Escalate** khi task fail QA 3 lần

### 4.8. Domain Expert Routing

Hệ thống tự động huy động đúng chuyên gia theo lĩnh vực dự án:

| Lĩnh vực dự án | Business Experts | Tech Experts |
|----------------|-----------------|--------------|
| ERP Core | finance, hr, operations | architect, dba |
| CRM | marketing, sales, customer | architect, frontend |
| Logistics/XNK | logistics | architect, data-engineer |
| E-commerce | ecommerce, marketing | architect, frontend |
| Retail Chain | retail, operations | architect, mobile |
| Manufacturing | manufacturing, operations | architect, data-engineer |
| Healthcare | healthcare, compliance | architect, security |
| AI/ML Platform | product | ai-engineer, data-engineer, model-qa |
| SaaS Platform | product, customer | architect, sre, devops |
| Paid Media/Ads | paid-media, marketing | data, frontend |
| Workflow Automation | operations | automation-architect, devops |

---

## 5. Single Source of Truth & Traceability

### 5.1. Registry — Nguồn Chân Lý Duy Nhất

Một file JSON trung tâm (`req-registry.json`) chứa toàn bộ thông tin có cấu trúc:

- **Systems** — danh sách phân hệ (VD: CRM, ERP, HRM)
- **Modules** — nhóm tính năng trong mỗi system (VD: Customer, Order)
- **Departments** — phòng ban liên quan
- **Requirements** — danh sách yêu cầu nghiệp vụ với REQ-IDs
- **Features** — tính năng specs với FEAT-IDs
- **Implementation order** — thứ tự triển khai
- **Status** — trạng thái từng item

### 5.2. Hệ Thống Mã Theo Dõi (ID System)

Mỗi thực thể được gán mã duy nhất, cho phép truy vết từ nghiệp vụ → code:

| Loại | Format | Ví dụ |
|------|--------|-------|
| Yêu cầu nghiệp vụ | `REQ-[DEPT]-[NNN]` | `REQ-SALES-001` |
| Module kỹ thuật | `MOD-[SYSTEM]-[MODULE]` | `MOD-CRM-CUST` |
| Tính năng | `FEAT-[SYSTEM]-[MODULE]-[NNN]` | `FEAT-CRM-CUST-001` |
| Màn hình UI | `UI-[SYSTEM]-[MODULE]-[SCREEN]-[NNN]` | `UI-CRM-CUST-LIST-001` |
| API Endpoint | `API-[SYSTEM]-[MODULE]-V1-[NNN]` | `API-CRM-CUST-V1-001` |
| Bảng dữ liệu | `DB-[SYSTEM]-[MODULE]-[NNN]` | `DB-CRM-CUST-001` |

**Luồng truy vết:**

```
REQ-SALES-001 (nghiệp vụ)
  → FEAT-CRM-CUST-001 (tính năng)
    → UI-CRM-CUST-LIST-001 (màn hình)
    → API-CRM-CUST-V1-001 (API)
    → DB-CRM-CUST-001 (database)
    → // REQ-ID: REQ-SALES-001 (trong source code)
```

### 5.3. Safe-Write Protocol

Mỗi phase/skill chỉ được update đúng fields được phân công trong registry — tránh conflict:

| Phase/Skill | Fields được phép update |
|-------------|------------------------|
| Phase 1 (Requirements) | systems, modules, departments, requirements |
| Phase 2 (Features) | features |
| Phase 3 (Design) | design_status |
| Phase 4 (UX) | ux_design_status |
| Phase 5 (Plan) | implementation_order |
| Phase 5 (Implement) | impl_status per REQ-ID |
| Verify | impl_status (safe-update only — không downgrade "done") |
| Fix Bugs | impl_status (safe-update only — cùng quy tắc với Verify) |
| Phase 3 (Design — legacy flow) | systems, modules, departments, requirements, features, interface_type |

---

## 6. Hệ Thống Tài Liệu (Document Framework)

### 6.1. Cấu Trúc Dữ Liệu Dự Án

Khi toolkit hoạt động, nó tạo một thư mục chứa toàn bộ dữ liệu dự án:

```
project-data/
├── docs/                              # Tài liệu chính thức theo 7 phases
│   ├── _meta/
│   │   └── req-registry.json          # ★ SINGLE SOURCE OF TRUTH
│   ├── phase0-brainstorm/             # Brainstorm outputs
│   ├── phase1-business/               # Business requirements
│   │   ├── project-overview.md
│   │   ├── business-workflow.md
│   │   ├── departments/
│   │   │   ├── _index.md              # Tổng hợp trạng thái
│   │   │   └── [dept-name]/
│   │   │       └── [dept-name].md     # Nhu cầu + Workflow
│   │   └── stakeholder-review.md
│   ├── phase2-features/               # Feature specifications
│   │   └── [system]/[module]/[feature].md
│   ├── phase3-architecture/           # Architecture + technical specs
│   │   ├── architecture.md
│   │   └── technical-specs/
│   │       ├── api-contract.md
│   │       ├── database-design.md
│   │       ├── integration-map.md
│   │       └── infra-spec.md
│   ├── phase4-ux/                     # UX/UI design (conditional)
│   │   ├── design-system.md
│   │   └── [system]/
│   │       ├── Navigation-[system].md
│   │       └── [module]/[screen-group].md
│   ├── phase5-implementation/         # Implementation plans
│   │   ├── implementation-roadmap.md
│   │   ├── sprints/
│   │   │   └── S0X-[sprint-name].md
│   │   └── tasks/
│   │       └── [system]/[module]/[feature]-impl.md
│   └── phase6-deployment/            # Deployment docs
│       ├── deployment-guide.md
│       ├── user-guide.md
│       └── incident-response-runbook.md
├── work/                              # Working data (trung gian, nội bộ)
│   ├── wf-analyze-requirements/
│   ├── wf-define-features/
│   ├── wf-design/
│   ├── wf-design-ux/
│   ├── wf-fix-bugs/
│   ├── wf-implement-feature/
│   ├── wf-preflight/
│   ├── legacy-scan/                   # Shared by wf-legacy-scan (all pipeline stages)
│   └── audit-skill-output/
├── sync/                              # REQ-ID sync tracking
└── knowledge-base/                    # Ghi chú bổ sung (optional)
```

### 6.2. Nguyên Tắc Tài Liệu

| Nguyên tắc | Giải thích |
|------------|-----------|
| **Đúng đối tượng** | Phase 1 viết cho người nghiệp vụ (không thuật ngữ kỹ thuật). Phase 3 viết cho developer |
| **1 feature = 1 file** | Dễ đọc, dễ sửa, tránh context overload cho AI |
| **1 skill = 1 phase** | Mỗi skill chỉ tạo tài liệu trong phạm vi 1 phase |
| **Tối giản nhưng đủ** | Chỉ ghi những gì cần thiết — không thừa, không thiếu |
| **Liên kết được** | REQ-ID giúp truy vết từ yêu cầu nghiệp vụ đến code |
| **Dễ cập nhật** | Mỗi file nhỏ, tập trung 1 chủ đề — thay đổi không ảnh hưởng file khác |

### 6.3. Task Hierarchy (3 levels)

```
EPIC (Feature)              ← Tính năng từ phase2-features/
└── STORY (User Story)      ← 1 story = 1 giá trị nghiệp vụ
    └── TASK (Implementation) ← 1 task = 1 file/operation cụ thể
```

### 6.4. Markers Trong Tài Liệu

| Marker | Ý nghĩa | Hành động |
|--------|---------|-----------|
| `[REQUIRED]` | Bắt buộc implement | Luôn implement, không skip |
| `[OPTIONAL]` | Có thể bỏ qua ở MVP | Hỏi user trước khi bỏ |
| `[FUTURE]` | Scope tương lai | Không implement, chỉ ghi comment |
| `[BLOCKED-BY: X]` | Phụ thuộc item X | Implement X trước |

---

## 7. Quality Enforcement — Đảm Bảo Chất Lượng

### 7.1. Quality Gates Giữa Các Phases

Mỗi phase có checklist bắt buộc trước khi chuyển sang phase tiếp theo:

**Phase 0 → 1:** Brainstorm đầy đủ, hệ thống đã chốt, policies đã soạn
**Phase 1 → 2:** Mọi REQ trong registry có file tương ứng, departments đầy đủ
**Phase 2 → 3:** Mọi FEAT có file, REQ mapping hợp lệ, không circular dependency
**Phase 3 → 4:** API và DB mapping hoàn chỉnh
**Phase 4 → 5:** Mọi screen group có file tương ứng (nếu có UI)

### 7.2. Stakeholder Review

Bắt buộc ở Phase 1–6. Mỗi review gồm:
- **Dashboard** — Tổng quan trạng thái phase
- **Sign-off rounds** — Nhiều vòng rà soát và phê duyệt

### 7.3. Retry Protocol (Khi Implement)

| Lần | Hành động |
|-----|-----------|
| 1–2 | Loop lại developer với QA feedback cụ thể (file, dòng, vấn đề) |
| 3 | Nếu vẫn fail → escalate cho user, mark blocked, tiếp tục pipeline |

**Nguyên tắc:** Không advance sang task tiếp theo khi task hiện tại chưa pass QA.

### 7.4. Anti-Fantasy Mechanisms

Hai agents đặc biệt mặc định **từ chối approve** — yêu cầu bằng chứng áp đảo:

- **Reality Checker** — Kiểm tra thực tế cuối cùng trước production
- **Integration Certifier** — Chứng nhận sẵn sàng triển khai

Mục đích: Ngăn chặn "fantasy approvals" — tình trạng AI tự approve mà không có evidence thực tế.

### 7.5. Automated Hooks

Các hook tự động chạy khi thao tác với code:

| Hook | Trigger | Mục đích |
|------|---------|----------|
| Validate REQ sync | Khi write/edit code | Cảnh báo nếu code file thiếu REQ-ID |
| Safety check | Khi chạy bash | Chặn lệnh nguy hiểm |
| Update sync | Sau write/edit | Cập nhật tracking đồng bộ |
| Validate contract | Sau write/edit | Validate đối chiếu với registry |
| UI quality | Sau write/edit | Kiểm tra chất lượng UI component |
| Stop verify | Khi kết thúc session | Xác minh đồng bộ trước khi dừng |

### 7.6. Cross-System Rules

```
✅ ĐƯỢC:  System A gọi REST API /internal/ của System B
✅ ĐƯỢC:  System A publish event, System B subscribe và xử lý
✅ ĐƯỢC:  System A đọc data của mình từ DB của mình

❌ CẤM:  System A query thẳng vào DB schema của System B
❌ CẤM:  System A import code từ System B (nếu là microservices)
❌ CẤM:  Duplicate business logic ở nhiều system
```

---

## 8. Đặc Điểm Thiết Kế Quan Trọng

### 8.1. Conversational Entry Point

- Người dùng bắt đầu bằng chat tự nhiên, không cần input có cấu trúc
- AI dẫn dắt qua hội thoại (~15-20 turns) để chốt khung dự án
- Từ mơ hồ → cụ thể qua từng phase (progressive refinement)

### 8.2. Domain-Aware Intelligence

- Tự nhận diện lĩnh vực dự án từ mô tả của user
- Tự động huy động đúng tổ hợp chuyên gia (domain routing)
- Chuyên gia có domain knowledge sâu (compliance, regulations, best practices)

### 8.3. Context Management

- Chia nhỏ công việc: Epic → Story → Task
- Mỗi file nhỏ, tập trung 1 chủ đề → AI không bị context overflow
- Registry là SSOT — AI luôn biết đang ở đâu, cần làm gì

### 8.4. Resume Capability

- Có thể dừng và tiếp tục từ điểm dừng (checkpoint)
- Working files lưu trạng thái trung gian
- Status command để xem tiến độ bất kỳ lúc nào

### 8.5. Conditional Phases

- Phase 4 (UX/UI) tự động skip nếu dự án là API-only
- Hệ thống đánh dấu `interface_type` (web / mobile / web+mobile / api-only) từ Phase 0

### 8.6. Extensibility

- Thêm agent mới bằng template có sẵn
- Thêm skill/workflow mới bằng template có sẵn
- Thêm domain knowledge bằng reference files
- Self-auditing: 6 agents review chính toolkit

### 8.7. Bilingual Convention

| Loại | Ngôn ngữ |
|------|----------|
| Documentation, comments | Tiếng Việt |
| File names, variables, functions | English |

### 8.8. Cross-Skill Output Path Contract

Giữa các phases, file paths phải khớp nhau chính xác:
- Phase N (producer) tạo output ở path X
- Phase N+1 (consumer) đọc input từ đúng path X
- Nếu paths không khớp → pipeline gãy

---

## 9. Glossary — Thuật Ngữ Cốt Lõi

| Thuật ngữ | Định nghĩa |
|-----------|-----------|
| **System** | Một subsystem/service trong dự án (VD: CRM, ERP, HRM) |
| **Module** | Nhóm tính năng liên quan trong một system (VD: Customer, Order) |
| **Feature** | Một tính năng cụ thể có thể implement |
| **REQ-ID** | ID duy nhất của một business requirement |
| **FEAT-ID** | ID duy nhất của một feature specification |
| **Actor** | Người dùng hoặc vai trò tương tác với hệ thống |
| **Business Rule (BR)** | Quy tắc nghiệp vụ bắt buộc phải tuân theo |
| **Acceptance Criteria (AC)** | Điều kiện để requirement được coi là hoàn thành |
| **SSOT** | Single Source of Truth — nguồn chân lý duy nhất |
| **Quality Gate** | Điểm kiểm tra bắt buộc trước khi chuyển phase |
| **Domain Routing** | Cơ chế tự động chọn experts phù hợp theo lĩnh vực |
| **Safe-Write** | Protocol đảm bảo mỗi phase chỉ update fields riêng |
| **Anti-Fantasy** | Cơ chế ngăn AI tự approve mà không có evidence |

---

## 10. Tổng Kết — Các Yếu Tố Cần Có Khi Xây Dựng Lại

Để xây dựng một dự án tương tự (bằng cách tiếp cận khác), cần đảm bảo các yếu tố sau:

| # | Yếu tố | Tại sao quan trọng |
|---|--------|-------------------|
| 1 | **Workflow tuần tự bắt buộc** (7 phases) | Ngăn skip phân tích/thiết kế, đảm bảo chất lượng |
| 2 | **Multi-agent system** (62 agents, 5 teams) | Chuyên môn hóa — mỗi agent giỏi một lĩnh vực |
| 3 | **Orchestrator điều phối** | Tự động chọn đúng experts, điều phối workflow |
| 4 | **Domain routing** | Nhận diện lĩnh vực → huy động đúng tổ hợp chuyên gia |
| 5 | **Single Source of Truth** (registry) | Tránh mất đồng bộ, mọi thông tin có 1 nơi duy nhất |
| 6 | **ID tracking xuyên suốt** (REQ → FEAT → UI → API → DB → Code) | Truy vết từ nghiệp vụ đến code, không bỏ sót |
| 7 | **Document framework** (54 templates) | Chuẩn hóa output, AI biết cần viết gì |
| 8 | **Quality gates giữa phases** | Ngăn lỗi lan truyền sang phase sau |
| 9 | **Anti-fantasy mechanisms** | Ngăn AI tự approve mà không có evidence thực |
| 10 | **Resume capability** | Dự án lớn không thể hoàn thành trong 1 session |
| 11 | **Automated hooks** | Validate tự động, không phụ thuộc vào "AI nhớ" |
| 12 | **Safe-Write Protocol** | Tránh conflict khi nhiều phases update cùng registry |
| 13 | **Conversational entry** | User không cần biết kỹ thuật, chỉ cần mô tả ý tưởng |
| 14 | **Conditional phases** | Linh hoạt — skip phase không cần thiết |
| 15 | **Self-auditing** | Toolkit tự kiểm tra chính mình |
