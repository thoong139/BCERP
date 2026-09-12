# Tính Năng: Ví TKQC góc ops — cảnh báo số dư & escalation

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A, B.2 — BR-OPS-2.3..2.5); phối hợp REQ-FIN-002 (`phase1-business/departments/finance/finance.md` — BR-FIN-104)
> **Phân hệ:** Vận hành (DEPT-OPS) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-007-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-OPS-003 (fan-out 6 hệ thống); counterpart: SYS-CORE-BACKEND (engine cảnh báo + SLA clock), SYS-INTEGRATION-GW (số dư/spend tươi ≤1h), SYS-MOBILE-INTERNAL (push + thao tác ngoài giờ), SYS-PORTAL-WEB & SYS-MOBILE-PORTAL (khách chỉ xem lịch sử điều chỉnh ví — read-only, mask giá vốn).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-007 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-OPS-003 (cross-dependency: REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN, một nguồn sự thật từ CORE) |
| Người dùng liên quan | OPS_ADS (owner ví — chính), OPS_AM, TL OPS; CROSS vai phụ trách ca: OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT (theo phân ca trực); CUSTOMER chỉ qua Portal/M-PORTAL (ngoài phạm vi touchpoint này) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-WALLET-002 (ngưỡng cảnh báo + SLA nguồn FIN — cùng dữ liệu CORE); FEAT-ERP-WALLET-001 (lệnh ví) |
| Ghi chú Expert (A7) | Dept doc operations có cấu trúc A7; phần review liên quan chưa có điều chỉnh cụ thể. Hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình — ngưỡng VND/ngày theo cấp Junior/Mid/Senior `[CẦN CHỐT SỐ]`, không tự quyết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp workspace góc vận hành trên Web nội bộ cho đội OPS (chủ yếu OPS_ADS làm owner ví, OPS_AM giữ quan hệ khách) để theo dõi cảnh báo số dư 3 mức per TK/nền tảng, hành động đúng SLA đỏ 2h làm việc (tạo lệnh đề xuất top-up hoặc giảm ngân sách), và được hệ thống escalation tự động có timestamp từng chặng owner → TL → AM — bảo đảm ví không hết quỹ gây die campaign, đồng thời tuân thủ tuyệt đối quy tắc lệnh ví (cấm mượn chéo ví, cấm xác nhận miệng).

**Phạm vi:**
- Bao gồm: dashboard số dư + "số ngày chi dự kiến" theo platform/khách cho góc ops; nút đề xuất top-up một chạm từ alert; theo dõi đồng hồ SLA đỏ và chuỗi escalation có timestamp; phân bổ owner ví và hiển thị hàng chờ việc của từng owner; hiển thị trạng thái ví sau khớp tiền (liên kết FEAT-ERP-WALLET-005); ghi nhận giảm ngân sách để kéo dài số ngày chi.
- Không bao gồm: tính ADS/phân mức/timer (SYS-CORE-BACKEND); số dư/spend tươi ≤1h và degraded `manual` (SYS-INTEGRATION-GW); push alert + thao tác ngoài giờ (SYS-MOBILE-INTERNAL); view khách (SYS-PORTAL-WEB/SYS-MOBILE-PORTAL — khách chỉ xem lịch sử điều chỉnh ví, trường gắn giá vốn mask thành "điều chỉnh đối soát", read-only tuyệt đối); màn khớp tiền của FIN_L1 (FEAT-ERP-WALLET-005).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: dashboard + form đề xuất + theo dõi SLA, gọi API core, hiển thị đúng trạng thái machine-state của alert và lệnh.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS (owner ví) | Thấy mọi TKQC mình phụ trách với mức Xanh/Vàng/Đỏ và số ngày chi dự kiến trên một dashboard | Chủ động lập kế hoạch nạp trước khi campaign chết |
| 2 | OPS_ADS | Bấm "đề xuất top-up" một chạm từ alert đỏ để tạo sẵn lệnh đúng khách/TKQC/tiền tệ | Đáp ứng SLA 2h trong vài phút thay vì soạn lại thủ công |
| 3 | OPS_ADS | Giảm ngân sách ngày của TK từ chính màn cảnh báo (theo hạn mức được cấp) | Kéo dài số ngày chi được khi khách chưa kịp nạp |
| 4 | OPS_AM | Nhận escalation khi quá 4h và thấy lịch sử các chặng owner → TL đã thử hành động gì | Chủ động liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày |
| 5 | TL OPS | Xem toàn bộ alert đỏ của team kèm đồng hồ SLA và trạng thái từng owner | Phân bổ lại việc khi owner vắng, can thiệp trước khi quá 2h |
| 6 | OPS_PLAN/OPS_CONT/OPS_DES/OPS_EDIT | Xem dashboard ví theo phân ca trực khi giữ ca (không sửa dữ liệu tài chính) | Ca trực vẫn nắm được tình hình ví để chuyển giao đúng |
| 7 | BOD_CFO_CTO (tham khảo qua bản FIN) | — (không thuộc workspace ops; xem tổng hợp tại FEAT-ERP-WALLET-002) | — |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Engine và SLA clock ở CORE; Web bảo đảm hành vi vận hành đúng quy tắc lệnh ví.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-O01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — dashboard ops hiển thị số dư khả dụng theo từng tiền tệ; đề xuất top-up chọn đúng ví-tiền tệ | Dashboard không cộng trộn USD/VND; lệnh đề xuất sai tiền tệ bị form chặn |
| BR-O02 | Công thức topup k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5) — form đề xuất top-up một chạm phải tính sẵn grossAmount theo k của Contract tại thời điểm tạo (snapshot) | OPS không tự điền con số gross khác công thức; sai k không submit được |
| BR-O03 | Cảnh báo 3 mức per TK/platform dùng đúng ngưỡng nguồn FIN (cross-dep REQ-FIN-002): **Xanh** (đủ chi ≥3 ngày — không hành động) / **Vàng** (<3 ngày — owner lập kế hoạch nạp, thông báo AM) / **Đỏ** (<1 ngày hoặc dưới mức tối thiểu platform — vào SLA đỏ); dữ liệu spend tươi ≤1h, nhãn `manual` khi degraded | Web không tự định nghĩa ngưỡng riêng; dữ liệu manual hiển thị nhãn + disclaimer |
| BR-O04 | **SLA đỏ 2h làm việc + escalation có timestamp**: 0–2h owner (OPS_ADS) phải tạo lệnh đề xuất top-up **hoặc** giảm ngân sách kéo dài số ngày chi; quá 2h → escalate TL; quá 4h → escalate AM (liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày); ngoài giờ escalate kênh on-call TL | Mỗi chặng ghi timestamp tự động; Web hiển thị chặng hiện tại; không có cách "hạ nhiệt" alert mà không có hành động thật |
| BR-O05 | **Quy tắc lệnh ví**: mọi top-up/refund/điều chỉnh chỉ qua lệnh hệ thống; cấm xác nhận miệng Zalo/điện thoại/email riêng — FIN từ chối đối chiếu lệnh miệng; OPS_ADS nhận alert đỏ chỉ được **nạp thêm qua lệnh**, **cấm mượn chéo ví giữa khách** (không dùng tiền khách khác đắp ví) | Không có UI chọn "nguồn tiền từ khách khác"; mọi lệnh gắn đúng ví-khách; lệnh miệng không tồn tại trong hệ thống để đối chiếu |
| BR-O06 | Dual approval (đề xuất ≠ duyệt) cho điều chỉnh số dư, tỷ giá tay, hoàn tiền (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự khi DUAL) — đề xuất của OPS luôn cần FIN duyệt, OPS không tự duyệt | Nút duyệt không tồn tại trong workspace ops; trạng thái lệnh phản ánh đúng chờ FIN xử lý |
| BR-O07 | SoD 4 vai dòng tiền: **đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ** — SoD engine chặn 1 người giữ ≥2 vai trong 1 giao dịch | Thử gán chính mình vào 2 bước bị block + log vi phạm cho CFO rà |
| BR-O08 | Refund từ platform (TK die còn dư): FIN_L1 khớp tiền hoàn về và ghi có theo giao dịch gốc; hoàn cho khách chỉ sau AM đề xuất + duyệt FIN_L2 — góc ops chỉ thấy trạng thái, không thao tác phần FIN | Workspace ops hiển thị trạng thái refund read-only; không có nút tác động dòng tiền hoàn |
| BR-O09 | Hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình — ngưỡng VND/ngày theo cấp Junior/Mid/Senior `[CẦN CHỐT SỐ — chờ chốt hạn mức]`; vượt hạn mức → chặn giảm ngân sách trực tiếp, phải đi luồng đề xuất | Form giảm ngân sách kiểm tra hạn mức theo profile người dùng; vượt hạn chỉ cho gửi đề xuất chờ duyệt |
| BR-O10 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0 / 0,5%·10USD / 1%·20USD, chốt & khóa kỳ — ví đang có ticket chênh lệch hiển thị nhãn "đang đối soát"; con số ops dùng là số đã đối soát từ CORE | Ops không thấy/ không dùng số "đã cân tay"; nhãn đối soát hiển thị đúng trạng thái |
| BR-O11 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — đề xuất top-up từ alert không nhảy qua kiểm tra AML; ops không hiển thị thông tin rebate của khách | Lệnh đề xuất vẫn đi qua rule engine; workspace ops không có màn rebate |
| BR-O12 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: khách xem lịch sử điều chỉnh ví của mình qua Portal/M-PORTAL (counterpart), trường gắn giá vốn mask thành "điều chỉnh đối soát", read-only tuyệt đối; workspace ops này không lộ cho khách | Không có route dùng chung không lọc tenant; mọi view khách đi qua Portal với mask + watermark |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Owner = OPS_ADS được gán theo khách/TK; CUSTOMER (chỉ Portal/M-PORTAL) không truy cập Web nội bộ — cột CUSTOMER đặt để chốt biên.

| Hành động | OPS_ADS | OPS_AM | TL OPS (OPS_PLAN/OPS_CONT đại diện vai quản lý ca) | FIN_L1/FIN_L2 | CUSTOMER |
|-----------|---------|--------|----------------------------------------------------|----------------|----------|
| Xem dashboard ví (khách mình phụ trách) | ✅ | ✅ (khách mình giữ) | ✅ (toàn team) | ✅ | ❌ (chỉ qua Portal read-only) |
| Đề xuất top-up một chạm từ alert | ✅ | ✅ | ❌ | ❌ (tạo ở workspace FIN nếu cần) | ❌ |
| Giảm ngân sách trong hạn mức cấp | ✅ | ❌ | ✅ (duyệt phê giảm vượt hạn mức ops) | ❌ | ❌ |
| Nhận escalation chặng TL/AM | ❌ (chặng owner) | ✅ (chặng AM) | ✅ (chặng TL) | ❌ | ❌ |
| Phân bổ lại owner ví khi vắng | ❌ | ❌ | ✅ | ❌ | ❌ |
| Khớp tiền/duyệt lệnh | ❌ | ❌ | ❌ | ✅ (workspace FIN — FEAT-001/003) | ❌ |
| Xem lịch sử điều chỉnh ví khách | ✅ | ✅ | ✅ | ✅ | ✅ (qua Portal/M-PORTAL, mask giá vốn) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Alert đỏ ngoài giờ làm việc: escalation chuyển kênh on-call TL (SYS-MOBILE-INTERNAL push); đồng hồ SLA tính giờ làm việc — Web hiển thị "ngoài giờ, on-call đã nhận"; lệnh vẫn phải tạo trên hệ thống, approval không bỏ qua.
- Owner OPS_ADS nghỉ việc/chuyển khách: TL phân bổ lại owner; lịch sử alert/lệnh cũ giữ nguyên người tạo cũ — không đổi tác giả dữ liệu lịch sử.
- Khách có nhiều TKQC burn nhanh cùng lúc: dashboard gom theo khách với tổng số ngày chi thấp nhất (worst case) để ưu tiên, cho phép mở rộng chi tiết per TK.
- Ví đỏ do client-owned TK (khách tự nạp trực tiếp nền tảng): không thể đề xuất top-up qua BC — alert hiển thị hướng dẫn AM liên hệ khách tự nạp; không sinh lệnh nạp BC sai mô hình.
- Giảm ngân sách gây ảnh hưởng hiệu suất campaign đang chạy tốt: ops phải ghi chú lý do; AM nhận thông báo kèm ngữ cảnh để cân nhắc với khách.
- Platform trả refund về ví sau khi alert đã escalation (ví tự hồi): alert tự hạ nhiệt khi số dư vượt ngưỡng Xanh; chuỗi escalation dừng với ghi chú "tự hồi do platform refund".
- Kỳ đã khóa/chốt trong lúc alert còn treo: alert vẫn xử lý được (không thuộc dữ liệu bị khóa), nhưng lệnh liên quan phát sinh sau chốt rơi vào kỳ mới — hiển thị kỳ áp dụng rõ ràng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Alert góc ops (OpsWalletAlert — cùng dữ liệu gốc với alert FIN của FEAT-ERP-WALLET-002, góc nhìn và hành động khác).*

**Entity:** Alert cảnh báo góc ops (OpsWalletAlert)

**Sơ đồ trạng thái:**
```
[TRIGGERED (đỏ)] ──(owner action: đề xuất top-up hoặc giảm ngân sách, 0–2h)──► [OWNER_ACTIONED]
      │                                                                              │
      │ (quá 2h)                                                                     │ (top-up được FIN khớp tiền / giảm NS hiệu lực)
      ▼                                                                              ▼
[ESCALATED_TL] ──(quá 4h)──► [ESCALATED_AM] ──(khách nạp + khớp)──► [RESOLVED]
      │
      └──(ví tự hồi vượt ngưỡng Xanh, ví dụ platform refund)──► [RESOLVED (tự hồi — ghi chú nguyên nhân)]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `TRIGGERED` | Đề xuất top-up / giảm ngân sách | `OWNER_ACTIONED` | OPS_ADS (owner), OPS_AM | Hành động là lệnh/điều chỉnh hợp lệ trên hệ thống; trong 0–2h làm việc |
| `TRIGGERED` | Quá 2h không hành động | `ESCALATED_TL` | Hệ thống (CORE timer) | Tự động + timestamp; on-call nếu ngoài giờ |
| `ESCALATED_TL` | Quá 4h | `ESCALATED_AM` | Hệ thống (CORE timer) | AM liên hệ khách trong ngày làm việc |
| `OWNER_ACTIONED` | Top-up được FIN_L1 khớp tiền | `RESOLVED` | Hệ thống (theo kết quả FEAT-ERP-WALLET-005) | Gate khớp tiền mở |
| Bất kỳ | Số dư hồi phục vượt ngưỡng Xanh | `RESOLVED` | Hệ thống | Ghi chú nguyên nhân (tự hồi/refund platform/nạp trực tiếp) |

**Quy tắc:**
- Mỗi chặng escalation timestamp bất biến; Web hiển thị dòng thời gian đầy đủ cho TL/AM.
- Vàng không tạo alert SLA — chỉ mức "lập kế hoạch nạp + thông báo AM" hiển thị trong dashboard.
- Hành động hạ nhiệt duy nhất là lệnh/điều chỉnh hợp lệ — không có nút "đóng alert thủ công" cho ops.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| OpsWalletAlert | `adAccountId`, `customerId`, `platformId`, `level`, `slaDeadline`, `state`, `ownerId` | FK → AdAccount/Customer/Employee | Cùng nguồn dữ liệu alert FIN (FEAT-002) |
| EscalationStep | `alertId`, `stage` (OWNER/TL/AM), `timestamp`, `actorId`, `onCall` | FK → OpsWalletAlert | Append-only |
| TopupProposal | `alertId`, `walletId`, `adAccountId`, `netAmount`, `grossAmount`, `kSnapshot`, `currency`, `state` | FK → OpsWalletAlert, Wallet, AdAccount | Một chạm từ alert; qua dual approval FIN |
| BudgetReduction | `adAccountId`, `oldDailyBudget`, `newDailyBudget`, `reasonNote`, `withinBuyerLimit` | FK → AdAccount | Kiểm tra hạn mức theo cấp buyer `[CẦN CHỐT SỐ]` |
| WalletHistoryView (cho Portal) | `customerId`, `adjustmentType`, `displayedAmount`, `maskedCostFlag` | FK → WalletTransaction (view lọc tenant) | Mask giá vốn → "điều chỉnh đối soát"; read-only |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đề xuất một chạm đúng k | Alert đỏ trên TK Meta (USD), Contract fee=3%/8%/8% | OPS_ADS bấm đề xuất top-up net 1.000 | Form ra gross 1.112,4 theo k snapshot; lệnh gửi FIN ở `PENDING` | [ ] |
| SC-002: SLA 2h escalation đúng chặng | Alert đỏ 10:00, owner không hành động | Hệ thống chạy timer | 12:01 escalate TL (timestamp); 14:01 escalate AM | [ ] |
| SC-003: Cấm mượn chéo ví | Ví khách A đỏ, ví khách B còn dư | Thử tạo lệnh nạp ví A ghi nguồn từ ví B | Không có lựa chọn hợp lệ; form chặn kèm giải thích quy tắc | [ ] |
| SC-004: Giảm ngân sách theo hạn mức | OPS_ADS cấp Junior, hạn mức `[CẦN CHỐT SỐ]` | Giảm ngân sách vượt hạn mức | Chặn trực tiếp; chuyển thành đề xuất chờ TL duyệt | [ ] |
| SC-005: Dữ liệu manual có nhãn | Nền tảng chưa API (degraded) | Xem số ngày chi dự kiến | Hiển thị nhãn `manual` + disclaimer độ trễ | [ ] |
| SC-006: Portal mask giá vốn | Khách xem lịch sử điều chỉnh qua Portal | Đọc trường điều chỉnh gắn giá vốn | Hiển thị "điều chỉnh đối soát", không lộ số giá vốn | [ ] |
| SC-007: Alert tự hồi | Ví đỏ được platform refund về | Số dư vượt ngưỡng Xanh | Alert `RESOLVED` với ghi chú "tự hồi — platform refund" | [ ] |

> **Liên kết:** SC-001→REQ-OPS-003 (BR-O02); SC-002→REQ-OPS-003 (BR-O04); SC-003/SC-004→REQ-OPS-003 (BR-O05/O09); SC-005→REQ-OPS-003 + REQ-FIN-002 (BR-O03); SC-006→REQ-OPS-003 (BR-O12) + REQ-FIN-017; SC-007→REQ-OPS-003 (BR-O03) trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (ops alert, escalation, topup proposal) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (ops-wallet-alerts, topup-proposals, budget-reductions) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-OPS-003: CORE, GW, M-INT, PORTAL, M-PORTAL) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (dashboard ops, hàng chờ alert, form đề xuất) |
| Bản touchpoint khác | FEAT cho 5 counterpart systems cùng REQ (lane riêng); góc FIN: FEAT-ERP-WALLET-002 |
