# Phase 3: Define Features

> Goi `/wf-define-features --from-scan` de tao feature specs cho tung feature da seed.
> Feature specs duoc viet theo chuan EUREKA, co REQ-ID, FEAT-ID.
> **v1.1:** Pre-flight check + registry snapshot cho rollback.

> **Shared:** Xem `procedures/_shared.md` — Sub-Skill Invocation Pattern, Sub-Skill Pre-Flight Check, Rollback Protocol, Registry Safe-Write.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.features | map(select(.module_id == "$TARGET_MODULE")) | length > 0' .mc-data/docs/_meta/req-registry.json
test -f $SESSION_DIR/preflight-results.json
```

Neu fail → Phase 2 chua hoan thanh dung cach. Kiem tra lai.

---

## INPUT

| File | Mo ta |
|------|-------|
| `$SCAN_SESSION_DIR/feature-inventory.md` | Feature inventory tu scan |
| `$SCAN_SESSION_DIR/target-map.json` | Target map tu scan |
| `$SESSION_DIR/strategy-matrix.md` | Strategy matrix (Phase 1) |
| `$SESSION_DIR/gap-analysis.md` | Gap analysis (Phase 1) — ngu canh bo sung |
| `.mc-data/docs/_meta/req-registry.json` | Registry da duoc add-scope |
| `$PREFLIGHT_RESULTS["wf-define-features"]` | Pre-flight check result |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.0 | **Pre-flight check wf-define-features:** Doc `$PREFLIGHT_RESULTS["wf-define-features"]`. Neu status=fail → hoi user (E016). Neu status=pass → tiep tuc. | Read | Pre-flight verified |
| 3.0a | **Snapshot registry truoc define-features (NEW v1.1):** Copy toan bo registry → `$SESSION_DIR/snapshots/registry-phase3-pre-{timestamp}.json`. Ghi metadata vao `$ROLLBACK_SNAPSHOTS[]`. | Read/Write | Pre-define snapshot |
| 3.1 | **Build args:** `--from-scan=$SCAN_SESSION_ID --module=$TARGET_MODULE`. Pass them context tu gap-analysis (features can giu nguyen logic, features can thiet ke lai). | — | Args built |
| 3.2 | **Invoke `/wf-define-features`:** Skill tool voi skill=`wf-define-features`, args=`--from-scan=$SCAN_SESSION_ID --module=$TARGET_MODULE`. | Skill | Sub-skill invoked |
| 3.3 | **Verify feature specs:** Kiem tra feature spec files duoc tao trong `.mc-data/docs/phase2-features/`. Moi feature co strategy != Deprecate phai co spec file. | Glob | Specs created |
| 3.4 | **Doc lai registry:** Verify `features[].impl_status` duoc set dung. | Read | Registry updated |
| 3.5 | **Cap nhat status + checkpoint:** Cap nhat `migrate-status.json` (current_phase="define-features"). Luu checkpoint (next_phase="phase4" hoac "phase5" neu skip design, rollback_snapshot_id). | Write | Status updated |

---

## POST-GATE

```bash
# Verify feature specs duoc tao
jq -e '.features | map(select(.module_id == "$TARGET_MODULE")) | length > 0' .mc-data/docs/_meta/req-registry.json
# Verify rollback snapshot ton tai (NEW v1.1)
test -f $SESSION_DIR/snapshots/registry-phase3-pre-*.json
```

---

## Next Phase

- Neu `"design" NOT IN $SKIP_PHASES` → `procedures/phase4-design.md`
- Neu `"design" IN $SKIP_PHASES` → `procedures/phase5-plan-modules.md`
