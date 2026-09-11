# Phase 8: Digest & Phase Summary

> POST-GATE handoff: tạo `design-input-digest.json` cho downstream skills (Phiên 6 — Digest Pipeline)
> và `phase-summary.md` cho user observability (CORE-028).

**PRE-GATE:**

```bash
# Phase 6 đã completed
jq -e '.design_status == "completed"' .mc-data/docs/_meta/req-registry.json

# Phase 6 outputs sẵn sàng
test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md
test -s .mc-data/work/wf-design/design-summary.json

# Nếu LEGACY_MODE: Phase 7 đã completed
[ "$LEGACY_MODE" != "true" ] || test -f .mc-data/work/legacy-scan/final-report.md
```

**INPUT:**
- `P3-01-architecture.md` + `technical-specs/*.md` (extract key decisions)
- `req-registry.json` (design_status, systems, modules)
- Template `.claude/doc-framework/_digests/design-input-digest.template.json`
- Template `.claude/doc-framework/_meta/phase-summary.template.md`

**OUTPUT:**
- `.mc-data/docs/_meta/design-input-digest.json` (digest cho wf-design-ux, wf-plan-modules, wf-implement-feature)
- `.mc-data/work/wf-design/phase-summary.md` (CORE-028)
- Session log entry (CORE-026)

---

## Sub-Phase 8A: Generate Digest Artifact

> Tạo `design-input-digest.json` từ Phase 3 output để downstream skills load nhanh.
> Consumers: `/wf-design-ux` PRE-GATE, `/wf-plan-modules` Phase 0.5, `/wf-implement-feature` Phase 0.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 8.1 | Đọc P3-01-architecture.md, technical-specs/*, API contract docs | Read | Context sẵn sàng |
| 8.2 | ĐỌC template `.claude/doc-framework/_digests/design-input-digest.template.json` → POPULATE values từ Phase 3 docs | Read | Template loaded, values populated |
| 8.2a | **Template Strip (ADR-OPT-05):** Xoá metadata fields khỏi populated data:<br>`jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' populated.json > stripped.json`<br>(xem `_shared/_shared.md §1 Template Metadata Stripping`) | Metadata fields không tồn tại trong stripped data |
| 8.2b | **Atomic Write (ADR-OPT-05):** Ghi vào session working copy:<br>`jq '.' stripped.json > $SESSION_DIR/design-input-digest.json.tmp`<br>`jq validate → mv $SESSION_DIR/design-input-digest.json.tmp $SESSION_DIR/design-input-digest.json`<br>(xem `_shared/_shared.md §2 Atomic Write Pattern`) | `test -s $SESSION_DIR/design-input-digest.json` + JSON valid |
| 8.2c | **Sync canonical path:**<br>`cp $SESSION_DIR/design-input-digest.json .mc-data/docs/_meta/design-input-digest.json` | `test -s .mc-data/docs/_meta/design-input-digest.json` |
| 8.3 | Validate canonical: `jq '.' .mc-data/docs/_meta/design-input-digest.json` | Bash | JSON valid |

**design-summary.json — cùng pattern:**

| Step | Action | Verify |
|------|--------|--------|
| 8.3b | ĐỌC `$SESSION_DIR/design-summary.json` (đã được tạo bởi Phase 6) → **Template Strip** → **Atomic Write** → `$SESSION_DIR/design-summary-final.json` | JSON valid, no `_template_notes` |
| 8.3c | **Sync canonical:** `cp $SESSION_DIR/design-summary-final.json .mc-data/work/wf-design/design-summary.json` | `test -s .mc-data/work/wf-design/design-summary.json` |

**Fallback:** Nếu digest generation fail → log warning, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

---

## Sub-Phase 8B: Phase Summary (CORE-028)

> Tạo phase-summary.md viết tiếng Việt cho non-specialist — ≤15 dòng, tóm tắt kết quả Phase 3.

| Step | Action | Verify |
|------|--------|--------|
| 8.4 | ĐỌC template `.claude/doc-framework/_meta/phase-summary.template.md` | Template loaded |
| 8.5 | POPULATE các fields:<br>- **Phase:** Phase 3 — Architecture Design<br>- **Skill:** /wf-design<br>- **Approach:** `$APPROACH`<br>- **Systems/Modules:** danh sách từ registry<br>- **Files created:** count + list<br>- **Stakeholder review:** status (APPROVED / APPROVED_WITH_CONDITIONS / REJECTED) + finding counts<br>- **Next step:** `/wf-design-ux` hoặc `/wf-plan-modules` | Fields populated |
| 8.6 | GHI `.mc-data/work/wf-design/phase-summary.md` | `test -s phase-summary.md` |
| 8.7 | Validate: file ≤15 dòng non-empty, viết tiếng Việt | Format valid |

---

## Sub-Phase 8C: Session Log + State Finalize (CORE-026)

| Step | Action | Verify |
|------|--------|--------|
| 8.8 | Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json` với: skill=wf-design, status=completed, session_id=$SESSION_ID, phases=[0..8], agents_spawned=`$AGENTS_SPAWNED`, errors=error_log[] | Entry appended |
| 8.9 | UPDATE session-state.json: SET `phases.P8.status = "completed"`, `next_action = null` (workflow complete). Sync `design-status.json` từ `$SESSION_DIR/design-status.json` → `.mc-data/work/wf-design/design-status.json`. | `jq '.phases.P8.status' session-state.json → "completed"` |

---

## POST-GATE

```bash
# Digest artifact — session working copy
test -s $SESSION_DIR/design-input-digest.json
jq '.' $SESSION_DIR/design-input-digest.json

# Digest artifact — canonical path (CORE-007)
test -s .mc-data/docs/_meta/design-input-digest.json
jq '.' .mc-data/docs/_meta/design-input-digest.json

# Template strip checks (ADR-OPT-05)
jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/design-input-digest.json
jq -e '.components | length > 0' .mc-data/docs/_meta/design-input-digest.json
jq -e '.apis | length >= 0' .mc-data/docs/_meta/design-input-digest.json

# design-summary.json canonical
test -s .mc-data/work/wf-design/design-summary.json
jq 'has("_template_notes") | not' .mc-data/work/wf-design/design-summary.json

# Phase summary
test -s .mc-data/work/wf-design/phase-summary.md
[ $(wc -l < .mc-data/work/wf-design/phase-summary.md) -le 30 ]  # tolerance cho markdown formatting

# Session log updated
grep -q '"skill":\s*"wf-design"' .mc-data/work/_trace/session-log.json 2>/dev/null

# session-state completed
jq -e '.phases.P8.status == "completed"' $SESSION_DIR/session-state.json
```

---

## Output Report (hiển thị cho user)

Khi hoàn thành, hiển thị:

```markdown
## /wf-design — Hoàn tất

**Approach:** [Module/System/Platform] Design

**Files đã tạo:**
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase3-architecture/technical-specs/database-design.md`
- `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md`
- `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md`
- `.mc-data/docs/phase3-architecture/stakeholder-review.md`
- `.mc-data/work/wf-design/design-summary.json` (compressed spec)
- `.mc-data/docs/_meta/design-input-digest.json` (downstream digest)

**Stakeholder Review Summary:**
- Phần B (Technical Review): [N findings] — [X RESOLVED, Y DEFERRED]
- Phần C (Consistency Check): [N findings] — [X RESOLVED, Y DEFERRED]
- Phần D (Gap Analysis): [N findings] — [X RESOLVED, Y DEFERRED]

[Nếu LEGACY_MODE:] **Gap Analysis:**
- Critical: [N] | High: [N] | Medium: [N] | Low: [N]
- Action items: `.mc-data/work/legacy-scan/action-items.json`

**Next:**
- `/wf-design-ux` (nếu project có UI — `interface_type != "api-only"`)
- `/wf-plan-modules` (nếu API-only hoặc sau `/wf-design-ux`)
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E015 | Digest generation fail | Log warning, continue (backward compatible) |
| E016 | Phase summary template thiếu | Fallback tạo summary inline |

---

## End of wf-design Workflow

Skill kết thúc tại đây. Xem checkpoint + session log để review execution trace.
