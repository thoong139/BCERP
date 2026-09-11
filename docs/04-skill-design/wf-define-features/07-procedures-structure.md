# 07 — Procedures Structure

> **Mục đích file:** Outline 11 procedure files (lazy-load).

---

## 1. Layout

```
.claude/skills/workflow/wf-define-features/procedures/
├── _shared.md                          ← Cross-cutting (NOT loaded standalone)
├── phase0-context.md                   ← Entry: LEGACY detect, session init, --resume/--status
├── phase0.5-workload-gate.md           ← Workload Gate (ADR-OPT-03)
├── phase0.5-legacy-impl-seed.md        ← LEGACY only — seed impl_status từ extracted data
├── phase1-scope-mapping.md             ← Scope decision + feature briefs + FEAT-ID assignment
├── phase2-create-specs.md              ← Lane Dispatch parallel per module
├── phase2.5-feat-mapping.md            ← LEGACY only — feat-mapping.json
├── phase2.7-ui-coverage.md             ← LEGACY + UI manifest only — UI Coverage Cross-Check
├── phase3-cross-validation.md          ← 7 checks + W4.7 + CF6 non-blocking
├── phase4-stakeholder-review.md        ← Stakeholder review B/C/D
└── phase5-registry-update.md           ← Referential Integrity Check (v3.1) + Safe-Write append-only
```

---

## 2. `_shared.md` content

| Section | Mục đích |
|---------|---------|
| **§State Variables** | `$LEGACY_MODE`, `$HAS_SCREENS`, `$SCOPE`, `$AUTO_STUB_REQUIREMENTS`, `$FROM_SCAN_SESSION_ID`, `$SESSION_DIR`, `$CI_CONTEXT` |
| **§Phase Ordering by Mode** | NEW: `0→0.5W→1→2→3→4→5`. LEGACY: `0→0.5W→0.5L→1→2→2.5→[2.7 if UI]→3→4→5` |
| **§Agent Context Templates** | BA Phase 2 (creation), BA Phase 4 (review), product-expert Phase 4 |
| **§LEGACY Context Injection** | `project-context.md` + `legacy-decisions.json` → BA/expert prompts |
| **§Fix Rules** | `missing_feature_file`, `duplicate_feat_id`, `coverage_gap`, `stakeholder_review_gap` |
| **§Registry Safe-Write** | features[] append-only + v3.1 exception requirements[] auto-stub |
| **§Error Codes Reference** | Full table E001-E020 với điểm nhấn E020 |

---

## 3. Phase procedure template (4 sections)

Mỗi `phaseN-*.md`:
- Section A: Header
- Section B: PRE-GATE (T1→T4)
- Section C: Steps
- Section D: POST-GATE (T1→T4)
- Section E: Phase Report (CORE-028)

---

## 4. Per-phase responsibility

| File | Key responsibility |
|------|-------------------|
| `phase0-context.md` | LEGACY detect (CORE-021), session init (ADR-OPT-02), `--resume`/`--status`, parse `--auto-stub-requirements`, `--from-scan` |
| `phase0.5-workload-gate.md` | 3-zone gate, CDG override (ADR-OPT-08) |
| `phase0.5-legacy-impl-seed.md` | LEGACY only — đọc extracted data, seed `impl_status` cho features đã có code |
| `phase1-scope-mapping.md` | Build `define-features-plan.md`, assign FEAT-IDs, sinh working `feature-briefs.json` |
| `phase2-create-specs.md` | **Lane Dispatch per module**: spawn BA hoặc product-expert per module, max 3 concurrent. Stub detection (v1.8+): detect `status: stub` frontmatter từ deep scan, flesh-out content |
| `phase2.5-feat-mapping.md` | LEGACY — build `feat-mapping.json` (FEAT-ID → {title, module, system, doc_path}) |
| `phase2.7-ui-coverage.md` | LEGACY + UI — cross-check screens vs features, classify COVERED/INFRASTRUCTURE/GAP/AMBIGUOUS, tạo stub cho GAP, sinh `ui-coverage-gaps.json` |
| `phase3-cross-validation.md` | 7 standard checks + **W4.7 Cross-Module Detection (non-blocking)** + **CF6 Cross-FEAT Ref Detection (non-blocking)**. Auto-fix loop max 3 iter |
| `phase4-stakeholder-review.md` | Stakeholder review Phần B (cross-spec) + C (consistency) + D (gap analysis). Iterations max 3 |
| `phase5-registry-update.md` | **Phase 5.3c Referential Integrity Check (v3.1)** — compute orphan REQ-IDs → BLOCK E020 OR `--auto-stub-requirements`. Safe-Write features[] append-only + cross_feat_refs[] (CF6 accepted) |

---

## 5. SKILL.md routing (lazy-load contract)

`SKILL.md` (~430 dòng) chứa Phase Mapping:

```markdown
| SKILL.md Phase | procedures/ file |
|---------------|------------------|
| Phase 0 | phase0-context.md |
| Phase 0.5 Workload | phase0.5-workload-gate.md |
| Phase 0.5 Legacy Impl Seed | phase0.5-legacy-impl-seed.md (LEGACY) |
| Phase 1 | phase1-scope-mapping.md + phase2-create-specs.md + phase2.5-feat-mapping.md (LEGACY) + phase2.7-ui-coverage.md (LEGACY+UI) |
| Phase 2 | phase3-cross-validation.md + phase4-stakeholder-review.md + phase5-registry-update.md |
| Phase 3 (Digest) | (Phiên 6 — thực thi tại cuối Phase 5) |
```

---

## 6. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md) — Phase 2 Lane per module
- Rules: CORE-032, CORE-035, CORE-037, CORE-038
- Source: [`.claude/skills/workflow/wf-define-features/SKILL.md`](../../../.claude/skills/workflow/wf-define-features/SKILL.md)
