# LLM Probe — QD10 Cross-Module Integration (v1.0)

Vai tro: Senior architect + data engineer. Phat hien **cross-module reference drift**, **API contract violations**, **event handler coverage gaps**, **orphan FK references**, **multi-platform entity sync errors**, **cache staleness** giua cac module, **state machine errors**, **business flow violations**, va **auth matrix violations**.

> **v1.0 (2026-05-11):** moi-them LLM probe chuyen biet cho QD10 lane. Khac voi `llm-probe-integration.md` (cross-dimension QD1-QD10), probe nay TAP TRUNG vao integration GIUA CAC MODULE — cross-module dependency graph, contract enforcement, multi-platform consistency.

---

## 1. Tap trung phat hien

### 1.1 Cross-Module Reference Drift

1. **Import path stale sau refactor**: Module A import `../../module-b/old-path/utils` nhung module B da doi cau truc thu muc → import fail runtime (TypeScript co the pass neu alias).
2. **Type definition out of sync**: Shared types `packages/types/` cap nhat nhung consumer module chua rebuild → interface mismatch → runtime error "property X does not exist".
3. **Barrel export thieu**: Module export component qua `index.ts` barrel nhung component da bi xoa/rename → import fail.
4. **Circular dependency runtime fail**: Module A import Module B, Module B import Module A → bundler warn nhung runtime co the fail (undefined export).

### 1.2 API Contract Violations

5. **Frontend assume old API shape**: Backend endpoint doi response field name/type → frontend destructure sai → `undefined` propagate → UI broken.
6. **Request payload mismatch**: Frontend POST payload thieu required field (them sau migration) → server tra 400 → feature broken.
7. **Error response shape khac nhau**: Module A tra `{error: {code, message}}`, Module B tra `{message}` → shared error handler crash parse.
8. **Pagination contract drift**: Backend doi tu `{items, total}` sang `{data, meta: {total}}` → frontend pagination break.

### 1.3 Event Handler & Message Coverage

9. **Event emitter listener thieu**: Service A emit `order.created` event → Service B (notification) khong subscribe → email never send.
10. **Webhook handler khong implement het events**: Webhook endpoint xu ly `payment.success` nhung khong handle `payment.failed`, `payment.refunded` → silent ignore.
11. **Message queue consumer thieu**: Message published to queue `stock-reserved` nhung consumer khong ton tai → message expire → system inconsistent.
12. **Cross-service event ordering bug**: Service A emit `user.deleted` + Service B emit `user.anonymized` → order khong dam bao → audit log thieu event.

### 1.4 Orphan References & Data Integrity

13. **FK reference to deleted entity**: Code trong Module A `SELECT * FROM orders WHERE user_id = ?` nhung user da bi xoa (cascade miss) → orphan rows khong cleanup.
14. **Cache key referencing missing data**: Redis key `module:a:user:${id}:profile` populate boi Module B → Module B refresh/delete key → Module A van expect ton tai → null reference.
15. **Enum value sync cross-module**: Module A define `Status = {ACTIVE, INACTIVE, SUSPENDED}`. Module B add `Status.DELETED`. DB co row voi 'DELETED' → Module A crash parse.

### 1.5 Multi-Platform & Entity Sync

16. **Mobile vs Web state divergence**: Mobile app offline cache entity → web app update same entity → mobile sync stale → conflict resolution thieu.
17. **Admin portal vs User portal data lag**: Admin update product price → user portal van hien gia cu do cache/cdn → user mua voi gia sai.
18. **Real-time sync gap**: WebSocket update entity → mobile notification push delay → 2 platforms hien 2 state khac nhau trong 5s.

### 1.6 State Machine & Business Flow Violations

19. **Cross-module state transition invalid**: Order state "shipped" (Module Order) → Module Return cho phep "return" → Order state khong update "return_requested" → inventory chua reserve.
20. **Multi-step workflow skip step**: Approval flow: Step 1 (manager) → Step 2 (director) → Step 3 (finance). Module A cho skip Step 2 khi amount < threshold, nhung Module B (audit) van expect 3 signatures → audit flag.
21. **Idempotency key scope conflict**: Module A dung `order_${id}` lam idempotency key, Module B cung dung cung pattern cho khac operation → key collision → create in A dup B.

### 1.7 Auth & Permission Matrix Violations

22. **Cross-module role inconsistency**: Module A define role "manager" co quyen delete → Module B khong gan quyen delete cho "manager" → user co quyen delete trong A nhung khong trong B.
23. **Tenant isolation gap cross-module**: Module A filter `tenant_id` trong query, Module B quen filter → cross-tenant data leak trong report.
24. **Token scope mismatch**: Module A generate token scope `read:orders write:orders`, Module B require `admin:orders` → service-to-service call fail.

---

## 2. Severity Calibration (QD10-specific)

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Import path stale | **high** | Production build fail → critical |
| Type out of sync | **high** | Runtime crash → critical |
| Barrel export thieu | **medium** | Production 404 → high |
| Circular dependency | **high** | Always (build/runtime risk) |
| API contract drift | **high** | Breaking change to user → critical |
| Request payload mismatch | **high** | Always |
| Error response shape drift | **medium** | Shared error handler → high |
| Pagination contract drift | **medium** | Multi-page list → high |
| Event listener thieu | **high** | Critical notification (payment, auth) → critical |
| Webhook handler incomplete | **high** | Payment refund event → critical |
| Message consumer thieu | **high** | Distributed transaction → critical |
| Event ordering bug | **high** | Audit/compliance → critical |
| Orphan FK reference | **medium** | Cascade to reporting → high |
| Cache key stale after delete | **high** | Financial entity → critical |
| Enum value sync | **high** | DB has value → critical |
| Mobile vs Web divergence | **medium** | E-commerce inventory → high |
| Admin vs User portal lag | **high** | Price/availability → critical |
| Real-time sync gap | **medium** | Trading/live bidding → high |
| State machine cross-module | **high** | Always (business logic) |
| Multi-step workflow skip | **high** | Financial approval → critical |
| Idempotency key collision | **high** | Payment/order → critical |
| Cross-module role inconsistency | **critical** | Always (security) |
| Tenant isolation gap | **critical** | Always (security/legal) |
| Token scope mismatch | **high** | Service-to-service → critical |

> **Quy tac chung:** Bug span >=2 modules + primary user flow → severity floor `high`. Bug anh huong cross-module auth/data isolation → always `critical`.

---

## 3. KHONG focus (tranh duplicate)

- Cross-module reference static → static probe (P-QD10-cross-module-ref-static)
- API contract drift runtime → runtime probe (P-QD10-api-contract-drift)
- Event handler coverage static → static probe (P-QD10-event-handler-coverage)
- Orphan reference runtime → runtime probe (P-QD10-orphan-reference-runtime)
- Multi-platform entity sync → runtime probe (P-QD10-multi-platform-entity-sync)
- Cache staleness probe → runtime probe (P-QD10-cache-staleness-probe)
- State machine correctness → static probe (P-QD10-state-machine-correctness)
- Business flow runtime → runtime probe (P-QD10-business-flow-runtime)
- Auth matrix check → static probe (P-QD10-auth-matrix-check)

---

## 4. Negative Patterns — KHONG emit (QD10-specific)

> Bo sung cho `_shared.md` §5.

1. **Import alias path KHI** da duoc map trong `tsconfig.json` paths (vd: `@shared/utils` → resolved correctly).
2. **Different error shape KHI** 2 modules su dung 2 API gateway khac nhau + co transform layer o BFF (Backend-for-Frontend).
3. **Event listener thieu KHI** chi la optional enhancement (vd: analytics event — fire-and-forget, khong business-critical).
4. **Cache key stale KHI** TTL < 5s + data is eventually consistent by design (CAP trade-off).
5. **State machine transition KHI** intentional shortcut duoc approve boi business (vd: emergency skip approval).
6. **Cross-module role KHI** 2 modules co 2 role hierarchy khac nhau by design (vd: admin portal vs merchant portal).
7. **Enum mismatch KHI** consumer module xu ly unknown enum value bang fallback gracefully (pattern matching voi default case).

---

## 5. CI Tools (BAT BUOC dung khi available)

QD10 probe **PHAI** dung CI tools (neu co) vi cross-module analysis khong the thuc hien chinh xac bang grep don thuan:

- **Cross-module import trace**: `mcp__plugin_gitnexus_gitnexus__impact({target: <shared_symbol>, direction: "downstream"})` → xem symbol duoc import boi nhung module nao.
- **Module dependency graph**: `mcp__plugin_gitnexus_gitnexus__query({query: "module dependency"})` → visualize cross-module wiring.
- **API contract cross-ref**: `mcp__serena__find_referencing_symbols({name_path: <DTO_class>, relative_path})` → liet ke moi noi consume DTO → detect drift.
- **Event emitter/consumer mapping**: `mcp__serena__find_referencing_symbols({name_path: "EventEmitter.emit"})` → list emit sites. Sau do `find_referencing_symbols` cho `EventEmitter.on`/`addListener` → confirm consumer exists.
- **Cache key cross-module**: `mcp__serena__find_referencing_symbols({name_path: <cache_key_pattern>, relative_path})` → xem nhung module nao read/write cung cache key.
- **Auth middleware coverage**: `mcp__plugin_gitnexus_gitnexus__route_map()` → check route-level guard consistency.
- **Enum value propagation**: `mcp__serena__find_referencing_symbols({name_path: <enum_name>})` → confirm consumer handles all values.

CI absent → emit voi confidence ≤ 0.6 + caveat "needs cross-module integration test".

---

## 6. Vi du

### 6.1 Positive — Event listener missing

```json
{
  "title": "order.created event khong co consumer cho notification → email khong bao gio gui",
  "description": "Module orders/order.service.ts:88 emit event 'order.created' qua EventEmitter. Module notifications (notification/subscribers/) dang ky consumer cho cac event khac ('user.registered', 'payment.completed') nhung KHONG co handler cho 'order.created'. Ket qua: dat hang thanh cong nhung khach hang khong nhan duoc email xac nhan → trai nghiem kem, support team nhan khieu nai.",
  "severity": "high",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-ORDER-NOTIFY", "REQ-NOTIFICATION-EMAIL"],
  "feat_ids": ["FEAT-ORDER-CREATE", "FEAT-NOTIFICATION-EMAIL"],
  "affected_modules": ["order-service", "notification-service"],
  "location": {"file": "src/orders/order.service.ts", "line": 88},
  "evidence": {
    "code_snippet": "// Module orders/order.service.ts:88\nawait this.orderRepo.save(order);\nthis.eventEmitter.emit('order.created', { orderId: order.id, userId });\n\n// Module notification/subscribers/index.ts\n// has: user.registered, payment.completed, shipment.status_changed\n// MISSING: order.created",
    "reproduction_steps": "1. Tao order moi POST /api/orders, 2. Check notification service log: khong co event 'order.created' duoc process, 3. Check email inbox: khong co order confirmation, 4. Check EventEmitter listener count: 'order.created' = 0.",
    "confidence": 0.91,
    "ci_citation": {
      "gitnexus_flow": "order-creation-flow",
      "serena_refs_count": 5,
      "tools_used": ["gitnexus_query", "serena_find_referencing_symbols"]
    }
  },
  "remediation": {
    "suggested_action": "Them subscriber trong notification/subscribers/: this.eventEmitter.on('order.created', async (payload) => { await this.emailService.sendOrderConfirmation(payload.userId, payload.orderId); });",
    "test_recommendation": "Integration test: emit 'order.created' event → assert email service.sendOrderConfirmation duoc goi. Event count check: verify listenerCount('order.created') >= 1.",
    "estimated_effort_min": 30,
    "regression_risk": "low"
  }
}
```

### 6.2 Critical — Cross-module role inconsistency

```json
{
  "title": "Role 'manager' co quyen delete trong CRM module nhung khong trong Audit module → user co the xoa record nhung audit log khong ghi nhan",
  "description": "CRM module (crm/permissions.ts:45) cho role 'manager' quyen `delete:leads`. Audit module (audit/permissions.ts:32) chi cho 'admin' quyen `write:audit_log`. Khi manager xoa lead → CRM pass, goi audit.log('lead.deleted') → audit tra 403 → lead bi xoa nhung audit trail mat. Vi pham compliance requirement (REQ-COMPLIANCE-AUDIT-001).",
  "severity": "critical",
  "fixability": "manual_fix",
  "domain": "backend",
  "req_ids": ["REQ-CRM-LEAD-DEL", "REQ-COMPLIANCE-AUDIT-001"],
  "feat_ids": ["FEAT-CRM-LEAD-DELETE", "FEAT-AUDIT-TRAIL"],
  "affected_modules": ["crm-leads", "audit-service"],
  "location": {"file": "src/crm/permissions.ts", "line": 45},
  "evidence": {
    "code_snippet": "// crm/permissions.ts:45\nconst ROLE_PERMISSIONS = {\n  manager: ['read:leads', 'write:leads', 'delete:leads'],\n};\n// audit/permissions.ts:32\n{\n  manager: ['read:audit_log'],  // missing: write:audit_log\n  admin:   ['read:audit_log', 'write:audit_log'],\n}",
    "reproduction_steps": "1. Login as manager, 2. Delete lead L1 (crm.deleteLead), 3. Check audit log: khong co entry 'lead.deleted', 4. API logs: 403 POST /api/audit/log.",
    "confidence": 0.93,
    "ci_citation": {
      "gitnexus_flow": "lead-deletion-flow",
      "gitnexus_impact_callers": 8,
      "tools_used": ["gitnexus_query", "gitnexus_impact"]
    }
  },
  "remediation": {
    "suggested_action": "Align role matrix: (1) Them 'write:audit_log' cho role 'manager' trong audit module; (2) Audit endpoint tra 202 accepted + queue (async log) de khong can require write permission tu sync call; (3) Them cross-module auth matrix test de prevent future drift.",
    "test_recommendation": "Cross-module role test: moi role → check all module permissions consistent. Snapshot role-permission matrix.",
    "estimated_effort_min": 120,
    "regression_risk": "high"
  }
}
```

### 6.3 Counter-example — DO NOT emit

```typescript
// analytics-tracker.ts (Module Analytics)
export function trackPageView(path: string) {
  fetch('/api/analytics/pageview', { method: 'POST', body: JSON.stringify({ path }) });
  // No await, no .catch — fire-and-forget
}

// LLM TEMPTED: "trackPageView called from 3 modules but no error handling → event loss!" → SAI
```

**Ly do KHONG emit:**
- `trackPageView` la analytics helper — fire-and-forget by design.
- Event loss o analytics khong anh huong business logic.
- Module chi lien quan one-way (emit only, no response expected).
- Match negative pattern §3 cua dimension QD10.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
