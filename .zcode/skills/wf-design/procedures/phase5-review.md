# Phase 5: Stakeholder Technical Review (AUTO-CORRECTION LOOP)

> Rà soát kết quả thiết kế kỹ thuật — phát hiện xung đột, thiếu sót, bất nhất quán.
> Spawn parallel agents: architect (Phần B+C) + security (Phần D).

> **Auto-Correction:** Áp dụng Auto-Correction Loop Protocol (max 3 iterations) — xem `.claude/skills/protocols/`
> Fix source documents (technical spec, feature spec), KHÔNG fix SO docs. Regenerate ONLY affected SO docs sau mỗi iteration.

**PRE-GATE:** Phase 4 Cross-Validation PASSED (zero CRITICAL errors HOẶC user acknowledged)

**INPUT:**
- `P3-01-architecture.md` + `technical-specs/*.md`
- `phase2-features/**/*.md`
- Template `.claude/doc-framework/phase3-architecture/stakeholder-review.md`

**OUTPUT:** `.mc-data/docs/phase3-architecture/stakeholder-review.md` (Phần A-D)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.1 | Đọc tất cả Phase 3 docs: P3-01, technical-specs/*, phase2-features/* (hoặc design-digest nếu > 5 files) | All loaded |
| 5.2 | Spawn PARALLEL: `architect` agent → `_tmp-so-bc.md` (Phần B + C) + `security` agent → `_tmp-so-d.md` (Phần D) | Agents success |
| 5.3 | **MERGE** `_tmp-so-bc.md` + `_tmp-so-d.md` → `stakeholder-review.md` (Phần B, C, D) | Merge complete |
| 5.4 | Xóa temp files `_tmp-so-*.md` | Temp files removed |
| 5.5 | Cập nhật Phần A (dashboard) trong `stakeholder-review.md` với status + issues summary | Phần A có nội dung |
| 5.6 | **CLASSIFY FINDINGS** — phân loại mỗi finding thành Fixable hoặc Deferred (xem Fix Rules trong `_shared.md`) | Tất cả findings đã classified |
| 5.7 | **AUTO-CORRECTION LOOP** (max 3 iterations) — auto-fix Fixable findings, DEFER phần còn lại | Zero Critical/High ở trạng thái PENDING |
| 5.8 | Cập nhật Phần A — tổng hợp RESOLVED + DEFERRED với lý do | `test -s stakeholder-review.md` |
| 5.9 | **SAVE CHECKPOINT:** ĐỌC `templates/checkpoint.json` → POPULATE `position` (phase_5 completed), `progress`, `files_state` (+= stakeholder-review.md), `coverage_state` → GHI `.mc-data/work/wf-design/checkpoint.json` | Checkpoint saved, JSON valid |

---

## Agent Prompts

Xem `_shared.md` §Agent Prompt Templates:
- **P5-A** — architect (Phần B+C: Cross-Review, Consistency)
- **P5-B** — security (Phần D: Gap Analysis)

Nếu `$LEGACY_MODE = true`: mỗi agent prompt PHẢI inject LEGACY BLOCK.

---

## Execution Diagram

```
Phase 3 docs ──┬─ PARALLEL ──┬→ architect   → _tmp-so-bc.md (Phần B + C)
               │             │
               │             └→ security    → _tmp-so-d.md  (Phần D)
               ↓
        MERGE → stakeholder-review.md (Phần A, B, C, D)
               ↓
        CLASSIFY FINDINGS (Fixable vs Deferred)
               ↓
        AUTO-CORRECTION LOOP (max 3 iterations)
        - Fix source docs (api-contract, database-design, etc.)
        - DEFER Critical non-auto-fixable → ghi lý do trong Phần A
```

---

## DEFERRED Classification (BẮT BUỘC)

Findings KHÔNG thể auto-fix trong Phase 5 PHẢI được:
1. Đánh dấu **DEFERRED** trong `phase3-architecture/stakeholder-review.md` Phần A (KHÔNG để PENDING)
2. Ghi **lý do** không thể fix tại design phase
3. Ghi **phase/sprint** nào sẽ xử lý (pre-launch / sprint N)
4. Nếu có DEFERRED Critical → ghi rõ trong Phần A Section "Điều Kiện Phase 3"

---

## Đánh giá tổng thể

| Kết quả | Điều kiện |
|---------|-----------|
| **APPROVED** | Zero Critical/High findings open (tất cả RESOLVED) |
| **APPROVED_WITH_CONDITIONS** | Có DEFERRED Critical/High — nhưng tất cả đã classified, không PENDING |
| **REJECTED** | Có PENDING Critical/High sau 3 iterations — STOP |

---

## POST-GATE

```bash
# T1: File tồn tại + non-empty
test -s .mc-data/docs/phase3-architecture/stakeholder-review.md

# T2: Có đủ Phần A, B, C, D
grep -q '^## Phần A' .mc-data/docs/phase3-architecture/stakeholder-review.md
grep -q '^## Phần B' .mc-data/docs/phase3-architecture/stakeholder-review.md
grep -q '^## Phần C' .mc-data/docs/phase3-architecture/stakeholder-review.md
grep -q '^## Phần D' .mc-data/docs/phase3-architecture/stakeholder-review.md

# T3: Zero Critical/High findings ở trạng thái PENDING (tất cả RESOLVED hoặc DEFERRED)
# Manual check theo Phần A dashboard
```

> **Trạng thái findings:** PENDING (chưa xử lý) | RESOLVED (đã sửa trong source docs) | DEFERRED (ghi lý do trong Phần A)

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E012 | Stakeholder review Critical/High findings sau 3 iterations | STOP + báo cáo findings → user quyết định |
| E011 | Auto-fix gây regression | Rollback fix → escalate |

---

## Next Phase

→ Read `procedures/phase6-finalize.md` — Registry Update + Compressed Spec
