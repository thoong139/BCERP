# Audit Checklist — wf-fix-bugs

> **Phiên bản:** v1.0.0 (2026-05-11)
> **Phạm vi:** Toàn bộ skill wf-fix-bugs v9.0.2 — orchestrator + 11 dimension lanes + sub-skills
> **Mục đích:** Bộ tiêu chuẩn kiểm tra chất lượng khi rà soát hoặc phát triển skill.
> **Nguyên tắc cốt lõi:** **Chất lượng & Độ chính xác là trên hết.** Mọi tối ưu về thời gian hoặc token bị loại bỏ nếu có nguy cơ làm giảm chất lượng phát hiện và sửa lỗi.

---

## Hướng Dẫn Sử Dụng

### Cách Chấm Điểm

| Ký hiệu | Ý nghĩa |
|---------|---------|
| PASS | Tiêu chí đạt |
| FAIL | Tiêu chí không đạt — **blocking** nếu thuộc P1 |
| WARN | Tiêu chí đạt không hoàn hảo — cần cải thiện nhưng không block |
| N/A | Không áp dụng cho phiên bản/ngữ cảnh hiện tại |
| SKIP | Bỏ qua có chủ đích (phải ghi rõ lý do) |

### Quy Tắc Chấm Điểm

```
KẾT QUẢ CUỐI CÙNG:
  PASS  = Mọi checkpoint P1 PASS, P2+P3 ≥ 60% PASS
  WARN  = Mọi checkpoint P1 PASS, P2+P3 < 60% PASS
  FAIL  = Bất kỳ checkpoint P1 nào FAIL
  BLOCK = ≥ 3 checkpoint P1 FAIL → không được release
```

### Tần Suất Audit

| Trigger | Phạm vi audit |
|---------|---------------|
| Trước mỗi release | Full 97 checkpoints |
| Sau khi sửa SKILL.md | P1 (74 checkpoints) |
| Sau khi thêm dimension lane mới | P1 + C2.1 + C2.2 |
| Sau khi sửa procedure | P1 checkpoints liên quan đến procedure đó |
| Định kỳ (monthly) | Full 97 checkpoints |

---

## TẦNG 1: Chính Xác & Bám Workflow (P1 — CORRECTNESS)

> **BLOCKING:** Bất kỳ FAIL nào trong tầng này → skill không được coi là hoạt động đúng.
> **Tổng:** 10 nhóm, 74 checkpoints. **Trọng số:** 60%.

---

### Nhóm C1.1 — Phase Execution Completeness

**Mục tiêu:** Mọi phase trong workflow phải được thực thi đầy đủ, không bỏ qua bước nào.

#### C1.1.1 — Phase 0 PRE-GATE hoàn thành trước Phase 1

- **Cách kiểm tra:** Mở `_trace/session-log.json`, tìm event `START` của Phase 1. Xác nhận trước đó có event `COMPLETE` của Phase 0.
- **Pass khi:** Phase 0 có đủ: `deprecation_block`, `ci_pre_gate`, `browser_cdg` (nếu có UI), `scope_cdg` (nếu >20 modules), `cost_cdg` (nếu >$5).
- **FAIL nếu:** Thiếu bất kỳ sub-step nào trong Phase 0 mà không có lý do skip hợp lệ.

#### C1.1.2 — Step 1.5 Workload Gate không bị skip

- **Cách kiểm tra:** Đọc `fix-status.json` → check field `workload_gate` tồn tại.
- **Pass khi:** `workload_gate.decision` khác `null`, `workload_gate.ratio` có giá trị số.
- **FAIL nếu:** Workload gate bị skip (field không tồn tại) khi có ≥ 2 dimensions.

#### C1.1.3 — Step 2.5 CDG Handoff thực thi

- **Cách kiểm tra:** Kiểm tra `cdg-tokens.json` hoặc `cdg_handoff` field trong `fix-status.json`.
- **Pass khi:** Với mỗi CDG được trigger, có decision token (accept/reject/escalate).
- **FAIL nếu:** CDG bị trigger nhưng không có token, workflow continue mà không resolve.

#### C1.1.4 — Step 2.6 Safety Check thực thi trước Phase 3

- **Cách kiểm tra:** Đọc `safety-check-result.json` trong session directory.
- **Pass khi:** File tồn tại + chứa kết quả của cả 4 checks:
  - `code_collision` — kiểm tra code mới không ghi đè code hiện có
  - `registry_xref` — kiểm tra REQ-ID trong code khớp với registry
  - `uncommitted_changes` — kiểm tra không có thay đổi chưa commit
  - `deprecated_modules` — kiểm tra không sửa module đã deprecated
- **FAIL nếu:** Thiếu bất kỳ check nào trong 4 checks trên.

#### C1.1.5 — Dependency chain giữa các phase được tôn trọng

- **Cách kiểm tra:** Trace thứ tự thực thi trong `session-log.json`.
- **Pass khi:**
  - Phase 1 COMPLETE → Phase 2 START
  - Phase 2 COMPLETE → Phase 3 START
  - Phase 3 COMPLETE → POST-GATE
- **FAIL nếu:** Phase sau bắt đầu khi phase trước chưa có output files.

#### C1.1.6 — E005 path (N=0 issues) không skip POST-GATE

- **Cách kiểm tra:** Test với codebase không có lỗi → verify output files.
- **Pass khi:**
  - `fix-status.json` có `status: "completed"`, `next_action: "done"`
  - `fix-impact.json` tồn tại với `fix_summary.fixed: 0`, `next_recommended_action.skill: "ready-for-release"`
  - `orchestrator-summary.md` tồn tại và có nội dung
- **FAIL nếu:** Thiếu `fix-impact.json` hoặc `orchestrator-summary.md`.

#### C1.1.7 — Tất cả phase có trace event

- **Cách kiểm tra:** `jq '.events[] | select(.event=="COMPLETE") | .phase' session-log.json | sort -u`
- **Pass khi:** Có COMPLETE event cho tất cả phase đã chạy (tối thiểu Phase 0, 1, 6; nếu có issues thì thêm 2, 3, 4, 5).
- **FAIL nếu:** Thiếu COMPLETE event cho phase đã thực thi.

---

### Nhóm C1.2 — Gate Enforcement

**Mục tiêu:** Mọi quality gate phải được evaluate đầy đủ và enforce đúng, không bypass.

#### C1.2.1 — Deprecation BLOCK (v6.x legacy detection)

- **Cách kiểm tra:** Tạo session directory format v6.x (`run-NNN--YYYYMMDD/`) → chạy workflow.
- **Pass khi:** Workflow exit với code 78, hiển thị message hướng dẫn migrate.
- **FAIL nếu:** Workflow tiếp tục chạy trên legacy path.
- **Escape hatch:** `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1` — verify chỉ hoạt động khi được set rõ ràng.

#### C1.2.2 — CI PRE-GATE freshness check

- **Cách kiểm tra:** Test với GitNexus index cũ hơn HEAD 20+ commits.
- **Pass khi:** Hiển thị cảnh báo "severe stale" nhưng không block workflow.
- **FAIL nếu:** Crash hoặc block workflow vì index cũ.

#### C1.2.3 — CI PRE-GATE graceful absence

- **Cách kiểm tra:** Test trên project không có GitNexus và Serena.
- **Pass khi:** Fallback về Grep/Glob, workflow continue bình thường.
- **FAIL nếu:** Crash hoặc từ chối chạy vì thiếu tool.

#### C1.2.4 — Browser CDG cho QD9

- **Cách kiểm tra:** Test project có `interface_type: web` nhưng `BASE_URL` không reachable.
- **Pass khi:** CDG prompt hỏi user, không auto-continue. Ghi nhận decision vào `cdg-tokens.json`.
- **FAIL nếu:** Auto-skip QD9 không hỏi user, hoặc crash.

#### C1.2.5 — Scope CDG-12 (>20 modules với scope=all)

- **Cách kiểm tra:** Test monorepo 25 modules, `scope=all`.
- **Pass khi:** Hiển thị cảnh báo thời gian 90+ phút, yêu cầu user xác nhận.
- **FAIL nếu:** Auto-continue không cảnh báo.

#### C1.2.6 — Cost CDG-13 (>$5 estimate)

- **Cách kiểm tra:** Test `profile=exhaustive` trên codebase 10K+ symbols.
- **Pass khi:** Hiển thị cost estimate + `AskUserQuestion` confirm.
- **FAIL nếu:** Không hiển thị cost hoặc auto-continue.

#### C1.2.7 — Workload Gate 3 mức phân loại đúng

- **Cách kiểm tra:** Test 3 scenarios:
  - ratio < 0.8 (ít việc)
  - ratio 0.8-1.5 (vừa)
  - ratio > 1.5 (nhiều)
- **Pass khi:**
  - dead_zone (ratio < 0.8): silent continue
  - warn (0.8-1.5): hiển thị prompt yes/no
  - block (>1.5): hiển thị Plan A/B menu 5 options
- **FAIL nếu:** Sai phân loại hoặc thiếu option trong menu.

#### C1.2.8 — CQG Counts Validation (HARD-ENFORCE)

- **Cách kiểm tra:** Sau Phase 3, verify `REMAINING = TOTAL - FIXED - ESCALATED - SKIPPED`.
- **Pass khi:** `REMAINING == 0` (với fresh-run, không phải dry-run).
- **FAIL nếu:** `REMAINING > 0` nhưng workflow vẫn mark completed.

#### C1.2.9 — CQG-2 Browser + Integration Gate

- **Cách kiểm tra:** Test workflow với QD9 signals có `runtime_console_error` severity HIGH.
- **Pass khi:** Gate BLOCKED, hiển thị danh sách blocking signals, yêu cầu accept/reject.
- **FAIL nếu:** Gate bị skip hoặc auto-accept không có user confirm.
- **Headless default:** Phải là `reject` (P1 Correctness — không tự accept console errors).

#### C1.2.10 — CQG-2 reject cycle anti-loop

- **Cách kiểm tra:** Reject CQG-2 3 lần liên tiếp.
- **Pass khi:**
  - Lần 3: `cqg2_reject_cycle >= 2` → force ESCALATE, exit 1 (E001).
  - Regression entries được ghi vào `cqg2-regression-entries.json`.
- **FAIL nếu:** Cho phép reject vô hạn (loop).

#### C1.2.11 — T5 Anti-Invention Rule

- **Cách kiểm tra:** Grep pattern `FIX NOW|FIX IF BUDGET|DEFER MANUAL|DEFER BACKLOG|TODO LATER|FOLLOW-UP|POSTPONE` trong `fix-report.md` và `orchestrator-summary.md`.
- **Pass khi:** 0 matches.
- **FAIL nếu:** Có bất kỳ match nào → trigger retry (max 3) hoặc escalate.

#### C1.2.12 — Sub-skill path validation (12 SKILL.md files)

- **Cách kiểm tra:** Verify tất cả 10 lane skills + 2 sub-skills (triage, execute) có SKILL.md tồn tại và không rỗng.
- **Pass khi:** 12/12 files tồn tại + `jq -e '.'` trên từng `_contract.json`.
- **FAIL nếu:** Thiếu bất kỳ file nào.

---

### Nhóm C1.3 — Status.json Accuracy

**Mục tiêu:** `fix-status.json` phản ánh chính xác trạng thái tại mọi thời điểm, là nền tảng cho `--resume`.

#### C1.3.1 — State machine transitions đúng

- **Cách kiểm tra:** Trace toàn bộ `status` field qua các lần update trong session.
- **Pass khi:** Chuỗi transition hợp lệ:
  ```
  in_progress → paused (khi CDG chờ user)
  paused → in_progress (khi user quay lại)
  in_progress → completed (chỉ sau POST-GATE pass, KHÔNG trước đó)
  ```
- **FAIL nếu:** `in_progress → completed` khi POST-GATE chưa pass, hoặc `completed → in_progress` (không thể đảo ngược).

#### C1.3.2 — next_action luôn khớp với thực tế

- **Cách kiểm tra:** Tại mỗi thời điểm, so sánh `next_action` với bước thực tế đang chờ.
- **Pass khi:** Mapping chính xác:
  - Sau Phase 1 → `workload_gate` hoặc `phase_2_triage`
  - Sau Phase 2 → `cdg_pending` hoặc `safety_check_pending`
  - Sau Safety Check → `phase_3_execute`
  - Sau Phase 3 → `done`
- **FAIL nếu:** `next_action = "phase_3_execute"` nhưng Phase 2 chưa có output.

#### C1.3.3 — phases.phase_N.status cập nhật atomic

- **Cách kiểm tra:** Trong quá trình chạy, kiểm tra không có file `.tmp.*` orphan trong session directory.
- **Pass khi:** Không có file tạm sót lại. Mọi file `fix-status.json` parse được với `jq -e '.'`.
- **FAIL nếu:** File corrupt (`jq -e '.'` fail) hoặc có `.tmp.*` orphan.

#### C1.3.4 — summary_counts chính xác tuyệt đối

- **Cách kiểm tra:** So sánh từng field trong `summary_counts` với `issue-registry.json`:
  ```bash
  TOTAL=$(jq '.issues | length' issue-registry.json)
  FIXED=$(jq '[.issues[] | select(.status=="fixed")] | length' issue-registry.json)
  # ... so sánh với fix-status.json
  ```
- **Pass khi:** Từng field khớp chính xác.
- **FAIL nếu:** Bất kỳ field nào lệch.

#### C1.3.5 — cdg_reject_counts không reset khi resume

- **Cách kiểm tra:** Tạo session có CDG reject → kill process → resume.
- **Pass khi:** `cdg_reject_counts[cdg_id]` giữ nguyên giá trị trước khi kill.
- **FAIL nếu:** Counter bị reset về 0 hoặc mất field.

#### C1.3.6 — updated_at tăng đơn điệu

- **Cách kiểm tra:** So sánh `updated_at` qua các lần update.
- **Pass khi:** Timestamp tăng (hoặc bằng) qua mỗi lần update.
- **FAIL nếu:** Timestamp lùi.

#### C1.3.7 — execution_mode_decision.transitions ghi nhận đúng

- **Cách kiểm tra:** Test resume với số lượng issues thay đổi → verify transition log.
- **Pass khi:** Mỗi lần switch inline↔agent_dispatch có entry với `reason`, `from`, `to`, `timestamp`.
- **FAIL nếu:** Switch mode nhưng không có transition entry.

---

### Nhóm C1.4 — Signal Completeness

**Mục tiêu:** Mọi probe cho mọi dimension được chọn phải thực thi. Không bỏ sót, không silent failure.

#### C1.4.1 — Mỗi dimension có signals.json

- **Cách kiểm tra:** Đọc `DIMS_ARRAY` từ `fix-status.json.flags.dimensions`, kiểm tra từng file.
  ```bash
  for dim in $(jq -r '.flags.dimensions' fix-status.json); do
    test -f "lanes/$dim/signals.json" || echo "MISSING: $dim"
  done
  ```
- **Pass khi:** Mọi dim được chọn đều có `signals.json`.
- **FAIL nếu:** Thiếu signals.json cho bất kỳ dim nào.

#### C1.4.2 — probes_executed == probes_total

- **Cách kiểm tra:** Đọc `lane-status.json` cho từng dimension.
- **Pass khi:** `probes_executed == probes_total` cho mọi dimension.
- **WARN khi:** `probes_executed < probes_total` nhưng có `skip_reason` hợp lệ (stack mismatch).
- **FAIL nếu:** `probes_executed < probes_total` mà không có skip reason.

#### C1.4.3 — Probe failure được ghi nhận đầy đủ

- **Cách kiểm tra:** Đọc `probe-failures.log`.
- **Pass khi:** Mọi probe fail (exit code != 0) có entry với: `probe_id`, `dimension`, `exit_code`, `stderr_summary`, `timestamp`.
- **FAIL nếu:** Probe fail mà không có entry trong log.

#### C1.4.4 — Stack-mismatch probes skip đúng cách

- **Cách kiểm tra:** Chạy React-specific probe trên Vue project.
- **Pass khi:** Probe skip với `skip_reason: "stack_mismatch"` (không crash).
- **FAIL nếu:** Probe crash hoặc emit signals sai ngữ cảnh.

#### C1.4.5 — Static + non-static merge không mất dữ liệu

- **Cách kiểm tra:** Đếm signals từ raw static output + raw non-static output, so với `signals.json`.
- **Pass khi:** Tổng khớp (sau dedup).
- **FAIL nếu:** Signals từ static probe biến mất sau merge.

#### C1.4.6 — QD3 Security không dùng scan cache

- **Cách kiểm tra:** Chạy QD3 probe 2 lần → verify output khác nhau (timestamp, scan time) chứng tỏ chạy fresh.
- **Pass khi:** Cả 2 lần đều chạy fresh, không đọc từ cache.
- **FAIL nếu:** Lần 2 trả về cache hit (ADR-22 rule 6 vi phạm).

#### C1.4.7 — Không hardcode QD[1-8] (regression v9.0.0)

- **Cách kiểm tra:** Grep pattern `QD[1-8]` (không có QD9, QD10) trong các vị trí hạ tầng:
  - `SKILL.md`
  - `procedures/phase1-engine.md`
  - `procedures/post-gate-completion.md`
  - `_shared/lane_dispatch.py`
  - `_shared/signal_aggregator.py`
  - `_shared/profiles.json`
- **Pass khi:** Mọi vị trí dùng dynamic dimension list (từ profile resolver), không hardcode range.
- **FAIL nếu:** Còn pattern `QD[1-8]` không bao gồm QD9/QD10.

---

### Nhóm C1.5 — Fix Correctness & Regression Prevention

**Mục tiêu:** Fixes thực sự giải quyết vấn đề, không tạo ra lỗi mới.

#### C1.5.1 — Traceability: fix → issue → REQ-ID

- **Cách kiểm tra:** Chọn ngẫu nhiên 5 fixes từ `fix-log.json`, trace ngược.
- **Pass khi:** Mỗi fix có chain: `fix-log.json` → `issue-registry.json` → REQ-ID (trong code) không đứt.
- **FAIL nếu:** Có fix không trace được về REQ-ID.

#### C1.5.2 — Post-fix regression probe pass

- **Cách kiểm tra:** Chạy `llm-probe-regression.md` sau khi Phase 3 hoàn thành.
- **Pass khi:** 0 signals mới với severity CRITICAL hoặc HIGH.
- **WARN khi:** Có signals MEDIUM hoặc LOW mới (không block nhưng cần review).
- **FAIL nếu:** Có signals CRITICAL hoặc HIGH mới → fix gây regression.

#### C1.5.3 — Pre-implementation safety không bị bypass

- **Cách kiểm tra:** Kiểm tra log — trước mỗi lần sửa code, 4 checks phải pass.
- **Pass khi:** 4/4 checks pass trước mỗi code change.
- **FAIL nếu:** Phát hiện code change không có safety check result trước đó.

#### C1.5.4 — CQG-2 regression entries được fix khi resume

- **Cách kiểm tra:** Resume session với `next_action: "phase3_regression_fix"`.
- **Pass khi:** Tất cả entries trong `cqg2-regression-entries.json` có `status: "fixed"` sau khi Phase 3 hoàn thành.
- **FAIL nếu:** Còn regression entry `status: "open"`.

---

### Nhóm C1.6 — Resume Reliability

**Mục tiêu:** `--resume` khôi phục chính xác trạng thái, không mất dữ liệu, không chạy lại.

#### C1.6.1 — Resume đúng session

- **Cách kiểm tra:** Tạo 3 sessions (2 `in_progress`, 1 `completed`) → `--resume` không `--session`.
- **Pass khi:** Pick latest `in_progress` matching scope.
- **FAIL nếu:** Pick session `completed` hoặc session không matching scope.

#### C1.6.2 — Resume đúng checkpoint

- **Cách kiểm tra:** Kill process giữa Phase 2 → resume.
- **Pass khi:** Tiếp tục từ `next_action` chính xác (vd: `phase_2_triage`), không chạy lại Phase 1.
- **FAIL nếu:** Chạy lại Phase 1 hoặc skip Phase 2.

#### C1.6.3 — Lock check khi resume

- **Cách kiểm tra:** Session đang active (lock fresh < 60 min) → `--resume` từ process khác.
- **Pass khi:** Từ chối với message rõ ràng + hướng dẫn check/release.
- **FAIL nếu:** Cho phép 2 process cùng chạy trên 1 session.

#### C1.6.4 — Stale lock takeover

- **Cách kiểm tra:** Lock > 60 min → resume.
- **Pass khi:** Warning "stale lock detected" + takeover thành công.
- **FAIL nếu:** Không takeover được lock cũ.

#### C1.6.5 — Cross-resume mode switching

- **Cách kiểm tra:** Session chạy lần đầu với 250 issues (agent_dispatch) → fix 200 issues → kill → resume.
- **Pass khi:** Re-evaluate threshold: 50 issues < 200 → switch về inline. Transition được log.
- **FAIL nếu:** Giữ nguyên agent_dispatch dù issues đã giảm dưới ngưỡng.

#### C1.6.6 — Sub-skill resume hoạt động độc lập

- **Cách kiểm tra:** `/wf-fix-triage --resume` hoặc `/wf-fix-execute --resume`.
- **Pass khi:** Đọc `last_checkpoint`, skip batch đã done, tiếp tục từ batch tiếp theo.
- **FAIL nếu:** Chạy lại từ đầu.

#### C1.6.7 — fix-status.json không corrupt sau crash

- **Cách kiểm tra:** Kill -9 process giữa lúc đang write `fix-status.json` → kiểm tra file.
- **Pass khi:** File vẫn là JSON valid (`jq -e '.'` pass) — nhờ atomic write pattern (`.tmp.$$` + `mv`).
- **FAIL nếu:** File corrupt, không parse được.

---

### Nhóm C1.7 — Session Isolation & Concurrency Safety

**Mục tiêu:** Nhiều session không ghi đè lẫn nhau. Lock ngăn concurrent modification.

#### C1.7.1 — POSIX lock atomic

- **Cách kiểm tra:** Chạy 2 process `acquire_lock` đồng thời trên cùng session.
- **Pass khi:** Chỉ 1 process acquire thành công. Process kia nhận message lỗi.
- **FAIL nếu:** Cả 2 cùng acquire được.

#### C1.7.2 — Heartbeat duy trì lock

- **Cách kiểm tra:** Start session → đợi 5 phút → check lock mtime.
- **Pass khi:** Lock mtime được cập nhật < 60s.
- **FAIL nếu:** Lock mtime cũ > 120s (heartbeat không chạy).

#### C1.7.3 — Cross-language lock (Python ↔ Bash)

- **Cách kiểm tra:** Python `lane_dispatch.py` đang giữ signals.json lock → Bash `signal-emit.md` cố ghi.
- **Pass khi:** Bash chờ lock release, không ghi đè.
- **FAIL nếu:** Bash ghi đè dữ liệu Python đang viết.

#### C1.7.4 — Trap cleanup khi exit

- **Cách kiểm tra:** Kill process (SIGTERM) → kiểm tra lock còn tồn tại không.
- **Pass khi:** Lock được release, heartbeat daemon dừng.
- **FAIL nếu:** Orphan lock còn lại.

#### C1.7.5 — Session directory isolation

- **Cách kiểm tra:** Chạy 2 sessions đồng thời (khác scope) → verify không file nào bị ghi đè.
- **Pass khi:** Mỗi session trong `sessions/{id}/` riêng, không cross-contamination.
- **FAIL nếu:** File từ session A xuất hiện trong session B.

---

### Nhóm C1.8 — Graceful Degradation

**Mục tiêu:** Khi thiếu công cụ hoặc điều kiện không đủ, skill phải fallback rõ ràng, không crash.

#### C1.8.1 — Thiếu Playwright (QD9 browser probes)

- **Cách kiểm tra:** Chạy trên môi trường không có Playwright.
- **Pass khi:** QD9 skip với `skip_reason: "playwright_unavailable"`, lane-status.json ghi rõ.
- **FAIL nếu:** Crash hoặc hang.

#### C1.8.2 — Thiếu GitNexus

- **Cách kiểm tra:** Chạy trên project không có GitNexus index.
- **Pass khi:** Fallback về Grep cho impact analysis. Workflow continue.
- **FAIL nếu:** Từ chối chạy hoặc crash.

#### C1.8.3 — Thiếu Serena

- **Cách kiểm tra:** Chạy trên môi trường không có Serena MCP.
- **Pass khi:** Fallback về Grep cho symbol search. Workflow continue.
- **FAIL nếu:** Crash hoặc loop tìm Serena.

#### C1.8.4 — Registry rỗng hoặc không tồn tại

- **Cách kiểm tra:** Chạy trên project không có `.mc-data/docs/_meta/req-registry.json`.
- **Pass khi:** Cảnh báo rõ ràng + STOP (không continue với dữ liệu giả).
- **FAIL nếu:** Continue với registry rỗng, tạo ra false positives.

#### C1.8.5 — Source directory không tồn tại

- **Cách kiểm tra:** Chạy với `--scope` chỉ định directory không tồn tại.
- **Pass khi:** STOP sớm với message rõ ràng.
- **FAIL nếu:** Chạy tiếp và tạo ra signals rỗng mà không báo lỗi.

---

### Nhóm C1.9 — Deep Scan Coverage & Component Exhaustiveness

**Mục tiêu:** Skill phải quét toàn bộ và phát hiện lỗi trong MỌI thành phần của module/hệ thống trong phạm vi được chỉ định. Không bỏ sót thành phần nào, kể cả các thành phần lồng nhau (popup → form → pagination → nested dialog → ...). Đây là tiêu chí **sống còn** — nếu skill bỏ sót khu vực, mọi chỉ số chất lượng khác là vô nghĩa.

> **Nguyên tắc cốt lõi:** Một module/hệ thống bao gồm nhiều tầng thành phần. Mở popup ra có form. Form có pagination. Pagination có rows. Mỗi row có buttons. Skill PHẢI đi hết chiều sâu này, không dừng ở bề mặt.

#### C1.9.1 — UI Component Discovery Exhaustiveness

- **Cách kiểm tra:** Đối chiếu danh sách components được scan với tất cả components thực tế trong source code:
  ```bash
  # Đếm tất cả interactive elements trong source
  grep -rnE '<(button|Button|a href|input|select|textarea|form|dialog|modal|popup|sheet|drawer|menu|dropdown|combobox|tabs|accordion|toast|tooltip|carousel)' src/
  # So sánh với danh sách components trong kết quả scan
  ```
- **Pass khi:** 100% interactive elements được phát hiện và kiểm tra.
- **FAIL nếu:** Có bất kỳ button, form, popup, sheet, dialog, dropdown, menu, tabs, accordion, toast, tooltip, carousel nào bị bỏ sót trong scope.
- **WARN khi:** Tỷ lệ phát hiện 90-99% (cho phép với dynamic/lazy-loaded components).

#### C1.9.2 — Nested Component Drill-Down (Quét đệ quy thành phần lồng nhau)

- **Cách kiểm tra:** Với mỗi popup/sheet/modal/dialog được phát hiện, kiểm tra xem nội dung bên trong có được scan không.
- **Pass khi:** Mọi thành phần con bên trong popup/sheet/modal/dialog được scan đầy đủ:
  - Form fields bên trong popup → được kiểm tra validation, error states
  - Table/list bên trong sheet → được kiểm tra pagination, sorting, filtering
  - Buttons/CTAs bên trong dialog → được kiểm tra click behavior, loading states
  - Nested dialog (dialog mở từ trong dialog) → được phát hiện và scan
  - Tabs/accordion bên trong popup → từng tab/panel được scan
- **FAIL nếu:** Popup được phát hiện nhưng form bên trong bị bỏ qua. Sheet được phát hiện nhưng pagination không được test. Nested dialog không được scan.

#### C1.9.3 — Feature Boundary Completeness

- **Cách kiểm tra:** Với mỗi feature trong scope, vẽ flow diagram đầy đủ → đối chiếu với kết quả scan.
- **Pass khi:** Mỗi feature được quét bao gồm ĐỦ các sub-flows:
  ```
  Ví dụ feature "Quản lý người dùng" phải bao gồm:
  ├── Màn hình danh sách: table, pagination, search, filter, sort
  ├── Nút "Thêm mới" → mở sheet/popup
  │   ├── Form: các field, validation, error messages
  │   ├── Nút "Lưu": loading state, success/error handling
  │   └── Nút "Hủy": đóng sheet, reset form
  ├── Nút "Sửa" trên mỗi row → mở sheet/popup (tương tự Thêm mới)
  ├── Nút "Xóa" → confirm dialog → loading → refresh list
  └── Các trạng thái: empty list, loading list, error list
  ```
- **FAIL nếu:** Feature được scan nhưng thiếu sub-flow (vd: chỉ scan list, không scan popup thêm mới; hoặc scan form nhưng không test validation).

#### C1.9.4 — Dynamic/Conditional Content Discovery

- **Cách kiểm tra:** Đếm số lượng conditional renders (`v-if`, `ngIf`, `{condition && ...}`, `hidden`, `display:none`) trong source → verify tất cả được scan.
- **Pass khi:**
  - Content hiển thị có điều kiện (permission-based, role-based, state-based) được phát hiện
  - Content lazy-loaded (dynamic import, code splitting) được phát hiện
  - Content render sau API response được phát hiện
  - Content trong các tab/bước chưa active được phát hiện
- **FAIL nếu:** Conditional content tồn tại trong source nhưng không có trong kết quả scan.

#### C1.9.5 — Interactive Element State Coverage

- **Cách kiểm tra:** Với mỗi interactive element, kiểm tra các trạng thái được test.
- **Pass khi:** Mỗi element được test ở tối thiểu các trạng thái:
  - **Button:** enabled, disabled, loading, clicked (success/error response)
  - **Form field:** empty, filled, invalid, disabled, readonly
  - **Form:** submitting, validation error, submit success, submit error
  - **Popup/Sheet/Dialog:** opening, open (idle), submitting, closing, closed
  - **Table/List:** empty, loading, populated, error, paginating
  - **Dropdown/Combobox:** closed, open, searching, selected, no results
- **FAIL nếu:** Element chỉ được test ở 1 trạng thái mặc định, bỏ qua error/loading/empty states.

#### C1.9.6 — Cross-Component State Flow Detection

- **Cách kiểm tra:** Kiểm tra các flow mà hành động trên component A gây thay đổi trên component B.
- **Pass khi:** Skill phát hiện và kiểm tra:
  - Popup submit → parent list refresh → item mới xuất hiện
  - Delete confirm → item biến mất khỏi list
  - Filter thay đổi → table reload
  - Tab switch → nội dung tab mới load
  - Form field thay đổi → field khác update (cascading)
- **FAIL nếu:** Cross-component interactions không được phát hiện hoặc không được test.

#### C1.9.7 — Module/System Boundary Coverage

- **Cách kiểm tra:** So sánh file tree của scope với danh sách files được scan.
- **Pass khi:** 100% files trong scope được scan. Mọi route/endpoint trong scope được probe.
- **FAIL nếu:** File hoặc route nào trong scope bị bỏ qua mà không có skip reason.
- **WARN khi:** File config/test/document bị skip (hợp lệ, nhưng cần ghi rõ skip reason).

#### C1.9.8 — Pagination & Infinite Scroll Exhaustiveness

- **Cách kiểm tra:** Với mọi table/list có pagination hoặc infinite scroll, kiểm tra các trang/phân đoạn.
- **Pass khi:**
  - Pagination: test page 1, page 2, page cuối, "không có dữ liệu"
  - Infinite scroll: test scroll → load more, scroll → hết dữ liệu
  - Page size change: test đổi page size → list reload đúng
  - Sort: test click sort → list reload đúng thứ tự
  - Filter kết hợp pagination: filter + chuyển trang → kết quả đúng
- **FAIL nếu:** Table có pagination nhưng chỉ test page 1.

#### C1.9.9 — Hidden/Implicit UI Patterns Detection

- **Cách kiểm tra:** Grep các pattern UI ẩn trong source:
  - Event handlers: `onClick`, `onSubmit`, `onChange`, `onBlur`, `onFocus`
  - Keyboard shortcuts: `onKeyDown`, `onKeyPress`, keyboard event listeners
  - Gesture handlers: swipe, pinch, drag, drop
  - Timer-based: `setTimeout`, `setInterval`, `requestAnimationFrame`
  - WebSocket/SSE: real-time update listeners
- **Pass khi:** Tất cả các event handler được phát hiện và có probe tương ứng kiểm tra behavior.
- **FAIL nếu:** Event handler tồn tại trong source nhưng không có probe kiểm tra.

#### C1.9.10 — Scan Depth Verification (Post-Scan Audit)

- **Cách kiểm tra:** Sau khi scan hoàn tất, chạy audit ngược:
  ```bash
  # Đếm tổng số components trong source
  TOTAL_COMPONENTS=$(grep -rE 'export (default |)function |export (default |)class |defineComponent|@Component' src/ | wc -l)
  # Đếm số components trong issue-registry.json
  SCANNED_COMPONENTS=$(jq '[.issues[].location.file] | unique | length' issue-registry.json)
  # Tính coverage
  COVERAGE=$(echo "scale=2; $SCANNED_COMPONENTS / $TOTAL_COMPONENTS * 100" | bc)
  ```
- **Pass khi:** Coverage ≥ 95% components trong scope.
- **WARN khi:** Coverage 85-94%.
- **FAIL nếu:** Coverage < 85%.

---

### Nhóm C1.10 — QD11: Business Completeness & Enhancement

**Mục tiêu:** Skill phải phát hiện được logic nghiệp vụ **bị thiếu** (không chỉ bị sai) và đề xuất cải thiện UX/UI dựa trên so sánh cross-module + domain knowledge. Điểm khác biệt cốt lõi với QD2 (Business Correctness): QD2 hỏi "cái đang làm có đúng không?", QD11 hỏi **"cái đang làm có đủ không? có thiếu gì so với chuẩn không?"**

> **Nguyên tắc cốt lõi:** Mọi suggestion từ QD11 là **đề xuất**, không phải bug. Cần user APPROVE trước khi implement. Không tự động sửa.

#### C1.10.1 — Cross-Module Pattern Comparison Engine

- **Cách kiểm tra:** Chạy QD11 trên project có ≥ 2 module cùng domain (vd: 2 module CRUD có entity "khách hàng").
- **Pass khi:** Skill tự động phát hiện và so sánh:
  - Entity forms: số lượng và loại fields giữa các module
  - List/table views: columns, filters, sorting options
  - Workflow steps: số bước, approvers, notifications
  - Action buttons: loại và số lượng nút tác vụ
- **FAIL nếu:** Không phát hiện được sự khác biệt giữa 2 module cùng domain.
- **SKIP hợp lệ khi:** Chỉ có 1 module trong scope (không có gì để so sánh).

#### C1.10.2 — Form Field Completeness Detection

- **Cách kiểm tra:** Với mỗi form entity, so sánh fields với module tham chiếu.
- **Pass khi:** Phát hiện và báo cáo:
  - Field có trong Module A nhưng thiếu trong Module B → `MISSING_FIELD` signal
  - Field cùng tên nhưng khác kiểu dữ liệu → `TYPE_MISMATCH` signal
  - Field cùng tên nhưng khác validation → `VALIDATION_GAP` signal
- **FAIL nếu:** Form thiếu 3+ fields so với tham chiếu nhưng không có signal.
- **WARN khi:** Chỉ thiếu 1-2 fields (có thể là intentional simplification).

#### C1.10.3 — Action Button Sufficiency Analysis

- **Cách kiểm tra:** Với mỗi form/detail view, kiểm tra bộ nút tác vụ.
- **Pass khi:** Phát hiện thiếu các nút phổ biến dựa trên cross-module comparison:
  - **Form:** Save/Submit, Cancel/Back, Reset (nếu module khác có)
  - **Detail view:** Edit, Delete, Back to List, Export/Print (nếu module khác có)
  - **List:** Add New, Export, Import, Batch Action (nếu module khác có)
  - **Workflow:** Approve, Reject, Request Change, Delegate (nếu module khác có)
- **FAIL nếu:** Thiếu nút tác vụ quan trọng (Save/Cancel/Delete) mà không có signal.
- **Nguyên tắc:** Chỉ đề xuất dựa trên **pattern có thật trong codebase**, không đề xuất dựa trên lý thuyết.

#### C1.10.4 — List/Table Feature Completeness

- **Cách kiểm tra:** Với mỗi table/list view, so sánh tính năng với module tham chiếu.
- **Pass khi:** Phát hiện thiếu:
  - **Search:** search bar có trong Module A nhưng thiếu trong Module B
  - **Column filter:** filter theo cột có trong A nhưng thiếu trong B
  - **Sort:** sort theo cột có trong A nhưng thiếu trong B
  - **Pagination:** pagination có trong A nhưng thiếu trong B
  - **Column visibility:** toggle cột có trong A nhưng thiếu trong B
  - **Export:** CSV/Excel export có trong A nhưng thiếu trong B
- **FAIL nếu:** Table 50+ rows không có pagination nhưng không có signal.
- **WARN khi:** Table < 10 rows không có pagination (có thể intentional).

#### C1.10.5 — Workflow Step Completeness

- **Cách kiểm tra:** Với mỗi workflow/process flow, so sánh số bước với module tham chiếu.
- **Pass khi:** Phát hiện thiếu:
  - Approval step có trong Module A nhưng thiếu trong Module B
  - Notification/email trigger có trong A nhưng thiếu trong B
  - Status transition (vd: "Draft → Submitted → Approved → Rejected") thiếu trạng thái so với A
  - Audit log/history có trong A nhưng thiếu trong B
- **FAIL nếu:** Workflow thiếu 2+ steps so với tham chiếu nhưng không có signal.

#### C1.10.6 — Domain-Specific Field Requirements

- **Cách kiểm tra:** Đọc domain knowledge từ `.claude/references/team-expert/[domain]/` → đối chiếu với entity forms.
- **Pass khi:** Dựa trên domain knowledge, phát hiện field bắt buộc theo domain bị thiếu:
  - **E-commerce/Retail:** product có thiếu SKU, price, inventory, category?
  - **HR:** employee có thiếu department, position, start_date?
  - **Finance:** transaction có thiếu amount, currency, date, category?
  - **Logistics:** shipment có thiếu tracking_number, origin, destination, status?
  - **Healthcare:** patient có thiếu medical_record_number, dob, blood_type?
- **FAIL nếu:** Domain knowledge có sẵn nhưng không được tham chiếu.
- **SKIP hợp lệ khi:** Project không có domain knowledge files.

#### C1.10.7 — Cross-Module Consistency Enforcement

- **Cách kiểm tra:** So sánh entity definitions giữa các module.
- **Pass khi:** Phát hiện:
  - Cùng entity name nhưng khác field name → `NAMING_INCONSISTENCY`
  - Cùng business concept nhưng khác data type → `TYPE_INCONSISTENCY`
  - Cùng validation rule nhưng khác error message → `MESSAGE_INCONSISTENCY`
  - Cùng status flow nhưng khác enum values → `ENUM_INCONSISTENCY`
- **FAIL nếu:** Entity giống nhau giữa 2 module nhưng không có consistency check.

#### C1.10.8 — Enhancement Suggestion Quality Control

- **Cách kiểm tra:** Audit ngẫu nhiên 10 suggestions từ QD11 output.
- **Pass khi:** Mỗi suggestion có đủ:
  - `evidence`: module/file tham chiếu (cross-reference cụ thể)
  - `rationale`: lý do đề xuất (1-2 câu, tiếng Việt)
  - `severity`: đúng mức — `HIGH` (gap từ registry/domain), `MEDIUM` (thiếu so với module khác), `LOW` (nice-to-have UX)
  - `confidence`: `high` (pattern rõ ràng), `medium` (có pattern nhưng có thể intentional), `low` (heuristic)
- **FAIL nếu:** > 20% suggestions thiếu evidence hoặc severity sai — coi như fantasy reporting.

#### C1.10.9 — QD11 CDG Gate: Enhancement Review

- **Cách kiểm tra:** Chạy QD11 trên project có suggestions → kiểm tra gate.
- **Pass khi:**
  - Mọi suggestion severity `HIGH` → hiển thị CDG gate, yêu cầu user ACCEPT/REJECT từng cái
  - Mọi suggestion severity `MEDIUM` → hiển thị summary, user có thể ACCEPT ALL / REJECT ALL / REVIEW
  - Suggestion `LOW` → ghi vào `enhancement-suggestions.json`, không block workflow
  - CDG token được ghi vào `cdg-tokens.json` cho từng suggestion được accept
  - User REJECT → không implement, ghi lại lý do reject
- **FAIL nếu:** QD11 tự động implement suggestion mà không có user approval.

#### C1.10.10 — QD11 Skip & Applicability Conditions

- **Cách kiểm tra:** Test các điều kiện skip.
- **Pass khi:**
  - **Skip:** scope chỉ có 1 module (không có cross-module comparison)
  - **Skip:** `interface_type=api-only` (không có UI để đánh giá form/UX)
  - **Skip:** profile=quick (QD11 chỉ chạy từ standard trở lên)
  - **Không skip:** 2+ modules cùng domain, có UI, profile ≥ standard
- **FAIL nếu:** QD11 skip mà không có reason, hoặc chạy khi không nên chạy.

---

## TẦNG 2: Tối Ưu Thời Gian & Song Song Hóa (P2 — PERFORMANCE)

> **KHÔNG BLOCKING** — nhưng fail > 30% → WARN.
> **Nguyên tắc:** Mọi tối ưu song song hóa PHẢI tuân thủ CORE-025 (ownership, isolated scope, stable contract, re-verification).
> **Tổng:** 4 nhóm, 13 checkpoints. **Trọng số:** 25%.

---

### Nhóm C2.1 — Parallel Lane Execution

#### C2.1.1 — max_parallel=3 được tôn trọng

- **Cách kiểm tra:** Chạy với 6+ dimensions → đếm concurrent probes trong log.
- **Pass khi:** Tối đa 3 probe chạy đồng thời tại mọi thời điểm.
- **FAIL nếu:** > 3 probe concurrent → có thể gây quá tải.

#### C2.1.2 — Token bucket + backpressure ngăn quá tải

- **Cách kiểm tra:** Chạy 10 dimensions → kiểm tra không có probe timeout do thiếu token.
- **Pass khi:** Không probe nào timeout với lý do "token_bucket_empty".
- **WARN khi:** Có probe chờ token > 30s.

#### C2.1.3 — Write scope tách biệt

- **Cách kiểm tra:** Verify `lanes/QD1/` và `lanes/QD2/` không có file chung.
- **Pass khi:** Mỗi lane ghi riêng directory, không shared mutable state.
- **FAIL nếu:** 2 lane ghi chung 1 file.

---

### Nhóm C2.2 — Static/Runtime Probe Separation

#### C2.2.1 — Static probes hoàn thành trước non-static

- **Cách kiểm tra:** Check execution order trong log.
- **Pass khi:** Tất cả static probes COMPLETE trước khi non-static START.
- **FAIL nếu:** Static và non-static chạy xen kẽ (gây conflict merge).

#### C2.2.2 — Non-static probes chỉ chạy probes pending

- **Cách kiểm tra:** Check `PENDING_PROBES_JSON` từ `wf-fix-merge-non-static-probes.sh`.
- **Pass khi:** Chỉ probes có type `runtime`, `agent`, `runtime+agent` và chưa có output mới được chạy.
- **FAIL nếu:** Chạy lại static probes.

#### C2.2.3 — Browser probes sequential per app (monorepo QD9)

- **Cách kiểm tra:** Test monorepo 3 apps → verify QD9 execution order.
- **Pass khi:** Browser probes chạy tuần tự cho từng app, không song song.
- **FAIL nếu:** 2 browser probes chạy song song (xung đột port).

---

### Nhóm C2.3 — Agent Dispatch Decision

#### C2.3.1 — Ngưỡng kích hoạt chính xác

- **Cách kiểm tra:** Test 3 scenarios:
  - 50 issues → inline
  - 250 issues → agent_dispatch
  - Context > 70% → agent_dispatch
- **Pass khi:** Decision khớp với threshold rules.
- **FAIL nếu:** 250 issues vẫn inline (gây context overflow).

#### C2.3.2 — Decision reason được ghi nhận

- **Cách kiểm tra:** Đọc `execution_mode_decision.reason` trong `fix-status.json`.
- **Pass khi:** Reason rõ ràng (vd: `"issue_count=250 > threshold=200"`).
- **FAIL nếu:** Reason rỗng hoặc null.

---

### Nhóm C2.4 — Checkpoint Granularity

#### C2.4.1 — Checkpoint sau mỗi sub-batch (agent_dispatch)

- **Cách kiểm tra:** Chạy agent_dispatch với 100 issues → đếm checkpoint updates.
- **Pass khi:** Ít nhất 10 checkpoint updates (mỗi 10 issues).
- **FAIL nếu:** Chỉ 1 checkpoint lúc bắt đầu và 1 lúc kết thúc.

#### C2.4.2 — Mất tối đa 1 batch khi crash

- **Cách kiểm tra:** Kill process sau khi fix 25/100 issues → resume → đếm issues cần làm lại.
- **Pass khi:** ≤ 10 issues phải fix lại.
- **FAIL nếu:** > 10 issues phải làm lại.

---

### Nhóm C2.5 — Workload Gate Accuracy

#### C2.5.1 — estimated_minutes khớp thực tế

- **Cách kiểm tra:** So sánh `workload_gate.estimated_minutes` với actual runtime từ trace log.
- **Pass khi:** Sai lệch ≤ 50%.
- **WARN khi:** Sai lệch 50-100%.
- **FAIL nếu:** Sai lệch > 100% (estimate vô dụng).

#### C2.5.2 — Codebase-size awareness

- **Cách kiểm tra:** Test codebase 10K symbols → verify `max_workload_size` giảm một nửa.
- **Pass khi:** Workload size ≤ 3 (thay vì 7) cho codebase lớn.
- **FAIL nếu:** Workload size không điều chỉnh.

---

## TẦNG 3: Tối Ưu Token & Context (P3 — EFFICIENCY)

> **KHÔNG BLOCKING** — nhưng fail > 50% → WARN.
> **Nguyên tắc:** Các tối ưu token **KHÔNG được phép** làm giảm khả năng phát hiện lỗi. Nếu một tối ưu token có nguy cơ bỏ sót issues → **bỏ tối ưu đó, giữ logic đầy đủ.**
> **Tổng:** 4 nhóm, 11 checkpoints. **Trọng số:** 15%.

---

### Nhóm C3.1 — Runtime File Content Purity

**Mục tiêu:** File `*.md` runtime chỉ chứa nội dung cần cho thực thi, không chứa rác lịch sử.

#### C3.1.1 — Không có changelog/version history trong procedure

- **Cách kiểm tra:** Grep pattern `(v[0-9]+\.[0-9]+\.[0-9]+|Changelog|Version history|## [0-9]+\.[0-9]+\.[0-9]+)` trong `procedures/*.md`.
- **Pass khi:** 0 matches về version history.
- **WARN khi:** Có version tag trong comment (vd: `(v9.0.3 W3.4)` trong post-gate-completion.md).
- **FAIL nếu:** Có changelog section riêng dài > 3 dòng.

#### C3.1.2 — Không có nội dung historical context

- **Cách kiểm tra:** Grep pattern `(đã fix|đã thay đổi từ|trước đây|trong version|cũ hơn|legacy behavior)`.
- **Pass khi:** 0 matches.
- **FAIL nếu:** > 3 matches (gây nhiễu context).

#### C3.1.3 — Không có comment thừa kiểu TODO/FIXME chưa resolve

- **Cách kiểm tra:** Grep pattern `TODO|FIXME|HACK|XXX` trong `procedures/` và `prompts/`.
- **Pass khi:** 0 matches, hoặc mỗi match có lý do chính đáng + ngày hết hạn.
- **WARN khi:** Có TODO không có ngày.

---

### Nhóm C3.2 — Procedure Lazy-Loading

#### C3.2.1 — Procedure chỉ load khi cần

- **Cách kiểm tra:** Trace xem procedure nào được đọc trong 1 session cụ thể.
- **Pass khi:**
  - `--status` → chỉ load `status-display.md`
  - `--resume` → load `resume-routing.md` + `session-dir.md` + `lock-management.md`
  - Normal run → không load `resume-routing.md` hoặc `status-display.md`
- **FAIL nếu:** Load procedure không liên quan đến flow hiện tại.

#### C3.2.2 — SKILL.md không nhúng nội dung procedure

- **Cách kiểm tra:** So sánh kích thước SKILL.md (~44KB) với tổng procedures (~175KB).
- **Pass khi:** SKILL.md chứa chủ yếu dispatch logic + references, không chứa nội dung chi tiết.
- **WARN khi:** SKILL.md > 50KB.

---

### Nhóm C3.3 — Bash Delegation Effectiveness

#### C3.3.1 — Deterministic logic được delegate

- **Cách kiểm tra:** Audit procedure files — mọi pure enumeration, regex parsing, JSON building đã delegate chưa.
- **Pass khi:** Static probes logic nằm trong script `.claude/scripts/wf-fix-probe-static-*.sh`, không inline trong procedure.
- **WARN khi:** Phát hiện logic deterministic > 30 dòng inline trong procedure.

#### C3.3.2 — Inline fallback tồn tại và không block

- **Cách kiểm tra:** Kiểm tra mỗi probe có fallback block khi bash script fail.
- **Pass khi:** Fallback ≤ 20 dòng, emit empty signals + `skip_reason`, không crash.
- **FAIL nếu:** Không có fallback → bash script fail là đứt cả lane.

---

### Nhóm C3.4 — Orchestrator Summary & Report

#### C3.4.1 — orchestrator-summary.md đúng format

- **Cách kiểm tra:** Đọc `orchestrator-summary.md`.
- **Pass khi:**
  - Tiếng Việt, dễ hiểu cho non-specialist
  - Có đủ: scope, profile, flags, execution mode, coverage, 3 bước kết quả, issues remaining, escalations, session, thời gian
  - Có dòng WARN nếu `runtime_warn: true`
  - Có dòng info QD9/QD10 nếu skip hoặc not-selected
- **FAIL nếu:** Thiếu bất kỳ phần bắt buộc nào.

#### C3.4.2 — Không chứa thuật ngữ bị cấm

- **Cách kiểm tra:** Grep forbidden terms trong `orchestrator-summary.md`.
- **Pass khi:** 0 matches với pattern `FIX NOW|FIX IF BUDGET|DEFER MANUAL|DEFER BACKLOG|TODO LATER|FOLLOW-UP|POSTPONE`.
- **FAIL nếu:** Có match.

#### C3.4.3 — fix-impact.json đúng schema

- **Cách kiểm tra:** Validate `fix-impact.json`:
  ```bash
  jq -e '.schema == "fix-impact-v1"' fix-impact.json
  jq -e '.fix_summary.deferred != null' fix-impact.json
  jq -e '.audit_chain.checksum_sha256 != null' fix-impact.json
  ```
- **Pass khi:** Tất cả fields bắt buộc tồn tại + đúng type.
- **FAIL nếu:** Thiếu field bắt buộc.

---

### Nhóm C3.5 — Cross-Skill Artifact Integrity

#### C3.5.1 — fix-impact.json được consumer đọc được

- **Cách kiểm tra:** Kiểm tra consumer skills có parse được file không:
  - `wf-verify-sync --from-fix-bugs=<SID>` đọc `fix-impact.json`
  - `wf-prepare-deployment --from-fix-bugs=<SID>` đọc `fix-impact.json`
- **Pass khi:** Cả 2 consumers parse thành công.
- **FAIL nếu:** Consumer crash vì schema mismatch.

---

## Bảng Tổng Hợp

| Tier | Nhóm | Số CP | Blocking | Trọng số |
|------|------|-------|----------|----------|
| **P1** | C1.1 — Phase Execution Completeness | 7 | YES | |
| **P1** | C1.2 — Gate Enforcement | 12 | YES | |
| **P1** | C1.3 — Status.json Accuracy | 7 | YES | |
| **P1** | C1.4 — Signal Completeness | 7 | YES | |
| **P1** | C1.5 — Fix Correctness & Regression | 4 | YES | |
| **P1** | C1.6 — Resume Reliability | 7 | YES | |
| **P1** | C1.7 — Session Isolation & Concurrency | 5 | YES | |
| **P1** | C1.8 — Graceful Degradation | 5 | YES | |
| **P1** | C1.9 — Deep Scan Coverage & Component Exhaustiveness | 10 | YES | |
| **P1** | C1.10 — QD11 Business Completeness & Enhancement | 10 | YES | |
| | **P1 Tổng** | **74** | **60%** | |
| **P2** | C2.1 — Parallel Lane Execution | 3 | NO | |
| **P2** | C2.2 — Static/Runtime Separation | 3 | NO | |
| **P2** | C2.3 — Agent Dispatch Decision | 2 | NO | |
| **P2** | C2.4 — Checkpoint Granularity | 2 | NO | |
| **P2** | C2.5 — Workload Gate Accuracy | 2 | NO | |
| | **P2 Tổng** | **12** | **25%** | |
| **P3** | C3.1 — Runtime File Content Purity | 3 | NO | |
| **P3** | C3.2 — Procedure Lazy-Loading | 2 | NO | |
| **P3** | C3.3 — Bash Delegation | 2 | NO | |
| **P3** | C3.4 — Summary & Report | 3 | NO | |
| **P3** | C3.5 — Cross-Skill Artifact Integrity | 1 | NO | |
| | **P3 Tổng** | **11** | **15%** | |
| | **TỔNG** | **97** | | **100%** |

---

## Quy Trình Audit

### Chuẩn Bị

```bash
# 1. Xác định phiên bản skill cần audit
git tag -l 'wf-fix-bugs/*' | tail -5

# 2. Chuẩn bị môi trường test
export MCV3_AUDIT_MODE=1
export MCV3_FIX_BUGS_BASE_DIR=".mc-data/work/wf-fix-bugs"

# 3. Tạo test fixtures nếu cần
cd .claude/skills/workflow/wf-fix-bugs/evals
bash regression-tests/run-all.sh
```

### Thực Hiện Audit

1. **Chạy regression test suite** — ít nhất 20 tests phải pass
2. **Chạy E2E large codebase test** — `bash e2e-large-codebase.test.sh`
3. **Kiểm tra từng checkpoint** — đánh dấu PASS/FAIL/WARN/N/A
4. **Ghi nhận findings** — mỗi FAIL phải có finding code + mô tả
5. **Tổng hợp kết quả** — tính điểm theo trọng số

### Báo Cáo

```markdown
# Audit Report — wf-fix-bugs v[X.Y.Z]
Date: [YYYY-MM-DD]
Auditor: [name]

## Summary
- P1: [X]/74 PASS, [Y] FAIL, [Z] WARN
- P2: [X]/12 PASS, [Y] FAIL, [Z] WARN
- P3: [X]/11 PASS, [Y] FAIL, [Z] WARN
- Result: PASS | WARN | FAIL | BLOCK

## Failures
| Code | Checkpoint | Severity | Description |
|------|-----------|----------|-------------|
| F001 | C1.2.8 | CRITICAL | CQG counts mismatch: REMAINING=3 |

## Warnings
| Code | Checkpoint | Description |
|------|-----------|-------------|
| W001 | C3.1.1 | Version tag in post-gate-completion.md |
```

---

## Liên Kết

- SKILL.md chính: [SKILL.md](SKILL.md)
- Contract: [_contract.json](_contract.json)
- Regression tests: [evals/](evals/)
- Shared Python modules: [../_shared/](../_shared/)
- Bash scripts: [../../../scripts/](../../../scripts/) (`wf-fix-*.sh`)
- CORE rules: [../../../../.claude/rules/00-core.md](../../../../.claude/rules/00-core.md)
- Behavioral principles: [../../../../.claude/rules/00-behavioral.md](../../../../.claude/rules/00-behavioral.md)
