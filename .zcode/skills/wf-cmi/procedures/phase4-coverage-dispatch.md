# Phase 4 — Coverage Dispatch (26 Lanes Gói C++ Logistics, 3-WAVE PARALLEL)

> **Đầu vào:** `business-invariants.json` (Phase 3) + 6 graphs (Phase 2) + `$DIMS_ACTIVE` + `$CI_CONTEXT`
> **Đầu ra:** `lanes/CD{N}-{name}/signals.json` × N + `lanes/CD{N}-{name}/lane-status.json` × N + `lanes/CD{N}-{name}/CD{N}-{name}-report.md` × N + `Phase4-report.md` + `wave-status.json` (NEW v2) + `probe-failures.log`
> **Auto-fix budget:** 3 retries (per-lane retry x1 trước batch escalate; per-wave gate check ≥3 fail STOP)
> **Time estimate v2.0:** quick 3-5 min (W1 only, 7 lanes) / standard 8-15 min (W1+W2+W3 13 lanes) / **deep 25-35 min (W1=10+W2=10+W3=6 = 26 lanes)** / exhaustive 40-60 min (35 lanes)
> **Required:** ✅ (Coverage measurement core)

---

## §A Header

Phase 4 spawn 7-26 lane agents theo **3-WAVE PARALLEL strategy** (v2.0 Gói C++ Logistics). Mỗi lane:
- 1 owner agent (xem `agent-prompt.md §3-40`)
- 1 file writer per output (`signals.json`, `lane-status.json`, `CD{N}-{name}-report.md`)
- Max 3 min timeout (E041)
- Wave-aware dispatch (Wave 1 → gate check → Wave 2 → gate check → Wave 3)
- Profile-aware skip (xem `_contract.json.profile_activation`)
- CD32-CD36 skeleton v3-deferred → SKIP với E149 WARN

**Concurrency:** Max 10 PER WAVE (CORE-025). Profile activation v2:

| Profile | Wave 1 | Wave 2 | Wave 3 | Total | Threshold |
|---------|--------|--------|--------|-------|-----------|
| quick (5-10 min) | CD1-CD4, CD7, CD16, CD17 (7) | — | — | 7 | ≥60% |
| standard (15-30 min) | CD1-CD7, CD11, CD16, CD17 (10) | CD13, CD18 (2) | CD9 (1) | 13 | ≥80% |
| **deep v3 (55-90 min + opt-in 10-40 min Phase 9)** | CD1-CD7, CD11, CD16, CD17 (10) | CD13, CD15, CD18, CD23-CD25, CD28, CD30, CD31, CD37 (10) | CD9, CD26, CD29, CD38-CD40, **CD41 (v3)** (7) | **27** | ≥95% |
| exhaustive v3 (120-180 min + Phase 9 nếu --exec-scenarios) | deep W1 + CD8, CD10 deferred enable (10) | deep W2 + CD12, CD14, CD19-22 (10) | deep W3 + CD27 + CD41 (11) | 36 | =100% |

**3-Wave Strategy (v2.0):**
- **Wave 1 (graphs-only):** Lanes consume Phase 2 graphs trực tiếp (entity/module/workflow/api/event/rbac). Max 10 parallel, ~10-12 min.
- **Wave 2 (cross-layer):** Lanes cần outputs từ Wave 1 (vd CD13 cần CD11+CD4 → FE-BE contract validation). Max 10 parallel, ~12-15 min.
- **Wave 3 (final cross-ref):** Lanes consume aggregated signals từ Wave 1+2 (vd CD9 regression cần biết tất cả modules đã scan, CD38 UI Coverage cần FE-API graph, **CD41 v3 E2E Synth cần W1+W2 violations để rank scenarios**). Max 7 lanes (v3 deep) / 11 (v3 exhaustive), ~8-15 min.
- **Per-wave gate check:** Sau mỗi wave, nếu ≥3 lanes fail/timeout → STOP wave dispatch, ESCALATE E120/E121/E122 batch.

**Mode:** SEQUENTIAL waves + PARALLEL lanes-per-wave — orchestrator spawn all wave-N lanes trong 1 response (multiple Agent calls cùng message), wait wave complete, check gate, then spawn wave-(N+1).

**Shared sections cần load:**
- `_shared.md §1, §3, §11, §15`

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `business-invariants.json` + 6 graphs exist | bash | **E040** — Phase 3 outputs missing → re-run Phase 3 |
| T2 | Lane subdirectory structure ready (`$SESSION_DIR/phase4-coverage/lanes/`) | bash | **E041** — Session structure invalid (auto-create) |
| T3 | Max concurrency budget (10 agents) available + context budget < 80% | composite | **E042** — System resource limit → reduce concurrency to 5, WARN |
| T4 | Active lanes match profile (vd quick = 5 lanes) | composite | **E043** — Lane activation mismatch → re-validate profile config |

```bash
# T1
[ -f "$SESSION_DIR/phase3-invariants/business-invariants.json" ] || die "E040" "Phase 3 invariants missing"
for g in entity-graph module-graph workflow-graph api-graph event-graph rbac-matrix; do
  [ -f "$SESSION_DIR/phase2-discovery/${g}.json" ] || die "E040" "Missing Phase 2 graph: $g"
done

# T2 — auto-create lane subdirs
DIMS_ARRAY=$(echo "$DIMS_ACTIVE" | jq -r '.[]')
for dim in $DIMS_ARRAY; do
  mkdir -p "$SESSION_DIR/phase4-coverage/lanes/$dim"
done

# T3 — context budget check
[ "$CONTEXT_PERCENT" -gt 80 ] && {
  log_warn "E042" "Context >80%, reduce concurrency to 5"
  MAX_CONCURRENCY=5
} || MAX_CONCURRENCY="${MCV3_CMI_MAX_CONCURRENCY:-10}"

# T4 — validate active lane count matches profile
EXPECTED_COUNT=0
case "$PROFILE" in
  quick) EXPECTED_COUNT=7 ;;        # v2.0: 7 lanes (W1 only)
  standard) EXPECTED_COUNT=13 ;;    # v2.0: 13 lanes (W1=10+W2=2+W3=1)
  deep) EXPECTED_COUNT=27 ;;        # v3.0: 26 v2 + CD41 = 27 lanes (W1=10+W2=10+W3=7)
  exhaustive) EXPECTED_COUNT=36 ;;  # v3.0: 26 deep + 9 SKIPPED enabled + CD41 = 36 lanes
esac
ACTUAL_COUNT=$(echo "$DIMS_ACTIVE" | jq 'length')
[ "$ACTUAL_COUNT" -gt "$EXPECTED_COUNT" ] && log_warn "E043" "Profile=$PROFILE expected $EXPECTED_COUNT lanes, got $ACTUAL_COUNT (v3 bump: deep includes CD41 v3 NEW)"
```

---

## §C Steps

### Step 4.1 — Determine active lanes theo profile + --dims

```bash
# Already computed in Phase 1 Step 1.10 → $DIMS_ACTIVE
log_phase_event "phase4" "INFO" "{\"dims_active\":$DIMS_ACTIVE,\"max_concurrency\":$MAX_CONCURRENCY}"
```

### Step 4.2 — Prepare lane subdirectories + init lane-status files + init wave-status.json (v2.0 NEW)

```bash
TPL_STATUS=".claude/skills/workflow/wf-cmi/templates/lane-status.json"

for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  LANE_DIR="$SESSION_DIR/phase4-coverage/lanes/$dim"
  mkdir -p "$LANE_DIR"

  # Init lane-status từ template (status="pending")
  strip_template_metadata "$TPL_STATUS" "$LANE_DIR/lane-status.json"
  jq --arg d "$dim" --arg ts "$(date -Iseconds)" \
     '. + {lane: $d, status: "pending", started_at: null, completed_at: null,
           duration_sec: 0, signals_count: 0, probes_executed: [], probes_failed: []}' \
     "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp.$$"
  mv "$LANE_DIR/lane-status.json.tmp.$$" "$LANE_DIR/lane-status.json"
done

# NEW v2.0 — Init wave-status.json (Stage 5 Dispatcher refinement)
# wave-coordinator.sh handles atomic write + template metadata strip + placeholder substitute.
bash .claude/scripts/wf-cmi/wave-coordinator.sh init "$SESSION_DIR" "$PROFILE"
```

### Step 4.3 — Lane agent map + subagent_type resolution (v2.0: 26 active + 5 skeleton)

> Reference: `agent-prompt.md §3-40` (v3 sẽ thêm §41-45 cho CD32-CD36 skeleton).
> Canonical map: `_contract.json.lanes_defined[]`.

**v2.0 LANE_AGENT_MAP (26 active lanes):**

| Lane | Wave | Primary agent | Secondary (consultant) | Group |
|------|------|---------------|------------------------|-------|
| CD1 | 1 | business-analyst | {domain}-experts | core |
| CD2 | 1 | architect | dba | core |
| CD3 | 1 | architect | business-analyst | core |
| CD4 | 1 | api-tester | architect | core |
| CD5 | 1 | architect | data-engineer | core |
| CD6 | 1 | security | business-analyst | core |
| CD7 | 1 | dba | data-engineer | core |
| CD9 | 3 | qa-lead | architect | core |
| CD11 | 1 | frontend-developer | — | frontend |
| CD13 | 2 | architect | frontend-developer | frontend |
| CD15 | 2 | frontend-developer | security | frontend |
| CD16 | 1 | architect | business-analyst | backend |
| CD17 | 1 | dba | data-engineer | backend |
| CD18 | 2 | architect | developer | backend |
| CD23 | 2 | ui-designer | brand-guardian | ux |
| CD24 | 2 | ux-designer | frontend-developer | ux |
| CD25 | 2 | ux-researcher | frontend-developer | ux |
| CD26 | 3 | ux-designer | business-analyst, logistics-expert | ux |
| CD28 ★★★ | 2 | data-engineer | dba, logistics-expert | logistics |
| CD29 | 3 | data-engineer | compliance-expert | compliance |
| CD30 ★★★ | 2 | architect | dba, logistics-expert | logistics |
| CD31 ★★★ | 2 | finance-expert | dba, architect | logistics |
| CD37 ★★★ | 2 | compliance-expert | legal-expert, dba | compliance |
| CD38 ★ | 3 | ux-researcher | frontend-developer, business-analyst | implementation |
| CD39 ★ | 3 | ux-designer | frontend-developer | implementation |
| CD40 ★ | 3 | ui-designer | frontend-developer, tech-writer | implementation |
| **CD41** (v3) | 3 | qa-lead | ux-researcher, business-analyst | e2e-synth (v3 NEW — profile=deep/exhaustive only) |

**9 SKIPPED v2 (not dispatched):** CD8 (sre), CD10 (tech-writer), CD12 (frontend-developer), CD14 (frontend-developer), CD19 (sre), CD20 (security), CD21 (sre), CD22 (security+devops), CD27 (ux-designer) — reactivate v2.1 hoặc exhaustive profile.

**5 SKELETON v3-deferred (E149 WARN nếu requested via --dims):** CD32 (tech-writer+data-engineer+compliance-expert), CD33 (business-analyst+ux-designer+frontend-developer), CD34 (architect+data-engineer+frontend-developer), CD35 (dba+architect+security), CD36 (sre+devops+architect).

```bash
declare -A LANE_AGENT_MAP=(
  # Wave 1 (10 lanes)
  [CD1]="business-analyst"
  [CD2]="architect"
  [CD3]="architect"
  [CD4]="api-tester"
  [CD5]="architect"
  [CD6]="security"
  [CD7]="dba"
  [CD11]="frontend-developer"
  [CD16]="architect"
  [CD17]="dba"
  # Wave 2 (10 lanes)
  [CD13]="architect"
  [CD15]="frontend-developer"
  [CD18]="architect"
  [CD23]="ui-designer"
  [CD24]="ux-designer"
  [CD25]="ux-researcher"
  [CD28]="data-engineer"
  [CD30]="architect"
  [CD31]="finance-expert"
  [CD37]="compliance-expert"
  # Wave 3 (7 lanes — v3 adds CD41 nếu profile=deep|exhaustive)
  [CD9]="qa-lead"
  [CD26]="ux-designer"
  [CD29]="data-engineer"
  [CD38]="ux-researcher"
  [CD39]="ux-designer"
  [CD40]="ui-designer"
  [CD41]="qa-lead"   # v3.0 NEW — only active when profile=deep|exhaustive (filter at Step 4.1)
)

declare -A LANE_WAVE_MAP=(
  [CD1]=1 [CD2]=1 [CD3]=1 [CD4]=1 [CD5]=1 [CD6]=1 [CD7]=1 [CD11]=1 [CD16]=1 [CD17]=1
  [CD13]=2 [CD15]=2 [CD18]=2 [CD23]=2 [CD24]=2 [CD25]=2 [CD28]=2 [CD30]=2 [CD31]=2 [CD37]=2
  [CD9]=3 [CD26]=3 [CD29]=3 [CD38]=3 [CD39]=3 [CD40]=3 [CD41]=3
)

declare -A LANE_NAME_MAP=(
  [CD1]="business-domain" [CD2]="entity-dependency" [CD3]="workflow-coverage" [CD4]="api-contract"
  [CD5]="event-coverage" [CD6]="permission-rbac" [CD7]="data-integrity" [CD9]="regression-coverage"
  [CD11]="fe-component-contracts" [CD13]="fe-be-contract-sync" [CD15]="ui-permission-mirror"
  [CD16]="domain-logic-integrity" [CD17]="persistence-consistency" [CD18]="cqrs-pipeline-integrity"
  [CD23]="ux-design-system" [CD24]="ux-display-format" [CD25]="ux-flow-continuity" [CD26]="ux-workflow-visibility"
  [CD28]="mdm-consistency" [CD29]="audit-trail" [CD30]="time-numbering" [CD31]="money-tax"
  [CD37]="regulatory-compliance"
  [CD38]="ui-implementation-coverage" [CD39]="error-ux-recovery" [CD40]="print-export-consistency"
  [CD41]="e2e-synth"   # v3.0 NEW
)
```

### Step 4.4 — Render lane prompts từ `agent-prompt.md` (CORE-037 8-section)

> Each lane prompt PHẢI có 8 sections theo CORE-037. Render via substitution.

**Render flow chuẩn (per lane):**

```text
1. READ docs/04-skill-design/wf-cmi/agent-prompt.md §{lane-section-id}
2. SUBSTITUTE placeholders:
   - {SESSION_DIR} → $SESSION_DIR
   - {PROFILE} → $PROFILE
   - {SCOPE} → $SCOPE_TYPE:$SCOPE_NAME
   - {DIMS_ACTIVE} → $DIMS_ACTIVE
   - {NAME} → CD{N}-{lane-suffix}
   - {AUTHOR} → $AUTHOR_NAME <$AUTHOR_EMAIL>
   - $CI_CONTEXT → render từ §4 CI Context
3. STRIP HTML comment header (giữ từ "# 1. ROLE" trở đi)
4. VERIFY 8 sections present
5. Pass vào Agent() call
```

**Per-lane prompt template summary (xem agent-prompt.md đầy đủ):**

Mỗi lane prompt section bao gồm:
1. **ROLE** — "Bạn là {primary-agent} cho Lane CD{N} {dim-name}"
2. **TASK** — Đọc SKILL.md + procedure file + execute lane-specific check (xem detail per-lane below)
3. **SESSION CONTEXT** — `SESSION_DIR, PROFILE, SCOPE, DIMS_ACTIVE, NAME=CD{N}, AUTHOR, TIMESTAMP`
4. **CI CONTEXT** — `$CI_CONTEXT` + routing tool priority cho lane
5. **PLAYWRIGHT** — `PLAYWRIGHT_MODE=none` (wf-cmi v1 không dùng)
6. **OUTPUT CONTRACT** — `signals.json` (schema `signals-v1`) + `CD{N}-report.md` (tiếng Việt ≤15 dòng)
7. **OWNERSHIP** — 2 files trên, KHÔNG modify integrity-status/error-ledger/registry
8. **COMPLETION** — Báo cáo `PHASE_4_LANE_CD{N}_STATUS=PASS|FAIL`, `OUTPUTS`, `SIGNAL_COUNT`

**Per-lane task detail (v2.0 — 26 active lanes):**

| Lane | W | Task summary | Expected signal kinds |
|------|---|--------------|----------------------|
| CD1 | 1 | Mọi business domain/module có ≥1 invariant; modules thiếu compliance | MISSING_DOMAIN_INVARIANT, MISSING_COMPLIANCE_CHECK, DOMAIN_RULE_VIOLATION |
| CD2 | 1 | `entity-graph.json`: aggregate roots, ownership, orphan entities, FK | ORPHAN_ENTITY, MISSING_FK_ENFORCEMENT, UNCLEAR_OWNERSHIP |
| CD3 | 1 | `workflow-graph.json`: start/end states, end-to-end trace, dangling | DANGLING_STATE, MISSING_EVENT_HANDLER, WORKFLOW_TRACE_GAP |
| CD4 | 1 | `api-graph.json`: schemas, routing, auth + identity | MISSING_REQUEST_SCHEMA, MISSING_RESPONSE_SCHEMA, MISSING_AUTH, NAMING_CONVENTION_VIOLATION |
| CD5 | 1 | `event-graph.json`: producers, consumers, propagation đầy đủ | EVENT_ORPHAN, EVENT_GHOST, PROPAGATION_INCOMPLETE |
| CD6 | 1 | `rbac-matrix.json`: actor×action×resource, default deny, identity check | MISSING_PERMISSION, PERMISSION_ORPHAN, OVERSCOPED_ROLE |
| CD7 | 1 | FK enforcement EF Core, unique constraints, NOT NULL, schema drift | FK_NOT_ENFORCED, UNIQUE_CONSTRAINT_MISSING, NOT_NULL_MISSING, SCHEMA_DRIFT |
| CD9 | 3 | Test plan cho affected modules, coverage, test types | TEST_MISSING_FOR_AFFECTED_MODULE, TEST_COVERAGE_INSUFFICIENT, TEST_OUTDATED |
| **CD11** | 1 | FE components props/types/orphan — `fe-component-graph.json` plugin. Procedure: `procedures/lanes/CD11.md` | INCOMPLETE_PROPS_TYPE, MISSING_REQUIRED_FLAG, PROP_NAMING_INCONSISTENCY, ORPHAN_COMPONENT, DUPLICATE_COMPONENT_NAME |
| **CD13** | 2 | FE↔BE contract sync — cross-ref fe-api-client-graph vs api-graph (route + HTTP method + path params). Procedure: `procedures/lanes/CD13.md` | FE_CALLS_NONEXISTENT_BE_ENDPOINT, BE_ENDPOINT_UNUSED_BY_FE, HTTP_METHOD_MISMATCH, ENDPOINT_PARAM_MISSING, DTO_SHAPE_DRIFT |
| **CD15** | 2 | UI permission mirror — fe-permission-graph vs api-graph [Authorize] vs rbac-permission-catalog. Procedure: `procedures/lanes/CD15.md` (SSOT) | ORPHAN_UI_PERMISSION, BE_AUTH_NO_UI_GATE, DYNAMIC_PERMISSION_UNVERIFIABLE, PERMISSION_NAMING_DRIFT, MISSING_PERMISSION_FOR_ADMIN_ACTION |
| **CD16** | 1 | Domain logic integrity — DDD aggregates, value objects, domain events. Procedure: `procedures/lanes/CD16.md` | AGGREGATE_BOUNDARY_VIOLATION, DOMAIN_EVENT_MISSING, VALUE_OBJECT_LEAK, ANEMIC_DOMAIN_MODEL |
| **CD17** | 1 | Persistence consistency — EF Migration vs entity definitions vs DB schema. Procedure: `procedures/lanes/CD17.md` | MIGRATION_DRIFT, MISSING_INDEX, SCHEMA_MISMATCH_ENTITY_DB, UNUSED_TABLE_COLUMN |
| **CD18** | 2 | CQRS pipeline — MediatR handlers, validators, notification handlers, duplicate handlers. Procedure: `procedures/lanes/CD18.md` | COMMAND_WITHOUT_HANDLER, COMMAND_WITHOUT_VALIDATOR, HANDLER_WITHOUT_REQUEST, NOTIFICATION_WITHOUT_HANDLER, DUPLICATE_HANDLER |
| **CD23** | 2 | UX design system — design tokens + component variants + brand color integrity + icon uniformity. Procedure: `procedures/lanes/CD23.md` (SSOT ux-conventions mandatory) | DESIGN_TOKEN_DRIFT, BUTTON_VARIANT_INCONSISTENT, COLOR_HARDCODED, TYPOGRAPHY_DRIFT, ICON_INCONSISTENT |
| **CD24** | 2 | UX display format — date/number/currency format consistency + timezone + VND no-decimal (TT 78/2021/TT-BTC). Procedure: `procedures/lanes/CD24.md` (SSOT ux-conventions mandatory) | DATE_FORMAT_INCONSISTENT, NUMBER_FORMAT_INCONSISTENT, CURRENCY_FORMAT_INCONSISTENT, TIMEZONE_DRIFT, VND_DECIMAL_PRESENT |
| **CD25** | 2 | UX flow continuity — user journey + dead-end + breadcrumb + navigation + confirmation cho destructive action. Procedure: `procedures/lanes/CD25.md` (SSOT ux-conventions mandatory) | BROKEN_USER_JOURNEY, DEAD_END_PAGE, MISSING_BREADCRUMB, INCONSISTENT_NAVIGATION, MISSING_CONFIRMATION_DIALOG |
| **CD26** | 3 | UX workflow visibility — status badge + action context + actor role + multi-step progress + transition history (logistics-critical: Booking/CustomsDeclaration/Invoice). Procedure: `procedures/lanes/CD26.md` (SSOT workflow-state-machines mandatory + ux-conventions secondary) | WORKFLOW_STATE_UNCLEAR_UI, MISSING_STATUS_INDICATOR, ACTOR_ROLE_AMBIGUOUS, PROGRESS_HIDDEN, MISSING_TRANSITION_HISTORY |
| **CD28** ★★★ | 2 | MDM consistency — mdm-canonical-entities.json vs entity/be-db-schema/be-domain/api graphs. Procedure: `procedures/lanes/CD28.md` | DUPLICATE_MASTER_ENTITY, MISSING_UNIQUE_CONSTRAINT, PARTIAL_UNIQUE_CONSTRAINT, UNAUTHORIZED_MASTER_WRITER, REFERENCE_DATA_DRIFT, MISSING_MDM_SYNC |
| **CD29** | 3 | Audit trail completeness — audit_table existence, action coverage, immutability, tracked fields capture, PII access log (VN-PDPL/GDPR). Procedure: `procedures/lanes/CD29.md` (SSOT audit-critical-entities mandatory) | MISSING_AUDIT_TABLE, AUDIT_ACTION_NOT_IMPLEMENTED, AUDIT_MUTABILITY_VIOLATION, TRACKED_FIELD_NOT_CAPTURED, PII_READ_NOT_LOGGED |
| **CD30** ★★★ | 2 | Time & numbering — timezone-aware + numbering uniqueness + format + reset. Procedure: `procedures/lanes/CD30.md` | NAIVE_DATETIME_STORAGE, TIMEZONE_BOUNDARY_DRIFT, MISSING_NUMBERING_UNIQUE, NUMBERING_FORMAT_VIOLATION, MISSING_NUMBERING_RESET, DATE_TYPE_DRIFT |
| **CD31** ★★★ | 2 | Money & tax — decimal precision + Money VO + currency mismatch + tax compliance + FX audit. Procedure: `procedures/lanes/CD31.md` (2 SSOTs) | WRONG_DECIMAL_SCALE, CRITICAL_FLOAT_MONEY, MISSING_MONEY_VALUE_OBJECT, INCOMPLETE_MONEY_TYPE, CURRENCY_MISMATCH_RISK, MIXED_CURRENCY_HEADER, EXPIRED_TAX_RATE, MISSING_ROUNDING_RULE, INCOMPLETE_TAX_BREAKDOWN, MISSING_FX_AUDIT_TRAIL, HARDCODED_FX_RATE |
| **CD37** ★★★ | 2 | Regulatory compliance — compliance check coverage, rule violation, PII governance, cross-border (CN-PIPL/OFAC), audit freshness. Procedure: `procedures/lanes/CD37.md` (SSOT compliance-mapping mandatory, 3 jurisdictions VN+CN+intl) | MISSING_COMPLIANCE_CHECK, REGULATORY_RULE_VIOLATION, PERSONAL_DATA_UNGOVERNED, CROSS_BORDER_COMPLIANCE_GAP, COMPLIANCE_AUDIT_STALE |
| **CD38** ★ | 3 | UI implementation coverage — orphan APIs, missing CRUD UI, perm UI, workflow state UI trigger. Procedure: `procedures/lanes/CD38.md` (SSOT-dependent ui-interactivity-spec.json) | ORPHAN_API_ENDPOINT, MISSING_UI_FOR_USER_FACING_API, INCOMPLETE_CRUD_UI, MISSING_PERMISSION_UI_ELEMENT, WORKFLOW_STATE_NO_UI_TRIGGER |
| **CD39** ★ | 3 | Error UX & recovery — error boundaries, recovery actions, VN messages, display consistency. Procedure: `procedures/lanes/CD39.md` (SSOT-optional error-code-catalog.json, fallback Grep heuristic) | MISSING_ERROR_BOUNDARY, RAW_ERROR_LEAKED_TO_USER, MISSING_RECOVERY_ACTION, ERROR_MESSAGE_NOT_VIETNAMESE, INCONSISTENT_ERROR_DISPLAY |
| **CD40** ★ | 3 | Print & export consistency — PDF/Excel templates, branding, font, export-UI mismatch. Procedure: `procedures/lanes/CD40.md` (SSOT-optional print-export-templates.json, fallback filesystem scan) | PRINT_TEMPLATE_DRIFT, PDF_FONT_MISSING, EXCEL_FORMULA_BROKEN, BRAND_LOGO_MISSING_DOC, EXPORT_DATA_MISMATCH_UI |
| **CD41** (v3.0 NEW, profile=deep/exhaustive only) | 3 | E2E Scenario Synthesizer — sinh test-scenario.md từ MUST/HIGH violations (dim subset CD9/CD11/CD13/CD15/CD23-26/CD38/CD39) + walk workflow-graph + render template với CMI metadata frontmatter. KHÔNG execute Playwright (artifact-only — Phase 9 consume nếu --exec-scenarios). Procedure: `procedures/lanes/CD41.md` (template-driven, CORE-031). Skip nếu 0 qualifying violations (E150b INFO). | E2E_SCENARIO_SYNTHESIZED, E2E_SCENARIO_CROSS_MODULE, E2E_SCENARIO_SKIPPED_LOW_CONFIDENCE |

**Lane procedure files (Stage 4 sub-stage build progress):**

> Mỗi lane CÓ THỂ có dedicated procedure file `procedures/lanes/CD{N}.md` chứa execution logic chi tiết (PRE-GATE/Steps/POST-GATE per-lane). Lane agent prompt §2 TASK reference cả `agent-prompt.md §{N}` (8 sections CORE-037) AND `procedures/lanes/CD{N}.md` (execution flow). Khi procedure file chưa có → agent chạy theo design canon từ `agent-prompt.md` (inline logic).

| Lane | Procedure file | Status |
|------|----------------|--------|
| CD1-CD9 (core 8) | — (inline trong agent-prompt §3-11) | v1.0 baseline |
| **CD11, CD13, CD15, CD18** | `procedures/lanes/CD{11\|13\|15\|18}.md` | ✅ **DONE (2026-05-16, sub-stage 4.1)** |
| **CD16, CD17** | `procedures/lanes/CD{16\|17}.md` | ✅ **DONE (2026-05-16, sub-stage 4.2 — integration test còn pending sau khi populate EUREKA fixtures)** |
| **CD23, CD24, CD25, CD26** | `procedures/lanes/CD{23\|24\|25\|26}.md` | ✅ **DONE (2026-05-16, sub-stage 4.3 — UX lanes Wave 2+3, integration test còn pending sau khi stakeholder populate `ux-conventions.json` + `workflow-state-machines.json`)** |
| **CD28, CD30, CD31** ★★★ | `procedures/lanes/CD{28\|30\|31}.md` | ✅ DONE (2026-05-16, sub-stage 4.4) |
| **CD29, CD37** | `procedures/lanes/CD{29\|37}.md` | ✅ **DONE (2026-05-16, sub-stage 4.5 — Compliance lanes Wave 2+3, integration test còn pending sau khi stakeholder populate `audit-critical-entities.json` + `compliance-mapping.json`)** |
| **CD38, CD39, CD40** ★ | `procedures/lanes/CD{38\|39\|40}.md` | ✅ **DONE (2026-05-16, sub-stage 4.6 — integration test còn pending sau khi stakeholder populate SSOTs)** |
| **CD41** (v3.0 NEW) | `procedures/lanes/CD41.md` | ✅ **DONE (2026-05-16, v3.0 Stage 2 — sinh scenarios từ violations + workflow-graph, profile=deep/exhaustive only)** |

Khi spawn lane có procedure file (CD11/CD13/CD15/CD16/CD17/CD18/CD23/CD24/CD25/CD26/CD28/CD29/CD30/CD31/CD37/CD38/CD39/CD40/**CD41 v3** — **19/19 lanes v3.0 active**), agent prompt §2 TASK PHẢI bao gồm:
```text
Đọc:
1. .claude/skills/workflow/wf-cmi/SKILL.md (lean routing)
2. docs/04-skill-design/wf-cmi/agent-prompt.md §{N_section} (role + 8 sections):
   - CD11 → §19, CD13 → §20, CD15 → §21, CD18 → §22
   - CD16 → §23, CD17 → §24
   - CD23 → §25, CD24 → §26, CD25 → §27, CD26 → §28
   - CD28 → §16, CD30 → §17, CD31 → §18
   - CD29 → §29, CD37 → §30
   - CD38 → §13, CD39 → §14, CD40 → §15
   - CD41 → §31 (v3.0 NEW E2E Scenario Synthesizer)
3. .claude/skills/workflow/wf-cmi/procedures/lanes/CD{N}.md (execution flow chi tiết)

Thực thi theo procedure file Steps CD{N}.1 → CD{N}.{9-10} với POST-GATE T1→T4 verification.
```

> **Sub-stage 4 COMPLETE (2026-05-16):** Toàn bộ 18/18 lanes v2.0 có dedicated procedure file + design canon section. Stage 4 đóng hoàn toàn — chuyển sang Stage 5 (Dispatcher refine) + Stage 6 (Aggregator 26-dim) + Stages 7-9.
> **v3.0 Stage 2 EXTENSION (2026-05-16):** Thêm CD41 procedure file `procedures/lanes/CD41.md` + design canon `agent-prompt.md §31`. Wave 3 dispatch list mở rộng 6→7 lanes (deep) hoặc 10→11 (exhaustive). CD41 ACTIVE chỉ khi `profile=deep|exhaustive` (skip với INFO ở filter Step 4.1 cho quick/standard).

### Step 4.5 — Spawn lane agents 3-WAVE SEQUENTIAL + PARALLEL within wave (v2.0)

> BẮT BUỘC: Spawn tất cả active lanes của 1 WAVE trong 1 response (multiple Agent calls cùng message).
> Wave 1 complete → gate check → Wave 2 spawn → gate check → Wave 3 spawn → gate check → POST-GATE.

**Pre-dispatch verify (per lane):**
1. Prompt rendered đủ 8 sections (grep heading `# 1. ROLE` → `# 8. COMPLETION`)
2. Placeholders đã substitute (không còn `{...}` brace pattern)
3. CI_CONTEXT injected vào §4
4. Output paths reference correctly `lanes/CD{N}-{name}/signals.json` (v2 naming)
5. CD32-CD36 skeleton → skip + WARN E149

**Per-wave spawn pattern (orchestrator pseudocode + bash coordinator wiring):**

> **Stage 5 v2.0 NEW:** Pattern này được hậu thuẫn bởi `.claude/scripts/wf-cmi/wave-coordinator.sh` — subcommands `init`, `start`, `end`, `gate-check`, `status`. Bash script handle atomic JSON write + gate threshold logic, orchestrator (LLM) handle Agent spawn batch.

```python
# 3-WAVE strategy: each wave runs sequentially, lanes within wave run parallel
WAVES = {1: WAVE1_LANES, 2: WAVE2_LANES, 3: WAVE3_LANES}
# Wave timeouts: max ngắt cho toàn wave (sum lane timeouts có buffer)
WAVE_TIMEOUTS = {1: 720, 2: 900, 3: 600}  # seconds (12/15/10 min)

for wave_id, wave_lanes in WAVES.items():
    # Filter lanes by DIMS_ACTIVE (profile-driven activation)
    wave_active = [d for d in wave_lanes if d in DIMS_ACTIVE]
    if not wave_active:
        # wave-coordinator.sh `end` tự động mark SKIPPED khi lanes_active rỗng
        bash_call(f"wave-coordinator.sh end {SESSION_DIR} {wave_id}")
        continue

    # Skip skeleton CD32-CD36 (v3-deferred) with WARN
    skeleton = [d for d in wave_active if d in {"CD32","CD33","CD34","CD35","CD36"}]
    if skeleton:
        log_warn("E149", f"Skeleton v3-deferred lanes skipped: {skeleton}")
        wave_active = [d for d in wave_active if d not in skeleton]

    # === START WAVE — mark started_at + populate lanes_active trong wave-status.json
    lanes_csv = ",".join(wave_active)
    bash_call(f'wave-coordinator.sh start {SESSION_DIR} {wave_id} "{lanes_csv}"')

    # Multi-tool-call trong 1 response — orchestrator gọi Agent N lần parallel cho wave này
    spawned = []
    for dim_id in wave_active:
        subagent_type = LANE_AGENT_MAP[dim_id]
        lane_name = LANE_NAME_MAP[dim_id]
        rendered_prompt = render_lane_prompt(dim_id, subagent_type, wave=wave_id)
        verify_prompt(rendered_prompt, sections=8)
        set_lane_status(dim_id, "running")

        spawned.append(Agent(
            subagent_type=subagent_type,
            description=f"Lane {dim_id}-{lane_name} (Wave {wave_id})",
            model="opus",
            prompt=rendered_prompt
        ))

    # Wait wave complete (Claude Code batch returns N results after parallel execution)
    # Per-lane lane-status.json đã được lane agent atomic update khi finish.

    # === END WAVE + GATE CHECK — wave-coordinator.sh aggregate outcomes + threshold check
    # Exit code: 0=PASS, 1=FAIL_THRESHOLD (≥threshold combined fail), 2=PARTIAL_FAIL (1+ fail < threshold)
    rc = bash_call(f"wave-coordinator.sh end {SESSION_DIR} {wave_id}")
    if rc == 1:
        die(f"E12{wave_id}", f"Wave {wave_id} batch fail (≥threshold) — STOP dispatch")
    elif rc == 2:
        log_warn("E123", f"Wave {wave_id} partial fail — continue with retry (Step 4.7)")
        retry_failed_lanes_in_wave(wave_active)
```

**Orchestrator note:** Trong Claude Code, "parallel spawn within wave" = gọi `Agent` tool N lần trong 1 assistant message. Tool execution sẽ chạy concurrent. Sau response, orchestrator nhận N kết quả batch lại. Wave 2 spawn CHỈ sau Wave 1 batch return + `wave-coordinator.sh end` PASS (exit 0 hoặc 2).

**Wave coordinator subcommands quick reference:**

| Command | Purpose | When |
|---------|---------|------|
| `init $SESSION_DIR $PROFILE` | Strip template + populate session_id/profile | Step 4.2 (once per session) |
| `start $SESSION_DIR $WAVE_ID "$LANES_CSV"` | Mark wave started, set lanes_active, gate_status=RUNNING | Before Agent spawn batch |
| `end $SESSION_DIR $WAVE_ID` | Aggregate per-lane outcomes, threshold gate check, idempotent | After Agent batch return |
| `gate-check $SESSION_DIR $WAVE_ID` | Read-only re-evaluate recorded gate_status | Resume/audit |
| `status $SESSION_DIR` | Print 3-wave summary | Phase end / debug |

### Step 4.6 — Monitor lane progress (timeout 3 min/lane — E041)

> Sau khi spawn batch, orchestrator monitor qua `lane-status.json` updates.

```bash
TIMEOUT_SEC="${MCV3_CMI_LANE_TIMEOUT_SEC:-180}"
START_TS=$(date +%s)

while true; do
  ALL_DONE=true
  for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
    STATUS=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
    case "$STATUS" in
      running|pending) ALL_DONE=false ;;
      completed|failed|timeout|skipped) ;;
    esac
  done

  # Check timeout
  ELAPSED=$(($(date +%s) - START_TS))
  if [ "$ELAPSED" -gt "$TIMEOUT_SEC" ]; then
    log_warn "E041" "Lane timeout ($ELAPSED s) — mark running lanes as TIMEOUT"
    for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
      st=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
      [ "$st" = "running" ] && set_lane_status "$dim" "timeout"
    done
    break
  fi

  [ "$ALL_DONE" = "true" ] && break
  sleep 5
done
```

**Note:** Trong Claude Code context, orchestrator nhận lane results SAU khi parallel spawn complete (batch return). Timeout check chủ yếu cho post-mortem nếu agent hang. Wave-level aggregation + gate check (E120/E121/E122/E123) thực hiện qua `wave-coordinator.sh end $SESSION_DIR $WAVE_ID` ngay sau batch — KHÔNG cần inline bash trong phase procedure.

### Step 4.7 — Per-lane retry x1 nếu fail (CORE-034 budget model)

```bash
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  STATUS=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
  RETRY=$(jq -r '.retry_count // 0' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")

  if [ "$STATUS" = "failed" ] && [ "$RETRY" -lt 1 ]; then
    log_phase_event "phase4" "RETRY" "{\"lane\":\"$dim\",\"retry\":1}"
    # Re-spawn lane agent với clarified output contract
    respawn_lane "$dim"
    set_lane_retry_count "$dim" $((RETRY + 1))
  fi
done
```

**Batch escalate:** ≥3 lanes timeout/fail → E040 ESCALATE.

### Step 4.8 — Validate signal schema cross-lane

> Mỗi `signals.json` PHẢI:
> - Schema `signals-v1` ($schema field)
> - `lane` field khớp directory name
> - `signals[]` array (có thể empty)
> - Mỗi signal có fingerprint unique trong lane

```bash
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  SIG_FILE="$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json"

  # T2: schema valid
  jq -e '."$schema" == "signals-v1"' "$SIG_FILE" >/dev/null \
    || { log_warn "E048" "Lane $dim schema invalid"; continue; }

  # T2: lane field matches
  ACTUAL_LANE=$(jq -r '.lane' "$SIG_FILE")
  [ "$ACTUAL_LANE" = "$dim" ] || log_warn "E048" "Lane $dim mismatch: file says $ACTUAL_LANE"

  # T4: fingerprint uniqueness
  DUP_FP=$(jq '[.signals[].fingerprint] | (length - (unique | length))' "$SIG_FILE")
  [ "$DUP_FP" -gt 0 ] && log_warn "E049" "Lane $dim has $DUP_FP duplicate fingerprints"
done

# Cross-lane fingerprint collision (rare — Phase 5 will dedupe)
ALL_FP=$(for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  jq -r '.signals[].fingerprint' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" 2>/dev/null
done | sort | uniq -d)
[ -n "$ALL_FP" ] && log_warn "E049" "Cross-lane fingerprint collision: $(echo "$ALL_FP" | wc -l)"
```

### Step 4.9 — Update integrity-status.json.lane_status{} atomic

```bash
LANE_STATUS_OBJ="{}"
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  st=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
  LANE_STATUS_OBJ=$(echo "$LANE_STATUS_OBJ" | jq --arg d "$dim" --arg s "$st" '. + {($d): $s}')
done

# Atomic update integrity-status.json
TARGET="$SESSION_DIR/integrity-status.json"
jq --argjson ls "$LANE_STATUS_OBJ" '.lane_status = $ls' "$TARGET" > "$TARGET.tmp.$$" \
   && mv "$TARGET.tmp.$$" "$TARGET"
```

### Step 4.10 — Write Phase4-report.md (CORE-028)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/Phase4-report.md"
REPORT="$SESSION_DIR/phase4-coverage/Phase4-report.md"

TOTAL_LANES=$(echo "$DIMS_ACTIVE" | jq 'length')
PASS_COUNT=$(echo "$LANE_STATUS_OBJ" | jq '[.[] | select(. == "completed")] | length')
FAIL_COUNT=$(echo "$LANE_STATUS_OBJ" | jq '[.[] | select(. == "failed" or . == "timeout")] | length')
SKIP_COUNT=$(echo "$LANE_STATUS_OBJ" | jq '[.[] | select(. == "skipped")] | length')

TOTAL_SIGNALS=0
for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
  c=$(jq '.signals | length' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" 2>/dev/null || echo 0)
  TOTAL_SIGNALS=$((TOTAL_SIGNALS + c))
done

sed -e "s|\[TOTAL_LANES\]|$TOTAL_LANES|g" \
    -e "s|\[PASS_COUNT\]|$PASS_COUNT|g" \
    -e "s|\[FAIL_COUNT\]|$FAIL_COUNT|g" \
    -e "s|\[SKIP_COUNT\]|$SKIP_COUNT|g" \
    -e "s|\[TOTAL_SIGNALS\]|$TOTAL_SIGNALS|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|$([ "$FAIL_COUNT" -ge 3 ] && echo FAIL || echo PASS)|g" \
    "$TPL" > "$REPORT"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | Mọi active lane có `signals.json` + `Phase4-report.md` (chính + lane CD{N}-report.md) | Re-spawn lane agent (max 1 retry per-lane) |
| T2 | Schema `signals-v1` valid mỗi lane | Re-prompt agent với clarified output contract |
| T3 | Signal count claimed = actual file count (lane-status.signals_count khớp jq `.signals \| length`) | Re-validate (E047 nếu mismatch) |
| T4 | Mỗi signal có fingerprint unique per-lane (cross-lane dedup ở Phase 5) | Dedupe in-place |

```bash
post_gate_phase4() {
  local retry=0
  while [ "$retry" -lt 3 ]; do
    local all_pass=true
    local failed_lanes=()

    for dim in $(echo "$DIMS_ACTIVE" | jq -r '.[]'); do
      st=$(jq -r '.status' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
      [ "$st" = "skipped" ] && continue

      # T1
      [ -f "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" ] \
        || { failed_lanes+=("$dim:T1"); all_pass=false; continue; }

      # T2
      jq -e '."$schema" == "signals-v1"' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json" >/dev/null \
        || { failed_lanes+=("$dim:T2"); all_pass=false; continue; }

      # T3
      claimed=$(jq -r '.signals_count // 0' "$SESSION_DIR/phase4-coverage/lanes/$dim/lane-status.json")
      actual=$(jq '.signals | length' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json")
      [ "$claimed" -eq "$actual" ] || { log_warn "E047" "$dim claimed=$claimed actual=$actual"; failed_lanes+=("$dim:T3"); }

      # T4 — fingerprint unique
      dup=$(jq '[.signals[].fingerprint] | (length - (unique | length))' "$SESSION_DIR/phase4-coverage/lanes/$dim/signals.json")
      [ "$dup" -gt 0 ] && { failed_lanes+=("$dim:T4"); all_pass=false; }
    done

    [ "$all_pass" = "true" ] && return 0

    # Per-lane retry
    for entry in "${failed_lanes[@]}"; do
      dim="${entry%%:*}"
      tier="${entry##*:}"
      retry_lane "$dim" "$tier"
    done
    retry=$((retry+1))
  done
  die "E001" "Phase 4 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 4
2. Update `integrity-status.json`:
   - `.phases_completed += [4]`
   - `.current_phase = 5`
   - `.next_action = "phase5-aggregate"`
3. TodoWrite: Phase 4 = completed, Phase 5 = in_progress

---

## §E Phase Report Template (CORE-028)

```markdown
## Phase 4: Quét coverage 8 chiều — PASS
Thời gian: 2026-05-15T14:48:35+07:00

**Đã làm:**
- Spawn 8 chuyên gia song song quét 8 chiều coverage
- Mỗi chuyên gia quét code + tài liệu theo lĩnh vực của mình

**Kết quả:**
- Lane hoàn thành: 8/8 (PASS=8, FAIL=0, TIMEOUT=0)
- Tổng signals phát hiện: 142
- CD1 Business: 18 | CD2 Entity: 12 | CD3 Workflow: 9
- CD4 API: 32 | CD5 Event: 14 | CD6 RBAC: 21
- CD7 Data: 16 | CD9 Regression: 20

**Tiếp theo:**
- Phase 5 — Tổng hợp signals → coverage matrix 8 chiều (1-2 phút)
```

---

## §F Error Code Quick Reference (Phase 4 namespace E040-E049 + v2.0 wave gates E120-E123 + lane-specific E130-E149)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E040 | high | Lane dispatch fail (agent spawn error) | Retry per-agent x1, ESCALATE batch |
| E041 | medium | Probe timeout (>$MCV3_CMI_LANE_TIMEOUT_SEC) | Mark lane TIMEOUT, continue others |
| E042 | high | System resource limit | Reduce concurrency to 5, WARN |
| E043 | medium | Lane activation mismatch | Re-validate profile config |
| E044 | high | Sidecar schema mismatch | ESCALATE → Phase 3 re-run |
| E045 | medium | Invariant incomplete (missing fields) | Re-prompt agent |
| E046 | medium | Orphan invariant (source_doc not found) | Re-link or DROP |
| E047 | high | DATA INCONSISTENCY (claimed ≠ actual) | ESCALATE agent corruption |
| E048 | medium | Signal schema validation fail | Drop invalid, log |
| E049 | low | Fingerprint collision | Dedupe, INFO log |
| **E120** | medium | **Wave 1 ≥3 lanes fail/timeout** (CD1-CD7, CD11, CD16, CD17 batch) | STOP wave dispatch, ESCALATE batch |
| **E121** | medium | **Wave 2 ≥3 lanes fail/timeout** (CD13, CD15, CD18, CD23-CD25, CD28, CD30, CD31, CD37 batch) | STOP wave dispatch, ESCALATE |
| **E122** | medium | **Wave 3 ≥2 lanes fail/timeout** (CD9, CD26, CD29, CD38-CD40 batch) | STOP wave dispatch, ESCALATE |
| **E123** | low | Wave 1-2 lane fail (partial) | WARN, retry failed lanes, continue next wave |
| **E130-E135** | medium-high | Lane CD11-CD18 graph dep fail (FE/BE) | Fallback Grep, downgrade confidence |
| **E140-E143** | high | Lane CD28/CD30/CD31/CD37 ★★★ SSOT missing | ESCALATE — yêu cầu domain expert define |
| **E144-E148** | medium | Lane CD23-CD26/CD29/CD38-CD40 SSOT missing | WARN, partial coverage fallback |
| **E149** | low | CD32-CD36 skeleton v3-deferred requested | WARN, skip — v3 sẽ activate |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §15 Agent Prompt Templates (lane agent map) |
| `docs/04-skill-design/wf-cmi/agent-prompt.md` | §3-12 per-lane prompt templates |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | §4 Profile skip rules |
| `docs/04-skill-design/wf-cmi/05-execution-profiles.md` | Profile → lane activation matrix |
| `templates/signals.json`, `lane-status.json`, `CD-report.md` | Per-lane outputs |
| **`templates/wave-status.json`** | **3-WAVE dispatch state (v2.0 Stage 5)** |
| **`.claude/scripts/wf-cmi/wave-coordinator.sh`** | **Wave coordinator: init/start/end/status/gate-check (v2.0 Stage 5)** |
| `_contract.json §outputs.working[]` | Lane output paths |

---

## §H Next

Phase 4 PASS → Read `procedures/phase5-aggregate.md` để aggregate signals → coverage matrix.
