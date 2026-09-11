# 09 — Design Decisions (Locked v2.0)

> **Đọc trước:** [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md)
> **Đọc tiếp:** [07-tradeoffs-adr.md](07-tradeoffs-adr.md)
> **Trạng thái:** LOCKED v2.0 — kế thừa locks v1.0 (North Star + Q14-Q23) + bổ sung v10.x decisions
> **Ngày chốt v2.0:** 2026-05-16 (Eureka — ERK Transport)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/09-design-decisions.md](../../99-archive/wf-fix-bugs-design-v1.0/09-design-decisions.md) (locked v1.0)

> **Lý do có file này:** Các tài liệu 01-08 đưa ra nhiều alternatives + open questions. File này **đóng** chúng theo ưu tiên của người dùng, để implementation team có một nguồn chân lý duy nhất. Mọi thay đổi phải viết ADR mới override trong [07-tradeoffs-adr.md](07-tradeoffs-adr.md).

---

## 1. North Star (Bất Biến Qua v1.0 → v2.0)

Nguyên tắc do owner Eureka phát biểu (2026-04-20):

> **"Người dùng quan tâm nhất tới việc đảm bảo không có lỗi logic, nghiệp vụ, và các tính năng trên giao diện phải đảm bảo hoạt động 100%. Các vấn đề khác chọn giải pháp tốt nhưng không làm cồng kềnh thiết kế."**

Dịch thành design language (mở rộng cho 11 dims):

| Ưu tiên user | Dimension | Mức độ | Default profile |
|--------------|-----------|--------|------------------|
| Không lỗi **logic** | **QD1 Functional** | CORE | standard, deep, exhaustive |
| Không lỗi **nghiệp vụ** | **QD2 Business** | CORE | standard, deep, exhaustive |
| **UI hoạt động 100%** | **QD5 UX/A11y** | CORE | quick, standard, deep, exhaustive |
| Dữ liệu đúng (gắn nghiệp vụ) | **QD6 Data Integrity** | HIGH | deep, exhaustive |
| An toàn (auth/secret touch) | **QD3 Security** | MED | deep, exhaustive (trigger context) |
| Reliability (payment/auth) | **QD8 Observability** | MED-HIGH | deep, exhaustive (CDG-RELIABILITY-RISK trigger) |
| Browser runtime correctness | **QD9 Runtime Health** | HIGH (web UI) | deep, exhaustive (Playwright required) |
| Cross-module integrity | **QD10 Integration** | HIGH (multi-module) | deep, exhaustive |
| Hiệu năng | **QD4 Performance** | LOW | deep, exhaustive |
| Tương thích browser/mobile | **QD7 Compatibility** | LOW | deep, exhaustive |
| Missing business logic | **QD11 Completeness** | MED-HIGH (multi-module) | deep, exhaustive |

**Hệ quả:** Default profile `standard = [QD1, QD2, QD5]` (ADR-21 — LOCKED v1.0, vẫn áp dụng).

---

## 2. Priority-Driven Simplification Rules (Kế Thừa v1.0)

Khi gặp xung đột giữa *correctness* và *simplicity*, áp dụng theo thứ tự:

1. **Correctness wins** (CORE-023) — không giảm chất lượng kiểm tra logic/nghiệp vụ/UI để gọn thiết kế.
2. **Simplify non-core features** — cache, multi-session, concurrency tuning không phải core correctness → chọn default đơn giản, opt-in mở rộng.
3. **Default must be safe** — user chạy `/wf-fix-bugs` không flag, kết quả phải đảm bảo 3 chiều core.
4. **Defer complexity** — tính năng không thiết yếu cho v10.x dồn sang v11.

---

## 3. Locked Decisions v1.0 (Q14-Q23) — Vẫn Áp Dụng

### Q14 — Interactive Selection Gate (ISG): mặc định mở?

**Quyết định v1.0: YES.**
**Trạng thái v10.18.0:** Defer — hiện tại dùng ISG fast-path (hardcoded). Roadmap v11: interactive checkbox (cần CLI AskUserQuestion multi-select).

### Q15 — Workload Gate ngưỡng trigger?

**Quyết định v1.0: 1.5× profile budget — dead-zone <0.8×, soft zone 0.8-1.5×, hard zone ≥1.5×.**
**Trạng thái v10.18.0:** IMPLEMENTED tại Phase 3 Step 3.4 INLINE AskUserQuestion (CDG-11).

### Q16 — Partition Strategy Default?

**Quyết định v1.0: Sub-menu (theo module structure) là default.**
**Trạng thái v10.18.0:** IMPLEMENTED qua `plan-isg-partition.sh` (ADR-23 ISG-guided fallback priority-based).

### Q17 — Scan Cache: opt-in hay default on?

**Quyết định v1.0: v6.0 opt-in (`--use-cache`); v6.1 default on.**
**Trạng thái v10.18.0:** Hiện tại per-tool TTL cache (GitNexus 24h, Serena 24h) — không cần `--use-cache`. Git-shared cache defer v11.

### Q18 — Cache commit vào git: default on?

**Quyết định v1.0: NO (defer v6.1, manual user choice).**
**Trạng thái v10.18.0:** NO — cache nằm trong `.mc-data/work/_meta/code-intelligence.json` (gitignored).

### Q19 — Incremental mode `--since=<git-ref>`?

**Quyết định v1.0: YES — opt-in flag.**
**Trạng thái v10.18.0:** Implement qua Anti-Staleness Guard (R6 E013) thay vì `--since=` flag explicit. Roadmap v11: `--since=<git-ref>` cho diff-only scan.

### Q20 — Multi-session conflict resolution?

**Quyết định v1.0: Lock-based với heartbeat + auto-release sau 60min.**
**Trạng thái v10.18.0:** IMPLEMENTED v7.0 + hardening v10.2 (E090b BASE_URL CDG + Protocol 22 R/W lock).

### Q21 — Resume granularity?

**Quyết định v1.0: Phase-level (không step-level).**
**Trạng thái v10.18.0:** Phase-level + **group-level routing** trong phase `in_progress` (v10.18.0 lazy-load aware) + **Phase 4 per-lane** (selective archive).

### Q22 — `--explain` flag (preview plan không chạy)?

**Quyết định v1.0: YES — first-class UX feature.**
**Trạng thái v10.18.0:** Implement qua `--dry-run` flag (Phase 6 preview only). `--explain` defer v11.

### Q23 — `--auto` opt-in hay default?

**Quyết định v1.0: opt-in, không default.**
**Trạng thái v10.18.0:** OPT-IN — `--auto` chưa implement (defer v11 — cần intelligent diff analysis).

---

## 4. Locked Decisions v2.0 (Mới — v10.x)

Các quyết định mới chốt trong giai đoạn v6 → v10 evolution:

### Q24 — Pipeline 7-phase hay giữ 3-stage v6?

**Quyết định v10.0 (2026-05-13): 7-phase pipeline.**

| Lý do | Detail |
|-------|--------|
| Separation of concerns | Mỗi phase 1 responsibility rõ: Init/Scan/Plan/Find/Triage/Execute/Verify |
| POST-GATE per phase | Validate T1-T4 từng bước, không trộn lẫn |
| Lazy-load friendly | Mỗi phase 1 procedure file → split groups dễ |
| Cross-skill artifact | `fix-impact.json` (CORE-036) sinh ở Phase 7 cuối cùng |

### Q25 — Phase 4 PARALLEL bao nhiêu agent?

**Quyết định v10.0: Max 10 (harness limit CORE-025).**

Lane skill N=11 → 11th queue tự nhiên. Single-response parallel (tất cả Agent calls trong MỘT response duy nhất) — gửi riêng lẻ sẽ tuần tự.

### Q26 — Lane skill spawn `subagent_type`?

**Quyết định v10.0: `"claude"` only.**

Lý do: Chỉ `"claude"` có đủ MCP tools cho lane skill execute (Bash + Read + Write + Edit + Grep + Glob + GitNexus + Serena). Các subagent_type khác (developer/qa-lead/security/...) **thiếu MCP tools** → lane fail.

### Q27 — Model cho spawn?

**Quyết định v10.0: `"opus"`.**

Lý do v10.0: Sonnet hết quota → bắt buộc opus. Khi Sonnet có sẵn → vẫn dùng opus cho lane skills (chi tiết hơn).

> Tham chiếu memory `feedback_use_opus_for_subagents`: "Khi Sonnet hết quota, mọi Agent spawn phải set model='opus'."

### Q28 — finalize-phase4.sh / finalize-phase7.sh special case?

**Quyết định v10.18.0: GIỮ SPECIAL CASE, KHÔNG migrate sang shared `phase-finalize.sh`.**

Lý do:
- **Phase 4** finalize aggregate `signals_total` từ filesystem scan (3 streams × N lanes) + `lanes_completed/failed` từ `lane-status.json` + `probe_failures` từ log. Generic `phase-finalize.sh` chỉ hỗ trợ static `PHASE_TOP_FIELDS` merge.
- **Phase 7** finalize có 2 đặc thù: (1) pre-finalize `pipeline_status=DONE` ở Step 7.5 cho CORE-036 audit_chain integrity, (2) dual-write global trace `.mc-data/work/_trace/session-log.json` (CORE-026).

Pattern: Phase 5 + Phase 6 migrate được (Step 5.10 + 6.7). Phase 4 + 7 GIỮ riêng.

### Q29 — CDG INLINE hay delegate script?

**Quyết định v10.0: CDG INLINE (user-facing AskUserQuestion).**

Lý do: AskUserQuestion là **orchestrator tool** — không script được. Mọi CDG render INLINE trong procedure file:
- Phase 3 Step 3.4 CDG-11 Workload Gate
- Phase 4 Step 4.3 E090/E090b Browser CDG
- Phase 5 Step 5.4 CDG Critical Violations
- Phase 5 Step 5.7 CDG Pre-Execute
- Phase 5 Step 5.8 CDG Safety Blockers
- Phase 6 Step 6.3 CDG HIGH/CRITICAL Risk
- Phase 7 Step 7.3 CQG-2 CDG REJECT

### Q30 — Agent spawn INLINE hay delegate?

**Quyết định v10.0: INLINE orchestrator-side.**

Lý do: Agent tool calls là **orchestrator-side primitives** — script không gọi được Agent tool. Mọi Agent spawn INLINE:
- Phase 4 Step 4.5 N×Agent (lane dispatch, single-response parallel)
- Phase 5 Step 5.5 Agent (wf-fix-triage spawn)
- Phase 6 Step 6.4 Agent (wf-fix-execute spawn)

### Q31 — TodoWrite + Completion Display delegate?

**Quyết định v10.0: GIỮ orchestrator-side (UI tools).**

Lý do: TodoWrite + Completion Display là **orchestrator UI tools** — script không control được terminal output style. Phase 7 Step 7.7 + 7.8 GIỮ orchestrator-side.

### Q32 — Selective Archive cho Phase 4 resume?

**Quyết định v10.18.0: YES — preserve completed lanes.**

Lý do: Wholesale archive khi Phase 4 `in_progress` → re-spawn ALL 11 = ~2.7h work lost + 11× quota waste + **false E005 healthy** (signals_total=0 → skip Phase 6/7 → false PASS).

Implementation: R5 scan `lanes/QD*/lane-status.json` → `completed`/`skipped` preserve, `failed`/`in_progress`/`pending` archive to `lanes-partial-{ts}/`.

### Q33 — Group-level routing trong phase `in_progress`?

**Quyết định v10.18.0: YES — đọc POST-GATE.md §Resume Logic.**

Lý do: Lazy-load phase split (v10.14 → v10.18) cho phép load chỉ group(s) cần re-execute thay vì load lại từ Group A. Saving ~5 phút mỗi resume.

Quy tắc:
- Orchestrator KHÔNG hardcode group routing logic
- Luôn delegate sang `phase{N}-{name}/POST-GATE.md §Resume Logic`
- Mỗi phase POST-GATE.md OWNS resume logic (CORE-007)

### Q34 — Browser CDG E090/E090b moved từ Phase 1 → Phase 4?

**Quyết định v10.3: YES — CDG just-in-time.**

Lý do: E090 (Missing URL) + E090b (BASE_URL Conflict) chỉ relevant khi `PW_LANE_COUNT > 0`. Ở Phase 1 không biết PW_LANE_COUNT → hỏi user sớm = false friction.

Implementation: Phase 1 Step 1.16b giờ chỉ stub init empty `cdg-tokens.json`. Phase 4 Step 4.3 (Group B) check `PW_LANE_COUNT > 0` → render CDG INLINE.

### Q35 — CI PRE-GATE gộp Na/Nb/Nc?

**Quyết định v10.3: GỘP thành 1 wrapper script `ci-pregate.sh`.**

Lý do: 3 steps Na/Nb/Nc đều spawn bash, sequential → có thể gộp thành 1 atomic call. Reduce bash tool calls Phase 1 từ ~10 → ~7 (-30%).

Implementation: Steps 1.5, 1.6 delete; gọi `ci-pregate.sh` duy nhất.

### Q36 — Schema versioning bắt buộc?

**Quyết định v10.0: YES — mọi cross-skill artifact PHẢI có `$schema` versioned + `audit_chain.checksum_sha256`.**

Lý do: CORE-036 enforce. Schema hardening wave v10.11:
- `fix-execution-result-v2` (bump v1→v2 derive-from-fix-log)
- `phase4-summary-v1` (new cross-skill artifact)
- `coverage-report-v1` (new cross-skill artifact)
- `docs-sync-report-v2` (bump v1→v2 enrich audit_chain)
- `issue-registry-v2` (bump v1→v2 _schema_notes)
- `lane-agent-prompt-v10.2` (template version)

### Q37 — Phase 4 single-response parallel hay wave-based?

**Quyết định v10.18.0: Single-response parallel (KHÔNG split wave).**

Lý do:
- N=10 spawn trong 1 response → harness execute parallel (max 10)
- N=11 → 11th queue tự nhiên
- Playwright lane TỰ acquire writer-lock qua Protocol 22 → orchestrator KHÔNG cần wave coordinator
- Single-response = simpler orchestrator logic

### Q38 — Bug-dashboard.md version counter?

**Quyết định v10.11: YES — HTML comment markers.**

Format:
```html
<!-- bug-dashboard-version: 3 -->
<!-- last-writer: phase-5-9 -->
<!-- last-updated: 2026-05-16T08:30:00Z -->
**Version:** 3
```

Lý do: 4 writers (init-bug-dashboard, generate-phase5-reports, verify-execute-outputs, finalize-dashboard) bump N+1 mỗi lần update → CORE-025 concurrent-write conflict detect khi 2 phiên cùng sửa session.

### Q39 — Per-phase smoke test bắt buộc?

**Quyết định v10.14: YES — bắt buộc cho mọi phase split (T6).**

Smoke tests đã có:
- `phase1-routing-smoke-test.sh` (42 checks)
- `phase3-routing-smoke-test.sh` (35 checks)
- `phase4-routing-smoke-test.sh` (51 checks, 7 categories)
- `phase5-routing-smoke-test.sh` (42 checks, 5 categories)
- `phase6-routing-smoke-test.sh` (40 checks)
- `phase7-routing-smoke-test.sh` (44 checks, 6 categories)

**Tổng 254 checks PASS, 0 regression.**

Verify:
1. Index file exists + đủ N group references
2. Mỗi group file exists + có Next pointer đúng
3. Routing chain unbroken: A → B → ... → POST-GATE
4. Mỗi group có Input/Output contract sections
5. Helper scripts exist + executable

### Q40 — Pattern T6 Lazy-Load Split: phase nào áp dụng?

**Quyết định v10.18.0: Phase 1, 3, 4, 5, 6, 7. Phase 2 grandfathered.**

Lý do:
- Phase 1 (1106 dòng) → split
- Phase 2 (5 steps, <300 dòng) → SKIP T6 (overhead split không đáng)
- Phase 3 (515 dòng) → split
- Phase 4 (782 dòng) → split (FINAL, v10.18.0)
- Phase 5 (648 dòng) → split
- Phase 6 (619 dòng) → split
- Phase 7 (657 dòng) → split

**Pattern T6 fully validated qua TOÀN BỘ 6 phase optimizable.** ROLLOUT-PLAN v10.15 COMPLETED.

---

## 5. Safety Defaults Non-Negotiable (ADR-22, Kế Thừa v1.0)

> Bảo vệ correctness ở mọi tổ hợp flag. KHÔNG ai (kể cả `--force`) có thể bypass.

| # | Rule | Enforcement |
|---|------|-------------|
| 1 | Profile ≥ standard PHẢI có ít nhất 1 trong QD1/QD2/QD5 | Phase 3 fail E030 |
| 2 | Verification Ripple always on (cross-module impact) | QD10 auto-add khi sửa shared code |
| 3 | QD3 (Security) KHÔNG dùng scan cache | `wf-fix-security` skip cache layer |
| 4 | CDG render khi phát hiện secret | Phase 4 INLINE AskUserQuestion |
| 5 | POST-GATE T1-T4 mọi phase | Không skip POST-GATE bằng flag |
| 6 | SAFE-UPDATE impl_status (CORE-008) | `wf-fix-execute` enforce no-downgrade |
| 7 (v10.x) | Cross-skill artifact PHẢI có audit_chain sha256 | Phase 7 POST-GATE T5 fail nếu missing |
| 8 (v10.x) | Phase 4 selective archive PRESERVE completed lanes | R5 Phase 4 SPECIAL CASE logic |
| 9 (v10.x) | CDG INLINE (KHÔNG delegate script) | Architectural rule |
| 10 (v10.x) | Agent spawn INLINE single-response (Phase 4 PARALLEL) | CORE-025 |

---

## 6. Decision Log Tóm Tắt

| ID | Quyết định | Phiên bản | Trạng thái |
|----|------------|-----------|------------|
| Q14-Q23 | Locked v1.0 (ISG, Workload Gate, Partition, Cache, ...) | v6.0 | Phần lớn IMPLEMENTED, một số defer v11 |
| Q24 | 7-phase pipeline | v10.0 | IMPLEMENTED |
| Q25 | Max 10 PARALLEL agents | v10.0 | IMPLEMENTED (CORE-025) |
| Q26 | `subagent_type=claude` only | v10.0 | IMPLEMENTED |
| Q27 | `model=opus` | v10.0 | IMPLEMENTED |
| Q28 | finalize-phase4/7.sh GIỮ special case | v10.18 | IMPLEMENTED |
| Q29 | CDG INLINE | v10.0 | IMPLEMENTED |
| Q30 | Agent spawn INLINE | v10.0 | IMPLEMENTED |
| Q31 | TodoWrite + Completion Display orchestrator-side | v10.0 | IMPLEMENTED |
| Q32 | Phase 4 Selective Archive | v10.18 | IMPLEMENTED |
| Q33 | Group-level routing resume | v10.18 | IMPLEMENTED |
| Q34 | E090/E090b move Phase 1 → Phase 4 | v10.3 | IMPLEMENTED |
| Q35 | CI PRE-GATE gộp ci-pregate.sh | v10.3 | IMPLEMENTED |
| Q36 | Schema versioning + audit_chain | v10.0 | IMPLEMENTED |
| Q37 | Single-response parallel Phase 4 | v10.18 | IMPLEMENTED |
| Q38 | bug-dashboard version counter | v10.11 | IMPLEMENTED |
| Q39 | Per-phase smoke test bắt buộc | v10.14 | IMPLEMENTED (254 checks) |
| Q40 | Pattern T6 phase coverage (1/3/4/5/6/7, skip 2) | v10.18 | IMPLEMENTED — ROLLOUT-PLAN v10.15 COMPLETED |

---

## 7. Open Questions Defer v11

| ID | Câu hỏi | Workaround v10.18.0 | Roadmap v11 |
|----|---------|----------------------|--------------|
| OQ1 | Interactive ISG checkbox UI | ISG fast-path hardcoded | CLI multi-select widget |
| OQ2 | Git-shared scan cache | Per-tool TTL cache | Content-addressable + git-friendly artifact |
| OQ3 | `--explain` preview plan | `--dry-run` Phase 6 only | First-class `--explain` (Phase 3 preview) |
| OQ4 | `--auto` intelligent dim selection | Manual `--dims=` | Diff-aware auto-detect (auth touch → +QD3, schema touch → +QD6) |
| OQ5 | `--since=<git-ref>` diff-only scan | Anti-Staleness Guard E013 only | Incremental scan mode |
| OQ6 | Cross-host lock (network/cluster) | Local lock only | Distributed lock service |
| OQ7 | Phase 5 CORE-029 spot-check full | Sample 3 random issues | Full validation pass |
| OQ8 | Custom partition split (Plan D) | Sub-menu only | User-defined partition |

---

## 8. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [01-vision-principles.md](01-vision-principles.md) | Vision + 11 principles |
| [05-execution-profiles.md](05-execution-profiles.md) | Profile × dim selection (Q15, Q16, Q40) |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADRs đầy đủ |
| [99-archive/wf-fix-bugs-design-v1.0/09-design-decisions.md](../../99-archive/wf-fix-bugs-design-v1.0/09-design-decisions.md) | Locked v1.0 (Q14-Q23 nguyên bản) |
| `.claude/rules/00-core.md` | CORE-023-024-025 (Priority Order, Downstream Bound, Parallelization Safety) |
