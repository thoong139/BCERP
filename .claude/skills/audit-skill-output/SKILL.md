---
name: audit-skill-output
version: 1.8.0
last_updated: 2026-04-23
description: |
  Kiểm tra chất lượng output của một workflow skill đã chạy — so sánh kết quả thực tế
  với thiết kế trong SKILL.md. Phát hiện lỗi, thiếu sót, sai schema, sai template.

  v1.8.0 — Bug fixes + improvements:
  - FIX: D8 detection dùng output path (không phải template path — template luôn tồn tại)
  - FIX: Verdict logic — structural CRITICAL luôn ưu tiên, kể cả khi D4+D5 fail
  - FIX: Auto-fix safety gate — KHÔNG sửa files trong .claude/ (chỉ flag + ESCALATE)
  - IMPROVE: _shared.md re-load trigger trong --all mode (context recovery)
  - IMPROVE: D6 POST-GATE extraction dùng grep-first (tránh context explosion)
  - IMPROVE: D3.7 partial count checks cho wf-design + wf-plan-modules
  - IMPROVE: D4 subagent prompt có scoring rubric chi tiết
  - IMPROVE: Templates tiếng Việt có dấu + D2 section dynamic (không hardcode)
  - IMPROVE: Evals updated v1.8.0 + 3 new eval cases (autofix, grep-first, partial checks)
  - DOCS: Cross-skill overlap documentation + integration notes

  TRIGGER khi:
  - User vừa chạy xong một /wf-* skill và muốn kiểm tra chất lượng
  - User nói: "kiểm tra kết quả", "audit output", "kiểm tra chất lượng phase"
  - User hỏi: "skill chạy đúng chưa", "output có đúng không", "review kết quả"
  - Giữa các phiên làm việc, user muốn đảm bảo output phase trước vẫn hợp lệ
  - Keywords: "audit output", "quality check", "kiểm tra output", "review phase"

  LUÔN trigger khi user cần kiểm chứng chất lượng output của bất kỳ workflow skill nào.

  KHÔNG trigger khi:
  - Kiểm tra cấu trúc DEVKIT → dùng /audit-devkit
  - Kiểm tra agent definitions → dùng /audit-agents
  - Kiểm tra REQ-ID traceability → dùng /wf-verify-sync
  - Kiểm tra toàn bộ project health → dùng /wf-preflight

argument-hint: "[skill-name | --all] [--no-fix] [--dimension=D1,D2,...] [--verbose] [--all --resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /audit-skill-output: $ARGUMENTS

## Overview

| Mục | Nội dung |
| --- | -------- |
| **Mục đích** | Kiểm tra chất lượng output của workflow skill — so sánh actual vs designed |
| **Prerequisites** | Ít nhất 1 workflow skill đã chạy xong (có output files) |
| **Duration** | Quick (1 skill) / Medium (--all) |
| **Phases** | 4 phases (Hybrid Delegation architecture) |
| **Input** | SKILL.md (thiết kế) + output files (thực tế) + registry |
| **Output** | `.mc-data/work/audit-skill-output/audit-report-[skill]-[date].md` |

### Workflow Position

```
/audit-devkit    → Kiểm tra BẢN THÂN DEVKIT (agents, skills, templates, rules)
/audit-agents    → Kiểm tra AGENT DEFINITIONS (compliance với spec)
/wf-preflight    → Kiểm tra PROJECT HEALTH (registry, docs, code, tests)
/wf-verify-sync  → Kiểm tra REQ-ID → CODE traceability

/audit-skill-output → Kiểm tra SKILL EXECUTION QUALITY
                       (output thực tế có đúng với thiết kế trong SKILL.md không?)
```

---

## Arguments

| Argument | Mô tả | Default |
| -------- | ----- | ------- |
| `skill-name` | Tên skill cần audit (vd: `wf-define-features`, `wf-design`) | — (bắt buộc nếu không có `--all`) |
| `--all` | Audit tất cả skills đã chạy (có output) | — |
| `--no-fix` | TẮT auto-fix — chỉ báo cáo, không sửa | — (mặc định: auto-fix BẬT) |
| `--dimension` | Chỉ audit các dimensions cụ thể: `D1,D3,D6,D8` | Tất cả (D1-D7, D8 nếu Master Plan enabled) |
| `--verbose` | Hiển thị chi tiết mỗi check (kể cả PASS) | Chỉ hiện WARN/FAIL |
| `--resume` | Tiếp tục từ checkpoint (chỉ dùng với `--all`) | — (chỉ khi `--all`) |

**Ví dụ sử dụng:**

```
/audit-skill-output wf-define-features                    # Audit + auto-fix (mặc định)
/audit-skill-output wf-design --no-fix                    # Chỉ báo cáo, không sửa
/audit-skill-output --all                                 # Audit tất cả skills + auto-fix
/audit-skill-output wf-define-features --dimension=D3,D6  # Chỉ registry + POST-GATE
/audit-skill-output --all --verbose                       # Full audit + fix + chi tiết
/audit-skill-output --all --resume                        # Tiếp tục --all từ checkpoint
```

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/`

- **Accuracy Assurance** (Protocol 1): POST-GATE sau mỗi phase
- **Auto-Correction Loop** (Protocol 2): MẶC ĐỊNH BẬT — auto-fix khi phát hiện lỗi, max 3 iterations. Tắt bằng `--no-fix`
- **Content Quality Gate** (Protocol 8): Dùng CQG dimensions cho D4

### Execution Strategy — Hybrid Delegation

> **Nguyên tắc thiết kế:** Accuracy > Work Quality > Time

```
Main Agent:  [Phase 0] → [Phase 1: Structural D1+D2+D3+D6+D7+D8] → [Phase 2: Auto-Fix]
                                                                           ↓
Subagent D4:                                                     [Content Quality ────]
                                                                                        → [Phase 4: Report]
Subagent D5:                                                     [Cross-Phase ────────]
                                                                  ↑ SONG SONG, fresh ctx ↑
```

| Nhóm | Dimensions | Agent | Lý do |
| ---- | ---------- | ----- | ----- |
| **Structural** | D1, D2, D3, D6, D7, D8 | Main agent (trực tiếp) | Tool-based (`glob`, `jq`, `test`, `grep`), context cost thấp |
| **Semantic** | D4 | Subagent riêng | Phải Read nhiều docs, cần fresh context phân tích nội dung |
| **Cross-Phase** | D5 | Subagent riêng | So sánh 2 phases, data lớn, fresh context đảm bảo không bỏ sót |

**Tại sao Hybrid Delegation?**
1. **Accuracy**: D4/D5 có fresh context riêng → không bị ảnh hưởng bởi structural checks
2. **Work Quality**: Auto-fix structural TRƯỚC → D4/D5 audit trên state đã sửa → không báo false positives
3. **Time**: D4 + D5 chạy SONG SONG → tiết kiệm ~40% thời gian so với sequential
4. **Full Scan**: Subagent có đủ context → KHÔNG cần sampling (100% docs)

---

## Procedure Files

> **IMPORTANT:** SKILL.md này là orchestrator mỏng. Chi tiết thực thi nằm trong `procedures/`.
> Đọc procedure file khi vào phase tương ứng — KHÔNG đọc tất cả procedures từ đầu.

| File | Nội dung | Load khi |
| ---- | -------- | -------- |
| `procedures/_shared.md` | 8 Audit Dimensions chi tiết, Skill Lookup Table, Registry Schemas per skill, Error codes, Verdict logic, Fix Rules | **Phase 0** (load 1 lần, reference cho các phase sau) |
| `procedures/phase0-scope.md` | Scope detection, `--resume` early exit, SKILL.md parsing, D8 detection, status init | Phase 0 |
| `procedures/phase1-structural.md` | D1+D2+D3+D6+D7+D8 checks (main agent, tool-based) | Phase 1 |
| `procedures/phase2-autofix.md` | Auto-fix structural issues (D1/D2/D3/D7), max 3 iterations | Phase 2 (skip nếu `--no-fix`) |
| `procedures/phase3-semantic.md` | Spawn D4 + D5 subagents SONG SONG, collect results | Phase 3 |
| `procedures/phase4-report.md` | Merge findings, verdict, report generation, status finalize | Phase 4 |

---

## Phases Overview

> Chi tiết Steps, PRE-GATE, POST-GATE của mỗi phase nằm trong `procedures/phaseN-*.md`.

| Phase | Procedure File | Mục đích | PRE-GATE | POST-GATE |
| ----- | -------------- | -------- | -------- | --------- |
| **Phase 0** | `procedures/phase0-scope.md` | Scope Detection & Context Loading | Có skill output | Target skills identified, SKILL.md specs loaded, registry loaded, `master_plan_enabled` detected, status file initialized |
| **Phase 1** | `procedures/phase1-structural.md` | Structural Audit (D1+D2+D3+D6+D7+D8) | Phase 0 completed | Structural findings collected |
| **Phase 2** | `procedures/phase2-autofix.md` | Auto-Fix Structural Issues (D1/D2/D3/D7) | Phase 1 completed, findings có sẵn | Fixable issues resolved (hoặc SKIPPED nếu `--no-fix`) |
| **Phase 3** | `procedures/phase3-semantic.md` | Semantic Audit via Subagents (D4+D5 SONG SONG) | Phase 2 completed | D4 + D5 findings collected từ subagents |
| **Phase 4** | `procedures/phase4-report.md` | Collect Results, Verdict & Report | Phase 1-3 completed | Report file tồn tại, status finalized |

---

## Error Handling

> Full table 13 error codes (E001-E013) + Best-Effort Parsing Rules: xem `procedures/_shared.md §6 Error Handling`.

| Code | Situation | Action |
| ---- | --------- | ------ |
| E001 | Skill chưa chạy (không có output) | STOP — "Skill [name] chưa có output" |
| E002 | SKILL.md không tìm thấy | STOP |
| E003 | Registry không tồn tại | STOP — chạy `/wf-brainstorm` trước |
| E005 | SKILL.md không có POST-GATE | Kiểm tra procedures/, skip D6 nếu không có |
| E011 | Subagent D4/D5 timeout/fail | Retry x1, sau đó skip dimension + WARNING |
| E012 | Subagent trả về sai format | Best-Effort Parsing, flag WARN |
| E013 | User gọi self-audit `/audit-skill-output audit-skill-output` | STOP — dùng `/audit-devkit` thay vì |

---

## Execution Flow

```
START
  │
  ├─ Parse $ARGUMENTS → detect: single skill | --all | --resume | --no-fix | --dimension=
  │
  ├─ [Phase 0] READ procedures/phase0-scope.md + procedures/_shared.md → execute
  │    → **--all mode:** RE-READ procedures/_shared.md ở đầu mỗi skill (context recovery)
  │    → target skills identified, SKILL.md specs loaded, registry loaded
  │    → audit-skill-output-status.json initialized
  │    → master_plan_enabled detected
  │
  ├─ [Phase 1] READ procedures/phase1-structural.md → execute
  │    → D1+D2+D3+D6+D7+D8 findings collected
  │
  ├─ [Phase 2] IF --no-fix: SKIP
  │            ELSE: READ procedures/phase2-autofix.md → execute
  │    → auto-fix D1/D2/D3/D7 issues, max 3 iterations
  │
  ├─ [Phase 3] READ procedures/phase3-semantic.md → execute
  │    → spawn D4 + D5 subagents SONG SONG
  │    → collect d4_findings, d5_findings
  │
  ├─ [Phase 4] READ procedures/phase4-report.md → execute
  │    → merge all findings, dedupe, verdict
  │    → generate audit-report-[skill]-[date].md
  │    → finalize status, write phase-summary.md
  │    → display summary to user
  │
  └─ IF --all mode: loop back to [Phase 0] for next skill
     ELSE: END
```

---

## Output Files

| File | Mô tả |
|------|-------|
| `.mc-data/work/audit-skill-output/audit-report-[skill-name]-[YYYY-MM-DD].md` | Báo cáo audit chi tiết — findings, fix results, verdict |
| `.mc-data/work/audit-skill-output/audit-skill-output-status.json` | Trạng thái chạy: phase progress, verdict, timestamps |
| `.mc-data/work/audit-skill-output/checkpoint.json` | Checkpoint để resume khi đứt giữa chừng (--all mode) |
| `.mc-data/work/audit-skill-output/phase-summary.md` | Tóm tắt kết quả audit cho người không chuyên (CORE-028) |
| `.mc-data/work/_trace/session-log.json` | Execution trace entry (CORE-026) — append-only |
| Modified `.mc-data/` files | Các files trong `.mc-data/` được sửa khi auto-fix mode (registry, status, docs). Files trong `.claude/` KHÔNG BAO GIỜ được auto-fix — chỉ flag + ESCALATE |

---

## Related Skills

| Skill | Relation |
| ----- | -------- |
| `/audit-devkit` | Kiểm tra DEVKIT structure — `/audit-skill-output` kiểm tra EXECUTION quality |
| `/audit-agents` | Kiểm tra agent definitions — không liên quan trực tiếp |
| `/wf-preflight` | Kiểm tra project health (docs + code) — `/audit-skill-output` kiểm tra từng skill output |
| `/wf-verify-sync` | Kiểm tra REQ-ID traceability — D4.3 của skill này có overlap nhẹ |
| `/wf-fix-bugs` | Consumer — khi audit phát hiện FAIL, user có thể chạy /wf-fix-bugs |
| Bất kỳ `/wf-*` skill | Target — mọi workflow skill có thể là đối tượng audit |
| `skill-compliance-audit.sh` | Bash script kiểm tra SKILL.md structural compliance — complement với audit-skill-output |

### Cross-Skill Overlap & Integration Notes

**Overlap với `/wf-preflight`:**
- Cả hai kiểm tra registry validity (D3 ≈ preflight Phase 4), file existence (D1 ≈ preflight Phase 3)
- Khác biệt: preflight kiểm tra PROJECT health tổng thể, audit-skill-output kiểm tra specific SKILL OUTPUT quality
- Recommend: chạy audit-skill-output TRƯỚC cho từng skill, sau đó preflight cho overall project

**Integration với `/audit-devkit`:**
- `audit-devkit` kiểm tra DEVKIT infrastructure (agents, skills, templates, cross-refs)
- `audit-skill-output` kiểm tra execution output quality
- Hai skills độc lập, không share findings. Nếu cả hai phát hiện registry issues → ưu tiên fix theo audit-devkit findings (infrastructure-level)

**Integration với `skill-compliance-audit.sh`:**
- Script kiểm tra SKILL.md structural compliance (12 sections, CRITICAL/REQUIRED/CONDITIONAL)
- `audit-skill-output` kiểm tra execution output quality (8 dimensions)
- Kết quả complement: script PASS + audit PASS → skill chất lượng cao

---

## Context & Checkpoint (--all mode)

| Context Usage | Hành động |
| ------------- | --------- |
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc |

### Checkpoint Creation

Khi context > 80%, lưu checkpoint TRƯỚC khi tiếp tục:

1. Đọc `templates/checkpoint.json` → populate các fields:
   - `checkpoint_id`: `CP-AUDIT-[YYYYMMDD]-[NNN]`
   - `current_skill`, `current_phase`, `current_step`, `context_used_pct`
   - `all_mode_state.completed_skills`, `all_mode_state.remaining_skills`, `all_mode_state.findings_so_far`
   - `completed_work.phases_done`, `completed_work.dimensions_done`, `completed_work.fixes_applied`
   - `in_memory_state.*` (structural_findings_count, d4/d5 status, verdict_so_far)
   - `next_action`: mô tả rõ ràng việc cần làm tiếp theo
2. Write checkpoint tại `.mc-data/work/audit-skill-output/checkpoint.json`
3. Update status file: `checkpoint.id`, `checkpoint.timestamp`, `checkpoint.context_used_pct`, `checkpoint.current_phase`
4. Báo cáo người dùng: "Checkpoint lưu tại ... Resume bằng `/audit-skill-output [skill] --resume`"

### Resume Process

1. Đọc `audit-skill-output-status.json` → xác định mode, completed_skills, remaining
2. Đọc `checkpoint.json` → xác định `current_phase`, `next_action`
3. SKIP các phases/skills đã ghi trong `completed_work.phases_done` / `all_mode_state.completed_skills`
4. TIẾP TỤC từ `next_action` trong checkpoint, update `checkpoint.resumed_from = checkpoint_id`
5. READ procedure file tương ứng với `current_phase` → execute tiếp

### Status File Schema

> Schema đầy đủ: `.claude/skills/audit-skill-output/templates/audit-status.json`

**Fields quan trọng:**

| Field | Mô tả |
|-------|-------|
| `status` | `not_started \| in_progress \| completed \| error \| paused` |
| `mode` | `single` (1 skill) hoặc `--all` |
| `target.current_skill` | Skill đang audit |
| `target.completed_skills[]` | Danh sách skill đã hoàn thành (dùng cho --resume) |
| `target.remaining_skills[]` | Còn lại (--all mode) |
| `findings.by_severity` | Summary CRITICAL/MAJOR/MINOR/INFO (sau fix) |
| `findings.by_dimension` | Pass/warn/fail per D1-D7 (+ D8 nếu enabled) |
| `findings.auto_fixed` | Số issues đã auto-fix |
| `phases.phase_N.status` | Trạng thái từng phase |
| `checkpoint.current_phase` | Dùng cho resume |
| `reports[]` | Danh sách report files đã tạo |

---

## Examples

```
Example 1: Audit 1 skill (Hybrid Delegation)
/audit-skill-output wf-define-features

Phase 0: Load SKILL.md + registry → 57 features, 8 systems
Phase 1 (Main): D1 (7 PASS, 1 FAIL) + D2 (3 PASS, 1 WARN) + D3 (3 FAIL) + D6 (2 FAIL) + D7 (1 WARN)
Phase 2 (Auto-Fix): D3 fixed (field names, dependencies, phase type) → re-check PASS
Phase 3 (Subagents):
  → D4 agent: full scan 57 feature specs → score 72/100, 2 WARN
  → D5 agent: Phase 1 vs Phase 2 → 1 WARN (9 REQ-IDs need verification)
  (D4 + D5 chạy SONG SONG — fresh context, 100% docs)
Phase 4: Merge → Verdict PASS_WITH_WARN (0 CRITICAL sau fix, 3 MAJOR)
Output: .mc-data/work/audit-skill-output/audit-report-wf-define-features-2026-04-19.md
```

```
Example 2: Audit với --no-fix
/audit-skill-output wf-define-features --no-fix

Phase 0-1: [same as above]
Phase 2: SKIP (--no-fix)
Phase 3: D4 + D5 agents audit trên state CHƯA fix
Phase 4: Verdict FAIL — 6 CRITICAL (D3 chưa fix), 3 MAJOR, 2 MINOR
```

```
Example 3: Audit all skills
/audit-skill-output --all

Detected 3 skills: wf-brainstorm, wf-analyze-requirements, wf-define-features
[mỗi skill chạy Phase 0-4 đầy đủ, bao gồm subagent delegation]
Combined report: 2 PASS, 1 PASS_WITH_WARN (wf-define-features)
```
