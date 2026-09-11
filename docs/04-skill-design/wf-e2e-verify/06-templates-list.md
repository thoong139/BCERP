# 06 — Templates List

> **Mục đích file:** 4 orchestrator templates + per-sub-skill template duplication strategy.

---

## 1. Orchestrator templates

| # | Template path | Output target | Required | Schema |
|---|--------------|--------------|----------|--------|
| 1 | `templates/e2e-status.template.json` | `$SESSION_DIR/e2e-status.json` | ✅ | `e2e-status-v1` |
| 2 | `templates/orchestrator-summary.template.md` | `$SESSION_DIR/orchestrator-summary.md` | ✅ | (markdown) |
| 3 | `.claude/doc-framework/_meta/phase-summary.template.md` (canonical) | `$SESSION_DIR/phase-summary.md` | ✅ | (markdown, CORE-028) |
| 4 | (inline, no template file) | `$SESSION_DIR/session-log.json` (APPEND) | ✅ | (JSONL) |
| 5 | (inline, no template file) | `$SESSION_DIR/error-ledger.json` (APPEND) | conditional | (JSONL) |

---

## 2. Per-phase template usage

| Phase | Template(s) READ | Output |
|-------|------------------|--------|
| Init | `e2e-status.template.json` | `$SESSION_DIR/e2e-status.json` initial |
| Each step transition | (no template — atomic jq update) | `e2e-status.json` UPDATE |
| Finalize | `orchestrator-summary.template.md` + canonical `phase-summary.template.md` | `orchestrator-summary.md` + `phase-summary.md` |
| Error logging | (inline) | `error-ledger.json` APPEND |
| Trace | (inline) | `session-log.json` APPEND |

---

## 3. Per-sub-skill template duplication (CORE-031.c)

**Pattern:** Mỗi sub-skill F0-F8 có templates riêng — KHÔNG share với orchestrator. Lý do: self-contained, không phụ thuộc orchestrator templates.

| Sub-skill | Templates | Output |
|-----------|-----------|--------|
| F0 `wf-e2e-infra-check` | `templates/infra-blockers.template.json` | `infra-blockers.json` |
| F0a `wf-e2e-finding` | 8 templates (business-rules, db-schema, api-contracts, ui-flows, cross-module-gaps, seed-requirements, test-scenarios, edge-cases) + 4 SSOT JSON templates | `findings/` + 4 SSOT JSONs |
| F0b `wf-e2e-seed-manifest` | `templates/seed-manifest.template.json` | seed manifest |
| F1 `wf-e2e-test` | `templates/test-scenario.template.md`, `templates/user-guide.template.md`, db/api/ui/integration report templates | outputs/ + 4 SSOT JSON APPEND |
| F2 `wf-e2e-browser` | `templates/browser-test-report.template.md` | `browser-test-report.md` |
| F3 `wf-e2e-unblock` | `templates/unblock-report.template.md` | `unblock-report.md` |
| F4 `wf-e2e-implement` | `templates/impl-log.template.json` | `impl-log.json` |
| F5 `wf-e2e-retest` | `templates/retest-log.template.md` | `retest-log.md` |
| F6 `wf-e2e-fix` | `templates/fix-log.template.json` | `fix-log.json` |
| F7 `wf-e2e-scenario` | `templates/scenario-test-report.template.md` | `scenario-test-report.md` |
| F8 `wf-e2e-demo` | `templates/demo-report.template.md` | `demo-report.md` |

**Total:** 4 orchestrator templates + ~25 sub-skill templates = ~29 templates trong toàn bộ E2E pipeline.

---

## 4. Metadata stripping rules (CORE-031.b)

Mọi template có metadata blocks ở đầu cần được **strip** trước khi write:

```yaml
# Template gốc
_template_notes:
  ...
_schema_notes:
  ...

# Sau khi populate + write → 2 blocks này bị xóa
```

Orchestrator dùng helper inline trong `_shared.md` §strip_metadata().

---

## 5. Template versioning

| Template | Version | Khi nào bump |
|----------|---------|--------------|
| `e2e-status.template.json` | v1.0 | Khi đổi steps schema (vd thêm F9, F10) |
| `orchestrator-summary.template.md` | v1.0 | Khi đổi summary structure |
| `phase-summary.template.md` (canonical) | v1.0 | Khi đổi CORE-028 structure |

**Quy tắc:** Bump major version khi breaking change → sub-skills cần migrate state file.

---

## 6. Validation cho output

Mỗi output từ template phải pass T1→T4 validation (xem [04-file-contract.md](04-file-contract.md) §4).

### Special validations

- **e2e-status.json T3:** `jq -e '.steps | keys | length == 11'` (F0, F0a, F0b, F1-F8)
- **orchestrator-summary.md T2:** Có 5 sections: Summary / 8-Step Pipeline / SSOT Counters / Errors & Warnings / Next Steps
- **phase-summary.md T3:** Vietnamese language check, ≤15 dòng (CORE-028)

---

## 7. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031 (Template Usage Rule)
- Protocol: [`.claude/skills/protocols/19-template-usage.md`](../../../.claude/skills/protocols/19-template-usage.md)
- File contract: [04-file-contract.md](04-file-contract.md)
- Source templates: [`.claude/skills/workflow/wf-e2e-verify/templates/`](../../../.claude/skills/workflow/wf-e2e-verify/) (nếu tồn tại) + 11 sub-skill `templates/` directories
