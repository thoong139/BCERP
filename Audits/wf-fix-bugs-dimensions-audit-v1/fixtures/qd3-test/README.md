# QD3 Test Fixture — Security: Secret Detection

> **Status:** ✅ Phase 3 DONE (Phiên 12) — P_strict=0.83, R=1.00, F1_strict=0.91
> **Lane skill:** `wf-fix-security` v2.0.0-alpha.s4
> **Live probe:** `P-QD3-secret-detection` (wf-fix-probe-static-secret.sh)
> **SPEC-ONLY probes:** 6/7 — dependency-vuln-scan, dangerous-deserialize, auth-flow-verify, cors-policy-check, security-header-audit, owasp-top-ten
> **Owner agent:** `security`
> **Audit report:** [04-qd3-security-audit.md](../../04-qd3-security-audit.md)
> **Accuracy report:** [accuracy-report.md](./accuracy-report.md)

## Mục đích

Đo precision/recall của probe `P-QD3-secret-detection` — probe duy nhất có bash implementation trong QD3. 6 probe còn lại là SPEC-ONLY (không có bash script độc lập → không đo được live).

## Expected signals per probe

| Probe ID | Type | Severity | Positive cases | Negative cases | Live measurable? |
|---|---|:-:|:-:|:-:|:-:|
| `P-QD3-secret-detection` | bash | critical/high | 5 (+1 bonus) | 5 | ✅ |
| `P-QD3-dependency-vuln-scan` | SPEC-ONLY | high | — | — | ❌ |
| `P-QD3-dangerous-deserialize` | SPEC-ONLY | critical | — | — | ❌ |
| `P-QD3-auth-flow-verify` | SPEC-ONLY | high | — | — | ❌ |
| `P-QD3-cors-policy-check` | SPEC-ONLY | high | — | — | ❌ |
| `P-QD3-security-header-audit` | SPEC-ONLY | medium | — | — | ❌ |
| `P-QD3-owasp-top-ten` | SPEC-ONLY | critical | — | — | ❌ |

## Cases

### Positive (5 files — P-QD3-secret-detection live targets)

| File | Pattern triggered | Severity | Signals |
|------|------------------|:--------:|:-------:|
| `pos-01-aws-key.ts` | AWS Access Key (`AKIA[0-9A-Z]{16}`) | CRITICAL | 1 |
| `pos-02-stripe-key.config.js` | Stripe Live Key (`sk_live_[0-9a-zA-Z]{24,}`) | CRITICAL | 1 |
| `pos-03-generic-password.py` | Generic Password + Database URL (f-string bonus) | HIGH | 2 |
| `pos-04-db-url.ts` | Database URL (`postgres://user:pass@...`) | HIGH | 1 |
| `pos-05-bearer-token.ts` | Bearer Token Hardcoded (`Bearer <20+ chars>`) | HIGH | 1 |

**Total emitted: 6 signals (5 intended + 1 bonus from f-string template in pos-03)**

### Negative (5 files — verify 0 FP)

| File | Mechanism | Reason for exclusion |
|------|-----------|---------------------|
| `neg-01-dotenv.example` | Extension not in `--include` | `.example` ≠ `*.env` in grep whitelist |
| `neg-02-uuid-fixture.test.ts` | EXCLUDE_PATTERN `\.test\.` | Path filter before signal emit |
| `neg-03-comment-only.ts` | Comment filter | `//` line + `TODO`/`example`/`your_` keyword |
| `neg-04-md5-cache.ts` | No pattern match | crypto.createHash('md5') not in 14 PATTERNS |
| `neg-05-readme.md` | EXCLUDE_PATTERN `.md$` + not in `--include` | Double filter |

**Total FP: 0 ✅**

### Advanced (5 cases pre-seeded — Stage 0 skeleton)

Pre-seeded in Stage 0 for future expansion. Not yet implemented:
- `advanced/jwt-alg-none/` — JWT alg=none acceptance (currently advanced/ folder contains only `.gitkeep`)
- `advanced/ssrf-redirect/` — SSRF via redirect chain
- `advanced/mass-assignment/` — mass assignment (role/admin flag)
- `advanced/idor-no-auth/` — Insecure Direct Object Reference
- `advanced/session-fixation/` — session ID not rotated after login

> Stage 4 re-audit will populate `advanced/` when corresponding SPEC-ONLY probes get bash implementations.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd3-test
bash run.sh
```

**CRITICAL design note:** The `run.sh` **must** `cd` to `FIXTURE_DIR` before invoking the probe. If the probe runs with an absolute `--source-dir`, `grep` returns paths containing `fixtures/` which triggers `EXCLUDE_PATTERN` → all signals dropped (0 detected). Running with relative `--source-dir positive` returns paths like `positive/pos-01-aws-key.ts` (no `fixtures/` prefix).

### Dry run (validate setup without invoking probe)

```bash
bash run.sh --dry-run
```

## Accuracy Results (Phiên 12)

| Metric | Value | DoD threshold | Pass? |
|--------|:-----:|:-------------:|:-----:|
| Precision (strict) | **0.83** | ≥ 0.70 | ✅ |
| Recall | **1.00** | ≥ 0.60 | ✅ |
| F1 (strict) | **0.91** | — | — |

Full analysis: [accuracy-report.md](./accuracy-report.md)

## Key findings from Phase 3

1. **f-string template bonus detection** (pos-03 line 13): Python f-string `f"postgresql://{username}:{password}@..."` matches Database URL pattern. Probe cannot distinguish dynamic template from literal cred → confirms FP-QD3 §4 pre-seed edge case. Classified as TP-bonus (f-string with credential vars IS security-relevant).

2. **EXCLUDE_PATTERN path-dependency**: Running with absolute `--source-dir` fails (paths include `fixtures/`). Running with relative `--source-dir` from fixture dir succeeds. This is a usability gap — users calling the probe from different CWDs may get 0 results unexpectedly.

3. **CDG hard-coded at emit time**: All 6 signals carry `CDG-SECURITY-LIVE` ✅. Confirms Phase 2 finding AF-QD3-003 (Probe 4 bash is CDG-correct; SPEC-ONLY probes have CDG risk via signal-emit.md helper).

4. **Fingerprint format**: `sha256:<64-hex-chars>` ✅. 6-token pre-hash input confirmed in Phase 2 source analysis (not derivable from output hash alone).

## Liên quan

- Audit report: [04-qd3-security-audit.md](../../04-qd3-security-audit.md)
- Lane skill: `.claude/skills/workflow/wf-fix-security/`
- Probe script: `.claude/scripts/wf-fix-probe-static-secret.sh`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
- Accuracy report: [accuracy-report.md](./accuracy-report.md)
