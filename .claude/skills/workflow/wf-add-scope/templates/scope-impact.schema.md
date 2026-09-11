# Schema: scope-impact-v1

> **Tạo bởi:** `/wf-add-scope` Phase 6 (sau Phase 4 success).
> **Template:** `templates/scope-impact.json`
> **Output path:** `$SESSION_DIR/scope-impact.json`
> **Builder:** `scripts/wf-add-scope/as-scope-impact-build.sh`
> **Consumers (opt-in):** `wf-verify-sync --from-add-scope`, `wf-preflight --from-add-scope`, `wf-implement-feature` (default scan N=3).

---

## Lifecycle

```
/wf-add-scope Phase 4 (append registry)
  → Phase 6 (build scope-impact.json)
  → [later] /wf-verify-sync --from-add-scope (opt-in)
  → [later] /wf-preflight --from-add-scope (opt-in)
  → [later] /wf-implement-feature Phase 0 (default scan, graceful skip nếu missing)
```

**READ-ONLY sau khi tạo.** Consumer skills KHÔNG được modify artifact này.

---

## Top-Level Fields

| Field | Type | Required | Mô tả |
|-------|------|----------|-------|
| `$schema` | string | ✅ | Phải là `"scope-impact-v1"` |
| `scope_id` | string | ✅ | Session ID — `{YYYY-MM-DD}-{sys-slug}` |
| `target_system` | string | ✅ | System ID từ registry (VD: `SYS-ERP-WEB`) |
| `mode` | string | ✅ | Execution mode: `from-mapping` \| `modules-list` \| `interactive` \| `from-scan` |
| `legacy_mode` | boolean | ✅ | `true` nếu dự án là legacy (CORE-021) |
| `timestamp` | string | ✅ | ISO 8601 UTC timestamp khi artifact được build |
| `registry_changes` | object | ✅ | Chi tiết thay đổi registry |
| `files_created` | string[] | ✅ | Relative paths của files đã tạo (feature stubs) |
| `audit_chain` | object | ✅ | Checksum + backup cho integrity verification |
| `consumer_hints` | object | ✅ | Structured hints cho 5 downstream consumers |

---

## registry_changes

| Field | Type | Mô tả |
|-------|------|-------|
| `modules_added` | string[] | Module IDs mới được APPEND vào registry |
| `modules_skipped` | `{id, reason}[]` | Modules không được thêm (already exists, deprecated, etc.) |
| `features_added_count` | integer | Số features APPEND vào registry |
| `features_skipped_count` | integer | Số features không được thêm |
| `modules_count_before` | integer | Tổng modules trong registry TRƯỚC append |
| `modules_count_after` | integer | Tổng modules SAU append |
| `features_count_before` | integer | Tổng features TRƯỚC append |
| `features_count_after` | integer | Tổng features SAU append |

**Validation rules:**
- `modules_count_after >= modules_count_before` (APPEND-ONLY, không delete)
- `features_count_after >= features_count_before` (APPEND-ONLY)
- `modules_added.length + modules_skipped.length` = tổng modules attempted

---

## audit_chain

| Field | Type | Mô tả |
|-------|------|-------|
| `checksum_pre` | string | SHA256 của registry TRƯỚC append (`sha256:<hex>`) |
| `checksum_post` | string | SHA256 SAU append — consumer dùng để verify integrity |
| `backup_path` | string | Path đến backup file (`req-registry.json.pre-addscope-<ts>`) |

**Consumer verification:**
```bash
# wf-verify-sync có thể verify integrity:
ACTUAL_CHECKSUM=$(sha256sum .mc-data/docs/_meta/req-registry.json | cut -d' ' -f1)
EXPECTED="$(jq -r '.audit_chain.checksum_post | ltrimstr("sha256:")' scope-impact.json)"
[[ "$ACTUAL_CHECKSUM" == "$EXPECTED" ]] || warn "Registry drift detected"
```

---

## consumer_hints

### wf-define-features

| Field | Type | Mô tả |
|-------|------|-------|
| `stubs_to_flesh` | string[] | Glob patterns của stub folders cần flesh-out (VD: `"sys-erp-web/**"`) |
| `total_stub_features` | integer | Tổng số feature stubs cần flesh-out |

**Tiêu thụ:** `/wf-define-features --from-scan` hoặc manual — AI biết ưu tiên modules nào cần flesh-out đầu tiên.

### wf-plan-modules

| Field | Type | Mô tả |
|-------|------|-------|
| `new_modules_to_plan` | string[] | Module IDs cần thêm vào implementation plan |
| `replan_recommended` | boolean | Luôn `true` — khi có module mới, plan cũ cần re-run |

### wf-annotate-code

| Field | Type | Mô tả |
|-------|------|-------|
| `new_modules_to_annotate` | string[] | Module IDs cần annotation (LEGACY_MODE chỉ) |

### wf-verify-sync

| Field | Type | Mô tả |
|-------|------|-------|
| `registry_changes_version` | string | Schema version (`"scope-impact-v1"`) |
| `cross_check_fields` | string[] | Fields cần cross-check khi `--from-add-scope` |

### wf-preflight

| Field | Type | Mô tả |
|-------|------|-------|
| `affected_files_count` | integer | Số files tạo mới (scope check) |
| `risk_level` | string | `"low"` \| `"medium"` \| `"high"` — theo features count |

**Risk level tính theo features:**
- `"low"` — features_added_count < 10
- `"medium"` — 10 ≤ features_added_count ≤ 30
- `"high"` — features_added_count > 30

---

## Backward Compatibility

- **v1.0:** Initial schema (released với wf-add-scope v3.0.0)
- **Future versions:** Additive fields only — không remove/rename existing fields
- **Consumer graceful degrade:** Nếu file missing OR `$schema` không khớp → no-op (không block)

```bash
# Consumer pattern (graceful):
if [[ -f "$IMPACT_FILE" ]] && jq -e '."$schema" == "scope-impact-v1"' "$IMPACT_FILE" >/dev/null 2>&1; then
  # Use consumer_hints
else
  # No-op — graceful skip
fi
```

---

## Ví dụ đầy đủ

```json
{
  "$schema": "scope-impact-v1",
  "scope_id": "2026-04-29-sys-erp-web",
  "target_system": "SYS-ERP-WEB",
  "mode": "from-mapping",
  "legacy_mode": true,
  "timestamp": "2026-04-29T10:45:00Z",
  "registry_changes": {
    "modules_added": ["MOD-ERPWEB-CRM", "MOD-ERPWEB-ORDERS"],
    "modules_skipped": [{"id": "MOD-ERPWEB-OLD", "reason": "already_exists"}],
    "features_added_count": 8,
    "features_skipped_count": 1,
    "modules_count_before": 5,
    "modules_count_after": 7,
    "features_count_before": 20,
    "features_count_after": 28
  },
  "files_created": [
    ".mc-data/docs/phase2-features/erp-web/crm/feat-customer-mgmt.md",
    ".mc-data/docs/phase2-features/erp-web/orders/feat-order-create.md"
  ],
  "audit_chain": {
    "checksum_pre": "sha256:abc123...",
    "checksum_post": "sha256:def456...",
    "backup_path": ".mc-data/docs/_meta/req-registry.json.pre-addscope-1745900000"
  },
  "consumer_hints": {
    "wf-define-features": {"stubs_to_flesh": ["erp-web/**"], "total_stub_features": 8},
    "wf-plan-modules": {"new_modules_to_plan": ["MOD-ERPWEB-CRM", "MOD-ERPWEB-ORDERS"], "replan_recommended": true},
    "wf-annotate-code": {"new_modules_to_annotate": ["MOD-ERPWEB-CRM"]},
    "wf-verify-sync": {"registry_changes_version": "scope-impact-v1", "cross_check_fields": ["registry_changes.modules_added", "files_created"]},
    "wf-preflight": {"affected_files_count": 2, "risk_level": "low"}
  }
}
```
