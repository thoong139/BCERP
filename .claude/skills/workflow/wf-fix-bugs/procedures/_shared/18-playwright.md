# §18 Playwright Integration Pattern

> Playwright chạy **PARALLEL dispatch + LOCK-BASED serialization** (max 1 browser instance global) — KHÔNG còn Wave 1/Wave 2 split từ v10.3.
>
> **Cơ chế:** Tất cả lanes (PW + non-PW) được orchestrator spawn SONG SONG trong 1 response. Mỗi lane PW agent TỰ acquire writer-lock trên resource `playwright` (Protocol 22, `global-rw-lock.sh`) trước khi launch browser. Lock đảm bảo tại mỗi thời điểm chỉ 1 browser instance active — không CDP port conflict, không RAM exhaustion, không state pollution. Non-PW lanes chạy hoàn toàn độc lập, KHÔNG đụng lock.
>
> **Nguồn chân lý "lane nào cần Playwright":** đọc field `needs_playwright` trong `dimension-plan.json` (Phase 3 emit). KHÔNG hardcode routing matrix trong orchestrator.
>
> **Dimension-specific Playwright focus:** Mỗi lane tự định nghĩa scope, browser matrix, evidence requirements — xem `## Playwright Usage` trong SKILL.md của từng lane:
> - `wf-fix-runtime-health/SKILL.md` — QD9: console errors, network failures, auth flows, SPA routes, CTAs, forms
> - `wf-fix-ux-a11y/SKILL.md` — QD5: axe-core, keyboard nav, ARIA, color contrast
> - `wf-fix-compat/SKILL.md` — QD7: cross-browser (Chromium/Firefox/WebKit/Edge), 4 breakpoints, i18n, env parity
> - Agent prompt (scope coverage rules + execution flow + lock acquire/release) → `templates/phase4-find-bugs/lane-agent-prompt.md`

## Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Headless** (default) | — | Chromium headless, invisible. Session-isolated. |
| **Visible** | `--show-browser` | Chromium visible window. Debug + observation. |
| **Mobile** | `--mobile` | Playwright device emulation. Auto-set `--show-browser`. |

## Mobile Device Defaults

| Device | Viewport | Pixel Ratio |
|--------|----------|-------------|
| **iPhone 14** | 390×844 | 3 |
| **Pixel 7** | 412×915 | 2.625 |
| **iPad Pro** | 1024×1366 | 2 |

## Session Isolation

```javascript
// playwright-session.js — tạo browser context riêng cho session
const browser = await chromium.launch({ headless: !showBrowser });
const context = await browser.newContext({
  ...(mobileMode ? devices[deviceName] : {}),
  storageState: sessionStoragePath  // session-isolated
});
```

## Lock-Based Serialization (v10.3+)

```
ORCHESTRATOR (KHÔNG quản lý slot, KHÔNG biết QD nào cần browser):
  └── Spawn TẤT CẢ lanes parallel trong 1 response (max 10)

LANE AGENT (đọc {{NEEDS_PLAYWRIGHT}} từ prompt — Phase 3 emit):
  IF needs_playwright == "CÓ":
    1. source .claude/scripts/wf-e2e-shared/global-rw-lock.sh
    2. acquire_writer_lock playwright "$SESSION_ID" "lane-$DIM_ID" "phase4 runtime probe"
       - RC=0  → tiếp tục (đã có lock độc quyền, browser an toàn launch)
       - RC=2  → TIMEOUT >10 phút chờ → E044, mark lane failed, exit
       - RC=1/3 → ESCALATE (env/args error)
    3. trap 'release_writer_lock playwright "$SESSION_ID"' EXIT
    4. Run Playwright probes (launch browser, navigate, capture evidence)
    5. release_writer_lock playwright "$SESSION_ID" (trap đã guard nếu crash)
  ELSE:
    Bỏ qua lock, chạy static + LLM probes ngay.

ORDERING:
  - Lock script writer-priority + FIFO trong writer_pending queue
  - playwright_priority (1=highest) là HINT, không bắt buộc — lane tự respect nếu muốn
  - Stale lock auto-cleanup (heartbeat 30s, stale threshold 2 phút)
```
