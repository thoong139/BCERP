# POST-GATE — wf-fix-functional (QD1 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1 (signal-v2), §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-functional"
DIMENSION="QD1"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md`:

| Tier | Check | Reference |
|------|-------|-----------|
| **T1** Existence | 4/4 required files non-empty | §"T1 — Existence Check" |
| **T2** Structure | $schema, fields, sections, headings | §"T2 — Structure Check" |
| **T3** Content | Per-signal v2 fields, fingerprint unique, totals consistent | §"T3 — Content Depth" |
| **T4** Cross-reference | location.file exists, REQ-IDs valid, probes declared | §"T4 — Cross-reference Check" |

## QD1-Specific T3 Extension Rules

### T3.5 — QD1 Content Depth Rules

Lane QD1 yêu cầu thêm:

```bash
# Mỗi signal QD1 PHẢI có dimension_id == "QD1"
INVALID_DIM=$(jq '[.signals[] | select(.dimension_id != "QD1")] | length' "$LANE_DIR/signals.json")
[ "$INVALID_DIM" = "0" ] || {
  echo "T3 FAIL: $INVALID_DIM signals voi dimension_id != QD1" >&2; return 1;
}

# Coverage gap signals PHAI co registry_refs.req_ids hoac feat_ids
COVERAGE_GAPS=$(jq '[.signals[] | select(.probe_id == "P-QD1-req-registry-xref" and (.title | test("coverage_gap|impl_status")))] | length' "$LANE_DIR/signals.json")
COVERAGE_GAPS_NO_REFS=$(jq '[.signals[] | select(.probe_id == "P-QD1-req-registry-xref" and (.title | test("coverage_gap|impl_status")) and (.registry_refs.req_ids // [] | length == 0) and (.registry_refs.feat_ids // [] | length == 0))] | length' "$LANE_DIR/signals.json")
[ "$COVERAGE_GAPS_NO_REFS" -le "$((COVERAGE_GAPS / 5))" ] || {
  echo "T3 WARN: $COVERAGE_GAPS_NO_REFS coverage gaps thieu registry_refs (>20%)" >&2
}
```

### T3.6 — Runtime probe evidence

Runtime probes (infra-preflight, deep-ui-traversal, api-smoke) PHẢI có HTTP trace hoặc screenshot:

```bash
RUNTIME_PROBES=("P-QD1-infra-preflight" "P-QD1-deep-ui-traversal" "P-QD1-api-smoke")
for probe in "${RUNTIME_PROBES[@]}"; do
  RUNTIME_NO_EVIDENCE=$(jq --arg p "$probe" '[.signals[] | select(.probe_id == $p) | select((.evidence // []) | map(select(.type == "http_response" or .type == "screenshot" or .type == "trace")) | length == 0)] | length' "$LANE_DIR/signals.json")
  [ "$RUNTIME_NO_EVIDENCE" = "0" ] || {
    echo "T3 WARN: $probe co $RUNTIME_NO_EVIDENCE signals khong co http/screenshot/trace evidence" >&2
  }
done
```

## POST-GATE Pass Criteria

ALL T1-T4 PASS → status = `completed`. Nếu probes_failed > 0 → status = `partial`.

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Theo `_shared/lane/post-gate.md` §"CORE-028 Phase Summary" — populate template `_shared/lane/templates/phase-summary.md` với:

- `[DIMENSION]` = QD1, `[DIMENSION_NAME]` = "Functional Correctness"
- `[N]` = total signals, `[a/b/c/d/e]` = severity counts
- `[X/Y]` = probes_run/total, `[Z]` = probes_skipped
- `[mm]` = duration phút
- `[SUMMARY]` = e.g. "Phat hien $N issue functional, gom $a critical (infrastructure/endpoint)..."
- `[ADVICE]` = recommendation cho user (vd: "Triage trien khai sua trong fix-execute")

## Failure Handling

POST-GATE retry max 2 lần (theo `_shared/lane/post-gate.md`). Nếu fail → status = `partial` hoặc `failed`.
