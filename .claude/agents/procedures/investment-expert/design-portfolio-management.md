# Playbook: Thiết kế Portfolio Management System

> **Type**: Agent Procedure
> **Agent**: investment-expert
> **Triggered by**: /wf-design khi cần thiết kế portfolio management, trading system
> **Output**: `.mc-data/docs/phase3-architecture/investment/portfolio-management.md`

---

## Bước 1: Portfolio Data Model

```
Thiết kế core entities:

Portfolio:
  - id: UUID (primary key)
  - name: string (display name)
  - mandate_id: FK → InvestmentMandate
  - inception_date: date
  - base_currency: enum (VND, USD, EUR)
  - benchmark_id: FK → Benchmark
  - manager_id: FK → User (Fund Manager role)
  - status: enum (active, closed, suspended)
  - fund_type: enum (open_end, close_end, pe, vc, corporate)

Position (snapshot per valuation date):
  - portfolio_id: FK → Portfolio
  - security_id: FK → Security
  - quantity: decimal(18,6)
  - avg_cost: decimal(18,4) (weighted average cost)
  - current_price: decimal(18,4)
  - market_value: decimal(18,4) (= quantity × current_price)
  - weight: decimal(6,4) (% of portfolio NAV)
  - valuation_date: date
  - currency: string (security currency)
  - fx_rate: decimal(10,6) (if non-base currency)

Transaction:
  - id: UUID
  - portfolio_id: FK → Portfolio
  - security_id: FK → Security
  - trade_type: enum (buy, sell, subscription, redemption, dividend, corporate_action)
  - quantity: decimal(18,6)
  - price: decimal(18,4)
  - trade_date: date
  - settle_date: date
  - settlement_status: enum (pending, settled, failed)
  - broker_id: FK → Broker (nullable)
  - order_id: FK → Order
  - created_by: FK → User
  - approved_by: FK → User (four-eyes)

InvestmentLimit:
  - portfolio_id: FK → Portfolio
  - limit_type: enum (issuer, sector, asset_class, geography, duration, cash)
  - dimension_value: string (e.g., "VCB" for issuer, "banking" for sector)
  - threshold_pct: decimal(6,4) (max % of NAV)
  - soft_breach_pct: decimal(6,4) (alert threshold)
  - current_value_pct: decimal(6,4) (real-time calculation)
  - status: enum (ok, soft_breach, hard_breach)
```

---

## Bước 2: Real-Time Position Tracking

```
Price feed architecture:
  - Primary: HNX/HOSE data feed (end-of-day, 16:00+)
  - Secondary: Bloomberg API (real-time, premium tier)
  - Fallback: Manual price entry (for illiquid assets)
  - Price staleness alert: If price > 1 business day old → flag

Mark-to-market calculation:
  - market_value = quantity × current_price × fx_rate (for non-VND)
  - portfolio_nav = Σ(market_value) + cash - accrued_liabilities
  - position_weight = market_value / portfolio_nav

P&L calculation:
  - Realized P&L: (sell_price - avg_cost) × quantity_sold
  - Unrealized P&L: (current_price - avg_cost) × quantity_held
  - Total P&L: Realized + Unrealized
  - P&L attribution: By security, by sector, by asset class

Multi-currency handling:
  - FX rates: Daily ECB/SBV rates, stored per date
  - FX P&L: Separated from investment P&L
  - Base currency consolidation: All positions converted to VND for reporting
```

---

## Bước 3: Performance Attribution (Brinson Model)

```
Benchmark configuration:
  - Supported: VN-Index, VN30, HNXINDEX, custom blend (weighted)
  - Custom blend: e.g., 70% VN30 + 30% VN Government Bond Index
  - Rebalancing: Benchmark weights updated daily from index provider

Brinson attribution calculation:
  - Allocation effect: (wp_i - wb_i) × (rb_i - rb_total)
    [Where: wp = portfolio weight, wb = benchmark weight, rb = benchmark return]
  - Selection effect: wb_i × (rp_i - rb_i)
    [Where: rp = portfolio return for sector i, rb = benchmark return for sector i]
  - Interaction effect: (wp_i - wb_i) × (rp_i - rb_i)

Performance periods:
  - Daily, MTD, QTD, YTD, 1Y, 3Y, 5Y, Since Inception
  - Annualized for periods > 1 year

Risk-adjusted metrics:
  - Sharpe ratio: (Rp - Rf) / σp [Rf = SBV deposit rate as proxy]
  - Sortino ratio: (Rp - Rf) / σd [σd = downside deviation]
  - Information ratio: Active return / Tracking error
  - Maximum drawdown: Peak-to-trough over period

Peer comparison:
  - Category peer group (open-end equity, balanced, fixed income)
  - Percentile ranking within peer group
  - Source: Morningstar VN hoặc internal calculation
```

---

## Bước 4: Order Management System (OMS)

```
Order creation:
  Fields: portfolio_id, security_id, direction (buy/sell), quantity OR value,
          order_type (market/limit/ATC), price (for limit), validity (day/GTC),
          notes, created_by

Pre-trade compliance check (automated, blocking):
  1. Mandate check: Would this trade breach any investment mandate limit?
  2. Limit check: Post-trade limit utilization (simulate trade impact)
  3. Cash check: Sufficient cash for buy orders?
  4. Four-eyes check: Is order above threshold requiring second approver?
  5. Chinese Wall check: Is security on restricted list?

Workflow states:
  DRAFT → PENDING_APPROVAL (if >1B VND) → APPROVED → ROUTING → SENT_TO_BROKER
  → PARTIALLY_FILLED / FILLED → CONFIRMED → SETTLED

Execution:
  - FIX protocol gateway (for brokers supporting FIX 4.2/4.4)
  - Manual routing: OMS generates order sheet for phone/portal execution
  - Execution report: Capture fill price, quantity, broker commission

Post-trade processing:
  - Auto-create Transaction record from confirmed order
  - Update Position (quantity, avg_cost)
  - Trigger P&L recalculation
  - Send trade confirmation to Middle Office
  - Schedule settlement tracking (T+2 for equity)
```

---

## Bước 5: Risk Dashboard

```
Real-time limit monitoring:
  - Dashboard: Gauge chart per limit category (green/amber/red)
  - Alert: Email + in-app notification on soft breach
  - Block: System blocks trade on hard breach (requires CIO override)
  - History: Limit utilization over time (chart)

VaR calculation:
  - Method: Historical simulation (250-day lookback)
  - Confidence levels: 95% and 99%
  - Horizon: 1-day
  - VaR by portfolio, by asset class, by security
  - Backtesting: # of exceedances over last 250 days

Concentration heatmap:
  - By sector: Table + heatmap visual (weight vs limit)
  - By issuer: Top 10 holdings + concentration ratio
  - By asset class: Allocation chart vs mandate ranges

Stress testing:
  - Predefined scenarios: VN market -20%, interest rate +200bps, FX -10%
  - Custom scenario: User-defined shock to any factor
  - Output: Portfolio P&L impact, limit breach simulation
  - Save and schedule: Run scenarios periodically, compare over time

Liquidity risk:
  - ADV (Average Daily Volume): Position size vs 20-day ADV
  - Days-to-liquidate: Estimated liquidation period assuming 20% ADV participation
  - Liquidity score: % of portfolio liquidatable within 5 days
```

---

## Checklist Thiết kế Portfolio Management

- [ ] Data model đủ entities (Portfolio, Position, Transaction, InvestmentLimit)
- [ ] Price feed architecture rõ ràng (primary, secondary, fallback, staleness)
- [ ] P&L calculation (realized, unrealized, multi-currency)
- [ ] Brinson attribution được thiết kế đúng (allocation + selection + interaction)
- [ ] OMS workflow states đầy đủ với pre-trade checks
- [ ] Pre-trade compliance checks tự động blocking
- [ ] Four-eyes enforcement trong OMS workflow
- [ ] Risk dashboard: limit gauges, VaR, concentration, stress test
- [ ] Chinese Wall enforced tại API/role level (không chỉ UI)
- [ ] Output file tồn tại tại đường dẫn đã chỉ định
