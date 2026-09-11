#!/usr/bin/env python3
"""Stage D: Create all 5 lane skeletons + probe files for QD3-QD7."""
import os

BASE = "Z:/Working/MCV3/.claude/skills/workflow"

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path

def probe_stub(qd, slug, ptype, profiles, purpose, cache_note="allowed"):
    return f"""# P-{qd}-{slug}

| Thuoc tinh | Gia tri |
|-----------|---------|
| Probe ID | P-{qd}-{slug} |
| Loai | {ptype} |
| Profile | {profiles} |
| Muc dich | {purpose} |
| Cache | **{cache_note}** |
| Migrates from | Stage D (new) |

## SENSE

**B1**: [Placeholder — doc source code / config / architecture docs]

**B2**: [Placeholder — extract relevant data]

**B3**: [Placeholder — check scan cache]

## THINK

[Placeholder — analysis logic]

## ACT

[Placeholder — emit signals with dimension_hint="{qd}"]

## VERIFY

- [ ] Signal co dimension_hint = "{qd}"
- [ ] Evidence khong rong
- [ ] Severity trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] probe_id match ^P-{qd}-[a-z0-9-]+$

## Severity Rules

| Pattern | Severity |
|---------|----------|
| [Critical pattern] | CRITICAL |
| [High pattern] | HIGH |
| [Medium pattern] | MEDIUM |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Source not found | Skip probe, emit 0 signals |
| Parse error | Log warning, continue |
"""

def signals_template(lane, dim):
    return f"""{{
  "$schema": "lane-signals-v1",
  "lane": "{lane}",
  "dimension": "{dim}",
  "session_dir": "[SESSION_DIR]",
  "generated_at": "YYYY-MM-DDTHH:mm:ssZ",
  "signals": []
}}
"""

def evals_stub(lane, desc):
    return f"""{{
  "$schema": "evals-v1",
  "skill": "{lane}",
  "version": "1.0.0",
  "description": "{desc}",
  "test_cases": []
}}
"""

def phase_summary_template(dim_name):
    return f"""# Phase Summary — {dim_name}

- Che do: [PROFILE]
- So bug phat hien: [N] (Critical [a] / High [b] / Medium [c] / Low [d])
- Probes chay: [X]/[Y] ([Z] bo qua)
- Thoi gian chay: [mm] phut
- Diem noi bat: [1-2 cau tom tat ket qua chinh]
- Can nguoi quyet dinh: [co/khong — ly do]
- File quan trong: [signals.json, lane-report.md]
- Loi khuyen: [1 cau khuyen nghi]
"""

# ============================================================
# LANE DEFINITIONS
# ============================================================
lanes = {
    "wf-fix-security": {
        "dim": "QD3", "dim_name": "Security Vulnerabilities",
        "probes": [
            ("dependency-vuln-scan", "static+runtime", "quick, standard, deep, exhaustive", "Quet dependency vulnerabilities", "NEVER (ADR-22 R6)"),
            ("owasp-top-ten", "static", "quick, standard, deep, exhaustive", "OWASP Top 10 pattern analysis", "NEVER (ADR-22 R6)"),
            ("dangerous-deserialize", "static", "quick, standard, deep, exhaustive", "Unsafe code eval + deserialization", "NEVER (ADR-22 R6)"),
            ("secret-detection", "static", "standard, deep, exhaustive", "Hard-coded secrets/credentials", "NEVER (ADR-22 R6)"),
            ("auth-flow-verify", "runtime+agent", "standard, deep, exhaustive", "Authentication/authorization flow", "NEVER (ADR-22 R6)"),
            ("cors-policy-check", "runtime", "standard, deep, exhaustive", "CORS configuration review", "NEVER (ADR-22 R6)"),
            ("security-header-audit", "runtime", "deep, exhaustive", "Security headers verification", "NEVER (ADR-22 R6)"),
        ],
    },
    "wf-fix-performance": {
        "dim": "QD4", "dim_name": "Performance Bottlenecks",
        "probes": [
            ("bundle-size-audit", "static", "quick, standard, deep, exhaustive", "Bundle size threshold check", "allowed"),
            ("render-perf-check", "runtime", "quick, standard, deep, exhaustive", "Render performance measurement", "skip"),
            ("api-latency-probe", "runtime", "quick, standard, deep, exhaustive", "API response latency measurement", "skip"),
            ("db-query-analysis", "static+runtime", "standard, deep, exhaustive", "DB query pattern analysis (N+1, missing idx)", "allowed"),
            ("memory-leak-scan", "static", "standard, deep, exhaustive", "Memory leak pattern detection", "allowed"),
            ("core-web-vitals", "runtime", "deep, exhaustive", "Core Web Vitals (LCP, FID, CLS)", "skip"),
        ],
    },
    "wf-fix-ux-a11y": {
        "dim": "QD5", "dim_name": "UX Consistency + Accessibility",
        "probes": [
            ("ui-traversal-deep", "runtime", "quick, standard, deep, exhaustive", "Deep UI traversal + interaction smoke", "skip"),
            ("label-consistency", "static+runtime", "quick, standard, deep, exhaustive", "UI label vs spec label cross-ref", "allowed"),
            ("accessibility-check", "runtime+agent", "quick, standard, deep, exhaustive", "WCAG 2.2 accessibility audit", "skip"),
            ("color-contrast-audit", "static", "standard, deep, exhaustive", "Color contrast ratio check", "allowed"),
            ("keyboard-nav-check", "runtime", "standard, deep, exhaustive", "Keyboard navigation verification", "skip"),
            ("responsive-layout", "runtime", "deep, exhaustive", "Responsive layout test", "skip"),
            ("aria-attribute-scan", "static", "standard, deep, exhaustive", "ARIA attribute correctness", "allowed"),
        ],
    },
    "wf-fix-data": {
        "dim": "QD6", "dim_name": "Data Integrity + Schema Drift",
        "probes": [
            ("schema-drift-detect", "static+runtime", "quick, standard, deep, exhaustive", "Schema drift between model and migration", "allowed"),
            ("migration-integrity", "static", "quick, standard, deep, exhaustive", "Migration chain integrity (up/down pairs)", "allowed"),
            ("constraint-violation", "runtime", "quick, standard, deep, exhaustive", "Database constraint violation check", "skip"),
            ("data-type-mismatch", "static", "standard, deep, exhaustive", "Data type mismatch code vs schema", "allowed"),
            ("orm-model-sync", "static", "standard, deep, exhaustive", "ORM model vs DB schema sync", "allowed"),
            ("seed-data-audit", "static", "deep, exhaustive", "Seed data correctness audit", "allowed"),
        ],
    },
    "wf-fix-compat": {
        "dim": "QD7", "dim_name": "Browser/API/Device Compatibility",
        "probes": [
            ("browser-compat-check", "static+runtime", "quick, standard, deep, exhaustive", "Browser compatibility check", "allowed"),
            ("api-version-compat", "static+runtime", "quick, standard, deep, exhaustive", "API version compatibility", "allowed"),
            ("deprecated-api-usage", "static", "quick, standard, deep, exhaustive", "Deprecated API usage detection", "allowed"),
            ("polyfill-coverage", "static", "standard, deep, exhaustive", "Polyfill coverage check", "allowed"),
            ("device-breakpoint-test", "runtime", "deep, exhaustive", "Device breakpoint responsive test", "skip"),
        ],
    },
}

count = 0
for lane_name, lane_data in lanes.items():
    dim = lane_data["dim"]
    dim_name = lane_data["dim_name"]
    lane_dir = os.path.join(BASE, lane_name)

    # Probe stubs
    for slug, ptype, profiles, purpose, cache in lane_data["probes"]:
        path = write_file(
            os.path.join(lane_dir, "probes", f"P-{dim}-{slug}.md"),
            probe_stub(dim, slug, ptype, profiles, purpose, cache)
        )
        count += 1

    # Templates
    write_file(os.path.join(lane_dir, "templates", "signals.json"), signals_template(lane_name, dim))
    write_file(os.path.join(lane_dir, "templates", "phase-summary.md"), phase_summary_template(dim_name))
    count += 2

    # Evals
    write_file(os.path.join(lane_dir, "evals", "evals.json"), evals_stub(lane_name, f"Evals cho {dim} {dim_name} — stub"))
    count += 1

    print(f"  {lane_name} ({dim}): {len(lane_data['probes'])} probes + templates + evals")

print(f"\nDone: {count} files written")
