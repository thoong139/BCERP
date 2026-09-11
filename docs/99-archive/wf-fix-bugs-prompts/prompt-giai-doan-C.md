# Prompt — Giai đoạn C: Bellweather Lanes (QD1 + QD2)

> Dùng prompt này trong phiên Claude Code mới để khởi động Giai đoạn C.
> Phiên trước đã hoàn tất Giai đoạn B (B1→B4 PASS, review reports tại `docs/design/skills/wf-fix-bugs/reviews/`).

---

## Copy prompt dưới đây:

```
Triển khai Giai đoạn C — Bellweather Lanes cho wf-fix-bugs v6.0.

## Bối cảnh

Giai đoạn B đã hoàn tất (B1 scaffold → B2 impl → B3 integration → B4 CI/CD). Review reports:
- docs/design/skills/wf-fix-bugs/reviews/B1-review-20260420.md (PASS)
- docs/design/skills/wf-fix-bugs/reviews/B2-review-20260420.md (PASS)
- docs/design/skills/wf-fix-bugs/reviews/B3-review-20260420.md (PASS)
- docs/design/skills/wf-fix-bugs/reviews/B4-review-20260421.md (PASS)

Shared infrastructure sẵn sàng trong `.claude/skills/workflow/_shared/`:
- signal_bus/ — Signal→Issue normalize + dedup + POST-GATE T1-T4
- scan_cache/ — content-addressable cache (ADR-19)
- impact_graph/ — builder + verify_ripple (ADR-22 rule 2)
- isg/ — Interactive Selection Gate (ADR-14)
- concurrency/ — 3-tier token bucket (ADR-22 rule 3)
- workload_estimator/ — Workload Gate (ADR-14/15)
- tests/ — 259+ tests, coverage gate 80%
- pyproject.toml — pytest CI config
- .github/workflows/wf-fix-bugs-ci.yml — GitHub Actions CI

3 sub-skills đã wire vào _shared/:
- wf-fix-discover (621 LOC SKILL.md)
- wf-fix-triage (399 LOC SKILL.md)
- wf-fix-execute (382 LOC SKILL.md)
- wf-fix-bugs orchestrator (723 LOC SKILL.md)

## Mục tiêu C

Implement 2 dimension lane đầu tiên: **QD1 (Functional Correctness)** + **QD2 (Business Correctness)**.
QD1 + QD2 là North Star dimensions (09-design-decisions.md §1) — ưu tiên cao nhất.

## Quy tắc bắt buộc

1. ĐỌC design docs trước khi code — đặc biệt:
   - docs/design/skills/wf-fix-bugs/02-quality-dimensions.md (QD1 probes P1.01-P1.07, QD2 probes P2.01-P2.05)
   - docs/design/skills/wf-fix-bugs/03-architecture.md (lane model: Sense→Think→Act→Verify)
   - docs/design/skills/wf-fix-bugs/04-contracts-data-model.md (Signal v2, Issue v2 schema)
   - docs/design/skills/wf-fix-bugs/05-execution-profiles.md (exit criteria per profile)
   - docs/design/skills/wf-fix-bugs/09-design-decisions.md (locked decisions)
   - .claude/rules/00-core.md (CORE rules, đặc biệt CORE-006/007/023/025/026/028/030/031)

2. Tuân thủ ADR-22 safety defaults — 6 rules đã enforce runtime từ B2/B3.
3. Tiếng Việt có dấu cho documentation + docstring; English cho identifier + file name.
4. Mọi output file tạo từ template (CORE-031).
5. Quality trước tốc độ (CORE-023).

## Phân chia Giai đoạn C

### C1 — QD1 Lane Skeleton (wf-fix-functional)
- Tạo `.claude/skills/workflow/wf-fix-functional/` folder
- SKILL.md — lane quy trình Sense→Think→Act→Verify với probes P1.01-P1.07
- _contract.json (role=NONE với registry)
- templates/ cho lane outputs
- dimension.json đăng ký lane
- Migrate probe logic từ wf-fix-discover 5-Layer hiện tại

### C2 — QD1 Lane Implementation
- Implement probes P1.01 (static req-registry cross-ref), P1.02 (route config parse), P1.03 (infra preflight), P1.05 (API smoke)
- Wire probes vào Signal Bus (_shared.signal_bus.signal_bus.SignalBus.ingest)
- Wire Scan Cache cho probes tĩnh (opt-in --use-cache)
- Exit criteria: quick profile (P1.01+P1.03+P1.05) chạy được E2E

### C3 — QD2 Lane Skeleton (wf-fix-business)
- Tạo `.claude/skills/workflow/wf-fix-business/` folder
- SKILL.md — lane với probes P2.01-P2.05
- _contract.json (role=NONE)
- dimension.json đăng ký lane
- QD2 cần domain expert agents — wire vào `.claude/agents/business/`

### C4 — QD2 Lane Implementation
- Implement probes P2.01 (domain expert review), P2.02 (calculation check), P2.05 (hard-coded value detect)
- Wire agent calls qua subagent_type phù hợp
- Exit criteria: standard profile (P2.01+P2.02+P2.05) chạy được E2E

### C5 — Integration Test + E2E
- Chạy QD1+QD2 song song qua orchestrator (CORE-025: write scope tách biệt)
- Verify Signal Bus dedup hoạt động khi 2 lane emit signal cho cùng file
- Verify Verify Ripple (impact_graph) cho cross-module fixes
- Golden fixture cho regression testing

### C6 — C Review Report
- `docs/design/skills/wf-fix-bugs/reviews/C-review-YYYYMMDD.md`
- Đánh giá: coverage vs v5, false positive rate, ADR-22 compliance
- Khuyến nghị cho Giai đoạn D (remaining lanes QD3-QD7)

## Thứ tự thực hiện

Tuần tự C1 → C2 → C3 → C4 → C5 → C6. Không skip.
C1 và C3 có thể song song NẾU muốn (CORE-025: write scope tách biệt lanes/QD1 vs lanes/QD2).

## Acceptance Criteria

- QD1 coverage ≥ 80% so với wf-fix-discover 5-Layer tương đương trên fixture
- QD2 domain expert review chạy được trên ≥ 1 department fixture
- Signal Bus dedup hoạt động đúng khi 2 lane emit signal cho cùng file
- False positive rate < 15% (tăng từ <10% baseline vì coverage rộng hơn — đã chấp nhận trong README §7 M5)
- phase-summary.md ≤ 15 dòng (CORE-028)
- POST-GATE T1-T4 pass
- Coverage gate 80% cho code mới
- CI pipeline pass (.github/workflows/wf-fix-bugs-ci.yml)

## Tham chiếu nhanh

| Tài liệu | Vị trí | Đọc để hiểu |
|----------|--------|-------------|
| Design README | docs/design/skills/wf-fix-bugs/README.md | Tổng quan + roadmap |
| Quality Dimensions | docs/design/skills/wf-fix-bugs/02-quality-dimensions.md | QD1 probes + QD2 probes chi tiết |
| Architecture | docs/design/skills/wf-fix-bugs/03-architecture.md | Lane model |
| Contracts | docs/design/skills/workflow/wf-fix-bugs/04-contracts-data-model.md | Signal v2 + Issue v2 schema |
| Execution Profiles | docs/design/skills/wf-fix-bugs/05-execution-profiles.md | Exit criteria per profile |
| Design Decisions | docs/design/skills/wf-fix-bugs/09-design-decisions.md | Locked decisions |
| CORE rules | .claude/rules/00-core.md | Bắt buộc tuân thủ |
| _shared README | .claude/skills/workflow/_shared/README.md | Shared modules |
| Runbook | docs/runbooks/wf-fix-bugs-troubleshooting.md | E-codes reference |
```
