# 08 — User Scenarios & Operational Design (v2.0)

> **Đọc trước:** [06-evolution-history.md](06-evolution-history.md)
> **Đọc tiếp:** [09-design-decisions.md](09-design-decisions.md)
> **Trạng thái:** v2.0 · Phản ánh skill `wf-fix-bugs v10.18.0` · Mở rộng R1-R6 + S7-S13 + scenarios v10.x mới
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/08-user-scenarios-solutions.md](../../99-archive/wf-fix-bugs-design-v1.0/08-user-scenarios-solutions.md) (6 R + 7 S scenarios v6.0)

Tài liệu này trả lời câu hỏi: **"Khi một người dùng thật sự chạy `/wf-fix-bugs` cho một ERP module 20-30 menu, hoặc N dev chia nhau chạy rồi đồng bộ qua git, skill phải cư xử như thế nào?"**

---

## 1. Tóm Tắt 6 Yêu Cầu Gốc (R1-R6) + Trạng Thái v10.18.0

| # | Yêu cầu | v6.0 design | v10.18.0 implementation |
|---|---------|--------------|---------------------------|
| **R1** | Người dùng chọn QD trước khi chạy | ISG interactive | ISG **fast-path** (phase1-isg-fastpath.sh, ~5ms vs Python 500ms) — v11 sẽ làm interactive |
| **R2** | Module lớn — tự phát hiện job lớn + chia chunk + N phiên parallel | Workload Gate + Partition Planner | **Workload Gate CDG-11** Phase 3 + **Multi-session safety Protocol 22** (v10.2) |
| **R3** | `--resume` bất cứ lúc nào | 4-level checkpoint | **Resume lazy-load aware** (v10.18.0) — group-level routing + **Phase 4 Selective Archive** |
| **R4** | Song song hoá tối đa | Lane parallel + intra-lane probe parallel | **Phase 4 PARALLEL ≤10 lane agents** (single-response, CORE-025) + **Wave 1 + Wave 4 parallel** trong Phase 1 |
| **R5** | Cross-module impact verify | Impact Graph + Verification Ripple | **QD10 Cross-Module Integration** lane (v9.0.x) + **GitNexus impact()** Phase 6 |
| **R6** | Tái sử dụng kết quả phiên trước (git-shared cache) | Scan cache content-addressable | **Defer v11** (ADR-Q17: cache opt-in v6.0, auto-on v6.1, git-shared v11) — hiện tại có per-tool TTL cache (GitNexus 24h, Serena 24h) |

---

## 2. 7 Scenario Bổ Sung (S7-S13) + Trạng Thái

| # | Scenario | v6.0 design | v10.18.0 implementation |
|---|----------|--------------|---------------------------|
| **S7** | Crash/power loss giữa chừng | 4-level checkpoint | Lock heartbeat (auto-release sau 60min) + R5 partial archive + R10 group-level routing |
| **S8** | Progress visibility + ETA | Status table | `/wf-fix-bugs --status` (resume-status.md S1-S7) — Display header + phase table + CI tools + metrics + next action |
| **S9** | Token/time budget burn alert | Budget guard | **Context budget tier (CORE-038)** — <65/65-80/80-90/>90% E009 |
| **S10** | Scope drift khi codebase thay đổi giữa session | Staleness check | **R6 Anti-Staleness Guard (E013)** — git diff vs CHECKPOINT_COMMIT, >30% files changed → AskUserQuestion |
| **S11** | Conflict khi 2 dev chạy cùng module cùng lúc | Lock | **R7 Lock check PID-aware** (kill -0) + same-host vs different-host paths + E031 conflict |
| **S12** | Partial trust của kết quả legacy | Trust marker | LEGACY_MODE detect (CORE-021 — project-context.md >500 bytes) + legacy-decisions.json (CORE-022) |
| **S13** | Audit trail cho compliance | Log | **fix-impact.json audit_chain sha256** (CORE-036) + `cdg-tokens.json` decision persist + `fix-log.json` per-action |

---

## 3. R1 — Interactive QD Selection (v11 Roadmap, v10.18.0 Fast-Path)

### Hiện tại (v10.18.0)

Khi user chạy `/wf-fix-bugs` không kèm flag dim:
- **ISG fast-path** (`phase1-isg-fastpath.sh`) hardcoded lookup theo profile
- `quick` → `[QD1, QD5]`
- `standard` → `[QD1, QD2, QD5]`
- `deep` → 8 dims
- `exhaustive` → 11 dims

Bash spawn ~5ms vs Python ISG ~200-500ms cold start.

Escape hatch: `MCV3_FIX_BUGS_FORCE_ISG=1` → bypass fast-path, dùng real Python ISG analyzer.

### v11 Roadmap (Interactive ISG)

```
┌──────────────────────────────────────────────────────────────────────┐
│  /wf-fix-bugs — Chọn chiều chất lượng cần kiểm tra                   │
│                                                                      │
│  Scope phát hiện: module=finance, features=27, files_changed=14      │
│  Profile đề xuất: standard (≈15-20 phút)                             │
│                                                                      │
│  [x] QD1 Functional   — spec vs behavior              🟢 RECOMMEND   │
│  [x] QD2 Business     — domain rules (finance)        🟢 RECOMMEND   │
│  [ ] QD3 Security     — auth, injection, secrets      🟡 khuyến nghị │
│  [ ] QD4 Performance  — CWV, query, bundle            ⚪ tuỳ chọn   │
│  [x] QD5 UX/A11y      — WCAG, UX heuristics           🟢 RECOMMEND   │
│  [ ] QD6 Data         — validation, integrity         🟡 khuyến nghị │
│  [ ] QD7 Compat       — browser, responsive, i18n     ⚪ tuỳ chọn   │
│  [ ] QD8 Observability — retry/timeout/logs           🟡 khuyến nghị │
│  [ ] QD9 Runtime Health — browser runtime             ⚪ tuỳ chọn   │
│  [ ] QD10 Integration  — cross-module                 ⚪ tuỳ chọn   │
│  [ ] QD11 Completeness — missing business logic       ⚪ tuỳ chọn   │
│                                                                      │
│  Lý do recommend:                                                    │
│   • QD1+QD2+QD5 = default standard (North Star)                      │
│   • QD3 → git diff có sửa file auth/* trong 7 ngày qua               │
│   • QD6 → module `finance` nhạy với dữ liệu                          │
│   • QD8 → module `payment` cần observability (CDG-RELIABILITY-RISK)  │
│                                                                      │
│  [Enter]=xác nhận  [a]=tích tất cả  [r]=chỉ recommend                │
│  [p]=đổi profile   [s]=skip (dùng default)  [q]=huỷ                  │
└──────────────────────────────────────────────────────────────────────┘
```

Defer v11 vì hiện tại CLI parser `AskUserQuestion` chưa support multi-select checkbox. Workaround: dùng `--dims=` explicit.

---

## 4. R2 — Large ERP Workload + Multi-Session Parallel

### 4.1 Workload Gate CDG-11 (Phase 3 Step 3.4)

Tự phát hiện job lớn (ERP module 20-30 menu, 100+ features) → propose chia chunk.

```
Workload Gate — Job nặng phát hiện

Profile: standard (budget 15-20 phút)
Estimated: 47 phút (3.1× budget)
Dimensions: QD1, QD2, QD5
Scope: all (52 modules)

Options:
  1) Chia thành 4 chunks (mỗi chunk ~12 phút) — recommend
     - Chunk 1: modules/finance + payment + invoice (13 modules)
     - Chunk 2: modules/sales + crm + marketing (15 modules)
     - Chunk 3: modules/hr + payroll + recruitment (10 modules)
     - Chunk 4: modules/erp-core + admin + reporting (14 modules)
     → Tạo 4 sessions riêng, mỗi session 1 chunk
     → User dispatch parallel hoặc sequential

  2) Downgrade profile sang quick (5 phút, QD1+QD5 only)
  3) Continue full (47 phút)
  4) Cancel
```

### 4.2 Multi-Session Parallel Execution

User chọn Plan A → orchestrator tạo 4 `SESSION_ID` riêng:
- `2026-05-16-module-chunk-1-01`
- `2026-05-16-module-chunk-2-02`
- `2026-05-16-module-chunk-3-03`
- `2026-05-16-module-chunk-4-04`

User dispatch 4 lệnh:
```bash
/wf-fix-bugs --scope=module --name=chunk-1 --session=2026-05-16-module-chunk-1-01 &
/wf-fix-bugs --scope=module --name=chunk-2 --session=2026-05-16-module-chunk-2-02 &
/wf-fix-bugs --scope=module --name=chunk-3 --session=2026-05-16-module-chunk-3-03 &
/wf-fix-bugs --scope=module --name=chunk-4 --session=2026-05-16-module-chunk-4-04
```

### 4.3 Multi-Session Safety (Protocol 22)

| Scenario | An toàn? |
|----------|---------|
| 4 phiên, scope khác nhau (chunk 1/2/3/4) | ✅ Hoàn toàn isolated |
| 2 phiên, cùng scope, BASE_URL khác | ✅ Browser session-isolated |
| 2 phiên, cùng BASE_URL, multi-tenant DB | ⚠️ E090b CDG warning |
| 2 phiên, cùng BASE_URL, shared state | ❌ E090b BLOCK |

### 4.4 Aggregation Cross-Sessions

Sau khi 4 chunks DONE, user chạy:
```bash
/wf-verify-sync --from-fix-bugs --sessions=chunk-1,chunk-2,chunk-3,chunk-4
```

→ wf-verify-sync aggregate 4 `fix-impact.json` → tạo cross-session summary.

---

## 5. R3 — Resume Anywhere (Lazy-Load Aware)

### 5.1 Resume Strategy Matrix

| Pipeline state | `prompt` (default) | `auto` | `force-fresh` |
|-----------------|---------------------|--------|----------------|
| `DONE` | AskUser: Re-run / Cancel | Cancel silently | Tạo fresh session |
| `failed` | AskUser: Resume / Fresh / Cancel | **Resume** từ phase failed | Tạo fresh session |
| `in_progress` | Continue resume (R5+) | Continue resume | Tạo fresh session |

### 5.2 Resume Routing Table

| Last Completed | Resume Phase | Procedure File | Notes |
|----------------|--------------|----------------|-------|
| (none) | Phase 1 | `phase1-init.md` | Fresh start |
| Phase 1 | Phase 2 | `phase2-scan.md` | Scope scan |
| Phase 2 | Phase 3 | `phase3-plan.md` | Planning |
| Phase 3 | Phase 4 | `phase4-find-bugs.md` | Lane dispatch |
| Phase 4 | Phase 5 | `phase5-triage.md` | Triage (hoặc Phase 7 nếu N=0) |
| Phase 5 (E005) | Phase 7 | `phase7-verify.md` | Healthy skip |
| Phase 5 | Phase 6 | `phase6-execute.md` | Execute fixes |
| Phase 6 | Phase 7 | `phase7-verify.md` | Verify |

### 5.3 Group-Level Routing (v10.18.0 Lazy-Load Aware)

Khi resume phase với status='in_progress':
1. Load phase index router (~80-140 dòng)
2. Đọc `phase{N}-{name}/POST-GATE.md §Resume Logic` table
3. Apply theo state files hiện tại:

| Phase | Detection rule | Resume from |
|-------|----------------|-------------|
| **Phase 1** | `fix-status.json` initialized + lock acquired | Last completed group hint từ `fix-status.phase1.last_group` |
| **Phase 2** | KHÔNG split (grandfathered) | Re-run từ Step 2.1 |
| **Phase 3** | `dimension-plan.json` exists | Group D (Route + Write) hoặc E (Report) |
| **Phase 4** | **SPECIAL CASE per-lane** | Per-lane skip/redispatch (xem §5.4) |
| **Phase 5** | `issue-registry.json` exists nhưng phase5 chưa complete | Group C/D (CDG critical + Spawn triage) |
| **Phase 6** | `fix-report.md` exists nhưng phase6 chưa complete | Group E (validate + dashboard) |
| **Phase 7** | `orchestrator-summary.md`/`fix-impact.json`/`phase-summary.md`/`Phase7-report.md` exist | Group E/F (Reports/Finalize) |

### 5.4 Phase 4 Selective Archive (v10.18.0)

**Vấn đề:** Phase 4 dispatch 11 parallel lane agents — wholesale archive khi `in_progress` → re-spawn ALL 11 = ~2.7h work lost + 11× quota waste.

**Giải pháp:** Selective archive — scan `lanes/QD*/lane-status.json`:
- `completed`/`skipped` → PRESERVE
- `failed`/`in_progress`/`pending` → ARCHIVE to `lanes-partial-{ts}/`
- Top-level files (`Phase4-report.md`, `phase4-summary.json`, `cdg-tokens.json`) → KHÔNG touch (regenerated)

Phase 4 POST-GATE Resume Logic sau đó skip lanes completed, chỉ re-dispatch pending.

### 5.5 Anti-Staleness Guard (R6, E013)

Nếu >30% files changed since CHECKPOINT_COMMIT → AskUserQuestion:
1. Continue resume (RỦI RO — outdated scan)
2. Fresh run
3. Cancel

Denominator: files trong scope từ Phase 2 `code-inventory.json` (fallback: `git ls-files` nếu resume trước Phase 2).

### 5.6 Retry Budget Preservation (R9.5)

Đọc `error-ledger.json` → đếm entries `phase = $RESUME_PHASE`:
- Count ≥3 → **E001 STOP** "Retry budget exhausted across resume attempts"
- AskUserQuestion: Re-run phase (reset budget — RỦI RO loop) / Cancel

---

## 6. R4 — Parallelization (Phase 4 PARALLEL Max 10)

### 6.1 Phase 4 PARALLEL Dispatch (CORE-025)

Orchestrator spawn N×Agent trong **MỘT response duy nhất** (single-response parallel):

```
Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-functional ..."})
Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-business ..."})
Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-security ..."})
...
Agent({subagent_type: "claude", model: "opus", prompt: "wf-fix-integration ..."})  // 10th
// N=11: 11th queue tự nhiên (harness max 10)
```

**Constraints:**
- Max **10 concurrent** (harness limit)
- 1 file = 1 writer (Safe-Write per lane subdirectory)
- Playwright lane TỰ acquire writer-lock `playwright` qua Protocol 22 — KHÔNG split wave

### 6.2 Phase 1 Wave 1 + Wave 4 Parallel (v10.12.0)

**Wave 1:** Steps 1.5 (CI PRE-GATE) + 1.6 (Registry+Source+LEGACY) + 1.9 (Sub-skill paths) chạy parallel qua `phase1-wave1-dispatch.sh` (3 workers internal `&` + `wait`)

**Wave 4:** Steps 1.15 (init-session-state) + 1.16 (init-bug-dashboard) chạy parallel qua `phase1-init-bundle.sh` (2 workers internal)

Giảm Phase 1 từ ~30s baseline xuống ~25s + reduce 30% bash tool calls.

---

## 7. R5 — Cross-Module Impact (QD10 + GitNexus impact())

### 7.1 QD10 Lane (Phase 4)

9 probes phát hiện cross-module issues:
- P10.01 Cross-module reference drift
- P10.02 API contract violation
- P10.03 Event handler coverage
- P10.04 Orphan FK
- P10.05 Multi-platform entity sync
- P10.06 Cache staleness
- P10.07 State machine error
- P10.08 Business flow violation (LLM)
- P10.09 Auth matrix violation

SKIP: single module project, `profile=quick`.

### 7.2 GitNexus impact() ở Phase 6 (Verification Ripple)

Trước khi spawn `wf-fix-execute`:
```bash
# CI-ROUTE: GitNexus impact analysis
gitnexus_impact({target: "resetPassword", direction: "upstream"})
# → Returns: direct callers, affected processes, risk level (LOW/MED/HIGH/CRITICAL)
```

Nếu HIGH/CRITICAL → CDG render AskUserQuestion:
- Proceed (chấp nhận risk)
- Skip target (defer fix)
- Cancel pipeline

### 7.3 wf-cmi Cross-Module Integrity Orchestrator (v2.0)

Standalone skill `wf-cmi` (v2.0.0 — 2026-05-16) phục vụ system-wide integrity check (26 lanes CD1-CD40 với 3-wave dispatch). Có thể consume `fix-impact.json` từ wf-fix-bugs qua `--from-fix-bugs` opt-in.

---

## 8. R6 — Scan Cache (Defer v11)

### 8.1 Hiện tại (v10.18.0)

Per-tool TTL cache cho CI tools:
- GitNexus: 24h available / 4h absent
- Serena: 24h available / 1h absent
- Cache location: `.mc-data/work/_meta/code-intelligence.json`
- Lock-protected write (60s stale timeout)
- Lock held → fallback Grep (không block)

### 8.2 Content-Addressable Cache (Defer v11)

ADR-Q17 quyết định:
- **v6.0** opt-in (`--use-cache`)
- **v6.1** default on
- **v11** git-friendly (cache key by content hash, không phải file path) — cho phép 2 dev chia sẻ qua git

Hiện tại workaround: per-tool TTL cache đủ cho single-user scenario.

---

## 9. S7-S13 Operational Scenarios

### S7 — Crash/Power Loss

- Heartbeat daemon update `.lock.heartbeat` mỗi 30s
- Crash → stale lock detected sau 60min (configurable `MCV3_LOCK_STALE_MINUTES=30`)
- R7 auto-release → R5 partial archive → R10 group-level routing

### S8 — Progress Visibility

```bash
/wf-fix-bugs --status
```

Output:
```
Session: 2026-05-16-module-payment-flow-03
Scope: module/payment-flow
Profile: standard
Pipeline: in_progress
Started: 2026-05-16T08:00:00Z
Updated: 2026-05-16T08:32:15Z

| Phase | Name | Status | Duration | Notes |
|-------|------|--------|----------|-------|
| 1 | Init | completed | 2m | CI: GitNexus ✓, Serena ✓ |
| 2 | Scan | completed | 5m | web, 45 files, 3 modules |
| 3 | Plan | completed | 1m | 5 dims, 2 workloads |
| 4 | Find Bugs | in_progress | — | 3/5 lanes done |
| 5 | Triage | pending | — | — |
| 6 | Execute | pending | — | — |
| 7 | Verify | pending | — | — |

CI Tools: GitNexus available (index 2h old), Serena available (index 5min old)
Metrics: 47 signals found
Next: --resume để tiếp tục từ Phase 4 (2/5 lanes pending)
```

### S9 — Context Budget Burn Alert

CORE-038 tiered:
- 65-80% → Phase{N}-report.md ghi WARN "Chuẩn bị checkpoint"
- 80-90% → Lưu checkpoint, STOP sau phase hiện tại → `--resume` hint
- >90% → **FORCE STOP E009** (không advance)

Phase 4 monitor mỗi 30s qua `monitor-lanes.sh`.

### S10 — Scope Drift (Codebase thay đổi giữa session)

R6 Anti-Staleness Guard E013:
```bash
# CHECKPOINT_TIME từ session-log.json
# CHECKPOINT_COMMIT = git log -1 --before=$CHECKPOINT_TIME --format=%H
# CHANGED = git diff --name-only $CHECKPOINT_COMMIT HEAD + staged + unstaged
# TOTAL = files trong scope (Phase 2 code-inventory)
# PCT = CHANGED * 100 / TOTAL
# >30% → AskUserQuestion: Continue / Fresh / Cancel
```

### S11 — Conflict 2 Dev Cùng Module

R7 Lock Check PID-aware:
- **Same host** → `kill -0 $pid` → alive: E031 STOP "Session khác đang chạy"
- **Different host** → mtime fallback → age <60min: E031; age ≥60min: E008 auto-release

### S12 — Legacy Module Partial Trust

LEGACY_MODE detection (CORE-021):
```bash
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
```

legacy-decisions.json (CORE-022) declare modules với `action="DEPRECATE"` → loại khỏi mọi output downstream.

### S13 — Audit Trail Cho Compliance

`fix-impact.json` (CORE-036):
- `audit_chain.checksum_sha256` sha256 64-char
- `audit_chain.source_file` reference
- `audit_chain.generated_by` script name
- `audit_chain.generated_at` ISO-8601

`cdg-tokens.json` (CORE-027):
- Mỗi CDG decision có `user_decision` + `decided_at`
- Audit qua `wf-verify-sync --from-fix-bugs`

`fix-log.json`:
- Per-action log với `action:"registry_update"` cho registry writes

---

## 10. v10.x Operational Scenarios Mới

### S14 — N Phiên Parallel Trên CI/CD (`--resume-strategy=auto`)

CI/cron pipeline:
```bash
# Cron trigger mỗi giờ
/wf-fix-bugs --scope=system --name=erp-finance --profile=standard \
             --resume-strategy=auto --no-browser
```

- DONE → Cancel silently
- failed → Resume từ phase failed
- in_progress → Continue resume

Không block cron pipeline với AskUserQuestion.

### S15 — Multi-Session Cùng Module Cùng URL (E090b BLOCK)

```
Phase 4 Step 4.3 phát hiện peer session:

E090b BASE_URL Conflict — 2 phiên cùng URL

Phiên hiện tại: 2026-05-16-module-payment-01 (BASE_URL=http://localhost:3000)
Peer:
  - ID: 2026-05-16-system-erp-02
  - PID: 12345 (alive)
  - BASE_URL: http://localhost:3000

Risk: Browser session conflict, shared cookies, race conditions

Options:
  1) Tiếp tục risk (chỉ chọn nếu DB tenancy isolated)
  2) Đợi peer hoàn thành (poll 30s, max 30 phút)
  3) Cancel pipeline
```

Escape hatch: `MCV3_PW_ALLOW_SHARED_URL=1` (CI/CD).

### S16 — Lazy-Load Group-Level Resume (Phase 5 Crash Mid-Triage)

Pipeline crash khi Phase 5 đang `D-spawn-triage` (Agent timeout):

```bash
/wf-fix-bugs --resume
```

1. R10 load `phase5-triage.md` index (~135 dòng)
2. R10 đọc `phase5-triage/POST-GATE.md §Resume Logic`:
   - `issue-registry.json` exists ✓
   - `bug-triage.md` exists ✗
   - → Resume from Group D (Spawn Triage)
3. Re-spawn `wf-fix-triage` agent (E053 budget +1, max 3 retries)
4. Continue Groups E/F/G

Không re-execute Groups A/B/C (đã completed) — saving ~5 phút.

### S17 — Phase 4 Selective Archive Trên Resume

Pipeline crash khi Phase 4 đang `in_progress` (3/11 lanes completed):

```bash
/wf-fix-bugs --resume
```

1. R5 detect Phase 4 `in_progress`
2. R5 scan `lanes/QD*/lane-status.json`:
   - QD1 completed → PRESERVE
   - QD2 completed → PRESERVE
   - QD3 completed → PRESERVE
   - QD4 in_progress → ARCHIVE to `lanes-partial-{ts}/`
   - QD5-QD11 pending → ARCHIVE
3. Top-level `Phase4-report.md`/`phase4-summary.json` → KHÔNG touch
4. Phase 4 POST-GATE Resume Logic: re-dispatch QD4-QD11 (8 lanes), skip QD1-QD3

Saving: ~45 phút × 3 lanes = ~2.25h preserved.

### S18 — Large ERP với --from-cmi (Cross-Skill Integrity)

User chạy wf-cmi trước → integrity-impact.json → hand off vào wf-fix-bugs:

```bash
# Bước 1: System-wide integrity check
/wf-cmi --scope=system --name=erp-finance --profile=deep
# → integrity-impact.json (26 lane CD1-CD40 results)

# Bước 2: Fix bugs với hint từ cmi
/wf-fix-bugs --scope=system --name=erp-finance --from-cmi
```

wf-fix-bugs Phase 3 ISG đọc `integrity-impact.json`:
- Critical lanes có violations → bump dim priority
- Recommend Add QD10 + QD11 nếu cross-module/business gaps detected

---

## 11. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [03-architecture.md](03-architecture.md) | Multi-session safety + Protocol 22 |
| [05-execution-profiles.md](05-execution-profiles.md) | Workload Gate + Resume Strategy |
| [06-evolution-history.md](06-evolution-history.md) | v10.x operational changes |
| [09-design-decisions.md](09-design-decisions.md) | Q14-Q23 locked + ADR-23 partition strategy |
| `.claude/skills/workflow/wf-fix-bugs/procedures/resume-status.md` | R1-R10 logic canonical |
| `.claude/skills/protocols/22-cross-session-rw-lock.md` | Protocol 22 R/W lock |
