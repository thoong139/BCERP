# wf-fix-bugs Phase Optimization Rollout Plan v10.15.0+

> **Mục đích:** Handoff document cho việc apply playbook (10 techniques) lên Phase 2-7 qua multiple sessions.
>
> **Status (2026-05-16, end of Session 4 — ROLLOUT-PLAN v10.15 COMPLETED):**
> - ✅ Playbook created: [`procedures/_optimization-playbook.md`](../../.claude/skills/workflow/wf-fix-bugs/procedures/_optimization-playbook.md)
> - ✅ Phase 1 fully optimized v10.14.0 (index router + 8 group files + 8 helper scripts) — smoke 42/42 PASS
> - ✅ Shared trace helpers created: `phase-trace-start.sh`, `phase-finalize.sh` (reusable cho Phase 2-7)
> - ✅ Phase 2 partial: migrated to shared trace scripts (Steps 2.2 + 2.5) — grandfathered (5 steps, <300 dòng — không cần T6 split)
> - ✅ **Phase 3 fully optimized v10.16.0** (Session 2): 109-line index + 7 group files (A-pregate-trace, B-isg-partition, C-workload-gate INLINE CDG-11, D-route-write, E-report, F-finalize, POST-GATE). Steps 3.2 + 3.7 migrated to shared trace scripts. Smoke test 35/35 PASS.
> - ✅ **Phase 6 fully optimized v10.16.0** (Session 2): 130-line index + 8 group files (A-setup, B-dry-run, C-impact-cdg INLINE CDG, D-spawn-execute INLINE Agent, E-validate-dashboard, F-report, G-finalize, POST-GATE). Step 6.7 migrated to shared `phase-finalize.sh`. Smoke test 40/40 PASS. Dry-run branching preserved (B → F skip C,D,E).
> - ✅ **Phase 5 fully optimized v10.17.0** (Session 3): 135-line index + 8 group files (A-setup E005 jump, B-aggregate steps 5.2+5.3, C-cdg-critical INLINE CDG, D-spawn-triage INLINE Agent CORE-037, E-validate-handoff steps 5.6+5.7 POST-GATE+INLINE CDG Pre-Execute, F-safety-check INLINE CDG blocker, G-reports-finalize steps 5.9+5.10 migrate phase-finalize.sh, POST-GATE T1-T4). Smoke test 42/42 PASS. Critical preservation: Step 5.4 CDG, Step 5.5 Agent({...}), Step 5.7 CDG Pre-Execute, Step 5.8 CDG blockers.
> - ✅ **Phase 7 fully optimized v10.17.0** (Session 3): 120-line index + 8 group files (A-setup E005 detect + route, B-cqg1 SKIP-if-E005, C-cqg2-cdg INLINE CDG REJECT 145 dòng structured fix-log check v10.10.0, D-mobile-dashboard, E-reports CORE-038 context budget, F-finalize GIỮ finalize-phase7.sh special case, G-todowrite-display ORCH UI, POST-GATE T1-T5 với CORE-036 fix-impact.json schema + audit_chain sha256). Smoke test 44/44 PASS (6 categories — extra check cross-skill artifact CORE-036). Critical preservation: Step 7.3 CQG-2 CDG REJECT, Steps 7.7-7.8 TodoWrite + Display ORCH UI. Phase 7 Step 7.6 KHÔNG migrate sang phase-finalize.sh do pre-finalize pipeline_status=DONE + dual-write global trace CORE-026 special case.
> - ✅ **Phase 4 fully optimized v10.18.0** (Session 4 — FINAL phase): 142-line index + 8 group files trong phase4-find-bugs/ (A-pregate-setup 118 dòng Steps 4.1+4.2 setup-lanes.sh, B-browser-cdg 130 dòng Step 4.3 INLINE AskUserQuestion E090 Missing URL + E090b BASE_URL Conflict multi-session safety, C-create-lanes 100 dòng Step 4.4 create-lane-dirs.sh, D-render-verify 164 dòng Step 4.5 render template substitution + Step 4.6 verify-lane-prompt.sh 6 check points, E-dispatch 158 dòng Step 4.5 **PARALLEL N×Agent({subagent_type:"claude", model:"opus"}) trong MỘT response duy nhất CORE-025 max 10 concurrent** — Playwright lanes TỰ acquire writer-lock playwright qua Protocol 22 KHÔNG split Wave, F-monitor-validate 137 dòng Step 4.7 monitor-lanes.sh + validate-lane-outputs.sh CORE-038 context budget tier, G-report-finalize 156 dòng Steps 4.8+4.9 generate-phase4-report.sh + **finalize-phase4.sh SPECIAL CASE GIỮ aggregation logic specific** signals_total từ 3 streams × N lanes + lanes_completed/failed filesystem scan + probe_failures log — KHÔNG migrate sang shared phase-finalize.sh do generic chỉ hỗ trợ static PHASE_TOP_FIELDS merge, pattern giống Phase 7 finalize-phase7.sh, POST-GATE 141 dòng T1-T4 với CORE-036 phase4-summary-v1 schema + audit_chain sha256 64-char). Smoke test 51/51 PASS (7 categories — extra Check 7 EXTRA Phase 4-specific PARALLEL Dispatch verification: MANDATORY DISPATCH PROTOCOL banner + Single-Response Parallel Dispatch + max 10 + subagent_type="claude"). Critical preservation: Step 4.3 Browser CDG E090/E090b INLINE AskUserQuestion x2, Step 4.5 PARALLEL Agent spawn INLINE N×Agent({subagent_type:"claude"}) trong MỘT response duy nhất, Step 4.9 finalize-phase4.sh GIỮ SPECIAL CASE.
>
> **Cross-phase verify (Session 4 final):** 6 smoke tests PASS **254/254 checks**, 0 regression (Phase 1: 42, Phase 3: 35, Phase 4: 51, Phase 5: 42, Phase 6: 40, Phase 7: 44). Compliance audit GRADE: PASS (CRITICAL 12/12, REQUIRED 13/13). Schema sync 0 errors.
>
> **✅ ROLLOUT-PLAN v10.15 COMPLETED — Pattern T6 (Phase Lazy-Load Split) fully validated qua TOÀN BỘ 6 phase optimizable (1, 3, 4, 5, 6, 7).** Phase 2 grandfathered (5 steps, <300 dòng — không cần T6 split). Tất cả 7 phases procedure file <12K tokens, không phase nào trigger /compact trên dự án lớn như EUREKA-2026.

## Per-Phase Action Plan

### Phase 3 (Plan) — ✅ COMPLETED Session 2 (v10.16.0)
**Priority:** ⭐⭐ MEDIUM | **Actual:** 109-line index + 7 group files (724 total) | **Smoke test:** 35/35 PASS

Original target 515 → 109 index. Group files: A-pregate-trace (93), B-isg-partition (85), C-workload-gate (119, INLINE CDG-11 preserved), D-route-write (91), E-report (70), F-finalize (72, migrated to phase-finalize.sh), POST-GATE (85). Steps 3.2 + 3.7 migrated to shared trace scripts.

---

### ~~Phase 3 (Plan)~~ — 515 lines, 7 steps, 181 bash → ~2-3h (LEGACY plan)

**Steps:**
1. **T4 extract:** ISG + Partition logic ở Step 3.3 (~80 dòng bash) → already in `plan-isg-partition.sh` ✓. Check Step 3.6 `route-and-write.sh` ✓. Workload Gate CDG-11 GIỮ INLINE (user interaction).
2. **T6 split candidate:** Borderline (515 dòng). Có thể tách thành:
   - `phase3-plan.md` (index ~80 dòng)
   - `phase3-plan/A-pregate-trace.md` (Steps 3.1-3.2, ~50 dòng)
   - `phase3-plan/B-isg-partition.md` (Step 3.3, ~80 dòng)
   - `phase3-plan/C-workload-gate.md` (Step 3.5 INLINE CDG, ~100 dòng)
   - `phase3-plan/D-route-write.md` (Step 3.6, ~80 dòng)
   - `phase3-plan/E-finalize.md` (Steps 3.10-3.11, ~60 dòng)
   - `phase3-plan/POST-GATE.md` (~50 dòng)
3. **Migrate to shared trace scripts:** `phase-trace-start.sh` + `phase-finalize.sh`
4. **Smoke test:** `phase3-routing-smoke-test.sh`

**Expected saving:** 515 → ~80 index + 6 groups × ~70 = ~80 idx + ~420 group = ~500 total. Per-group context ~500-800 tokens.

### Phase 4 (Find Bugs) — ✅ COMPLETED Session 4 (v10.18.0 — FINAL phase)
**Priority:** ⭐⭐⭐ HIGH (largest + most complex phase) | **Actual:** 142-line index + 8 group files (1104 total) | **Smoke test:** 51/51 PASS (7 categories)

Original target 782 → 142 index. Group files: A-pregate-setup (118, Steps 4.1+4.2 setup-lanes.sh + TRACE START), B-browser-cdg (130, Step 4.3 INLINE AskUserQuestion E090 Missing URL + E090b BASE_URL Conflict multi-session safety preserved), C-create-lanes (100, Step 4.4 create-lane-dirs.sh mkdir 5 subdirs/lane + lane-status.json template populate CORE-031), D-render-verify (164, Step 4.5 render template substitution Bảng Substitution + FORBIDDEN PATTERNS + Step 4.6 verify-lane-prompt.sh 6 check points C1-C6 chống fantasy prompt), E-dispatch (158, Step 4.5 **PARALLEL N×Agent({subagent_type:"claude", model:"opus"}) trong MỘT response duy nhất CORE-025 max 10 concurrent** — Playwright lanes TỰ acquire writer-lock playwright qua Protocol 22 global-rw-lock.sh KHÔNG split Wave, MANDATORY DISPATCH PROTOCOL banner preserved), F-monitor-validate (137, Step 4.7 monitor-lanes.sh poll 30s + lane timeout 15min E046 + context budget CORE-038 tier <65/65-80/80-90/>90% E009 + validate-lane-outputs.sh POST-GATE T1-T4 với E043 stub/E047 inconsistency/E048 invalid), G-report-finalize (156, Steps 4.8+4.9 generate-phase4-report.sh tạo Phase4-report.md ≤15 dòng tiếng Việt CORE-028 + phase4-summary.json schema phase4-summary-v1 CORE-036 cross-skill artifact + **finalize-phase4.sh SPECIAL CASE GIỮ aggregation logic specific** signals_total từ 3 streams × N lanes filesystem scan + lanes_completed/failed từ lane-status.json + probe_failures từ log — KHÔNG migrate sang shared phase-finalize.sh do generic chỉ hỗ trợ static PHASE_TOP_FIELDS merge, pattern giống Phase 7 finalize-phase7.sh), POST-GATE (141, T1-T4 với CORE-036 phase4-summary-v1 schema + audit_chain.signals_sha256 + audit_chain.lane_status_sha256 64-char checksum verification).

Smoke test phase4-routing-smoke-test.sh 51/51 PASS (7 categories — extra Check 7 EXTRA Phase 4-specific PARALLEL Dispatch pattern verification: MANDATORY DISPATCH PROTOCOL banner + Single-Response Parallel Dispatch requirement + max 10 concurrent limit CORE-025 + subagent_type="claude" enforcement CORE-037). Step numbering v10.6 gaps PRESERVED (4.3 merged 4.2, 4.7 merged 4.6, 4.10 merged 4.9).

---

### ~~Phase 4 (Find Bugs)~~ — 782 lines, 9 steps, 145 bash → ~3-4h (LEGACY plan)

**Steps:**
1. **T4 extract:** Steps đã largely delegated (setup-lanes.sh, monitor-lanes.sh, validate-lane-outputs.sh, finalize-phase4.sh). Check Step 4.3 Browser CDG INLINE preserved.
2. **T6 split:**
   - `phase4-find-bugs.md` (index ~100 dòng)
   - `phase4-find-bugs/A-setup-cdg.md` (Steps 4.1-4.3, includes Browser CDG INLINE, ~150 dòng)
   - `phase4-find-bugs/B-create-render.md` (Steps 4.4-4.5 lane dirs + prompt render, ~120 dòng)
   - `phase4-find-bugs/C-dispatch.md` (Step 4.5 PARALLEL agent spawn, ~100 dòng)
   - `phase4-find-bugs/D-verify-prompts.md` (Step 4.6 Pre-Dispatch Verify, ~80 dòng)
   - `phase4-find-bugs/E-monitor-validate.md` (Step 4.7, ~80 dòng)
   - `phase4-find-bugs/F-reports.md` (Step 4.8 Phase Report, ~60 dòng)
   - `phase4-find-bugs/G-finalize.md` (Step 4.9, ~50 dòng)
   - `phase4-find-bugs/POST-GATE.md` (~60 dòng)
3. **T1 verify:** Lane dispatch đã PARALLEL (max 10), check pattern khớp playbook
4. **Migrate trace scripts** + **smoke test**

**Expected saving:** 782 → ~100 idx + 8 groups × ~85 = ~780 total. Initial context -88%.

**Critical preservation:** Step 4.3 Browser CDG E090/E090b INLINE (AskUserQuestion). Step 4.5 Agent spawn INLINE (Agent tool calls).

### Phase 5 (Triage) — ✅ COMPLETED Session 3 (v10.17.0)
**Priority:** ⭐⭐⭐ HIGH | **Actual:** 135-line index + 8 group files (882 total) | **Smoke test:** 42/42 PASS

Original target 648 → 135 index. Group files: A-setup (88, includes E005 healthy jump), B-aggregate (124, Steps 5.2+5.3 aggregate + PI), C-cdg-critical (104, INLINE CDG critical violations CONTINUE/ABORT preserved), D-spawn-triage (133, INLINE Agent({subagent_type:"claude", model:"opus"}) spawn preserved per CORE-037), E-validate-handoff (137, Steps 5.6+5.7 POST-GATE T1-T4 + INLINE CDG Pre-Execute ACCEPT/REJECT/CANCEL), F-safety-check (89, INLINE CDG blocker), G-reports-finalize (122, Steps 5.9+5.10 migrate sang shared `phase-finalize.sh`), POST-GATE (97). Step 5.10 migrate sang shared `phase-finalize.sh` (finalize-phase5.sh still exists for backward-compat).

---

### ~~Phase 5 (Triage)~~ — 648 lines, 10 steps, 126 bash → ~3-4h (LEGACY plan)

**Steps:**
1. **T4 extract:** Already largely delegated (setup-triage, aggregate-and-spot-check, process-integrity-check, validate-triage-outputs, safety-check, generate-phase5-reports, finalize-phase5).
2. **T6 split:**
   - `phase5-triage.md` (index ~100 dòng)
   - `phase5-triage/A-setup.md` (Steps 5.1-5.2, ~60 dòng, includes E005 healthy jump)
   - `phase5-triage/B-aggregate.md` (Steps 5.3-5.5 aggregate + spot-check + PI, ~100 dòng)
   - `phase5-triage/C-cdg-critical.md` (Step 5.6 CDG INLINE, ~80 dòng)
   - `phase5-triage/D-spawn-triage.md` (Step 5.7 Agent spawn, ~80 dòng)
   - `phase5-triage/E-validate-handoff.md` (Steps 5.8-5.9 POST-GATE + CDG Pre-Execute, ~80 dòng)
   - `phase5-triage/F-safety-check.md` (Step 5.10, ~50 dòng)
   - `phase5-triage/G-reports-finalize.md` (Steps 5.11 + 5.14, ~70 dòng)
   - `phase5-triage/POST-GATE.md` (~50 dòng)
3. **Migrate trace scripts** + **smoke test**

**Expected saving:** 648 → ~100 idx + 8 groups × ~75 = ~700 total. Initial context -85%.

**Critical preservation:** Step 5.6 + 5.9 CDG INLINE. Step 5.7 Agent spawn INLINE.

### Phase 6 (Execute) — ✅ COMPLETED Session 2 (v10.16.0)
**Priority:** ⭐⭐ MEDIUM | **Actual:** 130-line index + 8 group files (932 total) | **Smoke test:** 40/40 PASS

Original target 619 → 130 index. Group files: A-setup (88), B-dry-run (84, branching to F nếu DRY_RUN), C-impact-cdg (142, INLINE CDG HIGH/CRITICAL preserved), D-spawn-execute (131, INLINE Agent({...}) call preserved per CORE-037), E-validate-dashboard (104), F-report (78), G-finalize (87, migrated to phase-finalize.sh), POST-GATE (88). Step 6.7 migrated to shared `phase-finalize.sh` (finalize-phase6.sh still exists for backward-compat).

---

### ~~Phase 6 (Execute)~~ — 619 lines, 7 steps, 139 bash → ~2.5-3h (LEGACY plan)

**Steps:**
1. **T4 extract:** Already delegated (setup-execute, dry-run-preview, verify-execute-outputs, generate-phase6-report, finalize-phase6).
2. **T6 split:**
   - `phase6-execute.md` (index ~90 dòng)
   - `phase6-execute/A-setup.md` (Step 6.1, ~60 dòng)
   - `phase6-execute/B-dry-run.md` (Step 6.3, ~50 dòng)
   - `phase6-execute/C-impact-cdg.md` (Step 6.4 CI-ROUTE + CDG INLINE, ~120 dòng)
   - `phase6-execute/D-spawn-execute.md` (Step 6.5 Agent spawn, ~80 dòng)
   - `phase6-execute/E-validate-reports.md` (Steps 6.7-6.8, ~100 dòng)
   - `phase6-execute/F-finalize.md` (Step 6.9, ~50 dòng)
   - `phase6-execute/POST-GATE.md` (~50 dòng)
3. **Migrate trace scripts** + **smoke test**

**Expected saving:** 619 → ~90 idx + 7 groups × ~75 = ~615 total. Initial context -85%.

### Phase 7 (Verify) — ✅ COMPLETED Session 3 (v10.17.0)
**Priority:** ⭐⭐⭐ HIGH | **Actual:** 120-line index + 8 group files (846 total) | **Smoke test:** 44/44 PASS (6 categories)

Original target 657 → 120 index. Group files: A-setup (99, E005 detect + route normal/e005_skip), B-cqg1 (88, SKIP-if-E005), C-cqg2-cdg (142, INLINE CDG REJECT QD9/QD10 với structured fix-log check v10.10.0 preserved — chống fragile grep-keyword false PASS), D-mobile-dashboard (85, Mobile WARN E045 + dashboard finalize), E-reports (122, 4 Reports + CORE-038 context budget check), F-finalize (89, GIỮ `finalize-phase7.sh` SPECIAL CASE — KHÔNG migrate sang phase-finalize.sh do pre-finalize pipeline_status=DONE ở Step 7.5 cho CORE-036 audit_chain integrity + dual-write global trace `.mc-data/work/_trace/session-log.json` CORE-026), G-todowrite-display (97, Steps 7.7+7.8 ORCH UI tools TodoWrite + Completion Display KHÔNG script được), POST-GATE (124, T1-T5 với CORE-036 fix-impact-v1 schema + audit_chain sha256 64-char + `_phase7_trace_fail` reference). Smoke test 44/44 PASS với extra Check 6 cross-skill artifact (POST-GATE references fix-impact.json + audit_chain + `_phase7_trace_fail`; E-reports references fix-impact-v1 + audit_chain).

---

### ~~Phase 7 (Verify)~~ — 657 lines, 8 steps, **267 bash (40%!)** → ~3-4h (LEGACY plan)

**Steps:**
1. **T4 extract — BIGGEST GAIN:** 267 bash lines cần audit. Already có setup-verify, cqg1-numeric, finalize-dashboard, generate-phase7-reports, finalize-phase7. Check inline blocks còn lại.
2. **T6 split:**
   - `phase7-verify.md` (index ~90 dòng)
   - `phase7-verify/A-setup.md` (Step 7.1, ~50 dòng)
   - `phase7-verify/B-cqg1.md` (Step 7.3 Numeric, ~80 dòng)
   - `phase7-verify/C-cqg2-cdg.md` (Step 7.4 INLINE CDG, ~100 dòng)
   - `phase7-verify/D-mobile-dashboard.md` (Step 7.5, ~60 dòng)
   - `phase7-verify/E-reports.md` (Step 7.6 Generate 4 Reports, ~80 dòng)
   - `phase7-verify/F-finalize.md` (Step 7.10, ~50 dòng)
   - `phase7-verify/G-todowrite-display.md` (Steps 7.7-7.8 UI tools, ~70 dòng)
   - `phase7-verify/POST-GATE.md` (~50 dòng)
3. **Migrate trace scripts** + **smoke test**

**Expected saving:** 657 → ~90 idx + 8 groups × ~70 = ~650 total. Initial context -86%. Bash extraction additional -100 lines if heavy refactor.

**Critical preservation:** Step 7.4 CQG-2 CDG INLINE (REJECT decisions). Steps 7.7-7.8 TodoWrite + Completion Display orchestrator-side.

## Session Plan Recommendation

### Session 2 (next): Phase 3 + Phase 6 (~5-6h)
- 2 smallest split candidates, lower risk
- Establish T6 pattern for Phase 2-7 (after Phase 1)
- Both don't have user-interaction complexity

### Session 3: Phase 5 + Phase 7 (~6-8h)
- High priority (most steps + most bash)
- Includes CDG INLINE preservation challenges
- Smoke tests critical here

### Session 4: Phase 4 (~3-4h)
- Most complex (parallel dispatch + agent spawns + CDG)
- Do last when pattern fully established
- Most critical preservation requirements

### Session 5 (cleanup): Final integration
- Bump SKILL.md to v10.15.0 / v10.16.0
- Update _contract.json with comprehensive changelog
- Run all smoke tests cross-phase
- Update playbook with lessons learned

## Acceptance Criteria (per phase)

After each phase migration:
- [ ] Index file ≤120 lines
- [ ] Each group file 50-160 lines
- [ ] Smoke test PASS all checks (12+ PASS)
- [ ] Compliance audit PASS (CRITICAL 100%)
- [ ] Schema sync PASS
- [ ] User-interaction code (CDG, Agent spawn, UI tools) PRESERVED INLINE
- [ ] Routing chain unbroken: A→B→...→POST-GATE→next phase
- [ ] Trace scripts migrated to shared helpers
- [ ] _shared/ references explicit per-group header

## Critical Preservation Rules (apply ALL phases)

**KHÔNG ĐƯỢC extract sang script:**
- CDG render (AskUserQuestion) — INLINE để user thấy context
- Agent({subagent_type, ...}) calls — orchestrator-side only (CORE-037)
- TodoWrite, Completion Display UI tools
- Browser MCP tool calls (mcp__plugin_playwright_*)

**LUÔN preserve khi T6 split:**
- Step numbering gaps (vd: 2.4-2.8 đã merge — KHÔNG renumber)
- Cross-refs vào _contract.json error codes
- Backward compat: phase{N}-name.md vẫn entry file (becomes index)

## Files Created/Modified Summary (Session 1)

**New files (10):**
- `procedures/_optimization-playbook.md` (canonical 10 techniques)
- `scripts/wf-fix-bugs/phase-trace-start.sh` (shared)
- `scripts/wf-fix-bugs/phase-finalize.sh` (shared)
- `plans/wf-fix-bugs-phase-rollout-v10.15/ROLLOUT-PLAN.md` (this file)

**Modified files (1):**
- `procedures/phase2-scan.md` (migrated Step 2.2 + 2.5 to shared trace scripts)

**Net change:** 2 new shared scripts saving ~20 lines/phase × 6 phases = ~120 lines total when fully rolled out.

## Files Created/Modified Summary (Session 4 — FINAL)

**New files (10):**
- `procedures/phase4-find-bugs/` directory (9 files):
  - `A-pregate-setup.md` (118), `B-browser-cdg.md` (130), `C-create-lanes.md` (100), `D-render-verify.md` (164), `E-dispatch.md` (158), `F-monitor-validate.md` (137), `G-report-finalize.md` (156), `POST-GATE.md` (141)
- `scripts/wf-fix-bugs/phase4-routing-smoke-test.sh` (251 dòng, 51 checks, 7 categories — extra Check 7 EXTRA Phase 4-specific PARALLEL Dispatch verification)

**Modified files (3):**
- `procedures/phase4-find-bugs.md` (782 → 142-line index router)
- `SKILL.md` (version 10.17.0 → 10.18.0 + description update Phase 4 lazy-load achievement)
- `_contract.json` (version 10.17.0 → 10.18.0 + description update)

**Net change Session 4:**
- Lines saved (Phase 4 monolithic → split): 782 lines → spread across 8 small files + 1 index = effectively ~1104 total lines (+41% format do explicit Input/Output contracts + group banners + Next pointers) NHƯNG lazy-loaded ~600-1400 tokens per group vs ~8K tokens/phase monolithic = -85% initial context per phase invocation.
- Smoke test: +51 new checks PASS, 0 regression cross-phase (Phase 1: 42, Phase 3: 35, Phase 5: 42, Phase 6: 40, Phase 7: 44 — all still PASS).
- Cross-phase total: **254 checks PASS** (vs 203 end-of-Session-3 = +51 Phase 4 checks, 0 regression).
- Compliance audit GRADE: PASS (CRITICAL 12/12 100%, REQUIRED 13/13 100%).
- Schema sync 0 errors.
- Pattern T6 (Phase Lazy-Load Split) **fully validated qua TOÀN BỘ 6 phase optimizable (1, 3, 4, 5, 6, 7)** — Phase 2 grandfathered (5 steps, <300 dòng — không cần T6 split).
- **ROLLOUT-PLAN v10.15 COMPLETED.** Tất cả 7 phases procedure file <12K tokens, không phase nào trigger /compact trên dự án lớn như EUREKA-2026.

## Files Created/Modified Summary (Session 3)

**New files (19):**
- `procedures/phase5-triage/` directory:
  - `A-setup.md` (88), `B-aggregate.md` (124), `C-cdg-critical.md` (104), `D-spawn-triage.md` (133), `E-validate-handoff.md` (137), `F-safety-check.md` (89), `G-reports-finalize.md` (122), `POST-GATE.md` (97)
- `procedures/phase7-verify/` directory:
  - `A-setup.md` (99), `B-cqg1.md` (88), `C-cqg2-cdg.md` (142), `D-mobile-dashboard.md` (85), `E-reports.md` (122), `F-finalize.md` (89), `G-todowrite-display.md` (97), `POST-GATE.md` (124)
- `scripts/wf-fix-bugs/phase5-routing-smoke-test.sh` (42 checks, 5 categories)
- `scripts/wf-fix-bugs/phase7-routing-smoke-test.sh` (44 checks, 6 categories — extra cross-skill artifact check)

**Modified files (4):**
- `procedures/phase5-triage.md` (648 → 135-line index router)
- `procedures/phase7-verify.md` (657 → 120-line index router)
- `SKILL.md` (version 10.16.0 → 10.17.0 + description update + audit 4.1 fix restore `## Phase N` heading prefixes)
- `_contract.json` (version 10.17.0 + description update)

**Net change Session 3:**
- Lines saved (Phase 5 + 7 monolithic → split): 648 + 657 = 1305 lines → spread across 16 small files + 2 indexes = effectively SAME total lines but lazy-loaded ~500-1400 tokens per group vs ~6-7K tokens/phase monolithic = -85% initial context per phase invocation.
- Smoke tests: +86 new checks (42 Phase 5 + 44 Phase 7) PASS, 0 regression cross-phase (Phase 1: 42, Phase 3: 35, Phase 6: 40 — all still PASS).
- Compliance audit GRADE: PASS (CRITICAL 12/12 100%, REQUIRED 13/13 100%).
- Schema sync 0 errors.
- Pattern T6 (Phase Lazy-Load Split) fully validated qua 5 phases. Phase 4 chờ Session 4 (final phase, ~3-4h, complex parallel dispatch).
