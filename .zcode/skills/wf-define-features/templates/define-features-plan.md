# Define Features Plan

> **Muc dich:** Ke hoach chi tiet de chuyen requirements thanh feature specifications.
>
> **Ai viet:** AI tu dong generate khi chay `/wf-define-features`
>
> **Khi viet:** Phase 1 cua define-features skill
>
> **Cap nhat:** Tu dong cap nhat sau moi phase hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Skill Run ID** | `[DEFINE-FEAT-YYYYMMDD-NNN]` |
| **Scope** | `[all / system-name / module-name]` |
| **Target** | `[all / System Name / Module Name]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `In Progress` / `Completed` / `Error` |

---

## 1. Scope Overview

### 1.1 Requirements Summary

| Muc | So luong |
|-----|---------|
| Total REQ-IDs trong registry | `[N]` |
| REQ-IDs trong scope | `[N]` |
| Systems can xu ly | `[N]` |
| Modules can xu ly | `[N]` |
| Feature files se tao | `[N]` |

### 1.2 Target Systems & Modules

| # | System ID | System Name | Modules | REQ count | Priority |
|---|-----------|-------------|---------|-----------|----------|
| 1 | `[SYS-XXX]` | `[System Name]` | `[MOD-1, MOD-2, ...]` | `[N]` | HIGH |
| 2 | `[SYS-YYY]` | `[System Name]` | `[MOD-1, ...]` | `[N]` | MEDIUM |
| ... | ... | ... | ... | ... | ... |

### 1.3 Handoff Inputs

| Input | Location | Vai trò |
|-------|----------|---------|
| Project intent digest | `.mc-data/work/wf-brainstorm/project-intent-digest.json` | Giữ intent và scope gọn cho Phase 2 |
| Phase 1 handoff | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` | REQ clusters, actors, business rule keywords |
| Feature briefs | `.mc-data/work/wf-define-features/feature-briefs.json` | Artifact ngắn dùng chung cho review và validation |

---

## 2. FEAT-ID Assignment

### 2.1 Scheme

```
FEAT-[SYS]-[MOD]-NNN
 ^     ^     ^    ^
 |     |     |    └── Sequential number (zero-padded, e.g. 001, 002)
 |     |     └─────── Module abbreviation (3-6 chars, uppercase)
 |     └───────────── System abbreviation (3-6 chars, uppercase)
 └─────────────────── Prefix "FEAT"
```

**Vi du:** `FEAT-CRM-CUST-001`, `FEAT-CRM-CUST-002`, `FEAT-HRM-PAYRL-001`

### 2.2 Feature Groups & FEAT-IDs

| FEAT-ID | Feature Name | System | Module | REQ-IDs Covered | Output File |
|---------|-------------|--------|--------|-----------------|-------------|
| `FEAT-[SYS]-[MOD]-001` | `[Feature Name]` | `[SYS]` | `[MOD]` | `REQ-xxx-001, REQ-xxx-002` | `[sys]/[mod]/[name].md` |
| `FEAT-[SYS]-[MOD]-002` | `[Feature Name]` | `[SYS]` | `[MOD]` | `REQ-xxx-003` | `[sys]/[mod]/[name].md` |
| ... | ... | ... | ... | ... | ... |

---

## 3. Session Breakdown

```
SESSION 1: Context & Planning
├── Phase 0: Context Loading ⏳ ~2 min
│   Status: Pending / In Progress / Completed
│
└── Phase 1: Scope & Feature Mapping ⏳ ~5 min
    Status: Pending / In Progress / Completed
    └── Output: define-features-plan.md (this file)
    └── Output: feature-briefs.json

SESSION 2+: Feature Spec Creation (Resumable)
├── Phase 2: Create Feature Specs ⏳ ~[N x 10] min
│   Status: Pending / In Progress / Completed
│   ├── System [SYS-001]: [N] features
│   │   ├── Module [MOD-1]: [N] files
│   │   └── Module [MOD-2]: [N] files
│   │   └── CHECKPOINT ✓ (sau system hoan thanh)
│   │
│   └── System [SYS-002]: [N] features
│       └── CHECKPOINT ✓
│
├── Phase 3: Cross-Validation (Auto-Correction) ⏳ ~10 min
│   Status: Pending / In Progress / Completed
│   └── Max 3 iterations
│   └── CHECKPOINT ✓
│
├── Phase 4: Stakeholder Review (Auto-Correction) ⏳ ~15 min
│   Status: Pending / In Progress / Completed
│   └── PARALLEL: business-analyst + product-expert
│   └── Max 3 iterations
│   └── CHECKPOINT ✓
│
SESSION N: Finalize
└── Phase 5: Update Registry ⏳ ~5 min
    Status: Pending / In Progress / Completed
    └── Safe-write features[] only
    └── Output: define-features-report.md
```

### 3.1 Progress Tracking

| Phase | Name | Status | Started | Completed | Output |
|-------|------|--------|---------|-----------|--------|
| 0 | Context Loading | Pending | — | — | define-features-status.json |
| 1 | Scope & Feature Mapping | Pending | — | — | define-features-plan.md |
| 2 | Create Feature Specs | Pending | — | — | phase2-features/**/*.md |
| 3 | Cross-Validation | Pending | — | — | (auto-fix in-place) |
| 4 | Stakeholder Review | Pending | — | — | phase2-features/stakeholder-review.md |
| 5 | Update Registry | Pending | — | — | registry.json + report.md |

**Overall Progress:** `0% (0/5 phases completed)`

---

## 4. File-Level Progress

| # | Output File | FEAT-ID | Status | Lines | REQ-IDs |
|---|-------------|---------|--------|-------|---------|
| 1 | `phase2-features/[sys]/[mod]/[feature].md` | `FEAT-xxx-001` | Pending | 0 | — |
| 2 | `phase2-features/[sys]/[mod]/[feature].md` | `FEAT-xxx-002` | Pending | 0 | — |
| ... | ... | ... | ... | ... | ... |

**Files Progress:** `0/[N] (0%)`

---

## 5. Context Sources

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| phase1-handoff.json | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` | `[FOUND / NOT_FOUND]` |
| Department docs | `.mc-data/docs/phase1-business/departments/` | `[FOUND / NOT_FOUND]` |
| Business workflow | `.mc-data/docs/phase1-business/P1-02-business-workflow.md` | `[FOUND / NOT_FOUND]` |
| Deferred issues | `.mc-data/work/wf-analyze-requirements/deferred-issues.md` | `[FOUND / NOT_FOUND]` |
| Feature template | `.claude/doc-framework/phase2-features/features/` | `[FOUND / NOT_FOUND]` |

---

## 6. Checkpoint Strategy

| Trigger | Nguong | Hanh dong |
|---------|--------|-----------|
| Context Warning | 65% | Log warning, tiep tuc |
| System Complete | Any | Save checkpoint |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |

---

## 7. Validation Checklist

### Pre-Execution
- [ ] req-registry.json ton tai
- [ ] requirements[] khong rong
- [ ] Dept docs co san
- [ ] Feature template co san

### Per-File
- [ ] File non-empty
- [ ] 9 sections theo template
- [ ] REQ-IDs referenced (format: REQ-[DEPT]-[NNN])
- [ ] FEAT-ID dung format (FEAT-[SYS]-[MOD]-NNN)
- [ ] Khong co TODO/TBD
- [ ] Khong co YAML front-matter

### Post-Execution
- [ ] 100% REQ-IDs duoc map sang >= 1 feature
- [ ] Khong co duplicate FEAT-IDs
- [ ] Stakeholder review APPROVED/APPROVED_WITH_CONDITIONS
- [ ] Registry updated, features[] populated
- [ ] define-features-report.md ton tai

---

## 8. Notes

*[Ghi chu them ve feature grouping decisions, conflicts, deferred items, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-define-features` skill.*
