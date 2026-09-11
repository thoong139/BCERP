# Schema: preflight-status-v3

> **Version:** 3.0 (introduced wf-preflight v3.0.0)
> **Template:** `templates/preflight-status.json`
> **Output path:** `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/preflight-status.json`
> **Previous version:** v2.0 (flat path `.mc-data/work/wf-preflight/preflight-status.json`)

---

## Field Reference

### Root Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | yes | `"3.0"` — versioning sentinel |
| `session_id` | string | yes | `{YYYY-MM-DD}-{scope-slug}-{NN}` (D1) |
| `run_id` | string | yes | ISO timestamp của run này |
| `host` | string | yes | Hostname tại thời điểm start |
| `user` | string | yes | OS username |
| `status` | string | yes | `"not_started"` \| `"in_progress"` \| `"completed"` \| `"error"` |
| `verdict` | string\|null | yes | `"PASS"` \| `"WARN"` \| `"FAIL"` \| null (khi in_progress) |
| `overall_score` | int\|null | yes | Weighted score 0-100 (null khi in_progress) |

### scope block

| Field | Type | Description |
|-------|------|-------------|
| `scope.type` | string | `"all"` \| `"system"` \| `"module"` \| `"feature"` |
| `scope.name` | string\|null | Scope name (null khi type=all) |

### flags block

| Field | Type | Description |
|-------|------|-------------|
| `flags.fix` | bool | True nếu `--fix` được passed |
| `flags.run_tests` | bool | True nếu `--run-tests` được passed |

### timestamps block

| Field | Type | Description |
|-------|------|-------------|
| `timestamps.started_at` | ISO string | Khi session bắt đầu (SI.7) |
| `timestamps.completed_at` | ISO string\|null | Khi phase 7 hoàn thành |
| `timestamps.duration_seconds` | int\|null | Tổng thời gian chạy |

### lock block (v3.0+ mới)

| Field | Type | Description |
|-------|------|-------------|
| `lock.heartbeat_pid` | int\|null | PID của pf-heartbeat.sh daemon (set ở SI.9) |
| `lock.acquired_at` | ISO string\|null | Khi lock acquire thành công |

### scores block

| Field | Type | Description |
|-------|------|-------------|
| `scores.registry` | int\|null | Phase 2 score (0-100) |
| `scores.docs` | int\|null | Phase 3 score (0-100) |
| `scores.code_sync` | int\|null | Phase 4 score (0-100) |
| `scores.quality` | int\|null | Phase 5 score (0-100) |
| `scores.tests` | int\|null | Phase 5a score (0-100) |

### phases block

| Field | Type | Description |
|-------|------|-------------|
| `phases.phase_N.status` | string | `"not_started"` \| `"completed"` \| `"skipped"` \| `"error"` |
| `phases.phase_N.started_at` | ISO\|null | Phase start time |
| `phases.phase_N.completed_at` | ISO\|null | Phase end time |

### checkpoint block

| Field | Type | Description |
|-------|------|-------------|
| `checkpoint.last_saved_at` | ISO\|null | Khi checkpoint cuối được ghi |
| `checkpoint.resume_from` | string\|null | Phase để resume từ đó |

### audit_chain block (v3.0+ mới)

| Field | Type | Description |
|-------|------|-------------|
| `audit_chain.registry_checksum` | string\|null | SHA256 của registry tại start time |
| `audit_chain.by_skill_version` | string | `"wf-preflight@3.0.0"` |

---

## Status Lifecycle

```
SI.7 (session-init) → status = "in_progress"
Phase 7.4           → status = "completed" (+ verdict + overall_score)
Error handler       → status = "error" (+ error_message)
```

---

## Migration từ v2.0 → v3.0

**v2.0 fields removed:**
- `run_id` (top-level) → renamed to `session_id` với format mới (D1)

**v3.0 fields added:**
- `schema_version = "3.0"`
- `session_id` (replaces old `run_id`)
- `host`, `user` — multi-developer visibility
- `lock.heartbeat_pid`, `lock.acquired_at`
- `audit_chain` block

**v2.0 flat path:** `.mc-data/work/wf-preflight/preflight-status.json`
**v3.0 session path:** `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/preflight-status.json`

Auto-migration via `pf-migrate-flat-to-sessions.sh` (D4 — idempotent).
