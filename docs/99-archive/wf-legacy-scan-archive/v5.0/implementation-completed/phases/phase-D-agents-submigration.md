# Phase D — Agent Upgrade + Sub-Skill Migration (CRITICAL)

> **Mục tiêu:** Upgrade agent delegation (direct spawn, không qua general-purpose wrapper) + migrate wf-legacy-classify/wf-legacy-extract đọc scan-state.json trực tiếp.
> **Duration:** 4-5 ngày
> **Dependencies:** Phase C complete (IPS + profile resolver operational)
> **Tag khi xong:** `v5.0-phase-D`
> **Risk level:** 🔴 **CRITICAL — backward-compat lock critical path.**
> **Rollback:** Revert sub-skill procedure changes → sub-skills quay về đọc ledger.json; revert agent type → general-purpose wrapper.

---

## ⚠️ CRITICAL WARNING

**Phase này là RISKY NHẤT** của toàn bộ migration vì:
1. Backward-compat lock (ADR-LS06) phải verify: standard profile = v4.1 behaviour.
2. Sub-skill migration (v2.1 NEW) chưa từng test trong DEVKIT.
3. Nếu break ở đây → downstream skills (wf-brainstorm legacy, wf-design legacy, ...) đều fail.

**Quy tắc:** Golden test MUST pass TRƯỚC khi tag `v5.0-phase-D`. Nếu không pass → revert, fix root cause, retry.

---

## Prerequisites

- [ ] Phase C tagged `v5.0-phase-C`
- [ ] IPS Phase A + Phase B operational
- [ ] 3 fixtures có v4.1 baseline output
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-d` created
- [ ] Owner available trong 4-5 ngày cho backward-compat review

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| D.1 | Sub-skill migration — `scan_state_reader.py` full API | CRITICAL | 4-5 giờ | ⬜ |
| D.2 | Migrate wf-legacy-classify đọc scan-state.json | CRITICAL | 4-5 giờ | ⬜ |
| D.3 | Migrate wf-legacy-extract đọc scan-state.json | CRITICAL | 4-5 giờ | ⬜ |
| D.4 | L4 Classification agent upgrade (direct spawn code-reviewer) | HIGH | 3-4 giờ | ⬜ |
| D.5 | L5 Extraction agent upgrade (direct spawn business-analyst + domain-expert) | CRITICAL | 4-5 giờ | ⬜ |
| D.6 | L4 surface depth heuristic grouping | MEDIUM | 2-3 giờ | ⬜ |
| D.7 | L4/L5 deep depth enriched prompts | MEDIUM | 3-4 giờ | ⬜ |
| D.8 | Standalone sub-skill fallback (helper auto-init session) | HIGH | 2-3 giờ | ⬜ |
| D.9 | **GOLDEN TEST — backward-compat verify trên 3 fixtures** | **CRITICAL** | **1 ngày** | ⬜ |

---

## Task D.1 — `scan_state_reader.py` Full API

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Expand `.claude/skills/workflow/_shared/ips/scan_state_reader.py` với đầy đủ API cho sub-skills:

```python
# Existing (from Phase B):
# - read_scan_state
# - update_layer_status
# - update_batch_progress
# - update_module_progress
# - append_error

# Add for Phase D:
def read_layer_outputs(layer: str, session_id: str | None = None) -> list[str]:
    """Read list of output files for layer."""

def append_layer_output(layer: str, output_path: str, session_id: str | None = None) -> None:
    """Append output file path to layer.outputs[]."""

def read_depth_map(session_id: str | None = None) -> dict[str, str]:
    """Return depth_map dict (L1-L6 → depth level)."""

def read_ips_phase_a(session_id: str | None = None) -> dict:
    """Return ips.phase_a content (domain hints, recommended profile, etc)."""

def read_ips_phase_b(session_id: str | None = None) -> dict:
    """Return ips.phase_b content (module routing, hotspots, etc)."""

def get_domain_expert_for_module(module: str, session_id: str | None = None) -> str | None:
    """Return recommended domain expert cho module (from ips.phase_b.module_routing).
    
    Returns None nếu confidence < 0.6 (use business-analyst only).
    """

def init_or_load_session(project_path: Path) -> str:
    """For standalone sub-skill run — init session nếu chưa có, hoặc load latest.
    
    Fallback strategy:
    1. Nếu có active session → use it
    2. Nếu có ledger.json v4.1 legacy → migrate to scan-state, init new session
    3. Else → raise error (user phải chạy /wf-legacy-scan trước)
    
    Returns session_id.
    """
```

### Tests

```python
class TestFullAPI:
    def test_init_or_load_active_session(self, active_session):
        sid = init_or_load_session(project_path)
        assert sid == active_session["id"]
    
    def test_init_or_load_from_legacy_ledger(self, legacy_ledger_fixture):
        """Simulate standalone /wf-legacy-classify run after v4.1 scan completed."""
        sid = init_or_load_session(project_path)
        state = read_scan_state(sid)
        assert state["session"]["id"] == sid
        assert state["layers"]["L3"]["status"] == "completed"  # migrated from ledger
    
    def test_init_or_load_no_prior_scan_fails(self, empty_project):
        with pytest.raises(RuntimeError, match="No prior scan"):
            init_or_load_session(project_path)
    
    def test_get_domain_expert_below_threshold(self, session_with_ips_b):
        # Module with confidence 0.5 → None (below 0.6)
        expert = get_domain_expert_for_module("operations_low_conf")
        assert expert is None
    
    def test_get_domain_expert_above_threshold(self, session_with_ips_b):
        # Module with confidence 0.85 → return expert
        expert = get_domain_expert_for_module("billing_strong")
        assert expert == "finance-expert"
```

### Acceptance Criteria

- [ ] 7 new API functions implemented
- [ ] `get_domain_expert_for_module()` respects threshold 0.6 (v2.1)
- [ ] `init_or_load_session()` fallback từ ledger.json works
- [ ] ≥ 10 tests pass
- [ ] API documented in docstrings

---

## Task D.2 — Migrate wf-legacy-classify

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Update `.claude/skills/workflow/wf-legacy-classify/`:

1. **SKILL.md:**
   - Update prerequisites: đọc scan-state.json thay ledger.json.
   - Update outputs: write to scan-state.layers.L4 qua helper.
   - Add note: standalone run fallback to init_or_load_session.

2. **Procedures:**
   - `procedures/_shared.md` — add imports + helper function references.
   - `procedures/phase0-detection.md` — PRE-GATE đọc scan-state.
   - `procedures/phase*.md` — update progress via helper (update_batch_progress).

3. **`_contract.json`:**
   - Add inputs: scan-state.json (required).
   - Remove ledger.json write outputs (chỉ read for fallback).

4. **Helper integration:**
   ```python
   # Example trong procedure file (pseudo-code — actual syntax trong markdown)
   from workflow._shared.ips.scan_state_reader import (
       init_or_load_session,
       read_layer_outputs,
       update_batch_progress,
       update_layer_status,
       append_error
   )
   
   session_id = init_or_load_session(project_path)
   update_layer_status("L4", "in_progress")
   
   # ... classification logic ...
   
   update_batch_progress("L4", {"current": 3, "total": 8, ...})
   update_layer_status("L4", "completed")
   ```

### Verify

```bash
# 1. Standalone run sau khi v4.1 scan đã complete
# Simulate: use v4.1 baseline từ fixtures
rm -rf docs/design/skills/wf-legacy-scan/fixtures/small-en/.mc-data/
cp -r docs/design/skills/wf-legacy-scan/fixtures/small-en.baseline-v4.1/ \
      docs/design/skills/wf-legacy-scan/fixtures/small-en/.mc-data/work/legacy-scan

cd docs/design/skills/wf-legacy-scan/fixtures/small-en
/wf-legacy-classify --resume

# Verify helper auto-init session
ls .mc-data/work/legacy-scan/sessions/
jq '.layers.L4.status' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expected: "completed"

# 2. Full pipeline run
rm -rf .mc-data/
/wf-legacy-scan . --profile=standard
# Sub-skill delegate trong orchestrator should also work
```

### Acceptance Criteria

- [ ] wf-legacy-classify SKILL.md updated
- [ ] Procedure files use helper API
- [ ] Standalone run works (fallback init)
- [ ] Orchestrator delegate works (use existing session)
- [ ] scan-state.json updated correctly (layer + batch_progress)
- [ ] Sub-skill KHÔNG write ledger.json
- [ ] _contract.json updated

---

## Task D.3 — Migrate wf-legacy-extract

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

Tương tự D.2 nhưng cho wf-legacy-extract:

- Update SKILL.md + procedures + _contract.json
- Use `update_module_progress()` thay batch_progress
- Update L5 outputs (extracted/{module}.json paths)

### Verify

```bash
# Standalone run
/wf-legacy-extract --resume

# Check scan-state updated
jq '.layers.L5.module_progress' .mc-data/work/legacy-scan/sessions/*/scan-state.json
```

### Acceptance Criteria

Same pattern như D.2.

---

## Task D.4 — L4 Classification Agent Upgrade

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Update `procedures/phase2-classify.md` (orchestrator side):

**Change:** Replace `subagent_type="general-purpose"` → `subagent_type="code-reviewer"` direct.

Thêm context trong agent prompt:
- Depth level (surface/standard/deep) từ scan-state.depth_map.L4
- IPS domain hints từ ips.phase_a
- Naming convention rules (CORE-016/017)

```python
# Agent spawn pseudo-code
depth = read_depth_map()["L4"]
if depth == "surface":
    # Heuristic inline — see D.6
    run_heuristic_grouping()
    return

# standard/deep
Agent(
    subagent_type="code-reviewer",  # NOT general-purpose
    prompt=build_prompt(
        batch=batch,
        depth=depth,
        ips_hints=read_ips_phase_a(),
        templates_ref="templates/classified/"
    ),
    description=f"Classify batch {N} (depth={depth})"
)
```

### Acceptance Criteria

- [ ] Agent spawn uses `subagent_type="code-reviewer"` direct
- [ ] Prompt includes depth + domain hints
- [ ] POST-GATE coverage ≥95% validated
- [ ] Deep depth additionally spawns domain-expert for glossary enrichment

---

## Task D.5 — L5 Extraction Agent Upgrade

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Update `procedures/phase3-extract.md`:

**Agent routing (CANONICAL — ADR-LS06 + 09 §2.1):**

```python
depth = read_depth_map()["L5"]
if depth == "skip":
    update_layer_status("L5", "skipped_by_profile")
    return

# For each module (topological order, max 3 parallel)
for module in modules:
    domain_expert = get_domain_expert_for_module(module)  # threshold 0.6
    
    # Always spawn business-analyst
    agents_to_spawn = [("business-analyst", build_ba_prompt(module, depth))]
    
    # Conditionally spawn domain-expert (standard + deep)
    if domain_expert:
        agents_to_spawn.append((domain_expert, build_de_prompt(module, depth)))
    
    # Deep: enriched prompt + cross-validation pass
    if depth == "deep":
        # BA extracts first, then DE reviews
        result_ba = spawn_sequential(agents_to_spawn[0])
        if domain_expert:
            result_de = spawn_with_context(agents_to_spawn[1], context=result_ba)
    else:
        # Standard: parallel spawn
        results = spawn_parallel(agents_to_spawn)
    
    # POST-GATE validate
    validate_post_gate(module, depth)
    update_module_progress("L5", module, "completed")
```

### CORE-029 Spot-Check Integration

Thêm tại POST-GATE:

```python
def post_gate_l5_spotcheck(module_output_path: Path) -> bool:
    """Spot-check 3 random requirements per module (CORE-029, ADR-LS17)."""
    import random
    data = json.loads(module_output_path.read_text())
    reqs = data.get("requirements", [])
    
    sample_size = 3 if len(reqs) >= 20 else 1
    samples = random.sample(reqs, min(sample_size, len(reqs)))
    
    for req in samples:
        # Check TMP-ID format
        if not re.match(r"^TMP-REQ-[A-Z]+-\d+$", req["id"]):
            return False
        # Check source_files non-empty + exist
        if not req.get("source_files"):
            return False
        for sf in req["source_files"]:
            if not Path(sf).exists():
                return False
        # Check confidence in [0, 1]
        if not (0 <= req.get("confidence", -1) <= 1):
            return False
        # Check description ≥ 20 chars
        if len(req.get("description", "")) < 20:
            return False
    
    return True
```

### Acceptance Criteria

- [ ] Agent spawn: business-analyst + (domain-expert if ≥0.6)
- [ ] Skip L5 cho surface profile
- [ ] Deep depth: cross-validation pass sequential
- [ ] POST-GATE confidence ≥0.6 standard, ≥0.8 deep
- [ ] CORE-029 spot-check implemented + integrated
- [ ] Agent timeout 300s standard / 600s deep respected

---

## Task D.6 — L4 Surface Depth Heuristic

**Priority:** MEDIUM · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

Implement surface profile heuristic grouping (no AI) theo [02 §4.4.1](../../02-scan-layers.md):

```python
def run_heuristic_grouping():
    """Surface depth — skip non-module dirs, group by first meaningful dir."""
    non_module_dirs = {"src", "lib", "app", "tests", "config", "public", "static",
                       "dist", "build", "scripts", "node_modules", "vendor", ".git",
                       "target"}
    
    files = read_inventory("source-files.json")
    groups = defaultdict(list)
    
    for f in files:
        parts = Path(f["path"]).parts
        # Skip until first meaningful dir
        for p in parts[:-1]:
            if p.lower() not in non_module_dirs:
                groups[p.lower()].append(f["path"])
                break
        else:
            groups["uncategorized"].append(f["path"])
    
    # Naming normalization (CORE-016/017)
    output = {
        module_name: {"files": files, "confidence": 1.0, "source": "heuristic"}
        for module_name, files in groups.items()
    }
    
    write_atomic("classified/auto-grouped.json", output)
```

### Acceptance Criteria

- [ ] Heuristic grouping no-AI
- [ ] Skip non-module dirs correctly
- [ ] Naming normalization applied
- [ ] Output `auto-grouped.json` (không batches)
- [ ] Runs trong ≤10s cho 500-file fixture

---

## Task D.7 — Deep Depth Enriched Prompts

**Priority:** MEDIUM · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Update L4/L5 deep depth prompts để include:
- IPS-detected complexity hotspots
- Domain-specific terminology hints
- Cross-validation request (for L5 deep)
- Higher confidence threshold (≥0.8)
- Divergence detection trigger (exhaustive profile only)

### Acceptance Criteria

- [ ] Deep prompt includes hotspots + domain hints
- [ ] Confidence target ≥0.8
- [ ] Cross-validation pass works sequential
- [ ] Exhaustive profile triggers divergence detection

---

## Task D.8 — Standalone Sub-Skill Fallback

**Priority:** HIGH · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

Ensure sub-skills có graceful fallback khi user chạy standalone không qua orchestrator:

1. Test case: user chạy `/wf-legacy-classify` after v4.1 scan đã complete (chỉ có ledger.json, không có scan-state.json).
2. Test case: user chạy `/wf-legacy-extract --resume` sau crash.
3. Test case: fresh run sub-skill (error: phải chạy /wf-legacy-scan trước).

### Acceptance Criteria

- [ ] Case 1: helper auto-migrate ledger → scan-state, continue
- [ ] Case 2: resume from checkpoint correct
- [ ] Case 3: clear error message + suggestion

---

## Task D.9 — GOLDEN TEST (CRITICAL)

**Priority:** CRITICAL · **Duration:** 1 ngày · **Status:** ⬜

> **Đây là GATE BLOCKING.** Nếu fail → revert Phase D, investigate root cause, retry.

### Actions

Run v5.0 standard profile trên 3 fixtures và compare với v4.1 baseline.

```bash
#!/bin/bash
# golden-test-phase-d.sh

set -e

FIXTURES=("small-en" "medium-vn" "large-mixed")
BASELINE_DIR="docs/design/skills/wf-legacy-scan/fixtures"
RESULTS=()

for fx in "${FIXTURES[@]}"; do
  echo "=== Fixture: $fx ==="
  
  # Clean run v5.0 standard
  cd "$BASELINE_DIR/$fx"
  rm -rf .mc-data/
  /wf-legacy-scan . --profile=standard
  
  V5_OUTPUT=".mc-data/work/legacy-scan"
  V4_BASELINE="../${fx}.baseline-v4.1"
  
  # Compare 1: Module count (±1 module tolerance)
  V5_MODULES=$(ls $V5_OUTPUT/classified/batch-*.json 2>/dev/null | wc -l)
  V4_MODULES=$(ls $V4_BASELINE/classified/batch-*.json 2>/dev/null | wc -l)
  
  # Compare 2: Feature count (±5% tolerance)
  V5_FEATS=$(jq -s '[.[].features // [] | length] | add' $V5_OUTPUT/extracted/*.json 2>/dev/null || echo 0)
  V4_FEATS=$(jq -s '[.[].features // [] | length] | add' $V4_BASELINE/extracted/*.json 2>/dev/null || echo 0)
  DIFF_PCT=$(awk -v a="$V5_FEATS" -v b="$V4_FEATS" 'BEGIN {if (b==0) print 0; else print (a-b)*100/b}')
  
  # Compare 3: Avg confidence (should not degrade significantly)
  V5_CONF=$(jq -s '[.[].requirements // [] | .[].confidence // 0] | add/length' $V5_OUTPUT/extracted/*.json 2>/dev/null)
  V4_CONF=$(jq -s '[.[].requirements // [] | .[].confidence // 0] | add/length' $V4_BASELINE/extracted/*.json 2>/dev/null)
  
  # Compare 4: project-context.md structure (same sections)
  V5_SECTIONS=$(grep -c "^## " $V5_OUTPUT/project-context.md)
  V4_SECTIONS=$(grep -c "^## " $V4_BASELINE/project-context.md)
  
  # Compare 5: REQ-ID format consistency
  V5_IDS_BAD=$(jq -r '[.. | objects | .id? // empty] | .[]' $V5_OUTPUT/extracted/*.json 2>/dev/null | \
               grep -vP '^(TMP-)?(REQ|FEAT)-[A-Z]+-\d+$' | wc -l)
  
  # Verdict
  echo "  Modules: v5=$V5_MODULES, v4=$V4_MODULES"
  echo "  Features: v5=$V5_FEATS, v4=$V4_FEATS, diff=${DIFF_PCT}%"
  echo "  Avg confidence: v5=$V5_CONF, v4=$V4_CONF"
  echo "  Sections: v5=$V5_SECTIONS, v4=$V4_SECTIONS"
  echo "  Invalid IDs: $V5_IDS_BAD"
  
  # Check criteria
  if (( ${DIFF_PCT%.*} > 5 )) || (( ${DIFF_PCT%.*} < -5 )); then
    echo "  ❌ FAIL: Feature count drift >5%"
    RESULTS+=("$fx: FAIL")
  elif [ "$V5_IDS_BAD" -gt 0 ]; then
    echo "  ❌ FAIL: $V5_IDS_BAD invalid IDs"
    RESULTS+=("$fx: FAIL")
  else
    echo "  ✅ PASS"
    RESULTS+=("$fx: PASS")
  fi
  
  cd -
done

echo ""
echo "=== GOLDEN TEST SUMMARY ==="
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
```

### Acceptance Criteria

- [ ] Script runs without error
- [ ] 3 fixtures đạt PASS verdict
- [ ] Feature count drift ≤ ±5% per fixture
- [ ] No invalid REQ-ID format
- [ ] Avg confidence ≥ v4.1 baseline (không degrade)
- [ ] project-context.md section count match

### If FAIL

1. STOP. **Không tag v5.0-phase-D.**
2. Create issue trong session log với specific diff.
3. Identify root cause:
   - Backward-compat break? → Fix code.
   - Fixture variance? → Re-run 3x lấy median.
   - Legitimate improvement (VN detection → more domains)? → Document exception.
4. Fix + retry golden test.
5. Escalate to Owner nếu không fix được trong 1 ngày.

---

## Post-Phase Verification

```bash
# 1. Python tests
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/ -v

# 2. Compliance
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-scan
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-classify
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-extract

# 3. Golden test (PHẢI PASS)
bash scripts/golden-test-phase-d.sh

# 4. Tag
git tag -a v5.0-phase-D -m "Phase D Agents + Sub-migration + backward-compat verified"
```

## Exit Criteria

- [ ] All 9 tasks ✅
- [ ] GOLDEN TEST PASS trên 3 fixtures ⚠️ BLOCKING
- [ ] Sub-skills migrated (no ledger.json write)
- [ ] Agent spawn direct (no general-purpose wrapper)
- [ ] CORE-029 spot-check integrated
- [ ] Agent timeout works
- [ ] Compliance + schema sync PASS
- [ ] `v5.0-phase-D` tag pushed
- [ ] MIGRATION-PROGRESS.md updated

## Next Phase

→ [phase-E-checkpoint-concurrency-cache.md](phase-E-checkpoint-concurrency-cache.md)
