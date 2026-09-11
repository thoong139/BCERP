# Agent Prompt Templates — wf-analyze-requirements

> **Mục đích file:** Concrete agent prompt templates cho mọi `Agent({...})` call trong `wf-analyze-requirements`. Tuân thủ CORE-037 (8 sections). Skill spawn BA + 1-3 domain experts theo project type.

---

## 1. Agents skill này spawn

| Phase | Agent | subagent_type | Vai trò | Spawn count |
|-------|-------|--------------|---------|-------------|
| Phase 3 (Part A) | Business Analyst chính | `business-analyst` | Phân tích cross-domain, BR, NFR, stakeholder map | 1 |
| Phase 3.5 (LEGACY) | Legacy data analyst | `business-analyst` | Đọc extracted data từ `wf-legacy-extract` | 1 |
| Phase 4 (Part B) | Domain Expert (1-3) | varies (xem §2) | Phân tích domain-specific requirements | 1-3 (auto-detect từ project type) |
| Phase 6 (Conflict) | BA + relevant expert | `business-analyst` + domain | Resolve conflict giữa stakeholder views | 2-3 |
| Phase 6c (Stakeholder Review) | Multi-perspective agent | `business-analyst` | Generate Phần B/C/D stakeholder review | 2-3 |

**Concurrency:** Phase 4 spawn 1-3 experts PARALLEL. Phase 3 + 3.5 sequential.

---

## 2. Domain Expert Dispatch Logic

**24 domain experts** trong `.claude/agents/business/`:

| Project type indicator | Expert agent (subagent_type) |
|------------------------|------------------------------|
| Healthcare, EMR, EHR, bệnh viện | `healthcare-expert` |
| Finance, kế toán, ERP Finance, GL/AR/AP | `finance-expert` |
| HR, payroll, nhân sự, tuyển dụng | `hr-expert` |
| Insurance, bảo hiểm, policy, claims | `insurance-expert` |
| Investment, fund, portfolio, NAV | `investment-expert` |
| Real estate, BĐS, property | `real-estate-expert` |
| Education, LMS, e-learning, đào tạo | `education-expert` |
| E-commerce, marketplace, cart | `ecommerce-expert` |
| Retail, POS, chuỗi cửa hàng | `retail-expert` |
| Manufacturing, MES, BOM | `manufacturing-expert` |
| Logistics, vận chuyển, hải quan | `logistics-expert` |
| Sales, CRM, pipeline, quote | `sales-expert` |
| Marketing, campaign, lead, SEO | `marketing-expert` |
| Paid media, PPC, ads, ROAS | `paid-media-expert` |
| Procurement, vendor, RFQ | `procurement-expert` |
| Operations, inventory, supply chain | `operations-expert` |
| Customer support, CX, helpdesk | `customer-expert` |
| Compliance, regulatory, AML, GDPR | `compliance-expert` |
| Enterprise risk, ERM, COSO | `enterprise-risk-expert` |
| Quality excellence, QMS, Six Sigma | `quality-excellence-expert` |
| Legal, contract, NDA, e-signature | `legal-expert` |
| Strategy, OKR, M&A, board | `strategy-expert` |
| Product, roadmap, MVP, backlog | `product-expert` |
| Data analytics, BI, dashboard, KPI | `data-expert` |

**Auto-detect logic** (Phase 1 Scope):
- Đọc `phase0-brainstorm/idea-spec.md`
- Match keywords trong `description`, `industry`, `domain` fields
- Top 1-3 matches → spawn experts cho Phase 4

---

## 3. Template — Business Analyst (Phase 3 Part A)

```
# 1. ROLE DECLARATION
Bạn là **business-analyst** chính cho skill `wf-analyze-requirements` (Phase 3 Part A —
Cross-domain Analysis: BR, NFR, stakeholder map, business workflows).

# 2. TASK INSTRUCTION
Đọc:
- `.claude/skills/workflow/wf-analyze-requirements/SKILL.md`
- `.claude/skills/workflow/wf-analyze-requirements/procedures/phase3-ba-parta.md`
- `.claude/agents/business/business-analyst.md` (role definition)
- `phase0-brainstorm/idea-spec.md` (project context)

Task:
- Identify business requirements (BR) cross-domain
- Define NFR (performance, security, scalability, availability)
- Map stakeholders (decision makers, users, beneficiaries)
- Document business workflows top-level

KHÔNG được:
- Phân tích domain-specific deep — đó là việc của domain expert (Phase 4)
- Tạo feature specs — đó là việc của wf-define-features
- Modify req-registry.json — chỉ orchestrator (main thread) ghi

# 3. SESSION CONTEXT
SESSION_DIR: $SESSION_DIR
PROJECT_TYPE: $PROJECT_TYPE (healthcare|finance|hr|...)
INTERFACE_TYPE: $INTERFACE_TYPE (web|mobile|api-only|...)
LEGACY_MODE: $LEGACY_MODE (true if legacy extracted data exists)
TIMESTAMP: $(date -Iseconds)

# 4. CI CONTEXT INJECTION
$CI_CONTEXT
# Recommend: Grep keyword "BR", "NFR" trong existing docs nếu có
# Recommend: Read existing phase1-business/* files (incremental analysis)

# 5. PLAYWRIGHT CONTEXT
N/A — analysis-only phase, không có UI test.

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
|------|--------|----------|
| $SESSION_DIR/phase3-ba/business-requirements.md | — (md) | ✅ |
| $SESSION_DIR/phase3-ba/nfr.md | — (md) | ✅ |
| $SESSION_DIR/phase3-ba/stakeholder-map.md | — (md) | ✅ |
| $SESSION_DIR/phase3-ba/workflows.md | — (md) | ✅ |
| $SESSION_DIR/phase3-ba/Phase3-report.md | — (md, ≤15 dòng) | ✅ |

# 7. OWNERSHIP RULES
OWNER: 5 file trên trong $SESSION_DIR/phase3-ba/
KHÔNG modify: req-registry.json, $SESSION_DIR/phase4-experts/*, error-ledger.json
KHÔNG ghi domain-specific content (HR-specific, Finance-specific) — để Phase 4 expert làm

# 8. COMPLETION CRITERIA
✅ 4 file BR/NFR/stakeholder/workflows non-empty (≥50 lines mỗi cái)
✅ Phase3-report.md viết tiếng Việt ≤15 dòng (CORE-028)
✅ Báo cáo:
   PHASE_3_BA_STATUS=PASS|FAIL
   PHASE_3_BA_OUTPUTS=business-requirements.md,nfr.md,stakeholder-map.md,workflows.md,Phase3-report.md
   PHASE_3_BA_NEXT=phase4-experts
```

---

## 4. Template — Domain Expert (Phase 4 Part B)

Same 8 sections, populate per expert:

```
# 1. ROLE: $EXPERT_TYPE (e.g., hr-expert, finance-expert)
# 2. TASK: Phân tích {domain} requirements specific cho project, dựa vào BR/NFR từ Phase 3
# 3. SESSION: $SESSION_DIR/phase4-experts/$EXPERT_TYPE/
# 6. OUTPUT: 
#    - $SESSION_DIR/phase4-experts/$EXPERT_TYPE/domain-requirements.md
#    - $SESSION_DIR/phase4-experts/$EXPERT_TYPE/compliance-checklist.md (nếu domain có regulatory)
#    - $SESSION_DIR/phase4-experts/$EXPERT_TYPE/Phase4-{expert}-report.md
# 7. OWNERSHIP: KHÔNG ghi files của expert khác, KHÔNG modify Phase 3 outputs
# 8. PASS criteria: domain-requirements.md ≥80 lines, có ít nhất 5 specific requirements
```

**Concurrency rule:** Spawn parallel — 1 file = 1 writer (mỗi expert có folder con riêng).

---

## 5. Template — Conflict Resolution Agent (Phase 6d)

```
# 1. ROLE: business-analyst (conflict resolver) — orchestrate conflict resolution giữa BR + domain requirements
# 2. TASK: Đọc Phase 3 BA outputs + Phase 4 expert outputs → identify conflicts → propose resolutions
# 6. OUTPUT: $SESSION_DIR/phase6d-conflict/conflicts-resolved.md + conflicts-pending.md (cần user)
# 7. OWNERSHIP: KHÔNG modify Phase 3/Phase 4 source files — chỉ tạo NEW file
# 8. ESCALATION: nếu có Critical conflict → AskUserQuestion ("BR nói X, expert nói Y — bạn quyết?")
```

---

## 6. Anti-patterns specific cho wf-analyze-requirements

❌ **Phase 4 spawn TẤT CẢ 24 experts** — chỉ spawn 1-3 theo dispatch logic §2
❌ **Domain expert ghi cross-domain content** — chỉ ghi trong scope domain mình
❌ **BA Phase 3 ghi feature specs** — đó là việc của wf-define-features
❌ **Skip Phase 3.5 trong LEGACY mode** — phải đọc extracted data trước Phase 4
❌ **Modify req-registry.json từ agent** — registry write CHỈ ở Phase 8 main thread

---

## 7. Liên kết

- Canonical template: [`../_template/agent-prompt.md`](../_template/agent-prompt.md)
- Domain expert pool: [`../../../.claude/agents/business/`](../../../.claude/agents/business/) (24 files)
- BA agent definition: [`../../../.claude/agents/business/business-analyst.md`](../../../.claude/agents/business/business-analyst.md)
- Architecture: [`03-architecture.md`](03-architecture.md) — multi-agent dispatch matrix
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
