# 09 — Evals & Test Cases

> **Mục đích file:** 6 evals match `evals/evals.json` v4.0.0.

---

## 1. Bảng test cases (6 evals)

| ID | Type | Mục đích |
|----|------|----------|
| TC-1 | integration | New project full run — 11 phases, registry safe-write `design_status`, digest STRIPPED |
| TC-2 | resume/LPM | LPM (Large Project Mode) multi-session resume — 6 systems, checkpoint per phase |
| TC-3 | legacy | LEGACY_MODE — Phase 7 Gap Analysis SEQUENTIAL, action-items.json STRIPPED |
| TC-4 | error | Chưa có `phase2-features/` → E002, STOP ngay |
| TC-5 | workload | Workload Gate block + CDG override (ADR-OPT-03) |
| TC-6 | cross-skill | `--from-scan=<id>` consume target-map.json baseline |

---

## 2. Test case detail (extract)

### TC-1 — New project full run

**Setup:** New project ERK Transport, 3 systems (CRM, SmartTax, EUREKA), 25 features in registry.

**Run:** `/wf-design`

**Expected:**
1. Phase 0: detect new mode, LPM=false (3 systems < 5 threshold)
2. Phase 1: 3 lanes parallel (architect per system, conditional ai-engineer cho EUREKA `$HAS_AI_ML`)
3. Phase 2: 3 lanes × 3 specs (api-contract + database-design + infra-spec) parallel
4. Phase 3: Signal Aggregation dual-dedup (`component_id` + `api_id`), 0 conflicts
5. Phase 4: 8 checks PASS 1 iteration
6. Phase 5: stakeholder review APPROVED (architect + security parallel)
7. Phase 6: Registry `design_status="completed"` cho 25 features
8. Phase 8: `_meta/design-input-digest.json` STRIPPED (no `_*` keys)

**Pass criteria:**
- All 4 technical-specs/*.md created
- Registry `design_status` updated cho 25 features (CORE-006 safe-write)
- `design-summary.json` valid
- `design-input-digest.json` không có `_*` keys (Template Strip)
- Phase 7 SKIPPED (new mode)

### TC-3 — LEGACY_MODE

**Setup:** LEGACY project với `module-code-mapping.json` đã extracted, 3 systems legacy + 2 new modules.

**Run:** `/wf-design` (auto-detect LEGACY)

**Expected:**
1. Phase 0: `$LEGACY_MODE=true` (project-context.md > 500 bytes)
2. Phase 1-5: Design với LEGACY injection, `[VERIFIED]/[INFERRED]/[RECOMMENDED]` labels
3. Phase 6: Registry updated (extended fields cho legacy: systems, modules, features, interface_type)
4. Phase 7: **SEQUENTIAL** Gap Analysis cross-ref `module-code-mapping.json`
5. Phase 7 outputs: `gap-report.md`, `gap-categories.json`, `action-items.json` STRIPPED

**Pass criteria:**
- Phase 7 KHÔNG lane-ify (single sequential)
- `action-items.json` valid JSON, schema `action-items-v1`, KHÔNG có `_*` keys
- `gap-report.md` có sections per system
- Registry legacy fields populated

### TC-5 — Workload Gate block + CDG override

**Setup:** Mega project (8 systems, 80 features) → ratio > 1.5 BLOCK.

**Run:** `/wf-design`

**Expected:**
1. Phase 0.5 ratio > 1.5 → BLOCK
2. AskUserQuestion Plan A (narrow scope) / Plan B (Override + CDG) / Cancel
3. User chọn Override → `cdg-tokens.json` với `cdg_id="CDG-A02-workload-override"`, decision="accept"
4. Skill continue với `lpm_mode=true` (auto)

### TC-6 — `--from-scan` cross-skill (Sprint 5)

**Setup:** Có existing scan session `20260515-100000-a1b2` với `target-map.json` đầy đủ (endpoints + entities).

**Run:** `/wf-design --from-scan=20260515-100000-a1b2`

**Expected:**
1. Phase 0 load `target-map.json`
2. Phase 1 architect agent prompt có `$CI_CONTEXT` chứa endpoints + entities từ scan
3. Architect KHÔNG re-design endpoints đã có trong code
4. Phase 7 Gap Analysis (nếu LEGACY) có baseline từ target-map

**Pass criteria:**
- Architect prompt log có scan context
- Output design có references tới existing endpoints
- KHÔNG modify behavior nếu flag absent (regression check)

---

## 3. Eval criteria

### Pass criteria

| Criteria | Threshold |
|----------|-----------|
| PRE-GATE/POST-GATE T1-T4 PASS | 100% |
| Registry `design_status` safe-write — chỉ field này | 100% |
| 7 conditional agents spawn đúng condition | 100% |
| Lane Dispatch parallel — 0 race condition | 100% |
| Phase 3 dual-dedup — 0 duplicate component/api | 100% |
| Phase 7 (LEGACY) SEQUENTIAL — không lane | 100% |
| Template Strip — canonical KHÔNG có `_*` | 100% |
| LPM multi-session resume idempotent | 100% |

### Fail criteria

| Criteria | Verdict |
|----------|---------|
| Registry `features[]` bị modify | FAIL |
| Registry `requirements[]` bị modify | FAIL |
| `_*` keys leak canonical | FAIL |
| Phase 7 lane-ify (LEGACY) | FAIL |
| Dual-dedup miss api duplicate | FAIL |

---

## 4. Coverage matrix

| | NEW | LEGACY | LPM | Single system |
|---|-----|--------|-----|---------------|
| **Standard** | TC-1 | TC-3 | — | (subset TC-1) |
| **LPM** | — | — | TC-2 | — |
| **Workload Gate** | TC-5 | — | TC-5 | — |
| **Cross-skill** | TC-6 | TC-6 | — | — |
| **Error** | TC-4 | — | — | — |

---

## 5. Eval execution

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-design --all
```

---

## 6. Liên kết

- Eval source: [`.claude/skills/workflow/wf-design/evals/evals.json`](../../../.claude/skills/workflow/wf-design/evals/evals.json)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7
- Review checklist: [`../../05-review-standards/wf-design.md`](../../05-review-standards/wf-design.md)
