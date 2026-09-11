# 07 — Procedures Structure (wf-cmi)

> **Mục đích file:** Outline thư mục `procedures/` của wf-cmi — kiến trúc lazy-load tuân thủ CORE-032.

---

## 1. Layout

```
.claude/skills/workflow/wf-cmi/procedures/
├── _shared.md                              ← Cross-cutting concerns
├── phase1-init.md                          ← Init + CI PRE-GATE 3-step
├── phase2-discovery.md                     ← Build 6 graphs
├── phase3-invariant-registry.md            ← 3-pass LLM inference
├── phase4-coverage-dispatch.md             ← Spawn 10 lanes CD1-CD10
├── phase5-aggregate.md                     ← Signals → coverage matrix
├── phase6-regression.md                    ← Predictive regression map
├── phase7-gap-cdg.md                       ← GAP detection + CDG decisions
├── phase8-report.md                        ← Final report + cross-skill artifact
└── resume-status.md                        ← --resume + --status handlers
```

**Quy tắc:** Mỗi procedure file CHỈ đọc khi tới phase tương ứng. KHÔNG load tất cả ở đầu (CORE-032 lazy-load — giảm 70%+ context).

**SKILL.md (lean routing hub ≤500 dòng):** chứa Phase Routing Map + File Contract + Error Codes quick lookup + Context Budget thresholds — KHÔNG chứa execution logic.

---

## 2. `_shared.md` content

| Section | Mục đích | Reference helper |
|---------|---------|------------------|
| State variables | `$SESSION_DIR`, `$PROFILE`, `$SCOPE`, `$DIMS_ACTIVE`, `$CI_CONTEXT`, `$SINCE_REF`, `$AUTO_SUGGEST`, `$CI_MODE`, `$DRY_RUN` | — |
| Atomic write helpers | `atomic_write_json()`, `atomic_append_jsonl()`, `atomic_write_md()` | `.claude/scripts/wf-cmi/atomic-write.sh` |
| Error handling | `escalate()`, `auto_fix()`, `record_error()`, `cdg_prompt()` | `.claude/scripts/wf-cmi/error-handlers.sh` |
| CI detection | Wrappers cho `ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh` | shared from `.claude/scripts/` |
| Logging | `log_phase_start()`, `log_phase_complete()`, `log_phase_fail()`, `log_phase_skip()`, `log_lane_status()` | `.claude/scripts/wf-cmi/logging.sh` |
| Session lock | `acquire_lock()`, `release_lock()`, `heartbeat_daemon()`, `check_stale_lock()` | `.claude/scripts/wf-cmi/lock-manager.sh` |
| R/W lock (Protocol 22) | `acquire_read_lock()`, `acquire_write_lock()` cho registry, cache | `.claude/scripts/_shared/rw-lock.sh` |
| Context budget | `check_context_budget()`, `force_checkpoint()` | inline (≤30 dòng helper) |
| Graph utilities | `merge_graphs()`, `traverse_graph()`, `compute_centrality()` | `.claude/scripts/wf-cmi/graph-utils.py` (Python) |
| Coverage compute | `compute_coverage_pct()`, `apply_threshold()` | `.claude/scripts/wf-cmi/coverage-compute.py` |
| Author info | `get_git_author()` (email + name từ git config) | inline |

---

## 3. `phase{N}-{name}.md` template (4 sections + 1 report)

### Section A — Header (chuẩn cho mọi phase)

```markdown
# Phase {N}: {Tên phase}

**Đầu vào:** {file/state cần có}
**Đầu ra:** {file/state tạo ra}
**Auto-fix budget:** 3 retries
**Time estimate (standard profile):** {X} min
**Required: ✅/⚪ (skip nếu profile=quick + condition)**
```

### Section B — PRE-GATE (T1→T4 forensic)

```markdown
## PRE-GATE

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | {exists} | `test -f` | E0{N}0 |
| T2 | {structure valid} | `jq -e` | E0{N}1 |
| T3 | {content non-empty} | `jq -e` | E0{N}2 |
| T4 | {cross-ref upstream} | bash composite | E0{N}3 |
```

### Section C — Steps (execution detail)

```markdown
## Steps

| # | Mô tả | Tool | Output |
|---|------|------|--------|
| {N}.1 | Read template `templates/{output}.json` | Read | content |
| {N}.2 | Populate placeholders | Edit | tmp |
| {N}.3 | Strip metadata (_schema_notes) | bash | clean tmp |
| {N}.4 | Validate JSON | jq | pass/fail |
| {N}.5 | Atomic write `mv tmp → target` | bash | output file |

### {N}.1. {Step name}
{detail thực thi — Read template, source path, expected fields}

### {N}.2. {Step name}
{detail populate}
...
```

### Section D — POST-GATE (T1→T4 + auto-fix)

```markdown
## POST-GATE

| Tier | Check | Auto-fix retry (max 3) |
|------|-------|------------------------|
| T1 | {exists} | Re-run step {N}.5 |
| T2 | {structure} | Re-build từ template (re-read + populate) |
| T3 | {content depth} | Re-generate với clarified input |
| T4 | {cross-ref upstream} | Re-read source + re-write target |

Budget hết → ESCALATE format:
"Phase {N} không thể tự fix. Re-run / Skip (risky) / Cancel / Switch profile?"
```

### Section E — Phase Report (CORE-028)

```markdown
## Phase Report Template

(Generate file `$SESSION_DIR/phase{N}-*/Phase{N}-report.md` từ template `templates/Phase{N}-report.md`)

Sample content (tiếng Việt, ≤15 dòng):

## Phase {N}: {Tên} — PASS|FAIL
Thời gian: {ISO 8601}
**Đã làm:** {1-2 câu cho người không chuyên}
**Kết quả:** {Số liệu chính} + {File đầu ra}
**Tiếp theo:** {Phase kế tiếp hoặc hành động user}
```

---

## 4. Per-phase outline

### Phase 1 — Init + CI PRE-GATE (`phase1-init.md`)

| Step | Mô tả |
|------|------|
| 1.1 | Parse + validate args (E010-E016) |
| 1.2 | Author info (git config user.email + user.name) |
| 1.3 | Generate SESSION_ID (`YYYY-MM-DD-{scope}-{slug}-NN`) hoặc resolve từ `--resume`/`--session-id` |
| 1.4 | Create $SESSION_DIR + acquire lock + spawn heartbeat daemon |
| 1.5 | CI PRE-GATE Na — `ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` |
| 1.6 | CI PRE-GATE Nb — `ci-freshness-check.sh` → check 4 levels (ok/light/strong/severe) |
| 1.7 | CI PRE-GATE Nc — `ci-inject-context.sh` → build `$CI_CONTEXT` for agent prompts |
| 1.8 | Build initial `integrity-status.json` từ template (Atomic Write) |
| 1.9 | Append entry vào `_index/sessions.jsonl` |
| 1.10 | Phase Report Phase1-report.md |

### Phase 2 — Discovery (`phase2-discovery.md`)

| Step | Mô tả |
|------|------|
| 2.1 | Load registry + phase docs (read-only) |
| 2.2 | Detect tech stack (CORE-014: code_parse > config > doc_infer) — vd EUREKA .NET 10 + Next.js + PostgreSQL + RabbitMQ + SignalR |
| 2.3 | Build entity-graph (parse Domain/Entities, EF Core configurations qua Serena/Grep) — Atomic Write |
| 2.4 | Build module-graph (parse Eureka.Modules.* dependencies qua project refs) |
| 2.5 | Build workflow-graph (parse Commands/Queries handlers + state transitions) |
| 2.6 | Build api-graph (parse Endpoints/*.cs + group by client routing erp-web/mobile-customer/mobile-staff) |
| 2.7 | Build event-graph (parse Domain Events + RabbitMQ config + SignalR hubs) — SKIP nếu profile=quick |
| 2.8 | Build rbac-matrix (parse Authorization + RBAC permissions + UserSeeder roles) |
| 2.9 | Cross-validate: graphs consistent (module nodes ∈ entity nodes, etc.) |
| 2.10 | Phase Report Phase2-report.md |

### Phase 3 — Invariant Registry (`phase3-invariant-registry.md`)

| Step | Mô tả |
|------|------|
| 3.1 | Load 6 graphs từ Phase 2 |
| 3.2 | Detect domain(s) từ registry `requirements[].department` — EUREKA: logistics + finance + sales + hrm + customer |
| 3.3 | Heuristic invariant extraction (no LLM) — pattern match FK references, FluentValidation rules, Result<T> Error codes |
| 3.4 | **Pass 1 LLM (cross-module pattern)** — spawn architect agent, find pattern A.field → B.field FK missing validation at B (skip nếu profile=quick) |
| 3.5 | **Pass 2 LLM (domain heuristic)** — spawn {domain}-expert agents parallel (max 5 concurrent — leave 5 budget for Phase 4), inject team-expert/{domain}/rules.md |
| 3.6 | **Pass 3 LLM (registry gap)** — business-analyst aggregate Pass 1+2, check against existing phase1-business docs |
| 3.7 | Cross-domain conflict detection — nếu Pass 2 có conflict (vd logistics + finance opinion lệch) → CDG E091 batch |
| 3.8 | Build candidate invariants với confidence scores → `business-invariants.json` template populate |
| 3.9 | (Optional) Detect can produce business-invariants sidecar → mark candidate, defer actual migration to Phase 7 if user accepts |
| 3.10 | Phase Report Phase3-report.md (báo cáo số invariants per domain + conflicts) |

### Phase 4 — Coverage Dispatch (`phase4-coverage-dispatch.md`)

| Step | Mô tả |
|------|------|
| 4.1 | Determine active lanes theo profile (5/7/10 lanes) |
| 4.2 | Prepare lane subdirectories `$SESSION_DIR/phase4-coverage/lanes/CD{N}/` |
| 4.3 | Build agent prompts per-lane từ `agent-prompt.md` template (CORE-037 8-section) |
| 4.4 | Spawn lane agents PARALLEL (max 10 concurrency — CORE-025) — xem [agent-prompt.md](agent-prompt.md) cho prompt 10 lanes |
| 4.5 | Monitor lane progress (timeout 3 min/lane — E041) |
| 4.6 | Aggregate lane outputs: mỗi lane produce `signals.json` + `Phase4-report.md` |
| 4.7 | Per-lane retry x1 nếu fail (CORE-034 budget model) |
| 4.8 | Validate signal schema cross-lane (no fingerprint collision — E049) |
| 4.9 | Update `integrity-status.json.lane_status{}` atomic mỗi lane PASS/FAIL |
| 4.10 | Phase Report Phase4-report.md (báo cáo lane completion + signal count) |

### Phase 5 — Aggregate (`phase5-aggregate.md`)

| Step | Mô tả |
|------|------|
| 5.1 | Load all `lanes/CD{N}/signals.json` |
| 5.2 | Compute coverage_pct per dim theo công thức (xem [05-execution-profiles.md](05-execution-profiles.md) §9.1) |
| 5.3 | Apply threshold theo profile (60/80/95/100%) |
| 5.4 | Build `coverage-matrix.json` Atomic Write |
| 5.5 | Build `signals-aggregated.jsonl` (deduplicate cross-lane) |
| 5.6 | Build `coverage-report.md` ≤15 dòng tiếng Việt |
| 5.7 | Check threshold violations → CDG E090 escalate per-dim below threshold |
| 5.8 | Phase Report Phase5-report.md |

### Phase 6 — Regression Map (`phase6-regression.md`)

SKIP nếu `--since` not set hoặc profile=quick.

| Step | Mô tả |
|------|------|
| 6.1 | Validate `$SINCE_REF` (git rev-parse — E061) |
| 6.2 | Get changed files: `git diff --name-only $SINCE_REF...HEAD -- $SCOPE_PATTERN` |
| 6.3 | If 0 files → EXIT 0 với report "no changes detected" (E065) |
| 6.4 | Build direct callers (GitNexus impact upstream OR Grep fallback) |
| 6.5 | Build transitive callers (GitNexus query — confidence per hop) |
| 6.6 | Affected modules computation (cross-ref module-graph từ Phase 2) |
| 6.7 | Affected workflows computation (cross-ref workflow-graph) |
| 6.8 | Test plan generation (find existing tests touching affected modules) |
| 6.9 | Confidence scoring per prediction (filter < 0.7 → mark low-confidence) |
| 6.10 | Build `regression-map.json` + `regression-report.md` |
| 6.11 | Phase Report Phase6-report.md |

### Phase 7 — GAP + CDG (`phase7-gap-cdg.md`)

| Step | Mô tả |
|------|------|
| 7.1 | Load matrix + invariants + signals + regression map |
| 7.2 | GAP detection per dim — find dims below threshold + identify root cause patterns |
| 7.3 | Generate gap suggestions per kind (test_case, invariant_rule, contract, doc_snippet) |
| 7.4 | If `--auto-suggest` → CDG E094 batch ("Sẽ APPEND N invariants vào registry. Confirm?") |
| 7.5 | If user ACCEPT → write invariants to sidecar artifact `business-invariants.json` (bump nếu chưa v3) qua Safe-Write APPEND |
| 7.6 | If user REJECT → log audit, không trigger lại trong session sau (trừ `--force`) |
| 7.7 | If user DEFER → mark status=`proposed`, skip commit |
| 7.8 | Build `gap-suggestions.json` + `gap-report.md` |
| 7.9 | Cross-domain conflict resolution (carry over từ Phase 3 nếu pending) |
| 7.10 | Phase Report Phase7-report.md |

### Phase 8 — Report (`phase8-report.md`)

| Step | Mô tả |
|------|------|
| 8.1 | Load all phase outputs |
| 8.2 | Compute final status (PASS/WARN/FAIL) — overall coverage + violations + cross-domain conflicts |
| 8.3 | Build `integrity-report.md` ≤30 dòng tiếng Việt (template populate) |
| 8.4 | Build `integrity-impact.json` (cross-skill artifact `integrity-impact-v1`) |
| 8.5 | Compute audit_chain.checksum (sha256 của source state file) |
| 8.6 | Insert git_commit + git_branch + author vào audit_chain |
| 8.7 | If `--show-graphs` → render Mermaid diagrams 6 graphs inline trong integrity-report.md |
| 8.8 | If `--ci` → format JSON output + post comment lên PR (GitHub API call) |
| 8.9 | Mark session COMPLETED trong `_index/sessions.jsonl` |
| 8.10 | Phase Report Phase8-report.md (final summary) |
| 8.11 | Release lock + kill heartbeat daemon |

---

## 5. `resume-status.md`

| Mode | Behavior |
|------|----------|
| `--resume` | 1. Đọc `integrity-status.json` → xác định `current_phase` + `next_action`<br>2. Stale lock check: age >30 min → auto-release (E008)<br>3. Re-validate PRE-GATE của next phase<br>4. Route phase → load procedure file<br>5. Continue execution |
| `--status` | 1. Đọc `integrity-status.json`<br>2. In summary: session_id, scope, profile, current_phase, % done, lane_status, context_budget_used_pct, lock_owner_pid + heartbeat age<br>3. Exit 0 |
| `--resume` ambiguous | Multiple session đang dở → prompt user chọn (AskUserQuestion) hoặc require `--session-id` |

### Stale lock auto-release flow

```bash
heartbeat_age = NOW - lock_heartbeat_at
if heartbeat_age > 30 min:
  log E008 "Stale lock detected (age=${heartbeat_age}s, owner=${lock_owner_pid})"
  rm $SESSION_DIR/.lock
  re-acquire lock với current PID
  continue resume
```

---

## 6. SKILL.md routing → procedures (lazy-load contract)

`SKILL.md` (lean routing hub, ≤500 dòng) chứa bảng routing:

```markdown
## Phase Routing

| Phase | Procedure file | Trigger |
|-------|---------------|---------|
| 1 | `procedures/phase1-init.md` | Always (entry) |
| 2 | `procedures/phase2-discovery.md` | After Phase 1 PASS |
| 3 | `procedures/phase3-invariant-registry.md` | After Phase 2 PASS |
| 4 | `procedures/phase4-coverage-dispatch.md` | After Phase 3 PASS |
| 5 | `procedures/phase5-aggregate.md` | After Phase 4 PASS |
| 6 | `procedures/phase6-regression.md` | After Phase 5 PASS (skip nếu no --since) |
| 7 | `procedures/phase7-gap-cdg.md` | After Phase 6 PASS hoặc Phase 5 PASS (skip 6) |
| 8 | `procedures/phase8-report.md` | After Phase 7 PASS |
| resume | `procedures/resume-status.md` | `--resume` hoặc `--status` flag |
```

**Quy tắc:** `SKILL.md` KHÔNG chứa execution logic — chỉ routing + summaries + contracts. Logic chi tiết LIVE trong `procedures/phase{N}-*.md`.

---

## 7. Spawn agent contract per phase

| Phase | Spawn agent? | Agent type | Concurrency |
|-------|-------------|-----------|-------------|
| 1 | ❌ | — | — |
| 2 | ⚪ Optional (LLM-assisted parse) | architect | 1 |
| 3 | ✅ | architect + business-analyst + {domain}-experts | Max 5 (leave 5 budget for Phase 4 retry) |
| 4 | ✅ | 10 lane agents (xem [agent-prompt.md](agent-prompt.md)) | 10 (max CORE-025) |
| 5 | ❌ (pure aggregation) | — | — |
| 6 | ⚪ Optional (predictive scoring) | data-engineer | 1 |
| 7 | ✅ | business-analyst + {domain}-experts (cho gap suggestions) | Max 3 |
| 8 | ❌ (pure report generation) | — | — |

**Tổng agent spawn tối đa per session:** ~25 agents (Phase 3-7), nhưng concurrent max 10 (CORE-025 enforce).

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-032 (Lazy-Load Procedures), CORE-035 (Phase Output Organization), CORE-037 (Agent Prompt 8-section)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §3-4
- Agent prompt: [agent-prompt.md](agent-prompt.md) (10 lane agents + triage)
- Real example: [`../wf-fix-bugs/`](../wf-fix-bugs/) (orchestrator 11-lane pattern), [`../wf-legacy-scan/`](../wf-legacy-scan/) (5-stage IPS pattern)
