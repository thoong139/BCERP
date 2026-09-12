---
name: wf-e2e-unblock
version: 2.1.0
last_updated: 2026-09-12
description: |
  F3 trong chuỗi wf-e2e-* (chia tách từ wf-e2e-verify v6.5.0 cờ --unblock-test).
  Đọc block-test.json → phân loại 4 nhóm → auto-unblock Nhóm 1 (Data) + Nhóm 2 (Infra) + Nhóm 4 (Hard Test verify code).
  Nhóm 3 (Not Implemented) → SKIP (delegate sang F4 wf-e2e-implement, không xử lý ở đây).
  Output: unblock-report.md + UPDATE block-test.json (status, retest_result) + APPEND manual.json (Group 4 verified-OK).
  YÊU CẦU --session=<id> từ orchestrator hoặc F1 (không tạo session mới).

  v2.0.0: Strict task generation cho Group 3 — bắt buộc target_file, target_line, proposed_signature,
  acceptance_criteria. POST-GATE T3 enforce 4 fields cho mọi Nhóm 3 entry trong implement-required.json.
  AUTO-FLAG requires_arch_review khi Group 3 count ≥ 5 (CDG-07).

  TRIGGER khi: "unblock tests", "xử lý blocked tests", "auto-unblock", "gỡ block".
  KHÔNG trigger: cần implement code (dùng F4 wf-e2e-implement), full pipeline (dùng /wf-e2e-verify).

argument-hint: "<FEAT-ID> --session=<id> [--resume] [--status]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__serena__find_symbol, mcp__serena__find_referencing_symbols,
  mcp__serena__search_for_pattern,
  mcp__gitnexus__query, mcp__gitnexus__context
---

# /wf-e2e-unblock: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Xử lý blocked tests trong block-test.json → auto-unblock Nhóm 1+2+4 → KHÔNG xử lý Nhóm 3 (defer F4) |
| **Prerequisites** | `block-test.json` có ≥1 entry status=blocked (từ F1/F2) + `--session=<id>` BẮT BUỘC (PRE-GATE T1-T4) |
| **Standalone** | NO — require `--session=<id>` từ orchestrator hoặc F1 |
| **Input** | `block-test.json` (từ F1/F2), `manual.json` (optional read), `findings/` (đọc context) |
| **Output** | `unblock-report.md`, UPDATE `block-test.json`, APPEND `manual.json` (Group 4 verified-OK) |
| **Phase** | Single phase `unblock` (loop qua từng BLK-NNN trong block-test.json) |

### Flow

```
[--session=<id>] → [PRE-GATE: block-test.json tồn tại + ≥1 entry status=blocked]
→ [LOAD blocks] → [CLASSIFY per BLK-NNN]
  ├── Nhóm 1 (Data) → AUTO-FIX (seed) → RETEST → unblock | fallback fail
  ├── Nhóm 2 (Infra) → AUTO-FIX (Infrastructure Auto-Start / grant permission) → RETEST → unblock | fallback
  ├── Nhóm 3 (Not Impl) → SKIP (note "delegate to F4 wf-e2e-implement")
  └── Nhóm 4 (Hard Test) → VERIFY CODE → code PASS → mark resolved + append manual.json
                                       → code FAIL → keep blocked + note needs implementation
                                       → code INCONCLUSIVE → keep blocked + note needs human
→ [WRITE unblock-report.md] → [UPDATE block-test.json + manual.json] → DONE
```

---

## Workflow Position

```
F1 wf-e2e-test / F2 wf-e2e-browser
        │
        ▼ block-test.json populated
   ┌─────────┐
   │   F3    │ ← wf-e2e-unblock (skill này)
   │ Unblock │
   └────┬────┘
        ▼ block-test.json updated + manual.json appended
   F4 wf-e2e-implement (Nhóm 3 còn lại) → F5 retest → F6 fix
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `<FEAT-ID>` | ID feature trong registry | required |
| `--session=<id>` | Session ID (BẮT BUỘC — phải có từ orchestrator/F1) | required |
| `--resume` | Resume nếu F3 bị interrupt giữa chừng | - |
| `--status` | Display unblock progress + STOP | - |

---

## CI PRE-GATE (CORE-033)

> CI tools auto-detect. F3 can CI cho Group 4 code verification (Serena, GitNexus impact).

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: Run `bash .claude/scripts/ci-detect.sh`. | CI flags set |
| **Nb** | Index Freshness Check: Run `bash .claude/scripts/ci-freshness-check.sh`. | Freshness status set |
| **Nc** | Agent Context Injection: Run `bash .claude/scripts/ci-inject-context.sh` (reserved). | CI context ready |

### CI-ROUTE

| CI Task | Primary Tool | Fallback |
|---------|-------------|----------|
| `impact_analysis` | GitNexus `impact({target})` | Grep |
| `symbol_overview` | Serena `get_symbols_overview` | Read |
| `find_by_annotation` | Serena `find_referencing_symbols` | Grep REQ-ID |

---
## Session Structure

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── block-test.json                  ← READ + UPDATE (F3 chính)
├── manual.json                      ← APPEND (Group 4 verified-OK)
├── issues.json                      ← APPEND (nếu unblock reveals new issue)
├── findings/                        ← READ context
├── F3-unblock/
│   ├── status.json                  ← F3 own state
│   ├── unblock-report.md            ← Output chính
│   └── Phase-report.md              ← CORE-028 summary
```

---

## Phase 0: Load & Classify Blocks (BẮT BUỘC — entry point)

> Chi tiết: `procedures/_shared.md` §pre-gate/§load. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | PRE-GATE T1-T4: block-test.json tồn tại + schema valid + ≥1 blocked + enum hợp lệ | Fail → E030 STOP |
| 2 | CI PRE-GATE Na-Nc (Group 4 cần Serena/GitNexus verify code) | CI flags set |
| 3 | LOAD blocks → group entries by blocking_reason (4 nhóm) | Mọi BLK-NNN được classify |
| 4 | Loop từng nhóm theo routing map (1/2 auto-fix, 3 skip, 4 verify code) | Mỗi entry có kết quả cuối |

## Phase Routing (CORE-032 lazy-load)

| # | Sub-phase | Procedure file | Description |
|---|-----------|---------------|-------------|
| **0** | PRE-GATE | `procedures/_shared.md` §pre-gate | Validate block-test.json tồn tại + ≥1 entry status=blocked |
| **1** | LOAD | `procedures/_shared.md` §load | Load block-test.json + group entries by blocking_reason |
| **2** | GROUP 1 (Data) | `procedures/unblock-group1-data.md` | Auto-fix seed data + retest |
| **3** | GROUP 2 (Infra) | `procedures/unblock-group2-infra.md` | Infrastructure Auto-Start + retest |
| **4** | GROUP 3 (Not Impl) | `procedures/_shared.md` §group3-skip | SKIP — note "delegate to F4" trong unblock-report.md |
| **5** | GROUP 4 (Hard Test) | `procedures/unblock-group4-hardtest.md` | Verify code → dual-write manual.json + update block-test.json |
| **6** | REPORT | `procedures/_shared.md` §report | Write unblock-report.md từ template + update block-test.json summary |
| **R** | Resume/Status | `procedures/resume-status.md` | --resume / --status handlers |

---

## 4-Group Classification (canonical từ F1 block-classification.md)

| Nhóm | blocking_reason enum | F3 action |
|------|---------------------|-----------|
| **1. Data** | `missing_seed_data`, `missing_cross_module_data`, `seed_accounts_unavailable`, `actor_account_missing` | Auto-fix seed (gen SQL INSERT, run, verify count). Retry 2 lần. Pass → status=unblocked, retest_result=PASS. Fail → keep blocked |
| **2. Infra** | `backend_not_running`, `fe_not_running`, `missing_permissions` | Infrastructure Auto-Start (DB container / BE / FE) hoặc grant permission. Retry 2 lần. Pass → unblocked. Fail → keep blocked |
| **3. Not Implemented** | `feature_deferred`, `feature_not_implemented` | **SKIP** — note "F4 wf-e2e-implement sẽ xử lý". KHÔNG attempt unblock |
| **4. Hard Test** | `requires_visual_inspection`, `requires_manual_interaction`, `external_dependency`, `flaky_test`, `requires_human_judgment`, `other` | VERIFY CODE (Serena/Grep) → PASS → status=resolved + manual.json append (code_verification.result=PASS, recommended_test_steps[]). FAIL → keep blocked + escalate as issue. INCONCLUSIVE → manual.json (result=INCONCLUSIVE, needs human) |

---

## PRE-GATE (CORE-011)

1. **T1 file existence:** `block-test.json` tồn tại trong session
2. **T2 schema valid:** `jq -e '.blocked_tests | length > 0' block-test.json` pass
3. **T3 content depth:** Có ≥1 entry với `status=="blocked"`
4. **T4 cross-ref:** Mỗi BLK-NNN có `blocking_reason` thuộc enum hợp lệ

Fail → E030 "block-test.json không hợp lệ hoặc rỗng" + STOP.

---

## POST-GATE (CORE-012)

1. **T1:** `unblock-report.md` tồn tại + non-empty
2. **T2:** `block-test.json` summary counts khớp với entries
3. **T3 (v2.0.0 — Nhóm 3 Strict Fields):** Mỗi entry trong `implement-required.json` có `group=3`
   BẮT BUỘC có đủ 4 fields:
   - `target_file`: non-null, len > 0
   - `target_line`: non-null, match pattern `^[0-9]+(-[0-9]+)?$`
   - `proposed_signature`: non-null, len > 10
   - `acceptance_criteria`: array với ≥1 item

   Fail → E030 (missing required field) → BLOCK F3 completion (không advance sang F4).

4. **T4:** Mỗi Group 4 verified-OK có related_manual_id link tới manual.json (2 chiều)

Fail → auto-fix retry (max 3) → E035.

---

## --resume + --status

Xem `procedures/resume-status.md`.

**--status:** Display unblock progress table (BLK-NNN | nhóm | hành động | kết quả) + STOP.
**--resume:** Tiếp tục từ BLK-NNN cuối cùng đang xử lý (idempotent, không re-attempt đã unblocked).

---

## Error Handling

Codes E030-E039 namespace (per-skill):

| Code | Mô tả | Action |
|------|-------|--------|
| E030 | block-test.json không tồn tại hoặc rỗng | STOP, suggest run F1/F2 trước |
| E031 | --session thiếu | STOP, hỏi user cung cấp |
| E032 | Auto-fix Group 1 fail 2 lần | Keep blocked, log fix-log |
| E033 | Auto-fix Group 2 fail 2 lần (infrastructure không start) | Keep blocked, alert user |
| E034 | Group 4 code_verification fail → escalate as issue (E034) | APPEND issues.json |
| E035 | POST-GATE cross-ref fail | Auto-fix retry |
| E036 | manual.json append fail (corrupt JSON) | Atomic write retry |
| E037 | block-test.json update fail (corrupt) | Atomic write retry |
| E038 | unblock-report.md template không tồn tại | Re-copy from skill templates |
| E039 | Lock conflict khi update block-test.json | Retry với backoff |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Group 1 thiếu seed data | Auto-fix: gen SQL INSERT + run + verify count (retry ×2) | Fail 2 lần → E032 keep blocked, log fix-log |
| Group 2 infra chưa chạy | Infrastructure Auto-Start (DB container/BE/FE) hoặc grant permission (retry ×2) | Fail 2 lần → E033 keep blocked, alert user |
| Group 3 Not Implemented | KHÔNG attempt unblock — note "delegate to F4 wf-e2e-implement" | Không escalate (đúng thiết kế defer) |
| Group 4 Hard Test | Verify code (Serena/Grep): PASS → resolved + manual.json; INCONCLUSIVE → manual.json needs human | FAIL → E034 APPEND issues.json escalate |
| POST-GATE T3 strict fields thiếu (target_file/target_line/proposed_signature/acceptance_criteria) | Auto-fix retry ×3 (điền lại fields) | Hết 3 retries → E030 BLOCK F3 completion |
| Cross-ref 2 chiều thiếu (E035) | Auto-fix link lại related_manual_id | Hết 3 retries → escalate |
| Corrupt JSON (E036/E037) | Atomic write retry (rebuild từ entries in-memory) | Vẫn fail → STOP |
| Template thiếu (E038) | Re-copy from skill templates (CORE-031) | Template gốc thiếu — STOP, báo devkit |

---

## Output Files

| File | Path (trong session) | Loại |
|------|----------------------|------|
| unblock-report.md + Phase-report.md (CORE-028) | `F3-unblock/` | CREATE |
| status.json | `F3-unblock/` | CREATE + UPDATE |
| block-test.json | session root | READ + UPDATE (blocked → unblocked/resolved) |
| manual.json | session root | APPEND (Group 4 verified-OK) |
| issues.json | session root | APPEND (E034 — unblock reveals new issue) |

> **Next:** F3 xong → F4 `/wf-e2e-implement` (xử lý Nhóm 3 còn lại) → F5 `/wf-e2e-retest`; qua orchestrator `/wf-e2e-verify`.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-test` (F1) / `wf-e2e-browser` (F2) | Producer block-test.json + implement-required.json + manual.json |
| `wf-e2e-implement` (F4) | F3 SKIP Group 3 → F4 xử lý |
| `wf-e2e-retest` (F5) | F3 unblock → F5 retest items đã unblocked |
| `wf-e2e-verify` (orchestrator) | Spawn F3 sau F1+F2 nếu block-test có entries |

---

## Backward Compatibility

Legacy command `/wf-e2e-verify <FEAT-ID> --unblock-test --session=<id>` → orchestrator detect flag → spawn F3 standalone mode với cùng session.
