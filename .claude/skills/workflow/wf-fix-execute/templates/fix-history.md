<!-- Template: fix-history.md — Lich su fix bugs (append-only) -->
<!-- Ai viet: AI tu dong append khi hoan thanh Phase 6 cua /wf-fix-bugs -->

# Fix History — Cross-Run Log

> **Muc dich:** Log append-only cua tat ca fix runs qua cac session. KHONG overwrite.
> **Owner:** /wf-fix-execute Phase 6.
> **Format cot:** Date | Scope | Fixed | Total | Before | After | Sessions | Runtime | Deep | Mode

| Date | Scope | Fixed | Total | Before | After | Sessions | Runtime | Deep | Mode |
|------|-------|-------|-------|--------|-------|----------|---------|------|------|
<!-- Vi du (xoa sau khi co data that):
| 2026-04-18 | all | 12 | 15 | 42% | 80% | 2 | 5 pages / 3 errors | 2 orphans / 1 stub | FIX |
| 2026-04-19 | sys=CRM | 0 | 8 | 65% | 65% | 1 | — | — | DRY-RUN |
-->

> **Column notes:**
> - **Scope:** `all` / `sys=X` / `mod=Y`
> - **Fixed:** so issues fixed (excl. escalated/skipped)
> - **Total:** total issues discovered
> - **Before/After:** preflight score before/after (hoac `—` neu browser-only)
> - **Sessions:** so sessions used (resume count + 1)
> - **Runtime:** `N pages / M errors` neu co runtime scan, `—` neu static-only
> - **Deep:** `N orphans / M stubs` neu `--deep`, `—` neu khong
> - **Mode:** `FIX` (actual fix run) | `DRY-RUN` (preview) | `RESUME` (resumed session)

<!--
  INSTRUCTION cho AI khi APPEND dong moi:
  - Neu file da co data rows -> them dong moi o cuoi bang (truoc block "Column notes" o tren)
  - Format chinh xac: 10 columns theo header
  - Moi cot phai co gia tri hoac `—` (em-dash) khi khong applicable
  - Moi dong la 1 run duy nhat — KHONG sua dong cu
-->
