# TÀI LIỆU ĐÁNH GIÁ — ĐỐI CHIẾU NGUỒN & KHOẢN CẦN XÁC NHẬN

**Mã tài liệu:** `10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md`
**Phiên bản:** 1.0 — 12/09/2026
**Vai trò:** Tài liệu đánh giá của bộ tái dựng — ghi nhận chất lượng nguồn, mọi mâu thuẫn giữa các nguồn, mọi điểm chưa rõ, và danh sách câu hỏi cần chủ dự án/khách hàng BC Agency chốt trước khi bộ quy trình được coi là chính thức.

---

## 1. Kết luận đánh giá (TL;DR)

| Hạng mục | Kết quả |
|----------|---------|
| Độ phủ vòng đời | **Đủ** — từ RAW DATA đến CLOSED/RENEW, gồm cả ONGOING 3 nhánh. Gap GIAI ĐOẠN 3 (Deploy) của V6.0 đã được bù từ v2.3 |
| Trình tự & SLA | **Nhất quán trong v2.3** — đủ chi tiết cấu hình PMS (mỗi stage có 5W1H, IO, Done, SLA, Risk, Module) |
| Tính nhất quán giữa nguồn | **KHÔNG đạt** — tối thiểu 6 mâu thuẫn trọng yếu giữa v2.3 và V6.0 (mục 3), lớn nhất là mô hình tier |
| Độ tin cậy nội bộ v2.3 | Trung bình — có 1 mâu thuẫn trình tự nội bộ, 1 node trùng lặp, số liệu sidebar lệch, 4/6 Communication Rules chưa định nghĩa |
| Trạng thái bộ tái dựng | **Dùng được để vận hành tham chiếu** — nhưng **chưa đủ điều kiện làm quy định chính thức** cho đến khi 20 khoản `[KXN]` mục 4 được chốt |

## 2. Đánh giá từng nguồn

### 2.1 Lifecycle v2.3 (`BC_Agency_Project_Lifecycle (1).html`)

**Điểm mạnh:** nguồn đầy đủ nhất — 72 entry dữ liệu (33 stage + 39 sub-protocol ONGOING), mỗi entry chuẩn hóa 5W1H / Input-Output / Done criteria / SLA (trigger–hạn–gia hạn) / Risk & Escalation / module PMS / next steps. Phủ cả giai đoạn Deploy và vận hành chi tiết (ngưỡng tối ưu, checklist QC, công thức) — độ sẵn sàng cấu hình PMS cao.

**Điểm yếu phát hiện:**

| # | Vấn đề | Chi tiết | Đã xử lý trong bản tái dựng |
|---|--------|----------|------------------------------|
| 1 | Mâu thuẫn trình tự nội bộ | FIRST_MEETING khai Input "Tier classification từ LEAD score" nhưng stage LEAD diễn ra SAU First Meeting | Giữ trình tự v2.3, ghi `[KXN-2]` |
| 2 | Node trùng lặp | `internal_retro` và `og_internal_retro` là 2 bản của cùng Internal Retrospective | Gộp theo bản chi tiết, `[KXN-16]` |
| 3 | Số liệu sidebar lệch | Sidebar "30 Stages · 41 Roles" nhưng DATA có 72 entry; "41 Roles" không có danh sách chứng minh | Không dùng số liệu sidebar |
| 4 | 6 Communication Rules thiếu 4 | Chỉ Rule 4 (im lặng 24h) và Rule 6 (3 kênh) được định nghĩa | `[KXN-11]` |
| 5 | Tiêu chí không liệt kê | EVALUATION "5–7 tiêu chí"; 16 sections Strategic Brief; 9 sections Report — chỉ nêu số | `[KXN-6]`, `[KXN-7]` |
| 6 | Từ viết tắt không định nghĩa | BPVH, TMS, CMS, CS không có glossary | Đã lập bảng rút gọn ở README |
| 7 | Tên chức danh lẫn lộn | Media Buyer vs Media Executive/Senior; Creative Lead vs Lead Content | `[KXN-13]` |
| 8 | Điểm lỏng pháp lý | "HĐ có thể ký sau D+0" trong khi Negotiation done là "HĐ/LOI đã ký 2 bên" | `[KXN-5]` |
| 9 | PAUSED không có vị trí trên flow | Chỉ là banner — khó vẽ nhánh pause/resume | Mô tả thành quy trình ngang ở 01 §6 |
| 10 | Xen lẫn hiện tại/tương lai | CMS/TMS/AI Agent/Manus AI đánh dấu "tương lai" trộn với quy trình đang chạy | Tách bảng trạng thái ở 01 §5, `[KXN-9]` |
| 11 | Trùng lặp hằng số | Ngưỡng CTR<0.5%/500 impressions xuất hiện 3 chỗ (og_routine/og_threshold/og_campaign_lifecycle) — rủi ro lệch khi cập nhật | Tập trung 1 nơi ở phụ lục 09 §5 |
| 12 | Không có changelog | v2.3 không ghi v2.2 → v2.3 đổi gì | Nêu ở đây |

### 2.2 Lifecycle V6.0 (`01_Quy_trinh_MKT_Tong_the.md`)

**Điểm mạnh:** cơ chế sàng lọc Sales Phase chi tiết hơn v2.3 (Knockout K1–K12, trọng số CQ, Handoff Package 5 nhóm, Brand Safety 7 tiêu chí + Weighted Scoring ≥3.5 với trọng số cụ thể, định mức proposal theo tier) — những chi tiết này v2.3 không có.

**Điểm yếu:** file bị cắt cụt ngay tại header "GIAI ĐOẠN 3: DEPLOY PHASE" — toàn bộ nửa sau vòng đời (Deploy, ONGOING, Kết thúc) không có trong nguồn này. Đã được bù từ v2.3 nhưng cần xác nhận hướng chuẩn hóa `[KXN-10]`.

### 2.3 Cơ cấu tổ chức (`05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md`)

**Điểm mạnh:** nguồn chuẩn duy nhất về tổ chức — 17 mã vai có cấu trúc (BOD, HR, Finance, Sales L1–L5, Ops 6 mã), khung năng lực L1–L5, triết lý ERP 5 trụ (TÍN/TÂM/TRÍ/NHÂN/Dự án kép).

**Điểm yếu:** thiếu các vai xuất hiện dày đặc trong v2.3 — **Account Director, Creative Lead, CS**; không thể hiện quan hệ báo cáo giữa AD–AM–Planner. → `[KXN-12]`, `[KXN-13]`.

## 3. Mâu thuẫn giữa các nguồn (chi tiết)

### 3.1 `[KXN-1]` — Mô hình Tier (NGHIÊM TRỌNG NHẤT)
- v2.3: **4 tier A/B/C/D**, ngữ nghĩa A/B = giá trị cao (bắt buộc First Meeting, C/D được bypass).
- V6.0: **5 tier A–E**, ngữ nghĩa **ngược**: A = <1.5đ AUTO LOST (tệ nhất), E = ≥3.0 (tốt nhất, được bypass).
- Tác động dây chuyền: AUTO SCORING, điều kiện bypass, số vòng sửa proposal (≤2/≤4 gán nhầm tier), định mức soạn proposal (8–12 vs 15–25 trang), hoa hồng, SLA theo tier. **Cùng một nhãn "Tier B" mang 2 ý nghĩa trái chiều trong 2 nguồn — không thể cấu hình PMS cho đến khi chốt.**
- Liên quan trực tiếp **AUD-01 (High)** đang mở trong `.mc-data/work/audit-documents-alignment-20260912.md`: policy `phan-loai-khach-hang-tier.md` §2.2 (nguồn sự thật Phase 0) quy định định mức proposal **ngược** với V6.0 §GĐ2-3.

### 3.2 `[KXN-2]` — Thời điểm chấm điểm tier
- V6.0: AUTO SCORING chạy **trước** First Meeting (sau brief sơ bộ 3 trường).
- v2.3: LEAD scoring xảy ra **sau** First Meeting, nhưng FIRST_MEETING lại cần Input tier → tự mâu thuẫn.
- Đề xuất hợp nhất: scoring sơ bộ trước First Meeting (V6.0) + chấm lại `qualifiedTier` sau Full Brief (V6.0 Gate 1) — nhưng phải chờ `[KXN-1]` chốt mô hình tier trước.

### 3.3 `[KXN-3]` — Danh sách 8 mục Brief
Hai nguồn cùng nói "8 mục" nhưng nội dung khác 4/8 (chi tiết ở phụ lục 09 §3.1). Ảnh hưởng form Google Form và checklist gate BRIEF_RECEIVED.

### 3.4 `[KXN-4]` — Vị trí gate bàn giao Sales → BPVH
- v2.3: bàn giao tại **QUALIFIED** (LEAD chỉ là xác nhận cơ hội).
- V6.0: **LEAD = Decision Gate 2** với Handoff Package 5 nhóm checklist, SM ký → AM xác nhận 4h.
- Đề xuất: trình tự v2.3 + Handoff Package 5 nhóm của V6.0 làm checklist bắt buộc tại điểm bàn giao.

### 3.5 `[KXN-6]` — Tiêu chí Evaluation
- v2.3: "5–7 tiêu chí kỹ thuật" không liệt kê.
- V6.0: Brand Safety Hard Stop 7 tiêu chí + Weighted 9 tiêu chí pass ≥3.5.
- Bản tái dựng lấy V6.0 vì cụ thể hơn — cần xác nhận đây là bộ chính thức.

### 3.6 `[KXN-8]` — Định mức proposal theo tier (= AUD-01)
Xem §3.1 — đây là finding audit đang mở, **chưa được sửa ở bất kỳ phía nào** vì DI-002 defer; bộ tái dựng giữ nguyên trạng thái mâu thuẫn và trích dẫn cả hai.

## 4. Danh sách 20 khoản chờ xác nhận `[KXN]`

> Người chốt: chủ dự án / khách hàng BC Agency. Ưu tiên **P0** = chặn cấu hình PMS · **P1** = chặn vận hành chính thức · **P2** = hoàn thiện sau.

| Mã | P | Khoản | Nguồn cần hỏi | Tài liệu liên quan |
|----|---|-------|----------------|--------------------|
| KXN-1 | **P0** | Chốt mô hình tier: 4 (v2.3) hay 5 (V6.0)? Ngữ nghĩa chiều tier? | Chủ dự án | 01 §3, 09 §1 |
| KXN-2 | **P0** | Thời điểm AUTO SCORING: trước hay sau First Meeting? | Chủ dự án | 02 §2.2b |
| KXN-3 | P1 | Danh sách 8 mục Brief chuẩn (v2.3 hay V6.0 hay hợp nhất)? | Khách hàng | 02 §2.4 |
| KXN-4 | P1 | Gate bàn giao Sales→BPVH đặt tại QUALIFIED hay LEAD? | Chủ dự án | 02 §3 |
| KXN-5 | **P0** | HĐ/LOI: triển khai trước khi ký HĐ có được phép không? LOI có đủ điều kiện D+0? | Khách hàng + pháp lý | 04 §3 |
| KXN-6 | P1 | Bộ tiêu chí Evaluation chính thức (Brand Safety 7 + Weighted ≥3.5 của V6.0?) | Chủ dự án | 03 §2.1 |
| KXN-7 | P1 | Nội dung 16 sections Strategic Brief + 9 sections Report/Final Report | Khách hàng | 03 §2.2, 06 §2.3 |
| KXN-8 | **P0** | Định mức proposal theo tier (AUD-01 — policy Phase 0 ngược V6.0) | Chủ dự án | 03 §2.3 |
| KXN-9 | P2 | Phạm vi "tương lai" (CMS, TMS, AI Agent, Manus AI, auto-alert pixel) — thứ tự ưu tiên | Chủ dự án | 01 §5 |
| KXN-10 | **P0** | Xác nhận phần Deploy tái dựng từ v2.3 là quy định chính thức (bù gap V6.0 bị cắt cụt) | Khách hàng | 04 toàn bộ |
| KXN-11 | **P0** | Nội dung 4/6 Communication Rules còn thiếu (Rules 1, 2, 3, 5) | Khách hàng | 06 §7 (04), 09 §4 |
| KXN-12 | P1 | Vai Account Director: cấp bậc, mã vai, quan hệ báo cáo, phạm vi quyền | Chủ dự án | 07 §2 |
| KXN-13 | P1 | Creative Lead = Lead Content? CS thuộc phòng nào, xuất hiện ở đâu trong flow? | Chủ dự án | 07 §2, 05 §2 |
| KXN-14 | P1 | SM ánh xạ TPKD hay GDKD? (ảnh hưởng Gate 1, bypass, hoa hồng) | Chủ dự án | 07 §2 |
| KXN-15 | P2 | Hình thức gửi Client Survey mặc định (AM tay / CS / hệ thống tự gửi) | Chủ dự án | 06 §2.2 |
| KXN-16 | P2 | Dọn node trùng lặp `internal_retro` / `og_internal_retro` trong dữ liệu gốc v2.3 | Người giữ v2.3 | 06 §2.5 |
| KXN-17 | P1 | Định nghĩa chi tiết 4 nhóm LOST A/B/C/D | Khách hàng | 09 §8 |
| KXN-18 | P2 | Quy trình HR (tuyển, onboard, KPI 3 trụ cột) — chưa có tài liệu nguồn | Chủ dự án | 07 §3.3 |
| KXN-19 | P1 | Xác nhận Ma trận RACI (tổng hợp bởi bản tái dựng, không có nguồn gốc) | Chủ dự án | 08 §1 |
| KXN-20 | P2 | Danh sách đầy đủ cờ cảnh báo K6–K12 của AUTO SCORING | Chủ dự án | 09 §2.3 |

## 5. Đánh giá độ sẵn sàng theo mục đích sử dụng

| Mục đích | Sẵn sàng? | Điều kiện |
|----------|-----------|-----------|
| Hiểu quy trình end-to-end, onboard nhân sự mới | ✅ Ngay | — |
| Đào tạo vai trò theo bộ phận | ✅ Ngay | Kèm giải thích `[KXN]` cho các điểm tier/AD |
| Cấu hình PMS (stage, gate, field, SLA) | ⚠️ Một phần | Chờ P0: KXN-1, 2, 5, 8, 10, 11 |
| Làm nguồn cho Phase 2 BCERP (`/wf-define-features --resume`) | ⚠️ Một phần | Chờ P0 + cập nhật audit .mc-data (đã thực hiện, xem §6) |
| Thay thế chính thức tài liệu 01/05 cũ | ❌ Chưa | Sau khi 20 khoản KXN được chốt và bộ được khách hàng duyệt |

## 6. Liên kết với pipeline DEVKIT (.mc-data)

- Gap **AUD-02** (`documents/01` cắt cụt tại DEPLOY): bộ tái dựng này đã bù nội dung từ v2.3 — cập nhật trạng thái đã ghi vào `.mc-data/work/audit-documents-alignment-20260912.md`.
- Gap **AUD-03** (thiếu serie 02–04): vẫn còn mở — cần hỏi khách hàng; tuy nhiên vòng đời hiện đã phủ đủ nhờ v2.3 nên mức độ cấp thiết giảm.
- **AUD-01** (tier-policy conflict): tương ứng `[KXN-1]` + `[KXN-8]` ở đây — hai tài liệu cùng trỏ về một quyết định kinh doanh cần stakeholder chốt trước khi resume Phase 2.
- Bộ tài liệu này là **nguồn đầu vào đề xuất** cho việc nạp thêm REQ vào `req-registry.json` khi resume Phase 2 — đặc biệt các ONGOING sub-protocol (39 entry) và Deploy timeline chưa có trong registry hiện tại. Việc nạp REQ phải qua `/wf-add-scope` hoặc resume skill, không sửa registry thủ công.

## 7. Đề xuất bước tiếp theo

1. Trình mục 4 (bảng KXN) cho chủ dự án — ưu tiên 6 khoản **P0**.
2. Sau khi chốt KXN-1: yêu cầu khách hàng cung cấp cấu trúc 16 sections Strategic Brief, 9 sections Report, 6 Communication Rules đầy đủ, định nghĩa 4 nhóm LOST (KXN-7, 11, 17).
3. Cập nhật bộ tái dựng lên v1.1 với các quyết định đã chốt; lúc đó mới đánh dấu "Quy trình chính thức" và cho phép tài liệu 01/05 cũ chuyển trạng thái lưu trữ tham chiếu.
4. Khi khách hàng bổ sung serie 02–04 (nếu có): nạp bổ sung theo đúng phương pháp hợp nhất ở README §1, không đè các mục đã chốt.
