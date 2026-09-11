---
name: wf-verify-sync
version: 4.0.1
last_updated: 2026-05-04
description: |
  Kiểm tra đồng bộ giữa requirements và code — tìm gaps (REQ-IDs chưa implement)
  và orphan code (code không có REQ-ID). Đây là bước cuối trong DEVKIT workflow trước release.

  TRIGGER khi:
  - User nói: "verify sync", "check sync", "kiểm tra đồng bộ", "có gap không"
  - User hỏi: "ready to release chưa", "còn thiếu gì", "coverage bao nhiêu"
  - User cần REQ-ID traceability matrix
  - Keywords: "sync status", "implementation coverage", "gaps analysis"
  - Gọi lệnh: /wf-verify-sync [--scope=...] [--name=...] [--fix]

  LUÔN trigger khi user cần biết requirements nào chưa có code tương ứng,
  dù không dùng từ "verify-sync". Đây là bước QA cuối trước khi release.

  KHÔNG trigger khi:
  - General code review → dùng code-reviewer agent
  - Viết requirements docs → dùng /wf-analyze-requirements

argument-hint: "[--scope=all | system | module] [--name=<n>] [--fix] [--status] [--resume] [--from-fix-bugs[=<id>]] [--from-add-scope[=<id>]] [--from-manage-change[=<id>]] [--from-preflight[=<id>]]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---
# /wf-verify-sync: $ARGUMENTS

## Overview

| Mục                        | Nội dung                                                                         |
| --------------------------- | --------------------------------------------------------------------------------- |
| **Mục đích**       | Kiểm tra đồng bộ REQ-IDs giữa requirements và code                          |
| **Prerequisites**     | Code đã implement,`.mc-data/docs/_meta/req-registry.json` tồn tại           |
| **Workflow position** | `/wf-implement-feature` → **/wf-verify-sync** ← YOU ARE HERE → Release |
| **Output**            | `verify-sync.md` (report) + `req-registry.json` (updated `impl_status`)     |
| **Phases**            | 0 → 1 → 2 → [3 UI conditional] → [4 fix conditional] → 5 → 6                |
| **Duration**          | Multi-session (có thể dừng/resume qua checkpoint)                              |

## Arguments

| Argument                            | Mô tả                                                                                                                                                                                                                                                                                                                                          | Default |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| `--scope`                         | `all` / `system` / `module`                                                                                                                                                                                                                                                                                                                | `all` |
| `--name`                          | Tên system hoặc module khi scope hẹp hơn                                                                                                                                                                                                                                                                                                     | —      |
| `--fix`                           | Auto-add REQ-ID comment vào orphan code files                                                                                                                                                                                                                                                                                                   | —      |
| `--status`                        | Hiển thị tiến độ verify-sync hiện tại                                                                                                                                                                                                                                                                                                     | —      |
| `--resume`                        | Resume từ checkpoint session trước                                                                                                                                                                                                                                                                                                            | —      |
| `--from-fix-bugs[=<session_id>]`  | **(v2.1+)** Cross-check với fix-bugs session — consume `fix-impact.json` + `docs-sync-report.json` để verify registry changes đã apply đúng + UI coverage mismatches. Không pass `<session_id>` → auto-resolve latest completed session từ `_index/sessions.jsonl`. **Opt-in:** không pass flag → behavior cũ. | —      |
| `--from-add-scope[=<session_id>]` | **(v4.0+)** Cross-check với add-scope session — consume `scope-impact.json` để verify modules[] mới đã có trong code scan. Không pass `<session_id>` → auto-resolve latest completed session từ `_index/sessions.jsonl`. **Opt-in:** không pass flag → behavior cũ.                                              | —      |
| `--from-manage-change[=<id>]`     | **(v4.0+)** Cross-check với manage-change session — consume `change-impact.json` để verify registry_changes[] đã apply đúng. Không pass `<id>` → auto-resolve latest completed change từ `_index/sessions.jsonl`. **Opt-in:** không pass flag → behavior cũ.                                                     | —      |
| `--from-preflight[=<session_id>]` | **(v4.0+)** Cross-check với preflight session — consume `preflight-impact.json` (session-scoped artifact) để cross-reference findings. Không pass `<session_id>` → auto-resolve latest completed session từ `_index/sessions.jsonl`. **Opt-in:** không pass flag → behavior cũ.                                      | —      |

> **Multi-session skill** — Hỗ trợ `--status` để xem tiến độ và `--resume` để tiếp tục từ checkpoint.

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
>
> 1. **READ** template file từ `templates/` directory (internal) hoặc `doc-framework/` (output docs)
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.** Không viết output từ đầu khi template tồn tại.
>
> Áp dụng cho:
>
> - **Internal templates** (3 files): `templates/verify-sync-status.json`, `templates/checkpoint.json`, `templates/ui-coverage-report.md`
> - **Shared templates**: `_meta/phase-summary.template.md`, `_meta/session-log.template.json`

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention), Protocol 7 (PAR), Protocol 8 (CQG-12), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation), Protocol 11 (Rollback), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared/` directory — state-variables.md, flag-handlers.md, scope-filtering.md, registry-safe-write.md, protocols-fix-rules.md, checkpoint-protocol.md, canonical-cdg.md, req-id-patterns.md, cross-phase-flow.md.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 5): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90% — checkpoint sau Phase 1 nếu project lớn (> 500 files)
- **Registry Safe-Write** (Phase 6): CHỈ update field `impl_status` per REQ-ID — **KHÔNG downgrade "done"** (CORE-008)
- **Token Limit Prevention** (Protocol 6): Scan-based skill — Phase 1 dùng Grep trực tiếp, không spawn agent. Registry safe-write trong main conversation.
- **Sequential Grep Scan** (Phase 1): Phase 1 — collect REQ-IDs (Group A) + scan code (Group B) thực thi tuần tự bằng Grep trực tiếp trong conversation, KHÔNG spawn agent riêng. Gọi là "PARALLEL" trong execution table chỉ có nghĩa 2 groups logic độc lập — không phải agent parallelism (Protocol 7).
- **Content Quality Gate** (Protocol 8): Phase 5 (CQG-12) — verify sync_rate tính đúng, gap list đầy đủ.
- **Phase Summary** (CORE-028): Phase 6 tạo `phase-summary.md` — tóm tắt skill bằng tiếng Việt.

## Execution Strategy

| Phase                 | Phase ID                  | Chế độ                                                            |
| --------------------- | ------------------------- | -------------------------------------------------------------------- |
| 0 (init + preflight)  | `phase0-init.md`        | SEQUENTIAL                                                           |
| 1 (collect + scan)    | `phase1-scan.md`        | SEQUENTIAL Grep calls — 2 logical groups (A: REQ-IDs, B: code scan) |
| 2 (analyze)           | `phase2-analyze.md`     | SEQUENTIAL                                                           |
| 3 (UI coverage)       | `phase3-ui-coverage.md` | SEQUENTIAL —**conditional** (`interface_type != api-only`)  |
| 4 (fix)               | `phase4-fix.md`         | SEQUENTIAL —**conditional** (`--fix`)                       |
| 5 (cross-validation)  | `phase5-crossval.md`    | SEQUENTIAL — auto-correction loop max 3 iter                        |
| 6 (report + finalize) | `phase6-report.md`      | SEQUENTIAL — main conversation, KHÔNG spawn agent                  |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

## Work Directory

```
.mc-data/work/wf-verify-sync/
├── verify-sync-status.json    # Runtime status
├── checkpoint.json            # Checkpoint cho resume
├── ui-coverage-report.md      # Phase 3 output (conditional)
├── ui-snapshot.json           # Raw UI scan (conditional)
├── verify-sync-history.md     # Append-only history log
└── phase-summary.md           # CORE-028 summary
```

Templates: `.claude/skills/workflow/wf-verify-sync/templates/`

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools duoc auto-detect, khong hoi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sanh HEAD vs index_commit. SEVERE (>20 behind) → warning: "GitNexus results may miss recent REQ-IDs (Serena unaffected — real-time LSP)." | Freshness status set |

### CI-ROUTE: REQ-ID Search & Cross-Reference (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus cypher + Serena de tim REQ-IDs thay vi grep thu cong.
> **Graceful:** CI unavailable → fallback grep (current behavior, zero regression).

| Phase | CI Task | Primary Tool | Fallback | Purpose |
|-------|---------|-------------|----------|---------|
| 2 (Code Scan) | `find_by_annotation` | **GitNexus** `cypher` (REQ-ID search) / **Serena** `find_references` (REQ-ID constants) | `grep -rn "REQ-ID:"` | Tim tat ca REQ-ID annotations trong code |
| 2 (Code Scan) | `cross_validate` | **Compare** GitNexus results ∩ Grep results | Grep-only | Report discrepancies |
| 3 (Cross-ref) | `find_references` | **Serena** `find_references` (per REQ-ID) / **GitNexus** `context` | grep | Tim tat ca noi reference REQ-ID |

> **Freshness caveat:** GitNexus cypher results co the thieu REQ-ID moi (index stale) — cross-validate voi Grep.
> Serena results chinh xac (real-time LSP), khong bi anh huong boi index staleness.

```
STEP 1: Parse flags từ $ARGUMENTS
  → Capture: $SCOPE, $NAME, $HAS_FIX_FLAG, $HAS_STATUS_FLAG, $HAS_RESUME_FLAG,
             $HAS_FROM_FIX_BUGS_FLAG, $FROM_FIX_BUGS_SESSION_ID,
             $HAS_FROM_ADD_SCOPE_FLAG, $FROM_ADD_SCOPE_SESSION_ID,
             $HAS_FROM_MANAGE_CHANGE_FLAG, $FROM_MANAGE_CHANGE_ID,
             $HAS_FROM_PREFLIGHT_FLAG, $FROM_PREFLIGHT_SESSION_ID
  → `--from-fix-bugs` parse: nếu có `=<id>` → set $FROM_FIX_BUGS_SESSION_ID;
    nếu chỉ `--from-fix-bugs` (no value) → $FROM_FIX_BUGS_SESSION_ID="" (auto-resolve latest)
  → `--from-add-scope`, `--from-manage-change`, `--from-preflight`: same pattern — `=<id>` hoặc auto-resolve

STEP 2: Route theo flag
  IF --status:
    → Load procedures/_shared/flag-handlers.md → chạy --status handler (6 bước)
    → STOP (không tiếp tục phases)

  IF --resume:
    → Load procedures/_shared/flag-handlers.md → chạy --resume handler + RESUME RECONCILIATION
    → CONTINUE từ checkpoint (next_action) — load đúng phase file tương ứng

  ELSE:
    → Load procedures/phase0-init.md → thực thi tuần tự đến phase6-report.md
    (phase0-init.md Steps 0.18-0.22 sẽ load $FIX_IMPACT_CONTEXT + $DOCS_SYNC_CONTEXT
     nếu $HAS_FROM_FIX_BUGS_FLAG=true; Steps 0.23-0.25 load $ADD_SCOPE_CONTEXT nếu
     --from-add-scope; Steps 0.26-0.28 load $MANAGE_CHANGE_CONTEXT nếu
     --from-manage-change; Steps 0.29-0.31 load $PREFLIGHT_IMPACT_CONTEXT nếu
     --from-preflight)
```

---

## Phase 1-6: Procedure Routing

| Phase       | Procedure file            | Mục đích                                                             | PRE-GATE                                                                                          | POST-GATE chính                                                                |
| ----------- | ------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **0** | `phase0-init.md`        | Prerequisites + Preflight Context (cũ Phase 1+1.5)                     | `test -f req-registry.json` + forensic                                                          | `$SCOPE_FILTER` built, status/checkpoint init                                 |
| **1** | `phase1-scan.md`        | Collect REQ-IDs (A) + Scan Code (B) —**PARALLEL**                | Phase 0 PASS                                                                                      | `$REQ_INDEX`, `$CODE_REFS`, `$ORPHAN_LIST` defined                        |
| **2** | `phase2-analyze.md`     | Calculate Sync Rate + Identify Gaps (cũ Phase 4+5)                     | Phase 1 PASS                                                                                      | `$SYNC_RATE`, `$COVERAGE_RATE`, `$W001_ANOMALIES`, `$GAPS_LIST` defined |
| **3** | `phase3-ui-coverage.md` | UI-Code Coverage Check —**conditional** (cũ Phase 5b)           | `interface_type != api-only` + UI dirs exist                                                    | `ui-coverage-report.md` written (hoặc skipped)                               |
| **4** | `phase4-fix.md`         | Auto-add REQ-ID + W001 fixes —**conditional** (cũ Phase 6)      | `$HAS_FIX_FLAG = true` | `$FIX_LOG` defined (empty array OK if nothing to fix), no regression |                                                                                 |
| **5** | `phase5-crossval.md`    | Cross-validation 10 checks — auto-correction (cũ Phase 6a)            | Phase 2 PASS                                                                                      | Zero arithmetic/logic errors                                                    |
| **6** | `phase6-report.md`      | Generate verify-sync.md + safe-update registry + finalize (cũ Phase 7) | Phase 5 PASS                                                                                      | `verify-sync.md` written, registry valid, summary written                     |

> **Cách load:** Mỗi phase là 1 file độc lập trong `procedures/`. Khi tới phase, READ file đó, thực thi steps, verify POST-GATE, rồi NEXT theo "NEXT" footer của file.
>
> **`_shared/` files** — chỉ load file cần thiết khi tham chiếu, KHÔNG đọc toàn bộ standalone.

### Steps Summary

| Step | Action                                                                                       |
| ---- | -------------------------------------------------------------------------------------------- |
| 0    | Init — session routing, lock acquire, scope resolve, --from-* context load                  |
| 1    | Scan — collect REQ-IDs từ registry + scan code files tìm REQ-ID comments                  |
| 2    | Analyze — match REQ_INDEX vs CODE_REFS, compute sync rate, detect W001/W002/W003            |
| 3    | UI Coverage — scan UI components, match screens → features (skip nếu api-only)            |
| 4    | Fix — auto-add REQ-ID comments cho orphan code files (--fix only)                           |
| 5    | Cross-Validate — 10 deterministic checks + auto-correction loop (max 3 iterations)          |
| 6    | Report — generate verify-sync.md, canonical dual-write, registry safe-update, phase-summary |

---

## Output Files

| File                                                     | Đường dẫn đầy đủ                                                       | Phase           | Template                                                                              |
| -------------------------------------------------------- | ------------------------------------------------------------------------------ | --------------- | ------------------------------------------------------------------------------------- |
| **PRIMARY OUTPUTS**                                |                                                                                |                 |                                                                                       |
| Verify-sync session copy                                 | `.mc-data/work/wf-verify-sync/sessions/{session_id}/verify-sync.md`          | 6               | History preserved per-session. Đây là báo cáo chính thức của mỗi lần chạy. |
| Actionable checklist                                     | `.mc-data/work/wf-verify-sync/sessions/{session_id}/actionable-checklist.md` | 6               | File checklist độc lập dùng để theo dõi tiến độ.                            |
| Registry (impl_status)                                   | `.mc-data/docs/_meta/req-registry.json`                                      | 6               | — (safe-update + registry lock)                                                      |
| **SESSION-SCOPED WORKING FILES**                   |                                                                                |                 |                                                                                       |
| Session status                                           | `.mc-data/work/wf-verify-sync/sessions/{session_id}/verify-sync-status.json` | 0/6             | `templates/verify-sync-status.json`                                                 |
| Checkpoint                                               | `.mc-data/work/wf-verify-sync/sessions/{session_id}/checkpoint.json`         | 0/6             | `templates/checkpoint.json`                                                         |
| UI coverage report                                       | `.mc-data/work/wf-verify-sync/sessions/{session_id}/ui-coverage-report.md`   | 3 (conditional) | `templates/ui-coverage-report.md` — chỉ khi `interface_type != "api-only"`      |
| UI snapshot                                              | `.mc-data/work/wf-verify-sync/sessions/{session_id}/ui-snapshot.json`        | 3 (conditional) | — (raw scan output)                                                                  |
| Phase summary                                            | `.mc-data/work/wf-verify-sync/sessions/{session_id}/phase-summary.md`        | 6               | `.claude/doc-framework/_meta/phase-summary.template.md`                             |
| Verify-sync impact                                       | `.mc-data/work/wf-verify-sync/sessions/{session_id}/verify-sync-impact.json` | 6               | `templates/verify-sync-impact.json` (schema verify-sync-impact-v1)                  |
| **GLOBAL FILES (top-level — NOT session-scoped)** |                                                                                |                 |                                                                                       |
| Sync history log                                         | `.mc-data/work/wf-verify-sync/verify-sync-history.md`                        | 6               | — (append-only:`[date] session=[id] scope=[scope] sync=[rate]%`)                   |
| Sessions index                                           | `.mc-data/work/wf-verify-sync/_index/sessions.jsonl`                         | 0/6             | — (append-only JSONL)                                                                |
| Source files (orphan fix)                                | Đường dẫn gốc của từng file orphan                                      | 4 (conditional) | — (thêm REQ-ID comment header)                                                      |

## Output Report

ALWAYS dùng template này khi hoàn thành:

```markdown
## Sync Verification Report

| Project | [name] | Date | YYYY-MM-DD | Scope | [all / system / module] |
|---------|--------|------|------------|-------|-------------------------|

### Summary

| Metric | Value |
|--------|-------|
| Total REQ-IDs | X |
| Implemented (done) | X (X%) |
| In Progress | X (X%) |
| Not Started | X (X%) |
| Skipped | X |
| Orphan Code Files | X |

**Sync Rate: X%** [READY: ≥80% AND features_in_progress=0 · PARTIAL_FEATURES: ≥80% nhưng features_in_progress>0 · PARTIAL: 60-79% · NOT READY: <60%]
**Coverage Rate: X%** [tổng code đã viết / total REQ-IDs]
**Verdict: READY / PARTIAL_FEATURES / PARTIAL / NOT READY**

> **Priority override:** Nếu có bất kỳ REQ-ID nào với `priority="critical"` hoặc `priority="high"` còn `impl_status="not_started"` → Verdict là **NOT READY** bất kể Sync Rate >= 80%. Ghi chú rõ danh sách REQ-IDs blocking trong Summary.
>
> Sync Rate chỉ đếm REQ-IDs có `impl_status="done"`. Coverage Rate đếm tất cả code đã viết (done + in_progress).
> Skipped REQ-IDs không tính vào sync rate. Xem danh sách skipped bên dưới.
> **READY verdict yêu cầu:** Sync Rate ≥ 80% **VÀ** `features[].in_progress == 0`. Nếu có features in_progress → PARTIAL_FEATURES (chưa sẵn sàng release).

- Skipped: N REQ-IDs (deprecated theo legacy-decisions.json hoặc user skip)
  → Không tính vào sync rate — xem chi tiết tại [danh sách skipped]

### Feature Completion

| Metric | Value |
|--------|-------|
| Total Features | X |
| Done | X (X%) |
| In Progress | X |
| Not Started | X |
| Skipped | X |

> [NẾU in_progress > 0:] ⚠️ **X feature(s) đang `in_progress`** — chưa hoàn thành. Verdict: **PARTIAL_FEATURES** — không nên chạy `/wf-prepare-deployment` cho đến khi các features sau được hoàn thành:
>
> | FEAT-ID | Tên |
> |---------|-----|
> | FEAT-XXX-001 | Feature name |
>
> [NẾU in_progress == 0 AND total > 0:] Tất cả features đã hoàn thành hoặc skipped. ✅

### Warnings (nếu có)

| Code | REQ-ID | Mô tả | Phân loại | Suggested Fix | Hành động |
|------|--------|-------|-----------|---------------|-----------|
| W001 | REQ-XXX-NNN | `impl_status="done"` nhưng code scan không tìm thấy | format_mismatch / code_refactored / genuine_missing | [candidate file hoặc fix command] | KHÔNG downgrade — yêu cầu user xác nhận |
| W003 | REQ-YYY-NNN | `impl_status="done"` và có code nhưng Feature cha chưa hoàn thành | partial_feature | Hoàn thiện Feature [FEAT-ID] | KHÔNG downgrade registry — hiển thị In Progress trong báo cáo |

### Actionable Checklist (Kế hoạch triển khai)

Dưới đây là các tính năng chưa hoàn thành (Gaps & In Progress), được gom nhóm theo Hệ thống (System). Sử dụng checkbox để quản lý tiến độ và copy lệnh tương ứng để AI triển khai.

#### 🌐 SYS-ERP-WEB (Ví dụ System)
| Trạng thái | Module | Tính năng (Feature) | Thuộc Yêu cầu (REQ) | Lệnh triển khai |
|---|---|---|---|---|
| [ ] `in_progress` | Finance | FEAT-EW-FIN-002: Ledger Entries | REQ-FIN-002 | `/wf-implement-feature FEAT-EW-FIN-002` |
| [ ] `not_started` | Finance | FEAT-EW-FIN-001: Chart of Accounts | REQ-FIN-001 | `/wf-implement-feature FEAT-EW-FIN-001` |

### Orphan Code

| File | Suggested REQ-ID | Action |
|------|------------------|--------|
| src/utils/format.ts | Unknown | Review và assign REQ-ID |

Full report: `.mc-data/docs/_meta/verify-sync.md`
Next: Fix gaps rồi chạy lại `/wf-verify-sync` — hoặc Release nếu sync rate >= 80%
```

#### Utility Scripts

> **Lưu ý:** Các scripts trong `scripts/` là **standalone utilities** cho user chạy manual — KHÔNG được gọi trong procedures flow. Skill execution dùng Claude Code built-in tools (Grep, Glob) trực tiếp. Scripts dùng cho: pre-run inspection, manual debugging, hoặc CI integration.

- **Pipeline Naming Validation**: `.claude/scripts/validate-pipeline-naming.sh`
  - Validates naming consistency across `.mc-data/` output (modules, systems, registry)
  - Run after wf-verify-sync to ensure naming conventions are consistent
  - Usage: `bash .claude/scripts/validate-pipeline-naming.sh [.mc-data]`

---

## Error Handling

| Code | Phase       | Tình huống                                                                            | Xử lý                                                                                     |
| ---- | ----------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| E001 | 0           | `req-registry.json` không tồn tại hoặc rỗng (PRE-GATE forensic fail)             | STOP → chạy `/wf-analyze-requirements` trước                                          |
| E002 | 0           | Không chạy từ project root (không tìm thấy `.mc-data/`)                         | Yêu cầu user cd đến project root, hoặc auto-detect parent directory                    |
| E003 | 0           | Không tìm thấy `src/` hoặc `apps/` directory                                    | STOP → chạy `/wf-implement-feature` trước                                             |
| E004 | 0           | `jq` không khả dụng                                                                | STOP → yêu cầu user cài đặt jq                                                        |
| E005 | 0           | `--scope` yêu cầu `--name`                                                        | STOP → yêu cầu user cung cấp --name                                                     |
| E006 | 0           | `--name` không tồn tại trong registry (system_id hoặc module_id invalid)          | STOP → liệt kê valid IDs từ registry, yêu cầu user chọn lại                         |
| E007 | 0           | `--resume` session_id không tìm thấy                                               | STOP → liệt kê recent sessions, yêu cầu user chọn                                     |
| E008 | 0           | `--resume` session lock conflict (phiên khác đang chạy)                           | STOP → hiển thị lock owner, yêu cầu user xác nhận                                    |
| E009 | 0           | Registry fingerprint mismatch (`--resume`)                                            | CDG prompt: Full scan / Partial resume / Force resume                                       |
| E010 | 1           | Scope filter yields zero REQ-IDs                                                        | STOP → kiểm tra scope filter logic                                                        |
| E011 | 1           | Code scan found zero source files (empty src/)                                          | STOP → kiểm tra source directories                                                        |
| E012 | 1           | All code files excluded by patterns                                                     | STOP → kiểm tra exclude patterns trong `_shared/req-id-patterns.md`                     |
| E013 | 1           | Orphan file trong modules/ directory (không phải utils/)                              | Flag as HIGH PRIORITY orphan — có thể là code bị miss trong implementation             |
| E020 | 2           | Total REQ-IDs (sau khi loại skipped) == 0 — tất cả skipped hoặc scope filter rỗng | Set `$SYNC_RATE = null`, SKIP Phase 2 rate calculation, generate N/A report trong Phase 6 |
| E021 | 2           | Sync rate computation error (division by zero)                                          | LOG ERROR, set `$SYNC_RATE = null`                                                        |
| E030 | 3           | UI directories not found (interface_type != api-only)                                   | WARNING → SKIP Phase 3                                                                     |
| E040 | 4           | `--fix` flag set but no gaps to fix                                                   | SKIP Phase 4, log info                                                                      |
| E041 | 4           | Fix attempted on unknown file extension                                                 | Skip file, log WARNING → cần xử lý thủ công                                           |
| E042 | 4           | Auto-fix regression detected                                                            | STOP auto-fix, escalate to user với báo cáo chi tiết                                    |
| E050 | 5           | Crossval iteration limit exceeded (3)                                                   | STOP → escalate to user với báo cáo error_log[]                                         |
| E051 | 5           | Circular regression detected (error count not decreasing)                               | STOP ngay → có thể có circular regression, escalate                                     |
| E052 | 5           | Cross-validation arithmetic mismatch (sau 3 retries)                                    | STOP → báo cáo chi tiết error_log[]                                                     |
| E060 | 6           | Canonical dual-write CDG cancelled by user                                              | Log WARNING → canonical not updated, session copy preserved                                |
| E061 | 6           | Registry safe-write lock acquisition failed                                             | Retry x3, rollback nếu vẫn fail                                                           |
| E062 | 6           | JSON invalid sau registry update                                                        | Retry x3, rollback nếu vẫn fail                                                           |
| E070 | Session     | Lock acquisition failed (session already locked)                                        | STOP → hiển thị lock owner, yêu cầu user xác nhận                                    |
| E071 | Session     | Stale lock cleanup failed                                                               | STOP → thử force cleanup, escalate nếu fail                                              |
| E072 | Session     | Heartbeat daemon died unexpectedly                                                      | WARNING → attempt re-spawn, continue với degraded safety                                  |
| E073 | Session     | `to_epoch` parse failure (cannot determine lock age)                                  | STOP → không thể xác định lock freshness                                              |
| E080 | Cross-skill | `--from-add-scope` session not found                                                  | WARNING → skip context, continue                                                           |
| E081 | Cross-skill | `--from-manage-change` session not found                                              | WARNING → skip context, continue                                                           |
| E082 | Cross-skill | `--from-preflight` session not found                                                  | WARNING → skip context, continue                                                           |
| W001 | 2           | REQ-ID `impl_status=done` nhưng code scan không tìm thấy                          | WARNING trong report, KHÔNG tự downgrade — yêu cầu user xác nhận                     |
| W002 | 2           | REQ-ID `impl_status=in_progress` nhưng code scan không tìm thấy                   | WARNING — đưa vào `$GAPS_LIST` type="partial_implementation"                          |
| W003 | 2           | REQ-ID `impl_status=done` và có code nhưng Feature cha chưa hoàn thành          | WARNING — downgrade xuống In Progress trong báo cáo, KHÔNG downgrade registry          |
| E057 | 5 (CF6)     | Circular dependency phát hiện trong cross_feat_refs (A→B→C→A)                   | CRITICAL — BLOCK Phase 6, yêu cầu user resolve cross-FEAT cycles                     |
| W-CF6-001 | 5 (CF6) | cross_feat_refs.target_req_id hoặc target_feat_id không tồn tại trong registry  | WARNING — display trong report, KHÔNG block                                           |
| W-CF6-002 | 5 (CF6) | cross_feat_refs với relationship="consume" nhưng target.impl_status != "done"   | WARNING — gợi ý implement target trước, KHÔNG block                                  |

---

## Related Skills

| Skill                        | Quan hệ                                           |
| ---------------------------- | -------------------------------------------------- |
| `/wf-implement-feature`    | Prerequisite                                       |
| `/wf-fix-bugs`             | Alternative — chạy khi cần fix bugs + sync docs |
| `/wf-design`               | Prerequisite                                       |
| `/wf-analyze-requirements` | Prerequisite                                       |
| `/wf-prepare-deployment`   | Next step — sau khi sync rate >= 80%              |
| `/status`                  | Xem tiến độ chi tiết                           |
