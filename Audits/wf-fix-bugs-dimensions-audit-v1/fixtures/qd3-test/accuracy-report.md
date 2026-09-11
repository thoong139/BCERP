# QD3 Accuracy Report — Phiên 12

> **Generated:** 2026-05-08 (Phiên 12)
> **Probe:** `P-QD3-secret-detection` v1.0 (`wf-fix-probe-static-secret.sh`)
> **Scope:** `fixtures/qd3-test/{positive,negative}/` (10 source files)
> **Live expectations:** 5/10 intended (other 5 = `true_negative`). Probe emitted 6 signals (+1 bonus).
> **DoD ngưỡng (13-DoD §Phase 3):** Precision ≥ 0.7 + Recall ≥ 0.6 → **VERDICT: ✅ PASS**

## 1. Source

- `expected-signals.json` v0.2.0 — 10 expectations (5 `live_detectable` + 1 `live_detectable_bonus` + 5 `true_negative`)
- `.actual-signals-positive.json` — 6 signals from probe run 2026-05-08 (positive scan)
- `.actual-signals-negative.json` — 0 signals from probe run 2026-05-08 (negative scan)
- `positive/` — 5 source files (pos-01..pos-05)
- `negative/` — 5 files (neg-01..neg-05)

### Run configuration

```bash
# cd to fixture dir (REQUIRED — so grep returns relative paths, avoids fixtures/ EXCLUDE_PATTERN)
cd fixtures/qd3-test/

# Positive scan
bash wf-fix-probe-static-secret.sh --session-dir /tmp/qd3-XXX --lane wf-fix-security \
  --probe P-QD3-secret-detection --profile standard --source-dir positive

# Negative scan  
bash wf-fix-probe-static-secret.sh --session-dir /tmp/qd3-XXX --lane wf-fix-security \
  --probe P-QD3-secret-detection --profile standard --source-dir negative
```

## 2. Confusion Matrix

|                                         | **Probe emits signal** | **Probe silent** |
| --------------------------------------- | :--------------------- | :--------------- |
| **Should emit (live_detectable × 5)**   | TP = **5**             | FN = **0**       |
| **Bonus detection (f-string template)** | TP_bonus = **1**       | —                |
| **Should be silent (true_negative × 5)**| FP = **0**             | TN = **5**       |

**Total signals:** 6 (positive scan) + 0 (negative scan) = 6

> `true_negative` cases tracked in the negative scan: all 5 correctly returned 0 signals.

## 3. Metrics

| Metric              | Formula                  | Value    | DoD threshold | Pass?  |
| ------------------- | ------------------------ | -------- | ------------- | ------ |
| Precision (lenient) | TP_all / (TP_all + FP)   | **1.00** | ≥ 0.70        | ✅     |
| Precision (strict)  | TP_int / (TP_int + FP)   | **0.83** | ≥ 0.70        | ✅     |
| Recall              | TP_int / (TP_int + FN)   | **1.00** | ≥ 0.60        | ✅     |
| F1 (lenient)        | 2·P_len·R / (P_len + R)  | **1.00** | —             | —      |
| F1 (strict)         | 2·P_str·R / (P_str + R)  | **0.91** | —             | —      |
| Accuracy            | (TP_all + TN) / 11       | **1.00** | —             | —      |

> **TP_int:** 5 intentional detections. **TP_bonus:** 1 unexpected extra (f-string template). **TP_all** = 6.
> Precision_strict treats the bonus detection as FP: 5 / (5 + 0 + 1) = 0.833.
> Precision_lenient counts it as valid TP: 6 / (6 + 0) = 1.000.
> Both exceed the DoD threshold of 0.70. **Official metric: Precision_strict = 0.83, Recall = 1.00.**

## 4. TP Detail (5 intended + 1 bonus)

| # | File | Line | Pattern | Severity | CDG? | Expected? |
|---|------|:----:|---------|:--------:|:----:|:---------:|
| 1 | `positive/pos-01-aws-key.ts` | 8 | AWS Access Key | CRITICAL | ✅ | ✅ intended |
| 2 | `positive/pos-02-stripe-key.config.js` | 7 | Stripe Live Key | CRITICAL | ✅ | ✅ intended |
| 3 | `positive/pos-03-generic-password.py` | 12 | Generic Password | HIGH | ✅ | ✅ intended |
| 4 | `positive/pos-03-generic-password.py` | 13 | Database URL | HIGH | ✅ | ⚠️ bonus |
| 5 | `positive/pos-04-db-url.ts` | 6 | Database URL | HIGH | ✅ | ✅ intended |
| 6 | `positive/pos-05-bearer-token.ts` | 8 | Bearer Token Hardcoded | HIGH | ✅ | ✅ intended |

### CDG Verification

All 6 emitted signals carry `cdg_flags: ["CDG-SECURITY-LIVE"]` ✅

This confirms Phase 2 finding AF-QD3-003: Probe 4 bash correctly hard-codes CDG for all signals at emit time (unlike SPEC-ONLY probes which have CDG risk via signal-emit.md helper default `cdg_flags: []`).

### Fingerprint Verification

Sample fingerprint (signal 0): `sha256:e0c63fa13f74bcb260455dfc43d5009fc9a5ce57e38ab5935b3a11847f980bfb`

Format: `sha256:<64-hex-chars>` ✅

The fingerprint is an **opaque hash** — token count cannot be derived from the output. Token count (6) was confirmed in Phase 2 via source code analysis:

```bash
# wf-fix-probe-static-secret.sh line 105:
fp=$(echo -n "QD3|$file|$line|$PROBE_ID|secret|$label" | _sha256 | awk '{print "sha256:"$1}')
#             ^^^  ^^^^  ^^^^  ^^^^^^^^  ^^^^^^  ^^^^^
#              1    2     3       4         5      6   tokens
```

This is the 6-token format vs. signal-emit.md's 5-token spec vs. _shared.md §1's 4-token spec → 3-way split DISCREPANCY-6 (IMP-QD3-006, MERGE candidate with IMP-QD1-007).

## 5. FP Detail (0 false positives — all TN)

| # | File | Mechanism | Result |
|---|------|-----------|--------|
| neg-01 | `negative/neg-01-dotenv.example` | Extension `.example` not in grep `--include` | 0 signals ✅ |
| neg-02 | `negative/neg-02-uuid-fixture.test.ts` | Path `\.test\.` matches EXCLUDE_PATTERN | 0 signals ✅ |
| neg-03 | `negative/neg-03-comment-only.ts` | `//` comment + TODO + example → comment filter skip | 0 signals ✅ |
| neg-04 | `negative/neg-04-md5-cache.ts` | `crypto.createHash('md5')` — no PATTERNS regex match | 0 signals ✅ |
| neg-05 | `negative/neg-05-readme.md` | `.md$` matches EXCLUDE_PATTERN + not in `--include` | 0 signals ✅ |

## 6. Bonus Detection Analysis

**Signal 4 (bonus):** `positive/pos-03-generic-password.py:13 — Hardcoded secret: Database URL`

Source line:
```python
return f"postgresql://{username}:{password}@{host}:{port}/{database}"
```

**Pattern matched:** `(postgres|postgresql|mysql|mongodb|redis)://[^[:space:]"']+:[^[:space:]"']+@`

The f-string template literally contains `postgresql://` followed by `{username}:` followed by `{password}@`. The grep cannot distinguish between:
- `"postgres://real_user:real_pass@prod-db:5432/db"` — hardcoded credential (true positive)
- `f"postgresql://{username}:{password}@..."` — dynamic template (debatable)

**Classification:** TP-bonus. The f-string template IS security-relevant: if `username` and `password` are local variables set to credentials (as they are in this fixture), the URL exposes them. The probe is technically correct to flag it.

**Implication for FP analysis:** This confirms FP candidate FP-008 (pre-seeded in Phase 1 §4): "Python f-string with variable placeholders matches URL/password pattern." Future improvement could add f-string template detection heuristic (e.g., `{variable_name}` markers in the matched segment → downgrade to WARNING severity).

**Impact on IMP-QD3-004 (Tech Stack P1):** Pattern behavior differs for Python f-strings vs. TypeScript template literals — further evidence for multi-language validation improvement.

## 7. Documented Gap (SPEC-ONLY probes)

6 of 7 QD3 probes do NOT have bash implementations. Their signals cannot be measured live:

| Probe | Type | Live measurable? |
|-------|------|:---------------:|
| P-QD3-secret-detection | bash script | ✅ (this report) |
| P-QD3-dependency-vuln-scan | SPEC-ONLY | ❌ |
| P-QD3-dangerous-deserialize | SPEC-ONLY | ❌ |
| P-QD3-auth-flow-verify | SPEC-ONLY | ❌ |
| P-QD3-cors-policy-check | SPEC-ONLY | ❌ |
| P-QD3-security-header-audit | SPEC-ONLY | ❌ |
| P-QD3-owasp-top-ten | SPEC-ONLY | ❌ |

Recall_overall (all 7 probes) = 1/7 = 0.14 — but this is a tooling gap (IMP-QD3-001), not a detection quality gap. The implemented probe (`secret-detection`) achieves Recall = 1.00.

## 8. Phase 3 DoD Verification

| DoD criterion | Result | Pass? |
|---|---|:-:|
| ≥5 positive cases built | 5 files (`pos-01..pos-05`) | ✅ |
| ≥5 negative cases built | 5 files (`neg-01..neg-05`) | ✅ |
| Probe emits ≥4 signals on positive set | 6 signals emitted | ✅ |
| 0 FP on negative set | 0 FP | ✅ |
| Precision ≥ 0.70 | P_strict = 0.83 | ✅ |
| Recall ≥ 0.60 | R = 1.00 | ✅ |
| CDG-SECURITY-LIVE attached to all signals | 6/6 ✅ | ✅ |
| Fingerprint format confirmed | sha256:<hex> ✅ | ✅ |
| accuracy-report.md created | This file | ✅ |

**VERDICT: Phase 3 DoD ✅ PASS** — P_strict=0.83, R=1.00, F1_strict=0.91
