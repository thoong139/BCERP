# Tính Năng: Financial Hard Stop "đã khớp tiền" FIN_L1

> **Dựa trên:** REQ-FIN-006 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md` (BR-FIN-302), `phase1-business/departments/operations/operations.md` (REQ-OPS-002, BR-OPS-2.1/2.2)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-004-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-FIN-006 (REQ xuất hiện ở 3 systems). Counterparts: SYS-CORE-BACKEND (hard stop thực thi trong code tầng API — không override), SYS-BCERP-WEB (kênh duy nhất FIN_L1 xác nhận "Đã khớp tiền" với MFA TOTP). Touchpoint Mobile nội bộ là **app React Native offline-capable**: bản spec này mô tả trải nghiệm **chỉ-đọc + alert** — mobile cố ý KHÔNG có action xác nhận khớp tiền nào để không tồn tại nút duyệt có thể bypass Hard Stop; REQ-OPS-002 (cross-dependency) chủ ý không có bản mobile để cùng lý do đó.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-004 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-006 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ1 — trụ cột số 1 của FINANCE, MVP) |
| Giai đoạn | Giai đoạn 1 (bản mobile alert đi cùng khung tối thiểu GĐ1; đầy đủ theo REQ-FIN-006) |
| Phụ thuộc | FEAT-CORE-WALLET-005 (engine hard stop + xác nhận khớp tiền trên Core); REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn (DR handoff — bản OPS thuộc SYS-CORE-BACKEND/SYS-BCERP-WEB, không có bản mobile theo chủ ý thiết kế) |
| Ghi chú Expert (A7) | Dept doc finance.md có cấu trúc A7; phần review chưa thực hiện chính thức. Điểm phối hợp liên phòng đã xác định: gate Hard Stop nằm trong vòng đời cấp phát TKQC do OPS vận hành, FIN nắm quyền xác nhận — mobile phản ánh trạng thái cho cả hai phía nhưng không nắm action nào |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa trạng thái Financial Hard Stop lên Mobile nội bộ để FIN_L1, FIN_L2 và BOD_CFO_CTO biết ngay trên điện thoại lệnh nạp nào đã được xác nhận "Đã khớp tiền", lệnh nào đang chặn việc cấp phát TKQC, và nhận alert tức thì khi có thu hồi xác nhận — mà **tuyệt đối không cung cấp bất kỳ nút hành động nào** liên quan việc khớp tiền. Hard Stop là trụ cột số 1 của FINANCE: không bao giờ cấp TKQC/bật chi tiêu khi tiền của khách chưa về và chưa khớp lệnh nạp; việc xác nhận chỉ hợp lệ trên Web nội bộ với MFA TOTP, còn mobile tồn tại để người có quyền biết tình hình mọi lúc mà không tạo ra kênh duyệt thứ hai có thể bị lạm dụng.

**Phạm vi:**
- Bao gồm: push alert khi lệnh nạp chuyển sang "Đã khớp tiền" (mở điều kiện Hard Stop) và khi xác nhận bị thu hồi (TK tự về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL); màn danh sách lệnh chờ khớp tiền với trạng thái từng lệnh; màn chi tiết hiển thị evidence (sao kê/lệnh nạp) ở chế độ đọc; trạng thái Hard Stop của từng TKQC/yêu cầu cấp phát FIN đang theo dõi; chế độ offline cache danh sách trạng thái kèm nhãn thời điểm sync.
- Không bao gồm: xác nhận "Đã khớp tiền" (chỉ trên SYS-BCERP-WEB với MFA TOTP — mobile không có nút, không có luồng, không có API ký nào trỏ tới action này); thu hồi xác nhận (Web/Core); chặn cấp phát thực thi (Core workflow engine — chặn trong code tầng API); đề xuất nạp của OPS (bản OPS thuộc Web/Core theo REQ-OPS-002 — mobile không có luồng đề xuất để không tồn tại nút bypass); mở khóa thủ công (không tồn tại ở bất kỳ kênh nào — mọi yêu cầu bị từ chối và ghi audit log bất biến).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Nhận push nhắc khi có lệnh nạp đã APPROVED đang chờ mình đối chiếu và xác nhận khớp tiền | Không bỏ sót lệnh nào làm OPS chờ cấp phát, dù mình đang di chuyển |
| 2 | FIN_L1 | Nhận push xác nhận "Đã khớp tiền" đã được ghi thành công (kênh Web) kèm evidence | Biết chắc gate đã mở đúng lệnh, có căn cứ lưu về thiết bị để tra lại |
| 3 | FIN_L1 | Nhận alert đỏ ngay khi một xác nhận khớp tiền bị thu hồi và TKQC tự về "Tạm dừng chi tiêu" | Phản ứng tức thì với sai sót khớp tiền, phối hợp TL xử lý trước khi ảnh hưởng khách |
| 4 | FIN_L2 | Xem danh sách toàn bộ lệnh chờ khớp tiền và trạng thái Hard Stop theo khách | Giám sát tiến độ khớp tiền của FIN_L1 và rủi ro chặn cấp phát mà không phải mở Web |
| 5 | BOD_CFO_CTO | Xem tổng quan số TKQC đang bị chặn bởi Hard Stop và số lệnh chờ khớp tiền | Nắm rủi ro vận hành cấp tổ hợp; hiểu vì sao một khách chưa được cấp TK dù đã "hứa chuyển" |
| 6 | FIN_L2 | Khi ai đó hỏi "sao chưa cấp TK được", mở mobile tra ngay trạng thái chặn của TK đó kèm lý do chuẩn | Trả lời bằng trạng thái hệ thống thay vì suy đoán, nhất quán với thông điệp "khách hứa chuyển không mở khóa được" |
| 7 | FIN_L1 | Xem trạng thái Hard Stop khi offline (cache lần sync gần nhất, có nhãn thời điểm) | Tra cứu được căn cứ khi đi đường sóng yếu mà không nhầm với trạng thái realtime |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — hard stop được enforce trong code của Core workflow engine (không nút override, không route bypass); mobile là bề mặt thông tin và bị khóa cứng ở mức build khỏi mọi action khớp tiền.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS §3.5/3.8). Trạng thái khớp tiền gắn từng lệnh nạp theo tiền tệ gốc của lệnh — mobile hiển thị đúng tiền tệ, không quy đổi hộ | Hiển thị sai tiền tệ của lệnh → lỗi dữ liệu; cảnh báo trong app và log |
| BR-W02 | Công thức topup `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`, NET/GROSS 2 chiều (CMS §5) — nếu evidence hiển thị breakdown topup, mobile render đúng snapshot đã lưu của Core | Mobile không tự tính lại k; số render lệch Web cho cùng lệnh → chặn release |
| BR-W03 | **Mobile chỉ alert/xem — KHÔNG xác nhận khớp tiền trên Mobile** (REQ-FIN-006 touchpoint; BR-FIN-302): xác nhận chỉ thực hiện trên WEB với MFA TOTP; app mobile không có nút, form, API ký hoặc luồng xác nhận/thu hồi khớp tiền nào | Bắt buộc kiểm tra build: không tồn tại đường dẫn UI/API từ app tới action xác nhận; phát hiện → bug P0 chặn release |
| BR-W04 | "Đã khớp tiền" = tiền đã về tài khoản BC **và** khớp số với lệnh nạp; mỗi xác nhận bắt buộc gắn evidence (sao kê ngân hàng/lệnh nạp) + timestamp (BR-FIN-302). Mobile hiển thị evidence ở chế độ đọc kèm watermark người xem | Hiển thị lệnh "đã khớp" thiếu evidence/timestamp → lỗi dữ liệu; báo lỗi thay vì render nửa vời |
| BR-W05 | **Không nút override — không vai nào bypass kể cả CEO/Super Admin**; không chấp nhận "chờ duyệt"/"khách hứa chuyển"/"đang chuyển" — các lý do này không có giá trị mở khóa; mọi yêu cầu mở khóa thủ công bị từ chối + audit log bất biến (BR-FIN-302, REQ-OPS-002, BR-OPS-2.1). Mobile hiển thị các trạng thái từ chối này nguyên văn trong chi tiết TK bị chặn | App không được hiển thị bất kỳ nhãn hàm ý "sắp được mở"/"ngoại lệ" nào; không có trường nhập lý do xin mở khóa |
| BR-W06 | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h (REQ-FIN-002 — FEAT-MBI-WALLET-002) là tín hiệu độc lập: một lệnh khớp tiền không tự động liên quan alert số dư; mobile giữ hai bức tranh riêng | Không gộp trạng thái Hard Stop vào alert số dư; mỗi màn hiển thị đúng nguồn dữ liệu của nó |
| BR-W07 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0/0,5%·10USD/1%·20USD, chốt & khóa kỳ (REQ-FIN-004 — counterpart Core/Web): khớp tiền theo sao kê ở bước này là đầu vào của đối trừ — mobile chỉ hiển thị trạng thái đối soát của lệnh (nếu có), không thao tác | Mobile không có màn xử lý discrepancy; hiển thị "xử lý trên Web nội bộ" khi user chạm vào trạng thái chênh lệch |
| BR-W08 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn (REQ-FIN-010 — FEAT-MBI-WALLET-005); Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10): lệnh nạp đang hold AML không được hiển thị như "sắp khớp được" — mobile hiển thị trạng thái hold rõ ràng | Trạng thái hold bị render thành trạng thái thường → lỗi; hold phải nổi bật và không có action |
| BR-W09 | Thu hồi xác nhận sai → TK tự chuyển "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL (BR-FIN-302, BR-OPS-2.2): mobile nhận alert thu hồi trong vòng vài phút từ lúc Core ghi nhận; thông tin bao gồm TKQC bị ảnh hưởng, người thu hồi, lý do | Mobile hiển thị thu hồi trễ/thiếu thông tin → lỗi khối alert; test kịch bản thu hồi trước release |
| BR-W10 | Portal khách chỉ đọc số dư ví qua view tenant (REQ-FIN-017) — **tenant isolation**: trạng thái Hard Stop là thông tin nội bộ, không bao giờ xuất hiện ở bất kỳ kênh khách nào; mobile nội bộ cũng chỉ hiển thị cho vai nội bộ được phân quyền | Phát hiện trạng thái Hard Stop lộ ra kênh khách → sự cố bảo mật; meta-log toàn bộ truy cập |

**Giả định chờ xác nhận:** SLA phản hồi alert thu hồi dùng cấu hình hệ thống (mục tiêu thiết kế vài phút, không chốt con số mới). 11 KXN còn mở (`[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]`) thuộc domain CRM/lifecycle — không tác động rule Hard Stop của spec này, không tự quyết.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Cột "Xác nhận khớp tiền" cố ý để ❌ toàn bộ các hàng mobile — đó là điểm then chốt của thiết kế; action này chỉ tồn tại ở SYS-BCERP-WEB.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_PLAN/OPS_AM/OPS_ADS (TL/bị chặn) | SYS_ADMIN | CUSTOMER |
|-----------|--------|--------|-------------|----------------------------------------|-----------|----------|
| Xem danh sách lệnh chờ khớp tiền | ✅ | ✅ (toàn bộ) | ✅ (tổng hợp) | ❌ (chỉ thấy trạng thái Hard Stop của TK mình chờ — qua hệ thống OPS) | ❌ | ❌ |
| Xem chi tiết lệnh + evidence (chế độ đọc) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xác nhận "Đã khớp tiền" trên mobile | ❌ **(chỉ Web + MFA)** | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thu hồi xác nhận khớp tiền trên mobile | ❌ (chỉ Web) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nhận push "đã khớp tiền" / "thu hồi" | ✅ | ✅ | ✅ | ✅ (alert TL khi thu hồi — bản OPS) | ❌ | ❌ |
| Xem trạng thái Hard Stop theo TKQC | ✅ | ✅ | ✅ | ✅ (TK phụ trách — chỉ đọc) | ❌ | ❌ |
| Yêu cầu mở khóa thủ công | ❌ (không tồn tại luồng) | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin) | ❌ |
| Override Hard Stop | ❌ | ❌ | ❌ | ❌ | ❌ (kể cả CEO/Super Admin) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Không có exception cho khẩn cấp:** khẩn cấp ngoài giờ vẫn chỉ mở khi đã khớp tiền — xử lý nhanh hơn trên Web, không bỏ bước (BR-OPS-2.1); mobile không phải kênh "giải cứu" — nếu ai đó đề nghị xác nhận qua mobile, app hiển thị hướng dẫn "chỉ thực hiện được trên Web nội bộ".
- **Thu hồi xác nhận sai:** FIN_L1 thu hồi trên Web → Core tự chuyển TK về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL; mobile của FIN_L1/FIN_L2/BOD nhận alert kèm liên kết mở chi tiết TK (chế độ đọc) để phối hợp khắc phục.
- **Mở khóa thủ công bị yêu cầu:** mọi yêu cầu (từ bất kỳ vai nào, kể cả BOD_CFO_CTO) bị từ chối và ghi audit log bất biến; mobile không có trường nhập để phát sinh yêu cầu này — nếu nhấn vào trạng thái "bị chặn", app hiển thị giải thích chính sách nguyên văn.
- **Offline giữa ca:** danh sách trạng thái Hard Stop được cache kèm nhãn "cập nhật lúc HH:MM"; người dùng được cảnh báo không dùng trạng thái cache để trả lời khách về việc cấp phát — trạng thái realtime phải xác nhận lại khi có mạng.
- **Lệnh hold AML trước khớp tiền:** lệnh nạp bị hold AML vẫn đứng ở "chờ khớp tiền" nhưng gắn cờ hold — mobile hiển thị cả hai thông tin để FIN_L1 không xác nhận nhầm lệnh đang điều tra (thực tế xác nhận vẫn chặn ở Core theo quy trình AML).
- **Thiết bị của FIN_L1 bị mất:** thiết bị đăng ký bị vô hiệu hóa; cache trạng thái bị xóa ở lần đăng nhập kế tiếp — alert thu hồi sẽ chuyển tới thiết bị đăng ký mới khi FIN_L1 đăng nhập lại.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Trạng thái khớp tiền của lệnh nạp (đầu vào của Hard Stop) — mobile chỉ-đọc toàn bộ state machine; mọi chuyển đổi thực thi tại Core/Web.

**Sơ đồ trạng thái:**
```
[CHƯA KHỚP TIỀN] ──(FIN_L1 xác nhận — Web + MFA)──► [ĐÃ KHỚP TIỀN] ──(CORE mở điều kiện cấp phát)──► [HARD STOP MỞ]
        ▲                                                      │
        │            (thu hồi xác nhận sai — FIN_L1, Web)      │
        └──────────────── [ĐÃ KHỚP TIỀN BỊ THU HỒI] ◄──────────┘
                    └──► TK tự về [TẠM DỪNG CHI TIÊU] + khóa nạp mới + alert TL
```

**Bảng chuyển đổi (mobile phản ánh kèm người thực hiện + timestamp):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép (kênh thật) | Điều kiện bắt buộc |
|---------------------|-----------|----------------|---------------------------|---------------------|
| `CHƯA KHỚP TIỀN` | Xác nhận khớp tiền | `ĐÃ KHỚP TIỀN` | FIN_L1 — **chỉ Web + MFA TOTP** | Tiền về TK BC và khớp số lệnh; evidence + timestamp |
| `ĐÃ KHỚP TIỀN` | Mở điều kiện cấp phát | `HARD STOP MỞ` | Hệ thống (Core workflow engine) | Tự động theo trạng thái khớp tiền — không thao tác tay |
| `ĐÃ KHỚP TIỀN` | Thu hồi xác nhận sai | `ĐÃ KHỚP TIỀN BỊ THU HỒI` | FIN_L1 — chỉ Web | TK tự về "Tạm dừng chi tiêu", khóa lệnh nạp mới, alert TL |
| `CHƯA KHỚP TIỀN` | Yêu cầu mở khóa thủ công | `CHƯA KHỚP TIỀN` (từ chối) | Không ai được duyệt | Từ chối + audit log bất biến |
| Bất kỳ | Lệnh hold AML | Giữ trạng thái + cờ `AML_HOLD` | Hệ thống (rule AML) | Không được xác nhận khớp tiền khi đang hold |

**Quy tắc:**
- Mobile không có trong cột "kênh thật" của bất kỳ chuyển đổi nào — xuất hiện luồng mobile-đổi-trạng thái là lỗi kiến trúc nghiêm trọng.
- `HARD STOP MỞ` chỉ được tính khi trạng thái khớp tiền của lệnh nạp tương ứng = "Đã khớp tiền"; thu hồi mở lại khóa tức thì.
- Mọi chuyển đổi (kể cả các lần từ chối mở khóa) ghi audit log bất biến — mobile hiển thị trích logs để FIN_L2/BOD giám sát.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mobile tiêu thụ — nguồn sự thật thuộc Core (`technical-specs/database-design.md`).*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `RechargeRequest` | `status` (khớp tiền), `amount`, `currency`, `evidence`, `matched_at`, `confirmed_by` | FK → `customers.id`, `ad_accounts.id` | Danh sách chờ khớp + chi tiết chỉ-đọc |
| `HardStopState` | `ad_account_id`, `blocked` (bool), `reason_ref`, `updated_at` | FK → `ad_accounts.id` | Trạng thái chặn cấp phát theo TKQC |
| `MatchEvidence` | `bank_statement_ref`, `order_ref`, `timestamp` | FK → `recharge_requests.id` | Hiển thị chế độ đọc + watermark người xem |
| `RevokeEvent` | `recharge_request_id`, `revoked_by`, `reason`, `at`, `affected_ad_accounts[]` | FK → `recharge_requests.id` | Nguồn alert thu hồi |
| `OfflineCache` (client-side) | `synced_at`, `payload`, `device_id` | Gắn thiết bị | Chỉ đọc khi offline; nhãn thời điểm bắt buộc |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Không tồn tại nút xác nhận trên mobile | FIN_L1 đăng nhập app với lệnh `CHƯA KHỚP TIỀN` | Rà soát toàn bộ luồng UI + API của app | Không có nút/form/API ký tới action khớp tiền; chỉ hiện "thực hiện trên Web nội bộ" | [ ] |
| SC-002: Push khớp tiền | FIN_L1 vừa xác nhận khớp tiền thành công trên Web | Kiểm tra thiết bị FIN_L1/FIN_L2 | Nhận push "Đã khớp tiền — lệnh #id" kèm evidence trong vài phút | [ ] |
| SC-003: Alert thu hồi | Xác nhận sai bị thu hồi trên Web | Kiểm tra thiết bị FIN_L1/FIN_L2/BOD | Alert đỏ hiển thị TKQC về "Tạm dừng chi tiêu", người thu hồi, lý do | [ ] |
| SC-004: Evidence chỉ-đọc | Lệnh `ĐÃ KHỚP TIỀN` có evidence | Mở chi tiết trên mobile | Hiển thị sao kê/lệnh nạp + timestamp ở chế độ đọc, không có nút hành động | [ ] |
| SC-005: Lý do "hứa chuyển" không mở khóa | TK bị chặn, khách "hứa chuyển" | Nhấn trạng thái bị chặn trên mobile | App hiển thị chính sách nguyên văn; không có trường nhập xin mở khóa | [ ] |
| SC-006: Hold AML hiển thị đúng | Lệnh nạp đang hold AML chờ khớp | Xem danh sách chờ khớp | Lệnh gắn cờ hold nổi bật, không hiển thị như "sắp khớp được", không có action | [ ] |
| SC-007: Offline cache có nhãn | App offline sau khi đã sync | Xem trạng thái Hard Stop | Dữ liệu hiển thị kèm "cập nhật lúc HH:MM"; cảnh báo không dùng cache để trả lời khách | [ ] |
| SC-008: Không lộ trạng thái ra kênh khách | Tenant khách tồn tại | Kiểm tra toàn bộ kênh khách (Portal/M-PORTAL) | Trạng thái Hard Stop không xuất hiện ở bất kỳ kênh khách nào | [ ] |

> **Liên kết:** SC-001→005 map REQ-FIN-006 (BR-FIN-302) + REQ-OPS-002 (BR-OPS-2.1/2.2); SC-006 map REQ-FIN-010 (hold AML); SC-007 map ràng buộc touchpoint mobile; SC-008 map REQ-FIN-017 (biên tenant).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — HardStopState, MatchEvidence, RevokeEvent (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — hard stop status feed cho mobile, push service (không có sign endpoint) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — workflow engine Core, biên OPS/FIN, counterparts Web | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (hard stop status, alert thu hồi) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — policy `quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.1–2.4 | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
