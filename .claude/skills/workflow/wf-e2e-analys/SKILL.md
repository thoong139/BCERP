---
name: wf-e2e-analys
version: 3.0.0
last_updated: 2026-05-15
description: |
  F1 trong chuỗi wf-e2e-* — Phân tích code 1 feature qua 5 lớp: DB → API → UI → Integration → Output.
  Consume findings từ F0a wf-e2e-finding (KHÔNG tự generate findings).
  Chỉ code analysis — KHÔNG live test, KHÔNG infra auto-start, KHÔNG browser.
  Cross-module detection LUÔN ON.

  v3.0.0 (2026-05-15): Remove live testing/browser. Code analysis only.
  v2.0.0 (2026-05-15): Tách Phase 1 BUSINESS sang F0a wf-e2e-finding.

  TRIGGER khi: "phân tích code feature", "code analysis", "e2e analysis".
  KHÔNG trigger: full pipeline (dùng /wf-e2e-verify orchestrator).

argument-hint: "<FEAT-ID> [--phase=<0-6>] [--resume] [--session=<id>] [--status] [--auto]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__get_symbols_overview, mcp__serena__search_for_pattern,
  mcp__gitnexus__query, mcp__gitnexus__context, mcp__gitnexus__impact,
  mcp__gitnexus__detect_changes
---

# /wf-e2e-analys: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Phân tích code 1 feature qua 5 lớp: DB → API → UI → Integration → Output |
| **Standalone** | YES — tạo session mới nếu thiếu `--session` |
| **Cross-module** | LUÔN ON (default, không cần flag) |
| **Input** | `<FEAT-ID>` + findings/ từ F0a |
| **Output** | analysis reports (5 lớp), `issues.json`, `block-test.json`, `implement-required.json`, `manual.json` |

### Flow tổng quan

```
[FEAT-ID] → [Phase 0: SETUP] → PRE-GATE CONSUME F0a (CORE-036)
  Verify findings/ 8 files + finding-summary.md + 4 SSOT JSONs
  FAIL → auto-spawn F0a nếu findings/ chưa tồn tại
→ [Phase 2: DB] CODE-ANALYSIS → classify issues
→ [Phase 3: API] CODE-ANALYSIS → classify issues
→ [Phase 4: UI] CODE-ANALYSIS → classify issues
→ [Phase 5: INTEGRATION] CODE-ANALYSIS (Cross-Module LUÔN ON)
→ [Phase 6: OUTPUT] issues.json + block-test.json + implement-required.json + manual.json populated
```

---

## Workflow Position

```
ORCHESTRATOR wf-e2e-verify
        │
        ▼
F0a wf-e2e-finding (findings/)
        │
        ▼
   ┌─────────┐
   │   F1    │ ← wf-e2e-analys (skill này)
   │ Code    │
   │Analysis │
   └────┬────┘
        ▼
   F4 implement → F6 fix → F7 scenario
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | ID feature trong registry | required (trừ `--session=`) |
| `--phase=<0-6>` | Resume từ phase cụ thể | auto-detect từ status.json |
| `--resume` | Resume session gần nhất | - |
| `--session=<id>` | Session ID cụ thể | auto-discover |
| `--status` | Xem progress session + DỪNG | - |
| `--auto` | Auto-classify issues inline | disabled |

---

## CI PRE-GATE (CORE-033)

| Step | Action | Verify |
|------|--------|--------|
| **Na** | `bash .claude/scripts/ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` | CI flags set |
| **Nb** | `bash .claude/scripts/ci-freshness-check.sh` | Freshness status set |
| **Nc** | `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT` | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `understand_flow` | GitNexus `query` | Serena `get_symbols_overview` | Grep + Read |
| `api_routes` | GitNexus `route_map()` | Serena `search_for_pattern` | Grep |
| `symbol_overview` | Serena `get_symbols_overview` | - | Read |
| `find_by_annotation` | GitNexus + Serena `find_referencing_symbols` | - | Grep REQ-ID |
| `impact_analysis` | GitNexus `impact({target})` | - | Grep |

---

## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── status.json                      ← F1 own state
├── issues.json                      ← F1 CREATE + APPEND
├── block-test.json                  ← F1 CREATE + APPEND
├── implement-required.json          ← F1 CREATE + APPEND (Nhóm 3)
├── manual.json                      ← F1 CREATE + APPEND (Nhóm 4)
├── findings/                        ← F0a OUTPUT — F1 đọc
│   ├── business-understanding.md
│   ├── business-rule-catalog.md
│   ├── state-machine.md
│   ├── cross-module-map.md
│   ├── db-mapping.md
│   ├── api-mapping.md
│   ├── ui-mapping.md
│   └── ...
├── F1-test/
│   ├── db-analysis-report.md        ← Phase 2 output
│   ├── api-analysis-report.md       ← Phase 3 output
│   ├── ui-analysis-report.md        ← Phase 4 output
│   ├── integration-analysis-report.md ← Phase 5 output
│   └── Phase{N}-report.md           ← CORE-028
└── _locks/
    └── module-{id}.lock             ← cross-session safety
```

---

## Phase Routing Map (CORE-032 lazy-load)

| Phase | Procedure file | Output |
|-------|---------------|--------|
| **P0 SETUP** | `procedures/phase0-setup.md` | status.json init + F0a verification |
| **P2 DB** | `procedures/phase2-db.md` | db-analysis-report.md (consume db-mapping.md từ F0a) |
| **P3 API** | `procedures/phase3-api.md` | api-analysis-report.md (consume api-mapping.md từ F0a) |
| **P4 UI** | `procedures/phase4-ui.md` | ui-analysis-report.md (consume ui-mapping.md từ F0a) |
| **P5 INTEGRATION** | `procedures/phase5-integration.md` | integration-analysis-report.md |
| **P6 OUTPUT** | `procedures/phase6-output.md` | issues.json, implement-required.json, manual.json populated |

---

## PRE-GATE (CORE-011)

1. **T1:** `.mc-data/docs/_meta/req-registry.json` tồn tại
2. **T2:** `jq -e ".features[] | select(.feat_id==\"$FEAT_ID\")"` pass
3. **T3:** Feature spec file size > 500 bytes
4. **T4:** `findings/` từ F0a tồn tại + ≥4 files

Fail T4 → auto-spawn F0a → retry.

---

## POST-GATE (CORE-012)

| Phase | T1 | T2 | T3 | T4 |
|-------|----|----|----|----|
| P2 | db-analysis-report.md tồn tại | Markdown sections đầy đủ | ≥1 finding | References db-mapping.md |
| P3 | api-analysis-report.md tồn tại | Endpoint coverage documented | ≥1 finding | Routes match code |
| P4 | ui-analysis-report.md tồn tại | Component analysis sections | ≥1 finding | References ui-mapping.md |
| P5 | integration-analysis-report.md | Cross-module section exists | ≥1 finding | Matches cross-module-map |
| P6 | 4 SSOT JSONs valid | jq parse pass | ≥1 entry nếu có issue | IDs không trùng |

---

## Context & Checkpoint (CORE-038)

| Context % | Action |
|-----------|--------|
| <65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu status.json) |
| 80-90% | STOP sau phase hiện tại → hướng dẫn `--resume` |
| >90% | FORCE STOP (E009) |

---

## Error Codes (E010-E022)

| Code | Phase | Mô tả | Action |
|------|-------|-------|--------|
| E001 | P0 | FEAT-ID không tồn tại | STOP, hỏi user |
| E002 | P0 | Spec không đủ content | STOP |
| E007 | All | Lock conflict | Retry hoặc abort |
| E008 | All | Stale lock >30 min | Auto-release |
| E009 | All | Context >90% | FORCE STOP |
| E010 | P0 | F0a findings thiếu — spawn F0a | Auto-spawn F0a |
| E015 | POST | Cross-reference mismatch | Auto-fix retry x3 |
| E016 | All | Atomic write fail | Restore from temp |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-finding` (F0a) | Producer findings/ — F1 consume |
| `wf-e2e-verify` (orchestrator) | Parent — spawn F1 |
| `wf-e2e-implement` (F4) | Consumer implement-required.json |
| `wf-e2e-fix` (F6) | Consumer issues.json |
| `wf-e2e-scenario` (F7) | Consumer analysis outputs |
