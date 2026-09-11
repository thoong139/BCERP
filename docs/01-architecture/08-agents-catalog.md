# 08 — Agents Catalog (62 agents)

> **Mức độ ràng buộc:** Tham khảo (overview)
> **Mục đích:** Inventory đầy đủ 62 AI agents MCV3 — phân theo 5 teams + orchestrator, kèm mô tả vai trò

---

## 1. Tóm tắt

```
.claude/agents/
├── orchestrator.md          ← 1 agent (điều phối toàn cảnh)
├── business/                ← 25 agents (BA + 24 domain experts)
├── engineering/             ← 14 agents (architect, dev, ops, security, ...)
├── design/                  ← 7 agents (UX/UI/Brand)
├── testing/                 ← 9 agents (QA, code review, perf, ...)
└── review/                  ← 6 agents (DEVKIT self-audit)

TỔNG: 62 agents
```

---

## 2. Cách spawn agent

Skills spawn agent qua `Agent` tool. `subagent_type` = tên file (không `.md`):

```python
Agent(
  description="...",
  subagent_type="business-analyst",  # tên file
  prompt="""8 sections theo CORE-037..."""
)
```

Chi tiết tạo agent: [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md).

---

## 3. Team Business (25 agents)

### 3.1. Core Business Analysis (1)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| Business Analyst | `business-analyst` | BA chính, làm việc xuyên-domain, tổng hợp requirements |

### 3.2. Domain Experts (24)

| Agent | Subagent type | Domain |
|-------|---------------|--------|
| Compliance Expert | `compliance-expert` | Regulatory compliance (GDPR, AML, licensing) |
| Customer Expert | `customer-expert` | CX, customer success, support, NPS/CSAT |
| Data Expert | `data-expert` | BI, analytics, reporting, dashboard, ETL |
| E-commerce Expert | `ecommerce-expert` | Marketplace, cart, checkout, payment |
| Education Expert | `education-expert` | LMS, e-learning, school management |
| Enterprise Risk Expert | `enterprise-risk-expert` | ERM, COSO ERM 2017, ISO 31000, KRI, BCP/DRP |
| Finance Expert | `finance-expert` | Kế toán, ngân sách, ERP Finance, GAAP/IFRS, VAS |
| Healthcare Expert | `healthcare-expert` | Hospital, EMR, FDA/CE, EMR standards, BHYT |
| HR Expert | `hr-expert` | Recruitment, payroll, performance, HRIS, OKRs |
| Insurance Expert | `insurance-expert` | Bảo hiểm nhân thọ/phi nhân thọ, insurtech, policy, claims |
| Investment Expert | `investment-expert` | Quỹ đầu tư, chứng khoán, NAV, UBCKNN |
| Legal Expert | `legal-expert` | Contracts, GDPR, CLM, e-signature |
| Logistics Expert | `logistics-expert` | TMS/WMS, hải quan VNACCS, HS Code, Incoterms |
| Manufacturing Expert | `manufacturing-expert` | MES, BOM, MRP, production planning, traceability |
| Marketing Expert | `marketing-expert` | Demand gen, content, SEO, SEM, CRM |
| Operations Expert | `operations-expert` | Supply chain, inventory, warehouse QC, FIFO/LIFO |
| Paid Media Expert | `paid-media-expert` | PPC (Google/Meta/TikTok), ROAS, attribution |
| Procurement Expert | `procurement-expert` | Vendor mgmt, sourcing, RFQ, PO, spend controls |
| Product Expert | `product-expert` | Roadmap, MVP, backlog, market research, NPS |
| Quality Excellence Expert | `quality-excellence-expert` | QMS ISO 9001, Six Sigma DMAIC, FMEA |
| Real Estate Expert | `real-estate-expert` | BĐS, property management, REIT, sàn giao dịch |
| Retail Expert | `retail-expert` | POS, store/chain, omnichannel, loyalty |
| Sales Expert | `sales-expert` | Pipeline, quotation, order, commission, CRM Sales |
| Strategy Expert | `strategy-expert` | C-suite, OKR, BSC, M&A, holding company |

**Routing per domain:** Khi user nêu lĩnh vực → orchestrator chọn 1-3 domain experts cùng với business-analyst.

---

## 4. Team Engineering (14 agents)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| Architect | `architect` | Kiến trúc enterprise, microservices/monolith, ADR, multi-app platform |
| Developer | `developer` | Implement code theo technical design |
| Frontend Developer | `frontend-developer` | React/Vue/Angular, CSS, Core Web Vitals, responsive |
| Mobile Developer | `mobile-developer` | iOS/Android, React Native, Flutter, Swift, Kotlin |
| Embedded Engineer | `embedded-engineer` | Firmware, MCU, RTOS, IoT (STM32, ESP32, FreeRTOS, Zephyr) |
| AI Engineer | `ai-engineer` | ML/AI features, model training, NLP/LLM, recommendation |
| AI Data Remediation Engineer | `ai-data-remediation-engineer` | AI data cleaning, semantic dedup, PII removal, air-gapped SLM |
| Data Engineer | `data-engineer` | ETL/ELT, lakehouse, data warehouse, streaming, Kafka/Spark/dbt |
| DBA | `dba` | Database schema, query optimization, migrations, SQL |
| DevOps | `devops` | CI/CD, deployment, infrastructure, Docker/K8s/Terraform |
| SRE | `sre` | Reliability, SLO/SLI, error budgets, incident mgmt, observability |
| Security | `security` | Security review, vulnerability assessment, OWASP, pen test |
| Tech Writer | `tech-writer` | Technical docs, API docs, user guides, release notes |
| Automation Architect | `automation-architect` | Workflow automation, n8n, Zapier, RPA, business process automation |

---

## 5. Team Design (7 agents)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| UX Designer | `ux-designer` | User experience, wireframes, user flows, prototypes |
| UI Designer | `ui-designer` | Visual design systems, component libraries, pixel-perfect |
| UX Architect | `ux-architect` | CSS architecture, layout frameworks, responsive strategies |
| UX Researcher | `ux-researcher` | User interview, personas, usability testing, journey mapping |
| Brand Guardian | `brand-guardian` | Brand identity, visual identity, brand consistency |
| Image Prompt Engineer | `image-prompt-engineer` | AI image generation prompts (Midjourney, DALL-E, Flux) |
| Inclusive Visuals Specialist | `inclusive-visuals-specialist` | Anti-bias trong AI image/video, cultural accuracy |

---

## 6. Team Testing (9 agents)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| QA Lead | `qa-lead` | Test strategy, test planning, test execution, quality assurance |
| Code Reviewer | `code-reviewer` | Code review, PR review, best practices, refactor assessment |
| API Tester | `api-tester` | API contract testing, load test, security test, integration test |
| Performance Benchmarker | `performance-benchmarker` | Load testing, Core Web Vitals, capacity planning |
| Accessibility Auditor | `accessibility-auditor` | WCAG 2.2, screen reader, keyboard nav, contrast |
| Evidence Collector | `evidence-collector` | Visual evidence-based QA, screenshot capture, Playwright |
| Integration Certifier | `integration-certifier` | Pre-production gate, deployment readiness, "NEEDS WORK" default |
| Reality Checker | `reality-checker` | Final reality check before production, fantasy approval prevention |
| Model QA | `model-qa` | ML/AI model validation, calibration, bias audit, SHAP, fairness |

**Phân biệt Integration Certifier vs Reality Checker:** Cả 2 đều "production gate", nhưng:
- `integration-certifier` — Pre-production integration certification
- `reality-checker` — Final reality check, last-mile pre-go-live

---

## 7. Team Review — DEVKIT Self-Audit (6 agents)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| Review Orchestrator | `review-orchestrator` | Điều phối toàn bộ review process DEVKIT |
| Agent Auditor | `agent-auditor` | Audit agent definitions compliance |
| Skill Auditor | `skill-auditor` | Audit skill definitions structure |
| Template Auditor | `template-auditor` | Audit doc-framework templates |
| Cross-Reference Auditor | `cross-reference-auditor` | Audit cross-component references |
| Workflow Auditor | `workflow-auditor` | Audit workflow integrity |

Team Review CHỈ chạy khi audit MCV3 self-quality — KHÔNG dùng cho dự án end-user.

---

## 8. Orchestrator (1 agent)

| Agent | Subagent type | Vai trò |
|-------|---------------|---------|
| Orchestrator | `orchestrator` | Điều phối giữa các teams khi skill spawn nhiều agents — quyết định team nào, agent nào |

---

## 9. Domain Knowledge Mapping

Mỗi agent (đặc biệt domain experts) reference tới folder knowledge cụ thể:

```
.claude/references/team-expert/
├── healthcare/             ← healthcare-expert reference
│   ├── emr-standards.md
│   ├── hl7-fhir.md
│   └── ...
├── finance/                ← finance-expert reference
├── ecommerce/              ← ecommerce-expert reference
├── logistics/
├── ... (29 domains, 162 files)
```

29 domains đang có knowledge files trong `.claude/references/team-expert/`. Khi tạo domain expert mới, BẮT BUỘC tạo folder knowledge tương ứng.

---

## 10. Agent Procedures Mapping

Mỗi agent có procedures chi tiết per task:

```
.claude/agents/procedures/
├── business-analyst/       ← procedure files BA dùng
│   ├── analyze-stakeholders.md
│   ├── write-user-story.md
│   └── ...
├── developer/
├── architect/
└── ... (61 procedure directories)
```

Agent đọc procedure khi cần HOW chi tiết cho 1 task cụ thể. Pattern lazy-load giống skill.

---

## 11. Quick Agent Routing Matrix

| Use case | Agents primary | Agents support |
|----------|---------------|----------------|
| Phase 0 brainstorm | orchestrator | business-analyst, strategy-expert |
| Phase 1 requirements (healthcare) | business-analyst, healthcare-expert | compliance-expert |
| Phase 1 requirements (ecommerce) | business-analyst, ecommerce-expert | sales-expert, paid-media-expert |
| Phase 2 features | business-analyst, product-expert | (domain experts) |
| Phase 3 architecture | architect | dba, devops, security, frontend-developer |
| Phase 4 UX | ux-designer, ui-designer | ux-architect, brand-guardian, accessibility-auditor |
| Phase 5 implement | developer, frontend-developer/mobile-developer | code-reviewer, qa-lead, security |
| Fix bugs lane QD3 (Security) | security | api-tester |
| Fix bugs lane QD5 (Accessibility) | accessibility-auditor | ux-designer |
| Fix bugs lane QD2 (Business) | business-analyst, domain expert | — |
| E2E Testing | qa-lead, evidence-collector | api-tester, accessibility-auditor |
| Pre-prod certification | integration-certifier | reality-checker, qa-lead |

---

## 12. Cách thêm Agent mới

1. Đọc spec [`.claude/agents/spec/README.md`](../../.claude/agents/spec/README.md)
2. Tạo Knowledge files TRƯỚC: `.claude/agents/spec/knowledge-template.md`
3. Tạo agent trong `.claude/agents/{category}/{name}.md`
4. Thêm domain knowledge `.claude/references/team-expert/{domain}/`
5. Tạo procedures `.claude/agents/procedures/{name}/`
6. Tên file (không `.md`) = `subagent_type` value
7. Validate qua [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md) checklist

---

## 13. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Spawn agent thiếu 8 sections trong prompt | Đủ 8 sections (CORE-037) |
| Agent ghi vào output của agent khác | 1 file = 1 writer |
| 2 agents cùng team handle cùng task (vd: 2 BA) | 1 task = 1 primary owner |
| Agent reference knowledge sai domain | Healthcare task → `references/team-expert/healthcare/`, KHÔNG `general/` |
| Skill spawn agent qua "subagent_type=BA" (chữ hoa) | Đúng tên file: `business-analyst` |
| Agent định nghĩa knowledge inline trong agent.md | Tách ra `references/` (lazy-load) |
| Tạo domain expert không có folder `references/team-expert/{domain}/` | PHẢI có |
| 2 agents trùng vai trò | Phải có "When NOT to use" để phân biệt |

---

## 14. Liên kết

- **Agent standard:** [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md)
- **System layers:** [`01-system-layers.md`](01-system-layers.md) — vai trò lớp 2
- **Skills catalog:** [`07-skills-catalog.md`](07-skills-catalog.md) — skills spawn agents
- **Spec & template:** [`.claude/agents/spec/`](../../.claude/agents/spec/)
- **Domain knowledge:** [`.claude/references/team-expert/`](../../.claude/references/team-expert/) (162 files, 29 domains)
- **Procedures:** [`.claude/agents/procedures/`](../../.claude/agents/procedures/) (61 directories)
