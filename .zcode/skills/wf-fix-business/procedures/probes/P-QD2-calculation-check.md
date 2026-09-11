# P-QD2-calculation-check: Calculation Formula Cross-Reference

> **Probe ID:** P-QD2-calculation-check
> **Type:** static
> **Depth:** standard, deep, exhaustive
> **Design ref:** P2.02

## Purpose

Grep arithmetic patterns trong service/business logic files va cross-ref voi reference formulas.

## Procedure

### SENSE
1. Scan `src/` hoac `apps/` cho files matching pattern:
   - `**/service/**/*.{ts,js,py,java}`
   - `**/business/**/*.{ts,js,py,java}`
   - `**/calculation/**/*.{ts,js,py,java}`
   - `**/domain/**/*.{ts,js,py,java}`
2. Grep arithmetic patterns:
   ```
   (\*|\+|-|\/|%)\s*[\w.]+
   Math\.(floor|ceil|round|abs|max|min)\s*\(
   toFixed\s*\(
   BigDecimal|Decimal|currency
   ```
3. Wire Scan Cache: `cache_lookup` → HIT=reuse signals, MISS=scan

### THINK
1. Doc reference formulas tu `.claude/references/team-expert/{domain}/controls.md`
2. Map code formula → reference formula
3. Xac dinh discrepancies (sai cong thuc, sai hang, missing rounding)

### ACT
1. So sanh code formulas voi reference formulas
2. Flag discrepancies voi severity:
   - CRITICAL: sai so tien, sai interest rate, sai tax rate
   - HIGH: sai quy trinh tinh, missing edge case
   - MEDIUM: sai rounding rule, sai display format
3. Wire Scan Cache: `cache_store` cho MISS entries

### VERIFY
1. Moi Signal co `evidence.code_snippet` chua doan code formula
2. Moi Signal co `evidence.spec_ref` chua reference formula source
3. Loai bo false positives (test fixtures, mock data, display-only calculations)

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json`
- Cache policy: **allowed** (static scan, results stable khi code khong doi)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No reference formulas | Skip probe, note "no_reference_formulas" |
| No business logic files | Skip, note "no_business_logic_files" |
| Scan Cache HIT | Reuse cached signals, skip re-scan |
