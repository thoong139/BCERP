# Prompt: Thực hiện Sprint 5 — Agent Spawn Quality (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 5 — Agent Spawn Quality (CORE-037 Compliance)** của plan v10.3 dựa trên audit report 2026-05-15. Sprint 0+1+2+3+4 đã hoàn thành ở các phiên trước với 35 commits trên master.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-029 (Agent Output Spot-Check), CORE-037 (Agent Prompt Templates 8 sections), CORE-025 (Parallel Safety, max 10 agents)
4. **`docs/wf-fix-bugs-audit-2026-05-15.md`** — audit report (focus §Sprint 5 đề xuất + §F02 cluster — F02.001-F02.011)
5. **`.claude/skills/workflow/wf-fix-bugs/procedures/_shared.md`** — đặc biệt §15 (Agent Prompt Templates) hiện chứa duplicate prompts với procedure Steps
6. **`.claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md`** — Step 4.5 Lane Agent dispatch + Boundary Mode sub-sub-agents
7. **`.claude/skills/workflow/wf-fix-bugs/procedures/phase5-triage.md`** — Step 5.7 (current: BASH COMMENT thay vì actual Agent() call)
8. **`.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute.md`** — Step 6.5 spawn wf-fix-execute prompt

**Quy tắc tuyệt đối:**

- ✅ Áp dụng **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ Áp dụng **BHV-003** (Surgical Changes): CHỈ sửa đúng issue, KHÔNG refactor xung quanh
- ✅ Áp dụng **CORE-037**: Mọi agent prompt PHẢI có đủ 8 sections (Role, Task, Session Context, CI Context, Playwright Context, Output Contract, Ownership Rules, Completion Criteria)
- ✅ Áp dụng **CORE-025**: Max 10 concurrent agents, 1 file = 1 writer
- ✅ Áp dụng **CORE-007 + CORE-036**: Giữ nguyên output paths + cross-skill contract khi sửa prompts
- ✅ Mỗi finding = 1 commit (trừ batch grouping nếu fix cùng pattern, vd: F02.003 + F02.005 cùng sub-probe template)
- ✅ Tiếng Việt cho commits/docs; English cho code/paths
- ✅ Dùng **Serena tools** (`replace_symbol_body`, `replace_content`) cho symbolic editing khi có thể; `Edit` cho prompt blocks
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — audit có thể stale (Sprint 3 phát hiện F07.007, Sprint 4 phát hiện XF-07a + XF-07c stale). Đọc nội dung thực tế, đếm sections, xác nhận block tồn tại.
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG thay đổi output paths / agent role definitions khi fix prompt sections
- ❌ KHÔNG tự suy diễn khi audit có ambiguity — LUÔN AskUserQuestion

## 1. MỤC TIÊU SPRINT 5

**Scope:** ~4h effort, 5 findings — CORE-037 compliance + agent spawn correctness.

**State đã biết (verify lại khi bắt đầu):**

| Vị trí | Vấn đề | Severity |
|--------|--------|----------|
| `_shared.md §15` (lines 535-615+) | Chứa Triage 4/8 sections + Execute 3/8 sections — duplicate với procedure Steps 5.7/6.5 (6/8 + 5/8). LLM đọc `_shared.md` trước sẽ dùng prompt yếu hơn. (F02.002 + F02.006) | CRITICAL |
| `phase5-triage.md` Step 5.7 (line ~448-453) | Spawn block là BASH COMMENT (`# subagent_type=...`) thay vì actual `Agent({...})` tool call (F02.004) | CRITICAL |
| QD1 + QD2 sub-probes (Boundary Mode lvl 3) | 6 sub-probe Agent() calls THIẾU `model="opus"` (F02.003): P-QD1-feature-verify, P-QD1-spec-completeness, P-QD2-ba-review, P-QD2-domain-review (3 boundary instances) | HIGH |
| Sub-probe prompts | Thiếu 5/8 CORE-037 sections (Role formal, Session Context inject, CI Context, Ownership, Completion) — F02.005 | HIGH |
| Phase 5 + Phase 6 prompts | Thiếu Role formal declaration, Playwright N/A note, Ownership explicit boundary, Task SKILL.md reference (F02.007-009) | MEDIUM |
| Boundary Mode QD2 sub-sub-agents (cấp 3) | Không có concurrency guard (max 10 violated tiềm năng) — F02.011 | MEDIUM |

**Priority order:**

| # | Finding | Effort | Issue |
|---|---------|--------|-------|
| 1 | **F02.004** | 30min | Sửa Step 5.7 BASH COMMENT → actual `Agent({subagent_type, model, prompt})` call. Quick win, critical bug |
| 2 | **F02.002 + F02.006** | 1h | Xóa duplicate prompts khỏi `_shared.md §15`, thay bằng pointer "Canonical: Step 5.7" + "Canonical: Step 6.5". Bổ sung sections còn thiếu vào hai Steps |
| 3 | **F02.003** | 30min | Thêm `model="opus"` vào 6 sub-probe Agent() calls (Boundary Mode QD1 + QD2 sub-probes trong Phase 4) |
| 4 | **F02.005** | 1h | Tạo shared sub-probe prompt template (8 CORE-037 sections); inject `$SESSION_DIR` + `$PROFILE` + `$CI_CONTEXT`; reuse cho 6 sub-probes |
| 5 | **F02.007-009 + F02.011** | 1h | Phase 5 Step 5.7 + Phase 6 Step 6.5 prompts: thêm Role formal (header), Playwright N/A note (delegate skill không launch browser), Ownership explicit (chỉ ghi `phase5-triage/` hoặc `phase6-execute/`), Task SKILL.md reference. Add concurrency guard cho QD2 sub-sub-agents (boundary mode lvl 3) |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. Đọc audit report (§Sprint 5 plan + §F02 findings)
2. **VERIFY state:**
   - `grep -n "§15\|Agent Prompt Templates" .claude/skills/workflow/wf-fix-bugs/procedures/_shared.md` → confirm `_shared.md §15` block tồn tại
   - Đọc `_shared.md` lines 535-630 → đếm sections thực tế trong Triage + Execute prompts
   - Đọc `phase5-triage.md` Step 5.7 → confirm bash comment block lines ~448-453
   - `grep -rn "model.*opus\|model=\"opus\"" .claude/skills/workflow/wf-fix-bugs/procedures/phase4*.md` → tìm sub-probe Agent() calls
   - Đọc `phase4-find-bugs.md` Boundary Mode section → identify 6 sub-probes (P-QD1-feature-verify, P-QD1-spec-completeness, P-QD2-ba-review, P-QD2-domain-review × 3 instances)
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-5-agent-spawn.md` theo pattern Sprint 4:
   - 5 finding IDs + files involved + current state
   - Strategy per finding (extraction target, sections to add)
   - Acceptance criteria per finding
4. **TodoWrite**: 5 todos (mỗi finding 1 todo, có thể split F02.005 nếu phức tạp)

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** chi tiết từ audit report
2. **VERIFY current state:** Đọc block cần sửa, đếm sections, xác nhận vấn đề tồn tại
3. **Decision point check:** Nếu ambiguity → `AskUserQuestion`
4. **Apply fix:**
   - F02.004: Replace bash comment block thành actual `Agent({...})` tool call format
   - F02.002+006: Xóa duplicate prompts trong `_shared.md §15`, thêm pointers; bổ sung sections còn thiếu vào procedure Steps 5.7/6.5
   - F02.003: Add `model="opus"` parameter vào 6 sub-probe Agent() calls
   - F02.005: Tạo shared template (markdown block) với 8 sections, document trong `_shared.md` mới như "§Sub-Probe Template" (KHÔNG duplicate prompt body — chỉ pattern + placeholders), reference từ Boundary Mode procedure
   - F02.007-009: Edit Phase 5/6 prompts inline thêm 4 sections còn thiếu
   - F02.011: Add concurrency guard pseudocode cho QD2 sub-sub-agents (semaphore hoặc throttle pattern, không vượt 10 cấp 3)
5. **Verify:**
   - CORE-037 8 sections present (Role, Task, Session, CI, Playwright, Output, Ownership, Completion)
   - Contract preserved: output paths trong prompts vẫn trỏ đúng `$SESSION_DIR/phase{N}-{name}/`
   - Cross-skill: prompts không phá `_contract.json §orchestrates[]`
   - Agent tool call format đúng (subagent_type + model + prompt)
6. **Commit:** message format:
   ```
   fix({scope}): {one-line summary} [F02.0YY]

   {2-3 dòng giải thích Vietnamese}

   Audit: docs/wf-fix-bugs-audit-2026-05-15.md F02.0YY
   ```

### 2.3 Post-Sprint

1. Re-verify: grep CORE-037 8 sections trong mọi agent prompt block
2. Cross-check: `_shared.md §15` không còn duplicate (chỉ pointers + sub-probe template)
3. Update audit report: append "Sprint 5 Closed YYYY-MM-DD" section với commit list
4. Update plan file: status DONE per finding
5. **AskUserQuestion:** tiếp tục Sprint 6 (Python Coverage ~12h) hay nghỉ?

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 F02.002 — Strategy xóa duplicate prompts trong `_shared.md §15`

`_shared.md §15` hiện chứa:
- Triage Agent Prompt (4/8 sections) — duplicate với Step 5.7 (6/8 sections, mới hơn)
- Execute Agent Prompt (3/8 sections) — duplicate với Step 6.5 (5/8 sections, mới hơn)
- Lane Agent Prompt — KHÔNG duplicate (canonical cho Phase 4 dispatch)

**Hỏi user:** 3 options:
1. **Xóa hoàn toàn Triage + Execute blocks khỏi §15, thay bằng pointer** "Canonical: phase5-triage.md §Step 5.7" + "Canonical: phase6-execute.md §Step 6.5". Giữ Lane Agent Prompt nguyên.
2. **Giữ §15 nhưng compact** — chỉ ghi pattern + placeholders (KHÔNG duplicate full body), Steps 5.7/6.5 là canonical source.
3. **Move §15 prompts thành templates** trong `templates/phase{5,6}-{triage,execute}/agent-prompt.md` (CORE-031 template-based).

### 3.2 F02.005 — Sub-probe prompt template location

6 sub-probes (P-QD1-feature-verify, P-QD1-spec-completeness, P-QD2-ba-review, P-QD2-domain-review × 3 boundary instances) cần shared template với 8 CORE-037 sections.

**Hỏi user:** Template đặt ở đâu:
1. **Trong `_shared.md` mới §16 "Sub-Probe Template"** — inline markdown, reference từ phase4-find-bugs.md Boundary Mode section.
2. **File template riêng** `templates/phase4-find-bugs/sub-probe-prompt.md` (CORE-031 pattern, render qua placeholders).
3. **Inline trong `phase4-find-bugs.md`** — section "## Sub-Probe Prompt Pattern" với 8 sections.

### 3.3 F02.011 — QD2 sub-sub-agents concurrency guard

Boundary Mode QD2 spawn sub-sub-agents (cấp 3) không có concurrency limit. Risk: spawn N main lanes × M boundary sub-probes × K sub-sub-agents > 10 concurrent.

**Hỏi user:** Guard pattern:
1. **Semaphore counter** — global counter trong session-log.json, atomic increment/decrement quanh Agent() spawn. Block nếu >10.
2. **Throttle by depth** — Limit cấp 3 max 3 concurrent (max 10 = 4 main + 3 cấp 2 + 3 cấp 3).
3. **Sequential dispatch cấp 3** — Boundary Mode lvl 3 chạy sequential, không parallel (an toàn nhất, chậm hơn).

### 3.4 F02.007-009 — Phase 5/6 prompts missing sections — pattern

Step 5.7 hiện có 6/8 sections (thiếu: Role formal header, Playwright N/A). Step 6.5 hiện có 5/8 (thiếu: Role formal, Playwright N/A, Ownership explicit).

**Hỏi user:** Confirm thêm các sections sau theo CORE-037 chuẩn:
- **Role formal:** "Bạn là [skill-name] agent — [1-câu mô tả role]." (đã có inline, formal hóa thành section 1)
- **Playwright N/A:** "Section 5: Playwright Context — KHÔNG áp dụng (delegate skill không launch browser)."
- **Ownership explicit:** "Section 7: Ownership — CHỈ ghi vào `$SESSION_DIR/phase{N}-{name}/`. KHÔNG ghi đè outputs của Phase khác."

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Sửa prompt làm mất output path → contract preservation fail
- ❌ Sub-probe template tạo dual source of truth mới (giống F02.002 cũ)
- ❌ Concurrency guard chọn pattern làm chậm pipeline > 50% (sequential lvl 3 risk)
- ❌ Decision point có ≥2 valid options (theo §3 trên)
- ❌ Context budget > 80% (checkpoint per CORE-038)
- ❌ Cần extend timeline > +50% (4h → 6h)
- ❌ Agent tool call format mới không khớp với Claude Code SDK syntax

## 5. COMPLETION CRITERIA

Sprint 5 DONE khi:

✅ Tất cả 5 findings mark `completed` trong TodoWrite
✅ Step 5.7 có actual `Agent({subagent_type, model, prompt})` call (không phải bash comment)
✅ `_shared.md §15` KHÔNG còn duplicate prompts với Steps 5.7/6.5
✅ 6 sub-probe Agent() calls có `model="opus"` parameter
✅ Sub-probe template với 8 CORE-037 sections tồn tại (location theo §3.2)
✅ Step 5.7 + Step 6.5 prompts có đủ 8 CORE-037 sections
✅ QD2 sub-sub-agents có concurrency guard (theo §3.3)
✅ Cross-skill contracts preserved (verify `_contract.json §orchestrates[]`)
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-5-agent-spawn.md` updated DONE
✅ Audit report append "Sprint 5 Closed YYYY-MM-DD"

## 6. KHỞI ĐỘNG

1. Serena đã active (project `d:\Working\MCV3`) — verify qua `mcp__serena__check_onboarding_performed` nếu cần
2. Đọc context (§0)
3. **VERIFY state thực tế:**
   - `_shared.md §15` block sections count
   - `phase5-triage.md` Step 5.7 bash comment exists
   - Phase 4 sub-probe Agent() calls list
   - Phase 6 Step 6.5 prompt sections
4. **`AskUserQuestion` 4 câu xác nhận:**
   - **"Confirm scope Sprint 5 (5 findings ~4h)?"** → Có thể split nếu F02.011 concurrency guard phức tạp
   - **"Git permissions: commit trên master như Sprint 0-4?"** → Confirm
   - **"Decision points §3 (xóa §15 duplicate, sub-probe template location, concurrency guard, Phase 5/6 sections): batch confirm trước hay hỏi từng cái?"** → Recommend batch confirm
   - **"Context budget: Sprint 5 nhẹ (4h) — làm hết 1 phiên hay tách F02.011 ra phiên sau?"**
5. Tạo plan file + TodoWrite + start execute theo §2

## 7. CHECKPOINT & RESUME

Nếu context > 80% / phiên hết:

1. **STOP** sau finding hiện tại completed
2. **Update** plan file với status (DONE/IN_PROGRESS/PENDING per finding)
3. **Commit** WIP `wip: pause at F02.0YY, resume from {next finding}`
4. **Note** audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `docs/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 5 section trong audit | §"Sprint 5 — Agent Spawn Quality (0.5 ngày, ~4h)" |
| F02 cluster details | §HIGH Findings — Agent Spawn Quality |
| Target files | `.claude/skills/workflow/wf-fix-bugs/procedures/{_shared,phase4-find-bugs,phase5-triage,phase6-execute}.md` |
| Contract file | `.claude/skills/workflow/wf-fix-bugs/_contract.json` |
| CORE-037 spec | `.claude/rules/00-core.md` §4n |
| CORE-025 parallel safety | `.claude/rules/00-core.md` §0 (CORE-025) |
| Sprint 4 closure | `docs/wf-fix-bugs-audit-2026-05-15.md §Sprint 4 Closed` |
| Sprint 4 plan | `plans/wf-fix-bugs-v10-3-audit/sprint-4-skill-compliance.md` |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Sửa nhiều findings 1 commit (trừ batch logical fix như F02.003 + F02.005 cùng sub-probe pattern)
- ❌ Tự suy diễn prompt sections nội dung (BHV-001) — extract từ existing prompt + add missing sections, KHÔNG rewrite
- ❌ Thay đổi agent role definitions khi fix sections (BHV-003) — chỉ add structure, không đổi behavior
- ❌ Duplicate prompts mới khi tạo sub-probe template (F02.002 anti-pattern)
- ❌ Concurrency guard làm chậm pipeline > 50% — verify với user trước khi áp dụng sequential
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Bypass pre-commit hooks (`--no-verify`)
- ❌ Modify `.mc-data/` runtime files
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (Sprint 3+4 đã phát hiện 3 audit drifts: F07.007, XF-07a, XF-07c)

## 10. SPRINT 0+1+2+3+4 CONTEXT (đã DONE — 35 commits)

**Sprint 0** (Quick-Wins, 14 items): 1 commit `310797e3`
**Sprint 1** (Critical Pipeline Blockers, 9 items): 9 commits — XF-05, XF-01, F03.015, F05.001, F05.002, F06.002, XF-06 PARTIAL, F04.003, F04.002
**Sprint 2** (Error Code Namespace, subset 5 items): 5 commits — F04.007, XF-02 PARTIAL, F03.008, F03.020
**Sprint 3** (Template + Schema Compliance, full 10 findings): 8 commits — XF-04, XF-03/F07.001, F07.003, F07.011, F07.009, F07.010, F07.008, F07.007, F07.004
  - F07.007 audit drift detected + corrected
**Sprint 4** (SKILL.md Compliance + Architecture, full 6 findings): 7 commits — XF-07a, F08.003-004, F04.004, F02.001, XF-07b/F01.017, XF-07c, closure
  - Commits: `b8302941` `975534cd` `72444944` `42cf2153` `e34d7ee7` `73d42ebc` `a0d62cd7`
  - XF-07a + XF-07c audit drifts detected + corrected — bài học: VERIFY state thực tế trước
  - Kết quả: 3/3 SKILL.md ≤500 dòng (588→476, 556→411, 512→483)

**Tổng đã DONE:** 35 commits, ~23.5h actual.

**Deferred sang Sprint 6+:**
- Sprint 6 — Python Coverage + Concurrency (~12h): XF-08 coverage gate 80%, F06.004-008 lock + observability
- Sprint 7 — Bash Scripts Hardening (~4h)
- Sprint 8 — Procedure Logic + Cleanup (~4h)
- XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema` (out-of-scope)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + audit report §Sprint 5 + §F02 cluster, VERIFY state 4 files target (`_shared.md`, `phase4-find-bugs.md`, `phase5-triage.md`, `phase6-execute.md`), rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + audit + F02 findings detail
   - VERIFY state thực tế (4 procedure files)
   - Hỏi 4 câu xác nhận (scope, git, decision strategy, split context)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-5-agent-spawn.md`
   - Thực hiện 5 findings theo §2 quy trình
   - Hỏi user 4 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 5 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **4 decision points** §3 yêu cầu user input (extraction strategy, template location, concurrency guard, prompt sections)
- Có **safety guardrails** §4 Quality Gates — đặc biệt concurrency guard chậm hơn 50%
- Có **resume mechanism** §7 nếu phiên hết (Sprint 5 nhẹ ~4h, ít cần resume)
- **Khác Sprint 4:** Sprint 5 chủ yếu là quality improvement (prompt structure), KHÔNG phải refactor lớn — rủi ro chính là phá agent role definition hoặc tạo duplicate prompts mới
- Prompt nhấn mạnh **VERIFY state thực tế** vì Sprint 3+4 đã phát hiện 3 audit drifts (F07.007, XF-07a, XF-07c)

## Khuyến nghị thực thi

- **Recommend:** Làm hết 1 phiên — Sprint 5 nhẹ (4h ước tính), context không bị nặng. F02.011 concurrency guard nếu phức tạp có thể split sang phiên sau.
- **Alternative:** Nếu user muốn cẩn trọng, có thể tách F02.011 (concurrency guard, kỹ thuật phức tạp) ra phiên riêng → phiên 1: F02.002-007-009 (~3h), phiên 2: F02.011 (~1h).
