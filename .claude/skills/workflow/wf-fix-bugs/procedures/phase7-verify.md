# Phase 7: Verify & Report — wf-fix-bugs v10.17.0 (Lazy-Load Router)

> Procedure Phase 7 split thành 8 sub-files trong [`phase7-verify/`](phase7-verify/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v10.17.0 lazy-load:** Trước: 1 file 657 dòng (~6.5K tokens) load 1 lần. Sau: ~120-dòng index + group files 70-145 dòng load on-demand. Per-group context ~500-1400 tokens.
> **v10.17.0 finalize note:** Step 7.6 GIỮ NGUYÊN `finalize-phase7.sh` (special case do pre-finalize `pipeline_status=DONE` ở Step 7.5 + dual-write global trace `.mc-data/work/_trace/session-log.json`). Migration sang `phase-finalize.sh` defer (cần adapter cho 2 đặc thù trên).

## PRE-GATE (cho toàn bộ Phase 7)

```bash
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase5.status == "completed"' "$SESSION_DIR/fix-status.json"
# Phase 6 nếu non-E005: phase6.status == "completed"
```

## Input / Output Contract

| | Source |
|---|---|
| **PRE-GATE** | `fix-status.phases.phase5.status == "completed"` (Phase 6 nếu non-E005) |

| Input | Source | Purpose |
|-------|--------|---------|
| `fix-status.json` | Session root | Pipeline state, E005 flag, phase statuses |
| `phase5-triage/fix-plan.md` | Phase 5 | Expected fix counts |
| `phase5-triage/issue-registry.json` | Phase 5 | All issues + dimensions |
| `phase5-triage/Phase5-report.md` | Phase 5 | Triage summary + E005 status |
| `phase6-execute/fix-report.md` | Phase 6 (non-E005) | Actual fix results |
| `phase4-find-bugs/lanes/QD*/lane-status.json` | Phase 4 | QD9/QD10 completion evidence |
| `phase4-find-bugs/Phase4-report.md` | Phase 4 | Mobile coverage check |
| All `Phase{N}-report.md` | Phase 1-6 | phase-summary accumulation |
| `$MOBILE_MODE`, `$DIMS_ARRAY`, `$PROFILE`, `$SESSION_DIR`, `$E005_HEALTHY` | Pipeline | Flags + state |

**Output (files):** xem [`phase7-verify/POST-GATE.md`](phase7-verify/POST-GATE.md) §T1-T5.

## Execution Flow (7 Groups → POST-GATE, 8 Steps)

```
Group A: Setup Verify         (Step 7.1)   SEQUENTIAL (PRE-GATE + E005 detect + TRACE START)
    ↓
    │ (route based on E005_HEALTHY)
    │
    ├─→ E005=true → SKIP B + C → Group D (Mobile + Dashboard)
    │
    └─→ E005=false → Group B → Group C
                       ↓             ↓
                Group B: CQG-1     Group C: CQG-2 (INLINE CDG REJECT)
                       ↓             ↓
                       └─────┬───────┘
                             ↓
Group D: Mobile + Dashboard   (Step 7.4)   Script + Mobile gate WARN
    ↓
Group E: Generate 4 Reports   (Step 7.5)   Context budget check + delegated script
    ↓
Group F: Finalize Pipeline    (Step 7.6)   finalize-phase7.sh (special, dual-write trace)
    ↓
Group G: TodoWrite + Display  (Steps 7.7+7.8) ORCH UI tools (KHÔNG script được)
    ↓
POST-GATE T1-T5 Validation (includes fix-impact.json schema + audit_chain checksum)
    ↓
→ END (Pipeline DONE — user nên chạy /wf-verify-sync --from-fix-bugs)
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase7-verify/A-setup.md`](phase7-verify/A-setup.md) | 7.1 | ~85 | Ngay sau khi vào Phase 7 (PRE-GATE PASS) |
| **B** | [`phase7-verify/B-cqg1.md`](phase7-verify/B-cqg1.md) | 7.2 | ~75 | Sau Group A (E005=false only) |
| **C** | [`phase7-verify/C-cqg2-cdg.md`](phase7-verify/C-cqg2-cdg.md) | 7.3 | ~145 | Sau Group B (E005=false only) |
| **D** | [`phase7-verify/D-mobile-dashboard.md`](phase7-verify/D-mobile-dashboard.md) | 7.4 | ~80 | Sau Group C (hoặc trực tiếp từ A nếu E005) |
| **E** | [`phase7-verify/E-reports.md`](phase7-verify/E-reports.md) | 7.5 | ~115 | Sau Group D POST-GATE |
| **F** | [`phase7-verify/F-finalize.md`](phase7-verify/F-finalize.md) | 7.6 | ~75 | Sau Group E POST-GATE |
| **G** | [`phase7-verify/G-todowrite-display.md`](phase7-verify/G-todowrite-display.md) | 7.7+7.8 | ~80 | Sau Group F POST-GATE |
| **POST-GATE** | [`phase7-verify/POST-GATE.md`](phase7-verify/POST-GATE.md) | T1-T5 + cross-skill | ~95 | Cuối Phase 7, validate fix-impact.json |

**Total nếu load tất cả: ~750 dòng (vs cũ 657 monolithic).** Incremental loading: chỉ ~500-1400 tokens per group.

## Shared Protocols (lazy-load per use-site)

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/06-on-failure.md](_shared/06-on-failure.md) | All (On Failure Standard, `_phase7_trace_fail`) |
| [_shared/08-phase-summary.md](_shared/08-phase-summary.md) | E (Step 7.5 Phase Summary format) |
| [_shared/16-critical-decision-gate.md](_shared/16-critical-decision-gate.md) | C (Step 7.3 CDG REJECT) |
| [_shared/04-error-handling.md](_shared/04-error-handling.md) | All (Phase 7 codes E070-E075) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern

```
1. Đọc phase7-verify.md (file này, ~120 dòng)
2. Verify PRE-GATE
3. Đọc phase7-verify/A-setup.md → execute Step 7.1
   ├─ IF E005_HEALTHY=true: skip Groups B + C → load D directly
   └─ ELSE: continue Group B
4. Đọc phase7-verify/B-cqg1.md → execute Step 7.2 (Numeric)
5. Đọc phase7-verify/C-cqg2-cdg.md → execute Step 7.3 (INLINE CDG REJECT)
   └─ IF REJECT 2 lần: `_phase7_trace_fail "E071"` → E001 escalate
6. Đọc phase7-verify/D-mobile-dashboard.md → execute Step 7.4
7. Đọc phase7-verify/E-reports.md → execute Step 7.5 (4 Reports + context budget)
8. Đọc phase7-verify/F-finalize.md → execute Step 7.6 (finalize-phase7.sh)
9. Đọc phase7-verify/G-todowrite-display.md → execute Steps 7.7 + 7.8 (UI tools)
10. Đọc phase7-verify/POST-GATE.md → validate T1-T5 (includes fix-impact.json schema)
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- E005 branching: orchestrator skip Groups B + C nếu Step 7.1 detect E005_HEALTHY=true

## Orchestrator Role Boundary

| Orchestrator **LÀM** | Orchestrator **KHÔNG LÀM** |
|----------------------|----------------------------|
| Run CQG-1 numeric check (qua cqg1-numeric.sh) | Sửa code (Phase 7 KHÔNG có agent spawn) |
| Run CQG-2 INLINE + CDG REJECT (Group C) | Re-spawn execute agent (Phase 6 việc) |
| Finalize dashboard (qua finalize-dashboard.sh) | Bỏ qua mobile evidence check (E045) |
| Generate 4 reports (qua generate-phase7-reports.sh) | Skip fix-impact.json (CORE-036 cross-skill) |
| Validate POST-GATE T1-T5 | Advance pipeline khi POST-GATE chưa pass |
| TodoWrite + Completion Display (Group G) | (Phase 7 là phase cuối — END after G) |

**Quy tắc:** Phase 7 là phase cuối — không spawn agent, toàn bộ do orchestrator thực thi.

## Helper Scripts (v10.17.0)

| Script | Group | Lines |
|--------|-------|-------|
| `setup-verify.sh` | A (Step 7.1) | ~100 |
| `cqg1-numeric.sh` | B (Step 7.2) | ~130 |
| `finalize-dashboard.sh` | D (Step 7.4) | ~120 |
| `generate-phase7-reports.sh` | E (Step 7.5) | ~250 |
| `finalize-phase7.sh` | F (Step 7.6) | ~120 |

**Versioning:** v10.17.0 (2026-05-16) — Lazy-load split (657 dòng monolithic → ~120-dòng index + 8 group files). Step 7.6 GIỮ `finalize-phase7.sh` (special case do pre-finalize `pipeline_status=DONE` ở Step 7.5 cho CORE-036 audit_chain integrity + dual-write global trace `.mc-data/work/_trace/session-log.json`). Step 7.3 CQG-2 GIỮ INLINE CDG REJECT (CORE-027). Steps 7.7-7.8 GIỮ orchestrator-side (TodoWrite + Completion Display UI tools không script được).
