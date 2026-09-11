<!-- From shared-protocols.md lines 121-235 (§3) -->
# Protocol 3 — Context & Checkpoint Protocol (Layer 2 Upgrade — Phiên 5+)

> Áp dụng cho Multi-session skills. **Phiên 5+: Upgraded với context_digest — tóm tắt bộ não session, không chỉ vị trí.**

## 3.1 Checkpoint Thresholds & Save Points

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | ✅ Tiếp tục bình thường |
| 65–80% | ⚠️ Chuẩn bị checkpoint |
| 80–90% | 🔴 Lưu checkpoint ngay |
| > 90% | ⛔ FORCE STOP — checkpoint bắt buộc |

## 3.2 Checkpoint Schema & Context Digest (LỚP 2 FEATURE)

**Phiên 5+: Mỗi batch kết thúc PHẢI generate context_digest**

Cấu trúc checkpoint:
```json
{
  "checkpoint_id": "CP-20260404-001",
  "phase": "phase_3",
  "batch": 2,
  "next_action": "implement_service_layer",

  "context_digest": {
    "feature_summary": "Quản lý khách hàng với soft-delete và audit trail",
    "architectural_decisions": [
      {
        "decision": "Dùng TypeORM Repository pattern",
        "reason": "Project đã có TypeORM setup, consistency",
        "affects": ["entity", "repository", "service"]
      }
    ],
    "interfaces_established": {
      "ICustomerRepository": {
        "file": "src/repositories/customer.repository.interface.ts",
        "key_methods": ["findById", "findByEmail", "softDelete"],
        "notes": "Tất cả query PHẢI filter deletedAt IS NULL"
      }
    },
    "patterns_in_use": {
      "error_handling": "throw AppError(code, httpStatus) trong service, catch trong controller middleware",
      "naming": "camelCase variables, PascalCase classes"
    },
    "cross_batch_contracts": {
      "batch_1_exports": ["CustomerEntity (src/entities/customer.entity.ts)"],
      "batch_2_imports": ["Cần CustomerEntity type cho service"]
    },
    "gotchas_and_warnings": [
      "Email field có UNIQUE constraint — mọi create/update phải check duplicate",
      "deletedAt phải là nullable Date, không phải boolean"
    ]
  }
}
```

> **Schema:** `.claude/skills/schemas/checkpoint-schema.json`

## 3.3 Context Digest Generation (Batch Completion Step)

**Sau MỖI batch hoàn thành, agent PHẢI generate digest:**

```
QUY TẮC:
1. Mỗi batch kết thúc → agent tự tóm tắt context trong digest
2. Digest format: theo schema ở section 3.2
3. Digest KHÔNG được qua agent bên ngoài — developer agent tự sinh

FIELDS BẮT BUỘC:
  - feature_summary (required, ~100-200 từ)
  - architectural_decisions (recommended, >= 1)
  - interfaces_established (recommended nếu có interface)
  - patterns_in_use (recommended, >= 1)
  - cross_batch_contracts (recommended nếu có batch tiếp theo)
  - gotchas_and_warnings (recommended, >= 1)

FIELDS OPTIONAL:
  - Bất kỳ field nào có additionProperties: true
```

## 3.4 Resume Process — Digest Injection

**Khi --resume, PHẢI inject digest TRƯỚC khi đọc full files:**

```
1. READ checkpoint.json → extract context_digest
2. INJECT digest vào prompt chính (first line của Phase intro)
3. Agent nhận digest — biết NGAY:
   - Feature đang làm gì?
   - Quyết định kiến trúc nào đã chốt?
   - Interface nào đã establish?
   - Pattern/convention nào?
   - Warning gì cần nhớ?
4. CHỈ read full files nếu:
   - Digest chưa chi tiết đủ
   - Cần xác nhận chi tiết cụ thể
   - Có conflict giữa digest và code thực tế

BENEFIT:
  - Agent không cần re-read 5-10 files → giảm ~50% context
  - Agent có explicit decisions từ session trước → tăng accuracy
  - Resume time giảm từ 10 phút xuống ~3 phút

BACKWARD COMPATIBILITY:
  - Nếu checkpoint cũ KHÔNG có context_digest → skip, hoạt động như trước
  - Skill KHÔNG break với checkpoint cũ
```

## 3.5 Resume Process — Original (No Digest)

1. READ `[skill]-status.json` từ `.mc-data/work/[skill]/`
2. LOAD context từ `checkpoint.json`
3. CONTINUE từ `next_action` trong status file
