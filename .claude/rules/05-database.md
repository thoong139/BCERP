---
paths:
  - "**/*.repository.ts"
  - "**/*.migration.*"
  - "**/*.schema.*"
  - "**/*.entity.ts"
  - "**/*.model.ts"
  - "**/*.sql"
  - "**/migrations/**"
  - "**/database/**"
  - "**/repositories/**"
---

# Database Rules

## 1. Repository Pattern (BẮT BUỘC)

`controller → service → repository → DB`. CẤM Service/Controller query DB trực tiếp. CẤM Repository chứa business logic.

## 2. Table Structure (BẮT BUỘC)

Mọi table PHẢI có: `id` (UUID), `created_at` (TIMESTAMPTZ), `updated_at` (TIMESTAMPTZ), `deleted_at` (TIMESTAMPTZ NULL — soft delete).

## 3. Soft Delete

- `UPDATE SET deleted_at = NOW()` thay vì `DELETE`
- Mọi query phải filter `WHERE deleted_at IS NULL`

## 4. Indexing

Index trên: foreign keys, status columns, WHERE clauses, ORDER BY columns.

## 5. Transactions

Transaction BẮT BUỘC khi modify >1 table. KHÔNG để multiple writes mà không có transaction.

## 6. Query Best Practices

- Select needed fields only, tránh `SELECT *`
- Pagination: `LIMIT $1 OFFSET $2`
- KHÔNG N+1 queries — dùng JOIN hoặc batch query
- Default timeout 5s, long queries set explicit timeout

## 7. Migrations

Mỗi migration PHẢI có UP + DOWN. Test trên development trước, backup trước khi migrate production.
