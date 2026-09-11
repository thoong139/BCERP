# P-QD2-hardcoded-value-detect: Hard-Coded Business Value Detection

> **Probe ID:** P-QD2-hardcoded-value-detect
> **Type:** static
> **Depth:** standard, deep, exhaustive
> **Design ref:** P2.05

## Purpose

Grep hard-coded business values (tax rate, interest rate, fees, commissions) ma nen la config/env variables.

## Procedure

### SENSE
1. Scan `src/` hoac `apps/` cho business-critical hard-coded values:
   ```
   # Tax rates
   (tax_rate|vatRate|TAX_RATE|VAT_RATE|taxRate)\s*[=:]\s*[\d.]+
   # Interest rates
   (interest_rate|INTEREST_RATE|interestRate)\s*[=:]\s*[\d.]+
   # Fees & commissions
   (fee|FEE|commission_rate|COMMISSION_RATE|feeRate)\s*[=:]\s*[\d.]+
   # Currency amounts (thresholds)
   (MIN_AMOUNT|MAX_AMOUNT|threshold|THRESHOLD)\s*[=:]\s*[\d.]+
   # Percentage values
   (discount|DISCOUNT|penalty|PENALTY)\s*[=:]\s*[\d.]+
   ```
2. Wire Scan Cache: `cache_lookup` → HIT=reuse, MISS=scan

### THINK
1. Loc false positives:
   - Enum values (status codes, type constants)
   - Display constants (UI labels, formatting)
   - Test fixtures (files trong `__tests__/`, `test/`, `spec/`)
   - Default values trong config files (acceptable)
2. Phan loai theo business impact:
   - Tax/interest/fee rates → HIGH (affect money)
   - Thresholds/limits → MEDIUM (affect business rules)
   - Display values → LOW (skip, false positive)

### ACT
1. Emit Signals cho moi confirmed hard-coded business value
2. Severity mapping:
   - CRITICAL: hard-coded tax/interest rate trong production code
   - HIGH: hard-coded fee/commission trong service logic
   - MEDIUM: hard-coded threshold nen la config
3. Wire Scan Cache: `cache_store` cho MISS entries

### VERIFY
1. Moi Signal co `evidence.code_snippet` chua hard-coded value
2. Moi Signal co `target.path` va `target.line_range` chinh xac
3. False positive rate < 15% (manual check sample)

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json`
- Cache policy: **allowed** (static scan, results stable khi code khong doi)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No business logic files | Skip, note "no_business_logic_files" |
| All matches are false positives | Write empty signals, note "all_false_positives" |
| Scan Cache HIT | Reuse cached signals, skip re-scan |
