# Phase 4: Architecture Design

> Goi `/wf-design` de thiet ke kien truc cho module moi.
> Thiet ke phai tuan thu pattern DDD + CQRS + Minimal API cua EUREKA.
> Dung `--from-scan` de lay baseline tu module cu, ket hop voi entity mapping tu Phase 1.
> **v1.1:** Pre-flight check + registry snapshot cho rollback.

> **Shared:** Xem `procedures/_shared.md` — Sub-Skill Invocation Pattern, Sub-Skill Pre-Flight Check, Rollback Protocol, Registry Safe-Write.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.features | map(select(.module_id == "$TARGET_MODULE")) | length > 0' .mc-data/docs/_meta/req-registry.json
test -f $SESSION_DIR/entity-mapping.md
test -f $SESSION_DIR/preflight-results.json
```

Neu fail → Phase 3 chua hoan thanh. Kiem tra lai.

---

## INPUT

| File | Mo ta |
|------|-------|
| `$SCAN_SESSION_DIR/target-map.json` | Baseline architecture cu |
| `$SCAN_SESSION_DIR/module-map.md` | Cau truc module cu |
| `$SESSION_DIR/entity-mapping.md` | Entity mapping cu → moi |
| `$SESSION_DIR/strategy-matrix.md` | Strategy per feature |
| `.mc-data/docs/_meta/req-registry.json` | Registry hien tai |
| `$PREFLIGHT_RESULTS["wf-design"]` | Pre-flight check result |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.0 | **Pre-flight check wf-design:** Doc `$PREFLIGHT_RESULTS["wf-design"]`. Neu status=fail → hoi user (E016). Neu status=pass → tiep tuc. | Read | Pre-flight verified |
| 4.0a | **Snapshot registry truoc design (NEW v1.1):** Copy toan bo registry → `$SESSION_DIR/snapshots/registry-phase4-pre-{timestamp}.json`. Ghi metadata vao `$ROLLBACK_SNAPSHOTS[]`. | Read/Write | Pre-design snapshot |
| 4.1 | **Build args:** `--from-scan=$SCAN_SESSION_ID --module=$TARGET_MODULE`. Pass them context: entity mapping (cu → moi), strategy decisions, target architecture constraints (DDD + CQRS). | — | Args built |
| 4.2 | **Invoke `/wf-design`:** Skill tool voi skill=`wf-design`, args=`--from-scan=$SCAN_SESSION_ID --module=$TARGET_MODULE`. | Skill | Sub-skill invoked |
| 4.3 | **Verify design docs:** Kiem tra design docs duoc tao trong `.mc-data/docs/phase3-architecture/`. | Glob | Design created |
| 4.4 | **Verify entity mapping alignment:** Cross-check entity mapping (Phase 1) co khop voi design entities khong. Neu co sai lech → WARNING + ghi vao error_log. | Read | Alignment verified |
| 4.5 | **Cap nhat status + checkpoint:** Cap nhat `migrate-status.json` (current_phase="design"). Luu checkpoint (next_phase="phase5" hoac "phase6" neu skip plan, rollback_snapshot_id). | Write | Status updated |

---

## POST-GATE

```bash
# Verify design_status duoc set
jq -e '.design_status' .mc-data/docs/_meta/req-registry.json
# Verify rollback snapshot ton tai (NEW v1.1)
test -f $SESSION_DIR/snapshots/registry-phase4-pre-*.json
```

---

## Next Phase

- Neu `"plan-modules" NOT IN $SKIP_PHASES` → `procedures/phase5-plan-modules.md`
- Neu `"plan-modules" IN $SKIP_PHASES` → `procedures/phase6-implement.md`
