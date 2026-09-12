Bạn là **business-analyst** của DEVKIT (MCV3) — làm việc cho dự án BCERP của BC Agency (digital marketing agency: trung gian TKQC đa nền tảng Meta/Google/TikTok..., marketing, SEO, thiết kế). Bối cảnh ngành: đọc nhanh AGENTS.md §0 nếu cần — KHÔNG suy diễn mô hình kinh doanh khác.

# NHIỆM VỤ LANE: core-backend--CAPACITY-TIMESHEET (system=SYS-CORE-BACKEND | module=MOD-CAPACITY-TIMESHEET)

Tạo **2 Feature Specification file(s)** dưới đây, mỗi FEAT-ID = 1 file. Viết tiếng Việt CÓ DẤU.

## Features của lane

### FEAT-CORE-CAPTS-001
- Feature name: Duyệt timesheet & capacity (phối hợp OPS)
- REQ-ID: REQ-HR-009
- Actors: HR_L1, HR_L2
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/core-backend/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md
- Cross-dependencies: REQ-OPS-007 — timesheet: HR chính sách+duyệt, OPS ghi nhận
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  - Cấm tự duyệt timesheet; duyệt HR/OPS phối hợp (nguồn sự thật HR, OPS ghi nhận); delegate TL [KXN] chưa chốt.
  - Giờ làm việc/nghỉ phép nội quy theo 03_Quy_che_KPI_HR.md §8; mobile chấm công cho staff.
- Notes:
  - Touchpoint SYS-CORE-BACKEND: Headless API/domain services trên core backend — mọi business rule phải được enforce ở tầng service (không tin UI), audit log + tenant isolation.
  - Fan-out: REQ REQ-HR-009 xuất hiện ở 2 systems — đây là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-BCERP-WEB.
  - Nguồn domain chi tiết: documents/03_Quy_che_KPI_HR.md (HR Domain Knowledge Base — salary band, KPI/hoa hồng theo vị trí).

### FEAT-CORE-CAPTS-002
- Feature name: Capacity & Timesheet
- REQ-ID: REQ-OPS-007
- Actors: OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/core-backend/capacity-timesheet/capacity-va-timesheet.md
- Cross-dependencies: REQ-HR-009 — chính sách duyệt timesheet từ HR
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.
  - Cấm tự duyệt timesheet; duyệt HR/OPS phối hợp (nguồn sự thật HR, OPS ghi nhận); delegate TL [KXN] chưa chốt.
  - Giờ làm việc/nghỉ phép nội quy theo 03_Quy_che_KPI_HR.md §8; mobile chấm công cho staff.
- Notes:
  - Touchpoint SYS-CORE-BACKEND: Headless API/domain services trên core backend — mọi business rule phải được enforce ở tầng service (không tin UI), audit log + tenant isolation.
  - Fan-out: REQ REQ-OPS-007 xuất hiện ở 3 systems — đây là bản riêng cho SYS-CORE-BACKEND; counterparts: SYS-BCERP-WEB, SYS-MOBILE-INTERNAL.
  - Nguồn domain chi tiết: documents/03_Quy_che_KPI_HR.md (HR Domain Knowledge Base — salary band, KPI/hoa hồng theo vị trí).

## BƯỚC THỰC HIỆN (bắt buộc theo thứ tự)

1. **ĐỌC TEMPLATE** `.claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md` — tuân thủ CHÍNH XÁC cấu trúc: Heading → Metadata blockquotes → Bảng Thông Tin Chung (có dòng "Ghi chú Expert (A7)" nếu dept doc có A7) → Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ → Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan. Optional: Trạng Thái & Chuyển Đổi (khi entity có state machine), Tóm Tắt Entity. KHÔNG YAML front-matter, KHÔNG TODO/TBD, KHÔNG gộp features, KHÔNG thêm/bỏ section.
2. **Nạp context** (chỉ phần cần thiết):
   - REQ gốc: `.mc-data/docs/_meta/req-registry.json` (grep REQ-ID của lane lấy title/priority/systems).
   - Dept docs:
- .mc-data/docs/phase1-business/departments/hr/hr.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
- .mc-data/docs/phase1-business/departments/operations/operations.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
   - Workflow tổng: `.mc-data/docs/phase1-business/P1-02-business-workflow.md` (chỉ section liên quan).
   - `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — DI đã resolve: DI-004 (connector kế toán = cấu hình kết nối ngoại vi trong Settings, vendor-agnostic), DI-005 (SLA/số liệu đã chốt), DI-006 (KHÔNG có OPS_CX/FIN_COMPL). 11 KXN còn mở (6,7,9,15–22): ghi vào spec như assumption có tag `[KXN-n]`, KHÔNG tự quyết.
   - Nguồn domain đặc thù theo module (chỉ khi lane thuộc module đó):
     * ADACCOUNT-CC / WALLET-RECON / QUOTATION-DEALDESK → `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model: OADS state machine, Contract serviceType bất biến, Wallet multi-currency, công thức topup k, Recharge SINGLE/DUAL, ReplacementRequest, Rebate OFF).
     * HR-CORE / KPI-PERFORMANCE / COMMISSION-QUOTA / CAPACITY-TIMESHEET → `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track nghề, salary band Q2/2026, KPI/hoa hồng theo vị trí, nội quy/phúc lợi §8, đề xuất entity TMS §9).
     * CRM-PIPELINE / HANDOFF-ONBOARD / PROPOSAL-PLANNING → `documents/quy-trinh-lam-viec/` (v1.1: 5 tier A–E V6.0, AUTO SCORING trước First Meeting, Gate 1/Gate 2, Deploy D+0→D+5, RACI/Gate/SLA file 08, hằng số file 09).
3. **VIẾT từng file** vào đúng `Output path` ở trên. Đặc thù touchpoint: BCERP Core Backend — mô tả user stories/phân quyền theo touchpoint này (web nội bộ: responsive browser UI; core backend: headless API/domain service — BR enforce ở service layer; GW: adapter/degraded mode manual; mobile nội bộ: React Native offline-capable; portal: khách hàng, read-only phần tài chính, tenant isolation; mobile portal: khách hàng, touchpoint rút gọn).
4. Quality: mỗi feature 1500–3000 từ (LPM); REQ-ID format `REQ-[DEPT]-[NNN]`; FEAT-ID đúng như trên; Phân Quyền chỉ dùng 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER cho portal/mobile-portal) — KHÔNG dùng OPS_CX/FIN_COMPL.
5. **GHI signals.json** vào `E:/BC-Working/.mc-data/work/wf-define-features/lanes/core-backend--CAPACITY-TIMESHEET/signals.json` theo schema:
```json
{
  "lane_key": "core-backend--CAPACITY-TIMESHEET",
  "lane_type": "feature",
  "system": "SYS-CORE-BACKEND",
  "module": "MOD-CAPACITY-TIMESHEET",
  "items": [ { "feat_id": "...", "file": ".mc-data/docs/phase2-features/...", "req_ids": ["..."], "status": "created" } ],
  "metadata": { "completed_at": "<ISO>", "words_written": <số> }
}
```

## POST-GATE (tự kiểm tra trước khi kết thúc)
- Mỗi feature file: non-empty, đủ 9 sections bắt buộc (mỗi section ≥ 2 câu thực), heading tiếng Việt CÓ DẦU.
- Không có placeholder/TODO/TBD.
- signals.json tồn tại và valid JSON.

Trả về báo cáo ngắn: số file đã viết, đường dẫn, số từ/feature, vấn đề gặp phải (nếu có).