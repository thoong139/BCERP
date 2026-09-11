# Progress — skill-design-expansion-v1

**Cập nhật lần cuối:** 2026-05-15 (Phiên #1 — Tier 1 COMPLETE 5/5)
**Trạng thái tổng:** ✅ Tier 1 5/5 skills (100%)

---

## Tier 1 — Critical ✅ COMPLETE

| # | Skill | Version | Status | Phiên |
|---|-------|---------|--------|-------|
| 1 | wf-implement-feature | v5.2.0 | ✅ Full 10 files | #1 |
| 2 | wf-e2e-verify | v8.0.0 | ✅ Full 10 files | #1 |
| 3 | wf-analyze-requirements | v3.0.0 | ✅ Full 10 files | #1 |
| 4 | wf-design | v4.0.0 | ✅ Full 10 files | #1 |
| 5 | wf-define-features | v3.2.0 | ✅ Full 10 files | #1 |

### Per-skill checklist (cả 5 tick toàn bộ)

Mỗi skill có 10 file: README + 01-vision + 02-arguments + 03-phase-routing + 04-file-contract + 05-error-codes + 06-templates-list + 07-procedures-structure + 08-tradeoffs-adr + 09-evals-test-cases.

Inventory `docs/04-skill-design/README.md` §3 updated với 5 row mới.

Cross-link `docs/05-review-standards/{skill}.md` §Reference updated cho 5 skills (skill-design canon link).

---

## Tier 2 — High (defer cho phiên sau)
- [ ] wf-plan-modules (v1.7)
- [ ] wf-brainstorm (v8.1)
- [ ] wf-preflight (v3.x)
- [ ] wf-manage-change (v3.0)
- [ ] wf-fix-execute (spawned executor)

---

## Tier 3 — Medium (defer dài hạn)
- [ ] 11 lane skills (wf-fix-functional, wf-fix-business, wf-fix-security, wf-fix-performance, wf-fix-ux-a11y, wf-fix-data, wf-fix-compat, wf-fix-observability, wf-fix-runtime-health, wf-fix-integration, wf-fix-business-completeness)
- [ ] 5 helper skills (wf-prepare-deployment, wf-design-ux, wf-add-scope, wf-verify-sync, wf-annotate-code)

---

## Lịch sử phiên

### Phiên #1 — 2026-05-15 (Tier 1 COMPLETE in single session, autonomous)

**Người thực hiện:** Claude (Opus 4.7 1M context) — user delegate "tự quyết theo defaults docs-restructure-v1"

**Defaults đã chốt:**
- Tier 1 (5 skill critical)
- Skill order: wf-implement-feature → wf-e2e-verify → wf-analyze-requirements → wf-design → wf-define-features
- Style: teaching cho 01-vision/08-tradeoffs, formal cho 03-routing/04-contracts
- Tiếng Việt user-facing, English identifiers
- KHÔNG sửa `.claude/**`, bám source thực tế
- Skill-batch review cadence (mỗi skill xong → tick + cross-link, không file-by-file)
- Metadata stripping: XÓA toàn bộ `_template_notes:` blocks (HTML comment) trước commit

**Đã làm:**

1. **Memory + plan canonical setup:**
   - Tạo `C:\Users\Vu Minh Tu\.claude\projects\d--Working-MCV3\memory\project_skill_design_expansion_v1.md`
   - Update `MEMORY.md` index
   - Tạo `plans/skill-design-expansion-v1/{README.md, 00-master-plan.md, progress.md}`

2. **5 skill folder design hoàn chỉnh (50 file total):**
   - **wf-implement-feature** (v5.2.0, 10 files): TDD core skill, parallel review, system-grouped layout v5, CORE-020 safety gate, `--from-fix-bugs` cross-skill, 19 evals
   - **wf-e2e-verify** (v8.0.0, 10 files): Orchestrator 11-step F0/F0a/F0b/F1-F8, backward-compat legacy flags, anti-loop F6↔F5, --no-playwright deprecated, 9 evals
   - **wf-analyze-requirements** (v3.0.0, 10 files): Multi-agent BA + 24 domain experts, 14 phases, ADR-OPT-01/02/03/04/05, Lane Dispatch per dept, dedup aggregator, 20 evals
   - **wf-design** (v4.0.0, 10 files): 7 agent types, 11 phases, ADR-OPT Lane per system + dual-dedup, Phase 7 LEGACY Gap Analysis SEQUENTIAL, --from-scan Sprint 5, 6 evals
   - **wf-define-features** (v3.2.0, 10 files): Referential Integrity Fix v3.1 (E020 + auto-stub), W4.7 Cross-Module Detection v3.2, CF6 Cross-FEAT Ref v3.3, dual-schema feature-briefs, 6 evals

3. **Cross-link updates:**
   - `docs/04-skill-design/README.md` §3 inventory — 5 row mới (2 cũ + 5 mới = 7 row total)
   - `docs/05-review-standards/{skill}.md` §Reference — 5 cross-link "Skill design canon" thêm vào

**Tổng:** Tier 1 = 5/5 skills (100%), 50 files total (5 × 10 = README + 9 design files).

**Phiên kế tiếp (nếu có):**
- Tier 2: wf-plan-modules → wf-brainstorm → wf-preflight → wf-manage-change → wf-fix-execute
- Hoặc defer hoàn toàn — Tier 1 đã đủ cover skills critical

---

## Style guide — tham khảo skill đã viết

Pattern thành công áp dụng cross-session:

**Standard skill (wf-implement-feature):**
- 9-file flow chuẩn: vision (teaching) → arguments (reference) → routing (Mermaid+formal) → contracts (schemas) → error codes (table) → templates (table) → procedures (outline) → ADRs (Context→Decision→Alternatives→Consequences) → evals (test cases table)

**Orchestrator skill (wf-e2e-verify):**
- `orchestrates[]` schema thay produces/consumes
- Sub-skill mapping table
- Anti-loop counters + escalation
- Backward-compat legacy flags
- Standalone modes (--fix/--retest/--unblock-test)

**Multi-agent skill (wf-analyze-requirements, wf-design, wf-define-features):**
- BA-first orchestration (analyze-requirements)
- 7 agent types với conditional spawning (wf-design)
- Lane Dispatch per dept/system/module
- Signal Aggregation dedup
- ADR-OPT pattern (Lane/Session/Workload/Aggregator/Template Strip)
- Registry safe-write PRIMARY với fields_owned explicit

**Distinctive features documentation:**
- Referential Integrity (define-features v3.1)
- Cross-Module Detection (define-features v3.2 W4.7)
- Cross-FEAT Ref Detection (define-features v3.3 CF6)
- Dual-schema (define-features feature-briefs)
- File naming divergence (define-features NEW vs LEGACY)

---

## Resume protocol (cho phiên sau)

```
1. Đọc file này (progress.md)
2. Đọc project_skill_design_expansion_v1.md memory
3. Xác định Tier next (2 hoặc 3) và skill order
4. Đọc 4 file ground truth của skill: SKILL.md, _contract.json, procedures/, evals/
5. Copy _template/ → {skill}/ (hoặc create files trực tiếp như Phiên #1)
6. Populate 9 file (xóa _template_notes blocks nếu copy)
7. Sau khi xong 1 skill → tick + update progress + update §3 README
8. Sau 2-3 skill hoặc cuối phiên → update memory file
```
