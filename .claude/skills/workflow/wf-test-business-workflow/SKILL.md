---
name: wf-test-business-workflow
version: 1.0.0
last_updated: 2026-05-08
description: |
  Test E2E + auto-fix + sinh business/technical narration cho mỗi business workflow spec
  trong .mc-data/docs/phase1-business/workflows/ (WF-L1 → WF-L6).
  Pipeline 3-phase: ANALYZE (parse spec) → TEST (Playwright MCP + auto-fix) → NARRATE (dual-agent).
  Output: .mc-data/docs/phase1-business/workflows/_presentations/{WF-id}.presentation.md.

  TRIGGER khi:
  - User muốn validate 1 hoặc nhiều WF-L*-NN-*.md chạy đúng end-to-end trong erp-web/backend
  - User cần sinh presentation gửi BA/PM cho mỗi business workflow
  - User muốn resume session test đang dở

  KHÔNG trigger khi:
  - Test 1 module code (dùng /wf-test-flow)
  - Sinh WF spec mới (dùng /wf-analyze-requirements)
  - Fix 1 bug cụ thể (dùng /wf-fix-bugs)

argument-hint: "[--workflow=WF-L1-01|--all|--level=L1|--set=WF-L1-10,WF-L1-11,WF-L2-03] [--resume] [--status] [--setup-machine] [--stop] [--no-spawn] [--phase=analyze|test|narrate] [--dry-run]"
disable-model-invocation: true
allowed-tools: >
  Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__gitnexus__query, mcp__gitnexus__context, mcp__gitnexus__impact
---
# wf-test-business-workflow

> Test E2E + auto-fix + dual-narrative presentation cho business workflow specs (WF-L1 → WF-L6).
> Pipeline: PRE-GATE → ANALYZE → TEST → NARRATE → SPAWN NEXT.
> Session-based, resumable, autonomous loop với kill-switch.

---

> **ĐỌC TRƯỚC KHI CHẠY**
>
> Skill này chạy theo mô hình **1 session = 1 WF**. Mỗi WF hoàn thành, skill **BẮT BUỘC**
> tự động spawn Claude Code tab mới cho WF tiếp theo thông qua
> `python -X utf8 scripts/next-session.py` (Step 4.6). Script copy prompt
> `/wf-test-business-workflow --resume` vào clipboard, mở VS Code command palette,
> tạo tab Claude Code mới và paste — không cần thao tác thủ công.
>
> **KHÔNG được tự tiếp tục WF tiếp theo trong cùng session** (context blow-up).
> Ngoại lệ duy nhất: script trả Exit 1 → FALLBACK MODE in-session (có log rõ ràng).

---

### Workflow Position

```
/wf-analyze-requirements → [WF-L*.md specs] → /wf-test-business-workflow → _presentations/
                                                          |
                                                   YOU ARE HERE
```

> Prerequisite: ≥1 WF-L*.md trong `.mc-data/docs/phase1-business/workflows/`
> Next: Review presentations tại `.mc-data/docs/phase1-business/workflows/_presentations/`

---

## Protocols & Strategy

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, chất lượng kỹ thuật, bảo mật**
2. **Tốc độ và song song hóa** — chỉ sau khi mục 1 được bảo vệ

### Execution Strategy

| Condition                              | Mode                                                               |
| -------------------------------------- | ------------------------------------------------------------------ |
| Phase 3 Narrate — 2 agents độc lập | **PARALLEL** — spawn developer + domain-expert đồng thời |
| Phase 0→1→2→3→4                    | **SEQUENTIAL** — output phase trước là input phase sau   |

### Fix Rules (BẮT BUỘC — fix đến sạch, không giới hạn số lần)

> **Nguyên tắc:** Thấy lỗi → phân loại → fix ngay → chạy lại test → lặp đến khi pass hết.
> Không có "max attempts". Không có "blast radius > 10 → blocked".
> CHỈ escalate khi fix đòi hỏi quyết định ngoài kỹ thuật (xem cột Escalate).

| Error Type           | Auto-Fix Strategy                                        | Escalate If (và chỉ khi)                               |
| -------------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| `TEST_BRITTLE`     | Adjust selector / add wait_for trong .spec.ts            | Không bao giờ — luôn fix được                     |
| `DATA_STATE`       | Seed data qua API trong beforeEach/beforeAll             | API seed trả 5xx và không có endpoint seed           |
| `AUTH_EXPIRED`     | Re-login + lưu storageState                             | Login fail do tài khoản bị khoá (cần Admin)         |
| `FRONTEND_BUG`     | Serena edit apps/erp-web/src/ → re-run                  | Cần business owner quyết định UX/behavior            |
| `BACKEND_BUG`      | Serena edit apps/backend/ → đợi rebuild 90s → re-run | Cần EF migration mới / cần thay đổi DB schema       |
| `MISSING_ENDPOINT` | Implement endpoint + handler đơn giản → re-run       | Cần domain design phức tạp (cross-module transaction) |
| `RENDER_TIMING`    | Thêm wait_for + retry trong .spec.ts                    | Không bao giờ — luôn fix được                     |
| `BUILD_ERROR`      | Fix TypeScript/compile error → re-run typecheck         | Cần thay đổi interface đã published                 |

### Template Usage (CORE-031)

Mọi output file: **READ template → POPULATE → WRITE**. Templates tại `templates/`.

---

## Cách Dùng

```bash
# Chạy 1 WF cụ thể (không spawn next)
/wf-test-business-workflow --workflow=WF-L1-01 --no-spawn

# Autonomous loop toàn bộ 33 WF
/wf-test-business-workflow --all

# Chạy danh sách WF tùy chọn (comma-separated)
/wf-test-business-workflow --set=WF-L1-10,WF-L1-11,WF-L2-03,WF-L6-02,WF-L1-09,WF-L5-03,WF-L6-05,WF-L6-06,WF-L6-07,WF-L6-08

# Chỉ 1 level
/wf-test-business-workflow --level=L1

# Xem dashboard tiến độ
/wf-test-business-workflow --status

# Resume session đang dở
/wf-test-business-workflow --resume

# Dừng loop sau WF hiện tại
/wf-test-business-workflow --stop

# Setup lại machine config
/wf-test-business-workflow --setup-machine

# Dry-run: chỉ Phase 1 (analyze), không test/narrate/spawn
/wf-test-business-workflow --workflow=WF-L1-01 --dry-run
```

---

## Phase 0: PRE-GATE

> Procedure: `procedures/session-dir.md` + `procedures/resume-routing.md` + `procedures/first-run-wizard.md`

**PRE-GATE:** `test -d .mc-data/docs/phase1-business/workflows/ && ls WF-L*.md 2>/dev/null | wc -l | grep -v ^0`

| Step | Action                                                   | Tool  | Verify                 |
| ---- | -------------------------------------------------------- | ----- | ---------------------- |
| 0.0  | Kill-switch check — đọc _runs/STOP                    | Read  | File tồn tại → exit |
| 0.1  | Flag dispatch (--status/--resume/--stop/--setup-machine) | -     | Route đúng           |
| 0.2  | Load machine config từ auto-memory                      | Read  | Config loaded          |
| 0.3  | Validate prerequisites (WF files + FE/BE running)        | Bash  | 200 OK từ localhost   |
| 0.4  | Build/refresh progress.json                              | Bash  | File tồn tại         |
| 0.5  | Claim WF (atomic write inprogress)                       | Write | status=inprogress      |
| 0.6  | Init session directory + copy templates                  | Write | SESSION_DIR created    |

**POST-GATE:** `test -f _runs/progress.json && SESSION_DIR exists && WF status=inprogress`

### Step 0.0 — Kill-switch Check

```
NẾU .mc-data/work/wf-test-business-workflow/_runs/STOP tồn tại:
  - NẾU có WF đang inprogress → mark lại = pending (atomic write progress.json)
  - In: "⛔ STOP detected. Loop halted. Remove _runs/STOP to resume."
  - EXIT ngay (không spawn next)
```

### Step 0.1 — Flag Dispatch

```
--stop          → Tạo _runs/STOP file → "⛔ STOP scheduled." → exit
--status        → Đọc progress.json → in dashboard → exit (xem procedures/resume-routing.md)
--setup-machine → Chạy first-run wizard (đè config hiện tại) → exit
--resume        → Đọc test-status.json session gần nhất → route theo next_action
--set           → Parse comma-separated WF-ID list → validate → lưu vào SESSION_DIR/_set.json
                → mark tất cả WF trong set = pending nếu chưa done
                → claim WF đầu tiên trong set có status=pending (Step 0.5)
                → NẾU tất cả trong set đã done → "✅ Set done." → exit
default         → Claim WF mới (Step 0.4)
```

### Step 0.2 — Load Machine Config

```
1. Đọc C:\Users\Admin\.claude\projects\d--EUREKA-2026\memory\wf-test-business-workflow-machine.md
2. NẾU không tồn tại HOẶC --setup-machine → first-run wizard (procedures/first-run-wizard.md)
3. Đọc _runs/.machine-mirror.json (cho scripts)
```

### Step 0.3 — Validate Prerequisites

```
KIỂM TRA:
  ✓ Có ≥1 file WF-L*.md tại .mc-data/docs/phase1-business/workflows/
    (glob: WF-L[0-9]-[0-9][0-9]-*.md)
  ✓ erp-web đang chạy: GET http://localhost:3000 → 200|302
  ✓ Backend đang chạy: GET http://localhost:5048/health → 200

NẾU prerequisites fail:
  - E004/E005: hướng dẫn start docker compose / pnpm dev
  - E001: hướng dẫn chạy /wf-analyze-requirements trước
  - DỪNG (không proceed)
```

### Step 0.4 — Build/Refresh progress.json

```
1. Kiểm tra _runs/progress.json tồn tại
2. NẾU không tồn tại → chạy: python scripts/build-progress.py
3. NẾU tồn tại + có WF mới trong filesystem không có trong JSON → chạy: python scripts/build-progress.py (idempotent, preserve statuses)
```

### Step 0.5 — Claim WF

```
1. Đọc _runs/progress.json
2. Xác định target WF theo flags:
   - --workflow=WF-L{N}-{NN}: chọn WF cụ thể đó
   - --set=WF-L{A},WF-L{B},...: parse comma-separated list → chỉ chạy các WF này
     (theo đúng thứ tự trong list). spawn next — tự động.
     Nếu WF chưa có trong progress.json → thêm mới với status=pending.
     Nếu WF đã done → skip (giữ nguyên).
   - --level=L{N}: filter workflows có level=L{N}
   - --all / default: tất cả 33 WF theo thứ tự L1-01 → L1-12 → L2-01 → ... → L6-08
3. Tìm WF đầu tiên status="pending" trong target set
4. NẾU hết pending trong target set:
   - --set mode: in "✅ Set complete: N/N workflows done." → exit
   - --all / --level mode: Đọc tất cả blocked → log summary
   - Sinh _runs/FINAL-REPORT.md (templates/final-report.md)
   - In: "✅ All workflows done. FINAL-REPORT.md generated."
   - EXIT (không spawn next)
5. Mark WF = inprogress, set started_at. Atomic write progress.json.
6. NẾU WF đang inprogress (conflict) + --resume: resume session đó
```

### Step 0.6 — Init Session

Xem `procedures/session-dir.md` để tạo SESSION_DIR.

```
BASE_DIR = .mc-data/work/wf-test-business-workflow
RUNS_DIR = BASE_DIR/_runs
SESSION_ID = YYYY-MM-DD-{WF-id}-{NN}   (auto-increment nếu collision)
SESSION_DIR = BASE_DIR/sessions/SESSION_ID
```

---

## Phase 1: ANALYZE

> **Procedure chi tiết:** `procedures/phase1-analyze.md`

**PRE-GATE:** `test -f $SESSION_DIR/test-status.json && WF analysis_status=pending`

| Step | Action                                      | Tool  | Verify               |
| ---- | ------------------------------------------- | ----- | -------------------- |
| 1.1  | Locate + read WF-L*.md spec file            | Read  | File found           |
| 1.2  | Run parse-workflow-spec.py → raw JSON      | Bash  | JSON output OK       |
| 1.3  | Resolve test accounts từ §3 Actors        | Read  | accounts mapped      |
| 1.4  | Naming gap check vs naming-alignment-matrix | Read  | MAJOR gaps flagged   |
| 1.5  | Sinh workflow-analysis.md từ template      | Write | File > 100 bytes     |
| 1.6  | Update test-status.json                     | Write | analysis_status=done |

**POST-GATE:** `test -f $SESSION_DIR/workflows/{WF-id}-analysis.md && analysis_status=done`

### Step 1.1 — Parse WF Spec

```
1. Đọc .mc-data/docs/phase1-business/workflows/{WF-id}-*.md (16 sections §1-§16)
2. Chạy scripts/parse-workflow-spec.py → workflows/{WF-id}-analysis-raw.json
3. Cross-ref naming-alignment-matrix.md (nếu tồn tại) → check endpoint aliases
```

**Sections quan trọng nhất:**

- §3 Actors → test accounts mapping
- §7 Steps → test plan
- §8 State machine → valid transitions để assert
- §9 Business rules → BR-WF{xx}-{NN} → assertion points
- §11 SLA → timing assertions
- §15 E2E test scenarios → Happy / Edge / Negative paths

### Step 1.2 — Resolve Test Accounts

```
Actor từ §3 → map sang test account:
  Sales/CRM actor   → sales.manager@erktransport.local / SalesMgr@123
  Finance actor     → finance.manager@erktransport.local / FinanceMgr@123
  Warehouse actor   → warehouse.manager@erktransport.local / WarehouseMgr@123
  Admin actor       → company.admin@erktransport.local / Company@123
  System Admin      → sysadmin@erktransport.local / SysAdmin@123
  Customer          → (nếu có CustomerMobile endpoint) — dùng customer test account

Đọc shared/test-accounts.md để override nếu có mapping cụ thể.
```

### Step 1.3 — Naming Gap Check

```
NẾU naming-alignment-matrix.md tồn tại:
  - Đọc MAJOR gaps liên quan WF này
  - NẾU WF dùng endpoint có MAJOR gap → E005: log warning, hỏi user có muốn test không
  - MINOR gaps: log, continue (test sẽ reveal actual state)
```

### Step 1.4 — Sinh Workflow Analysis

```
Sinh SESSION_DIR/workflows/{WF-id}-analysis.md từ templates/workflow-analysis.md:
  - Actors + test accounts
  - Test plan (Happy / Edge / Negative từ §15)
  - Systems & endpoints (cross-validated)
  - State machine transitions
  - Business rules → assertions
  - SLA → timing checks

Update test-status.json: workflows.{WF-id}.analysis_status = "done"
```

---

## Phase 2: TEST — WRITE → RUN/FIX → MCP VERIFY

> **Triết lý:** Viết test script trước (ground truth), chạy và fix code đến sạch, cuối cùng dùng
> Playwright MCP như một manual user để lấy evidence. Test script trở thành regression suite
> có thể tái sử dụng, không phải one-shot session.

**PRE-GATE:** `analysis_status=done && BE/FE running`

| Step | Action                                                               | Tool             | Verify                      |
| ---- | -------------------------------------------------------------------- | ---------------- | --------------------------- |
| 2.1  | Đọc analysis + sinh `{WF-id}.spec.ts`                            | Write            | File tồn tại tại e2e/wf/ |
| 2.2  | Run `pnpm e2e --grep {WF-id}` lần đầu                           | Bash             | Output có kết quả        |
| 2.3  | Fix loop: phân loại lỗi → fix code → re-run → lặp đến sạch | Edit/Serena/Bash | Exit 0 từ pnpm e2e         |
| 2.4  | MCP Verify: login manual + happy path + deep verify + screenshots    | MCP tools        | ≥1 .png evidence           |
| 2.5  | Record results                                                       | Write            | test-status.json updated    |

**POST-GATE:** `pnpm e2e exit 0 && screenshots ≥1 && spec file tồn tại`

---

### Step 2.1 — Sinh E2E Spec File

```
Input:  SESSION_DIR/workflows/{WF-id}-analysis.md
        shared/test-accounts.md
Output: apps/erp-web/e2e/wf/{WF-id}.spec.ts

Đọc template: templates/wf.spec.ts.template
Populate từ analysis:
  - BASE_URL = http://localhost:3000
  - AUTH credentials từ primary actor
  - describe block = WF-id + slug
  - test 'happy path' → steps từ §7, assertions từ §7 Expected column + §8 state transitions
  - test 'edge cases'  → TC từ §15 (mỗi TC = 1 test block)
  - test 'negative'    → TC từ §15 negative, assert HTTP status + error message
  - API assertions dùng page.waitForResponse() + expect(response.status())
  - UI assertions dùng expect(page.locator(...))
  - beforeAll: login + save storageState
  - afterAll: cleanup seed data nếu cần

Ghi file. Verify: `pnpm typecheck` tại apps/erp-web không thêm lỗi.
```

---

### Step 2.2 — Chạy Test Lần Đầu (Baseline)

```bash
cd apps/erp-web
pnpm e2e --project=chromium --grep "{WF-id}" --reporter=list 2>&1
```

```
Parse output:
  - Đếm passed / failed / skipped
  - VỚI MỖI failure: lấy test name + error message + stack trace
  - Ghi SESSION_DIR/shared/e2e-run-log.txt (append mỗi run)
  - NẾU tất cả pass ngay → skip Step 2.3, đến Step 2.4
```

---

### Step 2.3 — Fix Loop (Lặp Đến Sạch — Không Giới Hạn)

```
LOOP:
  1. Lấy danh sách failures từ run output
  2. VỚI MỖI failure (ưu tiên failures block nhiều tests nhất):
     a. Classify:
        - Build/TypeScript error        → BUILD_ERROR
        - Selector không tìm thấy      → TEST_BRITTLE
        - HTTP 404 endpoint chưa có    → MISSING_ENDPOINT
        - HTTP 4xx/5xx logic sai       → BACKEND_BUG
        - HTTP 2xx nhưng UI sai        → FRONTEND_BUG
        - Danh sách rỗng/entity thiếu  → DATA_STATE
        - 401/403 unexpectedly         → AUTH_EXPIRED
        - Element visible timing       → RENDER_TIMING

     b. Fix theo classification:
        BUILD_ERROR      → Serena fix TypeScript/import errors
        TEST_BRITTLE     → Edit .spec.ts: selector / wait_for
        RENDER_TIMING    → Edit .spec.ts: thêm waitForLoadState / waitForSelector
        DATA_STATE       → Thêm beforeAll seed via API / tạo fixture
        AUTH_EXPIRED     → Update storageState logic trong test
        MISSING_ENDPOINT → Implement endpoint + command handler trong apps/backend/
                           (MapGet/MapPost → Command/Query → Handler)
                           → đợi backend rebuild 90s
        BACKEND_BUG      → Serena fix handler / validator / business rule
                           → đợi backend rebuild 90s
        FRONTEND_BUG     → Serena fix component / hook / page trong apps/erp-web/src/
                           → verify pnpm typecheck pass

     c. Sau mỗi fix: chạy lại pnpm e2e --grep {WF-id}
     d. NẾU failure giảm → tiếp tục loop
     e. NẾU failure KHÔNG giảm sau fix → classify lại, thử cách khác

  DỪNG loop khi: tất cả tests pass (exit 0) HOẶC chỉ còn failures cần quyết định
  ngoài kỹ thuật (xem cột Escalate trong Fix Rules) → ghi BUG-{NNN}.json và tiếp tục.
```

**Ghi fix-log mỗi iteration:**

```
SESSION_DIR/shared/fix-log.json — mảng các entry:
  { "iteration": N, "failure": "...", "classification": "...", "fix": "...", "result": "pass|fail" }
```

---

### Step 2.4 — MCP Verify (Evidence + Final Smoke)

```
Mục đích: xác nhận bằng mắt người dùng sau khi scripts đã pass, lấy screenshot evidence.

1. browser_navigate  → http://localhost:3000/vi/login
2. browser_fill_form → email + password
3. browser_click submit → browser_wait_for /dashboard
4. VỚI MỖI bước chính trong Happy Path (§7):
   a. browser_navigate → trang target
   b. browser_snapshot → xác nhận page loaded
   c. browser_console_messages → kiểm tra không có JS error mới
   d. browser_network_requests → verify API calls đúng method/status
   e. Thực hiện action (fill/click/select)
   f. browser_wait_for → toast / redirect / modal
   g. browser_take_screenshot → SESSION_DIR/playwright/evidence/{WF-id}/step-{NN}-{description}.png
5. Bất kỳ lỗi mới nào (không thấy trong spec) → ghi BUG-{NNN}.json, fix ngay.
```

---

### Step 2.5 — Record Results

```
Overall test_status:
  "pass"    = pnpm e2e exit 0 + MCP verify không có critical error mới
  "partial" = một số edge/negative tests vẫn fail vì escalate (cần business decision)
  "fail"    = happy path vẫn fail sau fix loop

Update test-status.json: workflows.{WF-id}.test_status
Ghi SESSION_DIR/bugs/BUG-{NNN}.json cho mọi issue chưa fix (kể cả escalated)
Ghi SESSION_DIR/shared/fix-log.json (đã ghi incremental trong Step 2.3)

tc_results FORMAT (BẮT BUỘC — dùng object, KHÔNG dùng string thuần):
  Mỗi TC phải có:
    "result":          "PASS" | "FAIL" | "SKIP" | "PARTIAL" | "DEFERRED"
    "fixed":           true  (đã fix trong session)
                     | false (deferred — chưa fix, cần follow-up)
                     | null  (không áp dụng — TC không chạy)
    "deferred_reason": null | "string giải thích rõ: tại sao defer, cần làm gì tiếp theo"

  QUY TẮC:
    PASS    → fixed: null,  deferred_reason: null
    FAIL    → fixed: false, deferred_reason: BẮT BUỘC (mô tả bug + BUG-NNN)
    PARTIAL → fixed: false, deferred_reason: BẮT BUỘC (phần nào pass, phần nào chưa fix)
    DEFERRED → fixed: false, deferred_reason: BẮT BUỘC
    SKIP    → fixed: null,  deferred_reason: lý do bỏ qua (optional)

  KHÔNG được dùng string thuần như "PARTIAL (score=null)" vì không biết đã fix hay chưa.
```

---

## Phase 3: NARRATE (chỉ khi Phase 2 PASS)

> **Procedure chi tiết:** `procedures/phase3-narrate.md`

**PRE-GATE:** `test_status=pass`

| Step | Action                                            | Tool  | Verify                |
| ---- | ------------------------------------------------- | ----- | --------------------- |
| 3.1  | Map domain expert agent theo WF level             | -     | Agent name resolved   |
| 3.2  | Spawn developer + domain-expert agents (PARALLEL) | Agent | Both return output    |
| 3.3  | Compose presentation.md từ template (5 sections) | Write | File > 500 bytes      |
| 3.4  | Update _presentations/README.md index             | Edit  | Row added             |
| 3.5  | Update test-status.json                           | Write | narration_status=done |

**POST-GATE:** `presentation.md exists && size > 500 bytes && README.md updated`

### Step 3.1 — Spawn Dual-Agent

```
Spawn 2 agents SONG SONG:

Agent 1 — developer:
  - Input: workflow-analysis.md + fix-log.json + API evidence
  - Output: §3 Góc nhìn kỹ thuật (~600 từ, tiếng Việt)
    (sequence BE/FE, validation layers, side effects, assertion points)

Agent 2 — domain expert (theo level):
  L1 → sales-expert hoặc customer-expert
  L2 → procurement-expert
  L3 → hr-expert (+ finance-expert nếu có GL posting)
  L4 → customer-expert
  L5 → logistics-expert
  L6 → finance-expert / customer-expert / logistics-expert (theo subject)

  - Input: WF-L*.md (§1-§4) + workflow-analysis.md
  - Output: §2 Góc nhìn nghiệp vụ (~600 từ, tiếng Việt)
    (mục đích, actors, KPIs, downstream impact, edge cases)
```

### Step 3.2 — Compose Presentation

```
Đọc templates/presentation.md → populate 5 sections:
  §1 Tổng quan demo     (từ §1 spec + run metadata)
  §2 Góc nhìn nghiệp vụ (từ domain expert agent)
  §3 Góc nhìn kỹ thuật  (từ developer agent)
  §4 Kết quả QA         (từ fix-log + bugs + phase 2 observations)
  §5 Artifacts          (screenshots, checkpoint path, re-run command)

Ghi: .mc-data/docs/phase1-business/workflows/_presentations/{WF-id}-{slug}.presentation.md
Update README.md index tại _presentations/ (idempotent)
```

---

## Phase 4: SPAWN NEXT SESSION

> **Procedure chi tiết:** `procedures/phase4-spawn-next.md`

**PRE-GATE:** `status=done|blocked (not inprogress)`

| Step | Action                                          | Tool      | Verify                    |
| ---- | ----------------------------------------------- | --------- | ------------------------- |
| 4.0  | Phase Completeness Audit (BẮT BUỘC)            | Read      | steps_skipped documented  |
| 4.1  | Pre-exit verification (artifacts check)         | Read/Bash | All artifacts present     |
| 4.2  | Ghi checkpoint JSON                             | Write     | File exists               |
| 4.3  | Atomic update progress.json                     | Write     | status=done\|blocked      |
| 4.4  | Digest mỗi 10 WF done                          | Write     | Optional                  |
| 4.5  | Re-check STOP kill-switch                       | Read      | Exit nếu STOP            |
| 4.6  | Regenerate _runs/prompt-template.md             | Write     | File updated              |
| 4.7  | Invoke next-session.py (nếu không --no-spawn) | Bash      | Exit 0=spawn / 1=fallback |
| 4.8  | --set mode: loop back to Step 0.5             | -         | Next WF in set claimed    |

**POST-GATE:** `checkpoint exists && progress.json status correct && (spawned OR --no-spawn)`

### Step 4.0 — Phase Completeness Audit (BẮT BUỘC)

```
Mục đích: phát hiện step bị bỏ qua do context compaction, interrupt, hoặc lỗi logic.
Chạy TRƯỚC pre-exit verification, TRƯỚC khi ghi checkpoint.

CHECKLIST (đánh dấu true/false vào checkpoint.steps_completed):

  Phase 1:
    1.1_parse_spec          — WF spec đã được đọc?
    1.2_run_parse_script    — parse-workflow-spec.py đã chạy (hoặc manual parse)?
    1.3_resolve_accounts    — test accounts đã được map từ §3 Actors?
    1.4_naming_gap_check    — naming gaps đã được kiểm tra?
    1.5_write_analysis      — workflow-analysis.md đã được ghi?

  Phase 2:
    2.1_write_spec          — {WF-id}.e2e.ts đã tồn tại tại e2e/wf/?
    2.2_first_run           — pnpm e2e đã chạy ít nhất 1 lần?
    2.3_fix_loop            — fix loop đã chạy đến khi pass/escalate?
    2.4_mcp_verify          — Playwright MCP login + happy path + ≥1 screenshot?
    2.5_record_results      — test-status.json đã được update?

  Phase 3:
    3.1_map_agent           — domain expert agent đã được xác định?
    3.2_spawn_agents        — developer + domain agent đã được spawn?
    3.3_compose_presentation — presentation.md đã được ghi?
    3.4_update_readme       — _presentations/README.md đã được update?

RULES:
  - NẾU step = false → ghi vào steps_skipped[] + skip_reasons{} trong checkpoint
  - NẾU 2.4_mcp_verify = false → BẮT BUỘC chạy ngay trước khi spawn (không được bỏ qua)
  - NẾU 3.3_compose_presentation = false → BẮT BUỘC ghi presentation trước khi spawn
  - Các step khác = false → ghi rõ lý do, tiếp tục (không block spawn)
  - NẾU steps_skipped[] không rỗng → log rõ "⚠ SKIPPED STEPS: [list]" trước khi spawn
```

### Step 4.1 — Pre-exit Verification (BẮT BUỘC)

```
NẾU status = done (PASS):
  ✓ presentation.md tồn tại + size > 500 bytes
  ✓ playwright/evidence/{WF-id}/ có ≥1 .png
  ✓ _runs/checkpoints/{WF-id}.json tồn tại

NẾU status = blocked:
  ✓ SESSION_DIR/bugs/ có ≥1 BUG-{NNN}.json
  ✓ _runs/checkpoints/{WF-id}.json tồn tại, status=blocked

NẾU thiếu artifact → fix ngay, KHÔNG spawn trước khi đủ
```

### Step 4.2 — Update progress.json

```
status = done | blocked
presentation_path set (nếu done)
checkpoint = _runs/checkpoints/{WF-id}.json
completed_at = ISO8601
Atomic write
```

### Step 4.3 — Digest (mỗi 10 WF done)

```
NẾU done_count % 10 == 0:
  Ghi _runs/digest-{timestamp}.md với summary 10 WF vừa xong
```

### Step 4.4 — Kill-switch Re-check

```
NẾU _runs/STOP tồn tại → exit ngay (không spawn)
```

### Step 4.5 — Regenerate prompt-template.md

```
1. Đọc templates/prompt-template.md
2. NẾU đang trong --set mode (tồn tại SESSION_DIR/_set.json):
     - Đọc _set.json → lấy danh sách set
     - Prompt = "/wf-test-business-workflow --set={comma-separated-list}"
   NẾU không có --set:
     - Prompt = "/wf-test-business-workflow --resume"
3. Ghi _runs/prompt-template.md với prompt đã resolved
```

### Step 4.6 — Invoke Spawn Script (BẮT BUỘC — KHÔNG được bỏ qua)

> Đây là cơ chế cốt lõi của autonomous loop. Mỗi WF xong **PHẢI** chạy script này.
> KHÔNG tự tiếp tục WF tiếp theo trong cùng session — context blow-up sau vài WF.

```
NẾU --no-spawn → bỏ qua (exit gọn, dùng khi test 1 WF đơn lẻ)
NẾU --dry-run  → bỏ qua

LUÔN chạy với -X utf8 để tránh encoding error trên Windows:
  python -X utf8 scripts/next-session.py --runs-dir .mc-data/work/wf-test-business-workflow/_runs

Script thực hiện:
  1. Kiểm tra STOP file
  2. Kiểm tra còn pending workflows
  3. Copy _runs/prompt-template.md (chứa "/wf-test-business-workflow --resume") vào clipboard
  4. Mở VS Code command palette (Ctrl+Shift+P) → "Claude Code: Open in new tab"
  5. Paste prompt → Enter → tab mới tự chạy WF tiếp theo

Exit 0 → spawn OK hoặc STOP → EXIT session ngay (KHÔNG làm gì thêm)
Exit 1 → FALLBACK MODE: log rõ "FALLBACK: spawn failed, continuing in-session"
          → quay lại Phase 0.5 claim WF tiếp theo trong session hiện tại
          → lặp đến hết pending hoặc STOP hoặc context > 70%
```

---

## Error Handling

| Code | Mô tả                                    | Xử lý                                     |
| ---- | ------------------------------------------ | ------------------------------------------- |
| E001 | WF-L*.md không tồn tại                  | Hướng dẫn chạy /wf-analyze-requirements |
| E002 | Context > 70%                              | Ghi checkpoint + hướng dẫn --resume      |
| E003 | Playwright MCP không khả dụng           | Hướng dẫn manual test guide              |
| E004 | Backend không chạy                       | docker compose / dotnet run                 |
| E005 | Naming gap MAJOR — endpoint không match  | Escalate, hỏi user                         |
| E006 | Bug fix thất bại 3 lần                  | Escalate, mark blocked                      |
| E007 | Domain expert agent không phù hợp level | Fallback developer-only narration           |
| E008 | Machine config chưa setup                 | Trigger first-run wizard                    |
| E009 | Spawn script fail                          | FALLBACK MODE in-session                    |
| E010 | STOP file detected                         | Mark inprogress→pending, exit              |
| E011 | Pre-exit verification fail                 | Fix artifact trước khi spawn              |

---

## Related Skills

| Skill                        | Relationship                                    | Notes                                             |
| ---------------------------- | ----------------------------------------------- | ------------------------------------------------- |
| `/wf-analyze-requirements` | Upstream — sinh WF-L*.md specs                 | Prerequisite                                      |
| `/wf-test-flow`            | Sibling — test module-level features           | Dùng cho code flow, không dùng cho business WF |
| `/wf-fix-bugs`             | Companion — fix bugs khi blast radius quá cao | Invoke khi E006 escalate                          |
| `/wf-define-features`      | Upstream upstream — định nghĩa features     | Context                                           |
| `/status`                  | Standalone — xem tiến độ dự án tổng thể | Bổ sung cho --status flag                        |
