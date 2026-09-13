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
| **Design UX ID** | `DESIGN-UX-20260913-001` |
| **Scope** | `all` |
| **Target** | `Tất cả systems có UI` |
| **Interface Type** | `web+mobile` |
| **Created** | `2026-09-13 08:02:22` |
| **Last Updated** | `2026-09-13 08:05:00` |
| **Status** | `In Progress` |

---

## 1. Scope Overview

### 1.1 Systems co UI

| # | System ID | System Name | Modules co UI | Priority | Status |
|---|-----------|-------------|---------------|----------|--------|
| 1 | `SYS-BCERP-WEB` | BCERP Web nội bộ | 14 modules (MOD-HR-CORE → MOD-KPI-PERFORMANCE) | HIGH | Pending |
| 2 | `SYS-PORTAL-WEB` | Client Portal Web | 1 module (MOD-CLIENT-PORTAL) | HIGH | Pending |
| 3 | `SYS-MOBILE-INTERNAL` | Mobile App — BCERP Internal | 0 module riêng — features cross-system (30 feat files) | MEDIUM | Pending |
| 4 | `SYS-MOBILE-PORTAL` | Mobile App — BC Portal | 0 module riêng — features cross-system (5 feat files) | MEDIUM | Pending |

API-only (exclude khỏi UX scope): SYS-CORE-BACKEND, SYS-INTEGRATION-GW.

### 1.2 Screen Groups du kien

Ước tính từ 170 features (registry `screen_groups` chưa được wf-design populate — Phase 2 Step 2.0 Screen Inventory sẽ chốt danh sách chính thức):

| # | System | Module | Screen Groups dự kiến | Status |
|---|--------|--------|------------------------|--------|
| 1 | SYS-BCERP-WEB | MOD-HR-CORE | list + profile (nhân viên, phòng ban, vai) | Pending |
| 2 | SYS-BCERP-WEB | MOD-CRM-PIPELINE | pipeline board + lead/deal detail | Pending |
| 3 | SYS-BCERP-WEB | MOD-QUOTATION-DEALDESK | list + quote builder + approval | Pending |
| 4 | SYS-BCERP-WEB | MOD-ADACCOUNT-CC | registry list + account 360 + cấp phát flow | Pending |
| 5 | SYS-BCERP-WEB | MOD-WALLET-RECON | wallet list + đối soát + cảnh báo | Pending |
| 6 | SYS-BCERP-WEB | MOD-ARAP-PAYMENT | AR/AP list + payment + giải ngân approval | Pending |
| 7 | SYS-BCERP-WEB | MOD-HANDOFF-ONBOARD | handoff bridge + checklist onboarding | Pending |
| 8 | SYS-BCERP-WEB | MOD-PROPOSAL-PLANNING | proposal workspace + planning board | Pending |
| 9 | SYS-BCERP-WEB | MOD-CAMPAIGN-DELIVERABLE | campaign list + deliverable tracking | Pending |
| 10 | SYS-BCERP-WEB | MOD-CAPACITY-TIMESHEET | capacity board + timesheet | Pending |
| 11 | SYS-BCERP-WEB | MOD-SLA-NOTIF | SLA rules + notification center | Pending |
| 12 | SYS-BCERP-WEB | MOD-TICKET-CSKH | ticket queue + ticket detail | Pending |
| 13 | SYS-BCERP-WEB | MOD-COMMISSION-QUOTA | commission calc + quota tracking | Pending |
| 14 | SYS-BCERP-WEB | MOD-KPI-PERFORMANCE | KPI dashboard + performance review | Pending |
| 15 | SYS-PORTAL-WEB | MOD-CLIENT-PORTAL | portal home + project/deliverable view + billing view | Pending |
| 16 | SYS-MOBILE-INTERNAL | (cross-system) | mobile working surfaces cho features có cross_system chứa SYS-MOBILE-INTERNAL | Pending |
| 17 | SYS-MOBILE-PORTAL | (cross-system) | mobile surfaces cho client-facing features | Pending |

---

## 2. Session Breakdown

### 2.1 Multi-Session Architecture

```
SESSION 1 (hiện tại): Context & Design System & Navigation
├── Phase 0: Context Loading & UI Check ~2 min — COMPLETED
├── Phase 0.5: Workload Gate — pending
├── Phase 1: Design System ~15 min (3 agents sequential)
│   └── Output: phase4-ux/design-system.md → CHECKPOINT
└── Phase 2: Step 2.0 Workflow Context + Screen Inventory + Consolidation (main conversation)
    └── Navigation specs per system (SEQUENTIAL, ux-designer + ux-architect parallel) → CHECKPOINT

SESSION 2+: Screen Groups (Resumable, LPM max 3 agents)
├── Phase 3: Lane dispatch per system → screen-group files → CHECKPOINT per system
├── Phase 4: Cross-Validation 13 checks (max 3 iterations)

SESSION N: Stakeholder Review & Finalize
├── Phase 5: Stakeholder Review (ux-designer + architect parallel)
├── Phase 6: Registry safe-write ux_design_status=done
└── Phase 7: Digest + phase-summary
```

### 2.2 Progress Tracking

| Phase | Name | Status | Started | Completed | Output |
|-------|------|--------|---------|-----------|--------|
| 0 | Context Loading & UI Check | Completed | 08:02 | 08:05 | design-ux-status.json |
| 0.5 | Workload Gate | Pending | — | — | workload-report.md |
| 1 | Design System | Pending | — | — | phase4-ux/design-system.md |
| 2 | Workflow Context + Navigation | Pending | — | — | workflow-context.md + Navigation-*.md |
| 3 | Screen Groups | Pending | — | — | phase4-ux/[sys]/[mod]/screens-*.md |
| 4 | Cross-Validation | Pending | — | — | cross-validation-report.md |
| 5 | Stakeholder Review | Pending | — | — | phase4-ux/stakeholder-review.md |
| 6 | Update Registry | Pending | — | — | req-registry.json |
| 7 | Digest & Summary | Pending | — | — | ux-input-digest.json + phase-summary.md |

**Overall Progress:** `5% (Phase 0 completed)`

---

## 3. File-Level Progress

| # | Output File | Phase | Status | Sections | UI-IDs |
|---|-------------|-------|--------|----------|--------|
| 1 | `phase4-ux/design-system.md` | 1 | Pending | 0/6 | — |
| 2 | `phase4-ux/bcerp-web/Navigation-bcerp-web.md` | 2 | Pending | 0/5 | — |
| 3 | `phase4-ux/portal-web/Navigation-portal-web.md` | 2 | Pending | 0/5 | — |
| 4 | `phase4-ux/mobile-*/Navigation-*.md` | 2 | Pending | 0/5 | — |
| 5 | `phase4-ux/[sys]/[mod]/[screen-group].md` | 3 | Pending | 0/7 | 0 |
| 6 | `phase4-ux/stakeholder-review.md` | 5 | Pending | 0/4 | — |

**Files Progress:** `0/6+ (0%)`

---

## 4. Context Sources

### 4.1 Required Inputs

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `FOUND` (119.961 bytes, 170 FEAT) |
| P3-01-architecture.md | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | `FOUND` (52.022 bytes) |
| api-contract.md | `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md` | `FOUND` (134.235 bytes) |
| Features | `.mc-data/docs/phase2-features/` | `FOUND` (170 feat files, 6 system dirs) |
| business-context.md | `.mc-data/work/wf-design/sessions/20260913-053848-f4d7/` | `FOUND` (Step 1.0 /wf-design) |
| stakeholder-review.md | `.mc-data/docs/phase3-architecture/stakeholder-review.md` | `FOUND` (APPROVED_WITH_CONDITIONS) |

### 4.2 Interface Type Detection

| Method | Value | Confirmed |
|--------|-------|-----------|
| `req-registry.json` `.interface_type` | `web+mobile` | `YES` |

---

## 5. Agent Assignment

| Phase | Agent | Scope | Output |
|-------|-------|-------|--------|
| 1a | `brand-guardian` | Toàn bộ project (conditional — chỉ khi có brand guidelines) | Brand review |
| 1b | `ux-researcher` | Toàn bộ project | User research context |
| 1c | `ux-designer` | Toàn bộ project | design-system.md |
| 2 | `ux-designer` + `ux-architect` | Per system (parallel pair, sequential per system) | Navigation-[sys].md + CSS/layout arch |
| 3 | `ux-designer` | Per system (lane dispatch, max 3 đồng thời — LPM) | [screen-group].md |
| 4 | `accessibility-auditor` | Toàn bộ outputs | WCAG check |
| 5a | `ux-designer` | Phần B + C | stakeholder-review.md (SO-01, SO-02) |
| 5b | `architect` | Phần D | stakeholder-review.md (SO-03) |

**Parallel Strategy:** Phase 3 spawn 1 ux-designer lane per system, max `$LPM_PARAMS.max_parallel_agents` = 3 đồng thời; trong cùng system modules chạy SEQUENTIAL.

**Lưu ý harness:** DEVKIT subagent types (ux-designer, ux-architect, brand-guardian, ux-researcher, accessibility-auditor, architect) KHÔNG có sẵn trong Agent tool của môi trường này → spawn `general-purpose` với persona-injection prompt theo `_shared.md §Agent Prompt Templates` (memory: zcode-agent-tool-no-devkit-types).

---

## 6. Expected Outputs

### 6.1 UX Documents

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `phase4-ux/design-system.md` | 1 | Design system toàn thể (6 sections) | Pending |
| `phase4-ux/[sys]/Navigation-[sys].md` | 2 | Navigation spec per system | Pending |
| `phase4-ux/[sys]/[mod]/[screen-group].md` | 3 | Screen group per module (7 sections) | Pending |

### 6.2 Review & Registry

| File | Description | Status |
|------|-------------|--------|
| `phase4-ux/stakeholder-review.md` | Stakeholder review (Phần A-D) | Pending |
| `req-registry.json` (field `ux_design_status`) | Registry update | Pending |

### 6.3 Working Files

| File | Description |
|------|-------------|
| `sessions/20260913-080222-df29/design-ux-status.json` | Runtime status tracking |
| `.mc-data/work/wf-design-ux/design-ux-plan.md` | This file |
| `sessions/20260913-080222-df29/checkpoint.json` | Checkpoint for resume |
| `sessions/20260913-080222-df29/workflow-context.md` | Phase 2 Step 2.0 — workflow map + screen inventory + consolidation |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase 2 — per system | After each system | Save checkpoint |
| Phase 3 — per system batch | After each system | Save checkpoint (**LPM: checkpoint per system**) |

**LPM active:** systems (6) ≥ 5 → compression sớm hơn (threshold 2), digest 300, skeleton threshold 2000, max 3 parallel agents.

---

## 8. Validation Plan (Phase 4 — 13 checks v4.1)

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| 4.1 | Mọi feature có UI có ≥ 1 screen group | Tạo screen group stub |
| 4.2 | Tất cả UI-IDs unique | Đổi tên UI-ID trùng |
| 4.3 | Tất cả screen groups trong Navigation | Thêm entry vào Navigation |
| 4.4 | API endpoints tồn tại trong api-contract | Sửa endpoint reference |
| 4.5 | Design tokens nhất quán | Chuẩn hóa theo design-system |
| 4.6 | Permission matrix khớp feature spec | Sync permission |
| 4.7 | Screen files tồn tại trên disk | Retry/tạo file |
| 4.8 | Accessibility (WCAG AA) | Ghi finding |
| 4.9 | Screen Justification (mỗi screen có lý do tồn tại — Step 2.0) | Gắn justification |
| 4.10 | Data grid ERP chuẩn | Chuẩn hóa grid spec |
| 4.11 | Tab Justification | Gắn justification |
| 4.12 | Tab Completeness | Bổ sung tab còn thiếu |
| 4.13 | Cross-Module Context | Bổ sung context liên module |

---

## 9. Notes

- **Kế thừa từ /wf-design (Phase 3):** review kết quả **APPROVED_WITH_CONDITIONS** — 33 findings (0 Critical / 6 High / 19 Medium / 8 Low): 20 RESOLVED / 13 DEFERRED / 0 PENDING. 13 DEFERRED nằm ở `deferred-findings.md` — trong đó **F-D-17 (Mobile root/jailbreak detection — "Đưa vào thiết kế mobile")** liên quan trực tiếp Phase 1/2 mobile design; F-B-05 (vai ngoài registry — SALES_L4/L5, GM, DES/EDIT/ADS chờ BOD chốt theo NEEDS_REVIEW #8) ảnh hưởng Phân Quyền Navigation.
- **Nghiệp vụ:** BCERP = ERP nội bộ 5 phòng ban (BOD, HR, FINANCE, SALES, OPS) + Client Portal + 2 mobile apps; 19 vai người dùng trên web nội bộ; tích hợp 7 nền tảng QC.
- **v4.1 ERP rules:** Step 2.0 Screen Inventory + Consolidation bắt buộc trước khi chốt screen groups; R1–R12 ERP Working-Context Design Rules; data grid ERP; tab hoàn chỉnh; role-aware.
- **Registry screen_groups hiện rỗng** — Phase 2 Step 2.0 sẽ build screen inventory từ features + P3-01, không phụ thuộc field này.
- **Registry contract:** Phase 6 CHỈ được update field `ux_design_status` (hiện = "pending").

---

*This plan was auto-generated by DEVKIT `/wf-design-ux` skill.*
