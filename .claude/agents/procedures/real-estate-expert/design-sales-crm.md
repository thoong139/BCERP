# Playbook: Thiết kế Sales CRM & Booking System

> **Type**: Agent Procedure
> **Agent**: real-estate-expert
> **Triggered by**: /wf-design khi cần thiết kế BĐS sales platform, booking system
> **Output**: `.mc-data/docs/phase3-architecture/real-estate/sales-crm.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design`
- Khi dự án có module bán hàng BĐS: giỏ hàng, booking, tiến độ thanh toán
- Khi thiết kế hệ thống phục vụ Developer và Broker bán căn hộ/mặt bằng

---

## Procedure

### Bước 1: Đọc context và requirements

```
INPUT: Paths do skill cung cấp qua prompt
Ưu tiên đọc:
□ REQ-RE-SALE-*, REQ-RE-PAY-*, REQ-RE-LEGAL-*, REQ-RE-COM-* từ requirements
□ .mc-data/docs/_meta/req-registry.json
□ .mc-data/docs/phase2-features/ (feature specs liên quan)

Xác định scope:
□ Loại BĐS: residential / commercial / mixed
□ Quy mô giỏ hàng: số căn, số dự án, số building
□ Số broker / sàn phân phối
□ Có customer portal không?
□ Tích hợp ngân hàng bảo lãnh không?
```

### Bước 2: Inventory Management (Giỏ hàng)

```
Hierarchy thiết kế:
  Project → Building → Floor → Unit (4 cấp)
  Hoặc: Project → Zone → Unit (3 cấp cho nhà phố, biệt thự)

Unit entity (Sales context):
  - id, project_id, building_id, floor_number
  - unit_code (ví dụ: T1-1504 = Tháp 1, tầng 15, căn 04)
  - area_sqm (thông thủy, tim tường)
  - unit_type: studio | 1BR | 2BR | 3BR | penthouse | shophouse
  - orientation, view_direction, floor_plan_image_url
  - list_price (giá niêm yết), current_price (có thể adjust theo policy)
  - status: available | held | reserved | sold | cancelled | maintenance

Status Machine:
  Available → [Hold request] → Held (max 48h)
  Held → [Deposit confirmed] → Reserved
  Held → [Timeout 48h] → Available (auto-release)
  Held → [Broker cancel] → Available
  Reserved → [SPA signed] → Sold
  Sold → [Contract cancelled] → Cancelled → Available (sau xử lý)

Floor Plan Grid View:
  - Visual grid: Mỗi căn = 1 ô màu (Available=xanh, Held=vàng, Reserved=cam, Sold=đỏ)
  - Click vào căn → Popup chi tiết (price, area, floor plan, status)
  - Filter: Tầng, loại căn, khoảng giá, hướng, trạng thái
  - Real-time sync: Khi broker A lock → broker B thấy ngay (WebSocket hoặc polling 30s)

Admin Management:
  - Batch upload inventory (Excel import)
  - Price adjustment: Thay đổi giá theo đợt, theo tầng, theo block
  - Policy per launch batch (đợt mở bán): ngày mở bán, chính sách giá, discount rules
```

### Bước 3: Booking & Hold Engine

```
Hold Request Flow:
  1. Broker chọn căn → Click "Giữ chỗ"
  2. System check: Is unit available? (real-time lock check)
     → Yes: Create Hold record, lock unit, start countdown
     → No: Show error "Căn đã được giữ bởi broker khác"
  3. Hold record:
     - hold_id, unit_id, broker_id, created_at
     - expires_at (= created_at + 48h hoặc policy duration)
     - status: active | expired | converted | cancelled

Conflict Prevention:
  - Optimistic locking: Dùng database transaction để prevent race condition
  - KHÔNG cho phép 2 hold records cùng unit_id ở status active
  - Concurrent request: Người thứ 2 nhận lỗi ngay lập tức (không queue)

Timer Display:
  - Broker thấy countdown timer trên UI (real-time)
  - Warning khi còn 6h, 1h, 30 phút
  - Expired notification: Push/email khi hết giờ và unit bị release

Deposit Confirmation Flow:
  1. Broker yêu cầu KH chuyển khoản vào Escrow Account
  2. KH chuyển khoản (có ghi mã Hold/căn hộ trong nội dung CK)
  3. Ngân hàng webhook → System nhận payment notification
  4. System match payment với hold_id
  5. Status: Held → Reserved
  6. Notify broker + KH

Auto-Release:
  - Cron job check mỗi 5 phút: Hold nào đã expired?
  - Expired → Unit status: Held → Available
  - Notify broker: "Giữ chỗ đã hết hạn cho căn [unit_code]"
  - Log: auto_release event với timestamp

Admin Override:
  - Sales Manager có thể extend hold (nhập lý do, chọn duration)
  - Approval log: who extended, when, duration, reason
  - Giới hạn: Tối đa extend 2 lần/hold
```

### Bước 4: Payment Schedule (Tiến độ Thu tiền)

```
Installment Plan Generator:
  Input:
    - GTCH (giá trị căn hộ): từ unit record
    - Policy template: Chọn từ danh sách policy theo dự án/đợt mở bán
    - Ngày ký HĐMB: để tính ngày due của từng đợt
  
  Output: Danh sách installments

  Installment entity:
    - id, contract_id, installment_number (1, 2, 3...)
    - milestone_name ("Đặt cọc", "Ký HĐMB", "Xong móng"...)
    - amount (VND), percentage (%)
    - due_date
    - status: pending | reminded | paid | overdue
    - payment_date (khi đã thanh toán), payment_reference

Policy Template structure:
  - template_id, project_id, template_name
  - installments[]: {seq, name, percentage, days_from_event, event_trigger}
  - Ví dụ standard:
    1. Đặt cọc: 5%, T+0 (ngay khi booking)
    2. Ký HĐMB: 20%, T+30 ngày từ booking
    3. Hoàn thành móng: 15%, theo milestone xây dựng
    4. Hoàn thành kết cấu: 15%, theo milestone xây dựng
    5. Hoàn thiện: 20%, theo milestone xây dựng
    6. Bàn giao: 20%, theo milestone bàn giao
    7. Nhận sổ: 5%, sau khi sổ đỏ hoàn tất

Reminder System:
  - D-7: SMS + Email "Nhắc nhở thanh toán đợt [N] - [amount] - due [date]"
  - D-1: SMS + Email cuối cùng trước hạn
  - D+1: Thông báo quá hạn (nếu chưa thanh toán)
  - D+7: Escalate lên Sales Manager, ghi vào overdue log
  - Lãi phạt: Tính tự động theo điều khoản HĐMB (VD: 0.05%/ngày)

Collection Dashboard:
  - Outstanding per unit: Đợt nào còn nợ, bao nhiêu
  - Outstanding per project: Tổng phải thu, đã thu, còn lại
  - Aging analysis: 0-7 ngày, 8-15, 16-30, >30 ngày
  - Risk flagging: Unit có overdue > 30 ngày → Cảnh báo đỏ
```

### Bước 5: Legal Document Workflow

```
KH Checklist (Legal Clearance Gate):
  Checklist template per loại KH:
  - Cá nhân VN: CCCD (còn hạn), Sổ hộ khẩu, Xác nhận tình trạng hôn nhân
  - Mua chung vợ chồng: CCCD + HK của cả 2
  - Tổ chức / Công ty: ĐKKD, CCCD người đại diện, nghị quyết HĐQT
  - Người nước ngoài: Hộ chiếu, Visa/Thẻ tạm trú, Xác nhận thu nhập từ nước ngoài
  - AML check: Tất cả → KYC verification → Flag nếu cần enhanced due diligence

  Legal gate: Không được ký HĐMB nếu checklist chưa hoàn thành 100%

Document Repository:
  - Upload: Scan PDF/JPG, max size per file (VD: 10MB)
  - Version control: Mỗi upload = 1 version, giữ lại tất cả versions
  - Access control: Legal + KH chính (download own docs only)
  - Access log: Ghi nhận ai xem/tải, khi nào, IP
  - Immutable: Không được delete, chỉ archive với approval

Template Generation (HĐMB merge):
  - Template: .docx với merge fields ({{buyer_name}}, {{unit_code}}, {{price}}...)
  - Data sources: Unit record + Buyer record + Installment schedule
  - Generate: PDF preview trước khi finalize
  - E-signature: Tích hợp ViettelCA / VNPT-CA / FPT.eSign (nếu có)

Legal Status Tracker per Transaction:
  Đặt cọc → Ký HĐMB → Công chứng → Bàn giao căn hộ → Nộp hồ sơ sổ → Nhận sổ đỏ
  
  Mỗi step:
  - status: pending | in_progress | completed | blocked
  - completed_date, completed_by
  - documents_required[], documents_uploaded[]
  - notes (lý do blocked nếu có)
  - next_action, next_action_owner
```

### Bước 6: Broker & Commission Management

```
Broker Profile:
  - broker_id, full_name, phone, email
  - company_name (sàn phân phối)
  - license_number (chứng chỉ hành nghề nếu có)
  - bank_account (để nhận hoa hồng)
  - joined_date, status (active/inactive/suspended)
  - allowed_projects[] (dự án được phân phối)
  - max_concurrent_holds (giới hạn hold đồng thời)
  - total_sold_units, total_commission_earned (KPI)

Commission Policy:
  - policy_id, project_id, batch_id (đợt mở bán)
  - rate: % trên GTCH (không phải GTCH có discount)
  - conditions: KH phải đóng >= X% GTCH mới được tính
  - payment_timing: Sau bao nhiêu ngày từ khi đủ điều kiện
  - clawback_period: Số ngày (VD: 60 ngày từ ký HĐMB)

Commission Calculation:
  Trigger: KH đóng đủ threshold → System auto-calculate:
    commission_amount = unit.gtch × policy.rate
  
  Approval Workflow:
    1. System auto-calculate → Status: Calculated
    2. KD team review → Status: Pending Verification
    3. Kế toán verify (cross-check với HĐMB, GTCH, điều kiện) → Status: Verified
    4. GĐ approve → Status: Approved
    5. Kế toán xuất payment → Status: Paid
    6. Upload payment proof → Status: Completed

Clawback Tracking:
  - Khi HĐMB bị hủy trong clawback period → Flag commission record
  - Clawback amount = commission đã paid
  - Trừ vào payment batch tiếp theo (không yêu cầu hoàn trả tiền mặt)
  - Notify broker khi clawback xảy ra

Broker Portal (self-service):
  - Xem inventory real-time (units available/held/sold per project)
  - Xem commission statement: Tổng earned, pending, paid
  - Download payment slips
  - KPI dashboard cá nhân (units sold, conversion rate, rank)
```

---

## Output checklist

```
□ Inventory data model đầy đủ (Project/Building/Floor/Unit hierarchy)
□ Status machine cho Unit (7 states)
□ Hold Engine: conflict prevention, timer, auto-release
□ Deposit confirmation flow: bank integration point
□ Installment plan generator: policy template structure
□ Reminder system: timing và channels
□ Legal document workflow: checklist gate, template generation, e-sign
□ Commission calculation: policy, dual control, clawback
□ API endpoints cho real-time sync (inventory, booking)
□ Notification system: SMS, Email, Push
□ REQ-ID mapping: mỗi design decision trỏ về REQ-RE-SALE/PAY/LEGAL/COM-*
```
