# 06 — Evolution History (v5.1 → v10.18.0)

> **Đọc trước:** [05-execution-profiles.md](05-execution-profiles.md)
> **Đọc tiếp:** [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md)
> **Trạng thái:** v2.0 · Timeline đầy đủ từ v5.1 → v10.18.0 (2026-04-21 → 2026-05-16, ~27 ngày)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/06-migration-plan.md](../../99-archive/wf-fix-bugs-design-v1.0/06-migration-plan.md) (migration plan v5 → v6, đã DONE)

> Lưu ý: Migration plan v5 → v6 trong tài liệu v1.0 đã hoàn tất (Stage A-N, COMPLETE 2026-04-21). Tài liệu này thay thế bằng lịch sử evolution đầy đủ qua tất cả version major.

---

## 1. Timeline Tổng Quan

```
2026-04-20 ───── Design v1.0 approved (Eureka sign-off)
        │
        │ ┌─ Phase A: Design Closure (ADR-14 → 22)
        │ │
2026-04-21 ──── v6.0.0 Implementation COMPLETE
        │ │      • 7 dimensions (QD1-QD7)
        │ │      • 3 sub-skills (wf-fix-discover/triage/execute)
        │ │      • Signal Bus + Shared Services
        │ │      • Stage B-N hoàn tất (~507 tests)
        │ │
2026-04-22 ──── v6.1.0 (post-release audit fixes)
        │ │
2026-04-29 ──── v7.0.0 → v7.1.0 (Overhaul lớn)
        │ │      • Pure orchestrator (loại bỏ wf-fix-discover)
        │ │      • Session isolation (CORE-030)
        │ │      • Lock + heartbeat + JSONL index
        │ │      • CDG gates (E090/E090b/...)
        │ │      • 12 sprints + E2E + hotfix + v7.1 (4 sprints)
        │ │      • 28/28 findings closed, 73 evals
        │ │      • Deprecation BLOCK + escape hatch
        │ │
2026-05-09 ──── v8.2.0 (Signals.json overwrite fix + QD8)
        │ │      • Tier A (A1/A2/A3/B3) + Tier B+C
        │ │      • B1 cross-lang lock, B2 schema unify
        │ │      • C1 verify, C2 module skip, C3 ownership contract
        │ │      • QD8 Observability lane mới
        │ │      • 49 E2E + 7 new tests PASS
        │ │
2026-05-10 ──── v8.2.1 → v9.0.2 (Runtime + Integration + QD9/QD10)
        │ │      • v8.2.1+v8.2.2: 7 root causes B3/B1/B2/C1/C2/C3
        │ │      • v9.0.0 ❌ FANTASY COMPLETION (mark DONE nhưng runtime fail)
        │ │      • v9.0.1 patch: 7 vị trí hạ tầng hardcoded `QD[1-8]` → QD9/QD10
        │ │        - dimension.json schema fix, dispatch drift fix
        │ │        - 41 regression test + wave-gate runtime smoke
        │ │        - 611 pytest pass
        │ │      • v9.0.2 coverage completion: 5 planning gaps + 8 cosmetic docs + 20 regression tests (631 pytest)
        │ │
2026-05-10 ──── v9.1.0 (QD11 Business Completeness)
        │ │      • 3-pass LLM analysis (cross-module / domain heuristic / registry gap)
        │ │      • 11 signal types (MISSING_FIELD, MISSING_FEATURE, ...)
        │ │      • Enhancement workflow qua CDG gate (ACCEPT/REJECT)
        │ │
2026-05-12 ──── v10.0 Design (Architectural Redesign)
        │ │      • Design doc: docs/architect-skill/wf-fix-bugs-redesign-v10.md
        │ │      • 13 sprints planned (~32-45h)
        │ │
2026-05-13 ──── v10.0.0 IMPLEMENTATION (Đại tu)
        │ │      • 7-phase pipeline (Init → Scan → Plan → Find Bugs → Triage → Execute → Verify)
        │ │      • Lazy-load procedures (CORE-032): SKILL.md ≤500 dòng + 9 procedure files + 32 templates
        │ │      • CI PRE-GATE (CORE-033): Na/Nb/Nc auto-detect GitNexus/Serena
        │ │      • Namespaced error codes (CORE-034): E001-E109 + 10 ranges + auto-fix budget 3/phase
        │ │      • Session subdirectories (CORE-035): phase{N}-{name}/ + Phase{N}-report.md tiếng Việt ≤15 dòng
        │ │      • Cross-skill artifact contract (CORE-036): fix-impact.json + audit_chain sha256
        │ │      • 8-section agent prompts (CORE-037): role/task/session/CI/playwright/output/ownership/completion
        │ │      • Context budget management (CORE-038): tiered <65/65-80/80-90/>90%
        │ │      • Playwright 3 modes: headless / --show-browser / --mobile
        │ │
2026-05-14 ──── v10.2.0 (UI Coverage + lane-agent-prompt v10.2)
        │ │      • Tách Lane Agent Prompt thành template canonical
        │ │      • Placeholder {{VAR}} convention (§10)
        │ │      • Bảng Substitution + FORBIDDEN PATTERNS
        │ │      • Step 4.5a Pre-Dispatch Verify (6 check points)
        │ │      • 3 probes promote vào standard
        │ │      • NEW P-QD9-disabled-cta-check
        │ │      • BASE_URL E090b CDG + Multi-Session Notes
        │ │      • 6 sprints ~6h actual/16.5h estimated (-64%)
        │ │
2026-05-16 ──── v10.3 → v10.18 Optimization Waves (cùng ngày)
                 (xem chi tiết §6 bên dưới)
```

---

## 2. v5.1 → v6.0 (3 sub-skills → 7 dimension lanes)

### Vấn đề trong v5.1

- `wf-fix-discover` phình to với 5-Layer + 12 bug category nhồi vào trong
- Issue registry không có `dimension` field — không trả lời được "security coverage là gì"
- Flag `--deep`/`--full-test`/`--responsive` rời rạc, khó kết hợp
- Không có khái niệm "chạy 1 dim độc lập"

### Giải pháp v6.0 (2026-04-21)

- **Dimension axis** thay 5-Layer: 7 QDs (Functional, Business, Security, Performance, UX/A11y, Data, Compat)
- **Signal Bus** utility module: dedup + normalize signals từ multi-lane → emit Issues
- **Shared Services** 4-thành phần: Triage / Planner / Fixer / Verifier
- **4 profiles** (quick/standard/deep/exhaustive) thay flag rời rạc
- **First-class dimension selection** `--dims=QD3,QD5`

### Tests đạt được

| Stage | Tests | Notes |
|-------|-------|-------|
| B (Skeleton) | 259 | Signal Bus, Scan Cache, Probe Executor, ISG, Workload Estimator, Concurrency Controller, Impact Graph |
| C (Bellweather QD1+QD2) | +16 → 275 | 12 probes, 16 E2E |
| D (QD3-QD7) | +43 → 318 | 31 probes, 43 E2E |
| E (Orchestrator) | +37 → 380 | dispatch_lanes(), aggregate_lane_signals(), resolve_probes() |
| F-L (Integration) | ~507 total | Full v6 pipeline E2E |
| N (v5 Removal) | ~507 | wf-fix-discover deleted |

> Migration plan chi tiết: [99-archive/wf-fix-bugs-design-v1.0/06-migration-plan.md](../../99-archive/wf-fix-bugs-design-v1.0/06-migration-plan.md)

---

## 3. v6.x → v7.x (Pure Orchestrator + Session Isolation)

### Lý do overhaul (2026-04-29)

v6.0 vẫn còn `wf-fix-discover` làm dispatcher, không clean. Cần **pure orchestrator** + **session isolation** chính thức.

### v7.0.0 → v7.1.0 changes

| Aspect | v6.1.0 | v7.1.0 |
|--------|--------|---------|
| Architecture | wf-fix-discover dispatcher + 3 sub-skills | **Pure orchestrator** spawn lane skills `wf-fix-{slug}` |
| Session | Best-effort | Session isolation `sessions/{SESSION_ID}/` + atomic mkdir claim + lock canonical helper + heartbeat atomic |
| Index | None | `_index/sessions.jsonl` APPEND-only |
| CDG | Basic | Full CDG gates (E090/E090b/E091/E092/E093) |
| Deprecation | None | BLOCK legacy `run-NNN-*` paths với CDG override + escape hatch `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1` |

### Tests v7.1

- 12 sprints + E2E + hotfix + v7.1 (4 sprints) = ~27h actual / 70h estimate (-61%)
- 28/28 findings closed
- 73 evals
- 3 cross-skill consumers wired (wf-verify-sync, wf-prepare-deployment, wf-implement-feature)
- Migration v6.x → v7.0 qua `--migrate` flag

---

## 4. v7.x → v8.x → v9.1 (Mở rộng QD8, QD9, QD10, QD11)

### v8.2.0 — QD8 Observability (2026-05-09)

**Trigger:** Production incident — payment service không có retry + timeout → flaky failures trong giờ cao điểm. QD3 không cover. QD4 chỉ đo performance, không đo reliability.

**Giải pháp:**
- QD8 lane mới: 7 probes (retry/circuit-breaker, timeout, log coverage, metrics, health-check, trace propagation, alert rules)
- Owner: sre + devops
- CDG-RELIABILITY-RISK trigger trên `payment/auth` modules
- Signals.json overwrite fix: 7 root causes B3/B1/B2/C1/C2/C3 (cross-lang lock, schema unify, verify, module skip, ownership contract)

### v9.0.1 patch — Runtime Dispatch Drift (2026-05-10)

**Vấn đề CRITICAL (Fantasy Completion):**
- v9.0.0 mark 38/38 DONE
- Nhưng QD9/QD10 dispatch FAIL runtime
- Root cause: thiếu `dimension.json` + 6 vị trí hạ tầng hardcoded `QD[1-8]` regex

**Fix:**
- 7 vị trí fix trong dispatch logic
- 41 regression test + wave-gate runtime smoke
- 611 pytest pass
- CHANGELOG entry shipped

### v9.0.2 — Coverage Completion (2026-05-10)

- 5 planning-level gaps closed (profiles, dim-selection schema, workload schema, ISG DIMENSIONS, phase6-report QD4)
- 8 cosmetic docs
- 20 regression tests → 631 pytest pass
- version 8.2.0 → 9.0.2

### v9.0.x — QD9 Runtime Health (2026-05-10)

**Trigger:** Bug chỉ thấy qua browser runtime — console errors, network failures, uncaught exceptions, broken auth flows, SPA routes unreachable.

**Giải pháp:**
- QD9 lane Playwright-heavy: 7 probes (3 core Wave 1 + 4 deep Wave 1.5)
- Owner: qa-lead + frontend-developer
- SKIP rules: `interface_type=api-only`, `--no-browser`, `profile=quick`
- CDG E090 (Missing URL) + E090b (BASE_URL conflict)

### v9.0.x — QD10 Cross-Module Integration (2026-05-10)

**Trigger:** Bug do orphan FK, API contract drift, cross-module reference broken — single-module probe không thấy.

**Giải pháp:**
- QD10 lane: 9 probes (cross-module reference drift, API contract violation, event handler coverage, orphan FK, multi-platform entity sync, cache staleness, state machine errors, business flow violations, auth matrix violations)
- Owner: architect + data-engineer + domain experts
- SKIP rules: single module project, `profile=quick`

### v9.1.0 — QD11 Business Completeness (2026-05-10)

**Trigger:** Missing business logic phát hiện qua LLM analysis — pattern A có ở module X nhưng thiếu ở module Y với cùng vai trò.

**Giải pháp:**
- QD11 lane LLM-heavy: 3-pass analysis
  - Pass 1 Cross-module pattern comparison
  - Pass 2 Domain heuristic analysis (deep+)
  - Pass 3 Registry gap detection
- 11 signal types (MISSING_FIELD, MISSING_FEATURE, TYPE_MISMATCH, VALIDATION_GAP, MISSING_DOMAIN_FIELD, MISSING_COMPLIANCE_CHECK, MISSING_AUDIT_TRAIL, MISSING_BUSINESS_RULE, UNIMPLEMENTED_REQ, ORPHAN_REQ_ID, GAP_REQ_TO_FEAT)
- Enhancement suggestions qua CDG gate (user ACCEPT/REJECT)
- Owner: business-analyst + domain experts + architect
- SKIP rules: single module, api-only, `profile=quick`

---

## 5. v10.0 (Đại Tu Kiến Trúc — 2026-05-13)

### Bối cảnh

v9.1 dispatch 11 lane agents nhưng SKILL.md vẫn monolithic ~700 dòng + procedures inline + error codes ad-hoc. Trên dự án ERP lớn (EUREKA-2026), pipeline thường xuyên trigger `/compact` do context overflow.

### Design Document

`docs/architect-skill/wf-fix-bugs-redesign-v10.md` (1130 dòng, 11 sections) — design doc đầy đủ với 13 sprints ~32-45h estimated.

### v10.0.0 Changes (Foundation)

| Aspect | v9.1 | v10.0 |
|--------|------|--------|
| Pipeline | 3 phase (Discover/Triage/Execute) | **7 phases** (Init → Scan → Plan → Find Bugs → Triage → Execute → Verify) |
| SKILL.md | ~700 dòng monolithic | **~350 dòng lean routing** (CORE-032) |
| Procedure files | Inline | **9 procedure files** + **32 templates** (CORE-031) |
| Phase reports | Ad-hoc | **7 Phase reports** (Phase1-report.md → Phase7-report.md) + **11 Agent reports** (QD1-QD11) tiếng Việt ≤15 dòng (CORE-028) |
| Error codes | Ad-hoc | **Namespaced E001-E109** (10 ranges) + auto-fix budget 3 retries/phase (CORE-034) |
| CI integration | Optional manual | **CI PRE-GATE Na/Nb/Nc** (Protocol 20 §20.8) + graceful Grep/Glob fallback (CORE-033) |
| Playwright | Headless only | **3 modes** (headless/visible/mobile) + device emulation (CORE-037) |
| Session | Lock-based | **Session subdirectories** `phase{N}-{name}/` + atomic mkdir SESSION_ID claim + lock canonical helper + heartbeat atomic + `_index/sessions.jsonl` (CORE-030, CORE-035) |
| Cross-skill artifact | issue-v2 | **fix-impact-v1** + audit_chain sha256 (CORE-036) cho 6 consumers |
| Context budget | Best-effort | **Tiered <65/65-80/80-90/>90%** + checkpoint (CORE-038) |
| Agent prompts | Free-form | **8-section template bắt buộc** (CORE-037) |
| Lane count | 11 | **Max 10 PARALLEL** (harness limit, CORE-025) — N=11 queue tự nhiên |

### Quality Gates Mới

- Phase 5 Step 5.10 Safety Check (4-point: collision detect, REQ-ID xref, uncommitted changes, deprecated modules)
- Phase 7 Step 7.2 CQG-1 Numeric (deviation ≤5% expected vs actual)
- Phase 7 Step 7.3 CQG-2 Browser+Integration (CDG REJECT missing QD9/QD10 evidence)

### POST-GATE → `fix-impact.json` (schema fix-impact-v1)

- `$schema` field
- `audit_chain.checksum_sha256` sha256 64-char pre-finalize
- Consumed bởi wf-verify-sync, wf-prepare-deployment, wf-implement-feature, wf-cmi opt-in

### Cross-Skill Wiring

- `--from-fix-bugs` flag wired vào wf-verify-sync, wf-prepare-deployment, wf-implement-feature
- `--from-cmi` (opt-in) consume integrity-impact.json từ wf-cmi

---

## 6. v10.3 → v10.18 Optimization Waves (2026-05-16, cùng ngày)

> **Mục tiêu:** Pipeline ~5-6K tokens/phase, không trigger `/compact` trên dự án lớn. **6 waves** áp dụng Optimization Playbook T1-T10 cho từng phase.

### v10.3 — Phase 1 Optimization

- 25 → 18 steps (-28%)
- Procedure file 1503 → ~1000 dòng (-33%)
- ~28K → ~10K tokens (-65%)
- Architectural changes:
  - (1) CI PRE-GATE Na/Nb/Nc gộp thành 1 wrapper script `ci-pregate.sh` (delete Steps 1.5, 1.6)
  - (2) State files populate qua 1 script `init-session-state.sh` (delete Steps 1.20, 1.21)
  - (3) Bug dashboard init delegate sang `init-bug-dashboard.sh`
  - (4) CDG just-in-time: E090/E090b moved Phase 1 → Phase 4 Step 4.3a (chỉ khi `PW_LANE_COUNT > 0`)
  - (5) E091/E092/E093 auto-resolve hoặc WARN log (no CDG); E100 deleted (duplicate Phase 3 ISG Recommender)

### v10.4 — Phase 2 Optimization

- 10 → 5 steps (-50%)
- Procedure 874 → ~345 dòng (-60%)
- ~8.4K → ~3.5K tokens (-59%)
- Architectural changes:
  - Steps 2.3-2.7 (Interface Detection + Code Inventory + Doc Inventory + Scope Analysis + WRITE) gộp thành 1 atomic call wrapper `scan-and-analyze.sh` (458 dòng)
  - Step 2.9 Phase Report delegate sang `generate-phase2-report.sh`
  - Fix CORE-031 bug v10.3 (template Phase2-report.md trước đây không được sử dụng — inline heredoc thay vì sed populate)

### v10.5 — Phase 3 Optimization

- 12 → 7 steps (-42%)
- Procedure 1135 → 502 dòng (-56%)
- ~10.93K → ~5.24K tokens (-52%)
- Architectural changes:
  - Steps 3.3-3.4 (ISG + Partition) gộp → `plan-isg-partition.sh`
  - Steps 3.6-3.9 (Agent Dispatch + Playwright Planning + Dim→Lane Routing + WRITE outputs) gộp → `route-and-write.sh` (251 dòng)
  - Step 3.5 Workload Gate CDG-11 GIỮ INLINE (AskUserQuestion)

### v10.6 — Phase 4 Optimization

- 12 → 9 steps (-25%)
- Procedure 1106 → 740 dòng (-33%)
- ~15.65K → ~8.56K tokens (-45%)
- Architectural changes:
  - Steps 4.2-4.3 gộp → `setup-lanes.sh`
  - Steps 4.6-4.7 (Monitor + Validate) gộp → 2 sequential scripts (`monitor-lanes.sh` + `validate-lane-outputs.sh`)
  - Steps 4.9-4.10 (Update fix-status + TRACE COMPLETE) gộp → `finalize-phase4.sh`
  - Step 4.4 Create Lane Dirs delegate sang `create-lane-dirs.sh`
  - Step 4.5a 6 check points delegate sang `verify-lane-prompt.sh`
  - Step 4.3a Browser CDG GIỮ INLINE (user interaction)
  - Step 4.5 Dispatch Lane Agents GIỮ orchestrator-side (Agent tool calls không script được)

### v10.7 — Phase 5 Optimization

- 15 → 10 steps (-33%, phase nhiều steps nhất pipeline)
- Procedure 1039 → 616 dòng (-41%)
- ~10.73K → ~5.77K tokens (-46%)
- 7 scripts mới tổng ~37KB
- Cross-platform fixes: `bc` absent Git Bash → awk fallback, `grep -c | tr -d "\r"` chống "0\n0" corruption

### v10.8 — Phase 6 Optimization

- 11 → 7 steps (-36%)
- Procedure 968 → 581 dòng (-40%)
- ~10.81K → ~5.71K tokens (-47%)
- Architectural changes:
  - Steps 6.1-6.2 gộp → `setup-execute.sh`
  - Step 6.3 dry-run preview delegate sang `dry-run-preview.sh`
  - Steps 6.6-6.7-6.7b gộp → `verify-execute-outputs.sh`
  - Step 6.4 CI-ROUTE Pre-Execution Impact Analysis GIỮ INLINE (CDG render AskUserQuestion)
  - Step 6.5 Spawn wf-fix-execute GIỮ orchestrator-side

### v10.9 — Phase 7 Optimization

- 14 → 8 steps (-43%)
- Procedure 1186 → 601 dòng (-49% — phase dài nhất pipeline trước v10.9)
- ~11.96K → ~5.77K tokens (-52%)
- Architectural changes:
  - Steps 7.1-7.2 gộp → `setup-verify.sh`
  - Step 7.3 CQG-1 Numeric delegate sang `cqg1-numeric.sh`
  - Steps 7.5-7.5b gộp → `finalize-dashboard.sh`
  - Steps 7.6-7.7-7.8-7.9 (orchestrator-summary + fix-impact.json + phase-summary + Phase7-report) gộp → `generate-phase7-reports.sh`
  - Step 7.4 CQG-2 Browser+Integration Gate GIỮ INLINE (CDG REJECT)
  - Steps 7.12-7.13 TodoWrite + Completion Display GIỮ orchestrator-side (UI tools)

### v10.9.1 Fix Wave (cùng v10.9)

10 fix items:
- E010-E013 namespace conflict
- E090b stale ref
- Lock TOCTOU race
- Session-log raw append
- SESSION_ID atomic claim
- CQG-2 keyword fragility (chuyển sang structured fix-log check)
- CDG aggregation cross-phase Phase 6 PRE-GATE
- Max-retry enforcement Step 6.5
- fix-impact checksum pre-finalize
- CRITICAL_COUNT structured

### v10.10 — Phase 4 Downstream Artifact Contract

- Bổ sung `phase4-summary.json` (schema `phase4-summary-v1`) làm cross-lane rollup machine-readable
- Generated bởi `generate-phase4-report.sh` song song với Phase4-report.md
- Schema bao gồm: per-dim breakdown, aggregated rollup (top-10 fingerprints), registry_coverage, cdg_decisions snapshot, evidence_index cross-lane, audit_chain sha256
- Non-breaking: downstream skills VẪN có thể đọc lanes/QD*/signals.json trực tiếp

### v10.11 — Schema Hardening Wave

7 fixes cho phase output contract:
1. `fix-execution-result.json` bump v1→v2 (derive-from-fix-log, orchestrator-side)
2. Phase 2 templates bump v2 (_schema_notes definitions)
3. Phase 3 templates bump v2 (align với route-and-write.sh script output)
4. Phase 5 mới `coverage-report.json` schema `coverage-report-v1` (machine-readable)
5. `issue-registry.json` bump v2 (_schema_notes + consumer hints)
6. `docs-sync-report.json` bump v2 (files_synced field, audit_chain CORE-006)
7. `bug-dashboard.md` version counter (HTML comment markers) — CORE-025 concurrent-write conflict detect

### v10.12 — Phase 1 Parallel Optimization Wave

4 helpers mới (~750 dòng tổng):
- **Wave 1 Parallel Discovery:** Steps 1.5 (CI PRE-GATE) + 1.6 (Registry+Source+LEGACY) + 1.9 (Sub-skill paths) gộp thành 1 bash tool call qua `phase1-wave1-dispatch.sh` — 3 workers parallel
- **Wave 4 Parallel State Init:** Steps 1.15 (init-session-state) + 1.16 (init-bug-dashboard) gộp thành `phase1-init-bundle.sh` — 2 workers parallel
- **Step 1.14 ISG fast-path:** `phase1-isg-fastpath.sh` — bash hardcoded lookup ~5ms thay vì Python ISG ~200-500ms
- **Sub-skill paths cache 24h:** `phase1-validate-paths.sh` — cache hit ~10ms thay vì 13 test -f syscalls

Số bash tool calls Phase 1: ~10 → ~7 (-30%), Claude orchestration giảm ~5-10s.

### v10.13 — Shared Protocols Split (T5)

- `_shared.md` (1227 dòng monolithic, ~10K tokens) tách thành 21 file riêng trong `_shared/`
- Lazy-load per use-site → giảm context per phase 80-95%
- 4 sections slim hóa thành 1-line pointers (§1 State Vars, §4 Error Handling, §10 Template Usage, §17 Session Isolation)
- Backward compat: `_shared.md` chuyển thành ~30 dòng redirect file

| Phase | Saving |
|-------|--------|
| Phase 1 | -91% (10K → 1K) |
| Phase 2 | -97% |
| Phase 3 | -96% |
| Phase 4 | -68% |
| Phase 5 | -86% |
| Phase 6 | -88% |
| Phase 7 | -92% |

### v10.14 — Phase 1 Lazy-Load Split (T6)

- `phase1-init.md` 1106 dòng → 80-dòng index + 8 group files
- Per-group context ~88% nhỏ hơn vs monolithic
- 4 helper scripts mới extract heavy inline bash
- Smoke test `phase1-routing-smoke-test.sh` 42/42 PASS

### v10.15 — Optimization Playbook + Shared Trace Scripts

- `_optimization-playbook.md` document hóa 10 kỹ thuật canonical T1-T10
- 2 shared helper scripts mới (`phase-trace-start.sh` + `phase-finalize.sh`) reusable cross-phase (2-7)
- Phase 2 migrated to shared scripts (Steps 2.2 + 2.5)
- ROLLOUT-PLAN v10.15 cho Phase 3-7

### v10.16 — Phase 3 + Phase 6 Lazy-Load Split

- Phase 3: 515 → 80-dòng index + 6 groups + POST-GATE
- Phase 6: 619 → 90-dòng index + 7 groups + POST-GATE
- Steps 3.2 + 3.7 + 6.7 migrate sang shared trace scripts
- Smoke tests: 35/35 + 40/40 PASS

### v10.17 — Phase 5 + Phase 7 Lazy-Load Split

- Phase 5: 648 → 135-dòng index + 7 groups + POST-GATE
- Phase 7: 657 → 120-dòng index + 7 groups + POST-GATE
- Phase 5 Step 5.10 migrate sang shared `phase-finalize.sh`
- Phase 7 Step 7.6 GIỮ `finalize-phase7.sh` (special case do pre-finalize `pipeline_status=DONE` + dual-write global trace)
- Smoke tests: 42/42 + 44/44 PASS
- Cross-phase smoke tests: 203 checks PASS, 0 regression

### v10.18 — Phase 4 Lazy-Load Split (FINAL)

- Phase 4: 782 → 135-dòng index + 7 groups + POST-GATE
- Step 4.9 `finalize-phase4.sh` GIỮ SPECIAL CASE (aggregation logic specific)
- Smoke test 51/51 PASS (7 categories — extra Check 7 Phase 4-specific PARALLEL Dispatch pattern)
- Cross-phase smoke tests: 254 checks PASS, 0 regression
- **Pattern T6 fully validated qua TOÀN BỘ 6 phase optimizable (1, 3, 4, 5, 6, 7)** — Phase 2 grandfathered (<300 dòng)
- **ROLLOUT-PLAN v10.15 COMPLETED**

---

## 7. Metrics Tổng Kết

### Context Reduction (Peak per phase invocation)

| Phase | v9.1 monolithic | v10.18 lazy-load | Saving |
|-------|------------------|---------------------|--------|
| Phase 1 | ~28K tokens | ~2.5K tokens | **-91%** |
| Phase 2 | ~8.4K | ~3K | **-65%** |
| Phase 3 | ~10.9K | ~2.5K | **-77%** |
| Phase 4 | ~15.7K | ~2.5K | **-84%** |
| Phase 5 | ~10.7K | ~2.5K | **-77%** |
| Phase 6 | ~10.8K | ~2.5K | **-77%** |
| Phase 7 | ~12K | ~2.5K | **-79%** |
| **Average per phase** | **~14K** | **~2.6K** | **-81%** |

### Test Coverage Evolution

| Version | Tests | Notes |
|---------|-------|-------|
| v6.0.0 | 507 | Stage A-N complete |
| v7.1.0 | +73 evals = ~580 | 28/28 findings closed |
| v8.2.2 | +49 E2E +7 = ~636 | Signals fix complete |
| v9.0.2 | 631 pytest | Coverage completion |
| v10.0.0 | (baseline) | Architectural redesign |
| v10.18.0 | 254 cross-phase smoke tests PASS, 0 regression | Pattern T6 fully validated |

### Lines of Code (SKILL.md)

| Version | SKILL.md lines | Notes |
|---------|----------------|-------|
| v6.0.0 | ~700 | Monolithic |
| v7.0.0 | ~500 | Pure orchestrator |
| v9.1.0 | ~700 | 11 dims added |
| v10.0.0 | ~350 | Lean routing hub |
| v10.18.0 | ~540 | Routing + optimization history in frontmatter |

---

## 8. Lessons Learned

### Lesson 1: Fantasy Completion (v9.0.0 incident)

v9.0.0 mark 38/38 DONE nhưng QD9/QD10 runtime dispatch fail.

**Root cause:** Thiếu integration test ở Phase 4 dispatch + hardcoded `QD[1-8]` regex 6 nơi không update khi thêm QD9/QD10.

**Fix:** v9.0.1 — 7 vị trí fix + 41 regression test + wave-gate runtime smoke (611 pytest pass).

**Quy tắc:** Khi thêm dimension mới → search-replace `QD\[?[0-9]+\]?` regex toàn skill + helper scripts. Smoke test bắt buộc cho dispatch logic.

### Lesson 2: Phase 4 Selective Archive (v10.18.0 fix)

Phase 4 dispatch 11 parallel lane agents. Wholesale archive khi phase `in_progress` → re-spawn ALL 11 = ~2.7h work lost + 11× quota waste.

**Bug subtle:** `finalize-phase4.sh` aggregate `signals_total` từ filesystem scan. Mất `lanes/QD*/` → return 0 → Phase 5 `setup-triage.sh` trigger E005 healthy path **INCORRECTLY** → SKIP Phase 6/7 → false PASS.

**Fix:** Selective archive — preserve `lanes/QD*/completed`, archive `failed/in_progress`.

**Quy tắc:** Bất kỳ phase nào có per-instance state (lanes, workloads) → resume PHẢI preserve completed instances.

### Lesson 3: Pattern T6 Lazy-Load Split

v10.14 split Phase 1 đầu tiên → giảm 83% peak context. Pattern lặp lại qua v10.16/v10.17/v10.18 cho Phase 3/5/6/7/4. Phase 2 grandfathered (<300 dòng).

**Quy tắc:** Phase >500 dòng → áp dụng T6 split. Phase <300 dòng → skip (overhead split không đáng).

### Lesson 4: CI-First with Graceful Degradation

CI PRE-GATE Na/Nb/Nc auto-detect không hỏi user → reduce friction. Lock held / index stale / tool absent → fallback Grep/Glob (zero regression).

**Quy tắc:** Mọi skill cần đọc/analyze code → áp dụng CORE-033 pattern.

### Lesson 5: Cross-Skill Artifact với Audit Chain

`fix-impact.json` schema versioned + sha256 audit_chain — 6 consumer skills validate ở PRE-GATE.

**Quy tắc:** Mọi cross-skill artifact PHẢI có `$schema` + `audit_chain.checksum_sha256` pre-finalize.

---

## 9. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [01-vision-principles.md](01-vision-principles.md) | Vision v2.0 |
| [03-architecture.md](03-architecture.md) | Architecture v10.x |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADRs cho v6 → v10 |
| `plans/wf-fix-bugs-v7-overhaul/` | v7 overhaul plan |
| `plans/wf-fix-bugs-v9*/` | v9.x plans |
| `plans/wf-fix-bugs-v10-redesign/` | v10 design doc |
| `plans/wf-fix-bugs-phase-rollout-v10.15/` | ROLLOUT-PLAN v10.15 cho Phase 3-7 |
| `CHANGELOG.md` | Phát hành lịch sử |
| `99-archive/wf-fix-bugs-design-v1.0/` | Design v1.0 đầy đủ |
