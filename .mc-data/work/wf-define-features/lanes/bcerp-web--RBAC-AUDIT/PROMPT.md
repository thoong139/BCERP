Bạn là **business-analyst** của DEVKIT (MCV3) — làm việc cho dự án BCERP của BC Agency (digital marketing agency: trung gian TKQC đa nền tảng Meta/Google/TikTok..., marketing, SEO, thiết kế). Bối cảnh ngành: đọc nhanh AGENTS.md §0 nếu cần — KHÔNG suy diễn mô hình kinh doanh khác.

# NHIỆM VỤ LANE: bcerp-web--RBAC-AUDIT (system=SYS-BCERP-WEB | module=MOD-RBAC-AUDIT)

Tạo **7 Feature Specification file(s)** dưới đây, mỗi FEAT-ID = 1 file. Viết tiếng Việt CÓ DẤU.

## Features của lane

### FEAT-ERP-RBAC-001
- Feature name: Compensating control kiêm nhiệm CFO kiêm CTO
- REQ-ID: REQ-BOD-002
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/compensating-control-kiem-nhiem-cfo-kiem-cto.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-BOD-002 xuất hiện ở 3 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND, SYS-MOBILE-INTERNAL.

### FEAT-ERP-RBAC-002
- Feature name: Giám sát & truy xuất audit log
- REQ-ID: REQ-BOD-005
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/giam-sat-va-truy-xuat-audit-log.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-BOD-005 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND.

### FEAT-ERP-RBAC-003
- Feature name: Quarterly access review & phân quyền
- REQ-ID: REQ-BOD-007
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/quarterly-access-review-va-phan-quyen.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-BOD-007 xuất hiện ở 3 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND, SYS-INTEGRATION-GW.

### FEAT-ERP-RBAC-004
- Feature name: Phê duyệt chính sách, tham số quản trị & tier
- REQ-ID: REQ-BOD-009
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/phe-duyet-chinh-sach-tham-so-quan-tri-va-tier.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-BOD-009 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND.

### FEAT-ERP-RBAC-005
- Feature name: Nền tảng RBAC & SSO/MFA tập trung (cross-cutting)
- REQ-ID: REQ-BOD-011
- Actors: BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, CUSTOMER
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/nen-tang-rbac-va-sso-mfa-tap-trung-cross-cutting.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-BOD-011 xuất hiện ở 4 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND, SYS-PORTAL-WEB, SYS-MOBILE-INTERNAL.

### FEAT-ERP-RBAC-006
- Feature name: Bảo vệ PII nhân sự (lương Confidential/Restricted)
- REQ-ID: REQ-HR-010
- Actors: HR_L1, HR_L2
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/bao-ve-pii-nhan-su-luong-confidential-restricted.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-HR-010 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND.

### FEAT-ERP-RBAC-007
- Feature name: Lưu trữ chứng từ & audit log tiền ≥10 năm (WORM)
- REQ-ID: REQ-FIN-012
- Actors: FIN_L1, FIN_L2, BOD_CFO_CTO
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/phase2-features/bcerp-web/rbac-audit/luu-tru-chung-tu-va-audit-log-tien-10-nam-worm.md
- Cross-dependencies: (không có)
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
  - RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.
  - Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.
  - Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).
  - SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.
  - Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.
- Notes:
  - Touchpoint SYS-BCERP-WEB: Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.
  - Fan-out: REQ REQ-FIN-012 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND.

## BƯỚC THỰC HIỆN (bắt buộc theo thứ tự)

1. **ĐỌC TEMPLATE** `.claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md` — tuân thủ CHÍNH XÁC cấu trúc: Heading → Metadata blockquotes → Bảng Thông Tin Chung (có dòng "Ghi chú Expert (A7)" nếu dept doc có A7) → Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ → Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan. Optional: Trạng Thái & Chuyển Đổi (khi entity có state machine), Tóm Tắt Entity. KHÔNG YAML front-matter, KHÔNG TODO/TBD, KHÔNG gộp features, KHÔNG thêm/bỏ section.
2. **Nạp context** (chỉ phần cần thiết):
   - REQ gốc: `.mc-data/docs/_meta/req-registry.json` (grep REQ-ID của lane lấy title/priority/systems).
   - Dept docs:
- .mc-data/docs/phase1-business/departments/bod/bod.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)
   - Workflow tổng: `.mc-data/docs/phase1-business/P1-02-business-workflow.md` (chỉ section liên quan).
   - `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — DI đã resolve: DI-004 (connector kế toán = cấu hình kết nối ngoại vi trong Settings, vendor-agnostic), DI-005 (SLA/số liệu đã chốt), DI-006 (KHÔNG có OPS_CX/FIN_COMPL). 11 KXN còn mở (6,7,9,15–22): ghi vào spec như assumption có tag `[KXN-n]`, KHÔNG tự quyết.
   - Nguồn domain đặc thù theo module (chỉ khi lane thuộc module đó):
     * ADACCOUNT-CC / WALLET-RECON / QUOTATION-DEALDESK → `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model: OADS state machine, Contract serviceType bất biến, Wallet multi-currency, công thức topup k, Recharge SINGLE/DUAL, ReplacementRequest, Rebate OFF).
     * HR-CORE / KPI-PERFORMANCE / COMMISSION-QUOTA / CAPACITY-TIMESHEET → `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track nghề, salary band Q2/2026, KPI/hoa hồng theo vị trí, nội quy/phúc lợi §8, đề xuất entity TMS §9).
     * CRM-PIPELINE / HANDOFF-ONBOARD / PROPOSAL-PLANNING → `documents/quy-trinh-lam-viec/` (v1.1: 5 tier A–E V6.0, AUTO SCORING trước First Meeting, Gate 1/Gate 2, Deploy D+0→D+5, RACI/Gate/SLA file 08, hằng số file 09).
3. **VIẾT từng file** vào đúng `Output path` ở trên. Đặc thù touchpoint: BCERP Web nội bộ — mô tả user stories/phân quyền theo touchpoint này (web nội bộ: responsive browser UI; core backend: headless API/domain service — BR enforce ở service layer; GW: adapter/degraded mode manual; mobile nội bộ: React Native offline-capable; portal: khách hàng, read-only phần tài chính, tenant isolation; mobile portal: khách hàng, touchpoint rút gọn).
4. Quality: mỗi feature 1500–3000 từ (LPM); REQ-ID format `REQ-[DEPT]-[NNN]`; FEAT-ID đúng như trên; Phân Quyền chỉ dùng 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER cho portal/mobile-portal) — KHÔNG dùng OPS_CX/FIN_COMPL.
5. **GHI signals.json** vào `E:/BC-Working/.mc-data/work/wf-define-features/lanes/bcerp-web--RBAC-AUDIT/signals.json` theo schema:
```json
{
  "lane_key": "bcerp-web--RBAC-AUDIT",
  "lane_type": "feature",
  "system": "SYS-BCERP-WEB",
  "module": "MOD-RBAC-AUDIT",
  "items": [ { "feat_id": "...", "file": ".mc-data/docs/phase2-features/...", "req_ids": ["..."], "status": "created" } ],
  "metadata": { "completed_at": "<ISO>", "words_written": <số> }
}
```

## POST-GATE (tự kiểm tra trước khi kết thúc)
- Mỗi feature file: non-empty, đủ 9 sections bắt buộc (mỗi section ≥ 2 câu thực), heading tiếng Việt CÓ DẦU.
- Không có placeholder/TODO/TBD.
- signals.json tồn tại và valid JSON.

Trả về báo cáo ngắn: số file đã viết, đường dẫn, số từ/feature, vấn đề gặp phải (nếu có).