# Phase A — Design Closure

> **Mục tiêu:** Khoá thiết kế v2.1, tạo baseline, chuẩn bị infrastructure cho Phase B.
> **Duration:** 2-3 ngày
> **Dependencies:** None (entry point)
> **Tag khi xong:** `design-legacy-scan-v2.1-approved`
> **Rollback:** Revert git tag (không ảnh hưởng code).

---

## Prerequisites

- [ ] Read [../00-master-plan.md](../00-master-plan.md) §1-3
- [ ] Read [../01-session-protocol.md](../01-session-protocol.md)
- [ ] Access to Owner + DEVKIT core team cho sign-off

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| A.1 | Backup v4.1 skill + create feature branch | CRITICAL | 30' | ⬜ |
| A.2 | Create Migration Progress Tracker | LOW | 30' | ⬜ |
| A.3 | Prepare 3 test fixtures + v4.1 baseline output | **CRITICAL** | 1 ngày | ⬜ |
| A.4 | Review + sign-off 17 ADRs | CRITICAL | 2-3 giờ | ⬜ |
| A.5 | Draft `_contract.json` v5.0.0 | HIGH | 2-3 giờ | ⬜ |
| A.6 | Tạo 7 template file skeletons | HIGH | 4-5 giờ | ⬜ |
| A.7 | Setup IPS Python module skeleton | HIGH | 3-4 giờ | ⬜ |

**Suggested order:** A.1 → A.2 (parallel) → A.3 (long running, can parallel với A.4) → A.4 → A.5 → A.6 → A.7.

---

## Task A.1 — Backup + Feature Branch

**Priority:** CRITICAL · **Duration:** 30 phút · **Status:** ⬜

### Actions

```bash
# 1. Tag v4.1 baseline
git tag -a legacy-scan-v4.1.0-baseline -m "Baseline before v5.0 refactor — 2026-04-22"
git push origin legacy-scan-v4.1.0-baseline

# 2. Create feature branch cho Phase A
git checkout -b feat/wf-legacy-scan-v5.0-phase-a

# 3. Backup 3 skills + scripts
mkdir -p .claude/skills/workflow/.v4.1.bak
cp -r .claude/skills/workflow/wf-legacy-scan .claude/skills/workflow/.v4.1.bak/
cp -r .claude/skills/workflow/wf-legacy-classify .claude/skills/workflow/.v4.1.bak/
cp -r .claude/skills/workflow/wf-legacy-extract .claude/skills/workflow/.v4.1.bak/

mkdir -p .claude/scripts/.v4.1.bak
cp .claude/scripts/legacy-scan-*.sh .claude/scripts/.v4.1.bak/
cp .claude/scripts/ui-coverage-scan.sh .claude/scripts/.v4.1.bak/

# 4. .gitignore cho backup folders (không commit binary backup vào git — tag đã đủ)
echo ".v4.1.bak/" >> .claude/skills/workflow/.gitignore
echo ".v4.1.bak/" >> .claude/scripts/.gitignore
```

### Verify

```bash
# Tag exists
git tag -l | grep legacy-scan-v4.1.0-baseline

# Branch active
git branch --show-current  # → feat/wf-legacy-scan-v5.0-phase-a

# Backup folders exist
ls .claude/skills/workflow/.v4.1.bak/
ls .claude/scripts/.v4.1.bak/
```

### Acceptance Criteria

- [ ] Tag `legacy-scan-v4.1.0-baseline` exists at current main HEAD
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-a` created from main
- [ ] Backup folders có đủ 3 skills + 5 bash scripts
- [ ] `.gitignore` updated (backup not tracked)

---

## Task A.2 — Migration Progress Tracker

**Priority:** LOW · **Duration:** 30 phút · **Status:** ⬜

### Actions

Tạo `docs/design/skills/wf-legacy-scan/MIGRATION-PROGRESS.md`:

```markdown
# Migration Progress Tracker — wf-legacy-scan v4.1 → v5.0

**Design version:** v2.1
**Branch strategy:** feat/wf-legacy-scan-v5.0-phase-{X}

| Phase | Status | Branch | Tag | Start | End | Owner | Notes |
|-------|--------|--------|-----|-------|-----|-------|-------|
| A — Design Closure | 🟡 | feat/...-phase-a | — | 2026-04-22 | — | — | 7 actions |
| B — Foundation | ⬜ | — | — | — | — | — | — |
| C — Profiles + IPS + VN | ⬜ | — | — | — | — | — | — |
| D — Agents + Sub-migration | ⬜ | — | — | — | — | — | CRITICAL |
| E — Checkpoint + Concurrency + Cache | ⬜ | — | — | — | — | — | — |
| F — Impact + Incremental | ⬜ | — | — | — | — | — | — |
| G — Bash Refactor | ⬜ | — | — | — | — | — | — |
| H — Resume Routing | ⬜ | — | — | — | — | — | — |
| I — Integration + Testing | ⬜ | — | — | — | — | — | — |
| J — Migration + Docs | ⬜ | — | — | — | — | — | — |

## Current Phase: A

**Blockers:** None
**Risks:** None
**Timeline:** On track (day 1 of 3)
```

### Verify

```bash
test -s docs/design/skills/wf-legacy-scan/MIGRATION-PROGRESS.md
```

### Acceptance Criteria

- [ ] File exists với table đủ 10 phases
- [ ] Phase A marked 🟡 In Progress

---

## Task A.3 — Prepare 3 Fixtures + v4.1 Baseline

**Priority:** CRITICAL · **Duration:** 1 ngày · **Status:** ⬜

> **Blocking for Phase D.** Không có baseline thì không verify được backward-compat lock.

### 3 Fixtures Needed

| Fixture | Size | Stack | Language | Domain |
|---------|------|-------|----------|--------|
| `small-en` | 50 files, 3 modules | TypeScript + React | EN | sales (simple CRM) |
| `medium-vn` | 500 files, 10 modules | .NET + React | VN (qlkh, hoadon, qlns, ...) | finance + HR + sales |
| `large-mixed` | 1,500 files, 30 modules | Node.js monorepo | EN + VN mix | finance + logistics |

### Actions

```bash
# 1. Create fixtures folder
mkdir -p docs/design/skills/wf-legacy-scan/fixtures
cd docs/design/skills/wf-legacy-scan/fixtures

# 2. Option A — Generate fixtures from scratch (recommended for control)
# Use seed project templates:
# - Clone minimal React app → rename modules → 50 files
# - Clone .NET ERP template → localize module names sang VN → 500 files
# - Clone monorepo template → mix EN + VN → 1,500 files

# 2. Option B — Anonymize real projects (faster, privacy risk)
# Take 3 real internal projects → strip secrets → anonymize names

# 3. For each fixture, commit structure + README (content in .gitignore if large)
cat > small-en/README.md <<EOF
# Fixture: small-en
- Files: 50
- Modules: 3 (customer, sales, reporting)
- Stack: TypeScript + React
- Domain: sales (CRM)
- Source: <...>
EOF

# 4. Run v4.1 baseline trên cả 3 fixtures
git checkout legacy-scan-v4.1.0-baseline

cd fixtures/small-en
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan ../small-en.baseline-v4.1/
rm -rf .mc-data

cd ../medium-vn
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan ../medium-vn.baseline-v4.1/
rm -rf .mc-data

cd ../large-mixed
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan ../large-mixed.baseline-v4.1/
rm -rf .mc-data

git checkout feat/wf-legacy-scan-v5.0-phase-a

# 5. Commit baseline outputs
git add docs/design/skills/wf-legacy-scan/fixtures/*.baseline-v4.1/
git commit -m "Phase A A.3: Add v4.1 baseline output for 3 fixtures"
```

### Verify

```bash
# Check 3 baselines có đủ key outputs
for fx in small-en medium-vn large-mixed; do
  echo "=== $fx ==="
  test -s fixtures/${fx}.baseline-v4.1/project-context.md && echo "  project-context.md ✓"
  test -s fixtures/${fx}.baseline-v4.1/project-profile.json && echo "  project-profile.json ✓"
  test -s fixtures/${fx}.baseline-v4.1/assessment-report.json && echo "  assessment-report.json ✓"
  test -s fixtures/${fx}.baseline-v4.1/ledger.json && echo "  ledger.json ✓"
  test -d fixtures/${fx}.baseline-v4.1/inventory/ && echo "  inventory/ ✓"
  test -d fixtures/${fx}.baseline-v4.1/classified/ && echo "  classified/ ✓"
  test -d fixtures/${fx}.baseline-v4.1/extracted/ && echo "  extracted/ ✓"
done
```

### Acceptance Criteria

- [ ] 3 fixtures tồn tại với README + structure
- [ ] 3 baseline folders có đầy đủ: project-context.md, project-profile.json, assessment-report.json, ledger.json, inventory/, classified/, extracted/
- [ ] Baselines committed vào git (dù fixture content có thể gitignore)
- [ ] medium-vn fixture có ≥ 5 modules với tên tiếng Việt (qlkh, hoadon, qlns, chamcong, nhapkho, ...)

### Risks

- Không có real VN project để anonymize → fallback: generate synthetic VN project từ template.
- Large-mixed >1,500 files → v4.1 có thể context overflow → note trong session log, dùng large=800 files thay thế.

---

## Task A.4 — Sign-off 17 ADRs

**Priority:** CRITICAL · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

1. **Prep:** Gửi link design docs cho reviewers trước meeting (1 ngày trước).
2. **Meeting:** Đi qua checklist trong [../08-tradeoffs-adr.md §6](../../08-tradeoffs-adr.md).
3. **Record decisions:** Update section §5 Decisions Log trong 08-tradeoffs-adr.md với signoff names + date.

### Checklist (bám 08 §6)

- [ ] ADR-LS01 đến ADR-LS17 đã review + accept
- [ ] OQ-B, OQ-E, OQ-F locked (09/10 + ADR-LS03/LS15)
- [ ] `00-core.md §4b` impact assessed (only additions)
- [ ] wf-legacy-classify/extract compatibility verified
- [ ] **Sub-skill migration (Phase D) procedure agreed**
- [ ] **Standard profile = v4.1 backward-compat LOCK confirmed** ⚠️ CRITICAL
- [ ] Domain expert list (Core 7 + Optional 7) confirmed
- [ ] Bash shared library design agreed
- [ ] **IPS Python module `_shared/ips/` structure agreed**
- [ ] Concurrency (8/3/4/2 + timeout 300s/600s) agreed
- [ ] Workload Gate thresholds agreed (v5.0 WARN only)
- [ ] Cache TTL + privacy_scope defaults agreed
- [ ] **Thresholds justification (09-thresholds-justification.md) reviewed** — đặc biệt domain 0.4→0.6
- [ ] **VN keyword pool (10-vietnamese-keywords.md) reviewed**
- [ ] **CORE-029 spot-check (ADR-LS17) agreed**
- [ ] Timeline 23-32 ngày + resource confirmed
- [ ] Workload Partitioning defer v5.1 agreed
- [ ] Rollback strategy reviewed
- [ ] Risk register + mitigations approved
- [ ] Success criteria agreed

### Verify

```bash
# Signoff log updated
grep -A 5 "Sign-off" docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md | grep -i "$(date +%Y)"
```

### Acceptance Criteria

- [ ] All 20 checklist items ticked
- [ ] Decisions Log (08-tradeoffs-adr.md §5) có entry v2.1 với signoff names + date
- [ ] Git tag `design-legacy-scan-v2.1-approved` created

```bash
git tag -a design-legacy-scan-v2.1-approved -m "Design v2.1 approved by Owner + DEVKIT core team on $(date +%Y-%m-%d)"
git push origin design-legacy-scan-v2.1-approved
```

---

## Task A.5 — Draft `_contract.json` v5.0.0

**Priority:** HIGH · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

```bash
# 1. Read current contract
cat .claude/skills/workflow/wf-legacy-scan/_contract.json > /tmp/contract-v4.1.json

# 2. Draft v5.0.0 tại location mới (để không override v4.1 đang production)
cp .claude/skills/workflow/wf-legacy-scan/_contract.json \
   docs/design/skills/wf-legacy-scan/implementation/_contract-v5.0.0-draft.json

# 3. Edit draft với changes v2.1
```

### Changes Required

Edit `_contract-v5.0.0-draft.json`:

```diff
{
-  "version": "4.1.0",
+  "version": "5.0.0-draft",
   "phase": "legacy-scan",
   "registry_scope": { "role": "NONE", "fields_owned": [] },
   "inputs": {
     "required": ["<project-path>"],
-    "optional": []
+    "optional": ["legacy-decisions.json", ".mc-data/cache/wf-legacy-scan/"]
   },
+  "cli_flags": {
+    "backward_compat": ["--resume", "--status", "--re-vision", "--batch-size"],
+    "new_v5": ["--profile", "--layers", "--depth", "--session", "--incremental", "--since", "--no-cache", "--cache-publish"],
+    "deferred_v5_1": ["--workload", "--chunk", "--aggregate"]
+  },
+  "profiles": ["surface", "standard", "deep", "exhaustive"],
+  "default_profile": "standard",
   "outputs": {
     "working": [
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/scan-state.json", "template": "templates/scan-state.json" },
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/scan-plan.md", "template": "templates/scan-plan.md" },
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/phase-summary.md", "template": "templates/phase-summary.md" },
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/session-log.json", "template": null, "notes": "CORE-026, append-only" },
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/error-ledger.json", "template": "templates/error-ledger.json" },
+      { "path": ".mc-data/work/legacy-scan/sessions/{id}/events.jsonl", "template": null, "notes": "append-only JSONL" },
+      { "path": ".mc-data/work/legacy-scan/domain-hints.json", "template": "templates/domain-hints.json" },
+      { "path": ".mc-data/work/legacy-scan/impact-graph.json", "template": "templates/impact-graph.json" },
       { "path": ".mc-data/work/legacy-scan/project-profile.json", "template": "templates/project-profile.json" },
       { "path": ".mc-data/work/legacy-scan/assessment-report.json", "template": "templates/assessment-report.json" },
       { "path": ".mc-data/work/legacy-scan/ledger.json", "template": "templates/ledger.json",
+        "notes": "v2.1 — generated ONCE by orchestrator at POST Phase 4 synthesize (read-only legacy projection)" },
       ...
     ]
   }
}
```

### Verify

```bash
# Schema validity
jq empty docs/design/skills/wf-legacy-scan/implementation/_contract-v5.0.0-draft.json

# Version bumped
jq -r '.version' docs/design/skills/wf-legacy-scan/implementation/_contract-v5.0.0-draft.json
# → 5.0.0-draft

# New outputs present
jq '.outputs.working[] | select(.path | contains("scan-state"))' \
   docs/design/skills/wf-legacy-scan/implementation/_contract-v5.0.0-draft.json
```

### Acceptance Criteria

- [ ] Draft contract tồn tại tại `implementation/_contract-v5.0.0-draft.json`
- [ ] Version = `5.0.0-draft`
- [ ] 8 new output entries added (sessions/*, domain-hints, impact-graph)
- [ ] ledger.json note update (generated 1x POST-P4)
- [ ] 8 new CLI flags documented
- [ ] `jq empty` validates
- [ ] Phase B sẽ copy draft này vào production location sau Phase B foundation complete

---

## Task A.6 — Tạo 7 Template Skeletons

**Priority:** HIGH · **Duration:** 4-5 giờ · **Status:** ⬜

> **Note:** Phase A tạo skeleton (empty structure). Phase B/C sẽ populate với real schema.

### 7 Templates

| # | File | Schema | Location | Source section |
|---|------|--------|----------|----------------|
| 1 | `scan-state.json` | scan-state-v1 | `.claude/skills/workflow/wf-legacy-scan/templates/` | [04-data-model.md §1.1](../../04-data-model.md) |
| 2 | `domain-hints.json` | domain-hints-v1 | `.claude/skills/workflow/wf-legacy-scan/templates/` | [04-data-model.md §2.1](../../04-data-model.md) |
| 3 | `impact-graph.json` | impact-graph-v1 | `.claude/skills/workflow/wf-legacy-scan/templates/` | [04-data-model.md §2.2](../../04-data-model.md) |
| 4 | `phase-summary.md` | — (CORE-028) | `.claude/skills/workflow/wf-legacy-scan/templates/` | `.claude/skills/protocols/10-post-gate-schema.md` |
| 5 | `scan-plan.md` | — | `.claude/skills/workflow/wf-legacy-scan/templates/` | Bám `legacy-scan-plan.md` hiện có |
| 6 | `fix-workload.json` (stub for v5.1) | fix-workload-v1 | `.claude/skills/workflow/wf-legacy-scan/templates/` | [04-data-model.md §8](../../04-data-model.md) |
| 7 | `vietnamese-keywords.json` | vn-keywords-v1 | `.claude/skills/workflow/_shared/ips/` | [10-vietnamese-keywords.md §4.1](../../10-vietnamese-keywords.md) |

### Actions Per Template

Ví dụ cho `scan-state.json`:

```bash
# 1. Create file with full schema từ 04-data-model.md §1.1
cat > .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json <<'EOF'
{
  "$schema": "scan-state-v1",
  "session": {
    "id": "{{SESSION_ID}}",
    "created": "{{CREATED_AT}}",
    "project_path": "{{PROJECT_PATH}}",
    "profile": "standard",
    "strategy": "{{STRATEGY}}",
    "maturity_level": "{{MATURITY_LEVEL}}",
    "workload_id": null,
    "chunk_id": null
  },
  "depth_map": {
    "L1": "full", "L2": "full", "L3": "full",
    "L4": "standard", "L5": "standard", "L6": "full"
  },
  "synthesis_mode": "full",
  "config": {
    "batch_size": 100,
    "max_files_cap_api": 500,
    "max_files_cap_screens": 500,
    "concurrency": {
      "global_max": 8,
      "per_layer_max": 3,
      "per_probe_max": 4,
      "reserved_for_synthesis": 2,
      "per_agent_timeout_sec": 300,
      "per_agent_timeout_deep_sec": 600
    },
    "cache": {
      "session_cache_enabled": true,
      "project_cache_enabled": false,
      "ttl_days": 14
    },
    "incremental": false,
    "since_ref": null
  },
  "layers": {
    "L1": { "name": "discovery", "status": "not_started", "started": null, "completed": null, "outputs": [], "checkpoint": null },
    "L2": { "name": "assessment", "status": "not_started", "started": null, "completed": null, "outputs": [], "checkpoint": null },
    "L3": { "name": "inventory", "status": "not_started", "started": null, "completed": null, "outputs": [], "checkpoint": null },
    "L4": { "name": "classification", "status": "not_started", "depth": "standard", "batch_progress": null, "partial": null, "outputs": [] },
    "L5": { "name": "extraction", "status": "not_started", "depth": "standard", "module_progress": null, "partial": null, "outputs": [] },
    "L6": { "name": "synthesis", "status": "not_started", "synthesis_mode": "full", "outputs": [] }
  },
  "ips": { "phase_a": null, "phase_b": null },
  "workload": null,
  "last_completed": "init",
  "status": "in_progress",
  "error_log": [],
  "resume_hint": "",
  "legacy_ledger": {
    "generated_at": null,
    "schema_version": "legacy-v4.1",
    "note": "Generated 1x at POST Phase 4 synthesize (v2.1 — no reverse-sync)"
  }
}
EOF

# 2. Validate
jq empty .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json
```

Lặp lại cho 6 templates còn lại.

### Verify

```bash
# Tất cả 7 templates tồn tại + JSON valid
for t in scan-state domain-hints impact-graph fix-workload; do
  jq empty .claude/skills/workflow/wf-legacy-scan/templates/${t}.json || echo "FAIL: $t"
done

test -s .claude/skills/workflow/wf-legacy-scan/templates/phase-summary.md
test -s .claude/skills/workflow/wf-legacy-scan/templates/scan-plan.md
test -s .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
jq empty .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
```

### Acceptance Criteria

- [ ] 5 JSON templates valid (scan-state, domain-hints, impact-graph, fix-workload, vietnamese-keywords)
- [ ] 2 Markdown templates có structure (phase-summary, scan-plan)
- [ ] `vietnamese-keywords.json` có ít nhất 3 domains populated (finance, hr, sales) với 3+ keywords mỗi domain (sample — Phase C sẽ complete)
- [ ] All templates include `$schema` field

### Risks

- Template schema sai so với design → Phase B sẽ phát hiện và bump version. Mitigation: cross-check từng field với 04-data-model.md trước khi save.

---

## Task A.7 — IPS Python Module Skeleton

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Structure

```
.claude/skills/workflow/_shared/ips/
├── __init__.py                     (empty marker)
├── ips_recommender.py              (stub API)
├── domain_scorer.py                (stub)
├── vietnamese_keywords.py          (stub with normalize_vn working)
├── workload_estimator.py           (stub)
├── scan_state_reader.py            (stub — sẽ dùng cho Phase D sub-skill migration)
├── vietnamese-keywords.json        (đã tạo ở A.6)
├── requirements.txt                (pytest + jsonschema)
└── tests/
    ├── __init__.py
    ├── test_domain_scorer.py       (basic empty test)
    ├── test_vietnamese_keywords.py (test normalize_vn)
    ├── test_workload_estimator.py
    ├── test_scan_state_reader.py
    └── fixtures/
        ├── small_en/                (copy from fixtures/small-en/ subset)
        ├── medium_vn/
        └── mixed_en_vn/
```

### Actions

```bash
# 1. Create directory
mkdir -p .claude/skills/workflow/_shared/ips/tests/fixtures

# 2. Create __init__.py files
touch .claude/skills/workflow/_shared/ips/__init__.py
touch .claude/skills/workflow/_shared/ips/tests/__init__.py

# 3. Create requirements.txt
cat > .claude/skills/workflow/_shared/ips/requirements.txt <<EOF
pytest>=7.0
jsonschema>=4.0
EOF

# 4. Create stub ips_recommender.py
cat > .claude/skills/workflow/_shared/ips/ips_recommender.py <<'EOF'
"""IPS Recommender — 2-phase domain detection + profile recommendation.

Phase A: After L2 Assessment — recommend profile + initial domain hints.
Phase B: After L3 Inventory — refine module routing + complexity hotspots.

Pattern reference: wf-fix-bugs v6 ISG Recommender.
"""

from pathlib import Path
from typing import Any


def run_phase_a(project_profile_path: Path, assessment_path: Path, output_path: Path) -> dict[str, Any]:
    """IPS Phase A — run after L2 Assessment.

    Args:
        project_profile_path: Path to project-profile.json
        assessment_path: Path to assessment-report.json
        output_path: Path to write ips-phase-a.json

    Returns:
        IPS phase A result dict (also written to output_path).

    Raises:
        NotImplementedError: Phase C will implement.
    """
    raise NotImplementedError("Phase C will implement — see 05-profiles-ips.md §3.2")


def run_phase_b(inventory_dir: Path, ips_a_path: Path, output_path: Path) -> dict[str, Any]:
    """IPS Phase B — run after L3 Inventory.

    Args:
        inventory_dir: Path to inventory/ directory
        ips_a_path: Path to ips-phase-a.json output from phase A
        output_path: Path to write ips-phase-b.json

    Returns:
        IPS phase B result dict.

    Raises:
        NotImplementedError: Phase C will implement.
    """
    raise NotImplementedError("Phase C will implement — see 05-profiles-ips.md §3.3")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="phase")
    
    p_a = subparsers.add_parser("phase_a")
    p_a.add_argument("--project-profile", required=True, type=Path)
    p_a.add_argument("--assessment", required=True, type=Path)
    p_a.add_argument("--output", required=True, type=Path)
    
    p_b = subparsers.add_parser("phase_b")
    p_b.add_argument("--inventory", required=True, type=Path)
    p_b.add_argument("--ips-a", required=True, type=Path)
    p_b.add_argument("--output", required=True, type=Path)
    
    args = parser.parse_args()
    
    if args.phase == "phase_a":
        run_phase_a(args.project_profile, args.assessment, args.output)
    elif args.phase == "phase_b":
        run_phase_b(args.inventory, args.ips_a, args.output)
EOF

# 5. Create stub vietnamese_keywords.py với normalize_vn working (đây là logic đơn giản, làm luôn)
cat > .claude/skills/workflow/_shared/ips/vietnamese_keywords.py <<'EOF'
"""Vietnamese Keyword Pool — domain detection cho dự án Việt Nam.

Reference: 10-vietnamese-keywords.md
"""

import json
import re
import unicodedata
from pathlib import Path
from typing import Any

_POOL_PATH = Path(__file__).parent / "vietnamese-keywords.json"


def normalize_vn(text: str) -> str:
    """Normalize Vietnamese text: strip diacritics, lowercase, remove separators.
    
    Examples:
        >>> normalize_vn("Quản-Lý-Khách-Hàng")
        'quanlykhachhang'
        >>> normalize_vn("Hóa_Đơn")
        'hoadon'
    """
    text = text.lower()
    text = unicodedata.normalize('NFD', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    text = text.replace('đ', 'd')
    text = re.sub(r'[-_/.]', '', text)
    return text


def load_pool() -> dict[str, Any]:
    """Load VN keyword pool from JSON."""
    with _POOL_PATH.open() as f:
        return json.load(f)


def detect_domain_vn(module_name: str, pool: dict | None = None) -> list[dict[str, Any]]:
    """Detect domain hints for a module name using VN keyword pool.
    
    Raises:
        NotImplementedError: Phase C will implement full matching logic.
    """
    raise NotImplementedError("Phase C will implement — see 10-vietnamese-keywords.md §3")
EOF

# 6. Create stub other modules (similar pattern — raise NotImplementedError)
for mod in domain_scorer workload_estimator scan_state_reader; do
  cat > .claude/skills/workflow/_shared/ips/${mod}.py <<EOF
"""$(echo $mod | tr '_' ' ' | sed 's/\b./\U&/g') — Phase C/D will implement.

Reference: see design docs in docs/design/skills/wf-legacy-scan/
"""

# Stubs — full implementation in Phase C (ips, domain_scorer, workload_estimator)
# or Phase D (scan_state_reader).
EOF
done

# 7. Create basic test for normalize_vn (runnable now)
cat > .claude/skills/workflow/_shared/ips/tests/test_vietnamese_keywords.py <<'EOF'
"""Tests for vietnamese_keywords.py normalize_vn function."""

import pytest
from workflow._shared.ips.vietnamese_keywords import normalize_vn


class TestNormalizeVn:
    @pytest.mark.parametrize("input,expected", [
        ("Quản-Lý-Khách-Hàng", "quanlykhachhang"),
        ("Hóa_Đơn", "hoadon"),
        ("Nhập/Kho", "nhapkho"),
        ("qlkh", "qlkh"),  # already normalized
        ("CHAM-CONG", "chamcong"),
        ("Đào.tạo", "daotao"),
        ("Nhân Viên", "nhan vien"),  # space preserved (non-separator)
    ])
    def test_normalize(self, input, expected):
        assert normalize_vn(input) == expected
EOF

# 8. Run tests (should pass for normalize_vn, stubs raise NotImplementedError as expected)
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/test_vietnamese_keywords.py -v
```

### Verify

```bash
# Module importable
python -c "from workflow._shared.ips import vietnamese_keywords; print(vietnamese_keywords.normalize_vn('Quản-Lý'))"
# Expected: quanly

# Tests pass (for normalize_vn — stubs not yet tested)
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/test_vietnamese_keywords.py -v
# Expected: 7 tests pass
```

### Acceptance Criteria

- [ ] Folder `.claude/skills/workflow/_shared/ips/` tồn tại với 5 Python files
- [ ] `__init__.py` files tạo
- [ ] `requirements.txt` có pytest + jsonschema
- [ ] `normalize_vn()` function working (testable)
- [ ] 4 stub modules raise `NotImplementedError` với reference comment
- [ ] `test_vietnamese_keywords.py` có 7 test cases, all pass
- [ ] CLI interface `python -m workflow._shared.ips.ips_recommender phase_a --help` hiển thị help

---

## Post-Phase Verification

Sau khi 7 tasks complete:

```bash
# 1. Full phase verify
ls -la docs/design/skills/wf-legacy-scan/fixtures/
ls -la .claude/skills/workflow/wf-legacy-scan/templates/
ls -la .claude/skills/workflow/_shared/ips/
cat docs/design/skills/wf-legacy-scan/MIGRATION-PROGRESS.md

# 2. Git tag
git tag -a design-legacy-scan-v2.1-approved -m "Design v2.1 sign-off + Phase A closure"

# 3. Update implementation/README.md status
# Phase A status: ⬜ → ✅

# 4. Merge phase branch to main (first phase — OK to merge)
git checkout main
git merge feat/wf-legacy-scan-v5.0-phase-a
git push origin main
```

## Exit Criteria

- [ ] All 7 tasks ✅
- [ ] 3 fixtures có v4.1 baseline output
- [ ] 17 ADRs signed off (08-tradeoffs-adr.md §5 updated)
- [ ] `_contract-v5.0.0-draft.json` valid
- [ ] 7 template skeletons tạo
- [ ] IPS Python module skeleton importable + `normalize_vn` test pass
- [ ] Git tag `design-legacy-scan-v2.1-approved` pushed
- [ ] MIGRATION-PROGRESS.md updated: Phase A ✅
- [ ] implementation/README.md status table updated

## Next Phase

→ [phase-B-foundation.md](phase-B-foundation.md)
