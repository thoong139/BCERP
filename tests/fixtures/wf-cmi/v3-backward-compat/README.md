# Fixture: `v3-backward-compat/` — TC-cmi-014

> **Mục đích:** Smoke test v2 backward-compat khi user chạy `/wf-cmi --profile=standard` (KHÔNG có `--exec-scenarios` flag). Pipeline 8 phases hoàn tất bình thường, integrity-impact.json ghi `$schema=integrity-impact-v3` nhưng `e2e_execution_summary=null` và `scenarios_artifacts=[]`. v1+v2 fields preserved 100%.

---

## Cấu trúc

```
v3-backward-compat/
├── README.md                          ← Bạn đang đọc
├── apps/backend/Eureka.Modules.CRM/Domain/Entities/
│   └── Customer.cs                    ← REQ-CRM-CUST-001 (entity stub)
└── .mc-data/
    └── docs/
        └── _meta/req-registry.json    ← 1 REQ minimal valid
```

## Expected behavior

| Phase | Behavior |
|-------|----------|
| 1 (Init) | Parse args → `v3_flags.exec_scenarios=false`. Phase 9-10 SKIP marker set. |
| 4 (Dispatch) | CD41 lane skip (profile=standard, deep+exhaustive only). |
| 8 (Report) | integrity-impact.json $schema=v3, e2e_execution_summary=null, scenarios_artifacts=[]. integrity-report.md ≤55 dòng (v2 base, NO E2E section). |
| 9 (E2E Execute) | **SKIP** — NO Phase9-report.md created. |
| 10 (E2E Resolution) | **SKIP** — NO Phase10-report.md created. |

## Pass criteria

1. Exit code 0
2. integrity-status.json.phases_completed=[1,2,3,4,5,6,7,8]
3. integrity-impact.json: $schema='integrity-impact-v3', e2e_execution_summary=null, scenarios_artifacts=[]
4. schema_version_compat.readable_by=[v1,v2,v3]
5. Mock v1 consumer: jq access all v1 fields → no null/error
6. Mock v2 consumer: jq access all v2 fields → no null/error
7. integrity-report.md grep '## 3.5. E2E Execution Summary' → 0 matches

## Run

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-014
```
