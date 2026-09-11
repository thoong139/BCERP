# Prompt: Thực hiện Fix `wf-fix-bugs` v10.2.1 → v10.3 (Phiên mới)

> **Cách dùng:** Mở phiên Claude Code mới tại `z:\Working\MCV3`, copy toàn bộ nội dung bên dưới (giữa hai dòng `===PROMPT START===` và `===PROMPT END===`) và paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện sprint sửa lỗi cho skill `wf-fix-bugs` v10.2.1 → v10.3 dựa trên báo cáo audit đã hoàn thành ngày 2026-05-15.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm bất cứ điều gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project + Lệnh thường dùng + Cấu trúc
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004 (4 nguyên tắc hành vi)
3. **`.claude/rules/00-core.md`** — CORE-001 đến CORE-038 (đặc biệt CORE-031, CORE-032, CORE-034, CORE-036)
4. **`docs/wf-fix-bugs-audit-2026-05-15.md`** — báo cáo audit đầy đủ (166 findings, 29 CRITICAL)
5. **`.mc-data/audit/wf-fix-bugs-2026-05-15/findings-{01-08}-*.md`** — chi tiết per-facet (đọc khi cần deep-dive)

**Quy tắc tuyệt đối:**

- ✅ Áp dụng **BHV-001** (Hỏi trước khi giả định): findings nào ambiguous → DỪNG hỏi user (`AskUserQuestion`), KHÔNG tự suy diễn
- ✅ Áp dụng **BHV-003** (Surgical Changes): CHỈ sửa đúng issue, KHÔNG refactor xung quanh, KHÔNG "improve" code không liên quan
- ✅ Tiếng Việt cho commits/docs/comments; English cho code/paths
- ✅ **KHÔNG sửa nhiều issues cùng một edit** — mỗi finding 1 commit hoặc 1 logical unit
- ✅ Dùng **Serena tools** cho symbolic editing code (`find_symbol`, `replace_symbol_body`, `insert_before_symbol`) — không dùng Edit thuần khi có thể
- ✅ Dùng **GitNexus** `impact()` TRƯỚC mỗi sửa symbol public (cảnh báo HIGH/CRITICAL → hỏi user)
- ❌ KHÔNG skip verification steps
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` để bypass hooks

## 1. MỤC TIÊU SPRINT

**Tổng:** 8 sprints + 14 quick-wins, ước tính **~56.5h effort** để đạt PRODUCTION-READY status.

**Priority order (BẮT BUỘC theo thứ tự):**

| Sprint | Tên | Effort | Mục tiêu |
|---|---|---|---|
| 0 | Quick-Wins | ~3.5h | 14 typo/sync fixes (xem báo cáo §Quick-Win Backlog) |
| 1 | **CRITICAL Pipeline Blockers** | ~8h | 9 issues block pipeline runtime |
| 2 | Error Code Namespace Cleanup | ~6h | CORE-034 compliance |
| 3 | Template + Schema Compliance | ~7h | CORE-031 + CORE-036 |
| 4 | SKILL.md ≤500 dòng + Architecture | ~8h | CORE-032 |
| 5 | Agent Spawn Quality | ~4h | CORE-037 8 sections |
| 6 | Python Runtime + Coverage | ~12h | Coverage gate 80% |
| 7 | Bash Scripts Hardening | ~4h | Cross-platform safety |
| 8 | Procedure Logic + Cleanup | ~4h | DRY + organization |

## 2. QUY TRÌNH TỪNG SPRINT

Áp dụng cho mọi sprint:

### 2.1 Pre-Sprint

1. **Đọc** section Sprint tương ứng trong `docs/wf-fix-bugs-audit-2026-05-15.md`
2. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-{N}-{name}.md` với:
   - Mục tiêu
   - Danh sách finding IDs (F0X.0YY)
   - Files sẽ sửa
   - Acceptance criteria per finding
   - Verification command(s)
3. **TodoWrite**: tạo todos = 1 todo / 1 finding
4. **Tạo branch nếu chưa có:** `git checkout -b wf-fix-bugs-v10.3-sprint-{N}`

### 2.2 Per-Finding Loop

Cho mỗi finding F0X.0YY:

1. **READ** chi tiết từ `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-0X-*.md`
2. **VERIFY current state**:
   - Dùng `Read` / `Grep` / `find_symbol` để confirm vấn đề tồn tại
   - Nếu không reproducible → cập nhật finding status → SKIP
3. **Impact analysis** (đặc biệt cho fixes touch public symbols):
   - GitNexus `impact({target: "symbol", direction: "upstream"})` nếu sửa shared/code
   - Cảnh báo HIGH/CRITICAL → `AskUserQuestion` xác nhận trước khi tiến hành
4. **Apply fix**:
   - Code files: Serena `replace_symbol_body` / `insert_*_symbol` / `replace_content`
   - Docs/templates: Edit tool
   - JSON contracts: jq build + atomic mv pattern
5. **Verify fix**:
   - Re-grep / re-read confirm changes
   - JSON files: `jq '.' file.json` validate
   - Schema sync (nếu sửa contract): `./.claude/scripts/validate-schema-sync.sh {skill}`
   - Skill compliance (nếu sửa SKILL.md): `./.claude/scripts/skill-compliance-audit.sh {skill}`
6. **Run targeted tests**:
   - Python `_shared/` changes → `cd .claude/skills/workflow/_shared && ./run-tests.sh --module={mod}`
   - Bash scripts → smoke test trong `.claude/scripts/tests/`
   - Templates → render dry-run
7. **Update TodoWrite**: mark completed
8. **Commit**: `git add` chỉ files liên quan + message format:
   ```
   fix({scope}): {one-line summary} [F0X.0YY]
   
   {2-3 dòng giải thích Vietnamese}
   
   Audit: docs/wf-fix-bugs-audit-2026-05-15.md F0X.0YY
   ```

### 2.3 Post-Sprint

1. **Re-run full validation suite**:
   ```bash
   ./.claude/scripts/skill-compliance-audit.sh --all
   ./.claude/scripts/validate-schema-sync.sh --all
   ./.claude/scripts/validate-pipeline-naming.sh
   cd .claude/skills/workflow/_shared && ./run-tests.sh --fast
   ```
2. **Update plan file** với status DONE per finding
3. **Cập nhật báo cáo audit**: append section "Sprint {N} Closed" với ngày + commits
4. **Hỏi user**: tiếp tục Sprint {N+1} hay nghỉ?

## 3. CRITICAL ISSUES (Sprint 1) — Chi tiết

Đây là 9 issues phải fix TRƯỚC, không skip:

### 3.1 XF-05 — Phase 3 PRE-GATE jq path bug (5 min)
**File:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase3-plan.md`
**Issue:** `jq -e '.total_files > 0'` trả null vì schema thực là `{code: {total_files}, docs: {}}`
**Fix:** Đổi thành `jq -e '.code.total_files > 0'`
**Verify:** `jq -e '.code.total_files > 0' .claude/skills/workflow/wf-fix-bugs/templates/phase2-scan/scope-analysis.json` (nếu template có data) hoặc grep confirm

### 3.2 XF-01 — fix-impact schema version sync (15 min)
**Files:**
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase7-verify.md` (Steps 7.7, 7.11)
- Verify: `.claude/skills/workflow/wf-fix-bugs/_contract.json` §produces_for
- Verify: `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/fix-impact.json`

**Issue:** procedure emit `fix-impact-v2` nhưng contract + template + 3 consumers dùng `fix-impact-v1`
**Fix:** Đổi `fix-impact-v2` → `fix-impact-v1` trong phase7-verify.md (2 chỗ)
**Verify:** `grep -r "fix-impact-v" .claude/skills/workflow/wf-fix-bugs/` → tất cả đều v1

### 3.3 F03.015 — Phase 4 monitor loop glob path (30 min)
**File:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md` Step 4.6
**Issue:** Pattern `$dim-*/lane-status.json` không match actual dir `QD1-functional/`
**Fix:** Đổi thành `$dim/lane-status.json` (không suffix wildcard)
**Verify:** Test với mock session dir: `ls $session/phase4-find-bugs/lanes/QD*/lane-status.json` should match

### 3.4 F05.001 — Conflicting `set` declarations (15 min)
**Files:**
- `.claude/scripts/wf-fix-flow-driver.sh`
- `.claude/scripts/wf-fix-record-probe-failure.sh`

**Issue:** Dòng 26 `set -uo pipefail` ghi đè dòng 2 `set -euo pipefail` → mất `-e`
**Fix:** Xóa hoàn toàn dòng 26 trong cả 2 files
**Verify:** `grep -n "^set " .claude/scripts/wf-fix-flow-driver.sh .claude/scripts/wf-fix-record-probe-failure.sh` → mỗi file chỉ 1 line

### 3.5 F05.002 — Conditional source common.sh (1h)
**Files (6 probe scripts):**
- `wf-fix-probe-contract-drift.sh:52`
- `wf-fix-probe-playwright-axe.sh:29`
- `wf-fix-probe-playwright-cwv.sh:31`
- `wf-fix-probe-static-compat.sh:22`
- `wf-fix-probe-static-sast.sh:18`
- `wf-fix-probe-static-schema-drift.sh:27`

**Issue:** `[[ -f "$SCRIPT_DIR/wf-fix-common.sh" ]] && source ...` silently skip
**Fix:** Đổi thành pattern explicit (giống `wf-fix-phase0-init.sh`):
```bash
COMMON_SH="$SCRIPT_DIR/wf-fix-common.sh"
[ -f "$COMMON_SH" ] || { echo "ERROR: wf-fix-common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"
```
**Verify:** `for f in {6 files}; do bash -n "$f"; done` syntax check pass

### 3.6 F06.002 — signal_aggregator dead code return (10 min)
**File:** `.claude/skills/workflow/_shared/signal_aggregator.py:408`
**Issue:** `return 0 if not stats.errors else 0` — cả 2 nhánh return 0
**Fix:** Quyết định behavior:
- Option A (conservative): `return 0` thuần (drop ternary)
- Option B (correct): `return 1 if stats.errors else 0` (errors = exit 1)

→ Hỏi user nếu unclear; mặc định Option B + add test case

**Verify:** `cd .claude/skills/workflow/_shared && python -m pytest tests/test_signal_aggregator.py -v`

### 3.7 XF-06 — session-log.json format standardization (2h)
**File:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase2-scan.md` Step 2.2 + verify Phases 1, 3, 4, 5, 7

**Issue:** Phase 2 dùng `>> file` (JSONL); Phase 6 dùng `jq '. + [...]'` (JSON array)
**Fix:** Standardize JSON array atomic write theo `_shared.md §7`:
```bash
TMP="${SESSION_LOG}.tmp.$$"
jq --arg ts "$(date -Iseconds)" --arg ev "TRACE_START" --arg phase "phase2" \
   '. + [{"ts": $ts, "event": $ev, "phase": $phase}]' "$SESSION_LOG" > "$TMP" \
   && mv "$TMP" "$SESSION_LOG"
```
**Apply to:** Phases 1, 2, 3, 4, 5, 6, 7 — verify all dùng cùng pattern
**Verify:** `grep -E "session-log.json" .claude/skills/workflow/wf-fix-bugs/procedures/phase*.md` audit format consistency

### 3.8 F04.003 — Missing scripts wf-fix-execute references (1.5h)
**File:** `.claude/skills/workflow/wf-fix-execute/SKILL.md:245,252,255`
**Missing scripts:**
- `bash .claude/scripts/wf-fix-step-verify.sh`
- `bash .claude/scripts/wf-fix-record-process-violation.sh`

**Quyết định trước khi fix:**
- Option A: Tạo 2 scripts mới (cần read SKILL.md để hiểu functionality)
- Option B: Thay bằng `wf-fix-validate-gate.sh` (đã tồn tại, có T1-T4)

→ `AskUserQuestion` user chọn Option

### 3.9 F04.002 — Stale template paths trong phase2-triage.md (15 min)
**File:** `.claude/skills/workflow/wf-fix-triage/procedures/phase2-triage.md:123,125`
**Issue:** Trỏ `wf-fix-execute/templates/fix-plan.md` + `fix-log.json` đã migrate
**Fix:** Đổi thành `../_shared/lane/templates/fix-plan.md` + `fix-log.json`
**Verify:** `test -f .claude/skills/workflow/_shared/lane/templates/fix-plan.md && test -f .claude/skills/workflow/_shared/lane/templates/fix-log.json`

## 4. QUICK-WINS — Sprint 0 (Optional song song với Sprint 1)

14 fixes ≤30 min mỗi cái, có thể batch trong 1 commit:

| # | Finding | File | Action |
|---|---|---|---|
| Q1 | F01.006 | `wf-fix-runtime-health/SKILL.md` | version 1.0.0 → 1.1.0, last_updated 2026-05-14 |
| Q2 | F01.012 | 5 lane skills (functional/business/security/performance/compat) | sed `orchestrator v9.x` → `v10.x` |
| Q3 | F01.011 | 5 lane skills | last_updated 2026-04-28 → 2026-05-15 |
| Q4 | F01.018 | 3 skills (observability/runtime-health/business-completeness) | Strip double blank trong frontmatter description |
| Q5 | F05.024 | `wf-fix-lane-to-bus.py:37` | Add `"QD11"` vào VALID_DIMS frozenset |
| Q6 | F05.022 | `wf-fix-migrate-sessions.sh:73` | `grep '^#'` → `sed -n '2,36p'` |
| Q7 | F05.023 | `wf-fix-record-probe-failure.sh:30` | `.` → `source` |
| Q8 | F07.020 | `wf-fix-triage/templates/bug-triage.md` | Tiếng Việt không dấu → có dấu |
| Q9 | F07.022 | `wf-fix-bugs/templates/_common/session-log.json` | Parameterize `"version": "10.0.0"` → `"{{SKILL_VERSION}}"` |
| Q10 | F08.025 | Audit reports trong procedures/ | Đổi `D:\` → `z:\` (hoặc move sang .mc-data) |
| Q11 | F08.030 | `path-audit-report.md` + `phase2-scan-audit-report.md` | `mv` từ procedures/ sang `.mc-data/audit/` |
| Q12 | F01.013 | `wf-fix-performance/SKILL.md` | Description "6 probes" → "7 probes" |
| Q13 | F01.014 | `wf-fix-functional/SKILL.md` Related Skills | Add 4 rows QD8-QD11 |
| Q14 | F01.015 | `wf-fix-business/SKILL.md` + `wf-fix-business-completeness/SKILL.md` Output table | Remove `phase-summary.md` row (note đã ghi không còn tạo) |

**Commit gộp:** `chore: 14 quick-win fixes from audit 2026-05-15 [Q1-Q14]`

## 5. QUALITY GATES

DỪNG và `AskUserQuestion` nếu gặp:

- ❌ GitNexus impact analysis report **CRITICAL** blast radius cho fix
- ❌ Audit finding nội dung mâu thuẫn với code thực tế (audit có thể stale)
- ❌ Fix requires breaking change cho consumer skills (wf-verify-sync, wf-prepare-deployment, wf-implement-feature)
- ❌ Test suite FAIL sau fix > 1 retry
- ❌ Schema-sync validation FAIL không tự fix được
- ❌ Context budget > 80% (checkpoint per CORE-038)
- ❌ Cần extend timeline > estimate +50%

## 6. COMPLETION CRITERIA

Sprint được coi DONE khi:

✅ Tất cả findings trong sprint mark `completed` trong TodoWrite
✅ `skill-compliance-audit.sh --all` → no NEW errors
✅ `validate-schema-sync.sh --all` → no NEW errors
✅ Targeted tests pass cho files modified
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-{N}-*.md` cập nhật status
✅ Commits có message format chuẩn + tham chiếu finding IDs
✅ Báo cáo audit `docs/wf-fix-bugs-audit-2026-05-15.md` append "Sprint {N} Closed YYYY-MM-DD"

## 7. KHỞI ĐỘNG

Bắt đầu bằng cách:

1. Activate Serena: `mcp__serena__check_onboarding_performed`
2. Đọc CLAUDE.md + 2 rule files + audit report (như §0)
3. `AskUserQuestion`:
   - **"Bắt đầu Sprint 0 (Quick-Wins) hay Sprint 1 (Critical) trước?"** → Recommend Sprint 0 + Sprint 1 song song (ít risk, max throughput)
   - **"Có quyền tạo branch + commit không?"** → Confirm trước khi git operations
   - **"Phạm vi phiên này (Sprint nào tới sprint nào)?"** → Có thể không làm hết 8 sprints trong 1 phiên

4. Tạo plan files + TodoWrite + start execute theo §2

## 8. CHECKPOINT & RESUME

Nếu phiên hết / context > 80%:

1. **STOP** sau finding hiện tại completed (không bỏ dở giữa fix)
2. **Update** plan file với status hiện tại (DONE/IN_PROGRESS/PENDING per finding)
3. **Commit** WIP state với message `wip: pause at F0X.0YY, resume from {next finding}`
4. **Note** vào báo cáo audit + memory entry cho phiên sau:
   ```
   /remember "wf-fix-bugs v10.3 sprint progress: Sprint X done, Sprint Y in_progress at FZZ.ZZZ. Resume: plans/wf-fix-bugs-v10-3-audit/sprint-Y-*.md"
   ```

## 9. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `docs/wf-fix-bugs-audit-2026-05-15.md` |
| Findings chi tiết | `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-{01-08}-*.md` |
| Standards | `.claude/rules/00-core.md`, `00-behavioral.md` |
| Protocol | `.claude/skills/protocols/` |
| Compliance audit | `./.claude/scripts/skill-compliance-audit.sh` |
| Schema sync | `./.claude/scripts/validate-schema-sync.sh` |
| Python tests | `cd .claude/skills/workflow/_shared && ./run-tests.sh` |
| Plan output | `plans/wf-fix-bugs-v10-3-audit/sprint-{N}-{name}.md` |

## 10. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Sửa nhiều findings 1 commit (trừ Sprint 0 Quick-Wins gộp)
- ❌ Refactor code không liên quan đến finding (BHV-003)
- ❌ Thêm features/abstractions ngoài fix yêu cầu (BHV-002)
- ❌ Skip Quality Gates §5
- ❌ Force-push branches có commits đã share
- ❌ Bypass pre-commit hooks (`--no-verify`)
- ❌ Modify `.mc-data/` runtime files trừ khi document trong audit
- ❌ Tự chọn Option khi finding có ambiguity → LUÔN hỏi user

---

**Bắt đầu ngay:** Đọc CLAUDE.md + audit report + rules, rồi `AskUserQuestion` về scope phiên này.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `z:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + audit report
   - Hỏi 3 câu xác nhận scope (Sprint 0/1, git permissions, phạm vi phiên)
   - Tạo plan files trong `plans/wf-fix-bugs-v10-3-audit/`
   - Thực hiện sprint theo quy trình §2 + checkpoint §8

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên này
- Có **safety guardrails** — hỏi user tại mỗi decision point
- Có **resume mechanism** — nếu phiên hết, có thể tiếp tục phiên sau
- **Modular**: có thể chạy chỉ Sprint 1, hoặc Sprint 0+1, hoặc toàn bộ
- Tích hợp **memory entry** để chia sẻ trạng thái giữa các phiên
