# Schema: verify-sync-impact-v1

> **Artifact:** `$SESSION_DIR/verify-sync-impact.json`
> **Producer:** `/wf-verify-sync` Phase 6 Step 6.8 (via `vs-impact-build.sh`)
> **Version:** v1 (shipped v3.0.0 — schema-only; consumers wired v3.1+)
> **Policy:** Additive-only — thêm fields mới, không rename/delete existing fields.

---

## Mục đích

`verify-sync-impact.json` là cross-skill artifact của `/wf-verify-sync`, cung cấp structured summary
về kết quả verify cho downstream consumers. Pattern tương tự `fix-impact.json` của `/wf-fix-bugs`
và `scope-impact.json` của `/wf-add-scope`.

---

## Field Reference

### Root Fields

| Field | Type | Mô tả |
|-------|------|-------|
| `$schema` | string | Schema identifier: `"verify-sync-impact-v1"` |
| `schema_version` | string | Redundant alias (backward compat): `"verify-sync-impact-v1"` |
| `session_id` | string | Session ID từ vs-generate-session-id.sh, VD: `"2026-05-03-all-01"` |
| `session_dir` | string | Relative path tới session directory |
| `generated_at` | string (ISO 8601) | Timestamp khi builder chạy (UTC) |
| `host` | string | Hostname của máy chạy (từ lock file hoặc `hostname`) |
| `user` | string | Username (từ lock file hoặc `whoami`) |

---

### `scope` Object

| Field | Type | Giá trị hợp lệ | Mô tả |
|-------|------|----------------|-------|
| `scope.type` | string | `"all"` \| `"system"` \| `"module"` | Scope của verify session này |
| `scope.name` | string \| null | — | Tên system/module khi type != all. `null` khi type=all |

---

### `verify_summary` Object

Tóm tắt kết quả verify từ `$SESSION_DIR/verify-sync-status.json`.

| Field | Type | Mô tả |
|-------|------|-------|
| `total_req_ids` | integer | Tổng số REQ-ID trong registry (trong scope) |
| `implemented` | integer | Số REQ-ID có code và impl_status=done |
| `in_progress` | integer | Số REQ-ID đang implement (impl_status=in_progress) |
| `not_started` | integer | Số REQ-ID chưa có code (impl_status=not_started) |
| `skipped` | integer | Số REQ-ID bị skip (impl_status=skipped) |
| `orphan_count` | integer | Số code files có REQ-ID không tồn tại trong registry |
| `sync_rate_pct` | number | % implemented / (total - skipped) × 100. Công thức: `implemented / (total - skipped) * 100` |
| `coverage_rate_pct` | number | % code files có REQ-ID hợp lệ / tổng code files |
| `verdict` | string | `"READY"` \| `"PARTIAL_FEATURES"` \| `"PARTIAL"` \| `"NOT_READY"` — xem Verdict Rules |

**Verdict Rules:**

| Verdict | Điều kiện |
|---------|-----------|
| `READY` | `sync_rate_pct >= 80` AND `not_started == 0` AND `features[].in_progress == 0` (tất cả features đã hoàn thành) |
| `PARTIAL_FEATURES` | `sync_rate_pct >= 80` AND (`not_started > 0` HOẶC `features[].in_progress > 0`) — sync rate đạt ngưỡng nhưng vẫn còn features chưa hoàn thành |
| `PARTIAL` | `sync_rate_pct >= 50` (và không thỏa READY hoặc PARTIAL_FEATURES) |
| `NOT_READY` | `sync_rate_pct < 50` |

---

### `warnings` Object

| Field | Type | Mô tả |
|-------|------|-------|
| `w001_count` | integer | Số W001 anomalies (REQ-ID trong registry không có code match) |
| `w001_anomalies` | string[] | Danh sách REQ-IDs gây W001. Từ `checkpoint.json data_snapshot.w001_anomalies` |
| `w002_count` | integer | Số W002 anomalies (code có REQ-ID nhưng không match status) |
| `w002_anomalies` | string[] | Danh sách REQ-IDs gây W002. Từ `checkpoint.json data_snapshot.w002_anomalies` |
| `w003_count` | integer | **(v3.1+)** Số W003 anomalies (REQ-ID có code và impl_status=done nhưng Feature cha chưa hoàn thành). Dùng để tính PARTIAL_FEATURES verdict. |
| `w003_anomalies` | string[] | **(v3.1+)** Danh sách REQ-IDs gây W003. Từ `checkpoint.json data_snapshot.w003_anomalies` |

---

### `registry_changes` Array

> **v3.0 NOTE:** Luôn là `[]` trong v3.0 — builder không capture before/after của registry update.
> v3.1+ sẽ wire Phase 6.3 để capture các thay đổi impl_status.

Mỗi entry khi được wire:

| Field | Type | Mô tả |
|-------|------|-------|
| `req_id` | string | REQ-ID được cập nhật |
| `field` | string | Tên field thay đổi (thường `"impl_status"`) |
| `before` | string | Giá trị trước khi update |
| `after` | string | Giá trị sau khi update |

---

### `ui_coverage` Object

Chỉ có data khi Phase 3 chạy (`interface_type != api-only`).

| Field | Type | Mô tả |
|-------|------|-------|
| `ran` | boolean | `true` nếu Phase 3 đã chạy |
| `total_screens` | integer | Tổng số screens trong UI specs |
| `matched` | integer | Số screens có code match. Tính: `floor(total_screens × coverage_pct / 100)` |
| `coverage_pct` | number \| null | % UI coverage. `null` nếu Phase 3 không chạy |

---

### `fix_log` Object

Chỉ có data khi Phase 4 chạy (`--fix` flag).

| Field | Type | Mô tả |
|-------|------|-------|
| `applied` | boolean | `true` nếu Phase 4 đã chạy với `--fix` |
| `files_fixed` | integer | Số files đã được auto-fix (thêm REQ-ID comment) |

---

### `next_recommended_action` Object

| Field | Type | Mô tả |
|-------|------|-------|
| `skill` | string | Skill được khuyến nghị chạy tiếp theo |
| `rationale` | string | Giải thích tại sao skill này phù hợp |
| `blocking_items` | string[] | REQ-IDs hoặc issues cần giải quyết trước |

**Recommendation Logic:**

| Verdict | Recommended Skill |
|---------|------------------|
| `READY` | `/wf-prepare-deployment` |
| `PARTIAL_FEATURES` | `/wf-implement-feature` (còn features chưa hoàn thành) hoặc `/wf-fix-bugs` (nếu có W001/W002 issues) |
| `PARTIAL` | `/wf-fix-bugs` (nếu có issues) hoặc `/wf-implement-feature` (nếu cần implement) |
| `NOT_READY` | `/wf-implement-feature` |

---

### `audit_chain` Object

| Field | Type | Mô tả |
|-------|------|-------|
| `checksum_sha256` | string | SHA-256 của toàn bộ JSON (trừ field này). Cross-platform: sha256sum, shasum, hoặc no-checksum |
| `data_sources` | string[] | Danh sách files đã đọc để build artifact này |

---

## Versioning và Backward Compatibility

- **v3.0.0 (current):** Schema-only. Consumers chưa wired.
- **v3.1+ (planned):** Wire consumers `/wf-prepare-deployment --from-verify-sync`, `/wf-fix-bugs --from-verify-sync`, `/wf-implement-feature --from-verify-sync`.
- **Additive-only policy:** Khi add field mới, tất cả consumers cũ ignore gracefully (unknown fields).
- **KHÔNG rename/delete fields** sau khi schema shipped — dùng deprecation notes thay.

---

## Consumer Integration (v3.1+ Planned)

```bash
# wf-prepare-deployment --from-verify-sync (Go/No-Go gate)
IMPACT_FILE=$(cat .mc-data/work/wf-verify-sync/_index/sessions.jsonl | ... | jq -r .session_dir)/verify-sync-impact.json
VERDICT=$(jq -r '.verify_summary.verdict' "$IMPACT_FILE")
if [[ "$VERDICT" == "NOT_READY" ]]; then
  echo "BLOCK: verify-sync verdict NOT_READY — cần implement thêm"
  exit 1
fi

# wf-fix-bugs --from-verify-sync (prioritize not_started)
NOT_STARTED_REQ=$(jq -r '.verify_summary.not_started' "$IMPACT_FILE")
W001_LIST=$(jq -r '.warnings.w001_anomalies[]' "$IMPACT_FILE")
```

---

## Ví dụ hoàn chỉnh

```json
{
  "$schema": "verify-sync-impact-v1",
  "schema_version": "verify-sync-impact-v1",
  "session_id": "2026-05-03-all-01",
  "session_dir": ".mc-data/work/wf-verify-sync/sessions/2026-05-03-all-01",
  "generated_at": "2026-05-03T16:15:30Z",
  "host": "DEV-A",
  "user": "alice",
  "scope": { "type": "all", "name": null },
  "verify_summary": {
    "total_req_ids": 100,
    "implemented": 82,
    "in_progress": 5,
    "not_started": 10,
    "skipped": 3,
    "orphan_count": 2,
    "sync_rate_pct": 83.67,
    "coverage_rate_pct": 88.0,
    "verdict": "PARTIAL"
  },
  "warnings": {
    "w001_count": 3,
    "w001_anomalies": ["REQ-FIN-003", "REQ-INV-007", "REQ-CRM-010"],
    "w002_count": 1,
    "w002_anomalies": ["REQ-CRM-005"],
    "w003_count": 2,
    "w003_anomalies": ["REQ-FIN-010", "REQ-INV-012"]
  },
  "registry_changes": [],
  "ui_coverage": {
    "ran": true,
    "total_screens": 25,
    "matched": 20,
    "coverage_pct": 80.0
  },
  "fix_log": { "applied": false, "files_fixed": 0 },
  "next_recommended_action": {
    "skill": "/wf-fix-bugs",
    "rationale": "Sync rate 83.67% PARTIAL — 10 REQ-IDs chưa implement. Khuyến nghị /wf-fix-bugs hoặc /wf-implement-feature.",
    "blocking_items": ["REQ-FIN-003", "REQ-INV-007"]
  },
  "audit_chain": {
    "checksum_sha256": "abc123def456...",
    "data_sources": [
      ".mc-data/work/wf-verify-sync/sessions/2026-05-03-all-01/verify-sync-status.json",
      ".mc-data/docs/_meta/req-registry.json"
    ]
  }
}
```
