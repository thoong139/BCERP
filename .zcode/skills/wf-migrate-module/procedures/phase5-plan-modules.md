# Phase 5: Implementation Planning

> Goi `/wf-plan-modules` de tao task plan cho module moi.
> Phan ra features thanh cac task cu the, sap xep theo thu tu uu tien.
> **v1.1:** Pre-flight check + registry snapshot cho rollback.

> **Shared:** Xem `procedures/_shared.md` — Sub-Skill Invocation Pattern, Sub-Skill Pre-Flight Check, Rollback Protocol, Registry Safe-Write.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.design_status' .mc-data/docs/_meta/req-registry.json
test -f $SESSION_DIR/preflight-results.json
```

Neu fail → Phase 4 chua hoan thanh. Kiem tra lai.

---

## INPUT

| File | Mo ta |
|------|-------|
| `.mc-data/docs/_meta/req-registry.json` | Registry da co design |
| `$SESSION_DIR/strategy-matrix.md` | Strategy per feature — uu tien features Keep truoc |
| `$SESSION_DIR/entity-mapping.md` | Entity mapping — task data migration |
| `$PREFLIGHT_RESULTS["wf-plan-modules"]` | Pre-flight check result |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.0 | **Pre-flight check wf-plan-modules:** Doc `$PREFLIGHT_RESULTS["wf-plan-modules"]`. Neu status=fail → hoi user (E016). Neu status=pass → tiep tuc. | Read | Pre-flight verified |
| 5.0a | **Snapshot registry truoc plan-modules (NEW v1.1):** Copy toan bo registry → `$SESSION_DIR/snapshots/registry-phase5-pre-{timestamp}.json`. Ghi metadata vao `$ROLLBACK_SNAPSHOTS[]`. | Read/Write | Pre-plan snapshot |
| 5.1 | **Build args:** `--module=$TARGET_MODULE`. KHONG can `--from-scan` (wf-plan-modules doc registry). | — | Args built |
| 5.2 | **Invoke `/wf-plan-modules`:** Skill tool voi skill=`wf-plan-modules`, args=`--module=$TARGET_MODULE`. | Skill | Sub-skill invoked |
| 5.3 | **Verify task plan:** Kiem tra task files duoc tao. Moi feature co strategy != Deprecate phai co it nhat 1 task. | Glob/Grep | Tasks created |
| 5.4 | **Verify implementation_order:** Kiem tra registry `implementation_order` da duoc set. | Read | Order set |
| 5.5 | **Cap nhat status + checkpoint:** Cap nhat `migrate-status.json` (current_phase="plan-modules"). Luu checkpoint (next_phase="phase6" hoac "phase7" neu skip implement, rollback_snapshot_id). | Write | Status updated |

---

## POST-GATE

```bash
# Verify implementation_order duoc set
jq -e '.implementation_order | length > 0' .mc-data/docs/_meta/req-registry.json
# Verify rollback snapshot ton tai (NEW v1.1)
test -f $SESSION_DIR/snapshots/registry-phase5-pre-*.json
```

---

## Next Phase

- Neu `"implement" NOT IN $SKIP_PHASES` → `procedures/phase6-implement.md`
- Neu `"implement" IN $SKIP_PHASES` → `procedures/phase7-report.md`
