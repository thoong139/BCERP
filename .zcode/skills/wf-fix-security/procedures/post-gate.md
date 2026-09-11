# POST-GATE — wf-fix-security (QD3 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)
> **Special:** ADR-22 Rule 6 — verify KHÔNG có cache calls trong probe outputs

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-security"
DIMENSION="QD3"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD3-security"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md` (§T1, §T2, §T3, §T4).

## QD3-Specific T3 Extension Rules

### T3.5 — ADR-22 Rule 6 audit (NO cache)

```bash
# Verify lane-status.json reflects no cache used
CACHE_HITS=$(jq '.cache.cache_hits // 0' "$LANE_DIR/lane-status.json")
CACHE_MISSES=$(jq '.cache.cache_misses // 0' "$LANE_DIR/lane-status.json")
CACHE_ENABLED=$(jq '.cache.enabled // false' "$LANE_DIR/lane-status.json")

if [ "$CACHE_ENABLED" != "false" ] || [ "$CACHE_HITS" -gt 0 ] || [ "$CACHE_MISSES" -gt 0 ]; then
  echo "T3 FAIL: ADR-22 Rule 6 violation — QD3 cache enabled hoac co cache hits/misses (enabled=$CACHE_ENABLED, hits=$CACHE_HITS, misses=$CACHE_MISSES)" >&2
  return 1
fi
```

### T3.6 — CDG flag enforcement cho secret detection

P-QD3-secret-detection signals PHẢI có `cdg_flags` chứa `CDG-SECURITY-LIVE` (per CORE-027):

```bash
SECRET_NO_CDG=$(jq '[.signals[] | select(.probe_id == "P-QD3-secret-detection") | select((.cdg_flags // []) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$SECRET_NO_CDG" = "0" ] || {
  echo "T3 FAIL: $SECRET_NO_CDG secret-detection signals thieu cdg_flags (CORE-027 CDG required)" >&2; return 1;
}
```

### T3.7 — CRITICAL severity validation

QD3 CRITICAL signals (auth bypass, SQL injection, hard-coded secret) PHẢI có:
- `evidence` ≥ 1 entry với pattern_matched hoặc http_trace
- `remediation.suggested_action` non-empty (mitigation_hint)

```bash
CRITICAL_NO_REMEDIATION=$(jq '[.signals[] | select(.severity == "critical") | select((.remediation.suggested_action // "") | length < 10)] | length' "$LANE_DIR/signals.json")
[ "$CRITICAL_NO_REMEDIATION" = "0" ] || {
  echo "T3 FAIL: $CRITICAL_NO_REMEDIATION critical security signals thieu mitigation_hint" >&2; return 1;
}
```

### T3.8 — Mitigation hint required (mọi severity)

```bash
NO_MITIGATION=$(jq '[.signals[] | select((.remediation.suggested_action // "") == "")] | length' "$LANE_DIR/signals.json")
TOTAL=$(jq '.signals | length' "$LANE_DIR/signals.json")
[ "$NO_MITIGATION" -le "$((TOTAL / 4))" ] || {
  echo "T3 WARN: $NO_MITIGATION/$TOTAL security signals thieu mitigation_hint (>25%)" >&2
}
```

## POST-GATE Pass Criteria

ALL T1-T4 + T3.5 ADR-22 audit PASS → status = `completed`.

## CORE-028 Phase Summary

Populate template với:

- `[DIMENSION]` = QD3, `[DIMENSION_NAME]` = "Security & Privacy"
- `[ADVICE]` = e.g. "$a critical issues (auth/secret/injection) can fix NGAY truoc release"

## Failure Handling

Theo `_shared/lane/post-gate.md`. CRITICAL security failures escalate qua CDG, không auto-fix.
