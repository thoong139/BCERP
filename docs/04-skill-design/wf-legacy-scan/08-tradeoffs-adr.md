# 08 — Architecture Decision Records & Open Questions

> **Đọc trước:** [07-migration-plan.md](07-migration-plan.md)
> **Đọc tiếp:** [09-thresholds-justification.md](09-thresholds-justification.md), [10-vietnamese-keywords.md](10-vietnamese-keywords.md), quay lại [README.md](README.md) cho overview

---

## 1. ADR Index (17 ADRs — Design v2.1)

| ID | Quyết định | Status | Ngày |
|----|-----------|--------|------|
| ADR-LS01 | 6 Scan Layers thay 7 stages | ✅ Accepted | 2026-04-22 |
| ADR-LS02 | 4 Profiles (surface/standard/deep/exhaustive) | ✅ Accepted | 2026-04-22 |
| ADR-LS03 | IPS 2-phase — Python module `_shared/ips/` (v2.1 REVISED từ inline) | ✅ Accepted v2.1 | 2026-04-22 |
| ADR-LS04 | scan-state.json canonical — sub-skills migrate đọc trực tiếp (v2.1 REVISED — bỏ reverse-sync) | ✅ Accepted v2.1 | 2026-04-22 |
| ADR-LS05 | Session isolation runtime-only, output tại standard location | ✅ Accepted | 2026-04-22 |
| ADR-LS06 | Domain-Aware Agent Delegation — backward-compat lock standard = v4.1 | ✅ Accepted | 2026-04-22 |
| ADR-LS07 | Bash shared library `legacy-scan-common.sh` | ✅ Accepted | 2026-04-22 |
| ADR-LS08 | Strategy × Profile orthogonal + source-priority formal | ✅ Accepted | 2026-04-22 |
| ADR-LS09 | Configurable caps env vars + CLI override | ✅ Accepted | 2026-04-22 |
| ADR-LS10 | Incremental scan + Scan Cache (content-addressable, 2-tier) | ✅ Accepted | 2026-04-22 |
| ADR-LS11 | 4-Level Checkpoint (phase/layer/batch/intra-batch) | ✅ Accepted | 2026-04-22 |
| ADR-LS12 | Concurrency Controller 3-tier token bucket + per-agent timeout (v2.1 ADD timeout) | ✅ Accepted v2.1 | 2026-04-22 |
| ADR-LS13 | Workload Gate detect+WARN only (v2.1 REVISED — Partition Planner defer v5.1) | ✅ Accepted v2.1 | 2026-04-22 |
| ADR-LS14 | Impact Graph tại L6 (downstream ripple support) | ✅ Accepted | 2026-04-22 |
| **ADR-LS15** | **Vietnamese Keyword Pool cho IPS domain detection** | ✅ Accepted v2.1 | 2026-04-22 |
| **ADR-LS16** | **Thresholds justification table bắt buộc — 09-thresholds-justification.md** | ✅ Accepted v2.1 | 2026-04-22 |
| **ADR-LS17** | **Agent Output Spot-Check (CORE-029) integration tại L4/L5 POST-GATE** | ✅ Accepted v2.1 | 2026-04-22 |

---

## 2. ADR Details

### ADR-LS01: 6 Scan Layers thay 7 stages

**Context:** Pipeline hiện tại có 7 stages tuyến tính (0, 0A, 0.5, 1, 2, 3, 4). Mỗi stage có depth cố định, không adaptive.

**Decision:** Gom thành 6 Scan Layers (L1-L6). L1-L3 deterministic (bash, luôn full depth). L4-L5 intelligent (AI, adaptive depth). L6 synthesis (main context, luôn full).

**Alternatives considered:**
1. **Giữ 7 stages + thêm depth per stage** → Quá nhiều combinations (7 × 3 = 21 configs). Phức tạp.
2. **Gom thành 3 phases (Detect → Analyze → Synthesize)** → Quá coarse, mất granularity cho resume/checkpoint.
3. **Dimension-based (như wf-fix-bugs QD1-QD7)** → Không phù hợp vì wf-legacy-scan có "analysis layers" với dependency chain rõ, không phải "quality dimensions" độc lập.

**Consequences:**
- (+) Simpler mental model: 6 layers vs 7 stages
- (+) Depth control chỉ cần cho 2 layers (L4, L5)
- (+) Deterministic vs AI boundary rõ ràng
- (-) Phase numbering khác v4.1 → cần mapping doc
- (-) L4 surface cần implement heuristic grouping (new code)

---

### ADR-LS02: 4 Profiles

**Context:** wf-fix-bugs v6 thành công với 4 profiles. User quen với model này.

**Decision:** 4 profiles: surface (overview), standard (onboarding — = v4.1), deep (analysis), exhaustive (audit).

**Alternatives considered:**
1. **3 profiles (quick/standard/deep)** → Thiếu "audit" level cho divergence analysis.
2. **5 profiles** → Thêm "moderate" giữa standard và deep. Over-specify.
3. **2 profiles (quick/full)** → Quá coarse.

**Consequences:**
- (+) Consistent với wf-fix-bugs model
- (+) Clear use case mapping
- (+) surface profile cho "quick look" — use case quan trọng đang thiếu
- (+) Standard = v4.1 lock đảm bảo backward-compat
- (-) Exhaustive thêm divergence — có thể tốn thời gian

---

### ADR-LS03: IPS 2-Phase — Python Module `_shared/ips/` (v2.1 REVISED)

**Context:** wf-fix-bugs v6 có ISG Recommender như Python module (`_shared/isg/isg_recommender.py`) — có kiểm thử unit. Review v2.0 phát hiện: domain detection logic + VN keyword matching + multi-signal scoring + cross-domain penalty sẽ ~300-500 dòng; inline trong markdown khó test và khó maintain.

**Decision (v2.1 REVISED):** IPS là **Python module** tại `.claude/skills/workflow/_shared/ips/`, tái dùng pattern từ wf-fix-bugs ISG. Giữ 2-phase: phase A sau L2, phase B sau L3. Orchestrator gọi module qua helper script, nhận JSON output.

**Cấu trúc module:**
```
.claude/skills/workflow/_shared/ips/
├── __init__.py
├── ips_recommender.py          ← Main API: run_phase_a(), run_phase_b()
├── domain_scorer.py            ← Score domains từ signals (EN + VN)
├── vietnamese_keywords.py      ← Load + match VN keyword pool
├── workload_estimator.py       ← Estimate features + time
└── tests/
    ├── test_domain_scorer.py
    ├── test_vietnamese_keywords.py
    └── fixtures/
```

**Reasoning (updated v2.1):**
- Phase A: L2 aggregate data → recommend profile + initial domain hints
- Phase B: L3 file-level data → refine module routing + hotspots
- Python module có test unit → tăng reliability
- VN keyword pool + English pool cùng nằm trong module → tái dùng
- Consistent pattern với wf-fix-bugs v6 ISG → developer onboarding dễ

**Alternatives considered:**
1. **IPS inline trong SKILL.md** (v2.0 decision) — khó test, khó maintain khi pool ~500 dòng.
2. **IPS 1-phase** — không đủ data cho module routing → suboptimal.
3. **Skill riêng `/wf-legacy-ips`** — user không cần gọi trực tiếp; over-engineering.
4. **Bash-only domain detection** — Vietnamese diacritic normalization khó trong bash thuần.

**Consequences:**
- (+) Unit-testable domain scoring logic
- (+) VN + EN keyword pool chung 1 source of truth
- (+) Tái dùng pattern wf-fix-bugs v6 (developer đã quen)
- (+) Dễ extend thêm domain mới (sửa JSON pool, không sửa SKILL.md)
- (-) Thêm Python dependency (đã có từ wf-fix-bugs)
- (-) Bash scripts cần gọi Python (qua subprocess hoặc stdin/stdout JSON)

**v2.1 change driver:** Review feedback §3.3 — inline logic không đạt maintainability target cho VN support.

---

### ADR-LS04: scan-state.json Canonical — Sub-skill Migration trong Phase D (v2.1 REVISED)

**Context:** 3 state files (ledger.json + classify checkpoint + extract checkpoint) phức tạp cho resume routing. Sub-skills hiện tại READ và WRITE ledger.json. Làm sao migrate mà không break sub-skills và không tạo debt?

**Decision v2.0 (superseded):** scan-state canonical + reverse-sync ledger.json + deprecate Phase F+.

**Decision v2.1 (current):** `scan-state.json` canonical. **Sub-skills migrate đọc+ghi `scan-state.json` trực tiếp trong Phase D** — bỏ reverse-sync hoàn toàn. `ledger.json` chỉ được orchestrator generate **1 lần** tại POST Phase 4 synthesize (read-only legacy projection cho downstream skills cũ). **Zero race condition.**

**Migration protocol (v2.1):**
- Phase D bao gồm sub-skill procedure updates:
  - PRE-GATE: đọc `.mc-data/work/legacy-scan/sessions/{latest}/scan-state.json`
  - WRITE progress: update `scan-state.layers.L4` / `scan-state.layers.L5` qua helper `scan_state_reader.py`
- Helper function: atomic write + file-lock + state machine validation
- Orchestrator generate ledger.json (v4.1 schema) tại POST Phase 4 một lần — downstream consumers chỉ đọc, không ghi.

**Standalone sub-skill run:** Helper fallback — nếu không có active session (user chạy `/wf-legacy-classify` standalone sau khi đã scan xong), helper tự init session từ ledger.json v4.1 legacy → migrate vào scan-state.

**Alternatives considered:**
1. **Reverse-sync ledger ↔ scan-state** (v2.0 decision) — debt dài hạn, race condition khó test, deprecation không rõ ràng.
2. **Giữ 3 files + add wrapper** → Thêm complexity, không giải quyết root cause.
3. **ledger.json mở rộng** → Schema phức tạp hơn, không tách được canonical from derived.
4. **Sub-skill migration sang v5.1** → Kéo dài debt 1-2 tháng, risk regression cao vì 2 code path tồn tại.

**Consequences:**
- (+) Single source of truth (scan-state) — không có 2 state file
- (+) Zero race condition giữa sub-skills và orchestrator
- (+) Resume routing đọc 1 file (scan-state)
- (+) Session-based state (CORE-030) nhất quán
- (+) Rõ ràng: ledger.json = read-only legacy projection, scan-state = canonical write target
- (-) Sub-skill procedure files phải update trong Phase D (1 ngày work bổ sung)
- (-) Rủi ro: breaking standalone sub-skill run nếu helper fallback bug → mitigated bằng fallback test cases

**v2.1 change driver:** Review feedback §3.2 — reverse-sync tạo debt dài hạn với class lỗi race phức tạp. Migrate sớm đánh đổi 1 ngày effort để loại bỏ class lỗi.

---

### ADR-LS05: Session Isolation Runtime-Only

**Context:** wf-fix-bugs v6 đã chứng minh session isolation hiệu quả. wf-legacy-scan hiện tại ghi flat. Có nên isolate output data?

**Decision:** `sessions/{timestamp-id}/` cho **runtime state only** (scan-state, plan, summary, log, error, partial.json L3 checkpoints). **Output data** (inventory, classified, extracted) tại standard location cho backward-compat. **File-lock** ngăn concurrent corrupt.

**Key distinction:**
- Session directories: runtime state (scan-state.json, scan-plan.md, phase-summary.md, session-log.json, error-ledger.json, layers/L*/partial.json, cache/)
- Output data: tại `.mc-data/work/legacy-scan/` (backward compat for downstream skills)

**Alternatives considered:**
1. **Session cho tất cả data** → Breaking change cho downstream skills. Paths trong `00-core.md §4b` đều phải update. Sub-skills phải sửa.
2. **Không session isolation** → Mất audit trail; concurrent runs corrupt nhau.
3. **Session optional flag** → Thêm complexity, default behavior không clear.

**Consequences:**
- (+) Audit trail cho mỗi scan run
- (+) Re-scan không mất state cũ (vẫn override output, nhưng giữ session log)
- (+) Consistent với wf-fix-bugs v6 pattern
- (+) File-lock ngăn concurrent corrupt
- (-) Output data vẫn overwrite → user muốn backup phải `--backup-output` (optional flag, future)
- (-) Disk usage tăng (sessions accumulate). Mitigation: `--clean-sessions` flag + 30-day default retention

---

### ADR-LS06: Domain-Aware Agent Delegation — BACKWARD-COMPAT LOCK

**Context:** v4.1 sub-skills đã dùng specialized agents (code-reviewer cho classify, business-analyst + 7 domain experts cho extract), nhưng orchestrator delegate qua `general-purpose` wrapper mà không truyền domain hints hay depth config → domain experts không được route đúng. Avg confidence ~0.65.

**Decision:** Orchestrator truyền depth + domain hints xuống sub-skills qua agent prompt. **Standard profile = v4.1 behaviour LOCKED**: spawn `business-analyst` + 1 domain-expert per module (nếu match ≥0.6 — v2.1 raised từ 0.4 để giảm false positive, xem ADR-LS16 + 09-thresholds-justification.md). Deep profile = enriched (cross-validation pass). Surface profile = skip L5 hoàn toàn.

**Domain expert list (v4.1 BACKWARD-COMPAT):**
- **Core 7 (BÁM v4.1):** finance, procurement, sales, hr, ecommerce, operations, compliance
- **Optional 7 (v5.0 mở rộng — trigger khi IPS detect ≥0.75):** healthcare, logistics, manufacturing, retail, legal, insurance, education

**Alternatives considered:**
1. **Luôn dùng domain-expert** → Overhead cho simple projects.
2. **General-purpose + domain context injection** → Agent không có domain-specific knowledge.
3. **Lane-based (như wf-fix-bugs QD)** → Over-engineering cho scan use case.
4. **Replace 7 experts của v4.1 bằng 7 experts mới** (v1.0 design) → Breaking backward-compat, không acceptable.

**Consequences:**
- (+) Extraction quality cao hơn với domain expertise
- (+) Consistent với DEVKIT agent architecture (25 business agents)
- (+) Backward-compat guaranteed (standard = v4.1)
- (+) Fallback: business-analyst nếu không detect domain
- (-) Domain detection có thể sai → wrong expert → vẫn fallback business-analyst
- (-) More agent types to manage in prompts

**Key fix from v1.0 review (A1 + A2):** Bám danh sách v4.1 thay vì swap experts; standard profile **không giảm** capability.

---

### ADR-LS07: Bash Shared Library

**Context:** 4 scripts + ui-coverage-scan.sh chia sẻ ~500 dòng duplicated code.

**Decision:** `legacy-scan-common.sh` shared library. All scripts `source` it. Cross-platform (Windows Git Bash + WSL + Linux + macOS).

**Alternatives considered:**
1. **Python scripts thay bash** → Breaking change lớn. Bash đã work, chỉ cần improvement.
2. **Không refactor, chỉ fix bugs in-place** → Duplication remains, future bugs harder to fix.
3. **Monorepo script package** → Over-engineering cho utility scripts.

**Consequences:**
- (+) ~250 dòng UI code deduplication
- (+) Centralized helpers (json_escape, validate_json, atomic_write_json, cache_*)
- (+) Single source for exclude dirs, logging, caps
- (+) jq validation built-in (vs missing in v4.1)
- (+) Cache support shared
- (-) `source` command có subtle differences giữa bash versions
- (-) Testing cần verify `source` works on Windows Git Bash + WSL + Linux + macOS

---

### ADR-LS08: Strategy × Profile Orthogonal + Source-Priority Formal

**Context:** 7 strategies (FAST-TRACK, CODE-FIRST, ...) quyết định routing — phases nào chạy, source nào ưu tiên. Cần formal definition để tránh ambiguity.

**Decision:** Giữ nguyên S1-S7. Strategies và profiles là 2 trục độc lập:
- **Strategies:** "PHẢI chạy phases nào? Source nào ưu tiên?" (routing)
- **Profiles:** "ĐỘ SÂU mỗi phase?" (depth)

**Source-priority formal definition (fix B6):**
- `balanced`: L5 extraction xét cả code + docs equally
- `code-priority`: L5 ưu tiên code, docs validation. Modules chỉ docs → confidence -0.1
- `doc-priority`: L5 ưu tiên docs, code validation. Modules chỉ code → confidence -0.1
- `doc-first`: Giống doc-priority NHƯNG không trừ confidence cho code-only modules
- `diverge`: Bật divergence detection regardless of profile

**Strategy × source-priority mapping:**
- S1 FAST-TRACK → balanced
- S2 CODE-FIRST → code-priority
- S3 DOCS-BRAINSTORM → doc-priority
- S4 CODE-PLUS-DOCS → balanced
- S5 DIVERGENCE-RESOLVE → balanced + diverge
- S6 DOCS-PLUS-CODE → doc-first
- S7 NEAR-COMPLETE → delta mode (operational, not source-priority)

**S7 vs --incremental clarify (fix B8):**
- S7 (strategy) sets default delta behavior
- `--incremental` (operational flag) standalone, can combine with any strategy
- Combinations đầy đủ trong [05-profiles-ips.md §2.5](05-profiles-ips.md)

**Consequences:**
- (+) Không cần rewrite strategy logic
- (+) Two orthogonal axes = clear mental model
- (+) Source-priority formal → không ambiguity
- (-) Interaction matrix (7 × 4 × 6) cần documentation
- (-) Edge cases: documented thoroughly trong §2.5

---

### ADR-LS09: Configurable Caps

**Context:** Hardcoded `head -500`, `head -300`, `head -200` limits trong inventory script.

**Decision:** Environment variable overrides với defaults. CLI flag `--max-files=N` override.

**Env vars:**
- `LEGACY_SCAN_MAX_API` (default 500)
- `LEGACY_SCAN_MAX_SCREENS` (default 500)
- `LEGACY_SCAN_MAX_FILES` (default 200 for import analysis)
- `LEGACY_SCAN_MAX_IMPORTS` (default 20 per file)
- `LEGACY_SCAN_MAX_DOC_FILES` (default 300)
- `LEGACY_SCAN_STALE_DAYS` (default 180)
- `LEGACY_SCAN_CACHE_TTL` (default 14)

**Alternatives considered:**
1. **Không giới hạn** → Dự án rất lớn (10,000+ files) có thể OOM.
2. **Adaptive caps** (detect available memory) → Over-engineering.
3. **CLI flag only** (no env vars) → Verbose, harder to configure for CI.

**Consequences:**
- (+) User control cho large projects
- (+) Defaults safe cho most cases
- (+) Environment variables = simple, no flag explosion
- (-) Users không biết env vars tồn tại (need documentation)

---

### ADR-LS10: Incremental Scan + Scan Cache

**Context:** Re-scan hiện tại luôn chạy full pipeline. Nếu chỉ 10 files thay đổi, vẫn scan lại tất cả. Team collaboration (2 dev chia việc) không possible.

**Decision:** Staleness check → delta processing cho L3-L5. L1-L2 và L6 luôn re-run (nhanh). **Scan cache content-addressable**, 2-tier (session + project git-friendly).

**Cache invalidation rules:**
- File hash change
- Dependency closure hash change
- Probe version bump
- Probe config hash change
- TTL expire (default 14 days)
- `--no-cache` flag
- `--invalidate-cache=<pattern>`

**Cache tiers:**
- Session cache: `sessions/{id}/cache/` — gitignored, ephemeral
- Project cache: `.mc-data/cache/wf-legacy-scan/` — opt-in commit git via `--cache-publish`

**Alternatives considered:**
1. **Git-based incremental only** (`git diff`) → Chỉ work với git repos.
2. **Không cache** (just incremental) → Mất team collaboration benefit.
3. **Cache always commit git** → Privacy concern (code snippets in cache).

**Consequences:**
- (+) 50-80% time savings khi re-scan
- (+) Builds on existing staleness check
- (+) Team collaboration via git-friendly artifacts
- (+) Privacy guard (privacy_scope: secret never cached)
- (-) Delta merge logic cần careful implementation
- (-) Cache invalidation edge cases (renames detection)

---

### ADR-LS11: 4-Level Checkpoint

**Context:** v4.1 resume chỉ cấp phase. Crash giữa L4 batch 5/8 hoặc L5 module 12/20 → mất toàn bộ progress của unit đó. Dự án lớn cần chạy nhiều giờ → rủi ro cao mất công.

**Decision:** 4 levels checkpoint:
- **L0 Phase**: scan-state.last_completed (transition mỗi phase boundary)
- **L1 Layer**: scan-state.layers.<L>.status (in_progress/completed)
- **L2 Batch/Module**: batch_progress / module_progress (sau mỗi batch/module complete)
- **L3 Intra-batch**: layers/L*/partial.json (sau mỗi file/feature)

**"Never lose more than 1 unit" guarantee:**
- Checkpoint write throttle: minimum 5 giây giữa 2 writes (avoid I/O storm)
- Atomic write: write temp → fsync → rename
- Crash → mất tối đa 1 file / 1 feature

**Alternatives considered:**
1. **Phase-only checkpoint (current v4.1)** → Insufficient for large projects.
2. **Per-file checkpoint (no throttle)** → I/O storm, slowdown.
3. **Time-based checkpoint** (every N seconds) → Less precise, harder to resume.

**Consequences:**
- (+) Resume tin cậy cho dự án lớn
- (+) Mất tối đa 1 unit khi crash
- (-) Slight overhead per write (mitigated by throttle)
- (-) More complex resume routing (4 levels)

**Reused pattern:** wf-fix-bugs v6 R3 design (xem `docs/design/skills/wf-fix-bugs/08-user-scenarios-solutions.md §5`).

---

### ADR-LS12: Concurrency Controller 3-Tier + Per-Agent Timeout (v2.1 ADD timeout)

**Context:** Sub-skills tự quyết parallel, không có global cap. Rủi ro context overflow, OOM, agent slot exhaustion trên dự án lớn (>20 modules). Review v2.0 bổ sung: nếu 1 agent hang, cả pipeline block — Claude Agent spawn không có built-in timeout.

**Decision:** 3-tier token bucket controller + per-agent timeout:
- `global_max=8` (hard cap)
- `per_layer_max=3` (mỗi layer tối đa 3 parallel agent)
- `per_probe_max=4` (mỗi probe fanout tối đa 4)
- `reserved_for_synthesis=2` (luôn giữ 2 slot cho L6)
- **`per_agent_timeout=300s` default, `=600s` cho deep/exhaustive L5** (v2.1 NEW)

**Per-agent timeout behaviour:**
- Orchestrator start spawn → ghi timestamp vào `scan-state.layers.<L>.active_agents[]`.
- Mỗi 30s check: nếu agent chạy quá timeout → abort + retry với simplified scope (max 2x) → skip module/batch + WARN.
- Env vars: `LEGACY_SCAN_AGENT_TIMEOUT_SEC` (default 300), `LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC` (default 600).

**Spawn contract (CORE-025):**
- Parallel-safe declared
- Write scope tách biệt
- No read-after-write cross-agent
- Aggregator verify post-merge

**Alternatives considered:**
1. **No controller (current v4.1)** → OOM, context overflow on large projects.
2. **Single global cap only** → Doesn't prevent layer/probe imbalance.
3. **Adaptive based on system resources** → Over-engineering.
4. **No timeout** (v2.0 decision) — 1 hang agent block pipeline — không acceptable cho production.

**Consequences:**
- (+) Predictable resource usage
- (+) Safe spawn cho parallel agent
- (+) Reserved slots for synthesis ensure completion
- (+) Pipeline không hang vì 1 agent (v2.1 add)
- (-) Slight overhead (queue + token check + timeout watchdog)
- (-) Throughput cap có thể conservative for small projects

**Reused pattern:** wf-fix-bugs v6 R4 design + timeout watchdog từ v6 R4.2.

---

### ADR-LS13: Workload Gate Detect+WARN (v2.1 REVISED — Partition Planner defer v5.1)

**Context:** Dự án ERP lớn (>1,000 files, >30 modules) có thể vượt budget profile. v4.1 user phải tự đoán và chia. v5.0 cần auto-detect và đề xuất. Review v2.0 phát hiện: aggregate merge semantic cho multi-session chunk chưa rõ ràng (REQ-ID conflict, project-context.md merge) — cần benchmark trước khi lock contract.

**Decision v2.0 (superseded):** Workload Gate + Partition Planner + multi-session + aggregate step.

**Decision v2.1 (current):** v5.0 chỉ implement **Workload Gate detect + WARN**. Partition Planner + multi-session + aggregate defer sang v5.1.

**v5.0 scope:**
- IPS-B compute workload estimate (features, time, hotspots).
- Workload Gate trigger sau IPS-B theo thresholds §2.5 09-thresholds-justification.md.
- CDG (CORE-027) hiển thị WARN + 3 options:
  - `continue-as-is` → log WARN, tiếp tục execution.
  - `downgrade-profile` → apply profile thấp hơn (deep → standard, exhaustive → deep), tiếp tục.
  - `abort` → STOP + suggest reduce scope hoặc chờ v5.1.

**v5.1 roadmap (deferred):**
- Partition Planner sinh `fix-workload.json` với chunks độc lập.
- Multi-session execution: chunks chạy parallel terminals, file-lock coordination.
- Aggregate step merge chunks output với dedup strategy cho REQ-ID conflict.
- project-context.md merge strategy (section-wise union + dedup).
- Benchmark trên 3+ ERP fixtures.

**Trigger conditions (v5.0 — bám §2.5):**
- estimated_time > 1.5 × profile.time_budget_minutes
- total_features > 100
- largest_module_files > 40 (v2.1 lowered từ 50)
- modules_count > 30
- total_files > 1,000 AND profile ∈ {deep, exhaustive}

**Alternatives considered:**
1. **No workload gate (current v4.1)** → Users hit context overflow surprise.
2. **Full partition planner v5.0** (v2.0 decision) — aggregate semantic chưa rõ, risk bug cao.
3. **Auto-downgrade without user confirmation** → CDG violation.
4. **Partition only on explicit `--workload` flag** → Users not aware of feature.

**Consequences:**
- (+) Detect + WARN đủ để ngăn context overflow surprise cho v5.0
- (+) User control via CDG
- (+) Defer aggregate complexity → v5.0 stable hơn, v5.1 thiết kế đúng
- (+) Predictable release scope
- (-) Users cần manually reduce scope nếu không chọn downgrade-profile
- (-) ERP users phải chờ v5.1 cho multi-session — mitigation: downgrade-profile thường đủ cho 80% cases

**Reused pattern:** wf-fix-bugs v6 R2 design (partial — Gate only, không partition).

**v2.1 change driver:** Review feedback §3.1 + §3.8 — aggregate semantic chưa clear + cắt Phase F để giảm timeline risk.

---

### ADR-LS14: Impact Graph tại L6

**Context:** v4.1 chỉ tạo `dependency-graph.json` thô (import edges). Downstream skills (`/wf-verify-sync`, `/wf-fix-bugs` R5 ripple) cần richer graph với data flow + REQ cross-refs.

**Decision:** L6 build `impact-graph.json` với 6 relation types: code_import, data_dependency, event_subscription, api_call, req_cross_ref, entity_reference. Skip nếu `synthesis_mode=condensed` (surface profile).

**Schema:** xem [04-data-model.md §2.2](04-data-model.md).

**Consumers:**
- `/wf-verify-sync` — cross-module REQ-ID validation
- `/wf-fix-bugs` R5 ripple verification
- `/wf-design` (legacy flow) — gap analysis priority

**Alternatives considered:**
1. **Không impact graph** → Downstream verify/fix lacking cross-module info.
2. **Impact graph trong L1-L3** → Premature, không có classification yet.
3. **Skill riêng `/wf-build-impact-graph`** → Over-engineering, naturally fits L6 synthesis.

**Consequences:**
- (+) Enables downstream R5 ripple verification (wf-fix-bugs)
- (+) Improves verify-sync cross-module checks
- (+) Single graph for multiple consumers (no duplicate work)
- (-) L6 takes slightly longer
- (-) Graph build for very large projects (>5,000 modules) cần optimization

**Reused pattern:** wf-fix-bugs v6 R5 Impact Graph + Verification Ripple.

---

### ADR-LS15: Vietnamese Keyword Pool cho IPS (v2.1 NEW)

**Context:** Review v2.0 phát hiện: IPS v2.0 chỉ detect domain qua English keyword signals. Dự án Việt Nam dùng naming không dấu như `qlkh/` (quản lý khách hàng), `hoadon/` (hoá đơn), `qlns/` (quản lý nhân sự), `chamcong/`, `nhapkho/` → IPS miss hoàn toàn → fallback business-analyst only → mất lợi thế domain expert (confidence target 0.82 không đạt).

**Decision:** Thêm Vietnamese keyword pool tại `.claude/skills/workflow/wf-legacy-scan/_shared/ips/vietnamese-keywords.json`. IPS module tại `_shared/ips/` (ADR-LS03 revised) có `vietnamese_keywords.py` load + match pool. 14 domains × ~8 keywords = ~110 keywords.

**Normalization:** strip diacritics (NFD + combining marks) + lowercase + `đ → d` + strip separators `-_/.` để match consistent.

**Matching rules:**
- Exact match trong normalized form → weight đầy đủ.
- Substring match (keyword là prefix/suffix) → weight × 0.7.
- Multi-signal boost: ≥3 keyword cùng domain trong 1 module → +0.15.
- Cross-domain penalty: keyword xuất hiện trong ≥2 domain → weight × 0.6.
- Viết tắt 2-3 ký tự (`ns`, `kh`, `hd`, `bh`) match exact only.

**Alternatives considered:**
1. **Không support VN** (v2.0 decision) — 70% dự án Việt Nam miss domain → correctness degraded.
2. **Auto-translate VN → EN qua agent** — tốn tokens, unreliable cho viết tắt.
3. **Dùng VN BERT embeddings** — over-engineering cho v5.0, defer v5.1+.

**Consequences:**
- (+) Cover 14 domains tiếng Việt phổ biến
- (+) JSON pool dễ extend không cần code change
- (+) Phase I test trên 3 fixtures VN đo precision ≥80%, recall ≥70%
- (-) Maintenance burden cho keyword pool
- (-) Miss dialect/typo/camelCase tiếng Việt

**Chi tiết:** [10-vietnamese-keywords.md](10-vietnamese-keywords.md).

---

### ADR-LS16: Thresholds Justification Table Bắt Buộc (v2.1 NEW)

**Context:** Review v2.0 phát hiện 6 nhóm threshold được chốt cứng trong design v2.0 mà chưa có justification scientific/benchmark:
- Domain confidence ≥0.4 → route expert (quá thấp, rủi ro false positive)
- L3 drift tolerance ±5% (flat, không theo tier)
- Delta trigger >20% (arbitrary)
- Cache hit rate ≥60% (aspirational)
- Synthesis token caps (hardcoded)
- Concurrency caps (missing timeout)

**Decision:** Bắt buộc file `09-thresholds-justification.md` trong mọi sign-off Phase A. Mỗi threshold PHẢI có:
1. Giá trị v2.0 vs v2.1.
2. Căn cứ (v4.1 baseline / wf-fix-bugs v6 / fixture benchmark / "calibration-required").
3. Env var override name.
4. Impact analysis nếu thay đổi.

**Thay đổi chính v2.1:**
- Domain threshold 0.4 → 0.6 (fix false positive).
- Drift tolerance tiered: ±3% SMALL/MEDIUM, ±5% LARGE (thay flat 5%).
- Delta trigger 20% → 25%.
- Per-agent timeout 300s / 600s deep (NEW).
- CORE-029 spot-check integration (NEW — xem ADR-LS17).
- Synthesis truncation priority (NEW).

**Calibration Phase I:** 4 thresholds "calibration-required" sẽ tune qua E2E test trên 3 fixtures (small/medium/large):
- Cache hit rate 50% → 70%
- Drift tolerance SMALL/MEDIUM fine-tune
- Rename detection Levenshtein
- Per-agent timeout P99 buffer

**Alternatives considered:**
1. **Giữ thresholds v2.0 không justify** — review block. Đây là core correctness decisions.
2. **Defer justification sang Phase I** — quá muộn; một số threshold block implementation.

**Consequences:**
- (+) Decision traceable, reviewable
- (+) User có env var để override theo project
- (+) Phase I test plan rõ cho calibration
- (-) Maintenance burden — mỗi threshold change phải update bảng
- (-) Design doc tăng 1 file (~400 lines)

**Chi tiết:** [09-thresholds-justification.md](09-thresholds-justification.md).

---

### ADR-LS17: Agent Output Spot-Check (CORE-029) Integration (v2.1 NEW)

**Context:** Review v2.0 phát hiện design không đề cập CORE-029 (Agent Output Spot-Check) trong bindings. POST-GATE T1-T4 validate schema (file existence, JSON validity, coverage %, cross-ref) nhưng chưa có semantic sampling — agent có thể trả JSON đúng schema nhưng nội dung nonsense (TMP-ID format đúng nhưng description rỗng, source_files chứa path không tồn tại).

**Decision:** Tích hợp CORE-029 spot-check vào L4 và L5 POST-GATE:

**L4 batch spot-check:**
- Random sample 3 files/batch (nếu batch ≥ 30) hoặc 1 file/batch (nếu < 30).
- Check: (a) file path tồn tại trên disk; (b) module assignment match project structure; (c) category thuộc allowed enum; (d) confidence trong [0, 1].
- Fail → trigger auto-fix Protocol 2 (max 3 lần retry) → ESCALATE.

**L5 module spot-check:**
- Random sample 3 requirements/module (nếu ≥ 20) hoặc 1 req/module (nếu < 20).
- Check: (a) TMP-ID format đúng `TMP-REQ-{MODULE}-{NNN}`; (b) `source_files` non-empty và mọi path tồn tại; (c) confidence trong [0, 1]; (d) description ≥ 20 ký tự; (e) acceptance_criteria (nếu có) ≥ 1 item.
- Fail → Protocol 2 retry → ESCALATE.

**Alternatives considered:**
1. **Full content validation** — quá tốn context, không scale.
2. **Không spot-check** (v2.0) — vi phạm CORE-029, semantic errors leak downstream.
3. **Spot-check 100% files/reqs** — wasteful cho dự án lớn.

**Consequences:**
- (+) Catch semantic errors trước khi commit vào SSOT
- (+) Align với DEVKIT CORE-029
- (+) Statistical confidence cao (3 sample pass → 95%+ confidence cả batch đúng)
- (-) Tăng POST-GATE time ~10-20s/batch (mitigated bằng random sample)

**Reused pattern:** Protocol 2 auto-fix loop đã standardize trong DEVKIT.

---

## 3. Resolved Open Questions (từ v1.0 review)

### OQ-A: Surface profile — chạy L4 hay skip? ✅ RESOLVED

**Decision:** Chạy L4 surface với heuristic grouping (xem [02-scan-layers.md §4.4.1](02-scan-layers.md)).

**Reasoning:** Module map availability cho project-context.md → downstream brainstorm có module overview. Heuristic grouping đủ tốt cho overview, sai có thể fix bằng re-scan standard.

**Promoted to:** ADR-LS01 (6 layers definition).

---

### OQ-C: Session isolation scope? ✅ RESOLVED

**Decision:** Runtime-only — output data vẫn tại standard location.

**Reasoning:** Backward compat với downstream skills quan trọng hơn full isolation. Data comparison có thể bằng git diff trên `.mc-data/`.

**Promoted to:** ADR-LS05.

---

### OQ-D: Sub-skill refactor? ✅ RESOLVED

**Decision:** Keep wf-legacy-classify và wf-legacy-extract architecture as-is. Sub-skills nhận depth + domain context qua agent prompt từ orchestrator (additive change, không breaking).

**Reasoning:** Major refactor of sub-skills high risk + low benefit. Orchestrator-level changes đủ để truyền context.

**Promoted to:** ADR-LS06.

---

### OQ from v1.0 review (already addressed):

| Original OQ | v1.0 review status | v2.0 resolution |
|-------------|---------------------|-----------------|
| Domain expert list | A1 blocking | ADR-LS06 lock = v4.1 list + optional extensions |
| Standard backward-compat | A2 blocking | ADR-LS06 LOCKED + Phase D critical path |
| Ledger concurrent write | A3 blocking | ADR-LS04 + reverse-sync contract + file-lock |
| OQ-C redundancy | A4 minor | Removed; promoted to ADR-LS05 |
| synthesis_mode "full+" | B1 medium | ADR-LS01 + 02 §3 chốt 4 values |
| ADR-LS03 rationale | B2 medium | ADR-LS03 updated for 2-phase IPS |
| Checkpoint path | B3 medium | Fixed in PB-3 (01-vision-principles.md) |
| Templates new vs existing | B4 medium | 04-data-model.md §5 phân loại rõ |
| domain-hints.json consumers | B5 medium | 04-data-model.md §2.1 added |
| Source-priority formal | B6 medium | ADR-LS08 added formal definition |
| Exit criteria L3 T3 | B7 medium | 02-scan-layers.md §SL3 dùng tolerance ≥95% |
| S7 vs incremental | B8 medium | ADR-LS08 + 05-profiles-ips.md §2.5 clarify |

---

## 4. Remaining Open Questions (0 — ALL RESOLVED v2.1)

> **v2.1 update:** OQ-B, OQ-E, OQ-F đều đã resolve trong design v2.1.

### OQ-B: Domain hints detect — bash hay IPS? ✅ RESOLVED v2.1

**Question:** Domain hint detection nên chạy trong bash script (L1/L2) hay trong IPS (sau L2)?

**Option B1:** Trong bash (L2 assessment script)
- Pro: Domain hints available trước IPS → IPS dùng hints cho recommendation
- Pro: Bash đã scan files, chỉ thêm grep patterns
- Con: Thêm complexity vào bash script

**Option B2:** Trong IPS (inline logic sau L2)
- Pro: IPS có đầy đủ L1+L2 data
- Con: IPS phải grep files → tốn thêm I/O

**Recommendation:** B1 — trong bash. L2 script đã scan files, chỉ thêm grep patterns. IPS-A nhận domain-hints.json ready-made.

**v2.1 resolution:** B1 + Python enrichment. Bash `legacy-scan-assess.sh` gọi `detect_domain_hints()` (English) + `detect_domain_vn()` (Vietnamese via Python subprocess cho diacritic normalization). IPS-A Python module aggregate, scoring, multi-signal boost. Phase A không cần vote lại — locked in ADR-LS03 (revised) + ADR-LS15.

**Status:** ✅ RESOLVED.

---

### OQ-E: Pre-Scan Validation (L0)?

**Question:** Có thêm layer L0 (Pre-Scan Validation) để check project path, permissions, git status trước khi chạy L1?

**Option E1:** Thêm L0
- Pro: Fail fast, better error messages
- Con: Thêm phase, thêm time

**Option E2:** Không, keep validation trong Phase 0 init
- Pro: Simple, current approach works
- Con: Error messages less specific

**Recommendation:** E2 — giữ trong Phase 0 init. Không cần layer riêng.

**v2.1 resolution:** E2 locked. Phase 0 init thực hiện: (a) project path exists; (b) read/write permission; (c) git repo check (non-blocking); (d) disk space ≥ 100MB free. Fail → STOP với specific error message.

**Status:** ✅ RESOLVED.

---

### OQ-F: Scan cache project-level — opt-in hay opt-out?

**Question:** Scan cache project tier (`.mc-data/cache/wf-legacy-scan/`) có default opt-in (auto commit git) hay opt-out (user explicit `--cache-publish`)?

**Option F1:** Opt-in default (auto commit)
- Pro: Team collaboration ngay
- Con: Privacy concern (code snippets in cache might leak)
- Con: Git pollution

**Option F2:** Opt-out default (`--cache-publish` required)
- Pro: User explicit, safer
- Pro: Privacy guard
- Con: Extra step for team workflow

**Recommendation:** F2 — opt-out. User chạy `--cache-publish` để commit. Safer default cho privacy.

**v2.1 resolution:** F2 locked. Project cache opt-out default. User explicit `--cache-publish` commit git. Privacy scope check: nếu cache entry chứa secret pattern (password|token|api_key|private_key) → refuse publish + WARN.

**Status:** ✅ RESOLVED.

---

## 5. Decisions Log

| Ngày | Version | Action | Rationale |
|------|---------|--------|-----------|
| 2026-04-21 | v1.0 draft | Initial design (10 ADRs) | Based on analysis of v4.1 issues + wf-fix-bugs v6 patterns |
| 2026-04-22 | v1.0 review | 19 issues identified | Backward-compat critical issues found |
| 2026-04-22 | v2.0 draft | Redesign with 14 ADRs | Address all 19 issues; align with wf-fix-bugs v6 pattern; lock backward-compat |
| 2026-04-22 | v2.0 review | 10 issues identified (§3.1-3.10) | Reverse-sync debt, IPS maintainability, VN miss, thresholds unjustified, CORE-029 missing, timeline risk |
| 2026-04-22 | v2.1 draft | Redesign with 17 ADRs (+ 3: LS15/LS16/LS17) | Address all 10 v2.0 issues; loại bỏ reverse-sync debt; VN support; thresholds formal; CORE-029 integration; defer workload partition v5.1 |
| 2026-04-22 | v2.1 tech-review | **TECH-REVIEW PASSED** by AI reviewer (Claude Opus 4.7) — `implementation/checklists/A4-self-review-2026-04-22.md` | Static analysis: 17/17 ADRs coherent + 20/20 checklist tech-verified + 6 cross-doc consistency checks pass. Phase B unblocked technically. Human sign-off (§5.1) vẫn pending. |

**Sign-off pending:** Owner Eureka + DEVKIT core team (Phase A target — 2-3 ngày). Tech-review đã pass — xem row above.

### 5.1 Sign-off Sheet (pending signatures)

> **Populated by Phase A.4 (technical part) — empty rows chờ human signatures.**
> Khi meeting review xong, editor fill các cột `Signed date`, `Signature/Handle`, `Notes`.
> Tag `design-legacy-scan-v2.1-approved` được tạo sau khi bảng này có đủ 2 signatures.

| Role | Name | Scope of approval | Signed date | Signature/Handle | Notes |
|------|------|-------------------|-------------|------------------|-------|
| Owner / Sponsor | `<TBD>` | Full design v2.1 (17 ADRs, timeline, resource) | _(pending)_ | _(pending)_ | — |
| DEVKIT Core Lead | `<TBD>` | Technical design, backward-compat lock, contracts | _(pending)_ | _(pending)_ | — |
| Optional — Domain Expert Rep | `<TBD>` | VN keyword pool (10-vn-keywords.md), Core 7 + Optional 7 scope | _(optional)_ | _(optional)_ | Optional but recommended |
| Optional — QA Lead | `<TBD>` | Fixture strategy (A.3), backward-compat test plan, Phase D lock | _(optional)_ | _(optional)_ | Optional but recommended |

### 5.2 Sign-off Gate Procedure

1. Editor prep: gửi link design docs + section `§6 Checklist` cho reviewers trước meeting 1 ngày.
2. Review meeting: đi qua 20 items trong §6 checklist; record quyết định.
3. Sign-off: fill bảng §5.1 với Signed date + Signature.
4. Post-meeting: editor cập nhật `§5 Decisions Log` thêm 1 row `v2.1 APPROVED — <ngày> — <reviewers>`.
5. Create tag:
   ```bash
   git tag -a design-legacy-scan-v2.1-approved \
     -m "Design v2.1 approved by Owner + DEVKIT core team on $(date +%Y-%m-%d)"
   git push origin design-legacy-scan-v2.1-approved
   ```
6. Update `MIGRATION-PROGRESS.md` — Phase A.4 ⬜ → ✅.

### 5.3 Revision Triggers (post-signoff)

Sau khi approve, bất kỳ thay đổi nào sau đây cần re-signoff:

- Bump ADR version (VD ADR-LS04 v2.1 → v2.2).
- Add/remove ADR.
- Change backward-compat contract (standard profile output parity).
- Change Core 7 / Optional 7 domain list.
- Timeline delta >20% (VD 32 ngày → >38 ngày).

Thay đổi nhỏ (wording, typo fix, link update) không cần re-signoff nhưng phải commit riêng với prefix `docs(design):` để traceable.

---

## 6. Checklist Trước Khi Implement (Phase A → B handoff — v2.1)

Trước khi bắt đầu Phase B implementation, confirm:

- [ ] Tất cả ADR-LS01 đến ADR-LS17 đã review + accept
- [ ] OQ-B, OQ-E, OQ-F đã resolve (locked in v2.1)
- [ ] `00-core.md §4b` impact đã assess (chỉ additions, không breaking)
- [ ] wf-legacy-classify/extract compatibility đã verify
- [ ] **Sub-skill migration (Phase D) — procedure update scope agreed**
- [ ] Bash shared library design đã review
- [ ] **IPS Python module `_shared/ips/` structure đã agree**
- [ ] **Standard profile = v4.1 backward-compat lock confirmed**
- [ ] Domain expert list (Core 7 v4.1 + Optional 7 extensions) confirmed
- [ ] Concurrency controller defaults agreed (8/3/4 + timeout 300/600)
- [ ] Workload Gate trigger thresholds agreed (v5.0 detect+WARN only)
- [ ] Cache TTL + privacy_scope defaults agreed
- [ ] **Thresholds justification table (09-thresholds-justification.md) reviewed — đặc biệt: domain 0.4→0.6, drift tiered, delta 20%→25%, per-agent timeout**
- [ ] **Vietnamese keyword pool (10-vietnamese-keywords.md) reviewed — 14 domains cover use cases chính**
- [ ] **CORE-029 spot-check integration (ADR-LS17) reviewed**
- [ ] Timeline 23-32 ngày + resource allocation confirmed
- [ ] Workload Partitioning defer v5.1 agreed (v5.0 chỉ Gate+WARN)
- [ ] Rollback strategy reviewed per phase
- [ ] Risk register reviewed + mitigations approved (v2.1 eliminates reverse-sync risk)
- [ ] Success criteria measurable + agreed

---

## 7. Comparison — v1.0 → v2.0 → v2.1 (delta)

| Aspect | v1.0 | v2.0 | v2.1 |
|--------|------|------|------|
| ADR count | 10 | 14 | **17** (+3: LS15/LS16/LS17) |
| Open questions | 5 | 3 | **0** (OQ-B/E/F locked in 09/10) |
| Backward-compat lock | ❌ Standard reduced capability | ✅ Standard = v4.1 lock | ✅ Unchanged |
| Domain experts | ❌ Replaced 7 v4.1 with 4 new + 3 keep | ✅ Bám v4.1 + add 7 optional | ✅ Unchanged |
| State management | ⚠️ scan-state replace ledger (breaking) | ⚠️ scan-state canonical + reverse-sync (debt) | ✅ **scan-state canonical + sub-skill migration Phase D** (no debt) |
| Checkpoint levels | 1 (phase) | 4 (phase/layer/batch/intra-batch) | ✅ Unchanged |
| Concurrency control | ❌ Ad-hoc | ✅ 3-tier token bucket | ✅ **+ per-agent timeout 300s/600s** |
| Workload partitioning | ❌ Manual | ✅ Workload Gate + Partition Planner | ⚠️ **Gate+WARN only; Partition defer v5.1** |
| Impact graph | ❌ Only dependency-graph | ✅ Rich impact-graph for downstream R5 | ✅ Unchanged |
| Scan cache | ❌ None | ✅ Content-addressable 2-tier | ✅ Unchanged (calibration Phase I) |
| IPS implementation | N/A | Inline logic in SKILL.md | ✅ **Python module `_shared/ips/`** |
| Vietnamese keyword support | ❌ None | ❌ English only | ✅ **VN keyword pool (14 domains × ~8 kw)** |
| Thresholds justification | ❌ None | ⚠️ Some thresholds unjustified | ✅ **Formal table `09-thresholds-justification.md`** |
| Agent Output Spot-Check (CORE-029) | ❌ | ❌ | ✅ **L4/L5 POST-GATE integration** |
| Pattern alignment with wf-fix-bugs v6 | Partial | ✅ Full | ✅ Full + ISG module pattern |
| Issues fixed from review | N/A | 19/19 ✅ | 19/19 + 10 v2.0 review issues ✅ |
| Timeline sequential | — | 22-34 ngày | 23-32 ngày (net neutral) |

**v2.1 drivers:**
1. Review §3.2 — Reverse-sync debt → sub-skill migration Phase D (ADR-LS04 revised, ADR-LS15 for VN).
2. Review §3.3 — IPS inline maintainability → Python module (ADR-LS03 revised).
3. Review §3.5 — Thresholds unjustified → formal table (ADR-LS16).
4. Review §3.6 — VN dự án miss domain → keyword pool (ADR-LS15).
5. Review §3.7 — CORE-029 missing → spot-check (ADR-LS17).
6. Review §3.1 + §3.8 — Workload partition risk → defer v5.1 (ADR-LS13 revised).
7. Review §3.10 — Agent hang risk → per-agent timeout (ADR-LS12 revised).
