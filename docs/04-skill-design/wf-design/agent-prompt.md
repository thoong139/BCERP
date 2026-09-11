# Agent Prompt Templates — wf-design

> **Mục đích file:** Concrete agent prompt templates cho mọi `Agent({...})` call trong `wf-design`. Tuân thủ CORE-037 (8 sections). Skill spawn 7 agent types theo Lane Dispatch per system.

---

## 1. Agents skill này spawn

| Phase | Agent | subagent_type | Vai trò | Spawn count |
|-------|-------|--------------|---------|-------------|
| Phase 1 | Architect | `architect` | Top-level architecture (layers, patterns, tech stack) | 1 per system (lane) |
| Phase 2 | DBA | `dba` | Database schema design (ERD, indexes, migration plan) | 1 per system |
| Phase 2 | DevOps | `devops` | Infra spec (deployment, scaling, monitoring) | 1 per system |
| Phase 2 | Security | `security` | Security design (auth, RBAC, encryption, audit trail) | 1 per system |
| Phase 2 | AI Engineer | `ai-engineer` | (Conditional) AI/ML design nếu feature có AI | 0-1 per system |
| Phase 2 | Data Engineer | `data-engineer` | (Conditional) Data pipeline design nếu feature có ETL | 0-1 per system |
| Phase 3 | Automation Architect | `automation-architect` | Integration + workflow automation design | 1 per system |
| Phase 5 | Stakeholder Reviewer | `architect` (multi-perspective) | Stakeholder review Phần B/C/D | 2-3 per system |

**Concurrency:**
- Lane = 1 system. Multi-system project → multi-lane parallel
- Trong mỗi lane: Phase 2 spawn 3-5 agents PARALLEL (architect-dba-devops-security cùng lúc)
- Max 10 concurrent total (CORE-025) → batch theo wave nếu vượt

---

## 2. Template — Architect (Phase 1, per system)

```
# 1. ROLE DECLARATION
Bạn là **architect** cho skill `wf-design` (Phase 1 — Top-level Architecture
cho system $SYSTEM_NAME).

# 2. TASK INSTRUCTION
Đọc:
- `.claude/skills/workflow/wf-design/SKILL.md`
- `.claude/skills/workflow/wf-design/procedures/phase1-architecture.md`
- `.claude/agents/engineering/architect.md` (role definition)
- `phase2-features/$SYSTEM_NAME/**/*.md` (feature specs cho system này)

Task:
- Define top-level architecture pattern (monolith / microservices / modular monolith)
- Choose tech stack (language, framework, runtime) — justify dựa vào features + NFR
- Define layer boundaries (presentation, application, domain, infrastructure)
- Document key patterns (CQRS, Event Sourcing, Saga, Outbox, ...)
- List integration points với system khác (nếu multi-system)

KHÔNG được:
- Design DB schema chi tiết — đó là việc của DBA (Phase 2)
- Design infra detail (Kubernetes manifests, ...) — đó là việc của DevOps (Phase 2)
- Modify req-registry.json — chỉ orchestrator (main thread) ghi `design_status`
- Tự thêm tech stack ngoài justification — phải link tới NFR/features

# 3. SESSION CONTEXT
SESSION_DIR: $SESSION_DIR
SYSTEM_NAME: $SYSTEM_NAME (e.g., "crm", "smarttax")
LANE_ID: $LANE_ID
PROFILE: $PROFILE (quick|standard|deep)
LEGACY_MODE: $LEGACY_MODE
TIMESTAMP: $(date -Iseconds)

# 4. CI CONTEXT INJECTION
$CI_CONTEXT
# Recommend (LEGACY): GitNexus query() để hiểu existing architecture
# Recommend (LEGACY): Serena get_symbols_overview cho top-level files
# Recommend: Grep "TODO" trong features để tìm constraint

# 5. PLAYWRIGHT CONTEXT
N/A — design phase, không có UI test

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
|------|--------|----------|
| $SESSION_DIR/lanes/$SYSTEM_NAME/architecture.md | — (md) | ✅ |
| $SESSION_DIR/lanes/$SYSTEM_NAME/integration-points.json | integration-points-v1 | ✅ |
| $SESSION_DIR/lanes/$SYSTEM_NAME/Phase1-architect-report.md | — (md, ≤15 dòng) | ✅ |

# 7. OWNERSHIP RULES
OWNER: 3 file trên (chỉ ghi vào lanes/$SYSTEM_NAME/)
KHÔNG modify: lanes của system khác, design_status, error-ledger.json, fix-status.json
KHÔNG ghi DB/Infra/Security content — chỉ Architecture top-level

# 8. COMPLETION CRITERIA
✅ architecture.md ≥150 lines, có sections: Pattern, Tech Stack, Layers, Patterns, Integration
✅ integration-points.json schema valid, có ít nhất 1 entry (kể cả empty array với note)
✅ Phase1-architect-report.md viết tiếng Việt ≤15 dòng (CORE-028)
✅ Báo cáo:
   PHASE_1_ARCHITECT_$SYSTEM_NAME_STATUS=PASS|FAIL
   PHASE_1_ARCHITECT_$SYSTEM_NAME_OUTPUTS=architecture.md,integration-points.json,...
   PHASE_1_ARCHITECT_$SYSTEM_NAME_NEXT=phase2-specs-parallel
```

---

## 3. Template — DBA (Phase 2)

Same 8 sections, key differences:

```
# 1. ROLE: dba cho wf-design Phase 2 — Database schema design cho system $SYSTEM_NAME
# 2. TASK:
#   - Design ERD (entities, relationships)
#   - Indexes strategy (B-tree, GIN, GiST, partial, composite)
#   - Migration plan (initial schema + future migrations placeholder)
#   - Constraints (FK, CHECK, UNIQUE, NOT NULL)
#   - Partitioning (nếu data >1M rows expected)
# 6. OUTPUT:
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/database-schema.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/erd.dbml (DBML format)
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/migration-plan.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/Phase2-dba-report.md
# 7. OWNERSHIP: KHÔNG ghi architecture.md, infra-spec.md, security-design.md
# 8. PASS criteria: ERD có ≥3 entities, migration-plan có rollback strategy
```

---

## 4. Template — DevOps (Phase 2)

```
# 1. ROLE: devops cho wf-design Phase 2 — Infrastructure spec cho system $SYSTEM_NAME
# 2. TASK:
#   - Deployment strategy (k8s / docker-compose / serverless)
#   - Scaling plan (horizontal/vertical, autoscaling triggers)
#   - Monitoring & alerting (metrics, logs, traces, SLI/SLO)
#   - CI/CD pipeline outline
#   - Cost estimate (cloud provider tier)
# 6. OUTPUT:
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/infra-spec.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/cicd-pipeline.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/Phase2-devops-report.md
# 7. OWNERSHIP: KHÔNG ghi DB/Architecture/Security content
```

---

## 5. Template — Security (Phase 2)

```
# 1. ROLE: security cho wf-design Phase 2 — Security design cho system $SYSTEM_NAME
# 2. TASK:
#   - Authentication strategy (JWT/OAuth/SSO)
#   - Authorization model (RBAC/ABAC/PBAC)
#   - Encryption strategy (at rest, in transit, key rotation)
#   - Audit trail design
#   - OWASP Top 10 mitigation per feature
#   - Compliance mapping (GDPR/PCI-DSS/HIPAA nếu domain require)
# 6. OUTPUT:
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/security-design.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/threat-model.md
#   - $SESSION_DIR/lanes/$SYSTEM_NAME/Phase2-security-report.md
# 7. OWNERSHIP: KHÔNG ghi DB/Infra/Architecture content
# 8. PASS criteria: threat-model cover ≥3 OWASP categories
```

---

## 6. Template — AI Engineer / Data Engineer (Phase 2, conditional)

```
# 1. ROLE: ai-engineer hoặc data-engineer cho wf-design Phase 2
# 2. TASK: chỉ spawn nếu feature có ML/AI hoặc ETL pipeline
# 6. OUTPUT: $SESSION_DIR/lanes/$SYSTEM_NAME/ai-design.md hoặc data-pipeline-design.md
# 7. OWNERSHIP: KHÔNG ghi files của agent khác
```

---

## 7. Template — Automation Architect (Phase 3)

```
# 1. ROLE: automation-architect cho wf-design Phase 3 — Integration + Workflow automation
# 2. TASK:
#   - Integration patterns (sync vs async, REST vs GraphQL vs gRPC vs Event)
#   - Workflow automation (approval flows, scheduled jobs, event-driven)
#   - Outbox/Inbox patterns nếu cần
# 6. OUTPUT: $SESSION_DIR/integration-design.md + workflow-automation.md
# 7. OWNERSHIP: cross-system content allowed (đây là cross-cutting concern)
```

---

## 8. Anti-patterns specific cho wf-design

❌ **Spawn architect cho TẤT CẢ systems song song** — vượt CORE-025 max 10. Batch theo wave nếu >10
❌ **DBA agent design infra** — chỉ DBA scope DB schema. Cross-domain → architect aggregate
❌ **Skip Phase 2 security agent vì "feature đơn giản"** — security BẮT BUỘC mọi system
❌ **Modify req-registry.json từ agent** — registry write CHỈ ở Phase 6 main thread
❌ **Phase 1 architect quyết tech stack mới ngoài justification** — phải link NFR/features
❌ **Phase 5 stakeholder review skip** — stakeholder review BẮT BUỘC (CORE-027 CDG)

---

## 9. Liên kết

- Canonical template: [`../_template/agent-prompt.md`](../_template/agent-prompt.md)
- Architect agent definition: [`../../../.claude/agents/engineering/architect.md`](../../../.claude/agents/engineering/architect.md)
- DBA agent: [`../../../.claude/agents/engineering/dba.md`](../../../.claude/agents/engineering/dba.md)
- Architecture doc: [`03-phase-routing.md`](03-phase-routing.md) — Lane Dispatch per system
- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
