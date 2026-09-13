# Tính Năng: Gate 1 & Gate 2 — Go/No-Go và ký Handoff (Mobile Nội Bộ)

> **Dựa trên:** REQ-SALES-004 trong `phase1-business/departments/sales/sales.md` (Phần A §A3, Phần B §B.4)
> **Phân hệ:** Hệ Mobile Nội Bộ (SYS-MOBILE-INTERNAL)
> **Module:** CRM & Lead Pipeline V6.0 (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/` (file 02, 08, 09, 10 — v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/crm-pipeline/*.md`, `phase5-implementation/tasks/mobile-internal/crm-pipeline/feat-mbi-crm-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID sinh từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-SALES-004 fan-out trên 3 hệ thống (SYS-CORE-BACKEND, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL); bản spec này là slice riêng cho SYS-MOBILE-INTERNAL — kênh ký duyệt di động chính từ Phase2, đúng mục đích khai báo "SALES_L2–L5 duyệt di động" của app nội bộ. Counterparts: slice SYS-CORE-BACKEND (approval engine, SLA clock, audit log, chặn gate thiếu điều kiện) và slice SYS-BCERP-WEB (màn hình duyệt đầy đủ từ MVP).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CRM-001 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-004 |
| Người dùng liên quan | SALES_L4 (TPKD — ký Gate 1/Gate 2 với tư cách SM theo `[KXN-14]`), SALES_L5 (GDKD — nhận escalate, duyệt override knockout), SALES_L2 (NVKD chủ deal — nhận kết quả gate), SALES_L3 (TNKD — xem hàng đợi/dashboard nhóm), OPS_AM (xác nhận tiếp nhận Gate 2, SLA 4h), BOD_CEO/BOD_CFO_CTO (nhận escalate mức cuối) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase 2 — approval engine và màn hình ký WEB đã có từ MVP; MOBILE trở thành kênh ký chính của Gate 1/Gate 2 từ Phase 2) |
| Phụ thuộc | Không có cross-dependency FEAT được khai báo cho lane này. Điều kiện kỹ thuật: approval engine, SLA clock, escalation và audit log WORM phải sẵn có tại SYS-CORE-BACKEND (slice REQ-SALES-004 của CORE); trạng thái Handoff Package 5 nhóm và capacity check đọc từ slice REQ-SALES-008 (mobile-internal/handoff-onboard) |
| Ghi chú Expert (A7) | `sales.md` có mục A7 nhưng chưa điền điều chỉnh cụ thể cho REQ-SALES-004; chuyên môn đã phản ánh tại Phần B (BR-SALES-401/402). Quyết định `[KXN-14]` (SM = SALES_L4 TPKD) được đưa vào phân quyền của spec này — lưu ý bảng A1 của `sales.md` hiện vẫn xếp SM ở SALES_L3, RBAC phải cấu hình theo ánh xạ vai chốt tại thời điểm triển khai |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép Sales Manager ký Gate 1 (Go/No-Go trên `qualifiedTier`, SLA 1 ngày làm việc) và Gate 2 (ký Handoff, kèm xác nhận tiếp nhận của AM trong SLA 4h) ngay trên điện thoại với MFA step-up và token gắn device — biến di động thành kênh ký chính của hai điểm quyết định quan trọng nhất trong nửa đầu Lifecycle V6.0. Nhờ vậy, hai gate approval không bao giờ treo vì người ký vắng mặt, escalation quá SLA chạy tự động, và mọi chữ ký đều có audit trail bất biến đúng nguyên tắc hard gate "không ghi nhận = không tồn tại".

**Phạm vi:**
- Bao gồm: nhận push gate chờ ký (Gate 1/Gate 2) kèm SLA đếm ngược; xem hồ sơ gate trên di động (`qualifiedTier`, thành điểm CQ theo trọng số 30/25/20/15/10, checklist điều kiện vào gate, lịch sử scoring, trạng thái Handoff Package/capacity/nạp 100% NSQC); ký Gate 1 Go/No-Go và Gate 2 Handoff với MFA step-up (TOTP gắn device, P0-02 §2.4); AM xác nhận/từ chối tiếp nhận Gate 2 kèm lý do; escalate tự động quá SLA (GDKD rồi BOD) qua push; GDKD duyệt override knockout K1–K5 kèm lý do văn bản; offline-capable (đọc offline, ký đã qua MFA xếp hàng đồng bộ có đối chiếu trạng thái); dashboard hàng đợi gate; audit log mọi hành động ký/duyệt từ mobile.
- Không bao gồm: soạn Handoff Package, checklist 5 nhóm, capacity planning (slice REQ-SALES-008 — mobile chỉ đọc trạng thái); nhập lead, di chuyển stage, soạn quotation/proposal trên di động (WEB là kênh chính, mobile cấm nhập liệu hàng loạt); chấm AUTO SCORING và khóa `qualifiedTier` ở tầng engine (CORE enforce); block kích hoạt chiến dịch khi thiếu nạp 100% NSQC (Financial Hard Stop CORE/FIN); chữ ký khách hàng (e-sign thuộc REQ-SALES-007).

---

## 2. Luồng Người Dùng (User Stories)

> Các user story dưới đây đặc thù touchpoint mobile nội bộ: app React Native, offline-capable, tối ưu cho duyệt-on-the-go — mọi nghiệp vụ ghi nhận vẫn đi qua approval engine của CORE, mobile chỉ là kênh ký và hiển thị.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L4 (SM — người ký gate) | Nhận push Gate 1 chờ ký kèm `qualifiedTier`, điểm CQ từng tiêu chí và checklist điều kiện vào gate, rồi ký Go/No-Go với MFA step-up ngay trên di động trong SLA 1 ngày làm việc | Hai điểm quyết định không treo khi tôi đi công tác/không trước máy tính; mỗi chữ ký có audit trail thời gian/IP/device |
| 2 | SALES_L4 (SM) | Nhận push Gate 2 khi Handoff Package 5 nhóm đã đủ 100% và capacity ≠ 0, xem tóm tắt checklist rồi ký Handoff trên di động | Bàn giao Sales → Vận hành không chậm trễ, và tôi không ký một package thiếu điều kiện |
| 3 | OPS_AM (Account Manager) | Nhận push xác nhận tiếp nhận ngay sau SM ký Gate 2, bấm xác nhận trong 4h giờ làm việc hoặc từ chối kèm lý do cụ thể | Ranh giới Sales ↔ OPS rõ ràng; thiếu sót trả về SM khắc phục thay vì OPS gánh việc ngoài package |
| 4 | SALES_L2 (NVKD chủ deal) | Nhận push kết quả Gate 1 (Go/No-Go kèm lý do nếu No-Go) và Gate 2 (ký/xác nhận/trả về kèm thiếu sót) | Biết ngay việc tiếp theo; hiểu rõ credit hoa hồng tạm dừng khi deal bị trả về từ Gate 2 là trạng thái minh bạch trên hệ thống |
| 5 | SALES_L5 (GDKD) | Nhận push escalate khi gate quá SLA, và duyệt override knockout K1–K5 cho deal chiến lược kèm lý do bằng văn bản | Kiểm soát exception mà không cần vào web; mọi phê duyệt exception đều log bất biến |
| 6 | SALES_L3 (TNKD) | Xem dashboard nhóm trên di động: hàng đợi gate chờ ký, gate sắp quá SLA, deal borderline đang thẩm định | Đôn đốc nhóm trước khi quá hạn thay vì đợi escalation nổ ra |
| 7 | SALES_L4 (SM) | Đọc hồ sơ gate offline khi mất mạng, và hành động ký đã qua MFA được xếp hàng đồng bộ với đối chiếu trạng thái máy chủ | Mạng chập chờn không làm mất chữ ký, cũng không ghi đè nhầm khi gate đã đổi trạng thái |
| 8 | BOD_CEO / BOD_CFO_CTO | Nhận push escalate mức cuối khi gate quá SLA qua cả GDKD | Quyết định cấp cao nhất được đưa đúng người đúng lúc, có hồ sơ đầy đủ trên mobile |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Mọi rule được thực thi ở SYS-CORE-BACKEND kể cả khi thao tác ký đến từ mobile (sales.md B.10); mobile không có rule nào chỉ chạy riêng trên mobile. Các giả định từ bộ quy trình v1.1 gắn tag `[KXN-n]` — không tự quyết các khoản còn mở.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MBI-CRM-101 | Hard gate Pipeline V6.0 "không ghi nhận = không tồn tại": mọi quyết định Gate 1/Gate 2, chữ ký, kết quả thẩm định, override phải có bản ghi trên hệ thống trước khi phát sinh hệ quả (khóa tier, chuyển stage, bàn giao, tính credit). Xác nhận miệng qua Zalo/chat không được công nhận. Thực thi chặn 2 tầng (UI vô hiệu nút + API từ chối) ở CORE; mobile chỉ phản ánh bản ghi CORE | Yêu cầu ký/ghi nhận ngoài bản ghi hệ thống bị API từ chối; mobile hiển thị hướng dẫn ghi nhận chính thức thay vì cho phép "xác nhận tạm" |
| BR-MBI-CRM-102 | Mô hình 5 tier A–E theo V6.0 là chuẩn chính thức (`[KXN-1]` đã chốt): A <1.5 AUTO LOST (trừ tư vấn theo K4) → B 1.5–1.99 → C 2.0–2.99 → D 3.0–3.49 borderline → E ≥3.5 được bypass First Meeting/ưu tiên tài nguyên. `qualifiedTier` là đầu vào bắt buộc của Gate 1 và bị khóa vĩnh viễn ngay khi SM ký Gate 1. Nhãn tier nghịch trực giác (A = tệ nhất, E = tốt nhất) — UI mobile phải chú giải nghĩa từng tier, cấm hardcode nhãn trong code | Gate 1 thiếu `qualifiedTier` hoặc đang "Thiếu dữ liệu" không mở được màn ký; nút ký bị vô hiệu ở tầng UI và API từ chối |
| BR-MBI-CRM-103 | Trình tự scoring theo `[KXN-2]` (đã chốt): AUTO SCORING K1–K12 chạy TRƯỚC First Meeting (ngay sau brief sơ bộ đủ 3 trường), chấm lại `qualifiedTier` sau Full Brief 8 sections. K1–K5 là knockout tuyệt đối (fail bất kỳ → AUTO LOST ngay); K6–K12 là cờ cảnh báo FLAG SM Review 4h — danh sách đầy đủ K6–K12 chưa được nguồn liệt kê tường minh `[KXN-20]`, cấu hình theo enum mở. Mobile hiển thị kết quả scoring và lý do từng tiêu chí, không cung cấp chức năng sửa điểm | SM không thể sửa điểm trực tiếp từ mobile hay bất kỳ kênh nào — chỉ bổ sung dữ liệu rồi cho chấm lại; mọi lần chấm/chấm lại/bypass ghi audit log |
| BR-MBI-CRM-104 | Lead vào gate phải đi qua anti-duplicate 4 kênh (landing page webhook, Zalo OA, Fanpage/Messenger, referral/cold — so khớp email/SĐT/website/MST) và phân bổ owner theo quy tắc nguồn; lead tự do → SM gán trong 4h giờ làm việc (escape hatch) `[CẦN CHỐT SỐ — quy tắc round-robin và SLA gán chờ chính sách ban hành]`. Trên mobile: chỉ nhận push lead mới và cảnh báo, KHÔNG nhập lead | Deal có nguồn gốc không truy vết (nhập ngoài hệ thống) bị chặn khỏi gate theo BR-MBI-CRM-101; mobile không hiển thị chức năng nhập lead |
| BR-MBI-CRM-105 | Điều kiện vào Gate 1 (machine-checkable, chặn ở CORE — mobile chỉ đọc trạng thái): (1) Full Brief 8 sections đủ theo mô hình 2 cấp của `[KXN-3]`; (2) NDA mutual signed gắn khách; (3) `qualifiedTier` có giá trị (không "Thiếu dữ liệu"); (4) meeting notes đã ghi (bắt buộc tier B/C; bypass D/E phải có lý do SM); (5) scorecard QUALIFIED 5 tiêu chí pass ≥4/5, borderline 3/5 do SM quyết | Thiếu bất kỳ điều kiện nào → gate khóa, nút ký không tồn tại; mobile hiển thị danh mục điều kiện còn thiếu kèm trạng thái từng mục |
| BR-MBI-CRM-106 | Gate 1 (stage QUALIFIED — Go/No-Go): SM ký trong SLA 1 ngày làm việc. Ký Go → khóa `qualifiedTier` và mở luồng về phía proposal; ký No-Go → dừng deal, lưu hồ sơ và chuyển xử lý LOST management (ghi `lostStage`/`lostReason` trong 24h; phân loại 4 nhóm LOST `[KXN-17]` còn mở — dùng enum đề xuất, không tự chốt) | Quá SLA → escalate tự động GDKD (SALES_L5) rồi BOD kèm log; không ký, không treo — đồng hồ SLA luôn hiển thị trên mobile |
| BR-MBI-CRM-107 | Gate 2 (ký Handoff): điều kiện mở là Handoff Package 5 nhóm đủ 100% (đọc từ slice REQ-SALES-008) và capacity check ≠ 0 — capacity trống = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký. SM ký → AM xác nhận trong SLA 4h giờ làm việc (cấu hình được); AM từ chối → deal trả về SM khắc phục, credit hoa hồng tạm dừng đến khi handoff lại thành công (nối REQ-SALES-009); quá 4h → escalate tự động kèm log | Ký Gate 2 khi package <100% bị API từ chối; AM không phản hồi 4h → escalate; trạng thái "đã trả về — credit tạm dừng" hiển thị rõ cho SM và NVKD |
| BR-MBI-CRM-108 | Điều kiện tiền tại Gate 2: chưa xác nhận nạp đủ 100% NSQC → hợp đồng chuyển "chờ kích hoạt", block tạo chiến dịch ở tầng máy (bắt tay Financial Hard Stop — G10 do FIN_L1 phê duyệt theo tiền vào tài khoản). Mobile hiển thị thẻ trạng thái chờ kích hoạt và điều kiện còn thiếu; không cung cấp hành động gỡ block | Yêu cầu kích hoạt chiến dịch khi chưa đủ 100% NSQC bị từ chối tầng API mọi kênh; mobile chỉ hiển thị trạng thái, không gỡ được |
| BR-MBI-CRM-109 | Điểm CQ tính theo trọng số 30/25/20/15/10 (thang 1–5): Nhu cầu/KPI theo data 30% · ngân sách 25% · thẩm quyền quyết định 20% · nhu cầu nguồn lực 15% · pháp lý & sản phẩm 10%; tổng quy về thang 1.0–5.0 rồi map tier theo BR-MBI-CRM-102. Trọng số là tham số effective-dated version hóa — GDKD hiệu chỉnh phải trình BOD, không sửa tại chỗ | Thiếu dữ liệu ≥2/5 tiêu chí → chặn chấm, trạng thái "Thiếu dữ liệu"; đoán điểm thủ công bị cấm; sửa trọng số không qua luồng BOD bị từ chối |
| BR-MBI-CRM-110 | Người ký gate phải khác NVKD chủ deal (cấm tự duyệt deal của chính mình); chữ ký gate không ủy thác hàng loạt và không chia sẻ thiết bị; ký trên mobile bắt buộc MFA step-up (TOTP) với token gắn device theo P0-02 §2.4; mọi chữ ký ghi audit log WORM (thời gian, IP, device_id, kết quả MFA, người ký) | API từ chối chữ ký khi signer trùng chủ deal, khi thiếu MFA hoặc device không khớp enrollment; audit log không ai sửa/xóa được kể cả SYS_ADMIN |
| BR-MBI-CRM-111 | SLA và escalation: Gate 1 quá 1 ngày làm việc → escalate GDKD rồi BOD; Gate 2 quá 4h giờ làm việc (đồng hồ tính giờ làm việc cấu hình) → escalate tự động; mọi lần escalate ghi log và push tới người nhận. Hệ quả theo tier hiển thị sau Gate 1 Go (theo `[KXN-8]` chiều V6.0): tier B/C → proposal AM 8–12 trang, ≤2 vòng sửa; tier D/E → Planner 15–25 trang, ≤4 vòng sửa — mobile chỉ hiển thị định mức, không soạn proposal | Gate kẹt quá SLA không thể "im lặng" — escalation nổ tự động tới đúng cấp; cấu hình hằng số tier cấm đảo chiều B/C ↔ D/E so với chuẩn V6.0 |
| BR-MBI-CRM-112 | Override knockout K1–K5: chỉ dành cho deal chiến lược được chỉ định, lý do bằng văn bản, GDKD (SALES_L5) phê duyệt lại, log bất biến. Mobile cho GDKD duyệt override qua push với MFA step-up; NVKD không tự gỡ knockout | Override thiếu văn bản lý do hoặc sai cấp duyệt bị từ chối; knockout đã AUTO LOST không mở lại ngoài luồng override có log |
| BR-MBI-CRM-113 | Rà soát tier theo quý: GDKD rà win rate theo tier + độ lệch điểm CQ vs kết quả thực trên dashboard (mobile xem, cấu hình trên WEB); tham số ngưỡng/trọng số version hóa effective-dated. Cơ hội UPSELL (quy-trinh v1.1 file 06 §8) ghi record riêng, AM soạn đề xuất trong 24h; upsell Accepted lớn → tạo project mới gắn `parentProjectId` và đi đầy đủ pipeline — không tái sử dụng gate đã ký của project gốc, khách hiện hữu không được bỏ Gate 1/Gate 2 (tái ký chỉ rút gọn Initial Brief) | Cố mở Gate 1/Gate 2 cho dự án upsell kế thừa gate cũ bị từ chối; dashboard quý trên mobile là read-only |
| BR-MBI-CRM-114 | Offline-capable theo chuẩn touchpoint mobile nội bộ: đọc hồ sơ gate offline; hành động ký đã qua MFA được ký local, xếp hàng đồng bộ — máy chủ đối chiếu version và trạng thái gate, nếu gate đã đổi trạng thái thì kết quả "không áp dụng" và không ghi hai lần. MOBILE không dùng cho nhập liệu hàng loạt (lead, proposal, hợp đồng) theo nguyên tắc đa hệ thống (sales.md B.0) | Hai lần ghi mâu thuẫn không xảy ra — bản ghi thắng là bản ghi máy chủ; thao tác nhập liệu hàng loạt từ mobile bị API từ chối kèm hướng dẫn sang WEB |
| BR-MBI-CRM-115 | Cấu hình Approval Module tham số hóa người duyệt theo mã vai registry; ma trận RACI của bộ quy trình v1.1 chưa được khách hàng xác nhận chính thức `[KXN-19]` — ánh xạ SM = SALES_L4 (TPKD) theo `[KXN-14]` là căn cứ hiện hành, `sales.md` A1 vẫn ghi SM ở SALES_L3 nên RBAC phải dễ đổi ánh xạ khi có đồng bộ | Sai ánh xạ vai → nút ký không xuất hiện cho đúng người; cấu hình cứng người theo tên cá nhân bị chặn (duyệt theo mã vai, hỗ trợ vai kiêm nhiệm) |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry. Người ký gate là SM — ánh xạ SALES_L4 theo `[KXN-14]` (chốt 12/09); nếu tổ chức điều chỉnh ánh xạ SM về SALES_L3, RBAC đổi cấu hình theo mã vai, không đổi code. OPS_AM tham gia bắt buộc ở bước xác nhận Gate 2.*

| Hành động (trên mobile) | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | OPS_AM | BOD (CEO/CFO_CTO) | SYS_ADMIN |
|---------------------------|----------|----------|----------|---------------|-----------------|--------|--------------------|-----------|
| Xem kết quả gate của deal mình (Go/No-Go, trả về, lý do) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ (deal phụ trách) | ✅ | ❌ |
| Xem hồ sơ gate đầy đủ (qualifiedTier, checklist, lịch sử scoring) | ❌ | ❌ (deal mình: ✅) | ✅ (nhóm) | ✅ | ✅ | ✅ (Gate 2) | ✅ | ❌ |
| Ký Gate 1 — Go/No-Go (MFA step-up) | ❌ | ❌ | ❌ (trừ khi được ánh xạ SM) | ✅ (≠ chủ deal) | ❌ | ❌ | ❌ | ❌ |
| Ký Gate 2 — Handoff (MFA step-up) | ❌ | ❌ | ❌ (như trên) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận tiếp nhận Gate 2 (SLA 4h) / từ chối kèm lý do | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt override knockout K1–K5 (lý do văn bản) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Nhận escalate quá SLA | ❌ | ❌ | ❌ | ✅ (deal của mình quá SLA bị push) | ✅ (cấp 1) | ❌ | ✅ (cấp 2) | ❌ |
| Xem dashboard hàng đợi gate / SLA gate | ❌ (pipeline của mình) | ✅ (cá nhân) | ✅ (nhóm) | ✅ (nhóm/phòng) | ✅ (toàn Sales) | ❌ | ✅ | ❌ |
| Soạn Handoff Package, checklist 5 nhóm, capacity planning | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ WEB/CORE) |
| Nhập lead / di chuyển stage / soạn proposal trên mobile | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Sửa/xóa audit log chữ ký gate | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Ghi chú: SALES_L1 (Intern) không tham gia ký duyệt gate — chỉ xem pipeline cá nhân. SYS_ADMIN cấu hình kỹ thuật (device enrollment, kênh push, MFA, ánh xạ vai) nhưng không ký nghiệp vụ, không xem nội dung deal, không can thiệp audit trail. OPS_AM chỉ thấy hồ sơ Gate 2 phục vụ xác nhận tiếp nhận — không thấy bảng điểm CQ nội bộ của Sales.

---

## 5. Trường Hợp Đặc Biệt

- **`qualifiedTier` borderline tier D (3.0–3.49) trước Gate 1:** SM thẩm định trong SLA 4h, quá hạn escalate GDKD, kết quả kèm lý do; kết quả thẩm định là đầu vào bắt buộc trước khi mở nút ký Gate 1. Mobile push song song cho SM (việc đến hạn) và GDKD (khi quá hạn).
- **Deal BOD-sponsored hoặc do đối tác (Google/TikTok/Yandex) giới thiệu:** vẫn phải có `qualifiedTier` hợp lệ và đi đủ Gate 1/Gate 2 — đối tác giới thiệu không được bypass scoring; BOD-sponsored gắn nhãn riêng hiển thị trên hồ sơ gate để người ký biết bối cảnh, nhưng không miễn điều kiện.
- **AM từ chối Gate 2:** deal trả về SM khắc phục kèm danh mục thiếu sót trong package; credit hoa hồng tạm dừng tự động (nối REQ-SALES-009) đến khi handoff lại thành công; cả SM và NVKD chủ deal nhận push, trạng thái hiển thị "đã trả về — credit tạm dừng" trên mobile.
- **Capacity trống = 0 trước khi ký Gate 2:** hệ thống cảnh báo GDKD + OPS_PLAN trước khi nút ký mở; SM vẫn có thể ký sau khi cảnh báo được ghi nhận (quyết định rủi ro có log) — tránh ký deal không người chạy mà không khóa cứng quy trình phối hợp OPS.
- **Chưa nạp đủ 100% NSQC sau Gate 2:** hợp đồng rơi vào "chờ kích hoạt", block tạo chiến dịch ở tầng máy; mobile hiển thị thẻ trạng thái kèm điều kiện còn thiếu (tiền/chữ ký), không ai gỡ block được từ app.
- **Mất mạng ngay lúc ký:** chữ ký đã qua MFA ký local và xếp hàng đồng bộ; nếu gate đã đổi trạng thái (deal bị trả về, đã có người ký — điều không thể với khóa ký theo gate nhưng có thể với danh mục điều kiện) thì máy chủ trả kết quả "không áp dụng" và mobile làm mới dữ liệu.
- **Khách tái ký:** được rút gọn Initial Brief nhưng không bỏ Gate 1/Gate 2 — hai gate vẫn chạy đủ điều kiện; hồ sơ gate hiển thị nhãn "tái ký" để người ký phân biệt luồng rút gọn.
- **No-Go tại Gate 1:** deal dừng, lưu hồ sơ đầy đủ và chuyển LOST management (ghi lý do trong 24h, tag nurture/blacklist, re-contact date `[KXN-17]` còn mở — phân loại nhóm dùng enum đề xuất); SM có thể mở lại hồ sơ theo luồng lead cũ quay lại ≤180 ngày giữ lịch sử scoring, chấm lại đúng 1 lần.
- **Thiết bị mới / mất MFA:** SM phải re-enroll TOTP gắn device theo P0-02 §2.4 trước khi nút ký bật lại; không cho phép ký hộ, chia sẻ thiết bị hay ủy thác hàng loạt — người ký vắng dài hạn phải phân công theo cấu hình vai (khác chủ deal) trên WEB.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi phê duyệt gate (Gate Approval Record — một deal có tối đa 2 bản ghi theo chuỗi: Gate 1 tại stage QUALIFIED, Gate 2 tại điểm bàn giao Sales → Vận hành theo `[KXN-4]`; `qualifiedTier` khóa ngay khi Gate 1 Go).

**Sơ đồ trạng thái:**
```
                    (đủ điều kiện entry Gate 1: Full Brief 8 sections + NDA mutual
                     + qualifiedTier hợp lệ + meeting notes + scorecard ≥4/5)
[ENTRY_CHECK] ────────────────────────────────────────────────► [WAITING_SM_SIGN_G1]
      ▲                                                              │        │
      │ (thiếu mục: quay lại bổ sung)        (SM ký Go, SLA 1 ngày LV)       │ (SM ký No-Go / quá SLA escalate xong quyết No-Go)
      └──────────────────────────────────────────────────────────────────┐    ▼
                                                                          ▼  [NO_GO → LOST]
                                                        [GATE1_GO — khóa qualifiedTier]
                                                                              │
                        (Package 5 nhóm 100% + capacity ≠ 0 + 2h nhắc trước hạn)
                                                                              ▼
                                                             [WAITING_SM_SIGN_G2] ──(quá hạn trình)──► [ESCALATED_G2]
                                                                              │ (SM ký)
                                                                              ▼
                                                             [WAITING_AM_CONFIRM] ──(quá 4h)──► [ESCALATED_AM]
                                                        │                  │
                                          (AM xác nhận ≤4h)      (AM từ chối)
                                                        ▼                  ▼
                                              [HANDOFF_CONFIRMED]   [RETURNED_TO_SM — credit tạm dừng]
                                                        │                  │
                                              (chưa nạp 100% NSQC)        (SM khắc phục xong, trình lại)
                                                        ▼                  ▼
                                              [PENDING_ACTIVATION]  [WAITING_SM_SIGN_G2 — trình lại]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ENTRY_CHECK` | Bổ sung điều kiện còn thiếu | `ENTRY_CHECK` (cập nhật) | SALES_L2 chủ deal (WEB) | Đúng mục thiếu; mobile chỉ xem tiến độ |
| `ENTRY_CHECK` | Hệ thống xác nhận đủ entry | `WAITING_SM_SIGN_G1` | Hệ thống (CORE) | Đủ 5 điều kiện BR-MBI-CRM-105; SLA 1 ngày bắt đầu chạy |
| `WAITING_SM_SIGN_G1` | Ký Go | `GATE1_GO` | SM (≠ chủ deal) — mobile hoặc WEB | MFA step-up + token gắn device; khóa `qualifiedTier`; audit log WORM |
| `WAITING_SM_SIGN_G1` | Ký No-Go | `NO_GO` | SM | Lý do bắt buộc; chuyển LOST management (ghi lý do 24h) |
| `WAITING_SM_SIGN_G1` | Quá SLA | `ESCALATED_G1` | Hệ thống | Escalate GDKD → BOD tự động + push + log |
| `GATE1_GO` | Trình Gate 2 | `WAITING_SM_SIGN_G2` | SALES_L2 chủ deal (WEB) | Package 5 nhóm 100% + capacity ≠ 0; capacity = 0 → cảnh báo GDKD + OPS_PLAN |
| `WAITING_SM_SIGN_G2` | Ký Handoff | `WAITING_AM_CONFIRM` | SM — mobile là kênh ký chính | MFA step-up; đồng hồ 4h của AM bắt đầu |
| `WAITING_AM_CONFIRM` | Xác nhận tiếp nhận | `HANDOFF_CONFIRMED` | OPS_AM — mobile | Trong 4h giờ làm việc; kèm xác nhận nhận package |
| `WAITING_AM_CONFIRM` | Từ chối | `RETURNED_TO_SM` | OPS_AM | Lý do/thiếu sót bắt buộc; credit hoa hồng tạm dừng tự động |
| `WAITING_AM_CONFIRM` | Quá 4h | `ESCALATED_AM` | Hệ thống | Escalate tự động + log |
| `RETURNED_TO_SM` | Khắc phục và trình lại | `WAITING_SM_SIGN_G2` | SALES_L2 (WEB) | Package cập nhật đủ 100% lại từ đầu |
| `HANDOFF_CONFIRMED` | Đánh dấu chờ kích hoạt | `PENDING_ACTIVATION` | Hệ thống | Chưa xác nhận nạp đủ 100% NSQC — block tạo chiến dịch tầng máy |
| `HANDOFF_CONFIRMED` | Đủ nạp 100% NSQC | `ACTIVATED` | Hệ thống (theo bản ghi FIN) | Financial Hard Stop gỡ ở tầng máy (G10 — FIN_L1 theo tiền vào) |

**Quy tắc:** `NO_GO` là trạng thái kết thúc cho deal — không mở lại ngoài luồng lead cũ quay lại (≤180 ngày, chấm lại đúng 1 lần) tạo bản ghi gate mới; `qualifiedTier` chỉ khóa một lần tại `GATE1_GO` và không bao giờ mở khóa; `ACTIVATED`/`NO_GO` là trạng thái kết thúc của chuỗi gate; mọi chuyển đổi phát sinh từ mobile đều có audit log WORM với metadata device/IP/MFA. Cấu hình người duyệt theo mã vai, tham số hóa được do ma trận RACI chờ xác nhận chính thức `[KXN-19]`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`; engine và validation nằm ở CORE, mobile chỉ gọi API và lưu cache đọc offline.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `GateApprovalRecord` | `id`, `deal_id`, `gate_type` (GATE_1/GATE_2), `state`, `sla_deadline`, `outcome`, `escalation_level`, `retry_count` | FK → `deal.id` | 1 deal tối đa 2 bản ghi gate; state machine theo Mục 6 |
| `GateEntryChecklist` | `gate_record_id`, `check_full_brief_8`, `check_nda_mutual`, `check_tier_valid`, `check_meeting_notes`, `check_scorecard_4_of_5`, `missing_items` | FK → `GateApprovalRecord.id` | Machine-checkable ở CORE; mobile hiển thị từng mục |
| `QualifiedTierSnapshot` | `id`, `deal_id`, `tier` (A–E), `cq_score`, `weights_version`, `locked_at`, `locked_by_gate_id` | FK → `deal.id`, `GateApprovalRecord.id` | Khóa một lần tại Gate 1 Go; weights effective-dated 30/25/20/15/10 |
| `SignatureRecord` | `id`, `gate_record_id`, `signer_id`, `signer_role`, `signed_at`, `ip`, `device_id`, `mfa_verified`, `synced_from_offline` | FK → `GateApprovalRecord.id` | WORM; SM ≠ chủ deal kiểm tra tại đây; không ai sửa/xóa |
| `HandoffReadinessView` | `deal_id`, `package_complete_pct`, `capacity_status`, `nsqc_paid_pct`, `am_confirm_deadline` | Đọc từ slice REQ-SALES-008 + FIN | View chỉ đọc phục vụ điều kiện Gate 2; mobile không ghi |
| `EscalationLog` | `id`, `gate_record_id`, `level` (SM→GDKD→BOD / AM), `triggered_at`, `acknowledged_by`, `acknowledged_at` | FK → `GateApprovalRecord.id` | Tự sinh khi quá SLA; push mobile tới người nhận |
| `OverrideKnockoutRequest` | `id`, `deal_id`, `knockout_code` (K1–K5), `reason_doc_ref`, `requested_by`, `approved_by`, `approved_at` | FK → `deal.id` | Chỉ GDKD duyệt; log bất biến; lý do bằng văn bản bắt buộc |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-SALES-004 (Mục 2 — "Tôi cần hệ thống làm được").*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: SM ký Gate 1 trên mobile trong SLA | Gate 1 đủ 5 điều kiện entry, `qualifiedTier` = C, SM ≠ chủ deal | SALES_L4 mở push, MFA step-up, bấm "Go" | Trạng thái `GATE1_GO`; `qualifiedTier` khóa; audit trail đủ thời gian/IP/device/MFA; SLA clock dừng | [ ] |
| SC-002: Chặn ký khi thiếu điều kiện entry | Deal chưa có NDA mutual signed | SM mở hồ sơ Gate 1 trên mobile | Nút ký không tồn tại; màn hình liệt kê "NDA chưa mutual"; API từ chối nếu gọi trực tiếp | [ ] |
| SC-003: Quá SLA Gate 1 escalate tự động | Gate 1 `WAITING_SM_SIGN_G1` quá 1 ngày làm việc | SLA clock quá hạn | Push tới GDKD (SALES_L5) kèm hồ sơ; tiếp tục quá hạn → escalate BOD; `EscalationLog` ghi đủ | [ ] |
| SC-004: Cấm tự duyệt deal của mình | SM trùng người chủ deal | SM cố ký Gate 1 | API từ chối với lý do "signer trùng chủ deal"; nút ký ẩn ở UI | [ ] |
| SC-005: Gate 2 chặn khi package <100% | Handoff Package 5 nhóm đạt 92% | SALES_L2 trình Gate 2 | Trình bị từ chối; mobile hiển thị mục thiếu kèm responsible/due date; capacity = 0 → cảnh báo GDKD + OPS_PLAN | [ ] |
| SC-006: AM xác nhận Gate 2 trong 4h / từ chối | SM đã ký Gate 2 | OPS_AM bấm xác nhận sau 2h (hoặc từ chối kèm thiếu sót) | `HANDOFF_CONFIRMED` (hoặc `RETURNED_TO_SM` + credit tạm dừng hiển thị cho SM/NVKD); quá 4h → escalate tự động | [ ] |
| SC-007: Chưa nạp 100% NSQC → chờ kích hoạt | Gate 2 đã `HANDOFF_CONFIRMED`, nạp NSQC 80% | Hệ thống đánh giá điều kiện tiền | Trạng thái `PENDING_ACTIVATION`; block tạo chiến dịch tầng máy; thẻ trạng thái hiển thị trên mobile | [ ] |
| SC-008: Override knockout có kiểm soát | Deal chiến lược fail K4 (không chấp nhận nạp trước) | GDKD duyệt override kèm lý do văn bản trên mobile (MFA) | `OverrideKnockoutRequest` ghi log bất biến; deal mở lại luồng scoring; NVKD không tự gỡ được | [ ] |
| SC-009: Offline ký đồng bộ an toàn | SM mất mạng khi đang ký sau MFA | Mạng trở lại, app đồng bộ | Chữ ký push lên, máy chủ đối chiếu trạng thái; gate đã đổi trạng thái → kết quả "không áp dụng", không ghi hai lần | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (hàng đợi gate, ký MFA step-up, AM confirm, đồng bộ offline) | `technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (approval engine CORE, SLA clock, Financial Hard Stop FIN, push device enrollment P0-02 §2.4) | `technical-specs/integration-map.md` |
| Màn hình UI (hàng đợi gate, hồ sơ gate, thẻ trạng thái D+0/chờ kích hoạt) | `phase4-ux/mobile-internal/crm-pipeline/gate-approval.md` |
| Domain nguồn (Gate 1/Gate 2, RACI, SLA, hằng số tier) | `documents/quy-trinh-lam-viec/02_Giai_doan_1_Sales.md` §2.5–2.6, `08_Ma_tran_RACI_Gate_SLA.md` §2 G2–G3, `09_Phu_luc_Hang_so_Quy_trinh.md` §1–2, `10_..._Khoan_Can_Xac_nhan.md` §8 |
| Workflow tổng (bước B4/B7 luồng 1) | `phase1-business/P1-02-business-workflow.md` §3.1 |
| Spec cùng REQ tại hệ khác | `phase2-features/core-backend/crm-pipeline/*.md`, `phase2-features/bcerp-web/crm-pipeline/*.md` |
| Slice liên quan trong cùng touchpoint | `phase2-features/mobile-internal/handoff-onboard/*.md` (REQ-SALES-008 — Handoff Package, mobile đọc trạng thái) |
