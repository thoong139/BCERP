# _shared.md - Cross-Probe Protocols cho QD3 Lane

## 1. Signal Emission Protocol

Moi probe emit signals theo schema signal-v2. Signal dict:

```json
{
  "probe_id": "P-QD3-<probe-slug>",
  "probe_version": "1.0.0",
  "emitted_at": "2026-04-21T08:00:00Z",
  "lane": "wf-fix-security",
  "dimension_id": "QD3",
  "target": {
    "kind": "code|config_file|http_response|dependency",
    "file_path": "package.json",
    "line_range": [12, 15],
    "symbol": "dependency-name"
  },
  "description": "Mo ta issue >= 10 ky tu",
  "evidence": {
    "code_snippet": "...",
    "log_excerpt": "...",
    "http_response": "..."
  },
  "suggested_severity": "critical|high|medium|low",
  "dedup_hints": ["CVE-XXXX-YYYY", "package-name"]
}
```

### Rang buoc:
- probe_id phai match ^P-QD3-[a-z0-9-]+$
- description phai >= 10 ky tu
- It nhat 1 evidence field non-empty:
  - code_snippet min 10 chars
  - log_excerpt min 20 chars
  - http_response min 10 chars
  - cve_ref, advisory_url min 1 char
- target.kind bat buoc
- suggested_severity trong {critical, high, medium, low}

### Signal accumulation:
1. Moi probe viet signals vao $SESSION_DIR/phase4-find-bugs/lanes/QD3-security/raw/P-QD3-<probe>.json
2. Sau tat ca probes, lane gop vao $SESSION_DIR/phase4-find-bugs/lanes/QD3-security/signals.json

## 2. Cache Override: QD3 KHONG SU DUNG Scan Cache (ADR-22 Rule 6)

**Tat ca probes QD3 KHONG bao gio su dung scan cache.**

Khong co exception. Moi probe phai re-scan moi lan chay.

```
# KHONG bao gio goi cac lenh sau trong QD3 probes:
# python -m _shared.scan_cache.fingerprint  <- KHONG GOI
# python -m _shared.scan_cache.cache_lookup <- KHONG GOI
# python -m _shared.scan_cache.cache_store  <- KHONG GOI

# Moi probe chay truc tiep, khong kiem tra cache:
# 1. Read source file
# 2. Run analysis
# 3. Emit signals to raw/
```

Ly do (ADR-22 Rule 6): Security vulnerabilities phai duoc phat hien moi lan scan.
Cache co the bo sot vulnerability moi xuat hien giua cac lan scan, dan den
false negative nguy hiem.

## 3. Severity Mapping (QD3)

| Dieu kien | Severity | Confidence |
|-----------|----------|-----------|
| Hard-coded secret bi lo (API key, password, token) | CRITICAL | 0.95 |
| Authentication bypass | CRITICAL | 0.95 |
| SQL/Command injection | CRITICAL | 0.90 |
| XSS/CSRF pattern | HIGH | 0.85 |
| Unsafe dynamic code execution / deserialization | HIGH | 0.85 |
| Dependency CVE voi exploit cong khai | HIGH | 0.90 |
| Missing security header | MEDIUM | 0.80 |
| Overly permissive CORS | MEDIUM | 0.80 |
| Dependency CVE nhung chua co exploit | MEDIUM | 0.75 |
| Outdated dependency (khong co CVE) | LOW | 0.60 |

### CDG Trigger (CORE-027):
- P-QD3-secret-detection: Khi phat hien hard-coded secret -> CDG trigger
  -> Can user confirm truoc khi ghi signal (neu secret la test value thi co the skip)

## 4. Profile-Based Probe Selection

```
PROFILE="$PROFILE"

case "$PROFILE" in
  quick)
    PROBES="P-QD3-dependency-vuln-scan P-QD3-owasp-top-ten P-QD3-dangerous-deserialize"
    ;;
  standard)
    PROBES="P-QD3-dependency-vuln-scan P-QD3-owasp-top-ten P-QD3-dangerous-deserialize P-QD3-secret-detection P-QD3-auth-flow-verify P-QD3-cors-policy-check"
    ;;
  deep)
    PROBES="P-QD3-dependency-vuln-scan P-QD3-owasp-top-ten P-QD3-dangerous-deserialize P-QD3-secret-detection P-QD3-auth-flow-verify P-QD3-cors-policy-check P-QD3-security-header-audit"
    ;;
  exhaustive)
    PROBES="ALL"
    ;;
esac
```

## 5. Checkpoint Protocol

Sau moi probe hoan thanh, cap nhat lane-status.json:
```bash
jq --arg probe "$PROBE_ID" --arg status "completed" --arg signals "$SIGNAL_COUNT"   '.probes[$probe] = {"status": $status, "signals_emitted": ($signals|tonumber)}'   "$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/lane-status.json" > tmp.json && mv tmp.json "$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/lane-status.json"
```
