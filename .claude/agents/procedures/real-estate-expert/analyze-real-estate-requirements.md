# Playbook: Phân tích Real Estate Requirements

> **Type**: Agent Procedure
> **Agent**: real-estate-expert
> **Triggered by**: /wf-analyze-requirements khi project có BĐS modules
> **Output**: `.mc-data/docs/phase1-business/real-estate-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan: BĐS, property, chủ đầu tư, môi giới, quản lý tòa nhà
- Khi cần xác định requirements cho hệ thống phần mềm BĐS từ business idea

---

## Procedure

### Bước 1: Xác định Segment và Scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Segment chính:
  - Developer platform (chủ đầu tư quản lý dự án + bán hàng)
  - Broker marketplace (sàn giao dịch, môi giới)
  - Property management (quản lý vận hành sau bàn giao)
  - REIT / Investment fund (quản lý danh mục đầu tư BĐS)
  - Hybrid (kết hợp nhiều segment)

□ Loại BĐS:
  - Residential: căn hộ, nhà phố, biệt thự
  - Commercial: văn phòng, TTTM, mặt bằng bán lẻ
  - Industrial: KCN, kho xưởng, logistics
  - Mixed-use: kết hợp residential + commercial

□ Quy mô:
  - Số căn hộ / mặt bằng đang quản lý
  - Số dự án đang triển khai đồng thời
  - Số giao dịch ước tính / tháng
  - Số broker / sales agent

□ Pháp lý VN applicable:
  - Luật Kinh doanh BĐS 2023 (số 29/2023/QH15)
  - Luật Đất đai 2024 (số 31/2024/QH15)
  - Luật Nhà ở 2023
  - Quy định AML (Luật Phòng chống rửa tiền 2022)
```

### Bước 2: Identify Personas

```
READ: .claude/references/team-expert/real-estate/personas.md

Chọn personas relevant theo segment:
- Developer platform → Chủ đầu tư, Legal Officer (+ Broker nếu có kênh phân phối)
- Broker marketplace → Broker, Buyer, Developer (seller side)
- Property management → Property Manager, Tenant/Buyer
- Full-stack → Tất cả 5 personas

Với mỗi persona:
□ Note daily tasks bị ảnh hưởng
□ Note pain points hiện tại
□ Note must-have features
□ Estimate frequency of use
```

### Bước 3: Map Quy trình BĐS Hiện tại

```
READ: .claude/references/team-expert/real-estate/operations.md

Section phù hợp theo segment:
- Developer / Sales → §2 Sales Process Flow + §1 Development Lifecycle
- Property Management → §3 Property Management Cycle
- Commission → §4 Broker Commission Structure

Document:
□ Current process (as-is): quy trình đang làm thủ công thế nào?
□ Pain points: bước nào tốn thời gian nhất, dễ sai nhất?
□ Manual workarounds: đang dùng Excel/Zalo/điện thoại thay thế gì?
□ Integration points: liên kết với hệ thống nào (ngân hàng, công chứng, sở địa chính)?
```

### Bước 4: Xác định Controls Cần Thiết

```
READ: .claude/references/team-expert/real-estate/controls.md

Checklist:
□ Giỏ hàng hold/lock controls → §1
□ Discount approval matrix → §2
□ Revenue recognition approach (TT200 hay IFRS 15?) → §3
□ Escrow requirements (bảo lãnh NH, separate account) → §4
□ AML requirements → §5 (ngưỡng báo cáo, KYC level)
□ Commission dual control → §6
□ Legal document retention → §7

Flag: compliance nào là BẮT BUỘC theo pháp luật vs optional theo policy
```

### Bước 5: Identify Cross-Agent Dependencies

```
Tag các area cần chuyên gia khác:

□ finance-expert: Thu tiền đợt accounting, escrow journal entries, revenue recognition
□ legal-expert: Nội dung HĐMB, quy trình công chứng, điều khoản pháp lý
□ compliance-expert: AML workflow, KYC process, STR reporting mechanics
□ operations-expert: Facility management, vendor management, supply chain bảo trì
□ sales-expert: CRM pipeline, commission structure, broker performance

Document dependency rõ ràng để skills downstream biết cần gọi agent nào
```

### Bước 6: Viết Requirements

Format mỗi requirement:

```markdown
### REQ-RE-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Persona**: [Ai cần tính năng này]
**Business Value**: [Tại sao cần - impact gì]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Dependencies**: [REQ khác cần có trước]
**Priority**: [Must-have / Should-have / Nice-to-have]
**Compliance**: [Pháp lý bắt buộc nếu có]
```

**REQ-ID Format:**
```
REQ-RE-DEV-001   → Project Development (chủ đầu tư, giấy phép, milestone)
REQ-RE-SALE-001  → Sales & Booking (giỏ hàng, booking, hold/release)
REQ-RE-PAY-001   → Payment Schedule (tiến độ thu tiền, lịch đợt)
REQ-RE-PROP-001  → Property Management (lease, maintenance, billing)
REQ-RE-LEGAL-001 → Legal & Title (HĐMB, sổ đỏ, công chứng)
REQ-RE-FIN-001   → Financial (escrow, revenue recognition, reporting)
REQ-RE-FUND-001  → Fund & Investment (REIT, investor reporting)
REQ-RE-COM-001   → Commission & Broker (hoa hồng, clawback)
```

### Bước 7: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/real-estate-requirements.md

Cấu trúc output:
1. Executive Summary (segment, loại BĐS, quy mô)
2. Applicable Regulations (list pháp lý áp dụng)
3. Personas affected (summary table)
4. Quy trình as-is và gaps
5. Requirements (theo module, có REQ-ID)
6. Compliance & Control requirements (highlight BẮT BUỘC)
7. Cross-agent dependencies (ai cần gọi tiếp)
8. Integration requirements (ngân hàng, e-sign, sở địa chính)
9. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-RE-[MODULE]-[NNN]
□ Mỗi REQ có Business Value rõ ràng
□ Compliance requirements theo Luật KDBĐS 2023 đã covered
□ AML/KYC requirements đã included
□ Escrow controls đã addressed
□ Revenue recognition approach đã xác định
□ Cross-agent dependencies đã flagged
□ Open questions được list ra để stakeholders review
```
