# Lane Profile Resolver

> **Phien ban:** v1.0 (S3 wf-fix-bugs v7.0)
> **Ap dung cho:** 10 lane skills (QD1-QD10)
> **Muc dich:** Mapping `--profile` (quick|standard|deep|exhaustive) → probe subset cho moi lane

---

## Nguyen tac

1. Profile DECIDE WHICH probes run, KHONG decide HOW probes run
2. Lane skill van phai check budget (issue count, context %, duration limit) doc lap
3. Profile chi la guideline — lane co the override neu can (vi du: probe security CRIT phai chay du profile=quick)

---

## Profile semantics

| Profile | Ngu canh | Coverage | Latency | Token cost |
|---------|----------|----------|---------|-----------|
| `quick` | Pre-commit, CI fast lane | 30-50% | <1 min/lane | Low |
| `standard` | Default — chay hang ngay | 70-80% | 2-5 min/lane | Medium |
| `deep` | Pre-release, weekly audit | 90% | 5-10 min/lane | High |
| `exhaustive` | Pre-Go-Live audit | 100% | 10-20 min/lane | Very high |

---

## Per-lane mapping

### QD1 (wf-fix-functional, 7 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD1-req-registry-xref | ✅ | ✅ | ✅ | ✅ |
| P-QD1-route-config-parse | ✅ | ✅ | ✅ | ✅ |
| P-QD1-infra-preflight | ❌ | ✅ | ✅ | ✅ |
| P-QD1-deep-ui-traversal | ❌ | ❌ | ✅ | ✅ |
| P-QD1-api-smoke | ❌ | ✅ | ✅ | ✅ |
| P-QD1-orphan-ui-detect | ❌ | ✅ | ✅ | ✅ |
| P-QD1-agent-feature-verify | ❌ | ❌ | ✅ | ✅ |

**Coverage:** quick=2/7, standard=5/7, deep=7/7, exhaustive=7/7+

### QD2 (wf-fix-business, 5 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD2-hardcoded-value-detect | ✅ | ✅ | ✅ | ✅ |
| P-QD2-calculation-check | ❌ | ✅ | ✅ | ✅ |
| P-QD2-domain-fixture | ❌ | ✅ | ✅ | ✅ |
| P-QD2-domain-expert-review | ❌ | ❌ | ✅ | ✅ |
| P-QD2-business-analyst-review | ❌ | ❌ | ❌ | ✅ |

**Coverage:** quick=1/5, standard=3/5, deep=4/5, exhaustive=5/5

**Special:** quick mode neu user --profile=quick → QD2 co the SKIP toan bo (chi 1 probe nhanh) → orchestrator quyet dinh.

### QD3 (wf-fix-security, 7 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD3-secret-detection | ✅ | ✅ | ✅ | ✅ |
| P-QD3-dependency-vuln-scan | ✅ | ✅ | ✅ | ✅ |
| P-QD3-dangerous-deserialize | ❌ | ✅ | ✅ | ✅ |
| P-QD3-cors-policy-check | ❌ | ✅ | ✅ | ✅ |
| P-QD3-security-header-audit | ❌ | ✅ | ✅ | ✅ |
| P-QD3-auth-flow-verify | ❌ | ❌ | ✅ | ✅ |
| P-QD3-owasp-top-ten | ❌ | ❌ | ✅ | ✅ |

**Coverage:** quick=2/7, standard=5/7, deep=7/7, exhaustive=7/7+

**Special:** ADR-22 Rule 6 — QD3 KHONG dung scan cache trong moi profile.

### QD4 (wf-fix-performance, 6 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD4-bundle-size-audit | ✅ | ✅ | ✅ | ✅ |
| P-QD4-render-perf-check | ❌ | ✅ | ✅ | ✅ |
| P-QD4-api-latency-probe | ❌ | ✅ | ✅ | ✅ |
| P-QD4-db-query-analysis | ❌ | ✅ | ✅ | ✅ |
| P-QD4-core-web-vitals | ❌ | ❌ | ✅ | ✅ |
| P-QD4-memory-leak-scan | ❌ | ❌ | ❌ | ✅ |

**Coverage:** quick=1/6, standard=4/6, deep=5/6, exhaustive=6/6

### QD5 (wf-fix-ux-a11y, 7 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD5-aria-attribute-scan | ✅ | ✅ | ✅ | ✅ |
| P-QD5-label-consistency | ✅ | ✅ | ✅ | ✅ |
| P-QD5-color-contrast-audit | ❌ | ✅ | ✅ | ✅ |
| P-QD5-keyboard-nav-check | ❌ | ✅ | ✅ | ✅ |
| P-QD5-accessibility-check | ❌ | ❌ | ✅ | ✅ |
| P-QD5-responsive-layout | ❌ | ❌ | ✅ | ✅ |
| P-QD5-ui-traversal-deep | ❌ | ❌ | ❌ | ✅ |

**Coverage:** quick=2/7, standard=4/7, deep=6/7, exhaustive=7/7

### QD6 (wf-fix-data, 6 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD6-orm-model-sync | ✅ | ✅ | ✅ | ✅ |
| P-QD6-data-type-mismatch | ✅ | ✅ | ✅ | ✅ |
| P-QD6-schema-drift-detect | ❌ | ✅ | ✅ | ✅ |
| P-QD6-migration-integrity | ❌ | ✅ | ✅ | ✅ |
| P-QD6-constraint-violation | ❌ | ❌ | ✅ | ✅ |
| P-QD6-seed-data-audit | ❌ | ❌ | ❌ | ✅ |

**Coverage:** quick=2/6, standard=4/6, deep=5/6, exhaustive=6/6

### QD7 (wf-fix-compat, 5 probes)

| Probe | quick | standard | deep | exhaustive |
|-------|:-----:|:--------:|:----:|:----------:|
| P-QD7-deprecated-api-usage | ✅ | ✅ | ✅ | ✅ |
| P-QD7-api-version-compat | ❌ | ✅ | ✅ | ✅ |
| P-QD7-browser-compat-check | ❌ | ✅ | ✅ | ✅ |
| P-QD7-polyfill-coverage | ❌ | ❌ | ✅ | ✅ |
| P-QD7-device-breakpoint-test | ❌ | ❌ | ❌ | ✅ |

**Coverage:** quick=1/5, standard=3/5, deep=4/5, exhaustive=5/5

---

## Resolver Implementation

Lane skill PHAI resolve probe list theo profile. 2 patterns:

### Pattern A — Inline shell logic (default)

```bash
# Trong PRE-GATE Step 4
case "$PROFILE" in
  quick) PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse") ;;
  standard) PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse"
                    "P-QD1-infra-preflight" "P-QD1-api-smoke" "P-QD1-orphan-ui-detect") ;;
  deep|exhaustive) PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse"
                           "P-QD1-infra-preflight" "P-QD1-deep-ui-traversal"
                           "P-QD1-api-smoke" "P-QD1-orphan-ui-detect"
                           "P-QD1-agent-feature-verify") ;;
esac
```

### Pattern B — Python module call (S5 enhancement)

```bash
# S5 will introduce: bash -c "python -m profile_resolver lane --lane QD1 --profile $PROFILE"
# Output: JSON list cua probe IDs
PROBES_JSON=$(python -m profile_resolver lane --lane QD1 --profile "$PROFILE")
PROBES=($(echo "$PROBES_JSON" | jq -r '.[]'))
```

S3 chi document mapping. Lane skill PRE-GATE dung Pattern A inline.

---

## Override rules

Lane skill MAY override profile mapping khi:

1. **Critical security:** QD3 probe phat hien CRITICAL → tu dong run them deep probes (bump up)
2. **Cache miss:** Probe co cache hit → run light, KHONG hit → run full
3. **Resource unavailable:** Runtime probe khong co --base-url → SKIP regardless of profile
4. **CDG flag:** User reject CDG → SKIP probe lien quan

Override PHAI log vao `lane-status.json.probes[].skip_reason` hoac `errors[]` cho transparency.

---

## Audit

Lane skill log probe selection vao `lane-status.json`:

```json
{
  "profile": "standard",
  "probes": [
    {"id": "P-QD1-req-registry-xref", "status": "done", ...},
    {"id": "P-QD1-route-config-parse", "status": "done", ...},
    {"id": "P-QD1-infra-preflight", "status": "skipped", "skip_reason": "no --base-url"}
  ]
}
```

Orchestrator (`wf-fix-bugs`) audit qua `coverage-report.md`: `[probes_run / total_probes_in_profile]`.
