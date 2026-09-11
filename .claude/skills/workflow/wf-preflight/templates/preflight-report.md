<!-- Template: preflight-report.md — Báo cáo kết quả preflight -->
<!-- Ai viết: AI tự động generate khi hoàn thành Phase 7 của /wf-preflight -->
<!-- Template Usage: READ template này → POPULATE với data từ Phases 2-5b → WRITE output -->
<!-- Cập nhật: Ghi đè mỗi lần chạy /wf-preflight -->

## Preflight Report

| Project | [name] | Date | YYYY-MM-DD | Scope | [all / system=X / module=Y / feature=Z] |
|---------|--------|------|------------|-------|----------------------------------------|

---

## Verdict: PASS ✅ | WARN ⚠️ | FAIL ❌   (Overall Score: X%)

| Check | Score | Status | Issues |
|-------|-------|--------|--------|
| Registry Integrity | X% | ✅/⚠️/❌ | N issues |
| Document Completeness | X% | ✅/⚠️/❌ | N missing docs |
| Code-REQ Sync | X% | ✅/⚠️/❌ | N gaps, N orphans |
| Code Quality | X% | ✅/⚠️/❌ | N errors |
| Tests (if run) | X% | ✅/⚠️/❌ | N failed / N passed — BONUS |

> Score = registry×0.20 + docs×0.25 + sync×0.30 + quality×0.25 (null phases có weight được redistribute)

> **Skipped:** N features (deprecated hoặc user skip, impl_status="skipped") — không tính vào scores

---

### Issues

#### Critical — BLOCKING (phải fix trước khi chạy)

| # | Type | Location | Fix |
|---|------|----------|-----|
| 1 | [type] | [file/id/path] | [skill/action] |

#### High — WARNINGS (nên fix)

| # | Type | Location | Fix |
|---|------|----------|-----|
| 1 | [type] | [location] | [action] |

#### Medium / Low — Informational

[summary hoặc danh sách ngắn]

---

### Auto-fixes Applied (nếu --fix)

| # | File | Action |
|---|------|--------|
| 1 | [file] | [what was fixed] |

> Score trước fix: X% → Sau fix: Y%

---

### Next Steps

**Nếu PASS:**
→ Tiếp tục: `/wf-verify-sync` → `/wf-prepare-deployment`

**Nếu WARN:**
→ **Khuyến nghị:** Chạy `/wf-fix-bugs` để tự động sửa issues code-level
→ Sau khi fix: chạy lại `/wf-preflight` để verify
→ Hoặc fix issues HIGH priority thủ công, rồi chạy lại: `/wf-preflight --scope=[scope] --name=[name]`
→ Issues HIGH: [list]

**Nếu FAIL:**
→ **Khuyến nghị MẠNH:** Chạy `/wf-fix-bugs --scope=[scope]` trước
→ Fix CRITICAL issues trước:
  - Registry issues → sửa `req-registry.json` trực tiếp hoặc chạy lại skill tương ứng
  - Missing docs → [specific skill]: `/wf-[phase]`
  - Code errors → `/wf-fix-bugs` hoặc sửa thủ công, rồi chạy lại `/wf-preflight`
  - Test failures → `/wf-fix-bugs` hoặc fix tests thủ công, rồi chạy lại `/wf-preflight --run-tests`

Full report: `.mc-data/work/wf-preflight/preflight-report.md`
