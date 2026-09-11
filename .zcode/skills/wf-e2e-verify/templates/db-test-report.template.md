# DB Test Report — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}

## 1. Migration Check

| Migration | Status | Ghi chú |
|-----------|--------|---------|
| {MigrationName} | ✅ Applied / ⚠️ Pending / ❌ Missing | |

```
Kết quả lệnh:
dotnet ef migrations list ...
{output ở đây}
```

## 2. EF Config Analysis

| Hạng mục | Kết quả | File | Ghi chú |
|----------|---------|------|---------|
| Required columns | ✅/❌ | `{config file}` | |
| MaxLength constraints | ✅/❌ | | |
| FK configured | ✅/❌ | | |
| Index trên FK | ✅/❌ | | |
| Soft delete pattern | ✅/❌ | | `IsDeleted + DeletedAt?` |
| Timestamp columns | ✅/❌ | | `CreatedAt + UpdatedAt` |
| UUID default gen | ✅/❌ | | `gen_random_uuid()` |

## 3. Constraint Verification

| Table | Constraint | Expected | Actual | Pass/Fail |
|-------|-----------|---------|--------|-----------|
| {table} | {col} NOT NULL | NOT NULL | | - |
| {table} | {col} UNIQUE | UNIQUE | | - |

## 4. Issues Found

| # | Severity | Vấn đề | File | Recommendation |
|---|----------|--------|------|----------------|
| 1 | HIGH/MED/LOW | {mô tả} | | |

## 5. Summary

- Migration status: {OK / PENDING}
- EF config: {N} issues found
- Constraints: {N} issues found
- Overall: ✅ PASS / ⚠️ WARN / ❌ FAIL
