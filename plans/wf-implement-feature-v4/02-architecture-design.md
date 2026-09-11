# Architecture Design — wf-implement-feature v4.0

**Ngày tạo:** 2026-04-28
**Mục đích:** Cấu trúc kỹ thuật chi tiết của các giải pháp đề xuất trong `01-current-state-analysis.md`

---

## 1. Cấu trúc thư mục mới

### 1.1 Working directory layout

```
.mc-data/work/wf-implement-feature/
├── .history/                                          ← CHECK-IN git (multi-dev safety)
│   └── implementations-index.jsonl                    ← Append-only (G3)
├── .cache/                                            ← .gitignore (per-machine)
│   └── {module_slug}/
│       └── existing-patterns.{git_sha_short}.json     ← Pattern cache (G6) — TTL 24h
├── .locks/                                            ← .gitignore (runtime-only)
│   └── {feature_slug}.lock                            ← Per-feature lock (đã có v3.2.0)
├── multi-feature-report-{ts}.md                       ← Multi-feature mode (đã có)
└── {feature_slug}/
    ├── current.txt                                    ← Pointer to active session (relative path)
    ├── archived/                                      ← --fresh archive cũ (KHÔNG xóa)
    │   └── {old_session_id}/...                       ← Toàn bộ session cũ
    └── sessions/
        └── {YYYY-MM-DD}-{HHMMSS}-{shorthost}/         ← Session ID format
            ├── session-state.json                     ← MỚI: tracking phase status
            ├── impl-status.json                       ← Đã có (v2.0 schema)
            ├── impl-plan.md                           ← Đã có
            ├── existing-patterns.json                 ← Đã có (có thể là symlink → cache)
            ├── decision-registry.json                 ← Đã có (per-feature, vẫn giữ)
            ├── checkpoint.json                        ← Đã có
            ├── qa-review-attempt-{N}.md               ← Đã có
            ├── impl-report.md                         ← Đã có (v2.0 với consumer_hints)
            ├── phase-summary.md                       ← Đã có (v2.0 thêm "Cho skill kế tiếp")
            ├── cdg-tokens.json                        ← Đã có (conditional)
            ├── contracts.json                         ← Đã có (conditional --parallel)
            └── error-ledger.json                      ← MỚI (G5)
```

### 1.2 Global registry (cross-feature)

```
.mc-data/docs/_meta/
└── decision-registry.global.json                      ← MỚI (G9) — APPEND-only by wf-implement-feature
```

### 1.3 Bash scripts library

```
.claude/scripts/wf-implement-feature/
├── implement-common.sh           ← source helper (slug, host, paths, session_id gen)
├── implement-acquire-lock.sh     ← per-feature + registry mutex (DRY)
├── implement-detect-stack.sh     ← test framework, package manager, project type
├── implement-safety-gate.sh      ← CORE-020 search existing code
├── implement-postgate.sh         ← T1-T4 validator
├── implement-snapshot.sh         ← registry diff verify (Step 6.5)
└── implement-history-index.sh    ← append JSONL entry to .history/
```

---

## 2. Session ID format (G1)

**Format:** `{YYYY-MM-DD}-{HHMMSS}-{shorthost}`

**Examples:**
- `2026-04-28-103045-laptop`
- `2026-04-28-150022-erk-pc`
- `2026-04-28-220015-mac-air`

**Generation pattern (bash):**
```bash
SESSION_ID="$(date -u +%Y-%m-%d-%H%M%S)-$(hostname | head -c 12 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
SESSION_DIR=".mc-data/work/wf-implement-feature/$FEATURE_SLUG/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR"
echo "sessions/$SESSION_ID" > ".mc-data/work/wf-implement-feature/$FEATURE_SLUG/current.txt"
```

**Multi-session same-day:**
- Nếu user chạy 2 sessions trong cùng giây (rare) → second SESSION_ID giống first → append `-2`, `-3`, ...
- Pattern: while [[ -d "$SESSION_DIR" ]]; do SESSION_ID="${BASE}-$(N+1)"; done

**Resume logic:**
```bash
if [[ "$ARGUMENTS" == *"--resume"* ]]; then
  CURRENT="$(cat $FEATURE_DIR/current.txt 2>/dev/null)"
  if [[ -n "$CURRENT" && -d "$FEATURE_DIR/$CURRENT" ]]; then
    SESSION_DIR="$FEATURE_DIR/$CURRENT"
    SESSION_ID="$(basename $CURRENT)"
  else
    # Fallback: list sessions/, pick newest
    SESSION_ID="$(ls -1 $FEATURE_DIR/sessions/ | sort -r | head -1)"
  fi
fi
```

**--fresh logic:**
```bash
if [[ "$ARGUMENTS" == *"--fresh"* ]]; then
  if [[ -f "$FEATURE_DIR/current.txt" ]]; then
    OLD_SESSION="$(cat $FEATURE_DIR/current.txt)"
    mkdir -p "$FEATURE_DIR/archived"
    mv "$FEATURE_DIR/$OLD_SESSION" "$FEATURE_DIR/archived/$(basename $OLD_SESSION)"
    rm "$FEATURE_DIR/current.txt"
  fi
  # Tạo session mới như fresh start
fi
```

**Migration cho data cũ (v3.x → v4.0):**
```bash
# Migration script: implement-migrate-v3-to-v4.sh
for FEATURE_DIR in .mc-data/work/wf-implement-feature/*/; do
  if [[ -f "$FEATURE_DIR/impl-status.json" && ! -d "$FEATURE_DIR/sessions" ]]; then
    MIGRATED_SESSION="2026-04-28-000000-migrated"
    mkdir -p "$FEATURE_DIR/sessions/$MIGRATED_SESSION"
    mv "$FEATURE_DIR"*.{json,md} "$FEATURE_DIR/sessions/$MIGRATED_SESSION/" 2>/dev/null
    echo "sessions/$MIGRATED_SESSION" > "$FEATURE_DIR/current.txt"
  fi
done
```

---

## 3. Bash script library design (G2)

### 3.1 implement-common.sh — Shared helpers

```bash
#!/usr/bin/env bash
# Source-only file. KHÔNG run trực tiếp.

set -euo pipefail

# Constants
FEATURE_BASE_DIR=".mc-data/work/wf-implement-feature"
HISTORY_DIR="$FEATURE_BASE_DIR/.history"
CACHE_DIR="$FEATURE_BASE_DIR/.cache"
LOCKS_DIR="$FEATURE_BASE_DIR/.locks"
TRACE_LOG=".mc-data/work/_trace/session-log.json"

# Functions
normalize_slug() {
  local input="$1"
  echo "$input" \
    | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
    | sed -E 's![/\\_+]! !g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's![^a-z0-9 ]!!g; s/  +/ /g; s/^ +//; s/ +$//' \
    | tr ' ' '-' \
    | sed -E 's/-+/-/g' \
    | head -c 60
}

short_host() {
  hostname | head -c 12 | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-'
}

generate_session_id() {
  echo "$(date -u +%Y-%m-%d-%H%M%S)-$(short_host)"
}

resolve_session_dir() {
  local feature_slug="$1"
  local resume="${2:-false}"

  if [[ "$resume" == "true" ]]; then
    local current_pointer="$FEATURE_BASE_DIR/$feature_slug/current.txt"
    if [[ -f "$current_pointer" ]]; then
      local current_session
      current_session="$(cat $current_pointer)"
      echo "$FEATURE_BASE_DIR/$feature_slug/$current_session"
      return 0
    fi
  fi

  # Fresh
  local session_id
  session_id="$(generate_session_id)"
  local session_dir="$FEATURE_BASE_DIR/$feature_slug/sessions/$session_id"
  mkdir -p "$session_dir"
  echo "sessions/$session_id" > "$FEATURE_BASE_DIR/$feature_slug/current.txt"
  echo "$session_dir"
}

trace_event() {
  local event="$1"  # START / COMPLETE / FAIL / CHECKPOINT
  local feature_slug="$2"
  local session_id="$3"
  local extra_json="${4:-{}}"

  local entry
  entry="$(jq -nc --arg e "$event" --arg fs "$feature_slug" --arg sid "$session_id" \
    --arg ts "$(date -u +%FT%TZ)" --argjson extra "$extra_json" \
    '{skill:"wf-implement-feature",event:$e,feature_slug:$fs,session_id:$sid,ts:$ts} + $extra')"
  echo "$entry" >> "$TRACE_LOG"
}
```

### 3.2 Các scripts khác — Tóm tắt input/output contract

| Script | Input | Output | Side effect |
|--------|-------|--------|-------------|
| `implement-acquire-lock.sh` | `--slug=$FEATURE_SLUG --type=feature\|registry --resume=true\|false` | exit 0 (acquired), exit 1 (busy), exit 2 (timeout) | Tạo `.locks/$slug.lock` hoặc `.registry.lock` |
| `implement-detect-stack.sh` | `--cwd=$PROJECT_ROOT` | JSON: `{"test_framework":"jest","package_manager":"pnpm","language":"typescript","project_type":"monorepo"}` | Cache vào `$SESSION_DIR/stack.json` |
| `implement-safety-gate.sh` | `--req-id=REQ-XXX --feature-slug=... --search-terms=name1,name2` | JSON: `{"existing_files":[...],"existing_endpoints":[...],"existing_components":[...]}` | None |
| `implement-postgate.sh` | `--session-dir=... --req-ids=REQ-X,REQ-Y` | JSON: `{"T1":true,"T2":true,"T3":true,"T4":true,"failures":[]}` | None |
| `implement-snapshot.sh` | `--before=registry-before.json --after=registry-after.json --req-ids=REQ-X` | JSON: `{"changed_fields":[...],"unexpected_changes":[...]}` | None |
| `implement-history-index.sh` | `--feature-slug=... --feat-id=... --session-id=... --status=completed --files-created=N ...` | JSON entry appended | Append `.history/implementations-index.jsonl` |

### 3.3 Inline bash giảm

| Vị trí | Trước (dòng) | Sau (dòng) | Giảm |
|--------|--------------|------------|------|
| SKILL.md normalize_slug | 8 dòng inline | 1 dòng `source implement-common.sh; normalize_slug "$NAME"` | -7 |
| SKILL.md per-feature lock | 50+ dòng inline | 2 dòng call `implement-acquire-lock.sh` | -48 |
| _shared.md registry mutex | 50+ dòng inline | 2 dòng call `implement-acquire-lock.sh --type=registry` | -48 |
| phase6 POST-GATE T1-T4 | 40+ dòng inline | 3 dòng call `implement-postgate.sh` + parse JSON | -37 |
| Total | ~150 dòng | ~10 dòng | **~140 dòng giảm (~93%)** |

---

## 4. Profile system (G4)

### 4.1 Profile matrix

| Profile | Phase 3 mode | Phase 4 review agents | Tests run | Estimated time | Use case |
|---------|--------------|----------------------|-----------|----------------|----------|
| `quick` | sequential, no waves | code-reviewer only | smoke (failed-fast) | 5-15 min | Hotfix, prototype, throwaway |
| `standard` (default) | sequential | code-reviewer + qa-lead (parallel) | full unit | 15-45 min | Daily dev work |
| `deep` | parallel waves (--parallel auto) | code+qa+security (parallel) | unit + integration | 30-90 min | Feature production-ready |
| `exhaustive` | parallel waves + e2e | code+qa+security+a11y+performance | unit + integration + e2e | 60-180 min | Release-candidate |

### 4.2 Profile flag interaction

| Flag combination | Behavior |
|------------------|----------|
| `--profile=quick` | Auto: --skip-review=false (only code-reviewer), tests=smoke |
| `--profile=quick --skip-review` | Skip ALL review (override) |
| `--profile=deep --component=entity` | Profile applies to selected components only |
| `--profile=exhaustive --features=A,B,C` | Each feature in batch uses exhaustive |
| `--profile=quick --parallel` | --parallel ignored (quick = sequential) + WARNING |

### 4.3 Profile resolver

```bash
# implement-resolve-profile.sh
COUNT_FILES_IN_SCOPE=$(jq -r '.scope_files_exclusive | length' .locks/$SLUG.lock)
COUNT_TESTS=$(jq -r '.tests_count_estimated // 0' impl-status.json)

if [[ -z "$PROFILE" ]]; then
  if (( COUNT_FILES_IN_SCOPE <= 5 )); then
    RECOMMENDED="quick"
  elif (( COUNT_FILES_IN_SCOPE <= 30 )); then
    RECOMMENDED="standard"
  elif (( COUNT_FILES_IN_SCOPE <= 100 )); then
    RECOMMENDED="deep"
  else
    RECOMMENDED="exhaustive"
  fi
  echo "INFO: No --profile specified. Recommended: $RECOMMENDED ($COUNT_FILES_IN_SCOPE files)"
  PROFILE="$RECOMMENDED"
fi
```

---

## 5. Pattern cache (G6)

### 5.1 Cache key

```
key = "{module_slug}|{git_sha_short}"
file = .mc-data/work/wf-implement-feature/.cache/{module_slug}/existing-patterns.{git_sha_short}.json
```

**git_sha_short:** `git rev-parse --short=8 HEAD`

### 5.2 Invalidation

1. **TTL-based:** mtime > 24h → cache miss
2. **Git-based:** Hash of `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum` thay đổi → cache miss
3. **Force:** `--no-cache` flag → bypass

### 5.3 Phase 0 step phase01-pattern-scan logic (updated)

```
Step 0.1: Compute cache_key = $MODULE_SLUG + "|" + $GIT_SHA_SHORT
Step 0.2: IF --no-cache → goto Step 0.5 (always re-scan)
Step 0.3: IF cache file tồn tại AND mtime <= 24h:
            Compute current_hash = git ls-tree -r HEAD -- $MODULE_PATH | sha1sum
            IF current_hash == cache.invalidation_hash:
              → CACHE HIT — copy/symlink cache file vào $SESSION_DIR/existing-patterns.json
              → trace_event CACHE_HIT
              → goto Step 0.6
Step 0.4: CACHE MISS or invalid → fresh scan
Step 0.5: Scan existing patterns (như v3.4.0)
Step 0.6: Write to cache: $CACHE_DIR/$MODULE_SLUG/existing-patterns.$GIT_SHA_SHORT.json
            (kèm field "invalidation_hash" và "scanned_at")
Step 0.7: Symlink/copy vào $SESSION_DIR/existing-patterns.json
```

### 5.4 Token saving estimate

- Existing-patterns scan: ~5-10k tokens/feature
- Implement 5 features cùng module:
  - v3.4.0: 5 × 8k = 40k tokens
  - v4.0 với cache: 1 × 8k + 4 × 0 = 8k tokens
  - **Saving: ~80% với multi-feature trong cùng module**

---

## 6. Output schema v2.0 (G7)

### 6.1 impl-status.json v2.0

```json
{
  "schema_version": "2.0",
  "session_id": "2026-04-28-103045-laptop",
  "feature": { ... đã có ... },
  "scenario": "NEW",
  "session_number": 1,
  "phases": [ ... đã có ... ],
  "files_created": [ ... đã có ... ],
  "files_modified": [ ... đã có ... ],
  "tests_count": 24,
  "warnings": [ ... đã có (v3.4.0) ... ],

  "consumer_hints": {
    "wf-prepare-deployment": {
      "files_for_changelog": ["src/modules/crm/customer.service.ts", "..."],
      "breaking_changes": [],
      "migrations_required": false,
      "feature_summary_vi": "Triển khai chức năng Quản lý Khách hàng (CRUD)"
    },
    "wf-fix-bugs": {
      "scope_modules": ["crm/customer"],
      "test_files_added": ["tests/crm/customer.test.ts"],
      "decision_ids_new": ["D042","D043"],
      "implementation_strategy_used": "IMPLEMENT_NEW"
    },
    "wf-verify-sync": {
      "req_ids_completed": ["REQ-CRM-001","REQ-CRM-002"],
      "files_with_req_id": 12,
      "session_dir": ".mc-data/work/wf-implement-feature/customer-management/sessions/2026-04-28-103045-laptop"
    }
  },

  "profile": "standard",
  "cache_hits": {
    "existing_patterns": true,
    "saved_tokens_estimated": 8000
  }
}
```

### 6.2 Backward compat

- v1.0 schema (no schema_version field hoặc schema_version="1.0") vẫn được skill đọc.
- Khi PRIMARY skill update → bump lên v2.0.
- Consumer skills (wf-prepare-deployment etc.) check `schema_version` trước khi đọc consumer_hints.

---

## 7. Global decision registry (G9)

### 7.1 File location

`.mc-data/docs/_meta/decision-registry.global.json`

### 7.2 Schema

```json
{
  "schema_version": "1.0",
  "decisions": [
    {
      "id": "D-GLOBAL-001",
      "category": "data_modeling",
      "rule": "All deletions are soft delete (deleted_at column)",
      "reason": "Audit + recovery requirement",
      "scope": "project",
      "added_by": {
        "skill": "wf-implement-feature",
        "feature_slug": "customer-management",
        "session_id": "2026-04-28-103045-laptop",
        "timestamp": "2026-04-28T10:35:00Z"
      },
      "feature_specific_overrides": []
    }
  ]
}
```

### 7.3 Safe-write rules

- **Owner:** wf-implement-feature (PRIMARY) — đặc biệt Phase 3.5 (sau mỗi batch)
- **Mode:** APPEND-only (không modify existing decisions)
- **Conflict check:** Trước khi append, đọc existing decisions → check conflict (Protocol 12.2)
- **Mutex:** dùng cùng pattern `.decision-registry.lock` như _shared.md đã có

### 7.4 Phase 0.5 read flow

```
Step 0.5b.1: Read decision-registry.global.json (nếu tồn tại) → load all "scope: project" decisions
Step 0.5b.2: Read $SESSION_DIR/decision-registry.json (nếu --resume) → load feature-level
Step 0.5b.3: Merge: project_decisions + feature_decisions → $CONSTRAINT_LIST
Step 0.5b.4: Inject vào developer agent context (Phase 3)
```

---

## 8. Error ledger + namespaced codes (G5)

### 8.1 error-ledger.json schema

```json
{
  "schema_version": "1.0",
  "session_id": "2026-04-28-103045-laptop",
  "feature_slug": "customer-management",
  "errors": [
    {
      "code": "E101",
      "phase": "phase01-pattern-scan",
      "severity": "warning",
      "message": "Pattern cache miss — full scan triggered",
      "context": {"module": "crm", "git_sha": "abc1234"},
      "ts": "2026-04-28T10:35:00Z",
      "auto_resolved": true
    },
    {
      "code": "E301",
      "phase": "phase07-tdd",
      "severity": "error",
      "message": "Test gate failed after 2 auto-fix attempts",
      "context": {"batch": 2, "test_file": "customer.test.ts"},
      "ts": "2026-04-28T10:45:00Z",
      "auto_resolved": false,
      "escalated_to_user": true
    }
  ]
}
```

### 8.2 Namespace

| Range | Phase | Examples |
|-------|-------|----------|
| E1xx | Phase 1 (context, registry) | E101 (cache miss), E102 (registry inconsistent), E103 (req-id not found) |
| E2xx | Phase 2 (planning, populate-spec, contracts) | E201 (task file missing), E202 (A6-EXT stub detected) |
| E3xx | Phase 3 (TDD, test gate, decisions) | E301 (test gate fail), E302 (decision conflict) |
| E4xx | Phase 4 (review) | E401 (agent timeout), E402 (critical issues unfixed) |
| E5xx | Phase 5a (cross-validation) | E501 (validation auto-correction loop > 3) |
| E6xx | Phase 6 (registry write, finalize) | E601 (registry mutex timeout), E602 (POST-GATE T1-T4 fail) |
| E9xx | Cross-cutting | E901 (per-feature lock busy), E902 (history index append fail) |

### 8.3 Backward compat

`_shared.md §Error Codes Reference` thêm bảng alias:

| Old | New | Notes |
|-----|-----|-------|
| E001 | E101 | Missing feature/REQ-ID |
| E002 | E102 | Registry not found |
| E003 | E103 | Cannot determine feature |
| E004a | E202 | Feature design missing |
| E004b | E201 | Task file missing |
| E005 | E203 | Task list generation failed |
| E006 | E303 | Source file creation failed |
| E007 | E304 | REQ-ID missing |
| E008 | E301 | Tests failing |
| E009 | E402 | Critical/Security issues |
| E010 | E401 | Agent timeout |
| E011 | E602 | POST-GATE fail |
| E012 | E305 | Auto-fix regression |
| E013 | E901 | Session lifecycle (fresh) |
| E014 | E102 | Re-run without flag |

---

## 9. Cross-skill consumer flag `--from-impl`

### 9.1 Optional consumer pattern

Các skills KHÔNG cần modify default behavior. Chỉ thêm OPTIONAL flag:

| Skill | Flag | Đọc từ | Sử dụng |
|-------|------|--------|---------|
| `wf-prepare-deployment` | `--from-impl=$FEATURE_SLUG[@$SESSION_ID]` | impl-status.json.consumer_hints.wf-prepare-deployment | Auto-generate changelog, breaking changes, migrations |
| `wf-fix-bugs` | `--from-impl=$FEATURE_SLUG` | impl-status.json.consumer_hints.wf-fix-bugs | Focus fix scope vào features mới implement |
| `wf-verify-sync` | `--from-impl=$FEATURE_SLUG` | impl-status.json.consumer_hints.wf-verify-sync | Skip re-scan, dùng req_ids_completed list |

### 9.2 Resolution logic

```
IF --from-impl=$SLUG (no @SESSION):
  → Read $FEATURE_BASE_DIR/$SLUG/current.txt → resolve to active session
ELIF --from-impl=$SLUG@$SESSION:
  → Read $FEATURE_BASE_DIR/$SLUG/sessions/$SESSION/impl-status.json
ELSE:
  → Default behavior (no shortcut)
```

### 9.3 Schema_version check

```bash
SCHEMA_VER=$(jq -r '.schema_version // "1.0"' impl-status.json)
if [[ "$SCHEMA_VER" != "2.0" && "$SCHEMA_VER" != "2."* ]]; then
  echo "WARN: impl-status.json schema $SCHEMA_VER < 2.0 — consumer_hints không khả dụng. Falling back to default behavior."
  exit 0
fi
```

---

## 10. .gitignore conventions

```gitignore
# .gitignore (root project)

# Working state - per-machine, KHÔNG commit
.mc-data/work/wf-implement-feature/*/sessions/
.mc-data/work/wf-implement-feature/*/current.txt
.mc-data/work/wf-implement-feature/.locks/
.mc-data/work/wf-implement-feature/.cache/

# History index - CHECK-IN cho multi-dev visibility
!.mc-data/work/wf-implement-feature/.history/
!.mc-data/work/wf-implement-feature/.history/*.jsonl

# Multi-feature reports - CHECK-IN
!.mc-data/work/wf-implement-feature/multi-feature-report-*.md

# Archived sessions - CHECK-IN nếu user muốn (default ignore)
.mc-data/work/wf-implement-feature/*/archived/
```

---

## 11. CLAUDE.md §4b updates

Bổ sung 3 rows vào §4b Cross-Skill Output Path Contract:

```markdown
| `/wf-implement-feature` Phase 6 | `.mc-data/work/wf-implement-feature/{$FEATURE_SLUG}/sessions/{$SESSION_ID}/impl-status.json` (v2.0 schema với consumer_hints) | `/wf-prepare-deployment --from-impl` (optional), `/wf-fix-bugs --from-impl` (optional), `/wf-verify-sync --from-impl` (optional) |
| `/wf-implement-feature` Session-aware | `.mc-data/work/wf-implement-feature/{$FEATURE_SLUG}/.history/implementations-index.jsonl` | Audit trail (multi-dev), `/status` (read-only) |
| `/wf-implement-feature` Phase 3.5 | `.mc-data/docs/_meta/decision-registry.global.json` (APPEND-only) | All future implementations (cross-feature consistency) |
```

---

## 12. Verification matrix

| Component | Verify command | Expected output |
|-----------|---------------|-----------------|
| Session ID generated | `ls $FEATURE_DIR/sessions/` | At least 1 dir matching `{date}-{time}-{host}` pattern |
| current.txt pointer | `cat $FEATURE_DIR/current.txt` | `sessions/{id}` (relative path) |
| Bash script source | `bash -n $SCRIPT && source $SCRIPT && type normalize_slug` | Function defined |
| History index entry | `tail -1 .history/implementations-index.jsonl \| jq '.session_id'` | Matches active session |
| Pattern cache hit | `jq '.cache_hits.existing_patterns' impl-status.json` | `true` |
| Schema v2.0 | `jq -e '.schema_version == "2.0"' impl-status.json` | exit 0 |
| Global decisions | `jq '.decisions \| length' decision-registry.global.json` | > 0 sau ≥1 implementation |
| Error ledger created | `test -f error-ledger.json` | exit 0 (kể cả khi không có errors) |
| Profile applied | `jq '.profile' impl-status.json` | One of: quick/standard/deep/exhaustive |
| POST-GATE T1-T4 | `bash implement-postgate.sh --session-dir=... \| jq '.T1 and .T2 and .T3 and .T4'` | `true` |

---

## 13. Backward compat strategy

**Rule:** Không break v3.x clients.

| Component | v3.x behavior | v4.0 behavior | Migration |
|-----------|---------------|---------------|-----------|
| Path `$FEATURE_SLUG/foo.json` | Direct flat | Inside `sessions/{id}/` | Migration script (idempotent) |
| Resume | checkpoint.json + soft-resume fallback | current.txt → sessions/{id}/ | Detect old layout → use migration shim |
| Error codes E001-E014 | Flat | Aliased to E1xx-E9xx | _shared.md alias table |
| impl-status.json schema | v1.0 (implicit) | v2.0 with consumer_hints | Skill reads both, writes v2.0 |
| Decision registry | Per-feature only | Per-feature + global (additive) | Global is OPT-IN, tạo mới |
| Bash inline | All inline | 90% delegated | SKILL.md sources scripts; if scripts missing → fallback inline (defensive) |
