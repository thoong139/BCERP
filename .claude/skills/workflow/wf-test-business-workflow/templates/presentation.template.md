# TEMPLATE: Workflow Presentation — {WF-id}

> Sinh bởi Phase 3 NARRATE từ dual-agent outputs. Đối tượng đọc: BA/PM (không chuyên kỹ thuật).

---

# {WF-id}: {Tên workflow} — Demo Presentation

**Ngày test:** {date} · **Kết quả:** {PASS/PARTIAL} · **Session:** {SESSION_ID}

## §1. Tổng quan demo

{Từ §1 spec + run metadata: workflow này làm gì, phục vụ ai, phạm vi demo 2-4 câu.}

## §2. Góc nhìn nghiệp vụ

{(từ domain-expert agent, ~600 từ tiếng Việt): mục đích nghiệp vụ, actors, KPIs ảnh hưởng, tác động downstream, edge cases quan trọng.}

## §3. Góc nhìn kỹ thuật

{(từ developer agent, ~600 từ tiếng Việt): sequence BE/FE, các lớp validation, side effects, điểm assert.}

## §4. Kết quả QA

| Nhóm | Tổng | Pass | Fail/Deferred | Ghi chú |
|------|------|------|---------------|---------|
| Happy path | | | | |
| Edge cases | | | | |
| Negative | | | | |

Bugs còn mở: {BUG-NNN list hoặc "không có"} · Fix trong session: {số fix} iterations.

## §5. Artifacts

- Screenshots: `.mc-data/work/wf-test-business-workflow/sessions/{SESSION_ID}/playwright/evidence/{WF-id}/`
- Checkpoint: `_runs/checkpoints/{WF-id}.json`
- Re-run: `/wf-test-business-workflow --workflow={WF-id} --no-spawn`
- Regression spec: `apps/erp-web/e2e/wf/{WF-id}.spec.ts`
