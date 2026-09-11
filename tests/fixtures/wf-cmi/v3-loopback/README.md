# Fixture: `v3-loopback/` — TC-cmi-017

> **Mục đích:** Phase 10 source-fix (Phase B) loop-back validation với `--auto-fix-source` flag. CDG E195 trigger. 3 scenarios FAIL (1 TEST_SELECTOR + 1 NETWORK_ERROR + 1 BUSINESS_RULE). Phase A browser-fix fail → Phase B spawn agents → 2 PASS + 1 ESCALATE → gap-suggestions.json APPEND 3 entries kind='e2e_scenario_fix'.

---

## Cấu trúc

```
v3-loopback/
├── README.md                              ← Bạn đang đọc
└── .mc-data/
    └── docs/_meta/
        ├── req-registry.json              ← 3 REQ cross-module
        └── business-invariants.json       ← 3 invariants để BUSINESS_RULE trigger
```

## Expected behavior

| Step | Action | Outcome |
|------|--------|---------|
| Phase 9 | Execute 3 scenarios | All FAIL (selector + 500 + assertion) |
| Phase 10.A | Browser-fix attempts | All fail (variants/retry/no client-side fix) |
| CDG E195 | AskUserQuestion "Source-fix Authorization" | User chooses "Confirm cho session này" |
| Phase 10.B | Spawn 3 agents parallel max=3 | qa-lead (selector) / developer (endpoint) / developer+logistics-expert (rule) |
| Post-fix | Wait HMR reload → re-run | 2 AUTO_CORRECTED + 1 ESCALATED |
| Step 10.3 | Loop-back APPEND gap-suggestions | 3 entries kind='e2e_scenario_fix' |

## Pass criteria

1. CDG E195 trigger lần đầu source-fix attempt; cdg-decisions.json APPEND
2. 3 agents spawn với 8-section prompt template (CORE-037)
3. Post-HMR re-run: 2 PASS, 1 ESCALATED (escalation_reason='requires business-analyst manual review')
4. gap-suggestions.json: 3 NEW entries kind='e2e_scenario_fix' với target_path + source_signal_ids + confidence
5. NO re-trigger CD41 (loop-back guard) — no signal 'E2E_SCENARIO_SYNTHESIZED' emitted post Phase 10
6. resolution-report.md: auto_corrected=2, source_fix_required=3, escalated=1, loop_back_suggestions_count=3
7. Exit code 0 (with ESCALATE flag)

## Run

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-017
```
