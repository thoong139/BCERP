# Phase 0: Existing Code Analysis (EXTEND/MODIFY only)

> Phân tích code patterns hiện có để đảm bảo consistency.
> **Bỏ qua nếu scenario = NEW** (không load file này).
>
> **Protocols tham chiếu:** Template Rule (CORE-031) — xem `_shared.md §Template Usage Rule`

**PRE-GATE:** `test "$SCENARIO" != "new"`

**📥 INPUT:** `src/` hoặc `apps/` — patterns, naming, structure hiện có

**📤 OUTPUT:** `$SESSION_DIR/existing-patterns.json` (template: `templates/existing-patterns.json`)

---

## Cache Strategy (v4.0+ Sprint 2)

Pattern scan tốn ~5-10K tokens/feature. Khi implement nhiều features cùng module trong 1 ngày → re-scan là waste. Cache với **dual invalidation** (CORE-023 — bảo thủ, ưu tiên correctness):

- **Cache file:** `.mc-data/work/wf-implement-feature/.cache/$SYSTEM_SLUG/$MODULE_SLUG/existing-patterns.$GIT_SHA.json`
- **Cache key:** `$MODULE_SLUG | $GIT_SHA` (8-char short)
- **TTL:** 24h (1440 phút)
- **Git invalidation:** hash của `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum` thay đổi → miss
- **Bypass:** flag `--no-cache` từ `$ARGUMENTS`

Cache file thêm 3 fields metadata: `invalidation_hash`, `module_path`, `scanned_at`. Validator: `implement-cache-resolver.sh --validate`.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Detect scenario từ design (đã biết từ Multi-Run Logic / argument flag) | Scenario set |
| 0.1a | **[v4.0 Cache Setup]** Compute `$MODULE_SLUG` từ feature.module field. Compute `$MODULE_PATH` (thường = `src/modules/$MODULE_SLUG` hoặc `apps/*/src/modules/$MODULE_SLUG`; fallback: tìm từ existing-patterns scan kết quả ở v3.x). Compute `$GIT_SHA = git rev-parse --short=8 HEAD 2>/dev/null \|\| echo "no-git"`. | `$MODULE_SLUG`, `$GIT_SHA` set |
| 0.1b | **[v4.0 Cache Lookup]** Set `CACHE_FILE=".mc-data/work/wf-implement-feature/.cache/$SYSTEM_SLUG/$MODULE_SLUG/existing-patterns.$GIT_SHA.json"`. <br>• IF `--no-cache` ∈ `$ARGUMENTS` → skip cache, set `$CACHE_HIT=false`, log INFO `"[CACHE] Bypassed via --no-cache"` → goto 0.2 (full scan). <br>• ELIF `$GIT_SHA == "no-git"` → skip cache (no git context), set `$CACHE_HIT=false` → goto 0.2. <br>• ELIF `test -f $CACHE_FILE`: <br>&nbsp;&nbsp;- Check TTL: `find $CACHE_FILE -mmin -1440` (24h). Nếu vượt → `$CACHE_HIT=false`, log INFO `"[CACHE] TTL expired"`, goto 0.2. <br>&nbsp;&nbsp;- Validate via `bash .claude/scripts/wf-implement-feature/implement-cache-resolver.sh --validate $CACHE_FILE`. Exit 0 = hash match → CACHE HIT. Exit non-0 → `$CACHE_HIT=false`, log INFO `"[CACHE] Git SHA hash mismatch (module changed)"`, goto 0.2. <br>• ELSE → cache file không tồn tại, `$CACHE_HIT=false` → goto 0.2. | `$CACHE_HIT` set |
| 0.1c | **[v4.0 Cache HIT path]** IF `$CACHE_HIT == true`: <br>• Copy `$CACHE_FILE` → `$SESSION_DIR/existing-patterns.json`. <br>• `source .claude/scripts/wf-implement-feature/implement-common.sh; trace_event "CACHE_HIT" "$FEATURE_SLUG" "$SESSION_ID" "{\"module\":\"$MODULE_SLUG\",\"git_sha\":\"$GIT_SHA\",\"saved_tokens_estimated\":8000}"`. <br>• Log INFO `"[CACHE] HIT — module=$MODULE_SLUG sha=$GIT_SHA, tiết kiệm ~8K tokens"`. <br>• Set `$SAVED_TOKENS_ESTIMATED=8000`. <br>• SKIP Steps 0.2-0.6 → goto POST-GATE. | existing-patterns.json present |
| 0.2 | Scan existing codebase bằng Glob + Grep (tìm entity, service, controller files) | Patterns found |
| 0.3 | Phân tích naming convention, file structure, code style (import aliases, decorator style, error handling patterns) | Analysis done |
| 0.4 | **[Template Rule]** READ `templates/existing-patterns.json` → xác định sections cần populate | Template loaded |
| 0.5 | Nếu scenario = MODIFY: populate `impact_analysis` section → `impact_analysis.enabled = true` | Impact filled |
| 0.6 | Populate template với analysis data → WRITE `$SESSION_DIR/existing-patterns.json` | `test -s $OUT` |
| 0.7 | **[v4.0 Cache WRITE]** IF `$CACHE_HIT == false` AND `$GIT_SHA != "no-git"`: <br>• Compute hash: `INVALIDATION_HASH=$(bash .claude/scripts/wf-implement-feature/implement-cache-resolver.sh --compute-hash $MODULE_PATH)`. <br>• `mkdir -p .mc-data/work/wf-implement-feature/.cache/$SYSTEM_SLUG/$MODULE_SLUG/`. <br>• Augment `$SESSION_DIR/existing-patterns.json` với 3 fields metadata: `invalidation_hash`, `module_path`, `scanned_at`. Atomic write. <br>• Copy file → `$CACHE_FILE`. <br>• `trace_event "CACHE_MISS" "$FEATURE_SLUG" "$SESSION_ID" "{\"module\":\"$MODULE_SLUG\",\"git_sha\":\"$GIT_SHA\",\"reason\":\"<TTL_expired\|hash_mismatch\|not_found>\"}"`. <br>• Log INFO `"[CACHE] WRITE — $CACHE_FILE saved cho module=$MODULE_SLUG sha=$GIT_SHA"`. | Cache file written, augmented metadata present |

**POST-GATE:** `test -s $SESSION_DIR/existing-patterns.json`

---

## State Variables (output)

| Variable | Value | Consumed by |
|----------|-------|-------------|
| `$CACHE_HIT` | `true` (cache used) hoặc `false` (full scan) | phase6-finalize (impl-status.json `cache_hits` field) |
| `$SAVED_TOKENS_ESTIMATED` | Integer (≥0); 8000 khi cache HIT, 0 khi MISS | phase6-finalize (impl-status.json `cache_hits.saved_tokens_estimated`) |
| `$MODULE_SLUG` | normalized module name | phase3 (developer agent context) |
| `$GIT_SHA` | short git SHA | impl-report.md audit trail |

---

## Notes

- Phase này chạy **trước** phase0-5-context-setup.md vì khi EXTEND/MODIFY, pattern analysis độc lập với LEGACY_MODE detection.
- Nếu scenario = NEW → SKILL.md orchestrator skip file này, nhảy thẳng sang `phase0-5-context-setup.md`.
- `existing-patterns.json` sẽ được Developer Agent đọc trong Phase 3 để viết code nhất quán với codebase hiện có.
- Cache scope: per-machine (`.cache/` gitignored), per-module + per-commit. Multi-dev không share cache (mỗi dev có cache riêng).
- Khi `$SCENARIO == "new"` (file này không load) → cache không liên quan; phase3 vẫn dùng patterns từ docs design.
