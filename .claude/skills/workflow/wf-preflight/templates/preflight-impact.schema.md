# Schema: preflight-impact-v1

> **Version:** 1.0 (introduced wf-preflight v3.0.0)
> **Generator:** `.claude/scripts/wf-preflight/pf-impact-build.sh`
> **Template:** `templates/preflight-impact.json`
> **Output path:** `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/preflight-impact.json`
> **Consumer pattern:** OPT-IN via `--from-preflight[=<id>]` (ship v3.1+)

---

## Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema` | string | yes | Always `"preflight-impact-v1"` — version sentinel |
| `session_id` | string | yes | Session ID format: `{YYYY-MM-DD}-{scope-slug}-{NN}` |
| `scope.type` | string | yes | `"all"` \| `"system"` \| `"module"` \| `"feature"` |
| `scope.name` | string\|null | yes | Scope name (null khi type=all) |
| `verdict` | string | yes | `"PASS"` \| `"WARN"` \| `"FAIL"` |
| `scores.registry` | int\|null | no | 0-100. null nếu không chạy phase |
| `scores.docs` | int\|null | no | 0-100. null nếu không chạy phase |
| `scores.code_sync` | int\|null | no | 0-100. null nếu không có code được check |
| `scores.quality` | int\|null | no | 0-100. null nếu không có tooling |
| `scores.tests` | int\|null | no | 0-100. null nếu `--run-tests` không passed |
| `scores.overall` | int\|null | no | Weighted average (NULL redistribution applied) |
| `issues_by_category.critical` | int | yes | Số issues severity=critical |
| `issues_by_category.high` | int | yes | Số issues severity=high |
| `issues_by_category.medium` | int | yes | Số issues severity=medium |
| `issues_by_category.low` | int | yes | Số issues severity=low |
| `issues_by_category.total` | int | yes | Tổng tất cả issues |
| `issues[]` | array | yes | Danh sách issues (có thể rỗng nếu PASS) |
| `issues[].severity` | string | no | `"critical"` \| `"high"` \| `"medium"` \| `"low"` |
| `issues[].category` | string | no | Xem §Issue Categories bên dưới |
| `issues[].file` | string | no | Affected file path (relative to project root) |
| `issues[].message` | string | no | Human-readable issue description (tiếng Việt) |
| `issues[].fix_action_hint` | string | no | Suggested fix action cho user |
| `next_recommended_action` | string | no | Top suggestion cho user dựa trên verdict |
| `blocking_items` | string[] | no | Items preventing PASS verdict |
| `registry_changes` | object[] | no | Changes applied khi `--fix` chạy |
| `fix_applied` | bool | yes | True nếu `--fix` đã apply thành công |
| `tests_run` | bool | yes | True nếu `--run-tests` được passed |
| `audit_chain.registry_checksum_sha256` | string | yes | SHA256 của registry.json tại thời điểm generate |
| `audit_chain.report_checksum_sha256` | string | yes | SHA256 của preflight-report.md |
| `audit_chain.produced_at` | ISO string | yes | Generation timestamp |
| `audit_chain.by_skill_version` | string | yes | e.g. `"wf-preflight@3.0.0"` |

---

## Issue Categories

| Category | Mô tả | Phase nguồn |
|----------|-------|------------|
| `registry_syntax` | JSON invalid, required fields missing | Phase 2 |
| `registry_duplicate_id` | Duplicate REQ-ID / FEAT-ID | Phase 2 |
| `registry_invalid_ref` | Dangling cross-references | Phase 2 |
| `missing_doc` | Required phase docs không tồn tại | Phase 3 |
| `doc_empty` | Doc file tồn tại nhưng rỗng | Phase 3 |
| `code_orphan` | REQ done/in_progress nhưng không tìm thấy trong code | Phase 4 |
| `quality_fail` | Compile/lint errors | Phase 5 |
| `test_fail` | Test cases failed | Phase 5a |
| `cross_ref_mismatch` | Registry ↔ docs ↔ code inconsistency | Phase 5b |

---

## Verdict → next_recommended_action Mapping

| Verdict | Điều kiện | next_recommended_action |
|---------|-----------|------------------------|
| `FAIL` | critical > 0 | `"Sửa các vấn đề critical/high trước khi tiếp tục development"` |
| `FAIL` | overall < 60% | `"Kiểm tra toàn diện: registry, docs, code sync cần được cải thiện"` |
| `WARN` | high > 0 | `"Review và xử lý các vấn đề medium/high, sau đó tiếp tục"` |
| `PASS` | — | `"Sẵn sàng /wf-implement-feature hoặc /wf-prepare-deployment"` |

---

## Consumer Integration

### Resolve session ID (shared pattern)

```bash
# Nếu --from-preflight=<id>: dùng <id> trực tiếp
# Nếu --from-preflight (không có id): auto-discover
ID="${ARG:-$(tail -r .mc-data/work/wf-preflight/_index/sessions.jsonl 2>/dev/null \
  | grep '"status":"completed"' \
  | head -1 \
  | jq -r '.session_id')}"
IMPACT=".mc-data/work/wf-preflight/sessions/$ID/preflight-impact.json"
```

### wf-fix-bugs `--from-preflight[=<id>]` (ship v3.1+)

```bash
if [[ -f "$IMPACT" ]]; then
  VERDICT=$(jq -r '.verdict' "$IMPACT")
  CRITICAL=$(jq '.issues_by_category.critical' "$IMPACT")
  ISSUES=$(jq '.issues' "$IMPACT")
  # Truyền sang triage phase để phân loại nhanh hơn
fi
# File missing → no-op, behavior cũ giữ nguyên
```

### wf-prepare-deployment `--from-preflight[=<id>]` (ship v3.1+)

Go/No-Go gate: **BLOCK** (CDG) nếu:
- `verdict == "FAIL"`
- `issues_by_category.critical > 0`

```bash
if [[ -f "$IMPACT" ]]; then
  VERDICT=$(jq -r '.verdict' "$IMPACT")
  CRITICAL=$(jq '.issues_by_category.critical' "$IMPACT")
  if [[ "$VERDICT" == "FAIL" || "$CRITICAL" -gt 0 ]]; then
    echo "CDG: preflight FAIL — giải quyết critical issues trước khi deploy"
    # render CDG (Protocol 16)
  fi
fi
```

### wf-verify-sync `--from-preflight[=<id>]` (ship v3.1+)

Load `scores` + `verdict` → section "Trạng thái Preflight" trong verify report:

```bash
if [[ -f "$IMPACT" ]]; then
  VERDICT=$(jq -r '.verdict' "$IMPACT")
  OVERALL=$(jq '.scores.overall' "$IMPACT")
  # Thêm context section vào verify-sync report
fi
```

### Audit chain verification (tất cả consumers)

```bash
if [[ -f "$IMPACT" ]]; then
  REG_HASH=$(sha256sum .mc-data/docs/_meta/req-registry.json | awk '{print $1}')
  STORED_HASH=$(jq -r '.audit_chain.registry_checksum_sha256' "$IMPACT" | sed 's/^sha256://')
  if [[ "$REG_HASH" != "$STORED_HASH" ]]; then
    echo "WARN: registry thay đổi kể từ lần preflight cuối — kết quả có thể stale"
  fi
fi
```

---

## Backward Compatibility

- **File missing** → consumers silently skip (graceful no-op, behavior cũ giữ nguyên)
- **Schema version mismatch** → consumers log WARN, skip, proceed normally
- **`--from-preflight` không có `=<id>`** → auto-discover session mới nhất với `status="completed"` từ `_index/sessions.jsonl`
- **Producer failure** (pf-impact-build.sh fail) → log WARN, KHÔNG block POST-GATE

---

## Changelog

| Version | Change |
|---------|--------|
| 1.0 | Initial schema — wf-preflight v3.0.0 |
