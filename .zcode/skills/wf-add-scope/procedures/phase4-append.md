# Phase 4 — Registry Safe-Append

> **Self-contained phase file.** Atomic append vào registry. KHÔNG modify fields khác.
> Tham chiếu `_shared.md §3` cho Safe-Write Protocol (CORE-006).

---

## PRE-GATE

- Phase 3 POST-GATE PASS
- User confirmed (từ Step 3.3)
- `$DRY_RUN == false`
- `$SESSION_DIR/scope-spec.json` valid với `modules_to_add` hoặc `features_to_add` non-empty

---

## 📥 INPUT

- `$SESSION_DIR/scope-spec.json`
- `.mc-data/docs/_meta/req-registry.json` (current — sẽ được modify)

---

## 📤 OUTPUT

- `.mc-data/docs/_meta/req-registry.json` — updated (safe-append)
- `.mc-data/docs/_meta/req-registry.json.pre-addscope-<timestamp>` — backup

---

## Safe-Write Guarantee (CORE-006)

**Fields OWNED by this skill:** `modules[]`, `features[]`

**Fields NOT TOUCHED:** `project`, `systems[]`, `departments[]`, `requirements[]`, `interface_type`, `design_status`, `ux_design_status`, `implementation_order`, per-REQ `impl_status`

**Validation sau write:**
- `$systems_count_before == $systems_count_after`
- `$modules_count_after == $modules_count_before + $modules_added`
- `$features_count_after == $features_count_before + $features_added`
- All existing module/feature IDs still present (no deletions)

---

## Steps

### Step 4.1 — Acquire Registry Lock

```bash
RESULT=$(bash .claude/scripts/wf-add-scope/as-acquire-lock.sh registry "$SESSION_DIR" 30)
LOCK_STATUS=$(echo "$RESULT" | jq -r '.status // .error')
```

- `status="acquired"` → continue
- `error="lock_held_alive"` → wait 5s, retry up to 3 times → STOP E011 nếu vẫn fail
- Export `$REGISTRY_LOCK_PATH` từ `RESULT.lock_path`

---

### Step 4.2 — Backup Registry (delegate)

```bash
BACKUP_RESULT=$(bash .claude/scripts/wf-add-scope/as-backup-registry.sh "$SESSION_DIR")
BACKUP_PATH=$(echo "$BACKUP_RESULT" | jq -r '.backup_path')
CHECKSUM_PRE=$(echo "$BACKUP_RESULT" | jq -r '.checksum')
```

**Verify:** `$BACKUP_PATH` non-empty, file tồn tại.

**Export `$BACKUP_PATH`** → dùng ở Step 4.7 rollback và Phase 6 report.

---

### Step 4.3 — Count before

```bash
MODULES_BEFORE=$(jq '.modules | length' .mc-data/docs/_meta/req-registry.json)
FEATURES_BEFORE=$(jq '.features | length' .mc-data/docs/_meta/req-registry.json)
SYSTEMS_BEFORE=$(jq '.systems | length' .mc-data/docs/_meta/req-registry.json)
```

---

### Step 4.4 — Atomic append

```bash
# Đọc fresh (không cache)
NEW_MODULES=$(jq '.modules_to_add' "$SESSION_DIR/scope-spec.json")
NEW_FEATURES=$(jq '.features_to_add' "$SESSION_DIR/scope-spec.json")

# Append modules + features trong single jq pipeline (atomic)
# P1-7 fix: mktemp in same directory to ensure same-filesystem atomic mv
tmp=$(mktemp ".mc-data/docs/_meta/req-registry.XXXXXX")
jq \
  --argjson new_mods "$NEW_MODULES" \
  --argjson new_feats "$NEW_FEATURES" \
  '.modules += $new_mods | .features += $new_feats' \
  .mc-data/docs/_meta/req-registry.json > "$tmp"

# Atomic write — same-filesystem mv is atomic even on Windows
mv "$tmp" .mc-data/docs/_meta/req-registry.json
```

---

### Step 4.5 — Validate post-write (delegate)

```bash
MODULES_ADDED=$(jq '.modules_to_add | length' "$SESSION_DIR/scope-spec.json")
FEATURES_ADDED=$(jq '.features_to_add | length' "$SESSION_DIR/scope-spec.json")

VALIDATE_RESULT=$(bash .claude/scripts/wf-add-scope/as-validate-registry.sh \
  "$SESSION_DIR" "$MODULES_ADDED" "$FEATURES_ADDED")
VALIDATE_PASS=$(echo "$VALIDATE_RESULT" | jq -r '.pass')
```

- `pass: true` → continue
- `pass: false` → **ROLLBACK** từ `$BACKUP_PATH` → STOP E005

**Rollback:**

```bash
if [[ "$VALIDATE_PASS" != "true" ]]; then
  # P1-2 fix: Validate backup before restoring
  if jq '.' "$BACKUP_PATH" > /dev/null 2>&1; then
    cp "$BACKUP_PATH" .mc-data/docs/_meta/req-registry.json
  else
    echo "CRITICAL: Backup corrupted at $BACKUP_PATH. Manual recovery required."
  fi
  # P1-1 fix: Release registry lock on error path
  bash .claude/scripts/wf-add-scope/as-release-lock.sh registry "$SESSION_DIR"
  # APPEND execution trace FAIL entry (_shared.md §10)
  # STOP E005: "Write failed / validation failed. Registry restored từ backup: $BACKUP_PATH"
fi
```

---

### Step 4.6 — Update audit_chain + status

```bash
CHECKSUM_POST=$(sha256sum .mc-data/docs/_meta/req-registry.json 2>/dev/null | awk '{print $1}' || \
                shasum -a 256 .mc-data/docs/_meta/req-registry.json 2>/dev/null | awk '{print $1}' || \
                md5sum .mc-data/docs/_meta/req-registry.json | awk '{print $1}')
MODULES_AFTER=$(echo "$VALIDATE_RESULT" | jq -r '.modules')
FEATURES_AFTER=$(echo "$VALIDATE_RESULT" | jq -r '.features')
MODULES_ADDED_IDS=$(jq -c '[.modules_to_add[].id]' "$SESSION_DIR/scope-spec.json")
```

```
UPDATE $SESSION_DIR/add-scope-status.json:
  phases.phase_4.status             = "completed"
  audit_chain.checksum_pre          = $CHECKSUM_PRE
  audit_chain.checksum_post         = "sha256:$CHECKSUM_POST"
  summary.modules_added             = $MODULES_ADDED_IDS   (array of IDs)
  summary.features_added            = $FEATURES_ADDED
  summary.modules_before            = $MODULES_BEFORE
  summary.modules_after             = $MODULES_AFTER
  summary.features_before           = $FEATURES_BEFORE
  summary.features_after            = $FEATURES_AFTER
  summary.registry_backup           = $BACKUP_PATH
  summary.rollback_available        = true
```

---

### Step 4.7 — Release Registry Lock

```bash
bash .claude/scripts/wf-add-scope/as-release-lock.sh registry "$SESSION_DIR"
```

---

## POST-GATE

- Registry valid JSON (`jq '.' passes`)
- Count assertions pass: systems unchanged, modules/features incremented đúng số
- Backup tồn tại và đọc được
- Không entry hiện có bị modify/delete/rename
- `audit_chain.checksum_post` non-null (set — critical for resume detection)
- Registry lock released
- `$SESSION_DIR/add-scope-status.json.phases.phase_4.status` = `"completed"`

---

## Next Phase

- **IF `$NO_DOCS == false` AND `features_to_add > 0`:** → Load `phase5-docs.md`
- **ELSE:** → Load `phase6-report.md` (skip Phase 5)
