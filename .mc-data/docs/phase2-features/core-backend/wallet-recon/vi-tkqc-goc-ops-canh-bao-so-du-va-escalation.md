# Tính Năng: Ví TKQC góc ops — cảnh báo số dư & escalation

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1), policy `kiem-soat-vi-tkqc-giao-dich-tien.md` §2.1–2.3
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-007-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-OPS-003 (REQ xuất hiện ở 6 systems). Counterparts: SYS-INTEGRATION-GW (số dư/spend tươi ≤1h, degraded `manual`), SYS-BCERP-WEB (thao tác lệnh chính của OPS_ADS), SYS-MOBILE-INTERNAL (push alert đỏ + xử lý/duyệt ngoài giờ), SYS-PORTAL-WEB & SYS-MOBILE-PORTAL (khách xem lịch sử điều chỉnh ví — touchpoint rút gọn). Touchpoint Core Backend là **headless API/domain service**: engine cảnh báo, bộ đếm SLA đỏ, sổ lệnh và SoD engine chạy ở tầng service; góc FIN của ngưỡng cảnh báo là FEAT-CORE-WALLET-002 (cross-dependency: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN, OPS vận hành nạp).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-007 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-OPS-003 (cross-dependency: REQ-FIN-002, REQ-FIN-001) |
| Người dùng liên quan | OPS_ADS (owner ví), OPS_AM, OPS_PLAN (điều phối), OPS_CONT/OPS_DES/OPS_EDIT (xem trạng thái TK phụ trách), CUSTOMER (Portal/Mobile Portal — xem lịch sử điều chỉnh ví); phối hợp FIN_L1/FIN_L2 (duyệt, khớp tiền) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-002 (engine cảnh báo 3 mức + SLA — ngưỡng nguồn FIN), FEAT-CORE-WALLET-001 (sổ lệnh ví + vòng lệnh nạp), FEAT-CORE-WALLET-003 (dual approval 3 nhóm rủi ro cao) |
| Ghi chú Expert (A7) | Expert review Phần A operations.md chưa thực hiện chính thức (chờ review); điểm phối hợp liên phòng đã xác định: TL OPS quan tâm cảnh báo sớm không nghẽn phê duyệt (REQ-OPS-003); stakeholders ngoài phòng: FIN_L1 khớp tiền trước cấp TK (REQ-OPS-002/003), CLIENT_ADMIN/CLIENT_USER minh bạch dữ liệu không lộ giá vốn (REQ-OPS-010) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp cho team Ops (nhất là OPS_ADS làm owner ví) bản điều hành của ví TKQC trên nền engine cảnh báo của Core: mỗi TK/platform được tính average daily spend 7 ngày rolling và phân 3 mức Xanh/Vàng/Đỏ; alert Đỏ vào SLA 2h làm việc với escalation tự động owner → TL (quá 2h) → AM (quá 4h, chủ động liên hệ khách yêu cầu nạp), mỗi chặng ghi timestamp. Kết hợp quy tắc lệnh ví: mọi top-up/refund/điều chỉnh chỉ qua lệnh hệ thống, cấm lệnh miệng, cấm mượn chéo ví giữa khách — bảo đảm OPS hành động nhanh khi ví sắp cạn mà không phá vỡ kỷ luật dòng tiền.

**Phạm vi:**
- Bao gồm: API trạng thái ví theo platform/khách với "số ngày chi dự kiến" cho dashboard (WEB hiển thị, Core cấp dữ liệu); đề xuất top-up một chạm từ alert (sinh lệnh đề xuất nạp prefilled); sổ lệnh ví trung tâm ghi mọi top-up/refund/điều chỉnh; SoD engine chặn 1 người giữ ≥2 vai trong 1 giao dịch; bộ đếm SLA đỏ 2h + auto-escalation có timestamp; xử lý ngoài giờ qua on-call nhưng lệnh vẫn phải tạo trên hệ thống; hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình; API lịch sử điều chỉnh ví cho Portal/Mobile Portal (mask giá vốn thành "điều chỉnh đối soát", read-only tuyệt đối, tenant isolation).
- Không bao gồm: logic tính ngưỡng/ADS (FEAT-CORE-WALLET-002 — bản FIN của cảnh báo); màn dashboard và form tạo lệnh trên WEB (SYS-BCERP-WEB); pull số dư/spend từ nền tảng (SYS-INTEGRATION-GW — REQ-FIN-005); khớp tiền và dual approval duyệt (FIN — FEAT-CORE-WALLET-001/003); hard stop cấp phát (REQ-OPS-002).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS (owner ví) | Nhận alert Đỏ kèm "số ngày chi dự kiến" và bấm đề xuất top-up một chạm từ chính alert (lệnh prefilled) | Hành động trong SLA 2h mà không phải mở lại form, tìm thông tin khách/TK từ đầu |
| 2 | OPS_ADS | Chỉ được nạp thêm qua lệnh hệ thống — không tự ý dùng tiền khách khác đắp ví | Tránh vi phạm nguyên tắc tiền giữ hộ; ví mỗi khách tách bạch tuyệt đối |
| 3 | OPS_AM | Nhận escalate quá 4h với thông tin đủ (mức, số ngày còn, hành động đã/không có) và chủ động liên hệ khách yêu cầu nạp trong ngày làm việc | Cứu campaign trước khi die; khách được thông báo trong cùng ngày |
| 4 | TL OPS (OPS_PLAN/OPS_AM điều phối) | Xem hàng đợi alert của cả team, cấu hình hạn mức đổi ngân sách ngày theo cấp buyer | Phân bổ việc công bằng, kiểm soát rủi ro theo năng lực từng buyer |
| 5 | OPS_CONT/OPS_DES/OPS_EDIT | Xem trạng thái ví của TK trong dự án mình phụ trách (mức Xanh/Vàng/Đỏ) | Chủ động cảnh báo AM khi content/design có thể ảnh hưởng chi tiêu (đẩy vòng sửa, dừng campaign) |
| 6 | CUSTOMER (Portal/Mobile Portal) | Xem lịch sử điều chỉnh ví của mình, trường giá vốn hiển thị mask "điều chỉnh đối soát" | Minh bạch với khách mà không lộ giá vốn/chiết khấu nội bộ |
| 7 | Hệ thống (Core service) | Tự đếm SLA từng alert, auto-escalate có timestamp, và từ chối mọi lệnh vi phạm SoD/lệnh miệng | Kỷ luật vận hành không phụ thuộc trí nhớ hay thiện chí cá nhân |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; SLA clock và SoD chạy phía server.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-O01 | Nền tảng ví: tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) — mọi lệnh ví thao tác trên đúng ví/currency của khách; snapshot fee %/tỷ giá tại thời điểm giao dịch; công thức k = 1 + feePercent×(1+vatOnFeePercent) + vatOnSpendPercent hai chiều NET/GROSS cho lệnh nạp vào TK (FEAT-CORE-WALLET-001) | Lệnh truy ví sai khách/sai currency bị từ chối `WALLET_OWNERSHIP_MISMATCH`; tính toán k chạy service, test 2 chiều |
| BR-O02 | Cảnh báo 3 mức per TK/platform theo engine FIN (REQ-FIN-002 — ngưỡng nguồn FIN): Xanh (đủ chi ≥3 ngày — không hành động), Vàng (<3 ngày — owner lập kế hoạch nạp, thông báo AM), Đỏ (<1 ngày hoặc dưới mức tối thiểu platform — vào SLA đỏ); dữ liệu số dư/spend tươi ≤1h từ GW, nhãn `manual` khi degraded (BR-OPS-2.3) | Đổi ngưỡng phải đi từ cấu hình FIN (FEAT-002) — OPS không tự sửa ngưỡng; dữ liệu không nhãn nguồn không tham gia tính |
| BR-O03 | SLA Đỏ 2h làm việc: 0–2h owner (OPS_ADS) phải thực hiện 1 trong 2 hành động trên hệ thống — tạo lệnh đề xuất top-up hoặc giảm ngân sách kéo dài số ngày chi được; quá 2h → escalate TL; quá 4h → escalate AM, AM liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày; mỗi chặng ghi timestamp (BR-OPS-2.4) | Bộ đếm auto-escalate phía server; hành động ngoài hệ thống (tin nhắn, lời nói) không dừng đồng hồ |
| BR-O04 | Mọi top-up/refund/điều chỉnh **chỉ qua lệnh hệ thống** chứa đủ khách/TKQC/số tiền/tiền tệ/snapshot tỷ giá/căn cứ; cấm xác nhận miệng Zalo/điện thoại/email riêng — FIN từ chối đối chiếu lệnh miệng (BR-OPS-2.5; BR-FIN-102) | Ghi nhận không qua lệnh bị chặn ở service layer (`NO_ORDER_DENIED`); lệnh miệng không có giá trị đối chiếu |
| BR-O05 | **Cấm mượn chéo ví**: OPS_ADS nhận alert Đỏ chỉ được nạp thêm qua lệnh trên đúng ví khách đó — không tự ý dùng tiền khách khác đắp ví (BR-OPS-2.5) | Lệnh trích tiền ví khách khác để đắp bị chặn `CROSS_WALLET_TOPUP_DENIED`; nỗ lực log cho TL/BOD rà |
| BR-O06 | Dual approval (đề xuất ≠ duyệt) cho 3 nhóm rủi ro cao: điều chỉnh số dư tay, đổi tỷ giá tay, hoàn tiền — mode SINGLE/DUAL là 1 công tắc hệ thống; DUAL duyệt tuần tự FIN_L1 → FIN_L2, không đảo thứ tự, không cùng 1 người 2 bước (FEAT-CORE-WALLET-003; CMS §3.6) | SoD engine chặn thiếu chữ ký/sai thứ tự bất kể alert khẩn; không có đường bypass cho OPS |
| BR-O07 | SoD 4 vai dòng tiền: đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ; một người không giữ ≥2 vai trong 1 giao dịch; OPS_ADS đề xuất nạp, FIN_L1 khớp — không OPS nào tự khớp tiền (BR-FIN-106; BR-OPS-2.5) | Gán duyệt/khớp cho vai trùng bị chặn khi submit; log vi phạm append-only |
| BR-O08 | Refund từ platform (TK die còn dư): FIN_L1 khớp tiền hoàn về và ghi có theo giao dịch gốc; hoàn cho khách chỉ sau AM đề xuất + TL duyệt; OPS không tự quyết hoàn (BR-OPS-2.5) | Lệnh hoàn không có đề xuất AM + duyệt TL bị từ chối; hoàn đúng nguồn áp theo FEAT-CORE-WALLET-006 |
| BR-O09 | Hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình — ngưỡng VND/ngày theo cấp Junior/Mid/Senior `[CẦN CHỐT SỐ: khung % ngân sách tháng 20/50/100% theo cấp đã chốt theo DI-005, số VND/ngày cụ thể FIN chốt khi cấu hình]` (BR-OPS-2.5) | Đổi ngân sách vượt hạn mức cấp buyer → yêu cầu duyệt bậc trên; cấu hình hạn mức đổi chỉ TL được phép |
| BR-O10 | Khẩn ngoài giờ: xử lý qua kênh on-call TL (SLA on-call 4h ngoài giờ) nhưng **lệnh vẫn phải tạo trên hệ thống, approval không được bỏ qua** (BR-OPS-2.4/2.5; REQ-OPS-003) | Lệnh khẩn thiếu approval sau on-call → escalate BOD; hệ thống không có chế độ "hậu kiểm duyệt sau" cho lệnh ví |
| BR-O11 | Đối trừ 3 số & chốt kỳ: mọi lệnh OPS tạo là đầu vào đối trừ (dung sai 0 / 0,5%·10USD / 1%·20USD — mặc định theo DI-001); ví Đỏ kéo dài → FIN_L2 tạm giữ giải ngân tương ứng (nguyên tắc tiền giữ hộ — FEAT-CORE-WALLET-002 BR-A08) | Lệnh tạo sau giờ chốt kỳ thuộc kỳ mới; số đối soát không được "tự cân" bởi OPS |
| BR-O12 | AML T1–T6 + UBO ≥25% (mặc định theo DI-001) chấm điểm mọi lệnh nạp/hoàn OPS đề xuất; lệnh vi phạm → hold theo FEAT-CORE-WALLET-006; Rebate mặc định TẮT — Finance bật tay + nhập tay theo quý, OPS không đề xuất/kê khai rebate trong lệnh ví (CMS §3.10) | Lệnh hold không thực thi qua kênh OPS; nhãn rebate trong lệnh bị schema chặn |
| BR-O13 | Portal/Mobile Portal chỉ đọc lịch sử điều chỉnh ví của tenant mình (REQ-FIN-017 — tenant isolation): trường gắn giá vốn mask thành "điều chỉnh đối soát"; read-only tuyệt đối — khách không tạo được lệnh, không thấy alert/SLA nội bộ | Truy vấn Portal ép điều kiện tenant; mọi endpoint ghi từ Portal bị từ chối; mask áp ở tầng service, không chỉ UI |

---

## 4. Phân Quyền

| Hành động | OPS_ADS (owner) | OPS_AM | OPS_PLAN (TL) | OPS_CONT/DES/EDIT | FIN_L1/FIN_L2 | CUSTOMER (Portal/M-Portal) |
|-----------|-----------------|--------|---------------|--------------------|---------------|---------------------------|
| Xem trạng thái ví theo TK mình phụ trách | ✅ | ✅ (toàn bộ TK khách mình) | ✅ (toàn team) | ✅ (TK dự án mình) | ✅ | ✅ (tenant mình, mức tổng hợp) |
| Nhận alert + escalate theo SLA | ✅ (owner) | ✅ (chặng AM) | ✅ (chặng TL) | ❌ (chỉ xem mức) | ✅ | ❌ |
| Đề xuất lệnh top-up / giảm ngân sách | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ — Portal không tạo được lệnh |
| Đề xuất top-up một chạm từ alert | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình hạn mức đổi ngân sách theo cấp buyer | ❌ | ❌ | ✅ (TL cấu hình) | ❌ | ❌ | ❌ |
| Đổi ngân sách vượt hạn mức cấp mình | ❌ (cần duyệt bậc trên) | ✅ (theo cấp) | ✅ | ❌ | ❌ | ❌ |
| Khớp tiền / duyệt lệnh (dual approval) | ❌ | ❌ | ❌ | ❌ | ✅ (theo FEAT-001/003) | ❌ |
| Tự khớp tiền lệnh mình đề xuất | ❌ | ❌ | ❌ | ❌ | ❌ (SoD chặn) | ❌ |
| Xem lịch sử điều chỉnh ví (mask giá vốn) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (tenant mình, read-only) |

---

## 5. Trường Hợp Đặc Biệt

- **Alert Đỏ ngoài giờ hành chính/lễ:** escalate qua kênh on-call TL (SLA 4h ngoài giờ); lệnh vẫn phải tạo trên hệ thống; "2h làm việc" tính lại trên giờ làm việc kế tiếp — không có alert bị bỏ quên vì giờ giấc.
- **Owner vắng mặt (nghỉ ốm/offboard):** TL gán lại owner TK từ hàng đợi; alert không chờ cá nhân — lịch sử escalation giữ nguyên timestamp; offboard → thu hồi quyền trong 24h theo ma trận truy cập.
- **Khách có nhiều TK trên cùng platform:** alert per TK/platform; đề xuất top-up một chạm tạo 1 lệnh cho 1 TK — nạp gộp nhiều TK phải tách theo lệnh con (mỗi phần khớp tiền riêng, liên kết FEAT-CORE-WALLET-005).
- **Giảm ngân sách là hành động SLA:** khi khách chưa chuyển tiền ngay, owner có thể giảm ngân sách kéo dài số ngày chi được để dừng escalation hợp lệ — ADS rolling tự điều chỉnh lại theo ngày.
- **Ví Đỏ nhưng khách chậm nạp kéo dài:** kết hợp FEAT-CORE-WALLET-002 BR-A08 — FIN_L2 tạm giữ giải ngân tương ứng; OPS_AM thông báo khách và ghi kết quả liên hệ vào alert (timestamp).
- **Khách tự nạp (client-owned TK):** chỉ ghi nhận đối soát, không phát sinh lệnh nạp của BC — trạng thái ví vẫn hiển thị 3 mức cho OPS theo dõi, nhưng luồng hành động khác (liên hệ khách tự xử lý).
- **Mobile Portal (touchpoint rút gọn):** khách xem lịch sử điều chỉnh + số dư ở mức tổng hợp, mask giá vốn; không nhận alert nội bộ, không thao tác lệnh — chỉ các mốc "đã ghi nhận/đang đối soát".
- **OPS kiêm nhiệm nhiều vai:** nếu cá nhân giữ cả vai đề xuất và khớp/duyệt (ví dụ OPS_AM kiêm TL), SoD engine chặn riêng từng giao dịch — kiêm nhiệm không được biến thành tự duyệt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh ví góc OPS (WalletOrder — đề xuất nạp/giảm ngân sách/refund/điều chỉnh do OPS khởi tạo)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_FIN] ──(khớp tiền — FIN_L1)──► [MATCHED] ──(duyệt đủ — theo mode)──► [APPROVED] ──(thực thi)──► [EXECUTED]
   │                      │                        │                                              │
   │ (hủy nháp)           │ (bị từ chối + lý do)   │ (tiền về lệch → treo chờ đối chiếu)          │ (AML hold)
   ▼                      ▼                        ▼                                              ▼
[DRAFT_HUỶ]          [REJECTED] ──(AM khiếu nại lại)──► [PENDING_FIN]                        [ON_HOLD] ──(kết luận)──► tiếp tục | BLOCKED
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_FIN` | OPS_ADS/OPS_AM (đề xuất) | Đủ khách/TK/số tiền/tiền tệ/căn cứ; qua SoD check |
| `PENDING_FIN` | Đối chiếu sao kê khớp | `MATCHED` | FIN_L1 (≠ người đề xuất) | Số khớp, tên trùng KYC; snapshot tỷ giá tạo |
| `PENDING_FIN` | Từ chối (lệnh miệng, sai thông tin) | `REJECTED` | FIN_L1/FIN_L2 | Lý do bắt buộc |
| `MATCHED` | Duyệt đủ chữ ký (SINGLE/DUAL theo mode) | `APPROVED` | Theo mode hiện hành (FEAT-003) | Đề xuất ≠ duyệt; DUAL tuần tự FIN_L1 → FIN_L2 |
| `APPROVED` | Thực thi ghi sổ | `EXECUTED` | Core (tự động) | Không AML hold; reason code đủ |
| Bất kỳ đang chờ | AML cảnh báo | `ON_HOLD` | Hệ thống | Hold đến kết luận (FEAT-006) |

**Quy tắc:**
- OPS chỉ đến được `PENDING_FIN` — mọi trạng thái sau do FIN/hệ thống quyết; không có đường OPS → `EXECUTED` thẳng.
- `REJECTED` có thể khiếu nại lại (AM) và quay lại review — lịch sử cả hai vòng được giữ.
- Trạng thái giảm ngân sách (budget change) đi theo cùng state machine với type riêng và hạn mức theo cấp buyer (BR-O09).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `WalletOrder` | `type` (TOPUP_PROPOSAL/BUDGET_REDUCE/REFUND_PROPOSAL/ADJUSTMENT), `customer_id`, `ad_account_id`, `amount`, `currency`, `basis`, `status` | FK → `wallets.id`, `ad_accounts.id` | Sổ lệnh ví trung tâm; lệnh là input duy nhất FIN chấp nhận |
| `OneClickProposal` | `alert_id`, `prefill` (khách/TK/số tiền gợi ý theo ADS), `created_by`, `order_id` | FK → `balance_alerts.id`, `wallet_orders.id` | Đề xuất một chạm từ alert (BR-O01 luồng UX) |
| `BuyerBudgetLimit` | `buyer_level` (JUNIOR/MID/SENIOR), `daily_vnd_limit`, `configured_by` (TL) | — | `[CẦN CHỐT SỐ]` số VND/ngày; khung % đã chốt DI-005 |
| `EscalationLog` (chia sẻ FEAT-002) | `alert_id`, `stage` (OWNER/TL/AM), `sent_at`, `acted_at`, `action_ref` | FK → `balance_alerts.id` | Timestamp từng chặng; append-only |
| `ContactOutcomeLog` | `alert_id`, `contacted_by` (AM), `channel`, `outcome`, `customer_notified_at` | FK → `balance_alerts.id` | Kết quả AM liên hệ khách (quá 4h) |
| `PortalWalletHistoryView` | `tenant_id`, `entry_date`, `type`, `amount`, `masked_note` ("điều chỉnh đối soát") | View lọc `tenant_id` | Mask giá vốn ở tầng service; read-only; dùng chung Portal Web + Mobile Portal |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: One-click top-up proposal | Alert Đỏ đang mở | OPS_ADS bấm "đề xuất top-up" từ alert | Lệnh `WalletOrder` tạo prefilled (khách/TK/số tiền gợi ý), SLA clock dừng chặng OWNER | [ ] |
| SC-002: Chặn mượn chéo ví | Ví khách A Đỏ, ví khách B dư | OPS tạo lệnh trích ví B đắp ví A | Từ chối `CROSS_WALLET_TOPUP_DENIED`; nỗ lực log cho TL | [ ] |
| SC-003: Escalation đủ chặng | Alert Đỏ mở 2h30 | Kiểm tra escalation | Đã escalate TL với timestamp; quá 4h → AM nhận + AM liên hệ khách trong ngày làm việc | [ ] |
| SC-004: Lệnh miệng không dừng SLA | Owner nhắn Zalo "đã xử lý" | Hết 2h không lệnh trên hệ thống | Vẫn escalate; tin nhắn không có giá trị | [ ] |
| SC-005: Hạn mức buyer | Buyer Junior, hạn mức theo cấu hình TL | Đổi ngân sách vượt hạn mức cấp | Yêu cầu duyệt bậc trên; không cho thực thi vượt | [ ] |
| SC-006: SoD chặn tự duyệt | OPS_AM vừa đề xuất lệnh | Cùng cá nhân (kiêm vai) cố khớp tiền/duyệt | Chặn khi submit; log vi phạm SoD | [ ] |
| SC-007: Portal mask + isolation | Khách A có lịch sử điều chỉnh có giá vốn | Khách A xem Portal/Mobile Portal | Thấy "điều chỉnh đối soát" (mask); không thấy alert nội bộ; không tạo được lệnh; tenant B không thấy | [ ] |
| SC-008: Khẩn ngoài giờ | Alert Đỏ 22h đêm | Owner on-call tạo lệnh + FIN duyệt qua kênh khẩn trong hệ thống | Lệnh hợp lệ vì vẫn qua hệ thống; thiếu approval → escalate BOD | [ ] |

> **Liên kết:** SC-001→005, 008 map REQ-OPS-003 Mục 2 (BR-OPS-2.3/2.4/2.5) + REQ-FIN-002 (ngưỡng nguồn FIN); SC-006 map REQ-FIN-001/003 (SoD); SC-007 map REQ-FIN-017 + REQ-OPS-010 (mask, read-only).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — WalletOrder, OneClickProposal, BuyerBudgetLimit, PortalWalletHistoryView | `technical-specs/database-design.md` |
| API Endpoints — alert action, one-click proposal, escalation feed, portal history | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW (≤1h, degraded `manual`), MOBILE push ngoài giờ, Portal/M-Portal mask | `technical-specs/integration-map.md` |
| Màn hình UI (dashboard OPS + form lệnh thuộc SYS-BCERP-WEB; khách thuộc SYS-PORTAL-WEB/MOBILE-PORTAL) | `phase4-ux/bcerp-web/wallet-recon/*.md`, `phase4-ux/portal-web/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
