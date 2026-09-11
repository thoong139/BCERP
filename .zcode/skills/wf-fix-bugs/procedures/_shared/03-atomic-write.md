# §3 Atomic Write Pattern

> CORE-006 Safe-Write. Áp dụng cho mọi file shared state.

```bash
# Pattern bắt buộc cho fix-status.json + các JSON state files:
TARGET="$SESSION_DIR/fix-status.json"
TMP="${TARGET}.tmp.$$"

# 1. Build new content vào tmp file
jq '.phases.phase1.status = "completed"' "$TARGET" > "$TMP"

# 2. Validate tmp file pass JSON parse
jq '.' "$TMP" > /dev/null || { rm -f "$TMP"; echo "FAIL: invalid JSON"; exit 1; }

# 3. Atomic move
mv "$TMP" "$TARGET"
```

**Áp dụng cho:** `fix-status.json`, `session-log.json`, `error-ledger.json`, `cdg-tokens.json`, `issue-registry.json`
**KHÔNG áp dụng cho:** MD reports (Phase{N}-report.md), templates đã populate.
