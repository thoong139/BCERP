# Prompt: Thực hiện Sprint 6 — Python Runtime + Coverage (wf-fix-bugs v10.3)

> **Cách dùng:** Mở phiên Claude Code mới tại `d:\Working\MCV3`, copy toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`, paste vào prompt đầu tiên.

---

===PROMPT START===

Bạn là kỹ sư MCV3 senior thực hiện **Sprint 6 — Python Runtime + Coverage Gate** của plan v10.3 dựa trên audit report 2026-05-15. Sprint 0+1+2+3+4+5 đã hoàn thành ở các phiên trước với 40 commits trên master.

## 0. NGUYÊN TẮC BẮT BUỘC

Trước khi làm gì, NẠP ngữ cảnh theo thứ tự:

1. **`CLAUDE.md`** — overview project (đặc biệt section "Lệnh Thường Dùng" — `./run-tests.sh`, coverage gate ≥80%)
2. **`.claude/rules/00-behavioral.md`** — BHV-001 đến BHV-004
3. **`.claude/rules/00-core.md`** — CORE-025 (Parallel Safety), CORE-035 (Atomic Write), CORE-036 (Cross-Skill Contract Schema versioned), CORE-038 (Context Budget)
4. **`docs/danglam/wf-fix-bugs-audit-2026-05-15.md`** — audit report (focus §Sprint 6 đề xuất + §XF-08 CRITICAL + §F06 cluster Python Runtime)
5. **`.claude/skills/workflow/_shared/`** — Python package layout (lane, signal_bus, concurrency, workload_estimator, partition, aggregate, cdg, cache, profiles, isg, scan_cache)
6. **`.claude/skills/workflow/_shared/run-tests.sh`** — test runner + coverage gate logic
7. **`.claude/skills/workflow/_shared/pyproject.toml`** (hoặc `setup.cfg` / `pytest.ini`) — coverage config (fail_under, omit list)
8. **`.claude/skills/workflow/_shared/coverage.json`** (nếu tồn tại) — last coverage report

**Quy tắc tuyệt đối:**

- ✅ Áp dụng **BHV-001** (Hỏi trước khi giả định): mọi ambiguous → DỪNG hỏi user qua `AskUserQuestion`
- ✅ Áp dụng **BHV-002** (Simplicity First): KHÔNG thêm tests cho code không có ai dùng, KHÔNG refactor production để dễ test hơn
- ✅ Áp dụng **BHV-003** (Surgical Changes): CHỈ sửa đúng issue, KHÔNG refactor xung quanh
- ✅ Áp dụng **BHV-004** (Goal-Driven Execution): "DONE khi nào" = coverage gate PASS ≥80% (verified bằng `./run-tests.sh`)
- ✅ Áp dụng **CORE-025**: Mọi cross-process resource (lock, counter) PHẢI có atomic operation + timeout
- ✅ Áp dụng **CORE-035**: `json.dump` PHẢI có `sort_keys=True` cho audit_chain checksum determinism
- ✅ Mỗi finding = 1 commit (trừ batch grouping logical, vd: F06.005 dim→lane map + DIMENSION_REGISTRY refactor)
- ✅ Tiếng Việt cho commits/docs; English cho code/test names/paths
- ✅ Dùng **Serena tools** (`find_symbol`, `find_referencing_symbols`, `replace_symbol_body`) cho Python edits — token-efficient
- ✅ **CHẠY `./run-tests.sh` TRƯỚC** mỗi finding ảnh hưởng coverage để verify baseline
- ✅ **VERIFY current state mỗi finding TRƯỚC khi sửa** — audit có thể stale (Sprint 3+4+5 đã phát hiện 5 audit drifts: F07.007, XF-07a, XF-07c, F02.002 Execute 3/8 vs 4/8, Step 5.7 6/8 vs 7/8, boundary mode terminology). Đọc nội dung thực tế Python code, chạy tests, xác nhận vấn đề tồn tại.
- ❌ KHÔNG amend commits đã push
- ❌ KHÔNG dùng `--no-verify` bypass hooks
- ❌ KHÔNG bypass coverage gate bằng cách add to omit list trừ khi user approve qua AskUserQuestion (F06.013 llm_lane decision)
- ❌ KHÔNG implement cross-process lock mới mà không design pattern trước (F06.012 — lớn)
- ❌ KHÔNG tự suy diễn khi audit có ambiguity — LUÔN AskUserQuestion
- ❌ KHÔNG sửa Python code mà không có corresponding test (BHV-004: every fix verifiable)

## 1. MỤC TIÊU SPRINT 6

**Scope:** ~12h effort, 7 findings — Python coverage gate 80% PASS + concurrency safety + observability.

**State đã biết (verify lại khi bắt đầu):**

| Vị trí | Vấn đề | Severity |
|--------|--------|----------|
| `_shared/` package coverage gate | Effective 62.1% (1861/2999 statements) — thấp hơn `fail_under=80` 18 điểm. Hot spots: report_generator (29.5%), impact_graph/builder (46.6%), workload_estimator/estimator (51.7%), lane_dispatch (55.0% — core orchestrator!), profile_resolver (55.6%), llm_lane/* 6 files 0%, signal_aggregator (73.9%), partition_planner (69.3%) (XF-08 + F06.001) | CRITICAL |
| `_shared/lane/dispatch.py` (hoặc tương đương) | Thiếu session-level heartbeat; signals stale timeout 300s mismatch với session 30s (F06.004) | HIGH |
| `_shared/aggregate/signal_aggregator.py:_normalize_probe_signal` | Hardcode dim→lane map duplicate DIMENSION_REGISTRY → drift risk (F06.005) | HIGH |
| `_shared/llm_lane/*` 6 files | 0% coverage — production path khi `--llm-scan`, khó mock (F06.013) | HIGH |
| `_shared/` 4 subpackages | Thiếu `__init__.py` (F06.006) | MEDIUM |
| `_shared/lane/dispatch.py` | Dùng `print()` thay `logging` — không config được level/output (F06.007) | MEDIUM |
| `_shared/` mọi `json.dump` state file write | Thiếu `sort_keys=True` → audit_chain checksum non-deterministic (F06.008) | HIGH |
| `_shared/signal_bus/_contract.json` + `concurrency/_contract.json` | Version "0.1.0-skeleton", status "draft" — code đã production (F06.003) | MEDIUM |
| `SignalBus.flush()` | Không có cross-process lock — N concurrent lane writes có thể corrupt signal store (F06.012) | HIGH |

**Priority order:**

| # | Finding | Effort | Strategy |
|---|---------|--------|----------|
| 1 | **XF-08 baseline check** | 30min | Chạy `./run-tests.sh` → confirm coverage hiện tại + identify regressions từ Sprint 5 (nếu có). KHÔNG fix yet. |
| 2 | **F06.008** | 30min | Add `sort_keys=True` vào mọi `json.dump` state file write trong `_shared/`. Pure mechanical, prerequisite cho audit_chain. |
| 3 | **F06.006** | 15min | Tạo `__init__.py` cho 4 subpackages thiếu. Quick fix. |
| 4 | **F06.007** | 30min | Replace `print()` trong lane_dispatch.py bằng `logging.getLogger(__name__)`. Add basicConfig nếu chưa có. |
| 5 | **F06.005** | 1h | Loại bỏ hardcoded dim→lane map trong `signal_aggregator._normalize_probe_signal` — dùng `DIMENSION_REGISTRY` (canonical). Add test cho normalize logic. |
| 6 | **F06.004** | 1.5h | Giảm signals lock stale timeout 300s → 60s + thêm session-level heartbeat trong `lane_dispatch`. Add test cho stale lock takeover (mock time). |
| 7 | **XF-08 + F06.013** | 4-6h | Bổ sung tests cho lane_dispatch (timeout, stale lock, LLM gating), signal_aggregator (legacy fallback, probe failures loading), workload_estimator. Decision llm_lane/: omit hoặc mock tests. Verify gate PASS ≥80%. |
| 8 | **F06.003** | 30min | Update `signal_bus/_contract.json` + `concurrency/_contract.json` version "0.1.0-skeleton" → "1.0.0", status "draft" → "production". Verify schema fields populated. |
| 9 | **F06.012** | 1.5h | Design decision: document hoặc implement cross-process lock cho `SignalBus.flush()`. Recommend filelock library (đã dùng trong `_shared/`?) hoặc fcntl pattern (POSIX). User confirm scope. |

## 2. QUY TRÌNH

### 2.1 Pre-Sprint

1. **Đọc audit report** §Sprint 6 + §XF-08 + §F06 cluster (lines ~193-214, 253-279, 304-308, 417-426)
2. **VERIFY baseline:**
   - `cd .claude/skills/workflow/_shared && ./run-tests.sh` → confirm coverage gate fail tại 62.1% hay đã thay đổi
   - `ls .claude/skills/workflow/_shared/*/` → confirm subpackage structure (lane, signal_bus, concurrency, ...)
   - `grep -rn "json.dump" .claude/skills/workflow/_shared/ | head -20` → đếm số sites cần `sort_keys=True`
   - `grep -rn "print(" .claude/skills/workflow/_shared/lane/` → confirm print() usage trong lane_dispatch
   - `find .claude/skills/workflow/_shared -name __init__.py | head -20` → identify 4 missing __init__.py
3. **Tạo plan file** `plans/wf-fix-bugs-v10-3-audit/sprint-6-python-coverage.md` theo pattern Sprint 5:
   - 9 finding IDs + files involved + current state
   - Strategy per finding (test cases planned, files modified)
   - Acceptance criteria per finding (coverage % target nếu applicable)
4. **TodoWrite**: 9 todos (mỗi finding 1 todo; split XF-08+F06.013 thành 2-3 todos nếu phức tạp)

### 2.2 Per-Finding Loop

Cho mỗi finding:

1. **READ** chi tiết từ audit report
2. **VERIFY current state:** Đọc Python code, chạy `pytest <test_file>` nếu có, xác nhận vấn đề tồn tại
3. **Decision point check:** Nếu ambiguity → `AskUserQuestion`
4. **Apply fix + Add test:**
   - F06.008: Mechanical grep + sed (hoặc Edit batch). Verify deterministic via 2 consecutive writes diff.
   - F06.006: Touch `__init__.py` (verify package import works).
   - F06.007: Replace print → logger. Set logger level via env var.
   - F06.005: Refactor `_normalize_probe_signal` để dùng DIMENSION_REGISTRY. Add test fixture các dim values.
   - F06.004: Giảm timeout constant. Implement heartbeat thread (hoặc periodic touch). Test stale lock detection.
   - XF-08: Bổ sung tests theo Python testing best practices (parametrize, fixtures, mock). Mỗi test PHẢI có docstring giải thích "what" + "why".
   - F06.013: Design decision (omit vs mock). Document rationale trong `pyproject.toml` comment hoặc README.
   - F06.003: Edit `_contract.json` version + status. Verify schema fields đầy đủ.
   - F06.012: Design pattern (file-based lock vs in-memory mutex + cross-process advisory). User confirm trước implement.
5. **Verify:**
   - `./run-tests.sh --fast` pass (smoke check)
   - `./run-tests.sh` full pass với coverage không regress (nếu áp dụng)
   - Cross-skill: `_contract.json` changes không phá downstream consumers
6. **Commit:** message format:
   ```
   fix({scope}): {one-line summary} [F06.0YY]

   {2-3 dòng giải thích Vietnamese}

   Audit: docs/danglam/wf-fix-bugs-audit-2026-05-15.md F06.0YY
   ```

### 2.3 Post-Sprint

1. **Final verification:** `./run-tests.sh` PASS với coverage ≥80%
2. **Update audit report:** append "Sprint 6 Closed YYYY-MM-DD" section với commit list + coverage delta
3. **Update plan file:** status DONE per finding + coverage delta per finding
4. **AskUserQuestion:** tiếp tục Sprint 7 (Bash Hardening ~4h) hay Sprint 8 (Procedure Cleanup ~4h) hay nghỉ?

## 3. CRITICAL DECISION POINTS (cần AskUserQuestion)

### 3.1 F06.013 — llm_lane/* coverage strategy

`_shared/llm_lane/*` 6 files 0% coverage. Production path khi `--llm-scan` (chạy LLM thật).

**Hỏi user:** 3 options:
1. **Add `_shared/llm_lane/*` vào omit list** trong `pyproject.toml` — coverage gate không include. Lý do: LLM-dependent, khó mock chính xác. Risk: code path không có safety net.
2. **Viết mock-based tests** dùng `unittest.mock.patch` cho LLM client. Pros: real coverage. Cons: tests fragile, dễ false positive nếu LLM API thay đổi.
3. **Hybrid:** Mock infrastructure code (client init, request format), omit business logic (prompts, response parsing). Balance giữa safety + maintainability.

### 3.2 F06.004 — Heartbeat strategy

Session-level heartbeat trong `lane_dispatch.py` để detect stale lock. Options:

1. **Threading.Timer periodic touch** — background thread update lock file mtime every 20s. Simple, nhưng nếu main process hang → thread cũng hang.
2. **Subprocess heartbeat daemon** — spawn separate process touch lock. Robust nhưng phức tạp setup/teardown.
3. **Touch trên mỗi probe completion** — không async, không cần thread. Pros: simple. Cons: nếu probe dài (>60s) → false stale.

### 3.3 F06.012 — Cross-process lock cho SignalBus.flush()

`SignalBus.flush()` không có lock. N lanes concurrent flush có thể corrupt signal store.

**Hỏi user:** Implementation:
1. **`filelock` library** (third-party, đã dùng trong `_shared/`?) — clean API, cross-platform. Need check dependency tree.
2. **`fcntl.flock` (POSIX)** — built-in, free. Cons: không native Windows (need msvcrt fallback).
3. **Atomic rename pattern** (no lock) — flush ghi vào tmp file → atomic rename. Pros: no lock contention. Cons: cần redesign signal store thành append-only log.
4. **Document only (defer implementation)** — note risk trong contract, không fix Sprint 6 (move sang Sprint 7+).

### 3.4 XF-08 — Coverage gate strategy

Coverage hiện 62.1%, target 80%. Cần thêm ~540 lines test coverage.

**Hỏi user:** Priority focus:
1. **Core orchestrator first** (lane_dispatch 55.0% → 80%) — risk mitigation cao nhất, ~200 LOC test.
2. **Lowest hanging fruit** (workload_estimator 51.7% → 80%, profile_resolver 55.6% → 80%) — easier wins, ~150 LOC test.
3. **Width approach** — bổ sung tests đều cho mọi file <80%, không deep nhưng broad.
4. **Combined** — Order: lane_dispatch → signal_aggregator → workload_estimator → others.

## 4. QUALITY GATES (DỪNG + AskUserQuestion nếu gặp)

- ❌ Coverage gate sau Sprint 6 vẫn FAIL <80% → re-evaluate F06.013 omit decision
- ❌ Test mới flaky (fail intermittent) — không commit, fix flakiness trước
- ❌ Production code refactor phá downstream consumer → cross-skill artifact validation fail
- ❌ Cross-process lock design phức tạp >3h effort → defer F06.012 sang Sprint 7+
- ❌ Decision point có ≥2 valid options (theo §3 trên)
- ❌ Context budget > 80% (checkpoint per CORE-038) — Sprint 6 nặng ~12h, dễ vượt 1 phiên
- ❌ Cần extend timeline > +50% (12h → 18h)

## 5. COMPLETION CRITERIA

Sprint 6 DONE khi:

✅ Tất cả 9 findings mark `completed` trong TodoWrite
✅ `./run-tests.sh` PASS với coverage ≥80% (verified)
✅ 4 missing `__init__.py` created
✅ `lane_dispatch.py` dùng `logging` thay `print()`
✅ Mọi `json.dump` state file có `sort_keys=True`
✅ `signal_aggregator._normalize_probe_signal` dùng DIMENSION_REGISTRY (no hardcode)
✅ `lane_dispatch` có heartbeat mechanism + stale lock detection (60s timeout)
✅ `llm_lane/*` strategy resolved (omit hoặc mock — per §3.1 user choice)
✅ `signal_bus/_contract.json` + `concurrency/_contract.json` version "1.0.0", status "production"
✅ `SignalBus.flush()` cross-process safety resolved (implement hoặc document defer)
✅ Plan file `plans/wf-fix-bugs-v10-3-audit/sprint-6-python-coverage.md` updated DONE
✅ Audit report append "Sprint 6 Closed YYYY-MM-DD"

## 6. KHỞI ĐỘNG

1. Serena đã active (project `d:\Working\MCV3`) — verify qua `mcp__serena__check_onboarding_performed` nếu cần
2. Đọc context (§0)
3. **VERIFY baseline state:**
   - `cd .claude/skills/workflow/_shared && ./run-tests.sh` → coverage hiện tại + test status
   - Đọc `pyproject.toml` (hoặc `setup.cfg`) → confirm `fail_under = 80`, omit list hiện tại
   - `find .claude/skills/workflow/_shared -name __init__.py` → count subpackages có vs missing
   - `grep -rn "json.dump" .claude/skills/workflow/_shared/` | wc -l → đếm sites cần fix F06.008
4. **`AskUserQuestion` 4 câu xác nhận:**
   - **"Confirm scope Sprint 6 (9 findings ~12h)?"** → Có thể split sang multi-phiên nếu cần
   - **"Git permissions: commit trên master như Sprint 0-5?"** → Confirm
   - **"Decision points §3 (llm_lane, heartbeat, SignalBus lock, coverage focus): batch confirm trước hay hỏi từng cái?"** → Recommend batch confirm
   - **"Context budget: Sprint 6 nặng (12h) — kế hoạch resume nhiều phiên hay làm gọn 1 phiên dài?"**
5. Tạo plan file + TodoWrite + start execute theo §2

## 7. CHECKPOINT & RESUME

Sprint 6 nặng ~12h — có thể cần multi-session. Nếu context > 80% / phiên hết:

1. **STOP** sau finding hiện tại completed (KHÔNG bỏ dở giữa chừng test suite)
2. **Update** plan file với status (DONE/IN_PROGRESS/PENDING per finding)
3. **Commit** WIP `wip: pause at F06.0YY, resume from {next finding}`
4. **Note** audit report cho phiên sau
5. **Document** baseline coverage state khi resume để verify regression

**Suggested split (nếu 2 phiên):**
- **Phiên 1 (~6-7h):** F06.008 + F06.006 + F06.007 + F06.005 + F06.003 (quick wins + refactor)
- **Phiên 2 (~5-6h):** F06.004 heartbeat + XF-08 coverage + F06.013 llm_lane + F06.012 SignalBus lock

## 8. THAM CHIẾU NHANH

| Loại | File/Command |
|---|---|
| Báo cáo audit chính | `docs/danglam/wf-fix-bugs-audit-2026-05-15.md` |
| Sprint 6 section trong audit | §"Sprint 6 — Python Runtime + Coverage (1.5 ngày, ~12h)" |
| XF-08 details | §"XF-08: Python Coverage Gate 80% FAIL" lines ~193-214 |
| F06 cluster details | §"Python Runtime Critical (5 findings)" lines ~304-308 + §F06.002-008 chi tiết |
| Test runner | `cd .claude/skills/workflow/_shared && ./run-tests.sh [--fast \| --module=<name>]` |
| Coverage config | `.claude/skills/workflow/_shared/pyproject.toml` (hoặc `setup.cfg`) |
| Python package | `.claude/skills/workflow/_shared/` |
| CORE-035 atomic write | `.claude/rules/00-core.md` §4l |
| CORE-025 parallel safety | `.claude/rules/00-core.md` §0 |
| Sprint 5 closure | `docs/danglam/wf-fix-bugs-audit-2026-05-15.md §Sprint 5 Closed` |
| Sprint 5 plan | `plans/wf-fix-bugs-v10-3-audit/sprint-5-agent-spawn.md` |

## 9. ANTI-PATTERNS — TUYỆT ĐỐI KHÔNG

- ❌ Sửa nhiều findings 1 commit (trừ batch logical fix: F06.005 dim→lane + DIMENSION_REGISTRY refactor cùng nhau OK)
- ❌ Add tests chỉ để inflate coverage % (BHV-004) — mỗi test PHẢI verify behavior thật
- ❌ Refactor production code chỉ để dễ test hơn (BHV-002 + BHV-003) — chấp nhận test hơi phức tạp hơn nếu production logic đúng
- ❌ Add to omit list mà không user approve (F06.013)
- ❌ Implement F06.012 cross-process lock mà chưa AskUserQuestion design pattern
- ❌ Commit Python edit mà chưa chạy `./run-tests.sh --fast` smoke check
- ❌ Bypass coverage gate bằng `--no-cov` hoặc `--cov-fail-under=0`
- ❌ Skip Quality Gates §4
- ❌ Force-push branches có commits shared
- ❌ Bypass pre-commit hooks (`--no-verify`)
- ❌ Modify `.mc-data/` runtime files
- ❌ Tin tuyệt đối audit findings — VERIFY state thực tế trước (Sprint 3+4+5 đã phát hiện 5 audit drifts: F07.007, XF-07a, XF-07c, F02.002 sections count, Step 5.7 sections count, boundary mode terminology)

## 10. SPRINT 0+1+2+3+4+5 CONTEXT (đã DONE — 40 commits)

**Sprint 0** (Quick-Wins, 14 items): 1 commit `310797e3`
**Sprint 1** (Critical Pipeline Blockers, 9 items): 9 commits — XF-05, XF-01, F03.015, F05.001, F05.002, F06.002, XF-06 PARTIAL, F04.003, F04.002
**Sprint 2** (Error Code Namespace, subset 5 items): 5 commits — F04.007, XF-02 PARTIAL, F03.008, F03.020
**Sprint 3** (Template + Schema Compliance, full 10 findings): 8 commits — XF-04, XF-03/F07.001, F07.003, F07.011, F07.009, F07.010, F07.008, F07.007, F07.004
**Sprint 4** (SKILL.md Compliance + Architecture, full 6 findings): 7 commits — XF-07a, F08.003-004, F04.004, F02.001, XF-07b/F01.017, XF-07c, closure
**Sprint 5** (Agent Spawn Quality, full 5 findings, ~1.5h actual): 6 commits — F02.004, F02.002+006, F02.003, F02.005+011, F02.007-009, closure
  - Commits: `c1f4b139` `80407d0b` `59370a89` `2c4ad8cd` `669345b9` `790868b3`
  - 3 audit drifts detected + corrected (§15 Execute 4/8 vs audit 3/8, Step 5.7 7/8 vs audit 6/8, boundary mode terminology)
  - Kết quả: 8/8 CORE-037 sections cho Step 5.7 + Step 6.5; §16 Sub-Probe Template inline; 6 sub-probes có model=opus

**Tổng đã DONE:** 40 commits, ~25h actual.

**Deferred sang Sprint 7+:**
- Sprint 7 — Bash Scripts Hardening (~4h): F05.003-007, F05.009, F05.024, F05.011
- Sprint 8 — Procedure Logic + Cleanup (~4h): F08.015-022, F03.014
- XF-02 remaining (E010/E013 dual-use, wf-fix-integration E099-E106)
- XF-06 remaining (10 `>>` append patterns Phases 2-5,7)
- 14 state JSON templates không có `$schema` (out-of-scope)

---

**Bắt đầu ngay:** Đọc CLAUDE.md + rules + audit report §Sprint 6 + §XF-08 + §F06 cluster, VERIFY baseline state (chạy `./run-tests.sh`, count missing `__init__.py`, count `json.dump` sites, identify hot spots), rồi `AskUserQuestion` về scope phiên này theo §6.

===PROMPT END===

---

## Cách sử dụng

1. **Mở phiên mới** Claude Code tại workspace `d:\Working\MCV3`
2. **Copy** toàn bộ block giữa `===PROMPT START===` và `===PROMPT END===`
3. **Paste** vào prompt đầu tiên của phiên mới
4. Claude sẽ:
   - Đọc CLAUDE.md + rules + audit + F06 findings detail
   - VERIFY baseline state (Python tests, coverage, package structure)
   - Hỏi 4 câu xác nhận (scope, git, decision strategy, context split)
   - Tạo plan file `plans/wf-fix-bugs-v10-3-audit/sprint-6-python-coverage.md`
   - Thực hiện 9 findings theo §2 quy trình
   - Hỏi user 4 decision points (§3) tại các điểm ambiguous
   - Update audit report + commit Sprint 6 closure

## Lưu ý

- Prompt **tự-chứa** — không cần kèm context từ phiên hiện tại
- Có **4 decision points** §3 yêu cầu user input (llm_lane omit/mock, heartbeat strategy, SignalBus lock impl, coverage focus order)
- Có **safety guardrails** §4 Quality Gates — đặc biệt coverage gate FAIL hoặc F06.012 lock phức tạp
- Có **resume mechanism** §7 — Sprint 6 nặng ~12h, ưu tiên multi-session split
- **Khác Sprint 5:** Sprint 6 là RUNTIME (Python tests + concurrency) — risk cao hơn về regression, mọi fix PHẢI có test verification + `./run-tests.sh` PASS sau mỗi commit
- Prompt nhấn mạnh **VERIFY baseline trước** + **chạy tests sau mỗi fix** — không tin coverage.json stale

## Khuyến nghị thực thi

- **Recommend split 2 phiên:**
  - **Phiên 1 (~6-7h):** F06.008 + F06.006 + F06.007 + F06.005 + F06.003 (mechanical + refactor, ít risk)
  - **Phiên 2 (~5-6h):** F06.004 heartbeat + XF-08 coverage tests + F06.013 llm_lane + F06.012 SignalBus lock (heavy lifting)
- **Alternative:** 1 phiên dài nếu user OK với context budget cao và risk resume — Sprint 6 logic phức tạp hơn Sprint 5, ít fit cho 1 phiên.
- **High-risk findings:** F06.012 (cross-process lock design) có thể defer sang Sprint 7+ nếu thiết kế phức tạp hơn dự kiến — confirm với user qua §3.3 trước implement.
