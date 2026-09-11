#!/usr/bin/env python3
"""Stage D: Create SKILL.md, _contract.json, dimension.json, _shared.md, lane-report.md for QD4-QD7."""
import os, json

BASE = "Z:/Working/MCV3/.claude/skills/workflow"

def w(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def skill_md(lane, dim, dim_name, probes, agent, cache_section, extra_sections=""):
    probe_table = "\n".join(
        f"| P-{dim}-{slug} | {ptype} | {profiles}+ | {purpose} |"
        for slug, ptype, profiles, purpose, _ in probes
    )
    return f"""---
name: {lane}
version: 1.0.0
last_updated: "2026-04-21"
description: |
  QD{dim[2:]} {dim_name} Lane — phat hien van de qua probes static + runtime + agent.
  Chay theo mo hinh Sense > Think > Act > Verify.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /{lane}: QD{dim[2:]} {dim_name} Lane

## Overview

| Thuoc tinh | Gia tri |
|-----------|---------|
| Dimension | {dim} — {dim_name} |
| Owner Agent | `{agent}` |
| Probes | {len(probes)} |
| Cache Policy | Xem probe-specific |

### Probe Map

| Probe ID | Loai | Profile | Muc dich |
|----------|------|---------|----------|
{probe_table}

## Entry Point

```bash
SESSION_DIR="$SESSION_DIR"  # Set by orchestrator
PROFILE="${{PROFILE:-standard}}"
BASE_URL="${{BASE_URL:-}}"
```

## PRE-GATE (CORE-011)

1. Verify session directory: `test -d "$SESSION_DIR"`
2. Verify registry: `jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json`
3. Create lane dirs: `mkdir -p "$SESSION_DIR/lanes/{dim}/"{{raw,evidence}}`
4. Init lane status: Write lane-status.json

## Execution

### Phase 1: SENSE — Thu thap du lieu
Chay probes theo profile. Doc source code, config, architecture docs.

### Phase 2: THINK — Phan tich
Phan tich findings theo dimension-specific rules.

### Phase 3: ACT — Emit Signals
Moi probe emits signals vao raw directory. Signal phai co:
- `dimension_hint: "{dim}"`
- `evidence` khong rong (ADR-09)
- `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]

### Phase 4: VERIFY — Kiem tra signals
Validate moi signal theo signal-v2 schema.

## Signal Bus Batch Ingest

```bash
python -m _shared.signal_bus.signal_bus ingest --signal-file "$SESSION_DIR/lanes/{dim}/raw/P-{dim}-<probe>.json" --session-dir "$SESSION_DIR"
python -m _shared.signal_bus.signal_bus flush --session-dir "$SESSION_DIR"
```

## POST-GATE (CORE-012)

T1→T4 validation. Sau PASS: write lane-report.md, phase-summary.md, update lane-status.json.

{cache_section}

{extra_sections}

## Fallback & Error Handling

| Tinh huong | Xu ly |
|-----------|-------|
| Probe fail | Log warning, continue |
| Agent timeout | Skip probe, emit 0 signals |
| Missing files | Skip static probes |
| No base_url | Skip runtime probes |

## References

- `.claude/skills/protocols/` — Shared protocols
- `_shared/signal_bus/signal_bus.py` — Signal Bus
- `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` — Probe specs
"""

def contract_json(lane, dim, probes, has_cache=True, has_base_url=True):
    inputs = [
        {"name": "--session-dir", "type": "path", "required": True, "description": "Session directory."},
        {"name": "--profile", "type": "enum", "values": ["quick","standard","deep","exhaustive"], "required": False, "default": "standard", "description": "Profile chay."},
    ]
    if has_cache:
        inputs.append({"name": "--use-cache", "type": "flag", "required": False, "description": "Opt-in scan cache cho static probes."})
    if has_base_url:
        inputs.append({"name": "--base-url", "type": "url", "required": False, "description": "App URL cho runtime probes."})

    procedure = [f"probes/P-{dim}-{slug}.md" for slug, *_ in probes] + [f"probes/_shared.md"]

    outputs_working = [
        {"path": f"$SESSION_DIR/lanes/{dim}/signals.json", "required": True, "template": "templates/signals.json", "notes": "Lane-local signals."},
        {"path": f"$SESSION_DIR/lanes/{dim}/lane-status.json", "required": True, "template": None, "notes": "Lane progress tracker."},
        {"path": f"$SESSION_DIR/lanes/{dim}/lane-report.md", "required": True, "template": "templates/lane-report.md", "notes": "Lane report (CORE-031)."},
        {"path": f"$SESSION_DIR/lanes/{dim}/phase-summary.md", "required": True, "template": "templates/phase-summary.md", "notes": "Phase summary <=15 dong (CORE-028)."},
        {"path": f"$SESSION_DIR/lanes/{dim}/raw/", "required": False, "template": None, "notes": "Per-probe raw output."},
    ]

    return json.dumps({
        "$schema": "skill-contract-v1",
        "skill": lane,
        "version": "1.0.0",
        "phase": "lane",
        "description": f"{dim} {lane.split('-',3)[-1].replace('-',' ').title()} Lane.",
        "prerequisites": {
            "files": [".mc-data/docs/_meta/req-registry.json"],
            "directories_any_of": ["src", "apps"],
            "env_vars": {"SESSION_DIR": "Set by orchestrator"},
        },
        "inputs": inputs,
        "procedure": procedure,
        "outputs": {"working": outputs_working},
        "registry_scope": {"fields_owned": [], "notes": f"{dim} Lane KHONG ghi req-registry.json."},
        "cross_skill_contracts": {
            "spawned_by": {"skill": "wf-fix-bugs", "trigger": f"QD{dim[2:]} trong selected_dims", "receives": ["--session-dir", "--profile"]},
            "returns_to": {"skill": "wf-fix-bugs", "trigger": f"POST-GATE {dim} complete", "provides": [f"$SESSION_DIR/lanes/{dim}/signals.json", f"$SESSION_DIR/lanes/{dim}/lane-report.md"]},
            "produces_for": {"signal_bus": [f"$SESSION_DIR/lanes/{dim}/signals.json"]},
            "consumes_from": {"wf-fix-bugs": [f"$SESSION_DIR/fix-status.json"], "wf-analyze-requirements": [".mc-data/docs/_meta/req-registry.json"], "wf-design": [".mc-data/docs/phase3-architecture/"]},
        }
    }, indent=2, ensure_ascii=False)

def dimension_json(dim, dim_name, short_name, agent, probes, exit_criteria, severity_rules):
    probe_list = []
    for slug, ptype, profiles, purpose, cache in probes:
        probe_list.append({
            "id": f"P-{dim}-{slug}",
            "name": purpose,
            "type": ptype.split("+")[0] if "+" not in ptype else ptype,
            "depth": [p.strip() for p in profiles.split(",")],
            "cache_policy": cache.split(" ")[0].lower() if "never" not in cache.lower() else "never",
        })
    return json.dumps({
        "$schema": "dimension-v1",
        "dimension_id": dim,
        "dimension_name": dim_name,
        "short_name": short_name,
        "owner_agent": agent,
        "version": "1.0.0",
        "description": f"Dimension {dim}: {dim_name}",
        "probes": probe_list,
        "exit_criteria": exit_criteria,
        "severity_rules": severity_rules,
        "dependencies": {"agents": [agent]},
        "outputs": {
            "signals_file": f"$SESSION_DIR/lanes/{dim}/signals.json",
            "lane_report": f"$SESSION_DIR/lanes/{dim}/lane-report.md",
            "phase_summary": f"$SESSION_DIR/lanes/{dim}/phase-summary.md",
        }
    }, indent=2, ensure_ascii=False)

def shared_md(dim, cache_default="allowed"):
    return f"""# {dim} Shared Probe Protocols

## 1. Signal Emission Protocol

Signal schema signal-v2. Moi signal phai co:
- `dimension_hint: "{dim}"`
- `probe_id` match `^P-{dim}-[a-z0-9-]+$`
- `description` >= 10 ky tu
- It nhat 1 evidence field non-empty (ADR-09)

Raw output: `$SESSION_DIR/lanes/{dim}/raw/P-{dim}-<probe>.json`

## 2. Scan Cache Protocol

Cache policy: **{cache_default}** cho static probes. Runtime probes luon skip cache.

## 3. Severity Mapping ({dim})

| Pattern | Severity |
|---------|----------|
| Critical trigger | CRITICAL |
| High trigger | HIGH |
| Medium trigger | MEDIUM |
| Informational | LOW |

## 4. Profile-Based Probe Selection

Chay probes theo profile (quick/standard/deep/exhaustive).
Xem dimension.json exit_criteria cho probe list chinh xac.

## 5. Checkpoint Protocol

Sau moi probe, update lane-status.json voi probe status va signal count.
"""

def lane_report_md(lane, dim, dim_name, probes):
    rows = "\n".join(
        f"| P-{dim}-{slug} | {purpose} | [STATUS] | [N] | |"
        for slug, *_ , purpose, _ in [(p[0],p[1],p[2],p[3],p[4]) for p in probes]
    )
    return f"""# Lane Report — {dim} {dim_name}

## Thong tin

- Lane: {lane} ({dim})
- Profile: [PROFILE]
- Session: [SESSION_DIR]
- Thoi gian chay: [DURATION] phut

## Ket qua probes

| Probe ID | Ten | Trang thai | Signals | Ghi chu |
|----------|-----|-----------|---------|---------|
{rows}

## Tom tat severity

| Severity | So luong |
|----------|---------|
| CRITICAL | [N] |
| HIGH | [N] |
| MEDIUM | [N] |
| LOW | [N] |
| **Tong** | **[TOTAL]** |

## Probes bo qua

- [Danh sach probes bi skip va ly do]

## Khuyen nghi

- [Khuyen nghi cho lan chay tiep theo]
"""

# ============================================================
# LANE DEFINITIONS
# ============================================================

q3 = "NEVER (ADR-22 R6)"
q4_probes = [
    ("bundle-size-audit", "static", "quick, standard, deep, exhaustive", "Bundle Size Audit", "allowed"),
    ("render-perf-check", "runtime", "quick, standard, deep, exhaustive", "Render Performance", "skip"),
    ("api-latency-probe", "runtime", "quick, standard, deep, exhaustive", "API Latency", "skip"),
    ("db-query-analysis", "static+runtime", "standard, deep, exhaustive", "DB Query Analysis", "allowed"),
    ("memory-leak-scan", "static", "standard, deep, exhaustive", "Memory Leak Scan", "allowed"),
    ("core-web-vitals", "runtime", "deep, exhaustive", "Core Web Vitals", "skip"),
]

q5_probes = [
    ("ui-traversal-deep", "runtime", "quick, standard, deep, exhaustive", "Deep UI Traversal", "skip"),
    ("label-consistency", "static+runtime", "quick, standard, deep, exhaustive", "Label Consistency", "allowed"),
    ("accessibility-check", "runtime+agent", "quick, standard, deep, exhaustive", "Accessibility Check", "skip"),
    ("color-contrast-audit", "static", "standard, deep, exhaustive", "Color Contrast Audit", "allowed"),
    ("keyboard-nav-check", "runtime", "standard, deep, exhaustive", "Keyboard Nav Check", "skip"),
    ("responsive-layout", "runtime", "deep, exhaustive", "Responsive Layout", "skip"),
    ("aria-attribute-scan", "static", "standard, deep, exhaustive", "ARIA Attribute Scan", "allowed"),
]

q6_probes = [
    ("schema-drift-detect", "static+runtime", "quick, standard, deep, exhaustive", "Schema Drift Detect", "allowed"),
    ("migration-integrity", "static", "quick, standard, deep, exhaustive", "Migration Integrity", "allowed"),
    ("constraint-violation", "runtime", "quick, standard, deep, exhaustive", "Constraint Violation", "skip"),
    ("data-type-mismatch", "static", "standard, deep, exhaustive", "Data Type Mismatch", "allowed"),
    ("orm-model-sync", "static", "standard, deep, exhaustive", "ORM Model Sync", "allowed"),
    ("seed-data-audit", "static", "deep, exhaustive", "Seed Data Audit", "allowed"),
]

q7_probes = [
    ("browser-compat-check", "static+runtime", "quick, standard, deep, exhaustive", "Browser Compat Check", "allowed"),
    ("api-version-compat", "static+runtime", "quick, standard, deep, exhaustive", "API Version Compat", "allowed"),
    ("deprecated-api-usage", "static", "quick, standard, deep, exhaustive", "Deprecated API Usage", "allowed"),
    ("polyfill-coverage", "static", "standard, deep, exhaustive", "Polyfill Coverage", "allowed"),
    ("device-breakpoint-test", "runtime", "deep, exhaustive", "Device Breakpoint Test", "skip"),
]

lanes = [
    ("wf-fix-performance", "QD4", "Performance Bottlenecks", "performance-benchmarker",
     q4_probes, "allowed", True, True,
     {"quick": {"probes_required": ["P-QD4-bundle-size-audit","P-QD4-render-perf-check","P-QD4-api-latency-probe"],"max_signals_per_probe":30},
      "standard": {"probes_required": ["P-QD4-bundle-size-audit","P-QD4-render-perf-check","P-QD4-api-latency-probe","P-QD4-db-query-analysis","P-QD4-memory-leak-scan"],"max_signals_per_probe":50},
      "deep": {"probes_required": "ALL","max_signals_per_probe":100},
      "exhaustive": {"probes_required": "ALL","max_signals_per_probe":300}},
     {"critical_triggers": ["API latency > 10s","Memory leak trong production"],"high_triggers": ["API p95 > 2s","Bundle > 1MB","N+1 query"],"medium_triggers": ["API p95 > 500ms","Bundle chunk > 200KB"],"max_aggregation": True}),

    ("wf-fix-ux-a11y", "QD5", "UX Consistency + Accessibility", "ux-researcher",
     q5_probes, "allowed", True, True,
     {"quick": {"probes_required": ["P-QD5-ui-traversal-deep","P-QD5-label-consistency","P-QD5-accessibility-check"],"max_signals_per_probe":50},
      "standard": {"probes_required": ["P-QD5-ui-traversal-deep","P-QD5-label-consistency","P-QD5-accessibility-check","P-QD5-color-contrast-audit","P-QD5-keyboard-nav-check","P-QD5-aria-attribute-scan"],"max_signals_per_probe":100},
      "deep": {"probes_required": "ALL","max_signals_per_probe":200},
      "exhaustive": {"probes_required": "ALL","max_signals_per_probe":500}},
     {"critical_triggers": ["WCAG Level A violation tren primary flow"],"high_triggers": ["Missing alt text","Keyboard trap","Label mismatch"],"medium_triggers": ["Color contrast < 4.5:1","Missing ARIA label"],"max_aggregation": True}),

    ("wf-fix-data", "QD6", "Data Integrity + Schema Drift", "dba",
     q6_probes, "allowed", True, False,
     {"quick": {"probes_required": ["P-QD6-schema-drift-detect","P-QD6-migration-integrity","P-QD6-constraint-violation"],"max_signals_per_probe":30},
      "standard": {"probes_required": ["P-QD6-schema-drift-detect","P-QD6-migration-integrity","P-QD6-constraint-violation","P-QD6-data-type-mismatch","P-QD6-orm-model-sync"],"max_signals_per_probe":50},
      "deep": {"probes_required": "ALL","max_signals_per_probe":100},
      "exhaustive": {"probes_required": "ALL","max_signals_per_probe":300}},
     {"critical_triggers": ["Data loss risk","Migration khong co down()"],"high_triggers": ["ORM model khong dong bo","Missing constraint"],"medium_triggers": ["Data type mismatch","Seed data outdated"],"max_aggregation": True}),

    ("wf-fix-compat", "QD7", "Browser/API/Device Compatibility", "frontend-developer",
     q7_probes, "allowed", True, True,
     {"quick": {"probes_required": ["P-QD7-browser-compat-check","P-QD7-api-version-compat","P-QD7-deprecated-api-usage"],"max_signals_per_probe":30},
      "standard": {"probes_required": ["P-QD7-browser-compat-check","P-QD7-api-version-compat","P-QD7-deprecated-api-usage","P-QD7-polyfill-coverage"],"max_signals_per_probe":50},
      "deep": {"probes_required": "ALL","max_signals_per_probe":100},
      "exhaustive": {"probes_required": "ALL","max_signals_per_probe":300}},
     {"critical_triggers": ["API breaking change khong co fallback"],"high_triggers": ["Deprecated API khong co plan","Missing polyfill cho required feature"],"medium_triggers": ["Minor version mismatch","Layout break tai non-standard viewport"],"max_aggregation": True}),
]

count = 0
for lane, dim, dim_name, agent, probes, cache_default, has_cache, has_base_url, exit_crit, sev_rules in lanes:
    d = os.path.join(BASE, lane)

    # SKILL.md
    cache_section = "## Scan Cache\n\nCache policy: {cache_default} cho static probes. Runtime probes skip cache."
    w(os.path.join(d, "SKILL.md"), skill_md(lane, dim, dim_name, probes, agent, cache_section))
    count += 1

    # _contract.json
    w(os.path.join(d, "_contract.json"), contract_json(lane, dim, probes, has_cache, has_base_url))
    count += 1

    # dimension.json
    w(os.path.join(d, "dimension.json"), dimension_json(dim, dim_name, dim_name.split()[-1], agent, probes, exit_crit, sev_rules))
    count += 1

    # probes/_shared.md
    w(os.path.join(d, "probes", "_shared.md"), shared_md(dim, cache_default))
    count += 1

    # templates/lane-report.md
    w(os.path.join(d, "templates", "lane-report.md"), lane_report_md(lane, dim, dim_name, probes))
    count += 1

    print(f"  {lane} ({dim}): SKILL.md + _contract.json + dimension.json + _shared.md + lane-report.md")

print(f"\nDone: {count} lane-level files written")
