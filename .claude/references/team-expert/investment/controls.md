# Investment Expert — Controls

> **Domain**: Investment & Asset Management
> **Sử dụng bởi**: investment-expert agent
> **Mục đích**: Limit framework, SoD matrix, KYC/AML, Chinese Wall, regulatory controls

---

## Investment Mandate & Limit Framework

### Asset Class Limits (Open-End Fund — VN Default)
| Asset Class | Min | Max | Regulatory Basis |
|-------------|-----|-----|-----------------|
| VN Listed Equity | 0% | 80% | Nghị định 155/2020 |
| Fixed Income | 20% | 100% | Fund prospectus |
| Cash & equivalents | 0% | 15% | Fund prospectus |
| Alternative assets | 0% | 10% | Fund prospectus |

### Concentration Limits
| Limit Type | Threshold | Regulatory Source |
|------------|-----------|-------------------|
| Single issuer (open-end fund) | Max 10% of NAV | UBCKNN (Luật CK 54/2019) |
| Single stock ownership | Max 5% of outstanding shares | Luật CK 54/2019 Art. 86 |
| Single sector | Max 30% of portfolio | Fund prospectus (typical) |
| VN-domiciled listed securities | Min 65% of fund | UBCKNN requirement |
| Duration (bond portfolio) | Max 5 years weighted avg | Fund-specific |
| Geographic concentration | Per investment policy | Fund mandate |

### Soft vs Hard Breach
- **Soft breach** (80–100% of limit): Warning alert → Risk Officer review → decision within 24h
- **Hard breach** (>100% of limit): Pre-trade block OR immediate escalation → CIO/CRO approval required

---

## Four-Eyes Principle (Trade Authorization)

| Order Size | Required Approvers |
|------------|-------------------|
| < 1 tỷ VND | Fund Manager alone |
| 1 tỷ – 10 tỷ VND | Fund Manager + Risk Officer sign-off |
| > 10 tỷ VND | Fund Manager + Risk Officer + CIO approval |
| New asset class (first trade) | IC (Investment Committee) approval required |
| Block trade (>100,000 shares or >1 tỷ VND) | Fund Manager + compliance pre-approval |

**Audit requirement**: Mọi approval phải có timestamp, approver ID, và rationale note.

---

## NAV Approval Matrix

| NAV Type | Approvers Required | Condition |
|----------|-------------------|-----------|
| Daily NAV | Fund Accountant + Risk Officer | 2-person sign-off bắt buộc |
| Monthly official NAV | Fund Accountant + Risk Officer + Fund Manager + CEO | 4-person for formal reporting |
| Error investigation trigger | NAV difference > 0.01% | Mandatory before publish |
| NAV restatement | Fund Manager + CRO + External auditor confirmation | Rare, board notification required |

**Error tolerance**: 0.01% NAV difference = mandatory investigation. Publication blocked until resolved.

---

## KYC/AML — Investor Onboarding

### Individual Investor
- **Documents**: CMND/CCCD, passport (if foreign), proof of address
- **Liveness check**: Selfie + document photo (automated eKYC preferred)
- **Source of funds**: Income declaration, bank statement for large investments
- **PEP screening**: Against FATF lists và domestic PEP database
- **UBCKNN registration**: Mã số nhà đầu tư, tài khoản lưu ký tại VSDC

### Corporate Investor
- **Documents**: Giấy chứng nhận đăng ký doanh nghiệp, Điều lệ công ty
- **Beneficial owner**: Identify all owners >25% — KYC required for each
- **Authorized signatory**: Board resolution + specimen signature
- **Source of funds**: Audited financial statements

### Enhanced Due Diligence (EDD)
- **Triggers**: PEP (Politically Exposed Person), high-risk country, unusual transaction pattern
- **Process**: Senior management approval required
- **Monitoring**: Enhanced transaction monitoring, annual full review
- **Documentation**: EDD file separate from standard KYC

### Ongoing Monitoring
- **Annual review**: Re-verify KYC for all investors
- **Transaction monitoring**: Pattern detection (large/unusual transactions)
- **STR (Suspicious Transaction Report)**: File với Cục Phòng chống rửa tiền (AMLA) nếu suspicious
- **Account freeze**: Compliance can freeze account pending investigation

---

## Chinese Wall (Information Barrier)

| Team | Access Restrictions |
|------|-------------------|
| Investment team (Front Office) | No access to deal advisory client list, no compliance monitoring data |
| Research team | No access to order flow data before research publication |
| Trading team (Execution) | No access to non-public information, no research pre-publication |
| IT/Systems | Segregated access — no cross-access between FO and compliance monitoring systems |
| Compliance | Read-only on operational data — no trade execution capability |

**System enforcement**:
- Separate login domains for Front Office vs Back Office vs Compliance
- Network segmentation: FO systems cannot query compliance monitoring DB
- Audit log: All cross-wall data requests logged và reviewed monthly

---

## Segregation of Duties (SoD Matrix)

| Action | Front Office | Middle Office | Back Office | Compliance |
|--------|-------------|--------------|-------------|------------|
| Create order | ✅ | ❌ | ❌ | ❌ |
| Approve pre-trade limit | ❌ | ✅ | ❌ | ❌ |
| Execute/route order | ✅ | ❌ | ❌ | ❌ |
| Confirm trade | ❌ | ❌ | ✅ | ❌ |
| Settle trade | ❌ | ❌ | ✅ | ❌ |
| Calculate NAV | ❌ | ❌ | ✅ | ❌ |
| Verify NAV | ❌ | ✅ | ❌ | ❌ |
| Approve investor subscription | ❌ | ❌ | ✅ | ✅ (KYC check) |
| Monitor limits/compliance | ❌ | ✅ | ❌ | ✅ |
| File regulatory reports | ❌ | ❌ | ❌ | ✅ |

**Key SoD violations to prevent**:
- Front Office self-settling their own trades
- Fund Accountant both calculating AND verifying NAV
- Compliance officer having trading authority
- Single person both approving and processing investor subscription

---

## UBCKNN Regulatory Requirements (Vietnam)

### Periodic Reporting
| Report | Frequency | Deadline | Format |
|--------|-----------|----------|--------|
| Danh mục đầu tư | Monthly | 5th business day of following month | UBCKNN template |
| Báo cáo tài chính | Quarterly | 45 days after quarter end | UBCKNN XML/Excel |
| Báo cáo tài chính năm | Annual | 90 days after year end | Audited, UBCKNN format |
| Net Asset Value | Daily | By 19:00 (after market close) | Published to investors |

### Event-Based Reporting
- Thay đổi Fund Manager: Report within 3 business days
- Thay đổi chiến lược đầu tư: Report within 5 business days + investor notification
- Breach of investment mandate: Report within 1 business day
- Significant redemption (>10% NAV): Report within 1 business day

### Licensing Requirements
- Công ty Quản lý Quỹ: Giấy phép hoạt động từ UBCKNN
- Fund Manager: Chứng chỉ hành nghề (CFA/CISA equivalent or VN national certificate)
- Annual reporting on key personnel changes, AUM, performance

---

## Risk Limits — Quick Reference

| Category | Limit | Alert at | Block at |
|----------|-------|----------|----------|
| Single issuer | 10% NAV | 8% | 10% |
| Single sector | 30% NAV | 25% | 30% |
| Cash minimum | 5% NAV | 7% | 5% |
| VaR 99% (1-day) | Fund-specific | 90% of limit | 100% of limit |
| Liquidity (assets sold in <5 days) | Min 70% NAV | 75% | 70% |
| Leverage | None (open-end fund per UBCKNN) | N/A | Any leverage = block |
