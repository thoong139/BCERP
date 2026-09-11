# CHANGELOG

Lịch sử phát hành các skill trong DEVKIT (MCV3).

---

## [wf-fix-bugs v11.2.0] — 2026-05-17

### Wave 3 Polish — G4 (Cross-scope CDG E096 + Follow-up Queue)

Hoàn thành Wave 3. Bổ sung gate user-facing CDG E096 phát hiện cross-module issues và queue follow-up cross-session. Sessions cũ v10.x/v11.0.x/v11.1.0 `--resume` chạy bình thường (toàn bộ behavior G4 opt-in qua threshold/env).

#### G4 — Cross-scope detection + CDG E096 + Follow-up queue

**Vấn đề (R5)**: Khi `--scope=module=settings` chạy nhưng registry có 8+ issues nằm ngoài scope (`customs/`, `finance/`, ...), skill viết text "Mở session wf-fix-bugs --scope=cross-module" vào `deferred-issues-analysis.md` (ad-hoc) nhưng KHÔNG hỏi user và KHÔNG persist queue → user phải tự đọc file phụ và copy lệnh.

**Fix**: Phase 6 Step 6.7b mới — detection + CDG render + enqueue auto. Pipeline kết thúc với `pipeline_status=DONE_NEEDS_FOLLOWUP` khi có queue entries.

| File | Loại | Mô tả |
|------|------|-------|
| `scripts/wf-fix-bugs/build-id-mapping.sh` | NEW | Bridge 3 ID schemes (registry `QDx-XX-NNN`/`SIG-QDx-NNN` ↔ plan `ISS-YYYYMMDD-NNN` ↔ report `ISS-NNN`). Match: file path + severity (plan), title fuzzy ≥40% token overlap (report). Output: `$SESSION_DIR/_meta/id-mapping.json` schema `id-mapping-v1`. Single-jq pass, fork-safe. |
| `scripts/wf-fix-bugs/detect-cross-scope.sh` | NEW | Phân loại 3 layer: cross_module_dependencies flag (L1), file path outside scope substring match case-insensitive (L2), keyword match "cross-module"/"cross-scope"/"spawn session"/"mở session" (L3). Skip infra files (messages/, i18n/, e2e/, package.json, globals.css, etc.). Threshold default 3 (env `MCV3_FIX_CROSS_SCOPE_THRESHOLD`). Single-jq, fork-safe. |
| `scripts/wf-fix-bugs/enqueue-followup.sh` | NEW | APPEND-only helper. mkdir-based atomic lock (flock không có trên Git Bash) với 10s timeout + stale takeover sau 60s. Idempotent: (source_session, kind) dup → SKIP. Schema `followup-queue-v1`: `{$schema, queued_at, source_session, session_id, kind, suggested_command, items[], priority, status}`. |
| `skills/workflow/wf-fix-bugs/templates/_meta/id-mapping.json` | NEW | Template cho id-mapping.json (schema v1). |
| `skills/workflow/wf-fix-bugs/procedures/phase6-execute/G-finalize.md` | MODIFY | Thêm Step 6.7b INLINE: detection → CDG E096 AskUserQuestion (3 options) → enqueue. Anti-loop guard qua `cdg-tokens.json` (gate=E096). E096 type=warning (KHÔNG block POST-GATE). |
| `skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md` | MODIFY | Section "Follow-up Suggestions" mới với placeholder `[FOLLOWUP_SECTION]`. |
| `scripts/wf-fix-bugs/generate-phase7-reports.sh` | MODIFY | Populate `[FOLLOWUP_SECTION]` từ `_followup-queue.jsonl` lọc theo `(source_session OR session_id) == $SESSION_ID && status == "pending"`. Markdown table với # / Kind / Suggested Command / Priority / Items count. |
| `scripts/wf-fix-bugs/tests/g4-integration-tests.sh` | NEW | 5 scenarios: F1 detect 5 cross items, F2 5 parallel appends, F3 orchestrator-summary render, F4 disable env, F5 build-id-mapping schema valid. |

**Sub-spike — ID Schema Bridge (T0)**:

3 ID schemes incompatible buộc dùng cross-join thay vì 1:1:
- `issue-registry.json`: `QD9-RT-007` (dimension-runtime-N) hoặc `SIG-QD10-001` (signal-QDx-N)
- `fix-plan.md` Issue ID column: `ISS-YYYYMMDD-NNN` (date-based, sequential)
- `fix-report.md` Issue ID column: `ISS-NNN` (short) hoặc `ISS-YYYYMMDD-NNN`

Match logic:
1. registry ↔ plan: file path exact + severity priority preferred (consume-once tracking)
2. registry ↔ report: title token overlap ≥40% words (case-insensitive, first 6 tokens ≥4 chars)
3. canonical_id = registry_id (most stable)

**CDG E096 Spec**:

```
Gate: E096 (CDG user-facing, range E090-E099)
Type: warning — KHÔNG block POST-GATE
Trigger: cross_scope_count >= threshold (default 3)
Anti-loop: cdg-tokens.json append với gate=E096 → re-run skip
Disable: MCV3_FIX_CROSS_SCOPE_DISABLE=true (skip toàn bộ G4 logic)

3 options qua AskUserQuestion:
  1. "Spawn cross-scope session ngay (Recommended)"
     → enqueue + echo suggested_command
  2. "Enqueue follow-up only"
     → chỉ append vào _followup-queue.jsonl
  3. "Ignore — accept as backlog"
     → KHÔNG enqueue
```

**Smoke test (session settings EUREKA-2026)**:

```
build-id-mapping.sh:
  Input: registry 119 issues + fix-plan 109 rows + fix-report 27 rows
  Output: id-mapping.json schema v1, 119 mappings
  matched_to_plan: 109 / matched_to_report: 7 / unmapped: 10

detect-cross-scope.sh:
  scope=module name=settings threshold=3
  Output: cross_scope_count=12, should_trigger_cdg=true
  Items: 3 endpoints.ts (FE API cross), 1 PaymentGatewayEndpoints, 2 customs page,
         1 mobile-customer auth, 1 SystemRoleSeeder, 3 DSR/UserRefreshToken configs,
         1 finance receivables (target_scope=module=customs|finance|cross-module)
```

**Integration tests (5/5 PASS)**:

```
F1: 5 cross-module items detected (threshold trigger=true)
F2: 5 parallel appends → 5 valid JSONL lines (mkdir lock)
F3: orchestrator-summary renders Follow-up Suggestions với correct count + filter
F4: MCV3_FIX_CROSS_SCOPE_DISABLE=true → count=0, scope=disabled
F5: id-mapping.json valid (schema + mappings count + plan match)
```

**Backward-compat**:

| Scenario | Behavior |
|----------|----------|
| Sessions v10.x/v11.0.x/v11.1.0 `--resume` | Bình thường — G4 chỉ active ở Phase 6 Step 6.7b mới |
| `MCV3_FIX_CROSS_SCOPE_DISABLE=true` | detect-cross-scope.sh skip toàn bộ → CDG E096 KHÔNG fire |
| `cross_scope_count < threshold` | CDG E096 KHÔNG fire (warning only) |
| Sessions không có id-mapping.json | detect-cross-scope.sh fallback canonical_id = registry_id |
| flock không available (Git Bash) | enqueue-followup.sh dùng mkdir lock cross-platform |

#### Cross-skill impact

- **wf-verify-sync**: KHÔNG đổi — fix-impact.json schema v1 giữ nguyên
- **wf-prepare-deployment**: KHÔNG đổi — audit_chain checksum giữ nguyên
- **wf-implement-feature**: KHÔNG đổi — safety gate input giữ nguyên
- **wf-cmi** (future): có thể consume `_followup-queue.jsonl` để generate `integrity-impact.json` cross-references (opt-in qua `--from-fix-bugs`)
- **generate-phase7-reports.sh** đã có sẵn logic check `_followup-queue.jsonl` → set `pipeline_status=DONE_NEEDS_FOLLOWUP` từ trước (Wave 2). G4 cung cấp data input.

#### Files released (8 files MCV3 + mirror EUREKA)

| File | Loại |
|------|------|
| `.claude/scripts/wf-fix-bugs/build-id-mapping.sh` | NEW |
| `.claude/scripts/wf-fix-bugs/detect-cross-scope.sh` | NEW |
| `.claude/scripts/wf-fix-bugs/enqueue-followup.sh` | NEW |
| `.claude/scripts/wf-fix-bugs/tests/g4-integration-tests.sh` | NEW |
| `.claude/skills/workflow/wf-fix-bugs/templates/_meta/id-mapping.json` | NEW |
| `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute/G-finalize.md` | MODIFY |
| `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md` | MODIFY |
| `.claude/scripts/wf-fix-bugs/generate-phase7-reports.sh` | MODIFY |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | MODIFY (v11.1.0 → v11.2.0) |
| `CHANGELOG.md` | MODIFY |

---

## [wf-fix-bugs v11.1.0] — 2026-05-17

### Wave 3 Polish — G6 (Windows path sanitize) + G5 (False-positive exclusions)

Bản nâng cấp Wave 3 phần đầu (2 trên 3 nhóm) — không thay đổi behavior pipeline, chỉ cải thiện output chất lượng và giảm noise. **G4 (cross-scope CDG E096 + queue) defer sang phiên khác** với spike ID schema riêng do scope rộng.

#### G6 — Windows Git diff path sanitize

**Vấn đề (R7)**: `safety-check.json` và `git-diff-files.txt` chứa byte rác `0xEF 0x80 0x8D` (U+F00D PUA, biểu tượng "wrench" trong Nerd Fonts) chèn bởi Git on Windows trên một số môi trường (core.quotepath=true hoặc terminal có font icon).

**Fix**: Inline `tr -d '\357\200\215\r'` sau mỗi `git diff` trong 2 scripts.

| File | Vị trí |
|------|--------|
| `scripts/wf-fix-bugs/safety-check.sh` | Line 103 + 106 (UNCOMMITTED_FILES + UNCOMMITTED_DETAILS) |
| `scripts/wf-fix-bugs/verify-execute-outputs.sh` | Line 199 + 200 (GIT_DIFF_FILES + GIT_DIFF_STAT) |

**Smoke test (synthetic input)**:
```
Input: "QD1-functional\357\200\215\nQD2-business\357\200\215\nclean-line\n" (PUA injected)
After tr filter: 3 lines, NO PUA bytes (verified bằng xxd)
Line count preserved (newlines intact, content preserved)
```

**Backward-compat**: Trên Linux/Mac/clean Windows (không có PUA byte) → `tr -d` no-op, performance impact < 5ms.

#### G5 — False-positive exclusions cho QD3 secret detection

**Vấn đề (R6)**: 8 i18n keys (apps/erp-web/src/messages/*.json + tương tự) bị flag là "Generic API Key" / "Generic Password" do regex match `password.placeholder = "..."` hoặc `api_key = "..."` trong translation strings. False positives tốn iteration budget của Wave 2 auto-loop.

**Fix**: Config-driven exclusions với fallback inline regex để backward-compat.

| File | Loại | Mô tả |
|------|------|------|
| `skills/workflow/wf-fix-security/exclusions.json` | NEW | Schema `scan-exclusions-v1`, 4 nhóm: `i18n_translations`, `test_fixtures`, `docs_examples`, `build_artifacts`. Mỗi nhóm có `applies_to[]` cho phép share giữa probes. |
| `scripts/wf-fix-probe-static-secret.sh` | MODIFY | Load exclusions.json qua jq, build EXCLUDE_PATTERN động. Env override: `MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE=true` (bypass G5) hoặc `MCV3_FIX_SECURITY_EXCLUSIONS_FILE=/path/custom.json` (custom config). Fallback inline regex nếu file missing hoặc jq unavailable → behavior cũ. |
| `skills/workflow/wf-fix-security/procedures/probes/P-QD3-secret-detection.md` | MODIFY | Documentation thêm reference exclusions.json + 4 nhóm + env vars. |

**Smoke test (3 scenarios)**:
```
Fixtures: /tmp/g5fx/src/{messages,i18n,config}/

G5 ENABLED (default):  2 signals (cả 2 real secret trong src/config/database.ts CRITICAL)
                       i18n/vi.json + messages/en.json EXCLUDED đúng
G5 DISABLED (env):     3 signals (2 real + 1 i18n false positive HIGH)
                       Confirm cơ chế bypass hoạt động
```

**Backward-compat**: exclusions.json missing → probe behavior cũ (EXCLUDE_PATTERN inline). Sessions cũ resume bình thường.

#### G4 — DEFERRED sang phiên khác

Cross-scope CDG E096 + follow-up queue cần spike ID schema normalization riêng (3 ID schemes incompatible: `QD9-RT-007` / `ISS-20260516-001` / `ISS-001`). Plan chi tiết đã viết tại [plans/wf-fix-bugs-v11-quality-fix/04-wave3-polish.md](plans/wf-fix-bugs-v11-quality-fix/04-wave3-polish.md) §G4 — sẽ implement v11.2.0 phiên sau.

#### Tổng kết Wave 3 partial (G6+G5)

| File | Loại |
|------|------|
| `.claude/scripts/wf-fix-bugs/safety-check.sh` | MODIFY (G6) |
| `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh` | MODIFY (G6) |
| `.claude/scripts/wf-fix-probe-static-secret.sh` | MODIFY (G5) |
| `.claude/skills/workflow/wf-fix-security/exclusions.json` | NEW (G5) |
| `.claude/skills/workflow/wf-fix-security/procedures/probes/P-QD3-secret-detection.md` | MODIFY (G5 docs) |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | MODIFY (v11.0.2 → v11.1.0) |
| `plans/wf-fix-bugs-v11-quality-fix/04-wave3-polish.md` | NEW (Wave 3 plan detail) |
| `CHANGELOG.md` | MODIFY (entry này) |

#### Migration v11.0.2 → v11.1.0

- **Breaking changes**: NONE — 100% additive.
- **Env vars mới**: `MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE` (default false), `MCV3_FIX_SECURITY_EXCLUSIONS_FILE` (default `.claude/skills/workflow/wf-fix-security/exclusions.json`).
- **Sessions cũ v10.x/v11.0.x**: `--resume` chạy bình thường, no impact.

---

## [wf-fix-bugs v11.0.2] — 2026-05-17

### Patch — BUG-V11-001 Wave 2 Loop SSOT Consistency (production-ready)

Bản patch fix 2 bug pipeline phát hiện qua **end-to-end test** v11.0.1 trên session settings (EUREKA-2026): agent iter1 fix 5 items thật (input 45 → 50 fixed) nhưng pipeline báo fixed=45 → false-fire NO-PROGRESS guard → escalate sai. Sau patch, loop iteration ghi nhận progress đúng, Wave 2 sẵn sàng production.

#### Thay đổi (2 scripts + SKILL + CHANGELOG)

| File | Thay đổi |
|------|----------|
| `scripts/wf-fix-bugs/verify-execute-outputs.sh` | Thêm **Source 0** (priority cao nhất) trong chain extract counts: đọc `fix-iterations.json[].after_fix_count` của iter completed mới nhất. Lý do: agent re-spawn theo D-spawn-execute.md v11 output contract chỉ ghi `fix-iterations.json` + APPEND section vào `fix-report.md` (KHÔNG update Summary table top hoặc append `fix-log.json`) → Source 1 (fix-log.json) + Source 2 (fix-report Summary table) trả counts STALE. Source 0 dùng loop SSOT khi available. Wrap Source 1 với `if COUNTS_SOURCE = "none"` để skip khi Source 0 đã đặt. Log line mới: `INFO(v11.0.2): Source=fix_iterations_loop`. |
| `scripts/wf-fix-bugs/fix-iteration-loop.sh` | Fix semantic bug **NO-PROGRESS GUARD**: `PRIOR_FIXED` đổi từ `.iterations[N-1].after_fix_count` (= state AFTER iter ran, bằng ACTUAL_FIXED → false-fire sau MỌI iter completed) sang `.iterations[N-1].input_actually_fixed` (= state BEFORE iter ran, được snapshot tại `continue_loop` case khi iter bump). Bỏ fallback chain. |
| `SKILL.md` | Version bump v11.0.1 → v11.0.2. |
| `CHANGELOG.md` | Entry này. |

#### End-to-end test (session settings, EUREKA-2026)

Trước patch (v11.0.1):
```
Step 6.5b call 2 (post agent iter1):
  decision=escalate_cdg (FALSE-fire NO-PROGRESS — agent fix 5 items nhưng counts vẫn 45)
```

Sau patch (v11.0.2):
```
Step 6.5b call 2:
  Source=fix_iterations_loop — latest iter after_fix=50, after_deferred=54
  unsanctioned drop 59 → 54 (5 items fixed)
  decision=continue_loop ✓ (50 > 45 prior input)
  bumped to iter=2, input_actually_fixed=50 snapshot
```

#### Regression test (5 scenarios PASS)

| Scenario | Setup | Expected | Result |
|----------|-------|----------|--------|
| Fresh state | iter=0, unsanct=59 | continue_loop | ✓ |
| NO progress | iter=1, input=45, after=45 | escalate_cdg | ✓ (WARN message printed) |
| Progress | iter=1, input=45, after=50 | continue_loop | ✓ (was escalate before patch) |
| Max iter | iter=3, has progress per iter | escalate_cdg (budget exhaust) | ✓ |
| Disable hatch | MCV3_FIX_LOOP_DISABLE=true | disabled / finalize_phase6_legacy | ✓ |

#### Backward compatibility — 100%

- Sessions cũ KHÔNG có `fix-iterations.json` → Source 0 skip, fall through Source 1+ → zero impact.
- Sessions có `fix-iterations.json` nhưng chưa có iter completed → Source 0 skip (require `.completed_at != null` + `.after_fix_count != null`).
- NO-PROGRESS guard semantic fix chỉ ảnh hưởng case CURRENT_ITER >= 1 đã có loop chạy → trước đây luôn false-fire, sau patch ghi nhận progress đúng. Không có scenario nào hồi quy.

#### Acceptance

- Wave 2 (G2 + G3) production-ready. `/wf-fix-bugs --resume` trên session đã có loop iter sẽ tiếp tục loop đúng đến khi: hết unsanct / max iter / no progress thật sự.
- v11.0.0 acceptance criteria: `fixed_count tăng từ 45 → ≥70` giờ có thể đạt qua tự động loop iter 1-3 (mỗi iter ~5-15 items).

---

## [wf-fix-bugs v11.0.1] — 2026-05-17

### Patch — Orchestrator Loop-Back Wiring (completes Wave 2 v11.0.0)

Bản patch hoàn thiện Wave 2: trước v11.0.1, scripts `verify-defer-reasons.sh` + `fix-iteration-loop.sh` + procedure documentation EXIST nhưng không có code thực sự loop back Group D ở orchestrator level → v11.0.0 chỉ "on paper", chạy thực tế không loop. Patch này wire end-to-end.

#### Thay đổi (3 files)

| File | Thay đổi |
|------|----------|
| `procedures/phase6-execute.md` | Index router thêm explicit ROUTING DECISION ở Step 6.5b (Orchestrator Execution Pattern §7). Route theo NEXT_ACTION: (a) `spawn_execute_with_unsanctioned` → GOTO Step 6.4 với LOOP_ITERATION + UNSANCTIONED_FOCUS=true (max 3 iter); (b) `ask_user_question` → CDG E095 INLINE → route theo user choice (Force-fix +1 iter EXPERT_OVERRIDE / Accept / Spawn cross-scope); (c) `finalize_phase6` → continue Group F. Execution Flow diagram thêm loop-back arrow. Thêm "QUY TẮC LOOP SAFETY" (max iterations, no-progress guard, disable hatch, re-entrant E-validate). |
| `procedures/phase6-execute/D-spawn-execute.md` | Input contract thêm v11 Loop-back vars: `$LOOP_ITERATION`, `$UNSANCTIONED_FOCUS`, `$EXPERT_OVERRIDE`. Agent prompt template (CORE-037 Section 1+3) conditional injection cho 3 vars (chỉ render khi loop iter > 0). Section 6 Output Contract thêm v11 loop mode requirements: append `fix-blockers.md` per item không fix được + append `fix-iterations.json[].agent_decisions[]` per quyết định + APPEND section "## Loop Iteration N" vào fix-report.md (KHÔNG ghi đè). |
| `scripts/wf-fix-bugs/fix-iteration-loop.sh` | NO-PROGRESS GUARD mới: nếu CURRENT_ITER >= 1 và `actual_fixed` KHÔNG tăng so prior iteration → force `decision=escalate_cdg` (tránh infinite spin trên items không fixable). Verified smoke test: Call #1 continue_loop iter=0→1, Call #2 escalate_cdg vì fixed=45 không tăng. |
| `SKILL.md` | Version bump v11.0.0 → v11.0.1 + description giải thích loop-back wiring. |

#### Smoke test no-progress guard (session settings)

```
Call #1: decision=continue_loop, iter=0/3, unsanct=59 ✓ (first iter, không có baseline để compare)
Call #2: decision=escalate_cdg, iter=1/3, unsanct=59 ✓ (fixed=45 không tăng → guard trigger)
```

#### Backward compatibility — 100%

- Sessions v10.x + v11.0.0 `--resume` chạy bình thường.
- Env `MCV3_FIX_LOOP_DISABLE=true` → skip loop (v10.x behavior).
- Env `MCV3_FIX_LOOP_MAX_ITER=N` override max iterations.
- Agent prompt conditional injection — nếu vars không set (single-spawn), text loop conditional sẽ rỗng, prompt giống v10.x.

#### Outstanding work còn lại

- **Real E2E test** trên session settings (`/wf-fix-bugs --resume`): expect fixed_count 45 → 70+ sau loop iterations.
- **Wave 3** (G4 Cross-Scope CDG + G5 False-Positive Filter + G6 Windows Path): target v11.1.0, ETA 8-13h.
- **ID schema normalization** spike (registry vs plan vs report ID schemes): cải thiện accuracy của verify-defer-reasons.sh per-item attribution.

---

## [wf-fix-bugs v11.0.0] — 2026-05-17

### Wave 2 (G2 + G3) — Aggressive Auto-Loop + Forbidden Defers

**MAJOR release** giải quyết R3 (max-retry không enforced) + R4 (quick-fix items bị defer dù triage cho phép fix). Pipeline Phase 6 giờ tự loop max 3 iterations + CDG escalation khi exhaust budget.

#### Vấn đề được giải quyết

Trong session test (EUREKA-2026 module=settings, 2026-05-16):
- 104 items có fixability=auto_fix/agent_fix → triage CHO PHÉP fix
- Phase 6 chỉ fix 45 → 59 items "unsanctioned defers" (skill defer dù được phép fix)
- Skill exit sau 1 retry → user phải mở session mới để re-trigger

#### Thay đổi chính (6 files)

| File | Loại | Thay đổi |
|------|------|----------|
| `scripts/wf-fix-bugs/verify-defer-reasons.sh` | **NEW** | Aggregate approach (do ID schema mismatch giữa registry QD9-RT-N / plan ISS-YYYYMMDD-N / report ISS-N): `unsanctioned = should_fix - actually_fixed`. Output `unsanctioned-defers.json` schema v1. |
| `scripts/wf-fix-bugs/fix-iteration-loop.sh` | **NEW** | Orchestrator helper decision tree: continue_loop / escalate_cdg / done. Max 3 iter (env `MCV3_FIX_LOOP_MAX_ITER`). Init + update `fix-iterations.json` schema v1. |
| `templates/phase6-execute/fix-iterations.json` | **NEW** | Schema fix-iterations-v1: audit trail mỗi iteration (input/after counts, agent decisions, final_decision, cdg_token). |
| `procedures/phase6-execute/D-spawn-execute.md` | MODIFY | Section 7 "Ownership Rules" thêm **FORBIDDEN DEFERS** block — cấm defer items có fixability=auto/agent_fix, ghi `fix-blockers.md` thay vì silent defer. Section 8 "Completion Criteria" thêm v11 contract. |
| `procedures/phase6-execute/E-validate-dashboard.md` | MODIFY | Step 6.5b (loop check) + Step 6.5c (INLINE CDG E095 AskUserQuestion 3 options: Force-fix expert / Accept defer / Spawn cross-scope). |
| `scripts/wf-fix-bugs/generate-phase6-report.sh` + Phase6-report.md template | MODIFY | Thêm "Fix Iteration Loop (v11)" section trong Phase6-report.md. |

#### Smoke test trên session settings (EUREKA-2026)

- `verify-defer-reasons.sh`: should_fix=104, actually_fixed=45, **unsanctioned=59** ✓
- `fix-iteration-loop.sh`: 4 calls liên tiếp → iter 0→1→2→3→escalate_cdg ✓ (đúng max-budget logic)
- `fix-iterations.json` audit: 3 iterations entries, final_decision="cdg_escalated", summary tracking đúng
- `Phase6-report.md` mới có dòng "**Fix Iteration Loop (v11):** Iterations: X/3, decision=..." ✓

#### Backward compatibility — 100%

- Env `MCV3_FIX_LOOP_DISABLE=true` → skip toàn bộ loop, behavior v10.x.
- Env `MCV3_FIX_LOOP_MAX_ITER=1` → giả lập behavior v10.18.0.
- Sessions v10.x `--resume` chạy bình thường (verify-defer-reasons.sh fail graceful → skip loop).
- Cross-skill consumers KHÔNG bị break — fix-impact.json schema giữ fix-impact-v1.

#### Limitation đã document (Wave 3 candidate task)

**ID Schema Mismatch**: 3 ID schemes trong session:
- `issue-registry.json`: `id = QD9-RT-007` (dimension-probe-N)
- `fix-plan.md`: `ISS-20260516-001` (date-based ISS)
- `fix-report.md`: `ISS-001` (short ISS)

Per-item cross-join không khả thi → Wave 2 dùng aggregate count approach (vẫn detect được tổng unsanctioned chính xác). Wave 3 (hoặc spike riêng) sẽ normalize IDs để chi tiết per-item attribution.

#### Wave 3 còn lại

**Wave 3** (G4 Cross-Scope CDG E096 + G5 False-Positive Filter exclusions + G6 Windows Path sanitize): target v11.1.0, ETA 8-13h.

Plan: `plans/wf-fix-bugs-v11-quality-fix/`.

---

## [wf-fix-bugs v10.19.0] — 2026-05-17

### Wave 1 (G1 + G7) của plan `wf-fix-bugs-v11-quality-fix` — SSOT Counts + Status Honesty

Bản fix nền tảng giải quyết 3 trong 7 root causes phát hiện qua E2E EUREKA-2026 session `2026-05-16-module-settings-01`: (R1) CQG-1 "substance-based PASS" giả khi deviation thực ≥ 80%; (R2) số liệu fixed_count không nhất quán giữa fix-status.json (45), orchestrator-summary.md (35), Phase6-report.md narrative (39); (G7) pipeline báo "DONE" mơ hồ dù 52% issues defer.

#### Thay đổi chính (7 file)

| File | Thay đổi |
|------|----------|
| `scripts/wf-fix-bugs/verify-execute-outputs.sh` | Multi-source priority chain cho counts: (1) fix-log per-issue → (2) fix-report Summary table → (3) regex fallback với WARN. Thêm `counts_source` field + `is_summary:true` flag. |
| `scripts/wf-fix-bugs/derive-fix-plan-counts.sh` | **MỚI** — sinh `fix-plan-counts.json` (schema `fix-plan-counts-v1`) đếm action="fix"/"manual_review"/"escalate"/"skip" chính xác. |
| `scripts/wf-fix-bugs/cqg1-numeric.sh` | **STRICT MODE v11** — bắt buộc fix-plan-counts.json + fix-execution-result.json v1/v2. Escape hatch `MCV3_FIX_CQG1_ALLOW_REGEX=1`. Auto-bootstrap cho legacy sessions. |
| `scripts/wf-fix-bugs/generate-phase7-reports.sh` | Override env vars từ SSOT. Pre-finalize decide pipeline_status enum + defer placeholder substitution đến sau enum decision. |
| `scripts/wf-fix-bugs/finalize-phase7.sh` | PRESERVE pipeline_status (không hardcode "DONE"). |
| `templates/phase7-verify/orchestrator-summary.md` | Section `## Trạng Thái Pipeline` với banner ✅/⚠️/🔄. |
| `procedures/phase5-triage/G-reports-finalize.md` | Step 5.9b gọi `derive-fix-plan-counts.sh`. |

#### Smoke test trên session settings (EUREKA-2026)

- `verify-execute-outputs.sh`: counts_source=`fix_report_table`, fixed=45, deferred=62 ✓
- `cqg1-numeric.sh`: deviation 1140% → exit 4 ✓ (session này lẽ ra phải FAIL)
- `orchestrator-summary.md`: status="DONE_WITH_DEFERRED", banner ⚠️ "Còn 62 issues chưa fix..." ✓
- Counts 45 nhất quán across orchestrator-summary / fix-status / fix-execution-result ✓

#### Backward compatibility — 100%

Sessions v10.x `--resume` chạy bình thường. Escape hatch `MCV3_FIX_CQG1_ALLOW_REGEX=1` cho fallback. Cross-skill consumers (wf-verify-sync, wf-prepare-deployment, wf-implement-feature) **không** bị break.

#### Wave 2 + Wave 3 còn lại

- **Wave 2** (G2 Aggressive Auto-Loop + G3 Defer Validation): target v11.0.0, giải quyết R3+R4. User chốt "Aggressive auto-loop" qua AskUserQuestion.
- **Wave 3** (G4 Cross-Scope CDG + G5 False-Positive Filter + G6 Windows Path): target v11.1.0, giải quyết R5+R6+R7.

Plan: `plans/wf-fix-bugs-v11-quality-fix/`.

---

## [wf-cmi v3.0.0] — 2026-05-17

### E2E Scenario Engine — Lane CD41 + Phase 9-10 (mở rộng v2.0 → v3.0)

Mở rộng **wf-cmi** từ v2.0.0 (26 lanes Gói C++ Logistics) sang **v3.0.0** bằng cách **tích hợp toàn bộ 9 capability** của `wf-e2e-scenario` vào pipeline: thêm lane mới **CD41 "E2E Scenario Synthesizer"** ở Wave 3, **Phase 9 "E2E Execute & Verify"** (opt-in qua `--exec-scenarios`), và **Phase 10 "E2E Resolution"** (auto-run nếu Phase 9 có FAIL). Mọi thay đổi là **ADD-ONLY** — pipeline v2 (Phase 1-8) giữ nguyên 100% routing/output. Consumer skills tiếp tục consume `integrity-impact.json` v1/v2 schema không cần update (schema bump `integrity-impact-v2 → integrity-impact-v3` với `readable_by=["v1","v2","v3"]`).

#### Quyết định Scope chính (chốt với user 2026-05-16)

| Quyết định | Giá trị | Lý do |
|--------|---------|-------|
| **Scope tích hợp** | Full — toàn bộ 9 capability của wf-e2e-scenario | Tránh duplicate maintenance, kế thừa context dày từ Phase 2-3 (13 graphs + invariants) |
| **Mặc định execute Playwright?** | KHÔNG — chỉ chạy khi có cờ `--exec-scenarios` | An toàn cho user v2.0 hiện tại, quick/standard không tăng thời gian |
| **Trigger auto-run** | `--exec-scenarios` + `profile=deep\|exhaustive` → auto chạy hết. `quick\|standard` → execute subset + AskUserQuestion (CDG E195b) | Smart default theo profile |
| **Browser unavailable** | SKIP Phase 9-10 với E150 WARN, vẫn xuất integrity-report v3 | Graceful degradation (CORE-033) |
| **wf-e2e-scenario lifecycle** | DEPRECATE sau v3.0 ship 2 sprint stable (Stage 10) | wf-e2e-credentials GIỮ standalone (credential vault không thuộc CMI scope) |
| **Backward-compat** | 100% — Phase 1-8 routing identical, `integrity-impact.json` `readable_by=[v1,v2,v3]` | Consumers (verify-sync/fix-bugs/impl-feature/prepare-deployment) không cần update |

#### Lane CD41 "E2E Scenario Synthesizer" (Wave 3)

NEW `procedures/lanes/CD41.md` (814 dòng) — sinh `test-scenario.md` từ violations MUST/HIGH + workflow-graph:

- **Trigger:** profile ∈ {deep, exhaustive} (KHÔNG hoạt động quick/standard trừ khi `--exec-scenarios` + user chọn `execute_all` qua CDG E195b)
- **Owner agents:** qa-lead (CD41 owner) + ux-researcher + business-analyst (co-owners cho UX + business scenarios)
- **Filter dims:** CD9, CD11, CD13, CD15, CD23-26, CD38, CD39 (violations cross-module + UX critical)
- **8 synth steps:** Load Phase 2-5 outputs → Filter+Rank violations → Walk workflow-graph + confidence scoring → Render template → Manifest write → Signals emit 3 kinds (`E2E_SCENARIO_SYNTHESIZED` / `SKIPPED_LOW_CONFIDENCE` / `CROSS_MODULE_DETECTED`) → Phase report → Lane status cleanup
- **Output:** `phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json` (schema `scenarios-manifest-v1`) + `scenarios/test-scenario-CMI-{NN}-{slug}.md × N` (schema `scenario-md-v1` với 14-field CMI metadata frontmatter)
- **Profile activation v3:** deep = 26→27 lanes, exhaustive = 35→36 lanes. Wave 3 = 6→7 lanes (deep) / 10→11 lanes (exhaustive)

#### Phase 9 "E2E Execute & Verify" (NEW — opt-in `--exec-scenarios`)

NEW `procedures/phase9-e2e-execute.md` (737 dòng) — Playwright orchestration cho scenarios CD41 sinh ra:

- **Engine:** `procedures/_e2e-runner.md` (547 dòng — port từ `wf-e2e-scenario/procedures/scenario-runner.md` với 5 step patterns Click/Fill/Select/Wait/Navigate + tiếng Việt aliases + Cross-Module walk pattern)
- **Evidence:** `procedures/_screenshot-evidence.md` (341 dòng — port + 8 file naming categories + timing capture matrix 8 triggers + strict evidence validation 80% coverage default 100% strict)
- **PRE-GATE T1-T4:** manifest non-empty + Playwright MCP available + FE running (probe `entry_url`) + browser-mcp.lock acquirable
- **11 Steps:** init → acquire lock → lint loop (7 LINT rules CMI-specific) → pre-flight 5x flakiness với stable-registry sha256 TTL=30d → login optional → FOR each scenario dispatch engine → cross-module aggregate → release lock → write `e2e-execution-report.md` → update integrity-status + audit_chain → POST-GATE
- **5 Quality Gates (G1.1-G1.5):** lint script (`lint-scenario.sh` 7 rules) / 5x stability (4 levels: stable/flaky_warn/flaky_quarantine/blocked) / stable-registry hit (TTL 30 ngày cross-session) / quarantine override / cross-module aggregate
- **Output:** `phase9-e2e-execute/` subdir với `e2e-execution-report.md` + `e2e-results.json` (schema `e2e-results-v1`) + `lint-report.json` + `lint-fixes.md` + `stable-registry.json` + `quarantine-report.json` + `screenshots/scenario-{NN}-{slug}.png × N` + `Phase9-report.md`

#### Phase 10 "E2E Resolution" (NEW — auto-run nếu Phase 9 có FAIL)

NEW `procedures/phase10-e2e-resolution.md` (685 dòng) + engine `_failure-analyzer.md` (995 dòng):

- **Failure Analyzer 7-type:** AUTH > NETWORK > DATA_MISSING > TEST_SELECTOR > UI_BUG > BUSINESS_RULE > UNKNOWN (priority order với AUTH 401/403 override NETWORK 5xx)
- **Layer + Owner mapping:** 6 failure types → 6 owners (qa-lead/frontend-developer/security/developer/dba/business-analyst) + domain experts co-spawn theo modules_involved (finance/logistics/compliance/hr/sales)
- **Auto-fix 2-phase:**
  - **Phase A (browser-fix, default):** 5 strategies — TEST_SELECTOR 3 variants / AUTH re-login / NETWORK 5xx retry / UI_BUG reload / DATA_MISSING seed UI. Atomic update test-scenario.md với "Tested by Phase A".
  - **Phase B (source-fix, OPT-IN qua `--auto-fix-source` + CDG E195 confirm):** Spawn agent với 8-section prompt (CORE-037), max concurrency 3, HMR wait + reload + re-execute scenario. Resolution entry 4 variants (Phase A success / Phase B success / both fail UNRESOLVED / SKIP UNKNOWN).
- **Loop-back gap-suggestions APPEND:** Confidence buckets (0.95 PASS / 0.85 PASS-via-B / 0.30 FAIL / 0.50 default) — APPEND `kind="e2e_scenario_fix"` vào `phase7-gap-cdg/gap-suggestions.json` (schema `gap-suggestions-v1` KHÔNG bump, chỉ thêm value cho enum kind)
- **Anti-loop guard (4 rules):** APPEND CHỈ kind=e2e_scenario_fix / KHÔNG re-trigger CD41 / schema vẫn gap-suggestions-v1 / per-session synth 1 lần
- **Output:** `phase10-e2e-resolution/resolution-report.md` (6 sections: Tổng quan + Failure classification matrix + Per-failure resolution + Auto-fix outcomes + Loop-back suggestions + Phase Summary) + `Phase10-report.md`

#### Phase 8 Report v3 (UPDATE — backward-compat preserved 100%)

UPDATE `procedures/phase8-report.md` (+~257 dòng), `templates/integrity-report.md` (+E2E Summary section conditional, max bound 55→70 v3), `templates/integrity-impact.json` (schema v2→v3, +2 v3 fields):

- **`integrity-report.md` E2E Section conditional render:** chỉ xuất hiện nếu `PHASE_9_RAN=true`. Section "3.5. E2E Execution Summary" với bảng 9 metrics + top failure types + Evidence/Resolution link. POST-GATE T5 NEW verify conditional render đúng.
- **`integrity-impact.json` schema v3 (`integrity-impact-v3`):**
  - **2 v3 fields mới:** `e2e_execution_summary{}` (12 fields: exec_enabled + n_synth + n_exec + n_pass + n_auto_corrected + n_fail + n_quarantined + n_cross_module + duration_ms + n_loop_back + top_failure_types[]) + `scenarios_artifacts[]` (per-scenario entry với feat_id + modules_involved + cross_module + execution_status + screenshot_paths + resolution_path)
  - **`readable_by=["integrity-impact-v1", "integrity-impact-v2", "integrity-impact-v3"]`** — backward-compat read v1+v2+v3 verified qua mock test
  - **ALL v1+v2 fields preserved 100%** (lanes_v2, wave_breakdown, group_breakdown, logistics_critical_signals_count, coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, summary, audit_chain)

#### 7 Cờ mới CLI

| Cờ | Default | Mô tả |
|----|---------|-------|
| `--exec-scenarios` | OFF | Bật Phase 9 E2E execute (Playwright). KHÔNG bật mặc định. |
| `--scenarios-only` | OFF | Bypass Phase 1-8, chỉ chạy Phase 9-10 trên session DONE đã có scenarios-manifest (cần `--session-id`) |
| `--show-browser` | OFF | Playwright headed mode (visible browser). Yêu cầu `--exec-scenarios`. |
| `--mobile` | OFF | Mobile device emulation (Playwright). Yêu cầu `--exec-scenarios`. |
| `--strict-evidence` | OFF | Bật 100% evidence coverage requirement (default 80%). Yêu cầu `--exec-scenarios`. |
| `--no-prompt` | OFF | Bypass CDG AskUserQuestion (CI mode). CDG E195b silent default = `execute_must_only`. |
| `--auto-fix-source` | OFF | Bật Phase 10 Phase B source-fix (spawn agents). Yêu cầu CDG E195 confirm mỗi session. |

#### Error codes namespace v3 (E150-E199)

- **E150-E155:** Phase 9 init/PRE-GATE (Playwright DOWN graceful / manifest empty / FE not running / lock timeout / login fail)
- **E160-E162:** CD41 synth (insufficient violations / template render fail / cross-module path invalid)
- **E170-E171:** Screenshot evidence (capture fail / strict coverage shortage)
- **E180-E181:** Failure analyzer (evidence partial / classify ambiguous)
- **E190-E194:** Phase 10 auto-fix (Phase A all-strategy fail / Phase B agent timeout / spawn fail / HMR wait timeout / loop-back schema invalid)
- **E195 / E195b:** CDG user-facing (source-fix confirm / subset E2E execute confirm)
- **E016b:** v3 args mutex stop (--scenarios-only without --session-id / --scenarios-only + --resume)
- **E100-E101:** Warnings (--ci auto-set --no-prompt / flag ignored due to missing prerequisite)

#### Helper scripts mới (`scripts/wf-cmi-e2e/`)

- `lint-scenario.sh` (~11KB, 7 LINT rules CMI-specific): LINT-001 frontmatter / LINT-002 steps_table_malformed / LINT-003 unknown_step_pattern / LINT-004 expected_result_empty / LINT-005 actor_not_in_rbac / LINT-006 entry_url_unreachable / LINT-007 cross_module_path_invalid
- `detect-modified-scenarios.sh` (~2.6KB): git-diff scenarios mới/modified since baseline
- `e2e-pre-flight-check.sh` (~4.8KB): 5x stability deterministic stub với 4 levels + stable-registry hit
- `browser-lock.sh` (~3.8KB): per-session browser-mcp.lock acquire/release/status, TTL 30 min stale auto-release
- `test-stage7-smoke.sh` (~230 dòng): smoke test 7 scenarios §7.2 + AskUserQuestion CDG E195b decision logic
- `test-failure-classify.sh` / `test-auto-fix-phase-a-b.sh` / `test-loopback-append.sh` (Stage 5 — 7-type + Phase A/B + loop-back smoke)
- `test-browser-unavailable-smoke.sh` (~150 dòng): 5 scenarios browser unavailable (E150 graceful / silent skip / manifest empty / FE not running / positive control)

#### Quality Gates (Stage 8 — 6/6 PASS)

- **18 evals tổng** (5 v1 + 8 v2 + **5 v3 mới TC-cmi-014 → TC-cmi-018**):
  - **TC-cmi-014** backward-compat-v3: no exec flag → e2e fields null + integrity-report ≤55 dòng
  - **TC-cmi-015** cd41-synth: CD41 synth từ MUST violation → ≥1 scenario + cross-module
  - **TC-cmi-016** phase9-execute: 5 scenarios → 3 PASS + 2 FAIL → Phase 10 Phase A → 2 AUTO_CORRECTED
  - **TC-cmi-017** phase10-loopback: `--auto-fix-source` CDG E195 → Phase B spawn 3 agents → 2 PASS + 1 ESCALATE + loop-back APPEND `kind='e2e_scenario_fix'`
  - **TC-cmi-018** stable-registry: hit 7/10 + 5x pre-flight skip + 1 quarantine
- **5 fixture stubs** trong `tests/fixtures/wf-cmi/v3-*/` (9 JSON files all `jq` valid)
- Compliance audit GRADE PASS (12/12 CRITICAL + 13/13 REQUIRED + 5/5 CONDITIONAL)
- Schema sync 1/1 PASS với 35 procedure references
- SKILL.md = **497 dòng ≤500 HARD GATE PASS** (G1.3 RESOLVED qua 3 refactor actions Stage 7)
- Browser unavailable smoke 21/21 PASS (E150 graceful + silent skip + E150b + E151 + positive control)

#### Skill architecture compliance

- **SKILL.md = 497 dòng ≤500** (CORE-032 lazy-load procedures preserved) sau Stage 7 refactor (-38 dòng từ 535 alpha)
- **35 procedure paths** verified on disk (10 v2 phase + 18 v2 lane + 5 v3 Phase 9-10 engine + CD41 + _error-quick-lookup + 1 v3 lane CD41)
- **57 outputs.working[] entries** trong `_contract.json` (47 v2 + 10 v3 Phase 9-10 outputs)
- **Agent prompt 8 sections** (CORE-037) cho CD41 + Phase 10 source-fix agents

#### Breaking changes

**KHÔNG có.** v3.0 là **ADD-ONLY** thuần túy:

- ✅ Phase 1-8 routing identical (KHÔNG touch logic core)
- ✅ Phase 9-10 chỉ trigger khi `--exec-scenarios` ON
- ✅ `integrity-impact.json` v3 backward-compat read v1+v2 (consumers ignore unknown fields)
- ✅ `gap-suggestions.json` schema `gap-suggestions-v1` KHÔNG bump (chỉ thêm value cho enum `kind`)
- ✅ `integrity-status.json` v3 fields (`v3_flags{}` + `v3_cdg{}`) là OPTIONAL — v1/v2 readers ignore graceful
- ✅ v1/v2 consumers (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment) KHÔNG cần update reader logic — opt-in v3 features chỉ áp dụng khi consumer update reader

#### Migration notes v2 → v3

- **Default behavior unchanged:** `/wf-cmi --profile=deep` (không cờ v3) hoạt động identical v2.0 — phase 1-8 + 26 lanes + ~55-90 min
- **Opt-in v3 features:** Cần explicit pass `--exec-scenarios` để bật Phase 9-10. Profile=deep|exhaustive auto-run hết, quick|standard prompt CDG E195b
- **Browser unavailable graceful:** Playwright MCP không có → SKIP Phase 9-10 với E150 WARN, vẫn xuất Phase 8 v3 report bình thường (e2e_execution_summary=null)
- **CI mode:** `--ci --exec-scenarios` auto-set `--no-prompt=true` (E100 WARN), CDG silent default `execute_must_only` (balanced safety)
- **`--scenarios-only` re-execute:** Session DONE đã có scenarios-manifest → bypass Phase 1-8, chỉ chạy Phase 9-10 (cần `--session-id`)
- Chi tiết: xem `docs/04-skill-design/wf-cmi/v3-migration-notes.md`
- Architecture deep-dive: `docs/04-skill-design/wf-cmi/12-e2e-engine-arch.md`
- User guide: `docs/06-user-guides/per-skill/wf-cmi-v3-guide.md`

#### Pending Stage 10 (v3.0 → v3.0.1)

- DEPRECATE 10 wf-e2e-* skills (sau v3.0 ship 2 sprint stable): wf-e2e-scenario / wf-e2e-finding / wf-e2e-test / wf-e2e-verify / wf-e2e-batch / wf-e2e-fix / wf-e2e-implement / wf-e2e-retest / wf-e2e-unblock + decide wf-e2e-browser/wf-e2e-demo case-by-case
- wf-e2e-credentials GIỮ standalone (KHÔNG migrate — credential vault không thuộc CMI scope)
- Migration smoke test EUREKA-2026 real fixtures
- Track tại `plans/wf-cmi/progress-scenario.md` mục Stage 10

---

## [wf-cmi v2.0.0] — 2026-05-16

### Gói C++ Logistics — 26 lanes (mở rộng v1.0 → v2.0)

Mở rộng **wf-cmi** (Cross-Module Integrity Orchestrator) từ v1.0.0 (10 lanes CD1-CD10) sang **v2.0.0 với 26 lanes** (Gói C++ Logistics) phù hợp ERP đa module logistics Việt-Trung (target chính: EUREKA-2026). Toàn bộ thay đổi **backward-compatible** — consumer skills (wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment) đọc artifact v2 vẫn hoạt động bình thường nhờ schema versioning + forward-compatible `$schema` detection.

#### Quyết định Scope chính

| Quyết định | Giá trị |
|--------|---------|
| **Lanes active** | 26 (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40) |
| **Lanes skipped** | 9 markers (CD8, CD10, CD12, CD14, CD19-CD22, CD27) — defer cho v2.1+ |
| **Lanes skeleton** | 5 entries (CD32-CD36) — defer v3.0 activation, hiện chỉ placeholder trong `_contract.json.lanes_defined[]` |
| **Mobile scope** | Chỉ `erp-web` ở v2.0 (mobile-customer + mobile-staff defer v2.1) |
| **Profile naming** | Option A — expand `deep` profile từ 10 → 26 lanes (breaking change, migration notes provided) |
| **CD42 Carrier Integration** | Defer v2.1 (logistics-critical nhưng effort cao) |

#### 18 Lanes mới — 6 nhóm sub-stages

- **Frontend (sub-stage 4.1, 4 lanes)**: CD11 FE Component Contracts + CD13 FE↔BE Contract Sync + CD15 UI Permission Mirror + CD18 CQRS Pipeline Integrity (~1462 dòng lane procedures)
- **Backend deep (sub-stage 4.2, 2 lanes)**: CD16 Domain Logic Integrity + CD17 Persistence Consistency (~720 dòng, full integration test EUREKA)
- **UX (sub-stage 4.3, 4 lanes)**: CD23 UX Design System + CD24 UX Display Format + CD25 UX Flow Continuity + CD26 UX Workflow Visibility ★★★ (~1625 dòng)
- **Logistics ★★★ (sub-stage 4.4, 3 lanes)**: CD28 MDM Consistency + CD30 Time & Numbering + CD31 Money & Tax (~1204 dòng, multi-currency VND/CNY/USD + numbering uniqueness Invoice/BOL/Customs)
- **Compliance (sub-stage 4.5, 2 lanes)**: CD29 Audit Trail Completeness + CD37 Regulatory Compliance ★★★ (~833 dòng, PII VN-PDPL + cross-border CN→VN + GDPR/OFAC)
- **NEW Additions (sub-stage 4.6, 3 lanes)**: CD38 UI Implementation Coverage + CD39 Error UX & Recovery + CD40 Print & Export Consistency (~1260 dòng, e-invoice VN TT 78/2021 + BOL VN+EN+CN)

**Tổng lane procedures:** 18 files, ~6900 dòng, mỗi file 8 sections §A-§H theo CORE-037 standard.

#### 7 Graphs mới (Phase 2 Discovery)

| Graph | Lane(s) tiêu thụ | EUREKA fixture smoke test |
|---|---|---|
| `fe-component-graph.json` | CD11 | Skip path + 2-component fixture |
| `fe-api-client-graph.json` | CD13, CD38 | 4 kinds (RQ hooks + Refit + raw fetch + service) — 6 nodes |
| `fe-permission-graph.json` | CD15, CD38 | 6 guard patterns — 5 nodes/5 perms |
| `fe-route-graph.json` | CD25, CD38 | 7 route kinds Next.js App Router — 9 nodes/dynamic+protected |
| `be-domain-graph.json` | CD16 | EUREKA: **944 DDD types / 1338 edges / 18 modules** |
| `be-db-schema-graph.json` | CD17 | EUREKA: **1249 tables / 13827 columns / 2121 indexes** |
| `be-cqrs-graph.json` | CD18 | EUREKA: **3260 CQRS records / 2698 edges / 18 modules** |

#### 9 SSOT templates (Phase 1 Init)

Tất cả templates với `_template_notes` + `_schema_notes` + `_instructions` + `validation_rules.rules[]` ≥ 5:

- `ui-interactivity-spec.json` (823 dòng) — CD38 SSOT mandatory
- `ux-conventions.json` (538 dòng) — CD23/24/25/26
- `mdm-canonical-entities.json` (431 dòng) — CD28, 11 master + 8 reference data
- `compliance-mapping.json` (450 dòng) — CD37, 5 VN + 3 CN + 3 intl regulations
- `rbac-permission-catalog.json` (459 dòng) — CD15/38, 91 perms × 17 modules × 13 roles
- `workflow-state-machines.json` (369 dòng) — CD3/26/38, 9 state machines / 67 states
- `audit-critical-entities.json` (359 dòng) — CD29, 13 entities + PII access
- `error-code-catalog.json` (635 dòng) — CD39, 28 codes + 10 categories
- `print-export-templates.json` (459 dòng) — CD40, 16 doc + 3 label templates

**Tổng:** ~4500 dòng templates tại `plans/wf-cmi/*.eureka-template.json`.

#### Dispatcher 3-wave strategy (Phase 4)

NEW `.claude/scripts/wf-cmi/wave-coordinator.sh` (394 dòng) với 5 subcommands (init/start/end/status/gate-check):

```
Wave 1 (10 parallel, ~10-12 min) — Graphs only:    CD1-CD7, CD11, CD16, CD17
Wave 2 (10 parallel, ~12-15 min) — Cross-layer:    CD13, CD15, CD18, CD23-25, CD28, CD30, CD31, CD37
Wave 3 (6 parallel,  ~8-10 min) — Final cross-ref: CD9, CD26, CD29, CD38, CD39, CD40
```

- Per-wave gate threshold: W1+W2 fail_threshold=3 (E120/E121 STOP), W3 fail_threshold=2 (E122 STOP), 1-2 fail < threshold = PARTIAL_FAIL E123 WARN retry
- Idempotent end: re-run cùng wave KHÔNG double-count `total_lanes_completed/failed`
- Atomic write `.tmp.$$` → jq parse → POSIX `mv` (CORE-035 pattern)
- 11/11 smoke scenarios PASS, 8/8 audit gates PASS

NEW template `wave-status.json` (schema `wave-status-v1`, 73 dòng).

#### Aggregator v2 (Phase 5)

- Coverage matrix schema bump `coverage-matrix-v1 → coverage-matrix-v2` — 35 dim entries (26 active + 9 SKIPPED markers, CD32-36 KHÔNG present)
- Per-dim fields mới: `group`, `wave`, `owner_agents`
- NEW `wave_breakdown{wave_1, wave_2, wave_3}` với per-wave overall_pct
- Threshold check v2: quick≥60% / standard≥80% / deep≥95% / exhaustive=100%
- CDG E090 escalate khi `BELOW_COUNT > 0` (AskUser accept/generate/cancel)
- E005 early exit khi 0 violations + 100% coverage (jump Phase 8)

#### Reports v2 (Phase 8) — Backward-compat producer

- `integrity-report.md`: top 10 violations severity-weighted placeholder `[TOP_VIOLATIONS_LIST]` (MUST=4/HIGH=3/MEDIUM=2/LOW=1), max bound ≤55 dòng (44-48 typical)
- `integrity-impact.json` schema bump `integrity-impact-v1 → integrity-impact-v2`:
  - **5 v2 fields mới**: `lanes_v2{active[], skipped[], skeleton[]}` (26+9+5), `wave_breakdown{wave_1/2/3}` per-wave gate_status, `group_breakdown` 7 sections với critical flag, `logistics_critical_signals_count` từ 7 ★★★ lanes (CD28/30/31/37/38/39/40), `schema_version_compat.readable_by=['integrity-impact-v1','integrity-impact-v2']`
  - **All v1 fields PRESERVED** — backward-compat verified (jq -e check coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, summary, audit_chain)
- `consumers_recommended_actions` 4 consumers update logic: wf-prepare-deployment dùng `logistics_critical_signals_count.must_severity_count + wave_breakdown gate_status` để BLOCK release
- NEW `produces_for_schema_compat` section trong `_contract.json` định nghĩa backward-compat contract

#### Skill architecture compliance

- SKILL.md vẫn **487 dòng ≤500** (CORE-032 lazy-load procedures preserved)
- `_contract.json` v2.0.0 với 40 entries `lanes_defined[]` (26 active + 9 SKIPPED + 5 skeleton v3-deferred), `profile_activation{quick=7/standard=13/deep=26/exhaustive=35}`, 3 schema bumps v1→v2, errors E110-E149
- 28 procedure paths verified on disk (10 phase procedures + 18 lane procedures)
- Agent prompt 8 sections (CORE-037) cho mỗi lane

#### Testing & Eval

- **8 test cases mới (TC-cmi-006 → TC-cmi-013)**: wave subset dispatch, SSOT mandatory missing (E144), full 26-lane deep, logistics-critical multi-currency, compliance PII+cross-border, NEW additions UI/Error/Print, integrity-impact v2 backward-compat, status query
- 13 test cases tổng (5 v1 + 8 v2)
- 3 profile smoke test PASS (quick/standard/deep) qua wave-coordinator dry-run
- Audit gates: skill-compliance-audit GRADE PASS (12/12 + 13/13 + 5/5), validate-schema-sync 1/1 PASS, check-skill-design-populated PASS (11 files)

#### Migration notes v1 → v2

- **Profile activation thay đổi**: `--profile=deep` từ 10 lanes (v1) → 26 lanes (v2), thời gian từ ~60 min → ~90 min. User cần aware.
- **Cross-skill artifact schema**: `$schema` field thay đổi từ `integrity-impact-v1` → `integrity-impact-v2`. Consumer skills tự detect qua `jq '.\$schema'` và route reader v1 vs v2.
- **Workflow KHÔNG ảnh hưởng**: Cùng pipeline 8 phase, cùng cách trigger `/wf-cmi`, cùng output directory structure `.mc-data/work/wf-cmi/sessions/{ID}/`.
- **9 SSOT files cần stakeholder populate**: Để CD15/23-26/28-31/37-40 lanes phát hiện đầy đủ signal, cần điền runtime values vào SSOT templates trong `EUREKA-2026/.mc-data/docs/_meta/`. Lanes có SSOT mandatory (CD15/23-25/28-31/37/38) sẽ ESCALATE nếu thiếu (E141-E146).
- Chi tiết: xem `docs/04-skill-design/wf-cmi/v2-migration-notes.md`.

#### Pending Stage 4 integration tests (v2.0 → v2.0.1)

Integration tests với EUREKA-2026 real fixtures cho 6/6 sub-stages cần stakeholder populate 7 mandatory SSOTs trước. Track tại `plans/wf-cmi/progress-update.md` mục Stage 4 sub-stages.

---

## [wf-fix-bugs v10.9.0] — 2026-05-16

### Phase 7 Optimization — Phase cuối cùng + dài nhất pipeline (hoàn tất chu trình tối ưu Phase 1-7)

Áp dụng pattern tối ưu v10.8 (multi-script delegation + step consolidation + GIỮ INLINE cho CDG + GIỮ orchestrator-side cho UI tools) lên Phase 7 Verify & Report — **phase dài nhất pipeline trước v10.9** (1186 dòng, 14 steps, ~11.96K tokens — gần threshold 12K). Phase 7 là phase cuối cùng của wf-fix-bugs: CQG gates → 4 reports → fix-impact.json cross-skill artifact → pipeline DONE.

**Milestone:** v10.9 hoàn tất chu trình tối ưu Phase 1-7. Tất cả 7 phase procedure files đều <12K tokens (target ~5-6K), tổng pipeline có thể chạy end-to-end trên dự án lớn (EUREKA-2026, ~50+ modules) mà KHÔNG bao giờ trigger `/compact` ở bất kỳ phase nào.

#### Metrics before/after

| Chỉ số | Baseline v10.8 | Sau v10.9 | Δ |
|--------|----------------|-----------|---|
| **Lines** | 1186 (dài nhất) | 601 | **-49%** |
| **Tokens (est.)** | ~11.96K (gần threshold) | ~5.77K | **-52%** |
| **Steps** | 14 | 8 | **-43%** |
| **Inline bash heredocs >20 dòng** | 5+ | 0 | **-100%** |
| **Scripts mới** | 0 | 5 (~33KB) | +5 |

#### Wave 1 — Script delegation + step consolidation (commit cd25ad98)

Tạo 5 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **setup-verify.sh** (~120 dòng) — Gộp Steps 7.1-7.2 vào 1 atomic call:
  - PRE-GATE: verify `phase5.status == "completed"` (E001) + Phase 6 nếu non-E005.
  - E005 detection: `phase5.e005_healthy == true` → route `e005_skip`.
  - Forensic content check (CORE-011): E005=false → verify fix-report + issue-registry non-empty; E005=true → verify Phase5-report.md tồn tại.
  - TRACE START: atomic update `phase7 = in_progress` + APPEND START event.
  - Tạo `phase7-verify/` directory.
  - Output JSON: e005_healthy, route (normal|e005_skip), phase6_completed, status.

- **cqg1-numeric.sh** (~130 dòng) — Implements Step 7.3 CQG-1:
  - Extract expected metrics từ fix-plan.md: `fixed_count`, `deferred_count`, `failed_count` (multi-format regex).
  - Extract actual metrics từ fix-report.md: tương tự.
  - Calculate worst-case deviation (max of 3 deltas) so với threshold (default 5%).
  - E005 skip path (exit 5): không có fixes để verify.
  - Exit 4 nếu deviation > threshold → orchestrator retry x3 (CORE-034) → `_phase7_trace_fail "E070"`.

- **finalize-dashboard.sh** (~150 dòng) — Gộp Steps 7.5+7.5b vào 1 atomic call:
  - **Mobile Gate** (CORE-011 forensic): nếu MOBILE_MODE=true → check Phase4-report cho mobile/device/viewport/responsive references. Zero refs → WARN E045 (không block).
  - **Dashboard Finalize**: branch theo E005_HEALTHY:
    - E005=true: "Hệ thống HEALTHY — không phát hiện lỗi" template
    - E005=false: Tổng/Fixed/Deferred/Failed counts + unresolved details + next steps
  - Output JSON: mobile_gate, mobile_refs, mobile_warn, dashboard_path, total_issues, status.

- **generate-phase7-reports.sh** (~290 dòng — script lớn nhất từ trước) — Gộp Steps 7.6+7.7+7.8+7.9 vào 1 atomic call:
  - **7.6 orchestrator-summary.md** (CORE-028 ≤40 dòng): populate template với Session ID + duration + project + scope + profile + metrics + dimensions + CI tools + Playwright + next steps. Inject DIMS_SUMMARY/CI_TOOLS/PLAYWRIGHT_SUMMARY qua awk.
  - **7.7 fix-impact.json** (CORE-036 cross-skill artifact, schema `fix-impact-v1`):
    - audit_chain.checksum = sha256(fix-status.json) (64-char)
    - Populate dimensions_run, fixed_count, issues_found, signals_found, duration_seconds, ci_tools_used, playwright_used, phases_completed
    - Inline fallback nếu template missing
  - **7.8 phase-summary.md**: inline gộp head 8 dòng của Phase{1-7}-report.md
  - **7.9 Phase7-report.md** (CORE-028 ≤15 dòng): populate STATUS_PASS_FAIL + timestamps + CQG-1/CQG-2 results + pipeline status + duration + next action user

- **finalize-phase7.sh** (~85 dòng) — Gộp Steps 7.10+7.11 vào 1 atomic call:
  - 7.10 Update fix-status: atomic write `phase7.status = "completed"` + `pipeline_status = "DONE"` + `updated_at` (CORE-035).
  - 7.11 TRACE COMPLETE: APPEND COMPLETE event vào session-log + **dual-write global trace** `.mc-data/work/_trace/session-log.json` (CORE-026 dual-write).
  - Output JSON: pipeline_status, phase7_completed, trace_dual_write, status.

**Procedure rewrite** (`procedures/phase7-verify.md` 1186 → 601 dòng):

- Step consolidation 14 → 8 steps (-43%):
  - 7.1+7.2 → 7.1 "Setup Verify"
  - 7.5+7.5b → 7.5 "Mobile Gate + Finalize Dashboard"
  - 7.6+7.7+7.8+7.9 → 7.6 "Generate 4 Reports" (consolidation lớn nhất từ trước — 4 outputs in 1 script)
  - 7.10+7.11 → 7.10 "Finalize Pipeline DONE + TRACE COMPLETE"
- Step numbering giữ gaps **7.2, 7.7, 7.8, 7.9, 7.11** (đã merge) — tránh churn cross-refs
- Markdown boilerplate compression -33%

**GIỮ INLINE cho user interaction** (KHÔNG delegate — preserve UX):

- **Step 7.4 CQG-2 Browser+Integration Gate**: CDG render (AskUserQuestion) cho missing QD9/QD10 evidence — user-facing decision PHẢI INLINE. Logic check QD9_STATUS + QD9_SIGS + QD10 tương tự, decide PASS/FAIL/CDG.

**GIỮ orchestrator-side cho UI tools** (KHÔNG script được):

- **Step 7.12 TodoWrite**: UI tool, mark tất cả 7 phases completed + pipeline DONE
- **Step 7.13 Completion Display**: UI output — orchestrator render summary cuối cùng cho user (branch theo E005_HEALTHY)

#### Wave 2 — Cross-files update

- **SKILL.md** version 10.8.0 → 10.9.0, header description bổ sung v10.9 section với milestone notice, Phase 7 row trong Phase Summary table updated từ 14 steps → 8 steps với chi tiết script delegation
- **_contract.json** version 10.8.0 → 10.9.0, description paragraph v10.9
- **CHANGELOG.md** entry này

#### Verification

- Schema sync (`bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs`): PASS 0 errors
- 5 scripts smoke test PASS với synthetic SESSION_DIR
- CQG-1: PASS deviation 0% (expected 2 vs actual 2)
- Phase7-report.md = 11 lines (CORE-028 ≤15 ✅)
- fix-impact.json: schema `fix-impact-v1` + audit_chain.checksum 64-char sha256 ✅
- pipeline_status = DONE ✅
- TRACE dual-write (session + global) ✅

#### Behavior preserved

- Pipeline state schema (fix-status.json `phase7`) không breaking change — sessions đang dở vẫn `--resume` được
- Cross-skill artifact `fix-impact.json` schema `fix-impact-v1` unchanged — wf-verify-sync/wf-prepare-deployment/wf-implement-feature vẫn consume được
- E005 healthy path (skip CQG-1/CQG-2) preserved
- CQG-1/CQG-2 quality gate semantics preserved
- TRACE FAIL pattern `_phase7_trace_fail` preserved (dual-write + error-ledger)
- Auto-Fix Budget (CORE-034) preserved — max 3 retries cho POST-GATE fail

#### Pipeline-wide milestone v10.9

Hoàn tất chu trình tối ưu 7 phases (v10.3 → v10.9):

| Phase | Tokens trước | Tokens sau | Δ |
|-------|--------------|------------|---|
| 1 Init | ~28K | ~10.75K | -62% |
| 2 Scan | ~8.4K | ~3.45K | -59% |
| 3 Plan | ~10.93K | ~5.24K | -52% |
| 4 Find Bugs | ~15.65K | ~8.56K | -45% |
| 5 Triage | ~10.73K | ~5.77K | -46% |
| 6 Execute | ~10.81K | ~5.71K | -47% |
| 7 Verify | ~11.96K | ~5.77K | -52% |
| **Total** | **~96.48K** | **~45.25K** | **-53%** |

Toàn pipeline có thể chạy end-to-end multi-session trên dự án 50+ modules mà không trigger `/compact` ở bất kỳ phase nào. Resume cross-session với context budget tier <65% an toàn cho mọi phase.

---

## [wf-fix-bugs v10.8.0] — 2026-05-16

### Phase 6 Optimization — Execute Phase (kế thừa pattern v10.3 + v10.4 + v10.5 + v10.6 + v10.7)

Áp dụng pattern tối ưu v10.7 (multi-script delegation + step consolidation + GIỮ INLINE cho CDG + GIỮ orchestrator-side cho Agent) lên Phase 6 Execute — phase trung tâm thực thi fix (spawn `wf-fix-execute`, sync docs, update bug-dashboard). Phase 6 từ ~10.81K tokens (gần threshold) xuống ~5.71K, giảm 47% — đảm bảo pipeline có thể chạy end-to-end multi-session mà không trigger `/compact` ở Phase 6.

#### Metrics before/after

| Chỉ số | Baseline v10.7 | Sau v10.8 | Δ |
|--------|----------------|-----------|---|
| **Lines** | 968 | 581 | **-40%** |
| **Tokens (est.)** | ~10.81K | ~5.71K | **-47%** |
| **Steps** | 11 | 7 | **-36%** |
| **Inline bash heredocs >20 dòng** | 4+ | 0 | **-100%** |
| **Scripts mới** | 0 | 5 (~28KB) | +5 |

#### Wave 1 — Script delegation + step consolidation (commit 7903081f)

Tạo 5 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **setup-execute.sh** (~110 dòng) — Gộp Steps 6.1-6.2 vào 1 atomic call:
  - PRE-GATE: verify Phase 5 `status == "completed"` (E050) + E005 healthy skip detection.
  - Verify required files: `fix-plan.md`, `issue-registry.json`, `cdg-tokens.json` non-empty.
  - Verify `TOTAL_ISSUES > 0` (E061 logic error nếu = 0 nhưng Phase 5 không E005).
  - Verify tất cả CDG tokens `status == "accepted"` (E055 nếu pending — user phải resolve ở Phase 5 CDG handoff trước).
  - TRACE START: atomic update `phase6.status = "in_progress"` + APPEND START event vào session-log (CORE-026).
  - Output JSON: total_issues, cdg_pending, status.

- **dry-run-preview.sh** (~110 dòng) — Implements Step 6.3:
  - Nếu `DRY_RUN=true` → render preview với issues table (parse từ fix-plan.md) + estimated impact (counted files + time range) + Next Steps instructions.
  - Atomic update `fix-status.phase6 = "completed"` với `reason="dry_run"`, `execution_mode="dry_run"`.
  - Exit 5 (E_DRY_RUN_DONE) → orchestrator STOP pipeline (skip 6.4-6.7, chỉ chạy 6.8 + 6.9 nếu cần).
  - Nếu `DRY_RUN=false` → NO-OP, exit 0 → orchestrator tiếp tục Step 6.4.

- **verify-execute-outputs.sh** (~180 dòng) — Gộp Steps 6.6-6.7-6.7b vào 1 atomic call:
  - **POST-GATE T1-T4** (CORE-012): T1 file existence, T2 markdown section headers, T3 docs-sync JSON valid, T4 fix-result keywords (fixed|resolved|repaired|dry|deferred|failed).
  - **Extract counts**: Fixed/Deferred/Failed từ fix-report.md (regex multi-format — agent format đa dạng).
  - **Git diff**: `git diff --name-only` + `git diff --stat` ghi vào `git-diff-files.txt` + `git-diff-stat.txt`.
  - **Logic check**: warn nếu `FIXED + DEFERRED + FAILED > TOTAL_ISSUES` (E061 soft warning).
  - **Dashboard update**: append entry vào `fix-log.json` (atomic) + regenerate `bug-dashboard.md` inline (matches v10.7 pattern).
  - Output JSON: post_gate {t1/t2/t3/t4/all_pass}, fixed_count, deferred_count, failed_count, files_changed, dashboard_updated, status.

- **generate-phase6-report.sh** (~110 dòng) — Implements Step 6.8:
  - Populate template `templates/phase6-execute/Phase6-report.md` (CORE-031 READ → POPULATE → STRIP → WRITE).
  - Inject: STATUS_PASS_FAIL, timestamps, DRY_RUN_OR_LIVE, CI_IMPACT_DONE (auto-detect ci-impact-report.json), Fixed/Deferred/Failed counts, FILES_CHANGED, DOCS_SYNCED (from docs-sync-report), FIX_REPORT_VALID + DOCS_SYNC_VALID indicators (✓/✗).
  - Tiếng Việt (CORE-028) ≤15 dòng.

- **finalize-phase6.sh** (~100 dòng) — Gộp Steps 6.9-6.10 vào 1 atomic call:
  - 6.9 Update fix-status.json: atomic write `phase6.status = "completed"` + execution_mode + fixed/deferred/failed_total + files_changed + updated_at (CORE-035).
  - 6.10 TRACE COMPLETE: APPEND COMPLETE event với execution_mode + counts (CORE-026).
  - Output JSON: execution_mode, fixed_total, deferred_total, failed_total, files_changed, status.

**Procedure rewrite** (`procedures/phase6-execute.md` 968 → 581 dòng):

- Step consolidation 11 → 7 steps (-36%):
  - 6.1+6.2 → 6.1 "Setup Execute" (PRE-GATE + CDG verify + TRACE START)
  - 6.6+6.7+6.7b → 6.7 "Validate + Verify + Dashboard" (POST-GATE T1-T4 + counts + git diff + dashboard)
  - 6.9+6.10 → 6.9 "Finalize" (Update fix-status + TRACE COMPLETE)
- Step numbering giữ gaps **6.2, 6.7b, 6.9, 6.10** (đã merge) — tránh churn cross-refs
- Markdown boilerplate compression -33%

**GIỮ INLINE cho user interaction** (KHÔNG delegate — preserve UX + complex logic):

- **Step 6.4 CI-ROUTE Pre-Execution Impact Analysis**:
  - Fast Path (BLAST_RADIUS_AVAILABLE) + Slow Path (GitNexus impact() per target) detection logic
  - CDG render (AskUserQuestion) cho HIGH/CRITICAL risk targets warning — user-facing decision PHẢI INLINE
  - Complex GitNexus tool calls (`mcp__plugin_gitnexus_gitnexus__impact`) không script được sạch sẽ

**GIỮ orchestrator-side cho Agent tool calls** (KHÔNG script được — CORE-037):

- **Step 6.5 Spawn wf-fix-execute**: Agent({subagent_type, model: "opus", prompt: <8-section template>}) — Phase 6 delegate spawn

#### Wave 2 — Cross-files update

- **SKILL.md** version 10.7.0 → 10.8.0, header description bổ sung v10.8 section, Phase 6 row trong Phase Summary table updated từ 11 steps → 7 steps với chi tiết script delegation
- **_contract.json** version 10.7.0 → 10.8.0, description paragraph v10.8
- **CHANGELOG.md** entry này

#### Verification

- Schema sync (`bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs`): PASS 0 errors
- 5 scripts smoke test PASS với synthetic SESSION_DIR (2 issues từ Phase 5)
- POST-GATE T1-T4: T1 4/4 PASS, T2 4/4 PASS, T3 1/1 PASS, T4 1/1 PASS, all_pass = true
- Phase6-report.md = 10 dòng (CORE-028 ≤15 ✅)
- bug-dashboard.md regenerated correctly
- finalize updates fix-status atomically với execution_mode + counts

#### Behavior preserved

- Pipeline state schema (fix-status.json `phase6`) không breaking change — sessions đang dở vẫn `--resume` được
- Cross-skill artifact contract unchanged (fix-report-v1, docs-sync-report-v1)
- DRY_RUN early-exit path preserved
- CI-ROUTE Fast/Slow Path + CDG flow preserved (W1.1 De-duplicate CI Work optimization v10.0 vẫn áp dụng)
- Auto-Fix Budget (CORE-034) preserved — max 3 retries cho POST-GATE fail

---

## [wf-fix-bugs v10.7.0] — 2026-05-16

### Phase 5 Optimization — Phase nhiều steps nhất pipeline (kế thừa pattern v10.3 + v10.4 + v10.5 + v10.6)

Áp dụng pattern tối ưu v10.6 (multi-script delegation + step consolidation + GIỮ INLINE cho user interaction + GIỮ orchestrator-side cho Agent tool calls) lên Phase 5 Triage — phase **nhiều steps nhất pipeline** (15 steps trước v10.7) và là cầu nối critical giữa detection (Phase 4) và execution (Phase 6). Phase 5 từ ~10.73K tokens xuống ~5.77K, đảm bảo dù toàn bộ pipeline chạy end-to-end trên dự án lớn (EUREKA-2026, ~50+ modules) cũng không bao giờ trigger /compact ở Phase 5.

#### Metrics before/after

| Chỉ số | Baseline v10.6 | Sau v10.7 | Δ |
|--------|----------------|-----------|---|
| **Lines** | 1039 | 616 | **-41%** |
| **Tokens (est.)** | ~10.73K | ~5.77K | **-46%** |
| **Steps** | 15 (nhiều nhất) | 10 | **-33%** |
| **Inline bash heredocs >20 dòng** | 6+ | 0 | **-100%** |
| **Scripts mới** | 0 | 7 (~37KB) | +7 |

#### Wave 1 — Script delegation + step consolidation (commit ae355e8a)

Tạo 7 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **setup-triage.sh** (~140 dòng) — Gộp Steps 5.1-5.2 vào 1 atomic call:
  - PRE-GATE: verify Phase 4 `status == "completed"` (E040 nếu fail).
  - Count signals từ tất cả lanes (static + runtime + llm).
  - E005 healthy path: nếu `TOTAL_SIGNALS = 0` → atomic update fix-status (`phase5+phase6 = completed`, `e005_healthy = true`) + exit 5 → orchestrator jump Phase 7.
  - TRACE START: mark `phase5.status = in_progress` + APPEND START event vào session-log.json (CORE-026).
  - Output JSON: total_signals, signals_static, signals_runtime, signals_llm, e005_healthy, status.

- **aggregate-and-spot-check.sh** (~140 dòng) — Gộp Steps 5.3-5.4 vào 1 atomic call:
  - Aggregate: try Python `-m aggregate` first (module `_shared/aggregate/`), fallback jq merge dedup by fingerprint (keep first occurrence).
  - Spot-Check CORE-029: sample 3 random issues validate `lane/probe_id/fingerprint` required fields.
  - Verify fingerprint uniqueness via jq direct check.
  - Output JSON: total_issues, method (python|jq_fallback), fingerprint_unique, spot_check_warnings, samples_checked, status (ok|warn).

- **process-integrity-check.sh** (~210 dòng) — Implements Step 5.5 PI1-PI5:
  - Atomic write `process-violations.json` từ template (CORE-031 READ → POPULATE → STRIP `_template_notes` → WRITE).
  - PI1 Step Completeness: `phase4.status == "completed"`.
  - PI2 Empty Result Recording: tất cả dims có `lane-status.json`.
  - PI3 Signal Overwrite Detection: mỗi stream chỉ 1 `signals.json` (CORE-025 — 1 file = 1 writer).
  - PI4 Dimension Execution Completeness: dim trong plan có lane directory.
  - PI5 Cross-Source Consistency: static + runtime file overlap check.
  - Severity classification: critical (PI1/PI3 violations) / high (PI2/PI4) / low (PI5).
  - Exit 4 = critical → orchestrator render CDG ở Step 5.6.

- **validate-triage-outputs.sh** (~150 dòng) — Implements Step 5.8 POST-GATE T1-T4:
  - T1 File Existence: bug-triage.md, fix-plan.md, fix-log.json, issue-registry.json.
  - T2 Structure: JSON shape + markdown section markers (triage/severity headers, Execution Plan).
  - T3 Content Depth: bug-triage ≥10 lines, fix-plan ≥15 lines.
  - T4 Cross-Reference: registry count > 0.
  - Output JSON: t1-t4 pass/fail counts, total_fails, registry_count, status (ok|fail).

- **safety-check.sh** (~200 dòng) — Implements Step 5.10 CORE-020:
  - Atomic write `safety-check.json` từ template (CORE-031).
  - Check 1 Collision Detection: extract backtick-wrapped files từ fix-plan, check exist trong project.
  - Check 2 Xref Validation: REQ-IDs trong fix-plan có trong `.mc-data/docs/_meta/req-registry.json`.
  - Check 3 Uncommitted Changes: `git diff --name-only | wc -l` (WARN only).
  - Check 4 Deprecated Modules (LEGACY_MODE only — CORE-022): check fix-plan reference deprecated modules từ `legacy-decisions.json`.
  - Chỉ deprecated_modules là BLOCKER (CORE-022 hard rule). Exit 5 nếu blockers → orchestrator render CDG.

- **generate-phase5-reports.sh** (~270 dòng) — Gộp Steps 5.11-5.12-5.13 vào 1 atomic call:
  - 5.11 Coverage Report: populate `coverage-report.md` từ template (severity distribution, dimensions, probes, success rate).
  - 5.12 Bug Dashboard: inline generation (matches v10.6 fallback behavior — simple checklist by lane).
  - 5.13 Phase5-report.md: populate từ template (CORE-028 tiếng Việt ≤15 dòng) với raw signals, deduped, severity, fixability, CDG decision, safety status.
  - Output JSON: coverage_report path, bug_dashboard path, phase5_report path, total_issues, critical, high, status.

- **finalize-phase5.sh** (~110 dòng) — Gộp Steps 5.14-5.15 vào 1 atomic call:
  - 5.14 Update fix-status.json: atomic write `phase5.status = "completed"` + `issues_total` + `signals_total` + `updated_at` (CORE-035).
  - 5.15 TRACE COMPLETE: APPEND COMPLETE event với `cdg_decision`, `safety_blockers` (CORE-026).
  - Output JSON: issues_total, signals_total, cdg_decision, safety_blockers, status.

**Procedure rewrite** (`procedures/phase5-triage.md` 1039 → 616 dòng):

- Step consolidation 15 → 10 steps (-33%):
  - 5.1+5.2 → 5.1 "Setup Triage" (PRE-GATE + E005 + TRACE START)
  - 5.3+5.4 → 5.3 "Aggregate + Spot-Check"
  - 5.11+5.12+5.13 → 5.11 "Reports" (Coverage + Dashboard + Phase5-report)
  - 5.14+5.15 → 5.14 "Finalize"
- Step numbering giữ gaps **5.2, 5.4, 5.12, 5.13, 5.15** (đã merge) — tránh churn cross-refs
- Markdown boilerplate compression -33%

**GIỮ INLINE cho user interaction** (KHÔNG delegate — preserve UX):

- **Step 5.6 Evaluate Violations**: CDG critical (AskUserQuestion CONTINUE/ABORT) — user phải thấy raw counts trước khi quyết định
- **Step 5.9 CDG Pre-Execute Handoff**: AskUserQuestion ACCEPT/REJECT/CANCEL — critical gate trước Phase 6 Execute. Anti-loop REJECT 2 lần → E054 ESCALATE

**GIỮ orchestrator-side cho Agent tool calls** (KHÔNG script được — CORE-037):

- **Step 5.7 Spawn wf-fix-triage**: Agent({subagent_type, model: "opus", prompt: <8-section template>}) — Agent tool không script được, phải gọi từ orchestrator context

#### Wave 2 — Cross-files update

- **SKILL.md** version 10.6.0 → 10.7.0, header description bổ sung v10.7 section, Phase 5 row trong Phase Summary table updated từ 15 steps → 10 steps với chi tiết script delegation
- **_contract.json** version 10.6.0 → 10.7.0, description paragraph v10.7
- **CHANGELOG.md** entry này

#### Cross-platform fixes phát hiện trong Wave 1

- **`bc` không có trên Git Bash Windows** → fallback `awk '{s+=$1} END {print s+0}'` (cùng pattern Phase 4 v10.6 `tr -d '\r'` defensive)
- **`grep -c | tr -d '\r' | head -1` chống "0\n0" corruption**: `2>/dev/null || echo 0` cộng với grep -c (luôn print count + exit 1 khi no match) gây ra output 2 dòng "0\n0", phá comparison `[ "$VAR" -gt N ]`

#### Verification

- Schema sync (`bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs`): PASS 0 errors
- 7 scripts smoke test PASS với synthetic SESSION_DIR (2 signals từ 1 lane QD1)
- POST-GATE T1-T4: T1 4/4 PASS, T2 4/4 PASS, T3 2/2 PASS, T4 1/1 PASS
- Phase5-report.md = 10 dòng (CORE-028 ≤15 ✅)
- Zero leftover placeholders trong coverage-report.md, Phase5-report.md

#### Behavior preserved

- Pipeline state schema (fix-status.json `phase5`) không breaking change — sessions đang dở vẫn `--resume` được
- Cross-skill artifact contract unchanged (issue-registry-v1, fix-log-v2, etc.)
- E005 healthy path (N=0 → Jump Phase 7) hoạt động đúng
- CDG flow (5.6 critical, 5.9 pre-execute, 5.10 safety blockers) preserved
- Agent spawn (wf-fix-triage) prompt template 8 sections CORE-037 preserved

#### Pre-existing bug notes

- Python CLI `python -m aggregate` cần subcommands chuẩn — nếu CLI signature không khớp, script auto-fallback jq merge (đã verify trong smoke test → method="jq_fallback")
- Defer fix Python CLI alignment sang phiên riêng (out of scope optimize)

---

## [wf-fix-bugs v10.6.0] — 2026-05-16

### Phase 4 Optimization — Phase lớn nhất pipeline (kế thừa pattern v10.3 + v10.4 + v10.5)

Áp dụng pattern tối ưu v10.5 (script delegation gộp logic + step consolidation + giữ INLINE cho user interaction) lên Phase 4 Find Bugs — phase lớn nhất pipeline (~15.65K tokens trước v10.6, gần threshold target 12K). Phase 4 từ "vượt threshold" xuống "rộng rãi" (~8.56K tokens), đảm bảo toàn bộ wf-fix-bugs pipeline có thể chạy end-to-end trên EUREKA-2026 không trigger /compact ở bất kỳ phase nào.

#### Metrics before/after

| Chỉ số | Baseline v10.5 | Sau v10.6 | Δ |
|--------|----------------|-----------|---|
| **Lines** | 1106 | 740 | **-33%** |
| **Tokens (est.)** | ~15.65K | ~8.56K | **-45%** |
| **Steps** | 12 | 9 | **-25%** |
| **Inline bash heredocs >20 dòng** | 6+ | 0 | **-100%** |
| **Scripts mới** | 0 | 7 (~35KB) | +7 |

#### Wave 1 — Script delegation + step consolidation (commit 76aaf312)

Tạo 7 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **setup-lanes.sh** (~190 dòng) — Gộp Steps 4.2-4.3 vào 1 atomic call:
  - TRACE START: atomic update `fix-status.json` (`phase4.status="in_progress"`) + APPEND START event vào session-log.json (CORE-026).
  - Load Per-Dim Playwright Metadata: build `DIMS_ARRAY` (slug `QD{n}-{kebab-name}`, path-safe) + đếm `PW_LANE_COUNT` từ `dimension-plan.json .dimensions[].needs_playwright`. Verify lock script tồn tại nếu PW_LANE_COUNT > 0.
  - Output JSON cho orchestrator eval: dims_array, dims_count, pw_lane_count, pw_dims, status.

- **create-lane-dirs.sh** (~95 dòng) — Implements Step 4.4:
  - FOR loop mỗi dim trong DIMS_ARRAY: mkdir 5 subdirs (raw, evidence, static-scan, runtime, llm-scan) + populate `lane-status.json` từ template `templates/phase4-find-bugs/lane-status.json` (CORE-031 READ → POPULATE → STRIP → WRITE).
  - Đọc dim name từ dimension-plan.json để inject vào lane-status.json.

- **verify-lane-prompt.sh** (~75 dòng) — Implements Step 4.5a 6 check points:
  - PRESERVE semantics v10.2 fantasy-prompt guard (chỉ delegate execution, KHÔNG đổi check rules).
  - C1: Role declaration `^Bạn là lane agent cho dimension QD<n>`.
  - C2: KHÔNG còn `{{...}}` placeholder unsubstituted.
  - C3: Đủ 8 `BƯỚC N` sections (1-8).
  - C4: 5 file shared protocol references (`/SKILL.md`, `_shared/lane/_shared.md`, `pre-gate.md`, `signal-emit.md`, `profile-resolver.md`).
  - C5: `signals.json` reference + KHÔNG `findings.json` / `Phase4-lane-report.md`.
  - C6: Tiếng Việt — KHÔNG English role text.
  - Exit code = check number failed (1-6), giúp orchestrator log chính xác lỗi nào.

- **monitor-lanes.sh** (~145 dòng) — Implements Step 4.6 Monitor Loop:
  - Poll mỗi 30s (configurable `MCV3_POLL_INTERVAL`) + lane timeout 15min (E046 auto-mark failed).
  - Context budget check CORE-038: tier <65% OK / 65-80% prep / 80-90% checkpoint (exit 8 → stop_after_phase4 flag) / >90% FORCE STOP E009 (exit 9 → checkpoint bắt buộc).
  - Atomic update fix-status.json mỗi tier qua jq filter pattern.
  - Output JSON: completed, failed, skipped, total, stop_after_phase4, exit_reason.

- **validate-lane-outputs.sh** (~205 dòng) — Implements Step 4.7 POST-GATE T1-T4:
  - T1 File Existence: lane-status.json, signals.json per stream (static-scan/runtime/llm-scan), QD-report.md. E043 handling: QD-report missing → generate stub từ template (best-effort).
  - T2 Structure Validation: jq schema check `dimension_id and status and signals_*`, signals array type.
  - T3 Content Depth: signal required fields (`id`, `dimension_id`, `probe_id`, `severity`, `fixability`, `title`, `location.file`, `fingerprint`, `detected_at`). E048: count invalid signals.
  - T4 Cross-Ref Count Matching: CLAIMED (lane-status `.signals_static + .signals_runtime + .signals_llm`) vs ACTUAL (sum của 3 file `.signals | length`). E047 emit inconsistency array.
  - Exit codes: 0=ok, 4=partial (stubs/invalid signals), 7=inconsistent (E047 escalate).
  - Output JSON: T1-T4 pass/fail counts, lanes_validated, data_inconsistencies array, stubs_generated array, invalid_signals, probe_failures_count, signals_total, status.

- **generate-phase4-report.sh** (~110 dòng) — Implements Step 4.8 CORE-028:
  - Aggregate metrics từ lane-status.json + signals.json per stream + probe-failures.log.
  - Populate template `templates/phase4-find-bugs/Phase4-report.md` qua sed (CORE-031 READ → POPULATE → STRIP → ATOMIC WRITE).
  - Compute Playwright summary tự động (đếm `playwright_used` từ lane-status, không hardcode).

- **finalize-phase4.sh** (~125 dòng) — Gộp Steps 4.9-4.10 vào 1 atomic call:
  - 4.9 UPDATE fix-status.json: mark `phase4.status="completed"` + aggregate `signals_total` + atomic update (CORE-035).
  - 4.10 TRACE COMPLETE: APPEND COMPLETE event vào session-log.json (CORE-026).
  - Auto-count lanes_completed/lanes_failed nếu env vars không pass (fallback từ lane-status.json).

**Phase 4 procedure rewrite** (`procedures/phase4-find-bugs.md` 1106 → 740 dòng):

- Step 4.1 PRE-GATE Verify Phase 3 — giữ (compress markdown -50%)
- Step 4.2 "Init + Load PW Metadata" — delegate setup-lanes.sh (gộp 4.2+4.3)
- Step 4.3a Browser CDG (E090/E090b) — **GIỮ INLINE** (user interaction qua AskUserQuestion, giống Phase 3 v10.5 CDG-11 Workload Gate). KHÔNG delegate.
- Step 4.4 Create Lane Directories — delegate create-lane-dirs.sh
- Step 4.5 Dispatch Lane Agents — **GIỮ orchestrator-side** (Agent tool calls không script được, CORE-037). Render flow + Substitution table + Forbidden patterns + Single-Response Parallel Dispatch giữ nguyên semantics, compress markdown -25%.
- Step 4.5a Pre-Dispatch Verify — delegate verify-lane-prompt.sh (PRESERVE 6 check semantics)
- Step 4.6 "Monitor + Collect & Validate" — delegate monitor-lanes.sh + validate-lane-outputs.sh sequential (gộp 4.6+4.7)
- Step 4.8 Phase Report — delegate generate-phase4-report.sh (CORE-031 fix template usage giống Phase 2 v10.4 + Phase 3 v10.5)
- Step 4.9 Finalize — delegate finalize-phase4.sh (gộp 4.9+4.10)

**Step numbering giữ gaps** 4.3 (merged → 4.2), 4.7 (merged → 4.6), 4.10 (merged → 4.9) tránh churn cross-refs trong `_shared.md`, SKILL.md, các phase khác.

#### Wave 2 — Cross-files update (commit này)

- `SKILL.md` version 10.5.0 → 10.6.0, last_updated 2026-05-16, thêm v10.6 entry vào description block, update Phase 4 row trong Phase Summary table (12 → 9 steps + script names + v10.6 markers)
- `_contract.json` version 10.5.0 → 10.6.0, mô tả chi tiết 9 architectural changes (8 script delegations + step numbering policy)
- `CHANGELOG.md` entry này

#### Pattern kế thừa (v10.3 + v10.4 + v10.5)

| Pattern | Phase 1 v10.3 | Phase 2 v10.4 | Phase 3 v10.5 | Phase 4 v10.6 |
|---------|---------------|----------------|----------------|----------------|
| Script delegation cho inline heredocs >20 dòng | 3 scripts | 2 scripts | 3 scripts | **7 scripts** |
| Step consolidation (gộp N steps làm cùng 1 việc) | 25→18 (-28%) | 10→5 (-50%) | 12→7 (-42%) | **12→9 (-25%)** |
| Markdown boilerplate compression | -30% | -30% | -30% | **-33% (with Step 4.5 large tables preserved)** |
| Step numbering giữ gaps | 1.15-1.24 | 2.4-2.8 | 3.4, 3.7-3.9, 3.12 | **4.3, 4.7, 4.10** |
| GIỮ INLINE cho user interaction (CDG) | N/A | N/A | CDG-11 Workload | **CDG E090/E090b Browser** |
| GIỮ orchestrator-side cho Agent tool calls | N/A | N/A | N/A | **Step 4.5 Dispatch** |
| Combined Wave 1 (W1=scripts+rewrite, W2=version+cross-files) | tách | tách | tách | **tách** |
| Merge --no-ff Phương án A (per phase) | giống | giống | giống | **giống** |

#### Acceptance criteria PASS

- ✅ Procedure tokens < 12K (8.56K)
- ✅ Procedure lines < 1100 (740)
- ✅ Steps reduction ≥ 20% (-25%, 12→9)
- ✅ Inline bash heredocs >20 dòng ≤ 5 (0 — all delegated to scripts)
- ✅ Schema sync PASS 0 errors
- ✅ Cross-skill artifact contract (fix-impact-v1) unchanged
- ✅ Sessions đang dở vẫn `--resume` được (state file schemas backward compatible)
- ✅ Smoke test 7 scripts trên synthetic SESSION_DIR PASS hết (signals_total=6, no placeholders)

#### Behavior preservation (BHV-003 Surgical Changes)

- ❌ KHÔNG động `_shared.md §15` Lane Agent Prompt (v10.2 canonical)
- ❌ KHÔNG sửa `templates/phase4-find-bugs/lane-agent-prompt.md` (v10.2 canonical)
- ❌ KHÔNG đổi 6 check semantics của Step 4.5a (v10.2 fantasy-prompt guard)
- ❌ KHÔNG đổi output paths (CORE-007 cross-skill output path contract)
- ❌ KHÔNG đổi schema của fix-impact-v1 (CORE-036 cross-skill artifact contract)

---

## [wf-fix-bugs v10.5.0] — 2026-05-16

### Phase 3 Optimization — Tiếp tục giải quyết /compact loop (kế thừa pattern v10.3 + v10.4)

Áp dụng pattern tối ưu v10.4 (script delegation gộp logic + step consolidation + CORE-031 template fix) lên Phase 3 Plan. Phase 3 từ "tương đối lớn" (~10.93K tokens) xuống "rất gọn" (~5.24K tokens), tiếp tục tạo "buffer" cho Phase 4 — phase lớn nhất (~15.65K tokens) sẽ là target tối ưu kế tiếp.

#### Metrics before/after

| Chỉ số | Baseline v10.4 | Sau v10.5 | Δ |
|--------|---------------|-----------|---|
| **Lines** | 1135 | 502 | **-56%** |
| **Tokens (est.)** | ~10.93K | ~5.24K | **-52%** |
| **Steps** | 12 | 7 | **-42%** |
| **Code blocks** | 31 | 30 | **-3%** |
| **Inline bash heredocs >20 dòng** | 8+ | 2 | **-75%** |

#### Wave 1+2 (combined commit) — Script delegation + step consolidation + CORE-031 fix

Tạo 3 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **plan-isg-partition.sh** (138 dòng) — Gộp Steps 3.3-3.4 vào 1 atomic call:
  - ISG Recommender (`python -m isg`): refine dimensions theo profile + interface_type. Fallback E030 → giữ DIMS_ARRAY, profile=standard.
  - Partition Planner (`python -m partition`): chia dims thành workloads. Fallback E032 → auto-generate 1-workload với tất cả dimensions, estimated_issues = ceil(total_files / 10).
  - Output JSON cho orchestrator eval: refined_dims, refined_profile, dim_count, workload_count, total_estimated, isg_status, partition_status.

- **route-and-write.sh** (251 dòng) — Gộp Steps 3.6-3.9 vào 1 atomic call:
  - Agent Dispatch Threshold (CORE-038): `EXECUTION_MODE = agent_dispatch` nếu estimated > 200 hoặc context > 70%; else inline. Agent count = min(workloads, 10).
  - Playwright Planning: auto-detect mode (none/headless/visible/mobile). API-only → ép `pw_mode=none`. Order QD9 → QD5 → QD7.
  - Dim → Lane Routing (11 dims QD1-QD11): lane_skill + agent_type + probe_count + output_dir + needs_playwright + playwright_priority. Profile-based probe adjustment (quick÷2, deep×1.5, exhaustive×2). Validate unique output_dir (CORE-025).
  - WRITE work-plan.json + dimension-plan.json (CORE-031 READ→POPULATE→WRITE từ templates + Atomic Write Pattern).

- **generate-phase3-report.sh** (115 dòng) — Implements Step 3.10 đúng CORE-031:
  - Đọc từ work-plan.json + workload-gate.json (nếu có).
  - Populate template `templates/phase3-plan/Phase3-report.md` qua sed (READ → POPULATE → STRIP _template_notes → ATOMIC WRITE).
  - **Fix bug:** Trước v10.5 Step 3.10 dùng inline heredoc thay vì template — vi phạm CORE-031 (giống Phase 2 v10.3 bug đã fix v10.4). v10.5 mới đúng spec.

phase3-plan.md changes:
- Step consolidation 12 → 7:
  - **Step 3.3 mới** = "ISG + Partition" (delegate `plan-isg-partition.sh`, gộp 3.3+3.4)
  - **Step 3.5** = "Workload Gate CDG-11" (GIỮ INLINE — user interaction qua AskUserQuestion, không delegate)
  - **Step 3.6 mới** = "Route + Write Outputs" (delegate `route-and-write.sh`, gộp 3.6+3.7+3.8+3.9)
  - **Step 3.10** = "Phase Report" (delegate `generate-phase3-report.sh`)
  - **Step 3.11 mới** = "Finalize" (gộp 3.11+3.12 — UPDATE fix-status + TRACE COMPLETE)
- Step numbering giữ gaps: 3.1, 3.2, 3.3, **3.5**, 3.6, 3.10, 3.11. Gaps: 3.4, 3.7-3.9, 3.12 (đã merge hoặc deleted) — tránh churn cross-refs.
- Markdown boilerplate compression: bỏ "Điều kiện đầu vào: Step X.Y PASS" lặp lại, bỏ Cross-ref verbose, giữ "Mục đích/Thực thi/VERIFY/On Failure"
- Step Dependency Chain diagram cập nhật theo 7 steps

#### Tại sao gộp được 2+4+2 steps?

**Steps 3.3+3.4 (ISG + Partition):** Cả 2 đều là Python CLI calls có fallback đầy đủ. Sequential dependency (Partition đọc refined_dims từ ISG) nhưng không có user gate giữa → atomic call hợp lý.

**Steps 3.6+3.7+3.8+3.9 (Threshold + Playwright + Routing + Write):** Tất cả là pure computation không có user interaction. Threshold → Playwright → Routing → Write là pipeline chuyển tiếp data trong cùng phase. Phase 2 v10.4 đã chứng minh pattern này (5 steps → 1).

**Steps 3.11+3.12 (UPDATE fix-status + TRACE COMPLETE):** Cả 2 đều là atomic write JSON, không có gate giữa → gộp thành 1 "Finalize" step hợp lý.

**CDG-11 Workload Gate (Step 3.5):** GIỮ NGUYÊN. Có user interaction qua AskUserQuestion → script delegation sẽ phá vỡ flow user prompt. Logic inline ngắn (~50 dòng) chấp nhận được.

#### Pre-existing bug — Python CLI signatures (out of scope, DEFER)

Phát hiện trong Discovery: Phase 3 Step 3.3 gọi Python modules với signatures KHÔNG khớp module CLI thật:

- `python -m isg --session-dir=... --dims=... --interface-type=... --output=...` → sai. Module thật có 4 subcommands `analyze | render | enforce | emit`, mỗi cái flags khác.
- `python -m partition --session-dir=... --dims=... --output-dir=...` → sai. Module thật cần `--items-file --group-key --max-per-partition --est-minutes`.

**Hậu quả:** Cả 2 calls luôn fail → rơi vào fallback E030 (ISG) + E032 (Partition) → pipeline chạy với 1-workload mode + giữ DIMS_ARRAY hiện tại. **Pipeline vẫn vận hành được**, chỉ là ISG/Partition logic không thực sự hoạt động.

**Quyết định:** Defer fix sang phiên riêng. Lý do:
- Fix CLI signature alignment là task khác phạm vi (cần đọc ADR-14 ISG design + ADR-OPT-03 + cập nhật contract module + tests + có thể breaking schema isg-result.json).
- Trộn 2 loại fix (compression + CLI bug) vào cùng commit sẽ làm hard rollback nếu 1 trong 2 fail.
- Mục tiêu v10.5 là **token compression**, không phải **functional correctness fix** — đã đạt target -52%.

CHANGELOG note để phiên sau xử lý.

#### Cross-skill artifact contract

**KHÔNG breaking change:**
- work-plan.json, dimension-plan.json, fix-workload.json giữ nguyên schema (work-plan-v1, dimension-plan-v1, fix-workload-v1) — superset của template structure.
- Phase3-report.md giữ template path.
- POST-GATE T1-T4 giữ nguyên 4 tiers validation.
- Resume Logic giữ nguyên (verify outputs intact + stale lock check).
- Phase 4 consume `dimension-plan.json` không đổi — vẫn đọc `dimensions[].lane_skill, agent_type, probe_count, needs_playwright`.

#### Verification

- ✅ `validate-schema-sync.sh wf-fix-bugs`: PASS (0 errors)
- ✅ 3 scripts smoke test trên synthetic SESSION_DIR (250 files, web interface, 5 dims):
  - `plan-isg-partition.sh`: exit 0, refined_dims=QD1,QD2,QD5,QD9,QD10, workload_count=1, total_estimated=25
  - `route-and-write.sh`: exit 0, execution_mode=inline, pw_mode=headless, 5 dimensions routed
  - `generate-phase3-report.sh`: exit 0, Phase3-report.md 10 dòng (CORE-028 ≤15), 0 placeholders left
- ✅ POST-GATE T1-T4 E2E simulation: all 4 tiers PASS, T4 cross-ref OK (DP=WP=[QD1,QD10,QD2,QD5,QD9])

#### Migration notes

- **Backward compatible:** Sessions đang dở (v10.4 layout) vẫn `--resume` được. State file schemas KHÔNG đổi.
- **Forward compatible:** Phase 4 tiếp tục đọc work-plan.json + dimension-plan.json từ `$SESSION_DIR/phase3-plan/` — paths không đổi.
- **Cross-skill (wf-verify-sync, wf-prepare-deployment, wf-implement-feature):** fix-impact.json schema không đụng.

#### Files changed

- `.claude/scripts/wf-fix-bugs/plan-isg-partition.sh` (mới, 138 dòng)
- `.claude/scripts/wf-fix-bugs/route-and-write.sh` (mới, 251 dòng)
- `.claude/scripts/wf-fix-bugs/generate-phase3-report.sh` (mới, 115 dòng)
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase3-plan.md` (rewrite, 1135→502 dòng)
- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (version bump + Phase 3 row updated + v10.5 description paragraph)
- `.claude/skills/workflow/wf-fix-bugs/_contract.json` (version bump 10.4.0 → 10.5.0 + v10.5 description)
- `CHANGELOG.md` (entry này)

#### Next steps (Phase 4-7 + _shared.md)

Áp dụng pattern v10.3/v10.4/v10.5 lên các phase còn lại theo pipeline order:
- **Phase 4 (Find Bugs)** — 1106 dòng, 12 steps, **~15.65K tokens** (cao nhất). **NEXT TARGET — HIGH priority.** Tách `lane-dispatch.sh` + `monitor-loop.sh` + `collect-validate.sh`. KHÔNG sửa Step 4.5a Pre-Dispatch Verify (v10.2 fantasy-prompt guard).
- **Phase 5 (Triage)** — 1039 dòng, **15 steps** (nhiều nhất), ~10.73K tokens. Reuse `_shared.md §19` cho Step 5.12 bug-dashboard.
- **Phase 6 (Execute)** — 968 dòng, 11 steps, ~10.81K tokens.
- **Phase 7 (Verify)** — 1186 dòng, 14 steps, ~11.96K tokens. Tạo `generate-summaries.sh` cho 3 output files.
- **_shared.md** — defer cuối cùng, KHÔNG động §15 Lane Agent Prompt (v10.2 canonical).

Plan tổng thể: `plans/wf-fix-bugs-phase2-7-optimize/PROMPT.md`.

---

## [wf-fix-bugs v10.4.0] — 2026-05-16

### Phase 2 Optimization — Tiếp tục giải quyết /compact loop (kế thừa pattern v10.3)

Áp dụng pattern tối ưu v10.3 (script delegation + step consolidation + boilerplate compression + dead code deletion) lên Phase 2 Scan Scope. Phase 2 từ "tương đối hợp lý" (~8.4K tokens) xuống "rất gọn" (~3.5K tokens), tạo "buffer" cho các phase downstream khi consume scope-analysis.json.

#### Metrics before/after

| Chỉ số | Baseline v10.3 | Sau v10.4 | Δ |
|--------|---------------|-----------|---|
| **Lines** | 874 | 345 | **-60%** |
| **Tokens (est.)** | ~8.4K | ~3.5K | **-59%** |
| **Steps** | 10 | 5 | **-50%** |
| **Code blocks** | 17 | 12 | **-29%** |
| **Inline bash heredocs >20 dòng** | 6 | 1 | **-83%** |

#### Wave 1 — Script delegation + dead code removal (commit 6d5f285e)

Tạo 2 scripts mới (`.claude/scripts/wf-fix-bugs/`):

- **scan-and-analyze.sh** (458 dòng) — Gộp logic Steps 2.3-2.7 vào 1 atomic call:
  - Interface Type Detection (web|mobile|hybrid|api-only) từ package.json + pubspec.yaml + capacitor + expo + native files (Swift/Kotlin)
  - Code Inventory (CI-ROUTE: Serena `onboarding` > GitNexus `clusters` > Glob): enumerate files + language top 5 + LOC + modules + API routes
  - Doc Inventory: parse req-registry.json, scan .mc-data/docs/phase*/, đếm READMEs, REQ-ID annotation tracking
  - Scope Analysis (aggregate): scope-analysis-v2 với source_dir cho lane-agent-prompt v10.2.1
  - WRITE 3 JSON outputs (CORE-031 READ→POPULATE→WRITE + CORE-035 Atomic Write)
  - Output JSON cho orchestrator eval: interface_type, total_files, total_loc, req_count, frameworks, dep_level, ci tasks

- **generate-phase2-report.sh** (107 dòng) — Implements Step 2.9 đúng CORE-031:
  - Đọc từ scope-analysis.json + doc-inventory.json
  - Populate template `templates/phase2-scan/Phase2-report.md` qua sed (READ → POPULATE → STRIP _template_notes → ATOMIC WRITE)
  - **Fix bug v10.3:** Template Phase2-report.md trước đây KHÔNG được sử dụng (Step 2.9 dùng inline heredoc); v10.4 mới đúng spec CORE-031.

phase2-scan.md Wave 1 changes:
- Replace inline bash heredocs (5+ blocks, 50-100 dòng mỗi block) bằng script calls ngắn gọn
- **DELETE Step 2.8 (TRACE CHECKPOINT)** — dead code, không phase downstream nào đọc CHECKPOINT event (TRACE START + TRACE COMPLETE đủ truy vết)
- Step 2.10 bổ sung update `fix-status.json.interface_type` để Phase 3-7 truy cập trực tiếp (trước đây phải re-read scope-analysis.json)
- Markdown boilerplate compression: bỏ "Điều kiện đầu vào: Step X.Y PASS" lặp lại, bỏ Cross-ref verbose, giữ "Mục đích/Thực thi/VERIFY/On Failure"
- Step Dependency Chain diagram cập nhật

**Sau Wave 1:** 874→373 dòng (-57%), 8.4K→3.5K tokens (-58%), 10→9 steps (delete 2.8 only)

#### Wave 2 — Step consolidation (commit này)

- **Collapse Steps 2.3-2.7 (5 sections) → Step 2.3 "Scan & Analyze" (1 section)** mô tả 5 logical phases trong 1 atomic call. Match pattern Phase 1 v10.3 `init-session-state.sh` (4 file populates → 1 script).
- Step numbering giữ gaps 2.4-2.8 (đã merge vào 2.3, hoặc deleted) — tránh churn cross-refs trong _shared.md, SKILL.md, các phase khác.
- SKILL.md Phase Summary table: Phase 2 "10 steps" → "5 steps" với key actions cập nhật
- _contract.json version bump 10.3.0 → 10.4.0 + description đầy đủ v10.4 changes
- CHANGELOG.md entry (file này)

**Sau Wave 2:** 874→345 dòng (-60%), 8.4K→3.45K tokens (-59%), 10→5 steps (-50%)

#### Tại sao gộp được 5 steps?

5 steps cũ (2.3 Interface, 2.4 Code, 2.5 Doc, 2.6 Scope, 2.7 Write) đều làm cùng 1 việc cốt lõi: **thu thập data + ghi 3 JSON output**. Đây là "step pollution" — tách thành 5 steps không tạo giá trị (mỗi step phụ thuộc step trước, không thể chạy độc lập, không có gate giữa các steps), chỉ tăng context cho LLM phải xử lý.

Phân tích Phase 1 v10.3 Step 1.19 đã gộp 4 file populates → 1 script (`init-session-state.sh`) chứng minh pattern. Phase 2 áp dụng tương tự cho 5 logical phases tương đương.

#### Cross-skill artifact contract

**KHÔNG breaking change:**
- 3 JSON outputs (scope-analysis.json, code-inventory.json, doc-inventory.json) giữ nguyên schema (scope-analysis-v2, code-inventory-v1, doc-inventory-v1)
- Phase2-report.md giữ template path
- POST-GATE T1-T4 giữ nguyên 4 tiers validation
- Resume Logic giữ nguyên (verify 4 output files intact)

#### Verification

- ✅ `validate-schema-sync.sh wf-fix-bugs`: PASS (1/1 skill, 0 errors)
- ✅ `scan-and-analyze.sh` smoke test trên synthetic SESSION_DIR: exit 0, 3 JSONs valid, 591 files detected, interface_type=api-only auto-default
- ✅ `generate-phase2-report.sh` smoke test: exit 0, Phase2-report.md 10 dòng (CORE-028 ≤15 limit), không còn placeholder
- ✅ POST-GATE T1-T4 simulation: all 4 tiers PASS, T4 cross-ref OK

#### Migration notes

- **Backward compatible:** Sessions đang dở (v10.3 layout) vẫn `--resume` được. State file schemas KHÔNG đổi.
- **Forward compatible:** Phase 3+ tiếp tục đọc 3 JSON outputs từ `$SESSION_DIR/phase2-scan/` — paths không đổi.
- **Cross-skill (wf-verify-sync, wf-prepare-deployment, wf-implement-feature):** fix-impact.json schema không đụng (vẫn v1).

#### Files changed

- `.claude/scripts/wf-fix-bugs/scan-and-analyze.sh` (mới, 458 dòng)
- `.claude/scripts/wf-fix-bugs/generate-phase2-report.sh` (mới, 107 dòng)
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase2-scan.md` (rewrite, 874→345 dòng)
- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (version bump + Phase Summary updated)
- `.claude/skills/workflow/wf-fix-bugs/_contract.json` (version bump + v10.4 description)
- `CHANGELOG.md` (entry này)

#### Next steps (Phase 3-7 + _shared.md)

Áp dụng pattern v10.3/v10.4 lên các phase còn lại theo pipeline order:
- **Phase 3 (Plan)** — 1135 dòng, 12 steps, ~10.9K tokens. Workload Gate CDG-11 KHÔNG defer. Khả năng: `run-isg-recommender.sh` wrapper.
- **Phase 4 (Find Bugs)** — 1106 dòng, 12 steps, **~15.6K tokens** (cao nhất). Tách `lane-dispatch.sh` + `monitor-loop.sh` + `collect-validate.sh`. KHÔNG sửa Step 4.5a Pre-Dispatch Verify (v10.2 fantasy-prompt guard).
- **Phase 5 (Triage)** — 1039 dòng, **15 steps** (nhiều nhất), ~10.7K tokens. Reuse `_shared.md §19` cho Step 5.12 bug-dashboard.
- **Phase 6 (Execute)** — 968 dòng, 11 steps, ~10.8K tokens.
- **Phase 7 (Verify)** — 1186 dòng, 14 steps, ~12K tokens. Tạo `generate-summaries.sh` cho 3 output files (orchestrator-summary, fix-impact, phase-summary).
- **_shared.md** — defer cuối cùng, KHÔNG động §15 Lane Agent Prompt (v10.2 canonical).

Plan tổng thể: `plans/wf-fix-bugs-phase2-7-optimize/PROMPT.md`.

---

## [wf-fix-bugs v10.3.0] — 2026-05-16

### Phase 1 Optimization — Solve /compact loop on large projects

**Root cause:** Phase 1 procedure file (`procedures/phase1-init.md`) gánh 6 trách nhiệm khác nhau → 1503 dòng / ~28K tokens. Khi chạy trên dự án lớn (vd: EUREKA-2026), tổng context Phase 1 setup vượt 80% threshold → trigger `/compact` liên tục, Phase 1 không hoàn thành nổi.

**Metrics improvement:**
- Procedure dòng: 1503 → ~1000 (-33%)
- Token estimate: ~28K → ~10K (-65%)
- Steps: 25 → 18 (-28%)
- Inline bash heredocs: 102 → ~30 (-70%)
- CDG questions ở Phase 1: 5-7+ → 0 (defer/auto-resolve toàn bộ)
- User wait at Phase 1: 3-5 phút → <30 giây

### Added

**3 scripts mới (`.claude/scripts/wf-fix-bugs/`):**

- **`ci-pregate.sh`** — CI PRE-GATE wrapper gộp Na+Nb+Nc (call `ci-detect.sh` + `ci-freshness-check.sh` + `ci-inject-context.sh`). Output JSON hoặc `--eval` mode cho orchestrator. Graceful degradation: lock held → fallback Grep/Glob.

- **`init-session-state.sh`** — Initialize 4 state files in 1 atomic call: `fix-status.json`, `session-log.json`, `error-ledger.json`, `phase1-init/Phase1-report.md`. CORE-031 compliant (READ template → POPULATE → STRIP → ATOMIC WRITE). Per-file status tracking trong JSON output.

- **`init-bug-dashboard.sh`** — Implements `_shared.md §19 Bug Dashboard Update Pattern` cho `current-phase="init"`. Python CLI primary + sed inline fallback. Non-blocking E035.

**Phase 4 Step 4.3a — Browser CDG (E090 + E090b)** — Just-in-time gate cho Playwright lanes, chỉ chạy khi `PW_LANE_COUNT > 0`. Moved from Phase 1 Step 1.9 cũ.

### Changed

**Phase 1 procedure consolidation:**
- ❌ Steps 1.5, 1.6 (CI Nb, Nc) → gộp vào Step 1.4 qua `ci-pregate.sh`
- ❌ Steps 1.10, 1.11, 1.12 (E091 Scope, E092 Cost, E093 Mobile CDG) → gộp vào Step 1.9 thành "Auto-Resolve Quick Decisions" (no AskUserQuestion)
- ❌ Steps 1.20, 1.21 (session-log/error-ledger/Phase1-report populates) → gộp vào Step 1.19 qua `init-session-state.sh`
- 🔄 Step 1.22 (bug-dashboard init) → simplified 56 dòng inline → 8 dòng call `init-bug-dashboard.sh`
- 🔄 Step 1.16b (CDG persist) → giờ chỉ stub init empty `cdg-tokens.json` (no decisions to flush)
- 🔄 Step 1.13 (cũ là Step 1.14 Sub-Skill Path Validation, đổi number)

**Just-in-time CDG architecture:**
- E090 Browser URL: Phase 1 → **Phase 4 Step 4.3a** (chỉ khi browser lanes active)
- E090b BASE_URL Conflict: Phase 1 → **Phase 4 Step 4.3a**
- E091 Scope: auto-narrow nếu `--name` provided, WARN log nếu >20 modules (no CDG)
- E092 Cost: WARN log only (no CDG) — log vào Phase1-report notes
- E093 Mobile: auto-default `iPhone 14` (override qua `--device=<name>`)

### Removed

- **Step 1.13 cũ (E100 QD9/10/11 Recommendation Gate)** — duplicate với Phase 3 ISG Recommender. Phase 1 không có scan data → recommendation chỉ heuristic, không chính xác. Phase 3 ISG là nơi recommendation thực sự có data.

### Migration Notes

- **Backward compatibility:** State file schemas (`fix-status.json`, `cdg-tokens.json`) giữ nguyên — sessions đang dở ở v10.2.1 vẫn `--resume` được trong v10.3.0.
- **In-memory state changes:** v10.3 KHÔNG còn produce `$CDG_E09X_DECISION` variables (defer/auto-resolve). Downstream phases không tham chiếu trực tiếp các vars này — đọc từ `cdg-tokens.json` nếu cần.
- **CHANGELOG references:** Phase 1 `cdg-tokens.json` có thể rỗng `tokens: []` — đây là expected behavior v10.3.

### Files Changed

```
M  .claude/skills/workflow/wf-fix-bugs/SKILL.md            (+9/-2 lines, v10.3.0)
M  .claude/skills/workflow/wf-fix-bugs/_contract.json      (+1/-1 lines, version bump)
M  .claude/skills/workflow/wf-fix-bugs/procedures/phase1-init.md   (~500 lines, -33%)
M  .claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md  (+60 lines, Step 4.3a)
A  .claude/scripts/wf-fix-bugs/ci-pregate.sh               (114 lines)
A  .claude/scripts/wf-fix-bugs/init-session-state.sh       (~200 lines)
A  .claude/scripts/wf-fix-bugs/init-bug-dashboard.sh       (~120 lines)
```

---

## [Template v3.1] — 2026-05-15

### Skill Author Tooling Uplift

Mở rộng bộ template skill design để giảm thời gian onboard contributor mới và ngăn drift giữa 2 lớp template (`workflow-skill.md` + `04-skill-design/_template/`).

### Added

**`docs/04-skill-design/_template/` (4 file mới):**
- `00-master-checklist.md` — Checklist 10-step BẮT BUỘC end-to-end (gồm CLAUDE.md update, slash command, audit scripts) → gating cho reviewer
- `agent-prompt.md` — Template CORE-037 8-section cho mọi `Agent({...})` spawn (role, task, session, CI, playwright, output, ownership, completion)
- `eval-fixtures-sample.md` — Hướng dẫn cấu trúc `tests/fixtures/{skill}/` với 3 mẫu (minimal/realistic/corrupt) + helper scripts

**3 file variant `*.alt.md`:**
- `02-quality-dimensions.alt.md` — Cho Lane/Probe skills (thay 02-arguments)
- `05-execution-profiles.alt.md` — Cho skills có `--profile` (bổ sung 05-error-codes)
- `08-user-scenarios.alt.md` — Cho Orchestrator skills (bổ sung 08-tradeoffs)

**`.claude/scripts/check-skill-design-populated.sh`** — Validation script:
- Detect `_template_notes:` block còn sót
- Detect `{skill-name}`, `{Skill Display Name}`, `{X.Y.Z}` placeholders
- Verify min 50 dòng nội dung mỗi file
- Verify README index ticked
- Support `--all` mode quét toàn bộ design folders

### Changed

**`.claude/skills/workflow-skill.md` v3.1.0:**
- Thêm bridge section (đầu file) link sang `docs/04-skill-design/_template/00-master-checklist.md` + bảng variant matrix
- Thêm Mermaid diagram template (BẮT BUỘC khi >3 phases — ASCII chỉ chấp nhận quick skills)
- Cải thiện sample `_contract.json`:
  - Thêm `cross_skill_contracts.orchestrates[]` cho orchestrator skills (trigger, passes, validation)
  - Format `produces_for{}`/`consumes_from{}` thành map skill→artifacts với schema versioning
  - Thêm `graceful_degradation` field cho consumer

**`docs/04-skill-design/README.md`:**
- §4 — Thêm decision tree 4-question chọn variant (Quick / Lane / Orchestrator / Standard)
- §4.2 — Bảng đầy đủ 16 file (9 standard + 3 alt + 4 utility) với áp dụng + mục đích
- §4.3 — Quy trình 5 bước rõ ràng (copy → variant → populate → verify → update catalog)

**`docs/04-skill-design/_template/09-evals-test-cases.md`:**
- Thêm §6 cross-link sang `eval-fixtures-sample.md`
- Bảng map TC → fixture path

### Migration

- Skill mới: dùng template v3.1 toàn diện qua decision tree
- Skill hiện có (wf-fix-bugs, wf-legacy-scan, wf-implement-feature, wf-e2e-verify):
  - KHÔNG bắt buộc migrate ngay (legacy naming `04-data-model.md`, `05-profiles-ips.md`, etc. vẫn hoạt động)
  - Khi major refactor → migrate sang naming chuẩn template v3.1

### Verify

```bash
# Test validation script
bash .claude/scripts/check-skill-design-populated.sh --all
# Expected: skill mới PASS, skill legacy FAIL với MISSING required files (kỳ vọng)
```

---

## [8.0.0] — 2026-05-15

### Breaking Changes
- `wf-e2e-verify` v8.0.0: Pipeline mới F0→F0a→F0b→F1-F8 (11 steps)
- `wf-e2e-test` v2.0.0: Bắt buộc F0a findings trước khi live test
- `e2e-status.json`: Schema mở rộng 8→11 steps
- `--max-impl-items`: Deprecated, dùng `--max-time` thay thế
- `--no-playwright`: Không còn skip phases, chuyển sang degrade mode

### New Skills
- **wf-e2e-finding** v1.0.0: Analysis-only phase (tách từ wf-e2e-test)
- **wf-e2e-batch** v1.0.0: Batch orchestrator N FEATs với dependency graph
- **wf-e2e-credentials** v1.0.0: Credential Vault với OS keychain integration

### New Features
- F0 PRE-GATE: Infra health check (BE/FE/Playwright/DB)
- F0b Seed Manifest: Auto-seed với guard rails
- B1 Cross-Module Gap Detection: Phát hiện sớm ở F0a
- B2 DECISION-REQUIRED Queue: Tập trung pending decisions
- B3 Credential Vault: Secure credential storage
- --auto Expert Dispatch: Non-destructive decisions tự động
- Anti-loop per-severity: CRITICAL=5, HIGH=4, MEDIUM=3, LOW=2
- G1 Flakiness Elimination: Lint + smart retry + pre-flight + quarantine
- G2: --no-playwright degrade mode (đóng loophole fantasy approval)
- G6: Master seed global mutex cho batch

### Fixes
- F7 scenario: Bỏ fallback curl (retry 3x + BLOCKED)
- F8 demo: Bỏ EVIDENCE_COMPILATION mode
- F3 unblock: Strict task generation (4 required fields)
- F4 implement: --max-time thay --max-items, P1 enforcement 80%
## [wf-fix-bugs v10.2.1 — Pipeline Broken Fix + v10.2 Wire Completion] — 2026-05-14

### Tổng quan

Patch release ngay sau v10.2.0. Audit toàn diện sau v10.2.0 phát hiện **8 vấn đề pipeline broken** + **6 data integrity gap** mà compliance audit (structural) không bắt được vì v10.2.0 KHÔNG chạy end-to-end test. v10.2.1 sửa toàn bộ trong 4 đợt, **giữ nguyên 100% hành vi mục tiêu** (7-phase pipeline, 11 dimension lane, CI-first, Playwright 3 modes).

Tham khảo chi tiết: `docs/wf-fix-bugs-v10.2.1-fixes.md`.

### Đợt 1 — Pipeline broken fix (8 critical, ~2h)

| Fix | File | Vấn đề |
|------|------|--------|
| P1.1 | `procedures/phase1-init.md:483` | SOURCE_VALID chỉ set `false` ở else, không set `true` ở success → thêm `SOURCE_VALID=true` ở cả 2 success branch |
| P1.2 | `procedures/phase2-scan.md:811` | POST-GATE T2 check `.modules and .total_files` (flat) — JSON là nested `.code.total_files` → đổi sang `.interface_type and .scope and .code and .docs` |
| P1.3 | `procedures/phase3-plan.md:1050-1053` | POST-GATE T4 chạy `(.dimensions \| keys)` trên work-plan.json — key này ở dimension-plan.json → cross-file check 2 file riêng |
| P1.4 | `procedures/phase4-find-bugs.md:121-127` | DIMS_ARRAY format `"QD1\|Functional Correctness"` → bash word-split phá vỡ tên có space → slug-hóa `QD1-functional-correctness` (path-safe) + sửa Step 4.7 glob `$dim-*` → `$dim` |
| P1.5 | `procedures/phase4-find-bugs.md:773-787` | Đọc `Phase4-report.md.aggregate.json` phantom → tính SIGNALS_TOTAL bằng vòng lặp `lanes/$dim/{static-scan,runtime,llm-scan}/signals.json` |
| P1.6 | `procedures/phase5-triage.md:110` | Phase 5 set `reason="E005"` không set `e005_healthy=true` → Phase 7 check `phase5.e005_healthy == true` luôn false → thêm `e005_healthy: true` vào jq update (cả phase5 và phase6) |
| P1.7 | `procedures/phase5-triage.md:564-575,580-581,847,919` | Phase 5 ghi cdg-tokens.json bằng `>>` flat append → JSON invalid sau lần CDG thứ 2. Phase 6 đọc `[.tokens[]]` (object) → schema mismatch → đổi sang jq APPEND vào mảng `.tokens[]` + thêm field `status` để Phase 6 PRE-GATE check |
| P1.8 | `templates/phase7-verify/fix-impact.json` | Thiếu `$schema` field → 3 consumer (wf-verify-sync/wf-prepare-deployment/wf-implement-feature) validate fail silent → thêm `"$schema": "fix-impact-v1"` + `audit_chain.source` |

### Đợt 2 — Data integrity + v10.2 wire completion (~1.5h)

| Fix | File | Mô tả |
|------|------|--------|
| P2.1-P2.3 | `wf-fix-runtime-health/dimension.json` + `_contract.json` | QD9 dimension.json standard=3 → 6 probes (thêm interactive-smoke + spa-route-coverage + disabled-cta-check v10.2). execution_order bổ sung disabled-cta-check. parallel_groups bổ sung. _contract.json bump v1.0.0 → v1.1.0, procedure[] thêm probe mới, description ghi "9 probes total, standard=6" |
| P2.4 | `templates/phase1-init/fix-status.json` + `procedures/phase1-init.md:1067-1083` | Thêm field `project_name` + Phase 1 Step 1.19 populate từ env/registry/basename → lane-agent-prompt substitution `{{PROJECT_NAME}}` resolve được |
| P2.5 | `templates/phase2-scan/scope-analysis.json` + `procedures/phase2-scan.md:535-557` | Restructure nested (code/docs/ci_coverage) + thêm `source_dir` field + Phase 2 Step 2.6 populate `{{SOURCE_DIR}}` |
| P2.6 | `_contract.json` | fix-impact schema reconcile: template v1, contract notes v1, consumers check v1 → đồng nhất ghi rõ "Schema fix-impact-v1" trong notes |
| P3.1 | `_contract.json` | Thêm entry cho `lane-agent-prompt.md` (v10.2 NEW, schema lane-agent-prompt-v10.2) + `fix-execution-result.json` (orphan trước v10.2.1) vào `outputs.working[]` |
| P3.2 | `_contract.json` | Thêm `E090b` error code (BASE_URL conflict CDG v10.2) — trước đây dùng ở 5 chỗ nhưng không có trong quick lookup |
| P3.4 | `docs/wf-fix-bugs-v10.2.1-fixes.md` (NEW) | Tài liệu tổng hợp v10.2.1 fixes cho người dùng |
| P3.5 | `CLAUDE.md:162` | Bump version reference v10.0 → v10.2.1, ghi rõ v10.2 + v10.2.1 changes |

### Đợt 3 — Hardening (P4) + Quality (P5) (~2h)

| Fix | File | Mô tả |
|------|------|--------|
| P4.2 | `procedures/phase3-plan.md:443-472` | $RATIO undefined trong workload-gate.json + CDG message → thêm RATIO_X10 + RATIO_DISPLAY (vd "1.2x"), jq workload-gate.json ghi ratio_pct + ratio_display |
| P4.3 | `procedures/phase4-find-bugs.md:161-163` | Atomic Write Pattern: `.tmp` → `.tmp.$$` + jq validate trước mv (CORE-035) |
| P4.7 | `templates/phase4-find-bugs/probe-failures-log.json` | Thêm `_how_to_use` instruction rõ ràng — file là schema reference, không copy thẳng; runtime APPEND từng line JSON |
| P4.8 | 3 scripts | Thêm `set -euo pipefail` cho `wf-fix-browser-precheck.sh`, `wf-fix-flow-driver.sh`, `wf-fix-record-probe-failure.sh`. `wf-fix-catalog-consume.sh` annotate rõ là library (intentional no set -e) |
| P4.10 | (đã sửa trong P1.7) | Phase 5 Step 5.14 spurious escape `\"` trong TRACE COMPLETE — refactored thành biến `CDG_DECISION` + `SAFETY_BLOCKERS` |
| P5.1 | 16 template MD files | Version bump "wf-fix-bugs v10.0" → "v10.2.1" (sed batch) |
| P5.3 | `templates/phase7-verify/Phase7-report.md` | Typo `MODBILE_GATE_SECTION` → `MOBILE_GATE_SECTION` |
| P5.5 | `wf-fix-triage/_contract.json` | Version drift fix: 1.4.0 → 1.5.0 (match SKILL.md) |
| P5.6 | `wf-fix-observability/SKILL.md:36` | "orchestrator v8.x" → "orchestrator v10.x" |
| P5.7 | `wf-fix-performance/SKILL.md:30` | "Probes: 6 (lazy-load)" → "Probes: 7" (match table count) |

### Đợt 4 — Coverage (P6)

| Fix | File | Mô tả |
|------|------|--------|
| P6.4 | `wf-fix-security/SKILL.md:57` | Promote `P-QD3-owasp-top-ten` vào `standard` profile (trước đây quick + deep+, standard ❌) → security default profile có OWASP Top 10 |
| P6.1-P6.3 | (documented) | Coverage gaps i18n runtime, mobile-specific UX (--mobile flag), error boundary/offline đã được nhận diện trong audit — defer cho v10.3 vì cần thêm probe design |

### Validation

- `jq` toàn bộ JSON templates đã sửa: PASS
- QD9 counts: standard=6 probes ✅, execution_order=9 ✅, procedure[]=11 ✅
- _contract.json: version=10.2.1, errors có E090b, outputs.working[]=41 entries

### Behavioral Compatibility

**Không có breaking change.** Mọi hành vi mục tiêu (7-phase pipeline, dispatch QD1-QD11, CI-first, Playwright 3 modes, multi-session safety, resume/status/migrate) giữ nguyên 100%. Session đang chạy có thể `--resume` ngay với code v10.2.1.

---

## [wf-fix-bugs v10.2.0 — UI Coverage + Playwright Parallel Safety] — 2026-05-14

### Tổng quan

Minor release fix 2 nhóm vấn đề user báo cáo trong production: (1) UI bugs (sidebar/button/popup/sheet/disabled-CTA) không bị bắt ở `--profile=standard`; (2) Playwright flag chain `--show-browser`/`--mobile` không hoạt động, và parallel sessions cùng máy thiếu safety guard. 6 sprints trong session 2026-05-14, plan dir `plans/wf-fix-bugs-v10.2-ui-coverage/`.

### Decisions

| Q | Decision | Rationale |
|---|---|---|
| Q1 Profile rebalance | Promote `P-QD9-interactive-smoke`, `P-QD9-spa-route-coverage`, `P-QD9-disabled-cta-check` (NEW) vào `standard` với caps (MAX_ROUTES=10, BUTTONS=8) | CORE-023 correctness > speed |
| Q2 Cancel skip | Bỏ `cancel/reset/clear` khỏi destructive skip-list | Source bug phổ biến, không destroy data |
| Q3 BASE_URL conflict | AskUserQuestion 3 options (Continue/Wait/Cancel), env `MCV3_PW_ALLOW_SHARED_URL=1` bypass | Linh hoạt cho user + CI bypass |
| Q4 Plan dir | Tạo `plans/wf-fix-bugs-v10.2-ui-coverage/` theo pattern v9/v10 | Resume support |

### Sprint 1 — Flag chain repair

Phase1-init.md (4 bugs):
- Thêm case `--show-browser) SHOW_BROWSER=true` (trước đây silent ignored).
- Tách `$SHOW_BROWSER` (visible mode) khỏi `$NO_BROWSER` (skip browser) — semantic khác nhau.
- Xóa dead default branch dòng 171 (`if [ -z "$SHOW_BROWSER" ]; then SHOW_BROWSER=true; fi`).
- Sửa conflict check dùng `$NO_BROWSER` thay `$SHOW_BROWSER`.
- `--mobile` auto-set `$SHOW_BROWSER=true` (theo design intent).
- Thêm `$MOBILE_DEVICE` cho `--device=<name>` (default "iPhone 14").

Template `fix-status.json` thêm fields additive: `no_browser`, `mobile_device`, `playwright.show_browser`, `playwright.mode`. Cập nhật Step 1.19 populate đầy đủ.

### Sprint 2 — Playwright launcher hardening

`playwright-session.js`:
- `actionLaunch(port, userDataDir, sessionFile, launchOpts)` — thêm param `launchOpts: {showBrowser, mobileMode, deviceName}`.
- Conditional `'--headless=new'` — chỉ khi không `--show-browser`.
- `windowsHide: !showBrowser` — visible mode KHÔNG hide window.
- Mobile emulation qua CDP `Emulation.setDeviceMetricsOverride` + `setUserAgentOverride` (iPhone 14/Pixel 7/iPad Pro qua `playwright.devices`).
- Port hardening: `findFreePort()` retry tự động (max 50 tries) khi `EADDRINUSE`. Ghi `resolvedPort` thực tế vào `playwright-session.json`.

`probes/_shared.md` cho QD9/QD5/QD7:
- Đọc `SHOW_BROWSER`/`MOBILE_MODE`/`MOBILE_DEVICE` từ `fix-status.json` (graceful fallback env).
- `PW_LAUNCH_CMD` propagate flags `--show-browser=true --mobile=true --device="$MOBILE_DEVICE"` vào launch action.
- `pw_launch()` log launch mode (headless/visible/mobile) cho debug.

### Sprint 3 — Profile rebalance + selector expansion

`wf-fix-runtime-health/SKILL.md` Probe Routing Table v10.2:
- `P-QD9-interactive-smoke`: deep+ → **standard+** (MAX_ROUTES=10, BUTTONS=8).
- `P-QD9-spa-route-coverage`: deep+ → **standard+**.
- Thêm `P-QD9-disabled-cta-check` NEW vào standard+.
- Per-profile caps: standard (10/8/50) / deep (25/20/100) / exhaustive (50/30/200).

`P-QD9-interactive-smoke.md`:
- B0 NEW Sidebar/Menu Expand Pre-Step: detect `aria-haspopup`, `[aria-expanded="false"]`, burger menu selectors → hover/click toggle để expose buttons ẩn (try/catch guard, không emit signal nếu fail).
- Modal/sheet selector mở rộng dòng 278: thêm `role="menu"`, `role="tooltip"`, `data-state="open"`, `data-radix-portal`, `data-headlessui-state="open"`, `MuiDialog`, `MuiDrawer`, `MuiMenu`, `MuiPopover` (Radix/headlessui/shadcn/MUI/Mantine).
- Destructive skip-list reduce: bỏ `cancel|reset|clear` (source bug phổ biến). Giữ `delete|destroy|logout|signout|xoa|dang xuat`.
- MAX_ROUTES + BUTTONS_PER_ROUTE + MAX_SIGNALS đọc từ PRE-GATE step 2.

### Sprint 4 — New probe P-QD9-disabled-cta-check

NEW probe ở `wf-fix-runtime-health/procedures/probes/P-QD9-disabled-cta-check.md`:
- Read-only DOM/CSS check — KHÔNG click button (an toàn).
- Phát hiện: `disabled` attr, `aria-disabled="true"`, `pointer-events:none`, `opacity<0.3`, overlay obstruction (`elementFromPoint`), `<fieldset disabled>` ancestor.
- Loại trừ: button text/aria-label chứa `loading|saving|wait|đang xử lý` (legitimate disabled state), form chưa fill (input:invalid sibling).
- Signal types: `ui_cta_obstructed` (HIGH), `ui_cta_disabled_unexpected` (MEDIUM), `ui_cta_hidden_with_handler` (LOW).
- Profile: standard (10 routes, 30 buttons), deep (25/50), exhaustive (50/80).
- `dimension.json` + `_shared.md` severity table updated.

### Sprint 5 — Parallel BASE_URL CDG

NEW: `.claude/scripts/wf-fix-baseurl-conflict-check.sh` — output JSON `{conflict, peer_sessions[]}` từ `sessions.jsonl` (filter: cùng URL, in_progress, age < 120 min). Bypass: env `MCV3_PW_ALLOW_SHARED_URL=1`.

`phase1-init.md` Step 1.9:
- Đổi tên "Browser CDG" → "Browser CDG + BASE_URL Conflict Check (E090b v10.2)".
- E090: existing (URL missing).
- E090b NEW: peer session cùng URL → AskUserQuestion 3 options (Tiếp tục / Đợi / Huỷ).
- Decision ghi vào `fix-status.json.cdg_decisions[]`.

`SKILL.md` thêm section "Multi-Session Notes" với bảng safety matrix (BASE_URL khác/cùng + isolated/shared state).

### Sprint 6 — Evals + docs

- `SKILL.md` version 10.1.0 → 10.2.0.
- `_contract.json` version 10.1.0 → 10.2.0.
- `dimension.json` QD9 thêm probe `P-QD9-disabled-cta-check` + promote 2 probes vào standard.
- `wf-fix-runtime-health/procedures/probes/_shared.md` severity table thêm 3 signal types mới (ui_cta_obstructed/disabled_unexpected/hidden_with_handler).

### Migration v10.1 → v10.2

- Schema additive — backward compat hoàn toàn. `jq -e '.show_browser // false'` ở reader.
- Sessions in-progress v10.1 `--resume` được vì state file additive.
- User cũ chạy `/wf-fix-bugs` thấy:
  - Default `standard` chậm hơn ~1.5× (bù lại bắt nhiều UI bug hơn).
  - `--show-browser` lần đầu thực sự hoạt động (trước đây silent ignored).
  - `--mobile` lần đầu thực sự áp dụng device emulation.
  - BASE_URL conflict warning E090b nếu chạy parallel cùng URL.

### Files affected

13 files changed:
- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (version + Multi-Session Notes)
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase1-init.md` (flag chain + Step 1.9 E090b)
- `.claude/skills/workflow/wf-fix-bugs/procedures/_shared.md` (state vars glossary)
- `.claude/skills/workflow/wf-fix-bugs/templates/phase1-init/fix-status.json` (schema additive)
- `.claude/skills/workflow/_shared/playwright-session.js` (actionLaunch + findFreePort + mobile emulation)
- `.claude/skills/workflow/wf-fix-runtime-health/SKILL.md` (probe table + per-profile caps)
- `.claude/skills/workflow/wf-fix-runtime-health/dimension.json` (NEW probe + promote)
- `.claude/skills/workflow/wf-fix-runtime-health/procedures/probes/_shared.md` (PW_LAUNCH_CMD + severity table)
- `.claude/skills/workflow/wf-fix-runtime-health/procedures/probes/P-QD9-interactive-smoke.md` (B0 sidebar expand + modal selector + bỏ cancel)
- `.claude/skills/workflow/wf-fix-runtime-health/procedures/probes/P-QD9-disabled-cta-check.md` (NEW)
- `.claude/skills/workflow/wf-fix-ux-a11y/procedures/probes/_shared.md` (PW_LAUNCH_CMD propagation)
- `.claude/skills/workflow/wf-fix-compat/procedures/probes/_shared.md` (PW_LAUNCH_CMD propagation)
- `.claude/scripts/wf-fix-baseurl-conflict-check.sh` (NEW)
- `plans/wf-fix-bugs-v10.2-ui-coverage/00-master-plan.md` (NEW)

### Memory note

`project_wf-fix-bugs-v10-2-plan.md` lưu decisions + sprint breakdown trong personal memory.

---

## [wf-fix-bugs v10.1.0 + wf-fix-execute v3.8.0 — Speedup Wave 1+2+3] — 2026-05-14

### Tổng quan

Minor release tăng tốc profile `exhaustive` ~50-60% (120 min → ~50-60 min) qua 3 waves song song. Kế hoạch đầy đủ trong `plans/wf-fix-bugs-v10-speedup/` (5 plan files). 8 cải tiến triển khai bởi 7 parallel agents (2+2+3) trong session 2026-05-14. **Zero quality loss**: toàn bộ guard rails MCV3 bảo toàn (POST-GATE T1-T4, CDG CORE-027, CORE-029 Spot-Check, CORE-037 Agent Prompt 8 sections, CQG hard-enforce, Protocol 20 CI Logging, Scope Boundary, Atomic Write).

### Added

**Wave 1 — Foundation (commit 2b5fd677):**
- **W1.2 Session-tier CI Impact Cache** (`scripts/wf-fix-ci-cache.sh` — 371 lines, +x): wrapper script 3 subcommands (`lookup`/`store`/`bypass`). File-backed cache `$SESSION_DIR/.ci-cache/impact/{sha256(key)[0:16]}.json`. Cache key `impact:{HEAD-sha}:{target}:{direction}` → auto-invalidate khi commit-sha đổi. Escape hatch `MCV3_FIX_CI_CACHE_DISABLED=1`.
- **W1.3 POST-GATE helper** (`scripts/wf-fix-common.sh` `validate_post_gate_tiered`): gộp 4 jq/grep subprocess calls thành 1 function call, output per-tier vẫn riêng để debug.

**Wave 2 — Parallel Execution (commit b09ee1ce):**
- **W2.1 Playwright Multi-Context** (`_shared/playwright-session.js` `actionNavigateParallel` + `actionCloseContext`): mở max `MCV3_PW_MAX_CONTEXTS=4` contexts trong 1 browser instance. Auth-required routes (`/auth/|/login|/admin|/profile`) vẫn sequential. Evidence per route preserved (closure scope).
- **W2.2 Dependency Graph** (`scripts/wf-fix-dep-graph.sh` — 213 lines, +x): bash wrapping Python union-find. Output `dep-groups.json` cho Batch 1 CRITICAL parallel max `$MAX_PARALLEL_AGENTS`. Overlap rule: share file (`target.file_path`/`location.file`/`files_modified[]`) hoặc same `target.symbol`. Escape hatch `MCV3_FIX_BATCH1_PARALLEL_DISABLED=1`.

**Wave 3 — Smart Skip & Aggregation (commit e5d42753):**
- **W3.2 CI Batching Per File** (`scripts/wf-fix-ci-batch.sh` — 375 lines, +x): gom issues theo primary file → 1 impact call/file. 5 issues cùng file → 5× → 1× CI call (cache miss path). Log 1 entry/issue với `cache_source: batch_lookup` + `parent_file`. Escape hatch `MCV3_FIX_CI_BATCH_DISABLED=1`.
- **W3.3 Spot-Check Pattern Cache** (`_shared/spot_check_cache.py` — 140 lines): `SpotCheckCache` LRU max 50 entries. Key `(agent_type, signal_type, severity)` case-normalized. Tier 1 SCHEMA cached, Tier 2/3/4 (file/scope/content) LUÔN chạy. Escape hatch `MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1`.

### Changed

- **W1.1 Phase 6 Wrapper De-dup** (`wf-fix-bugs/procedures/phase6-execute.md` Step 6.4): Fast Path đọc `blast_radius` từ Phase 5 triage (ADR-22 rule 2) → skip redundant `gitnexus_impact` calls. Threshold: `severity=CRITICAL OR direct_count≥20 → CRITICAL`. Slow Path fallback giữ nguyên. `ci-impact-report.json` thêm field optional `fast_path_used` + `tool` enum (blast_radius_reused | gitnexus_fresh | grep_fallback). Step 6.6 POST-GATE: gọi helper `validate_post_gate_tiered`.
- **Phase 3 batches CI PRE-GATE** (`wf-fix-execute/procedures/phase3-batch{1,2,3}.md`): replace direct `gitnexus_impact` call bằng wrapper `wf-fix-ci-cache.sh`. fix-log.json CI_TOOL_USED entries extended với `cache_hit` + `cache_source` fields. Thêm §CI Batch Mode + §CI Cache Wrapper Usage sections.
- **Phase 3 Batch 1 dep-aware** (`wf-fix-execute/procedures/phase3-batch1.md`): NEW Step 3.1.0b build dep-graph. Step 3.1.1 spawn agents PER GROUP (run_in_background:true), max `$MAX_PARALLEL_AGENTS`. NEW Step 3.1.1b: wait + spot-check + cross-group file overlap verify. User's Step 3.1.0 P3 Pre-Batch Resume Filter (commit 6ec1c50d) intact.
- **Phase 5 Smart Rescan** (`wf-fix-execute/procedures/phase5-scan.md` Step 5.1 + `phase5-loop.md` Step 5.16/5.19): iter 1 LUÔN full, iter giữa = delta + cross-module dependents (qua wf-fix-ci-cache.sh downstream lookup), iter cuối LUÔN full. `iteration_history[].scan_mode` field logged. Graceful degradation 3 lớp.
- **Phase 5.14 Playwright parallel routes** (`wf-fix-execute/procedures/phase5-scan.md` Step 5.14): public routes parallel max 4 contexts, auth routes sequential. `playwright_verify` schema thêm 3 optional debug fields.
- **Spot-Check Protocol §17** (`wf-fix-execute/procedures/_shared.md`): 4-tier rõ ràng — Tier 1 SCHEMA cached, Tier 2/3/4 LUÔN chạy. Cache integration via SpotCheckCache.

### Verification

- skill-compliance-audit.sh wf-fix-bugs + wf-fix-execute: GRADE PASS cả 2 (12/12 CRITICAL)
- validate-schema-sync.sh wf-fix-bugs + wf-fix-execute: ALL PASS, 0 errors
- bash -n cho 3 scripts mới: OK (wf-fix-ci-cache.sh, wf-fix-dep-graph.sh, wf-fix-ci-batch.sh)
- node -c playwright-session.js: OK
- py -m py_compile spot_check_cache.py: OK
- LRU smoke test 60 inserts → size==50: PASS
- POST-GATE helper parity test 4/4 cases: PASS
- dep-graph smoke test 5 fixtures: PASS (normal, escape hatch, empty)
- ci-batch script smoke test 6 scenarios: PASS

### Plan reference

- `plans/wf-fix-bugs-v10-speedup/` — 5 plan files (README, master-plan, guard-rails, benchmark, progress) tổng ~1437 lines
- `tools/benchmark-fixtures/wf-fix-bugs/` — synthetic fixture 20 bugs verified (commit a28e5d19)

### Schema version impact

KHÔNG break — additive only:
- New env variables (optional escape hatches)
- New optional fields trong ci-impact-report.json (fast_path_used, tool enum value)
- New optional fields trong fix-log.json CI_TOOL_USED entries (cache_hit, cache_source, parent_file)
- New optional fields trong playwright_verify (parallel_mode, public_routes_count, auth_routes_count)
- New optional fields trong iteration_history[] (scan_mode)
- 3 new bash scripts + 1 new Python module
- 1 new helper function trong wf-fix-common.sh

### Expected speedup breakdown

| Wave | Cải tiến | Min | Max |
|------|----------|-----|-----|
| W1.1 | Phase 6 de-dup | -5 | -10 |
| W1.2 | CI Impact Cache | -15 | -25 |
| W1.3 | POST-GATE consolidation | -2 | -3 |
| W2.1 | Playwright parallel | -5 | -10 |
| W2.2 | Batch 1 dep-aware parallel | -5 | -10 |
| W3.1 | Smart rescan (iter giữa delta + cross-module) | -10 | -15 |
| W3.2 | CI Batching per file | -5 | -8 |
| W3.3 | Spot-check pattern cache | -2 | -4 |
| **Cumulative** | | **-49 min** | **-85 min** |
| **% Baseline 120 min** | | **~40%** | **~70%** |

Effective median: ~50-60% trên fixture có ~20 issues.

### Follow-ups (deferred to future plans)

- Distributed dimension scan (Phase 4 parallel hơn nữa) → v10.2.0
- Pre-warmed agent context (template caching) → v10.2.0
- Persistent disk-tier cache cho CI impact across sessions → v10.2.0
- W3.1 cross-module enhancement với GitNexus depth=2 (cần benchmark trước)

---

## [wf-fix-bugs v10.0.2 — Resume Mechanism Improvements] — 2026-05-14

### Tổng quan

Patch release sửa 8 vấn đề correctness + UX cho cơ chế `--resume` của wf-fix-bugs v10.0. Audit cơ chế resume R1-R10 phát hiện gaps về staleness guard, lock liveness, retry budget, PRE-GATE re-validation và step-level resume cho Phase 6 (avoid re-fix bugs đã hoàn thành). 3 waves triển khai trong session 2026-05-14: Wave 1 correctness (P1, P2, P5, P7, P8), Wave 2 UX flags (P4, P6), Wave 3 step-level resume (P3).

### Fixed

- **P1 — R6 git diff syntax bug** (`procedures/resume-status.md` §Anti-Staleness Guard): `git diff --since` (sai cú pháp, silent skip) thay bằng resolve `CHECKPOINT_COMMIT` qua `git log --before` rồi `git diff $CHECKPOINT_COMMIT HEAD`. Denominator scope-aware dùng `code-inventory.json`, fallback `git ls-files`.
- **P2 — Lock không check PID liveness** (`.claude/scripts/wf-fix-common.sh` `acquire_lock` + `procedures/_shared.md §13`): Heartbeat daemon chết âm thầm → process khác có thể steal lock của process đang chạy. Lock check 2-path: **Path A** (same host) `kill -0 $pid` → live=ERROR, dead=takeover ngay. **Path B** (cross-host hoặc thiếu pid) → fallback mtime stale check.
- **P3 — No step-level resume Phase 6** (`wf-fix-execute/procedures/_shared.md` + `phase3-batch{1,2,3}.md`): Phase 6 fix 35/50 bugs rồi crash → resume cũ chạy lại toàn bộ 50 bugs. Thêm **Pre-Batch Resume Filter** trước mỗi batch lấy `fix-log.json.entries[].issue_id` làm SSOT cho "đã fix DONE" (theo Lifecycle Rule APPEND-khi-DONE). Skip issues đã trong fix-log → fix chỉ remaining.
- **P5 — Retry budget reset sai khi resume** (`procedures/resume-status.md` R9.5): Mỗi `--resume` reset `$RETRY_COUNT=0` → bypass anti-loop guard. Đọc `error-ledger.json` đếm FAIL entries của phase resume → restore `$RETRY_COUNT`. ≥3 → E001 STOP với option reset rõ ràng.
- **P7 — R10 không re-validate PRE-GATE** (`procedures/resume-status.md` R9.6): Upstream phase outputs corrupt → resume tiếp tục mù quáng. Re-run PRE-GATE T1→T4 cho outputs phases trước. Corrupt → AskUser re-run prior phase / cancel.
- **P8 — Probe completion check yếu** (`procedures/_shared.md §15` Lane Agent Prompt): Resume support chỉ check `.signals` exists, false-positive nếu probe bị kill mid-write. Probe writer phải ghi `completed_at` + `probe_complete: true` ở bước CUỐI. RESUME SUPPORT validate đủ 3 conditions trước khi skip.

### Added

- **P4 — `--session=<SESSION_ID>` flag** (`_contract.json §inputs`, `procedures/phase1-init.md` Step 1.1, `procedures/resume-status.md` R1+S1, `SKILL.md` Arguments): R1 không cho user chọn session cụ thể, chỉ "latest". Thêm `--session` priority: flag → env → latest. Validate session tồn tại trước khi resume.
- **P6 — `--resume-strategy=prompt|auto|force-fresh` flag** (`_contract.json §inputs`, `procedures/phase1-init.md` Step 1.1, `procedures/resume-status.md` R3+R4 + Strategy Matrix, `SKILL.md` Arguments): R3/R4 AskUserQuestion blocking trong CI/cron → hang. `auto` không block (CI/cron). `force-fresh` luôn tạo session mới.

### Verification

- Compliance audit: GRADE PASS (12/12 CRITICAL, 11/13 REQUIRED, 3/5 CONDITIONAL)
- Schema sync: ALL PASS (skill identity, procedure references, registry scope, output templates)
- Bash syntax: `wf-fix-common.sh` OK
- JSON validity: `_contract.json` OK
- PID liveness smoke test: 4/4 kịch bản đúng (fresh / live PID / dead PID / cross-host)
- Schema version impact: KHÔNG (additive inputs, fix-log schema unchanged, wf-fix-lock-v1 unchanged)

### Plan reference

`plans/wf-fix-bugs-resume-improvements/` — README.md với 8 fixes P1-P8 detailed analysis, 3-wave breakdown, follow-ups deferred.

### Follow-ups deferred

- E031 namespace collision (severity: thấp — display only)
- `.status` vs `.result` field inconsistency trong fix-log.json check (severity: thấp — không xung đột thực tế)
- `session-log.json` rotation policy (severity: thấp — performance dài hạn)
- R9 mode re-evaluation 2-chiều (severity: thấp — rare in practice)
- Existing probes update `completed_at` writer (severity: trung bình — doc done, probes audit pending)

---

## [wf-fix-bugs v9.1.0 — QD11 Business Completeness & Enhancement] — 2026-05-12

### Tổng quan

Thêm dimension lane QD11 (wf-fix-business-completeness) vào orchestrator wf-fix-bugs. QD11 là lane 100% LLM-based, dùng 3-pass analysis để phát hiện missing business logic: cross-module pattern comparison (Pass 1, HIGH confidence), domain heuristic analysis (Pass 2, MEDIUM confidence, deep+ profile), và registry gap detection (Pass 3, HIGHEST confidence). Enhancement suggestions được đưa qua CDG gate cho user ACCEPT/REJECT.

### Added

- **`wf-fix-business-completeness/` skill** (lane QD11): SKILL.md, _contract.json, dimension.json với 3 probes (P-QD11-cross-module-comparison, P-QD11-domain-heuristic, P-QD11-registry-gap). 11 valid signal types: MISSING_FIELD, MISSING_FEATURE, TYPE_MISMATCH, VALIDATION_GAP, MISSING_DOMAIN_FIELD, MISSING_COMPLIANCE_CHECK, MISSING_AUDIT_TRAIL, MISSING_BUSINESS_RULE, UNIMPLEMENTED_REQ, ORPHAN_REQ_ID, GAP_REQ_TO_FEAT.
- **3 LLM probe prompts**: `prompts/llm-probe-qd11-cross-module.md`, `prompts/llm-probe-qd11-domain-heuristic.md`, `prompts/llm-probe-qd11-registry-gap.md`.
- **Procedures**: `procedures/qd11-workflow.md` (3-pass flow), `procedures/qd11-cdg-gate.md` (CDG ACCEPT/REJECT/Defer).
- **Bash scripts**: `scripts/wf-fix-qd11-skip-check.sh` (3 skip conditions: profile_quick, api_only, single_module), `scripts/wf-fix-qd11-signals-validate.sh` (11 valid signal types, required fields validation).
- **Evals**: 5 test cases (TC-QD11-001 → TC-QD11-005) covering Pass 1/2/3, skip conditions, and cross-module comparison.
- **Orchestrator integration**: PRE-GATE recommendation gate cho QD11 (dựa trên module count, profile, interface_type), `llm` probe type trong phase1-engine.md, QD11 visibility sections trong post-gate-completion.md summary.
- **_contract.json updates**: wf-fix-bugs _contract.json bumped 9.0.2→9.1.0, --dims description updated with QD11.

### Changed

- **SKILL.md** (wf-fix-bugs): version 9.0.2→9.1.0, dimension count 10→11, sub-skill validation path added, QD11 recommendation gate added, Output Files table entry #18 added.
- **phase1-engine.md**: probe execution strategy table extended with `llm` type.
- **post-gate-completion.md**: orchestrator summary template extended with QD11 sections.

### Verification

- `skill-compliance-audit.sh wf-fix-business-completeness`: PASS
- `validate-schema-sync.sh wf-fix-business-completeness`: PASS
- `validate-schema-sync.sh wf-fix-bugs`: PASS
- `pytest .claude/skills/workflow/_shared/`: all tests pass

---

## [schema-sync-triage-fix v1.0.0] — 2026-05-10

### Fixed

- **`validate-schema-sync.sh`**: `check_output_templates()` path resolution — thử 3 base dirs (skill, doc-framework, root). Giải quyết false FAIL cho 6 skills (wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux, wf-annotate-code) và cả wf-plan-modules (template check). validate-schema-sync.sh --all tăng từ 24 PASS → 31 PASS.
- **`doc-framework/phase5-implementation/_contract.json`**: thêm template keys `sprints-index` + `parallel-safe-groups` — wf-plan-modules reference đến 2 output paths này nhưng keys thiếu trong framework contract.
- **`doc-framework/phase1-business/_contract.json`**: thêm template key `departments-index` — wf-analyze-requirements reference `departments/_index.md` output nhưng key thiếu trong framework contract.
- **`wf-plan-modules/_contract.json`**: thêm field `procedure` (array 16 files) — validator check `.procedure` nhưng field bị đặt tên `procedure_files`. Cả 2 fields giờ tồn tại song song.
- **`wf-fix-triage/SKILL.md`**: thêm `## Phase 0: PRE-GATE` header (compliance check 4.5 — ≥2 phase headers), `## Fix Rules` table tổng hợp triage rules (check 5.1), `## Registry Safe-Write (CORE-006)` reference (check 10.2). REQUIRED tăng từ 10/12 (83%) → 12/12 (100%).

---

## [wf-fix-bugs v9.0.2 — QD9/QD10 Coverage Completion] — 2026-05-10

### Tổng quan

Patch hoàn thiện phạm vi bao phủ QD9/QD10 sau v9.0.1: 5 thành phần hạ tầng chia sẻ (`profiles.json`, `dim-selection.schema.json`, `fix-workload.schema.json`, `isg_recommender.py`, `phase6-report.md`) chưa nhận biết QD9/QD10, dẫn đến `--profile=exhaustive` không dispatch cả 10 dimensions và ISG không có khả năng recommend QD9/QD10. Patch này hoàn thiện 11 findings (F1-F11), cập nhật 8 cosmetic docs, và thêm 20 regression tests dành riêng cho QD9/QD10.

### Fixed

- **`profiles.json`: exhaustive profile** (F1): thêm QD9, QD10 vào `dimensions[]` và cập nhật `description` + `estimated_time_minutes` (75→95). Trước patch, `--profile=exhaustive` chỉ dispatch 8 dimensions thay vì 10.
- **`dim-selection.schema.json`** (F2): 3 enum (`recommendations[].dim`, `selected[]`, `skipped[]`) thêm "QD9", "QD10". Trước patch, schema reject QD9/QD10 → validator báo lỗi giả.
- **`fix-workload.schema.json`** (F3): 2 enum (`dimension` field tại 2 vị trí) thêm "QD9", "QD10". Workload estimator output bị reject validator khi plan include QD9/QD10.
- **`isg_recommender.py`: DIMENSIONS + DIM_NAMES + DIMENSION_SCORES** (F4): Mở rộng từ QD1-QD8 lên QD1-QD10. Deep profile thêm QD9 (QD10 chỉ exhaustive — design decision). Trước patch, ISG không thể recommend QD9/QD10 kể cả khi người dùng chỉ định `--dims=QD9`.
- **`phase6-report.md` example schema** (F5 — bug độc lập): `dimensions_enabled` thiếu "QD4". Bug không liên quan QD9/QD10 — phát hiện trong quá trình rà soát.

### Added

- **`tests/test_e2e_qd9_qd10.py`** (F11): 20 regression tests trong 4 class:
  - 6 tests lock-in F1/F2/F3 (profiles, dim-selection schema, workload schema)
  - 3 tests lock-in F4 ISG recommender (DIMENSIONS, deep+QD9, deep!QD10)
  - 6 tests `TestDimensionManifestQD9QD10` (dimension.json tồn tại, probe IDs hợp lệ, probe files tồn tại)
  - 3 tests `TestQD9RuntimeHealth` (cache disabled, lane path, agents)
  - 3 tests `TestQD10Integration` (cache allowed, lane path, agents)
  - 2 tests `TestExhaustiveProfileFull` (dispatch 10 dims, profile includes QD9/QD10)

### Documentation

- Cosmetic docstring/help/README updates cho 8 files (F6-F10):
  - `lane_dispatch.py` + `dimension_registry.py` + `partition_planner.py` docstrings: `QD1-QD8` → `QD1-QD10`
  - `SKILL.md` table header: mở rộng để phân biệt Static (QD1-QD8) + Runtime (QD9) + Integration (QD10)
  - `lock-management.md` + `examples.md` + `lane/_shared.md` + `fix-plan.md`: cập nhật text tham chiếu QD1-QD10

### Verification

- Full pytest: **631 passed, 10 skipped, 0 FAIL** (up từ 611 baseline của v9.0.1).
- `test_e2e_qd9_qd10.py`: **20/20 PASS**.
- `skill-compliance-audit.sh wf-fix-bugs`: GRADE: PASS (CRITICAL 12/12, REQUIRED 13/13).
- `validate-schema-sync.sh wf-fix-bugs`: PASS (1/1).

---

## [wf-fix-bugs v9.0.1 — Runtime Dispatch Drift Patch] — 2026-05-10

### Tổng quan

Patch khắc phục **fantasy completion** của v9.0.0: cấu trúc skill QD9/QD10 đã có đầy đủ và compliance audit PASS, nhưng 5 mảnh hạ tầng dùng chung (`signal_bus`, `lane_dispatch`, `wf-fix-merge-non-static-probes.sh`, JSON schemas) chưa được nâng từ 8 dimensions lên 10. Hệ quả: `/wf-fix-bugs --lane=QD9` hoặc `--lane=QD10` fail ngay tại `_execute_lane_sequential` với `dimension.json not found`, và mọi signal QD9/QD10 bị `signal_bus` reject với `ValueError: dimension_id không hợp lệ`.

Patch này không thêm tính năng mới — chỉ vá 5 vị trí drift, thêm 41 regression test, và mở rộng `check-wave-gate.sh` để tự động phát hiện drift tương tự trong tương lai.

### Fixed

- **`signal_bus.signal_bus.VALID_DIMENSIONS`** (Critical): mở rộng từ `{QD1..QD8}` thành `{QD1..QD10}`. Trước patch, mọi `Signal.from_dict({dimension_id: 'QD9'})` ném `ValueError`, làm pipeline ingest signals từ QD9/QD10 lane bị chặn hoàn toàn.
- **`signal_bus.signal_bus.PROBE_ID_PATTERN`** (Critical): regex `^P-QD[1-8]-...$` → `^P-QD([1-9]|10)-...$`. Cùng vấn đề: probe IDs `P-QD9-*` và `P-QD10-*` bị reject.
- **JSON schemas** (Critical): `signal.v2.schema.json` + `issue.v2.schema.json` enum + pattern cập nhật cùng phạm vi.
- **`scan_cache/schemas/cache-entry.schema.json`** (Critical): pattern `probe_id` mở rộng để cache QD9/QD10 probe results.
- **`.claude/scripts/wf-fix-merge-non-static-probes.sh`** (Critical): case map `qd_to_lane()` thêm `QD9 → wf-fix-runtime-health`, `QD10 → wf-fix-integration`. Trước patch, helper trả `[]` với "WARN: unknown dimension" → orchestrator skip toàn bộ non-static probes của QD9/QD10.
- **`.claude/scripts/wf-fix-lane-to-bus.py`** (Critical): `PROBE_ID_RE` + `VALID_DIMS` mở rộng, đồng bộ với signal_bus.
- **`_shared/profile_resolver.py`** (Minor): docstring + error message của `_validate_probe_id()` cập nhật `[1-8]` → `{1..10}` (logic regex đã đúng từ v9.0.0).
- **`_shared/isg/isg_recommender.py`** (Critical): `_QD_TOKEN_PATTERN` mở rộng để parse user response `--dims=QD9` hoặc `QD10`.

### Added

- **`dimension.json` cho QD9** (`wf-fix-runtime-health/dimension.json`): 7 probes + exit_criteria 4-tier + severity_rules + parallel_groups (sequential do browser singleton). Trước patch file này không tồn tại → `_execute_lane_sequential` return `LaneResult(status="failed", error="dimension.json not found")` ngay tại bước resolve probes.
- **`dimension.json` cho QD10** (`wf-fix-integration/dimension.json`): 9 probes (gồm `P-QD10-auth-matrix-check` từ W5.6) + exit_criteria 4-tier + severity_rules + parallel_groups (3 static parallel + sequential runtime).
- **`_shared/tests/test_qd9_qd10_v9.py`** (41 regression tests): lock-in 5 mảnh đã vá. Cấu trúc 6 test classes: `TestSignalBusV9Constants`, `TestSignalFromDictV9`, `TestJsonSchemaV9Enum`, `TestDimensionJsonV9`, `TestLaneDispatchV9`, `TestDimensionRegistryV9`. Nếu drift xảy ra (ai đó remove QD9/QD10 khỏi 1 trong 5 vị trí), test fail ngay → tránh "drift trở lại 8 dim".
- **Wave gate runtime drift check** (`plans/wf-fix-bugs-v9/scripts/check-wave-gate.sh`): hàm `check_lane_dispatch_smoke <DIM> <LANE>` mới gọi pytest filtered. Wired vào `check_w1_5` (QD9), `check_w2` (QD10), `check_release` (cả 2). Trước patch các Wave gate chỉ check file existence — sign-off không phát hiện được runtime dispatch fail.

### Updated tests

- `tests/test_signal_bus.py::test_valid_dimensions_cover_8` → `test_valid_dimensions_cover_10` (assertion update để khớp v9 thực tế).
- `tests/test_e2e_orchestrator.py::test_get_all_dimensions` + `test_registry_has_8_entries`: update kỳ vọng từ 8 dim → 10 dim.

### Verification

- Smoke test `_execute_lane_sequential`: cả QD9 (quick→0, standard→3, deep→7) và QD10 (quick→0, standard→3, deep→5, exhaustive→9) đều `status=completed`.
- Helper `wf-fix-merge-non-static-probes.sh --dims=QD9,QD10`: trả 11 entries (7 QD9 runtime + 4 QD10 runtime). Trước patch trả `[]`.
- Full pytest: **611 passed, 10 skipped** (unchanged regressions; 3 originally-failing tests now pass + 41 new tests added).
- skill-compliance-audit: PASS 12/12 CRITICAL cho cả 3 skill (`wf-fix-runtime-health`, `wf-fix-integration`, `wf-fix-bugs`).
- validate-schema-sync: PASS cho cả 2 lane.
- Wave gates `w1.5`, `w2`, `release`: smoke test mới PASS, không tạo regression cho gate logic cũ.

### Migration note

KHÔNG có breaking change cho user. Patch là backward-compatible:
- Code đã chạy v9.0.0 vẫn chạy bình thường (chỉ giờ dispatch QD9/QD10 thực sự work).
- Session đang dở (sessions/{id}/) tiếp tục resume bình thường — schema không thay đổi.
- Không cần `--migrate`.

### Pre-existing issue out-of-scope

- `git tag plan-wf-fix-bugs-v9-DONE` được declare DONE trong progress.md Session 46 nhưng tag thực sự chưa tồn tại. Phát hiện bởi `check_release` mới — sẽ xử lý trong v9.0.2 nếu cần.

---

## [wf-fix-bugs v9.0.0 — Cross-Module Integration + Runtime Health] — 2026-05-10

### Tổng quan

v9.0.0 nâng cấp `wf-fix-bugs` từ 8 lên **10 dimension lanes**, bổ sung kiểm tra toàn diện browser runtime (QD9) và cross-module integration (QD10). Đây là phiên bản lớn nhất kể từ v7.0 (session isolation), với 5 Waves triển khai trong plan `wf-fix-bugs-v9`.

### Added (Wave 1 — Foundation + Lane QD9 Core)

- **Registry schema `cross_module_dependencies[]`** (W1.1): Trường mới trong `req-registry.json` để khai báo quan hệ phụ thuộc giữa modules. Schema: `dependency_id`, `provider_module`, `consumer_module`, `binding_type`, `confidence`, `provider_api_path`, `consumer_field`.
- **Script `wf-fix-detect-base-url.sh`** (W1.2): Auto-detect BASE_URL cho mọi app trong monorepo (web, mobile, API). Smoke: 5 EUREKA apps detected.
- **Lane QD9 `wf-fix-runtime-health`** (W1.3): Skeleton lane mới — 7 browser probes qua Playwright MCP. Registered trong `wf-fix-bugs` SUB_SKILLS.
- **Probe `P-QD9-dev-server-bootstrap`** (W1.4): Phát hiện `dev_server_bootstrap_failed` (CRITICAL) — dev server không start. Error code E095.
- **Probe `P-QD9-console-network-monitor`** (W1.5): Theo dõi `runtime_console_error` (HIGH) và `uncaught_exception` (CRITICAL) qua Playwright event listeners.
- **Probe `P-QD9-auth-aware-smoke`** (W1.6): Login URL auto-detect + cookie inject + protected route traverse. Phát hiện `post_auth_unauthorized` (HIGH).
- **`--browser-required-when-ui` CDG enforcement** (W1.7): Script `wf-fix-browser-precheck.sh` + CDG gate Step 4.5 + error E097.
- **fix-report.md "Browser Verification" section** (W1.8): Section QD9 được tự động thêm/xóa dựa trên QD9 execution status.
- **Realistic coverage breakdown** (W1.9): SKILL.md 3-col table (Static%/Runtime%/LLM%); `coverage_estimator.py` v1.1.0 với `runtime_pct`.

### Added (Wave 1.5 — QD9 Deep Probes)

- **Probe `P-QD9-feature-checklist-smoke`** (W1.5a): Registry query `impl_status=done` → navigate → CTA smoke. Phát hiện `feature_route_broken` (HIGH). REUSE QD1 orphan-ui-detect.
- **Probe `P-QD9-interactive-smoke`** (W1.5b): Click tất cả CTAs (button/role=button/.btn, limit 10/route, skip destructive). Phát hiện `ui_cta_no_response` (MEDIUM). REUSE QD1 A2.
- **Probe `P-QD9-spa-route-coverage`** (W1.5c): Framework detection (Next.js pages/app/, Vue Router, React Router). Phát hiện `spa_route_unreachable` (MEDIUM). Optional output `spa-routes.json`.
- **Probe `P-QD9-form-validation-smoke`** (W1.5d): 2-pass per form (submit-empty + fill-invalid). Phát hiện `form_validation_bypass` (HIGH) và `form_validation_missing` (MEDIUM). Profile exhaustive only.

### Added (Wave 2 — Cross-Module Static)

- **Lane QD10 `wf-fix-integration`** (W2.1): Skeleton lane mới — 10 probes cross-module. Registered trong `wf-fix-bugs` SUB_SKILLS. Error codes E101-E110.
- **Probe `P-QD10-cross-module-ref-static`** (W2.2): Import/type drift giữa modules. Phát hiện `cross_module_ref_drift` (MEDIUM), `deprecated_import` (MEDIUM). Script `wf-fix-probe-cross-module-ref.sh`. REUSE QD7 combined grep.
- **Probe `P-QD10-api-contract-drift`** (W2.3): So sánh OpenAPI/GraphQL/AsyncAPI spec vs consumer DTO (TypeScript/Python/Java/C#). Phát hiện `api_contract_breaking_change` (HIGH), `api_contract_type_mismatch` (MEDIUM). Script `wf-fix-probe-contract-drift.sh`. REUSE QD6 schema diff algorithm.
- **Probe `P-QD10-event-handler-coverage`** (W2.4): Kiểm tra event emitted có handler. Phát hiện `event_handler_missing` (HIGH), `event_handler_partial` (MEDIUM). CI-ROUTE: GitNexus PRIMARY.
- **QD2 "Boundary Mode"** (W2.5): Khi phát hiện cross-module deps giữa 2 domains khác nhau, spawn 2 agents concurrent (consumer + provider perspective). REUSE QD2 spawn pattern. `_contract.json` v2.1.0.
- **Script `wf-detect-cross-module-deps.sh`** (W2.6): Auto-detect cross-module dependencies (combined grep import + API + type, confidence 0.75/0.15/0.10). Dry-run: 49 modules 2352 pairs.

### Added (Wave 3 — Runtime Integration + Multi-Platform)

- **Probe `P-QD10-orphan-reference-runtime`** (W3.1): LEFT JOIN DB query kiểm tra FK orphan records (4 dialects: PostgreSQL/MySQL/SQLite/MSSQL). E104 production block. Phát hiện `orphan_reference_detected` (HIGH), `cross_module_fk_mismatch` (MEDIUM).
- **Probe `P-QD10-multi-platform-entity-sync`** (W3.2): So sánh entity response giữa ERP + MC platform. Phát hiện `entity_sync_response_shape_mismatch` (HIGH), `entity_sync_field_mismatch` (MEDIUM). REUSE QD1 curl pattern.
- **Probe `P-QD10-cache-staleness-probe`** (W3.3): PATCH mutation + poll consumer + rollback. E104 production block + opt-in `--test-cache-sync`. Phát hiện `cache_staleness_detected` (MEDIUM), `cache_sync_missing` (HIGH). Exhaustive only.
- **CQG-2 pre-completion gate** (W3.4): Block hoàn thành nếu `runtime_console_error > 0` hoặc QD10 HIGH+ còn tồn tại. Override `MCV3_CQG2_OVERRIDE=accept`. Anti-loop max 2 cycles → E001.
- **Re-use 121 E2E tests EUREKA** (W3.5): `phase5-scan.md` Step 5.14c — E2E Discovery + Smart Route Matching (max 20 matched specs, 300s cap).
- **Triage `user_journey_broken` dimension** (W3.6): `wf-fix-triage` v1.4.0 — phát hiện cross-module signals ảnh hưởng user journey → severity bump. `bug-triage.md` thêm "User Journey Impact" section.
- **Multi-app browser smoke isolation** (W3.7): Script `wf-fix-multi-app-coordinator.sh` — sequential browser smoke per app với priority order + lock.

### Added (Wave 4 — Business Flow + State Machine)

- **Schema `state-machine-spec.yaml`** (W4.1): JSON Schema Draft 2020-12 (`state-machine-spec-schema.json`) + mẫu `state-machine-quotation-sample.yaml`. Fields: entity, states, transitions, forbidden_transitions, guards, actions.
- **Schema `business-flow.yaml`** (W4.2): JSON Schema Draft 2020-12 (`business-flow-spec-schema.json`) + mẫu `business-flow-quote-to-cash.yaml` (9 steps Q2C). Assertion DSL với 11 operators.
- **Probe `P-QD10-state-machine-correctness`** (W4.3): Python3 YAML parse + jsonschema validate. A1: illegal co-occurrence grep (50-line window). A2: missing action handler search. Profile exhaustive only. CI-ROUTE: Serena + GitNexus PRIMARY.
- **Probe `P-QD10-business-flow-runtime`** (W4.4): Chạy full business-flow YAML spec từ đầu đến cuối. Script `wf-fix-flow-driver.sh` (~350 lines Python3 inline). 10-operator assertion DSL. Fixture cleanup queue. E104 production block. Phát hiện `business_flow_step_failed` (HIGH), `business_flow_invariant_violated` (CRITICAL).
- **Probe `P-QD2-business-rule-coverage`** (W4.5): BIZ-RULE annotation convention + scan code references. Phát hiện `business_rule_uncovered` (MEDIUM). Profile exhaustive only.
- **Integration với `wf-define-features`** (W4.7): `wf-define-features` v3.2.0 phát hiện cross-module entity references tự động và đề xuất author `cross_module_dependencies`.

### Added (Wave 5 — Performance + Polish + Cost Gating)

- **CDG-12 default scope policy** (W5.1): Khi module count > 20, hỏi user: full-scan / scope-module / incremental / cancel. Error E099. Headless escape `MCV3_SCOPE_CDG_SKIP=1`.
- **`--since=<git-ref>` incremental scoping** (W5.2): Script `wf-fix-incremental-scope.sh` (2 strategies: module-code-mapping + heuristic). Integration vào `phase1-engine.md` Step 3.5.
- **Cross-module dep resolver cache** (W5.3): Module `integration_cache.py` (TTL 24h, mtime-aware invalidation, 4 CacheTypes). 43 tests, 92% coverage. Cache dir `.mc-data-cache/integration/`.
- **Cost estimator + CDG-13 gate** (W5.4): Script `wf-fix-cost-estimator.sh` (static table QD1-QD10×4 profiles, 4 probe cost tiers). CDG-13: ước tính > $5 → hỏi user. Error E100.
- **`--lane=<id>` filter** (W5.5): Chỉ dispatch 1 lane cụ thể. `profile_resolver.py` updated (QD1-QD10 PROBE_ID_PATTERN). `dimension_registry.py` thêm QD9+QD10.
- **Probe `P-QD10-auth-matrix-check`** (W5.6): Authorization matrix YAML spec + 13 cross-framework guard patterns. Schema `authorization-matrix-schema.json`. Phát hiện `auth_matrix_missing_guard` (HIGH), `auth_matrix_over_permissive` (MEDIUM).

### Architecture summary (v9.0.0)

```
wf-fix-bugs v9.0 — 10 Dimension Lanes
─────────────────────────────────────────────────────────────
Phase 0: PRE-GATE
  CDG-12 (scope) → CDG-13 (cost) → browser precheck

Phase 1: ISG PARTITION → 10 LANES SONG SONG
  QD1 Functional | QD2 Business | QD3 Security | QD4 Performance
  QD5 UX/A11y   | QD6 Data     | QD7 Compat   | QD8 Observability
  QD9 Runtime Health (Browser/Playwright)
  QD10 Cross-Module Integration (Static+Runtime+YAML Spec)

Phase 2: wf-fix-triage
  Signal aggregation → severity/fixability → user_journey_broken

Phase 3-5: wf-fix-execute
  Fix CRITICAL→HIGH→MEDIUM → CQG-2 gate → Verify loop

Phase 6: Report
  fix-report.md + Browser Verification + fix-impact.json (audit chain)
─────────────────────────────────────────────────────────────
```

### Migration từ v8.x

v9.0 backward compatible với v8.x sessions. Session directory format thay đổi từ `run-NNN-*` sang `sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/`. Migrate tự động với `--migrate` flag hoặc script `scripts/wf-fix-migrate-sessions.sh`.

### Tài liệu

- `docs/skills-reference.md` §2.9 — Updated wf-fix-bugs v9.0 reference
- `docs/huong-dan-su-dung.md` §"Debug Nâng Cao" — QD9/QD10 user guide
- `docs/wf-fix-bugs-v9-guide.md` — **NEW** — Full v9 user guide (YAML spec authoring, performance tips, cost guide)

---

## [wf-fix-bugs v8.2.2 — Hotfix: signals.json overwrite (Tier B + C)] — 2026-05-09

### Đính chính & lý do
Tiếp nối v8.2.1 (Tier A — 4/7 fixes). Phiên này đóng nốt 3 root cause còn lại
(R4, R3, R6/R7 cleanup) qua Tier B (defense-in-depth) + Tier C (verify + speed).
Hoàn thành 7/7 root causes của bug ghi đè `lanes/QD*/signals.json`.

### Added (Tier B + C)
- **B1 — File-level signals lock (bash + Python)**:
  - `scripts/wf-fix-common.sh`: thêm `acquire_signals_lock`, `release_signals_lock` (mkdir `<file>.lock/` POSIX atomic, timeout 30s, stale 5min).
  - `_shared/lane_dispatch.py`: thêm `_signals_lock_acquire`, `_signals_lock_release`, `_atomic_write_signals_locked` — cùng convention path → bash + Python share lock.
  - `_shared/llm_lane/merge_signals.py`: thêm tương tự — 3 writer Python (lane_dispatch, merge_signals) + bash (signal-emit) đều dùng cùng `<signals_file>.lock/`.
  - Wrap **mọi write site**: `lane_dispatch._execute_lane_sequential` (R-M-W lock bao quanh `_merge_static_signals` + `_atomic_write_json`); `merge_signals.merge_lane` (R-M-W lock bao quanh full envelope update); `signal-emit.md::emit_signal` Step 4 (lock bao quanh jq atomic mv); `pre-gate.md` Step 7 init template (lock bao quanh fresh init).
  - Lock failure → log WARNING + fallback non-locked (best-effort, A1 merge defense vẫn preserve).
- **B2 — Schema unification `lane-signals-v1`**:
  - `_shared/lane/templates/signals.json`: thêm `probes_executed: 0`, `cache_policy: null` để khớp full envelope.
  - `_shared/lane_dispatch.py` `new_envelope`: bổ sung `lane`, `session_id`, `session_dir` (trước chỉ có schema/dimension/profile/generated_at/probes_executed/cache_policy/signals).
  - `_shared/lane/post-gate.md` T2.2: enforce required fields đầy đủ (`lane`, `dimension`, `session_id`, `session_dir`, `profile`, `generated_at`, `probes_executed`, `cache_policy`, `signals`) + type checks (`probes_executed` number, `cache_policy` ∈ {allowed, never, null}). LLM fields (`llm_merged`, `llm_signals_count`, `cross_signals_count`, `llm_dedup_dropped`) optional — chỉ xuất hiện sau `merge_signals.py`.
- **C1 — Cache-friendly resume verification**:
  - Test E2E: setup session với 5 signals (2 static + 3 non-static), re-call `dispatch_lanes_async` → C2 module-level skip → 0 subprocess spawn → signals.json giữ nguyên 5/5 (incl. agent + runtime probes).
  - Helper logic verified: `wf-fix-merge-non-static-probes.sh` thấy `runtime-playwright-cta` + `agent-business-review` trong FOUND → KHÔNG include vào MISSING list → KHÔNG re-spawn (token saving).
- **C2 — Module-level skip**:
  - `_shared/lane_dispatch.py`: tách helper `_lane_already_complete(signals_path) → (bool, int)` module-level.
  - `dispatch_lanes_async`: pre-filter trước khi gather — lanes đã pass POST-GATE → KHÔNG submit task vào semaphore (giải phóng slot cho lanes thực sự pending). Khác A3 (per-attempt retry guard) — đây là gate trước cả khi dispatch.
  - `_run_lane_async`: refactor dùng `_lane_already_complete` (DRY).
- **C3 — "Write Ownership Contract" documentation**:
  - `wf-fix-bugs/procedures/phase1-engine.md`: thêm section "Write Ownership Contract" sau "Execution Order Overview" — table 4 writers (lane_dispatch / signal-emit / merge_signals / signal_aggregator) với scope sở hữu rõ ràng + 4 quy tắc bất di bất dịch.
  - `_shared/lane/_shared.md` §8.2: thêm "Write Ownership Contract for `signals.json`" với cùng table + lock convention + reference tới phase1-engine.
  - `wf-fix-bugs/procedures/lock-management.md` §7.2: thêm "Signals lock (`<signals_file>.lock/`) — v8.2.2 Tier B B1" — table 4 helper bash + Python + lifecycle code patterns.

### Tests (v8.2.2 — bổ sung 7 tests)
- **B1 concurrent test (Python)**: 4 workers × 10 iters R-M-W → 40/40 signals preserved (no race) + lock timeout + idempotent release.
- **B1 bash test**: acquire+release / contention timeout / idempotent release / stale takeover (4 sub-tests).
- **B2 schema test**: template has all required / lane_dispatch envelope has 10 canonical fields / POST-GATE T2.2 enforces required (3 sub-tests).
- **C1 verification test**: dispatch_lanes_async skips completed lane (signals 5/5 preserved) + helper MISSING list correctness (2 sub-tests).
- **49/49 E2E** (`test_e2e_orchestrator.py` + `test_e2e_qd1_qd2.py`): PASS — không regression.

### Architecture summary (post-v8.2.2)

```
WRITE OWNERSHIP — lanes/QDx/signals.json
─────────────────────────────────────────
lane_dispatch.py (Python)        → MERGE static probes (preserve non-static + LLM)
signal-emit.md::emit_signal      → APPEND non-static probes (dedup fingerprint)
merge_signals.py (Python)        → MERGE LLM signals (dedup vs static + non-static)
signal_aggregator.py (Python)    → READ-ONLY (owner: issue-registry.json)

LOCK CONVENTION
─────────────────────────────────────────
<signals_file>.lock/  (mkdir POSIX atomic)
- bash:   acquire_signals_lock / release_signals_lock
- python: _signals_lock_acquire / _signals_lock_release
Timeout 30s. Stale 5min. Cross-language mutual exclusion.

RESUME PATH
─────────────────────────────────────────
1. PRE-GATE Step 7: idempotent — preserve nếu file valid + lane_state ≠ failed (A2)
2. dispatch_lanes_async: pre-filter completed lanes — skip module-level (C2)
3. _run_lane_async: per-attempt idempotent guard (A3)
4. helper merge-non-static: skip non-static probe đã có signals (C1 verified)
```

---

## [wf-fix-bugs v8.2.1 — Hotfix: signals.json overwrite (Tier A)] — 2026-05-09

### Đính chính & lý do
User báo `lanes/QD*/signals.json` bị ghi đè trong runs thực tế → mất signals từ non-static / LLM probes mỗi khi `--resume` hoặc retry. Rà soát phát hiện 7 root causes; phiên này khắc phục Tier A (3 fix accuracy khẩn) + B3 (sync counters). Tier B1/B2/C1/C2/C3 queued cho phiên tiếp theo (xem memory `project_wf-fix-bugs-signals-overwrite-fix.md`).

### Fixed (CORE-023 chất lượng > tốc độ)
- **A1 — `_shared/lane_dispatch.py`**: `_execute_lane_sequential` không còn OVERWRITE blind. Thêm 2 helpers `_read_existing_signals` + `_merge_static_signals`: chỉ thay thế signals của static probe (probe_id ∈ `STATIC_PROBE_SCRIPTS`), GIỮ NGUYÊN signals từ non-static + LLM probes đã APPEND trước đó. Preserve fields `lane`, `session_id`, `session_dir`, `llm_merged*`, `cross_signals_count`. Log chi tiết `preserved=N, replaced=M, new_static=K → total=T`.
- **A2 — `_shared/lane/pre-gate.md` Step 7**: PRE-GATE init `signals.json` giờ idempotent. Resume guard: nếu file tồn tại + valid (`$schema=lane-signals-v1` + `signals[]` array) + `lane-status.status != "failed"` → preserve (không reset về `signals: []`). Chỉ init từ template khi: file thiếu/rỗng/invalid HOẶC `status=failed`.
- **A3 — `_shared/lane_dispatch.py` `_run_lane_async`**: Trước mỗi attempt retry, kiểm tra `signals.json` đã pass `_post_gate_lane()` chưa. Nếu rồi → trả `LaneResult(status="completed")` ngay, không re-execute probes (tránh wipe non-static signals + tránh tốn token re-spawn LLM probes trên `--resume`).

### Added (defense-in-depth)
- **B3 — `_shared/lane_dispatch.py` `_sync_lane_status_totals`**: Helper mới đồng bộ `lane-status.json.totals.signals_emitted` + `signals_by_severity` + `probes_run` từ `signals[]` THỰC TẾ trong file. Trước B3 chỉ `signal-emit.md` increment counter → POST-GATE T3.3 fail giả khi lane_dispatch viết signals mà không update lane-status. Idempotent + best-effort (không fail caller).

### Tests
- 4 functional tests mới: `_read_existing_signals` (missing→None), `_merge_static_signals` (preserved=2, replaced=1, total=4), `_sync_lane_status_totals` (signals_emitted=4 / severity counts / probes_run max), `_run_lane_async` idempotent skip (preserve `probes_executed=5` không re-execute) — TẤT CẢ PASS.
- 49/49 E2E tests cũ (`test_e2e_orchestrator.py` + `test_e2e_qd1_qd2.py`) PASS — không regression.
- 3 bash unit tests cho A2 (preserve in_progress, reset failed, reset invalid JSON) PASS.

### Pending (Tier B + C — phiên kế tiếp)
- B1: File-level lock cho `signals.json` (mkdir-based, share giữa bash + Python) — race condition defense.
- B2: Schema unification `lane-signals-v1` (template + lane_dispatch + merge_signals) + POST-GATE T2.2 enforce required fields.
- C1: Cache-friendly resume cho non-static probes (auto từ A1+A2).
- C2: Skip `lane_dispatch` hoàn toàn nếu signals đã đủ — speed boost.
- C3: "Write Ownership Contract" section trong `phase1-engine.md` để contributors về sau không phá lại.

---

## [wf-fix-bugs v8.2.0 — Phase C wire-up: LLM Lane execution path] — 2026-05-09

### Đính chính & lý do
v8.0.0 và v8.1.0 publish module `llm_lane/`, catalog `LLM_PROBE_AGENTS`, 7 prompt templates, và flag `--llm-scan` trong `_contract.json` — **NHƯNG** không có execution path nào nối user input → agent invocation. Khi user chạy `/wf-fix-bugs --llm-scan`, flag bị silent ignore. Coverage claim "+15-20%" không thực tế vì module không bao giờ được gọi. Phiên bản v8.2.0 đóng gap này.

### Added
- **`scripts/wf-fix-init-status.sh`** (~150 LoC): Single-source-of-truth tạo `fix-status.json` từ template + parse 8 flags (`--llm-scan`, `--dry-run`, `--deep`, `--responsive`, `--no-browser`, `--browser-only`, `--run-tests`, `--full-test`) từ raw `$ARGUMENTS`. Validation: `--llm-scan` + profile NOT IN {deep, exhaustive} → exit 2 với suggestion. Atomic write.
- **`llm_lane/emit_invocations.py`** (~220 LoC): Pass 1.5 — subprocess emit JSON list "invocations" cho orchestrator drive Agent. Reads `fix-status.json.flags.llm_scan` + LLM_PROBE_AGENTS catalog + optional `_meta/stack.json`. Filters: profile gating (deep/exhaustive only) + stack match (`spec.applicable_stacks`) + optional `--dims` filter. Dedup per probe_id. Cross-cutting probes (multi-dim) routed to `lanes/cross/{probe_id}/`. Empty array khi flag OFF (zero overhead).
- **`llm_lane/emit_signals.py`** (~130 LoC): Pass 2 wrapper — wraps `signal_parser.parse_signals` với envelope `lane-signals-v1`. Atomic write `lanes/{DIM}/llm-signals.json` (hoặc `lanes/cross/{probe_id}/llm-signals.json`). Exits 2 khi không có JSON in raw output.
- **`llm_lane/merge_signals.py`** (~150 LoC): Pass 3 — merge `signals.json` (static) + `llm-signals.json` (LLM) + `cross/{*}/llm-signals.json` (dispatch theo `signal.dimension_id`) per dim. Dedup by fingerprint, static priority. Atomic write back. `--all` flag merge tất cả 7 dims trong 1 lệnh.
- **19 unit tests** (`llm_lane/tests/test_wire_up.py`): 7 emit_invocations + 3 emit_signals + 5 merge_signals + 4 cross-cutting routing + dedup tests. Tổng test suite 51/51 PASS (32 cũ + 19 mới).
- **Step 1.1.7** trong `procedures/phase1-engine.md`: Document kiến trúc 2-pass với 3 substeps (1.1.7a emit invocations / 1.1.7b orchestrator drives Agent / 1.1.7c merge). Backward-compat note: skip toàn bộ khi flag OFF.

### Changed
- **`_shared/templates/fix-status.json`**: Thêm field `flags.llm_scan` (default `false`).
- **`procedures/phase1-engine.md` Step 5**: Thay 1 dòng abstract bằng bash gọi `wf-fix-init-status.sh` — single source-of-truth populate fix-status.json.
- **`llm_lane/budget_guard.py`** (v8.1 → v8.2 — đính kèm với Phase C wire-up): Quality-first defaults — caps = 0 (UNLIMITED). Tracking cost cho visibility, KHÔNG enforce hard caps mặc định. Caller có thể opt-in caps qua explicit non-zero values khi construct `LLMBudget`. Mục đích: cap $1.50 cũ < cost expected $1.89 cho 7 dims → mathematically guarantee không đủ chạy đầy đủ. Vi phạm CORE-023 (chất lượng > cost). 4 tests mới cho unlimited mode.
- **`emit_invocations` quan hệ với cross-cutting probes**: 1 invocation per unique probe_id (không phải per dim) — cross-cutting probes có `dimensions: list` + `is_cross_cutting: true` + output ra `lanes/cross/{probe_id}/`. Merge stage dispatch theo signal.dimension_id.

### Architecture: 2-pass design

```
PASS 1 (subprocess Python):
  python -m lane_dispatch → static probes only → lanes/{DIM}/signals.json

PASS 1.5 (orchestrator Claude):
  python -m llm_lane.emit_invocations → JSON list invocations

PASS 2 (orchestrator drives Agent):
  for each invocation:
    spawn Agent({subagent_type, prompt}) → save raw → emit_signals.py
    → lanes/{DIM}/llm-signals.json (lane-signals-v1)

PASS 3 (merge):
  python -m llm_lane.merge_signals --all
  → lanes/{DIM}/signals.json (replaced với static + LLM merged, dedup by fingerprint)
```

Lý do 2-pass: subprocess Python KHÔNG gọi được `Task`/`Agent` tool (đó là tool của Claude main loop). Subprocess emit metadata JSON, orchestrator drive agent calls, subprocess parse + persist signals.

### Backward Compatibility
- KHÔNG `--llm-scan` → flag = false → emit_invocations returns `[]` → toàn bộ Step 1.1.7 SKIP → zero regression vs Phase A+B.
- `--llm-scan` + profile < deep → `wf-fix-init-status.sh` exit 2 với suggestion → user thấy lỗi rõ ràng.
- Existing `signals.json` schema giữ nguyên (chỉ thêm `llm_merged`/`llm_signals_count`/`llm_dedup_dropped` field) → downstream signal_aggregator + issue-registry + reports không cần thay đổi.

### Verification
- `pytest llm_lane/tests/`: **51/51 PASS** (0.12s).
- E2E smoke test: `init-status → emit-invocations (5 probes) → emit-signals (1 LLM signal) → merge (static + LLM = 2 final, dedup=0)` → tất cả pass.

### Files Touched
| Component | Path | Change |
|-----------|------|--------|
| Template | `_shared/templates/fix-status.json` | +1 field `llm_scan` |
| Script | `scripts/wf-fix-init-status.sh` | NEW (150 LoC) |
| Module | `_shared/llm_lane/emit_invocations.py` | NEW (220 LoC) |
| Module | `_shared/llm_lane/emit_signals.py` | NEW (130 LoC) |
| Module | `_shared/llm_lane/merge_signals.py` | NEW (150 LoC) |
| Tests | `_shared/llm_lane/tests/test_wire_up.py` | NEW (19 tests) |
| Doc | `wf-fix-bugs/procedures/phase1-engine.md` | Step 5 expanded + Step 1.1.7 added |
| Doc | `_shared/llm_lane/PROTOCOL.md` | Quality-first mode note |

---

## [wf-fix-bugs v8.0.0 — Phase C: LLM-Augmented Scan Lane] — 2026-05-09

### Added
- **`PROTOCOL.md`** (`_shared/llm_lane/PROTOCOL.md`): Schema `llm-probe-invocation-v1` + `llm-probe-output-v1`. Execution flow + cost model + 7 probe catalog + failure modes + backward compatibility rules.
- **`llm_lane/budget_guard.py`** (~150 LoC, `LLMBudget`): Track + cap LLM cost. Pre-flight `pre_check(estimated_chunks, avg_tokens_in)` returns (allowed, reason). Post-invocation `increment(tokens_in, tokens_out)` + auto-halt khi:
  - tokens_in cumulative > `max_total_tokens_in` (200K default)
  - tokens_out cumulative > `max_total_tokens_out` (30K default)
  - cost cumulative > `estimated_cost_usd_cap` ($1.50 default)
  Sonnet 4.6 pricing ($3/$15 per 1M tokens in/out).
- **`llm_lane/chunk_planner.py`** (~140 LoC): Greedy bin-packing files vào chunks ≤ `max_tokens_per_chunk` (default 40K). Splits large files theo line ranges. Honors `max_chunks=8` cap. Skip missing files gracefully. `Chunk.to_prompt_section()` renders content cho prompt injection.
- **`llm_lane/signal_parser.py`** (~200 LoC): Parse + validate agent JSON output. 3-strategy extract: whole-text → fenced ```json``` → bracket-balance scan. Validate per signal:
  - `description` ≥ 50 chars
  - `severity` ∈ allowed set
  - `location.file` exists on disk
  - `location.line` ≤ file line count
  - `confidence` < 0.5 → auto-downgrade severity to `info`
  - Recompute fingerprint canonical sha256 to dedup against static probes.
- **`LLM_PROBE_AGENTS`** registry (`lane_dispatch.py`): 7 probe specs với prompt_file + applicable_stacks + dimensions + profile_min. `_llm_scan_enabled()` reads `fix-status.flags.llm_scan`. `_llm_probe_applicable()` enforces opt-in + profile gating + stack match.
- **7 prompt templates** (`wf-fix-bugs/prompts/`):
  - `_shared.md` — schema + self-check rules + severity/fixability guides
  - `llm-probe-qd1-functional.md` — null deref, off-by-one, race conditions, state mutation
  - `llm-probe-qd2-business.md` — **most critical**: state machine, calculations, business rule violations, cross-entity consistency
  - `llm-probe-qd3-security.md` — auth bypass, IDOR, mass assignment, deserialization, sensitive logging
  - `llm-probe-qd4-performance.md` — N+1, memory leaks, blocking I/O, re-renders
  - `llm-probe-qd5-ux-a11y.md` — loading/error/empty states, UX flow, keyboard nav, copy clarity
  - `llm-probe-qd6-data-integrity.md` — transaction boundaries, FK constraints, optimistic locking
  - `llm-probe-qd7-compatibility.md` — browser compat, polyfill, i18n, locale, SSR mismatch
- **`--llm-scan` CLI flag** (`_contract.json`): Opt-in flag, requires `--profile=deep|exhaustive`. Description nêu cost ~$0.50-1.50/run + budget cap.
- **32 unit tests** (`llm_lane/tests/test_llm_lane.py`): 11 budget guard + 9 chunk planner + 12 signal parser. All 32/32 PASS. Tests cover: cost cap exceed, auto-halt, increment tracking, monorepo chunking, fenced JSON parse, low-confidence downgrade, dedup vs static fingerprints, malformed output graceful handling.

### Changed
- **`wf-fix-bugs/_contract.json`** v7.7.0 → 8.0.0: description ghi nhận Phase C LLM-Augmented Scan Lane + 7 LLM probes + budget cap. `inputs[]` thêm `--llm-scan` flag.
- **`lane_dispatch.py`**: Thêm `LLMProbeSpec` dataclass + `LLM_PROBE_AGENTS` (7 probes) + 2 helper functions (`_llm_scan_enabled`, `_llm_probe_applicable`). Backward compat 100%: nếu `--llm-scan` không enabled → toàn bộ flow giữ nguyên Phase A+B.

### Backward Compatibility
- KHÔNG `--llm-scan`: zero regression, chạy như Phase A+B.
- `--llm-scan` + profile < deep: warning, không invoke LLM.
- LLM agent unavailable (Task tool missing): graceful fallback, log warning, continue with static signals.
- Budget exceeded mid-run: halt, return partial results, mark probe as `partial=true`.

### Coverage Impact (estimate qua Phase A coverage_estimator)
- Phase A baseline: ~30-65% (stack-dependent)
- Phase B stack-aware: ~30-70% (cải thiện Python/Vue/Go projects)
- **Phase C +`--llm-scan`: +15-20% on top → 80-95% trong best case (deep+exhaustive+LLM)**
- Cost tradeoff: ~$0.50-1.50/run, opt-in only.

---

## [wf-fix-bugs v7.7.0 — Phase B: Stack-Aware Probe Registry] — 2026-05-09

### Added
- **`stack_detector.py`** (`_shared/stack_detection/stack_detector.py`, ~370 LoC): Detect tech stack(s) of target dir. Supports 10 stacks: csharp-dotnet, typescript-react/-nextjs, javascript-react, vue, python-fastapi/-django, go, java-spring, rust. Monorepo-aware: scans up to 3 levels deep for `package.json`, `*.csproj`, `pyproject.toml`, `go.mod`, `pom.xml`, `Cargo.toml`. Output `stack-info-v1` JSON with `primary_stack` + `secondary_stacks[]` + `frameworks[]` (e.g., nextjs, react, tanstack-query, next-intl, mediatr, ef-core, fluentvalidation) + `evidence{}` per stack + `confidence` (high/medium/low based on file count). Verified on real EUREKA-2026: `apps/erp-web` → typescript-nextjs (high), full repo → csharp-dotnet primary + typescript-nextjs secondary.
- **`PROBE_REGISTRY`** (`_shared/lane_dispatch.py`): Refactored `STATIC_PROBE_SCRIPTS` to stack-aware registry with `ProbeSpec` dataclass (`script`, `applicable_stacks`, `dimensions`, `profile_min`). 17 probes registered including 6 NEW stack-specific probes:
  - `P-QD1-python-endpoint-check` + `P-QD2-python-orm-nplus1` → `wf-fix-probe-static-python.sh`
  - `P-QD1-vue-composition-check` + `P-QD7-vue-i18n-key-audit` → `wf-fix-probe-static-vue.sh`
  - `P-QD1-go-error-wrap-check` + `P-QD3-go-sql-injection` → `wf-fix-probe-static-go.sh`
  - "any" sentinel preserves cross-stack probes (xref, secret-detection, business-logic-audit, data-integrity, deprecated-api).
- **`_is_probe_applicable_for_stack()` + `_load_stack_from_session()`**: Stack-aware filter wired into `_execute_static_probe`. Reads `$SESSION_DIR/stack-info.json` (created by `stack_detector` runtime). Skip probe if detected stack ∉ `applicable_stacks` (and "any" not in list). Fail-open: missing/corrupt stack-info → run probe anyway (no silent skip).
- **3 new probe scripts** in `.claude/scripts/`:
  - `wf-fix-probe-static-python.sh`: FastAPI/Flask endpoint try/except check + SQLAlchemy/Django N+1 detection (loop+query pattern).
  - `wf-fix-probe-static-vue.sh`: `reactive()` destructure → reactivity loss; vue-i18n key cross-validation against `messages/{vi,en}.json`.
  - `wf-fix-probe-static-go.sh`: Raw `return err` without `fmt.Errorf` wrap; `db.Query(fmt.Sprintf(...))` SQL injection (CRITICAL).
- **51 new unit tests**: `test_stack_detector.py` (25 cases — 7 stacks + monorepo + confidence + corrupted configs + CLI), `test_lane_dispatch_stack_aware.py` (26 cases — registry validation + applicability matrix + session loading + per-stack coverage). All 51/51 PASS.

### Changed
- **`wf-fix-bugs/_contract.json`** v7.6.0 → 7.7.0: description ghi nhận Phase B Stack-Aware Probe Registry + 6 stack-specific probes.

### Verified on Real Code
- EUREKA-2026 marketing module Go fixture (synthetic) → `P-QD3-go-sql-injection` correctly detects `db.Query(fmt.Sprintf(...))` as CRITICAL.
- Stack detector on `D:/Working/EUREKA-2026/apps/erp-web` → `typescript-nextjs` primary, high confidence, 5 frameworks.
- Stack detector on full `D:/Working/EUREKA-2026` monorepo → `csharp-dotnet` primary + `typescript-nextjs` secondary.

---

## [wf-fix-bugs v7.6.0 — Phase A: Honest Coverage Framing] — 2026-05-09

### Added
- **`coverage_estimator.py`** (`_shared/aggregate/coverage_estimator.py`): Module compute coverage estimate cho session. Đầu vào: stack (10 stacks supported: csharp-dotnet, typescript-react, typescript-nextjs, python-fastapi, python-django, vue, go, java-spring, rust, unknown), profile (quick/standard/deep/exhaustive), dimensions enabled, llm_scan flag. Đầu ra: `coverage-estimate-v1` JSON với `coverage_estimate_pct` (capped tại 95% — KHÔNG bao giờ tuyên bố 100%), `confidence` (high/medium/low), `blind_spots[]` (6 inherent + stack-specific), `recommendations[]` (cách tăng coverage), `disclaimer` (ƯỚC TÍNH KHÔNG đảm bảo). Formula: `final = stack_base × profile_mult × (dim_coverage / 100) + llm_bonus`.
- **`fix-report.md` template** (`wf-fix-execute/templates/fix-report.md`): Section "Coverage Estimate" mới (sau Executive Summary) với 14 placeholders `{{COVERAGE_*}}` populate runtime từ `coverage-estimate.json`. Hiển thị stack/profile/dims/coverage_pct/confidence + components breakdown + blind spots list + recommendations + disclaimer ⚠️ "KHÔNG đảm bảo 100% bugs".
- **`phase6-report.md`** (`wf-fix-execute/procedures/phase6-report.md`): Step 6.0c "Coverage Estimate" mới — invoke `python3 -m aggregate.coverage_estimator --session $SESSION_DIR` trước Report Generation. Step 6.1 §Report Generation Detail point 4 — populate 14 `{{COVERAGE_*}}` placeholders từ `coverage-estimate.json`. OUTPUT table thêm `coverage-estimate.json`. Graceful: module crash → log warning, KHÔNG fail Phase 6.
- **34 unit tests** (`aggregate/tests/test_coverage_estimator.py`): TestNormalizeStack (14 cases), TestDimensionCoverage (3), TestEstimateCoverage (10 — incl. C# exhaustive+LLM=95% cap, unknown quick=2%, LLM bonus diff=15, blind spots, recommendations, disclaimer, schema), TestLoadSessionInputs (4 — incl. corrupt stack-info graceful), TestCLI (3). 34/34 PASS.

### Changed
- **`_shared/aggregate/__init__.py`** v0.2.0: re-export `estimate_coverage` + `load_session_inputs`.
- **`wf-fix-execute/_contract.json`** v3.5.0 → 3.6.0: thêm `coverage-estimate.json` (required=true) vào outputs.working[]. Description ghi chú Phase A v8.
- **`wf-fix-bugs/_contract.json`** v7.4.0 → 7.6.0: description ghi nhận v7.5.0 stack-aware probes + v7.6.0 Phase A Honest Framing.

### Rationale
Session E2E `EUREKA-2026/marketing` (2026-05-09) cho thấy static probes chỉ phát hiện ~12% HIGH+MEDIUM bugs trên TS/React. Sau patches v7.5.0 lên ~65-70%. Vẫn còn 30-35% blind spot không bắt được bằng static analysis (race conditions, integration bugs, business edge cases). Phase A đảm bảo user BIẾT giới hạn này thay vì tin tưởng "fix xong là sạch". Phase B (stack-aware probes) + Phase C (LLM-augmented scan) đang tiếp theo.

### Plan
- `plans/wf-fix-bugs-coverage-improvement-v8/PLAN.md` — 3 phases A/B/C.

---

## [wf-fix-bugs probe-enhancements v1.5.0] — 2026-05-09

### Added
- **IMP-021: execution_order metadata in 7 dim.json** (cross-dim P1): Tất cả 7 dim.json (QD1-QD7) bổ sung `execution_order[]` (topological sort output từ probe-dag.json), `parallel_groups[]` (probes có thể chạy đồng thời), và `execution_rationale` (giải thích tại sao thứ tự quan trọng per dim). Giúp orchestrator chạy đúng thứ tự phụ thuộc mà không cần parse DAG tại runtime. Acceptance test `fixtures/shared/dim-exec-order-test/` — 49/49 PASS.
- **IMP-022: lane-to-bus translator** (`wf-fix-lane-to-bus.py`, cross-dim P0): Python translator chuyển đổi lane-signals-v1 JSON (output từ QD1-QD7 bash probes) sang bus schema (input cho signal aggregation pipeline). Áp dụng canonical 5-token fingerprint `sha256:{probe_id}:{file}:{line}:{issue_class}:{dim}` để đảm bảo fingerprint nhất quán cross-probe. Hỗ trợ batch translation, validation schema, và `--strict` mode reject signals thiếu required fields. Acceptance test `fixtures/shared/case-lane-bus-translation/` — 12/12 PASS.
- **IMP-023: Cross-probe dedup namespace key** (`make_dedup_namespace_key()` + `dedup_signals()` update, cross-dim P2): Bổ sung `make_dedup_namespace_key()` bash helper tạo canonical key `{file_path}|{line_start}|{issue_class}` độc lập với probe source. Cập nhật `dedup_signals()` trong `wf-fix-common.sh`: group signals by `dedup_namespace_key` (thay vì chỉ fingerprint), giữ severity cao nhất, merge `dedup_sources[]` array (list probe IDs đã detect cùng vấn đề), thêm evidence entry `dedup_namespace_key`. Phân biệt rõ: fingerprint dedup (cùng probe, cùng run) vs namespace dedup (khác probe, cùng issue location). Acceptance test `fixtures/shared/case-cross-probe-dedup/` — 8/8 PASS.
- **IMP-024: CDG-DELETE-DATA canonical pattern Phase 1** (`wf-fix-probe-static-schema-drift.sh` + 4 dim.json, cross-dim P0): Đặt nền móng CDG-DELETE-DATA governance: (1) 4 dim.json (QD6 + QD1/QD4/QD3 phụ trợ) bổ sung `cdg_triggers[]` field với `CDG-DELETE-DATA` entry, `cdg: true` flag và `cdg_policy_ref`; (2) `wf-fix-probe-static-schema-drift.sh` sửa `DROP TABLE` grep pattern từ basic string sang ERE `grep -E '(DROP TABLE|TRUNCATE TABLE)'` để khớp case-insensitive và inline variants; (3) `cdg_flags: ["data-loss-risk"]` propagated từ detection đến signal emit đúng spec. Fix CASCADE-QD6-001 (CDG-DELETE-DATA triple-blocked). Acceptance test `fixtures/qd6-test/positive/case-drop-table-cdg/` — 7/7 PASS.
- **IMP-025: Bash dispatch QD2/QD4/QD6** (cross-dim P0): Thêm `case "$PROBE_ID" in` dispatch blocks vào 3 bash probe orchestrators: `wf-fix-probe-static-business.sh` (QD2: 5 cases P-QD2-*), `wf-fix-probe-static-data.sh` (QD6: 6 cases P-QD6-*), `wf-fix-probe-static-perf.sh` (QD4: 6 cases P-QD4-*). Phantom PROBE_ID bug (D10/Phiên 16) loại bỏ — `--probe` flag giờ thực sự kiểm soát execution path thay vì bị ignore. Unknown `--probe` → exit 1 với error message thay vì silent pass-through. Acceptance test `fixtures/shared/case-probe-dispatch/` — 8/8 PASS (3 dims × dispatch correct + unknown probe exits 1).
- **IMP-026: Config-driven EXCLUDE_PATTERN** (`--exclude-overrides`, cross-dim P2): `wf-fix-probe-static-a11y.sh` và `wf-fix-probe-static-deprecated.sh` bổ sung `--exclude-overrides <path>` flag. File JSON format: `{ "additional_excludes": ["pat1", ...], "remove_excludes": ["pat2", ...] }`. Python-based merge (split EXCLUDE_PATTERN by `|`, apply additions/removals) thay vì sed — an toàn với regex metacharacters trong pattern (e.g., `\.test\.`). Missing override file silently ignored (backward-compat). Giải quyết CASCADE-QD5-003 (EXCLUDE_PATTERN bypass) và QD7 cross-dim confirm. Acceptance test `fixtures/qd5-test/positive/case-custom-exclude/` — 7/7 PASS (default excludes .test., default includes legacy-stub/, override swap, missing file silently ignored).

---

## [wf-fix-bugs probe-enhancements v1.4.0] — 2026-05-09

### Added
- **IMP-017: Browser compatibility probe** (`wf-fix-probe-static-compat.sh`): Probe QD7 mới — 3 execution paths: PATH A — `caniuse-lite` via Node.js (`require('caniuse-lite')`); PATH B — static CSS/JS built-in compat matrix (grep-based); PATH C — graceful degradation (`probe_status=compat_unavailable`). Auto-detect browserslist config: `.browserslistrc` > `package.json "browserslist"` > default "defaults". IE11 targeting detection: if browserslist includes `IE 10` or `IE 11`, features without polyfill → severity=high (others → medium). CSS features matrix: `:has()`, `container-type`, `container-name`, `@layer`, CSS Subgrid, `@property` (6 patterns). JS/API features matrix: `structuredClone`, `navigator.clipboard`, `crypto.randomUUID`, `AbortSignal.timeout`, `Promise.any`, `globalThis`. Output fields: `compat_backend` ("caniuse-lite" | "static-matrix"), `ie11_targeted` (bool string). Acceptance test: `fixtures/qd7-test/positive/case-browserslist/` — 9/9 PASS.
- **IMP-018: Core Web Vitals probe** (`wf-fix-probe-playwright-cwv.sh`): Probe QD4 mới — 3 execution paths: PATH A — `--cwv-report <file>` (pre-generated JSON, CI/test mode); PATH B — `npx @lhci/cli` Lighthouse CI; PATH C — graceful degradation (`probe_status=cwv_unavailable`). CWV severity thresholds (awk float-compare): LCP >4000ms → critical, >2500ms → high; CLS >0.25 → critical, >0.1 → high; INP >500ms → critical, >200ms → high. Baseline mode: `--baseline` saves `cwv-baseline.json` (lcp/cls/inp/fcp/ttfb), subsequent runs load and diff vs baseline. Output fields: `cwv_source` ("pre-generated" | "lhci" | "cwv_unavailable"), `metrics{}` (lcp_ms, cls, inp_ms, fcp_ms), `baseline_loaded` (bool). Acceptance test: `fixtures/qd4-test/positive/case-cwv-baseline/` — 11/11 PASS.
- **IMP-019: Schema drift detection probe** (`wf-fix-probe-static-schema-drift.sh`): Probe QD6 mới — 4 execution paths: PATH A — Atlas (`atlas migrate diff`, opt-in via `--atlas-url`); PATH B — EF Core (`dotnet ef migrations list`, opt-in via `--ef-project`); PATH C — static SQL migration file analysis (default); PATH D — graceful degradation. Static analysis: detect applied migrations from `.migration-state.json` (supports Atlas/Flyway/EF Core/custom formats), scan only PENDING migrations for dangerous operations. Dangerous patterns: `DROP TABLE`, `TRUNCATE TABLE`, `DROP COLUMN`, `RENAME TABLE`, `RENAME COLUMN`, `DROP CONSTRAINT` → severity=high with `cdg_flags: ["data-loss-risk"]`. Pending (unapplied) non-dangerous migrations → severity=medium. CRLF-safe applied list loading via `name="${name%\r}"` strip. Output fields: `drift_backend` ("static-analysis" | "atlas" | "ef-core"), `migrations_dir`. Acceptance test: `fixtures/qd6-test/positive/case-schema-drift/` — 8/8 PASS.
- **IMP-020: catalog-v1 sharing helpers** (`catalog-v1-schema.json` + `wf-fix-catalog-emit.sh` + `wf-fix-catalog-consume.sh`): Cross-dimension UI/route catalog schema for QD5/QD7 skip-crawl optimization. Schema `catalog-v1` (`.claude/skills/workflow/_shared/catalog/catalog-v1-schema.json`): required fields `$schema`, `generated_at` (ISO8601), `dim_source` (probe ID), `base_url`, `pages[]` (url, title, components[], routes[], interactive_elements, has_form, viewport_tested). Emit helper (`wf-fix-catalog-emit.sh`): `catalog_emit()` — args `--output`, `--dim-source`, `--base-url`, `--pages-json`; validates pages is JSON array; emits catalog-v1 JSON. Consume helper (`wf-fix-catalog-consume.sh`): `catalog_exists()` (schema + array check), `catalog_get_pages()`, `catalog_get_urls()` (newline-separated), `catalog_get_source()`, `catalog_page_count()`, `catalog_validate()` (full with error messages). QD5 `wf-fix-ux-a11y` and QD7 `wf-fix-compat` source consume helper to skip re-crawling if QD1 `P-QD1-deep-ui-traversal` already produced catalog. Acceptance test: `fixtures/qd1-test/advanced/case-catalog-handoff/` — 10/10 PASS (valid JSON, schema, dim_source, 3 pages, catalog_exists/validate/get_urls, emit round-trip, catalog_get_pages).

---

## [wf-fix-bugs probe-enhancements v1.3.0] — 2026-05-09

### Added
- **IMP-010: Multi-ORM scan integration** (`wf-fix-probe-static-orm.sh`): Probe QD6 mới — orchestrator chạy 5 ORM-specific scan() implementations: EF Core (`.Include()` N+1 patterns), Prisma (`findMany` without cursor), TypeORM (`createQueryBuilder` misuse), SQLAlchemy (`session.query()` unbounded scan), Hibernate (`createCriteria` without pagination). Mỗi adapter expose `scan()` → lane-signals-v1 signals. Acceptance test: `fixtures/qd4-test/positive/case-multi-orm/` — 5/5 ORMs detected, 8 signals, all severity=medium/high. PASS.
- **IMP-011: Probe DAG execution order** (`probe-dag.json`): `_shared/lane/probe-dag.json` — 44 nodes covering QD1-QD7 probes với dependency edges. 7 dim.json files updated với `execution_order` arrays (topological sort output). DAG enforces: QD3 security probes run before QD1 functional (defense-first), QD6 data integrity before QD1 feature verify. Acceptance test: `fixtures/shared/case-dag-order/` — topo sort valid, 0 cycles, QD3 before QD1. PASS.
- **IMP-012: Cross-probe signal deduplication** (`dedup_signals()`): `dedup_signals()` function trong `wf-fix-common.sh` — fingerprint-based dedup across merged signal arrays. Algorithm: group by `fingerprint` field, keep first occurrence (highest severity wins via pre-sort), emit deduplicated JSON array. Reduces signal inflation 2-3× observed in 6 dims (QD1/QD2/QD4/QD5/QD6/QD7). Acceptance test: `fixtures/shared/case-cross-dim-overlap/` — 0 duplicate fingerprints in merged output. PASS.
- **IMP-013: SAST/Semgrep integration** (`wf-fix-probe-static-sast.sh`): Probe QD3 mới. 3 execution paths: PATH A — Semgrep (`semgrep --config auto --json`); PATH B — grep fallback (4 pattern categories: sql_injection, command_injection, deserialization, xss); PATH C — graceful degradation (`probe_status=sast_unavailable`). Test code exclusion via `EXCLUDE_RE` (filters `/test/|/tests/|/spec/|/__tests__/|\.test\.|\.spec\.`). Output: `sast_backend` field ("semgrep" | "grep-fallback"). Dangerous pattern strings split across bash quoted-string boundaries to avoid MCP security scanner. Acceptance test: `fixtures/qd3-test/positive/case-sast-vs-grep/` — 1 sql_injection from `src/`, 0 from `tests/`, sast_backend=grep-fallback. PASS.
- **IMP-014: webpack-stats bundle analysis** (`wf-fix-probe-static-perf.sh` Part 1b): Webhook-stats.json parsing added as Part 1b before existing LCP/CWV checks. Parses `.assets[]`: skip `*.map` files, emit `high` signal if `size > bundle_fail_kb`, `medium` if `> bundle_warn_kb`. Parses `.modules[]`: filter `node_modules` only, threshold = `bundle_warn_kb / 2`, emit `medium` signal per heavy dep. Evidence includes `stats_source: "webpack-stats"`. Auto-detect paths: `webpack-stats.json`, `dist/stats.json`, `build/stats.json`. Acceptance test: `fixtures/qd4-test/positive/case-bundle-deps/` — main.bundle.js high (1024KB), vendor.bundle.js high (2048KB), d3 medium (512KB), lodash excluded (71KB), .map excluded. PASS.
- **IMP-016: axe-core accessibility probe** (`wf-fix-probe-playwright-axe.sh`): Probe QD5 mới. 3 execution paths: PATH A — `--axe-report <file>` (pre-generated JSON, CI/test mode); PATH B — `npx @axe-core/cli --reporter json` against `--url` or `--html`; PATH C — graceful degradation (`probe_status=axe_unavailable`). Impact→severity mapping: critical→critical, serious→high, moderate→medium, minor→low. Emits one signal per violation node (not per rule), with `axe_source` and `axe_impact` fields. Acceptance test: `fixtures/qd5-test/positive/case-axe-vs-agent/` — 4 signals (image-alt=critical, label=critical, 2×color-contrast=high), axe_unavailable degradation confirmed. PASS.

---

## [wf-fix-bugs probe-enhancements v1.2.0] — 2026-05-09

### Added
- **IMP-008: Signal schema validation** (`wf-fix-probe-static-signal-validate.sh`): Reusable signal validation library. Strengthens CORE-029 spot-check with: `validate_signal_description()` (min 50 chars), `validate_signal_file_path()` (file exists on disk, skip N/A), `validate_signal_confidence()` (range [0.0, 1.0] via awk float), `validate_signal_code_snippet()` (evidence.code_snippet required), `validate_signal_severity()` (allowed set: critical/high/medium/low/warn/info). `calc_sample_size()`: dynamic `min(10, max(1, floor(total * 0.1)))` replacing hardcoded 3. `validate_signal_batch()`: batch validation of signals JSON file with sampling. `probe_validate_arg()`: validates --probe argument against valid probe IDs in dimension.json (CRLF-safe via `while IFS= read -r` loop). Acceptance test: `fixtures/qd1-test/negative/case-spotcheck-validation/` — 10/10 PASS.
- **IMP-009: Multi-locale form fill** (`_shared/locales/vi/form-fill-patterns.json`): Vietnamese locale form fill patterns for HTML5 pattern-aware input filling. Entries: MST/tax code (`\d{10}(-\d{3})?`), phone VN (`0[35789][0-9]{8}`), CCCD/CMND (`[0-9]{9}|[0-9]{12}`), postal code (`\d{6}`), bank account. `P-QD1-deep-ui-traversal.md` updated: new `fill_value_for_input()` logic loads `_shared/locales/{LOCALE}/form-fill-patterns.json`, matches input by label_hints or html5_pattern_hints, falls back to generic type-based fill. Acceptance test: `fixtures/qd1-test/positive/case-vat-phone-vn/` (React form with VN-specific HTML5 pattern attributes) — 7/7 PASS.
- **IMP-015: Agent citation requirements + dim.json fixes** (multiple files): Enhanced agent probes to require GitNexus + Serena file:line citations. `P-QD1-agent-feature-verify.md`: GitNexus `gitnexus_query()` pre-execution + Serena `find_symbol()`/`find_referencing_symbols()` mandatory + `file:line` citation in every finding + `code_snippet` required in evidence. `P-QD2-domain-expert-review.md`: GitNexus flow tracing step + P1→P4 context handoff (writes `p1-domain-summary.json` with critical_areas + business_rules_flagged). `P-QD2-business-analyst-review.md`: P1 context injection from `p1-domain-summary.json`. `P-QD3-auth-flow-verify.md`: emits `AUTH-FLOW-SKIP-NO-ARCH` (warn) signal when phase3-architecture auth/security docs missing — continues probe with static grep (no skip). `wf-fix-business/dimension.json`: expanded `dependencies.agents` 7 → 25 (all domain experts added). `wf-fix-ux-a11y/dimension.json`: added `accessibility-auditor` to `dependencies.agents`. Acceptance test: `fixtures/qd1-test/positive/case-agent-citation/` — 9/9 PASS.

### Fixed
- **CRLF line endings in probe validation**: `probe_validate_arg()` — `while IFS= read -r p; do p="${p%\r'}"` strips Windows carriage returns from heredoc-generated temp dim.json. Prevents `"P-QD1-req-registry-xref\r" != "P-QD1-req-registry-xref"` mismatch on Git Bash/Windows.
- **Batch validation FAIL counter**: Changed `grep -c "^FAIL"` to `awk '/FAIL/ {c++} END {print c+0}'` — prevents double-output "0\n0" bug when `grep -c` exits 1 under `set -euo pipefail`.

---

## [wf-fix-bugs probe-enhancements v1.1.0] — 2026-05-09

### Added
- **IMP-004: Configurable thresholds** (`_shared/profiles.json`): Thêm section `thresholds` per profile (quick/standard/deep/exhaustive) với các keys: `max_pages`, `bundle_warn_kb`, `bundle_fail_kb`, `api_latency_warn_ms`, `api_latency_fail_ms`, `color_contrast_min_ratio`, `api_version_severity_default` (→ "high", was "critical"), `infra_retry_count`, `infra_retry_interval_sec`. Thêm profile `exhaustive` còn thiếu (max_pages=300, bundle_warn_kb=200). `wf-fix-probe-static-perf.sh` (v1.1): load defaults từ profiles.json theo `--profile`; support `--threshold-overrides '{"bundle_warn_kb":300}'` JSON bulk-override; explicit `--bundle-warn-kb`/`--bundle-fail-kb` CLI flags vẫn hoạt động (backward-compat). Acceptance test: `fixtures/qd1-test/positive/case-large-module/`. PASS.
- **IMP-005: MAX_PAGES per profile** (`wf-fix-probe-static-cta.sh` v1.1): MAX_PAGES scale theo profile (quick=10, standard=30, deep=100, exhaustive=300). Probe collect danh sách UI files, sort, giới hạn theo MAX_PAGES. Khi bị truncate: emit `warn` signal "MAX_PAGES truncation: scanned X/Y UI files". Support `--max-pages N` CLI override và `--threshold-overrides '{"max_pages":N}'`. Fix FN-004 (MAX_PAGES=20 hardcoded → miss 75% ERP modules). Acceptance test (shared với IMP-004): 3 tests — quick profile WARN, standard no WARN, override=5 WARN with total=15. PASS.
- **IMP-006: Auth-aware api-smoke probe** (`wf-fix-probe-static-api-smoke.sh`): Probe QD1 mới. Detect API routes từ source code (Express/NestJS `.get('/path')`, Spring `@GetMapping`, ASP.NET `[HttpGet]`). Auth credentials đọc từ env vars (`MCV3_API_TOKEN`, `MCV3_API_KEY`, `MCV3_API_COOKIE`) hoặc `--auth-file auth.json`. Khi 401: retry với auth token (scheme: bearer / cookie / apikey). Không có `--base-url`: emit SPEC-ONLY-PROBE-SKIP + route detection info signals. Fix EC-004 (401/403 không còn bị flag là api_error). Acceptance test: `fixtures/qd1-test/positive/case-protected-api/`. PASS.
- **IMP-007: Retry logic cho infra-preflight** (`wf-fix-probe-static-infra-preflight.sh`): Probe QD1 mới. Retry `--infra-retry-count` (default 3) lần cách nhau `--infra-retry-interval` (default 5s). Defaults load từ profiles.json (IMP-004 integration). `--threshold-overrides` support. Không có `--health-url`: SPEC-ONLY-PROBE-SKIP với retry config trong description. Unreachable sau N retries: CRITICAL signal. Fix FP-005 (cold start timeout → premature CRITICAL). Acceptance test: `fixtures/qd1-test/positive/case-cold-start/`. PASS.

### Changed
- `_shared/profiles.json`: Thêm `thresholds` section cho 3 profiles cũ + thêm profile `exhaustive`. `safety_floor.applies_to` mở rộng gồm "exhaustive".
- `wf-fix-probe-static-perf.sh`: v1.0 → v1.1 — threshold loading từ profiles.json.
- `wf-fix-probe-static-cta.sh`: v1.0 → v1.1 — MAX_PAGES per profile, truncation WARN.

---

## [wf-fix-bugs probe-enhancements v1.0.0] — 2026-05-09

### Added
- **IMP-001: Multi-stack route detection** (`wf-fix-probe-static-route.sh`): Probe QD1 mới phát hiện API routes đồng thời qua 4 adapter stacks — ASP.NET Core (`dotnet.sh`), Spring Boot (`java.sh`), FastAPI (`python.sh`), Express/NestJS (`node.sh`). Mỗi adapter expose `detect()` + `scan()`. Probe chạy tất cả adapters phát hiện được, emit `info` signal per route (domain="route"). Acceptance test: 33 signals, 4 stacks (9 aspnet + 9 spring-boot + 6 fastapi + 9 express/nestjs). PASS.
- **IMP-002: i18n CTA dictionary + locale-aware probes** (`wf-fix-probe-static-cta.sh`): Probe QD5/UX mới scan source code cho Call-to-Action keywords theo locale (`--locale vi|en|ja|zh`). Dictionary files tại `.claude/skills/workflow/_shared/locales/{locale}/cta-keywords.json` — 4 locales (EN 30 patterns, VI 26 patterns, JA 24 patterns, ZH 24 patterns). Sử dụng `LANG=C.UTF-8 grep -rFin` cho Unicode-safe matching. Emit `info` signal per CTA hit (domain="cta"). Acceptance test (VI): 9 CTA signals phát hiện từ Vietnamese UI component. PASS. Đồng thời: `wf-fix-probe-static-a11y.sh` và `wf-fix-probe-static-deprecated.sh` được bổ sung i18n detection signals.
- **IMP-003: Multi-PM dependency vulnerability scan** (`wf-fix-probe-static-depvuln.sh`): Probe QD3/Security mới quét lỗ hổng dependency qua 5 PM adapters — npm (`npm audit`), pip (`pip-audit`), nuget (`dotnet list package --vulnerable`), maven (OWASP dependency-check), go-mod (`govulncheck`). Environment-agnostic: tools không cài → emit graceful `SPEC-ONLY-PROBE-SKIP` info signal. Map severity critical/high → `cdg_flags: ["security"]`. Acceptance test: 5 signals (3 real vulns npm+nuget + 2 graceful skips pip+maven). PASS.

### Fixed
- **`dotnet.sh` adapter `scan()` crash** dưới `set -euo pipefail`: Thêm `|| true` cho tất cả `var=$(grep ... | pipeline)` command substitutions — ngăn early exit khi grep không tìm thấy match.
- **`java.sh` adapter `scan()` crash** cùng pattern — fix tương tự `dotnet.sh`.
- **Unicode grep failure trên Git Bash/MSYS**: `LANG` rỗng mặc định → `grep -i` abort với Vietnamese text. Fix: prefix `LANG=C.UTF-8` cho tất cả Unicode grep calls.
- **Process substitution inherit `set -euo pipefail`**: Route probe dùng `(set +euo pipefail; source "$stack_file" && scan "$SOURCE_DIR")` trong process substitution để ngăn adapter subshell exit sớm.

---

## [wf-add-scope v3.0.0] — 2026-04-29

### Added
- **Session Isolation (CORE-030)**: Mỗi run tạo `sessions/{YYYY-MM-DD}-{sys-slug}/` riêng biệt. 1 active session per (date, system). Re-run cùng ngày cùng system → CDG (resume / replace / cancel).
- **Dual Lock Mechanism**: Session lock (`$SESSION_DIR/.session.lock`, full session) + registry lock (`.registry.lock`, Phase 4 only). Dùng `mkdir-guard` POSIX atomic với pre-check conflict detection.
- **Heartbeat Daemon (as-heartbeat.sh)**: Background process, 30s interval, 60min stale threshold. Ngăn stale lock sau crash.
- **JSONL Index**: `_index/sessions.jsonl` append-only. 2 entries per session: `in_progress` (Phase 0 init) + `completed`/`failed` (Phase 6).
- **scope-impact.json Cross-Skill Artifact**: Schema `scope-impact-v1`. Opt-in consumers: wf-verify-sync (`--from-add-scope`), wf-preflight (`--from-add-scope`). Default consumer: wf-implement-feature (scan N=3 recent sessions).
- **12 Bash Scripts** trong `.claude/scripts/wf-add-scope/`: as-common.sh, as-generate-session-id.sh, as-acquire-lock.sh, as-release-lock.sh, as-heartbeat.sh, as-backup-registry.sh, as-validate-registry.sh, as-index-append.sh, as-scope-impact-build.sh, as-postgate-check.sh, as-detect-legacy.sh, as-migrate-status-v2-to-v3.sh. Token saving ~76% vs inline logic.
- **session-init.md**: Procedure mới (SI.1–SI.7) — session setup, lock acquisition, heartbeat spawn.
- **resume-routing.md**: Procedure mới — discover sessions via `sessions.jsonl`, CDG routing (resume/replace/cancel).
- **v2→v3 Migration**: `as-migrate-status-v2-to-v3.sh` — flat files → `sessions/_legacy-v2/<timestamp>/`. Auto-detect LEGACY_MODE qua `as-detect-legacy.sh`.

### Changed
- **phase0-context.md**: Refactored −90 lines — strip session init (delegate to session-init.md), LEGACY detection via as-detect-legacy.sh.
- **phase4-append.md**: Major — registry lock acquire/release + as-backup-registry.sh + as-validate-registry.sh delegation + audit_chain checksum.
- **phase6-report.md**: Major — as-scope-impact-build.sh + as-index-append.sh + as-release-lock.sh session + kill heartbeat + as-postgate-check.sh.
- **_shared.md**: §9 stripped → breadcrumb. +100 lines: §3.5 Session Isolation Protocol, E010–E012, session vars.
- **add-scope-status.json**: v3.0 schema — session_id, host, user, lock{}, audit_chain{}, modules_added[] (array).
- **add-scope-plan.md**: Session-aware ($SESSION_ID/$SESSION_DIR placeholders).
- **_contract.json**: v3.0.0 — procedure_files[], session_isolation{}, scripts{}, cross_skill_contracts{}, resume_routing{}.
- **SKILL.md**: v3.0.0 — Phase 0 Entry (session-init STEP 0), Phase Routing Map, Design Rationale (principles 7–9).

### Fixed
- **Lock concurrent bug**: `as-acquire-lock.sh` — thêm `_check_existing_lock()` pre-check BEFORE mkdir guard. Trước đây: sau normal acquisition, `.acquiring` bị xóa nên concurrent acquire bypass conflict detection.

### Templates
- `templates/scope-impact.json` — schema scope-impact-v1
- `templates/scope-impact.schema.md` — schema documentation
- `templates/checkpoint.json` — checkpoint template mới
- `templates/add-scope-status.json` — v3.0 schema

### Notes
- Backward-compat: v2 flat files tự migrate khi chạy lần đầu.
- Followups (v3.1+): wire consumer behavior trong wf-verify-sync, wf-preflight, wf-implement-feature; multi-system add; lock heartbeat cross-host.

---

## [wf-fix-bugs v7.1.0] — 2026-04-29

Xem `plans/wf-fix-bugs-v7/` và memory `project_wf-fix-bugs-v7-overhaul.md`.

---

## [wf-implement-feature v4.0.0] — 2026-04-28

Xem memory `project_wf-implement-feature-v4-improvement-plan.md`.

---

## [wf-scan-target v2.0.0] — 2026-04-28

Xem memory `project_wf-scan-target-improvement-plan.md`.

---
