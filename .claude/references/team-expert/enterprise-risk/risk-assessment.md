# Enterprise Risk Management - Risk Assessment Methods

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: ISO 31000:2018, IRM Risk Assessment Standards, Basel Operational Risk Framework

---

## 1. Risk Identification Methods

### 1a. Facilitated Workshops
Phương pháp phổ biến nhất — nhóm experts cùng identify risks.

**Structured Facilitation Guide:**
```
Chuẩn bị (1 tuần trước):
- Xác định scope: business unit / process / project
- Gửi pre-read: risk universe, previous risk register, industry risk reports
- Invite đúng stakeholders: process owners, SMEs, risk manager, facilitator

Trong workshop (2-3 giờ):
Step 1 (15 min): Context setting — mục tiêu cần bảo vệ là gì?
Step 2 (60 min): Brainstorm — "Gì có thể ngăn cản chúng ta đạt mục tiêu?"
  → Round-robin / silent brainstorm / sticky notes
  → KHÔNG đánh giá trong bước này
Step 3 (30 min): Group và deduplicate
Step 4 (45 min): Sơ bộ score likelihood × impact
Step 5 (15 min): Next steps, owners, deadlines

Sau workshop (1 tuần):
- Risk Manager compile và validate scores
- Circulate draft risk register cho participants review
- Finalize và add vào enterprise risk register
```

### 1b. PESTLE Analysis — Strategic Risk Identification
Áp dụng cho top-down strategic risk identification, phù hợp với CRO/Board level.

| Factor | Câu hỏi cần đặt | Ví dụ risks |
|--------|-----------------|-------------|
| **Political** | Chính sách, quan hệ ngoại giao, ổn định chính trị | Thay đổi chính sách FDI, trade war |
| **Economic** | Tăng trưởng GDP, lạm phát, tỷ giá, lãi suất | Suy thoái, VND mất giá |
| **Social** | Nhân khẩu học, văn hóa tiêu dùng, lao động | Thiếu nhân lực kỹ thuật cao |
| **Technological** | Công nghệ mới, digitalization, cyber | AI disruption, data breach |
| **Legal** | Luật mới, quy định, enforcement | Nghị định mới về data protection |
| **Environmental** | Khí hậu, thiên tai, ESG pressure | Lũ lụt miền Nam, carbon tax |

### 1c. Process Mapping — Operational Risk Identification
Áp dụng cho bottom-up operational risk identification.
- Vẽ process flow cho từng core business process
- Tại mỗi bước: "Gì có thể sai? Input sai? Người làm sai? System fail?"
- Identify: single points of failure, manual handoffs, external dependencies

### 1d. Bow-Tie Analysis
Phương pháp phân tích sâu cho critical risks.

```
THREATS                    EVENT                   CONSEQUENCES
(nguyên nhân)           (rủi ro chính)             (tác động)
─────────────           ──────────────             ─────────────
IT system failure  →\                            → Revenue loss
Power outage      → → [System Downtime] → → → → Financial penalty
Cyber attack      →/                            → Reputation damage
                   ↑                    ↑
             Preventive            Corrective
              Controls              Controls
         (ngăn ngừa nguyên nhân) (giảm hậu quả)
```

### 1e. Near-Miss Reporting
- Definition: Sự kiện gần xảy ra tổn thất nhưng không xảy ra — nguồn thông tin quý giá
- Yêu cầu văn hóa "no-blame": khuyến khích báo cáo, không phạt người báo cáo
- Phân tích systematic: mỗi near-miss có root cause analysis

---

## 2. Risk Analysis — Scoring Methodology

### 2a. 5×5 Risk Matrix: Likelihood × Impact

**Likelihood Scale:**

| Score | Level | Định nghĩa | Tần suất |
|-------|-------|------------|---------|
| 5 | Almost Certain | Gần như chắc chắn xảy ra | >80% xác suất / Đã xảy ra nhiều lần |
| 4 | Likely | Có khả năng cao xảy ra | 60-80% / Đã xảy ra trong 2 năm qua |
| 3 | Possible | Có thể xảy ra | 40-60% / Đã xảy ra trong 5 năm qua |
| 2 | Unlikely | Ít khả năng nhưng không loại trừ | 20-40% / Đã xảy ra trong 10 năm qua |
| 1 | Rare | Chỉ xảy ra trong hoàn cảnh đặc biệt | <20% / Chưa từng xảy ra trong ngành |

**Impact Scale (đánh giá theo chiều cao nhất trong 3 dimensions):**

| Score | Level | Financial | Operational | Reputational |
|-------|-------|-----------|-------------|--------------|
| 5 | Catastrophic | >10% revenue / bankruptcy risk | Core operations down >72h | National/international crisis, regulatory action |
| 4 | Major | 5-10% revenue | Core operations down 24-72h | Tier-1 media, customer churn >10% |
| 3 | Moderate | 1-5% revenue | Core operations down 4-24h | Local media, some customer complaints |
| 2 | Minor | 0.1-1% revenue | Degraded service <4h | Internal reputation impact only |
| 1 | Insignificant | <0.1% revenue | Minimal disruption <1h | Negligible external impact |

**Risk Score Matrix (Likelihood × Impact):**

```
         Impact →
         1    2    3    4    5
    5  [ 5]  [10]  [15]  [20]  [25]  ← Almost Certain
    4  [ 4]  [ 8]  [12]  [16]  [20]  ← Likely
L   3  [ 3]  [ 6]  [ 9]  [12]  [15]  ← Possible
    2  [ 2]  [ 4]  [ 6]  [ 8]  [10]  ← Unlikely
    1  [ 1]  [ 2]  [ 3]  [ 4]  [ 5]  ← Rare

[ 1-6 ] = LOW (Green)
[ 7-12] = MEDIUM (Amber)
[13-19] = HIGH (Red)
[20-25] = CRITICAL (Dark Red)
```

### 2b. Velocity Factor
Velocity đo tốc độ risk materializes — quan trọng vì ảnh hưởng đến response strategy.

| Velocity | Định nghĩa | Ví dụ | Response implication |
|----------|-----------|-------|---------------------|
| **Rapid** | Xảy ra trong giờ/ngày | Cyber attack, system crash | Pre-defined playbook, automated response |
| **Moderate** | Xảy ra trong tuần/tháng | Market downturn, key person leaving | Action plans, monitoring |
| **Slow** | Xảy ra trong tháng/năm | Regulatory change, technology obsolescence | Strategic planning, gradual mitigation |

> Rapid velocity risks với High/Critical score cần immediate response playbook, không chỉ action plan.

---

## 3. KRI (Key Risk Indicator) Design

### 3a. Definition
- **Leading KRI**: Cảnh báo TRƯỚC khi risk materializes (tiên đoán)
- **Lagging KRI**: Đo lường SAU KHI risk đã xảy ra (kết quả)
- Best practice: Kết hợp cả leading (cảnh báo sớm) và lagging (confirm trend)

### 3b. KRI Examples per Risk Category

**Strategic Risk KRIs:**
- Market share change (% quarter-over-quarter) — Leading
- Customer Net Promoter Score (NPS) — Leading
- Revenue concentration (% from top 3 customers) — Leading/Lagging

**Financial Risk KRIs:**
- Current ratio (Current Assets / Current Liabilities) — Leading (target: >1.5)
- Days Sales Outstanding (DSO) — Leading (target: <45 days)
- FX exposure as % of revenue — Leading

**Operational Risk KRIs:**
- Operational incident count (monthly) — Lagging
- System uptime % — Lagging (target: >99.9%)
- Process exception rate (% transactions flagged) — Leading/Lagging
- Staff turnover rate (% annual) — Leading

**Technology/Cyber Risk KRIs:**
- Number of unpatched critical vulnerabilities — Leading
- Phishing click rate (% from training tests) — Leading
- Mean Time to Detect (MTTD) security incidents — Lagging
- Backup restore test success rate — Leading

**People/HR Risk KRIs:**
- Key person dependency score (% knowledge concentrated in 1 person) — Leading
- Training completion rate — Leading
- Employee satisfaction score — Leading

### 3c. Threshold Setting

| Threshold | Band | Suggested Rule |
|-----------|------|---------------|
| Green (Normal) | No action | Comfortable within risk appetite |
| Amber (Watch) | Action plan required | Approaching tolerance limit (70-85% of Red) |
| Red (Breach) | Immediate escalation | At or beyond tolerance limit |

**Calibration approach:**
- Dùng historical data (12-24 tháng) để xác định normal range
- Red threshold = nơi historical data cho thấy incidents xảy ra
- Amber threshold = 80% của Red threshold (early warning)

---

## 4. Risk Prioritization

### 4a. Top-Down: Board Risk Appetite → Business Unit Allocation
```
Board sets overall risk appetite
    ↓
CRO translates to risk appetite per category
    ↓
Risk Managers allocate tolerance budget per business unit
    ↓
Business Risk Owners manage risks within their allocation
```

### 4b. Bottom-Up: Aggregation from Operational Level
```
Business Unit Risk Registers (operational risks)
    ↓
Consolidation by Risk Manager (remove duplicates, aggregate)
    ↓
Enterprise Risk Register (cross-BU view)
    ↓
Portfolio analysis: concentration, correlation, emerging themes
    ↓
Reporting to Board: Top 10 enterprise risks
```

### 4c. Heat Map Positioning
Standard heat map với 4 quadrants:

```
High  │ WATCH closely   │ PRIORITY actions │
Impact│ (Amber)         │ (Red/Critical)   │
      ├─────────────────┼──────────────────┤
Low   │ MONITOR         │ MANAGE proactively│
Impact│ (Green)         │ (Amber)          │
      └─────────────────┴──────────────────┘
          Low Likelihood      High Likelihood
```

### 4d. Concentration Risk
- Identify risks cùng category hoặc cùng root cause → aggregation effect
- Ví dụ: 5 risks từ IT outage → combined impact lớn hơn sum individual impacts
- Ví dụ: 3 vendors cùng 1 geography → geographic concentration risk

---

## 5. Risk Quantification Methods (Overview)

### Scenario Analysis
- **Best case**: Nếu mọi thứ diễn ra thuận lợi
- **Base case**: Expected outcome (most likely)
- **Worst case**: Nếu risk materializes fully
- Sử dụng cho: strategic decisions, risk appetite setting, BCP testing

### Sensitivity Analysis
- Thay đổi 1 variable → xem impact lên kết quả
- Ví dụ: "Nếu USD/VND tăng 5%, P&L thay đổi bao nhiêu?"
- Sử dụng cho: financial risks, project risks

### Monte Carlo Simulation
- Khi nào dùng: nhiều variables bất định, cần probability distribution của outcomes
- Phù hợp: large project risks, portfolio risk, operational loss estimation
- Yêu cầu: historical data tốt, tool (Excel add-in, Python, specialized software)
- Không nên dùng nếu thiếu historical data — garbage in, garbage out

### Expected Loss Calculation (Basel-inspired, Operational Risk)
```
Expected Loss = Probability of Loss Event × Loss Given Event
EL = P(event) × Severity

Ví dụ: Fraud risk
P(fraud event per year) = 0.1 (10%)
Average loss per event = 500 triệu VND
Expected Annual Loss = 0.1 × 500M = 50M VND
```
