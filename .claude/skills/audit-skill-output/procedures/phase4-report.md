# Phase 4 — Collect Results, Verdict & Report

> Merge tất cả findings từ 3 phases, tính verdict, xuất báo cáo, finalize status.

**PRE-GATE:** Phase 1-3 completed.

## Steps

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 4.1 | Merge: `structural_findings` + `fix_log` + `d4_findings` + `d5_findings` | — | all_findings[] |
| 4.2 | Deduplicate (cùng vấn đề bởi nhiều dimensions → giữ 1, ghi nguồn) | — | deduped[] |
| 4.3 | Classify: CRITICAL → MAJOR → MINOR → INFO | — | classified[] |
| 4.4 | Tính metrics: counts (sau fix), compliance rate, content score (từ D4) | — | metrics{} |
| 4.5 | Xác định verdict: PASS / PASS_WITH_WARN / FAIL. **Khi auto-fix:** dựa trên findings còn lại SAU fix. **Khi `--no-fix`:** dựa trên findings CHƯA fix từ Phase 1+3 (CRITICAL > 0 → FAIL tất cả). Chi tiết: xem `_shared.md §7 Verdict Logic` | — | verdict |
| 4.6 | Generate report từ `templates/audit-report.md` — điền findings gốc + fix results + D4/D5, lưu tại `.mc-data/work/audit-skill-output/audit-report-[skill]-[date].md` | Write | report_file |
| 4.6b | Finalize status file: `status = "completed"`, `phases.phase_4.verdict`, `phases.phase_4.report_file`, `phases.phase_4.dimensions_audited`, `completed_at`, `reports[]` append | Write | status finalized |
| 4.6c | **CORE-028:** Tạo phase-summary.md từ template `templates/phase-summary.md` — populate: skill-name, date, verdict, metrics, issues cần xử lý (nếu có), bước tiếp theo. Max 15 dòng, tiếng Việt. Lưu tại `.mc-data/work/audit-skill-output/phase-summary.md`. Hiển thị cho user | Write | phase-summary exists |
| 4.7 | Hiển thị summary cho user | — | displayed |

## Report Summary Format (Inline)

```markdown
## /audit-skill-output Hoàn Tất!

| Mục | Giá trị |
|-----|---------|
| Skill audited | [skill-name] |
| Dimensions kiểm tra | [N] / 7 (+ D8 nếu Master Plan enabled) |
| Tổng checks | [N] |
| PASS / WARN / FAIL | [N] / [N] / [N] |
| Content Score (D4) | [0-100 hoặc N/A] |
| Auto-fix applied | [N] (hoặc N/A nếu --no-fix) |
| **Verdict** | PASS / PASS_WITH_WARN / FAIL |

Report: .mc-data/work/audit-skill-output/audit-report-[skill]-[date].md
```

**Các section trong report file:**
- **Tóm Tắt** — metrics table (dimensions kiểm tra, PASS/WARN/FAIL counts, Content Score, Verdict)
- **Chi Tiết theo Dimension** — D1 đến D7 (+ D8 nếu Master Plan enabled)
- **Hành Động Cần Thiết** — CRITICAL / MAJOR / MINOR grouped tables
- **Fix Results** — kết quả auto-fix (nếu có, bỏ qua khi `--no-fix`)
- **Đề Xuất Cải Thiện Skill** — feedback cho SKILL.md design

## Bước Tiếp Theo Sau Audit

| Verdict | Hành động |
|---------|-----------|
| PASS | Tiếp tục workflow — chạy skill tiếp theo trong chuỗi |
| PASS_WITH_WARN | Xem xét fix MAJOR issues hoặc tiếp tục nếu chấp nhận rủi ro. Chạy `/wf-fix-bugs` nếu cần |
| FAIL | Phải fix CRITICAL issues trước khi tiếp tục. Chạy `/wf-fix-bugs` hoặc re-run skill bị lỗi |

## POST-GATE

- Report file tồn tại tại `.mc-data/work/audit-skill-output/audit-report-[skill]-[date].md`
- Summary hiển thị cho user
- Status file finalized (`status = "completed"`, verdict ghi rõ)
- **CORE-028:** `phase-summary.md` tồn tại tại `.mc-data/work/audit-skill-output/`
- **CORE-026:** Append COMPLETE (hoặc FAIL) entry to `.mc-data/work/_trace/session-log.json` (skill: `audit-skill-output`, event: `COMPLETE`/`FAIL`, verdict, files_created)

## Next

→ Nếu `--all` mode: quay lại Phase 0 cho skill tiếp theo trong `skills_to_audit[]`. Nếu hết → END.
→ Nếu single skill: END.
