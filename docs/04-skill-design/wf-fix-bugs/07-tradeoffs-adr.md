# 07 — Tradeoffs & Architecture Decision Records (v2.0)

> **Đọc trước:** [09-design-decisions.md](09-design-decisions.md)
> **Quay về index:** [README.md](README.md)
> **Trạng thái:** v2.0 · Kế thừa ADR-01 → ADR-24 (v1.0) + bổ sung ADR-25 → ADR-40 (v7→v10 evolution)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/07-tradeoffs-adr.md](../../99-archive/wf-fix-bugs-design-v1.0/07-tradeoffs-adr.md) (ADR-01 → ADR-24)

Tài liệu này ghi lại **các quyết định kiến trúc lớn** (ADR), **lý do chọn** phương án này thay vì phương án khác, và **câu hỏi mở** còn lại. Đây là bộ nhớ tổ chức — người implement phase sau đọc để hiểu WHY.

---

## 0. Format

Mỗi ADR có cấu trúc:

```
ADR-NN — Tiêu đề
Status:    accepted | proposed | superseded | deprecated
Phiên bản: Khi nào quyết định
Context:   Vì sao phải quyết định
Decision:  Quyết định cụ thể
Alternatives: Các phương án đã xem xét
Consequences: Tích cực + tiêu cực
Followups: Hành động kèm theo
```

---

## Phần I: Kế Thừa từ v1.0 (ADR-01 → ADR-24)

### ADR-01 — Dimension là primary axis thay vì Layer

**Status:** accepted (v6.0, vẫn áp dụng v10.x)
**Phiên bản:** v6.0 (2026-04-20)

**Context:** Pipeline v5.1 chia discovery theo **5 Layer** (L1 Feature Completeness → L5 ERP Integration). Layer mix lẫn nhiều loại bug. Plan v1.1 thêm 12 bug category cho thấy cần axis mới để lane hoá.

**Decision:** Chia discovery theo **Quality Dimension** — 7 QD orthogonal (Functional, Business, Security, Performance, UX/A11y, Data Integrity, Compatibility). Mở rộng v9.1 thành **11 QD** (thêm Observability + Runtime Health + Integration + Business Completeness).

**Consequences:** + plug-able + user chạy 1 dim độc lập + severity aggregation MAX-across-dim. - Cần Signal Bus.

---

### ADR-02 — Signal Bus là utility module, không phải skill

**Status:** accepted (v6.0). **v10.x:** Signal Bus tích hợp vào `wf-fix-triage` Phase 5 (`aggregate-and-spot-check.sh` + `process-integrity-check.sh`).

---

### ADR-03 — Shared Services 4 thành phần (Triage/Planner/Fixer/Verifier) thay `/wf-fix-execute` monolith

**Status:** accepted (v6.0). **v10.x:** Triage = `wf-fix-triage` (Phase 5), Fixer + Verifier gộp vào `wf-fix-execute` (Phase 6). Planner trở thành `plan-isg-partition.sh` + `route-and-write.sh` (Phase 3).

---

### ADR-04 — Issue schema v2 extend v1 (không breaking)

**Status:** accepted (v6.0). **v10.x:** `issue-registry-v2` enrich `_schema_notes` (v10.11). Vẫn backward compat.

---

### ADR-05 — Max 3 lane song song mặc định

**Status:** superseded by ADR-25 (v10.0).
**Lý do superseded:** v10.0 nâng lên **max 10** (harness limit CORE-025) sau khi validate parallel safety. ADR-25 chi tiết.

---

### ADR-06 — Skill name convention `wf-fix-<slug>`

**Status:** accepted (v6.0). **v10.x:** 11 lane skills (`wf-fix-functional/business/security/performance/ux-a11y/data/compat/observability/runtime-health/integration/business-completeness`).

---

### ADR-07 — Registry role NONE cho tất cả lane; chỉ Fixer SAFE-UPDATE `impl_status`

**Status:** accepted (v6.0, áp dụng v10.x). `wf-fix-bugs` = orchestrator, `registry_scope.fields_owned = []`, `write_role = "NONE"`. `wf-fix-execute` (Phase 6) handle registry write.

---

### ADR-08 — 4 profiles (quick/standard/deep/exhaustive)

**Status:** accepted (v6.0, vẫn áp dụng v10.x).

---

### ADR-09 — Evidence bắt buộc cho mọi Signal (≥1 non-empty field)

**Status:** accepted (v6.0, áp dụng v10.x). Phase 7 CQG-2 enforce.

---

### ADR-10 — CORE-028 phase-summary hai cấp (lane technical + orchestrator human)

**Status:** accepted (v6.0). **v10.x:** Mỗi phase có Phase{N}-report.md (tiếng Việt ≤15 dòng, cho non-specialist). Orchestrator Phase 7 generate orchestrator-summary.md (tiếng Việt ≤40 dòng) + phase-summary.md (gộp head 8 dòng × 7 phase).

---

### ADR-11 — LEGACY_MODE không đổi profile/dim selection, chỉ đổi probe behavior

**Status:** accepted (v6.0, áp dụng v10.x). CORE-021 detect qua `project-context.md >500 bytes`. CORE-022 enforce qua `legacy-decisions.json`.

---

### ADR-12 — `--explain` là first-class UX feature

**Status:** deferred to v11 (v10.x). Workaround: `--dry-run` Phase 6 only.

---

### ADR-13 — `--auto` opt-in, không default

**Status:** deferred to v11 (chưa implement v10.x).

---

### ADR-14 → ADR-20 — Operational ADRs (ISG, Workload Gate, 4-level checkpoint, Concurrency, Impact Graph, Scan Cache, Incremental)

**Status:** Implemented variants v10.x:
- **ADR-14 ISG** → ISG fast-path (v10.12) + interactive defer v11
- **ADR-15 Workload Gate** → CDG-11 Phase 3 (v10.0)
- **ADR-16 4-level checkpoint** → Phase-level + group-level + per-lane (Phase 4 selective archive v10.18)
- **ADR-17 Concurrency** → CORE-025 max 10 + Protocol 22 R/W lock
- **ADR-18 Impact Graph** → GitNexus impact() Phase 6 + QD10 cross-module lane
- **ADR-19 Scan Cache** → Per-tool TTL cache (GitNexus 24h, Serena 24h)
- **ADR-20 Incremental mode** → Anti-Staleness Guard E013

---

### ADR-21 ★ Default profile shift `standard = [QD1, QD2, QD5]`

**Status:** accepted (v6.0, vẫn áp dụng v10.x).
**Lý do:** Ưu tiên North Star (logic + nghiệp vụ + UI). QD3 chạy khi context có auth/crypto touch hoặc `--only=security` hoặc profile `deep`/`exhaustive`.

---

### ADR-22 ★ Safety Defaults non-negotiable

**Status:** accepted (v6.0). **v10.x:** Mở rộng từ 6 rules → 10 rules (xem [09-design-decisions.md §5](09-design-decisions.md)).

---

### ADR-23 — Partition Planner: ISG-guided vs priority-based

**Status:** accepted (v6.0, implemented v10.5 `plan-isg-partition.sh`). Ưu tiên ISG recommendation, fallback priority-based (QD1+QD2+QD5 trước).

---

### ADR-24 — AggregationStats v2 schema

**Status:** accepted (v6.0). **v10.x:** Implement qua `phase4-summary-v1` schema + `coverage-report-v1` schema (v10.10 + v10.11).

---

## Phần II: Mới Bổ Sung (ADR-25 → ADR-40)

### ADR-25 — 7-Phase Pipeline thay vì 4-Stage v6

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
v6.0 pipeline 4 stages (Compose → Dispatch → Aggregate → Triage-Fix-Verify) trộn nhiều responsibility. POST-GATE T1-T4 không rõ ranh giới. SKILL.md ~700 dòng monolithic. Trên ERP lớn (EUREKA-2026), pipeline trigger `/compact` thường xuyên do context overflow.

**Decision:**
Pipeline **7-phase** rõ ràng: Init → Scan → Plan → Find Bugs → Triage → Execute → Verify. Mỗi phase 1 responsibility + POST-GATE T1-T4 + Phase{N}-report.md tiếng Việt ≤15 dòng (CORE-028).

**Alternatives:**
- Alt A: Giữ 4-stage, slim SKILL.md → vẫn không tách rõ Init/Scan/Plan
- Alt B: 10-stage finer-grained → over-engineered, mỗi stage <5 steps
- Alt C: 7-phase với reusable shared trace scripts → CHOSEN

**Consequences:**
+ POST-GATE T1-T4 rõ ràng per phase
+ Phase-level resume granularity
+ Cross-skill artifact ở Phase 7 cuối
+ Phase numbering match memory model user (Phase 1 = bắt đầu)
- Cần migrate v6 → v10 (1 lần work)

**Followups:**
- ADR-30 (Lazy-load procedures) — split mỗi phase
- ADR-35 (Agent prompt 8 sections)

---

### ADR-26 — QD8 Observability & Reliability lane

**Status:** accepted
**Phiên bản:** v8.2.0 (2026-05-09)

**Context:**
Production incident — payment service không có retry + timeout → flaky failures trong giờ cao điểm. QD3 (Security) không cover reliability. QD4 (Performance) chỉ đo perf, không đo resilience.

**Decision:**
QD8 lane mới với 7 probes: retry/circuit-breaker, timeout, log coverage, metrics, health-check, trace propagation, alert rules. Owner: sre + devops. CDG-RELIABILITY-RISK trigger trên `payment/auth` modules.

**Consequences:**
+ Cover blindspot reliability quan trọng
+ KHÔNG dùng scan cache (security-sensitive, no false-pass)
- Thêm 1 lane skill cần maintain

---

### ADR-27 — QD9 Runtime Health Verification (Playwright-heavy)

**Status:** accepted
**Phiên bản:** v9.0.x (2026-05-10)

**Context:**
Bug chỉ thấy qua browser runtime — console errors, network failures, uncaught exceptions, broken auth flows. Static analysis (QD1/QD3) không catch.

**Decision:**
QD9 lane Playwright-heavy: 7 probes (3 core Wave 1 + 4 deep Wave 1.5). SKIP rules: `interface_type=api-only`, `--no-browser`, `profile=quick`. CDG E090 (Missing URL) + E090b (BASE_URL conflict).

**Consequences:**
+ Phát hiện runtime bugs không thấy bằng static
+ 3 Playwright modes (headless/visible/mobile)
- Tốn thời gian runtime (~5-15 phút/lane)
- Multi-session conflict cần E090b CDG

**Followups:**
- ADR-37 (Playwright 3 modes)
- ADR-38 (Multi-session safety)

---

### ADR-28 — QD10 Cross-Module Integration lane

**Status:** accepted
**Phiên bản:** v9.0.x (2026-05-10)

**Context:**
Bug do orphan FK, API contract drift, cross-module reference broken — single-module probe không thấy. Cross-module integrity quan trọng cho ERP.

**Decision:**
QD10 lane: 9 probes (cross-module reference drift, API contract violation, event handler coverage, orphan FK, multi-platform entity sync, cache staleness, state machine errors, business flow violations, auth matrix violations). Owner: architect + data-engineer + domain experts.

**Consequences:**
+ Cover cross-module blindspot
+ Tích hợp tốt với GitNexus impact() Phase 6
- SKIP single module project, `profile=quick`

---

### ADR-29 — QD11 Business Completeness (3-pass LLM)

**Status:** accepted
**Phiên bản:** v9.1.0 (2026-05-10)

**Context:**
Missing business logic phát hiện qua LLM analysis — pattern A có ở module X nhưng thiếu ở module Y với cùng vai trò. Dev mới chưa thấy được.

**Decision:**
QD11 lane LLM-heavy: 3-pass analysis (cross-module pattern, domain heuristic, registry gap). 11 signal types. Enhancement suggestions qua CDG gate (user ACCEPT/REJECT).

**Consequences:**
+ Phát hiện gaps không thấy bằng probe truyền thống
+ Enhancement workflow cho user control
- Tốn LLM tokens (~10K-40K/lane tùy profile)
- SKIP single module, api-only, `profile=quick`

---

### ADR-30 — Lazy-Load Procedures (CORE-032)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
SKILL.md v9.1 ~700 dòng monolithic. ERP lớn trigger `/compact`. Cần lean routing hub + logic chi tiết tách riêng.

**Decision:**
SKILL.md **lean routing hub ≤500 dòng** (chỉ Overview, Arguments, Phase Routing Map, Output Files, Error Quick Lookup). Logic chi tiết trong `procedures/phase{N}-{name}.md` index + `procedures/phase{N}-{name}/X-{group}.md` group sub-files. Orchestrator load on-demand.

**Pattern T6 (Optimization Playbook v10.15):**
- Phase >500 dòng → split (Phase 1, 3, 4, 5, 6, 7)
- Phase <300 dòng → grandfathered (Phase 2)
- Per-group context ~500-1400 tokens (vs ~6-15K monolithic = -85%)

**Consequences:**
+ Peak context per phase invocation -87% (~19K → ~2.5K)
+ Mỗi group có Input/Output contract rõ
+ Resume group-level routing
- Cần smoke test mỗi phase (T8)
- Mỗi group file <160 dòng — discipline khi viết

**Followups:**
- ADR-39 (Optimization Playbook T1-T10)

---

### ADR-31 — CI-First with Graceful Degradation (CORE-033)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
GitNexus + Serena có sẵn nhưng chưa được tận dụng. Mỗi skill self-detect → inconsistent.

**Decision:**
CI PRE-GATE **3-step (Na/Nb/Nc)** chạy ở Phase 1 Init:
- Na: `ci-detect.sh` → `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`
- Nb: `ci-freshness-check.sh` → ok/light/strong/severe
- Nc: `ci-inject-context.sh` → `$CI_CONTEXT` cho spawned agents

**Graceful degradation:** Lock held → fallback Grep/Glob. KHÔNG hỏi user.

**Consequences:**
+ Zero-config — user không cần làm gì
+ Per-tool TTL cache giảm spawn overhead
+ Graceful fallback đảm bảo zero regression
- Cần Protocol 20 documentation + canonical scripts

---

### ADR-32 — Namespaced Error Codes (CORE-034)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
Error codes ad-hoc trong v9.x → khó tra cứu, dễ collision khi thêm phase mới.

**Decision:**
**Namespace convention E001-E109** qua 10 ranges:
- E001-E009 → Pipeline/session/lock (shared)
- E010-E019 → Phase 1, E020-E029 → Phase 2, ...
- E090-E099 → CDG User-Facing Gates
- E100-E109 → Recommendations

**Auto-fix budget:** Max 3 retries/phase. Budget hết → ESCALATE AskUserQuestion.

**Consequences:**
+ Tra cứu dễ (E040-E049 = Phase 4 ngay lập tức)
+ Auto-fix budget enforce anti-loop
+ error-ledger.json APPEND-only (CORE-026 output-only)

---

### ADR-33 — Phase Output Organization (CORE-035)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
v9.x outputs trải khắp `$SESSION_DIR/` flat → khó navigate khi debug.

**Decision:**
**Session subdirectories** `phase{N}-{name}/` per phase + **Phase{N}-report.md** tiếng Việt ≤15 dòng (CORE-028) per phase + **Atomic Write Pattern** cho mọi JSON state file.

**SESSION_ID format:** `YYYY-MM-DD-{scope}-{slug}-{NN}` (vd: `2026-05-16-module-payment-flow-03`)

**Consequences:**
+ Easy navigate khi debug
+ Phase report cho người không chuyên
+ Atomic write tránh corrupt khi crash

---

### ADR-34 — Cross-Skill Artifact Contract (CORE-036)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
v9.x cross-skill artifact (issue-registry.json) thiếu audit chain. Consumer skills không validate được schema version.

**Decision:**
**Cross-skill artifact PHẢI có:**
- `$schema` versioned (vd: `fix-impact-v1`, `phase4-summary-v1`, `coverage-report-v1`)
- `audit_chain.checksum_sha256` (sha256 64-char pre-finalize)
- `audit_chain.source_file`, `generated_by`, `generated_at`

**Consumer skills validate ở PRE-GATE** (T1 exists → T2 schema → T3 audit_chain).

**Consequences:**
+ Audit trail cho compliance
+ Schema version compat enforce
+ Consumer skills không drift schema

---

### ADR-35 — Agent Prompt Templates 8 Sections (CORE-037)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
v9.x agent prompts free-form → inconsistent + missing context (CI, Playwright, output).

**Decision:**
Mọi agent prompt PHẢI có 8 sections:
1. Role declaration
2. Task instruction
3. Session context
4. CI context injection
5. Playwright context (nếu applicable)
6. Output contract
7. Ownership rules
8. Completion criteria

Spawn rules: `subagent_type="claude"`, `model="opus"`, max 10 concurrent, 1 file = 1 writer.

**Consequences:**
+ Predictable agent behavior
+ CI/Playwright context inject consistent
+ Lane agent output validate được POST-GATE

---

### ADR-36 — Context Budget Management (CORE-038)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
ERP lớn trigger `/compact` giữa phase → mất state, không resume được clean.

**Decision:**
**Tiered context budget:**
- <65% → bình thường
- 65-80% → chuẩn bị checkpoint (lưu state files)
- 80-90% → STOP sau phase hiện tại → hướng dẫn `--resume`
- >90% → **FORCE STOP E009**

Phase 4 monitor mỗi 30s qua `monitor-lanes.sh`. Phase 7 check trước Step 7.5 (generate 4 reports).

**Consequences:**
+ Tránh context overflow giữa phase
+ Resume clean qua checkpoint
- Cần discipline check budget mỗi phase

---

### ADR-37 — Playwright 3 Modes (headless/visible/mobile)

**Status:** accepted
**Phiên bản:** v10.0 (2026-05-13)

**Context:**
v9.x chỉ headless mode. User cần visible mode để debug + mobile device emulation cho responsive test.

**Decision:**
3 Playwright modes:
- **Headless** (default) — CI, pre-commit, batch run
- **Visible** (`--show-browser`) — Debug, user observation, demo
- **Mobile** (`--mobile`) — Device emulation (iPhone 14 390×844, Pixel 7 412×915, iPad Pro 1024×1366). Auto-sets `--show-browser`.

**Serialization:** Lane có Playwright TỰ acquire writer-lock `playwright` qua Protocol 22 `global-rw-lock.sh`. Orchestrator KHÔNG split wave.

**Consequences:**
+ Debug-friendly với visible mode
+ Responsive test với mobile emulation
+ Cross-session safe qua Protocol 22 lock
- Cần tích hợp device profiles (iPhone/Pixel/iPad)

---

### ADR-38 — Multi-Session Safety (Protocol 22 + E090b)

**Status:** accepted
**Phiên bản:** v10.2 (2026-05-14)

**Context:**
v7.0 introduced session isolation nhưng 2 phiên cùng BASE_URL chia sẻ browser state → flaky.

**Decision:**
**Protocol 22 cross-session R/W lock:**
- Reader-lock `source` (multiple readers OK)
- Writer-lock `playwright` (1 writer at a time)
- Writer-lock `BE`/`FE`/`DB` (1 writer at a time)

**E090b BASE_URL CDG** (Phase 4 Step 4.3):
- Detect peer session cùng URL
- AskUserQuestion: Tiếp tục risk / Đợi peer / Cancel

**Escape hatch:** `MCV3_PW_ALLOW_SHARED_URL=1` (CI/CD).

**Hardening v10.2:** `findFreePort()` retry tự động (max 50 tries).

**Consequences:**
+ N phiên parallel an toàn cho module/system khác nhau
+ E090b block conflict scenarios
- Cần Protocol 22 documentation + canonical scripts

---

### ADR-39 — Optimization Playbook T1-T10

**Status:** accepted
**Phiên bản:** v10.15 (2026-05-16)

**Context:**
Optimization waves v10.3 → v10.14 áp dụng nhiều kỹ thuật ad-hoc. Cần document hóa để reuse cho phase khác và skill khác.

**Decision:**
**10 kỹ thuật canonical T1-T10:**
- T1 Parallel Wave Dispatchers
- T2 Fast-Path Bash Bypass
- T3 Caching for Idempotent Validations
- T4 Heavy Inline Bash Extraction
- T5 Shared Protocols Split
- T6 Phase Lazy-Load Split
- T7 Group Banners + Execution Flow Map
- T8 Smoke Test for Routing Chain
- T9 Cross-Platform Defensive Scripts
- T10 Versioned Schemas with Audit Trail

**Apply order:** T9+T10 foundation → T4 extract → T1 parallelize → T2 bypass → T3 cache → T7 banners → T6 split → T5 shared refs → T8 verify.

**Consequences:**
+ Reusable cho skill khác (wf-legacy-scan v5.0, wf-cmi v2.0 dùng tương tự)
+ Metrics đo lường (-87% peak context per phase)
- Cần discipline khi viết phase mới (apply tuần tự)

---

### ADR-40 — Phase 4 Selective Archive (Preserve Completed Lanes)

**Status:** accepted
**Phiên bản:** v10.18 (2026-05-16)

**Context:**
Phase 4 dispatch 11 parallel lane agents — mỗi lane ~15 phút work + 1 model quota. Resume khi `in_progress` → wholesale archive = re-spawn ALL 11 = ~2.7h work lost + 11× quota waste.

**Bug subtle:** `finalize-phase4.sh` aggregate `signals_total` từ filesystem scan. Mất `lanes/QD*/` → return 0 → Phase 5 setup-triage.sh trigger E005 healthy path **INCORRECTLY** → SKIP Phase 6/7 → false PASS (bug không fix nhưng pipeline mark DONE).

**Decision:**
**Selective archive logic** (R5 Phase 4 SPECIAL CASE):
- Scan `lanes/QD*/lane-status.json`
- `completed`/`skipped` → PRESERVE (Phase 4 POST-GATE Resume Logic skip)
- `failed`/`in_progress`/`pending`/invalid → ARCHIVE to `lanes-partial-{ts}/`
- Top-level files (`Phase4-report.md`, `phase4-summary.json`, `cdg-tokens.json`) → KHÔNG touch (regenerated)

Phase 4 POST-GATE Resume Logic re-dispatch CHỈ pending lanes.

**Alternatives:**
- Alt A: Wholesale archive → mất completed lanes (cost prohibitive)
- Alt B: Per-lane checkpoint state file → over-engineer
- Alt C: Selective archive với lane-status.json → CHOSEN

**Consequences:**
+ Preserve completed lanes (saving ~2.7h × N lanes preserved)
+ Tránh false E005 healthy path
- Cần special-case logic trong resume-status.md R5
- Top-level files regenerate sau resume

---

## 3. Open Questions Defer v11

Xem [09-design-decisions.md §7](09-design-decisions.md) cho danh sách 8 OQ defer v11.

---

## 4. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [09-design-decisions.md](09-design-decisions.md) | Q14-Q40 locked decisions |
| [01-vision-principles.md](01-vision-principles.md) | 11 design principles |
| [02-quality-dimensions.md](02-quality-dimensions.md) | 11 QDs canonical |
| [03-architecture.md](03-architecture.md) | Architecture chi tiết |
| [06-evolution-history.md](06-evolution-history.md) | Timeline v5 → v10 |
| `.claude/rules/00-core.md` | CORE-032 → CORE-039 |
