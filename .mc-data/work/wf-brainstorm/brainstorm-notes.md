# Biên Bản Brainstorm — BC Agency
**Ngày:** 2026-09-11
**Chuyên gia tham gia:** 10 experts (paid-media, finance, sales, marketing, customer, hr, data, legal, compliance, ecommerce)
**Bối cảnh dự án:** BCERP — ERP nội bộ đầy đủ (không MVP), Web + Mobile, ENTERPRISE; 5 phòng ban theo tài liệu cơ cấu tổ chức; 12/12 nhóm chính sách user trả lời "Chưa có"

## Phòng Vận hành — Paid Media & TKQC (chuyên gia paid-media-expert)
**Yêu cầu chính:**
- Ad Account Command Center cho 2.600+ TKQC: sync theo giờ số dư, chi tiêu, spend limit, trạng thái qua API 7 nền tảng; mỗi TK map 1 khách + 1 owner; chấm dứt ảnh chụp màn hình.
- Cảnh báo realtime 2 loại rủi ro: (a) số dư chạm ngưỡng tối thiểu — đứt chi tiêu hỏng learning phase; (b) bất thường (spend spike, checkpoint, die account); đẩy đúng owner + AM, có SLA.
- Financial Hard Stop cấp hệ thống: không cấp phát TKQC khi kế toán chưa xác nhận "đã khớp tiền"; immutable audit log mọi lệnh nạp/rút/điều chỉnh số dư/đổi tỷ giá.
- Campaign change log tự động bất biến (chuẩn audit trail 3 năm): trả lời được "ai sửa budget/bid/targeting lúc nào, lý do gì".
- View cross-platform theo khách: total spend, pacing theo Khách → Nền tảng → Chiến dịch — nền cho Client Portal và P&L realtime.

**Lo ngại:**
- Chưa có quyền API developer nền tảng: lộ trình 2 lớp — Business Verification song song nhập tay có cấu trúc; 2.600 TK đụng rate limit → batch/queue ngay từ đầu.
- Data migration "bão lệnh": import 2.600 TK chuẩn 100% (platform, currency, spend limit, owner, số dư mở sổ) — sai map 1 TK là sai cả chuỗi đối soát.
- Die account là tồn kho tiền thật của khách — cần trạng thái + evidence + lịch sử có hệ thống.

**Đề xuất ưu tiên:** Ad Account Command Center (registry trung tâm); Integration Gateway + Settings (credentials, sync scheduler, fallback nhập tay có kiểm soát); Wallet & Đối soát (bắt tay FIN_L1, immutable log); Client Portal. Vòng đời TKQC hard gate ở "Khớp tiền"; đối soát hằng ngày chốt số cuối ngày.

**Chính sách đề xuất:**
- Cấp phát & Thu hồi TKQC — Ưu tiên: Bắt buộc — Lý do: chỉ cấp khi FIN_L1 xác nhận khớp tiền (hard stop); 1 owner + 1 backup, không chia sẻ login; thu hồi trong 24h khi nghỉ/chuyển.
- Ngưỡng số dư & Xử lý die account — Ưu tiên: Bắt buộc — Lý do: cảnh báo đủ chi ≥3 ngày tới; SLA đỏ 2h làm việc; escalation owner → TL → AM; có TK dự phòng.
- Nạp tiền & Đối soát hằng ngày — Ưu tiên: Bắt buộc — Lý do: mọi top-up/refund qua lệnh hệ thống; chênh lệch vượt dung sai phải giải trình trước chốt ngày; tỷ giá theo bảng công bố nội bộ.
- Naming & UTM Convention — Ưu tiên: Nên có — Lý do: campaign bắt buộc gắn dự án trước khi bật, không gắn = không tồn tại.
- Phê duyệt thay đổi ngân sách chiến dịch — Ưu tiên: Nên có — Lý do: buyer tự quyết trong hạn mức ngày; vượt hạn mức TL/AM duyệt theo bậc; mọi thay đổi ghi lý do.

## Phòng Tài chính - Kế toán (chuyên gia finance-expert)
**Yêu cầu chính:**
- Tách bạch tiền nạp khách và doanh thu: tiền nạp ví TKQC là tiền giữ hộ (nợ phải trả); doanh thu chỉ ghi nhận trên phí dịch vụ/markup; sổ phụ ví riêng từng khách.
- Đối soát tự động, đối trừ 3 số: tiền khách nạp ↔ nạp lên nền tảng ↔ chi tiêu thực tế, theo TKQC/khách/nền tảng; chưa có API → Settings credentials + import statement chuẩn hóa.
- Financial Hard Stop "đã khớp tiền" thực thi bằng máy: không nút override, không chấp nhận "chờ duyệt" để cấp phát.
- Immutable audit log append-only (old→new value + lý do) + snapshot tỷ giá tại thời điểm giao dịch.
- P&L realtime bắt buộc gắn nhãn Timesheet Client Billable vs Internal Non-billable ngay tại nguồn — nếu không COGS sai từ nguồn.

**Lo ngại:**
- "Realtime" sẽ bị giới hạn: giờ × Cost/Level + Outsource + Tools được; chi tiêu nền tảng phụ thuộc API/import → phải định nghĩa tần suất từng thành phần.
- Rủi ro tỷ giá đa tiền tệ: lãi/lỗ FX phải snapshot, không làm nhiễu GM dịch vụ.
- Lệch số với phần mềm kế toán hiện hữu [Cần làm rõ]: chạy song song sổ VAS cần đối chiếu định kỳ; điểm nghẽn FIN_L2 cần cơ chế ủy quyền (delegate).

**Đề xuất ưu tiên:** Finance & Đối soát TKQC; Công nợ AR/AP & ngân quỹ (aging, nhắc nợ); Giải ngân & phê duyệt (workflow FIN_L1/L2/CFO theo ngưỡng, SoD, delegate); P&L dự án realtime + dashboard FIN_L2/BOD (drill-down về chứng từ gốc).

**Chính sách đề xuất:**
- Ghi nhận doanh thu & xử lý tiền nạp khách — Ưu tiên: Bắt buộc — Lý do: tiền nạp = tiền giữ hộ; doanh thu khi cung cấp dịch vụ; refund chỉ qua phiếu duyệt + audit log.
- Đa tiền tệ & tỷ giá — Ưu tiên: Bắt buộc — Lý do: sổ gốc VND; snapshot tỷ giá từng giao dịch; chênh lệch FX ghi khoản riêng, không cộng GM.
- Hạn mức chi, giải ngân & SoD — Ưu tiên: Bắt buộc — Lý do: ma trận FIN_L1 → FIN_L2 → CFO/CEO; người tạo ≠ người duyệt ≠ người chi; block vi phạm + log.
- Đối soát công nợ nền tảng — Ưu tiên: Bắt buộc — Lý do: chu kỳ ngày/tuần/tháng có dung sai; FIN_L2 chốt và khóa kỳ (period lock), mở kỳ chỉ CFO duyệt.
- Định mức tính giá & duyệt Gross Margin — Ưu tiên: Nên có — Lý do: bảng giá chuẩn cho Quotation; ngưỡng GM theo tier; chiết khấu vượt ngưỡng cần duyệt + log.

## Phòng Kinh Doanh (chuyên gia sales-expert)
**Yêu cầu chính:**
- Pipeline V6.0 nguyên trạng với hard gate thật sự: Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → Pitching → Quotation → WON; "Không ghi nhận vào PMS = Không tồn tại" là ràng buộc kỹ thuật — hoa hồng/chỉ tiêu/báo cáo chỉ tính deal trong hệ thống.
- AUTO SCORING chuẩn V6.0: K1–K5 knockout → AUTO LOST (K4 cho phép tư vấn trước); K6–K12 flag SM review 4h; CQ trọng số 30/25/20/15/10 → Tier A–E tự động; chấm 2 lần (sơ bộ + qualifiedTier sau Full Brief 8 sections).
- Hai Decision Gate điện tử có ký duyệt: Gate 1 QUALIFIED — SM Go/No-Go (SLA 1 ngày); Gate 2 LEAD — Handoff Package 5 nhóm checklist 100%, SM ký, AM xác nhận (SLA 4h).
- CRM chống trùng lặp đa kênh (Landing/Zalo/Fanpage/Referral/Cold), truy xuất nguồn lead; phát hiện KH "nhảy agency ≥3 lần/12 tháng".
- Quotation–WON có kiểm soát: tính giá theo định mức → duyệt GM → gửi trong 2 ngày; WON cập nhật 24h, tự sinh dự án + xác nhận Capacity AM.

**Lo ngại:**
- Điểm nghẽn ở SM: Gate 1, Gate 2, bypass, duyệt GM dồn qua SM — cần escalation tự động khi quá SLA.
- Thang Tier nghịch trực giác (Tier A = auto LOST, Tier E = tốt nhất) — cần khóa logic bằng dữ liệu test + audit log mọi bypass.
- 12/12 chính sách "Chưa có": hoa hồng L1–L5 chưa có sẽ gây tranh chấp "deal này credit cho ai".

**Đề xuất ưu tiên:** CRM & Lead Pipeline V6.0 (anti-duplicate, auto scoring, hard gate); Quotation & Deal Desk (version control, giới hạn vòng sửa ≤2 vs ≤4 theo tier); Handoff & Onboarding Bridge (ký 3 bên Sales/SM/AM); Commission & Quota L1–L5.

**Chính sách đề xuất:**
- Phân loại KH theo Tier A–E — Ưu tiên: Bắt buộc — Lý do: tiêu chí định tính + định lượng; hệ quả vận hành theo tier (AM 8-12 trang vs Planner 15-25 trang); rà soát quý theo win rate.
- Bảng giá & ma trận chiết khấu — Ưu tiên: Bắt buộc — Lý do: NVKD ≤5%, TPKD 10–15%, GDKD >15%, vượt lên BOD; hiệu lực báo giá 30–60 ngày; GM tối thiểu theo nhóm dịch vụ.
- Hoa hồng Sales L1–L5 — Ưu tiên: Bắt buộc — Lý do: credit theo thanh toán thực nhận + clawback khi hủy/nợ xấu; chỉ deal ghi nhận PMS trước Gate 2 mới hưởng.
- Chỉ tiêu doanh số (Quota) theo cấp — Ưu tiên: Nên có — Lý do: pipeline coverage ≥3x, attainment tự động.
- Hợp đồng, LOI & Brand Safety — Ưu tiên: Bắt buộc — Lý do: mẫu chuẩn; điều khoản phản đòn bẩy KPI cứng; hard stop lưu bằng chứng LOST chủ động.

## Phòng Vận hành — Strategic Planning & Campaign (chuyên gia marketing-expert)
**Yêu cầu chính:**
- Số hóa trọn vẹn Lifecycle V6.0 thành stage-gate cứng trên PMS: Raw Data → Auto Scoring → Qualified → Lead → Evaluation (Brand Safety 7 + Weighted ≥3.5) → Proposal → WON → Deploy; entry/done criteria machine-checkable.
- Capacity L1-L5 là ràng buộc khi phân công: mọi task gán OPS qua capacity check, cảnh báo đỏ >100% định mức giờ/tuần; workload realtime.
- P&L realtime từng dự án theo công thức đã chốt: timesheet gắn nhãn Client Billable/Internal Non-billable ngay tại nguồn nhập.
- Handoff Sales→Vận hành là giao dịch điện tử có nghiệm thu: Handoff Package 5 nhóm, SM ký, AM xác nhận SLA 4h.
- Client Portal minh bạch theo tần suất cam kết (Daily/Weekly/Monthly).

**Lo ngại:**
- Tài liệu 01 dừng ở tiêu đề Giai đoạn 3 Deploy Phase — chưa có chuẩn khâu thực thi (campaign, deliverable, nghiệm thu, retainer) — nơi phát sinh phần lớn giờ billable.
- Rủi ro "quy trình trên giấy": nếu ERP thiếu SLA timer, escalation, đếm vòng sửa tự động sẽ tạo thêm việc.
- Định mức nền chưa có (cost-per-hour L1-L5, giờ/tuần, khung SLA theo Tier) — không chốt con số thì P&L/KPI vẫn cảm tính.

**Đề xuất ưu tiên:** Proposal & Planning Workspace (stage-gate V6.0, template theo Tier, đếm vòng review); Campaign & Deliverable Management (WBS, lịch nội dung, duyệt creative); Capacity & Timesheet Engine; Client Portal + SLA & Alert Center.

**Chính sách đề xuất:**
- Stage-Gate & Điều kiện chuyển pha — Ưu tiên: Bắt buộc — Lý do: entry/done criteria machine-checkable; cấm chuyển pha thiếu điều kiện; SLA duyệt + escalation.
- SLA khách hàng — Ưu tiên: Bắt buộc — Lý do: khung SLA theo Tier; Reporting Frequency chuẩn hóa đo được; cảnh báo đỏ breach TL+AM; % SLA đạt là KPI phòng Vận hành.
- Capacity & Timesheet — Ưu tiên: Bắt buộc — Lý do: định mức giờ/tuần L1-L5; chặn >100%; nhãn bắt buộc; duyệt tuần; đầu vào duy nhất cho P&L và KPI.
- KPI & Hiệu suất — Ưu tiên: Bắt buộc — Lý do: 3 trụ cột tự tổng hợp; không nhập điểm tay; chu kỳ review minh bạch.
- Brand Safety & Kỷ luật Proposal — Ưu tiên: Nên có — Lý do: 7 tiêu chí hard stop; Weighted ≥3.5 (borderline 3.0-3.49 thẩm định 4h); giới hạn vòng sửa theo Tier; Rehearsal trước gửi.

## CSKH & Client Portal (chuyên gia customer-expert)
**Yêu cầu chính:**
- Client Portal realtime (Web + Mobile) số 1: khách tự xem số dư ví TKQC, chi tiêu hàng ngày, tiến độ nghiệm thu; đa ngôn ngữ, đa múi giờ, đa tenant; "single source of truth" thay Zalo/ảnh chụp.
- SLA Engine tự động: đếm giờ theo tier × priority; pre-alert 80%; báo đỏ breach tới AM + TL.
- Ticket/Complaint hub hợp nhất: mọi yêu cầu portal/email/Zalo về một queue, gắn tier, SLA timer, escalation, CSAT sau đóng.
- Onboarding có milestone kiểm soát: Handoff Package 5 nhóm (AM xác nhận SLA 4h), milestone Day 1/7/14/30, gate "khách kích hoạt Client Portal thành công".
- AM Dashboard tổng hợp portfolio (open tickets, SLA risk, số dư ví, tiến độ) — đầu mối duy nhất cho OPS_AM.

**Lo ngại:**
- Minh bạch tài chính vs lộ biên lợi nhuận: cần ranh giới dữ liệu portal rõ ràng + audit log mọi điều chỉnh số dư.
- Cam kết SLA khi 12/12 chính sách "Chưa có": phải định nghĩa "SLA clock" trước (múi giờ, giờ làm việc, luật tạm dừng) — khách đa quốc gia phức tạp.
- "Thời gian thực" phụ thuộc API: độ trễ, rate limit, API fail — cần công bố độ trễ chấp nhận được, tránh portal thành nguồn khiếu nại mới.

**Đề xuất ưu tiên:** Client Portal (Web + Mobile); Ticket & Complaint Management (queue hợp nhất); SLA & Notification Engine (ma trận tier×priority, báo cáo compliance); Onboarding & Customer Success (milestone tracker, health score).

**Chính sách đề xuất:**
- SLA khách hàng — Ưu tiên: Bắt buộc — Lý do: ma trận tier×priority First Response/Resolution; định nghĩa SLA clock; pre-alert 80%; override theo cấp + audit log.
- Phân loại tier khách hàng CS — Ưu tiên: Bắt buộc — Lý do: chuyển tier Sales → CS theo giá trị HĐ, số TK, churn risk; tier cao + Critical auto-escalate.
- Minh bạch dữ liệu Client Portal — Ưu tiên: Bắt buộc — Lý do: khách thấy số dư, chi tiêu daily, tiến độ, ticket; không thấy giá vốn, chiết khấu, P&L, dữ liệu KH khác; disclaimer độ trễ.
- Cảnh báo ví & Financial Hard Stop — Ưu tiên: Bắt buộc — Lý do: ngưỡng theo mức chi tiêu daily; cảnh báo đỏ AM + khách (portal/push/email); cam kết thời gian xử lý top-up.
- CSAT/NPS & xử lý khiếu nại — Ưu tiên: Nên có — Lý do: CSAT tự động sau đóng ticket; detractor liên hệ lại 48h; khiếu nại nghiêm trọng leo thang BOD.

## Phòng Hành chính Nhân sự (chuyên gia hr-expert)
**Yêu cầu chính:**
- Một nguồn sự thật nhân sự theo Level L1–L5: hồ sơ là gốc (Level hiện hành, mã vai, hợp đồng, trạng thái) để RBAC, hoa hồng, P&L, KPI đọc chung một chuẩn.
- Cost per Hour theo Level version hóa theo thời gian (từ ngày–đến ngày): đổi rate không làm sai chi phí quá khứ của P&L.
- Timesheet gắn nhãn bắt buộc ngay lúc ghi: Client Billable vs Internal Non-billable không sửa sau; chặn ghi giờ nội bộ vào dự án khách.
- Capacity kiểm tra TRƯỚC khi gán: Gate 2 cần "xác nhận Capacity trống" + phân bổ AM SLA 4h; >100% chặn gán mới hoặc escalate.
- KPI tự động nhưng tách bạch nguồn số liệu: 3 trụ cột từ timesheet + task SLA; thành phần chấm tay khai báo trọng số riêng.

**Lo ngại:**
- Kiêm nhiệm nhiều vai (CFO kiêm CTO, Planner kiêm TP OPS): RBAC 1 người – nhiều vai + tách xung đột phê duyệt (người ghi timesheet không tự duyệt).
- HR_L1 mỏng + 12/12 chính sách "Chưa có": cần self-service + duyệt phân cấp tránh tê liệt một đầu mối.
- Sốc chuyển KPI cảm tính sang số liệu + alert fatigue: cần chính sách OT/buffer, tránh timesheet "làm đẹp".

**Đề xuất ưu tiên:** HR Core & Hành chính (hồ sơ, HĐLĐ cảnh báo hạn, chấm công, nghỉ phép); Timesheet & Capacity Management (dashboard tải theo Level, cảnh báo burnout); KPI & Performance Engine (PIP, calibration HR_L2); Talent (requisition duyệt headcount, onboarding, lộ trình thăng Level).

**Chính sách đề xuất:**
- Định mức giờ làm & Capacity theo Level — Ưu tiên: Bắt buộc — Lý do: ngưỡng vàng 90% – đỏ 100%; ai duyệt gán vượt; OT + tỷ lệ billable mục tiêu theo bậc.
- Ghi nhận Timesheet & phân loại dự án kép — Ưu tiên: Bắt buộc — Lý do: ghi hằng ngày, chốt tuần; TL duyệt (cấm tự duyệt); giờ chưa duyệt không vào P&L; sửa sai qua audit log.
- KPI 3 trụ cột & PIP — Ưu tiên: Bắt buộc — Lý do: trọng số theo bậc (L1-L2 nặng Output, L4-L5 nặng Target/SLA); review quý; PIP 30-60-90; calibration HR_L2 trước khi trình BOD.
- Cost Rate Card theo Level — Ưu tiên: Bắt buộc — Lý do: HR_L2 – FIN_L2 thẩm định, BOD duyệt thay đổi; hiệu lực theo thời gian; lương mã hóa Confidential chỉ HR_L2+ xem.
- Bảo mật dữ liệu nhân sự (PII) — Ưu tiên: Nên có — Lý do: phân loại dữ liệu, ma trận truy cập, audit log lương/HĐ; NĐ 13/2023 + Bộ luật Lao động (48h/tuần, 12 ngày phép, BHXH).

## Ban Điều hành — Data/BI (chuyên gia data-expert)
**Yêu cầu chính:**
- Pipeline ingestion đa nền tảng chịu lỗi: kéo chi tiêu hàng giờ Meta/Google/TikTok (sau đó Bing/X/Pinterest/Yandex) qua adapter riêng; lưu raw payload; retry/backoff; chế độ degraded (nhập tay gắn nhãn "manual"); backfill khi được cấp API.
- Kho dữ liệu star schema một nguồn sự thật: fact_timesheet (nhãn bắt buộc), fact_ad_spend (TK × chiến dịch × giờ), fact_revenue/outsource/tools; conformed dimensions (Khách, Dự án, TKQC, Nền tảng, Chiến dịch, Nhân sự cost rate SCD2); P&L realtime tính trực tiếp từ fact.
- Dashboard BOD (Web + Mobile): P&L → drill-down khách → nền tảng → chiến dịch; trung tâm cảnh báo (ngưỡng số dư, die, SLA breach, vượt hạn mức); chỉ báo "dữ liệu cập nhật lúc".
- Metric catalog chuẩn hóa: ROAS, GM, P&L, On-time Delivery định nghĩa duy nhất, có owner, dùng chung nội bộ + portal.
- Immutable Audit Log: append-only + before/after + hash-chain; BOD tra cứu trực tiếp.

**Lo ngại:**
- Chưa có quyền API + quy mô 2.600+ TKQC: rate limit, token hết hạn; chỉ trông API → P&L chết khi connector lỗi.
- P&L realtime phụ thuộc timesheet nhập đúng/kịp — rủi ro chất lượng dữ liệu số 1.
- 12/12 chính sách "Chưa có": chấm dứt "mỗi người một bảng tính" ngay từ đầu; cost rate/lương nhạy cảm nhưng P&L bắt buộc cần.

**Đề xuất ưu tiên:** Data Integration Hub (vault mã hóa, job đồng bộ hàng giờ, queue retry, backfill); Analytics Core (star schema, metric catalog, data quality test tự động); BOD Dashboard & Reporting (alert center, export, mobile-responsive); Audit Log & Governance Service (event store, tra cứu cho BOD).

**Chính sách đề xuất:**
- P1 Phân quyền & phân loại dữ liệu (RBAC theo tier) — Ưu tiên: Bắt buộc — Lý do: 4 tier (Công khai/Nội bộ/Mật/Restricted); cost rate, lương = Restricted chỉ CEO/CFO; log mọi truy cập tài chính.
- P2 Quản trị định nghĩa chỉ số — Ưu tiên: Bắt buộc — Lý do: metric khai báo (tên, công thức, nguồn, owner); đổi định nghĩa CFO duyệt + lịch sử hiệu lực.
- P3 Chất lượng & độ tươi dữ liệu (Freshness SLA) — Ưu tiên: Bắt buộc — Lý do: chi tiêu QC ≤1 giờ; timesheet chốt hằng ngày; test tự động đối soát ±0,1%; dashboard hiển thị freshness.
- P4 Bảo mật credentials & kết nối API — Ưu tiên: Bắt buộc — Lý do: vault mã hóa chỉ CTO/Super Admin; rotate token; log mọi lần gọi; degraded mode ghi nguồn manual.
- P5 Lưu trữ & kiểm soát audit log — Ưu tiên: Bắt buộc — Lý do: append-only + hash-chain; retention ≥5 năm sự kiện tiền; backup mã hóa + test phục hồi; việc xem audit cũng bị log.

## Pháp lý (chuyên gia legal-expert)
**Yêu cầu chính (quy định áp dụng):**
- Luật Quảng cáo 2012 (+ sửa đổi): SP hạn chế cần giấy phép — ERP lưu hồ sơ pháp lý SP, gắn Knockout K1.
- NĐ 13/2023 (dữ liệu cá nhân): cơ sở pháp lý xử lý, phân quyền, bảo mật, thông báo vi phạm 72h, kiểm soát retention.
- TT 78/2021 + NĐ 123/2020 (HĐĐT): xuất/kết nối hóa đơn điện tử mã cơ quan thuế, XML, lưu đúng quy định.
- Luật ATTT 2018 / NĐ 53/2022: lưu dữ liệu tại VN (khi áp dụng), kiểm soát Portal truy cập từ nước ngoài; Luật Kế toán 2015: HĐ + chứng từ đối soát lưu ≥10 năm, retention policy cấu hình được.
- GDPR + CCPA (khách EU/US): DPA, controller/processor, DSAR; Luật GDTĐT 2023 / NĐ 91/2022: e-sign HĐ, LOI; Meta/Google/TikTok/Yandex Ads Policy: Business Verification, chống resale TKQC.

**Lo ngại:**
- Trách nhiệm lan truyền từ SP khách (K1/K3 + Brand Safety): cần bằng chứng due diligence — audit trail checklist Brand Safety.
- Chồng lấn NĐ 13 và GDPR vai trò kép (vừa controller vừa processor): phân định trong hợp đồng, tránh phạt GDPR tới 4% doanh thu.
- Dữ liệu ví TKQC + credentials API nhạy cảm: immutable audit log + hard stop là nền đúng, cần nâng chuẩn pháp lý (log 10 năm).

**Đề xuất ưu tiên:** Workflow duyệt hợp đồng (template chuẩn → legal review → duyệt theo ma trận giá trị → e-sign → archive + alert hết hạn; version control draft → Final → Signed lock); Checklist Brand Safety 7 tiêu chí dạng form chặn cứng trong Evaluation (fail 1 → LOST chủ động), gắn K1/K3, tự lưu evidence; Retention schedule (HĐ/chứng từ thuế 10 năm, litigation 10 năm sau đóng, disposal qua phê duyệt + log hủy).

**Chính sách đề xuất:**
- HĐ/LOI & NDA chuẩn hóa — Ưu tiên: Bắt buộc — Lý do: IN/OUT of scope rõ; nạp trước 100% NSQC (đồng bộ K4); miễn trừ khi nền tảng khóa TK; NDA mutual trước Full Brief 8 sections.
- Brand Safety clause — Ưu tiên: Bắt buộc — Lý do: khách cam kết SP hợp pháp + giấy phép; BC quyền từ chối vận hành nếu vi phạm 1/7 tiêu chí.
- Giới hạn trách nhiệm & KPI — Ưu tiên: Bắt buộc — Lý do: không cam kết KPI cứng (K2); cap trách nhiệm = phí dịch vụ đã nhận; miễn trừ thuật toán nền tảng.
- Bảo mật Client Portal & dữ liệu khách — Ưu tiên: Bắt buộc — Lý do: 2FA/OTP, tenant isolation, session timeout, log IP; ví read-only, watermark, data minimization, quyền xóa/ẩn danh khi chấm dứt HĐ.
- E-sign & retention schedule — Ưu tiên: Nên có — Lý do: e-sign theo Luật GDTĐT 2023; lưu trữ theo retention schedule, disposal có phê duyệt + log.

## Tuân thủ/Kiểm toán nội bộ (chuyên gia compliance-expert)
**Yêu cầu chính:**
- Immutable Audit Log (TÍN): mọi giao dịch tiền + hợp đồng append-only who/when/what/before-after/reason-code; kể cả Super Admin không xóa/sửa; lưu ≥10 năm theo chuẩn kế toán VN.
- Segregation of Duties 3 lớp: đề xuất nạp (AM/Ops) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ; cảnh báo CFO kiêm CTO + Super Admin = concentration of risk → compensating control (CEO duyệt vượt ngưỡng, access review định kỳ).
- Financial Hard Stop tự động (TÂM): chặn cứng cấp phát TKQC khi chưa "Đã khớp tiền"; cấm bypass; exception có duyệt riêng + log.
- Approval matrix theo cấp bậc + ngưỡng giá trị: dual approval bắt buộc cho điều chỉnh số dư, đổi tỷ giá thủ công, hoàn tiền, chiết khấu ngoài biểu.
- Reconciliation 3 chiều: ví nội bộ ↔ chi tiêu API nền tảng ↔ tiền khách đã thanh toán; chênh lệch có reason code, review trước khi close.

**Lo ngại:**
- Rửa tiền qua ví TKQC: 2.600+ TK, nạp/rút đa kênh quốc tế, hoàn tiền có thể về TK bên thứ ba; K2/K4 chỉ lọc tầng lead → cần KYC + monitoring giao dịch bất thường.
- PCI-DSS nếu Portal xử lý thẻ: khuyến nghị hosted payment page/redirect của PSP (SAQ-A) để thu hẹp scope từ ngày đầu.
- Truy cập credentials API + gian lận nội bộ: vault mã hóa, MFA, least privilege, xoay token, session log.

**Đề xuất ưu tiên:** Immutable Audit Log Service (nền móng trước mọi module tiền/hợp đồng); Wallet & Balance Management + Financial Hard Stop; Reconciliation Engine (hourly/daily, cảnh báo lệch + die); RBAC + Approval Workflow Engine (ma trận ngưỡng, dual approval).

**Chính sách đề xuất:**
- Kiểm soát ví & giao dịch tiền TKQC — Ưu tiên: Bắt buộc — Lý do: SoD 4 vai; hard stop khớp tiền; dual approval điều chỉnh dư/tỷ giá thủ công/hoàn tiền.
- AML/KYC — Ưu tiên: Bắt buộc — Lý do: định danh pháp nhân khách trước cấp TK; hoàn tiền về đúng TK nguồn nạp; ngưỡng cảnh báo giao dịch bất thường (nạp gấp, tách nhỏ).
- Quản lý truy cập & Credentials — Ưu tiên: Bắt buộc — Lý do: vault mã hóa token; MFA toàn bộ tài khoản quản trị; quarterly access review + thu hồi khi nghỉ.
- Dữ liệu cá nhân (NĐ 13/2023 + GDPR) — Ưu tiên: Bắt buộc — Lý do: inventory dữ liệu Portal, mục đích xử lý, retention; breach notification 72h; DSR tracking.
- Bảo lưu hồ sơ & Audit Log — Ưu tiên: Nên có — Lý do: tài chính 10 năm, audit log ≥7 năm, storage WORM.

## Phòng Vận hành — TikTok Shop (chuyên gia ecommerce-expert — vai phụ)
**Yêu cầu chính:**
- Tích hợp TikTok Business API theo từng khách hàng: kéo đơn hàng, GMV, settlement, chi tiêu TikTok Ads, shop health theo giờ.
- Tách bạch GMV khách khỏi P&L agency: GMV/đơn/settlement là chỉ số của khách; P&L dự án TikTok Shop chỉ tính phí dịch vụ + giờ billable + tools.
- Client Portal mở rộng TikTok Shop: khách xem realtime GMV, đơn, settlement, chi tiêu ads, tiến độ task.
- Giám sát shop health & SLA dạng cảnh báo: fulfillment SLA, tỷ lệ hoàn/hủy, violation points — ERP cảnh báo, không xử lý logistics.

**Lo ngại:**
- Trôi phạm vi sang OMS/WMS đầy đủ — ERP agency chỉ ở tầng "quản lý dự án + giám sát qua API".
- Sở hữu dữ liệu và dòng tiền: shop, PII người mua cuối, settlement thuộc khách; agency chỉ được ủy quyền OAuth, có thể bị thu hồi.

**Đề xuất ưu tiên:** Tích hợp TikTok Business API (Shop + Ads) per-client, feed cho Đối soát + P&L; Client Portal TikTok Shop (dashboard realtime theo shop); Giám sát vận hành Shop theo SLA (gắn task ops với timesheet/capacity). TikTok Shop Lifecycle 3 Gate nối vào Lifecycle V6.0: Verification → Go-live (SM ký) → Đối soát định kỳ (settlement vs đơn vs ads hằng ngày, báo tháng qua Portal).

**Chính sách đề xuất:**
- Truy cập & Sở hữu dữ liệu Shop khách — Ưu tiên: CAO (≈ Bắt buộc) — Lý do: OAuth theo khách, log mọi truy cập, thu hồi khi hết HĐ; không lưu PII thô, mask SĐT/địa chỉ; isolation giữa shop khách.
- Tách bạch GMV vs doanh thu agency — Ưu tiên: CAO (≈ Bắt buộc) — Lý do: GMV/settlement chỉ tham chiếu; doanh thu agency = phí dịch vụ + phí ads thu hộ; audit log mọi điều chỉnh.
- Thẩm định Shop trước vận hành — Ưu tiên: TRUNG BÌNH (≈ Nên có) — Lý do: checklist chủ shop + giấy phép ngành hàng; không nhận logistics trừ khi HĐ quy định; baseline KPI, không cam kết KPI cứng.

---
## Phân Tích Tuân Thủ Pháp Lý
> Bởi legal-expert + compliance-expert

**(1) Quy định áp dụng.** Luật Quảng cáo 2012 (+ sửa đổi): SP hạn chế cần giấy phép, ERP lưu hồ sơ pháp lý SP gắn Knockout K1. NĐ 13/2023/NĐ-CP (dữ liệu cá nhân): cơ sở pháp lý xử lý, phân quyền, thông báo vi phạm 72h, kiểm soát retention. TT 78/2021/TT-BTC + NĐ 123/2020 (HĐĐT): xuất/kết nối hóa đơn điện tử mã cơ quan thuế, XML, lưu đúng quy định. Luật ATTT 2018 / NĐ 53/2022: lưu dữ liệu tại VN trong trường hợp áp dụng, kiểm soát Portal truy cập từ nước ngoài. Luật Kế toán 2015 (+ Luật Thương mại): HĐ, chứng từ đối soát lưu ≥10 năm, retention policy cấu hình được. GDPR + CCPA (khách EU/US): DPA, phân vai controller/processor, DSAR, transfer mechanism. Luật GDTĐT 2023 / NĐ 91/2022: chữ ký số/e-sign HĐ, LOI. Meta/Google/TikTok/Yandex Ads Policy: Business Verification, chống gian lận và resale TKQC, theo dõi trạng thái tuân thủ từng TK.

**(2) Ba lo ngại pháp lý chính.** Thứ nhất, trách nhiệm lan truyền từ sản phẩm/dịch vụ quảng cáo của khách (K1/K3 + Brand Safety): BC cần bằng chứng due diligence — audit trail checklist Brand Safety 7 tiêu chí — để chứng minh đã thẩm định trước khi vận hành. Thứ hai, vai trò kép controller/processor theo NĐ 13/2023 và GDPR: phải phân định trách nhiệm trong hợp đồng với khách, tránh rủi ro phạt GDPR tới 4% doanh thu. Thứ ba, dữ liệu ví TKQC và credentials API là dữ liệu nhạy cảm bậc nhất: immutable audit log + Financial Hard Stop là nền đúng nhưng cần nâng chuẩn pháp lý (log 10 năm), kèm rủi ro AML qua hoàn tiền đa kênh quốc tế.

**(3) Yêu cầu cụ thể với BCERP.**
- Immutable audit log: append-only, old→new value + reason-code, hash-chain; kể cả Super Admin không xóa/sửa; retention ≥10 năm cho sự kiện tiền và hợp đồng; việc xem log cũng bị log.
- SoD + cảnh báo kiêm nhiệm: tách 4 vai (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ); CFO kiêm CTO + Super Admin là concentration of risk → compensating control: CEO duyệt giao dịch vượt ngưỡng, quarterly access review; dual approval cho điều chỉnh số dư, đổi tỷ giá thủ công, hoàn tiền.
- AML/KYC: định danh pháp nhân khách trước cấp TK; hoàn tiền về đúng TK nguồn nạp; ngưỡng cảnh báo giao dịch bất thường (nạp gấp, tách nhỏ, nguồn rủi ro cao).
- PCI-DSS: dùng hosted payment page/redirect của PSP (mức SAQ-A) để thu hẹp scope từ ngày đầu; credentials API trong vault mã hóa, MFA, rotate token, session log.
- Client Portal: tenant isolation + 2FA/OTP, session timeout, log IP/khu vực; dữ liệu ví read-only, giới hạn download/print (watermark); data minimization, quyền xóa/ẩn danh khi chấm dứt HĐ; breach notification 72h + DSR tracking.
- Retention & hợp đồng: HĐ 10 năm, chứng từ thuế 10 năm, litigation 10 năm sau đóng hồ sơ; disposal qua phê duyệt + log hủy; contract lifecycle e-sign theo Luật GDTĐT 2023.

**(4) Ghi chú.** Đây là phân tích khởi điểm từ góc độ chuyên gia nội bộ — cần luật sư VN chuyên dữ liệu/công nghệ và auditor độc lập xác nhận trước khi áp dụng làm bắt buộc thiết kế. Các điểm chưa xác nhận: mô hình thanh toán Portal (thẻ trực tiếp hay chuyển khoản), chính sách hoàn tiền, phương án phân tách quyền CFO/CTO kiêm nhiệm.
