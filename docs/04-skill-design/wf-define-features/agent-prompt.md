# Agent Prompt Templates — wf-define-features

> **Mục đích file:** Concrete agent prompt templates cho mọi `Agent({...})` call trong `wf-define-features`. Tuân thủ CORE-037 (8 sections). Skill spawn 2 agent types: BA (Phase 2 feature spec generation) + product-expert (Phase 4 stakeholder review).

---

## 1. Agents skill này spawn

| Phase | Agent | subagent_type | Vai trò | Spawn count |
|-------|-------|--------------|---------|-------------|
| Phase 2 | Business Analyst | `business-analyst` | Generate feature spec từ REQ-ID (1 spec/feature) | 1 per FEAT-ID (parallel batch) |
| Phase 4 | Product Expert | `product-expert` | Stakeholder review Phần B (PO perspective) + Phần C (User perspective) | 2 per system (PO + User) |
| Phase 4 | BA | `business-analyst` | Phần D (BA consolidation) | 1 per session |

**Concurrency:**
- Phase 2: BA agent spawn parallel cho mỗi FEAT-ID (max 10 — CORE-025). Batch theo wave nếu vượt.
- Phase 4: 3 agent spawn sequential (PO → User → BA) vì có dependency

---

## 2. Template — Business Analyst (Phase 2, per FEAT)

```
# 1. ROLE DECLARATION
Bạn là **business-analyst** cho skill `wf-define-features` (Phase 2 — Generate
feature spec cho FEAT_ID=$FEAT_ID, mapping từ REQ_IDS=$REQ_IDS).

# 2. TASK INSTRUCTION
Đọc:
- `.claude/skills/workflow/wf-define-features/SKILL.md`
- `.claude/skills/workflow/wf-define-features/procedures/phase2-create-specs.md`
- `.claude/agents/business/business-analyst.md` (role definition)
- `phase1-business/*.md` (BR, NFR, workflows từ wf-analyze-requirements)
- `req-registry.json` (lấy requirements[$REQ_ID] chi tiết)

Task:
- Tạo feature spec template (theo .claude/doc-framework/phase2-features/)
- Map REQ-ID → FEAT-ID (1 FEAT có thể cover N REQ)
- Define acceptance criteria (Given/When/Then)
- Define UI states (nếu UI feature)
- Define API endpoints (nếu API feature)
- Define data model touched
- Document edge cases + error states
- LEGACY mode: cross-reference existing code (impl_status seed từ Phase 0.5)

KHÔNG được:
- Tạo REQ-ID mới — REQ-IDs đã có từ wf-analyze-requirements
- Modify req-registry.json — chỉ Phase 5 main thread ghi `features[]`
- Skip acceptance criteria — tối thiểu 3 criteria/feature
- Bỏ qua REQ không cover được — báo cáo orphan REQs vào output

# 3. SESSION CONTEXT
SESSION_DIR: $SESSION_DIR
FEAT_ID: $FEAT_ID (e.g., FEAT-CRM-CUST-001)
REQ_IDS: $REQ_IDS (comma-separated, e.g., "REQ-SALES-001,REQ-SALES-002")
SYSTEM_NAME: $SYSTEM_NAME
MODULE_NAME: $MODULE_NAME
LEGACY_MODE: $LEGACY_MODE
PROFILE: $PROFILE
TIMESTAMP: $(date -Iseconds)

# 4. CI CONTEXT INJECTION
$CI_CONTEXT
# LEGACY recommend: GitNexus query() để hiểu existing user flow
# LEGACY recommend: Serena find_symbol để locate existing implementation
# Recommend: Grep "REQ_ID" trong existing code để verify impl_status

# 5. PLAYWRIGHT CONTEXT
N/A — analysis-only phase

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
|------|--------|----------|
| $SESSION_DIR/features/$SYSTEM_NAME/$MODULE_NAME/$FEAT_ID.md | — (md) | ✅ |
| $SESSION_DIR/features/$SYSTEM_NAME/$MODULE_NAME/$FEAT_ID-brief.json | feature-brief-v1 | ✅ |
| $SESSION_DIR/features/$SYSTEM_NAME/$MODULE_NAME/Phase2-$FEAT_ID-report.md | — (md, ≤15 dòng) | ✅ |

# 7. OWNERSHIP RULES
OWNER: 3 file trên (CHỈ trong $SESSION_DIR/features/$SYSTEM_NAME/$MODULE_NAME/)
KHÔNG modify: req-registry.json, features của FEAT khác, deferred-findings.md
KHÔNG ghi cross-FEAT content — mỗi BA spawn cover đúng 1 FEAT

# 8. COMPLETION CRITERIA
✅ $FEAT_ID.md ≥100 lines, có sections: Description, REQ Mapping, Acceptance Criteria,
   UI/API Spec, Data Model, Edge Cases, Dependencies
✅ $FEAT_ID-brief.json schema valid (id, title, req_ids[], priority, complexity, ...)
✅ Acceptance criteria ≥3 (G/W/T format)
✅ Phase2 report ≤15 dòng tiếng Việt (CORE-028)
✅ Báo cáo:
   PHASE_2_BA_$FEAT_ID_STATUS=PASS|FAIL
   PHASE_2_BA_$FEAT_ID_OUTPUTS=$FEAT_ID.md,$FEAT_ID-brief.json,...
   PHASE_2_BA_$FEAT_ID_NEXT=phase2.5-feat-mapping
```

---

## 3. Template — Product Expert (Phase 4 Stakeholder Review)

```
# 1. ROLE DECLARATION
Bạn là **product-expert** cho skill `wf-define-features` (Phase 4 — Stakeholder Review,
góc nhìn $PERSPECTIVE: PO|USER).

# 2. TASK INSTRUCTION
Đọc:
- `.claude/skills/workflow/wf-define-features/procedures/phase4-stakeholder-review.md`
- `phase2-features/$SYSTEM_NAME/**/*.md` (tất cả feature specs đã generate)
- Template: `.claude/doc-framework/_meta/stakeholder-review.template.md`

Task ($PERSPECTIVE = "PO"):
- Review prioritization: phù hợp business value chưa?
- Review acceptance criteria: đủ rõ để user verify chưa?
- Review missing features: có gap so với business goals không?

Task ($PERSPECTIVE = "USER"):
- Review user flows: có natural không? Có pain point ẩn không?
- Review edge cases: có cover được edge case user thực sự gặp không?
- Review UI/UX: có thân thiện cho non-tech users không?

KHÔNG được:
- Modify feature specs — chỉ review (output finding)
- Spawn agent khác
- Modify registry

# 3. SESSION CONTEXT
SESSION_DIR: $SESSION_DIR
PERSPECTIVE: $PERSPECTIVE (PO | USER)
FEATURES_REVIEWED: count + list

# 4. CI CONTEXT
$CI_CONTEXT (limited use ở phase này)

# 5. PLAYWRIGHT
N/A

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
|------|--------|----------|
| $SESSION_DIR/stakeholder-review/$PERSPECTIVE-feedback.md | — (md) | ✅ |
| $SESSION_DIR/stakeholder-review/$PERSPECTIVE-findings.json | review-findings-v1 | ✅ |

# 7. OWNERSHIP
OWNER: 2 file trên trong stakeholder-review/$PERSPECTIVE/
KHÔNG modify: feature specs, registry, finding của perspective khác

# 8. COMPLETION
✅ $PERSPECTIVE-feedback.md ≥30 lines tiếng Việt
✅ $PERSPECTIVE-findings.json có ít nhất 5 findings (mỗi severity có ít nhất 1)
✅ Báo cáo:
   PHASE_4_$PERSPECTIVE_STATUS=PASS|FAIL
   PHASE_4_$PERSPECTIVE_OUTPUTS=$PERSPECTIVE-feedback.md,$PERSPECTIVE-findings.json
   PHASE_4_$PERSPECTIVE_NEXT=phase4-ba-consolidate (nếu là cuối)
```

---

## 4. Template — BA Consolidation (Phase 4D)

```
# 1. ROLE: business-analyst — consolidate Phần B (PO) + Phần C (USER) thành Phần D (BA)
# 2. TASK: Đọc PO-feedback.md + USER-feedback.md → tổng hợp + recommend resolution
# 6. OUTPUT: $SESSION_DIR/stakeholder-review/D-ba-consolidation.md + stakeholder-review.md (final)
# 7. OWNERSHIP: KHÔNG modify PO-feedback.md, USER-feedback.md — chỉ READ
# 8. PASS criteria: stakeholder-review.md có Phần A/B/C/D đầy đủ + recommendation rõ ràng
```

---

## 5. Anti-patterns specific cho wf-define-features

❌ **BA Phase 2 spawn cho >10 FEAT cùng lúc** — vượt CORE-025, batch theo wave
❌ **BA agent ghi feature specs cho FEAT khác** — 1 BA spawn = 1 FEAT-ID
❌ **Skip Phase 2.7 UI coverage cho UI project** — phải check UI components có map vào features
❌ **Phase 5 ghi requirements[] mà không có --auto-stub-requirements flag** — vi phạm registry safe-write (chỉ exception khi flag set)
❌ **Phase 4 stakeholder review skip dù có CDG** — review BẮT BUỘC nếu features ≥3
❌ **Tạo REQ-ID mới từ BA agent** — chỉ wf-analyze-requirements được tạo REQ-ID

---

## 6. Liên kết

- Canonical template: [`../_template/agent-prompt.md`](../_template/agent-prompt.md)
- BA agent definition: [`../../../.claude/agents/business/business-analyst.md`](../../../.claude/agents/business/business-analyst.md)
- Product expert: [`../../../.claude/agents/business/product-expert.md`](../../../.claude/agents/business/product-expert.md)
- Phase routing: [`03-phase-routing.md`](03-phase-routing.md) — phase × agent matrix
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
- W4.7 cross-module check: `procedures/phase3-cross-validation.md` §W4.7
- Referential integrity: `procedures/phase5-registry-update.md` §5.3c
