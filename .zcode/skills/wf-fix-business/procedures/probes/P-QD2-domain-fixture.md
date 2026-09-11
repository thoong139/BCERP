# P-QD2-domain-fixture: Domain-Specific Test Fixture Runner

> **Probe ID:** P-QD2-domain-fixture
> **Type:** runtime+fixture
> **Depth:** deep, exhaustive
> **Design ref:** P2.03

## Purpose

Chay domain-specific test fixtures de verify business logic correctness voi real test data.

## Procedure

### SENSE
1. Tim fixture files trong project:
   - `**/fixtures/**/*.{json,yaml,yml}`
   - `**/test-data/**/*.{json,yaml,yml}`
   - `**/__tests__/fixtures/**`
2. Loc domain-specific fixtures (co chua business data: invoices, orders, payroll, etc.)
3. Tim test runner config (jest, pytest, vitest, etc.)

### THINK
1. Phan loai fixtures theo domain (finance, HR, logistics, etc.)
2. Xac dinh expected results per fixture
3. Map fixtures → API endpoints hoac service methods

### ACT
1. Chay fixtures qua test runner hoac API calls
2. Compare actual results vs expected results
3. Flag discrepancies:
   - CRITICAL: calculation error (sai ket qua tinh toan)
   - HIGH: flow error (missing step, wrong sequence)
   - MEDIUM: format error (sai display format)

### VERIFY
1. Moi failed fixture co Signal voi `evidence.log_excerpt`
2. Fixture success/failure ratio documented trong lane-report

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json`
- Cache policy: **skip** (runtime probe, results thay doi theo code)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No fixtures found | Skip probe, note "no_domain_fixtures" |
| Test runner not available | Skip probe, note "no_test_runner" |
| Fixture parse error | Log WARNING, skip fixture, continue others |
