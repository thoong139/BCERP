# Deferred Issues từ /wf-analyze-requirements

> Nguồn: phase1-business/stakeholder-review.md — DEFER-TO-PHASE items
> Ngày tạo: 2026-09-12 · Cập nhật: 2026-09-12 (phiên rà soát quy-trinh-lam-viec) · **Cập nhật 2026-09-12 (phiên audit độc lập + duyệt đề xuất): DI-001/002/003/005/008 ĐÃ GIẢI QUYẾT — chỉ còn DI-004 chờ 1 fact từ user (tên phần mềm kế toán VAS)**
> Consumer: /wf-define-features Phase 0 (context), /wf-design Phase 0 (context)
> LƯU Ý: Không có items KHẨN CẤP — SO2-01 (Critical) đã được resolve ngay trong run này bằng Phase 8 registry update (xem stakeholder-review.md Phần E, DR-001)

## Tóm Tắt

| Mức độ | Số lượng | Trạng thái |
|--------|----------|------------|
| TRUNG BÌNH | 6 | 5 đã giải quyết 12/09 (DI-001 ✅, DI-002 ✅, DI-003 ✅, DI-005 ✅, DI-008 ✅); DI-004 còn chờ tên VAS từ user |
| NHỎ | 2 | DI-006 ✅ resolved (12/09); DI-007 theo dõi vận hành (không chặn) |

## Danh sách Issues

| # | Issue ID | Loại | Severity | Mô tả | Departments liên quan | Phase xử lý |
|---|---------|------|----------|--------|----------------------|-------------|
| 1 | DI-001 | data-gap | Medium | 6 nhóm [CẦN CHỐT SỐ] gom theo SO3-09: ngưỡng giải ngân 5/50/200tr, dung sai đối soát, định mức giờ/cost-per-hour L1–L5, ma trận SLA creative/rounds, thang hoa hồng + quota L1–L5, ngưỡng AML T1–T6 + UBO 25% | ALL | ✅ **Resolved 12/09 (phiên duyệt đề xuất): chủ dự án chốt nguyên bản mức mặc định do experts đề xuất** (chi tiết trong policies tương ứng) |
| 2 | DI-002 | policy-doc | Medium | stage-gate-lifecycle-v6.md §2.1 mâu thuẫn phan-loai-khach-hang-tier.md §2.2 về số trang/người soạn proposal theo tier (B/C vs D/E bị đảo) — đã dùng tier policy làm nguồn sự thật trong BR-OPS-6.3; cần hiệu chỉnh bản policy stage-gate. Ghi chú 12/09: = AUD-01 = `[KXN-8]`, mở rộng bởi `[KXN-1]` | OPS, SALES | ✅ **Resolved 12/09: chốt theo hướng V6.0** (KXN-8) — đã hiệu chỉnh `phan-loai-khach-hang-tier.md` §2.2 (bản 1.1) + đồng bộ BR-OPS-6.3/6.4 trong operations.md. Xem stakeholder-review F.5 |
| 3 | DI-003 | spec-gap | Medium | Tiêu chí stage DEPLOY trong Lifecycle V6.0 chưa hoàn thiện (Lifecycle gốc không có chi tiết — đề xuất tại BR-OPS-6.x cần xác nhận). Ghi chú 12/09: nguồn Deploy đã có từ Lifecycle v2.3 (tái dựng tại `documents/quy-trinh-lam-viec/04`) — chờ `[KXN-10]` xác nhận chính thức rồi mới đóng | OPS | ✅ **Resolved 12/09: KXN-10 phê chuẩn Deploy v2.3 làm chính thức** — done-criteria đã cập nhật vào `stage-gate-lifecycle-v6.md` bảng 2.1 (bản 1.2). SO3-04 đóng kèm |
| 4 | DI-004 | dependency | Medium | Tên phần mềm kế toán VAS hiện hữu chưa xác định (connector đối chiếu sổ) + PMS cũ trong quy trình V6.0 (thay thế hoàn toàn hay migration) — 2 điểm P0 đã flag, cần chủ dự án cung cấp | FIN, SALES | 🔄 **Nửa giải quyết 12/09: PMS cũ chốt hướng C (migrate chọn lọc: master data + dự án active + payment history 12 tháng; legacy read-only). Còn duy nhất: tên phần mềm kế toán VAS — hỏi user tại Phase 0 phiên resume** |
| 5 | DI-005 | data-gap | Medium | 6 [CẦN CHỐT SỐ] còn lại trong operations.md: hạn mức VND/ngày theo cấp buyer, ca trực Critical 24/7, sample size A/B, số ngày chờ confirm nghiệm thu, SLA từng bước duyệt creative, vòng sửa creative | OPS | ✅ **Resolved 12/09:** 3 mục có câu trả lời từ nguồn v2.3 (sample size A/B ≥50 clicks/≥10 conversions chênh ≥20%; SLA duyệt creative 2h/4h video/1h trend; vòng sửa creative tối đa 3 vòng) + 3 mục chốt theo đề xuất (hạn mức buyer theo % ngân sách tháng 20/50/100% theo cấp — số cụ thể FIN chốt; ca trực on-call SLA 4h ngoài giờ; nghiệm thu 3 ngày + nhắc ngày 2 + escalate AD ngày 4, không áp im lặng = đồng ý) |
| 6 | DI-006 | role-model | Small | Vai mới OPS_CX, FIN_COMPL + quy ước delegate duyệt timesheet (đề xuất trong stakeholder-review.md Phụ lục Phase 6d) cần thêm vào registry + xác nhận tổ chức thực tế | OPS, FIN | ✅ **Resolved 12/09/2026** — user TỪ CHỐI 2 vai; trách nhiệm gán lại OPS_PLAN / FIN_L2+BOD (stakeholder-review.md Phần F.3) |
| 7 | DI-007 | integration | Small | Business Verification 7 nền tảng QC chưa có quyền API developer — mọi REQ liên quan GW phải giữ degraded mode "manual" + backfill; tiến trình BV cần theo dõi song song | FIN, OPS, BOD | 🔄 Theo dõi vận hành (không chặn Phase 2 — degraded mode đã nằm trong spec) |
| 8 | DI-008 | business-decision | Medium | 6 khoản `[KXN]` P0 từ bộ tài liệu gốc `documents/quy-trinh-lam-viec/` (file 10 §4) cần chủ dự án/khách hàng chốt trước khi resume Phase 2 scope-mapping: KXN-1, 2, 5, 8, 10, 11 | ALL | ✅ **Resolved 12/09 (phiên duyệt đề xuất): cả 6 khoản P0 đã chốt** — KXN-1: 5 tier A–E; KXN-2: scoring trước First Meeting; KXN-5: D+0 cần LOI/HĐ; KXN-8: theo V6.0; KXN-10: Deploy phê chuẩn; KXN-11: 4 Rules dự thảo duyệt nội bộ. Kèm 5 khoản P1 khác (3, 4, 12, 13, 14). Nhật ký: `documents/quy-trinh-lam-viec/10 §8` + stakeholder-review F.5 |

## Chi tiết

### DI-001: Nhóm số liệu chưa chốt (6 nhóm)
- **✅ RESOLVED 12/09/2026 (phiên duyệt đề xuất):** chủ dự án chốt nguyên bản các mức mặc định do experts đề xuất trong policies — không cần trình lại tại Phase 0.
- **Loại:** data-gap (chính sách số chưa có quyết định của chủ dự án)
- **Mô tả:** Các con số trọng yếu của business rules đang dùng mức mặc định đề xuất bởi experts (đánh dấu `[CẦN CHỐT SỐ]`): ngưỡng duyệt chi 5/50/200 triệu VND; dung sai đối soát 0 / 0,5%·10USD / 1%·20USD; định mức giờ/tuần + cost-per-hour L1–L5; thang hoa hồng L1–L5 + quota coverage ≥3x; ngưỡng AML T1–T6 + UBO ≥25%; SLA creative/nghiệm thu.
- **Departments:** ALL
- **Đề xuất:** /wf-define-features Phase 0 trình stakeholder xác nhận từng nhóm trước khi fan-out features.
- **Tại sao defer:** Đây là quyết định kinh doanh (số tiền/ngưỡng SLA) — chỉ chủ dự án chốt được; experts đã đề xuất mặc định nên không chặn phân tích.

### DI-002: Mâu thuẫn 2 policy (tier proposal)
- **✅ RESOLVED 12/09/2026 (KXN-1 + KXN-8):** chủ dự án chốt mô hình 5 tier A–E và định mức theo chiều **V6.0** (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng). Đã hiệu chỉnh `phan-loai-khach-hang-tier.md` §2.2 (bản 1.1) và đồng bộ BR-OPS-6.3/6.4 trong `operations.md`. Hướng sửa ĐẢO so với kế hoạch gốc (sửa stage-gate) vì audit độc lập xác nhận V6.0 là tài liệu gốc của khách hàng — xem `documents/quy-trinh-lam-viec/10 §3.6 + §8`.
- **Loại:** policy-doc conflict
- **Mô tả:** `stage-gate-lifecycle-v6.md` §2.1 ghi B/C 8–12 trang/AM/≤2 vòng, D/E 15–25 trang/Planner/≤4 — đảo ngược so với `phan-loai-khach-hang-tier.md` §2.2.
- **Đề xuất:** Sửa stage-gate policy theo tier policy (nguồn sự thật đã chọn trong BR-OPS-6.3).
- **Tại sao defer:** Sửa policy library nằm ngoài phạm vi phase1-business docs của skill này.

### DI-003: Tiêu chí stage DEPLOY
- **✅ RESOLVED 12/09/2026 (KXN-10):** chủ dự án phê chuẩn Deploy tái dựng từ Lifecycle v2.3 làm quy định chính thức. Done-criteria (D+0 cần LOI/HĐ; checklist tài nguyên D+4; Planning TT→ĐH→AD trong ngày D+0; 6 Rules ký tại D+3; ONGOING D+5) đã cập nhật vào `stage-gate-lifecycle-v6.md` bảng 2.1 (bản 1.2). SO3-04 đóng kèm.
- **Loại:** spec-gap
- **Mô tả:** Lifecycle gốc không định nghĩa chi tiêu done-criteria cho stage DEPLOY; đề xuất hiện tại là draft của marketing-expert.
- **Tại sao defer:** Cần context thiết kế feature (Phase 2) để chốt criteria machine-checkable.

### DI-004: Tên phần mềm kế toán + PMS cũ
- **✅ RESOLVED 12/09/2026 (phiên resume /wf-define-features):** chủ dự án KHÔNG chốt tên vendor cụ thể — thay vào đó định hướng thiết kế: **"Cần có module cấu hình trong Settings để quản lý kết nối ngoại vi"**. Hệ quả thiết kế: (1) REQ-FIN-013 spec connector đối chiếu sổ theo hướng **vendor-agnostic** — connection profile + field mapping + import/export template + API adapter cắm được, cấu hình toàn bộ tại **MOD-SETTINGS-GW** (không hardcode vendor); (2) MOD-SETTINGS-GW bổ sung phạm vi "quản lý kết nối ngoại vi" (external connections management) vào brief feature; (3) ghi chú trong spec: tên phần mềm kế toán cụ thể sẽ được cấu hình khi triển khai, không chặn thiết kế.
- **Loại:** dependency (đầu vào từ user chưa có)
- **Tại sao defer:** Chỉ chủ dự án cung cấp được; đã là 2 điểm "cần làm rõ" từ P0-01 §3.2.

### DI-005: [CẦN CHỐT SỐ] riêng của OPS
- **✅ RESOLVED 12/09/2026:** (1) sample size A/B — **từ nguồn v2.3**: winner chênh ≥20% + ≥50 clicks hoặc ≥10 conversions; (2) SLA duyệt creative — **từ nguồn v2.3**: AM 2h (video dài 4h, trend gấp 1h), content self-QC + Lead review 4h; (3) vòng sửa creative — **từ nguồn v2.3**: tối đa 3 vòng nội bộ, vòng 4 escalate AM; (4) hạn mức VND/ngày theo cấp buyer — **chốt theo đề xuất**: khung % ngân sách tháng 20/50/100% theo cấp (Junior/Senior/Lead), số cụ thể FIN chốt khi cấu hình; (5) ca trực Critical — **chốt theo đề xuất**: on-call xoay vòng SLA 4h ngoài giờ (thay desk 24/7); (6) nghiệm thu — **chốt theo đề xuất**: 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4; KHÔNG áp "im lặng = đồng ý".
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

### DI-008: 6 khoản KXN P0 từ bộ tài liệu gốc `documents/quy-trinh-lam-viec/`
- **✅ RESOLVED 12/09/2026 (phiên audit độc lập + duyệt đề xuất):** chủ dự án chốt **cả 6 khoản P0** và kèm 5 khoản P1 (KXN-3, 4, 12, 13, 14) — tổng 11/22 khoản. Bộ gốc đã lên **v1.1** với nhật ký quyết định tại `documents/quy-trinh-lam-viec/10_..._Khoan_Can_Xac_nhan.md` §8. Audit độc lập xác nhận PASS 4/4 phần trước khi chốt (`.mc-data/work/audit-independent-20260912.md`). 11 khoản còn mở (6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22) **không chặn Phase 2** — theo dõi tại file 10 §4.
- **Loại:** business-decision (quyết định kinh doanh từ nguồn mới 12/09/2026)
- **Bối cảnh:** Bộ tài liệu quy trình chính thức tái dựng (11 file) từ Project Lifecycle v2.3 + V6.0 + cơ cấu tổ chức đã hoàn thành tại `documents/quy-trinh-lam-viec/`. Tài liệu đánh giá (file 10) liệt kê 20 khoản chờ xác nhận `[KXN]`, trong đó 6 khoản P0 chặn cấu hình PMS và spec feature.
- **Danh sách P0:**
  1. `[KXN-1]` Mô hình tier: 4 tier A/B/C/D (v2.3, A/B = giá trị cao) hay 5 tier A–E (V6.0, A = tệ nhất)? — ảnh hưởng dây chuyền AUTO SCORING, bypass, vòng sửa proposal, hoa hồng, SLA; mọi REQ/policy viết theo Tier A–E cần rà lại sau khi chốt.
  2. `[KXN-2]` Thời điểm AUTO SCORING: trước First Meeting (V6.0) hay sau (v2.3)?
  3. `[KXN-5]` HĐ/LOI: có được triển khai trước khi ký HĐ? LOI có đủ điều kiện kích hoạt D+0?
  4. `[KXN-8]` Định mức proposal theo tier — trùng AUD-01/DI-002, không thực thi DI-002 cho đến khi chốt.
  5. `[KXN-10]` Xác nhận phần Deploy tái dựng từ v2.3 là quy định chính thức (bù gap V6.0 bị cắt cụt) — điều kiện đóng DI-003/SO3-04.
  6. `[KXN-11]` Nội dung 4/6 Communication Rules còn thiếu (Rules 1, 2, 3, 5) — chặn form ký tại Kick-off D+3.
- **Đề xuất:** Trình cùng DI-001/DI-004/DI-005 tại /wf-define-features Phase 0; nạp REQ mới (39 ONGOING sub-protocol + Deploy timeline) qua `/wf-add-scope` hoặc resume skill — **không sửa registry thủ công**.
- **Tại sao defer:** Quyết định kinh doanh thuộc chủ dự án/khách hàng; bộ tái dựng đã tài liệu hóa đủ căn cứ 2 chiều để ra quyết định.
- **Nguồn tham chiếu:** `documents/quy-trinh-lam-viec/10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md` §4 · stakeholder-review.md Phần F.4 · audit-documents-alignment-20260912.md §7.
