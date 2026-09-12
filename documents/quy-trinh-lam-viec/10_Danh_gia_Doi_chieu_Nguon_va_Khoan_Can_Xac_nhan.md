# TÀI LIỆU ĐÁNH GIÁ — ĐỐI CHIẾU NGUỒN & KHOẢN CẦN XÁC NHẬN

**Mã tài liệu:** `10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md`
**Phiên bản:** 1.1 — 12/09/2026 (chủ dự án chốt 11/20 khoản — nhật ký tại §8; audit độc lập thêm KXN-21/22)
**Vai trò:** Tài liệu đánh giá của bộ tái dựng — ghi nhận chất lượng nguồn, mọi mâu thuẫn giữa các nguồn, mọi điểm chưa rõ, và danh sách câu hỏi cần chủ dự án/khách hàng BC Agency chốt trước khi bộ quy trình được coi là chính thức.

---

## 1. Kết luận đánh giá (TL;DR)

| Hạng mục | Kết quả |
|----------|---------|
| Độ phủ vòng đời | **Đủ** — từ RAW DATA đến CLOSED/RENEW, gồm cả ONGOING 3 nhánh. Gap GIAI ĐOẠN 3 (Deploy) của V6.0 đã được bù từ v2.3 |
| Trình tự & SLA | **Nhất quán trong v2.3** — đủ chi tiết cấu hình PMS (mỗi stage có 5W1H, IO, Done, SLA, Risk, Module) |
| Tính nhất quán giữa nguồn | **ĐÃ GIẢI QUYẾT phần trọng yếu** — 11/22 khoản đã chốt (12/09), lớn nhất là mô hình tier (KXN-1) và định mức proposal (KXN-8 = AUD-01) |
| Độ tin cậy nội bộ v2.3 | Trung bình — có 1 mâu thuẫn trình tự nội bộ (đã giải bằng KXN-2), 1 node trùng lặp, số liệu sidebar lệch, 4/6 Communication Rules có bản dự thảo nội bộ chờ khách hàng duyệt |
| Trạng thái bộ tái dựng (v1.1) | **Dùng được để vận hành tham chiếu + đã chốt đủ cấu hình PMS phần Sales/Proposal/Deploy** — 11 khoản còn mở (6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22) không chặn cấu hình PMS cốt lõi; đổi thành "Quy trình chính thức" khi khách hàng duyệt toàn bộ |

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

> **✅ ĐÃ CHỐT (12/09, KXN-1):** mô hình **5 tier A–E theo V6.0** — chọn vì chỉ V6.0 có cơ chế CQ đầy đủ để auto xếp tier và pipeline Phase 0-1 đã viết theo A–E. Policy Phase 0 đã hiệu chỉnh cùng chiều (DI-002 resolved).

### 3.2 `[KXN-2]` — Thời điểm chấm điểm tier
- V6.0: AUTO SCORING chạy **trước** First Meeting (sau brief sơ bộ 3 trường).
- v2.3: LEAD scoring xảy ra **sau** First Meeting, nhưng FIRST_MEETING lại cần Input tier → tự mâu thuẫn.
- Đề xuất hợp nhất: scoring sơ bộ trước First Meeting (V6.0) + chấm lại `qualifiedTier` sau Full Brief (V6.0 Gate 1) — nhưng phải chờ `[KXN-1]` chốt mô hình tier trước.

> **✅ ĐÃ CHỐT (12/09, KXN-2):** chốt đúng theo đề xuất hợp nhất — AUTO SCORING chạy sau brief sơ bộ 3 trường (trước First Meeting); chấm lại `qualifiedTier` sau Full Brief.

### 3.3 `[KXN-3]` — Danh sách 8 mục Brief
Hai nguồn cùng nói "8 mục" nhưng nội dung khác 4/8 (chi tiết ở phụ lục 09 §3.1). Ảnh hưởng form Google Form và checklist gate BRIEF_RECEIVED.

> **✅ ĐÃ CHỐT (12/09, KXN-3):** mô hình 2 cấp form (sơ bộ 3 trường + Full Brief 8 sections V6.0; 8 mục v2.3 = checklist tối thiểu).

### 3.4 `[KXN-4]` — Vị trí gate bàn giao Sales → BPVH
- v2.3: bàn giao tại **QUALIFIED** (LEAD chỉ là xác nhận cơ hội).
- V6.0: **LEAD = Decision Gate 2** với Handoff Package 5 nhóm checklist, SM ký → AM xác nhận 4h.
- Đề xuất: trình tự v2.3 + Handoff Package 5 nhóm của V6.0 làm checklist bắt buộc tại điểm bàn giao.

> **✅ ĐÃ CHỐT (12/09, KXN-4):** đúng theo đề xuất — bàn giao tại QUALIFIED, Handoff Package 5 nhóm là checklist bắt buộc.

### 3.5 `[KXN-6]` — Tiêu chí Evaluation
- v2.3: "5–7 tiêu chí kỹ thuật" không liệt kê.
- V6.0: Brand Safety Hard Stop 7 tiêu chí + Weighted 9 tiêu chí pass ≥3.5.
- Bản tái dựng lấy V6.0 vì cụ thể hơn — cần xác nhận đây là bộ chính thức.

### 3.6 `[KXN-8]` — Định mức proposal theo tier (= AUD-01)
Xem §3.1 — đây là finding audit đang mở, **chưa được sửa ở bất kỳ phía nào** vì DI-002 defer; bộ tái dựng giữ nguyên trạng thái mâu thuẫn và trích dẫn cả hai.

> **✅ ĐÃ CHỐT (12/09, KXN-8 = AUD-01 = DI-002):** định mức theo chiều **V6.0** (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng). Policy `phan-loai-khach-hang-tier.md` §2.2 đã hiệu chỉnh cùng chiều (bản 1.1); BR-OPS-6.3/6.4 trong `operations.md` đã đồng bộ.

## 4. Danh sách khoản chờ xác nhận `[KXN]` — cập nhật v1.1 (12/09)

> Người chốt: chủ dự án / khách hàng BC Agency. Ưu tiên **P0** = chặn cấu hình PMS · **P1** = chặn vận hành chính thức · **P2** = hoàn thiện sau. **11/22 khoản đã chốt ngày 12/09/2026** (nhật ký §8); còn mở: 6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22.

| Mã | P | Khoản | Trạng thái / Quyết định | Tài liệu liên quan |
|----|---|-------|-------------------------|--------------------|
| KXN-1 | **P0** | Chốt mô hình tier: 4 (v2.3) hay 5 (V6.0)? | ✅ **CHỐT: 5 tier A–E (V6.0)** | 01 §3, 09 §1 |
| KXN-2 | **P0** | Thời điểm AUTO SCORING: trước hay sau First Meeting? | ✅ **CHỐT: trước First Meeting** (sau brief 3 trường) + chấm lại qualifiedTier | 02 §2.2b |
| KXN-3 | P1 | Danh sách 8 mục Brief chuẩn | ✅ **CHỐT: 2 cấp form** (sơ bộ 3 trường + Full Brief V6.0; v2.3 = checklist tối thiểu) | 02 §2.4, 09 §3.1 |
| KXN-4 | P1 | Gate bàn giao Sales→BPVH đặt tại QUALIFIED hay LEAD? | ✅ **CHỐT: QUALIFIED** + Handoff Package 5 nhóm bắt buộc | 02 §3 |
| KXN-5 | **P0** | HĐ/LOI: triển khai trước khi ký HĐ? LOI có đủ điều kiện D+0? | ✅ **CHỐT: D+0 cần tiền vào + LOI hoặc HĐ đã ký; HĐ đầy đủ ≤7 ngày sau D+0** | 04 §3 |
| KXN-6 | P1 | Bộ tiêu chí Evaluation chính thức (Brand Safety 7 + Weighted ≥3.5 của V6.0?) | 🔓 Còn mở — chờ xác nhận | 03 §2.1 |
| KXN-7 | P1 | Nội dung 16 sections Strategic Brief + 9 sections Report/Final Report | 🔓 Còn mở — chờ khách hàng | 03 §2.2, 06 §2.3 |
| KXN-8 | **P0** | Định mức proposal theo tier (AUD-01) | ✅ **CHỐT: theo V6.0** — B/C AM 8–12 trang ≤2 vòng; D/E Planner 15–25 ≤4 vòng; policy Phase 0 đã sửa cùng chiều | 03 §2.3 |
| KXN-9 | P2 | Phạm vi "tương lai" (CMS, TMS, AI Agent…) | 🔓 Còn mở | 01 §5 |
| KXN-10 | **P0** | Xác nhận Deploy tái dựng từ v2.3 là quy định chính thức | ✅ **CHỐT: phê chuẩn** (DI-003 đã đóng) | 04 toàn bộ |
| KXN-11 | **P0** | Nội dung 4/6 Communication Rules còn thiếu | ✅ **CHỐT (mức nội bộ):** 4 rule dự thảo được duyệt (09 §4); thay bằng rule chính thức khi khách hàng cung cấp | 09 §4 |
| KXN-12 | P1 | Vai Account Director | ✅ **CHỐT: mã vai mới `OPS_AD`** — chờ đồng bộ documents/05; câu hỏi phụ "Quản lý GM (V6.0) = AD hay BOD/CFO?" còn mở | 07 §2, §5 |
| KXN-13 | P1 | Creative Lead = Lead Content? CS thuộc đâu? | ✅ **CHỐT: Creative Lead = Lead Content; bỏ vai CS** (AM gửi survey) | 07 §2 |
| KXN-14 | P1 | SM ánh xạ TPKD hay GDKD? | ✅ **CHỐT: SM = SALES_L4 TPKD** | 07 §2 |
| KXN-15 | P2 | Hình thức gửi Client Survey mặc định | 🔓 Còn mở (CS đã bỏ — còn AM tay / hệ thống) | 06 §2.2 |
| KXN-16 | P2 | Dọn node trùng lặp `internal_retro`/`og_internal_retro` trong dữ liệu gốc v2.3 | 🔓 Còn mở | 06 §2.5 |
| KXN-17 | P1 | Định nghĩa chi tiết 4 nhóm LOST A/B/C/D | 🔓 Còn mở — chờ khách hàng (liên quan KXN-21) | 09 §8 |
| KXN-18 | P2 | Quy trình HR | 🔓 Còn mở | 07 §3.3 |
| KXN-19 | P1 | Xác nhận Ma trận RACI | 🔓 Còn mở | 08 §1 |
| KXN-20 | P2 | Danh sách đầy đủ cờ cảnh báo K6–K12 | 🔓 Còn mở | 09 §2.3 |
| KXN-21 | P1 | Danh sách "4 lý do LOST" tại Pitching/Negotiation — không có nguồn (audit độc lập IND-04) | 🔓 Mới thêm 12/09 — dùng làm enum đề xuất, chờ khách hàng xác nhận | 03 §2.7/§2.9, 06 §6 |
| KXN-22 | P1 | Mốc "15 ngày → PAUSE" non-payment — không có trong v2.3 (audit IND-05) | 🔓 Mới thêm 12/09 — đề xuất giữ 2 bậc 15/30 ngày, chờ khách hàng xác nhận | 06 §7, 08 §3.5, 09 §9 |

## 5. Đánh giá độ sẵn sàng theo mục đích sử dụng

| Mục đích | Sẵn sàng? | Điều kiện |
|----------|-----------|-----------|
| Hiểu quy trình end-to-end, onboard nhân sự mới | ✅ Ngay | — |
| Đào tạo vai trò theo bộ phận | ✅ Ngay | Kèm giải thích các khoản còn mở |
| Cấu hình PMS (stage, gate, field, SLA) | ✅ **Đủ cho phần lõi** (từ 12/09: 6/6 KXN P0 đã chốt) | Các khoản còn mở không chặn lõi; bổ sung khi chốt |
| Làm nguồn cho Phase 2 BCERP (`/wf-define-features --resume`) | ✅ Sẵn sàng | DI-008 đã giải quyết (Xem §8); chỉ còn câu hỏi tên phần mềm kế toán (DI-004) |
| Thay thế chính thức tài liệu 01/05 cũ | ❌ Chưa | Sau khi 11 khoản còn mở được chốt và bộ được khách hàng duyệt |

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

---

## 8. Nhật ký quyết định 12/09/2026 (phiên audit độc lập + duyệt đề xuất)

> Bối cảnh: sau audit độc lập (`.mc-data/work/audit-independent-20260912.md` — PASS 4/4 phần) và bảng đề xuất phương án, **chủ dự án duyệt áp dụng toàn bộ đề xuất**. 11/20 khoản chốt trong phiên này:

| Khoản | Quyết định | Căn cứ chọn |
|-------|------------|-------------|
| KXN-1 | **5 tier A–E (V6.0)** — A<1.5 AUTO LOST → E≥3.5 bypass/ưu tiên | Chỉ V6.0 có CQ weighted scoring hoàn chỉnh để auto xếp tier; pipeline Phase 0-1 đã viết theo A–E (không phải rà lại REQ/policy) |
| KXN-2 | **AUTO SCORING trước First Meeting** (sau brief 3 trường) + chấm lại `qualifiedTier` sau Full Brief | Giải mâu thuẫn nội bộ v2.3 (FIRST_MEETING cần tier từ LEAD); V6.0 có sẵn cơ chế 2 lần chấm |
| KXN-3 | **2 cấp form**: sơ bộ 3 trường + Full Brief 8 sections (V6.0); 8 mục v2.3 = checklist tối thiểu | Gộp được thế mạnh cả 2 nguồn, không mất nội dung |
| KXN-4 | **Bàn giao tại QUALIFIED** + Handoff Package 5 nhóm (V6.0) làm checklist bắt buộc | Trình tự v2.3 + kỷ luật bàn giao V6.0 — đúng đề xuất gốc 02 §3 |
| KXN-5 | **D+0 = tiền vào TK + LOI hoặc HĐ đã ký**; HĐ đầy đủ ≤7 ngày sau D+0; cảnh báo ngày 3 giữ nguyên | Cân bằng dòng tiền (v2.3) và rào pháp lý tối thiểu |
| KXN-8 | **Định mức theo V6.0**: B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng | Khách điểm cao nhất phải được đầu tư proposal lớn nhất; policy `phan-loai-khach-hang-tier.md` §2.2 đã hiệu chỉnh cùng chiều → **DI-002/AUD-01 RESOLVED** |
| KXN-10 | **Phê chuẩn Deploy v2.3 làm quy định chính thức** | v2.3 là nguồn duy nhất có chi tiết; audit verify 6/6 mẫu khớp nguyên văn → **DI-003 RESOLVED**; done-criteria DEPLOY đã cập nhật vào stage-gate policy v1.2 |
| KXN-11 | **4 Rules (1/2/3/5) duyệt theo bản dự thảo nội bộ** (09 §4) — thay bằng rule chính thức khi khách hàng cung cấp | Dựng từ chính nguyên tắc có nguồn trong bộ gốc (đầu mối AM, lưu vết, budget riêng biệt, reporting frequency) |
| KXN-12 | **Bổ sung mã vai `OPS_AD`** cho Account Director (RBAC tường minh); câu hỏi phụ "Quản lý GM (V6.0) = ai?" vẫn mở | Tách quyền duyệt giá/margin khỏi Planner (v2.3 xử lý 2 vai tách bạch trong backup chain); chờ đồng bộ documents/05 |
| KXN-13 | **Creative Lead = Lead Content; bỏ vai CS** (AM gửi survey) | CS chỉ xuất hiện 1 lần trong nguồn; gộp tránh nhân bản vai |
| KXN-14 | **SM = SALES_L4 TPKD** | GDKD là vị trí quy hoạch |

**Kèm theo (cùng phiên):** thêm KXN-21 (4 lý do LOST — audit IND-04) và KXN-22 (mốc 15 ngày PAUSE — audit IND-05) ở mức "đề xuất chờ khách hàng xác nhận"; sửa 3 lỗi cross-ref (IND-01/02/03) và bổ sung mục UPSELL 06 §8 từ entry `upsell` v2.3 (IND-03); sửa tag nguồn TNKD (IND-07).

**Còn mở (không chặn Phase 2):** KXN-6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22 — phần lớn cần khách hàng cung cấp nội dung (16 sections, 9 sections, nhóm LOST, K6–K12, RACI confirm).
