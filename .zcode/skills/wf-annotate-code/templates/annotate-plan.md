# Annotate Plan

> **Muc dich:** Ke hoach inject REQ-ID comments vao code files hien co.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-annotate-code`
>
> **Khi viet:** Phase 0 cua annotate skill
>
> **Cap nhat:** Tu dong cap nhat sau moi phase/batch hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Annotate ID** | `[ANNOTATE-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Maturity Level** | `[CODE_ONLY / CODE_PLUS_* / NEAR_COMPLETE]` |
| **Module Filter** | `[ALL / module_name]` |
| **Batch Size** | `[50]` |
| **Dry Run** | `[YES / NO]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `🔄 In Progress` / `✅ Completed` / `❌ Error` |

---

## 1. Scope Overview

### 1.1 Annotation Scope

| Metric | Gia tri |
|--------|---------|
| Total code files (project) | `[N]` |
| Files co REQ-ID (hien tai) | `[N]` |
| Traceability score (hien tai) | `[N]%` |
| Files can annotate (tu mapping) | `[N]` |
| REQ-IDs can inject | `[N]` |
| FEAT-IDs can inject | `[N]` |
| Modules affected | `[N]` |

### 1.2 Module Breakdown

| # | Module | Code Directory | Files | REQ-IDs | Status |
|---|--------|---------------|-------|---------|--------|
| 1 | `[MODULE_1]` | `[path]` | `[N]` | `[N]` | ⬜ Pending |
| 2 | `[MODULE_2]` | `[path]` | `[N]` | `[N]` | ⬜ Pending |

---

## 2. Session Breakdown

### 2.1 Execution Plan

```
SESSION 1: Context & Map Building
├── Phase 0: Context Loading & Mode Detection ⏳ ~2 min
│   Status: ⬜ Pending
│
├── Phase 1: Build Annotation Map ⏳ ~5 min
│   Status: ⬜ Pending
│   └── Output: annotation-map.json
│
└── Phase 2: Review & Confirm ⏳ ~3 min
    Status: ⬜ Pending
    └── [DRY-RUN stops here]

SESSION 2+: Injection (Resumable per batch)
├── Phase 3: Inject Annotations ⏳ ~[N] min
│   Status: ⬜ Pending
│   ├── Batch 1: files [1-50] → CHECKPOINT ✓
│   ├── Batch 2: files [51-100] → CHECKPOINT ✓
│   └── Batch N: files [...] → CHECKPOINT ✓
│
└── Phase 4: Verify & Report ⏳ ~5 min
    Status: ⬜ Pending
    └── Output: annotation-report.md
    └── CHECKPOINT ✓
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output File |
|-------|------|--------|---------|-----------|-------------|
| 0 | Context Loading & Mode Detection | ⬜ | — | — | — |
| 1 | Build Annotation Map | ⬜ | — | — | annotation-map.json |
| 2 | Review & Confirm | ⬜ | — | — | annotation-map.json (updated) |
| 3 | Inject Annotations | ⬜ | — | — | code files |
| 4 | Verify & Report | ⬜ | — | — | annotation-report.md |

**Overall Progress:** `0% (0/5 phases completed)`

---

## 3. Batch Planning

### 3.1 Batch Breakdown

| Batch | Files | Module(s) | Est. Time | Status |
|-------|-------|-----------|-----------|--------|
| 1 | `[file_1, ..., file_50]` | `[modules]` | ~5 min | ⬜ Pending |
| 2 | `[file_51, ..., file_100]` | `[modules]` | ~5 min | ⬜ Pending |

**Batches Progress:** `0/[N] (0%)`

### 3.2 Comment Format Distribution

| Ngon ngu | Files | Format |
|----------|-------|--------|
| TypeScript/JavaScript | `[N]` | `// REQ-ID: ...` |
| Python | `[N]` | `# REQ-ID: ...` |
| HTML/Vue | `[N]` | `<!-- REQ-ID: ... -->` |
| CSS/SCSS | `[N]` | `/* REQ-ID: ... */` |
| Other | `[N]` | `// REQ-ID: ...` |

---

## 4. Context Sources

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| ledger.json | `.mc-data/work/legacy-scan/ledger.json` | `[FOUND / NOT_FOUND]` |
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| module-code-mapping.json | `.mc-data/work/legacy-scan/module-code-mapping.json` | `[FOUND / NOT_FOUND]` |
| gap-report.md | `.mc-data/work/legacy-scan/gap-report.md` | `[FOUND / NOT_FOUND]` |
| project-profile.json | `.mc-data/work/legacy-scan/project-profile.json` | `[FOUND / NOT_FOUND]` |

### 4.2 Gap Report Annotation Gaps

| # | REQ-ID | Category | File(s) | Priority |
|---|--------|----------|---------|----------|
| 1 | `[REQ-XXX-001]` | annotation_gap | `[file_path]` | HIGH |
| 2 | `[REQ-XXX-002]` | annotation_gap | `[file_path]` | MEDIUM |

---

## 5. Expected Outputs

### 5.1 Files Modified

| Type | Count | Location |
|------|-------|----------|
| Code files (annotated) | `[N]` | Project source directories |
| annotation-map.json | 1 | `.mc-data/work/legacy-scan/` |
| annotation-report.md | 1 | `.mc-data/work/legacy-scan/` |

### 5.2 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/legacy-scan/annotate-status.json` | Runtime status tracking |
| `.mc-data/work/legacy-scan/annotate-plan.md` | This file |
| `.mc-data/work/legacy-scan/annotate-checkpoint.json` | Checkpoint for resume |

---

## 6. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Batch Complete | Any | Save checkpoint with batch data |

---

## 7. Notes

*[Ghi chu them ve annotation, cac file can luu y dac biet, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-annotate-code` skill.*
