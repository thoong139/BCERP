# Master Plan — wf-fix-bugs v11.0.0 Quality Fix

## 7 Root Causes → 7 Solution Groups

| ID | Root cause | Solution Group | Wave |
|----|-----------|----------------|------|
| R1 | CQG-1 leniency: `grep \| head -1` regex picks wrong number → "substance-based PASS" giả | **G1**: SSOT counts từ fix-execution-result.json v2; cqg1-numeric.sh strict (no regex fallback) | 1 |
| R2 | Aggregation inconsistency: 35 (env var) vs 45 (fix-status) vs 39 (narrative) | **G1**: cùng giải pháp R1 — single source of truth | 1 |
| R3 | Max-retry 3 không enforced, chỉ 1 retry POST-GATE | **G2**: Fix Iteration Loop — re-spawn execute với scope thu hẹp, max 3 iter | 2 |
| R4 | wf-fix-execute defer quick-fix items dù triage cho phép fix | **G2** + **G3**: agent prompt cấm defer items có fixability=AUTO_FIX/AGENT_FIX; script verify-defer-reasons.sh check post-hoc | 2 |
| R5 | Cross-module issues không auto-spawn session khác | **G4**: CDG E096 ở Phase 6 finalize, queue file follow-up | 3 |
| R6 | False positives: 8 i18n keys bị flag là hardcoded password | **G5**: exclusions.json cho wf-fix-security + aggregate de-prio | 3 |
| R7 | Path corruption `\357\200\215` trong safety-check.json (Windows) | **G6**: sanitize safety-check output | 3 |
| — | "DONE" báo cáo mơ hồ khi 52% defer | **G7**: Pipeline status enum mở rộng (DONE_CLEAN, DONE_WITH_DEFERRED, DONE_NEEDS_FOLLOWUP) | 1 |

## Wave Structure

### Wave 1 — Foundational (G1 + G7) — ETA 6-9h

**Mục tiêu**: Counts chính xác + status report trung thực. Tạo nền cho Wave 2 (loop logic cần counts đúng để biết khi nào dừng).

**Tasks**:
1. `verify-execute-outputs.sh`: Đổi FIXED_COUNT/DEFERRED_COUNT/FAILED_COUNT từ regex Markdown → đọc từ `fix-log.json` aggregated (đã có ISSUES_JSON build sẵn ở line 233-253)
2. `cqg1-numeric.sh`: Bắt buộc `fix-execution-result.json` schema v2 tồn tại + valid. Bỏ fallback regex (chỉ giữ cho graceful degradation v10.x sessions với WARN log)
3. Script mới `derive-fix-plan-counts.sh` (Phase 5 add-on): Đếm action="fix" entries trong fix-plan.md → ghi vào `fix-plan-counts.json` (schema mới `fix-plan-counts-v1`). cqg1-numeric.sh đọc file này cho expected counts.
4. `generate-phase7-reports.sh`: Đổi `$FIXED_COUNT/DEFERRED_COUNT` env var → đọc từ `fix-execution-result.json aggregated`. Đảm bảo orchestrator-summary.md luôn khớp fix-status.json.
5. `fix-status.json` schema: thêm enum value `DONE_CLEAN | DONE_WITH_DEFERRED | DONE_NEEDS_FOLLOWUP` cho `pipeline_status`. Default vẫn `DONE` cho backward-compat.
6. `orchestrator-summary.md` template: thêm dòng đầu hiển thị pipeline_status rõ ràng kèm icon ✅/⚠️.
7. Smoke test: chạy lại trên session `2026-05-16-module-settings-01` để verify counts khớp.

**Acceptance**:
- fix-status.json `fixed_count` == orchestrator-summary "Lỗi đã sửa" == fix-execution-result.json `aggregated.fixed_total`
- CQG-1 fail E070 nếu deviation thực > 5% (không có cách bypass)
- Smoke test pass: phase5/phase6/phase7 routing tests không regression

### Wave 2 — Aggressive Auto-Loop (G2 + G3) — ETA 11-16h

**Mục tiêu**: Đẩy fixed_count lên cao bằng cách re-spawn execute agent cho deferred items có quyền fix.

**Tasks**:
1. Script mới `verify-defer-reasons.sh`: Cross-join fix-log × fix-plan × issue-registry. Output `unsanctioned-defers.json` (schema mới).
2. Script mới `fix-iteration-loop.sh`: Orchestrator-side helper xử lý loop logic. Inputs: `unsanctioned-defers.json`, `.fix-iteration-count` file. Output: decision (continue/CDG/exit).
3. `phase6-execute/E-validate-dashboard.md`: Tích hợp loop check sau Step 6.5 POST-GATE.
4. `phase6-execute/D-spawn-execute.md`: Agent prompt template thêm section "FORBIDDEN to defer items với fixability=AUTO_FIX/AGENT_FIX. If cannot fix → write to `phase6-execute/fix-blockers.md` với rationale, agent KHÔNG được chọn `result="deferred"` trừ khi fixability=MANUAL_FIX/ESCALATE/SKIP".
5. CDG E095 mới khi iteration >= 3 và còn unsanctioned defers: AskUserQuestion 3 options (Force-fix với expert agent / Accept defer / Spawn cross-scope).
6. File mới `phase6-execute/fix-iterations.json` (schema `fix-iterations-v1`): Audit trail của mỗi iteration với fixed/deferred trước-sau, agent decisions.
7. Update `generate-phase6-report.sh` để include iteration summary.
8. Smoke test + integration test trên session settings.

**Acceptance**:
- Trên session test, fixed_count tăng từ baseline (45) lên ≥ 70 (60%+)
- 4 entity validation guards (quick-fix) PHẢI được fix (không defer)
- unsanctioned-defers.json rỗng cuối Phase 6 hoặc CDG đã ghi nhận user accept
- Iteration count enforced max 3, không infinite loop
- Backward-compat: sessions cũ resume vẫn chạy được (loop opt-in via flag)

### Wave 3 — Polish (G4 + G5 + G6) — ETA 8-13h

**Mục tiêu**: Khắc phục các vấn đề periferal nhưng vẫn quan trọng cho UX.

**Tasks**:
1. **G4 Cross-scope CDG**:
   - CDG E096 trong Step 6.6 (trước Phase 7)
   - Queue file `.mc-data/work/wf-fix-bugs/_followup-queue.jsonl` (APPEND-only)
   - orchestrator-summary suggest user chạy lệnh tiếp theo
2. **G5 False-positive filter**:
   - File `.claude/skills/workflow/wf-fix-security/exclusions.json`
   - Probe pre-filter cho wf-fix-security hardcoded_secret pattern
   - Phase 5 aggregate Step B-aggregate.md: de-priority signals from excluded paths
3. **G6 Windows path fix**:
   - Locate safety-check script (Phase 5 Step 5.10)
   - Sanitize git status output: `tr -d '\357\200\215\r'` hoặc dùng `-z` null delimiter
4. Smoke + manual verification trên sessions test.

**Acceptance**:
- 8 i18n false positives không xuất hiện trong issue-registry với severity HIGH
- safety-check.json không còn byte rác U+F00D
- Cross-scope items có CDG hỏi user, queue file đúng format

## Cross-Cutting Concerns

### Backward Compatibility (BẮT BUỘC)
- Tất cả thay đổi additive — sessions cũ `--resume` không break
- Schema mới (fix-plan-counts-v1, fix-iterations-v1, scan-exclusions-v1) đều có `$schema` field
- Default behavior giữ nguyên trừ khi env var/flag bật mới
- Smoke tests phải pass: Phase 1/3/4/5/6/7 routing tests (254 checks)

### Version Bump
- v10.18.0 → v11.0.0 (major bump do Phase 6 behavior thay đổi đáng kể)
- CHANGELOG.md update với migration notes
- `_contract.json` version field update

### Cross-Skill Impact Audit
- `fix-impact.json` consumers: wf-verify-sync, wf-prepare-deployment, wf-implement-feature
- Schema giữ nguyên (fix-impact-v1), chỉ giá trị `fixed_count` có thể cao hơn (do loop)
- Verify: smoke test cross-skill scenarios A-H (tools/integration-test.py)

### Documentation Updates
- `docs/04-skill-design/wf-fix-bugs/` — thêm `v11-fix-iteration-loop-arch.md`
- `docs/06-user-guides/per-skill/wf-fix-bugs-v11-guide.md` — user guide với ví dụ aggressive loop
- CLAUDE.md description field cập nhật cho v11.0.0
