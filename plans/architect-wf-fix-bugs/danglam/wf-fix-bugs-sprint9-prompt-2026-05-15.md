# Prompt: Thực hiện Sprint 9 — Procedure Logic + Cleanup (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 9 — Procedure Logic + Cleanup** của plan v10.3 dựa trên Sprint 8 closure 2026-05-15. Sprint 0-8 đã hoàn thành (Sprint 7: Python coverage 81.75%; Sprint 8: 8 F05 bash hardening findings; tổng 56+ commits trên master).

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project (đặc biệt CORE-026, CORE-027, CORE-028, CORE-038, BHV-002)
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-026 (Execution Trace), CORE-027 (CDG), CORE-038 (Context Budget)
4. **`plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md`** §"Sprint 8 Closed" + §"Sprint 8 — Procedure Logic + Cleanup" — danh sách 9 findings
5. **`plans/wf-fix-bugs-v10-3-audit/sprint-8-bash-hardening.md`** §"DONE" — confirm Sprint 8 closed
6. **`.claude/skills/workflow/wf-fix-bugs/SKILL.md`** — entry point (lean routing hub)
7. **`.claude/skills/workflow/wf-fix-bugs/procedures/_shared.md`** — cross-cutting (target F08.015)

**Quy tắc tuyệt đối:**

- ✅ **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ **BHV-002** (Simplicity First): F08.015 (DRY bug-dashboard) là CỐT LÕI sprint này — tránh duplication
- ✅ **BHV-003** (Surgical Changes): mỗi finding chỉ touch các dòng/sections liên quan
- ✅ **BHV-004** (Goal-Driven Execution): DONE = 9 findings áp dụng + audit-skill-output PASS + Python tests vẫn xanh
- ✅ Tiếng Việt cho commits/docs; English cho path/code names
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — pattern Sprint 6+7+8 (drift có thể tồn tại)
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG đổi semantic hành vi của procedure — chỉ refactor structure
- ❌ KHÔNG move templates/state files runtime — chỉ thay đổi DOCUMENTATION/PROCEDURE

## 1. MỤC TIÊU SPRINT 9

**Scope:** ~4h effort, 9 findings F08.* + F03.014 cho code organization, DRY, traceability completeness.

**Findings list (theo ưu tiên):**

| # | Finding | Mô tả | File chính | Effort |
|---|---------|-------|-----------|--------|
| 1 | **F08.015** | Centralize `bug-dashboard` logic → `_shared.md §dashboard-update` (đang duplicated 4 lần) | `procedures/_shared.md` + 4 phase files | 45min |
| 2 | **F08.018** | Tách Step 6.4 (178 dòng) → `6.4a Impact / 6.4b Risk / 6.4c CDG` | `procedures/phase6-report.md` | 30min |
| 3 | **F08.016** | Thêm `append cdg-tokens.json` explicit pattern cho 6 CDGs Phase 1 | `procedures/phase1-init.md` (or relevant) | 30min |
| 4 | **F08.020** | Rename Step 5.11b → 5.12 (shift 5.12-5.14 → 5.13-5.15) | `procedures/phase5-execute.md` + cross-refs | 20min |
| 5 | **F08.021** | Add TRACE FAIL explicit pattern Phase 7 (CORE-026 compliance) | `procedures/phase7-verify.md` | 20min |
| 6 | **F08.022** | Resume R5 handle partial outputs (MOVE partial → `partial-{timestamp}/`) | `procedures/resume-status.md` | 30min |
| 7 | **F08.030** | MOVE `path-audit-report.md` + `phase2-scan-audit-report.md` → `.mc-data/audit/` (DOC change, không runtime move) | SKILL.md output table + procedures | 15min |
| 8 | **F08.009** | Rename Phase 5 C1-C5 → PI1-PI5 (Process Integrity, tránh nhầm Critical) | `procedures/phase5-execute.md` + cross-refs | 30min |
| 9 | **F03.014** | Implement CORE-038 Phase 4 context budget checkpoint (replace stub) | `procedures/phase4-monitor.md` | 30min |

**Tổng estimate:** ~4h (1 sprint, single session feasible).

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. **Đọc Sprint 8 closure** trong audit + plan file
2. **VERIFY baseline (BHV-001):**
   - `bash run-tests.sh` PASS coverage 81.75% (Sprint 7+8 baseline preserved)
   - `ls .claude/skills/workflow/wf-fix-bugs/procedures/` → list procedure files
   - `wc -l .claude/skills/workflow/wf-fix-bugs/procedures/phase*.md` → check line counts
   - `grep -rn "bug-dashboard" .claude/skills/workflow/wf-fix-bugs/procedures/` → confirm F08.015 duplication
   - `grep -rn "C1\|C2\|C3\|C4\|C5" .claude/skills/workflow/wf-fix-bugs/procedures/phase5-execute.md | head` → confirm F08.009 references
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-9-procedure-cleanup.md`:
   - 9 findings + per-finding action + verification
   - Acceptance: skill audit PASS, test suite PASS, no behavioral diff
4. **TodoWrite:** 10-12 todos (1 verify baseline + 9 findings + 1 closure)

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** file hiện tại — locate vùng cần sửa
2. **VERIFY drift:** so sánh audit description với code thực tế
   - Nếu finding đã fix sẵn (false positive) → DOCUMENT only, KHÔNG action
   - Nếu finding chỉ partial → áp dụng phần còn thiếu
3. **APPLY fix surgical:**
   - **F08.015**: Tạo section `## §dashboard-update` trong `_shared.md` mô tả 1 lần. Trong 4 phase file, thay block dashboard logic → `> **Cross-ref:** Xem _shared.md §dashboard-update`
   - **F08.018**: Tách 1 step lớn → 3 step nhỏ với heading riêng (giữ nội dung, chỉ chia)
   - **F08.016**: Add đoạn pattern `bash` snippet cho `append cdg-tokens.json` mỗi lần CDG fire
   - **F08.020**: `sed` rename "Step 5.11b" → "Step 5.12", shift 5.12-5.14 → 5.13-5.15. **Verify cross-refs trong** SKILL.md, _contract.json, error codes nếu có
   - **F08.021**: Thêm `TRACE FAIL` block ở mỗi point có error trong Phase 7 (xem CORE-026 protocol)
   - **F08.022**: Trong resume-status.md R5, thêm logic `mv $partial_dir partial-$(date +%Y%m%dT%H%M%S)/`
   - **F08.030**: Update SKILL.md output table + procedure references về paths mới (`.mc-data/audit/`). KHÔNG move file runtime, chỉ doc
   - **F08.009**: Replace `C1`...`C5` → `PI1`...`PI5` trong phase5-execute + audit error code references
   - **F03.014**: Replace stub trong phase4-monitor với implementation thật của CORE-038 (check context %, save state, hint --resume)
4. **VERIFY no breaking change:**
   - Cross-ref consistency: nếu rename step → check SKILL.md routing table
   - Run `bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs 2>&1 | tail`
   - Skim phase report templates không trỏ về step name cũ
5. **Commit per finding** (hoặc gộp 2-3 logically related):
   ```
   refactor(wf-fix-bugs/procedures): F08.<NN> <mô tả ngắn> [F08-<NN>]

   Audit: plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md F08.<NN>
   Verification: bash run-tests.sh PASS + skill-compliance-audit clean
   ```

### 2.3 Post-Sprint

1. **Final verify:**
   - `bash run-tests.sh` PASS coverage 81.75% (regression)
   - `bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs` clean
   - `bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs` clean
   - Manual skim: SKILL.md routing table → procedure step names khớp
2. **Update audit report:** append "Sprint 9 Closed YYYY-MM-DD"
3. **Update plan file:** status DONE per finding
4. Recommend Sprint 10 (optional): lane_dispatch async path coverage

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 F08.015 cross-reference style

Khi centralize bug-dashboard:
1. **Inline `> See _shared.md §dashboard-update`** — minimal diff (recommended)
2. **Macro/include directive** — không có chuẩn DRY trong markdown DEVKIT
3. **Move toàn bộ phase logic về _shared, phase chỉ trỏ link** — risk break PRE-GATE flow

### 3.2 F08.020 step rename impact

Step 5.11b → 5.12 (shift 5.12-5.14):
1. **Manual edit + grep cross-refs** (recommended) — safer, smaller blast radius
2. **Helper script `rename-phase-step.sh`** — reusable cho future renames
3. **Skip nếu drift** — nếu phase5-execute đã consolidate steps khác

### 3.3 F03.014 context budget implementation

CORE-038 Phase 4 stub:
1. **Match wf-fix-bugs/SKILL.md context-budget pattern** (recommended) — consistency
2. **Custom impl per phase** — divergence risk
3. **Defer Sprint 10** nếu phase4-monitor refactor lớn hơn dự kiến

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Sau fix, `bash run-tests.sh` regression FAIL → rollback fix gần nhất
- ❌ `skill-compliance-audit` báo lỗi mới không tồn tại trước fix
- ❌ F08.020 rename phá routing table SKILL.md (cross-ref không sync)
- ❌ Decision point §3 có ≥2 valid options
- ❌ Finding "drift detected" (audit description không khớp code thực tế) → document + skip action

## 5. COMPLETION CRITERIA

Sprint 9 DONE khi:

✅ 9 findings F08.* + F03.014 đã apply (hoặc document drift)
✅ `bash run-tests.sh` PASS coverage 81.75%+ (regression preserved)
✅ `skill-compliance-audit wf-fix-bugs` clean
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-9-procedure-cleanup.md` DONE
✅ Audit report append "Sprint 9 Closed YYYY-MM-DD"
✅ 6-9 commits trên master (per finding hoặc nhóm)

## 6. KHỞI ĐỘNG

1. Đọc context (§0) + Sprint 8 closure (audit + plan)
2. **VERIFY baseline:**
   - `bash run-tests.sh` PASS coverage 81.75%
   - Inspect `procedures/_shared.md` + 6 phase files (phase1-7)
3. **`AskUserQuestion` 3 câu xác nhận:**
   - "Confirm scope Sprint 9 (9 procedure findings ~4h)?"
   - "Git permissions: commit trên master như Sprint 7+8?"
   - "Decision points §3 batch confirm trước hay hỏi từng finding?"
4. Tạo plan file + TodoWrite + start execute

## 7. CHECKPOINT & RESUME

Sprint 9 ~4h — single session khả thi. Nếu context > 80%:

1. **STOP** sau finding hiện tại completed
2. **Update** plan file status
3. **Commit** WIP `wip: pause at F08.NNN, resume from next`
4. **Note** audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 8 closure | §"Sprint 8 Closed — 2026-05-15" trong audit |
| Sprint 9 scope | §"Sprint 8 — Procedure Logic + Cleanup" trong audit (numbering audit lệch +1) |
| Test runner | `cd .claude/skills/workflow/_shared && bash run-tests.sh` |
| Skill compliance | `bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs` |
| Schema sync | `bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs` |
| Procedures dir | `.claude/skills/workflow/wf-fix-bugs/procedures/` |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Refactor cấu trúc procedure ngoài 9 findings (BHV-003)
- ❌ Đổi semantic step (chỉ rename hoặc tách, KHÔNG đổi behavior)
- ❌ Thêm CDG mới (chỉ thêm explicit `append cdg-tokens.json` cho CDG đã có)
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (pattern Sprint 3+4+5+6+7+8)
- ❌ Modify `.mc-data/` runtime files
- ❌ Move templates/state files thật (chỉ thay đổi DOCUMENTATION paths cho F08.030)

## 10. SPRINT 0+1+2+3+4+5+6+7+8 CONTEXT (đã DONE)

**Tổng đã DONE qua 8 sprints:** 56+ commits, ~38h actual.

**Sprint 7 final (2026-05-15):**
- Python coverage: 73.18% → 81.75% (+8.57pp), 1015 tests pass
- 4 commits, fail_under=80 restored

**Sprint 8 final (2026-05-15):**
- 8/8 F05 bash hardening findings + 1 drift documented
- 2 commits (1 prompt + 1 closure batch), regression PASS
- 28 scripts edited (5 critical + 1 helper + 26 probe scripts batch)

**Deferred sang Sprint 10+:**
- Sprint 10 (optional) — lane_dispatch async path coverage uplift (~3h)
- XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema` (out-of-scope)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + Sprint 8 closure audit + plan file, VERIFY baseline (`bash run-tests.sh` PASS 81.75%), rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + Sprint 8 closure
   - VERIFY baseline (coverage 81.75%, tests pass)
   - Hỏi 3 câu xác nhận (scope, git, decision strategy)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-9-procedure-cleanup.md`
   - Thực hiện 9 findings theo §2 quy trình
   - Hỏi user 3 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 9 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **3 decision points** §3 yêu cầu user input (cross-ref style, step rename impact, context budget impl)
- Có **safety guardrails** §4 Quality Gates — đặc biệt rename step không phá routing
- Có **resume mechanism** §7 — Sprint 9 ~4h single-session khả thi
- **Khác Sprint 8:** Sprint 9 focus 100% vào PROCEDURE DOCUMENTATION (markdown procedures, không Python/bash code thay đổi)
- Prompt nhấn mạnh **không đổi semantic** + **chỉ touch documentation/procedure structure** (BHV-003)

## Khuyến nghị thực thi

- **Single session feasible** (~4h)
- **High-risk fix:** F08.020 step rename — phải verify cross-refs SKILL.md + _contract.json + error code refs trước
- **Fallback:** Nếu drift detected ≥3 findings (audit overcount), document + skip; commit closure với coverage findings reduction
- **Verify regression:** Sau mỗi 2-3 fixes, chạy `bash run-tests.sh` smoke (~5min) để catch sớm
- **Audit cleanup:** Sprint 9 là sprint cuối cleanup major findings — sau đó codebase wf-fix-bugs ở trạng thái audit-clean
