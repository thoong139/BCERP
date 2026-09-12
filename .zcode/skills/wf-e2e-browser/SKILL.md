---
name: wf-e2e-browser
version: 1.2.0
last_updated: 2026-09-12
description: |
  F2 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 Phase 7 pre-scan + browser execution).
  Pre-scan F1 outputs (ui-test-report, integration-test-report, test-scenario.md) → tìm tests cần
  browser execution (UI rendering, runtime validation, RBAC UI). Execute qua Playwright MCP.
  Live browser BẮT BUỘC. FE/Playwright/BE chưa sẵn sàng → MANDATORY auto-start (retry 2 lần);
  fail → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion. KHÔNG có cờ --no-playwright,
  KHÔNG silent fallback static analysis.
  Block classification 4 nhóm — Nhóm 3 DUAL-WRITE implement-required.json (F4 consume),
  Nhóm 4 (visual/real payment/OAuth/hardware) verify code → DUAL-WRITE manual.json (QA consume).
  KHÔNG chạy test-scenario.md (F7). YÊU CẦU --session=<id>.

  TRIGGER khi: "browser pre-scan", "execute browser-only tests", "UI runtime verify".
  KHÔNG trigger: test scenarios (F7), user-guide demo (F8), code-based test (F1).

argument-hint: "<FEAT-ID> --session=<id> [--resume] [--status] [--show-browser] [--mobile]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__plugin_playwright_playwright__browser_navigate,
  mcp__plugin_playwright_playwright__browser_snapshot,
  mcp__plugin_playwright_playwright__browser_click,
  mcp__plugin_playwright_playwright__browser_type,
  mcp__plugin_playwright_playwright__browser_fill_form,
  mcp__plugin_playwright_playwright__browser_select_option,
  mcp__plugin_playwright_playwright__browser_wait_for,
  mcp__plugin_playwright_playwright__browser_take_screenshot,
  mcp__plugin_playwright_playwright__browser_evaluate,
  mcp__plugin_playwright_playwright__browser_console_messages,
  mcp__plugin_playwright_playwright__browser_network_requests,
  mcp__plugin_playwright_playwright__browser_close,
  mcp__plugin_playwright_playwright__browser_resize,
  mcp__serena__find_symbol, mcp__serena__search_for_pattern
---

# /wf-e2e-browser: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Pre-scan F1 reports tìm tests cần browser + execute qua Playwright MCP |
| **Prerequisites** | F1 wf-e2e-test outputs (ui-test-report.md, integration-test-report.md, test-scenario.md) + `--session=<id>` BẮT BUỘC + Playwright MCP/FE/BE/DB running hoặc auto-start được (PRE-GATE T1-T4) |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | F1 outputs (ui-test-report.md, integration-test-report.md, test-scenario.md, block-test.json, issues.json) |
| **Output** | `screenshots/browser-*.png`, `browser-test-report.md`, APPEND issues/block-test/implement-required/manual |
| **Browser lock** | Acquire `browser-mcp.lock` (sequential với F7, F8) |
| **KHÔNG chạy** | test-scenario.md execution (F7), user-guide demo (F8) |

### Flow

```
[--session] → [PRE-GATE: F1 reports + Playwright + FE running]
→ [Acquire browser-mcp.lock]
→ Pre-scan F1 reports:
  - ui-test-report.md → tìm UI checks FAIL/PENDING/⬜ cần browser verify
  - integration-test-report.md → tìm integration tests có UI component
  - block-test.json → tìm browser-related blocks
  - issues.json → tìm issues type=ui-runtime
→ [Login qua Playwright] → screenshot login-result.png
→ FOR each browser-blocked test:
    1. Navigate đến UI relevant
    2. Execute action (form fill, button click, RBAC role switch, ...)
    3. Snapshot + verify expected
    4. Capture screenshot browser-{slug}.png
    5. IF fail → classify (4 nhóm) → DUAL-WRITE block-test + (implement-required | manual)
    6. APPEND issues.json nếu là bug runtime
→ Write browser-test-report.md
→ Release lock → DONE
```

---

## Workflow Position

```
F1 wf-e2e-test (findings/* + outputs/*)
        │
        ▼
   ┌─────────┐
   │   F2    │ ← wf-e2e-browser (skill này)
   │ Browser │ pre-scan + execute browser-only
   │ Pre-scan│
   └────┬────┘
        ▼ block-test.json + implement-required.json + manual.json updated
   F3 unblock → F4 implement → F5 retest → F6 fix → F7 scenario → F8 demo
```

F2 KHÔNG chạy test-scenario.md (đó là F7 wf-e2e-scenario). F2 KHÔNG chạy user-guide demo (đó là F8). F2 chỉ verify tests cần BROWSER ngữ cảnh (UI rendering, JS runtime validation, RBAC).

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID (BẮT BUỘC) | required |
| `--resume` | Resume từ test chưa execute | - |
| `--status` | Display browser pre-scan progress + STOP | - |
| `--show-browser` | Hiển thị browser | headless |
| `--mobile` | Mobile viewport | desktop |
| `--strict-evidence` | Bất kỳ step thiếu screenshot (path null hoặc file_size < 1KB) → mark evidence_missing, status=BLOCKED | inherited from orchestrator (ON by default) |

> **Đã bỏ `--no-playwright`** (v1.1.0). Live browser BẮT BUỘC. FE/Playwright/BE chưa sẵn sàng → MANDATORY auto-start (retry 2 lần) → fail → ESCALATE Nhóm 2.

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F2 chu yeu Playwright, CI chi can cho pre-scan code lookup.

## Phase 0: Pre-Scan & Lock (BẮT BUỘC — entry point)

> Chi tiết: `procedures/pre-scan.md` + `procedures/_shared.md`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | Acquire `browser-mcp.lock` (shared với F7, F8) | Lock OK; conflict → E023 |
| 2 | PRE-GATE T1-T2: F1 outputs tồn tại + schema valid | Fail → E020 |
| 3 | CI PRE-GATE Na-Nc (bảng dưới) | CI flags set |
| 4 | Pre-scan 4 sources (ui-test-report, integration-test-report, block-test, issues) → `pre-scan-report.md` | ≥1 test cần browser (T3); 0 test → early exit sạch |
| 5 | PRE-GATE T4: Playwright + FE + BE + DB running (auto-start mandatory, retry ×2) | Fail → E021 ESCALATE Nhóm 2 |

CI PRE-GATE steps (Na-Nc):

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. Graceful: lock held -> fallback Grep. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` (reserved). | CI context ready |

## Phase Routing Map (CORE-032 lazy-load)

| # | Phase | Procedure file | Mô tả |
|---|-------|---------------|-------|
| **0** | Pre-Scan & Lock | `procedures/pre-scan.md` | Lock + PRE-GATE + pre-scan 4 sources |
| **1** | Login | `procedures/browser-execute.md` §login | Login qua Playwright + screenshot login-result.png |
| **2** | Execute per test | `procedures/browser-execute.md` | Navigate → action → snapshot verify → screenshot → classify |
| **3** | Block classification | `procedures/block-classification.md` | 4 nhóm — Nhóm 3/4 DUAL-WRITE |
| **4** | Report | `procedures/browser-execute.md` §report | browser-test-report.md + release lock |
| **R** | Resume/Status | `procedures/resume-status.md` | --resume / --status handlers |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `project_structure` | Serena `get_symbols_overview` | Glob |
| `find_by_annotation` | Serena `find_referencing_symbols` | Grep |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── findings/ui-test-report.md       ← READ
├── findings/integration-test-report.md ← READ
├── outputs/test-scenario.md         ← READ context (KHÔNG execute)
├── block-test.json                  ← APPEND
├── implement-required.json          ← APPEND (Nhóm 3)
├── manual.json                      ← APPEND (Nhóm 4 verified-OK)
├── issues.json                      ← APPEND (ui-runtime bugs)
├── F2-browser/
│   ├── status.json                  ← F2 own state
│   ├── pre-scan-report.md           ← Pre-scan output (list tests cần browser)
│   ├── browser-test-report.md       ← Execution results
│   └── Phase-report.md              ← CORE-028
├── screenshots/
│   ├── login-result.png
│   └── browser-{slug}.png
└── _locks/
    └── browser-mcp.lock             ← Shared với F7, F8
```

---

## Pre-Scan Logic

Đọc 4 sources, tìm browser-related tests:

### 1. ui-test-report.md

```
- Find sections "FAIL", "PENDING", "⬜" với reason có chứa:
  - "needs browser verification"
  - "runtime validation"
  - "RBAC UI"
  - "responsive"
  - "animation"
- Output: list of UI test refs cần browser
```

### 2. integration-test-report.md

```
- Find tests có UI component (vd: form submit through UI, RBAC at UI level)
- Skip tests purely API-level (đó là Phase 3 F1 đã làm)
```

### 3. block-test.json

```
- Find entries blocking_reason ∈ {requires_visual_inspection, requires_manual_interaction}
- Cần execute qua Playwright nếu có thể automate
```

### 4. issues.json

```
- Find entries type=ui đã fix (status=fixed) cần re-verify trong browser
```

Output `pre-scan-report.md`:

```markdown
# Pre-Scan Report — F2 wf-e2e-browser

## Tests cần browser execute

| Source | Test ref | Lý do | Priority |
|--------|----------|-------|----------|
| ui-test-report | RBAC sales-manager dashboard | runtime check role gate | P0 |
| integration-test | login form validation | UI runtime + network | P1 |
| block-test BLK-005 | visual inspection of toast | requires_visual_inspection | P2 |
| ... |

Total: 8 tests
```

---

## Execution Pattern

Cho mỗi test trong pre-scan list:

```bash
# 1. Navigate
mcp__playwright__browser_navigate --url=$URL

# 2. Login if needed (per RBAC test, switch role)
perform_login_with_role $ROLE

# 3. Execute action
# (Click button / fill form / select option)

# 4. Snapshot + verify
SNAPSHOT=$(mcp__playwright__browser_snapshot)
verify_expected $EXPECTED

# 5. Capture
mcp__playwright__browser_take_screenshot --output="$SCREENSHOTS/browser-${SLUG}.png"

# 6. Classify result
if PASS:
  → mark test resolved trong report
elif FAIL_BUG:
  → APPEND issues.json (severity=high, type=ui-runtime)
elif FAIL_BLOCKED:
  → CLASSIFY 4 nhóm:
    - Group 1/2: try auto-fix → retest
    - Group 3 (feature not impl): DUAL-WRITE block-test + implement-required
    - Group 4 (hard test): VERIFY CODE → DUAL-WRITE block-test + manual
```

---

## PRE-GATE (CORE-011)

1. **T1:** F1 outputs tồn tại (`findings/ui-test-report.md`, `outputs/test-scenario.md`)
2. **T2:** Schema valid
3. **T3:** Có ≥1 test cần browser (post pre-scan check)
4. **T4:** Playwright MCP available + FE + BE + DB running. Auto-start mandatory nếu chưa chạy (qua `ensure_infrastructure_running fe/backend/db`). Auto-start fail sau 2 retry → ESCALATE Nhóm 2 (block-test.json), KHÔNG fallback static.

Fail → E020 (F1 outputs missing) hoặc E021 (Playwright/FE/BE/DB không chạy sau auto-start, đã ESCALATE).

---

## POST-GATE (CORE-012)

1. **T1:** `pre-scan-report.md` + `browser-test-report.md` tồn tại
2. **T2:** Mỗi pre-scan entry có row trong browser-test-report
3. **T3:** Screenshots tồn tại cho ≥80% executed tests
4. **T4:** Nhóm 3 → có related_impl_req_id link; Nhóm 4 → có related_manual_id link

Fail → auto-fix retry x3 → E028.

---

## --resume + --status

Xem `procedures/resume-status.md`.

---

## Error Handling

Codes E020-E029 (per-skill namespace):

| Code | Mô tả |
|------|-------|
| E020 | F1 outputs không đủ |
| E021 | Playwright không available hoặc FE không running |
| E022 | --session thiếu |
| E023 | Browser lock conflict |
| E024 | Login fail |
| E025 | Navigate fail |
| E026 | Snapshot mismatch (UI bug → ISSUE) |
| E027 | Screenshot fail |
| E028 | POST-GATE cross-ref fail |
| E029 | Atomic write fail |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| FE/Playwright/BE/DB chưa chạy (E021) | MANDATORY auto-start qua `ensure_infrastructure_running` (retry ×2) — KHÔNG fallback static analysis | Auto-start fail sau 2 retry → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion |
| Login fail (E024) | Retry login ×2 với same credentials (credential inject qua env từ vault) | Vẫn fail → classify theo 4 nhóm (thường Nhóm 4 requires_3rd_party_login) |
| Snapshot mismatch (E026) | KHÔNG auto-fix — đây là UI bug thật → APPEND issues.json (severity=high, type=ui-runtime) | Bug blocker → DUAL-WRITE block-test + route F6 wf-e2e-fix |
| Screenshot thiếu/<1KB (E027, strict-evidence) | Re-capture screenshot ×1 | Vẫn thiếu → mark evidence_missing, status=BLOCKED |
| POST-GATE cross-ref fail (E028) | Auto-fix retry ×3 (link lại Nhóm 3→implement-required, Nhóm 4→manual) | Hết 3 retries — STOP phase |
| Browser lock conflict (E023) | Chờ lock release (F7/F8 đang giữ) rồi retry acquire | Vẫn conflict sau timeout → hỏi user kill session nào giữ lock |

---

## Output Files

| File | Path (trong session) | Loại |
|------|----------------------|------|
| pre-scan-report.md | `F2-browser/` | CREATE |
| browser-test-report.md | `F2-browser/` | CREATE |
| Phase-report.md (CORE-028) | `F2-browser/` | CREATE |
| login-result.png + browser-{slug}.png | `screenshots/` | CREATE |
| issues.json / block-test.json / implement-required.json / manual.json | session root | APPEND (DUAL-WRITE khi block) |

> **Next:** F2 xong → F3 `/wf-e2e-unblock` (giải blocks) → F4 `/wf-e2e-implement`; trong pipeline dùng `/wf-e2e-verify`.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` (F1) | Producer ui-test-report, integration-test-report, test-scenario, block-test, issues |
| `wf-e2e-scenario` (F7) | Shares browser-mcp.lock; F7 chạy SCENARIOS, F2 chạy individual browser tests |
| `wf-e2e-demo` (F8) | Shares browser-mcp.lock; F8 chạy USER-GUIDE, F2 verify UI runtime |
| `wf-e2e-unblock` (F3) | F3 xử lý block-test entries F2 đã append |
| `wf-e2e-implement` (F4) | F4 xử lý implement-required entries F2 đã append |
| `wf-e2e-verify` orchestrator | Spawn F2 sau F1 |
