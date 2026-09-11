# Insurance Operations

> Reference file cho insurance-expert agent
> Load file này khi cần phân tích policy lifecycle, claims process, underwriting workflow

## 1. Policy Lifecycle

Vòng đời hợp đồng bảo hiểm từ Quote đến Closure:

| Bước | Tên giai đoạn | Mô tả | Actor chính | STP Potential |
|------|---------------|-------|-------------|---------------|
| 1 | **Quote** | KH cung cấp thông tin rủi ro → hệ thống tính phí | Agent / Policyholder | High (rule-based pricing) |
| 2 | **Application** | KH điền đơn, cung cấp tài liệu KYC và y tế (nếu nhân thọ) | Agent / Policyholder | Medium (eKYC) |
| 3 | **Underwriting** | UW review, risk scoring, accept/rate/decline | Underwriter | Medium (auto-accept for low risk) |
| 4 | **Binding** | Coverage effective, premium payment confirmed | Finance / System | High |
| 5 | **Policy Issuance** | Policy document generated and delivered | System | High (auto-generation) |
| 6 | **Premium Collection** | Annual/semi-annual/quarterly/monthly installments | Finance / Policyholder | High (auto-debit) |
| 7 | **Policy Service** | Endorsement, beneficiary change, address change | Agent / Policyholder | Medium |
| 8 | **Renewal** | Reminder 60 days before, new quote, KH confirm | System / Agent | High (auto-renewal) |
| 9 | **Lapse/Cancellation** | Non-payment → Grace period → Lapse; hoặc KH cancel | System / Policyholder | Medium |
| 10 | **Reinstatement** | Within window, with health declaration if life | Underwriter / Policyholder | Low (manual review) |

### Policy Status State Machine

```
[NEW APPLICATION]
      ↓
  [IN_UNDERWRITING] → [DECLINED]
      ↓
  [PENDING_PAYMENT]
      ↓
  [IN_FORCE] ←────────────────────────┐
      ↓                               |
  [GRACE_PERIOD] (30 days non-payment)|
      ↓                               |
  [LAPSED] ──── [REINSTATED] ─────────┘
      |
  [CANCELLED] (KH-initiated)
      |
  [EXPIRED] (End of term)
```

---

## 2. Claims Lifecycle

Quy trình xử lý bồi thường từ FNOL đến Closure:

| Bước | Tên giai đoạn | Mô tả | Actor | SLA |
|------|---------------|-------|-------|-----|
| 1 | **FNOL** | First Notice of Loss (phone/portal/agent) | Policyholder / Agent | Ngay lập tức |
| 2 | **Claim Registration** | Assign claim number, adjuster assignment | System / Claims Supervisor | < 4 giờ |
| 3 | **Coverage Verification** | Policy in-force, event within coverage, no exclusions | Claims Adjuster | < 1 ngày |
| 4 | **Investigation** | Document collection, site visit if needed | Claims Adjuster / Investigator | 3-7 ngày |
| 5 | **Fraud Screening** | Pattern check, blacklist check, fraud score | System / Senior Adjuster | Concurrent với Investigation |
| 6 | **Coverage Decision** | Covered / Partially covered / Denied / Excluded | Claims Adjuster + Supervisor | < 10 ngày |
| 7 | **Settlement Calculation** | Loss assessment, deductible, co-insurance | Claims Adjuster | < 14 ngày |
| 8 | **Approval** | Per authority matrix based on amount | Per claims authority | < 3 ngày |
| 9 | **Payment** | Bank transfer to claimant or repair shop/hospital | Finance | < 5 ngày sau approval |
| 10 | **Closure** | Documentation finalized, reserve released | Claims Adjuster | Ngay sau payment |
| 11 | **Subrogation** | Pursue liable third party if applicable | Legal / Claims | Post-closure |

### Claim Status State Machine

```
[FNOL_RECEIVED]
      ↓
  [REGISTERED] → assigned claim number, adjuster
      ↓
  [UNDER_INVESTIGATION]
      ↓
  [PENDING_COVERAGE_DECISION]
      ↓
  [APPROVED] ────── [PARTIALLY_APPROVED]
      |                    |
  [DENIED] ←──────────────┘
      |
  [PENDING_PAYMENT]
      ↓
  [PAID]
      ↓
  [CLOSED]
      |
  [SUBROGATION_PENDING] (nếu có third-party liability)
```

---

## 3. Underwriting Process

### Flow tổng quát

```
Application received
      ↓
Completeness check (tài liệu đủ không?)
      ↓
Risk scoring (automatic)
      ↓
  [Score LOW]     [Score MEDIUM]    [Score HIGH]
  Auto-accept     Manual UW review   Senior UW + Reinsurer
      ↓               ↓                    ↓
  Bind at         Accept/Rate/       Accept with special terms
  standard rate   Conditional/       or Decline
                  Decline
```

### Rating Factors phổ biến

| Line of Business | Rating Factors chính |
|-----------------|---------------------|
| **Motor** | Xe loại gì, năm sản xuất, địa điểm, lịch sử tai nạn, tuổi lái xe |
| **Property** | Vị trí, loại xây dựng, mục đích sử dụng, lịch sử claim, bảo vệ chống cháy |
| **Life/Health** | Tuổi, giới tính, nghề nghiệp, tình trạng sức khỏe, sum insured |
| **Marine** | Loại hàng, tuyến đường, phương tiện vận chuyển, đóng gói |
| **Liability** | Ngành nghề, doanh thu, số nhân viên, lịch sử kiện tụng |

### Underwriting Decision Types

| Decision | Điều kiện | Hành động |
|----------|-----------|-----------|
| **Standard** | Risk score trong ngưỡng cho phép | Issue at standard premium |
| **Rated** | Risk above standard nhưng acceptable | Issue with premium surcharge (tính %) |
| **Conditional** | Specific risks excluded | Issue with named exclusions |
| **Declined** | Risk vượt tolerance | No coverage, decline letter |
| **Referred** | Sum insured > retention limit | Gửi cho reinsurer, wait for approval |

---

## 4. Reinsurance Operations

### Treaty Reinsurance (Cố định theo hợp đồng)

| Loại | Cơ chế | Khi dùng |
|------|--------|----------|
| **Proportional (Quota Share)** | Chia cố định % premium và % claim | Mở rộng capacity, start-up |
| **Proportional (Surplus)** | Reinsurer nhận phần trên retention | Lines với sum insured biến động lớn |
| **Non-Proportional (Excess of Loss)** | Reinsurer trả khi claim vượt ngưỡng | Catastrophe protection |
| **Non-Proportional (Stop Loss)** | Reinsurer trả khi loss ratio vượt % | Aggregate protection |

### Facultative Reinsurance (Từng risk cụ thể)

- Kích hoạt khi: Individual risk > Company retention limit
- Process: Prepare risk submission → Submit to reinsurer(s) → Negotiate → Bind
- Bordereau: Monthly reporting của tất cả risks đã ceded cho reinsurer

---

## 5. Distribution Channel Operations

| Channel | Đặc điểm vận hành | KPI chính |
|---------|-------------------|-----------|
| **Direct Sales** | Bán trực tiếp tại văn phòng hoặc telesales | Conversion rate, AHT |
| **Agency** | Đại lý cá nhân, hưởng hoa hồng | Policies/agent, renewal rate |
| **Broker** | Công ty môi giới, đại diện KH | Volume, placement ratio |
| **Bancassurance** | Bán qua ngân hàng đối tác | Penetration rate, cross-sell % |
| **Digital/Insurtech** | App/web, fully digital, rule-based UW | STP rate, CAC, NPS |

---

## 6. KPIs Quan trọng

| KPI | Formula | Target thông thường | Alert khi |
|-----|---------|---------------------|-----------|
| **Loss Ratio** | Claims Incurred / Earned Premium | < 60-70% | > 75% |
| **Combined Ratio** | (Claims + Expenses) / Premium | < 100% | > 105% |
| **Claims Settlement Ratio** | Settled / Total Claims | > 90% within 30 days | < 80% |
| **STP Rate** | Auto-processed / Total | > 60% (non-life), > 40% (life) | < 40% |
| **Policy Renewal Rate** | Renewed / Due for Renewal | > 80% (personal lines) | < 70% |
| **Agent Productivity** | New Policies / Active Agents | Benchmark by LoB | - 20% vs prior year |
| **Claim Fraud Detection Rate** | Flagged-and-confirmed / Total | > 5% of investigated | Drop below trend |
| **Reserve Adequacy** | Actual vs Estimated at closure | < 10% variance | > 15% variance |
