# PRE-GATE — wf-fix-security (QD3 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)
> **Special:** ADR-22 Rule 6 — KHÔNG sử dụng scan cache trong mọi profile

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-security"
DIMENSION="QD3"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security"
USE_CACHE=false   # ADR-22 Rule 6 — luôn false, ignore --use-cache flag
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD3 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD3)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template — set `cache.enabled = false` (ADR-22)
7. Init `signals.json` từ shared template

## QD3-Specific Extension Steps

### Step 8 — Force disable cache (ADR-22 Rule 6)

```bash
# QD3 KHONG bao gio dung scan cache — security probes phai re-scan moi lan
if [ "${USE_CACHE:-false}" = "true" ]; then
  echo "WARN: --use-cache ignored cho QD3 (ADR-22 Rule 6 — security KHONG cache)" >&2
fi
USE_CACHE=false
```

### Step 9 — Verify scan tools available

```bash
# Check optional security tools — graceful degradation nếu thiếu
SEMGREP_AVAILABLE=$(command -v semgrep > /dev/null 2>&1 && echo true || echo false)
GITLEAKS_AVAILABLE=$(command -v gitleaks > /dev/null 2>&1 && echo true || echo false)
NPM_AUDIT_AVAILABLE=$(command -v npm > /dev/null 2>&1 && echo true || echo false)

[ "$SEMGREP_AVAILABLE" = "false" ] && echo "INFO: semgrep khong cai dat — P-QD3-owasp-top-ten se fallback grep" >&2
[ "$GITLEAKS_AVAILABLE" = "false" ] && echo "INFO: gitleaks khong cai dat — P-QD3-secret-detection se dung regex builtin" >&2
```

### Step 10 — Verify --base-url cho runtime probes

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD3-cors-policy-check, P-QD3-security-header-audit, P-QD3-auth-flow-verify) se skip" >&2
fi
```

### Step 11 — Resolve probe list theo profile (QD3)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD3-secret-detection" "P-QD3-dependency-vuln-scan")
    ;;
  standard)
    PROBES=("P-QD3-secret-detection" "P-QD3-dependency-vuln-scan"
            "P-QD3-dangerous-deserialize" "P-QD3-cors-policy-check"
            "P-QD3-security-header-audit")
    ;;
  deep|exhaustive)
    PROBES=("P-QD3-secret-detection" "P-QD3-dependency-vuln-scan"
            "P-QD3-dangerous-deserialize" "P-QD3-cors-policy-check"
            "P-QD3-security-header-audit" "P-QD3-auth-flow-verify"
            "P-QD3-owasp-top-ten")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior". QD3 KHÔNG cache → resume luôn re-scan probes pending.
