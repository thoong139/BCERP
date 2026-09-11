# 06 — Templates List (wf-cmi)

> **Mục đích file:** Danh sách 13 templates skill dùng để tạo output files. Tuân thủ CORE-031 (mọi output từ template).

---

## 1. Bảng templates

| #  | Template path                          | Output target                                                   | Fields populate                                                                                                                                                                                   | Schema                                   |
| -- | -------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| 1  | `templates/integrity-status.json`    | `$SESSION_DIR/integrity-status.json`                          | session_id, scope, profile, dims_active, current_phase, phases_completed, next_action, context_budget_used_pct, lane_status, ci_context, checkpoint_at, lock_owner_pid, lock_heartbeat_at, author | `integrity-status-v1`                  |
| 2  | `templates/entity-graph.json`        | `$SESSION_DIR/phase2-discovery/entity-graph.json`             | nodes[], edges[], metadata (build_at, module_filter)                                                                                                                                              | `entity-graph-v1`                      |
| 3  | `templates/module-graph.json`        | `$SESSION_DIR/phase2-discovery/module-graph.json`             | nodes (modules), edges (dependencies), metadata                                                                                                                                                   | `module-graph-v1`                      |
| 4  | `templates/workflow-graph.json`      | `$SESSION_DIR/phase2-discovery/workflow-graph.json`           | workflows[], start_states, end_states, transitions, metadata                                                                                                                                      | `workflow-graph-v1`                    |
| 5  | `templates/api-graph.json`           | `$SESSION_DIR/phase2-discovery/api-graph.json`                | endpoints[], request_schemas[], response_schemas[], client_routing (erp-web/mobile-customer/mobile-staff)                                                                                         | `api-graph-v1`                         |
| 6  | `templates/event-graph.json`         | `$SESSION_DIR/phase2-discovery/event-graph.json`              | events[], producers[], consumers[], propagation_paths, broker_config (RabbitMQ + SignalR)                                                                                                         | `event-graph-v1`                       |
| 7  | `templates/rbac-matrix.json`         | `$SESSION_DIR/phase2-discovery/rbac-matrix.json`              | actors[], actions[], resources[], permissions[] (actor × action × resource), gaps[]                                                                                                             | `rbac-matrix-v1`                       |
| 8  | `templates/business-invariants.json` | `$SESSION_DIR/phase3-invariants/business-invariants.json`     | invariants[], cross_module_dependencies[], inferred_by, status, source_doc, verified_by, audit_chain                                                                                              | `business-invariants-v1`               |
| 9  | `templates/coverage-matrix.json`     | `$SESSION_DIR/phase5-aggregate/coverage-matrix.json`          | dimensions{CD1..CD10}, coverage_pct, violations_count, status, signals_file, overall_status, audit_chain                                                                                          | `coverage-matrix-v1`                   |
| 10 | `templates/regression-map.json`      | `$SESSION_DIR/phase6-regression/regression-map.json`          | changed_files[], predicted_impact (direct/transitive callers, affected_modules, affected_workflows, test_plan), confidence_threshold                                                              | `regression-map-v1`                    |
| 11 | `templates/integrity-report.md`      | `$SESSION_DIR/phase8-report/integrity-report.md`              | (markdown) summary, coverage table, top violations, gap suggestions, regression scope, recommendation                                                                                             | — (md ≤30 dòng tiếng Việt)          |
| 12 | `templates/coverage-report.md`       | `$SESSION_DIR/phase5-aggregate/coverage-report.md`            | (markdown) per-dim table, threshold status                                                                                                                                                        | — (md ≤15 dòng tiếng Việt CORE-028) |
| 13 | `templates/integrity-impact.json`    | `$SESSION_DIR/phase8-report/integrity-impact.json`            | scope, profile, coverage_matrix_summary, violations, regression_scope, gap_artifacts_suggested, consumers_recommended_actions, audit_chain (source/checksum/git_commit/git_branch/author)         | `integrity-impact-v1`                  |
| 14 | `templates/Phase{N}-report.md`       | `$SESSION_DIR/phase{N}-*/Phase{N}-report.md` × 8             | timestamp, summary, result, next_action (tiếng Việt)                                                                                                                                            | — (md ≤15 dòng)                       |
| 15 | `templates/signals.json`             | `$SESSION_DIR/phase4-coverage/lanes/CD{N}/signals.json` × 10 | lane, agent_subagent_type, scope, scan_duration_sec, signals[] (fingerprint, dim, severity, category, rule_id, message, affected_files, evidence, suggested_action)                               | `signals-v1`                           |
| 16 | `templates/gap-suggestions.json`     | `$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json`            | suggestions[] (kind, id, status, target, content, confidence, source)                                                                                                                             | `gap-suggestions-v1`                   |
| 17 | `templates/gap-report.md`            | `$SESSION_DIR/phase7-gap-cdg/gap-report.md`                   | (markdown) suggestion list per kind (test/contract/invariant), CDG decisions log                                                                                                                  | — (md ≤30 dòng tiếng Việt)          |
| 18 | `templates/regression-report.md`     | `$SESSION_DIR/phase6-regression/regression-report.md`         | (markdown) changed files, affected modules, test plan summary                                                                                                                                     | — (md ≤15 dòng tiếng Việt)          |

**Tổng:** 18 templates (13 JSON schemas + 5 markdown reports).

---

## 2. Metadata stripping rules (CORE-031.b)

Mọi template có metadata blocks ở đầu cần được **strip** trước khi write:

```yaml
# Template gốc (vd integrity-status.json header)
{
  "_schema_notes": {
    "purpose": "Pipeline state SSOT cho wf-cmi",
    "populate": ["session_id từ Phase 1 init", "..."]
  },
  "$schema": "integrity-status-v1",
  "session_id": "..."
}

# Sau khi populate + write → _schema_notes bị xóa
{
  "$schema": "integrity-status-v1",
  "session_id": "...",
  ...
}
```

Script tham chiếu: `.claude/scripts/strip-template-metadata.sh` (shared helper, sẽ dùng lại).

---

## 3. Template versioning

| Template                     | Version | Khi nào bump                                                   |
| ---------------------------- | ------- | --------------------------------------------------------------- |
| `integrity-status.json`    | v1.0    | Khi thêm/đổi field trong state SSOT                          |
| `entity-graph.json`        | v1.0    | Khi đổi node/edge structure                                   |
| `module-graph.json`        | v1.0    | Same                                                            |
| `workflow-graph.json`      | v1.0    | Khi đổi workflow detection logic                              |
| `api-graph.json`           | v1.0    | Khi support stack mới (vd FastAPI, Express)                    |
| `event-graph.json`         | v1.0    | Khi support broker mới                                         |
| `rbac-matrix.json`         | v1.0    | Khi đổi RBAC pattern detection                                |
| `business-invariants.json` | v1.0    | Khi đổi inference output format                               |
| `coverage-matrix.json`     | v1.0    | Khi đổi dim count (vd CD11)                                   |
| `regression-map.json`      | v1.0    | Khi predictive algorithm bump                                   |
| `integrity-impact.json`    | v1.0    | Khi consumers cần field mới                                   |
| `signals.json`             | v1.0    | Shared với wf-fix-bugs lane signals — coordinate version bump |
| `gap-suggestions.json`     | v1.0    | Khi thêm suggestion kind mới                                  |
| `Phase{N}-report.md`       | v1.0    | Khi đổi structure markdown                                    |
| `integrity-report.md`      | v1.0    | Khi đổi semantic                                              |
| `coverage-report.md`       | v1.0    | Khi đổi format                                                |
| `gap-report.md`            | v1.0    | Khi đổi suggestion presentation                               |
| `regression-report.md`     | v1.0    | Khi đổi format                                                |

**Quy tắc:**

- Bump major version (v1→v2) khi breaking change → consumer phải migrate
- Bump minor (v1.0→v1.1) khi add optional field
- Cross-skill artifacts (`integrity-impact.json`) version bump cần coordinate với 4 consumers

---

## 4. Validation cho output

Mọi output từ template phải pass T1→T4 validation (xem [04-file-contract.md](04-file-contract.md) §2).

### Validation snippets per template

**`integrity-status.json` (T2 structure):**

```bash
jq -e '.session_id and .scope and .profile and .current_phase and .phases_completed' integrity-status.json
```

**`business-invariants.json` (T3 content):**

```bash
jq -e '.invariants | length > 0' business-invariants.json
jq -e '.invariants[] | (.id and .kind and .expression and .source_doc and .severity)' business-invariants.json
```

**`coverage-matrix.json` (T2 structure):**

```bash
# Mọi active dim phải có coverage_pct (kể cả null cho SKIPPED)
jq -e '.dimensions | to_entries[] | (.value.coverage_pct != null or .value.status == "SKIPPED")' coverage-matrix.json
```

**`integrity-impact.json` (cross-skill — bắt buộc audit_chain):**

```bash
jq -e '.["$schema"] == "integrity-impact-v1" and .audit_chain.source and .audit_chain.checksum' integrity-impact.json
```

---

## 5. Template content samples

### `integrity-status.json` (template trước populate)

```json
{
  "_schema_notes": {
    "purpose": "SSOT pipeline state cho wf-cmi",
    "populate": [
      "session_id từ Phase 1 init",
      "scope từ args",
      "profile từ args (default standard)",
      "dims_active dựa profile activation matrix",
      "lane_status start với 'PENDING' cho mọi active lane"
    ],
    "delete_before_write": true
  },
  "$schema": "integrity-status-v1",
  "session_id": "PLACEHOLDER",
  "scope": {"type": "PLACEHOLDER", "modules": []},
  "profile": "PLACEHOLDER",
  "dims_active": [],
  "current_phase": 1,
  "phases_completed": [],
  "next_action": "phase1-init",
  "context_budget_used_pct": 0,
  "lane_status": {},
  "ci_context": {"gitnexus_available": false, "serena_available": false, "index_freshness": "unknown", "fallback_tool": null},
  "checkpoint_at": "PLACEHOLDER",
  "lock_owner_pid": 0,
  "lock_heartbeat_at": "PLACEHOLDER",
  "author": {"git_user_email": "PLACEHOLDER", "git_user_name": "PLACEHOLDER"}
}
```

### `Phase{N}-report.md` (template)

```markdown
<!--
_schema_notes:
  purpose: Phase report tiếng Việt cho người không chuyên (CORE-028)
  rules:
    - Max 15 dòng (bao gồm heading)
    - KHÔNG dùng jargon kỹ thuật thô
    - Có 4 fields: Đã làm, Kết quả, Tiếp theo, Lỗi (nếu có)
    - Vietnamese only, English chỉ cho REQ-ID/FEAT-ID/file path
  delete_before_write: true
-->
## Phase {N}: {Tên phase} — {PASS|WARN|FAIL}
Thời gian: {ISO 8601}

**Đã làm:** {1-2 câu mô tả những gì AI đã thực hiện}

**Kết quả:** {Số liệu chính (vd: 8 graph nodes, 45 invariants, 5 lanes PASS)} + {File đầu ra chính}

**Tiếp theo:** {Phase kế tiếp hoặc hành động user cần làm}

{Nếu FAIL/WARN:}
**Vấn đề:** {Mô tả ngắn lỗi cuối + error code}
**Cách xử lý:** {AI tự xử lý hoặc gợi ý cho user}
```

### `integrity-report.md` (template — chính, user-facing)

```markdown
<!--
_schema_notes:
  purpose: Báo cáo tổng hợp cuối session, cho người không chuyên đọc
  rules:
    - Max 30 dòng total
    - Có 6 sections: Tổng quan, Coverage 10 chiều, Top vi phạm, Đề xuất, Regression, Khuyến nghị
    - Tiếng Việt, có markdown link đến file detail
  delete_before_write: true
-->
# Báo cáo Cross-Module Integrity — {Session ID}

**Phạm vi:** {scope.type} — {modules}
**Profile:** {profile}
**Thời gian chạy:** {duration}
**Trạng thái:** {PASS|WARN|FAIL}

## 1. Coverage 10 chiều

| Chiều | % | Trạng thái |
|------|---|-----------|
| CD1 Business | {N}% | {PASS/FAIL_THRESHOLD/SKIPPED} |
| ... | ... | ... |

**Tổng coverage:** {overall_pct}% (ngưỡng profile {profile}: {threshold}%)

## 2. Vi phạm chính (top 5)

1. **{rule_name}** — {affected_modules} — [`{file}:L{line}`]({file}#L{line})
2. ...

## 3. Đề xuất ({N} artifacts)

- {N1} test case mới ([gap-suggestions.json](../phase7-gap-cdg/gap-suggestions.json))
- {N2} invariant rule
- {N3} API contract

## 4. Phạm vi regression

{N} files đổi từ {since_ref} → {M} module dự kiến ảnh hưởng — chi tiết [regression-map.json](../phase6-regression/regression-map.json)

## 5. Khuyến nghị

- {action 1 cho consumer wf-verify-sync/wf-fix-bugs/...}
- {action 2}

**File chi tiết:**
- [coverage-matrix.json](../phase5-aggregate/coverage-matrix.json)
- [business-invariants.json](../phase3-invariants/business-invariants.json)
- [integrity-impact.json](integrity-impact.json) (consume bởi 4 downstream skills)
```

---

## 6. Cross-skill template sharing

| Template                                      | Skill sharing                                                                                         | Coordination                                                                     |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `signals.json` (lane signals)               | wf-fix-bugs (QD1-QD11), wf-cmi (CD1-CD10)                                                             | Schema `signals-v1` SHARED — version bump phải coordinate cả 2 skills       |
| `Phase{N}-report.md`                        | Tất cả wf-* skills                                                                                  | Format `Phase{N}: {tên} — PASS                                                 |
| Cross-skill artifact `*-impact.json` family | wf-fix-bugs (`fix-impact.json`), wf-cmi (`integrity-impact.json`), wf-preflight, wf-manage-change | Tất cả phải có `$schema`, `audit_chain.source`, `audit_chain.checksum` |

---

## 7. Template directory structure

```
.claude/skills/workflow/wf-cmi/templates/
├── integrity-status.json
├── entity-graph.json
├── module-graph.json
├── workflow-graph.json
├── api-graph.json
├── event-graph.json
├── rbac-matrix.json
├── business-invariants.json
├── coverage-matrix.json
├── regression-map.json
├── integrity-impact.json
├── signals.json
├── gap-suggestions.json
├── Phase1-report.md
├── Phase2-report.md
├── ...
├── Phase8-report.md
├── integrity-report.md
├── coverage-report.md
├── gap-report.md
└── regression-report.md
```

**Total:** 13 JSON + 13 Markdown = 26 template files.

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031 (Template Usage Rule)
- Protocol: [`.claude/skills/protocols/19-template-usage.md`](../../../.claude/skills/protocols/19-template-usage.md)
- File contract: [04-file-contract.md](04-file-contract.md) §2 POST-GATE validation
- Cross-skill versioning: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §schema versioning
