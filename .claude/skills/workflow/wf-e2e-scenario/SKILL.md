---
name: wf-e2e-scenario
version: 1.3.0
last_updated: 2026-05-14
description: |
  F7 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 Phase 7 phần scenario).
  Chạy test-scenario.md (sinh bởi F1) qua Playwright MCP → fill Pass/Fail cho mỗi row + screenshots evidence.
  Cross-module scenarios LUÔN included (no --cross-module flag, default ON).
  YÊU CẦU --session=<id>, Playwright MCP available, FE running.

  TRIGGER khi: "test scenario", "kịch bản E2E", "Playwright scenario", "verify test-scenario.md".
  KHÔNG trigger: tester user-guide (dùng F8 wf-e2e-demo), pre-scan browser tests (dùng F2 wf-e2e-browser).

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
  mcp__plugin_playwright_playwright__browser_resize
---

# /wf-e2e-scenario: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Execute test-scenario.md qua Playwright MCP, điền Pass/Fail + screenshots |
| **Standalone** | NO — require `--session=<id>` |
| **Input** | `outputs/test-scenario.md` (skeleton từ F1) |
| **Output** | `screenshots/scenario-*.png`, `scenario-test-report.md`, UPDATE `outputs/test-scenario.md`, `resolution-report.md` (khi có FAIL) |
| **Browser lock** | Acquire `browser-mcp.lock` (sequential với F2 + F8) |

### Flow

```
[--session] → [PRE-GATE: test-scenario.md + Playwright avail + FE running]
→ [Acquire browser-mcp.lock]
→ [Login qua Playwright MCP] → screenshot login-result.png
→ FOR each scenario row trong test-scenario.md:
    1. Navigate đến entry URL
    2. Execute bước trong "Bước" column (click/fill/select)
    3. Verify "Kết quả mong đợi" vs DOM snapshot
    4. Capture screenshot scenario-{NN}-{slug}.png
    5. Fill "Kết quả thực tế" + "Pass/Fail" trong test-scenario.md
    6. IF FAIL → Load failure-analyzer.md:
         - Bước 1-6: collect evidence → classify (7 loại) → enrich issues.json + resolution direction
         - Bước 7 Auto-Fix (2-Phase, có quyền sửa source code):
             Phase 1 Browser Fix:
               A. TEST_SELECTOR → thử 3 selector variants (text= / data-testid / ARIA role)
               B. AUTH_FAILURE → re-login → retry scenario
               C. NETWORK 5xx → wait 3s → transient retry
               D. UI_BUG → page reload → retry scenario
               E. DATA_MISSING → tạo data qua UI → retry scenario
             Phase 2 Source Code Fix (khi Phase 1 fail hoặc không áp dụng):
               TEST_SELECTOR → spawn qa-lead → sửa selector trong test file
               AUTH_FAILURE → spawn developer → fix RBAC/permission middleware
               NETWORK_ERROR → spawn developer → fix endpoint/handler/service
               UI_BUG → spawn frontend-developer → fix component null check
               BUSINESS_RULE → spawn developer + domain expert → fix business logic
               DATA_MISSING → spawn dba → tạo seed/migration
             Post-fix: wait HMR reload → re-run scenario → verify
             UNKNOWN → SKIP (không đủ signal để fix an toàn)
         - AUTO_FIX_RESULT=PASS → override ✅ PASS; FAIL/SKIP → giữ ❌ FAIL
→ Cross-module scenarios (nếu có) → navigate xuyên module → verify reference ID + consistency
→ [Release lock]
→ Write scenario-test-report.md → Write resolution-report.md (nếu còn FAIL sau auto-fix) → DONE
```

---

## Workflow Position

```
F1 wf-e2e-test (test-scenario.md skeleton)
        │
        ▼
[F2 browser → F3 unblock → F4 implement → F5 retest → F6 fix] (orchestrator)
        │
        ▼
   ┌─────────┐
   │   F7    │ ← wf-e2e-scenario (skill này)
   │ Scenario│
   └────┬────┘
        ▼ test-scenario.md filled Pass/Fail
   F8 wf-e2e-demo (user-guide)
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | Feature ID | required |
| `--session=<id>` | Session ID (BẮT BUỘC) | required |
| `--resume` | Resume từ scenario chưa execute | - |
| `--status` | Display scenario progress + STOP | - |
| `--show-browser` | Hiển thị browser (default headless) | headless |
| `--mobile` | Test mobile viewport (375x667 iPhone SE) | desktop 1280x720 |
| `--strict-evidence` | Bất kỳ step thiếu screenshot (path null hoặc file_size < 1KB) → mark evidence_missing, status=BLOCKED | inherited from orchestrator (ON by default) |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F7 chu yeu Playwright, CI chi can cho cross-module scenario lookup.

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
├── outputs/test-scenario.md         ← F7 UPDATE (fill Pass/Fail)
├── screenshots/
│   ├── login-result.png             ← Login evidence
│   ├── scenario-01-{slug}.png       ← Per scenario row
│   ├── scenario-01-error.png        ← Error evidence (FAIL only)
│   ├── scenario-02-{slug}.png
│   └── ...
├── F7-scenario/
│   ├── status.json                  ← F7 own state
│   ├── scenario-test-report.md      ← Summary report
│   ├── resolution-report.md         ← Hướng giải quyết per FAIL (v1.1.0, optional)
│   └── Phase-report.md              ← CORE-028
└── _locks/
    └── browser-mcp.lock             ← Shared với F2, F8
```

---

## PRE-GATE (CORE-011)

1. **T1:** `outputs/test-scenario.md` tồn tại
2. **T2:** Có ≥1 scenario (parse heading `## Kịch bản N:`)
3. **T3:** Playwright MCP available (browser_navigate test call)
4. **T4:** FE running (`curl http://localhost:3000` returns 200 or 307)

Fail → E070-E073.

### PRE-GATE Lint Check (G1.1)

Sau T1-T4 PASS, chạy lint trước khi execute:

```bash
bash .claude/scripts/wf-e2e-verify/lint-scenario.sh \
  "$SESSION_DIR/outputs/test-scenario.md" --json > "$F7_DIR/lint-report.json"

BLOCK=$(jq -r '.block_execution' "$F7_DIR/lint-report.json")
if [ "$BLOCK" = "true" ]; then
  VCOUNT=$(jq -r '.violation_count' "$F7_DIR/lint-report.json")
  log_error "E080" "pre-gate-lint" "Lint FAIL: $VCOUNT violation(s) — BLOCK scenario execution"
  # Ghi lint-fixes.md để hướng dẫn sửa
  jq -r '.violations[] | "- [" + .rule + "] Line " + (.line|tostring) + ": " + .suggestion' \
    "$F7_DIR/lint-report.json" > "$F7_DIR/lint-fixes.md"
  echo "BLOCKED: Sửa lint violations trước — xem $F7_DIR/lint-fixes.md"
  exit 1
fi
```

Vi phạm bất kỳ RULE 1-6 → BLOCK, xuất `lint-fixes.md` với suggestions cụ thể.
Tham khảo: `.claude/skills/workflow/wf-e2e-finding/procedures/lint-rules.md`

### PRE-FLIGHT Flakiness Check (G1.3)

Áp dụng cho scenarios MỚI hoặc MODIFIED (phát hiện bởi `detect-modified-scenarios.sh`):

```bash
CHANGED=$(bash .claude/scripts/wf-e2e-verify/detect-modified-scenarios.sh \
  --since=HEAD~1 2>/dev/null || echo "")

if [ "$CHANGED" != "NO_CHANGED_SCENARIOS" ] && [ -n "$CHANGED" ]; then
  # Stable registry check: nếu scenario hash không đổi và <30 ngày → skip 5x check
  SCENARIO_HASH=$(sha256sum "$SESSION_DIR/outputs/test-scenario.md" | cut -d' ' -f1)
  ALREADY_STABLE=$(jq -r --arg h "$SCENARIO_HASH" \
    '.scenarios[] | select(.hash==$h and .stable==true) | .stable' \
    "$SESSION_DIR/stable-registry.json" 2>/dev/null | head -1 || echo "")

  if [ "$ALREADY_STABLE" != "true" ]; then
    # 5x stability check cho scenario mới/modified
    PASS_COUNT=0
    for RUN in $(seq 1 5); do
      # Mỗi run: reset context + execute + check result
      bash -c "mcp__plugin_playwright_playwright__browser_close 2>/dev/null; true"
      if execute_scenario_quick_check; then
        PASS_COUNT=$((PASS_COUNT + 1))
      fi
    done

    if [ "$PASS_COUNT" -eq 5 ]; then
      # Stable → ghi vào stable-registry
      STABLE_ENTRY="{\"scenario_file\":\"test-scenario.md\",\"hash\":\"$SCENARIO_HASH\",\"stable\":true,\"verified_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
      # Append to stable-registry.json
      log "PRE-FLIGHT: $PASS_COUNT/5 PASS → stable"
    elif [ "$PASS_COUNT" -ge 4 ]; then
      echo "WARN: PRE-FLIGHT suspect (${PASS_COUNT}/5 PASS) — tiep tuc voi canh bao"
    else
      # Flaky → auto-quarantine (G1.5)
      auto_quarantine "$(basename $SESSION_DIR)" "$SESSION_DIR/outputs/test-scenario.md"
      echo "BLOCKED: Scenario flaky (${PASS_COUNT}/5 PASS) → quarantine. Xem: .mc-data/work/wf-e2e-verify/quarantine/"
      exit 1
    fi
  fi
fi
```

Stable scenarios (hash không đổi, trong stable-registry) → bỏ qua 5x check để tiết kiệm thời gian.

---

## POST-GATE (CORE-012)

1. **T1:** `scenario-test-report.md` tồn tại
2. **T2:** `outputs/test-scenario.md` mỗi scenario row có cột Pass/Fail filled
3. **T3:** ≥80% scenarios có screenshot evidence (HOẶC status=BLOCKED với lý do E075)
4. **T4 (--strict-evidence):** MỌI step có screenshot tồn tại + file_size ≥ 1KB. Thiếu bất kỳ → mark evidence_missing, status=BLOCKED

Fail → auto-fix retry x3 → E078.

---

## Browser Lock Strategy

```
1. Acquire $SESSION_DIR/_locks/browser-mcp.lock
   - Lock file: PID + ISO timestamp
   - TTL: 30 min (auto-release nếu stale)
2. Hold suốt F7 session
3. Release ngay sau F7 done (cuối phase hoặc error)
4. Conflict với F2/F8 → WAIT (poll 10s, max 5 lần) → E074 nếu vẫn locked
```

---

## --resume + --status

Xem `procedures/resume-status.md`.

**--status:** Display scenario table (idx | name | status | screenshot exists) + STOP.
**--resume:** Skip scenarios đã có screenshot + Pass/Fail filled. Execute remaining.

---

## Error Codes (E070-E081)

| Code | Mô tả |
|------|-------|
| E070 | test-scenario.md không tồn tại / empty |
| E071 | Playwright MCP không available |
| E072 | FE không running |
| E073 | Login fail (auth issue) |
| E074 | browser-mcp.lock conflict |
| E075 | Scenario navigate fail (URL không hợp lệ) |
| E076 | Snapshot không match expected (UI bug) → append issues.json → failure-analyzer |
| E077 | Screenshot capture fail |
| E078 | POST-GATE T4 fail (BR mismatch) |
| E079 | Atomic write fail (test-scenario.md update) |
| E080 | Failure analysis inconclusive (UNKNOWN) — warning only, không block |
| E081 | Evidence collection partial (console/network unavailable) — warning only, không block |
| E082 | Auto-fix exhausted — đã thử nhưng vẫn fail, giữ FAIL gốc — warning only, không block |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` (F1) | Producer test-scenario.md skeleton |
| `wf-e2e-browser` (F2) | Shares browser-mcp.lock, đã chạy pre-scan/browser tests |
| `wf-e2e-demo` (F8) | Shares browser-mcp.lock, runs sau F7 |
| `wf-e2e-verify` orchestrator | Spawn F7 sau F6 |

---

## Backward Compatibility

Legacy `/wf-e2e-verify <FEAT-ID> --playwright-mcp` → orchestrator detect → spawn F7 + F8 trong sequence.
Legacy `--phase=7` → alias `--from-step=F7` (run F7 + F8).
