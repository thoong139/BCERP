# 06 — Templates List

> **Mục đích file:** Danh sách 15 templates skill dùng để tạo output files. Tuân thủ CORE-031 (mọi output từ template).

---

## 1. Bảng templates

| # | Template path | Output target | Required | Schema |
|---|--------------|--------------|----------|--------|
| 1 | `templates/impl-status.json` | `$SESSION_DIR/impl-status.json` | ✅ | `impl-status-v2` (schema_version 2.0) |
| 2 | `templates/impl-plan.md` | `$SESSION_DIR/impl-plan.md` | ✅ | (markdown) |
| 3 | `templates/impl-report.md` | `$SESSION_DIR/impl-report.md` | ✅ | (markdown) |
| 4 | `templates/checkpoint.json` | `$SESSION_DIR/checkpoint.json` | ✅ (từ Phase 3) | `checkpoint-v1` |
| 5 | `templates/qa-review-report.md` | `$SESSION_DIR/qa-review-attempt-[N].md` | ✅ | (markdown) |
| 6 | `templates/qa-review-report-annotation.md` | `$SESSION_DIR/qa-review-attempt-[N].md` | conditional | (markdown) — khi `$BATCH_TYPE == annotation_only` |
| 7 | `templates/decision-registry.json` | `$SESSION_DIR/decision-registry.json` | ✅ | `decision-registry-v1` (per-feature) |
| 8 | `templates/decision-registry-global.json` | `.mc-data/docs/_meta/decision-registry.global.json` | conditional | `decision-registry-v1` (cross-feature) |
| 9 | `templates/decision-registry-global.schema.md` | — (schema doc only) | — | (markdown) |
| 10 | `templates/existing-patterns.json` | `$SESSION_DIR/existing-patterns.json` | conditional | `existing-patterns-v1` — khi `$SCENARIO != "new"` |
| 11 | `templates/cdg-tokens.json` | `$SESSION_DIR/cdg-tokens.json` | conditional | `cdg-tokens-v1` — khi Registry write CDG-02/03/04 triggered |
| 12 | `templates/error-ledger.json` | `$SESSION_DIR/error-ledger.json` | conditional | `error-ledger-v1` — lazy-init (≥1 error logged) |
| 13 | `templates/error-ledger.schema.md` | — (schema doc only) | — | (markdown) |
| 14 | `templates/impl-status.schema.md` | — (schema doc only) | — | (markdown) |
| 15 | `templates/phase-summary.md` | `$SESSION_DIR/phase-summary.md` | ✅ | (markdown, CORE-028 tiếng Việt) |

---

## 2. Per-phase template usage

| Phase | Template(s) READ | Mục đích |
|-------|------------------|---------|
| 0a (Existing Analysis) | `existing-patterns.json` | Schema cho pattern scan output |
| 0.5 (Context Setup) | `decision-registry.json` | Per-feature decision tracking |
| 1 (Feature Context) | `impl-status.json` | Initialize pipeline state (schema v2.0) |
| 2 (Planning) | `impl-plan.md` | Task breakdown + batch plan |
| 3 (TDD) | `checkpoint.json` | Per-batch checkpoint at Phase 3.4 |
| 4-5 (Review-Fix) | `qa-review-report.md` (default) hoặc `qa-review-report-annotation.md` (Finding #23) | Review consolidation |
| 5a (Cross-validation) | `impl-report.md` | Validation results iterations |
| 6 (Finalize) | `impl-report.md` + `phase-summary.md` + `decision-registry-global.json` (conditional) | Final report + Vietnamese summary + cross-feature decisions append |

**Phase 6.1-CDG:** Khi registry write trigger CDG (Critical Decision Gate) → write `cdg-tokens.json` log.

**Error logging:** Bất kỳ phase nào — `ledger_log()` helper auto-init `error-ledger.json` khi có error đầu tiên.

---

## 3. Metadata stripping rules (CORE-031.b)

Mọi template có metadata blocks ở đầu cần được **strip** trước khi write:

```yaml
# Template gốc (impl-status.json, existing-patterns.json, ...)
_schema_notes:
  field_descriptions: ...
  populate_guide: ...
  required_fields: ...

# Sau khi populate + write → block _schema_notes bị xóa
```

Helper: `strip_metadata()` trong `implement-common.sh` xử lý cả `_template_notes`, `_schema_notes`, `_examples`.

---

## 4. Template versioning

| Template | Version | Khi nào bump |
|----------|---------|--------------|
| `impl-status.json` | v2.0 | Bumped v1→v2 ở Sprint 3 (thêm consumer_hints) |
| `checkpoint.json` | v1.0 | Khi đổi resume mechanism |
| `decision-registry.json` | v1.0 | Khi thêm field decision |
| `decision-registry-global.json` | v1.0 | Khi thay đổi cross-feature semantic |
| `existing-patterns.json` | v1.0 | Khi mở rộng pattern types |
| `error-ledger.json` | v1.0 | Khi thay đổi entry schema |
| `cdg-tokens.json` | v1.0 | Khi thêm CDG types |
| `qa-review-report.md` | v1.0 | Khi thay đổi review checklist (v5.1 thêm env safety/runtime safety/i18n) |
| `phase-summary.md` | v1.0 | Khi thay đổi consumer_hints reference |

**Quy tắc:** Bump MAJOR version khi breaking schema change → consumer (wf-prepare-deployment, wf-fix-bugs, wf-verify-sync) phải migrate.

---

## 5. Validation cho output

Mỗi output từ template phải pass T1→T4 validation (xem [04-file-contract.md](04-file-contract.md) §2).

### Special validations

- **impl-status.json T3:** `jq -e '.schema_version == "2.0" and .session_id and .feature_id and .consumer_hints'`
- **decision-registry.json T2:** `jq -e '.$schema == "decision-registry-v1" and (.decisions | type == "array")'`
- **phase-summary.md T3:** Vietnamese language check (CORE-028 — non-specialist readable)
- **error-ledger.json T2:** `jq -e '.errors | length <= 100'` (cap 100 entries)

---

## 6. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031 (Template Usage Rule)
- Protocol: [`.claude/skills/protocols/19-template-usage.md`](../../../.claude/skills/protocols/19-template-usage.md)
- File contract: [04-file-contract.md](04-file-contract.md)
- Source templates: [`.claude/skills/workflow/wf-implement-feature/templates/`](../../../.claude/skills/workflow/wf-implement-feature/templates/)
