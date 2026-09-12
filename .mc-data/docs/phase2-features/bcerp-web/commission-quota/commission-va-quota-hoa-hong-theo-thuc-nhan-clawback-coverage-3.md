# Tính Năng: Commission & Quota — Hoa hồng theo thực nhận, clawback, coverage ≥3× (Web nội bộ)

> **Dựa trên:** REQ-SALES-009 trong `phase1-business/departments/sales/sales.md` (Phần A Mục 9, Phần B.9)
> **Phân hệ:** Kinh doanh — hoa hồng & chỉ tiêu (SYS-BCERP-WEB)
> **Module:** Commission & Quota (MOD-COMMISSION-QUOTA)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/03_Quy_che_KPI_HR.md` (§5 Salary Band, §6 Chính sách lương — KPI — hoa hồng theo vị trí, §9 đề xuất entity TMS), `wf-analyze-requirements/deferred-issues.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/commission-quota/*.md`, `phase5-implementation/tasks/bcerp-web/commission-quota/feat-erp-comm-001-impl.md`
>
> **Phạm vi touchpoint SYS-BCERP-WEB:** spec này mô tả **web nội bộ responsive (Next.js)** — dashboard, form/list/workflow UI gọi API của core backend, hiển thị đúng trạng thái machine-state. Mọi business rule hoa hồng/quota được enforce ở service layer của `SYS-CORE-BACKEND` (counterpart chính — xem `core-backend/commission-quota/`); web vô hiệu hóa nút và hiển thị lỗi nghiệp vụ nhưng không tự tính con số quyền lợi. `SYS-MOBILE-INTERNAL` là counterpart thứ hai (kênh alert coverage vàng/đỏ + xem hoa hồng của mình, read-only, PII Restricted — từ Phase2).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-COMM-001 |
| Module | MOD-COMMISSION-QUOTA |
| Yêu cầu nghiệp vụ | [REQ-SALES-009] |
| Người dùng liên quan | SALES_L1 (Intern Sales), SALES_L2 (NVKD), SALES_L3 (TNKD/SM), SALES_L4 (TPKD), SALES_L5 (GDKD), FIN_L1 (xem đối soát), FIN_L2 (xác nhận clawback, đồng khóa kỳ), HR_L1 (đối chiếu KPI theo cấp), BOD_CFO_CTO (duyệt mở khóa kỳ), SYS_ADMIN |
| Độ ưu tiên | Trung bình (MEDIUM) |
| Giai đoạn | Giai đoạn 3 (Phase3 — phụ thuộc Công nợ AR GĐ2 + timesheet nhãn billable) |
| Phụ thuộc | Không có cross-dependency chặn; nội bộ: Credit engine + clawback engine + coverage/attainment tính tự động nằm ở counterpart `SYS-CORE-BACKEND` (cùng REQ-ID); dữ liệu đầu vào từ Pipeline (REQ-SALES-001/002), Quotation & Deal Desk (REQ-SALES-006), Handoff Gate 2 (REQ-SALES-008), Công nợ AR GĐ2 (REQ-FIN-007) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền (bước đánh giá expert chưa thực hiện) — spec kế thừa nguyên văn business rules Phần B.9 do sales-expert review 12/09/2026 và chính sách theo vị trí tại `documents/03_Quy_che_KPI_HR.md` §6 (`CHÍNH_SÁCH_LƯƠNG_2026`) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên web nội bộ bề mặt thao tác chính của cơ chế hoa hồng theo thực nhận: dashboard coverage/attainment realtime theo cá nhân/nhóm/phòng (coverage ≥3× quota kỳ kế tiếp = on-track; <3× vàng; <2× đỏ), màn hình quản lý clawback kỳ (FIN xác nhận số liệu → GDKD duyệt trong SLA 3 ngày làm việc), luồng phân xử tranh chấp credit deal trùng, và phê duyệt điều chỉnh quota giữa kỳ. Tính năng giúp lực lượng kinh doanh L1–L5 nhìn thấy "tiền của mình" một cách minh bạch theo tiền khách thực trả (không theo ngày ký), đồng thời cho GDKD/FIN điều hành các quyết định trừ hồi, điều chỉnh chỉ tiêu mà không đụng vào engine.

**Phạm vi:**
- Bao gồm: dashboard hoa hồng của chính mình cho từng cấp L1–L5 (credit theo từng đợt thanh toán thực nhận, clawback đã áp, attainment so quota, trạng thái từng dòng credit: ACTIVE/PAUSED/REVERSED); dashboard coverage/attainment theo nhóm (SM), theo phòng (TPKD) và toàn Sales (GDKD) với màu trạng thái vàng/đỏ realtime; form ghi split credit trước Gate 2 (chủ deal 70% – hỗ trợ 30%, SM/TPKD pre-sale tối đa 20%, tổng ≤100%) với validate trực quan tổng tỷ lệ; hàng đợi phân xử deal trùng (SM hòa giải 24h → GDKD quyết cuối 3 ngày làm việc, audit log); workflow duyệt clawback (danh sách dòng clawback engine tự sinh, FIN_L2 xác nhận kèm dẫn chiếu hóa đơn/phiếu thu/công nợ, GDKD duyệt SLA 3 ngày kể từ khi aging vượt 90 ngày); workflow điều chỉnh quota giữa kỳ theo tỷ lệ ngày làm việc (nghỉ ốm/thai sản/chuyển vị trí — SALES_L4 đề xuất, GDKD duyệt); màn xem thang hoa hồng/quota hiệu lực theo cấp (effective-dated) và trạng thái khóa kỳ; báo cáo credit/clawback/aging ảnh hưởng hoa hồng theo tháng cho GDKD/FIN/BOD.
- Không bao gồm: tính toán credit, clawback, attainment (engine ở counterpart `SYS-CORE-BACKEND` — web chỉ gọi API và hiển thị machine-state); push alert coverage vàng/đỏ hàng tuần và thông báo attainment ≥100% + booster lên mobile (counterpart `SYS-MOBILE-INTERNAL`); sổ cái AR, aging, phát hành hóa đơn (module AR/AP); bảng lương cứng, KPI template, ON/OFF lương theo doanh thu (module HR-CORE — web chỉ đọc tham chiếu `commission_tier` từ HR §6 `CHÍNH_SÁCH_LƯƠNG_2026`); xem hoa hồng/quota trên mobile nội bộ (kênh của counterpart MOBILE — trên web nội bộ, sale xem qua dashboard của mình).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive là kênh thao tác chính cho 24/25 business rules của Sales — với REQ-SALES-009, web đóng vai dashboard + phân xử + phê duyệt: hiển thị đúng machine-state của dòng credit (ACTIVE/PAUSED/REVERSED), dòng clawback (PENDING_CONFIRM → FIN_CONFIRMED → APPROVED → APPLIED/REJECTED), kỳ hoa hồng (OPEN/LOCKED) và yêu cầu điều chỉnh quota (DRAFT → PENDING_GDKD → APPROVED/REJECTED) đọc trực tiếp từ API core. Khi kỳ LOCKED, mọi form nhập liên quan bị vô hiệu hóa ở UI và API core từ chối ghi — UI phải hiển thị rõ "kỳ đã khóa" thay vì nút mờ không lý do. Dữ liệu hoa hồng là PII Restricted: mỗi sale chỉ thấy của mình, SM thấy nhóm, TPKD thấy phòng, GDKD thấy toàn phòng kinh doanh; vượt phạm vi bị chặn ở cả UI và API.

**Fan-out:**
REQ-SALES-009 xuất hiện ở 3 systems — đây là bản riêng cho SYS-BCERP-WEB; counterparts: SYS-CORE-BACKEND (credit/clawback/coverage engine — nơi enforce toàn bộ rule) và SYS-MOBILE-INTERNAL (alert coverage vàng <3×/đỏ <2× hàng tuần tới SM + GDKD; thông báo attainment ≥100% + hệ số booster; sale xem hoa hồng/quota của chính mình read-only, PII Restricted). Không rule nào có logic khác nhau giữa web và mobile — chỉ khác kênh tương tác.

**Nguồn domain:**
`documents/03_Quy_che_KPI_HR.md` (HR Domain Knowledge Base v3.9) §5–§6: salary band theo grade KD-1–KD-5; `CHÍNH_SÁCH_LƯƠNG_2026` gồm 21 sheet theo vị trí (NV Sale không BHXH, Sale intern, Sale, Sale TV, Leader Sale, Sale teamlead, TPKD-1, TPKD - chốt, Kế toán, Phân bổ doanh thu mục tiêu, Mục tiêu KD...). Cấu trúc lặp: (1) bảng điều kiện ON/OFF lương theo doanh thu theo % hoàn thành KPI trung bình nhiều tháng; (2) trọng số KPI (DTT 70% + số khách mới 30% với sale cá nhân; DTT 80% + tỷ lệ nhân sự đạt DTT tiêu chuẩn 20% với Leader/TPKD); (3) bảng "Mức Level/Rank" 12 bậc theo khoảng doanh thu thuần — mỗi bậc có lương cứng, % hoa hồng thực nhận, DTT tối thiểu, tổng thu nhập; kèm chính sách tỷ lệ 50/50 sau 6 tháng thử việc và com team (Leader Sale 0,5%–1,5% theo bậc DTT team; TPKD 3% phần chênh lệch doanh thu nhóm vượt mục tiêu). Các mức khởi tạo thang L1 2,5% → L5 6,5% (+0,5% doanh thu đơn vị cho L4/L5) và quota L1 600 triệu → L5 5 tỷ/phòng đã chốt theo DI-001 (12/09/2026) và quản lý như tham số effective-dated, không hardcode.

---

## 2. Luồng Người Dùng (User Stories)

Trên web, dữ liệu hoa hồng chảy một chiều từ engine: sale mở dashboard thấy credit từng đợt thực nhận và clawback đã áp; SM/TPKD thấy coverage nhóm/phòng đổi màu theo ngưỡng; các quyết định cần con người (xác nhận clawback, duyệt clawback, duyệt điều chỉnh quota, phân xử tranh chấp) chạy qua hàng đợi workflow có SLA hiển thị.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD) | Xem dashboard hoa hồng của mình: credit từng đợt thực nhận đối chiếu AR, clawback đã áp, attainment so quota quý | Minh bạch thu nhập, tự biết còn cách quota bao xa, không tranh chấp cuối kỳ |
| 2 | SALES_L2 (NVKD) | Ghi split credit (ai chủ deal, ai hỗ trợ, bao nhiêu %) trên form web trước khi deal qua Gate 2 | Chốt trước phần credit của mỗi người, tránh tranh chấp phát sinh sau khi deal sống |
| 3 | SALES_L3 (TNKD/SM) | Xem dashboard coverage nhóm với màu vàng (<3×)/đỏ (<2×) và danh sách deal đang treo credit | Chủ động kế hoạch bổ sung lead khi nhóm đỏ — mình là người chịu trách nhiệm trước GDKD |
| 4 | SALES_L3 (TNKD/SM) | Xử lý hàng đợi hòa giải tranh chấp credit deal trùng trong 24h, ghi kết quả có bằng chứng | Tranh chấp không treo credit vô thời hạn, kết quả minh bạch cho cả hai bên |
| 5 | SALES_L4 (TPKD) | Xem dashboard phòng + trình đơn điều chỉnh quota giữa kỳ cho nhân sự nghỉ ốm/thai sản/chuyển vị trí | Chỉ tiêu phản ánh công bằng số ngày làm việc thực tế, GDKD duyệt có căn cứ |
| 6 | SALES_L5 (GDKD) | Có một màn duyệt gộp: clawback chờ duyệt (SLA 3 ngày), yêu cầu điều chỉnh quota, khiếu nại phân xử vượt SM | Ra quyết định trừ hồi/chỉ tiêu nhanh, không trượt SLA, mọi quyết định có audit log |
| 7 | FIN_L2 | Xác nhận từng dòng clawback kèm dẫn chiếu hóa đơn/phiếu thu/công nợ, đồng khóa kỳ cùng GDKD | Mỗi dòng trừ hoa hồng bám chứng từ AR thật, kỳ chốt sạch không sửa ngầm |
| 8 | SALES_L1 (Intern Sales) | Xem hoa hồng và mức hỗ trợ của mình (theo bậc Level/Rank, chế độ học việc) — chỉ đọc | Rõ lộ trình thu nhập từ tháng đầu, không cần hỏi rồi chờ trả lời miệng |
| 9 | HR_L1 | Xem attainment/quota tổng hợp theo cấp (không PII tài chính chi tiết) | Đối chiếu chính sách §6 (`CHÍNH_SÁCH_LƯƠNG_2026`) với kết quả thực khi salary review Q4 |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — enforce tại service layer của `SYS-CORE-BACKEND`; web phải phản ánh đúng và vô hiệu hóa thao tác vi phạm ngay từ UI. Mọi thao tác ghi trên web (split, duyệt, phân xử, điều chỉnh) đều sinh audit log bất biến.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận vào PMS = không tồn tại": chỉ deal có bản ghi pipeline trước Gate 2 + qualifiedTier hợp lệ + quotation đã duyệt GM mới được hưởng credit hoa hồng — kể cả khi SM/GDKD xác nhận miệng | Dòng credit không sinh ra; web hiển thị deal ở trạng thái "không đủ điều kiện hưởng credit" kèm lý do thiếu điều kiện nào |
| BR-SALES-901 | Credit tính theo **thanh toán thực nhận** đối chiếu sổ AR (FIN nguồn sự thật) — không theo ngày ký; doanh thu chỉ đếm phí dịch vụ/markup, loại bỏ phần pass-through NSQC; HĐ dài hạn >12 tháng credit chia theo từng kỳ thực nhận; deal bị trả về từ Gate 2 → credit tạm dừng (PAUSED) đến khi handoff lại thành công | Con số hiển thị trên dashboard chỉ lấy từ `commission_credit` do engine ghi; web không có bất kỳ form nhập/sửa credit thủ công nào |
| BR-SALES-902 | Clawback: khách hủy/hoàn phí → hồi hoa hồng theo tỷ lệ tiền hoàn; nợ quá hạn >90 ngày → clawback 100% phần chưa thu; trừ vào kỳ kế tiếp; FIN_L2 xác nhận số liệu + GDKD duyệt trong SLA 3 ngày làm việc kể từ khi aging vượt 90; luôn dẫn chiếu hóa đơn/phiếu thu/công nợ | Web không cho duyệt clawback khi chưa có FIN xác nhận (nút vô hiệu + API từ chối); quá SLA tự escalate và hiển thị cảnh báo trễ; cấm xóa dòng đã áp — sai sót xử lý bằng dòng điều chỉnh ngược có phê duyệt |
| BR-SALES-903 | Split credit: chủ deal 70% – người hỗ trợ 30%; SM/TPKD hỗ trợ pre-sale tối đa 20% credit deal; **tổng mọi split ≤100%**; ghi trước Gate 2 — sau Gate 2 chặn bổ sung cứng | Form split tính tổng realtime, vượt 100% không cho lưu; deal đã qua Gate 2 mở form ở chế độ chỉ đọc kèm ghi chú "khóa sau Gate 2" |
| BR-SALES-904 | Quota theo cấp/quý (khởi tạo đã chốt theo DI-001: L1 600 triệu → L5 5 tỷ/phòng); pipeline coverage ≥3× quota kỳ kế tiếp = on-track; <3× vàng; <2× đỏ — bắt buộc kế hoạch bổ sung lead, SM (SALES_L3) chịu trách nhiệm; **attainment tự động, cấm nhập tay**; hệ số attainment quý: ≥100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; <70% ×0,8 | Không tồn tại form nhập attainment trên web; dashboard màu vàng/đỏ đọc từ `attainment_snapshot` của engine, các kênh (web/mobile) hiển thị đồng nhất một nguồn |
| BR-SALES-905 | Thang hoa hồng theo cấp: khởi tạo L1 2,5% → L5 6,5% (L4/L5 cộng 0,5% doanh thu đơn vị) — đã chốt theo DI-001; chi tiết theo vị trí tra bảng "Mức Level/Rank" 12 bậc theo %KPI tại HR §6 (`CHÍNH_SÁCH_LƯƠNG_2026`, sheet Sale/NV Sale không BHXH/Sale TV/Leader Sale/TPKD...); chính sách là bản ghi effective-dated — sửa = ban hành phiên bản mới | Web hiển thị thang hiệu lực tại thời điểm phát sinh credit; tham số không hardcode — sai phiên bản hiệu lực là lỗi hiển thị phải sửa ở nguồn dữ liệu, không sửa tay trên màn hình |
| BR-SALES-906 | Nghỉ ốm/thai sản/chuyển vị trí giữa kỳ: quota giảm theo **tỷ lệ ngày làm việc thực tế**, GDKD duyệt; điều chỉnh phải kèm ngày hiệu lực + lý do | Đề xuất thiếu lý do/hiệu lực không gửi được; attainment sau đó tính trên quota đã điều chỉnh, dashboard hiển thị cả quota gốc và quota điều chỉnh |
| BR-SALES-907 | Khóa kỳ hoa hồng sau khi chốt (GDKD + FIN_L2 đồng chốt); mở khóa phải phê duyệt (BOD_CFO_CTO) + audit log bất biến | Kỳ LOCKED: mọi form nhập vô hiệu, API từ chối ghi trừ clawback điều chỉnh đã duyệt; mở khóa không phê duyệt bị chặn kể cả với SYS_ADMIN |
| BR-SALES-908 | Tranh chấp credit deal trùng: credit thuộc người thắng phân xử theo REQ-SALES-001 (ghi trước có bằng chứng → SM hòa giải 24h → GDKD quyết cuối 3 ngày làm việc); khi tranh chấp mở, credit treo | Hàng đợi phân xử nhắc SLA; SM là đương sự thì GDKD thay thế; kết quả ghi kèm bằng chứng + audit log, web cập nhật lại credit theo kết quả chốt |

---

## 4. Phân Quyền

> *Dữ liệu hoa hồng là PII Restricted — quyền xem chặt hơn quyền xem pipeline thường. Ma trận theo 18 vai registry; thực thi ở API core, UI chỉ ẩn/vô hiệu tương ứng.*

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | FIN_L2 | HR_L1 | SYS_ADMIN / BOD_CFO_CTO |
|-----------|----------|----------|---------------|-----------------|-----------------|--------|-------|--------------------------|
| Xem hoa hồng/clawback/attainment của chính mình | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem hoa hồng chi tiết người khác | ❌ | ❌ | ✅ (nhóm mình) | ✅ (phòng) | ✅ (toàn KD) | ✅ (đối soát) | ❌ (chỉ tổng hợp không PII) | ✅ (BOD xem báo cáo) |
| Ghi split credit (chỉ trước Gate 2) | ❌ | ✅ (deal của mình) | ✅ (kèm pre-sale ≤20%) | ✅ (kèm pre-sale ≤20%) | ✅ | ❌ | ❌ | ❌ |
| Sửa/xóa split sau Gate 2 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — chặn cứng) |
| Hòa giải tranh chấp credit (24h) | ❌ | ❌ | ✅ | ❌ | ✅ (khi SM là đương sự) | ❌ | ❌ | ❌ |
| Quyết khiếu nại phân xử (3 ngày) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Xác nhận clawback (đối chiếu AR) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt clawback (SLA 3 ngày) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Đề xuất điều chỉnh quota giữa kỳ | ❌ | ❌ | ✅ (nhóm mình) | ✅ (phòng) | ❌ | ❌ | ❌ | ❌ |
| Duyệt điều chỉnh quota giữa kỳ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Khóa kỳ hoa hồng (đồng chốt) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Mở khóa kỳ (phê duyệt + log) | ❌ | ❌ | ❌ | ❌ | ✅ (trình duyệt) | ❌ | ❌ | ✅ (BOD_CFO_CTO duyệt; SYS_ADMIN thực thi) |
| Ban hành phiên bản thang hoa hồng/quota | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (trên phê duyệt BOD_CEO) |

**Lưu ý:** FIN_L1 chỉ xem báo cáo đối soát tổng hợp ở module AR/AP, không thao tác clawback trên web Sales; BOD_CEO/BOD_CFO_CTO xem dashboard tổng hợp chi phí hoa hồng, không duyệt thay GDKD các quyết định trong SLA của clawback (trừ mở khóa kỳ).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ màn hình/workflow web phải xử lý — đều đọc machine-state từ API core, không tự suy diễn.*

- **Nghỉ ốm/thai sản/chuyển vị trí giữa kỳ:** TPKD/SM trình đơn điều chỉnh trên web với ngày hiệu lực + lý do; sau khi GDKD duyệt, dashboard hiển thị song song quota gốc và quota điều chỉnh, attainment tính trên quota điều chỉnh — history các phiên điều chỉnh giữ nguyên để tra cứu.
- **Deal bị trả về từ Gate 2:** dòng credit chuyển PAUSED trên dashboard của NVKD và SM kèm chú thích "handoff lại thành công sẽ tiếp tục"; SM thấy deal trong danh sách cần xử lý, không phải đoán vì sao tháng này không có credit.
- **Tranh chấp có SM là đương sự:** hàng đợi tự chuyển lên GDKD thay thế; hai bên tranh chấp thấy trạng thái "đang phân xử cấp GDKD" và không thấy bản kết luận cho đến khi chốt kèm bằng chứng.
- **Clawback trượt SLA 3 ngày:** dòng clawback nhãn cảnh báo trễ, tự escalate lên GDKD rồi BOD theo cấu hình; GDKD duyệt muộn vẫn được nhưng hiển thị "duyệt quá SLA" trong audit log — không được xóa dấu vết trễ.
- **Kỳ hoa hồng đã khóa (LOCKED):** toàn bộ form split/điều chỉnh của kỳ đó chuyển chỉ đọc với thông báo "kỳ đã khóa ngày X bởi Y"; chỉ dòng clawback điều chỉnh đã duyệt trước đó được áp; SYS_ADMIN mở khóa không phê duyệt bị từ chối và log attempt.
- **HĐ dài hạn >12 tháng:** dashboard chia credit theo schedule từng kỳ thực nhận; khách trả lệch lịch thì đợt tiền thực về vẫn ghi credit đúng đợt, phần lệch đẩy sang đối soát của FIN hiển thị nhãn riêng.
- **Intern/chưa phát sinh doanh thu:** dashboard hiển thị mức hỗ trợ theo chế độ học việc (mức hỗ trợ cố định theo bậc, hỗ trợ 2 triệu/đợt cho đủ số brief meeting lần 2 hoặc pitching lần đầu theo HR §6) thay vì bảng hoa hồng trống — tránh hiểu nhầm "0 hoa hồng" là "bị phạt".
- **Chất lượng dữ liệu nguồn `CHÍNH_SÁCH_LƯƠNG_2026`:** sheet Sale TV có ô `#REF!` ở phần lương cứng Level 05 trở đi — khi chuẩn hóa thành tham số `commission_tier`, các ô lỗi phải được FIN/HR xác nhận giá trị thay thế trước khi ban hành; web chỉ hiển thị thang từ bản ghi policy đã chuẩn hóa, không bao giờ đọc trực tiếp file Excel gốc.
- **Mốc tạm ngừng vì không thanh toán (15/30 ngày):** đề xuất 2 bậc 15/30 ngày trước khi PAUSE `[KXN-22]` chưa được khách hàng xác nhận — spec giữ nguyên clawback cứng >90 ngày; khi `[KXN-22]` chốt, dashboard bổ sung nhãn tạm ngừng mà không phá các BR hiện có. Các khoản KXN còn mở khác (6, 7, 9, 15–21) không chặn spec này — theo dõi tại `documents/quy-trinh-lam-viec/10 §4`, không tự quyết.
- **Mobile nội bộ là kênh đối chiếu nhanh:** sale không có điện thoại/công ty chặn app vẫn làm được toàn bộ nghiệp vụ trên web; ngược lại mobile chỉ xem (read-only, PII Restricted) — mọi quyết định duyệt/phân xử phải thực hiện trên web hoặc API core, mobile không phải kênh duyệt của module này (khác với Gate 1/Gate 2).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu điều chỉnh quota (`quota_adjustment_request` — tạo trên web) và dòng Clawback (`clawback_record` — web hiển thị machine-state do engine quản lý).

**Sơ đồ trạng thái — Yêu cầu điều chỉnh quota:**
```
[DRAFT] ──(submit)──► [PENDING_GDKD] ──(duyệt)──► [APPROVED]
                          │
                          │ (từ chối, nhập lý do)
                          ▼
                      [REJECTED] ──(sửa lại)──► [DRAFT]
```

**Bảng chuyển đổi — Yêu cầu điều chỉnh quota:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_GDKD` | SALES_L3 (nhóm) / SALES_L4 (phòng) | Đủ ngày hiệu lực + lý do (ốm/thai sản/chuyển vị trí) + tỷ lệ ngày làm việc |
| `PENDING_GDKD` | Duyệt | `APPROVED` | SALES_L5 | Engine cập nhật `quota.adjusted_target`; audit log người duyệt |
| `PENDING_GDKD` | Từ chối | `REJECTED` | SALES_L5 | Bắt buộc nhập lý do; người trình thấy lý do ngay trên đơn |
| `REJECTED` | Sửa lại | `DRAFT` | Người trình | Mọi phiên sửa giữ history |

**Sơ đồ trạng thái — Dòng Clawback (web hiển thị, engine quản lý):**
```
[PENDING_CONFIRM] ──(FIN xác nhận)──► [FIN_CONFIRMED] ──(GDKD duyệt, SLA 3 ngày)──► [APPROVED] ──(áp kỳ kế tiếp)──► [APPLIED]
                                                                                       │ (từ chối)
                                                                                       ▼
                                                                                  [REJECTED]
```

**Bảng chuyển đổi — Dòng Clawback (thao tác trên web):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING_CONFIRM` | Xác nhận số liệu | `FIN_CONFIRMED` | FIN_L2 | Dẫn chiếu đầy đủ hóa đơn/phiếu thu/công nợ; aging xác thực từ sổ AR |
| `FIN_CONFIRMED` | Duyệt | `APPROVED` | SALES_L5 | Trong SLA 3 ngày làm việc kể từ khi aging vượt 90; quá SLA hiển thị cảnh báo + log |
| `FIN_CONFIRMED` | Từ chối | `REJECTED` | SALES_L5 | Bắt buộc nhập lý do; log bất biến |
| `APPROVED` | Áp vào kỳ kế tiếp | `APPLIED` | Hệ thống (tại khóa kỳ) | Kỳ kế tiếp khóa; dashboard cập nhật giảm thu nhập kỳ kế tiếp |

**Quy tắc:** `APPLIED` và `REJECTED` là trạng thái kết thúc — sai sót chỉ xử lý bằng dòng điều chỉnh ngược mới có phê duyệt; web không cho nhảy cóc trạng thái (duyệt khi chưa có FIN xác nhận bị chặn ở cả UI lẫn API); kỳ hoa hồng chỉ có `OPEN`/`LOCKED` — chuyển đổi theo BR-SALES-907.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity để developer nắm nhanh bề mặt web — DDL đầy đủ và logic engine tại counterpart `SYS-CORE-BACKEND` (`core-backend/commission-quota/`) và `database-design.md`. Đặt tên theo định hướng entity TMS tại `documents/03_Quy_che_KPI_HR.md` §9.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `commission_credit` (đọc) | `deal_id`, `user_id`, `payment_ref` (AR), `recognized_amount`, `rate_applied`, `split_ratio`, `status` (ACTIVE/PAUSED/REVERSED) | FK → `deal`, `ar_payment`, `users`, `commission_period` | Dashboard cá nhân đọc; 1 payment thực nhận = 1 dòng |
| `commission_split` (ghi qua form) | `deal_id`, `owner_user_id`, `support_user_id`, `ratio`, `recorded_at`, `gate2_passed` | FK → `deal`, `users` | Chỉ ghi trước Gate 2; tổng ≤100% validate ở service layer |
| `clawback_record` (workflow duyệt) | `credit_id`, `reason` (CANCEL_REFUND/OVERDUE_90), `amount`, `invoice_ref`, `status` | FK → `commission_credit`, `ar_document` | Engine tự sinh; FIN xác nhận + GDKD duyệt SLA 3 ngày |
| `quota` (đọc) | `user_id`, `period_id`, `target_amount`, `adjusted_target`, `adjust_reason` | FK → `users`, `commission_period` | `adjusted_target` chỉ có khi đề xuất điều chỉnh được duyệt |
| `quota_adjustment_request` (tạo trên web) | `user_id`, `period_id`, `requested_ratio`, `reason`, `effective_from`, `state` (DRAFT/PENDING_GDKD/APPROVED/REJECTED) | FK → `users`, `quota` | Workflow riêng của web; duyệt xong engine cập nhật `quota` |
| `credit_dispute` (hàng đợi phân xử) | `deal_id`, `claimant_user_id`, `respondent_user_id`, `evidence_ref`, `state` (OPEN/SM_MEDIATION/GDKD_DECIDED), `resolution` | FK → `deal`, `users` | SLA hòa giải SM 24h; GDKD quyết cuối 3 ngày; audit log |
| `attainment_snapshot` (đọc) | `user_id`, `period_id`, `coverage_ratio`, `attainment_pct`, `computed_at` | FK → `users`, `quota` | Nguồn màu vàng/đỏ dashboard; không có form ghi tay |
| `commission_period` (đọc) | `code` (VD: 2026-Q3), `status` (OPEN/LOCKED), `locked_at`, `locked_by` | 1-N → `commission_credit`, `clawback_record` | LOCKED → form vô hiệu trên toàn web |
| `commission_policy` / `commission_tier` (đọc) | `version`, `effective_from/to`, `tier_rates` (L1–L5), `attainment_multipliers`; `career_level`, `rate`, `quota_per_period` | FK → policy | Tham chiếu bảng Level/Rank HR §6; effective-dated, append-only |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-009.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Dashboard cá nhân đúng nguồn | NVKD có deal qua Gate 2, khách đã trả 1 đợt phí dịch vụ | NVKD mở dashboard hoa hồng của mình | Thấy đúng 1 dòng credit theo rate cấp × hệ số attainment, không có phần pass-through NSQC, trạng thái ACTIVE | [ ] |
| SC-002: Chặn split vượt 100% sau Gate 2 | Deal đã qua Gate 2 với split 70/30 | NVKD mở form split và thử bổ sung người hỗ trợ | Form chỉ đọc kèm chú thích "khóa sau Gate 2"; mọi request ghi bị API từ chối và log attempt | [ ] |
| SC-003: Workflow clawback đủ 2 chặn | Engine sinh clawback aging >90 ngày | GDKD thử duyệt khi FIN chưa xác nhận | Nút duyệt vô hiệu + API từ chối; sau khi FIN_L2 xác nhận, GDKD duyệt được trong SLA 3 ngày, dòng chuyển APPROVED | [ ] |
| SC-004: Coverage đổi màu đúng ngưỡng | Nhóm SM có coverage 2,4× quota kỳ kế tiếp (vàng), giảm còn 1,8× (đỏ) | SM mở dashboard nhóm theo 2 thời điểm | 2,4× hiển thị vàng (<3×); 1,8× hiển thị đỏ (<2×) kèm nhãn "bắt buộc kế hoạch bổ sung lead" — cả hai đọc từ `attainment_snapshot`, không nhập tay | [ ] |
| SC-005: Điều chỉnh quota giữa kỳ | NVKD nghỉ thai sản 45 ngày giữa quý | TPKD trình đơn với tỷ lệ ngày làm việc, GDKD duyệt | Quota điều chỉnh hiển thị song song quota gốc; attainment tháng sau tính trên quota điều chỉnh; history đơn giữ nguyên | [ ] |
| SC-006: PII Restricted chặn chéo phạm vi | SALES_L2 đăng nhập web | Thử mở dashboard hoa hồng của NVKD khác (đổi ID trên URL) | API trả lỗi truy cập; UI không render dữ liệu; log attempt ghi nhận | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (credit engine, đối chiếu AR, fan-out MOBILE) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (dashboard coverage/attainment, hàng đợi clawback/phân xử) | `phase4-ux/bcerp-web/commission-quota/*.md` |
| Counterpart engine (enforce business rules) | `phase2-features/core-backend/commission-quota/commission-va-quota-hoa-hong-theo-thuc-nhan-clawback-coverage-3.md` |
| Counterpart mobile (alert + xem của mình, PII Restricted) | `phase2-features/mobile-internal/commission-quota/*.md` |
| Nguồn domain chính sách lương — hoa hồng theo vị trí | `documents/03_Quy_che_KPI_HR.md` (§5, §6 — `CHÍNH_SÁCH_LƯƠNG_2026`, §9) |
| Business rules gốc REQ-SALES-009 | `phase1-business/departments/sales/sales.md` (A Mục 9, B.9) |
| Vòng đời báo cáo coverage/clawback trong workflow tổng | `phase1-business/P1-02-business-workflow.md` (Bảng B.9: coverage ≥3×; aging >90 ngày clawback — FIN_L2, GDKD) |
