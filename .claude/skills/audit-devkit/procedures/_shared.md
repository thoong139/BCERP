# Shared Protocols — audit-devkit (orchestrator)

> Cross-cutting protocols, state variables, argument mapping tables, và verdict logic
> được dùng bởi nhiều Phase trong audit-devkit orchestrator.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần (Table of Contents phía dưới).

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Argument Mapping Tables](#argument-mapping-tables)
- [Sub-Skill Invocation Model](#sub-skill-invocation-model)
- [Verdict Computation (3 verdicts)](#verdict-computation)
- [Error Handling Reference](#error-handling-reference)
- [Session-ID Discovery Protocol](#session-id-discovery-protocol)

---

## State Variables Glossary

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$PIPELINE_MODE` | Phase 0 | 0, 1, 2, 3, 3.5, 3.6, 4 | `full` / `no-fix` / `scan-only` / `quick` / `fix-only` / `master-plan` |
| `$STAGES[]` | Phase 0 | 0, 1-4 | Danh sách stages cần chạy. VD: `[scan, verify, fix, master-plan]` |
| `$SCOPE` | Phase 0 | 1 | `all` / `agents` / `skills` / `templates` / `focused-skill` |
| `$FOCUSED_SKILL` | Phase 0 | 1, 2 | Tên skill khi `--skill=<name>`. NULL nếu khác |
| `$FIX_MODE` | Phase 0 | 3 | `ON` / `OFF` |
| `$SCAN_ARGS` | Phase 0 | 1 | Arguments pass sang `/audit-devkit-scan` (VD: `--all`, `--agents`, `--skill=<name> --since=HEAD~5`) |
| `$VERIFY_ARGS` | Phase 0 | 2 | Arguments pass sang `/audit-devkit-verify` (mặc định `--all` hoặc `--skill=<name>` khi focused) |
| `$FIX_SEVERITY` | Phase 0 | 3 | `ALL` / `CRITICAL` / `MAJOR`. Mặc định `ALL`. Lưu ý: filter là ADDITIVE — `MAJOR` = CRITICAL+MAJOR; `ALL` = tất cả AUTO findings (gồm MINOR). KHÔNG có `MINOR-only` mode (fix không hỗ trợ). |
| `$EVAL_MODE` | Phase 0 | 3.6 | `ON` / `OFF` |
| `$EVAL_HARNESS_MODE` | Phase 0 | 3.6 | `stub` / `judge` / `auto` / `real`. Mặc định `stub` |
| `$EVAL_SKILL_FILTER` | Phase 0 | 3.6 | Tên skill khi `--eval-skill=<name>`. NULL khi `--all` |
| `$SESSION_ID` | Phase 1 | 2, 3, 3.6, 4 | Timestamp directory của scan output (VD: `20260419-100000`) |
| `$SCAN_SUMMARY` | Phase 1 | 4 | Counts từ scan: `{total, critical, major, minor}` |
| `$VERIFY_VERDICT_PRE_FIX` | Phase 2 | 4 | Verdict từ verify phase |
| `$FIX_SUMMARY` | Phase 3 | 4 | Counts: `{attempted, fixed, reverted, skipped}` |
| `$VERIFY_VERDICT_POST_FIX` | Phase 3 | 4 | Verdict sau fix (chỉ khi FIX_MODE=ON) |
| `$MASTER_PLAN_STATUS` | Phase 3.5 | 4 | Object chứa 8 component statuses + schema_sync + gate_reports + verdict |
| `$EVAL_STATUS` | Phase 3.6 | 4 | `{verdict, total_cases, pass, fail, skip, error, mode}` |

---

## Cross-Phase Data Flow

```
Phase 0 (parse-args)   → $PIPELINE_MODE, $STAGES[], $SCOPE, $FIX_MODE, $EVAL_MODE
                          $SCAN_ARGS, $VERIFY_ARGS, $FIX_SEVERITY
Phase 1 (scan)         → Delegate /audit-devkit-scan → $SESSION_ID, $SCAN_SUMMARY
Phase 2 (verify)       → Delegate /audit-devkit-verify → $VERIFY_VERDICT_PRE_FIX
Phase 3 (fix)          → Delegate /audit-devkit-fix → $FIX_SUMMARY, $VERIFY_VERDICT_POST_FIX
Phase 3.5 (masterplan) → Bash + Grep checks → $MASTER_PLAN_STATUS
Phase 3.6 (evals)      → run-skill-evals.sh → $EVAL_STATUS
Phase 4 (summary)      → Aggregate all → Output markdown summary to user
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước.

---

## Argument Mapping Tables

### Pipeline mode → stages

| Argument | stages[] | fix_mode |
|----------|----------|----------|
| *(none)* / `--full` | `[scan, verify, fix, master-plan]` | ON |
| `--no-fix` | `[scan, verify, master-plan]` | OFF |
| `--scan-only` | `[scan]` | OFF |
| `--quick` | `[scan]` (scan_args += "--agents --skills", structural only) | OFF |
| `--fix-only` | `[fix]` (skip scan+verify+master-plan) | ON |
| `--master-plan` | `[master-plan]` | OFF |
| `--evals` | +`evals` stage (chạy sau 3/3.5) | — |

### Scope → scan_args

| Scope flag | scan_args | verify_args |
|------------|-----------|-------------|
| *(none)* / `--agents`+`--skills`+`--templates` tất cả hoặc không có | `--all` | `--all` |
| `--agents` | `--agents` | `--agents` |
| `--skills` | `--skills` | `--skills` |
| `--templates` | `--templates` | `--templates` |
| `--skill=<name>` | `--skill=<name>` (+ focused, duration 3-8 min) | `--skill=<name>` |
| `--since=<commit>` | append ` --since=<commit>` | luôn `--all` (cross-component cần toàn bộ data) |

---

## Sub-Skill Invocation Model

Orchestrator gọi 3 sub-skills tuần tự (SEQUENTIAL) qua **Skill tool**. Không parallel.

```
# Phase 1: Scan
Skill tool: { skill: "audit-devkit-scan", args: "<$SCAN_ARGS>" }
# → Sau khi xong, orchestrator Glob latest session-id → set $SESSION_ID

# Phase 2: Verify (PIN session)
Skill tool: { skill: "audit-devkit-verify", args: "<$VERIFY_ARGS> --session=$SESSION_ID" }

# Phase 3: Fix (PIN session)
Skill tool: { skill: "audit-devkit-fix", args: "--severity=<$FIX_SEVERITY> --session=$SESSION_ID" }
```

**Rules:**
- Verify POST-GATE check sau mỗi lần gọi: output file tồn tại + JSON valid
- Sub-skill fail → STOP pipeline (trừ Phase 3 — WARNING + nhảy Phase 4 với partial data)
- `--skill=<name>` pass-through cả scan + verify. Verify dùng focused mode
- `--since=<commit>` CHỈ pass sang scan (verify cần `--all`)
- **Session pinning (BẮT BUỘC từ C3 fix 2026-05-10):** Verify + Fix luôn nhận `--session=$SESSION_ID` từ orchestrator. Nếu không truyền, sub-skill fallback Glob latest (backward compat khi gọi standalone) — nhưng trong pipeline context có thể pick nhầm session khác → silent corrupt verdict. Orchestrator KHÔNG được skip flag này.

### Sub-Skill Output Discovery (V7 — Intentional Design)

Orchestrator sử dụng **Glob-based discovery** để tìm output từ sub-skills thay vì structured return.

**Lý do thiết kế:**
- Skill tool không trả structured output — chỉ execute và trả text
- Output files được write bởi sub-skill vào session directory theo convention
- Glob pattern `*/audit-scan-result.json` là cơ chế discovery đáng tin cậy nhất
- Pattern này match với convention `YYYYMMDD-HHMMSS` directory name

**Discovery protocol:**
```
1. Gọi Skill tool với sub-skill name + args
2. Sau khi Skill xong → Glob pattern để discover session-id
3. Read output file → parse JSON → extract data
4. Nếu file không tồn tại → STOP E004
```

**Invariant:** Mỗi sub-skill PHẢI tạo output file tại convention path. Orchestrator KHÔNG assume success — luôn verify output tồn tại.

---

## Verdict Computation

Orchestrator tính **3 verdicts độc lập**:

### 1. Audit Verdict

Tính từ findings **SAU** auto-fix (Phase 3). Nếu `--no-fix`, tính từ pre-fix counts (Phase 2).

Mỗi finding có 2 dimensions: severity (CRITICAL/MAJOR/MINOR) + category (functional/structural).

| Điều kiện | Verdict |
|-----------|---------|
| Total = 0 | `CLEAN` |
| CRITICAL-functional = 0, MAJOR ≤ 5 | `ACCEPTABLE` |
| CRITICAL-functional = 0, MAJOR > 5 | `NEEDS ATTENTION` |
| CRITICAL-functional 1-3 | `NEEDS ATTENTION` — fix trước khi dùng |
| CRITICAL-functional > 3 | `BROKEN` — không dùng cho dự án mới cho đến khi fix |

**Lưu ý:** CRITICAL-structural KHÔNG ảnh hưởng verdict. Liệt kê riêng trong section "Structural Issues".

**STRICT RULE:** Verdict PHẢI tuân theo bảng CHÍNH XÁC dựa trên số CRITICAL-functional. KHÔNG exercise judgment.

### 2. Master Plan Verdict

Tính từ `$MASTER_PLAN_STATUS` sau Phase 3.5:

| Điều kiện | Verdict |
|-----------|---------|
| Tất cả 8 components OK + schema 15/15 pass | `MP-CLEAN` |
| ≥6 components OK, 0 BROKEN | `MP-ACCEPTABLE` |
| Bất kỳ BROKEN | `MP-NEEDS-ATTENTION` |
| ≥3 MISSING | `MP-INCOMPLETE` |

### 3. Eval Verdict (chỉ khi `--evals`)

Tính từ `$EVAL_STATUS` sau Phase 3.6:

| Điều kiện | Verdict |
|-----------|---------|
| fail=0, skip=0 | `EVAL-CLEAN` |
| fail=0, skip>0 | `EVAL-PARTIAL` |
| fail 1-5 | `EVAL-NEEDS-REVIEW` |
| fail>5 | `EVAL-NEEDS-FIX` |

---

## Error Handling Reference

> **Error code prefix:** ORCH- (VD: ORCH-E001, ORCH-E002). Dùng khi log/display để phân biệt với errors từ scan/verify/fix. Sub-skills dùng prefix riêng: SCAN-, VERIFY-, FIX-.

| Code | Situation | Action |
|------|-----------|--------|
| E001 | PRE-GATE fail: `.claude/agents/` hoặc `.claude/skills/` không tồn tại | STOP — không phải DEVKIT project |
| E002 | Argument không hợp lệ | Hỏi user → default `--full` |
| E003 | Sub-skill fail (scan/verify/fix) | Hiển thị error + stage name. STOP hoặc continue tùy stage |
| E004 | Output file không tồn tại sau sub-skill | STOP với hướng dẫn chạy sub-skill trực tiếp để debug |
| E005 | `--fix-only` nhưng thiếu prerequisite files (audit-verified-result.json) | STOP: "Chạy /audit-devkit-scan và /audit-devkit-verify trước" |
| E006 | JSON invalid từ sub-skill output | Retry read 1 lần, sau đó STOP |
| E007 | `E_AUDIT_SCAN_INCOMPLETE` — scan bị interrupt, findings thiếu batch | WARNING + CONTINUE: Hiển thị cảnh báo, tiếp tục verify/fix với available data |
| E008 | `E_AUDIT_REGISTRY_READ_FAIL` — không đọc được req-registry.json khi cross-validate | WARNING + SKIP: Log warning, skip cross-validation liên quan registry |
| E009 | Phase 3.5 script không tồn tại (VD: validate-schema-sync.sh) | WARNING: component = MISSING, tiếp tục |
| E010 | Phase 3.6 eval harness script fail hoặc output invalid | WARNING + skip eval verdict, tiếp tục Phase 4 |

---

## Session-ID Discovery Protocol

Orchestrator KHÔNG tự generate session-id — sub-skill `audit-devkit-scan` tạo session directory theo format `YYYYMMDD-HHMMSS`. Orchestrator discovery bằng:

```
Glob: .mc-data/work/audit-devkit-scan/*/audit-scan-result.json
Pick: latest timestamp directory (sort by filename/mtime desc)
Extract: $SESSION_ID từ directory name
```

**Invariant:** verify + fix sub-skills dùng CÙNG `$SESSION_ID` với scan để đảm bảo session consistency. Sub-skills tự discover cùng pattern, orchestrator chỉ cần track để hiển thị cho user.

---

## Orchestrator Persistent State (V3+V4 fix)

Orchestrator lưu state vào `.mc-data/work/audit-devkit/orchestrator-status.json` để survive context compression và support resume.

```jsonc
{
  "$schema": "orchestrator-status-v1",
  "session_id": null,                          // set after Phase 1 scan
  "pipeline_mode": "full",
  "stages": ["scan", "verify", "fix", "master-plan"],
  "scope": "all",
  "fix_mode": "ON",
  "eval_mode": "OFF",
  "started_at": "2026-04-23T10:00:00Z",
  "current_phase": "phase0-parse-args",
  "completed_phases": [],
  "state": {
    "scan_summary": null,                       // set after Phase 1
    "verdict_pre_fix": null,                    // set after Phase 2
    "verdict_post_fix": null,                   // set after Phase 3
    "fix_summary": null,                        // set after Phase 3
    "master_plan_status": null,                 // set after Phase 3.5
    "eval_status": null                         // set after Phase 3.6
  },
  "timestamps": {
    "phase0_completed": null,
    "phase1_completed": null,
    "phase2_completed": null,
    "phase3_completed": null,
    "phase3_5_completed": null,
    "phase3_6_completed": null,
    "phase4_completed": null
  }
}
```

**Quy tắc:**
- Phase 0: WRITE initial state sau khi parse args xong
- Mỗi phase: UPDATE `current_phase`, `completed_phases[]`, `state.*`, `timestamps.*`
- Khi resume: READ state → jump tới `current_phase` chưa completed
- Context compression giữa phases: READ state để khôi phục biến
