# Tính Năng: Hợp Đồng/LOI/NDA & Brand Safety + E-sign

> **Dựa trên:** REQ-SALES-007 trong `phase1-business/departments/sales/sales.md` (Phần A mục A3, Phần B mục B.7)
> **Phân hệ:** Kinh Doanh — Sales (SYS-CORE-BACKEND)
> **Module:** Quotation & Deal Desk (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1), `phase1-business/P1-02-business-workflow.md` (khối B6)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-core-backend/mod-quotation-dealdesk/*.md`, `phase5-implementation/tasks/sys-core-backend/mod-quotation-dealdesk/feats-impl.md`

> **Đặc thù touchpoint SYS-CORE-BACKEND:** tính năng là headless API/domain service; mọi business rule (block NDA, Brand Safety, khóa version, chờ kích hoạt, retention) enforce ở tầng service dạng machine-level block — UI kênh nào cũng không "vẽ lại" được lối đi. Mọi thao tác ghi dữ liệu có audit log bất biến (hash-chain, WORM ≥10 năm) và tenant isolation theo khách hàng/tenant.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-QDD-002 |
| Module | MOD-QUOTATION-DEALDESK |
| Yêu cầu nghiệp vụ | REQ-SALES-007 |
| Người dùng liên quan | SALES_L1, SALES_L2, SALES_L3, SALES_L4, SALES_L5, OPS_AM, OPS_PLAN, FIN_L1, FIN_L2, BOD_CEO, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (MVP: mẫu chuẩn, chặn NDA + nạp trước NSQC, version lock). E-sign hoàn chỉnh, checklist Brand Safety gắn EVALUATION và archive alert theo lộ trình Phase2 của REQ gốc nhưng entity + rule để dành ngay từ thiết kế |
| Phụ thuộc | FEAT-CORE-QDD-001 (báo giá đã duyệt GM, trạng thái ACCEPTED là đầu vào giá trị hợp đồng). Không có cross-dependency ngoài lane; ràng buộc vận hành đầu ra đọc bởi OPS qua API nội bộ CORE. |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Cung cấp trên core backend bộ engine quản lý vòng đời hồ sơ pháp lý của deal — NDA (thỏa thuận không tiết lộ), LOI (biên bản ghi nhớ) và hợp đồng dịch vụ chính — theo luồng version hóa Template → Draft → Legal review → duyệt ma trận giá trị → Counterparty → Final → E-sign → Signed (khóa cứng) → Archive, kèm cổng Brand Safety 7 tiêu chí bắt buộc trước khi ký và trạng thái "chờ kích hoạt" khi chưa nạp đủ 100% NSQC. Tính năng đảm bảo agency không vận hành cho khách chưa qua sàng lọc thương hiệu, không nhận brief khi chưa có NDA, không kích hoạt chiến dịch khi chưa có tiền — và mọi hồ sơ truy vết được chữ ký, nội dung, thời gian theo Luật GDTĐT 2023.

**Phạm vi:**

- Bao gồm: mẫu hợp đồng chuẩn (IN/OUT of scope) đã legal duyệt; luồng Draft → Legal review → duyệt ma trận giá trị → Counterparty → Final → E-sign → Signed lock cứng → Archive; block máy khi nhận Full Brief 8 sections thiếu NDA mutual gắn khách; checklist Brand Safety 7 tiêu chí gắn EVALUATION với cơ chế "Từ chối vận hành"; trạng thái "chờ kích hoạt" khi chưa nạp đủ 100% NSQC; kích hoạt D+0 khi có tiền vào và LOI/HĐ đã ký, HĐ đầy đủ ≤7 ngày; bất biến serviceType (RENTAL/MANAGED) — đổi dịch vụ = tất toán + hợp đồng mới; red-line diff; e-sign audit trail; retention ≥10 năm, archive alert 30/60/90 ngày.
- Không bao gồm: màn hình soạn/checklist trên web nội bộ (SYS-BCERP-WEB); kênh GDKD duyệt HĐ lớn trên di động Phase2 (SYS-MOBILE-INTERNAL); chữ ký khách trên portal (qua callback e-sign provider); ví đa tiền tệ, đối soát nạp tiền (module WALLET-RECON — CORE chỉ tiêu thụ tín hiệu "đã nạp đủ 100% NSQC").

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | NVKD (SALES_L2) | Gọi API tạo Draft v0.x từ mẫu chuẩn IN/OUT of scope đã legal duyệt | Soạn hợp đồng nhanh mà không tự bịa điều khoản chưa qua kiểm duyệt |
| 2 | GDKD (SALES_L5) | Ghi nhận kết quả legal review, duyệt HĐ theo ma trận giá trị, nhận cảnh báo diff khi điều khoản red-line (không cam kết KPI cứng, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa so mẫu | HĐ rủi ro pháp lý không đến tay khách khi chưa qua mắt người chịu trách nhiệm |
| 3 | BOD_CEO / BOD_CFO_CTO | Duyệt HĐ giá trị lớn theo bậc cao nhất của ma trận (di động Phase2, MFA step-up) | HĐ giá trị lớn luôn có chữ ký cấp điều hành đúng phân cấp |
| 4 | NVKD (SALES_L2) | Điền checklist Brand Safety 7 tiêu chí pass/fail gắn stage EVALUATION; hệ thống chặn PROPOSAL khi fail bất kỳ | Sàng lọc rủi ro thương hiệu trước khi ký, deal rủi ro không lọt sang vận hành |
| 5 | OPS_PLAN / OPS_AM | Nhận thông báo kèm tiêu chí vi phạm khi có lượt "Từ chối vận hành" (legal + TP Vận hành xác nhận 24h), đọc ràng buộc vận hành trên HĐ ACTIVE | Vận hành không nhận deal rủi ro chưa xử lý và chạy đúng loại hình đã ký |
| 6 | Kế toán (FIN_L1/FIN_L2) | Xác nhận tín hiệu tài chính "đã nạp đủ 100% NSQC" để mở trạng thái chờ kích hoạt | Tiền vào do finance xác thực, không do sales tự báo — khớp Financial Hard Stop |
| 7 | NVKD (SALES_L2) | Thấy HĐ tự ACTIVE đúng khi có tiền vào + LOI/HĐ đã ký (D+0), kèm cảnh báo deadline HĐ đầy đủ ≤7 ngày | Deal khởi động nhanh theo cam kết Deploy mà hồ sơ pháp lý vẫn đúng hạn |
| 8 | BOD_CEO / BOD_CFO_CTO | Phê duyệt tiêu hủy hồ sơ hết hạn và xem archive alert 30/60/90 ngày trước hạn | Tuân thủ retention ≥10 năm mà kho hồ sơ không phình vô kiểm soát |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforce ở service layer của CORE dạng machine-level block; audit log hash-chain mọi sự kiện chữ ký/khóa/tiêu hủy.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HDC-201 | Luồng version bắt buộc: Template (mẫu chuẩn legal duyệt) → Draft v0.x → Legal review → duyệt ma trận giá trị (ma trận cấu hình được; bậc giá trị cụ thể chờ GDKD/BOD ban hành chính sách trước go-live — thiết kế sẵn 3 bậc khởi tạo chạy thử) → Counterparty v1.x → Final v2.0 → E-sign → Signed (lock cứng) → Archive; ra khỏi Draft rồi thì mọi thay đổi tạo version mới | API từ chối nhảy bước (400 kèm trạng thái hiện tại); e-sign chỉ nhận version trạng thái FINAL |
| BR-HDC-202 | NDA mutual phải signed và gắn đúng khách trước khi nhận Full Brief 8 sections — block ở tầng service, không chỉ ẩn nút UI; LOI/MOU ký trước HĐ chính được nhưng không thay NDA cho mục đích này | API nhận Full Brief trả 403 mã "NDA_NOT_SIGNED"; attempt bị log phục vụ GDKD rà kỷ luật bán hàng |
| BR-HDC-203 | Brand Safety 7 tiêu chí pass 7/7 trước khi ký, gắn EVALUATION: (1) SP hợp pháp + giấy phép con; (2) không vi phạm Ads Policy; (3) không spam/misleading; (4) quyền image/video/bản quyền hợp lệ; (5) landing page hợp pháp khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập; (7) không ngành cấm/nhạy cảm chưa duyệt; fail bất kỳ → dừng, không sang PROPOSAL | API chuyển stage trả 403 kèm tiêu chí fail; "Từ chối vận hành" ghi tiêu chí vi phạm + notify legal + OPS (xác nhận 24h); vi phạm K1 → chấm dứt hợp đồng |
| BR-HDC-204 | Một hợp đồng chỉ giữ MỘT `serviceType` bất biến suốt vòng đời (RENTAL/MANAGED — CMS §1); đổi dịch vụ = tất toán HĐ cũ (hoàn số dư trong 15 ngày làm việc) + mở HĐ mới; `pms_project_id` chỉ set khi MANAGED, luôn null khi RENTAL | API sửa serviceType trên HĐ ACTIVE trả 409 — endpoint đổi không tồn tại; phải qua TERMINATE (hoàn tiền xong) → HĐ mới |
| BR-HDC-205 | Nạp trước 100% NSQC là điều kiện kích hoạt: chưa xác nhận đủ → HĐ "chờ kích hoạt" (PENDING_ACTIVATION) và block tạo chiến dịch ở tầng máy (Financial Hard Stop); tín hiệu "đủ 100%" do chain tài chính (WALLET-RECON/FIN) xác nhận, sales không tự báo | API tạo chiến dịch trả 403 "CONTRACT_PENDING_ACTIVATION"; không có route bỏ qua với vai nào — chỉ tín hiệu tài chính mở khóa |
| BR-HDC-206 | Kích hoạt D+0 theo điều kiện kép đã chốt: có tiền vào (nạp đủ 100% NSQC) VÀ LOI/HĐ đã ký (KXN-5 — LOI đủ điều kiện D+0); HĐ đầy đủ hoàn tất ≤7 ngày kể từ khi triển khai bằng LOI (KXN-10 — Deploy v2.3 phê chuẩn); quá 7 ngày → cảnh báo SM + GDKD, GDKD quyết pause hoặc gia hạn có lý do | Service layer chỉ mở chiến dịch khi đủ cả hai điều kiện; thiếu một → 403 kèm điều kiện còn thiếu; job ngày 7 sinh cảnh báo escalation |
| BR-HDC-207 | Red-line diff check bắt buộc: so từng điều khoản với mẫu chuẩn, cảnh báo khi điều khoản red-line (không cam kết KPI cứng — lead/CPA/ROAS, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa; dùng mẫu đối tác hoặc đụng red-line → GDKD + luật sư duyệt 5–7 ngày làm việc | Bản có diff red-line gắn cờ, khóa luồng duyệt thường (403); tiếp tục chỉ sau duyệt đặc thù GDKD + kết quả legal |
| BR-HDC-208 | E-sign theo Luật GDTĐT 2023 và NĐ 91/2022: chữ ký số do tổ chức chứng thực (CA) cấp; audit trail bắt buộc thời gian/IP/danh tính người ký; ký nội bộ qua approval engine của CORE (MOBILE Phase2: MFA step-up + token gắn device) | Endpoint e-sign từ chối giao dịch thiếu chứng chỉ hợp lệ hoặc thiếu audit trail; callback thất bại → version giữ trạng thái, không có "ký nửa vời" |
| BR-HDC-209 | Retention hồ sơ pháp lý ≥10 năm; alert 30/60/90 ngày trước hạn lưu trữ; tiêu hủy hết hạn chỉ khi có phê duyệt BOD kèm log hủy riêng — không có xóa cứng tự do | API xóa thường không tồn tại; tiêu hủy là endpoint riêng yêu cầu bản ghi phê duyệt; DB không cấp quyền DELETE ngoài luồng |
| BR-HDC-210 | Không cam kết KPI cứng (số lead, CPA, ROAS) trong điều khoản nào; mẫu chuẩn đã loại sẵn; đề xuất cam kết từ đối tác là red-line theo BR-HDC-207 | Diff check gắn cờ; phát hiện cam kết KPI trong điều khoản mới → cảnh báo bắt buộc legal review trước khi tiếp tục |
| BR-HDC-211 | Sau Signed khóa cứng ở tầng dữ liệu (không có API sửa nội dung); thay đổi sau ký bằng phụ lục đi đúng luồng version; archive giữ bản v2.0 + toàn bộ audit trail; tenant isolation mọi truy vấn | Attempt sửa HĐ Signed trả 409 + log; phụ lục không qua luồng không sinh được bản ghi ràng buộc |
| BR-HDC-212 | Rebate mặc định TẮT cho mọi Contract (CMS §3.10): không auto-tính theo bảng tier; Finance/Admin bật tay per-contract và tự nhập giá trị khi ghi nhận; bảng % tier chỉ là tham khảo gợi ý | Không có job tự tạo rebate; API bật rebate yêu cầu vai FIN + lý do; giá trị nhập tay, có `approved_by` |

---

## 4. Phân Quyền

> Thực thi ở tầng API/service theo 18 vai registry (không dùng OPS_CX/FIN_COMPL). Legal review do luật sư thực hiện ngoài hệ thống — kết quả ghi nhận vào CORE bởi SALES_L5; chữ ký bên khách ghi nhận qua callback e-sign provider. SALES_L1 không có hành động ghi — chỉ xem hồ sơ deal được phân công trong tenant scope.

| Hành động | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | OPS_AM | OPS_PLAN | FIN_L1/L2 | BOD | SYS_ADMIN |
|-----------|----------|----------|----------|----------|--------|----------|-----------|-----|-----------|
| Xem HĐ/LOI/NDA deal mình tham gia | ✅ | ✅ | ✅ | ✅ | ✅ (ràng buộc vận hành) | ✅ | ✅ (điều khoản tài chính) | ✅ | ❌ |
| Soạn Draft v0.x / chuyển stage PROPOSAL khi Brand Safety 7/7 | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ghi nhận kết quả legal review | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt HĐ theo ma trận (bậc thường / bậc giá trị lớn) | ❌ | ❌ | ❌ | ✅ / ❌ | ❌ | ❌ | ❌ | ✅ / ✅ | ❌ |
| Điền checklist Brand Safety (gắn EVALUATION) | ✅ | ✅ | ✅ | ✅ | ✅ (tham gia đánh giá) | ✅ | ❌ | ❌ | ❌ |
| Quyết "Từ chối vận hành" (legal xác nhận, 24h) | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Ký nội bộ e-sign theo ma trận | ❌ | ✅ (SM xác nhận hồ sơ) | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xác nhận tín hiệu tài chính đủ 100% NSQC | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Tất toán HĐ / khởi tạo đổi serviceType | ❌ | ❌ | ❌ | ✅ (đề xuất) | ❌ | ❌ | ✅ (xác nhận hoàn số dư) | ✅ (duyệt) | ❌ |
| Ban hành mẫu & điều khoản red-line | ❌ | ❌ | ❌ | ✅ (ghi nhận GDKD + luật sư) | ❌ | ❌ | ❌ | ✅ (ban hành) | ❌ |
| Quản lý e-sign provider / tiêu hủy hồ sơ hết hạn | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (phê duyệt hủy) | ✅ |
| Xem audit trail chữ ký / archive alert | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ (vận hành, bị log khi xem) |

---

## 5. Trường Hợp Đặc Biệt

- **Đổi loại dịch vụ trên HĐ ACTIVE:** chặn cứng theo BR-HDC-204; luồng đúng là tất toán HĐ cũ (hoàn số dư trong 15 ngày làm việc, FIN xác nhận) rồi mở HĐ mới; lịch sử fee schedule của HĐ cũ giữ nguyên cho giao dịch đã phát sinh (pattern snapshot CMS).
- **Triển khai bằng LOI quá 7 ngày chưa có HĐ đầy đủ:** cảnh báo SM + GDKD; GDKD quyết pause hoặc gia hạn có lý do ghi log; LOI hết hiệu lực trước khi HĐ đầy đủ ký → chiến dịch vào diện rà soát pháp lý.
- **NDA hết hạn/thu hồi giữa deal:** block nhận Full Brief tự bật lại ở tầng service; dữ liệu đã nhận giữ hiệu lực, dữ liệu nhạy cảm mới bị chặn đến khi NDA mới signed.
- **Brand Safety fail 1/7:** deal dừng, không sang PROPOSAL; fail thuộc knockout K1 (thiếu giấy phép — Luật Quảng cáo 2012) trên HĐ đã ký → chấm dứt; "Từ chối vận hành" ghi tiêu chí vi phạm, legal + TP Vận hành xác nhận 24h.
- **Mẫu đối tác/red-line bị sửa:** GDKD + luật sư duyệt 5–7 ngày làm việc, luồng duyệt thường khóa; toàn bộ điều khoản cần luật sư VN xác nhận trước khi phát hành mẫu chính thức — CORE chỉ ghi nhận kết quả.
- **Callback e-sign lỗi/trùng:** giao dịch ký idempotent theo mã; callback trùng không tạo bản ghi kép; thất bại → version giữ FINAL_PENDING_SIGN, hàng đợi retry. **Thiếu một trong hai điều kiện D+0:** tiền đủ nhưng chưa ký (hoặc ngược lại) → không kích hoạt; API trả điều kiện còn thiếu (BR-HDC-206, KXN-5).
- **Nợ sau kích hoạt:** giả định thiết kế theo đề xuất chờ khách hàng xác nhận `[KXN-22]` — 15 ngày không thanh toán → PAUSE, 30 ngày → lộ trình chấm dứt; CORE chỉ cung cấp cờ trạng thái, không tự pause ở tầng hợp đồng.
- **HĐ đa giai đoạn/phụ lục:** mỗi phụ lục là version đi đúng BR-HDC-201; hiệu lực từng giai đoạn là bản ghi riêng, tổng giá trị đối chiếu về báo giá đã duyệt GM (FEAT-CORE-QDD-001).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hợp đồng (Contract); NDA và LOI dùng máy trạng thái con giản lọc (DRAFT → SENT → SIGNED / EXPIRED, gắn khách, có ngày hết hạn riêng).

**Sơ đồ trạng thái:**
```
[DRAFT v0.x] ──(nộp legal)──► [LEGAL_REVIEW] ──(legal pass + duyệt ma trận)──► [INTERNAL_APPROVED]
      ▲                            │ (reject — quay soạn)                            │ (gửi đối tác)
      └────────────────────────────┘                                                 ▼
                                                                        [COUNTERPARTY v1.x] ──(thống nhất Final)──► [FINAL_PENDING_SIGN v2.0]
                                                                                                                            │ (e-sign đủ bên, audit trail đủ)
                                                                                                                            ▼
                                                                                                                        [SIGNED] (khóa cứng)
                                                                                                                         │           │
                                                                                                       (chưa nạp đủ 100% NSQC)   (đã nạp đủ)
                                                                                                                         ▼           ▼
                                                                                                            [PENDING_ACTIVATION]   [ACTIVE]
                                                                                                                │ (đủ tiền)            │ (tất toán/đổi serviceType)
                                                                                                                ▼                      ▼
                                                                                                            [ACTIVE]   [TERMINATED] ──(hết hạn lưu trữ + BOD phê duyệt)──► [DESTROYED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Nộp legal review | `LEGAL_REVIEW` | SALES_L2 trở lên | Soạn từ mẫu chuẩn; diff check đã chạy |
| `LEGAL_REVIEW` | Reject / duyệt | `DRAFT` / `INTERNAL_APPROVED` | SALES_L5 (ghi nhận legal) / L5–BOD theo bậc giá trị | Reject kèm lý do luật sư; duyệt yêu cầu diff red-line = 0 hoặc đã qua duyệt đặc thù 5–7 ngày |
| `INTERNAL_APPROVED` | Gửi đối tác → chốt Final | `COUNTERPARTY` → `FINAL_PENDING_SIGN` | SALES_L2 trở lên | Version v1.x log người gửi/thời điểm; hai bên thống nhất → version v2.0 |
| `FINAL_PENDING_SIGN` | E-sign đủ các bên | `SIGNED` | Hệ thống (callback e-sign) + người ký nội bộ theo ma trận | Chứng chỉ CA hợp lệ; audit trail đủ; Brand Safety 7/7 pass |
| `SIGNED` | Kiểm tra điều kiện tiền | `PENDING_ACTIVATION` / `ACTIVE` | Hệ thống | Chưa đủ 100% NSQC → chờ kích hoạt; có tín hiệu tài chính → ACTIVE |
| `PENDING_ACTIVATION` | Nhận tín hiệu đủ tiền | `ACTIVE` | Hệ thống (tín hiệu từ FIN) | Kích hoạt triển khai D+0 từ thời điểm đủ cả tiền + chữ ký |
| `ACTIVE` | Tất toán (đổi serviceType, hủy, hết hạn) | `TERMINATED` | L5 đề xuất + BOD duyệt + FIN xác nhận | `termination_reason` bắt buộc; hoàn số dư trong 15 ngày làm việc |
| `TERMINATED` | Hết hạn lưu trữ + tiêu hủy | `DESTROYED` | BOD phê duyệt + SYS_ADMIN thực hiện | ≥10 năm retention; phê duyệt + log hủy riêng |

**Quy tắc:**
- `SIGNED` khóa cứng: không có API sửa nội dung; thay đổi sau ký chỉ bằng phụ lục đi lại luồng version.
- `ACTIVE`/`TERMINATED` không quay về `DRAFT`; đổi serviceType bắt buộc qua `TERMINATED` rồi hợp đồng mới (BR-HDC-204).
- `PENDING_ACTIVATION` chỉ mở bởi tín hiệu tài chính — không vai nội bộ nào mở tay; LOI-signed cho triển khai D+0 nhưng không tạo trạng thái `ACTIVE` cho HĐ đầy đủ — HĐ vẫn phải hoàn tất ≤7 ngày.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `contract_template` | `name`, `scope_type` (IN/OUT of scope), `clause_payload` (đánh dấu red-line), `status` (DRAFT/ACTIVE/RETIRED), `legal_approved_by` | 1–N `contract_version` | Mẫu đối tác có cờ riêng → buộc duyệt đặc thù |
| `contract` | `code`, `customer_id` (tenant), `service_type` (RENTAL/MANAGED — bất biến), `fee_percent`, `vat_on_fee_percent`, `vat_on_spend_percent`, `pms_project_id` (chỉ khi MANAGED), `status`, `start_date`, `end_date`, `termination_reason`, `refund_amount`, `rebate_enabled` (false) | FK → customer; 1 `ad_account` có đúng 1 contract ACTIVE tại một thời điểm | Snapshot % áp dụng cho giao dịch mới; phí nạp k = 1 + fee×(1+vatFee) + vatSpend (CMS §5) |
| `contract_version` | `contract_id`, `version_no` (v0.x/v1.x/v2.0), `content_hash`, `redline_diff` (JSON), `status`, `locked_at` | FK → `contract`, `contract_template` | Khóa read-only khi SIGNED; v2.0 là bản ký |
| `nda_record` / `loi_record` | `customer_id`, `type` (NDA_MUTUAL/LOI), `status` (DRAFT/SENT/SIGNED/EXPIRED), `signed_at`, `expires_at`, `document_ref` | FK → customer | NDA mutual là điều kiện block Full Brief (BR-HDC-202) |
| `brand_safety_check` | `deal_id`, `criterion_1..7` (pass/fail/evidence), `overall_status`, `reviewed_by`, `refuse_operation_reason` | FK → deal (EVALUATION) | Fail bất kỳ → chặn PROPOSAL; cơ sở "Từ chối vận hành" |
| `signature_record` | `contract_version_id`, `signer_type` (INTERNAL/EXTERNAL), `signer_id`, `signed_at`, `ip`, `provider_txn_id`, `cert_ref` | FK → `contract_version` | Append-only; idempotent theo `provider_txn_id` |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Block Full Brief thiếu NDA | Khách chưa có NDA mutual signed | Sales gọi API nhận Full Brief 8 sections | API trả 403 "NDA_NOT_SIGNED" + log; sau khi NDA SIGNED thì API mở | [ ] |
| SC-002: Brand Safety fail chặn PROPOSAL | Checklist có tiêu chí (2) fail | Sales gọi API chuyển stage PROPOSAL | API trả 403 kèm tiêu chí fail; deal dừng tại cổng | [ ] |
| SC-003: Chờ kích hoạt block chiến dịch | HĐ SIGNED nhưng chưa nạp đủ 100% NSQC | Tạo chiến dịch | API trả 403 "CONTRACT_PENDING_ACTIVATION"; sau tín hiệu tài chính đủ 100% → tạo thành công | [ ] |
| SC-004: serviceType bất biến | HĐ ACTIVE serviceType RENTAL | Gọi API đổi sang MANAGED | API trả 409 — endpoint đổi không tồn tại; luồng đúng là tất toán + HĐ mới | [ ] |
| SC-005: D+0 điều kiện kép | Khách đã ký LOI, tiền vào đủ 100% NSQC | Sales kích hoạt triển khai D+0 | Chiến dịch mở thành công; job đặt deadline HĐ đầy đủ ≤7 ngày, cảnh báo khi cận hạn | [ ] |
| SC-006: Red-line diff + e-sign audit trail | Bản v1.x bị sửa điều khoản cap trách nhiệm; bản v2.0 ký qua provider | Hệ thống chạy diff; callback ghi nhận chữ ký | Bản gắn cờ red-line, luồng thường trả 403 đến khi GDKD + legal duyệt 5–7 ngày; `signature_record` đủ thời gian/IP/người ký, callback trùng không nhân đôi | [ ] |

> **Liên kết:** SC-001→SC-006 map vào REQ-SALES-007 (Mục 2 — NDA block, Brand Safety, nạp 100% NSQC, e-sign, retention).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (contract, checklist, e-sign callback) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (e-sign provider, Financial Hard Stop, callback) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình web nội bộ (soạn HĐ, checklist Brand Safety, archive alert) | `phase4-ux/sys-bcerp-web/mod-quotation-dealdesk/*.md` |
| Kênh duyệt di động (Phase2, MFA step-up) | `phase4-ux/sys-mobile-internal/mod-quotation-dealdesk/*.md` |
| Nguồn domain tham chiếu | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — Contract, serviceType, công thức phí §5, rebate §3.10) |
