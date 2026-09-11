# P-QD1-infra-preflight — Infrastructure Preflight Check

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-infra-preflight |
| **Loai** | runtime |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Kiem tra frontend/backend/DB/CORS alive truoc khi chay probes khac |
| **Cache** | skip (runtime probe) |
| **Migrates from** | (v5 legacy — removed in v6) phase3-infra-check.md (Layer 0) |

## PRE-GATE

```
IF $BASE_URL == null:
  SKIP probe, note "skipped_no_base_url"
  WRITE lane-status.json voi probe status="skipped"
```

## SENSE

### B1: Frontend reachable

```bash
FRONTEND_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/" --max-time 10 2>/dev/null || echo "000")
```

Hoac voi Playwright bash-level: `pw_navigate "$BASE_URL/" "networkidle"` → check page loaded.

### B2: Backend API health

Thu 3 health endpoint patterns:
```bash
for EP in "/api/health" "/health" "/api"; do
  HTTP=$(curl -s -o /tmp/health_body.txt -w "%{http_code}" "$BASE_URL$EP" --max-time 10 2>/dev/null || echo "000")
  if [ "$HTTP" != "000" ]; then
    BACKEND_HTTP=$HTTP
    BACKEND_BODY=$(cat /tmp/health_body.txt | head -c 500)
    break
  fi
done
```

### B3: Database connectivity (qua API health)

```bash
DB_STATUS=$(echo "$BACKEND_BODY" | jq -r '.db // .database // .status // "unknown"' 2>/dev/null)
```

### B4: CORS check

```bash
CORS_HEADERS=$(curl -sI "$BASE_URL/api/" -H "Origin: $BASE_URL" --max-time 10 2>/dev/null | grep -i "access-control-allow")
```

### B5: Environment config (static check)

```bash
if [ -f "package.json" ]; then
  DEPS=$(jq -r '.dependencies // {} | keys[]' package.json)
  # next → NEXT_PUBLIC_*, @prisma/client → DATABASE_URL, mongoose → MONGODB_URI
fi
# Check .env file existence (KHONG doc noi dung)
ls .env .env.local .env.development 2>/dev/null
```

## THINK

### Build infrastructure status

```json
{
  "frontend": "reachable|unreachable",
  "backend": "running|not_running|unknown",
  "database": "connected|error|unknown",
  "cors": "ok|blocked|unknown",
  "env": "complete|missing_[list]"
}
```

### Severity assignment

| Component | Status | Severity |
|-----------|--------|----------|
| Backend khong phan hoi | not_running | CRITICAL |
| Frontend khong reachable | unreachable | CRITICAL |
| Database loi ket noi | error | CRITICAL |
| CORS blocked | blocked | CRITICAL |
| Missing env vars | missing | HIGH |

## ACT

### Tao Signals

Cho moi infrastructure failure:
```json
{
  "probe_id": "P-QD1-infra-preflight",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "infrastructure_error",
  "target": { "kind": "route", "file_path": "N/A", "line_range": [0, 0], "url": "$BASE_URL/api/health" },
  "description": "Backend API khong phan hoi. HTTP code: 000. Phat hien loi ha tang.",
  "evidence": { "log_excerpt": "curl: (7) Failed to connect to localhost port 3000: Connection refused" },
  "suggested_severity": "critical",
  "dedup_hints": ["infra:backend"]
}
```

### Special handling

```
IF backend == "not_running":
  → CRITICAL signal
  → SKIP P-QD1-api-smoke, P-QD1-deep-ui-traversal (se fail het)
  → Static probes (P-QD1-req-registry-xref, P-QD1-route-config-parse) van chay

IF database == "error":
  → CRITICAL signal
  → API smoke tests co the return errors → flag nhung van chay

IF cors == "blocked":
  → CRITICAL signal
  → SKIP P-QD1-deep-ui-traversal (interactions se fail)
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-infra-preflight.json" << 'EOF'
$INFRA_SIGNALS
EOF
```

## VERIFY

1. Kiem tra moi Signal co `evidence.log_excerpt` non-empty (min 20 chars)
2. Kiem tra moi Signal co `target.url` cho infrastructure endpoints
3. Kiem tra moi Signal co `suggested_severity` == "critical" cho infrastructure down
4. Kiem tra $INFRA_STATUS duoc build day du (5 fields)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| $BASE_URL == null | Skip toan bo probe, note "skipped_no_base_url" |
| curl khong available | Dung Playwright bash-level pw_navigate + pw_evaluate |
| Backend timeout (>10s) | Mark "not_running", emit CRITICAL signal |
| Health endpoint khong chuan | Thu 3 patterns (/api/health, /health, /api) |
| Khong co .env file | Skip env check, note "no_env_file" |
