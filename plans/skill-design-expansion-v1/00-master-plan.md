# 00 — Master Plan

> **Plan:** skill-design-expansion-v1
> **Bắt đầu:** 2026-05-15
> **Mục tiêu Tier 1:** 5 skill folder design hoàn chỉnh

---

## 1. Vision

Mỗi skill complex trên MCV3 có **folder design canon riêng** (9 file) trong `docs/04-skill-design/{skill}/` — chứa quyết định kiến trúc, contracts, tradeoffs, eval criteria. Contributor mới đọc folder design → hiểu skill mà không phải đọc source.

**Tại sao quan trọng:**
- 43 skills MCV3 — đọc source mỗi skill mới mất nhiều giờ
- Design decisions thường lưu trong commit messages, dễ mất theo thời gian
- Reviewer cần biết "tại sao chọn cách này" để review PR sửa skill
- `02-standards/02-skill-standard.md` §10 yêu cầu skill complex có folder design

---

## 2. Per-skill checklist (DoD per skill)

```
- [ ] Copy _template/ → docs/04-skill-design/{skill}/
- [ ] README.md (đổi title, version, date, skill display name)
- [ ] 01-vision-principles.md (vision + non-goals + nguyên tắc thiết kế)
- [ ] 02-arguments.md (bảng args + validation + examples)
- [ ] 03-phase-routing.md (Mermaid diagram + phase table + profile dispatch)
- [ ] 04-file-contract.md (PRE-GATE/POST-GATE + cross-skill produces_for/consumes_from + schemas)
- [ ] 05-error-codes.md (namespace E0xx + auto-fix budget + ledger)
- [ ] 06-templates-list.md (templates dùng + populate fields)
- [ ] 07-procedures-structure.md (_shared.md + phase{N}-*.md outline)
- [ ] 08-tradeoffs-adr.md (≥3 ADR theo template Context→Decision→Alternatives→Consequences)
- [ ] 09-evals-test-cases.md (≥3 test cases match evals.json)
- [ ] XÓA toàn bộ `<!-- _template_notes: ... -->` block trước commit
- [ ] Update docs/04-skill-design/README.md §3 inventory
- [ ] Update docs/05-review-standards/{skill}.md cross-link "Skill design canon"
```

---

## 3. Tier ranking & order

### Tier 1 — Critical (5 skill — đang làm)

Thứ tự thực thi:
1. **wf-implement-feature** — Dev dùng nhiều nhất, base case
2. **wf-e2e-verify** — Pipeline 11-step phức tạp, nhiều moving parts
3. **wf-analyze-requirements** — Multi-agent per dept, vision rộng
4. **wf-design** — 7 agent types, LEGACY branching
5. **wf-define-features** — Dual-schema digest, cross-skill mạnh

### Tier 2 — High (sau Tier 1)

6. wf-plan-modules · 7. wf-brainstorm · 8. wf-preflight · 9. wf-manage-change · 10. wf-fix-execute

### Tier 3 — Medium (defer)

11 lane skills (wf-fix-*) + 5 helper skills (wf-prepare-deployment, wf-design-ux, wf-add-scope, wf-verify-sync, wf-annotate-code).

---

## 4. Style guide

### Cho tone teaching (01-vision, 08-tradeoffs)
- Vietnamese ví dụ cụ thể
- "Tại sao có skill" với pain point thực tế
- ADR theo template: Context → Decision → Alternatives → Consequences

### Cho tone formal (03-routing, 04-contracts, 05-error-codes)
- Reference table dày
- Mermaid diagram + JSON schema snippets
- Bám sát ground truth (_contract.json + procedures/)

### Universal
- Tiếng Việt user-facing prose
- English cho identifiers/schema/code blocks
- Max 800 dòng/file (split nếu cần)
- KHÔNG copy-paste 100% từ SKILL.md — TÓM TẮT + cross-link
- XÓA toàn bộ `_template_notes:` HTML comment (CORE-031)

---

## 5. Constraints

- **KHÔNG sửa `.claude/**`** — chỉ thêm/sửa file trong `docs/04-skill-design/{skill}/` và update `docs/04-skill-design/README.md` + `docs/05-review-standards/{skill}.md`
- **Bám source thực tế** — đọc `_contract.json`, SKILL.md, procedures/ trước khi viết. KHÔNG invent fields/error codes/test cases
- **Path lowercase-kebab-case** (CORE-016)
- **Atomic write** cho files mới (Write tool đảm bảo)

---

## 6. Multi-session checkpoint

Sau khi xong mỗi 2-3 skill HOẶC khi context budget ≥80%:
1. Update `progress.md` với status từng skill
2. Update `project_skill_design_expansion_v1.md` mục "Trạng thái hiện tại"
3. Update `MEMORY.md` entry với % progress

Context budget tiers (CORE-038):
- <65%: tiếp tục bình thường
- 65-80%: chuẩn bị checkpoint
- 80-90%: hoàn thành skill hiện tại → STOP → handoff
- >90%: FORCE STOP

---

## 7. DoD cho cả Tier 1

- [ ] 5 folder hoàn chỉnh: wf-implement-feature, wf-e2e-verify, wf-analyze-requirements, wf-design, wf-define-features
- [ ] `docs/04-skill-design/README.md` §3 có 7 row (2 cũ + 5 mới)
- [ ] `progress.md` Tier 1 100%
- [ ] Memory + MEMORY.md updated
- [ ] (Optional) Run link check để verify 0 broken
