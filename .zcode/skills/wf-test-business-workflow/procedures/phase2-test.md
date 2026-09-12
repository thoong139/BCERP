# Procedure: Phase 2 TEST — WRITE → RUN/FIX → MCP VERIFY — wf-test-business-workflow

> **Triết lý:** Viết test script trước (ground truth), chạy và fix code đến sạch, cuối cùng dùng
> Playwright MCP như một manual user để lấy evidence. Test script trở thành regression suite
> có thể tái sử dụng, không phải one-shot session.

## PRE-GATE

`analysis_status=done && BE/FE running`

## Step 2.1 — Sinh E2E Spec File

```
Input:  SESSION_DIR/workflows/{WF-id}-analysis.md
        $TEST_ACCOUNTS_PATH (test accounts)
Output: apps/erp-web/e2e/wf/{WF-id}.spec.ts

Đọc template: templates/wf.spec.ts.template
Populate từ analysis:
  - BASE_URL = $FE_BASE_URL (machine config, default http://localhost:3000)
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

## Step 2.2 — Chạy Test Lần Đầu (Baseline)

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

## Step 2.3 — Fix Loop (Lặp Đến Sạch — Không Giới Hạn)

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

     b. Fix theo classification (chi tiết Auto-Fix Strategy: SKILL.md §Fix Rules):
        BUILD_ERROR      → Serena fix TypeScript/import errors
        TEST_BRITTLE     → Edit .spec.ts: selector / wait_for
        RENDER_TIMING    → Edit .spec.ts: thêm waitForLoadState / waitForSelector
        DATA_STATE       → Thêm beforeAll seed via API / tạo fixture
        AUTH_EXPIRED     → Update storageState logic trong test
        MISSING_ENDPOINT → Implement endpoint + command handler trong apps/backend/
                           (MapGet/MapPost → Command/Query → Handler)
                           → đợi backend rebuild $BE_REBUILD_WAIT_SEC (default 90s)
        BACKEND_BUG      → Serena fix handler / validator / business rule → đợi rebuild
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

## Step 2.4 — MCP Verify (Evidence + Final Smoke)

```
Mục đích: xác nhận bằng mắt người dùng sau khi scripts đã pass, lấy screenshot evidence.

1. browser_navigate  → $FE_BASE_URL/vi/login
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

## Step 2.5 — Record Results

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

## POST-GATE

`pnpm e2e exit 0 && screenshots ≥1 && spec file tồn tại`
→ `next_action = "narrate_pending"` (test_status=pass) hoặc `"narrate_skip"` (partial/fail → Phase 4 với status tương ứng)
