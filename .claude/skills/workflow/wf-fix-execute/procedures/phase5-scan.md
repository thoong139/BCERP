# Phase 5 SCAN: INIT + Full Regression + Content Quality + Playwright

> Day la phase dau tien cua state machine Phase 5 — chuan bi scope va chay full regression scan.
> Steps 5.0-5.15. Sau khi hoan thanh → chuyen `phase5-loop.md` (VERIFY_EVALUATE).

> **Protocol:** Xem `.claude/skills/protocols/` — Auto-Correction Loop Protocol (MAX_ITERATIONS = 3)
> **Data sources:** `$SESSION_DIR/issue-registry.json`, `$SESSION_DIR/fix-log.json`, `$SESSION_DIR/fix-status.json`

**PRE-GATE:** Phase 3 + Phase 4 completed.

---

## State Machine Architecture (tong quan)

```
VERIFY_INIT → VERIFY_SCAN → VERIFY_EVALUATE
                                    ↓
                              VERIFY_FINAL (PASS)
                                    ↓
                              VERIFY_FIX → VERIFY_DOCS → VERIFY_RESCAN → VERIFY_EVALUATE
                                    ↑                                                    |
                                    └────────── iteration < MAX_ITERATIONS ───────────────┘

VERIFY_EVALUATE → VERIFY_FINAL (FAIL — iteration >= MAX_ITERATIONS, CRITICAL remain)
```

> **Backward compatible:** Neu `issue-registry.json` khong ton tai (pre-v2.0 session) → chay legacy mode (inline verify, khong state machine). Neu ton tai → chay state machine.

**Phan cong file:**
- Phase 5 SCAN (file nay) — VERIFY_INIT + VERIFY_SCAN (steps 5.0-5.15)
- [`phase5-loop.md`](phase5-loop.md) — VERIFY_EVALUATE + VERIFY_FIX + VERIFY_DOCS + VERIFY_RESCAN (steps 5.16-5.19)
- [`phase5-final.md`](phase5-final.md) — VERIFY_FINAL (step 5.20)

---

## VERIFY_INIT — Prepare Verification Scope

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.0  | **Load structured data:** READ `$SESSION_DIR/issue-registry.json`. Build `$VERIFY_SCOPE`: (a) `fixed_issues[]` — issues WHERE `status == "fixed"` (verify fix con ton tai). (b) `all_issues[]` — TAT CA issues (full regression, khong chi fixed). READ `$SESSION_DIR/fix-log.json` — build `$ROUTES_TO_VERIFY` tu `entries[].route_map` (flattened, deduped). **Shared code detection:** FOR each entry WHERE `files_modified` chua path trong `shared/`, `packages/`, `libs/` → ADD ALL routes tu `fix-status.json.scope.app_routes` vao `$ROUTES_TO_VERIFY`. SET `iteration = phases.phase_5.loop_state.current_iteration` (resume support). | Scope built, routes resolved |
| 5.0a | **BAT BUOC — VERIFY_INIT la OWNER DUY NHAT cua `current_iteration += 1`:** Update fix-status.json theo spec "Phase 5 LOOP START" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract): `loop_state.current_iteration += 1` (moi lan enter VERIFY_INIT — ca first run lan moi RESCAN loop-back), `loop_state.state = "VERIFY_INIT"`, `iterations_run = [current]`, APPEND entry vao `iteration_history[]`. **Rationale:** VERIFY_FIX va VERIFY_RESCAN KHONG duoc tu tang iteration — chi VERIFY_INIT tang. Moi RESCAN (5.19) phai quay lai VERIFY_INIT (5.0-5.0a) truoc khi SCAN. | `jq '.phases.phase_5.loop_state.current_iteration > 0' $SESSION_DIR/fix-status.json` |

---

## VERIFY_SCAN — Full Regression Scan

> **THAY DOI CHINH:** Step 5.1 chay FULL scan trong `$TARGET_SCOPE`, khong phai "scope hep chi check items da fix".
> Day la thay doi quan trong nhat — bat regression cross-module.

| Check | Action | Verify |
| ----- | ------ | ------ |
| 5.1   | **Smart regression preflight (W3.1 plan v10-speedup):** Detect iteration mode (full vs delta) — xem §Smart Rescan Logic ben duoi. Chay wf-preflight voi scope da chon. Bat regression. | Score captured, scan_mode logged |
| 5.1a  | **Issue-level verification:** FOR each issue trong issue-registry.json WHERE `status == "fixed"`: (a) Verify file con ton tai (`test -f`). (b) Neu issue co line number → grep content tai line do, kiem tra fix van con. (c) Neu fix da bi revert hoac new error tai cung location → SET `status = "regression"`, `verify.regression_of = issue_id`. FOR each issue WHERE `status == "discovered"` (chua fix) → include trong remaining count. **CHAY CHO MOI iteration (full + delta) — khong phu thuoc scan_mode.** | Regressions detected |
| 5.1b  | **Verify Ripple (ADR-22 rule 2):** xem §Verify Ripple ben duoi | Downstream dependents scanned |

### Smart Rescan Logic (Step 5.1 detail — W3.1 plan v10-speedup)

> **Muc dich:** Iter 1 va iter cuoi LUON full scan de bao toan cross-module regression
> detection. Iter giua (middle iteration) chay delta scan tren `recently_modified_files`
> UNION cross-module dependents (qua GitNexus depth=1 downstream cache lookup).
> Zero quality loss vi cross-module regression van duoc bao toan qua dependency graph.

```bash
# 1. Detect iteration mode
ITERATION=$(jq -r '.phases.phase_5.loop_state.current_iteration' "$SESSION_DIR/fix-status.json")
MAX_ITERATIONS=3

# IS_FIRST: iter 1 luon full scan (baseline cho moi regression sau nay)
# IS_LAST_LIKELY: iter >= MAX-1 → full scan (final safety net cross-module)
if [ "$ITERATION" -le 1 ]; then
  IS_FIRST=true
else
  IS_FIRST=false
fi
if [ "$ITERATION" -ge "$((MAX_ITERATIONS - 1))" ]; then
  IS_LAST_LIKELY=true
else
  IS_LAST_LIKELY=false
fi

# 2. Escape hatch — neu user disable delta → moi iter full scan nhu cu
if [ "${MCV3_FIX_VERIFY_DELTA_DISABLED:-0}" = "1" ]; then
  IS_FIRST=true  # force full scan
fi

# 3. Determine scope + mode
if [ "$IS_FIRST" = "true" ] || [ "$IS_LAST_LIKELY" = "true" ]; then
  # FULL scan — iter 1 hoac iter cuoi (cross-module regression detection critical)
  SCAN_SCOPE="$TARGET_DIRS"
  SCAN_MODE="full"
else
  # DELTA scan — iter giua (middle iteration, e.g., iter 2 khi MAX=3)
  # Recently modified files tu iter truoc
  PREV_ITER=$((ITERATION - 1))
  RECENT=$(jq -r --argjson pi "$PREV_ITER" \
    '[.entries[] | select(.iteration == $pi) | .files_modified[]?] | unique | .[]' \
    "$SESSION_DIR/fix-log.json" 2>/dev/null | sort -u)

  # Enhanced safety — ADD cross-module dependents via GitNexus (depth=1 downstream)
  # qua cache wrapper W1.2. Neu cache MISS (lookup exit 1) hoac GitNexus unavailable
  # → graceful degradation: CROSS_DEPS empty, fall back delta-only (RECENT files).
  CROSS_DEPS=""
  if [ "${GITNEXUS_AVAILABLE:-false}" = "true" ]; then
    for f in $RECENT; do
      # Lookup downstream dependents tu session cache (populated boi Phase 3 batches)
      DEP_JSON=$(bash .claude/scripts/wf-fix-ci-cache.sh lookup \
        "$SESSION_DIR" "$f" "downstream" 2>/dev/null || true)
      if [ -n "$DEP_JSON" ]; then
        # Extract file paths tu impact JSON (.targets[].file_path hoac .impacted_symbols[].file)
        DEP_FILES=$(printf '%s' "$DEP_JSON" | jq -r '
          if type == "object" then
            (.impacted_symbols // .targets // .affected // .nodes // []) |
            map(.file // .file_path // .path // empty) | .[]
          else empty end
        ' 2>/dev/null | sort -u)
        CROSS_DEPS="$CROSS_DEPS $DEP_FILES"
      fi
    done
    CROSS_DEPS=$(printf '%s\n' $CROSS_DEPS | sort -u | grep -v '^$' || true)
  fi
  # Neu GitNexus unavailable hoac cache MISS hoan toan → CROSS_DEPS=empty (graceful)

  SCAN_SCOPE=$(printf '%s\n' $RECENT $CROSS_DEPS | sort -u | grep -v '^$' | tr '\n' ' ')
  SCAN_MODE="delta"

  # Safety net: neu delta scope rong (khong co files modified) → fall back full
  if [ -z "$(printf '%s' "$SCAN_SCOPE" | tr -d ' ')" ]; then
    SCAN_SCOPE="$TARGET_DIRS"
    SCAN_MODE="full"  # fallback an toan
  fi
fi

# 4. Run preflight voi scope da chon
bash .claude/skills/workflow/wf-preflight/SKILL.md \
  --scope "$SCAN_SCOPE" \
  --mode "$SCAN_MODE" \
  > "$SESSION_DIR/phase5-verify/preflight-iter${ITERATION}.json" 2>&1 || true

# 5. Log scan_mode vao loop_state.iteration_history[] (atomic write)
TMP="$SESSION_DIR/fix-status.json.tmp.$$"
jq --argjson iter "$ITERATION" --arg mode "$SCAN_MODE" \
  '.phases.phase_5.loop_state.iteration_history |=
    (map(if .iteration == $iter then . + {scan_mode: $mode} else . end))' \
  "$SESSION_DIR/fix-status.json" > "$TMP" \
  && jq -e '.' "$TMP" > /dev/null \
  && mv "$TMP" "$SESSION_DIR/fix-status.json" \
  || rm -f "$TMP"
```

**Khi nao dung full vs delta:**

| Iteration | Mode | Ly do |
|-----------|------|-------|
| 1 (first) | `full` | Baseline — moi regression sau nay so voi diem nay |
| 2 (middle) | `delta` | Toi uu: chi rescan files iter 1 fix + cross-module dependents (depth=1) |
| 3 (last, MAX) | `full` | Final safety net — bao toan cross-module regression detection |
| 4 (override iter, neu CDG approve) | `full` | Absolute max — luon full |

**Quality preservation:**
- Iter 1 + iter cuoi LUON full → cross-module regression detection KHONG bi mat.
- Iter giua delta + cross-module dependents (qua GitNexus depth=1) → bao toan ripple detection.
- Step 5.1a issue-level verification CHAY MOI iter (mode-independent).
- Step 5.14 playwright_verify CHAY MOI iter (route-level, khong phu thuoc scan scope).
- Escape hatch `MCV3_FIX_VERIFY_DELTA_DISABLED=1` → moi iter full scan nhu cu.
- Graceful degradation: GitNexus unavailable → CROSS_DEPS empty, delta-only (RECENT files).
- Safety net: delta scope rong → fall back full (tranh skip preflight).
| 5.2   | So sanh preflight score truoc/sau | Score >= truoc |
| 5.3   | Chay tests (neu `--run-tests` hoac tests da duoc chay o Phase 3) | Tests pass |
| 5.4   | Verify REQ-ID comments trong files da fix | REQ-IDs present |
| 5.5   | Verify docs updated nhat quan voi code | Docs consistent |
| 5.6   | Spawn `reality-checker` agent cho final check | Reality check PASS |

---

## Content Quality Check (Protocol 8)

| Check | Action | Verify |
| ----- | ------ | ------ |
| 5.7   | **fixed_count accuracy:** So sanh `fixed_count` voi so luong files THUC SU modify (git diff hoac file timestamps) | fixed_count == actual |
| 5.8   | **escalated_count accuracy:** So sanh `escalated_count` voi `jq '[.issues[] \| select(.status=="escalated")] \| length' issue-registry.json` | Count match |
| 5.9   | **Score delta validation:** `score_after - score_before` PHAI >= 0. Neu negative → co regression | Delta >= 0 |
| 5.10  | **Completeness (issue ID tracking):** `jq -r '.issues[] \| select(.status != "fixed" and .status != "skipped") \| .issue_id' issue-registry.json` — moi non-fixed issue_id PHAI xuat hien trong report. Exact ID matching, khong content comparison. | All issues accounted |
| 5.11  | **Runtime re-verify:** Dung `pw_navigate` + `pw_console` + `pw_network` (bash-level `playwright-session.js`) navigate lai cac pages co runtime issues da fix. Check console + network errors. So sanh count truoc/sau | Error count giam |
| 5.12  | **Button re-test:** Dung `pw_click` re-click cac buttons da fix, `pw_snapshot` verify response | Buttons functional |
| 5.13  | **Skip preflight comparison neu `--browser-only`:** Neu `flags.browser_only == true` → bo qua 5.1-5.4. Van chay 5.5-5.12. Set `preflight.score_before = null`, `preflight.score_after = null` | browser-only check |

---

## Post-fix Playwright Verification (Step 5.14)

**BAT BUOC khi `flags.no_browser == false` VA `issues.fixed > 0`.**

Dung `$ROUTES_TO_VERIFY` tu step 5.0 (co san tu fix-log.json route_map + shared code detection — KHONG can ad-hoc derive).
Browser tools: Bash-level `playwright-session.js` CLI qua `pw_*` wrappers (xem QD9 `_shared.md`).

> **W2.1 (plan wf-fix-bugs-v10-speedup):** Public routes navigate **PARALLEL max 4 contexts/instance**
> qua `pw_navigate_parallel`. Auth-required routes (`/auth/...`, `/login`, `/admin`, `/profile`)
> van **SEQUENTIAL** de tranh race condition token. Escape hatch: `export MCV3_PW_MAX_CONTEXTS=1` → mois route sequential nhu cu.

**Quy trinh:**
1. `pw_launch` — acquire browser session. `trap "pw_close" EXIT`.
2. `pw_navigate "$APP_URL" "networkidle"` (timeout 15s via playwright-session.js) — root smoke.

3. **Phan loai routes (auth detect regex):**
   ```bash
   AUTH_RE='/auth/|/login|/admin|/profile'
   AUTH_ROUTES=$(printf '%s\n' "${ROUTES_TO_VERIFY[@]}" | grep -E "$AUTH_RE" || true)
   PUBLIC_ROUTES=$(printf '%s\n' "${ROUTES_TO_VERIFY[@]}" | grep -vE "$AUTH_RE" || true)
   EVIDENCE_DIR="$SESSION_DIR/phase5-verify/evidence"
   mkdir -p "$EVIDENCE_DIR"
   ```

4. **Public routes — PARALLEL (max MCV3_PW_MAX_CONTEXTS=4):**
   ```bash
   if [ -n "$PUBLIC_ROUTES" ]; then
     ROUTES_JSON=$(printf '%s\n' $PUBLIC_ROUTES | jq -R . | jq -c -s .)
     node .claude/skills/workflow/_shared/playwright-session.js \
       --session-dir="$SESSION_DIR" \
       --action=navigate_parallel \
       --routes-json="$ROUTES_JSON" \
       --base-url="$APP_URL" \
       --evidence-dir="$EVIDENCE_DIR" \
       --wait-until=networkidle \
       --timeout=15000 \
       > "$SESSION_DIR/phase5-verify/parallel-results.json"

     # Parse aggregate counts
     PUB_OK=$(jq '[.results[] | select(.status == "ok")] | length' \
       "$SESSION_DIR/phase5-verify/parallel-results.json")
     PUB_CONSOLE_ERRS=$(jq '[.results[].console_errors] | add // 0' \
       "$SESSION_DIR/phase5-verify/parallel-results.json")
     PUB_NET_FAILS=$(jq '[.results[].network_failures] | add // 0' \
       "$SESSION_DIR/phase5-verify/parallel-results.json")

     # Cleanup contexts (idempotent — actionNavigateParallel da auto-close)
     node .claude/skills/workflow/_shared/playwright-session.js \
       --session-dir="$SESSION_DIR" \
       --action=close_context --close-all=true > /dev/null 2>&1 || true
   fi
   ```
   Evidence per route da duoc ghi tu dong vao `$EVIDENCE_DIR`:
   - `console-{slug}.txt` — console errors + page errors + network failures
   - `snapshot-{slug}.yml` — accessibility tree + DOM counts
   - `screenshot-{slug}.png` — full-page screenshot (skip neu navigate fail)

5. **Auth routes — SEQUENTIAL (giu nguyen logic cu, single shared context):**
   ```bash
   for route in $AUTH_ROUTES; do
     SLUG=$(echo "$route" | sed 's:[^a-zA-Z0-9]:-:g; s:^-*::; s:-*$::' | tr '[:upper:]' '[:lower:]')
     pw_navigate "$APP_URL$route" "networkidle"   # E013/E017 handle nguyen ven
     pw_console > "$EVIDENCE_DIR/console-$SLUG.txt"
     pw_snapshot > "$EVIDENCE_DIR/snapshot-$SLUG.yml"
     pw_screenshot "$EVIDENCE_DIR/screenshot-$SLUG.png"
     pw_click "[data-testid='primary-cta']" 2>/dev/null || true  # re-test fixed CTAs (best effort)
   done
   ```
   - NEU navigate THAT BAI (E013) → LOG warning, skip gracefully (giu nguyen)
   - NEU auth required (E017) → ap dung 4-giai-doan auto-login giong Step 1c.0a (giu nguyen)

6. NEU co E2E test files → `npx playwright test` (test runner, khong phai MCP) → capture results

7. **Ghi vao `fix-status.json` (schema giu nguyen — chi them field debug optional):**
   ```
   phases.phase_5.playwright_verify = {
     attempted, pages_checked, new_console_errors,
     e2e_tests_run, e2e_tests_passed, e2e_tests_failed,
     parallel_mode: ("parallel" neu MCV3_PW_MAX_CONTEXTS != 1 va co public routes else "sequential"),
     public_routes_count, auth_routes_count
   }
   ```
   `pages_checked = PUB_OK + so auth routes thanh cong`
   `new_console_errors = PUB_CONSOLE_ERRS + so console errors tu auth routes`

8. NEU `new_console_errors > 0` HOAC `e2e_tests_failed > 0` → them vao issue-registry.json voi `status = "regression"` cho auto-correction loop. Max 5 items moi — nhieu hon → ESCALATE.

**Verify:**
- `jq '.phases.phase_5.playwright_verify != null' $SESSION_DIR/fix-status.json`
- Per-route evidence: FOR each route trong $ROUTES_TO_VERIFY, kiem tra `test -s "$EVIDENCE_DIR/console-$SLUG.txt"` va `test -s "$EVIDENCE_DIR/snapshot-$SLUG.yml"`
- Khong mix giua contexts: moi `console-{slug}.txt` chi chua errors cua chinh route do (verify boi context isolation trong actionNavigateParallel)

---

## e2e-results.json Handling (Step 5.14b)

> **Ownership contract (dong bo voi wf-fix-bugs/_contract.json):**
> - `wf-fix-bugs` Lane Dispatch = **INIT owner** (CREATE file voi flow results khi co E2E flow chay).
> - `wf-fix-execute` Phase 5 verify = **UPDATE owner** (APPEND verify iterations vao file da ton tai).
> - **wf-fix-execute KHONG bao gio CREATE e2e-results.json** — tuan thu CORE-007 cross-skill contract.

**Logic 3 nhanh:**

```
E2E_FILE = "$SESSION_DIR/e2e-results.json"

IF test -f "$E2E_FILE" (wf-fix-bugs Lane Dispatch da tao):
  # NHANH 1: UPDATE (append verify iteration results)
  - READ $E2E_FILE
  - APPEND verify results per route + per test cua iteration hien tai vao field `verify_iterations[]`
    (schema: { iteration: N, attempted_at, pages_checked, new_console_errors,
               e2e_tests_run, e2e_tests_passed, e2e_tests_failed, per_route_results[] })
  - WRITE atomic
  - SET `fix-status.json.phases.phase_5.playwright_verify.e2e_results_file = $E2E_FILE`

ELIF flags.full_test == true OR project co E2E test files:
  # NHANH 2: File khong ton tai nhung dieu kien thoa → chi ghi summary vao playwright_verify
  # KHONG tu CREATE (tranh conflict voi wf-fix-bugs orchestrator contract)
  - LOG: "e2e-results.json khong ton tai — wf-fix-bugs Lane Dispatch da bi skip/fail.
          Ghi summary vao playwright_verify, KHONG tu CREATE file de giu ownership contract."
  - SET `fix-status.json.phases.phase_5.playwright_verify = { attempted: true,
          pages_checked: N, new_console_errors: N, e2e_tests_run: N,
          e2e_tests_passed: N, e2e_tests_failed: N, e2e_results_file: null,
          e2e_init_status: "skipped_or_failed" }`

ELSE:
  # NHANH 3: Khong thoa dieu kien → chi ghi summary playwright_verify voi e2e_tests_run=0
  - SET `fix-status.json.phases.phase_5.playwright_verify = { attempted: true,
          pages_checked: N, new_console_errors: N, e2e_tests_run: 0,
          e2e_tests_passed: 0, e2e_tests_failed: 0, e2e_results_file: null }`
```

**E2E detection helper:**
```bash
E2E_FILES=$(find . -type f \( \
  -path "*/e2e/*" -o -path "*/__e2e__/*" -o -path "*/playwright/*" \
  -o -name "*.e2e.ts" -o -name "*.e2e.js" -o -name "*.spec.e2e.*" \
  -o -name "*.e2e.spec.ts" -o -name "*.e2e.spec.js" \) \
  2>/dev/null | wc -l)
test "$E2E_FILES" -gt "0"
```

> **Phase 6 consumer:** `phase6-report.md` §E2E Section Rendering chon render chi tiet (read file) hay render summary (chi doc `playwright_verify`) dua tren gia tri `e2e_results_file`.

---

## E2E Test Discovery + Smart Route Matching (Step 5.14c)

**BẮT BUỘC khi:** `flags.no_browser == false` AND `issues.fixed > 0`
**PRE-GATE:** Step 5.0 đã build `$ROUTES_TO_VERIFY`; Step 5.14 đã chạy navigate verify.
**Skip khi:** không derive được module slugs HOẶC không tìm thấy spec files.

> **Reuses from:**
> - Step 5.0 `$ROUTES_TO_VERIFY` — route list đã build từ `fix-log.json.route_map` + shared code detection (KHÔNG tính lại)
> - Step 5.14b E2E detection `find` helper — extend patterns (không thay thế)
> - `wf-fix-common.sh:with_runtime_cap` (line 134) — timeout guard cho `npx playwright test`
>
> **CI-ROUTE:** N/A cho file discovery (pure file pattern matching). `npx playwright test` cho execution.

### S1 — Extract module slugs từ changed routes

Routes trong `$ROUTES_TO_VERIFY` (e.g., `/crm/dashboard`, `/quotation/list`) → first non-trivial path segment = module slug.

```bash
# Reuse $ROUTES_TO_VERIFY đã build ở Step 5.0 — KHÔNG tính lại
ROUTES_JSON=$(jq '.phases.phase_5.routes_to_verify // []' $SESSION_DIR/fix-status.json 2>/dev/null)
if [ -z "$ROUTES_JSON" ] || [ "$ROUTES_JSON" = "[]" ]; then
  # Fallback: derive trực tiếp từ fix-log.json (khi Step 5.0 chưa persist routes)
  ROUTES_JSON=$(jq '[.entries[].route_map[]] | unique' $SESSION_DIR/fix-log.json 2>/dev/null || echo "[]")
fi

# First non-trivial segment (skip: api, v1, v2, public, static, assets, auth, login, logout)
SKIP_RE='^(api|v1|v2|v3|public|static|assets|_next|__next|auth|login|logout|_|favicon)$'
MODULE_SLUGS=$(echo "$ROUTES_JSON" | jq -r '.[] |
  split("/") |
  map(select(length > 0 and (test("'"$SKIP_RE"'") | not))) |
  .[0] // empty' | tr -d '\r' | sort -u | head -10)

# Also extract slugs từ files_modified path depth 3-4 (apps/erp-web/src/crm/ → crm)
FILE_SLUGS=$(jq -r '[.entries[].files_modified[]? |
  split("/") |
  map(select(length > 0 and (. != "src" and . != "app" and . != "pages" and
    . != "components" and . != "views" and . != "modules" and . != "lib" and
    . != "utils" and . != "hooks" and . != "types" and . != "styles"))) |
  .[3]? // .[2]? // empty] | unique | .[]' $SESSION_DIR/fix-log.json 2>/dev/null | tr -d '\r' | head -10)

ALL_SLUGS=$(printf "%s\n%s\n" "$MODULE_SLUGS" "$FILE_SLUGS" | tr -d '\r' | sort -u | grep -v '^$' | head -15)

if [ -z "$ALL_SLUGS" ]; then
  LOG "5.14c SKIP: Không derive được module slugs từ routes/files"
  jq '.phases.phase_5.playwright_verify.e2e_discovery = {
    status: "skipped", reason: "no_module_slugs", discovered: 0, matched_count: 0, matched_specs: []
  }' $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
  && mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
  # exit step gracefully — tiếp tục Step 5.15
fi
```

### S2 — Discover E2E spec files trong target project

```bash
TARGET_DIR="${PROJECT_ROOT:-$SOURCE_DIR}"

# Extended discovery (extends helper từ Step 5.14b — thêm broad *.spec.ts pattern)
E2E_SPEC_FILES=$(find "$TARGET_DIR" -type f \( \
  -path "*/e2e/*.spec.ts"  -o -path "*/e2e/*.spec.js"  \
  -o -path "*/e2e/*.test.ts" -o -path "*/e2e/*.test.js" \
  -o -path "*/__e2e__/*.ts" -o -path "*/__e2e__/*.js"  \
  -o -path "*/playwright/tests/*.ts"                    \
  -o -name "*.e2e.ts"       -o -name "*.e2e.js"         \
  -o -name "*.e2e.spec.ts"  -o -name "*.e2e.spec.js"    \
\) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

E2E_DISCOVERED=$(echo "$E2E_SPEC_FILES" | grep -c . 2>/dev/null || echo 0)

if [ "$E2E_DISCOVERED" -eq 0 ]; then
  LOG "5.14c SKIP: Không tìm thấy E2E spec files trong $TARGET_DIR"
  jq '.phases.phase_5.playwright_verify.e2e_discovery = {
    status: "skipped", reason: "no_spec_files_found", discovered: 0, matched_count: 0, matched_specs: []
  }' $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
  && mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
  # exit step gracefully — tiếp tục Step 5.15
fi
```

### THINK — Match slugs → spec files (naming convention)

Convention: `crm-customers.spec.ts` → slug `crm`; `e2e/crm/*.spec.ts` → slug `crm`.

```bash
MATCHED_SPECS=()
for SLUG in $ALL_SLUGS; do
  SLUG_LOWER=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  # Match: /${slug}[-/.], /${slug}/, or ${slug}[-_] in filename
  MATCHES=$(echo "$E2E_SPEC_FILES" | grep -i \
    -e "/${SLUG_LOWER}[-/.]" \
    -e "/${SLUG_LOWER}\." \
    -e "/${SLUG_LOWER}/" \
    -e "[/-]${SLUG_LOWER}[._-]" | head -5)
  if [ -n "$MATCHES" ]; then
    while IFS= read -r MATCH_FILE; do
      MATCHED_SPECS+=("$MATCH_FILE")
    done <<< "$MATCHES"
  fi
done

# Dedup + limit max 20
MATCHED_SPECS=($(printf "%s\n" "${MATCHED_SPECS[@]}" | sort -u | head -20))
MATCHED_COUNT=${#MATCHED_SPECS[@]}

if [ "$MATCHED_COUNT" -eq 0 ]; then
  LOG "5.14c WARN: Không match spec files với slugs [$ALL_SLUGS] — bỏ qua subset run (không chạy full suite)"
  SLUGS_JSON=$(printf '%s\n' $ALL_SLUGS | jq -R . | jq -s .)
  jq --argjson slugs "$SLUGS_JSON" --argjson disc "$E2E_DISCOVERED" \
     '.phases.phase_5.playwright_verify.e2e_discovery = {
       status: "no_match", module_slugs: $slugs, discovered: $disc, matched_count: 0, matched_specs: []
     }' $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
  && mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
  # Graceful exit — KHÔNG run full suite (tránh 121 tests)
fi
```

### ACT — Run matched subset

```bash
# Find playwright config
PW_CONFIG=$(find "$TARGET_DIR" -name "playwright.config.ts" -o -name "playwright.config.js" \
  -not -path "*/node_modules/*" 2>/dev/null | head -1)
PW_CONFIG_ARG=${PW_CONFIG:+--config "$PW_CONFIG"}

PLAYWRIGHT_JSON_OUT="/tmp/pw-e2e-$$.json"

# Run subset (with_runtime_cap 300s = 5 phút max — từ wf-fix-common.sh:134)
with_runtime_cap 300 bash -c "
  cd \"$TARGET_DIR\" && \
  npx playwright test $(printf '"%s" ' "${MATCHED_SPECS[@]}") \
    $PW_CONFIG_ARG --reporter=json 2>&1
" > "$PLAYWRIGHT_JSON_OUT" 2>&1
PW_EXIT=$?

# Parse Playwright JSON reporter output
E2E_PASSED=$(jq '.stats.expected // 0' "$PLAYWRIGHT_JSON_OUT" 2>/dev/null || echo 0)
E2E_UNEXPECTED=$(jq '.stats.unexpected // 0' "$PLAYWRIGHT_JSON_OUT" 2>/dev/null || echo 0)
E2E_RUN=$((E2E_PASSED + E2E_UNEXPECTED))

# Failed test titles (max 5 cho issue-registry)
FAILED_TESTS=$(jq -r '[.suites[].suites[]?.specs[]? | select(.ok == false) | .title] | .[0:5] | .[]' \
  "$PLAYWRIGHT_JSON_OUT" 2>/dev/null || echo "")
```

### UPDATE fix-status.json

```bash
SLUGS_JSON=$(printf '%s\n' $ALL_SLUGS | jq -R . | jq -s .)
SPECS_JSON=$(printf '%s\n' "${MATCHED_SPECS[@]}" | jq -R . | jq -s .)

jq --argjson slugs "$SLUGS_JSON" \
   --argjson matched_specs "$SPECS_JSON" \
   --argjson disc "$E2E_DISCOVERED" \
   --argjson matched "$MATCHED_COUNT" \
   --argjson run "$E2E_RUN" \
   --argjson passed "$E2E_PASSED" \
   --argjson failed "$E2E_UNEXPECTED" \
   '.phases.phase_5.playwright_verify |= . + {
     e2e_discovery: {
       status: "completed",
       module_slugs: $slugs,
       discovered: ($disc | tonumber),
       matched_count: ($matched | tonumber),
       matched_specs: $matched_specs
     },
     e2e_tests_run: ($run | tonumber),
     e2e_tests_passed: ($passed | tonumber),
     e2e_tests_failed: ($failed | tonumber)
   }' $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
&& mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
```

### REGRESSION HANDLING

NEU `E2E_UNEXPECTED > 0` → thêm vào `issue-registry.json` (cùng pattern Step 5.14):

```bash
REGRESSION_COUNT=0
while IFS= read -r FAILED_TEST && [ $REGRESSION_COUNT -lt 5 ]; do
  [ -z "$FAILED_TEST" ] && continue
  jq --arg test_name "$FAILED_TEST" --arg iter "$ITER" \
     --argjson rc "$REGRESSION_COUNT" \
     '.issues += [{
       id: ("ISSUE-E2E-" + $iter + "-" + ($rc | tostring)),
       type: "e2e_test_failure",
       source: "phase_5_14c_e2e_match",
       description: ("E2E test thất bại: " + $test_name),
       severity: "HIGH",
       fixability: "AGENT_FIX",
       dimensions: ["QD9"],
       evidence: { probe: "P5.14C.E2E" },
       status: "regression",
       iteration: ($iter | tonumber)
     }]' $SESSION_DIR/issue-registry.json > $SESSION_DIR/issue-registry.json.tmp \
  && mv $SESSION_DIR/issue-registry.json.tmp $SESSION_DIR/issue-registry.json
  REGRESSION_COUNT=$((REGRESSION_COUNT + 1))
done <<< "$FAILED_TESTS"

if [ "$E2E_UNEXPECTED" -gt 5 ]; then
  LOG "5.14c ESCALATE: $E2E_UNEXPECTED E2E failures > threshold → max 5 đã thêm vào issue-registry"
fi
```

**Verify:** `jq '.phases.phase_5.playwright_verify.e2e_discovery != null' $SESSION_DIR/fix-status.json`

---

## Test Record Cleanup (Step 5.15)

**BAT BUOC khi `flags.test_destructive == true` hoac `flags.full_test == true`.**

```
FOR each record IN fix-status.json.test_records WHERE status == "active":
  (a) Thu DELETE via API
  (b) Neu API fail: navigate → tim delete button → click → confirm
  (c) Update status = "cleaned_up" hoac "cleanup_failed"
```

**Verify:** No active test records.

---

## LLM Regression Probe — Post-Fix Second Invocation (Step 5.14f)

**BAT BUOC khi `flags.llm_scan == true` VA `issues.fixed > 0`.**
**PRE-GATE:** Phase 3 completed (fixes applied). Phase 5 regression checks completed (5.1-5.15).

### Trigger
Chi chay khi `--llm-scan` da duoc su dung trong Phase 1 Lane Dispatch.
```bash
LLM_SCAN_ACTIVE=$(jq -r '.flags.llm_scan // false' $SESSION_DIR/fix-status.json)
FIXED_COUNT=$(jq -r '.fix_summary.fixed // 0' $SESSION_DIR/fix-status.json)
if [ "$LLM_SCAN_ACTIVE" != "true" ] || [ "$FIXED_COUNT" = "0" ]; then
  LOG "5.14f SKIP: llm_scan=$LLM_SCAN_ACTIVE, fixed=$FIXED_COUNT"
  jq '.phases.phase_5.llm_regression_verify = { attempted: false, reason: "skip_condition" }' \
     $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
  && mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
  # exit step gracefully
fi
```

### Procedure (only when trigger satisfied)

1. **Load fix context:** READ `$SESSION_DIR/fix-log.json` — lay entries tu current iteration.
2. **Invoke P-LLM-regression-verify:**
   Spawn sub-agent `llm-probe-regression` (CORE-037: sub-agent tự xử lý prompting, không cần prompt file ngoài):
   - `$SESSION_DIR/fix-log.json` (fixes da apply trong session nay)
   - `git diff HEAD~N..HEAD` (tat ca changes tu session start)
   - `$SESSION_DIR/issue-registry.json` (de cross-ref original bugs)
3. **Parse signals:** Agent tra ve signals.json schema `lane-signals-v1`
4. **Threshold guard:**
   - ≤3 CRITICAL/HIGH signals → APPEND vao `issue-registry.json` voi `source="P-LLM-regression-verify"`
   - >3 CRITICAL/HIGH → ESCALATE + block POST-GATE

### UPDATE fix-status.json
```bash
SIGNALS_FOUND=$(jq '.signals | length' $TMP_SIGNALS 2>/dev/null || echo 0)
CRITICAL=$(jq '[.signals[] | select(.severity == "CRITICAL")] | length' $TMP_SIGNALS 2>/dev/null || echo 0)
HIGH=$(jq '[.signals[] | select(.severity == "HIGH")] | length' $TMP_SIGNALS 2>/dev/null || echo 0)

jq --argjson found "$SIGNALS_FOUND" --argjson crit "$CRITICAL" --argjson hi "$HIGH" \
   '.phases.phase_5.llm_regression_verify = {
     attempted: true,
     signals_found: $found,
     critical: $crit,
     high: $hi,
     status: (if $crit > 3 then "escalated" else "ok" end)
   }' $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
&& mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
```

### Error handling
| Code | Condition | Action |
|------|-----------|--------|
| E_LLM_TIMEOUT | Agent khong respond trong 300s | SKIP, LOG warning |
| E_LLM_REG_PARSE_FAIL | Agent output khong parse duoc | SKIP, LOG, mark `llm_regression_verify.status="parse_failed"` |

---

## Verify Ripple (Step 5.1b — ADR-22 rule 2, ADR-18)

> Goal: Sau khi fix file F, KHONG duoc gioi thieu regression tai cac file downstream phu thuoc F
> (depth=1, strength >= 0.5) theo Impact Graph. Day la complement cua "full regression scan" — focus vao
> cac dependents cua FILES DA FIX.

### Input

- `$SESSION_DIR/impact-graph.json` (tu wf-fix-bugs Lane Dispatch — probe QD1/QD2, schema `impact-graph.v1`)
- `$SESSION_DIR/fix-log.json` (entries[].files_modified — cac file da sua o Phase 3)
- `$SESSION_DIR/issue-registry.json` (de append ripple regressions neu phat hien)

### PRE-CHECK

```bash
# Impact graph la BAT BUOC — neu thieu va flags.no_browser==false → ERROR, fail Phase 5
if [ ! -s "$SESSION_DIR/impact-graph.json" ]; then
  echo "E_RIPPLE_NO_GRAPH: impact-graph.json khong ton tai. Lane Dispatch (wf-fix-bugs Phase 0-2) chua chay hoac da bi skip."
  # LPM minimal mode fallback: neu --lpm-minimal → skip Verify Ripple + LOG warning, khong fail
  if jq -e '.flags.lpm_minimal == true' $SESSION_DIR/fix-status.json > /dev/null 2>&1; then
    echo "RIPPLE SKIP (LPM minimal mode)"
    jq '.phases.phase_5.ripple_verify = { attempted: false, reason: "lpm_minimal", skipped: true }' \
       $SESSION_DIR/fix-status.json > $SESSION_DIR/fix-status.json.tmp \
       && mv $SESSION_DIR/fix-status.json.tmp $SESSION_DIR/fix-status.json
  else
    exit 1
  fi
fi

# Schema check (forensic — Protocol 10.4)
jq -e '."$schema" == "impact-graph.v1" and (.nodes | type) == "array" and (.edges | type) == "array"' \
   $SESSION_DIR/impact-graph.json > /dev/null \
  || { echo "E_RIPPLE_BAD_SCHEMA"; exit 1; }
```

### Procedure

```
1. Collect $FIXED_FILES[] tu fix-log.json:
   FIXED_FILES=$(jq -r '[.entries[] | select(.iteration == '"$ITER"') | .files_modified[]] | unique | .[]' \
                   $SESSION_DIR/fix-log.json)
   # NOTE: $ITER = current_iteration (tu VERIFY_INIT 5.0a)

2. FOR each $FILE in $FIXED_FILES:
     2a. Goi verify_ripple() qua Python import (preferred) hoac CLI fallback.
         Ca 2 cach deu emit JSON co key `.targets[]` (ADR-22 rule 2 — dong nhat schema).

         # Preferred — Python import (neu repo co module _shared).
         # Kwarg "impact_graph_path" tuan thu public API trong _shared/impact_graph/ripple.py
         python3 -c "
         from _shared.impact_graph.ripple import verify_ripple
         from dataclasses import asdict
         import json
         targets = verify_ripple(
             issue={'id': 'RIPPLE-VERIFY', 'file_path': '$FILE'},
             impact_graph_path='$SESSION_DIR/impact-graph.json',
             depth=1,
             strength_threshold=0.5,
         )
         print(json.dumps({'origin': '$FILE', 'target_count': len(targets),
                           'targets': [asdict(t) for t in targets]}))
         " > /tmp/ripple-$FILE.json

         # Fallback CLI (neu khong import duoc module _shared):
         # CLI yeu cau issue JSON file thay vi --file — tao tmp issue stub truoc.
         printf '{"id":"RIPPLE-VERIFY","file_path":"%s"}' "$FILE" > /tmp/ripple-issue.json
         python3 -m _shared.impact_graph.ripple verify \
            --issue /tmp/ripple-issue.json \
            --graph "$SESSION_DIR/impact-graph.json" \
            --depth 1 \
            --strength 0.5 > /tmp/ripple-$FILE.json
         # CLI payload: {origin, depth, strength_threshold, target_count, targets[]}

     2b. Parse ket qua (key `.targets[]` trong ca 2 flow):
         DOWNSTREAM=$(jq -r '.targets[] | .file_path' /tmp/ripple-$FILE.json)
         FOR each $DEP_FILE in $DOWNSTREAM:
           # Chay linter/typechecker/compile check cho $DEP_FILE
           if ! verify_file_still_compiles_and_lints "$DEP_FILE"; then
             # Co regression do ripple — APPEND vao issue-registry.json
             jq --arg f "$DEP_FILE" --arg src "$FILE" --arg iter "$ITER" \
               '.issues += [{
                  id: ("ISSUE-RIPPLE-" + $f + "-iter" + $iter),
                  type: "ripple_regression",
                  source: "verify_ripple",
                  file: $f,
                  description: ("Ripple regression: fix o " + $src + " gay loi tai " + $f),
                  severity: "HIGH",
                  fixability: "AGENT_FIX",
                  domain: "engineering",
                  dimensions: ["QD1"],
                  evidence: { probe: "P5.RIPPLE", source_fix: $src, depth: 1 },
                  status: "regression",
                  iteration: ($iter | tonumber)
                }]' \
               $SESSION_DIR/issue-registry.json > $SESSION_DIR/issue-registry.json.tmp \
               && mv $SESSION_DIR/issue-registry.json.tmp $SESSION_DIR/issue-registry.json
           fi

3. UPDATE fix-status.json:
   phases.phase_5.ripple_verify = {
     attempted: true,
     fixed_files_scanned: (so file),
     dependents_checked: (tong downstream),
     ripple_regressions_found: (so ripple_regression moi them vao issue-registry),
     graph_schema: "impact-graph.v1",
     iteration: $ITER
   }

4. Transition: tiep tuc buoc 5.2 (so sanh preflight score).
```

### Rules (ADR-22 rule 2)

- Depth luon = 1 (khong transitive) — de focused + deterministic.
- Strength threshold >= 0.5 — loc strong dependents (eager top-of-file imports, wildcard imports).
- Neu `impact-graph.json` rong (nodes=0 OR edges=0) → skip gracefully, LOG warning, KHONG fail.
- Verify Ripple chay mot lan per iteration — dung chung `$ITER` voi VERIFY_INIT.
- LPM minimal mode (`flags.lpm_minimal == true`) → skip Verify Ripple voi reason="lpm_minimal".
- Cache: KHONG cache ripple results — luon re-run per iteration (vi fix-log.json thay doi).
- **W1.2 CI Cache note:** Verify Ripple KHONG goi `mcp__plugin_gitnexus_gitnexus__impact` truc tiep — chi doc `impact-graph.json` (da co tu Lane Dispatch Phase 0-2). Vi vay session cache wrapper (`wf-fix-ci-cache.sh`) KHONG ap dung o step nay. Neu mai sau co step Phase 5 goi `gitnexus_impact` truc tiep → ap dung pattern wrapper trong [`phase3-batch1.md` §CI Cache Wrapper Usage](phase3-batch1.md).

### Error handling

| Code | Khi xay ra | Xu ly |
|------|-----------|-------|
| E_RIPPLE_NO_GRAPH | impact-graph.json missing | FAIL neu khong LPM minimal; else skip |
| E_RIPPLE_BAD_SCHEMA | schema != impact-graph.v1 | FAIL — chay lai wf-fix-bugs de regenerate impact-graph |
| E_RIPPLE_IMPORT_FAIL | Python module _shared.impact_graph khong load duoc | Fallback CLI; neu CLI fail → FAIL |
| E_RIPPLE_TIMEOUT | Script chay > 30s | Skip, LOG warning, khong fail |

---

## POST-GATE

- Scope built, routes resolved
- Regression scan hoan thanh
- **Verify Ripple attempted** (ADR-22 rule 2): `jq '.phases.phase_5.ripple_verify.attempted == true or .phases.phase_5.ripple_verify.skipped == true' $SESSION_DIR/fix-status.json`
- Content quality checks pass
- Playwright verify da attempt (neu applicable)
- LLM regression probe attempted (neu `--llm-scan`): `jq '.phases.phase_5.llm_regression_verify != null' $SESSION_DIR/fix-status.json`
- fix-status.json: `phases.phase_5.loop_state.state = "VERIFY_SCAN"` → chuan bi chuyen VERIFY_EVALUATE

**Next:** [`phase5-loop.md`](phase5-loop.md) — VERIFY_EVALUATE (step 5.16) ra quyet dinh PASS / FAIL / WARN / LOOP.
