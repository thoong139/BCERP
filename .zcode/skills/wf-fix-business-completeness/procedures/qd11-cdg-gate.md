# QD11 CDG Gate — Enhancement Suggestions ACCEPT/REJECT

> Procedure này mô tả CDG gate logic cho QD11 enhancement suggestions.
> QD11 PHẢI có CDG gate vì enhancement suggestions là BUSINESS DECISION, không phải auto-fix.
> Reference: Protocol 16 (Critical Decision Gate).

## Trigger

CDG gate được trigger khi `phase4-find-bugs/lanes/QD11-business-completeness/signals.json` có signals với severity ∈ {HIGH, CRITICAL}.
MEDIUM/LOW signals được auto-accept (không cần CDG).

## Gate Flow

### Step 1: Collect CDG signals

```bash
SIGNALS_FILE="$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/signals.json"
CDG_SIGNALS=$(jq '[.signals[] | select(.severity == "HIGH" or .severity == "CRITICAL")]' "$SIGNALS_FILE")
CDG_COUNT=$(jq 'length' <<< "$CDG_SIGNALS")
```

Nếu `CDG_COUNT == 0` → skip CDG gate, auto-accept all.

### Step 2: Render CDG menu

Hiển thị danh sách enhancement suggestions với:

| Field | Source |
|-------|--------|
| Signal type | `.signal_type` |
| Severity | `.severity` |
| Title | `.title` |
| Description | `.description` |
| Pass | `.probe_id` (Pass 1/2/3) |
| Suggestion | `.suggestion` |

### Step 3: User quyết định per-signal

Với mỗi signal có severity HIGH/CRITICAL, hỏi user:

```
[CDG-QD11] Enhancement Suggestion #N:
  Type: MISSING_FIELD
  Severity: HIGH
  Title: [title]
  Description: [description]
  Suggestion: [suggestion]

  Accept (A) / Reject (R) / Defer (D)?
```

- **Accept (A):** Chấp nhận suggestion → add vào enhancement-suggestions.json với `status=accepted`. Suggestion được pass cho wf-fix-execute để implement.
- **Reject (R):** Từ chối suggestion → ghi `status=rejected` + `reject_reason` (user-provided).
- **Defer (D):** Hoãn lại → ghi `status=deferred` + `defer_reason`. Không block workflow.

### Step 4: Write enhancement-suggestions.json

```jsonc
{
  "$schema": "enhancement-suggestions-v1",
  "session_id": "<SESSION_ID>",
  "dimension": "QD11",
  "generated_at": "<ISO8601>",
  "total_signals": N,
  "cdg_required_count": M,
  "suggestions": [
    {
      "signal_id": "<signal fingerprint>",
      "signal_type": "MISSING_FIELD",
      "severity": "HIGH",
      "probe_id": "P-QD11-cross-module-comparison",
      "title": "...",
      "description": "...",
      "suggestion": "...",
      "decision": "accepted|rejected|deferred",
      "decision_reason": "...",
      "decided_at": "<ISO8601>"
    }
  ],
  "summary": {
    "accepted": A,
    "rejected": R,
    "deferred": D
  }
}
```

### Step 5: Write CDG tokens

Ghi accept/reject tokens vào `$SESSION_DIR/cdg-tokens.json`:

```bash
jq --argjson qd11_cdg "$CDG_DECISIONS" \
  '.cdg_tokens.qd11_enhancement = $qd11_cdg' \
  "$SESSION_DIR/cdg-tokens.json" > "$SESSION_DIR/.cdg-tokens.tmp.$$" \
  && mv "$SESSION_DIR/.cdg-tokens.tmp.$$" "$SESSION_DIR/cdg-tokens.json"
```

## Anti-Loop Guard

- Max 2 CDG cycles cho QD11 — nếu user reject 2 lần liên tiếp → force Accept với warning
- Ghi `cdg_reject_counts.qd11` vào fix-status.json

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E111 | enhancement-suggestions.json schema invalid | Retry POST-GATE T1-T4 |
| E112 | CDG gate timeout (user không respond) | Defer all, continue workflow |
| E113 | Anti-loop: 2 consecutive rejects | Force accept, log warning |

## Integration

- **wf-fix-execute** đọc `enhancement-suggestions.json` → implement accepted suggestions
- **wf-fix-triage** include accepted suggestions trong fix-plan.md
- **fix-impact.json** ghi `qd11_enhancements_accepted` count
