# Agent Prompt Templates — wf-cmi (CORE-037)

> **Mục đích file:** Template chuẩn cho mọi `Agent({subagent_type, prompt})` call trong skill `wf-cmi`. Đảm bảo 8 sections BẮT BUỘC + ownership rules + completion criteria rõ ràng.

---

## 1. Agent spawn map (4 phases có spawn)

| Phase | Agents spawn | Concurrency |
|-------|-------------|-------------|
| Phase 2 — Discovery | Optional: `architect` cho LLM-assisted parse (rare) | 1 |
| Phase 3 — Invariant Registry (3-pass) | `architect` (Pass 1) + 2-5 `{domain}-experts` (Pass 2) + `business-analyst` (Pass 3) | Max 5 (leave 5 budget cho Phase 4 retry) |
| Phase 4 — Coverage Dispatch (chính) | **v2.0:** 26 active lane agents — 1 agent/lane, dispatch 3-WAVE (W1=10/W2=10/W3=6). §3-12 cho v1 lanes CD1-CD10 (Carry-over). §13-15 cho v2 NEW lanes CD38/CD39/CD40 (sub-stage 4.6 ★). §16-18 cho v2 logistics-critical lanes CD28/CD30/CD31 (sub-stage 4.4 ★★★ — Wave 2). §19-22 cho v2 lanes CD11/CD13/CD15/CD18 (sub-stage 4.1 — FE component + FE↔BE contract + UI permission + CQRS pipeline). §23-24 cho v2 BE deep lanes CD16/CD17 (sub-stage 4.2 — Domain Logic Integrity + Persistence Consistency, Wave 1). §25-28 cho v2 UX lanes CD23/CD24/CD25/CD26 (sub-stage 4.3 — Design System + Display Format + Flow Continuity + Workflow Visibility, W2 + W3). §29-30 cho v2 compliance lanes CD29/CD37 (sub-stage 4.5 — Audit Trail Completeness W3 + Regulatory Compliance W2 ★★★ cross-border VN+CN+intl). **Stage 4 đóng hoàn toàn 18/18 lanes có procedure file + design canon.** | Max 10 / wave (CORE-025) |
| Phase 7 — GAP + CDG | `business-analyst` + 1-3 `{domain}-experts` cho gap suggestions | Max 3 |

**Tổng spawn per session tối đa (v2.0 deep profile, 26 lanes):** ~40 agents (Phase 3 + 4 × 3 waves + 7), concurrent max 10/wave.

---

## 2. Cấu trúc 8 sections BẮT BUỘC (CORE-037)

Mọi prompt phải có đầy đủ 8 sections theo thứ tự:

```markdown
# 1. ROLE DECLARATION (BẮT BUỘC)
Bạn là **{agent-role}** cho skill `wf-cmi` (Phase {N} — {phase-name}, Lane {lane-id nếu Phase 4}).

# 2. TASK INSTRUCTION (BẮT BUỘC)
Đọc file `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi đầy đủ {phase task} theo procedure file `.claude/skills/workflow/wf-cmi/procedures/phase{N}-{name}.md`.

KHÔNG được:
- Thay đổi scope ngoài {task}
- Đọc/ghi files ngoài $SESSION_DIR (trừ SSOT registry read-only nếu cần)
- Spawn sub-agent (chỉ orchestrator được phép)
- Tự ghi `integrity-status.json`, `error-ledger.json`, `session-log.json` (helper functions only)

# 3. SESSION CONTEXT (BẮT BUỘC)
- SESSION_DIR: {session-dir}
- PROFILE: {quick|standard|deep|exhaustive}
- SCOPE: {system|module=X|feat=Y}
- DIMS_ACTIVE: {array of CDX}
- NAME: {feat-id|module-id|context-name}
- TIMESTAMP: {ISO 8601}
- AUTHOR: {git_user_email + git_user_name}

# 4. CI CONTEXT INJECTION (CONDITIONAL — nếu CI available)
$CI_CONTEXT
# Format: GITNEXUS_AVAILABLE=true|false, SERENA_AVAILABLE=true|false,
#         INDEX_FRESHNESS=ok|light|strong|severe, FALLBACK_TOOL=Grep|Glob

Routing tool ưu tiên cho lane này:
- {tool 1} → primary
- {tool 2} → fallback

# 5. PLAYWRIGHT CONTEXT (CONDITIONAL — wf-cmi v1 KHÔNG dùng Playwright)
Skill wf-cmi KHÔNG runtime test — bỏ section này hoặc set PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT (BẮT BUỘC)
| # | Output path | Schema | Required | Note |
|---|-------------|--------|----------|------|
| 1 | $SESSION_DIR/phase{N}-{name}/{output1}.json | {schema-vN} | ✅ | Atomic write |
| 2 | $SESSION_DIR/phase{N}-{name}/Phase{N}-report.md | — (md) | ✅ | Tiếng Việt ≤15 dòng |

Mọi output PHẢI:
- Atomic write pattern (.tmp.$$ → validate → mv)
- Pass POST-GATE T1→T4 (xem `04-file-contract.md` §2)
- KHÔNG ghi đè output của agent khác (1 file = 1 writer)

# 7. OWNERSHIP RULES (BẮT BUỘC)
- File này là OWNER của: {list output paths}
- KHÔNG modify: $SESSION_DIR/integrity-status.json (orchestrator owns)
- KHÔNG modify: $SESSION_DIR/error-ledger.json (write qua helper `record_error()`)
- KHÔNG modify: $SESSION_DIR/session-log.json (append qua helper `log_phase_*()`)
- Registry update: chỉ orchestrator Phase 7 (KHÔNG được sửa req-registry.json từ lane agent)

# 8. COMPLETION CRITERIA (BẮT BUỘC)
{task} HOÀN THÀNH khi:
- ✅ Tất cả output ở §6 tồn tại + pass POST-GATE T1→T4
- ✅ Phase{N}-report.md viết tiếng Việt ≤15 dòng (CORE-028)
- ✅ Không có error CRITICAL trong `error-ledger.json`
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator format:
```
PHASE_{N}_LANE_{lane-id}_STATUS=PASS|FAIL
PHASE_{N}_LANE_{lane-id}_OUTPUTS={comma-separated paths}
PHASE_{N}_LANE_{lane-id}_SIGNAL_COUNT={N}
PHASE_{N}_LANE_{lane-id}_NEXT={next phase name | null}
```
```

---

## 3. Lane CD1 — Business Domain Coverage

**Agent:** `business-analyst` (orchestrator) + spawn 2-5 `{domain}-experts` parallel

```python
Agent({
  "subagent_type": "business-analyst",
  "description": "Lane CD1 — Business domain coverage",
  "model": "opus",
  "prompt": """
# 1. ROLE
Bạn là **business-analyst** cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD1 Business domain coverage).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD1 theo `procedures/phase4-coverage-dispatch.md` §Lane CD1.

Mục tiêu lane CD1:
- Kiểm tra mọi business domain/module có ≥1 invariant đăng ký trong `business-invariants.json` (Phase 3 output)
- Phát hiện modules thiếu domain compliance rules (vd Finance thiếu GAAP/IFRS Vietnam check, Customs thiếu HS Code validation)
- Sinh signals cho mỗi domain coverage gap

KHÔNG được:
- Tự ghi invariants vào registry (orchestrator Phase 7 only)
- Spawn sub-agent (xin orchestrator nếu cần domain expert)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD1-business-domain
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Domain knowledge lookup → Read team-expert/{domain}/*.md
- Module-domain mapping → Read registry .requirements[].department
- Code domain detection → Grep + Read (LLM context)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v1 không dùng Playwright)

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD1/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD1/Phase4-report.md | — md | ✅ |

Signal kinds expected:
- MISSING_DOMAIN_INVARIANT — domain X có 0 invariants registered
- MISSING_COMPLIANCE_CHECK — domain X thiếu compliance rule (GDPR, HS Code, GAAP, ...)
- DOMAIN_RULE_VIOLATION — code A vi phạm rule domain B

# 7. OWNERSHIP RULES
OWNER: 2 file trên.
KHÔNG modify: integrity-status.json, business-invariants.json, registry.

# 8. COMPLETION CRITERIA
Lane CD1 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ Phase4-report.md tiếng Việt ≤15 dòng
- ✅ Mọi signal có fingerprint unique + dim="CD1"

Báo cáo:
PHASE_4_LANE_CD1_STATUS=PASS|FAIL
PHASE_4_LANE_CD1_OUTPUTS=signals.json,Phase4-report.md
PHASE_4_LANE_CD1_SIGNAL_COUNT={N}
PHASE_4_LANE_CD1_NEXT=phase5-aggregate
"""
})
```

---

## 4. Lane CD2 — Entity Dependency Coverage

**Agent:** `architect` + `dba`

```markdown
# 1. ROLE
Bạn là **architect** (chính) + `dba` (consultant) cho Lane CD2 Entity dependency coverage.

# 2. TASK
Kiểm tra `entity-graph.json` (Phase 2 output):
- Mọi entity quan trọng (aggregate roots) có dependency graph node
- Mọi entity có ownership rõ (BoundedContext + Module)
- Phát hiện orphan entities (không thuộc module nào)
- Phát hiện FK references không enforce (vd Order.CustomerId không có FK constraint)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD2/signals.json (schema signals-v1)
$SESSION_DIR/phase4-coverage/lanes/CD2/Phase4-report.md

Signal kinds:
- ORPHAN_ENTITY — entity không thuộc module/aggregate root
- MISSING_FK_ENFORCEMENT — FK reference không có DB constraint
- UNCLEAR_OWNERSHIP — entity có ≥2 module claim ownership
```

---

## 5. Lane CD3 — Workflow Coverage

**Agent:** `architect` + `business-analyst`

```markdown
# 1. ROLE
Bạn là **architect** cho Lane CD3 Workflow coverage.

# 2. TASK
Kiểm tra `workflow-graph.json`:
- Mọi business workflow có start state + end state rõ
- Trace end-to-end: từ command → handler → repository → DB → response
- Phát hiện workflow dangling (state không có outgoing transition trừ END)
- Phát hiện workflow corruption (event handler thiếu)

CHÚ Ý EUREKA pattern: MediatR pipeline (Logging → Caching → Validation → AuditLog → Transaction)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD3/signals.json

Signal kinds:
- DANGLING_STATE — state không có outgoing transition
- MISSING_EVENT_HANDLER — event không có consumer
- WORKFLOW_TRACE_GAP — không trace được end-to-end
```

---

## 6. Lane CD4 — API Contract Coverage

**Agent:** `api-tester` + `architect`

```markdown
# 1. ROLE
Bạn là **api-tester** cho Lane CD4 API contract coverage.

# 2. TASK
Kiểm tra `api-graph.json`:
- Mọi public API endpoint có request schema (FluentValidation) + response schema (DTO)
- Phân biệt 3 clients: erp-web (`/api/v1/{module}/`), mobile-customer (`/api/v1/customer/mobile/`), mobile-staff (`/api/v1/{module}/mobile/` hoặc `/api/v1/staff/mobile/{module}/`)
- Phát hiện endpoint thiếu schema, thiếu authorization, thiếu identity enforcement (customer mobile)
- Phát hiện endpoint không tuân thủ CORE convention (vd customer mobile thiếu `CustomerMobile` prefix)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD4/signals.json

Signal kinds:
- MISSING_REQUEST_SCHEMA
- MISSING_RESPONSE_SCHEMA
- MISSING_AUTH
- MISSING_IDENTITY_CHECK (customer mobile)
- NAMING_CONVENTION_VIOLATION
```

---

## 7. Lane CD5 — Event Coverage

**Agent:** `architect` + `data-engineer`

```markdown
# 1. ROLE
Bạn là **architect** cho Lane CD5 Event coverage. SKIP nếu profile=quick.

# 2. TASK
Kiểm tra `event-graph.json`:
- Mọi domain event có producer rõ
- Mọi domain event có ≥1 consumer (handler)
- Propagation path đầy đủ (vd OrderCreated → 4 SignalR hubs + RabbitMQ queue → 3 consumers)
- Phát hiện event orphan (no consumer) hoặc event ghost (consumer reference event không tồn tại)

EUREKA infra: SignalR (4 hubs: dashboard, tracking, notifications, orders) + RabbitMQ 3

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD5/signals.json

Signal kinds:
- EVENT_ORPHAN (no consumer)
- EVENT_GHOST (consumer ref non-existent event)
- PROPAGATION_INCOMPLETE
```

---

## 8. Lane CD6 — Permission/RBAC Coverage

**Agent:** `security` + `business-analyst`

```markdown
# 1. ROLE
Bạn là **security** cho Lane CD6 RBAC coverage. SKIP nếu profile=quick.

# 2. TASK
Kiểm tra `rbac-matrix.json`:
- Mọi resource có RBAC matrix đầy đủ (actor × action × resource)
- Mọi action có ít nhất 1 role được phép (không hỏng default deny)
- Phát hiện permission orphan (defined nhưng không ai dùng)
- Phát hiện gap: customer mobile endpoint thiếu identity check (CUSTOMER role chỉ truy cập data của chính mình)

EUREKA: 90+ permissions format `{module}.{resource}.{action}` (vd `crm.customers.view`)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD6/signals.json

Signal kinds:
- MISSING_PERMISSION
- PERMISSION_ORPHAN
- IDENTITY_CHECK_MISSING
- OVERSCOPED_ROLE (role có quyền không cần thiết)
```

---

## 9. Lane CD7 — Data Integrity Coverage

**Agent:** `dba` + `data-engineer`

```markdown
# 1. ROLE
Bạn là **dba** cho Lane CD7 Data integrity coverage.

# 2. TASK
Kiểm tra:
- Mọi FK reference được enforce trong EF Core configurations
- Mọi unique constraint được declare (vd `Customer.Email`, `Employee.TaxCode`)
- Mọi NOT NULL constraint khớp DDD requirement
- Phát hiện schema drift: code Domain/Entities ≠ EF Core configurations ≠ migrations

EUREKA: PostgreSQL schema-per-module pattern, EurekaDbContext UNIFIED (ADR-001)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD7/signals.json

Signal kinds:
- FK_NOT_ENFORCED
- UNIQUE_CONSTRAINT_MISSING
- NOT_NULL_MISSING
- SCHEMA_DRIFT
```

---

## 10. Lane CD8 — Observability Coverage

**Agent:** `sre` + `devops`

```markdown
# 1. ROLE
Bạn là **sre** cho Lane CD8 Observability coverage. SKIP nếu profile ∈ {quick, standard}.

# 2. TASK
Kiểm tra:
- Mọi critical path (Commands liên quan tiền/security/auth) có log structured (Serilog)
- Mọi critical path có metric (Prometheus)
- Mọi critical path có trace (cross-service)
- Health-check endpoint có cho 17 modules
- Alert rules cho HIGH-IMPACT events

EUREKA: Serilog → Seq, Prometheus + Grafana + Alertmanager, Sentry

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD8/signals.json

Signal kinds:
- MISSING_LOG
- MISSING_METRIC
- MISSING_TRACE
- MISSING_HEALTH_CHECK
- MISSING_ALERT_RULE
```

---

## 11. Lane CD9 — Regression Coverage

**Agent:** `qa-lead` + `architect`

```markdown
# 1. ROLE
Bạn là **qa-lead** cho Lane CD9 Regression coverage. SKIP nếu profile=quick.

# 2. TASK
Kiểm tra (cần `regression-map.json` từ Phase 6 hoặc git history):
- Mọi affected module có test plan tương ứng
- Test plan đầy đủ types (unit + integration + e2e)
- Phát hiện affected modules không có test files
- Cross-ref test coverage với requirements impl_status

EUREKA tests: tests/backend/Eureka.{UnitTests,IntegrationTests,ArchitectureTests}, apps/erp-web/e2e (Playwright)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD9/signals.json

Signal kinds:
- TEST_MISSING_FOR_AFFECTED_MODULE
- TEST_COVERAGE_INSUFFICIENT
- TEST_OUTDATED (test exists nhưng không match current schema)
```

---

## 12. Lane CD10 — Documentation Coverage

**Agent:** `tech-writer` + `business-analyst`

```markdown
# 1. ROLE
Bạn là **tech-writer** cho Lane CD10 Documentation coverage. SKIP nếu profile ∈ {quick, standard}.

# 2. TASK
Kiểm tra:
- Mọi invariant trong `business-invariants.json` có doc tiếng Việt (CORE-005)
- Mọi cross_module_dependency có ghi chú nghiệp vụ
- Mọi REQ-ID trong registry có phase1-business/[dept].md mention
- Phát hiện stale docs (doc reference REQ-ID đã `skipped`/`deleted`)
- i18n consistency: vi/en/zh keys khớp nhau (EUREKA: 18K+ keys/locale)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase4-coverage/lanes/CD10/signals.json

Signal kinds:
- MISSING_DOC_VIETNAMESE
- STALE_DOC_REF
- I18N_KEY_MISMATCH
- INVARIANT_NOT_DOCUMENTED
```

---

## 13. Lane CD38 — UI Implementation Coverage ★ NEW (v2.0)

**Agent:** `ux-researcher` (chính) + `frontend-developer` + `business-analyst`
**Wave:** 3 (final cross-ref — cần Wave 1+2 graphs đã build)
**Effort:** 3 ngày (sub-stage 4.6)

**Graph dependencies (Phase 2):**
- `fe-api-client-graph.json` (Plugin #8, Stage 2.1) — RQ hooks + Refit + raw fetch
- `fe-permission-graph.json` (Plugin #9, Stage 2.1) — PermissionGate/usePermission/Can/hasPermission
- `fe-route-graph.json` (Plugin #10, Stage 2.1) — Next.js App Router pages/layouts/middleware

**SSOT dependency:** `.mc-data/docs/_meta/ui-interactivity-spec.json` (template tại `plans/wf-cmi/ui-interactivity-spec.eureka-template.json`). Thiếu → E144 ESCALATE.

```markdown
# 1. ROLE
Bạn là **ux-researcher** (chính) + tham vấn `frontend-developer` + `business-analyst` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD38 UI Implementation Coverage ★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD38 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 3.

Mục tiêu lane CD38 — đo độ phủ giữa BACKEND code và FRONTEND implementation:

1. **Orphan API check** — Cross-ref `fe-api-client-graph.json` vs `api-graph.json`:
   - Endpoint classified `user_facing` trong `ui-interactivity-spec.json` mà 0 FE caller sau `grace_period_days` (default 14d) → ORPHAN_API_ENDPOINT
   - Endpoint user_facing nhưng client-specific (vd customer mobile gọi endpoint không phép trong `should_consume`) → MISSING_UI_FOR_USER_FACING_API
2. **CRUD UI completeness** — Mỗi entity trong `crud_required_entities[]`:
   - Resolve UI page paths (Create/Read/Update/Delete/List) trong `fe-route-graph.json`
   - Thiếu 1 trong các CRUD operation đã declared → INCOMPLETE_CRUD_UI (severity MEDIUM-HIGH)
   - Bỏ qua entities trong `crud_optional_entities[]`
3. **Permission UI mapping** — Cross-ref `permission_ui_mapping[]` vs `fe-permission-graph.json`:
   - Permission được grant cho role trong `rbac-permission-catalog.json` nhưng KHÔNG có UI element (button/menu/fab) → MISSING_PERMISSION_UI_ELEMENT
4. **Workflow state UI trigger** — Cross-ref `workflow_user_actions{}` vs `workflow-state-machines.json` + UI routes:
   - State requires_user_action nhưng không có UI button/form tương ứng → WORKFLOW_STATE_NO_UI_TRIGGER (severity CRITICAL — block user)

CHÚ Ý:
- Áp dụng `grace_period_days` cho endpoints deploy mới (< 14d không flag)
- Strict/lenient mode theo `config.strict_crud_check` (default strict)
- Mobile clients (mobile-customer/mobile-staff): chỉ check trong `client_specific.<client>.should_consume` scope (v2.0 mặc định skip mobile — chỉ scan erp-web)

KHÔNG được:
- Spawn sub-agent (orchestrator chỉ pre-spawn ở Phase 3)
- Modify SSOT `ui-interactivity-spec.json` (read-only)
- Mark deprecated endpoints/permissions là violation (chúng có flow riêng — REVERSE_ORPHAN_UI)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD38-ui-implementation-coverage
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- FE API caller resolution → đọc `fe-api-client-graph.json` (primary) → Grep `useQuery\|useMutation\|fetch\|axios` (fallback)
- UI route resolution → đọc `fe-route-graph.json` (primary) → Glob `apps/erp-web/app/**/page.tsx` (fallback)
- Permission UI mapping → đọc `fe-permission-graph.json` (primary) → Grep `<PermissionGate>\|usePermission` (fallback)
- BE API endpoint → đọc `api-graph.json` (Phase 2 core)
- RBAC catalog → Read `.mc-data/docs/_meta/rbac-permission-catalog.json` (SSOT)
- Workflow state machines → Read `.mc-data/docs/_meta/workflow-state-machines.json` (SSOT)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test; coverage analyzed via graphs).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD38-ui-implementation-coverage/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD38-ui-implementation-coverage/CD38-ui-implementation-coverage-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `ORPHAN_API_ENDPOINT` — Endpoint user_facing có 0 FE caller sau grace period
- `MISSING_UI_FOR_USER_FACING_API` — Endpoint có ý định user-facing nhưng client KHÔNG được phép consume
- `INCOMPLETE_CRUD_UI` — Entity declared CRUD nhưng thiếu UI page (vd `/customer/[id]/edit` không tồn tại)
- `MISSING_PERMISSION_UI_ELEMENT` — Permission có role grant nhưng không có UI element render
- `WORKFLOW_STATE_NO_UI_TRIGGER` — State workflow_user_action nhưng không có button/form tương ứng

Mỗi signal có `rule_id` format `UI-CD38-{NNN}` mapping vào `validation_rules[].id` trong `ui-interactivity-spec.json`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json (helper functions only), SSOT files, registry.

# 8. COMPLETION CRITERIA
Lane CD38 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4 (schema signals-v1, dim="CD38", fingerprint unique)
- ✅ CD38-report.md tiếng Việt ≤15 dòng theo template `templates/CD-report.md`
- ✅ Mọi signal có `rule_id` hợp lệ + `affected_files[]` resolve được (file path tồn tại)
- ✅ Context budget <80%

Báo cáo về orchestrator:
PHASE_4_LANE_CD38_STATUS=PASS|FAIL
PHASE_4_LANE_CD38_OUTPUTS=signals.json,CD38-ui-implementation-coverage-report.md
PHASE_4_LANE_CD38_SIGNAL_COUNT={N}
PHASE_4_LANE_CD38_NEXT=phase5-aggregate
```

---

## 14. Lane CD39 — Error UX & Recovery ★ NEW (v2.0)

**Agent:** `ux-designer` (chính) + `frontend-developer`
**Wave:** 3
**Effort:** 3 ngày (sub-stage 4.6)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7, Stage 2) — Component tree để detect error boundary placement
- `fe-route-graph.json` (Plugin #10, Stage 2.1) — Route-level `error.tsx`, `not-found.tsx` coverage

**SSOT dependency:** `.mc-data/docs/_meta/error-code-catalog.json` (template tại `plans/wf-cmi/error-code-catalog.eureka-template.json`). Thiếu → E147 WARN (fallback heuristic).

```markdown
# 1. ROLE
Bạn là **ux-designer** (chính) + tham vấn `frontend-developer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD39 Error UX & Recovery ★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD39 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 3.

Mục tiêu lane CD39 — đảm bảo trải nghiệm lỗi nhân văn + có lối thoát:

1. **Error boundary placement** — Cross-ref `fe-component-graph.json` + `fe-route-graph.json`:
   - Mỗi route segment (page hoặc layout) PHẢI có `error.tsx` cùng cấp HOẶC cấp cha → thiếu → MISSING_ERROR_BOUNDARY
   - Root layout PHẢI có `global-error.tsx` cho Next.js App Router
2. **Raw error leak detection** — Grep code FE:
   - `error.message` render trực tiếp lên UI mà KHÔNG qua catalog mapping → RAW_ERROR_LEAKED_TO_USER (severity HIGH — bảo mật + UX)
   - `console.error` xuất ra UI (vd `toast(err.message)`) → RAW_ERROR_LEAKED_TO_USER
3. **Recovery action coverage** — Cross-ref `error-code-catalog.json` `recovery_actions[]`:
   - Mỗi error code trong catalog có `recovery_action` declared nhưng UI KHÔNG render action button (retry/go-back/contact-support) → MISSING_RECOVERY_ACTION
4. **Vietnamese message check** — Mỗi error code phải có `display_messages.vi` populated:
   - Render fallback `en` hoặc raw code → ERROR_MESSAGE_NOT_VIETNAMESE (CORE-005 violation)
5. **Display consistency** — Mỗi error severity có UI pattern declared (vd CRITICAL=modal+block, HIGH=toast-red, MEDIUM=inline-warn):
   - Code render khác pattern → INCONSISTENT_ERROR_DISPLAY

CHÚ Ý EUREKA pattern:
- Backend trả `Result<T>.Error` với `code` + `category` — UI map qua `error-code-catalog.json`
- Toast notifications dùng sonner/react-hot-toast
- Modal errors dùng shadcn `<AlertDialog>`

KHÔNG được:
- Spawn sub-agent
- Modify SSOT `error-code-catalog.json`
- Flag warnings trong dev-only files (`*.dev.tsx`, `**/_dev/**`)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD39-error-ux-recovery
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Error boundary detection → Read `fe-route-graph.json` (filesystem) → Glob `apps/erp-web/app/**/error.tsx`
- Error message rendering → Grep `error\.message\|err\.message\|\.error\.code` trong `apps/erp-web/`
- Catalog lookup → Read `.mc-data/docs/_meta/error-code-catalog.json` (SSOT)
- Component error patterns → đọc `fe-component-graph.json` cho component hierarchy

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD39-error-ux-recovery/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD39-error-ux-recovery/CD39-error-ux-recovery-report.md | — (md ≤15 dòng) | ✅ |

Signal kinds expected:
- `MISSING_ERROR_BOUNDARY` — Route segment thiếu error.tsx
- `RAW_ERROR_LEAKED_TO_USER` — Error.message render trực tiếp (security + UX risk)
- `MISSING_RECOVERY_ACTION` — Error code có recovery_action declared nhưng UI thiếu
- `ERROR_MESSAGE_NOT_VIETNAMESE` — Thiếu display_messages.vi hoặc fallback en
- `INCONSISTENT_ERROR_DISPLAY` — UI pattern không khớp catalog severity

Mỗi signal có `rule_id` format `ERR-CD39-{NNN}`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên.
KHÔNG modify: integrity-status.json, error-ledger.json, SSOT, registry, error-code-catalog.json.

# 8. COMPLETION CRITERIA
Lane CD39 HOÀN THÀNH khi:
- ✅ signals.json pass POST-GATE T1→T4, dim="CD39"
- ✅ CD39-report.md tiếng Việt ≤15 dòng
- ✅ SSOT file `error-code-catalog.json` đã load (nếu thiếu → log E147 WARN, continue với fallback Grep)

Báo cáo:
PHASE_4_LANE_CD39_STATUS=PASS|FAIL
PHASE_4_LANE_CD39_OUTPUTS=signals.json,CD39-error-ux-recovery-report.md
PHASE_4_LANE_CD39_SIGNAL_COUNT={N}
PHASE_4_LANE_CD39_NEXT=phase5-aggregate
```

---

## 15. Lane CD40 — Print & Export Consistency ★ NEW (v2.0)

**Agent:** `ui-designer` (chính) + `frontend-developer` + `tech-writer`
**Wave:** 3
**Effort:** 4 ngày (sub-stage 4.6 — logistics document-heavy)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7) — Detect print/export components (PdfRenderer, ExcelExport, etc.)
- `fe-route-graph.json` (Plugin #10) — Find print preview routes (`/invoice/[id]/print`, `/customs/[id]/declaration-pdf`)
- `api-graph.json` (Phase 2 core) — BE endpoints trả PDF/Excel binary (vd `GET /api/invoice/{id}/pdf`)

**SSOT dependency:** `.mc-data/docs/_meta/print-export-templates.json` (template tại `plans/wf-cmi/print-export-templates.eureka-template.json`). Thiếu → E148 WARN (fallback scan templates).

```markdown
# 1. ROLE
Bạn là **ui-designer** (chính) + tham vấn `frontend-developer` + `tech-writer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD40 Print & Export Consistency ★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD40 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 3.

Mục tiêu lane CD40 — đảm bảo tài liệu in/xuất nhất quán brand + đầy đủ dữ liệu (logistics-critical: invoice, BOL, customs declaration, packing list, COO):

1. **Template drift check** — Cross-ref `print-export-templates.json` `doc_templates[]`:
   - Mỗi `doc_template` declared (vd `invoice-vn`, `bol`, `customs-declaration-vn`, `packing-list`) phải có file template thực tế trong project
   - Template thực tế có fields khác declared `required_fields[]` → PRINT_TEMPLATE_DRIFT (severity MEDIUM-HIGH cho compliance docs)
2. **Font availability** — Mỗi PDF template phải declare `fonts[]` đầy đủ:
   - Font Vietnamese (vd `Times New Roman`, `Arial Unicode MS`) phải bundled trong project hoặc cộng tác system
   - Thiếu → PDF_FONT_MISSING (CRITICAL cho VN/CN documents)
3. **Excel formula integrity** — Cross-ref `doc_templates[].excel_formulas[]`:
   - Formula reference cell range không tồn tại trong template → EXCEL_FORMULA_BROKEN
4. **Brand consistency** — Mỗi doc template phải có `branding{logo, address, tax_code, hotline}` đầy đủ:
   - Logo path không resolve hoặc thiếu → BRAND_LOGO_MISSING_DOC (CRITICAL cho external-facing docs invoice/BOL)
5. **Export data integrity** — Cross-ref BE export endpoints vs UI list view:
   - Excel export endpoint trả N cột nhưng UI list view show M cột khác → EXPORT_DATA_MISMATCH_UI (M ≠ N → user confused)
   - Default sort/filter trong UI KHÔNG được preserve khi export → EXPORT_DATA_MISMATCH_UI

CHÚ Ý EUREKA logistics docs:
- Invoice tuân thủ Thông tư 78/2021/TT-BTC (e-invoice VN) — required fields: số serial, mã CQT, signing certificate
- Customs declaration VNACCS có format chuẩn (XML + PDF)
- BOL bilingual VN+EN+CN — phải có CN translation cho receiver
- Logo + tax code + business license cần render đúng pixel

KHÔNG được:
- Spawn sub-agent
- Modify SSOT `print-export-templates.json`
- Flag dev-only print templates (`**/dev-templates/**`, `**/*.dev.html`)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD40-print-export-consistency
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Template file discovery → Glob `apps/backend/**/Templates/**/*.{html,liquid,hbs,xml}` + `apps/erp-web/templates/**/*`
- PDF/Excel export endpoints → đọc `api-graph.json` filter `Content-Type: application/pdf|spreadsheet`
- Component print/export → đọc `fe-component-graph.json` filter name match `Pdf*|Excel*|Export*|Print*`
- Catalog lookup → Read `.mc-data/docs/_meta/print-export-templates.json` (SSOT)
- Brand asset → Glob `apps/{backend,erp-web}/assets/{logo,brand}*`

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG render PDF runtime — chỉ analyze template files).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD40-print-export-consistency/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD40-print-export-consistency/CD40-print-export-consistency-report.md | — (md ≤15 dòng) | ✅ |

Signal kinds expected:
- `PRINT_TEMPLATE_DRIFT` — Template thực tế có fields khác declared
- `PDF_FONT_MISSING` — VN/CN font không bundled, render lỗi
- `EXCEL_FORMULA_BROKEN` — Cell reference không tồn tại
- `BRAND_LOGO_MISSING_DOC` — Logo/tax_code không có trong external-facing doc
- `EXPORT_DATA_MISMATCH_UI` — Export columns khác UI list columns

Mỗi signal có `rule_id` format `DOC-CD40-{NNN}`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên.
KHÔNG modify: integrity-status.json, error-ledger.json, SSOT, registry, print-export-templates.json, template files thực tế (read-only).

# 8. COMPLETION CRITERIA
Lane CD40 HOÀN THÀNH khi:
- ✅ signals.json pass POST-GATE T1→T4, dim="CD40"
- ✅ CD40-report.md tiếng Việt ≤15 dòng
- ✅ SSOT file `print-export-templates.json` đã load (nếu thiếu → E148 WARN, continue scan templates)
- ✅ Logistics-critical doc types (invoice, BOL, customs) ưu tiên check trước generic docs

Báo cáo:
PHASE_4_LANE_CD40_STATUS=PASS|FAIL
PHASE_4_LANE_CD40_OUTPUTS=signals.json,CD40-print-export-consistency-report.md
PHASE_4_LANE_CD40_SIGNAL_COUNT={N}
PHASE_4_LANE_CD40_NEXT=phase5-aggregate
```

---

## 16. Lane CD28 — MDM Consistency ★★★ NEW (v2.0 logistics-critical)

**Agent:** `data-engineer` (chính) + `dba` + `logistics-expert`
**Wave:** 2 (cross-layer — cần `entity-graph.json` + `be-db-schema-graph.json` Wave 1)
**Effort:** 5 ngày (sub-stage 4.4 — logistics-critical highest)

**Graph dependencies (Phase 2):**
- `entity-graph.json` (Phase 2 core #2) — Domain entity dependency edges + ownership module
- `be-db-schema-graph.json` (Plugin #12, Stage 2.2) — DB tables + columns + PKs + FKs + unique constraints
- `be-domain-graph.json` (Plugin #11, Stage 2.2) — DDD AggregateRoot + ValueObject + Repository — xác định canonical owner module
- `api-graph.json` (Phase 2 core #4) — endpoints CREATE/UPDATE master entities (multi-writer detection)

**SSOT dependency:** `.mc-data/docs/_meta/mdm-canonical-entities.json` (template tại `plans/wf-cmi/mdm-canonical-entities.eureka-template.json` — 11 master entities Carrier/Customer/Employee/Invoice/Order/...). Thiếu → E141 ESCALATE (lane KHÔNG chạy được nếu SSOT vắng — MDM rules cần explicit ownership declaration).

```markdown
# 1. ROLE
Bạn là **data-engineer** (chính) + tham vấn `dba` + `logistics-expert` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD28 MDM Consistency ★★★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD28 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD28 — đảm bảo tính nhất quán Master Data Management qua mọi modules (logistics-critical: Carrier mã 1 phải dùng chung cho Booking + Customs + Invoice; Customer code phải duy nhất xuyên CRM + Sales + AR):

1. **Canonical ownership check** — Mỗi master entity declared trong `mdm-canonical-entities.json.master_entities{}`:
   - `owner_module` field phải khớp module thực tế chứa AggregateRoot trong `be-domain-graph.json`
   - Modules khác CHỈ được tham chiếu qua FK (`be-db-schema-graph.json`) hoặc value-object snapshot, KHÔNG được redefine entity
   - Vi phạm → DUPLICATE_MASTER_ENTITY (severity HIGH)
2. **Unique key integrity** — Mỗi entity có `unique_keys[]` declared (vd Customer.tax_code unique national, Carrier.code unique global):
   - DB schema phải có UNIQUE constraint tương ứng (check `be-db-schema-graph.json` `indexes[]` với `unique=true`)
   - Thiếu UNIQUE index → MISSING_UNIQUE_CONSTRAINT (CRITICAL — duplicate risk)
   - Composite unique declared mà DB chỉ có single-column → PARTIAL_UNIQUE_CONSTRAINT
3. **Multi-writer detection** — Cross-ref `api-graph.json` POST/PUT/PATCH endpoints cho mỗi master entity:
   - Chỉ `owner_module` được phép CREATE entity (vd `Eureka.Modules.Crm.Customers` cho Customer)
   - Module khác CREATE entity master → UNAUTHORIZED_MASTER_WRITER (HIGH — bypass MDM governance)
   - UPDATE allowed nếu trong `ownership_rules.update_allowed_modules[]` (vd Sales được update Customer.credit_limit)
4. **Reference data drift** — Cross-ref `reference_data{}` (vd HS Code list, Currency codes, Country codes):
   - Reference data phải có 1 source-of-truth file/table declared
   - Nhiều bản copy reference data trong codebase → REFERENCE_DATA_DRIFT (vd 2 enum HS_CODE khác nhau)
5. **Cross-module entity consistency** — Cross-ref `sync_rules{}` (vd Customer sync CRM → AR within 5 min):
   - Sync endpoint/event declared trong SSOT phải có handler thực tế trong `be-cqrs-graph.json` (event subscription) hoặc scheduled job
   - Thiếu sync mechanism → MISSING_MDM_SYNC (severity MEDIUM-HIGH theo lag tolerance)

CHÚ Ý EUREKA logistics MDM:
- Carrier (hãng vận tải) là entity-of-record cho TẤT CẢ booking + customs + invoice — 1 carrier_id sai = lệch toàn bộ chuỗi
- Customer (chủ hàng) duplicated giữa CRM + AR là root cause #1 cho lệch công nợ
- HS Code (mã hàng hóa) phải sync từ Customs Module ra Pricing + Invoice — drift = sai thuế suất
- Tài liệu reference: TT 31/2022/TT-BTC (HS Code VN), HS Code CN 2024 (国家税务总局)

KHÔNG được:
- Spawn sub-agent (orchestrator chỉ pre-spawn Phase 3)
- Modify SSOT `mdm-canonical-entities.json` (read-only)
- Flag entities trong `mdm-canonical-entities.json.exclusions[]` (vd Audit logs, system tables)
- Flag legacy duplicate entities marked `deprecated_until: <date>` (compatibility window)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD28-mdm-consistency
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Entity ownership → đọc `be-domain-graph.json` filter `kind=aggregate_root` (primary) → Serena `find_symbol "AggregateRoot"` (fallback)
- DB schema constraints → đọc `be-db-schema-graph.json` `indexes[]` + `foreign_keys[]` (primary) → Grep EF Migration `HasIndex.IsUnique\|HasForeignKey` (fallback)
- API writer endpoints → đọc `api-graph.json` filter HTTP method POST/PUT/PATCH (primary)
- MDM catalog → Read `.mc-data/docs/_meta/mdm-canonical-entities.json` (SSOT)
- Reference data files → Glob `apps/backend/**/SeedData/**/*.{json,csv}` + Grep `enum.*HsCode\|enum.*Currency` (cross-validate single source)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — MDM consistency analyzed via graphs + SSOT cross-ref).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD28-mdm-consistency/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD28-mdm-consistency/CD28-mdm-consistency-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `DUPLICATE_MASTER_ENTITY` — Entity AggregateRoot trùng tên giữa 2+ modules (vi phạm canonical ownership)
- `MISSING_UNIQUE_CONSTRAINT` — Unique key declared trong SSOT nhưng DB không có UNIQUE index
- `PARTIAL_UNIQUE_CONSTRAINT` — Composite unique declared nhưng DB chỉ có single-column index
- `UNAUTHORIZED_MASTER_WRITER` — Module ngoài owner CREATE master entity (POST endpoint)
- `REFERENCE_DATA_DRIFT` — Reference data (HS Code/Currency/Country) có >1 source trong codebase
- `MISSING_MDM_SYNC` — Sync rule declared nhưng không có event handler/job triển khai

Mỗi signal có `rule_id` format `MDM-CD28-{NNN}` mapping vào `validation_rules[].id` trong `mdm-canonical-entities.json`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json (helper functions only), SSOT files, registry, DB migration files (read-only).

# 8. COMPLETION CRITERIA
Lane CD28 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4 (schema signals-v1, dim="CD28", fingerprint unique)
- ✅ CD28-report.md tiếng Việt ≤15 dòng theo template `templates/CD-report.md`
- ✅ SSOT `mdm-canonical-entities.json` đã load (nếu thiếu → E141 ESCALATE, lane FAIL — KHÔNG fallback heuristic)
- ✅ Mọi signal có `rule_id` hợp lệ + `affected_entities[]` resolve được trong `mdm-canonical-entities.json.master_entities{}`
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator:
PHASE_4_LANE_CD28_STATUS=PASS|FAIL
PHASE_4_LANE_CD28_OUTPUTS=signals.json,CD28-mdm-consistency-report.md
PHASE_4_LANE_CD28_SIGNAL_COUNT={N}
PHASE_4_LANE_CD28_NEXT=phase5-aggregate
```

---

## 17. Lane CD30 — Time & Numbering Integrity ★★★ NEW (v2.0 logistics-critical)

**Agent:** `architect` (chính) + `dba` + `logistics-expert`
**Wave:** 2 (cross-layer — cần `be-db-schema-graph.json` + `be-domain-graph.json` Wave 1)
**Effort:** 4 ngày (sub-stage 4.4 — logistics-critical)

**Graph dependencies (Phase 2):**
- `be-db-schema-graph.json` (Plugin #12, Stage 2.2) — DB columns datetime + sql_type (timestamp/timestamptz/date)
- `be-domain-graph.json` (Plugin #11, Stage 2.2) — Entity properties + value objects (DateTimeOffset vs DateTime)
- `be-cqrs-graph.json` (Plugin #13, Stage 2.2) — Command/query parameters chứa datetime (input boundary)
- `api-graph.json` (Phase 2 core #4) — Request/response datetime fields (API contract boundary)

**SSOT dependency:** `.mc-data/docs/_meta/workflow-state-machines.json` (numbering schemes per workflow vd Invoice/BOL/CustomsDeclaration) + `config.timezone_policy` + `config.numbering_schemes[]`. Thiếu → E142 ESCALATE (sequence rules cần explicit declaration).

```markdown
# 1. ROLE
Bạn là **architect** (chính) + tham vấn `dba` + `logistics-expert` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD30 Time & Numbering Integrity ★★★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD30 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD30 — đảm bảo:
(A) Time integrity — Mọi datetime nhất quán timezone-aware + chuẩn hóa UTC storage + đúng business timezone display
(B) Numbering integrity — Số chứng từ (Invoice, BOL, CustomsDeclaration, Quotation, Order) duy nhất + đúng format + đúng sequence rule (vd reset hàng năm/tháng)

1. **Timezone-aware datetime check** — Mỗi datetime column/property:
   - DB: PostgreSQL phải dùng `timestamptz` (timestamp with time zone) cho mọi business datetime, KHÔNG dùng `timestamp` naive (`be-db-schema-graph.json` columns.sql_type)
   - Domain: C# entity phải dùng `DateTimeOffset` thay vì `DateTime` cho audit fields (CreatedAt, UpdatedAt, OccurredAt) (`be-domain-graph.json` properties)
   - Vi phạm → NAIVE_DATETIME_STORAGE (HIGH — gây sai múi giờ khi serve client Việt Nam/Trung Quốc/quốc tế)
2. **Timezone consistency between layers** — Cross-ref API → Domain → DB:
   - API request/response datetime PHẢI ISO-8601 + offset (vd `2026-05-16T10:30:00+07:00`)
   - Backend convert sang UTC trước khi persist (check Domain layer DateTimeOffset usage)
   - DB store UTC (timestamptz luôn UTC offset)
   - Lệch giữa layers (vd API nhận local time nhưng DB lưu naive) → TIMEZONE_BOUNDARY_DRIFT
3. **Numbering scheme uniqueness** — Mỗi document type declared trong `config.numbering_schemes[]` (vd Invoice prefix `INV-{YYYY}-{NNNNNN}` reset annually):
   - DB column phải có UNIQUE constraint (check `be-db-schema-graph.json` indexes unique=true)
   - Thiếu UNIQUE → MISSING_NUMBERING_UNIQUE (CRITICAL — duplicate invoice number = vi phạm thuế VN)
4. **Numbering format compliance** — Cross-ref `numbering_schemes[].format_regex`:
   - Sequence generator code (Grep `NumberGenerator\|SequenceProvider\|NextNumber`) phải tuân thủ format regex
   - Mismatch format → NUMBERING_FORMAT_VIOLATION (vd Invoice không có YYYY → khó audit)
5. **Reset policy compliance** — `numbering_schemes[].reset_policy` (annually/monthly/never):
   - Sequence generator phải có logic reset tương ứng (vd query MAX number theo year + 1)
   - Thiếu reset logic khi declared → MISSING_NUMBERING_RESET (MEDIUM-HIGH compliance risk)
6. **Date-only vs datetime mismatch** — DB column `date` type vs domain `DateOnly` (.NET 6+):
   - Field phải đồng nhất giữa DB + domain (vd InvoiceDate là `date` thì entity phải `DateOnly`, KHÔNG `DateTime`)
   - Mismatch → DATE_TYPE_DRIFT (silent timezone bugs khi cast)

CHÚ Ý EUREKA logistics numbering:
- Invoice VN theo TT 78/2021/TT-BTC: mã CQT cấp + số serial duy nhất per năm tài chính
- Customs declaration VNACCS: mã tờ khai do hệ thống VNACCS cấp, KHÔNG được generate local
- BOL: numbering có thể theo hãng vận tải hoặc dùng global sequence — kiểm tra `numbering_schemes.BOL.source`
- Timezone Asia/Ho_Chi_Minh (UTC+7), Asia/Shanghai (UTC+8) — client display, nhưng storage UTC

KHÔNG được:
- Spawn sub-agent
- Modify SSOT `workflow-state-machines.json`
- Flag legacy columns marked `migration_pending: true` trong SSOT (grace period)
- Flag system-generated numbers (vd VNACCS_DeclarationNumber) đã có `external_source: true`

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD30-time-numbering-integrity
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Datetime column types → đọc `be-db-schema-graph.json` filter `sql_type IN (timestamp,timestamptz,date)` (primary)
- Entity datetime properties → đọc `be-domain-graph.json` properties filter type=`DateTime|DateTimeOffset|DateOnly` (primary) → Serena `find_symbol DateTime` (fallback)
- API datetime fields → đọc `api-graph.json` filter request/response.properties.format=`date-time|date` (primary)
- Numbering scheme generator → Grep `NumberGenerator\|SequenceProvider\|NextNumber\|InvoiceNumber` (no graph plugin v2.0)
- Timezone policy → Read `.mc-data/docs/_meta/workflow-state-machines.json` `config.timezone_policy` (SSOT)
- Numbering schemes catalog → Read `.mc-data/docs/_meta/workflow-state-machines.json` `config.numbering_schemes[]` (SSOT)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — datetime integrity analyzed static).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD30-time-numbering-integrity/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD30-time-numbering-integrity/CD30-time-numbering-integrity-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `NAIVE_DATETIME_STORAGE` — DB column `timestamp` (naive) hoặc entity property `DateTime` (không có offset)
- `TIMEZONE_BOUNDARY_DRIFT` — API/Domain/DB layer dùng datetime mismatch (vd API nhận local time nhưng persist naive)
- `MISSING_NUMBERING_UNIQUE` — Numbering column không có UNIQUE constraint trong DB
- `NUMBERING_FORMAT_VIOLATION` — Sequence generator không tuân thủ format_regex declared
- `MISSING_NUMBERING_RESET` — Reset policy declared (annually/monthly) nhưng code không reset
- `DATE_TYPE_DRIFT` — DB `date` vs domain `DateTime` (hoặc ngược lại)

Mỗi signal có `rule_id` format `TIME-CD30-{NNN}` mapping vào `validation_rules[].id` trong `workflow-state-machines.json`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json (helper functions only), SSOT files, registry, EF Migration files (read-only).

# 8. COMPLETION CRITERIA
Lane CD30 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4 (schema signals-v1, dim="CD30", fingerprint unique)
- ✅ CD30-report.md tiếng Việt ≤15 dòng theo template `templates/CD-report.md`
- ✅ SSOT `workflow-state-machines.json` đã load (nếu thiếu numbering schemes → E142 ESCALATE, lane FAIL)
- ✅ Mọi signal có `rule_id` hợp lệ + `affected_columns[]` hoặc `affected_properties[]` resolve được
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator:
PHASE_4_LANE_CD30_STATUS=PASS|FAIL
PHASE_4_LANE_CD30_OUTPUTS=signals.json,CD30-time-numbering-integrity-report.md
PHASE_4_LANE_CD30_SIGNAL_COUNT={N}
PHASE_4_LANE_CD30_NEXT=phase5-aggregate
```

---

## 18. Lane CD31 — Money & Tax Integrity ★★★ NEW (v2.0 logistics-critical)

**Agent:** `finance-expert` (chính) + `dba` + `architect`
**Wave:** 2 (cross-layer — cần `be-db-schema-graph.json` + `be-domain-graph.json` Wave 1)
**Effort:** 4 ngày (sub-stage 4.4 — logistics-critical)

**Graph dependencies (Phase 2):**
- `be-db-schema-graph.json` (Plugin #12, Stage 2.2) — DB columns numeric (decimal precision/scale)
- `be-domain-graph.json` (Plugin #11, Stage 2.2) — Money value object + Currency aggregate
- `be-cqrs-graph.json` (Plugin #13, Stage 2.2) — Commands/queries chứa money fields (boundary)
- `api-graph.json` (Phase 2 core #4) — Request/response money fields + currency declaration

**SSOT dependency:** `.mc-data/docs/_meta/mdm-canonical-entities.json` (`reference_data.currencies[]` + `reference_data.tax_rates[]`) + `.mc-data/docs/_meta/compliance-mapping.json` (VAT VN + import duty CN + IFRS rounding rules). Thiếu → E143 ESCALATE (money/tax cần regulatory declaration).

```markdown
# 1. ROLE
Bạn là **finance-expert** (chính) + tham vấn `dba` + `architect` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD31 Money & Tax Integrity ★★★).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD31 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD31 — đảm bảo:
(A) Money integrity — Mọi money field dùng decimal precision đúng + currency-aware + không bị implicit conversion sai số
(B) Tax integrity — Mọi tax calculation tuân thủ regulatory rules (VAT VN 8%/10%, VAT CN 13%, import duty per HS Code) + rounding rules + audit traceable

1. **Decimal precision check** — Mỗi money column trong DB (`be-db-schema-graph.json` filter `sql_type LIKE 'numeric%'|decimal'`):
   - Money declared trong `reference_data.currencies[]` với scale rules (VND scale=0, CNY/USD scale=2, gold scale=4)
   - DB column scale phải khớp currency rule → mismatch = WRONG_DECIMAL_SCALE (HIGH — silent rounding loss)
   - Money column dùng `float` hoặc `double` → CRITICAL_FLOAT_MONEY (CRITICAL — IEEE 754 không exact cho money)
2. **Money value object usage** — Cross-ref `be-domain-graph.json`:
   - Money fields phải dùng custom `Money` value object (chứa Amount + Currency), KHÔNG raw `decimal`
   - Raw decimal cho money field → MISSING_MONEY_VALUE_OBJECT (HIGH — mất currency context)
   - Money VO không có Currency field → INCOMPLETE_MONEY_TYPE
3. **Currency mismatch in calculation** — Cross-ref `be-cqrs-graph.json` commands:
   - Operations Add/Subtract money giữa 2 currencies khác nhau mà không qua FX conversion → CURRENCY_MISMATCH_RISK (HIGH — sai số phép tính)
   - Quote/Invoice có line items khác currency với header currency → MIXED_CURRENCY_HEADER
4. **Tax rate compliance** — Cross-ref `compliance-mapping.json.tax_regulations[]` (VAT VN 8%/10% theo Nghị quyết 142/2024/QH15, VAT CN 13%/9%/6%):
   - Tax rate hardcoded trong code (Grep `0.10\|0.08\|0.13\|VatRate`) phải khớp regulation effective date
   - Tax rate hết hạn (effective_until < today) → EXPIRED_TAX_RATE (CRITICAL — compliance vi phạm)
   - Tax calculation thiếu rounding rule (vd HALF_UP per Thông tư 80/2021/TT-BTC) → MISSING_ROUNDING_RULE
5. **Tax breakdown completeness** — Mỗi Invoice/Order phải có tax breakdown đầy đủ:
   - `subtotal + tax_amount = total` (check Domain invariant)
   - Tax breakdown phải có tax_code + tax_rate + tax_base + tax_amount per line (audit requirement)
   - Thiếu → INCOMPLETE_TAX_BREAKDOWN (HIGH — không pass tax audit)
6. **FX rate source traceability** — Currency conversion phải lưu FX rate + source + timestamp:
   - Code FX conversion (Grep `ExchangeRate\|FxRate\|ConvertCurrency`) không lưu `rate_source` + `rate_date` → MISSING_FX_AUDIT_TRAIL (HIGH — gold accounting requirement)
   - FX rate hardcoded → HARDCODED_FX_RATE (CRITICAL — phải gọi SBV/PBoC API hoặc store rate history)

CHÚ Ý EUREKA logistics money/tax:
- VND: scale=0 (không có cent), VND 100 = 100 (KHÔNG 100.00)
- CNY/USD: scale=2 (cent/fen)
- VAT VN 2024: 8% (giảm thuế per NQ 142/2024) hoặc 10% (chuẩn) — code phải check effective date
- VAT CN 2024: 13% (chuẩn), 9% (vận tải/nông sản), 6% (dịch vụ) — depend HS Code
- Import duty: theo HS Code + MFN rate (Most Favored Nation) — lookup table phải có effective date
- Rounding: VN Thông tư 80/2021 = HALF_UP, IFRS chuẩn = BANKERS_ROUNDING (HALF_TO_EVEN)
- FX rate VN: SBV daily rate (vnd-cny pair), thường lock T+1 cho invoice ngày T
- Customs valuation: theo Incoterms (FOB/CIF/EXW) + freight + insurance

KHÔNG được:
- Spawn sub-agent
- Modify SSOT (mdm-canonical-entities.json, compliance-mapping.json) — read-only
- Flag test fixtures money values (path `**/Tests/**`, `**/*Test*.cs`)
- Flag dev seed data money (path `**/SeedData/dev/**`)
- Flag historical migration data có `migration_grandfather: true` flag

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD31-money-tax-integrity
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Money DB columns → đọc `be-db-schema-graph.json` filter `sql_type LIKE 'numeric%'|decimal\|money` (primary)
- Money value object → đọc `be-domain-graph.json` filter `kind=value_object AND name=Money` (primary) → Serena `find_symbol Money` (fallback)
- Tax calculation code → Grep `TaxRate\|VatRate\|CalculateTax\|ApplyVat` (no graph plugin)
- FX conversion code → Grep `ExchangeRate\|FxRate\|ConvertCurrency\|ExchangeRateProvider` (no graph plugin)
- Currency rules → Read `.mc-data/docs/_meta/mdm-canonical-entities.json` `reference_data.currencies[]` (SSOT)
- Tax regulations → Read `.mc-data/docs/_meta/compliance-mapping.json` `tax_regulations[]` (SSOT)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — money/tax integrity analyzed static).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD31-money-tax-integrity/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD31-money-tax-integrity/CD31-money-tax-integrity-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `WRONG_DECIMAL_SCALE` — DB column scale không khớp currency rule (vd VND scale=2 thay vì 0)
- `CRITICAL_FLOAT_MONEY` — Money column dùng float/double (CRITICAL — luôn fail audit)
- `MISSING_MONEY_VALUE_OBJECT` — Money field dùng raw decimal, không có Money VO
- `INCOMPLETE_MONEY_TYPE` — Money VO thiếu Currency field
- `CURRENCY_MISMATCH_RISK` — Operations giữa 2 currencies không qua FX conversion
- `MIXED_CURRENCY_HEADER` — Invoice/Order header currency khác line items currency
- `EXPIRED_TAX_RATE` — Tax rate hardcoded đã quá effective_until
- `MISSING_ROUNDING_RULE` — Tax calculation không declare rounding strategy
- `INCOMPLETE_TAX_BREAKDOWN` — Tax breakdown thiếu tax_code/tax_rate/tax_base/tax_amount per line
- `MISSING_FX_AUDIT_TRAIL` — FX conversion không lưu rate_source + rate_date
- `HARDCODED_FX_RATE` — FX rate hardcoded (CRITICAL — phải từ SBV/PBoC API)

Mỗi signal có `rule_id` format `MONEY-CD31-{NNN}` (cho money) hoặc `TAX-CD31-{NNN}` (cho tax) mapping vào `validation_rules[].id` trong `compliance-mapping.json`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json (helper functions only), SSOT files, registry, EF Migration files, FX rate provider implementations (read-only).

# 8. COMPLETION CRITERIA
Lane CD31 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4 (schema signals-v1, dim="CD31", fingerprint unique)
- ✅ CD31-report.md tiếng Việt ≤15 dòng theo template `templates/CD-report.md`
- ✅ SSOT `mdm-canonical-entities.json` + `compliance-mapping.json` đã load (nếu thiếu → E143 ESCALATE, lane FAIL)
- ✅ Mọi tax rate signal cross-validated với `compliance-mapping.json.tax_regulations[].effective_from/until`
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator:
PHASE_4_LANE_CD31_STATUS=PASS|FAIL
PHASE_4_LANE_CD31_OUTPUTS=signals.json,CD31-money-tax-integrity-report.md
PHASE_4_LANE_CD31_SIGNAL_COUNT={N}
PHASE_4_LANE_CD31_NEXT=phase5-aggregate
```

---

## 19. Lane CD11 — FE Component Contracts (v2.0 Gói C++ — sub-stage 4.1)

**Agent:** `frontend-developer` (chính, không cần consult)
**Wave:** 1 (Phase 2 graphs only — không chờ lane khác)
**Effort:** 2 ngày (sub-stage 4.1 — simplest FE lane)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7, Stage 2 vertical slice) — Component nodes + props[] + import edges + module attribution

**SSOT dependency:** None mandatory (CD11 dùng heuristic + cross-component graph analysis; populate ux-conventions.json tăng độ chính xác nhưng KHÔNG block).

```markdown
# 1. ROLE
Bạn là **frontend-developer** cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD11 FE Component Contracts).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD11 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 1.

Mục tiêu lane CD11 — đảm bảo tính nhất quán React/Next.js component contracts trong `apps/erp-web`:

1. **Props type completeness** — Mỗi component node trong `fe-component-graph.json`:
   - props[] type không được là `any` hoặc `unknown` (vi phạm type safety)
   - props[] phải có `type` field không rỗng
   - Vi phạm → INCOMPLETE_PROPS_TYPE (severity SHOULD)
2. **Required flag accuracy** — Props không có default_value VÀ tên có pattern "id|name|value|on*|data" thường phải required:
   - Nếu required=false nhưng pattern match → MISSING_REQUIRED_FLAG (severity MAY — gợi ý, không cấm)
3. **Component naming consistency** — Cross-component naming:
   - Component name phải PascalCase (vd `CustomerCard` không `customer-card`)
   - Props name phải camelCase (vd `onSelect` không `OnSelect`/`on_select`)
   - File name kebab-case (vd `customer-card.tsx`)
   - Vi phạm → PROP_NAMING_INCONSISTENCY (severity SHOULD)
4. **Orphan component detection** — Cross-ref edges[]:
   - Component không xuất hiện ở bất kỳ edge `kind=imports` nào (tức là không component nào import)
   - VÀ không phải `default_export` của page/layout file
   - → ORPHAN_COMPONENT (severity MAY — có thể dead code)
5. **Duplicate component name** — Nodes filter cùng `name`:
   - 2+ component cùng tên ở khác `module` → DUPLICATE_COMPONENT_NAME (severity SHOULD — risk import nhầm)

CHÚ Ý EUREKA FE:
- v2.0 chỉ scan `apps/erp-web` (mobile-customer + mobile-staff defer v2.1)
- Component shared trong `apps/erp-web/components/shared/` được phép xuất hiện ở nhiều page imports — KHÔNG flag là duplicate
- Component `index.tsx` re-export pattern (vd `export { Button } from './button'`) là OK — KHÔNG flag

KHÔNG được:
- Spawn sub-agent
- Modify fe-component-graph.json (read-only)
- Flag components trong `exclusions[]` của ux-conventions.json (nếu có)
- Re-parse .tsx files (graph builder Phase 2 đã parse)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD11-fe-component-contracts
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Component graph → đọc `fe-component-graph.json` (primary) — KHÔNG re-parse
- UX conventions → Read `.mc-data/docs/_meta/ux-conventions.json` (optional, fallback default heuristic naming rules nếu thiếu)
- Cross-component import resolution → đã có trong `edges[]` graph

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — component contracts analyzed via static graph).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD11-fe-component-contracts/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD11-fe-component-contracts/CD11-fe-component-contracts-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `INCOMPLETE_PROPS_TYPE` — Props type là `any`/`unknown`/rỗng
- `MISSING_REQUIRED_FLAG` — Prop pattern thường required nhưng required=false
- `PROP_NAMING_INCONSISTENCY` — Component/prop/file name vi phạm convention
- `ORPHAN_COMPONENT` — Component không được import từ bất kỳ component khác
- `DUPLICATE_COMPONENT_NAME` — 2+ components cùng name khác module

Rule_id format: `FECC-CD11-{NNN}` (FECC = FE Component Contracts).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, fe-component-graph.json, registry.

# 8. COMPLETION CRITERIA
Lane CD11 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD11-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `FECC-CD11-\d{3}` + `affected_files[]` resolve trong fe-component-graph.json nodes
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD11_STATUS=PASS|FAIL
PHASE_4_LANE_CD11_OUTPUTS=signals.json,CD11-fe-component-contracts-report.md
PHASE_4_LANE_CD11_SIGNAL_COUNT={N}
PHASE_4_LANE_CD11_NEXT=phase5-aggregate
```

---

## 20. Lane CD13 — FE↔BE Contract Sync (v2.0 Gói C++ — sub-stage 4.1)

**Agent:** `architect` (chính) + `frontend-developer` (consult)
**Wave:** 2 (cross-layer — cần `fe-api-client-graph.json` + `api-graph.json` Wave 1)
**Effort:** 3 ngày (sub-stage 4.1)

**Graph dependencies (Phase 2):**
- `fe-api-client-graph.json` (Plugin #8, Stage 2.1) — React Query hooks + Refit interfaces + raw fetch + endpoint_method + endpoint_path
- `api-graph.json` (Phase 2 core #4) — BE endpoints declared (route + method + controller module)

**SSOT dependency:** None mandatory (CD13 cross-ref 2 graphs trực tiếp; ui-interactivity-spec.json bổ sung mapping nếu populated).

```markdown
# 1. ROLE
Bạn là **architect** (chính) + tham vấn `frontend-developer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD13 FE↔BE Contract Sync).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD13 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD13 — đảm bảo FE API client calls khớp BE endpoint contracts (route + method) — root cause #1 cho 4xx errors production:

1. **FE→BE endpoint existence** — Mỗi node trong `fe-api-client-graph.json` với `endpoint_path` không null:
   - Resolve route pattern vào `api-graph.json` (normalize `/api/v1/crm/customers/{id}` ~ `/api/v1/crm/customers/{id:int}`)
   - Không tìm thấy route trong api-graph → FE_CALLS_NONEXISTENT_BE_ENDPOINT (severity MUST — chắc chắn 404)
2. **BE endpoint coverage** — Cross-ref ngược: mỗi BE endpoint trong `api-graph.json`:
   - Không có FE client node nào reference → BE_ENDPOINT_UNUSED_BY_FE (severity MAY — có thể là API public/legacy, không cấm)
3. **HTTP method mismatch** — Cho FE nodes match BE route:
   - So sánh `endpoint_method` FE vs BE method
   - Mismatch (vd FE POST nhưng BE GET) → HTTP_METHOD_MISMATCH (severity MUST — guaranteed 405)
4. **Path param coverage** — Route pattern có `{paramName}`:
   - FE call phải build URL với param (heuristic: client name hoặc context có hint param)
   - Path param trong route nhưng FE call hardcode URL không param → ENDPOINT_PARAM_MISSING (severity SHOULD)
5. **Response DTO shape drift** — (heuristic, optional)
   - FE expect `data.items[].name` nhưng BE controller method return DTO không có `name` → DTO_SHAPE_DRIFT (severity MAY — chỉ flag confidence cao, dùng cẩn thận)

CHÚ Ý EUREKA Refit + React Query:
- Refit interface attributes (`[Get("/api/...")]`) là source-of-truth cho FE side
- React Query `useQuery({queryFn: () => fetch(...)})` ít structured hơn — endpoint_path có thể null
- Nodes `kind=raw_fetch` warn lower confidence (FE devs hardcode URL)
- BE endpoint dùng `[Authorize]` không ảnh hưởng CD13 (đó là CD15)

KHÔNG được:
- Spawn sub-agent
- Modify graph files
- Flag endpoints trong `exclusions[]` của ui-interactivity-spec.json (vd webhook/admin-only endpoints)

# 3. SESSION CONTEXT
... (như §2 template chung)
- NAME: CD13-fe-be-contract-sync

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- FE clients → đọc `fe-api-client-graph.json` (primary)
- BE endpoints → đọc `api-graph.json` (primary)
- Path param coverage → string analysis trên `endpoint_path` (no extra parsing)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD13-fe-be-contract-sync/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD13-fe-be-contract-sync/CD13-fe-be-contract-sync-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected:
- `FE_CALLS_NONEXISTENT_BE_ENDPOINT` — FE client call route không tồn tại BE
- `BE_ENDPOINT_UNUSED_BY_FE` — BE endpoint không có FE caller
- `HTTP_METHOD_MISMATCH` — FE method ≠ BE registered method
- `ENDPOINT_PARAM_MISSING` — Route có {param} nhưng FE không pass
- `DTO_SHAPE_DRIFT` — FE response shape ≠ BE return shape (heuristic, low confidence)

Rule_id format: `FEBE-CD13-{NNN}`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên.

# 8. COMPLETION CRITERIA
Lane CD13 HOÀN THÀNH khi:
- ✅ signals.json + report.md tồn tại + pass POST-GATE
- ✅ Mọi signal có `affected_files[]` resolve trong fe-api-client-graph hoặc api-graph nodes
- ✅ Context budget <80%

Báo cáo:
PHASE_4_LANE_CD13_STATUS=PASS|FAIL
PHASE_4_LANE_CD13_OUTPUTS=signals.json,CD13-fe-be-contract-sync-report.md
PHASE_4_LANE_CD13_SIGNAL_COUNT={N}
PHASE_4_LANE_CD13_NEXT=phase5-aggregate
```

---

## 21. Lane CD15 — UI Permission Mirror (v2.0 Gói C++ — sub-stage 4.1)

**Agent:** `frontend-developer` (chính) + `security` (consult)
**Wave:** 2 (cross-layer — cần `fe-permission-graph.json` + `api-graph.json` Wave 1)
**Effort:** 2 ngày (sub-stage 4.1)

**Graph dependencies (Phase 2):**
- `fe-permission-graph.json` (Plugin #9, Stage 2.1) — PermissionGate/usePermission/Can/hasPermission/authorize nodes + permission_key
- `api-graph.json` (Phase 2 core #4) — BE endpoints với `[Authorize(Policy="...")]` attribute

**SSOT dependency:** `.mc-data/docs/_meta/rbac-permission-catalog.json` (template tại `plans/wf-cmi/rbac-permission-catalog.eureka-template.json` — 91 permissions × 17 modules + 13 roles + 3 clients). Thiếu → E144 ESCALATE (lane KHÔNG fallback heuristic — permission catalog cần explicit declaration).

```markdown
# 1. ROLE
Bạn là **frontend-developer** (chính) + tham vấn `security` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD15 UI Permission Mirror).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD15 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD15 — đảm bảo UI permission gates mirror BE authorization rules (zero trust UI + RBAC catalog consistency):

1. **Orphan UI permission** — Mỗi node trong `fe-permission-graph.json` có `permission_key` không null:
   - Cross-ref `rbac-permission-catalog.json.permissions[].key`
   - Không tìm thấy → ORPHAN_UI_PERMISSION (severity SHOULD — UI gates by key không tồn tại RBAC, có thể typo)
2. **BE auth without UI gate** — Mỗi BE endpoint trong `api-graph.json` có `[Authorize(Policy="X")]`:
   - Permission key X phải có FE PermissionGate ở route corresponding
   - Không tìm thấy → BE_AUTH_NO_UI_GATE (severity SHOULD — user thấy menu/button nhưng click → 403)
3. **Dynamic permission unverifiable** — Nodes có `permission_key="dynamic_or_variable"`:
   - Cannot static-verify → DYNAMIC_PERMISSION_UNVERIFIABLE (severity MAY — log info, suggest refactor)
4. **Permission naming drift** — Permission key normalization:
   - Convention: `module.entity.action` (vd `crm.customer.read`)
   - FE dùng `crm-customer-read` hoặc `CRM_CUSTOMER_READ` → PERMISSION_NAMING_DRIFT (severity SHOULD)
5. **Missing permission for admin action** — UI nodes có pattern admin-only (delete/bulk-delete/system-config):
   - Component file path chứa `admin/` HOẶC `system/`
   - Không có PermissionGate/usePermission wrap → MISSING_PERMISSION_FOR_ADMIN_ACTION (severity MUST — security risk)

CHÚ Ý EUREKA RBAC:
- 91 permissions × 17 modules — naming convention `{module}.{entity}.{action}` (vd `customs.declaration.submit`)
- 3 clients: erp-web (full), mobile-customer (limited), mobile-staff (operational)
- v2.0 chỉ scan erp-web — mobile-customer/staff defer v2.1
- Role "Admin" có wildcard `*.*.*` — KHÔNG flag thiếu permission cho Admin

KHÔNG được:
- Spawn sub-agent
- Modify graph hoặc SSOT
- Flag permissions trong `exclusions[]` của rbac-permission-catalog (vd public endpoints)
- Flag dynamic permission như security risk (chỉ log INFO)

# 3. SESSION CONTEXT
... (như §2 template chung)
- NAME: CD15-ui-permission-mirror

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- FE permission guards → đọc `fe-permission-graph.json` (primary)
- BE auth attribute → đọc `api-graph.json` (primary) — filter endpoints với `requires_auth=true` hoặc `policy` field
- RBAC catalog → Read `.mc-data/docs/_meta/rbac-permission-catalog.json` (SSOT)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD15-ui-permission-mirror/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD15-ui-permission-mirror/CD15-ui-permission-mirror-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected:
- `ORPHAN_UI_PERMISSION` — UI permission key không có trong RBAC catalog
- `BE_AUTH_NO_UI_GATE` — BE endpoint có `[Authorize]` nhưng FE không có PermissionGate tương ứng
- `DYNAMIC_PERMISSION_UNVERIFIABLE` — Permission expression dynamic (không static check được)
- `PERMISSION_NAMING_DRIFT` — Permission key sai naming convention
- `MISSING_PERMISSION_FOR_ADMIN_ACTION` — Admin/system UI action không có permission guard

Rule_id format: `UIPM-CD15-{NNN}` (UIPM = UI Permission Mirror).

# 7. OWNERSHIP RULES
OWNER: 2 files trên.

# 8. COMPLETION CRITERIA
Lane CD15 HOÀN THÀNH khi:
- ✅ signals.json + report.md tồn tại + pass POST-GATE
- ✅ SSOT rbac-permission-catalog.json đã load (nếu thiếu → E144 ESCALATE)
- ✅ Mọi signal có `rule_id` hợp lệ + permissions resolve trong SSOT `permissions[].key`
- ✅ Context budget <80%

Báo cáo:
PHASE_4_LANE_CD15_STATUS=PASS|FAIL
PHASE_4_LANE_CD15_OUTPUTS=signals.json,CD15-ui-permission-mirror-report.md
PHASE_4_LANE_CD15_SIGNAL_COUNT={N}
PHASE_4_LANE_CD15_NEXT=phase5-aggregate
```

---

## 22. Lane CD18 — CQRS Pipeline Integrity (v2.0 Gói C++ — sub-stage 4.1)

**Agent:** `architect` (chính) + `developer` (consult)
**Wave:** 2 (cross-layer — cần `be-cqrs-graph.json` + `be-domain-graph.json` Wave 1)
**Effort:** 3 ngày (sub-stage 4.1)

**Graph dependencies (Phase 2):**
- `be-cqrs-graph.json` (Plugin #13, Stage 2.2 close) — MediatR commands/queries + handlers + validators + pipeline behaviors + notifications + handlers + coverage_indicators
- `be-domain-graph.json` (Plugin #11, Stage 2.2) — Aggregate roots + domain events (cross-ref command effects)

**SSOT dependency:** None mandatory (CD18 dùng pure graph cross-ref).

```markdown
# 1. ROLE
Bạn là **architect** (chính) + tham vấn `developer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD18 CQRS Pipeline Integrity).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD18 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD18 — đảm bảo MediatR CQRS pipeline đầy đủ (mọi Command/Query có handler, validator, pipeline behavior chain hợp lệ, notifications subscribed):

1. **Command without handler** — Filter `be-cqrs-graph.json.nodes[]` `kind=command`:
   - Cross-ref edges[] có `kind=handles` từ handler node tới command node
   - Không tìm thấy → COMMAND_WITHOUT_HANDLER (severity MUST — dispatch sẽ throw HandlerNotFoundException)
2. **Command/Query without validator** — Filter `kind=command|query`:
   - Cross-ref edges[] có `kind=validates` từ validator node tới request node
   - Không tìm thấy validator AND command/query có path matching pattern public-facing (vd `Application/*/Commands/`) → COMMAND_WITHOUT_VALIDATOR (severity SHOULD — input không được validate)
   - LƯU Ý: coverage_indicators.requests_without_validator đã preprocess sẵn — tham khảo
3. **Handler without request** — Filter `kind=request_handler`:
   - Cross-ref ngược: handler có generic param `IRequest<X>` nhưng X không tồn tại trong nodes
   - → HANDLER_WITHOUT_REQUEST (severity SHOULD — handler dead code, có thể bug parser hoặc legacy)
   - LƯU Ý: coverage_indicators.handlers_without_request preprocess
4. **Notification without subscribers** — Filter `kind=notification`:
   - Cross-ref edges[] `kind=handles` từ notification_handler nodes
   - Không có handler → NOTIFICATION_WITHOUT_HANDLER (severity SHOULD — event raise nhưng không ai listen)
5. **Duplicate handler** — Group by handled request:
   - 2+ `kind=request_handler` đều handle cùng `IRequest<X>` → DUPLICATE_HANDLER (severity MUST — MediatR throw AmbiguousHandlerException runtime)

CHÚ Ý EUREKA MediatR + DDD:
- Conventions: Commands trong `Application/{Module}/Commands/`, Queries `Application/{Module}/Queries/`, Handlers cạnh request (same folder)
- FluentValidation: validators trong `Application/{Module}/Validators/` extend `AbstractValidator<TCommand>`
- Pipeline behaviors trong `Application/Common/Behaviors/` (vd UnhandledExceptionBehavior, LoggingBehavior, ValidationBehavior)
- Notification handlers = domain event handlers — subscribe domain events cross-bounded-context

KHÔNG được:
- Spawn sub-agent
- Modify graph
- Flag domain events trong `exclusions[]` (vd test fixture commands)

# 3. SESSION CONTEXT
... (như §2 template chung)
- NAME: CD18-cqrs-pipeline-integrity

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- CQRS pipeline → đọc `be-cqrs-graph.json` (primary), `coverage_indicators` đã preprocess
- Domain context → đọc `be-domain-graph.json` filter `kind=domain_event|domain_event_handler` (primary)
- KHÔNG re-parse .cs files (graph builder Phase 2 đã parse 2336 files trong EUREKA)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD18-cqrs-pipeline-integrity/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD18-cqrs-pipeline-integrity/CD18-cqrs-pipeline-integrity-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected:
- `COMMAND_WITHOUT_HANDLER` — ICommand declared nhưng không có IRequestHandler
- `COMMAND_WITHOUT_VALIDATOR` — ICommand/IQuery public-facing nhưng không có AbstractValidator
- `HANDLER_WITHOUT_REQUEST` — IRequestHandler<X> nhưng X không tồn tại trong codebase
- `NOTIFICATION_WITHOUT_HANDLER` — INotification raised nhưng không có handler subscribe
- `DUPLICATE_HANDLER` — 2+ handler handle cùng 1 IRequest

Rule_id format: `CQRS-CD18-{NNN}`.

# 7. OWNERSHIP RULES
OWNER: 2 files trên.

# 8. COMPLETION CRITERIA
Lane CD18 HOÀN THÀNH khi:
- ✅ signals.json + report.md tồn tại + pass POST-GATE
- ✅ Mọi signal `affected_files[]` resolve trong be-cqrs-graph.json nodes (file_path field)
- ✅ Coverage indicators referenced trong signal evidence (vd reqs_without_handler=33 trong EUREKA test fixture)
- ✅ Context budget <80%

Báo cáo:
PHASE_4_LANE_CD18_STATUS=PASS|FAIL
PHASE_4_LANE_CD18_OUTPUTS=signals.json,CD18-cqrs-pipeline-integrity-report.md
PHASE_4_LANE_CD18_SIGNAL_COUNT={N}
PHASE_4_LANE_CD18_NEXT=phase5-aggregate
```

---

## 23. Lane CD16 — Domain Logic Integrity (v2.0 Gói C++ — sub-stage 4.2)

**Agent:** `architect` (chính) + `business-analyst` (consult cho DDD pattern semantics)
**Wave:** 1 (Phase 2 graphs only — không chờ lane khác; song song với CD11/CD17)
**Effort:** 4 ngày (sub-stage 4.2 — BE deep lane, phức tạp do cần hiểu DDD invariants)

**Graph dependencies (Phase 2):**
- `be-domain-graph.json` (Plugin #11, Stage 2.2 vertical slice) — Aggregate roots + Entities + Value objects + Domain events + Handlers + Specifications + Repository interfaces + edges (inherits_from, uses_value_object, raises_event, handles_event, aggregates, references_entity)
- `be-cqrs-graph.json` (Plugin #13, Stage 2.2 close) — secondary: cross-ref Command handlers gọi vào Aggregate methods để phát hiện missing domain event

**SSOT dependency:** None mandatory (CD16 dùng pure DDD pattern analysis từ be-domain-graph; populate `mdm-canonical-entities.json` nếu có sẽ tăng độ chính xác cho ANEMIC_DOMAIN_MODEL nhưng KHÔNG block).

```markdown
# 1. ROLE
Bạn là **architect** (chính) + tham vấn `business-analyst` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD16 Domain Logic Integrity).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD16 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 1.

Mục tiêu lane CD16 — đảm bảo **tính toàn vẹn logic miền (Domain Logic Integrity)** trong codebase backend DDD: aggregate boundaries, domain event coverage, value object immutability, business behavior coverage:

1. **Aggregate boundary violation** — Filter `be-domain-graph.json.nodes[]` `kind=aggregate_root`:
   - Cross-ref `edges[]` `kind=references_entity|aggregates` từ aggregate A đến entity X (X thuộc aggregate B khác)
   - VÀ X KHÔNG phải value_object — tức là aggregate A đang nắm direct reference tới entity của aggregate B
   - → AGGREGATE_BOUNDARY_VIOLATION (severity MUST — vi phạm DDD rule "aggregates reference each other by ID only")
   - Evidence: `from`/`to` aggregate IDs + file_path + line
2. **Domain event missing** — Filter `kind=aggregate_root`:
   - Cross-ref `be-cqrs-graph.json.nodes[]` `kind=request_handler` có `handles` edge tới Command targeting aggregate
   - Handler edit aggregate state (vd `aggregate.Update(...)`, `aggregate.Cancel()`, `aggregate.Approve()`) NHƯNG aggregate KHÔNG có edge `kind=raises_event` từ method tương ứng
   - → DOMAIN_EVENT_MISSING (severity SHOULD — state change không thông báo bounded contexts khác)
   - Skip aggregates marked `is_event_sourced=false` trong metadata (legacy or read-only entities)
3. **Value object leak** — Filter `kind=value_object`:
   - Properties có setter public (không readonly) OR có method modify state
   - Heuristic: `set;` public hoặc method tên `Set*`/`Update*`/`Change*` không return new VO instance
   - → VALUE_OBJECT_LEAK (severity SHOULD — vi phạm VO immutability, có thể gây bug khi share reference)
   - Evidence: VO name + file_path + offending property/method
4. **Anemic domain model** — Filter `kind=aggregate_root|entity`:
   - `properties_count >= 5` AND chỉ có constructor + getter/setter + 0-1 business method
   - VÀ KHÔNG có edge `kind=raises_event` (không có behavior thực sự)
   - → ANEMIC_DOMAIN_MODEL (severity MAY — code smell, gợi ý refactor business logic vào aggregate thay vì service)
   - Skip entities thuộc reference data (Currency, Country, HsCode) — chấp nhận anemic

CHÚ Ý EUREKA DDD .NET 10:
- Conventions DDD: `apps/backend/Eureka.Modules.{Module}/Domain/{Aggregate}/` chứa AggregateRoot + Entity + ValueObject + DomainEvent cùng folder
- Aggregate base type: `AggregateRoot<TId>` hoặc `AggregateRoot` (no generic) trong `Eureka.Shared.Domain.Abstractions`
- Domain events: `: IDomainEvent` hoặc `: DomainEvent` raise qua `aggregate.RaiseDomainEvent(new XxxEvent(...))`
- Value objects: extend `ValueObject` (override `GetEqualityComponents()`) — record types cũng valid
- Repository interfaces trong `Domain/{Aggregate}/I{Aggregate}Repository.cs` — implementation ở `Infrastructure/Persistence/`

KHÔNG được:
- Spawn sub-agent
- Modify graph
- Flag aggregates trong `exclusions[]` (vd legacy entities Eureka.Infrastructure.*)
- Re-parse .cs files (graph builder Phase 2 đã parse 886 files trong EUREKA)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD16-domain-logic-integrity
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- DDD pattern → đọc `be-domain-graph.json` (primary) — KHÔNG re-parse
- CQRS handler cross-ref → đọc `be-cqrs-graph.json` filter `kind=request_handler` (secondary cho DOMAIN_EVENT_MISSING)
- Domain expert business rules → tham vấn `business-analyst` (nếu cần verify "aggregate có nên raise event không")

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — domain integrity analyzed via static graph).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD16-domain-logic-integrity/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD16-domain-logic-integrity/CD16-domain-logic-integrity-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `AGGREGATE_BOUNDARY_VIOLATION` — Aggregate reference trực tiếp entity của aggregate khác (không qua ID)
- `DOMAIN_EVENT_MISSING` — Aggregate state-changing method không raise domain event
- `VALUE_OBJECT_LEAK` — Value object có mutable setter hoặc method modify state in-place
- `ANEMIC_DOMAIN_MODEL` — Aggregate/Entity chỉ getters/setters, không có business behavior

Rule_id format: `DDD-CD16-{NNN}` (DDD = Domain-Driven Design).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, be-domain-graph.json, be-cqrs-graph.json, registry.

# 8. COMPLETION CRITERIA
Lane CD16 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD16-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `DDD-CD16-\d{3}` + `affected_entities[]` resolve trong be-domain-graph.json nodes (name field)
- ✅ AGGREGATE_BOUNDARY_VIOLATION signals luôn severity MUST (chặn merge)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD16_STATUS=PASS|FAIL
PHASE_4_LANE_CD16_OUTPUTS=signals.json,CD16-domain-logic-integrity-report.md
PHASE_4_LANE_CD16_SIGNAL_COUNT={N}
PHASE_4_LANE_CD16_NEXT=phase5-aggregate
```

---

## 24. Lane CD17 — Persistence Consistency (v2.0 Gói C++ — sub-stage 4.2)

**Agent:** `dba` (chính) + `data-engineer` (consult cho EF Core migration semantics)
**Wave:** 1 (Phase 2 graphs only — không chờ lane khác; song song với CD11/CD16)
**Effort:** 4 ngày (sub-stage 4.2 — BE deep lane, phức tạp do cross-ref entity-vs-DB schema)

**Graph dependencies (Phase 2):**
- `be-db-schema-graph.json` (Plugin #12, Stage 2.2 close) — Tables + Columns + Foreign keys + Indexes + Unique constraints + last_migration_per_module
- `be-domain-graph.json` (Plugin #11, Stage 2.2 vertical slice) — secondary: cross-ref Entity properties vs DB columns để phát hiện SCHEMA_MISMATCH

**SSOT dependency:** None mandatory (CD17 dùng pure DB schema vs Entity cross-ref; populate `mdm-canonical-entities.json` nếu có sẽ giúp xác định master table cần extra constraints nhưng KHÔNG block).

```markdown
# 1. ROLE
Bạn là **dba** (chính) + tham vấn `data-engineer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD17 Persistence Consistency).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD17 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 1.

Mục tiêu lane CD17 — đảm bảo **tính nhất quán của persistence layer**: DB schema khớp Entity, migration không drift, FK có index, không có dead column:

1. **Migration drift** — Cross-ref `be-db-schema-graph.json.metadata.last_migration_per_module{}` vs filesystem:
   - Đếm Migration files trong `apps/backend/Eureka.Migration/Migrations/` (hoặc `**/Migrations/`) theo timestamp prefix
   - So với `last_migration_per_module[Infrastructure]` declared trong graph (build từ DbContextModelSnapshot.cs)
   - Nếu filesystem có migration mới hơn snapshot timestamp → MIGRATION_DRIFT (severity MUST — snapshot stale, deployment risk)
   - Evidence: latest_migration_file vs snapshot_last_migration timestamp diff
2. **Missing index on FK** — Filter `be-db-schema-graph.json.foreign_keys[]`:
   - Mỗi FK có `column_name` trong table — cross-ref `indexes[]` cùng table có index bao phủ column này
   - Không tìm thấy index → MISSING_INDEX (severity SHOULD — query performance: JOIN hoặc filter by FK sẽ table scan)
   - Skip nếu PK trùng FK (composite PK đã cover) hoặc FK trong table <100 rows expected (heuristic dùng table_name pattern)
3. **Schema mismatch entity vs DB** — Cross-ref `be-domain-graph.json.nodes[].properties` vs `be-db-schema-graph.json.columns[]`:
   - Match table name = entity name (PascalCase → snake_case hoặc same case)
   - For each property: check column tương ứng exist + type compatibility (decimal vs decimal, datetime vs timestamp, string vs varchar/nvarchar)
   - Property tồn tại entity nhưng KHÔNG có column → SCHEMA_MISMATCH_ENTITY_DB kind=missing_column
   - Type incompatible (vd entity Money decimal(18,4) nhưng DB float) → SCHEMA_MISMATCH_ENTITY_DB kind=type_drift (severity MUST — data loss risk)
   - Evidence: entity name + property name + expected_type + actual_db_type
4. **Unused table column** — Filter `be-db-schema-graph.json.columns[]`:
   - Cross-ref `be-domain-graph.json.nodes[].properties[]` — column name không match property nào
   - VÀ column không phải technical: `created_at`, `updated_at`, `deleted_at`, `tenant_id`, `version`, `audit_*` (skip whitelist)
   - VÀ column không phải FK shadow property (skip nếu kết thúc `_id` và có matching navigation property)
   - → UNUSED_TABLE_COLUMN (severity MAY — dead column candidate, có thể từ legacy migration không cleanup)
   - Evidence: table_name + column_name + column_type

CHÚ Ý EUREKA EF Core 10 + PostgreSQL 16:
- Single DbContext shared across 17 modules — tables aggregate vào module `Infrastructure` thay vì module riêng (limitation v2.0)
- Conventions: Entity `Eureka.Modules.{Module}.Domain.{Aggregate}` → Table `{aggregate_name}` snake_case hoặc PascalCase (check `[Table]` attribute)
- FK convention: `{related_entity}_id` (snake_case) hoặc `{RelatedEntity}Id` (PascalCase)
- Money columns: phải `decimal(18,4)` hoặc `numeric(18,4)` — float/double = data loss
- Timestamp columns: phải `timestamp with time zone` (timestamptz) — naive timestamp = timezone bug
- Index naming: `IX_{Table}_{Columns}` (EF Core default convention)

KHÔNG được:
- Spawn sub-agent
- Modify graph
- Flag tables trong `exclusions[]` (vd `__EFMigrationsHistory`, `_outbox_messages`, infrastructure tables)
- Re-parse migration files (graph builder Phase 2 đã parse DbContextModelSnapshot)
- Run `dotnet ef` commands (graph builder đã capture state)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD17-persistence-consistency
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- DB schema → đọc `be-db-schema-graph.json` (primary) — KHÔNG re-parse
- Entity → DB cross-ref → đọc `be-domain-graph.json` filter `kind=aggregate_root|entity` (secondary cho SCHEMA_MISMATCH + UNUSED_COLUMN)
- Migration file scan → Glob `apps/backend/**/Migrations/[0-9]*_*.cs` (chỉ filesystem listing, không parse content)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — persistence integrity analyzed via static graphs).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD17-persistence-consistency/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD17-persistence-consistency/CD17-persistence-consistency-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `MIGRATION_DRIFT` — DbContextModelSnapshot khác latest migration file (snapshot stale)
- `MISSING_INDEX` — FK column không có DB index → query performance risk
- `SCHEMA_MISMATCH_ENTITY_DB` — Entity property type/existence mismatch với DB column
- `UNUSED_TABLE_COLUMN` — DB column không map property nào (dead column candidate)

Rule_id format: `PERSIST-CD17-{NNN}` (PERSIST = Persistence layer).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, be-db-schema-graph.json, be-domain-graph.json, registry, migration files.

# 8. COMPLETION CRITERIA
Lane CD17 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD17-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `PERSIST-CD17-\d{3}` + `affected_entities[]` resolve trong be-db-schema-graph.json tables[].name hoặc be-domain-graph.json nodes[].name
- ✅ MIGRATION_DRIFT signals luôn severity MUST (chặn deployment)
- ✅ SCHEMA_MISMATCH_ENTITY_DB kind=type_drift luôn severity MUST (data loss risk)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD17_STATUS=PASS|FAIL
PHASE_4_LANE_CD17_OUTPUTS=signals.json,CD17-persistence-consistency-report.md
PHASE_4_LANE_CD17_SIGNAL_COUNT={N}
PHASE_4_LANE_CD17_NEXT=phase5-aggregate
```

---

## 25. Lane CD23 — UX Design System Consistency (v2.0 Gói C++ — sub-stage 4.3)

**Agent:** `ui-designer` (chính) + `brand-guardian` (consult cho brand integrity + token governance)
**Wave:** 2 (cross-layer — chờ Wave 1 graphs)
**Effort:** 2 ngày (sub-stage 4.3 — simplest UX lane)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7, Stage 2 vertical slice) — Component nodes với props[] + file_path để scan token usage + variant attribute

**SSOT dependency:** **`ux-conventions.json` MANDATORY** (chứa `design_tokens.colors|typography|spacing|border_radius|shadow|z_index` + `component_variants.{Button,Badge,Input,Modal,StatusBadge,Toast}` + `validation_rules.rules[]` CD23-001/CD23-002). Lane KHÔNG fallback heuristic vì design system cần explicit token declaration — `E145` ESCALATE nếu thiếu.

```markdown
# 1. ROLE
Bạn là **ui-designer** (chính) + tham vấn `brand-guardian` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD23 UX Design System Consistency).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` + `procedures/lanes/CD23.md` và thực thi Phase 4 Lane CD23 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD23 — đảm bảo **tính nhất quán Design System** trong `apps/erp-web` so với SSOT `ux-conventions.json`:

1. **Design token drift** — Components hardcode color/spacing/font-size/border-radius:
   - Quét `fe-component-graph.nodes[].file_path` filter `.tsx`/`.ts` qua Grep regex `#[0-9a-fA-F]{3,8}` (color hex), `rgb\(|rgba\(|hsl\(` (color function), `padding:\s*\d+px|margin:\s*\d+px|gap:\s*\d+px` (hardcoded spacing), `font-size:\s*\d+px` (hardcoded type scale)
   - Cross-ref với `ux-conventions.design_tokens` — nếu giá trị KHÔNG match token nào → DESIGN_TOKEN_DRIFT (severity SHOULD)
   - Exclude: components trong `ui-conventions.exclusions[]` (vd shadcn/ui base) + components có TODO comment "DESIGN_TOKEN_PENDING"
2. **Button/Badge variant inconsistent** — Component instance dùng variant không declared:
   - Filter `fe-component-graph.nodes[]` filter name match `Button|Badge|Input|StatusBadge|Toast`
   - Parse props variant value qua Grep `variant=\"([a-z]+)\"`
   - Cross-ref `ux-conventions.component_variants.{Component}.variants[]` — nếu variant KHÔNG trong list → BUTTON_VARIANT_INCONSISTENT (severity SHOULD)
3. **Color hardcoded** — Special case của token drift cho color:
   - Tách riêng signal vì color drift nghiêm trọng nhất (brand-guardian quan tâm)
   - Hex `#xxx`/`#xxxxxx` không trong `colors.{primary,secondary,success,warning,error,info,neutral}` → COLOR_HARDCODED (severity MUST)
   - Exclude tailwind utility classes (vd `bg-red-500`) — cho phép, không flag
4. **Typography drift** — font-family/font-size/line-height không từ tokens:
   - Quét CSS-in-JS hoặc style props
   - Font-size không match `typography.font_sizes[]` → TYPOGRAPHY_DRIFT (severity SHOULD)
   - Font-family không match `typography.font_families[]` → TYPOGRAPHY_DRIFT
5. **Icon inconsistent** — Icon library mix (vd lucide-react vs heroicons cùng project):
   - Grep import statements pattern `from '(lucide-react|@heroicons|react-icons|@tabler/icons)'`
   - Nếu >1 icon library detected → ICON_INCONSISTENT (severity MAY)
   - Brand-guardian consult: chọn 1 library chính thống

CHÚ Ý EUREKA UX:
- v2.0 chỉ scan `apps/erp-web` (mobile defer v2.1)
- Tailwind utility classes được phép — KHÔNG flag inline color classes
- Components shadcn/ui base trong `components/ui/` được phép giữ tokens external
- Skip components có comment `// @design-token-exception` (explicit opt-out)

KHÔNG được:
- Spawn sub-agent
- Modify `ux-conventions.json` (read-only)
- Re-parse .tsx files (graph builder Phase 2 đã parse)
- Suggest token thay đổi (chỉ flag drift, đề xuất ở Phase 7 CDG)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD23-ux-design-system
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Component graph → đọc `fe-component-graph.json` (primary)
- SSOT tokens → Read `.mc-data/docs/_meta/ux-conventions.json` (mandatory)
- Style usage scan → Grep regex các pattern hex/rgb/font-size trong file_path
- Variant consultation → `brand-guardian` (nếu unclear về brand colors)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (wf-cmi v2 KHÔNG runtime test — design tokens analyzed via static scan).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD23-ux-design-system/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD23-ux-design-system/CD23-ux-design-system-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `DESIGN_TOKEN_DRIFT` — Hardcoded color/spacing/typography không match token
- `BUTTON_VARIANT_INCONSISTENT` — Component instance dùng variant không declared
- `COLOR_HARDCODED` — Hex/rgb color không từ palette tokens (severity MUST)
- `TYPOGRAPHY_DRIFT` — Font-size/family/line-height không từ tokens
- `ICON_INCONSISTENT` — Project dùng >1 icon library

Rule_id format: `UXDS-CD23-{NNN}` (UXDS = UX Design System).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, fe-component-graph.json, ux-conventions.json, registry.

# 8. COMPLETION CRITERIA
Lane CD23 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD23-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `UXDS-CD23-\d{3}` + `affected_files[]` resolve trong fe-component-graph.json
- ✅ COLOR_HARDCODED signals luôn severity MUST (brand-guardian gate)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD23_STATUS=PASS|FAIL
PHASE_4_LANE_CD23_OUTPUTS=signals.json,CD23-ux-design-system-report.md
PHASE_4_LANE_CD23_SIGNAL_COUNT={N}
PHASE_4_LANE_CD23_NEXT=phase5-aggregate
```

---

## 26. Lane CD24 — UX Display Format Consistency (v2.0 Gói C++ — sub-stage 4.3)

**Agent:** `ux-designer` (chính) + `frontend-developer` (consult cho format implementation patterns)
**Wave:** 2 (cross-layer — chờ Wave 1 graphs; song song CD23)
**Effort:** 2 ngày (sub-stage 4.3 — straightforward format scan)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7, Stage 2 vertical slice) — Component nodes với file_path để scan format usage patterns

**SSOT dependency:** **`ux-conventions.json` MANDATORY** (chứa `display_formats.{date,datetime,time,number,currency,phone_vn,tax_code_vn,bol_number,container_number,weight,volume,address_vn}` + `validation_rules.rules[]` CD24-001/002/003). Lane KHÔNG fallback — format consistency cần explicit pattern declaration.

```markdown
# 1. ROLE
Bạn là **ux-designer** (chính) + tham vấn `frontend-developer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD24 UX Display Format Consistency).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` + `procedures/lanes/CD24.md` và thực thi Phase 4 Lane CD24 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD24 — đảm bảo **tính nhất quán hiển thị format** trong `apps/erp-web` so với SSOT `ux-conventions.display_formats`:

1. **Date format inconsistent** — Hardcoded date format string không qua formatter:
   - Quét `fe-component-graph.nodes[].file_path` qua Grep regex `format\(\s*['"](DD/MM/YYYY|MM/DD/YYYY|YYYY-MM-DD|YYYY/MM/DD|D-M-Y|.*[Yy]{2,4}.*)['"]\s*\)` (dayjs/date-fns format calls)
   - VÀ Grep `toLocaleDateString\(|new Date\(.*\)\.toString` (raw JS date methods)
   - Cross-ref với `display_formats.date.format` (vd `DD/MM/YYYY` VN convention) — nếu format khác → DATE_FORMAT_INCONSISTENT (severity HIGH)
   - Detect raw method usage không qua `<FormatDate />` component → DATE_FORMAT_INCONSISTENT
2. **Number format inconsistent** — Hardcoded `toLocaleString`/`toFixed`/`Intl.NumberFormat` không qua formatter:
   - Grep pattern `toLocaleString\(['"]vi-VN|en-US['"]\)`, `\.toFixed\(\d\)`, `Intl\.NumberFormat\(`
   - Cross-ref `display_formats.number.{thousands_separator,decimal_separator,decimal_places}`
   - Component KHÔNG dùng `<FormatNumber />` wrapper → NUMBER_FORMAT_INCONSISTENT (severity SHOULD)
3. **Currency format inconsistent** — Hardcoded currency symbol hoặc thiếu currency code:
   - Grep `['"]₫['"]|['"]\$['"]|['"]¥['"]|['"]VNĐ['"]|['"]VND['"]` literal currency strings
   - VÀ Grep `\.toLocaleString\(.*currency.*\)` calls
   - Cross-ref `display_formats.currency.{vnd,cny,usd}` configurations
   - Component KHÔNG dùng `<FormatCurrency code="VND" />` → CURRENCY_FORMAT_INCONSISTENT (severity HIGH)
4. **Timezone drift** — `new Date()` không timezone-aware hoặc `moment()` chưa default:
   - Grep `new Date\(\)` (naive), `moment\(\)\.local\(\)|dayjs\(\)` (timezone unclear)
   - Cross-ref display: `display_formats.datetime.timezone_display` (vd `Asia/Ho_Chi_Minh GMT+7`)
   - Component KHÔNG dùng timezone-aware wrapper → TIMEZONE_DRIFT (severity SHOULD)
5. **VND decimal present** — VND amount hiển thị có decimal places (vi phạm TT 78/2021/TT-BTC):
   - Grep `['"]VND['"]` near `\.toFixed\([1-9]\)` hoặc `decimal_places:\s*[1-9]`
   - Cross-ref `display_formats.currency.vnd.decimal_places` (PHẢI = 0)
   - → VND_DECIMAL_PRESENT (severity HIGH — compliance violation)

CHÚ Ý EUREKA logistics format:
- VND amount KHÔNG có decimal (TT 78/2021/TT-BTC)
- CNY decimal 2 places (国家税务总局 standard)
- USD decimal 2 places (Incoterms)
- BOL number format: `BOL-YYYY-NNNNNN` (VNACCS spec)
- Container number format: ISO 6346 `AAAA NNNNNN-N`
- Tax code VN format: 10 hoặc 13 digit (TIN)
- Phone VN format: `+84 NNN NNN NNNN` hoặc `0NN NNN NNNN`

KHÔNG được:
- Spawn sub-agent
- Modify `ux-conventions.json` (read-only)
- Re-parse .tsx files

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD24-ux-display-format
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Component graph → `fe-component-graph.json` (primary)
- SSOT formats → Read `.mc-data/docs/_meta/ux-conventions.json` (mandatory, focus `display_formats` section)
- Format usage → Grep regex các format pattern trong file_path
- Format consultation → `frontend-developer` cho implementation pattern (Format* wrappers)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (format consistency analyzed via static scan).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD24-ux-display-format/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD24-ux-display-format/CD24-ux-display-format-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `DATE_FORMAT_INCONSISTENT` — Hardcoded date format hoặc không qua formatter component
- `NUMBER_FORMAT_INCONSISTENT` — toLocaleString/toFixed/Intl.NumberFormat hardcoded
- `CURRENCY_FORMAT_INCONSISTENT` — Hardcoded currency symbol hoặc thiếu code
- `TIMEZONE_DRIFT` — Naive datetime hoặc timezone không declared
- `VND_DECIMAL_PRESENT` — VND amount có decimal places (compliance violation TT 78/2021)

Rule_id format: `UXFMT-CD24-{NNN}` (UXFMT = UX Format).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, fe-component-graph.json, ux-conventions.json, registry.

# 8. COMPLETION CRITERIA
Lane CD24 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD24-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `UXFMT-CD24-\d{3}`
- ✅ VND_DECIMAL_PRESENT signals luôn severity HIGH (compliance gate)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD24_STATUS=PASS|FAIL
PHASE_4_LANE_CD24_OUTPUTS=signals.json,CD24-ux-display-format-report.md
PHASE_4_LANE_CD24_SIGNAL_COUNT={N}
PHASE_4_LANE_CD24_NEXT=phase5-aggregate
```

---

## 27. Lane CD25 — UX Flow Continuity (v2.0 Gói C++ — sub-stage 4.3)

**Agent:** `ux-researcher` (chính) + `frontend-developer` (consult cho route/middleware semantics)
**Wave:** 2 (cross-layer — chờ Wave 1 graphs; song song CD23/CD24)
**Effort:** 3 ngày (sub-stage 4.3 — cần cross-ref multi-graph)

**Graph dependencies (Phase 2):**
- `fe-route-graph.json` (Plugin #10) — Routes (page/layout/middleware) + dynamic + protected status
- `fe-component-graph.json` (Plugin #7) — secondary: cross-ref components dùng Link/router.push để detect orphan navigation

**SSOT dependency:** **`ux-conventions.json` MANDATORY** (chứa `ux_flow_continuity.rules[]` + `confirmation_patterns.CONF-{001-003}` + `validation_rules.rules[]` CD25-001). Lane KHÔNG fallback — flow continuity cần explicit user journey declaration.

```markdown
# 1. ROLE
Bạn là **ux-researcher** (chính) + tham vấn `frontend-developer` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD25 UX Flow Continuity).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` + `procedures/lanes/CD25.md` và thực thi Phase 4 Lane CD25 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 2.

Mục tiêu lane CD25 — đảm bảo **tính liên tục của hành trình người dùng** trong `apps/erp-web`:

1. **Broken user journey** — Route được link đến nhưng không tồn tại trong fe-route-graph:
   - Iterate `fe-component-graph.nodes[]` qua Grep pattern `<Link\s+href=\"([^\"]+)\"|router\.push\(['"]([^'"]+)['"]|navigate\(['"]([^'"]+)['"]`
   - Extract target route path
   - Cross-ref `fe-route-graph.nodes[]` filter `route_path` — nếu KHÔNG match (kể cả dynamic [param]) → BROKEN_USER_JOURNEY (severity MUST — runtime 404)
   - Exclude: external links (http://, https://, mailto:, tel:)
2. **Dead-end page** — Route tồn tại nhưng không có outgoing navigation:
   - Iterate `fe-route-graph.nodes[]` filter `kind=page`
   - Cross-ref edges[] hoặc Grep file_path tìm `<Link|router\.push|navigate\(`
   - Nếu 0 outgoing nav AND không có form/CTA quan trọng → DEAD_END_PAGE (severity SHOULD — UX trap)
   - Exclude: dynamic single-purpose pages (vd `/reset-password/confirm`) trong `ux_flow_continuity.dead_end_exclusions[]`
3. **Missing breadcrumb** — Pages sâu (depth ≥3) không có breadcrumb:
   - Iterate `fe-route-graph.nodes[]` filter `route_path` segments count ≥3 (vd `/crm/customers/[id]/edit`)
   - Cross-ref file_path content qua Grep `<Breadcrumb|breadcrumbs:|<NavBreadcrumb`
   - Nếu KHÔNG có breadcrumb component → MISSING_BREADCRUMB (severity SHOULD)
   - Exclude routes trong layouts có breadcrumb auto (vd app/(authenticated)/layout.tsx có `<AutoBreadcrumb />`)
4. **Inconsistent navigation** — Menu/sidebar/header navigation drift:
   - Quét components trong `components/layout/`, `components/sidebar/`, `components/navigation/`
   - Cross-ref route paths trong nav components vs `fe-route-graph.nodes[].route_path`
   - Routes trong nav nhưng không tồn tại → INCONSISTENT_NAVIGATION (severity MUST)
   - Routes tồn tại nhưng không trong nav (orphan public routes) → INCONSISTENT_NAVIGATION (severity SHOULD)
5. **Missing confirmation dialog** — Irreversible actions không có confirmation:
   - Iterate `ux-conventions.confirmation_patterns.{CONF-001..003}` (vd CONF-001 = delete patterns)
   - Cross-ref components qua Grep patterns matching destructive actions (`onDelete|handleDelete|onConfirmRemove|onPurge|onBulkDelete`)
   - Component có destructive handler nhưng KHÔNG có `<ConfirmationDialog />` hoặc `confirm(...)` call → MISSING_CONFIRMATION_DIALOG (severity MUST — data loss risk)
   - Cross-validate với `validation_rules.rules[].id="RULE-CD25-001"` (irreversible_action_has_confirmation)

CHÚ Ý EUREKA flow:
- v2.0 chỉ scan `apps/erp-web` (mobile defer v2.1)
- Next.js App Router conventions: `app/**/page.tsx`, `app/**/layout.tsx`, middleware `app/**/middleware.ts`
- Route groups `(group-name)/` không count vào depth (vd `/(authenticated)/crm/customers/[id]` = depth 3 không 4)
- Authentication layout có thể wrap breadcrumb component → cần check parent layout

KHÔNG được:
- Spawn sub-agent
- Modify graph files (read-only)
- Re-parse .tsx files
- Flag routes trong `ux_flow_continuity.exclusions[]` (vd debug routes)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD25-ux-flow-continuity
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- Route graph → `fe-route-graph.json` (primary)
- Component graph (Link/router.push scan) → `fe-component-graph.json` (secondary)
- SSOT flow rules → Read `.mc-data/docs/_meta/ux-conventions.json` (mandatory, focus `ux_flow_continuity` + `confirmation_patterns`)
- Navigation file scan → Grep components/layout, components/sidebar, components/navigation
- UX consultation → `frontend-developer` cho Next.js route param semantics

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (flow analyzed via static cross-ref route + component graphs).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD25-ux-flow-continuity/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD25-ux-flow-continuity/CD25-ux-flow-continuity-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `BROKEN_USER_JOURNEY` — Link tới route không tồn tại (404 risk, severity MUST)
- `DEAD_END_PAGE` — Page không có outgoing navigation (UX trap)
- `MISSING_BREADCRUMB` — Page depth ≥3 không có breadcrumb
- `INCONSISTENT_NAVIGATION` — Menu drift vs actual routes
- `MISSING_CONFIRMATION_DIALOG` — Irreversible action không confirmation (severity MUST)

Rule_id format: `UXFLOW-CD25-{NNN}` (UXFLOW = UX Flow Continuity).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, fe-route-graph.json, fe-component-graph.json, ux-conventions.json, registry.

# 8. COMPLETION CRITERIA
Lane CD25 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD25-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `UXFLOW-CD25-\d{3}` + `affected_files[]` resolve
- ✅ BROKEN_USER_JOURNEY + MISSING_CONFIRMATION_DIALOG signals luôn severity MUST (UX/safety gate)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD25_STATUS=PASS|FAIL
PHASE_4_LANE_CD25_OUTPUTS=signals.json,CD25-ux-flow-continuity-report.md
PHASE_4_LANE_CD25_SIGNAL_COUNT={N}
PHASE_4_LANE_CD25_NEXT=phase5-aggregate
```

---

## 28. Lane CD26 — UX Workflow Visibility (v2.0 Gói C++ — sub-stage 4.3, ★★★ logistics-aware)

**Agent:** `ux-designer` (chính) + `business-analyst` (consult cho workflow domain) + `logistics-expert` (consult cho logistics state machines)
**Wave:** 3 (final cross-ref — chờ Wave 1+2 graphs)
**Effort:** 4 ngày (sub-stage 4.3 — most complex UX lane, cần cross-ref 3 graphs + 2 SSOTs)

**Graph dependencies (Phase 2):**
- `fe-component-graph.json` (Plugin #7) — Components dùng StatusBadge/Timeline/ProgressBar
- `fe-route-graph.json` (Plugin #10) — Pages list/detail của entities có state machine
- `be-domain-graph.json` (Plugin #11) — Aggregate roots với states + domain events (cross-ref UI mirror)

**SSOT dependencies:**
- **`workflow-state-machines.json` MANDATORY** (chứa `state_machines.{Booking,Invoice,Order,...}` với states[] + transitions[] + ux_visibility_requirements.requirements[]). Lane KHÔNG fallback — workflow visibility cần explicit state declaration. **E146** ESCALATE nếu thiếu.
- `ux-conventions.json` secondary (cho StatusBadge variants + display formats)

```markdown
# 1. ROLE
Bạn là **ux-designer** (chính) + tham vấn `business-analyst` + `logistics-expert` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD26 UX Workflow Visibility).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` + `procedures/lanes/CD26.md` và thực thi Phase 4 Lane CD26 theo `procedures/phase4-coverage-dispatch.md` Step 4.5 Wave 3.

Mục tiêu lane CD26 — đảm bảo **tính visible của workflow states + actor roles** trong UI cho mọi entity có state machine:

1. **Workflow state unclear UI** — Entity có state machine nhưng UI list/detail không hiển thị status:
   - Iterate `workflow-state-machines.state_machines.{name}` — mỗi entry có `entity` + `states[]` + `terminal_states[]`
   - Cross-ref `fe-route-graph.nodes[]` filter route_path match `/{entity-plural}` (list) hoặc `/{entity-plural}/[id]` (detail)
   - Cross-ref `fe-component-graph.nodes[]` filter file_path trong route — Grep `<StatusBadge|<StatusChip|<state-badge|status:`
   - List page KHÔNG có StatusBadge column hoặc detail page KHÔNG có status display → WORKFLOW_STATE_UNCLEAR_UI (severity HIGH)
   - Cross-validate với `ux_visibility_requirements.requirements[].id="UX-VIS-001"`
2. **Missing status indicator** — Action buttons không show current state context:
   - Quét components có action handlers (`onApprove|onReject|onConfirm|onCancel`)
   - Cross-ref state machine `transitions[]` — action chỉ valid ở certain states
   - Component KHÔNG show current state badge near action button → MISSING_STATUS_INDICATOR (severity SHOULD)
3. **Actor role ambiguous** — Detail page không show owner/assigned actor:
   - Iterate state machines có `owner_module` (vd Booking owned by Logistics module)
   - Cross-ref entity detail page components qua Grep `<Owner|<AssignedTo|<Assignee|actor:|owner_id`
   - Page KHÔNG show actor display → ACTOR_ROLE_AMBIGUOUS (severity SHOULD)
4. **Progress hidden** — Multi-step workflow không có progress visualization:
   - Iterate state machines có states.length ≥5 (multi-step workflow)
   - Cross-ref detail page qua Grep `<Stepper|<Timeline|<Progress|<WorkflowStep|<TransitionHistory`
   - KHÔNG có progress component → PROGRESS_HIDDEN (severity SHOULD)
   - Logistics-critical: Booking (8 states) + CustomsDeclaration (6 states) + Invoice (5 states) PHẢI có Timeline
5. **Missing transition history** — User không thể xem state transition history:
   - Iterate state machines có `events_published[]` length ≥3 (significant state changes)
   - Cross-ref detail page qua Grep `<History|<AuditLog|<TransitionLog|<EventTimeline|state_history`
   - KHÔNG có history component → MISSING_TRANSITION_HISTORY (severity SHOULD)
   - Critical cho compliance audit trail (CD29 dependency)

CHÚ Ý EUREKA logistics workflows:
- **Booking**: draft → submitted → approved → in_transit → delivered → completed/cancelled (8 states, 10 transitions)
- **CustomsDeclaration**: prepared → submitted → under_review → approved/rejected → finalized
- **Invoice**: draft → issued → paid → settled (5 states, TT 78/2021 invoice lifecycle)
- **Order**: pending → confirmed → shipping → delivered → completed
- **Payment**: pending → processing → completed/failed
- **Quotation**: draft → sent → accepted/rejected → expired
- **PurchaseOrder**: draft → approved → received → closed
- **QcInspection**: scheduled → in_progress → passed/failed → reported
- **ApprovalRequest**: pending → approved/rejected → expired

KHÔNG được:
- Spawn sub-agent
- Modify graph files hoặc SSOT (read-only)
- Re-parse .tsx files
- Flag entities trong `workflow-state-machines.exclusions[]` (read-only reference data)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD26-ux-workflow-visibility
- AUTHOR: {author}

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên:
- 3 graphs → `fe-component-graph.json` + `fe-route-graph.json` + `be-domain-graph.json` (primary triplet)
- SSOT workflows → Read `.mc-data/docs/_meta/workflow-state-machines.json` (mandatory)
- SSOT UX (StatusBadge variants) → Read `.mc-data/docs/_meta/ux-conventions.json` (secondary)
- State/component cross-ref → Grep status/timeline/stepper patterns trong file_path components route
- Logistics consultation → `logistics-expert` cho domain validation (vd Booking timeline expected)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (workflow visibility analyzed via static cross-ref 3 graphs + 2 SSOTs).

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD26-ux-workflow-visibility/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD26-ux-workflow-visibility/CD26-ux-workflow-visibility-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |

Signal kinds expected (chỉ dùng các kinds này):
- `WORKFLOW_STATE_UNCLEAR_UI` — Entity state machine không có StatusBadge UI (severity HIGH)
- `MISSING_STATUS_INDICATOR` — Action button không show current state context
- `ACTOR_ROLE_AMBIGUOUS` — Detail page không show owner/assignee
- `PROGRESS_HIDDEN` — Multi-step workflow (≥5 states) không có Timeline/Stepper
- `MISSING_TRANSITION_HISTORY` — Workflow ≥3 events_published không có history component

Rule_id format: `UXWFV-CD26-{NNN}` (UXWFV = UX Workflow Visibility).

# 7. OWNERSHIP RULES
OWNER: 2 files trên + atomic write.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json, fe-component-graph.json, fe-route-graph.json, be-domain-graph.json, workflow-state-machines.json, ux-conventions.json, registry.

# 8. COMPLETION CRITERIA
Lane CD26 HOÀN THÀNH khi:
- ✅ signals.json tồn tại + pass POST-GATE T1→T4
- ✅ CD26-report.md tiếng Việt ≤15 dòng theo template
- ✅ Mọi signal có `rule_id` format `UXWFV-CD26-\d{3}` + `affected_entities[]` resolve trong workflow-state-machines.json keys
- ✅ WORKFLOW_STATE_UNCLEAR_UI signals luôn severity HIGH (UX visibility gate)
- ✅ PROGRESS_HIDDEN signal cho Booking/CustomsDeclaration/Invoice luôn severity HIGH (logistics-critical)
- ✅ Context budget <80% (CORE-038)

Báo cáo:
PHASE_4_LANE_CD26_STATUS=PASS|FAIL
PHASE_4_LANE_CD26_OUTPUTS=signals.json,CD26-ux-workflow-visibility-report.md
PHASE_4_LANE_CD26_SIGNAL_COUNT={N}
PHASE_4_LANE_CD26_NEXT=phase5-aggregate
```

---

## 29. Lane CD29 — Audit Trail Completeness (v2.0 Gói C++ — sub-stage 4.5)

**Agent dyad:** `data-engineer` (chính) + tham vấn `compliance-expert`

**Wave:** 3 (final cross-ref — chờ Wave 1+2 graphs + handlers + endpoints)

**Effort design:** 3 ngày · **Time estimate runtime:** 2-4 min/lane

**Graph dependencies:** `be-db-schema-graph.json` (audit tables) + `be-domain-graph.json` (entity properties) + `be-cqrs-graph.json` (handlers ghi log) + `api-graph.json` (PII endpoints)

**SSOT dependency:** `audit-critical-entities.json` **MANDATORY** — lane KHÔNG fallback heuristic (audit requirements cần explicit entity declaration để verify compliance).

**Procedure file:** `procedures/lanes/CD29.md` (~400 dòng, Steps CD29.1-CD29.9)

```python
Agent({
  "subagent_type": "data-engineer",
  "description": "Lane CD29 — Audit Trail Completeness (compliance-critical)",
  "model": "opus",
  "prompt": """
# 1. ROLE
Bạn là **data-engineer** cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD29 Audit Trail Completeness). Tham vấn `compliance-expert` cho quyết định nghiêm trọng PII access logging (VN-PDPL Điều 6 + GDPR Art. 30).

# 2. TASK
Đọc:
1. `.claude/skills/workflow/wf-cmi/SKILL.md` (lean routing)
2. `docs/04-skill-design/wf-cmi/agent-prompt.md §29` (role + 8 sections)
3. `.claude/skills/workflow/wf-cmi/procedures/lanes/CD29.md` (execution flow chi tiết — Steps CD29.1-CD29.9 + PRE-GATE T1-T4 + POST-GATE T1-T4)

Thực thi lane CD29 theo procedure file. Mục tiêu:
- Phát hiện entities audit-critical thiếu `audit_table` trong DB schema (MISSING_AUDIT_TABLE)
- Phát hiện actions trong `audit_required_actions[]` thiếu code path ghi log (AUDIT_ACTION_NOT_IMPLEMENTED)
- Phát hiện UPDATE/DELETE statement trên audit table (AUDIT_MUTABILITY_VIOLATION — vi phạm forensic integrity)
- Phát hiện tracked_fields KHÔNG được capture trong ChangedFields (TRACKED_FIELD_NOT_CAPTURED)
- Phát hiện PII READ endpoints KHÔNG ghi pii_access_log (PII_READ_NOT_LOGGED — vi phạm VN-PDPL + GDPR)

KHÔNG được:
- Tự ghi sang SSOT `audit-critical-entities.json` (read-only — wf-cmi không own SSOT này)
- Spawn sub-agent
- Modify entities/migrations trong codebase (lane chỉ DETECT, suggest_action trong signals — orchestrator Phase 7 sẽ CDG)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {quick|standard|deep|exhaustive}
- SCOPE: {system|module=X|feat=Y}
- DIMS_ACTIVE: {includes CD29}
- WAVE: 3
- NAME: lane-cd29-audit-trail
- TIMESTAMP: {ISO 8601}
- AUTHOR: data-engineer

# 4. CI CONTEXT
$CI_CONTEXT
# Format: GITNEXUS_AVAILABLE=true|false, SERENA_AVAILABLE=true|false,
#         INDEX_FRESHNESS=ok|light|strong|severe, FALLBACK_TOOL=Grep|Glob

Routing tool ưu tiên cho lane CD29:
- **Serena `find_references`** → primary (tìm callers của audit_table classes trong codebase)
- **GitNexus `cypher`** → secondary (query immutability constraint: UPDATE/DELETE statements on audit_*)
- **Grep `_auditWriter|_piiAuditService|AuditLog.Add|PiiAccessLog`** → fallback

# 5. PLAYWRIGHT
KHÔNG dùng — set PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required | Note |
|---|-------------|--------|----------|------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD29-audit-trail/signals.json | signals-v1 | ✅ | Atomic write, fingerprint dedup |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD29-audit-trail/CD29-audit-trail-report.md | — (md) | ✅ | Tiếng Việt ≤15 dòng (CORE-028) |
| 3 | $SESSION_DIR/phase4-coverage/lanes/CD29-audit-trail/lane-status.json | lane-status-v1 | ✅ | Atomic write, status=COMPLETED|FAILED |

Mọi output PHẢI:
- Atomic write pattern (.tmp.$$ → validate → mv)
- Pass POST-GATE T1→T4 (xem `procedures/lanes/CD29.md §D`)
- KHÔNG ghi đè output của agent khác (1 file = 1 writer)
- rule_id format `AUDIT-CD29-\d{3}` map ↔ `RULE-CD29-NNN` trong SSOT

# 7. OWNERSHIP RULES
- File này là OWNER của: 3 outputs ở §6 (signals.json + report.md + lane-status.json)
- KHÔNG modify: $SESSION_DIR/integrity-status.json (orchestrator owns)
- KHÔNG modify: $SESSION_DIR/error-ledger.json (write qua helper `record_error()`)
- KHÔNG modify: $SESSION_DIR/session-log.json (append qua helper `log_phase_*()`)
- KHÔNG modify: `.mc-data/docs/_meta/audit-critical-entities.json` (READ-ONLY SSOT)
- KHÔNG modify: codebase migrations/entities (suggest only — orchestrator Phase 7 CDG)

# 8. COMPLETION CRITERIA
Lane CD29 HOÀN THÀNH khi:
- ✅ 3 outputs ở §6 tồn tại + pass POST-GATE T1→T4
- ✅ CD29-audit-trail-report.md viết tiếng Việt ≤15 dòng (CORE-028)
- ✅ Không có error CRITICAL trong `error-ledger.json` (E130/E145 ESCALATE → FAIL)
- ✅ Mọi signal rule_id match `AUDIT-CD29-\d{3}` AND resolve được trong SSOT `validation_rules.rules[].id`
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator format:
```
PHASE_4_LANE_CD29_STATUS=PASS|FAIL
PHASE_4_LANE_CD29_OUTPUTS=signals.json,CD29-audit-trail-report.md
PHASE_4_LANE_CD29_SIGNAL_COUNT={N}
PHASE_4_LANE_CD29_NEXT=phase5-aggregate
```
"""
})
```

**Signal kinds (5):** MISSING_AUDIT_TABLE, AUDIT_ACTION_NOT_IMPLEMENTED, AUDIT_MUTABILITY_VIOLATION, TRACKED_FIELD_NOT_CAPTURED, PII_READ_NOT_LOGGED

**Severity floor:** MISSING_AUDIT_TABLE + AUDIT_MUTABILITY_VIOLATION + PII_READ_NOT_LOGGED luôn **MUST** (compliance violation = potential fine/criminal liability under VN-PDPL/GDPR).

---

## 30. Lane CD37 — Regulatory Compliance ★★★ (v2.0 Gói C++ — sub-stage 4.5, compliance-critical)

**Agent triad:** `compliance-expert` (chính) + tham vấn `legal-expert` + `dba`

**Wave:** 2 (cross-layer — chờ Wave 1 graphs + Domain/CQRS handlers)

**Effort design:** 5 ngày · **Time estimate runtime:** 3-5 min/lane (phức tạp nhất Wave 2 — multi-regulation cross-border VN+CN+intl)

**Graph dependencies:** `be-db-schema-graph.json` + `be-domain-graph.json` + `be-cqrs-graph.json` + `api-graph.json`

**SSOT dependency:** `compliance-mapping.json` **MANDATORY** — lane KHÔNG fallback heuristic (compliance cần explicit regulation declaration).

**Procedure file:** `procedures/lanes/CD37.md` (~435 dòng, Steps CD37.1-CD37.9)

```python
Agent({
  "subagent_type": "compliance-expert",
  "description": "Lane CD37 — Regulatory Compliance ★★★ (cross-border VN+CN+intl)",
  "model": "opus",
  "prompt": """
# 1. ROLE
Bạn là **compliance-expert** cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD37 Regulatory Compliance ★★★). Tham vấn `legal-expert` cho interpretation pháp lý + `dba` cho schema-level enforcement (encrypted fields, FK to compliance tables).

# 2. TASK
Đọc:
1. `.claude/skills/workflow/wf-cmi/SKILL.md` (lean routing)
2. `docs/04-skill-design/wf-cmi/agent-prompt.md §30` (role + 8 sections)
3. `.claude/skills/workflow/wf-cmi/procedures/lanes/CD37.md` (execution flow chi tiết — Steps CD37.1-CD37.9 + PRE-GATE T1-T4 + POST-GATE T1-T4)

Thực thi lane CD37 theo procedure file. Mục tiêu:
- Phát hiện regulations declared nhưng KHÔNG có code path enforce (MISSING_COMPLIANCE_CHECK — vd VN-TT78 e-invoice thiếu EInvoiceCode field)
- Phát hiện code vi phạm rule cụ thể (REGULATORY_RULE_VIOLATION — vd Invoice.Update() KHÔNG throw if Status=issued, VAT rate ngoài allowed_rates)
- Phát hiện PII handling vi phạm VN-PDPL/GDPR/CN-PIPL (PERSONAL_DATA_UNGOVERNED — thiếu consent fields, encryption, erasure endpoint)
- Phát hiện cross-border data transfer thiếu compliance (CROSS_BORDER_COMPLIANCE_GAP — CN→VN không có CAC assessment, OFAC screening missing)
- Phát hiện regulation audit stale (COMPLIANCE_AUDIT_STALE — last_audited_at > 365 ngày)

KHÔNG được:
- Tự ghi sang SSOT `compliance-mapping.json` (read-only — wf-cmi không own SSOT này)
- Spawn sub-agent
- Modify entities/migrations trong codebase (suggest only)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {quick|standard|deep|exhaustive}
- SCOPE: {system|module=X|feat=Y}
- DIMS_ACTIVE: {includes CD37}
- WAVE: 2
- NAME: lane-cd37-regulatory-compliance
- TIMESTAMP: {ISO 8601}
- AUTHOR: compliance-expert

# 4. CI CONTEXT
$CI_CONTEXT
# Format: GITNEXUS_AVAILABLE=true|false, SERENA_AVAILABLE=true|false,
#         INDEX_FRESHNESS=ok|light|strong|severe, FALLBACK_TOOL=Grep|Glob

Routing tool ưu tiên cho lane CD37:
- **GitNexus `query("compliance enforcement {regulation}")`** → primary (semantic search cho compliance code paths)
- **Serena `find_references`** → secondary (find guard methods + validators matching regulation rules)
- **Grep `[Authorize]|FluentValidation|GuardClauses|.Throw(|ValidationException|_ofacService|CACAssessment`** → fallback

# 5. PLAYWRIGHT
KHÔNG dùng — set PLAYWRIGHT_MODE=none.

# 6. OUTPUT CONTRACT
| # | Output path | Schema | Required | Note |
|---|-------------|--------|----------|------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD37-regulatory-compliance/signals.json | signals-v1 | ✅ | Atomic write, fingerprint dedup, jurisdiction_breakdown metadata |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD37-regulatory-compliance/CD37-regulatory-compliance-report.md | — (md) | ✅ | Tiếng Việt ≤15 dòng (CORE-028), include jurisdiction breakdown |
| 3 | $SESSION_DIR/phase4-coverage/lanes/CD37-regulatory-compliance/lane-status.json | lane-status-v1 | ✅ | Atomic write |

Mọi output PHẢI:
- Atomic write pattern
- Pass POST-GATE T1→T4 (xem `procedures/lanes/CD37.md §D`)
- 1 file = 1 writer
- rule_id format `COMP-CD37-\d{3}` map ↔ `RULE-CD37-NNN` trong SSOT
- regulation_ref mỗi signal resolve được trong SSOT (regulations_vn/cn/international keys)

# 7. OWNERSHIP RULES
- File này là OWNER của: 3 outputs ở §6
- KHÔNG modify: $SESSION_DIR/integrity-status.json
- KHÔNG modify: $SESSION_DIR/error-ledger.json (helper `record_error()`)
- KHÔNG modify: $SESSION_DIR/session-log.json (helper `log_phase_*()`)
- KHÔNG modify: `.mc-data/docs/_meta/compliance-mapping.json` (READ-ONLY SSOT)
- KHÔNG modify: codebase (suggest only)

# 8. COMPLETION CRITERIA
Lane CD37 HOÀN THÀNH khi:
- ✅ 3 outputs ở §6 tồn tại + pass POST-GATE T1→T4
- ✅ CD37-regulatory-compliance-report.md viết tiếng Việt ≤15 dòng + jurisdiction breakdown (VN/CN/intl)
- ✅ Không có error CRITICAL (E130/E143 ESCALATE → FAIL)
- ✅ Mọi signal rule_id match `COMP-CD37-\d{3}` AND resolve được trong SSOT validation_rules
- ✅ Mọi signal regulation_ref resolve được trong SSOT 3 jurisdictions
- ✅ Context budget <80%

Báo cáo về orchestrator format:
```
PHASE_4_LANE_CD37_STATUS=PASS|FAIL
PHASE_4_LANE_CD37_OUTPUTS=signals.json,CD37-regulatory-compliance-report.md
PHASE_4_LANE_CD37_SIGNAL_COUNT={N}
PHASE_4_LANE_CD37_NEXT=phase5-aggregate
```
"""
})
```

**Signal kinds (5):** MISSING_COMPLIANCE_CHECK, REGULATORY_RULE_VIOLATION, PERSONAL_DATA_UNGOVERNED, CROSS_BORDER_COMPLIANCE_GAP, COMPLIANCE_AUDIT_STALE

**Severity floor:** REGULATORY_RULE_VIOLATION + PERSONAL_DATA_UNGOVERNED + CROSS_BORDER_COMPLIANCE_GAP luôn **MUST** (regulatory violation = potential fine + criminal liability + business operations halt). Logistics-critical regulations VN (TT78, PDPL, VNACCS) + CN (Fapiao, H2010, PIPL) + intl (Incoterms, GDPR, OFAC).

**Cross-lane note:** CD29 PII_READ_NOT_LOGGED check **call-site** (handler có gọi pii audit). CD37 PERSONAL_DATA_UNGOVERNED check **structural existence** (entity có ConsentTimestamp field + erasure endpoint). 2 lanes complementary — KHÔNG duplicate signals.

---

## 31. Lane CD41 — E2E Scenario Synthesizer ★ NEW (v3.0)

**Agent:** `qa-lead` (chính) + `ux-researcher` + `business-analyst`
**Wave:** 3 (final cross-ref — cần Wave 1+2 signals)
**Effort:** 4 ngày (v3.0 Stage 2)
**Profile activation:** quick=SKIP / standard=SKIP / **deep=ACTIVE** / exhaustive=ACTIVE

**Graph dependencies (Phase 2):**
- `workflow-graph.json` (Discovery #3) — Walk paths involving modules → build flow steps
- `api-graph.json` (Discovery #4) — Find endpoints touched along path
- `fe-route-graph.json` (Plugin #10, Stage 2.1) — Find UI routes user navigate (entry URL)

**Phase 3 dependencies:**
- `business-invariants.json` (sidecar candidate) — Resolve invariant_id → expression + modules_involved

**Wave 1+2 dependencies:**
- `signals-aggregated.jsonl` HOẶC per-lane `signals.json` từ CD9/CD11/CD13/CD15/CD23-CD26/CD38/CD39 — Filter qualifying violations (MUST/HIGH)

**SSOT dependency (optional):** `.mc-data/docs/_meta/ui-interactivity-spec.json` (entry URL hint cho user_facing endpoints — fallback heuristic OK nếu missing).
**RBAC dependency (optional):** `rbac-matrix.json` (Phase 2 #6) — Actor resolution; fallback `sysadmin` nếu missing.

```markdown
# 1. ROLE
Bạn là **qa-lead** (chính) + tham vấn `ux-researcher` + `business-analyst` cho skill `wf-cmi` (Phase 4 — Coverage Dispatch, Lane CD41 E2E Scenario Synthesizer ★ NEW v3.0).

# 2. TASK
Đọc `.claude/skills/workflow/wf-cmi/SKILL.md` và thực thi Phase 4 Lane CD41 theo `procedures/lanes/CD41.md` Steps CD41.1 → CD41.8 (synth artifact-only — KHÔNG execute Playwright; Phase 9 sẽ execute nếu `--exec-scenarios`).

Mục tiêu lane CD41 — sinh test scenarios E2E từ violations + workflow-graph + business-invariants để Phase 9 có "đầu vào" runtime verify (thay thế wf-e2e-* legacy sẽ DEPRECATE Stage 10):

1. **Filter qualifying violations** — `signals-aggregated.jsonl` từ Wave 1+2 hoặc per-lane signals.json:
   - severity ∈ {MUST, HIGH} (skip MEDIUM/LOW — runtime verify quá rộng sẽ tốn 30+ min Phase 9)
   - dim ∈ {CD9, CD11, CD13, CD15, CD23, CD24, CD25, CD26, CD38, CD39} (lanes UX/cross-module/business flow/UI coverage/error UX — không synth từ pure backend lane vd CD2/CD7 vì runtime check không add value)
   - Dedup theo `fingerprint` (nếu nhiều lanes phát hiện cùng issue → 1 scenario)
   - Rank: MUST > HIGH, affected_modules.length desc (cross-module ưu tiên)
   - Cap MAX_SCENARIOS=40 (override `MCV3_CMI_CD41_MAX_SCENARIOS`)

2. **Walk workflow-graph per violation** — Build flow path từ entry node:
   - Resolve `invariant_id` (nếu signal có ref) → `business-invariants.json` → expression + modules
   - Entry node = first node có `module ∈ invariant.modules_involved`
   - BFS walk edges, max depth 8 (tránh path quá dài)
   - Cross-ref api-graph endpoints touched + fe-route-graph UI routes
   - Confidence scoring: path_length=0 → `low_confidence` (skip render, emit `E2E_SCENARIO_SKIPPED_LOW_CONFIDENCE`); ≥1 → `medium`; ≥expected → `high`

3. **Render scenarios theo template `templates/test-scenario.template.md`** — CMI metadata frontmatter YAML:
   - 14 fields bắt buộc: scenario_id (CMI-SC-{NNN}), generated_by=wf-cmi v3.0 CD41, generated_at, session_id, source_violation_id, source_invariant_id, source_dim, severity, scenario_type, modules_involved (array), cross_module (bool), confidence, entry_url, actor; mode optional (browser default, api-only fallback)
   - Bảng Bước:
     · Step 1: Navigate to `entry_url` (từ fe-route-graph + ui-interactivity-spec fallback)
     · Step 2-N: derive từ workflow-graph nodes (action per node — `.action_label || .label || .name`, expected từ `.expected_state || .description`)
     · Last step: Assertion theo `invariant.expression` (hoặc violation_kind fallback nếu không có invariant ref)
   - 1 scenario file per qualifying violation: `scenarios/test-scenario-CMI-{NN}-{slug}.md`
   - Slug = kebab-case từ `{kind}-{invariant_id}` (cut 40 chars, lowercase, only [a-z0-9-])

4. **Cross-module flag detection** — Nếu `modules_involved.length > 1`:
   - mark `cross_module=true` trong frontmatter
   - scenario_type = "Cross-module"
   - Thêm bước navigate xuyên modules trong workflow path
   - Emit signal kind=`E2E_SCENARIO_CROSS_MODULE` (1 per cross scenario)

5. **Write scenarios-manifest.json** — Schema `scenarios-manifest-v1`:
   - Inventory cho Phase 9 PRE-GATE T1 consume
   - Fields: session_id, lane=CD41, mode, total_synthesized, total_valid, total_skipped_low_confidence, total_cross_module, scenarios[] (per-scenario metadata), metadata.filter_dims, filter_severities, max_scenarios_cap
   - Atomic Write Pattern: `.tmp.$$` → validate JSON → mv

6. **Emit signals.json** — 3 signal kinds (1 per synthesized scenario + 1 per skipped):
   - `E2E_SCENARIO_SYNTHESIZED` (basic) — severity INFO, category RECOMMENDATION, rule_id CMI-CD41-001
   - `E2E_SCENARIO_CROSS_MODULE` (nếu cross_module=true) — severity INFO, category RECOMMENDATION, rule_id CMI-CD41-002
   - `E2E_SCENARIO_SKIPPED_LOW_CONFIDENCE` (nếu confidence=low_confidence) — severity INFO, category GAP, rule_id CMI-CD41-003
   - Mỗi signal có `scenario_ref: <scenario_id>` để Phase 5 aggregate cross-ref

7. **Phase Report** — `CD41-e2e-synth-report.md` CORE-028 ≤15 dòng tiếng Việt:
   - Số scenarios sinh ra + cross-module count + skipped count + top 3 modules + breakdown type

CHÚ Ý:
- KHÔNG execute Playwright trong CD41 — chỉ synth artifact. Phase 9 (opt-in `--exec-scenarios`) sẽ execute.
- KHÔNG re-trigger CD41 từ Phase 10 (avoid infinite loop) — Phase 10 chỉ APPEND `gap-suggestions` kind=`e2e_scenario_fix`.
- Mode `api-only` fallback khi `fe-route-graph.metadata.skipped=true` (project không có FE) — scenarios sẽ chứa HTTP request steps thay vì browser navigate.

KHÔNG được:
- Spawn sub-agent (orchestrator chỉ pre-spawn ở Phase 3)
- Modify `business-invariants.json` (read-only — Phase 7 CDG mới append)
- Modify `signals.json` của lanes khác (1 file = 1 writer rule)
- Mark scenarios là `validated`/`executed`/`passed` (Phase 9 owner — CD41 chỉ là `synthesized`/`skipped_low_confidence`)

# 3. SESSION CONTEXT
- SESSION_DIR: {session-dir}
- PROFILE: {profile}
- SCOPE: {scope}
- DIMS_ACTIVE: {dims}
- NAME: CD41-e2e-synth
- AUTHOR: {author}
- TIMESTAMP: {iso-timestamp}
- MAX_SCENARIOS: {max-scenarios} (default 40)

# 4. CI CONTEXT
$CI_CONTEXT
Routing tool ưu tiên (Phase 4 Lane CD41):
- Workflow nodes resolution → đọc `workflow-graph.json` (primary, Phase 2 #3) → Grep `class .*Command\|class .*Handler` (fallback)
- API endpoints lookup → đọc `api-graph.json` (primary, Phase 2 #4) → Grep `MapPost\|MapGet\|MapPut` (fallback)
- FE route resolution → đọc `fe-route-graph.json` (primary, Phase 2 Plugin #10) → Glob `apps/erp-web/app/**/page.tsx` (fallback)
- Invariants lookup → đọc `business-invariants.json` (Phase 3 sidecar candidate) — REQUIRED
- Violations lookup → đọc `signals-aggregated.jsonl` (Phase 5 nếu đã run) HOẶC per-lane `phase4-coverage/lanes/CD{N}/signals.json` (fallback Wave 1+2 done) — REQUIRED
- RBAC matrix → đọc `rbac-matrix.json` (Phase 2 #6) — optional, fallback `actor=sysadmin`
- UI hints → đọc `.mc-data/docs/_meta/ui-interactivity-spec.json` (SSOT) — optional, fallback heuristic

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=none (CD41 KHÔNG execute browser — chỉ synth scenario artifact. Phase 9 sẽ enable Playwright khi `--exec-scenarios`).

# 6. OUTPUT CONTRACT

| # | Output path | Schema | Required |
|---|-------------|--------|----------|
| 1 | $SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/signals.json | signals-v1 | ✅ |
| 2 | $SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/lane-status.json | lane-status-v1 | ✅ |
| 3 | $SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/CD41-e2e-synth-report.md | — (md, ≤15 dòng tiếng Việt) | ✅ |
| 4 | $SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json | scenarios-manifest-v1 | ✅ |
| 5 | $SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios/test-scenario-CMI-{NN}-{slug}.md × N | scenario-md-v1 (frontmatter YAML + Markdown body) | ✅ (1 per valid scenario; ≥1 file nếu total_valid ≥1) |

Signal kinds expected (chỉ dùng 3 kinds này):
- `E2E_SCENARIO_SYNTHESIZED` — Basic synth signal (1 per valid scenario)
- `E2E_SCENARIO_CROSS_MODULE` — Cross-module subset (subset của SYNTHESIZED)
- `E2E_SCENARIO_SKIPPED_LOW_CONFIDENCE` — Workflow walk inconclusive, scenario NOT rendered

Mỗi signal có `rule_id` format `CMI-CD41-{NNN}` (001=SYNTHESIZED, 002=CROSS_MODULE, 003=SKIPPED) + `scenario_ref: <scenario_id>` để Phase 5 aggregate cross-ref.

# 7. OWNERSHIP RULES
OWNER: 5 outputs trên + atomic write per file.
KHÔNG modify: integrity-status.json, error-ledger.json, session-log.json (helper functions only), `business-invariants.json` (Phase 7 owner), signals.json của lanes khác, registry.

# 8. COMPLETION CRITERIA
Lane CD41 HOÀN THÀNH khi:
- ✅ 5 outputs tồn tại + pass POST-GATE T1→T4 (signals schema signals-v1, lane=CD41, fingerprint unique; manifest schema scenarios-manifest-v1; mỗi scenario_file path resolve được; mỗi scenario có frontmatter YAML hợp lệ + ≥1 bảng Bước row)
- ✅ CD41-e2e-synth-report.md tiếng Việt ≤15 dòng theo template `templates/CD-report.md`
- ✅ Mọi signal có `rule_id` format `CMI-CD41-{NNN}` + `scenario_ref` resolve trong scenarios-manifest
- ✅ Context budget <80%

Hoặc lane SKIPPED gracefully (E150b INFO) nếu:
- 0 qualifying violations sau filter (no MUST/HIGH trong dim subset) → set lane status=SKIPPED, KHÔNG sinh outputs, KHÔNG die

Báo cáo về orchestrator:
PHASE_4_LANE_CD41_STATUS=PASS|FAIL|SKIPPED
PHASE_4_LANE_CD41_OUTPUTS=signals.json,scenarios-manifest.json,CD41-e2e-synth-report.md,scenarios/
PHASE_4_LANE_CD41_SIGNAL_COUNT={N}
PHASE_4_LANE_CD41_SCENARIOS_VALID={N}
PHASE_4_LANE_CD41_SCENARIOS_CROSS_MODULE={N}
PHASE_4_LANE_CD41_NEXT=phase5-aggregate|phase9-e2e-execute(if --exec-scenarios)
```

**Signal kinds (3):** E2E_SCENARIO_SYNTHESIZED, E2E_SCENARIO_CROSS_MODULE, E2E_SCENARIO_SKIPPED_LOW_CONFIDENCE

**Cross-lane note:** CD41 KHÔNG duplicate logic của 26 v2 lanes (đo coverage thuần). CD41 là PRODUCER scenarios cho Phase 9 (replace wf-e2e-* legacy). Consumer Phase 9 PRE-GATE T1 = `scenarios-manifest.json` exists. Consumer Phase 10 loop-back = `gap-suggestions.json` APPEND kind=`e2e_scenario_fix` (KHÔNG re-trigger CD41 — tránh infinite loop).

**SSOT optional handling:**
- `fe-route-graph.json` skipped (api-only project) → mode=`api-only`, scenarios chứa HTTP request steps thay vì browser navigate (Phase 9 sẽ run via curl-style nếu Playwright unavailable)
- `ui-interactivity-spec.json` missing → fallback heuristic entry URL từ `/{module-lowercase}` pattern
- `rbac-matrix.json` missing → actor default `sysadmin`

---

## 32. Triage agent (Phase 7 GAP + CDG)

**Agent:** `business-analyst` (orchestrate) + 1-3 `{domain}-experts`

```python
Agent({
  "subagent_type": "business-analyst",
  "description": "Phase 7 Triage — gap detection + CDG suggestions",
  "model": "opus",
  "prompt": """
# 1. ROLE
Bạn là **business-analyst** điều phối triage cho Phase 7 GAP detection + CDG suggestions.

# 2. TASK
Đọc:
- coverage-matrix.json (Phase 5)
- business-invariants.json (Phase 3)
- regression-map.json (Phase 6 nếu có)
- Tất cả lane signals (10 files signals.json)

Sinh `gap-suggestions.json` với 4 kinds:
- test_case — test case mới (mô tả + target test file path)
- invariant_rule — invariant mới với expression + source_doc + verified_by trong sidecar artifact `business-invariants.json`
- contract — API/event/event contract mới
- doc_snippet — đoạn doc tiếng Việt mô tả invariant/dependency

Mỗi suggestion có:
- confidence (≥0.5 để enter ACCEPTED, <0.5 mark PROPOSED only)
- target_path (file sẽ chứa artifact nếu user accept)
- source signal IDs (truy vết)

# 3. SESSION CONTEXT
... (như §2 template chung)

# 6. OUTPUT CONTRACT
$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json (schema gap-suggestions-v1)
$SESSION_DIR/phase7-gap-cdg/gap-report.md (tiếng Việt ≤30 dòng)

# 7. OWNERSHIP RULES
OWNER: 2 file trên + CDG decisions log (`$SESSION_DIR/phase7-gap-cdg/cdg-decisions.jsonl`)
KHÔNG modify: business-invariants.json (orchestrator merge sau CDG), registry.

# 8. COMPLETION CRITERIA
Báo cáo:
PHASE_7_STATUS=PASS|FAIL
PHASE_7_SUGGESTIONS_COUNT={N}
PHASE_7_CDG_TRIGGERED=true|false (true nếu --auto-suggest)
PHASE_7_NEXT=phase8-report
"""
})
```

---

## 33. Quy tắc spawn chung (CORE-025 + CORE-037)

| Quy tắc | Detail |
|---------|--------|
| Model | Default `opus` (kiến trúc + inference quan trọng). Sonnet fallback chỉ khi quota hết |
| Concurrency | Max 10 agents/phase (CORE-025). Phase 4 spawn 10 lanes parallel = hit max |
| 1 file = 1 writer | KHÔNG 2 agent ghi cùng 1 file. Lane signals path strictly per-lane |
| Timeout | Mỗi lane agent ≤3 min (Phase 4). Vượt → orchestrator kill + retry x1 (E041) |
| Sub-agent | KHÔNG được — chỉ orchestrator spawn agent (tránh runaway) |
| CI context | Inject `$CI_CONTEXT` vào §4 prompt — agent biết route Serena/GitNexus/Grep |
| Phase 3 LLM cost | Pass 2 spawn max 5 domain experts parallel (leave 5 budget cho Phase 4 retry) |

---

## 34. Anti-patterns chung (KHÔNG làm)

❌ **Vague role:** "Bạn là engineer" → đổi thành "Bạn là sre cho Lane CD8 observability"
❌ **No output contract:** Agent tự quyết file ghi → liệt kê đầy đủ §6
❌ **Modify orchestrator state:** Lane agent ghi `integrity-status.json` → CHỈ orchestrator
❌ **Cross-agent file overlap:** 2 lane ghi cùng `signals.json` → path strict per-lane `lanes/CD{N}/signals.json`
❌ **No completion criteria:** Agent return prose dài → enforce format STATUS/OUTPUTS/SIGNAL_COUNT/NEXT
❌ **Spawn sub-agent:** Lane agent spawn `{domain}-expert` → KHÔNG được; orchestrator pre-spawn ở Phase 3
❌ **Hardcode timeout:** Lane agent chạy >5 min → vi phạm CORE-025; orchestrator kill ở 3 min
❌ **Ignore CI context:** Lane agent dùng Grep dù Serena available → vi phạm CORE-033

---

## 35. Liên kết

- Rule: CORE-037 (Agent Prompt Templates), CORE-025 (Parallelization max 10), CORE-005 (Vietnamese docs)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
- Procedures section: [07-procedures-structure.md](07-procedures-structure.md) §4 (per-phase outline)
- Concrete examples: [`../wf-fix-bugs/03-architecture.md`](../wf-fix-bugs/03-architecture.md) (11 lanes pattern — canonical reference)
- Engines: #12 Prompt Orchestration Strategy ([`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md))
