# 06 — Templates List

> **Mục đích file:** 9 skill-local templates + 4 shared `_shared/templates/` + Template Strip pattern (ADR-OPT-05).

---

## 1. Skill-local templates (5)

| # | Template path | Output target | Schema |
|---|--------------|--------------|--------|
| 1 | `templates/analyze-status.json` | `sessions/{id}/analyze-status.json` + flat DUAL-WRITE | `analyze-status-v1` |
| 2 | `templates/analyze-plan.md` | `sessions/{id}/analyze-plan.md` + flat | (markdown) |
| 3 | `templates/checkpoint.json` | `sessions/{id}/checkpoint.json` + flat | `checkpoint-v1` (legacy backward-compat) |
| 4 | `templates/department-digests.json` | `sessions/{id}/department-digests.json` (working, pre-Phase 8c) | `dept-digests-v1` |
| 5 | `templates/phase1-handoff.json` | `sessions/{id}/phase1-handoff.json` (working) | `phase1-handoff-v1` |

---

## 2. Shared templates (`_shared/templates/`, 4)

| # | Template path | Output target | Schema |
|---|--------------|--------------|--------|
| 6 | `_shared/templates/session-state.json` | `sessions/{id}/session-state.json` | `session-state-v1` (ADR-OPT-02) |
| 7 | `_shared/templates/workload-report.md` | `sessions/{id}/workload-report.md` | (markdown, ADR-OPT-03) |
| 8 | `_shared/templates/lane-signal.json` | `sessions/{id}/lanes/{dept-key}/signals.json` | `lane-signal-v1` (ADR-OPT-01) |
| 9 | `_shared/templates/aggregation-result.json` | `sessions/{id}/aggregation-result.json` | `aggregation-result-v1` (ADR-OPT-04) |

---

## 3. Canonical digest templates (`_digests/`, schema docs only)

| Template path | Mục đích |
|--------------|---------|
| `.claude/doc-framework/_digests/dept-digests.template.json` | **Schema doc** — mô tả validation rules. KHÔNG dùng để tạo file. |
| `.claude/doc-framework/_digests/phase1-handoff.template.json` | **Schema doc** — tham khảo schema. |

**Quy ước:** Skill-local `templates/` = **starter files** (có placeholder values, dùng READ→POPULATE→WRITE). `_digests/` = **schema documentation** (mô tả field types, validation rules).

---

## 4. Per-phase template usage

| Phase | Template(s) READ | Output |
|-------|------------------|--------|
| 0 (Context) | `session-state.json` + `analyze-status.json` | sessions/{id}/session-state.json + analyze-status.json |
| 0.5 (Workload Gate) | `workload-report.md` | sessions/{id}/workload-report.md |
| 2 (Plan) | `analyze-plan.md` + `checkpoint.json` | sessions/{id}/analyze-plan.md + checkpoint.json (đầu tiên) |
| 4 (Lane Dispatch) | `lane-signal.json` (per lane) | sessions/{id}/lanes/{dept}/signals.json (×N) |
| 6 (Consolidate) | `aggregation-result.json` | sessions/{id}/aggregation-result.json |
| 8c (Handoff) | `department-digests.json` + `phase1-handoff.json` | sessions/{id}/* + canonical `_meta/dept-digests.json` + `_meta/phase1-handoff.json` (STRIPPED) |

---

## 5. Template Strip rules (ADR-OPT-05, CORE-031.b)

Mọi template có metadata blocks ở đầu cần được **strip** trước khi write canonical:

```yaml
# Template gốc (skill-local + _digests/)
_template_notes:
  description: "..."
  example: "..."
_comments:
  - "..."
_examples:
  - "..."
_placeholder:
  field: "..."

# Sau khi populate + STRIP → 4 blocks này bị xóa recursively
```

Helpers: `_shared/_shared.md §1 strip_template_metadata()` — walk JSON recursively, remove keys starting với `_`.

**Áp dụng:** Phase 8c bắt buộc strip trước khi ghi canonical `_meta/dept-digests.json` và `_meta/phase1-handoff.json`. Working artifacts (sessions/{id}/department-digests.json) có thể giữ helper keys (không leak).

---

## 6. Template versioning

| Template | Version | Khi nào bump |
|----------|---------|--------------|
| `analyze-status.json` | v1.0 | Khi thêm field tracking |
| `session-state.json` | v1.0 | Khi thay đổi phases schema |
| `lane-signal.json` | v1.0 | Khi thay đổi signal schema (items[] structure) |
| `aggregation-result.json` | v1.0 | Khi thay đổi dedup output structure |
| `dept-digests.json` | v1.0 | Khi thay đổi cấu trúc per-dept |
| `phase1-handoff.json` | v1.0 | Khi thay đổi handoff cho `wf-define-features` |

**Quy tắc:** Bump major version → consumer skill (`wf-define-features`) phải migrate.

---

## 7. Validation cho output

Mỗi output từ template phải pass T1→T4 validation (xem [04-file-contract.md](04-file-contract.md) §4).

### Special validations

- **session-state.json T3:** `jq -e '.phases | keys | length == 14'` (P0, P0_5, P1...P8c)
- **lane-signal.json T3:** `jq -e '.items | length > 0 and (.items[] | has("req_id"))'`
- **aggregation-result.json T3:** `jq -e '.total_output <= .total_input'` (dedup logic check)
- **dept-digests.json canonical T2:** KHÔNG có key bắt đầu với `_` (template strip check)

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031 (Template Usage Rule), ADR-OPT-05 (Template Strip)
- Protocol: [`.claude/skills/protocols/19-template-usage.md`](../../../.claude/skills/protocols/19-template-usage.md)
- File contract: [04-file-contract.md](04-file-contract.md) §8 (Atomic write + Template Strip)
- Source: [`.claude/skills/workflow/wf-analyze-requirements/templates/`](../../../.claude/skills/workflow/wf-analyze-requirements/templates/) + [`_shared/templates/`](../../../.claude/skills/workflow/_shared/templates/)
