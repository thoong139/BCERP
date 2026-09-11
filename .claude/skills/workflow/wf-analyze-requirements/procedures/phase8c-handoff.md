# Phase 8c: Generate Phase 1 Handoff

> Chốt artifact trung gian gọn cho `/wf-define-features` dùng lại, tránh phải đọc full Phase 1 docs ở mọi bước downstream.
> Phase cuối cùng — sau khi hoàn thành, in Output Report (xem `_shared.md §Output Report Template`).

**PRE-GATE:** Phase 8b POST-GATE PASS.

**INPUT:** Registry cuối + tất cả `[dept].md` + `P1-02-business-workflow.md` + `stakeholder-review.md` (nếu có) + `deferred-issues.md` (nếu có) + `.mc-data/work/wf-brainstorm/project-intent-digest.json` (nếu có)

**OUTPUT:**
- `.mc-data/work/wf-analyze-requirements/department-digests.json`
- `.mc-data/work/wf-analyze-requirements/phase1-handoff.json`
- `.mc-data/docs/_meta/dept-digests.json` (canonical copy)
- `.mc-data/docs/_meta/phase1-handoff.json` (canonical copy)

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 8c.1 | Tạo `$SESSION_DIR/department-digests.json` từ template `.claude/skills/workflow/wf-analyze-requirements/templates/department-digests.json` (Template Usage Rule CORE-031) — tổng hợp cho mỗi department: `department_id`, `department_name`, `actors`, `workflow_touchpoints`, `core_requirements`, `business_rule_keywords`, `integrations`, `open_questions`, `source_files[]`. Nguồn sự thật: dept docs + `P1-02-business-workflow.md` + registry.<br>**Template Strip (ADR-OPT-05):** `jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json`<br>**Atomic Write (ADR-OPT-05):** tmp → validate → mv → `$SESSION_DIR/department-digests.json` (xem `_shared/_shared.md §1-2`)<br>Sau đó mirror sang `.mc-data/work/wf-analyze-requirements/department-digests.json` (dual-write backward-compat). | Digest hợp lệ JSON, không chứa `_template_notes` |
| 8c.2 | Tạo `$SESSION_DIR/phase1-handoff.json` từ template `.claude/skills/workflow/wf-analyze-requirements/templates/phase1-handoff.json` (Template Usage Rule) — điền: project context, scope, `requirement_clusters`, `actors`, `workflow_touchpoints`, `business_rule_keywords`, `integration_notes`, `deferred_items`, `review_notes`, `next_phase_focus`. Ưu tiên sự thật từ registry + dept docs + stakeholder-review + `project-intent-digest.json` (nếu có).<br>**Template Strip + Atomic Write** (cùng pattern 8c.1) → `$SESSION_DIR/phase1-handoff.json`<br>Mirror sang `.mc-data/work/wf-analyze-requirements/phase1-handoff.json`. | Digest hợp lệ JSON, không chứa `_template_notes` |
| 8c.2b | **SYNC sang canonical `_meta/`** (CORE-007 §4b — source giờ từ `$SESSION_DIR`):<br>`cp $SESSION_DIR/department-digests.json .mc-data/docs/_meta/dept-digests.json`<br>`cp $SESSION_DIR/phase1-handoff.json .mc-data/docs/_meta/phase1-handoff.json`<br>Downstream consumers (`/wf-define-features`) đọc từ canonical `_meta/` — nội dung gốc đến từ session dir (không ghi đè session cũ). | `test -s .mc-data/docs/_meta/dept-digests.json && test -s .mc-data/docs/_meta/phase1-handoff.json` |
| 8c.3 | Cập nhật `.mc-data/work/wf-analyze-requirements/analyze-status.json`: `handoff_artifacts.department_digest_file = $SESSION_DIR/department-digests.json`, `handoff_artifacts.phase1_handoff_file = $SESSION_DIR/phase1-handoff.json`, `handoff_artifacts.session_id = $SESSION_ID`, `timestamps.last_updated`. Nếu status có `runtime_metrics.source` thì cập nhật `last_metrics_sync_at`.<br>Cập nhật `$SESSION_DIR/session-state.json`: `phases.P8c.status = "completed"`, `status = "completed"`, `digests_produced[]` append 2 entries (dept-digests, phase1-handoff). | Status updated + session-state completed |

**Fallback:** Nếu digest generation fail → log warning vào `analyze-report-[date].md`, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

**POST-GATE:**

```bash
# T1-T2: file existence + non-empty (working + session + canonical)
test -s $SESSION_DIR/department-digests.json && \
  test -s $SESSION_DIR/phase1-handoff.json && \
  test -s .mc-data/work/wf-analyze-requirements/department-digests.json && \
  test -s .mc-data/work/wf-analyze-requirements/phase1-handoff.json && \
  test -s .mc-data/docs/_meta/dept-digests.json && \
  test -s .mc-data/docs/_meta/phase1-handoff.json

# T3: No _template_notes leaked (ADR-OPT-05 check)
jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/dept-digests.json
jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/phase1-handoff.json
jq -e 'has("_template_notes") | not' $SESSION_DIR/department-digests.json
jq -e 'has("_template_notes") | not' $SESSION_DIR/phase1-handoff.json

# T4: Session state marked completed
jq -e '.status == "completed" and .phases.P8c.status == "completed"' $SESSION_DIR/session-state.json
```

**Status update:** `analyze-status.json` → `phase_8c.status = "completed"`, `status = "completed"`, `progress_pct = 100`, `timestamps.completed_at = <ISO timestamp>`.

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id=8c, status=completed, items_processed (N departments, M requirements → handoff artifacts), key_findings (scope, clusters, deferred count), next_action=/wf-define-features
3. WRITE: `.mc-data/work/wf-analyze-requirements/phase-summary.md` (ghi đè final summary tổng của skill)

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json` — đánh dấu toàn bộ skill `/wf-analyze-requirements` kết thúc.

## Output Report

Xem `_shared.md §Output Report Template` — in report cuối cùng cho user.

**Next skill:** `/wf-define-features`
