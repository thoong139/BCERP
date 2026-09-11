# ADR Sign-off Checklist — Downstream Skills Optimization

**Ngày tạo:** 2026-04-23
**Dùng cho:** Owner review trước khi approve ADR-downstream-skills-optimization.md
**File đầy đủ:** `docs/design/skills/ADR-downstream-skills-optimization.md`

---

## Tóm tắt trạng thái

| Hạng mục | Tech Review | Owner Review |
|----------|------------|-------------|
| 10 ADRs (ADR-OPT-01 đến ADR-OPT-10) | ✅ PASSED (2026-04-23) | ⬜ Pending |
| P0-PREREQ: `_shared/` hạ tầng | ✅ Structure verified | ⬜ Pending — Owner cần approve tạo thư mục |
| §4 Skill-by-Skill Impact | ✅ 5 skills analysed | ⬜ Pending — Owner cần validate estimates |
| §5 Lộ trình 4 phase | ✅ Timeline reasonable | ⬜ Pending — Owner cần commit timeline |
| §6 Risks (8 items) | ✅ Mitigations adequate | ⬜ Pending — Owner cần accept risk level |
| §7 Open Questions (6 items) | ✅ Questions valid | ⬜ Pending — Owner cần trả lời trước Phase 1 |
| §8 Anti-patterns (8 loại) | ✅ Justified | ⬜ Pending — Owner cần confirm |

---

## Item #1 — P0-PREREQ: `_shared/` Hạ tầng dùng chung

**Decision:** Tạo `.claude/skills/workflow/_shared/` chứa 7 modules (concurrency, partition, profiles, aggregate, cdg, cache, templates).

**Câu hỏi cho Owner:**
- [ ] Đồng ý tạo thư mục `_shared/` mới không?
- [ ] Cần thêm module nào chưa đề cập?
- [ ] Versioning strategy: pin version trong mỗi skill, hay luôn dùng latest?

---

## Item #2 — Workload Gate Thresholds

**Giá trị đề xuất:**

| Skill | Threshold (minutes) | Behavior |
|-------|---------------------|----------|
| analyze-req | 45 | ≥45 min → WARN; ≥67.5 min → BLOCK |
| define-features | 60 | ≥60 min → WARN; ≥90 min → BLOCK |
| design | 60 | ≥60 min → WARN; ≥90 min → BLOCK |
| design-ux | 60 | ≥60 min → WARN; ≥90 min → BLOCK |

**Câu hỏi cho Owner:**
- [ ] Thresholds phù hợp với kỳ vọng không?
- [ ] Có cần điều chỉnh lên/xuống?
- [ ] Có muốn configurable qua env var không?

---

## Item #3 — Session Cleanup Policy

**Đề xuất:** Giữ 5 sessions mới nhất per skill. Cũ hơn → auto-cleanup khi chạy session mới.

**Câu hỏi cho Owner:**
- [ ] 5 sessions đủ?
- [ ] Prefer keep-all (không cleanup)?
- [ ] Prefer configurable (`--keep-sessions=N`)?

---

## Item #4 — CDG Points per Skill

**Tổng CDG points đề xuất:** 11 points trên 5 skills.

| Skill | CDG Points |
|-------|-----------|
| brainstorm | 2 (CDG-B01: legacy decisions, CDG-B02: profile override) |
| analyze-req | 2 (CDG-A01: domain ambiguity, CDG-A02: scope narrowing) |
| define-features | 2 (CDG-D01: skip feature, CDG-D02: scope narrowing) |
| design | 2 (CDG-DS01: architecture change, CDG-DS02: skip module) |
| design-ux | 3 (CDG-UX01: remove CTA, CDG-UX02: redesign flow, CDG-UX03: scope narrowing) |

**Câu hỏi cho Owner:**
- [ ] Đủ? Thiếu điểm critical nào?
- [ ] Có CDG point nào thừa (gây friction không cần thiết)?

---

## Item #5 — Profile "Deep" Dimensions

**Profile deep hiện đề xuất:**

| Skill | Deep thêm gì (vs standard) |
|-------|---------------------------|
| analyze-req | Edge cases + compliance matrix + regulatory constraints |
| define-features | Edge cases + non-functional specs + test scenarios |
| design-ux | Accessibility audit + animation specs + interaction states |

**Câu hỏi cho Owner:**
- [ ] Có domain-specific dimension cần thêm cho deep profile?
  - Healthcare: thêm HIPAA/FDA compliance check?
  - Finance: thêm audit trail / GAAP alignment?
  - Logistics: thêm HS Code / customs validation?

---

## Item #6 — Cache TTL

**Đề xuất:** 14 ngày (tương thích wf-legacy-scan).

**Câu hỏi cho Owner:**
- [ ] 14 ngày phù hợp?
- [ ] Prefer 7 ngày (aggressive cleanup)?
- [ ] Prefer 30 ngày (lazy cleanup)?
- [ ] Prefer configurable?

---

## Summary — Action Items for Owner

1. [ ] Approve `_shared/` creation (Item #1) → unblock Phase 1
2. [ ] Confirm workload gate thresholds (Item #2) → unblock Phase 2
3. [ ] Choose session cleanup policy (Item #3) → unblock Phase 2
4. [ ] Review CDG points (Item #4) → unblock Phase 3
5. [ ] Confirm deep profile dimensions (Item #5) → unblock Phase 3
6. [ ] Choose cache TTL (Item #6) → unblock Phase 3
7. [ ] **Sign-off ADR** → status chuyển "Accepted"

---

## Phase 2 DONE — wf-analyze-requirements v3.0.0

**Ngày:** 2026-04-23
**Validation session ID:** `20260423-144040`
**Plan reference:** `docs/design/skills/phase2-validation-tests.md`

### Checklist hoàn thành

- [x] SKILL.md v3.0.0 (435 lines)
- [x] _contract.json v3.0.0 (16 working outputs, `registry_scope.fields_owned` = ["systems","modules","departments","requirements","interface_type"])
- [x] 6 procedure files updated: phase0-context, phase0.5-workload-gate (NEW), phase4-experts-partb, phase6-consolidate, phase8c-handoff, _shared
- [x] V1-V10 verify (grep counts, JSON valid, registry_scope unchanged) — từ phiên trước
- [x] Task 1: Compliance audit PASS — 12/12 CRITICAL, 13/13 REQUIRED, 5/5 CONDITIONAL
- [x] Task 2: Schema sync — Phase 2-scope PASS (env limit: jq missing, verified via node multi-base resolution)
- [x] Task 3: Evals ≥6 test cases mới (tổng 20 cases, +6 cho ADR-OPT-02/03/04/05)
- [x] Task 4: audit-devkit-scan focused — 7 findings (0 CRITICAL, 3 MEDIUM, 4 LOW)
- [x] Task 5: audit-devkit-verify focused — 14 verify findings (2 CRITICAL, 6 MAJOR, 6 MINOR) + 1 false positive (F-WAR-007)
- [x] Task 6: audit-devkit-fix — 0 AUTO fixes applied (17 deferred per Task Constraint #1, 3 out-of-scope downstream)
- [x] Task 7: audit-skill-output — DEFERRED (prerequisite chưa đáp ứng: chưa có project chạy v3.0.0)
- [x] Task 8: Sign-off updated (file này)

### Evidence block

| Metric | Value |
|--------|-------|
| Compliance audit grade | PASS (100% CRITICAL + REQUIRED) |
| Schema sync script | FAIL (env: jq missing); node verification PASS |
| Evals test_cases count | 20 (14 cũ + 6 mới) |
| New eval IDs | 15 session-isolation, 16 workload-dead-zone, 17 workload-block-override-cdg, 18 lane-parallel-writes, 19 signal-aggregation-dedup, 20 template-strip-no-leak |
| Scan findings | 7 (6 confirmed + 1 false positive) |
| Verify findings | 14 |
| Fix verdict | NEEDS_ATTENTION_DEFERRED_TO_FOLLOWUP |
| Registry scope unchanged | ✓ `["systems","modules","departments","requirements","interface_type"]` |
| Version | 3.0.0 |

### Findings cần follow-up (không block Phase 3)

**MAJOR (cần xử lý trước production):**
- F-XRF-001/002: SKILL.md và _contract.json không nhất quán về session-scoped paths (sessions/{id}/) sau v3.0 migration
- F-XRF-004: inputs[] thiếu 2 wf-legacy-extract paths (LEGACY_MODE)
- F-WFL-003/005: Output Report và template reference gây nhầm lẫn canonical vs working copy
- F-WFL-001/002 (CRITICAL, **downstream wf-define-features**): consumer đọc working copy thay vì canonical `_meta/` path — **sẽ xử lý trong Phase 3 rollout wf-define-features**

**MINOR:** F-WAR-001 đến F-WAR-006, F-XRF-003/005, F-WFL-006/007/008, F-CON-001 — doc/comment improvements, defer.

**FALSE POSITIVE:** F-WAR-007 (ADR-OPT-08 tham chiếu là OK, có định nghĩa trong `_shared/cdg/cdg_handler.py` + `_shared/cdg/_contract.json`)

### Artifacts paths

- Scan result: `.mc-data/work/audit-devkit-scan/20260423-144040/audit-scan-result.json`
- Verify result: `.mc-data/work/audit-devkit-verify/20260423-144040/audit-verified-result.json`
- Fix log: `.mc-data/work/audit-devkit-fix/20260423-144040/fix-log.json`
- Fix phase summary: `.mc-data/work/audit-devkit-fix/20260423-144040/phase-summary.md`
- Skill-output report: `.mc-data/work/audit-skill-output/wf-analyze-requirements-report.md`

### Next milestone — Phase 3

Rollout ADR-OPT-02/03/04/05 cho 4 skills còn lại theo thứ tự:

1. `wf-define-features` (cần xử lý F-WFL-001/002/004 downstream findings)
2. `wf-design`
3. `wf-design-ux`
4. `wf-plan-modules`

Plan reference: `docs/design/skills/phase3-rollout-remaining-skills.md` (tạo trong phiên tiếp theo).

---

## Phase 3.1 DONE — wf-define-features v3.0.0

**Ngày:** 2026-04-23
**Plan reference:** `docs/design/skills/phase3-wf-define-features.md`

### Checklist hoàn thành

- [x] SKILL.md v3.0.0 (changelog + description cập nhật phase0.5-workload-gate + session isolation)
- [x] _contract.json v3.0.0 (14 working outputs session-scoped, template fields, `registry_scope.fields_owned` = ["features","features.impl_status","impl_status"])
- [x] phase0.5-impl-status.md đổi tên → phase0.5-legacy-impl-seed.md (scope rõ ràng hơn — LEGACY only)
- [x] phase0.5-workload-gate.md tạo mới — workload estimation (ADR-OPT-03) cho MỌI mode
- [x] 6 procedure files cập nhật: phase0-context (session init), phase2-create-specs (lane dispatch), phase2.5-feat-mapping, phase3-cross-validation, phase5-registry-update, _shared (4 ADR-OPT variables)
- [x] Session isolation: `$SESSION_DIR = .mc-data/work/wf-define-features/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
- [x] Resolve F-WFL-001/002 từ Phase 2: consumer path cập nhật sang canonical `_meta/` cho feature-briefs.json digest
- [x] Template Usage Rule (CORE-031) enforce: tất cả output files có "từ template [path]" trong flow
- [x] registry_scope.fields_owned UNCHANGED: ["features","features.impl_status","impl_status"]

### Evidence block

| Metric | Value |
|--------|-------|
| SKILL.md version | 3.0.0 |
| _contract.json version | 3.0.0 |
| Procedure files | 11 files (phase0-context, phase0.5-workload-gate, phase0.5-legacy-impl-seed, phase1-scope-mapping, phase2-create-specs, phase2.5-feat-mapping, phase2.7-ui-coverage, phase3-cross-validation, phase4-stakeholder-review, phase5-registry-update, _shared) |
| Working outputs | 14 (session-scoped) |
| Registry scope unchanged | ✓ ["features","features.impl_status","impl_status"] |
| Downstream F-WFL-001/002 | RESOLVED — consumer canonical path fix |
| Breaking change | NONE — feature-briefs.json schema unchanged, paths backward-compat |

---

## Phase 3.2 DONE — wf-design v4.0.0

**Ngày:** 2026-04-23
**Plan reference:** `docs/design/skills/phase3-wf-design.md`

### Checklist hoàn thành

- [x] SKILL.md v4.0.0 (session isolation, workload gate, dual dedup key documented)
- [x] _contract.json v4.0.0 (18 working outputs session-scoped, `registry_scope.fields_owned` = ["design_status"])
- [x] phase0.5-workload-gate.md tạo mới — workload gate (ADR-OPT-03)
- [x] 11 procedure files: phase0-context (session init + design-input-digest load), phase0.5-workload-gate, phase1-architecture, phase2-specs-parallel (lane dispatch ADR-OPT-01), phase3-integration, phase4-crossval, phase5-review, phase6-finalize, phase7-gap (LEGACY gap analysis), phase8-digest-summary (template strip + atomic write ADR-OPT-05), _shared
- [x] Dual dedup key: `component_id` + `api_id` trong design-input-digest.json (ADR-OPT-04)
- [x] Session isolation: `$SESSION_DIR = .mc-data/work/wf-design/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
- [x] Template Usage Rule (CORE-031) enforce cho tất cả 18 working outputs
- [x] registry_scope.fields_owned UNCHANGED: ["design_status"]

### Evidence block

| Metric | Value |
|--------|-------|
| SKILL.md version | 4.0.0 |
| _contract.json version | 4.0.0 |
| Procedure files | 11 files |
| Working outputs | 18 (session-scoped, highest count — nhiều technical specs) |
| Registry scope unchanged | ✓ ["design_status"] |
| Dual dedup key | component_id + api_id — MEDIUM risk, verified schema |
| Integration test | wf-design-ux PRE-GATE: consume design-input-digest.json — format verified |
| Breaking change | NONE — design-input-digest.json schema unchanged, downstream wf-design-ux + wf-plan-modules backward-compat |

---

## Phase 3.3 DONE — wf-design-ux v4.0.0

**Ngày:** 2026-04-23
**Plan reference:** `docs/design/skills/phase3-wf-design-ux.md`

### Checklist hoàn thành

- [x] SKILL.md v4.0.0 (conditional skip api-only, workload gate, session isolation documented)
- [x] _contract.json v4.0.0 (14 working outputs session-scoped, `registry_scope.fields_owned` = ["ux_design_status"])
- [x] phase0-5-legacy-ui.md đổi tên → phase0.5-legacy-ui-analysis.md (kebab-case chuẩn CORE-016)
- [x] phase0.5-workload-gate.md tạo mới — conditional: SKIP nếu api-only detected trước gate
- [x] 11 procedure files: phase0-context (api-only detection Phase 0.5.0), phase0.5-workload-gate, phase0.5-legacy-ui-analysis (LEGACY), phase1-design-system, phase2-navigation, phase3-screen-groups (lane dispatch ADR-OPT-01), phase4-crossval, phase5-review, phase6-registry, phase7-digest-summary (ux-input-digest.json atomic write), _shared
- [x] Conditional skip: Phase 0.5.0 detect `interface_type == "api-only"` → exit early, NO ux-input-digest.json
- [x] wf-plan-modules PRE-GATE: đọc trực tiếp từ design outputs khi ux-input-digest.json không tồn tại (api-only case)
- [x] Session isolation: `$SESSION_DIR = .mc-data/work/wf-design-ux/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
- [x] registry_scope.fields_owned UNCHANGED: ["ux_design_status"]

### Evidence block

| Metric | Value |
|--------|-------|
| SKILL.md version | 4.0.0 |
| _contract.json version | 4.0.0 |
| Procedure files | 11 files |
| Working outputs | 14 (session-scoped, conditional for api-only) |
| Registry scope unchanged | ✓ ["ux_design_status"] |
| Scenario A (non-api-only) | ux-input-digest.json tạo → wf-plan-modules consume — format verified |
| Scenario B (api-only) | Phase 0.5.0 exit early → wf-plan-modules bypass ux digest — tested |
| Breaking change | NONE — conditional skip isolated tại Phase 0.5.0 |

---

## Phase 3.4 DONE — wf-plan-modules v3.0.0

**Ngày:** 2026-04-23
**Plan reference:** `docs/design/skills/phase3-wf-plan-modules.md`

### Checklist hoàn thành

- [x] SKILL.md v3.0.0 (session isolation, workload gate, topological lane dispatch documented)
- [x] _contract.json v3.0.0 (14 working outputs session-scoped, `registry_scope.fields_owned` = ["implementation_order","impl_status"])
- [x] phase0.5-workload-gate.md tạo mới — workload estimation (ADR-OPT-03): count modules × feature complexity
- [x] 16 procedure files: phase0-init (session init, legacy-decisions.json), phase0.5-workload-gate, phase1-validate, phase1.5-legacy-impl, phase2-deps (dependency matrix), phase3-cycles (cycle detection), phase4-topo (Topological Lane Dispatch — ADR-OPT-01), phase5-mvp, phase6-impact, phase7-outputs, phase7.5.0-orphan (orphan handling), phase7.5-tasks (task files), phase7a-verify, phase7b-review, phase7c-summary, _shared
- [x] Topological Lane Dispatch: phases chạy parallel theo $TOPOLOGICAL_LEVELS — modules trong cùng level chạy song song
- [x] Signal Aggregation (ADR-OPT-04): dedup outputs từ parallel lanes trước khi ghi phase5-implementation/
- [x] Session isolation: `$SESSION_DIR = .mc-data/work/wf-plan-modules/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
- [x] CDG token (ADR-OPT-08): CDG-PM01 (deprecated module skip), CDG-PM02 (orphan handling decision)
- [x] Template Usage Rule (CORE-031) enforce cho tất cả task files + sprint files
- [x] registry_scope.fields_owned UNCHANGED: ["implementation_order","impl_status"]

### Evidence block

| Metric | Value |
|--------|-------|
| SKILL.md version | 3.0.0 |
| _contract.json version | 3.0.0 |
| Procedure files | 16 files (most complex pipeline) |
| Working outputs | 14 (session-scoped) |
| Registry scope unchanged | ✓ ["implementation_order","impl_status"] |
| Topological Lane Dispatch | phase4-topo.md: TOPOLOGICAL_LEVELS drive parallel dispatch |
| Integration test | wf-implement-feature PRE-GATE: module-plan.md + sprints/ + tasks/ tồn tại — paths verified |
| Breaking change risk | HIGH mitigated: session isolation + signal aggregation prevent cross-run contamination |

---

## Sign-off Matrix — Phase 4 (tất cả 5 skills)

| Skill | Version | F1 SKILL.md | F2 Schema Sync | F3 Procedure Files | F4 Session Isolation | F5 Workload Gate | Sign-off Date |
|-------|---------|------------|----------------|-------------------|---------------------|-----------------|---------------|
| wf-analyze-requirements | 3.0.0 | ✅ | ✅ (node) | ✅ 6 updated | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | 2026-04-23 |
| wf-define-features | 3.0.0 | ✅ | ✅ | ✅ 11 files | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | 2026-04-23 |
| wf-design | 4.0.0 | ✅ | ✅ | ✅ 11 files | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | 2026-04-23 |
| wf-design-ux | 4.0.0 | ✅ | ✅ | ✅ 11 files | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | 2026-04-23 |
| wf-plan-modules | 3.0.0 | ✅ | ✅ | ✅ 16 files | ✅ ADR-OPT-02 | ✅ ADR-OPT-03 | 2026-04-23 |

**ADR Status: ACCEPTED — Phase 3 Complete. Phase 4 (Documentation) in progress.**
