# Playbook: Đánh giá Automation Candidate

> **Type**: Agent Skill Playbook
> **Agent**: automation-architect
> **Triggered by**: Khi có yêu cầu tự động hóa một quy trình — bước đầu tiên bắt buộc trước mọi automation work
> **Output**: Automation evaluation report tại `.mc-data/docs/phase3-architecture/automation-eval-[process-name].md`

---

## Khi nào dùng playbook này

- Bất cứ khi nào nhận được yêu cầu "tự động hóa quy trình X"
- Trước khi design bất kỳ workflow automation nào
- Khi review đề xuất automation từ team
- Khi business muốn RPA hoặc integration automation

**Quy tắc bất biến**: Không thiết kế automation trước khi evaluation report được approve.

---

## Procedure

### Bước 1: Quy trình hiện tại documentation

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3
READ: architecture-patterns.md

Thu thập:
□ Mô tả chi tiết quy trình hiện tại (as-is) — từng bước
□ Ai thực hiện? (role, team, số người)
□ Hệ thống/tools đang dùng
□ Triggers: Khi nào quy trình bắt đầu?
□ Outputs: Kết quả cụ thể của quy trình
□ Exception cases: Khi nào phải xử lý khác?
□ Người yêu cầu automation: Role và business goal
```

Document as-is process:

```markdown
## Quy trình hiện tại: [Tên quy trình]

**Trigger**: [Khi nào/điều kiện gì bắt đầu quy trình này]
**Owner**: [Team/role chịu trách nhiệm]
**Stakeholders**: [Ai bị ảnh hưởng]

### Các bước

| Bước | Người thực hiện | Hệ thống | Thời gian | Ghi chú |
|------|----------------|---------|-----------|---------|
| 1. [Tên bước] | [Role] | [System] | [X phút] | [Exception nếu có] |
| 2. | | | | |
| ... | | | | |

**Tổng thời gian thủ công**: [X phút/giờ per instance]
**Tần suất**: [X lần/ngày, tuần, tháng]
**Volume**: [X instances/tháng hiện tại]
```

### Bước 2: Frequency và volume analysis

Đây là dữ liệu nền tảng cho ROI calculation:

```markdown
## Frequency & Volume Analysis

### Tần suất hiện tại
- Trung bình: [X] instances/tháng
- Peak: [X] instances/tháng (khi nào?)
- Seasonal pattern: [Có/Không — nếu có, mô tả]

### Trend
- 3 tháng trước: [X]/tháng
- 3 tháng gần nhất: [Y]/tháng
- Dự báo 12 tháng tới: [Z]/tháng (cơ sở dự báo là gì?)

### Volume characteristics
- Instance size: [Mỗi instance xử lý bao nhiêu records/data?]
- Outliers: [Có instances đặc biệt lớn/nhỏ không?]
- Batch vs real-time: [Có thể batch được không?]

**Kết luận volume**: [Đủ lớn để justify automation / Quá nhỏ / Growing fast]
```

### Bước 3: Manual effort cost

Tính toán chi phí thực tế của quy trình thủ công:

```markdown
## Manual Effort Cost

### Thời gian per instance
| Bước | Thời gian thực (phút) | Ghi chú |
|------|----------------------|---------|
| [Bước 1] | [X] | Bao gồm context switching |
| [Bước 2] | [X] | |
| Exception handling (avg) | [X] | ~[Y]% instances có exception |
| **Tổng** | **[X]** | |

### Chi phí tháng hiện tại
- Thời gian/tháng: [X instances] × [Y phút] = [Z phút] = [W giờ]
- Nhân sự xử lý: [N người × X giờ/người]
- Chi phí ước tính: [W giờ] × [hourly rate] = [USD/tháng]

### Hidden costs (không tính trong giờ)
- [ ] Errors do manual entry (rework cost)
- [ ] Delays (downstream impact)
- [ ] Scalability constraint (không scale được khi volume tăng)
- [ ] Knowledge dependency (chỉ [N] người biết làm)
```

### Bước 4: Automation complexity estimate

Đánh giá độ phức tạp kỹ thuật theo 4 chiều:

```markdown
## Automation Complexity Assessment

### Chiều 1: Input/Output Stability
| Yếu tố | Đánh giá | Score (1-5) |
|--------|---------|------------|
| Input format có chuẩn hóa không? | [Structured JSON / CSV / Free text / Email] | [1-5] |
| Input sources ổn định không? | [Có API / Chỉ có UI / Cần scraping] | [1-5] |
| Output format có định nghĩa rõ? | [Có / Mơ hồ / Thay đổi theo case] | [1-5] |

### Chiều 2: Business Logic Complexity
| Yếu tố | Đánh giá | Score (1-5) |
|--------|---------|------------|
| Rules có rõ ràng, document được không? | | [1-5] |
| Có nhiều exception cases không? | [<5 / 5-20 / >20] | [1-5] |
| Cần judgment/context của con người không? | | [1-5] |
| Rules thay đổi thường xuyên không? | | [1-5] |

### Chiều 3: External Dependencies
| Dependency | Type | Stability | Auth method |
|-----------|------|----------|------------|
| [System A] | [API / DB / UI] | [Stable / Sometimes changes] | [API key / OAuth / Password] |
| [System B] | | | |

**Tổng external dependencies**: [N]
**Dependency risk**: Mỗi dependency = 1 potential failure point

### Chiều 4: Data Sensitivity
| Loại dữ liệu | Sensitivity | Compliance requirement |
|-------------|------------|----------------------|
| [Customer PII] | [High] | [GDPR/PDPA] |
| [Financial records] | [High] | [Audit trail required] |
| [Internal operational] | [Low] | [None] |

### Complexity Summary
| Chiều | Score | Ý nghĩa |
|-------|-------|---------|
| Input/Output Stability | [1-5] | 1=phức tạp, 5=đơn giản |
| Business Logic | [1-5] | |
| External Dependencies | [1-5] | |
| Data Sensitivity | [1-5] | |
| **Overall** | **[avg]** | < 3: High complexity |
```

### Bước 5: ROI calculation — breakeven point

```markdown
## ROI Analysis

### Investment (one-time)
| Item | Estimated Cost |
|------|---------------|
| Design & development | [X] giờ × [hourly rate] |
| Testing & QA | [X] giờ |
| Documentation & training | [X] giờ |
| **Total investment** | **[X] USD** |

### Ongoing costs (monthly)
| Item | Monthly Cost |
|------|-------------|
| Maintenance & updates | [X] giờ/tháng |
| Platform/tool fees | [X] USD/tháng |
| Monitoring | [X] giờ/tháng |
| **Total ongoing** | **[X] USD/tháng** |

### Savings (monthly)
| Item | Monthly Saving |
|------|--------------|
| Labor hours eliminated | [X] giờ × [hourly rate] |
| Error reduction | [X] USD ước tính |
| Scalability headroom | [Quantified nếu có thể] |
| **Total savings** | **[X] USD/tháng** |

### Breakeven Analysis
- Net monthly benefit: [Savings] - [Ongoing cost] = [X] USD/tháng
- Payback period: [Investment] / [Net monthly benefit] = [N] tháng
- 12-month ROI: ([12 × Net benefit - Investment] / Investment) × 100 = [Y]%

**Đánh giá ROI**: [Strong >200% / Marginal 50-200% / Weak <50%]
```

### Bước 6: Risk assessment

```markdown
## Risk Assessment

### Failure impact (Blast Radius)
Nếu automation fail hoàn toàn:
- Immediate impact: [Mô tả cụ thể điều gì xảy ra]
- Business process blocked?: [Yes — X giờ / No — fallback to manual]
- Data at risk: [Có / Không / Partial]
- Downstream systems affected: [List]
- Recovery time (manual): [X giờ để xử lý backlog]
- **Blast radius score**: [High / Medium / Low]

### Edge case sensitivity
| Edge Case | Frequency | Current handling | Automatable? |
|-----------|-----------|-----------------|-------------|
| [Case 1] | [X]% | [Manual review] | [Yes/No/Partial] |
| [Case 2] | | | |

**Edge cases không automatable**: [N cases] — sẽ cần human-in-the-loop

### External dependency risks
| Dependency | Risk type | Mitigation |
|-----------|----------|-----------|
| [API A] | Rate limiting, auth expiry | Retry + alert |
| [System B] | Scheduled downtime | Queue + retry |
| [Service C] | Breaking API changes | Version pin + monitoring |

### Operational risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Logic error causes incorrect data | Medium | High | Audit log + human review sample |
| Volume spike exceeds rate limits | Low | Medium | Queue + backpressure |
| Credential expiry | Medium | High | Secret rotation monitoring |
```

### Bước 7: Reversibility analysis

```markdown
## Reversibility

### Rollback capability
- Có thể rollback nếu automation fail sau 1 giờ chạy? [Yes / Partial / No]
- Có thể rollback nếu automation fail sau 1 ngày chạy? [Yes / Partial / No]
- Data writes có idempotent không? [Yes / No / Partial]
- Có thể chạy manual process song song trong giai đoạn transition? [Yes / No]

### Transition plan
| Phase | Duration | What's running |
|-------|---------|----------------|
| Parallel run | 2 tuần | Manual + automation, compare outputs |
| Shadow mode | 1 tuần | Automation runs but outputs verified manually |
| Gradual rollout | 1 tuần | 10% → 50% → 100% volume |
| Full automation | - | Automation primary, manual as fallback |

### Kill switch
- Kill switch có không? [Yes — mô tả / No — cần build]
- Ai có quyền trigger kill switch? [Role]
- Recovery procedure sau kill switch: [Link hoặc mô tả]
```

### Bước 8: Go/No-Go recommendation

```markdown
## Verdict

**Recommendation**: [APPROVE / APPROVE AS PILOT / PARTIAL AUTOMATION ONLY / DEFER / REJECT]

**REQ-ID**: REQ-AUTO-[MODULE]-[NNN]

### Justification

| Factor | Score | Weight | Weighted |
|--------|-------|--------|---------|
| ROI strength | [1-5] | 30% | |
| Complexity | [1-5] | 25% | |
| Risk level | [1-5] | 25% | |
| Reversibility | [1-5] | 20% | |
| **Total** | | | **[X/5]** |

**Verdict Criteria**:
- APPROVE: Score >= 4.0, blast radius Low/Medium, payback < 6 tháng
- APPROVE AS PILOT: Score 3.0-3.9, limited scope để validate assumptions
- PARTIAL AUTOMATION ONLY: Một số steps nên remain manual (specify which)
- DEFER: Economics yếu nhưng có thể improve — conditions to revisit
- REJECT: Score < 2.5, blast radius High, hoặc economics không justify

### Nếu APPROVE — Prerequisites trước khi design
- [ ] [Prerequisite 1 — ví dụ: API documentation từ vendor]
- [ ] [Prerequisite 2 — ví dụ: Error handling spec từ business]
- [ ] [Prerequisite 3 — ví dụ: Approval từ data owner]

### Nếu PARTIAL — Steps nên giữ manual
- [Step X]: Vì [lý do — ví dụ: cần judgment, legal requirement, frequency quá thấp]
- [Step Y]: Vì [lý do]
```

---

## Checklist trước khi submit

```
□ As-is process được document đầy đủ, không giả định
□ Volume/frequency data có nguồn rõ ràng (không ước đoán)
□ ROI calculation có breakeven point cụ thể
□ Blast radius được đánh giá worst-case, không optimistic
□ Edge cases được liệt kê đầy đủ
□ Reversibility và kill switch được xem xét
□ REQ-ID được gán đúng format
□ Verdict có justification, không chỉ "yes/no"
□ Nếu APPROVE, prerequisites rõ ràng trước khi bắt đầu design
```

---

## Lưu ý quan trọng

- **Value Gate**: "Khả thi về kỹ thuật" không phải lý do đủ để APPROVE
- **Fragility check**: Đếm external dependencies — > 4 dependencies thường cần design đặc biệt
- **Data criticality**: Customer/finance/contract records → blast radius luôn High bất kể complexity
- **Không self-serve**: Evaluation report cần được review bởi business owner trước khi proceed
