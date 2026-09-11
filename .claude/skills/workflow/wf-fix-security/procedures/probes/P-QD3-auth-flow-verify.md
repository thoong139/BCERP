# P-QD3-auth-flow-verify — Authentication & Authorization Flow Verification

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-auth-flow-verify |
| **Loai** | static+runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Verify authentication va authorization flows: JWT validation, session management, RBAC enforcement, token expiry, password policies. Runtime: test protected endpoints voi auth tokens. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-auth-check.md |

## PRE-GATE

```
IF khong co source code AND khong co BASE_URL:
  SKIP probe, note "skipped_no_source_and_no_base_url"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always)
IF profile == standard: chi static grep auth patterns, skip runtime
IF profile == deep: static grep + runtime endpoint check neu BASE_URL available
IF profile == exhaustive: static grep + runtime fuzzing + security agent review
IF runtime component can chay: kiem tra $BASE_URL != null, otherwise skip runtime part

# (IMP-015) Check phase3-architecture docs for auth design context
ARCH_DOCS=$(find .mc-data/docs/phase3-architecture -name "*auth*" -o -name "*security*" 2>/dev/null | head -5)
IF ARCH_DOCS is empty:
  EMIT signal AUTH-FLOW-SKIP-NO-ARCH:
    signal_type: "auth_flow_no_arch_docs"
    severity: "warn"
    description: "Khong tim thay phase3-architecture auth/security docs — P-QD3-auth-flow-verify chay static grep only, khong co architecture context. Accuracy co the bi giam. Nen chay /wf-design truoc de co architecture docs."
    cdg_flags: []
  — Tiep tuc probe voi static grep (KHONG skip, chi warning)
```

## SENSE

### B1: Static analysis — grep auth patterns

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-auth-flow-verify.json"
mkdir -p "$(dirname "$RAW_OUT")"

# Check source code exists
SCAN_FILES=$(find src/ -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \) \
  ! -path "*/node_modules/*" 2>/dev/null | head -50)

if [ -z "$SCAN_FILES" ] && [ -z "$BASE_URL" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-auth-flow-verify","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_and_no_base_url"}
EOF
  exit 0
fi

# --- JWT verification patterns ---
grep -rnE '(jwt\.verify|verifyIdToken|validateToken|verifyToken|decodeToken)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -30 > "$RAW_OUT.jwt_verify"

# JWT missing verification
grep -rnE '(jwt|token|bearer|authorization)' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|\.spec\.)' \
  | grep -vE '(jwt\.verify|verifyIdToken|validateToken|verifyToken)' \
  | head -30 > "$RAW_OUT.jwt_missing_verify"

# --- Session management ---
grep -rnE '(session|express-session|cookie-session|connect-redis|session\.cookie)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -30 > "$RAW_OUT.session_config"

# Check for secure cookie flags
grep -rnE '(httpOnly|secure|sameSite|signed|maxAge|expires)' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -iE '(cookie|session)' | grep -vE '(node_modules|\.test\.)' \
  | head -30 > "$RAW_OUT.cookie_flags"

# --- RBAC / Authorization guards ---
grep -rnE '(role|permission|guard|canActivate|authorize|requireRole|hasRole|isAdmin|isOwner)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -40 > "$RAW_OUT.rbac_patterns"

grep -rnE '(\.use\(.*auth|middleware|authenticate)' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.auth_middleware"

# --- Password policy ---
grep -rnE '(password|passwd|pwd)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -iE '(hash|bcrypt|argon2|scrypt|minLength|complexity|strength)' \
  | grep -vE '(node_modules|\.test\.|mock|fixture)' \
  | head -30 > "$RAW_OUT.password_policy"

# Detect weak hashing
grep -rnE '(md5\(.*pass|sha1\(.*pass|password.*md5|password.*sha1|crypt\.createHash)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.weak_hash"

# --- Token expiry ---
grep -rnE '(expiresIn|expiry|expiration|tokenExpiry|refreshToken|refresh_token)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.token_expiry"
```

**Static analysis summary:** Output files contain grep matches for each auth category.

### B2: Runtime endpoint test (deep/exhaustive only)

```bash
if [ -n "$BASE_URL" ] && [ "$PROFILE" != "standard" ]; then
  # Test 1: Access protected endpoint without auth token (expect 401)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/protected" 2>/dev/null || echo "000")
  echo "{\"test\":\"no_auth\",\"endpoint\":\"$BASE_URL/api/protected\",\"status\":\"$HTTP_STATUS\"}" > "$RAW_OUT.runtime_noauth"

  # Test 2: Access with invalid token (expect 401)
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer invalid_token_xyz" \
    "$BASE_URL/api/protected" 2>/dev/null || echo "000")
  echo "{\"test\":\"invalid_token\",\"endpoint\":\"$BASE_URL/api/protected\",\"status\":\"$HTTP_STATUS\"}" > "$RAW_OUT.runtime_invalid_token"

  # Test 3: Check if auth endpoint uses HTTPS (exhaustive only)
  if [ "$PROFILE" = "exhaustive" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/auth/login" 2>/dev/null || echo "000")
    echo "{\"test\":\"auth_endpoint\",\"endpoint\":\"$BASE_URL/auth/login\",\"status\":\"$HTTP_STATUS\"}" >> "$RAW_OUT.runtime_noauth"
  fi
fi
```

### B3: KHONG check scan cache

ADR-22 Rule 6 -- security probes ALWAYS re-scan.

### B3a: CI Enrichment (BAT BUOC khi GITNEXUS available — canonical use case cho auth flow tracing)

> **Quan trong:** ADR-22 Rule 6 cam **scan cache** cho security, NHUNG cho phep CI MCP tools (GitNexus query, Serena find_refs) vi day la realtime code intelligence query, KHONG phai cached scan results.
> **Muc dich:** Auth bypass / IDOR la use-case kinh dien cho `gitnexus_query("auth")` — trace tu router → middleware → handler de xac nhan day du auth check.

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # Pseudocode (orchestrator agent thuc hien):
  # 
  # Step 1: Query auth flow tu GitNexus
  auth_flow = mcp__plugin_gitnexus_gitnexus__query(query="authentication flow")
  # Returns process steps: router → middleware → handler chain
  # 
  # Step 2: Cross-check voi static findings
  # FOR each signal trong $RAW_OUT.signals[]:
  #   IF signal.signal_type IN ("missing_jwt_verify", "missing_auth_middleware", "missing_role_check"):
  #     # Tim noi cu the bi missing trong flow
  #     impact = mcp__plugin_gitnexus_gitnexus__impact(target=signal.location.symbol, direction="upstream")
  #     signal.evidence.gitnexus_callers = impact.direct_callers_count
  #     signal.evidence.gitnexus_processes = impact.affected_processes
  #     # Bump severity neu callers > 0 va trong production endpoint
  #     IF "endpoint" in impact.affected_processes:
  #       signal.suggested_severity = "critical"
  # 
  # Step 3: Discover untested endpoints
  # endpoints = mcp__plugin_gitnexus_gitnexus__route_map() if available
  # FOR each endpoint:
  #   IF endpoint.handler khong co middleware "requireAuth"|"verifyToken":
  #     EMIT NEW signal (severity=high) — auth_missing_endpoint
  # 
  # Step 4: Serena find_refs cho session/auth helpers
  # IF SERENA_AVAILABLE:
  #   FOR each signal voi auth_helper symbol:
  #     refs = mcp__serena__find_referencing_symbols(name_path=auth_helper, relative_path=...)
  #     signal.evidence.serena_refs_count = refs.length
  # 
  # signal.evidence.ci_meta = {gitnexus_used: true, serena_used: $SERENA_AVAILABLE, freshness_level: $FRESHNESS_LEVEL}
fi
```

**Graceful:** GitNexus absent → skip B3a, signals giu nguyen tu B1.

## THINK

Phan tich ket qua theo 4 truc:

1. **JWT lifecycle:** Co verify call khong? Algorithm co explicit khong? Secret co hardcoded khong? Expiry duoc kiem tra khong?

2. **Session security:** Cookie flags (httpOnly, secure, sameSite) co set khong? Session store dung production-grade (redis/DB) khong?

3. **Authorization coverage:** Tat ca API endpoints co auth middleware khong? RBAC roles duoc enforce o controller level khong? IDOR kiem tra ownership?

4. **Password hygiene:** Hash algorithm (bcrypt/argon2 vs md5/sha1)? Min length? Brute-force protection?

**CDG flags:** CRITICAL signals attach `cdg_flags: ["CDG-SECURITY-LIVE"]`

**MITRE ATT&CK mapping:**
- Missing JWT verification -> T1550.004 (Use Alternate Authentication Material)
- Weak session config -> T1529 (Web Session Cookie)
- Missing RBAC enforcement -> T1078 (Valid Accounts)
- Weak password hash -> T1110.002 (Brute Force: Password Cracking)

## ACT

Static + runtime results duoc aggregate thanh signals theo schema `signal-v2`:
- `signal_id` format: `AUTH-{category}-{file_hash8}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: ["CDG-SECURITY-LIVE"] cho missing auth / token forgery
- `evidence[].type`: "grep_match" (static) hoac "http_response" (runtime)
- `remediation.suggested_agent`: "security" hoac "backend-developer"

SKILL.md emit signals qua signal-emit.md helper voi lock + dedup.


## VERIFY

1. Moi CRITICAL signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
2. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
3. Runtime signals co `evidence[].type == "http_response"`
4. Static signals co `target.file_path` va `target.line_range`
5. KHONG co scan cache calls (ADR-22 Rule 6 audit)
6. Neu co runtime test: verify HTTP status code duoc ghi nhan dung

## Severity Rules

| Dieu kien | Severity | CDG | MITRE ATT&CK |
|----------|----------|-----|--------------|
| Protected endpoint tra ve 200 khi khong co token | CRITICAL | CDG-SECURITY-LIVE | T1550.004 |
| JWT verify missing / algorithm none | CRITICAL | CDG-SECURITY-LIVE | T1550.004 |
| JWT secret hardcoded trong source | HIGH | -- | T1552.004 |
| Session cookie thieu httpOnly/secure/sameSite | HIGH | -- | T1529 |
| RBAC middleware thieu tren API route | HIGH | -- | T1078 |
| Password hash dung md5/sha1 | HIGH | -- | T1110.002 |
| Password policy khong co minLength | MEDIUM | -- | T1110.001 |
| Token expiry khong duoc set | MEDIUM | -- | T1529 |
| Session store dung memory thay vi redis/DB | MEDIUM | -- | T1529 |
| Refresh token khong co rotation | MEDIUM | -- | T1529 |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source code khong ton tai, BASE_URL khong co | Skip probe, `skip_reason: "no_source_and_no_base_url"` |
| BASE_URL khong co (runtime) | Chi static grep, skip runtime, note "runtime_skipped_no_base_url" |
| Static scan khong tim thay auth pattern nao | Emit WARNING: "no_auth_patterns_found" -- co the codebase thieu auth completely |
| Endpoint tra ve timeout / 000 | Ghi nhan "endpoint_unreachable", khong emit signal tu runtime test |
| curl khong available | Skip runtime test, note "runtime_skipped_no_curl" |

