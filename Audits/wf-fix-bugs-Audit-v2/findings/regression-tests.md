# Task 3.1 — Regression Test Suite Results

**Date:** 2026-05-12  
**Session:** Phiên 18  
**Status:** 3 PASS, 2 FAIL, 0 SKIP

---

## Test Execution Summary

Ran `bash regression-tests/run-all.sh` from `.claude/skills/workflow/wf-fix-bugs/evals/`.

| # | Test | Result | Duration | Details |
|---|------|--------|----------|---------|
| 1 | test-isg-name-narrowing | PASS | ~2s | ISG scope={type=module, name=marketing}, profile=standard — works correctly |
| 2 | test-init-status-flags | FAIL | ~1s | flags.credentials returned redacted JSON object instead of expected plaintext |
| 3 | test-xref-on-N-orphans | PASS | ~4s | 1000 orphan REQ-IDs handled in 4s (budget 30s) |
| 4 | test-probe-timeout-not-silent | PASS | ~3s | probe_failures_count=1, healthy=False — timeout correctly detected and logged |
| 5 | e2e-large-codebase | FAIL | ~30s | probe_failures_count=1 (expected 0) — P-QD1-req-registry-xref probe failed |

**Overall:** 3/5 passed (60%), exit code 1.

---

## Failure Analysis

### FAIL #1: test-init-status-flags

**Failure:** `flags.credentials='{"$redacted":true,...}'` instead of expected `'sysadmin@erktransport.local:SysAdmin@123'`

**Root Cause:** This is a **test drift**, not a code bug. The `wf-fix-init-status.sh` script was updated with a security improvement: credentials are now redacted in `fix-status.json` and stored in a separate `.credentials.txt` file (chmod 600). The test still expects the old plaintext-in-JSON behavior.

**Evidence:**
- `fix-status.json` flags.credentials: `{"$redacted":true,"scheme":"email_password","length":40,"hash8":"50bda277","raw_path":"Z:/...session/.credentials.txt","note":"Plaintext credentials persist o raw_path (chmod 600). Probe scripts doc tu day, KHONG tu fix-status.json."}`
- flags.url still resolves correctly to `http://localhost:3000` (PASS)
- flags.scope, flags.name, flags.deep, flags.responsive all PASS

**Classification:** TEST_DRIFT — The code behavior change is intentional (security hardening). The test needs updating to read credentials from `.credentials.txt` or accept the redacted format with `$redacted: true`.

**Severity:** WARN (non-blocking — credential handling is actually improved; test just needs updating)

---

### FAIL #2: e2e-large-codebase

**Failure:** probe_failures_count=1 (expected 0). Probe `P-QD1-req-registry-xref` failed with exit=1.

**Error snippet:**
```
ERROR: registry not found: Z:/Working/MCV3/.mc-data/docs/_meta/req-registry.json
```

**Root Cause:** The `P-QD1-req-registry-xref` probe hardcodes the registry path to `Z:/Working/MCV3/.mc-data/docs/_meta/req-registry.json` (MCV3 repo root). When the e2e test runs against the large fixture (`.cache/wf-fix-large-fixture/`), the probe should resolve paths relative to the fixture's own `.mc-data/docs/_meta/req-registry.json`, not the MCV3 repo path.

**Evidence:**
- Fixture has its own registry: `.cache/wf-fix-large-fixture/.mc-data/docs/_meta/req-registry.json` (exists)
- Probe looked for: `Z:/Working/MCV3/.mc-data/docs/_meta/req-registry.json` (wrong — MCV3 repo, not fixture)
- Fixture was generated with 200 reqs, 100 feats via the generate-fixture.py script
- Other probes (QD2, QD3) completed without errors, generating 0 and 1 signals respectively

**Classification:** REAL_BUG — Path resolution issue in xref probe when running against non-MCV3-repo fixtures. The probe should use `$WORKFLOW_ROOT` or fixture path, not hardcoded `$REPO_ROOT`.

**Severity:** WARN (non-blocking for audit — affects test fixture isolation only; production usage would use actual `.mc-data/` at project root)

---

## Observations

| ID | Description |
|----|-------------|
| OBS-053 | `run-all.sh` lists 4 regression tests but `regression-tests/` directory contains 7 `.sh` files (test-cqg2-jq-path-correctness.sh, test-no-hardcoded-qd1-8.sh, test-probe-failure-recording.sh are not included in run-all.sh). These 3 additional tests should be incorporated. |
| OBS-054 | test-init-status-flags credential redaction is a security improvement — the `.credentials.txt` (chmod 600) approach is better than plaintext in JSON. Test should verify `.credentials.txt` content instead. |
| OBS-055 | e2e-large-codebase probe failure only affects QD1 (2 signals generated). QD2 (0 signals) and QD3 (1 signal) completed successfully. The 1 failure is from path resolution, not from logic errors in the probe itself. |
| OBS-056 | e2e test runs ~30s for 5000 files — performance is acceptable even for large codebases. |

---

## Recommendations

1. **Update test-init-status-flags.sh** to either:
   - Accept redacted credentials format (`$redacted: true`) as valid, OR
   - Read credentials from `.credentials.txt` instead of `fix-status.json`
2. **Fix P-QD1-req-registry-xref path resolution** to use fixture's project root, not hardcoded MCV3 repo path. Use `$WORKFLOW_ROOT` or derive from session dir context.
3. **Add 3 missing regression tests** to `run-all.sh`: test-cqg2-jq-path-correctness.sh, test-no-hardcoded-qd1-8.sh, test-probe-failure-recording.sh.

---

## DoD Assessment

| Criterion | Status |
|-----------|--------|
| Tests executed | ✅ All 5 ran (4 regression + 1 e2e) |
| Results documented | ✅ Per-test PASS/FAIL with details |
| Failures analyzed | ✅ Root causes identified for both failures |
| Exit code captured | ✅ exit=1 (2 failures) |
| Findings written | ✅ This file |

**Task 3.1 is DONE** — all tests executed, results documented, failures analyzed.

---

PHIEN_DONE: Task 3.1 — Run regression test suite. 3/5 PASS, 2 FAIL (test-init-status-flags: credential redaction test drift; e2e-large-codebase: xref probe path resolution to fixture). 4 observations (OBS-053→056). Findings: findings/regression-tests.md.
