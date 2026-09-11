# Phase 2.5: Generate Implementation Contracts

> **Điều kiện load:** Chỉ load file này khi `$PARALLEL_MODE == true` (flag `--parallel`).
> SKIP trong sequential mode (single feature, default).
>
> **Mục đích:** Contract-first approach ngăn dev agents conflict, đảm bảo mọi agents dùng chung types, interfaces, DTOs. Contracts là IMMUTABLE trong session.
>
> **Agent:** `architect` — xem context template tại `_shared.md §Agent Context: Architect (Contracts)`.

**PRE-GATE:** `test "$PARALLEL_MODE" = "true"`

**📥 INPUT:**
- Feature design
- `impl-plan.md`
- Phase 3 architecture docs (api-contract.md, database-design.md)

**📤 OUTPUT:**

| File | Mục đích |
|------|----------|
| `src/shared/types.ts` | Shared types, enums, constants |
| `src/interfaces/*.ts` | Service interfaces, repository contracts |
| `src/dtos/*.ts` | Request/response DTOs với validation decorators |
| `src/database/migrations/[timestamp]-[feature].sql` | DB schema (nếu cần) |
| `$SESSION_DIR/contracts.json` | Contract manifest |

---

## Contracts Manifest Format (contracts.json)

```json
{
  "generated_at": "ISO-8601 timestamp",
  "feature": "FEAT-CRM-CUST-001",
  "contracts": {
    "shared_types": [{"file": "src/shared/types.ts", "exports": ["CustomerEntity"], "immutable": true}],
    "interfaces": [{"file": "src/interfaces/customer.service.ts", "exports": ["ICustomerService"], "immutable": true}],
    "dtos": [{"file": "src/dtos/customer.dto.ts", "exports": ["CreateCustomerDTO"], "immutable": true}],
    "database": [{"file": "src/database/migrations/[ts]-create_customer.sql", "immutable": true}]
  },
  "contract_rules": {
    "dev_agent_write_scope": {
      "entity_agent": ["src/entities/**/*.ts"],
      "repository_agent": ["src/repositories/**/*.ts"],
      "service_agent": ["src/services/**/*.ts"],
      "controller_agent": ["src/controllers/**/*.ts"],
      "test_agent": ["src/**/*.test.ts"]
    },
    "forbidden_write_scope": ["src/shared/**", "src/interfaces/**", "src/dtos/**", "src/database/migrations/**"],
    "escalation_trigger": "Nếu agent cần sửa contract → STOP + log 'CONTRACT_MODIFICATION_ATTEMPT' + escalate to architect"
  }
}
```

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.5.1 | Spawn `architect` agent với context từ `_shared.md §Agent Context: Architect (Contracts)` | Agent success |
| 2.5.2 | Architect tạo 4 loại file (types, interfaces, DTOs, migrations) từ feature spec + Phase 3 API contract | Files exist |
| 2.5.3 | Architect commit contracts (nếu git available) hoặc ghi `CONTRACTS_COMMITTED = true` | Contracts immutable |
| 2.5.4 | Generate `contracts.json` manifest — list tất cả contracts + forbid rules + agent write scopes | `test -s contracts.json` |
| 2.5.5 | **Contract Validation:** Validate mỗi interface có matching exports trong types + DTOs. Validate DB schema vs entities. | Validation pass |

---

**POST-GATE:** Contracts created, immutable flag set, `contracts.json` valid (JSON parse OK, all 4 sections có entries).

---

## Output State Variables

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$CONTRACTS_MANIFEST` | Path to contracts.json | phase3 (3.0.F file pre-check + waves) |
| `$CONTRACTS_COMMITTED` | true/false | phase3 (R2 enforcement) |
| `$FORBIDDEN_WRITE_SCOPE` | Array of glob patterns | phase3 (R1 isolation) |
