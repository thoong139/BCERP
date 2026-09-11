# wf-legacy-scan v5.0

Skill scan toàn diện dự án hiện có: detect → classify → extract → synthesize → `project-context.md`.

## Tổng quan

`/wf-legacy-scan` là bước đầu tiên trong **Existing Path** của DEVKIT. Skill orchestrate toàn bộ
legacy scan pipeline qua 6 layers (L1-L6), tự động phát hiện hiện trạng dự án, xác định strategy
(S1-S7), và tổng hợp `project-context.md` — file chìa khoá cho tất cả shared skills downstream.

```
/wf-legacy-scan [project-path] [flags]
    → /wf-legacy-classify (L4)
    → /wf-legacy-extract (L5)
    → /wf-brainstorm* → /wf-analyze-requirements* → ... (downstream pipeline)
```

> `*` = shared skills tự detect LEGACY_MODE qua `project-context.md` (CORE-021).

## Tính năng v5.0

| Tính năng | Mô tả |
|-----------|-------|
| **4 Profiles** | `surface` / `standard` / `deep` / `exhaustive` — kiểm soát depth L4/L5/L6 |
| **IPS 2-phase** | Intelligent Profile Selection: IPS-A (project size) + IPS-B (domain detection EN+VN) |
| **Session isolation** | Mỗi lần chạy trong session riêng (`sessions/{id}/`) — không overwrite |
| **4-Level Checkpoint** | L0 phase / L1 layer / L2 batch / L3 intra-batch — resume sau crash |
| **Incremental scan** | `--incremental` + `--since=<git-ref>` — chỉ re-process files thay đổi |
| **Scan Cache** | Content-addressable fingerprint, 2-tier (session + project), privacy guard |
| **Workload Gate** | Detect large+deep combo → WARN + 3 options (continue/downgrade/abort) |
| **Impact Graph** | `impact-graph.json` tại L6 — downstream ripple support cho verify-sync + fix-bugs |
| **Domain-Aware Agents** | L4/L5 tự động route đến business-analyst + domain expert theo IPS-B |
| **VN Keyword Pool** | 14 domains × 159+ từ khoá tiếng Việt cho IPS domain detection |

## Kiến trúc

```
SKILL.md (orchestrator)
├── procedures/
│   ├── phase0-detection.md      # L1: Detect + tech stack
│   ├── phase0a-assessment.md    # L2: Score + strategy (S1-S7)
│   ├── phase0b-profile.md       # IPS-A + profile resolver + CDG
│   ├── phase05-maturity.md      # Optional: DEVKIT_PARTIAL+ projects
│   ├── phase1-inventory.md      # L3: Inventory (8 files + ui-manifest + IPS-B)
│   ├── phase2-classify.md       # L4: Agent delegation → /wf-legacy-classify
│   ├── phase3-extract.md        # L5: Agent delegation → /wf-legacy-extract
│   ├── phase4-synthesize.md     # L6: project-context.md + impact-graph
│   ├── resume-status.md         # --resume + --status handlers
│   └── _shared.md               # Cross-cutting: state vars, templates, error handling
├── templates/
│   ├── scan-state.json          # Session state schema (v5.0 canonical)
│   ├── project-context.md       # Phase 4 synthesis output template
│   ├── domain-hints.json        # IPS-B domain signals schema
│   ├── impact-graph.json        # Impact graph schema (L6)
│   └── ...                      # 14 tổng templates
├── evals/
│   └── evals.json               # Test cases cho skill compliance audit
└── _contract.json               # Skill contract v5.0.0 (jq-valid, 19 outputs)
```

### Python shared modules (`.claude/skills/workflow/wf-legacy-scan/_shared/ips/`)

| Module | Mục đích |
|--------|----------|
| `vietnamese_keywords.py` | VN keyword pool loader (14 domains) |
| `domain_scorer.py` | IPS-B domain scoring + confidence threshold |
| `ips_recommender.py` | IPS-A → profile recommendation |
| `scan_state_reader.py` | scan-state.json API (12 functions) |
| `concurrency_controller.py` | 3-tier token bucket (global/per_layer/per_probe) |
| `agent_timeout.py` | Per-agent timeout resolution + watchdog registry |
| `scan_cache.py` | Content-addressable 2-tier cache + privacy guard |
| `impact_graph_builder.py` | 6 relation types + Tarjan SCC circular detection |
| `incremental.py` | git_diff + mtime delta processing + Levenshtein rename |
| `workload_gate.py` | 5-trigger detect + 3-option user prompt |
| `resume_router.py` | 4-level resume routing (16 action types) |

## Output Files

### Session-scoped (`.mc-data/work/legacy-scan/sessions/{id}/`)

| File | Mô tả |
|------|-------|
| `scan-state.json` | Pipeline state machine — canonical v5.0 |
| `scan-plan.md` | Human-readable scan plan per session |
| `phase-summary.md` | Phase summary tiếng Việt (CORE-028) |
| `session-digest.md` | Session summary cuối pipeline |
| `error-ledger.json` | Errors per session |

### Standard location (`.mc-data/work/legacy-scan/`)

| File | Mô tả |
|------|-------|
| `project-profile.json` | Tech stack + project metrics |
| `assessment-report.json` | Strategy selection scores (S1-S7) |
| `domain-hints.json` | IPS-B domain signals + confidence |
| `impact-graph.json` | Dependency ripple graph (conditional) |
| `project-context.md` | **Canonical output — CORE-021 LEGACY_MODE anchor** |
| `doc-quality-map.json` | Doc trust scores per file |
| `impl-status-snapshot.json` | Existing impl status (one-time seed) |
| `ledger.json` | v4.1 backward-compat projection |
| `inventory/*.json` | 8 inventory files (screens, APIs, docs, sources, deps, ext-docs, ui-manifest) |
| `classified/*` | Classify outputs (via wf-legacy-classify L4) |
| `extracted/*` | Extract outputs (via wf-legacy-extract L5) |

## CLI Flags

| Flag | Mô tả |
|------|-------|
| `project-path` | Đường dẫn đến thư mục gốc (default: CWD) |
| `--profile=surface\|standard\|deep\|exhaustive` | Execution profile |
| `--layers=L1,...` | Layer depth override (dùng với `--depth`) |
| `--depth=surface\|standard\|deep` | Depth override cho `--layers` |
| `--session=ID` | Gắn vào session cụ thể |
| `--status` | Hiển thị pipeline status → STOP |
| `--resume` | Resume từ checkpoint cuối |
| `--re-vision` | Strategy S6: giữ code, thay đổi vision |
| `--batch-size=N` | Batch size cho classify (default: 100) |
| `--incremental` | Chỉ re-process files thay đổi |
| `--since=<git-ref>` | Git ref cho `--incremental` diff |
| `--no-cache` | Bypass scan cache |
| `--cache-publish` | Copy session cache → project cache |

## Test Coverage (Phase I — 2026-04-22)

| Test Suite | Kết quả |
|------------|---------|
| IPS Python suite | 410/410 PASS |
| E2E Tier 1 (12 profiles × fixtures) | 12/12 PASS |
| Crash injection | 8/8 PASS |
| Resume router | 36/36 unit + 13/13 Tier 1 PASS |
| Downstream integration Tier 1 | 9/9 PASS |
| Compliance audit (3 skills) | 3/3 PASS |
| Regression suite | 10/11 PASS (1 SKIP/A.3 fixtures pending) |

## Backward Compatibility

**Default usage không bị breaking change.** Chạy `/wf-legacy-scan` không flag = v4.1 behaviour.
- `standard` profile = v4.1 depth (ADR-LS02).
- `ledger.json` vẫn được tạo (dual-write cho transition period).
- Sub-skills `/wf-legacy-classify` và `/wf-legacy-extract` đọc được cả `scan-state.json` (v5.0) lẫn `ledger.json` (v4.1 fallback).

## User Guide

Xem: [`docs/wf-legacy-scan-v5-guide.md`](../../../../docs/wf-legacy-scan-v5-guide.md)

## Design Documents

| File | Mô tả |
|------|-------|
| `docs/design/skills/wf-legacy-scan/01-vision-principles.md` | Vision + nguyên lý thiết kế |
| `docs/design/skills/wf-legacy-scan/02-scan-layers.md` | 6 Scan Layers (L1-L6) |
| `docs/design/skills/wf-legacy-scan/03-architecture.md` | Kiến trúc tổng thể |
| `docs/design/skills/wf-legacy-scan/04-data-model.md` | scan-state.json schema |
| `docs/design/skills/wf-legacy-scan/05-profiles-ips.md` | 4 Profiles + IPS 2-phase |
| `docs/design/skills/wf-legacy-scan/06-bash-scripts.md` | Bash scripts architecture |
| `docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md` | 17 ADRs |
| `docs/design/skills/wf-legacy-scan/10-vietnamese-keywords.md` | VN keyword pool (14 domains) |

## Migration từ v4.1

Xem: [Migration Helper Script](.claude/scripts/migrate-legacy-scan-v4-to-v5.sh)

```bash
# Chạy một lần để migrate ledger.json → scan-state.json
./.claude/scripts/migrate-legacy-scan-v4-to-v5.sh [project-path]
```

**Không cần làm gì nếu:**
- Bạn chỉ dùng `/wf-legacy-scan` qua Claude (không gọi trực tiếp sub-skills).
- Bạn bắt đầu scan mới từ đầu.
