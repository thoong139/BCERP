# Phase 6: Report — Bao cao

> Tao bao cao ket qua, cap nhat fix-history, va phase-summary.
> Phase cuoi trong wf-fix-execute — chay SAU Phase 5 (Verify).
> **Dry-run mode:** Van chay Phase 6 day du — tao fix-report.md, fix-history.md, phase-summary.md. Report the hien "preview" cho thay triage ket qua (khong co actual fixes).

**PRE-GATE:**
```bash
# Fresh run (dry_run = false):
jq -e '.phases.phase_5.status == "completed"' $SESSION_DIR/fix-status.json

# Dry-run (skip Phase 3-5, Phase 6 chay sau Phase 2):
jq -e '.phases.phase_2.status == "completed" and .flags.dry_run == true' $SESSION_DIR/fix-status.json
```

**OUTPUT:**

| File           | Duong dan                                          | Template                      |
| -------------- | -------------------------------------------------- | ----------------------------- |
| Coverage estimate | `$SESSION_DIR/coverage-estimate.json`           | Schema `coverage-estimate-v1` (Phase A v8) |
| Fix report     | `$SESSION_DIR/fix-report.md`                       | `templates/fix-report.md`     |
| Session status | `$SESSION_DIR/fix-status.json`                     | UPDATE (tu wf-fix-bugs orchestrator) |
| Fix history    | `.mc-data/work/wf-fix-bugs/fix-history.md`         | `templates/fix-history.md` (CREATE lan dau, APPEND sau do) |
| Phase summary  | `$SESSION_DIR/phase-summary.md`                    | Inline template (xem §Phase Summary) |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.0  | **Estimate output size:** Dem issues (fixed + escalated + skipped). Neu `estimated_words > $SKELETON_THRESHOLD` → dung **skeleton-first pattern** (xem §Skeleton-First Pattern). | Size estimated |
| 6.0a | **Set report path:** `$REPORT_FILE = $SESSION_DIR/fix-report.md`. Luon CREATE moi cho moi run. Log: "Report path: $REPORT_FILE". | Path determined |
| 6.0b | **Dry-run detection:** Neu `flags.dry_run == true` → SET `$DRY_RUN_MODE = true`. Report se chua "Preview (dry-run)" thay vi actual fix results. Metrics tu triage only (Phase 2). | Mode detected |
| 6.0c | **BAT BUOC — Coverage Estimate (Phase A v8 — Honest Framing):** Compute coverage estimate va luu `$SESSION_DIR/coverage-estimate.json`. Xem §Coverage Estimate ben duoi. | `test -s $SESSION_DIR/coverage-estimate.json && jq -e '.coverage_estimate_pct' $SESSION_DIR/coverage-estimate.json` |
| 6.1  | **BAT BUOC — Report Generation** (xem §Report Generation Detail) | `test -s $SESSION_DIR/fix-report.md && grep "Bug Fix Report" $SESSION_DIR/fix-report.md > /dev/null` |
| 6.1a | **Deep scan section (chi khi `flags.deep == true`):** Them section "UI->Docs Gaps (Deep Scan)" vao `$REPORT_FILE` voi: interactive elements found, overlays traversed, orphan UI counts (actions/screens/flows), stubs created, items needing manual review. Dry-run: section them nhung ghi ro "Planned only, khong co actual scan". | Deep scan section added |
| 6.1b | **Verification Loop History (chi khi `phases.phase_5.iterations_run > 0`):** Them section "## Verification Loop History" vao `$REPORT_FILE` sau Executive Summary. Noi dung doc tu `fix-status.json.phases.phase_5.loop_state.iteration_history[]`: bang iteration/issues_remaining/regressions_found/action_taken. **Tong ket:** "Total iterations: X/3. Regressions caught: N total. Final fix_success_rate: Y%." Dry-run: SKIP section nay. | Loop history section added |
| 6.1c | **BAT BUOC — CQG Numeric Metrics Verify (Protocol 8 — Content Quality Gate):** Sau khi WRITE fix-report.md (Step 6.1), re-READ file va cross-check numeric metrics voi structured data source (KHONG fantasy reporting). Xem §CQG Verify ben duoi de biet chi tiet. Neu mismatch → retry regenerate section (max 3 lan). Dry-run: van verify (voi nguon la triage counts). | Metrics khop giua report + source |
| 6.1d | **QD9 Browser Verification section (Conditional):** Kiem tra `jq -e '.flags.no_browser != true and (.lanes["QD9-runtime-health"].status // "") == "completed"' $SESSION_DIR/fix-status.json 2>/dev/null`. **(A) IF true (QD9 chay + co browser):** Doc `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/runtime/signals.json` va `$SESSION_DIR/phase4-find-bugs/lanes/QD9-runtime-health/lane-status.json`. FILL placeholders trong fix-report.md: `{{QD9_CONSOLE_BEFORE}}` = count signals where `probe == "P-QD9-console-network-monitor" and type == "console_error"` tu signals.json; `{{QD9_CONSOLE_AFTER}}` = `.phases.phase_5.playwright_verify.new_console_errors // "Not re-tested"` tu fix-status.json; `{{QD9_NETWORK_BEFORE}}` = count signals where `type == "network_failure"`; `{{QD9_NETWORK_AFTER}}` = `.phases.phase_5.playwright_verify.new_network_errors // "Not re-tested"`; `{{QD9_PAGES_TESTED}}` = `.pages_tested` tu lane-status.json (hoac list pages); `{{QD9_SCREENSHOTS}}` = `.screenshots_count` tu lane-status.json; `{{QD9_AUTH_FLOWS}}` = count signals where `probe == "P-QD9-auth-aware-smoke"` (0 neu probe skip). **(B) IF false (QD9 khong chay HOAC no_browser=true):** XOA toan bo block "## Browser Verification (QD9)" khoi fix-report.md (tu dong `## Browser Verification (QD9)` den dong `---` tiep theo). KHONG de lai unfilled `{{QD9_*}}` placeholders trong file. | QD9 section filled (A) hoac removed (B) — khong co unfilled `{{QD9_*}}` |
| 6.2  | **BAT BUOC — Fix History (10 columns)** (xem §Fix History Format) | `test -s .mc-data/work/wf-fix-bugs/fix-history.md` |
| 6.3  | Output report summary cho user (hien thi inline trong conversation) | User sees report |
| 6.4  | **BAT BUOC — Phase Summary (CORE-028):** WRITE `$SESSION_DIR/phase-summary.md` voi template (xem §Phase Summary). Hien thi noi dung trong conversation. | `test -s $SESSION_DIR/phase-summary.md` |

---

## Coverage Estimate (Step 6.0c — Honest Framing)

> **Phase A v8.** Muc dich: phai cong khai cho user biet skill cover bao nhieu, KHONG de user lam tuong "fix xong la sach". Source: `.claude/skills/workflow/_shared/aggregate/coverage_estimator.py`.

**Procedure:**

```bash
# Step 1: Compute coverage estimate, ghi $SESSION_DIR/coverage-estimate.json
python3 -m aggregate.coverage_estimator \
  --session "$SESSION_DIR" \
  --output "$SESSION_DIR/coverage-estimate.json"

# Step 2: Verify file co valid
jq -e '.coverage_estimate_pct' "$SESSION_DIR/coverage-estimate.json" > /dev/null || {
  echo "ERROR: coverage-estimate.json invalid"
  exit 1
}
```

**Cach module dieu chinh:**
- Doc `fix-status.json.profile_used` + `dimensions_resolved` + `flags.llm_scan`
- Doc (optional) `stack-info.json.primary_stack` (do `stack_detector` Phase B tao). Neu khong co → fallback `unknown` (confidence=low).
- Compute: `final_pct = stack_base * profile_multiplier * (dim_coverage / 100) + llm_bonus`, clamp [0, 95].

**Output schema (coverage-estimate.json):**

> `dimensions_enabled` phụ thuộc profile — exhaustive = `QD1`-`QD10`; deep = mặc định 7 chiều (gồm QD9 từ v9.0.2); standard/quick = subset.

```json
{
  "schema": "coverage-estimate-v1",
  "stack": "typescript-react",
  "profile": "deep",
  "dimensions_enabled": ["QD1","QD2","QD3","QD4","QD5","QD6","QD7","QD8"],
  "llm_scan_enabled": false,
  "components": {
    "stack_base_pct": 65,
    "profile_multiplier": 1.0,
    "dimension_coverage_pct": 90,
    "static_estimate_pct": 58,
    "llm_bonus_pct": 0
  },
  "coverage_estimate_pct": 58,
  "confidence": "medium",
  "blind_spots": ["Race conditions ...", "Cross-component integration ..."],
  "recommendations": ["Chay --profile=exhaustive ...", "Bat --llm-scan ..."],
  "disclaimer": "Day la UOC TINH — KHONG dam bao..."
}
```

**Failure handling:** Neu Python module crash → log warning, KHONG fail Phase 6. fix-report.md se hien "Coverage Estimate: KHONG TINH DUOC (xem warning)".

---

## Report Generation Detail (Step 6.1)

```
1. READ template .claude/skills/workflow/wf-fix-execute/templates/fix-report.md

2. FILL metrics:
   IF $DRY_RUN_MODE == true:
     → metrics tu triage (total planned, by_severity, AUTO_FIX/AGENT_FIX counts)
   ELSE:
     → metrics tu fix-log.json + issue-registry.json (actual fixed, escalated, skipped)

3. Fixed Issues table:
   IF !DRY_RUN_MODE:
     → Them cot "Iteration" — doc tu $SESSION_DIR/issue-registry.json:
       jq -r '.issues[] | select(.status=="fixed") | "\(.issue_id) | \(.verify.iteration_verified)"' issue-registry.json
   IF DRY_RUN_MODE:
     → Thay bang cot "Planned Batch"

4. FILL Coverage Estimate placeholders (Phase A v8 — Honest Framing):
   READ $SESSION_DIR/coverage-estimate.json (created at Step 6.0c)
   POPULATE:
     {{COVERAGE_STACK}}              ← .stack
     {{COVERAGE_PROFILE}}            ← .profile
     {{COVERAGE_DIMS_COUNT}}         ← .dimensions_count
     {{COVERAGE_DIMS_LIST}}          ← .dimensions_enabled (comma-joined)
     {{COVERAGE_LLM_ENABLED}}        ← "yes" | "no" tu .llm_scan_enabled
     {{COVERAGE_PCT}}                ← .coverage_estimate_pct
     {{COVERAGE_CONFIDENCE}}         ← .confidence
     {{COVERAGE_STACK_BASE}}         ← .components.stack_base_pct
     {{COVERAGE_PROFILE_MULT}}       ← .components.profile_multiplier
     {{COVERAGE_DIM_PCT}}            ← .components.dimension_coverage_pct
     {{COVERAGE_STATIC_PCT}}         ← .components.static_estimate_pct
     {{COVERAGE_LLM_BONUS}}          ← .components.llm_bonus_pct
     {{COVERAGE_BLIND_SPOTS_LIST}}   ← bullet list tu .blind_spots
     {{COVERAGE_RECOMMENDATIONS_LIST}} ← bullet list tu .recommendations
     {{COVERAGE_DISCLAIMER}}         ← .disclaimer

5. WRITE to $REPORT_FILE

NEU SKIP → bao loi, khong ket thuc skill.
```

---

## Fix History Format (Step 6.2 — 10 columns aligned with templates/fix-history.md)

**Procedure:**
```
1. READ template .claude/skills/workflow/wf-fix-execute/templates/fix-history.md
2. Neu file .mc-data/work/wf-fix-bugs/fix-history.md da ton tai → APPEND dong moi
   Neu chua ton tai → WRITE tu template voi dong dau tien
```

**Format (10 cot):**
```
| Date | Scope | Fixed | Total | Before | After | Sessions | Runtime | Deep | Mode |
```

**Column values per run:**

| Column | Value |
|--------|-------|
| Date | YYYY-MM-DD |
| Scope | `"all"` \| `"sys=<sys-id>"` \| `"mod=<mod-id>"` |
| Fixed | `jq '[.entries[] \| select(.iteration == max_iteration)] \| length' fix-log.json` |
| Total | `issues.total` tu fix-status.json |
| Before | `preflight.score_before` (hoac `—` neu browser-only) |
| After | `preflight.score_after` (hoac `—`) |
| Sessions | `metrics.sessions_used` |
| Runtime | `N pages / M errors` neu `flags.no_browser=false`, else `—` |
| Deep | `N orphans / M stubs` neu `flags.deep=true`, else `—` |
| Mode | `FIX` (normal) \| `DRY-RUN` (`flags.dry_run=true`) \| `RESUME` (resumed from checkpoint) |

**APPEND rule:**
- IF chua ton tai → CREATE tu template
- ELSE → APPEND row moi vao cuoi table (truoc block "Column notes")
- KHONG sua rows cu

---

## CQG Verify — Numeric Metrics Cross-Check (Step 6.1c)

> **Protocol 8 — Content Quality Gate.** Muc dich: chong fantasy reporting. Numeric metrics trong fix-report.md PHAI khop voi structured source (fix-log.json + issue-registry.json + fix-status.json). Neu mismatch → regenerate section, khong WRITE metrics sai.

### Metrics phai verify

```bash
# Source counts (KHONG FILE, chay ngay)
ACTUAL_FIXED=$(jq '[.issues[] | select(.status=="fixed")] | length' $SESSION_DIR/issue-registry.json)
ACTUAL_ESCALATED=$(jq '[.issues[] | select(.status=="escalated")] | length' $SESSION_DIR/issue-registry.json)
ACTUAL_SKIPPED=$(jq '[.issues[] | select(.status=="skipped")] | length' $SESSION_DIR/issue-registry.json)
ACTUAL_REGRESSION=$(jq '[.issues[] | select(.status=="regression")] | length' $SESSION_DIR/issue-registry.json)
ACTUAL_TOTAL=$(jq '.issues | length' $SESSION_DIR/issue-registry.json)
ACTUAL_LOG_ENTRIES=$(jq '.entries | length' $SESSION_DIR/fix-log.json)
ACTUAL_ITERATIONS=$(jq '.phases.phase_5.loop_state.current_iteration // 0' $SESSION_DIR/fix-status.json)
ACTUAL_DOCS=$(jq '.metrics.docs_synced // 0' $SESSION_DIR/fix-status.json)
```

### Parse report va compare

```
FOR moi metric in ["Issues Fixed", "Issues Escalated", "Issues Found", "Docs Updated", "Iterations"]:
  REPORT_VALUE = grep/awk extract tu fix-report.md (regex theo format bang "| Metric | ... |")
  SOURCE_VALUE = ACTUAL_* tuong ung
  IF REPORT_VALUE != SOURCE_VALUE:
    LOG ERROR: "CQG mismatch: [metric] report=$REPORT_VALUE source=$SOURCE_VALUE"
    retry_count += 1
    IF retry_count < 3:
      Regenerate affected section (re-FILL template) → re-WRITE
      Re-run CQG verify
    ELSE:
      → POST-GATE FAIL voi error code E001 (CQG_NUMERIC_MISMATCH), CDG render. KHONG tiep tuc Phase 6.
```

### Fix Rate formula check

```
IF $DRY_RUN_MODE == false:
  EXPECTED_RATE = (ACTUAL_FIXED * 100) / ACTUAL_TOTAL (neu ACTUAL_TOTAL > 0)
  REPORTED_RATE = regex extract "Fix Rate: X%" tu fix-report.md
  IF abs(EXPECTED_RATE - REPORTED_RATE) > 1: # tolerance 1% do rounding
    LOG ERROR + retry (theo logic tren)
```

### Dry-run handling

```
IF $DRY_RUN_MODE == true:
  # Nguon la triage counts tu fix-status.phases.phase_2 (KHONG phai fix-log)
  ACTUAL_FIXED = 0 (khong fix)
  ACTUAL_TOTAL = jq '.phases.phase_2.triage_counts.total // .issues | length' $SESSION_DIR/fix-status.json
  VERIFY: "Preview mode — X planned fixes" string xuat hien trong report
```

---

## POST-GATE (CORE-012 — tiered T1-T4)

| Tier | Check | Verify |
|------|-------|--------|
| T1 | `test -f $SESSION_DIR/fix-report.md && test -f .mc-data/work/wf-fix-bugs/fix-history.md && test -f $SESSION_DIR/phase-summary.md` | Files exist |
| T2 | `test -s` cho ca 3 files | Non-empty |
| T3 | `grep -E "^# Bug Fix Report" $SESSION_DIR/fix-report.md` + `grep -E "^# Fix History" .mc-data/work/wf-fix-bugs/fix-history.md` + `grep -E "^## Ket qua Fix Bugs" $SESSION_DIR/phase-summary.md` | Markdown valid (H1 + section headings) |
| T4 | `grep "## Executive Summary" fix-report.md` + `grep "Trang thai:" phase-summary.md` + `grep -E "\\\| [0-9]{4}-[0-9]{2}-[0-9]{2} \\\|" fix-history.md` (dong data row moi) | Required content |
| T3-QD9 | **Conditional** (chi check khi QD9 ran): `QD9_RAN=$(jq -e '.flags.no_browser != true and (.lanes["QD9-runtime-health"].status // "") == "completed"' $SESSION_DIR/fix-status.json 2>/dev/null && echo true \|\| echo false)`. IF `$QD9_RAN == true` → `grep -q "## Browser Verification (QD9)" $SESSION_DIR/fix-report.md && ! grep -q "{{QD9_CONSOLE_BEFORE}}" $SESSION_DIR/fix-report.md`. IF false → chi verify khong con unfilled `{{QD9_` placeholders: `! grep -q "{{QD9_" $SESSION_DIR/fix-report.md`. | Browser Verification section present + filled khi QD9 ran; section da xoa (khong co `{{QD9_*}}`) khi QD9 khong chay. |

Chi PASS khi TAT CA T1-T4 pass; T3-QD9 la conditional (SKIP neu QD9 khong chay, khong phai FAIL). FAIL → LOG error, khong ket thuc skill, retry report generation (max 3).

**BAT BUOC — Update fix-status.json** theo spec "Phase 6 POST-GATE" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract):
```
phases.phase_6.status = "completed"
phases.phase_6.completed_at = NOW
status = "completed"
progress_pct = 100
timestamps.completed_at = NOW
timestamps.last_updated = NOW
active_skill = "wf-fix-bugs"
next_action = "done"
```

---

## Phase Summary (CORE-028)

> File: `$SESSION_DIR/phase-summary.md`
> Quy tac chung: xem `.claude/skills/protocols/` §14

**Tao khi nao:** SAU POST-GATE Phase 6 completed. Neu FAIL → van tao voi trang thai "THAT BAI".
**Resume behavior:** Khi resume → GIU NGUYEN summary cu, chi UPDATE khi phase cuoi hoan thanh.
**DEFERRED findings** tu Phase 2 triage PHAI xuat hien trong "Can luu y".

**Template:**

```
## Ket qua Fix Bugs

**Trang thai:** [HOAN THANH / THAT BAI / DANG XU LY / PREVIEW (dry-run)]
**Pham vi:** [scope description]
**Ngay:** [YYYY-MM-DD]
**Mode:** [Fresh run / Dry-run / Resumed]

### Da lam gi
- [Mo ta ket qua chinh bang tieng Viet, toi da 15 dong, tap trung KET QUA]
- [Dry-run: mo ta "Da phan tich X issues, preview fix plan"]
- [Fresh: "Da sua X issues, M escalated, docs sync Y feature specs"]

### Can luu y
- [Escalated issues, manual review items, deferred findings tu triage Phase 2]
- [Stubs --deep mode can flesh-out sau]

### Buoc tiep theo
- [Dry-run] Chay `/wf-fix-bugs` khong `--dry-run` de execute
- [Fresh] Chay `/wf-verify-sync` de xac nhan dong bo registry
```

---

## Skeleton-First Pattern (Protocol 6.5)

**Khi ap dung:**
```
$SKELETON_THRESHOLD = 2000 (LPM active) HOAC 3000 (standard mode)
estimated_words > $SKELETON_THRESHOLD → dung skeleton-first
```

**Implementation (theo `protocols/06-token-limit.md §6.5`):**

**Buoc 1 — Skeleton:**
```
1. Write report title + metadata table (Fix ID, Date, Scope)
2. Write section headers (Table of Contents) — TAT CA sections
3. Write Executive Summary (3-5 dong)
4. Write metrics summary (severity counts, fix rate, iterations)
5. SAVE — checkpoint 1
```

**Buoc 2 — Fill details (optional per-section checkpoint):**
```
FOR each section in TOC:
  APPEND detailed content (issue lists, code snippets, verify results)
  IF context_usage > 80%: SAVE + suggest resume
  ELSE: continue
```

**Rationale:**
- Checkpoint early (sau skeleton) — neu bi interrupt, co overview khung con dung
- Grep structure co the dung de navigate report du chua day du
- Phu hop voi LPM (Large Project Mode) khi co > 100 issues

---

## E2E Section Rendering (conditional)

Logic render section "E2E Verification" trong `$REPORT_FILE` (Step 6.1):

```
IF fix-status.phases.phase_5.playwright_verify.e2e_results_file != null:
  READ $SESSION_DIR/e2e-results.json
  RENDER detailed per-route + per-test results trong report section
ELIF fix-status.phases.phase_5.playwright_verify.attempted == true:
  RENDER summary only tu playwright_verify
    (pages_checked, new_console_errors, e2e_tests_run/passed/failed)
ELSE:
  RENDER: "E2E verification: SKIPPED (--no-browser hoac app khong running)"
```

> **Lien quan** [`phase5-scan.md`](phase5-scan.md) §Step 5.14b: `e2e-results.json` la OWNED boi wf-fix-bugs Lane Dispatch (CREATE). wf-fix-execute Phase 5 chi UPDATE (append verify iterations). Neu Lane Dispatch skip → file khong ton tai → Phase 5 ghi summary vao `fix-status.playwright_verify` → Phase 6 render summary-only.

---

## Dry-Run Behavior Matrix

| Item | Fresh Run | Dry-Run |
|------|-----------|---------|
| fix-report.md | Actual metrics (fix-log.json + issue-registry.json.verify) | Preview metrics (triage only) |
| Fixed Issues table | Co cot "Iteration" | Thay bang "Planned Batch" column |
| Deep scan section | Actual runtime results | "Planned only" note |
| Loop history | Co neu iterations > 0 | SKIP (khong loop) |
| fix-history.md | APPEND dong moi | APPEND dong moi voi mode="DRY-RUN" |
| phase-summary.md | Status="HOAN THANH" | Status="PREVIEW (dry-run)" |
| fix-status.json | status="completed", progress_pct=100 | status="completed", progress_pct=100 |
