# Extract Plan

> **Muc dich:** Ke hoach trich xuat requirements va features tu classified modules.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-legacy-extract`
>
> **Khi viet:** Phase 0 cua extract skill
>
> **Cap nhat:** Tu dong cap nhat sau moi module hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Extract ID** | `[EXTRACT-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Module Filter** | `[ALL / module_name]` |
| **Total Modules** | `[N]` |
| **Maturity Mode** | `full / delta / skip` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `In Progress` / `Completed` / `Error` |

---

## 1. Scope Overview

### 1.1 Module Breakdown

| # | Module | Files | Dependencies | Domain Expert | Priority | Status |
|---|--------|-------|-------------|---------------|----------|--------|
| 1 | `[MODULE_1]` | `[N]` | `[deps]` | `[expert-name]` | `[HIGH/MEDIUM/LOW]` | ⬜ Pending |
| 2 | `[MODULE_2]` | `[N]` | `[deps]` | `[expert-name]` | `[HIGH/MEDIUM/LOW]` | ⬜ Pending |

### 1.2 Extraction Metrics (du kien)

| Metric | Gia tri |
|--------|---------|
| Total modules | `[N]` |
| Estimated requirements | `[N]` |
| Estimated features | `[N]` |
| Confidence threshold | `[0.7]` |

---

## 2. Session Breakdown

### 2.1 Execution Plan

```
SESSION 1: Context + Extraction
├── Phase 0: Context Loading ⏳ ~3 min
│   Status: ⬜ Pending
│   └── Output: extract-plan.md (this file)
│
├── Stage 3: Extract Requirements & Features ⏳ ~[N] min
│   Status: ⬜ Pending
│   ├── [PARALLEL GROUP A — max 3 agents]
│   │   ├── Module 1: [MODULE_1] → CHECKPOINT ✓
│   │   ├── Module 2: [MODULE_2] → CHECKPOINT ✓
│   │   └── Module 3: [MODULE_3] → CHECKPOINT ✓
│   │
│   ├── [PARALLEL GROUP B — max 3 agents]
│   │   ├── Module 4: [MODULE_4] → CHECKPOINT ✓
│   │   └── Module 5: [MODULE_5] → CHECKPOINT ✓
│   │
│   ├── Dedup Pass ⏳ ~3 min
│   │   └── Output: dedup-report.json
│   │
│   └── Stage 3.5: Module-Code Alignment ⏳ ~5 min
│       └── Output: module-code-mapping.json
│
└── Post-Stage Verification ⏳ ~3 min
    Status: ⬜ Pending
    └── Auto-fix max 3 iterations
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output File |
|-------|------|--------|---------|-----------|-------------|
| 0 | Context Loading | ⬜ | — | — | extract-plan.md |
| 3 | Extract Modules | ⬜ | — | — | extracted/*.json |
| 3-D | Dedup Pass | ⬜ | — | — | dedup-report.json |
| 3.5 | Module-Code Alignment | ⬜ | — | — | module-code-mapping.json |
| V | Post-Stage Verification | ⬜ | — | — | — |

**Overall Progress:** `0% (0/5 phases completed)`

---

## 3. Module Parallelization Plan

### 3.1 Topological Order

| Order | Module | Dependencies | Parallel Group |
|-------|--------|-------------|----------------|
| 1 | `[MODULE_1]` | None | A |
| 2 | `[MODULE_2]` | None | A |
| 3 | `[MODULE_3]` | None | A |
| 4 | `[MODULE_4]` | `[MODULE_1]` | B |
| 5 | `[MODULE_5]` | `[MODULE_2]` | B |

### 3.2 Parallel Groups

| Group | Modules | Max Agents | Est. Time |
|-------|---------|------------|-----------|
| A | `[MOD_1, MOD_2, MOD_3]` | 3 | ~10 min |
| B | `[MOD_4, MOD_5]` | 2 | ~8 min |

---

## 4. Agent Assignment

### 4.1 Domain Expert Selection

| Module | Primary Agent | Domain Expert | Rationale |
|--------|--------------|---------------|-----------|
| `[MODULE_1]` | `business-analyst` | `[domain-expert]` | `[domain match]` |
| `[MODULE_2]` | `business-analyst` | `[domain-expert]` | `[domain match]` |

### 4.2 Execution Strategy

| Dieu kien | Che do |
|-----------|--------|
| Modules doc lap | PARALLEL (max 3) |
| Modules co dependency | SEQUENTIAL (theo topological order) |
| Dedup pass | SEQUENTIAL (sau tat ca modules) |
| Stage 3.5 alignment | SEQUENTIAL (sau dedup) |

---

## 5. Context Sources

### 5.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| ledger.json | `.mc-data/work/legacy-scan/ledger.json` | `[FOUND / NOT_FOUND]` |
| project-profile.json | `.mc-data/work/legacy-scan/project-profile.json` | `[FOUND / NOT_FOUND]` |
| dependency-graph.json | `.mc-data/work/legacy-scan/inventory/dependency-graph.json` | `[FOUND / NOT_FOUND]` |
| glossary.json | `.mc-data/work/legacy-scan/glossary.json` | `[FOUND / NOT_FOUND]` |
| classified/*.json | `.mc-data/work/legacy-scan/classified/` | `[FOUND / NOT_FOUND]` |

---

## 6. Expected Outputs

### 6.1 Extraction Files

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `extracted/[module].json` | 3 | Requirements + features per module | ⬜ |
| `dedup-report.json` | 3-D | Cross-module deduplication results | ⬜ |
| `module-code-mapping.json` | 3.5 | Module-to-code directory mapping | ⬜ |

### 6.2 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/legacy-scan/extract-status.json` | Runtime status tracking |
| `.mc-data/work/legacy-scan/extract-plan.md` | This file |
| `.mc-data/work/legacy-scan/extract-checkpoint.json` | Checkpoint for resume |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Module Complete | Any | Save checkpoint with module data |

---

## 8. Notes

*[Ghi chu them ve extraction, confidence thresholds, domain-specific notes, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-legacy-extract` skill.*
