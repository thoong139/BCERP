# Investment Expert — Personas

> **Domain**: Investment & Asset Management
> **Sử dụng bởi**: investment-expert agent
> **Mục đích**: Chi tiết 5 personas cho hệ thống quỹ đầu tư và quản lý tài sản tại Việt Nam

---

## Persona 1 — Fund Manager / Portfolio Manager

**Profile**: Investment decision maker, P&L owner, research-driven, data-heavy user

**Daily tasks**:
- Review portfolio positions và P&L buổi sáng trước khi thị trường mở
- Analyze market data, research reports, macro indicators
- Make buy/sell decisions, monitor vs benchmark
- Attend Investment Committee (IC) meetings cho positions lớn
- Review risk reports từ Middle Office

**Key decisions**:
- Asset allocation và rebalancing
- Position sizing, sector rotation
- Stop-loss và profit-taking thresholds
- New asset class / new instrument approval (via IC)

**Pain points**:
- Data scattered (Bloomberg, internal system, Excel workbooks)
- Slow P&L calculation — thường T+1 thay vì real-time
- Manual risk reports từ Middle Office — không có real-time view
- Order entry thủ công, dễ nhầm lẫn

**Must-have**:
- Real-time portfolio dashboard (positions, P&L, sector breakdown)
- Performance attribution vs benchmark (Brinson model)
- What-if analysis: simulate impact of a trade before execution
- Integrated order management (tạo order → pre-trade check → route)
- Mobile view cho monitoring ngoài giờ

---

## Persona 2 — Risk Officer / Middle Office

**Profile**: Independent risk oversight, reports to CRO, không có trading authority

**Daily tasks**:
- Monitor limit utilization (sector, issuer, asset class, liquidity)
- Calculate VaR hàng ngày (historical simulation)
- Review concentration risk, stress test portfolio
- Prepare daily/weekly risk report cho management
- Validate NAV trước khi publish (independent verifier)

**Key decisions**:
- Breach escalation (soft breach → warning, hard breach → block)
- Limit adjustment recommendations (trình CRO)
- Risk appetite review định kỳ
- Sign-off NAV (cùng Fund Accountant)

**Pain points**:
- Risk data delayed (T+1) — limit breach phát hiện quá muộn
- Manual aggregation từ nhiều sources
- Không có automated limit alerts — phải chạy Excel macro
- VaR tính trong Excel, prone to error

**Must-have**:
- Real-time limit monitoring dashboard với alert ngưỡng
- Automated VaR calculation (95% và 99% confidence)
- Pre-trade compliance check engine
- Stress testing module (custom scenarios)
- Audit trail cho mọi breach và resolution

---

## Persona 3 — Fund Accountant / Administrator

**Profile**: Back Office, NAV production, reconciliation, investor reporting

**Daily tasks**:
- Collect price feeds (SSI, HNX data, Bloomberg for foreign assets)
- Calculate accruals (management fee, performance fee, dividends)
- Apply corporate actions (dividend, split, rights issue)
- Produce daily NAV và submit for sign-off
- Reconcile with custodian (VSDC) và bank
- Generate investor statements (monthly standard, ad hoc on request)

**Key decisions**:
- Pricing methodology for illiquid assets
- Accrual methodology (linear vs event-based)
- Error investigation và resolution

**Pain points**:
- Manual price collection từ nhiều sources — time-consuming và error-prone
- Reconciliation differences với custodian thường xảy ra, khó trace
- Statement generation mất nhiều giờ mỗi tháng
- Corporate action apply thủ công — dễ nhầm ex-date

**Must-have**:
- Automated price feeds với fallback pricing
- Reconciliation engine với exception workflow
- NAV production workflow (checklist, sign-off, publish)
- Investor statement auto-generation (PDF, email)
- Corporate action management module

---

## Persona 4 — Compliance Officer

**Profile**: Regulatory compliance, KYC/AML, UBCKNN reporting, insider trading monitoring

**Daily tasks**:
- Monitor insider trading alerts
- Review KYC documents cho new investors
- Prepare regulatory reports cho UBCKNN (monthly, quarterly)
- Maintain insider trading watchlist
- Review pre-trade compliance exceptions

**Key decisions**:
- KYC approve / reject / escalate to senior management
- STR (Suspicious Transaction Report) filing
- Regulatory exemption requests

**Pain points**:
- Manual KYC document review — không có digital workflow
- UBCKNN report format thay đổi thường xuyên
- Không có automated insider trading monitoring
- Audit trail phân tán — khó tra cứu khi bị kiểm tra

**Must-have**:
- KYC/AML digital workflow (document upload, checklist, approval)
- Automated UBCKNN regulatory report generation
- Insider trading watchlist management + automated alerts
- Audit trail tập trung, searchable
- Compliance calendar với deadline reminders

---

## Persona 5 — Investor / Limited Partner (LP)

**Profile**: End investor, cần transparency về performance và liquidity

**Daily tasks**:
- Check portfolio value và NAV per unit
- Review monthly/quarterly statements
- Track capital calls (PE/VC) và distributions
- Request redemptions hoặc subscriptions

**Key decisions**:
- Additional investment decision
- Redemption request (với cooling-off period)
- Reinvestment choice (distributions)

**Pain points**:
- Statements delayed (T+3 trở lên)
- Không có self-service — phải gọi điện để hỏi balance
- Không có real-time view của fund performance
- Document requests (prospectus, annual report) phải email

**Must-have**:
- Investor portal với real-time NAV và portfolio value
- Historical performance charts (since investment, vs benchmark)
- Statement download (PDF, filter by period)
- Self-service: redemption request, bank update, document access
- Capital account statement (PE/VC): contributions, distributions, NAV, IRR
