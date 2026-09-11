# Module Planning Plan

> **Mục đích:** Kế hoạch chi tiết để phân tích dependencies và xác định thứ tự implement modules.
>
> **Ai viết:** AI tự động generate khi chạy `/wf-plan-modules`
>
> **Khi viết:** Phase 1 của plan-modules skill
>
> **Cập nhật:** Tự động cập nhật sau mỗi phase hoàn thành

---

## Meta Information

| Mục | Giá trị |
|-----|---------|
| **PlanMod ID** | `[PLANMOD-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Mode** | `simple` / `lite` / `full` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `🔄 In Progress` / `✅ Completed` / `❌ Error` |
| **Session** | `[N]` |

---

## 1. Registry Overview

| Mục | Giá trị |
|-----|---------|
| **Total Modules** | `[COUNT]` |
| **Total Systems** | `[COUNT]` |
| **Mode** | `simple (1 module)` / `lite (2 modules)` / `full (3+ modules)` |
| **Registry Status** | `[VALID / INVALID]` |

### 1.1 Modules Found

| # | Module | System | Features | Dependencies |
|---|--------|--------|----------|-------------|
| 1 | `[MODULE_1]` | `[SYSTEM_1]` | `[COUNT]` | `[DEP_LIST or NONE]` |
| 2 | `[MODULE_2]` | `[SYSTEM_2]` | `[COUNT]` | `[DEP_LIST or NONE]` |
| ... | ... | ... | ... | ... |

---

## 2. Arguments & Mode

### 2.1 Arguments Parsed

| Flag | Value | Active |
|------|-------|--------|
| `--graph` | Chỉ xuất dependency graph | `[YES/NO]` |
| `--mvp` | Xác định MVP scope | `[YES/NO]` |
| `--impact=<module>` | Phân tích impact module | `[MODULE or N/A]` |
| `--skip-sprints` | Bỏ qua tạo sprint plans | `[YES/NO]` |

### 2.2 Execution Mode

| Mode | Description | Active |
|------|-------------|--------|
| **Simple** | 1 module — roadmap đơn giản, 1 sprint, bỏ qua dependency graph | `[YES/NO]` |
| **Lite** | 2 modules — dependency check, 1-2 sprints | `[YES/NO]` |
| **Full** | 3+ modules — full dependency graph, topological sort, multi-sprint | `[YES/NO]` |

---

## 3. Phase Plan

### 3.1 Session Breakdown

```
SESSION 1: Analysis & Planning
├── Phase 1: Registry Validation ⏳ ~2 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Output: planmod-plan.md (this file)
│   Checkpoint: YES
│
├── Phase 2: Thu thập Dependencies (Parallel) ⏳ ~5-10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed / ⏭️ Skipped
│   Condition: Skipped when mode == simple or lite
│   Checkpoint: YES
│
├── Phase 3: Phát hiện Circular Dependencies ⏳ ~3 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed / ⏭️ Skipped
│   Condition: Skipped when mode == simple or lite
│   Action: Dừng và chờ user chọn giải pháp nếu có cycle
│   Checkpoint: YES
│
└── Phase 4: Topological Sorting ⏳ ~3 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    Checkpoint: YES

SESSION 2 (Optional): Conditional Phases
├── Phase 5: MVP Scope (Conditional) ⏳ ~3 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed / ⏭️ Skipped
│   Condition: Only runs when --mvp flag set
│
├── Phase 6: Impact Analysis (Conditional) ⏳ ~3 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed / ⏭️ Skipped
│   Condition: Only runs when --impact=<module> flag set
│
SESSION N: Output Generation
└── Phase 7: Tạo Output Files ⏳ ~5-10 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    ├── 7.1: mkdir output directories (phase5-implementation/sprints/)
    ├── 7.2: Ghi module-plan.md
    ├── 7.3: Ghi dependency-graph.md (Mermaid)
    ├── 7.4: Update req-registry.json (implementation_order)
    ├── 7.5: Ghi P5-00-implementation-roadmap.md
    ├── 7.6: Ghi sprints/S01-foundation.md (skip nếu --skip-sprints)
    ├── 7.7: Ghi sprints/S02+ (nếu cần)
    └── 7a: Output Verification (auto-correction loop, max 3 iterations)
    Checkpoint: YES (final)
```

### 3.2 Progress Tracking

| Phase | Name | Status | Started | Completed |
|-------|------|--------|---------|-----------|
| 1 | Registry Validation | ⬜ | — | — |
| 2 | Thu thập Dependencies | ⬜ / ⏭️ | — | — |
| 3 | Phát hiện Circular Dependencies | ⬜ / ⏭️ | — | — |
| 4 | Topological Sorting | ⬜ | — | — |
| 5 | MVP Scope | ⬜ / ⏭️ | — | — |
| 6 | Impact Analysis | ⬜ / ⏭️ | — | — |
| 7 | Tạo Output Files | ⬜ | — | — |

**Overall Progress:** `0% (0/7 phases completed)`

---

## 4. Dependency Analysis (Full Mode)

### 4.1 Dependency Matrix

| Module | Depends On | Depended By |
|--------|-----------|-------------|
| `[MODULE_1]` | `[NONE]` | `[MODULE_2, MODULE_3]` |
| `[MODULE_2]` | `[MODULE_1]` | `[MODULE_4]` |
| ... | ... | ... |

### 4.2 Circular Dependencies

| # | Cycle | Status | Solution |
|---|-------|--------|----------|
| — | *Không có circular dependency* | ✅ | — |

---

## 5. Layer Assignment

| Layer | Phase | Modules | Parallel? | Status |
|-------|-------|---------|-----------|--------|
| 0 | Foundation | `[MODULES]` | ✅ | ⬜ |
| 1 | Core | `[MODULES]` | ✅ | ⬜ |
| 2 | Business | `[MODULES]` | ✅ | ⬜ |
| 3 | Operations | `[MODULES]` | ✅ | ⬜ |
| 4 | Intelligence | `[MODULES]` | ✅ | ⬜ |

**Modules Assigned:** `0 / [TOTAL]`

---

## 6. Expected Outputs

### 6.1 Output Files

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `module-plan.md` | 7.2 | Implementation plan với layers | ⬜ |
| `dependency-graph.md` | 7.3 | Mermaid diagram visualization | ⬜ |
| `P5-00-implementation-roadmap.md` | 7 | Phase 3 roadmap | ⬜ |
| `sprints/S01-foundation.md` | 7 | Sprint 1 plan | ⬜ |
| `sprints/S02-*.md` | 7 | Sprint plans tiếp theo | ⬜ |

### 6.2 Registry Updates

| Section | Action | Detail |
|---------|--------|--------|
| `implementation_order` | ADD/UPDATE | Layer assignments + sprint mapping |

### 6.3 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/wf-plan-modules/planmod-status.json` | Runtime status tracking |
| `.mc-data/work/wf-plan-modules/planmod-plan.md` | This file |
| `.mc-data/work/wf-plan-modules/checkpoint.json` | Checkpoint for resume |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase Complete | Any | Save checkpoint with phase data |
| Cycle Detected | Phase 3 | Save checkpoint, wait user decision |

---

## 8. Notes

*[Ghi chú thêm về module planning, các điểm cần lưu ý, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-plan-modules` skill.*
