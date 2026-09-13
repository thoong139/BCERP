# Tính Năng: Ví TKQC góc ops — cảnh báo số dư & escalation

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Tài chính — Ví TKQC & Đối Soát (SYS-MOBILE-INTERNAL)
> **Module:** Ví TKQC & Đối Soát (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md` (BR-OPS-2.3/2.4/2.5), `phase1-business/departments/finance/finance.md` (REQ-FIN-002, BR-FIN-104)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/wallet-recon/*.md`, `phase5-implementation/tasks/mobile-internal/wallet-recon/feat-mbi-wallet-006-impl.md`

> **Ghi chú fan-out:** Đây là bản riêng cho **SYS-MOBILE-INTERNAL** của REQ-OPS-003 (REQ xuất hiện ở 6 systems). Counterparts: SYS-CORE-BACKEND (engine cảnh báo + bộ đếm SLA + sổ lệnh), SYS-INTEGRATION-GW (số dư/spend tươi ≤1h, degraded `manual`), SYS-BCERP-WEB (thao tác lệnh chính của OPS_ADS), SYS-PORTAL-WEB/SYS-MOBILE-PORTAL (khách chỉ xem lịch sử điều chỉnh ví — ngoài phạm vi app nội bộ). Touchpoint Mobile nội bộ là **app React Native offline-capable**: bản spec này mô tả trải nghiệm **nhận push alert đỏ và xử lý/duyệt ngoài giờ của đội OPS** — owner hành động đúng SLA ngay trên điện thoại thay vì chờ tới máy tính.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-WALLET-006 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-OPS-003 |
| Người dùng liên quan | OPS_ADS (owner ví — chính), OPS_AM (escalation chặng AM), OPS_PLAN/OPS_CONT (đại diện vai TL trong escalation), OPS_DES/OPS_EDIT (theo phân ca trực), CROSS FIN_L1/FIN_L2 (đầu vào ngưỡng) |
| Độ ưu tiên | Cao (HIGH · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-WALLET-002 (engine cảnh báo 3 mức + bộ đếm SLA trên Core); REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN (bản FIN mobile tại FEAT-MBI-WALLET-002); GW số dư/spend tươi ≤1h |
| Ghi chú Expert (A7) | Dept doc operations.md có cấu trúc A7; phần review chưa thực hiện chính thức. Hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình — ngưỡng VND/ngày theo cấp Junior/Mid/Senior `[CẦN CHỐT SỐ]`, không tự quyết; ca trực Critical on-call SLA 4h ngoài giờ đã chốt theo DI-005 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa góc vận hành của ví TKQC lên Mobile nội bộ cho đội OPS — chủ yếu OPS_ADS làm owner ví, OPS_AM giữ quan hệ khách — để nhận push cảnh báo số dư 3 mức ngay khi phát hiện và **xử lý đúng SLA đỏ 2h làm việc ngay trên điện thoại** (tạo lệnh đề xuất top-up hoặc giảm ngân sách), kể cả ngoài giờ qua kênh on-call. Hệ thống tự động escalation có timestamp từng chặng owner → TL (quá 2h) → AM (quá 4h, chủ động liên hệ khách yêu cầu nạp); app mobile bảo đảm chuỗi phản ứng này không chết vì "không ai ngồi máy tính", đồng thời giữ nguyên mọi quy tắc lệnh ví: cấm lệnh miệng, cấm mượn chéo ví giữa khách.

**Phạm vi:**
- Bao gồm: push alert đỏ/vàng theo khách/TK/nền tảng cho owner và người trực; đề xuất top-up một chạm từ alert (form tối giản lấy sẵn khách/TK/nền tảng/số tiền gợi ý từ số ngày chi dự kiến); giảm ngân sách trong hạn mức theo cấp buyer (vượt hạn mức → chuyển luồng đề xuất chờ duyệt); dashboard rút gọn số dư + "số ngày chi dự kiến" theo platform/khách của mình phụ trách; dòng thời gian escalation có timestamp từng chặng; chế độ on-call ngoài giờ — push tới người trực và cho phép thao tác như owner được ủy trong ca; trạng thái xử lý của alert (đã có hành động — chờ khớp tiền); cache offline danh sách cảnh báo kèm nhãn thời điểm.
- Không bao gồm: tính ADS/phân mức/đếm SLA (Core); khớp tiền và duyệt lệnh nạp (FIN — kênh Web; đề xuất của OPS chỉ là đầu vào); hoàn tiền, điều chỉnh số dư, đổi tỷ giá (FIN dual approval — FEAT-MBI-WALLET-003); khách xem lịch sử điều chỉnh ví (SYS-PORTAL-WEB/SYS-MOBILE-PORTAL — khách KHÔNG dùng app nội bộ này); sửa số dư thủ công bất kỳ mục đích nào (nghiêm cấm — chỉ FIN qua dual approval).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS (owner ví) | Nhận push đỏ trên điện thoại khi một TK đang chạy của mình sắp hết quỹ (<1 ngày chi) | Phản ứng ngay trong khung 0–2h kể cả khi đang ngoài văn phòng, tránh die campaign |
| 2 | OPS_ADS (owner ví) | Tạo lệnh đề xuất top-up một chạm từ alert với khách/TK/số tiền gợi ý đã điền sẵn | Không phải mò lại màn hình Web giữa lúc gấp — lệnh vẫn đúng chuẩn hệ thống, FIN chấp nhận đối chiếu |
| 3 | OPS_ADS (owner ví) | Giảm ngân sách ngay trong hạn mức theo cấp buyer của mình khi khách chưa kịp nạp | Kéo dài số ngày chi được như SLA yêu cầu mà không cần đợi duyệt cho mức trong hạn mức |
| 4 | OPS_AM | Nhận escalation khi alert quá 4h và thấy lịch sử các chặng owner → TL đã làm gì | Chủ động liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày |
| 5 | OPS_PLAN/OPS_CONT (TL ca trực) | Nhận push escalation chặng TL và xem toàn bộ alert đỏ của team kèm đồng hồ SLA | Phân bổ lại việc khi owner vắng, can thiệp trước khi quá 2h; on-call ngoài giờ có người thật nhận |
| 6 | OPS_DES/OPS_EDIT (trực ca) | Nhận alert hộ owner khi mình trực ca và owner không phản hồi | Không có khoảng trống người xử lý trong ca on-call — alert luôn có một người chịu trách nhiệm hiện hành |
| 7 | OPS_AM | Xem trạng thái alert đã được "hạ nhiệt" khi FIN khớp tiền lệnh nạp | Biết vòng xử lý đã khép để ngừng nhắc khách, có timestamp làm căn cứ báo cáo |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — engine cảnh báo và SLA nằm ở Core; mobile là kênh nhận + hành động lệnh hợp lệ (đề xuất top-up/giảm ngân sách), mọi vi phạm bị chặn ở API kể cả khi UI bị bỏ qua.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-W01 | Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS §3.5/3.8). Alert và số ngày chi dự kiến tính trên ví/tiền tệ gốc từng TK — mobile hiển thị không quy đổi gộp | Hiển thị alert theo tổng quy đổi → bug; render nguyên dữ liệu Core theo tiền tệ gốc |
| BR-W02 | Công thức topup `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`, NET/GROSS 2 chiều (CMS §5): khi tạo đề xuất top-up từ alert, số tiền gợi ý do Core tính theo công thức từ số ngày chi cần kéo dài — mobile hiển thị breakdown phí theo snapshot fee % hiện hành của Contract | Mobile không tự tính k; breakdown hiển thị lấy từ API tính gợi ý của Core; sai lệch Web → chặn release |
| BR-W03 | Cảnh báo 3 mức per TK/platform (BR-OPS-2.3): **Xanh** (đủ chi ≥3 ngày — không hành động), **Vàng** (<3 ngày — owner lập kế hoạch nạp, thông báo AM), **Đỏ** (<1 ngày hoặc dưới mức tối thiểu platform — vào SLA đỏ). Dữ liệu GW tươi ≤1h, degraded `manual` kèm disclaimer độ trễ (DI-007). Mobile phân biệt mức bằng push: Đỏ push ngay, Vàng push thụ động | Push sai mức/sót Đỏ → lỗi khối push; degraded bắt buộc gắn disclaimer trên màn chi tiết |
| BR-W04 | **SLA đỏ 2h + escalation có timestamp** (BR-OPS-2.4): 0–2h owner (OPS_ADS) phải tạo lệnh đề xuất top-up **hoặc** giảm ngân sách trên hệ thống; quá 2h → escalate TL (OPS_PLAN/OPS_CONT đại diện); quá 4h → escalate AM (chủ động liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày); ngoài giờ → kênh on-call TL (on-call SLA 4h ngoài giờ theo DI-005). Mỗi chặng ghi timestamp tự động | Mobile hiển thị chặng hiện tại + đồng hồ giờ làm việc; alert không thể "hạ nhiệt" mà không có hành động thật trên lệnh — không có nút đóng alert thủ công |
| BR-W05 | Quy tắc lệnh ví (BR-OPS-2.5): mọi top-up/refund/điều chỉnh **chỉ qua lệnh hệ thống** — cấm xác nhận miệng Zalo/điện thoại/email riêng; OPS_ADS nhận alert đỏ chỉ được nạp thêm qua lệnh, **cấm mượn chéo ví giữa khách** (không dùng tiền khách khác đắp ví); app không có tính năng "chia sẻ lệnh qua chat nội bộ có giá trị đối chiếu" | Form đề xuất khóa cứng khách/TK nguồn tiền — không thể chọn ví khách khác làm nguồn; cố gọi API đắp chéo → Core từ chối `CROSS_WALLET_DENIED` + log |
| BR-W06 | Dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền (CMS §3.6): OPS **không có** bất kỳ quyền nào trong 3 nhóm này — bản mobile OPS chỉ thấy trạng thái "chờ FIN xử lý" của lệnh mình đề xuất | App OPS không hiển thị nút duyệt nào thuộc luồng FIN; mọi API duyệt gọi từ vai OPS → Core từ chối theo RBAC |
| BR-W07 | Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0/0,5%·10USD/1%·20USD, chốt & khóa kỳ (REQ-FIN-004 — counterpart Core/Web): OPS không thao tác đối soát; khi alert liên quan chênh lệch đối soát, mobile chỉ hiển thị nhãn "đang đối soát — FIN xử lý" | Mobile OPS không mở ticket discrepancy hay nhập số đối soát; hiển thị hướng dẫn chuyển FIN |
| BR-W08 | AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn (REQ-FIN-010 — FEAT-MBI-WALLET-005); Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS §3.10): lệnh top-up của OPS cũng chịu chấm điểm AML — nếu bị hold, alert hiển thị "lệnh đang hold AML — FIN xử lý" và không đếm là hành động hạ nhiệt alert số dư | Lệnh hold AML không tự động coi alert số dư đã xử lý; đồng hồ SLA tiếp tục — hiển thị đúng trạng thái kèm cảnh báo |
| BR-W09 | Hạn mức đổi ngân sách ngày theo cấp buyer do TL cấu hình — ngưỡng VND/ngày theo cấp Junior/Mid/Senior `[CẦN CHỐT SỐ]`: trong hạn mức → giảm ngân sách trực tiếp có hiệu lực ngay; vượt hạn mức → chặn giảm trực tiếp, chỉ cho gửi đề xuất chờ duyệt TL | Form giảm ngân sách kiểm tra hạn mức theo profile người dùng; vượt hạn chỉ có nút "gửi đề xuất" — API từ chối giảm trực tiếp |
| BR-W10 | Portal chỉ đọc số dư ví (REQ-FIN-017) — **tenant isolation**: CUSTOMER không dùng app nội bộ; khách chỉ xem lịch sử điều chỉnh ví của mình qua Portal/M-PORTAL (trường gắn giá vốn mask thành "điều chỉnh đối soát", read-only tuyệt đối). App OPS không gửi bất kỳ thông tin nào ra biên khách, và không cho OPS xem thông tin giá vốn ngoài phần cần cho lệnh ví | Phát hiện push/thông tin ra thiết bị khách → sự cố bảo mật; giá vốn chỉ hiển thị ở ngữ cảnh tạo lệnh do phân quyền cho phép |
| BR-W11 | Offline: danh sách alert + dashboard rút gọn cache kèm nhãn "cập nhật lúc HH:MM"; khi offline không cho tạo lệnh/giảm ngân sách (hành động ghi cần online — chống lệnh trùng/kém dữ liệu); đồng hồ SLA freeze kèm nhãn giá trị tại thời điểm sync | Không có hàng đợi lệnh "gửi sau" khi offline; cố submit offline → chặn với thông báo cần kết nối |
| BR-W12 | Quyền hành động theo ca trực: khi owner không phản hồi và alert escalate lên TL, người trực (OPS_DES/OPS_EDIT theo phân ca) được ủy hành động như owner **trong ca** — mọi hành động ghi nhãn "theo ủy quyền ca #id"; kết thúc ca ủy quyền tự hết hiệu lực | Hành động ngoài ca không có ủy quyền → chặn; log ủy quyền append-only cho TL rà |

**Giả định chờ xác nhận:** ngưỡng hạn mức đổi ngân sách ngày theo cấp buyer `[CẦN CHỐT SỐ]` — TL cấu hình, không tự quyết trong spec; danh sách "mức tối thiểu nền tảng" per platform lấy từ cấu hình Core. 11 KXN còn mở (`[KXN-6]`/`[KXN-7]`/`[KXN-9]`/`[KXN-15]`–`[KXN-22]`) thuộc domain CRM/lifecycle — không tác động rule cảnh báo ví của spec này, không tự quyết.

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Owner = OPS_ADS gán theo khách/TK; vai TL trong escalation đại diện bởi OPS_PLAN/OPS_CONT theo quy ước registry; CUSTOMER không truy cập app nội bộ — cột đặt để chốt biên.

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN/OPS_CONT (TL ca) | OPS_DES/OPS_EDIT (trực ca) | FIN_L1/FIN_L2 | CUSTOMER |
|-----------|---------|--------|---------------------------|----------------------------|---------------|----------|
| Nhận push alert ví khách mình phụ trách | ✅ | ✅ (khách mình giữ) | ✅ (toàn team) | ✅ (alert hộ khi trực ca) | ❌ (bản FIN — FEAT-002) | ❌ |
| Xem dashboard số dư + số ngày chi dự kiến | ✅ | ✅ (khách mình giữ) | ✅ (toàn team) | ✅ (trong ca) | ✅ | ❌ |
| Đề xuất top-up một chạm từ alert | ✅ (owner) | ✅ | ❌ | ✅ (theo ủy quyền ca) | ❌ (tạo ở workspace FIN nếu cần) | ❌ |
| Giảm ngân sách trong hạn mức cấp | ✅ | ❌ | ✅ (duyệt phê giảm vượt hạn mức ops) | ✅ (theo ủy quyền ca) | ❌ | ❌ |
| Gửi đề xuất vượt hạn mức | ✅ | ❌ | ❌ (nhận duyệt) | ✅ (theo ủy quyền ca) | ❌ | ❌ |
| Nhận escalation chặng TL/AM | ❌ (chặng owner) | ✅ (chặng AM) | ✅ (chặng TL) | ❌ | ❌ | ❌ |
| Phân bổ lại owner ví khi vắng | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Khớp tiền / duyệt lệnh / hoàn tiền / điều chỉnh ví | ❌ | ❌ | ❌ | ❌ | ✅ (kênh Web — FEAT-001/003) | ❌ |
| Xem giá vốn/chiết khấu/P&L | ❌ | ❌ | ❌ | ❌ | ✅ (theo phân quyền FIN) | ❌ (Portal mask giá vốn) |
| Xem lịch sử điều chỉnh ví khách | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (chỉ qua Portal/M-PORTAL, read-only, mask) |

---

## 5. Trường Hợp Đặc Biệt

- **Alert đỏ ngoài giờ làm việc:** escalation chuyển kênh on-call TL (on-call SLA 4h ngoài giờ theo DI-005); đồng hồ SLA tính giờ làm việc — app hiển thị "ngoài giờ — on-call đã nhận"; lệnh vẫn phải tạo trên hệ thống, approval không bỏ qua.
- **Owner nghỉ phép/vắng dài ngày:** TL phân bổ lại owner ví trên Web/Core; app của owner mới nhận push từ lúc phân bổ lại; lịch sử chặng cũ giữ nguyên để không mất dấu vết trách nhiệm.
- **Khách chậm nạp dù đã escalate AM:** FIN_L1 đánh dấu rủi ro gián đoạn chi tiêu; FIN_L2 tạm giữ phần giải ngân nạp nền tảng tương ứng (BR-FIN-104 exception) — app OPS hiển thị trạng thái "đã giữ giải ngân — chờ tiền khách" để OPS không hứa sai với khách.
- **Nhiều TK cùng khách cùng đỏ:** app gộp nhóm alert theo khách tránh bão push nhưng vẫn cho phép hành động từng TK riêng; đề xuất top-up hỗ trợ gộp nhiều TK vào một lệnh theo chuẩn lệnh hệ thống (đủ khách/TK/số tiền/tiền tệ/căn cứ từng dòng).
- **Lệnh đề xuất bị FIN từ chối:** alert quay về trạng thái chờ hành động, đồng hồ SLA tiếp tục từ mốc cũ (không reset); OPS_ADS nhận lý do từ chối để điều chỉnh đề xuất — bắt buộc hành động thật mới hạ nhiệt alert.
- **Thiết bị trực ca dùng chung:** thiết bị on-call đăng ký riêng gắn ca trực; khi đổi ca, push tự chuyển sang thiết bị người trực kế nhiệm; cache thiết bị cũ bị xóa khi ca kết thúc — không để dữ liệu khách nằm lại thiết bị cá nhân.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Alert số dư góc OPS (cùng entity alert với FEAT-MBI-WALLET-002, hành động phía OPS) + Lệnh đề xuất top-up.

**Sơ đồ trạng thái:**
```
[MỚI] ──(owner: tạo lệnh top-up/giảm ngân sách)──► [ĐÃ CÓ HÀNH ĐỘNG] ──(lệnh "Đã khớp tiền" — FIN)──► [ĐÃ XỬ LÝ]
   │                                                        │
   │ (quá 2h)                                               │ (lệnh bị reject/hủy)
   ▼                                                        ▼
[ESCALATED — TL] ──(quá 4h)──► [ESCALATED — AM]              [MỚI — đồng hồ tiếp tục, có lý do từ chối hiển thị]
   │
   └─(ngoài giờ)──► [ON-CALL — TL trực nhận] ──(hành động trong ca)──► [ĐÃ CÓ HÀNH ĐỘNG]
```

**Bảng chuyển đổi (mobile là kênh hành động hợp lệ cho owner/người ủy quyền ca):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `MỚI` | Tạo lệnh đề xuất top-up (một chạm từ alert) | `ĐÃ CÓ HÀNH ĐỘNG` | OPS_ADS owner / người ủy quyền ca | Lệnh hợp lệ qua API Core; ghi danh tính + kênh MOBILE |
| `MỚI` | Giảm ngân sách trong hạn mức | `ĐÃ CÓ HÀNH ĐỘNG` | OPS_ADS owner (đúng cấp buyer) | Không vượt hạn mức; hiệu lực ngay |
| `MỚI` | Quá 2h không hành động | `ESCALATED — TL` | Hệ thống (Core auto-escalate) | Timestamp chặng owner khóa |
| `ESCALATED — TL` | Quá 4h không hành động | `ESCALATED — AM` | Hệ thống (Core auto-escalate) | AM liên hệ khách trong ngày làm việc, thông báo khách trong cùng ngày |
| `ESCALATED — TL/AM` | Người ủy quyền ca hành động | `ĐÃ CÓ HÀNH ĐỘNG` | Người trực theo ủy quyền ca | Log nhãn "theo ủy quyền ca #id" |
| `ĐÃ CÓ HÀNH ĐỘNG` | Lệnh bị FIN reject/hủy | `MỚI` | Hệ thống (theo trạng thái lệnh) | Đồng hồ tiếp tục từ mốc cũ; hiển thị lý do từ chối |
| `ĐÃ CÓ HÀNH ĐỘNG` | Lệnh về "Đã khớp tiền" | `ĐÃ XỬ LÝ` | Core (theo vòng lệnh nạp) | Alert đóng; lịch sử chặng giữ nguyên |

**Quy tắc:**
- Không có nút "đóng alert" thủ công — hạ nhiệt chỉ khi có hành động thật trên lệnh hoặc Core xác nhận tiền đã về.
- `ĐÃ XỬ LÝ` là trạng thái kết thúc; toàn bộ chặng timestamp được lưu phục vụ rà SLA của TL và báo cáo định kỳ.
- Giảm mức alert (Đỏ → Vàng → Xanh) chỉ do Core tính lại theo dữ liệu mới — mobile không cho người dùng tự đổi mức.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity mobile tiêu thụ/tương tác — nguồn sự thật thuộc Core (`technical-specs/database-design.md`).*

| Entity (Core nguồn) | Fields chính mobile tiêu thụ | Quan hệ | Ghi chú mobile |
|---------------------|------------------------------|---------|----------------|
| `WalletBalanceAlert` | `level`, `days_of_runway`, `ads_7d`, `status`, `escalation_stage`, `assigned_owner` | FK → `wallets.id`, `ad_accounts.id` | Alert gộp theo khách khi hiển thị; hành động từng TK |
| `EscalationStep` | `stage` (OWNER/TL/AM/ON_CALL), `notified_user_id`, `at` | FK → `wallet_balance_alerts.id` | Dòng thời gian timestamp từng chặng |
| `RechargeRequest` (đề xuất) | `customer_id`, `ad_account_id`, `amount`, `currency`, `suggested_breakdown`, `status` | FK → `customers.id`, `ad_accounts.id` | Form một chạm lấy sẵn từ alert; breakdown từ công thức k |
| `BuyerBudgetChange` (giảm ngân sách) | `ad_account_id`, `amount`, `buyer_level`, `within_limit`, `authorization_ref` | FK → `ad_accounts.id` | Kiểm tra hạn mức theo cấp; log ủy quyền ca |
| `OnCallShift` | `user_id`, `device_id`, `from`, `to`, `role_scope` | Gắn ca trực | Nền tảng ủy quyền hành động trong ca |
| `OfflineCache` (client-side) | `synced_at`, `payload`, `device_id` | Gắn thiết bị | Chỉ đọc khi offline; hành động ghi cần online |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push đỏ tới owner | TK khách A về mức Đỏ sau lần sync | Core phát hiện | OPS_ADS owner nhận push trong vài phút, mở được chi tiết alert | [ ] |
| SC-002: Đề xuất top-up một chạm | Alert đỏ đang mở | Bấm "đề xuất top-up" | Form điền sẵn khách/TK/nền tảng + số tiền gợi ý kèm breakdown công thức k từ Core; gửi thành lệnh hợp lệ | [ ] |
| SC-003: Giảm ngân sách trong hạn mức | OPS_ADS cấp Senior với hạn mức cấu hình | Giảm ngân sách ≤ hạn mức | Hiệu lực ngay; alert chuyển "ĐÃ CÓ HÀNH ĐỘNG"; log ghi đủ | [ ] |
| SC-004: Vượt hạn mức chỉ gửi đề xuất | Giảm vượt hạn mức cấp buyer | Thử giảm trực tiếp | API từ chối; app chỉ cho "gửi đề xuất chờ duyệt TL" | [ ] |
| SC-005: Cấm đắp chéo ví | Khách A đỏ, khách B còn dư | Cố chọn nguồn tiền ví khách B | Form không cho chọn; API từ chối `CROSS_WALLET_DENIED` + log vi phạm | [ ] |
| SC-006: Escalation đúng chặng | Alert không có hành động 2h rồi 4h | Xem dòng thời gian | Chặng TL xuất hiện quá 2h, chặng AM quá 4h, đủ timestamp; OPS_AM nhận push chặng AM | [ ] |
| SC-007: On-call ngoài giờ nhận alert | Alert phát 22h ngoài giờ | Kiểm tra thiết bị người trực | Người on-call nhận push; app hiển thị "ngoài giờ — on-call đã nhận"; hành động ghi nhãn ủy quyền ca | [ ] |
| SC-008: Offline freeze + cấm ghi | App offline với alert đang mở | Xem và thử thao tác | Đồng hồ freeze kèm nhãn sync; mọi nút ghi bị chặn "cần kết nối mạng" | [ ] |
| SC-009: Lệnh hold AML không hạ nhiệt alert | Lệnh top-up đề xuất bị hold AML | Kiểm tra alert số dư | Alert giữ trạng thái chờ hành động; hiển thị "lệnh đang hold AML — FIN xử lý"; đồng hồ tiếp tục | [ ] |
| SC-010: Khách không vào app nội bộ | Tenant khách tồn tại | Kiểm tra toàn bộ luồng app | Không có tài khoản/luồng nào cho CUSTOMER; lịch sử điều chỉnh ví khách chỉ qua Portal/M-PORTAL mask giá vốn | [ ] |

> **Liên kết:** SC-001→007, 009 map REQ-OPS-003 (BR-OPS-2.3/2.4/2.5); SC-008 map ràng buộc touchpoint mobile; SC-010 map REQ-FIN-017 (biên tenant, mask giá vốn).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — WalletBalanceAlert, EscalationStep, OnCallShift (nguồn Core) | `technical-specs/database-design.md` |
| API Endpoints — alert feed OPS, create recharge suggestion, budget change (hạn mức), on-call registry | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — GW freshness ≤1h, biên OPS/FIN, Portal mask giá vốn, counterparts | `technical-specs/integration-map.md` |
| Màn hình UI — mobile-internal/wallet-recon (alert list OPS, one-tap topup, on-call states) | `phase4-ux/mobile-internal/wallet-recon/*.md` |
| Nguồn domain chi tiết — policy `kiem-soat-vi-tkqc-giao-dich-tien.md` §2.1–2.3 | `documents/02_Quy_trinh_Cho_thue_TKQC.md` |
