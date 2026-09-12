---
name: wf-e2e-finding
version: 1.1.0
last_updated: 2026-09-12
description: |
  F0a trong chuỗi wf-e2e-*. Phân tích business + mapping (KHÔNG live-test). Output 8 finding files + 4 SSOT JSONs
  (rỗng) cho wf-e2e-test consume. Scope: FIND only — P1 Business, P2 DB-mapping, P3 API-mapping, P4 UI-mapping.
  Tách từ wf-e2e-test v1.0.0 (Tier 0 Foundation Refactor).
  TRIGGER khi: "/wf-e2e-finding", hoặc spawned bởi wf-e2e-verify orchestrator (F0a step).
argument-hint: "<FEAT-ID> [--phase=<0-5>] [--resume] [--session=<id>] [--status] [--auto]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__get_symbols_overview, mcp__serena__search_for_pattern
---

# /wf-e2e-finding: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Phân tích nghiệp vụ + mapping code (KHÔNG live-test). Output 8 finding files + 4 SSOT JSONs rỗng |
| **Prerequisites** | `req-registry.json` + FEAT-ID hợp lệ + spec > 500 bytes + feat.req_ids cross-ref (PRE-GATE T1-T4 dưới) |
| **Standalone** | YES — tạo session mới nếu thiếu `--session` |
| **Scope** | FIND only — đọc spec + code, KHÔNG chạy DB/API/browser |
| **Input** | `<FEAT-ID>` (vd `FEAT-EW-CRM-001`) |
| **Output** | 8 finding files (`findings/*.md`) + 4 SSOT JSONs rỗng + `finding-summary.md` |
| **Consumed by** | `wf-e2e-test` (F1) — PRE-GATE consume findings làm context |

### Workflow Position

```
ORCHESTRATOR /wf-e2e-verify
        │
        ▼
F0a wf-e2e-finding  ← YOU ARE HERE (findings/ + 4 SSOT JSONs rỗng)
        │
        ▼
F1 wf-e2e-test → F2 wf-e2e-browser → ... → F8
```

### Flow tổng quan

```
[FEAT-ID] → [P0: SETUP] → PRE-GATE validate
  → [P1: BUSINESS] FIND→ASSESS→BỔ SUNG→VERIFY
      Output: business-understanding.md, business-rule-catalog.md,
              state-machine.md, cross-module-map.md
  → [P2: DB-MAPPING] FIND→ASSESS
      Output: db-mapping.md, db-seed-data.md
  → [P3: API-MAPPING] FIND→ASSESS
      Output: api-mapping.md
  → [P4: UI-MAPPING] FIND→ASSESS
      Output: ui-mapping.md
  → [P5: COMPLETION]
      - Consolidate → finding-summary.md
      - Init 4 SSOT JSONs (rỗng)
      - POST-GATE: verify 8 files tồn tại + size > 500 bytes
      - Context budget check G4

KHÔNG THỰC HIỆN:
  - Live DB test (F1 Phase 2 LIVE-TEST)
  - Live API test (F1 Phase 3 LIVE-TEST)
  - Browser test (F2/F7/F8)
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | ID feature trong registry (FEAT-EW-{MOD}-{NNN}) | required (trừ `--session=`) |
| `--phase=<0-5>` | Resume từ phase cụ thể | auto-detect từ status.json |
| `--resume` | Resume session gần nhất của FEAT-ID | - |
| `--session=<id>` | Session name cụ thể để resume | auto-discover từ FEAT-ID nếu --resume |
| `--status` | Xem progress session hiện tại + DỪNG | - |
| `--auto` | Auto-confirm Phase 1 VERIFY (skip AskUserQuestion) | disabled |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: `bash .claude/scripts/ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| **Nb** | Index Freshness Check: `bash .claude/scripts/ci-freshness-check.sh` → ok/light/strong/severe. | Freshness status set |
| **Nc** | Agent Context Injection: `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT`. | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `understand_flow` | GitNexus `query` | Serena `get_symbols_overview` | Grep + Read |
| `find_entities` | Serena `find_symbol` | Serena `search_for_pattern` | Grep |
| `find_endpoints` | GitNexus `route_map()` | Serena `search_for_pattern` | Grep |
| `find_components` | Serena `get_symbols_overview` | Serena `search_for_pattern` | Glob |
| `find_by_annotation` | Serena `find_referencing_symbols` | - | Grep REQ-ID |

---

## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── status.json                      ← F0a own state
├── prompt-context.md                ← input user verbatim
├── findings/
│   ├── business-understanding.md    ← P1
│   ├── business-rule-catalog.md     ← P1
│   ├── state-machine.md             ← P1
│   ├── cross-module-map.md          ← P1
│   ├── db-mapping.md                ← P2
│   ├── db-seed-data.md              ← P2
│   ├── api-mapping.md               ← P3
│   ├── ui-mapping.md                ← P4
│   └── finding-summary.md           ← P5 consolidation
├── issues.json                      ← P5 init rỗng
├── block-test.json                  ← P5 init rỗng
├── implement-required.json          ← P5 init rỗng
└── manual.json                      ← P5 init rỗng
```

---

## Phase 0: SETUP (BẮT BUỘC — entry point)

> Chi tiết: `procedures/phase0-setup.md`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | Session init: tạo `sessions/{FEAT-ID}-*/`, lock, prompt-context.md | Session dir + lock OK |
| 2 | `--status`/`--resume`/`--session` handlers (resume-status.md) | Route đúng phase hoặc DỪNG |
| 3 | PRE-GATE T1-T4 (registry, spec, schema validation, cross-ref req_ids) | Fail → E020/E029 STOP |
| 4 | status.json init → route P1 theo routing map | current_phase = 1 |

## Phase Routing Map (CORE-032 lazy-load)

| # | Phase | Procedure file | Mô tả | Output |
|---|-------|---------------|-------|--------|
| **0** | P0 SETUP | `procedures/phase0-setup.md` | Session init, PRE-GATE validate, lock | status.json |
| **1** | P1 BUSINESS | `procedures/phase1-business.md` | FIND→ASSESS→BỔ SUNG→VERIFY | 4 business findings |
| **2** | P2 DB-MAPPING | `procedures/phase2-db-mapping.md` | FIND→ASSESS schema + seed | db-mapping.md, db-seed-data.md |
| **3** | P3 API-MAPPING | `procedures/phase3-api-mapping.md` | FIND→ASSESS endpoints | api-mapping.md |
| **4** | P4 UI-MAPPING | `procedures/phase4-ui-mapping.md` | FIND→ASSESS pages + hooks | ui-mapping.md |
| **5** | P5 COMPLETION | `procedures/phase5-completion.md` | Consolidate + init SSOT JSONs + POST-GATE | finding-summary.md, 4 SSOT JSONs |

**Shared protocols:** `procedures/_shared.md` (session init, atomic write, CI detection, error ledger, context budget).

**Resume + Status handlers:** `procedures/resume-status.md`.

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
   - Feature spec file size > 500 bytes
   - FEAT-ID tồn tại trong registry.features[]

4. **T4 — Cross-reference:**
   - feat.req_ids[] đều tồn tại trong registry.requirements[]

Fail bất kỳ T1-T4 → E020 hoặc E029 — không advance phase.

---

## POST-GATE (CORE-012)

Sau Phase 5 (COMPLETION), POST-GATE toàn bộ:

| Check | Tiêu chí |
|-------|---------|
| T1 file exists | 8 findings + finding-summary.md + 4 SSOT JSONs tồn tại |
| T2 size check | Mỗi finding file > 500 bytes |
| T3 content depth | business-understanding.md có ≥3 BR; api-mapping.md có ≥1 endpoint |
| T4 cross-ref | finding-summary.md trỏ tới tất cả 8 findings |

Fail → auto-fix retry max 3 lần → escalate E026.

---

## Output Files

| File | Template | Phase |
|------|----------|-------|
| `findings/business-understanding.md` | `templates/business-understanding.template.md` | P1 |
| `findings/business-rule-catalog.md` | `templates/business-rule-catalog.template.md` | P1 |
| `findings/state-machine.md` | `templates/state-machine.template.md` | P1 |
| `findings/cross-module-map.md` | `templates/cross-module-map.template.md` | P1 |
| `findings/db-mapping.md` | `templates/db-mapping.template.md` | P2 |
| `findings/db-seed-data.md` | `templates/db-seed-data.template.md` | P2 |
| `findings/api-mapping.md` | `templates/api-mapping.template.md` | P3 |
| `findings/ui-mapping.md` | `templates/ui-mapping.template.md` | P4 |
| `findings/finding-summary.md` | `templates/finding-summary.template.md` | P5 |
| `issues.json` | `wf-e2e-verify/templates/issues.template.json` | P5 init |
| `block-test.json` | `wf-e2e-verify/templates/block-test.template.json` | P5 init |
| `implement-required.json` | `wf-e2e-test/templates/implement-required.template.json` | P5 init |
| `manual.json` | `wf-e2e-test/templates/manual.template.json` | P5 init |

---

## Context & Checkpoint (CORE-038)

| Context % | Action |
|-----------|--------|
| <50% | Tiếp tục bình thường |
| 50-65% | Chuẩn bị checkpoint (lưu status.json) |
| 65-80% | STOP sau phase hiện tại, hướng dẫn `/clear` + `--resume` |
| >80% | FORCE STOP (E028) |

> F0a dùng ngưỡng thấp hơn F1 vì F0a phải giữ context cho F1 sau đó.

---

## Error Handling

Codes E020-E029 (per-skill namespace):

| Code | Phase | Mô tả | Action |
|------|-------|-------|--------|
| E020 | P0 | Feature spec không tồn tại hoặc content < 500 bytes | STOP, hỏi user |
| E021 | P1 | Cross-module gap critical — module phụ thuộc chưa implement | WARN, ghi vào finding |
| E022 | P1 | Business rule extraction thiếu — không tìm thấy BR trong spec | BỔ SUNG thêm nguồn |
| E023 | P2 | DB schema không tồn tại (migration files not found) | WARN, ghi N/A |
| E024 | P3 | API endpoints không tìm thấy trong code | WARN, ghi N/A |
| E025 | P4 | UI components không tìm thấy | WARN, ghi N/A |
| E026 | P5 | finding-summary consolidation thất bại | Auto-fix retry x3 |
| E027 | P5 | SSOT JSON init thất bại (template không tồn tại) | Re-init from templates |
| E028 | All | Context budget > 80% — force checkpoint | FORCE STOP |
| E029 | P0 | Phase transition blocked — PRE-GATE verify fail | STOP, escalate |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Business rule thiếu (E022) | BỔ SUNG: tìm thêm nguồn (registry.requirements, code annotations) rồi re-VERIFY | Không tìm thấy thêm nguồn — hỏi user cung cấp |
| Consolidation fail (E026) | Auto-fix retry tối đa 3 lần (Protocol 2) | Hết 3 retries — E026 escalate user |
| SSOT JSON init fail (E027) | Re-init từ templates (READ → POPULATE → WRITE, CORE-031) | Template cũng thiếu — STOP, báo devkit hỏng |
| Cross-module gap (E021) / DB-API-UI không thấy (E023-E025) | WARN + ghi N/A trong finding — F0a là FIND only, không block | Gaps critical ảnh hưởng F1 → flag trong finding-summary |
| Context >80% (E028) | FORCE STOP + checkpoint status.json (ngưỡng thấp hơn F1) | User `--resume` session mới |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-verify` (orchestrator) | Parent — spawn F0a trước F1 |
| `wf-e2e-test` (F1) | Consumer — đọc findings làm context cho live-test |
| `wf-e2e-browser` (F2) | Indirect consumer qua F1 session |

> **Next:** F0a xong → F1 `/wf-e2e-test` consume findings (PRE-GATE CORE-036); qua orchestrator `/wf-e2e-verify`.
