# Tính Năng: Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h

> **Dựa trên:** REQ-FIN-002 trong `phase1-business/departments/finance/finance.md` (Phần A, B.1 — BR-FIN-104)
> **Phân hệ:** Tài chính – Kế toán (DEPT-FINANCE) · Hệ thống: SYS-BCERP-WEB (Web nội bộ responsive Next.js)
> **Module:** Wallet & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md` (REQ-OPS-003 — cross-dependency)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-bcerp-web/mod-wallet-recon/*.md`, `phase5-implementation/tasks/sys-bcerp-web/mod-wallet-recon/FEAT-ERP-WALLET-002-impl.md`

> **Hướng dẫn ID:** Bản này là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-FIN-002 (fan-out 3 hệ thống); counterpart: SYS-CORE-BACKEND (tính ADS + timer SLA), SYS-MOBILE-INTERNAL (push ≤5 phút).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-WALLET-002 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-002 (cross-dependency: REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (góc FIN); owner alert phía OPS (OPS_ADS/OPS_AM) thao tác tại FEAT-ERP-WALLET-007 |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-ERP-WALLET-001 (sổ phụ ví + lệnh giao dịch — nguồn dữ liệu số dư); dữ liệu chi tiêu tươi ≤1h từ GW (REQ-FIN-005) |
| Ghi chú Expert (A7) | Dept doc có Mục A7 nhưng expert review chưa thực hiện — chưa có điều chỉnh cụ thể; lưu ý đánh dấu: chất lượng cảnh báo phụ thuộc Business Verification API nền tảng (dữ liệu `manual` khi degraded) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép FIN_L1/FIN_L2 thấy trước trên Web nội bộ ví nào của khách sắp hết quỹ (mức Xanh/Vàng/Đỏ theo số ngày chi được), theo dõi SLA đỏ 2h làm việc và chuỗi escalation có timestamp, để chủ động xin khách nạp kịp thời — tránh die campaign và tránh BC phải chi tiền trước khi tiền khách về (nguyên tắc tiền giữ hộ).

**Phạm vi:**
- Bao gồm: dashboard trạng thái ví theo khách/nền tảng trên Web với 3 mức cảnh báo; hiển thị "số ngày chi dự kiến" (average daily spend 7 ngày rolling); bảng theo dõi alert đỏ vào SLA 2h với từng chặng escalation có timestamp; hành động góc FIN khi khách chậm nạp (đánh dấu rủi ro gián đoạn, tạm giữ giải ngân tương ứng trong kế hoạch nạp tuần).
- Không bao gồm: tính ADS + phân mức + bộ đếm SLA + push mobile (thực thi ở SYS-CORE-BACKEND/SYS-MOBILE-INTERNAL — Web chỉ hiển thị kết quả); luồng đề xuất top-up một chạm và escalation góc ops (FEAT-ERP-WALLET-007 — bản REQ-OPS-003); view khách trên Portal (REQ-OPS-003 counterparts SYS-PORTAL-WEB/SYS-MOBILE-PORTAL).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint này là Web nội bộ: dashboard/list + workflow UI, gọi API core, hiển thị đúng trạng thái machine-state của alert và lệnh.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem dashboard số dư ví theo khách/nền tảng với mức Xanh (đủ chi ≥3 ngày) / Vàng (<3 ngày) / Đỏ (<1 ngày hoặc dưới mức tối thiểu nền tảng) | Biết ngay ví nào cần chuẩn bị dòng tiền nạp nền tảng |
| 2 | FIN_L1 | Thấy mỗi alert đỏ kèm đồng hồ SLA 2h và hành động của owner (đã tạo lệnh top-up hay đã giảm ngân sách) | Đo lường việc xử lý và can thiệp trước khi die campaign |
| 3 | FIN_L2 | Đánh dấu ví đỏ "rủi ro gián đoạn chi tiêu" khi khách chậm nạp và tạm giữ phần giải ngân tương ứng trong kế hoạch nạp nền tảng tuần | Không chi tiền BC trước khi tiền khách về |
| 4 | BOD_CFO_CTO | Xem báo cáo tổng hợp alert theo mức, tỷ lệ xử lý đúng SLA, ví đang bị tạm giữ giải ngân | Giám sát rủi ro dòng tiền và hiệu quả xử lý của FIN/OPS |
| 5 | FIN_L1 | Lọc danh sách ví theo tiền tệ (USD/VND không gộp) khi rà soát kế hoạch nạp | Ngưỡng đủ chi phải tính đúng trên từng tiền tệ, không quy đổi ước lượng |
| 6 | FIN_L2 | Xem vết audit của mỗi lần tạm giữ/mở giữ giải ngân (ai, khi nào, lý do) | Truy cứu được khi đối soát hoặc tranh chấp với khách |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Ngưỡng và máy tính ADS nằm ở CORE; Web bảo đảm hiển thị đúng và không cho thao tác ngoài luồng.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-C01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8) — số dư phục vụ tính cảnh báo là số dư khả dụng theo từng tiền tệ từ sổ phụ FEAT-ERP-WALLET-001 | Cảnh báo tính trên số dư quy đổi chung bị chặn; UI luôn hiển thị theo cặp (ví, tiền tệ) |
| BR-C02 | Công thức topup chuẩn CMS doc §5: k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều — lệnh top-up đề xuất từ alert phải tính qua công thức này, không nhập tay con số "trời biết" | Form đề xuất tính sai k bị chặn submit; chỉ tạo lệnh qua form chuẩn có snapshot % |
| BR-C03 | ADS 7 ngày rolling **per TKQC/nền tảng**, cập nhật hằng ngày từ dữ liệu chi tiêu tươi ≤1h (GW); 3 mức: **Xanh** (đủ chi ≥3 ngày), **Vàng** (<3 ngày), **Đỏ** (<1 ngày hoặc số dư dưới mức tối thiểu nền tảng) | Hiển thị sai mức màu so với máy tính CORE là bug chặn nghiệm thu; Web không tự tính lại ngưỡng riêng |
| BR-C04 | Alert đỏ kích hoạt **SLA 2h làm việc**: owner phải tạo lệnh top-up hoặc giảm ngân sách trên hệ thống trong 0–2h; escalation có timestamp từng chặng: owner (0–2h) → TL (quá 2h) → AM (quá 4h, chủ động liên hệ khách yêu cầu nạp); ngoài giờ escalate kênh on-call | Web hiển thị alert quá SLA màu cảnh báo + trạng thái escalation hiện tại; không có cách nào "reset" đồng hồ mà không có hành động thật trên lệnh |
| BR-C05 | Mobile push cảnh báo ≤5 phút từ lúc sync phát hiện là trách nhiệm counterpart SYS-MOBILE-INTERNAL — Web không thay thế push; Web có nghĩa vụ hiển thị cùng dữ liệu trạng thái (single source of truth từ CORE) | Không được tạo cơ chế cảnh báo song song riêng trên Web làm lệch trạng thái; mọi trạng thái alert lấy từ API CORE |
| BR-C06 | Exception góc FIN: ví đỏ mà khách chậm nạp → FIN_L1 đánh dấu "rủi ro gián đoạn chi tiêu"; nếu khách nằm trong kế hoạch nạp nền tảng tuần, FIN_L2 tạm giữ phần giải ngân tương ứng đến khi tiền khách về — không chi tiền BC trước khi có tiền khách (nguyên tắc tiền giữ hộ) | Mỗi lần tạm giữ/mở giữ bắt buộc reason code + audit log bất biến; không có nút giữ/mở không lý do |
| BR-C07 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0 / 0,5%·10USD / 1%·20USD, chốt & khóa kỳ — số ngày chi dự kiến hiển thị trên dashboard phải khớp với số dư đã đối soát; ví đang có ticket chênh lệch vượt dung sai hiển thị nhãn "đang đối soát" | Dashboard không hiển thị số dư "đã cân tay"; nhãn nguồn dữ liệu (`api`/`manual`) hiển thị kèm disclaimer khi manual |
| BR-C08 | Dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền — hành động xử lý alert không được tự động sửa số dư để "hết đỏ" | Mọi thay đổi số dư chỉ qua lệnh được duyệt (FEAT-ERP-WALLET-003); không có đường tắt xóa alert bằng cách sửa số |
| BR-C09 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10) — cảnh báo lệnh nạp khối lượng lớn do alert đỏ không bỏ qua AML check | Lệnh top-up tạo từ alert vẫn chạy qua rule engine T1–T6 như lệnh thường; UI không hiển thị trạng thái "ưu tiên bỏ kiểm tra" |
| BR-C10 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: dashboard Web nội bộ là dữ liệu FIN nội bộ, tuyệt đối không trộn dữ liệu khách vào view Portal; cảnh báo nội bộ (bao gồm nhãn rủi ro, tạm giữ) không lộ cho khách | Không tồn tại endpoint Web nội bộ trả cảnh báo cho tenant khách; test tenant isolation bắt buộc trước go-live |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. OWNER của alert xác định theo assignment khách/TKQC (OPS_ADS/OPS_AM) — xem bản ops tại FEAT-ERP-WALLET-007.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_ADS/OPS_AM | SYS_ADMIN |
|-----------|--------|--------|-------------|----------------|-----------|
| Xem dashboard ví theo khách/nền tảng | ✅ | ✅ | ✅ | ✅ (khách mình phụ trách) | ❌ |
| Xem chi tiết SLA + escalation timestamp | ✅ | ✅ | ✅ | ✅ (alert của mình) | ❌ |
| Đánh dấu "rủi ro gián đoạn chi tiêu" | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạm giữ/mở giữ giải ngân trong kế hoạch tuần | ❌ | ✅ | ✅ (rà soát) | ❌ | ❌ |
| Tạo lệnh top-up từ alert | ✅ | ❌ (duyệt ở FEAT-003) | ❌ | ✅ (đề xuất) | ❌ |
| Cấu hình ngưỡng mức Xanh/Vàng/Đỏ | ❌ | ❌ | ✅ (phê duyệt chính sách ngưỡng) | ❌ | ✅ (thiết lập kỹ thuật theo chính sách đã duyệt) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Dữ liệu chi tiêu degraded (`manual` do nền tảng chưa có API — DI-007): số ngày chi dự kiến tính từ dữ liệu manual phải hiển thị nhãn nguồn + disclaimer độ trễ, không đóng giả dữ liệu tươi.
- Ví đỏ ngoài giờ làm việc: escalation chuyển kênh on-call TL; đồng hồ SLA tính giờ làm việc — Web hiển thị rõ "ngoài giờ, chờ on-call" thay vì đếm tiếp như giờ thường.
- Khách có nhiều TKQC trên cùng ví: alert tính per TK nhưng tổng ví có thể còn đủ — hiển thị cả 2 tầng (per-TK để cảnh báo, per-ví để nắm tổng), tránh báo động giả "ví hết tiền" khi chỉ 1 TK burn nhanh.
- ADS đột biến do khách tự tăng ngân sách ngoài dự kiến: mức cảnh báo chuyển đỏ hợp lệ — hệ thống ghi chú nguyên nhân biến động từ dữ liệu chi tiêu thay vì coi là lỗi dữ liệu.
- Ví đỏ nhưng khách là diện EDD/rủi ro AML: lệnh top-up phát sinh từ alert vẫn phải đi qua AML T1–T6 — UI giữ trạng thái chờ kiểm tra AML, không "ưu tiên nhanh".
- Nhiều alert đỏ cùng lúc nghẽn xử lý: Web sắp xếp theo thời gian còn lại của SLA (gần breach lên đầu) và cho FIN_L2 phân bổ lại owner tạm thời khi owner vắng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính: Alert cảnh báo số dư ví. Máy trạng thái thực thi ở CORE; Web hiển thị và cho phép các hành động theo vai.*

**Entity:** Alert cảnh báo số dư (WalletBalanceAlert)

**Sơ đồ trạng thái:**
```
[TRIGGERED] ──(owner tạo lệnh top-up hoặc giảm ngân sách, 0–2h)──► [ACTIONED] ──(tiền về/khớp)──► [RESOLVED]
     │                                                                  │
     │ (quá 2h)                                                         │ (quá 4h không xử lý tiếp)
     ▼                                                                  ▼
[ESCALATED_TL] ──(quá 4h)──► [ESCALATED_AM] ────────────────────► [ESCALATED_AM] (AM liên hệ khách)
     │
     └──(mức tự hạ khi nạp thêm)──► [RESOLVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `TRIGGERED` (đỏ) | Owner tạo lệnh top-up / giảm ngân sách | `ACTIONED` | OPS_ADS/OPS_AM (owner), FIN_L1 | Hành động là lệnh hệ thống thật; trong 0–2h làm việc |
| `TRIGGERED` | Không phản hồi quá 2h | `ESCALATED_TL` | Hệ thống (CORE timer) | Tự động; ghi timestamp chặng TL |
| `ESCALATED_TL` | Không phản hồi quá 4h | `ESCALATED_AM` | Hệ thống (CORE timer) | Tự động; AM liên hệ khách trong ngày làm việc |
| `ACTIONED` | Tiền khách về + khớp lệnh | `RESOLVED` | FIN_L1 | Khớp theo vòng lệnh nạp FEAT-ERP-WALLET-001 |
| Bất kỳ | Nạp thêm/khôi phục đủ chi ≥3 ngày | `RESOLVED` | Hệ thống | Số dư khả dụng per tiền tệ vượt ngưỡng Xanh |

**Quy tắc:**
- Mỗi chặng escalation ghi timestamp bất biến — Web hiển thị dòng thời gian, không cho sửa/xóa chặng.
- Mức Xanh/Vàng là trạng thái tính toán (không tạo alert), chỉ Đỏ tạo alert có SLA.
- Ngoài giờ: bộ đếm dừng theo giờ làm việc; kênh on-call nhận thông báo, lệnh vẫn phải tạo trên hệ thống.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| WalletBalanceAlert | `walletId`, `adAccountId`, `level` (RED), `triggeredAt`, `slaDeadline`, `state` | FK → Wallet, AdAccount | Per TK/nền tảng; tiền tệ kế thừa từ ví |
| EscalationStep | `alertId`, `stage` (OWNER/TL/AM), `timestamp`, `actorId` | FK → WalletBalanceAlert | Append-only, không sửa |
| AdSpendDaily | `adAccountId`, `date`, `spend`, `source` (`api`/`manual`), `syncedAt` | FK → AdAccount | Nguồn tính ADS 7 ngày |
| SpendHold (tạm giữ giải ngân) | `customerId`, `amount`, `currency`, `reasonCode`, `status`, `holdBy`, `releasedBy` | FK → Customer, Kế hoạch nạp tuần | Mở giữ bắt buộc reason code |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Mức màu đúng công thức | TKQC có ADS 7 ngày = 1.000 USD/ngày, số dư khả dụng 2.500 USD | CORE tính lại hằng ngày | Mức Đỏ (<1 ngày... không — 2,5 ngày → Vàng) hiển thị Vàng trên dashboard; per tiền tệ đúng | [ ] |
| SC-002: SLA đỏ 2h đếm đúng | Alert đỏ 10:00 | 12:01 chưa có lệnh | Chuyển `ESCALATED_TL`, timestamp chặng TL ghi tự động | [ ] |
| SC-003: Owner action đúng loại | Alert đỏ trong SLA | Owner giảm ngân sách trên hệ thống | `ACTIONED`, không escalate nữa | [ ] |
| SC-004: Tạm giữ giải ngân góc FIN | Khách ví đỏ, chậm nạp, nằm kế hoạch nạp tuần | FIN_L2 tạm giữ phần tương ứng | Hold ghi reason code + audit; kế hoạch tuần trừ phần giữ | [ ] |
| SC-005: Nhãn dữ liệu manual | Nền tảng chưa API, dữ liệu import tay | Xem số ngày chi dự kiến | Hiển thị nhãn `manual` + disclaimer độ trễ | [ ] |
| SC-006: Không gộp tiền tệ | Ví USD đỏ, ví VND xanh cùng khách | Xem dashboard | Hai dòng riêng theo tiền tệ, không cộng trộn | [ ] |

> **Liên kết:** SC-001/SC-005 → REQ-FIN-002 (BR-C03, BR-C07); SC-002/SC-003 → REQ-FIN-002 (BR-C04); SC-004 → REQ-FIN-002 exception BR-FIN-104; SC-006 → REQ-FIN-002 + REQ-OPS-003 trong Mục 2.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (alert, escalation, spend daily) |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` (wallet-alerts, spend-sync) |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` (fan-out REQ-FIN-002: CORE, MOBILE-INTERNAL; cross REQ-OPS-003) |
| Màn hình UI | `phase4-ux/sys-bcerp-web/mod-wallet-recon/` (dashboard ví, bảng SLA escalation) |
| Bản touchpoint khác | FEAT cho SYS-CORE-BACKEND / SYS-MOBILE-INTERNAL cùng REQ (lane riêng), FEAT-ERP-WALLET-007 (góc ops) |
