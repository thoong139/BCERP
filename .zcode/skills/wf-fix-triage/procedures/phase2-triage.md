# Phase 2: Triage — Phan loai Loi

> Phan loai issues theo severity va fixability, chuan bi execution plan cho wf-fix-execute.
> Doc file nay khi bat dau Phase 2 (sau khi Lane Dispatch Phase 2 completed).

**INPUT:**
- `$SESSION_DIR/fix-status.json` — session config, scope, flags, phase 1 completion state
- `$SESSION_DIR/issue-registry.json` — initial issue list (severity/fixability/domain CHUA set, tu wf-fix-bugs Lane Dispatch POST-GATE)
- `$SESSION_DIR/checkpoint.json` — (chi khi flags.deep=true) chua `partial_state.deep_scan_state.orphan_ui_issues_accumulated`
- `$SESSION_DIR/impact-graph.json` — cross-reference graph tu wf-fix-bugs Lane Dispatch (QD1/QD2 probe output, schema `impact-graph.v1`, ADR-18). Optional khi repo khong co code.
- `.mc-data/work/wf-fix-bugs/workloads/$FIX_ID/fix-workload.json` — workload artifact tu wf-fix-bugs Lane Dispatch (ADR-14). Resolve path tu `fix-status.json.workload_artifact_path` neu co.
- `$TARGET_SCOPE`, `$TARGET_DIRS`, `$TARGET_ROUTES`, `$FLAGS` — tu fix-status.json

**PRE-GATE:** `test -n "$DISCOVERED_ISSUES"` (tu $SESSION_DIR/issue-registry.json)

### CI-ROUTE: Bug Investigation (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus + Serena de trace bug flows thay vi Grep/Read thu cong.
> **Graceful:** CI unavailable → fallback Grep/Read (current behavior, zero regression).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("{bug_description}", task_context="fixing bug", goal="find execution flows related to bug")` | Grep + Read | Tim execution flows + symbols lien quan den bug, ranked by relevance |
| `find_definition` | **Serena** `find_definition` | Grep | Xac dinh vi tri chinh xac cua suspected function |
| `symbol_overview` | **Serena** `get_symbols_overview` | Read file | Hieu cau truc file chua bug |

> **Freshness caveat:** Neu freshness behind > 0 → "Results based on index N commits behind HEAD."

**PRE-GATE mo rong (CORE-011 forensic):**
```bash
# Co-requisites: issue-registry + fix-workload + impact-graph
jq -e '.issues | type == "array"' $SESSION_DIR/issue-registry.json \
  || { echo "PRE-GATE FAIL: issue-registry.json khong hop le"; exit 1; }

# Workload artifact optional nhung khuyen nghi — fallback empty neu thieu
WORKLOAD_PATH=$(jq -r '.workload_artifact_path // empty' $SESSION_DIR/fix-status.json)
if [ -z "$WORKLOAD_PATH" ]; then
  WORKLOAD_PATH="$SESSION_DIR/workloads/W01/fix-workload.json"
fi
test -f "$WORKLOAD_PATH" \
  && jq -e '.workload_id and (.total_estimated_seconds | type) == "number"' "$WORKLOAD_PATH" > /dev/null \
  || echo "WARN: fix-workload.json thieu hoac invalid — Execution Plan se dung fallback estimate"

# Impact graph optional — fallback skip blast_radius neu thieu
test -f $SESSION_DIR/impact-graph.json \
  && jq -e '."$schema" == "impact-graph.v1"' $SESSION_DIR/impact-graph.json > /dev/null \
  || echo "WARN: impact-graph.json thieu — blast_radius annotation se skip"
```

> **(Protocol 6 — 6.2/6.4)** Neu scan files vuot `$COMPRESSION_THRESHOLD` (LPM: >2 files, standard: >3 files):
> main conversation Grep key sections (REQ-IDs, error patterns) → tao digest theo `$DIGEST_SIZE` → triage agent nhan digest thay vi full files.
>
> - **Standard Digest (~200 tu/file):** REQ-IDs, quy trinh chinh, van de noi bat, nguon.
> - **Extended Digest (~300 tu/file, LPM):** Nhu Standard + priority, constraints, tech implications. Xem protocols/ §6.4 Extended Digest Format.

**OUTPUT:**
- `$SESSION_DIR/bug-triage.md` (template: `templates/bug-triage.md`)
- `$SESSION_DIR/fix-plan.md` (template: `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-plan.md` — canonical v10 sau Sprint 3 F07.010)
- `$SESSION_DIR/issue-registry.json` (UPDATE — da tao boi wf-fix-bugs Lane Dispatch POST-GATE)
- `$SESSION_DIR/fix-log.json` (template: `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-log.json` — canonical schema fix-log-v2 sau Sprint 3 XF-03)
- `$SESSION_DIR/phase-summary.md` (inline template — CORE-028 + Protocol 14, tieng Viet <=15 dong)

---

## Severity Mapping Table (Deterministic — Step 2.1)

> Cung issue.type + source → cung severity. KHONG AI subjective. Reproducible.

| Issue Type | Severity | Batch | Rationale |
|------------|----------|-------|-----------|
| `compile_error` | CRITICAL | 1 | Chan build — khong the tiep tuc |
| `type_error` | CRITICAL | 1 | Chan build / type safety |
| `missing_import` | CRITICAL | 1 | Chan build |
| `circular_dependency` | CRITICAL | 1 | Chan build / architecture |
| `registry_corruption` | CRITICAL | 1 | Chan toan bo pipeline |
| `test_failure` | HIGH | 2 | Anh huong chinh xac |
| `security_issue` | HIGH | 2 | Anh huong bao mat |
| `logic_bug` | HIGH | 2 | Anh huong logic nghiep vu |
| `data_loss_risk` | HIGH | 2 | Co mat du lieu |
| `runtime_error` | HIGH | 2 | Crash tai runtime |
| `api_contract_mismatch` | HIGH | 2 | Tich hop bi loi |
| `lint_error` | MEDIUM | 3 | Chat luong code |
| `orphan_code` | MEDIUM | 3 | Thieu REQ-ID — khong chan build |
| `registry_format` | MEDIUM | 3 | Format — khong chan pipeline |
| `missing_req_id` | MEDIUM | 3 | Compliance |
| `performance_warning` | MEDIUM | 3 | Performance |
| `style_suggestion` | LOW | 3 | Cosmetic |
| `informational` | LOW | 3 | Khong anh huong |
| `deprecated_module` | LOW | — | Ngoai scope — SKIP |
| `missing_doc` | — | — | ESCALATE — vuot scope tu dong |
| `design_issue` | — | — | ESCALATE — can architect review |
| `ux_decision_needed` | — | — | ESCALATE — can UX/business decision |

> **Fallback:** Neu issue.type khong co trong bang → severity = MEDIUM, batch = 3.

---

## Atomic Write Pattern (H2)

> Khi ghi `fix-status.json` va `issue-registry.json` — su dung atomic write de tranh corrupt khi interrupt:
> ```
> WRITE toi `$SESSION_DIR/.tmp-issue-registry.json` → `mv $SESSION_DIR/.tmp-issue-registry.json $SESSION_DIR/issue-registry.json`
> ```
> Pattern ap dung cho Step 2.3b (issue-registry.json) va POST-GATE (fix-status.json).

---

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 2.0  | **SCOPE FILTER (multi-source):** FOR each issue IN `$DISCOVERED_ISSUES`: IF issue.source == "static" → filter by `$TARGET_DIRS` (file path ngoai scope → OUT_OF_SCOPE). ELIF issue.source == "runtime" → filter by `$TARGET_ROUTES` (page_url ngoai scope → OUT_OF_SCOPE). ELIF issue.source == "gap" → PASS (Layer 4 gap issues khong co file path — luon trong scope). ELIF issue.source IN ["e2e", "data_verification", "visual", "responsive"] → filter by `$TARGET_ROUTES`. **Fallback:** Neu `$TARGET_DIRS` va `$TARGET_ROUTES` deu rong (scope=all khong kem routes explicit) → PASS tat ca. Log `OUT_OF_SCOPE` items rieng (danh dau `out_of_scope=true` tren issue object khi ghi registry). **DEPRECATED MODULES (CORE-022):** Neu LEGACY_MODE active va `$DEPRECATED_MODULES` (tu `legacy-decisions.json`) khong rong → FOR each issue: neu issue's module thuoc `$DEPRECATED_MODULES` → `out_of_scope=true`, `fixability=SKIP`. Graceful: neu `legacy-decisions.json` khong ton tai → `$DEPRECATED_MODULES=[]`, tiep tuc binh thuong (khong block). | Issues scoped |
| 2.0a | **Deep scan orphan issues (chi khi `flags.deep == true`):** VERIFY `$ORPHAN_UI_ISSUES` da duoc load o PRE-GATE §5 (KHONG re-load tu `checkpoint.json` de tranh race voi phase4-docs.md — checkpoint la SSOT, PRE-GATE da load). Neu `$ORPHAN_UI_ISSUES` chua co o PRE-GATE → STOP voi T009. Orphan issues KHONG merge vao `$DISCOVERED_ISSUES` — duoc xu ly rieng trong bug-triage.md section "UI→Docs Gap Analysis (--deep)". | Orphan issues verified |
| 2.0b | **Issue ID Assignment (BAT BUOC — Owner of issue_id field per CORE convention):** **PRE-CONDITION:** Confirm Lane Dispatch da de `issue_id = null` (khong assign o Phase 1). `NULL_COUNT=$(jq '[.issues[] \| select(.issue_id == null)] \| length' $SESSION_DIR/issue-registry.json)`; `TOTAL=$(jq '.issues \| length' $SESSION_DIR/issue-registry.json)`; `test "$NULL_COUNT" = "$TOTAL"` hoac STOP T010 "Expected all issue_id to be null (Lane Dispatch shouldn't assign). Got pre-assigned — contract violation." **ASSIGNMENT:** Sau scope filter (2.0) va orphan merge (2.0a), assign sequential `issue_id` ISSUE-001, ISSUE-002, ... to every item in `$DISCOVERED_ISSUES` va `$ORPHAN_UI_ISSUES`. Format: zero-padded 3-digit (`printf 'ISSUE-%03d' $N`). Store IDs back vao issue objects. **POST-CONDITION:** `INVALID=$(jq '[.issues[] \| select(.issue_id == null or (.issue_id \| test("^ISSUE-[0-9]{3}$") \| not))] \| length' $SESSION_DIR/issue-registry.json)`; `test "$INVALID" = "0"` hoac FAIL "Still $INVALID issues with invalid issue_id". | IDs assigned + regex valid |
| 2.1  | Phan loai issues theo severity: CRITICAL → HIGH → MEDIUM → LOW (LOW gom vao Batch 3 hoac SKIP tuy type) | Issues categorized |
| 2.1a | **Domain Detection per issue:** Map moi issue den module (tu file path + REQ-ID → registry.modules[].id). Xac dinh domain cua module theo **Domain Expert Routing** (xem §Domain Expert Routing ben duoi) → ghi `$ISSUE_DOMAIN` vao moi issue trong triage | Domains mapped |
| 2.1b | **Blast Radius Annotation (ADR-18 + ADR-22 rule 2):** Neu `$SESSION_DIR/impact-graph.json` ton tai → FOR each issue co `file_path` (hoac `target.file_path`): goi `_shared.impact_graph.ripple.verify_ripple()` voi depth=1, strength>=0.5 → populate `issue.blast_radius = { direct_count, critical_downstream[] }`. Issues KHONG co file_path (gap issues, runtime issues khong attach file) → set `blast_radius = {"direct_count": 0, "critical_downstream": []}`. **Severity bump rule:** Neu `direct_count >= 5` va severity hien tai la MEDIUM/LOW → bump len HIGH (moi bug o file share tren >=5 downstream co kha nang anh huong rong). Ghi lai decision vao `issue.severity_bump_reason` de truy vet. CLI fallback: `python -m _shared.impact_graph.ripple verify --issue <issue.json> --graph $SESSION_DIR/impact-graph.json --depth 1 --strength 0.5`. | blast_radius populated for code issues |
| 2.1c | **CI Live Impact Fallback (BAT BUOC khi `$GITNEXUS_AVAILABLE=true` VA `impact-graph.json` MISSING):** Neu impact-graph khong duoc build trong Phase 1 (builder unavailable / pre-existing graph absent) — FOR each issue co `file_path` va `symbol` (parse tu code_snippet hoac infer): goi MCP tool `mcp__plugin_gitnexus_gitnexus__impact({target: <symbol>, direction: "upstream"})`. Map ket qua: `direct_callers` → `blast_radius.direct_count`, `top_callers` → `blast_radius.critical_downstream[]`. Cap nhat `issue.blast_radius` va apply severity bump rule (giong 2.1b). Cap top 30 issues theo severity de tranh MCP overload. Ghi `issue.ci_meta = {gitnexus_used: true, freshness_level: <from PRE-GATE>, behind_commits: <N>}`. CI absent → skip step (issue.blast_radius giu nguyen tu 2.1b). Xem §CI-Aware Severity & Fixability ben duoi. | blast_radius populated via live MCP cho top-N issues |
| 2.1d | **User Journey Impact Detection (v9.0):** FOR each issue: (1) `cross_module_impact[]` = extract module IDs khi `issue.dimensions` chua "QD10" HOAC `issue.type` thuoc `CROSS_MODULE_SIGNALS` (xem §Step 2.1d ben duoi). Extract tu `issue.metadata.consumer_module` + `issue.metadata.provider_module`; fallback infer tu file path prefix (vd "MOD-CRM" tu "apps/crm/"). (2) `affected_flows[]` = `issue.metadata.flow_ids // []`; neu empty va `cross_module_impact.length > 1` → `["cross-module:" + join("-")]`. (3) SET `user_journey_broken = (cross_module_impact.length > 0 OR affected_flows.length > 0)`. (4) SET `data_consistency_risk`: "high" neu issue.type ∈ {orphan_reference_detected, entity_sync_response_shape_mismatch, data_loss_risk}; "medium" neu ∈ {api_contract_breaking_change, api_contract_type_mismatch, entity_sync_field_mismatch, cache_staleness_detected, cross_module_fk_mismatch}; "low" otherwise. **Severity bump rule (v9):** `user_journey_broken=true` VA severity ∉ {CRITICAL, HIGH} → SET severity=HIGH + SET `severity_bump_reason = (existing // "") + " + user_journey_broken=true"`. Graceful: issue khong co QD10 context → default values (false, [], [], "low"), zero regression. Xem §Step 2.1d — User Journey Impact Detection ben duoi. | user_journey_broken + data_consistency_risk populated; severity bumped if needed |
| 2.2  | Phan loai theo fixability (AUTO_FIX / AGENT_FIX / MANUAL_FIX / ESCALATE / SKIP — xem §Fixability Categories) | Fixability determined |
| 2.2a | **CI-Aware Fixability Escalation (BAT BUOC khi `$SERENA_AVAILABLE=true`):** FOR each issue voi `fixability=AGENT_FIX` VA `severity IN (CRITICAL, HIGH)` VA co `file_path`+`symbol`: goi MCP tool `mcp__serena__find_referencing_symbols({name_path: <symbol>, relative_path: <file>})`. Neu refs.length > 10 → ESCALATE fixability tu AGENT_FIX → MANUAL_FIX (cao surface — can architect review). Ghi `issue.fixability_escalation_reason = "serena_refs_count=<N> > 10 + severity>=HIGH"`. Neu refs.length > 30 → ESCALATE TIEP tu MANUAL_FIX → ESCALATE (queue cho team decision). Ghi `issue.ci_meta.serena_refs_count = <N>`. Cap top 50 issues HIGH/CRITICAL de tranh MCP overload. CI absent → skip step (giu nguyen fixability tu 2.2). Xem §CI-Aware Severity & Fixability. | fixability escalation applied + ci_meta populated |
| 2.3  | **BAT BUOC — Template Loading (CQG Protocol 8):** (1) READ template file `.claude/skills/workflow/wf-fix-triage/templates/bug-triage.md` (2) FILL triage data vao template: severity counts, issue tables (with "ID" column as first column after "#" in every table: `# \| ID \| Type \| Source \| ...`), scope info, preflight score, execution plan (3) WRITE result toi `$SESSION_DIR/bug-triage.md`. **NEU SKIP → STOP skill.** | `test -s $SESSION_DIR/bug-triage.md && grep -q "^# Bug Triage" $SESSION_DIR/bug-triage.md && grep -q "^## Summary" $SESSION_DIR/bug-triage.md && grep -q "^## Execution Plan" $SESSION_DIR/bug-triage.md` |
| 2.3a | **BAT BUOC — Fix Plan Creation (canonical v10 — Sprint 3 F07.010):** (1) READ template file `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-plan.md` (canonical v10 concise template — fix-plan.md la input cua wf-fix-execute) (2) Replace placeholder `[SESSION_ID]`, `[GENERATED_AT]`, va `[FIX_PLAN_ROWS]` (table content), `[BATCH1_COUNT]`, `[BATCH2_COUNT]`, `[BATCH3_COUNT]`, `[ESTIMATED_FIXES]`, `[ESTIMATED_TIME]`, `[ESTIMATED_COST]` bang gia tri thuc te. (3) FILL execution plan rows voi cac issue (Priority, Issue ID, Action, File, Est. Time, CDG Markers). (4) WRITE result toi `$SESSION_DIR/fix-plan.md`. **NEU SKIP → STOP skill.** | `test -s $SESSION_DIR/fix-plan.md && grep -q "Fix Plan" $SESSION_DIR/fix-plan.md && ! grep -q '\[SESSION_ID\]' $SESSION_DIR/fix-plan.md && ! grep -q '\[FIX_PLAN_ROWS\]' $SESSION_DIR/fix-plan.md` |
| 2.3b | **BAT BUOC — Issue Registry UPDATE (KHONG CREATE):** File `$SESSION_DIR/issue-registry.json` DA TON TAI — duoc tao boi wf-fix-bugs Lane Dispatch voi initial issue list (severity/fixability CHUA set). Phase 2 triage PHAI UPDATE (enrich), KHONG overwrite: (1) READ `$SESSION_DIR/issue-registry.json` hien tai (2) FOR each issue in `.issues[]`: SET `severity` (CRITICAL/HIGH/MEDIUM/LOW tu step 2.1), `batch` (1/2/3 tu severity), `fixability` (AUTO_FIX/AGENT_FIX/ESCALATE/SKIP tu step 2.2), `domain` (tu step 2.1a), `blast_radius` (tu step 2.1b, object `{direct_count, critical_downstream[]}` hoac `null`), `severity_bump_reason` (string, chi set khi step 2.1b bump — vd "blast_radius>=5 downstream"), `out_of_scope` (boolean, mac dinh false — true neu bi loc tai Step 2.0), **`user_journey_broken`** (boolean, mac dinh false — tu step 2.1d), **`affected_flows`** (array, mac dinh [] — tu step 2.1d), **`cross_module_impact`** (array, mac dinh [] — tu step 2.1d), **`data_consistency_risk`** (low|medium|high, mac dinh "low" — tu step 2.1d), giu nguyen cac fields khac (issue_id, type, source, status="discovered", file_path, line, description, req_id, page_url, element_ref, evidence, dimensions, dedup_key — tu Signal Bus schema v2). ALSO MERGE `$ORPHAN_UI_ISSUES` neu co (chi khi `flags.deep == true` va chua co trong registry) (3) WRITE lai `$SESSION_DIR/issue-registry.json` (atomic, single write). **Exception T004 (empty issues):** Neu `$DISCOVERED_ISSUES` effective = rong sau scope filter → KHONG UPDATE file (giu nguyen do wf-fix-bugs Lane Dispatch tao voi `.issues` rong). **CDG passthrough (ADR-22 rule 4):** Neu issue co `triage_status == "cdg_required"` (do Signal Bus set cho QD3 secrets) → GIU NGUYEN, orchestrator se xu ly CDG prompt. **NEU SKIP → wf-fix-execute PRE-GATE FAIL (issues khong co severity).** | `test -s $SESSION_DIR/issue-registry.json && (ISSUES_COUNT=$(jq '.issues \| length' $SESSION_DIR/issue-registry.json); [ "$ISSUES_COUNT" -eq 0 ] \|\| jq -e '.issues[0] \| has("severity") and has("fixability") and has("domain") and has("blast_radius")' $SESSION_DIR/issue-registry.json)` |
| 2.3c | **BAT BUOC — Fix Log Init (canonical schema fix-log-v2 — Sprint 3 XF-03):** (1) READ template file `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/fix-log.json` (canonical — co `$schema: "fix-log-v2"` field) (2) STRIP `_*` metadata fields theo Protocol 19 (jq walk pattern — xem `_shared.md §10`) (3) REPLACE placeholder `{{SESSION_ID}}` voi `session_id` thuc (4) SET `entries` to empty array `[]` (5) WRITE result to `$SESSION_DIR/fix-log.json`. **Muc dich:** Khoi tao fix-log.json voi entries rong truoc khi wf-fix-execute Phase 3 APPEND entries. **NEU SKIP → wf-fix-execute Phase 3 se CREATE tu template thay vi APPEND.** | `test -s $SESSION_DIR/fix-log.json && jq -e '."$schema" == "fix-log-v2"' $SESSION_DIR/fix-log.json && jq -e '.entries' $SESSION_DIR/fix-log.json` |
| 2.4  | Hien thi triage summary cho user | User sees summary |
| 2.5  | **Dry-run mode handling:** Neu `flags.dry_run == true`: Van tao DAY DU cac file (da tao o 2.3-2.3c). Hien thi: "Dry-run mode — bug-triage.md + fix-plan.md + fix-log.json da tao. wf-fix-execute SE chay o preview mode: skip Phase 3-5, chi tao fix-report.md o Phase 6." → Update fix-status.json `next_action="phase_3_execute"` (execute tu detect dry_run de skip Phase 3-5). | — |
| 2.6  | **Token & Checkpoint Planning (Protocol 9 + ADR-14):** Ghi vao bug-triage.md: token estimate per batch, checkpoint strategy, resume point. **Consume `fix-workload.json`** (tu PRE-GATE `$WORKLOAD_PATH`): doc `.total_estimated_seconds`, `.quality_dimensions[]` → them section "Workload Overview" voi total_minutes, QD breakdown, Workload Gate status (Plan A = continue, Plan B = user chose sub-scope). Neu `total_estimated_seconds > 2700` → flag `workload_gate_triggered: true` trong fix-status.json. Output files referenced: `bug-triage.md`, `fix-plan.md`, `issue_registry: $SESSION_DIR/issue-registry.json`, `fix_log: $SESSION_DIR/fix-log.json`, `workload_artifact: $WORKLOAD_PATH`. | Plan documented + workload section present |
| 2.7  | **User confirmation (Protocol 16 CDG):** Hoi user xac nhan truoc khi fix (chi neu `flags.dry_run == false`). Format: hien thi summary CRITICAL/HIGH/MEDIUM/ESCALATE/SKIP + prompt "yes/no/review chi tiet". Xem `.claude/skills/protocols/16-critical-decision-gate.md` | User confirmed |
| 2.8  | **BAT BUOC — phase-summary.md (CORE-028 + Protocol 14):** (1) Tao noi dung tieng Viet, <=20 dong, non-technical theo inline template (xem §Phase Summary Inline Template ben duoi). (2) WRITE toi `$SESSION_DIR/phase-summary.md`. (3) Hien thi inline cho user (Protocol 14.4). Sub-skill family: overwrite summary cua phase truoc. **Exception:** Neu POST-GATE fail sau 3 iterations → VAN tao voi status='THAT BAI' (Protocol 14.1). | `test -s $SESSION_DIR/phase-summary.md && LINES=$(wc -l < $SESSION_DIR/phase-summary.md) && test "$LINES" -le 20 && grep -q '## Da lam gi\|## Ket qua\|## Buoc tiep theo' $SESSION_DIR/phase-summary.md` |

> **Scope filter (2.0):** Buoc nay BAT BUOC khi `--scope != all`. Moi issue phai co file path thuoc `$TARGET_DIRS`. Issues ngoai scope bi loai TRUOC KHI triage.

---

## Fixability Categories

| Category  | Mo ta | Action |
| --------- | ----- | ------ |
| AUTO_FIX  | Compile errors, type errors, lint, orphan code, registry format | wf-fix-execute tu fix |
| AGENT_FIX | Test failures, logic bugs, security issues, **tao moi UI component/helper co spec ro rang** | Developer / Security / Frontend-developer agent fix |
| MANUAL_FIX | Architectural changes, multi-module refactors, complex config changes — can developer review + approve truoc khi auto-fix | Developer review + manual intervention |
| ESCALATE  | Missing docs, design issues, UI component can UX/business decision truoc | Log + recommend skill/action |
| SKIP      | **Thuan tuy** informational warnings, style suggestions — KHONG co code change | Log only |

> **QUY TAC PHAN LOAI BAT BUOC:**
> - Issue "can tao UI component moi" → chi la **SKIP** khi: (a) spec chua duoc thiet ke va can UX/business decision truoc, HOAC (b) nam ngoai scope $TARGET_DIRS.
> - Issue "can tao UI component moi" nhung mo ta du ro (biet duoc component name, behavior, input/output) → **AGENT_FIX** (spawn `frontend-developer`), **KHONG PHAI SKIP**.
> - Vi du: "reject reason hardcoded, can dialog nhap ly do" — spec ro (modal/dialog + input field + confirm button + goi API) → **AGENT_FIX**.
> - Vi du: "can thiet ke lai toan bo UX flow" — chua co spec → **ESCALATE**.

---

## CI-Aware Severity & Fixability (Step 2.1c + 2.2a)

> **Muc dich:** Khi GitNexus/Serena MCP co san, dung live tools de tang chinh xac severity (blast radius) va fixability (escalation surface).
> **Graceful:** CI absent → skip toan bo logic nay, giu nguyen severity tu 2.1b va fixability tu 2.2 (zero regression).
> **Tham chieu:** Protocol 20 §20.5 (CI-ROUTE), CLAUDE.md "MUST run impact analysis before editing".

### Step 2.1c — Live Impact Fallback (severity)

**Khi nao chay:**
- `$GITNEXUS_AVAILABLE == "true"` (tu PRE-GATE Step 0.Nb)
- `$SESSION_DIR/impact-graph.json` MISSING (Phase 1 builder fail / unavailable)

**Logic:**
```
FOR each issue trong issue-registry.json (top 30 theo severity):
  IF issue.file_path va issue.symbol (parse tu code_snippet hoac infer):
    callers = mcp__plugin_gitnexus_gitnexus__impact({
      target: issue.symbol,
      direction: "upstream",
      depth: 2
    })
    issue.blast_radius.direct_count = callers.direct.length
    issue.blast_radius.critical_downstream = callers.top_callers[0:5]
    IF callers.direct.length >= 5 AND issue.severity IN (MEDIUM, LOW):
      issue.severity = HIGH
      issue.severity_bump_reason = "ci_live_impact: direct_callers=N (>=5)"
    issue.ci_meta = {
      gitnexus_used: true,
      freshness_level: $FRESHNESS_LEVEL,
      behind_commits: $FRESHNESS_BEHIND
    }
```

**Cap top-N:** 30 issue dau theo (severity DESC, file_path nullness ASC) de tranh MCP overload. Issue ngoai top 30 → `blast_radius.direct_count = null` + `ci_meta.gitnexus_used = false`.

**Logging:** Append vao `$SESSION_DIR/triage-ci-log.json`:
```json
{ "step": "2.1c", "issues_processed": 30, "severity_bumped": 7, "duration_ms": 4200, "freshness_level": "ok" }
```

### Step 2.2a — Fixability Escalation (Serena refs)

**Khi nao chay:**
- `$SERENA_AVAILABLE == "true"` (tu PRE-GATE Step 0.Nb)

**Logic:**
```
FOR each issue voi fixability=AGENT_FIX VA severity IN (CRITICAL, HIGH) (top 50):
  IF issue.file_path va issue.symbol:
    refs = mcp__serena__find_referencing_symbols({
      name_path: issue.symbol,
      relative_path: issue.file_path
    })
    issue.ci_meta.serena_refs_count = refs.length
    IF refs.length > 30:
      issue.fixability = ESCALATE
      issue.fixability_escalation_reason = "serena_refs=N (>30) + severity=HIGH+ → team decision needed"
    ELIF refs.length > 10:
      issue.fixability = MANUAL_FIX
      issue.fixability_escalation_reason = "serena_refs=N (>10) + severity=HIGH+ → architect review needed"
```

**Threshold rationale:**
- `> 30 refs` → ESCALATE: change touches > 30 call sites, risk regression cao, can co-ordination cap team.
- `> 10 refs` → MANUAL_FIX: surface lon nhung trong tam tay 1 architect review.
- `≤ 10 refs` → giu AGENT_FIX (developer agent du suc handle).

**Cap top-N:** 50 issue HIGH/CRITICAL dau de tranh MCP overload. Issue HIGH/CRITICAL ngoai top 50 → giu fixability tu 2.2 + log warning.

**Logging:** Append vao `$SESSION_DIR/triage-ci-log.json`:
```json
{ "step": "2.2a", "issues_processed": 50, "escalated_to_manual": 12, "escalated_to_team": 3, "duration_ms": 6800 }
```

### Schema bo sung (issue-registry.json fields moi tu CI)

```json
{
  "issue_id": "ISSUE-NNN",
  "...": "...",
  "blast_radius": {
    "direct_count": 12,
    "critical_downstream": [...]
  },
  "ci_meta": {
    "gitnexus_used": true,
    "serena_refs_count": 18,
    "freshness_level": "ok",
    "behind_commits": 0
  },
  "severity_bump_reason": "ci_live_impact: direct_callers=12 (>=5) + user_journey_broken=true",
  "fixability_escalation_reason": "serena_refs=18 (>10) + severity=HIGH → architect review needed",
  "user_journey_broken": false,
  "affected_flows": [],
  "cross_module_impact": [],
  "data_consistency_risk": "low"
}
```

### Graceful Degradation

| Tinh huong | Hanh vi |
|------------|---------|
| `$GITNEXUS_AVAILABLE=false` va `impact-graph.json` MISSING | Skip 2.1c. Severity giu nguyen tu 2.1 (khong bump). Log "ci_live_impact: skipped (no gitnexus)" |
| `$SERENA_AVAILABLE=false` | Skip 2.2a. Fixability giu nguyen tu 2.2. Log "ci_fixability: skipped (no serena)" |
| MCP call fail giua chung | Catch exception, log warning, mark issue.ci_meta.partial=true, tiep tuc voi issue ke tiep |
| Issue khong co `symbol` (chi co `file_path`) | Skip CI cho issue do, log "ci_skipped: no_symbol" |

---

## Step 2.1d — User Journey Impact Detection (v9.0)

> **Muc dich:** Phat hien issues anh huong den user journey (luong nguoi dung bi gian doan boi cross-module gap). Severity auto-bump khi `user_journey_broken=true`.
> **Graceful:** Issues khong co QD10 dimension → default values (false, [], [], "low"). Zero regression voi sessions khong co QD10.

### Cross-module Signal Types (QD10)

```
CROSS_MODULE_SIGNALS = [
  "cross_module_ref_drift",               // P-QD10-cross-module-ref-static
  "api_contract_breaking_change",         // P-QD10-api-contract-drift
  "api_contract_type_mismatch",           // P-QD10-api-contract-drift
  "event_handler_missing",                // P-QD10-event-handler-coverage
  "event_handler_partial",                // P-QD10-event-handler-coverage
  "orphan_reference_detected",            // P-QD10-orphan-reference-runtime
  "cross_module_fk_mismatch",             // P-QD10-orphan-reference-runtime
  "entity_sync_response_shape_mismatch",  // P-QD10-multi-platform-entity-sync
  "entity_sync_field_mismatch",           // P-QD10-multi-platform-entity-sync
  "cache_staleness_detected"              // P-QD10-cache-staleness-probe
]
```

### Detection Logic per Issue

```
FOR each issue IN $DISCOVERED_ISSUES:

  // 1. cross_module_impact
  IF (issue.dimensions contains "QD10") OR (issue.type IN CROSS_MODULE_SIGNALS):
    cross_module_impact = []
    IF issue.metadata.consumer_module: cross_module_impact.push(issue.metadata.consumer_module)
    IF issue.metadata.provider_module: cross_module_impact.push(issue.metadata.provider_module)
    IF cross_module_impact empty AND issue.file_path:
      // Fallback: infer module prefix from file path (e.g. "apps/crm/" → "MOD-CRM")
      cross_module_impact = [infer_module_from_path(issue.file_path)]
  ELSE:
    cross_module_impact = []

  // 2. affected_flows
  affected_flows = issue.metadata.flow_ids // [] if absent
  IF affected_flows empty AND cross_module_impact.length > 1:
    // Cross-module pair = 1 implicit broken flow
    affected_flows = ["cross-module:" + cross_module_impact.join("-")]

  // 3. user_journey_broken
  user_journey_broken = (cross_module_impact.length > 0 OR affected_flows.length > 0)

  // 4. data_consistency_risk
  IF issue.type IN ["orphan_reference_detected", "entity_sync_response_shape_mismatch", "data_loss_risk"]:
    data_consistency_risk = "high"
  ELIF issue.type IN ["api_contract_breaking_change", "api_contract_type_mismatch",
                       "entity_sync_field_mismatch", "cache_staleness_detected",
                       "cross_module_fk_mismatch"]:
    data_consistency_risk = "medium"
  ELSE:
    data_consistency_risk = "low"

  // 5. Severity bump (v9 rule)
  IF user_journey_broken == true AND issue.severity NOT IN ["CRITICAL", "HIGH"]:
    old_severity = issue.severity
    issue.severity = "HIGH"
    existing_reason = issue.severity_bump_reason // ""
    issue.severity_bump_reason = existing_reason +
      (IF existing_reason != "" THEN " + " ELSE "") +
      "user_journey_broken=true (cross_module_impact=" + cross_module_impact.join(",") +
      " / affected_flows=" + affected_flows.join(",") + ")"
```

### Defaults (no QD10 context)

| Field | Default |
|-------|---------|
| `user_journey_broken` | `false` |
| `affected_flows` | `[]` |
| `cross_module_impact` | `[]` |
| `data_consistency_risk` | `"low"` |

### Graceful Degradation

| Tinh huong | Hanh vi |
|------------|---------|
| Issue khong co `dimensions` field | `cross_module_impact = []`, `user_journey_broken = false` |
| `issue.metadata` null hoac absent | `affected_flows = []`, dung fallback path inference cho cross_module_impact |
| QD10 lane khong chay | Tat ca issues co default values — zero regression voi pre-v9 sessions |
| Module prefix khong infer duoc tu file path | `cross_module_impact = []` — khong force-assign unknown module |

---

## Domain Expert Routing

> Tu step 2.1a, moi issue duoc gan `domain` field. wf-fix-execute se spawn agent tuong ung.

| Module / Nghiep vu | Domain | Agent |
|--------------------|--------|-------|
| CRM, Sales, Customer Management | sales | sales-expert + developer |
| ERP Finance, Accounting, GL, AR, AP | finance | finance-expert + developer |
| HR, Payroll, Timesheet, Recruitment | hr | hr-expert + developer |
| Procurement, Vendor, PO, RFQ | procurement | procurement-expert + developer |
| Manufacturing, MES, BOM, MRP | manufacturing | manufacturing-expert + developer |
| Retail, POS, Chain Store, Loyalty | retail | retail-expert + developer |
| E-commerce, Marketplace, Cart, Checkout | ecommerce | ecommerce-expert + developer |
| Logistics, TMS, WMS, Customs | logistics | logistics-expert + developer |
| Healthcare, EMR, EHR, Patient, Clinic | healthcare | healthcare-expert + developer |
| Education, LMS, School, Course | education | education-expert + developer |
| Real Estate, Property, BDS | real-estate | real-estate-expert + developer |
| Insurance, Policy, Claims | insurance | insurance-expert + developer |
| Investment, Fund, Portfolio | investment | investment-expert + developer |
| Legal, Contract, Compliance | legal | legal-expert + developer |
| Marketing, Campaign, Lead | marketing | marketing-expert + developer |
| Paid Media, PPC, Ad Campaigns | paid-media | paid-media-expert + developer |
| Customer Support, CX, Helpdesk | customer | customer-expert + developer |
| Operations, Inventory, Supply Chain | operations | operations-expert + developer |
| Quality, QMS, Six Sigma, FMEA | quality | quality-excellence-expert + developer |
| Enterprise Risk, ERM, KRI, BCP | risk | enterprise-risk-expert + developer |
| Regulatory Compliance, AML, GDPR | compliance | compliance-expert + developer |
| Strategy, OKR, BSC, M&A | strategy | strategy-expert + developer |
| Data, BI, Analytics, Reporting | data | data-expert + developer |
| Product, Roadmap, MVP, Backlog | product | product-expert + developer |

**Fallback logic:**
- Neu file path chua rieng trong app specific module → lookup module tu `registry.modules[]`
- Neu khong match cu the → `domain = "general"` → `developer` agent (khong spawn domain expert)
- Cross-cutting concerns (auth, i18n, utils, shared) → `domain = "general"` → `developer`

---

## Hien thi triage

```
▶ Bug Triage
────────────
Tim thay N issues:
  CRITICAL: X (se fix ngay)
  HIGH:     Y (se fix)
  MEDIUM:   Z (auto-fix)
  ESCALATE: W (can user xu ly)
  SKIP:     V (informational)

Ban co muon tien hanh fix khong? (yes / no / review chi tiet)
```

---

## Token & Checkpoint Planning (Protocol 9 — PLN-11)

```
TRONG bug-triage.md, bo sung section "Execution Plan":

### Execution Plan
| Batch | Issues | Est. Tokens | Owner | Checkpoint |
|-------|--------|-------------|-------|------------|
| Batch 1 (CRITICAL) | N | ~(N × 10K) | skill (auto) | Sau batch 1 |
| Batch 2 (HIGH) | N | ~(N × 10K) | developer / domain-expert | Sau batch 2 |
| Batch 3 (MEDIUM) | N | ~(N × 5K) | skill (auto) | Sau batch 3 |

Resume point: batch_number + last_fixed_issue_id
Token estimate: Σ(agents × 10K) + Σ(files × 2K) + validation(4K)

NEU estimated_tokens > 60% context_limit:
  → Chia batches thanh sessions, checkpoint sau moi batch
  → Thong bao user: "Task nay can nhieu sessions"
```

---

## Phase Summary Inline Template (Step 2.8 — CORE-028)

> Tao `$SESSION_DIR/phase-summary.md` voi noi dung duoi day sau khi POST-GATE T1-T4 pass.
> Tieng Viet, <=15 dong, non-technical. Thay `[...]` bang gia tri thuc te.

```markdown
# Tom Tat: /wf-fix-triage

**Thoi gian:** [YYYY-MM-DD HH:mm:ss]
**Trang thai:** HOAN THANH | HOAN THANH CO LUU Y | THAT BAI

## Da lam gi
- Phan loai [N] loi theo muc do nghiem trong va kha nang tu sua.
- Len ke hoach thuc thi [N] batch, uoc tinh [N] tokens.

## Ket qua
- CRITICAL: [X] | HIGH: [Y] | MEDIUM: [Z] | LOW: [W]
- Tu sua tu dong: [N] | Can agent ho tro: [N] | Chuyen nguoi xu ly: [N]
- [N] loi ngoai pham vi (neu co scope filter)

## Can luu y
- [Chi ghi items can user action. Neu khong co: "Khong co"]

## Buoc tiep theo
- Quay lai `/wf-fix-bugs` de tiep tuc (spawn `/wf-fix-execute`)
```

**Rules (Protocol 14.2):**
- Lead voi KET QUA, khong mo ta qua trinh.
- "Can luu y" chi items can user action — khong warnings da auto-fix.
- Resume (--resume): giu nguyen summary cu, chi update khi phase complete (Protocol 14.3).
- Orchestrator family: overwrite summary cua phase truoc.

---

**POST-GATE (Protocol 10 — T1→T4):**
```bash
# ===== T1 Existence =====
test -s $SESSION_DIR/bug-triage.md \
  && test -s $SESSION_DIR/fix-plan.md \
  && test -s $SESSION_DIR/issue-registry.json \
  && test -s $SESSION_DIR/fix-log.json \
  && test -s $SESSION_DIR/phase-summary.md \
  || { echo "POST-GATE T1 FAIL: missing required output files"; exit 1; }

# ===== T2 Structure — bug-triage.md sections =====
grep -q '^## Workload Overview' $SESSION_DIR/bug-triage.md \
  || { echo "POST-GATE T2 FAIL: bug-triage.md missing Workload Overview section"; exit 1; }
grep -q '^## Execution Plan' $SESSION_DIR/bug-triage.md \
  || { echo "POST-GATE T2 FAIL: bug-triage.md missing Execution Plan section"; exit 1; }

# ===== T3 Content — issue-registry enriched =====
ISSUES_COUNT=$(jq '.issues | length' $SESSION_DIR/issue-registry.json)
if [ "$ISSUES_COUNT" -gt 0 ]; then
  # Moi issue phai co severity + fixability + domain + blast_radius (ADR-22 rule 2)
  jq -e '.issues | all(has("severity") and has("fixability") and has("domain") and has("blast_radius"))' \
    $SESSION_DIR/issue-registry.json \
    || { echo "POST-GATE T3 FAIL: issue-registry.json missing triage fields (severity/fixability/domain/blast_radius)"; exit 1; }
  # blast_radius phai co direct_count (number) va critical_downstream (array)
  jq -e '.issues | all(.blast_radius | has("direct_count") and has("critical_downstream") and (.direct_count | type) == "number")' \
    $SESSION_DIR/issue-registry.json \
    || { echo "POST-GATE T3 FAIL: issue-registry.json blast_radius schema invalid"; exit 1; }
fi

jq -e '."$schema" == "fix-log-v2"' $SESSION_DIR/fix-log.json > /dev/null \
  || { echo "POST-GATE T3 FAIL: fix-log.json missing/invalid \$schema (expected fix-log-v2)"; exit 1; }
jq -e '.entries' $SESSION_DIR/fix-log.json > /dev/null \
  || { echo "POST-GATE T3 FAIL: fix-log.json missing entries array"; exit 1; }

# ===== T4 Cross-reference — Workload ID consistency (neu co fix-workload.json) =====
WORKLOAD_PATH=$(jq -r '.workload_artifact_path // empty' $SESSION_DIR/fix-status.json 2>/dev/null)
if [ -z "$WORKLOAD_PATH" ]; then
  FIX_ID=$(jq -r '.fix_id' $SESSION_DIR/fix-status.json)
  WORKLOAD_PATH=".mc-data/work/wf-fix-bugs/workloads/${FIX_ID}/fix-workload.json"
fi
if [ -f "$WORKLOAD_PATH" ]; then
  WL_ID=$(jq -r '.workload_id' "$WORKLOAD_PATH")
  FIX_ID=$(jq -r '.fix_id' $SESSION_DIR/fix-status.json)
  test "$WL_ID" = "$FIX_ID" \
    || { echo "POST-GATE T4 FAIL: workload_id ($WL_ID) != fix_id ($FIX_ID)"; exit 1; }
  # Workload overview trong bug-triage phai trung total_minutes voi fix-workload
  WL_SECONDS=$(jq -r '.total_estimated_seconds' "$WORKLOAD_PATH")
  WL_MINUTES=$(( (WL_SECONDS + 30) / 60 ))
  grep -qE "total[_ ]minutes[^0-9]*${WL_MINUTES}|${WL_MINUTES}[[:space:]]*phut|${WL_MINUTES}[[:space:]]*min" \
       $SESSION_DIR/bug-triage.md \
    || echo "POST-GATE T4 WARN: Workload Overview total minutes in bug-triage.md may not match fix-workload.json ($WL_MINUTES min)"
fi

# ===== Phase-summary structural check (CORE-028) =====
LINES=$(wc -l < $SESSION_DIR/phase-summary.md)
test "$LINES" -le 20 \
  || { echo "POST-GATE FAIL: phase-summary.md exceeds 20 lines"; exit 1; }
grep -q '## Da lam gi\|## Ket qua\|## Buoc tiep theo' $SESSION_DIR/phase-summary.md \
  || { echo "POST-GATE FAIL: phase-summary.md missing required sections"; exit 1; }

# ===== User confirmation gate (CDG — neu khong dry-run) =====
# (flags.dry_run == true || user confirmed qua CDG)
```

**FAIL handling (Protocol 2 Auto-Correction):** retry output creation x3, escalate T007.
**phase-summary.md fail:** VAN tao voi status='THAT BAI' (Protocol 14.1 exception).

> **BAT BUOC:** Update fix-status.json theo spec "Phase 2 POST-GATE" trong SKILL.md §POST-GATE
> (them `output_files.phase_summary = "$SESSION_DIR/phase-summary.md"`, `issues.out_of_scope`).

---

## POST-GATE Tiered Validation (T1→T6)

> Reference: `procedures/_shared.md §T2` cho summary table. Block dưới là canonical bash implementation.
> Extracted từ SKILL.md theo XF-07b (audit 2026-05-15 Sprint 4).

### T1-T3: Structural + Schema + Content checks

```bash
# T1 (existence) + T2 (structure) + T3 (content)
test -s $SESSION_DIR/bug-triage.md
test -s $SESSION_DIR/fix-plan.md
test -s $SESSION_DIR/issue-registry.json
test -s $SESSION_DIR/fix-log.json

# T4 schema gate (skip neu .issues rong — xem T004 handling)
ISSUES_COUNT=$(jq '.issues | length' $SESSION_DIR/issue-registry.json)
if [ "$ISSUES_COUNT" -gt 0 ]; then
  jq -e '.issues[0] | has("severity") and has("fixability") and has("domain")' $SESSION_DIR/issue-registry.json
fi

# CORE-028: phase-summary.md BAT BUOC + content depth
test -s $SESSION_DIR/phase-summary.md
LINES=$(wc -l < $SESSION_DIR/phase-summary.md)
test "$LINES" -le 20
grep -q '## Da lam gi\|## Ket qua\|## Buoc tiep theo' $SESSION_DIR/phase-summary.md
```

### T5: Anti-Invention Check (BẮT BUỘC)

bug-triage.md / fix-plan.md / issue-registry.json KHÔNG được chứa các thuật ngữ cấm (xem SKILL.md §Anti-Invention Rule):

```bash
FORBIDDEN_PATTERN='FIX NOW|FIX IF BUDGET|DEFER MANUAL|DEFER BACKLOG|TODO LATER|FOLLOW-UP|POSTPONE'
for f in "$SESSION_DIR/bug-triage.md" "$SESSION_DIR/fix-plan.md"; do
  if grep -Eq "$FORBIDDEN_PATTERN" "$f" 2>/dev/null; then
    echo "T5 FAIL: $f chua thuat ngu cam (Anti-Invention Rule)" >&2
    exit 1  # → retry hoac escalate T012
  fi
done

# issue-registry.json: kiem tra fixability ∈ canonical {AUTO_FIX,AGENT_FIX,MANUAL_FIX,ESCALATE,SKIP}
INVALID_FIX=$(jq -r '[.issues[] | .fixability // empty] | unique | map(select(. as $f | ["AUTO_FIX","AGENT_FIX","MANUAL_FIX","ESCALATE","SKIP"] | index($f) == null)) | length' "$SESSION_DIR/issue-registry.json")
test "$INVALID_FIX" = "0" || { echo "T5 FAIL: issue-registry.json co fixability ngoai canonical taxonomy" >&2; exit 1; }
```

### T6: Profile Coverage Check

`exhaustive` profile KHÔNG được skip MEDIUM/LOW với reason 'budget':

```bash
PROFILE=$(jq -r '.flags.profile // "standard"' $SESSION_DIR/fix-status.json)
if [ "$PROFILE" = "exhaustive" ]; then
  SKIPPED_BY_BUDGET=$(jq -r '[.issues[] | select(.fixability == "SKIP" and ((.skip_reason // "") | test("budget|backlog|defer"; "i")))] | length' $SESSION_DIR/issue-registry.json)
  test "$SKIPPED_BY_BUDGET" = "0" || { echo "T6 FAIL: exhaustive profile khong duoc skip MEDIUM/LOW vi 'budget'" >&2; exit 1; }
fi
```

### Step P1: User Confirmation (CDG — Protocol 16)

Áp dụng khi `flags.dry_run == false`. CDG render ở Step 2.7 — POST-GATE chỉ verify confirmation token.

### Step P2: escalations.json Artifact Builder (BẮT BUỘC nếu có MANUAL_FIX/ESCALATE)

```bash
ESCALATE_COUNT=$(jq -r '[.issues[] | select(.fixability == "MANUAL_FIX" or .fixability == "ESCALATE")] | length' $SESSION_DIR/issue-registry.json)
if [ "$ESCALATE_COUNT" -gt 0 ]; then
  # Build escalations.json theo schema escalations-v1
  jq -r '{
    "$schema": "escalations-v1",
    "session_id": (input_filename | split("/")[-2]),
    "generated_at": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    "items": [.issues[] | select(.fixability == "MANUAL_FIX" or .fixability == "ESCALATE") | {
      issue_id, severity, fixability, title,
      file: (.target.file_path // null),
      line: (.target.line // null),
      req_ids: (.req_ids // []),
      stakeholder_hint: (
        if (.evidence // []) | map(.content // "") | join(" ") | test("compliance|legal|GDPR|Decree|PCI|SOC2"; "i") then "legal"
        elif .severity == "CRITICAL" or .fixability == "ESCALATE" then "architect"
        else "product_owner" end
      ),
      rationale: (.fixability_reason // .description_md // "Manual review required"),
      suggested_skill: (
        if .fixability == "ESCALATE" and ((.evidence // []) | map(.content // "") | join(" ") | test("missing.*spec|missing.*doc"; "i")) then "/wf-define-features"
        elif .fixability == "ESCALATE" and ((.evidence // []) | map(.content // "") | join(" ") | test("design"; "i")) then "/wf-design"
        else "/wf-fix-bugs --resume" end
      )
    }]
  }' $SESSION_DIR/issue-registry.json > $SESSION_DIR/escalations.json.tmp.$$
  jq '.' $SESSION_DIR/escalations.json.tmp.$$ > /dev/null  # validate
  mv $SESSION_DIR/escalations.json.tmp.$$ $SESSION_DIR/escalations.json
fi
```

### Step P3: UPDATE fix-status.json (atomic write — Safe-Write Protocol CORE-006)

```
phases.phase_2.status = "completed"
phases.phase_2.completed_at = NOW
issues.by_severity.* = {critical, high, medium, low} counts
issues.by_action.* = {auto_fix, agent_fix, manual_fix, escalate, skip} counts
issues.by_orphan_type.* (neu flags.deep)
issues.out_of_scope = <count> (issues bi loc o Step 2.0)
issues.escalation_count = $ESCALATE_COUNT (so MANUAL_FIX + ESCALATE)
output_files.triage_report = "$SESSION_DIR/bug-triage.md"
output_files.fix_plan = "$SESSION_DIR/fix-plan.md"
output_files.issue_registry = "$SESSION_DIR/issue-registry.json"
output_files.fix_log = "$SESSION_DIR/fix-log.json"
output_files.phase_summary = "$SESSION_DIR/phase-summary.md"
output_files.escalations = "$SESSION_DIR/escalations.json" (neu co)
progress_pct = 30 (nhay tu 20 -> 30 sau triage)
active_skill = "wf-fix-bugs"
next_action = "phase_3_execute"  (orchestrator luon spawn wf-fix-execute; execute tu detect flags.dry_run de skip Phase 3-5)
timestamps.last_updated = NOW
```

### Step P4: Display + Return Control

- Hiển thị nội dung phase-summary.md inline cho user (Protocol 14.4)
- Hiển thị summary orchestrator: "Triage complete. [N] issues classified. [E] escalations require human review. Returning to wf-fix-bugs for [next step]."

### FAIL Handling (Protocol 2 — Auto-Correction Loop)

| Tier | FAIL | Auto-fix strategy | Escalate code |
|------|------|-------------------|---------------|
| T1-T3 | Output missing/invalid | Retry tạo lại file (max 3 iterations) | T007 |
| T5 | Anti-Invention | Retry tạo lại bug-triage.md + fix-plan.md (max 3) | T012 |
| T6 | Profile Coverage | Retry triage với exhaustive profile rule (max 3) | T013 |
| phase-summary | fail sau 3 iterations | VẪN tạo với status='THAT BAI' (Protocol 14.1 exception) | — |

---

## Next Phase

Triage xong. Return control ve **wf-fix-bugs** orchestrator:
- fix-status.json: `phases.phase_2.status="completed"`, `active_skill="wf-fix-bugs"`, `next_action="phase_3_execute"`
- wf-fix-bugs se spawn **wf-fix-execute** (neu khong dry-run) hoac chay Phase 6 Report (neu dry-run — execute tu detect flags.dry_run de skip Phase 3-5)
- wf-fix-execute nhan input: `$SESSION_DIR/bug-triage.md`, `fix-plan.md`, `issue-registry.json` (enriched), `fix-log.json` (init)
