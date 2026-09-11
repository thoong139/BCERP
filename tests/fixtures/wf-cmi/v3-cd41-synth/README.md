# Fixture: `v3-cd41-synth/` — TC-cmi-015

> **Mục đích:** CD41 lane synthesis test với 3 MUST violations cross-module + business-invariants + workflow-graph + ui-interactivity-spec. Validate CD41 sinh ≥1 test scenario hợp lệ với confidence ≥0.5, KHÔNG execute Playwright (no --exec-scenarios).

---

## Cấu trúc

```
v3-cd41-synth/
├── README.md                              ← Bạn đang đọc
└── .mc-data/
    └── docs/
        └── _meta/
            ├── req-registry.json          ← 3 REQ cross-module (CRM+Orders+Finance)
            └── ui-interactivity-spec.json ← SSOT bắt buộc CD41
```

## Expected behavior

| Phase | Behavior |
|-------|----------|
| 4 (Dispatch) | profile=deep → activate CD41 Wave 3. Owner agents: qa-lead + ux-researcher + business-analyst. |
| CD41.1 | Load 4 inputs: signals-aggregated.jsonl, business-invariants.json, workflow-graph.json, ui-interactivity-spec.json. |
| CD41.2 | Filter violations severity=MUST AND dim ∈ {CD9,CD11,CD13,CD15,CD23-26,CD38,CD39}. |
| CD41.4 | Render scenario template với confidence scoring (≥0.7 = strong). |
| CD41.5 | Write scenarios-manifest.json + scenarios/test-scenario-CMI-*.md. |
| CD41.6 | Emit 3 signal kinds (E2E_SCENARIO_SYNTHESIZED + SKIPPED_LOW_CONFIDENCE + CROSS_MODULE_DETECTED). |
| 9 (E2E Execute) | **SKIP** — no --exec-scenarios flag. CD41 outputs preserved. |

## Pass criteria

1. Exit code 0
2. scenarios-manifest.json: total_synthesized ≥3, total_valid ≥1, total_cross_module ≥1
3. ≥1 test-scenario-CMI-{NN}-{slug}.md exists với frontmatter YAML đầy đủ 14 fields
4. signals.json: ≥1 entry rule_id='E2E_SCENARIO_SYNTHESIZED'
5. CD41-e2e-synth-report.md ≤20 dòng tiếng Việt
6. Phase9-report.md + Phase10-report.md NOT created (SKIP)

## Run

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-015
```
