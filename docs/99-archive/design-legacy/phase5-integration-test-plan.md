# Phase 5 — Integration Test Plan

> **Tạo:** 2026-04-23
> **Trạng thái:** IMPLEMENTED — test infrastructure + 8 scenarios PASS (57/57).
> **Prerequisite:** Phase 4 sign-off PASS.

---

## 1. Mục tiêu Phase 5

1. E2E test trên 1 project nhỏ (3-5 modules, 2-3 systems).
2. Verify `sessions/{id}/` + `latest` pointer chuyển đúng giữa skills.
3. Verify `--resume` ở mọi skill (kill giữa chừng → resume đúng state).
4. Verify multi-run không đè session cũ (cleanup giữ 5 sessions).
5. Verify workload gate + CDG override + anti-loop guard (`_shared/partition`, `_shared/cdg`).
6. Verify lane dispatch + signal aggregation (`_shared/lane`, `_shared/aggregate`) không mất data.

---

## 2. Test Scenarios

| ID | Scenario | Expected | Status |
|----|----------|----------|--------|
| A | New project full path (10 skills) | Full `.mc-data/docs/` tree, no `_template_notes` leak | PASS (8 tests) |
| B | Existing project full path (13 skills) | LEGACY_MODE detect, `legacy-decisions.json` propagate, gap analysis integrate | PASS (8 tests) |
| C | Feature addition (5 skills) | Registry append-only, existing features unchanged | PASS (7 tests) |
| D | Resume mid-phase (P0.5, P-lane, P-aggregate) | `session-state.json` preserves position, resume đúng phase | PASS (6 tests) |
| E | Workload BLOCK + CDG-A02 override + anti-loop | `cdg-tokens.json` có accept, skill complete, không loop | PASS (12 tests) |
| F | API-only (conditional skip wf-design-ux) | `ux-input-digest.json` KHÔNG canonical, wf-plan-modules bypass UX OK | PASS (5 tests) |
| G | Session cleanup | Sau 7 runs → `ls sessions/` == 5 | PASS (6 tests) |
| H | Concurrent lane write scope isolation | 5 lanes parallel không lock contention, không mất data | PASS (5 tests) |

---

## 3. Success Criteria

- [x] 8 scenarios A-H PASS
- [x] Canonical `_meta/*.json` không `_template_notes` (jq verify)
- [x] `latest` pointer đúng (`find_latest_session` returns newest by mtime)
- [x] `req-registry.json.impl_status` không downgrade (diff before/after)
- [x] Cleanup giữ đúng 5 sessions (Scenario G)
- [x] Không race condition / file corruption
- [x] Workload gate thresholds (0.8 / 1.5) trigger đúng
- [x] CDG flow không infinite loop (Scenario E)

---

## 4. Test Project Specs

- **Project A (new):** 3 systems × 2 modules × 3 features = 18 features, web+mobile
- **Project B (legacy):** 2 systems, 5 modules, React+Node+Postgres, doc trust ~60%
- **Project C (feature addition):** Base = Project A done + add 1 module × 3 features

---

## 5. Test Infrastructure

### Cấu trúc thư mục

```
tools/
├── integration-test.py          # CLI entry point (run/validate/report)
├── pyproject.toml               # pytest config
├── conftest.py                  # Shared fixtures
├── fixtures/
│   ├── project_a.py             # New project: 3 sys × 2 mod × 3 feat
│   ├── project_b.py             # Legacy project: 2 sys, 5 mod
│   └── project_c.py             # Feature addition: base A + 1 mod
├── validators/
│   ├── schema_validator.py      # JSON schema + _template_notes check
│   ├── path_contract.py         # Cross-skill path validator (23 contracts)
│   ├── registry_validator.py    # impl_status no-downgrade, append-only
│   └── session_validator.py     # Session isolation, cleanup, history
├── scenarios/
│   ├── test_a_new_project.py    # 8 tests
│   ├── test_b_legacy_project.py # 8 tests
│   ├── test_c_feature_add.py    # 7 tests
│   ├── test_d_resume.py         # 6 tests
│   ├── test_e_workload_cdg.py   # 12 tests
│   ├── test_f_api_only.py       # 5 tests
│   ├── test_g_session_cleanup.py # 6 tests
│   └── test_h_concurrent.py     # 5 tests
└── report/
    └── report_generator.py      # Markdown/JSON report generation
```

### Cách chạy

```bash
# Chạy tất cả 8 scenarios
cd tools && python -m pytest scenarios/ -v

# Chạy 1 scenario
cd tools && python integration-test.py run --scenario E

# Validate .mc-data/ hiện có
cd tools && python integration-test.py validate --dir ../.mc-data

# Tạo báo cáo
cd tools && python integration-test.py report --format md
```

### Reuse existing code

| Module | Dùng trong |
|--------|-----------|
| `_shared/ips/workload_gate.py` | Scenario E |
| `_shared/partition_planner.py` | Scenarios E, H |
| `_shared/signal_aggregator.py` | Scenario H |
| `_shared/signal_bus/signal_bus.py` | Scenario H |
| `_shared/profile_resolver.py` | Scenario H |

---

## 6. Defects Severity

| Severity | Action |
|----------|--------|
| Critical | STOP Phase 5 — escalate Phase 3 rollback |
| High | Fix + re-run scenario |
| Medium | Log + patch release |
| Low | Log + batch fix |

---

## 7. Phase 5 Exit Criteria

- [x] 8 scenarios PASS, Zero Critical + Zero High
- [x] Test infrastructure implemented (`tools/`)
- [x] 57/57 tests pass in 0.53s
- [x] Defects logged `phase5-defects-log.md` (none found)
- [x] Report capability via `integration-test.py report`
- [x] Tag `adr-opt-phase5-complete`

---

## 8. Tham chiếu

- `docs/design/skills/ADR-downstream-skills-optimization.md`
- `docs/design/skills/phase4-documentation-signoff.md`
- `.claude/rules/00-core.md §4b`
- `.claude/skills/protocols/10-post-gate-schema.md` (T1-T4)
- `.claude/skills/protocols/16-critical-decision-gate.md` (CDG-A02)
