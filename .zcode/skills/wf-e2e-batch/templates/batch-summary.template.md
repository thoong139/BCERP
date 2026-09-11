# Batch E2E Test — Tóm Tắt

<!-- Template: batch-summary.template.md | Schema: e2e-batch-v1 -->
<!-- Populate tất cả {placeholders}. Giữ ≤20 dòng nội dung chính (CORE-028). -->

**Batch ID:** {batch_id}
**Thời gian:** {started_at} → {completed_at}
**Scope:** {scope_or_feats_list}
**Trạng thái:** {COMPLETED | PARTIAL | FAILED | BLOCKED}

## Kết Quả Theo FEAT

| FEAT | Trạng thái | Scenarios Pass | Scenarios Fail | Issues Open |
|------|-----------|---------------|---------------|------------|
| {feat_id_1} | {completed/failed/blocked} | {N}/{total} | {N}/{total} | {N} |

## Tóm Tắt

- **Tổng FEATs:** {total}
- **PASS:** {passed} ({pass_rate}%)
- **FAIL:** {failed}
- **BLOCKED:** {blocked}

## Hành Động Cần Thiết

{Nếu không có FEAT fail/blocked: "Tất cả FEATs đã PASS. Có thể chạy /wf-verify-sync để kiểm tra coverage."}

{Nếu có FEAT fail/blocked:}
| FEAT | Vấn đề | Lệnh gợi ý |
|------|--------|------------|
| {feat_id} | {lý do fail/blocked} | `/wf-e2e-verify {feat_id} --from-step=F{N}` |
