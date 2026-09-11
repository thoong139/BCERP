# Fixture: `realistic/` — TC-cmi-002, TC-cmi-004

> **Mục đích:** Integration test với 3 modules (CRM, Orders, Finance) + cross-module FK + 30+ REQs. Đủ phức tạp để test 7 lanes parallel (profile=standard, 15-30 min).

---

## Cấu trúc

```
realistic/
├── README.md                                            ← Bạn đang đọc
├── apps/backend/
│   ├── Eureka.Modules.CRM/Domain/Entities/
│   │   ├── Customer.cs                                  ← REQ-CRM-CUST-001
│   │   └── SalesOwner.cs                                ← REQ-CRM-CUST-003
│   ├── Eureka.Modules.Orders/Domain/Entities/
│   │   ├── Order.cs                                     ← REQ-ORD-ORD-001 (FK: CustomerId → CRM.Customer.Id)
│   │   ├── OrderLine.cs                                 ← REQ-ORD-ORD-002
│   │   └── Quotation.cs                                 ← REQ-ORD-QUO-001
│   └── Eureka.Modules.Finance/Domain/Entities/
│       ├── Invoice.cs                                   ← REQ-FIN-INV-001 (FK: OrderId → Orders.Order.Id)
│       └── JournalEntry.cs                              ← REQ-FIN-JNL-001
└── .mc-data/
    └── docs/
        ├── _meta/req-registry.json                      ← ~25 REQs across 3 modules
        ├── phase1-business/01-business-overview.md
        ├── phase2-features/{crm,orders,finance}/...     ← 3 feature spec files
        └── phase3-architecture/04-architecture-overview.md
```

## Cross-module dependencies (key invariants)

| Source | Target | Type | Business rule |
|--------|--------|------|---------------|
| `Orders.Order.CustomerId` | `CRM.Customer.Id` | FK | Order phải gắn với customer hợp lệ |
| `Orders.Order.QuotationId` | `Orders.Quotation.Id` | FK (intra) | Optional — order từ quotation |
| `Finance.Invoice.OrderId` | `Orders.Order.Id` | FK | Invoice phải gắn với order hợp lệ |
| `Finance.Invoice.CustomerId` | `CRM.Customer.Id` | FK (denormalized) | Cùng customer như Order |
| `Finance.JournalEntry.InvoiceId` | `Finance.Invoice.Id` | FK (intra) | Mỗi invoice trigger 1 journal entry |

## Run

### TC-cmi-002 Integration

```bash
cd tests/fixtures/wf-cmi/realistic
/wf-cmi --profile=standard
```

**Expected:** 7 lanes active (CD1-CD6, CD9), business-invariants.json ≥10 entries, coverage ≥80%, integrity-impact.json schema valid.

### TC-cmi-004 Resume

```bash
cd tests/fixtures/wf-cmi/realistic
/wf-cmi --profile=standard &
PID=$!
sleep 60  # Vào Phase 4
kill -INT $PID
/wf-cmi --resume
```

**Expected:** Detect Phase 4 partial state, skip 6 PASS lanes, re-spawn 3 pending, continue Phase 5-8.

## Pass criteria

- `business-invariants.json` có ≥10 invariants cross-module
- `coverage-matrix.json` overall_pct ≥80%
- `integrity-impact.json` $schema=`integrity-impact-v1` + 4 consumers
- Phase reports ≤15 dòng tiếng Việt
- Time 15-30 min (TC-002), <10 min resume continuation (TC-004)
