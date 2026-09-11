# Shared Protocols — wf-fix-execute

> Cross-cutting protocols, state variables glossary, agent prompt templates va fix-status.json Update Contract duoc dung boi nhieu Phase.
> KHONG doc file nay standalone — chi load section cu the khi can.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [fix-status.json Update Contract](#fix-statusjson-update-contract)
- [Developer Selection Protocol](#developer-selection-protocol)
- [Domain Expert Routing](#domain-expert-routing)
- [Agent Context Template](#agent-context-template)
- [Symbolic Editing Preference](#symbolic-editing-preference)
- [Agent Output Spot-Check Protocol](#agent-output-spot-check-protocol)
- [Scope Boundary Rule](#scope-boundary-rule)
- [Registry Safe-Write](#registry-safe-write)
- [Context Digest Generation](#context-digest-generation)
- [CORE-027 Critical Decision Gate](#core-027-critical-decision-gate)
- [Execution Trace Protocol](#execution-trace-protocol)
- [Error Codes](#error-codes)
- [Checkpoint Protocol](#checkpoint-protocol)

---

## State Variables Glossary

Cac bien in-memory duoc set/doc xuyen suot skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$SESSION_DIR` | PRE-GATE | 3, 4, 5, 6 | Session directory — chua fix-status.json, issue-registry.json, fix-log.json |
| `$DRY_RUN_MODE` | PRE-GATE | 3, 4, 5, 6 | Boolean — true neu `flags.dry_run == true`, skip Phase 3-5 |
| `$TARGET_DIRS` | PRE-GATE | 3, 4, 5 | Array paths cho scope boundary — agents khong modify ngoai scope |
| `$TARGET_SCOPE` | PRE-GATE | 4a, 5 | Object `{ systems[], modules[], reqs[] }` |
| `$ARCH_DIGEST` | PRE-GATE | 3 | Architecture digest (tech stack, patterns, API summary) neu co |
| `$LARGE_PROJECT` | PRE-GATE | 3, 6 | Boolean — large project mode |
| `$LPM_PARAMS` | PRE-GATE | 3, 6 | `{ max_parallel_agents, skeleton_threshold, checkpoint_strategy }` (LPM: 3, standard: 5) |
| `$RUN_TESTS` | PRE-GATE | 3, 5 | Boolean — flag chay tests sau fix |
| `$ROUTES_TO_VERIFY` | Phase 5.0 | 5.14 | Routes deduped tu fix-log.json route_map + shared code detection |
| `$VERIFY_SCOPE` | Phase 5.0 | 5.x | `{ fixed_issues[], all_issues[] }` — full regression scope |
| `$ORPHAN_UI_ISSUES` | PRE-GATE | 4b | Orphan UI items tu checkpoint.json (chi --deep) |
| `$ORPHAN_UI_ISSUES_FOR_STUB` | Phase 4b invalidation | 4b stub creation | Filtered orphan items sau invalidation logic |
| `$ISSUE_DOMAIN` | Phase 3.2 | 3.2.2a | Primary domain cua batch (finance/procurement/...) neu match |
| `$PV_COUNT` | PRE-GATE (v9.2.0) | 3, 5, 6 | Process violation count tu process-violations.json |
| `$PV_CRITICAL` | PRE-GATE (v9.2.0) | 3, 5 | Critical process violation count — block execute neu >0 |
| `$PV_HIGH` | PRE-GATE (v9.2.0) | 3, 5, 6 | High process violation count — warn, tiep tuc |
| `$SOURCE_STATIC` | PRE-GATE (v9.2.0) | 3, 6 | Static scan issue count (do tin cay CAO) |
| `$SOURCE_RUNTIME` | PRE-GATE (v9.2.0) | 3, 6 | Runtime issue count (do tin cay CAO) |
| `$SOURCE_LLM` | PRE-GATE (v9.2.0) | 3, 6 | LLM scan issue count (do tin cay TRUNG BINH) |
| `$QD11_ENHANCEMENT_COUNT` | PRE-GATE (v9.2.0) | 3, 6 | QD11 enhancement signal count — escalate, KHONG fix |
| `$CDG_REJECT_COUNT` | PRE-GATE (v9.2.0) | 3, 4, 5 | So CDG decisions bi user REJECT |
| `error_log[]` | All phases | Phase 6 | Array errors — dung cho final report |

---

## Cross-Phase Data Flow

```
PRE-GATE                  → $SESSION_DIR, $DRY_RUN_MODE, $TARGET_DIRS/SCOPE,
                            $ARCH_DIGEST, $LARGE_PROJECT, $LPM_PARAMS, $RUN_TESTS

Phase 3 Batch 1 (CRITICAL)→ fix-log.json (APPEND), issue-registry.json (UPDATE),
                            checkpoint.json (ADDITIVE context_digest)
Phase 3 Batch 2 (HIGH)    → fix-log.json (APPEND), issue-registry.json (UPDATE)
Phase 3 Batch 3 (MED+LOW) → fix-log.json (APPEND) + flush verify

Phase 4a (Docs Sync)      → phase2-features/**.md (UPDATE), req-registry.json (impl_status)
Phase 4b (Stubs --deep)   → phase2-features/**.md, phase4-ux/**.md (CREATE stubs)

Phase 5 SCAN              → issue-registry.json (status=regression neu co),
                            fix-status.playwright_verify, e2e-results.json (conditional)
Phase 5 LOOP              → partial Phase 3 + delta Phase 4 + rescan
Phase 5 FINAL             → fix_success_rate, verify.verified=true per issue

Phase 6                   → fix-report.md, fix-history.md (APPEND), phase-summary.md
```

---

## v9.2.0 Source-Aware Fix Protocol

> **Muc dich:** Fix strategy khac nhau tuy theo `source` cua signal. Static scan evidence ro rang → fix inline. Runtime evidence thuc te → spawn agent. LLM scan co the false positive → verify evidence truoc khi fix.
> **Ap dung:** Phase 3 (tat ca batches).

### Source → Fix Mode Routing

| Source | Fix Mode | Agent | Verification | Notes |
|--------|----------|-------|-------------|-------|
| `static-scan` | **Inline Edit** | Khong spawn agent | `tsc --noEmit` hoac equivalent | Static probes co evidence ro rang, repeatable. Fix don gian (lint, type, format). |
| `runtime` | **Agent Fix** | `developer` hoac `frontend-developer` | Playwright verify + test suite | Runtime observation co bang chung thuc te. |
| `llm-scan` | **Agent Fix + Scrutiny** | `developer` (sau verify) | Evidence re-verify + test suite | LLM co the false positive. PHAI verify evidence (file_path, code snippet) TRUOC khi spawn agent. |
| `null` / `""` (legacy) | **Agent Fix** | `developer` | Normal | Session cu khong co source tagging. Default heuristic. |

### QD11 Enhancement Signal Handling (v9.1.0 + v9.2.0)

```
IF issue.dimension_id == "QD11" THEN:
  - fixability = "escalate" (LUON LUON)
  - KHONG fix (block fix attempt → E044)
  - Day vao escalations.json
  - Can user ACCEPT/REJECT qua CDG gate
END IF
```

### LLM Scan Scrutiny Rules (v9.2.0)

Truoc khi fix LLM-scan signals, verify:

1. **Evidence check:** file_path co cu the khong? Co code snippet khong?
2. **Target check:** target.kind co phai "logical" khong? (logical targets khong co file cu the → escalate)
3. **Signal type check:** signal_type co phai "MISSING_FEATURE" hoac "MISSING_FIELD" khong? (can business decision → escalate)
4. **Description clarity:** description co mo ho khong? (>80% mo ho → escalate)

```
IF source == "llm-scan" THEN:
  IF location.file == null OR description mo ho OR target.kind == "logical" THEN:
    → escalate (E045: LLM Fix Without Verification)
  ELSE IF signal_type IN ["MISSING_FEATURE", "MISSING_FIELD"]:
    → escalate (can business decision)
  ELSE:
    → spawn agent fix (sau khi verify evidence)
END IF
```

### Process Violation Impact on Execute (v9.2.0)

```
IF $PV_CRITICAL > 0 THEN:
  → DUNG, CDG render (E029): "Phase 1 co process violation CRITICAL. Tiep tuc execute?"
  → Neu user chon tiep tuc: ghi "process_violation_impact" vao fix-log metadata
  → Issues tu dimension bi anh huong co the khong day du

IF $PV_HIGH > 0 THEN:
  → WARN, tiep tuc
  → Ghi "process_violation_impact" vao fix-log metadata
```

---

## fix-status.json Update Contract

Moi Phase phai update `$SESSION_DIR/fix-status.json` theo spec sau:

### Phase 3 BAT DAU
```
phases.phase_3.status = "in_progress"
phases.phase_3.started_at = NOW
timestamps.last_updated = NOW
active_skill = "wf-fix-execute"
next_action = "phase_3_batch_1"
```

### Sau Batch 1 (CRITICAL completed)
```
phases.phase_3.batches.batch_1.status = "completed"
phases.phase_3.batches.batch_1.completed_at = NOW
phases.phase_3.batches.batch_1.issues_fixed = N_CRITICAL
issues.fixed += N_CRITICAL
progress_pct = 40
metrics.batches_completed += 1
timestamps.last_updated = NOW
```

### Sau Batch 2 (HIGH completed)
```
phases.phase_3.batches.batch_2.status = "completed"
phases.phase_3.batches.batch_2.completed_at = NOW
phases.phase_3.batches.batch_2.issues_fixed = N_HIGH
issues.fixed += N_HIGH
progress_pct = 50
metrics.batches_completed += 1
# Neu sub-batches: phases.phase_3.batches.batch_2.sub_batch_progress = { total, completed }
```

### Sau Batch 3 (MEDIUM+LOW completed)
```
phases.phase_3.batches.batch_3.status = "completed"
phases.phase_3.batches.batch_3.completed_at = NOW
phases.phase_3.batches.batch_3.issues_fixed = N_MED_LOW
issues.fixed += N_MED_LOW
phases.phase_3.status = "completed"
phases.phase_3.completed_at = NOW
progress_pct = 65
metrics.batches_completed += 1
next_action = "phase_4_docs_sync"
```

### Phase 4a POST-GATE
```
phases.phase_4.sub_phases.phase_4a.status = "completed"
phases.phase_4.sub_phases.phase_4a.completed_at = NOW
metrics.docs_synced = N
docs_updated = [list]
progress_pct = 75
next_action = IF flags.deep THEN "phase_4b_stubs" ELSE "phase_5_verify"
```

### Phase 4b POST-GATE (--deep only)
```
phases.phase_4.sub_phases.phase_4b.status = "completed"
phases.phase_4.sub_phases.phase_4b.stubs_created = N
phases.phase_4.sub_phases.phase_4b.completed_at = NOW
phases.phase_4.status = "completed"
progress_pct = 80
next_action = "phase_5_verify"
```

### Phase 5 LOOP START (moi iteration — VERIFY_INIT owner)
```
phases.phase_5.status = "in_progress"
phases.phase_5.loop_state.current_iteration += 1    # ONLY place to increment
phases.phase_5.loop_state.state = "VERIFY_INIT"
phases.phase_5.iterations_run = current_iteration
phases.phase_5.loop_state.iteration_history[].append({ iteration, started_at })
```

> **Contract:** VERIFY_INIT la OWNER DUY NHAT cua `current_iteration += 1`. VERIFY_FIX / VERIFY_DOCS / VERIFY_RESCAN **KHONG duoc tu tang** iteration counter. Khi EVALUATE decide LOOP, RESCAN phai di qua VERIFY_INIT → tu dong tang. Tranh double-increment.

### Phase 5 LOOP FIX/DOCS (trong iteration — KHONG tang iteration)
```
phases.phase_5.loop_state.state = "VERIFY_FIX" / "VERIFY_DOCS" / "VERIFY_RESCAN"
# Append context vao iteration_history[-1]
# GIU NGUYEN current_iteration — chi VERIFY_INIT moi tang
```

### Phase 5 POST-GATE (FINAL)
```
phases.phase_5.status = "completed"
phases.phase_5.completed_at = NOW
phases.phase_5.iterations_run = final_iteration
phases.phase_5.fix_success_rate = X%
phases.phase_5.loop_state.current_iteration = final_iteration
phases.phase_5.loop_state.state = "VERIFY_FINAL"
phases.phase_5.loop_state.iteration_history[-1].final_status = "PASS" | "WARN" | "FAIL"
phases.phase_5.override_granted = true/false
phases.phase_5.override_reason = "..." (neu granted)
progress_pct = 90
next_action = "phase_6_report"
```

### Phase 6 POST-GATE
```
phases.phase_6.status = "completed"
phases.phase_6.completed_at = NOW
status = "completed"
progress_pct = 100
timestamps.completed_at = NOW
timestamps.last_updated = NOW
active_skill = "wf-fix-bugs"
next_action = "done"

# BAT BUOC: summary_counts phai chinh xac (POST-GATE T7 — anti-fantasy reporting)
# Tat ca cac issue PHAI duoc account-for trong dung 1 bucket:
#   total_issues = fixed + escalated + skipped + verified_failures
#   (KHONG co bucket "deferred"/"backlog"/"if budget" — invented terms cam dung — xem wf-fix-triage Anti-Invention Rule)
summary_counts.total_issues = jq '.issues | length' issue-registry.json
summary_counts.issues_fixed = jq '[.issues[] | select(.status == "fixed")] | length' issue-registry.json
summary_counts.issues_escalated = jq '[.issues[] | select(.status == "escalated" or .fixability == "MANUAL_FIX" or .fixability == "ESCALATE")] | length' issue-registry.json
summary_counts.issues_skipped = jq '[.issues[] | select(.status == "skipped" or .fixability == "SKIP")] | length' issue-registry.json
summary_counts.issues_remaining = (total_issues - issues_fixed - issues_escalated - issues_skipped)
# Validation: issues_remaining MUST = 0 cho fresh run pass; >0 → re-run hoac CDG
```

---

## Fix-Log Schema Enforcement (BAT BUOC)

`$SESSION_DIR/fix-log.json` PHAI dung schema `fix-log-v1`:

```json
{
  "$schema": "fix-log-v1",
  "fix_id": "FIX-YYYYMMDD-NNN",
  "entries": [
    {
      "issue_id": "ISSUE-001",
      "batch": 1,
      "iteration": 0,
      "agent": "developer",
      "source": "static-scan|runtime|llm-scan",
      "files_modified": [...],
      "files_created": [...],
      "change_type": "bug_fix",
      "behavior_changed": false,
      "api_contract_changed": false,
      "route_map": [...],
      "summary": "...",
      "timestamp": "YYYY-MM-DDTHH:mm:ssZ"
    }
  ]
}
```

**Lifecycle rules (BAT BUOC):**

1. **Triage init** (Step 2.3c): tao file voi `entries: []` (rong) tu template `wf-fix-bugs/templates/phase5-triage/fix-log.json` (canonical schema fix-log-v2 sau Sprint 3 XF-03). KHONG dung `fixes[]`, KHONG dung `status: pending`.
2. **Phase 3 batches**: APPEND entry MOI khi fix HOAN THANH. Entry PHAI co `file_changed` non-empty (theo v2 schema; tru truong hop verify-only thi notes giai thich).
3. **Phase 6 POST-GATE T8** (BAT BUOC verify):
   ```bash
   # Schema check
   jq -e '."$schema" == "fix-log-v2"' $SESSION_DIR/fix-log.json
   # Phai dung "entries", KHONG dung "fixes"
   jq -e 'has("entries") and (has("fixes") | not)' $SESSION_DIR/fix-log.json
   # Khong duoc co status:pending — entry chi APPEND khi fix done
   PENDING_COUNT=$(jq '[.entries[] | select(.status // "" == "pending")] | length' $SESSION_DIR/fix-log.json)
   test "$PENDING_COUNT" = "0" || { echo "T8 FAIL: fix-log.json co entry voi status=pending — vi pham lifecycle (chi APPEND khi DONE)" >&2; exit 1; }
   # Count match: entries phai >= so issues fixed (cho phep CI_TOOL_USED entries them)
   ENTRIES_COUNT=$(jq '[.entries[] | select(has("issue_id"))] | length' $SESSION_DIR/fix-log.json)
   FIXED_COUNT=$(jq '[.issues[] | select(.status == "fixed")] | length' $SESSION_DIR/issue-registry.json)
   test "$ENTRIES_COUNT" -ge "$FIXED_COUNT" || { echo "T8 FAIL: entries=$ENTRIES_COUNT < fixed=$FIXED_COUNT" >&2; exit 1; }
   ```
4. Vi pham → POST-GATE FAIL E_FIXLOG_SCHEMA, retry x3, escalate.

---

## Pre-Batch Resume Filter (P3 — step-level resume)

> **Muc dich:** Khi Phase 6 bi interrupt giua chung (vd context >90% E009, manual cancel, OOM) va user chay `/wf-fix-bugs --resume`, batch khong duoc fix lai issues da hoan thanh tu lan chay truoc.
>
> **Cross-skill contract:** Lay `fix-log.json.entries[].issue_id` lam SSOT cho "da fix thanh cong" — moi entry duoc APPEND chi khi fix HOAN THANH (theo Lifecycle Rule §2 cua "Fix-Log Schema Enforcement"). Khong dua vao issue-registry.json (co the bi update truoc fix-log append → race window).

### Filter Algorithm (chay TRUOC Step 3.X.1 cua moi batch)

```bash
# Input: $BATCH_NUM (1|2|3), $BATCH_ISSUES (array issue_id du dinh fix trong batch)
# Output: $PENDING_ISSUES (array issue_id can fix), $SKIPPED_COUNT

FIX_LOG="$SESSION_DIR/fix-log.json"

# Truong hop fresh run (fix-log chua ton tai hoac empty entries)
if [ ! -f "$FIX_LOG" ] || ! jq -e '.entries | length > 0' "$FIX_LOG" >/dev/null 2>&1; then
  PENDING_ISSUES="${BATCH_ISSUES[@]}"
  SKIPPED_COUNT=0
else
  # Build set: issues da fix thanh cong trong batch nay (theo issue_id + batch field)
  ALREADY_FIXED=$(jq -r --argjson bn "$BATCH_NUM" '
    [.entries[]
      | select((.batch // 0) == $bn)
      | select(.issue_id | length > 0)
      | select((.files_modified // [] | length > 0)
            or (.files_created // [] | length > 0))
      | .issue_id
    ] | unique | .[]
  ' "$FIX_LOG" 2>/dev/null)

  # Filter batch issues — keep only those NOT in ALREADY_FIXED
  PENDING_ISSUES=()
  SKIPPED_COUNT=0
  for iss in "${BATCH_ISSUES[@]}"; do
    if echo "$ALREADY_FIXED" | grep -qFx "$iss"; then
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
      PENDING_ISSUES+=("$iss")
    fi
  done
fi

# Logging cho transparency
if [ "$SKIPPED_COUNT" -gt 0 ]; then
  echo "INFO: Pre-Batch Resume Filter — skipping $SKIPPED_COUNT issue(s) da fix thanh cong tu lan chay truoc"
fi

# Empty queue → skip ca batch
if [ "${#PENDING_ISSUES[@]}" -eq 0 ]; then
  echo "INFO: Batch $BATCH_NUM all issues already fixed — SKIP batch (treat as completed)"
  # UPDATE fix-status.json batch_$BATCH_NUM.status = "completed" voi metadata "resumed=true"
  # KHONG spawn developer agent
  # Return ngay
  return 0  # hoac equivalent flow control
fi
```

### Integration Points

| Step | Action |
|------|--------|
| Step 3.1.0 (NEW) | Phase 3 Batch 1 — chay Pre-Batch Resume Filter voi `$BATCH_NUM=1`. PENDING_ISSUES truyen vao Agent Context Template thay vi BATCH_ISSUES nguyen ban. |
| Step 3.2.0 (NEW) | Phase 3 Batch 2 — chay Pre-Batch Resume Filter voi `$BATCH_NUM=2`. |
| Step 3.3.0 (NEW) | Phase 3 Batch 3 — chay Pre-Batch Resume Filter voi `$BATCH_NUM=3`. |

### Edge Cases

| Case | Handling |
|------|----------|
| Fix-log empty | PENDING_ISSUES = BATCH_ISSUES, behavior = fresh run |
| All batch issues already fixed | Skip batch entirely, mark `completed` voi `metadata.resumed=true` |
| Partial batch (1/5 fixed) | Spawn agent voi 4 pending issues, log "skipped 1 resumed" |
| Entry exists nhung files_modified rong | KHONG count la "fixed" — safety filter trong jq (line `select((.files_modified // [] | length > 0) or ...)`) |
| Entry bi corrupt (jq parse fail) | Treat as empty fix-log → fresh run (safe default) |

### Atomicity Guarantee

Fix-log entries duoc APPEND voi Atomic Write Pattern (jq → tmp → validate → mv). Mat dien giua APPEND/mv → entry KHONG persist → resume se re-fix issue do (idempotent neu fix la null-check/typo, co the re-modify file neu fix la code-gen — agent phai detect "code da fix" va no-op).

**Best practice cho agent:** Truoc khi fix, READ current file content. Neu fix da co (vd null check da ton tai) → emit fix-log entry voi `files_modified=[]` + `summary="already_fixed_by_prior_run"`. Filter algorithm vi the SKIP entry nay (do guard `files_modified > 0`), va lan resume tiep theo se re-check.

---

## Escalations Artifact (BAT BUOC khi co MANUAL_FIX/ESCALATE)

`$SESSION_DIR/escalations.json` schema `escalations-v1` — duoc tao boi wf-fix-triage POST-GATE step 3 (xem wf-fix-triage SKILL.md POST-GATE).

wf-fix-execute KHONG modify file nay. Phase 6 fix-report.md PHAI tham chieu file nay neu ton tai:

```bash
if [ -s "$SESSION_DIR/escalations.json" ]; then
  ESCALATIONS_COUNT=$(jq '.items | length' "$SESSION_DIR/escalations.json")
  # Render section "## Escalations Required Stakeholder Review" trong fix-report.md
  # Liet ke tung item: issue_id, severity, file, stakeholder_hint, suggested_skill
fi
```

**Phase 6 phase-summary.md "Can luu y" section PHAI bao gom:**

- "[N] escalations can [stakeholder list] review — xem `escalations.json`"

---

## Developer Selection Protocol

```
Kiem tra file extensions trong $TARGET_DIRS de chon developer agent phu hop:

IF files co .tsx, .jsx, .vue, .svelte, .css, .scss:
  → Spawn `frontend-developer` agent
ELIF files co .swift, .kt, .dart, .xcodeproj, android/:
  → Spawn `mobile-developer` agent
ELSE:
  → Spawn `developer` agent (default — backend, fullstack, scripts)

Monorepo → spawn developer phu hop THEO FILE bi loi, khong phai project type chung.

// Runtime issues (khong co file path) → route theo issue type
IF issue.source == "runtime":
  IF issue.type IN ["button_non_functional", "ui_element_missing", "form_validation_error"]:
    → `frontend-developer`
  ELIF issue.type IN ["console_error", "network_error", "runtime_exception"]:
    → `developer`
  ELSE: → `developer`

// Gap issues (Layer 4) → route theo issue type
IF issue.source == "gap":
  IF issue.type IN ["infrastructure_error", "database_connection_error"]:
    → ESCALATE (can DevOps/DBA)
  ELIF issue.type IN ["import_picker_missing", "loading_state_missing", "error_handling_missing",
                      "cross_page_state_loss", "data_stale", "missing_ui"]:
    → `frontend-developer`
  ELIF issue.type IN ["feature_not_implemented", "feature_missing_backend", "api_404_error",
                      "api_500_error", "api_format_mismatch", "data_integrity_error",
                      "cascade_side_effect", "export_endpoint_missing", "export_error",
                      "export_response_invalid", "frontend_api_call_unmatched"]:
    → `developer`
  ELIF issue.type IN ["orphan_feature", "orphan_api"]:
    → ESCALATE (business/architectural decision)
  ELSE: → `developer`
```

---

## Domain Expert Routing

```
Xac dinh domain cua module bi loi:
1. Registry: module_id → module name/description
2. Keyword matching trong file path + code content:

DOMAIN_MAP = {
  "finance":     ["invoice", "payment", "ledger", "accounting", "tax", "GL", "AR", "AP"],
  "procurement": ["PO", "vendor", "supplier", "sourcing", "RFQ"],
  "sales":       ["order", "quotation", "pipeline", "commission", "CRM", "deal"],
  "hr":          ["employee", "payroll", "leave", "attendance", "recruitment"],
  "ecommerce":   ["cart", "checkout", "product", "catalog", "storefront"],
  "operations":  ["inventory", "warehouse", "stock", "FIFO", "shipping"],
  "compliance":  ["audit", "GDPR", "AML", "regulatory", "license"],
  "healthcare":  ["patient", "EMR", "prescription", "appointment", "diagnosis"]
}

FOR each issue IN $DISCOVERED_ISSUES:
  module_id = resolve_module_from_file(issue.file_path, registry)
  keywords = extract_keywords(issue.file_path, issue.code_context)
  issue.$ISSUE_DOMAIN = match_domain(keywords, DOMAIN_MAP)  // null neu khong match

Usage (Phase 3 Batch 2):
  Neu batch co issues voi $ISSUE_DOMAIN != null:
    → Spawn domain expert THEM vao developer + security (PARALLEL)
    → Max 1 domain expert per batch (chon domain xuat hien nhieu nhat)
    → Domain expert chi REVIEW (khong fix code) — output la validation comments
```

---

## Agent Context Template

Template chung spawn agent trong Phase 3:

```
Ban la [AGENT_ROLE]. Sua loi trong project [PROJECT_NAME].
Context: Preflight report + bug triage
Architecture: [NEU $ARCH_DIGEST != null → inject digest. NEU null → "Doc Phase 3 docs khi can."]
Infrastructure: [NEU $INFRA_STATUS != null → inject "Frontend: [s], Backend: [s], DB: [s], CORS: [s]"]
Known API Endpoints: [NEU $KNOWN_API_ENDPOINTS != null → inject max 20: method + path + handler]
Batch: [N] — [CRITICAL/HIGH/MEDIUM]
Scope: [SCOPE_TYPE] = [SCOPE_NAME] (directories: [TARGET_DIRS])
Session dir: $SESSION_DIR
Evidence dir: $SESSION_DIR/evidence/

Danh sach loi can fix:
[LIST_FROM_TRIAGE]
  ↳ Day la `$PENDING_ISSUES` da duoc Pre-Batch Resume Filter loc (xem [Pre-Batch Resume Filter](#pre-batch-resume-filter-p3--step-level-resume)).
    Issues da fix thanh cong tu lan chay truoc da bi skip — KHONG can re-fix.
    Neu phat hien file da co fix can lam (vd null-check da ton tai) → emit fix-log entry voi
    `files_modified=[]` + `summary="already_fixed_by_prior_run"` thay vi re-apply.

Quy tac:
1. Fix DUNG loi duoc chi dinh — KHONG refactor code khac
2. Giu nguyen REQ-ID comments da co
3. Them REQ-ID comment neu tao file moi
4. Chay tests sau moi fix de verify
5. Log moi thay doi: file, dong, truoc/sau
6. CHI FIX files trong [TARGET_DIRS] — KHONG modify files ngoai scope
7. Neu can thay doi shared code (packages/, libs/) → ESCALATE, KHONG tu fix
8. Neu 1 batch co > 15 issues → chia sub-batches 10 issues/sub-batch
9. **SYMBOLIC EDITING (BAT BUOC khi $SERENA_AVAILABLE=true):** Khi sua function/method/class body
   → DUNG `mcp__serena__replace_symbol_body` thay vi Edit line-based.
   Khi them code truoc/sau symbol → DUNG `mcp__serena__insert_before_symbol` / `insert_after_symbol`.
   Khi rename symbol → DUNG `mcp__plugin_gitnexus_gitnexus__rename` (graph-aware) thay vi find/replace.
   Xem [Symbolic Editing Preference](#symbolic-editing-preference) cho chi tiet + ly do.

Output: Fixed files + log thay doi. Target ~500-1000 tu per fix (change + rationale).
```

---

## Symbolic Editing Preference

> **Muc dich:** Khi CI tools (Serena/GitNexus) co san, agents PHAI uu tien symbolic-edit thay vi line-based Edit.
> Ly do (CLAUDE.md mandate): symbolic-edit chinh xac hon, robust truoc reformat, an toan voi rename, va duy tri call graph integrity.
> **Graceful:** Serena/GitNexus absent → fallback Edit line-based (zero regression).

### Quy tac uu tien (per task type)

| Task | Tool BAT BUOC khi available | Fallback |
|------|----------------------------|----------|
| Sua TOAN BO body cua function/method/class | `mcp__serena__replace_symbol_body({name_path, relative_path, body})` | Edit (line-based) |
| Sua VAI DONG trong 1 symbol lon | `mcp__serena__replace_content({relative_path, needle, repl, mode})` | Edit |
| Them code TRUOC symbol (decorator, import, comment block) | `mcp__serena__insert_before_symbol({name_path, relative_path, body})` | Edit |
| Them code SAU symbol (helper function, export) | `mcp__serena__insert_after_symbol({name_path, relative_path, body})` | Edit |
| Rename symbol (function, class, variable) cross-file | `mcp__plugin_gitnexus_gitnexus__rename({old_name, new_name})` (graph-aware) HOAC `mcp__serena__rename_symbol` | Manual find/replace (KHONG khuyen) |
| Xoa symbol (an toan check refs) | `mcp__serena__safe_delete_symbol({name_path_pattern, relative_path})` | Manual |
| Tao file moi | `Write` (built-in) | — |

### Khi fallback Edit chap nhan

- CI tools absent (`$SERENA_AVAILABLE=false` AND `$GITNEXUS_AVAILABLE=false`)
- File khong phai code (config, JSON, Markdown, YAML)
- Sua text trong comment/docstring khong lien quan structure
- Symbol khong duoc LSP nhan dien (helper inline, dynamic dispatch)

### Logging (gan vao fix-log.json)

```json
{
  "issue_id": "ISSUE-NNN",
  "edit_method": "symbolic" | "line_based" | "mixed",
  "ci_tools_used": ["serena_replace_symbol_body", "gitnexus_rename"],
  "fallback_reason": null | "ci_unavailable" | "non_code_file" | "lsp_unrecognized"
}
```

### Vi pham (anti-pattern)

- KHONG dung Edit de rename symbol cross-file → SE BREAK call graph, miss reference
- KHONG dung Edit cho function body lon (>30 dong) khi Serena available → fragile truoc reformat
- KHONG mix Edit + Serena trong cung 1 symbol → conflict state

---

## Agent Output Spot-Check Protocol

> Protocol 17 / CORE-029. Kiem tra agent output tuan thu schema TRUOC khi ghi vao fix-log.json / issue-registry.json.
> Ap dung: MOI agent spawn trong Phase 3 (Batch 1, 2, 3) va Phase 5 VERIFY_FIX.

### Quy trinh spot-check (sau khi agent return)

```
FOR each agent_output trong batch:
  1. SCHEMA CHECK (CACHED — pattern-aware):
     - Cache key = (agent_type, signal_type, severity) — pattern recognition LRU max 50.
     - IF SpotCheckCache.pattern_seen(agent_type, signal_type, severity) → SKIP full schema
       validation, REUSE cached result (entry.result). Log fix-log entry voi
       {event: "SCHEMA_CHECK", source: "cache_hit"}.
     - ELSE: run full schema check, sau do SpotCheckCache.remember(...) result.
       Log {event: "SCHEMA_CHECK", source: "cache_miss"}.
     - Cac field kiem tra (khi miss):
        · agent_output.files_modified la array non-empty? (neu fix expected to touch files)
        · agent_output.fix_summary la string non-null?
        · agent_output.issue_id khop voi issue trong issue-registry.json?

  2. FILE EXISTENCE CHECK (LUON CHAY — never cached):
     - FOR each file trong files_modified: test -f "$file" → PASS
     - Neu file khong ton tai → ERROR

  3. SCOPE CHECK (LUON CHAY — never cached, reuse Scope Boundary Rule):
     - FOR each file trong files_modified: file phai thuoc $TARGET_DIRS
     - Neu out-of-scope → ERROR + ROLLBACK

  4. CONTENT SANITY CHECK (LUON CHAY — never cached, agent-specific output):
     - Neu agent claim "behavior_changed=true" → tim "Bug Fix Notes" section trong feature spec
     - Neu agent claim "api_contract_changed=true" → verify endpoint path trong code

  5. RESULT:
     - PASS → proceed to APPEND vao fix-log.json + UPDATE issue-registry.json
       (chi PASS khi CA 4 tier deu PASS — cache hit khong by-pass tier 2/3/4)
     - ERROR → trigger auto-fix (re-spawn agent voi context error) hoac escalate
```

### Cache integration (W3.3)

- **Module:** `.claude/skills/workflow/_shared/spot_check_cache.py` — class `SpotCheckCache`.
- **Lifetime:** In-memory per-session. KHONG persist cross-session (skill restart → fresh cache).
- **Eviction:** LRU max 50 entries, key = `(agent_type, signal_type, severity)` (lower/upper-cased).
- **Escape hatch:** Set env `MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1` → moi schema check chay fresh
  (bypass cache hoan toan). Dung khi nghi cache co stale validation logic.
- **Guard rail enforce:** Cache CHI SKIP tier 1 (schema pattern). Tier 2/3/4 LUON CHAY fresh —
  vi pham (skip tier 2/3/4) la VI PHAM Protocol 17 CORE-029, BLOCK execute.
- **Auto-fix trigger:** ERROR case (re-spawn agent) van enforce nguyen ven — cache hit
  KHONG suppress retry budget (max 3 retries/agent).

### Auto-fix trigger (ERROR case)

```
IF spot_check_errors.length > 0 AND retry_count < 3:
  retry_count += 1
  Re-spawn agent voi context: "Previous output failed spot-check: [errors]. Fix + retry."
  Wait agent complete → spot-check lai
ELSE IF retry_count >= 3:
  LOG E005 (regression) hoac E006 (schema fail)
  Mark issue status = "escalated"
  Continue voi issues khac
```

### Mapping voi phases

| Phase | Spot-check trigger point |
|-------|--------------------------|
| 3 Batch 1 | Sau Step 3.1.2 (agent fix complete), TRUOC Step 3.1.4 (update data) |
| 3 Batch 2 | Sau Step 3.2.3 (wait ALL agents), TRUOC Step 3.2.4 |
| 3 Batch 3 | Sau Step 3.3.0a (wait AGENT_FIX agents), TRUOC Step 3.3.4 |
| 5 VERIFY_FIX | Sau partial Phase 3 spawn, TRUOC UPDATE issue-registry.json |

---

## Scope Boundary Rule

Developer agent KHONG DUOC modify files ngoai `$TARGET_DIRS`.

Neu bug trong scoped system co root cause o shared code (`packages/`, `libs/`, `shared/`):
- Agent PHAI ESCALATE voi context
- KHONG tu dong fix shared code trong scoped mode
- Phase 3 POST-GATE verify ALL modified files thuoc `$TARGET_DIRS` → ROLLBACK + WARNING neu vi pham

---

## Registry Safe-Write

**Fields duoc phep update:** `impl_status` (per REQ-ID, Phase 4a only)

**Rules:**
- KHONG downgrade tu "done" → gia tri khac
- KHONG them/xoa requirements, features, systems, modules
- Doc registry NGAY TRUOC KHI GHI → ghi atomic → validate `jq '.' req-registry.json`
- Single write cho toan bo JSON

**Rollback:** Neu fix gay regression → revert `impl_status` ve gia tri truoc fix.

---

## Context Digest Generation

**Muc dich:** Khi resume, agent biet NGAY context debug session truoc — root causes, fix patterns, gotchas — khong can re-analyze code da fix.

SAU MOI BATCH CHECKPOINT, MERGE `context_digest` vao `checkpoint.json` (ADDITIVE — KHONG ghi de batch truoc):

| Field | Noi dung |
|-------|---------|
| `fix_session_summary` | Tom tat: loi gi, fix the nao, con gi chua fix (100-200 tu) |
| `root_causes_identified` | Array string: VD "Missing null check in auth middleware" |
| `fix_patterns_applied` | Array string: VD "Error handling: them try-catch cho tat ca services" |
| `domain_context` | `{ primary_domain, business_rules_discovered[] }` |
| `code_patterns_observed` | `{ error_handling, naming_convention, test_framework }` |
| `cross_batch_state` | `{ batch_N_fixes[], batch_N_plus_1_impacts[] }` |
| `gotchas_and_warnings` | Array string: VD "Circular import auth↔user — can refactor" |

**Quy tac:** Chi luu QUYET DINH va PATTERN — khong luu full code diffs. Backward compatible: checkpoint cu khong co context_digest → skip khi resume.

---

## CORE-027 Critical Decision Gate

Cac hanh dong KHONG UNDO can user confirmation truoc khi thuc thi.
Map voi Protocol 16 `.claude/skills/protocols/16-critical-decision-gate.md` §16.1.

| CDG Point | Protocol 16 ID | Phase | Hanh dong | Rejection behavior |
|-----------|----------------|-------|-----------|---------------------|
| CDG-EXEC-01 | CDG-02 (overwrite) | 4a | Update existing feature spec `phase2-features/[sys]/[mod]/[feat].md` khi behavior doi | SKIP update file do, tiep tuc Phase 4a voi features khac |
| CDG-EXEC-02 | CDG-03 (impl_status) | 5.20 (rollback) | Downgrade `impl_status` tu "done" khi fix gay regression + phai rollback | GIU NGUYEN impl_status cu + LOG warning "regression da detect nhung user tu choi downgrade" |
| CDG-EXEC-03 | — (skill-specific) | 4b | Tao stub docs cho orphan UI (phase2-features, phase4-ux, flow) — **decision fatigue mitigation:** hoi batch accept 1 lan cho toan bo N stubs | SKIP Phase 4b, ghi orphan issues vao Phase 6 report |
| CDG-EXEC-04 | — (skill-specific) | 5.16 | Grant override iteration 4 khi HIGH issues remain sau iter 3 | Decline → VERIFY_FINAL status=WARN |

**Prompt format (tuan thu Protocol 16 §16.4 templates):**
```
[Icon ⚠️] [Mo ta hanh dong bang tieng Viet — khong dung thuat ngu ky thuat]
[Du lieu bi anh huong: ten file / REQ-ID / module name]
[Hau qua neu thuc hien]
[IF CDG-EXEC-01 (overwrite): hien thi tom tat before/after diff]

Confirm? (yes/no[/review])
  - "yes": Thuc hien
  - "no": Apply rejection behavior tuong ung (xem bang tren)
  - "review" (neu ap dung, VD CDG-EXEC-03 batch): hien thi chi tiet tung item → user tick chon
```

**Quy tac cua Protocol 16 (ap dung luon):**
- CDG confirmation KHONG dem vao iteration count cua Auto-Correction Loop
- KHONG hoi lai cung 1 CDG cho cung du lieu trong cung session
- CDG-EXEC-03: Batch accept "Dong y tat ca" → apply cho moi stub con lai trong Phase 4b
- CDG-EXEC-01: Batch accept per-phase — Phase 4a co nhieu file update → hoi 1 lan voi list day du
- Log moi CDG rejection vao session-log.json (event: CDG_REJECTED)

---

## Execution Trace Protocol

> Protocol 15 / CORE-026. Output-only observability — KHONG dung lam input cho skill khac.

**File:** `.mc-data/work/_trace/session-log.json`
**Template:** `.claude/doc-framework/_meta/session-log.template.json`

### Khi nao ghi (3 events)

| Event | Thoi diem | Noi dung |
|-------|-----------|----------|
| START | Sau PRE-GATE pass (truoc Phase 3 BAT DAU) | `{ skill: "wf-fix-execute", phase: "phase_3", timestamp, run_sequence }` |
| COMPLETE | Sau POST-GATE Phase 6 pass (cuoi skill) | `{ skill: "wf-fix-execute", phase: "phase_6", timestamp, agents_invoked[], files_created[], files_modified[], warnings[], decisions[] }` |
| FAIL | POST-GATE fail sau 3 iterations tai bat ky phase (Phase 3-6) | `{ skill: "wf-fix-execute", phase: [dung o phase nao], timestamp, errors[], details }` |

### Append pattern (atomic jq)

```
# READ + APPEND + WRITE atomic:
LOG_FILE=".mc-data/work/_trace/session-log.json"
[ ! -f "$LOG_FILE" ] && cp .claude/doc-framework/_meta/session-log.template.json "$LOG_FILE"

tmp=$(mktemp)
jq --arg skill "wf-fix-execute" \
   --arg phase "phase_3" \
   --arg event "START" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.entries += [{skill: $skill, phase: $phase, event: $event, timestamp: $ts}]' \
   "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
```

### Quy tac (BAT BUOC)

1. **APPEND-ONLY** — KHONG overwrite entries cu
2. **Best-effort** — fail khong block skill (wrap trong `|| true`)
3. **run_sequence** = max(existing entries WHERE skill==wf-fix-execute) + 1
4. **KHONG Read toan bo file** — chi append
5. **Rotation**: khi entries > 200 → archive vao `session-log.archive.json` (best-effort)

### Trigger points trong flow

- PRE-GATE Step 6 (sau mode routing) → WRITE START
- Phase 6 POST-GATE (sau update fix-status) → WRITE COMPLETE
- Bat ky phase FAIL sau 3 retries → WRITE FAIL + stop

---

## Error Codes

| Code | Tinh huong | Xu ly |
|------|------------|-------|
| E005 | Developer agent fix gay loi moi (regression) | Rollback fix → escalate voi context |
| E006 | Tests fail sau fix | Retry fix (max 3 lan), neu van fail → escalate |
| E007 | Feature spec khong tim thay cho behavior change | Log WARNING, tiep tuc |
| E008 | Registry JSON invalid sau update | Retry x3, rollback neu van fail |
| E013 | Playwright navigate that bai | LOG warning, skip gracefully |
| E017 | Auth required khi playwright verify | Apply 4-giai-doan auto-login |
| E039 | CRITICAL issues remain sau iter 3 (hoac 4 neu override) | LOG error, mark status=FAIL, KHONG CDG extend, section "Unfixed Critical Issues" trong fix-report |
| E040 | Loop fix gay regression moi | LOG warning, them vao issue-registry.json. Max 5 regressions → ESCALATE |
| E041 | CQG numeric metrics mismatch trong fix-report.md sau 3 retries | LOG WARNING, flag section "Validation Notes" trong report cho user review, khong block skill |
| E027 | Workload Missing — khong tim thay fix-workload.json sau 3 retries | Ghi process violation, dung auto-generated workload, CDG render |
| E028 | Step Verification Fail — execute step chua hoan thanh sau 3 retries | CDG render: skip/abort/manual-fix |
| E029 | Process Violation critical — Phase 1 scan khong day du | CDG render: tiep tuc execute hay re-run Phase 1 |
| E044 | QD11 Fix Attempt — attempt fix QD11 enhancement signal | Block fix, set fixability="escalate", log violation |
| E045 | LLM Fix Without Verification — LLM-scan signal fixed without evidence re-verify | Block fix, require evidence re-verification truoc khi proceed |

---

## Checkpoint Protocol

**CHECKPOINT sau moi batch + moi iteration:**

1. UPDATE `$SESSION_DIR/checkpoint.json`:
   - `last_completed_phase` / `last_completed_batch`
   - `next_phase` / `next_batch`
   - `context_digest` (ADDITIVE merge)
   - `verify_loop_state.state` / `verify_loop_state.override_granted` / `verify_loop_state.iteration_history`
   > **v7.0 BREAKING (S2):** KHONG ghi `verify_loop_state.current_iteration` vao checkpoint.
   > Iteration counter SSOT duy nhat la `fix-status.json.phases.phase_5.loop_state.current_iteration`
   > (set boi VERIFY_INIT). Checkpoint chi giu state/override/history lam cache cho UX.
2. UPDATE `$SESSION_DIR/fix-status.json` theo contract tuong ung (xem §fix-status.json Update Contract — Phase 5)
3. **(v7.0 S6) UPDATE `last_checkpoint` field per-phase** — Section "Per-Batch Checkpoint (S6)" ben duoi
4. Neu context > 80% → save checkpoint, thong bao user dung `--resume`

**LPM + scope=all:** Khi `$LARGE_PROJECT = True` VA `--scope=all`, them checkpoint sau moi system (group issues by system → fix per system → checkpoint).

**Resume logic (v7.0 — single SSOT):**
- **Iteration counter:** `fix-status.json.phases.phase_5.loop_state.current_iteration` (SSOT duy nhat).
  Neu khong co (vd new session) → mac dinh 0 → VERIFY_INIT se tang len 1 trong iteration ke tiep.
- **State machine position:** `fix-status.json.phases.phase_5.loop_state.state`.
  Fallback: `checkpoint.json.verify_loop_state.state`. Neu ca 2 deu thieu → `VERIFY_INIT`.
- **Override grant:** `fix-status.json.phases.phase_5.override_granted` (boolean, default false).
- **KHONG dung MAX() cross-file** — checkpoint da bo field `current_iteration` (v7.0 BREAKING).
  Backward compat: neu doc legacy checkpoint co field nay → IGNORE, log debug "deprecated field".

---

### Per-Batch Checkpoint (S6 v7.0)

**Muc dich:** Khi `EXECUTION_MODE=agent_dispatch` (xem `wf-fix-bugs/procedures/agent-dispatch.md`),
sub-skills co the bi cut bat ky thoi diem. Per-batch checkpoint cho phep resume mid-phase
khong can redo nhung gi da xong.

> **Inline mode:** field `last_checkpoint` VAN duoc ghi (tot cho UX/`--status`) nhung khong critical
> bang agent_dispatch — orchestrator co the resume tu fix-status.json full state.

#### Schema `last_checkpoint` (extend SSOT da co tu S2)

```json
{
  "phases": {
    "phase_3": {
      "loop_state": {
        "last_checkpoint": {
          "batch_id": "batch_2",
          "sub_batch_index": 3,
          "timestamp": "2026-04-28T10:30:00Z",
          "issues_processed": 42,
          "next_action": "phase_3_batch_2_sub_4"
        }
      }
    },
    "phase_5": {
      "loop_state": {
        "current_iteration": 2,
        "state": "VERIFY_FIX",
        "last_checkpoint": {
          "iteration": 2,
          "phase": "VERIFY_FIX",
          "timestamp": "2026-04-28T10:35:00Z",
          "issues_in_iteration": 5,
          "next_action": "phase_5_verify_iter_2_continue"
        }
      }
    }
  }
}
```

#### Trigger points

| Phase | Trigger | Field set |
|-------|---------|-----------|
| Phase 3 Batch 1 (CRITICAL) | Sau moi sub-batch (10 issues) | `phase_3.loop_state.last_checkpoint = {batch_id: "batch_1", sub_batch_index: N, timestamp, issues_processed, next_action}` |
| Phase 3 Batch 2 (HIGH) | Sau moi sub-batch (10 issues) | `phase_3.loop_state.last_checkpoint = {batch_id: "batch_2", ...}` |
| Phase 3 Batch 3 (MED+LOW) | Sau moi sub-batch (10 issues) | `phase_3.loop_state.last_checkpoint = {batch_id: "batch_3", ...}` |
| Phase 5 Verify Loop | Sau moi state transition (VERIFY_FIX/VERIFY_DOCS/VERIFY_RESCAN/EVALUATE) | `phase_5.loop_state.last_checkpoint = {iteration, phase, timestamp, issues_in_iteration, next_action}` |

#### Bash atomic write pattern

```bash
# Sau khi sub-batch hoan thanh (Phase 3):
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg batch "batch_2" \
   --argjson sub 3 \
   --arg ts "$TS" \
   --argjson processed 42 \
   --arg next "phase_3_batch_2_sub_4" \
   '.phases.phase_3.loop_state.last_checkpoint = {
      batch_id: $batch,
      sub_batch_index: $sub,
      timestamp: $ts,
      issues_processed: $processed,
      next_action: $next
   }' "$SESSION_DIR/fix-status.json" > "$SESSION_DIR/.fix-status.tmp.$$" \
  && mv "$SESSION_DIR/.fix-status.tmp.$$" "$SESSION_DIR/fix-status.json"

# Tuong tu cho Phase 5 sau moi state transition:
jq --argjson iter 2 \
   --arg state "VERIFY_FIX" \
   --arg ts "$TS" \
   --argjson issues 5 \
   --arg next "phase_5_verify_iter_2_continue" \
   '.phases.phase_5.loop_state.last_checkpoint = {
      iteration: $iter,
      phase: $state,
      timestamp: $ts,
      issues_in_iteration: $issues,
      next_action: $next
   }' "$SESSION_DIR/fix-status.json" > "$SESSION_DIR/.fix-status.tmp.$$" \
  && mv "$SESSION_DIR/.fix-status.tmp.$$" "$SESSION_DIR/fix-status.json"
```

#### Resume mid-phase logic

```bash
# Trong PRE-GATE Phase 3 / Phase 5 (sau khi --resume detect session):
LAST_CKPT_P3=$(jq -c '.phases.phase_3.loop_state.last_checkpoint // null' \
               "$SESSION_DIR/fix-status.json")
LAST_CKPT_P5=$(jq -c '.phases.phase_5.loop_state.last_checkpoint // null' \
               "$SESSION_DIR/fix-status.json")

# Phase 3 resume:
if [ "$LAST_CKPT_P3" != "null" ]; then
  RESUME_BATCH=$(echo "$LAST_CKPT_P3" | jq -r '.batch_id')
  RESUME_SUB=$(echo "$LAST_CKPT_P3" | jq -r '.sub_batch_index')
  echo "Resume Phase 3 from $RESUME_BATCH sub-batch $RESUME_SUB"
  # Skip sub-batches 0..RESUME_SUB-1, start tu RESUME_SUB
fi

# Phase 5 resume:
if [ "$LAST_CKPT_P5" != "null" ]; then
  RESUME_ITER=$(echo "$LAST_CKPT_P5" | jq -r '.iteration')
  RESUME_STATE=$(echo "$LAST_CKPT_P5" | jq -r '.phase')
  echo "Resume Phase 5 from iteration $RESUME_ITER state $RESUME_STATE"
  # Resume tu state tuong ung trong loop FSM
fi
```

#### Backward compat

- Legacy session khong co `last_checkpoint` field → fallback default state:
  - Phase 3: start tu `batch_1`, `sub_batch_index=0`
  - Phase 5: start tu `current_iteration` SSOT (S2), `state=VERIFY_INIT`
- KHONG break behavior cu cho session inline mode — chi additive field.
- Field nay APPEND vao schema, KHONG modify field hien co.
