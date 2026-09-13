# Tính Năng: Đối Trừ 3 Số Tự Động, Đa Tiền Tệ, Chốt & Khóa Kỳ

> **Dựa trên:** REQ-FIN-004 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tích hợp Gateway (SYS-INTEGRATION-GW)
> **Module:** Ví TKQC & Đối Trừ (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp: `REQ-FIN-004` → `FEAT-GW-WALLET-001` — bản riêng cho **SYS-INTEGRATION-GW** (REQ xuất hiện ở 3 systems; bản counterpart viết riêng ở lane tương ứng, không gộp trong file này).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-WALLET-001 |
| Module | MOD-WALLET-RECON (SYS-INTEGRATION-GW) |
| Yêu cầu nghiệp vụ | REQ-FIN-004 (Đối trừ 3 số tự động, đa tiền tệ, chốt & khóa kỳ) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (GĐ2 · Phase 2 triển khai) |
| Phụ thuộc | Không có phụ thuộc chéo lane (theo fan-out); tiền đề kỹ thuật trong module: REQ-FIN-001 (sổ phụ ví) và REQ-FIN-005 (API + degraded mode `manual`) phải có trước để có đầu vào đối trừ |
| Ghi chú Expert (A7) | `finance.md` Mục A7 chưa review chính thức; điểm phối hợp đã ghi nhận: REQ-FIN-005 phụ thuộc Business Verification API 7 nền tảng (DI-007 — giữ degraded `manual` + backfill); REQ-FIN-017 là biên tin cậy đối ngoại phối hợp customer/legal-expert |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Thay đối soát bằng ảnh chụp màn hình bằng đối trừ 3 vế tự động — khách nạp theo sổ phụ ví BCERP ↔ nạp thực vào nền tảng (statement/API) ↔ chi tiêu thực tế do nền tảng báo cáo — theo TKQC/khách/nền tảng, với dung sai chuẩn, xử lý chênh lệch có kiểm soát, chốt số liệu và khóa kỳ bảo vệ chứng từ. Ở touchpoint SYS-INTEGRATION-GW, tính năng cung cấp đầu vào vế 2–3 cho đối trừ: adapter kéo số dư/spend/statement từ 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) và VAS, gắn nhãn nguồn, lưu raw payload, thực thi degraded mode `manual` + backfill khi mất API.

**Phạm vi:**
- Bao gồm: adapter pull hourly qua batch/queue chống rate limit; lưu raw payload; nhãn nguồn `api`/`manual`; schema import statement chuẩn cho luồng manual; backfill + tái đối soát khi API sống lại; đồng bộ snapshot tỷ giá chuẩn và FATF list cho rule engine AML; báo trạng thái dữ liệu GW cho màn đối soát (WEB) và API đối trừ cho CORE.
- Không bao gồm: logic khớp 3 vế, ticket discrepancy, khóa kỳ tầng dữ liệu — bản SYS-CORE-BACKEND (counterpart); màn đối soát/ticket/chốt kỳ — bản SYS-BCERP-WEB; ghi sổ phụ ví và lệnh giao dịch tiền gốc (REQ-FIN-001); cảnh báo số dư góc ops (FEAT-GW-WALLET-002); xuất hóa đơn điện tử (REQ-FIN-011).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 (Kế toán viên) | GW tự kéo statement/số dư/spend từ 7 nền tảng mỗi giờ với nhãn nguồn rõ ràng | Có đầu vào vế 2–3 đáng tin cho đối trừ hàng ngày, không thu thập ảnh chụp màn hình |
| 2 | FIN_L1 | Import/nhập tay có cấu trúc khi chưa có API (degraded `manual`) và backfill tái đối soát các kỳ đó khi API sống lại | Nền tảng chưa cấp quyền vẫn đối soát đúng luồng; số `manual` thay bằng số `api` có dấu vết cũ→mới |
| 3 | FIN_L2 (Kế toán trưởng) | GW ghi snapshot tỷ giá ngân hàng quy chuẩn tại từng giao dịch, khóa sau ghi nhận; dữ liệu đối soát có raw payload + mã tham chiếu đầy đủ | Quy VND nhất quán không truy lịch; chốt kỳ ngày 3 và rà tuần truy vết được mọi con số về chứng từ gốc |
| 4 | BOD_CFO_CTO (CFO/CTO) | Báo cáo tỷ lệ dữ liệu `api`/`manual` theo kỳ trước khi duyệt mở khóa kỳ | Đánh giá độ tin cậy của kỳ đối soát bằng căn cứ dữ liệu |
| 5 | SYS_ADMIN | Cấu hình adapter/connector từng nền tảng (vendor-agnostic, qua quản lý kết nối ngoại vi trong Settings) | Đổi thông tin kết nối hoặc bổ sung nền tảng không phải sửa code |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn: `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1) và `finance.md` Phần B.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Ví giữ hộ per-khách multi-currency:** mỗi khách một ví riêng tách theo `currency` (USD/VND không gộp quy đổi — CMS §3.5); tiền khách nạp là **tiền giữ hộ — nợ phải trả**, cấm tự hạch toán thành doanh thu; mọi giao dịch tiền đi qua **lệnh giao dịch tiền** trên hệ thống (khách, TKQC, số tiền, tiền tệ, snapshot tỷ giá, căn cứ) — kế toán từ chối đối chiếu lệnh miệng qua Zalo/điện thoại/email | Ghi nhận ngoài lệnh bị chặn ở tầng ứng dụng; số liệu không có lệnh nguồn không được đưa vào đối trừ |
| BR-002 | **Snapshot fee % tại thời điểm giao dịch:** mọi `TopupTransaction` lưu snapshot `feePercent/vatOnFeePercent/vatOnSpendPercent` ngay tại thời điểm giao dịch, không tham chiếu sống tới `Contract` — Contract đổi % sau không ảnh hưởng giao dịch cũ (CMS §3.8); GW bảo toàn snapshot khi đồng bộ và đối chiếu | Thiếu snapshot → dòng dữ liệu bất hợp lệ, loại khỏi vòng đối trừ, báo lỗi GW |
| BR-003 | **Công thức topup:** `k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent`; nhập NSQC (net) → trừ ví `grossAmount = netAmount × k`; nhập Tổng tiền (gross) → vào AdAccount `netAmount = grossAmount / k` — 2 chiều NET/GROSS khớp ngược chính xác (CMS §5); Rebate không nằm trong công thức | Chênh lệch làm tròn ngoài dung sai nhỏ nhất → chặn giao dịch, báo lỗi công thức |
| BR-004 | **Đối trừ 3 vế tự động:** khớp theo TKQC/khách/nền tảng giữa (1) khách nạp theo sổ phụ ví BCERP, (2) nạp thực tế vào nền tảng (statement/API), (3) chi tiêu thực tế do nền tảng báo cáo; chu kỳ: đối nạp = ngày (sai số tuyệt đối 0/dòng), chi tiêu = ngày, tích lũy chi tiêu + số dư ví = tuần; 4 trạng thái chuẩn: Chưa đối soát / Đã đối soát / Chênh lệch / Đã điều chỉnh (có phiếu duyệt) | Thiếu một vế hoặc sai khóa đối chiếu → dòng giữ "Chưa đối soát", không tự đoán ghép |
| BR-005 | **Dung sai đối trừ (mặc định chốt theo DI-001, cấu hình được):** đối nạp 0/dòng/ngày; chi tiêu ≤0,5% hoặc ≤10 USD/TK/ngày (mức thấp hơn); tích lũy ≤1% hoặc ≤20 USD/khách/tuần. Trong dung sai → "Đã đối soát (dung sai)", hạch toán tài khoản sai lệch đối soát, FIN_L2 rà tuần; vượt dung sai → ticket discrepancy, FIN_L1 giải trình FIN_L2 trước chốt kỳ (T+1), **cấm tự cân số** cho hai vế khớp | Vượt dung sai không có ticket → chặn chốt kỳ; tự cân số không phiếu duyệt bị audit log bắt |
| BR-006 | **Nhãn nguồn `api`/`manual`:** mọi số liệu vào đối soát phải có nhãn nguồn; GW pull hourly qua batch/queue chống rate limit, lưu raw payload; luồng manual là nhập có cấu trúc theo schema chuẩn (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) — sai schema bị chặn, báo lỗi từng dòng, không có nhập tự do dạng text; dữ liệu manual đối soát như luồng API | Thiếu nhãn hoặc sai schema → từ chối vào vòng đối trừ |
| BR-007 | **Degraded mode `manual` bắt buộc + backfill:** khi chưa có quyền API/Business Verification hoặc connector lỗi, GW chuyển sang import/nhập tay `manual` (đối soát ngày hạ xuống tuần); khi API sống lại, backfill và tái đối soát các kỳ đã nhập tay, ghi dấu vết cũ→mới; ràng buộc thiết kế theo DI-007 — không phụ thuộc 100% API | Thiếu chế độ manual là lỗi thiết kế; backfill không tái đối soát → kỳ giữ nhãn `manual`, cảnh báo trên dashboard |
| BR-008 | **Đa tiền tệ & snapshot tỷ giá:** sổ gốc VND; giao dịch ngoại tệ quy đổi theo snapshot tỷ giá ghi ngay tại thời điểm giao dịch (nguồn ngân hàng quy chuẩn), **khóa sau ghi nhận, không truy lịch**; lãi/lỗ FX ghi khoản riêng, tách khỏi giá vốn và GM dịch vụ; sai lệch timing/tỷ giá BC↔nền tảng xử lý qua khoản FX riêng, không tính vi phạm dung sai | UPDATE truy lịch snapshot bị chặn tầng dữ liệu; sửa snapshot gốc phải qua reversal có reason code |
| BR-009 | **Chốt & khóa kỳ:** FIN_L2 chốt công nợ nền tảng tháng ngày 3 tháng kế (mặc định theo DI-001, cấu hình được); chặn chốt khi còn ticket discrepancy; sau chốt khóa kỳ — chứng từ trong kỳ chặn sửa/xóa ở tầng dữ liệu; mở khóa chỉ CFO (BOD_CFO_CTO) duyệt phiếu mở kỳ ghi rõ lý do, phạm vi, thời hạn + audit log bất biến; sửa xong bắt buộc chốt lại; GW không ghi đè dữ liệu kỳ đã khóa | Chốt khi còn ticket → từ chối; GW ghi đè kỳ khóa → chặn tầng API + audit log cảnh báo toàn vẹn |
| BR-010 | **Điều chỉnh rủi ro cao dùng dual approval:** điều chỉnh số dư / đổi tỷ giá tay / hoàn tiền theo công tắc toàn hệ thống `approvalMode = SINGLE/DUAL` (CMS §3.6): `SINGLE` — một người trong nhóm kế toán duyệt 1 lần; `DUAL` — tuần tự bắt buộc ACCOUNTANT (FIN_L1) → CHIEF_ACCOUNTANT (FIN_L2), không đảo thứ tự, không một người duyệt cả 2 bước; người đề xuất ≠ người duyệt; đổi tỷ giá tay chỉ khi biên bản đối chiếu với khách ghi nhận sai khác (đính kèm bắt buộc) | Thiếu một chữ ký ở DUAL → chặn thực thi; đảo thứ tự hoặc trùng người → SoD engine chặn và log nỗ lực vi phạm |
| BR-011 | **AML T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn:** GW đồng bộ FATF list định kỳ vào rule engine; rule engine chấm điểm mọi lệnh nạp/hoàn/điều chỉnh theo T1–T6 (T4 hoàn đổi beneficiary chặn mặc định); KYC khai báo UBO từ 25% sở hữu thụ hưởng; hoàn tiền bắt buộc dẫn chiếu giao dịch nạp gốc, trả về đúng TK nguồn trùng tên pháp nhân KYC, cấm hoàn bên thứ ba; ngưỡng cấu hình được (mặc định chốt theo DI-001); EDD siết 50%; cấm tắt monitoring | Vi phạm T4 → chặn mặc định; mất đồng bộ FATF → GW cảnh báo, rule engine dùng bản mới nhất kèm nhãn độ trễ |
| BR-012 | **Rebate mặc định TẮT:** rebate OFF toàn bộ AdAccount/Contract; Finance/Admin bật tay (`rebateEnabled`) từng trường hợp và **nhập tay** `rebateAmount` khi ghi nhận theo kỳ quý — không auto-tính từ bảng % tier (bảng tier chỉ tham khảo gợi ý); rebate tách khỏi công thức topup BR-003 và khỏi luồng đối trừ tự động | Bất kỳ job tự tính rebate nào trong GW là vi phạm thiết kế; thiếu `approvedBy`/`note` → chặn ghi nhận |
| BR-013 | **Portal chỉ đọc số dư ví (REQ-FIN-017):** khách xem qua view tổng hợp lọc tenant (RLS DB + filter API 2 lớp); tenant isolation bắt buộc — không thấy dữ liệu tenant khác, không thấy giá vốn/chiết khấu/P&L (giá vốn mask thành "điều chỉnh đối soát"); read-only tuyệt đối; watermark + disclaimer độ trễ | Endpoint GW cho Portal ghi dữ liệu tài chính hoặc lộ chéo tenant → chặn tầng API, audit log vi phạm bảo mật |

---

## 4. Phân Quyền

> Touchpoint SYS-INTEGRATION-GW: GW là tầng adapter cung cấp API/dữ liệu — quyền dưới đây chiếu lên web nội bộ (WEB) và được enforce lại ở service layer của CORE; GW không cấp quyền ghi trực tiếp cho người dùng cuối. Ánh xạ vai CMS: ACCOUNTANT = FIN_L1, CHIEF_ACCOUNTANT = FIN_L2, CFO = BOD_CFO_CTO, ADMIN = SYS_ADMIN.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Xem kết quả đối trừ + trạng thái nguồn `api`/`manual` | ✅ | ✅ | ✅ | ✅ (vận hành) |
| Import statement / nhập tay `manual` (schema chuẩn) | ✅ | ✅ | ❌ | ❌ |
| Tạo ticket discrepancy + giải trình | ✅ | ✅ (nhận giải trình) | ❌ | ❌ |
| Duyệt điều chỉnh có chứng từ (dual approval BR-010) | ✅ (bước 1 khi DUAL) | ✅ (bước 2 khi DUAL) | ✅ (duyệt khi SINGLE) | ❌ |
| Rà tuần sai lệch đối soát + khoản FX | ✅ | ✅ | ✅ | ❌ |
| Chốt kỳ (khi không còn ticket) | ❌ | ✅ | ❌ | ❌ |
| Mở khóa kỳ (phiếu lý do, phạm vi, thời hạn) | ❌ | ❌ | ✅ (duyệt duy nhất) | ❌ |
| Cấu hình dung sai / ngày chốt kỳ / ngưỡng AML / adapter-connector nền tảng | ❌ | ✅ (đề xuất) | ✅ (phê duyệt) | ✅ (thực thi) |
| Kích hoạt backfill / tái đối soát kỳ `manual` | ✅ | ✅ | ❌ | ✅ (vận hành) |
| Xóa/sửa audit log hoặc raw payload | ❌ | ❌ | ❌ | ❌ (kể cả Super Admin) |

---

## 5. Trường Hợp Đặc Biệt

- **Nền tảng chưa có API / chưa qua Business Verification (DI-007):** GW hạ đối soát ngày xuống tuần qua import chuẩn; kỳ đánh dấu `manual`, dashboard hiển thị nhãn nguồn + disclaimer độ trễ; khi được cấp quyền, backfill chạy theo nền tảng/theo kỳ, không merge đè số `manual` trước khi tái đối soát xong. Import fail schema: báo lỗi từng dòng kèm lý do (thiếu trường, sai định dạng tiền tệ, trùng mã tham chiếu), FIN_L1 sửa và nạp lại đúng dòng lỗi — không có nhập tự do dạng text.
- **Sai lệch timing/tỷ giá BC↔nền tảng:** xử lý qua khoản FX riêng (BR-008), không tính vi phạm dung sai; dòng đối trừ hiển thị song song tiền gốc + quy VND kèm snapshot tỷ giá từng bên.
- **Kỳ đã khóa phát hiện sai số:** không sửa chứng từ gốc — mở kỳ bằng phiếu CFO (lý do/phạm vi/thời hạn), xử lý từng phiếu không mở khóa hàng loạt; điều chỉnh ảnh hưởng P&L tháng đã chốt do CFO duyệt trong 48h; GW chấp nhận tham số "period-locked" đóng băng ghi nhận thuộc phạm vi khóa.
- **Kết nối kế toán VAS đối chiếu sổ (DI-004):** connector là cấu hình kết nối ngoại vi vendor-agnostic trong Settings (connection profile + field mapping + import/export template + API adapter cắm được); tên phần mềm kế toán cụ thể cấu hình khi triển khai, không chặn thiết kế.
- **Giới hạn scope nguồn gốc CMS `[KXN-9]`:** entity Wallet/TopupTransaction/RebateStatement trong `documents/02` đã vào triển khai hiện tại theo req-registry; ranh giới phần CMS đánh dấu "tương lai" chưa chốt (KXN-9 còn mở) — không tự suy diễn entity ngoài registry. Các KXN còn mở khác (6, 7, 15–22) thuộc SALES/OPS lifecycle, đã rà và không ảnh hưởng tính năng này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity chính:** Kỳ đối soát nền tảng (Reconciliation Period) và dòng đối trừ (Reconciliation Line).

**Sơ đồ trạng thái (Kỳ đối soát):**
```
[MỞ] ──(đủ dữ liệu vế 1–3)──► [SẴN SÀNG CHỐT]
[SẴN SÀNG CHỐT] ──(FIN_L2 chốt, 0 ticket)──► [ĐÃ CHỐT — KHÓA]
[ĐÃ CHỐT — KHÓA] ──(CFO duyệt phiếu mở kỳ)──► [MỞ KHÓA — ĐANG SỬA]
[MỞ KHÓA — ĐANG SỬA] ──(sửa xong, chốt lại)──► [ĐÃ CHỐT — KHÓA]
```

**Sơ đồ trạng thái (Dòng đối trừ):**
```
[CHƯA ĐỐI SOÁT] ──(khớp tuyệt đối)──► [ĐÃ ĐỐI SOÁT]
     │ (trong dung sai)                    │ (vượt dung sai → ticket → phiếu duyệt)
     ▼                                     ▼
[ĐÃ ĐỐI SOÁT (DUNG SAI)]              [ĐÃ ĐIỀU CHỈNH]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `MỞ` | Đóng dữ liệu nhập, chờ backfill xong | `SẴN SÀNG CHỐT` | Hệ thống (GW báo trạng thái) | 3 vế có dữ liệu, nhãn nguồn đầy đủ |
| `SẴN SÀNG CHỐT` | Chốt kỳ | `ĐÃ CHỐT — KHÓA` | FIN_L2 | 0 ticket chưa giải trình; đúng ngày chốt (mặc định ngày 3 tháng kế) |
| `ĐÃ CHỐT — KHÓA` | Mở khóa kỳ | `MỞ KHÓA — ĐANG SỬA` | BOD_CFO_CTO | Phiếu mở kỳ: lý do, phạm vi, thời hạn + audit log |
| `MỞ KHÓA — ĐANG SỬA` | Chốt lại | `ĐÃ CHỐT — KHÓA` | FIN_L2 | Sửa xong trong thời hạn phiếu; điều chỉnh P&L do CFO duyệt 48h |
| `CHƯA ĐỐI SOÁT` | Khớp 3 vế (tuyệt đối hoặc trong dung sai) | `ĐÃ ĐỐI SOÁT` / `ĐÃ ĐỐI SOÁT (DUNG SAI)` | Hệ thống (CORE) | Sai số = 0; hoặc trong ngưỡng BR-005 → hạch toán tài khoản sai lệch đối soát |
| `CHƯA ĐỐI SOÁT` | Vượt dung sai → ticket → điều chỉnh | `ĐÃ ĐIỀU CHỈNH` | FIN_L1 giải trình + FIN_L2 duyệt | Ticket đủ trường; phiếu duyệt + dual approval BR-010 |

**Quy tắc:**
- `ĐÃ CHỐT — KHÓA` là trạng thái bảo vệ: GW và mọi tầng không được UPDATE/DELETE chứng từ thuộc kỳ; chỉ thoát qua phiếu mở kỳ của CFO.
- Dòng `ĐÃ ĐIỀU CHỈNH` không quay về `CHƯA ĐỐI SOÁT` — sửa tiếp qua ticket/reversal có reason code; backfill không tự đổi trạng thái kỳ đã chốt, chỉ tạo đề xuất tái đối soát cho CFO duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `PlatformStatement` (raw pull GW) | `platform_id`, `external_ref`, `period`, `payload_raw`, `source_label`, `synced_at` | FK → `Platform` | Append-only; chứa cả bản import manual theo schema chuẩn |
| `ReconciliationLine` | `customer_id`, `ad_account_id`, `platform_id`, `wallet_amount`, `platform_amount`, `spend_amount`, `status`, `fx_snapshot_id` | FK → 3 nguồn | Khóa đối chiếu TKQC/khách/nền tảng |
| `DiscrepancyTicket` | `line_id`, `two_sides_values`, `source`, `timestamp`, `assignee`, `explanation`, `resolution` | FK → `ReconciliationLine` | Chặn chốt kỳ khi còn ticket mở |
| `ReconciliationPeriod` | `platform_id`, `period`, `status`, `locked_at`, `reopen_ticket_id` | FK → `Platform` | Khóa kỳ thực thi ở tầng dữ liệu |
| `Wallet` / `WalletTransaction` | `customer_id`, `currency`, `available_balance`, `frozen_balance`; lệnh: `amount`, `currency`, `fx_snapshot`, `fee_percent_snapshot`, `basis` | FK → `Customer` | USD/VND không gộp; snapshot khóa sau ghi nhận (CMS §3.5/3.8) |
| `FxRateSnapshot` | `currency_pair`, `rate`, `source_bank`, `captured_at` | Tham chiếu bởi giao dịch ngoại tệ | Không UPDATE truy lịch |
| `ExternalConnectionProfile` (Settings) | `vendor_type`, `auth_config`, `field_mapping`, `status`, `last_sync_at` | FK → `Platform`/VAS | Vendor-agnostic theo DI-004; cấp FATF list sync cho rule engine AML |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ mức Phase 2; chi tiết ở Phase 5. Map về REQ-FIN-004.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đối trừ khớp tuyệt đối | Statement `api` khớp sổ phụ ví | Đối trừ chạy | Dòng chuyển "Đã đối soát", không phát sinh ticket | [ ] |
| SC-002: Vượt dung sai phát sinh ticket | Chi tiêu lệch >0,5%/10USD per TK/ngày | Đối trừ chạy | Ticket đủ trường; chặn chốt kỳ đến khi giải trình | [ ] |
| SC-003: Degraded manual + backfill | Nền tảng mất API | Import `manual`; sau đó API sống lại | Đối soát đúng luồng API; backfill tái đối soát, ghi dấu vết cũ→mới | [ ] |
| SC-004: Chốt kỳ chặn khi còn ticket / mở kỳ chỉ CFO | Kỳ còn ticket hoặc đã khóa | FIN_L2 bấm chốt; SYS_ADMIN cố mở khóa | Từ chối chốt liệt kê ticket; chỉ CFO mở được bằng phiếu lý do/phạm vi/thời hạn | [ ] |
| SC-005: Multi-currency + công thức k | Khách có ví USD và VND; fee=3%, vatOnFee=8%, vatOnSpend=8% | Xem số dư quy VND; nhập net 1.000 / gross 1.112,4 | Sổ tách riêng theo tiền tệ, quy VND dùng snapshot khóa; k 2 chiều khớp ngược đúng CMS §5 | [ ] |
| SC-006: AML + Portal isolation | Lệnh hoàn đổi beneficiary; khách A xem Portal | Tạo lệnh hoàn; khách A xem ví | T4 chặn mặc định cảnh báo đỏ; Portal chỉ thấy tenant A, read-only, mask giá vốn | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (adapter GW, đối trừ, khóa kỳ) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (7 nền tảng, VAS, kế toán VAS, FATF sync) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (đối soát, ticket, chốt kỳ — bản WEB) | `phase4-ux/bcerp-web/wallet-recon/` |
| Nguồn domain chi tiết | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.5, §3.6, §3.8, §5, §3.10) |
