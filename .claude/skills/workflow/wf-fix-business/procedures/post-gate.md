# POST-GATE — wf-fix-business (QD2 Lane)

> **Reference:** `_shared/lane/post-gate.md` (T1-T4 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §1, §5
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-business"
DIMENSION="QD2"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD2-business"
```

## Tier Validation Chuẩn (T1-T4)

Đọc và thực hiện đầy đủ theo `_shared/lane/post-gate.md` (§T1, §T2, §T3, §T4).

## QD2-Specific T3 Extension Rules

### T3.5 — Domain agent output validation (CORE-029)

Lane QD2 phụ thuộc vào agent findings (P-QD2-domain-expert-review, P-QD2-business-analyst-review). Mỗi agent signal PHẢI:

```bash
# Agent signals (probe_id contains "review") phai co domain field
AGENT_SIGNALS_NO_DOMAIN=$(jq '[.signals[] | select(.probe_id | test("review")) | select(.domain == null or .domain == "" or .domain == "general")] | length' "$LANE_DIR/signals.json")
[ "$AGENT_SIGNALS_NO_DOMAIN" = "0" ] || {
  echo "T3 WARN: $AGENT_SIGNALS_NO_DOMAIN agent signals thieu domain (must be specific business domain)" >&2
}

# Mọi agent signal phai co evidence type = "agent_output" hoac description >= 50 chars
AGENT_INVALID=$(jq '[.signals[] | select(.probe_id | test("review")) | select(((.evidence // []) | map(select(.type == "agent_output")) | length == 0) and (.description // "" | length < 50))] | length' "$LANE_DIR/signals.json")
[ "$AGENT_INVALID" = "0" ] || {
  echo "T3 FAIL: $AGENT_INVALID agent signals thieu agent_output evidence va description < 50 chars" >&2; return 1;
}
```

### T3.6 — Hard-coded value evidence

P-QD2-hardcoded-value-detect signals PHẢI có evidence type = "code" với code_snippet chứa hard-coded value:

```bash
HARDCODE_NO_CODE=$(jq '[.signals[] | select(.probe_id == "P-QD2-hardcoded-value-detect") | select((.evidence // []) | map(select(.type == "code")) | length == 0)] | length' "$LANE_DIR/signals.json")
[ "$HARDCODE_NO_CODE" = "0" ] || {
  echo "T3 FAIL: $HARDCODE_NO_CODE hardcoded-value signals thieu code evidence" >&2; return 1;
}
```

### T3.7 — Reference rule cross-check (deep+)

Calculation-check + domain-expert-review signals NÊN reference `.claude/references/team-expert/[domain]/`:

```bash
if [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; then
  CALC_NO_REF=$(jq '[.signals[] | select(.probe_id == "P-QD2-calculation-check") | select((.evidence // []) | map(select(.description | test("reference|formula|rule"))) | length == 0)] | length' "$LANE_DIR/signals.json")
  [ "$CALC_NO_REF" -le 2 ] || {
    echo "T3 WARN: $CALC_NO_REF calculation signals thieu reference_rule cross-ref" >&2
  }
fi
```

## POST-GATE Pass Criteria

Theo `_shared/lane/post-gate.md` §"POST-GATE Pass Criteria".

## CORE-028 Phase Summary

Populate template `_shared/lane/templates/phase-summary.md` với:

- `[DIMENSION]` = QD2, `[DIMENSION_NAME]` = "Business Correctness"
- `[ADVICE]` = e.g. "Cac calculation_error cap critical can fix truoc go-live"

## Failure Handling

Theo `_shared/lane/post-gate.md` §"Failure Handling".
