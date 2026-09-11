# Phase 3: Plan — wf-fix-bugs v10.16.0 (Lazy-Load Router)

> Procedure Phase 3 split thành 7 sub-files trong [`phase3-plan/`](phase3-plan/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v10.16.0 lazy-load:** Trước: 1 file 515 dòng (~5K tokens) load 1 lần. Sau: 80-dòng index + group files 50-150 dòng load on-demand. Per-group context ~500-1000 tokens.
> **v10.16.0 shared trace:** Steps 3.2 + 3.7 migrate sang `phase-trace-start.sh` + `phase-finalize.sh` (shared cho Phase 2-7).

## PRE-GATE (cho toàn bộ Phase 3)

```bash
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase2.status == "completed"' "$SESSION_DIR/fix-status.json"
```

## Input / Output Contract

- **Input:** `fix-status.json`, `phase2-scan/{scope-analysis,code-inventory,doc-inventory}.json`, `$DIMS_ARRAY`, `$PROFILE`, `$SCOPE`, `$INTERFACE_TYPE`, `$MOBILE_MODE`
- **Output (files):** xem [`phase3-plan/POST-GATE.md`](phase3-plan/POST-GATE.md) §T1-T4
- **In-memory state truyền sang Phase 4:** `$EXECUTION_MODE`, `$AGENT_COUNT`, `$REFINED_DIMS`, `$WORKLOAD_COUNT`, `$PW_MODE`

## Execution Flow (6 Groups, 7 Steps)

```
Group A: PRE-GATE + TRACE START (Steps 3.1 → 3.2)        Sequential
    ↓
Group B: ISG + Partition         (Step 3.3)              Sequential (script delegated)
    ↓
Group C: Workload Gate CDG-11    (Step 3.4)              INLINE AskUserQuestion
    ↓
Group D: Route + Write           (Step 3.5)              Sequential (script delegated)
    ↓
Group E: Phase Report            (Step 3.6)              Sequential (script delegated)
    ↓
Group F: Finalize                (Step 3.7)              Sequential (phase-finalize.sh)
    ↓
POST-GATE T1-T4 Validation
    ↓
→ Phase 4
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase3-plan/A-pregate-trace.md`](phase3-plan/A-pregate-trace.md) | 3.1, 3.2 | ~60 | Ngay sau khi vào Phase 3 (PRE-GATE PASS) |
| **B** | [`phase3-plan/B-isg-partition.md`](phase3-plan/B-isg-partition.md) | 3.3 | ~90 | Sau Group A POST-GATE PASS |
| **C** | [`phase3-plan/C-workload-gate.md`](phase3-plan/C-workload-gate.md) | 3.4 | ~110 | Sau Group B POST-GATE PASS |
| **D** | [`phase3-plan/D-route-write.md`](phase3-plan/D-route-write.md) | 3.5 | ~80 | Sau Group C POST-GATE PASS |
| **E** | [`phase3-plan/E-report.md`](phase3-plan/E-report.md) | 3.6 | ~60 | Sau Group D POST-GATE PASS |
| **F** | [`phase3-plan/F-finalize.md`](phase3-plan/F-finalize.md) | 3.7 | ~50 | Sau Group E POST-GATE PASS |
| **POST-GATE** | [`phase3-plan/POST-GATE.md`](phase3-plan/POST-GATE.md) | T1-T4 + error ref | ~70 | Cuối Phase 3, trước khi advance Phase 4 |

**Total nếu load tất cả: ~520 dòng (≈ cũ 515 dòng).** Incremental loading: chỉ ~500-1000 tokens per group tại một thời điểm.

## Shared Protocols (lazy-load per use-site)

Mỗi group file declare TỪNG shared protocol cần dùng ở header — orchestrator chỉ load khi vào group đó. Tham khảo nhanh:

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/16-critical-decision-gate.md](_shared/16-critical-decision-gate.md) | C (Step 3.4 CDG-11) |
| [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | C (Step 3.4 CDG token format) |
| [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | F (reference for finalize pattern) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern

```
1. Đọc phase3-plan.md (file này, ~80 dòng)
2. Verify PRE-GATE
3. Đọc phase3-plan/A-pregate-trace.md → execute Steps 3.1-3.2 → Group A POST-GATE
4. Đọc phase3-plan/B-isg-partition.md → execute Step 3.3 → Group B POST-GATE
5. Đọc phase3-plan/C-workload-gate.md → execute Step 3.4 (INLINE CDG) → Group C POST-GATE
6. Đọc phase3-plan/D-route-write.md → execute Step 3.5 → Group D POST-GATE
7. Đọc phase3-plan/E-report.md → execute Step 3.6 → Group E POST-GATE
8. Đọc phase3-plan/F-finalize.md → execute Step 3.7 → Group F POST-GATE
9. Đọc phase3-plan/POST-GATE.md → validate T1-T4 → advance Phase 4
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- Nếu skip phase hoặc context reset, có thể re-read group file riêng

## Orchestrator Role Boundary

Phase 3 là **planning phase** — orchestrator tự thực thi, KHÔNG spawn agent.

| LÀM | KHÔNG LÀM |
|-----|-----------|
| Chạy ISG + Partition (qua `plan-isg-partition.sh`) | Spawn agent phân tích / probe |
| Tính Workload Gate ratio + gọi CDG-11 INLINE | Tự ý đổi workload partition |
| Quyết định `$EXECUTION_MODE` | Spawn lane agent (Phase 4) |
| Lập Playwright slot reservation | Mở browser / chạy Playwright |
| Viết work-plan.json, dimension-plan.json (qua `route-and-write.sh`) | Ghi đè output Phase 2 |
| Viết Phase3-report.md (CORE-028 via `generate-phase3-report.sh`) | Tự tạo template mới |

## Helper Scripts (v10.16.0)

| Script | Group | Lines |
|--------|-------|-------|
| `phase-trace-start.sh` (shared) | A (Step 3.2) | ~70 |
| `plan-isg-partition.sh` | B (Step 3.3) | ~95 |
| `route-and-write.sh` | D (Step 3.5) | ~140 |
| `generate-phase3-report.sh` | E (Step 3.6) | ~75 |
| `phase-finalize.sh` (shared) | F (Step 3.7) | ~110 |

**Versioning:** v10.16.0 (2026-05-16) — Lazy-load split (515 dòng monolithic → 80-dòng index + 7 group files). Steps 3.2 + 3.7 migrate sang shared trace scripts (theo ROLLOUT-PLAN v10.15).
