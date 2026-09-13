# Tính Năng: AML monitoring T1–T6 + hoàn tiền đúng nguồn

> **Dựa trên:** REQ-FIN-010 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md` (BR-FIN-401/402/403/404/405, BR-FIN-603), `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS §3.10)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-005-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-FIN-010 (REQ xuất hiện ở 3 systems). Counterparts: SYS-CORE-BACKEND (rule engine T1–T6 chạy trên ledger — enforce ở service layer), SYS-BCERP-WEB (danh sách cảnh báo theo mức, workflow điều tra — kênh chính). Touchpoint Mobile nội bộ là **app React Native offline-capable**: bản spec này mô tả trải nghiệm **nhận push alert vàng/đỏ + theo dõi trạng thái điều tra/hoàn tiền trên di động** — mobile không kênh điều tra, không hiển thị hồ sơ KYC/UBO chi tiết (giới hạn BR-FIN-603).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-005 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-010 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (ledger — nguồn dữ liệu chấm điểm); FEAT-CORE-WALLET-006 (rule engine T1–T6 + quy trình điều tra trên Core) |
| Ghi chú Expert (A7) | Dept doc finance.md có cấu trúc A7; phần review chưa thực hiện chính thức. Ngưỡng T1–T6 và UBO ≥25% dùng mức mặc định đã chốt theo DI-001 (chờ tư vấn AML/luật sư rà soát — cấu hình được trên hệ thống, không sửa code). Compliance không lập vai riêng (DI-006): FIN_L2 xử lý + BOD oversight độc lập |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa giám sát chống rửa tiền lên Mobile nội bộ để FIN_L1, FIN_L2 và BOD_CFO_CTO nhận ngay trên điện thoại mọi cảnh báo vàng/đỏ do rule engine T1–T6 phát hiện trên các lệnh nạp/hoàn/điều chỉnh của ví TKQC, theo dõi trạng thái khóa mềm (hold) và tiến độ điều tra 24h, đồng thời thấy được trạng thái các lệnh hoàn tiền bị chặn do vi phạm quy tắc "hoàn đúng nguồn". Rủi ro gốc là rửa tiền qua ví TKQC trên 2.600+ tài khoản đa kênh quốc tế — mobile bảo đảm người có trách nhiệm không bỏ lỡ cảnh báo chỉ vì không ngồi máy tính, trong khi toàn bộ quyết định điều tra và báo cáo vẫn nằm ở kênh Web/Core có audit log đầy đủ.

**Phạm vi:**
- Bao gồm: push alert theo mức Vàng/Đỏ cho 6 quy tắc T1–T6 (ngưỡng cấu hình trên Core, không sửa code); màn danh sách cảnh báo đang mở theo mức kèm đồng hồ SLA điều tra 24h và trạng thái escalate BOD (cho cảnh báo đỏ); màn chi tiết cảnh báo ở mức tóm tắt (khách/TKQC/giao dịch vi phạm + ngưỡng vượt) — không hiển thị hồ sơ KYC/UBO chi tiết theo BR-FIN-603; trạng thái lệnh hoàn bị chặn T4 (đổi beneficiary) và trạng thái hoàn đúng nguồn của lệnh đang xử lý; thông báo khi giao dịch được đóng băng/giải tỏa; cache offline danh sách cảnh báo kèm nhãn thời điểm.
- Không bao gồm: rule engine chấm điểm và ngưỡng (Core); workflow điều tra — ghi trạng thái, người xử lý, lý do đóng/duyệt (Web — kênh chính); quyết định BOD đối với cảnh báo đỏ và yêu cầu đổi beneficiary (Web bằng văn bản); báo cáo AML định kỳ (Web — báo cáo tháng); hiển thị hồ sơ KYC/EDD/UBO đầy đủ (Web, theo phân loại Restricted — BR-FIN-603); báo cáo cơ quan chức năng (quy trình pháp lý ngoài hệ thống — phối hợp luật sư/tư vấn AML).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Nhận push đỏ ngay khi rule T2 (tách nhỏ ≥3 lệnh/24h tổng ≥200 triệu VND) bắn cảnh báo | Bắt đầu điều tra trong khung SLA 24h kể cả khi đang di chuyển, không chờ về văn phòng |
| 2 | FIN_L2 | Nhận push vàng cho T1/T5/T6 và xem chi tiết vi phạm (giao dịch + ngưỡng vượt) | Sàng lọc nhanh mức vàng trên điện thoại, chỉ vào Web xử lý những case thật sự nghi vấn |
| 3 | BOD_CFO_CTO | Nhận push khi cảnh báo đỏ được escalate lên BOD trong 24h tiếp theo | Thực hiện vai oversight độc lập đúng hạn, biết ngay case nào cần quyết định |
| 4 | FIN_L1 | Nhận thông báo lệnh hoàn tôi đề xuất bị chặn T4 vì đổi beneficiary | Hiểu ngay lý do chặn, không thắc mắc hay thử đường vòng — và ghi nhớ hoàn phải đúng nguồn |
| 5 | FIN_L2 | Theo dõi trên mobile trạng thái điều tra từng case (đang điều tra — ai giữ — đã đóng/đã escalate) | Bàn giao và giám sát tiến độ điều tra không bị đứt khi thay đổi người trực |
| 6 | FIN_L1 | Nhận thông báo một giao dịch đang hold AML đã được giải tỏa hoặc bị từ chối vĩnh viễn | Cập nhật trạng thái đúng cho khách/AM mà không phải hỏi lại FIN_L2 |
| 7 | BOD_CFO_CTO | Xem tổng quan số cảnh báo vàng/đỏ đang mở và SLA xử lý trên điện thoại | Nắm áp lực compliance cấp tổ hợp giữa các cuộc họp, trước khi có báo cáo tháng |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — rule engine và quy trình điều tra nằm ở service layer Core; mobile chỉ nhận kết quả, phản ánh trạng thái và không mở bất kỳ luồng quyết định AML nào.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS §3.5/3.8). Rule engine chấm điểm trên dữ liệu ledger gốc theo tiền tệ gốc — mobile hiển thị cảnh báo kèm đúng tiền tệ/ snapshot của giao dịch vi phạm | Hiển thị sai tiền tệ/snapshot giao dịch vi phạm → lỗi dữ liệu; render lấy nguyên văn từ API Core |
| BR-W02 | Công thức topup `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`, NET/GROSS 2 chiều (CMS §5): ngưỡng quy đổi so ngưỡng (VD 200 triệu VND) do Core chuẩn hóa theo tỷ giá quy chuẩn — mobile không tự quy đổi để so ngưỡng | Mobile không tự tính chuyển đổi tiền tệ cho ngưỡng; hiển thị giá trị chuẩn hóa do Core trả kèm nhãn nguồn tỷ giá |
| BR-W03 | **Rule engine 6 quy tắc, ngưỡng cấu hình được không sửa code** (BR-FIN-403): T1 nạp ≥3× bình quân 30 ngày (Vàng); T2 tách nhỏ ≥3 lệnh/24h tổng ≥200 triệu VND (Đỏ); T3 nguồn vùng FATF rủi ro cao (Đỏ); T4 hoàn tiền đổi beneficiary (Đỏ — chặn mặc định); T5 vòng tiền nạp–hoàn 72h không có chi tiêu tương ứng (Vàng); T6 hoàn ≥50% giá trị nạp trong kỳ (Vàng). Ngưỡng dùng mức mặc định đã chốt theo DI-001, chờ tư vấn AML/luật sư rà. **Cấm tắt monitoring cho bất kỳ khách nào** kể cả VIP. Khách EDD → ngưỡng siết 50% theo cấu hình | Mobile không cung cấp giao diện tắt monitoring hay sửa ngưỡng; cảnh báo xuất phát từ engine luôn hiển thị đúng mức (Vàng/Đỏ) — render sai mức là bug P0 |
| BR-W04 | **Hoàn tiền đúng nguồn** (BR-FIN-402): hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK nguồn nạp trùng tên pháp nhân KYC — cấm hoàn bên thứ ba; lệnh đổi beneficiary bị chặn mặc định + cảnh báo T4; chỉ BOD xem xét lại bằng văn bản 3 ngày làm việc, kết quả lưu vĩnh viễn. Mobile hiển thị trạng thái các lệnh hoàn bị chặn/đang xử lý đúng nguồn | Mobile không mở luồng "duyệt lại T4"; hiển thị "bị chặn T4 — BOD xem xét bằng văn bản" nguyên văn |
| BR-W05 | **Quy trình cảnh báo: đóng băng → điều tra → BOD → quyết định** (BR-FIN-404): giao dịch nghi vấn bị khóa mềm (hold) đến khi có quyết định — cấm xử lý song song; điều tra 24h; vàng vô hại → đóng + lý do, có nghi vấn → nâng đỏ; đỏ → escalate BOD trong 24h tiếp; quyết định ghi lý do bằng văn bản lưu vĩnh viễn. **Người đề xuất/nhập giao dịch không tự điều tra** (SoD). Mobile chỉ phản ánh trạng thái + push escalation | Mobile không có nút điều tra/đóng/nâng mức; mọi cố gọi API thay đổi trạng thái điều tra từ mobile → Core từ chối `AML_INVESTIGATION_WEB_ONLY` |
| BR-W06 | Dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền (CMS §3.6): lệnh hoàn từng bước duyệt theo FEAT-MBI-WALLET-003 — giao dịch đang hold AML không vào hàng chờ duyệt thường | Nếu một lệnh hold vẫn nhận được chữ ký duyệt → Core chặn `AML_HOLD_BLOCK`; mobile hiển thị trạng thái hold kèm lý do |
| BR-W07 | Đối trừ 3 số tự động (dung sai 0/0,5%·10USD/1%·20USD), chốt & khóa kỳ (REQ-FIN-004 — counterpart Core/Web): cảnh báo AML gắn giao dịch, không phụ thuộc trạng thái đối soát — mobile hiển thị hai tín hiệu độc lập, không suy diễn "đối soát lệch = AML" | Không gộp/mẹo hiển thị giữa discrepancy và AML alert; mỗi cảnh báo gắn đúng giao dịch + ngưỡng vi phạm |
| BR-W08 | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h (REQ-FIN-002 — FEAT-MBI-WALLET-002) là luồng alert khác mục đích: alert AML KHÔNG gợi ý hành động top-up/giảm ngân sách | Màn AML không chứa action vận hành ví; hai loại alert tách kênh, tránh người dùng nhầm ưu tiên |
| BR-W09 | **Dữ liệu hạn chế trên mobile** (BR-FIN-603 — PDPA/Restricted): hồ sơ KYC/UBO chi tiết không hiển thị trên mobile — chỉ tóm tắt mức cảnh báo (khách/TKQC/giao dịch/ngưỡng); hồ sơ đầy đủ xem trên Web với phân quyền tương ứng | Màn mobile xuất hiện trường định danh nhạy cảm (số giấy tờ, UBO đầy đủ) → vi phạm bảo vệ dữ liệu, chặn release |
| BR-W10 | Portal chỉ đọc số dư ví (REQ-FIN-017) — **tenant isolation**: tồn tại cảnh báo AML là thông tin nội bộ tuyệt mật, không bao giờ hiện ở kênh khách; rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10) — không liên quan alert | Phát hiện thông tin AML rò ra kênh khách → sự cố bảo mật nghiêm trọng, meta-log + khóa truy cập |
| BR-W11 | Báo cáo AML định kỳ & lưu hồ sơ (BR-FIN-405): retention hồ sơ KYC/AML ≥5 năm (khởi điểm, chờ luật sư xác nhận); hồ sơ thuộc điều tra đang mở giữ đến khi đóng. Mobile có thể xem tổng hợp số liệu tháng (số lượng vàng/đỏ, SLA, tỷ lệ escalation) ở chế độ dashboard rút gọn | Mobile không xuất/nhập chứng từ điều tra; báo cáo đầy đủ làm trên Web — mobile chỉ đọc tổng hợp |
| BR-W12 | Offline: danh sách cảnh báo + trạng thái điều tra cache kèm nhãn "cập nhật lúc HH:MM"; khi offline case AML phải hiển thị "dữ liệu có thể đã thay đổi — trạng thái hold vẫn hiệu lực cho đến khi Core xác nhận"; mọi thông báo "đã giải tỏa" chỉ tin khi sync online | Mobile hiển thị "đã giải tỏa" từ dữ liệu cache cũ → nguy cơ xử lý giao dịch nhầm; bắt buộc re-validate khi online |

**Giả định chờ xác nhận:** ngưỡng T1–T6 + UBO ≥25% + retention ≥5 năm là mức mặc định chốt theo DI-001, chờ tư vấn AML/luật sư xác nhận chính thức — tất cả cấu hình được trên Core, mobile không chứa hằng số cứng. 11 KXN còn mở (`[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]`) thuộc domain CRM/lifecycle — không tác động rule AML, không tự quyết.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Compliance không lập vai riêng (DI-006): FIN_L2 xử lý, BOD_CFO_CTO oversight độc lập. Toàn bộ quyền điều tra/quyết định nằm ở Web/Core; mobile chỉ nhận + xem.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | CUSTOMER |
|-----------|--------|--------|-------------|-----------|----------|
| Nhận push alert vàng/đỏ | ✅ (vàng + liên quan lệnh mình) | ✅ | ✅ (đỏ + escalate) | ❌ | ❌ |
| Xem danh sách cảnh báo + chi tiết tóm tắt | ✅ | ✅ (toàn bộ) | ✅ | ❌ | ❌ |
| Xem hồ sơ KYC/UBO chi tiết trên mobile | ❌ (chỉ Web) | ❌ (chỉ Web) | ❌ (chỉ Web) | ❌ | ❌ |
| Điều tra / đóng / nâng mức cảnh báo trên mobile | ❌ (chỉ Web) | ❌ (chỉ Web) | ❌ (chỉ Web) | ❌ | ❌ |
| Quyết định case đỏ (duyệt/từ chối bằng văn bản) | ❌ | ❌ (chuẩn bị hồ sơ trên Web) | ✅ (trên Web — bằng văn bản) | ❌ | ❌ |
| Tắt monitoring / sửa ngưỡng T1–T6 | ❌ | ❌ | ❌ (cấu hình hệ thống qua luồng Web + ký duyệt) | ❌ (kỹ thuật vận hành cấu hình, không tắt monitoring) | ❌ |
| Xem trạng thái lệnh hoàn đúng nguồn/bị chặn T4 | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem dashboard tổng hợp AML tháng (rút gọn) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Xem bất kỳ thông tin AML nào (kênh khách) | ❌ | ❌ | ❌ | ❌ | ❌ (tuyệt mật nội bộ) |

---

## 5. Trường Hợp Đặc Biệt

- **Người đề xuất giao dịch là FIN_L1:** SoD cấm tự điều tra — case tự chuyển sang người điều tra khác theo phân công (FIN_L2); mobile của FIN_L1 chỉ nhận thông báo kết quả, không thấy nút "nhận điều tra".
- **Nâng mức vàng → đỏ giữa chừng:** mobile cập nhật màu cảnh báo và push thêm khi FIN_L2 nâng mức; toàn bộ lịch sử nâng/đóng hiển thị dạng dòng thời gian để truy vết quyết định.
- **Khách EDD:** ngưỡng T1–T6 tự siết 50% — cảnh báo phát sinh nhiều hơn bình thường; mobile hiển thị nhãn "khách EDD" để người nhận hiểu mật độ cao là chủ đích, không phải lỗi.
- **T4 bị nhắc lại qua Portal:** khách yêu cầu hoàn cho tài khoản khác tên — lệnh chặn mặc định; AM được FIN_L1 phản hồi bằng trạng thái chuẩn; mobile FIN hiển thị "chờ BOD xem xét bằng văn bản" với hạn 3 ngày làm việc.
- **Giao dịch hold kéo dài qua nhiều kỳ:** hold không bị "quên" khi chốt kỳ — Core giữ trạng thái và chặn chốt liên quan giao dịch đó; mobile hiển thị "đang hold — vượt SLA điều tra" để FIN_L2/BOD nhận diện case trễ.
- **Nghi vấn rửa tiền được xác thực:** thực hiện nghĩa vụ báo cáo cơ quan chức năng theo pháp luật, phối hợp luật sư/tư vấn AML — quy trình pháp lý ngoài app; mobile chỉ phản ánh trạng thái "đã chuyển cơ quan chức năng" và khóa mọi hiển thị chi tiết case trên thiết bị di động cho an toàn dữ liệu.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Cảnh báo AML (tạo bởi rule engine Core; mobile phản ánh).

**Sơ đồ trạng thái:**
```
[MỚI — VÀNG] ──(điều tra: vô hại)──────────────► [ĐÓNG — CÓ LÝ DO]
     │  └──(điều tra: có nghi vấn)──► [NÂNG ĐỎ] ──┐
                                                 ▼
[MỚI — ĐỎ] ──(escalate BOD trong 24h)──► [CHỜ QUYẾT ĐỊNH BOD] ──(duyệt/từ chối bằng văn bản)──► [ĐÃ QUYẾT ĐỊNH — LƯU VĨNH VIỄN]
     │                                                                                          │
     └──(giao dịch hold)──► [HOLD HIỆU LỰC] ◄───────────────────────────────────────────────────┘
                                  (giải tỏa khi quyết định cho phép)
```

**Bảng chuyển đổi (mobile phản ánh + push tại các mốc có alert):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép (nơi thật) | Điều kiện bắt buộc |
|---------------------|-----------|----------------|--------------------------|---------------------|
| `MỚI — VÀNG` | Điều tra: vô hại | `ĐÓNG — CÓ LÝ DO` | FIN_L2 — Web | Lý do bắt buộc; người điều tra ≠ người đề xuất giao dịch |
| `MỚI — VÀNG` | Điều tra: có nghi vấn | `NÂNG ĐỎ` | FIN_L2 — Web | Lý do bắt buộc; push lại cho FIN/BOD |
| `MỚI — ĐỎ` / `NÂNG ĐỎ` | Escalate BOD | `CHỜ QUYẾT ĐỊNH BOD` | Hệ thống (trong 24h) | Push đỏ tới BOD_CFO_CTO |
| `CHỜ QUYẾT ĐỊNH BOD` | Quyết định | `ĐÃ QUYẾT ĐỊNH` | BOD_CFO_CTO — Web bằng văn bản | Lý do văn bản lưu vĩnh viễn |
| Bất kỳ (giao dịch nghi vấn) | Khóa mềm | `HOLD HIỆU LỰC` | Hệ thống (Core) | Cấm xử lý song song; giải tỏa chỉ theo quyết định |
| `ĐÓNG` / `ĐÃ QUYẾT ĐỊNH` | — | Trạng thái kết thúc | — | Hồ sơ lưu ≥5 năm; case điều tra mở giữ đến khi đóng |

**Quy tắc:**
- Mobile không là tác nhân của bất kỳ chuyển đổi nào — xuất hiện luồng đổi trạng thái AML từ mobile là lỗi kiến trúc nghiêm trọng.
- `HOLD HIỆU LỰC` không phụ thuộc hiển thị: khi offline, giao dịch vẫn bị hold cho đến khi Core xác nhận giải tỏa — mobile phải hiển thị nguyên tắc này.
- Mọi quyết định lưu vĩnh viễn, truy xuất theo khách/TKQC/giao dịch/cảnh báo (BR-FIN-405) — mobile chỉ đọc tổng hợp, không xuất chứng từ.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mobile tiêu thụ — nguồn sự thật thuộc Core (`technical-specs/database-design.md`).*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `AmlAlert` | `rule` (T1–T6), `level` (VÀNG/ĐỎ), `customer_id`, `ad_account_id`, `transaction_id`, `threshold_breached`, `status` | FK → giao dịch ledger | Chi tiết tóm tắt — không chứa KYC/UBO |
| `InvestigationRecord` | `alert_id`, `investigator_id`, `status`, `reason`, `opened_at`, `closed_at` | FK → `aml_alerts.id` | Mobile chỉ xem trạng thái + người giữ; lý do đọc được |
| `TransactionHold` | `transaction_id`, `held_at`, `released_at`, `decision_ref` | FK → `wallet_transactions.id` | Hiển thị "hold hiệu lực" kể cả offline |
| `BeneficiaryBlock` (T4) | `refund_request_id`, `blocked_at`, `bod_review_ref` | FK → lệnh hoàn | Trạng thái "bị chặn T4 — chờ BOD văn bản" |
| `OfflineCache` (client-side) | `synced_at`, `payload`, `device_id` | Gắn thiết bị | Nhãn thời điểm + cảnh báo dữ liệu có thể đổi |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push đỏ T2 | Khách tạo lệnh nạp thứ 3 trong 24h, tổng ≥200 triệu VND | Core bắn cảnh báo đỏ | Push đỏ tới FIN_L2/BOD trong vài phút; chi tiết hiển thị ngưỡng vi phạm + giao dịch | [ ] |
| SC-002: Mức vàng/đỏ đúng rule | Bộ case mẫu phủ T1, T5, T6 (vàng) và T2, T3, T4 (đỏ) | Xem danh sách cảnh báo | Mỗi case gắn đúng rule + mức; nhãn EDD hiển thị với khách EDD | [ ] |
| SC-003: Không hiển thị KYC/UBO trên mobile | Case có hồ sơ KYC đầy đủ ở Core | Mở chi tiết cảnh báo trên mobile | Chỉ thấy tóm tắt (khách/TKQC/giao dịch/ngưỡng); không có trường giấy tờ/UBO | [ ] |
| SC-004: Không có luồng điều tra trên mobile | FIN_L2 mở một case vàng | Rà UI + API của app | Không có nút điều tra/đóng/nâng mức; Core từ chối `AML_INVESTIGATION_WEB_ONLY` khi gọi trực tiếp | [ ] |
| SC-005: T4 chặn và hiển thị | Lệnh hoàn đổi beneficiary | FIN_L1 xem trạng thái lệnh | Hiển thị "bị chặn T4 — BOD xem xét bằng văn bản"; không có đường duyệt lại trên app | [ ] |
| SC-006: Escalate BOD 24h | Cảnh báo đỏ chưa quyết định sau 24h | Kiểm tra trạng thái | Trạng thái "chờ quyết định BOD"; push đã gửi BOD_CFO_CTO; mobile hiển thị đồng hồ escalate | [ ] |
| SC-007: Hold hiệu lực khi offline | Giao dịch đang hold, app offline | Xem chi tiết giao dịch | Hiển thị "hold hiệu lực cho đến khi Core xác nhận"; không có tín hiệu "đã giải tỏa" từ cache | [ ] |
| SC-008: Cấm tắt monitoring | Cố tìm tùy chọn tắt monitoring cho khách VIP | Rà toàn app | Không tồn tại tùy chọn; ngưỡng chỉ đổi được qua luồng cấu hình Web có ký duyệt | [ ] |
| SC-009: Không lộ AML ra kênh khách | Tenant khách tồn tại | Kiểm tra toàn bộ kênh khách | Không có bất kỳ thông tin cảnh báo AML nào xuất hiện ở Portal/M-PORTAL | [ ] |

> **Liên kết:** SC-001→002, 005→006, 008 map REQ-FIN-010 (BR-FIN-402/403/404); SC-003, 009 map BR-FIN-603/REQ-FIN-017; SC-004 map SoD BR-FIN-404; SC-007 map ràng buộc touchpoint mobile.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — AmlAlert, InvestigationRecord, TransactionHold (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — AML alert feed cho mobile, push service (read-only) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — rule engine, FATF list sync (GW), biên Web/Mobile, retention | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (AML alert list, case status, dashboard rút gọn) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — policy `aml-kyc-giam-sat-giao-dich.md` + `bao-ve-du-lieu-ca-nhan.md` | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
