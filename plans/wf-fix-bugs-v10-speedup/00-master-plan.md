# Master Plan — Per-Task Detailed Specs

> Mỗi task có format chuẩn: **Mục đích → Files → Hiện trạng → Đề xuất → Acceptance Criteria → Guard Rails → Rollback → Effort**.
> Read this together với [`01-guard-rails.md`](01-guard-rails.md) và [`02-benchmark.md`](02-benchmark.md).

---

## WAVE 1 — Foundation (Low Risk, ~30% speedup)

### W1.1 — Phase 6 Wrapper De-duplicate CI Work

**Mục đích:** Loại bỏ redundant `gitnexus_impact` call ở Step 6.4 trong `phase6-execute.md` — wf-fix-execute Phase 3 batches sẽ làm CI-1 lại cho từng issue, nên Step 6.4 hiện đang DUPLICATE.

**Files affected:**
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute.md` (Steps 6.4)

**Hiện trạng (line 276-353):**
```bash
# Step 6.4: extract FIX_TARGETS từ fix-plan.md (head -20)
# FOR each target → call mcp__plugin_gitnexus_gitnexus__impact
# ≤20 CI calls × 3-5s = 60-100s overhead
```

**Đề xuất:**
1. **Step 6.4a:** Try-read `blast_radius[]` từ `issue-registry.json` (Phase 5 triage ADR-22 rule 2 đã enrich):
   ```bash
   BLAST_RADIUS_AVAILABLE=$(jq -e '.issues | all(has("blast_radius"))' "$SESSION_DIR/phase5-triage/issue-registry.json" 2>/dev/null && echo "true" || echo "false")
   ```
2. **Step 6.4b (FAST PATH — when BLAST_RADIUS_AVAILABLE=true):**
   - Aggregate HIGH/CRITICAL targets từ `blast_radius`:
     ```bash
     HIGH_RISK_TARGETS=$(jq -r '[.issues[] | select(.blast_radius.risk == "HIGH") | .target] | unique | .[]' "$SESSION_DIR/phase5-triage/issue-registry.json")
     CRITICAL_RISK_TARGETS=$(jq -r '[.issues[] | select(.blast_radius.risk == "CRITICAL") | .target] | unique | .[]' "$SESSION_DIR/phase5-triage/issue-registry.json")
     ```
   - SKIP gitnexus_impact calls (đã có data từ Phase 5).
3. **Step 6.4c (SLOW PATH — fallback when BLAST_RADIUS_AVAILABLE=false):**
   - Behavior cũ (chạy gitnexus_impact cho FIX_TARGETS) — giữ nguyên 100%.
4. **Step 6.4d:** CDG render & write `ci-impact-report.json` — IDENTICAL behavior cũ:
   ```json
   {
     "critical": "...",
     "high": "...",
     "targets_analyzed": N,
     "tool": "blast_radius_reused" | "gitnexus_fresh" | "grep_fallback",
     "fast_path_used": true | false
   }
   ```

**Acceptance Criteria:**
- [ ] Fast path: nếu `blast_radius` đầy đủ → 0 gitnexus_impact calls trong Step 6.4
- [ ] Slow path: nếu thiếu → behavior cũ KHÔNG đổi
- [ ] `ci-impact-report.json` schema identical (thêm field `fast_path_used` optional)
- [ ] CDG `AskUserQuestion` cảnh báo HIGH/CRITICAL vẫn được render
- [ ] POST-GATE T1-T4 cho Step 6.4 PASS
- [ ] Step 6.5 (spawn wf-fix-execute) nhận đúng context

**Guard Rails:**
- ✅ CDG CORE-027 (HIGH/CRITICAL warning) — preserved
- ✅ CI Tool Usage Logging — fast path log entry `{tool: "blast_radius_reused", source: "phase5_triage", fallback_used: false}`
- ✅ `ci-impact-report.json` cross-skill artifact contract — schema preserved
- ✅ Forensic PRE-GATE (CORE-011) — read content blast_radius, không chỉ check existence

**Rollback:** `git revert` commit Step 6.4 change → behavior cũ 100%. Không touch wf-fix-execute.

**Effort:** 1-2 giờ (đọc + sửa + smoke test).

---

### W1.2 — CI Impact Caching (Session-Tier)

**Mục đích:** Cache `gitnexus_impact` results trong session để tránh duplicate calls cho cùng symbol/file trong Phase 3 Batch 1/2/3 + Phase 5 Verify Loop iterations.

**Files affected:**
- New: `.claude/scripts/wf-fix-ci-cache.sh` (wrapper script)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch1.md` (CI PRE-GATE section)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch2.md` (CI PRE-GATE section)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch3.md` (CI PRE-GATE section)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase5-scan.md` (Step 5.1b Verify Ripple)
- Reuse: `.claude/skills/workflow/_shared/cache/cache_adapter.py` (đã có 2-tier cache)

**Hiện trạng:**
- Mỗi issue → 1 gitnexus_impact call (CI-1) ~3-5s
- N issues × 3 batches (Batch 1/2/3) + M iterations × Verify Loop = O(N×M) calls
- Profile exhaustive với 50 issues, 3 iterations → ~150-200 calls × 3s = 7-10 phút thuần CI overhead

**Đề xuất:**

**Bước 1 — Tạo helper `wf-fix-ci-cache.sh`:**
```bash
#!/usr/bin/env bash
# wf-fix-ci-cache.sh — session-tier cache wrapper cho gitnexus_impact
#
# Usage:
#   wf-fix-ci-cache.sh impact --session-dir <path> --target <symbol> --direction upstream
#
# Behavior:
#   1. Compute cache_key = "impact:{HEAD-sha}:{target}:{direction}"
#   2. Lookup cache_adapter.py (session-tier only — không persist)
#   3. HIT → return cached JSON + log {cache_hit: true, duration_ms ~10ms}
#   4. MISS → call mcp__plugin_gitnexus_gitnexus__impact, store result, return + log
#   5. Skip cache nếu $CI_FRESHNESS = severe (index stale)
#   6. Skip cache nếu $MCV3_FIX_CI_CACHE_DISABLED=1 (escape hatch)

set -euo pipefail
SESSION_DIR="$1"; TARGET="$2"; DIRECTION="${3:-upstream}"
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
CACHE_KEY="impact:${COMMIT_SHA}:${TARGET}:${DIRECTION}"
FRESHNESS=$(jq -r '.freshness_level // "unknown"' "$SESSION_DIR/ci-context.json" 2>/dev/null || echo "unknown")

# Escape hatch + freshness check
if [ "${MCV3_FIX_CI_CACHE_DISABLED:-0}" = "1" ] || [ "$FRESHNESS" = "severe" ]; then
  # Direct call — bypass cache
  RESULT=$(call_gitnexus_impact)
  log_ci_usage "$RESULT" "false" "bypass_${FRESHNESS}"
  echo "$RESULT"; exit 0
fi

# Cache lookup
CACHED=$(python -m _shared.cache.cache_adapter lookup --skill wf-fix-execute --key "$CACHE_KEY")
if [ -n "$CACHED" ]; then
  log_ci_usage "$CACHED" "true" "session_cache_hit"
  echo "$CACHED"; exit 0
fi

# Cache miss — fresh call
RESULT=$(call_gitnexus_impact)
python -m _shared.cache.cache_adapter store --skill wf-fix-execute --key "$CACHE_KEY" --value "$RESULT" --ttl session
log_ci_usage "$RESULT" "false" "session_cache_miss"
echo "$RESULT"
```

**Bước 2 — Sửa CI PRE-GATE trong phase3-batch{1,2,3}.md:**

Thay vì gọi `mcp__plugin_gitnexus_gitnexus__impact` trực tiếp, gọi qua wrapper:
```bash
# OLD (line ~20 of phase3-batch1.md CI-1):
IMPACT=$(mcp__plugin_gitnexus_gitnexus__impact "{\"target\": \"$symbol\", \"direction\": \"upstream\"}")

# NEW:
IMPACT=$(bash .claude/scripts/wf-fix-ci-cache.sh "$SESSION_DIR" "$symbol" "upstream")
```

**Bước 3 — fix-log.json entry format mới:**
```json
{
  "event": "CI_TOOL_USED",
  "task": "impact_analysis",
  "primary": "gitnexus_impact",
  "secondary": null,
  "fallback_used": false,
  "cache_hit": true,
  "cache_source": "session_tier",
  "duration_ms": 12,
  "result_count": 8,
  "freshness_behind_commits": 0,
  "freshness_level": "ok"
}
```

**Acceptance Criteria:**
- [ ] Cache hit rate ≥30% trên scenario có >10 issues touching ≤5 files
- [ ] Cache MISS → behavior identical với direct gitnexus_impact (same JSON output schema)
- [ ] `cache_hit` field present trong mọi CI_TOOL_USED log entry
- [ ] `MCV3_FIX_CI_CACHE_DISABLED=1` → bypass cache hoàn toàn (smoke test pass)
- [ ] Freshness=severe → bypass cache (smoke test pass)
- [ ] Verify Ripple (Phase 5.1b) cũng dùng cache (depth=1 cache reuse từ Phase 3)
- [ ] Cache key invalidation tự động khi commit-sha thay đổi

**Guard Rails:**
- ✅ CI Tool Usage Logging Protocol 20 §20.11 — `cache_hit` là extension field, không thay format chính
- ✅ Freshness severity check — không cache khi stale
- ✅ CDG cho HIGH/CRITICAL impact — data từ cache identical, vẫn trigger
- ✅ Session isolation — cache không leak cross-session

**Rollback:** `export MCV3_FIX_CI_CACHE_DISABLED=1` → mọi call bypass cache. Hoặc `git revert` helper script + procedure changes.

**Effort:** 4-6 giờ (helper script + 4 procedure files + smoke test cache adapter integration).

---

### W1.3 — POST-GATE T1-T4 Query Consolidation

**Mục đích:** Gộp nhiều `jq` subprocess calls trong POST-GATE thành 1 query với multiple selectors. Mỗi tier check vẫn output riêng để debug.

**Files affected:**
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute.md` (Step 6.6 POST-GATE T1-T4)
- `.claude/skills/workflow/wf-fix-execute/procedures/_shared.md` (POST-GATE template if exists)
- (Tùy chọn) `.claude/scripts/wf-fix-common.sh` (helper function `validate_post_gate_tiered`)

**Hiện trạng (phase6-execute.md line 452-462):**
```bash
T1_OK=false; T2_OK=false; T3_OK=false; T4_OK=false
test -s "..." && test -s "..." && T1_OK=true
grep -q "## " "..." && T2_OK=true
jq -e '.files_synced >= 0' "..." > /dev/null 2>&1 && T3_OK=true
grep -qP '(?i)(fixed|resolved|repaired|dry)' "..." && T4_OK=true
# 4 subprocess calls + 2 file reads
```

**Đề xuất:**

**Bước 1 — Tạo helper function trong `wf-fix-common.sh`:**
```bash
# wf-fix-common.sh
# validate_post_gate_tiered <fix_report> <docs_sync_report>
# Returns: 0 nếu PASS, 1 nếu FAIL. Echo: "T1=ok T2=ok T3=ok T4=ok"
validate_post_gate_tiered() {
  local fix_report="$1"
  local docs_sync="$2"
  local T1 T2 T3 T4

  # T1+T2: file checks
  if [ -s "$fix_report" ] && [ -s "$docs_sync" ]; then T1=ok; else T1=fail; fi
  if [ "$T1" = "ok" ] && grep -q "## " "$fix_report"; then T2=ok; else T2=fail; fi

  # T3+T4: single jq query for docs_sync, single grep for fix_report
  if jq -e '.files_synced >= 0' "$docs_sync" > /dev/null 2>&1; then T3=ok; else T3=fail; fi
  if grep -qP '(?i)(fixed|resolved|repaired|dry)' "$fix_report"; then T4=ok; else T4=fail; fi

  echo "T1=$T1 T2=$T2 T3=$T3 T4=$T4"
  [ "$T1$T2$T3$T4" = "okokokok" ]
}
```

**Bước 2 — Sửa Step 6.6 POST-GATE:**
```bash
# OLD: 4 separate variable assignments + concat string
# NEW: 1 function call
POST_GATE_RESULT=$(validate_post_gate_tiered \
  "$SESSION_DIR/phase6-execute/fix-report.md" \
  "$SESSION_DIR/phase6-execute/docs-sync-report.json")

if validate_post_gate_tiered "$SESSION_DIR/phase6-execute/fix-report.md" "$SESSION_DIR/phase6-execute/docs-sync-report.json"; then
  echo "POST-GATE T1-T4: PASS — $POST_GATE_RESULT"
else
  echo "POST-GATE FAIL: $POST_GATE_RESULT" >&2
  # Trigger retry / escalate (CORE-034 auto-fix budget)
fi
```

**Acceptance Criteria:**
- [ ] POST-GATE T1-T4 vẫn pass/fail đúng cho cùng input (parity với version cũ)
- [ ] Mỗi tier vẫn output rõ ràng (`T1=ok T2=ok ...`) để debug
- [ ] Subprocess count giảm ≥30% (đo bằng `strace -c` hoặc `time`)
- [ ] Logic AND vẫn enforce (1 tier fail → toàn bộ POST-GATE fail)

**Guard Rails:**
- ✅ POST-GATE T1-T4 CORE-012 — số tier không đổi, semantics không đổi
- ✅ Forensic PRE-GATE CORE-011 — vẫn check content depth, không chỉ existence
- ✅ Auto-fix budget CORE-034 — 1 tier fail vẫn trigger retry

**Rollback:** Revert helper function + Step 6.6 changes. Behavior cũ là 4 separate jq/grep — không có dependency.

**Effort:** 1-2 giờ.

---

### W1.4 — Benchmark Wave 1 + Verify Guard Rails

**Mục đích:** Đo speedup thực tế của Wave 1 trên scenario có ý nghĩa, verify mọi guard rail vẫn enforce.

**Files affected:**
- `tools/integration-test.py` — chọn scenario G hoặc H (lớn nhất)
- New: `plans/wf-fix-bugs-v10-speedup/benchmarks/wave1-{date}.md`

**Methodology:** Xem chi tiết trong [`02-benchmark.md`](02-benchmark.md).

**Acceptance Criteria:**
- [ ] Speedup measured ≥25% (target Wave 1)
- [ ] POST-GATE T1-T4 PASS cho mọi phase 1-7
- [ ] CDG render đúng khi HIGH/CRITICAL impact
- [ ] CQG hard-enforce PASS (tolerance ≤5%)
- [ ] Spot-check Protocol 17 enforce ≥1 lần khi agent spawn
- [ ] CI Tool Usage log entries có `cache_hit` field
- [ ] No regression — fixed_count + deferred_count + failed_count tổng bằng baseline

**Rollback:** Không applicable — benchmark only.

**Effort:** 2-3 giờ (run baseline + run optimized + analyze).

---

## WAVE 2 — Parallel Execution (Medium Risk, +15-20% speedup)

### W2.1 — Playwright Parallel Routes (Max 4 Contexts)

**Mục đích:** Trong Phase 5.14 Playwright verify, mở nhiều browser contexts trong 1 instance để navigate routes parallel (max 4) thay vì sequential. Auth-required routes vẫn sequential để tránh race condition token.

**Files affected:**
- `.claude/skills/workflow/_shared/playwright-session.js` (multi-context support)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase5-scan.md` (Step 5.14)
- (Tùy chọn) New: `.claude/scripts/pw-parallel-routes.sh` wrapper

**Hiện trạng (phase5-scan.md Step 5.14, ~line 84):**
```
FOR EACH route: pw_navigate → pw_console → pw_snapshot → pw_click
# 10 routes × 4 ops × ~3s = 2-3 phút
```

**Đề xuất:**

**Bước 1 — Extend `playwright-session.js`:**
```javascript
// Add new commands:
// pw_navigate_parallel <route1> <route2> ... — opens N contexts, navigates parallel
// pw_console_per_context <context_id> — collect console per context
// pw_close_context <context_id> — close specific context

// Implementation:
const browser = await chromium.launch({...});
const contexts = await Promise.all(routes.map(() => browser.newContext()));
const pages = await Promise.all(contexts.map(ctx => ctx.newPage()));
await Promise.all(pages.map((page, idx) => page.goto(routes[idx], { waitUntil: 'networkidle' })));
// Capture per-context console + screenshot + snapshot
```

**Bước 2 — Sửa Step 5.14 trong phase5-scan.md:**
```bash
# Detect auth-required routes (those với 'auth' / 'login' / 'profile' / 'admin' patterns)
AUTH_ROUTES=$(jq -r '.[] | select(test("/auth/|/login|/admin|/profile"))' <<< "$ROUTES_TO_VERIFY")
PUBLIC_ROUTES=$(jq -r '.[] | select(test("/auth/|/login|/admin|/profile") | not)' <<< "$ROUTES_TO_VERIFY")

# Parallel public routes (max 4 contexts)
echo "$PUBLIC_ROUTES" | xargs -n4 pw_navigate_parallel
# Sequential auth routes
for route in $AUTH_ROUTES; do
  pw_navigate "$APP_URL$route" "networkidle"
  pw_console > "$SESSION_DIR/phase5-verify/evidence/console-$(slugify "$route").txt"
  pw_snapshot > "$SESSION_DIR/phase5-verify/evidence/snapshot-$(slugify "$route").yml"
done
```

**Acceptance Criteria:**
- [ ] Phase 5.14 thời gian giảm ≥40% với ≥8 public routes
- [ ] Mỗi route vẫn capture console errors + snapshot + screenshot riêng biệt
- [ ] Auth-required routes vẫn sequential (verify bằng log timestamps)
- [ ] No browser crash trên project medium (10 routes, 4-core machine)
- [ ] Evidence files per route đầy đủ (không bị mix giữa contexts)

**Guard Rails:**
- ✅ Phase 5.14 evidence collection — preserved per-route
- ✅ Console error / network error detection — vẫn trigger nếu có
- ✅ E013 (navigate fail) / E017 (auth required) — handle nguyên vẹn
- ✅ playwright_verify object trong fix-status.json — schema không đổi

**Rollback:** Set env `MCV3_PW_MAX_CONTEXTS=1` → sequential như cũ. Hoặc revert procedure + JS extension.

**Effort:** 4-6 giờ (JS extension + procedure update + smoke test multi-context).

---

### W2.2 — Batch 1 CRITICAL Sub-Parallel (Dependency-Aware)

**Mục đích:** Batch 1 hiện sequential vì sợ dependency. Cải tiến: phân tích `files_modified` + `target_symbols` để detect issues KHÔNG overlap → spawn parallel max LPM_PARAMS (3-5).

**Files affected:**
- `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch1.md`
- New: `.claude/scripts/wf-fix-dep-graph.sh` (analyze issue dependency)
- `.claude/skills/workflow/wf-fix-execute/_shared.md` (Developer Selection — add dep-graph)

**Hiện trạng (phase3-batch1.md line 79-86):**
```
| 3.1.1  | Spawn developer agent ... | Agent spawned |
| 3.1.2  | Agent fix compile/type errors | Errors fixed |
# Sequential, 1 agent at a time
```

**Đề xuất:**

**Bước 1 — Tạo `wf-fix-dep-graph.sh`:**
```bash
#!/usr/bin/env bash
# wf-fix-dep-graph.sh — build dependency groups từ CRITICAL issues
#
# Input:  $SESSION_DIR/issue-registry.json (filtered: severity=CRITICAL)
# Output: $SESSION_DIR/phase3-batch1/dep-groups.json
#         Format: { "groups": [["issue_id_1", "issue_id_2"], ["issue_id_3"], ...] }
#                 Issues trong cùng group có file/symbol overlap → sequential
#                 Issues khác group → parallel-safe

set -euo pipefail
SESSION_DIR="$1"
ISSUES_JSON="$SESSION_DIR/issue-registry.json"

# Build adjacency from files_modified + target.symbol
python3 <<EOF
import json
from collections import defaultdict

with open("$ISSUES_JSON") as f:
    data = json.load(f)

critical = [i for i in data["issues"] if i.get("severity") == "CRITICAL"]

# Build adjacency: 2 issues overlap if share any file OR symbol
def overlap(i1, i2):
    files1 = set(i1.get("files_modified") or [i1.get("location", {}).get("file", "")])
    files2 = set(i2.get("files_modified") or [i2.get("location", {}).get("file", "")])
    if files1 & files2: return True
    sym1 = i1.get("target", {}).get("symbol")
    sym2 = i2.get("target", {}).get("symbol")
    if sym1 and sym2 and sym1 == sym2: return True
    return False

# Union-find groups
parent = {i["issue_id"]: i["issue_id"] for i in critical}
def find(x):
    while parent[x] != x: x = parent[x]
    return x
def union(x, y):
    px, py = find(x), find(y)
    if px != py: parent[px] = py

for i1 in critical:
    for i2 in critical:
        if i1["issue_id"] < i2["issue_id"] and overlap(i1, i2):
            union(i1["issue_id"], i2["issue_id"])

groups_map = defaultdict(list)
for iid in parent:
    groups_map[find(iid)].append(iid)

result = {"groups": list(groups_map.values()), "total_critical": len(critical), "total_groups": len(groups_map)}
print(json.dumps(result, indent=2))
EOF
```

**Bước 2 — Sửa phase3-batch1.md Step 3.1.1:**
```
| 3.1.0  | **Build dep-graph:** Run wf-fix-dep-graph.sh. IF total_groups == total_critical → no overlap (fully parallel). IF total_groups == 1 → fully sequential. ELSE → mixed. | dep-groups.json created |
| 3.1.1  | Spawn developer agents PER GROUP (run_in_background): max $MAX_PARALLEL_AGENTS (LPM=3, standard=5). Mỗi group nội bộ vẫn sequential (1 agent xử lý tuần tự issues trong group). | Agents spawned per group |
| 3.1.2  | Wait ALL agents complete → CORE-029 spot-check per group | Spot-check PASS |
| 3.1.3  | Verify: tsc --noEmit hoặc equivalent | Zero compile errors |
| 3.1.4  | Update data + fix-status.json | POST-GATE pass |
```

**Acceptance Criteria:**
- [ ] CRITICAL issues KHÔNG overlap (different files + symbols) → spawn parallel max LPM
- [ ] CRITICAL issues overlap → sequential trong cùng group
- [ ] No 2 agents ghi cùng file (verify bằng git log: mỗi file 1 commit/agent)
- [ ] Spot-check Protocol 17 vẫn enforce per agent
- [ ] POST-GATE per sub-batch (per group) PASS
- [ ] Speedup ≥40% khi N=10 CRITICAL, 2-3 groups

**Guard Rails:**
- ✅ Scope Boundary Rule — mỗi agent vẫn check `$TARGET_DIRS`
- ✅ CORE-025 Safe parallelization — owner rõ ràng (1 agent/group), write scope tách biệt
- ✅ CORE-029 Spot-check per agent
- ✅ Symbolic editing preference (Serena replace_symbol_body) — không thay đổi
- ✅ CI-1/CI-2/CI-3 vẫn run per issue (qua cache W1.2)

**Rollback:** `dep-groups.json` always có `{groups: [[all_critical]]}` (1 group all) → sequential như cũ. Hoặc set env `MCV3_FIX_BATCH1_PARALLEL_DISABLED=1`.

**Effort:** 4-6 giờ (dep-graph script + procedure update + smoke test với scenario có CRITICAL overlap).

---

### W2.3 — Benchmark Wave 2 + Verify No Race Conditions

Tương tự W1.4. Bổ sung verify:
- [ ] `git log --since=<phase3 start>` — mỗi file chỉ có 1 modification path
- [ ] No file conflict in `fix-log.json` entries
- [ ] Browser context isolation — console errors không leak giữa contexts

---

## WAVE 3 — Smart Skip & Aggregation (Medium Risk, +15-20% speedup)

### W3.1 — Verify Loop Smart Rescan (Iter 2+ Delta)

**Mục đích:** Iteration 2+ trong Verify Loop chỉ rescan `recently_modified_files` từ fix-log iter trước, thay vì full $TARGET_DIRS. Iter 1 và iter cuối LUÔN full scan để bảo toàn regression detection cross-module.

**Files affected:**
- `.claude/skills/workflow/wf-fix-execute/procedures/phase5-scan.md` (Step 5.1 Full regression preflight)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase5-loop.md` (VERIFY_RESCAN, Step 5.19)

**Hiện trạng (phase5-scan.md Step 5.1):**
```
5.1 | **Full regression preflight:** Chay lai wf-preflight voi FULL scope ($TARGET_DIRS), khong phai scoped. Bat regression moi module.
```
Trong Verify Loop max 3 iterations → 3× full preflight = ~5-10 phút overhead.

**Đề xuất:**

**Bước 1 — Sửa Step 5.1 phase5-scan.md:**
```bash
# Detect iteration phase
ITERATION=$(jq -r '.phases.phase_5.loop_state.current_iteration' fix-status.json)
MAX_ITERATIONS=3
IS_FIRST=$([ "$ITERATION" -eq 1 ] && echo true || echo false)
IS_LAST_LIKELY=$([ "$ITERATION" -ge "$((MAX_ITERATIONS - 1))" ] && echo true || echo false)

# Determine scope
if $IS_FIRST || $IS_LAST_LIKELY; then
  SCAN_SCOPE="$TARGET_DIRS"
  SCAN_MODE="full"
else
  # Iter 2 (middle iteration) — delta scan
  RECENT_FILES=$(jq -r "[.entries[] | select(.iteration == $((ITERATION - 1))) | .files_modified[]] | unique | .[]" fix-log.json)
  SCAN_SCOPE="$RECENT_FILES"
  SCAN_MODE="delta"
fi

# Run preflight with chosen scope
wf-preflight --scope "$SCAN_SCOPE" --mode "$SCAN_MODE" > "$SESSION_DIR/phase5-verify/preflight-iter$ITERATION.json"
```

**Bước 2 — Sửa Step 5.19 phase5-loop.md (VERIFY_RESCAN):**
```
5.19 | **Re-run regression scan:** Quay lai VERIFY_INIT, tang iteration. SCAN_MODE = full (iter 1 & cuối) | delta (iter giữa). Trong delta mode: thêm "Note: delta scan — full rescan sẽ chạy ở iter cuối" vào loop_state.iteration_history. | scan completed, mode logged |
```

**Acceptance Criteria:**
- [ ] Iter 1 LUÔN full scan (verify log: `scan_mode=full`)
- [ ] Iter 2 (middle): delta scan trên `recently_modified_files` từ iter 1 fix-log
- [ ] Iter 3 (last, nếu reach): LUÔN full scan (cross-module regression detection)
- [ ] Iter 4 (override case): LUÔN full scan
- [ ] `phases.phase_5.loop_state.iteration_history[]` có field `scan_mode`
- [ ] Speedup ≥30% cho Verify Loop khi N issues touch ≤30% of $TARGET_DIRS

**Guard Rails:**
- ✅ Cross-module regression detection — iter cuối luôn full
- ✅ Issue-level verification (Step 5.1a) — vẫn enforce cho mọi iter
- ✅ playwright_verify Step 5.14 — không thay đổi (route-level, không phụ thuộc scan scope)
- ✅ CDG-EXEC-04 — vẫn trigger nếu HIGH remaining

**Rollback:** Set env `MCV3_FIX_VERIFY_DELTA_DISABLED=1` → mọi iter full scan như cũ.

**Effort:** 3-4 giờ (logic update + smoke test với forced regression scenario).

---

### W3.2 — CI Batching Per File (Group Issues → 1 Impact/File)

**Mục đích:** Hiện tại Phase 3 batches gọi CI-1 cho từng issue. Tối ưu: gom issues theo `files_modified` → 1 `gitnexus_impact` call per file. Đặc biệt hiệu quả khi nhiều issues cùng file.

**Files affected:**
- New: `.claude/scripts/wf-fix-ci-batch.sh` (group + call)
- `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch{1,2,3}.md` (CI PRE-GATE section)

**Hiện trạng:** 1 issue → 1 CI-1 call. 5 issues cùng `src/auth/login.ts` → 5 calls cùng symbol.

**Đề xuất:**

**Bước 1 — Tạo `wf-fix-ci-batch.sh`:**
```bash
#!/usr/bin/env bash
# wf-fix-ci-batch.sh — group issues by file, call impact 1×/file
#
# Input:  $SESSION_DIR + batch_number + severity_filter
# Output: $SESSION_DIR/phase3-batch{N}/ci-batch-{severity}.json
#         Format: { "files": { "src/foo.ts": { "impact": {...}, "issues": ["ID1", "ID2"] } } }

set -euo pipefail
SESSION_DIR="$1"; BATCH="$2"; SEVERITY="$3"
ISSUES_JSON="$SESSION_DIR/issue-registry.json"

# Group issues by primary file
GROUPS=$(jq -r --arg sev "$SEVERITY" '
  [.issues[] | select(.severity == $sev)] |
  group_by(.location.file // .files_modified[0] // "unknown") |
  map({file: .[0].location.file, issue_ids: [.[].issue_id]})
' "$ISSUES_JSON")

# For each file, call gitnexus_impact (via cache W1.2)
echo "$GROUPS" | jq -c '.[]' | while read -r group; do
  FILE=$(echo "$group" | jq -r '.file')
  ISSUE_IDS=$(echo "$group" | jq -c '.issue_ids')
  IMPACT=$(bash .claude/scripts/wf-fix-ci-cache.sh "$SESSION_DIR" "$FILE" "upstream")
  # Append to ci-batch JSON
  echo "{\"file\": \"$FILE\", \"impact\": $IMPACT, \"issue_ids\": $ISSUE_IDS}"
done | jq -s '.' > "$SESSION_DIR/phase3-batch$BATCH/ci-batch-$SEVERITY.json"
```

**Bước 2 — Sửa CI PRE-GATE trong phase3-batch{1,2,3}.md:**
```bash
# OLD: per-issue CI-1 call
# NEW: 1 batch call before iterating issues
bash .claude/scripts/wf-fix-ci-batch.sh "$SESSION_DIR" "1" "CRITICAL"

# Then for each issue, lookup pre-computed impact:
for issue in $CRITICAL_ISSUES; do
  IMPACT=$(jq -r --arg id "$issue" '.[] | select(.issue_ids | index($id)) | .impact' "$SESSION_DIR/phase3-batch1/ci-batch-CRITICAL.json")
  # ... proceed with fix
  # LOG: 1 CI_TOOL_USED entry per issue với reference parent file impact
  log_ci_usage "$IMPACT" "true" "batch_lookup" "parent_file=$FILE_OF_ISSUE"
done
```

**Acceptance Criteria:**
- [ ] Khi 5 issues cùng file → 1 gitnexus_impact call (5× → 1×)
- [ ] Mỗi issue vẫn có 1 CI_TOOL_USED log entry với `source=batch_lookup` + `parent_file`
- [ ] Cache W1.2 hoạt động song song (batch_lookup tăng cache hit)
- [ ] CDG cảnh báo HIGH/CRITICAL vẫn trigger per file (không per issue)

**Guard Rails:**
- ✅ CI Tool Usage Logging — 1 entry/issue, không bỏ bước log
- ✅ CDG HIGH/CRITICAL — render đúng (theo file, không miss)
- ✅ Cache W1.2 integration — batch lookup ưu tiên cache

**Rollback:** Set env `MCV3_FIX_CI_BATCH_DISABLED=1` → fall back per-issue calls.

**Effort:** 3-4 giờ. **Phụ thuộc W1.2** (cache đã có).

---

### W3.3 — Spot-Check Pattern Cache (LRU 50)

**Mục đích:** Trong CORE-029 spot-check, agent output có pattern lặp lại (cùng agent_type + cùng issue_pattern → output schema tương tự). Cache pattern recognition để skip phần này. Scope+file existence LUÔN chạy.

**Files affected:**
- `.claude/skills/workflow/wf-fix-execute/procedures/_shared.md` (§Agent Output Spot-Check)
- (Tùy chọn) New: `.claude/skills/workflow/_shared/spot_check_cache.py`

**Hiện trạng (_shared.md line 498-521):**
4 checks per agent output: schema, file existence, scope, content sanity.

**Đề xuất:**
```python
# spot_check_cache.py
# LRU max 50 entries, key = (agent_type, issue_signal_type, issue_severity)
# Value = {schema_pattern_validated: True, validated_at: timestamp}

class SpotCheckCache:
    MAX_SIZE = 50
    def __init__(self): self.cache = OrderedDict()

    def pattern_seen(self, agent_type, signal_type, severity):
        key = (agent_type, signal_type, severity)
        if key in self.cache:
            self.cache.move_to_end(key)
            return self.cache[key]
        return None

    def remember(self, agent_type, signal_type, severity, result):
        key = (agent_type, signal_type, severity)
        if len(self.cache) >= self.MAX_SIZE:
            self.cache.popitem(last=False)
        self.cache[key] = result
```

**Sửa _shared.md Spot-Check quy trình:**
```
FOR each agent_output:
  1. SCHEMA CHECK:
     - IF cache.pattern_seen(agent_type, signal_type, severity) → SKIP schema, use cached result
     - ELSE: run full schema check, cache result
  2. FILE EXISTENCE CHECK: LUÔN CHẠY (never cached)
  3. SCOPE CHECK: LUÔN CHẠY (never cached)
  4. CONTENT SANITY CHECK: LUÔN CHẠY (never cached — agent-specific output)
  5. RESULT: PASS only nếu all 4 pass
```

**Acceptance Criteria:**
- [ ] Pattern cache HIT khi cùng (agent_type, signal_type, severity) seen ≥2 times
- [ ] File existence + Scope + Content checks LUÔN chạy
- [ ] Cache size ≤ 50 (verify via inspector function)
- [ ] CORE-029 enforce — không vi phạm Protocol 17

**Guard Rails:**
- ✅ CORE-029 Protocol 17 — 3/4 checks luôn chạy, schema cache có invalidation
- ✅ Auto-fix trigger ERROR case — vẫn enforce (re-spawn agent max 3)

**Rollback:** Set env `MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1` → mọi check chạy fresh.

**Effort:** 2-3 giờ.

---

### W3.4 — Final Benchmark + CHANGELOG + Version Bump

**Files affected:**
- `CHANGELOG.md` (root)
- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (version 10.0.1 → 10.1.0)
- `.claude/skills/workflow/wf-fix-bugs/_contract.json` (version bump)
- `.claude/skills/workflow/wf-fix-execute/SKILL.md` (version 3.7.0 → 3.8.0)
- `.claude/skills/workflow/wf-fix-execute/_contract.json` (version bump)
- `plans/wf-fix-bugs-v10-speedup/benchmarks/final-{date}.md`

**Methodology:** Same as W1.4 + W2.3, full pipeline exhaustive profile.

**Acceptance Criteria:**
- [ ] Total speedup ≥50% on chosen scenario
- [ ] All POST-GATE T1-T4 PASS
- [ ] All CDG render correctly
- [ ] CQG hard-enforce PASS
- [ ] No regression in fixed/deferred/failed counts
- [ ] CHANGELOG entry added với speedup numbers
- [ ] Version bumped trong SKILL.md + _contract.json

**Effort:** 3-4 giờ.

---

## Tổng Effort Estimate

| Wave | Tasks | Hours |
|------|-------|-------|
| W1 | 1.1, 1.2, 1.3, 1.4 | 8-13 |
| W2 | 2.1, 2.2, 2.3 | 10-15 |
| W3 | 3.1, 3.2, 3.3, 3.4 | 11-15 |
| **Total** | 11 tasks | **29-43 giờ** |

> Có thể split thành 3-4 session (10-12 giờ/session) qua multi-session với `--resume`.

---

## Cross-References

- Guard rails detail: [`01-guard-rails.md`](01-guard-rails.md)
- Benchmark methodology: [`02-benchmark.md`](02-benchmark.md)
- Progress tracking: [`progress.md`](progress.md)
