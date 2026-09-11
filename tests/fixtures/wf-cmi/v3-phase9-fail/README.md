# Fixture: `v3-phase9-fail/` — TC-cmi-016

> **Mục đích:** Phase 9 execute fail → Phase 10 auto-fix Phase A (browser-fix, không touch source) → 2 scenarios PASS after retry. Validate failure classification 7-type + auto-fix budget + AUTO_CORRECTED status update.

---

## Cấu trúc

```
v3-phase9-fail/
├── README.md                          ← Bạn đang đọc
└── .mc-data/
    ├── docs/_meta/req-registry.json   ← 2 REQ stub
    └── work/wf-cmi/sessions/
        └── 2026-05-17-system-deep-01/phase4-coverage/lanes/CD41-e2e-synth/
            └── scenarios-manifest.json ← 5 scenarios pre-synthesized (mock)
```

## Expected behavior

| Phase | Behavior |
|-------|----------|
| 9 (E2E Execute) | 5 scenarios sequential. 3 PASS, 2 FAIL (TEST_SELECTOR + UI_BUG). |
| 10 (Resolution) | Auto-trigger vì ≥1 FAIL. Classify per failure_type. |
| Phase A (browser-fix) | TEST_SELECTOR: thử 3 selector variant (data-testid → role → label) → variant 3 PASS. UI_BUG: page_reload → state recover → PASS. |
| 9 (re-run) | scenario-04 + scenario-05 → AUTO_CORRECTED. |

## Pass criteria

1. Exit code 0
2. e2e-results.json: 3 PASS + 2 AUTO_CORRECTED + 0 FAIL (after Phase 10)
3. auto_fix_attempts[] populated cho 2 scenarios (3 attempts + 1 attempt)
4. resolution-report.md: auto_corrected=2, source_fix_required=0, escalated=0
5. integrity-impact.json e2e_execution_summary: N_PASS=3, N_AUTO_CORRECTED=2, N_FAIL=0
6. integrity-report.md ≤70 dòng (v3 max with E2E section)

## Notes

- Fixture chỉ provide manifest stub (pre-synthesized scenarios) — bypass Phase 1-8 nếu test isolate Phase 9-10 logic.
- Real Playwright MCP integration required cho actual E2E run; fixture có thể dùng mock Playwright adapter cho deterministic test.

## Run

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-016
```
