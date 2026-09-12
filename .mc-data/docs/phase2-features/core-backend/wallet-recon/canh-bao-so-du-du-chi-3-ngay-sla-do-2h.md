# Tính Năng: Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h

> **Dựa trên:** REQ-FIN-002 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-CORE-BACKEND)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/wallet-recon/*.md`, `phase5-implementation/tasks/core-backend/wallet-recon/feat-core-wallet-002-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-CORE-BACKEND** của REQ-FIN-002 (REQ xuất hiện ở 3 systems). Counterparts: SYS-BCERP-WEB (dashboard ví theo khách/nền tảng), SYS-MOBILE-INTERNAL (push cảnh báo ≤5 phút). Touchpoint Core Backend là **headless API/domain service**: engine tính ADS, phân mức, bộ đếm SLA và escalation chạy ở tầng service — UI chỉ hiển thị kết quả, không tin UI. Cross-dependency: REQ-OPS-003 — cảnh báo số dư ví: FIN nắm sổ sách (ngưỡng, tính toán), OPS vận hành nạp (owner hành động theo alert).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-WALLET-002 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-FIN-002 (cross-dependency: REQ-OPS-003) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (theo dõi, tạm giữ giải ngân); owner ví OPS_ADS/OPS_AM và TL hành động theo SLA (chi tiết góc OPS tại FEAT-CORE-WALLET-007) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-001 (sổ phụ ví — nguồn số dư và giao dịch); dữ liệu chi tiêu tươi từ GW theo REQ-FIN-005 |
| Ghi chú Expert (A7) | Expert review Phần A finance.md chưa thực hiện chính thức (chờ review); điểm phối hợp liên phòng đã xác định: cảnh báo số dư là điểm giao FIN–OPS — FIN tính ngưỡng và sổ sách, OPS vận hành nạp; REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng nên alert phải chạy được cả với dữ liệu nhãn `manual` |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép BC biết trước ví/TKQC nào sắp hết quỹ **trước khi campaign die**: Core Backend tự động tính average daily spend (ADS) 7 ngày rolling cho từng TK/nền tảng, so với số dư ví để phân 3 mức Xanh/Vàng/Đỏ, và khi chạm mức Đỏ kích hoạt SLA 2h làm việc với cơ chế escalation có timestamp từng chặng (owner → TL → AM). Điều này giúp chủ động xin khách nạp đúng lúc, tránh die campaign và tránh BC phải chi tiền của mình đắp tiền khách (vi phạm nguyên tắc tiền giữ hộ).

**Phạm vi:**
- Bao gồm: job tính ADS 7 ngày rolling per TK/platform (cập nhật hằng ngày từ dữ liệu chi tiêu của GW, nhãn `api` hoặc `manual`); phân 3 mức — Xanh (đủ chi ≥3 ngày), Vàng (<3 ngày), Đỏ (<1 ngày hoặc dưới mức tối thiểu của nền tảng); bộ đếm SLA đỏ 2h làm việc; auto-escalation owner (0–2h) → TL (quá 2h) → AM (quá 4h, chủ động liên hệ khách) với timestamp mỗi chặng; nâng escalation ngoài giờ qua kênh on-call; API trạng thái alert cho dashboard WEB và push MOBILE; góc FIN: đánh dấu rủi ro gián đoạn chi tiêu + tạm giữ giải ngân tương ứng khi ví đỏ mà khách chậm nạp.
- Không bao gồm: màn hình dashboard và thao tác tạo lệnh top-up/giảm ngân sách (SYS-BCERP-WEB; góc vận hành nạp của OPS thuộc FEAT-CORE-WALLET-007); pull dữ liệu chi tiêu từ nền tảng (SYS-INTEGRATION-GW — REQ-FIN-005, Core chỉ tiêu thụ dữ liệu nhãn nguồn); ghi nhận số dư ví (FEAT-CORE-WALLET-001); hard stop cấp phát TK (FEAT-CORE-WALLET-005).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Core tự tính "số ngày chi được" cho từng TK/nền tảng mỗi ngày và gán mức Xanh/Vàng/Đỏ | Không phải dò tay từng ví trên ảnh chụp màn hình; biết ngay ví nào sắp nguy |
| 2 | FIN_L1 | Khi ví chạm Đỏ, hệ thống khởi động đồng hồ SLA 2h và ghi timestamp từng chặng escalation | Có bằng chứng ai được báo lúc nào, ai chậm phản hồi — không tranh cãi "tôi không nhận được alert" |
| 3 | FIN_L2 | Ví đỏ mà khách chậm nạp → đánh dấu rủi ro gián đoạn và tạm giữ phần giải ngân nạp nền tảng tương ứng | Không chi tiền BC trước khi tiền khách về, bảo vệ nguyên tắc tiền giữ hộ |
| 4 | BOD_CFO_CTO | Xem tổng quan ví đỏ/vàng theo khách/nền tảng + trạng thái SLA (bao nhiêu alert quá 2h/4h) | Nắm rủi ro dòng tiền của công ty và đánh giá kỷ luật vận hành theo số liệu |
| 5 | Owner ví (OPS_ADS — góc chi tiết tại FEAT-CORE-WALLET-007) | Nhận alert đỏ kèm "số ngày chi dự kiến" và bị yêu cầu chọn 1 trong 2 hành động: tạo lệnh top-up hoặc giảm ngân sách trong 2h | Có mốc trách nhiệm rõ ràng, hành động ngay trước khi campaign die |
| 6 | Hệ thống (Core service) | Tự escalate qua TL rồi AM khi hết 2h/4h không có hành động hợp lệ, và đẩy kênh on-call ngoài giờ | Không ai phải nhớ theo dõi tay; alert không bao giờ "chìm" |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của Core Backend; SLA clock và escalation chạy phía server, không dựa vào client.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-A01 | Nền tảng dữ liệu: ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) — engine cảnh báo đọc số dư từ ledger FEAT-CORE-WALLET-001 theo từng currency, không quy đổi gộp khi tính số ngày chi được | Chặn tính toán trên số dư tổng hợp chéo currency; mỗi TK tính trên đúng currency của nó |
| BR-A02 | Công thức nền: mọi số dư/alert gắn với giao dịch tạo ra từ lệnh hệ thống và snapshot fee % tại thời điểm giao dịch; chi tiêu dự phóng dùng công thức k = 1 + feePercent×(1+vatOnFeePercent) + vatOnSpendPercent (NET/GROSS 2 chiều) để quy đổi giữa NSQC và tổng tiền trừ ví | Nếu dữ liệu chi tiêu GW không khớp công thức k của giao dịch gốc → cờ bất thường, chuyển ticket đối soát (FEAT-CORE-WALLET-004) |
| BR-A03 | Tính ADS 7 ngày rolling per TK/platform, cập nhật hằng ngày; 3 mức: **Xanh** (đủ chi ≥3 ngày — không hành động), **Vàng** (<3 ngày — owner lập kế hoạch nạp, thông báo AM), **Đỏ** (<1 ngày HOẶC số dư dưới mức tối thiểu nền tảng — vào SLA đỏ) | Sai công thức/mức → chấp nhận lại toàn bộ ngày tính lại; job fail → retry + alert, không để ngày trống dữ liệu âm thầm |
| BR-A04 | Alert Đỏ kích hoạt **SLA 2h làm việc**: owner (OPS_ADS) phải thực hiện 1 trong 2 hành động trên hệ thống — tạo lệnh đề xuất top-up hoặc giảm ngân sách kéo dài số ngày chi được; hành động hợp lệ mới dừng đồng hồ | Quá 2h không có hành động → auto-escalate TL; Core chỉ công nhận hành động ghi qua lệnh hệ thống, tin nhắn miệng không dừng SLA |
| BR-A05 | Escalation có timestamp từng chặng: owner (0–2h) → TL (quá 2h) → AM (quá 4h — chủ động liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày); ngoài giờ escalate kênh on-call (SLA on-call 4h ngoài giờ) | Bộ đếm chạy phía server; mọi chặng ghi ai-nhận-lúc-nào; tắt/thay đổi timer không được phép ở UI — chỉ cấu hình hệ thống |
| BR-A06 | MOBILE push cảnh báo ≤5 phút từ lúc sync phát hiện; dữ liệu chi tiêu đầu vào phải tươi ≤1h (GW cấp, nhãn `api`/`manual`); alert sinh ra kèm khách/TK/nền tảng/số ngày chi dự kiến | Push trễ vượt 5 phút → log sự cố vận hành; dữ liệu `manual` hiển thị kèm nhãn nguồn và disclaimer độ trễ |
| BR-A07 | Dual approval (SINGLE/DUAL công tắc hệ thống, FIN_L1 → FIN_L2 tuần tự) vẫn áp dụng cho lệnh top-up sinh ra từ alert nếu thuộc 3 nhóm rủi ro cao (điều chỉnh số dư/đổi tỷ giá/hoàn tiền); lệnh top-up bình thường đi vòng lệnh nạp chuẩn của FEAT-CORE-WALLET-001 | Service chặn thiếu chữ ký/sai thứ tự bất kể alert có urgent hay không — alert không được dùng làm lý do bỏ bước duyệt |
| BR-A08 | Góc FIN khi ví đỏ kéo dài: FIN_L1 đánh dấu TK "rủi ro gián đoạn chi tiêu"; nếu khách nằm trong kế hoạch nạp nền tảng tuần, FIN_L2 tạm giữ phần giải ngân tương ứng đến khi tiền khách về — không chi tiền BC trước khi có tiền khách (nguyên tắc tiền giữ hộ) | Giải ngân vẫn bị chặn trong khi cờ "tạm giữ" còn hiệu lực; mở giữ phải có lệnh nạp khách đã "Đã khớp tiền" |
| BR-A09 | Dữ liệu alert phục vụ đối trừ 3 số (sổ ví – platform – ngân hàng) với dung sai 0 / 0,5%·10USD / 1%·20USD (mặc định đã chốt theo DI-001) và chốt & khóa kỳ — đối chiếu chi tiết tại FEAT-CORE-WALLET-004; alert số dư không được dùng để tự cân số | Chênh lệch phát hiện qua alert chuyển ticket discrepancy, cấm tự cân số hai vế cho khớp |
| BR-A10 | AML monitoring T1–T6 + UBO ≥25% (mặc định đã chốt theo DI-001) vẫn chấm điểm mọi lệnh nạp phát sinh từ cảnh báo; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý — alert không tự động tính/kích hoạt rebate | Lệnh nạp từ alert vi phạm ngưỡng AML → khóa mềm (hold) theo FEAT-CORE-WALLET-006 trước khi thực thi |
| BR-A11 | Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation: khách thấy số dư + "số ngày chi dự kiến" của tenant mình qua view lọc; không thấy alert nội bộ, escalation log, giá vốn | Truy vấn Portal bị ép điều kiện tenant; cảnh báo nội bộ/SLA không bao giờ lộ ra view khách |

**Giả định chờ xác nhận:** ngưỡng "mức tối thiểu nền tảng" per platform cần cấu hình khi triển khai (chưa có bảng chuẩn trong nguồn); 11 KXN còn mở (KXN-6/7/9/15–22) thuộc domain CRM/lifecycle — không tác động rule cảnh báo của module này.

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_ADS (owner) | OPS_AM/TL | SYS_ADMIN | CUSTOMER (Portal) |
|-----------|--------|--------|-------------|-----------------|-----------|-----------|-------------------|
| Xem dashboard trạng thái ví theo khách/nền tảng | ✅ | ✅ | ✅ (tổng hợp) | ✅ (TK mình phụ trách) | ✅ (TK mình) | ❌ | ✅ (tenant mình, mức tổng hợp) |
| Xem alert + timestamp escalation | ✅ | ✅ | ✅ | ✅ (alert mình) | ✅ (được escalate) | ❌ | ❌ |
| Đánh dấu "rủi ro gián đoạn chi tiêu" | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạm giữ giải ngân tương ứng khi ví đỏ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo lệnh top-up / giảm ngân sách (hành động SLA) | ✅ | ✅ | ❌ | ✅ (bắt buộc trong 2h) | ✅ | ❌ | ❌ |
| Xác nhận khách đã được liên hệ (chặng AM) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Cấu hình ngưỡng mức tối thiểu nền tảng / timer SLA | ❌ | ❌ | ✅ (phê duyệt) | ❌ | ❌ | ✅ (thao tác cấu hình) | ❌ |
| Tắt/đổi timer SLA trên alert đang chạy | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không có interface) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Nền tảng chưa có API (degraded `manual`):** dữ liệu chi tiêu từ import/nhập tay nhãn `manual`, tươi kém hơn — alert vẫn chạy trên dữ liệu có nhãn, hiển thị disclaimer độ trễ; khi API sống lại, GW backfill và Core tính lại ADS các ngày bị ảnh hưởng.
- **TK mới mở chưa đủ 7 ngày dữ liệu:** ADS tính trên số ngày có dữ liệu thực tế (tối thiểu 1 ngày); mức mặc định khởi điểm là Vàng cho đến khi đủ dữ liệu — không suy diễn từ TK khác.
- **Khách giảm ngân sách đột ngột:** ADS rolling 7 ngày sẽ cao hơn thực tế mới — owner giảm ngân sách được tính là hành động hợp lệ dừng SLA; ADS tự điều chỉnh lại theo ngày.
- **Ví đỏ ngoài giờ hành chính/lễ Tết:** escalate qua kênh on-call TL (SLA 4h ngoài giờ); lệnh vẫn phải tạo trên hệ thống, approval không được bỏ qua; đồng hồ "2h làm việc" tính lại trên giờ làm việc kế tiếp.
- **Ví đỏ nhưng khách đang có lệnh nạp chờ khớp tiền:** alert hiển thị "đang chờ tiền khách"; FIN_L2 vẫn tạm giữ giải ngân tương ứng đến khi lệnh đạt "Đã khớp tiền" — trạng thái "khách hứa chuyển" không giảm mức cảnh báo.
- **Multi-currency:** TK tính mức cảnh báo trên đúng currency của nó (TK USD dùng USD, TK VND dùng VND); không quy đổi gộp làm sai số ngày chi được.
- **Nghẽn alert (nhiều ví đỏ cùng lúc):** Core sắp xếp hàng đợi escalation theo độ nghiêm (số ngày chi <1 trước, dưới mức tối thiểu nền tảng trước); không ai được gỡ alert khỏi hàng đợi thủ công.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** BalanceAlert (cảnh báo số dư per TK/platform)

**Sơ đồ trạng thái:**
```
[XANH] ──(đủ chi <3 ngày)──► [VÀNG] ──(<1 ngày / dưới mức tối thiểu)──► [ĐỎ — SLA 2H]
   ▲                            │                                          │
   │ (số dư phục hồi ≥3 ngày)   │ (owner lập kế hoạch nạp)                 │ (owner tạo lệnh top-up hoặc giảm ngân sách trong 2h)
   └────────────────────────────┴──────────────────────────────────────────┤
                                            ▲                              │ (quá 2h không hành động)
                                            │                              ▼
                                     [ESCALATED — TL] ──(quá 4h)──► [ESCALATED — AM]
                                            │                              │
                                            └──────(hành động hợp lệ)──────┴──► [RESOLVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `XANH` | Job tính ADS hằng ngày phát hiện <3 ngày | `VÀNG` | Hệ thống | ADS + số dư từ ledger FEAT-001 |
| `VÀNG` | Số ngày chi <1 hoặc dưới mức tối thiểu nền tảng | `ĐỎ` (SLA clock bắt đầu) | Hệ thống | Ghi timestamp mở SLA; push MOBILE ≤5 phút |
| `ĐỎ` | Owner tạo lệnh top-up / giảm ngân sách | `RESOLVED` | OPS_ADS (owner), FIN_L1/L2, OPS_AM | Hành động ghi qua lệnh hệ thống; SLA clock dừng, ghi timestamp |
| `ĐỎ` | Quá 2h không hành động | `ESCALATED — TL` | Hệ thống (auto) | Ghi timestamp chặng TL; notify TL + kênh on-call ngoài giờ |
| `ESCALATED — TL` | Quá 4h không hành động | `ESCALATED — AM` | Hệ thống (auto) | Ghi timestamp chặng AM; AM liên hệ khách trong ngày làm việc |
| `ESCALATED — TL/AM` | Hành động hợp lệ xuất hiện | `RESOLVED` | Owner/AM | Bắt buộc dẫn chiếu lệnh top-up hoặc biên giảm ngân sách |
| Bất kỳ | Số dư phục hồi đủ chi ≥3 ngày (nạp đã khớp tiền) | `XANH` | Hệ thống | Chỉ tính lệnh đã "Đã khớp tiền"; "chờ duyệt" không tính |

**Quy tắc:**
- Escalation chỉ đi tiến (owner → TL → AM); không ai hạ cấp escalation thủ công — chỉ hành động hợp lệ trên hệ thống mới kết thúc alert.
- `RESOLVED` giữ toàn bộ lịch sử timestamp để báo cáo kỷ luật SLA; không xóa alert đã phát sinh.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `SpendMetric` | `ad_account_id`, `date`, `spend`, `currency`, `source` (`api`/`manual`), `synced_at` | FK → `ad_accounts.id` | Đầu vào từ GW (REQ-FIN-005); tươi ≤1h |
| `BalanceAlert` | `ad_account_id`, `platform_id`, `customer_id`, `currency`, `ads_7d`, `days_remaining`, `level` (XANH/VÀNG/ĐỎ), `min_platform_balance` | FK → `wallets.id` | Tính hằng ngày; theo đúng currency, không gộp |
| `EscalationLog` | `alert_id`, `stage` (OWNER/TL/AM), `assigned_to`, `sent_at`, `acted_at`, `action_ref` | FK → `balance_alerts.id` | Append-only; timestamp từng chặng |
| `SpendingRiskFlag` | `customer_id`, `flag_type` (GIÁN ĐOẠN/TẠM GIỮ GIẢI NGÂN), `hold_amount`, `set_by`, `released_at` | FK → `customers.id` | Góc FIN BR-A08; mở giữ khi lệnh nạp "Đã khớp tiền" |
| `AlertConfig` | `platform_id`, `min_balance`, `sla_red_hours` (mặc định 2), `escalate_tl_hours` (2), `escalate_am_hours` (4) | — | Đổi cấu hình cần BOD_CFO_CTO phê duyệt + audit log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Phân mức đúng | TK chi 1.000 USD/ngày đều 7 ngày, số dư ví USD 2.500 | Job hằng ngày chạy | days_remaining ≈ 2,5 → mức VÀNG; không động vào ví VND của cùng khách | [ ] |
| SC-002: SLA đỏ 2h | Alert mức ĐỎ mở lúc 10:00 | Đến 12:00 không có lệnh top-up/giảm ngân sách | Auto-escalate TL, timestamp ghi; push MOBILE đã bắn ≤5 phút từ 10:00 | [ ] |
| SC-003: Hành động hợp lệ dừng SLA | Alert ĐỎ đang chạy | Owner tạo lệnh đề xuất top-up trên hệ thống lúc 11:30 | SLA clock dừng, chặng OWNER ghi `acted_at`; alert → RESOLVED sau khi lệnh khớp tiền | [ ] |
| SC-004: Lệnh miệng không dừng SLA | Owner nhắn Zalo "đã chuyển tiền" | 2h hết không có lệnh trên hệ thống | Vẫn escalate TL; tin nhắn ngoài hệ thống không có giá trị | [ ] |
| SC-005: Tạm giữ giải ngân góc FIN | Ví đỏ, khách chậm nạp, có kế hoạch nạp nền tảng tuần | FIN_L2 bật "tạm giữ giải ngân" tương ứng | Giải ngân bị chặn đến khi lệnh nạp khách đạt "Đã khớp tiền"; audit log ghi | [ ] |
| SC-006: Dữ liệu manual | Nền tảng chưa có API, dữ liệu import nhãn `manual` | Job tính ADS | Alert vẫn chạy, hiển thị nhãn nguồn + disclaimer độ trễ; không tính ngày trống thành 0 chi tiêu | [ ] |
| SC-007: Portal isolation | Khách A có ví ĐỔ + escalation nội bộ | Khách A mở Portal xem ví | Thấy số dư + số ngày chi dự kiến tenant mình; không thấy alert nội bộ/SLA/escalation | [ ] |

> **Liên kết:** SC-001→006 map REQ-FIN-002 Mục 2 (A3, BR-FIN-104) + REQ-OPS-003 (BR-OPS-2.3/2.4); SC-007 map REQ-FIN-017.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — SpendMetric, BalanceAlert, EscalationLog | `technical-specs/database-design.md` |
| API Endpoints — alert engine, trạng thái SLA, feed dashboard/push | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW (REQ-FIN-005), MOBILE push, góc OPS (FEAT-CORE-WALLET-007) | `technical-specs/integration-map.md` |
| Màn hình UI (dashboard ví thuộc SYS-BCERP-WEB) | `phase4-ux/bcerp-web/wallet-recon/*.md` |
| Nguồn domain chi tiết — CMS Domain Model v1 | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
