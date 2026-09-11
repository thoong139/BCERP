---
$schema: parity-check-v1
migrate_id: {MIGRATE_ID}
feature_id: {FEATURE_ID}
feature_name: {FEATURE_NAME}
strategy: {Keep | Redesign | Merge}
---

# Parity Check — {FEATURE_NAME}

## He thong cu

| Muc | Gia tri |
|-----|---------|
| API endpoints | {old_api_endpoints} |
| Response shape | `{old_response_shape_summary}` |
| Business rules | {old_business_rules} |
| Entities | {old_entities} |
| Edge cases | {old_edge_cases} |

## He thong moi (EUREKA)

| Muc | Gia tri |
|-----|---------|
| API endpoints | {new_api_endpoints} |
| Response shape | `{new_response_shape_summary}` |
| Business rules | {new_business_rules} |
| Entities | {new_entities} |
| Edge cases | {new_edge_cases_handled} |

## Ket qua so sanh

| Hang muc | Trang thai | Chi tiet sai lech |
|----------|-----------|--------------------|
| API endpoints | PASS / PARTIAL / FAIL | {ket qua so endpoint cu vs moi} |
| Response shape | PASS / PARTIAL / FAIL | {field nao thieu, field nao khac type} |
| Business rules | PASS / PARTIAL / FAIL | {rule nao thieu hoac khac logic} |
| Entity mapping | PASS / PARTIAL / FAIL | {entity nao thieu field, field nao map sai} |
| Edge cases | PASS / PARTIAL / FAIL | {edge case nao chua xu ly} |

## Tong ket

| Chi tieu | Gia tri |
|----------|---------|
| Tong hang muc | {total_items} |
| PASS | {pass_count} |
| PARTIAL | {partial_count} |
| FAIL | {fail_count} |

## Hanh dong can thiet

<!-- POPULATE: Neu co FAIL hoac PARTIAL > 3 → hanh dong cu the -->
{action_items}
