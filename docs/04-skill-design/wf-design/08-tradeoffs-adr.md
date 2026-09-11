# 08 — Tradeoffs & ADR

> **Mục đích file:** 5 ADR-OPT (giống wf-analyze-requirements pattern) + 2 architectural decisions đặc thù wf-design.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Version |
|----|---------|--------|---------|
| ADR-OPT-01 | Phase 1+2 Lane Dispatch **per system** (không per dept) | ACCEPTED | v4.0.0 |
| ADR-OPT-02 | Session Isolation `sessions/{id}/` + DUAL-WRITE | ACCEPTED | v3.5.0 |
| ADR-OPT-03 | Phase 0.5 Workload Gate + LPM auto-detect | ACCEPTED | v4.0.0 |
| ADR-OPT-04 | Phase 3 Signal Aggregation **dual-dedup** (component_id + api_id) | ACCEPTED | v4.0.0 |
| ADR-OPT-05 | Template Strip recursive trước canonical write | ACCEPTED | v4.0.0 |
| ADR-design-01 | Phase 2 Option A — 3 specs trong cùng system lane | ACCEPTED | v4.0.0 |
| ADR-design-02 | Phase 7 Gap Analysis SEQUENTIAL, KHÔNG lane | ACCEPTED | v4.0.0 |

---

## 2. ADR-OPT-01: Lane Dispatch per system

**Context:** Multi-system project (CRM + SmartTax + EUREKA) cần design song song. v3.x sequential — 5 system × 30 min = 2.5h.

**Decision:** Lane per system (KHÔNG per dept như wf-analyze-requirements):
- Each system = 1 lane
- Conditional agents (ai-engineer, data-engineer, automation-architect) chạy TRONG cùng lane
- Max concurrent: `$LPM_PARAMS.max_parallel_agents` (Standard: 5, LPM: 3)

**Alternatives:**

| Option | Reason rejected |
|--------|----------------|
| Lane per dept (như analyze-requirements) | Dept không là natural boundary cho design — architecture là per-system |
| Lane per component | Quá granular, overhead spawn cao |

**Consequences:** 5 systems × 30 min sequential → ~12 min parallel (LPM 3 concurrent). Conditional agents trong lane → context sharing tốt.

---

## 3. ADR-OPT-02: Session Isolation

(Giống ADR-OPT-02 của wf-analyze-requirements — xem [`../wf-analyze-requirements/08-tradeoffs-adr.md`](../wf-analyze-requirements/08-tradeoffs-adr.md) §3)

Adapted cho wf-design: `sessions/{YYYYMMDD-HHMMSS}-{hash4}/` + DUAL-WRITE flat path + cleanup 5 most recent.

---

## 4. ADR-OPT-03: Workload Gate + LPM auto-detect

**Context:** v3.x không có gate → user không biết "design 6-system ERP mất 2h hay 6h?". Mid-large project blow context budget.

**Decision:** Phase 0.5 Workload Gate (3 zones) + LPM auto-detect:
- **LPM (Large Project Mode)** triggered khi: `systems ≥ 5 OR departments ≥ 10 OR requirements ≥ 50 OR features ≥ 40`
- LPM mode: compression sớm hơn, skeleton-first, checkpoint per phase
- Workload Gate: dead_zone <0.8, warn 0.8-1.5, block >1.5

**Consequences:** Large projects (≥5 systems) auto LPM mode → multi-session resume tự nhiên. User biết trước budget.

---

## 5. ADR-OPT-04: Signal Aggregation dual-dedup

**Context:** Phase 1+2 parallel → 2 systems có thể design cùng API endpoint `/api/users` hoặc cùng component `UserService`. Single-key dedup (chỉ `component_id`) bỏ sót API duplicate.

**Decision:** Dual-dedup:
- `component_id` (architecture components) → group
- `api_id` = `method + URL normalized` → group
- Cross-system duplicate với schema/contract khác → flag CONFLICT
- Conflicts route Phase 4 cross-validation resolve

**Alternatives:**

| Option | Reason rejected |
|--------|----------------|
| Single-key (component_id only) | Miss API duplicates |
| Triple-key (+ entity_id) | Overhead, hiếm khi entity conflict cross-system |

**Consequences:** 0 silent duplicate API endpoints. Explicit conflict handling Phase 4.

---

## 6. ADR-OPT-05: Template Strip recursive

(Giống ADR-OPT-05 của wf-analyze-requirements — xem [`../wf-analyze-requirements/08-tradeoffs-adr.md`](../wf-analyze-requirements/08-tradeoffs-adr.md) §6)

Adapted: Phase 8 strip cho `_meta/design-input-digest.json`, Phase 7 strip cho `action-items.json` (LEGACY).

---

## 7. ADR-design-01: Phase 2 Option A — 3 specs trong cùng system lane

**Context:** Phase 2 design 3 specs (api-contract, database-design, infra-spec) per system. Option B: 3 specs riêng lane → 3 × 5 = 15 lanes cho 5-system project → overhead spawn cao + context sharing kém. Option A: 3 specs cùng lane → context sharing tốt (architect biết DB schema khi design API).

**Decision:** Option A — 3 specs cùng system lane:
- Mỗi lane chứa: `architect` (API + integration) + `dba` (DB) + `devops` (infra)
- 3 agents work parallel trong cùng lane với shared system context
- 5-system project → 5 lanes (không 15)

**Alternatives:**

| Option | Reason rejected |
|--------|----------------|
| Option B (3 specs riêng lane) | Overhead + context sharing kém |
| Option C (sequential trong lane) | Quá chậm |

**Consequences:** 5-system: 5 lanes × 3 agents parallel = ~25 min. Context sharing tốt → DB schema khớp API contract.

---

## 8. ADR-design-02: Phase 7 Gap Analysis SEQUENTIAL

**Context:** Phase 7 cross-reference design với `module-code-mapping.json`. Multi-system project có cảm dỗ lane-ify Phase 7 per system. NHƯNG gap analysis cần holistic view — gap ở system A có thể link với code ở system B.

**Decision:** Phase 7 SEQUENTIAL, KHÔNG lane-ify:
- Single agent (`architect`) đọc toàn bộ `module-code-mapping.json`
- Cross-reference design (all systems) với code (all modules)
- Output: `gap-report.md`, `gap-categories.json`, `action-items.json`
- Template Strip áp dụng cho `action-items.json` canonical

**Alternatives:**

| Option | Reason rejected |
|--------|----------------|
| Lane per system Phase 7 | Mất holistic view, miss cross-system gaps |
| Skip Phase 7 cho new project | OK — Phase 7 đã chỉ chạy khi LEGACY_MODE |

**Consequences:** Phase 7 chậm hơn lane-ify (5-15 min) nhưng đầy đủ cross-system gaps. `action-items.json` consumed by `wf-plan-modules` làm priority input.

---

## 9. Liên kết

- ADR style: [Michael Nygard's template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ:
  - [`../wf-analyze-requirements/08-tradeoffs-adr.md`](../wf-analyze-requirements/08-tradeoffs-adr.md)
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
