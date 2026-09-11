# DEVKIT Agents Capability Matrix

> **Version:** 3.4.0 | **Last Updated:** 2026-03-22

## Overview

DEVKIT sử dụng **multi-agent architecture** với 5 teams chuyên biệt:

- **Business**: Business Analysis — 20 agents (BA + 19 domain experts)
- **Engineering**: Technical Development — 13 agents
- **Design**: UX/UI Design — 7 agents
- **Testing**: Quality Assurance — 9 agents
- **Review**: DEVKIT Self-Quality — 6 agents

---

## Quick Reference

### Orchestrator

| Agent | Role | Khi nào dùng |
|-------|------|--------------|
| [orchestrator](orchestrator.md) | Điều phối chính | Luôn bắt đầu với orchestrator |

---

### Business — Business Analysis (20 agents)

#### Enterprise Core (8 agents)

| Agent | Domain | Khi nào dùng | Keywords |
|-------|--------|--------------|----------|
| [business-analyst](business/business-analyst.md) | Tổng quát | Luôn bắt đầu với BA | business, requirements, phân tích |
| [finance-expert](business/finance-expert.md) | Tài chính | ERP Finance, kế toán | finance, accounting, thuế |
| [hr-expert](business/hr-expert.md) | Nhân sự | Recruitment, Payroll, HRIS | HR, recruitment, lương |
| [legal-expert](business/legal-expert.md) | Pháp lý | Contracts, Compliance | legal, contract, NDA |
| [operations-expert](business/operations-expert.md) | Vận hành | Inventory, Supply Chain, Production | operations, inventory, kho |
| [marketing-expert](business/marketing-expert.md) | Marketing | Campaign, CRM Marketing | marketing, campaign, lead |
| [sales-expert](business/sales-expert.md) | Bán hàng | Pipeline, Quotation, CRM Sales | sales, pipeline, deal |
| [logistics-expert](business/logistics-expert.md) | Logistics | Xuất nhập khẩu, Hải quan, TMS, WMS | logistics, hải quan, customs |

#### Enterprise Extensions (5 agents)

| Agent | Domain | Khi nào dùng | Keywords |
|-------|--------|--------------|----------|
| [procurement-expert](business/procurement-expert.md) | Thu mua | Vendor Management, RFQ, PO | procurement, vendor, supplier |
| [compliance-expert](business/compliance-expert.md) | Tuân thủ | Regulatory, Audit Trail, Internal Controls | compliance, audit, regulatory |
| [data-expert](business/data-expert.md) | Analytics | BI, Dashboard, Reporting | analytics, BI, dashboard |
| [enterprise-risk-expert](business/enterprise-risk-expert.md) | Quản trị Rủi ro | ERM, Risk Governance, KRI, BCP/DRP | enterprise risk, ERM, risk governance, KRI, rủi ro doanh nghiệp |
| [quality-excellence-expert](business/quality-excellence-expert.md) | Chất lượng | QMS, Six Sigma, FMEA, ISO 9001 | quality management, QMS, Six Sigma, FMEA, CAPA |

#### Industry Specific (4 agents)

| Agent | Domain | Khi nào dùng | Keywords |
|-------|--------|--------------|----------|
| [ecommerce-expert](business/ecommerce-expert.md) | TMĐT | E-commerce, Marketplace | ecommerce, cart, checkout |
| [manufacturing-expert](business/manufacturing-expert.md) | Sản xuất | MES, BOM, Production | manufacturing, MES, BOM |
| [retail-expert](business/retail-expert.md) | Bán lẻ | POS, Store Management | retail, POS, chain |
| [healthcare-expert](business/healthcare-expert.md) | Y tế | Hospital, EMR, Patient | healthcare, EMR, hospital |

#### Emerging / Digital (3 agents)

| Agent | Domain | Khi nào dùng | Keywords |
|-------|--------|--------------|----------|
| [product-expert](business/product-expert.md) | Product | Roadmap, MVP, Backlog | product, roadmap, MVP |
| [customer-expert](business/customer-expert.md) | CX | Customer Success, Support | CX, customer success, support |
| [paid-media-expert](business/paid-media-expert.md) | Paid Media | PPC, Paid Social, ROAS | paid media, PPC, Google Ads, ROAS |

---

### Engineering — Technical Development (13 agents)

| Agent | Role | Khi nào dùng | Keywords |
|-------|------|--------------|----------|
| [architect](engineering/architect.md) | Kiến trúc | Thiết kế hệ thống, ADR | architecture, microservices, ADR |
| [developer](engineering/developer.md) | Lập trình | Implement code | implement, code, fix bug |
| [frontend-developer](engineering/frontend-developer.md) | Frontend | React/Vue, CSS, Web Vitals | frontend, React, CSS, SPA |
| [mobile-developer](engineering/mobile-developer.md) | Mobile | iOS/Android/React Native | mobile, iOS, Android, React Native |
| [ai-engineer](engineering/ai-engineer.md) | AI/ML | ML models, AI integration | AI, ML, model, LLM |
| [ai-data-remediation-engineer](engineering/ai-data-remediation-engineer.md) | AI Data | Data remediation, PII removal | data remediation, PII, semantic dedup |
| [data-engineer](engineering/data-engineer.md) | Data | ETL, pipelines, data lakehouse | ETL, pipeline, data lake, streaming |
| [dba](engineering/dba.md) | Database | Schema design, Migration | database, schema, SQL |
| [devops](engineering/devops.md) | DevOps | CI/CD, Deployment | CI/CD, Docker, Kubernetes |
| [sre](engineering/sre.md) | SRE | SLO/SLI, Incident Management | SRE, SLO, incident, reliability |
| [security](engineering/security.md) | Bảo mật | Security review | security, OWASP, vulnerability |
| [tech-writer](engineering/tech-writer.md) | Tài liệu | Documentation | docs, README, API docs |
| [automation-architect](engineering/automation-architect.md) | Automation | Workflow automation governance | automation, RPA, n8n, Zapier |

---

### Design — UX/UI (7 agents)

| Agent | Role | Khi nào dùng | Keywords |
|-------|------|--------------|----------|
| [ux-designer](design/ux-designer.md) | UX/UI | Wireframes, user flows, prototypes | wireframe, mockup, UI/UX, user flow |
| [ui-designer](design/ui-designer.md) | UI Design | Design systems, component libraries | design system, component, visual design, tokens |
| [ux-architect](design/ux-architect.md) | UX Architecture | CSS systems, layout frameworks | CSS architecture, layout, responsive, handoff |
| [brand-guardian](design/brand-guardian.md) | Brand Strategy | Brand identity, guidelines | brand, branding, visual identity, guidelines |
| [ux-researcher](design/ux-researcher.md) | UX Research | User research, Usability testing | personas, usability, user testing, A/B test |
| [image-prompt-engineer](design/image-prompt-engineer.md) | AI Image | Prompt engineering cho AI image generation | Midjourney, DALL-E, Stable Diffusion, Flux |
| [inclusive-visuals-specialist](design/inclusive-visuals-specialist.md) | Inclusive Visuals | Chống bias, đại diện hình ảnh bao trùm | inclusive, representation, bias, diversity |

---

### Testing — Quality Assurance (9 agents)

| Agent | Role | Khi nào dùng | Keywords |
|-------|------|--------------|----------|
| [qa-lead](testing/qa-lead.md) | QA | Testing, Quality | test, QA, bug, UAT |
| [code-reviewer](testing/code-reviewer.md) | Code Review | Review code quality | code review, PR review |
| [api-tester](testing/api-tester.md) | API Testing | API contract, load, security | API test, contract test, load test |
| [accessibility-auditor](testing/accessibility-auditor.md) | Accessibility | WCAG 2.2 compliance | a11y, WCAG, accessibility |
| [evidence-collector](testing/evidence-collector.md) | Visual QA | Screenshot evidence, visual validation | visual QA, screenshot, visual testing |
| [performance-benchmarker](testing/performance-benchmarker.md) | Performance | Load test, Core Web Vitals, capacity | performance, benchmark, load test, LCP |
| [integration-certifier](testing/integration-certifier.md) | Integration Gate | Deployment readiness certification | integration, deployment ready, go-live |
| [model-qa](testing/model-qa.md) | ML Model QA | Model audit, calibration, bias, SHAP | model audit, model validation, bias audit |
| [reality-checker](testing/reality-checker.md) | Reality Check | Final production gate, anti-fantasy | reality check, final check, production ready |

---

### Review — DEVKIT Self-Quality (6 agents)

| Agent | Role | Khi nào dùng | Keywords |
|-------|------|--------------|----------|
| [review-orchestrator](review/review-orchestrator.md) | Điều phối review | Full review coordination | review, audit, check |
| [skill-auditor](review/skill-auditor.md) | Kiểm tra skills | Review skill definitions | skill audit, skill check |
| [agent-auditor](review/agent-auditor.md) | Kiểm tra agents | Review agent definitions | agent audit, agent check |
| [template-auditor](review/template-auditor.md) | Kiểm tra templates | Review templates | template audit, orphan |
| [cross-reference-auditor](review/cross-reference-auditor.md) | Kiểm tra references | Review dependencies | cross-ref, broken links |
| [workflow-auditor](review/workflow-auditor.md) | Kiểm tra workflow | Review workflow integrity | workflow, consistency |

---

## Workflow

```
USER REQUEST
     │
     ▼
ORCHESTRATOR (Phân tích & Điều phối)
     │
     ├──────────────┬──────────────┬──────────────┬──────────────┐
     ▼              ▼              ▼              ▼              ▼
 BUSINESS      ENGINEERING      DESIGN       TESTING        REVIEW
(20 agents)   (13 agents)     (7 agents)   (9 agents)    (6 agents)
     │              │              │              │              │
     ▼              ▼              ▼              ▼              ▼
• business-    • architect     • ux-designer • qa-lead     • review-
  analyst      • developer     • ui-designer • code-         orchestrator
• finance-     • frontend-     • ux-          reviewer    • skill-auditor
  expert         developer       architect  • api-tester  • agent-auditor
• hr-expert    • mobile-       • brand-     • access-     • template-
• legal-         developer       guardian     ibility-      auditor
  expert       • ai-engineer   • ux-          auditor     • cross-ref-
• operations-  • ai-data-        researcher • evidence-      auditor
  expert         remediation-  • image-       collector   • workflow-
• marketing-     engineer        prompt-    • performance-   auditor
  expert       • data-engineer   engineer     benchmarker
• sales-       • dba           • inclusive- • integration-
  expert       • devops          visuals-     certifier
• logistics-   • sre             specialist • model-qa
  expert       • security                   • reality-
• procurement- • tech-writer                  checker
  expert       • automation-
• compliance-    architect
  expert
• data-expert
• ecommerce-
  expert
• manufacturing-
  expert
• retail-expert
• healthcare-
  expert
• product-
  expert
• customer-
  expert
• paid-media-
  expert
• enterprise-
  risk-expert
• quality-
  excellence-
  expert
     │              │              │              │              │
     └──────────────┴──────────────┴──────────────┴──────────────┘
                                   ▼
                          KNOWLEDGE BASE
                              (.mc-data/)
```

---

## Domain Expert Routing

Khi phát hiện yêu cầu thuộc domain chuyên môn, Orchestrator sẽ huy động:

| Domain | Business Experts | Tech Experts |
|--------|-----------------|--------------|
| ERP Core | finance-expert, hr-expert, operations-expert | architect, dba |
| ERP Extended | procurement-expert, compliance-expert | architect, dba |
| CRM Core | marketing-expert, sales-expert | developer, frontend-developer |
| CRM Extended | customer-expert, product-expert | developer, ux-designer |
| Logistics/Cross-border | logistics-expert | developer, dba |
| E-commerce | ecommerce-expert, marketing-expert, sales-expert | frontend-developer, developer |
| Retail Chain | retail-expert, operations-expert | developer, mobile-developer |
| Manufacturing | manufacturing-expert, operations-expert, quality-excellence-expert | developer, data-engineer |
| Healthcare | healthcare-expert, compliance-expert, enterprise-risk-expert | security, developer |
| Analytics/BI | data-expert | data-engineer, dba |
| AI/ML Projects | product-expert | ai-engineer, data-engineer, model-qa |
| Paid Media / Ads | paid-media-expert, marketing-expert | data-expert, frontend-developer |
| Mobile App | product-expert | mobile-developer, architect |
| SaaS Platform | product-expert, customer-expert | architect, sre, devops |
| Brand/Marketing Site | marketing-expert, product-expert | brand-guardian, ui-designer, ux-architect |
| Workflow Automation | operations-expert | automation-architect, devops |
| Enterprise Risk / GRC | enterprise-risk-expert, compliance-expert | architect, security, dba |
| Quality Management / QMS | quality-excellence-expert, operations-expert | architect, developer, dba |

---

## SDK Runtime Agent Types

Ngoài các agent definition files trong thư mục `.claude/agents/`, Claude Code SDK cung cấp 2 **runtime agent types** dùng được qua `subagent_type` nhưng **KHÔNG có file agent tương ứng** trong DEVKIT:

| `subagent_type` | Nguồn | Mục đích | Khi nào dùng trong DEVKIT |
|-----------------|-------|----------|---------------------------|
| `"claude"` | Claude Agent SDK runtime | Generic Claude agent — full tool access, không có procedure/knowledge ràng buộc. Default catch-all. | Lane agents (Phase 4 wf-fix-bugs) spawn với `subagent_type="claude"` vì mỗi lane đã có SKILL.md riêng (wf-fix-functional, wf-fix-security, ...) — agent đọc lane SKILL.md để xác định behavior, không cần agent definition. |
| `"general-purpose"` | Claude Agent SDK runtime | Multi-step research/exploration agent với full tool access. | Khi cần research mở (search code, find symbols, multi-round exploration) mà không khớp với specialized agent nào trong DEVKIT. Tránh dùng nếu task khớp với agent chuyên dụng (business-analyst, architect, developer, ...). |

**Phân biệt với DEVKIT agent definitions:**

- DEVKIT agents (62 agents trong `agents/business/`, `engineering/`, `design/`, `testing/`, `review/`, + `orchestrator.md`) — có file `.md` định nghĩa role, knowledge, procedures cụ thể; tham chiếu domain knowledge trong `references/team-expert/`.
- SDK runtime types (`claude`, `general-purpose`) — KHÔNG có file, là runtime primitives của Claude Code SDK. Khi spawn, agent nhận instructions trực tiếp từ caller (skill SKILL.md hoặc prompt).

**Quy tắc lựa chọn `subagent_type`:**

1. Task khớp specialized DEVKIT agent → dùng tên file agent (vd: `"business-analyst"`, `"developer"`)
2. Task là lane execution có SKILL.md riêng → `"claude"` (agent đọc skill, không cần định nghĩa)
3. Task là multi-step research mở không khớp specialized → `"general-purpose"`

> **Audit reference:** F02.001 — Document SDK runtime types để cross-reference auditor (`subagent_type="claude"` và `"general-purpose"` xuất hiện trong wf-fix-bugs SKILL.md Phase 4 spawn nhưng không có file agent → không phải bug, là runtime primitives).

---

## Tools Summary

| Tool | Available To |
|------|--------------|
| **Read** | Tất cả agents |
| **Write** | Tất cả agents (trừ security, code-reviewer, evidence-collector, integration-certifier, accessibility-auditor, review agents) |
| **Edit** | developer, frontend-developer, mobile-developer, ai-engineer, ai-data-remediation-engineer, data-engineer, dba, devops, sre, automation-architect, api-tester, performance-benchmarker, model-qa, reality-checker |
| **Grep/Glob** | Tất cả agents |
| **Bash** | architect, developer, frontend-developer, mobile-developer, ai-engineer, ai-data-remediation-engineer, data-engineer, dba, devops, sre, security, automation-architect, qa-lead, ux-designer, ui-designer, ux-architect, code-reviewer, api-tester, accessibility-auditor, evidence-collector, performance-benchmarker, integration-certifier, model-qa, reality-checker, review-orchestrator |
| **Task** | orchestrator, review-orchestrator |

---

## Changelog

### Note: Legacy Scan Agent Reuse

`/wf-legacy-scan` tái sử dụng agents hiện có — không tạo agent mới:
- **code-reviewer** — Stage 2: classify files
- **business-analyst** + domain experts — Stage 3: extract requirements/features
- **architect** + **dba** — Stage 4c: normalize Phase 3 docs
- **qa-lead** — Stage 5: gap analysis

Procedures riêng cho legacy-scan tại:
- `.claude/agents/procedures/business-analyst/legacy-scan-extract.md`
- `.claude/agents/procedures/architect/legacy-scan-normalize.md`
- `.claude/agents/procedures/code-reviewer/legacy-scan-classify.md`

### v3.4.0 (2026-03-22)
- **Mở rộng Business team** thêm 2 agents:
  - Thêm enterprise-risk-expert (ERM, risk governance, KRI, BCP/DRP — COSO ERM 2017, ISO 31000:2018)
  - Thêm quality-excellence-expert (QMS, Six Sigma DMAIC, FMEA, ISO 9001, CAPA)
- **Nâng cấp operations-expert** v3.1.0 — làm rõ scope boundary vs quality-excellence-expert
- **Nâng cấp compliance-expert** v2.1.0 — làm rõ scope boundary vs enterprise-risk-expert
- **Cập nhật Domain Expert Routing** thêm Enterprise Risk/GRC và Quality Management/QMS
- Tổng agents: 53 → 55

### v3.3.0 (2026-03-15)
- **Mở rộng Business team** thêm 1 agent:
  - Thêm paid-media-expert (PPC, Paid Social, ROAS optimization)
- **Mở rộng Design team** từ 5 → 7 agents:
  - Thêm image-prompt-engineer (AI image generation prompts)
  - Thêm inclusive-visuals-specialist (bias detection, inclusive representation)
- **Mở rộng Testing team** từ 7 → 9 agents:
  - Thêm model-qa (ML model audit, calibration, bias, SHAP)
  - Thêm reality-checker (final production gate, anti-fantasy)
- **Đồng bộ README.md** với CLAUDE.md và Orchestrator.md
- **Cập nhật Domain Expert Routing** thêm Paid Media, Mobile App, SaaS, Brand
- **Cập nhật Tools Summary** đầy đủ cho tất cả 54 agents
- Tổng agents: 48 → 53

### v3.2.0 (2026-03-15)
- **Mở rộng Testing team** từ 4 → 7 agents:
  - Thêm evidence-collector (visual QA, screenshot evidence)
  - Thêm performance-benchmarker (load test, Core Web Vitals, capacity planning)
  - Thêm integration-certifier (deployment readiness gate, anti-fantasy)
- Tổng agents: 45 → 48

### v3.1.0 (2026-03-15)
- **Mở rộng Design team** từ 2 → 5 agents:
  - Thêm ui-designer (visual design systems, component libraries)
  - Thêm ux-architect (CSS architecture, layout frameworks, design-to-dev handoff)
  - Thêm brand-guardian (brand strategy, identity, consistency)
- **Nâng cấp ux-researcher** v1.1.0 (thêm ethical research, heatmap analysis, survey design)
- Tổng agents: 42 → 45

### v3.0.0 (2026-03-15)
- **Tổ chức lại folder structure** theo domain chức năng:
  - `team-expert/` → `business/` (18 agents)
  - `team-tech/` → `engineering/` (11), `design/` (2), `testing/` (4)
  - `review/` giữ nguyên (6 agents)
- **Thêm 9 agents mới**:
  - Engineering: frontend-developer, mobile-developer, ai-engineer, data-engineer, sre
  - Testing: code-reviewer, api-tester, accessibility-auditor
  - Design: ux-researcher
- **Nâng cấp 8 agents** với Communication Style, Success Metrics, Advanced Capabilities:
  - security, architect, devops, qa-lead, ux-designer, developer, dba, tech-writer
- Tổng agents: 32 → 42

### v2.1.0 (2026-03-07)
- Thêm **Team Review** - Quality Assurance team (6 agents)

### v2.0.0 (2026-03-07)
- Thêm 9 agents mới vào Team Expert
- Phân loại Team Expert thành 4 categories

### v1.1.0 (2026-03-06)
- Thêm logistics-expert, version metadata, Agent Capability Matrix

### v1.0.0 (Initial)
- Tạo cấu trúc 17 agents cơ bản
