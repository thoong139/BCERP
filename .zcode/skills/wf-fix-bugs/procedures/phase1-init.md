# Phase 1: Init — wf-fix-bugs v10.14.0 (Lazy-Load Router)

> Procedure Phase 1 split thành 8 sub-files trong [`phase1-init/`](phase1-init/) — orchestrator đọc index này, sau đó load TỪNG GROUP file khi tới execution.
>
> **v10.14.0 lazy-load:** Trước: 1 file 1106 dòng (~9K tokens) load 1 lần. Sau: 80-dòng index + group files 60-150 dòng load on-demand. Per-group context ~500-1200 tokens.

## PRE-GATE (cho toàn bộ Phase 1)

```bash
test -f .claude/scripts/wf-fix-common.sh
```

## Input / Output Contract

- **Input:** Tất cả CLI arguments (`$ARGUMENTS`), `req-registry.json`, source code (`src/` hoặc `apps/`)
- **Output (files):** xem [`phase1-init/POST-GATE.md`](phase1-init/POST-GATE.md) §T1-T5
- **In-memory state truyền sang Phase 2-7:** `$SESSION_ID`, `$SESSION_DIR`, `$DIMS_ARRAY`, `$PROFILE`, `$SCOPE`, `$NAME`, `$LEGACY_MODE`, `$CI_CONTEXT`, `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$FRESHNESS_STATUS`, `$CI_ROUTE`, `$SHOW_BROWSER`, `$NO_BROWSER`, `$MOBILE_MODE`, `$MOBILE_DEVICE`, `$URL`, `$INTERFACE_TYPE`

## Execution Flow (7 Groups, 18 Steps)

```
Group A: Bootstrap          (Steps 1.1 → 1.4)        Sequential
    ↓
Group B: Wave 1 Parallel    (Steps 1.5 + 1.6 + 1.9)  PARALLEL (3 workers, 1 bash call)
    ↓
Group C: Decision           (Steps 1.7 → 1.8)        Sequential
    ↓
Group D: Session Setup      (Steps 1.10 → 1.13)      Sequential
    ↓
Group E: ISG Fast-Path      (Step 1.14)              Single
    ↓
Group F: Wave 4 Parallel    (Steps 1.15 + 1.16)      PARALLEL (2 workers, 1 bash call)
    ↓
Group G: Finalize           (Steps 1.17 → 1.18)      Sequential
    ↓
POST-GATE T1-T5 Validation
    ↓
→ Phase 2
```

## Group Routing Table (lazy-load — đọc file khi tới group)

| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| **A** | [`phase1-init/A-bootstrap.md`](phase1-init/A-bootstrap.md) | 1.1, 1.2, 1.3, 1.4 | ~115 | Ngay sau khi vào Phase 1 (PRE-GATE PASS) |
| **B** | [`phase1-init/B-wave1.md`](phase1-init/B-wave1.md) | 1.5+1.6+1.9 parallel | ~90 | Sau Group A POST-GATE PASS |
| **C** | [`phase1-init/C-decision.md`](phase1-init/C-decision.md) | 1.7, 1.8 | ~85 | Sau Group B POST-GATE PASS |
| **D** | [`phase1-init/D-session-setup.md`](phase1-init/D-session-setup.md) | 1.10, 1.11, 1.12, 1.13 | ~135 | Sau Group C POST-GATE PASS |
| **E** | [`phase1-init/E-isg.md`](phase1-init/E-isg.md) | 1.14 | ~60 | Sau Group D POST-GATE PASS |
| **F** | [`phase1-init/F-wave4.md`](phase1-init/F-wave4.md) | 1.15+1.16 parallel | ~85 | Sau Group E POST-GATE PASS |
| **G** | [`phase1-init/G-finalize.md`](phase1-init/G-finalize.md) | 1.17, 1.18 | ~75 | Sau Group F POST-GATE PASS |
| **POST-GATE** | [`phase1-init/POST-GATE.md`](phase1-init/POST-GATE.md) | T1-T5 + error ref | ~80 | Cuối Phase 1, trước khi advance Phase 2 |

**Total nếu load tất cả: ~725 dòng (vs cũ 1106 dòng).** Incremental loading: chỉ ~500-1200 tokens per group tại một thời điểm.

## Shared Protocols (lazy-load per use-site)

Mỗi group file declare TỪNG shared protocol cần dùng ở header — orchestrator chỉ load khi vào group đó. Tham khảo nhanh:

| Shared file | Dùng bởi Group |
|-------------|----------------|
| [_shared/13-lock-heartbeat.md](_shared/13-lock-heartbeat.md) | D (Step 1.11) |
| [_shared/19-bug-dashboard.md](_shared/19-bug-dashboard.md) | F (Worker 2) |
| [_shared/20-cdg-tokens.md](_shared/20-cdg-tokens.md) | D (Step 1.12 stub) |
| [_shared/07-execution-trace.md](_shared/07-execution-trace.md) | G (Step 1.17) |
| [_shared/11-task-planning.md](_shared/11-task-planning.md) | G (Step 1.18) |

**KHÔNG đọc toàn bộ `_shared/` folder.**

## Orchestrator Execution Pattern

```
1. Đọc phase1-init.md (file này, ~80 dòng)
2. Verify PRE-GATE
3. Đọc phase1-init/A-bootstrap.md → execute Steps 1.1-1.4 → Group A POST-GATE
4. Đọc phase1-init/B-wave1.md → execute Wave 1 → Group B POST-GATE
5. Đọc phase1-init/C-decision.md → execute Steps 1.7-1.8 → Group C POST-GATE
6. Đọc phase1-init/D-session-setup.md → execute Steps 1.10-1.13 → Group D POST-GATE
7. Đọc phase1-init/E-isg.md → execute Step 1.14 → Group E POST-GATE
8. Đọc phase1-init/F-wave4.md → execute Wave 4 → Group F POST-GATE
9. Đọc phase1-init/G-finalize.md → execute Steps 1.17-1.18 → Group G POST-GATE
10. Đọc phase1-init/POST-GATE.md → validate T1-T5 → advance Phase 2
```

**QUY TẮC LAZY-LOAD:**
- KHÔNG đọc trước tất cả group files — chỉ load khi tới group đó
- Mỗi group file có "Next Group" pointer ở cuối → orchestrator route theo
- Nếu skip phase hoặc context reset, có thể re-read group file riêng

## Orchestrator Role Boundary

Phase 1 chạy hoàn toàn trong orchestrator — không spawn sub-agents. Phase 1 thiết lập session cho toàn bộ phase downstream.

| Orchestrator **LÀM** | Orchestrator **KHÔNG LÀM** |
|-----------------------|-----------------------------|
| Parse CLI flags (delegate phase1-parse-flags.sh) | Chạy probe |
| CI PRE-GATE detection (Wave 1) | Mở browser |
| CDG gates (defer Phase 4) | Phân tích code |
| Session directory creation (delegate phase1-create-session.sh) | Tạo signals |
| Lock + heartbeat daemon | Fix bugs |
| Profile → dimension resolution (delegate phase1-isg-fastpath.sh) | Ghi lane outputs |
| Template population (CORE-031, qua bundle script) | Execute lane skills |
| Validate sub-skill paths (Wave 1 Worker 3, cached 24h) | Spawn sub-agents |

## Helper Scripts (v10.14.0)

| Script | Sub-step | Lines |
|--------|----------|-------|
| `phase1-parse-flags.sh` | Step 1.2 | ~110 |
| `phase1-wave1-dispatch.sh` | Group B Wave 1 | ~150 |
| `phase1-validate-paths.sh` | Wave 1 Worker 3 (cache 24h) | ~110 |
| `phase1-auto-resolve.sh` | Step 1.8 | ~95 |
| `phase1-create-session.sh` | Step 1.10 | ~80 |
| `phase1-isg-fastpath.sh` | Step 1.14 | ~110 |
| `phase1-init-bundle.sh` | Group F Wave 4 | ~110 |
| `phase1-trace-start.sh` | Step 1.17 | ~70 |

**Versioning:** v10.14.0 (2026-05-16) — Lazy-load split (1106 dòng monolithic → 80-dòng index + 8 group files, 4 new scripts extracted: parse-flags, auto-resolve, create-session, trace-start).
