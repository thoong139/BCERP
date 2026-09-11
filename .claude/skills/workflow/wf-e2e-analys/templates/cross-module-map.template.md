# Cross-Module Trigger Map — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Phạm vi: domain events feature này publish + consumer modules + side effects.

---

## 1. Domain Events Published

| Event | Triggered by | Source location | Payload fields chính |
|-------|--------------|-----------------|----------------------|
| `OrderConfirmedEvent` | `Order.Confirm()` aggregate method | `Eureka.Modules.Orders/Domain/Entities/Order.cs:line` | OrderId, CustomerId, TotalAmount |
| `OrderCancelledEvent` | `Order.Cancel()` | `...:line` | OrderId, Reason |

---

## 2. Consumers / Subscribers

| Event | Consumer Module | Handler class | Side effect | Verify SQL/API |
|-------|----------------|----------------|--------------|------------------|
| `OrderConfirmedEvent` | Finance | `OrderConfirmedEventHandler` | Tạo Invoice với OrderId reference | `SELECT * FROM finance.invoices WHERE order_id = '{id}'` HOẶC `GET /api/v1/finance/invoices?orderId={id}` |
| `OrderConfirmedEvent` | TMS | `OrderConfirmedShipmentHandler` | Tạo Shipment | `GET /api/v1/tms/shipments?orderId={id}` |
| `OrderCancelledEvent` | WMS | `OrderCancelledRestoreInventoryHandler` | Restore inventory quantity | `SELECT quantity_available FROM wms.inventories WHERE product_id = ...` |

---

## 3. Cross-Module Data Dependencies

| Field ở Module A | Field ở Module B | Quan hệ | Consistency check |
|------------------|------------------|---------|---------------------|
| `Orders.Order.TotalAmount` | `Finance.Invoice.Amount` | A → B (event-driven) | A.TotalAmount == B.Amount |
| `Orders.Order.Status` | `TMS.Shipment` existence | Status=Confirmed → Shipment phải tồn tại | EXISTS check |
| `Orders.Order.Items[].Quantity` | `WMS.Inventory.QuantityAvailable` | Trừ khi confirm, hoàn khi cancel | Before/after delta |

---

## 4. Wait Strategy per Event

| Event | Strategy | Timeout | Verify method |
|-------|----------|---------|---------------|
| OrderConfirmedEvent → Invoice | Poll API mỗi 1s | 30s | `GET /api/v1/finance/invoices?orderId={id}` trả ≥1 record |
| OrderConfirmedEvent → Shipment | Poll API mỗi 1s | 30s | `GET /api/v1/tms/shipments?orderId={id}` |
| OrderCancelledEvent → InventoryRestore | Poll SQL mỗi 2s | 60s | quantity_available trở lại giá trị trước confirm |

---

## 5. Compensation / Saga

| Scenario | Step thất bại | Compensation cần xảy ra | Verify |
|----------|---------------|--------------------------|--------|
| Order confirmed → Invoice tạo OK → Shipment fail | Shipment | Rollback Invoice (mark Cancelled) HOẶC retry policy | `Finance.Invoice.Status` = Cancelled OR retry log exists |
| Order confirmed → Invoice fail | Invoice | Order phải revert về Draft | `Orders.Order.Status` = Draft |

---

## 6. Test Coverage Map

| Event Chain | Test case trong integration-test-report.md §7 | Status |
|-------------|-----------------------------------------------|--------|
| OrderConfirmed → Invoice + Shipment | §7.2 #1 | ⬜ Chưa test / ✅ PASS / ❌ FAIL |
| OrderCancelled → Inventory restore | §7.2 #2 | - |
| Compensation Order → Invoice fail rollback | §7.4 #1 | - |
