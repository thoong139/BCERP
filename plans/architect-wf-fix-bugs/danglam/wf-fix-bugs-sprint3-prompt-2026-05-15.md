# Prompt: Thực hiện Sprint 3 — Template + Schema Compliance (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `z:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 3 — Template + Schema Compliance** của plan v10.3 dựa trên audit report 2026-05-15. Sprint 0+1+2 đã hoàn thành phiên trước với 21 commits trên master.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-031 (Template Usage), CORE-036 (Cross-Skill Artifact)
4. **`docs/wf-fix-bugs-audit-2026-05-15.md`** — audit report (focus §Sprint 3 + §Sprint 2 Closed + §Sprint 0+1 Closed sections)
5. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-07-templates.md`** — chi tiết F07.* findings
6. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-04-cross-references.md`** — XF-03, F07.003, F07.011 cross-ref

**Quy tắc tuyệt đối:**

- ✅ Áp dụng **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ Áp dụng **BHV-003** (Surgical Changes): CHỈ sửa đúng issue, KHÔNG refactor xung quanh
- ✅ Áp dụng **CORE-031**: Template Usage Rule — mọi output file PHẢI từ template (READ → POPULATE → WRITE)
- ✅ Áp dụng **CORE-036**: Cross-Skill Artifact phải có `$schema` field + audit_chain checksum
- ✅ Mỗi finding = 1 commit (trừ batch grouping nếu fix cùng pattern)
- ✅ Tiếng Việt cho commits/docs; English cho code/paths
- ✅ Dùng **Serena tools** cho symbolic editing khi có thể; `Edit` cho docs/templates
- ❌ KHÔNG skip verification (`jq '.' file.json > /dev/null`, `validate-schema-sync.sh`)
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG tự suy diễn khi audit có ambiguity — LUÔN AskUserQuestion

## 1. MỤC TIÊU SPRINT 3

**Scope:** ~7h effort, 9 findings — Template + Schema Compliance để đạt CORE-031 + CORE-036 PASS.

**Priority order:**

| # | Finding | Effort | Issue |
|---|---------|--------|-------|
| 1 | **XF-04** | 2h | Template `_template_notes` leak risk — STRIP pattern không cover `_how_to_use`, `_example`, `_entry_schema_notes` |
| 2 | **XF-03** | 1h | `fix-log.json` schema 3-way conflict — choose canonical (v1 vs v2) |
| 3 | **F07.001** | 1h | (part of XF-03) Resolve fix-log.json conflict between `_shared/lane/templates/` and `wf-fix-bugs/templates/phase5-triage/` |
| 4 | **F07.003** | 15min | Add `$schema: "fix-execution-result-v1"` field |
| 5 | **F07.011** | 30min | Add `$schema` field vào 4 templates: `issue-registry.json`, `cdg-tokens.json`, `process-violations.json`, `safety-check.json` |
| 6 | **F07.009** | 30min | Resolve dual templates: `bug-triage.md` + `fix-report.md` tồn tại 2 locations với content khác hoàn toàn |
| 7 | **F07.010** | 30min | `fix-plan.md` dual versions (36 dòng v10 vs 320 dòng _shared legacy) |
| 8 | **F07.008** | 10min | Xóa orphan `_shared/lane/templates/lane-signal.json` |
| 9 | **F07.007** | 30min | Clarify `lane-report.md` (164 dòng) vs `QD-report.md` (33 dòng) — deprecate non-canonical |
| 10 | **F07.004** | 1h | Update 7 `Phase{N}-report.md` templates theo CORE-028 format (H2, PASS|FAIL suffix, Vietnamese sections) |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. Đọc audit report + findings-07 + findings-04
2. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-3-templates.md` với:
   - Danh sách 10 finding IDs + files involved
   - Decision points (v1 vs v2, canonical vs legacy) — flag để AskUserQuestion
   - Acceptance criteria per finding
3. **TodoWrite**: 10 todos = 1 todo/finding
4. **Verify state:** chạy `validate-schema-sync.sh wf-fix-bugs` để baseline

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** chi tiết từ findings-07-templates.md hoặc findings-04-cross-references.md
2. **VERIFY current state:** confirm vấn đề tồn tại (file content, structure)
3. **Decision point check:** Nếu finding có ambiguity (chọn v1/v2, keep/delete) → `AskUserQuestion`
4. **Apply fix:**
   - Templates JSON: dùng `jq` build từ source, validate before mv
   - Templates MD: Edit tool, preserve formatting
   - JSON schema field: `jq '.$schema = "..."'` atomic write
5. **Verify:**
   - JSON files: `jq '.' file.json > /dev/null`
   - Templates referenced: `grep -rn "template_path"` để check consumers OK
   - Schema sync: `./.claude/scripts/validate-schema-sync.sh wf-fix-bugs`
6. **Commit:** message format:
   ```
   fix({scope}): {one-line summary} [F0X.0YY]

   {2-3 dòng giải thích Vietnamese}

   Audit: docs/wf-fix-bugs-audit-2026-05-15.md F0X.0YY
   ```

### 2.3 Post-Sprint

1. Re-run validation:
   ```bash
   ./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs
   ./.claude/scripts/validate-schema-sync.sh wf-fix-bugs
   ./.claude/scripts/validate-pipeline-naming.sh
   ```
2. Update audit report: append "Sprint 3 Closed YYYY-MM-DD" section với commit list
3. Update plan file: status DONE per finding
4. **AskUserQuestion:** tiếp tục Sprint 4 hay nghỉ?

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 XF-04 — STRIP Pattern Scope

Audit recommends jq filter loại bỏ MỌI field bắt đầu `_`:
```bash
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)'
```

**Hỏi user:** Có muốn áp dụng pattern toàn bộ procedures hay chỉ cập nhật canonical reference trong `_shared.md §19` (Template Usage)?

### 3.2 XF-03 — fix-log.json canonical v1 vs v2

3 nguồn conflict:
- `wf-fix-bugs/templates/phase5-triage/fix-log.json` — v2 (action, result, file_changed, notes), THIẾU `$schema`
- `_shared/lane/templates/fix-log.json` — v1 (`$schema: "fix-log-v1"`, batch, iteration, files_modified, behavior_changed)
- `procedures/phase5-triage.md` table ghi "fix-log-v1" trỏ template v2

Audit recommendation: chọn v2 (dashboard_generator.py dùng v2, more operational info).

**Hỏi user:** Confirm chọn v2 canonical + add `$schema: "fix-log-v2"` field, hay v1 (giữ `_shared/lane` template làm canonical)?

### 3.3 F07.009 — Dual templates resolution

- `wf-fix-triage/templates/bug-triage.md` (244 dòng legacy) vs `wf-fix-bugs/templates/phase5-triage/bug-triage.md` (29 dòng v10)
- `wf-fix-execute/templates/fix-report.md` (230 dòng legacy) vs `wf-fix-bugs/templates/phase6-execute/fix-report.md` (28 dòng v10)

**Hỏi user:** Keep v10 minimal (29/28 dòng) + archive legacy 244/230 dòng? Hay merge content?

### 3.4 F07.010 — fix-plan.md dual versions

- `wf-fix-bugs/templates/phase5-triage/fix-plan.md` (36 dòng v10)
- `_shared/lane/templates/fix-plan.md` (320 dòng legacy v7)

wf-fix-triage contract trỏ `_shared`, wf-fix-bugs trỏ `phase5-triage` → cùng output path, content khác.

**Hỏi user:** Choose canonical v10 (concise) hay legacy v7 (comprehensive)?

### 3.5 F07.007 — lane-report.md vs QD-report.md

- `_shared/lane/templates/lane-report.md` (164 dòng)
- `wf-fix-bugs/templates/phase4-find-bugs/QD-report.md` (33 dòng)

DUPLICATE purpose, no canonical declared.

**Hỏi user:** Choose canonical (QD-report v10 hay lane-report legacy)? Archive other?

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Schema-sync validation FAIL không tự fix được
- ❌ Test suite FAIL > 1 retry
- ❌ Decision point có ≥2 valid options (theo §3 trên)
- ❌ Context budget > 80% (checkpoint per CORE-038)
- ❌ Cần extend timeline > +50% (7h → 10.5h)
- ❌ Cross-skill consumer impact (vd: dashboard_generator.py phải read được template format đã chọn)

## 5. COMPLETION CRITERIA

Sprint 3 DONE khi:

✅ Tất cả 10 findings mark `completed` trong TodoWrite
✅ `skill-compliance-audit.sh wf-fix-bugs` → no NEW errors
✅ `validate-schema-sync.sh wf-fix-bugs` → no NEW errors
✅ Mọi JSON template có `$schema` field (verify: `find templates -name "*.json" -exec jq -e '."\$schema"' {} \;`)
✅ `_template_notes` STRIP pattern documented trong `_shared.md §19`
✅ Dual versions resolved (1 canonical, archive/delete other)
✅ Phase{N}-report.md templates conform CORE-028 (## H2 + PASS|FAIL suffix + Vietnamese sections)
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-3-templates.md` updated DONE
✅ Commits format chuẩn + tham chiếu finding IDs
✅ Audit report append "Sprint 3 Closed YYYY-MM-DD"

## 6. KHỞI ĐỘNG

1. Activate Serena: `mcp__serena__check_onboarding_performed`
2. Đọc context (§0)
3. **`AskUserQuestion` 4 câu xác nhận:**
   - **"Confirm scope Sprint 3 (10 findings ~7h) hay subset?"** → Recommend full nếu fresh phiên
   - **"Git permissions: commit trên master như Sprint 0+1+2?"** → Confirm
   - **"Decision points §3 sẵn sàng được hỏi từng cái khi gặp, hay batch confirm trước?"** → Recommend batch confirm trước (faster)
   - **"Có cần preflight smoke-test trước khi sửa?"** → Recommend yes nếu chưa biết state hiện tại

4. Tạo plan file + TodoWrite + start execute theo §2

## 7. CHECKPOINT & RESUME

Nếu context > 80% / phiên hết:

1. **STOP** sau finding hiện tại completed
2. **Update** plan file với status (DONE/IN_PROGRESS/PENDING per finding)
3. **Commit** WIP `wip: pause at F0X.0YY, resume from {next finding}`
4. **Note** memory entry + audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `docs/wf-fix-bugs-audit-2026-05-15.md` |
| Findings templates | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-07-templates.md` |
| Findings cross-refs | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-04-cross-references.md` |
| Templates dir wf-fix-bugs | `.claude/skills/workflow/wf-fix-bugs/templates/` |
| Templates dir _shared | `.claude/skills/workflow/_shared/lane/templates/` |
| Templates dir wf-fix-triage | `.claude/skills/workflow/wf-fix-triage/templates/` |
| Templates dir wf-fix-execute | `.claude/skills/workflow/wf-fix-execute/templates/` |
| Compliance audit | `./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs` |
| Schema sync | `./.claude/scripts/validate-schema-sync.sh wf-fix-bugs` |
| Sprint 0+1 Closed details | `docs/wf-fix-bugs-audit-2026-05-15.md §Sprint 0 + Sprint 1 Closed` |
| Sprint 2 Closed details | `docs/wf-fix-bugs-audit-2026-05-15.md §Sprint 2 Closed` |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Sửa nhiều findings 1 commit (trừ logical pattern fix như XF-04 STRIP pattern apply cùng pattern)
- ❌ Refactor templates ngoài fix yêu cầu (BHV-003)
- ❌ Thêm fields/sections ngoài audit recommendation (BHV-002)
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Bypass pre-commit hooks (`--no-verify`)
- ❌ Modify `.mc-data/` runtime files
- ❌ Tự chọn decision points §3 khi ambiguous — LUÔN AskUserQuestion
- ❌ Delete legacy templates without archive (move to `archive/` subdirectory)

## 10. SPRINT 0+1+2 CONTEXT (đã DONE)

**Sprint 0** (Quick-Wins, 14 items): 1 commit `310797e3`
**Sprint 1** (Critical Pipeline Blockers, 9 items): 9 commits — XF-05, XF-01, F03.015, F05.001, F05.002, F06.002, XF-06 PARTIAL, F04.003, F04.002
**Sprint 2** (Error Code Namespace, subset 5 items): 5 commits — F04.007, XF-02 PARTIAL (Phase 4 cross-phase + Phase 1 rename), F03.008, F03.020

**Tổng đã DONE:** 21 commits, ~12.5h actual, 23 findings closed.

**Deferred sang Sprint 4+:**
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- XF-02 Step 3-5 (E010/E013 dual-use, wf-fix-integration E099-E106)
- Sprint 4-8 plan từ original audit

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + audit report + findings-07/04, rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `z:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + audit + findings detail
   - Hỏi 4 câu xác nhận (scope, git, decision strategy, preflight)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-3-templates.md`
   - Thực hiện 10 findings theo §2 quy trình
   - Hỏi user 5 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 3 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **5 decision points** §3 yêu cầu user input (canonical choices)
- Có **safety guardrails** §4 Quality Gates
- Có **resume mechanism** §7 nếu phiên hết
- Tích hợp **memory entry** cho cross-session continuity
- Prompt size ~9KB — fit comfortably trong phiên mới

## Khuyến nghị thực thi

- **Recommend:** Mở phiên mới + paste prompt + để Claude tự AskUserQuestion 4 câu mở đầu
- **Alternative:** Nếu cần làm gấp + scope nhỏ, paste prompt với suffix "Chỉ làm 3 items đầu (XF-04 + XF-03 + F07.011)" → ~3.5h
