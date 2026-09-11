# BUG-CATALOG — Synthetic Benchmark Fixture

> Manifest 15 bugs intentional inject vào template/. Mỗi bug có expected detection mapping.
> Sau khi `/wf-fix-bugs --profile=exhaustive` chạy, dùng catalog này để verify detection rate.

---

## Distribution Summary

**Total: 20 unique bugs** (3 CRITICAL + 7 HIGH + 7 MEDIUM + 3 LOW)

| Severity | Count | IDs |
|----------|:-----:|-----|
| CRITICAL | 3 | BUG-S01, BUG-C01, BUG-F01 |
| HIGH | 7 | BUG-S02, BUG-S03, BUG-C02, BUG-C03, BUG-CR01, BUG-F02, BUG-P01 |
| MEDIUM | 7 | BUG-S04, BUG-C04, BUG-CR02, BUG-CR03, BUG-F03, BUG-F04, BUG-P02 |
| LOW | 3 | BUG-S05, BUG-C05, BUG-P03 |

| Source | Count | Notes |
|--------|:-----:|-------|
| static-scan | 13 | Lint, type, null check, deprecated, perf, security patterns |
| runtime | 0 | (v1 fixture chưa có — defer to v2) |
| llm-scan | 7 | Business rules, missing validations |

> **v1 fixture: chạy `--no-browser` flag.** Runtime bugs sẽ thêm trong v2.

---

## Bug Manifest (Per File)

### `src/sales/order.service.ts`

| Bug ID | Severity | Source | Dim | Line ~ | Description | Expected Fix |
|--------|----------|--------|-----|-------|-------------|--------------|
| BUG-S01 | CRITICAL | static-scan | QD1 | 30 | Null reference: `order.customer.taxRate` không null-guard | Add null check or default tax rate |
| BUG-S02 | HIGH | llm-scan | QD2 | 41 | Discount calc wrong: `total - discountPct` should be `total * (1 - pct/100)` | Fix calculation formula |
| BUG-S03 | HIGH | llm-scan | QD2, QD11 | 53 | Missing business rule: cancel allows non-PENDING orders | Add status check |
| BUG-S04 | MEDIUM | static-scan | QD1 | 61 | `price: any` should be `price: number` | Add proper type |
| BUG-S05 | LOW | static-scan | QD5 | 68 | Unused variable `random` | Remove unused decl |

### `src/crm/customer.service.ts`

| Bug ID | Severity | Source | Dim | Line ~ | Description | Expected Fix |
|--------|----------|--------|-----|-------|-------------|--------------|
| BUG-C01 | CRITICAL | static-scan | QD1 | 19 | Return type Customer but returns `undefined as any` | Throw or change return type |
| BUG-C02 | HIGH | static-scan | QD3 | 30 | SQL string concat pattern (injection vulnerability pattern) | Use parameterized query |
| BUG-C03 | HIGH | llm-scan | QD3 | 40 | Password stored plaintext in `passwordHash` | Use bcrypt rounds ≥12 |
| BUG-C04 | MEDIUM | static-scan | QD1 | 49 | `idOrEmail: any` — implicit any | Type as `string` |
| BUG-C05 | LOW | static-scan | QD5 | 58 | Empty stub function + leftover TODO | Implement or remove |

### `src/crm/lead.service.ts`

| Bug ID | Severity | Source | Dim | Line ~ | Description | Expected Fix |
|--------|----------|--------|-----|-------|-------------|--------------|
| BUG-CR01 | HIGH | llm-scan | QD10 | 31 | Cross-module: depends on BUG-C01 returning undefined | Handle null return from createCustomer |
| BUG-CR02 | MEDIUM | llm-scan | QD2, QD11 | 42 | Missing state machine validation (WON → NEW allowed) | Add transition rules |
| BUG-CR03 | MEDIUM | static-scan | QD4 | 52 | O(n²) nested loop with indexOf | Use Set or Map |

### `src/finance/invoice.service.ts`

| Bug ID | Severity | Source | Dim | Line ~ | Description | Expected Fix |
|--------|----------|--------|-----|-------|-------------|--------------|
| BUG-F01 | CRITICAL | static-scan | QD1 | 24 | Unsafe cast `as Order` bypasses null check | Proper guard, throw if null |
| BUG-F02 | HIGH | llm-scan | QD11 | 35 | VAT rate hardcoded, missing region parameter (business completeness) | Add region param + lookup table |
| BUG-F03 | MEDIUM | static-scan | QD1 | 42 | Function mutates input parameter | Return new object |
| BUG-F04 | MEDIUM | static-scan | QD4 | 50 | Inefficient `Array.from(values()).filter()` repeated | Cache result |

### `src/finance/payment.service.ts`

| Bug ID | Severity | Source | Dim | Line ~ | Description | Expected Fix |
|--------|----------|--------|-----|-------|-------------|--------------|
| BUG-P01 | HIGH | static-scan | QD3 | 21 | Sensitive data leak — card number logged plaintext | Mask card or remove log |
| BUG-P02 | MEDIUM | llm-scan | QD2 | 38 | Missing 30-day window check on refund | Add date comparison |
| BUG-P03 | LOW | static-scan | QD5 | 47 | Deprecated `Date.getYear()` | Use `getFullYear()` |

---

## Cross-Cutting Validation

After `/wf-fix-bugs --profile=exhaustive --scope=all --no-browser`:

```bash
SESSION=$(ls -t .mc-data/work/wf-fix-bugs/sessions/ | head -1)
REGISTRY=".mc-data/work/wf-fix-bugs/sessions/$SESSION/phase5-triage/issue-registry.json"

# Verify total count
EXPECTED=20
DETECTED=$(jq '.issues | length' "$REGISTRY")
echo "Detected: $DETECTED / $EXPECTED"

# Verify severity distribution
jq '[.issues[] | .severity] | group_by(.) | map({severity: .[0], count: length})' "$REGISTRY"

# Verify per-module
jq '[.issues[] | {module: .target.module, severity, source: .source}] | group_by(.module)' "$REGISTRY"
```

**Expected detection rate:**

| Detection Level | Threshold | Action if below |
|-----------------|-----------|----------------|
| ≥95% (≥19/20) | Excellent | Continue |
| ≥80% (≥16/20) | Acceptable | Note missed bugs, investigate |
| <80% | Concerning | Audit probe coverage |

**Known limitations (v1):**
- Runtime bugs (Playwright) NOT included — defer to v2
- E2E test scenarios NOT included — defer to v2
- Cross-app monorepo NOT tested — defer to v3
