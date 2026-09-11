# LLM Probe — QD6 Data Integrity & Resilience (v2.0)

Vai tro: Senior database engineer + data architect.

> **v2.0:** mo rong 10 → 15 categories — them 5 patterns distributed/GDPR/connection (saga compensation, idempotency keys, GDPR retention, read replica lag, connection leak, time-series tz). Severity matrix.

---

## 1. Tap trung phat hien

### 1.1 Core (10 categories ban dau)

1. **Transaction boundary missing**: Multiple writes phai atomic nhung khong wrap trong transaction (vd: tao Order + cap nhat Inventory).
2. **Cascade delete unintended**: ON DELETE CASCADE xoa records ma user khong expect (vd: xoa User → xoa toan bo Orders cua user → mat audit trail).
3. **Foreign key constraint missing**: References khong co FK → orphaned rows khi parent bi xoa.
4. **Migration breaking change**: ALTER COLUMN type without USING clause, DROP COLUMN voi data live.
5. **Race condition trong update**: Read-modify-write khong atomic (`SELECT count → count++; UPDATE`).
6. **Optimistic locking missing**: Multiple users edit same record → last write wins → mat data.
7. **Backup/recovery khong test**: Schema thay doi nhung migration rollback path khong ton tai.
8. **JSON column khong validate**: `JSONB metadata` cho any shape, code cha thay schema giua versions.
9. **Soft-delete not respected in queries**: Code SELECT khong check `deleted_at IS NULL`.
10. **Constraint thieu**: NOT NULL missing cho field business critical, UNIQUE thieu cho identifier.

### 1.2 Mo rong (5 categories moi — v2.0)

11. **Distributed transaction / saga compensation missing**: Workflow span multiple services (vd: order → payment → fulfillment) khong co compensation rollback khi step thu N fail. Result: data inconsistency cross-service.
12. **Idempotency keys for state changes**: Multi-step state-change (createOrder, processPayment) khong co idempotency table → duplicate khi retry. (Lien quan QD2.9 nhung o tang DB.)
13. **GDPR right-to-erasure / data retention**: User delete request → code `DELETE FROM users WHERE id = ?` nhung khong cascade ve audit logs / order history / cache → PII residual. Hoac retention policy thieu (data > 7 nam khong purge).
14. **Read replica lag handling**: Code write to primary, sau do read tu replica ngay → stale data. Khong dung "read-your-write" (sticky session) hoac wait-for-replication.
15. **Time-series timestamp without timezone / connection leak**: Column `TIMESTAMP` thay vi `TIMESTAMPTZ` → DST bug khi cross-region. DB connection acquired khong release (try khong finally close) → pool exhaust.

---

## 2. Severity Calibration (QD6-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Transaction missing | **critical** | Always (data inconsistency) |
| Cascade delete (audit) | **high** | Lam mat compliance trail → critical |
| FK missing | **high** | Production DB → critical |
| Migration breaking | **critical** | Production deploy → always critical |
| Race condition update | **high** | Financial → critical |
| Optimistic lock missing | **medium** | Multi-user edit common → high |
| No rollback path | **high** | Always (recovery risk) |
| JSON unvalidated | **medium** | Stored 1+ yr → high (schema drift) |
| Soft-delete not respected | **high** | Cross-tenant query → critical |
| NOT NULL/UNIQUE missing | **medium** | Identity field → high |
| Saga compensation missing | **critical** | Cross-service write |
| Idempotency key DB schema missing | **high** | Payment retry path → critical |
| GDPR retention/erasure missing | **critical** | Always (regulatory) |
| Read replica lag unhandled | **high** | Financial flow → critical |
| TIMESTAMP without TZ | **high** | Cross-region/scheduled → critical |

---

## 3. KHONG focus (tranh duplicate)

- Schema drift detection → static probe (P-QD6-schema-drift-detect)
- Migration integrity static → static probe (P-QD6-migration-integrity)
- ORM N+1 → QD4 LLM probe
- Data type mismatch static → static probe (P-QD6-data-type-mismatch)
- ORM model sync → static probe (P-QD6-orm-model-sync)
- Seed data audit → static probe (P-QD6-seed-data-audit)

---

## 4. Negative Patterns — KHONG emit (QD6-specific)

> Bo sung cho `_shared.md` §5.

1. **Transaction missing KHI** chi 1 write statement (no need to wrap).
2. **FK missing KHI** dung NoSQL (MongoDB/DynamoDB) — khong co FK semantically.
3. **Optimistic lock missing KHI** field write-once (created_at, immutable id).
4. **JSON unvalidated KHI** la analytics event payload (intentionally schema-less).
5. **GDPR erasure missing KHI** project khong co user PII (vd: developer tool noi bo).
6. **TIMESTAMP without TZ KHI** UTC-only by app convention va da stored UTC.
7. **Read replica lag KHI** read-after-write delay > 5s la acceptable theo product spec.

---

## 5. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD6 data integrity (use-case kinh dien — schema/migration la noi CI tools manh nhat):

- **Schema drift (entity vs DB)**: `mcp__plugin_gitnexus_gitnexus__impact({target: <Entity_class>, direction:"upstream"})` → xem moi noi dung Entity. Sau do `mcp__serena__find_referencing_symbols({name_path: <field>, relative_path: <entity>})` cho field bi drop/rename → list precise call sites bi gay.
- **Migration thieu rollback / dropping NOT-NULL column**: `mcp__plugin_gitnexus_gitnexus__impact({target: <column_name>, direction:"upstream"})` → blast radius cho fix. HIGH/CRITICAL → flag CDG-06 (destructive DB).
- **ORM N+1 / lazy load**: `mcp__plugin_gitnexus_gitnexus__query({query: "<endpoint>"})` → trace endpoint chua repository call.
- **Constraint violation (FK, unique, check)**: `mcp__serena__find_referencing_symbols({name_path: "Repository.save"})` → xem cac noi insert co validate constraint khong.
- **Data type mismatch (string trong number column, date format khac)**: `mcp__serena__find_referencing_symbols` cho field type alias.
- **Seed/fixture out of sync**: `mcp__serena__get_symbols_overview` cho seeders directory.
- **Saga compensation flow**: `mcp__plugin_gitnexus_gitnexus__query({query: "saga compensate"})` → trace rollback handlers.

Populate `evidence.ci_citation` voi `gitnexus_impact_callers` (cuc ky quan trong cho schema bug — quyet dinh severity), `serena_refs_count`, va `tools_used`.

---

## 6. Vi du

### 6.1 Positive — Transaction missing

```json
{
  "title": "createOrder thieu transaction wrap voi inventory update",
  "description": "orders.service.ts:142 tao Order roi update Inventory.stockCount tach biet. Neu fail giua chung → Order tao thanh cong ma stock khong giam → oversell. Khong co try/catch + rollback.",
  "severity": "critical",
  "fixability": "agent_fix",
  "domain": "database",
  "req_ids": ["REQ-ORDER-CREATE", "REQ-INV-DECREMENT"],
  "feat_ids": ["FEAT-ORDER-CREATE"],
  "affected_modules": ["order-service", "inventory-service"],
  "location": {"file": "src/orders/orders.service.ts", "line": 142},
  "evidence": {
    "code_snippet": "await this.ordersRepo.save(order);\n// Khong co transaction wrap\nawait this.inventoryRepo.decrementStock(productId, qty);",
    "reproduction_steps": "1. Tao order, 2. Mock inventory.decrementStock throw error, 3. Quan sat: Order da save vao DB nhung stock chua giam → inventory inconsistent.",
    "confidence": 0.93
  },
  "remediation": {
    "suggested_action": "Wrap trong DB transaction: this.dataSource.transaction(async manager => { await manager.save(order); await manager.decrementStock(...); }). Neu inner throw → auto rollback.",
    "test_recommendation": "Integration test: mock decrementStock to throw → assert order khong ton tai trong DB sau action.",
    "estimated_effort_min": 25,
    "regression_risk": "medium"
  }
}
```

### 6.2 Critical — GDPR erasure missing

```json
{
  "title": "User delete khong xoa PII trong audit logs vi pham GDPR right-to-erasure",
  "description": "Endpoint DELETE /api/users/:id trong users.service.ts:72 chi xoa row trong table users (soft-delete). Tables audit_logs va order_history van giu cot user_email + user_phone (PII). User yeu cau erasure (Article 17 GDPR) → he thong KHONG bao dam xoa toan bo PII → vi pham phap ly.",
  "severity": "critical",
  "fixability": "manual_fix",
  "domain": "database",
  "req_ids": ["REQ-COMPLIANCE-GDPR-001"],
  "feat_ids": ["FEAT-USER-DELETE"],
  "affected_modules": ["user-service", "audit-service", "order-history"],
  "location": {"file": "src/users/users.service.ts", "line": 72},
  "evidence": {
    "code_snippet": "async deleteUser(userId: string) {\n  await this.repo.softDelete(userId);\n  // missing: anonymize audit_logs.user_email, order_history.user_phone\n}",
    "reproduction_steps": "1. Tao user co audit log + order history, 2. POST /api/users/:id/delete (GDPR erasure), 3. SELECT * FROM audit_logs WHERE user_email = ? → ROW VAN CON.",
    "confidence": 0.9,
    "ci_citation": {
      "gitnexus_impact_callers": 12,
      "tools_used": ["gitnexus_impact"]
    }
  },
  "remediation": {
    "suggested_action": "Tao job DeleteUserJob: (1) anonymize PII fields trong audit_logs (`user_email = NULL`), (2) anonymize order_history.user_phone, (3) hard-delete users row sau retention period 30 ngay. Compliance officer approve.",
    "test_recommendation": "E2E test: delete user → query all tables → no PII match.",
    "references": ["https://gdpr.eu/article-17-right-to-be-forgotten/"],
    "estimated_effort_min": 240,
    "regression_risk": "high"
  }
}
```

### 6.3 Counter-example — DO NOT emit

```typescript
// log-event.ts (analytics events)
await db.events.insert({
  event_type: 'page_view',
  payload: req.body  // <-- JSON column khong validate schema
});
// LLM TEMPTED: "JSON column khong validate → bug!" → SAI
```

**Ly do KHONG emit:**
- Day la **analytics events** — payload intentionally schema-less de support evolution.
- Khong dung consume nay cho business logic, chi de aggregate stats.
- Match negative pattern §4 cua dimension QD6.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
