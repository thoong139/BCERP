<!-- Template: qa-review-report.md — Báo cáo kết quả review code/security có cấu trúc -->
<!-- Ai viết: qa-lead hoặc security agent trong Phase 4 của /wf-implement-feature -->
<!-- Mục đích: Chuẩn hóa feedback giữa reviewer → developer, hỗ trợ retry tracking -->

# QA Review Report — [Feature Name]

## Metadata

| Field | Value |
|-------|-------|
| **Feature** | [FEAT-ID] — [Feature Name] |
| **Reviewer** | [qa-lead / security] |
| **Review Type** | Code Quality / Security |
| **Attempt** | [N] of 3 |
| **Timestamp** | YYYY-MM-DD HH:mm:ss |

---

## Verdict: [PASS / NEEDS WORK]

---

## Issues Found

> *Chỉ điền khi verdict = NEEDS WORK. Liệt kê TẤT CẢ issues tìm thấy.*

### Issue 1: [Category] — [CRITICAL / HIGH / MEDIUM / LOW]

| Field | Detail |
|-------|--------|
| **File** | `path/to/file.ts:LINE` |
| **Description** | [Mô tả chính xác vấn đề] |
| **Expected** | [Hành vi/code đúng theo acceptance criteria] |
| **Actual** | [Hành vi/code hiện tại] |
| **Fix instruction** | [Hướng dẫn sửa cụ thể, actionable] |
| **CWE** | [CWE-XXX nếu là security issue, bỏ trống nếu code quality] |

### Issue 2: [Category] — [Severity]

| Field | Detail |
|-------|--------|
| **File** | `path/to/file.ts:LINE` |
| **Description** | [...] |
| **Expected** | [...] |
| **Actual** | [...] |
| **Fix instruction** | [...] |

<!-- Lặp lại cho tất cả issues -->

---

## Acceptance Criteria Status

| # | Criterion | Status | Issue Ref |
|---|-----------|--------|-----------|
| 1 | [Criterion từ feature design] | ✅ PASS / ❌ FAIL | — / Issue #N |
| 2 | [Criterion] | ✅ / ❌ | |
| 3 | [Criterion] | ✅ / ❌ | |

---

## Review Checklist

### Code Quality (qa-lead)

- [ ] Naming conventions đúng project rules
- [ ] Structure theo SOLID principles
- [ ] DRY — không duplicated logic
- [ ] Error handling đúng pattern
- [ ] Test coverage đủ: edge cases, error paths, boundary
- [ ] REQ-ID comment có trong mọi source files
- [ ] Không có TODO/FIXME chưa xử lý

### Security (security agent)

- [ ] Input validation tại controller layer
- [ ] Authentication/Authorization checks
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (output encoding)
- [ ] Không hardcode credentials/secrets
- [ ] Sensitive data không log/expose
- [ ] Access control đúng per role

### Environment Safety (tất cả agents — BẮT BUỘC)

- [ ] Không `process.env` trong browser-bundled code (Vite: dùng `import.meta.env`)
- [ ] Không hardcoded secrets/fallback values trong source code
- [ ] API keys/config từ env vars, không inject qua `define` vào client bundle
- [ ] `import.meta.env` values được xử lý đúng (string constants at build time)

### Runtime Safety (qa-lead — BẮT BUỘC)

- [ ] NaN guard trên tất cả `parseInt()`, `parseFloat()`, `new Date()`, phép chia
- [ ] Blob URL / timer / subscription được cleanup trong useEffect return
- [ ] `String.replace()` dùng regex `/pattern/g` khi cần replace tất cả occurrences
- [ ] Optional chaining / nullish coalescing (`??`) thay vì `||` cho falsy values hợp lệ (0, '')

### i18n & Accessibility (qa-lead, frontend — BẮT BUỘC)

- [ ] Không hardcoded UI strings — tất cả qua `t()` hoặc i18n function
- [ ] Placeholder, aria-label, alt text cũng được translate
- [ ] Label có `htmlFor` attribute matching input `id`
- [ ] Hình ảnh có alt text mô tả (không generic như "Product", "Avatar")
- [ ] Error/success feedback dùng Toast component (không `alert()`)
- [ ] Number/date formats theo locale (không hardcode định dạng)

---

## Summary

| Metric | Value |
|--------|-------|
| **Total issues** | [N] |
| **CRITICAL** | [N] |
| **HIGH** | [N] |
| **MEDIUM** | [N] |
| **LOW** | [N] |

**Tóm tắt:** [1-2 câu tóm tắt kết quả review]

---

## Next Action

> Tự động xác định dựa trên verdict và attempt count.

- **PASS** → Tiếp tục Phase 5a (Cross-Validation)
- **NEEDS WORK (attempt < 3)** → Developer fix issues → Re-review (Phase 4 lại)
- **NEEDS WORK (attempt = 3)** → Escalate — xem Escalation Report

---

## Escalation Report (chỉ khi attempt = 3 và vẫn NEEDS WORK)

> *Điền khi task đã qua 3 review cycles mà vẫn fail.*

### Failure History

| Attempt | Issues Found | Fixes Applied | Remaining |
|---------|-------------|---------------|-----------|
| 1 | [N issues] | [Mô tả fixes] | [N remaining] |
| 2 | [N issues] | [Mô tả fixes] | [N remaining] |
| 3 | [N issues] | [Mô tả fixes] | [N remaining] |

### Root Cause Analysis

**Tại sao task liên tục fail:** [Phân tích nguyên nhân gốc]

**Phân loại:** One-off / Systemic pattern

### Recommended Resolution

- [ ] **Decompose** — Chia nhỏ task thành sub-tasks đơn giản hơn
- [ ] **Revise approach** — Thay đổi kiến trúc/design
- [ ] **Accept** — Chấp nhận trạng thái hiện tại với documented limitations
- [ ] **Defer** — Chuyển sang sprint sau

### Impact Assessment

| Impact | Description |
|--------|-------------|
| **Blocking** | [Tasks nào bị block bởi issue này] |
| **Timeline** | [Ảnh hưởng đến schedule] |
| **Quality** | [Rủi ro chất lượng nếu accept current state] |

**Decision required from:** User

---

*Report generated by DEVKIT `/wf-implement-feature` Phase 4*
