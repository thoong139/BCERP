# Tính Năng: AML monitoring T1–T6 + hoàn tiền đúng nguồn

> **Dựa trên:** REQ-FIN-010 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md` (B.4 — compliance-expert), `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.10 Rebate), policies `aml-kyc-giam-sat-giao-dich.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-006-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-010 (REQ xuất hiện ở 3 systems). Counterparts: SYS-BCERP-WEB (danh sách cảnh báo, workflow điều tra), SYS-MOBILE-INTERNAL (push alert vàng/đỏ cho FIN/BOD). Touchpoint Core Backend là **headless API/domain service**: rule engine chấm điểm tự động mọi lệnh nạp/hoàn/điều chỉnh ở tầng service trước khi giao dịch thực thi; khóa mềm (hold) và escalation do engine điều phối — UI chỉ hiển thị và ghi kết luận.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-006 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-010 |
| Người dùng liên quan | FIN_L1 (tuyến 1 — hỗ trợ điều tra), FIN_L2 (điều tra, quyết định vàng), BOD_CFO_CTO (oversight độc lập, quyết định đỏ) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (dữ liệu ledger), FEAT-CORE-WALLET-003 (dual approval — hoàn tiền, SoD người đề xuất ≠ người điều tra); danh sách FATF do GW đồng bộ định kỳ |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); compliance-expert (call-2) đã phân tích B.4 theo Three Lines of Defense — FIN_L1/L2 tuyến 1, Compliance chức năng tuyến 2 gán FIN_L2 xử lý + BOD oversight độc lập (KHÔNG lập vai FIN_COMPL riêng theo quyết định stakeholder DI-006); Knockout K1–K5 chỉ lọc rủi ro tầng lead — không thay thế KYC và không miễn giám sát giao dịch |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Giám sát tầng giao dịch suốt vòng đời khách trên 2.600+ TKQC đa kênh quốc tế để **chống rửa tiền qua ví TKQC** — kịch bản rủi ro gốc của mô hình trung gian: tiền nguồn không rõ nạp vào TKQC, tiêu hao dưới dạng chi phí quảng cáo hoặc hoàn về tài khoản khác dưới vỏ bọc dịch vụ hợp pháp. Core Backend vận hành rule engine 6 quy tắc (T1–T6) chấm điểm tự động mọi lệnh nạp/hoàn/điều chỉnh với ngưỡng cấu hình được không sửa code, khóa mềm giao dịch nghi vấn đến khi có quyết định, và ép nguyên tắc hoàn tiền đúng nguồn (dẫn chiếu giao dịch nạp gốc, trùng tên pháp nhân KYC, cấm hoàn bên thứ ba).

**Phạm vi:**
- Bao gồm: rule engine T1–T6 chạy tự động trên dữ liệu ledger (FEAT-CORE-WALLET-001) + dữ liệu đối soát (FEAT-CORE-WALLET-004); cấu hình ngưỡng per-rule không sửa code; siết ngưỡng 50% tự động cho khách diện EDD; khóa mềm (hold) giao dịch nghi vấn — cấm xử lý song song; workflow điều tra 24h với SoD (người đề xuất/nhập giao dịch không tự điều tra); escalate đỏ → BOD trong 24h; quyết định ghi lý do bằng văn bản lưu vĩnh viễn; chặn mặc định lệnh hoàn đổi beneficiary (T4); báo cáo AML tháng; lưu hồ sơ KYC/AML ≥5 năm.
- Không bao gồm: hồ sơ KYC đầu vào và gate Verified trước cấp phát (REQ-FIN-009 — module Quản lý TKQC phối hợp; Core chỉ đọc trạng thái KYC/UBO); màn danh sách cảnh báo và form điều tra (SYS-BCERP-WEB); push alert (SYS-MOBILE-INTERNAL); dual approval của lệnh hoàn (FEAT-CORE-WALLET-003 — engine AML đứng trước và có thể hold lệnh đã duyệt).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (Core service) | Tự chấm điểm mọi lệnh nạp/hoàn/điều chỉnh theo 6 quy tắc trước khi thực thi, và khóa mềm giao dịch nghi vấn ngay lập tức | Không có giao dịch rủi ro nào lọt qua chỉ vì người làm quên kiểm tra |
| 2 | FIN_L2 | Nhận danh sách cảnh báo vàng/đỏ kèm khách/TKQC/giao dịch/ngưỡng vi phạm, điều tra trong SLA 24h | Xử lý có hệ thống, có hồ sơ, đúng SLA — không xử lý cảm tính |
| 3 | FIN_L2 | Người đề xuất/nhập giao dịch không thể tự điều tra giao dịch của mình | Tách bạch công vụ theo SoD — người trong cuộc không tự thẩm mình |
| 4 | BOD_CFO_CTO | Nhận escalate cảnh báo đỏ trong 24h và ra quyết định bằng văn bản | Lớp oversight độc lập cuối cùng; quyết định nhạy cảm có chữ ký, có lý do, lưu vĩnh viễn |
| 5 | FIN_L1 | Khi tạo lệnh hoàn, hệ thống tự dẫn chiếu giao dịch nạp gốc và tự khớp tên chủ TK nhận với tên pháp nhân KYC | Không hoàn nhầm/hoàn chéo; lệch tên bị phát hiện ngay tại lúc tạo lệnh |
| 6 | CUSTOMER (Portal) | Thấy trạng thái đối soát ở mức dành cho khách (số tranh chấp hiển thị "Đang đối soát") | Minh bạch ở mức hợp lý mà quy trình AML nội bộ không bị lộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; ngưỡng cấu hình được qua cấu hình hệ thống, không sửa code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-M01 | Nền tảng dữ liệu: engine chạy trên ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) — so sánh quy VND dùng snapshot tỷ giá đã khóa tại thời điểm giao dịch; mọi giao dịch sinh từ lệnh hệ thống với snapshot fee % (FEAT-CORE-WALLET-001) | So sánh chéo currency bằng số dư gộp quy đổi hiện hành → chặn; ngưỡng T2 quy VND theo snapshot từng lệnh |
| BR-M02 | Rule engine 6 quy tắc — ngưỡng khởi điểm đã chốt làm mức mặc định theo DI-001 (chờ tư vấn AML/luật sư rà chính thức), cấu hình được không sửa code: **T1** nạp gấp nhiều lần bình thường — đơn nạp ≥3× bình quân 30 ngày gần nhất (Vàng); **T2** tách nhỏ (structuring) — ≥3 lệnh nạp/24h, tổng ≥200 triệu VND hoặc tương đương (Đỏ); **T3** nguồn từ quốc gia rủi ro cao — FATF list hoặc do BOD cập nhật (Đỏ); **T4** hoàn tiền đổi beneficiary — bất kỳ trường hợp nào (Đỏ — chặn mặc định); **T5** vòng tiền nhanh — nạp rồi yêu cầu hoàn trong 72h không có chi tiêu tương ứng (Vàng); **T6** hoàn vượt tỷ lệ — hoàn ≥50% giá trị nạp trong kỳ đối soát (Vàng) (BR-FIN-403) | Mỗi cảnh báo gắn bắt buộc khách/TKQC/giao dịch + ngưỡng vi phạm; giao dịch không qua engine không được thực thi |
| BR-M03 | Khách diện EDD (khách nước ngoài, khu vực FATF rủi ro cao, lead flag Knockout K2/K4) → ngưỡng T1–T6 **tự siết 50%** theo cấu hình; review hồ sơ 6 tháng thay vì 12 tháng (BR-FIN-401) | Siết ngưỡng áp tự động từ trạng thái KYC/EDD; không ai tắt siết thủ công cho từng giao dịch |
| BR-M04 | **Cấm tắt monitoring cho bất kỳ khách nào** — kể cả VIP/khách lâu năm tại khu vực rủi ro cao (BOD duyệt hợp đồng nhưng không miễn monitoring) | Cấu hình tắt rule cho cá nhân khách bị schema chặn; nỗ lực cấu hình bị log |
| BR-M05 | Khóa mềm (hold): giao dịch vi phạm ngưỡng Đỏ (và Vàng khi nâng cấp) bị **hold đến khi có quyết định** — cấm xử lý song song; hold áp cả lệnh đã qua dual approval (hold ưu tiên hơn duyệt) | Lệnh đang hold không thực thi được qua bất kỳ kênh nào; release chỉ bởi kết luận điều tra ghi văn bản |
| BR-M06 | Quy trình xử lý: điều tra **24 giờ** — xác minh hợp đồng, lịch sử nạp–chi tiêu, giấy tờ nguồn tiền; cảnh báo vàng: vô hại → đóng + ghi lý do, có nghi vấn → nâng đỏ; **đỏ → escalate BOD trong 24 giờ tiếp theo**; quyết định duyệt/từ chối **ghi lý do bằng văn bản, lưu vĩnh viễn** (BR-FIN-404) | Quá SLA điều tra/escalate → tự escalate cấp trên + log sự cố; đóng cảnh báo không lý do bị schema chặn |
| BR-M07 | SoD điều tra: **người đề xuất/nhập giao dịch không được tự điều tra** (khớp SoD 4 vai BR-FIN-106); BOD là lớp oversight độc lập (compensating control — không lập vai Compliance riêng theo DI-006) | Engine gán điều tra viên tự động loại người đề xuất/nhập; gán trùng bị chặn `INVESTIGATOR_SOD_VIOLATION` |
| BR-M08 | **Hoàn tiền đúng nguồn:** bắt buộc dẫn chiếu giao dịch nạp gốc, chỉ trả về đúng TK ngân hàng/ví nguồn nạp **trùng tên pháp nhân KYC**; cấm hoàn cho bên thứ ba hoặc tài khoản khác tên; Core tự khớp tên chủ TK nhận với tên pháp nhân đã KYC — lệch → chuyển rà thủ công (BR-FIN-402) | Lệnh hoàn thiếu dẫn chiếu nạp gốc bị chặn submit; TK nhận lệch tên → T4 (đỏ, chặn mặc định); chỉ BOD xem xét lại bằng văn bản (3 ngày làm việc), kết quả lưu vĩnh viễn |
| BR-M09 | Nghi vấn rửa tiền được xác thực → thực hiện nghĩa vụ báo cáo cơ quan chức năng theo quy định pháp luật, phối hợp luật sư/tư vấn AML; hồ sơ điều tra truy xuất theo khách/TKQC/giao dịch/cảnh báo | — (quy trình pháp lý; hệ thống bảo đảm dữ liệu truy xuất đầy đủ) |
| BR-M10 | Báo cáo AML tháng: số lượng cảnh báo vàng/đỏ, SLA xử lý, tỷ lệ đóng/escalation (báo cáo #5 mục A5); retention hồ sơ KYC + giao dịch + cảnh báo + biên bản + quyết định **≥5 năm** kể từ kết thúc quan hệ khách hàng (khởi điểm theo thông lệ AML — `[CẦN CHỐT SỐ — luật sư xác nhận]`) (BR-FIN-405) | Hồ sơ thuộc thanh tra/điều tra đang mở giữ đến khi hồ sơ đóng, bất kể hết hạn retention |
| BR-M11 | Dual approval (SINGLE/DUAL — FIN_L1 → FIN_L2 tuần tự theo công tắc hệ thống) vẫn áp dụng cho lệnh hoàn/điều chỉnh (FEAT-CORE-WALLET-003); AML đứng **trước** approval: hold xảy ra ngay khi cảnh báo, không chờ duyệt xong | Lệnh vi phạm T4 không thể "duyệt nhanh" bỏ qua — chặn mặc định dù đủ 2 chữ ký |
| BR-M12 | Đối trừ 3 số & chốt kỳ: giao dịch đang hold không tham gia chốt số liệu kỳ; hoàn đúng nguồn là cơ sở khớp vế 1↔vế 2 khi platform hoàn (dung sai nạp = 0/dòng; chi tiêu ≤0,5%·10USD; tích lũy ≤1%·20USD — mặc định theo DI-001) (FEAT-CORE-WALLET-004) | Kỳ chứa giao dịch hold → xử lý hold trước; chốt kỳ bị chặn khi còn ticket liên quan hold |
| BR-M13 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation; khách không thấy cảnh báo AML, điều tra, quyết định; số tranh chấp liên quan hiển thị "Đang đối soát" | Truy vấn Portal ép điều kiện tenant; dữ liệu AML không nằm trong view khách dưới mọi hình thức |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_AM/OPS_ADS | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|----------------|-----------|-------------------|
| Xem danh sách cảnh báo theo mức | ✅ (được gán hỗ trợ) | ✅ (toàn bộ) | ✅ (tổng hợp) | ❌ | ❌ | ❌ |
| Điều tra cảnh báo (ghi trạng thái, người xử lý) | ✅ (không phải người đề xuất/nhập) | ✅ | ❌ (oversight) | ❌ | ❌ | ❌ |
| Đóng cảnh báo vàng (vô hại, ghi lý do) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Nâng vàng → đỏ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Quyết định cảnh báo đỏ | ❌ | ❌ | ✅ (bằng văn bản, lưu vĩnh viễn) | ❌ | ❌ | ❌ |
| Xem xét lại lệnh hoàn đổi beneficiary (T4) | ❌ | ❌ | ✅ (bằng văn bản 3 ngày làm việc) | ❌ | ❌ | ❌ |
| Tạo lệnh hoàn (dẫn chiếu nạp gốc) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình ngưỡng T1–T6 / danh sách FATF | ❌ | ❌ | ✅ (phê duyệt thay đổi) | ❌ | ✅ (thao tác cấu hình + audit) | ❌ |
| Tắt monitoring cho một khách | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại cấu hình này) | ❌ |
| Xem trạng thái "Đang đối soát" của tenant mình | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (read-only, mức tổng hợp) |

---

## 5. Trường Hợp Đặc Biệt

- **Khách nhiều lệnh nạp cùng ngày (tách nhỏ thật sự vs. nghiệp vụ chính đáng):** T2 phát hiện theo pattern — điều tra xác minh hợp đồng/nguồn tiền; nếu vô hại → đóng + lý do; nếu đúng structuring → nâng đỏ + BOD quyết; không có chế độ "danh sách trắng bỏ qua T2".
- **Nạp từ quốc gia FATF rủi ro cao nhưng khách đã EDD:** T3 vẫn bắn (đỏ); EDD giúp điều tra nhanh hơn chứ không miễn cảnh báo; danh sách quốc gia do BOD cập nhật, GW đồng bộ FATF định kỳ.
- **Refund từ nền tảng (TKQC die còn dư) khác nguồn nạp gốc:** FIN_L1 khớp tiền hoàn về theo giao dịch gốc (BR-FIN-102) và ghi có; hoàn cho khách vẫn qua luồng hoàn đúng nguồn + dual approval; không map được giao dịch gốc → ticket discrepancy (FEAT-004).
- **Vòng tiền nhanh có chi tiêu một phần:** T5 so chi tiêu tương ứng trong 72h — chi tiêu một phần không loại trừ cảnh báo nếu phần hoàn vượt ngưỡng T6; điều tra đánh giá trên toàn bộ chuỗi.
- **Giao dịch hold trùng kỳ chốt:** kỳ bị chặn chốt cho đến khi hold kết thúc; nếu bắt buộc chốt (mốc ngày 3), giao dịch hold được tách ghi chú "chưa kết luận" và kỳ mở lại theo phiếu khi có quyết định — không chốt số "tạm ổn".
- **Nghỉ/transfer điều tra viên giữa chừng:** workflow cho phép FIN_L2 gán lại (không phải người đề xuất/nhập); lịch sử điều tra ghi continuity — không reset SLA.
- **Khách kết thúc quan hệ:** retention hồ sơ AML ≥5 năm kể từ ngày kết thúc; dữ liệu không bị xóa theo yêu cầu xóa dữ liệu thông thường (nghĩa vụ lưu trữ pháp luật ưu tiên).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** AMLAlert (cảnh báo) và trạng thái giao dịch liên quan (HoldStatus)

**Sơ đồ trạng thái:**
```
[Giao dịch] ACTIVE ──(vi phạm ngưỡng)──► [ALERT MỞ — VÀNG | ĐỎ] + giao dịch: ACTIVE ──► [HELD]
                                              │                                        │
                          (vàng: vô hại)       │        (vàng: có nghi vấn → nâng đỏ)   │
                                              ▼                                        ▼
                                        [ĐÓNG — VÔ HẠI]                    [ESCALATED — BOD ≤24h]
                                              ▲                                        │
                                              │ (kết luận vô hại)                      │ (quyết định văn bản)
                                              │                                        ▼
                                              └────────────────────────── [QUYẾT ĐỊNH: DUYỆT | TỪ CHỐI]
                                                                              giao dịch: RELEASED | BLOCKED
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` (giao dịch) | Engine bắn cảnh báo ngưỡng | `ALERT MỞ (VÀNG/ĐỎ)` + giao dịch `HELD` | Hệ thống | Gắn khách/TKQC/giao dịch + ngưỡng vi phạm; đỏ hold ngay |
| `ALERT MỞ — VÀNG` | Điều tra vô hại | `ĐÓNG — VÔ HẠI` + giao dịch `RELEASED` | FIN_L2 (≠ người đề xuất/nhập) | Lý do văn bản; SLA 24h |
| `ALERT MỞ — VÀNG` | Có nghi vấn | `ESCALATED — BOD` (đỏ) | FIN_L2 | Lý do nâng cấp; giao dịch giữ `HELD` |
| `ALERT MỞ — ĐỎ` | Escalate | `ESCALATED — BOD` | Hệ thống (tự động ≤24h) | Notify BOD_CFO_CTO; push MOBILE |
| `ESCALATED — BOD` | Quyết định duyệt | `QUYẾT ĐỊNH: DUYỆT` + giao dịch `RELEASED` | BOD_CFO_CTO | Quyết định bằng văn bản, lưu vĩnh viễn |
| `ESCALATED — BOD` | Quyết định từ chối | `QUYẾT ĐỊNH: TỪ CHỐI` + giao dịch `BLOCKED` | BOD_CFO_CTO | Quyết định bằng văn bản, lưu vĩnh viễn; báo cáo cơ quan chức năng khi xác thực |

**Quy tắc:**
- `HELD` là trạng thái chặn tuyệt đối: không thực thi, không hoàn, không điều chỉnh trong khi hold — kể cả khi đủ dual approval.
- `ĐÓNG`/`QUYẾT ĐỊNH` là trạng thái kết thúc của cảnh báo; hồ sơ (kể cả giao dịch bị BLOCKED) lưu vĩnh viễn trong phạm vi retention ≥5 năm.
- Điều tra viên không thể là người đề xuất/nhập giao dịch của chính cảnh báo — engine ép khi gán.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `AmlRuleConfig` | `rule_code` (T1–T6), `threshold`, `level` (VÀNG/ĐỎ), `enabled`, `edd_factor` (0.5) | — | Cấu hình không sửa code; đổi ngưỡng cần BOD phê duyệt + audit |
| `AmlAlert` | `rule_code`, `customer_id`, `ad_account_id`, `transaction_id`, `level`, `status`, `breach_detail` | FK → `wallet_transactions.id` | Gắn đầy đủ ngữ cảnh; lưu vĩnh viễn |
| `InvestigationCase` | `alert_id`, `investigator_id`, `assigned_at`, `sla_due` (24h), `findings`, `conclusion` | FK → `aml_alerts.id` | Engine loại người đề xuất/nhập khỏi investigator |
| `HoldRecord` | `transaction_id`, `reason` (AML_ALERT), `held_at`, `released_at`, `release_basis` | FK → `wallet_transactions.id` | Hold chặn mọi thực thi; release chỉ theo kết luận |
| `RefundSourceLink` | `refund_request_id`, `source_transaction_id`, `beneficiary_name_match` (bool) | FK → `risky_transaction_requests.id`, `wallet_transactions.id` | Bắt buộc cho mọi lệnh hoàn (BR-M08) |
| `AmlMonthlyReport` | `period`, `yellow_count`, `red_count`, `sla_compliance`, `escalation_rate` | — | Báo cáo #5 mục A5; FIN_L2 tổng hợp |
| `AmlArchive` | `alert_id`, `case_id`, `decision_doc`, `retention_until` (≥5 năm) | FK → `aml_alerts.id` | Giữ đến khi hồ sơ điều tra đóng nếu đang mở |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: T1 vàng | Khách nạp bình quân 30 ngày = 5.000 USD | Đơn nạp 16.000 USD (≥3×) | Cảnh báo VÀNG; điều tra SLA 24h; giao dịch hold nếu nâng cấp | [ ] |
| SC-002: T2 đỏ | 3 lệnh nạp trong 24h, tổng quy VND ≥200 triệu | Engine chấm | Cảnh báo ĐỎ; giao dịch `HELD` ngay; escalate BOD ≤24h | [ ] |
| SC-003: T4 chặn mặc định | Lệnh hoàn có TK nhận khác tên pháp nhân KYC | Submit lệnh hoàn | Chặn mặc định + T4 đỏ; chỉ BOD xem xét lại bằng văn bản 3 ngày | [ ] |
| SC-004: EDD siết ngưỡng | Khách EDD, ngưỡng T1 mặc định 3× | Cấu hình áp dụng | Ngưỡng hiệu lực 1,5×; tự động theo trạng thái KYC | [ ] |
| SC-005: SoD điều tra | OPS_ADS là người nhập lệnh bị cảnh báo | Engine gán điều tra viên | OPS không xuất hiện trong danh sách gán; `INVESTIGATOR_SOD_VIOLATION` nếu thử | [ ] |
| SC-006: Hold ưu tiên hơn duyệt | Lệnh hoàn đã đủ 2 chữ ký dual approval | Cảnh báo T5 bắn trước khi thực thi | Giao dịch `HELD`; không thực thi dù đã duyệt; release theo kết luận | [ ] |
| SC-007: Quyết định văn bản | BOD quyết cảnh báo đỏ | Đóng quyết định | Lý do văn bản bắt buộc; lưu vĩnh viễn; giao dịch RELEASED/BLOCKED tương ứng | [ ] |
| SC-008: Không tắt monitoring | Khách VIP lâu năm | SYS_ADMIN thử tắt rule cho khách | Không tồn tại cấu hình; nỗ lực bị log; monitoring vẫn chạy | [ ] |

> **Liên kết:** SC-001→008 map REQ-FIN-010 Mục 2 (A3, BR-FIN-402…405); SC-003/006 liên kết REQ-FIN-003 (dual approval, BR-FIN-105); SC-004 liên kết REQ-FIN-009 (EDD).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — AmlRuleConfig, AmlAlert, InvestigationCase, HoldRecord | `technical-specs/database-design.md` |
| API Endpoints — rule engine hooks, hold/release, escalation, báo cáo tháng | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — FATF sync (GW), KYC status (REQ-FIN-009), dual approval (FEAT-003) | `technical-specs/integration-map.md` |
| Màn hình UI (danh sách cảnh báo + workflow điều tra thuộc SYS-BCERP-WEB) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Policy — AML/KYC giám sát giao dịch | `.mc-data/docs/phase0-brainstorm/policies/aml-kyc-giam-sat-giao-dich.md` |
