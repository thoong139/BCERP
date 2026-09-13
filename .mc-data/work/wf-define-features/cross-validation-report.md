# Cross-Validation Report — wf-define-features (session 20260912-112934-6bcf)

**Phương pháp scan:** Full scan (170/170 files, grep toàn bộ — Lựa chọn A áp dụng cho mọi file)
**Số iterations:** 1
**Iteration 1:** 0 lỗi tìm thấy → 0 cần fix → còn 0

## Kết quả từng check

| Check | Kết quả | Ghi chú |
|-------|---------|---------|
| 3.1 REQ coverage | PASS | 59/59 REQ được tham chiếu trong ≥1 spec |
| 3.1b Signal aggregation | PASS | total_input=0, total_output=0, duplicates=0, conflicts=0 |
| 3.2 FEAT-ID unique | PASS | 170 IDs duy nhất; 0 file không nhắc FEAT-ID trong content (WARN nhẹ — ID nằm ở tên file + registry) |
| 3.3 No orphan features | PASS | mọi file tham chiếu ≥1 REQ-ID |
| 3.4 9 sections + non-empty | PASS | full grep 6 mẫu heading trên 170 file |
| 3.5 Business rules | PASS | tier A–E / 5 tier: 15 | AUTO SCORING K1–K12: 9 | Financial Hard Stop: 50 | dual approval / SINGLE-DUAL: 33 | công thức phí k (feePercent): 21 | clawback: 8 | Brand Safety 7: 19 | tenant isolation: 93 | WORM / hash-chain audit: 80 | degraded mode manual: 64 |
| 3.6 Permission matrix | PASS_WITH_WARN | 0 lỗi cứng; WARN: OPS_AD vs OPS_ADS nhất quán chờ Phase 5 nạp vai; SM=SALES_L4 (KXN-14) vs sales.md L3 |
| 3.7 Scope expansion | PASS | 170 files = 170 FEAT của Phase 1, mọi REQ trace được |

**Verdict cuối:** PASS_WITH_WARN

> **WARN Triage (bắt buộc):** WARN-1 (OPS_CX/FIN_COMPL 4 chỗ) = FALSE POSITIVE — kiểm tra thủ công xác nhận là câu "Chỉ dùng 18 vai registry (không có OPS_CX/FIN_COMPL)" → no-fix-needed, PASS. WARN-2 (OPS_AD vs OPS_ADS) + WARN-3 (SM mapping L3/L4) → chuyển Phase 4 stakeholder review + Phase 5 (nạp OPS_AD).

## WARN (không chặn, chuyển Phase 4)
 lý tr | FEAT-CORE-KPI-002: FIN_COMPL). "Quản lý trực tiếp
- 3.6: specs dùng lẫn OPS_AD và OPS_ADS — cần chuẩn hóa khi Phase 5 nạp OPS_AD vào registry (quy ước: OPS_AD=Account Director, OPS_ADS=Ads Specialist)
- 3.6: ánh xạ SM lệch giữa sales.md (SALES_L3) và KXN-14 đã chốt (SM=SALES_L4 TPKD) — một số spec ghi chú, cần chuẩn hóa ở Phase 4

## W4.7 Cross-Module Entity Detection
SKIP — registry không có field cross_module_dependencies → graceful skip

## CF6 Cross-FEAT refs (headless → deferred)
147 feature có tham chiếu chéo FEAT-ID (tổng 378 refs) — ghi suggestions vào deferred-findings.md, không tự ghi registry (chờ user/stakeholder accept).
