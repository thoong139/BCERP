---
name: wf-e2e-batch
description: Batch E2E test N FEATs với dependency graph và topology dispatch. Dispatch wf-e2e-verify × N FEATs theo topology sort.
argument-hint: "[--scope=<module>] [--feats=<ID1,ID2,...>] [--max-parallel=<N>] [--dry-run] [--auto] [--no-seed] [--resume] [--status]"
---
/wf-e2e-batch $ARGUMENTS
