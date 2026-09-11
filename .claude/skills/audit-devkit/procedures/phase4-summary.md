# Phase 4: Summary Display

> **Đọc:** `procedures/_shared.md §Verdict Computation` + `templates/` directory để render.

**Điều kiện chạy:** LUÔN chạy ở cuối pipeline (sau khi các stages khác xong).

**Mục đích:** Thu thập data từ tất cả phases đã chạy, load templates, render markdown summary cho user.

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.1 | Thu thập data từ state variables: `$PIPELINE_MODE`, `$STAGES[]`, `$SCOPE`, `$FIX_MODE`, `$SCAN_SUMMARY`, `$VERIFY_VERDICT_PRE_FIX`, `$VERIFY_VERDICT_POST_FIX`, `$FIX_SUMMARY`, `$MASTER_PLAN_STATUS`, `$EVAL_STATUS`, `$SESSION_ID` | — | Data collected |
| 4.2 | **READ template:** `templates/summary-main.md` → populate variables | Read | Template loaded |
| 4.3 | Nếu `$MASTER_PLAN_STATUS` populated → **READ** `templates/summary-masterplan-section.md` → populate + append vào output | Read | Section appended |
| 4.4 | Nếu `$EVAL_STATUS` populated → **READ** `templates/summary-evals-section.md` → populate + append vào output | Read | Section appended |
| 4.5 | Nếu `$SCOPE = focused-skill` → append section "Focused Findings: $FOCUSED_SKILL" (liệt kê findings + verdict cho skill) | — | Appended |
| 4.6 | Hiển thị toàn bộ summary cho user | Output | Displayed |
| 4.7 | Nếu có manual issues (fix_type=MANUAL từ verify) → list ra cho user | Output | Displayed |
| 4.8 | Hiển thị next steps guidance: | Output | Displayed |

**Next steps guidance:**

| Verdict | Next step |
|---------|-----------|
| `CLEAN` | "Không có issues. DEVKIT sẵn sàng release." |
| `ACCEPTABLE` | "Có vài issues nhỏ. Có thể release với notes. Xem manual issues nếu có." |
| `NEEDS ATTENTION` | "Cần fix CRITICAL-functional issues trước khi release." |
| `BROKEN` | "KHÔNG release. Chạy `/audit-devkit --fix-only` hoặc fix thủ công. Sau đó chạy `/audit-devkit --no-fix` để verify." |

---

## Edge Cases

| Mode | Summary behavior |
|------|------------------|
| `--no-fix` | Bỏ dòng "Auto-fixed" trong template. Verdict chỉ hiển thị 1 giá trị (pre-fix) |
| `--scan-only` | Chỉ hiển thị scan summary (skip verify/fix/masterplan sections) |
| `--master-plan` | Chỉ hiển thị Master Plan Components Status section. KHÔNG có audit verdict |
| `--fix-only` | Hiển thị fix summary + verdict before/after. Skip scan summary section |
| `--quick` | Như `--scan-only`, note rõ "Structural scan only" |

---

## Output Files Reference

Summary PHẢI list các output files từ sub-skills (KHÔNG duplicate info — chỉ pointer):

> **Lưu ý:** Session-id format = timestamp directory (VD: `20260419-100000`). Paths dùng `$SESSION_ID`.

| # | File | Path | Producer |
|---|------|------|----------|
| 1 | audit-index.json | `.mc-data/work/audit-devkit-scan/$SESSION_ID/` | audit-devkit-scan |
| 2 | audit-scan-result.json | `.mc-data/work/audit-devkit-scan/$SESSION_ID/` | audit-devkit-scan |
| 3 | audit-verified-result.json | `.mc-data/work/audit-devkit-verify/$SESSION_ID/` | audit-devkit-verify |
| 4 | fix-log.json | `.mc-data/work/audit-devkit-fix/$SESSION_ID/` | audit-devkit-fix |
| 5 | devkit-audit-[date].md | `.mc-data/work/audit-devkit-verify/reports/` | audit-devkit-verify |
| 6 | devkit-audit-fix-[date].md | `.mc-data/work/audit-devkit-fix/reports/` | audit-devkit-fix |
| 7 | eval-results.json | `docs/audit/work/eval-results.json` (fixed location, NOT session-isolated) | eval harness (opt-in) |
| 8 | eval-results.md | `docs/audit/reports/eval-results.md` (fixed location, NOT session-isolated) | eval harness (opt-in) |

---

## POST-GATE

| Check | Required |
|-------|----------|
| Markdown summary được hiển thị cho user | ✓ |
| Next steps guidance hiển thị | ✓ |
| 3 verdicts (Audit / MasterPlan / Eval) hiển thị khi applicable | ✓ |
