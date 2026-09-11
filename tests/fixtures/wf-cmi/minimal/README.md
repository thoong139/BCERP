# Fixture: `minimal/` — TC-cmi-001 Smoke

> **Mục đích:** Smoke test với 1 module CRM, 3 entity stubs, 5 REQs. Pipeline phải hoàn tất trong <5 min với `--profile=quick`.

---

## Cấu trúc

```
minimal/
├── README.md                              ← Bạn đang đọc
├── apps/backend/Eureka.Modules.CRM/
│   ├── Domain/Entities/
│   │   ├── Customer.cs                    ← REQ-CRM-CUST-001 (entity chính)
│   │   ├── Contact.cs                     ← REQ-CRM-CUST-002 (1:N child)
│   │   └── SalesOwner.cs                  ← REQ-CRM-CUST-003 (FK reference)
│   ├── Application/Commands/
│   │   └── CreateCustomerCommand.cs       ← REQ-CRM-CUST-001
│   └── Infrastructure/Persistence/Configurations/
│       └── CustomerConfiguration.cs       ← REQ-CRM-CUST-004 (EF Core mapping)
└── .mc-data/
    └── docs/
        ├── _meta/req-registry.json        ← 5 REQs (CORE-009 schema valid)
        ├── phase1-business/01-business-overview.md
        ├── phase2-features/crm/customer-mgmt/FEAT-CRM-CUST-001.md
        └── phase3-architecture/04-architecture-overview.md
```

## Run

```bash
cd tests/fixtures/wf-cmi/minimal
/wf-cmi --scope=module=crm --profile=quick
```

## Expected behavior

- Phase 1 Init: profile=quick → activate 5 lanes (CD1, CD2, CD3, CD4, CD7)
- Phase 2 Discovery: 5 graphs built (entity/module/workflow/api/rbac), event-graph SKIPPED (CD5 not active in quick)
- Phase 3 Invariant Artifact: 3-pass LLM phát hiện 1-3 invariants cơ bản (Customer entity validation, SalesOwner FK existence)
- Phase 4 Coverage Dispatch: 5 lanes parallel max 3 min/lane
- Phase 5 Aggregate: coverage threshold=60% (quick profile) — phải PASS với fixture này
- Phase 6 Regression: SKIPPED (không có `--since`)
- Phase 7 GAP + CDG: minimal GAPs, bypass CDG nếu không có suggestion CRITICAL
- Phase 8 Report: `integrity-report.md` ≤30 dòng tiếng Việt + `integrity-impact.json` schema valid

## Pass criteria

- Exit code 0
- Tất cả 7 POST-GATE T1-T4 PASS
- `coverage-matrix.json` overall_pct ≥60
- Time <5 min
- Context budget <50%

## Cross-module dependencies (test discovery)

- `Customer.SalesOwnerId` → `SalesOwner.Id` (intra-module — phải phát hiện)
- `Contact.CustomerId` → `Customer.Id` (intra-module — phải phát hiện)

Không có cross-module dep thực sự ở minimal (chỉ 1 module CRM) → entity-graph có 3 nodes + 2 edges.

## Liên kết

- Eval definition: [`.claude/skills/workflow/wf-cmi/evals/evals.json`](../../../../.claude/skills/workflow/wf-cmi/evals/evals.json) §TC-cmi-001
- Design canon: [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md) §2.TC-cmi-001
