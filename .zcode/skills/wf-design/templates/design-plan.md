# Design Plan

> **Muc dich:** Ke hoach chi tiet de thiet ke kien truc ky thuat cho he thong/module.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-design`
>
> **Khi viet:** Phase 1 cua design skill
>
> **Cap nhat:** Tu dong cap nhat sau moi phase hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Design ID** | `[DESIGN-YYYYMMDD-NNN]` |
| **Scope** | `[platform / system / module]` |
| **Target** | `[System Name / Module Name]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `🔄 In Progress` / `✅ Completed` / `❌ Error` |
| **Context** | `new` / `onboard` |

---

## 1. Scope Overview

### 1.1 Design Type

| Type | Description | Active |
|------|-------------|--------|
| **Platform Design** | Thiet ke multi-system platform (> 1 system) | `[YES/NO]` |
| **System Design** | Thiet ke single system (1 system, > 2 modules) | `[YES/NO]` |
| **Module Design** | Thiet ke single module (1 system, 1-2 modules) | `[YES/NO]` |

### 1.2 Target Systems/Modules

| # | System | Modules | Priority | Status |
|---|--------|---------|----------|--------|
| 1 | `[SYSTEM_1]` | `[MOD_1, MOD_2, ...]` | `[HIGH/MEDIUM/LOW]` | ⬜ Pending |
| 2 | `[SYSTEM_2]` | `[...]` | `[...]` | ⬜ Pending |
| ... | ... | ... | ... | ... |

---

## 2. Session Breakdown

### 2.1 Multi-Session Architecture

```
SESSION 1: Context & Planning
├── Phase 0: Context Loading ⏳ ~2 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│
└── Phase 1: Registry Validation & Approach ⏳ ~5 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    └── Output: design-plan.md (this file)

SESSION 2+: Design Execution (Resumable)
├── Phase 2: Architecture Overview ⏳ ~15 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   └── Output: P3-01-architecture.md
│   └── CHECKPOINT ✓
│
├── [PARALLEL GROUP A] - Run concurrently
│   ├── Phase 2a: API Contract Design ⏳ ~20 min
│   │   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   │   └── Output: api-contract.md
│   │   └── CHECKPOINT ✓
│   │
│   ├── Phase 2b: Database Design ⏳ ~20 min
│   │   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   │   └── Output: database-design.md
│   │   └── CHECKPOINT ✓
│   │
│   └── Phase 2d: Infrastructure Spec ⏳ ~15 min
│       Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│       └── Output: infra-spec.md
│       └── CHECKPOINT ✓
│
├── Phase 2c: Integration & Cross-system Rules ⏳ ~15 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   └── Condition: Runs AFTER 2a, 2b complete
│   └── Output: integration-map.md (incl. cross-system rules)
│   └── CHECKPOINT ✓
│
├── Phase 4a: Cross-Validation (Auto-Correction) ⏳ ~10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   └── Output: design-report.md (validation results)
│   └── CHECKPOINT ✓
│
SESSION N: Finalize
└── Phase 4: Update Registry & Finalize ⏳ ~10 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    └── Output: design-report.md
    └── CHECKPOINT ✓
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output File |
|-------|------|--------|---------|-----------|-------------|
| 0 | Context Loading | ⬜ | — | — | — |
| 1 | Registry Validation & Approach | ⬜ | — | — | design-plan.md |
| 2 | Architecture Overview | ⬜ | — | — | P3-01-architecture.md |
| 2a | API Contract Design | ⬜ | — | — | api-contract.md |
| 2b | Database Design | ⬜ | — | — | database-design.md |
| 2c | Integration & Cross-system Rules | ⬜ | — | — | integration-map.md |
| 2d | Infrastructure Spec | ⬜ | — | — | infra-spec.md |
| 4a | Cross-Validation (Auto-Correction) | ⬜ | — | — | design-report.md |
| 4 | Update Registry & Finalize | ⬜ | — | — | design-report.md |

**Overall Progress:** `0% (0/9 phases completed)`

---

## 3. File-Level Progress

| # | Output File | Phase | Status | Lines | REQ-IDs |
|---|-------------|-------|--------|-------|---------|
| 1 | `phase3-architecture/P3-01-architecture.md` | 2 | ⬜ Pending | 0 | — |
| 2 | `phase3-architecture/technical-specs/api-contract.md` | 2a | ⬜ Pending | 0 | — |
| 3 | `phase3-architecture/technical-specs/database-design.md` | 2b | ⬜ Pending | 0 | — |
| 4 | `phase3-architecture/technical-specs/integration-map.md` | 2c | ⬜ Pending | 0 | — |
| 5 | `phase3-architecture/technical-specs/infra-spec.md` | 2d | ⬜ Pending | 0 | — |

**Files Progress:** `0/5 (0%)`

---

## 4. Context Source

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| Features | `.mc-data/docs/phase2-features/features/` | `[FOUND / NOT_FOUND]` |
| Business Requirements | `.mc-data/docs/phase1-business/` | `[FOUND / NOT_FOUND]` |

### 4.2 Context Mode

| Mode | Description | Active |
|------|-------------|--------|
| **New Project** | Design tu requirements moi | `[YES/NO]` |
| **Onboard** | Design tu existing codebase | `[YES/NO]` |

---

## 5. Parallel Execution Strategy

### 5.1 Execution Groups

| Group | Phases | Can Run Parallel | Estimated Time |
|-------|--------|------------------|----------------|
| **A** | 2a, 2b, 2d | ✓ Yes | ~20 min (vs ~55 min sequential) |
| **Sequential** | 2c (depends on 2a + 2b) | ✗ Must wait | ~15 min |

### 5.2 Agent Assignment

| Phase | Agent Type | Output File |
|-------|------------|-------------|
| 2 | `architect` | P3-01-architecture.md |
| 2a | `architect` | api-contract.md |
| 2b | `dba` + `architect` | database-design.md |
| 2c | `architect` | integration-map.md |
| 2d | `devops` + `architect` | infra-spec.md |
---

## 6. Expected Outputs

### 6.1 Design Documents

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `phase3-architecture/P3-01-architecture.md` | 2 | System architecture overview | ⬜ |
| `phase3-architecture/technical-specs/api-contract.md` | 2a | API specifications | ⬜ |
| `phase3-architecture/technical-specs/database-design.md` | 2b | Database schema & entities | ⬜ |
| `phase3-architecture/technical-specs/integration-map.md` | 2c | Integration points giua cac systems | ⬜ |
| `phase3-architecture/technical-specs/infra-spec.md` | 2d | Infrastructure requirements | ⬜ |

### 6.2 Finalization (Phase 4)

| File | Description | Status |
|------|-------------|--------|
| `.mc-data/work/wf-design/design-report.md` | Design completion report | ⬜ |

### 6.3 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/wf-design/design-status.json` | Runtime status tracking |
| `.mc-data/work/wf-design/design-plan.md` | This file |
| `.mc-data/work/wf-design/checkpoint.json` | Checkpoint for resume |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase Complete | Any | Save checkpoint with phase data |

---

## 8. Notes

*[Ghi chu them ve design, cac diem can luu y, dependencies, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-design` skill.*
