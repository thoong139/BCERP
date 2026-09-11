# Master Plan Section Template

> Template cho Phase 4 khi `$MASTER_PLAN_STATUS` populated. Render sau main summary.

```markdown
### Master Plan Components Status

| Component | Status | Evidence |
|-----------|--------|----------|
| Schema Sync (validate-schema-sync.sh) | $SCHEMA_PASSED/$SCHEMA_TOTAL pass | $SCHEMA_DETAILS |
| Hook 2-Tầng | $COMP1_STATUS | $COMP1_EVIDENCE |
| Baseline Metrics | $COMP2_STATUS | $COMP2_EVIDENCE |
| Context Digest | $COMP3_STATUS | $COMP3_EVIDENCE |
| Digest Pipeline (6 templates) | $COMP4_N/6 present | $COMP4_EVIDENCE |
| A6-EXT | $COMP5_STATUS | $COMP5_EVIDENCE |
| A7-EXT | $COMP6_STATUS | $COMP6_EVIDENCE |
| Parallel (Phase 2.5) | $COMP7_STATUS | $COMP7_EVIDENCE |
| --features flag | $COMP8_STATUS | $COMP8_EVIDENCE |
| Layer Gate Reports | $GATE_N/3 found | L1: $L1_VERDICT, L2: $L2_VERDICT, L3: $L3_VERDICT |
| Backward Compatibility | $BC_STATUS | contracts: $BC_CONTRACTS, --parallel default: $BC_PARALLEL, --features optional: $BC_FEATURES |

**Master Plan Verdict: $MP_VERDICT**
```

## Placeholders

| Placeholder | Source |
|-------------|--------|
| `$SCHEMA_PASSED`, `$SCHEMA_TOTAL`, `$SCHEMA_DETAILS` | `$MASTER_PLAN_STATUS.schema_sync` |
| `$COMP1..8_STATUS`, `$COMP1..8_EVIDENCE` | `$MASTER_PLAN_STATUS.components[]` |
| `$GATE_N`, `$L1_VERDICT`, `$L2_VERDICT`, `$L3_VERDICT` | `$MASTER_PLAN_STATUS.gate_reports` |
| `$BC_STATUS`, `$BC_CONTRACTS`, `$BC_PARALLEL`, `$BC_FEATURES` | `$MASTER_PLAN_STATUS.backward_compat` |
| `$MP_VERDICT` | `$MASTER_PLAN_STATUS.verdict` ∈ {`MP-CLEAN`, `MP-ACCEPTABLE`, `MP-NEEDS-ATTENTION`, `MP-INCOMPLETE`} |

## Khi nào render

- Pipeline có `master-plan` stage: `--full`, `--no-fix`, hoặc `--master-plan`
- KHÔNG render khi `--scan-only`, `--quick`, hoặc `--fix-only` (không chạy Master Plan)
