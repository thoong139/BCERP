# P-QD3-secret-detection — Hard-Coded Secret Detection

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD3-secret-detection |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien hardcoded secrets (API keys, passwords, tokens, private keys) trong source code va config files. CDG trigger. |
| **Cache** | NEVER (ADR-22 Rule 6 — security probes always re-scan) |
| **Migrates from** | (v5 legacy — removed in v6) phase4-secret-scan.md |

## PRE-GATE

```
IF khong co source code (Glob src/**/* tra 0 results):
  SKIP probe, note "skipped_no_source_code"
IF chay tu wf-fix-bugs orchestrator: yeu cau --use-cache=false (always)
```

## SENSE

### B1: Delegate to bash script (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-secret-detection.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-secret.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-security \
      --probe P-QD3-secret-detection \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash secret probe failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-security","dimension":"QD3",
 "probe_id":"P-QD3-secret-detection","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script scans 14 patterns:**
- AWS Access Key (`AKIA[A-Z0-9]{16}`)
- AWS Secret Key
- Google API Key (`AIza...`)
- GitHub Token (`gh[pousr]_...`)
- Slack Token (`xox[baprs]-...`)
- Stripe Live/Test Keys
- JWT Tokens
- Private Key Headers (RSA/DSA/EC/OPENSSH/PGP)
- Generic API Key / Password assignments
- Database URLs voi credentials
- Bearer tokens hardcoded
- Hex hashes 64+ chars

**Filter false positives:** test files, fixtures, mocks, examples, docs, node_modules. Comment lines voi keywords (example, placeholder, TODO, FIXME) → skip.

**G5 exclusions config (v11.1.0):** Probe doc duong path exclusions tu `.claude/skills/workflow/wf-fix-security/exclusions.json` (schema `scan-exclusions-v1`). 4 nhom mac dinh:
- `i18n_translations`: `/messages/`, `/i18n/`, `/locales/`, `/translations/`, `/lang/` — translation files khong phai real credentials
- `test_fixtures`: `__tests__`, `spec/`, `fixtures/`, etc. — intentional dummy secrets
- `docs_examples`: `.md`, `.example`, `README`, `CHANGELOG` — illustrative configs
- `build_artifacts`: `node_modules`, `.git/`, `dist/`, `build/`, etc. — not source

Bypass G5 (scan all): `MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE=true`.
Override config path: `MCV3_FIX_SECURITY_EXCLUSIONS_FILE=/custom/path/exclusions.json`.

### B2: KHONG check scan cache

ADR-22 Rule 6 — security probes ALWAYS re-scan. Bash script KHONG goi cache_lookup.

## THINK

Bash script da implement logic:
1. **Severity by pattern type:**
   - AWS Access/Secret Key, Google API Key, GitHub Token, Stripe Live Key, Private Key Header → CRITICAL
   - JWT, generic API key, generic password, DB URL voi creds, Bearer token → HIGH
   - Hex hashes 64+ → MEDIUM
2. **CDG flag attached:** `cdg_flags: ["CDG-SECURITY-LIVE"]` cho TAT CA signals — orchestrator yeu cau user confirm truoc khi auto-fix
3. **Domain:** `security`
4. **Fixability:** `agent_fix` (security agent rotate + move to env)

## ACT

Bash script output theo schema `signal-v2`:
- `dimension_id: "QD3"`, `domain: "security"`, `cdg_flags: ["CDG-SECURITY-LIVE"]`
- `evidence[].description` chua label + truncated snippet (100 chars max)
- `remediation.suggested_action: "Move to env var or secrets manager"`
- `remediation.suggested_agent: "security"`

SKILL.md sau khi nhan output → emit signals qua signal-emit.md helper voi lock + dedup.

## VERIFY

1. Moi Signal co `evidence[]` voi description chua pattern label + snippet
2. Moi Signal co `cdg_flags` chua "CDG-SECURITY-LIVE"
3. Moi Signal co `domain == "security"`
4. Moi Signal co `dimension_id == "QD3"`
5. KHONG co scan cache calls (audit qua grep cache_lookup trong probe MD/script)

## Severity Rules

| Pattern | Severity | Ly do |
|---------|----------|-------|
| AWS/Google/GitHub/Stripe Live Keys, Private Key Headers | CRITICAL | Direct production access |
| JWT, generic API key, password, DB URL, Bearer token | HIGH | Credentials co the abuse |
| Hex hash 64+ trong string literal | MEDIUM | Could be hash, could be secret |
| Stripe Test Key | HIGH | Less critical nhung still leak |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source code khong ton tai | Skip probe, emit empty signals voi `skip_reason: "no_source_dir"` |
| Bash script fail | SKILL.md inline fallback: emit empty signals voi `skip_reason: "bash_script_failed"`, log error |
| Match regex la trong comment voi placeholder/example | Bash script tu filter, KHONG emit |
| External secret scanner (gitleaks, trufflehog) khong co | KHONG block — bash regex la primary detection layer |
