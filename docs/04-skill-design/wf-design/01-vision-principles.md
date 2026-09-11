# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của `wf-design`.

---

## 1. Tóm tắt

`wf-design` giải quyết bài toán **"có feature specs rồi, nhưng dev cần biết: dùng tech stack gì? API contract ra sao? DB schema thế nào? Infra deploy ở đâu?"** bằng cách **orchestrate 7 agent types (architect + dba + devops + security + ai-engineer + data-engineer + automation-architect) qua 11 phases với Lane Dispatch per system** + **dual-dedup Signal Aggregation** + **Phase 7 Gap Analysis cho LEGACY**, sinh **technical specification docs đầy đủ**.

---

## 2. Vấn đề trước khi có skill

| Hiện trạng | Pain point |
|------------|-----------|
| Architect viết design thủ công, không có structured template | Inconsistent docs across projects, thiếu sections |
| Multi-system project: 5 systems × 5 design docs = 25 docs sequential | Tốn 2-3 ngày |
| DB schema + API contract + Infra spec viết tuần tự | Conflict không phát hiện sớm |
| LEGACY project: design lại từ đầu thay vì dùng existing code | Lãng phí, không reuse |
| Stakeholder review qua chat 1-1 | Slow, không formalized |
| Registry `design_status` không track | Không biết feature nào đã design |

**Ví dụ thực tế:** ERK Transport có 3 systems (CRM, SmartTax, EUREKA-2026). Trước v4.0: architect viết tuần tự P3-01-architecture cho 3 systems → 6 giờ + DB design 3 giờ + API contract 4 giờ + infra 2 giờ = 15 giờ. Với v4.0 Lane Dispatch: 3 systems chạy parallel (3 lanes), mỗi lane có architect + dba + devops cùng làm → 4-5 giờ. Signal aggregator dedup endpoints/entities trùng giữa systems.

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | Multi-system parallel design (Lane per system) | Phase 1 Lane Dispatch ADR-OPT-01. Eval TC-2 LPM |
| 2 | Dual-dedup Signal Aggregation (component_id + api_id) | Phase 3 ADR-OPT-04. Eval TC-1 |
| 3 | 7 conditional agent types — chỉ spawn khi project có | architect (always), dba (DB), devops (infra), security (Phase 5), ai-engineer ($HAS_AI_ML), data-engineer ($HAS_DATA_PIPELINE), automation-architect ($HAS_AUTOMATION) |
| 4 | LEGACY Phase 7 Gap Analysis — cross-ref code, không design lại | Phase 7 SEQUENTIAL, KHÔNG lane-ify. Eval TC-3 |
| 5 | `--from-scan` consume target-map cho legacy baseline | Sprint 5 cross-skill. Eval TC-6 |
| 6 | Registry safe-write `design_status` only | CORE-006 PRIMARY. Eval TC-1 |
| 7 | Multi-session resume LPM (large projects) | Eval TC-2 |
| 8 | Workload Gate trước commit (ADR-OPT-03) | Phase 0.5. Eval TC-5 |

---

## 4. Nguyên tắc thiết kế

1. **Lane Dispatch per system (ADR-OPT-01)** — Phase 1+2 mỗi system = 1 lane. Conditional agents (ai-engineer, data-engineer, automation-architect) chạy TRONG cùng lane của system đó. LPM override: SEQUENTIAL nếu tổng conditionals ≥ 3.

2. **Signal Aggregation dual-dedup (ADR-OPT-04)** — Phase 3 dedup theo CẢ `component_id` (architecture) VÀ `api_id` (API contract). Cross-system duplicate flagged, route Phase 4 cross-validation.

3. **7 agent types với conditional spawning** — `architect` (always Phase 1, 2, 3, 5), `dba` (Phase 2 DB), `devops` (Phase 2 infra), `security` (Phase 5 review), `ai-engineer` (`$HAS_AI_ML=true`), `data-engineer` (`$HAS_DATA_PIPELINE=true`), `automation-architect` (`$HAS_AUTOMATION=true`).

4. **Phase 7 Gap Analysis LEGACY-only** — Cross-reference design với `module-code-mapping.json` từ `wf-legacy-extract`. SEQUENTIAL (KHÔNG lane), output `gap-report.md`, `gap-categories.json`, `action-items.json`. Template Strip áp dụng.

5. **Workload Gate (ADR-OPT-03)** — Phase 0.5: 3 zones (dead_zone/warn/block). LPM detection: `systems ≥ 5 OR departments ≥ 10 OR requirements ≥ 50 OR features ≥ 40` → compression sớm + skeleton-first + checkpoint per phase.

6. **Session Isolation (ADR-OPT-02)** — `sessions/{YYYYMMDD-HHMMSS}-{hash4}/` với DUAL-WRITE backward-compat tới flat `.mc-data/work/wf-design/`.

7. **Template Strip (ADR-OPT-05)** — Phase 8: strip `_*` keys trước khi ghi canonical `_meta/design-input-digest.json`.

8. **CORE-032 Lazy-Load Procedures** — SKILL.md ~370 dòng. 11 procedure files lazy-load.

---

## 5. Non-goals (KHÔNG làm)

Để tránh scope creep:

- **Define features** — `/wf-define-features` làm (skill này CONSUME features đã định nghĩa)
- **Analyze business requirements** — `/wf-analyze-requirements` làm
- **UX/UI design** — `/wf-design-ux` làm (skill này chỉ technical design, không màn hình/wireframe)
- **Module planning + dependency graph** — `/wf-plan-modules` làm
- **Implement code** — `/wf-implement-feature` làm
- **Modify registry `features[]`, `requirements[]`, `impl_status`** — thuộc skill khác
- **Tự design module không có trong registry** — CORE-004 enforced

---

## 6. Tham chiếu

- Patterns:
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
  - [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md) — Lane per system
  - [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md) — `--from-scan` consume target-map
  - [`../../03-design-patterns/06-checkpoint-resume.md`](../../03-design-patterns/06-checkpoint-resume.md) — multi-session LPM

- Standards: CORE-004 (Registry SSOT), CORE-006 (Safe-Write `design_status`), CORE-013 (Module-code alignment LEGACY), CORE-021/022, CORE-032/035/038
