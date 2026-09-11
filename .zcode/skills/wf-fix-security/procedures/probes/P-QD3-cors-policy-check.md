# P-QD3-cors-policy-check — CORS Policy Security Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-cors-policy-check |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Kiem tra CORS configuration: overly permissive origins (wildcard), credentials exposure voi wildcard, thieu CSRF protection, allowed methods qua rong. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-cors-check.md |

## PRE-GATE

```
IF khong co source code AND khong co BASE_URL:
  SKIP probe, note "skipped_no_source"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always — ADR-22 Rule 6)
IF profile == standard: chi static grep CORS config patterns
IF profile == deep: static grep + curl OPTIONS request neu BASE_URL available
IF profile == exhaustive: static grep + curl OPTIONS + multiple origin test headers
```

## SENSE

### B1: Static analysis — grep CORS config patterns

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-cors-policy-check.json"
mkdir -p "$(dirname "$RAW_OUT")"

# Check source code exists
SCAN_FILES=$(find src/ -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \
  -o -name "*.java" -o -name "*.go" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.conf" \) \
  ! -path "*/node_modules/*" 2>/dev/null | head -50)

if [ -z "$SCAN_FILES" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-cors-policy-check","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_files"}
EOF
  exit 0
fi

# --- Wildcard origin ---
grep -rnE '(Access-Control-Allow-Origin:\s*\*|allowOrigin.*\*|origins:\s*\[\s*"\*"\]|origin.*"\*")' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" \
  --include="*.yaml" --include="*.yml" --include="*.json" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|example|template)' \
  | head -20 > "$RAW_OUT.wildcard_origin"

# --- Credentials + wildcard (dangerous combination) ---
grep -rnE '(credentials.*true|allowCredentials.*true|supportsCredentials.*true)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' \
  | head -20 > "$RAW_OUT.credentials_true"

# --- Overly permissive allowed methods ---
grep -rnE '(Access-Control-Allow-Methods.*\*|allowMethods.*\*|allowedMethods.*\[.*"\*"|methods.*"\*")' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" \
  --include="*.yaml" --include="*.yml" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' \
  | head -10 > "$RAW_OUT.permissive_methods"

# --- Allowed headers too permissive ---
grep -rnE '(Access-Control-Allow-Headers.*\*|allowHeaders.*\*|allowedHeaders.*\[.*"\*")' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
  --include="*.yaml" --include="*.yml" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' \
  | head -10 > "$RAW_OUT.permissive_headers"


# --- CORS config from env file ---
grep -rnE '(CORS_ORIGIN|CORS_ALLOWED_ORIGINS|ALLOWED_ORIGINS|cors_allowed)' \
  --include="*.env*" --include="*.ts" --include="*.yaml" --include="*.yml" --include="*.json" \
  --include="*.conf" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.env\.example|\.env\.sample|README)' \
  | head -10 > "$RAW_OUT.cors_env_config"

# --- MaxAge CORS (preflight cache) ---
grep -rnE '(Access-Control-Max-Age|maxAge|corsMaxAge|cors_max_age)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.cors_maxage"

# --- Expose-Headers (may leak internal headers) ---
grep -rnE '(Access-Control-Expose-Headers|exposeHeaders|exposedHeaders)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.expose_headers"

# --- CORS middleware detection ---
grep -rnE '(cors\(|cors\(\)|useCors|enableCors|cors_options|CorsMiddleware)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.go" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.cors_middleware"

# --- Check for missing sameSite attribute alongside CORS ---
grep -rnE '(sameSite|same_site)' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -ivE '(node_modules|\.test\.|lax|strict)' \
  | head -10 > "$RAW_OUT.missing_samesite"

### B2: Runtime CORS check (deep/exhaustive only)
if [ -n "$BASE_URL" ] && [ "$PROFILE" != "standard" ]; then
  for ORIGIN in "https://evil.com" "https://attacker.io" "null"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS -H "Origin: $ORIGIN" "$BASE_URL/api/test" 2>/dev/null || echo "000")
    echo "{\"test\":\"preflight\",\"origin\":\"$ORIGIN\",\"status\":\"$HTTP_CODE\"}" >> "$RAW_OUT.cors_runtime"
  done
fi

### B3: Cache check
Cache allowed (1h TTL). Bash script co the goi cache_lookup truoc khi scan. Neu cache hit, emit cached signals.


## THINK

Phan tich CORS config theo cac nguy co:

1. **Wildcard origin + credentials:** `*` + `credentials: true` = CRITICAL. Any website read authenticated responses.

2. **Wildcard origin (no credentials):** MEDIUM. Reflects all origins, nhung khong kem credentials.

3. **Permissive methods/headers:** MEDIUM. Attacker use PUT/DELETE/PATCH or custom headers.

4. **Missing sameSite:** MEDIUM. CORS + thieu sameSite strict tang risk CSRF.

5. **No CORS middleware found:** HIGH. API co the khong co CORS protection.

**CDG flags:** Chi CRITICAL (wildcard + credentials) co CDG flag.

**MITRE ATT&CK mapping:**
- Wildcard + credentials -> T1557.001 (Man-in-the-Middle: Web Session Cookie)
- Permissive CORS -> T1204.001 (User Execution: Malicious Link)
- Missing CORS config -> T1190 (Exploit Public-Facing Application)

## ACT

Results aggregate thanh signals theo schema `signal-v2`:
- `signal_id` format: `CORS-{category}-{file_hash8}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: ["CDG-SECURITY-LIVE"] cho wildcard+credentials
- `evidence[].type`: "grep_match" hoac "http_response"
- `remediation.suggested_action`: "Specify explicit origins, do not use wildcard with credentials"
- `remediation.suggested_agent`: "devops"

## VERIFY

1. Wildcard+credentials signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
2. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
3. Neu runtime: verify response status codes
4. CACHING: verify cache TTL ton tai (1h) — khong violate ADR-22
5. Moi signal co `remediation.suggested_action` non-empty

## Severity Rules

| Dieu kien | Severity | CDG | MITRE ATT&CK |
|----------|----------|-----|--------------|
| Wildcard origin + credentials: true | CRITICAL | CDG-SECURITY-LIVE | T1557.001 |
| Wildcard origin (no credentials) | MEDIUM | -- | T1204.001 |
| Permissive methods/headers (all) | MEDIUM | -- | T1204.001 |
| Missing CORS middleware | HIGH | -- | T1190 |
| Missing sameSite attribute | MEDIUM | -- | T1204.001 |
| Missing Access-Control-Max-Age | LOW | -- | N/A |
| Expose-Headers exposes internal headers | MEDIUM | -- | T1557.001 |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source code khong ton tai, BASE_URL khong co | Skip probe, `skip_reason: "no_source"` |
| Cache hit (1h TTL) | Emit cached signals, note "from_cache" |
| Runtime test khong co BASE_URL | Chi static grep, skip runtime, note "runtime_skipped_no_base_url" |
| CURL khong available | Skip runtime test, note "runtime_skipped_no_curl" |
| No CORS patterns found in code | Emit WARNING: API co the thieu CORS config completely |

