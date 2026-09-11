# DB Mapping — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}

## 1. Tables & Entities

| Table | Entity Class | Schema | File Path |
|-------|-------------|--------|-----------|
| {table_name} | {EntityClass} | {schema} | `{path/to/Entity.cs}` |

## 2. Columns Quan Trọng

### {table_name}

| Column | Type | Nullable | Constraints | Ghi chú |
|--------|------|----------|-------------|---------|
| id | uuid | NO | PK, gen_random_uuid() | |
| {col} | {type} | {YES/NO} | {constraints} | |
| created_at | timestamptz | NO | DEFAULT now() | |
| updated_at | timestamptz | NO | | |
| is_deleted | bool | NO | DEFAULT false | Soft delete |

## 3. Relationships

| From | Relationship | To | FK Column | Config |
|------|--------------|----|-----------|--------|
| {TableA} | HasMany | {TableB} | {fk_col} | {OnDelete behavior} |

## 4. CRUD Operations

| Operation | Trigger | Handler | SQL Effect |
|-----------|---------|---------|------------|
| Create | POST /api/v1/{route} | CreateXxxCommandHandler | INSERT INTO {table} |
| Read | GET /api/v1/{route} | GetXxxQueryHandler | SELECT FROM {table} |
| Update | PUT /api/v1/{route} | UpdateXxxCommandHandler | UPDATE {table} |
| Delete | DELETE /api/v1/{route} | DeleteXxxCommandHandler | Soft delete (is_deleted=true) |

## 5. Migration Files

| Migration | File | Tables Affected |
|-----------|------|-----------------|
| {MigrationName} | `Migrations/{timestamp}_{MigrationName}.cs` | {tables} |

## 6. Transaction Scope

{Mô tả: single table / multi-table / có UnitOfWork không?}
