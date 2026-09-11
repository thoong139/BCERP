# QD7 Phase 3 Accuracy Report — Compatibility Dimension

> **Dimension:** QD7 — Browser/API/Device Compatibility
> **Phase:** 3 — Test Fixture
> **Date:** 2026-05-08 (Phiên 37)
> **Live probe:** `wf-fix-probe-static-deprecated.sh` (P-QD7-deprecated-api-usage)
> **Run:** `bash fixtures/qd7-test/run.sh` — PASS ✅
> **Audit report:** [08-qd7-compat-audit.md](../../08-qd7-compat-audit.md)

---

## §1 Tóm Tắt Kết Quả

| Metric | Live-testable (1/5 probes, file-level) | Full audit spec (5/5 probes) |
|---|:-:|:-:|
| Precision (P) | **1.00** | N/A (SPEC_GAP) |
| Recall (R) | **1.00** | N/A (SPEC_GAP) |
| F1 Score | **1.00** | N/A (SPEC_GAP) |
| TP_files | 5 | — |
| FP_files | 0 | — |
| FN_files | 0 | — |
| TN_files | 5 | — |
| Total signals (positive scan) | 7 (cascade — overlapping patterns) | — |

**Live probe verdict:** ✅ PASS — P=R=F1=1.00 (file-level), FP=0

> **Measurement note:** Precision/Recall measured at FILE level (not signal count). Probe has overlapping regex patterns: `document.execCommand('copy')` matches both pattern #1 (HIGH specific) and pattern #3 (MEDIUM general) → 2 signals from 1 code line (cascade). File-level measurement is correct for this probe architecture.

---

## §2 Live Run Results (Actual Output)

### Positive Scan (7 signals, 5 files detected)

| Signal | File | Line | Severity | Type | Verdict |
|---|---|:-:|:-:|---|:-:|
| `document.execCommand('copy')` | pos-01-deprecated-execcommand.tsx | 12 | HIGH | deprecated_api | TP (cascade) |
| `document.execCommand` | pos-01-deprecated-execcommand.tsx | 12 | MEDIUM | deprecated_api | TP (cascade) |
| `componentWillMount` | pos-02-componentwillmount.tsx | 14 | HIGH | deprecated_api | TP |
| `new Buffer()` | pos-04-new-buffer.ts | 5 | CRITICAL | deprecated_api | TP |
| `zoom CSS` | pos-03-zoom-css.css | 7 | LOW | deprecated_css | TP |
| `zoom CSS` | pos-03-zoom-css.css | 13 | LOW | deprecated_css | TP (2nd occurrence) |
| `moment` | positive/package.json | null | MEDIUM | deprecated_pkg | TP |

**Positive files detected: 5/5** (all 5 positive locations have ≥1 signal)

### Negative Scan (0 signals)

| File | Signals | Verdict |
|---|:-:|:-:|
| neg-01-modern-clipboard.ts | 0 | TN |
| neg-02-modern-hooks.tsx | 0 | TN |
| neg-03-transform-css.css | 0 | TN |
| neg-04-buffer-alloc.ts | 0 | TN |
| negative/package.json | 0 | TN |

**Negative files: 5/5 clean** (FP = 0)

### Fingerprint Verification

```
Signal 0 fingerprint: sha256:630f7b2e002d3e0d0b5ea50af5c46e79b8e89b7320e9ab8ae63034dcc1f97b11
Format check: OK (sha256:<64-hex> from 6-token input)
```

D17 confirmed: probe uses 6-token `QD7|file|line|probe_id|type|label` vs 5-token spec.

---

## §3 Cascade Analysis

The probe iterates **all 17 API patterns** unconditionally (D13: `--probe` cosmetic). Overlapping patterns produce multiple signals per code line:

| Pattern | Regex | Severity | Match on pos-01 |
|---|---|:-:|:-:|
| `document.execCommand('copy')` | `document\.execCommand\(\s*['"]copy['"]` | HIGH | ✓ line 12 |
| `document.execCommand` (general) | `document\.execCommand\(` | MEDIUM | ✓ line 12 (same line) |

→ **2 signals from 1 occurrence** — both are correct detections (HIGH for specific deprecated variant, MEDIUM as fallback). File-level TP = 1 (correctly detected).

CSS probe has **2 occurrences** of `zoom: 1.5` / `zoom: 0.75` in pos-03 → 2 signals from 2 lines (expected).

---

## §4 Signal Type Coverage

| Signal type | Positive files | Expected count | Live count | Status |
|---|---|:-:|:-:|:-:|
| `deprecated_api` (JS/TS) | pos-01 (cascade ×2), pos-02 (×1), pos-04 (×1) | ≥3 | 4 | ✅ |
| `deprecated_css` (CSS/SCSS) | pos-03 (×2 occurrences) | ≥1 | 2 | ✅ |
| `deprecated_pkg` (package.json) | positive/package.json | 1 | 1 | ✅ |
| CDG flags | positive/package.json moment | 1 CDG-DEPS-DOWN | 1 ✓ | ✅ (D10 documented) |

---

## §5 SPEC_GAP — Probes Không Live-Testable

4/5 audit-spec probes của QD7 không thể đo precision/recall qua bash vì:

### P-QD7-browser-compat-check (SPEC_GAP — D1)
- **Lý do:** Probe spec khai báo `type: static+runtime` nhưng chỉ có static grep (B1-B4 blocks). Không có Playwright launch.
- **Coverage thiếu:** `Can I Use` matrix checks (`caniuse-lite` D16 — text-only, không live query API), feature detection runtime.
- **Impact:** Browser compat issues chỉ được detect nếu code dùng browser API mà không có feature detection — static grep cơ bản.

### P-QD7-api-version-compat (SPEC_GAP — D1/D2)
- **Lý do:** Probe spec chỉ có B1-B3 static grep + req-registry cross-ref. Không có HTTP curl check API version.
- **Coverage thiếu:** Runtime: client calls non-existent API version → CRITICAL (D2 severity_default outlier).
- **Impact:** API contract mismatches chỉ detect nếu version string explicitly in code vs registry.

### P-QD7-polyfill-coverage (SPEC_GAP)
- **Lý do:** Probe requires `browserslist` analysis tool at runtime — no bash wrapper in probe spec. Inline bash B1-B3 có `CACHE_KEY=` block nhưng không wire vào real `scan_cache.cache_lookup`.
- **Coverage thiếu:** Browserslist usage % comparison, auto-generating polyfill list.
- **Impact:** Polyfill gaps (D11 defensive PRE-GATE missing, D12 severity mismatch) cannot be measured statically.

### P-QD7-device-breakpoint-test (SPEC_GAP — D15 CRITICAL bug)
- **Lý do:** **D15 CRITICAL bug** — heredoc terminator `<< 'PWEOF'` (single-quoted) prevents bash from expanding `${WIDTH}`, `${HEIGHT}`, `${URL}` template literals. Playwright test config receives literal string `${WIDTH}` → silent runtime failure.
- **Fix needed:** Unquoted `<< PWEOF` with JS template literals escaped, OR temp-file approach (như P-QD4-core-web-vitals working pattern).
- **Impact:** Probe is fundamentally broken as spec'd. Zero valid signals emitted.

---

## §6 Known Issues và Edge Cases

### Cascade (overlapping patterns — probe design)
- `document.execCommand('copy')` → 2 signals (HIGH specific + MEDIUM general) per occurrence
- This is expected probe behavior (D13: all patterns unconditional). File-level TP still = 1.
- IMP candidate: probe should deduplicate overlapping matches or use dispatch mode.

### Multiple occurrences (pos-03 CSS)
- `zoom: 1.5` (line 7) + `zoom: 0.75` (line 13) → 2 LOW signals
- Both are true positives — each CSS occurrence is a real deprecated usage
- File correctly flagged with 2 signals.

### FP Risk — Test Files (FP-09)
- `EXCLUDE_PATTERN` has no `\.test\.` exclusion (unlike QD5 which added it as neg-04)
- Test files using deprecated APIs intentionally → not filtered → FP flooding risk
- **IMP gap:** IMP-QD7-010 ↔ IMP-QD5-015 (EXCLUDE_PATTERN config cross-dim MERGE)

### Cache Gap (D14)
- `wf-fix-probe-static-deprecated.sh` has 0 scan cache integration
- Header `Cache policy: allowed` — spec declares cache but bash has no `USE_CACHE`
- Cross-dim: QD4 D13 ↔ QD7 D14 — same external-bash-cache-gap pattern

### CDG orphan flag (D10)
- `deprecated_pkg` signals include `cdg_flags: ["CDG-DEPS-DOWN"]`
- `wf-fix-common.sh` has no `CDG-DEPS-DOWN` handler — flag is orphan metadata
- Cross-dim confirmed: same pattern as QD4 D4

---

## §7 DoD Compliance

| Criterion | Required | Status |
|---|:-:|:-:|
| ≥5 positive cases | 5 | ✅ 5 cases (4 code files + 1 package.json) |
| ≥5 negative cases | 5 | ✅ 5 cases (4 code files + 1 package.json) |
| expected-signals.json schema valid (jq lane-signals-v1) | Pass | ✅ |
| Live run produces signals — all positive files detected | TP_files=5 | ✅ 5/5 |
| Precision ≥ 0.70 (file-level, live-testable) | 0.70 | ✅ 1.00 |
| Recall ≥ 0.60 (file-level, live-testable) | 0.60 | ✅ 1.00 |
| FP = 0 | 0 | ✅ 0 |
| SPEC_GAP section documented | Required | ✅ §5 |
| Fingerprint format verified | sha256:<64-hex> | ✅ (D17 6-token noted) |

**Overall DoD: 9/9 PASS** ✅
