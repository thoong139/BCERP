<!--
_schema_notes:
  purpose: Phase 2 (Discovery — 6 core + 4 FE plugin + 3 BE plugin v2.0 Stage 2.1+2.2 COMPLETE) report. CORE-028 ≤22 dòng tiếng Việt (relaxed v2 cho 7 plugins).
  rules:
    - Max 22 dòng total (v2 relaxed cho 7 plugins)
    - Tiếng Việt, không jargon
    - 6 core graphs summary: entity/module/workflow/api/event/rbac với node/edge counts
    - 4 FE plugin graphs v2.0: fe-component, fe-api-client, fe-permission, fe-route (OK/SKIPPED + count)
    - 3 BE plugin graphs v2.0 Stage 2.2 COMPLETE: be-domain (DDD types), be-db-schema (tables/cols/idx), be-cqrs (cmds/queries/handlers/validators + coverage)
  delete_before_write: true
-->
## Phase 2: Discovery (6 core + 4 FE plugin + 3 BE plugin v2.0) — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)

**Đã làm:** Build 6 core graph + 7 plugin (4 FE Stage 2.1 + 3 BE Stage 2.2 COMPLETE) PARALLEL từ codebase: entity, module, workflow, API, event, RBAC + FE components/API clients/permissions/routes + BE DDD types / DB schema cumulative / CQRS pipeline. CI source: [CI_SOURCE] (fallback [N_FALLBACK] lần sang Grep).

**Kết quả:**

- Entity: [N_ENTITIES] nodes / [N_FK] edges
- Module: [N_MODULES] modules / [N_DEPS] dependencies ([N_CYCLES] cycles)
- Workflow: [N_WORKFLOWS] workflows ([N_INCOMPLETE] incomplete)
- API: [N_ENDPOINTS] endpoints / [N_DEPRECATED] deprecated
- Event: [N_EVENTS] events / [N_ORPHAN] orphan / [N_UNHANDLED] unhandled
- RBAC: [N_ACTORS]×[N_ACTIONS]×[N_RESOURCES] = [N_PERMS] permissions / [N_GAPS] gaps
- FE Component (v2.0): [FE_COMPONENT_COUNT] components ([FE_COMPONENT_STATUS])
- FE API Client (v2.0): [FE_API_CLIENT_COUNT] client units ([FE_API_CLIENT_STATUS])
- FE Permission (v2.0): [FE_PERMISSION_COUNT] guards ([FE_PERMISSION_STATUS])
- FE Route (v2.0): [FE_ROUTE_COUNT] routes ([FE_ROUTE_STATUS])
- BE Domain (v2.0 Stage 2.2): [BE_DOMAIN_COUNT] DDD types ([BE_DOMAIN_STATUS]) — aggregates=[BE_DOMAIN_AGG], entities=[BE_DOMAIN_ENT], VOs=[BE_DOMAIN_VO], events=[BE_DOMAIN_EVT], handlers=[BE_DOMAIN_DEH]
- BE DB Schema (v2.0 Stage 2.2): [BE_DB_SCHEMA_COUNT] tables ([BE_DB_SCHEMA_STATUS]) — cols=[BE_DB_SCHEMA_COL], FKs=[BE_DB_SCHEMA_FK], indexes=[BE_DB_SCHEMA_IDX]
- BE CQRS (v2.0 Stage 2.2): [BE_CQRS_COUNT] types ([BE_CQRS_STATUS]) — cmds=[BE_CQRS_CMD], queries=[BE_CQRS_QRY], handlers=[BE_CQRS_HDL], validators=[BE_CQRS_VAL] / coverage: reqs_no_handler=[BE_CQRS_NOH], reqs_no_validator=[BE_CQRS_NOV]

**Tiếp theo:** Phase 3 — Invariant Artifact (3-pass LLM inference: pattern → domain → registry gap).

[NẾU FAIL:]
**Vấn đề:** [ERROR_MESSAGE]
**Cách xử lý:** [RECOVERY_PLAN]
