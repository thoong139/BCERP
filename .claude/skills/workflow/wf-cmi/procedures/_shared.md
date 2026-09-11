# Shared Protocols — wf-cmi v1.0.0

> Cross-cutting protocols, state variables glossary, error handling, CI detection, R/W lock pattern, agent prompt templates được dùng bởi nhiều Phase trong `wf-cmi`.
>
> **KHÔNG đọc file này standalone** — phase file sẽ chỉ định section cụ thể cần load.

---

## Sections

- [§1 State Variables Glossary](#1-state-variables-glossary)
- [§2 Cross-Phase Data Flow](#2-cross-phase-data-flow)
- [§3 Atomic Write Pattern](#3-atomic-write-pattern)
- [§4 Error Handling Canonical](#4-error-handling-canonical)
- [§5 Auto-Fix & Escalation Protocol](#5-auto-fix--escalation-protocol)
- [§6 On Failure — Standard Format](#6-on-failure--standard-format)
- [§7 Execution Trace (CORE-026)](#7-execution-trace-core-026)
- [§8 Phase Summary (CORE-028)](#8-phase-summary-core-028)
- [§9 Context & Checkpoint](#9-context--checkpoint)
- [§10 Template Usage Rule (CORE-031)](#10-template-usage-rule-core-031)
- [§11 Task Planning (Protocol 9)](#11-task-planning-protocol-9)
- [§12 CI Detection Pattern (Protocol 20)](#12-ci-detection-pattern-protocol-20)
- [§13 Session Lock & Heartbeat](#13-session-lock--heartbeat)
- [§14 Cross-Session R/W Lock (Protocol 22)](#14-cross-session-rw-lock-protocol-22)
- [§15 Agent Prompt Templates](#15-agent-prompt-templates)
- [§16 Session Isolation Protocol](#16-session-isolation-protocol)
- [§17 Author Info (Multi-User)](#17-author-info-multi-user)
- [§18 CDG Token Persist Pattern](#18-cdg-token-persist-pattern)
- [§19 Audit Chain Construction](#19-audit-chain-construction)

---

## §1 State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt pipeline execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|-------------|---------------|-------------|
| `$SESSION_ID` | 1 | All | Format `YYYY-MM-DD-{scope}-{slug}-{NN}` |
| `$SESSION_DIR` | 1 | All | `.mc-data/work/wf-cmi/sessions/$SESSION_ID` |
| `$PROFILE` | 1 | 2-8 | `quick` / `standard` / `deep` / `exhaustive` |
| `$DIMS_ACTIVE` | 1 | 2-8 | Array CD1..CD10 active theo profile + `--dims` override |
| `$SCOPE_TYPE` | 1 | 2-8 | `system` / `module` / `feat` |
| `$SCOPE_NAME` | 1 | 2-8 | Module name / FEAT-ID hoặc empty cho `system` |
| `$SINCE_REF` | 1 | 6 | Git ref cho regression-aware mode (optional) |
| `$AUTO_SUGGEST` | 1 | 7 | Boolean — `--auto-suggest` flag |
| `$DRY_RUN` | 1 | 7,8 | Boolean — `--dry-run` flag |
| `$CI_MODE` | 1 | 7,8 | Boolean — `--ci` flag (GitHub Action mode) |
| `$NO_CACHE` | 1 | 2,6 | Boolean — `--no-cache` flag |
| `$SHOW_GRAPHS` | 1 | 8 | Boolean — `--show-graphs` flag |
| `$GITNEXUS_AVAILABLE` | 1 (CI PRE-GATE) | 2-8 | Boolean — Protocol 20 |
| `$SERENA_AVAILABLE` | 1 (CI PRE-GATE) | 2-8 | Boolean — Protocol 20 |
| `$CI_CONTEXT` | 1 (CI PRE-GATE) | 2-7 | CI context string cho agent prompts |
| `$INDEX_FRESHNESS` | 1 | 2,6 | `ok` / `light` / `strong` / `severe` |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage (0-100) |
| `$RETRY_COUNT[phase]` | All phases | All phases | Per-phase retry counter (max 3) |
| `$AUTHOR_EMAIL` | 1 | All | `git config user.email` |
| `$AUTHOR_NAME` | 1 | All | `git config user.name` |
| `$LANE_STATUS` | 4 | 5,7,8 | Map `CD{N}` → PASS/FAIL/SKIPPED/TIMEOUT |
| `$OVERALL_STATUS` | 5 | 7,8 | PASS / WARN / FAIL |
| `$TOTAL_SIGNALS` | 5 | 7,8 | Tổng signals aggregated |

### §1.1 Contract Reference: `_contract.json`

> **SSOT cho output paths, templates, error codes, inputs, cross-skill contracts.**
> Khi thêm/sửa output hoặc error code → **cập nhật `_contract.json` trước**, rồi mới code.

---

## §2 Cross-Phase Data Flow

```
Phase 1 (Init)          → integrity-status.json, session-log.json, error-ledger.json,
                           .lock (acquired), $SESSION_ID, $PROFILE, $DIMS_ACTIVE,
                           $CI_CONTEXT, Phase1-report.md

Phase 2 (Discovery)     → entity-graph.json, module-graph.json, workflow-graph.json,
                           api-graph.json, event-graph.json, rbac-matrix.json,
                           Phase2-report.md

Phase 3 (Invariant)     → business-invariants.json (per-session draft),
                           invariants-diff.json, Phase3-report.md

Phase 4 (Coverage)      → lanes/CD{N}/signals.json (5-10 files),
                           lanes/CD{N}/lane-status.json,
                           lanes/CD{N}/CD{N}-report.md,
                           probe-failures.log, Phase4-report.md

Phase 5 (Aggregate)     → coverage-matrix.json, coverage-report.md,
                           signals-aggregated.jsonl, $OVERALL_STATUS, $TOTAL_SIGNALS,
                           Phase5-report.md

Phase 6 (Regression)    → regression-map.json, regression-report.md,
                           Phase6-report.md

Phase 7 (GAP + CDG)     → gap-suggestions.json, gap-report.md,
                           cdg-decisions.jsonl,
                           .mc-data/work/wf-cmi/business-invariants.json (APPEND sidecar),
                           Phase7-report.md

Phase 8 (Report)        → integrity-report.md, integrity-impact.json,
                           Phase8-report.md,
                           integrity-status.json (pipeline_status=DONE)
```

---

## §3 Atomic Write Pattern

> CORE-006 Safe-Write + CORE-035 Atomic Write. Áp dụng cho MỌI JSON state file.

```bash
# Pattern bắt buộc cho integrity-status.json + các JSON state files:
TARGET="$SESSION_DIR/integrity-status.json"
TMP="${TARGET}.tmp.$$"

# 1. Build new content vào tmp file (qua jq mutation hoặc echo content)
jq --arg phase "1" '.current_phase = ($phase | tonumber) | .phases_completed += [1]' \
   "$TARGET" > "$TMP"

# 2. Validate tmp file pass JSON parse
jq '.' "$TMP" > /dev/null || { rm -f "$TMP"; echo "FAIL: invalid JSON" >&2; exit 1; }

# 3. Atomic move
mv "$TMP" "$TARGET"
```

**Áp dụng cho:**
- `integrity-status.json` (SSOT pipeline state)
- `session-log.json` (execution trace)
- `error-ledger.json` (error tracking)
- 6 graphs `*.json` (Phase 2)
- `business-invariants.json` (Phase 3 + sidecar)
- `signals.json` per-lane (Phase 4)
- `coverage-matrix.json` (Phase 5)
- `regression-map.json` (Phase 6)
- `gap-suggestions.json` (Phase 7)
- `integrity-impact.json` (Phase 8 cross-skill artifact)

**KHÔNG áp dụng cho:** MD reports (Phase{N}-report.md), templates đã populate, JSONL append-only (cdg-decisions.jsonl, signals-aggregated.jsonl, probe-failures.log).

---

## §4 Error Handling Canonical

### Namespace Convention (v1.0)

```
E001-E009   → Pipeline/session/lock (shared)
E010-E019   → Phase 1 Init (args, CI PRE-GATE, registry, lock)
E020-E029   → Phase 2 Discovery (6 graph builds)
E030-E039   → Phase 3 Invariant (LLM, domain expert, schema)
E040-E049   → Phase 4 Coverage Dispatch (lane spawn, signals)
E050-E059   → Phase 5 Aggregate (compute, matrix, threshold)
E060-E069   → Phase 6 Regression (impact, predict, test plan)
E070-E079   → Phase 7 GAP + CDG (suggestion, decision log)
E080-E089   → Phase 8 Report (artifact write, audit chain)
E090-E099   → CDG User-Facing Gates (coverage, conflict, compliance)
E100-E109   → Warnings (CI degrade, stale cache, low confidence)
```

### Canonical Lookup (quick reference)

| Code | Severity | Tình huống | Xử lý | Phase |
|------|---------|-----------|-------|-------|
| E001 | critical | POST-GATE fail sau 3 retries | DỪNG, escalate | All |
| E002 | medium | User REJECT CDG decision | Checkpoint, `--resume` | 3,5,7 |
| E003 | critical | Registry thiếu/rỗng | STOP — chạy `/wf-brainstorm` | 1 |
| E004 | critical | Procedure file không tồn tại | STOP | 1 |
| E005 | info | 100% coverage + 0 violations | Early-exit Phase 8 OK | 5 |
| E008 | medium | Stale lock detected (≥30 min) | Auto-release, WARN | 1, resume |
| E009 | critical | Context > 90% | FORCE checkpoint, STOP | All |
| E010 | critical | Registry missing | ESCALATE → `/wf-brainstorm` | 1 |
| E011 | critical | Registry schema invalid | ESCALATE user fix manual | 1 |
| E012 | high | Registry empty / args conflict | ESCALATE | 1 |
| E013 | high | Architecture docs missing | ESCALATE → `/wf-design` | 1 |
| E014 | high | `--since` invalid ref | ESCALATE user fix | 1, 6 |
| E015 | medium | `--session-id` format invalid | Re-generate auto, WARN | 1 |
| E016 | medium | Args conflict (vd `--resume + --scope`) | Resolve theo priority, WARN | 1 |
| E017 | high | Session dir creation fail | Retry x3, ESCALATE | 1 |
| E018 | high | Lock acquire fail (peer session) | Retry x3 + 5s delay | 1 |
| E019 | high | Heartbeat daemon spawn fail | Retry x1, ESCALATE | 1 |
| E020-E029 | medium-high | Graph build fails | Per-graph retry, fallback Grep | 2 |
| E030-E039 | medium-high | LLM inference/schema fails | Retry, fallback, CDG E091 conflict | 3 |
| E040-E049 | medium-high | Lane spawn/timeout/schema fails | Per-lane retry x1 | 4 |
| E050-E059 | medium | Aggregate/matrix/threshold fails | Re-aggregate, re-format | 5 |
| E060-E069 | medium | Regression scope/predict fails | Fallback diff-aware, WARN | 6 |
| E070-E079 | medium | CDG decision/suggestion fails | Retry x1, escalate | 7 |
| E080-E089 | high | Artifact write/audit chain fails | Retry x3, ESCALATE | 8 |
| E090-E099 | info | CDG user-facing gates | DỪNG, AskUserQuestion | All |
| E100-E109 | low | Warnings — CI degrade/cache | LOG, continue | All |

> **Canonical chi tiết:** `_contract.json §errors` (108 entries E001-E109).
> **Auto-fix budget:** Per-phase, max 3 retries / phase.

---

## §5 Auto-Fix & Escalation Protocol

> Áp dụng SAU mỗi POST-GATE. Mục tiêu: tự sửa lỗi nhỏ, không làm phiền user khi không cần.

```
BUDGET MODEL: PER-PHASE (max 3 retries total / phase).
  - Mỗi tier fail trigger 1 attempt fix → increment $RETRY_COUNT[$PHASE]
  - Khác tier cũng share 1 budget
  - Reset $RETRY_COUNT[$PHASE] = 0 khi POST-GATE PASS

1. ATTEMPT auto-fix theo Fix Rules:
   - T1 fail (file missing) → re-run step tạo file
   - T2 fail (structure wrong) → re-read template + populate lại
   - T3 fail (content too short) → re-generate với more context
   - T4 fail (cross-ref mismatch) → re-read source + re-write target

2. ESCALATE khi:
   - $RETRY_COUNT[$PHASE] >= 3 → STOP với error message
   - Hoặc auto-fix không khả thi

3. ESCALATION format:
   - AskUserQuestion với options: "Re-run phase" / "Skip (risky)" / "Cancel"
   - Append entry vào error-ledger.json
```

### Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `template_missing` | Đọc lại template từ git history hoặc re-locate `templates/` path | Không có history → escalate |
| `post_gate_t1_t4_fail` | Retry phase x1 với verbose logging | Vẫn fail → escalate |
| `agent_output_invalid` | Re-spawn agent x1 với prompt nhấn mạnh schema | Vẫn invalid → STOP |
| `llm_timeout` (Phase 3) | Retry x1 với scope thu hẹp | Domain expert unreachable → fallback business-analyst |
| `lane_timeout` (Phase 4) | Mark lane TIMEOUT, continue khác lanes | ≥3 lanes timeout → batch escalate |
| `context_overflow` | FORCE checkpoint, STOP (E009) | — |
| `lock_stale` | Auto-release, WARN, continue | — |
| `ci_detection_fail` | Fallback Grep/Glob (E100) | — |
| `cross_domain_conflict` | CDG E091 dual-approval | User DEFER → log, không enforce |

---

## §6 On Failure — Standard Format

> Áp dụng cho mọi phase. Khi POST-GATE fail hoặc step quan trọng fail.

```
ON FAILURE (BẮT BUỘC mỗi phase):

1. APPEND error-ledger.json (Atomic Write Pattern):
   {
     "phase": "[phase-id]",
     "error_code": "[E0XX]",
     "message": "[mô tả ngắn]",
     "timestamp": "ISO-8601",
     "retry_count": $RETRY_COUNT[$PHASE]
   }

2. AUTO-FIX qua §5 (max 3 retries / phase).

3. Nếu vẫn fail sau retry:
   a. WRITE Phase{N}-report.md với status=FAILED + reason
   b. WRITE session-log.json entry FAIL (Execution Trace)
   c. UPDATE integrity-status.json: phases.phase{N}.status = "failed"
   d. STOP pipeline + AskUserQuestion: "Re-run --resume / Cancel"

4. KHÔNG advance sang phase tiếp theo khi POST-GATE chưa pass.
```

---

## §7 Execution Trace (CORE-026)

> Mọi phase ghi START/COMPLETE/FAIL events vào HAI session log.
> Output-only — KHÔNG đọc lại file này làm input context.

```
EVENT FORMAT:
{
  "timestamp": "ISO-8601",
  "skill": "wf-cmi",
  "phase": "1-8",
  "event": "START|COMPLETE|FAIL|CHECKPOINT|SKIP",
  "duration_ms": 0,
  "metadata": {}
}

WHEN TO WRITE:
- START: ngay sau PRE-GATE pass, trước Step đầu tiên
- COMPLETE: ngay sau POST-GATE pass
- FAIL: trong §6 On Failure flow
- CHECKPOINT: sau mỗi milestone quan trọng (vd lane done)
- SKIP: phase skipped theo profile rule

DUAL-WRITE pattern (atomic append):
GLOBAL_TRACE=".mc-data/work/_trace/session-log.json"
SESSION_TRACE="${SESSION_DIR}/session-log.json"

mkdir -p "$(dirname "$GLOBAL_TRACE")"
for TARGET in "$GLOBAL_TRACE" "$SESSION_TRACE"; do
  [ ! -s "$TARGET" ] && echo '{"skill":"wf-cmi","events":[]}' > "$TARGET"
  TMP="${TARGET}.tmp.$$"
  jq --arg ts "$(date -Iseconds)" --arg ph "$PHASE" --arg ev "START" \
     '.events += [{timestamp:$ts, skill:"wf-cmi", phase:$ph, event:$ev}]' \
     "$TARGET" > "$TMP" && mv "$TMP" "$TARGET"
done
```

---

## §8 Phase Summary (CORE-028)

> Mọi phase TẠO Phase{N}-report.md sau POST-GATE — viết tiếng Việt, ≤15 dòng,
> dành cho non-specialist đọc hiểu tiến độ.

```
PATH: $SESSION_DIR/phase{N}-{name}/Phase{N}-report.md

FORMAT (tiếng Việt, ≤15 dòng):

## Phase [N]: [Tên phase] — PASS|FAIL
Thời gian: [ISO-8601]

**Đã làm:**
- [1-2 câu mô tả hành động chính]

**Kết quả:**
- [Số liệu chính]
- [File đầu ra]

**Tiếp theo:**
- [Phase kế tiếp hoặc hành động user]

QUY TẮC:
- KHÔNG dùng jargon (CDG, T1-T4, $CI_CONTEXT, ...) — viết cho người không chuyên
- ≤15 dòng MỖI report (CORE-028)
- Output từ template templates/Phase{N}-report.md
```

---

## §9 Context & Checkpoint

> CORE-038 Context Budget Management. Áp dụng cho mọi phase.

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu state files) |
| 80-90% | Lưu checkpoint, STOP sau phase hiện tại → `--resume` |
| > 90% | FORCE STOP (E009) — checkpoint bắt buộc |

**Checkpoint files tối thiểu:**
- `integrity-status.json` (current phase + next_action)
- `session-log.json` (execution trace)
- Current `Phase{N}-report.md`

**Helper inline:**
```bash
check_context_budget() {
  if [ "$CONTEXT_PERCENT" -gt 90 ]; then
    log_phase_fail "E009: context >90%, force stop"
    write_checkpoint
    exit 9
  elif [ "$CONTEXT_PERCENT" -gt 80 ]; then
    log_phase_event "CHECKPOINT" "context >80%, stop after phase"
    return 1
  fi
  return 0
}
```

---

## §10 Template Usage Rule (CORE-031)

> BẮT BUỘC: Mọi output file có template PHẢI được tạo bằng pattern:
> 1. **READ** template từ `templates/` directory
> 2. **POPULATE** values (thay thế placeholders + strip `_template_notes`, `_schema_notes`)
> 3. **WRITE** output via Atomic Write (`.tmp.$$` → validate → mv)

### Placeholder Convention

| File type | Pattern | Ví dụ |
|-----------|---------|-------|
| JSON templates | `{{VAR_NAME}}` | `"session_id": "{{SESSION_ID}}"` |
| Markdown templates | `[VAR_NAME]` | `# Phase Report: [PHASE_NAME]` |

### Template Metadata Stripping

```bash
# Canonical STRIP pattern — loại bỏ MỌI field bắt đầu `_` ở mọi cấp
strip_template_metadata() {
  local template_path="$1"
  local output_path="$2"
  jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
    "$template_path" > "${output_path}.tmp.$$"
  # Populate values sau khi strip
  jq --arg sid "$SESSION_ID" \
     --arg ts "$(date -Iseconds)" \
     '. + {"session_id": $sid, "generated_at": $ts}' \
     "${output_path}.tmp.$$" > "${output_path}"
  rm -f "${output_path}.tmp.$$"
}
```

**Template locations:**
- `.claude/skills/workflow/wf-cmi/templates/` (18 templates)
- `_common/` subfolder cho session-log + error-ledger templates

---

## §11 Task Planning (Protocol 9)

> Phase 1 (entry point) PHẢI init TodoWrite với danh sách 8 phases.
> Mỗi phase POST-GATE PASS → mark phase đó completed.

```
TODOWRITE INIT (Phase 1 Step cuối):

todos = [
  {content: "Phase 1: Init — args validate, CI PRE-GATE, session init", activeForm: "Khởi tạo session"},
  {content: "Phase 2: Discovery — build 6 graphs", activeForm: "Build 6 graphs"},
  {content: "Phase 3: Invariant Artifact — 3-pass LLM infer", activeForm: "Suy luận business invariants"},
  {content: "Phase 4: Coverage Dispatch — spawn 10 lanes parallel", activeForm: "Dispatch coverage lanes"},
  {content: "Phase 5: Aggregate — coverage matrix", activeForm: "Aggregate signals"},
  {content: "Phase 6: Regression Map — predictive impact", activeForm: "Build regression map"},
  {content: "Phase 7: GAP + CDG — gap detect + decisions", activeForm: "GAP detection + CDG"},
  {content: "Phase 8: Report — integrity-impact.json", activeForm: "Generate final report"}
]

UPDATE pattern (sau mỗi POST-GATE pass):
- Mark phase hiện tại = completed
- Mark phase kế tiếp = in_progress

SKIP pattern (Phase 6 skipped khi profile=quick hoặc no --since):
- Mark Phase 6 = completed (note: skipped — profile=quick / no --since)
- Mark Phase 7 = in_progress

EARLY EXIT pattern (Phase 5 healthy 100% → E005):
- Mark Phase 5 = completed
- Mark Phase 6 = completed (note: skipped — E005 healthy)
- Mark Phase 7 = completed (note: skipped — E005 healthy)
- Mark Phase 8 = in_progress
```

---

## §12 CI Detection Pattern (Protocol 20)

> Protocol 20 §20.8. CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

### CI PRE-GATE (3-step — Phase 1)

| Step | Action | Verify |
|------|--------|--------|
| Na | **Load CI Capabilities:** `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | CI flags set |
| Nb | **Index Freshness Check:** `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. 4 mức: ok/light/strong/severe. Strong+ → WARN, fallback. | $INDEX_FRESHNESS set |
| Nc | **Agent Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → set `$CI_CONTEXT`. Pass vào spawned agents qua prompt. | $CI_CONTEXT ready |

### CI-ROUTE Matrix cho wf-cmi (Protocol 20 §20.5)

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `entity_graph` | **GitNexus** `clusters` | **Serena** `find_symbol` | Glob `**/Domain/Entities/*.cs` |
| `module_graph` | **GitNexus** `query({key_concept})` | — | Grep `using.*Modules` |
| `workflow_graph` | **GitNexus** `query(workflow)` + **Serena** `get_symbols_overview` | — | Grep CQRS Command/Handler |
| `api_graph` | **GitNexus** `route_map()` | — | Grep `MapPost\|MapGet\|MapPut\|MapDelete` |
| `event_graph` | **GitNexus** `cypher` + **Serena** `find_refs` | — | Grep `IntegrationEvent\|DomainEvent` |
| `rbac_matrix` | **Serena** `find_symbol(Authorization)` | — | Grep `[Authorize]\|[RequirePermission]` |
| `impact_analysis` (Phase 6) | **GitNexus** `impact({changed_files, direction:"upstream"})` | — | `git diff --name-only` + manual trace |
| `change_detection` (Phase 6) | **GitNexus** `detect_changes()` | — | `git diff --stat $SINCE_REF...HEAD` |

### Cache TTL

| Tool | Available TTL | Absent TTL |
|------|--------------|------------|
| GitNexus | 24h | 4h |
| Serena | 24h | 1h |

**Bypass cache:** `--no-cache` flag → force fresh detect.

---

## §13 Session Lock & Heartbeat

> Session-level lock chống 2 instance ghi cùng SESSION_DIR.
> Stale auto-release sau 30 phút (configurable qua `MCV3_CMI_LOCK_STALE_MIN`).

### Lock file schema (`cmi-lock-v1`)

```json
{
  "$schema": "cmi-lock-v1",
  "session_id": "2026-05-15-system-eureka-erp-01",
  "pid": 12345,
  "host": "dev-machine-a",
  "acquired_at": "2026-05-15T14:30:00+07:00",
  "heartbeat_at": "2026-05-15T14:34:30+07:00",
  "phase": 4,
  "author": {"email": "dev.a@erktransport.com", "name": "Developer A"}
}
```

### Acquire lock (atomic mkdir guard)

```bash
acquire_lock() {
  local session_dir="$1"
  local lock_file="$session_dir/.lock"

  # Check existing lock
  if [ -f "$lock_file" ]; then
    local existing_pid existing_host
    existing_pid=$(jq -r '.pid' "$lock_file" 2>/dev/null)
    existing_host=$(jq -r '.host' "$lock_file" 2>/dev/null)
    local current_host
    current_host=$(hostname 2>/dev/null || echo "unknown")

    # Path A: same host — PID liveness check
    if [ "$existing_host" = "$current_host" ]; then
      if kill -0 "$existing_pid" 2>/dev/null; then
        echo "E018: Peer session active (PID $existing_pid)" >&2
        return 1
      fi
      # PID dead → takeover
      echo "WARN: Stale lock (PID $existing_pid dead) — takeover" >&2
    else
      # Path B: different host — mtime check
      local age stale_min
      age=$(($(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file")))
      stale_min="${MCV3_CMI_LOCK_STALE_MIN:-30}"
      if [ "$age" -lt $((stale_min * 60)) ]; then
        echo "E018: Peer session active (other host, age=${age}s)" >&2
        return 1
      fi
      echo "E008: Stale lock (age=${age}s) — auto-release" >&2
    fi
  fi

  # Write lock atomically
  local tmp="$lock_file.tmp.$$"
  jq -n --arg sid "$SESSION_ID" --arg pid "$$" --arg host "$(hostname)" \
        --arg ts "$(date -Iseconds)" --arg email "$AUTHOR_EMAIL" --arg name "$AUTHOR_NAME" \
     '{"$schema": "cmi-lock-v1", session_id: $sid, pid: ($pid | tonumber),
       host: $host, acquired_at: $ts, heartbeat_at: $ts, phase: 1,
       author: {email: $email, name: $name}}' > "$tmp"
  mv "$tmp" "$lock_file"
}
```

### Heartbeat daemon (update mtime + heartbeat field every 30s)

```bash
start_heartbeat_daemon() {
  local session_dir="$1"
  (
    while [ -f "$session_dir/.lock" ]; do
      jq --arg ts "$(date -Iseconds)" '.heartbeat_at = $ts' \
         "$session_dir/.lock" > "$session_dir/.lock.tmp.$$" \
         && mv "$session_dir/.lock.tmp.$$" "$session_dir/.lock"
      touch "$session_dir/.lock"
      sleep 30
    done
  ) &
  echo $! > "$session_dir/.heartbeat.pid"
}
```

### Cleanup (release lock + kill daemon)

```bash
cleanup() {
  local hb_pid
  hb_pid=$(cat "$SESSION_DIR/.heartbeat.pid" 2>/dev/null)
  [ -n "$hb_pid" ] && kill "$hb_pid" 2>/dev/null
  rm -f "$SESSION_DIR/.lock" "$SESSION_DIR/.heartbeat.pid"
}

trap cleanup EXIT INT TERM
```

---

## §14 Cross-Session R/W Lock (Protocol 22)

> Protocol 22 — Cross-session lock cho shared resources (sidecar artifact, scan cache).
> N readers concurrent OK; write exclusive.

### Lock path & resources

| Resource | Lock path | Acquired by |
|----------|-----------|-------------|
| `business-invariants` (sidecar) | `.mc-data/work/wf-cmi/_locks/business-invariants.rwlock` | Phase 7 sync (WRITE), Phase 3 read (READ) |
| `scan-cache` | `.mc-data/work/wf-cmi/_locks/scan-cache.rwlock` | Phase 2-6 (READ), Phase 2 cache publish (WRITE) |
| `ci-index` (shared with other skills) | `.mc-data/work/_locks/code-intelligence.rwlock` | CI PRE-GATE Na (READ) |

### Acquire read lock (allow N concurrent readers)

```bash
acquire_read_lock() {
  local resource="$1"  # e.g., business-invariants
  local lock_dir=".mc-data/work/wf-cmi/_locks"
  local lock_file="$lock_dir/${resource}.rwlock"
  local reader_id="$$.$(date +%N)"

  mkdir -p "$lock_dir"
  [ ! -f "$lock_file" ] && echo '{"writer":null,"readers":[]}' > "$lock_file"

  # Check if writer active
  local writer
  writer=$(jq -r '.writer // empty' "$lock_file" 2>/dev/null)
  if [ -n "$writer" ]; then
    echo "WAIT: writer active ($writer), retrying..." >&2
    return 1  # Caller retries
  fi

  # APPEND reader_id
  jq --arg rid "$reader_id" '.readers += [$rid]' "$lock_file" > "$lock_file.tmp.$$" \
     && mv "$lock_file.tmp.$$" "$lock_file"
}
```

### Acquire write lock (exclusive — wait for all readers)

```bash
acquire_write_lock() {
  local resource="$1"
  local lock_file=".mc-data/work/wf-cmi/_locks/${resource}.rwlock"
  local writer_id="$$"

  # Wait until no readers + no writer (max 60s)
  local waited=0
  while [ "$waited" -lt 60 ]; do
    local writer_active reader_count
    writer_active=$(jq -r '.writer // empty' "$lock_file" 2>/dev/null)
    reader_count=$(jq -r '.readers | length' "$lock_file" 2>/dev/null || echo 0)
    if [ -z "$writer_active" ] && [ "$reader_count" -eq 0 ]; then
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done

  [ "$waited" -ge 60 ] && { echo "E018: Write lock timeout (60s)" >&2; return 1; }

  # Acquire writer slot
  jq --arg wid "$writer_id" '.writer = $wid' "$lock_file" > "$lock_file.tmp.$$" \
     && mv "$lock_file.tmp.$$" "$lock_file"
}

release_write_lock() {
  local resource="$1"
  local lock_file=".mc-data/work/wf-cmi/_locks/${resource}.rwlock"
  jq '.writer = null' "$lock_file" > "$lock_file.tmp.$$" && mv "$lock_file.tmp.$$" "$lock_file"
}

release_read_lock() {
  local resource="$1"
  local reader_id="$2"
  local lock_file=".mc-data/work/wf-cmi/_locks/${resource}.rwlock"
  jq --arg rid "$reader_id" '.readers -= [$rid]' "$lock_file" > "$lock_file.tmp.$$" \
     && mv "$lock_file.tmp.$$" "$lock_file"
}
```

**Trap pattern:**
```bash
trap 'release_read_lock business-invariants "$READER_ID" 2>/dev/null' EXIT INT TERM
```

---

## §15 Agent Prompt Templates

> CORE-037 — Mọi `Agent({...})` call PHẢI có đủ 8 sections.
> Canonical templates per phase tại [`docs/04-skill-design/wf-cmi/agent-prompt.md`](../../../../docs/04-skill-design/wf-cmi/agent-prompt.md).

### Render flow chuẩn

```text
READ agent-prompt.md §N (per phase + lane)
  ↓
SUBSTITUTE placeholders ({SESSION_DIR}, {PROFILE}, {SCOPE}, {DIMS_ACTIVE}, {AUTHOR}, $CI_CONTEXT, ...)
  ↓
STRIP HTML comment block (giữ từ "# 1. ROLE" trở đi)
  ↓
VERIFY rendered prompt có đủ 8 sections
  ↓
Agent({subagent_type, prompt=<rendered_text>, model="opus"})
```

### Agent spawn matrix per phase

| Phase | Spawn | Agent type | Concurrency | Reference |
|-------|-------|-----------|-------------|-----------|
| 1 | ❌ | — | — | — |
| 2 | ⚪ Optional | `architect` (LLM-assisted parse) | 1 | agent-prompt §2 |
| 3 | ✅ | `architect` + `{domain}-experts` + `business-analyst` | Max 5 (leave 5 budget cho Phase 4) | agent-prompt §3 |
| 4 | ✅ | 10 lane agents (xem dưới) | Max 10 (CORE-025) | agent-prompt §3-12 |
| 5 | ❌ | — | — | — |
| 6 | ⚪ Optional | `data-engineer` (predictive scoring) | 1 | agent-prompt §13 |
| 7 | ✅ | `business-analyst` + 1-3 `{domain}-experts` | Max 3 | agent-prompt §13 |
| 8 | ❌ | — | — | — |

### Lane agent map (Phase 4 — chính)

| Lane | Dim | Primary agent | Secondary | Skip condition |
|------|-----|---------------|-----------|----------------|
| CD1 | Business domain | `business-analyst` | `{domain}-experts` | — |
| CD2 | Entity dependency | `architect` | `dba` | — |
| CD3 | Workflow | `architect` | `business-analyst` | — |
| CD4 | API contract | `api-tester` | `architect` | — |
| CD5 | Event coverage | `architect` | `data-engineer` | `profile=quick` OR no event infra |
| CD6 | RBAC | `security` | `business-analyst` | `profile=quick` OR no auth |
| CD7 | Data integrity | `dba` | `data-engineer` | — |
| CD8 | Observability | `sre` | `devops` | `profile ∈ {quick,standard}` |
| CD9 | Regression | `qa-lead` | `architect` | `profile=quick` |
| CD10 | Documentation | `tech-writer` | `business-analyst` | `profile ∈ {quick,standard}` |

### Common ownership rules (every spawned agent)

```
KHÔNG được:
- Modify $SESSION_DIR/integrity-status.json (orchestrator owns)
- Modify $SESSION_DIR/error-ledger.json (write qua helper)
- Modify $SESSION_DIR/session-log.json (append qua helper)
- Spawn sub-agent (orchestrator only)
- Touch req-registry.json (read-only consumer)
- Touch sidecar business-invariants.json (orchestrator Phase 7 merge)

OWNER paths (per agent type — strict 1 file = 1 writer):
- Lane agent CD{N}: $SESSION_DIR/phase4-coverage/lanes/CD{N}/signals.json,
                     lane-status.json, CD{N}-report.md
- Domain expert (Phase 3): trả về JSON list invariants qua stdout/output,
                            orchestrator merge vào phase3-invariants/business-invariants.json
- Triage agent (Phase 7): gap-suggestions.json + gap-report.md + cdg-decisions.jsonl
```

### Completion criteria format (BẮT BUỘC mọi agent)

```
Báo cáo về orchestrator:
PHASE_{N}_{tag}_STATUS=PASS|FAIL
PHASE_{N}_{tag}_OUTPUTS=<comma-separated paths>
PHASE_{N}_{tag}_SIGNAL_COUNT=<N>   # Phase 4 lane only
PHASE_{N}_{tag}_NEXT=<next phase | null>
```

---

## §16 Session Isolation Protocol

```
SESSION_ID format: YYYY-MM-DD-{scope}-{slug}-{NN}
  scope: "system" | "module" | "feat" (slug-hóa)
  slug: lower-kebab của --name (hoặc "auto" cho scope=system)
  NN: auto-increment (01, 02, ...) qua glob check sessions.jsonl

SESSION_DIR: .mc-data/work/wf-cmi/sessions/$SESSION_ID/

Phase subdirectories created at session init:
  $SESSION_DIR/phase1-init/
  $SESSION_DIR/phase2-discovery/
  $SESSION_DIR/phase3-invariants/
  $SESSION_DIR/phase4-coverage/lanes/
  $SESSION_DIR/phase5-aggregate/
  $SESSION_DIR/phase6-regression/
  $SESSION_DIR/phase7-gap-cdg/
  $SESSION_DIR/phase8-report/

Index file: .mc-data/work/wf-cmi/_index/sessions.jsonl (APPEND-only)

Index entry schema:
{
  "session_id": "...",
  "scope": {"type": "...", "name": "..."},
  "profile": "...",
  "started_at": "ISO-8601",
  "status": "active|completed|failed|abandoned",
  "author": {"email": "...", "name": "..."},
  "host": "..."
}
```

---

## §17 Author Info (Multi-User)

> Multi-user collaboration qua Git — mỗi session ghi author vào lock + session-log + audit chain.

```bash
get_git_author() {
  AUTHOR_EMAIL=$(git config user.email 2>/dev/null || echo "unknown@local")
  AUTHOR_NAME=$(git config user.name 2>/dev/null || echo "Unknown User")
  export AUTHOR_EMAIL AUTHOR_NAME
}

get_git_commit_info() {
  GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-branch")
  export GIT_COMMIT GIT_BRANCH
}
```

**Sử dụng:**
- Phase 1: `get_git_author` → set state vars → ghi vào lock JSON
- Phase 8: `get_git_commit_info` → ghi vào `integrity-impact.json.audit_chain`
- Phase 7 CDG: `cdg-decisions.jsonl` ghi `approver` = `$AUTHOR_EMAIL`

---

## §18 CDG Token Persist Pattern

> CORE-027 + Protocol 16. Mọi quyết định CDG (Critical Decision Gate) PHẢI được persist để audit trail + anti-loop tracking.

### Canonical paths

| Phase | File |
|-------|------|
| Phase 1 | `$SESSION_DIR/phase1-init/cdg-tokens.json` |
| Phase 3 | `$SESSION_DIR/phase3-invariants/cdg-tokens.json` |
| Phase 5 | `$SESSION_DIR/phase5-aggregate/cdg-tokens.json` |
| Phase 7 | `$SESSION_DIR/phase7-gap-cdg/cdg-tokens.json` + `cdg-decisions.jsonl` |

### Schema (`cdg-tokens-v1`)

```json
{
  "$schema": "cdg-tokens-v1",
  "tokens": [
    {
      "gate": "E091-Scope-Profile-Upgrade",
      "decision": "continue|upgrade|cancel",
      "timestamp": "2026-05-15T14:30:00Z",
      "phase": "phase1",
      "status": "accepted",
      "approver": "dev.a@erktransport.com"
    }
  ]
}
```

### Append helper (atomic write)

```bash
append_cdg_token() {
  local phase="$1"
  local gate="$2"
  local decision="$3"
  local target="$SESSION_DIR/phase${phase%%-*}-${phase#*-}/cdg-tokens.json"
  local ts
  ts=$(date -Iseconds)

  [ ! -s "$target" ] && echo '{"$schema":"cdg-tokens-v1","tokens":[]}' > "$target"

  jq --arg g "$gate" --arg d "$decision" --arg t "$ts" --arg ph "$phase" --arg a "$AUTHOR_EMAIL" \
     '.tokens += [{gate:$g, decision:$d, timestamp:$t, phase:$ph, status:"accepted", approver:$a}]' \
     "$target" > "$target.tmp.$$" \
   && jq '.' "$target.tmp.$$" > /dev/null \
   && mv "$target.tmp.$$" "$target"
}
```

### Anti-loop guard

```
Mỗi CDG gate có max 2 reject per CDG-id → reject lần 3 = ESCALATE (E001).
Phase 7 sidecar APPEND CDG (E094) đặc biệt strict: anti-loop max 2 (CDG vs commit lớn).
```

---

## §19 Audit Chain Construction

> CORE-036 Cross-Skill Artifact Contract — `integrity-impact.json` PHẢI có audit_chain.

### Audit chain schema (per artifact)

```json
{
  "audit_chain": {
    "source": "$SESSION_DIR/integrity-status.json",
    "checksum": "sha256:abc123...",
    "git_commit": "abc12345",
    "git_branch": "feature/order-mgmt",
    "author": {"email": "dev.a@erktransport.com", "name": "Developer A"},
    "scanned_files": ["array<string>"],
    "since_ref": "main",
    "skipped_phases": [{"phase": 6, "reason": "profile=quick"}]
  }
}
```

### Compute checksum helper

```bash
compute_audit_chain_checksum() {
  local source_file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$source_file" | awk '{print "sha256:"$1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$source_file" | awk '{print "sha256:"$1}'
  else
    echo "sha256:unavailable"
  fi
}
```

### Sidecar source_registry_checksum (Phase 7)

```bash
# Sidecar artifact business-invariants.json có source_registry_checksum để detect stale
build_sidecar_audit_chain() {
  local registry_path=".mc-data/docs/_meta/req-registry.json"
  local registry_checksum
  registry_checksum=$(compute_audit_chain_checksum "$registry_path")

  jq --arg rc "$registry_checksum" --arg rp "$registry_path" \
     '.audit_chain.source_registry_checksum = $rc | .audit_chain.source_registry_path = $rp' \
     "$SIDECAR_PATH" > "$SIDECAR_PATH.tmp.$$" \
   && mv "$SIDECAR_PATH.tmp.$$" "$SIDECAR_PATH"
}
```

---

## §20 Cross-References

| Reference | Purpose |
|-----------|---------|
| `docs/04-skill-design/wf-cmi/05-error-codes.md` | E001-E149 + E150-E199 (v3) detail + auto-fix strategy |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | PRE/POST gates + 6 schemas + sidecar pattern + v3 e2e outputs |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | 10 phases routing + profile dispatch + regression-aware (v3 thêm Phase 9-10) |
| `docs/04-skill-design/wf-cmi/agent-prompt.md` | CORE-037 8-section templates cho 26 lanes + triage + CD41 v3 + Phase 10 source-fix |
| `.claude/skills/protocols/19-template-usage.md` | Template Usage Rule canonical |
| `.claude/skills/protocols/20-code-intelligence.md` | CI detection + routing |
| `.claude/skills/protocols/22-cross-session-rw-lock.md` | R/W lock cross-session |
| `_contract.json` | SSOT inputs + outputs + errors + cross_skill_contracts |

---

## §21 Browser Lock Pattern (v3.0 — for Phase 9 E2E Execute)

> Port từ `wf-e2e-scenario/procedures/_shared.md §Lock Strategy`. Áp dụng Phase 9 Step 9.2 (acquire) + Step 9.8 (release).

```bash
# Per-session browser-mcp.lock — bảo vệ Playwright MCP instance khỏi 2 phase 9 đồng thời trong cùng session
# Cross-session protection: dùng Protocol 22 R/W lock cho 'playwright' resource (separate)

BROWSER_LOCK="$SESSION_DIR/phase9-e2e-execute/.lock-browser-mcp"
BROWSER_LOCK_TTL_SEC=1800  # 30 min stale auto-release

acquire_browser_lock() {
  mkdir -p "$(dirname "$BROWSER_LOCK")"
  for i in {1..5}; do
    if [ ! -f "$BROWSER_LOCK" ]; then
      echo "$$:$(date -u +%s)" > "$BROWSER_LOCK"
      log_error "INFO" "browser_lock" "Acquired browser-mcp.lock (PID $$)"
      return 0
    fi
    # Check stale
    LOCK_TS=$(cut -d: -f2 "$BROWSER_LOCK" 2>/dev/null || echo 0)
    AGE=$(($(date -u +%s) - LOCK_TS))
    if [ "$AGE" -gt "$BROWSER_LOCK_TTL_SEC" ]; then
      log_error "E153" "browser_lock" "Stale lock detected (${AGE}s > ${BROWSER_LOCK_TTL_SEC}s) — auto-release"
      rm -f "$BROWSER_LOCK"
      echo "$$:$(date -u +%s)" > "$BROWSER_LOCK"
      return 0
    fi
    sleep 10
  done
  log_error "E153" "browser_lock" "Failed to acquire browser-mcp.lock after 5 attempts"
  return 1
}

release_browser_lock() {
  rm -f "$BROWSER_LOCK"
  log_error "INFO" "browser_lock" "Released browser-mcp.lock"
}

# Cleanup trap — release CẢ browser lock VÀ session lock
trap '
  release_browser_lock 2>/dev/null
  rm -f "$SESSION_DIR/.lock" 2>/dev/null
' EXIT
```

**Cross-session playwright resource lock (Protocol 22):**

Phase 9 PRE-GATE T4 cũng acquire cross-session reader lock cho `playwright` resource qua Protocol 22 (`.mc-data/work/wf-cmi/_locks/playwright.rwlock`). Nếu peer session đang writer lock (vd wf-e2e-scenario legacy còn chạy parallel — đến khi Stage 10 DEPRECATE) → wait hoặc fallback graceful.

---

## §22 Playwright Retry Pattern (v3.0 — Smart Retry by Failure Type)

> Port từ `wf-e2e-scenario/procedures/_shared.md §classify_failure() + execute_with_smart_retry()`.
> Áp dụng Phase 9 Step 9.6 (FOR each scenario → execute steps).

```bash
# Classify failure type → chỉ retry recoverable errors
# WHY: retry blanket dẫn đến retry assertion failures (bug thật) — che giấu lỗi + tốn thời gian

classify_failure() {
  local ERROR_TYPE="$1"
  local ERROR_MSG="$2"

  case "$ERROR_TYPE/$ERROR_MSG" in
    *TimeoutError*|*/TimeoutError*) echo "TIMEOUT" ;;
    *net:*|*ECONNREFUSED*|*ECONNRESET*|*ETIMEDOUT*) echo "NETWORK_ERROR" ;;
    *"selector"*|*"no element"*|*"strict mode"*) echo "SELECTOR_NOT_FOUND" ;;
    *"expected"*"received"*|*"toBe"*|*"toEqual"*) echo "ASSERTION_FAIL" ;;
    *TargetClosedError*|*"page was closed"*) echo "BROWSER_CRASH" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# Smart retry policy theo failure type:
#   TIMEOUT        → retry 3x với timeout x2 (environment có thể chậm)
#   NETWORK_ERROR  → exponential backoff 1,2,4,8,16s (max 5x — server transient)
#   SELECTOR_NOT_FOUND → 1 retry với fallback selector (UI chưa render)
#   ASSERTION_FAIL → KHÔNG retry — bug thật, push HIGH ngay
#   BROWSER_CRASH  → restart browser context, max 3x
#   UNKNOWN        → 2x conservative retry

execute_with_smart_retry() {
  local ACTION_DESC="$1"  # mô tả hành động để log
  local SCENARIO_ID="$2"

  local ATTEMPT=1
  local LAST_ERROR_TYPE=""

  while true; do
    if eval "${ACTION:-true}"; then
      # PASS — return
      return 0
    fi

    LAST_ERROR_TYPE=$(classify_failure "${LAST_ERROR_TYPE:-UNKNOWN}" "${LAST_ERROR_MSG:-}")

    case "$LAST_ERROR_TYPE" in
      TIMEOUT)
        [ "$ATTEMPT" -ge 3 ] && break
        SLEEP=$((ATTEMPT * 5))
        log_error "E160" "retry" "TIMEOUT attempt $ATTEMPT — sleep ${SLEEP}s"
        sleep "$SLEEP"
        ;;
      NETWORK_ERROR)
        [ "$ATTEMPT" -ge 5 ] && break
        BACKOFF=$((2 ** (ATTEMPT - 1)))
        log_error "E160" "retry" "NETWORK_ERROR attempt $ATTEMPT — backoff ${BACKOFF}s"
        sleep "$BACKOFF"
        ;;
      SELECTOR_NOT_FOUND)
        [ "$ATTEMPT" -ge 2 ] && break
        log_error "E160" "retry" "SELECTOR_NOT_FOUND attempt $ATTEMPT — try fallback selector"
        ;;
      ASSERTION_FAIL)
        # KHÔNG retry — defer Phase 10 classify + auto-fix
        log_error "E160" "assertion" "ASSERTION_FAIL: $ACTION_DESC — defer Phase 10"
        return 1
        ;;
      BROWSER_CRASH)
        [ "$ATTEMPT" -ge 3 ] && break
        log_error "E160" "browser" "BROWSER_CRASH attempt $ATTEMPT — fresh context"
        mcp__plugin_playwright_playwright__browser_close 2>/dev/null || true
        sleep 2
        ;;
      *)
        [ "$ATTEMPT" -ge 2 ] && break
        log_error "E160" "unknown" "UNKNOWN error attempt $ATTEMPT"
        ;;
    esac

    ATTEMPT=$((ATTEMPT + 1))
  done

  return 1
}
```

**Strict Evidence Check (v3 --strict-evidence):**

```bash
check_strict_evidence() {
  local SCREENSHOT_PATH="$1"
  local STRICT="${STRICT_EVIDENCE:-false}"  # OFF by default per v3 spec

  [ "$STRICT" != "true" ] && return 0  # Bypass nếu không bật

  if [ ! -f "$SCREENSHOT_PATH" ]; then
    log_error "E171" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH missing — BLOCKED"
    return 1
  fi

  SIZE=$(wc -c < "$SCREENSHOT_PATH" 2>/dev/null || echo 0)
  if [ "$SIZE" -lt 1024 ]; then
    log_error "E171" "evidence" "STRICT: Screenshot $SCREENSHOT_PATH < 1KB (${SIZE} bytes) — BLOCKED"
    return 1
  fi
  return 0
}
```

---

> **End of `_shared.md`** — phase files reference từng section qua tag `§N`. v3.0 thêm §21-22 cho Phase 9-10.
