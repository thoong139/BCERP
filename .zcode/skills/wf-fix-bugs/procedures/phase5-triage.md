# Phase 5: Classify & Triage — wf-fix-bugs v10.17.0 (Lazy-Load Router)

> Procedure Phase 5 split thành 8 sub-files trong [`phase5-triage/`](phase5-triage/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v10.17.0 lazy-load:** Trước: 1 file 648 dòng (~7K tokens) load 1 lần. Sau: ~135-dòng index + group files 75-140 dòng load on-demand. Per-group context ~500-1300 tokens.
> **v10.17.0 shared trace:** Step 5.10 migrate từ `finalize-phase5.sh` sang `phase-finalize.sh` (shared cho Phase 2-7).

## PRE-GATE (cho toàn bộ Phase 5)

```bash
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase4.status == "completed"' "$SESSION_DIR/fix-status.json"
```

## Input / Output Contract

- **Input:** `lanes/QD*/{static-scan,runtime,llm-scan}/signals.json`, `fix-status.json`, `phase3-plan/work-plan.json`, `$DRY_RUN`, `$CI_CONTEXT`, `$PROFILE`, `$SCOPE`, `$LEGACY_MODE`
- **Output (files):** xem [`phase5-triage/POST-GATE.md`](phase5-triage/POST-GATE.md) §T1-T4
- **In-memory state truyền sang Phase 6:** `$TOTAL_ISSUES`, CDG tokens accepted, fix-plan ready

## Execution Flow (7 Groups → POST-GATE, 10 Steps)

```
Group A: Setup              (Step 5.1)        SEQUENTIAL (E005 healthy → jump Phase 7)
    ↓
Group B: Aggregate + PI     (Steps 5.2+5.3)   SEQUENTIAL (scripts delegated)
    ↓
Group C: CDG Critical       (Step 5.4)        INLINE AskUserQuestion CONTINUE/ABORT
    ↓
Group D: Spawn Triage Agent (Step 5.5)        INLINE Agent({...}) call (CORE-037)
    ↓
Group E: Validate + Handoff (Steps 5.6+5.7)   POST-GATE + INLINE CDG Pre-Execute
    ↓
Group F: Safety Check       (Step 5.8)        Script + INLINE CDG nếu blockers
    ↓
Group G: Reports + Finalize (Steps 5.9+5.10)  3 Reports + phase-finalize.sh
    ↓
POST-GATE T1-T4 Validation
    ↓
→ Phase 6 (hoặc Phase 7 nếu E005 jump từ Group A)
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase5-triage/A-setup.md`](phase5-triage/A-setup.md) | 5.1 | ~85 | Ngay sau khi vào Phase 5 (PRE-GATE PASS) |
| **B** | [`phase5-triage/B-aggregate.md`](phase5-triage/B-aggregate.md) | 5.2+5.3 | ~95 | Sau Group A POST-GATE (không E005) |
| **C** | [`phase5-triage/C-cdg-critical.md`](phase5-triage/C-cdg-critical.md) | 5.4 | ~80 | Sau Group B PI check (xử lý critical) |
| **D** | [`phase5-triage/D-spawn-triage.md`](phase5-triage/D-spawn-triage.md) | 5.5 | ~135 | Sau Group C (pipeline not aborted) |
| **E** | [`phase5-triage/E-validate-handoff.md`](phase5-triage/E-validate-handoff.md) | 5.6+5.7 | ~120 | Sau Group D (agent completed) |
| **F** | [`phase5-triage/F-safety-check.md`](phase5-triage/F-safety-check.md) | 5.8 | ~80 | Sau Group E CDG ACCEPT |
| **G** | [`phase5-triage/G-reports-finalize.md`](phase5-triage/G-reports-finalize.md) | 5.9+5.10 | ~80 | Sau Group F (no blockers) |
| **POST-GATE** | [`phase5-triage/POST-GATE.md`](phase5-triage/POST-GATE.md) | T1-T4 + error ref | ~75 | Cuối Phase 5, trước khi advance Phase 6 |

**Total nếu load tất cả: ~750 dòng (vs cũ 648 monolithic).** Incremental loading: chỉ ~500-1300 tokens per group.

## Shared Protocols (lazy-load per use-site)

Mỗi group file declare TỪNG shared protocol cần dùng ở header — orchestrator chỉ load khi vào group đó.

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/04-error-handling.md](_shared/04-error-handling.md) | All (Phase 5 codes E050-E059) |
| [_shared/16-critical-decision-gate.md](_shared/16-critical-decision-gate.md) | C, E, F (CDG render pattern) |
| [_shared/15-agent-prompts.md](_shared/15-agent-prompts.md) | D (Step 5.5 Triage Agent prompt template) |
| [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | E (Step 5.7 CDG-PRE-EXECUTE token append) |
| [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | G (reference for finalize pattern) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern

```
1. Đọc phase5-triage.md (file này, ~135 dòng)
2. Verify PRE-GATE
3. Đọc phase5-triage/A-setup.md → execute Step 5.1
   ├─ IF E005 healthy (RC=5): jump Phase 7 (procedures/phase7-verify.md), SKIP B-G
   └─ ELSE: continue Group B
4. Đọc phase5-triage/B-aggregate.md → execute Steps 5.2+5.3 → check PI critical count
5. Đọc phase5-triage/C-cdg-critical.md → execute Step 5.4 (INLINE CDG nếu critical>0)
   └─ IF ABORT: stop pipeline
6. Đọc phase5-triage/D-spawn-triage.md → execute Step 5.5 (INLINE Agent spawn)
7. Đọc phase5-triage/E-validate-handoff.md → execute Steps 5.6+5.7 (POST-GATE + INLINE CDG)
   └─ IF REJECT lần 3: ESCALATE
8. Đọc phase5-triage/F-safety-check.md → execute Step 5.8 (script + INLINE CDG nếu blockers)
9. Đọc phase5-triage/G-reports-finalize.md → execute Steps 5.9+5.10
10. Đọc phase5-triage/POST-GATE.md → validate T1-T4 → advance Phase 6
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- E005 healthy branching: Group A exit 5 → SKIP B-G → route trực tiếp Phase 7

## Orchestrator Role Boundary

| Orchestrator **LÀM** | Orchestrator **KHÔNG LÀM** |
|----------------------|----------------------------|
| Aggregate + dedup signals (qua aggregate-and-spot-check.sh) | Phân loại severity (việc của triage agent) |
| Run PI1-PI5 process integrity (qua process-integrity-check.sh) | Đề xuất fix strategy |
| Render CDG INLINE (Groups C, E, F) | Bỏ qua safety check (CORE-020) |
| Spawn `wf-fix-triage` INLINE Agent({...}) | Ghi đè output triage agent |
| Validate POST-GATE T1-T4 (qua validate-triage-outputs.sh) | Bắt đầu Phase 6 khi POST-GATE chưa pass |
| Generate dashboard + reports (qua generate-phase5-reports.sh) | Bỏ qua E005 healthy path (N=0) |

**Quy tắc:** Orchestrator aggregate, validate, hand off — KHÔNG tự classify hay fix.

## Agent Dispatch Safety (CORE-025)

| Aspect | Value |
|--------|-------|
| Agent | `wf-fix-triage` (subagent_type="claude", model="opus") |
| Concurrency | 1 (sequential — chỉ 1 triage agent) |
| Writer scope | `$SESSION_DIR/phase5-triage/{bug-triage.md, fix-plan.md, fix-log.json}` |
| Prompt template | [`_shared/15-agent-prompts.md` — Triage Agent (Phase 5)](_shared/15-agent-prompts.md#triage-agent-prompt-phase-5) (8 sections CORE-037) |
| CI context | Inject từ Phase 1 PRE-GATE Step Nc |
| Timeout | 15 phút |
| Re-spawn on fail | Max 1 lần (E053), budget tổng 3 retries/phase (CORE-034) |

## Helper Scripts (v10.17.0)

| Script | Group | Lines |
|--------|-------|-------|
| `setup-triage.sh` | A (Step 5.1) | ~80 |
| `aggregate-and-spot-check.sh` | B (Step 5.2) | ~150 |
| `process-integrity-check.sh` | B (Step 5.3) | ~120 |
| `validate-triage-outputs.sh` | E (Step 5.6) | ~110 |
| `safety-check.sh` | F (Step 5.8) | ~140 |
| `generate-phase5-reports.sh` | G (Step 5.9) | ~180 |
| `phase-finalize.sh` (shared) | G (Step 5.10) | ~110 |

**Versioning:** v10.17.0 (2026-05-16) — Lazy-load split (648 dòng monolithic → ~135-dòng index + 8 group files). Step 5.10 migrate từ `finalize-phase5.sh` (still exists for backward-compat) sang shared `phase-finalize.sh`.
