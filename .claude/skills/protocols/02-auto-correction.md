<!-- From shared-protocols.md lines 74-119 (§2) -->
# Protocol 2 — Auto-Correction Loop Protocol

> Dùng cho Cross-Validation phases và Stakeholder Review phases.

```
iteration = 0
MAX_ITERATIONS = 3

// Trước khi vào loop: check agent status
IF agent_status == "DONE_WITH_CONCERNS":
  → Log concerns (không phải errors)
  → SKIP auto-correction loop — advance sang step tiếp theo
  → Concerns được ghi vào report cuối cùng của skill

WHILE iteration < MAX_ITERATIONS:
  iteration += 1
  errors = run_all_checks()

  IF errors.length == 0:
    → PASS — log "Validation PASSED (iteration {iteration})"
    → BREAK

  IF iteration == MAX_ITERATIONS:
    → FAIL — log all remaining errors
    → Escalate to user: "Còn {N} lỗi sau {MAX_ITERATIONS} lần sửa tự động"
    → STOP — KHÔNG cho phép tiếp tục

  // Auto-fix errors (chỉ cho hard failures — missing files, invalid JSON, schema violations)
  FOR each error in errors:
    apply fix theo Fix Rules của phase/skill cụ thể

  verify_outputs()
  log("Iteration {iteration}: Fixed {fixed_count}/{error_count} errors, retrying...")
```

**Lưu ý**: Auto-Correction Loop chỉ trigger cho **hard failures** (missing files, invalid JSON, schema violations). Agent status `DONE_WITH_CONCERNS` (warnings không blocking như flaky test, partial coverage) KHÔNG trigger loop — xem Protocol 1b Agent Status Protocol.

## 2.1 Escalation Rules (3 tiers)

| Sau iteration | Hành động |
|---------------|-----------|
| 1 | Fix tự động — không hỏi user |
| 2 | Fix tự động + WARNING cho user biết lỗi lặp lại |
| 3 (final) | STOP + báo cáo chi tiết lỗi còn lại → user quyết định |
