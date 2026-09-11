# Prompt: Thực hiện Sprint 8 — Bash Scripts Hardening (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 8 — Bash Scripts Hardening** của plan v10.3 dựa trên Sprint 7 closure 2026-05-15. Sprint 0-7 đã hoàn thành (Sprint 7: 4 commits, Python coverage 73.18% → 81.75% PASS, fail_under=80 restored).

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project (Lệnh Thường Dùng, scripts/ cấu trúc)
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-023, CORE-025, CORE-035 (Atomic Write)
4. **`plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md`** §"Sprint 7 — Bash Scripts Hardening" — 8 findings F05.003-024
5. **`plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md`** §"DONE" — confirm Sprint 7 closed
6. **`.claude/scripts/wf-fix-common.sh`** — shared helpers (read trước khi sửa)

**Quy tắc tuyệt đối:**

- ✅ **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ **BHV-002** (Simplicity First): KHÔNG refactor production scripts ngoài scope finding
- ✅ **BHV-003** (Surgical Changes): mỗi finding → diff tối thiểu để đạt mục tiêu
- ✅ **BHV-004** (Goal-Driven Execution): DONE = tất cả 8 findings áp dụng + smoke tests pass
- ✅ Tiếng Việt cho commits/docs; English cho code/test names/paths
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — pattern Sprint 6+7 (audit drifts có thể tồn tại)
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG thay đổi behavior đã có nếu finding chỉ yêu cầu safety wrapper
- ❌ KHÔNG chạy probe scripts thực tế trong test environment (chỉ syntax check + lint)

## 1. MỤC TIÊU SPRINT 8

**Scope:** ~4h effort, 8 findings F05.* hardening cross-platform safety + observability cho bash scripts.

**Findings list (theo ưu tiên):**

| # | Finding | Mô tả | File | Effort |
|---|---------|-------|------|--------|
| 1 | **F05.003** | `acquire_lock()` heredoc → `jq -n --arg` JSON build (Windows domain `DOMAIN\user` safe) | `wf-fix-common.sh` | 30min |
| 2 | **F05.004** | `wf-fix-report-builder.sh` atomic write pattern (tmp → rename) | `wf-fix-report-builder.sh` | 30min |
| 3 | **F05.005** | `wf-fix-baseurl-conflict-check.sh` `jq -n` thay shell concat | `wf-fix-baseurl-conflict-check.sh` | 20min |
| 4 | **F05.006** | `atomic_write_json` dùng `mktemp` thay `.tmp.$$.$RANDOM` ($RANDOM 15-bit collision) | `wf-fix-common.sh` | 30min |
| 5 | **F05.007** | `wf-fix-ci-batch.sh` `dirname "$0"` → `${BASH_SOURCE[0]}` (sourced safe) | `wf-fix-ci-batch.sh` | 15min |
| 6 | **F05.009** | Thêm ERR trap helper vào `wf-fix-common.sh`, enable trong critical scripts | `wf-fix-common.sh` + 2-3 critical scripts | 45min |
| 7 | **F05.024** | `wf-fix-lane-to-bus.py`: thêm `"QD11"` vào VALID_DIMS + KeyboardInterrupt + BrokenPipeError handlers | `wf-fix-lane-to-bus.py` | 20min |
| 8 | **F05.011** | Batch-move `set -euo pipefail` lên **dòng 2** trong 26 probe scripts (`wf-fix-probe-*.sh`) | 26 probe scripts | 30min |

**Tổng estimate:** ~3h45min effort + 30min audit/closure = ~4h15min.

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. **Đọc Sprint 7 closure** trong audit + plan file
2. **VERIFY baseline (BHV-001):**
   - `bash run-tests.sh` → confirm 81.75% PASS (Sprint 7 coverage gate)
   - `ls .claude/scripts/wf-fix-*.sh | wc -l` → đếm script files (smoke check)
   - `grep -n "acquire_lock\|atomic_write_json\|trap.*ERR" .claude/scripts/wf-fix-common.sh` → confirm functions tồn tại
   - `head -3 .claude/scripts/wf-fix-probe-*.sh | head -90` → kiểm tra 26 probe scripts có vi phạm `set -euo` thật không
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-8-bash-hardening.md` theo pattern Sprint 7:
   - 8 findings + per-finding fix strategy + smoke test
   - Acceptance: `shellcheck` clean (nếu installed); manual smoke pass cho mỗi script edited
4. **TodoWrite:** 9-10 todos chính (1 verify baseline + 8 findings + 1 closure)

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** file hiện tại — locate vùng cần sửa
2. **VERIFY drift:** so sánh audit description với code thực tế. Nếu finding đã fix sẵn (false positive như Sprint 6 F06.006/F06.013) → DOCUMENT only, KHÔNG action
3. **APPLY fix surgical:**
   - F05.003: replace heredoc với `jq -n --arg host "$HOSTNAME" --arg user "$USERNAME" '{host:$host,user:$user,...}'`
   - F05.004: wrap write site với atomic pattern (`tmp_fd=$(mktemp ...) && mv $tmp_fd $target`)
   - F05.005: Tương tự F05.003 với `jq -n`
   - F05.006: thay `${TEMP_FILE}.tmp.$$.$RANDOM` → `mktemp "${TEMP_FILE}.XXXXXX"`
   - F05.007: `dirname "$0"` → `dirname "${BASH_SOURCE[0]}"` (sourced-safe)
   - F05.009: define `_err_trap()` trong common.sh, add `trap _err_trap ERR` trong critical scripts
   - F05.024: thêm `"QD11"` vào VALID_DIMS list + wrap main() với `try/except (KeyboardInterrupt, BrokenPipeError):`
   - F05.011: viết script `scripts/move-set-euo-line2.sh` để batch process 26 files (idempotent — chỉ move nếu vi phạm)
4. **SMOKE test:**
   - `bash -n <script>` syntax check
   - `shellcheck <script>` (nếu installed) — không xuất hiện new warning
   - Functional smoke: gọi 1 helper từ script (vd `acquire_lock` test) trong subshell
5. **Commit per finding** (hoặc gộp 2-3 fixes nhỏ):
   ```
   fix(_scripts/<file>): F05.<NN> <mô tả ngắn> [F05-<NN>]

   Audit: plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md F05.<NN>
   Smoke: bash -n + shellcheck PASS
   ```

### 2.3 Post-Sprint

1. **Final verify:**
   - `bash run-tests.sh` PASS (regression check Python tests)
   - Smoke run: `bash .claude/scripts/wf-fix-common.sh` source check + 1 dummy session lock acquire
   - `git diff --stat HEAD~8 HEAD` → confirm scope đúng (chỉ scripts)
2. **Update audit report:** append "Sprint 8 Closed YYYY-MM-DD" section
3. **Update plan file:** status DONE per finding
4. Recommend Sprint 9:
   - **Sprint 9 — Procedure Logic + Cleanup (~4h)**: F08.015-022, F03.014

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 F05.011 batch script approach

26 probe scripts cần move `set -euo pipefail` line 2:
1. **Script đơn `move-set-euo-line2.sh`** — sed in-place + dry-run mode (recommended)
2. **Manual edit từng file** — chậm hơn nhưng safer
3. **Skip nếu < 5 vi phạm** — verify drift trước (audit có thể overcount)

### 3.2 F05.009 ERR trap scope

Critical scripts nào nên add `trap _err_trap ERR`?
1. **Tất cả entry-point scripts** (wf-fix-flow-driver.sh, wf-fix-record-probe-failure.sh, wf-fix-ci-batch.sh) — thorough
2. **Chỉ wf-fix-common.sh + auto-trap khi sourced** — minimal change
3. **User chọn 3-5 scripts theo blast-radius** — pragmatic

### 3.3 F05.006 mktemp template

`mktemp` template format:
1. **`mktemp "${TARGET}.XXXXXX"`** — Linux/macOS standard, Windows Git Bash hỗ trợ
2. **`mktemp -p "$(dirname "$TARGET")" "$(basename "$TARGET").XXXXXX"`** — explicit dir, safer
3. **Custom helper `make_tmp_in_dir()` trong common.sh** — DRY, testable

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Sau fix, `bash run-tests.sh` regression FAIL — rollback fix gần nhất
- ❌ `shellcheck` báo new SC2086/SC2068 (word splitting) — fix proper quoting
- ❌ Decision point §3 có ≥2 valid options
- ❌ Finding "drift detected" (audit description không khớp code thực tế) — document + skip action

## 5. COMPLETION CRITERIA

Sprint 8 DONE khi:

✅ 8 findings F05.003-024 đã apply (hoặc document drift)
✅ `bash run-tests.sh` vẫn PASS coverage 80%+ (regression check)
✅ `bash -n` clean cho mọi script edited
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-8-bash-hardening.md` DONE
✅ Audit report append "Sprint 8 Closed YYYY-MM-DD"
✅ 8-10 commits trên master (per finding hoặc nhóm)

## 6. KHỞI ĐỘNG

1. Đọc context (§0) + Sprint 7 closure (audit + plan)
2. **VERIFY baseline:**
   - `bash run-tests.sh` PASS 81.75%
   - Inspect 5-6 target scripts (common.sh, report-builder, baseurl, ci-batch, lane-to-bus, 1-2 probe scripts)
3. **`AskUserQuestion` 3 câu xác nhận:**
   - "Confirm scope Sprint 8 (8 F05 findings ~4h)?"
   - "Git permissions: commit trên master như Sprint 7?"
   - "Decision points §3 batch confirm trước hay hỏi từng finding?"
4. Tạo plan file + TodoWrite + start execute

## 7. CHECKPOINT & RESUME

Sprint 8 ~4h — single session khả thi. Nếu context > 80%:

1. **STOP** sau finding hiện tại completed
2. **Update** plan file status
3. **Commit** WIP `wip: pause at F05.NNN, resume from next`
4. **Note** audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 7 closure | §"Sprint 7 Closed — 2026-05-15" trong audit |
| Sprint 8 scope | §"Sprint 7 — Bash Scripts Hardening" (đánh số sai trong audit, thực ra là Sprint 8 theo numbering linear) |
| Test runner | `cd .claude/skills/workflow/_shared && bash run-tests.sh` |
| Bash syntax check | `bash -n <script>` |
| Shellcheck (optional) | `shellcheck <script>` |
| Common helpers | `.claude/scripts/wf-fix-common.sh` (acquire_lock, atomic_write_json, ...) |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Refactor `wf-fix-common.sh` ngoài scope F05 findings (BHV-003)
- ❌ Sửa probe script behavior (chỉ move `set -euo` lên line 2 — F05.011)
- ❌ Add new dependencies (jq version, bash version) — match existing requirements
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (pattern Sprint 3+4+5+6+7)
- ❌ Modify `.mc-data/` runtime files
- ❌ Run probe scripts thực tế trong test (chỉ smoke `bash -n` + dry-run helpers)

## 10. SPRINT 0+1+2+3+4+5+6+7 CONTEXT (đã DONE)

**Tổng đã DONE qua 7 sprints:** 55+ commits, ~36h actual.

**Sprint 7 final (2026-05-15):**
- Coverage: 73.18% → 81.75% (+8.57pp), 1015 tests pass (+150)
- 4 commits, fail_under=80 restored
- 3 modules uplift: builder 86.90%, isg_recommender 96.01%, lane_dispatch 70.43%
- Async path lane_dispatch deferred (không gating 80%)

**Deferred sang Sprint 9+:**
- Sprint 9 — Procedure Logic + Cleanup (~4h): F08.015-022, F03.014
- (Optional) Sprint 10 — lane_dispatch async path coverage uplift (~3h)
- XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema` (out-of-scope)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + Sprint 7 closure audit + plan file, VERIFY baseline (`bash run-tests.sh` PASS 81.75%), rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + Sprint 7 closure
   - VERIFY baseline (coverage 81.75%, tests pass)
   - Hỏi 3 câu xác nhận (scope, git, decision strategy)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-8-bash-hardening.md`
   - Thực hiện 8 findings theo §2 quy trình
   - Hỏi user 3 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 8 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **3 decision points** §3 yêu cầu user input (batch script approach, ERR trap scope, mktemp template)
- Có **safety guardrails** §4 Quality Gates
- Có **resume mechanism** §7 — Sprint 8 ~4h single-session khả thi
- **Khác Sprint 7:** Sprint 8 focus 100% vào BASH SCRIPT SAFETY (không có Python tests)
- Prompt nhấn mạnh **không sửa probe behavior** + **không refactor common.sh ngoài scope** (BHV-003)

## Khuyến nghị thực thi

- **Single session feasible** (~4h): không cần split
- **High-risk fix:** F05.011 batch 26 probe scripts — phải dry-run trước, verify line numbers chính xác
- **Fallback:** Nếu drift detected ≥3 findings (audit overcount), document + skip; commit closure với coverage findings reduction
- **Verify regression:** Sau mỗi 2-3 fixes, chạy `bash run-tests.sh` smoke (~5min) để catch sớm
