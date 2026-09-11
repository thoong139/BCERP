# P-QD3-security-header-audit — HTTP Security Header Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-security-header-audit |
| **Loai** | static+runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Audit HTTP security headers: Content-Security-Policy (CSP), Strict-Transport-Security (HSTS), X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy. Static: grep header middleware/config patterns. Runtime: curl endpoints and inspect response headers. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-header-audit.md |

## PRE-GATE

```
IF khong co source code AND khong co BASE_URL:
  SKIP probe, note "skipped_no_source_and_no_base_url"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always — ADR-22 Rule 6)
IF profile == standard: chi static grep header config patterns
IF profile == deep: static grep + runtime curl endpoint check (single page)
IF profile == exhaustive: static grep + runtime scan multiple endpoints + security agent review
IF runtime component can chay: kiem tra $BASE_URL != null
```

## SENSE

### B1: Static analysis -- grep header config patterns

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-security-header-audit.json"
mkdir -p "$(dirname "$RAW_OUT")"

SCAN_FILES=$(find src/ -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \
  -o -name "*.go" -o -name "*.yaml" -o -name "*.yml" -o -name "*.conf" -o -name "*.json" \) \
  ! -path "*/node_modules/*" 2>/dev/null | head -50)

if [ -z "$SCAN_FILES" ] && [ -z "$BASE_URL" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-security-header-audit","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_and_no_base_url"}
EOF
  exit 0
fi

# --- Helmet / security middleware (Node.js) ---
grep -rnE 'helmet\s*\(|helmet\.|helmet\(' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.helmet_detected"

# --- CSP header config ---
grep -rnE '(contentSecurityPolicy|content.?security.?policy|"Content-Security-Policy"|"CSP"|csp\.)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.csp_config"

# CSP that uses 'unsafe-inline' or 'unsafe-eval' (weakens protection)
grep -rnE "(unsafe-inline|unsafe-eval)" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.csp_unsafe"

# --- HSTS header config ---
grep -rnE '(strictTransportSecurity|strict.?transport.?security|"Strict-Transport-Security"|hsts\s*\()' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.hsts_config"

# --- X-Frame-Options ---
grep -rnE '(xFrameOptions|x.?frame.?options|"X-Frame-Options"|frameguard)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.xframe_config"

# --- X-Content-Type-Options ---
grep -rnE '(xContentTypeOptions|"X-Content-Type-Options"|nosniff|noSniff)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.xcontent_config"

# --- Referrer-Policy ---
grep -rnE '(referrerPolicy|referrer.?policy|"Referrer-Policy"|referrerPolicy\s*\()' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.referrer_config"

# --- Permissions-Policy ---
grep -rnE '(permissionsPolicy|permissions.?policy|"Permissions-Policy"|featurePolicy)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.permissions_config"

# --- Django SecurityMiddleware (Python) ---
grep -rnE '(SecurityMiddleware|SECURE_HSTS_SECONDS|SECURE_SSL_REDIRECT|CSP_DEFAULT_SRC|SECURE_CONTENT_TYPE_NOSNIFF|SECURE_BROWSER_XSS_FILTER|X_FRAME_OPTIONS)' \
  --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.django_security"

### B2: Runtime header check (deep/exhaustive only)

```bash
if [ -n "$BASE_URL" ] && [ "$PROFILE" != "standard" ]; then
  # Curl main endpoint and extract response headers
  RESPONSE=$(curl -s -D - "$BASE_URL" -o /dev/null 2>/dev/null)
  if [ -n "$RESPONSE" ]; then
    echo "$RESPONSE" | grep -iE '^(content-security-policy|strict-transport-security|x-frame-options|x-content-type-options|referrer-policy|permissions-policy|access-control-allow-origin):' \
      | sed "s/://" | while IFS= read -r line; do
      HEADER=$(echo "$line" | cut -d: -f1 | tr -d ' ')
      VALUE=$(echo "$line" | cut -d: -f2- | xargs)
      echo "{\"header\":\"$HEADER\",\"value\":\"$VALUE\"}" >> "$RAW_OUT.headers_found"
    done
  fi

  # Check for missing headers
  for HEADER in "content-security-policy" "strict-transport-security" "x-frame-options" \
    "x-content-type-options" "referrer-policy" "permissions-policy"; do
    if ! echo "$RESPONSE" | grep -iq "^$HEADER:"; then
      echo "{\"header\":\"$HEADER\",\"status\":\"missing\"}" >> "$RAW_OUT.headers_missing"
    fi
  done
fi
```

### B3: Cache check

Cache allowed for static grep (1h TTL). Runtime NEVER cached.

## THINK

Phan tich security headers theo 3 muc do:

1. **PRODUCTION-REQUIRED headers (missing = HIGH):**
   - `Strict-Transport-Security` (HSTS) -- prevents downgrade attacks
   - `Content-Security-Policy` (CSP) -- prevents XSS and data injection
   - `X-Content-Type-Options: nosniff` -- prevents MIME sniffing

2. **PRODUCTION-RECOMMENDED headers (missing = MEDIUM):**
   - `X-Frame-Options: DENY/SAMEORIGIN` -- prevents clickjacking
   - `Referrer-Policy: strict-origin-when-cross-origin` -- controls referrer leakage
   - `Permissions-Policy` -- restricts browser API access

3. **CSP quality:**
   - CSP with `unsafe-inline` or `unsafe-eval` = weakened protection (MEDIUM)
   - CSP without `script-src` or `default-src` = incomplete protection (MEDIUM)
   - No CSP = HIGH

**CDG flags:** Chi CRITICAL signals (full CSP missing on production endpoints) co CDG flag.
**No CDG for MEDIUM/LOW signals.**

**MITRE ATT&CK mapping:**
- Missing HSTS -> T1557.001 (Man-in-the-Middle: SSL Stripping)
- Missing CSP -> T1059.007 (XSS via no CSP)
- Missing X-Frame-Options -> T1204.001 (Clickjacking)
- Missing X-Content-Type-Options -> T1036.005 (MIME confusion)

## ACT

Static + runtime results aggregate thanh signals theo schema `signal-v2`:
- `signal_id` format: `HEADER-{name}-{action}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: [] (no CDG for MEDIUM/HIGH headers)
- `evidence[].type`: "grep_match" hoac "http_response_header"
- `remediation.suggested_agent`: "devops" hoac "backend-developer"

SKILL.md emit signals qua signal-emit.md helper voi lock + dedup.

## VERIFY

1. Runtime missing headers signal co `evidence[].type == "http_response_header"`
2. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
3. Static signals co `target.file_path` va `target.line_range`
4. Runtime signals co header name va observed value
5. CACHING: static co cache TTL (1h), runtime khong cache
6. Moi signal co `remediation.suggested_action` non-empty

## Severity Rules

| Header | Trang thai | Severity | CDG | MITRE ATT&CK |
|--------|-----------|----------|-----|--------------|
| Content-Security-Policy | Missing | HIGH | -- | T1059.007 |
| Content-Security-Policy | unsafe-inline/unsafe-eval | MEDIUM | -- | T1059.007 |
| Strict-Transport-Security | Missing | HIGH | -- | T1557.001 |
| X-Frame-Options | Missing | MEDIUM | -- | T1204.001 |
| X-Content-Type-Options | Missing | MEDIUM | -- | T1036.005 |
| Referrer-Policy | Missing | MEDIUM | -- | T1557.001 |
| Permissions-Policy | Missing | MEDIUM | -- | T1204.001 |
| Helmet/security middleware | Not found in code | HIGH | -- | N/A (config gap) |
| Multiple production headers missing | >=3 required headers | HIGH | -- | N/A (cumulative) |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No source code, no BASE_URL | Skip probe, `skip_reason: "no_source_and_no_base_url"` |
| Static cache hit (1h TTL) | Emit cached static signals, note "static_from_cache" |
| BASE_URL khong co (runtime) | Chi static grep, skip runtime, note "runtime_skipped_no_base_url" |
| curl khong available | Skip runtime test, note "runtime_skipped_no_curl" |
| Endpoint tra ve non-200 (redirect, auth) | Ghi nhan "endpoint_blocked", headers khong the verify |
| Khong co header config pattern nao trong code | Emit WARNING: "no_header_config_found" -- co the deploy thieu security headers |

