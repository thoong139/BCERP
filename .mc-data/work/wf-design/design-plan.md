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
| **Design ID** | `DESIGN-20260913-001` |
| **Scope** | `platform` |
| **Target** | `BCERP Platform — 6 systems, 19 modules` |
| **Created** | `2026-09-13 05:38:48` |
| **Last Updated** | `2026-09-13 05:38:48` |
| **Status** | `🔄 In Progress` |
| **Context** | `new` |

---

## 1. Scope Overview

### 1.1 Design Type

| Type | Description | Active |
|------|-------------|--------|
| **Platform Design** | Thiet ke multi-system platform (> 1 system) | `YES` |
| **System Design** | Thiet ke single system (1 system, > 2 modules) | `NO` |
| **Module Design** | Thiet ke single module (1 system, 1-2 modules) | `NO` |

### 1.2 Target Systems/Modules

| # | System | Modules | Features | Priority | Status |
|---|--------|---------|----------|----------|--------|
| 1 | SYS-BCERP-WEB — BCERP Web nội bộ | MOD-HR-CORE, MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-ADACCOUNT-CC, MOD-WALLET-RECON, MOD-ARAP-PAYMENT, MOD-HANDOFF-ONBOARD, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE, MOD-CAPACITY-TIMESHEET, MOD-SLA-NOTIF, MOD-TICKET-CSKH, MOD-COMMISSION-QUOTA, MOD-KPI-PERFORMANCE (14) | 58 | HIGH | ⬜ Pending |
| 2 | SYS-CORE-BACKEND — BCERP Core Backend | MOD-RBAC-AUDIT, MOD-DATAHUB-BI (2) | 59 | HIGH | ⬜ Pending |
| 3 | SYS-INTEGRATION-GW — API Integration Gateway | MOD-SETTINGS-GW, MOD-TIKTOK-SHOP (2) | 11 | HIGH | ⬜ Pending |
| 4 | SYS-PORTAL-WEB — Client Portal Web | MOD-CLIENT-PORTAL (1) | 7 | MEDIUM | ⬜ Pending |
| 5 | SYS-MOBILE-INTERNAL — Mobile App BCERP Internal | (thin client — dùng module core qua API) | 30 | MEDIUM | ⬜ Pending |
| 6 | SYS-MOBILE-PORTAL — Mobile App BC Portal | (thin client — dùng module portal qua API) | 5 | MEDIUM | ⬜ Pending |

**Large Project Mode: ACTIVE** (systems=6 ≥ 5, requirements=59 ≥ 50, features=170 ≥ 40).
LPM params: max_parallel=3, skeleton-first >2000 từ, digest extended, checkpoint per phase + per sub-step.

---

## 2. Session Breakdown

### 2.1 Multi-Session Architecture

```
SESSION 1: Context & Planning
├── Phase 0: Context Loading ✅ Completed
│   └── Session 20260913-053848-f4d7
│
└── Phase 0.5: Workload Gate ⏳ ~5 min
    └── Output: workload-report.md

SESSION 1+ (LPM — resumable per phase + per sub-step):
├── Phase 1: Business Context Baseline (Step 1.0, SEQUENTIAL main-conversation)
│   └── Output: $SESSION_DIR/business-context.md
├── Phase 1: Architecture Overview — Lane Dispatch per system (max 3 parallel)
│   └── Output: P3-01-architecture.md + lanes/{sys}/signals.json
│   └── CHECKPOINT ✓
│
├── Phase 2: Technical Specs — 3 specs per system lane (max 3 parallel)
│   ├── api-contract.md ⏳
│   ├── database-design.md ⏳
│   └── infra-spec.md ⏳
│   └── CHECKPOINT ✓
│
├── Phase 3: Signal Aggregation + Integration Map (SEQUENTIAL)
│   └── Output: integration-map.md + aggregation-result.json
│   └── CHECKPOINT ✓
│
├── Phase 4: Cross-Validation (8 checks, auto-correction ≤3 iterations)
│   └── Output: design-report.md
│   └── CHECKPOINT ✓
│
├── Phase 5: Stakeholder Review (PARALLEL architect + security)
│   └── Output: stakeholder-review.md
│   └── CHECKPOINT ✓
│
└── Phase 6: Registry Safe-Write + Compressed Spec (SEQUENTIAL main-conversation)
    └── Output: design-summary.json + req-registry.json.design_status
    └── CHECKPOINT ✓

SESSION N: Finalize
└── Phase 8: Digest + Phase Summary + Session Log
    └── Output: design-input-digest.json + phase-summary.md
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output File |
|-------|------|--------|---------|-----------|-------------|
| 0 | Context Loading | ✅ | 05:38 | — | design-status.json |
| 0.5 | Workload Gate | ⬜ | — | — | workload-report.md |
| 1 | Business Context + Architecture | ⬜ | — | — | P3-01-architecture.md |
| 2 | Technical Specs (2a+2b+2d per lane) | ⬜ | — | — | api/db/infra specs |
| 2c/3 | Integration Map + Aggregation | ⬜ | — | — | integration-map.md |
| 4 | Cross-Validation | ⬜ | — | — | design-report.md |
| 5 | Stakeholder Review | ⬜ | — | — | stakeholder-review.md |
| 6 | Registry Update + Compressed Spec | ⬜ | — | — | design-summary.json |
| 8 | Digest + Summary | ⬜ | — | — | design-input-digest.json |

**Overall Progress:** `~10% (Phase 0 completed / 9 phases)`

---

## 3. File-Level Progress

| # | Output File | Phase | Status | Lines | REQ-IDs |
|---|-------------|-------|--------|-------|---------|
| 1 | `phase3-architecture/P3-01-architecture.md` | 1 | ⬜ Pending | 0 | — |
| 2 | `phase3-architecture/technical-specs/api-contract.md` | 2 | ⬜ Pending | 0 | — |
| 3 | `phase3-architecture/technical-specs/database-design.md` | 2 | ⬜ Pending | 0 | — |
| 4 | `phase3-architecture/technical-specs/integration-map.md` | 3 | ⬜ Pending | 0 | — |
| 5 | `phase3-architecture/technical-specs/infra-spec.md` | 2 | ⬜ Pending | 0 | — |

**Files Progress:** `0/5 (0%)`

---

## 4. Context Source

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `FOUND` (59 REQ / 19 MOD / 6 SYS / 170 FEAT) |
| Features | `.mc-data/docs/phase2-features/` | `FOUND` (170 features, 171 files, forensic PASS 171/171) |
| feature-briefs.json | `.mc-data/docs/_meta/feature-briefs.json` | `FOUND` (228 KB) |
| Feature digest | `$SESSION_DIR/feature-digest.md` | `GENERATED` (~10.9K từ, 6 systems) |
| Deferred findings (upstream) | `.mc-data/work/wf-define-features/deferred-findings.md` | `FOUND` (CF6 cross-FEAT refs) |
| Business Requirements | `.mc-data/docs/phase1-business/` | `FOUND` |

### 4.2 Context Mode

| Mode | Description | Active |
|------|-------------|--------|
| **New Project** | Design tu requirements moi | `YES` |
| **Onboard** | Design tu existing codebase | `NO` (LEGACY_MODE=false) |

---

## 5. Parallel Execution Strategy

### 5.1 Execution Groups (LPM — max 3 parallel agents)

| Group | Phases | Can Run Parallel | Estimated Time |
|-------|--------|------------------|----------------|
| **Lane 1** | P1+P2 system BCERP-WEB | Serial trong lane | Lớn nhất (58 features, 14 modules) |
| **Lane 2** | P1+P2 system CORE-BACKEND | Song song với Lane 1/3 | 59 features |
| **Lane 3** | P1+P2 system INTEGRATION-GW | Song song | 11 features |
| **Lane 4** | P1+P2 systems PORTAL + MOBILE-INTERNAL + MOBILE-PORTAL | Nối sau (queue) | 42 features |
| **Sequential** | Phase 3 (sau P2), Phase 4, 5, 6, 8 | ✗ Must wait | — |

### 5.2 Agent Assignment

| Phase | Agent Type | Output File |
|-------|------------|-------------|
| 1 | `architect` (per system lane) | P3-01 sections + lane signals |
| 1 | `data-engineer` (conditional — MOD-DATAHUB-BI có ETL/BI) | Data Pipeline section |
| 2 | `architect` (per lane) | api-contract.md |
| 2 | `dba` + `architect` | database-design.md |
| 2 | `devops` + `architect` | infra-spec.md |
| 3 | `architect` | integration-map.md |
| 5 | `architect` | stakeholder-review Phần B+C |
| 5 | `security` | stakeholder-review Phần D |

**Conditional agents:** `$HAS_AI_ML = false` (không có ML training/serving trong registry).
`$HAS_DATA_PIPELINE = true` (MOD-DATAHUB-BI: Data Integration Hub & Analytics — ETL, BI/BOD dashboard).
`$HAS_AUTOMATION = true` (SLA & Notification Engine, Workflow automation nhiều module — đánh giá trong P3-01).

---

## 6. Expected Outputs

### 6.1 Design Documents

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `phase3-architecture/P3-01-architecture.md` | 1 | Platform architecture overview (7 sections + §9 business matrix) | ⬜ |
| `phase3-architecture/technical-specs/api-contract.md` | 2 | API specifications per system | ⬜ |
| `phase3-architecture/technical-specs/database-design.md` | 2 | Database schema & entities | ⬜ |
| `phase3-architecture/technical-specs/integration-map.md` | 3 | Integration points + cross-system rules | ⬜ |
| `phase3-architecture/technical-specs/infra-spec.md` | 2 | Infrastructure requirements | ⬜ |
| `phase3-architecture/stakeholder-review.md` | 5 | Stakeholder review Phần A–D | ⬜ |

### 6.2 Finalization

| File | Description | Status |
|------|-------------|--------|
| `.mc-data/work/wf-design/design-report.md` | Design completion report | ⬜ |
| `.mc-data/work/wf-design/design-summary.json` | Compressed spec (canonical) | ⬜ |
| `.mc-data/docs/_meta/design-input-digest.json` | Digest cho wf-implement-feature | ⬜ |
| `req-registry.json` | `design_status = completed` (safe-write) | ⬜ |

### 6.3 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/wf-design/design-status.json` | Runtime status tracking |
| `.mc-data/work/wf-design/design-plan.md` | This file |
| `.mc-data/work/wf-design/checkpoint.json` | Checkpoint for resume (mirror) |

---

## 7. Checkpoint Strategy (LPM)

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase Complete | Any | Save checkpoint with phase data |
| LPM Extra | Per sub-step | Save sau mỗi lane/spec batch |

---

## 8. Notes

- BC Agency là digital marketing agency — trung gian TKQC đa nền tảng (Meta/Google/TikTok/Bing/X/Pinterest/Yandex), 1000+ KH, 2600+ TKQC active. Domain experts: paid-media-expert, marketing-expert, sales-expert, finance-expert, customer-expert, compliance-expert.
- Nền Phase 2 hoàn tất 13/09: 170 features APPROVED_WITH_CONDITIONS (workflow /wf-define-features). DI-004: connector vendor-agnostic qua Settings.
- Deferred findings upstream (CF6) liệt kê cross-FEAT references — dùng cho Phase 4/5 validation.
- Module Consolidation Review chạy ở Phase 1 Step 1.0 — nếu flag gộp module thì CHỈ report cho user, KHÔNG tự sửa registry (CORE-006).
- CI tools (GitNexus/Serena) không khả dụng cho repo docs-only → fallback Read/Grep.

---

*This plan was auto-generated by DEVKIT `/wf-design` skill.*
