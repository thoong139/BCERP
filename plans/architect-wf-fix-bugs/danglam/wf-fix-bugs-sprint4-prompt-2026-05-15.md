# Prompt: Thực hiện Sprint 4 — SKILL.md Compliance + Architecture (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `z:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 4 — SKILL.md Compliance + Architecture** của plan v10.3 dựa trên audit report 2026-05-15. Sprint 0+1+2+3 đã hoàn thành các phiên trước với 29 commits trên master.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-032 (Lazy-Load Procedures), CORE-037 (Agent Prompt Templates)
4. **`docs/wf-fix-bugs-audit-2026-05-15.md`** — audit report (focus §Sprint 4 + §Sprint 3 Closed + §XF-07 + §CRITICAL XF-07)
5. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-01-skill-structure.md`** — F01.* chi tiết (XF-07 a/b/c, F01.017)
6. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-08-procedure-logic.md`** — F08.003-004 step counts
7. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-04-cross-references.md`** — F04.004 template count
8. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-02-agent-spawn.md`** — F02.001 SDK runtime types

**Quy tắc tuyệt đối:**

- ✅ Áp dụng **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ Áp dụng **BHV-003** (Surgical Changes): CHỈ sửa đúng issue, KHÔNG refactor xung quanh
- ✅ Áp dụng **CORE-032**: SKILL.md là lean routing hub ≤500 dòng — logic thực thi nằm trong `procedures/`
- ✅ Áp dụng **CORE-007 + CORE-036**: Giữ nguyên output paths + gate markers + contract khi extract logic
- ✅ Mỗi finding = 1 commit (trừ batch grouping nếu fix cùng pattern)
- ✅ Tiếng Việt cho commits/docs; English cho code/paths
- ✅ Dùng **Serena tools** cho symbolic editing khi có thể; `Edit` cho docs/SKILL.md
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — audit có thể stale (Sprint 3 phát hiện F07.007 audit error). Đếm dòng thực tế, đọc content thực tế.
- ❌ KHÔNG tin tuyệt đối `skill-compliance-audit.sh` / `validate-schema-sync.sh` — verify file-level bằng `wc -l`, `grep`, đọc nội dung
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG thay đổi output paths / gate markers khi extract logic SKILL.md → procedures
- ❌ KHÔNG tự suy diễn khi audit có ambiguity — LUÔN AskUserQuestion

## 1. MỤC TIÊU SPRINT 4

**Scope:** ~8h effort, 6 findings — CORE-032 compliance (SKILL.md ≤500 dòng) + documentation drift sync.

**State đã verify (2026-05-15, có thể đổi — RE-VERIFY khi bắt đầu):**

| File | Dòng hiện tại | Giới hạn CORE-032 | Vượt |
|------|---------------|-------------------|------|
| `wf-fix-bugs/SKILL.md` | 588 | 500 | +88 |
| `wf-fix-triage/SKILL.md` | 556 | 500 | +56 |
| `wf-fix-execute/SKILL.md` | 512 | 500 | +12 |

- `wf-fix-triage/procedures/` hiện CHỈ có `phase2-triage.md` — thiếu `_shared.md` + `resume-status.md`
- `wf-fix-bugs/SKILL.md` claim "32 templates" (lines 8 + 581) nhưng disk có **36** files (non-archive)
- `wf-fix-bugs/SKILL.md` step counts: Phase 1 "23 steps", Phase 5 "14 steps", Phase 6 "10 steps" — audit nói actual 25/15/11

**Priority order:**

| # | Finding | Effort | Issue |
|---|---------|--------|-------|
| 1 | **XF-07a** | 30min | `wf-fix-execute/SKILL.md` 512 dòng — xóa Version History block (~dòng 495-512) → CHANGELOG.md, đưa về ≤500 |
| 2 | **F08.003-004** | 15min | Step counts mismatch: SKILL.md Phase 1=23→25, Phase 5=14→15, Phase 6=10→11 |
| 3 | **F04.004** | 30min | Template count "32" → 36; thêm bug-dashboard.md, fix-execution-result.json, probe-failures-log.json vào Output table |
| 4 | **XF-07b** | 3h | `wf-fix-triage/SKILL.md` 556 dòng — collapse Steps 2.1-2.10 thành Execution Summary table; tạo `procedures/_shared.md` + `procedures/resume-status.md` (F01.017) |
| 5 | **XF-07c** | 3h | `wf-fix-bugs/SKILL.md` 588 dòng — extract CI PRE-GATE 3-step (Na/Nb/Nc) + Error Codes narrative vào `procedures/_shared.md`, giữ Quick Lookup table |
| 6 | **F02.001** | 1h | Document SDK runtime types `"claude"` + `"general-purpose"` trong `agents/README.md` (subagent_type không phải agent file thực) |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. Đọc audit report + findings-01/08/04/02
2. **VERIFY state:** `wc -l` 3 SKILL.md files, đọc procedures/ directories, đếm templates
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-4-skill-compliance.md` với:
   - 6 finding IDs + files involved + current line counts
   - Extraction strategy per XF-07 item (chính xác block nào → procedure file nào)
   - Acceptance criteria per finding (line count target, contract preservation)
4. **TodoWrite**: 6 todos = 1 todo/finding (XF-07b, XF-07c có thể split subtasks)

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** chi tiết từ findings file tương ứng
2. **VERIFY current state:** `wc -l`, đọc block cần extract, xác nhận vấn đề tồn tại
3. **Decision point check:** Nếu ambiguity (block nào extract, đặt section nào) → `AskUserQuestion`
4. **Apply fix:**
   - SKILL.md extraction: CUT block → PASTE vào procedure file, để lại pointer ngắn "Xem `procedures/...`"
   - Tạo procedure mới: theo template CORE-032 (`_shared.md` cross-cutting, `resume-status.md` handlers)
   - Step count / template count: Edit số literal
5. **Verify:**
   - Line count: `wc -l SKILL.md` ≤ 500
   - Contract preserved: `grep` output paths + gate markers vẫn còn
   - Procedure references valid: `grep -rn "procedures/"` SKILL.md → mọi file tồn tại
   - Cross-skill: extracted logic không phá `_contract.json` orchestrates/produces_for
6. **Commit:** message format:
   ```
   fix({scope}): {one-line summary} [F0X.0YY]

   {2-3 dòng giải thích Vietnamese}

   Audit: docs/wf-fix-bugs-audit-2026-05-15.md F0X.0YY
   ```

### 2.3 Post-Sprint

1. Re-verify: `wc -l` cả 3 SKILL.md → tất cả ≤500
2. Cross-check: `validate-schema-sync.sh wf-fix-bugs` + `skill-compliance-audit.sh wf-fix-bugs` (dùng làm reference, KHÔNG phải SSOT)
3. Update audit report: append "Sprint 4 Closed YYYY-MM-DD" section với commit list
4. Update plan file: status DONE per finding
5. **AskUserQuestion:** tiếp tục Sprint 5 hay nghỉ?

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 XF-07b — wf-fix-triage Steps 2.1-2.10 collapse strategy

`wf-fix-triage/SKILL.md` hiện chứa Steps 2.1-2.10 inline (~chi tiết). Audit khuyến nghị:
- Collapse thành "Execution Summary" table trong SKILL.md
- Move chi tiết vào `procedures/phase2-triage.md` (đã tồn tại) HOẶC tạo mới

**Hỏi user:** Steps 2.1-2.10 đã có trong `procedures/phase2-triage.md` chưa (duplicate)? Nếu duplicate → SKILL.md chỉ cần Summary table + pointer. Nếu chưa → cần migrate content. Confirm strategy.

### 3.2 XF-07b — tạo procedures/_shared.md + resume-status.md cho wf-fix-triage

F01.017 yêu cầu wf-fix-triage có `procedures/_shared.md` + `procedures/resume-status.md` như wf-fix-bugs.

**Hỏi user:** Nội dung `_shared.md` lấy từ đâu — extract từ SKILL.md hiện tại, hay reference sang `wf-fix-bugs/procedures/_shared.md`? (wf-fix-triage là sub-skill, có thể share nhiều cross-cutting concerns)

### 3.3 XF-07c — wf-fix-bugs CI PRE-GATE + Error Codes extraction target

`wf-fix-bugs/SKILL.md` cần extract CI PRE-GATE 3-step narrative + Error Codes narrative. `procedures/_shared.md` ĐÃ TỒN TẠI và đã có §10 (Template), §12 (CI Detection Pattern), §4 (error codes?).

**Hỏi user:** Append vào `_shared.md` sections hiện có, hay tạo sections mới? Verify `_shared.md` §12 đã có CI PRE-GATE chưa — nếu có thì SKILL.md chỉ cần Quick Lookup table + pointer (tránh duplicate — F02.002 dual source of truth).

### 3.4 F02.001 — agents/README.md scope

`subagent_type="claude"` và `"general-purpose"` là SDK runtime types, KHÔNG phải agent definition files trong `.claude/agents/`. Audit muốn document điều này.

**Hỏi user:** Document trong `.claude/agents/README.md` (section mới "SDK Runtime Agent Types") hay tạo note riêng? Confirm vị trí.

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ SKILL.md sau extract vẫn >500 dòng (cần extract thêm — hỏi block nào)
- ❌ Extract làm mất pointer/contract (output path, gate marker biến mất)
- ❌ Procedure file mới tạo trùng nội dung file đã có (F02.002 dual source of truth risk)
- ❌ Decision point có ≥2 valid options (theo §3 trên)
- ❌ Context budget > 80% (checkpoint per CORE-038 — XF-07b/c nặng)
- ❌ Cần extend timeline > +50% (8h → 12h)
- ❌ `_contract.json` procedure[] array không khớp procedure files thực tế sau khi tạo mới

## 5. COMPLETION CRITERIA

Sprint 4 DONE khi:

✅ Tất cả 6 findings mark `completed` trong TodoWrite
✅ `wf-fix-bugs/SKILL.md` ≤ 500 dòng
✅ `wf-fix-triage/SKILL.md` ≤ 500 dòng + có `procedures/_shared.md` + `procedures/resume-status.md`
✅ `wf-fix-execute/SKILL.md` ≤ 500 dòng
✅ Step counts SKILL.md khớp procedures thực tế (Phase 1/5/6)
✅ Template count SKILL.md = 36 (khớp disk), Output table đủ 3 files thiếu
✅ `agents/README.md` document SDK runtime types
✅ Mọi procedure reference trong SKILL.md trỏ file tồn tại
✅ `_contract.json` procedure[] array đồng bộ với procedure files
✅ Output paths + gate markers preserved (verify grep)
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-4-skill-compliance.md` updated DONE
✅ Audit report append "Sprint 4 Closed YYYY-MM-DD"

## 6. KHỞI ĐỘNG

1. Serena đã active (project z:\Working\MCV3) — verify qua `mcp__serena__check_onboarding_performed` nếu cần
2. Đọc context (§0)
3. **VERIFY state thực tế:** `wc -l` 3 SKILL.md, `ls procedures/`, đếm templates
4. **`AskUserQuestion` 4 câu xác nhận:**
   - **"Confirm scope Sprint 4 (6 findings ~8h) hay subset?"** → XF-07b+c nặng (6h), có thể tách subset quick-wins (XF-07a + F08.003-004 + F04.004 + F02.001 ≈ 2.25h)
   - **"Git permissions: commit trên master như Sprint 0-3?"** → Confirm
   - **"Decision points §3 batch confirm trước hay hỏi từng cái?"** → Recommend batch confirm
   - **"Context budget: XF-07b+c có thể đẩy >80% — chia 2 phiên (quick-wins phiên này, XF-07 phiên sau) hay làm hết?"**
5. Tạo plan file + TodoWrite + start execute theo §2

## 7. CHECKPOINT & RESUME

Nếu context > 80% / phiên hết:

1. **STOP** sau finding hiện tại completed
2. **Update** plan file với status (DONE/IN_PROGRESS/PENDING per finding)
3. **Commit** WIP `wip: pause at F0X.0YY, resume from {next finding}`
4. **Note** audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `docs/wf-fix-bugs-audit-2026-05-15.md` |
| Findings skill structure | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-01-skill-structure.md` |
| Findings procedure logic | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-08-procedure-logic.md` |
| Findings cross-refs | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-04-cross-references.md` |
| Findings agent spawn | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-02-agent-spawn.md` |
| SKILL.md targets | `.claude/skills/workflow/wf-fix-{bugs,triage,execute}/SKILL.md` |
| Procedure dirs | `.claude/skills/workflow/wf-fix-{bugs,triage,execute}/procedures/` |
| Contract files | `.claude/skills/workflow/wf-fix-{bugs,triage,execute}/_contract.json` |
| Agents README | `.claude/agents/README.md` |
| Compliance audit | `./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs` (reference only) |
| Schema sync | `./.claude/scripts/validate-schema-sync.sh wf-fix-bugs` (reference only) |
| CORE-032 spec | `.claude/rules/00-core.md` §4i |
| Sprint 3 Closed details | `docs/wf-fix-bugs-audit-2026-05-15.md §Sprint 3 Closed` |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Sửa nhiều findings 1 commit (trừ logical pattern fix)
- ❌ Refactor SKILL.md ngoài fix yêu cầu (BHV-003) — chỉ extract, không rewrite
- ❌ Thêm sections/logic mới khi extract (BHV-002) — extract = move, không tạo mới
- ❌ Tạo procedure file duplicate nội dung file đã có (F02.002 dual source of truth)
- ❌ Xóa output paths / gate markers / contract references khi extract
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Bypass pre-commit hooks (`--no-verify`)
- ❌ Modify `.mc-data/` runtime files
- ❌ Tự chọn decision points §3 khi ambiguous — LUÔN AskUserQuestion
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (Sprint 3 đã phát hiện F07.007 audit error)

## 10. SPRINT 0+1+2+3 CONTEXT (đã DONE — 29 commits)

**Sprint 0** (Quick-Wins, 14 items): 1 commit `310797e3`
**Sprint 1** (Critical Pipeline Blockers, 9 items): 9 commits — XF-05, XF-01, F03.015, F05.001, F05.002, F06.002, XF-06 PARTIAL, F04.003, F04.002
**Sprint 2** (Error Code Namespace, subset 5 items): 5 commits — F04.007, XF-02 PARTIAL, F03.008, F03.020
**Sprint 3** (Template + Schema Compliance, full 10 findings): 8 commits — XF-04, XF-03/F07.001, F07.003, F07.011, F07.009, F07.010, F07.008, F07.007, F07.004
  - Commits: `16f07e3c` `f97222d1` `289c08ba` `af94b7b9` `5a1ef053` `60771856` `de99ef08` `7c863b55`
  - **Lưu ý Sprint 3:** F07.007 audit recommendation SAI — `lane-report.md` được 11 lane skills consume, KHÔNG archive được. Bài học: LUÔN verify state thực tế.

**Tổng đã DONE:** 29 commits, ~20.5h actual.

**Deferred sang Sprint 5+:**
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- XF-02 Step 3-5 (E010/E013 dual-use, wf-fix-integration E099-E106)
- 14 state JSON templates không có `$schema` (out-of-scope, state files thường không cần)
- Sprint 5-8 plan từ original audit (Agent Spawn Quality, Python Coverage, Bash Hardening, Procedure Logic)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + audit report + findings-01/08/04/02, VERIFY state 3 SKILL.md, rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `z:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + audit + findings detail
   - VERIFY state thực tế (line counts, procedures, template count)
   - Hỏi 4 câu xác nhận (scope, git, decision strategy, context budget split)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-4-skill-compliance.md`
   - Thực hiện 6 findings theo §2 quy trình
   - Hỏi user 4 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 4 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **4 decision points** §3 yêu cầu user input (extraction strategy)
- Có **safety guardrails** §4 Quality Gates — đặc biệt context budget (XF-07b+c nặng 6h)
- Có **resume mechanism** §7 nếu phiên hết
- **Khác Sprint 3:** Sprint 4 chủ yếu là refactor/extract (không tạo content mới) — rủi ro chính là phá contract/gate markers khi cắt SKILL.md
- Prompt nhấn mạnh **VERIFY state thực tế** vì Sprint 3 đã phát hiện 1 audit error (F07.007)

## Khuyến nghị thực thi

- **Recommend:** Chia 2 phiên — phiên 1 quick-wins (XF-07a + F08.003-004 + F04.004 + F02.001 ≈ 2.25h), phiên 2 XF-07b+c (6h). Tránh context budget vượt 80%.
- **Alternative:** Nếu muốn làm hết 1 phiên, theo dõi context budget sát, checkpoint sau mỗi XF-07 item.
