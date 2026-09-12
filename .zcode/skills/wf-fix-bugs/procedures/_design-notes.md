# Design Notes & References — wf-fix-bugs

> Tách từ SKILL.md (compliance ≤500 dòng). Nội dung tham chiếu — không execution logic.

## References

| File                               | Purpose                                                                                                                                                                            |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `procedures/_shared.md`          | Cross-cutting protocols, state vars, CI detection, Playwright, agent prompts, error handling                                                                                       |
| `procedures/phase1-init.md`      | Phase 1 Init detail (18 steps v10.12 — Wave 1 + Wave 4 parallel waves, ISG fast-path bash bypass)                                                                                 |
| `procedures/phase2-scan.md`      | Phase 2 Scan detail (5 steps v10.4 — scan-and-analyze wrapper)                                                                                                                    |
| `procedures/phase3-plan.md`      | Phase 3 Plan detail (7 steps v10.5 — ISG + Partition + Route wrappers)                                                                                                            |
| `procedures/phase4-find-bugs.md` | Phase 4 Find Bugs detail (9 steps v10.6 — PARALLEL lane dispatch, Playwright)                                                                                                     |
| `procedures/phase5-triage.md`    | Phase 5 Triage detail (10 steps v10.7 — aggregate, triage, CDG, safety)                                                                                                           |
| `procedures/phase6-execute.md`   | Phase 6 Execute detail (7 steps v10.8 — CI impact, execute spawn, verify)                                                                                                         |
| `procedures/phase7-verify.md`    | Phase 7 Verify detail (8 steps v10.9 — CQG-1, CQG-2, 4 reports, finalize)                                                                                                         |
| `procedures/resume-status.md`    | --resume & --status handlers                                                                                                                                                       |
| `_contract.json`                 | Structured skill contract — inputs, outputs, templates, error codes, procedures, cross-skill contracts                                                                            |
| `.claude/skills/protocols/`      | Shared protocols (09, 10, 16, 19, 20)                                                                                                                                              |
| **Templates (36 files):**    |                                                                                                                                                                                    |
| `templates/phase1-init/`         | fix-status.json, Phase1-report.md                                                                                                                                                  |
| `templates/phase2-scan/`         | scope-analysis.json, code-inventory.json, doc-inventory.json, Phase2-report.md                                                                                                     |
| `templates/phase3-plan/`         | work-plan.json, dimension-plan.json, fix-workload.json, Phase3-report.md                                                                                                           |
| `templates/phase4-find-bugs/`    | lane-agent-prompt.md (v10.2 — canonical lane agent prompt), lane-signals.json, lane-status.json, QD-report.md, Phase4-report.md, probe-failures-log.json                          |
| `templates/phase5-triage/`       | issue-registry.json, bug-triage.md, fix-plan.md, fix-log.json, cdg-tokens.json, safety-check.json, process-violations.json, coverage-report.md, bug-dashboard.md, Phase5-report.md |
| `templates/phase6-execute/`      | fix-report.md, docs-sync-report.json, fix-execution-result.json, Phase6-report.md                                                                                                  |
| `templates/phase7-verify/`       | orchestrator-summary.md, fix-impact.json, phase-summary.md, Phase7-report.md                                                                                                       |
| `templates/_common/`             | session-log.json, error-ledger.json                                                                                                                                                |

---

## Design Rationale

### Tại sao cần skill này?

1. **11 dimensions (QD1-QD11)** — không skill nào khác cover toàn diện từ functional correctness (QD1) đến business completeness (QD11)
2. **Orchestrator pattern** — dispatch song song 10+ lane agents, aggregate signals, triage, execute — một mình user không thể làm manual
3. **CI-first** — GitNexus + Serena auto-detect giúp impact analysis chính xác trước khi sửa, tránh regression
4. **Playwright browser testing** — QD5/QD7/QD9 cần browser thật để phát hiện lỗi runtime, không thể làm bằng static analysis
5. **Multi-session** — pipeline 7 phase có thể kéo dài nhiều session, checkpoint + resume là bắt buộc

### Design Principles

1. **Lazy-load procedures (v10.0):** SKILL.md ~400 dòng routing, toàn bộ logic trong 9 procedure files + 37 templates. Giảm 70%+ context so với monolithic.
2. **CI-first (Protocol 20):** Mọi scan/impact analysis dùng GitNexus + Serena trước, graceful degradation về Grep/Glob
3. **Dimension isolation:** Mỗi QD lane chạy độc lập, không shared state, không cần coordination
4. **Signal aggregation:** Python CLI aggregate signals từ 11 lanes → dedup → severity classification → triage
5. **Safety gates:** CDG tại mọi critical decision point (E090-E093 browser/scope/cost/mobile, E100 recommendation)
6. **Cross-skill artifact:** `fix-impact.json` consumed bởi wf-verify-sync, wf-prepare-deployment, wf-implement-feature
7. **Playwright integration:** Headless default, visible với `--show-browser`, mobile emulation với `--mobile`. SEQUENTIAL across lanes để tránh conflict browser instances.
8. **Session isolation (CORE-030):** `sessions/{SESSION_ID}/` + lock + heartbeat + JSONL index

---

## Phase Anchors (Audit Compliance)
