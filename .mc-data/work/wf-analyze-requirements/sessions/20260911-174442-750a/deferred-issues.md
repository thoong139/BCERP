# Deferred Issues từ /wf-analyze-requirements

> Nguồn: phase1-business/stakeholder-review.md — DEFER-TO-PHASE items
> Ngày tạo: 2026-09-12
> Consumer: /wf-define-features Phase 0 (context), /wf-design Phase 0 (context)
> LƯU Ý: Không có items KHẨN CẤP — SO2-01 (Critical) đã được resolve ngay trong run này bằng Phase 8 registry update (xem stakeholder-review.md Phần E, DR-001)

## Tóm Tắt

| Mức độ | Số lượng | Xử lý khi nào |
|--------|----------|---------------|
| TRUNG BÌNH | 5 | Đầu /wf-define-features Phase 0 (stakeholder confirm số liệu) |
| NHỎ | 2 | Trong Phase 2/3 của wf-define-features hoặc /wf-design |

## Danh sách Issues

| # | Issue ID | Loại | Severity | Mô tả | Departments liên quan | Phase xử lý |
|---|---------|------|----------|--------|----------------------|-------------|
| 1 | DI-001 | data-gap | Medium | 6 nhóm [CẦN CHỐT SỐ] gom theo SO3-09: ngưỡng giải ngân 5/50/200tr, dung sai đối soát, định mức giờ/cost-per-hour L1–L5, ma trận SLA creative/rounds, thang hoa hồng + quota L1–L5, ngưỡng AML T1–T6 + UBO 25% (đều CÓ mặc định đề xuất, chỉ cần stakeholder xác nhận) | ALL | /wf-define-features Phase 0 |
| 2 | DI-002 | policy-doc | Medium | stage-gate-lifecycle-v6.md §2.1 mâu thuẫn phan-loai-khach-hang-tier.md §2.2 về số trang/người soạn proposal theo tier (B/C vs D/E bị đảo) — đã dùng tier policy làm nguồn sự thật trong BR-OPS-6.3; cần hiệu chỉnh bản policy stage-gate | OPS, SALES | Sửa policy library trước /wf-design |
| 3 | DI-003 | spec-gap | Medium | Tiêu chí stage DEPLOY trong Lifecycle V6.0 chưa hoàn thiện (Lifecycle gốc không có chi tiết — đề xuất tại BR-OPS-6.x cần xác nhận) | OPS | /wf-define-features Phase 2 |
| 4 | DI-004 | dependency | Medium | Tên phần mềm kế toán VAS hiện hữu chưa xác định (connector đối chiếu sổ) + PMS cũ trong quy trình V6.0 (thay thế hoàn toàn hay migration) — 2 điểm P0 đã flag, cần chủ dự án cung cấp | FIN, SALES | /wf-define-features Phase 0 (hỏi user) |
| 5 | DI-005 | data-gap | Medium | 6 [CẦN CHỐT SỐ] còn lại trong operations.md: hạn mức VND/ngày theo cấp buyer, ca trực Critical 24/7, sample size A/B, số ngày chờ confirm nghiệm thu, SLA từng bước duyệt creative, vòng sửa creative | OPS | /wf-define-features Phase 0 |
| 6 | DI-006 | role-model | Small | Vai mới OPS_CX, FIN_COMPL + quy ước delegate duyệt timesheet (đề xuất trong stakeholder-review.md Phụ lục Phase 6d) cần thêm vào registry + xác nhận tổ chức thực tế | OPS, FIN | ✅ **Resolved 12/09/2026** — user TỪ CHỐI 2 vai; trách nhiệm gán lại OPS_PLAN / FIN_L2+BOD (stakeholder-review.md Phần F.3) |
| 7 | DI-007 | integration | Small | Business Verification 7 nền tảng QC chưa có quyền API developer — mọi REQ liên quan GW phải giữ degraded mode "manual" + backfill; tiến trình BV cần theo dõi song song | FIN, OPS, BOD | Đánh dấu tại /wf-design + theo dõi vận hành |

## Chi tiết

### DI-001: Nhóm số liệu chưa chốt (6 nhóm)
- **Loại:** data-gap (chính sách số chưa có quyết định của chủ dự án)
- **Mô tả:** Các con số trọng yếu của business rules đang dùng mức mặc định đề xuất bởi experts (đánh dấu `[CẦN CHỐT SỐ]`): ngưỡng duyệt chi 5/50/200 triệu VND; dung sai đối soát 0 / 0,5%·10USD / 1%·20USD; định mức giờ/tuần + cost-per-hour L1–L5; thang hoa hồng L1–L5 + quota coverage ≥3x; ngưỡng AML T1–T6 + UBO ≥25%; SLA creative/nghiệm thu.
- **Departments:** ALL
- **Đề xuất:** /wf-define-features Phase 0 trình stakeholder xác nhận từng nhóm trước khi fan-out features.
- **Tại sao defer:** Đây là quyết định kinh doanh (số tiền/ngưỡng SLA) — chỉ chủ dự án chốt được; experts đã đề xuất mặc định nên không chặn phân tích.

### DI-002: Mâu thuẫn 2 policy (tier proposal)
- **Loại:** policy-doc conflict
- **Mô tả:** `stage-gate-lifecycle-v6.md` §2.1 ghi B/C 8–12 trang/AM/≤2 vòng, D/E 15–25 trang/Planner/≤4 — đảo ngược so với `phan-loai-khach-hang-tier.md` §2.2.
- **Đề xuất:** Sửa stage-gate policy theo tier policy (nguồn sự thật đã chọn trong BR-OPS-6.3).
- **Tại sao defer:** Sửa policy library nằm ngoài phạm vi phase1-business docs của skill này.

### DI-003: Tiêu chí stage DEPLOY
- **Loại:** spec-gap
- **Mô tả:** Lifecycle gốc không định nghĩa chi tiêu done-criteria cho stage DEPLOY; đề xuất hiện tại là draft của marketing-expert.
- **Tại sao defer:** Cần context thiết kế feature (Phase 2) để chốt criteria machine-checkable.

### DI-004: Tên phần mềm kế toán + PMS cũ
- **Loại:** dependency (đầu vào từ user chưa có)
- **Tại sao defer:** Chỉ chủ dự án cung cấp được; đã là 2 điểm "cần làm rõ" từ P0-01 §3.2.

### DI-005: [CẦN CHỐT SỐ] riêng của OPS
- **Loại:** data-gap
- **Tại sao defer:** Như DI-001 — cần quyết định kinh doanh.

### DI-006: Role model bổ sung
- **Loại:** role-model
- **Mô tả:** OPS_CX (CX Head), FIN_COMPL (Compliance officer) + delegate duyệt timesheet cho TL cụ thể — đã ghi đề xuất AI-recommended trong stakeholder-review.md Phụ lục Phase 6d; registry sẽ thêm 2 vai này ở Phase 8 của run này.
- **Tại sao defer:** Cần chủ dự án xác nhận cơ cấu tổ chức thực tế có vị trí này hay kiêm nhiệm.
- **✅ RESOLVED 12/09/2026 — quyết định stakeholder: KHÔNG duyệt cả 2 vai.** Đã gỡ `OPS_CX`/`FIN_COMPL` khỏi registry (`SYS-BCERP-WEB.user_roles` 20→18) và mọi actors list. Trách nhiệm gán lại: CX Head → **OPS_PLAN**; Compliance → **FIN_L2** xử lý + **BOD** oversight độc lập. Đã cập nhật: policies (sla-khach-hang, client-portal-minh-bach-bao-mat, aml-kyc-giam-sat-giao-dich), P1-02, operations.md, finance.md. Chi tiết: stakeholder-review.md Phần F.3. Riêng delegate duyệt timesheet TL vẫn `[CẦN CHỐT SỐ]` (SO3-09 nhóm D).

### DI-007: Tiến trình Business Verification
- **Loại:** integration dependency
- **Tại sao defer:** Phụ thuộc hãng thứ 3 (Meta/Google/TikTok/...); thiết kế đã bao phủ degraded mode, chỉ cần theo dõi khi được cấp quyền.
