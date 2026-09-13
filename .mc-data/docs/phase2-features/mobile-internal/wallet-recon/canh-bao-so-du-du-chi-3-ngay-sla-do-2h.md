# Tính Năng: Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h

> **Dựa trên:** REQ-FIN-002 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md` (BR-OPS-2.3/2.4)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-002-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-FIN-002 (REQ xuất hiện ở 3 systems). Counterparts: SYS-CORE-BACKEND (tính ADS 7 ngày rolling, 3 mức, bộ đếm SLA — rule enforce ở service layer), SYS-BCERP-WEB (dashboard ví là kênh xem chính). Touchpoint Mobile nội bộ là **app React Native offline-capable**: bản spec này mô tả trải nghiệm **nhận push cảnh báo và theo dõi đồng hồ SLA trên di động** — bề mặt phản ứng nhanh nhất của cảnh báo vì owner/Finance không phải lúc nào cũng ngồi máy tính.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-002 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-002 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (ledger ví — nguồn số dư); FEAT-CORE-WALLET-002 (engine tính ADS + 3 mức + timer SLA trên Core); REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp (bản OPS góc mobile tại FEAT-MBI-WALLET-006) |
| Ghi chú Expert (A7) | Dept doc finance.md có cấu trúc A7; phần review chưa thực hiện chính thức. Ngưỡng 3 mức Xanh/Vàng/Đỏ và SLA đỏ 2h đã chốt theo nguồn finance.md — không phải mức tự suy; yêu cầu dữ liệu chi tiêu tươi ≤1h thuộc GW (DI-007: degraded mode `manual` phải giữ nhãn) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa cảnh báo số dư ví lên Mobile nội bộ để FIN_L1, FIN_L2 và BOD_CFO_CTO biết **trong vòng 5 phút** từ lúc hệ thống phát hiện ví sắp hết quỹ, theo dõi được đồng hồ SLA đỏ 2h làm việc và vị trí escalation của từng alert khi đang di chuyển. Mục tiêu nghiệp vụ của REQ-FIN-002 là biết trước ví nào sắp hết quỹ để chủ động xin khách nạp và tránh die campaign — mobile là kênh bảo đảm người nhận cảnh báo không bỏ lỡ vì không ngồi máy tính.

**Phạm vi:**
- Bao gồm: push notification theo 3 mức (Xanh — đủ chi ≥3 ngày, Vàng — <3 ngày, Đỏ — <1 ngày hoặc dưới mức tối thiểu nền tảng) cho ví thuộc phạm vi FIN theo dõi; màn danh sách alert kèm đồng hồ SLA đỏ 2h đếm giờ làm việc và chặng escalation hiện tại (owner → TL → AM, có timestamp); màn chi tiết alert hiển thị số dư, average daily spend 7 ngày, số ngày chi dự kiến và lịch sử alert; thông báo escalation khi alert quá 2h/4h không có hành động; theo dõi từ mobile trạng thái "đã có hành động" (lệnh top-up đã tạo/giảm ngân sách) do phía OPS/Web thực hiện; cache offline danh sách alert đã sync kèm nhãn thời điểm.
- Không bao gồm: tính ADS và phân mức (Core thực thi — mobile chỉ nhận kết quả); tạo lệnh đề xuất top-up hoặc giảm ngân sách từ alert (kênh chính là Web — bản OPS góc mobile với thao tác ngoài giờ thuộc FEAT-MBI-WALLET-006); dashboard ví đầy đủ theo khách/nền tảng (SYS-BCERP-WEB); kéo số dư/spend từ nền tảng (SYS-INTEGRATION-GW theo REQ-FIN-005); gửi thông báo cho khách hàng (Portal — ngoài phạm vi app nội bộ).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Nhận push trên điện thoại khi một ví chuyển sang mức Đỏ | Biết ngay ví nào sắp cạn để chuẩn bị dòng tiền nạp nền tảng theo nguyên tắc tiền giữ hộ (không chi tiền BC trước khi có tiền khách) |
| 2 | FIN_L1 | Nhận push khi ví chuyển Vàng (<3 ngày) | Chủ động nhắc AM xin khách nạp trước khi situation xấu đi, thay vì phát hiện khi campaign đã die |
| 3 | FIN_L2 | Xem danh sách tất cả alert Đỏ đang mở kèm đồng hồ SLA 2h và chặng escalation hiện tại | Kiểm soát rủi ro gián đoạn chi tiêu toàn tổ hợp khách mà không phải mở dashboard Web từng lần |
| 4 | FIN_L2 | Nhận thông báo khi một alert Đỏ quá 2h không có hành động và đã escalate lên TL | Can thiệp phân bổ lại hoặc nhắc đúng người đúng thời điểm, có timestamp làm căn cứ |
| 5 | BOD_CFO_CTO | Nhận chỉ báo tổng quan (badge + push tóm tắt hằng ngày) về số ví Đỏ/Vàng và alert quá SLA | Nắm rủi ro dòng tiền cấp tổ hợp ở mức quản trị mà không đọc chi tiết từng alert |
| 6 | FIN_L1 | Xem trên mobile trạng thái alert đã được "hạ nhiệt" khi phía OPS tạo lệnh top-up hoặc giảm ngân sách | Tránh gọi nhắc trùng người — hệ thống đã phản ánh hành động thật trên lệnh |
| 7 | FIN_L1 | Mở app khi offline và xem được danh sách alert + đồng hồ theo lần sync gần nhất | Vẫn biết bức tranh rủi ro khi đi đường, kèm nhãn "dữ liệu offline" để không hành động trên số cũ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — engine tính toán và timer SLA nằm ở service layer của SYS-CORE-BACKEND; mobile là kênh nhận/phản ánh, không được tự tính lại mức cảnh báo.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS §3.5/3.8). Alert tính trên ví gốc theo tiền tệ — không phát sinh alert dựa trên tổng quy đổi | Mobile hiển thị alert theo từng ví/tiền tệ; nếu thấy alert tổng hợp quy đổi → coi là bug, chặn release |
| BR-W02 | Công thức topup `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`, NET/GROSS 2 chiều (CMS §5). Con số "số ngày chi dự kiến" hiển thị trên mobile do Core tính từ ADS 7 ngày và số dư khả dụng — mobile không tự nhân chia công thức nào | Mọi phép tính hiển thị lấy từ API Core; test so khớp giá trị mobile = giá trị Web cho cùng alert |
| BR-W03 | 3 mức cảnh báo per TK/platform: **Xanh** (đủ chi ≥3 ngày — không hành động), **Vàng** (<3 ngày — owner lập kế hoạch nạp, thông báo AM), **Đỏ** (<1 ngày hoặc dưới mức tối thiểu nền tảng — vào SLA đỏ) (BR-FIN-104, BR-OPS-2.3). Mobile phân biệt mức bằng màu + push: Đỏ push ngay, Vàng push trong cửa sổ thông báo, Xanh không push | Push sai mức hoặc sót mức Đỏ → lỗi khối push; test 3 mức với dữ liệu mẫu trước release |
| BR-W04 | **SLA đỏ 2h làm việc + escalation có timestamp**: 0–2h owner phải tạo lệnh đề xuất top-up hoặc giảm ngân sách trên hệ thống; quá 2h → escalate TL; quá 4h → escalate AM (liên hệ khách yêu cầu nạp trong ngày làm việc); ngoài giờ escalate kênh on-call (BR-FIN-104, BR-OPS-2.4). Mobile hiển thị đồng hồ giờ làm việc + chặng hiện tại của **mọi** alert Đỏ FIN nhận | Đồng hồ/chặng không cập nhật → lỗi hiển thị; alert Đỏ không hiển thị chặng escalation bị chặn ở QA |
| BR-W05 | **Push cảnh báo ≤5 phút** từ lúc sync phát hiện (BR-FIN-104; REQ-FIN-002): dữ liệu chi tiêu tươi ≤1h do GW cấp (degraded mode gắn nhãn `manual` theo DI-007 — khi connector lỗi, alert vẫn chạy nhưng màn chi tiết hiển thị disclaimer "số liệu manual — độ trễ có thể lớn hơn") | Push quá 5 phút với alert Đỏ (trừ degraded được ghi rõ) → vi phạm SLA kỹ thuật, đo bằng metric push latency |
| BR-W06 | Dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền (CMS §3.6). Mobile **không mở luồng duyệt** từ alert của feature này — hành động từ alert là tạo lệnh/giảm ngân sách, thuộc kênh Web (bản FIN chỉ theo dõi); duyệt mobile chỉ tồn tại ở FEAT-MBI-WALLET-003 | Nếu alert dẫn người dùng vào luồng duyệt rủi ro cao không qua FEAT-003 → chặn luồng; chỉ deep-link sang màn chi tiết lệnh |
| BR-W07 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng) với dung sai 0/0,5%·10USD/1%·20USD, chốt & khóa kỳ — thuộc counterpart Core (REQ-FIN-004). Alert số dư không thay thế đối trừ: một ví Đỏ vẫn có thể đang "Đã đối soát" — hai tín hiệu độc lập, mobile hiển thị song song không suy diễn hộ | Không được hiển thị "ví đỏ = chênh lệch đối soát"; mỗi alert gắn đúng dữ liệu nguồn của nó |
| BR-W08 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn (REQ-FIN-010); Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10). Alert số dư không có bất kỳ gợi ý hành động tài chính nào ngoài tạo lệnh top-up/giảm ngân sách (ví dụ: không gợi ý "hoàn tiền", "đổi tỷ giá" từ alert) | Màn alert chứa action rủi ro cao ngoài phạm vi → chặn; chỉ deep-link theo BR-W06 |
| BR-W09 | Portal chỉ đọc số dư ví (REQ-FIN-017) — **tenant isolation**: app nội bộ không gửi bất kỳ thông báo nào ra ngoài biên nội bộ; khách hàng không nhận push từ hệ thống này | Phát hiện luồng push ra thiết bị khách → sự cố bảo mật, chặn và meta-log |
| BR-W10 | Offline: danh sách alert + chặng escalation được cache theo lần sync; khi offline hiển thị nhãn "cập nhật lúc HH:MM" và đồng hồ SLA đánh dấu "giá trị tại thời điểm sync — có thể đã trôi"; cấm hành động ghi khi offline | Nếu hiển thị đồng hồ chạy tiếp như real-time khi offline → đánh lừa người dùng; bắt buộc freeze + nhãn |

**Giả định chờ xác nhận:** ngưỡng "mức tối thiểu nền tảng" per platform do cấu hình hệ thống cung cấp (Core là nguồn) — nếu có thay đổi ngưỡng theo nền tảng, cấu hình lại ở Core không sửa app. 11 KXN còn mở (`[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]`) thuộc domain CRM/lifecycle — không tác động rule cảnh báo ví của spec này, không tự quyết.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Bản FIN của alert là nội dung spec này; góc OPS owner (thao tác từ alert) tại FEAT-MBI-WALLET-006. TL trong escalation được đại diện bởi vai OPS_PLAN/OPS_CONT theo quy ước registry.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_PLAN/OPS_CONT (TL) | OPS_AM/OPS_ADS | CUSTOMER |
|-----------|--------|--------|-------------|------------------------|----------------|----------|
| Nhận push cảnh báo ví (khách FIN theo dõi) | ✅ | ✅ | ✅ (chỉ Đỏ + tổng quan) | ❌ (nhận ở bản OPS — FEAT-006) | ❌ (nhận ở bản OPS — FEAT-006) | ❌ |
| Xem danh sách alert + đồng hồ SLA + chặng escalation | ✅ | ✅ (toàn bộ) | ✅ (tổng hợp) | ❌ (bản OPS) | ❌ (bản OPS) | ❌ |
| Xem chi tiết alert (ADS 7 ngày, số ngày chi dự kiến, lịch sử) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo lệnh đề xuất top-up / giảm ngân sách từ alert | ❌ (kênh Web) | ❌ (kênh Web) | ❌ | ✅ (bản OPS — FEAT-006) | ✅ (bản OPS — FEAT-006, owner) | ❌ |
| Nhận thông báo escalation chặng TL/AM | ❌ | ❌ | ❌ | ✅ (chặng TL — bản OPS) | ✅ (chặng AM — bản OPS) | ❌ |
| Tắt/ngắt monitoring ví bất kỳ khách nào | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình kênh nhận push của bản thân | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Ngoài giờ làm việc:** đồng hồ SLA tính giờ làm việc — alert Đỏ phát sinh ngoài giờ đẩy sang kênh on-call TL; mobile hiển thị "ngoài giờ — on-call đã nhận" thay vì đồng hồ chạy tiếp, tránh đếm sai làm người dùng hoảng giữa đêm.
- **Dữ liệu degraded `manual`:** khi GW connector lỗi (DI-007), alert vẫn phát hành nhưng màn chi tiết gắn disclaimer "số liệu manual — độ trễ có thể lớn hơn 1h"; FIN_L1 coi đây là tín hiệu cần xác minh trên statement trước khi báo khách.
- **Ví Đỏ mà khách chậm nạp:** FIN_L1 đánh dấu rủi ro gián đoạn chi tiêu; nếu khách nằm trong kế hoạch nạp nền tảng tuần, FIN_L2 tạm giữ phần giải ngân tương ứng (BR-FIN-104 exception) — mobile hiển thị trạng thái "đã giữ giải ngân" do Core phản ánh.
- **Alert trùng khách nhiều TK:** một khách có nhiều TK/platform cùng đỏ — mobile gộp nhóm theo khách để tránh bão push, nhưng mở ra vẫn thấy từng TK riêng và đồng hồ riêng.
- **Alert đã có hành động:** khi phía OPS tạo lệnh top-up hoặc giảm ngân sách, alert chuyển "đã có hành động — chờ khớp tiền"; push thông báo cho FIN kèm mã lệnh; chỉ hẳn "Đã xử lý" khi lệnh về "Đã khớp tiền".
- **Thiết bị tắt thông báo:** nếu người dùng tắt push ở tầng OS, app hiển thị cảnh báo trong app "bạn đang không nhận push — SLA đỏ có thể bị lỡ" mỗi lần mở, vì cảnh báo ≤5 phút là yêu cầu nghiệp vụ chứ không phải tiện ích.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Alert cảnh báo số dư (tạo bởi Core; mobile phản ánh).

**Sơ đồ trạng thái:**
```
[MỚI] ──(owner tạo lệnh top-up/giảm ngân sách)──► [ĐÃ CÓ HÀNH ĐỘNG] ──(lệnh "Đã khớp tiền")──► [ĐÃ XỬ LÝ]
   │                                                     │
   │ (quá 2h)                                            │ (lệnh bị reject/hủy)
   ▼                                                     ▼
[ESCALATED — TL] ──(quá 4h)──► [ESCALATED — AM]            [MỚI — đồng hồ tiếp tục]
```

**Bảng chuyển đổi (mobile hiển thị trạng thái + timestamp từng chặng):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép (thực thi nơi khác) | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-----------------------------------|---------------------|
| `MỚI` | Owner tạo lệnh đề xuất top-up hoặc giảm ngân sách | `ĐÃ CÓ HÀNH ĐỘNG` | OPS owner (kênh Web/bản OPS mobile) | Lệnh hợp lệ trong vòng 0–2h làm việc |
| `MỚI` | Quá 2h không hành động | `ESCALATED — TL` | Hệ thống (Core auto-escalate) | Timestamp chặng owner bị khóa |
| `ESCALATED — TL` | Quá 4h không hành động | `ESCALATED — AM` | Hệ thống (Core auto-escalate) | AM chủ động liên hệ khách trong ngày làm việc |
| `ĐÃ CÓ HÀNH ĐỘNG` | Lệnh nạp tương ứng bị reject/hủy | `MỚI` | Hệ thống (theo trạng thái lệnh) | Đồng hồ SLA tiếp tục từ mốc cũ — không reset về 0 |
| `ĐÃ CÓ HÀNH ĐỘNG` | Lệnh về "Đã khớp tiền" | `ĐÃ XULÝ` | Core (theo vòng lệnh nạp) | Alert đóng; lịch sử giữ nguyên |
| `ESCALATED — AM` | Khách nạp/lệnh tạo sau đó | `ĐÃ CÓ HÀNH ĐỘNG` / `ĐÃ XỬ LÝ` | Theo hành động thực tế | Mọi chặng vẫn giữ timestamp |

**Quy tắc:**
- Mobile không là tác nhân của chuyển trạng thái — mọi chuyển đổi đến từ hành động thật trên lệnh hoặc auto-escalate của Core; không có nút "đóng alert" thủ công trên mobile (không hạ nhiệt mà không có hành động thật).
- Trạng thái `ĐÃ XỬ LÝ` là trạng thái kết thúc; alert và toàn bộ timestamp chặng được lưu để rà soát SLA theo tuần (phối hợp REQ-FIN-015 dashboard).
- Chỉ phân mức lại (Xanh/Vàng/Đỏ) do Core tính lại theo dữ liệu mới — mobile không cho người dùng tự đổi mức alert.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mobile tiêu thụ — nguồn sự thật thuộc Core (`technical-specs/database-design.md`); mobile giữ cache đọc + đăng ký push.*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `WalletBalanceAlert` | `wallet_id`, `level` (XANH/VÀNG/ĐỎ), `days_of_runway`, `ads_7d`, `status`, `escalation_stage`, `timestamps[]` | FK → `wallets.id` | 3 mức + chặng escalation; phân theo tiền tệ gốc |
| `EscalationStep` | `stage` (OWNER/TL/AM/ON_CALL), `notified_user_id`, `at` | FK → `wallet_balance_alerts.id` | Mobile hiển thị dòng thời gian có timestamp |
| `Wallet` | `customer_id`, `currency`, `available_balance` | FK → `customers.id` | Hiển thị kèm nhãn tiền giữ hộ |
| `PushRegistration` (client-side) | `device_id`, `user_id`, `os`, `push_token`, `enabled` | Gắn vai nội bộ | Cơ sở bảo đảm "push ≤5 phút" tới đúng người |
| `OfflineCache` (client-side) | `synced_at`, `payload`, `device_id` | Gắn thiết bị | Offline chỉ đọc; nhãn thời điểm bắt buộc |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push Đỏ ≤5 phút | Ví khách A rơi xuống <1 ngày chi sau lần sync | Core phát hiện mức Đỏ | Thiết bị FIN_L1 nhận push trong ≤5 phút; mở được chi tiết alert | [ ] |
| SC-002: 3 mức phân biệt đúng | Bộ ví mẫu có đủ 3 mức | Xem danh sách alert | Xanh không push, Vàng push thụ động, Đỏ push ngay; màu nhãn đúng mức | [ ] |
| SC-003: Đồng hồ SLA 2h giờ làm việc | Alert Đỏ phát lúc 16:45 giờ làm việc | Sang ngày làm việc kế tiếp | Đồng hồ cộng dồn theo giờ làm việc, không đếm ngoài giờ; hiển thị đúng chặng | [ ] |
| SC-004: Escalation có timestamp | Alert Đỏ quá 2h không hành động | Xem dòng thời gian alert | Chặng TL xuất hiện kèm timestamp; quá 4h thấy chặng AM | [ ] |
| SC-005: Hạ nhiệt qua hành động thật | Alert đã "ĐÃ CÓ HÀNH ĐỘNG" | OPS tạo lệnh top-up rồi lệnh bị reject | Alert quay về `MỚI`, đồng hồ tiếp tục từ mốc cũ, không reset | [ ] |
| SC-006: Offline freeze đồng hồ | App offline với alert đang mở | Xem màn danh sách alert | Đồng hồ freeze kèm nhãn "giá trị tại thời điểm sync"; không có nút ghi nào khả dụng | [ ] |
| SC-007: Degraded disclaimer | GW connector lỗi, dữ liệu `manual` | Mở chi tiết alert | Hiển thị disclaimer độ trễ kèm nhãn nguồn manual | [ ] |
| SC-008: Không push ra biên nội bộ | Tenant khách A tồn tại trong hệ thống | Kiểm tra toàn bộ luồng push | Không có kênh nào gửi alert tới thiết bị khách; push chỉ tới vai nội bộ được phân quyền | [ ] |

> **Liên kết:** SC-001→005 map REQ-FIN-002 (A3 finance.md, BR-FIN-104); SC-006→007 map ràng buộc touchpoint mobile + DI-007 degraded mode; SC-008 map REQ-FIN-017 (biên tenant).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — WalletBalanceAlert, EscalationStep (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — alert feed, push notification service, SLA clock API | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW freshness ≤1h, biên OPS/FIN alert, counterparts | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (alert list, SLA clock, push templates) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 + policy `kiem-soat-vi-tkqc-giao-dich-tien.md` | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
