# Enterprise Risk Management - Risk Governance

> **Domain**: Enterprise Risk Management / Quản trị Rủi ro Doanh nghiệp
> **Last Updated**: 2026-03-22
> **Nguồn**: COSO ERM 2017, IIA Three Lines Model (2020), Basel Committee Principles

---

## 1. Three Lines of Defense (Detailed)

### Overview
Model phân công trách nhiệm quản lý rủi ro trong tổ chức.

```
┌──────────────────────────────────────────────────────────────────┐
│                    GOVERNING BODY (Board)                        │
│           Board Risk Committee — strategic oversight             │
├────────────────────────────────────────────────────────────────  │
│                    SENIOR MANAGEMENT (CRO, CEO)                  │
├──────────────┬───────────────────────────┬──────────────────────┤
│  1st Line    │       2nd Line            │      3rd Line        │
│  Business    │   Risk Management +       │  Internal Audit      │
│  Operations  │   Compliance Functions    │  (Assurance)         │
│              │                           │                      │
│ Day-to-day   │ Oversight, frameworks,    │ Independent          │
│ controls     │ reporting, guidelines     │ assurance            │
│ Self-assess  │ Challenge 1st line        │ Test 1st + 2nd lines │
└──────────────┴───────────────────────────┴──────────────────────┘
```

### 1st Line: Business Operations
**Who**: Business unit managers, process owners, front-line staff, Risk Champions

**Responsibilities:**
- Identify và manage risks trong daily operations
- Design và operate controls tại process level
- Conduct Risk and Control Self-Assessment (RCSA)
- Report operational incidents, near-misses
- Implement action plans từ risk assessments và audit findings

**Không làm được nếu thiếu:** Clear risk ownership, tools đơn giản để báo cáo, training

### 2nd Line: Risk Management & Compliance Functions
**Who**: CRO, Risk Managers, Compliance Officers, Information Security

**Responsibilities:**
- Thiết lập ERM framework, policies, methodologies
- Monitor và challenge 1st line risk management
- Aggregate và report risks to senior management và Board
- Design KRI system và monitor thresholds
- Facilitate RCSA và risk workshops
- Maintain enterprise risk register
- Provide independent risk assessment của significant decisions

**Không làm được nếu thiếu:** Mandate từ Board, adequate budget, independence từ business lines

### 3rd Line: Internal Audit
**Who**: Chief Audit Executive, Internal Auditors

**Responsibilities:**
- Cung cấp independent assurance về effectiveness của governance, risk management, controls
- Test controls theo risk-based audit plan
- Report findings trực tiếp lên Audit Committee (không qua management)
- Follow up remediation của findings
- Không trực tiếp manage risks (đó là 1st và 2nd line)

**Independence yêu cầu:** Reporting line trực tiếp lên Board/Audit Committee, không phải CEO

### Trách nhiệm Ma trận

| Trách nhiệm | 1st Line | 2nd Line | 3rd Line |
|-------------|:--------:|:--------:|:--------:|
| Own risks | ✅ Primary | ⚠ Oversight | ❌ |
| Design controls | ✅ Primary | ✅ Support | ❌ |
| Operate controls | ✅ Primary | ⚠ Some | ❌ |
| Monitor controls | ✅ Self | ✅ Independent | ❌ |
| Risk framework | ⚠ Apply | ✅ Own | ❌ |
| Risk reporting | ✅ Input | ✅ Compile | ❌ |
| Assurance | ❌ | ❌ | ✅ Primary |
| Audit findings | ✅ Remediate | ⚠ Coordinate | ✅ Issue |

### Common Failures và cách phòng ngừa

| Failure | Symptom | Prevention |
|---------|---------|------------|
| 1st Line không own risks | "Risk là việc của Risk team" | Clear accountability, performance KPIs |
| 2nd Line quá sát nghiệp vụ | Risk Manager kiêm luôn business decisions | Maintain independence, separate reporting line |
| 3rd Line không có independence | Internal Audit report qua CFO | Direct reporting to Audit Committee |
| Gaps giữa các Lines | Risks không ai pick up | Regular coordination meetings, clear RACI |
| Over-reliance on 3rd Line | "Audit sẽ catch it" | Strengthen 1st và 2nd line |

---

## 2. Governance Structures

### Board Risk Committee
**Charter elements:**
- **Purpose**: Assist Board trong oversight of risk management framework
- **Membership**: Minimum 3 independent directors, 1 financial expert required
- **Chair**: Independent non-executive director (không phải Chairman of Board)
- **Quorum**: Majority of members
- **Meeting frequency**: Minimum quarterly; ad-hoc khi có material risk events
- **CRO access**: CRO có quyền tiếp cận trực tiếp không qua CEO

**Standard Agenda Items (Quarterly):**
1. Risk Appetite Statement — review và confirm
2. Enterprise Risk Register — top risks update
3. KRI dashboard — threshold breaches và trends
4. Emerging risks — new risks được identify
5. BCP/DRP status — testing results
6. Internal Audit findings — remediation status
7. Regulatory environment — material changes

### Management Risk Committee (Executive Level)
**Composition:**
- Chair: CRO hoặc CEO
- Members: CFO, COO, CTO, CISO, CCO (Chief Compliance Officer), Business Unit Heads
- Secretary: Risk Manager

**Responsibilities:**
- Review và approve ERM framework changes
- Approve risk appetite thresholds (trước khi trình Board)
- Make treatment decisions cho High risks
- Review KRI breaches và approve responses
- Approve BCP activation (operational level)

**Quorum:** Majority of members; CEO + CFO + CRO tối thiểu

**Meeting frequency:** Monthly; ad-hoc emergency khi cần

### Business Unit Risk Committees
**Escalation criteria lên Management Risk Committee:**
- Risk score ≥ 16 (High/Critical) sau treatment
- KRI breach Red threshold
- New risk không có precedent
- Operational incident gây tổn thất > [threshold định theo RAS]
- Regulatory enforcement action

### CRO Reporting Line Best Practices
- **Preferred**: CRO report trực tiếp lên CEO hoặc Board
- **Minimum**: CRO report lên CFO với direct access lên Board Risk Committee
- **Tránh**: CRO report lên COO (conflict: COO own operational risks mà CRO phải oversee)
- **Lý do**: Independence là yếu tố cốt lõi của effective risk governance

---

## 3. RCSA (Risk and Control Self-Assessment)

### Definition và Purpose
RCSA là quy trình để business units tự đánh giá rủi ro và hiệu quả kiểm soát trong phạm vi của mình.
- **Mục tiêu 1**: Đảm bảo 1st line own risks của họ (không phải chỉ 2nd line)
- **Mục tiêu 2**: Thu thập bottom-up risk data để aggregate lên enterprise level
- **Mục tiêu 3**: Xây dựng risk culture — nhận thức rủi ro ở mọi cấp

### Process

```
Step 1: Preparation (2 tuần trước)
├── Risk Manager gửi RCSA template và hướng dẫn cho business units
├── Pre-populate template với risks từ enterprise register (nếu applicable)
└── Schedule workshop với business unit heads

Step 2: Risk Identification (Workshop — 2-3 giờ)
├── Business unit identify risks trong phạm vi operations
├── Risk Manager facilitate: hỏi thêm, challenge, đảm bảo coverage
└── Identify controls hiện có cho mỗi risk

Step 3: Assessment
├── Score inherent risk (likelihood × impact TRƯỚC controls)
├── Đánh giá control effectiveness: Effective / Partially Effective / Ineffective
└── Score residual risk (likelihood × impact SAU controls)

Step 4: Action Planning
├── Với risks residual > risk appetite: yêu cầu action plans
├── Owner, deadline, expected residual risk sau action
└── Resources needed

Step 5: Consolidation (Risk Manager)
├── Compile từ tất cả business units
├── Normalize scoring (đảm bảo consistency)
├── Identify cross-BU risks và aggregation effects
└── Update enterprise risk register

Step 6: Review và Sign-off
├── Business unit head sign-off RCSA results
└── CRO review và approve enterprise-level aggregate
```

### Frequency
- **Base**: Annual comprehensive RCSA
- **Trigger-based updates**: M&A, new product launch, major regulatory change, significant incident

### Facilitation Guide — Common Biases to Avoid

| Bias | Mô tả | Counter-measure |
|------|-------|-----------------|
| **Optimism bias** | "Chuyện đó không xảy ra với chúng ta" | Dẫn historical examples, industry data |
| **Group think** | Mọi người đồng ý với người có quyền lực nhất | Anonymous pre-voting, silent brainstorm |
| **Recency bias** | Chỉ nhớ incidents gần đây | Review risk universe toàn diện |
| **Control optimism** | "Controls của chúng ta rất tốt" | Test controls trước RCSA, dùng audit findings |
| **Sandbagging** | Score cao để có nhiều resources | Calibration với historical data |

---

## 4. Risk Reporting Cadence

### Operational Reporting
- **Daily**: KRI dashboard alerts (automated) → Risk Manager
- **Weekly**: Risk status update email → Business Unit Heads; Escalated risks → CRO

### Management Reporting (Monthly Risk Report)

**Template chuẩn:**
```
MONTHLY RISK REPORT — [Tháng/Năm]

1. EXECUTIVE SUMMARY (1 trang)
   - Risk posture tháng này vs tháng trước
   - Top 3 changes trong risk profile
   - KRI breach summary

2. KRI DASHBOARD
   - Status mỗi KRI: Green/Amber/Red
   - Trend: ↑ Deteriorating / → Stable / ↓ Improving

3. TOP 10 ENTERPRISE RISKS
   - Rank, Risk description, Category, Score (Inherent / Residual)
   - Owner, Treatment status, Deadline

4. EMERGING RISKS
   - Risks mới được identify trong tháng
   - External risk intelligence (industry news, regulatory changes)

5. OPERATIONAL INCIDENTS
   - Số incidents, tổng losses, phân loại theo category
   - Significant incidents: root cause, remediation

6. ACTION PLAN STATUS
   - % actions on track / behind / overdue
   - Overdue actions: reason, revised deadline

7. NEXT MONTH FOCUS
   - Planned activities: RCSA, control testing, BCP exercise
```

### Board Reporting (Quarterly)
Tương tự Monthly nhưng:
- Strategic perspective, không operational detail
- Comparison vs risk appetite (quantitative)
- Scenario analysis cho top strategic risks
- Peer benchmarking nếu available
- CRO recommendation và management response

### Escalation: Immediate Triggers
Các situations cần báo cáo ngay lập tức (trong 24 giờ):
- Critical risk materializes (risk score 20-25 xảy ra thực tế)
- KRI breach Red threshold bất ngờ (rapid deterioration)
- Significant operational incident (tổn thất > threshold trong RAS)
- Regulatory inquiry hoặc enforcement action
- Data breach hoặc cyber incident với material impact

```
Escalation path:
Risk Champion → Risk Manager (trong 1 giờ)
  → CRO (trong 4 giờ)
    → CEO + General Counsel (trong 24 giờ)
      → Board Risk Committee Chair (nếu material)
```

---

## 5. Risk Appetite Statement (RAS) — Template Chi tiết

### Template Structure

```markdown
## RISK APPETITE STATEMENT
### [Tên tổ chức] | Phê duyệt: [Board ngày DD/MM/YYYY] | Review: [Năm]

### 1. Tuyên bố tổng quát
[Tên tổ chức] theo đuổi tăng trưởng bền vững với [profile rủi ro: conservative/moderate/growth-oriented].
Chúng tôi chấp nhận rủi ro có chủ đích nhằm đạt [strategic objectives],
trong khi không chấp nhận rủi ro đe dọa [ổn định tài chính / giấy phép hoạt động / tin tưởng của khách hàng].

### 2. Risk Tolerance Matrix (xem erm-framework.md cho bảng đầy đủ)

### 3. Absolute Restrictions (Zero tolerance)
- Vi phạm pháp luật
- Gian lận, tham nhũng
- Rủi ro gây nguy hiểm tính mạng
- [Industry-specific zero tolerance]

### 4. Risk Capacity
Maximum risk có thể absorb trước khi ảnh hưởng đến:
- Capital adequacy / Liquidity buffer
- Business continuity
- Regulatory standing

### 5. Monitoring Mechanism
- KRI breaches: [frequency] review
- RAS review: Annual hoặc khi chiến lược thay đổi
- Escalation: [xem Escalation section ở trên]
```
