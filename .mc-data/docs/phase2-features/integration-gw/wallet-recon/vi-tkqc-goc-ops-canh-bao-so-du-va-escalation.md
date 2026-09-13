# Tính Năng: Ví TKQC Góc Ops — Cảnh Báo Số Dư & Escalation

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Tích hợp Gateway (SYS-INTEGRATION-GW)
> **Module:** Ví TKQC & Đối Trừ (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md` (REQ-FIN-002), `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp theo REQ-ID gốc:
> `REQ-OPS-003` → `FEAT-GW-WALLET-002` — bản dành riêng cho **SYS-INTEGRATION-GW**.
> REQ-OPS-003 xuất hiện ở 6 systems (SYS-CORE-BACKEND, SYS-INTEGRATION-GW, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL, SYS-PORTAL-WEB, SYS-MOBILE-PORTAL); bản counterpart viết riêng ở lane tương ứng, không gộp trong file này.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-WALLET-002 |
| Module | MOD-WALLET-RECON (SYS-INTEGRATION-GW) |
| Yêu cầu nghiệp vụ | REQ-OPS-003 (Ví TKQC góc ops — cảnh báo số dư & escalation); cross-dependency: REQ-FIN-002 (Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h) — ngưỡng cảnh báo nguồn FIN |
| Người dùng liên quan | OPS_ADS (owner ví), OPS_AM, OPS_PLAN, OPS_CONT/OPS_DES/OPS_EDIT (view), CUSTOMER (Portal), SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (GĐ2 · Phase 2 triển khai) |
| Phụ thuộc | REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN (cross-dependency theo lane); tiền đề kỹ thuật: REQ-FIN-001 (sổ phụ ví), REQ-FIN-005 (API + degraded mode `manual`) |
| Ghi chú Expert (A7) | `operations.md` Mục A7 chờ review; điểm đối chiếu chéo đã ghi nhận: REQ-OPS-003 phối hợp FIN (ngưỡng, khớp tiền), REQ-OPS-007 ranh giới HR, REQ-OPS-004 phối hợp Sales |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Giúp đội OPS biết trước ví TKQC nào sắp hết quỹ để chủ động xin khách nạp trước khi campaign gián đoạn: cảnh báo 3 mức theo số ngày chi dự kiến, SLA đỏ 2h làm việc với escalation tự động có timestamp từng chặng, mọi hành động xử lý (top-up, giảm ngân sách) chỉ qua lệnh hệ thống. Ở touchpoint SYS-INTEGRATION-GW, tính năng chịu trách nhiệm đảm bảo dữ liệu số dư/spend đưa vào cảnh báo là tươi ≤1h, đáng tin và không đứt gãy: adapter pull hourly từ 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), gắn nhãn nguồn `api`/`manual`, tự chuyển degraded mode `manual` + backfill khi mất API hoặc connector lỗi.

**Phạm vi:**
- Bao gồm: đồng bộ số dư/spend hourly per TK/platform qua batch/queue chống rate limit; nhãn nguồn và độ trễ dữ liệu cấp cho engine cảnh báo (CORE) và dashboard (WEB); degraded mode `manual` khi connector lỗi/chưa cấp quyền API, kèm backfill khi API sống lại; dữ liệu lịch sử điều chỉnh ví lọc tenant + mask giá vốn cho Portal/Mobile Portal (REQ-FIN-017); API rút gọn cho mobile nội bộ push alert; cấu hình adapter vendor-agnostic qua Settings.
- Không bao gồm: tính average daily spend 7 ngày rolling, phân mức Xanh/Vàng/Đỏ, bộ đếm SLA đỏ và auto-escalation — bản SYS-CORE-BACKEND (counterpart, REQ-FIN-002/REQ-OPS-003); dashboard ví và luồng tạo lệnh top-up chính của OPS_ADS — bản SYS-BCERP-WEB; khớp tiền và ghi sổ phụ ví của FIN; điều chỉnh ngân sách campaign (MOD-CAMPAIGN-DELIVERABLE).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS (owner ví) | Nhận alert đỏ kèm "số ngày chi dự kiến" cập nhật từ số dư/spend tươi ≤1h và đề xuất top-up một chạm ngay từ alert | Hành động trong SLA 2h trước khi TKQC die, không gõ lại số, không sai lệch giữa cảnh báo và lệnh |
| 2 | OPS_ADS | Biết dữ liệu nào đang nhãn `manual` (connector lỗi) trên alert/dashboard | Không quyết định nạp trên số kém tin cậy |
| 3 | OPS_AM | Nhận escalate khi alert đỏ quá 4h chưa xử lý, kèm thông tin ví và khách | Chủ động liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách cùng ngày |
| 4 | OPS_PLAN (Strategic Planner kiêm quyền TP — vai escalation cấp trung gian) | Nhận escalate chặng 2h và xem dashboard tình trạng cảnh báo toàn nhóm | Đôn đốc owner kịp SLA, không để alert treo, không nghẽn phê duyệt |
| 5 | CUSTOMER (qua Portal/Mobile Portal) | Xem lịch sử điều chỉnh ví và số dư của tenant mình, read-only | Tự theo dõi minh bạch mà không cần hỏi AM, không thấy giá vốn |
| 6 | SYS_ADMIN | Cấu hình/monitor connector số dư từng nền tảng và trạng thái degraded | Phát hiện nguồn dữ liệu lỗi trước khi ảnh hưởng cảnh báo |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Ngưỡng cảnh báo nguồn FIN theo REQ-FIN-002 (cross-dependency). Nguồn: `documents/02_Quy_trinh_Cho_thue_TKQC.md` và `operations.md` Phần B (BR-OPS-2.3–2.5).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Ví giữ hộ per-khách multi-currency:** mỗi khách một ví riêng tách theo `currency` (USD/VND không gộp quy đổi — CMS §3.5); mọi top-up/refund/điều chỉnh chỉ qua **lệnh giao dịch tiền** trên hệ thống — cấm xác nhận miệng Zalo/điện thoại/email, FIN từ chối đối chiếu lệnh miệng; OPS_ADS nhận alert đỏ chỉ được nạp thêm qua lệnh, **cấm mượn chéo ví** giữa khách; snapshot fee % (`feePercent/vatOnFeePercent/vatOnSpendPercent`) lưu tại thời điểm giao dịch, không tham chiếu sống tới Contract (CMS §3.8) | Lệnh miệng không có giá trị đối chiếu; dùng chéo ví → chặn lệnh, cảnh báo FIN_L2 + quản lý nhóm |
| BR-002 | **Công thức topup:** `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`; 2 chiều NET/GROSS — nhập NSQC → trừ ví `netAmount × k`, nhập Tổng tiền → vào AdAccount `grossAmount / k` (CMS §5); số tiền lệnh đề xuất top-up sinh từ alert tính theo đúng công thức với snapshot fee đang áp dụng | Preview không khớp ngược → chặn tạo lệnh, báo lỗi tính toán |
| BR-003 | **Cảnh báo 3 mức theo số ngày chi dự kiến:** engine (CORE) tính average daily spend 7 ngày rolling per TK/platform; **Xanh** (đủ chi ≥3 ngày — không hành động) / **Vàng** (<3 ngày — owner lập kế hoạch nạp, thông báo AM) / **Đỏ** (<1 ngày hoặc dưới mức tối thiểu platform — vào SLA đỏ); ngưỡng nguồn FIN theo REQ-FIN-002, cấu hình được | GW cấp số sai độ trễ >1h mà không gắn nhãn → dữ liệu đánh dấu kém tin cậy, dashboard cảnh báo độ trễ |
| BR-004 | **SLA đỏ 2h + escalation có timestamp:** 0–2h làm việc — owner (OPS_ADS) phải tạo **lệnh đề xuất top-up** hoặc **giảm ngân sách** trên hệ thống; quá 2h → escalate OPS_PLAN; quá 4h → escalate OPS_AM — AM liên hệ khách yêu cầu nạp trong ngày làm việc, thông báo khách trong cùng ngày; ngoài giờ escalate kênh on-call, **lệnh vẫn phải tạo trên hệ thống, approval không bỏ qua**; mỗi chặng ghi timestamp | Thiếu timestamp chặng → escalation không coi là hoàn tất; alert đỏ không owner → tự escalate chặng đầu |
| BR-005 | **Dual approval giao dịch rủi ro cao:** điều chỉnh số dư tay / đổi tỷ giá tay / hoàn tiền theo công tắc toàn hệ thống `approvalMode = SINGLE/DUAL` (CMS §3.6): `SINGLE` — một người trong ACCOUNTANT/CHIEF_ACCOUNTANT/CFO (FIN_L1/FIN_L2/BOD_CFO_CTO) duyệt 1 lần; `DUAL` — tuần tự bắt buộc ACCOUNTANT (FIN_L1, bước 1) → CHIEF_ACCOUNTANT (FIN_L2, bước 2), không đảo thứ tự, không một người duyệt cả 2 bước; người đề xuất ≠ người duyệt; SoD 4 vai dòng tiền: đề xuất (OPS_AM/OPS_ADS) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2) ≠ ghi sổ | Thiếu một chữ ký ở DUAL → chặn thực thi; trùng vai trong 1 giao dịch → SoD engine chặn và log nỗ lực vi phạm |
| BR-006 | **Đối trừ 3 số gắn với lệnh nạp:** lệnh top-up từ alert là input đối trừ vế 1 — đối trừ 3 vế (sổ ví ↔ nền tảng ↔ ngân hàng/statement) với dung sai: đối nạp 0/dòng/ngày; chi tiêu ≤0,5% hoặc ≤10 USD/TK/ngày; tích lũy ≤1% hoặc ≤20 USD/khách/tuần (mặc định chốt theo DI-001); vượt dung sai → ticket discrepancy, FIN_L1 giải trình FIN_L2 trước chốt kỳ, cấm tự cân số; chốt kỳ ngày 3 tháng kế (mặc định) và khóa kỳ — chặn sửa/xóa chứng từ, mở kỳ chỉ CFO duyệt phiếu lý do; GW không ghi đè dữ liệu kỳ đã khóa | Lệnh không khớp tiền về → treo "chờ đối chiếu"; tự cân số → bị audit log bắt |
| BR-007 | **AML T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn:** mọi lệnh nạp/hoàn sinh từ cảnh báo chịu chấm điểm rule engine T1–T6 (T4 hoàn đổi beneficiary chặn mặc định); KYC khai báo UBO từ 25% sở hữu thụ hưởng; hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, trả về đúng TK nguồn trùng tên pháp nhân KYC, cấm hoàn bên thứ ba; ngưỡng cấu hình được, EDD siết 50%, cấm tắt monitoring; GW đồng bộ FATF list định kỳ (mặc định chốt theo DI-001) | Giao dịch vi phạm → khóa mềm (hold) đến khi có quyết định điều tra; không có luồng bỏ qua monitoring |
| BR-008 | **Rebate mặc định TẮT:** rebate OFF toàn bộ AdAccount/Contract; Finance bật tay từng trường hợp và nhập tay `rebateAmount` theo kỳ quý, không auto-tính (CMS §3.10); rebate không trừ vào số dư ví dùng cho cảnh báo trừ khi có lệnh điều chỉnh được duyệt | Job tự tính rebate trong GW là vi phạm thiết kế; rebate chưa duyệt không ảnh hưởng số dư cảnh báo |
| BR-009 | **Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation:** khách xem qua view tổng hợp lọc tenant (RLS DB + filter API 2 lớp); chỉ thấy số dư ví, chi tiêu daily, lịch sử điều chỉnh ví mức dành cho khách; trường giá vốn **mask thành "điều chỉnh đối soát"**; KHÔNG thấy giá vốn, chiết khấu, P&L, dữ liệu tenant khác; read-only tuyệt đối — Portal không ghi dữ liệu tài chính; watermark + disclaimer độ trễ (15 phút–24h theo nguồn) | Lộ chéo tenant hoặc endpoint cho Portal ghi dữ liệu → chặn tầng API, audit log vi phạm bảo mật; hiện giá vốn thật cho khách là lỗi nghiêm trọng |
| BR-010 | **Degraded mode `manual` + backfill bắt buộc:** khi connector lỗi hoặc chưa cấp quyền API, GW chuyển nguồn số dư/spend sang import/nhập tay `manual`, dữ liệu đi kèm nhãn nguồn + độ trễ; cảnh báo vẫn chạy trên dữ liệu `manual` (đúng luồng API); khi API sống lại, backfill và đối chiếu số cũ→số mới; ràng buộc thiết kế theo DI-007 — không phụ thuộc 100% API nền tảng | Thiếu chế độ manual → đứt gãy khi mất API là lỗi nghiệm thu; backfill không tái đối chiếu → kỳ giữ nhãn `manual` và cảnh báo |

---

## 4. Phân Quyền

> Touchpoint SYS-INTEGRATION-GW: GW là tầng adapter — quyền dưới đây enforce ở service layer của CORE và chiếu lên web nội bộ (WEB, luồng chính), mobile nội bộ (M-INT, push + xử lý ngoài giờ), Portal/Mobile Portal (CUSTOMER, read-only). Ánh xạ vai CMS: ACCOUNTANT = FIN_L1, CHIEF_ACCOUNTANT = FIN_L2, CFO = BOD_CFO_CTO.

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN | CUSTOMER | SYS_ADMIN |
|-----------|---------|--------|----------|----------|-----------|
| Xem alert + "số ngày chi dự kiến" | ✅ (ví mình phụ trách) | ✅ (portfolio) | ✅ (toàn nhóm) | ❌ | ✅ (vận hành) |
| Xem trạng thái nguồn `api`/`manual` + độ trễ | ✅ | ✅ | ✅ | ❌ (chỉ disclaimer độ trễ) | ✅ |
| Tạo lệnh đề xuất top-up từ alert (một chạm) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Giảm ngân sách trong hạn mức ngày theo cấp buyer | ✅ | ✅ | ✅ (duyệt vượt hạn mức) | ❌ | ❌ |
| Xử lý/duyệt ngoài giờ qua mobile nội bộ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Nhận escalation (chặng 2h / chặng 4h) | ❌ (người bị escalate) | ✅ (chặng 4h) | ✅ (chặng 2h) | ❌ | ❌ |
| Duyệt điều chỉnh số dư / tỷ giá tay / hoàn tiền (dual approval) | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ FIN_L1→FIN_L2/BOD theo BR-005) |
| Cấu hình ngưỡng Xanh/Vàng/Đỏ (nguồn FIN) | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi, FIN phê duyệt) |
| Cấu hình connector số dư + kích hoạt backfill | ❌ | ❌ | ❌ | ❌ | ✅ |
| Xem số dư ví + lịch sử điều chỉnh tenant mình (masked, read-only) | ❌ | ❌ | ❌ | ✅ (Portal/Mobile Portal) | ❌ |
| Ghi dữ liệu tài chính từ Portal | ❌ | ❌ | ❌ | ❌ (read-only tuyệt đối) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Connector nền tảng lỗi giữa ngày:** GW giữ dữ liệu sync gần nhất, đánh dấu `manual`/stale kèm độ trễ; engine cảnh báo vẫn chạy trên số cũ nhưng dashboard hiển thị disclaimer; khi connector hồi phục, backfill đối chiếu — nếu số ngày chi đổi mức thì alert bắn lại theo số mới, không triệt tiêu alert cũ im lặng.
- **Nền tảng chưa cấp quyền API (DI-007):** số dư/spend nhập theo chu kỳ manual; SLA đỏ 2h vẫn áp dụng cho owner trên dữ liệu manual, alert gắn nhãn rõ độ tin cậy.
- **Alert đỏ ngoài giờ hành chính:** escalate qua kênh on-call; owner vẫn phải tạo lệnh trên hệ thống (mở từ mobile nội bộ offline-capable) — "khách hứa chuyển tiền" không có giá trị mở khóa.
- **Khách có nhiều ví đa tiền tệ (USD/VND):** cảnh báo tính riêng từng ví theo tiền tệ, không quy đổi gộp; ví USD <1 ngày và VND đủ 5 ngày → chỉ ví USD vào Vàng/Đỏ.
- **Khách xem Portal trong lúc có tranh chấp số dư:** hiển thị trạng thái "Đang đối soát" thay vì con số chưa xác nhận; điều chỉnh đang chờ dual approval hiển thị ở lịch sử kèm trạng thái, không hiện số tạm.
- **Giới hạn scope nguồn gốc CMS `[KXN-9]`:** phạm vi "tương lai" của CMS trong tài liệu gốc chưa chốt (KXN-9 còn mở) — tính năng chỉ triển khai theo REQ-OPS-003/REQ-FIN-002 trong req-registry, không tự suy diễn thêm kênh cảnh báo hay touchpoint ngoài 6 systems đã đăng ký. Các KXN còn mở khác (6, 7, 15–22) thuộc SALES/OPS lifecycle, đã rà và không ảnh hưởng tính năng này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity chính:** Cảnh báo số dư ví (Wallet Alert) và lệnh đề xuất top-up (Top-up Request, theo CMS §3.6).

**Sơ đồ trạng thái (Wallet Alert):**
```
[XANH] ──(số ngày chi <3)──► [VÀNG] ──(<1 ngày / dưới mức tối thiểu)──► [ĐỎ]
[ĐỎ] ──(0–2h, owner tạo lệnh top-up hoặc giảm ngân sách)──► [ĐÃ HÀNH ĐỘNG]
[ĐỎ] ──(quá 2h)──► [ESCALATED — OPS_PLAN] ──(quá 4h)──► [ESCALATED — OPS_AM]
[ĐÃ HÀNH ĐỘNG / ESCALATED] ──(tiền nạp khớp lệnh, ví về Xanh)──► [ĐÃ GIẢI QUYẾT]
```

**Sơ đồ trạng thái (Top-up Request — chế độ DUAL):**
```
[PENDING] ──(bước 1: ACCOUNTANT)──► [STEP1_APPROVED] ──(bước 2: CHIEF_ACCOUNTANT)──► [APPROVED]
   │ (từ chối)                              │ (khách khiếu nại)
   ▼                                        ▼
[REJECTED] ───────────────────────► [DISPUTED] → quay lại review
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `XANH` | Số ngày chi <3 | `VÀNG` | Hệ thống (CORE engine) | ADS 7 ngày rolling cập nhật; dữ liệu GW ≤1h |
| `VÀNG` | Số ngày chi <1 hoặc dưới mức tối thiểu platform | `ĐỎ` | Hệ thống (CORE engine) | Ngưỡng nguồn FIN (REQ-FIN-002) |
| `ĐỎ` | Owner tạo lệnh top-up / giảm ngân sách | `ĐÃ HÀNH ĐỘNG` | OPS_ADS | Lệnh đủ khách/TKQC/số tiền/tiền tệ/căn cứ + timestamp |
| `ĐỎ` | Quá 2h không phản hồi | `ESCALATED — OPS_PLAN` | Hệ thống (auto) | Timestamp chặng 1 ghi tự động |
| `ESCALATED — OPS_PLAN` | Quá 4h không xử lý | `ESCALATED — OPS_AM` | Hệ thống (auto) | AM liên hệ khách trong ngày làm việc |
| `ĐÃ HÀNH ĐỘNG`/`ESCALATED` | Tiền về, FIN_L1 xác nhận khớp, ví về ≥Xanh | `ĐÃ GIẢI QUYẾT` | Hệ thống | Lệnh ở `APPROVED`; GW cập nhật số dư mới |
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (ACCOUNTANT) | Người duyệt ≠ người đề xuất |
| `STEP1_APPROVED` | Duyệt bước 2 | `APPROVED` | FIN_L2 (CHIEF_ACCOUNTANT) | Không đảo thứ tự, không trùng người bước 1 |
| `PENDING`/`STEP1_APPROVED` | Từ chối | `REJECTED` | FIN_L1/FIN_L2/BOD tùy chế độ | Ghi lý do; khách khiếu nại → `DISPUTED` quay lại review |

**Quy tắc:**
- `ĐÃ GIẢI QUYẾT` là trạng thái kết thúc; ví tái suy giảm → alert chu kỳ mới, liên kết lịch sử.
- Chế độ `SINGLE` (CMS §3.6): `PENDING → APPROVED/REJECTED` một bước bởi vai FIN trong nhóm duyệt; chuyển SINGLE↔DUAL là công tắc hệ thống do SYS_ADMIN bật/tắt thủ công — không theo ngưỡng tiền, không tự động.
- Mọi chuyển trạng thái ghi timestamp + danh tính — escalation thiếu timestamp chặng bị coi là vi phạm SLA tracking.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Wallet` | `customer_id`, `currency`, `available_balance`, `frozen_balance` | FK → `Customer` | USD/VND tách riêng, không gộp quy đổi (CMS §3.5) |
| `BalanceSync` (GW) | `platform_id`, `ad_account_id`, `balance`, `spend_daily`, `synced_at`, `source_label`, `stale_flag` | FK → `Platform`, `AdAccount` | Tươi ≤1h; raw payload lưu phía đối trừ |
| `WalletAlert` | `ad_account_id`, `level` (`GREEN/YELLOW/RED`), `days_of_spend_left`, `opened_at`, `status`, `current_stage` | FK → `AdAccount` | Ngưỡng nguồn REQ-FIN-002 |
| `EscalationLog` | `alert_id`, `stage` (`OWNER/OPS_PLAN/OPS_AM/ON_CALL`), `escalated_at`, `acted_by`, `action_ref` | FK → `WalletAlert` | Mỗi chặng bắt buộc timestamp |
| `TopupRequest` (RechargeRequest) | `customer_id`, `ad_account_id`, `amount`, `currency`, `approval_mode`, `state`, `proposed_by`, `step1_by`, `step2_by` | FK → `Customer`, `AdAccount` | SINGLE/DUAL tuần tự (CMS §3.6) |
| `TopupTransaction` | `topup_request_id`, `input_mode` (`NET/GROSS`), `net_amount`, `fee_amount`, `vat_on_fee_amount`, `vat_on_spend_amount`, `gross_amount`, `fee_snapshot` | FK → `TopupRequest` | k = 1 + fee×(1+vatFee) + vatSpend; snapshot khóa (CMS §3.8/§5) |
| `PortalWalletView` | `customer_id`, `balance_by_currency`, `daily_spend`, `adjustment_history_masked`, `recon_status_public` | View lọc tenant | RLS + filter API 2 lớp; mask giá vốn; read-only |
| `ExternalConnectionProfile` (Settings) | `vendor_type`, `auth_config`, `field_mapping`, `status`, `degraded_flag` | FK → `Platform` | Vendor-agnostic theo DI-004 |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ mức Phase 2; chi tiết ở Phase 5. Map về REQ-OPS-003/REQ-FIN-002.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Phân loại 3 mức đúng | ADS 7 ngày = 2.000/ngày, số dư 5.000 | Engine tính | Số ngày chi 2,5 → Vàng, thông báo AM | [ ] |
| SC-002: Push alert đỏ ≤5 phút | GW sync phát hiện số ngày chi <1 | Sync hoàn tất | Push tới owner trên mobile nội bộ trong 5 phút | [ ] |
| SC-003: Escalation 2h/4h có timestamp | Alert đỏ mở 2h rồi 4h, owner không hành động | Bộ đếm quá hạn từng mốc | Escalate OPS_PLAN rồi OPS_AM, mỗi chặng ghi timestamp | [ ] |
| SC-004: Top-up một chạm đúng công thức | Owner bấm "đề xuất nạp" trên alert | Lệnh sinh | Số dư/spend tự điền; k đúng 2 chiều NET/GROSS | [ ] |
| SC-005: Cấm mượn chéo ví | Ví khách A đỏ, ví khách B dư | Owner thử đắp bằng ví B | Bị chặn, cảnh báo FIN_L2 | [ ] |
| SC-006: Degraded manual vẫn cảnh báo | Connector Meta lỗi | Dữ liệu nhập `manual` | Cảnh báo chạy kèm nhãn nguồn + độ trễ; backfill đối chiếu khi API hồi | [ ] |
| SC-007: Portal isolation + dual approval | Khách A xem Portal; approvalMode = DUAL | Xem ví; FIN_L2 thử duyệt cả 2 bước | Chỉ thấy tenant A, mask giá vốn, read-only; bị chặn — bắt buộc FIN_L1 bước 1 → FIN_L2 bước 2 | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (sync số dư GW, alert, escalation, portal view) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (7 nền tảng, push M-INT, portal view) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (dashboard ví, alert — WEB; push — M-INT; view khách — Portal) | `phase4-ux/bcerp-web/wallet-recon/`, `phase4-ux/portal-web/wallet/` |
| Nguồn domain chi tiết | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5, §3.6, §3.8, §5, §3.10) |
