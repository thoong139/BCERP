# Sprint 1 — Foundation

**Goal:** Session isolation + 7 bash scripts + JSONL history index
**Estimated effort:** 4h
**Dependencies:** User approve D1, D2 trong `03-decisions-pending.md`
**Output:** v4.0.0-alpha — backward compat với data v3.x qua migration script

---

## Mục tiêu cụ thể (8 sub-goals)

1. **G1 fix:** Session isolation `$FEATURE_SLUG/sessions/{id}/`
2. **G2 fix:** 7 bash scripts trong `.claude/scripts/wf-implement-feature/`
3. **G3 fix:** JSONL history index `.history/implementations-index.jsonl`
4. SKILL.md: Bump v4.0.0, thay inline bash → script calls (giảm ~150 dòng)
5. Migration script v3.x → v4.0 (idempotent)
6. .gitignore conventions
7. CLAUDE.md §4b cập nhật
8. _contract.json cập nhật outputs paths + `procedure[]`

---

## Steps chi tiết

### Step 1.1 — Tạo `implement-common.sh`

**File:** `.claude/scripts/wf-implement-feature/implement-common.sh`

**Functions cần có:**
- `normalize_slug()` — Vietnamese-safe slug (đã có trong SKILL.md:213-220, port over)
- `short_host()` — hostname truncated to 12 chars, lowercased
- `generate_session_id()` — `{date}-{time}-{host}` format
- `resolve_session_dir()` — handle --resume/--fresh routing
- `trace_event()` — append to `_trace/session-log.json`
- `get_feature_dir()` — `.mc-data/work/wf-implement-feature/$FEATURE_SLUG`
- `get_active_session()` — read `current.txt`, fallback list sessions/

**Verify:**
```bash
bash -n .claude/scripts/wf-implement-feature/implement-common.sh
source .claude/scripts/wf-implement-feature/implement-common.sh
type normalize_slug | grep -q "function"
test "$(normalize_slug 'Đăng nhập SmartTax')" = "dang-nhap-smarttax"
```

---

### Step 1.2 — Tạo `implement-acquire-lock.sh`

**Args:** `--slug=$SLUG --type=feature|registry|decision-registry --resume=true|false`

**Behavior:**
- type=feature → `.locks/$SLUG.lock`
- type=registry → `.mc-data/docs/_meta/.registry.lock`
- type=decision-registry → `.mc-data/docs/_meta/.decision-registry.lock`

**Exit codes:**
- 0 — acquired
- 1 — busy (other process alive)
- 2 — timeout (30s)

**Atomic create:** `( set -C; echo "$$:$(date +%s)" > "$LOCK" )`
**Stale detection:** PID dead OR age > 5min (registry/decision-registry) / age > 1h (feature)
**Trap release on EXIT** in calling script

**Verify:**
```bash
.claude/scripts/wf-implement-feature/implement-acquire-lock.sh --slug=test-feat --type=feature && \
  test -f .mc-data/work/wf-implement-feature/.locks/test-feat.lock && \
  rm .mc-data/work/wf-implement-feature/.locks/test-feat.lock
```

---

### Step 1.3 — Tạo `implement-detect-stack.sh`

**Args:** `--cwd=$PROJECT_ROOT`

**Output (stdout):** JSON
```json
{
  "test_framework": "jest",
  "package_manager": "pnpm",
  "language": "typescript",
  "project_type": "monorepo",
  "node_version": "20.x"
}
```

**Detection logic:**
- `package.json` exists → JS/TS project. Read `devDependencies` cho test framework (jest/vitest/mocha)
- `pyproject.toml` → Python. Detect pytest
- `*.csproj` → C#. Detect xUnit
- `go.mod` → Go. Detect testing
- `Cargo.toml` → Rust. Detect cargo test
- `pom.xml` → Java/Maven
- `build.gradle` → Java/Gradle

**Cache:** Lưu vào `$SESSION_DIR/stack.json` để skip re-detect

**Verify:**
```bash
.claude/scripts/wf-implement-feature/implement-detect-stack.sh --cwd=/path | jq -e '.test_framework'
```

---

### Step 1.4 — Tạo `implement-safety-gate.sh`

**Args:** `--req-id=REQ-XXX --feature-name="..." --search-terms=name1,name2 --cwd=...`

**Output:** JSON
```json
{
  "existing_files": ["src/modules/crm/customer.entity.ts"],
  "existing_endpoints": ["POST /customers", "GET /customers/:id"],
  "existing_components": ["CustomerListPage"],
  "found_count": 3
}
```

**Logic:**
- Grep search_terms in src/, apps/
- Detect entity files matching name pattern
- Detect API routes
- Detect frontend components

**Verify (CORE-020):**
- Khi `found_count > 0` AND `--strategy=IMPLEMENT_NEW` → caller must escalate to user
- Khi `found_count == 0` AND `--strategy=COMPLETE_EXISTING` → caller must escalate

---

### Step 1.5 — Tạo `implement-postgate.sh`

**Args:** `--session-dir=... --req-ids=REQ-X,REQ-Y`

**Output:** JSON
```json
{
  "T1": true,
  "T2": true,
  "T3": true,
  "T4": true,
  "failures": [],
  "details": {
    "T1_files_checked": [...],
    "T2_sections_found": [...],
    "T3_word_counts": {"phase-summary.md": 87, "impl-report.md": 245},
    "T4_req_ids_done": ["REQ-X", "REQ-Y"]
  }
}
```

**Logic:** Port từ phase6-finalize.md:62-109

---

### Step 1.6 — Tạo `implement-snapshot.sh`

**Args:** `--before=...json --after=...json --req-ids=REQ-X,REQ-Y`

**Output:** JSON
```json
{
  "changed_fields": ["requirements[REQ-X].impl_status", "requirements[REQ-Y].impl_status"],
  "unexpected_changes": [],
  "passed": true
}
```

**Logic:** Diff JSON, verify CHỈ `impl_status` cho req-ids trong scope thay đổi.

---

### Step 1.7 — Tạo `implement-history-index.sh`

**Args:** `--feature-slug=... --feat-id=... --session-id=... --status=completed --files-created=N --files-modified=N --tests-count=N --scenario=NEW --profile=standard`

**Behavior:**
- Lock `.history/.lock`
- Append JSON entry to `.history/implementations-index.jsonl`
- Release lock

**Entry format:**
```json
{"feature_slug":"customer-management","feat_id":"FEAT-CRM-CUST-001","session_id":"2026-04-28-103045-laptop","host":"laptop","user":"cntt","scenario":"NEW","started_at":"2026-04-28T10:30:00Z","completed_at":"2026-04-28T10:50:00Z","status":"completed","files_created":12,"files_modified":3,"tests_count":24,"profile":"standard","decisions_added":2}
```

---

### Step 1.8 — Tạo migration script `implement-migrate-v3-to-v4.sh`

**Behavior:** Idempotent — chạy lần thứ 2 không lỗi.

```bash
for FEATURE_DIR in .mc-data/work/wf-implement-feature/*/; do
  # Skip non-feature dirs (.history, .cache, .locks, archived)
  [[ "$(basename $FEATURE_DIR)" =~ ^\..+ ]] && continue

  # Already migrated?
  [[ -d "$FEATURE_DIR/sessions" ]] && continue

  # Has flat data?
  [[ -f "$FEATURE_DIR/impl-status.json" ]] || continue

  MIGRATED_SESSION="2026-04-28-000000-migrated"
  mkdir -p "$FEATURE_DIR/sessions/$MIGRATED_SESSION"
  for f in "$FEATURE_DIR"*.json "$FEATURE_DIR"*.md; do
    [[ -f "$f" ]] && mv "$f" "$FEATURE_DIR/sessions/$MIGRATED_SESSION/"
  done
  echo "sessions/$MIGRATED_SESSION" > "$FEATURE_DIR/current.txt"
  echo "Migrated: $FEATURE_DIR"
done
```

**Run automatically:** SKILL.md Phase 0 step 0.0 — detect old layout → call migration → continue.

---

### Step 1.9 — Update SKILL.md

**Changes:**
- `version: 4.0.0`
- `last_updated: <date>`
- Changelog entry v4.0.0
- Phase 0.2b: replace inline normalize_slug → `source implement-common.sh; SLUG=$(normalize_slug "$NAME")`
- Phase 0.2c: replace inline lock → `bash implement-acquire-lock.sh --slug=$SLUG --type=feature --resume=$RESUME`
- Phase 0.2d (NEW): `SESSION_DIR=$(resolve_session_dir "$SLUG" "$RESUME")` + `mkdir -p $SESSION_DIR`
- Update all path references: `$FEATURE_SLUG/foo` → `$SESSION_DIR/foo`
- Section "FEATURE_SLUG Derivation" → reference script function

**Line count target:** 596 → ~500 dòng (giảm ~100)

---

### Step 1.10 — Update _shared.md

**Changes:**
- `Cross-Process Mutex` section: replace ~50 dòng inline bash → `bash implement-acquire-lock.sh --type=registry`
- `Execution Flow Between Phase Files` table: thêm `$SESSION_DIR` variable
- `State Variables Passed Between Phases` table: thêm `$SESSION_ID`, `$SESSION_DIR`

---

### Step 1.11 — Update phase6-finalize.md

**Changes:**
- Step 6.1-LOCK: replace inline → `bash implement-acquire-lock.sh --type=registry`
- Step 6.5: replace inline registry diff → `bash implement-snapshot.sh --before=$BEFORE --after=$AFTER --req-ids=$REQ_IDS`
- POST-GATE T1-T4: replace inline → `bash implement-postgate.sh --session-dir=$SESSION_DIR --req-ids=$REQ_IDS | jq -e '.passed'`
- Step 6.x (NEW): `bash implement-history-index.sh --feature-slug=$SLUG ...` (append history)

---

### Step 1.12 — Update phase0-5-context-setup.md, phase1-feature-context.md

**Changes:**
- All `$FEATURE_SLUG/foo.json` paths → `$SESSION_DIR/foo.json`
- Step phase0-5 0.5a: read $SESSION_DIR from caller (SKILL.md)

---

### Step 1.13 — Cập nhật .gitignore

**File:** root `.gitignore` (project) + `.mc-data/.gitignore` (nested)

```gitignore
# wf-implement-feature - per-machine working state
.mc-data/work/wf-implement-feature/*/sessions/
.mc-data/work/wf-implement-feature/*/current.txt
.mc-data/work/wf-implement-feature/.locks/
.mc-data/work/wf-implement-feature/.cache/

# History index - CHECK-IN cho multi-dev
!.mc-data/work/wf-implement-feature/.history/
!.mc-data/work/wf-implement-feature/.history/*.jsonl
```

---

### Step 1.14 — CLAUDE.md §4b

**Add 3 rows:**

```markdown
| `/wf-implement-feature` Session-aware | `.mc-data/work/wf-implement-feature/{$FEATURE_SLUG}/sessions/{$SESSION_ID}/impl-status.json` | wf-preflight, wf-verify-sync, OPTIONAL: wf-prepare-deployment / wf-fix-bugs (--from-impl) |
| `/wf-implement-feature` History | `.mc-data/work/wf-implement-feature/.history/implementations-index.jsonl` | Audit trail (multi-dev), `/status` skill |
| `/wf-implement-feature` Current pointer | `.mc-data/work/wf-implement-feature/{$FEATURE_SLUG}/current.txt` | --resume routing |
```

---

### Step 1.15 — Update _contract.json

**Changes:**
- `version: 4.0.0`
- `outputs.working[]`: replace `$FEATURE_SLUG/...` → `$FEATURE_SLUG/sessions/$SESSION_ID/...`
- Add new outputs: `current.txt`, `.history/implementations-index.jsonl`, `error-ledger.json` (Sprint 4 trước, prepare here)
- `procedure[]`: same files, no changes (Sprint 4 rename optional)

---

### Step 1.16 — Smoke test

**Test:**
```bash
# 1. Create dummy feature in registry
# 2. Run: claude /wf-implement-feature TEST-FEAT-001
# 3. Verify:
test -d .mc-data/work/wf-implement-feature/test-feat-001/sessions/$(cat .mc-data/work/wf-implement-feature/test-feat-001/current.txt | xargs basename)
test -f .mc-data/work/wf-implement-feature/.history/implementations-index.jsonl
jq -e '.session_id' < $(tail -1 .mc-data/work/wf-implement-feature/.history/implementations-index.jsonl)
```

---

## Definition of Done — Sprint 1

- [ ] 7 bash scripts tồn tại + có executable bit + `bash -n` pass
- [ ] Migration script idempotent (chạy 2 lần không break)
- [ ] SKILL.md bumped v4.0.0, changelog entry
- [ ] All paths trong procedures dùng `$SESSION_DIR` thay `$FEATURE_SLUG/...`
- [ ] .gitignore cập nhật + verify (sessions ignored, .history check-in)
- [ ] CLAUDE.md §4b 3 rows mới
- [ ] _contract.json bumped + paths updated + schema sync
- [ ] Smoke test: chạy skill cho 1 feature đơn giản → verify session dir + history JSONL
- [ ] Inline bash giảm ≥ 100 dòng (target -150)

---

## Risks Sprint 1

| Risk | Mitigation |
|------|-----------|
| Migration script accidentally moves wrong files | Idempotent + chỉ move .json/.md flat, không touch dirs (sessions/, archived/) |
| Bash script Windows compat | Test với Git Bash + WSL như existing scan-target-*.sh pattern |
| Smoke test fail giữa chừng | Có rollback: `git diff` toàn bộ changes, revert nếu cần |
| --resume cũ (v3.x style) break | Backward compat read trong implement-common.sh: nếu current.txt missing AND impl-status.json flat → trigger auto-migrate trước resume |

---

## Output cho Sprint 2

Sprint 1 produce:
- 7 scripts ready để Sprint 2 reuse (đặc biệt `implement-common.sh`)
- `$SESSION_DIR` variable established → Sprint 2 cache layer build trên đó
- Skill v4.0.0-alpha (foundation) ready cho profile system add-on
