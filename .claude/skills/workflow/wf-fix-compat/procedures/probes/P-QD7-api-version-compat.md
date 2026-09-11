# P-QD7-api-version-compat — API Version Compatibility Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD7-api-version-compat |
| **Loai** | static+runtime |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Kiem tra API version compatibility giua client va server. Phat hien version mismatches, breaking changes, va missing version headers. |
| **Cache** | **allowed** (static portion) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co API docs va khong co source code routes:
  Glob .mc-data/docs/phase3-architecture/**/api-*.md + src/**/route*.{ts,js}
  IF ca 2 tra 0 results:
    SKIP probe, note "skipped_no_api_artifacts"
```

## SENSE

### B1: Doc API version config

```bash
# Tim API versioning strategy trong code
VERSION_PATTERNS=(
  "api/v[0-9]"                        # URL path versioning /api/v1/
  "X-API-Version"                     # Header versioning
  "Accept: application/vnd.api"       # Content negotiation versioning
  "API_VERSION"                       # Env var versioning
  "apiVersion"                        # GraphQL schema versioning
  "version.*route"                     # Route-level versioning
)

for PATTERN in "${VERSION_PATTERNS[@]}"; do
  grep -rn "$PATTERN" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null || true
done
```

### B2: Doc API contract docs va compare

```bash
# Doc API specs tu phase3-architecture
API_DOCS=$(find .mc-data/docs/phase3-architecture/ -name "api-*.md" -o -name "API-*.md" 2>/dev/null)

# Extract version info tu docs
for DOC in $API_DOCS; do
  grep -iE "(version|v[0-9]|/api/v)" "$DOC" 2>/dev/null || true
done

# Doc req-registry.json cho impl_status cross-ref
jq -r '.requirements[] | select(.impl_status == "done") | .id' .mc-data/docs/_meta/req-registry.json 2>/dev/null
```

### B3: Check scan cache (neu --use-cache)

```bash
CACHE_KEY="api-version-$(find src/ -name 'route*' -o -name 'controller*' | sort | xargs cat | md5sum | cut -d' ' -f1)"
```

## THINK

1. **Version strategy detection**: Xac dinh project dung versioning nao (URL path, header, content negotiation)
2. **Version alignment check**:
   - Client code goi `/api/v1/...` nhung server chi co `/api/v2/...` → CRITICAL (breaking)
   - Server co `/api/v1/` va `/api/v2/` cho cung endpoint → check v1 co deprecated warning
   - API contract docs noi version 2 nhung code chi implement version 1 → HIGH
3. **Breaking change detection**:
   - Request/response schema thay doi giua versions
   - Required fields them/xoa giua versions
   - Enum values thay doi giua versions
4. **Cross-ref voi req-registry**:
   - Requirement impl_status=done nhung API endpoint khong co → HIGH
   - API endpoint ton tai nhung khong map requirement nao → LOW

## ACT

### Emit signals cho version compat issues

```json
{
  "probe_id": "P-QD7-api-version-compat",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-compat",
  "dimension_id": "QD7",
  "signal_type": "api_version_mismatch",
  "target": {
    "kind": "code",
    "file_path": "src/api/v1/customers/route.ts",
    "line_range": [1, 10]
  },
  "description": "Client su dung /api/v1/customers nhung server chi implement /api/v2/customers. Breaking change khong co fallback.",
  "evidence": {
    "client_calls": "grep: src/services/customer.ts:12: fetch('/api/v1/customers')",
    "server_routes": "grep: src/api/v2/customers/route.ts (chi co v2, khong co v1)"
  },
  "suggested_severity": "critical",
  "dedup_hints": ["api-version:/api/v1/customers"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-api-version-compat.json" << 'EOF'
{
  "$schema": "lane-signals-v1",
  "lane": "wf-fix-compat",
  "dimension": "QD7",
  "generated_at": "<ISO>",
  "signals": []
}
EOF
```

## VERIFY

- [ ] Moi Signal co `dimension_id = "QD7"`
- [ ] Moi Signal co `evidence` khong rong (it nhat 1 field)
- [ ] `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] `probe_id` match `^P-QD7-[a-z0-9-]+$`
- [ ] API path trong `description` match `target.file_path`
- [ ] `dedup_hints` chua api version key

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Client goi API version khong ton tai tren server | CRITICAL |
| API contract docs version khac code implementation | HIGH |
| Deprecated API version khong co migration guide | HIGH |
| Missing API version header tren versioned endpoints | MEDIUM |
| Minor version mismatch (<semver patch>) | LOW |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Khong co API artifacts | Skip probe, emit 0 signals |
| Parse error tren route files | Log warning per file, continue |
| Khong tim thay versioning strategy | INFO: assume single version, check breaking changes only |
