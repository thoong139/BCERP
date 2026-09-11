# Sprint 2 — Adaptive Profile

**Goal:** `--profile=quick|standard|deep|exhaustive` flag + pattern cache + profile resolver
**Estimated effort:** 3h
**Dependencies:** Sprint 1 complete (7 scripts + session isolation)
**Output:** v4.0.0-beta — adaptive scaling theo project size

---

## Mục tiêu cụ thể

1. **G4 fix:** Profile system với 4 levels — đồng bộ với peer skills
2. **G6 fix:** Pattern cache cho cùng module (TTL 24h + git SHA invalidation)
3. Profile resolver script: file_count → recommended profile
4. Smoke test cache hit (2 features cùng module → measurable token saving)

---

## Steps chi tiết

### Step 2.1 — Định nghĩa profile matrix trong SKILL.md

**Section MỚI:** "## Profile System" (đặt sau "Arguments" table)

```markdown
## Profile System

| Profile | Phase 3 mode | Phase 4 review agents | Tests run | Estimated time | Use case |
|---------|--------------|----------------------|-----------|----------------|----------|
| `quick` | sequential, no waves | code-reviewer only | smoke (failed-fast) | 5-15 min | Hotfix, prototype |
| `standard` (default) | sequential | code-reviewer + qa-lead | full unit | 15-45 min | Daily dev |
| `deep` | parallel waves auto | code+qa+security | unit + integration | 30-90 min | Production-ready |
| `exhaustive` | parallel waves + e2e | code+qa+security+a11y+performance | unit + integration + e2e | 60-180 min | Release-candidate |

### Profile Resolution

If `--profile` not specified → auto-detect via `implement-resolve-profile.sh`:
- ≤ 5 files in scope → `quick`
- 6-30 files → `standard`
- 31-100 files → `deep`
- > 100 files → `exhaustive`

User có thể override với `--profile=<name>` flag.

### Profile Flag Interaction

| Flag combination | Behavior |
|------------------|----------|
| `--profile=quick` | Auto: code-reviewer only, smoke tests |
| `--profile=quick --skip-review` | Skip ALL review (override) |
| `--profile=deep --component=entity` | Profile applies to selected components |
| `--profile=quick --parallel` | --parallel ignored + WARNING (quick = sequential) |
```

**Update args table:** Thêm row `--profile=<name>` cho `--profile=quick|standard|deep|exhaustive`

---

### Step 2.2 — Tạo `implement-resolve-profile.sh`

**Args:** `--scope-files-count=N --task-file=...`

**Output:** stdout = profile name, stderr = recommendation note

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname $0)/implement-common.sh"

COUNT="${SCOPE_FILES_COUNT:-0}"

if [[ -n "${PROFILE_OVERRIDE:-}" ]]; then
  echo "$PROFILE_OVERRIDE"
  exit 0
fi

if (( COUNT <= 5 )); then
  RECOMMENDED="quick"
elif (( COUNT <= 30 )); then
  RECOMMENDED="standard"
elif (( COUNT <= 100 )); then
  RECOMMENDED="deep"
else
  RECOMMENDED="exhaustive"
fi

echo "INFO: No --profile specified. Auto-recommended: $RECOMMENDED ($COUNT files)" >&2
echo "$RECOMMENDED"
```

---

### Step 2.3 — Update phase2-planning.md

**Changes:**
- Step 2.0 (NEW): Resolve profile
  ```
  IF $PROFILE empty: $PROFILE = $(implement-resolve-profile.sh --scope-files-count=$(jq '.a2_4_scope_files | length' task-meta.json))
  ```
- Update batch logic: profile=quick → 1 batch all, profile=deep → multi batches with parallel waves

---

### Step 2.4 — Update phase4-5-review-fix.md

**Changes:**
- Step 4.0 (Adaptive agent spawning) đã có v3.3.0 — extend theo profile:
  ```
  Agent set per profile:
  - quick: [code-reviewer]
  - standard: [code-reviewer, qa-lead]
  - deep: [code-reviewer, qa-lead, security]
  - exhaustive: [code-reviewer, qa-lead, security, accessibility-auditor, performance-benchmarker]

  CROSS theo batch_type:
  - annotation_only batch: chỉ code-reviewer regardless of profile (token saving)
  - new_files batch: full profile set
  ```

---

### Step 2.5 — Pattern cache logic trong phase01-pattern-scan (phase0-existing-analysis.md)

**Add new section "Cache Strategy":**

```markdown
## Cache Strategy (v4.0+)

Trước khi scan existing patterns:

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Compute MODULE_SLUG từ feature.module field | `$MODULE_SLUG` non-empty |
| 0.2 | Compute GIT_SHA = `git rev-parse --short=8 HEAD` | `$GIT_SHA` 8-char hex |
| 0.3 | CACHE_FILE=`.mc-data/work/wf-implement-feature/.cache/$MODULE_SLUG/existing-patterns.$GIT_SHA.json` | Path resolved |
| 0.4 | IF `--no-cache` → skip cache, goto Step 0.7 (full scan) | — |
| 0.5 | IF cache file exists AND `find $CACHE_FILE -mmin -1440` (TTL 24h) AND `bash implement-cache-resolver.sh --validate $CACHE_FILE` returns 0: | CACHE HIT |
|      | → Copy cache to `$SESSION_DIR/existing-patterns.json` | File copied |
|      | → trace_event CACHE_HIT | Logged |
|      | → goto next phase | — |
| 0.6 | CACHE MISS — log `error-ledger.json`: code=E101 severity=info | Logged |
| 0.7 | Full scan (existing logic v3.4.0) | — |
| 0.8 | Write to cache: `$CACHE_FILE` (kèm `invalidation_hash`, `scanned_at`, `module_slug`, `git_sha`) | Cache written |
| 0.9 | Symlink `$SESSION_DIR/existing-patterns.json` → `$CACHE_FILE` (HOẶC copy nếu Windows) | Linked |
```

---

### Step 2.6 — Tạo `implement-cache-resolver.sh`

**Args:** `--validate $CACHE_FILE` (mode 1) | `--compute-hash $MODULE_PATH` (mode 2)

**Mode 1 (validate):**
- Check JSON valid
- Check `invalidation_hash` matches current `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum`
- Exit 0 if valid, 1 if invalid

**Mode 2 (compute hash):**
- Output current invalidation hash for storage

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname $0)/implement-common.sh"

MODE="$1"
ARG="$2"

if [[ "$MODE" == "--validate" ]]; then
  CACHE_FILE="$ARG"
  jq '.' "$CACHE_FILE" >/dev/null 2>&1 || exit 1

  STORED_HASH=$(jq -r '.invalidation_hash' "$CACHE_FILE")
  MODULE_PATH=$(jq -r '.module_path' "$CACHE_FILE")
  CURRENT_HASH=$(git ls-tree -r HEAD -- "$MODULE_PATH" 2>/dev/null | sha1sum | cut -d' ' -f1)

  [[ "$STORED_HASH" == "$CURRENT_HASH" ]] && exit 0 || exit 1
elif [[ "$MODE" == "--compute-hash" ]]; then
  MODULE_PATH="$ARG"
  git ls-tree -r HEAD -- "$MODULE_PATH" 2>/dev/null | sha1sum | cut -d' ' -f1
fi
```

---

### Step 2.7 — Smoke test cache hit

**Test scenario:**

```bash
# Implement FEAT-A trong module CRM
claude /wf-implement-feature FEAT-CRM-CUST-001
TOKENS_A=$(jq '.cache_hits.saved_tokens_estimated' .mc-data/work/wf-implement-feature/customer-management/sessions/$ID/impl-status.json)

# Implement FEAT-B trong cùng module CRM (no commit between)
claude /wf-implement-feature FEAT-CRM-CUST-002
TOKENS_B=$(jq '.cache_hits.saved_tokens_estimated' .mc-data/work/wf-implement-feature/contact-management/sessions/$ID/impl-status.json)
HIT_B=$(jq '.cache_hits.existing_patterns' .mc-data/work/wf-implement-feature/contact-management/sessions/$ID/impl-status.json)

# Assert
test "$HIT_B" = "true"
test "$TOKENS_B" -ge 5000  # estimated saved
```

---

### Step 2.8 — Update _contract.json

- `version: 4.0.0` (đã bump Sprint 1, just confirm)
- Add cache path to outputs (notes: per-machine, gitignored)
- Add `--profile`, `--no-cache` to documented arguments (in description)

---

## Definition of Done — Sprint 2

- [ ] `--profile=quick|standard|deep|exhaustive` flag works end-to-end
- [ ] Profile auto-recommendation works (≤5 files → quick, >100 → exhaustive)
- [ ] `--no-cache` flag bypasses cache
- [ ] Cache hit measurable (tokens saved estimated in impl-status.json)
- [ ] Multi-feature same-module test: feature 2 has cache_hits=true
- [ ] Cache invalidation works (git commit changes module → cache miss next time)
- [ ] _contract.json updated
- [ ] SKILL.md profile section added

---

## Risks Sprint 2

| Risk | Mitigation |
|------|-----------|
| Cache stale → bug | Dual invalidation: TTL 24h + git SHA hash |
| Symlink không work trên Windows | Fallback: copy thay vì symlink. Detect `uname -s` trong implement-common.sh |
| Profile=exhaustive too slow cho dev daily | Default = standard, exhaustive là OPT-IN cho release |
| ProfileHashes git not initialized | Graceful fallback: nếu `git rev-parse` fail → cache key = "no-git" + timestamp |

---

## Output cho Sprint 3

- Profile system established → Sprint 3 schema v2.0 thêm `profile` field vào impl-status.json
- Cache hits tracked → Sprint 3 thêm `cache_hits` field vào consumer_hints
