Bạn là **business-analyst** của DEVKIT (MCV3) — làm việc cho dự án BCERP của BC Agency (digital marketing agency: trung gian TKQC đa nền tảng Meta/Google/TikTok..., marketing, SEO, thiết kế). Bối cảnh ngành: đọc nhanh AGENTS.md §0 nếu cần — KHÔNG suy diễn mô hình kinh doanh khác.

# NHIỆM VỤ LANE: mobile-internal--CRM-PIPELINE (system=SYS-MOBILE-INTERNAL | module=MOD-CRM-PIPELINE)

Tạo **1 Feature Specification file(s)** dưới đây, mỗi FEAT-ID = 1 file. Viết tiếng Việt CÓ DẤU.

## Features của lane

### FEAT-MBI-CRM-001
- Feature name: Gate 1 & Gate 2 — Go/No-Go và ký Handoff
- REQ-ID: REQ-SALES-004
- Actors: SALES_L1, SALES_L2, SALES_L3, SALES_L4, SALES_L5
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/mobile-internal/crm-pipeline/gate-1-va-gate-2-go-no-go-va-ky-handoff.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.
  - AUTO SCORING K1–K12 (K1–K5 knockout) chạy TRƯỚC First Meeting; qualifiedTier chốt sau Full Brief — KXN-2 đã chốt.
  - Anti-duplicate 4 kênh; phân bổ lead theo quy tắc + escape hatch.
  - Gate 1 (SLA 1 ngày) / Gate 2 (nạp trước 100%, SLA 4h) — Go/No-Go; CQ theo tier 30/25/20/15/10.
  - Proposal theo tier: B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng (KXN-8, chiều V6.0).
  - Rà soát tier theo quý; UPSELL stage theo quy-trinh v1.1 file 06 §8.
- Notes:
  - Touchpoint SYS-MOBILE-INTERNAL: Mobile nội bộ (React Native, offline-capable) cho staff cần di động: duyệt-on-the-go, xem dashboard, chấm công/timesheet.
  - Fan-out: REQ REQ-SALES-004 xuất hiện ở 3 systems — đây là bản riêng cho SYS-MOBILE-INTERNAL; counterparts: SYS-CORE-BACKEND, SYS-BCERP-WEB.
  - Nguồn quy trình: documents/quy-trinh-lam-viec/ v1.1 (11 KXN đã chốt; 11 khoản còn mở ghi assumption có tag, không tự quyết).

## BƯỚC THỰC HIỆN (bắt buộc theo thứ tự)

1. **ĐỌC TEMPLATE** `.claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md` — tuân thủ CHÍNH XÁC cấu trúc: Heading → Metadata blockquotes → Bảng Thông Tin Chung (có dòng "Ghi chú Expert (A7)" nếu dept doc có A7) → Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ → Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan. Optional: Trạng Thái & Chuyển Đổi (khi entity có state machine), Tóm Tắt Entity. KHÔNG YAML front-matter, KHÔNG TODO/TBD, KHÔNG gộp features, KHÔNG thêm/bỏ section.
2. **Nạp context** (chỉ phần cần thiết):
   - REQ gốc: `.mc-data/docs/_meta/req-registry.json` (grep REQ-ID của lane lấy title/priority/systems).
   - Dept docs:
- .mc-data/docs/phase1-business/departments/sales/sales.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
   - Workflow tổng: `.mc-data/docs/phase1-business/P1-02-business-workflow.md` (chỉ section liên quan).
   - `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — DI đã resolve: DI-004 (connector kế toán = cấu hình kết nối ngoại vi trong Settings, vendor-agnostic), DI-005 (SLA/số liệu đã chốt), DI-006 (KHÔNG có OPS_CX/FIN_COMPL). 11 KXN còn mở (6,7,9,15–22): ghi vào spec như assumption có tag `[KXN-n]`, KHÔNG tự quyết.
   - Nguồn domain đặc thù theo module (chỉ khi lane thuộc module đó):
     * ADACCOUNT-CC / WALLET-RECON / QUOTATION-DEALDESK → `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model: OADS state machine, Contract serviceType bất biến, Wallet multi-currency, công thức topup k, Recharge SINGLE/DUAL, ReplacementRequest, Rebate OFF).
     * HR-CORE / KPI-PERFORMANCE / COMMISSION-QUOTA / CAPACITY-TIMESHEET → `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track nghề, salary band Q2/2026, KPI/hoa hồng theo vị trí, nội quy/phúc lợi §8, đề xuất entity TMS §9).
     * CRM-PIPELINE / HANDOFF-ONBOARD / PROPOSAL-PLANNING → `documents/quy-trinh-lam-viec/` (v1.1: 5 tier A–E V6.0, AUTO SCORING trước First Meeting, Gate 1/Gate 2, Deploy D+0→D+5, RACI/Gate/SLA file 08, hằng số file 09).
3. **VIẾT từng file** vào đúng `Output path` ở trên. Đặc thù touchpoint: Mobile App — BCERP Internal — mô tả user stories/phân quyền theo touchpoint này (web nội bộ: responsive browser UI; core backend: headless API/domain service — BR enforce ở service layer; GW: adapter/degraded mode manual; mobile nội bộ: React Native offline-capable; portal: khách hàng, read-only phần tài chính, tenant isolation; mobile portal: khách hàng, touchpoint rút gọn).
4. Quality: mỗi feature 1500–3000 từ (LPM); REQ-ID format `REQ-[DEPT]-[NNN]`; FEAT-ID đúng như trên; Phân Quyền chỉ dùng 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER cho portal/mobile-portal) — KHÔNG dùng OPS_CX/FIN_COMPL.
5. **GHI signals.json** vào `E:/BC-Working/.mc-data/work/wf-define-features/lanes/mobile-internal--CRM-PIPELINE/signals.json` theo schema:
```json
{
  "lane_key": "mobile-internal--CRM-PIPELINE",
  "lane_type": "feature",
  "system": "SYS-MOBILE-INTERNAL",
  "module": "MOD-CRM-PIPELINE",
  "items": [ { "feat_id": "...", "file": ".mc-data/docs/phase2-features/...", "req_ids": ["..."], "status": "created" } ],
  "metadata": { "completed_at": "<ISO>", "words_written": <số> }
}
```

## POST-GATE (tự kiểm tra trước khi kết thúc)
- Mỗi feature file: non-empty, đủ 9 sections bắt buộc (mỗi section ≥ 2 câu thực), heading tiếng Việt CÓ DẦU.
- Không có placeholder/TODO/TBD.
- signals.json tồn tại và valid JSON.

Trả về báo cáo ngắn: số file đã viết, đường dẫn, số từ/feature, vấn đề gặp phải (nếu có).