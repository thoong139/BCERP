# Tính Năng: Ad Account Command Center — Registry & Vòng Đời TKQC

> **Dựa trên:** REQ-OPS-001 trong `phase1-business/departments/operations/operations.md` (Phần A3, Phần B.1 — BR-OPS-1.1 đến 1.8)
> **Phân hệ:** Vận hành & Marketing nội bộ — Paid Media / Ad Ops (SYS-CORE-BACKEND)
> **Module:** Quản lý Tài khoản Quảng cáo — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/adaccount-cc/[screen-group].md`, `phase5-implementation/tasks/core-backend/adaccount-cc/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-OPS-001 fan-out ra 4 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-ADACC-002); counterparts: SYS-BCERP-WEB (màn Command Center), SYS-INTEGRATION-GW (đồng bộ số dư/spend), SYS-MOBILE-INTERNAL (push cảnh báo, từ GĐ2). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ADACC-002 |
| Module | MOD-ADACCOUNT-CC (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-001 (Ad Account Command Center — registry & vòng đời TKQC) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (chính); FIN_L1 (view-only/billing); SYS_ADMIN |
| Độ ưu tiên | Cao (HIGH · MVP · GĐ1) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Gate KYC (FEAT-CORE-ADACC-001) + gate khớp tiền (FEAT-CORE-ADACC-003) — registry tiêu thụ cả 2 gate trước khi chuyển "Cấp phát" |
| Ghi chú Expert (A7) | Chưa có điều chỉnh — Mục A7 trong `operations.md` đang "chờ review"; ghi chú trùng lặp tại A7 (REQ-OPS-002/003 phối hợp FIN) đã xử lý bằng cách tách REQ-OPS-002 thành FEAT-CORE-ADACC-003 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng registry trung tâm trên core backend quản lý toàn bộ **2.600+ TKQC active trên 7 nền tảng** (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) của BC Agency: vòng đời 5 trạng thái, ownership chặt (1 khách + 1 owner + 1 backup), naming/UTM chuẩn tự sinh, die account tracking với evidence bất biến, và thu hồi quyền 24h khi có sự kiện nhân sự. Registry là nguồn sự thật duy nhất về "tài khoản nào thuộc ai, đang ở giai đoạn nào, tại sao" — mọi thay đổi trạng thái đều được enforce và ghi log ở tầng service.

**Phạm vi:**
- Bao gồm: entity `AdAccount` + registry (số dư, spend limit, trạng thái, lọc theo khách/platform/owner); vòng đời 5 bước (Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng); OADS state machine xử lý yêu cầu mở TK mới (`DRAFT → CONTENT_REVIEWING → CONTENT_APPROVED → CS_REVIEWING → CS_APPROVED →` tạo `AdAccount` + `Contract`); naming convention validator + sinh UTM tự động chặn sửa tay; rule campaign bắt buộc gắn project (không gắn → tự pause + task trong 4h làm việc); ownership RBAC 4 mức (edit/view-only/billing/admin); die account tracking + evidence store bất biến (hash, không sửa/xóa hậu kiểm) + TK dự phòng mỗi khách ≥1; ReplacementRequest do CS gán tay với chuỗi lịch sử thay thế; thu hồi quyền trong 24h từ sự kiện HR; quy tắc bất biến `Contract.serviceType` (`RENTAL | MANAGED`) và `pmsProjectId` chỉ set khi `MANAGED`; import mở sổ có kiểm soát + gắn nhãn dữ liệu `manual` khi degraded.
- Không bao gồm: đồng bộ số dư/spend hourly và connector 7 nền tảng (chức năng chính của SYS-INTEGRATION-GW — CORE chỉ nhận và lưu kết quả); màn hình dashboard Command Center (SYS-BCERP-WEB); push cảnh báo mobile (SYS-MOBILE-INTERNAL, GĐ2); đối soát và xác nhận khớp tiền (REQ-FIN-006 / FEAT-CORE-ADACC-003 — registry chỉ tiêu thụ tín hiệu); gate KYC (FEAT-CORE-ADACC-001 — registry chỉ gọi gate); kho nguồn cung nội bộ BM/VIA/proxy (để giai đoạn sau — ReplacementRequest hiện giả định "đã có sẵn, CS gán tay").

---

## 2. Luồng Người Dùng (User Stories)

Luồng người dùng dưới đây mô tả trải nghiệm qua touchpoint WEB nội bộ; mọi hành động đều gọi headless API của core backend — nơi thực thi toàn bộ business rules.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Tạo yêu cầu đăng ký TKQC mới (chọn platform/khách/dự án), hệ thống tự sinh mã theo naming chuẩn `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` và ghi registry ở "Khởi tạo" | TK đúng chuẩn ngay lúc sinh, không phải dọn naming về sau |
| 2 | OPS_CONT | Soạn hồ sơ mở TK (business info, licenseDocs), đẩy lên cấp duyệt và được sửa nội dung khi bị trả về `DRAFT` kèm reason + evidence | Hồ sơ được chỉnh đến chuẩn nền tảng, lý do từ chối luôn có căn cứ |
| 3 | OPS_CONT (cấp Executive+) | Duyệt/từ chối OADS ở bước CONTENT_REVIEWING, biết rằng cấp INTERN/JUNIOR không đổi được trạng thái dù sửa được nội dung | Duyệt ngành theo whitelist do đúng cấp quyết — tách soạn thảo khỏi phê duyệt |
| 4 | OPS_AM | Registry tự chuyển TK sang "Cấp phát" khi FIN_L1 khớp tiền và gate KYC mở, owner nhận quyền theo RBAC | Không vận hành tay bước mở khóa — quyền đến đúng lúc tiền đã an toàn |
| 5 | OPS_ADS | Ghi nhận die account kèm evidence (snapshot số dư, thông báo platform, timestamp) và kích hoạt TK dự phòng sẵn của khách | Chạy lại trong 4h làm việc và có bằng chứng bất biến để khiếu nại platform |
| 6 | OPS_ADS | Hệ thống tự pause campaign không gắn dự án và tạo task gắn project trong 4h làm việc | Không có chi tiêu nào không truy vết được về khách |
| 7 | OPS_PLAN | Xem toàn cảnh registry theo khách/platform/owner, cảnh báo TK thiếu owner/backup và owner sắp nghỉ | Cân đối nguồn lực, rà soát rủi ro tập trung |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Registry và toàn bộ state machine enforce tại tầng service của core backend; WEB/GW/M-INT là điểm tiêu thụ, không phải điểm kiểm soát.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Vòng đời 5 trạng thái** (`Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng`): TK mới luôn bắt đầu ở "Khởi tạo — chưa hoạt động", không nhảy cóc; mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/sang trạng thái nào, căn cứ). Nguồn: BR-OPS-1.1, CMS §3.4. | API từ chối chuyển không hợp lệ; thiếu căn cứ → không submit |
| BR-002 | **Gate kép trước "Cấp phát":** (a) KYC khách = `Verified` (gate FEAT-CORE-ADACC-001); (b) tín hiệu "Đã khớp tiền" từ FIN_L1 cho lệnh nạp tương ứng (gate FEAT-CORE-ADACC-003). Thiếu một trong hai → không tạo `AdAccount`/`Contract` tại `CS_APPROVED`, không bật chi tiêu. | Chặn cứng với mã lỗi chỉ rõ gate nào chưa mở; không override |
| BR-003 | **OADS state machine:** `DRAFT → CONTENT_REVIEWING → CONTENT_APPROVED → CS_REVIEWING → CS_APPROVED →` tạo 1 `AdAccount` mới + 1 `Contract` ACTIVE; reject ở bước nào cũng về `DRAFT` kèm `rejectReason` + `rejectEvidence`; quyền duyệt bước CONTENT chỉ dành cho OPS_CONT cấp tương đương `CONTENT_EXECUTIVE/SENIOR/LEADER` (track 5 cấp CMS §3.2) — `INTERN/JUNIOR` chỉ sửa nội dung, không đổi trạng thái. | API từ chối vai chưa đủ cấp; reject luôn kèm reason + evidence |
| BR-004 | **Naming + UTM:** chuẩn `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` (VD `FMCG01-META-CONV-VN-2609`); CORE validator chặn tạo/sửa sai chuẩn ở tầng API; `utm_source/medium/campaign` sinh tự động, chặn sửa tay ở cả WEB và GW; áp mọi TK/campaign/adset/ad, kể cả client-owned. Ngoại lệ chuẩn riêng của khách: OPS_PLAN (TL) duyệt ≤1 ngày làm việc + change log. Nguồn: BR-OPS-1.2. | Validator từ chối; ngoại lệ thiếu lý do → không lưu |
| BR-005 | **Campaign bắt buộc gắn project:** job quét định kỳ tự pause campaign không gắn dự án (thực thi qua GW khi có quyền API) + tạo task gắn project trong 4h làm việc; cấm report/hạch toán chi tiêu về khách tới khi gắn xong. Degraded: chưa có API → task pause tay cho OPS_ADS, dữ liệu nhãn `manual`. Nguồn: BR-OPS-1.3. | Chi tiêu chưa gắn không hạch toán về khách; task quá 4h → escalate |
| BR-006 | **Ownership 1-1-1:** mỗi TK đúng 1 owner + 1 backup, tối đa 2 quyền edit; cấm chia sẻ email/mật khẩu/2FA; RBAC 4 mức — edit (owner+backup) / view-only (OPS_PLAN, OPS_AM, FIN) / billing (FIN_L1 — tài chính, không sửa ngân sách chiến dịch) / admin (quản trị, không chỉnh chi tiêu); cảnh báo TK thiếu owner/backup, owner sắp nghỉ; đổi owner/backup do OPS_PLAN (TL) duyệt ≤1 ngày làm việc. Nguồn: BR-OPS-1.4. | Vi phạm chia sẻ login → thu hồi quyền ngay + kỷ luật; chặn gán owner thứ 2 |
| BR-007 | **Die account tracking:** phát hiện qua GW sync hoặc OPS_ADS ghi nhận tay; evidence chụp tại thời điểm xảy ra (snapshot số dư, thông báo platform, timestamp chính xác) lưu evidence store bất biến (hash, không sửa/xóa hậu kiểm); lịch sử die theo platform phục vụ đánh giá rủi ro nạp mới; mỗi khách ≥1 TK dự phòng đã khởi tạo, chưa bật chi tiêu; thay thế = kích hoạt TK dự phòng → qua Hard Stop → chuyển hướng vận hành trong 4h làm việc; khôi phục TK gốc chỉ khi platform gỡ hạn chế + xác nhận. Nguồn: BR-OPS-1.6. | Evidence thiếu timestamp/hash → không hợp lệ; thay thế không qua Hard Stop → chặn |
| BR-008 | **ReplacementRequest — CS gán tay, không tự động từ kho:** state `PENDING → CS_ASSIGNED → BALANCE_TRANSFERRED → COMPLETED`; lỗi do khách → `REJECTED`; `newAdAccount.replacesAdAccountId = oldAdAccountId` giữ chuỗi lịch sử thay thế (1 account bị thay nhiều lần); `balanceTransferredAmount` ghi nhận để đối soát; `isCustomerFault` quyết định SLA miễn phí; `Contract` hiện tại không đổi khi Replacement — fee schedule giữ nguyên. Nguồn: CMS §3.11. | Thiếu `isCustomerFault` → không sang `CS_ASSIGNED`; đổi Contract khi replacement → chặn |
| BR-009 | **`Contract.serviceType` bất biến:** `RENTAL | MANAGED` không sửa sau khi tạo; đổi loại dịch vụ = tất toán HĐ cũ (hoàn số dư trong 15 ngày làm việc) + mở HĐ mới; `pmsProjectId` chỉ set khi `MANAGED`, luôn `null` khi `RENTAL`; 1 `AdAccount` đúng 1 Contract ACTIVE tại một thời điểm, Contract TERMINATED giữ nguyên fee schedule cho giao dịch cũ. Nguồn: CMS §3.3/§4. | Chặn UPDATE serviceType; gán pmsProjectId cho RENTAL → từ chối; 2 Contract ACTIVE → chặn |
| BR-010 | **Thu hồi quyền 24h:** sự kiện nghỉ/chuyển dự án/thay owner từ HR_L1 → CORE tự revoke quyền TKQC trong 24h + sinh task bàn giao cho backup; SYS_ADMIN rotate credentials liên quan trong vault; đóng TK hết HĐ: OPS_PLAN (TL) + FIN_L1 xác nhận hết dư nợ (2 ngày làm việc) → thu hồi access, snapshot evidence, archive dữ liệu. Nguồn: BR-OPS-1.7. | Quá 24h chưa revoke → alert escalate; đóng TK còn dư nợ → chặn |
| BR-011 | **Degraded mode `manual`:** trước khi đủ quyền API, import statement chuẩn hóa/nhập tay có cấu trúc gắn nhãn `manual` + nguồn + timestamp; khi được cấp API → backfill tự động + đối chiếu số trước khi chuyển nguồn; import Google Sheets có kiểm soát schema, không ghi đè nguồn API. Nguồn: BR-OPS-1.8, REQ-OPS-001. | Sai schema → từ chối; chuyển nguồn không đối chiếu → chặn |
| BR-012 | **Audit log + tenant isolation:** mọi thao tác registry ghi log bất biến append-only; truy vấn scop cứng theo tenant tại service layer; credentials lưu vault mã hóa — chỉ SYS_ADMIN/BOD_CFO_CTO quản trị, rotate ≥90 ngày, không trả plaintext về UI, chỉ thao tác trên WEB nội bộ với MFA, mobile cấm hiển thị credentials. Nguồn: BR-OPS-1.8, Notes lane. | Vượt tenant / đọc plaintext → từ chối + audit log bảo mật |

---

## 4. Phân Quyền

| Hành động | OPS_ADS | OPS_AM | OPS_CONT / OPS_DES / OPS_EDIT | OPS_PLAN | FIN_L1 | SYS_ADMIN |
|-----------|---------|--------|-------------------------------|----------|--------|-----------|
| Xem registry (lọc theo khách/platform/owner) | ✅ | ✅ | ✅ | ✅ (toàn cảnh) | ✅ (view-only/billing) | ✅ |
| Tạo yêu cầu đăng ký TK mới (OADS) | ✅ | ✅ | ✅ (soạn hồ sơ) | ❌ | ❌ | ❌ |
| Duyệt/từ chối OADS bước CONTENT (EXECUTIVE+) | ❌ | ❌ | ✅ (chỉ cấp Executive trở lên) | ❌ | ❌ | ❌ |
| Thiết lập thông số TK sau Content duyệt (CS) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gán/đổi owner + backup | ❌ | ❌ | ❌ | ✅ (duyệt ≤1 ngày LV) | ❌ | ❌ |
| Gán tay ReplacementRequest | ❌ | ✅ (CS gán tay theo CMS) | ❌ | ❌ | ❌ | ❌ |
| Ghi nhận die account + upload evidence | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt đóng TK / khôi phục TK gốc | ❌ | ❌ | ❌ | ✅ (TL) | ✅ (xác nhận hết dư nợ khi đóng TK hết HĐ) | ❌ |
| Sửa naming/UTM tay | ❌ (chỉ có hệ thống sinh; sửa = vi phạm BR-004) | ❌ | ❌ | ✅ (duyệt ngoại lệ chuẩn riêng, ≤1 ngày LV) | ❌ | ❌ |
| Sửa `Contract.serviceType` trên hợp đồng ACTIVE | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (bất biến — mọi vai; chỉ tất toán + mở HĐ mới) |
| Sửa ngân sách chiến dịch | ✅ (owner/backup, trong hạn mức theo cấp buyer) | ❌ | ❌ | ❌ | ❌ (billing không đụng ngân sách) | ❌ |
| Đăng ký API/Business Verification, quản lý vault | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (MFA bắt buộc, rotate ≥90 ngày) |

> Ghi chú touchpoint: vai CS/CONTENT trong CMS Domain Model ánh xạ sang registry 18 vai — CS → OPS_AM/OPS_ADS; CONTENT → OPS_CONT (Executive+ mới được duyệt); ACCOUNTANT/CHIEF_ACCOUNTANT/CFO → FIN_L1/FIN_L2/BOD_CFO_CTO; ADMIN → SYS_ADMIN. Mọi quyền enforce tại tầng API core backend; các hệ thống khác chỉ render kết quả.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **TK Internal-Sandbox:** không gắn khách (ngân sách thật ≤ mức OPS_PLAN duyệt, rà soát theo quý) — vẫn quản lý vòng đời nhưng loại khỏi báo cáo khách/đối soát bằng cờ phân loại, không bằng quy ước tên.
- **Client-owned TK:** quyền sở hữu thuộc khách, BC không nạp tiền; vẫn áp naming + gắn project; Hard Stop áp dụng ở mức đo lường.
- **Die account khi degraded (chưa có API):** phát hiện bằng ghi nhận tay của OPS_ADS; evidence vẫn bắt buộc upload; lệnh pause platform là thao tác tay, dữ liệu gắn nhãn `manual`.
- **Owner + backup cùng rời:** HR ghi sự kiện → revoke 24h tự động kèm task bàn giao có deadline; nếu cả hai rời → cảnh báo đỏ cho OPS_PLAN, khóa edit đến khi gán lại.
- **Import lỗi/trùng từ Google Sheets:** từ chối dòng lỗi, import dòng hợp lệ, báo cáo kết quả có log; cấm ghi đè giá trị nguồn API bằng nguồn `manual`.
- **TK dự phòng bị khóa trước kích hoạt:** replacement từ pool dự phòng khác của khách; hết dự phòng → cảnh báo vi phạm "mỗi khách ≥1 TK dự phòng" + task khởi tạo ngay.
- **Sự kiện nền tảng khóa TK ngoài giờ:** GW sync vẫn ghi `FROZEN/BLOCKED` và bắn cảnh báo theo quy trình die account; việc thay thế vẫn phải chờ hoàn tất evidence + Hard Stop đúng SLA 4h làm việc.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity chính:** `AdAccount` (registry) — vòng đời OPS 5 trạng thái; kèm **entity yêu cầu mở TK** `OadsRequest` (CMS §3.2) điều khiển việc tạo `AdAccount` + `Contract`.

**Sơ đồ vòng đời `AdAccount` (registry):**
```
[Khởi tạo] ──(FIN_L1 xác nhận khớp tiền + KYC Verified)──► [Khớp tiền] ──(mở khóa Hard Stop)──► [Cấp phát]
                    │                                                                              │
                    │ (đóng sớm)                                                                   ▼
                    ▼                                                                        [Vận hành]
              [Thu hồi/Đóng] ◄──────────────(TL + FIN_L1 xác nhận hết dư nợ)──────────────────┘
```
Trạng thái nền tảng của `AdAccount` (đồng bộ từ platform/GW, CMS §3.4): `ACTIVE | FROZEN | BLOCKED | OUT_OF_MONEY` — độc lập với vòng đời OPS, lưu song song.

**Sơ đồ `OadsRequest`:**
```
[DRAFT] ──(submit)──► [CONTENT_REVIEWING] ──(approve EXECUTIVE+)──► [CONTENT_APPROVED]
                            │ (reject + reason + evidence)                │
                            ▼                                            ▼
                         [DRAFT] ──(submit)──► [CS_REVIEWING] ──(approve)──► [CS_APPROVED]
                                                   │ (reject + reason)            │
                                                   ▼                              ▼
                                                [DRAFT]                tạo AdAccount + Contract ACTIVE
```

**Bảng chuyển đổi vòng đời `AdAccount`:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Khởi tạo | Xác nhận khớp tiền | Khớp tiền | Hệ thống (tín hiệu từ FIN_L1 — FEAT-CORE-ADACC-003) | KYC khách `Verified` + lệnh nạp tương ứng "Đã khớp tiền" |
| Khớp tiền | Cấp phát | Cấp phát | Hệ thống (gate kép BR-002 mở) | Gate Hard Stop mở; owner + backup đã gán; naming hợp lệ |
| Cấp phát | Bật chi tiêu | Vận hành | OPS_ADS (owner/backup) | TK bind platform thành công; campaign gắn project |
| Vận hành | Thu hồi/Đóng | Thu hồi/Đóng | OPS_PLAN (TL) + FIN_L1 | Hết dư nợ xác nhận trong 2 ngày LV; snapshot evidence; archive dữ liệu |
| Vận hành | Die + thay thế | Vận hành (trên `newAdAccount`) | OPS_AM (CS gán tay) + hệ thống | Qua Hard Stop khớp tiền; `ReplacementRequest` hoàn tất `BALANCE_TRANSFERRED` |

**Quy tắc:**
- Không quay về trạng thái trước trong vòng đời OPS; `Thu hồi/Đóng` là trạng thái kết thúc — mở lại chỉ bằng tạo yêu cầu mới (audit log giữ nguyên lịch sử).
- Tạo `AdAccount` + `Contract` chỉ xảy ra duy nhất tại `CS_APPROVED` của OADS — không có đường tạo TK ngoài state machine.
- Trạng thái nền tảng (`FROZEN/BLOCKED/OUT_OF_MONEY`) không đổi vòng đời OPS nhưng kích hoạt die tracking (BR-007) và chặn bật chi tiêu khi đang `BLOCKED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`; domain gốc tại `documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `AdAccount` | `status` (`ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY`), `ops_lifecycle` (5 bước), `platform_id`, `external_account_id`, `currency`, `bind_info` (JSON), `pixel_id`, `current_contract_id`, `replaces_ad_account_id`, `owner_id`, `backup_id` | FK → `platforms`, `contracts`, `employees` | 2.600+ bản ghi; ownership 1-1-1; `replaces_ad_account_id` tạo chuỗi lịch sử thay thế |
| `OadsRequest` | `customer_id`, `platform_id`, `ad_account_type_id`, `business_info`, `license_docs[]`, `reject_reason`, `reject_evidence`, `state` | FK → `customers` | Tạo 1 `AdAccount` + 1 `Contract` tại `CS_APPROVED` |
| `Contract` | `service_type` (`RENTAL/MANAGED` — bất biến), `fee_percent`, `vat_on_fee_percent`, `vat_on_spend_percent`, `pms_project_id`, `status` (`ACTIVE/TERMINATED`), `refund_amount` | FK → `ad_accounts` (1 ACTIVE tại 1 thời điểm) | `pms_project_id` chỉ set khi MANAGED; % là giá trị áp dụng cho giao dịch mới |
| `ReplacementRequest` | `old_ad_account_id`, `new_ad_account_id`, `reason`, `is_customer_fault`, `balance_transferred_amount`, `state` (`PENDING/CS_ASSIGNED/BALANCE_TRANSFERRED/COMPLETED/REJECTED`) | FK → `ad_accounts` (cũ + mới) | CS gán tay; Contract không đổi; `is_customer_fault` quyết định SLA miễn phí |
| `AdAccountEvidence` | `ad_account_id`, `type` (`DIE_SNAPSHOT/PLATFORM_NOTICE/CLOSURE`), `file_ref`, `captured_at`, `hash` | FK → `ad_accounts` | Evidence store bất biến — append-only, hash-chain |
| `UtmAssignment` / naming log | `ad_account_id`, `naming_code`, `utm_source/medium/campaign`, `exception_approved_by` | FK → `ad_accounts` | Sinh tự động từ naming; ngoại lệ có change log |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-001 (`operations.md` Mục A3/B.1) và các BR tương ứng.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: OADS chỉ tạo TK khi đủ gate kép (REQ-OPS-001) | Hồ sơ `CS_APPROVED` nhưng KYC khách ≠ `Verified` | Hệ thống xử lý bước tạo AdAccount + Contract | Tạo bị chặn với mã "KYC chưa Verified"; tương tự chặn khi chưa khớp tiền; audit log ghi rõ gate nào chặn | [ ] |
| SC-002: Chỉ OPS_CONT Executive+ duyệt CONTENT (REQ-OPS-001, CMS §3.2) | `OadsRequest` ở `CONTENT_REVIEWING` | Vai tương đương INTERN/JUNIOR gọi API approve; sau đó vai EXECUTIVE+ gọi | Lời gọi đầu bị từ chối (trạng thái không đổi, vẫn sửa được nội dung); lời gọi hai chuyển sang `CONTENT_APPROVED` | [ ] |
| SC-003: Naming sai bị chặn, UTM tự sinh (REQ-OPS-001) | OPS_ADS tạo TK với naming `FMCG01-META-CONV` (thiếu Market/YYMM) | Validator CORE xử lý | API từ chối tạo; naming hợp lệ → UTM sinh tự động, mọi attempt sửa tay bị chặn + log | [ ] |
| SC-004: Campaign không gắn project tự pause (REQ-OPS-001) | Campaign phát sinh chi tiêu không gắn dự án | Job quét định kỳ chạy | Campaign bị pause (qua GW khi có API / task pause tay khi degraded); task gắn project tạo trong 4h LV; chi tiêu không hạch toán về khách tới khi gắn xong | [ ] |
| SC-005: Replacement giữ chuỗi lịch sử + Contract nguyên (REQ-OPS-001, CMS §3.11) | TK die không do lỗi khách, khách có TK dự phòng | OPS_AM gán replacement, `is_customer_fault = false` | `ReplacementRequest` đi `PENDING → CS_ASSIGNED → BALANCE_TRANSFERRED → COMPLETED`; `replacesAdAccountId` trỏ đúng TK cũ; `Contract` giữ fee schedule; SLA miễn phí áp dụng | [ ] |
| SC-006: Thu hồi quyền trong 24h (REQ-OPS-001) | HR_L1 ghi sự kiện nghỉ việc của 1 owner | Đồng hồ 24h chạy | CORE revoke quyền trước 24h; task bàn giao sinh cho backup; SYS_ADMIN thấy danh sách credentials cần rotate | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW đồng bộ số dư/spend hourly + nhãn `manual`; M-INT push GĐ2; handoff sự kiện HR_L1) |
| Màn hình UI (Command Center — WEB) | `phase4-ux/bcerp-web/adaccount-cc/[screen-group].md` |
| Domain model nguồn | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.2 OADS, §3.3 Contract, §3.4 AdAccount, §3.11 ReplacementRequest, §4 quan hệ PMS) |
| Policy nghiệp vụ | `policies/quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.2–2.4 |
| Feature liên quan cùng module | Gate đầu vào: `kyc-phap-nhan-truoc-cap-phat-tkqc.md` (FEAT-CORE-ADACC-001), `financial-hard-stop-chan-cap-phat-tkqc.md` (FEAT-CORE-ADACC-003) |
