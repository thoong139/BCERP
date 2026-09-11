# Phase 7: Digest Artifacts & Phase Summary (ADR-OPT-05)

> POST-GATE wrap-up: Template Strip + Atomic Write `ux-input-digest.json` → sync canonical → phase-summary.md + session log close.

**PRE-GATE:**
- [ ] Phase 6 (`phase6-registry.md`) POST-GATE PASS
- [ ] `jq '.ux_design_status == "done"' registry.json` = true
- [ ] `$SKILL_SKIPPED != true` (nếu api-only đã EXIT ở Phase 0.5.0, Phase 7 KHÔNG chạy — đã handled bởi exit gate)

**INPUT:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase4-ux/*/Navigation-*.md`
- `.mc-data/docs/phase4-ux/*/*/screens-*.md`
- `.mc-data/docs/phase4-ux/stakeholder-review.md`
- `.mc-data/work/wf-design-ux/design-ux-status.json`

**OUTPUT:**
- `.mc-data/docs/_meta/ux-input-digest.json` — downstream digest cho `/wf-plan-modules`
- `.mc-data/work/wf-design-ux/phase-summary.md` — CORE-028 summary
- Session log closed (CORE-026)

---

## Reference Sections

- `protocols/` §14 Phase Summary Protocol
- `protocols/` §15 Session Log Protocol
- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.1 | Đọc design-system.md, Navigation specs, screen groups, aggregation-result.json từ `$SESSION_DIR` | Context ready |
| 7.2 | **[READ-TEMPLATE]** READ `.claude/doc-framework/_digests/ux-input-digest.template.json` | Template loaded |
| 7.3 | POPULATE digest fields từ template — xem §Digest Structure | Digest JSON ready |
| 7.4 | **Template Strip (ADR-OPT-05):** `jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest-raw.json > $SESSION_DIR/ux-input-digest.json.tmp` | Strip applied |
| 7.5 | **Validate JSON:** `jq '.' $SESSION_DIR/ux-input-digest.json.tmp` phải pass | Valid JSON |
| 7.6 | **Atomic Write:** `mv $SESSION_DIR/ux-input-digest.json.tmp $SESSION_DIR/ux-input-digest.json` | `test -s $SESSION_DIR/ux-input-digest.json` |
| 7.7 | **Sync canonical:** `cp $SESSION_DIR/ux-input-digest.json .mc-data/docs/_meta/ux-input-digest.json` | `test -s .mc-data/docs/_meta/ux-input-digest.json` |
| 7.8 | **POST-GATE verify strip:** `jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/ux-input-digest.json` → true | `_template_notes` absent |
| 7.9 | **[READ-TEMPLATE]** READ `.claude/doc-framework/_meta/phase-summary.template.md` | Template loaded |
| 7.10 | POPULATE phase-summary theo CORE-028 (tiếng Việt, non-specialist, <= 15 dòng) — xem §Phase Summary | Summary ready |
| 7.11 | WRITE `$SESSION_DIR/phase-summary.md` | File exists, non-empty |
| 7.12 | Append session log entry (COMPLETE/FAIL/SKIP) → `.mc-data/work/_trace/session-log.json` | Entry appended |
| 7.13 | **FINAL CHECKPOINT** — POPULATE (trigger=skill_complete, position.current_phase=7, status=done, session_id=$SESSION_ID) → WRITE `$SESSION_DIR/checkpoint.json` | Checkpoint saved |

---

## Digest Structure (Step 7.3)

Populate `ux-input-digest.json` theo schema từ template:

```json
{
  "$schema": "ux-input-digest-v1",
  "produced_by": "wf-design-ux",
  "produced_at": "[ISO 8601 timestamp]",
  "interface_type": "[$INTERFACE_TYPE]",
  "design_system": {
    "path": ".mc-data/docs/phase4-ux/design-system.md",
    "sections": ["Màu Sắc", "Chữ", "Khoảng Cách", "Component", "Bố Cục", "Quy Ước"],
    "key_tokens": {
      "colors": ["primary", "secondary", ...],
      "typography": ["h1", "h2", ...],
      "spacing": ["4", "8", "16", ...]
    }
  },
  "navigation": [
    {
      "system": "SYS-XXX",
      "path": ".mc-data/docs/phase4-ux/[sys]/Navigation-[sys].md",
      "screen_groups_count": N,
      "key_routes": ["/route1", "/route2", ...]
    }
  ],
  "screen_groups": [
    {
      "system": "SYS-XXX",
      "module": "MOD-YYY",
      "path": ".mc-data/docs/phase4-ux/[sys]/[mod]/screens-[group].md",
      "feat_ids": ["FEAT-XXX-001"],
      "ui_id_count": N,
      "api_endpoints": ["GET /api/xxx", ...]
    }
  ],
  "metrics": {
    "total_systems": N,
    "total_screen_groups": N,
    "total_ui_ids": N,
    "stakeholder_review_status": "APPROVED / APPROVED_WITH_CONDITIONS"
  }
}
```

**Fallback:** Nếu digest generation fail → log WARNING, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

---

## Phase Summary (Step 7.7)

Format per CORE-028 (tiếng Việt, non-specialist audience, <= 15 dòng):

```markdown
# Phase Summary — wf-design-ux

**Ngày:** [date]
**Scope:** [all / system-name]
**Status:** COMPLETED

## Kết quả
- Đã thiết kế design system với X color tokens, Y typography sizes, Z components
- Đã tạo Navigation spec cho N systems
- Đã tạo M screen groups (tổng K UI-IDs unique)
- Stakeholder review: APPROVED / APPROVED_WITH_CONDITIONS
- Findings: A Critical (0 remaining), B High (0 remaining), C Medium, D Low

## Agents đã dùng
- ux-researcher, ux-designer, ux-architect, brand-guardian (conditional),
  accessibility-auditor, architect

## Files tạo ra
- design-system.md, N Navigation files, M screen group files, stakeholder-review.md

## Next step
Chạy `/wf-plan-modules` để xác định implementation order.

## Deferred findings (nếu có)
- [liệt kê Critical/High DEFERRED]
```

---

## Session Log Entry (Step 7.9)

Append vào `.mc-data/work/_trace/session-log.json`:

```json
{
  "skill": "wf-design-ux",
  "event": "COMPLETE",
  "timestamp": "[ISO 8601]",
  "duration_seconds": N,
  "outputs": {
    "design-system.md": "done",
    "navigation_files": N,
    "screen_group_files": M,
    "stakeholder-review.md": "done",
    "registry_ux_design_status": "done",
    "ux-input-digest.json": "done"
  },
  "agents_spawned": [...],
  "errors_logged": X,
  "errors_fixed": Y,
  "cross_val_iterations": Z
}
```

---

## POST-GATE

- [ ] `$SESSION_DIR/ux-input-digest.json` tồn tại (working copy, post-strip)
- [ ] `.mc-data/docs/_meta/ux-input-digest.json` tồn tại và JSON hợp lệ (canonical — synced từ session)
- [ ] `jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/ux-input-digest.json` → true (không có template metadata)
- [ ] `$SESSION_DIR/phase-summary.md` tồn tại, non-empty, tiếng Việt, <= 15 dòng nội dung chính
- [ ] Session log entry appended với event=COMPLETE
- [ ] Final checkpoint saved tại `$SESSION_DIR/checkpoint.json` với status=done

**Next:** Skill complete. Hiển thị phase-summary.md content cho user + hướng dẫn next step.

---

## Output Report (hiển thị cho user)

```
✅ wf-design-ux completed successfully

Files tạo ra:
- Design System: .mc-data/docs/phase4-ux/design-system.md
- Navigation specs: N files (.mc-data/docs/phase4-ux/*/Navigation-*.md)
- Screen Groups: M files (.mc-data/docs/phase4-ux/*/*/screens-*.md)
- Stakeholder Review: .mc-data/docs/phase4-ux/stakeholder-review.md
- UX Input Digest: .mc-data/docs/_meta/ux-input-digest.json

Stakeholder Review Summary:
- Status: [APPROVED / APPROVED_WITH_CONDITIONS]
- Critical: 0 remaining
- High: 0 remaining  
- Medium: X (all RESOLVED hoặc DEFERRED)
- Low: Y

Next: /wf-plan-modules để xác định implementation order
```

---

## Error Handling

- Digest generation fail → log WARNING, tiếp tục (không block skill completion)
- phase-summary write fail → retry 3 lần, escalate
- Session log append fail → log WARNING, tiếp tục (session log là observability, không block)
