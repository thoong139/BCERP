---
name: audit-devkit-fix
version: 1.4.0
last_updated: 2026-09-12
changelog:
  v1.4.0 (2026-09-12):
    - Compliance fix: thêm Output Files section, đổi heading Error Codes → Error Handling,
      thêm Next step (audit 7.1/8.1/2.2/7.2). Không đổi fix logic.
  v1.3.0 (2026-04-19):
    - Tái cấu trúc: tách SKILL.md monolithic (993 dòng) thành SKILL.md orchestrator (~400 dòng) + 6 procedure files.
    - Mỗi phase (0-3) tách thành file procedure riêng — load ON-DEMAND để giảm context load.
    - Tách Fix Patterns (FP1-FP9) sang `procedures/fix-patterns.md` — chỉ load khi Phase 1 match pattern.
    - Tách cross-cutting protocols (Fix Rules, Auto-Fix Limits, FP Recognition, Error codes) sang `procedures/_shared.md`.
    - KHÔNG thay đổi logic behavior — behavior-equivalent với v1.2.0.
  v1.2.0 (2026-04-14):
    - Thêm verify-complete gate check (Phase 0 Step 0.1a) — bắt buộc verify status = "completed" trước khi fix.
description: |
  Auto-fix issues từ /audit-devkit-verify.
  Per-fix verification: mỗi fix được verify NGAY LẬP TỨC — Read → Edit → Grep verify → Pass/Revert.
  Revert nếu verify fail. KHÔNG fix manual issues.
  v1.2: thêm verify-complete gate check (bắt buộc verify status = completed trước khi fix).
  v1.3: tái cấu trúc thành orchestrator + procedures (load on-demand) để giảm context load.

  TRIGGER khi:
  - Đã chạy /audit-devkit-verify xong, cần auto-fix verified findings
  - Bước thứ 3 trong audit pipeline (scan → verify → fix)
  - Keywords: "audit fix", "fix devkit", "audit-devkit-fix"

  KHÔNG trigger khi:
  - Chưa có verified results → dùng /audit-devkit-verify trước
  - Cần scan lại → dùng /audit-devkit-scan
  - Audit dự án đang dùng MCV3 → không liên quan
  - Chỉ audit agents → dùng /audit-agents

argument-hint: "[--dry-run] [--severity=CRITICAL|MAJOR|ALL] [--session=<id>] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Edit, Glob, Grep, Bash, Write, Agent, TodoWrite
---

# /audit-devkit-fix: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Auto-fix verified findings với per-fix verification loop — mỗi fix được verify ngay lập tức |
| **Prerequisites** | `/audit-devkit-verify` đã hoàn thành — `audit-verified-result.json` tồn tại + `verify-status.json.status = "completed"` |
| **Duration** | Multi-session (nhiều fixes, re-scan) |
| **Phases** | 4 phases (0-3) |
| **Input** | `.mc-data/work/audit-devkit-verify/[session-id]/audit-verified-result.json`, `.mc-data/work/audit-devkit-scan/[session-id]/audit-index.json` |
| **Output** | `.mc-data/work/audit-devkit-fix/[session-id]/fix-log.json`, `fix-status.json`, `phase-summary.md`, `reports/devkit-audit-fix-[date].md` |

### Workflow Position

```
/audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix
                                                    |
                                               YOU ARE HERE
```

### Terminology Mapping (Procedure Files ↔ SKILL.md Sections)

| Procedure file | SKILL.md section | Vai trò |
|----------------|------------------|---------|
| `_shared.md` | Protocols & Strategy | Fix Rules, Auto-Fix Limits, FP Recognition, Error codes |
| `fix-patterns.md` | Fix Patterns reference | FP1-FP9 chi tiết (load on-demand) |
| `phase0-load.md` | §Phase 0 Load Verified Findings | Parse args, filter AUTO, sort, init fix-status.json |
| `phase1-fix-loop.md` | §Phase 1 Per-Fix Verification | Read → Edit → Verify → Pass/Revert loop |
| `phase2-rescan.md` | §Phase 2 Post-Fix Re-scan | Spawn auditors cho changed files, regression detection |
| `phase3-report.md` | §Phase 3 Final Report | fix-log.json, report, phase-summary.md |

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--dry-run` | Chạy toàn bộ pipeline nhưng KHÔNG thực sự Edit — chỉ log fix proposals | - |
| `--severity=CRITICAL` | Chỉ fix findings có severity=CRITICAL | - |
| `--severity=MAJOR` | Fix CRITICAL + MAJOR (ADDITIVE) | - |
| `--severity=ALL` | Fix tất cả AUTO findings (CRITICAL + MAJOR + MINOR) | `--severity=ALL` (mặc định) |

> **Lưu ý:** Filter là ADDITIVE. KHÔNG có `--severity=MINOR` (chỉ fix MINOR — không hỗ trợ vì không hợp lý). Muốn fix bao gồm MINOR → dùng `--severity=ALL`.

| Argument | Description | Default |
|----------|-------------|---------|
| `--session=<id>` | **[v1.4 — C3 fix 2026-05-10]** Pin session-id (timestamp dir như `20260510-130000`) từ orchestrator để khớp `audit-devkit-verify` session. Khi gọi standalone (không truyền) → fallback Glob latest verify session. Khi gọi từ `/audit-devkit` orchestrator → BẮT BUỘC nhận flag này để chống race condition giữa nhiều historical sessions | - (fallback latest) |
| `--resume` | Resume từ checkpoint | - |

---

## PRE-GATE (Entry)

```
1. IF --resume:
   - Scan `.mc-data/work/audit-devkit-fix/*/fix-status.json` tìm session có `status: "in_progress"`
   - Set $SESSION_DIR = `.mc-data/work/audit-devkit-fix/[found-session-id]/`
   - Validate: JSON valid, `phases.phase3-report.status != "completed"`
   - Jump Phase tương ứng `current_phase` — KHÔNG init lại
2. ELSE (fresh run):
   - Validate: `.mc-data/work/audit-devkit-verify/[session]/audit-verified-result.json` tồn tại
   - Validate: `.mc-data/work/audit-devkit-scan/[session]/audit-index.json` tồn tại
   - Validate (E001b — warning): `verify-status.json.status == "completed"` (nếu không → WARNING + hỏi user confirm)
   - Proceed to Phase 0
```

**FAIL ứng xử:**
- `audit-verified-result.json` không tồn tại → E001: "Chưa có verified results. Chạy `/audit-devkit-verify` trước."
- `audit-index.json` không tồn tại → E002: "Chưa có scan index. Chạy `/audit-devkit-scan` trước."
- JSON invalid → E003: retry 3 lần, sau đó yêu cầu re-run verify
- verify-status.json báo `status: "in_progress"` → E001b: WARNING + hỏi confirm

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/` (DEVKIT-wide protocols).
> **Skill-specific protocols:** READ `procedures/_shared.md` khi cần section cụ thể:
> - Execution Strategy (Sequential/Parallel mode per phase)
> - Fix Rules (Error Handling table)
> - Auto-Fix Limits (BẮT BUỘC — được phép/không được phép)
> - False Positive Recognition (stale, description mismatch, already_fixed, out_of_scope)
> - Fix Pattern → Priority Lookup
> - Error Codes (E001-E014)
> - Context & Checkpoint (resume process)

### Execution Strategy (summary)

| Phase | Mode |
|-------|------|
| Phase 0 (load + sort) | **SEQUENTIAL** |
| Phase 1 (per-fix loop) | **SEQUENTIAL** — mỗi fix phải verify xong mới tiếp tục |
| Phase 2 (re-scan) | **PARALLEL** — agent-auditor + skill-auditor đồng thời |
| Phase 3 (report) | **SEQUENTIAL** |

---

## Execution Summary

| Step | Action | Output |
|------|--------|--------|
| PRE-GATE | Validate inputs (verified result + scan index + verify-status gate) | — |
| Phase 0 | Load verified findings, filter AUTO, sort priority | `fix-status.json`, `fix_queue[]` sorted |
| Phase 1 | Per-fix verification loop: Read → Edit → Verify → Pass/Revert | `fix-log.json` (populated), changed files |
| Phase 2 | Targeted re-scan changed files + regression detection (CHỈ khi có changed files) | `rescan_findings[]`, `regressions[]` |
| Phase 3 | Write final `fix-log.json`, audit report, phase summary | `fix-log.json`, `devkit-audit-fix-[date].md`, `phase-summary.md` |
| POST-GATE | `status: "completed"`, Execution Trace COMPLETE entry, phase-summary displayed | — |

---

## Phase 0: Load Verified Findings

> Chi tiết: READ `procedures/phase0-load.md` — parse arguments, verify-complete gate check, session-id discovery, filter AUTO findings, sort theo dependency order, init `fix-status.json`.

**PRE-GATE:** Entry PRE-GATE passed (inputs exist + verify-status gate).

**📤 OUTPUT:**
- `$SESSION_DIR/fix-status.json` (template: `templates/fix-status.template.json`)

| Step | Action | Verify |
|------|--------|--------|
| 0.1-0.1a | Parse arguments + verify-complete gate check | flags + gate confirmed |
| 0.1b-0.1c | Session-id discovery + Execution Trace START | session_id set, trace appended |
| 0.2-0.6 | Create work dir, read `audit-verified-result.json` + `audit-index.json` | content loaded, JSON valid |
| 0.7 | Nếu `--resume`: extract processed finding IDs | processed IDs extracted |
| 0.8-0.10a | Filter AUTO + severity + sort priority + FP Recognition pass | `fix_queue[]` cleaned |
| 0.11-0.12 | Log queue summary + init `fix-status.json` từ template | file created |

**POST-GATE:**
```
test -s $SESSION_DIR/fix-status.json \
  && jq -e '.phases."phase0-load".status == "completed"' fix-status.json \
  && fix_queue sorted (hoặc empty → skip Phase 1)
```

---

## Phase 1: Fix với Per-Fix Verification

> Chi tiết: READ `procedures/phase1-fix-loop.md` — per-fix loop với 3 ví dụ cụ thể (VD1 REFERENCE, VD2 Revert, VD3 FP4 ADDITIVE).
>
> **Load on-demand:** Khi finding match Fix Pattern (FP1-FP9) → READ section tương ứng trong `procedures/fix-patterns.md`.

**PRE-GATE:** Phase 0 POST-GATE pass — `fix_queue` sorted, non-empty.

**📤 OUTPUT:**
- `$SESSION_DIR/fix-log.json` (template: `templates/fix-log.template.json`) — populated dần qua loop
- Code files `.claude/**/*.md|.json|.sh` được sửa in-place theo giới hạn `_shared.md §Auto-Fix Limits`

**ĐIỂM THEN CHỐT:** Mỗi fix đi qua `Read → Edit → IMMEDIATELY Verify → Log`. Verify FAIL → Revert + MANUAL. **KHÔNG BAO GIỜ** bỏ qua verify.

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | Init `fix-log` từ template | structure valid |
| 1.2-1.3 | FOR EACH finding: Read file → save `original_content` | content captured |
| 1.4-1.6 | Check `old_value` exists + dry-run handling | per branch |
| 1.7 | Edit theo `fix_proposal` (match FP → load `fix-patterns.md` §FPn nếu cần) | edit applied |
| 1.8-1.11 | Verify 3a-3d (old_value=0 nếu REPLACEMENT, new_value≥1, cross-ref check) | all checks per edit_type |
| 1.12-1.17 | PASS → log `FIXED_VERIFIED`; FAIL → Revert → `REVERTED` + MANUAL | status logged |
| 1.19 | Checkpoint mỗi 10 fixes hoặc context > 65% | fix-status updated |

**POST-GATE:** Tất cả findings processed; `fix_log[]` populated; `total = fixed + reverted + skipped + dry_run`.

---

## Phase 2: Post-Fix Targeted Re-scan

> Chi tiết: READ `procedures/phase2-rescan.md` — chỉ re-scan files đã sửa (`FIXED_VERIFIED`), phân loại theo component type, spawn agent-auditor + skill-auditor song song, regression detection.

**PRE-GATE:** Phase 1 POST-GATE pass.

**Action:**
- **IF `changed_files == 0`** (all skipped/reverted/dry-run): SKIP Phase 2 → jump Phase 3.
- **ELSE:**
  - Phân loại `changed_files` → `agent_files[]` / `skill_files[]` / `other_files[]`
  - Spawn `agent-auditor` + `skill-auditor` ĐỒNG THỜI cho các batch non-empty
  - So sánh `rescan_findings` vs pre-fix findings → detect regressions (finding MỚI xuất hiện)
  - Log regressions (KHÔNG revert — chỉ WARNING E012)

**POST-GATE:**
- Re-scan complete cho tất cả changed files (hoặc Phase 2 skipped)
- `fix_log.regressions[]` populated nếu có
- `fix-status.json`: `phase2-rescan.status = "completed"` + `regressions_found` count

---

## Phase 3: Final Report

> Chi tiết: READ `procedures/phase3-report.md` — compute summary + post-fix verdict, write `fix-log.json`, tạo report + phase-summary, ghi Execution Trace COMPLETE.

**PRE-GATE:** Phase 2 POST-GATE pass (hoặc Phase 2 skipped).

**📤 OUTPUT:**
- `$SESSION_DIR/fix-log.json` (final, schema `fix-log-v1`)
- `.mc-data/work/audit-devkit-fix/reports/devkit-audit-fix-[date].md` (MỚI — KHÔNG edit verify report)
- `$SESSION_DIR/phase-summary.md` (Protocol §14, tiếng Việt ≤15 dòng)
- `$SESSION_DIR/fix-status.json` updated: `status = "completed"`

**Verdict Matrix (CRITICAL-functional only):**

| Điều kiện | Verdict |
|-----------|---------|
| Total = 0 | CLEAN |
| CRITICAL-functional = 0, MAJOR ≤ 5 | ACCEPTABLE |
| CRITICAL-functional = 0, MAJOR > 5 | NEEDS ATTENTION |
| CRITICAL-functional 1-3 | NEEDS ATTENTION |
| CRITICAL-functional > 3 | BROKEN |

> CRITICAL-structural KHÔNG ảnh hưởng verdict — liệt kê riêng trong report. Xem `procedures/_shared.md §Verdict Computation`.

**POST-GATE:**
- `fix-log.json` JSON valid, schema `fix-log-v1`, `summary.attempted = length(fixes[])`
- `summary.fixed_verified + reverted + skipped + dry_run = summary.attempted`
- Report + phase-summary tồn tại
- Execution Trace COMPLETE entry appended
- `fix-status.json.status = "completed"`

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/audit-devkit-verify` | Prerequisite — output `audit-verified-result.json` làm input |
| `/audit-devkit-scan` | Upstream — scan results là foundation cho verify + fix pipeline |
| `/audit-devkit` | Parent orchestrator — gọi skill này như bước 3 trong pipeline |
| `/audit-agents` | Alternative — chỉ audit agent definitions (nhẹ hơn, không fix) |

---

## Resume & Checkpoint

> Chi tiết: READ `procedures/_shared.md §Context & Checkpoint`.

**Quick Reference:**

| Trigger (count-based) | Action |
|----------------------|--------|
| Mỗi 10 fixes processed | Checkpoint — update `fix-status.json` + flush partial `fix-log.json` |
| Mỗi phase hoàn thành | Update `fix-status.json` phase status + timestamps |
| FORCE STOP (khi không thể tiếp tục) | Checkpoint ngay — ghi `last_processed_finding` để resume |

**Resume Flow:**
1. `--resume` → Glob `fix-status.json` có `status: "in_progress"`
2. READ existing `fix-log.json` + extract processed finding IDs
3. Filter `fix_queue` bỏ processed IDs → continue từ finding tiếp theo
4. Jump đúng phase theo `current_phase`

---

## Output Files

| File | Path | Phase |
|------|------|-------|
| fix-status.json | `$SESSION_DIR` (`.mc-data/work/audit-devkit-fix/[session-id]/`) | 0 (init), updates |
| fix-log.json (schema fix-log-v1) | `$SESSION_DIR` | 1 (populate), 3 (final) |
| devkit-audit-fix-[date].md | `.mc-data/work/audit-devkit-fix/reports/` | 3 |
| phase-summary.md (Protocol §14, ≤15 dòng) | `$SESSION_DIR` | 3 |
| Code files `.claude/**` | sửa in-place theo `_shared.md §Auto-Fix Limits` | 1 |

> **Next:** fix xong → re-run `/audit-devkit-verify --session=<id>` hoặc `/audit-devkit --no-fix` để xác nhận verdict, rồi về orchestrator `/audit-devkit`.

---

## Error Handling

Codes E001-E014 — chi tiết đầy đủ: READ `procedures/_shared.md §Error Codes`.

| Code | Khái quát |
|------|-----------|
| E001 / E002 | PRE-GATE fail (input files missing) — STOP |
| E001b | verify-complete gate (status != completed) — WARNING + confirm |
| E003 | JSON invalid — retry 3 lần |
| E004 / E014 | Revert fail — CRITICAL STOP, log chi tiết |
| E005 | File locked — retry 3 lần, sau đó SKIP |
| E006 | Edit conflict — re-read, recalculate. Fail → MANUAL |
| E007 / E008 | Agent timeout / bad output — re-spawn 1 lần |
| E009 | fix-log.json write fail — retry 3 lần |
| E010 | Verify report missing — tạo report mới không cần context |
| E011 | Resume: fix-status corrupt — rebuild |
| E012 | Regression detected — WARNING, không revert |
| E013 | Grep timeout — subdirectory fallback |
