# Tính Năng: AML monitoring T1–T6 + hoàn tiền đúng nguồn

> **Dựa trên:** REQ-FIN-010 trong `phase1-business/departments/finance/finance.md` (Phần B.4 — BR-FIN-402..405)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.10)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-006-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-FIN-010 (fan-out 3 hệ thống); counterpart: SYS-CORE-BACKEND (rule engine chấm điểm tự động, hold), SYS-MOBILE-INTERNAL (push alert vàng/đỏ cho FIN/BOD).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-006 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-010 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (BOD là lớp oversight độc lập — compensating control SoD, không lập vai Compliance riêng theo DI-006) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-WALLET-001 (ledger ví — dữ liệu chấm rule); FEAT-ERP-WALLET-003 (hoàn tiền qua dual approval, T4 chặn mặc định); hồ sơ KYC/UBO theo REQ-FIN-009 |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể. Ngưỡng T1–T6 + UBO ≥25% đã chốt theo mức mặc định 12/09 (DI-001); toàn bộ ngưỡng cấu hình được trên hệ thống, không sửa code; DI-006: KHÔNG lập vai compliance riêng trong registry — FIN_L2 xử lý + BOD oversight độc lập |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Giám sát tầng giao dịch suốt vòng đời khách trên Web nội bộ bằng rule engine 6 quy tắc (T1–T6) chống rửa tiền qua ví TKQC — hệ thống chấm tự động mọi lệnh nạp/hoàn/điều chỉnh, khóa mềm giao dịch nghi vấn, điều tra theo SLA với sự tách bạch công vụ (người đề xuất không tự điều tra), escalate đỏ lên BOD trong 24h — và ép nguyên tắc hoàn tiền chỉ về đúng tài khoản nguồn nạp trùng tên pháp nhân KYC, cấm hoàn cho bên thứ ba.

**Phạm vi:**
- Bao gồm: danh sách cảnh báo theo mức (vàng/đỏ) kèm chi tiết giao dịch vi phạm và ngưỡng chạm; màn hình chi tiết giao dịch nạp gốc khi tạo lệnh hoàn (để dẫn chiếu đúng nguồn); workflow điều tra ghi trạng thái/người xử lý/lý do bắt buộc khi đóng/duyệt/từ chối; màn cấu hình ngưỡng T1–T6 (không sửa code) và tự siết 50% cho khách diện EDD; báo cáo AML tháng (số lượng vàng/đỏ, SLA xử lý, tỷ lệ đóng/escalation).
- Không bao gồm: chấm điểm tự động và hold giao dịch (thực thi ở SYS-CORE-BACKEND); đồng bộ danh sách FATF (GW); push alert vàng/đỏ cho FIN/BOD (SYS-MOBILE-INTERNAL); nhập hồ sơ KYC/UBO ban đầu (REQ-FIN-009 — module KYC, Web chỉ hiển thị trạng thái KYC liên quan giao dịch).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: list cảnh báo + workflow điều tra + màn cấu hình, gọi API core, hiển thị đúng trạng thái machine-state của từng cảnh báo và giao dịch bị hold.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Xem danh sách cảnh báo T1–T6 theo mức vàng/đỏ với chi tiết khách/TKQC/giao dịch + ngưỡng vi phạm | Ưu tiên xử lý đúng SLA 24h, không bỏ sót cảnh báo đỏ |
| 2 | FIN_L2 | Điều tra cảnh báo trong workflow có ghi trạng thái, người xử lý, giấy tờ kiểm tra (hợp đồng, lịch sử nạp–chi, nguồn tiền) | Mỗi quyết định có hồ sơ truy xuất, bảo vệ công ty khi bị thanh tra |
| 3 | FIN_L1 | Khi tạo lệnh hoàn tiền, thấy giao dịch nạp gốc và danh sách TK nhận hợp lệ (trùng tên pháp nhân KYC) | Hoàn đúng nguồn, không lỡ tay hoàn cho bên thứ ba |
| 4 | BOD_CFO_CTO | Nhận escalate cảnh báo đỏ trong 24h và ra quyết định duyệt/từ chối ghi lý do bằng văn bản | Oversight độc lập theo Three Lines of Defense, không kiêm nhiệm điều tra |
| 5 | BOD_CFO_CTO | Cấu hình ngưỡng T1–T6 và xem báo cáo AML tháng (số lượng, SLA, tỷ lệ escalation) | Hiệu chỉnh ngưỡng theo tư vấn AML mà không cần sửa code |
| 6 | SYS_ADMIN | Đồng bộ tham số danh sách quốc gia rủi ro (FATF) vào rule engine định kỳ | Rule T3 luôn dùng danh sách mới nhất |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Rule engine chạy ở CORE; Web bảo đảm quy trình xử lý đúng SLA, đúng vai, không có đường tắt.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-A01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — rule engine chấm trên giao dịch gốc đúng tiền tệ, quy tham chiếu VND theo snapshot tỷ giá của chính giao dịch | Chấm điểm trên số quy đổi sai snapshot bị coi là lỗi dữ liệu; UI hiển thị số gốc + quy VND theo snapshot |
| BR-A02 | Công thức topup k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5) — ngưỡng T1/T2 (giá trị nạp) tính trên grossAmount trừ ví theo snapshot, không tính trên net | Rule chạm ngưỡng hiển thị breakdown tính toán để điều tra đối soát được |
| BR-A03 | **Rule engine T1–T6**, ngưỡng đã chốt mức mặc định (DI-001) và cấu hình được không sửa code: **T1** nạp đơn ≥3× bình quân 30 ngày gần nhất (vàng); **T2** tách nhỏ ≥3 lệnh nạp/24h tổng ≥200 triệu VND hoặc tương đương (đỏ); **T3** nguồn từ quốc gia FATF rủi ro cao hoặc BOD cập nhật (đỏ); **T4** hoàn tiền đổi beneficiary — bất kỳ trường hợp (đỏ, **chặn mặc định**); **T5** vòng tiền nạp rồi hoàn trong 72h không có chi tiêu tương ứng (vàng); **T6** hoàn ≥50% giá trị nạp trong kỳ đối soát (vàng) | Mỗi cảnh báo gắn khách/TKQC/giao dịch + ngưỡng vi phạm; không có cơ chế tắt rule riêng lẻ ngoài cấu hình ngưỡng chính thức |
| BR-A04 | **EDD siết ngưỡng 50%**: khách nước ngoài/khu vực rủi ro cao/flag Knockout K2–K4 → ngưỡng T1–T6 tự siết 50% theo cấu hình; UBO ≥25% là ngưỡng khai báo hồ sơ KYC (REQ-FIN-009) — giao dịch của khách chưa KYC Verified không được xử lý qua luồng thường | Khi trạng thái KYC/EDD đổi, hệ thống áp ngưỡng mới từ giao dịch tiếp theo; UI hiển thị nhãn EDD trên cảnh báo |
| BR-A05 | **Cấm tắt monitoring cho bất kỳ khách nào** — kể cả VIP/khách lâu năm tại khu vực rủi ro cao (chỉ BOD duyệt hợp đồng, không miễn monitoring) | Không tồn tại flag "miễn giám sát"; mọi nỗ lực tắt bị từ chối + log |
| BR-A06 | **Giao dịch nghi vấn bị khóa mềm (hold)** đến khi có quyết định — cấm xử lý song song; điều tra 24h: xác minh hợp đồng, lịch sử nạp–chi tiêu, giấy tờ nguồn tiền; **người đề xuất/nhập giao dịch không được tự điều tra** (SoD BR-FIN-106) | Giao dịch hold không thực thi dù đã có chữ ký duyệt; nút điều tra disabled cho người liên quan đến giao dịch |
| BR-A07 | **Escalation**: cảnh báo vàng vô hại → đóng + ghi lý do, có nghi vấn → nâng đỏ; đỏ → escalate BOD trong 24 giờ tiếp theo; quyết định duyệt/từ chối **ghi lý do bằng văn bản, lưu vĩnh viễn** | Không đóng được cảnh báo thiếu lý do; escalation tự động theo timer, không nhân viên nào trì hoãn được |
| BR-A08 | **Hoàn tiền đúng nguồn**: hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK ngân hàng/ví nguồn nạp trùng tên pháp nhân KYC; cấm hoàn cho bên thứ ba hoặc tài khoản khác tên; yêu cầu đổi beneficiary bị **từ chối mặc định** — chỉ BOD xem xét lại bằng văn bản (3 ngày làm việc), kết quả lưu vĩnh viễn vào hồ sơ AML | Form hoàn chỉ chọn beneficiary từ danh sách TK đã KYC; lệch tên tự chuyển rà thủ công + T4 đỏ |
| BR-A09 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0 / 0,5%·10USD / 1%·20USD, chốt & khóa kỳ — dữ liệu đối soát là đầu vào rule engine; cảnh báo ghi nhận trong kỳ đã khóa vẫn truy xuất được (read-only) | Rule engine không ghi đè dữ liệu đối soát; hồ sơ AML trong kỳ khóa chỉ đọc |
| BR-A10 | Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h (FEAT-ERP-WALLET-002) — alert đỏ cảnh báo số dư không được dùng để "đi nhanh" lệnh nạp qua AML; mọi lệnh nạp vẫn chấm T1–T6 như thường | Không có chế độ "ưu tiên bỏ kiểm tra" trên cả Web lẫn mobile |
| BR-A11 | Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — dòng rebate nhập tay là giao dịch cần chấm rule (T6 hoàn ≥50% có thể chạm rebate) và phải qua duyệt riêng | Rebate không tự động né rule; ghi nhận rebate có note + approvedBy bắt buộc |
| BR-A12 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: hồ sơ AML/điều tra là dữ liệu bảo mật nội bộ cao nhất; khách không thấy tồn tại cảnh báo nào của mình qua Portal | Không có route Portal đụng hồ sơ AML; danh sách cảnh báo không lọt qua API công khai |
| BR-A13 | **Báo cáo & retention**: báo cáo AML tháng cho BOD_CFO_CTO/BOD (số lượng vàng/đỏ, SLA xử lý, tỷ lệ đóng/escalation); hồ sơ KYC + giao dịch + cảnh báo + biên bản điều tra + quyết định lưu **≥5 năm** kể từ kết thúc quan hệ khách hàng (mức khởi điểm `[CẦN CHỐT SỐ — luật sư xác nhận]`); hồ sơ thuộc thanh tra/điều tra đang mở giữ đến khi đóng | Không có giao diện xóa hồ sơ AML; hết hạn retention chỉ chuyển trạng thái lưu trữ, không xóa |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry (DI-006: chủ dự án không duyệt vai compliance/customer-experience riêng — trách nhiệm gán lại FIN_L2 + BOD). Three Lines of Defense: FIN_L1/L2 tuyến 1, FIN_L2 + BOD oversight tuyến 2, Internal Audit tuyến 3.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Xem danh sách cảnh báo vàng/đỏ | ✅ | ✅ | ✅ | ❌ |
| Điều tra cảnh báo | ❌ (nếu liên quan giao dịch mình nhập/đề xuất — chặn tuyệt đối) | ✅ | ❌ (oversight, không kiêm điều tra) | ❌ |
| Đóng cảnh báo vàng (vô hại, ghi lý do) | ❌ | ✅ | ❌ | ❌ |
| Nâng vàng → đỏ | ❌ | ✅ | ❌ | ❌ |
| Quyết định cảnh báo đỏ | ❌ | ❌ (chỉ điều tra + trình) | ✅ (duyệt/từ chối, lý do văn bản) | ❌ |
| Tạo lệnh hoàn tiền đúng nguồn | ✅ | ✅ | ❌ | ❌ |
| Xem xét lại yêu cầu đổi beneficiary (bằng văn bản) | ❌ | ❌ | ✅ | ❌ |
| Cấu hình ngưỡng T1–T6 | ❌ | ❌ | ✅ (phê duyệt) | ✅ (thao tác kỹ thuật) |
| Xem báo cáo AML tháng | ✅ | ✅ | ✅ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Nghi vấn rửa tiền được xác thực → thực hiện nghĩa vụ báo cáo cơ quan chức năng theo quy định pháp luật, phối hợp luật sư/tư vấn AML; hồ sơ điều tra truy xuất theo khách/TKQC/giao dịch/cảnh báo phục vụ cơ quan chức năng.
- Khách tập đoàn nhiều pháp nhân (danh sách trắng trong hợp đồng): giao dịch từ pháp nhân trong danh sách trắng vẫn chấm rule bình thường — danh sách trắng chỉ giải trừ lỗi "khác tên" ở bước hoàn tiền, không miễn giám sát.
- Hoàn tiền do platform trả lại (TKQC die còn dư): FIN_L1 khớp tiền hoàn về theo giao dịch gốc; hoàn cho khách vẫn qua luồng đúng nguồn + dual approval — luồng này không nhảy qua T4/T6.
- Nghi ngờ sai cảnh báo (false positive) do lỗi dữ liệu nền tảng: cảnh báo vàng đóng kèm lý do + bằng chứng đối soát; không xóa cảnh báo, chỉ kết luận.
- Cảnh báo phát sinh trong kỳ đối soát đã khóa: xử lý bình thường trên hồ sơ AML; dữ liệu đối soát gốc đọc-only.
- Rule ngưỡng đổi giữa chừng (tư vấn AML cập nhật): giao dịch đã chấm giữ nguyên kết quả theo ngưỡng lúc chấm; chỉ giao dịch mới dùng ngưỡng mới — audit log ghi thay đổi cấu hình.
- Khách EDD chuyển diện thường (review 6 tháng đạt): ngưỡng tự nới về chuẩn từ chu kỳ sau; không áp dụng hồi tố.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Cảnh báo AML (AmlAlert) — Web vận hành workflow; timer/hold thực thi ở CORE.*

**Entity:** Cảnh báo AML (AmlAlert)

**Sơ đồ trạng thái:**
```
[MỚI] ──(FIN_L2 nhận xử lý)──► [ĐANG ĐIỀU TRA] ──(24h)──► [KẾT LUẬN]
   │                                │
   │ (tự động theo rule)            ├─(vô hại)──► [ĐÃ ĐÓNG — ghi lý do]
   │                                └─(có nghi vấn / đỏ)──► [NÂNG ĐỎ / ESCALATED_BOD (24h)]
   │                                                              │
   │                                                              ├─(duyệt)──► [QUYẾT ĐỊNH BOD — LƯU VĨNH VIỄN]
   │                                                              └─(từ chối)─► [QUYẾT ĐỊNH BOD — LƯU VĨNH VIỄN]
   │
   └──(giao dịch liên quan giữ HOLD đến khi có quyết định)──► [HOLD NHẢ] khi alert đóng
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `MỚI` | Nhận xử lý | `ĐANG ĐIỀU TRA` | FIN_L2 (không phải người đề xuất/nhập giao dịch) | Ghi người xử lý + thời điểm nhận; SLA 24h |
| `ĐANG ĐIỀU TRA` | Kết luận vô hại | `ĐÃ ĐÓNG` | FIN_L2 | Lý do bằng văn bản + bằng chứng |
| `ĐANG ĐIỀU TRA` | Nâng mức | `NÂNG ĐỎ` | FIN_L2 | Căn cứ nghi vấn ghi rõ |
| `NÂNG ĐỎ`/đỏ mới | Escalate BOD | `ESCALATED_BOD` | Hệ thống (timer 24h) | Tự động; alert mobile cho BOD |
| `ESCALATED_BOD` | Quyết định duyệt/từ chối | `QUYẾT ĐỊNH BOD` | BOD_CFO_CTO (oversight) | Lý do văn bản bắt buộc; lưu vĩnh viễn |
| Bất kỳ | Giao dịch hold | HOLD duy trì | Hệ thống | Nhả hold chỉ khi alert đóng/quyết định có hiệu lực |

**Quy tắc:**
- Mỗi bước ghi trạng thái, người xử lý, timestamp — không ghi đè; quyết định lưu vĩnh viễn, không xóa được.
- SLA điều tra 24h chạy tự động; quá hạn escalate tự động lên BOD, không cần ai bấm.
- Cảnh báo đã đóng/quyết định là trạng thái kết thúc — mở lại chỉ bằng cảnh báo mới gắn cùng giao dịch (nếu phát sinh sự kiện mới).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| AmlAlert | `ruleId` (T1–T6), `severity` (VÀNG/ĐỎ), `customerId`, `adAccountId`, `transactionId`, `thresholdHit`, `state` | FK → WalletTransaction/Customer/AdAccount | EDD hiển thị nhãn ngưỡng siết 50% |
| AmlInvestigation | `alertId`, `investigatorId`, `startedAt`, `findings`, `documentIds[]` | FK → AmlAlert | Chặn investigator trùng người đề xuất |
| AmlDecision | `alertId`, `decision` (DUYỆT/TỪ CHỐI/ĐÓNG), `reasonText`, `decidedBy`, `decidedAt` | FK → AmlAlert | Lưu vĩnh viễn, không xóa |
| RuleConfig | `ruleId`, `thresholdParams`, `effectiveFrom`, `changedBy` | Cấu hình global | Version hoá; đổi ngưỡng không hồi tố |
| BeneficiaryAccount | `customerId`, `accountNo`, `accountName`, `kycMatch` | FK → Customer (hồ sơ KYC REQ-FIN-009) | Chỉ TK trùng tên pháp nhân được chọn khi hoàn |
| RebateStatement | `contractId`, `period`, `rebateAmount` (nhập tay), `note`, `approvedBy` | FK → Contract | Mặc định OFF; kỳ quý, review thủ công |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: T1 chạm ngưỡng | Khách bình quân nạp 30 ngày = 5.000 USD | Đơn nạp 15.000 USD | Cảnh báo vàng T1 sinh đúng ngưỡng, gắn khách/giao dịch | [ ] |
| SC-002: T2 đỏ escalate | 3 lệnh nạp trong 24h, tổng ≥200 triệu VND | Rule chấm | Đỏ T2; hold giao dịch; escalate BOD trong 24h | [ ] |
| SC-003: T4 chặn mặc định | Lệnh hoàn đổi beneficiary sang TK khác tên | Submit hoàn | Chặn + cảnh báo T4 đỏ; chỉ BOD xem xét lại bằng văn bản | [ ] |
| SC-004: EDD siết 50% | Khách diện EDD, ngưỡng T1 chuẩn 3× | Đơn nạp 1,6× bình quân | Chạm cảnh báo theo ngưỡng đã siết (1,5×) | [ ] |
| SC-005: SoD điều tra | FIN_L1 là người nhập giao dịch bị cảnh báo | FIN_L1 mở màn điều tra | Nút điều tra disabled; chỉ FIN_L2 nhận xử lý | [ ] |
| SC-006: Hold nhả đúng lúc | Giao dịch hold do cảnh báo đỏ | BOD ra quyết định "không nghi vấn" | Hold nhả tự động; quyết định + lý do lưu vĩnh viễn | [ ] |
| SC-007: Không miễn monitoring | Khách VIP khu vực rủi ro cao | Cố cấu hình tắt monitoring | Từ chối + log; rule vẫn chấm bình thường | [ ] |

> **Liên kết:** SC-001→REQ-FIN-010 (BR-A03); SC-002→REQ-FIN-010 (BR-A03/A07); SC-003→REQ-FIN-010 (BR-A08); SC-004→REQ-FIN-010 (BR-A04); SC-005→REQ-FIN-010 (BR-A06); SC-006→REQ-FIN-010 (BR-A07); SC-007→REQ-FIN-010 (BR-A05) trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (aml_alert, investigation, rule_config) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (aml-alerts, investigations, refund-source) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-010: CORE, MOBILE-INTERNAL; FATF sync qua GW) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (danh sách cảnh báo, workflow điều tra, cấu hình ngưỡng) |
| Policies liên quan | `aml-kyc-giam-sat-giao-dich.md`; hồ sơ KYC/UBO tại REQ-FIN-009 (module KYC) |
