# Requirements Analysis Plan

> **Mục đích:** Kế hoạch chi tiết để phân tích requirements với BA + Domain Experts cho BCERP.
> **Ai viết:** AI tự động generate khi chạy `/wf-analyze-requirements`
> **Khi viết:** Phase 2 của analyze-requirements skill
> **Cập nhật:** Tự động cập nhật sau mỗi phase hoàn thành

---

## Meta Information

| Mục | Giá trị |
|-----|---------|
| **Analyze ID** | `ANALYZE-20260912-001` |
| **Project** | `BCERP` |
| **Scope** | `all` |
| **Created** | 2026-09-12 00:55 |
| **Last Updated** | 2026-09-12 00:55 |
| **Status** | 🔄 In Progress |
| **Session** | `20260911-174442-750a` |
| **Large Project Mode** | **TRUE** (registry.systems.length = 6 ≥ 5) → $MAX_PARALLEL_AGENTS = 3, checkpoint sau MỖI phase, output targets LPM |

---

## 1. Project Context

| Mục | Giá trị |
|-----|---------|
| **Project Name** | BCERP — ERP nội bộ cho BC Agency (digital marketing agency) |
| **Domain** | ERP đa phân hệ cho agency: tài chính giữ hộ TKQC + CRM V6.0 + OPS campaign + HR + Client Portal multi-tenant |
| **Source** | `new` |
| **Has Existing Docs** | NO (`legacy-scan/doc-mapping.json` không tồn tại) |
| **Registry Status** | VALID — seed đầy đủ: 6 systems, 5 departments, interface_type=web+mobile; modules[]/requirements[] chờ populate |
| **LEGACY_MODE** | false |
| **$DEPRECATED_MODULES** | [] |

---

## 2. Scope Definition

**Applied Scope:** `all` — toàn bộ 5 departments + P1-02 + stakeholder-review + conflict resolution.

**In Scope:**
- 5 departments: DEPT-BOD, DEPT-HR, DEPT-FINANCE, DEPT-SALES, DEPT-OPS
- 19 phân hệ (P0-01 §3.1) ánh xạ vào departments
- 20 chính sách đã soạn (phase0-brainstorm/policies/) làm nguồn ràng buộc nghiệp vụ
- Cross-dept workflow, stakeholder review 3 góc, conflict resolution

**Out of Scope:**
- Feature specs / UI / API / DB (thuộc `/wf-define-features` và `/wf-design`)
- Phần mềm kế toán hiện hữu (chỉ tích hợp, không thay thế)
- OMS/WMS cho TikTok Shop (chỉ monitoring)

---

## 3. Domain Experts Plan

### 3.1 Experts Selection ($EXPERT_LIST — union Section 1 + pattern Section 2, dedup)

| # | Expert | Department (Phần B) | Focus Area | Spawn Mode | Status |
|---|--------|---------------------|------------|------------|--------|
| 1 | `business-analyst` | All (Phần A) + DEPT-BOD (Phần B) | Stakeholders, user needs, phê duyệt ngưỡng, BI/BOD oversight | Sequential FIRST, per-dept parallel | ⬜ |
| 2 | `hr-expert` | DEPT-HR | Hồ sơ L1–L5, chấm công, Cost Rate Card, KPI 3 trụ cột, timesheet/capacity | Parallel | ⬜ |
| 3 | `finance-expert` | DEPT-FINANCE (call-1) | Ví TKQC, đối soát 3 số đa tiền tệ, công nợ AR/AP, giải ngân SoD | Parallel | ⬜ |
| 4 | `compliance-expert` | DEPT-FINANCE (call-2 — heavyweight split) | AML/KYC, audit log retention, HĐĐT/VAS, PDPA dữ liệu tài chính | Parallel (batch sau call-1) | ⬜ |
| 5 | `sales-expert` | DEPT-SALES | Pipeline V6.0, quotation/deal desk GM, hoa hồng/quota, handoff | Parallel | ⬜ |
| 6 | `paid-media-expert` | DEPT-OPS (call-1) | Ad Account Command Center 2.600+ TK, wallet ops, TikTok Shop, degraded mode | Parallel | ⬜ |
| 7 | `marketing-expert` | DEPT-OPS (call-2 — heavyweight split) | Lifecycle V6.0 stage-gate, proposal/planning, campaign & deliverable, Brand Safety | Parallel | ⬜ |
| 8 | `customer-expert` | (supporting — không sở hữu dept) | SLA ma trận tier×priority, ticket/CSAT, portal minh bạch | On-call cho 6d EXPERT-RESOLVE | ⬜ |
| 9 | `data-expert` | (supporting) | Metric catalog, star schema, freshness SLA, BI | On-call cho 6d | ⬜ |
| 10 | `legal-expert` | (supporting) | Hợp đồng/NDA/Brand Safety clause, NĐ 13/2023, GDPR/CCPA | On-call cho 6d | ⬜ |
| 11 | `operations-expert` | (supporting) | Quy trình vận hành tổng hợp | On-call cho 6d | ⬜ |
| 12 | `ecommerce-expert` | (supporting — pattern ERP+Portal/TMĐT) | TikTok Shop, portal commerce | On-call cho 6d | ⬜ |

> **Ướp theo BC Agency context (docs/00-overview/00-company-context.md):** paid-media-expert + marketing-expert là 2 expert TRUNG TÂM — đã được xếp ownership chính cho DEPT-OPS (end user chính, 2 calls split). compliance-expert nằm trong danh sách ưu tiên — xếp call-2 cho DEPT-FINANCE.

### 3.2 Expert → Department Assignment (Phần B — quy tắc 1 dept = 1 expert/call)

| Department | Phần B owner | Heavyweight? | Lý do split |
|-----------|--------------|--------------|-------------|
| DEPT-BOD | `business-analyst` | No | 3 areas (phê duyệt ngưỡng, P&L/BI oversight, audit/risk alert) — cùng domain quản trị |
| DEPT-HR | `hr-expert` | No | 1 domain nhân sự (hồ sơ, chấm công, rate card, KPI) |
| DEPT-FINANCE | `finance-expert` (call-1) + `compliance-expert` (call-2) | **YES (5 areas)** | Ví/đối soát/công nợ/giải ngân ≠ AML-KYC/audit retention/HĐĐT/PDPA — 2 domain độc lập |
| DEPT-SALES | `sales-expert` | No | 1 domain sales (pipeline, giá, hoa hồng, handoff) |
| DEPT-OPS | `paid-media-expert` (call-1) + `marketing-expert` (call-2) | **YES (5 areas)** | Ads ops + TikTok Shop ≠ lifecycle V6.0 + campaign/deliverable + SLA/ticket — 2 domain độc lập |

### 3.3 Expert Batching Strategy (LPM — max 3 song song)

- **Batch BA (Phase 3):** [BOD, HR, FINANCE] → [SALES, OPS] — 2 batches
- **Batch Experts (Phase 4):** [BOD-PhầnB, HR, FIN-call1] → [FIN-call2, SALES, OPS-call1] → [OPS-call2] — 3 batches
- Context budget per expert: ~10K tokens (đường dẫn tài liệu, không paste toàn văn)

---

## 4. Existing Documentation

Không có (source=new, HAS_EXISTING_DOCS=false). Nguồn duy nhất: `phase0-brainstorm/` (P0-01, P0-02, policies/ 20 file) + `documents/` của công ty.

---

## 5. Phase Plan

Xem `execution-plan.md` (Protocol 9.2) — chi tiết thứ tự, agent, token estimate.

---

## 6. Expected Outputs

| File | Phase | Department | Status |
|------|-------|------------|--------|
| `departments/bod/bod.md` (A+B) | 3+4 | DEPT-BOD | ⬜ |
| `departments/hr/hr.md` (A+B) | 3+4 | DEPT-HR | ⬜ |
| `departments/finance/finance.md` (A+B, 2 calls) | 3+4 | DEPT-FINANCE | ⬜ |
| `departments/sales/sales.md` (A+B) | 3+4 | DEPT-SALES | ⬜ |
| `departments/operations/operations.md` (A+B, 2 calls) | 3+4 | DEPT-OPS | ⬜ |
| `P1-01-project-overview.md` | 3 | — | ✅ (đã điền từ brainstorm) |
| `P1-02-business-workflow.md` | 6b | cross-dept | ⬜ |
| `stakeholder-review.md` | 6c/6d | — | ⬜ |

Registry sẽ được populate: `modules[]` (~19 phân hệ), `requirements[]` (target ~80–150 REQ), `interface_type` giữ nguyên web+mobile.

---

## 7. Checkpoint Strategy

LPM: checkpoint sau MỖI phase (L1 Phase level; L2 Batch cho Phase 3/4). Token threshold: ≥65% finish batch + checkpoint; ≥80% không spawn thêm; ≥90% force stop.

## 8. Conflict Resolution Plan

Theo Phase 6d 4 tracks (AUTO / EXPERT / BLOCKING / DEFER). Expert on-call: customer, data, legal, operations, ecommerce. Ghi log conflict tại stakeholder-review.md.

## 9. Notes

- BC Agency đặc thù: tiền giữ hộ ≠ doanh thu; Financial Hard Stop; SoD 4 vai; kiêm nhiệm CFO/CTO cần compensating control — mọi dept analysis phải tôn trọng 4 trụ cột này.
- Chưa có quyền API 7 nền tảng → mọi REQ liên quan integration phải có degraded mode (nhập tay gắn nhãn "manual").
- Định mức nền (giờ/tuần L1–L5, cost-per-hour, SLA theo tier) chưa có con số — experts đề xuất khung + đánh dấu [CẦN CHỐT SỐ] thay vì bỏ trống.

---

> Trạng thái: PLAN COMPLETE — 2026-09-12T00:58:00+07:00

*This plan was auto-generated by DEVKIT `/wf-analyze-requirements` skill.*
