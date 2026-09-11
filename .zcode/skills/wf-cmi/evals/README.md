# wf-cmi Evals

> **18 test cases** cho skill `wf-cmi` (Cross-Module Integrity Orchestrator):
> - **5 v1 cases** (TC-cmi-001 → TC-cmi-005) — Pipeline core, profiles, error handling, resume, concurrency
> - **8 v2 cases** (TC-cmi-006 → TC-cmi-013) — Wave dispatch, SSOT enforcement, 26-lane deep, logistics-critical, compliance, NEW additions, backward-compat, status query
> - **5 v3 cases** (TC-cmi-014 → TC-cmi-018) — E2E Scenario Engine: v3 backward-compat (no exec flag), CD41 synth, Phase 9 execute fail → Phase 10 auto-fix, source-fix loop-back, stable-registry hit

---

## Test cases (v1 — Pipeline core)

| ID | Type | Fixture | Profile | Duration | Pass criteria chính |
|----|------|---------|---------|----------|---------------------|
| [TC-cmi-001](../../../../tests/fixtures/wf-cmi/minimal/) | smoke | minimal/ (1 mod CRM) | quick | <5 min | 5 lanes active, exit 0, coverage ≥60% |
| [TC-cmi-002](../../../../tests/fixtures/wf-cmi/realistic/) | integration | realistic/ (3 mods) | standard | 15-30 min | 7 lanes, ≥10 invariants, coverage ≥80% |
| [TC-cmi-003](../../../../tests/fixtures/wf-cmi/corrupt/) | edge | corrupt/ (registry break) | standard | <10 min | E039 + auto-fix 3 retries + ESCALATE, exit 2 |
| [TC-cmi-004](../../../../tests/fixtures/wf-cmi/realistic/) | resume | realistic/ (interrupted) | standard | <10 min | Resume from Phase 4, skip 6 PASS lanes |
| [TC-cmi-005](../../../../tests/fixtures/wf-cmi/concurrent/) | concurrent | concurrent/ (2 sessions) | standard+deep | ~30 min | R/W lock OK, E090b CDG nếu write conflict |

## Test cases (v2 — Wave dispatch + new lanes)

| ID | Type | Fixture | Profile | Duration | Pass criteria chính |
|----|------|---------|---------|----------|---------------------|
| TC-cmi-006 | wave-subset | v2-wave1/ (CD11+CD16+CD17) | deep --dims | <10 min | Wave 1 only, W2+W3 SKIPPED, integrity-impact-v2 lanes_v2.active=3 |
| TC-cmi-007 | ssot-missing | v2-ssot-missing/ (no RBAC SSOT) | deep --dims=CD15 | <5 min | E144 ESCALATE, no fallback heuristic, exit 2 |
| TC-cmi-008 | full-26-lanes | v2-full/ (5 mods + 9 SSOTs) | deep | 55-90 min | 3-wave dispatch (W1=10/W2=10/W3=6), coverage ≥95%, integrity-impact-v2 |
| TC-cmi-009 | logistics-★★★ | v2-logistics/ (multi-currency) | deep --dims=CD28,30,31 | <20 min | MDM+TIME+MONEY/TAX signals, VND/CNY/USD, must_severity_count populated |
| TC-cmi-010 | compliance | v2-compliance/ (PII + cross-border) | deep --dims=CD29,37 | <15 min | AUDIT+COMP signals, PII_READ_NOT_LOGGED MUST VN-PDPL, cross-lane no dup |
| TC-cmi-011 | new-additions | v2-newadds/ (UI+error+print) | deep --dims=CD38,39,40 | <15 min | UI/ERR/DOC signals, e-invoice VN, ERROR_MESSAGE_NOT_VIETNAMESE check |
| TC-cmi-012 | backward-compat | v1-legacy/ (v1 reader + v2 artifact) | quick | <5 min | v1 fields preserved, v2 fields ignored gracefully, $schema detect |
| TC-cmi-013 | status-query | realistic/ (post-deep) | --status | <1 min | Read-only, no lock acquire, no agent spawn, tiếng Việt summary table |

## Test cases (v3 — E2E Scenario Engine)

| ID | Type | Fixture | Profile + flags | Duration | Pass criteria chính |
|----|------|---------|-----------------|----------|---------------------|
| [TC-cmi-014](../../../../tests/fixtures/wf-cmi/v3-backward-compat/) | backward-compat-v3 | v3-backward-compat/ (no exec) | standard | <10 min | v3 schema artifact với e2e_execution_summary=null + scenarios_artifacts=[]. v1+v2 fields preserved 100%. Phase 9-10 SKIP. integrity-report.md ≤55 dòng (NO E2E section) |
| [TC-cmi-015](../../../../tests/fixtures/wf-cmi/v3-cd41-synth/) | cd41-synth | v3-cd41-synth/ (3 MUST cross-module) | deep | <15 min | CD41 Wave 3 active. scenarios-manifest total_valid ≥1 + ≥1 cross-module. signal E2E_SCENARIO_SYNTHESIZED. Phase 9 SKIP (no --exec-scenarios) |
| [TC-cmi-016](../../../../tests/fixtures/wf-cmi/v3-phase9-fail/) | phase9-execute | v3-phase9-fail/ (5 scenarios, 2 FAIL) | deep --exec-scenarios | <30 min | Phase 9 execute 5: 3 PASS + 2 FAIL → Phase 10 auto-trigger → Phase A browser-fix → 2 AUTO_CORRECTED. integrity-report.md ≤70 dòng (v3 max E2E section) |
| [TC-cmi-017](../../../../tests/fixtures/wf-cmi/v3-loopback/) | phase10-loopback | v3-loopback/ (3 FAIL, source-fix needed) | deep --exec-scenarios --auto-fix-source | <45 min | CDG E195 source-fix authorization. Phase B spawn 3 agents (qa-lead/developer/developer+logistics-expert). 2 AUTO_CORRECTED + 1 ESCALATED. gap-suggestions.json APPEND 3 entries kind='e2e_scenario_fix' |
| [TC-cmi-018](../../../../tests/fixtures/wf-cmi/v3-stable-registry/) | stable-registry | v3-stable-registry/ (7 stable + 3 new) | deep --exec-scenarios | <20 min | Step 9.4: 7 hash match (TTL valid) skip 5x → time saved 5.8 min. 3 NEW × 5x → 2 stable + 1 quarantine. stable-registry.json APPEND 2 entries (final length 9). integrity-impact.json e2e_execution_summary.stable_registry_hits=7 |

## Schema

Theo [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../scripts/audit/EVAL-SCHEMA.md):

```jsonc
{
  "skill_name": "wf-cmi",
  "evals": [
    {
      "id": "TC-cmi-001",
      "prompt": "/wf-cmi ...",
      "expected_output": "free-form description",
      "assertions": [
        {"type": "file_exists | file_content | behavior | content_check | structure | registry_check", "text": "..."}
      ],
      "files": ["fixture path 1", "fixture path 2"]
    }
  ]
}
```

## Chạy tests

### Single test case

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-001
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-014   # v3 backward-compat
```

### All 18 test cases

```bash
./.claude/skills/workflow/wf-cmi/evals/run-all.sh
```

### Type filter

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --type=smoke,integration
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --type=backward-compat-v3,cd41-synth,phase9-execute,phase10-loopback,stable-registry
```

## Output

Results lưu tại `evals/results/TC-cmi-{ID}-{ISO-timestamp}.json`:

```jsonc
{
  "test_id": "TC-cmi-001",
  "type": "smoke",
  "result": "PASS | FAIL | SKIP",
  "duration_sec": 222,
  "post_gate_failures": 0,
  "error_count": 0,
  "context_budget_max_pct": 35,
  "phase_reports_compliance": {"all_under_15_lines": true, "vietnamese": true}
}
```

## Liên kết

- Design canon: [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md)
- v3 plan: [`plans/wf-cmi/v3.0-e2e-integration-plan.md`](../../../../plans/wf-cmi/v3.0-e2e-integration-plan.md) §7.3
- Fixtures: [`tests/fixtures/wf-cmi/`](../../../../tests/fixtures/wf-cmi/)
- Skill contract: [`../_contract.json`](../_contract.json) §evals
- Eval harness: [`../../../scripts/audit/run-skill-evals.sh`](../../../scripts/audit/run-skill-evals.sh)
- Eval schema: [`../../../scripts/audit/EVAL-SCHEMA.md`](../../../scripts/audit/EVAL-SCHEMA.md)

## Test cases history

| Wave | Cases | Stage added | Date |
|------|-------|-------------|------|
| v1 (pipeline core) | TC-cmi-001 → TC-cmi-005 | v1.0 baseline | 2026-04 |
| v2 (Wave dispatch + new lanes) | TC-cmi-006 → TC-cmi-013 | wf-cmi v2.0 (Gói C++ Logistics) | 2026-05-16 |
| v3 (E2E Scenario Engine) | TC-cmi-014 → TC-cmi-018 | wf-cmi v3.0 Stage 8 | 2026-05-17 |
