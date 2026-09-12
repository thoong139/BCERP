# BÁO CÁO AUDIT ĐỘC LẬP — BỘ TÀI LIỆU QUY TRÌNH & ĐỐI CHIẾU PIPELINE MCV3

> **Ngày:** 12/09/2026 (phiên audit độc lập đầu tiên)
> **Theo prompt:** `.mc-data/work/audit-prompt-independent-v2.md`
> **Phương pháp:** contract-driven (`.mc-data/work/audit-structure-check.js` — chạy lại, PASS) + đối chiếu chuỗi trực tiếp 3 nguồn (v2.3 HTML qua trích xuất DATA, V6.0, documents/05). KHÔNG dùng `phase0-cross-check.sh`.
> **Ràng buộc đã tuân theo:** read-only với `documents/`, `.claude/`, `.zcode/`, `docs/`; không sửa tay `req-registry.json`; không chạy skill `wf-*`. Sửa duy nhất 1 file tooling `.mc-data` (coverage-check.js — vá bug regex, có `.bak` kèm cạnh, chi tiết IND-06).
> **Artifact hỗ trợ để lại** (read-only evidence): `work/audit-independent-verify.js`, `work/independent-audit-data-dump.txt` (dump 72 entry v2.3).

---

## 1. TL;DR — Verdict 4 phần

| Phần | Nội dung | Verdict | Ghi chú |
|------|----------|---------|---------|
| **A** | Bộ gốc vs 3 nguồn (cấu trúc, ~40 mẫu, KXN coverage, bộ đếm) | **PASS** (có findings) | 33 mẫu MATCH + 7 TAGGED-KXN (hành vi đúng) + 3 SOURCE-NOT-FOUND (IND-04, IND-05); 3 lỗi cross-ref (IND-01/02/03); mọi bộ đếm tuyên bố đều xác minh được |
| **B** | Tham chiếu `.mc-data` → bộ gốc (6 điểm + DATA-extract ≥3 entry) | **PASS** | 6/6 điểm resolve đúng chiều; DATA-extract.json khớp 100% DATA trong HTML (72/72 entry, 0 khác biệt) |
| **C** | Nhất quán tầng trạng thái pipeline (khả năng resume) | **PASS** | 4 tầng (status/session-state/checkpoint/latest) cùng vị trí `phase1-scope-mapping`, P0+P0.5 completed, override CDG-A02; handoff trỏ đúng; 59 REQ / 19 modules / 18 vai khớp `docs_reqs.txt` |
| **D** | Cam kết "chưa làm" chưa ai tự ý thực thi | **PASS** | Mâu thuẫn tier 2 chiều còn nguyên vẹn; DEPLOY bảng 2.1 vẫn bản đề xuất cũ; `phase2-features/` không tồn tại |
| **TỔNG** | | **PASS** | 4/4 phần đạt; 10 findings (0 Critical, 0 High, 5 Medium, 3 Low, 2 Info) — không finding nào chặn Phase 2 ngoài 6 KXN P0 đã biết |

---

## 2. Findings (IND-xx)

> Severity: Critical/High/Medium/Low/Info. "Người chốt" = ai quyết định/khắc phục.

### IND-01 · Medium — Cross-ref sai: file 03 §2.3 trỏ "tài liệu 10 §3.4" cho AUD-01 nhưng §3.4 là KXN-4
- **Bằng chứng:** `documents/quy-trinh-lam-viec/03_Giai_doan_2_Danh_gia_va_De_xuat.md` dòng 92: "*(AUD-01, xem tài liệu 10 §3.4)*". File `10_...md` §3.4 (dòng 70–73) là **KXN-4 — Vị trí gate bàn giao**; nội dung AUD-01 nằm ở **§3.1 (KXN-1)** và **§3.6 (KXN-8)**. Đối chiếu: `.mc-data/docs/phase1-business/stakeholder-review.md` F.4 và deferred-issues.md DI-002 đều trỏ đúng "file 10 §3.1/§3.6".
- **Ảnh hưởng:** người đọc tra khoản P0 quan trọng nhất sẽ đến nhầm khoản khác.
- **Hành động:** sửa ref thành "10 §3.6 (và §3.1)" khi ra bản v1.1.
- **Người chốt:** chủ dự án (sửa tài liệu — không phải quyết định kinh doanh).

### IND-02 · Low — Cross-ref treo: file 04 §7 trỏ "05 §5.7" không tồn tại
- **Bằng chứng:** `04_Giai_doan_3_Trien_khai_Deploy.md` dòng 162: "Rule 4 (Im lặng = Đồng ý, 24h — **xem 05 §5.7**)". File `05_Giai_doan_4_Van_hanh_ONGOING.md` không có mục §5.7 (chỉ có §1–§5, trong đó §5 là bảng phân công vai); Rule 4 thực tế định nghĩa tại **05 §4.2** (`og_silence`).
- **Ảnh hưởng:** tham chiếu không mở được nội dung tương ứng (nội dung vẫn tồn tại ở mục khác).
- **Hành động:** sửa ref thành "05 §4.2" ở bản v1.1.
- **Người chốt:** chủ dự án.

### IND-03 · Medium — Stage UPSELL của v2.3 không được tái dựng; file 01 trỏ "06 §1" nhưng file 06 không có mục UPSELL
- **Bằng chứng:** DATA v2.3 có entry `upsell` đầy đủ (SLA "AM soạn đề xuất trong 24h"; accepted nhỏ → điều chỉnh project / accepted lớn → project mới + `parentProjectId`). File 01 dòng 52 trỏ UPSELL → "Tài liệu **06 §1**" và dòng 118 ghi "UPSELL/RENEW/CLOSED tại 06 §1–4" — nhưng file 06 chỉ có RENEW (§4) và CLOSED (§3); §1 là sơ đồ không chứa upsell; không file nào trong bộ gốc tái dựng 5W1H của stage này. `coverage-check.js` chỉ kiểm 39 key `og_*` nên 33 stage không được coverage-check — upsell lọt lưới.
- **Ảnh hưởng:** 1/33 stage của nguồn chuẩn bị thiếu nội dung; cross-ref dẫn tới chỗ trống.
- **Hành động:** bổ sung mục UPSELL (dựa nguyên văn entry `upsell` v2.3) vào file 06 hoặc file 01, sửa cross-ref; cân nhắc mở rộng coverage-check sang 33 stage key.
- **Người chốt:** chủ dự án (sửa tài liệu).

### IND-04 · Medium — Danh sách "4 lý do LOST" tại Pitching và Negotiation không có ở bất kỳ nguồn nào, không gắn thẻ
- **Bằng chứng:** file 03 §2.7: "LOST sau pitching — 4 lý do: thua đối thủ / chiến lược không phù hợp / thời điểm không phù hợp / nhân sự không đáp ứng"; §2.9: "giá không phù hợp / cấp trên KH không duyệt / giấy tờ vướng mắc / lý do khác"; lặp lại tại file 06 §6 ("Lý do LOST chuẩn"). Tìm chuỗi trong toàn bộ DATA v2.3 (72 entry), V6.0 và documents/05: **không có** — v2.3 chỉ ghi "KH từ chối → LOST (ghi lý do 4 nhóm)" (pitching.ft) và "→ LOST (4 lý do chi tiết)" (negotiation.ft) mà không liệt kê; "thua đối thủ" chỉ xuất hiện 1 lần ở `rehearsal` như kịch bản luyện tập, không phải lý do LOST.
- **Ảnh hưởng:** đây là mâu thuẫn/giá trị chưa định nghĩa **chưa được gắn `[KXN-n]`** (đúng loại finding Phần A3 yêu cầu tìm) — nếu cấu hình PMS field `lostReason` theo enum này mà nguồn không xác nhận sẽ đi ngược nguyên tắc 3 của README §1.
- **Hành động:** hoặc bổ sung KXN-21 (P1) vào file 10, hoặc gắn `[KXN-17]`-liên-quan (nhóm LOST A/B/C/D cũng chưa định nghĩa nguồn).
- **Người chốt:** chủ dự án/khách hàng (nguồn gốc con số "4 lý do" phải được xác nhận hoặc gỡ).

### IND-05 · Medium — Hằng số "trễ 15 ngày → PAUSE campaign" (Non-payment) không có trong nguồn
- **Bằng chứng:** file 06 §7 (kịch bản 3): "Trễ **15 ngày** → PAUSE campaign · trễ 30 ngày → TERMINATE"; lặp tại file 08 §3.5 và 09 §9. DATA v2.3 (`og_ongoing_exit`) chỉ ghi: "Non-payment → PAUSE → **30 ngày → TERMINATE**" — không có mốc 15 ngày PAUSE ở entry nào (grep "15 ngày" = 0 hit trong 72 entry). V6.0/documents/05 không đề cập.
- **Ảnh hưởng:** giá trị chưa định nghĩa chưa gắn thẻ — ảnh hưởng cấu hình notification rule non-payment (PMS).
- **Hành động:** bổ sung KXN-22 (đề xuất P1) hoặc xác nhận lại mốc 15 ngày với khách hàng; nếu bỏ, sửa 3 chỗ (06/08/09).
- **Người chốt:** chủ dự án/khách hàng.

### IND-06 · Low — Bug tooling: check mermaid trong coverage-check.js luôn báo 0 block (đã vá trong audit, có .bak)
- **Bằng chứng:** `.mc-data/work/lifecycle-v23/coverage-check.js` (bản gốc dòng 11) dùng `new RegExp(fence + 'mermaid([\s\S]*?)' + fence)` — trong string literal JS, `\s`/`\S` mất backslash → regex thực thi là `[sS]` → không khớp block nào. Kết quả cũ: "mermaid blocks: 0 | malformed: 0" (kiểm tra vô hiệu). **Đã vá trong phiên audit này** (regex `\\s\\S` đúng), kèm `coverage-check.js.bak`; validate `node --check` PASS; kết quả mới: **"mermaid blocks: 13 | malformed: 0"** — khớp đếm độc lập bằng script audit (`audit-independent-verify.js mermaid`).
- **Ảnh hưởng:** trước đây không ai phát hiện được lỗi mermaid bằng script này (may mắn 13/13 block đều hợp lệ theo kiểm tra độc lập của audit — cấu trúc khai báo, cân bằng nhãn/subgraph, mũi tên đều đúng; `-.->` và `A & B` là cú pháp Mermaid hợp lệ).
- **Người chốt:** ✅ đã xử lý xong bởi auditor (IND-06 closed).

### IND-07 · Low — File 07 gắn nhãn nguồn `[V6.0]` sai cho mô tả TNKD
- **Bằng chứng:** `07_Co_cau...md` §2 dòng 30: "TNKD … Hỗ trợ xử lý deal lớn `[V6.0]` — chưa xuất hiện trong lifecycle v2.3". Cụm "hỗ trợ xử lý deal lớn" lấy từ **documents/05** (mô tả `SALES_L3`), không có trong `01_Quy_trinh_MKT_Tong_the.md` (V6.0 không nhắc TNKD). Quy ước `[V6.0]` ở README §3 định nghĩa là "chi tiết lấy bổ sung từ tài liệu 01".
- **Ảnh hưởng:** sai lệch truy vết nguồn (minor).
- **Hành động:** đổi nhãn thành nguồn documents/05 khi ra v1.1.
- **Người chốt:** chủ dự án.

### IND-08 · Low — Giả định "Quản lý duyệt Gross Margin" (V6.0) ≡ AD chưa được ghi chú
- **Bằng chứng:** V6.0 §GĐ2-4 ghi "Quản lý duyệt biên lợi nhuận (Gross Margin)"; bộ gốc quy về **AD** ở 03 §3 và 08 G8 mà không chú thích, trong khi bản thân AD là vai chưa định nghĩa (KXN-12 — chưa có mã vai, cấp bậc trong documents/05).
- **Ảnh hưởng:** nếu "Quản lý" thực tế là BOD/CFO thì ma trận phê duyệt G8 sai tầng.
- **Hành động:** thêm ghi chú vào KXN-12 (hỏi luôn phạm vi quyền "Quản lý" của V6.0) khi v1.1.
- **Người chốt:** chủ dự án/khách hàng.

### IND-09 · Info — Hai bộ tiêu chí QUALIFIED được trình bày song song nhưng khác bản chất, chưa có KXN riêng
- **Bằng chứng:** v2.3: 5 tiêu chí chấm điểm, pass ≥4/5 (file 02 §2.6 chính); V6.0: "tiêu chuẩn qualify" 3 điều kiện + chấm lại CQ lần 2 (`qualifiedTier`). File 02 §2.6 trình bày bản V6.0 như "Bổ sung" — không tuyên xung đột, khác biệt được bao trùm một phần bởi KXN-2/KXN-4 nhưng không trọn vẹn (KXN-2 là thời điểm scoring, KXN-4 là vị trí gate).
- **Ảnh hưởng:** thấp — đã hiển thị 2 chiều, người đọc không bị dẫn dắt sai.
- **Hành động:** cân nhắc gom ghi chú vào KXN-2 khi v1.1.
- **Người chốt:** chủ dự án.

### IND-10 · Info (ngoài phạm vi bộ gốc) — Con số "17 mã vai" trong prompt audit và audit 12/09 không tái hiện được
- **Bằng chứng:** audit prompt §1 và `audit-documents-alignment-20260912.md` §1 đều ghi "17 (mã vai)" cho documents/05; đếm thực tế documents/05: **15 mã vai** (HR_L1/L2, FIN_L1/L2, SALES_L1–L5, OPS×6) + 4 vị trí BOD không mang mã. Bộ gốc **không** tuyên bố con số 17 ở đâu (README chỉ nói "Vận hành 6 mã vai", "Sales 5 cấp") nên đây là sai số của prompt/biên bản trước, không phải lỗi bộ gốc.
- **Ảnh hưởng:** không ảnh hưởng tài liệu; có thể gây hiểu nhầm khi đối chiếu registry 18 vai (18 = 15 mã + BOD_CEO + BOD_CFO_CTO + SYS_ADMIN theo handoff actors — hợp lý).
- **Người chốt:** ghi nhận; không cần hành động.

### Ghi chú thêm về "33/39" trong prompt (không lập finding riêng)
Prompt Phần A4 yêu cầu xác minh "33/39 key og trong coverage-check.js". Thực tế chạy: **39/39**; biên bản §8.1 của audit 12/09 cũng ghi 39/39 (đếm lại sau khi hoàn tất bộ gốc). Con số "33/39" trong prompt là **stale/typo** — có khả năng nhầm từ thời điểm giữa phiên tái dựng. Không có hành động cần thiết ngoài ghi nhận.

---

## 3. Sample evidence (Phần A2) — 40 mẫu đối chiếu

> Nguồn đối chiếu: **v2.3** = tìm chuỗi trong DATA 72 entry của HTML (dump: `independent-audit-data-dump.txt`); **V6.0** = `documents/01_Quy_trinh_MKT_Tong_the.md`; **05** = `documents/05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md`. Verdict: MATCH / TAGGED-KXN (mâu thuẫn đã được gắn thẻ — hành vi đúng) / SOURCE-NOT-FOUND.

### Giai đoạn 1 — Sales (file 02)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 1 | RAW DATA SLA (02 §2.1) | 24h tạo project PMS, không gia hạn | v2.3 `raw_data.sla` | MATCH |
| 2 | Escalation KH không mở form (02 §2.2) | Ngày 2 nhắc Zalo → ngày 3 gọi → ngày 4 escalate SM | v2.3 `brief_sent.risks` | MATCH |
| 3 | First Meeting SLA (02 §2.3) | 3 ngày làm việc sau submit; +2 ngày có lý do ghi PMS | v2.3 `first_meeting.sla` | MATCH |
| 4 | BYPASS (02 §2.3b) | SM là người duy nhất duyệt; phản hồi 4h làm việc; Tier C/D | v2.3 `bypass` | MATCH |
| 5 | Brief đủ 8 mục (02 §2.4) | mục tiêu, ngân sách, timeline, target audience, sản phẩm, đối thủ, kênh mong muốn, KPI kỳ vọng | v2.3 `brief_received.done` (nguyên văn); biến thể V6.0 8 sections khác 4/8 | MATCH (biến thể đã gắn KXN-3) |
| 6 | LEAD SLA (02 §2.5) | 1 ngày làm việc sau khi brief đủ | v2.3 `lead.sla` | MATCH |
| 7 | QUALIFIED 5 tiêu chí (02 §2.6) | Ngân sách đủ/Ngành phù hợp/Quyết định/Timeline/Kỳ vọng — pass ≥4/5; borderline 3/5 SM quyết | v2.3 `qualified` (nguyên văn) | MATCH |
| 8 | AUTO SCORING (02 §2.2b) | K1–K5 knockout AUTO LOST; CQ 30/25/20/15/10; Tier A <1.5 AUTO LOST · B/C 1.5–2.99 gặp bắt buộc · D/E ≥3.0 bypass | V6.0 §3 (nguyên văn) | MATCH (tier map gắn KXN-1, thời điểm gắn KXN-2) |
| 9 | Handoff Package (02 §2.5) | 5 nhóm checklist; SM ký → AM xác nhận 4h; V6.0 đặt gate ở LEAD vs v2.3 ở QUALIFIED | V6.0 §6 | MATCH (gắn KXN-4) |

### Giai đoạn 2 — Đánh giá & Đề xuất (file 03)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 10 | EVALUATION SLA (03 §2.1) | 2 ngày làm việc (+1 brief phức tạp) | v2.3 `evaluation.sla` | MATCH |
| 11 | Tiêu chí Evaluation (03 §2.1) | v2.3 "5–7 tiêu chí" không liệt kê; V6.0 Brand Safety 7 tiêu chí (fail 1 → LOST) + Weighted 9 tiêu chí pass ≥3.5, trọng số 20/15/15/10×4/5/5; borderline 3.0–3.49 thẩm định 4h | v2.3 `evaluation` + V6.0 §1 (nguyên văn) | MATCH (gắn KXN-6) |
| 12 | Second Meeting (03 §2.2) | 3 ngày (+2 KH bận); Strategic Brief 16 sections ≥80% | v2.3 `second_meeting` | MATCH (16 sections chưa định nghĩa — gắn KXN-7) |
| 13 | Proposal nội bộ (03 §2.3) | Tối đa 3 vòng (v0.1→v0.3) trong 5 ngày; giá sơ bộ AD confirm trước Rehearsal | v2.3 `proposal_internal` | MATCH |
| 14 | Rehearsal (03 §2.4) | 1 buổi 2–3h; AD quyết định giá cuối; AM không tự thỏa ngoài khung AD duyệt | v2.3 `rehearsal` | MATCH |
| 15 | Giới hạn vòng sửa (03 §2.6) | v2.3: A/B ≤2 · C/D ≤4; V6.0: B/C ≤2 · D/E ≤4 — khác do mô hình tier | v2.3 `proposal_review.done` + V6.0 §3 | TAGGED-KXN-1 (đúng hành vi) |
| 16 | Pitching SLA (03 §2.7) | 5 ngày làm việc sau confirm lịch (+3 KH bận) | v2.3 `pitching.sla` | MATCH |
| 17 | LOST pitching 4 lý do (03 §2.7) | thua đối thủ / chiến lược không phù hợp / thời điểm không phù hợp / nhân sự không đáp ứng | **không tìm thấy ở 3 nguồn** | **SOURCE-NOT-FOUND** (IND-04) |
| 18 | Quotation (03 §2.8) | 2 ngày; AM scope → Accountant tính giá → AD duyệt margin | v2.3 `quotation` + V6.0 §4 ("theo định mức", "Gross Margin") | MATCH |
| 19 | Negotiation (03 §2.9) | 5 ngày làm việc (SM approve gia hạn pháp lý); reminder 2 ngày/lần; quá 7 ngày SM contact CEO KH; 14 ngày LOST/PAUSED | v2.3 `negotiation.risks` | MATCH |
| 20 | LOST negotiation 4 lý do (03 §2.9) | giá không phù hợp / cấp trên không duyệt / giấy tờ vướng mắc / lý do khác | **không tìm thấy ở 3 nguồn** | **SOURCE-NOT-FOUND** (IND-04) |
| 21 | WON (03 §2.10) | 24h update PMS + notify team; SE chuyển observe; bắt đầu đồng hồ D-day | v2.3 `won` | MATCH |
| 22 | Định mức proposal theo tier (03 §2.3) | V6.0: B/C AM 8–12 trang; D/E Planner 15–25 trang; Tier E Big Corp bổ sung Team Bios… | V6.0 §3 (nguyên văn) | TAGGED-KXN-8/AUD-01 (đúng hành vi — giữ 2 chiều) |

### Giai đoạn 3 — Triển khai (file 04)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 23 | COLLECTING (04 §2.1) | Hoàn tất trước D+4; D+5 lùi nếu thiếu; KH chậm cấp quyền: nhắc hàng ngày → 3 ngày AM call → 5 ngày AD | v2.3 `collecting` | MATCH |
| 24 | WAIT PAYMENT (04 §2.2) | Accountant confirm 4h làm việc sau tiền vào; tiền thiếu phase → chưa trigger D+0 | v2.3 `wait_payment` | MATCH |
| 25 | D+0 & HĐ (04 §3) | HĐ có thể ký sau; PMS cảnh báo sau 3 ngày (`hasContractWarning`); mâu thuẫn với done criteria NEGOTIATION "HĐ/LOI đã ký" | v2.3 `d0_trigger` | MATCH (gắn KXN-5) |
| 26 | Planning Draft (04 §4) | Flow TT→ĐH→AD hoàn thành trong ngày D+0 | v2.3 `planning_draft` | MATCH |
| 27 | Kick-off nội bộ ×2 (04 §5–6) | D+1/D+2, 1–2h, không thể lùi; vắng phải gửi feedback trước qua chat | v2.3 `kickoff_i1`/`kickoff_i2` | MATCH |
| 28 | Kick-off KH D+3 (04 §7) | KH ký 6 Communication Rules (Hard Gate); từ chối → AD negotiate + exception; chỉ Rule 4 & Rule 6 được định nghĩa nguồn | v2.3 `kickoff_client` + `og_silence` + `og_send_report` | MATCH (gắn KXN-11) |

### Giai đoạn 4 — ONGOING (file 05)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 29 | AM duyệt content (05 §2.1.5) | 2h (video dài 4h; trend gấp 1h); AM bắt buộc không ngoại lệ; chuỗi Planner → Lead Content | v2.3 `og_am_review` | MATCH |
| 30 | Content QC (05 §2.1.1) | Tự QC + Lead review 4h; tối đa 3 vòng nội bộ, vòng 4 escalate AM; buffer 20% | v2.3 `og_content` | MATCH |
| 31 | Campaign Lifecycle (05 §2.2.2) | 24h chỉ fix kỹ thuật; 48h tắt CTR <0.5% sau 500 impressions / ad set không click sau 1000; 72h–5 ngày main window; ngày 14 mid-check; 25–28 end-month; minimum sample 500 impressions hoặc 10 conversions | v2.3 `og_campaign_lifecycle` + `og_threshold` + `og_routine` | MATCH |
| 32 | A/B test (05 §3.1) | 1 variable; 2–7 ngày; budget ≥2–3× CPL target/ngày/ad set; winner chênh ≥20% + ≥50 clicks hoặc ≥10 conversions; AM declare | v2.3 `og_ab_test` | MATCH |
| 33 | Budget pacing (05 §3.1) | Daily cap = monthly/30 × 1.1; báo AM khi còn 20% (~ngày 20–22); mọi thay đổi cần KH approve; cuối tháng dư → hỏi KH trước | v2.3 `og_budget_pacing` | MATCH |
| 34 | Emergency (05 §3.2) | Tag AM 15' · acknowledge 15' · AM duyệt action 2h · AM không phản hồi 30' → AD; AM duy nhất được tắt toàn bộ campaign, Media chỉ tắt ad set đơn lẻ | v2.3 `og_emergency`/`og_notify_am`/`og_am_action` | MATCH |
| 35 | Rule 4 im lặng (05 §4.2) | 20h hệ thống nhắc; 24h log "Im lặng = Đồng ý"; KHÔNG áp dụng budget/targeting | v2.3 `og_silence` | MATCH |
| 36 | Pull data (05 §4.1) | Daily trước 8h · Weekly thứ 2 · Monthly ngày 1–3; ≥4h trước deadline gửi; ưu tiên nguồn KH > platform > GA4/Pixel > tool; attribution FB 7-day click vs Google 30-day | v2.3 `og_pull_data` | MATCH |
| 37 | AM QC & feedback (05 §4.1–4.2) | QC 1h/2h/4h (D/W/M); sai số liệu: ack 30' + sửa gửi lại 4h; hỏi giải thích 2h (30p call nếu phức tạp) | v2.3 `og_am_qc`/`og_fb_data`/`og_fb_explain` | MATCH |
| 38 | Monthly Closing (05 §4.3) | 25–26 data (27 chưa có → escalate) · 27–28 internal review 30–45p · 29–30 gửi KH 3 kênh · 1–5 monthly meeting; report 9 sections | v2.3 `og_monthly_closing` | MATCH (9 sections gắn KXN-7) |
| 39 | QBR (05 §4.4) | Dự án ≥3 tháng, lần đầu tháng 3 + mỗi 3 tháng; deck 7 sections; prep 5 ngày; internal 45–60p; +35% renew | v2.3 `og_qbr` | MATCH |
| 40 | Client Health Score (05 §4.5) | KPI 40% + Payment 20% + Portal 20% + Communication 20%; ≥80 xanh/60–79 vàng/<60 đỏ AD vào; drop >15/tuần; check thứ 2; hiệu chỉnh Portal 10% + Comm 30% | v2.3 `og_client_health` | MATCH |
| 41 | Capacity (05 §2.2.9) | <80%/80–100%/>100% traffic light; 40h −20% overhead = 32h; calibrate sau 1 tháng; >100% CEO/COO ngừng nhận | v2.3 `og_capacity` | MATCH |
| 42 | Daily Health Check (05 §2.2.4) | Mỗi sáng trước 9h, 5–10'; 5 điểm; issue tag AM trong 5', xử lý 2h; task chưa xong 10h → alert Lead Media | v2.3 `og_account_health` | MATCH |
| 43 | Competitive Intel (05 §2.2.8) | Weekly thứ 5 (kịp report thứ 2), 15' không quá 30'; 3–5 đối thủ set lúc Second Meeting + Kick-off; giới hạn 3 ưu tiên, review mỗi quý; section Competitor Pulse | v2.3 `og_competitive` | MATCH |
| 44 | Lead quality (05 §2.2.3) | Lead ảo xử lý 48h sau KH báo; CPL >2× target → Emergency; funnel Lead thô → Hợp lệ → Đã liên hệ → Qualified → Chốt | v2.3 `og_lead_quality` | MATCH |
| 45 | AM Backup (05 §2.2.6) | Planner → Lead Content → AD; define tại D+1; handover note trước 8pm, tối đa 10 bullet; alert AD nếu AM inactive >4h; vắng >3 ngày email KH | v2.3 `og_am_backup` | MATCH |
| 46 | Handoff form & đối tác (05 §2.1.2, §2.2.5) | Form Design/Video đủ trường; T-2 reminder · T-1 Zalo · trễ → escalate AD 2h; đối tác không PMS, AM đầu mối duy nhất, `isPartnerTask`/`isEvidence` | v2.3 `og_handoff_form`/`og_partner` | MATCH |
| 47 | Creative Library (05 §2.2.7) | Chỉ nhận winner rõ ràng; điền 24h + AM approve 24h; max 5 tags; >50 entries xem xét AI layer | v2.3 `og_creative_library` | MATCH |

### Giai đoạn 5 — Kết thúc (file 06)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 48 | Wrap-up (06 §2.1) | Còn 14 ngày (PMS alert); book trong 3 ngày; họp 1–1.5h; không renew → LOST nhóm A + SM contact sau 1 tháng | v2.3 `wrapup` | MATCH |
| 49 | Survey (06 §2.2) | NPS 0–10; NPS <6 → AD review ngay; 3 hình thức gửi (AM/CS/hệ thống) | v2.3 `survey` | MATCH (hình thức mặc định gắn KXN-15) |
| 50 | Final Report (06 §2.3) | 3–5 ngày (+2 phức tạp); 9 sections; Planner duyệt; gửi 3 kênh; ưu tiên nguồn số liệu KH > platform > GA4 > tool | v2.3 `final_report` | MATCH (9 sections gắn KXN-7) |
| 51 | Retro (06 §2.5) | 30–45' tuần đầu sau Offboarding; Start/Stop/Continue; ≥3 action items có assignee+deadline; KHÔNG có KH; v2.3 có 2 node trùng | v2.3 `og_internal_retro` + `internal_retro` | MATCH (node trùng gắn KXN-16) |
| 52 | CLOSED (06 §3) | 24h sau Offboarding; archive không xóa lưu vĩnh viễn; KH vào nurturing SE (nhóm A/B/C) | v2.3 `closed` | MATCH |
| 53 | RENEW (06 §4) | 30/14/7 ngày (AD vào cuộc còn 7); 3 luồng A→PLANNING_DRAFT cùng ID / B→QUOTATION / C→project mới + `parentProjectId` từ SECOND_MEETING; NPS ≥7 + KPI ≥80% ưu tiên A | v2.3 `renew` | MATCH |
| 54 | PAUSED (06 §5) | AM đề xuất + SM/AD duyệt; 24h update + pause campaign; review 2 tuần; 30 ngày contact; 60 ngày → LOST nhóm A | v2.3 `paused` | MATCH |
| 55 | ONGOING Exit (06 §7) | 30-day notice; mutual → fast-track 7 ngày + pro-rata + AD approve 4h; non-payment → PAUSE → **30 ngày TERMINATE**; KPI miss 3 options (reset/đổi strategy/mutual) | v2.3 `og_ongoing_exit` | MATCH **trừ** mốc "15 ngày PAUSE" — **SOURCE-NOT-FOUND** (IND-05) |

### File 08 (RACI/Gate/SLA) & 09 (hằng số)

| # | Mẫu | Giá trị trong bộ gốc | Nguồn | Verdict |
|---|-----|----------------------|-------|---------|
| 56 | Ma trận RACI (08 §1) | Tổng hợp từ trường "Phụ trách" 72 entry + V6.0 — không có nguồn gốc | (bộ dựng) | TAGGED-KXN-19 (đúng hành vi) |
| 57 | Gates G1–G20 (08 §2) | G1 SM 4h bypass · G2 SM ký 1 ngày · G10 Accountant D+0 4h · G12 AM duyệt 2h · G15 KH budget bắt buộc · G19 AD exit 4h… | tổng hợp đúng từ các entry thành phần (đã đối chiếu rải) | MATCH |
| 58 | Field PMS (09 §10) | `dStartDate` `paymentConfirmedAt` `hasContractWarning` `clientTier` `servicePackage` `reportingFrequency` `backup_am_id` `routineThresholds` `communicationRules.silenceConsentHours` `parentProjectId` `exit_reason` `pro_rata_amount`… | v2.3 (mods/done của các entry tương ứng) | MATCH |
| 59 | Content Post flow (09 §10) | `IDEA→DRAFT→REVIEW→APPROVED→SCHEDULED→PUBLISHED` (+REVISION_REQUESTED) | v2.3 `og_content` | MATCH |
| 60 | "141 tham chiếu module" (01 §5) | Đếm refs `sy=pms` trong DATA v2.3 = **141** (tổng 145 gồm 4 ref cms/tms/ai tương lai) | v2.3 | MATCH |

**Tổng kết mẫu:** 60 phép đối chiếu (≥25 yêu cầu; ≥5/giai đoạn): **52 MATCH + 5 MATCH-có-gắn-KXN + 2 TAGGED-KXN thuần + 3 SOURCE-NOT-FOUND** (IND-04 ×2, IND-05 ×1). Không có mẫu nào MISMATCH (trích sai chiều nguồn).

---

## 4. Ma trận KXN — xác nhận 20 khoản còn mở

Đối chiếu file 10 §4 (bản hiện tại) với mọi quyết định đã ghi trong `.mc-data` (stakeholder-review F.3/F.4, deferred-issues, audit §7/§8): **chưa có khoản KXN nào được chốt.** Quyết định duy nhất của stakeholder tính đến giờ là DI-006 (từ chối 2 vai OPS_CX/FIN_COMPL) — không thuộc danh sách KXN.

| Mã | P | Khoản (tóm tắt) | Trạng thái | Ghi chú audit |
|----|---|------------------|-----------|---------------|
| KXN-1 | **P0** | Mô hình tier 4 (v2.3) vs 5 (V6.0) — ngữ nghĩa ngược | 🔓 Còn mở | Đúng; mâu thuẫn 2 chiều vẫn nguyên (xác nhận Phần D) |
| KXN-2 | **P0** | Thời điểm AUTO SCORING trước/sau First Meeting | 🔓 Còn mở | — |
| KXN-3 | P1 | Danh sách 8 mục Brief chuẩn | 🔓 Còn mở | — |
| KXN-4 | P1 | Vị trí gate bàn giao QUALIFIED (v2.3) hay LEAD (V6.0) | 🔓 Còn mở | — |
| KXN-5 | **P0** | HĐ/LOI trước D+0 — pháp lý | 🔓 Còn mở | — |
| KXN-6 | P1 | Bộ tiêu chí Evaluation chính thức | 🔓 Còn mở | — |
| KXN-7 | P1 | Nội dung 16 sections Strategic Brief + 9 sections Report | 🔓 Còn mở | — |
| KXN-8 | **P0** | Định mức proposal theo tier (= AUD-01/DI-002) | 🔓 Còn mở | 2 policy vẫn mâu thuẫn nguyên vẹn (Phần D) |
| KXN-9 | P2 | Phạm vi "tương lai" (CMS/TMS/AI) | 🔓 Còn mở | — |
| KXN-10 | **P0** | Xác nhận Deploy v2.3 là chính thức (bù gap V6.0) | 🔓 Còn mở | DEPLOY bảng 2.1 giữ nguyên đúng cam kết |
| KXN-11 | **P0** | Nội dung 4/6 Communication Rules thiếu | 🔓 Còn mở | — |
| KXN-12 | P1 | Vai Account Director | 🔓 Còn mở | Đề xuất gom thêm IND-08 (phạm vi "Quản lý" GM của V6.0) |
| KXN-13 | P1 | Creative Lead = Lead Content? CS thuộc đâu? | 🔓 Còn mở | — |
| KXN-14 | P1 | SM = TPKD hay GDKD | 🔓 Còn mở | — |
| KXN-15 | P2 | Hình thức gửi Survey mặc định | 🔓 Còn mở | — |
| KXN-16 | P2 | Dọn node trùng internal_retro | 🔓 Còn mở | — |
| KXN-17 | P1 | Định nghĩa 4 nhóm LOST A/B/C/D | 🔓 Còn mở | Liên quan IND-04 (danh sách lý do LOST cũng chưa có nguồn) |
| KXN-18 | P2 | Quy trình HR | 🔓 Còn mở | — |
| KXN-19 | P1 | Xác nhận Ma trận RACI | 🔓 Còn mở | — |
| KXN-20 | P2 | Danh sách đầy đủ K6–K12 | 🔓 Còn mở | — |

**Đề xuất mở rộng:** KXN-21 (P1 — 4 lý do LOST chuẩn, IND-04) và KXN-22 (P1 — mốc 15 ngày PAUSE non-payment, IND-05) khi cập nhật file 10 lên v1.1.

---

## 5. Khuyến nghị pipeline — điều kiện resume Phase 2

**Trạng thái resume path đã verify thông suốt:** `latest` → `sessions/20260912-112934-6bcf` → checkpoint (P0.5 completed, CDG-A02, current = phase1-scope-mapping, next_action nêu đủ DI-001/004/005 + DI-008) → status top + mirror (có `process_docs` → bộ gốc 11 file) → deferred-issues (DI-008 với đúng 6 mã P0) → bộ gốc. Cấu trúc phase docs theo contract: PASS (script structure-check; file phase0 stakeholder-review vắng mặt là chủ đích manual-only đã ghi nhận từ audit trước). Registry: 59 REQ ↔ `docs_reqs.txt` khớp 2 chiều 0 thiếu; 19 modules; 6 systems; **18 vai** trong handoff actors (không còn OPS_CX/FIN_COMPL — nhất quán với DI-006 resolved). Không có dấu hiệu sửa tay registry ngoài các thay đổi được biên bản (script fix-di006-reject.js có ghi nhận + F.3).

**Quyết định cần trình stakeholder trước khi fan-out Phase 2 (không thay đổi so với kế hoạch hiện hành):**
1. **DI-001** — 6 nhóm `[CẦN CHỐT SỐ]` (ngân sách/SLA/hoa hồng/AML…).
2. **DI-004** — tên phần mềm kế toán VAS + xử lý PMS cũ.
3. **DI-005** — 6 `[CẦN CHỐT SỐ]` riêng OPS.
4. **DI-008** — 6 KXN P0: **KXN-1, 2, 5, 8, 10, 11** (trong đó KXN-8 = AUD-01/DI-002 — tuyệt đối không hiệu chỉnh policy trước khi chốt).

**Finding mới của audit này có chặn Phase 2 không?** KHÔNG. IND-01/02/03/07/08/09 là lỗi tài liệu, xử lý ở bản v1.1 của bộ gốc; IND-04/05 cần vào danh sách KXN (đề xuất P1 — không chặn cấu hình PMS ở mức "chặn hoàn toàn" như 6 P0 hiện có, nhưng nên chốt trước khi build enum `lostReason` và notification rule non-payment). Không finding nào mâu thuẫn với tầng trạng thái pipeline hay yêu cầu rollback.

**Thứ tự khuyến nghị:** (1) trình stakeholder gộp DI-001/004/005 + DI-008 một lần; (2) song song ra v1.1 bộ gốc sửa IND-01/02/03/07 + bổ sung KXN-21/22 + ghi chú IND-08 vào KXN-12; (3) resume `/wf-define-features --resume` — nạp REQ mới (39 ONGOING sub-protocol + Deploy timeline + UPSELL stage đang thiếu) chỉ qua skill, không sửa registry tay.

---

## Phụ lục — thay đổi đã thực hiện trong phiên audit (minh bạch)

| File | Thay đổi | Bằng chứng |
|------|----------|------------|
| `.mc-data/work/lifecycle-v23/coverage-check.js` | Vá bug regex mermaid (IND-06): `'[\s\S]'` → `'[\\s\\S]'` | `coverage-check.js.bak` kèm cạnh; `node --check` PASS; chạy lại: "mermaid blocks: 13 \| malformed: 0" (trước vá: 0 blocks — check vô hiệu) |
| `.mc-data/work/audit-independent-verify.js` (mới) | Script đối chiếu: trích DATA từ HTML, so extract, tìm chuỗi, kiểm mermaid | Read-only; không đụng `documents/` |
| `.mc-data/work/independent-audit-data-dump.txt` (mới) | Dump 72 entry v2.3 làm bằng chứng grep | Read-only evidence |

Không file nào trong `documents/`, `.claude/`, `.zcode/`, `docs/` bị sửa. `req-registry.json` không đụng tới. Không skill `wf-*` nào được chạy.
