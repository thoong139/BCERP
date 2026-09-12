# CMS — Domain Model: Dịch vụ Tài khoản Quảng cáo (Ad Account Service)

> Tài liệu tham chiếu nghiệp vụ cho module **CMS** trong hệ ERP hợp nhất của BC Agency (PMS + CMS + TMS, Modular Monolith, NestJS + Next.js + PostgreSQL + Prisma + Redis + MinIO). Viết cho AI coding harness (Claude Code, v.v.) đọc trước khi thiết kế schema/module — đây là bản **v1, mức domain model tổng quan**, chưa phải đặc tả implementation cuối cùng.
>
> Nguồn: brainstorm trực tiếp với Nam (business owner) + phân tích website bcagency.vn + phân tích codebase CMS cũ (`cms-bcagency`, stack Vue3/Pinia + Express/MongoDB — **đã bỏ**, chỉ giữ lại tư duy nghiệp vụ, không port code/schema vì backend cũ toàn bộ dùng mock data, chưa từng persist thật).

---

## 1. Bối cảnh & phạm vi

BC Agency có 2 mảng kinh doanh khác nhau nhưng dùng chung một "nguyên liệu" là **tài khoản quảng cáo cấp Invoice/Agency** (Meta, TikTok, Google, Yandex, Bing, X, Snapchat, VK, Kwai, Bigo, Taboola, Outbrain — lấy qua quan hệ đối tác chính thức với các platform):

| | **THUÊ** (Rental) | **CHẠY HỘ** (Managed) |
|---|---|---|
| Ai vận hành campaign | Khách hàng tự chạy | Team Paid Media của BC chạy |
| Phí | 1–8% trên chi tiêu | 10–20% theo NSQC |
| Gắn với Project trong PMS? | Không | **Có** — cần AM/Planner/Paid Media vận hành theo lifecycle 30-stage |
| Vai trò CMS | Cấp + quản lý account, billing | Cấp account làm "nguyên liệu" đầu vào cho Project |

**Quy tắc cứng:** một hợp đồng (`Contract`) chỉ giữ **một** `serviceType` trong suốt vòng đời. Muốn đổi loại dịch vụ → **tất toán hợp đồng cũ (hoàn số dư trong 15 ngày làm việc) + mở hợp đồng mới**. Không cho phép sửa `serviceType` trên hợp đồng đang `ACTIVE`.

**Ngoài phạm vi bản v1 này** (để sau, đã xác nhận với Nam):
- Kho nguồn cung nội bộ: BM/BC, VIA/profile, proxy/VPS, rủi ro/ban — hiện vận hành thủ công, tham khảo SOP ở dự án "Nguyên liệu TKQC" khi cần. `ReplacementRequest` (mục 3.13) vẫn giả định CS gán tay account thay thế từ nguồn này, không tự động hoá từ kho.

---

## 2. Actors / Roles

| Role | Vai trò trong CMS |
|---|---|
| `CUSTOMER` | Khách thuê/dùng dịch vụ tài khoản quảng cáo |
| `CONTENT` (CT) | Duyệt hồ sơ/ngành hàng/giấy phép khi mở tài khoản mới (compliance theo whitelist ngành) — track 5 cấp: `CONTENT_INTERN → CONTENT_JUNIOR → CONTENT_EXECUTIVE → CONTENT_SENIOR → CONTENT_LEADER`. **Chỉ `EXECUTIVE` trở lên (Executive/Senior/Leader) có quyền bấm duyệt/từ chối OADS**; `INTERN`/`JUNIOR` chỉ soạn hồ sơ, hướng dẫn khách chỉnh sửa theo tiêu chí nền tảng rồi đẩy lên cấp gần nhất từ Executive trở lên để duyệt. |
| `CS` | Thiết lập thông số tài khoản (BC, advertiser, currency, timezone, fee schedule) sau khi Content duyệt |
| `SALE` | Tư vấn, khởi tạo quan hệ khách hàng |
| `ACCOUNTANT` (Kế toán viên) | Duyệt Recharge/Withdraw — bước 1 khi ở chế độ `DUAL` |
| `CHIEF_ACCOUNTANT` (Kế toán trưởng) | Duyệt Recharge/Withdraw — bước 2 khi ở chế độ `DUAL` |
| `CFO` | Cũng có quyền duyệt Recharge/Withdraw ở chế độ `SINGLE` (xem 3.6) |
| `ADMIN` | Cấu hình hệ thống, platform, fee mặc định, bật/tắt `approvalMode` |

---

## 3. Entities

### 3.1 `Customer`
Khách hàng thuê dịch vụ. Có quy trình duyệt hồ sơ trước khi được hoạt động (tương tự KYC).
- `status`: `PENDING_APPROVAL | APPROVED | REJECTED`
- `industry`, `taxCode`, `companyInfo`
- Một `Customer` có thể có nhiều `Wallet` (theo currency) và nhiều `Contract`.

### 3.2 `OadsRequest` (Order Ads — yêu cầu mở tài khoản mới)
State machine:
```
DRAFT → CONTENT_REVIEWING → CONTENT_APPROVED → CS_REVIEWING → CS_APPROVED
                ↓ (reject + reason + evidence)              ↓ (reject + reason + evidence)
              DRAFT (sửa & nộp lại)                        DRAFT (sửa & nộp lại)
```
`CS_APPROVED` → tạo ra 1 `AdAccount` mới + 1 `Contract` mới (ACTIVE).
- Fields: `customerId`, `platformId`, `adAccountTypeId`, `businessInfo`, `licenseDocs[]`, `rejectReason`, `rejectEvidence`
- Quyền chuyển trạng thái ở bước `CONTENT_REVIEWING`: chỉ `CONTENT_EXECUTIVE/SENIOR/LEADER` được bấm `CONTENT_APPROVED`/`CONTENT_REJECTED`. `CONTENT_INTERN/JUNIOR` chỉ được sửa nội dung hồ sơ trong lúc `CONTENT_REVIEWING`, không đổi được trạng thái.

### 3.3 `Contract`
Tách riêng khỏi `AdAccount` — lý do: khi tất toán/đổi loại dịch vụ, lịch sử fee schedule phải giữ nguyên cho các giao dịch cũ, không được sửa đè.
- `serviceType`: `RENTAL | MANAGED` (bất biến sau khi tạo)
- `feePercent`, `vatOnFeePercent`, `vatOnSpendPercent` — % **đang áp dụng cho giao dịch mới** (xem công thức mục 5)
- `pmsProjectId`: **chỉ set khi `serviceType = MANAGED`**; luôn `null` khi `RENTAL`
- `status`: `ACTIVE | TERMINATED`
- `startDate`, `endDate`, `terminationReason`, `refundAmount`
- Quan hệ: 1 `AdAccount` có đúng 1 `Contract` đang `ACTIVE` tại một thời điểm; có thể có nhiều `Contract` lịch sử (đã `TERMINATED`).

### 3.4 `AdAccount` (TKQC)
- `status`: `ACTIVE | FROZEN | BLOCKED | OUT_OF_MONEY`
- `platformId`, `adAccountTypeId`, `externalAccountId` (advertiser ID/BM ID...), `currency`, `timezone`, `country`
- `currentContractId`
- `bindInfo` (JSON, payload khác nhau theo platform: TikTok = BC + role, Google = email, Facebook = BMID)
- `pixelId` (nullable)
- Actions: `Topup`, `Reduction`, `Bind`, `Unbind`, `Clear` (rút khẩn khi bị khóa)

### 3.5 `Wallet` (ví theo currency, cấp Customer)
- `availableBalance`, `frozenBalance` — tách theo `currency` (USD/VND multi-currency, không gộp quy đổi)

### 3.6 `RechargeRequest` (nạp tiền ngoài → Wallet)
- `approvalMode`: `SINGLE | DUAL` — **1 công tắc toàn hệ thống**, `ADMIN` bật/tắt thủ công khi phòng kế toán đủ người (không theo ngưỡng số tiền, không tự động).
  - **`SINGLE`** (hiện tại): **bất kỳ ai** trong 3 role `ACCOUNTANT | CHIEF_ACCOUNTANT | CFO` duyệt 1 lần là xong — không phân biệt cấp bậc.
  - **`DUAL`** (bật sau, khi đủ người): duyệt **tuần tự theo đúng cấp bậc** — bước 1 bắt buộc do `ACCOUNTANT`, bước 2 bắt buộc do `CHIEF_ACCOUNTANT` (không được đảo thứ tự hay để cùng 1 người duyệt cả 2 bước).
- State (`SINGLE`): `PENDING → APPROVED | REJECTED`
- State (`DUAL`): `PENDING → STEP1_APPROVED (bởi ACCOUNTANT) → APPROVED (bởi CHIEF_ACCOUNTANT) | REJECTED`
- `REJECTED` → khách có thể `DISPUTED` (khiếu nại) → quay lại review
- `paymentMethod`: `VND_BANK | VND_VNPAY | USD_BANK | GLOBAL_BANK`

### 3.7 `WithdrawRequest` (Wallet → ngoài)
State: `PENDING → APPROVED (tính fee) → COMPLETED`

### 3.8 `TopupTransaction` (Wallet → AdAccount) — xem công thức chi tiết ở mục 5
- `inputMode`: `NET | GROSS` — khách chọn nhập NSQC hay Tổng tiền, hệ thống tính chiều còn lại
- Lưu **snapshot** `feePercent/vatOnFeePercent/vatOnSpendPercent` tại thời điểm giao dịch (không tham chiếu sống tới `Contract` — Contract có thể đổi % sau này mà không ảnh hưởng giao dịch cũ)
- Fields: `netAmount`, `feeAmount`, `vatOnFeeAmount`, `vatOnSpendAmount`, `grossAmount`

### 3.9 `ReductionTransaction` (AdAccount → Wallet)
State: `PENDING → APPROVED | REJECTED`

### 3.10 `RebateStatement` (mặc định TẮT, xử lý thủ công — không auto-tính)
- Thực tế: rebate **mặc định OFF cho toàn bộ `AdAccount`/`Contract`**. Số khách thực sự được rebate rất ít, nên **không** cần một job tự động tính theo bảng tier ngân sách — Finance/Admin **bật tay** (`Contract.rebateEnabled = true`) cho từng trường hợp cụ thể, rồi **tự nhập tay** `rebateAmount` khi ghi nhận (không lấy tự động từ bảng %).
- Bảng tier ngân sách trước đó (`<$2k → 0%`, ... `>$50k → 4%`) chỉ giữ lại **làm tham khảo gợi ý** khi Finance tự quyết định số rebate, **không phải công thức auto-apply**.
- Kỳ ghi nhận: theo quý (nếu có phát sinh) — nhưng đây là chu kỳ *review thủ công*, không phải chu kỳ chạy batch job tự động.
- Fields: `contractId`, `period`, `rebateAmount` (nhập tay), `note`, `approvedBy`
- Vì vậy rebate hoàn toàn tách khỏi công thức Topup ở mục 5 — không tự động, không real-time, không theo công thức cố định.

### 3.11 `ReplacementRequest` (tài khoản bị khóa không do lỗi khách)
Đi theo đúng pattern `OadsRequest` — CS gán tay, không tự động hoá từ kho nguồn cung (kho để giai đoạn sau).
- **Mục đích:** giữ đúng cam kết SLA với khách ("cấp account thay thế + chuyển số dư miễn phí") một cách có kiểm soát — có liên kết account cũ/mới để tra lịch sử, có ghi nhận số dư đã chuyển để đối soát, và có dữ liệu tần suất khóa account theo platform/khách hàng phục vụ đánh giá rủi ro vận hành.
- State machine:
  ```
  PENDING → CS_ASSIGNED (gán AdAccount mới thủ công) → BALANCE_TRANSFERRED → COMPLETED
                      ↓ (không đủ điều kiện — lỗi do khách)
                    REJECTED
  ```
- Fields: `oldAdAccountId`, `newAdAccountId`, `reason`, `isCustomerFault` (bool — quyết định có áp dụng SLA miễn phí hay không), `balanceTransferredAmount`
- `newAdAccount` giữ tham chiếu `replacesAdAccountId = oldAdAccountId` để tra chuỗi lịch sử thay thế (1 account có thể bị thay nhiều lần).
- `Contract` hiện tại của khách **không đổi** khi Replacement xảy ra — chỉ đổi `AdAccount` gắn với Contract đó, fee schedule giữ nguyên.

### 3.12 Reference data
`Platform`, `AdAccountType` (theo platform: `openingFee`, `defaultCurrency`, `requiredDocs`), `Industries` (kèm cờ whitelist/từ chối theo ngành), `Currency`, `Timezone`.

### 3.13 Org (dùng chung với PMS, không tạo lại)
`Department`, `Team`, `Employee` — tái sử dụng module tổ chức đã có trong PMS thay vì tạo entity song song.

---

## 4. Quan hệ với PMS

```
Contract.serviceType = RENTAL  →  pmsProjectId = null (khách hàng độc lập với CMS)
Contract.serviceType = MANAGED →  pmsProjectId = <Project trong PMS>
                                   (AdAccount trở thành 1 resource được Project tiêu thụ;
                                    fee 10–20% nằm ở Contract, KHÔNG tính trùng ở phía PMS)
```

---

## 5. Công thức tính phí Topup (đã xác nhận với Nam, ví dụ bằng số)

```
k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent

Nhập NSQC (net)     → grossAmount (trừ Wallet) = netAmount × k
Nhập Tổng tiền (gross) → netAmount (vào AdAccount) = grossAmount / k
```

**Ví dụ** (fee=3%, vatOnFee=8%, vatOnSpend=8% → k = 1.1124):
- Khách nhập NSQC = 1,000 → Wallet bị trừ **1,112.4** (= 1,000 + phí dịch vụ 30 + VAT/phí 2.4 + VAT/chi tiêu 80)
- Khách nhập Tổng tiền = 1,112.4 → NSQC ra = **1,000** (khớp ngược)

Rebate **không** nằm trong công thức này — xử lý riêng theo kỳ (mục 3.10).

---

## 6. Việc còn mở / phạm vi để sau

- [ ] Kho nguồn cung nội bộ (BM/VIA/proxy/risk) — để giai đoạn sau, hiện `AdAccount`/`ReplacementRequest` giả định "đã có sẵn, CS gán tay".

Tất cả các mục khác (kỳ/bảng % Rebate, điều kiện `SINGLE→DUAL` cho Recharge, thiết kế `ReplacementRequest`, track + cấp bậc duyệt `CONTENT`) đã chốt và đưa thẳng vào entity tương ứng ở mục 2–3.
