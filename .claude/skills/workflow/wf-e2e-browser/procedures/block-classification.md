# F2 — Block Classification (delegated from F1 with browser-specific context)

**Reference:** `.claude/skills/workflow/wf-e2e-test/procedures/block-classification.md` — canonical 4-nhóm logic.

**F2-specific adaptations:**

- F2 phát hiện browser-blocked tests trong context BROWSER execution
- Nhóm 1 Data ít gặp ở F2 (vì F1 đã handle phần lớn)
- Nhóm 2 Infra: FE running là điều kiện tiên quyết (đã PRE-GATE check)
- Nhóm 3 Not Impl: UI/component chưa implement → DUAL-WRITE
- Nhóm 4 Hard Test: visual_inspection / external dep / flaky → DUAL-WRITE với code verification

---

## F2 Block Detection

Trong khi execute test qua Playwright, F2 phát hiện block khi:

1. **Element không tồn tại** → blocking_reason=ui_screen_missing (Group 3)
2. **Navigation 404** → blocking_reason=feature_not_implemented (Group 3)
3. **External login required** (vd: OAuth) → blocking_reason=requires_3rd_party_login (Group 4)
4. **Animation/visual issue** → blocking_reason=requires_visual_inspection (Group 4)
5. **Flaky test** → blocking_reason=flaky_test (Group 4)

---

## Dual-Write Pattern (canonical từ F1)

### Group 3 → DUAL-WRITE

```jsonc
// block-test.json APPEND
{
  "id": "BLK-NNN",
  "test_ref": "<test from pre-scan>",
  "phase": 7,  // F2 logically belongs to Phase 7
  "blocking_reason": "ui_screen_missing",
  "blocking_detail": "Element [data-testid='customer-create-btn'] không tồn tại trong UI",
  "status": "blocked",
  "discovered_by_skill": "wf-e2e-browser",
  "discovered_at": "<ISO>",
  "related_impl_req_id": "IMPL-REQ-NNN"
}

// implement-required.json APPEND
{
  "id": "IMPL-REQ-NNN",
  "discovered_by_skill": "wf-e2e-browser",
  "discovered_in_phase": 7,
  "test_ref": "<same as block>",
  "feat_id": "<FEAT-ID>",
  "blocking_reason": "ui_screen_missing",
  "suggested_action": "implement_ui",
  "location_hint": "<file from ui-mapping.md hoặc Serena search>",
  "expected_behavior": "Page có button 'Tạo Customer' với data-testid='customer-create-btn'",
  "priority": "P0",
  "status": "pending",
  "related_blk_id": "BLK-NNN"
}
```

### Group 4 → VERIFY CODE → DUAL-WRITE

```bash
# Verify code logic via Serena
mcp__serena__find_symbol --name_path="ToastNotification" --include_body=true

# Đánh giá
# IF code OK → manual.json verification_result=PASS + block-test resolved
# IF code FAIL → issues.json (escalate, KHÔNG ghi manual)
# IF INCONCLUSIVE → manual.json verification_result=INCONCLUSIVE
```

```jsonc
// block-test.json APPEND
{
  "id": "BLK-NNN",
  "test_ref": "Toast animation",
  "blocking_reason": "requires_visual_inspection",
  "status": "resolved",  // hoặc "blocked" nếu code FAIL
  "retest_result": "SKIPPED",
  "resolution_note": "Code logic verified PASS — Toast component đúng pattern",
  "related_manual_id": "MAN-NNN",
  "discovered_by_skill": "wf-e2e-browser"
}

// manual.json APPEND
{
  "id": "MAN-NNN",
  "test_ref": "Toast animation",
  "manual_reason": "requires_visual_inspection",
  "code_verification": {
    "verification_method": "static_code_review",
    "verification_result": "PASS",
    "code_location": "apps/erp-web/src/components/ui/Toast.tsx",
    "notes": "Toast component dùng framer-motion với fade-in 300ms + fade-out 500ms"
  },
  "recommended_test_steps": [
    "Bước 1: Đăng nhập erp-web",
    "Bước 2: Trigger toast bằng click 'Lưu' trên form",
    "Bước 3: Verify mắt: toast fade in mượt, hiển thị 3s, fade out mượt",
    "Bước 4: Verify mobile viewport: toast vẫn responsive"
  ],
  "status": "pending",
  "assigned_to": "qa-team",
  "related_blk_id": "BLK-NNN",
  "discovered_by_skill": "wf-e2e-browser"
}
```

---

## When NOT to Block-Classify

Nếu test FAIL vì CODE BUG (rõ ràng là logic sai) — KHÔNG block-classify, mà:
- APPEND issues.json với type=ui-runtime, severity (high/medium per impact)
- KHÔNG ghi block-test
- Test sẽ được F6 wf-e2e-fix xử lý

Phân biệt:
- **Block** = test không thực thi được (env/data/impl/hard-test)
- **Bug** = test thực thi được nhưng kết quả sai

---

## Cross-Reference với F1's Existing Blocks

F2 đọc `block-test.json` trước khi append → check trùng `test_ref`. Nếu đã có BLK cho test này → SKIP append (avoid duplicate). Có thể UPDATE thông tin nếu phát hiện thêm context.
