# Raw Expert Outputs — BCERP Brainstorm Phase 3 (2026-09-11)

> 10 expert outputs, thu theo đúng thứ tự spawn. File làm input cho BA tổng hợp (Step 3.3) — giữ nguyên văn làm audit trail.

---

## E1. paid-media-expert — Head of Paid Media (OPS_ADS)

### 1. Yêu cầu quan trọng nhất
1. **Ad Account Command Center — một màn hình cho 2.600+ TKQC:** hệ thống phải tự sync (theo giờ) số dư, chi tiêu ngày, spend limit và trạng thái từng TK qua API 7 nền tảng; media buyer không còn login rải rác hay chụp màn hình. Mỗi TK phải được map chặt vào 1 khách hàng + 1 owner phụ trách.
2. **Cảnh báo realtime 2 loại rủi ro chết người:** (a) số dư chạm ngưỡng tối thiểu — đứt chi tiêu 1 ngày là mất money của khách và hỏng learning phase của thuật toán; (b) dấu hiệu bất thường — spend spike, checkpoint, die account. Cảnh báo phải đẩy đúng người (owner + AM), có SLA phản ứng, không chỉ nằm trong dashboard.
3. **Financial Hard Stop ở cấp hệ thống:** không thể gán/cấp phát TKQC cho khách nếu kế toán chưa xác nhận "đã khớp tiền". Với số tiền chạy qua 2.600 TK mỗi ngày, chặn bằng quy trình mềm là không đủ — phải chặn cứng trong code, kèm immutable audit log mọi lệnh nạp/rút/điều chỉnh số dư/đổi tỷ giá.
4. **Campaign change log tự động:** khi ROAS tụt, phải trả lời được "ai sửa budget/bid/targeting lúc nào, lý do gì" — mọi thay đổi ghi log bất biến (chuẩn audit trail 3 năm của ngành).
5. **View tổng hợp cross-platform theo khách hàng:** 1 khách chạy 5–7 nền tảng → cần total spend, hiệu suất, pacing theo chiều Khách → Nền tảng → Chiến dịch, là nền cho Client Portal và P&L realtime.

### 2. Lo ngại chính
1. **Chưa có quyền API developer nền tảng** — cần lộ trình 2 lớp: đăng ký Business Verification song song với cơ chế nhập tay có cấu trúc (validate, version, ai nhập) — tuyệt đối không quay lại ảnh chụp màn hình. 2.600 TK sẽ đụng rate limit API → thiết kế batch/queue ngay từ đầu.
2. **Data migration là bão lệnh:** 2.600 TK phải import chuẩn 100% (platform, currency, spend limit, owner, khách, số dư mở sổ). Sai map 1 TK là sai cả chuỗi đối soát. Cần quy trình import có kiểm chứng chéo.
3. **Die account là rủi ro tồn kho tiền thật:** số dư trong TK bị khóa là tiền của khách. Cần trạng thái + evidence + lịch sử lưu có hệ thống.

### 3. Đề xuất modules ưu tiên
1. **Ad Account Command Center** — registry trung tâm: trạng thái, số dư, spend limit, owner, cảnh báo ngưỡng, lịch sử từng TK.
2. **Integration Gateway + Settings** — quản lý credentials từng nền tảng tự cấu hình, sync scheduler, fallback nhập tay có kiểm soát.
3. **Wallet & Đối soát** — lệnh nạp/rút, khớp tiền FIN, đối soát API vs sổ nội bộ, immutable log (bắt tay FIN_L1).
4. **Client Portal** — khách tự xem số dư, chi tiêu realtime, trạng thái nghiệm thu.

### 4. Chính sách đề xuất
1. **Chính sách Cấp phát & Thu hồi TKQC — Bắt buộc**: chỉ cấp TK khi FIN_L1 xác nhận "đã khớp tiền" (hard stop); 1 owner + 1 backup, không chia sẻ login; thu hồi truy cập trong 24h khi nghỉ/chuyển; phân quyền edit/view-only/billing/admin.
2. **Chính sách Ngưỡng số dư & Xử lý die account — Bắt buộc**: ngưỡng cảnh báo mặc định theo platform (đủ chi tiêu ≥3 ngày tới); SLA phản ứng cảnh báo đỏ 2h làm việc; evidence die account lưu tại thời điểm; escalation owner → TL → AM; phương án TK dự phòng.
3. **Chính sách Nạp tiền & Đối soát hằng ngày — Bắt buộc**: mọi top-up/refund qua lệnh hệ thống, cấm miệng; đối soát tự động API vs sổ; chênh lệch vượt dung sai phải giải trình trước khi chốt ngày; tỷ giá theo bảng công bố nội bộ, log bất biến.
4. **Chính sách Naming & UTM Convention — Nên có**: chuẩn tên campaign/adset/ads + UTM; campaign bắt buộc gắn dự án trước khi bật, không gắn = không tồn tại.
5. **Chính sách phê duyệt thay đổi ngân sách chiến dịch — Nên có**: buyer tự quyết trong hạn mức hằng ngày; vượt hạn mức TL/AM duyệt theo bậc; mọi thay đổi ghi lý do.

### 5. Quy trình kiểm soát
1. **Vòng đời TKQC** (Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng) — hard gate ở khớp tiền.
2. **Đối soát hằng ngày** (sync API theo giờ → so khớp sổ → flag chênh lệch → FIN xử lý → chốt số cuối ngày).
3. **Xử lý sự cố TKQC** (phát hiện die/cạn dư → evidence → thông báo AM + khách → recovery/chuyển TK dự phòng → ghi nguyên nhân).

---

## E2. finance-expert — Kế toán trưởng (FIN_L2)

### 1. Yêu cầu quan trọng nhất
1. **Tách bạch tiền nạp khách và doanh thu dịch vụ**: tiền khách nạp vào ví TKQC là **tiền giữ hộ (nợ phải trả)**, không phải doanh thu. Doanh thu chỉ ghi nhận trên phí dịch vụ/markup. Sổ phụ ví riêng từng khách, đối chiếu được từng đồng.
2. **Đối soát nạp/rút TKQC tự động, đối trừ 3 số**: tiền khách nạp ↔ tiền nạp lên nền tảng ↔ chi tiêu thực tế, theo từng TKQC/khách/nền tảng. Chưa có API → module Settings credentials + import statement chuẩn hóa, trạng thái "đã đối soát/chênh lệch".
3. **Financial Hard Stop "đã khớp tiền" thực thi bằng máy**: chặn cứng cấp phát/nạp TKQC khi FIN_L1 chưa xác nhận — không nút override, không chấp nhận "chờ duyệt" để cấp phát.
4. **Immutable audit log + snapshot tỷ giá**: mọi biến động tiền ghi append-only, old→new value + lý do; tỷ giá chốt tại thời điểm giao dịch.
5. **P&L realtime** bắt buộc gắn phân loại Timesheet Client Billable vs Internal Non-billable — nếu không COGS sai từ nguồn.

### 2. Lo ngại chính
1. **"Realtime" sẽ bị giới hạn**: giờ × Cost/Level + Outsource + Tools có thể realtime; chi tiêu nền tảng phụ thuộc API/import — cần định nghĩa tần suất từng thành phần.
2. **Rủi ro tỷ giá đa tiền tệ**: nạp USD, chi tiêu liên tục — lãi/lỗ FX phải snapshot, không làm nhiễu GM.
3. **Lệch số với phần mềm kế toán hiện hữu ([Cần làm rõ])**: BCERP chạy song song sổ VAS — cần đối chiếu/đồng bộ định kỳ; điểm nghẽn phê duyệt FIN_L2 cần cơ chế ủy quyền.

### 3. Đề xuất modules ưu tiên
1. **Finance & Đối soát TKQC** — ví khách, nạp/rút/refund, đối trừ nền tảng, tỷ giá, hard stop khớp tiền.
2. **Công nợ AR/AP & ngân quỹ** — công nợ khách, công nợ nền tảng, aging, nhắc nợ, thanh toán.
3. **Giải ngân & phê duyệt** — workflow FIN_L1/L2/CFO theo ngưỡng, SoD, delegate khi vắng.
4. **P&L dự án realtime + dashboard FIN_L2/BOD** — drill-down từ biên lợi nhuận về chứng từ gốc.

### 4. Chính sách đề xuất
1. **Ghi nhận doanh thu & xử lý tiền nạp khách — Bắt buộc**: tiền nạp = tiền giữ hộ; doanh thu khi cung cấp dịch vụ; refund/điều chỉnh chỉ qua phiếu duyệt + audit log.
2. **Đa tiền tệ & tỷ giá — Bắt buộc**: sổ gốc VND; snapshot tỷ giá từng giao dịch; chênh lệch FX ghi khoản riêng, không cộng GM dịch vụ.
3. **Hạn mức chi, phê duyệt giải ngân & SoD — Bắt buộc**: ma trận ngưỡng FIN_L1 → FIN_L2 → CFO/CEO; người tạo ≠ người duyệt ≠ người chi; block vi phạm SoD + log.
4. **Đối soát công nợ nền tảng — Bắt buộc**: chu kỳ ngày/tuần/tháng, dung sai sai lệch, quy trình discrepancy, FIN_L2 chốt + khóa kỳ (period lock).
5. **Định mức tính giá & duyệt Gross Margin — Nên có**: bảng định mức giá chuẩn cho Quotation; ngưỡng GM duyệt theo tier; chiết khấu vượt ngưỡng cần duyệt + log.

### 5. Quy trình kiểm soát
1. **"Khớp tiền → Cấp phát"**: khách nạp → đối chiếu sao kê ngân hàng → FIN_L1 xác nhận → hệ thống mở khóa cấp phát; timestamp lưu vĩnh viễn.
2. **Đối soát 3 số định kỳ + chốt tháng**: ngân hàng ↔ ví khách ↔ nền tảng; cuối tháng FIN_L2 chốt công nợ, khóa kỳ — mở kỳ chỉ CFO duyệt.
3. **Kiểm soát cảnh báo số dư**: cảnh báo đỏ khi chạm ngưỡng tối thiểu/die → gắn quy trình xin nạp thêm + khóa chi khi dưới ngưỡng.

---

## E3. sales-expert — GDKD (SALES_L5)

### 1. Yêu cầu quan trọng nhất
1. **Pipeline V6.0 số hóa nguyên trạng với Hard Gate thật sự:** stage cứng Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → Pitching → Quotation → WON; "Không ghi nhận vào PMS = Không tồn tại" thành ràng buộc kỹ thuật — hoa hồng/chỉ tiêu/báo cáo chỉ tính deal trong hệ thống.
2. **AUTO SCORING engine đúng chuẩn V6.0:** K1–K5 knockout → AUTO LOST (K4 cho phép tư vấn trước); K6–K12 → flag SM review 4h; CQ 5 tiêu chí trọng số 30/25/20/15/10 → Tier A–E tự động; chấm 2 lần (sơ bộ + qualifiedTier sau Full Brief 8 sections).
3. **Hai Decision Gate điện tử có ký duyệt:** Gate 1 QUALIFIED — SM ký Go/No-Go (SLA 1 ngày); Gate 2 LEAD — Handoff Package 5 nhóm checklist 100%, SM ký, AM xác nhận (SLA 4h).
4. **CRM chống trùng lặp đa kênh:** anti-duplicate trước khi tạo record (Landing/Zalo/Fanpage/Referral/Cold), truy xuất nguồn lead, phát hiện KH "nhảy agency ≥3 lần/12 tháng".
5. **Quotation–WON có kiểm soát:** Accountant tính giá theo định mức → duyệt GM → gửi trong 2 ngày; WON cập nhật 24h, tự sinh dự án + xác nhận Capacity AM.

### 2. Lo ngại chính
1. **Điểm nghẽn ở SM:** Gate 1, Gate 2, bypass, duyệt GM dồn qua SM — cần escalation tự động khi quá SLA.
2. **Thang Tier nghịch trực giác (Tier A = auto LOST, Tier E = tốt nhất):** cần khóa logic bằng dữ liệu test + audit log mọi bypass.
3. **12/12 chính sách "Chưa có":** hệ thống đi trước chính sách (hoa hồng L1–L5) sẽ gây tranh chấp "deal này credit cho ai".

### 3. Đề xuất modules ưu tiên
1. **CRM & Lead Pipeline V6.0** — full lifecycle, anti-duplicate, auto scoring, hard gate.
2. **Quotation & Deal Desk** — tính giá, duyệt GM, version control, giới hạn vòng sửa theo tier (≤2 vs ≤4).
3. **Handoff & Onboarding Bridge** — Handoff Package 5 nhóm, ký duyệt 3 bên Sales/SM/AM.
4. **Commission & Quota L1–L5** — tự tính hoa hồng, theo dõi chỉ tiêu từng level.

### 4. Chính sách đề xuất
1. **Phân loại KH theo Tier A–E — Bắt buộc**: tiêu chí định tính + định lượng; nâng/hạ tier khi chấm qualifiedTier; hệ quả vận hành theo tier (AM 8-12 trang vs Planner 15-25 trang); rà soát ngưỡng quý theo win rate.
2. **Bảng giá & ma trận chiết khấu — Bắt buộc**: NVKD ≤5%, TPKD 10–15%, GDKD >15%, vượt lên BOD; hiệu lực báo giá 30–60 ngày; version control, bản gửi KH bị khóa; GM tối thiểu theo nhóm dịch vụ.
3. **Hoa hồng Sales L1–L5 — Bắt buộc**: credit theo thanh toán thực nhận + clawback khi hủy/nợ xấu; split credit TNKD/TPKD; chỉ deal ghi nhận PMS trước Gate 2 mới hưởng hoa hồng.
4. **Chỉ tiêu doanh số (Quota) theo cấp — Nên có**: pipeline coverage ≥3x, attainment tự động.
5. **Hợp đồng, LOI & Brand Safety — Bắt buộc**: mẫu chuẩn; điều khoản phản đòn bẩy KPI cứng; Brand Safety hard stop lưu bằng chứng LOST chủ động.

### 5. Quy trình kiểm soát
1. **Gate Enforcement & Immutable Audit:** checklist bắt buộc trước chuyển stage; K1–K5 hệ thống tự LOST không override; bypass SM bắt buộc ghi lý do audit log.
2. **SLA Monitoring & Escalation:** đồng hồ giờ làm việc cho SLA 2h/4h/1 ngày/2 ngày/24h; quá hạn → cảnh báo đỏ TNKD → TPKD/GDKD.
3. **Pipeline Hygiene Review hàng tuần:** deal >14 ngày không activity flag stale; lý do LOST gắn mã K1–K12; đo conversion từng stage hiệu chỉnh trọng số CQ theo dữ liệu thật.

---

## E4. marketing-expert — CMO / Strategic Planner (OPS_PLAN, L5 kiêm quyền TP Vận hành)

### 1. Yêu cầu quan trọng nhất
1. **Số hóa trọn vẹn Lifecycle V6.0 thành stage-gate cứng trên PMS:** Raw Data → Auto Scoring → Qualified → Lead → Evaluation (Brand Safety 7 + Weighted ≥3.5) → Proposal → WON → Deploy; mỗi gate có entry/done criteria machine-checkable; "Không ghi nhận vào PMS = Không tồn tại".
2. **Capacity L1-L5 là ràng buộc khi phân công:** mọi task gán OPS phải qua capacity check, cảnh báo đỏ >100% định mức giờ/tuần; workload toàn phòng realtime.
3. **P&L realtime từng dự án theo công thức đã chốt:** timesheet gắn nhãn Client Billable/Internal Non-billable ngay tại nguồn nhập.
4. **Handoff Sales→Vận hành là giao dịch điện tử có nghiệm thu:** Handoff Package 5 nhóm, SM ký, AM xác nhận SLA 4h.
5. **Client Portal minh bạch theo tần suất cam kết (Daily/Weekly/Monthly).**

### 2. Lo ngại chính
1. **Tài liệu 01 dừng ở tiêu đề Giai đoạn 3 Deploy Phase** — chưa có chuẩn khâu thực thi (triển khai campaign, deliverable, nghiệm thu, retainer) — nơi phát sinh phần lớn giờ billable.
2. **Rủi ro "quy trình trên giấy":** nhiều điểm duyệt thủ công — nếu ERP không có SLA timer, escalation, đếm vòng sửa tự động sẽ tạo thêm việc.
3. **Định mức nền chưa có:** cost-per-hour L1-L5, định mức giờ/tuần, khung SLA theo Tier — không chốt con số thì P&L/KPI vẫn cảm tính.

### 3. Đề xuất modules ưu tiên
1. **Proposal & Planning Workspace** — stage-gate V6.0, template proposal theo Tier, checklist Rehearsal, đếm vòng review, quotation + duyệt GM.
2. **Campaign & Deliverable Management** — dự án khách đa nền tảng, WBS deliverable, lịch nội dung, duyệt creative, report theo frequency.
3. **Capacity & Timesheet Engine** — định mức L1-L5, capacity check khi gán việc, timesheet phân loại bắt buộc, cost per hour.
4. **Client Portal + SLA & Alert Center** — portal, cảnh báo đỏ SLA breach TL+AM, cảnh báo số dư/die.

### 4. Chính sách đề xuất
1. **Stage-Gate & Điều kiện chuyển pha — Bắt buộc**: entry/done criteria machine-checkable; cấm chuyển pha thiếu điều kiện; SLA duyệt + escalation; mọi lead/deal phải nằm trên PMS.
2. **SLA khách hàng — Bắt buộc**: khung SLA theo Tier; chuẩn hóa Reporting Frequency thành định nghĩa đo được; cảnh báo đỏ breach TL+AM; % SLA đạt là KPI phòng Vận hành.
3. **Capacity & Timesheet — Bắt buộc**: định mức giờ/tuần L1-L5; chặn/cảnh báo >100%; gắn nhãn bắt buộc để lưu; duyệt timesheet tuần; đầu vào duy nhất cho P&L và KPI.
4. **KPI & Hiệu suất — Bắt buộc**: 3 trụ cột tự tổng hợp; không nhập điểm tay; chu kỳ review minh bạch.
5. **Brand Safety & Kỷ luật Proposal — Nên có**: 7 tiêu chí hard stop trước Evaluation; Weighted ≥3.5, borderline 3.0-3.49 thẩm định 4h; giới hạn vòng sửa theo Tier; Rehearsal + duyệt biên lợi nhuận trước gửi.

### 5. Quy trình kiểm soát
1. **Handoff có nghiệm thu 2 chiều:** Package 5 nhóm điện tử → SM ký → AM chấp nhận/từ chối có lý do trong 4h; từ chối trả lead về Sales với trạng thái rõ.
2. **Phê duyệt Proposal–Báo giá maker-checker:** soạn → Rehearsal phản biện → duyệt giá theo định mức → gửi; đếm vòng sửa và cảnh báo vượt hạn mức.
3. **Kiểm soát chiến dịch đang chạy:** launch checklist → giám sát pacing/CPA với pause rule → cảnh báo số dư → review tuần gắn KPI OPS_ADS/OPS_AM.

---

## E5. customer-expert — Head of Customer Experience

### 1. Yêu cầu quan trọng nhất
1. **Client Portal realtime (Web + Mobile) số 1** — khách tự xem số dư ví TKQC, chi tiêu hàng ngày, tiến độ nghiệm thu; đa ngôn ngữ, đa múi giờ, đa tenant; "single source of truth" thay Zalo/ảnh chụp.
2. **SLA Engine tự động**: đếm giờ theo ticket/task theo tier × priority; pre-alert 80%; báo đỏ breach tới AM + TL.
3. **Ticket/Complaint hub hợp nhất**: mọi yêu cầu portal/email/Zalo về một queue, gắn tier, SLA timer, escalation, CSAT sau đóng.
4. **Onboarding có milestone kiểm soát**: Handoff Package 5 nhóm (SLA 4h AM xác nhận), milestone Day 1/7/14/30, gate "khách kích hoạt Client Portal thành công".
5. **AM Dashboard tổng hợp**: portfolio (open tickets, SLA risk, số dư ví từng KH, tiến độ) cho OPS_AM — đầu mối duy nhất.

### 2. Lo ngại chính
1. **Minh bạch tài chính vs lộ biên lợi nhuận**: cần ranh giới dữ liệu portal rõ ràng + audit log mọi điều chỉnh số dư.
2. **Cam kết SLA khi 12/12 chính sách "Chưa có"**: phải định nghĩa "SLA clock" trước (múi giờ, giờ làm việc, luật tạm dừng) — khách đa quốc gia phức tạp.
3. **"Thời gian thực" phụ thuộc API**: độ trễ, rate limit, API fail — cần công bố độ trễ chấp nhận được, tránh portal thành nguồn khiếu nại mới.

### 3. Đề xuất modules ưu tiên
1. **Client Portal (Web + Mobile)** — ví, chi tiêu daily, nghiệm thu, ticket, thông báo; đa ngôn ngữ/múi giờ.
2. **Ticket & Complaint Management** — queue hợp nhất, SLA timer, escalation, CSAT/NPS.
3. **SLA & Notification Engine** — ma trận tier×priority, pre-alert 80%, breach alert, báo cáo compliance.
4. **Onboarding & Customer Success** — milestone tracker, health score, báo cáo theo tần suất cam kết.

### 4. Chính sách đề xuất
1. **SLA khách hàng — Bắt buộc**: ma trận tier×priority First Response/Resolution; định nghĩa SLA clock (múi giờ, giờ làm việc, tạm dừng chờ khách); pre-alert 80% + breach alert đỏ; thẩm quyền override theo cấp + audit log.
2. **Phân loại tier khách hàng CS — Bắt buộc**: chuyển đổi tier Sales → tier CS theo giá trị HĐ, số TK, churn risk; quyền lợi theo tier (tỷ lệ KH/AM, tần suất báo cáo); rà soát quý; tier cao + Critical → auto-escalate.
3. **Minh bạch dữ liệu Client Portal — Bắt buộc**: khách thấy (số dư, chi tiêu daily, tiến độ task, ticket, lịch nạp) vs không thấy (giá vốn, chiết khấu nội bộ, P&L, dữ liệu KH khác); nhiều user/roles phía khách; disclaimer độ trễ; audit log mọi điều chỉnh, khách xem lịch sử.
4. **Cảnh báo ví & Financial Hard Stop — Bắt buộc**: ngưỡng số dư theo mức chi tiêu daily, cảnh báo đỏ AM + khách (portal/push/email); không cấp phát TK khi chưa khớp tiền; cam kết thời gian xử lý top-up.
5. **CSAT/NPS & xử lý khiếu nại — Nên có**: CSAT tự động sau đóng ticket; detractor liên hệ lại 48h; khiếu nại nghiêm trọng KH lớn leo thang BOD; tổng hợp feedback hàng tháng.

### 5. Quy trình kiểm soát
1. **Vòng đời Ticket + Escalation**: state machine New→Open→Pending→Resolved→Closed (reopen 7 ngày); trigger bắt buộc (SLA >80%, khách yêu cầu quản lý, >72h, đe dọa pháp lý); hygiene: chưa nhận >30 phút báo TL, Pending >72h tự follow-up; audit trail mọi chuyển trạng thái.
2. **Onboarding Sales→AM**: Package 5 nhóm là điều kiện qua gate, AM xác nhận 4h, Second Meeting chốt IN/OUT scope + đầu mối duy nhất; milestone Day 1/7/14/30; gate cuối: khách kích hoạt portal + chạy chiến dịch đầu tiên.
3. **Xử lý SLA breach**: phát hiện tự động → báo đỏ AM+TL trong phút đầu → AM thông báo khách kèm phương án → post-mortem breach lặp → báo cáo SLA compliance hàng tháng cho BOD.

---

## E6. hr-expert — TPHR (HR_L2)

### 1. Yêu cầu quan trọng nhất
1. **Một nguồn sự thật nhân sự theo Level L1–L5:** hồ sơ là gốc — Level hiện hành, mã vai, hợp đồng, trạng thái — để RBAC, hoa hồng, P&L, KPI đọc chung một chuẩn.
2. **Cost per Hour theo Level version hóa theo thời gian** (từ ngày–đến ngày): đổi rate không được làm sai chi phí quá khứ của P&L.
3. **Timesheet gắn nhãn bắt buộc ngay lúc ghi:** Client Billable vs Internal Non-billable không sửa sau; chặn ghi giờ dự án nội bộ vào dự án khách.
4. **Capacity kiểm tra TRƯỚC khi gán:** Handoff Gate 2 cần "xác nhận Capacity trống" + phân bổ AM SLA 4h; >100% chặn gán mới hoặc escalate.
5. **KPI tự động nhưng tách bạch nguồn số liệu:** 3 trụ cột từ timesheet + task SLA; thành phần chấm tay phải khai báo trọng số riêng.

### 2. Lo ngại chính
1. **Kiêm nhiệm nhiều vai (CFO kiêm CTO, Planner kiêm TP OPS):** RBAC hỗ trợ 1 người – nhiều vai + tách xung đột phê duyệt (người ghi timesheet không tự duyệt).
2. **HR_L1 mỏng, 12/12 chính sách "Chưa có":** cần self-service + duyệt phân cấp tránh tê liệt một đầu mối.
3. **Sốc chuyển KPI cảm tính sang số liệu + alert fatigue:** cần chính sách OT/buffer, tránh timesheet "làm đẹp".

### 3. Đề xuất modules ưu tiên
1. **HR Core & Hành chính** — hồ sơ, HĐLĐ (cảnh báo hạn), chấm công, nghỉ phép.
2. **Timesheet & Capacity Management** — dự án kép, dashboard tải theo Level, cảnh báo burnout.
3. **KPI & Performance Engine** — 3 trụ cột tự động, chu kỳ review, PIP, calibration HR_L2.
4. **Talent (Tuyển dụng – Onboarding – Đào tạo)** — requisition duyệt headcount HR_L2, onboarding checklist, lộ trình thăng Level.

### 4. Chính sách đề xuất
1. **Định mức giờ làm & Capacity theo Level — Bắt buộc**: định mức giờ/tuần L1–L5; ngưỡng vàng 90% – đỏ 100%; ai duyệt gán vượt; cơ chế OT + tỷ lệ billable mục tiêu theo bậc.
2. **Ghi nhận Timesheet & phân loại dự án kép — Bắt buộc**: ghi hằng ngày, chốt tuần; TL duyệt (cấm tự duyệt); giờ chưa duyệt không vào P&L; sửa sai qua audit log.
3. **KPI 3 trụ cột & PIP — Bắt buộc**: công thức + nguồn dữ liệu từng trụ cột; trọng số theo bậc (L1-L2 nặng Output, L4-L5 nặng Target/SLA); review quý; PIP 30-60-90; HR_L2 calibration trước khi trình BOD.
4. **Cost Rate Card theo Level — Bắt buộc**: do HR_L2 – FIN_L2 thẩm định, BOD phê duyệt thay đổi; hiệu lực theo thời gian; lương mã hóa Confidential chỉ HR_L2+ được xem.
5. **Bảo mật dữ liệu nhân sự (PII) — Nên có**: phân loại dữ liệu, ma trận truy cập, audit log thay đổi lương/HĐ; tuân thủ NĐ 13/2023 + Bộ luật Lao động (48h/tuần, 12 ngày phép, BHXH, hạn chế thử việc).

### 5. Quy trình kiểm soát
1. **Phân bổ nguồn lực tại Handoff Gate 2:** SM duyệt → hệ thống lọc nhân sự còn capacity theo Level + kỹ năng → AM xác nhận 4h; thiếu capacity escalate TPHR/Planner, không ép gán.
2. **Chu trình timesheet tuần:** Ghi nhận → TL duyệt → FIN_L1 đối chiếu chi phí → khóa kỳ → số liệu chảy vào P&L/KPI; mở khóa chỉ HR_L2.
3. **Nhịp rà soát sức khỏe nhân sự:** tuần — TL xem dashboard quá tải; tháng — HR_L2 xử lý cảnh báo >100% liên tục ≥2 tuần; quý — calibration KPI + rà soát thăng Level.

---

## E7. data-expert — Head of Data/BI (phục vụ BOD)

### 1. Yêu cầu quan trọng nhất
1. **Pipeline ingestion đa nền tảng, chịu lỗi:** kéo chi tiêu hàng giờ từ Meta/Google/TikTok API (sau đó Bing/X/Pinterest/Yandex) qua adapter riêng; lưu raw payload; retry/backoff; **chế độ degraded** (nhập tay, gắn nhãn "manual") khi chưa có quyền API; backfill lịch sử khi được cấp.
2. **Kho dữ liệu = một nguồn sự thật (star schema):** fact_timesheet (nhãn bắt buộc), fact_ad_spend (TK × chiến dịch × giờ), fact_revenue/outsource/tools; conformed dimensions: Khách, Dự án, TKQC, Nền tảng, Chiến dịch, Nhân sự (cost rate SCD2). P&L realtime tính trực tiếp từ fact.
3. **Dashboard BOD (Web + Mobile):** P&L toàn công ty → drill-down khách → nền tảng → chiến dịch; trung tâm cảnh báo (số dư ngưỡng, die, SLA breach, vượt hạn mức tín dụng); chỉ báo "dữ liệu cập nhật lúc".
4. **Metric catalog chuẩn hóa:** ROAS, GM, P&L, On-time Delivery định nghĩa duy nhất, có owner, dùng chung nội bộ + portal.
5. **Immutable Audit Log:** append-only + before/after + hash-chain; BOD tra cứu trực tiếp.

### 2. Lo ngại chính
1. **Chưa có quyền API + quy mô 2.600+ TKQC:** rate limit, token hết hạn, mức trưởng API không đồng nhất; chỉ trông API → P&L chết khi connector lỗi.
2. **P&L realtime phụ thuộc timesheet nhập đúng/kịp:** rủi ro chất lượng dữ liệu số 1.
3. **12/12 chính sách "Chưa có":** chấm dứt "mỗi người một bảng tính" ngay từ đầu; cost rate/lương nhạy cảm nhưng P&L bắt buộc cần.

### 3. Đề xuất modules ưu tiên
1. **Data Integration Hub** — Settings credentials (vault mã hóa), adapter từng nền tảng, job đồng bộ hàng giờ, queue retry, trạng thái kết nối + backfill.
2. **Analytics Core (Warehouse + Metric Layer)** — star schema, conformed dimensions, metric catalog, data quality test tự động.
3. **BOD Dashboard & Reporting** — executive dashboard, alert center, ROAS theo khách/nền tảng/chiến dịch, export + subscription, mobile-responsive.
4. **Audit Log & Governance Service** — event store append-only, phân quyền theo tier dữ liệu, màn hình tra cứu audit cho BOD.

### 4. Chính sách đề xuất
1. **P1 Phân quyền & phân loại dữ liệu (RBAC theo tier) — Bắt buộc**: 4 tier (Công khai/Nội bộ/Mật/Restricted); cost rate, lương = Restricted chỉ CEO/CFO; ma trận phê duyệt cấp quyền; review quý; log mọi truy cập dữ liệu tài chính.
2. **P2 Quản trị định nghĩa chỉ số — Bắt buộc**: metric khai báo (tên, công thức, nguồn, owner); dashboard chỉ dùng metric chuẩn; đổi định nghĩa CFO duyệt + lịch sử hiệu lực.
3. **P3 Chất lượng & độ tươi dữ liệu (Freshness SLA) — Bắt buộc**: chi tiêu QC ≤ 1 giờ; timesheet chốt hằng ngày; test tự động (not-null, uniqueness, đối soát ±0,1%); dashboard hiển thị freshness; alert stale/fail.
4. **P4 Bảo mật credentials & kết nối API — Bắt buộc**: vault mã hóa, chỉ CTO/Super Admin quản trị; rotate token, thu hồi khi nghỉ; log mọi lần gọi API; degraded mode ghi nguồn manual.
5. **P5 Lưu trữ & kiểm soát audit log — Bắt buộc**: append-only + hash-chain; retention ≥ 5 năm sự kiện tiền; backup mã hóa + test phục hồi; việc xem audit cũng bị log.

### 5. Quy trình kiểm soát
1. **Đối soát 3 lớp:** (a) hàng giờ API spend vs số dư nội bộ; (b) hằng ngày FIN_L1 đối soát top-up/refund trước cấp phát (Hard Stop); (c) hàng tháng KTT chốt công nợ nền tảng; chênh lệch → cảnh báo CFO.
2. **Runbook sự cố dữ liệu:** fail/stale → phân loại mức → backfill có ghi nhận → báo cáo nguyên nhân; stale quá ngưỡng → cảnh báo đỏ BOD.
3. **Vòng đời ban hành báo cáo:** yêu cầu → KPI sign-off → build → QA đối chiếu nguồn ±0,1% → CFO duyệt publish → theo dõi usage, thu hồi báo cáo không dùng.

---

## E8. legal-expert — Giám đốc Pháp lý (P0-01 §5.1)

### 1. Quy định/pháp luật áp dụng
| Quy định | Áp dụng? | Yêu cầu cụ thể với BCERP | Ưu tiên |
|---|---|---|---|
| Luật Quảng cáo 2012 (+ sửa đổi) | Có | Mạng QC internet đăng ký; SP hạn chế cần giấy phép — ERP lưu hồ sơ pháp lý SP, gắn Knockout K1 | Cao |
| NĐ 13/2023/NĐ-CP (dữ liệu cá nhân) | Có | Cơ sở pháp lý xử lý, phân quyền, bảo mật, thông báo vi phạm 72h, kiểm soát retention | Cao |
| TT 78/2021/TT-BTC + NĐ 123/2020 (HĐĐT) | Có | Finance xuất/kết nối hóa đơn điện tử mã cơ quan thuế, XML, lưu đúng quy định | Cao |
| Luật ATTT 2018 / NĐ 53/2022 | Có | Lưu dữ liệu tại VN (trường hợp áp dụng); kiểm soát Portal truy cập từ nước ngoài | Cao |
| Lưu trữ chứng từ (Luật Kế toán 2015, Luật Thương mại) | Có | HĐ, chứng từ đối soát: lưu ≥10 năm; retention policy cấu hình được | Cao |
| GDPR + CCPA | Có nếu khách EU/US | DPA, controller/processor, DSAR, transfer mechanism | Cao |
| Luật Giao dịch điện tử 2023 / NĐ 91/2022 | Có | Chữ ký số/e-sign HĐ, LOI | TB |
| Hợp đồng đa quốc gia | Có | Luật áp dụng, tranh chấp, withholding tax, đa ngôn ngữ/phiên bản | TB |
| Meta/Google/TikTok/Yandex Ads Policy | Có | Business Verification, chống gian lận, resale TKQC; theo dõi trạng thái tuân thủ từng TK | Cao |

### 2. Lo ngại pháp lý chính
1. **Trách nhiệm lan truyền từ SP khách (K1/K3 + Brand Safety):** cần bằng chứng due diligence (audit trail checklist Brand Safety) chứng minh đã thẩm định.
2. **Chồng lấn NĐ 13 và GDPR vai trò kép:** vừa controller vừa processor — phân định trong hợp đồng, tránh phạt GDPR tới 4% doanh thu.
3. **Dữ liệu ví TKQC + credentials API nhạy cảm:** immutable audit log + Financial Hard Stop là nền đúng, cần nâng chuẩn pháp lý (log 10 năm).

### 3. Điều khoản hợp đồng cần chuẩn hóa
1. **HĐ/LOI dịch vụ:** IN/OUT of scope rõ; nạp trước 100% NSQC (đồng bộ K4); chấm dứt/miễn trừ khi nền tảng khóa TK.
2. **NDA mutual:** bắt buộc trước khi nhận Full Brief 8 sections; quản lý trạng thái NDA trong CRM.
3. **Brand Safety clause:** khách cam kết SP hợp pháp + giấy phép; BC quyền từ chối vận hành nếu vi phạm 1/7 tiêu chí; phụ lục 7 tiêu chí gắn HĐ.
4. **Giới hạn trách nhiệm & KPI:** không cam kết KPI cứng (K2); cap trách nhiệm = phí dịch vụ đã nhận; miễn trừ thuật toán nền tảng; đúng tần suất báo cáo chốt.

### 4. Yêu cầu tuân thủ Client Portal & dữ liệu khách
1. Xác thực mạnh (2FA/OTP) + tenant isolation; session timeout; log IP/khu vực.
2. Dữ liệu ví/chi tiêu read-only; điều chỉnh có audit log; giới hạn download/print (watermark).
3. Data minimization + quyền xóa/ẩn danh khi chấm dứt HĐ (NĐ 13, GDPR).
4. Credentials API: vault mã hóa, không hiển thị qua Portal, key rotation — CTO Super Admin.

### 5. Quy trình pháp lý cần xây dựng
1. **Workflow duyệt hợp đồng:** template chuẩn → legal review → duyệt theo ma trận giá trị → e-sign (Luật GDTĐT 2023) → archive + alert hết hạn; version control (draft → counterparty → Final → Signed lock).
2. **Checklist Brand Safety 7 tiêu chí dạng form chặn cứng** trong Evaluation (fail 1 → LOST chủ động), gắn K1/K3; tự lưu evidence.
3. **Lưu trữ theo retention schedule:** HĐ 10 năm, chứng từ thuế 10 năm, litigation 10 năm sau đóng; disposal qua phê duyệt + log hủy.

> **Lưu ý:** phân tích khởi điểm — cần luật sư VN chuyên dữ liệu/công nghệ xác nhận trước khi áp dụng chính thức.

---

## E9. compliance-expert — Trưởng Kiểm toán nội bộ

### 1. Yêu cầu kiểm soát nội bộ quan trọng nhất
1. **Immutable Audit Log (TÍN):** mọi giao dịch tiền + hợp đồng ghi append-only who/when/what/before-after/reason-code; kể cả Super Admin không xóa/sửa; lưu ≥10 năm theo chuẩn kế toán VN.
2. **Segregation of Duties 3 lớp:** người đề xuất nạp (AM/Ops) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ. Cảnh báo: **CFO kiêm CTO + Super Admin = concentration of risk** — cần compensating control (CEO duyệt giao dịch vượt ngưỡng, access review định kỳ).
3. **Financial Hard Stop tự động (TÂM):** chặn cứng cấp phát TKQC khi chưa "Đã khớp tiền"; cấm bypass; exception phải có duyệt riêng + log.
4. **Approval matrix theo cấp bậc + ngưỡng giá trị:** dual approval bắt buộc cho điều chỉnh số dư, đổi tỷ giá thủ công, hoàn tiền, chiết khấu ngoài biểu.
5. **Reconciliation 3 chiều:** ví nội bộ ↔ chi tiêu API nền tảng ↔ tiền khách đã thanh toán; chênh lệch có reason code, review trước khi close.

### 2. Lo ngại rủi ro tuân thủ chính
1. **Rửa tiền qua ví TKQC:** 2.600+ TK, nạp/rút đa kênh quốc tế, hoàn tiền có thể về TK bên thứ ba — K2/K4 chỉ lọc tầng lead, chưa có monitoring tầng giao dịch → cần KYC + giao dịch bất thường.
2. **PCI-DSS nếu Portal xử lý thẻ:** khuyến nghị hosted payment page/redirect của PSP (SAQ-A) để thu hẹp scope từ ngày đầu.
3. **Truy cập credentials API + gian lận nội bộ:** vault mã hóa, MFA, least privilege, xoay token, session log.

### 3. Đề xuất modules ưu tiên
1. **Immutable Audit Log Service** — nền móng trước mọi module tiền/hợp đồng.
2. **Wallet & Balance Management + Financial Hard Stop.**
3. **Reconciliation Engine qua API nền tảng** — hourly/daily, cảnh báo lệch + die.
4. **RBAC + Approval Workflow Engine** — ma trận phân quyền, ngưỡng duyệt, dual approval.

### 4. Chính sách đề xuất
1. **Kiểm soát ví & giao dịch tiền TKQC — Bắt buộc:** SoD 4 vai; hard stop khớp tiền; dual approval điều chỉnh dư/tỷ giá thủ công/hoàn tiền.
2. **AML/KYC — Bắt buộc:** định danh pháp nhân khách trước cấp TK; hoàn tiền về đúng TK nguồn nạp; ngưỡng cảnh báo giao dịch bất thường (nạp gấp, tách nhỏ, nguồn rủi ro cao).
3. **Quản lý truy cập & Credentials — Bắt buộc:** vault mã hóa token, MFA toàn bộ tài khoản quản trị; quarterly access review + thu hồi khi nghỉ.
4. **Dữ liệu cá nhân (NĐ 13/2023 + GDPR) — Bắt buộc:** inventory dữ liệu Portal, mục đích xử lý, retention; breach notification 72h; DSR tracking.
5. **Bảo lưu hồ sơ & Audit Log — Nên có:** tài chính 10 năm, audit log ≥7 năm, storage WORM.

### 5. Quy trình kiểm soát
1. **Nạp tiền → Khớp tiền → Cấp phát TKQC** (three-way match + exception approval riêng).
2. **Đối soát định kỳ & xử lý chênh lệch** (auto-recon hàng giờ; FIN_L2 review tuần; escalation lên BOD).
3. **Điều chỉnh số dư / Hoàn tiền / Đổi tỷ giá bất thường** (request lý do → dual approval → thực thi → log bất biến; sampling test quý).

> **Lưu ý:** cần auditor/luật sư độc lập xác nhận trước khi áp dụng làm bắt buộc thiết kế. Chưa xác nhận: mô hình thanh toán (thẻ trực tiếp hay chuyển khoản), chính sách hoàn tiền, phân tách quyền CFO/CTO kiêm nhiệm.

---

## E10. ecommerce-expert — Head of E-commerce (vai PHỤ — TikTok Shop)

### 1. Yêu cầu quan trọng nhất
1. **Tích hợp TikTok Business API theo từng khách hàng:** kéo đơn hàng, GMV, settlement, chi tiêu TikTok Ads, shop health theo giờ.
2. **Tách bạch GMV khách khỏi P&L agency:** GMV/đơn/settlement là chỉ số của khách, không phải doanh thu agency; P&L dự án TikTok Shop chỉ tính phí dịch vụ + giờ billable + tools.
3. **Client Portal mở rộng TikTok Shop:** khách xem realtime GMV, đơn, settlement, chi tiêu ads, tiến độ task.
4. **Giám sát shop health & SLA dạng cảnh báo:** fulfillment SLA, tỷ lệ hoàn/hủy, violation points — ERP cảnh báo, không xử lý logistics.

### 2. Lo ngại chính
1. **Trôi phạm vi sang OMS/WMS đầy đủ** — ERP agency chỉ ở tầng "quản lý dự án + giám sát qua API".
2. **Sở hữu dữ liệu và dòng tiền:** shop, PII người mua cuối, settlement thuộc khách; agency chỉ được ủy quyền OAuth, có thể bị thu hồi.

### 3. Đề xuất modules
1. **Tích hợp TikTok Business API (Shop + Ads)** — đồng bộ per-client, feed cho Đối soát + P&L.
2. **Client Portal TikTok Shop** — dashboard realtime theo shop.
3. **Giám sát vận hành Shop theo SLA** — cảnh báo shop health, gắn task ops với timesheet/capacity.

### 4. Chính sách đề xuất
1. **Truy cập & Sở hữu dữ liệu Shop khách — CAO**: OAuth theo khách, log mọi truy cập, thu hồi khi hết HĐ; không lưu PII thô, mask SĐT/địa chỉ; isolation giữa shop khách.
2. **Tách bạch GMV vs doanh thu agency — CAO**: GMV/settlement chỉ tham chiếu; doanh thu agency = phí dịch vụ + phí ads thu hộ; audit log mọi điều chỉnh.
3. **Thẩm định Shop trước vận hành — TRUNG BÌNH**: checklist chủ shop + giấy phép ngành hàng theo chính sách TikTok Shop; IN/OUT scope (không nhận logistics trừ khi HĐ quy định); baseline KPI lúc bàn giao, không cam kết KPI cứng.

### 5. Quy trình kiểm soát
**TikTok Shop Lifecycle 3 Gate** nối vào Lifecycle V6.0: (1) Gate Verification — chủ shop ủy quyền API + checklist hợp lệ mới kết nối; (2) Gate Go-live — listing, ngân sách, baseline KPI do SM ký duyệt; (3) Gate Đối soát định kỳ — tự khớp settlement vs đơn vs chi tiêu ads hàng ngày, chênh lệch vượt ngưỡng báo FIN_L1 + AM, báo cáo tháng qua Portal cho khách nghiệm thu.
