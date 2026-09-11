# Sprint 4 Report — Stage 2: Roadmap Consolidation

> **Plan:** wf-fix-bugs-dimensions-audit-v1
> **Stage:** 2 — Roadmap Consolidation
> **Sprint:** 4 (gán cho Stage 2 per plan naming convention — Sprint 1-3 dành cho Stage 1)
> **Sessions:** Phiên 41–44 (2026-05-09)
> **Status:** ✅ COMPLETE — G2 criteria fully met

---

## Mục tiêu Stage 2

Chuyển từ 7 bản audit rời (Stage 1) sang một roadmap được khóa, cross-validated, sẵn sàng cho Stage 3 implementation.

**Definition of Done (G2):**
1. Tất cả IMP có `evidence_status` ∈ {verified, dropped} — 0 tentative còn lại
2. Mỗi IMP verified có acceptance_test fixture path
3. IMP-002 cross-skill impact analysis với wf-brainstorm completed
4. Tất cả 7 `evals.json` sync xong, ≥3 TC-audit-* cases mỗi dim

---

## Tasks Completed

### Task 1 — Cross-Cutting Findings Rebuild (Phiên 41)

**Outcome:** `09-cross-cutting-findings.md` rebuilt từ đầu với 10 themes, tất cả VERIFIED.

| Theme | Dims | Status |
|-------|------|--------|
| Theme 1: Tech Stack Detection Bias (Node-centric) | QD1/QD2/QD3/QD4/QD6 (5 dims) | ✅ VERIFIED |
| Theme 2: Hardcoded Thresholds | QD1/QD4/QD5/QD7 (4 dims) | ✅ VERIFIED |
| Theme 3: i18n/l10n Issues | QD1/QD5/QD7 (3 dims) | ✅ VERIFIED |
| Theme 4: Schema Validation Strictness | QD1/QD2/QD6 (3 dims) | ✅ VERIFIED |
| Theme 5: Cross-Probe Interaction Issues | All 7 dims | ✅ VERIFIED |
| Theme 6: Agent Probe Cost & Quality | QD1/QD2/QD3/QD5 (4 dims) | ✅ VERIFIED |
| Theme 7: SPEC-ONLY Probe Coverage Gap | All 7 dims | ✅ VERIFIED |
| Theme 8: Signal Schema Fork (dual signal-v2) | QD1/QD2/QD3/QD6 (4 dims) | ✅ VERIFIED [NEW] |
| Theme 9: CDG Governance Gap | QD3/QD4/QD5/QD7 (4 dims) | ✅ VERIFIED [NEW] |
| Theme 10: Bash Probe Dispatch Missing | QD2/QD4/QD6 (3 dims) | ✅ VERIFIED [NEW] |

**Key metrics:**
- 76 total findings across 10 themes
- 3 new themes (8, 9, 10) discovered via cross-dim analysis
- Merge summary table with 7 MERGE clusters documented

---

### Task 2 — Roadmap Lock (Phiên 42)

**Outcome:** `10-improvement-roadmap.md` STATUS = 🔒 LOCKED.

**IMP promotion summary:**

| Batch | Action | Count |
|-------|--------|-------|
| 10 tentative IMPs | Promoted → verified (with Stage 1 evidence) | 10 |
| 6 new global IMPs added | IMP-021..026 from cross-dim MERGE analysis | 6 |
| Dropped | 0 | 0 |

**Final inventory:**
- 27 total verified IMPs (IMP-000 infra + IMP-001..IMP-026 global)
- 0 tentative remaining
- All have acceptance_test fixture paths

**New IMPs from Stage 2 MERGE analysis:**
- IMP-021: Dimension execution order fix (7-dim MERGE — CASCADE-QD2-001 root)
- IMP-022: Signal schema fork consolidation (4-dim)
- IMP-023: Cross-probe dedup logic (3-dim)
- IMP-024: CDG governance uniform enforcement (4-dim)
- IMP-025: Bash probe dispatch scaffold (3-dim)
- IMP-026: EXCLUDE_PATTERN configurable (3-dim)

---

### Task 3 — IMP-002 Cross-Skill Impact Analysis (Phiên 43)

**Outcome:** `reports/imp-002-cross-skill-impact.md` + DEC-008 in decisions log.

**Findings:**
- IMP-002 adds `project.locale` field to registry schema → wf-brainstorm is PRIMARY owner
- wf-fix-functional (QD1) is CONSUMER — must survive gracefully if field absent
- Impact: LOW (backward-compatible addition) — no blocking dependency
- Action: Coordinate addition with wf-brainstorm author; QD1 uses `getattr(registry, "project.locale", None)` pattern

---

### Task 4 — Sync Findings → evals.json (Phiên 44)

**Outcome:** 21 new `TC-audit-*` test cases added (3 per dim × 7 dims). `scripts/sync-audit-to-evals.sh` exits 0.

| Dim | TC-audit cases added | Key coverage |
|-----|---------------------|--------------|
| QD1 | 3 | D1 orphan-FEAT-ID / VI-CTA bias / .NET routing |
| QD2 | 3 | comment-as-pattern FP / CDG governance / CASCADE-QD2-001 |
| QD3 | 3 | OWASP 40% coverage / CDG double-fire / cache-NEVER |
| QD4 | 3 | CDG routing broken / --probe cosmetic / api-latency SPEC_GAP |
| QD5 | 3 | VI-CTA bias / EXCLUDE_PATTERN hardcoded / fingerprint 6-token |
| QD6 | 3 | CDG empty DROP TABLE / all-inline / EF Core C# |
| QD7 | 3 | D15 heredoc PWEOF / CDG broken bash / cascade signal |

---

## G2 Gate Checklist

| Criterion | Status | Evidence |
|-----------|--------|---------|
| Tất cả IMP `evidence_status` ∈ {verified, dropped} | ✅ PASS | 0 tentative, 27 verified |
| Mỗi IMP verified có acceptance_test path | ✅ PASS | 27/27 paths set |
| IMP-002 cross-skill impact analysis | ✅ PASS | DEC-008 + reports/imp-002-cross-skill-impact.md |
| 7 evals.json sync xong (≥3 TC-audit-* mỗi dim) | ✅ PASS | sync-audit-to-evals.sh exit 0, 21 cases |
| 09-cross-cutting-findings.md ≥7 themes | ✅ PASS | 10 themes ALL VERIFIED |
| 12-decisions-log.md ≥4 decisions | ✅ PASS | DEC-001..DEC-008 (8 decisions) |
| 10-improvement-roadmap.md LOCKED header | ✅ PASS | Status: 🔒 LOCKED (G2 — Phiên 42) |

**Result: G2 GATE PASS ✅ — Stage 3 UNLOCKED**

---

## Stage 2 Metrics

| Metric | Value |
|--------|-------|
| Sessions | Phiên 41–44 (4 sessions) |
| Duration | 1 ngày (2026-05-09) |
| New IMPs discovered | 6 (IMP-021..026 from cross-dim MERGE) |
| IMPs promoted tentative → verified | 10 |
| Themes cross-cutting | 10 (3 new) |
| Evals added | 21 |
| Decisions logged | 2 new (DEC-007, DEC-008) |

---

## Stage 3 Readiness

Stage 3 Implementation Sprints is now UNLOCKED. Recommended execution order:

**Sprint 1 (P0 — week 1-2):** IMP-001, IMP-002, IMP-003
**Sprint 2 (P1 — week 3-4):** IMP-004, IMP-005, IMP-006, IMP-007
**Sprint 3 (P1-P2 — week 5-6):** IMP-008, IMP-009, IMP-015
**Sprint 4 (P2 — week 7-8):** IMP-010, IMP-011, IMP-012, IMP-013, IMP-014, IMP-016
**Sprint 5 (P3 — week 9):** IMP-017, IMP-018, IMP-019, IMP-020

Cross-dim IMPs (IMP-021..026) should be implemented as part of their primary dim sprint where possible.

---

*Generated: 2026-05-09 | Phiên 45 | Plan: wf-fix-bugs-dimensions-audit-v1*
