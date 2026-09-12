# MA TRẬN RACI · ĐIỂM GATE PHÊ DUYỆT · BẢNG SLA TỔNG HỢP

**Mã tài liệu:** `08_Ma_tran_RACI_Gate_SLA.md`
**Phiên bản:** 1.1 — 12/09/2026 (tier theo A–E đã chốt; non-payment gắn [KXN-22])
**Ghi chú:** Lifecycle v2.3 **không có bảng RACI chính thức** — vai trò gắn rải rác trong từng node. Ma trận dưới đây do bản tái dựng tổng hợp từ trường "Phụ trách" của 72 entry + chi tiết V6.0; cần chủ dự án xác nhận `[KXN-19]` trước khi cấu hình Approval Module.

**Chú giải RACI:** **R** = Realize — người thực hiện chính · **A** = Accountable — chịu trách nhiệm cuối/phê duyệt (mỗi hàng chỉ 1 A) · **C** = Consulted — được tham vấn · **I** = Informed — được thông báo.

---

## 1. Ma trận RACI theo stage chính

| Stage | SE | SM | AM | Planner | AD | Content/Design/Video | Media | Accountant | KH |
|-------|----|----|----|---------|----|----------------------|-------|------------|----|
| RAW DATA | R/A | I | — | — | — | — | — | — | I |
| BRIEF SENT | R/A | I | — | — | — | — | — | — | R |
| FIRST MEETING | R/A | C | — | — | — | — | — | — | R |
| BYPASS First Meeting | R (đề xuất) | **A** | — | — | — | — | — | — | I |
| BRIEF RECEIVED | R/A | I | I | — | — | — | — | — | R |
| LEAD (scoring, tier) | R/A | C | I | — | — | — | — | — | — |
| QUALIFIED (Gate 1) | R | **A** (ký duyệt) | I | — | — | — | — | — | I |
| Bàn giao Sales → BPVH | R | A | **R xác nhận tiếp nhận** (4h) | I | I | — | — | — | I |
| EVALUATION | I | — | R/**A** | R (hỗ trợ) | C | — | — | — | — |
| SECOND MEETING | I | — | R/**A** | R | C | — | — | — | R |
| PROPOSAL v0.x | — | — | R/**A** | C (duyệt strategy) | A giá sơ bộ | C (feasibility) | — | — | — |
| REHEARSAL | I | — | R | R | **A** (giá cuối) | C | — | — | — |
| PROPOSAL v1.0 gửi KH | — | — | R/**A** | I | I | — | — | — | I |
| PROPOSAL REVIEW | — | C | R/**A** | C | A (vượt giới hạn) | — | — | — | R (feedback) |
| PITCHING | I | — | R/**A** | C | C | C | — | — | A (quyết định chọn) |
| QUOTATION | — | — | R (scope) | — | **A** (duyệt margin) | — | — | R (tính giá) | I |
| NEGOTIATION | — | R (support) | R/**A** (dẫn đầu) | — | C | — | — | C | R |
| WON | I | A (xác nhận) | R | I | I | I | I | I | I |
| COLLECTING | R (hỗ trợ) | — | R/**A** | — | — | — | C | — | R (cấp quyền) |
| WAIT PAYMENT / D+0 | — | — | I (nhận confirm) | — | — | — | — | **R/A** | R (chuyển khoản) |
| PLANNING DRAFT | — | — | R/**A** | R (review) | — | — | — | — | — |
| KICK-OFF nội bộ ×2 | — | — | R/**A** | R | I | R | R | — | — |
| KICK-OFF KH (D+3) | I | — | R/**A** | R | C | R | R | — | A (ký Rules) |
| ONGOING — EXECUTING | — | — | **A** (duyệt content) | C | — | R | R | — | I |
| ONGOING — OPTIMIZING Routine | — | — | I (daily summary) | — | — | R | R/**A** (trong ngưỡng) | — | — |
| ONGOING — EMERGENCY | — | — | **A** (duyệt action 2h) | C | A (khi AM không phản hồi) | R | R | — | A (budget/targeting) |
| ONGOING — REPORTING | — | — | **A** (QC + gửi) | C (duyệt insight Monthly) | — | R (compile) | R (pull data) | — | I |
| WRAP-UP | I | — | R/**A** | R | C | — | — | — | R |
| CLIENT SURVEY | — | — | R/**A** | — | C (NPS <6) | — | — | — | R |
| FINAL REPORT | — | — | R | A (duyệt format) | I | — | — | — | I |
| OFFBOARDING | R (hỗ trợ) | — | R/**A** | — | — | — | — | — | A (ký biên bản) |
| INTERNAL RETRO | — | — | R/**A** | R | — | R | R | — | — |
| CLOSED | R (nhận nurturing) | I | **A** | I | I | I | I | — | I |
| RENEW (A/B/C) | R (phối hợp) | C | R/**A** | C | C | — | — | C | A (quyết định) |
| LOST | R/A (Sales stages) | C (review) | R/A (BPVH stages) | — | — | — | — | — | — |
| PAUSED | I | **A** (hoặc AD) | R (đề xuất) | I | A | I | I | — | I |

## 2. Điểm Gate phê duyệt — tổng hợp

| # | Gate | Ai phê duyệt | Điều kiện | SLA người duyệt |
|---|------|--------------|-----------|-----------------|
| G1 | BYPASS First Meeting | **SM** (duy nhất) | Tier D/E + lý do nhãn lớn | 4h làm việc |
| G2 | QUALIFIED Go/No-Go | **SM ký duyệt** `[V6.0]` | 5 tiêu chí ≥4/5; borderline 3/5 SM quyết | 1 ngày làm việc |
| G3 | Bàn giao Sales → BPVH | SM ký → **AM xác nhận tiếp nhận** | Handoff Package đầy đủ | AM: 4h làm việc |
| G4 | Thẩm định borderline Evaluation | AM Lead / AD `[V6.0]` | Điểm 3.0–3.49 | 4h |
| G5 | Giá sơ bộ Proposal v0.x | **AD** | Trước Rehearsal | Trong vòng 5 ngày v0.x |
| G6 | Giá cuối + điều khoản | **AD** (Rehearsal) | AM không tự thỏa ngoài khung | Tại buổi Rehearsal |
| G7 | Vượt giới hạn revision Proposal | **AD** | PMS tự block khi quá ≤2/≤4 vòng | Ngay khi cảnh báo |
| G8 | Duyệt margin Quotation | **AD** | Accountant tính giá theo định mức | Trong SLA 2 ngày Quotation |
| G9 | Gia hạn Negotiation quá SLA | **SM** | Chỉ khi lý do pháp lý | Khi có yêu cầu |
| G10 | **D+0 kích hoạt** | **Accountant (FIN_L1)** | Tiền vào TK — điều kiện duy nhất (Financial Hard Stop) | 4h làm việc |
| G11 | KH ký 6 Communication Rules | **KH** | Điều kiện Hard Gate Kick-off D+3 | Tại buổi D+3 |
| G12 | Duyệt content/creative | **AM** — bắt buộc, không ngoại lệ | Mọi content trước publish | 2h (4h video dài) |
| G13 | A/B test chạy + declare winner | **AM** | 1 variable; ≥50 clicks hoặc ≥10 conversions; chênh ≥20% | Trước khi chạy / khi đủ sample |
| G14 | Emergency action | **AM** (2h) → AD (AM không phản hồi 30p) | KPI <70% / KH khẩn / lỗi nghiêm trọng | 2h |
| G15 | Thay đổi budget/targeting | **KH** — luôn bắt buộc, kể cả emergency | Không áp dụng Rule 4 im lặng | Theo SLA Communication Rules |
| G16 | Dự án vượt năng lực / capacity 80–100% | **AD**; capacity >100% → **CEO/COO ngừng nhận** | Trước khi nhận project mới | Ngay |
| G17 | Health Score <60 / drop >15 điểm | **AD vào cuộc** | PMS auto-alert | Alert trong 24h |
| G18 | PAUSED | **SM hoặc AD** | AM đề xuất + lý do | 24h update PMS |
| G19 | Early termination / ONGOING exit | **AD approve** · Accountant pro-rata | Termination clause / mutual agreement | 4h |
| G20 | Renew đề xuất cuối | AD (còn 7 ngày) | KH chưa phản hồi đề xuất renew | Mốc 30/14/7 ngày |

## 3. Bảng SLA tổng hợp toàn vòng đời

### 3.1 Sales Phase

| Việc | SLA |
|------|-----|
| Tạo project PMS sau khi nhận lead | 24h |
| Gửi form brief | 24h sau RAW_DATA |
| KH không mở form | Nhắc D+2 · gọi D+3 · escalate SM D+4 |
| Tổ chức First Meeting | 3 ngày làm việc (+2 có lý do) |
| SM duyệt bypass | 4h làm việc |
| Kiểm tra brief sơ bộ đủ 3 trường `[V6.0]` | 2h làm việc |
| Hoàn thiện brief chi tiết | 1 ngày làm việc |
| Stage LEAD | 1 ngày làm việc |
| QUALIFIED | 1 ngày |
| AM xác nhận bàn giao | 4h làm việc |
| LOST: update PMS + nurturing plan | 24h |

### 3.2 Đánh giá & Đề xuất

| Việc | SLA |
|------|-----|
| EVALUATION | 2 ngày (+1 nếu phức tạp) |
| SECOND MEETING | 3 ngày tổ chức (+2 nếu KH bận) |
| PROPOSAL v0.x | 5 ngày (tối đa 3 vòng nội bộ) |
| REHEARSAL | 1 buổi 2–3h (reschedule ≤2 ngày) |
| Gửi PROPOSAL v1.0 | 1 ngày sau Rehearsal pass |
| Review vòng: KH phản hồi / AM sửa | 3 ngày / 2 ngày (KH im 3 ngày nhắc · 5 ngày escalate SM) |
| PITCHING | 5 ngày sau khi KH confirm lịch (+3) |
| QUOTATION | 2 ngày sau khi KH chọn |
| NEGOTIATION | 5 ngày làm việc (SM approve gia hạn) · reminder 2 ngày/lần · quá 7 ngày SM contact CEO KH · quá 14 ngày LOST/PAUSED |
| WON update PMS + notify | 24h |

### 3.3 Triển khai (D+ timeline)

| Việc | SLA |
|------|-----|
| Accountant confirm tiền | 4h làm việc sau khi tiền vào |
| Planning Draft | Trong ngày D+0 |
| Kick-off nội bộ 1 / 2 | D+1 / D+2 · 1–2h · không lùi |
| Kick-off KH | D+3 · 1–2h · không gia hạn (D+5 lùi theo nếu trễ) |
| Thu thập tài nguyên | Trước D+4 (KH chậm cấp quyền: nhắc hàng ngày → 3 ngày AM call → 5 ngày AD) |
| HĐ chưa ký sau D+0 | Cảnh báo PMS ngày 3 |

### 3.4 ONGOING

| Việc | SLA |
|------|-----|
| Daily Health Check | Trước 9h (5–10 phút) · task chưa complete 10h → alert Lead Media · issue xử lý 2h |
| AM duyệt content | 2h (4h video dài · 1h trend gấp) |
| Content self-QC + Lead review | 4h · tối đa 3 vòng nội bộ |
| Launch campaign sau approve | Trong ngày |
| Emergency: tag AM / AM acknowledge / AM duyệt / thực thi | 15p / 15p / 2h / 2h |
| Pull data | Daily trước 8h · Weekly T2 · Monthly ngày 1–3 (trước deadline gửi ≥4h) |
| Compile báo cáo | 2h |
| AM QC báo cáo | 1h Daily · 2h Weekly · 4h Monthly |
| Sai số liệu: acknowledge / sửa gửi lại | 30 phút / 4h |
| Giải thích kết quả KH hỏi | 2h |
| Rule 4: nhắc tự động / mặc định đồng ý | 20h / 24h (không áp dụng budget/targeting) |
| Lead ảo sau khi KH báo | Xử lý 48h |
| CPL >2× target | Trigger Emergency |
| Budget còn 20% | Media báo AM (~ngày 20–22) |
| A/B test | 2–7 ngày · winner: chênh ≥20% + ≥50 clicks hoặc ≥10 conversions |
| Creative Library: điền / AM approve | 24h / 24h tiếp theo |
| Handoff deadline | T-2 reminder · T-1 nhắn Zalo · trễ → escalate AD trong 2h |
| Đối tác trễ | T-2 reminder · T-1 nhắn · trễ → báo AD trong 2h |
| AM inactive | >4h giờ làm việc → alert AD |
| Competitive Intelligence | Weekly thứ 5 · 15 phút |
| Monthly Closing | 25–26 data · 27–28 internal review · 29–30 gửi KH · 1–5 monthly meeting |
| QBR | Tháng thứ 3 + mỗi 3 tháng · prep 5 ngày · không gia hạn |
| Health Score | Update tuần · AM check thứ 2 · alert <60 hoặc drop >15 trong 24h |

### 3.5 Kết thúc

| Việc | SLA |
|------|-----|
| Wrap-up | Còn 14 ngày · book trong 3 ngày |
| Survey | Gửi ngay · KH 3 ngày · nhắc sau 2 ngày |
| Final Report | 3–5 ngày (+2) |
| Offboarding | 2–3 ngày |
| Internal Retro | Tuần đầu sau Offboarding · 30–45p |
| CLOSED | 24h sau Offboarding |
| Renew mốc | 30 / 14 / 7 ngày |
| PAUSED | 24h update + pause campaign · review 2 tuần · 30 ngày contact · 60 ngày → LOST A |
| AD phản hồi exit | 4h |
| Non-payment | 15 ngày → PAUSE `[KXN-22]` · 30 ngày → TERMINATE |
| Early termination | Fast-track offboarding 7 ngày |
| AD duyệt emergency thay AM | Khi AM không phản hồi 30 phút |

## 4. Quy tắc đếm/giới hạn cần cấu hình PMS

| Quy tắc | Giá trị | Field PMS |
|---------|---------|-----------|
| Vòng review Proposal nội bộ | Tối đa 3 (v0.1→v0.3) | revision count |
| Vòng review KH | Tier B/C ≤2 · D/E ≤4 — ✅ đã chốt 12/09 theo mô hình 5 tier A–E | revision count |
| Vòng QC content nội bộ | Tối đa 3 · vòng 4 escalate AM | — |
| Daily cap quảng cáo | monthly / 30 × 1.1 | Budget Module |
| Tắt creative CTR | <0.5% sau 500 impressions | routineThresholds |
| Tắt ad set không click | sau 1000 impressions | routineThresholds |
| Minimum sample trước khi tắt | 500 impressions hoặc 10 conversions | — |
| A/B test | ≥50 clicks hoặc ≥10 conversions · chênh ≥20% | — |
| Budget test A/B tối thiểu | 2–3× CPL target/ngày/ad set | — |
| Rule 4 im lặng | `communicationRules.silenceConsentHours = 24` | communicationRules |
| Non-payment | 15 ngày PAUSE `[KXN-22]` · 30 ngày TERMINATE | — |
| PAUSED | 30 ngày contact · 60 ngày LOST A | pausedAt, resumeDate |
| Renew | 30 / 14 / 7 ngày | Notification |
| Capacity | <80% / 80–100% / >100% · trừ 20% overhead · default 40h/tuần | Capacity Module |
| Health Score | KPI 40% + Payment 20% + Portal 20% + Communication 20% · <60 đỏ · drop >15 | Analytics |
| Trend content | Đăng trong 24h kể từ khi trend nổi · buffer 20% | Content Post |
| AM handover note | Viết trước 8pm hôm trước · tối đa 10 bullet | handover_notes |
