# Stage M Prompt — Documentation Sync: Update Design Docs with Stage J/K/L Completion

## Context

Stage J hoàn tất (PASS). ISG + Partition Planner + v6 Orchestrator Wiring thành công (492 tests).
Stage K hoàn tất (PASS). Tất cả _contract.json files đồng bộ + `00-core.md §4b` path contract updated.
Stage L hoàn tất (PASS). Multi-workload integration tests validated (~507 tests).

### Trạng thái kiến trúc sau Stage L

```
_shared/                           ✅ COMPLETE — shared services layer + config
├── signal_bus/                    ✅ Signal Bus (emit, validate, dedup)
├── scan_cache/                    ✅ Scan Cache (fingerprint, TTL, QD3 never cached)
├── probe_executor.py              ✅ Probe execution (grep/agent/runtime → Signal v2)
├── lane_dispatch.py               ✅ Lane dispatch (cache integration, parallel)
├── signal_aggregator.py           ✅ Aggregation v2 (v2 schema fields populated)
├── dimension_registry.py          ✅ Dimension registry (metadata, cache policy)
├── profile_resolver.py            ✅ Profile → probe + dimension resolver
├── report_generator.py            ✅ Lane + coverage report generation từ templates
├── partition_planner.py           ✅ Partition dimensions → workloads (ISG-guided + priority-based)
├── read_trace.py                  ✅ Code tracing
├── isg/                           ✅ ISG recommender (core logic)
├── impact_graph/                  ✅ Impact graph builder
├── workload_estimator/            ✅ Workload estimation (core logic)
├── concurrency/                   ✅ Backpressure + token bucket
├── profiles.json                  ✅ Profile config (ADR-21 locked defaults)
├── templates/                     ✅ 3 v6 output templates (CORE-031)
└── tests/                         ✅ ~507 tests (463 base + 17 Stage I + 12 Stage J + ~15 Stage L)

wf-fix-functional/                 ✅ QD1 — dimension.json + 7 probe .md files
wf-fix-business/                   ✅ QD2 — dimension.json + 5 probe .md files
wf-fix-security/                   ✅ QD3 — dimension.json + 7 probe .md files
wf-fix-performance/                ✅ QD4 — dimension.json + 6 probe .md files
wf-fix-ux-a11y/                    ✅ QD5 — dimension.json + 7 probe .md files
wf-fix-data/                       ✅ QD6 — dimension.json + 6 probe .md files
wf-fix-compat/                     ✅ QD7 — dimension.json + 5 probe .md files

wf-fix-bugs/                       ✅ Orchestrator v6 flow (resolve → ISG → partition → dispatch)
wf-fix-discover/                   ✅ v6 mode dispatch + report generation
wf-fix-triage/                     ✅ v6 mode + v2 schema documented
wf-fix-execute/                    ✅ v6 mode for verify + report documented

Contracts:                         ✅ All _contract.json synced (Stage K)
00-core.md §4b:                    ✅ Path contract updated (Stage K)
```

### What's Missing (Gap Analysis)

Tất cả code, tests, và contracts hoàn tất. Stage M cập nhật **design documentation** để phản ánh
trạng thái thực tế sau khi tất cả implementation stages (A-L) hoàn tất:

```
GAPS:
1. README.md — cần update §11 Status & Next Actions với Stage J/K/L completion
2. 03-architecture.md — cần update component list với partition_planner.py
3. 04-contracts-data-model.md — cần update v2 AggregationStats schema fields
4. 06-migration-plan.md — cần update phase completion status
5. 07-tradeoffs-adr.md — cần thêm ADR entries cho Stage J decisions (ISG-guided partition, v2 schema)
```

---

## Stage M: Documentation Sync

### Mục tiêu

Cập nhật tất cả design docs để phản ánh implementation hoàn tất qua Stages A-L:

1. Update README.md status section
2. Update 03-architecture.md component map
3. Update 04-contracts-data-model.md v2 schema
4. Update 06-migration-plan.md phase progress
5. Update 07-tradeoffs-adr.md với Stage J ADRs

### Key Constraints

1. **Chỉ update docs** — KHÔNG thay đổi code, tests, hay contracts
2. **CORE-005**: Tài liệu tiếng Việt, technical terms giữ English
3. **Accuracy**: Mọi claim trong docs phải match actual code state
4. **No fantasy docs**: Chỉ ghi nhận những gì đã implement + test pass
5. **Cross-reference**: ADR IDs, file paths, function names phải chính xác

---

## Tasks

### M1: Update README.md §11 Status & Next Actions (CRITICAL)

File: `docs/design/skills/wf-fix-bugs/README.md`

Update §11 (hoặc section tương tự) để phản ánh:

**Implementation status:**
- Phase 0 (Design): ✅ COMPLETE
- Phase 1 (Skeleton + Dim Registry): ✅ COMPLETE (Stages A-C)
- Phase 2 (Bellweather Lanes QD1+QD2): ✅ COMPLETE (Stages D-E)
- Phase 3 (Remaining Lanes QD3-QD7): ✅ COMPLETE (Stages F-G)
- Phase 4 (Shared Services v6): ✅ COMPLETE (Stages H-L)
  - Stage H: Profile config + templates + SKILL.md wiring
  - Stage I: E2E validation + triage/execute v6 wiring
  - Stage J: ISG integration + partition planner + discover v6 dispatch
  - Stage K: Contract sync + path contract
  - Stage L: Multi-workload integration tests
- Phase 5 (Cutover + Deprecation): 🔲 PENDING — `--engine=v5` still default
- Phase 6 (v5 Removal): 🔲 PENDING

**Test status:**
- ~507 tests, 0 failures (after Stage L)
- E2E coverage: full v6 pipeline from profiles → ISG → partition → dispatch → aggregate → reports

**Next actions:**
- Phase 5: Change default engine from v5 → v6 (breaking change, cần user communication)
- Phase 6: Remove v5 code paths after grace period

### M2: Update 03-architecture.md component map (HIGH)

File: `docs/design/skills/wf-fix-bugs/03-architecture.md`

Trong section components, thêm:
- `partition_planner.py` — Partition dimensions → workloads (ADR-14, ADR-15)
- `isg/` — ISG recommender module (ADR-14)
- Update data flow diagram nếu cần để show resolve_dimensions → ISG → partition → dispatch sequence

### M3: Update 04-contracts-data-model.md v2 schema (HIGH)

File: `docs/design/skills/wf-fix-bugs/04-contracts-data-model.md`

Update AggregationStats schema để include v2 fields:

```json
{
  "AggregationStats": {
    "total_signals": "int — tổng signals trước dedup",
    "total_issues": "int — issues sau dedup",
    "by_dimension": "dict[str, int] — issues per dimension",
    "errors": "list[str] — aggregation errors",
    "dimensions_run": "list[str] — (v2) dimensions đã chạy",
    "dimensions_with_issues": "list[str] — (v2) dimensions có issues",
    "dimensions_without_issues": "list[str] — (v2) dimensions không có issues",
    "coverage_rate_pct": "float — (v2) % dimensions có issues",
    "dedup_ingested": "int — (v2) signals ingested vào bus",
    "dedup_deduplicated": "int — (v2) signals removed by dedup"
  }
}
```

Thêm WorkloadPlan schema:
```json
{
  "WorkloadPlan": {
    "id": "str — workload ID (W01, W02, ...)",
    "dimensions": "list[str] — dimension IDs trong workload",
    "estimated_probes": "int — tổng probes estimate",
    "estimated_minutes": "float — thời gian estimate (minutes)"
  }
}
```

### M4: Update 06-migration-plan.md phase progress (MEDIUM)

File: `docs/design/skills/wf-fix-bugs/06-migration-plan.md`

Update checkboxes/status cho từng phase:
- Phase 1 deliverables: ✅ tất cả complete
- Phase 2 deliverables: ✅ tất cả complete (QD1+QD2 bellweather + expanding to QD3-QD7)
- Phase 3 deliverables: ✅ tất cả complete
- Phase 4 deliverables: ✅ tất cả complete
- Phase 5: 🔲 PENDING — cutover checklist
- Phase 6: 🔲 PENDING — v5 removal

Thêm note về Stage J/K/L completion trong timeline.

### M5: Update 07-tradeoffs-adr.md with Stage J ADRs (MEDIUM)

File: `docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md`

Thêm ADR entries (nếu chưa có):

**ADR-23 — Partition Planner: ISG-guided vs default priority split**
- Status: accepted
- Context: Khi dimensions vượt max_workload_size, cần strategy chia workloads
- Decision: Ưu tiên ISG recommendation khi có, fallback sang priority-based (core dims QD1+QD2+QD5 trước)
- Consequences: ISG-aware partition cho kết quả tốt hơn cho specific domains, default strategy đảm bảo always-working fallback

**ADR-24 — AggregationStats v2 schema: dimension-level coverage fields**
- Status: accepted
- Context: Cần track dimension-level coverage để generate meaningful coverage-report
- Decision: Thêm 6 fields vào AggregationStats (dimensions_run, dimensions_with/without_issues, coverage_rate_pct, dedup_ingested, dedup_deduplicated)
- Consequences: Reports có coverage metrics, nhưng stats object lớn hơn

---

## File Summary

### Files to MODIFY

| File | Thay đổi |
|------|----------|
| `docs/design/skills/wf-fix-bugs/README.md` | Update §11 status + next actions |
| `docs/design/skills/wf-fix-bugs/03-architecture.md` | Add partition_planner to component map |
| `docs/design/skills/wf-fix-bugs/04-contracts-data-model.md` | Add v2 AggregationStats + WorkloadPlan schemas |
| `docs/design/skills/wf-fix-bugs/06-migration-plan.md` | Update phase completion checkboxes |
| `docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md` | Add ADR-23, ADR-24 |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| Tất cả `.py` files | Stage M chỉ update docs |
| `_contract.json` files | Stage K đã sync |
| `00-core.md` | Stage K đã update |
| `SKILL.md` files | Stage J đã update |
| `_shared/tests/` | Stage L đã thêm |
| `_shared/templates/` | Stage H tạo, stable |

---

## Success Criteria

1. ✅ README.md §11 phản ánh đúng implementation status (Phase 0-4 complete)
2. ✅ 03-architecture.md có partition_planner.py trong component map
3. ✅ 04-contracts-data-model.md có v2 AggregationStats + WorkloadPlan schemas
4. ✅ 06-migration-plan.md phase checkboxes updated
5. ✅ 07-tradeoffs-adr.md có ADR-23 + ADR-24
6. ✅ Không có code, test hay contract files bị thay đổi
7. ✅ Mọi path reference, function name, ADR ID trong docs chính xác với code thực tế
