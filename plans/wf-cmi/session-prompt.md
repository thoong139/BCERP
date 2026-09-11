# Session Re-Entry Prompt — Skill `wf-cmi` Implementation

> **Mục đích:** Prompt khởi động cho session Claude Code mới để triển khai skill `wf-cmi`. Đọc file này NGAY khi bắt đầu session — đảm bảo context đầy đủ trước khi code.

---

## Khởi động session mới — Copy paste prompt sau

```
Tôi đang triển khai skill `wf-cmi` (cross-module integrity) cho MCV3 framework.
Đây là phiên làm việc tiếp theo, design canon đã hoàn thành.

Đọc các tài liệu sau theo thứ tự trước khi bắt đầu code:

1. plans/wf-cmi/session-prompt.md (file này — context tóm tắt)
2. plans/wf-cmi/progress.md (tracking tasks done + pending)
3. plans/wf-cmi/wf-cmi.md (plan gốc từ user)
4. docs/04-skill-design/wf-cmi/README.md (index 14 files design canon)
5. docs/04-skill-design/wf-cmi/00-master-checklist.md (gating 10-step)

Sau đó, đọc các file design canon liên quan tới task hiện tại (theo Step trong progress.md).

Quy tắc bắt buộc:
- Tuân thủ CLAUDE.md (BHV-001 đến BHV-004 + CORE-001 đến CORE-038)
- Skill nằm tại `.claude/skills/workflow/wf-cmi/` (CHƯA tạo)
- KHÔNG bump registry v3 — dùng sidecar artifact `.mc-data/work/wf-cmi/business-invariants.json` (ADR-cmi-002 Revised)
- SKILL.md ≤500 dòng (CORE-032 lazy-load)
- 10 procedures lazy-load tại `procedures/` (8 phases + _shared + resume-status)
- 18 templates output tại `templates/`
- 5 test cases tại `evals/evals.json`
- Cross-skill artifact `integrity-impact.json` schema `integrity-impact-v1`

Bước tiếp theo: xem progress.md mục "Next step".
```

---

## Tóm tắt context cốt lõi

### Skill identity

- **Tên:** `wf-cmi` (Cross-Module Integrity)
- **Loại:** Standalone Orchestrator skill (cùng nhóm wf-scan-target, wf-diagram)
- **Slash command:** `/wf-cmi`
- **Variant:** ❸ ORCHESTRATOR (spawn ≥3 lanes — thực tế 10 lanes CD1-CD10)
- **Target ban đầu:** EUREKA-2026 ERP (D:\EUREKA-2026, 17 modules .NET 10 + Next.js)

### Quyết định kiến trúc đã chốt (8 ADRs)

1. **ADR-cmi-001:** Standalone, KHÔNG phải lane QD12 trong wf-fix-bugs
2. **ADR-cmi-002 (Revised):** Sidecar artifact `.mc-data/work/wf-cmi/business-invariants.json`, **KHÔNG bump registry v3**
3. **ADR-cmi-003:** 10 lanes parallel max concurrency 10 (CORE-025)
4. **ADR-cmi-004:** 3-pass LLM inference kế thừa QD11
5. **ADR-cmi-005:** Multi-session R/W lock qua Protocol 22
6. **ADR-cmi-006:** Self-healing v1 chỉ ĐỀ XUẤT, không auto-apply
7. **ADR-cmi-007:** Cross-skill artifact bundle `integrity-impact.json` cho 4 consumers
8. **ADR-cmi-008:** 10 dimensions CD1-CD10 cố định v1, defer CD11+ v2

### 8 Phases

1. **Init + CI PRE-GATE** (`phase1-init.md`)
2. **Discovery** — Build 6 graphs (`phase2-discovery.md`)
3. **Invariant Artifact** (`phase3-invariant-artifact.md` — đổi tên từ "registry")
4. **Coverage Dispatch** — Spawn 10 lanes (`phase4-coverage-dispatch.md`)
5. **Aggregate** (`phase5-aggregate.md`)
6. **Regression Map** (`phase6-regression.md`)
7. **GAP + CDG** (`phase7-gap-cdg.md`)
8. **Report** (`phase8-report.md`)

### 10 Coverage Dimensions (CD1-CD10)

| CD | Dimension | Agent chính |
|----|-----------|-------------|
| CD1 | Business domain coverage | business-analyst + 24 domain experts |
| CD2 | Entity dependency | architect + dba |
| CD3 | Workflow coverage | architect + business-analyst |
| CD4 | API contract | api-tester + architect |
| CD5 | Event coverage | architect + data-engineer |
| CD6 | Permission/RBAC | security + business-analyst |
| CD7 | Data integrity | dba + data-engineer |
| CD8 | Observability | sre + devops |
| CD9 | Regression coverage | qa-lead + architect |
| CD10 | Documentation | tech-writer + business-analyst |

### 4 Profiles + Threshold

| Profile | Threshold | Duration EUREKA | Lanes active |
|---------|-----------|-----------------|--------------|
| quick | ≥60% | 5-10 min | 5 (CD1,2,3,4,7) |
| standard (default) | ≥80% | 15-30 min | 7 (+CD5,6,9) |
| deep | ≥95% | 45-90 min | 10 (all) |
| exhaustive | 100% | 120-180 min | 10 + LLM enhance |

### Error code namespace

| Range | Phase |
|-------|-------|
| E001-E009 | Shared (lock, session, context) |
| E010-E019 | Phase 1 (Init + CI PRE-GATE) |
| E020-E029 | Phase 2 (Discovery) |
| E030-E039 | Phase 3 (Invariant) |
| E040-E049 | Phase 4 (Coverage Dispatch) |
| E050-E059 | Phase 5 (Aggregate) |
| E060-E069 | Phase 6 (Regression) |
| E070-E079 | Phase 7 (GAP + CDG) |
| E080-E089 | Phase 8 (Report) |
| E090-E099 | CDG user-facing gates |
| E100-E109 | Warnings (non-blocking) |

### Files Design Canon (đã có)

Tất cả tại `docs/04-skill-design/wf-cmi/` (14 files, ~227 KB):

| # | File | Purpose |
|---|------|---------|
| 1 | README.md | Index + persona guide |
| 2 | 00-master-checklist.md | Gating 10-step pre-PR |
| 3 | 01-vision-principles.md | Vision + 8 SMART goals + §7 Domain context |
| 4 | 02-arguments.md | 15 args + profile detail |
| 5 | 03-phase-routing.md | 8 phases + Mermaid flow + §6 regression-aware |
| 6 | 04-file-contract.md | PRE/POST gates + 6 schemas + §6 Business invariants sidecar pattern |
| 7 | 05-error-codes.md | E001-E109 namespace + auto-fix budget |
| 8 | 05-execution-profiles.md | 4 profiles + lane activation matrix |
| 9 | 06-templates-list.md | 18 templates output |
| 10 | 07-procedures-structure.md | 10 procedure files lazy-load |
| 11 | 08-tradeoffs-adr.md | 8 ADRs decisions lớn |
| 12 | 08-user-scenarios-solutions.md | 6 UX scenarios + error recovery |
| 13 | 09-evals-test-cases.md | 8 test cases (smoke→concurrent→CI→dry-run) |
| 14 | agent-prompt.md | CORE-037 8-section template cho 10 lanes + triage |

### Files Skill Code (sẽ tạo)

Tất cả sẽ ở `.claude/skills/workflow/wf-cmi/`:

```
wf-cmi/
├── SKILL.md                    ← ≤500 dòng lean routing hub
├── _contract.json              ← schema skill-contract-v1
├── procedures/                 ← 10 files lazy-load
│   ├── _shared.md
│   ├── phase1-init.md
│   ├── phase2-discovery.md
│   ├── phase3-invariant-artifact.md
│   ├── phase4-coverage-dispatch.md
│   ├── phase5-aggregate.md
│   ├── phase6-regression.md
│   ├── phase7-gap-cdg.md
│   ├── phase8-report.md
│   └── resume-status.md
├── templates/                  ← 18 templates
│   ├── integrity-status.json
│   ├── entity-graph.json
│   ├── ... (6 graphs)
│   ├── business-invariants.json
│   ├── coverage-matrix.json
│   ├── regression-map.json
│   ├── integrity-impact.json
│   ├── signals.json
│   ├── gap-suggestions.json
│   ├── Phase1..Phase8-report.md
│   ├── integrity-report.md
│   ├── coverage-report.md
│   ├── gap-report.md
│   └── regression-report.md
├── evals/
│   └── evals.json              ← 5 test cases
└── scripts/                    ← Bash + Python helpers
    ├── cmi-build-entity-graph.sh
    ├── cmi-coverage-aggregate.py
    └── cmi-invariant-validator.py
```

### Cross-skill artifact contract

**Producer:** wf-cmi
**Artifact:** `integrity-impact.json` schema `integrity-impact-v1`
**Path:** `.mc-data/work/wf-cmi/sessions/{id}/phase8-report/integrity-impact.json`

**Consumers (opt-in qua flag):**
- `wf-verify-sync --from-cmi`
- `wf-fix-bugs --from-cmi`
- `wf-implement-feature --from-cmi`
- `wf-prepare-deployment --from-cmi`

**Sidecar artifact (canonical, KHÔNG registry):**
- Path: `.mc-data/work/wf-cmi/business-invariants.json`
- Schema: `business-invariants-v1`
- Update: APPEND-only sau CDG E094 ACCEPT
- audit_chain.source_registry_checksum để detect stale

---

## Quy tắc chốt khi triển khai

1. **KHÔNG bump registry** — `req-registry.json` v1/v2 unchanged, wf-cmi chỉ READ
2. **SKILL.md ≤500 dòng** (CORE-032) — lean routing hub
3. **Procedures lazy-load** — Mỗi `phase{N}-*.md` chỉ đọc khi tới phase
4. **Output từ template** (CORE-031) — READ template → POPULATE → strip metadata → ATOMIC WRITE
5. **Agent prompt 8 sections** (CORE-037) — xem [agent-prompt.md](../../docs/04-skill-design/wf-cmi/agent-prompt.md)
6. **Session isolation** (CORE-030, CORE-035) — `$SESSION_DIR = .mc-data/work/wf-cmi/sessions/{YYYY-MM-DD-{scope}-{slug}-NN}/`
7. **Multi-session R/W lock** (Protocol 22) — read-heavy phases không block
8. **Tiếng Việt** cho user-facing prose (Phase reports ≤15 dòng, integrity-report ≤30 dòng)
9. **Cross-skill artifact** phải có `$schema` + `audit_chain.source` + `audit_chain.checksum` (CORE-036)
10. **Atomic write** mọi JSON state (.tmp.$$ → validate → mv)

---

## Liên kết

- Plan gốc: [wf-cmi.md](wf-cmi.md) (yêu cầu từ user)
- Design canon: [docs/04-skill-design/wf-cmi/](../../docs/04-skill-design/wf-cmi/)
- Progress tracker: [progress.md](progress.md)
- CLAUDE.md (project rules): [../../CLAUDE.md](../../CLAUDE.md)
- Target project: D:\EUREKA-2026 (ERP logistics Việt-Trung, 17 modules .NET 10)
