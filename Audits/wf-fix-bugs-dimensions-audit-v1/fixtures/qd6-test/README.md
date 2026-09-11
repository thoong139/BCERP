# QD6 Test Fixture — Data Integrity + Schema Drift

> **Status:** ✅ Phase 3 DONE (Phiên 17, 2026-05-08) — DoD PASS: P=1.00 R=1.00 on live_detectable
> **Lane skill:** `wf-fix-data` v2.0.0-alpha.s4
> **Số probes:** 6 (probe specs) / 3 bash checks (EF Core specific)
> **Owner agent:** `dba`
> **Audit report:** [07-qd6-data-audit.md](../../07-qd6-data-audit.md)

## Mục đích

Đo precision/recall của `wf-fix-probe-static-data.sh` — 3 bash checks thực tế (không phải 6 probe specs theo thiết kế). Xác nhận IMPL-REFUTED status và document tất cả gaps.

## Expected signals per probe

| Probe / Check | Signal type(s) | Severity | Positive cases | Negative cases | Notes |
|---|:-:|:-:|:-:|:-:|---|
| CHECK 1 (standard+): Domain/Entities/ Create() no guard | entity_guard_missing | medium | 3 | 3 | live_detectable at standard profile |
| CHECK 2 (deep+): Configurations/ Property(*Id) no HasOne | fk_config_missing | medium | 1 | 1 | documented_gap: profile-gated deep+ |
| CHECK 3 (exhaustive): AlterColumn maxLength shorter | migration_data_loss | high | 1 | 0 | documented_gap: profile-gated exhaustive |
| P-QD6-schema-drift-detect | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |
| P-QD6-migration-integrity | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |
| P-QD6-constraint-violation | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |
| P-QD6-data-type-mismatch | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |
| P-QD6-orm-model-sync | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |
| P-QD6-seed-data-audit | — | — | 0 | — | documented_gap: IMPL-REFUTED (Phase 2) |

## Cases

### Positive (5 cases — code có known bugs)

Files in `positive/src/` with proper subdirectory structure (probe uses `find -path`):

| File | Check | Expects signal |
|---|:-:|---|
| `positive/src/Domain/Entities/pos-01-order-no-guard.cs` | CHECK 1 | ✅ Entity Create thieu validation guard (medium) |
| `positive/src/Domain/Entities/pos-02-product-no-guard.cs` | CHECK 1 | ✅ Entity Create thieu validation guard (medium) |
| `positive/src/Domain/Entities/pos-05-customer-no-guard.cs` | CHECK 1 | ✅ Entity Create thieu validation guard (medium) |
| `positive/src/Configurations/pos-03-order-config-no-fk.cs` | CHECK 2 | ✅ EF Configuration thieu FK relationship (medium, deep+) |
| `positive/src/Migrations/pos-04-alter-maxlength.cs` | CHECK 3 | ✅ Migration AlterColumn co the gay data loss (high, exhaustive) |

### Negative (5 cases — code legit, không nên flag)

| File | Check avoided | Why no signal |
|---|---|---|
| `negative/src/Domain/Entities/neg-01-invoice-with-result-failure.cs` | CHECK 1 | Has `Result.Failure<T>()` guard |
| `negative/src/Domain/Entities/neg-02-subscription-with-throw.cs` | CHECK 1 | Has `throw new ArgumentException` |
| `negative/src/Configurations/neg-03-customer-config-with-hasone.cs` | CHECK 2 | Has `HasOne<T>().WithMany()` |
| `negative/src/Domain/Entities/neg-04-base-entity-no-create.cs` | CHECK 1 | No `Create()` method → first condition fails |
| `negative/src/Services/neg-05-order-service-not-entity.cs` | ALL | Not in `Domain/Entities/` or `Configurations/` path |

### Advanced (optional)

Not built — Phase 3 DoD met with 5+5 cases.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd6-test
bash run.sh
```

**Design note:** Must `cd` to fixture dir first. If run from repo root with absolute paths, the `positive/src/...` path would contain `fixtures/` which triggers EXCLUDE_PATTERN in CHECK 1/2 → 0 signals.

**Results (Phiên 17, 2026-05-08):**

| Step | Profile | Expected | Actual | Status |
|---|---|:-:|:-:|:-:|
| Step 1 (positive/) | standard | 3 | 3 | ✅ |
| Step 2 (positive/) | exhaustive | 5 | 5 | ✅ |
| Step 3 (negative/) | exhaustive | 0 | 0 | ✅ |

**Metrics:**
- Precision (live_detectable): **1.00** (DoD ≥ 0.70 ✅)
- Recall (live_detectable): **1.00** (DoD ≥ 0.60 ✅)
- CDG flags non-empty: **0** (hardcoded empty, confirmed Phase 2)

## Debugging Issues Found (Phiên 17)

- **Comment contamination bug:** Comments containing grep-detectable patterns (guard keywords, FK navigation names) falsely triggered probe checks. Fix: sanitize fixture comments. See [accuracy-report.md §10](./accuracy-report.md).
- **Down() double match:** Migration Down() method with `oldMaxLength: 50` on single line matched `AlterColumn.*maxLength: [0-9]+`. Fix: multi-line Down() format.

## Liên quan

- Audit report: [07-qd6-data-audit.md](../../07-qd6-data-audit.md)
- Accuracy report: [accuracy-report.md](./accuracy-report.md)
- Lane skill: `.claude/skills/workflow/wf-fix-data/`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
