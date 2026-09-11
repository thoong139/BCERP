# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của `wf-define-features`.

---

## 1. Tóm tắt

`wf-define-features` chuyển **abstract requirements** thành **actionable feature specs** với user stories, business rules, permissions. v3.x là core skill cho mapping REQ-IDs → FEAT-IDs với 4 power features: **Referential Integrity Fix** (v3.1), **W4.7 Cross-Module Entity Detection** (v3.2), **CF6 Cross-FEAT Ref Detection** (v3.3), **dual-schema feature-briefs**.

---

## 2. Vấn đề trước khi có skill

| Pain point | Mô tả |
|------------|------|
| Manual mapping REQ → FEAT | Bỏ sót REQ-IDs, không trace được |
| Stale references (orphan REQ-IDs) | features có `req_ids[]` reference REQ không tồn tại → downstream wf-implement-feature crash |
| Cross-module entity refs không declare | Feature ở module A reference `MOD-B` entity, nhưng `cross_module_dependencies[]` không có → integration drift |
| Feature spec không có acceptance criteria rõ | Dev không biết "DONE khi nào?" |
| LEGACY: file naming inconsistent | Mix kebab-case vs FEAT-ID prefix |
| `feature-briefs.json` schema lẫn lộn | Working ≠ digest — consumer downstream confused |

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | **Referential Integrity (v3.1)** — Block khi orphan REQ-IDs detected, suggest 3 lựa chọn | Phase 5 step 5.3c → E020. Eval TC-1 |
| 2 | **W4.7 Cross-Module Detection (v3.2)** — Suggest undeclared cross-module deps, non-blocking | Phase 3 check 3.8. Eval TC-2 |
| 3 | **CF6 Cross-FEAT Ref Detection (v3.3)** — Auto-suggest `cross_feat_refs[]` từ feature mentions | Phase 2.1c AskUserQuestion. Eval TC-3 |
| 4 | **Dual-schema feature-briefs** — Working (creation use) ≠ Digest (consumer schema) | Phase 1 creation + Phase 6 digest gen |
| 5 | **`--auto-stub-requirements`** — Optional escape hatch cho orphan REQ-IDs | v3.1 flag. APPEND stubs với `auto_generated_by` + `needs_user_review` |
| 6 | **`--from-scan` (Sprint 5)** — Suggest features từ wf-scan-target inventory | Suggest-only, user accept/reject |
| 7 | **LEGACY UI Coverage (Phase 2.7)** — Detect orphan UI screens không có feature | LEGACY only, `ui-coverage-gaps.json` |
| 8 | **Stub Detection (v1.8+)** — Flesh-out stubs từ wf-fix-bugs --deep | `status: stub` frontmatter detection |

---

## 4. Nguyên tắc thiết kế

1. **Referential Integrity at Source (v3.1)** — Block tại Phase 5 KHI features reference REQ-IDs không tồn tại. KHÔNG để downstream wf-implement-feature crash. `--auto-stub-requirements` là escape hatch CÓ TRACKING (`auto_generated_by`, `needs_user_review`).

2. **W4.7 Cross-Module Suggest-Only** — Phase 3 check 3.8 detect `MOD-XXX` refs từ module khác. Interactive AskUserQuestion (Có/Không/Deferred). KHÔNG block POST-GATE. Graceful skip khi registry chưa có `cross_module_dependencies` field.

3. **CF6 Cross-FEAT Ref Detection (v3.3)** — Scan feature specs tìm `FEAT-XXX` hoặc `REQ-XXX` mention → auto-suggest entry cho `features[].cross_feat_refs[]`. User review/accept từng suggestion. wf-verify-sync sẽ validate refs về sau.

4. **Dual-schema feature-briefs.json** — Working (`templates/feature-briefs.json`): fields `feat_id`, `actors`, `business_rules`, `output_path` cho Phase 1 creation. Digest (`_digests/feature-briefs.template.json`): fields `feature_id`, `summary`, `acceptance_criteria`, `technical_complexity` cho downstream. Phase 6 generate digest schema riêng.

5. **Stub Detection (v1.8+)** — Detect frontmatter `status: stub` (từ `/wf-fix-bugs --deep`) → flesh-out content theo template, remove `status: stub`, giữ `related_feature_id`.

6. **File naming convention divergence** — NEW: `kebab-case-vietnamese.md`. LEGACY: `FEAT-ID.md`. Intentional difference cho consistency với `feat-mapping.json` legacy tools.

7. **Append-only features[]** — Phase 5 safe-write: append entries mới, KHÔNG modify/delete existing. `impl_status` chỉ set "skipped" cho features thuộc DEPRECATED modules.

8. **CORE-032 Lazy-Load** — SKILL.md ~430 dòng. 11 procedure files.

---

## 5. Non-goals

- **Analyze requirements** — `wf-analyze-requirements` làm (skill này CONSUME requirements)
- **Design architecture/tech stack** — `wf-design`
- **Implement code** — `wf-implement-feature`
- **Modify `requirements[]`, `systems[]`, `modules[]`** — wf-analyze-requirements owns
- **Modify `design_status`, `impl_status`** (trừ DEPRECATED skip) — wf-design, wf-implement-feature owns

---

## 6. Tham chiếu

- Patterns: [lazy-load](../../03-design-patterns/01-lazy-load-procedures.md), [parallel-lane](../../03-design-patterns/04-parallel-lane-dispatch.md), [checkpoint-resume](../../03-design-patterns/06-checkpoint-resume.md), [cdg-gate](../../03-design-patterns/10-cdg-gate.md)
- Rules: CORE-006 (safe-write `features[]`), CORE-007 (cross-skill), CORE-010 (impl_status states), CORE-027 (CDG), CORE-031, CORE-032

## 7. Liên kết design canon

- Architecture chi tiết: [`03-phase-routing.md`](03-phase-routing.md) — 11 phases dispatch
- Contract: [`04-file-contract.md`](04-file-contract.md) — PRE-GATE/POST-GATE per phase
- ADR decisions: [`08-tradeoffs-adr.md`](08-tradeoffs-adr.md) — bao gồm decision về W4.7, --auto-stub-requirements, append-only features
- Agent prompt patterns: [`agent-prompt.md`](agent-prompt.md) — BA Phase 2 + product-expert Phase 4
- Master checklist: [`00-master-checklist.md`](00-master-checklist.md) — 10-step gating
