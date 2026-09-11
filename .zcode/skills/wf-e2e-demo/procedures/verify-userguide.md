# F8 — Verify User-Guide Accuracy Procedure

## demo-report.md Structure

```markdown
# Demo Report — F8 wf-e2e-demo

## Tổng quan
- Feature: {FEAT-ID}
- Session: {SESSION_ID}
- Started: {ISO}
- Completed: {ISO}
- Browser mode: desktop|mobile
- Auto-correct: ON|OFF

## Accuracy Assessment

| Metric | Value |
|--------|-------|
| Total steps | 12 |
| Exact match | 8 |
| Partial match | 3 |
| No match | 1 |
| **Accuracy score** | **79%** (Good) |

## Verdict

**Good** — Minor corrections needed. User-guide accurate cho 8/12 steps. 3 steps có partial match (UI text changed nhẹ), 1 step không match (element không tồn tại).

## Per-Step Results

| # | Bước | Match | Screenshot |
|---|------|-------|------------|
| 1 | Đăng nhập với sysadmin | exact | demo-01-login.png |
| 2 | Điều hướng đến CRM > Customer | exact | demo-02-navigate.png |
| 3 | Click button "Tạo Customer" | partial | demo-03-tao.png |
| 4 | Điền email, tên, sđt | exact | demo-04-fill.png |
| 5 | Click "Lưu" | exact | demo-05-save.png |
| 6 | Verify toast "Lưu thành công" | partial | demo-06-toast.png |
| ... |

## Corrections Needed

### Step 3: Click button "Tạo Customer"
- **user-guide.md says:** Click button "Tạo Customer"
- **Actual UI:** Button label "Tạo Khách Hàng" (i18n key crm.customer.create)
- **Recommendation:** Update step 3 text → "Click button 'Tạo Khách Hàng'"
- **Auto-correct status:** {applied|pending|skipped}

### Step 6: Verify toast "Lưu thành công"
- **user-guide.md says:** Verify toast "Lưu thành công"
- **Actual UI:** Toast "Tạo khách hàng thành công"
- **Recommendation:** Update step 6 expected text

### Step 9: Click link "Xuất Excel"
- **user-guide.md says:** Click link "Xuất Excel"
- **Actual UI:** Element không tồn tại
- **Recommendation:** Feature có thể chưa implement HOẶC link đã chuyển vị trí. Cần investigate

## Issues to log

**v1.1.0 — ISSUE-IMMEDIATE pattern (giống F1/F7):**

APPEND issues.json **NGAY** khi step có `match != exact` (không chờ POST-GATE, không chỉ khi critical).

| match | classify | severity | type | Auto-fix |
|-------|----------|----------|------|----------|
| `none` + element missing | real_failure → TEST_SELECTOR | medium | ui-runtime | F7 analyzer Phase 1+2 |
| `none` + network 4xx/5xx | real_failure → NETWORK_ERROR | high | ui-runtime | F7 analyzer Phase 1+2 |
| `none` + console TypeError | real_failure → UI_BUG | high | ui-runtime | F7 analyzer Phase 1+2 |
| `none` + 401/403 | real_failure → AUTH_FAILURE | high | ui-runtime | F7 analyzer Phase 1+2 |
| `none` + empty data list | real_failure → DATA_MISSING | medium | ui-runtime | F7 analyzer Phase 1 (seed data apply) |
| `partial` + text wording diff | accuracy_wording | low | doc-drift | --auto-correct nếu flag bật |
| `none` + business outcome khác | real_failure → BUSINESS_RULE | high | business-logic | F7 analyzer Phase 2 (spawn agent) |

## Phase Summary (CORE-028)

Đã chạy demo qua hướng dẫn sử dụng. 8/12 bước khớp chính xác, 3 bước cần sửa text nhỏ (do i18n đã đổi), 1 bước không tìm thấy nút. Tổng accuracy 79% — tương đối tốt nhưng cần cập nhật user-guide.md cho 4 bước. Đã capture đầy đủ screenshot làm tài liệu hướng dẫn cho người dùng.
```

---

## Verdict Thresholds

| Accuracy | Verdict | Action |
|----------|---------|--------|
| ≥90% | Excellent | No corrections needed |
| 70-89% | Good | Log corrections trong demo-report (default) |
| 50-69% | Needs revision | Log corrections + WARN orchestrator |
| <50% | Outdated | E088 escalate → user-guide cần re-generate (suggest F1 re-run Phase 6) |

---

## --auto-correct Logic

Khi `--auto-correct` flag được pass:

```bash
# Cho mỗi correction trong demo-report.md
FOR each suggestion:
  # Use Edit tool
  Edit $GUIDE \
    old_string="<original-text>" \
    new_string="<corrected-text>" \
    replace_all=false
  
  # Mark trong demo-report.md: "Auto-correct status: applied"
  
  # IF Edit fail (old_string không unique) → mark "skipped, needs manual review"
```

---

## Issue Logging (ISSUE-IMMEDIATE — NGAY khi match != exact)

```jsonc
{
  "id": "ISS-NNN",
  "type": "ui-runtime | doc-drift | business-logic",
  "severity": "high | medium | low",
  "phase": 8,
  "title": "Bước {N} user-guide.md — <mô tả>",
  "description": "Demo verify phát hiện step {N} ({action}) không khớp với UI hiện tại.",
  "location": "user-guide.md step {N}",
  "evidence": "screenshots/demo-{NN}-{slug}.png",
  "status": "open",
  "discovered_by_skill": "wf-e2e-demo",
  "match": "partial | none",
  "classify": "accuracy_wording | real_failure",
  "auto_fix": {
    "delegated_to": "F7-failure-analyzer | --auto-correct | none",
    "phase1_strategy": "...",
    "phase1_result": "pass | fail | skip",
    "phase2_strategy": "...",
    "phase2_result": "pass | fail | skip",
    "final_result": "pass | fail | skip"
  }
}
```

> Note: severity HIGH cho real_failure (NETWORK/UI_BUG/AUTH/BUSINESS), MEDIUM cho real_failure (TEST_SELECTOR/DATA_MISSING), LOW cho accuracy_wording.

---

## POST-GATE Validation

1. demo-report.md tồn tại + có Accuracy Assessment section
2. Mỗi step có entry trong "Per-Step Results" table
3. Mỗi NO_MATCH step có ISS-NNN trong issues.json (nếu critical)
4. Screenshots ≥80% steps có file PNG

Fail → auto-fix retry x3 → E088.
