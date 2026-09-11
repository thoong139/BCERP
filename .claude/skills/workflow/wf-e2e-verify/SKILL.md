---
name: wf-e2e-verify
version: 8.0.0
last_updated: 2026-05-15
description: |
  ORCHESTRATOR — điều phối 11 sub-skills wf-e2e-* để test E2E 1 feature đầy đủ.
  Flow: F0 infra-check (mandatory) → F0a wf-e2e-finding (mandatory, FIND only)
  → [F0b wf-e2e-seed-manifest conditional] → F1 wf-e2e-test (live-test, consume F0a)
  → F2 wf-e2e-browser → [F3 unblock] → [F4 implement] → F5 retest → [F6 fix]
  → F7 wf-e2e-scenario → F8 wf-e2e-demo.

  Cross-module + Parallel-safe LUÔN ON. --strict-evidence ON by default (screenshot bắt buộc F2/F7/F8).
  Backward-compat: silent accept legacy flags + WARN deprecation.

  v8.0.0 (2026-05-15): Tier 0 Foundation Refactor — thêm F0/F0a/F0b. F0a tách FIND khỏi F1.
  Context checkpoint G4 sau F0a: suggest /clear + --resume trước F1 nếu context > 50%.
  v7.0.0 (2026-05-13): MAJOR REFACTOR — chia tách monolithic v6.5.0 thành 8 sub-skills.

  TRIGGER khi: "test feature", "kiểm thử", "e2e", "kịch bản thao tác", "hướng dẫn sử dụng", "full E2E pipeline".
  KHÔNG trigger: spec chưa có code (dùng /wf-implement-feature trước), audit DEVKIT, performance/security test.

argument-hint: "<FEAT-ID> [--phase=<0-7>|--from-step=<F0-F8>] [--resume] [--session=<id>] [--status] [--auto] [--skip=<F2,F3,F4,F6>] [--no-playwright] [--show-browser] [--mobile] [--strict-evidence] [--no-seed] [LEGACY: --fix=<path>] [LEGACY: --retest] [LEGACY: --unblock-test] [LEGACY: --playwright-mcp] [LEGACY: --cross-module] [LEGACY: --parallel-safe]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent
---

# /wf-e2e-verify: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | ORCHESTRATOR — không tự test, gọi 8 sub-skills sequential với conditional skip |
| **Standalone** | YES — entry point chính, tạo session mới nếu thiếu `--session` |
| **Cross-module + Parallel-safe** | LUÔN ON (default, không cần flag) |
| **Backward-compat** | Legacy flags được map sang behavior mới + WARN |
| **Input** | `<FEAT-ID>` |
| **Output** | `e2e-status.json` (SSOT 8-step), `orchestrator-summary.md`, `phase-summary.md` + tất cả outputs của F1-F8 |

### Flow tổng quan

```
ENTRY (FEAT-ID) → init session + e2e-status.json + .lock
   │
   ▼ F1 wf-e2e-test (mandatory) — Phase 0-6 code-based
   │   produces: findings/, outputs/{test-scenario,user-guide}.md skeleton,
   │             issues.json, block-test.json, implement-required.json, manual.json
   │
   ▼ F2 wf-e2e-browser (BẮT BUỘC — live browser, auto-start mandatory)
   │   pre-scan F1 reports → execute browser-only tests
   │   APPENDS: issues, block-test, implement-required, manual
   │
   ▼ DECIDE F3: block-test.json có entries status=blocked?
   │   NO  → skip F3
   │   YES → F3 wf-e2e-unblock (Groups 1+2+4; Group 3 → F4)
   │
   ▼ DECIDE F4: implement-required.json có pending?
   │   NO  → skip F4
   │   YES → F4 wf-e2e-implement (DELEGATE wf-implement-feature)
   │         MARK retest_after_impl=true
   │
   ▼ F5 wf-e2e-retest (Playwright BẮT BUỘC cho UI, auto-start mandatory)
   │
   ▼ DECIDE F6: issues.json có status=open?
   │   NO  → skip F6
   │   YES → F6 wf-e2e-fix (continuous loop, max 3 retry/issue)
   │         → orchestrator anti-loop: max 3 vòng F6↔F5
   │
   ▼ F7 wf-e2e-scenario (Playwright BẮT BUỘC, auto-start mandatory)
   │
   ▼ F8 wf-e2e-demo (Playwright BẮT BUỘC, auto-start mandatory)
   │
   ▼ FINALIZE: orchestrator-summary.md, phase-summary.md (CORE-028), release locks
```

---

## Sub-Skills Reference

| Step | Skill | Phase Mapping | Mandatory? | Output |
|------|-------|---------------|------------|--------|
| **F0** | `wf-e2e-infra-check` | Infra validation trước toàn bộ pipeline | YES (never skip) | infra-blockers.json |
| **F0a** | `wf-e2e-finding` | FIND only: Business+DB+API+UI mapping | YES (never skip) | findings/ 8 files + 4 SSOT JSONs rỗng |
| **F0b** | `wf-e2e-seed-manifest` | Seed data manifest | CONDITIONAL (seed-requirements.json + !--no-seed) | seed manifest |
| **F1** | `wf-e2e-test` | Live test code-based: DB+API+UI+Integration | YES | db/api/ui/integration test reports, SSOT JSONs |
| **F2** | `wf-e2e-browser` | Browser pre-scan + execute | DEFAULT (degraded_no_browser với --no-playwright — G2) | screenshots/browser-*.png, browser-test-report.md |
| **F3** | `wf-e2e-unblock` | Unblock blocked tests | CONDITIONAL (block-test có blocked) | unblock-report.md |
| **F4** | `wf-e2e-implement` | Delegate wf-implement-feature | CONDITIONAL (implement-required có pending) | impl-log.json |
| **F5** | `wf-e2e-retest` | Retest sau fix/implement | YES (sau F4 hoặc PENDING) | retest-log.md |
| **F6** | `wf-e2e-fix` | Fix loop | CONDITIONAL (issues.json có open) | fix-log.json |
| **F7** | `wf-e2e-scenario` | Playwright test-scenario.md | DEFAULT (degraded_no_browser với --no-playwright — G2) | scenario-test-report.md |
| **F8** | `wf-e2e-demo` | Playwright user-guide.md | DEFAULT (degraded_no_browser với --no-playwright — G2) | demo-report.md |

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | ID feature | required (trừ `--session=`) |
| `--from-step=<F0-F8>` | Jump-to step (validate prereq trước) | F0 |
| `--phase=<0-7>` (legacy) | Map sang `--from-step=F1` (P0-6) hoặc `--from-step=F7` (P7) | auto-detect |
| `--resume` | Resume session gần nhất | - |
| `--session=<id>` | Session ID cụ thể | auto-discover |
| `--status` | Display orchestrator dashboard + STOP | - |
| `--auto` | Auto-confirm tất cả prompts (pass tới F0a+F1+F4+F6) | disabled |
| `--skip=<F2,F3,...>` | Opt-out sub-skills (F0/F0a KHÔNG thể skip) | none |
| `--no-playwright` | DEGRADE mode (G2): F2/F7/F8 chạy ở mode="degraded_no_browser" (static analysis only). KHÔNG skip phases — batch_status="degraded", KHÔNG "completed". WARN: "Không production-ready — cần re-run KHÔNG có --no-playwright trước khi ship" | disabled |
| `--show-browser` | Hiển thị browser (pass tới F2/F7/F8) | headless |
| `--mobile` | Mobile viewport (pass tới F2/F7/F8) | desktop |
| `--strict-evidence` | Bắt buộc screenshot cho mọi step F2/F7/F8. Thiếu → BLOCKED | ON (default) |
| `--no-seed` | Skip F0b seed-manifest | disabled |
| `--max-impl-items=<N>` | Limit F4 implement (priority P0 first) | unlimited |

### Legacy Flags (silent accept + WARN deprecation)

| Legacy flag | Behavior mới | Note |
|-------------|--------------|------|
| `--parallel-safe` | no-op (luôn ON) | WARN "deprecated, always enabled" |
| `--cross-module` | no-op (luôn ON) | WARN "deprecated, always enabled" |
| `--cross-module-wait=<N>` | pass-through tới F5+F7 | accept |
| `--playwright-mcp` | no-op (default Playwright cho F2/F5/F7/F8) | WARN "deprecated" |
| `--phase=0..6` | alias `--from-step=F1` (start at F1) | WARN |
| `--phase=7` | alias `--from-step=F7` (F7+F8 only) | WARN |
| `--fix=<path>` | jump to F6 với `--path=<path>` | accept, run F6 standalone |
| `--retest` | jump to F5 standalone | accept |
| `--unblock-test` | jump to F3 standalone | accept |
| `--no-playwright` | **DEPRECATED v7.1.0** — ignored với WARN. Live browser BẮT BUỘC ở F2/F5/F7/F8; auto-start mandatory; fail → ESCALATE Nhóm 2. Code analysis CHỈ hợp lệ cho item Nhóm 4 đã được F1 classify. | WARN, ignore |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect, khong hoi user. Lock held -> fallback Grep/Glob.

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh` -> set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held -> fallback Grep/Glob. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh` -> ok/light/strong/severe. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` -> `$CI_CONTEXT` pass to sub-skill spawns via orchestrator. | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `project_structure` | Serena `get_symbols_overview` | GitNexus `clusters` | Glob |
| `understand_flow` | GitNexus `query` | Serena `get_symbols_overview` | Grep + Read |
| `impact_analysis` | GitNexus `impact({target})` | - | Grep |

---
## Session Structure

**Path duy nhất:** `.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/`

Tất cả 9 skills (orchestrator + F1-F8) ghi vào cùng session dir. SSOT: `e2e-status.json`.

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── e2e-status.json              ← ORCHESTRATOR SSOT 8-step (chỉ orchestrator write)
├── session-log.json             ← CORE-026 APPEND-only
├── error-ledger.json            ← CORE-034 APPEND-only, namespaced E001-E099
├── prompt-context.md            ← input user verbatim
├── .lock                        ← session-level lock + heartbeat
│
├── issues.json                  ← SHARED — F1,F2,F5,F7,F8 APPEND; F6 UPDATE
├── block-test.json              ← SHARED — F1,F2 APPEND; F3 UPDATE; F5 UPDATE
├── implement-required.json      ← NEW — F1,F2 APPEND; F4 UPDATE
├── manual.json                  ← NEW — F1,F2,F3 APPEND; report-only
│
├── findings/                    ← F1 OWNED
├── outputs/                     ← F1 init; F2,F7,F8 UPDATE
├── screenshots/                 ← F2,F7,F8 SHARED (prefix: browser-, scenario-, demo-)
│
├── F1-test/, F2-browser/, F3-unblock/, F4-implement/, F5-retest/,
├── F6-fix/, F7-scenario/, F8-demo/  ← per-skill workspaces
│
├── _locks/
│   ├── browser-mcp.lock         ← F2, F5, F7, F8 sequential
│   ├── source-{hash}.lock       ← F4, F6 acquire khi edit
│   ├── migration.lock           ← F1 DB migrate
│   └── module-{id}.lock         ← cross-session safety
│
├── orchestrator-summary.md      ← orchestrator finalize
└── phase-summary.md             ← CORE-028 tổng kết tiếng Việt
```

---

## Phase Routing (CORE-032 lazy-load)

| Step | Procedure | Description |
|------|-----------|-------------|
| **Init** | `procedures/_shared.md` §init | Resolve session, create e2e-status.json, acquire .lock, parse flags |
| **Legacy Flag Mapping** | `procedures/legacy-flags.md` | Detect + map legacy flags + WARN |
| **Main Orchestration** | `procedures/orchestrate.md` | Spawn F1-F8 sequential với skip-rules |
| **Skip Rules** | `procedures/skip-rules.md` | Conditional logic cho F3/F4/F6 |
| **Resume/Status** | `procedures/resume-status.md` | --resume + --status handlers |

---

## Phase Gating (re-verify each sub-skill)

Sau mỗi sub-skill complete, orchestrator chạy POST-VERIFY:

1. **T1:** Completion signal file marker exists (`e2e-status.json.steps.F{N}.status = "completed"`)
2. **T2:** Outputs declared trong contract tồn tại
3. **T3:** Schema validate (jq) cho JSON outputs
4. **T4:** Cross-ref (vd F1 produces 12 findings, F2 verifies test-scenario.md format)

Fail → re-spawn sub-skill x1 (max 3 retries CORE-034) → escalate AskUserQuestion.

---

## Conditional Skip Rules

Xem `procedures/skip-rules.md` chi tiết.

```
After F1+F2:
  IF block-test.json blocked > 0 → run F3
  ELSE skip F3

After F3:
  IF implement-required.json pending > 0 → run F4
  ELSE skip F4

After F4:
  MUST run F5 (mark retest_after_impl=true)

After F5:
  IF issues.json open > 0 AND f6_f5_loop_count < 3 → run F6 → loop back to F5
  ELSE proceed F7

F7 mandatory (live browser BẮT BUỘC, auto-start)
F8 mandatory (live browser BẮT BUỘC, auto-start)
```

---

## --status

Read-only display dashboard. Xem `procedures/resume-status.md`.

```
================================================================
wf-e2e-verify Orchestrator — Status Dashboard
Session: {SESSION_DIR}
FEAT-ID: {feat_id}
================================================================

8-Step Pipeline:
| Step | Skill          | Status      | Duration | Result                |
|------|----------------|-------------|----------|------------------------|
| F1   | wf-e2e-test    | completed   | 25m      | findings/ + 4 SSOT JSONs |
| F2   | wf-e2e-browser | completed   | 12m      | 5 browser tests, 1 issue |
| F3   | wf-e2e-unblock | completed   | 5m       | 3 unblocked, 1 → F4    |
| F4   | wf-e2e-implement | running   | 8m+      | IMPL-REQ-002 (delegate) |
| F5   | wf-e2e-retest  | pending     | -        | -                      |
| F6   | wf-e2e-fix     | pending     | -        | -                      |
| F7   | wf-e2e-scenario | pending    | -        | -                      |
| F8   | wf-e2e-demo    | pending     | -        | -                      |

SSOT Counters:
- issues.json: open=3, fixed=8, total=11
- block-test.json: blocked=1 (Group 3), resolved=4, unblocked=3
- implement-required.json: pending=1, in_progress=1, done=1, skipped=0
- manual.json: pending=2, verified=0

Anti-loop counter: f6_f5_loop_count = 0 / 3
Context: 47%

Next action: continue F4 (delegate IMPL-REQ-002 in progress)
================================================================
STOP
```

---

## PRE-GATE (CORE-011)

1. **T1:** FEAT-ID hợp lệ trong registry
2. **T2:** Registry schema valid
3. **T3:** Feature spec tồn tại + ≥500 bytes
4. **T4:** Sub-skills (F1-F8) directories tồn tại trong `.claude/skills/workflow/`

Fail → E001/E002 → STOP.

---

## POST-GATE (CORE-012)

Sau khi 8 steps complete (hoặc partial completion):

1. **T1:** `e2e-status.json` valid + tất cả steps có status terminal (completed|skipped|failed)
2. **T2:** `orchestrator-summary.md` tồn tại
3. **T3:** Phase-summary tiếng Việt ≤15 dòng (CORE-028)
4. **T4:** Tổng outputs (findings + scenarios + screenshots + reports) khớp với declared trong sub-skill contracts

Fail → auto-fix retry x3 → escalate.

---

## Error Codes

### E001-E009 — Orchestrator pipeline/session/lock

| Code | Mô tả | Action |
|------|-------|--------|
| E001 | FEAT-ID không hợp lệ | STOP, hỏi user |
| E002 | Spec content insufficient | STOP, suggest implement spec trước |
| E003 | Sub-skill spawn fail | Retry x1, escalate |
| E004 | Anti-loop F6↔F5 max 3 vòng | Escalate AskUserQuestion |
| E005 | Phase gating T4 cross-ref fail | Auto-fix retry x3 |
| E006 | Legacy flag mapping ambiguous | WARN, ask user |
| E007 | Lock active (process khác đang chạy) | Retry hoặc abort |
| E008 | Stale lock (>30 min) | Auto-release, retry |
| E009 | Context >90% | FORCE STOP |

### E010-E019 — F0/F0a/F0b errors

| Code | Step | Mô tả | Action |
|------|------|-------|--------|
| E010 | F0 | Infra check gặp lỗi không xác định | STOP, escalate |
| E011 | F0 | Backend health fail (HTTP error / timeout) | BLOCKED_INFRA |
| E012 | F0 | Frontend health fail | BLOCKED_INFRA |
| E013 | F0 | Playwright MCP không available | BLOCKED_INFRA |
| E014 | F0 | DB connection fail | BLOCKED_INFRA |
| E015 | F0a | wf-e2e-finding spawn fail | Retry x1, escalate |
| E016 | F0a | F0a outputs thiếu sau spawn | E003 cascade |
| E017 | F0b | seed-manifest spawn fail | BLOCKED_SEED |
| E018 | F0b | Seed data validation fail | BLOCKED_SEED |
| E019 | F0a/F0b | Context > 50% sau F0a — checkpoint suggested | WARN (không block) |

---

## Backward Compatibility

Examples:

```bash
# Legacy: full pipeline with all flags
/wf-e2e-verify FEAT-EW-CRM-001 --playwright-mcp --cross-module --parallel-safe
# → Orchestrator: WARN 3 deprecated flags + run default chain F1→F8

# Legacy: fix only
/wf-e2e-verify FEAT-EW-CRM-001 --fix=path/to/issues.json --session=<id>
# → Jump to F6 với --path=<path>

# Legacy: retest only
/wf-e2e-verify FEAT-EW-CRM-001 --retest --session=<id>
# → Jump to F5 standalone

# Legacy: unblock only
/wf-e2e-verify FEAT-EW-CRM-001 --unblock-test --session=<id>
# → Jump to F3 standalone

# Legacy: Phase 7 only
/wf-e2e-verify FEAT-EW-CRM-001 --phase=7
# → --from-step=F7 (run F7 + F8)
```

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` (F1) | Foundation step, mandatory |
| `wf-e2e-browser` (F2) | Default ON |
| `wf-e2e-unblock` (F3) | Conditional |
| `wf-e2e-implement` (F4) | Conditional, delegate `wf-implement-feature` |
| `wf-e2e-retest` (F5) | Default Playwright |
| `wf-e2e-fix` (F6) | Conditional |
| `wf-e2e-scenario` (F7) | Default Playwright |
| `wf-e2e-demo` (F8) | Default Playwright |
| `wf-implement-feature` | Downstream của F4 delegate — PRIMARY owner registry.impl_status |
| `wf-verify-sync` | Downstream — consume registry updates |

---

## Migration Note (v7.0.0 → v7.1.0)

**Breaking change duy nhất:** cờ `--no-playwright` bị deprecated và **IGNORED** ở runtime. Live browser BẮT BUỘC ở F2/F5/F7/F8; hạ tầng không chạy → MANDATORY auto-start (retry 2 lần) → fail → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion. KHÔNG có đường thoát silent fallback static analysis.

Code analysis CHỈ hợp lệ cho item đã được F1 classify Nhóm 4 (visual_inspection / requires_real_payment / requires_3rd_party_login / requires_hardware / requires_data_volume / requires_external_api / requires_human_judgment).

Migration:
- Người dùng cần bỏ qua UI test (vd CI không có browser) → dùng `--skip=F2,F5,F7,F8` explicit.
- Người dùng cũ truyền `--no-playwright` → WARN, ignored, pipeline vẫn chạy live.

---

## Migration Note (v6.5.0 → v7.0.0)

**Breaking changes (KHÔNG):** Backward-compat hoàn toàn cho user cũ — legacy flags vẫn work với silent WARN.

**Internal restructure:**
- 1,026 dòng SKILL.md → ~450 dòng lean routing
- Phase 0-7 logic được MOVE sang F1-F8 sub-skills
- Templates được DUPLICATE (mỗi skill có copy riêng để self-contained)
- Session dir path KHÔNG đổi: vẫn `.mc-data/work/wf-e2e-verify/sessions/{...}/`
- 4 SSOT JSONs (issues, block-test, implement-required NEW, manual NEW) ở session root

**New artifacts:**
- `implement-required.json` — Nhóm 3 blocks dual-write
- `manual.json` — Nhóm 4 verified-OK / needs-human
- `e2e-status.json` — orchestrator 8-step SSOT
