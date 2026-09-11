# Task 3.2 — E2E Large Codebase Test (Standalone Deep Analysis)

**Date:** 2026-05-12  
**Session:** Phiên 19  
**Status:** FAIL (reproducible — confirmed same root cause as Task 3.1 FAIL #2)

---

## Test Execution

Ran standalone: `bash e2e-large-codebase.test.sh` from `.claude/skills/workflow/wf-fix-bugs/evals/`.

**Result:** FAIL — `probe_failures_count=1` (expected 0)

```
[e2e] FAIL: probe_failures_count: expected '0' got '1'
```

**Other assertions:**
- Wall-clock time: ~30s (within 300s budget) — PASS
- Lanes created: 3 (QD1, QD2, QD3) — PASS
- Signal aggregator schema valid — PASS
- total_issues: 2 (>0, detects coverage gaps) — PASS

Only assertion 4 (`probe_failures_count == 0`) failed — 4/5 assertions pass.

---

## Root Cause Analysis

### Error Trace

Full error from `probe-failures.log`:
```json
{
  "probe_id": "P-QD1-req-registry-xref",
  "reason": "non_zero_exit (exit=1)",
  "returncode": 1,
  "stderr_snippet": "ERROR: registry not found: Z:/Working/MCV3/.mc-data/docs/_meta/req-registry.json"
}
```

### Chain of Causation

1. **Test script** sets `--workflow-root "$WORKFLOW_DIR"` where `WORKFLOW_DIR="$REPO_ROOT/.claude/skills/workflow"` → points to MCV3's DEVKIT installation
2. **lane_dispatch.py:879** computes `repo_root = workflow_root.parent.parent.parent` → `Z:/Working/MCV3/` (MCV3 repo root, not fixture root)
3. **lane_dispatch.py:928** sets `cwd=str(repo_root)` for the subprocess running the bash probe
4. **wf-fix-probe-static-xref.sh:45** computes `REPO_ROOT=$(git rev-parse --show-toplevel)` → returns MCV3 repo root (because cwd=MCV3 root)
5. **wf-fix-probe-static-xref.sh:46** sets `REGISTRY="$REPO_ROOT/.mc-data/docs/_meta/req-registry.json"` → `Z:/Working/MCV3/.mc-data/docs/_meta/req-registry.json`
6. **MCV3 repo** does NOT have `.mc-data/docs/` directory (MCV3 is a DEVKIT tool, not a project using DEVKIT)
7. **wf-fix-probe-static-xref.sh:66-68**: `[ ! -f "$REGISTRY" ]` → exit 1 with error

### Why It Works In Production

In production, DEVKIT is installed inside the target project:
```
/home/user/my-project/
  .claude/skills/workflow/    ← workflow_root
  .mc-data/docs/_meta/req-registry.json  ← expected registry
```

`repo_root = workflow_root.parent.parent.parent` = `/home/user/my-project/` → correct.

In the e2e test:
```
Z:/Working/MCV3/                         ← repo_root (from lane_dispatch)
  .claude/skills/workflow/               ← workflow_root
  .mc-data/                              ← EMPTY (no docs/)
  .cache/wf-fix-large-fixture/           ← fixture (separate project)
    .mc-data/docs/_meta/req-registry.json  ← CORRECT registry
    apps/                                ← source code (correctly discovered)
```

The source_dir is correctly resolved from `WF_FIX_SOURCE_DIR` env var (line 884), but the registry path has no equivalent override mechanism.

### What Worked Correctly

- **QD2 probes** (P-QD2-calculation-check, P-QD2-hardcoded-value-detect): 0 signals, no errors
- **QD3 probes** (P-QD3-dependency-vuln-scan, P-QD3-secret-detection): 1 signal generated
- **QD1 other probes** (P-QD1-infra-preflight, P-QD1-route-config-parse): 2 signals generated — these don't depend on registry path resolution
- **Signal aggregator**: correctly merged all signals, total_issues=2
- **Source code scanning**: grep correctly found 200 reqs and 100 features in fixture's apps/

### Probe Impact Assessment

| Probe | Depends on Registry | Result |
|-------|-------------------|--------|
| P-QD1-req-registry-xref | YES — registry path from `git rev-parse --show-toplevel` | FAIL (registry not found) |
| P-QD1-infra-preflight | NO | PASS (emitted skip signal) |
| P-QD1-route-config-parse | NO | PASS (emitted skip signal) |
| P-QD2-calculation-check | NO | PASS |
| P-QD2-hardcoded-value-detect | NO | PASS |
| P-QD3-dependency-vuln-scan | NO | PASS |
| P-QD3-secret-detection | NO | PASS |

---

## Classification

**Type:** TEST_INFRA — The e2e test runs DEVKIT infrastructure (from MCV3 repo) against a separate fixture project. The `repo_root` derivation in `lane_dispatch.py` assumes DEVKIT is inside the target project, which is always true in production but not in the cross-project e2e test fixture.

**Severity:** WARN (non-blocking for audit)
- Does NOT affect production users — in production, the workflow root is inside the user's project
- Does NOT indicate a bug in wf-fix-bugs runtime logic
- Indicates a test architecture limitation: the e2e test cannot use MCV3's DEVKIT to analyze a separate fixture without additional path override support

**Reproducibility:** REPRODUCIBLE — verified in both Phiên 18 (run-all.sh) and Phiên 19 (standalone)

---

## Recommended Fix (for reference — not in audit scope)

Three options, ordered by effort:

1. **Add `WF_FIX_PROJECT_ROOT` env var** to lane_dispatch.py (line 879): `repo_root = Path(os.environ.get("WF_FIX_PROJECT_ROOT", workflow_root.parent.parent.parent))` — minimal change, test sets `WF_FIX_PROJECT_ROOT="$FIXTURE_DIR"`

2. **Pass `--registry` to probe from lane_dispatch:** The xref bash script already supports `--registry` flag (line 55). Lane dispatch could detect the registry path from source_dir's parent project and pass it through.

3. **Full fixture simulation:** Copy DEVKIT `.claude/` into the fixture so `repo_root` naturally resolves to the fixture — most realistic but heavy.

Option 1 is recommended as it's the standard pattern used by `WF_FIX_SOURCE_DIR` (already supported for source_dir).

---

## Observations

| ID | Description |
|----|-------------|
| OBS-057 | `repo_root` derivation in lane_dispatch.py:879 assumes DEVKIT is inside target project. Valid for production, broken for cross-project testing. |
| OBS-058 | xref probe bash script (wf-fix-probe-static-xref.sh) supports `--registry` flag (line 55) but lane_dispatch.py never passes it. |
| OBS-059 | MCV3 repo itself has no `.mc-data/docs/` — expected for a tool repo, but means the fallback `REPO_ROOT/.mc-data/docs/_meta/req-registry.json` always fails when running from MCV3. |
| OBS-060 | 4/5 e2e assertions pass. Only `probe_failures_count==0` fails. The test correctly validates 4 other properties (time budget, lanes created, schema valid, issues detected). |
| OBS-061 | Other probes (QD1 infra-preflight/route-config-parse, QD2, QD3) complete correctly because they either don't depend on registry path or resolve paths from source_dir/args. |

---

## DoD Assessment

| Criterion | Status |
|-----------|--------|
| Test executed standalone | ✅ Ran with `bash e2e-large-codebase.test.sh` |
| Failure reproduced | ✅ Same error: registry not found at MCV3 path |
| Root cause traced | ✅ Full chain of causation documented (7 steps) |
| Impact assessed | ✅ Only P-QD1-req-registry-xref affected; 6/7 probes OK |
| Classification determined | ✅ TEST_INFRA — not a production bug |
| Findings documented | ✅ This file |

**Task 3.2 is DONE** — failure confirmed as test infrastructure limitation, not production code bug. Root cause: `repo_root` derivation in `lane_dispatch.py` assumes DEVKIT is inside target project; e2e test runs DEVKIT from MCV3 repo against separate fixture. Fix: add `WF_FIX_PROJECT_ROOT` env var override.

---

PHIEN_DONE: Task 3.2 — E2E large codebase test standalone analysis. FAIL confirmed reproducible. Root cause: lane_dispatch.py:879 repo_root derivation from workflow_root assumes DEVKIT in target project; e2e test uses MCV3's DEVKIT to analyze separate fixture with no registry path override. 4/5 assertions pass. 5 observations (OBS-057→061). Findings: findings/e2e-large-codebase.md.
