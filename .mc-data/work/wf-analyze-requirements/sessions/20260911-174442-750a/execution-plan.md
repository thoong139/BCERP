# Execution Plan — /wf-analyze-requirements (Protocol 9.2)

**Session:** 20260911-174442-750a · **Project:** BCERP · **Scope:** all · **LPM:** TRUE (max_parallel=3)

## Input
- `.mc-data/docs/_meta/req-registry.json` (seed: 6 systems, 5 depts, 0 reqs)
- `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` (~4.900 từ, 19 phân hệ, 5 depts)
- `.mc-data/docs/phase0-brainstorm/P0-02-systems-users.md` + `policies/` (20 files)
- `.mc-data/docs/phase1-business/P1-01-project-overview.md` (đã điền)
- `docs/00-overview/00-company-context.md` (bối cảnh BC Agency — bắt buộc)

## Output
- `phase1-business/departments/{bod,hr,finance,sales,operations}/*.md` (Phần A + Phần B)
- `phase1-business/P1-02-business-workflow.md`, `stakeholder-review.md`
- `req-registry.json`: modules[] ~19, requirements[] target 80–150
- Handoff: `department-digests.json` + `phase1-handoff.json` → `_meta/`

## Agents
- BA (business-analyst persona): 5 spawns — 1 per dept Phần A
- Experts: 7 spawns — bod(BA), hr(hr-expert), finance×2(finance, compliance), sales(sales-expert), operations×2(paid-media, marketing)
- On-call (6d): customer, data, legal, operations, ecommerce

## Execution Order
1. ~~Phase 0/0.5/1~~ ✅ (session init, gate dead_zone 0.667, scope=all)
2. ~~Phase 2~~ ✅ plan + LPM
3. **Phase 3 (BA Phần A):** batch [BOD, HR, FINANCE] → [SALES, OPS] — mỗi agent 1 dept, ~1.200–2.000 từ
4. Phase 4 (Expert Phần B, lane dispatch ADR-OPT-01, max 3): [BOD-B, HR-B, FIN-B1] → [FIN-B2, SALES-B, OPS-B1] → [OPS-B2] — ~1.500–2.500 từ/call, signals.json per lane
5. Phase 6 consolidation (aggregation + dedup REQ-ID) → 6b workflow → 6c stakeholder → 6d conflict
6. Phase 8 registry safe-write → 8b cross-val (3 iterations, 7 checks) → 8c handoff
7. Checkpoint: sau MỖI phase (LPM-05)

## Token Estimate (Protocol 9.3)
- Phase 3: 5 agents × ~6K output+context ≈ 30K; Phase 4: 7 × ~8K ≈ 56K; Phase 6–8c ≈ 40K inline. Tổng ước tính ~130–160K — cần manage context chặt: agent prompts chứa đường dẫn + trích đoạn, agents tự đọc file nguồn.
