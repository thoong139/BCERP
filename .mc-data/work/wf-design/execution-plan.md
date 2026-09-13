# Execution Plan — /wf-design BCERP (Protocol 9 — PLN-08)

> Session: 20260913-053848-f4d7 | Design ID: DESIGN-20260913-001 | Created: 2026-09-13 05:38

## (a) Architecture Approach Decision

- **$APPROACH = Platform Design** — 6 systems trong registry (> 1 system).
- Lane Dispatch per system (ADR-OPT-01): mỗi system = 1 lane chạy P1 (architecture) + P2 (3 specs).
- Step 1.0 Business Context Baseline chạy SEQUENTIAL trong main conversation TRƯỚC lane dispatch (v4.1).
- LEGACY_MODE = false → tất cả decisions là [RECOMMENDED] (default, không ghi label).

## (b) Conditional Agent Selection

| Agent | Điều kiện | Quyết định |
|-------|-----------|-----------|
| `architect` | Always | SPAWN (per lane) |
| `ai-engineer` | $HAS_AI_ML | KHÔNG spawn — không có ML training/inference trong registry features |
| `data-engineer` | $HAS_DATA_PIPELINE | SPAWN — MOD-DATAHUB-BI (ETL connector vendor-agnostic, BI/BOD dashboard) |
| `automation-architect` | $HAS_AUTOMATION | SPAWN — SLA & Notification Engine + workflow automation cross-module |
| `dba` + `architect` | Phase 2 | SPAWN (database-design) |
| `devops` + `architect` | Phase 2 | SPAWN (infra-spec) |
| `security` | Phase 5 | SPAWN (gap analysis Phần D) |

LPM override: nếu tổng conditional agents >= 3 trong Phase 1 → SEQUENTIAL sau architect. Ở đây Phase 1 conditional = data-engineer + automation-architect (2) → vẫn chạy song song sau architect, trong giới hạn max_parallel = 3.

## (c) Execution Order

```
P0 Context (DONE) → P0.5 Workload Gate
  → P1 Step 1.0 Business Context Baseline (SEQUENTIAL, main conversation)
  → P1 Lane Dispatch (max 3 parallel):
      L1: SYS-BCERP-WEB (58 FEAT, 14 MOD)   ← lane lớn nhất
      L2: SYS-CORE-BACKEND (59 FEAT, 2 MOD)
      L3: SYS-INTEGRATION-GW (11 FEAT, 2 MOD)
      L4 (queue sau lane đầu rảnh): SYS-PORTAL-WEB (7) + SYS-MOBILE-INTERNAL (30) + SYS-MOBILE-PORTAL (5)
  → P2 Specs trong cùng lane (api-contract + database-design + infra-spec) — Option A
  → P3 Aggregation (dual dedup: component_id + api_id) + Integration Map (SEQUENTIAL)
  → P4 Cross-Validation 8 checks (SEQUENTIAL, ≤3 iterations)
  → P5 Stakeholder Review (PARALLEL: architect + security)
  → P6 Registry Safe-Write + Compressed Spec (SEQUENTIAL, main conversation)
  → P8 Digest + phase-summary + session log (SEQUENTIAL)
(LEGACY_MODE = false → P7 SKIP)
```

## (d) Token Estimate (Protocol 9.3)

| Hạng mục | Ước tính |
|----------|----------|
| Feature digest (file, agent đọc phần cần) | ~10.9K từ (~14K tokens) — nằm ở file, KHÔNG inject toàn bộ |
| Registry summary + business context | ~3K tokens |
| P3-01 (LPM 3000–6000 từ) + 4 spec files (LPM tổng ~10–18K từ) | ~20–30K tokens output |
| Agent spawns (6 lanes × P1+P2 + P3 + P5 ×2 + conditionals) | ~15 spawns |
| Cross-validation + review + finalize | ~15K tokens |
| **Tổng ước tính workflow** | **~120–180K tokens → chắc chắn multi-session (checkpoint tại 80%)** |

## Contingency

- Context ≥ 65%: finish current phase, checkpoint.
- Context ≥ 80%: FORCE SAVE → user chạy `--resume` (session-state next_action dẫn đường).
- Agent timeout: re-spawn 1 lần → skip + WARNING (E003).
- Conflict kiến trúc giữa lanes: flag + present options (E004).
