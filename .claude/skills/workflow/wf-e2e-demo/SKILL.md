---
name: wf-e2e-demo
version: 1.2.0
last_updated: 2026-09-12
description: |
  F8 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 Phase 7 phần user-guide).
  Chạy user-guide.md (sinh bởi F1) qua Playwright MCP → demo từng bước hướng dẫn → verify accuracy +
  capture screenshots cho non-specialist. Optionally update user-guide.md khi mismatch.

  v1.1.0: Thêm auto-fix loop khi step fail. Phân biệt accuracy_wording (text diff nhẹ) vs real_failure
  (element missing / network 4xx-5xx / JS bug / missing data). Real_failure → delegate F7
  failure-analyzer (2-phase: browser-fix → agent source fix). DATA_MISSING →
  apply seed data từ findings/db-seed-data.md trước khi thử tạo qua UI. Mọi step fail APPEND issues.json
  NGAY (ISSUE-IMMEDIATE pattern giống F1/F7), không chờ POST-GATE.

  YÊU CẦU --session=<id>, Playwright MCP available, FE running.

  TRIGGER khi: "demo user-guide", "verify hướng dẫn", "Playwright user-guide", "kiểm tra docs accuracy".
  KHÔNG trigger: test scenarios (dùng F7 wf-e2e-scenario), pre-scan browser (dùng F2 wf-e2e-browser).

argument-hint: "<FEAT-ID> --session=<id> [--resume] [--status] [--show-browser] [--mobile]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__plugin_playwright_playwright__browser_navigate,
  mcp__plugin_playwright_playwright__browser_snapshot,
  mcp__plugin_playwright_playwright__browser_click,
  mcp__plugin_playwright_playwright__browser_type,
  mcp__plugin_playwright_playwright__browser_fill_form,
  mcp__plugin_playwright_playwright__browser_wait_for,
  mcp__plugin_playwright_playwright__browser_take_screenshot,
  mcp__plugin_playwright_playwright__browser_evaluate,
  mcp__plugin_playwright_playwright__browser_close,
  mcp__plugin_playwright_playwright__browser_resize
---

# /wf-e2e-demo: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Execute user-guide.md qua Playwright → verify accuracy + auto-fix step fail + screenshots |
| **Prerequisites** | `outputs/user-guide.md` (skeleton từ F1, ≥1 "Bước N") + `--session=<id>` BẮT BUỘC + Playwright MCP + FE running (PRE-GATE T1-T4) |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | `outputs/user-guide.md` (skeleton từ F1), `findings/db-seed-data.md` (cho DATA_MISSING fix) |
| **Output** | `screenshots/demo-*.png`, `demo-report.md`, ISSUES APPEND (real_failure), corrections (accuracy_wording) |
| **Browser lock** | Shared với F2, F7 + cross-session R/W locks (BE/FE/DB/Playwright) |
| **Auto-fix** | accuracy_wording → log correction / --auto-correct. real_failure → delegate F7 failure-analyzer (Phase 1+2) |
| **Issue logging** | ISSUE-IMMEDIATE: APPEND issues.json NGAY khi step match != exact (không chờ POST-GATE) |

### Flow

```
[--session] → [PRE-GATE: user-guide.md + Playwright + FE/BE/DB + R/W locks]
→ [Acquire browser-mcp.lock + reader locks cross-session]
→ [Login] → screenshot demo-00-login.png
→ Parse user-guide.md → identify steps (theo định dạng "Bước N: ...")
→ FOR each step:
    1. Read step description
    2. Execute action (navigate / click / fill)
    3. Verify expected state (DOM snapshot) → match = exact|partial|none
    4. Capture screenshot demo-{NN}-{slug}.png
    5. IF match != exact:
       → APPEND issues.json NGAY (severity theo classify)
       → CLASSIFY: accuracy_wording vs real_failure
       → accuracy_wording: log correction (auto-correct nếu --auto-correct)
       → real_failure: delegate F7 failure-analyzer
           • Phase 1 (browser fix): selector fallback / re-login / transient retry /
             page reload / SEED DATA APPLY từ findings/db-seed-data.md / UI create
           • Phase 2 (source code fix): spawn agent (developer / frontend-developer /
             dba / domain-expert) → wait HMR → re-verify
           • Update issues.json auto_fix object
       → IF auto_fix PASS → mark ✅ (auto-fixed), continue
       → IF auto_fix FAIL → mark ❌ (ISS-NNN), log resolution, continue
→ [Release locks]
→ Write demo-report.md với accuracy assessment + auto-fix log + corrections
→ DONE
```

---

## Workflow Position

```
F1 wf-e2e-test (user-guide.md skeleton + ui-mapping.md)
        │
        ▼
[F2-F7 orchestrator pipeline]
        │
        ▼
   ┌─────────┐
   │   F8    │ ← wf-e2e-demo (skill này, last step)
   │  Demo   │
   └────┬────┘
        ▼
   Orchestrator finalize (CORE-028 summary)
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID | required |
| `--resume` | Resume từ step chưa demo | - |
| `--status` | Display demo progress + STOP | - |
| `--show-browser` | Hiển thị browser | headless |
| `--mobile` | Mobile viewport 375x667 | desktop 1280x720 |
| `--auto-correct` | Auto-update user-guide.md nếu phát hiện mismatch | disabled |
| `--strict-evidence` | Bất kỳ step thiếu screenshot (path null hoặc file_size < 1KB) → mark evidence_missing, status=BLOCKED | inherited from orchestrator (ON by default) |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F8 chu yeu Playwright, CI chi can cho user-guide lookup.

## Phase 0: Verify User-Guide & Lock (BẮT BUỘC — entry point)

> Chi tiết: `procedures/verify-userguide.md`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | Acquire `browser-mcp.lock` + reader locks cross-session (BE/FE/DB/Playwright) | Lock OK; conflict → E084 |
| 2 | PRE-GATE T1-T2: `outputs/user-guide.md` tồn tại + ≥1 step ("**Bước N:**") | Fail → E080 |
| 3 | CI PRE-GATE Na-Nc + PRE-GATE T3-T4: Playwright available + FE running | Fail → E081/E082 |
| 4 | Login → screenshot demo-00-login.png | Login OK; fail → E083 |

## Phase Routing Map (CORE-032 lazy-load)

| # | Phase | Procedure file | Mô tả |
|---|-------|---------------|-------|
| **0** | Verify + Lock | `procedures/verify-userguide.md` | PRE-GATE + parse user-guide steps + login |
| **1** | Demo per step | `procedures/userguide-runner.md` | Execute → verify → screenshot → classify (exact/partial/none) |
| **2** | Auto-fix loop | `procedures/userguide-runner.md` §auto-fix | accuracy_wording → correction; real_failure → delegate F7 failure-analyzer (Phase 1 browser-fix + Phase 2 source fix) |
| **3** | Report | `procedures/userguide-runner.md` §report | demo-report.md + accuracy score + corrections |
| **R** | Resume/Status | `procedures/resume-status.md` | --resume / --status handlers |

CI PRE-GATE steps (Na-Nc):

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` (reserved). | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `project_structure` | Serena `get_symbols_overview` | Glob |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── outputs/user-guide.md            ← F8 READ + (optional UPDATE)
├── screenshots/
│   ├── demo-00-login.png            ← Initial state
│   ├── demo-{NN}-{slug}.png         ← Per step demo
│   └── ...
├── F8-demo/
│   ├── status.json                  ← F8 own state
│   ├── demo-report.md               ← Accuracy assessment + corrections
│   └── Phase-report.md              ← CORE-028
└── _locks/
    └── browser-mcp.lock             ← Shared với F2, F7
```

---

## PRE-GATE (CORE-011)

1. **T1:** `outputs/user-guide.md` tồn tại
2. **T2:** Có ≥1 step (parse "**Bước N:**" hoặc "## Bước N")
3. **T3:** Playwright MCP available
4. **T4:** FE running

---

## POST-GATE (CORE-012)

1. **T1:** `demo-report.md` tồn tại
2. **T2:** ≥1 screenshot demo-*.png capture (HOẶC status=BLOCKED với lý do E085)
3. **T3:** Accuracy score ≥70% (số step verify match ≥70%)
4. **T4 (--strict-evidence):** MỌI step.screenshot.path tồn tại + file_size ≥ 1KB. Thiếu bất kỳ → E086 evidence_missing, status=BLOCKED

Fail → auto-fix retry x3 → E088.

---

## Demo Accuracy Assessment

Mỗi step trong user-guide.md có:
- **Description**: Hành động user phải làm
- **Expected outcome**: Kết quả mong đợi

F8 verify:
1. Action có thực hiện được trong UI hiện tại? → YES/NO
2. Element selector (button label, link text) còn tồn tại? → YES/NO/CHANGED
3. Expected outcome có match DOM state sau action? → YES/NO/PARTIAL

Accuracy score = (số step YES + 0.5 × số PARTIAL) / total steps × 100%

| Score | Verdict |
|-------|---------|
| ≥90% | Excellent — user-guide chính xác |
| 70-89% | Good — minor corrections cần thiết |
| 50-69% | Needs revision — corrections trong demo-report.md |
| <50% | Outdated — user-guide cần re-generate (F1 phase 6 lại) |

---

## Correction Logging

Khi phát hiện mismatch (KHÔNG auto-correct mặc định):

```markdown
## Corrections needed (demo-report.md)

### Step 3: Click button "Tạo Customer"
- **user-guide.md says:** Click button "Tạo Customer"
- **Actual UI:** Button label changed to "Tạo Khách Hàng" (i18n key crm.customer.create)
- **Recommendation:** Update user-guide.md step 3 từ "Tạo Customer" → "Tạo Khách Hàng"
- **OR:** Verify i18n key consistency với business-rule-catalog.md

### Step 5: Verify "Lưu thành công" toast
- **user-guide.md says:** Wait toast "Lưu thành công"
- **Actual UI:** Toast text "Tạo khách hàng thành công"
- **Recommendation:** Update user-guide.md step 5
```

Với `--auto-correct`: Apply corrections vào user-guide.md (atomic write).

---

## --resume + --status

Xem `procedures/resume-status.md`.

---

## Error Handling

Codes E080-E089 (per-skill namespace):

| Code | Mô tả |
|------|-------|
| E080 | user-guide.md không tồn tại / empty |
| E081 | Playwright không available |
| E082 | FE không running |
| E083 | Login fail |
| E084 | Browser lock conflict |
| E085 | Navigate fail (URL trong user-guide không hợp lệ) |
| E086 | Action không execute được (element không tồn tại) |
| E087 | Expected state mismatch |
| E088 | POST-GATE accuracy <50% |
| E089 | Atomic write fail (user-guide update) |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Step mismatch accuracy_wording (E087 nhẹ) | Log correction vào demo-report.md; apply vào user-guide.md khi `--auto-correct` (atomic write) | User review corrections khi không có --auto-correct |
| Step real_failure (E086/E087 nặng) | Delegate F7 failure-analyzer 2-phase: browser-fix (selector fallback, re-login, seed data apply từ db-seed-data.md) → source fix (spawn agent, wait HMR, re-verify) | Auto-fix FAIL → mark ❌ ISS-NNN, APPEND issues.json NGAY (ISSUE-IMMEDIATE) |
| FE không running (E082) | Auto-start FE (retry ×2) | Vẫn fail → ESCALATE user |
| Accuracy <50% (E088) | KHÔNG auto-fix — verdict "Outdated" → user-guide cần re-generate | User quyết định chạy lại F1 phase 6 hay không |
| Atomic write fail (E089) | Restore từ temp file rồi write lại | Temp hỏng — STOP, báo disk issue |

---

## Output Files

| File | Path (trong session) | Loại |
|------|----------------------|------|
| demo-report.md + Phase-report.md (CORE-028) | `F8-demo/` | CREATE |
| demo-00-login.png + demo-{NN}-{slug}.png | `screenshots/` | CREATE |
| issues.json | session root | APPEND (real_failure, ISSUE-IMMEDIATE) |
| user-guide.md | `outputs/` | READ + optional UPDATE (--auto-correct) |

> **Next:** F8 là bước cuối trong pipeline — orchestrator `/wf-e2e-verify` finalize CORE-028 summary sau F8.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` (F1) | Producer user-guide.md + ui-mapping.md |
| `wf-e2e-scenario` (F7) | Shares browser-mcp.lock |
| `wf-e2e-browser` (F2) | Shares browser-mcp.lock |
| `wf-e2e-verify` orchestrator | Spawn F8 sau F7 |
