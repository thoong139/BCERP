---
name: wf-e2e-test
version: 2.0.0
last_updated: 2026-05-15
description: |
  F1 trong chuỗi wf-e2e-* — Live test code-based 1 feature (KHÔNG FIND — consume findings từ F0a wf-e2e-finding; G5 shim tự spawn F0a nếu thiếu). 5 phase: SETUP → DB → API → UI → INTEGRATION → OUTPUT. KHÔNG dùng Playwright (đó là F2/F7/F8). Cross-module + Parallel-safe LUÔN ON. Live DB + Live API + Live FE BẮT BUỘC; hạ tầng không chạy → MANDATORY auto-start (retry 2 lần), fail → ESCALATE Nhóm 2 (block-test.json) + AskUserQuestion, KHÔNG silent fallback code analysis. Block classification 4 nhóm: Nhóm 3 DUAL-WRITE block-test.json + implement-required.json (F4 consume); Nhóm 4 verify code → block-test.json + manual.json (QA consume). ISSUE-IMMEDIATE: ghi NGAY mỗi issue vào issues.json (1 lỗi = 1 write).

  TRIGGER khi: "test code", "kiểm thử nghiệp vụ", "e2e test code-based", "không cần browser".
  KHÔNG trigger: cần browser test (dùng F2), full pipeline (dùng /wf-e2e-verify orchestrator).
argument-hint: "<FEAT-ID> [--phase=<0-6>] [--resume] [--session=<id>] [--status] [--auto]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__get_symbols_overview, mcp__serena__search_for_pattern,
  mcp__serena__replace_content, mcp__serena__replace_symbol_body,
  mcp__gitnexus__query, mcp__gitnexus__context, mcp__gitnexus__impact,
  mcp__gitnexus__detect_changes
---
# /wf-e2e-test: $ARGUMENTS

## Overview

| Mục                                   | Nội dung                                                                                                                                                                             |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Mục đích**                  | Test code-based 1 feature qua 6 phase: Business → DB → API → UI → Integration → Output                                                                                           |
| **Standalone**                   | YES — tạo session mới nếu thiếu `--session`                                                                                                                                    |
| **Cross-module + Parallel-safe** | LUÔN ON (default), không cần flag                                                                                                                                                  |
| **Input**                        | `<FEAT-ID>` (vd `FEAT-EW-CRM-001`)                                                                                                                                                |
| **Output**                       | `findings/*.md` (12 files), `outputs/test-scenario.md` + `outputs/user-guide.md` (skeleton), `issues.json`, `block-test.json`, `implement-required.json`, `manual.json` |
| **Triết lý**                   | Iterative "thiếu gì bổ sung đó". Live DB + Live API + Live FE test BẮT BUỘC, auto-start hạ tầng nếu chưa chạy. KHÔNG silent fallback code analysis. ISSUE-IMMEDIATE. Dual-write block-test → implement-required (Nhóm 3) / manual (Nhóm 4 — special case duy nhất hợp lệ cho code analysis kết quả). |

### Flow tổng quan

```
[FEAT-ID] → [Phase 0: SETUP] → PRE-GATE CONSUME F0a (CORE-036)
  Verify findings/ 8 files + finding-summary.md + 4 SSOT JSONs
  FAIL → G5 shim: auto-spawn F0a nếu findings/ chưa tồn tại
→ [Phase 2: DB] LIVE-TEST‡→FIX**→RETEST§ (dùng db-mapping.md từ F0a)
→ [Phase 3: API] LIVE-TEST‡→FIX**→RETEST§ (dùng api-mapping.md từ F0a)
→ [Phase 4: UI] TEST→FIX**→RETEST§ (dùng ui-mapping.md từ F0a)
→ [Phase 5: INTEGRATION] (Cross-Module LUÔN ON, dùng cross-module-map.md từ F0a)
→ [Phase 6: OUTPUT] test-scenario.md + user-guide.md skeleton + phase-summary.md

[Phase 1 BUSINESS đã di chuyển sang F0a wf-e2e-finding — xem procedures/phase1-business.md (redirect)]

‡ LIVE-TEST (BẮT BUỘC P2+P3): infrastructure auto-start với auto-diagnose + retry. KHÔNG fallback code-only
** FIX: active khi --auto (auto-fix inline). Continuous fix loop: fix → RETEST → còn issue? → lặp. Code analysis CHỈ hợp lệ cho Nhóm 4 (test cần con người).
§ RETEST (BẮT BUỘC sau FIX): chạy lại test thu hẹp → cập nhật report + issues.json (CORE-039)
```

---

## Workflow Position

```
ORCHESTRATOR wf-e2e-verify
        │
        ▼
   ┌─────────┐
   │   F1    │ ← wf-e2e-test (skill này)
   │ Phase   │
   │ 0-6     │
   └────┬────┘
        ▼
   F2 browser → F3 unblock → F4 implement → F5 retest → F6 fix → F7 scenario → F8 demo
```

F1 là **foundation step** — produces toàn bộ findings + 4 SSOT JSON files cho các skill F2-F8 consume.

---

## Arguments

| Argument           | Mô tả                                                  | Default                                 |
| ------------------ | -------------------------------------------------------- | --------------------------------------- |
| `<FEAT-ID>`      | ID feature trong registry (FEAT-EW-{MOD}-{NNN})          | required (trừ `--session=`)          |
| `--phase=<0-6>`  | Resume từ phase cụ thể                                | auto-detect từ status.json             |
| `--resume`       | Resume session gần nhất của FEAT-ID                   | -                                       |
| `--session=<id>` | Session name cụ thể để resume                        | auto-discover từ FEAT-ID nếu --resume |
| `--status`       | Xem progress session hiện tại + DỪNG (không execute) | -                                       |
| `--auto`         | Auto-confirm Phase 1 VERIFY + auto-fix inline Phase 2-5  | disabled                                |

**Bỏ flags so với wf-e2e-verify cũ:**

- `--parallel-safe` → luôn ON (default)
- `--cross-module` → luôn ON (default)
- `--cross-module-wait=<sec>` → fixed 30s default (orchestrator có thể override)
- `--fix=<path>` → moved sang F6 wf-e2e-fix
- `--retest` → moved sang F5 wf-e2e-retest
- `--playwright-mcp` → moved sang F2 wf-e2e-browser / F7 wf-e2e-scenario / F8 wf-e2e-demo
- `--unblock-test` → moved sang F3 wf-e2e-unblock

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect, khong hoi user. Lock held -> fallback Grep/Glob.

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh` -> set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh` -> ok/light/strong/severe. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` -> `$CI_CONTEXT`. | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `understand_flow` | GitNexus `query` | Serena `get_symbols_overview` | Grep + Read |
| `api_routes` | GitNexus `route_map()` | Serena `search_for_pattern` | Grep |
| `symbol_overview` | Serena `get_symbols_overview` | - | Read |
| `find_by_annotation` | GitNexus `cypher` + Serena `find_referencing_symbols` | - | Grep REQ-ID |
| `impact_analysis` | GitNexus `impact({target})` | - | Grep |

---
## Session Structure

**Shared session dir** (cùng các skill F2-F8 + orchestrator):

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── status.json                      ← F1 own state (state machine, sub_state)
├── e2e-status.json                  ← orchestrator state (nếu spawn từ orchestrator)
├── prompt-context.md                ← input user verbatim
├── issues.json                      ← F1 CREATE + APPEND (ISSUE-IMMEDIATE)
├── block-test.json                  ← F1 CREATE + APPEND (4-group classification)
├── implement-required.json          ← F1 CREATE + APPEND (Nhóm 3, NEW)
├── manual.json                      ← F1 CREATE + APPEND (Nhóm 4 verified-OK, NEW)
├── findings/
│   ├── business-understanding.md    ← Phase 1
│   ├── business-rule-catalog.md     ← Phase 1
│   ├── state-machine.md             ← Phase 1
│   ├── cross-module-map.md          ← Phase 1 (LUÔN generate, N/A nếu không publish events)
│   ├── db-mapping.md                ← Phase 2 FIND
│   ├── db-seed-data.md              ← Phase 2 SEED
│   ├── db-test-report.md            ← Phase 2 TEST
│   ├── api-mapping.md               ← Phase 3 FIND
│   ├── api-test-report.md           ← Phase 3 TEST
│   ├── ui-mapping.md                ← Phase 4 FIND
│   ├── ui-test-report.md            ← Phase 4 TEST
│   └── integration-test-report.md   ← Phase 5
├── outputs/
│   ├── test-scenario.md             ← Phase 6 skeleton (F7 fill Pass/Fail)
│   └── user-guide.md                ← Phase 6 skeleton (F8 verify accuracy)
├── F1-test/
│   └── Phase{N}-report.md           ← CORE-028 per-phase summary
└── _locks/
    └── migration.lock               ← Phase 2 DB migrate acquires
```

> **⚠️ Cấu trúc thư mục IMMUTABLE.** Mọi file PHẢI nằm đúng vị trí. KHÔNG tạo file ngoài cấu trúc, KHÔNG đặt sai thư mục con, KHÔNG đổi tên.

---

## State Machine

Mỗi phase 1-5 chạy: `[FIND] → [ASSESS] → đủ? → [LIVE-TEST] (P2-3) hoặc [TEST] (P4-5) → (--auto? → [FIX LOOP: fix → RETEST → còn issue? → lặp]) → NEXT_PHASE`. Nếu ASSESS thiếu: `[BỔ SUNG] → quay lại [ASSESS]`. Context >65% → cảnh báo /compact + --resume.

- **Phase 1:** thay [TEST] bằng [VERIFY] (AskUserQuestion blocking), không có FIX step.
- **Phase 2+3:** [LIVE-TEST] BẮT BUỘC — `ensure_infrastructure_running db/backend` trước, test trên DB/API thật. Auto-start fail → ESCALATE blocking (xem `_shared.md`).
- **Phase 5:** state machine đơn giản — chỉ TEST → (FIX nếu --auto) → RETEST → output. Live FE/BE BẮT BUỘC nếu test có chain UI→API.
- **Phase 6:** OUTPUT — sinh test-scenario.md + user-guide.md (skeleton, chưa fill browser Pass/Fail).

---

## Phase Routing Map (CORE-032 lazy-load)

| Phase | Sub-state | Procedure file | Output |
|-------|-----------|---------------|--------|
| **P0 SETUP** | INIT + CONSUME F0a | `procedures/phase0-setup.md` | status.json init + F0a verification |
| ~~**P1 BUSINESS**~~ | *(Di chuyển sang F0a)* | `procedures/phase1-business.md` (redirect) | Xem wf-e2e-finding |
| **P2 DB** | LIVE-TEST→FIX→RETEST | `procedures/phase2-db.md` | db-test-report.md (consume db-mapping.md từ F0a) |
| **P3 API** | LIVE-TEST→FIX→RETEST | `procedures/phase3-api.md` | api-test-report.md (consume api-mapping.md từ F0a) |
| **P4 UI** | TEST→FIX→RETEST | `procedures/phase4-ui.md` | ui-test-report.md (consume ui-mapping.md từ F0a) |
| **P5 INTEGRATION** | TEST→FIX→RETEST (LUÔN ON) | `procedures/phase5-integration.md` | `findings/integration-test-report.md` |
| **P6 OUTPUT** | DONE | `procedures/phase6-output.md` | test-scenario.md (skeleton), user-guide.md (skeleton) |

**Block classification** áp dụng Phase 2-5: `procedures/block-classification.md` — 4 nhóm + dual-write block-test.json + implement-required.json / manual.json.

**Resume + Status handlers:** `procedures/resume-status.md`.

**Shared protocols:** `procedures/_shared.md` (atomic write, lock acquisition, error handling, infrastructure auto-start, cross-session R/W lock).

**Cross-session locks (v1.2.0):** Phase 0 SETUP start heartbeat daemon (`lock-daemon.sh start`). Phase 6 OUTPUT stop daemon → release_all_session_locks. Resources locked: `backend`, `frontend`, `database`, `playwright`. Files: `.mc-data/_global_locks/{resource}.lock` (schema `global-rw-lock-v1`).

---

## PRE-GATE (CORE-011 Forensic)

Trước khi vào Phase 0:

1. **T1 — File existence:**

   - `.mc-data/docs/_meta/req-registry.json` tồn tại
   - Feature spec file (từ `registry.features[].file`) tồn tại
2. **T2 — Schema validation:**

   - `jq -e '.requirements | length > 0' req-registry.json` pass
   - `jq -e ".features[] | select(.feat_id==\"$FEAT_ID\")" req-registry.json` pass
3. **T3 — Content depth:**

   - Feature spec file size > 500 bytes (không stub trống)
   - FEAT-ID tồn tại trong registry.features[]
4. **T4 — Cross-reference:**

   - feat.req_ids[] đều tồn tại trong registry.requirements[]

Fail bất kỳ T1-T4 → escalate `E001` (FEAT-ID không hợp lệ) hoặc `E002` (spec không đủ content) — không advance phase.

---

## POST-GATE (CORE-012)

Sau mỗi phase POST-GATE T1→T4 trên output phase đó:

| Phase | T1 (file exists)                    | T2 (schema)                                        | T3 (content depth)                           | T4 (cross-ref)                                                        |
| ----- | ----------------------------------- | -------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------- |
| P1    | 4 findings tồn tại                | Markdown valid, headings đầy đủ                | ≥3 BR, ≥2 actors                           | BR catalog tham chiếu được trong state-machine + cross-module-map |
| P2    | `findings/db-test-report.md` + `findings/db-mapping.md` + `findings/db-seed-data.md` | seed-data có SQL INSERT hợp lệ | ≥15 seed records (4 nhóm)                  | FK references match tables                                            |
| P3    | `findings/api-test-report.md` + `findings/api-mapping.md` | endpoint matrix có đủ cột                      | ≥3 happy + ≥3 BR violation tests           | API routes match Endpoints/*.cs                                       |
| P4    | `findings/ui-test-report.md` + `findings/ui-mapping.md` | ui-mapping.md có §1-§10; ui-test-report.md có §1-§11 | loading/error/success/validation/RBAC/i18n + ≥80% User Flow Coverage + Event Handler 7 checks + Element Sufficiency | hooks reference API endpoints khớp Phase 3 + User Flow Mapping khớp business-understanding.md §4 |
| P5    | `findings/integration-test-report.md`                | 8 sections (4.4 evidence, 7 cross-module nếu có) | live test evidence có response + cross-module results | chain steps khớp với cross-module-map                               |
| P6    | 2 outputs + phase-summary tồn tại | YAML frontmatter valid                             | ≥2 scenarios, user-guide Việt ≥1000 chars | scenarios reference BR catalog + state-machine                        |

Vi phạm T4 → auto-fix retry (max 3 lần) → fail vĩnh viễn → escalate E0X5.

---

## --status & --resume

Xem `procedures/resume-status.md` — full logic.

**Quick reference:**

- `--status` → đọc status.json + 4 SSOT JSON → display dashboard 7-row table → STOP
- `--resume` → tìm latest session, acquire lock, re-validate phase N-1 output, route theo current_phase + sub_state

---

## Context & Checkpoint (CORE-038)

| Context % | Action                                                                                        |
| --------- | --------------------------------------------------------------------------------------------- |
| <65%      | Tiếp tục bình thường                                                                     |
| 65-80%    | Chuẩn bị checkpoint (lưu status.json, đảm bảo phase hiện tại có thể resume)         |
| 80-90%    | STOP sau phase hiện tại, hướng dẫn user `/clear` + `/wf-e2e-test <FEAT-ID> --resume` |
| >90%      | FORCE STOP (E009), checkpoint ngay                                                            |

Update `status.context_estimate_pct` mỗi POST-GATE để track.

---

## Error Codes (E010-E022 namespace)

| Code | Phase | Mô tả                                               | Action                                 |
| ---- | ----- | ----------------------------------------------------- | -------------------------------------- |
| E001 | P0    | FEAT-ID không tồn tại trong registry               | STOP, hỏi user                        |
| E002 | P0    | Spec file không đủ content (≤500 bytes)           | STOP, hỏi user implement spec trước |
| E007 | All   | Lock active, process khác đang chạy                | Retry hoặc abort                      |
| E008 | All   | Stale lock (>30 min)                                  | Auto-release, retry                    |
| E009 | All   | Context >90%                                          | FORCE STOP                             |
| E010 | P0    | Template implement-required / manual không tồn tại | Re-init from skill templates           |
| E011 | P1-5  | Lock conflict khi append SSOT JSON                    | Retry với backoff                     |
| E012 | P2-5  | blocking_reason không thuộc enum hợp lệ           | Auto-fix retry                         |
| E013 | P2-5  | Nhóm 3 thiếu related_impl_req_id                    | Auto-fix retry                         |
| E014 | P2-5  | Nhóm 4 thiếu code_verification                      | Auto-fix retry                         |
| E015 | POST  | Cross-reference link không khớp 2 chiều            | Auto-fix retry                         |
| E016 | All   | Atomic write fail (corrupted JSON)                    | Restore from temp, retry               |
| E017 | P2-5  | Entry thiếu required field                           | Auto-fix retry                         |
| E018 | P2-5  | Trùng test_ref → 2 BLK-NNN                          | WARN (không fail)                     |
| E019 | P2-5  | code_verification.result=FAIL nhưng vẫn ghi manual  | Escalate issue thay vì manual         |
| E020 | P4    | Phase 1 outputs chưa available                      | WARN + ghi caveat, continue best-effort |
| E021 | P4    | Coverage Phase 4 critically low (<50%)              | FAIL POST-GATE, escalate               |
| E022 | P4    | Critical UI element missing                          | FAIL POST-GATE, escalate               |

---

## Related Skills

| Skill                            | Quan hệ                                  | Artifacts produced/consumed                                 |
| -------------------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| `wf-e2e-verify` (orchestrator) | Parent — spawn F1 đầu pipeline         | Pass `--session`                                          |
| `wf-e2e-browser` (F2)          | Consumer F1 outputs                       | findings/ui-*, integration-test-report.md, test-scenario.md |
| `wf-e2e-unblock` (F3)          | Consumer F1 outputs                       | block-test.json                                             |
| `wf-e2e-implement` (F4)        | Consumer F1 outputs                       | implement-required.json                                     |
| `wf-e2e-retest` (F5)           | Consumer F1 outputs                       | findings/*.md, issues.json                                  |
| `wf-e2e-fix` (F6)              | Consumer F1 outputs                       | issues.json                                                 |
| `wf-e2e-scenario` (F7)         | Consumer F1 outputs                       | outputs/test-scenario.md                                    |
| `wf-e2e-demo` (F8)             | Consumer F1 outputs                       | outputs/user-guide.md                                       |
| `wf-implement-feature`         | Optional (legacy refactoring)             | F4 delegate sang skill này                                 |
| `wf-fix-bugs`                  | Sibling — orchestrator khác cho bug-fix | Không direct dependency                                    |

---

## Backward Compatibility

Người dùng cũ chạy `/wf-e2e-verify <FEAT-ID>` sẽ tự động spawn F1 wf-e2e-test ở step đầu. F1 standalone (`/wf-e2e-test <FEAT-ID>`) tạo session mới — orchestrator có thể pick up session đó sau.

Legacy flags `--phase=<0-6>` của wf-e2e-verify map 1-1 sang `--phase=<0-6>` của F1. Legacy `--phase=7` map sang F7 wf-e2e-scenario (orchestrator pass-through).
