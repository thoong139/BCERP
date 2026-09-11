# Block Classification Procedure (F1 wf-e2e-test)

**Áp dụng:** Phase 2 → Phase 5 của F1 wf-e2e-test (và share logic với F2 wf-e2e-browser).

**Mục đích:** Khi 1 test KHÔNG thực thi được (không phải code bug), phân loại theo **4 nhóm** + định tuyến tới 3 SSOT files:

- `block-test.json` — log toàn diện (mọi block đều ghi)
- `implement-required.json` — danh sách cần F4 wf-e2e-implement (Nhóm 3)
- `manual.json` — danh sách cần QA test thủ công (Nhóm 4 verified-OK / needs-human)

**Quy tắc tối quan trọng:**
- **Nhóm 4 là trường hợp ĐẶC BIỆT DUY NHẤT** trong toàn bộ wf-e2e-* pipeline mà kết quả "verified qua code analysis" được chấp nhận thay cho live test.
- **Tất cả nhóm khác (1, 2, 3)** đều PHẢI cố gắng live test (tự seed data, auto-start hạ tầng, hoặc chờ implement). KHÔNG silent fallback code analysis.
- Nếu hạ tầng không chạy ở Nhóm 2 → MANDATORY `ensure_infrastructure_running` (xem `_shared.md` §Infrastructure Auto-Start) → auto-start fail sau 2 retry → mới ghi block-test.json Nhóm 2 + ESCALATE.

---

## 1. 4 Nhóm Block (canonical)

| Nhóm | Mô tả | blocking_reason enum | Hành động chính | Ghi vào file |
|------|-------|---------------------|-----------------|--------------|
| **1. Thiếu dữ liệu** | DB không có data test | `missing_seed_data`, `missing_cross_module_data`, `seed_accounts_unavailable`, `actor_account_missing` | **AUTO-FIX NGAY** → sinh seed → retest. Sau 2 lần fail → fallback ghi `block-test.json` | block-test.json (chỉ khi fallback) |
| **2. Hạ tầng không sẵn sàng** | BE/FE/DB không chạy, thiếu permission | `backend_not_running`, `fe_not_running`, `missing_permissions` | **AUTO-FIX NGAY** → Infrastructure Auto-Start / grant permission → retest. Sau 2 lần fail → fallback ghi `block-test.json` | block-test.json (chỉ khi fallback) |
| **3. Chưa implement** | Tính năng chưa code, deferred | `feature_deferred`, `feature_not_implemented` | **GHI ĐỒNG THỜI** block-test.json + **implement-required.json** → chờ F4 implement → KHÔNG auto-fix | block-test.json **+ implement-required.json** |
| **4. Khó test / Cần người** | Cần người nhìn UI, thao tác không automation được, external dependency, flaky | `requires_visual_inspection`, `requires_manual_interaction`, `external_dependency`, `flaky_test`, `requires_human_judgment`, `other` | **VERIFY CODE TRƯỚC** → đọc code để verify logic → ghi kết quả vào `code_verification` của manual.json → ghi đồng thời block-test.json | block-test.json **+ manual.json** |

---

## 2. Decision Tree (BẮT BUỘC)

```
TEST FAIL không phải code bug?
│
├── Nhóm 1 (thiếu data)?
│   ├── YES → AUTO-FIX (sinh seed / tạo account / ...)
│   │   ├── Fix xong → RETEST → PASS? → TIẾP TỤC test, KHÔNG ghi block-test
│   │   └── Sau 2 lần auto-fix vẫn fail → GHI block-test.json (fallback BLK entry)
│   └── NO → tiếp tục
│
├── Nhóm 2 (hạ tầng)?
│   ├── YES → AUTO-FIX (Infrastructure Auto-Start / grant permission)
│   │   ├── Fix xong → RETEST → PASS? → TIẾP TỤC, KHÔNG ghi block-test
│   │   └── Sau 2 lần fail → GHI block-test.json (fallback BLK entry)
│   └── NO → tiếp tục
│
├── Nhóm 3 (chưa implement)?
│   ├── YES → DUAL-WRITE:
│   │   1) GHI block-test.json: status="blocked", blocking_reason="feature_not_implemented"
│   │   2) GHI implement-required.json: new IMPL-REQ-NNN entry
│   │      ├── suggested_action: chọn enum phù hợp (implement_endpoint / implement_ui / ...)
│   │      ├── priority: P0 (block critical) | P1 | P2
│   │      ├── related_blk_id: link 2 chiều với BLK-NNN
│   │      └── status="pending"
│   │   → KHÔNG auto-fix — chờ F4 wf-e2e-implement
│   └── NO → tiếp tục
│
└── Nhóm 4 (khó test / cần người) — SPECIAL CASE DUY NHẤT cho code-analysis kết quả?
    │  Điều kiện áp dụng: test BẢN CHẤT cần con người nhìn/thao tác trực tiếp
    │  (visual_inspection, requires_real_payment, requires_3rd_party_login,
    │   requires_hardware, requires_human_judgment, external_dependency, flaky_test).
    │  KHÔNG dùng Nhóm 4 để bypass infra fail — đó là Nhóm 2 (live test bắt buộc, auto-start).
    │
    ├── YES → VERIFY CODE TRƯỚC:
    │   1) Đọc code (Serena find_symbol / Grep) để verify logic
    │   2) DUAL-WRITE:
    │      a) GHI block-test.json:
    │         - Code logic OK → status="resolved", retest_result="SKIPPED", note="verified qua code analysis (Nhóm 4 special case)"
    │         - Cần người thật → status="blocked", note lý do cụ thể
    │         - External dependency / flaky → status="blocked", note dependency + cách test khi có
    │      b) GHI manual.json: new MAN-NNN entry với:
    │         - manual_reason: enum phù hợp (visual_inspection / requires_real_payment / ...)
    │         - code_verification: {method, result PASS|FAIL|INCONCLUSIVE, code_location, notes}
    │         - recommended_test_steps[]: chi tiết bước cho QA
    │         - status: pending (chờ QA)
    │         - related_blk_id: link 2 chiều với BLK-NNN
    └── NO → ghi `other` với mô tả chi tiết
```

---

## 3. Atomic Write Pattern (CORE-035)

Mỗi lần ghi 1 entry (block-test / implement-required / manual):

```bash
# 1. READ file hiện tại (init từ template nếu chưa có)
# 2. Compute next_id = max(ids) + 1 (BLK-NNN / IMPL-REQ-NNN / MAN-NNN)
# 3. Append entry vào array (blocked_tests[] / entries[] / entries[])
# 4. Recompute summary counters (by_status, by_reason, by_phase, by_priority, by_action)
# 5. Update last_updated = now() (ISO-8601)
# 6. WRITE temp file (.tmp.$$)
# 7. VALIDATE: jq '.' temp > /dev/null (parse JSON)
# 8. Atomic move (mv temp → target)
```

**KHÔNG đợi cuối phase mới write.** ISSUE-IMMEDIATE pattern: phát hiện block → DỪNG test hiện tại → GHI → TIẾP TỤC test tiếp theo.

**Templates:** 
- `templates/block-test.template.json` 
- `templates/implement-required.template.json` 
- `templates/manual.template.json`

Mỗi template có `_template_notes` + `_schema_notes` — PHẢI strip trước khi write (CORE-031).

---

## 4. Dual-Write Logic chi tiết

### Nhóm 3 → DUAL-WRITE block-test.json + implement-required.json

```jsonc
// block-test.json entry
{
  "id": "BLK-003",
  "test_ref": "POST /api/v1/crm/customers — validation duplicate email",
  "phase": 3,
  "blocking_reason": "feature_not_implemented",
  "blocking_detail": "Endpoint thiếu validation duplicate email check trong CreateCustomerCommandHandler",
  "status": "blocked",
  "discovered_at": "2026-05-13T14:30:00Z",
  "related_impl_req_id": "IMPL-REQ-001"  // link 2 chiều
}

// implement-required.json entry  
{
  "id": "IMPL-REQ-001",
  "discovered_by_skill": "wf-e2e-test",
  "discovered_in_phase": 3,
  "test_ref": "POST /api/v1/crm/customers — validation duplicate email",
  "feat_id": "FEAT-EW-CRM-001",
  "req_id": "REQ-CRM-001",
  "blocking_reason": "validation_missing",
  "suggested_action": "implement_validation",
  "location_hint": "apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommandHandler.cs",
  "expected_behavior": "POST trả 400 với code DUPLICATE_EMAIL nếu email đã tồn tại trong company",
  "priority": "P0",
  "status": "pending",
  "related_blk_id": "BLK-003"  // link 2 chiều
}
```

### Nhóm 4 → VERIFY CODE → DUAL-WRITE block-test.json + manual.json

**Bước 1: Verify code logic**

Dùng Serena hoặc Grep để tìm code liên quan tới test, đánh giá:
- `static_code_review`: đọc code, đối chiếu với BR catalog → PASS/FAIL/INCONCLUSIVE
- `mock_api_test`: gọi API với mock data → check response shape + status
- `unit_test`: chạy unit test hiện có (nếu có) → check assertion

**Bước 2: Dual-write**

```jsonc
// block-test.json entry
{
  "id": "BLK-007",
  "test_ref": "VNPay sandbox redirect — verify payment success callback",
  "phase": 5,
  "blocking_reason": "requires_real_payment",
  "blocking_detail": "Test cần thực sự thanh toán qua VNPay sandbox, không thể automation",
  "status": "resolved",  // hoặc "blocked" nếu code FAIL hoặc INCONCLUSIVE
  "retest_result": "SKIPPED",
  "resolution_note": "Code logic verified PASS qua static review — signature verify + callback handler + idempotency đều đúng",
  "discovered_at": "2026-05-13T15:00:00Z",
  "related_manual_id": "MAN-001"  // link 2 chiều
}

// manual.json entry
{
  "id": "MAN-001",
  "discovered_by_skill": "wf-e2e-test",
  "discovered_in_phase": 5,
  "test_ref": "VNPay sandbox redirect — verify payment success callback",
  "feat_id": "FEAT-EW-FIN-008",
  "manual_reason": "requires_real_payment",
  "code_verification": {
    "verified_at": "2026-05-13T15:00:00Z",
    "verified_by_skill": "wf-e2e-test",
    "verification_method": "static_code_review",
    "verification_result": "PASS",
    "code_location": "apps/backend/Eureka.Modules.Finance/Application/Payments/VNPayService.cs:123",
    "notes": "Code logic OK — signature verify đúng, callback handler đúng, idempotency key đúng"
  },
  "recommended_test_steps": [
    "Bước 1: Đăng nhập VNPay Sandbox (account: testuser@vnpay.vn / Test@123)",
    "Bước 2: Tạo invoice 100.000đ trong erp-web → click 'Thanh toán'",
    "Bước 3: Verify redirect URL có chứa sandbox.vnpayment.vn",
    "Bước 4: Trên sandbox → chọn 'NCB' → submit",
    "Bước 5: Verify callback redirect về app → invoice status=Paid + ledger entry tạo đúng"
  ],
  "status": "pending",
  "assigned_to": "qa-team",
  "related_blk_id": "BLK-007"
}
```

---

## 5. Suggested Action Mapping (Nhóm 3)

| blocking_reason | suggested_action |
|-----------------|------------------|
| `endpoint_missing` / API handler không tồn tại | `implement_endpoint` |
| `ui_screen_missing` / Page/Component không tồn tại | `implement_ui` |
| `validation_missing` / Validator handler thiếu | `implement_validation` |
| `business_rule_missing` / BR chưa code | `implement_feature` |
| `seed_schema_missing` / Bảng/cột chưa migrate | `implement_seed_data` |
| `feature_deferred` / Tính năng hoãn có chủ đích | `implement_feature` (defer P2 priority) |
| `feature_not_implemented` / Code chưa có | `implement_feature` |

---

## 6. Priority Calibration (Nhóm 3)

| Priority | Khi nào | Tác động |
|----------|---------|----------|
| **P0** | Block critical/high test (happy path, BR core, security boundary) | F4 PHẢI implement trước F5 retest |
| **P1** | Block medium test (validation edge, error UX) | F4 nên implement |
| **P2** | Block low test (nice-to-have, deferred designed) | F4 có thể skip nếu deadline gấp |

---

## 7. Manual Reason Calibration (Nhóm 4)

| manual_reason | Khi nào áp dụng | Code verification method gợi ý |
|---------------|------------------|-------------------------------|
| `visual_inspection` | UI rendering, animation, layout phức tạp, responsive, màu sắc | `static_code_review` (đọc CSS/component) |
| `requires_real_payment` | VNPay/MoMo/banking real flow | `static_code_review` + `unit_test` (callback handler) |
| `requires_external_api` | External API không có sandbox | `mock_api_test` (mock client) |
| `requires_3rd_party_login` | OAuth Google/Facebook thật | `static_code_review` (callback exchange logic) |
| `requires_hardware` | Barcode scanner thật, GPS device | `unit_test` (parsing logic) |
| `requires_data_volume` | Test load 10k+ records, performance | `static_code_review` (pagination/query) — defer to perf test |
| `requires_human_judgment` | Quyết định subjective (vd: copy text quality) | `static_code_review` (template review) |

---

## 8. Anti-Patterns (KHÔNG được làm)

- ❌ KHÔNG ghi block-test.json mà bỏ qua implement-required.json khi Nhóm 3 (phải dual-write)
- ❌ KHÔNG ghi manual.json mà chưa verify code (phải code_verification trước)
- ❌ KHÔNG ghi cùng test_ref thành 2 BLK-NNN (check trùng trước khi append)
- ❌ KHÔNG dùng Nhóm 4 để bypass implement (nếu rõ ràng là chưa implement → Nhóm 3, không phải Nhóm 4)
- ❌ KHÔNG dùng Nhóm 4 để bypass infrastructure fail (BE/FE/DB không chạy → Nhóm 2 + MANDATORY auto-start, không phải Nhóm 4)
- ❌ KHÔNG silent fallback "code analysis" khi không thuộc 7 enum của Nhóm 4. Code analysis kết quả CHỈ hợp lệ khi `manual_reason` ∈ {visual_inspection, requires_real_payment, requires_external_api, requires_3rd_party_login, requires_hardware, requires_data_volume, requires_human_judgment}
- ❌ KHÔNG quên related_*_id link 2 chiều (orchestrator phụ thuộc vào link này để tracking)
- ❌ KHÔNG gom nhiều block thành 1 write (vi phạm ISSUE-IMMEDIATE pattern)

---

## 9. POST-GATE Check (T4 cross-reference)

Sau khi F1 phase 2-5 xong, POST-GATE T4 kiểm:

1. Mỗi BLK-NNN có `blocking_reason="feature_not_implemented" or "feature_deferred"` → PHẢI có related_impl_req_id link tới implement-required.json
2. Mỗi BLK-NNN có Nhóm 4 reason → PHẢI có related_manual_id link tới manual.json
3. Mỗi IMPL-REQ-NNN PHẢI có related_blk_id link ngược tới block-test.json
4. Mỗi MAN-NNN PHẢI có related_blk_id link ngược + code_verification.verification_result ∈ {PASS, FAIL, INCONCLUSIVE}

Vi phạm → POST-GATE FAIL → auto-fix attempt sửa link → max 3 retries (CORE-034).

---

## 10. Error Codes (E010-E019 namespace)

| Code | Phase | Mô tả |
|------|-------|-------|
| E010 | Setup | Template implement-required.template.json / manual.template.json không tồn tại |
| E011 | Init | Lock file conflict khi append block-test/implement-required/manual |
| E012 | Classification | blocking_reason không thuộc enum hợp lệ |
| E013 | Dual-write | Nhóm 3 thiếu link related_impl_req_id |
| E014 | Dual-write | Nhóm 4 thiếu code_verification |
| E015 | POST-GATE | Cross-reference link không khớp 2 chiều |
| E016 | Atomic write | jq validate fail sau write (corrupted JSON) |
| E017 | Schema | Entry thiếu required field (id, test_ref, phase, blocking_reason) |
| E018 | Idempotency | Trùng test_ref → 2 BLK-NNN (warning, không fail) |
| E019 | Manual flow | code_verification.verification_result=FAIL nhưng vẫn ghi manual → escalate ISSUE thay vì manual |

---

## 11. Reference

- Template files: `templates/block-test.template.json`, `templates/implement-required.template.json`, `templates/manual.template.json`
- Consumer skills: F3 wf-e2e-unblock (block-test groups 1+2+4), F4 wf-e2e-implement (implement-required), QA team (manual.json)
- Atomic write pattern: CORE-035
- Issue immediate pattern: SKILL.md §ISSUE-IMMEDIATE
