# wf-legacy-scan v5.0.0 — Release Notes

**Ngày phát hành:** 2026-04-22
**Tương thích ngược:** Có — `standard` profile = v4.1 behaviour
**Branch:** `feat/wf-legacy-scan-v5.0-phase-j`
**Tag:** `v5.0.0`
**Tác giả:** DEVKIT core team

---

## Điểm nổi bật

wf-legacy-scan v5.0 là bản nâng cấp lớn nhất kể từ v4.1. Skill được thiết kế lại hoàn toàn với
kiến trúc pipeline 6 layers, session isolation, intelligent profile selection (IPS), và cơ sở hạ
tầng enterprise-grade cho các dự án legacy phức tạp.

### Tính năng mới

| Tính năng | Mô tả |
|-----------|-------|
| **4 Execution Profiles** | `surface` / `standard` / `deep` / `exhaustive` — kiểm soát độ sâu phân tích theo quy mô và timeline |
| **IPS 2-Phase Domain Detection** | Intelligent Profile Selection: IPS-A (project metrics → profile) + IPS-B (domain keywords EN+VN → agent routing) |
| **Session Isolation** | Mỗi lần chạy tạo session riêng — không overwrite scan cũ, hỗ trợ multi-session compare |
| **4-Level Checkpoint** | L0 (phase) / L1 (layer) / L2 (batch) / L3 (intra-batch) — resume chính xác sau crash hoặc timeout |
| **Concurrency Controller** | 3-tier token bucket (global/per_layer/per_probe) — ngăn context overload |
| **Per-Agent Timeout + Watchdog** | Timeout 300s (standard) / 600s (deep+exhaustive), max 2 retry, auto-skip |
| **Scan Cache** | Content-addressable fingerprint, 2-tier (session + project), privacy guard (secret/PII block) |
| **Incremental Re-scan** | `--incremental` + `--since=<git-ref>` — chỉ re-process files thay đổi, tiết kiệm 60-70% runtime |
| **Workload Gate** | Detect large+deep combo → WARN + 3 options (continue/downgrade/abort) |
| **Impact Graph** | `impact-graph.json` tại L6 — 6 relation types, Tarjan SCC circular detection, downstream ripple support |
| **Domain-Aware Agent Routing** | L4/L5 tự động spawn `business-analyst` + domain expert dựa trên IPS-B confidence |
| **Vietnamese Keyword Pool** | 14 domains × 159+ keywords + abbreviations tiếng Việt cho IPS domain detection |
| **4-Level Resume Router** | Phân tích scan-state.json → tìm đúng checkpoint để resume (16 action types) |
| **Bash Shared Library** | `legacy-scan-common.sh` — 31 functions tái sử dụng, 9 UI helpers, atomic JSON writes |

---

## Breaking Changes

**Không có** cho default usage.

Chạy `/wf-legacy-scan` không flag hoạt động như v4.1 (`standard` profile = v4.1 behaviour — ADR-LS02).

### Thay đổi nội bộ (chỉ ảnh hưởng direct sub-skill users)

Nếu bạn gọi `/wf-legacy-classify` hoặc `/wf-legacy-extract` **trực tiếp** (không qua `/wf-legacy-scan`):

- Cả hai sub-skills giờ đọc **`scan-state.json`** (v5.0 canonical) ưu tiên hơn `ledger.json` (v4.1 fallback).
- Nếu chưa có `scan-state.json`, sub-skills tự động fallback về `ledger.json` — không block.
- **Khuyến nghị:** Chạy migration helper một lần: `.claude/scripts/migrate-legacy-scan-v4-to-v5.sh`

---

## Migration Guide

### Người dùng thông thường (dùng qua Claude)

**Không cần làm gì.** Chạy `/wf-legacy-scan` bình thường — v5.0 tự động xử lý.

```
/wf-legacy-scan /path/to/project
```

Muốn thử profile sâu hơn:

```
/wf-legacy-scan /path/to/project --profile=deep
```

### Người dùng gọi sub-skills trực tiếp

1. Chạy migration helper (một lần):
   ```bash
   ./.claude/scripts/migrate-legacy-scan-v4-to-v5.sh /path/to/project
   ```
2. Kiểm tra: `/wf-legacy-scan --status`
3. Tiếp tục bình thường.

---

## Hiệu năng

Đo trên test fixtures (Tier 1 synthetic — Tier 2 E2E pending fixtures A.3):

| Metric | v4.1 | v5.0 standard | v5.0 incremental |
|--------|------|---------------|-----------------|
| Standard profile 500 files | baseline | ~20-40% nhanh hơn | ≤30% baseline |
| Deep extraction confidence | ~0.65 | ≥0.82 | ≥0.82 |
| Re-scan 20% changes | 100% | 100% | ≤30% |
| Cache hit rate (2nd run) | 0% | ≥60% | ≥80% |
| Crash recovery (mất dữ liệu) | toàn bộ run | ≤1 batch | ≤1 intra-batch item |

---

## Test Coverage

| Test Suite | Kết quả |
|------------|---------|
| IPS Python suite | **410/410 PASS** |
| E2E Tier 1 (4 profiles × 3 fixtures mock) | **12/12 PASS** |
| Crash injection (kill -9, 4 levels) | **8/8 PASS** |
| Resume router unit tests | **36/36 PASS** |
| Resume router Tier 1 flow tests | **13/13 PASS** |
| Downstream integration Tier 1 | **9/9 PASS** |
| Compliance audit (3 skills) | **3/3 PASS** |
| Calibration Tier 1 (4 thresholds) | **4/4 PASS** |
| Phase H backward-compat | **23/23 PASS** |
| Regression suite | **10/11 PASS** (1 SKIP — A.3 fixtures pending) |

---

## Chi tiết theo Phase Implementation

### Phase B — Foundation
- Bash shared library `legacy-scan-common.sh` (31 functions)
- Session infrastructure + file locking
- `scan_state_reader.py` (12 API functions)
- `ledger.json` backward-compat projection

### Phase C — Profiles + IPS + VN
- Profile resolver (`phase0b-profile.md`)
- IPS-A recommendation engine
- Vietnamese keyword pool (14 domains × 159+ entries)
- `domain_scorer.py`, `ips_recommender.py`

### Phase D — Domain-Aware Agent Delegation
- IPS-B domain scoring → agent routing (confidence ≥ 0.6)
- `/wf-legacy-classify` + `/wf-legacy-extract` dual-write migration
- L4 surface heuristic grouping (no-AI mode)
- L4/L5 deep enriched prompts

### Phase E — Checkpoint + Concurrency + Cache
- L3 intra-batch partial.json API
- Write throttle (5s min interval per session)
- `ConcurrencyController` 3-tier token bucket
- `AgentWatchdogRegistry` + timeout resolution
- `ScanCache` content-addressable 2-tier + privacy guard

### Phase F — Impact Graph + Incremental
- `impact_graph_builder.py` (6 relations + Tarjan SCC)
- L6 synthesis integration (4 synthesis modes)
- `incremental.py` (git_diff + mtime + Levenshtein rename detection)
- `workload_gate.py` (5 triggers, 3 options)

### Phase G — Bash Script Refactor
- 5 scripts refactored với shared library
- Scoring overflow fix (per-component clamps)
- 11 JSON outputs: `atomic_write_json` + `validate_json`
- 8 hardcoded caps → env vars

### Phase H — Resume Routing
- `resume_router.py` (604 dòng, 16 action types)
- `--session=ID` CLI flag
- `--status` v5.0 rewrite (scan-state canonical)

### Phase I — Integration Testing
- SKILL.md final integration (13 flags, 17 ADRs, 16 outputs)
- `_contract.json` v5.0.0 (jq-valid, 19 outputs, 8 new CLI flags)
- Compliance audit 3/3 PASS
- E2E test matrix Tier 1 12/12 PASS

---

## Những gì bị deferred sang v5.1

| Tính năng | Lý do defer |
|-----------|-------------|
| Workload Partition Planner | Scope quá lớn cho v5.0 — Gate detect đủ dùng. ADR-LS13 §3 |
| Multi-session aggregate report | Dependency on partition planner |
| `ledger.json` deprecation (breaking change) | Cần 1-2 releases transition period |
| ML-based domain detection | Over-engineering cho Vietnamese corpus hiện tại |
| Tier 2 E2E fixtures (A.3) | User cần populate fixtures từ real projects |

---

## Known Limitations

1. **A.3 Fixtures:** Tier 2 E2E tests (12 combinations) và performance benchmark cần fixtures
   thực tế (`small-en`, `medium-vn`, `large-mixed`). Hiện tại chỉ có Tier 1 synthetic PASS.
   → User cần chạy v4.1 trên 3 sample projects và copy output vào `docs/design/skills/wf-legacy-scan/fixtures/`.

2. **Workload Gate:** Detect + WARN hoạt động, nhưng Partition Planner (tự động chia work)
   bị defer sang v5.1. Nếu trigger → user phải tự chọn continue/downgrade/abort.

3. **Windows Git Bash symlinks:** `sessions/latest` symlink có thể không hoạt động trên
   một số Windows config — fallback về `latest.txt` marker file.

---

## Upgrade Notes cho DEVKIT Maintainers

### Paths mới (CORE §4b đã cập nhật)

```
.mc-data/work/legacy-scan/sessions/{id}/scan-state.json     # canonical v5.0
.mc-data/work/legacy-scan/sessions/{id}/scan-plan.md        # per-session plan
.mc-data/work/legacy-scan/sessions/{id}/phase-summary.md    # CORE-028
.mc-data/work/legacy-scan/domain-hints.json                 # IPS-B output
.mc-data/work/legacy-scan/impact-graph.json                 # L6 conditional
```

### Scripts mới

```
.claude/scripts/migrate-legacy-scan-v4-to-v5.sh   # one-time v4→v5 migration
.claude/scripts/legacy-scan-common.sh              # shared bash library (v1.0)
.claude/scripts/legacy-scan-phase-*-smoke.sh       # per-phase smoke tests (A-I)
```

### Python modules mới (`_shared/ips/`)

```
concurrency_controller.py   # 3-tier token bucket
agent_timeout.py            # watchdog registry
scan_cache.py               # content-addressable cache
impact_graph_builder.py     # L6 impact graph
incremental.py              # delta processing
workload_gate.py            # large-project gate
resume_router.py            # 4-level resume routing
vietnamese_keywords.py      # VN keyword pool
domain_scorer.py            # IPS-B scoring
ips_recommender.py          # IPS-A recommendation
scan_state_reader.py        # scan-state.json API
```

---

## Credits

- **DEVKIT Core Team** — Architecture design, implementation (Phases A-I)
- **Owner Eureka** — Project vision, requirements, ADR sign-off (pending A.4)
- **VN Keyword Contributors** — 14-domain Vietnamese pool (159+ entries)

---

## Tài liệu liên quan

| Tài liệu | Link |
|----------|------|
| User Guide (tiếng Việt) | [`docs/wf-legacy-scan-v5-guide.md`](wf-legacy-scan-v5-guide.md) |
| Design ADRs (17 quyết định) | [`docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md`](design/skills/wf-legacy-scan/08-tradeoffs-adr.md) |
| Migration Progress | [`docs/design/skills/wf-legacy-scan/MIGRATION-PROGRESS.md`](design/skills/wf-legacy-scan/MIGRATION-PROGRESS.md) |
| Skill README | [`.claude/skills/workflow/wf-legacy-scan/README.md`](../.claude/skills/workflow/wf-legacy-scan/README.md) |
