# Prompt: Thực hiện Sprint 7 — Coverage 80% Target (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 7 — Python Coverage 80% Target** của plan v10.3 dựa trên Sprint 6 closure 2026-05-15. Sprint 0-6 đã hoàn thành với 51+ commits trên master (Sprint 6: 14 commits, coverage 58.77% → 73.18%).

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project (đặc biệt section "Lệnh Thường Dùng" — `./run-tests.sh`, coverage gate hiện = 70%)
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-025 (Parallel Safety), CORE-035 (Atomic Write), CORE-038 (Context Budget)
4. **`plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md`** §"Sprint 6 Closed" — kết quả Sprint 6 + Sprint 7 pending modules
5. **`plans/wf-fix-bugs-v10-3-audit/sprint-6-python-coverage.md`** §"Sprint 7 Recommended Scope" — 3 modules target
6. **`.claude/skills/workflow/_shared/pyproject.toml`** — fail_under hiện = 70, target 80
7. **`.claude/skills/workflow/_shared/run-tests.sh`** — test runner

**Quy tắc tuyệt đối:**

- ✅ **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ **BHV-002** (Simplicity First): KHÔNG add tests chỉ để inflate coverage; mỗi test PHẢI verify behavior thật
- ✅ **BHV-003** (Surgical Changes): KHÔNG refactor production để dễ test hơn
- ✅ **BHV-004** (Goal-Driven Execution): DONE = coverage gate PASS ≥80% (verify `./run-tests.sh` PASS với `fail_under=80`)
- ✅ Tiếng Việt cho commits/docs; English cho code/test names/paths
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — Sprint 6 đã phát hiện 5 audit drifts; tiếp tục pattern này
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG inflate coverage bằng cách add omit list trừ khi user approve qua AskUserQuestion
- ❌ KHÔNG tests cho code không có ai dùng (BHV-002)
- ❌ KHÔNG refactor production code chỉ để dễ test hơn (BHV-002 + BHV-003)

## 1. MỤC TIÊU SPRINT 7

**Scope:** ~13h effort, 3 modules cuối cùng để đạt coverage 80% PASS.

**State đã biết (verify lại khi bắt đầu):**

| Module | Sprint 6 end | Sprint 7 target | Effort | Miss focus |
|--------|-------------|-----------------|--------|-----------|
| `lane_dispatch.py` | 59.02% (246 miss / 648 stmts) | 80% (130 miss) | ~6h | async dispatch + subprocess + cache path |
| `impact_graph/builder.py` | 46.60% (140 miss / 289 stmts) | 80% (58 miss) | ~4h | graph construction, Python/TS import extraction |
| `isg/isg_recommender.py` | 72.84% (122 miss / 434 stmts) | 80% (87 miss) | ~3h | recommender ranking + scoring |

**Coverage gap calculation:**
- Total stmts (sau omit): 3522
- Hiện covered: 2627 (73.18%)
- Cần covered cho 80%: 2818
- Gap: +191 covered stmts

3 modules tổng miss giảm xuống: (130 + 58 + 87) = 275 miss, từ 508 hiện tại → giảm 233 miss → đạt 80% (191 cần + 42 buffer).

**Priority order:**

| # | Module | Strategy | Estimate | Status |
|---|--------|----------|----------|--------|
| 1 | **Baseline check** | Chạy `./run-tests.sh` → confirm 73.18% coverage + 865 tests pass | 15min | PENDING |
| 2 | **lane_dispatch async** | Mock asyncio.gather + subprocess. Tests: _run_lane_async, dispatch_lanes_async, _execute_lane_sequential retry, _execute_static_probe, _post_gate_lane | 6h | PENDING |
| 3 | **impact_graph/builder** | Build sample Python/TS source tree → test build_impact_graph, _extract_imports_python, _extract_imports_typescript, _graph_to_dict | 4h | PENDING |
| 4 | **isg_recommender** | Mock ISG dump → test recommend_priorities, _score_node, CLI subcommands | 3h | PENDING |
| 5 | **Final verify** | `./run-tests.sh` PASS với `fail_under=80` (update pyproject.toml). Audit + plan closure. | 30min | PENDING |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. **Đọc Sprint 6 closure** trong audit + plan file (đặc biệt §"Sprint 7 Recommended Scope")
2. **VERIFY baseline:**
   - `cd .claude/skills/workflow/_shared && bash run-tests.sh` → confirm PASS (fail_under=70, coverage 73%+)
   - `grep -n "^def \|^async def " .claude/skills/workflow/_shared/lane_dispatch.py | head -40`
   - `grep -n "^def " .claude/skills/workflow/_shared/impact_graph/builder.py | head -30`
   - `grep -n "^def " .claude/skills/workflow/_shared/isg/isg_recommender.py | head -30`
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md` theo pattern Sprint 6:
   - 3 modules + per-function tests planned
   - Acceptance: `./run-tests.sh` PASS với fail_under=80
4. **TodoWrite**: 5-8 todos chính

### 2.2 Per-Module Loop

Cho mỗi module:

1. **READ** module hiện tại — identify uncovered functions (xem coverage report missing lines)
2. **Categorize functions:**
   - **Easy** (pure functions, no I/O): test trực tiếp với tmp_path
   - **Medium** (file I/O, dataclass): test với tmp_path + fixtures
   - **Hard** (subprocess, async, network): mock với `unittest.mock.patch`
3. **Skip functions** nếu:
   - CLI entry duplicates main module logic (đã test ở core function)
   - Pure thin wrapper (gọi 1 hàm khác đã test)
   - Dead code (verify với `grep -r "<func_name>("`)
4. **Write tests** với docstring `"what + why"`. KHÔNG inflate.
5. **Verify** `./run-tests.sh --fast` pass smoke
6. **Commit** mỗi module 1 batch:
   ```
   test(_shared/<module>): XF-08 Sprint 7 coverage tests [XF-08]

   Module: <module>
   Coverage delta: A% → B% (+Cpp)
   Tests added: N cases (functions: X, Y, Z)

   Audit: docs/danglam/wf-fix-bugs-audit-2026-05-15.md Sprint 7
   ```

### 2.3 Post-Sprint

1. **Final coverage:** `bash run-tests.sh` với `fail_under=80`
2. **Update pyproject.toml:** `fail_under = 80` (restored từ 70)
3. **Update audit report:** append "Sprint 7 Closed YYYY-MM-DD" section
4. **Update plan file:** status DONE per module + coverage delta
5. Recommend next sprint:
   - **Sprint 8 — Bash Scripts Hardening (~4h)**: F05.003-007, F05.009, F05.024, F05.011
   - **Sprint 9 — Procedure Logic + Cleanup (~4h)**: F08.015-022, F03.014

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 lane_dispatch async tests strategy

Mock asyncio để tests deterministic, hay run actual asyncio?

1. **Mock asyncio.gather + subprocess.run** (recommended) — Fast, deterministic, isolate units.
2. **Run real asyncio + mock subprocess only** — Closer to production, slower.
3. **Skip async path, focus sequential** — Lose coverage points (asyncio.gather không bị test).

### 3.2 impact_graph/builder fixture strategy

Build sample source tree fixture cho test build_impact_graph?

1. **Inline strings** — Tạo .py/.ts files với contents inline trong test → simple, slow.
2. **fixtures/sample-projects/** directory — Persistent fixtures, reusable. Cần tạo + maintain.
3. **mock import extraction** — Bypass _extract_imports_* logic, test orchestrator only.

### 3.3 isg_recommender mock strategy

ISG dump format phức tạp. Mock strategy:

1. **Inline ISG dict** — Build fixture dict inline trong test.
2. **fixtures/isg-samples/** — Persistent JSON fixtures.
3. **Skip if 80% reached** — Nếu lane_dispatch + builder đủ đạt 80% → defer isg_recommender Sprint 8.

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Coverage gate vẫn FAIL < 80% sau effort hợp lý (>10h)
- ❌ Tests new flaky (intermittent fail)
- ❌ Production code phải refactor để test → reconsider scope
- ❌ Context budget > 80% — Sprint 7 ~13h dễ vượt 1 phiên
- ❌ Decision point §3 có ≥2 valid options

## 5. COMPLETION CRITERIA

Sprint 7 DONE khi:

✅ 3 modules có coverage uplift theo target (lane_dispatch 80%, builder 80%, isg_recommender 80%)
✅ `./run-tests.sh` PASS với `--cov-fail-under=80`
✅ `pyproject.toml` fail_under = 80 (restored)
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md` DONE
✅ Audit report append "Sprint 7 Closed YYYY-MM-DD"

## 6. KHỞI ĐỘNG

1. Đọc context (§0) + Sprint 6 closure
2. **VERIFY baseline:**
   - `bash run-tests.sh` → coverage 73.18% PASS fail_under=70
   - Inspect 3 module files để hiểu structure
3. **`AskUserQuestion` 3 câu xác nhận:**
   - "Confirm scope Sprint 7 (3 modules ~13h, target coverage 80%)?"
   - "Git permissions: commit trên master như Sprint 0-6?"
   - "Decision points §3 batch confirm trước hay hỏi từng module?"
4. Tạo plan file + TodoWrite + start execute

## 7. CHECKPOINT & RESUME

Sprint 7 ~13h — có thể cần multi-session. Nếu context > 80%:

1. **STOP** sau module hiện tại completed
2. **Update** plan file status
3. **Commit** WIP `wip: pause at <module>, resume from <next>`
4. **Note** audit report cho phiên sau

**Suggested split:**
- **Phiên 1 (~6-7h):** Baseline + lane_dispatch async tests
- **Phiên 2 (~6h):** impact_graph/builder + isg_recommender + final verify

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 6 closure | §"Sprint 6 Closed — 2026-05-15" trong audit |
| Sprint 7 scope | §"Sprint 7 Recommended Scope" trong `plans/wf-fix-bugs-v10-3-audit/sprint-6-python-coverage.md` |
| Test runner | `cd .claude/skills/workflow/_shared && bash run-tests.sh [--fast \| --module=<name>]` |
| Coverage config | `.claude/skills/workflow/_shared/pyproject.toml` |
| Tests Sprint 6 reference | `tests/test_*_xf08.py` (10 files, 209 cases pattern) |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Add tests chỉ để inflate coverage % (BHV-004) — mỗi test PHẢI verify behavior thật
- ❌ Refactor production code chỉ để dễ test hơn (BHV-002 + BHV-003)
- ❌ Add to omit list mà không user approve
- ❌ Commit test edit mà chưa chạy `./run-tests.sh --fast` smoke check
- ❌ Mock quá deep — nếu mock 5+ layers thì test fragile
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (pattern Sprint 3+4+5+6)
- ❌ Modify `.mc-data/` runtime files

## 10. SPRINT 0+1+2+3+4+5+6 CONTEXT (đã DONE)

**Tổng đã DONE qua 6 sprints:** 54+ commits, ~33h actual.

**Sprint 6 final:**
- Coverage: 58.77% → 73.18% (+14.41pp), 865 tests pass
- 14 commits, fail_under=70 tạm (target 80% sang Sprint 7)
- 5 audit drifts detected + corrected (BHV-001 protection)
- F06.x cluster + XF-08 partial complete

**Deferred sang Sprint 8+:**
- Sprint 8 — Bash Scripts Hardening (~4h): F05.003-007, F05.009, F05.024, F05.011
- Sprint 9 — Procedure Logic + Cleanup (~4h): F08.015-022, F03.014
- XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema` (out-of-scope)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + Sprint 6 closure audit + plan file §"Sprint 7 Recommended Scope", VERIFY baseline (`bash run-tests.sh` PASS), rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + Sprint 6 closure + Sprint 7 scope
   - VERIFY baseline (coverage 73%, tests pass)
   - Hỏi 3 câu xác nhận (scope, git, decision strategy)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md`
   - Thực hiện 3 modules theo §2 quy trình
   - Hỏi user 3 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 7 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **3 decision points** §3 yêu cầu user input (async mock strategy, fixture style, isg defer)
- Có **safety guardrails** §4 Quality Gates — đặc biệt coverage gate vẫn FAIL hoặc tests flaky
- Có **resume mechanism** §7 — Sprint 7 ~13h, ưu tiên multi-session split
- **Khác Sprint 6:** Sprint 7 focus 100% vào COVERAGE TESTS (không có refactor/bugfix mixed)
- Prompt nhấn mạnh **không inflate coverage** + **không refactor production để test** (BHV-002/003)

## Khuyến nghị thực thi

- **Recommend split 2 phiên:**
  - **Phiên 1 (~6-7h):** Baseline + lane_dispatch async tests
  - **Phiên 2 (~6h):** impact_graph/builder + isg_recommender + final verify với fail_under=80
- **High-risk module:** lane_dispatch async (subprocess + asyncio mock phức tạp) — có thể defer 1 phần sang Sprint 8 nếu test fragile
- **Fallback:** Nếu sau effort hợp lý vẫn không đạt 80%, document gap + tăng fail_under từ 70 → giá trị achievable (vd 75-78%) và defer 80% sang Sprint 8
