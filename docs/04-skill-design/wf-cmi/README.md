# Cross-Module Integrity Orchestrator — Design Canon

> **Skill:** `wf-cmi` (v1.0.0, tên ngắn `wf-cmi`)
> **Owner:** orchestrator + architect + business-analyst team
> **Variant:** ❸ ORCHESTRATOR (spawn ≥3 lanes)
> **Cập nhật lần cuối:** 2026-05-16

---

## 1. Đọc theo persona

| Persona | Đọc trước |
|---------|-----------|
| **Skill author tạo skill mới (reference)** | 01-vision → **03-architecture** → 03-phase-routing → 04-file-contract → 07-procedures |
| **Skill author sửa wf-cmi** | 08-tradeoffs-adr → 03-architecture → 08-user-scenarios → file bị ảnh hưởng |
| **Reviewer review PR** | 09-evals → 04-file-contract → 03-architecture → 05-error-codes → file bị ảnh hưởng |
| **End-user gặp bug** | [`../../06-user-guides/per-skill/`](../../06-user-guides/per-skill/) (TBD) |
| **Stakeholder/PO** | 01-vision (§1-3) → 08-user-scenarios §1-2 |

---

## 2. Tóm tắt 1 dòng

`wf-cmi` (wf-cmi) — **AI Enterprise Integrity Orchestrator** chạy system-wide trên project ERP để build entity/workflow/event/permission graphs, infer + enforce business invariants liên module, đo coverage matrix 10 chiều (CD1-CD10) theo profile, phát hiện GAP và đề xuất artifact bổ sung (test/contract/invariant) qua CDG.

**Trigger:** `/wf-cmi [args]` (standalone — KHÔNG thuộc main pipeline)
**Phase trong workflow:** Standalone — gọi sau khi có code + phase docs (≥Phase 3 Architecture)
**Đầu vào chính:** `req-registry.json`, `phase1-business/`, `phase2-features/`, `phase3-architecture/`, code + CI index
**Đầu ra chính:** `integrity-report.md`, `coverage-matrix.json`, `business-invariants.json`, `regression-map.json`, `integrity-impact.json` (cross-skill)

**Variant ORCHESTRATOR:** Spawn 10 lane agents (CD1-CD10) song song qua `Agent({subagent_type, prompt})`, mỗi lane do 1 agent đặc thù chủ trì (xem [agent-prompt.md](agent-prompt.md)).

---

## 3. Files (12 — ORCHESTRATOR variant)

| # | File | Mục đích | Optional sections | Trạng thái |
|---|------|----------|-------------------|-----------|
| 00 | [00-master-checklist.md](00-master-checklist.md) | Gating 10-step trước commit | — | [x] |
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision + Mục tiêu + Non-goals | §7 Domain context (chạm 24 domain experts) | [x] |
| 02 | [02-arguments.md](02-arguments.md) | Args + defaults + validation | §5 Profile detail (có `--profile`) | [x] |
| 03a | [03-architecture.md](03-architecture.md) | **Kiến trúc tổng quan** — 10 components, data flow, parallelism, state machine, session output layout | §4 Parallelism, §8 State machine | [x] |
| 03b | [03-phase-routing.md](03-phase-routing.md) | 8 phases + flow diagram | §6 Regression-aware skipping (có `--since`) | [x] |
| 04 | [04-file-contract.md](04-file-contract.md) | PRE/POST gates + cross-skill artifacts | §6 Business invariants (bump sidecar artifact `business-invariants.json`) | [x] |
| 05 | [05-error-codes.md](05-error-codes.md) | Namespace E0xx + auto-fix budget | — | [x] |
| 05b | [05-execution-profiles.md](05-execution-profiles.md) | 4 profiles + lane dispatch matrix | — (BỔ SUNG cho 05-error-codes) | [x] |
| 06 | [06-templates-list.md](06-templates-list.md) | 12 templates output | — | [x] |
| 07 | [07-procedures-structure.md](07-procedures-structure.md) | `_shared.md` + 8 phase files outline | — | [x] |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 7 ADRs decisions lớn | — | [x] |
| 08b | [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md) | UX flows + 6 scenarios + recovery | — (BỔ SUNG cho 08-tradeoffs, ORCHESTRATOR variant) | [x] |
| 09 | [09-evals-test-cases.md](09-evals-test-cases.md) | 5+ test cases (smoke/integration/edge/resume/concurrent) | — | [x] |
| — | [agent-prompt.md](agent-prompt.md) | Template CORE-037 8-section cho 10 lane agents + triage | — | [x] |

> **Lưu ý 03-architecture vs 03-phase-routing:** Hai file bổ sung nhau, KHÔNG trùng lặp.
> - `03-architecture.md` tả **CẤU TRÚC** (cái gì có) — 10 components, data flow, integration points, session output layout.
> - `03-phase-routing.md` tả **TRÌNH TỰ** (chạy theo thứ tự nào) — 8 phase map, profile dispatch, conditional skip, regression-aware.
> - Sort alphabet: `03-architecture` < `03-phase-routing` (do `a` < `p`) → architecture đứng trước trong `ls`.

**Optional sections điền vì skill chạm engine tương ứng:**
- §7 Domain context (01-vision): wf-cmi spawn 24 domain experts cho CD1 Business domain coverage — Engine #14 + #15
- §5 Profile detail (02-arguments): có `--profile=quick|standard|deep|exhaustive` với threshold khác nhau
- §4 Parallelism (03-architecture): Phase 4 spawn 10 lanes parallel, Phase 3 Pass 2 max 5 domain experts (CORE-025)
- §8 State machine (03-architecture): Orchestrator main loop với CDG branches (E090/E091/E094) + per-lane retry x1
- §6 Regression-aware skipping (03-phase-routing): có `--since=<git-ref>` và consume `GitNexus.detect_changes()` — Engine #6
- §6 Business invariants (04-file-contract): wf-cmi **producer chính** của Business Invariant Registry — Engine #4 upgrade

---

## 4. Liên kết

- **Skill source (sẽ tạo sau khi design canon được duyệt):** [`.claude/skills/workflow/wf-cmi/`](../../../.claude/skills/workflow/) (SKILL.md, procedures/, _contract.json, evals/)
- **Plan gốc:** [`../../../plans/wf-cmi/wf-cmi.md`](../../../plans/wf-cmi/wf-cmi.md)
- **Standards áp dụng:** [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
- **Engines liên quan (15 engines):** #2 Workflow Orchestration, #3 Dependency Analysis, #4 Business Invariant Registry, #5 Cross-Module Verification, #6 Regression Intelligence, #7 GAP Detection, #8 Self-Healing, #10 Governance, #14 Domain Graph, #15 Business Rule Inference — xem [`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md)
- **Skill liên quan (tránh trùng):**
  - wf-fix-integration (QD10 lane) — wf-cmi **mở rộng** thành standalone system-wide
  - wf-fix-business-completeness (QD11) — wf-cmi **kế thừa** 3-pass inference pattern
  - wf-e2e-finding (F0a) — wf-cmi consume `cross-module-gaps.md` nếu có
  - wf-verify-sync — wf-cmi **producer** artifact mới cho wf-verify-sync consume
- **Patterns dùng:** `01-lazy-load-procedures`, `02-ci-first-integration`, `03-cross-skill-artifacts`, `05-agent-prompt-template`, `06-checkpoint-resume`
