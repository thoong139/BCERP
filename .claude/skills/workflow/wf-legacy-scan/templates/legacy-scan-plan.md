# Legacy Scan Plan

> **Muc dich:** Ke hoach chi tiet de scan va phan tich du an hien co.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-legacy-scan`
>
> **Khi viet:** Step 0.8 cua legacy-scan skill
>
> **Cap nhat:** Tu dong cap nhat sau moi stage hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Scan ID** | `[SCAN-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Project Path** | `[PROJECT_PATH]` |
| **Project Size Tier** | `SMALL / MEDIUM / LARGE` |
| **Strategy** | `[S1-S7] — [Strategy Name]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `In Progress` / `Completed` / `Error` |

---

## 1. Scope Overview

### 1.1 Project Detection Summary

| Metric | Gia tri |
|--------|---------|
| Total files | `[N]` |
| Total directories | `[N]` |
| Primary languages | `[lang1, lang2, ...]` |
| Frameworks detected | `[framework1, framework2, ...]` |
| Has existing .mc-data/ | `[YES / NO]` |
| Has existing docs | `[YES / NO]` |

### 1.2 Project Size Tier

| Tier | Dieu kien | Active | LPM | Batch Size |
|------|-----------|--------|-----|------------|
| **SMALL** | total_files < 100 | `[YES/NO]` | OFF | All-at-once |
| **MEDIUM** | 100-500 files | `[YES/NO]` | PARTIAL | 200 |
| **LARGE** | > 500 files | `[YES/NO]` | FULL | 100 |

---

## 2. Session Breakdown

### 2.1 Execution Plan

```
SESSION 1: Detection + Assessment + Inventory
├── Stage 0: Detection (DETERMINISTIC) ⏳ ~3 min
│   Status: ⬜ Pending
│   └── Output: project-profile.json (partial)
│
├── Stage 0A: Assessment (HYBRID) ⏳ ~5 min
│   Status: ⬜ Pending
│   ├── Output: assessment-report.json
│   ├── Strategy routing (S1-S7)
│   └── User confirmation (AskUserQuestion)
│
├── Stage 0.5: Maturity Validation ⏳ ~3 min
│   Status: ⬜ Pending
│   ├── Condition: co existing .mc-data/
│   └── Output: maturity scores + stage_modes
│
└── Stage 1: Inventory (DETERMINISTIC) ⏳ ~5 min
    Status: ⬜ Pending
    ├── Output: inventory/*.json
    ├── Output: ledger.json
    └── CHECKPOINT ✓
```

### 2.2 Progress Tracking

| Stage | Name | Status | Started | Completed | Output File |
|-------|------|--------|---------|-----------|-------------|
| 0 | Detection | ⬜ | — | — | project-profile.json |
| 0A | Assessment | ⬜ | — | — | assessment-report.json |
| 0.5 | Maturity Validation | ⬜ | — | — | ledger.json (maturity) |
| 1 | Inventory | ⬜ | — | — | inventory/*.json, ledger.json |

**Overall Progress:** `0% (0/4 stages completed)`

---

## 3. Strategy Routing

### 3.1 Input Signals

| Signal | Value | Source |
|--------|-------|--------|
| Has DEVKIT data | `[YES / NO]` | .mc-data/ detection |
| DEVKIT completeness | `[COMPLETE / NEAR_COMPLETE / PARTIAL / NONE]` | Stage 0.5 |
| Alignment score | `[HIGH / MEDIUM / LOW]` | Stage 0A |
| Has code | `[YES / NO]` | Stage 0 |
| Has docs | `[YES / NO]` | Stage 0 |
| --re-vision flag | `[YES / NO]` | Arguments |

### 3.2 Strategy Selection

| Strategy | Condition | Active |
|----------|-----------|--------|
| S1: FAST-TRACK | DEVKIT complete + HIGH alignment | `[YES/NO]` |
| S2: CODE-FIRST | CODE_ONLY + MED+ code | `[YES/NO]` |
| S3: DOCS-FIRST | DOCS_ONLY + HIGH docs | `[YES/NO]` |
| S4: DOCS-BRAINSTORM | DOCS_ONLY + LOW docs | `[YES/NO]` |
| S5: DIVERGENCE-RESOLVE | DEVKIT complete + LOW alignment | `[YES/NO]` |
| S6: RE-VISION | --re-vision flag | `[YES/NO]` |
| S7: FULL-REBUILD | CODE_ONLY + LOW code | `[YES/NO]` |

**Selected Strategy:** `[SN: NAME]`

---

## 4. Context Sources

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| Project directory | `[PROJECT_PATH]` | `[FOUND / NOT_FOUND]` |
| Existing .mc-data/ | `.mc-data/` | `[FOUND / NOT_FOUND / N/A]` |

### 4.2 Existing DEVKIT Data (if applicable)

| File | Status | Action |
|------|--------|--------|
| req-registry.json | `[FOUND / NOT_FOUND]` | `[VALIDATE / SKIP]` |
| Phase 1-3 docs | `[FOUND / NOT_FOUND]` | `[VALIDATE / SKIP]` |
| ledger.json | `[FOUND / NOT_FOUND]` | `[UPDATE / CREATE]` |

---

## 5. Expected Outputs

### 5.1 Output Files

| File | Stage | Description | Status |
|------|-------|-------------|--------|
| `project-profile.json` | 0+0A | Project profile + tech stack | ⬜ |
| `assessment-report.json` | 0A | Assessment scores + strategy | ⬜ |
| `inventory/screens.json` | 1 | UI screens / pages / views | ⬜ |
| `inventory/api-endpoints.json` | 1 | API route definitions | ⬜ |
| `inventory/source-files.json` | 1 | Source code inventory | ⬜ |
| `inventory/doc-files.json` | 1 | Documentation files | ⬜ |
| `inventory/dependency-graph.json` | 1 | Dependency analysis | ⬜ |
| `inventory/external-docs.json` | 1 | External docs (business, integration, infra) | ⬜ |
| `inventory/doc-classified.json` | 1 | Pre-classified docs (DOCS_ONLY only) | ⬜ |
| `inventory/ui-manifest.json` | 1 | UI manifest with route mapping (conditional — chi khi screen_count > 0) | ⬜ |
| `ledger.json` | 1 | Pipeline ledger (stages + status) | ⬜ |
| `project-context.md` | 4 | Project context cho downstream skills (CORE-021) | ⬜ |
| `doc-quality-map.json` | 4 | Doc trust assessment per document | ⬜ |
| `impl-status-snapshot.json` | 4 | Feature-level impl status (READ-ONLY — P8) | ⬜ |

### 5.2 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/legacy-scan/legacy-scan-status.json` | Runtime status tracking |
| `.mc-data/work/legacy-scan/legacy-scan-plan.md` | This file |

---

## 6. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Stage Complete | Any | Save checkpoint with stage data |

---

## 7. Notes

*[Ghi chu them ve scan, cac diem can luu y, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-legacy-scan` skill.*
