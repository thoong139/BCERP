# Business Rule Catalog — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Nguồn: feature spec + code reading + AskUserQuestion verify

---

## 1. Danh Mục Business Rules

| BR-ID | Mô tả | Trigger (action) | Expected Error Code | Expected HTTP Status | Expected Message | Source |
|-------|-------|------------------|---------------------|----------------------|------------------|--------|
| BR-001 | {Mô tả rule, vd: "Không cho tạo Order nếu Customer.Status = Inactive"} | POST /api/v1/orders | `CUSTOMER_INACTIVE` | 400 | "Khách hàng không hoạt động" | spec §X / handler line Y |
| BR-002 | {...} | {...} | {...} | {...} | {...} | {...} |

---

## 2. Cross-Field Validation Rules

| CFV-ID | Field A | Field B | Quan hệ | Validator location | Expected error |
|--------|---------|---------|---------|--------------------|-----------------|
| CFV-001 | EndDate | StartDate | EndDate > StartDate | `{Validator class}.cs:line` | "Ngày kết thúc phải sau ngày bắt đầu" |
| CFV-002 | TotalAmount | LineItems | TotalAmount = SUM(LineItems.SubTotal) | {handler}.cs:line | "Tổng tiền không khớp" |

---

## 3. Business Calculation Rules

| CALC-ID | Output Field | Formula | Source location | Example |
|---------|--------------|---------|-----------------|---------|
| CALC-001 | Invoice.Total | `SUM(lines.SubTotal) + Tax - Discount` | `{handler}.cs:line` | `1,000,000 + 100,000 - 50,000 = 1,050,000` |
| CALC-002 | {...} | {...} | {...} | {...} |

---

## 4. Test Coverage Map

| BR-ID | Test case trong api-test-report.md | Status |
|-------|-------------------------------------|--------|
| BR-001 | Section 6 #1 | ⬜ Chưa test / ✅ PASS / ❌ FAIL |
| BR-002 | Section 6 #2 | - |

---

## 5. Open Questions

- {Nếu có rule chưa rõ → ghi vào đây để hỏi user ở Phase 1 VERIFY}
