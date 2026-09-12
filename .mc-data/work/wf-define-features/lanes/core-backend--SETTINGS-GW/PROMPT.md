Bạn là **business-analyst** của DEVKIT (MCV3) — làm việc cho dự án BCERP của BC Agency (digital marketing agency: trung gian TKQC đa nền tảng Meta/Google/TikTok..., marketing, SEO, thiết kế). Bối cảnh ngành: đọc nhanh AGENTS.md §0 nếu cần — KHÔNG suy diễn mô hình kinh doanh khác.

# NHIỆM VỤ LANE: core-backend--SETTINGS-GW (system=SYS-CORE-BACKEND | module=MOD-SETTINGS-GW)

Tạo **2 Feature Specification file(s)** dưới đây, mỗi FEAT-ID = 1 file. Viết tiếng Việt CÓ DẤU.

## Features của lane

### FEAT-CORE-STGW-001
- Feature name: Quản trị Integration Gateway & credentials vault (vai CTO)
- REQ-ID: REQ-BOD-008
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/core-backend/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md
- Cross-dependencies: REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-004)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm.
  - API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) — credentials vault + sync scheduler.
  - Mọi integration phải có degraded mode "manual" + backfill khi mất quyền API (DI-007: Business Verification chưa có quyền developer).
  - Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA) chỉ ADMIN/BOD sửa, có version + audit.
- Notes:
  - Touchpoint SYS-CORE-BACKEND: Headless API/domain services trên core backend — mọi business rule phải được enforce ở tầng service (không tin UI), audit log + tenant isolation.
  - Fan-out: REQ REQ-BOD-008 xuất hiện ở 3 systems — đây là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-INTEGRATION-GW, SYS-BCERP-WEB.

### FEAT-CORE-STGW-002
- Feature name: API 7 nền tảng + degraded mode manual
- REQ-ID: REQ-FIN-005
- Actors: FIN_L1, FIN_L2, BOD_CFO_CTO
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/core-backend/settings-gw/api-7-nen-tang-degraded-mode-manual.md
- Cross-dependencies: REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account CC + ví
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm.
  - API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) — credentials vault + sync scheduler.
  - Mọi integration phải có degraded mode "manual" + backfill khi mất quyền API (DI-007: Business Verification chưa có quyền developer).
  - Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA) chỉ ADMIN/BOD sửa, có version + audit.
- Notes:
  - Touchpoint SYS-CORE-BACKEND: Headless API/domain services trên core backend — mọi business rule phải được enforce ở tầng service (không tin UI), audit log + tenant isolation.
  - Fan-out: REQ REQ-FIN-005 xuất hiện ở 3 systems — đây là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-INTEGRATION-GW, SYS-BCERP-WEB.

## BƯỚC THỰC HIỆN (bắt buộc theo thứ tự)

1. **ĐỌC TEMPLATE** `.claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md` — tuân thủ CHÍNH XÁC cấu trúc: Heading → Metadata blockquotes → Bảng Thông Tin Chung (có dòng "Ghi chú Expert (A7)" nếu dept doc có A7) → Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ → Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan. Optional: Trạng Thái & Chuyển Đổi (khi entity có state machine), Tóm Tắt Entity. KHÔNG YAML front-matter, KHÔNG TODO/TBD, KHÔNG gộp features, KHÔNG thêm/bỏ section.
2. **Nạp context** (chỉ phần cần thiết):
   - REQ gốc: `.mc-data/docs/_meta/req-registry.json` (grep REQ-ID của lane lấy title/priority/systems).
   - Dept docs:
- .mc-data/docs/phase1-business/departments/bod/bod.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
- .mc-data/docs/phase1-business/departments/finance/finance.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
   - Workflow tổng: `.mc-data/docs/phase1-business/P1-02-business-workflow.md` (chỉ section liên quan).
   - `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — DI đã resolve: DI-004 (connector kế toán = cấu hình kết nối ngoại vi trong Settings, vendor-agnostic), DI-005 (SLA/số liệu đã chốt), DI-006 (KHÔNG có OPS_CX/FIN_COMPL). 11 KXN còn mở (6,7,9,15–22): ghi vào spec như assumption có tag `[KXN-n]`, KHÔNG tự quyết.
   - Nguồn domain đặc thù theo module (chỉ khi lane thuộc module đó):
     * ADACCOUNT-CC / WALLET-RECON / QUOTATION-DEALDESK → `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model: OADS state machine, Contract serviceType bất biến, Wallet multi-currency, công thức topup k, Recharge SINGLE/DUAL, ReplacementRequest, Rebate OFF).
     * HR-CORE / KPI-PERFORMANCE / COMMISSION-QUOTA / CAPACITY-TIMESHEET → `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track nghề, salary band Q2/2026, KPI/hoa hồng theo vị trí, nội quy/phúc lợi §8, đề xuất entity TMS §9).
     * CRM-PIPELINE / HANDOFF-ONBOARD / PROPOSAL-PLANNING → `documents/quy-trinh-lam-viec/` (v1.1: 5 tier A–E V6.0, AUTO SCORING trước First Meeting, Gate 1/Gate 2, Deploy D+0→D+5, RACI/Gate/SLA file 08, hằng số file 09).
3. **VIẾT từng file** vào đúng `Output path` ở trên. Đặc thù touchpoint: BCERP Core Backend — mô tả user stories/phân quyền theo touchpoint này (web nội bộ: responsive browser UI; core backend: headless API/domain service — BR enforce ở service layer; GW: adapter/degraded mode manual; mobile nội bộ: React Native offline-capable; portal: khách hàng, read-only phần tài chính, tenant isolation; mobile portal: khách hàng, touchpoint rút gọn).
4. Quality: mỗi feature 1500–3000 từ (LPM); REQ-ID format `REQ-[DEPT]-[NNN]`; FEAT-ID đúng như trên; Phân Quyền chỉ dùng 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER cho portal/mobile-portal) — KHÔNG dùng OPS_CX/FIN_COMPL.
5. **GHI signals.json** vào `E:/BC-Working/.mc-data/work/wf-define-features/lanes/core-backend--SETTINGS-GW/signals.json` theo schema:
```json
{
  "lane_key": "core-backend--SETTINGS-GW",
  "lane_type": "feature",
  "system": "SYS-CORE-BACKEND",
  "module": "MOD-SETTINGS-GW",
  "items": [ { "feat_id": "...", "file": ".mc-data/docs/phase2-features/...", "req_ids": ["..."], "status": "created" } ],
  "metadata": { "completed_at": "<ISO>", "words_written": <số> }
}
```

## POST-GATE (tự kiểm tra trước khi kết thúc)
- Mỗi feature file: non-empty, đủ 9 sections bắt buộc (mỗi section ≥ 2 câu thực), heading tiếng Việt CÓ DẦU.
- Không có placeholder/TODO/TBD.
- signals.json tồn tại và valid JSON.

Trả về báo cáo ngắn: số file đã viết, đường dẫn, số từ/feature, vấn đề gặp phải (nếu có).