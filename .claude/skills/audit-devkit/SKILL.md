---
name: audit-devkit
version: 5.2.0
last_updated: 2026-09-12
description: |
  Orchestrator MCV3 self-audit pipeline: scan → verify → fix tuần tự + Master Plan
  validation (Hook 2-Tầng, Digest Pipeline, A6/A7-EXT, Parallel Execution) + optional
  Skill Eval Harness (--evals, Phase 3.6). Entry point duy nhất cho audit toàn diện;
  gọi /audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix.
  History: v5.2 compliance headings; v5.1 quality fixes; v5.0 tách 7 procedures + _shared (lazy load).

  TRIGGER khi:
  - Cần audit toàn bộ MCV3 toolkit trước release version mới
  - Thêm/sửa/xóa agent, skill, template, rule, hook bất kỳ
  - Phát hiện inconsistency giữa các components; kiểm tra Master Plan components status
  - Keywords: "audit devkit", "audit MCV3", "kiểm tra MCV3", "review DEVKIT", "master plan status"

  KHÔNG trigger khi:
  - Audit dự án đang dùng MCV3 → xem docs/audit/devkit-existing-project-audit.md
  - Chỉ audit agents → /audit-agents; chỉ scan → /audit-devkit-scan; chỉ fix → /audit-devkit-fix

argument-hint: "[--full | --no-fix | --scan-only | --quick | --fix-only | --master-plan] [--agents | --skills | --templates | --rules | --hooks | --skill=<name>] [--since=<commit>] [--evals [--eval-mode=stub|judge|auto|real] [--eval-skill=<name>]]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Agent, TodoWrite, Skill
---

# /audit-devkit: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | MCV3 self-audit orchestrator — điều phối pipeline scan → verify → fix → master plan validation |
| **Phạm vi** | Agents, Skills, Templates, Rules, Hooks, Cross-References, Workflow, Master Plan Components |
| **Quy trình** | Parse args → /audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix → Master Plan → (optional Evals) → Summary |
| **Duration** | 15-40 min (full), 2-5 min (--master-plan), 3-8 min (--skill=<name>) |
| **Output** | `.mc-data/work/audit-devkit-{scan,verify,fix}/[session]/*.json` + reports (xem `procedures/phase4-summary.md §Output Files`) |
| **Entry point** | Duy nhất cho MCV3 self-audit đầy đủ |

### Workflow Position

```
[Thêm/sửa agent, skill, template, rule, hook] → /audit-devkit  ← YOU ARE HERE
                                                      │
                                                      ▼
                              /audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix
                                                      │
                                                      ▼
                                          Master Plan validation → Summary (→ release)
```

> Standalone self-audit lane của DEVKIT — KHÔNG thuộc main pipeline; chạy trước mỗi release MCV3.

### Prerequisites

- `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/rules/` tồn tại (PRE-GATE E001 — không phải DEVKIT project nếu thiếu).
- `--fix-only` yêu cầu scan + verify đã chạy trong session gần nhất (E005).

### Phân biệt với skill liên quan

| Skill | Khi dùng |
|-------|----------|
| `/audit-devkit` (đây) | Audit toàn diện end-to-end — scan + verify + fix |
| `/audit-devkit-scan` | Chỉ scan components, output findings JSON |
| `/audit-devkit-verify` | Chỉ cross-validate (cần scan results trước) |
| `/audit-devkit-fix` | Chỉ auto-fix (cần verified results trước) |
| `/audit-agents` | Chỉ audit agent definitions (nhẹ, không cross-validate) |

---

## Arguments

| Argument | Pipeline stages | Mô tả |
|----------|-----------------|-------|
| `--full` (mặc định) | scan → verify → fix → master-plan | Toàn bộ pipeline, auto-fix ON |
| `--no-fix` | scan → verify → master-plan | Audit + report, KHÔNG auto-fix |
| `--scan-only` | scan | Chỉ scan components |
| `--quick` | scan (structural only) | Scan nhanh — agents + skills, không deep content |
| `--fix-only` | fix | Chỉ fix (cần scan + verify đã chạy) |
| `--master-plan` | master-plan-validation | Chỉ Master Plan validation (2-5 min) |
| `--evals` | +Phase 3.6 | Kích hoạt Skill Eval Harness (opt-in) |
| `--eval-mode=<mode>` | Phase 3.6 | `stub` (default) / `judge` / `auto` / `real` |
| `--eval-skill=<name>` | Phase 3.6 | Chỉ chạy eval cho 1 skill cụ thể |
| `--since=<commit>` | scan | Delta scan — chỉ files thay đổi từ commit |

### Scope arguments (kết hợp với pipeline mode)

| Argument | Scope | Truyền sang sub-skill |
|----------|-------|----------------------|
| `--agents` | Chỉ agents | `/audit-devkit-scan --agents` |
| `--skills` | Chỉ skills | `/audit-devkit-scan --skills` |
| `--templates` | Chỉ templates | `/audit-devkit-scan --templates` |
| `--rules` | Chỉ rules | `/audit-devkit-scan --rules` (verify fallback `--all`) |
| `--hooks` | Chỉ hooks | `/audit-devkit-scan --hooks` (verify fallback `--all`) |
| `--skill=<name>` | Chỉ 1 skill cụ thể | `/audit-devkit-scan --skill=<name>` (focused mode) |
| *(không có)* | Tất cả | `/audit-devkit-scan --all` |

> **Protocols:** Xem `.claude/skills/protocols/` — áp dụng §1 (POST-GATE), §10 (Schema), §10.4 (PRE-GATE), §14 (Phase Summary), §15 (Execution Trace), §19 (Template Usage).
>
> **Skill-internal shared:** `procedures/_shared.md` — State Variables, Argument Mapping, Sub-Skill Invocation Model, Verdict Computation, Error Handling, Session-ID Discovery.

---

## Phase 0: Parse Args (BẮT BUỘC — entry point)

> Chi tiết: `procedures/phase0-parse-args.md`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | Parse `$ARGUMENTS` → pipeline mode (`--full`/`--no-fix`/`--scan-only`/`--quick`/`--fix-only`/`--master-plan`) + scope args + `--evals`/`--since` | Arg hợp lệ; sai → E002 default `--full` |
| 2 | PRE-GATE: DEVKIT directories tồn tại | Thiếu → E001 STOP |
| 3 | `--fix-only` prerequisite validation (scan + verify session) | Thiếu → E005 STOP |
| 4 | Build `$STAGES[]` + `$SCAN_ARGS`/`$VERIFY_ARGS`/`$FIX_SEVERITY` → route Phase 1 | Routing flow khớp mode |

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua phase files.
> Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện chạy | Mục đích |
|-------|----------------|----------------|----------|
| **0** | `procedures/phase0-parse-args.md` | Luôn (entry point) | Parse `$ARGUMENTS`, xác định pipeline mode + scope + stages |
| **1** | `procedures/phase1-scan.md` | `scan` ∈ `$STAGES[]` | Delegate `/audit-devkit-scan`, discover session-id |
| **2** | `procedures/phase2-verify.md` | `verify` ∈ `$STAGES[]` | Delegate `/audit-devkit-verify`, đọc verdict_pre_fix |
| **3** | `procedures/phase3-fix.md` | `fix` ∈ `$STAGES[]` & `$FIX_MODE=ON` | Delegate `/audit-devkit-fix`, đọc verdict_post_fix |
| **3.5** | `procedures/phase3-5-masterplan.md` | `master-plan` ∈ `$STAGES[]` | Master Plan 8 components + schema sync + gate reports + backward compat |
| **3.6** | `procedures/phase3-6-evals.md` | `evals` ∈ `$STAGES[]` (chỉ khi `--evals`) | Run eval harness, compute eval verdict |
| **4** | `procedures/phase4-summary.md` | Luôn (cuối pipeline) | Aggregate data, load templates, render summary markdown |

### Routing Flows theo Pipeline Mode

**`--full` (mặc định, full pipeline):**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 3.5 → Phase 4 → DONE
```

**`--no-fix`:**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3.5 → Phase 4 → DONE
```

**`--scan-only` / `--quick`:**
```
Phase 0 → Phase 1 → Phase 4 (scan summary only) → DONE
```

**`--fix-only`:**
```
Phase 0 (+ prerequisite validation) → Phase 3 → Phase 4 → DONE
```

**`--master-plan`:**
```
Phase 0 → Phase 3.5 → Phase 4 (master-plan summary only) → DONE
```

**With `--evals` (append to any above):**
```
... → Phase 3.6 → Phase 4 (+ evals section) → DONE
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns (arg mapping, verdict, errors).

---

## Sub-Skill Invocation Model (tóm tắt)

Orchestrator gọi 3 sub-skills **tuần tự** qua **Skill tool** với arguments từ `$SCAN_ARGS`, `$VERIFY_ARGS`, `$FIX_SEVERITY`:

```
Skill tool: { skill: "audit-devkit-scan",   args: "<$SCAN_ARGS>" }
Skill tool: { skill: "audit-devkit-verify", args: "<$VERIFY_ARGS>" }
Skill tool: { skill: "audit-devkit-fix",    args: "--severity=<$FIX_SEVERITY>" }
```

Chi tiết invocation rules: `procedures/_shared.md §Sub-Skill Invocation Model`.

---

## Verdicts (3 verdicts độc lập)

Orchestrator tính **3 verdicts** riêng biệt, KHÔNG merge:

| Verdict | Nguồn | Giá trị |
|---------|-------|---------|
| **Audit** | Phase 2/3 | `CLEAN` / `ACCEPTABLE` / `NEEDS ATTENTION` / `BROKEN` |
| **Master Plan** | Phase 3.5 | `MP-CLEAN` / `MP-ACCEPTABLE` / `MP-NEEDS-ATTENTION` / `MP-INCOMPLETE` |
| **Eval** (opt-in) | Phase 3.6 | `EVAL-CLEAN` / `EVAL-PARTIAL` / `EVAL-NEEDS-REVIEW` / `EVAL-NEEDS-FIX` |

Bảng tính chi tiết: `procedures/_shared.md §Verdict Computation`.

**STRICT RULE:** Audit verdict tuân theo bảng CHÍNH XÁC dựa trên số CRITICAL-functional. KHÔNG exercise judgment.

---

## Error Handling (top-level codes)

| Code | Tình huống | Action |
|------|------------|--------|
| E001 | PRE-GATE directories missing | STOP — không phải DEVKIT project |
| E002 | Argument không hợp lệ | WARNING + default `--full` |
| E003 | Sub-skill fail | Hiển thị error + stage name. STOP hoặc continue tùy stage |
| E004 | Output file không tồn tại sau sub-skill | STOP với hướng dẫn debug |
| E005 | `--fix-only` thiếu prerequisite | STOP — chạy scan+verify trước |
| E006 | JSON invalid | Retry 1 lần, sau đó STOP |
| E007 | Scan incomplete (partial batches) | WARNING + continue với available data |
| E008 | Registry read fail khi cross-validate | WARNING + skip cross-validation |
| E009 | Phase 3.5 script missing (schema-sync) | WARNING + component = MISSING |
| E010 | Phase 3.6 eval harness fail | WARNING + skip eval verdict |

Chi tiết: `procedures/_shared.md §Error Handling Reference`.

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Argument không hợp lệ (E002) | WARNING + fallback default `--full` | Không escalate |
| Sub-skill fail (E003) | Theo stage: scan/verify fail → STOP; fix fail → continue với available data | STOP stage → hiển thị error + stage name |
| Output file thiếu sau sub-skill (E004) | Kiểm tra lại session-id discovery ×1 | Vẫn thiếu → STOP với hướng dẫn debug |
| JSON invalid (E006) | Retry parse ×1 | Vẫn fail → STOP |
| Scan incomplete (E007) | WARNING + continue với available data | CRITICAL-functional findings bị mất → STOP |
| Registry read fail (E008) | WARNING + skip cross-validation | Không auto-fix thêm |
| Script missing Phase 3.5/3.6 (E009/E010) | WARNING + component MISSING / skip eval verdict | Không auto-fix thêm |

---

## Lưu ý quan trọng

1. **Orchestrator only** — Skill này KHÔNG tự scan, verify, hay fix. Delegate cho sub-skills + tự chạy Master Plan validation + optional evals
2. **Backward compatible** — `--agents`, `--skills`, `--templates`, `--master-plan`, `--skill=<name>`, `--since=<commit>` hoạt động như v4.x
3. **Mặc định = `--full`** — Không có argument = scan → verify → fix → master-plan (auto-fix ON)
4. **Output path per sub-skill** — Mỗi sub-skill output vào directory riêng: `.mc-data/work/audit-devkit-{scan,verify,fix}/[session_id]/`. Reports tại `.mc-data/work/audit-devkit-{verify,fix}/reports/`
5. **Resumable** — Mỗi sub-skill có checkpoint riêng. Nếu pipeline bị ngắt, user có thể chạy sub-skill tiếp theo trực tiếp
6. **Verdict strict** — 3 verdicts độc lập (Audit / Master Plan / Eval). Audit verdict chỉ dựa trên CRITICAL-functional
7. **Evals opt-in** — `--evals` flag KHÔNG mặc định. Phải chủ động truyền
8. **Focused mode** — `--skill=<name>` duration 3-8 min (giảm đáng kể so với 15-40 min full)
9. **Delta scan** — `--since=<commit>` chỉ scan files thay đổi. Hữu ích cho PR review

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/audit-devkit-scan` | Sub-skill 1 — scan components, build ground truth index |
| `/audit-devkit-verify` | Sub-skill 2 — cross-validate references, workflow integrity |
| `/audit-devkit-fix` | Sub-skill 3 — auto-fix với per-fix verification |
| `/audit-agents` | Alternative — chỉ audit agent definitions (nhẹ hơn) |
| `/audit-skill-output` | Khác mục đích — kiểm tra chất lượng output của skill |

> **Next:** audit xong → review summary + verdicts tại `.mc-data/work/audit-devkit-{verify,fix}/reports/`, fix findings còn lại thủ công nếu có, rồi release version MCV3 mới.
