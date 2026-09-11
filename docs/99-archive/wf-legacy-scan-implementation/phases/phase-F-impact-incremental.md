# Phase F — Impact Graph + Incremental (Workload Partition DEFERRED v5.1)

> **Mục tiêu:** Build impact-graph.json tại L6 + implement incremental mode base + Workload Gate detect+WARN only.
> **Duration:** 2 ngày (v2.1 reduced — workload partitioning defer v5.1)
> **Dependencies:** Phase E (checkpoint + concurrency)
> **Tag:** `v5.0-phase-F`
> **Parallelizable:** With E, G

---

## Prerequisites

- [ ] Phase E tagged `v5.0-phase-E`
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-f`

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| F.1 | Impact graph builder (6 relation types) | HIGH | 3-4 giờ | ✅ |
| F.2 | Impact graph tại L6 synthesis integration | HIGH | 2-3 giờ | ✅ |
| F.3 | Incremental mode — staleness check + delta processing | HIGH | 3-4 giờ | ✅ |
| F.4 | `--incremental` + `--since` flags | MEDIUM | 2 giờ | ✅ |
| F.5 | Workload Gate detect + WARN (v5.0 — no partition) | MEDIUM | 2-3 giờ | ✅ |

---

## Task F.1 — Impact Graph Builder

**Duration:** 3-4 giờ

Implement `_shared/ips/impact_graph_builder.py`:

6 relation types theo [04 §2.2](../../04-data-model.md):
- `code_import` — AST import/export
- `data_dependency` — FK / schema reference  
- `event_subscription` — event bus / decorator
- `api_call` — REST/gRPC call (runtime trace if available)
- `req_cross_ref` — `USES: REQ-X` comment annotation
- `entity_reference` — entity name reference

Algorithm:
1. Read inventory/dependency-graph.json (imports)
2. Parse code files for schema refs (if DB schema detected)
3. Detect circular dependencies
4. Identify orphan modules
5. Compute fanout metrics

### Acceptance Criteria

- [ ] impact-graph.json schema valid
- [ ] ≥ 3 relation types detected trên fixtures
- [ ] Circular deps detected if exist
- [ ] Orphan modules listed
- [ ] Schema ref: `impact-graph-v1`

---

## Task F.2 — L6 Synthesis Integration

**Duration:** 2-3 giờ

Update `procedures/phase4-synthesize.md`:

- synthesis_mode=condensed → skip impact-graph (surface profile)
- synthesis_mode=full → basic impact-graph (dependency re-format)
- synthesis_mode=full+insights → enriched với data flow
- synthesis_mode=full+divergence → + divergence refs

### Acceptance Criteria

- [ ] impact-graph.json generated per synthesis_mode
- [ ] Downstream `/wf-verify-sync` can consume
- [ ] Schema valid

---

## Task F.3 — Incremental Mode

**Duration:** 3-4 giờ

Implement delta processing theo [02 §7](../../02-scan-layers.md):

```python
def detect_changes(project_path, since_ref=None) -> ChangeSet:
    """Detect changes since last scan.
    
    Methods:
    - If git repo + since_ref → git diff
    - Else → mtime compare với previous scan
    - Also: content hash compare cho rename detection
    """

def apply_delta(changes: ChangeSet, previous_state: dict) -> dict:
    """Apply delta to L3/L4/L5 outputs.
    
    Rules (from 09 §2.3):
    - UNCHANGED → keep cache
    - MODIFIED → re-process at L3, mark L4/L5 delta
    - NEW → add to L3, mark L4/L5
    - DELETED → remove, mark affected L4/L5
    - RENAMED → DELETE+ADD, full re-classify affected module
    
    Threshold: >25% files affected → auto-upgrade to full re-run
    """
```

### Acceptance Criteria

- [ ] Staleness check works (git + mtime)
- [ ] Delta processing respects thresholds
- [ ] Rename detection via Levenshtein + function signature
- [ ] Re-scan với 20% changes → ≤ 30% full scan time

---

## Task F.4 — CLI Flags

**Duration:** 2 giờ

### Actions

Add `--incremental`, `--since=<git-ref>` flag parsing trong SKILL.md.

### Acceptance Criteria

- [ ] `--incremental` standalone works (mtime compare)
- [ ] `--incremental --since=HEAD~5` works (git diff)
- [ ] No git repo + `--since` → clear error message

---

## Task F.5 — Workload Gate (Detect + WARN only)

**Duration:** 2-3 giờ

> **v2.1 scope:** Detect + WARN 3 options (continue-as-is / downgrade-profile / abort). **NOT** full Partition Planner — defer v5.1.

### Actions

Thêm Workload Gate logic vào procedure Phase 0.5 (sau IPS-B):

```python
def check_workload_gate(ips_b: dict, depth_map: dict) -> None:
    """Check workload thresholds, trigger CDG if exceeded.
    
    Thresholds (from 09 §2.5):
    - estimated_time > 1.5 × profile.budget
    - total_features_est > 100
    - largest_module_files > 40 (v2.1 lowered from 50)
    - modules_count > 30
    - total_files > 1,000 AND profile ∈ {deep, exhaustive}
    """
    triggers = []
    workload = ips_b.get("workload_estimate", {})
    
    if workload.get("exceeds_cap"):
        triggers.append(f"Time estimate exceeds {workload['ratio']}× budget")
    # ... other triggers ...
    
    if triggers:
        options = [
            "continue-as-is — log WARN, continue execution",
            "downgrade-profile — apply smaller profile, continue",
            "abort — STOP, reduce scope and retry"
        ]
        selected = ask_user_question(
            question=f"Workload lớn phát hiện:\n{chr(10).join('- '+t for t in triggers)}",
            options=options,
            default="downgrade-profile"
        )
        handle_user_choice(selected)
```

### Acceptance Criteria

- [ ] Gate triggers đúng theo 09 §2.5 thresholds
- [ ] UI hiển thị WARN message clear
- [ ] 3 options available
- [ ] `downgrade-profile` logic works (deep→standard, exhaustive→deep)
- [ ] `abort` exits clean
- [ ] KHÔNG generate fix-workload.json (defer v5.1)

---

## Exit Criteria

- [ ] All 5 tasks ✅
- [ ] impact-graph.json consumable by wf-verify-sync
- [ ] Incremental 20% changes → ≤ 30% time
- [ ] Workload Gate triggers + user can choose option
- [ ] `v5.0-phase-F` tag pushed

## Next Phase

→ [phase-G-bash-refactor.md](phase-G-bash-refactor.md)
