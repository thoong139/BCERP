# Orchestrator Summary — wf-e2e-verify v7.0.0

<!-- _template_notes: Template cho orchestrator-summary.md — final summary của 8-step pipeline. Populate sau khi finalize. Strip _template_notes khi write. -->

## Tổng quan Session

| Mục | Giá trị |
|-----|---------|
| **Feature** | {FEAT-ID} |
| **Session** | {SESSION_ID} |
| **Created** | {CREATED_AT} |
| **Completed** | {COMPLETED_AT} |
| **Duration** | {DURATION_MIN} phút |
| **Overall status** | {OVERALL_STATUS} (success / partial / failed) |

---

## 8-Step Pipeline Results

| Step | Skill | Status | Duration | Key Outputs |
|------|-------|--------|----------|-------------|
| F1 | wf-e2e-test | {F1_STATUS} | {F1_DURATION} | findings/ (12 files), outputs/ skeleton, 4 SSOT JSONs |
| F2 | wf-e2e-browser | {F2_STATUS} | {F2_DURATION} | screenshots/browser-*.png, browser-test-report.md |
| F3 | wf-e2e-unblock | {F3_STATUS} | {F3_DURATION} | unblock-report.md, block-test updates |
| F4 | wf-e2e-implement | {F4_STATUS} | {F4_DURATION} | impl-log.json, registry impl_status updates |
| F5 | wf-e2e-retest | {F5_STATUS} | {F5_DURATION} | retest-log.md, reports updated |
| F6 | wf-e2e-fix | {F6_STATUS} | {F6_DURATION} | fix-log.json, code patches |
| F7 | wf-e2e-scenario | {F7_STATUS} | {F7_DURATION} | scenario-test-report.md, test-scenario Pass/Fail |
| F8 | wf-e2e-demo | {F8_STATUS} | {F8_DURATION} | demo-report.md, accuracy score |

**Skipped steps lý do:** {SKIPPED_REASONS}

---

## SSOT Counters Final

### issues.json
- Total: {ISSUES_TOTAL}
- Open (chưa fix): {ISSUES_OPEN}
- Fixed: {ISSUES_FIXED}
- Still_fail (đã exhausted retry): {ISSUES_STILL_FAIL}
- Deferred-locked: {ISSUES_DEFERRED}

### block-test.json
- Total blocks: {BLOCKS_TOTAL}
- Blocked (còn tồn tại): {BLOCKS_BLOCKED}
- Unblocked (Group 1+2 fixed): {BLOCKS_UNBLOCKED}
- Resolved (Group 4 verified-OK): {BLOCKS_RESOLVED}

### implement-required.json
- Total: {IMPL_TOTAL}
- Pending (chưa làm): {IMPL_PENDING}
- Done (F4 implement xong): {IMPL_DONE}
- Skipped: {IMPL_SKIPPED}

### manual.json
- Total manual tests: {MANUAL_TOTAL}
- Pending (cần QA): {MANUAL_PENDING}
- Verified (QA đã test): {MANUAL_VERIFIED}

---

## Anti-Loop Tracking

- f6_f5_loop_count: {F6_F5_LOOPS} / 3 (max)
- f3_f2_loop_count: {F3_F2_LOOPS} / 2 (max)

---

## Issues Phát hiện Đáng chú ý

### Critical/High issues còn open
{LIST_CRITICAL_OPEN_ISSUES}

### Manual tests cần QA team
{LIST_MANUAL_PENDING_TOP_5}

### Implement-required còn pending
{LIST_IMPL_PENDING_TOP_5}

---

## Key Outputs

- **findings/**: 12 markdown reports (Phase 1-5)
- **outputs/test-scenario.md**: {SCENARIO_COUNT} scenarios filled Pass/Fail
- **outputs/user-guide.md**: Hướng dẫn tiếng Việt + demo accuracy {DEMO_ACCURACY}%
- **screenshots/**: {SCREENSHOT_COUNT} files (browser-, scenario-, demo-)
- **Registry updates**: {REGISTRY_UPDATES_COUNT} REQ-IDs upgraded impl_status

---

## Recommendations

{RECOMMENDATIONS}

Possible next actions:
- Review still_fail issues — cần manual fix vì exceed retry budget
- Execute manual tests trong QA team (xem manual.json)
- Re-run `/wf-e2e-verify {FEAT-ID} --resume` nếu có bước skipped
- Spawn `/wf-fix-bugs` cho issues quá phức tạp cho F6

---

## Legacy Flags Used (Deprecation Warnings)

{LEGACY_FLAGS_USED}

---

## Phase Summary (CORE-028)

> Đã chạy đầy đủ pipeline test E2E 8 bước cho feature {FEAT-ID}. {COMPLETED}/{TOTAL_STEPS} bước hoàn tất.
> Tổng phát hiện {ISSUES_TOTAL} vấn đề ({ISSUES_FIXED} đã fix, {ISSUES_OPEN} còn open).
> {BLOCKS_TOTAL} test bị block ban đầu, {BLOCKS_UNBLOCKED} đã unblock tự động.
> {IMPL_DONE} hạng mục code đã implement qua F4 delegate.
> {MANUAL_TOTAL} test cần QA thực hiện thủ công.
> Đã capture {SCREENSHOT_COUNT} screenshots evidence.
> Kết quả tổng: {OVERALL_STATUS}.
