# F3 — Group 4 (Hard Test) Unblock Procedure

**Áp dụng:** blocked_tests có `blocking_reason` ∈ {`requires_visual_inspection`, `requires_manual_interaction`, `external_dependency`, `flaky_test`, `requires_human_judgment`, `other`}.

**Strategy:** VERIFY CODE TRƯỚC → dual-write block-test.json + manual.json. KHÔNG auto-fix data/infra.

---

## Flow

```
FOR each BLK-NNN với blocking_reason ∈ Group 4:
  1. VERIFY CODE — đọc code liên quan:
     - mcp__serena__find_symbol → tìm function/class liên quan test_ref
     - mcp__serena__find_referencing_symbols → tìm callers
     - Grep cho keyword (vd: "VNPayService", "signature_verify")
     
  2. Đánh giá code logic:
     - static_code_review: đọc code, đối chiếu BR catalog → PASS|FAIL|INCONCLUSIVE
     - mock_api_test (nếu external dep có sandbox): curl mock → check response shape
     - unit_test: chạy `dotnet test --filter "FullyQualifiedName~<test>"` → check pass

  3. DUAL-WRITE:
     - block-test.json: status (resolved nếu code PASS, blocked nếu FAIL/INCONCLUSIVE), unblock_attempts[], related_manual_id
     - manual.json: APPEND new MAN-NNN với code_verification + recommended_test_steps[]

  4. Nếu code FAIL → ESCALATE as ISSUE (append issues.json E034)
```

---

## Code Verification Method per Reason

### requires_visual_inspection

```bash
# Static review CSS/component code
mcp__serena__find_symbol --name_path="ComponentName" --include_body=true

# Đánh giá:
# - Component có render đúng states (loading/empty/success/error)?
# - Tailwind classes có đúng responsive breakpoints?
# - Animation logic có pattern phổ biến (transition, transform)?
# - Color tokens từ design system?

# Result: PASS (code OK, cần QA xem mắt) | FAIL (code có bug rõ ràng)
```

### requires_real_payment / requires_external_api

```bash
# Static review service layer
mcp__serena__find_symbol --name_path="VNPayService.HandleCallback"

# Đánh giá:
# - Signature verification logic đúng (HMAC SHA512 with secret)?
# - Callback URL handling (success/cancel/failure paths)?
# - Idempotency key (transaction ID) check?
# - Database update transactional?

# Mock test:
curl -X POST http://localhost:5048/api/v1/payments/vnpay/callback \
  -d "vnp_TxnRef=TEST-001&vnp_Amount=100000&vnp_SecureHash=<mock>" 

# Result: PASS (logic correct, cần thanh toán thật để verify end-to-end)
```

### requires_3rd_party_login

```bash
# Static review OAuth callback handler
mcp__serena__find_symbol --name_path="GoogleAuthController.Callback"

# Đánh giá:
# - Code exchange logic đúng (POST to /token)?
# - State parameter validation (CSRF protection)?
# - User profile fetch + map đúng?
# - Refresh token storage encrypted?
```

### requires_hardware

```bash
# Test parsing logic độc lập hardware
# vd: barcode parser, GPS coordinate parsing

# Unit test
dotnet test --filter "FullyQualifiedName~BarcodeParserTests"

# Result: PASS (parsing correct với mock data, cần device thật để verify scan)
```

### flaky_test

```bash
# Retry 3 lần để xem có pass đa số không
for i in 1 2 3; do
  curl -X <test> ... 
  echo "Run $i: $?"
done

# Đánh giá:
# - 3/3 PASS → status=resolved (no longer flaky)
# - 2/3 PASS → keep blocked, note "flaky 67%, need investigation"
# - 0-1/3 PASS → keep blocked, escalate as issue
```

### requires_human_judgment

```bash
# Static review template/copy/UX text
# vd: email templates, error messages, copy quality

# Đọc resource files
mcp__serena__find_file --pattern="*.resx" --search_in_folder="apps/erp-web/src/messages"

# Result: thường là INCONCLUSIVE (cần copywriter / UX writer review)
```

---

## Dual-Write Pattern

### block-test.json UPDATE

```jsonc
{
  "id": "BLK-007",
  "status": "resolved",  // hoặc "blocked" nếu code FAIL/INCONCLUSIVE
  "retest_result": "SKIPPED",
  "resolution_note": "Code logic verified PASS qua static review — signature verify + callback handler + idempotency đều đúng",
  "related_manual_id": "MAN-001",  // link 2 chiều
  "unblock_attempts": [
    {
      "at": "2026-05-13T15:00:00Z",
      "action": "static_code_review VNPayService.HandleCallback",
      "result": "verified",
      "detail": "Code PASS — signature/callback/idempotency đúng. Cần thanh toán thật để verify end-to-end."
    }
  ]
}
```

### manual.json APPEND new entry

```jsonc
{
  "id": "MAN-001",
  "discovered_at": "2026-05-13T15:00:00Z",
  "discovered_by_skill": "wf-e2e-unblock",
  "discovered_in_phase": 0,  // F3 phase (post-hoc)
  "test_ref": "VNPay sandbox redirect — verify payment success callback",
  "feat_id": "FEAT-EW-FIN-008",
  "manual_reason": "requires_real_payment",
  "code_verification": {
    "verified_at": "2026-05-13T15:00:00Z",
    "verified_by_skill": "wf-e2e-unblock",
    "verification_method": "static_code_review",
    "verification_result": "PASS",
    "code_location": "apps/backend/Eureka.Modules.Finance/Application/Payments/VNPayService.cs:123",
    "notes": "Signature verify + callback handler + idempotency key đều đúng"
  },
  "recommended_test_steps": [
    "Bước 1: Đăng nhập VNPay Sandbox (testuser@vnpay.vn / Test@123)",
    "Bước 2: Tạo invoice 100k → click 'Thanh toán'",
    "Bước 3: Verify redirect → sandbox.vnpayment.vn",
    "Bước 4: Submit card 9704198526191432198",
    "Bước 5: Verify callback → invoice status=Paid + ledger entry"
  ],
  "status": "pending",
  "assigned_to": "qa-team",
  "related_blk_id": "BLK-007"
}
```

---

## Code FAIL Escalation

Nếu `code_verification.verification_result = FAIL`:

```bash
# KHÔNG ghi vào manual.json (vì code có bug, không phải hard-to-test)
# THAY VÀO ĐÓ: append issues.json
jq --arg id "ISS-NNN" '.signals += [{
  "id": $id,
  "phase": <phase>,
  "type": "code-bug",
  "severity": "high",
  "title": "Code logic FAIL trong <component>",
  "description": "F3 verify code phát hiện bug: <detail>",
  "location": "<file:line>",
  "status": "open",
  "discovered_by_skill": "wf-e2e-unblock",
  "related_blk_id": "BLK-NNN"
}]' issues.json > issues.json.tmp && mv issues.json.tmp issues.json

# Update block-test.json BLK-NNN:
#   status="blocked", resolution_note="Code FAIL — see ISS-NNN", related_iss_id="ISS-NNN"

# Trigger E034
```

---

## Error Handling

- **Serena/Grep không tìm thấy code** → INCONCLUSIVE, escalate manual.json với note "code không tồn tại, cần investigate"
- **Verification method không phù hợp** (vd: hardware test) → INCONCLUSIVE, manual.json với note rõ
- **Code FAIL** → E034 + issues.json append, KHÔNG manual.json
- **Code PASS** → manual.json + block-test resolved
