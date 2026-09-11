# Prompt: Thực hiện Sprint 10 — lane_dispatch Async Path Coverage (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 10 — lane_dispatch Async Path Coverage Uplift** (optional sprint sau Sprint 9). Sprint 0-9 đã hoàn thành (Sprint 7: coverage 81.75%, Sprint 8: 8 F05 bash hardening, Sprint 9: 9 F08 procedure cleanup; tổng 60+ commits).

Sprint 10 là OPTIONAL — chỉ chạy nếu user muốn `lane_dispatch.py` đạt full 80% (hiện 70.43%) thay vì để stable ở mức hiện tại.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project (đặc biệt section "Lệnh Thường Dùng" — `./run-tests.sh`)
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004 (đặc biệt BHV-002 — KHÔNG inflate)
3. **`.claude/rules/00-core.md`** — CORE-023 (Quality > Speed), CORE-025 (Parallel Safety)
4. **`plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md`** §"Sprint 9 Closed" — confirm Sprint 9 đã DONE
5. **`plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md`** §"DONE" — Sprint 7 deferred async paths
6. **`.claude/skills/workflow/_shared/lane_dispatch.py`** — target file (~1724 lines)
7. **`.claude/skills/workflow/_shared/tests/test_lane_dispatch_xf08.py`** — Sprint 7 baseline tests (36 cases)

**Quy tắc tuyệt đối:**

- ✅ **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ **BHV-002** (Simplicity First): KHÔNG add tests chỉ để inflate — mỗi test verify behavior thật
- ✅ **BHV-003** (Surgical Changes): KHÔNG refactor `lane_dispatch.py` để dễ test hơn — async impl giữ nguyên
- ✅ **BHV-004** (Goal-Driven Execution): DONE = `lane_dispatch.py` ≥80% PASS HOẶC document gap nếu effort > 4h
- ✅ Tiếng Việt cho commits/docs; English cho code/test names/paths
- ✅ **VERIFY current state TRƯỚC** — coverage số liệu có thể đã thay đổi sau Sprint 9
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG mock quá deep (5+ layers) — fragile tests
- ❌ KHÔNG test asyncio internals — chỉ test behavior

## 1. MỤC TIÊU SPRINT 10

**Scope:** ~3-4h effort, đẩy `lane_dispatch.py` từ 70.43% → ≥80% bằng async + subprocess tests.

**State đã biết (verify lại khi bắt đầu):**

| File | Sprint 7 end | Sprint 10 target | Lines còn miss |
|------|-------------|------------------|---------------|
| `lane_dispatch.py` | 70.43% (192 miss / 648 stmts) | ≥80% (≤130 miss) | -62 miss cần cover |

**Async paths cần cover (Sprint 7 deferred):**

| # | Function | Lines | Strategy |
|---|----------|-------|----------|
| 1 | `_run_lane_async` | 1440-1502 (~50 lines) | `pytest-asyncio` + `AsyncMock` cho semaphore + retry loop |
| 2 | `dispatch_lanes_async` | 1531-1586 (~45 lines) | Mock `_run_lane_async` + `asyncio.gather` happy path |
| 3 | `_execute_lane_sequential` | 547-548, 570-583, 613-614, 646 (~25 lines) | Mock subprocess + cache + signal aggregation |
| 4 | `dispatch_lanes` sync wrapper | 1630-1683 (~30 lines) | Test sync→async dispatch + Windows ProactorEventLoop guard |

Tổng coverable: ~150 lines pure python (đủ vượt 80% target).

**Priority order:**

| # | Module | Strategy | Estimate | Status |
|---|--------|----------|----------|--------|
| 1 | **Baseline check** | `bash run-tests.sh` confirm 81.75% PASS, lane_dispatch 70.43% | 15min | PENDING |
| 2 | **`pytest-asyncio` setup** | Verify pytest-asyncio đã cài (hoặc add to pyproject deps) | 15min | PENDING |
| 3 | **`_execute_lane_sequential`** tests | Mock subprocess + signal write + retry path | 1h | PENDING |
| 4 | **`_run_lane_async`** tests | AsyncMock semaphore + retry + idempotent skip | 1h | PENDING |
| 5 | **`dispatch_lanes_async`** tests | Mock `_run_lane_async`, test orchestrator pre_completed + pending | 30min | PENDING |
| 6 | **`dispatch_lanes`** sync tests | Test sync wrapper với 1 dim sequential + N dims async | 30min | PENDING |
| 7 | **Final verify** | `bash run-tests.sh` PASS với coverage 80%+ cho lane_dispatch | 30min | PENDING |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. **Đọc Sprint 9 closure** trong audit + plan file
2. **VERIFY baseline:**
   - `cd .claude/skills/workflow/_shared && bash run-tests.sh` confirm coverage 81.75% PASS
   - `python -m pytest tests/test_lane_dispatch_xf08.py --cov=lane_dispatch --cov-report=term-missing -q` xem missing lines hiện tại
   - `python -c "import pytest_asyncio; print(pytest_asyncio.__version__)"` confirm cài
   - Nếu `pytest-asyncio` chưa cài: `pip install pytest-asyncio` + add `pytest-asyncio>=0.23` vào pyproject.toml [tool.pytest.ini_options] asyncio_mode = "auto"
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-10-async-coverage.md`:
   - 4 functions targets + per-function test plan
   - Acceptance: `bash run-tests.sh` PASS, lane_dispatch ≥80%
4. **TodoWrite:** 6-8 todos chính

### 2.2 Per-Function Loop

Cho mỗi async function:

1. **READ** function body — identify exact missing branches
2. **Categorize mock points:**
   - Subprocess (`subprocess.run`) — mock với `unittest.mock.patch`
   - Semaphore acquisition — `AsyncMock` hoặc real `asyncio.Semaphore(N)`
   - File I/O (signals.json read/write) — tmp_path fixtures
   - Token bucket / Backpressure — set `enable_concurrency=False` hoặc mock instances
3. **Test patterns**:
   - **Happy path**: function chạy đến completion, status="completed"
   - **Retry path**: simulate first attempt fail, second pass
   - **Idempotent skip**: pre-existing valid signals.json → skip retries
   - **Failure path**: max retries exhausted → return failure
4. **Verify** mỗi test với `pytest-asyncio` decorator hoặc `asyncio.run` wrapper:
   ```python
   @pytest.mark.asyncio
   async def test_run_lane_async_happy_path(tmp_path):
       ...
   ```
5. **Smoke test sau mỗi function**: `python -m pytest tests/test_lane_dispatch_async_xf10.py -q` (~5s)
6. **Commit per function** (hoặc gộp 2 nhỏ):
   ```
   test(_shared/lane_dispatch): XF-10 Sprint 10 async coverage [XF-10]

   Function: <name>
   Coverage delta: A% → B%
   Tests added: N cases với pytest-asyncio + AsyncMock

   Audit: docs/danglam/wf-fix-bugs-audit-2026-05-15.md Sprint 10
   ```

### 2.3 Post-Sprint

1. **Final coverage:** `bash run-tests.sh` PASS với lane_dispatch ≥80%
2. **Update audit report:** append "Sprint 10 Closed YYYY-MM-DD"
3. **Update plan file:** status DONE per function + coverage delta
4. Recommend cleanup nếu còn:
   - XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
   - XF-06 remaining (10 `>>` append patterns)
   - 14 state JSON templates không có `$schema` — out-of-scope

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 pytest-asyncio mode

`pytest-asyncio` có 2 mode:
1. **`auto` mode** (recommended) — implicit `@pytest.mark.asyncio`, simpler tests
2. **`strict` mode** — explicit decorator required, more verbose nhưng explicit
3. **Skip pytest-asyncio, dùng `asyncio.run` wrapper** — fallback nếu cài đặt fail

### 3.2 AsyncMock vs real asyncio

Cho `_run_lane_async` retry loop:
1. **Mock toàn bộ `_execute_lane_sequential`** — fast, isolation tốt (recommended)
2. **Real subprocess + mock chỉ network/external** — closer to production, slower
3. **Hybrid**: mock subprocess, real asyncio primitives — middle ground

### 3.3 Coverage gap acceptable

Nếu sau effort hợp lý (3h) chỉ đạt 75-78% (không 80%):
1. **Document gap + lock fail_under tại current** — pragmatic (Sprint 7 đã cho thấy 70.43% đủ)
2. **Tăng effort lên 5-6h** để force 80% — risk fragile tests
3. **Skip async path, focus other modules** — Sprint 10 turns into uplift cho module khác

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Tests new flaky (intermittent fail giữa các runs)
- ❌ Mock 5+ layers cho 1 test — quá deep, fragile
- ❌ Production code phải refactor để test → reconsider scope
- ❌ Coverage gate vẫn FAIL < 80% sau effort > 4h
- ❌ Decision point §3 có ≥2 valid options
- ❌ pytest-asyncio cài đặt fail trên Windows Git Bash

## 5. COMPLETION CRITERIA

Sprint 10 DONE khi:

✅ `lane_dispatch.py` coverage ≥80% (hoặc document gap nếu effort > 4h)
✅ `bash run-tests.sh` PASS với fail_under=80
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-10-async-coverage.md` DONE
✅ Audit report append "Sprint 10 Closed YYYY-MM-DD"
✅ 3-5 commits trên master (per function + closure)

## 6. KHỞI ĐỘNG

1. Đọc context (§0) + Sprint 9 closure
2. **VERIFY baseline:**
   - `bash run-tests.sh` PASS coverage 81.75%
   - Inspect lane_dispatch.py async functions (1440-1683)
3. **`AskUserQuestion` 3 câu xác nhận:**
   - "Confirm scope Sprint 10 (lane_dispatch async, ~3-4h, target 80%)?"
   - "pytest-asyncio cài đặt OK trên Windows? Hoặc dùng asyncio.run wrapper?"
   - "Decision §3.3: nếu effort > 4h chưa đạt 80% → accept gap hay tăng effort?"
4. Tạo plan file + TodoWrite + start execute

## 7. CHECKPOINT & RESUME

Sprint 10 ~3-4h — single session khả thi. Nếu context > 80%:

1. **STOP** sau function hiện tại completed
2. **Update** plan file status
3. **Commit** WIP `wip: pause at <function>, resume from <next>`
4. **Note** audit report cho phiên sau

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `plans/architect-wf-fix-bugs/danglam/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 9 closure | §"Sprint 9 Closed — 2026-05-15" trong audit |
| Sprint 10 scope | `plans/wf-fix-bugs-v10-3-audit/sprint-7-coverage-80.md` §"async deferred" |
| Test runner | `cd .claude/skills/workflow/_shared && bash run-tests.sh` |
| Coverage report | `python -m coverage report --include="lane_dispatch.py"` |
| pytest-asyncio docs | `https://pytest-asyncio.readthedocs.io/` |
| Sprint 7 baseline tests | `tests/test_lane_dispatch_xf08.py` (36 cases pure-logic + CLI) |
| Sprint 7 helper tests | `tests/test_lane_dispatch_helpers_xf08.py` (14 cases) |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Add tests chỉ để inflate coverage % (BHV-004) — mỗi test PHẢI verify behavior thật
- ❌ Refactor `lane_dispatch.py` async code chỉ để dễ test hơn (BHV-002 + BHV-003)
- ❌ Mock asyncio internals (`asyncio.gather` mock chỉ ở entry, không deeper)
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (pattern Sprint 3+4+5+6+7+8+9)
- ❌ Modify `.mc-data/` runtime files
- ❌ Add to omit list mà không user approve

## 10. SPRINT 0+1+2+3+4+5+6+7+8+9 CONTEXT (đã DONE)

**Tổng đã DONE qua 9 sprints:** 60+ commits, ~42h actual.

**Sprint 7 final (2026-05-15):**
- Python coverage: 73.18% → 81.75% (+8.57pp), 1015 tests pass
- 4 commits, fail_under=80 restored
- lane_dispatch deferred async path: 59.02% → 70.43% (+11.41pp), Sprint 7 không reach 80% individual

**Sprint 8 final (2026-05-15):**
- 8/8 F05 bash hardening findings + 1 drift documented
- 2 commits, regression PASS

**Sprint 9 final (2026-05-XX TBD):**
- 9 F08 procedure cleanup findings
- N commits, regression PASS

**Sprint 10 (THIS SPRINT — OPTIONAL):**
- Push lane_dispatch async path → ≥80%
- Acceptable fallback: 75-78% với gap documented

**Out-of-scope (no sprint planned):**
- XF-02 remaining (error code dual-use)
- XF-06 remaining (`>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema`

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + Sprint 9 closure audit + plan file, VERIFY baseline (`bash run-tests.sh` PASS 81.75%, lane_dispatch 70.43%), check pytest-asyncio installation, rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + Sprint 9 closure
   - VERIFY baseline (coverage 81.75%, lane_dispatch 70.43%)
   - Check pytest-asyncio installation
   - Hỏi 3 câu xác nhận (scope, pytest-asyncio, gap acceptance)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-10-async-coverage.md`
   - Thực hiện 4 async functions theo §2 quy trình
   - Hỏi user 3 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 10 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- **OPTIONAL sprint** — chỉ chạy nếu user muốn 100% coverage. Sprint 7 đã đảm bảo overall 81.75% PASS
- Có **3 decision points** §3 yêu cầu user input (pytest-asyncio mode, mock strategy, gap acceptance)
- Có **safety guardrails** §4 Quality Gates — đặc biệt mock 5+ layers + flaky tests
- Có **resume mechanism** §7 — Sprint 10 ~3-4h single-session khả thi
- **Khác Sprint 7:** Sprint 10 focus 100% vào ASYNC path (deferred từ Sprint 7 vì AsyncMock complexity)
- Prompt nhấn mạnh **không inflate** + **không refactor production async** (BHV-002/003)

## Khuyến nghị thực thi

- **Single session feasible** (~3-4h)
- **High-risk function:** `_run_lane_async` retry loop — async + semaphore + token bucket nhiều mock points
- **Pragmatic fallback:** Nếu sau 4h chưa đạt 80%, document gap + lock fail_under tại level achieved (vd 78% nếu lane_dispatch 75%) — **đây là OPTIONAL sprint, không phá pipeline**
- **Verify regression:** Sau mỗi 2 functions, chạy `bash run-tests.sh` smoke (~5min) để catch sớm
- **Out-of-scope:** Không touch `dispatch_lanes_async` token_bucket + backpressure logic — chỉ test happy path orchestration
