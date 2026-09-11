# Compliance - Audit Templates & Execution Guide

> **Domain**: Compliance / Tuân thủ & Kiểm toán
> **Last Updated**: 2026-03-15

---

## 1. Gap Assessment (Đánh giá Khoảng cách)

Khi cần audit readiness cho certification (SOC 2, ISO 27001, HIPAA, PCI-DSS):

1. **Scoping**: Xác định trust service criteria / control objectives trong scope, systems/data flows/teams trong audit boundary
2. **Walk-through**: Đánh giá từng control objective so với trạng thái hiện tại, rating gaps theo severity và complexity
3. **Roadmap**: Tạo prioritized remediation plan với owners và deadlines
4. **Scorecard**: Readiness score cho leadership với timeline thực tế

Yêu cầu bắt buộc cho mỗi gap finding:
- Control reference cụ thể (VD: SOC 2 CC6.1, ISO 27001 A.9.2.1)
- Current state vs. Target state
- Remediation steps và estimated effort
- Priority rating (Critical / High / Medium / Low)

---

## 2. Evidence Collection

- Tổ chức evidence theo control objective, không theo team structure
- Tự động hóa evidence collection nơi có thể — manual evidence là fragile evidence
- Evidence phải chứng minh control hoạt động hiệu quả **suốt audit period**, không chỉ thời điểm hiện tại
- Population và sampling: nếu control áp dụng cho 500 servers, bất kỳ server nào cũng phải pass

---

## 3. Continuous Compliance

- Thiết lập automated evidence collection pipelines
- Quarterly control testing giữa các annual audits
- Theo dõi regulatory changes ảnh hưởng compliance program
- Monthly compliance posture report cho leadership

---

## 4. Gap Assessment Report Template

```markdown
# Compliance Gap Assessment: [Framework]

**Assessment Date**: YYYY-MM-DD
**Target Certification**: SOC 2 Type II / ISO 27001 / HIPAA / PCI-DSS
**Audit Period**: YYYY-MM-DD to YYYY-MM-DD

## Executive Summary
- Overall readiness: X/100
- Critical gaps: N
- Estimated time to audit-ready: N weeks

## Findings by Control Domain

### [Control Domain] ([Control ID])
**Status**: Full / Partial / Missing
**Current State**: [Mô tả trạng thái hiện tại]
**Target State**: [Mô tả trạng thái cần đạt]
**Remediation**:
1. [Bước 1]
2. [Bước 2]
**Effort**: [Ước lượng]
**Priority**: Critical / High / Medium / Low
```

---

## 5. Evidence Collection Matrix Template

```markdown
# Evidence Collection Matrix

| Control ID | Control Description | Evidence Type | Source | Collection Method | Frequency |
|------------|-------------------|---------------|--------|-------------------|-----------|
| CC6.1 | Logical access controls | Access review logs | Okta | API export | Quarterly |
| CC6.2 | User provisioning | Onboarding tickets | Jira | JQL query | Per event |
| CC7.1 | System monitoring | Alert configurations | Datadog | Dashboard export | Monthly |
```

---

## 6. Nguyên tắc Audit

### Substance Over Checkbox
- Policy không ai tuân theo tệ hơn không có policy — tạo false confidence
- Controls phải được tested, không chỉ documented
- Nếu control không hoạt động, nói thẳng — che giấu tạo vấn đề lớn hơn

### Right-Size Program
- Match control complexity với actual risk và company stage
- Technical controls ưu tiên hơn administrative controls — code đáng tin hơn training
- Dùng common control framework để satisfy nhiều certifications cùng lúc

### Auditor Mindset
- Nghĩ như auditor: sẽ test gì? yêu cầu evidence gì?
- Scope rõ ràng — in/out of audit boundary
- Exceptions cần documentation: ai approved, tại sao, khi nào hết hạn, compensating control nào
