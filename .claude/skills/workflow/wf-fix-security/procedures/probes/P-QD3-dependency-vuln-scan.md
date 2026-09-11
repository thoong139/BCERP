# P-QD3-dependency-vuln-scan — Dependency Vulnerability Scan

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-dependency-vuln-scan |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Scan dependencies cho known CVEs: package.json, requirements.txt, pom.xml, Gemfile, go.mod. So sanh version patterns voi known CVE checklist. Exhaustive profile goi npm audit / pip audit. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-dep-check.md |

## PRE-GATE

```
IF khong co dependency manifests (Glob **/package.json,**/requirements.txt,**/pom.xml tra 0 results):
  SKIP probe, note "no_dependency_manifests"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always — ADR-22 Rule 6)
IF profile == standard: chi parse dependency manifests + known CVE checklist
IF profile == deep: parse manifests + CVE checklist + bump-version recommendations
IF profile == exhaustive: manifests + CVE checklist + npm audit/pip audit + security agent review
```

## SENSE

### B1: Parse dependency manifests

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-dependency-vuln-scan.json"
mkdir -p "$(dirname "$RAW_OUT")"

# Find dependency manifests
PKG_JSON=$(find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -5)
REQ_TXT=$(find . -name "requirements.txt" -not -path "*/node_modules/*" 2>/dev/null | head -5)
POM_XML=$(find . -name "pom.xml" -not -path "*/node_modules/*" 2>/dev/null | head -5)
GEMFILE=$(find . -name "Gemfile" -not -path "*/node_modules/*" 2>/dev/null | head -5)
GO_MOD=$(find . -name "go.mod" -not -path "*/node_modules/*" 2>/dev/null | head -5)

if [ -z "$PKG_JSON$REQ_TXT$POM_XML$GEMFILE$GO_MOD" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-dependency-vuln-scan","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_dependency_manifests"}
EOF
  exit 0
fi

# --- Known CVE checklist (hardcoded patterns by package) ---
# Format: package_name minimum_safe_version
CVE_CHECKLIST='
  express:<4.18.0
  lodash:<4.17.21
  axios:<1.6.0
  jsonwebtoken:<9.0.0
  passport:<0.7.0
  mongoose:<8.0.0
  django:<4.2.10
  flask:<3.0.0
  requests:<2.31.0
  urllib3:<2.0.0
  jinja2:<3.1.3
  log4j-core:<2.17.1
  spring-core:<5.3.25
  jackson-databind:<2.14.3
  tomcat:<10.1.14
  nokogiri:<1.16.0
  devise:<4.9.3
'

# --- Parse package.json ---
if [ -n "$PKG_JSON" ]; then
  for MANIFEST in $PKG_JSON; do
    while IFS= read -r line; do
      PKG=$(echo "$line" | grep -oE '"[a-zA-Z0-9_@/-]+"' | head -1 | tr -d '"')
      VER=$(echo "$line" | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | tr -d '"')
      if [ -n "$PKG" ] && [ -n "$VER" ]; then
        echo "$PKG:$VER" >> "$RAW_OUT.node_deps"
        # Check against CVE checklist
        SAFE_VER=$(echo "$CVE_CHECKLIST" | grep "^$PKG:<" | cut -d: -f2)
        if [ -n "$SAFE_VER" ]; then
          echo "vulnerable:$PKG:$VER:known_CVE" >> "$RAW_OUT.node_vulns"
        fi
      fi
    done < <(grep -E '"[a-zA-Z0-9_@/-]+"\s*:\s*"'$(echo [0-9])'' "$MANIFEST" 2>/dev/null)
  done
fi

# --- Parse requirements.txt ---
if [ -n "$REQ_TXT" ]; then
  for MANIFEST in $REQ_TXT; do
    while IFS= read -r line; do
      PKG=$(echo "$line" | grep -oE '^[a-zA-Z0-9_.-]+' | head -1)
      OP=$(echo "$line" | grep -oE '(==|>=|<=|!=|~=)' | head -1)
      VER=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      if [ -n "$PKG" ] && [ -n "$VER" ]; then
        echo "$PKG:$OP$VER" >> "$RAW_OUT.py_deps"
        SAFE_VER=$(echo "$CVE_CHECKLIST" | grep "^$PKG:<" | cut -d: -f2)
        if [ -n "$SAFE_VER" ]; then
          echo "vulnerable:$PKG:$VER:$SAFE_VER" >> "$RAW_OUT.py_vulns"
        fi
      fi
    done < "$MANIFEST"
  done
fi

# --- Exhaustive: npm audit / pip audit ---
if [ "$PROFILE" = "exhaustive" ]; then
  if command -v npm &>/dev/null && [ -n "$PKG_JSON" ]; then
    cd "$(dirname "$(echo "$PKG_JSON" | head -1)")"
    npm audit --json 2>/dev/null | jq -r '.vulnerabilities // empty | to_entries[] | "\(.key):\(.value.severity):\(.value.range)"' 2>/dev/null > "$RAW_OUT.npm_audit" || \
      echo "npm_audit_failed" > "$RAW_OUT.npm_audit"
    cd - >/dev/null
  fi
  if command -v pip &>/dev/null && [ -n "$REQ_TXT" ]; then
    pip-audit --json 2>/dev/null > "$RAW_OUT.pip_audit" || \
      echo "pip_audit_failed" > "$RAW_OUT.pip_audit"
  fi
fi

# --- Write aggregate output ---
VULN_COUNT=$(wc -l < "$RAW_OUT.node_vulns" 2>/dev/null || echo 0)
VULN_COUNT=$((VULN_COUNT + $(wc -l < "$RAW_OUT.py_vulns" 2>/dev/null || echo 0)))

cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-dependency-vuln-scan","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)",
 "signals":[],"vulnerable_count":$VULN_COUNT,"note":"CVE checklist matches in temp files"}
EOF

rm -f "$RAW_OUT.node_deps" "$RAW_OUT.node_vulns" "$RAW_OUT.py_deps" "$RAW_OUT.py_vulns" \
      "$RAW_OUT.npm_audit" "$RAW_OUT.pip_audit" 2>/dev/null
```

### B2: Cache check

Cache allowed (24h TTL). Bash script co the goi cache_lookup truoc khi scan. Neu cache hit, emit cached signals.

## THINK

Phan tich dependency vulnerabilities:

1. **Known CVE checklist:** Compare package versions against minimum safe versions for critical packages.

2. **npm audit / pip audit (exhaustive):** Full CVE database scan via package manager auditing tools.

3. **Severity mapping:**
   - CRITICAL: Known RCE CVEs (log4shell, jackson gadget, express RCE)
   - HIGH: Leading to data access or DoS (XSS via deps, prototype pollution)
   - MEDIUM: Moderate severity CVEs (information disclosure)

4. **Priority:** CRITICAL CVEs -> CDG-SECURITY-LIVE flag, user must approve before build.

**CDG flags:** `cdg_flags: ["CDG-SECURITY-LIVE"]` cho CRITICAL CVEs (RCE, auth bypass in auth libraries).

**MITRE ATT&CK mapping:**
- Known RCE CVE in dependency -> T1190 (Exploit Public-Facing Application)
- Known XSS in dependency -> T1059.007 (XSS via compromised library)
- Known SQLi in ORM/DB driver -> T1190


## ACT

Results duoc aggregate thanh signals theo schema `signal-v2`:
- `signal_id` format: `CVE-{package}-{severity}`
- `dimension_id: "QD3"`, `domain: "security"`
- `cdg_flags`: ["CDG-SECURITY-LIVE"] cho CRITICAL CVEs
- `evidence[].type`: "cve_checklist" hoac "npm_audit" hoac "pip_audit"
- `evidence[].description`: "package:version - known CVE: {cve_id}"
- `remediation.suggested_action`: "Upgrade {package} to >= {safe_version}"
- `remediation.suggested_agent`: "devops"

SKILL.md emit signals qua signal-emit.md helper voi lock + dedup.

## VERIFY

1. Moi CRITICAL CVE signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
2. Moi signal co `dimension_id == "QD3"` va `domain == "security"`
3. Moi signal co `remediation.suggested_action` chua specific upgrade instruction
4. CACHING: verify cache TTL ton tai (24h)
5. Dependency count signal: so luong deps da duoc scan
6. Neu npm audit/pip audit failed: ghi nhan trong metadata, khong block

## Severity Rules

| Dieu kien | Severity | CDG | MITRE ATT&CK | Example |
|----------|----------|-----|--------------|---------|
| Known RCE CVE (log4shell, jackson, etc.) | CRITICAL | CDG-SECURITY-LIVE | T1190 | log4j < 2.17.1 |
| Auth bypass CVE in auth library | CRITICAL | CDG-SECURITY-LIVE | T1550.004 | jsonwebtoken < 9.0.0 |
| High severity CVE (XSS, prototype pollution) | HIGH | -- | T1059.007 | lodash < 4.17.21 |
| High severity CVE (SSRF, path traversal) | HIGH | -- | T1190 | axios < 1.6.0 |
| Moderate severity CVE | MEDIUM | -- | T1190 | express < 4.18.0 |
| npm audit / pip audit warning | MEDIUM | -- | N/A | Deprecation warning |
| Deprecated package (unmaintained) | MEDIUM | -- | N/A | No update in 2+ years |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| No dependency manifests found | Skip probe, `skip_reason: "no_dependency_manifests"` |
| npm/pip khong installed | Chi static CVE checklist, skip audit, note "audit_tool_not_available" |
| npm audit failed / timeout | Chi static CVE checklist, note "npm_audit_failed" |
| pip-audit khong installed | Chi static CVE checklist, note "pip_audit_not_installed" |
| Cache hit (24h TTL) | Emit cached signals, note "from_cache" |
| CVE checklist match is false positive | Agent review, giam severity or remove |

