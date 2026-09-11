# Insurance User Personas

> Reference file cho insurance-expert agent
> Load file này khi cần hiểu về users trong domain Insurance

## Danh sách Personas

### 1. Underwriter / Chuyên viên Khai thác

**Profile:**
- Chức danh: Underwriter / Chuyên viên Thẩm định Rủi ro
- Kinh nghiệm: Mid to Senior level (3-10 năm)
- Technical skill: High — am hiểu risk assessment, pricing models, reinsurance
- Tần suất sử dụng hệ thống: Daily (6-8 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review new applications | 10-30 hồ sơ/ngày | 15-30 phút/hồ sơ | High |
| Risk scoring & pricing | 10-20 cases/ngày | 20 phút/case | High |
| Accept/rate/decline decisions | 10-20 decisions/ngày | 10 phút/decision | High |
| Reinsurer referral | 1-5 cases/tuần | 1-2 giờ/case | High |
| Apply exclusions & special conditions | 5-10 cases/ngày | 15 phút/case | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Accept at standard premium | Risk score < threshold | Policy issued | Yes - auto-accept rule engine |
| Rated premium (surcharge) | Risk factors above standard | Higher premium, still accepted | Yes - rating factor calculator |
| Conditional acceptance (exclusions) | Specific pre-existing risk | Limited coverage | Yes - exclusion template library |
| Decline | Risk above tolerance | No coverage | Yes - decline reason codes |
| Refer to reinsurer | Sum insured > retention limit | Reinsurer decision | Yes - referral workflow + tracking |

**Pain Points:**
1. **Manual risk scoring**: Tính phí từ Excel, không kết nối với claim history
2. **No historical data**: Thiếu loss data per risk type để ra quyết định
3. **Slow reinsurer communication**: Email qua lại với reinsurer, không track được
4. **Inconsistent pricing**: Junior UW và Senior UW tính khác nhau cùng risk type

**Must-have Features:**
- Risk scoring engine tích hợp với claim history database
- Rating engine tự động: Base rate × rating factors (configurable per product)
- Reinsurer referral workflow với status tracking
- Rapid quote generation (< 5 phút cho standard risks)
- UW authority enforcement (system prevent override above limit)

---

### 2. Claims Adjuster / Giám định viên Bồi thường

**Profile:**
- Chức danh: Claims Adjuster / Chuyên viên Giám định
- Kinh nghiệm: Mid level (3-7 năm)
- Technical skill: Medium-High — am hiểu coverage, evidence evaluation
- Tần suất sử dụng hệ thống: Daily (full day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Receive & register FNOL | 5-15 claims/ngày | 15 phút/claim | High |
| Assign investigator / site visit | 2-5 cases/ngày | 20 phút/case | High |
| Collect & review documents | 10-20 cases active | 30 phút/case/ngày | High |
| Make coverage decision | 3-8 decisions/ngày | 30-60 phút/decision | High |
| Calculate settlement amount | 3-8 settlements/ngày | 20 phút/settlement | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Coverage applicable? | Policy terms, event details | Covered vs denied | Yes - coverage verification tool |
| Fraud indicators? | Fraud scoring, pattern match | Investigation required | Yes - fraud scoring engine |
| Settlement amount | Loss assessment, deductible | Payment to claimant | Yes - settlement calculator |
| Salvage value | Motor total loss assessment | Offset against settlement | Yes - salvage workflow |

**Pain Points:**
1. **Unstructured FNOL**: Nhận qua điện thoại, không có cấu trúc, miss thông tin
2. **Document chaos**: Tài liệu giấy rời rạc, không scan, không gắn với claim
3. **No case tracking**: Không biết case đang ở đâu trong quy trình
4. **Manual settlement calc**: Tính settlement trong Excel, error-prone

**Must-have Features:**
- Structured FNOL intake form (guided questions, multi-channel)
- Document repository per claim (scan, upload, index)
- Workflow tracking dashboard (current step, SLA countdown)
- Fraud scoring engine (rule-based + ML score 0-100)
- Settlement calculator (loss - deductible - co-insurance)

---

### 3. Insurance Agent / Đại lý Bảo hiểm

**Profile:**
- Chức danh: Insurance Agent / Đại lý / Broker
- Kinh nghiệm: Variable (1-15 năm)
- Technical skill: Low to Medium — mobile-first, prefer simple UI
- Tần suất sử dụng hệ thống: Daily via mobile app hoặc web portal

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Tư vấn KH & tạo quote | 5-20 quotes/ngày | 15-30 phút/quote | High |
| Submit application thay KH | 3-10 applications/ngày | 20 phút/application | High |
| Theo dõi hoa hồng | 1 lần/ngày | 10 phút | High |
| Renewal reminder cho KH | 2-5 KH/ngày | 15 phút/KH | Medium |
| Hỗ trợ KH submit claim | 1-3 claims/tuần | 30 phút/claim | Medium |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Sản phẩm nào phù hợp KH | KH profile, needs, budget | KH satisfaction, retention | Yes - needs assessment tool |
| Mức phí tối ưu | KH risk profile, affordability | Acceptance rate | Yes - quote engine với scenarios |
| Up-sell/cross-sell khi nào | Policy renewal, life event | Revenue increase | Yes - cross-sell recommender |

**Pain Points:**
1. **Re-entry data**: Nhập lại thông tin KH nhiều lần trên nhiều form
2. **No real-time status**: Không biết application/policy đang ở trạng thái nào
3. **Hoa hồng tính chậm/sai**: Commission statement muộn, khó reconcile
4. **KYC phức tạp**: Giấy tờ giấy, phải mang đến văn phòng

**Must-have Features:**
- Agent portal với quote engine one-stop
- CRM nhẹ cho danh sách KH và renewal tracking
- Commission dashboard real-time (earned, pending, paid)
- Digital KYC: Scan CCCD/Hộ chiếu, eKYC tích hợp
- Policy status tracking real-time cho KH của mình

---

### 4. Actuary / Chuyên gia Tính toán Bảo hiểm

**Profile:**
- Chức danh: Actuary / Chuyên viên Định phí
- Kinh nghiệm: Senior (5-15 năm, có chứng chỉ FSAI/FIAA/FCAS)
- Technical skill: Very High — R, Python, Excel modeling, statistical analysis
- Tần suất sử dụng hệ thống: Weekly deep analysis + Monthly reporting

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Calculate IBNR reserves | Quarterly (Hàng tháng interim) | 2-3 ngày/quarter | Critical |
| Review pricing assumptions | Monthly | 1 ngày/tháng | High |
| Loss ratio analysis by product | Monthly | 4 giờ/tháng | High |
| Regulatory actuarial report | Quarterly/Annual | 3-5 ngày | Critical |
| Product pricing review | Ad-hoc | Variable | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Reserve adequacy | Loss development patterns | Solvency, P&L accuracy | Yes - actuarial data mart |
| Premium rate change | Loss ratio, expense ratio | Profitability vs competitiveness | Yes - pricing model integration |
| Product discontinuation | Loss ratio trend, competitive | Portfolio risk | Yes - product performance dashboard |

**Pain Points:**
1. **Data extraction**: Lấy claim data từ legacy system tốn 1-2 ngày/lần
2. **Manual IBNR**: Tính reserve trong Excel, không tích hợp với system
3. **Data quality**: Claim data thiếu fields, inconsistent coding
4. **No audit trail for reserves**: Không track được reserve changes over time

**Must-have Features:**
- Actuarial data mart: Clean export của claims, premiums, exposures theo format chuẩn
- Automated IBNR calculation support (data in, triangle out)
- Reserve tracking over time (quarterly snapshots)
- Loss ratio dashboard by product, distribution channel, risk class

---

### 5. Policyholder / Người được Bảo hiểm

**Profile:**
- Chức danh: Policyholder / Khách hàng cá nhân hoặc doanh nghiệp
- Kinh nghiệm: Non-technical — ít tương tác trừ khi có sự kiện
- Technical skill: Low — mobile app preferred, simple UX required
- Tần suất sử dụng hệ thống: Sporadic (renewal, premium payment, claim)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Pay premium installment | Monthly/Quarterly/Annual | 5 phút | High |
| Check coverage details | 1-2 lần/năm | 10 phút | Medium |
| Submit claim | 0-2 lần/năm | 20-60 phút | Critical when needed |
| Track claim status | Daily khi có claim | 2 phút/lần | High |
| Renew policy | Annually | 15 phút | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Renew or lapse | Premium affordability, perceived value | Coverage continuity | Yes - renewal reminder + easy payment |
| Upgrade coverage / add riders | Life events (marriage, child, new asset) | Better protection | Yes - needs assessment + upgrade flow |
| Choose payment method | Convenience, cash flow | Premium payment compliance | Yes - multiple payment options |

**Pain Points:**
1. **Không biết coverage**: Không rõ mình đang được bảo vệ cái gì
2. **Claim status opacity**: Phải gọi điện hỏi claim đang xử lý đến đâu
3. **Giấy tờ phức tạp**: Quá nhiều documents cần chuẩn bị khi claim
4. **Premium reminder**: Quên đóng phí, dẫn đến lapse

**Must-have Features:**
- Self-service portal / mobile app: Xem coverage, đóng phí, submit claim, track claim status
- Push notification: Renewal reminder, premium due, claim status update
- Digital claim submission: Upload photos/docs từ mobile
- Plain-language coverage summary (không legalese)

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Underwriter | Risk assessment & pricing | Acceptance rate, loss ratio by UW tier |
| Claims Adjuster | FNOL → Settlement accuracy | Settlement cycle time, fraud detection rate |
| Insurance Agent | Sales & renewal | Policies sold, renewal rate, commission |
| Actuary | Reserve accuracy & pricing | IBNR accuracy, loss ratio trend |
| Policyholder | Coverage access & claim ease | Claim satisfaction score, renewal rate |
