# POST-GATE — wf-fix-performance (QD4 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-performance"
DIMENSION="QD4"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md`.

## QD4-Specific T3 Extension Rules

### T3.5 — Performance metric thresholds

QD4 signals PHẢI có metric value trong evidence để justify severity. Validate severity rules:

```bash
# CRITICAL: LCP > 4s, INP > 500ms, page crash
# HIGH: LCP 2.5-4s, API p95 > 1000ms, N+1 confirmed, bundle > 500KB gzip
# MEDIUM: bundle > 250KB, query > 1s, missing memoization
# LOW: minor optimizations

# Mọi signal severity != "info" PHẢI có evidence type ∈ {lighthouse_score, latency_stats, query_plan, bundle_analysis}
PERF_NO_METRIC=$(jq '[.signals[] | select(.severity != "info") | select((.evidence // []) | map(select(.type == "code" or .type == "log" or .type == "stdout" or .type == "trace")) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$PERF_NO_METRIC" = "0" ] || {
  echo "T3 WARN: $PERF_NO_METRIC perf signals thieu metric evidence (lighthouse_score/latency_stats/query_plan)" >&2
}
```

### T3.6 — Severity threshold consistency

```bash
# CRITICAL signals phải mention "LCP > 4s" hoặc "crash" hoặc "p99 > 5s" trong description
CRITICAL_INCONSISTENT=$(jq '[.signals[] | select(.severity == "critical") | select(.description | test("LCP|p99|crash|timeout|outage"; "i") | not)] | length' "$LANE_DIR/signals.json")
[ "$CRITICAL_INCONSISTENT" = "0" ] || {
  echo "T3 WARN: $CRITICAL_INCONSISTENT critical signals khong mention metric threshold" >&2
}

# HIGH signals phải mention metric range trong description
HIGH_INCONSISTENT=$(jq '[.signals[] | select(.severity == "high") | select(.description | test("LCP|p95|N\\+1|bundle|>|ms|s\\b"; "i") | not)] | length' "$LANE_DIR/signals.json")
[ "$HIGH_INCONSISTENT" -le 2 ] || {
  echo "T3 WARN: $HIGH_INCONSISTENT high signals khong mention metric range" >&2
}
```

### T3.7 — Bundle size signals require numeric value

```bash
BUNDLE_NO_SIZE=$(jq '[.signals[] | select(.probe_id == "P-QD4-bundle-size-audit") | select(.description | test("[0-9]+\\s*(KB|MB|kb|mb)") | not)] | length' "$LANE_DIR/signals.json")
[ "$BUNDLE_NO_SIZE" = "0" ] || {
  echo "T3 WARN: $BUNDLE_NO_SIZE bundle-size signals thieu numeric KB/MB value trong description" >&2
}
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template với:

- `[DIMENSION]` = QD4, `[DIMENSION_NAME]` = "Performance & Efficiency"
- `[ADVICE]` = e.g. "Bundle hien tai $X KB > threshold 500KB — uu tien split/lazy load"

## Failure Handling

Theo `_shared/lane/post-gate.md`. Runtime probe fail (lighthouse/k6 unavailable) → graceful skip, mark probe `skipped`.
