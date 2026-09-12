# DEPT-SALES — Phòng Kinh Doanh (Sales)

> **Phòng ban:** Phòng Kinh Doanh — 5 cấp bậc `SALES_L1` (Intern) → `SALES_L5` (GDKD, vị trí quy hoạch — tạm BOD kiêm nhiệm)
> **Ngày cập nhật:** 12/09/2026
> **Trạng thái:** Đang phân tích (Phần A — BA viết; Phần B — Sales Expert review 12/09/2026; A7 do bước sau điền)
>
> READS: `P1-01-project-overview.md`, `phase0-brainstorm/P0-01-brainstorm.md`, `P0-02-systems-users.md`, policies: `phan-loai-khach-hang-tier.md`, `bang-gia-chiet-khau-gross-margin.md`, `hoa-hong-sales-quota.md`, `hop-dong-loi-nda-brand-safety.md`, `stage-gate-lifecycle-v6.md`
> USED BY: `departments/_index.md`, `_meta/req-registry.json`, `phase2-features/`

---

## Phần A — Phân Tích BA (Stakeholders & User Needs)

### A0. Ma Trận Requirement × System

Hệ thống declared cho DEPT-SALES: **SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL** (ký hiệu: CORE, WEB, MOBILE). Quy ước phase: MVP = GĐ1, Phase2 = GĐ2, Phase3 = GĐ3 (dự án phát triển đầy đủ, nhãn phase chỉ là thứ tự xây dựng).

| REQ-ID | Title | Systems | Primary | Lý do tách/gộp |
|---|---|---|---|---|
| REQ-SALES-001 | Thu nhận lead đa kênh & anti-duplicate | CORE, WEB | CORE | So khớp trùng + tiếp nhận đa nguồn là engine ở CORE; WEB cho nhập tay referral/cold |
| REQ-SALES-002 | Pipeline V6.0 — hard gate & phân bổ lead | CORE, WEB | WEB | WEB là mặt làm việc hằng ngày của sales; hard block stage ở CORE nhưng trọng tâm trải nghiệm là pipeline board |
| REQ-SALES-003 | AUTO SCORING K1–K12 & Tier A–E | CORE, WEB | CORE | Scoring engine, chấm 2 lần, khóa điểm ở CORE; WEB hiển thị + review flag |
| REQ-SALES-004 | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | CORE, WEB, MOBILE | MOBILE | Approval engine ở CORE; MOBILE là kênh ký duyệt chính của SM từ Phase2 (mục đích khai báo của app nội bộ) — tách khỏi 002 vì đây là điểm quyết định có chữ ký, không phải di chuyển stage |
| REQ-SALES-005 | Chuyển tier Sales → CS & rà soát quý | CORE, WEB | CORE | Đồng bộ tier sang CS + tham số effective-dated ở CORE; chu trình quý trên WEB |
| REQ-SALES-006 | Quotation & Deal Desk | CORE, WEB, MOBILE | CORE | GM engine + version control + hiệu lực ở CORE; WEB lập báo giá; MOBILE duyệt chiết khấu/GM (Phase2) |
| REQ-SALES-007 | Hợp đồng/LOI/NDA & Brand Safety + e-sign | CORE, WEB, MOBILE | CORE | Workflow duyệt, version lock, trạng thái chờ kích hoạt, retention ở CORE; WEB soạn + checklist; MOBILE duyệt HĐ giá trị lớn (Phase2) |
| REQ-SALES-008 | Handoff & Onboarding Bridge | CORE, WEB, MOBILE | WEB | Soạn package + theo dõi milestone Day 1/7/14/30 là công việc web; checklist chặn Gate 2 ở CORE; SM/AM ký qua MOBILE (Phase2) |
| REQ-SALES-009 | Commission & Quota | CORE, WEB, MOBILE | CORE | Credit/clawback/split/khóa kỳ là engine ở CORE; WEB dashboard; MOBILE alert coverage + attainment (Phase2) |

Cả 3 hệ thống phục vụ đều có vai primary: CORE (001, 003, 005, 006, 007, 009), WEB (002, 008), MOBILE (004).

**Note các hệ thống còn lại:**
- `SYS-INTEGRATION-GW`: **không có requirement riêng của DEPT-SALES** — cấu hình kênh webhook lead (landing page, Zalo OA, Fanpage/Messenger) thuộc quản trị Gateway (REQ-BOD-008, vai SYS_ADMIN/CTO theo Settings & Integration Gateway); nhu cầu Sales bắt đầu từ khi lead đã đổ về CORE (REQ-SALES-001).
- `SYS-PORTAL-WEB`: sales **không vận hành portal**. Need duy nhất: xem trạng thái kích hoạt tài khoản portal của khách tại milestone onboarding (dữ liệu trạng thái đọc từ CORE, không có màn hình riêng cho sales trên portal).
- `SYS-MOBILE-PORTAL`: **không có requirement riêng** — app dành cho khách hàng.

---

### A1. Giới Thiệu Phòng Ban

**Phòng Kinh Doanh làm gì:** Sở hữu nửa đầu Lifecycle V6.0 — từ lead đa kênh → qualification (Gate 1/Gate 2) → báo giá theo định mức GM → hợp đồng → bàn giao cho Vận hành (Handoff). Đồng thời chịu trách nhiệm chỉ tiêu doanh số (quota) và hoa hồng theo thang bậc L1–L5. Phân hệ phụ trách: CRM & Lead Pipeline V6.0 (GĐ1), Quotation & Deal Desk (GĐ1), Handoff & Onboarding Bridge (GĐ2), Commission & Quota (GĐ3).

**Rủi ro then chốt:**
- GDKD (L5) hiện là **vị trí quy hoạch, tạm BOD kiêm nhiệm** — hệ thống phải hỗ trợ vai kiêm nhiệm (duyệt theo mã vai, không theo người) và cho tách vai sau này không phải redesign.
- Nguyên tắc sống còn: **"Không ghi nhận vào PMS = Không tồn tại"** — kỷ luật dữ liệu pipeline là điều kiện tiên quyết để hoa hồng không tranh chấp deal credit.
- Doanh thu agency chỉ tính trên **phí dịch vụ/markup**; tiền nạp QC của khách là tiền giữ hộ — báo giá và hoa hồng không được đếm phần pass-through vào sai cấu trúc.

| Vai trò | SL | Công việc hàng ngày | Cần hệ thống hỗ trợ gì |
|---|---|---|---|
| Intern Sales (`SALES_L1`) | Chưa chốt (trong tổng 31–50 NS toàn công ty) | Tìm data khách, nhập lead thô, nuôi lead đầu phễu | Form nhập lead, tra cứu anti-duplicate, theo dõi SLA Initial Brief 2h |
| NVKD (`SALES_L2`) | Chưa chốt | Tư vấn, chốt HĐ MKT/cho thuê TKQC, quản pipeline cá nhân, chiết khấu ≤5% | Pipeline cá nhân, quotation, nhận push duyệt, credit hoa hồng của mình |
| TNKD/SM (`SALES_L3`) | Chưa chốt | Ký Gate 1 (Go/No-Go), Gate 2 (Handoff), KPI nhóm, review scoring flag, phân xử deal trùng | Hàng đợi duyệt gate, pipeline nhóm, alert SLA gate, dashboard coverage |
| TPKD (`SALES_L4`) | Chưa chốt | Chỉ tiêu toàn phòng, duyệt chiết khấu >5–15%, chính sách bán hàng | Pipeline phòng, duyệt quotation, báo cáo GM |
| GDKD (`SALES_L5` — quy hoạch) | Chưa chốt | Duyệt chiết khấu >15–20%, deal lớn, exception vòng sửa, quyết khiếu nại credit, báo cáo BOD | Dashboard toàn Sales, duyệt exception, báo cáo win rate theo tier |

*Ngoài phòng: OPS_AM (Account Manager) tham gia bắt buộc tại Gate 2 (xác nhận Handoff SLA 4h) và Accountant (FIN) lập quotation theo định mức — chi tiết phối hợp tại REQ-SALES-006, REQ-SALES-008.*

---

### A2. Tổng Hợp Nhu Cầu

| STT | Mã | Tên nhu cầu | Ưu tiên |
|---|---|---|---|
| 1 | REQ-SALES-001 | Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate) | HIGH |
| 2 | REQ-SALES-002 | Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead | HIGH |
| 3 | REQ-SALES-003 | AUTO SCORING K1–K12 & Tier A–E | HIGH |
| 4 | REQ-SALES-004 | Gate 1 & Gate 2 — Go/No-Go và ký Handoff | HIGH |
| 5 | REQ-SALES-005 | Chuyển tier Sales → CS & rà soát quý tier | MEDIUM |
| 6 | REQ-SALES-006 | Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM | HIGH |
| 7 | REQ-SALES-007 | Hợp đồng/LOI/NDA & Brand Safety + e-sign | HIGH |
| 8 | REQ-SALES-008 | Handoff & Onboarding Bridge | HIGH |
| 9 | REQ-SALES-009 | Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3× | MEDIUM |

> HIGH = Bắt buộc (không có thì pipeline và kiểm soát doanh thu gãy); MEDIUM = Quan trọng (chu kỳ kỳ hạn, có thể vận hành tạm thủ công ngắn hạn nhưng bắt buộc tự động hóa để tránh tranh chấp).

---

### A3. Chi Tiết Từng Nhu Cầu

#### REQ-SALES-001: Thu nhận lead đa kênh & chống trùng lặp (anti-duplicate)

**Ưu tiên:** HIGH — **Phase:** MVP (GĐ1). **Ai dùng:** SALES_L1 (nhập lead thô/cold data), SALES_L2 (referral, lead kênh số), SM (phân xử deal trùng).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): tiếp nhận lead từ 4 nguồn (landing page form/webhook, Zalo OA, Fanpage/Messenger, referral/cold) vào stage Raw Data; anti-duplicate matching theo email/SĐT/website/MST với lead đang mở; gắn nhãn nguồn; hàng đợi retry khi kênh webhook lỗi.
- `SYS-BCERP-WEB`: form nhập tay lead referral/cold data với trường bắt buộc tối thiểu (tên công ty, người liên hệ, email/SĐT, nguồn lead); xem kết quả so khớp (trùng/mới) và lịch sử hoạt động lead.

**Tôi cần hệ thống làm được:**
- [ ] Lead từ landing page (webhook), Zalo OA, Fanpage/Messenger tự đổ về pipeline trong vài phút, tag đúng nguồn + chiến dịch
- [ ] So khớp trùng tự động — lead trùng bị flag kèm người ghi trước + bằng chứng hoạt động (email/call/meeting log), không chặn mù
- [ ] Thứ tự ưu tiên khi trùng: người ghi trước có bằng chứng → hòa: SM phân xử SLA 24h → khiếu nại: GDKD quyết cuối, ghi audit log

**Quy tắc:** mọi lead phải nằm trên hệ thống — cấm giữ lead trên Zalo cá nhân/Sheets; cấm tự ý gộp/xóa lead trùng không qua phân xử. **Đặc biệt:** lead cũ quay lại ≤180 ngày giữ nguyên lịch sử scoring, được chấm lại đúng 1 lần với dữ liệu mới; kênh webhook lỗi → hàng đợi retry, không mất lead.

#### REQ-SALES-002: Pipeline V6.0 — hard gate "không ghi nhận = không tồn tại" & phân bổ lead

**Ưu tiên:** HIGH — **Phase:** MVP. **Ai dùng:** toàn bộ L1–L5 (L2 pipeline cá nhân, L3 nhóm, L4 phòng, L5 toàn Sales).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND`: stage machine 10 stage; **hard block chuyển stage thiếu done criteria ở cả UI và API**; SLA clock từng gate + escalation tự động quá hạn; audit log bất biến mọi chuyển stage.
- `SYS-BCERP-WEB` (primary): pipeline board theo cá nhân/nhóm/phòng; nhập meeting notes; theo dõi SLA; kéo stage khi đủ điều kiện.

**Tôi cần hệ thống làm được:**
- [ ] 10 stage V6.0 (Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → EVALUATION → PROPOSAL → WON → DEPLOY) hiển thị rõ điều kiện chuyển tiếp từng stage
- [ ] Initial Brief hoàn tất trong **2h** từ Raw Data với 3 trường bắt buộc: Ngân sách, Sản phẩm/dịch vụ, Nhu cầu — quá hạn cảnh báo + escalate
- [ ] Meeting notes bắt buộc trước QUALIFIED (không notes = meeting không được công nhận)
- [ ] WON: cập nhật trong 24h, tự sinh dự án + AM xác nhận capacity (liên kết REQ-SALES-008)
- [ ] Phân bổ lead mới: tự gán owner theo quy tắc nguồn/vùng hoặc SM gán trong SLA `[CẦN CHỐT SỐ — quy tắc phân bổ và SLA gán chưa có chính sách; đề xuất gán trong 4h giờ làm việc]`

**Quy tắc:** cấm chuyển pha thiếu điều kiện (chặn cả 2 tầng); escalation tự động lên cấp trên trực tiếp khi quá SLA. **Đặc biệt:** khách tái ký được rút gọn Initial Brief nhưng không bỏ Gate 1/Gate 2; deal hủy trước Gate 1 chỉ lưu hồ sơ.

#### REQ-SALES-003: AUTO SCORING K1–K12 & Tier A–E

**Ưu tiên:** HIGH — **Phase:** MVP. **Ai dùng:** hệ thống (tự chấm), SM (review flag, thẩm định borderline), NVKD (xem điểm, bổ sung dữ liệu).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): scoring engine — K1–K5 knockout (fail → tự loại), K6–K12 flag (cảnh báo), điểm CQ theo trọng số 30/25/20/15/10 thang 1–5; chấm 2 lần (autoScore tại Initial Brief, qualifiedTier sau Full Brief 8 sections); khóa qualifiedTier sau Gate 1; map tier theo ngưỡng 1.5/2.0/3.0/3.5.
- `SYS-BCERP-WEB`: hiển thị điểm + lý do từng tiêu chí; hàng đợi review scoring flag của SM; route borderline vào hàng đợi thẩm định.

**Tôi cần hệ thống làm được:**
- [ ] Tier A (<1.5) AUTO LOST — không vào First Meeting (trừ tư vấn theo K4); Tier B/C bắt buộc First Meeting; Tier E (≥3.5) SM được bypass First Meeting
- [ ] Tier D (3.0–3.49) borderline — SM thẩm định SLA 4h, quá hạn escalate GDKD, kết quả kèm lý do
- [ ] Thiếu dữ liệu ≥2/5 tiêu chí CQ → chặn chấm, trạng thái "Thiếu dữ liệu", cấm đoán điểm thủ công
- [ ] SM không sửa điểm trực tiếp — chỉ bổ sung dữ liệu rồi cho chấm lại; mọi chấm/chấm lại/bypass/thẩm định ghi audit log

**Quy tắc:** thang tier **nghịch trực giác (A = tệ nhất, E = tốt nhất)** — giao diện phải hiển thị rõ nghĩa từng tier; cấm hardcode nhãn tier trong code. **Đặc biệt:** khách do đối tác (Google/TikTok/Yandex) giới thiệu không được bypass scoring; khách BOD-sponsored gắn nhãn riêng nhưng vẫn chấm qualifiedTier; qualifiedTier là đầu vào bắt buộc của Gate 1 và khóa sau khi SM ký.

#### REQ-SALES-004: Gate 1 & Gate 2 — Go/No-Go và ký Handoff

**Ưu tiên:** HIGH — **Phase:** MVP (approval engine, ký trên web) → MOBILE từ Phase2 (kênh ký di động chính). **Ai dùng:** SM (ký cả 2 gate), NVKD (chờ kết quả), OPS_AM (xác nhận Gate 2 SLA 4h).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND`: approval engine — e-approval chữ ký SM; chặn gate thiếu điều kiện; escalation tự động quá SLA; audit log mọi chữ ký.
- `SYS-BCERP-WEB`: màn hình duyệt đầy đủ — hồ sơ deal, qualifiedTier, checklist Handoff, lịch sử.
- `SYS-MOBILE-INTERNAL` (primary kênh ký từ Phase2): push gate chờ duyệt; ký Gate 1 (SLA 1 ngày làm việc) và xác nhận Gate 2 (SLA 4h) trên di động — đúng mục đích khai báo "SALES_L2–L5 duyệt di động".

**Tôi cần hệ thống làm được:**
- [ ] Gate 1 (QUALIFIED): AM chấm qualifiedTier + SM ký Go/No-Go trong SLA 1 ngày làm việc
- [ ] Gate 2 (LEAD): Handoff Package 5 nhóm đủ 100% + SM ký + AM xác nhận SLA 4h (nội dung package tại REQ-SALES-008)
- [ ] Quá SLA: escalate tự động lên cấp trên + log; cấm tự duyệt deal do chính mình chốt (SM ký phải khác NVKD chủ deal)
- [ ] Override knockout K1–K5: chỉ deal chiến lược được chỉ định, lý do bằng văn bản + GDKD phê duyệt lại, log bất biến

**Quy tắc:** chữ ký gate không ủy thác hàng loạt; mobile ký dùng token gắn device (NFR P0-02 §2.4). **Đặc biệt:** AM từ chối Gate 2 → deal trả về SM khắc phục, credit hoa hồng tạm dừng (REQ-SALES-009).

#### REQ-SALES-005: Chuyển tier Sales → CS & rà soát quý tier

**Ưu tiên:** MEDIUM — **Phase:** MVP (tier + đồng bộ sang CS tại WON) → Phase2 (chu trình đề xuất chuyển tier với CS). **Ai dùng:** GDKD (duyệt, rà quý), SM (đồng thuận), CS/AM (bên nhận).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): tier chuyển nguyên trạng cho CS khi WON — không nhập lại; tham số ngưỡng/trọng số CQ effective-dated (version hóa, không sửa quá khứ); health score làm đầu vào đề xuất.
- `SYS-BCERP-WEB`: luồng đề xuất chuyển tier — CS đề xuất → SM + CS TL đồng thuận → GDKD duyệt (SLA 3 ngày làm việc).

**Tôi cần hệ thống làm được:**
- [ ] Đề xuất chuyển tier trong kỳ theo: doanh thu thực tế của hợp đồng, số TKQC active, churn risk (health score)
- [ ] Rà soát quý: GDKD rà win rate theo tier + độ lệch điểm CQ vs kết quả thực; hiệu chỉnh ngưỡng/trọng số phải GDKD trình BOD — không chỉnh tại chỗ
- [ ] Dashboard win rate theo tier + độ chính xác scoring theo quý cho GDKD/BOD

**Quy tắc:** mọi thay đổi tier có audit log + lý do; tham số version hóa effective-dated. **Đặc biệt:** khách strategic BOD-sponsored vẫn phải có qualifiedTier để phục vụ vận hành (template proposal, SLA, vòng sửa).

#### REQ-SALES-006: Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM

**Ưu tiên:** HIGH — **Phase:** MVP (GĐ1). **Ai dùng:** Accountant/FIN (lập theo định mức — phối hợp DEPT-FIN), NVKD (tạo, gửi, chiết khấu ≤5%), TPKD (>5–15%), GDKD (>15–20%, exception), BOD (>20%).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): định mức tính giá version theo quý; GM engine theo nhóm dịch vụ (agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%); approval ma trận chiết khấu; version control + khóa bản gửi khách; đồng hồ hiệu lực 30/60 ngày.
- `SYS-BCERP-WEB`: soạn quotation trace về đúng version định mức hiệu lực; gửi khách sau khi đủ duyệt.
- `SYS-MOBILE-INTERNAL` (từ Phase2): TPKD duyệt chiết khấu (SLA 8 giờ làm việc), GDKD duyệt GM/exception (SLA 1 ngày) qua push.

**Tôi cần hệ thống làm được:**
- [ ] Tự tính GM từ định mức hiện hành; cảnh báo đỏ khi GM dưới ngưỡng nhóm dịch vụ
- [ ] Chặn gửi khách khi: hết hiệu lực, chưa duyệt GM, chưa duyệt chiết khấu theo ma trận
- [ ] Bản gửi khách khóa vĩnh viễn (read-only); sửa = version mới + duyệt lại; vòng sửa theo tier: D/E ≤2, B/C ≤4 — vượt chặn, GDKD mở exception có lý do
- [ ] Tự chuyển "Hết hạn" sau 30 ngày (tối đa 60 cho HĐ năm/đa giai đoạn); sau duyệt GM tối đa 2 ngày làm việc phải gửi KH — quá hạn cảnh báo SM + GDKD

**Quy tắc:** cấm "chiết khấu ẩn" (tặng giờ/tài nguyên không ghi giá không qua duyệt); giá vốn/GM là dữ liệu Mật — NVKD không xem giá vốn; mọi version, người duyệt, lý do chiết khấu ghi audit log. **Đặc biệt:** pilot 1 tháng được GM dưới ngưỡng tối đa một kỳ và ≤60 ngày, GDKD duyệt kèm mục tiêu chuyển đổi; tái ký trong 12 tháng giữ bảng giá cũ tối đa 1 lần; biến động tỷ giá/phí nền tảng >5% → version điều chỉnh không tính vào vòng sửa.

#### REQ-SALES-007: Hợp đồng/LOI/NDA & Brand Safety + e-sign

**Ưu tiên:** HIGH — **Phase:** MVP (mẫu chuẩn, chặn NDA + nạp trước NSQC, version lock) → Phase2 (e-sign tích hợp hoàn chỉnh + checklist Brand Safety gắn EVALUATION + archive alert). **Ai dùng:** NVKD (soạn từ mẫu), SM/GDKD (duyệt theo ma trận giá trị), legal (review), AM/OPS (nhận ràng buộc vận hành).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): workflow Template → Draft → Legal review → duyệt theo ma trận giá trị → E-sign → Archive; version Draft (v0.x) → Counterparty (v1.x) → Final (v2.0) → Signed (lock cứng); trạng thái HĐ "chờ kích hoạt" khi chưa xác nhận nạp đủ 100% NSQC; retention ≥10 năm.
- `SYS-BCERP-WEB`: soạn từ mẫu IN/OUT of scope; checklist Brand Safety 7 tiêu chí (pass/fail từng tiêu chí); nút "Từ chối vận hành" ghi tiêu chí vi phạm + notify legal + OPS; archive + alert 30/60/90 ngày trước hạn.
- `SYS-MOBILE-INTERNAL` (từ Phase2): GDKD duyệt HĐ giá trị lớn trên di động.

**Tôi cần hệ thống làm được:**
- [ ] Block nhận Full Brief 8 sections khi chưa có NDA mutual signed gắn khách hàng
- [ ] Block kích hoạt chiến dịch khi chưa xác nhận nạp đủ 100% NSQC (K4) — phối hợp Financial Hard Stop
- [ ] Diff check cảnh báo khi điều khoản red-line (không cam kết KPI cứng, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa so với template
- [ ] E-sign theo Luật GDTĐT 2023 với audit trail (thời gian, IP, người ký); tiêu hủy hết hạn chỉ khi có phê duyệt + log hủy

**Quy tắc:** cấm dùng mẫu đối tác khi chưa qua legal review; điều khoản red-line không chấp nhận xóa; không cam kết KPI cứng (lead, CPA, ROAS). **Đặc biệt:** ngưỡng ma trận giá trị HĐ do GDKD/BOD ban hành `[CẦN CHỐT SỐ]`; mẫu đối tác/red-line bị sửa → GDKD + luật sư duyệt 5–7 ngày; toàn bộ điều khoản cần luật sư VN xác nhận trước khi phát hành mẫu chính thức.

#### REQ-SALES-008: Handoff & Onboarding Bridge

**Ưu tiên:** HIGH — **Phase:** Phase2 (GĐ2 — phụ thuộc Capacity & Timesheet cho capacity check). **Ai dùng:** NVKD chủ deal (soạn package), SM (ký), OPS_AM (xác nhận — phối hợp DEPT-OPS).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND`: checklist Handoff Package 5 nhóm — **chặn Gate 2 nếu <100%**; chữ ký 3 bên (Sales/SM/AM); milestone Day 1/7/14/30; tự sinh dự án + capacity check khi WON.
- `SYS-BCERP-WEB` (primary): soạn + theo dõi package; dashboard milestone onboarding; phối hợp OPS xử lý thiếu sót.
- `SYS-MOBILE-INTERNAL` (từ Phase2): push SM ký + AM xác nhận SLA 4h; cảnh báo milestone trễ.

**Tôi cần hệ thống làm được:**
- [ ] Package 5 nhóm checklist đủ 100% mới mở được Gate 2 — thiếu mục nào hiển thị rõ responsible + due date
- [ ] Ký 3 bên trong SLA: AM xác nhận trong 4h từ khi SM ký; fail → trả về SM khắc phục, credit tạm dừng
- [ ] Theo dõi milestone Day 1/7/14/30 sau handoff đến khi onboarding ổn định (sales nhận feedback điểm chưa bàn giao xong)
- [ ] WON tự sinh dự án + AM xác nhận capacity trong 24h — điều kiện mở DEPLOY

**Quy tắc:** handoff ngoài package (miệng/chat) không được công nhận; trạng thái kích hoạt portal của khách hiển thị trong milestone (đọc từ CORE — sales không vận hành portal). **Đặc biệt:** capacity trống = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký Gate 2, tránh ký deal không người chạy.

#### REQ-SALES-009: Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3×

**Ưu tiên:** MEDIUM — **Phase:** Phase3 (GĐ3 — phụ thuộc Công nợ AR GĐ2 + timesheet nhãn billable). **Ai dùng:** toàn bộ L1–L5 (xem credit của mình), GDKD (duyệt clawback/quota), FIN (AR nguồn sự thật), HR (gắn KPI theo cấp).

**Hệ thống liên quan:**
- `SYS-CORE-BACKEND` (primary): credit engine theo thanh toán thực nhận đối chiếu AR (không theo ngày ký); clawback tự động; kiểm soát split ≤100%; khóa kỳ hoa hồng; attainment tự động.
- `SYS-BCERP-WEB`: dashboard coverage/attainment theo cá nhân/nhóm/phòng; luồng phân xử deal trùng; GDKD duyệt điều chỉnh quota giữa kỳ.
- `SYS-MOBILE-INTERNAL` (từ Phase2): alert coverage vàng (<3×)/đỏ (<2×) hàng tuần tới SM + GDKD; thông báo attainment ≥100% + hệ số booster.

**Tôi cần hệ thống làm được:**
- [ ] Chỉ deal ghi nhận trước Gate 2 mới hưởng credit — chặn deal nhập sau Gate 2 hoặc quản lý ngoài hệ thống
- [ ] Bảng hoa hồng theo cấp `[CẦN CHỐT SỐ — mức khởi tạo policy: L1 2,5% → L5 6,5% (L4/L5 cộng 0,5% doanh thu đơn vị)]` + hệ số attainment quý (≥100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; <70% ×0,8)
- [ ] Clawback tự động: khách hủy/hoàn theo tỷ lệ tiền hoàn; nợ quá hạn >90 ngày clawback 100% phần chưa thu; trừ vào kỳ kế tiếp, tham chiếu hóa đơn/phiếu thu/công nợ
- [ ] Split: chủ deal 70% – người hỗ trợ 30%; SM/TPKD hỗ trợ pre-sale tối đa 20% credit deal; tổng mọi split ≤100%; ghi trước Gate 2 — sau Gate 2 cấm bổ sung
- [ ] Quota theo cấp/quý `[CẦN CHỐT SỐ — mức khởi tạo: L1 600 triệu → L5 5 tỷ/phòng]`; pipeline coverage ≥3× = on-track; attainment tự động, cấm nhập tay

**Quy tắc:** khóa kỳ sau khi chốt; mở khóa phải phê duyệt + log; nghỉ ốm/thai sản/chuyển vị trí giữa kỳ — quota theo tỷ lệ ngày làm việc, GDKD duyệt. **Đặc biệt:** HĐ dài hạn >12 tháng credit chia theo từng kỳ thực nhận; deal trả về từ Gate 2 tạm dừng credit đến khi handoff lại thành công; phân xử trùng theo thứ tự REQ-SALES-001.

---

### A4. Dữ Liệu Phòng Ban Cần Quản Lý

| STT | Loại dữ liệu | Thông tin cần lưu | Ghi chú quan trọng |
|---|---|---|---|
| 1 | Lead & khách hàng tiềm năng | Tên công ty, người liên hệ, email/SĐT, website, MST, nguồn lead, lịch sử hoạt động | Anti-duplicate theo email/SĐT/website/MST; không được xóa lead trùng tùy tiện |
| 2 | Bản ghi scoring | autoScore, qualifiedTier, K1–K12 flags, điểm CQ, lịch sử chấm lại | Tách biệt sơ bộ/chốt; khóa qualifiedTier sau Gate 1; audit mọi lần chấm |
| 3 | Quotation | Version, giá theo định mức, chiết khấu, GM, vòng sửa, hiệu lực | Bản gửi khách khóa vĩnh viễn; trace về version định mức hiệu lực |
| 4 | Hợp đồng/LOI/NDA | Version Draft→Signed, trạng thái nạp NSQC, checklist Brand Safety 7 tiêu chí, ngày hiệu lực/hết hạn | Lock sau Signed; retention ≥10 năm; alert 30/60/90 ngày |
| 5 | Handoff Package | 5 nhóm checklist, chữ ký 3 bên, milestone Day 1/7/14/30 | Chặn Gate 2 nếu <100% |
| 6 | Chỉ tiêu & credit hoa hồng | Quota theo cấp/quý, thanh toán thực nhận, split, clawback, hệ số attainment | Khóa kỳ sau chốt; attainment cấm nhập tay; tổng split ≤100% |

---

### A5. Báo Cáo & Thống Kê Cần Có

| STT | Tên báo cáo | Nội dung | Tần suất | Người xem |
|---|---|---|---|---|
| 1 | Pipeline funnel theo stage | Conversion, độ tuổi deal, deal kẹt SLA | Tuần | NVKD, SM |
| 2 | Win rate theo tier + độ chính xác scoring | So độ lệch điểm CQ vs kết quả thực | Quý | GDKD, BOD |
| 3 | GM thực tế vs tối thiểu | Theo deal/NVKD/nhóm dịch vụ; cảnh báo GM dưới ngưỡng | Tháng | GDKD, BOD |
| 4 | Coverage & attainment realtime | Theo cấp L1–L5, so quota kỳ, alert vàng/đỏ | Realtime/tuần | SM, GDKD |
| 5 | Danh mục HĐ sắp hết hạn / chờ nạp NSQC / bị từ chối vận hành | Ngày hạn, trạng thái kích hoạt, tiêu chí vi phạm | Tháng | SM, GDKD, legal |
| 6 | Credit/clawback/aging ảnh hưởng hoa hồng | Credit theo nhân sự, clawback kỳ, nợ >90 ngày | Tháng | GDKD, FIN, HR |
| 7 | SLA compliance & gate pass rate | Theo stage/nhân sự, escalation đã chạy | Tuần | SM, GDKD |

---

### A6. Điều Phòng Ban KHÔNG Muốn

- Không cho nhập deal/lead ngoài hệ thống — nguyên tắc "không ghi nhận = không tồn tại" phải áp dụng cả với cấp quản lý.
- SM/GDKD không sửa điểm scoring trực tiếp — chỉ bổ sung dữ liệu rồi chấm lại; sửa tay là mất niềm tin vào tier.
- Không sửa quotation đã gửi khách — mọi chỉnh sửa chỉ qua version mới có duyệt lại.
- NVKD không được thấy giá vốn/GM của người khác; chiết khấu ẩn phải bị hệ thống chặn, không phải dựa vào tự giác.
- Không bổ sung split credit sau Gate 2 — tranh chấp "deal credit cho ai" là rủi ro tranh chấp nội bộ lớn nhất, chặn cứng từ nguồn.
- Không để nhân viên nghỉ làm mất pipeline — chuyển quản lead/deal có audit log, không xóa.
- Hoa hồng không tính theo ngày ký hợp đồng — chỉ theo thanh toán thực nhận (tránh đua ký rồi bỏ mặc thu tiền).

---

### A7. Đánh Giá Của Team Expert

*Điền ở bước đánh giá chuyên gia sau khi Phần A được review — gồm kết quả đánh giá tổng thể (đầy đủ/khả thi/rõ ràng/trùng lặp), điểm cần làm rõ theo REQ-ID, điều chỉnh sau đánh giá, và ký xác nhận của expert phụ trách, team expert, đại diện phòng ban.*

---

## Phần B — Quy Trình Nghiệp Vụ & Business Rules (Sales Expert Review)

> **Người review:** sales-expert (Sales Director) — 12/09/2026. Phần B bám sát 9 REQ của Phần A, không tạo REQ mới. Mã business rule `BR-SALES-XYZ`. Căn cứ: policies `phan-loai-khach-hang-tier.md`, `bang-gia-chiet-khau-gross-margin.md`, `hoa-hong-sales-quota.md`, `hop-dong-loi-nda-brand-safety.md`, `stage-gate-lifecycle-v6.md`, `P0-02-systems-users.md`.

### B.0. Nguyên Tắc Xuyên Suốt

**BR-SALES-000 — Hard gate "Không ghi nhận = Không tồn tại".** Mọi lead, deal, meeting notes, split credit, chữ ký gate, kết quả thẩm định phải có bản ghi trên hệ thống trước khi phát sinh hệ quả (chuyển stage, vận hành, hoa hồng). Deal không có bản ghi trong pipeline trước Gate 2: không được vận hành và không được tính credit hoa hồng — kể cả khi SM/GDKD xác nhận miệng. Thực thi chặn 2 tầng: UI vô hiệu hóa nút + API từ chối request; mọi ngoại lệ phải có phê duyệt và audit log bất biến.

**Nguyên tắc multi-system (không giả định web = mobile):** CORE là engine nguồn sự thật (validation, approval engine, SLA clock, audit log WORM); WEB là mặt làm việc chính (pipeline, soạn quotation/hợp đồng, dashboard); MOBILE là kênh ký duyệt và cảnh báo push — từ Phase2 là kênh ký chính của Gate 1/Gate 2. Mọi ký/duyệt giá trị cao trên MOBILE yêu cầu MFA step-up (TOTP) với token gắn device theo P0-02 §2.4; MOBILE không dùng cho nhập liệu hàng loạt (lead, quotation, hợp đồng).

### B.1. REQ-SALES-001 — Thu Lead Đa Kênh & Anti-Duplicate

1. **Tiếp nhận (CORE):** lead từ landing page (webhook), Zalo OA, Fanpage/Messenger đổ về pipeline trong vài phút, tự gắn tag nguồn + chiến dịch, vào stage Raw Data. Ngoại lệ: kênh webhook lỗi → hàng đợi retry, không mất lead; retry vượt ngưỡng `[CẦN CHỐT SỐ — số lần/tần suất]` → alert SYS_ADMIN + SM.
2. **Nhập tay (WEB):** lead referral/cold do NVKD nhập form tối thiểu (tên công ty, người liên hệ, email/SĐT, nguồn lead). MOBILE chỉ nhận push lead mới, không nhập lead.
3. **Anti-duplicate (BR-SALES-101, CORE):** khi tạo lead, hệ thống chuẩn hóa rồi so khớp với lead đang mở theo SĐT (chuẩn E.164), email (lowercase), domain website (bỏ www), MST. **Định nghĩa trùng theo trọng số:** khớp ≥2/4 trường → trùng chắc chắn (flag cứng); khớp 1 trường định danh mạnh (SĐT/email/MST) → trùng tiềm năng (flag review); chỉ khớp tên công ty (fuzzy) → nghi vấn `[CẦN CHỐT SỐ — ngưỡng fuzzy và bảng trọng số chốt khi thiết kế rule engine]`. Lead trùng bị flag kèm người ghi trước + bằng chứng hoạt động — không chặn mù.
4. **Tranh chấp nguồn (BR-SALES-102):** (1) người ghi trước có bằng chứng (email/call/meeting log) giữ lead; (2) hòa → SM phân xử SLA 24h; (3) khiếu nại → GDKD quyết cuối SLA 3 ngày làm việc, audit log. Cấm tự gộp/xóa lead trùng không qua phân xử.
5. **Kỷ luật nguồn (BR-SALES-103):** cấm giữ lead trên Zalo cá nhân/Sheets; lead cũ quay lại ≤180 ngày giữ nguyên lịch sử scoring, được chấm lại đúng 1 lần với dữ liệu mới.

### B.2. REQ-SALES-002 — Pipeline V6.0, Hard Gate & Phân Bổ Lead

1. **Stage machine (CORE, BR-SALES-201):** 10 stage V6.0; hard block chuyển stage thiếu done criteria ở cả UI và API; audit log bất biến mọi chuyển stage.
2. **Initial Brief (BR-SALES-202):** SLA 2h từ Raw Data, đủ 3 trường bắt buộc Ngân sách / Sản phẩm-dịch vụ / Nhu cầu; quá hạn cảnh báo rồi escalate cấp trên trực tiếp.
3. **Meeting notes:** bắt buộc trước QUALIFIED — không notes = meeting không được công nhận.
4. **Phân bổ lead mới (BR-SALES-203, WEB):** lead kênh tự gán owner theo quy tắc nguồn (kênh chủ quản); lead tự do → SM gán trong 4h giờ làm việc `[CẦN CHỐT SỐ — SLA gán và quy tắc round-robin chưa có chính sách ban hành]`; tranh chấp nguồn giải theo B.1.
5. **WON:** cập nhật trong 24h → tự sinh dự án + AM xác nhận capacity (nối REQ-SALES-008).
6. Ngoại lệ: khách tái ký rút gọn Initial Brief nhưng không bỏ Gate 1/Gate 2; deal hủy trước Gate 1 chỉ lưu hồ sơ. Trên MOBILE sales chỉ xem board + nhận cảnh báo SLA, không di chuyển stage trên di động (WEB là primary).

### B.3. REQ-SALES-003 — AUTO SCORING K1–K12 & Tier A–E

1. **Chấm 2 lần (BR-SALES-301, CORE):** autoScore tại Initial Brief (quyết bypass First Meeting); qualifiedTier sau Full Brief 8 sections (tier vận hành); khóa qualifiedTier sau khi SM ký Gate 1.
2. **Knockout vs cộng điểm (BR-SALES-302):** **K1–K5 là knockout tuyệt đối — fail bất kỳ → AUTO LOST:** K1 sản phẩm hạn chế thiếu giấy phép (Luật Quảng cáo 2012); K2 khách từ chối điều khoản trách nhiệm (không cam kết KPI cứng / cap trách nhiệm / miễn trừ nền tảng); K3 ngành cấm hoặc nhạy cảm chưa duyệt nội bộ; K4 không chấp nhận nạp trước 100% NSQC; K5 — đề xuất mặc định (AI-recommended, Phase 6d): **"Khách thuộc danh sách FATF high-risk / bị chế tài quốc tế / không xác thực được UBO"**, khớp chuỗi AML/KYC (KYC fail → scoring knockout, nối BR-FIN-403/404) `[CẦN CHỐT SỐ — chờ policy Lead Scoring & Qualification chốt trước khi code engine]`. **K6–K12 là flag cộng/trừ điểm cảnh báo** (không chặn), dùng để buộc sales bổ sung dữ liệu.
3. **Điểm CQ:** 5 tiêu chí trọng số 30/25/20/15/10 thang 1–5 → thang 1.0–5.0; thiếu dữ liệu ≥2/5 → chặn chấm, trạng thái "Thiếu dữ liệu", cấm đoán điểm thủ công.
4. **Tier A–E nghịch trực giác (BR-SALES-303):** A <1.5 AUTO LOST (trừ tư vấn theo K4); B 1.5–1.99 và C 2.0–2.99 First Meeting bắt buộc; D 3.0–3.49 borderline — SM thẩm định SLA 4h, quá hạn escalate GDKD, kết quả kèm lý do; E ≥3.5 SM được bypass First Meeting. Hệ quả theo tier: B/C proposal Planner 15–25 trang + vòng sửa quotation ≤4; D/E proposal AM 8–12 trang + vòng sửa ≤2; tier quyết template/SLA/vòng sửa. UI phải chú giải nghĩa từng tier, cấm hardcode nhãn tier trong code.
   ⚠ **Phát hiện review:** bảng Stage-Gate §2.1 dòng PROPOSAL đang đảo số trang/người soạn giữa B/C và D/E so với policy tier (nguồn sự thật cho Tier A–E) — đề xuất hiệu chỉnh stage-gate trước khi thiết kế.
5. SM không sửa điểm trực tiếp — chỉ bổ sung dữ liệu rồi chấm lại; khách do đối tác (Google/TikTok/Yandex) giới thiệu không được bypass scoring; khách BOD-sponsored gắn nhãn riêng nhưng vẫn chấm qualifiedTier; mọi chấm/chấm lại/bypass/thẩm định ghi audit log.

### B.4. REQ-SALES-004 — Gate 1 & Gate 2 (Go/No-Go và Ký Handoff)

**Gate 1 — QUALIFIED, Go/No-Go (BR-SALES-401):** SM ký.
- **Entry (machine-checkable):** Full Brief 8 sections đủ; NDA mutual signed gắn khách (REQ-SALES-007); qualifiedTier có giá trị (không "Thiếu dữ liệu"); meeting notes đã ghi (bắt buộc với B/C; bypass D/E phải có lý do SM).
- **Done:** SM ký Go/No-Go trong SLA 1 ngày làm việc → khóa qualifiedTier.
- **Ai ký, kênh nào:** SM (phải khác NVKD chủ deal — cấm tự duyệt deal của mình). WEB đầy đủ từ MVP; **MOBILE là kênh ký chính từ Phase2** — push gate chờ duyệt, ký với MFA step-up + token gắn device.
- **Exception:** quá SLA → escalate tự động GDKD rồi BOD + log; No-Go → dừng, lưu hồ sơ; override knockout K1–K5 chỉ cho deal chiến lược được chỉ định, lý do bằng văn bản + GDKD phê duyệt lại, log bất biến.

**Gate 2 — LEAD, ký Handoff (BR-SALES-402):** SM ký + AM xác nhận.
- **Entry:** Handoff Package 5 nhóm đủ 100% (REQ-SALES-008); capacity check không bằng 0.
- **Done:** SM ký → **AM xác nhận trong SLA 4h**; đồng thời điều kiện tiền: chưa xác nhận nạp đủ **100% NSQC** → hợp đồng "chờ kích hoạt", block tạo chiến dịch (bắt tay Financial Hard Stop).
- **Exception:** AM từ chối → trả về SM khắc phục, credit hoa hồng tạm dừng đến handoff lại thành công; quá SLA 4h escalate tự động; SLA tính giờ làm việc cấu hình.

### B.5. REQ-SALES-005 — Chuyển Tier Sales → CS & Rà Quý

1. WON → tier chuyển nguyên trạng cho CS (CORE, BR-SALES-501), không nhập lại.
2. **Đề xuất chuyển tier trong kỳ (BR-SALES-502):** theo doanh thu thực tế của hợp đồng + số TKQC active + churn risk (health score); CS đề xuất → SM + CS TL đồng thuận → GDKD duyệt SLA 3 ngày làm việc; mọi thay đổi có lý do + audit log.
3. **Rà quý (BR-SALES-503):** GDKD rà win rate theo tier + độ lệch điểm CQ vs kết quả thực; hiệu chỉnh ngưỡng/trọng số GDKD trình BOD — tham số version hóa effective-dated, không sửa quá khứ.
4. WEB chạy luồng đề xuất + dashboard win rate/độ chính xác scoring; CORE lưu tham số; MOBILE push GDKD duyệt (Phase2). Khách strategic BOD-sponsored vẫn phải có qualifiedTier.

### B.6. REQ-SALES-006 — Quotation & Deal Desk

Quy trình chuẩn (BR-SALES-601):
1. **Tính giá từ định mức (WEB):** Accountant (FIN phối hợp) lập theo định mức version hiện hành (giá media sau CK agency, định mức giờ L1–L5, phí nền tảng, dự phòng rủi ro); quotation trace về đúng version định mức hiệu lực tại thời điểm phát hành.
2. **GM engine (CORE, BR-SALES-602):** tự tính GM theo nhóm dịch vụ — agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%; dưới ngưỡng → cảnh báo đỏ. Media pass-through giá vốn 0 GM nhưng phải tính đủ phí dịch vụ.
3. **Duyệt chiết khấu phân cấp (BR-SALES-603):** NVKD ≤5% tự duyệt (GM đạt ngưỡng, tức thời); >5–15% TPKD SLA 8h làm việc; >15–20% GDKD SLA 1 ngày kèm nhận định chiến lược; >20% BOD SLA 2 ngày, quyết bằng văn bản. GM dưới ngưỡng → GDKD (đến 20%) hoặc BOD duyệt. MOBILE (Phase2): TPKD/GDKD duyệt qua push + MFA step-up.
4. **Duyệt GM:** GDKD phối hợp FIN; giá vốn/GM là dữ liệu Mật — NVKD không xem.
5. **Version control & gửi khách (BR-SALES-604):** gửi chỉ khi đủ duyệt; bản gửi khách khóa vĩnh viễn read-only + log người gửi/thời điểm/nội dung; sửa = version mới + duyệt lại; vòng sửa theo tier D/E ≤2, B/C ≤4 — vượt chặn, GDKD mở exception có lý do; biến động tỷ giá/phí nền tảng >5% → version điều chỉnh không tính vào vòng sửa.
6. **Hiệu lực:** 30 ngày (tối đa 60 cho HĐ năm/đa giai đoạn); hết hạn tự chuyển "Hết hạn" → tiếp tục bán phải re-quote theo định mức hiện hành. Sau duyệt GM tối đa 2 ngày làm việc phải gửi KH, quá hạn cảnh báo SM + GDKD.
Ngoại lệ: pilot 1 tháng được GM dưới ngưỡng tối đa một kỳ và ≤60 ngày (GDKD duyệt kèm mục tiêu chuyển đổi); tái ký trong 12 tháng giữ bảng giá cũ tối đa 1 lần; khách BOD-sponsored ngoài ma trận bằng văn bản; cấm chiết khấu ẩn (tặng giờ/tài nguyên không ghi giá không qua duyệt).

### B.7. REQ-SALES-007 — HĐ/LOI/NDA & Brand Safety + E-sign

Luồng chuẩn (BR-SALES-701): Template (mẫu chuẩn legal duyệt) → Draft v0.x (WEB soạn từ mẫu IN/OUT of scope) → Legal review → duyệt theo ma trận giá trị `[CẦN CHỐT SỐ — ngưỡng do GDKD/BOD ban hành]` → Counterparty v1.x → Final v2.0 → E-sign → Signed (lock cứng) → Archive.
- **NDA mutual trước Full Brief (BR-SALES-702):** CORE block nhận Full Brief 8 sections khi chưa có NDA mutual signed gắn khách — sales không được trigger bước nhận brief. LOI/MOU đàm phán được ký trước HĐ chính nhưng vẫn cấm nhận brief khi chưa có NDA.
- **Brand Safety 7 tiêu chí (BR-SALES-703):** (1) SP hợp pháp + giấy phép con; (2) không vi phạm Ads Policy nền tảng; (3) không spam/misleading; (4) quyền image/video/bản quyền hợp lệ; (5) landing page hợp pháp khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập; (7) không ngành cấm/nhạy cảm chưa duyệt nội bộ. Checklist pass/fail từng tiêu chí gắn stage EVALUATION; fail bất kỳ → dừng, không sang PROPOSAL; nút "Từ chối vận hành" ghi tiêu chí vi phạm + notify legal + OPS (legal xác nhận + TP Vận hành, 24h); vi phạm K1 → chấm dứt hợp đồng.
- **Nạp trước 100% NSQC:** chưa xác nhận nạp đủ → trạng thái "chờ kích hoạt", block tạo chiến dịch ở tầng máy.
- **Red-line (BR-SALES-704):** diff check cảnh báo khi điều khoản không cam kết KPI cứng / cap trách nhiệm / miễn trừ nền tảng bị xóa-sửa so với template; dùng mẫu đối tác hoặc đụng red-line → GDKD + luật sư duyệt 5–7 ngày làm việc.
- **E-sign (BR-SALES-705):** theo Luật GDTĐT 2023 và NĐ 91/2022 — chữ ký số CA cấp bởi tổ chức chứng thực, audit trail thời gian/IP/người ký; archive alert 30/60/90 ngày trước hạn; retention ≥10 năm; tiêu hủy hết hạn chỉ khi có phê duyệt + log hủy. MOBILE (Phase2): GDKD duyệt HĐ giá trị lớn.

### B.8. REQ-SALES-008 — Handoff & Onboarding Bridge

- **Package 5 nhóm (BR-SALES-801, CORE):** Handoff Package 5 nhóm checklist theo chuẩn Handoff Package — mỗi mục có responsible + due date; **chặn Gate 2 nếu <100%**, thiếu mục nào hiển thị rõ thiếu gì.
- **Ký 3 bên (BR-SALES-802):** NVKD chủ deal soạn → SM ký → AM xác nhận trong SLA 4h; AM từ chối → trả về SM khắc phục, credit tạm dừng. MOBILE (Phase2): push SM ký + AM xác nhận + cảnh báo trễ.
- **Ranh giới Sales ↔ OPS:** Sales soạn package, bàn giao và theo dõi milestone đến khi onboarding ổn định; OPS (AM) thực thi onboarding và vận hành chiến dịch. Phát sinh thiếu sót trong Day 1–30 quay về SM khắc phục theo package — OPS không nhận việc ngoài package (handoff miệng/chat không được công nhận).
- **Milestone Day 1/7/14/30 (BR-SALES-803):** dashboard theo dõi trên WEB; trạng thái kích hoạt portal của khách hiển thị trong milestone (đọc từ CORE — sales không vận hành portal).
- WON tự sinh dự án + AM xác nhận capacity trong 24h — điều kiện mở DEPLOY; capacity trống = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký Gate 2 (tránh ký deal không người chạy).

### B.9. REQ-SALES-009 — Commission & Quota

1. **Credit (BR-SALES-901, CORE):** tính theo **thanh toán thực nhận** đối chiếu sổ AR (FIN nguồn sự thật) — không theo ngày ký; chỉ deal có bản ghi PMS trước Gate 2 + qualifiedTier hợp lệ + quotation đã duyệt GM mới hưởng; doanh thu chỉ đếm phần phí dịch vụ/markup, không đếm pass-through NSQC.
2. **Thang hoa hồng L1–L5** `[CẦN CHỐT SỐ — mức khởi tạo chờ xác nhận: L1 2,5% → L5 6,5%; L4/L5 cộng 0,5% doanh thu đơn vị]` + hệ số attainment quý (≥100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; <70% ×0,8).
3. **Clawback (BR-SALES-902):** khách hủy/hoàn phí → hồi hoa hồng theo tỷ lệ tiền hoàn; nợ quá hạn >90 ngày → clawback 100% phần chưa thu; trừ vào kỳ kế tiếp; FIN xác nhận số liệu + GDKD duyệt SLA 3 ngày làm việc kể từ khi aging vượt 90; luôn dẫn chiếu hóa đơn/phiếu thu/công nợ.
4. **Split (BR-SALES-903):** chủ deal 70% – người hỗ trợ 30%; SM/TPKD hỗ trợ pre-sale tối đa 20% credit deal; tổng mọi split ≤100%; ghi trước Gate 2 — sau Gate 2 chặn bổ sung cứng.
5. **Tranh chấp nguồn lead:** credit cho người thắng phân xử theo B.1 (ghi trước có bằng chứng; hòa SM 24h; khiếu nại GDKD quyết cuối, audit log).
6. **Quota & coverage (BR-SALES-904):** quota theo cấp/quý `[CẦN CHỐT SỐ — khởi tạo L1 600 triệu → L5 5 tỷ/phòng]`; pipeline coverage ≥3× quota kỳ kế tiếp = on-track; <2× đỏ → bắt buộc kế hoạch bổ sung lead, SM chịu trách nhiệm; attainment tự động, cấm nhập tay. MOBILE (Phase2): alert coverage vàng (<3×)/đỏ (<2×) hàng tuần tới SM + GDKD; thông báo attainment ≥100% + booster.
7. HĐ dài hạn >12 tháng credit chia theo từng kỳ thực nhận; deal trả về từ Gate 2 tạm dừng credit đến handoff lại thành công; nghỉ ốm/thai sản/chuyển vị trí giữa kỳ → quota theo tỷ lệ ngày làm việc (GDKD duyệt); khóa kỳ hoa hồng sau khi chốt, mở khóa phải phê duyệt + log.

### B.10. Ma Trận Business-Rules × System

Quy ước: **Thực thi** = engine/chặn tại system; **Nhập/Xem** = thao tác người dùng; **Ký/Push (P2)** = từ Phase2. Mọi rule được thực thi ở CORE kể cả khi UI ở kênh khác.

| Business Rule | SYS-CORE-BACKEND | SYS-BCERP-WEB | SYS-MOBILE-INTERNAL | Ghi chú |
|---|---|---|---|---|
| BR-SALES-101 Anti-duplicate weighted | Thực thi matching | Form nhập + kết quả so khớp | — | Chạy cả API webhook lẫn nhập tay |
| BR-SALES-102 Phân xử lead trùng | Khóa quyết định + audit | Hàng đợi SM/GDKD | Push (P2) | SLA 24h / 3 ngày làm việc |
| BR-SALES-103 Kỷ luật nguồn + retry webhook | Queue retry + alert | Xem lịch sử lead | Push lead mới (P2) | Không mất lead, không giữ ngoài hệ thống |
| BR-SALES-201 Hard gate stage | Block UI + API | Board + nút stage vô hiệu | Chỉ xem | Audit log bất biến |
| BR-SALES-202 SLA Initial Brief 2h | SLA clock + escalate | Cảnh báo trên board | Push (P2) | 3 trường bắt buộc |
| BR-SALES-203 Phân bổ lead | Auto-assign engine | SM gán owner | Push (P2) | SLA 4h `[CẦN CHỐT SỐ]` |
| BR-SALES-301 Scoring 2 lần + khóa qualifiedTier | Chấm + khóa sau Gate 1 | Hiển thị điểm + lý do | — | Cấm sửa điểm trực tiếp |
| BR-SALES-302 Knockout K1–K5 / flag K6–K12 | AUTO LOST | Hiển thị lý do loại | — | Override log bất biến |
| BR-SALES-303 Tier map + hệ quả | Map 1.5/2.0/3.0/3.5 | Chú giải nghĩa tier | — | Cấm hardcode nhãn tier |
| BR-SALES-401 Gate 1 e-approval SLA 1 ngày | Approval engine + escalate | Màn hình duyệt đầy đủ | Kênh ký chính (P2) + MFA step-up | SM ≠ chủ deal |
| BR-SALES-402 Gate 2 + nạp 100% NSQC | Chặn kích hoạt thiếu nạp | Checklist + ký | Ký/confirm push (P2) | Bắt tay Financial Hard Stop |
| BR-SALES-501 Chuyển tier Sales → CS | Đồng bộ nguyên trạng | Luồng đề xuất + duyệt GDKD | Push (P2) | SLA 3 ngày làm việc |
| BR-SALES-502/503 Tham số tier version hóa | Effective-dated | Dashboard rà quý | — | GDKD trình BOD |
| BR-SALES-601/602 GM engine theo định mức | Tính GM + cảnh báo đỏ | Soạn quotation trace version | — | Giá vốn = dữ liệu Mật |
| BR-SALES-603 Ma trận chiết khấu | Chặn gửi thiếu duyệt | Tạo yêu cầu duyệt | Duyệt push (P2) + MFA | SLA 8h / 1 ngày / 2 ngày |
| BR-SALES-604 Version lock + hiệu lực | Khóa read-only + auto hết hạn | Gửi khách + version mới | — | Vòng sửa D/E ≤2, B/C ≤4 |
| BR-SALES-701–702 NDA block Full Brief | Block máy khi chưa NDA | Soạn từ mẫu IN/OUT scope | — | Sales không trigger brief |
| BR-SALES-703 Brand Safety 7 tiêu chí | Chặn PROPOSAL khi fail | Checklist pass/fail + nút từ chối vận hành | — | Fail 1/7 → dừng |
| BR-SALES-704 Red-line diff check | Cảnh báo diff so template | Xem cảnh báo | — | Đụng red-line → GDKD + luật sư |
| BR-SALES-705 E-sign GDTĐT + retention | Audit trail + archive + alert 30/60/90 | Ký/xem hồ sơ | Duyệt HĐ lớn (P2) | Retention ≥10 năm |
| BR-SALES-801/802 Handoff ký 3 bên | Chặn Gate 2 <100% | Soạn + theo dõi package | Ký + push (P2) | SLA AM 4h |
| BR-SALES-803 Milestone Day 1/7/14/30 | Tracking + trạng thái portal | Dashboard milestone | Cảnh báo trễ (P2) | Ranh giới Sales/OPS |
| BR-SALES-901/903 Credit thực nhận + split | Credit engine + chặn split | Dashboard + phân xử | Alert (P2) | Thực nhận ≠ ngày ký |
| BR-SALES-902 Clawback >90 ngày | Tự tạo dòng clawback | Xem clawback kỳ | — | FIN xác nhận + GDKD duyệt |
| BR-SALES-904 Coverage/attainment | Tính tự động | Dashboard realtime | Alert vàng/đỏ (P2) | Cấm nhập tay attainment |

> **Tổng hợp:** CORE thực thi toàn bộ 25 business rules; WEB là kênh thao tác chính cho 24/25; MOBILE không có rule nào chỉ chạy riêng trên mobile — mọi ký/duyệt mobile (P2) đi qua approval engine của CORE với MFA step-up. Không rule nào áp dụng web≠mobile về logic nghiệp vụ — chỉ khác kênh tương tác và cơ chế xác thực.

---
