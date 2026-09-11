# Agent Coordination Registry — DEVKIT SSOT

> **Muc dich:** File nay la SINGLE SOURCE OF TRUTH cho coordination giua tat ca agents.
> Agents tra cuu file nay de biet phoi hop voi ai va khi nao.
> Khi them/xoa/sua agent, CHI CAN SUA FILE NAY + agent file tuong ung.
> **Last Updated:** 2026-04-13 (thêm embedded-engineer)

---

## 1. Agent Directory

### 1.1 Business Team (25 agents)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| business-analyst | Phan tich yeu cau tong quat, dieu phoi domain experts | business, requirements, phan tich, nghiep vu, quy trinh, stakeholder, use case, workflow |
| finance-expert | Tai chinh, ke toan, ngan sach, kiem soat noi bo | finance, accounting, budget, invoice, payment, ERP, ke toan, thue, AR, AP, GL |
| hr-expert | Nhan su, tuyen dung, luong, dao tao | HR, recruitment, payroll, employee, performance, training, nhan su, cham cong |
| sales-expert | Ban hang, pipeline, CRM, doanh so | sales, pipeline, quotation, order, commission, revenue, CRM, ban hang, deal |
| marketing-expert | Marketing, campaigns, demand generation | marketing, campaign, lead, content, SEO, SEM, ads, CRM, growth, funnel |
| paid-media-expert | Quang cao tra phi, PPC, ROAS | paid media, PPC, Google Ads, Facebook Ads, ROAS, CPA, ad spend, programmatic |
| operations-expert | Van hanh, kho, supply chain | operations, inventory, supply chain, warehouse, QC, van hanh, kho, ton kho, FIFO |
| logistics-expert | Logistics, xuat nhap khau, hai quan | logistics, van chuyen, hai quan, HS Code, VNACCS, container, freight, Incoterms, TMS, WMS |
| legal-expert | Phap ly, hop dong, NDA | legal, contract, GDPR, policy, phap ly, hop dong, NDA, CLM, e-signature |
| compliance-expert | Kiem toan, rui ro, tuan thu quy dinh | compliance, audit, risk, regulatory, internal control, tuan thu, kiem toan, rui ro |
| enterprise-risk-expert | Quan tri rui ro doanh nghiep (ERM), risk governance, KRI, BCP/DRP | enterprise risk, ERM, risk management, risk governance, risk appetite, KRI, BCP, DRP, rui ro doanh nghiep |
| quality-excellence-expert | Quan ly chat luong, QMS, Six Sigma, FMEA, ISO 9001 | quality management, QMS, Six Sigma, DMAIC, ISO 9001, FMEA, quality excellence, process improvement |
| ecommerce-expert | Thuong mai dien tu, marketplace | ecommerce, marketplace, cart, checkout, product catalog, storefront, TMDT, gio hang |
| retail-expert | Ban le, POS, chuoi cua hang | retail, POS, store, chain, franchise, omni-channel, ban le, cua hang |
| manufacturing-expert | San xuat, nha may, BOM, day chuyen | manufacturing, MES, production, BOM, MRP, work order, san xuat, nha may |
| procurement-expert | Thu mua, nha cung cap, RFQ | procurement, vendor, supplier, sourcing, RFQ, RFP, PO, thu mua, nha cung cap |
| healthcare-expert | Y te, benh vien, EMR | healthcare, hospital, EMR, EHR, patient, medical, clinic, y te, benh vien |
| customer-expert | Cham soc khach hang, CX, support | customer, CX, customer success, support, helpdesk, ticket, NPS, CSAT |
| product-expert | Product management, roadmap, MVP | product, roadmap, MVP, backlog, feature, user story, PM, product owner, TAM |
| data-expert | Analytics, BI, dashboard, bao cao | analytics, BI, dashboard, reporting, data warehouse, ETL, KPI, metrics |
| strategy-expert | Chiến lược doanh nghiệp, OKR/BSC, điều hành tập đoàn, M&A, board governance | strategy, CEO, board, OKR, BSC, M&A, holding company, executive dashboard, chiến lược, tập đoàn, hội đồng quản trị, ban điều hành |
| real-estate-expert | Bất động sản, quản lý dự án BĐS, property management, sàn giao dịch | real estate, property, bất động sản, BĐS, chủ đầu tư, sổ đỏ, căn hộ, property management, thuê mặt bằng, REIT |
| investment-expert | Quản lý quỹ đầu tư, chứng khoán, danh mục, NAV, portfolio management | investment, fund, portfolio, NAV, chứng khoán, quỹ đầu tư, UBCKNN, private equity, venture capital, asset management |
| insurance-expert | Bảo hiểm nhân thọ/phi nhân thọ, policy, claims, underwriting, insurtech | insurance, bảo hiểm, policy, claims, underwriting, premium, nhân thọ, phi nhân thọ, tái bảo hiểm, insurtech |
| education-expert | Giáo dục, LMS, quản lý học sinh, e-learning, trường học, corporate training | education, LMS, e-learning, school, course, student, teacher, giáo dục, học sinh, khóa học, đào tạo, trung tâm |

### 1.2 Engineering Team (13 agents)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| architect | Kien truc he thong, multi-app platforms, distributed systems | architecture, ADR, microservices, monolith, system design |
| developer | Lap trinh backend, implement features, fix bugs | implement, code, fix bug, refactor |
| frontend-developer | Frontend web: React/Vue/Angular, CSS, responsive, accessibility | frontend, UI components, CSS, responsive, React, Vue, Angular |
| mobile-developer | Mobile iOS/Android native va cross-platform | mobile, iOS, Android, React Native, Flutter, Swift, Kotlin |
| ai-engineer | AI/ML: training, inference, LLM integration | AI, ML, machine learning, deep learning, NLP, LLM, model training |
| ai-data-remediation-engineer | Data cleaning cho AI: PII removal, semantic dedup | data remediation, data cleaning, PII removal, semantic dedup, air-gapped |
| data-engineer | ETL/ELT pipelines, data warehouse, streaming | ETL, ELT, data pipeline, data warehouse, data lake, Kafka, Spark, CDC, dbt |
| dba | Database schema, toi uu hieu nang, data integrity | schema, ERD, migration, SQL, database design, query optimization |
| devops | CI/CD, deployment, infrastructure, monitoring | CI/CD, Docker, Kubernetes, Terraform, deploy, infrastructure |
| sre | Reliability: SLO/SLI/SLA, incident management, observability | SRE, reliability, SLO, SLI, incident, post-mortem, observability, monitoring |
| security | Security review, vulnerability assessment, penetration testing | security, OWASP, vulnerability, penetration test, threat modeling |
| tech-writer | Technical documentation, API docs, user guides | docs, README, API docs, user guide, release notes, documentation |
| automation-architect | Danh gia va quan tri workflow automation | automation, workflow automation, n8n, Zapier, RPA, integration governance |
| embedded-engineer | Firmware & Embedded Systems: MCU, RTOS, HAL, IoT protocols | firmware, MCU, RTOS, HAL, STM32, ESP32, Arduino, FreeRTOS, Zephyr, GPIO, UART, SPI, I2C, CAN, embedded, IoT device |

### 1.3 Design Team (7 agents)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| ux-designer | UX/UI design: wireframes, user flows, prototypes | UI, UX, wireframe, mockup, user flow, prototype |
| ui-designer | Design systems, component libraries, visual hierarchy | design system, component library, visual design, color palette, typography, design tokens |
| ux-architect | CSS architecture, layout frameworks, design-to-dev handoff | CSS architecture, layout system, responsive framework, information architecture |
| brand-guardian | Brand identity, guidelines, visual identity systems | brand, branding, brand identity, brand guidelines, logo, visual identity, brand voice |
| ux-researcher | User research, personas, usability testing, A/B testing | UX research, user interview, persona, usability test, journey map, survey, A/B testing |
| image-prompt-engineer | AI image prompts: Midjourney, DALL-E, Stable Diffusion, Flux | AI image, prompt engineering, Midjourney, DALL-E, Stable Diffusion, Flux |
| inclusive-visuals-specialist | Chong bias trong AI image, dai dien hinh anh bao trum | inclusive, representation, bias, diversity, cultural accuracy, accessible visuals |

### 1.4 Testing Team (9 agents)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| qa-lead | Test strategy, test planning, quality gates, release readiness | test, QA, bug, test case, UAT, quality gate |
| code-reviewer | Code quality, PR review, best practices, refactoring | code review, PR review, quality check, refactor, naming, pattern |
| api-tester | API contract testing, load testing, security testing | API testing, contract testing, load test, integration test, endpoint |
| accessibility-auditor | WCAG 2.2, screen reader, keyboard navigation, ARIA | accessibility, WCAG, a11y, screen reader, keyboard navigation, ARIA, contrast |
| evidence-collector | Visual QA: screenshot evidence, Playwright capture | visual testing, screenshot evidence, visual QA, UI validation |
| performance-benchmarker | Load testing, Core Web Vitals, capacity planning | performance, benchmark, load test, stress test, LCP, FID, CLS, latency |
| integration-certifier | Deployment readiness, production gate (mac dinh NEEDS WORK) | integration test, deployment readiness, go-live, production ready, release gate |
| model-qa | ML model audit: calibration, bias, SHAP, fairness | model audit, model validation, ML testing, bias audit, calibration, SHAP |
| reality-checker | Final production gate, chong fantasy approvals | reality check, final check, production ready, deployment readiness |

### 1.5 Review Team (6 agents)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| review-orchestrator | Dieu phoi quy trinh ra soat DEVKIT | DEVKIT review, audit orchestration |
| agent-auditor | Kiem tra agent definitions | agent audit, agent definition check |
| skill-auditor | Kiem tra skill definitions | skill audit, workflow compliance |
| template-auditor | Kiem tra template files | template audit, doc-framework review |
| cross-reference-auditor | Kiem tra cross-component references | reference audit, dependency check, broken links |
| workflow-auditor | Kiem tra workflow integrity | workflow audit, handoff validation, phase continuity |

### 1.6 Orchestrator (agent dac biet)

| Agent | Mo ta | Keywords Trigger |
|-------|-------|-----------------|
| orchestrator | Dieu phoi chinh cua DEVKIT, ket noi user voi cac teams | du an, yeu cau phan tich, trien khai code |

---

## 2. Cross-Team Coordination

### 2.1 Business ↔ Engineering

| Business Agent | Khi phat hien | Engineering Agent |
|---------------|---------------|-------------------|
| finance-expert | Can audit trail cho transactions | architect, dba |
| finance-expert | Import/export taxes | logistics-expert → architect (system design) |
| operations-expert | Can inventory sync real-time | data-engineer, architect |
| data-expert | Can data infrastructure, query optimization | dba, data-engineer |
| compliance-expert | Can data security review | security |
| healthcare-expert | Can data security, privacy compliance | security |
| automation-architect* | Can business process analysis | business-analyst |

> *automation-architect thuoc Engineering nhung phoi hop nguoc voi Business

### 2.2 Business ↔ Design

| Business Agent | Khi phat hien | Design Agent |
|---------------|---------------|--------------|
| product-expert | Can UX design cho features | ux-designer |
| product-expert | Can user research data | ux-researcher |
| customer-expert | Can customer journey mapping | ux-researcher |

### 2.3 Engineering ↔ Testing

| Engineering Agent | Khi phat hien | Testing Agent |
|-------------------|---------------|---------------|
| developer | Code can review | code-reviewer |
| developer | Code can QA | qa-lead |
| frontend-developer | Can design specs, component behavior | ux-designer (Design) |
| architect | Can security review | security (internal) → code-reviewer |
| tech-writer | Can verify behavior da test | qa-lead |

### 2.4 Testing ↔ Engineering

| Testing Agent | Khi phat hien | Engineering Agent |
|---------------|---------------|-------------------|
| code-reviewer | Architecture concern can thiet ke lai | architect |
| api-tester | API design can redesign | architect |
| performance-benchmarker | Database bottleneck | dba |
| performance-benchmarker | Infrastructure scaling | devops, sre |
| performance-benchmarker | Frontend CWV can optimize | frontend-developer |
| evidence-collector | Issues can developer fix | developer, frontend-developer |
| reality-checker | Issues can developer fix | developer, frontend-developer |
| reality-checker | Deployment infrastructure check | devops |
| integration-certifier | Deployment infrastructure check | devops |
| model-qa | Model architecture issues | ai-engineer |
| model-qa | Data pipeline problems | data-engineer |
| model-qa | Production monitoring gaps | sre |
| model-qa | Security concerns (adversarial, PII) | security |
| accessibility-auditor | Component ARIA implementation | developer |

### 2.5 Design ↔ Testing

| Design Agent | Khi phat hien | Testing Agent |
|--------------|---------------|---------------|
| inclusive-visuals-specialist | Representation issues can audit | accessibility-auditor |
| image-prompt-engineer | User perception feedback | ux-researcher (internal) |

| Testing Agent | Khi phat hien | Design Agent |
|---------------|---------------|--------------|
| accessibility-auditor | Design tokens can audit (contrast, spacing) | ux-designer |

### 2.6 Engineering ↔ Design

| Engineering Agent | Khi phat hien | Design Agent |
|-------------------|---------------|--------------|
| frontend-developer | Can design specs, component behavior | ux-designer |

| Design Agent | Khi phat hien | Engineering Agent |
|--------------|---------------|-------------------|
| ux-architect | Can CSS implementation handoff | frontend-developer |
| ui-designer | Can component implementation | frontend-developer |

---

## 3. Intra-Team Coordination

### 3.1 Business Team

| Agent | Phoi hop voi | Tinh huong |
|-------|-------------|-----------|
| business-analyst | Tat ca domain experts | Luon bat dau BA truoc, dispatch theo domain |
| sales-expert | finance-expert | Invoice, AR, sales commission |
| sales-expert | operations-expert | Inventory availability |
| sales-expert | marketing-expert | Marketing leads handoff |
| sales-expert | legal-expert | Contract terms |
| marketing-expert | sales-expert | Lead handoff to Sales |
| marketing-expert | finance-expert | Marketing budget |
| marketing-expert | legal-expert | GDPR, influencer contracts |
| marketing-expert | ecommerce-expert | E-commerce marketing |
| marketing-expert | customer-expert | Customer experience, NPS |
| marketing-expert | data-expert | Data analytics, BI dashboards |
| finance-expert | hr-expert | Payroll processing |
| finance-expert | operations-expert | Inventory valuation |
| finance-expert | legal-expert | Contract terms affecting payment |
| finance-expert | logistics-expert | Import/export taxes |
| finance-expert | sales-expert | Sales commission |
| hr-expert | finance-expert | Payroll GL posting, training budget |
| hr-expert | legal-expert | Employee contracts |
| hr-expert | sales-expert | Sales commission |
| operations-expert | finance-expert | Inventory valuation (accounting) |
| operations-expert | logistics-expert | Shipping/import/export |
| operations-expert | legal-expert | Vendor contracts |
| operations-expert | sales-expert | Sales order fulfillment |
| logistics-expert | finance-expert | Import/export taxes, shipping cost |
| logistics-expert | operations-expert | Domestic warehouse |
| logistics-expert | legal-expert | Carrier contracts |
| legal-expert | finance-expert | Payment terms trong contract |
| legal-expert | hr-expert | Employee contracts |
| legal-expert | operations-expert | Vendor/supplier contracts |
| legal-expert | sales-expert | Sales contracts |
| compliance-expert | legal-expert | Contract compliance |
| compliance-expert | finance-expert | Financial controls |
| compliance-expert | hr-expert | HR compliance |
| ecommerce-expert | finance-expert | Payment processing |
| ecommerce-expert | operations-expert | Inventory sync |
| ecommerce-expert | logistics-expert | Shipping integration |
| ecommerce-expert | marketing-expert | Marketing campaigns |
| ecommerce-expert | customer-expert | Customer data |
| retail-expert | finance-expert | Payment processing |
| retail-expert | operations-expert | Inventory optimization |
| retail-expert | marketing-expert | Customer loyalty |
| retail-expert | ecommerce-expert | E-commerce integration |
| retail-expert | logistics-expert | Supply chain |
| manufacturing-expert | procurement-expert | Raw material procurement |
| manufacturing-expert | operations-expert | Inventory management |
| manufacturing-expert | compliance-expert | Quality compliance |
| manufacturing-expert | finance-expert | Cost accounting |
| procurement-expert | finance-expert | Payment terms |
| procurement-expert | legal-expert | Contract legal terms |
| procurement-expert | operations-expert | Inventory impact |
| procurement-expert | logistics-expert | Import logistics |
| healthcare-expert | finance-expert | Medical billing |
| healthcare-expert | hr-expert | HR for medical staff |
| healthcare-expert | compliance-expert | Compliance/privacy |
| customer-expert | sales-expert | Sales handoff |
| customer-expert | marketing-expert | Marketing campaigns |
| customer-expert | product-expert | Product feedback |
| customer-expert | finance-expert | Billing issues |
| product-expert | marketing-expert | Marketing GTM |
| product-expert | sales-expert | Sales enablement |
| product-expert | data-expert | Analytics needs |
| product-expert | customer-expert | Customer feedback patterns |
| data-expert | finance-expert | Financial metrics |
| data-expert | sales-expert | Sales analytics |
| data-expert | marketing-expert | Marketing metrics |
| paid-media-expert | marketing-expert | Organic marketing strategy |
| paid-media-expert | ecommerce-expert | E-commerce paid campaigns |
| paid-media-expert | data-expert | Attribution dashboards |
| paid-media-expert | finance-expert | Budget allocation, ROI reporting |
| strategy-expert | finance-expert | Financial consolidation, M&A financials |
| strategy-expert | legal-expert | M&A legal documents, shareholder agreements |
| strategy-expert | enterprise-risk-expert | Strategic risk framework, ERM governance |
| strategy-expert | data-expert | Executive KPI dashboards, board reporting |
| real-estate-expert | legal-expert | BĐS contracts, sổ đỏ/sổ hồng legal review |
| real-estate-expert | compliance-expert | AML trong giao dịch bất động sản |
| real-estate-expert | finance-expert | Escrow, revenue recognition, BĐS accounting |
| investment-expert | compliance-expert | UBCKNN regulatory filing, securities compliance |
| investment-expert | legal-expert | Fund legal documents, LPA, investment agreements |
| investment-expert | enterprise-risk-expert | Market risk, liquidity risk framework |
| insurance-expert | compliance-expert | Health/medical data privacy, bảo hiểm compliance |
| insurance-expert | legal-expert | Claim dispute, policy wording, insurance contracts |
| insurance-expert | finance-expert | Premium/reserve accounting, actuarial |
| education-expert | hr-expert | Teacher payroll, academic staff management |
| education-expert | finance-expert | Tuition fee, scholarship accounting |
| education-expert | compliance-expert | Child data privacy, FERPA, educational regulations |

### 3.2 Engineering Team

| Agent | Phoi hop voi | Tinh huong |
|-------|-------------|-----------|
| architect | developer | Technical design va coding standards |
| architect | frontend-developer | BFF strategy va API contracts |
| architect | mobile-developer | Mobile-specific API patterns |
| architect | dba | Database technology choice |
| architect | data-engineer | Data architecture, platform choices |
| architect | devops | Infrastructure, deployment strategy |
| architect | security | Security architecture review |
| developer | architect | Nhan technical design |
| developer | frontend-developer | API contracts, shared types |
| developer | dba | ORM usage, N+1 detection, query patterns |
| developer | code-reviewer (Testing) | Submit code cho review |
| developer | devops | Deployment pipeline |
| frontend-developer | architect | Technical design, BFF strategy |
| frontend-developer | mobile-developer | Shared components, responsive strategies |
| frontend-developer | developer | API contracts, shared types |
| frontend-developer | devops | Build pipeline, CDN, deployment |
| mobile-developer | architect | Nhan technical design |
| mobile-developer | frontend-developer | Shared components/APIs |
| mobile-developer | devops | CI/CD mobile pipeline |
| ai-engineer | architect | ML infrastructure vs system architecture |
| ai-engineer | data-engineer | Data pipelines, feature stores |
| ai-engineer | ai-data-remediation-engineer | Data cleaning, PII removal |
| ai-engineer | devops | ML serving, GPU provisioning |
| ai-engineer | security | Model endpoints, data access security |
| ai-data-remediation-engineer | ai-engineer | Data quality for training |
| ai-data-remediation-engineer | data-engineer | Pipeline infrastructure, data contracts |
| ai-data-remediation-engineer | security | Air-gapped processing, PII handling |
| ai-data-remediation-engineer | architect | Remediation pipeline vs architecture |
| data-engineer | dba | Schema design, indexing for DWH |
| data-engineer | data-expert (Business) | Analytics requirements cho Gold layer |
| data-engineer | architect | Data architecture, cloud platform |
| data-engineer | devops | Pipeline scheduling, monitoring |
| dba | architect | Database technology choice |
| dba | developer | ORM usage, query patterns |
| dba | data-engineer | Schema cho DWH, ETL targets |
| dba | devops | Backup, connection pool, monitoring |
| devops | architect | Deployment topology |
| devops | sre | SLO-based deployment gates |
| devops | security | Security scanning integration |
| sre | architect | User journeys can SLO |
| sre | devops | Deployment, infrastructure observability |
| sre | security | Audit trail, compliance monitoring |
| security | architect | Security architecture, zero-trust |
| security | developer | Remediation voi code examples |
| security | devops | Container security, IaC review, CI/CD security |
| security | dba | Database access controls, encryption |
| tech-writer | developer | Code logic, API behavior, breaking changes |
| tech-writer | architect | Architectural decisions |
| tech-writer | qa-lead (Testing) | Behavior da verified |
| tech-writer | devops | Deployment docs |
| automation-architect | architect | API integration design |
| automation-architect | data-engineer | Data pipeline automation |
| automation-architect | devops | Deployment automation |
| automation-architect | security | Security cho automation workflows |
| automation-architect | business-analyst (Business) | Business process analysis |
| embedded-engineer | architect | System-level design, hardware-software co-design |
| embedded-engineer | developer | Firmware-to-app bridge (REST API, WebSocket, MQTT) |
| embedded-engineer | devops | CI/CD pipeline cho firmware build va flash |
| embedded-engineer | security | Firmware security review (secure boot, flash encryption) |
| embedded-engineer | qa-lead (Testing) | Embedded test strategy, HIL test plan |

### 3.3 Design Team

| Agent | Phoi hop voi | Tinh huong |
|-------|-------------|-----------|
| ux-designer | brand-guardian | Brand guidelines check |
| ux-designer | ux-researcher | User research data |
| ux-designer | ux-architect | CSS architecture handoff |
| ux-designer | ui-designer | Visual design specs |
| ui-designer | brand-guardian | Brand consistency |
| ui-designer | ux-designer | UX specs va user flows |
| ui-designer | ux-architect | Component CSS architecture |
| ui-designer | frontend-developer (Engineering) | Component implementation |
| ux-architect | ux-designer | Design specs |
| ux-architect | ui-designer | Visual design tokens |
| ux-architect | frontend-developer (Engineering) | CSS implementation handoff |
| brand-guardian | ux-designer | Brand-aligned UX |
| brand-guardian | ui-designer | Inclusive visual standards |
| brand-guardian | image-prompt-engineer | Brand-aligned imagery review |
| ux-researcher | ux-designer | Research findings cho design |
| ux-researcher | product-expert (Business) | Product feedback patterns |
| ux-researcher | customer-expert (Business) | Customer journey data |
| image-prompt-engineer | inclusive-visuals-specialist | Representation accuracy |
| image-prompt-engineer | brand-guardian | Brand-aligned imagery |
| image-prompt-engineer | ux-designer | Visual assets |
| image-prompt-engineer | ux-researcher | User perception feedback |
| inclusive-visuals-specialist | brand-guardian | Brand-aligned representation |
| inclusive-visuals-specialist | ux-designer | Inclusive visual standards |
| inclusive-visuals-specialist | ui-designer | Inclusive visual standards |
| inclusive-visuals-specialist | image-prompt-engineer | Pre-publishing review |
| inclusive-visuals-specialist | accessibility-auditor (Testing) | Representation issues audit |

### 3.4 Testing Team

| Agent | Phoi hop voi | Tinh huong |
|-------|-------------|-----------|
| qa-lead | evidence-collector | Visual evidence cho QA assessment |
| qa-lead | api-tester | API testing chuyen sau |
| qa-lead | accessibility-auditor | Accessibility audit |
| qa-lead | performance-benchmarker | Performance benchmarking |
| qa-lead | code-reviewer | Code quality review truoc testing |
| qa-lead | integration-certifier | Final deployment certification |
| code-reviewer | security (Engineering) | Lo hong bao mat nghiem trong |
| code-reviewer | performance-benchmarker | Performance bottleneck |
| code-reviewer | architect (Engineering) | Architecture concern |
| code-reviewer | qa-lead | Test coverage thieu |
| api-tester | security (Engineering) | Lo hong bao mat API |
| api-tester | performance-benchmarker | Performance bottleneck |
| api-tester | architect (Engineering) | API design can redesign |
| api-tester | qa-lead | Tich hop vao test plan |
| accessibility-auditor | ux-designer (Design) | Design tokens can audit |
| accessibility-auditor | developer (Engineering) | Component ARIA implementation |
| accessibility-auditor | security (Engineering) | Accessibility tao lo hong bao mat |
| accessibility-auditor | qa-lead | Accessibility test cases |
| accessibility-auditor | compliance-expert (Business) | Yeu cau phap ly accessibility |
| performance-benchmarker | api-tester | API performance issues |
| performance-benchmarker | dba (Engineering) | Database bottleneck |
| performance-benchmarker | devops (Engineering) | Infrastructure scaling |
| performance-benchmarker | sre (Engineering) | Infrastructure scaling |
| performance-benchmarker | frontend-developer (Engineering) | Frontend CWV optimize |
| performance-benchmarker | qa-lead | Tich hop metrics vao quality |
| evidence-collector | qa-lead | Tich hop evidence vao test plan |
| evidence-collector | integration-certifier | Certification decision |
| evidence-collector | accessibility-auditor | Accessibility visual evidence |
| evidence-collector | developer (Engineering) | Issues can fix |
| evidence-collector | frontend-developer (Engineering) | Issues can fix |
| integration-certifier | evidence-collector | Visual evidence cross-validate |
| integration-certifier | performance-benchmarker | Performance data cho SLA |
| integration-certifier | qa-lead | Pre-certification quality |
| integration-certifier | code-reviewer | Code quality assessment |
| integration-certifier | devops (Engineering) | Deployment infrastructure check |
| model-qa | ai-engineer (Engineering) | Model architecture issues |
| model-qa | data-engineer (Engineering) | Data pipeline problems |
| model-qa | sre (Engineering) | Production monitoring gaps |
| model-qa | security (Engineering) | Security concerns |
| reality-checker | evidence-collector | Visual evidence cross-validation |
| reality-checker | qa-lead | Quality assessment tong the |
| reality-checker | integration-certifier | Technical integration cert |
| reality-checker | developer (Engineering) | Issues can fix |
| reality-checker | frontend-developer (Engineering) | Issues can fix |
| reality-checker | devops (Engineering) | Deployment readiness |

### 3.5 Review Team

| Agent | Phoi hop voi | Tinh huong |
|-------|-------------|-----------|
| review-orchestrator | agent-auditor | Kiem tra agent definitions |
| review-orchestrator | skill-auditor | Kiem tra skill definitions |
| review-orchestrator | template-auditor | Kiem tra templates |
| review-orchestrator | cross-reference-auditor | Kiem tra cross-component references |
| review-orchestrator | workflow-auditor | Kiem tra workflow integrity |
| agent-auditor | review-orchestrator | Tong hop ket qua audit |
| agent-auditor | cross-reference-auditor | Knowledge routing paths cross-validate |
| agent-auditor | skill-auditor | Agent reference skill names verify |
| skill-auditor | review-orchestrator | Tong hop ket qua audit |
| skill-auditor | template-auditor | Skill reference template paths verify |
| skill-auditor | agent-auditor | Skill reference agent names verify |
| skill-auditor | cross-reference-auditor | Skill-to-skill references cross-validate |
| template-auditor | review-orchestrator | Tong hop ket qua audit |
| template-auditor | skill-auditor | Skill reference template verify nguon |
| template-auditor | cross-reference-auditor | Template paths trong agents cross-check |
| cross-reference-auditor | review-orchestrator | Tong hop ket qua audit |
| cross-reference-auditor | agent-auditor | Broken agent reference context |
| cross-reference-auditor | skill-auditor | Broken skill reference context |
| cross-reference-auditor | template-auditor | Broken template reference context |
| workflow-auditor | review-orchestrator | Tong hop ket qua audit |
| workflow-auditor | skill-auditor | Skill definition verify chi tiet |
| workflow-auditor | cross-reference-auditor | Skill names verify current vs deprecated |

---

## 4. Nguyen tac Coordination chung

### 4.1 Khi nao huy dong agent khac

- Phat hien cross-domain signal cu the (khong mo ho)
- Agent hien tai KHONG CO expertise can thiet cho van de
- Output can input tu domain khac de dam bao chat luong
- Van de anh huong truc tiep den domain cua agent khac

### 4.2 Khi nao KHONG huy dong

- Chi can tra cuu knowledge file (doc thay vi invoke agent)
- Van de nam trong pham vi expertise cua agent hien tai
- Coordination se tao circular dependency (A goi B goi A)
- Van de da duoc giai quyet trong output truoc do

### 4.3 Escalation Path

```
Agent → Team Lead → Orchestrator → User

Team Leads:
- Business: business-analyst
- Engineering: architect
- Design: ux-designer
- Testing: qa-lead
- Review: review-orchestrator
```

### 4.4 Quy tac cap nhat file nay

```
1. Khi THEM agent moi:
   - Them vao Section 1 (Agent Directory)
   - Them coordination entries vao Section 2 hoac 3
   - Tao agent file voi section Coordination tro ve file nay

2. Khi XOA agent:
   - Xoa khoi Section 1
   - Xoa tat ca entries lien quan trong Section 2 va 3
   - Xoa agent file

3. Khi DOI TEN agent:
   - Cap nhat tat ca entries trong file nay
   - Cap nhat agent file
```
