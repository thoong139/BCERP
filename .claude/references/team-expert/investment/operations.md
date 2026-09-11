# Investment Expert — Operations

> **Domain**: Investment & Asset Management
> **Sử dụng bởi**: investment-expert agent
> **Mục đích**: Investment process, NAV cycle, trade lifecycle, KPIs cho hệ thống tại Việt Nam

---

## Investment Process Flow

1. **Investment Mandate review** — Asset class limits, geography, risk budget (annual/quarterly review)
2. **Research & Idea Generation** — Analyst recommendation, market screening, macro analysis
3. **Investment Committee (IC) approval** — Required for positions above threshold (defined in mandate)
4. **Order Generation** — Front Office creates order in OMS (security, direction, quantity, price)
5. **Pre-trade compliance check** — Limit check, mandate check, cash availability check
6. **Order Execution** — Route to broker via FIX protocol hoặc manual phone order
7. **Trade Confirmation** — Counterparty confirmation (broker confirmation)
8. **Settlement** — T+2 for VN equity (HNX/HOSE), T+1 for bonds; via VSDC
9. **Accounting** — Back Office posts trade to books (cost, position update)
10. **Reconciliation** — Internal positions vs Custodian (VSDC) vs Broker confirmation

---

## Daily NAV Production Cycle (Open-End Fund)

| Thời gian | Hoạt động | Owner |
|-----------|-----------|-------|
| 16:00 | Market close, price feeds received (SSI, HNX data) | Fund Accountant |
| 16:30 | Accruals calculated (management fee, performance fee, dividends) | Fund Accountant |
| 17:00 | Corporate actions applied (dividend, split, rights) | Fund Accountant |
| 17:30 | NAV calculation run | System |
| 18:00 | Fund Accountant review và sign-off | Fund Accountant |
| 18:30 | Risk Officer independent verification | Risk Officer |
| 19:00 | NAV published to investors (via portal/SMS) | System |
| T+1 | Reconciliation with custodian (VSDC) | Fund Accountant |

**NAV Formula**: `NAV = (Total Assets - Total Liabilities) / Units Outstanding`

**Accrual types**:
- Management fee: Daily accrual = AUM × annual_rate / 365
- Performance fee: HWM (High Water Mark) based — accrued khi NAV vượt HWM
- Fund expenses: Audit fee, custodian fee, legal fee — straight-line accrual

---

## Trade Lifecycle — VN Market Specifics

**Trading hours**:
- HNX/HOSE: 9:00–11:30, 13:00–14:30
- ATC session: 14:30–14:45 (Automatic Trading Close)

**Order types**:
- Market Order (MP): Best available price
- Limit Order (LO): Specified price hoặc better
- ATC: At closing price
- MOK (Market-Or-Kill): Fill at market or cancel
- MAK (Market-And-Kill): Partial fill then cancel remainder

**Settlement**:
- Equity (HNX/HOSE): T+2
- Government bonds: T+1
- Corporate bonds: T+1 or T+2 depending on market

**Custody**: VSDC (Vietnam Securities Depository and Clearing Corporation)
- Mọi securities phải được lưu ký tại VSDC hoặc ngân hàng lưu ký thành viên
- Block trade: Min 100,000 shares hoặc 1 tỷ VND value

---

## Subscription / Redemption Process (Open-End Fund)

**Subscription flow**:
1. Investor submits application (portal hoặc paper)
2. AML/KYC check (automated screening + manual review nếu flagged)
3. Fund Accountant review và approve
4. Unit allocation at next NAV after D-day (T+1 or T+2 tùy fund)
5. Confirmation sent to investor (email + portal)

**Redemption flow**:
1. Investor submits redemption request (portal hoặc form)
2. Cooling-off period check (nếu applicable)
3. Redemption processed at next NAV
4. Cash payment T+3 từ ngày NAV
5. Confirmation và statement updated

**Large redemption rules**:
- Notice period: 3–5 business days cho redemptions >5% NAV
- Liquidity gate: Fund Manager có thể impose 10% gate nếu liquidity stress
- Gate applies proportionally to all redeeming investors trong period

---

## Capital Call & Distribution Process (PE/VC Fund)

**Capital call**:
1. Investment opportunity identified và IC approved
2. Capital call notice sent to LPs (10–15 business days notice)
3. LP wires capital to fund collection account
4. Fund deploys capital into investment
5. LP capital account updated

**Distribution**:
1. Liquidity event (exit, dividend, partial sale)
2. Fund Manager calculates distributable amount
3. Distribution notice sent to LPs
4. Wire transfer to LP accounts
5. LP capital account updated (return of capital vs profit)

**PE/VC KPIs**:
- IRR (Internal Rate of Return): Annualized return on investment
- TVPI (Total Value to Paid-In): (NAV + Distributions) / Capital Called
- DPI (Distributions to Paid-In): Distributions / Capital Called
- RVPI (Residual Value to Paid-In): NAV / Capital Called

---

## KPIs — Fund Performance

| KPI | Description | Frequency |
|-----|-------------|-----------|
| NAV per unit | Market value per unit | Daily |
| Fund return | Total return vs inception | Daily/Monthly |
| Return vs benchmark | Active return (alpha) | Daily/Monthly |
| Sharpe ratio | Risk-adjusted return | Monthly |
| Sortino ratio | Downside-adjusted return | Monthly |
| Information ratio | Alpha / Tracking error | Monthly |
| VaR 95% | Value at Risk, 1-day | Daily |
| VaR 99% | Value at Risk, 1-day | Daily |
| Limit utilization | % of limit used per category | Real-time |
| Subscription/Redemption | Net flows | Daily |
| Reconciliation breaks | # of open breaks | Daily |
| UBCKNN report status | Submitted on time | Per deadline |

---

## Integration Points

| System | Data | Direction |
|--------|------|-----------|
| HNX/HOSE data feed | End-of-day prices, corporate actions | Inbound |
| Bloomberg Terminal | Prices, analytics, news | Inbound |
| FiinPro | VN market data, financial statements | Inbound |
| VSDC | Custody positions, settlement confirmation | Bidirectional |
| Ngân hàng lưu ký | Cash positions, bank statements | Inbound |
| Broker FIX gateway | Order routing, execution reports | Bidirectional |
| UBCKNN portal | Regulatory report submission | Outbound |
| Payment gateway | Investor fund transfers | Bidirectional |
