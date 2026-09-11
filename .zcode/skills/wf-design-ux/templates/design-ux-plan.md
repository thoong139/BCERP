# Design UX Plan

> **Muc dich:** Ke hoach chi tiet de thiet ke UX/UI cho he thong.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-design-ux`
>
> **Khi viet:** Phase 0 cua design-ux skill
>
> **Cap nhat:** Tu dong cap nhat sau moi phase hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Design UX ID** | `[DESIGN-UX-YYYYMMDD-NNN]` |
| **Scope** | `[all / system-name]` |
| **Target** | `[Tat ca systems co UI / System Name]` |
| **Interface Type** | `[web / mobile / web+mobile]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `In Progress` / `Completed` / `Error` |

---

## 1. Scope Overview

### 1.1 Systems co UI

| # | System ID | System Name | Modules co UI | Priority | Status |
|---|-----------|-------------|---------------|----------|--------|
| 1 | `[SYS-XXX]` | `[System Name]` | `[MOD-1, MOD-2, ...]` | `[HIGH/MEDIUM/LOW]` | Pending |
| 2 | `[SYS-XXX]` | `[System Name]` | `[...]` | `[...]` | Pending |

### 1.2 Screen Groups du kien

| # | System | Module | Screen Groups | Status |
|---|--------|--------|---------------|--------|
| 1 | `[SYS-XXX]` | `[MOD-XXX]` | `[list, detail, form, ...]` | Pending |

---

## 2. Session Breakdown

### 2.1 Multi-Session Architecture

```
SESSION 1: Context & Design System
├── Phase 0: Context Loading & UI Check ~2 min
│   Status: Pending / In Progress / Completed / Exit (api-only)
│
└── Phase 1: Design System ~15 min
    Status: Pending / In Progress / Completed
    └── Output: phase4-ux/design-system.md
    └── CHECKPOINT

SESSION 2+: Navigation & Screen Groups (Resumable)
├── Phase 2: Navigation Specs (per system) ~10 min/system
│   Status: Pending / In Progress / Completed
│   ├── [SYS-XXX] Navigation-[sys].md → CHECKPOINT
│   └── [SYS-XXX] Navigation-[sys].md → CHECKPOINT
│
├── Phase 3: Screen Groups (per module) ~10 min/module
│   Status: Pending / In Progress / Completed
│   ├── [SYS-1] batch
│   │   ├── [MOD-1] screen-group files → CHECKPOINT (end of system)
│   │   └── [MOD-2] screen-group files
│   └── [SYS-2] batch
│       └── [MOD-3] screen-group files → CHECKPOINT (end of system)
│
├── Phase 4: Cross-Validation (Auto-Correction) ~10 min
│   Status: Pending / In Progress / Completed
│   └── Validates 6 checks, max 3 iterations
│
SESSION N: Stakeholder Review & Finalize
├── Phase 5: Stakeholder Review ~15 min
│   Status: Pending / In Progress / Completed
│   └── Output: phase4-ux/stakeholder-review.md
│   └── CHECKPOINT
│
└── Phase 6: Update Registry ~2 min
    Status: Pending / In Progress / Completed
    └── ux_design_status = "done"
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output |
|-------|------|--------|---------|-----------|--------|
| 0 | Context Loading & UI Check | Pending | — | — | design-ux-status.json |
| 1 | Design System | Pending | — | — | phase4-ux/design-system.md |
| 2 | Navigation Specs | Pending | — | — | phase4-ux/[sys]/Navigation-*.md |
| 3 | Screen Groups | Pending | — | — | phase4-ux/[sys]/[mod]/*.md |
| 4 | Cross-Validation | Pending | — | — | — (auto-fix) |
| 5 | Stakeholder Review | Pending | — | — | phase4-ux/stakeholder-review.md |
| 6 | Update Registry | Pending | — | — | req-registry.json |

**Overall Progress:** `0% (0/6 phases completed)`

---

## 3. File-Level Progress

| # | Output File | Phase | Status | Sections | UI-IDs |
|---|-------------|-------|--------|----------|--------|
| 1 | `phase4-ux/design-system.md` | 1 | Pending | 0/6 | — |
| 2 | `phase4-ux/[sys]/Navigation-[sys].md` | 2 | Pending | 0/10 | — |
| 3 | `phase4-ux/[sys]/[mod]/[screen-group].md` | 3 | Pending | 0/7 | 0 |
| 4 | `phase4-ux/stakeholder-review.md` | 5 | Pending | 0/4 | — |

**Files Progress:** `0/N (0%)`

---

## 4. Context Sources

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| P3-01-architecture.md | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | `[FOUND / NOT_FOUND]` |
| api-contract.md | `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md` | `[FOUND / NOT_FOUND]` |
| Features | `.mc-data/docs/phase2-features/features/` | `[FOUND / NOT_FOUND]` |

### 4.2 Interface Type Detection

| Method | Value | Confirmed |
|--------|-------|-----------|
| `req-registry.json` `.interface_type` | `[web / mobile / web+mobile / api-only]` | `[YES/NO]` |

---

## 5. Agent Assignment

| Phase | Agent | Scope | Output |
|-------|-------|-------|--------|
| 1 | `ux-designer` | Toan bo project | design-system.md |
| 2 | `ux-designer` | Per system | Navigation-[sys].md |
| 3 | `ux-designer` | Per module | [screen-group].md |
| 5a | `ux-designer` | Phan B + C | stakeholder-review.md (SO-01, SO-02) |
| 5b | `architect` | Phan D | stakeholder-review.md (SO-03) |

---

## 6. Expected Outputs

### 6.1 UX Documents

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `phase4-ux/design-system.md` | 1 | Design system toan the (6 sections) | Pending |
| `phase4-ux/[sys]/Navigation-[sys].md` | 2 | Navigation spec per system (10 sections) | Pending |
| `phase4-ux/[sys]/[mod]/[screen-group].md` | 3 | Screen group per module (7 sections) | Pending |

### 6.2 Review & Registry

| File | Description | Status |
|------|-------------|--------|
| `phase4-ux/stakeholder-review.md` | Stakeholder review (Phan A-D) | Pending |
| `req-registry.json` (field `ux_design_status`) | Registry update | Pending |

### 6.3 Working Files

| File | Description |
|------|-------------|
| `.mc-data/work/wf-design-ux/design-ux-status.json` | Runtime status tracking |
| `.mc-data/work/wf-design-ux/design-ux-plan.md` | This file |
| `.mc-data/work/wf-design-ux/checkpoint.json` | Checkpoint for resume |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase 2 — per system | After each system | Save checkpoint |
| Phase 3 — per system batch | After each system | Save checkpoint |

---

## 8. Validation Plan (Phase 4)

| Check | Description | Auto-Fix |
|-------|-------------|---------|
| 4.1 | Moi feature co UI co >= 1 screen group | Tao screen group stub |
| 4.2 | Tat ca UI-IDs unique | Doi ten UI-ID trung |
| 4.3 | Tat ca screen groups trong Navigation | Them entry vao Navigation |
| 4.4 | API endpoints ton tai trong api-contract | Sua endpoint reference |
| 4.5 | Design tokens nhat quan | Chuan hoa theo design-system |
| 4.6 | Permission matrix khop feature spec | Sync permission |

---

## 9. Notes

*[Ghi chu them: dependencies, cac diem can luu y, deferred items, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-design-ux` skill.*
