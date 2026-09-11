# error-ledger.json — Schema & Constraints (v4.0+)

> Per-session error ledger — replace + extend `impl-status.warnings[]`.
> Append-only. Tạo lazy-init: chỉ ghi lần đầu khi có error đầu tiên (`log_error()` helper).
> Skill code dùng `log_error()` trong `implement-common.sh` — KHÔNG ghi tay.

---

## Top-level fields

| Field | Type | Allowed values | Required |
|-------|------|----------------|----------|
| `$schema` | string | `"error-ledger-v1"` | yes |
| `schema_version` | string | `"1.0"` (literal) | yes |
| `session_id` | string | Format `{YYYY-MM-DD}-{HHMMSS}-{shorthost}` | yes |
| `feature_slug` | string | Vietnamese-safe slug | yes |
| `errors` | array | List of error entries (xem schema bên dưới) | yes |

---

## Error entry schema

| Field | Type | Allowed values | Required |
|-------|------|----------------|----------|
| `code` | string | Pattern `E[1-9][0-9]{2}` (namespaced E1xx-E9xx) | yes |
| `phase` | string | Phase identifier (e.g. `phase01-pattern-scan`, `phase07-tdd`, `phase10-finalize`) | yes |
| `severity` | enum | `info` \| `warning` \| `error` \| `critical` | yes |
| `message` | string | Human-readable description (Vietnamese OK) | yes |
| `context` | object | Free-form JSON metadata (e.g. `{module, batch, file, ...}`) | yes (default `{}`) |
| `ts` | string | ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) | yes |
| `auto_resolved` | bool | `true` nếu skill auto-fix thành công, `false` nếu chưa resolve | yes |
| `escalated_to_user` | bool | `true` nếu đã escalate qua user prompt | yes |
| `resolution` | string | Cách resolve (rỗng nếu chưa resolved) | yes (default `""`) |

---

## Severity → Action

| Severity | Behavior |
|----------|----------|
| `info` | Log only, no user notification |
| `warning` | Log + display in `phase-summary.md` |
| `error` | Log + retry up to 3 times, then escalate |
| `critical` | Log + immediate escalate (no retry) |

---

## Namespaced codes (v4.0)

Xem `procedures/_shared.md` § Error Codes Reference cho:
- Namespace table (E1xx-E9xx mapped sang phases)
- Backward compat alias (E001-E014 → namespaced equivalents)

---

## Validation (jq)

```bash
LEDGER=".mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/sessions/$SESSION_ID/error-ledger.json"

# T1 — schema_version
jq -e '.schema_version == "1.0"' "$LEDGER"

# T2 — required top-level fields
jq -e 'has("session_id") and has("feature_slug") and has("errors")' "$LEDGER"

# T3 — entry shape (each error has required fields)
jq -e '.errors | all(has("code") and has("phase") and has("severity") and has("ts"))' "$LEDGER"

# T4 — code pattern E[1-9][0-9]{2}
jq -e '.errors | all(.code | test("^E[1-9][0-9]{2}$"))' "$LEDGER"

# T5 — severity enum
jq -e '.errors | all(.severity | IN("info","warning","error","critical"))' "$LEDGER"
```

---

## Lazy-init pattern

`log_error()` tự khởi tạo file lần đầu:

```bash
if [[ ! -f "$ledger_file" ]]; then
  jq -nc --arg sid "$SESSION_ID" --arg fs "$FEATURE_SLUG" \
    '{"$schema":"error-ledger-v1",schema_version:"1.0",session_id:$sid,feature_slug:$fs,errors:[]}' \
    > "$ledger_file"
fi
```

Files vẫn không tồn tại nếu run hoàn hảo (zero errors) — phase-summary đọc graceful (treat as empty).

---

## Cap entries

`errors[]` capped tại 100 entries để tránh file phình quá lớn. Khi vượt:
- Truncate oldest entries (slice `.errors[-100:]`)
- Append warning entry: `code=E904`, `message="error-ledger truncated, oldest entries dropped"`

Logic này nằm trong `log_error()` — caller không cần handle.
