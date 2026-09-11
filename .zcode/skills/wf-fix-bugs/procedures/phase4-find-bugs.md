# Phase 4: Find Bugs — wf-fix-bugs v10.18.0 (Lazy-Load Router)

> Procedure Phase 4 split thành 8 sub-files trong [`phase4-find-bugs/`](phase4-find-bugs/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v10.18.0 lazy-load:** Trước: 1 file 782 dòng (~8K tokens) load 1 lần. Sau: ~135-dòng index + group files 75-145 dòng load on-demand. Per-group context ~600-1400 tokens.
> **v10.18.0 finalize special case:** Step 4.9 GIỮ `finalize-phase4.sh` (KHÔNG migrate sang shared `phase-finalize.sh`) — lý do aggregation logic specific (signals_total từ 3 stream × N lanes, lanes_completed/failed từ filesystem, probe_failures từ log). Pattern giống Phase 7.

## PRE-GATE (cho toàn bộ Phase 4)

```bash
test -s "$SESSION_DIR/fix-status.json"
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json"
jq -e '.phases.phase3.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.dimensions | length > 0' "$SESSION_DIR/phase3-plan/dimension-plan.json"
```

## Input / Output Contract

- **Input:** `phase3-plan/{dimension-plan.json, work-plan.json}`, `fix-status.json`, `$DIMS_ARRAY`, `$PROFILE`, `$EXECUTION_MODE`, `$CI_CONTEXT`, `$SHOW_BROWSER`, `$MOBILE_MODE`, `$INTERFACE_TYPE`, `$URL`
- **Output (files):** xem [`phase4-find-bugs/POST-GATE.md`](phase4-find-bugs/POST-GATE.md) §T1-T4 — gồm `Phase4-report.md`, `phase4-summary.json` (CORE-036 schema `phase4-summary-v1`), `lanes/QD*/lane-status.json` × N
- **In-memory state truyền sang Phase 5:** `$SIGNALS_TOTAL`, `$LANES_COMPLETED`, `$LANES_FAILED`, CDG tokens accepted

## Execution Flow (8 Groups → POST-GATE, 9 Steps — v10.6 numbering preserved)

```
Group A: PRE-GATE + Setup       (Steps 4.1+4.2)   SEQUENTIAL (setup-lanes.sh)
    ↓
Group B: Browser CDG            (Step 4.3)        INLINE AskUserQuestion E090/E090b (SKIP nếu PW_LANE_COUNT=0)
    ↓
Group C: Create Lane Dirs       (Step 4.4)        SEQUENTIAL (create-lane-dirs.sh)
    ↓
Group D: Render + Verify        (Steps 4.5+4.6)   SEQUENTIAL render per dim → verify per prompt
    ↓
Group E: PARALLEL Dispatch      (Step 4.5)        INLINE N×Agent({...}) trong 1 response (CORE-025 max 10)
    ↓
Group F: Monitor + Validate     (Step 4.7)        Poll 30s + T1-T4 POST-GATE
    ↓
Group G: Report + Finalize      (Steps 4.8+4.9)   generate-phase4-report.sh + finalize-phase4.sh (special)
    ↓
POST-GATE T1-T4 Validation
    ↓
→ Phase 5 (Triage)
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase4-find-bugs/A-pregate-setup.md`](phase4-find-bugs/A-pregate-setup.md) | 4.1+4.2 | ~90 | Ngay sau khi vào Phase 4 (PRE-GATE PASS) |
| **B** | [`phase4-find-bugs/B-browser-cdg.md`](phase4-find-bugs/B-browser-cdg.md) | 4.3 | ~125 | Sau Group A (chỉ khi `PW_LANE_COUNT > 0`) |
| **C** | [`phase4-find-bugs/C-create-lanes.md`](phase4-find-bugs/C-create-lanes.md) | 4.4 | ~75 | Sau Group B (hoặc Group A nếu SKIP B) |
| **D** | [`phase4-find-bugs/D-render-verify.md`](phase4-find-bugs/D-render-verify.md) | 4.5(render) + 4.6 | ~125 | Sau Group C lane dirs created |
| **E** | [`phase4-find-bugs/E-dispatch.md`](phase4-find-bugs/E-dispatch.md) | 4.5(dispatch) | ~140 | Sau Group D tất cả prompts verified |
| **F** | [`phase4-find-bugs/F-monitor-validate.md`](phase4-find-bugs/F-monitor-validate.md) | 4.7 | ~110 | Sau Group E agents dispatched |
| **G** | [`phase4-find-bugs/G-report-finalize.md`](phase4-find-bugs/G-report-finalize.md) | 4.8+4.9 | ~100 | Sau Group F POST-GATE T1-T4 PASS |
| **POST-GATE** | [`phase4-find-bugs/POST-GATE.md`](phase4-find-bugs/POST-GATE.md) | T1-T4 + error ref | ~90 | Cuối Phase 4, trước khi advance Phase 5 |

**Total nếu load tất cả: ~990 dòng (vs cũ 782 monolithic, +27% format).** Incremental loading: chỉ ~600-1400 tokens per group.

## Shared Protocols (lazy-load per use-site)

Mỗi group file declare TỪNG shared protocol cần dùng ở header — orchestrator chỉ load khi vào group đó.

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/04-error-handling.md](_shared/04-error-handling.md) | All (Phase 4 codes E040-E049, E090/E090b) |
| [_shared/15-agent-prompts.md](_shared/15-agent-prompts.md) | D, E (Lane Agent Prompt template + dispatch contract) |
| [_shared/16-sub-probe-template.md](_shared/16-sub-probe-template.md) | D (sub-probe template cross-skill cho lane skills) |
| [_shared/18-playwright.md](_shared/18-playwright.md) | B, E (Lock-based serialization Protocol 22) |
| [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | B (CDG token persist E090/E090b) |
| [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | G (reference cho finalize pattern) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern

```
1. Đọc phase4-find-bugs.md (file này, ~135 dòng)
2. Verify PRE-GATE
3. Đọc phase4-find-bugs/A-pregate-setup.md → execute Steps 4.1+4.2 → setup-lanes.sh
   → DIMS_ARRAY + PW_LANE_COUNT
4. IF PW_LANE_COUNT > 0: đọc phase4-find-bugs/B-browser-cdg.md → execute Step 4.3 INLINE CDG
   └─ User skip → recompute DIMS_ARRAY (loại browser dims) → continue
   └─ User cancel → STOP E090/E090b
   ELSE: SKIP Group B
5. Đọc phase4-find-bugs/C-create-lanes.md → execute Step 4.4 create-lane-dirs.sh
6. Đọc phase4-find-bugs/D-render-verify.md → execute Step 4.5 (render N prompts) + Step 4.6 (verify-lane-prompt.sh per prompt)
   └─ Any verify FAIL → re-render từ template, KHÔNG sửa tay
7. Đọc phase4-find-bugs/E-dispatch.md → **CRITICAL: spawn N×Agent({subagent_type:"claude"}) trong MỘT response duy nhất** (CORE-025, max 10)
8. Đọc phase4-find-bugs/F-monitor-validate.md → execute Step 4.7 monitor-lanes.sh + validate-lane-outputs.sh
   └─ Context >90% → E009 FORCE STOP
9. Đọc phase4-find-bugs/G-report-finalize.md → execute Steps 4.8+4.9
10. Đọc phase4-find-bugs/POST-GATE.md → validate T1-T4 → advance Phase 5
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- Group B SKIP nếu `PW_LANE_COUNT == 0` → A route trực tiếp đến C

## Orchestrator Role Boundary

| Orchestrator **LÀM** | Orchestrator **KHÔNG LÀM** |
|----------------------|----------------------------|
| Spawn Agent cho từng dimension lane (Group E) | Chạy probe (static/runtime/LLM) — việc lane agent |
| Monitor `lane-status.json` qua script (Group F) | Mở browser / chạy Playwright |
| Render Browser CDG INLINE (Group B) | Phân tích code / dò bug |
| Render Lane prompts từ template (Group D) | Tự ý tạo signals.json |
| Validate POST-GATE T1-T4 qua script (Group F) | Ghi đè output của lane agent |
| Generate report + finalize (Group G) | Bỏ qua Browser CDG khi có PW lanes |

**Quy tắc:** Mọi bug detection nằm trong lane agent. Orchestrator là **điều phối viên**, không phải **người thực thi**. Nếu orchestrator tự chạy probe hoặc mở browser → vi phạm CORE-025 + CORE-037.

## Agent Dispatch Safety (CORE-025 + CORE-037)

| Aspect | Value |
|--------|-------|
| Agents | N × `wf-fix-{functional,business,security,performance,ux-a11y,data,compat,observability,runtime-health,integration,business-completeness}` |
| `subagent_type` | **`"claude"`** (chỉ "claude" có đủ MCP tools — KHÔNG dùng `developer`/`qa-lead`/...) |
| Model | `"opus"` |
| Concurrency | **Max 10** (harness limit) — N=11 → queue tự nhiên |
| Dispatch mode | **Single-response parallel** — TẤT CẢ Agent calls trong MỘT response (gửi riêng lẻ → tuần tự) |
| Writer scope | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{slug}/` — 1 file = 1 writer |
| Playwright serialization | Lane agent TỰ acquire writer-lock `playwright` qua `global-rw-lock.sh` (Protocol 22) — orchestrator KHÔNG split Wave |
| Prompt template | [`templates/phase4-find-bugs/lane-agent-prompt.md`](../../templates/phase4-find-bugs/lane-agent-prompt.md) (CORE-031 + CORE-037) |
| Timeout | 15 phút/lane (E046) |

## Helper Scripts (v10.18.0)

| Script | Group | Lines | Status |
|--------|-------|-------|--------|
| `setup-lanes.sh` | A (Step 4.2) | ~120 | Existing |
| `wf-fix-baseurl-conflict-check.sh` | B (Step 4.3 E090b) | ~80 | Existing |
| `create-lane-dirs.sh` | C (Step 4.4) | ~70 | Existing |
| `verify-lane-prompt.sh` | D (Step 4.6) | ~90 | Existing |
| `monitor-lanes.sh` | F (Step 4.7) | ~150 | Existing |
| `validate-lane-outputs.sh` | F (Step 4.7) | ~180 | Existing |
| `generate-phase4-report.sh` | G (Step 4.8) | ~220 | Existing |
| `finalize-phase4.sh` | G (Step 4.9) | ~121 | **GIỮ SPECIAL CASE** (aggregation specific) |
| `phase4-routing-smoke-test.sh` | (CI verify) | ~250 | **NEW v10.18.0** — 7 categories ~45 checks |

**Versioning:** v10.18.0 (2026-05-16) — Lazy-load split (782 dòng monolithic → ~135-dòng index + 8 group files). Step 4.9 finalize-phase4.sh GIỮ special case (aggregation logic). Pattern T6 fully validated qua TOÀN BỘ 6 phase optimizable (1, 3, 4, 5, 6, 7).
