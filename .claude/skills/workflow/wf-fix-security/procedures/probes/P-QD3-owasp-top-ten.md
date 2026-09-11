# P-QD3-owasp-top-ten — OWASP Top 10 2021 Vulnerability Scan

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-owasp-top-ten |
| **Loai** | static (agent-assisted) |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Scan codebase cho OWASP Top 10 2021: Broken Access Control (A01), Cryptographic Failures (A02), Injection (A03), Insecure Design (A04), Security Misconfiguration (A05), Vulnerable Components (A06), Auth Failures (A07), Integrity Failures (A08), Logging Failures (A09), SSRF (A10). Agent security expert classify grep results. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-owasp-scan.md |

## PRE-GATE

```
IF khong co source code (Glob src/**/* tra 0 results) AND profile == standard:
  SKIP probe, note "skipped_no_source_code"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always)
IF profile == standard: chi scan injection + access control + auth patterns (A01, A03, A07)
IF profile == deep: scan A01-A07 + A10 (bo sung Cryptographic, Config, SSRF)
IF profile == exhaustive: scan FULL A01-A10 + goi security agent de classify
```

## SENSE

### B1: Delegate to bash script (inline grep, agent-assisted)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-owasp-top-ten.json"
mkdir -p "$(dirname "$RAW_OUT")"

# Threshold: chi scan file types co logic code
SCAN_FILES=$(find src/ -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.cs" -o -name "*.go" -o -name "*.php" -o -name "*.rb" \) \
  ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/__tests__/*" 2>/dev/null | head -200)

if [ -z "$SCAN_FILES" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-owasp-top-ten","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_files"}
EOF
  exit 0
fi

# --- A01: Broken Access Control ---
grep -rnE '\.(all|get|post|put|delete|patch)\(' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -ivE '(auth|authGuard|requireAuth|authenticate|middleware|verifyToken|jwt|role|permission|isAuthenticated)' \
  | grep -vE '/(public|health|metrics|status|webhook)/' \
  | head -50 > "$RAW_OUT.acc_ctrl"

grep -rnE '(req\.params\.|req\.query\.|request\.params\.)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -iE '(findById|findOne|findByPk|getById|where.*id|\.id\s*=|find\()' \
  | grep -ivE '(auth|session|currentUser|validate|sanitize)' \
  | head -30 > "$RAW_OUT.idor"

# --- A02: Cryptographic Failures ---
grep -rnE '(MD4|MD5|SHA1|DES|3DES|RC2|RC4|Blowfish|PBKDF2_without|ECB|cipher.*AES.*ECB)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.java" --include="*.cs" \
  src/ 2>/dev/null | grep -vE '(node_modules|\.test\.|\.spec\.)' | head -30 > "$RAW_OUT.crypto"


# --- A03: Injection ---
grep -rnE '(SELECT\s+.*\s+FROM.*\s*\+\s*|INSERT\s+INTO.*\s*\+\s*|UPDATE\s+.*SET.*\s*\+\s*|DELETE\s+FROM.*\s*\+\s*)' \
  -i --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|template|placeholder|\?|\$1|%s|:param|@param)' \
  | head -50 > "$RAW_OUT.sqli"

grep -rnE '(find\s*\(\s*\{.*\$where|find\s*\(\s*\{.*\$gt|find\s*\(\s*\{.*\$ne|find\s*\(\s*\{.*\$regex)' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.)' | head -20 > "$RAW_OUT.nosqli"

grep -rnE '(exec\(|execSync\(|spawn\(|spawnSync\(|child_process|shell:\s*true|execFile\()' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|\.spec\.|__mocks__|fixtures)' \
  | grep -vE '("ls"|"cat"|"echo"|"mkdir"|"rm"|"cp"|"mv"|"git"|"npm")' \
  | head -30 > "$RAW_OUT.os_cmd"

# --- A07: Auth Failures ---
grep -rnE '(algorithm.*none|alg.*none|jwt\.verify\(.*,\s*"")' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | head -10 > "$RAW_OUT.jwt_none"

grep -rnE '(jwtSecret|jwt_secret|JWT_SECRET\s*[:=]\s*["].{1,20}["])' \
  --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null \
  | grep -vE '(process\.env|process\.env\.NEXT_PUBLIC)' \
  | head -10 > "$RAW_OUT.jwt_hardcoded"


# --- A05: Security Misconfiguration ---
grep -rnE '(debug\s*:\s*true|debugMode|NODE_ENV.*development|APP_DEBUG.*true|DEBUG\s*=\s*True)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.json" \
  --include="*.yaml" --include="*.yml" --include="*.env*" --include="*.conf" \
  src/ 2>/dev/null | grep -vE '(.env\.example|.env\.sample|template|README)' \
  | head -20 > "$RAW_OUT.debug_mode"

grep -rnE '(admin.*admin|password.*password|admin.*123456|root.*toor)' \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" --include="*.json" \
  --include="*.yaml" --include="*.yml" src/ 2>/dev/null \
  | grep -vE '(node_modules|\.test\.|fixture|mock|example)' \
  | head -10 > "$RAW_OUT.default_creds"

# --- A04: Insecure Design (deep/exhaustive only) ---
if [ "$PROFILE" != "standard" ]; then
  grep -rnE '(rate.?limit|throttle|maxLoginAttempts|accountLockout|brute.?force)' \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
    | head -5 > /dev/null
  if [ $? -ne 0 ]; then
    echo "missing_rate_limit" >> "$RAW_OUT.design"
  fi

  grep -rnE '(csrf|csrfProtection|csrfToken|doubleSubmitCookie|sameSite.*strict|X-Requested-With)' \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.)' | head -10 > "$RAW_OUT.csrf"
fi

# --- A10: SSRF (deep/exhaustive only) ---
if [ "$PROFILE" != "standard" ]; then
  grep -rnE '(fetch\(|axios\.\(|request\(|got\(|superagent|http\.get\(|https\.get\()' \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" src/ 2>/dev/null \
    | grep -vE '(node_modules|\.test\.|\.spec\.|fixtures|mocks|__mocks__)' \
    | grep -vE '("https?://[^$]|'https?://[^$])' \
    | head -30 > "$RAW_OUT.ssrf"
fi

# --- A09: Logging Failures (exhaustive only) ---
if [ "$PROFILE" = "exhaustive" ]; then
  grep -rnE '(console\.log\(.*(password|secret|token|api.?key|credit.?card))' \
    -i --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
    src/ 2>/dev/null | grep -vE '(node_modules|\.test\.)' \
    | head -20 > "$RAW_OUT.logging_sensitive"

  grep -rnE '(sentry|datadog|newrelic|elastic|logstash|fluentd|winston|pino|log4j|logback)' \
    --include="*.json" --include="*.yaml" --include="*.yml" --include="*.ts" \
    --include="*.py" src/ 2>/dev/null | head -5 > /dev/null
  if [ $? -ne 0 ]; then
    echo "missing_logging_framework" >> "$RAW_OUT.design"
  fi
fi

cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-owasp-top-ten","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)",
 "signals":[],"note":"Raw grep results in temp files -- security agent processes into signal-v2"}
EOF

rm -f "$RAW_OUT.acc_ctrl" "$RAW_OUT.idor" "$RAW_OUT.sqli" "$RAW_OUT.nosqli" \
      "$RAW_OUT.os_cmd" "$RAW_OUT.crypto" "$RAW_OUT.jwt_none" "$RAW_OUT.jwt_hardcoded" \
      "$RAW_OUT.debug_mode" "$RAW_OUT.default_creds" "$RAW_OUT.design" "$RAW_OUT.csrf" \
      "$RAW_OUT.ssrf" "$RAW_OUT.logging_sensitive"
```

**Chi tiet pattern groups theo profile:**

| Profile | OWASP Categories | Patterns scanned |
|---------|-----------------|------------------|
| standard | A01, A03, A07 | SQLi, Broken Access Control, Auth failures (JWT) |
| deep | A01-A07, A10 | Bo sung Crypto (A02), Insecure Design (A04), Misconfig (A05), SSRF (A10) |
| exhaustive | A01-A10 | Full: bo sung Logging (A09) |

**Agent-assisted classification (deep/exhaustive):**
- Security agent reviews grep results for false positives
- Classifies each match as: confirmed, suspected, or false_positive
- For confirmed: assigns MITRE ATT&CK technique mapping

### B2: KHONG check scan cache

ADR-22 Rule 6 -- security probes ALWAYS re-scan. Bash script KHONG goi cache_lookup.

## THINK

Bash script implement logic:

1. **Scan pattern groups** theo profile depth -- standard chi quet 3 categories (A01, A03, A07)

2. **Severity assignment:**
   - CRITICAL: SQLi/NoSQLi/OS Command Injection, JWT algorithm confusion, Broken Access Control missing guard
   - HIGH: IDOR, weak crypto, hardcoded JWT secret, default credentials, SSRF
   - MEDIUM: debug mode, missing rate limiting, missing CSRF protection, sensitive data in logs

3. **CDG flags:** `cdg_flags: ["CDG-SECURITY-LIVE"]` cho injection + access control CRITICAL signals

4. **MITRE ATT&CK mapping:**
   - SQLi/NoSQLi -> T1190 (Exploit Public-Facing Application)
   - OS Command Injection -> T1059 (Command and Scripting Interpreter)
   - Broken Access Control -> T1078 (Valid Accounts)
   - IDOR -> T1212 (Exploitation for Privilege Escalation)
   - JWT alg none -> T1550.004 (Use Alternate Authentication Material)
   - Weak crypto -> T1552.004 (Unsecured Credentials: Private Keys)
   - SSRF -> T1190 / T1613 (Container and Resource Discovery)
   - Sensitive data in logs -> T1565.002 (Data Manipulation)

## ACT

Grep output duoc security agent xu ly thanh signals theo schema `signal-v2`:
- `signal_id` format: `OWASP-{category}-{file_hash8}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: ["CDG-SECURITY-LIVE"] cho CRITICAL injection/access control
- `evidence[].description` chua snippet (100 chars max)
- `remediation.suggested_action`: OWASP cheat sheet reference
- `remediation.suggested_agent`: "security"

SKILL.md emit signals qua signal-emit.md helper voi lock + dedup.

## VERIFY

1. Moi CRITICAL signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
2. Moi signal co `evidence[]` voi it nhat 1 non-empty field
3. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
4. KHONG co scan cache calls (audit cache_lookup trong probe MD/script)
5. Standard profile khong co A08/A09/A10 signals
6. Moi signal co `remediation.suggested_action` non-empty

## Severity Rules

| OWASP Category | Pattern phat hien | Severity | CDG | Ly do |
|---------------|-------------------|----------|-----|-------|
| A01 -- Broken Access Control | API endpoint thieu auth guard | CRITICAL | CDG-SECURITY-LIVE | Unrestricted resource access |
| A01 -- IDOR | User param truc tiep db query | HIGH | -- | Horizontal privilege escalation |
| A02 -- Cryptographic Failures | MD5/SHA1/DES/ECB | HIGH | -- | Weak encryption |
| A03 -- SQL Injection | String concat raw query | CRITICAL | CDG-SECURITY-LIVE | Direct database access |
| A03 -- NoSQL Injection | $where/$gt/$ne user query | CRITICAL | CDG-SECURITY-LIVE | Database bypass |
| A03 -- OS Command Injection | exec/spawn/shell:true variable | CRITICAL | CDG-SECURITY-LIVE | Remote code execution |
| A04 -- Insecure Design | Missing rate limiting | MEDIUM | -- | Brute-force vulnerability |
| A04 -- Insecure Design | Missing CSRF protection | MEDIUM | -- | Cross-site request forgery |
| A05 -- Misconfiguration | Debug mode in production | MEDIUM | -- | Information disclosure |
| A05 -- Misconfiguration | Default credentials | HIGH | -- | Easy unauthorized access |
| A07 -- Auth Failures | JWT alg none | CRITICAL | CDG-SECURITY-LIVE | Token forgery |
| A07 -- Auth Failures | Hardcoded JWT secret | HIGH | -- | Signing key compromise |
| A09 -- Logging Failures | Sensitive data in logs | MEDIUM | -- | Credential exposure |
| A10 -- SSRF | User-controlled URL HTTP call | HIGH | -- | Internal network scan |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source code khong ton tai | Skip probe, emit empty signals voi `skip_reason: "no_source_dir"` |
| Khong co file nguon phu hop (.ts/.js/.py/.java...) | Skip probe, note "no_code_files_scannable" |
| False positive rate >50% | Agent re-classify, giam severity cho low-confidence |
| Security agent khong available | Chi raw grep results, khong classification |
| Tat ca pattern deu khong match | Emit empty signals, ghi "no_vulnerabilities_found" |

