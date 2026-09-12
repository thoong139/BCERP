# Eval Results — Lớp 3 Behavioral Harness (v2, mode=stub)

_Generated: 2026-09-12T22:10:29+07:00_
_Harness: `run-skill-evals.sh` v2 — mode=`stub`_

## Summary

| Metric                | Value |
|-----------------------|-------|
| Cases run             | 22 |
| Assertions evaluated  | 139 |
| Pass                  | 0 |
| Fail                  | 0 |
| Skip (needs-judge)    | 139 |
| Duration              | 28s |
| Judge calls (live)    | 0 |
| Judge calls (cached)  | 0 |
| Judge budget          | 50 (hit: 0) |
| Judge avg latency     | 0ms |

## Per-skill breakdown

| Skill | Cases | Pass | Fail | Skip |
|-------|-------|------|------|------|
| wf-preflight | 22 | 0 | 0 | 22 |

## Failed cases (top 20)

_(none)_

## Coverage analysis

v1 STUB harness only auto-checks 5 of 7 assertion types:

| Type | Auto-checkable in v1? |
|------|----------------------|
| file_exists      | YES |
| file_content     | YES (when section/path parseable) |
| content_check    | PARTIAL (text often unstructured) |
| structure        | PARTIAL |
| registry_check   | PARTIAL (needs structured rules) |
| behavior         | NO — needs LLM judge or real run |
| output_contains  | NO — needs real skill stdout |

## Roadmap

### v2 — LLM judge integration

- Wire `behavior` and `output_contains` assertions through Claude as judge.
- Pass: assertion text + relevant workspace files → ask judge "does this hold?"
- Cache judge results by hash(assertion_text + workspace_state) to keep runs cheap.
- Target: convert ~345 needs-judge assertions to pass/fail.

### v3 — Real Claude Code CLI invocation ✓ IMPLEMENTED (Phiên 20)

- Flag `--mode=real` invokes `claude -p --allowedTools Write,Read,Bash,Glob` in sandbox.
- Sandbox: `.mc-data-eval-real/<skill>/case-N/`; fixture context from `fixtures/<skill>/case-N/real-fixture.md`.
- Captures stdout → checks `output_contains` via heuristic + judge; file assertions on actual artifacts.
- Tested: wf-brainstorm (4 cases, pass=6/22). Extend to: wf-plan-modules, wf-preflight (high-fail skills).
- Limitation: behavior assertions about internal agent spawning remain inconclusive (~73% skip for wf-brainstorm).

### CI integration

- v1 stub: run on every PR that touches `.claude/skills/workflow/**` (fast, deterministic).
- v2 judge: nightly + on PR with skill changes (rate-limited).
- v3 real: pre-release gate only (slow + expensive).

## Files

- Harness: [.claude/scripts/audit/run-skill-evals.sh](../../.claude/scripts/audit/run-skill-evals.sh)
- Schema: [.claude/scripts/audit/EVAL-SCHEMA.md](../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Results JSON: [docs/audit/work/eval-results.json](../work/eval-results.json)
- Workspaces (failed only): `.mc-data-eval/<skill>/case-<id>/`
- Judge cache: `.mc-data-eval/.judge-cache/`

<!-- MANUAL -->
## Manual notes

_Add manual analysis here; wrapped in MANUAL comments so regenerate won't wipe it._
<!-- /MANUAL -->
