# 07 — Playwright 3 Modes

> **Mức độ ràng buộc:** Tham khảo (overview)
> **Khi nào dùng:** Skill cần browser testing (UI verification, E2E, accessibility, runtime health)

---

## 1. Vấn đề pattern giải quyết

Playwright (browser automation) trong MCV3 có nhiều use cases:
- **wf-e2e-verify**: Full live test cycle (cần browser thật, mạnh)
- **wf-fix-runtime-health (QD9)**: Detect runtime bugs (cần browser, không cần user)
- **wf-fix-ux-a11y (QD5)**: A11y audit (cần screenshot + DOM)
- **wf-design-ux**: Visual reference (đôi khi không cần)

**Vấn đề:** Mỗi skill cần Playwright theo mức độ khác nhau. Không nên "all or nothing".

**Pattern giải quyết:** 3 modes — `none`, `assisted`, `full` — skill chọn mode phù hợp.

---

## 2. Pattern definition

### 2.1. 3 modes

| Mode | Browser visible | User can intervene | Use case |
|------|-----------------|---------------------|----------|
| **none** | — (no browser) | — | Skill chạy mà không cần browser; SKIP browser probes |
| **assisted** | Yes (headed) | Yes (user can pause, take over) | Demo, debug, user oversight |
| **full** | Yes (headless hoặc headed) | No (auto) | E2E test, CI/CD, batch processing |

### 2.2. Mode selection flow

```
Skill PRE-GATE:
  Check interface_type from registry
  ├─ "api-only" → mode=none, SKIP browser probes
  └─ "web" or "mobile":
      Check --no-browser flag
      ├─ Yes → mode=none
      └─ No:
          Check --show-browser flag
          ├─ Yes → mode=assisted
          └─ No → mode=full (default for automation)
```

### 2.3. Mode-specific behaviors

```
MODE=none:
  - SKIP QD9 (runtime-health), QD5 visual probes
  - status="skipped (no browser)"
  - signals empty hoặc only static-analysis

MODE=assisted:
  - Launch Playwright headed
  - Pause at critical steps (user confirm)
  - Screenshot at each step
  - User can pause/resume/abort

MODE=full:
  - Launch Playwright headless (default) or headed if --show-browser
  - Auto-execute scenarios
  - Screenshot on failure
  - No user prompts during run
```

---

## 3. Case study — wf-fix-bugs QD9 (Runtime Health) v9.0.2

QD9 phát hiện browser-runtime bugs:
- Console errors
- Network failures
- Uncaught exceptions
- Broken auth flows
- SPA routes unreachable
- CTAs không hoạt động
- Form validation thiếu

**Mode routing:**

```
QD9 lane PRE-GATE:
   ├─ interface_type=api-only → SKIP (mode=none, status=skipped)
   ├─ --no-browser flag → SKIP
   ├─ --show-browser flag → mode=assisted
   └─ default → mode=full

Mode=full execution:
  1. Read feature spec → identify test routes
  2. Launch Playwright headless
  3. For each route:
     - browser_navigate(url)
     - browser_console_messages() → capture errors
     - browser_network_requests() → capture failures
     - browser_snapshot() → DOM check
     - browser_click(CTA buttons) → verify response
  4. Aggregate findings → signals.json
  5. browser_close()

Mode=assisted (--show-browser):
  Same as full BUT:
  - Pause after each route (5s default)
  - User can interrupt with Ctrl+C
  - Take screenshot for review
```

### 3.1. wf-e2e-verify full mode

```
wf-e2e-verify F1-F8:
  Phase F0: Pre-flight (infra health, credential vault)
  Phase F1: Set up test data (seeds)
  Phase F2: Execute test scenarios (Playwright headless)
  Phase F3: Capture evidence (screenshots, video)
  Phase F4: Verify expected outcomes
  Phase F5-F8: Cleanup + report

Mode=full mặc định. Mode=assisted khi --show-browser cho debugging.
```

### 3.2. wf-e2e-demo assisted mode

```
wf-e2e-demo: cho user xem 1 scenario chạy thật
Mode=assisted (mặc định) — user theo dõi từng bước
Pause sau mỗi click — user có thể đặt câu hỏi
```

---

## 4. Variations / Edge cases

### 4.1. Mobile mode

```
QD9 mobile-coverage:
  - browser_resize(375, 812)  # iPhone 12
  - Test responsive layouts
  - Touch event simulation

Mode vẫn là full/assisted/none, nhưng device profile khác.
```

### 4.2. Cross-browser

Playwright support: Chrome, Firefox, Safari (WebKit), Edge.

```
--browser=firefox → launch Firefox engine
Default: Chromium
```

### 4.3. CI/CD mode

```
CI environment (no display):
  ├─ Mode=assisted không khả thi
  └─ Auto switch to mode=full headless

Detect via env: $CI=true → force headless
```

### 4.4. Authentication required

```
Test route /admin requires login
   ↓
Step 1: Load credentials từ vault (wf-e2e-credentials)
Step 2: browser_fill_form(login_page, credentials)
Step 3: browser_click(submit)
Step 4: Verify redirect to /admin
Step 5: Continue test scenarios

KHÔNG bao giờ log credentials values.
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Skill hardcode `mode=full` cho api-only project | Auto-detect interface_type → mode=none |
| Mode=assisted nhưng không pause cho user | Phải có pause point + screenshot |
| Mode=full headed trong CI | Auto-switch to headless khi $CI=true |
| Log credential values vào console hoặc file | NEVER log values — chỉ status |
| Playwright crash → skill abort | Catch + log + signals partial → aggregator handle |
| browser_close() quên gọi → leak | Try/finally pattern hoặc cleanup hook |
| Mode change giữa chừng → race | Mode locked at PRE-GATE |
| Mode=none nhưng vẫn try browser tool | Check mode TRƯỚC khi call browser_* |
| Run Playwright song song với cùng base_url → port conflict | Coordinate qua Protocol 22 (R/W lock) |
| Screenshot quá nhiều → disk full | Limit per-session, prune old |

---

## 6. Checklist áp dụng

**Khi skill cần browser:**

- [ ] Define 3 modes trong SKILL.md arguments (`--no-browser`, `--show-browser`, default)
- [ ] PRE-GATE detect mode từ flags + interface_type
- [ ] SKIP browser probes nếu mode=none → signals.status="skipped"
- [ ] Mode=full default cho automation
- [ ] Mode=assisted cho demo/debug
- [ ] Auto-switch headless khi $CI=true
- [ ] Try/finally cho browser_close() (cleanup guaranteed)
- [ ] Screenshot trên failure (mode=full) hoặc mỗi step (mode=assisted)
- [ ] Coordinate qua Protocol 22 nếu nhiều skills cùng dùng infra
- [ ] Credential handling qua wf-e2e-credentials (KHÔNG hardcode)
- [ ] Document mode behavior trong SKILL.md

---

## 7. Liên kết

- **wf-fix-bugs QD9 case:** `.claude/skills/workflow/wf-fix-runtime-health/`
- **wf-e2e-verify case:** `.claude/skills/workflow/wf-e2e-verify/`
- **Credentials skill:** `.claude/skills/workflow/wf-e2e-credentials/`
- **Protocol 22 (R/W lock cho live infra):** [`.claude/skills/protocols/22-infrastructure-rw-lock.md`](../../.claude/skills/protocols/22-infrastructure-rw-lock.md)
- **Playwright tools (MCP):** mcp__plugin_playwright_playwright__browser_*
- **Related patterns:**
  - [`05-agent-prompt-template.md`](05-agent-prompt-template.md) — Section 5 Playwright Context
  - [`09-multi-session-locking.md`](09-multi-session-locking.md) — Coordinate browser infra
