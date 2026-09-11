# Phase 2: Seed Registry — Add Scope

> Goi `/wf-add-scope --from-scan` de seed module + features vao req-registry.json.
> Sub-skill nay chi APPEND, khong sua du lieu co san.
> **v1.1:** Pre-flight check sub-skill truoc khi goi + registry snapshot cho rollback.

> **Shared:** Xem `procedures/_shared.md` — Sub-Skill Invocation Pattern, Sub-Skill Pre-Flight Check, Rollback Protocol, Registry Safe-Write.

---

## PRE-GATE

```bash
test -f $SESSION_DIR/strategy-matrix.md
test -f $SESSION_DIR/preflight-results.json
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.modules | length > 0' .mc-data/docs/_meta/req-registry.json
```

Neu `$MODULE_EXISTS == false` → module chua co → can tao moi.
Neu `$MODULE_EXISTS == true` → module da co → add-scope se append features vao module.

---

## INPUT

| File | Mo ta |
|------|-------|
| `$SESSION_DIR/strategy-matrix.md` | Chi lay features co strategy != Deprecate |
| `$SCAN_SESSION_DIR/target-map.json` | Pass vao `--from-scan` |
| `.mc-data/docs/_meta/req-registry.json` | Registry hien tai |
| `$PREFLIGHT_RESULTS["wf-add-scope"]` | Pre-flight check result |

---

## OUTPUT

| File | Mo ta |
|------|-------|
| `.mc-data/docs/_meta/req-registry.json` | UPDATED — module + features moi duoc APPEND |
| `$SESSION_DIR/snapshots/registry-phase2-{ts}.json` | **NEW v1.1** — Snapshot cho rollback |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.0 | **Pre-flight check wf-add-scope:** Doc `$PREFLIGHT_RESULTS["wf-add-scope"]`. Neu status=fail → hoi user (E016). Neu status=pass → tiep tuc. | Read | Pre-flight verified |
| 2.1 | **Loc features:** Tu `strategy-matrix.md`, loc ra danh sach features co strategy != "Deprecate". Day la features se duoc seed vao registry. | Read | Features filtered |
| 2.2 | **Build args:** `--from-scan=$SCAN_SESSION_ID --system=$TARGET_SYSTEM --module=$TARGET_MODULE`. Neu `$MODULE_EXISTS == false` → them flag `--new-module`. | — | Args built |
| 2.3 | **Invoke `/wf-add-scope`:** Skill tool voi skill=`wf-add-scope`, args=`--from-scan=$SCAN_SESSION_ID ...`. Theo Sub-Skill Invocation Pattern. | Skill | Sub-skill invoked |
| 2.4 | **Verify registry updated:** Doc lai registry. Kiem tra `$TARGET_MODULE` co trong `modules[]`. Kiem tra features moi duoc them. | Read | Registry verified |
| 2.5 | **Snapshot registry cho rollback (NEW v1.1):** Copy toan bo registry hien tai vao `$SESSION_DIR/snapshots/registry-phase2-{timestamp}.json`. Ghi snapshot metadata vao `$ROLLBACK_SNAPSHOTS[]`. | Read/Write | Snapshot saved |
| 2.6 | **Cap nhat status + checkpoint:** Cap nhat `migrate-status.json` (current_phase="add-scope"). Luu checkpoint (next_phase="phase3", rollback_snapshot_id). | Write | Status updated |

---

## POST-GATE

```bash
# Verify registry da duoc cap nhat
jq -e '.modules[] | select(.id == "$TARGET_MODULE")' .mc-data/docs/_meta/req-registry.json
# Verify it nhat 1 feature moi duoc them
jq -e '.features | map(select(.module_id == "$TARGET_MODULE")) | length > 0' .mc-data/docs/_meta/req-registry.json
# Verify rollback snapshot ton tai (NEW v1.1)
test -f $SESSION_DIR/snapshots/registry-phase2-*.json
```

---

## Next Phase

→ `procedures/phase3-define-features.md`
