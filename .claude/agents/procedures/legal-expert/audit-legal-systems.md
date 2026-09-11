# Playbook: Audit Existing Legal Systems

> **Type**: Agent Skill Playbook
> **Agent**: legal-expert
> **Triggered by**: /wf-legacy-scan khi có legal/contract tools hiện có
> **Output**: `.mc-data/docs/phase1-business/legal-as-is-analysis.md`

---

## Khi nào dùng playbook này

- Khi onboard dự án đã có hệ thống Legal/Contract management
- Khi cần đánh giá tình trạng hiện tại trước khi thiết kế lại
- Khi cần tìm gaps, risks và automation opportunities trong legal operations
- Khi cần baseline để đo lường improvement sau khi implement

---

## Procedure

### Bước 1: Thu thập Inventory

```
Cần thu thập từ stakeholders hoặc codebase/tài liệu hiện có:

TOOLS & SYSTEMS:
□ Hệ thống quản lý hợp đồng: Nếu có → tên, version, vendor
□ Document management: SharePoint, Google Drive, physical files?
□ E-signature tool: DocuSign, Adobe Sign, chưa có?
□ Compliance tool: GRC platform, spreadsheet, hay không có gì?
□ Legal matter management: Tool nào track litigation/disputes?
□ Policy management: Intranet, email, paper?

DATA:
□ Số lượng contracts đang active (ước tính)
□ Contracts/tháng được xử lý
□ Document formats: Word, PDF, paper scan?
□ Nơi lưu trữ: Network drive, cloud, filing cabinet?
□ Có searchable không? Full-text search?

TEAM:
□ Legal team size và roles
□ External counsel hiện đang dùng?
□ Workload: Bao nhiêu contracts/người/tháng?
```

### Bước 2: Đánh giá Contract Repository

```
READ: controls.md → Section 3 (Document Security Controls)

Kiểm tra tình trạng repository hiện tại:

ORGANIZATION:
□ Cấu trúc thư mục có logic không? (theo type, year, counterparty?)
□ Naming convention có nhất quán không?
□ Metadata có đầy đủ không? (type, value, parties, expiry date)
□ Đã scan/digitize hết chưa? Bao nhiêu % còn paper?

FINDABILITY:
□ Có search capability không? Tìm theo: counterparty? value? expiry? keyword?
□ Thời gian trung bình để tìm 1 contract cụ thể? (proxy cho efficiency)
□ Có version history không? Có thể tìm lại draft đã gửi không?

ACCESS CONTROL:
□ Ai có quyền truy cập contracts? Có phân quyền theo role không?
□ External sharing được control như thế nào? (email đính kèm vs secure portal)
□ Có log ai access document nào không?

RISK ITEMS:
□ Contracts nhạy cảm có được protected không? (NDA, executive comp)
□ Có contracts nào không biết đang ở đâu không? (shadow files, personal drives)
□ Backup policy: Khi nào backup, lưu ở đâu, tested chưa?
```

### Bước 3: Đánh giá Compliance Documentation

```
READ: operations.md → Section 4 (Compliance Monitoring)
READ: controls.md → Section 4 (Compliance Calendar Controls)

REGULATORY TRACKING:
□ Có danh sách đầy đủ regulations áp dụng không?
□ Ai chịu trách nhiệm cập nhật khi có thay đổi luật?
□ Cơ chế nhận thông tin thay đổi regulatory là gì? (email alert, legal news service...)

COMPLIANCE CALENDAR:
□ Có compliance calendar không? Dùng tool nào?
□ Deadlines có được assign owner rõ ràng không?
□ Alert mechanism: Tự động hay manual reminder?
□ Có miss deadline trong 12 tháng qua không? Nguyên nhân gì?

POLICY MANAGEMENT:
□ Có policy library không? Bao nhiêu policies hiện có?
□ Version control: Có biết version nào là latest không?
□ Distribution: Ai được thông báo khi policy update?
□ Acknowledgment: Có track employee đã đọc/ký acknowledge chưa?
□ Review cycle: Có review policies định kỳ không?
```

### Bước 4: Đánh giá Regulatory Risk Exposure

```
READ: controls.md → Quick Reference: Risk Assessment Matrix

Với từng regulation applicable:

GDPR / PDP Bill Vietnam (nếu xử lý dữ liệu cá nhân):
□ Có Records of Processing Activities (RoPA) không?
□ Có Data Protection Officer (DPO) được chỉ định không?
□ Có DPIA process cho high-risk processing không?
□ Thời gian phản hồi DSAR (Data Subject Access Request)?
□ Breach notification process: Có 72h response plan không?
□ Data transfer: Có safeguards cho data ra nước ngoài không?

Data privacy risk score:
□ Không có gì → CRITICAL (potential fine: 4% annual revenue GDPR)
□ Có basic process nhưng không documented → HIGH
□ Documented nhưng không tested → MEDIUM
□ Documented + tested + audited → LOW

E-signature compliance (nếu đang dùng):
□ Provider có compliance với eIDAS (EU) / ESIGN Act (US) không?
□ Audit trail đầy đủ không? (sent, viewed, signed, IP, timestamp)
□ Có biết loại e-signature nào applicable cho từng contract type không?

Contract management risks:
□ Có contracts hết hạn không ai biết không? (shadow liability)
□ Có payment obligations bị miss không? (financial exposure)
□ Có auto-renewal clause không có người review không?
□ Có contracts ký vượt authorization level không?
```

### Bước 5: Đánh giá Process Automation Opportunities

```
READ: operations.md → Section 3 (Task Frequency Analysis)

Tìm những tasks đang làm thủ công có thể automate:

HIGH IMPACT AUTOMATION OPPORTUNITIES:
□ Contract request intake → Self-service form thay email/verbal
□ Template selection → Auto-suggest dựa trên contract type
□ Approval routing → Auto-route theo authorization matrix (value + type)
□ Expiry alerts → Automated, không phải manual calendar reminder
□ Compliance deadline tracking → Automated calendar với owner assignment
□ Policy acknowledgment → Digital sign-off thay paper
□ Report generation → Auto-generate thay manual compile

CALCULATE TIME SAVINGS (để justify investment):
□ Giờ/tuần đang spend vào manual tracking?
□ Số contracts bị delay vì approval process?
□ Số compliance deadlines gần miss hoặc đã miss?
□ Thời gian tìm 1 contract khi cần?
```

### Bước 6: Data Classification Assessment

```
READ: controls.md → Section 3 (Document Security Controls)

Phân loại dữ liệu đang có:

HIGHLY CONFIDENTIAL (cần encryption + strict access):
□ NDAs và confidentiality agreements
□ M&A documents (trong thời gian deal)
□ Litigation strategy documents
□ Executive compensation contracts
□ Board resolutions và minutes

CONFIDENTIAL (need-to-know access):
□ Vendor contracts với pricing
□ Customer contracts với terms
□ Employment contracts
□ IP assignments và licenses

INTERNAL:
□ Standard policies và procedures
□ Template library
□ Training materials
□ Compliance reports

PUBLIC:
□ Corporate registration documents
□ Published regulatory filings
□ Terms of service / Privacy policy

Gaps cần address:
□ Có dữ liệu HIGHLY CONFIDENTIAL không được protected đúng mức không?
□ Có PII trong contracts không được encrypted không?
□ Có access logs cho confidential documents không?
```

### Bước 7: Output — Legal As-Is Analysis Report

```markdown
# Báo cáo Phân tích Hệ thống Legal Hiện trạng (As-Is)

## Executive Summary
[3-5 dòng: tình trạng tổng thể, rủi ro lớn nhất, cơ hội cải thiện quan trọng nhất]

## 1. Inventory Hiện Tại

### 1.1 Tools & Systems
| Tool/System | Mục đích | Tình trạng | Issues |
|-------------|---------|-----------|--------|
| [Tool name] | [Purpose] | Active/Partial/Broken | [Known issues] |

### 1.2 Contract Repository Assessment
| Tiêu chí | Tình trạng | Score (1-5) | Notes |
|----------|-----------|:-----------:|-------|
| Tổ chức/Cấu trúc | | | |
| Khả năng tìm kiếm | | | |
| Access control | | | |
| Version control | | | |
| Backup & recovery | | | |

## 2. Compliance Documentation Gaps

### 2.1 Regulatory Coverage
| Regulation | Applicable | Coverage | Gap | Risk Level |
|------------|:----------:|---------|-----|:----------:|
| PDP / GDPR | Có/Không | %  | [Gap description] | Cao/TB/Thấp |

### 2.2 Compliance Calendar
[Tình trạng: Tool đang dùng, automation level, recent misses nếu có]

## 3. Regulatory Risk Exposure

### 3.1 Critical Risks (cần address ngay)
- **[Risk 1]**: [Mô tả] → **Potential impact**: [Penalty/Business impact]
  → **Recommended action**: [Action]

### 3.2 High Risks (address trong 3 tháng)
- **[Risk 2]**: ...

### 3.3 Medium Risks (address trong roadmap)
- **[Risk 3]**: ...

## 4. Process Automation Opportunities

| Process | Current (Manual) | Potential Saving | Priority |
|---------|-----------------|:----------------:|:--------:|
| Contract intake | Email-based | X giờ/tuần | Cao |
| Expiry alerts | Manual calendar | Y giờ/tuần | Cao |

## 5. Data Classification Issues

| Issue | Documents Affected | Risk | Recommendation |
|-------|-------------------|:----:|----------------|
| [Issue 1] | [Scope] | Cao/TB/Thấp | [Action] |

## 6. Priority Recommendations

### Quick Wins (< 1 tháng, effort thấp, impact cao)
1. [Recommendation] — Effort: Low, Impact: High

### Medium Term (1-3 tháng)
1. [Recommendation] — Effort: Medium, Impact: High

### Long Term (3-6 tháng, cần hệ thống mới)
1. [Recommendation] — Effort: High, Impact: High

## 7. Open Questions
- [Question cần confirm với Legal Director / stakeholders]

## 8. Baseline Metrics (để đo improvement sau implement)
| Metric | Current | Target |
|--------|---------|--------|
| Contract turnaround time | X ngày | <14 ngày |
| Compliance deadline on-time rate | X% | 100% |
| Time to find a contract | X phút | <1 phút |
| Template usage rate | X% | >80% |
```

---

## Checklist trước khi submit

```
□ Tool inventory đầy đủ (mọi tools đang dùng, kể cả Excel/email)
□ Contract repository assessment: tất cả 5 tiêu chí đã score
□ Data privacy risk đã assess (GDPR/PDP exposure)
□ E-signature compliance đã check (nếu đang dùng e-sign)
□ Authorization matrix: có contracts ký vượt thẩm quyền không?
□ Data classification: có dữ liệu nhạy cảm không được protect?
□ Automation opportunities có estimate giờ tiết kiệm
□ Mọi critical risk đều có recommended action
□ Baseline metrics có để so sánh sau khi implement
□ Open questions được list cho stakeholder review
```
