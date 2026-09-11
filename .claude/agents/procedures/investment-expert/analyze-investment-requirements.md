# Playbook: Phân tích Investment Requirements

> **Type**: Agent Procedure
> **Agent**: investment-expert
> **Triggered by**: /wf-analyze-requirements khi project có investment/fund management modules
> **Output**: `.mc-data/docs/phase1-business/investment-requirements.md`

---

## Bước 1: Xác định Fund Type và Scope

```
Đặt câu hỏi / đọc context để xác định:

Fund type:
  - Open-end fund (quỹ mở): Daily subscription/redemption, daily NAV required
  - Close-end fund (quỹ đóng): Fixed units, NAV periodic, listed on exchange
  - PE/VC fund: Capital calls, illiquid assets, IRR reporting, LP management
  - Corporate Treasury: Internal investment of company cash, no external investors
  - Family Office: Private wealth management, multi-asset, reporting to family members

Asset classes in scope:
  - VN Listed Equity (HNX/HOSE/UPCOM)
  - Fixed Income (government bonds, corporate bonds)
  - Money market instruments
  - Alternative (real estate, private equity, commodities)
  - Foreign securities (nếu có)

Regulatory scope:
  - Quỹ nội địa → tuân thủ UBCKNN (Luật CK 54/2019, Nghị định 155/2020)
  - Offshore fund (Cayman, Singapore) → jurisdiction-specific
  - Corporate investment (không phải quỹ) → internal policy only

Scale:
  - AUM hiện tại và dự kiến (tỷ VND)
  - Số lượng investors/LPs
  - Số portfolios quản lý
  - Số lệnh giao dịch trung bình/ngày
```

---

## Bước 2: Map Personas

```
READ: .claude/references/team-expert/investment/personas.md

Chọn personas relevant cho fund type:
  - Open-end/Close-end fund: Tất cả 5 personas
  - PE/VC fund: Fund Manager, Risk Officer, Fund Accountant, Compliance, LP (thay Investor)
  - Corporate Treasury: Fund Manager (Treasury), Risk Officer, Finance team (thay Fund Accountant)
  - Family Office: Portfolio Manager, Family Officer (thay Compliance), Family Members (Investor)

Với mỗi persona relevant:
  - Ghi nhận daily tasks cụ thể trong context của dự án
  - Identify pain points hiện tại (manual process, Excel, thiếu real-time data)
  - Prioritize must-have features vs nice-to-have
```

---

## Bước 3: Map Investment Process

```
READ: .claude/references/team-expert/investment/operations.md

Mapping:
  - Trade lifecycle: Các bước nào đang manual? Nào cần automate?
  - NAV cycle: Daily NAV có bắt buộc không? Timeline publish?
  - Subscription/Redemption: Tần suất, quy mô, notice period?
  - Corporate actions: Tần suất, complexity?
  - Reconciliation: Với custodian nào? Tần suất? Tolerance?

Document:
  - AS-IS process: Quy trình hiện tại (nếu existing system)
  - TO-BE process: Target process sau khi implement
  - Gap analysis: Những bước nào system sẽ automate
  - Integration points cần thiết: Bloomberg, VSDC, HNX data, ngân hàng lưu ký
```

---

## Bước 4: Xác định Controls

```
READ: .claude/references/team-expert/investment/controls.md

Mandatory controls (UBCKNN/regulatory):
  - Concentration limits (10% single issuer for open-end)
  - KYC/AML cho investor onboarding
  - Chinese Wall giữa Front Office và Compliance
  - UBCKNN periodic reporting

Operational controls (best practice):
  - Four-eyes principle cho large trades
  - NAV independent verification
  - Reconciliation exception workflow
  - Audit trail cho mọi transaction

Flag từng control:
  - REGULATED: Bắt buộc theo luật, không thể bỏ
  - BUSINESS: Best practice, cần confirm với client về priority
  - OUT_OF_SCOPE: Client explicitly loại trừ
```

---

## Bước 5: Identify Integration Points

```
Danh sách integration cần xác nhận với client:

Market data:
  - Bloomberg Terminal: Giá, analytics, news (premium)
  - HNX/HOSE data feed: End-of-day prices (cần đăng ký)
  - FiinPro / Vietstock: VN market data (alternative to Bloomberg)
  - Manual price entry: Fallback cho illiquid assets

Custody & settlement:
  - VSDC: Vietnam Securities Depository — settlement confirmation, position statement
  - Ngân hàng lưu ký: Cash account statement (daily)
  - SWIFT: Nếu có foreign securities

Trading:
  - Broker FIX gateway: Automated order routing (từng broker có FIX spec riêng)
  - Broker web portal: Manual fallback

Regulatory:
  - UBCKNN reporting portal: Submit reports (định kỳ + sự kiện)
  - AMLA (Cục Phòng chống rửa tiền): STR filing

Investor-facing:
  - Email/SMS gateway: NAV notification, statement delivery
  - eKYC provider: Liveness check, document verification
  - Payment gateway: Investor subscription/redemption cash transfer
```

---

## Bước 6: Output Requirements

```
Ghi requirements vào: .mc-data/docs/phase1-business/investment-requirements.md

REQ-ID format: REQ-INV-[MODULE]-[NNN]

Modules:
  - PORT: Portfolio Management
  - FUND: Fund Administration (NAV, unit registry)
  - RISK: Risk Management & Compliance
  - COMP: Regulatory Compliance & Reporting
  - TRADE: Order Management & Trading
  - IR: Investor Relations & Portal

Với mỗi requirement:
  - REQ-ID: REQ-INV-PORT-001
  - Mô tả: Ngắn gọn, actionable
  - Priority: P0 (blocker) / P1 (must-have) / P2 (nice-to-have)
  - Regulatory: REGULATED / BUSINESS
  - Persona: Fund Manager / Risk Officer / Fund Accountant / Compliance / Investor
  - Notes: Constraints, assumptions, open questions

Phân loại đầu ra:
  - Regulated requirements (mandatory — cannot defer)
  - Core operational requirements (must-have for go-live)
  - Enhancement requirements (post-launch backlog)
```

---

## Checklist Hoàn thành

- [ ] Fund type và regulatory scope đã xác định
- [ ] Personas relevant đã selected và documented
- [ ] Investment process đã mapped (AS-IS + TO-BE)
- [ ] Controls đã flagged (REGULATED vs BUSINESS)
- [ ] Integration points đã confirmed với client
- [ ] REQ-IDs đã gán đầy đủ (REQ-INV-[MODULE]-[NNN])
- [ ] Output file tồn tại và không rỗng
- [ ] Open questions đã liệt kê để follow up
