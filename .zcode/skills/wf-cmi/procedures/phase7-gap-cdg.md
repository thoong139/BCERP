# Phase 7 — GAP Detection + CDG (Auto-Suggest + Sidecar APPEND)

> **Đầu vào:** `coverage-matrix.json` + `business-invariants.json` (draft) + `signals-aggregated.jsonl` + `regression-map.json`
> **Đầu ra:** `gap-suggestions.json`, `gap-report.md`, `cdg-decisions.jsonl`, sidecar APPEND nếu CDG ACCEPT, `Phase7-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate:** 2-5 min (CDG block)
> **Required:** ✅ (Final gate trước Phase 8)

---

## §A Header

Phase 7 detect GAPs từ Phase 5-6 outputs, generate artifact suggestions (test_case, invariant_rule, contract, doc_snippet), gate qua CDG decisions, sync accepted invariants vào canonical sidecar `business-invariants.json`.

**Mode:** HYBRID — Spawn `business-analyst` + 1-3 `{domain}-experts` cho gap suggestions, then user CDG decisions.

**4 suggestion kinds:**
- `test_case` — test case mới (target test file path)
- `invariant_rule` — invariant mới với expression + source_doc + verified_by
- `contract` — API/event/event contract mới
- `doc_snippet` — đoạn doc tiếng Việt mô tả invariant/dependency

**CDG gates:**
- E094 Sidecar APPEND confirm (max 2 reject → ESCALATE)
- E095 Multi-user dual-approval (Dev A approved → Dev B confirm cho MUST invariant)

**Shared sections cần load:**
- `_shared.md §1, §3, §14 R/W Lock, §15 Agent Prompts, §17 Author, §18 CDG Token, §19 Audit Chain`

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Coverage matrix + invariants + signals đầy đủ | bash | **E070** — Phase 5-6 outputs missing → re-run prerequisite |
| T2 | CDG protocol available (`--ci` mode bypass CDG) | composite | **E071** — CDG mode invalid trong --ci context → ESCALATE user fix args |
| T3 | Auto-suggest enabled? (check `$AUTO_SUGGEST` flag) | bash | — (info only, không fail) |
| T4 | Cross-domain conflict resolved (nếu Phase 3 raise E091) | bash | **E072** — Unresolved CDG → re-prompt (max 1), ESCALATE |

```bash
# T1
[ -f "$SESSION_DIR/phase5-aggregate/coverage-matrix.json" ] || die "E070" "Coverage matrix missing"
[ -f "$SESSION_DIR/phase3-invariants/business-invariants.json" ] || die "E070" "Invariants missing"
[ -f "$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl" ] || die "E070" "Signals aggregated missing"

# T2 — CI mode incompatibility
if [ "$CI_MODE" = "true" ] && [ "$AUTO_SUGGEST" = "true" ]; then
  die "E071" "--ci mutually exclusive với --auto-suggest"
fi

# T4 — Check unresolved cross-domain conflicts from Phase 3
CONFLICTS_FILE="$SESSION_DIR/phase3-invariants/conflicts.json"
if [ -f "$CONFLICTS_FILE" ] && [ "$(jq 'length' "$CONFLICTS_FILE")" -gt 0 ]; then
  UNRESOLVED=$(jq '[.[] | select(.resolved != true)] | length' "$CONFLICTS_FILE")
  [ "$UNRESOLVED" -gt 0 ] && log_warn "E072" "$UNRESOLVED unresolved cross-domain conflicts — will batch CDG E091"
fi
```

---

## §C Steps

### Step 7.1 — Load all upstream outputs

```bash
COVERAGE_MATRIX=$(cat "$SESSION_DIR/phase5-aggregate/coverage-matrix.json")
INVARIANTS=$(jq -r '.invariants' "$SESSION_DIR/phase3-invariants/business-invariants.json")
SIGNALS_AGG=$(jq -s '.' "$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl")
REGRESSION_MAP=$(cat "$SESSION_DIR/phase6-regression/regression-map.json" 2>/dev/null || echo '{}')

log_phase_event "phase7" "INFO" "{\"signals\":$(echo "$SIGNALS_AGG" | jq 'length'),\"invariants\":$(echo "$INVARIANTS" | jq 'length')}"
```

### Step 7.2 — GAP detection per dim

> Mỗi dim FAIL_THRESHOLD → identify root cause patterns.

```bash
GAPS_PER_DIM="[]"

for dim in CD1 CD2 CD3 CD4 CD5 CD6 CD7 CD8 CD9 CD10; do
  STATUS=$(echo "$COVERAGE_MATRIX" | jq -r --arg d "$dim" '.dimensions[$d].status // "N/A"')
  [ "$STATUS" != "FAIL_THRESHOLD" ] && continue

  # Find violation signals for this dim
  DIM_VIOLATIONS=$(echo "$SIGNALS_AGG" | jq --arg d "$dim" \
                   '[.[] | select(.dim == $d and .category == "VIOLATION")]')

  # Root cause analysis: cluster by category
  ROOT_CAUSES=$(echo "$DIM_VIOLATIONS" | jq 'group_by(.category) | map({category: .[0].category, count: length})')

  GAPS_PER_DIM=$(jq -n --argjson g "$GAPS_PER_DIM" --arg d "$dim" --argjson rc "$ROOT_CAUSES" \
                 --argjson dv "$DIM_VIOLATIONS" \
                 '$g + [{dim: $d, violation_count: ($dv | length), root_causes: $rc, signals: $dv}]')
done
```

### Step 7.3 — Spawn triage agent (business-analyst orchestrate)

> Reference: `docs/04-skill-design/wf-cmi/agent-prompt.md §13`.

```
Agent({
  subagent_type: "business-analyst",
  description: "Phase 7 Triage — gap detection + CDG suggestions",
  model: "opus",
  prompt: <render từ agent-prompt.md §13 với 8 sections>
})
```

**Render input cho agent (substitution placeholders):**

| Placeholder | Value |
|-------------|-------|
| `{SESSION_DIR}` | `$SESSION_DIR` |
| `{COVERAGE_MATRIX_PATH}` | `$SESSION_DIR/phase5-aggregate/coverage-matrix.json` |
| `{INVARIANTS_PATH}` | `$SESSION_DIR/phase3-invariants/business-invariants.json` |
| `{SIGNALS_AGG_PATH}` | `$SESSION_DIR/phase5-aggregate/signals-aggregated.jsonl` |
| `{REGRESSION_MAP_PATH}` | `$SESSION_DIR/phase6-regression/regression-map.json` |
| `{AUTO_SUGGEST}` | `$AUTO_SUGGEST` |
| `{DRY_RUN}` | `$DRY_RUN` |
| `{AUTHOR}` | `$AUTHOR_NAME <$AUTHOR_EMAIL>` |
| `$CI_CONTEXT` | rendered từ §4 |

**Expected output (agent ghi vào `gap-suggestions.json` qua orchestrator):**

```json
{
  "$schema": "gap-suggestions-v1",
  "session_id": "...",
  "suggestions": [
    {
      "id": "CMI-S-001",
      "kind": "test_case|invariant_rule|contract|doc_snippet",
      "title": "Thêm test cho Customer.SalesOwner validation",
      "description": "...",
      "target_path": "tests/backend/Eureka.UnitTests/CRM/CreateCustomerValidatorTests.cs",
      "source_signal_ids": ["sig-001", "sig-042"],
      "confidence": 0.85,
      "severity": "MUST|SHOULD|MAY",
      "status": "proposed",
      "linked_invariant_id": "INV-CRM-001",
      "rationale": "Coverage CD9 dưới ngưỡng do thiếu test cho FK customer.sales_owner."
    }
  ]
}
```

**Concurrency:** Triage agent có thể spawn 1-3 `{domain}-experts` parallel cho domain-specific suggestions (managed by orchestrator, không bởi triage agent).

### Step 7.4 — Generate gap suggestions per kind

> Nếu `--auto-suggest` flag → trigger CDG E094 batch ngay sau.

```bash
TARGET="$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json"
# Triage agent đã write target ở Step 7.3 — verify schema
jq -e '."$schema" == "gap-suggestions-v1"' "$TARGET" >/dev/null \
  || { log_phase_fail "E073" "gap-suggestions.json invalid"; }

SUGGESTION_COUNT=$(jq '.suggestions | length' "$TARGET")
INVARIANT_SUGG_COUNT=$(jq '[.suggestions[] | select(.kind == "invariant_rule")] | length' "$TARGET")
TEST_SUGG_COUNT=$(jq '[.suggestions[] | select(.kind == "test_case")] | length' "$TARGET")

log_phase_event "phase7" "INFO" \
  "{\"suggestions\":$SUGGESTION_COUNT,\"invariants\":$INVARIANT_SUGG_COUNT,\"tests\":$TEST_SUGG_COUNT}"
```

### Step 7.5 — CDG E094 (Sidecar APPEND confirm) — nếu `--auto-suggest`

> Trigger nếu user request auto-suggest VÀ có invariant suggestions accepted.

```
IF $AUTO_SUGGEST = true AND $INVARIANT_SUGG_COUNT > 0 AND $CI_MODE != true:
  AskUserQuestion:
    "Sẽ APPEND $INVARIANT_SUGG_COUNT invariants mới vào canonical sidecar
     .mc-data/work/wf-cmi/business-invariants.json:
       - $(list top 3 invariant.id + severity)
       - ... ($((INVARIANT_SUGG_COUNT - 3)) khác)

     Sidecar artifact đã có $(EXISTING_INVARIANT_COUNT) invariants existing.
     APPEND-only — không ghi đè existing.

     Confirm?"
    Options:
      1. Confirm APPEND ($INVARIANT_SUGG_COUNT)
      2. Confirm only HIGH confidence (≥0.8)
      3. Cancel

  Default: ABORT (option 3)
  Anti-loop: max 2 reject → ESCALATE E094

  Save: CDG_E094_DECISION="full|high_only|cancel"
  append_cdg_token "phase7-gap-cdg" "E094-Sidecar-APPEND" "$CDG_E094_DECISION"
```

### Step 7.6 — Sync accepted invariants → canonical sidecar (APPEND)

> Acquire WRITE lock cho `business-invariants` resource (Protocol 22).

```bash
if [ "$CDG_E094_DECISION" = "full" ] || [ "$CDG_E094_DECISION" = "high_only" ]; then
  # Acquire write lock (cross-session R/W lock)
  acquire_write_lock business-invariants

  CANONICAL=".mc-data/work/wf-cmi/business-invariants.json"

  # Init canonical if not exists
  if [ ! -f "$CANONICAL" ]; then
    cat > "$CANONICAL" <<EOF
{
  "\$schema": "business-invariants-v1",
  "artifact_version": "1.0.0",
  "generated_at": "$(date -Iseconds)",
  "generated_by": "wf-cmi",
  "scope": {"type": "system"},
  "invariants": [],
  "cross_module_dependencies": [],
  "audit_chain": {
    "source_registry_checksum": "",
    "source_registry_path": ".mc-data/docs/_meta/req-registry.json",
    "checksum": ""
  }
}
EOF
  fi

  # Filter suggestions to invariants (accepted)
  if [ "$CDG_E094_DECISION" = "full" ]; then
    NEW_INVARIANTS=$(jq '[.suggestions[] | select(.kind == "invariant_rule" and .status != "rejected")]' "$TARGET")
  else
    NEW_INVARIANTS=$(jq '[.suggestions[] | select(.kind == "invariant_rule" and .confidence >= 0.8)]' "$TARGET")
  fi

  # Transform suggestion → invariant schema
  NEW_INVARIANTS=$(echo "$NEW_INVARIANTS" | jq --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
    --arg ae "$AUTHOR_EMAIL" \
    '[.[] | {
       id: .linked_invariant_id // .id,
       kind: "invariant",
       expression: .description,
       severity: .severity,
       modules_involved: (.affected_modules // []),
       source_doc: (.source_doc // ""),
       verified_by: [],
       inferred_by: {skill: "wf-cmi", session_id: $sid, confidence: .confidence},
       status: "accepted",
       approver: $ae,
       approved_at: $ts
     }]')

  # APPEND to canonical (NO override existing)
  jq --argjson new "$NEW_INVARIANTS" \
     '.invariants += $new | .invariants |= unique_by(.id)' \
     "$CANONICAL" > "$CANONICAL.tmp.$$" && mv "$CANONICAL.tmp.$$" "$CANONICAL"

  # Update audit_chain.source_registry_checksum
  build_sidecar_audit_chain  # from _shared.md §19

  # Release lock
  release_write_lock business-invariants

  APPENDED_COUNT=$(echo "$NEW_INVARIANTS" | jq 'length')
  log_phase_event "phase7" "INFO" "{\"sidecar_appended\":$APPENDED_COUNT}"
fi
```

### Step 7.7 — Multi-user dual-approval (CDG E095) — nếu MUST invariants từ peer

> Check nếu có invariant MUST đã được Dev A approve trong session khác, cần Dev B approve.

```bash
# Find peer-approved MUST invariants chưa có dual approval
PEER_MUST=$(jq --arg me "$AUTHOR_EMAIL" \
            '[.invariants[] | select(.severity == "MUST" and .approver != $me and .dual_approver == null)]' \
            .mc-data/work/wf-cmi/business-invariants.json 2>/dev/null || echo "[]")

PEER_MUST_COUNT=$(echo "$PEER_MUST" | jq 'length')

if [ "$PEER_MUST_COUNT" -gt 0 ] && [ "$CI_MODE" != "true" ]; then
  # AskUserQuestion per invariant (hoặc batch nếu >5)
  for inv in $(echo "$PEER_MUST" | jq -c '.[]' | head -5); do
    INV_ID=$(echo "$inv" | jq -r '.id')
    INV_EXPR=$(echo "$inv" | jq -r '.expression')
    INV_APPROVER=$(echo "$inv" | jq -r '.approver')

    # AskUserQuestion:
    #   "$INV_APPROVER approved invariant $INV_ID ($INV_EXPR).
    #    Bạn ($AUTHOR_EMAIL) approve để commit vào sidecar?"
    #   Options: Approve / Defer / Reject
    #   Default: Defer

    # Save decision
    append_cdg_token "phase7-gap-cdg" "E095-Dual-Approval-$INV_ID" "$DECISION"
  done
fi
```

### Step 7.8 — Build gap-suggestions.json + gap-report.md

> gap-suggestions.json đã ghi ở Step 7.3-7.4 bởi triage agent. Verify final state + add status updates.

```bash
# Update status sau CDG (accepted/rejected/deferred)
jq --arg dec "$CDG_E094_DECISION" \
   'if $dec == "full" then .suggestions = (.suggestions | map(. + {final_status: "accepted"}))
    elif $dec == "high_only" then .suggestions = (.suggestions | map(
      if .confidence >= 0.8 then . + {final_status: "accepted"}
      else . + {final_status: "proposed"} end))
    else .suggestions = (.suggestions | map(. + {final_status: "rejected"})) end' \
   "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"

# gap-report.md (tiếng Việt ≤30 dòng)
TPL_GAP=".claude/skills/workflow/wf-cmi/templates/gap-report.md"
GAP_REPORT="$SESSION_DIR/phase7-gap-cdg/gap-report.md"

ACCEPTED=$(jq '[.suggestions[] | select(.final_status == "accepted")] | length' "$TARGET")
REJECTED=$(jq '[.suggestions[] | select(.final_status == "rejected")] | length' "$TARGET")
DEFERRED=$(jq '[.suggestions[] | select(.final_status == "proposed")] | length' "$TARGET")

sed -e "s|\[SUGGESTION_COUNT\]|$SUGGESTION_COUNT|g" \
    -e "s|\[ACCEPTED\]|$ACCEPTED|g" \
    -e "s|\[REJECTED\]|$REJECTED|g" \
    -e "s|\[DEFERRED\]|$DEFERRED|g" \
    -e "s|\[INVARIANT_COUNT\]|$INVARIANT_SUGG_COUNT|g" \
    -e "s|\[TEST_COUNT\]|$TEST_SUGG_COUNT|g" \
    -e "s|\[CDG_DECISION\]|${CDG_E094_DECISION:-not-triggered}|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    "$TPL_GAP" > "$GAP_REPORT"

[ "$(wc -l < "$GAP_REPORT")" -le 30 ] || log_warn "E084" "gap-report.md >30 dòng"
```

### Step 7.9 — Cross-domain conflict resolution (carry over từ Phase 3)

> Resolve Phase 3 E091 conflicts qua CDG batch.

```bash
if [ -f "$SESSION_DIR/phase3-invariants/conflicts.json" ]; then
  CONFLICT_COUNT=$(jq 'length' "$SESSION_DIR/phase3-invariants/conflicts.json")
  if [ "$CONFLICT_COUNT" -gt 0 ] && [ "$CI_MODE" != "true" ]; then
    # AskUserQuestion batch — per conflict (max 5)
    for conflict in $(jq -c '.[]' "$SESSION_DIR/phase3-invariants/conflicts.json" | head -5); do
      CONF_ID=$(echo "$conflict" | jq -r '.id')
      OPINIONS=$(echo "$conflict" | jq -r '.opinions | map("\(.dept): \(.expression) (severity=\(.severity))") | join(" | ")')

      # AskUserQuestion:
      #   "Invariant $CONF_ID conflict giữa $OPINIONS.
      #    Chọn:"
      #   Options: A (option 1) / B (option 2) / Defer
      #   Default: Defer

      append_cdg_token "phase7-gap-cdg" "E091-Conflict-$CONF_ID" "$DECISION"
    done
  fi
fi
```

### Step 7.10 — Write Phase7-report.md (CORE-028)

```bash
TPL=".claude/skills/workflow/wf-cmi/templates/Phase7-report.md"

SIDECAR_NOTE=""
[ -n "${APPENDED_COUNT:-}" ] && SIDECAR_NOTE="- Đã APPEND $APPENDED_COUNT invariants vào sidecar artifact"

sed -e "s|\[SUGGESTION_COUNT\]|$SUGGESTION_COUNT|g" \
    -e "s|\[ACCEPTED\]|$ACCEPTED|g" \
    -e "s|\[REJECTED\]|$REJECTED|g" \
    -e "s|\[SIDECAR_NOTE\]|$SIDECAR_NOTE|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|PASS|g" \
    "$TPL" > "$SESSION_DIR/phase7-gap-cdg/Phase7-report.md"
```

### Step 7.11 — Loop-back từ Phase 10 (v3.0 NEW)

> **Trigger:** Phase 10 (session trước hoặc session hiện tại nếu re-run) đã APPEND `gap-suggestions.json` với kind=`e2e_scenario_fix`.
> **Mục đích:** Detect + summarize loop-back suggestions cho user review. KHÔNG re-trigger CD41 (anti-loop guard).
> **Consumer behavior:** Khi Phase 7 chạy ở session **kế tiếp** sau Phase 10, sẽ đọc `e2e_scenario_fix` suggestions như loại suggestion khác (test_case/invariant_rule) cho user accept/reject.

```bash
# Step 7.11 — Check loop-back suggestions from previous Phase 10
LOOPBACK_COUNT=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix")] | length' "$TARGET" 2>/dev/null || echo 0)

if [ "$LOOPBACK_COUNT" -gt 0 ]; then
  log_phase_event "phase7" "INFO" "{\"loopback_from_phase10\":$LOOPBACK_COUNT}"

  # Loop-back suggestions đã có sẵn trong gap-suggestions.json (Phase 10 APPEND-only ở session trước)
  # Bucket theo confidence để user dễ review
  E2E_AUTO_CORRECTED=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence >= 0.85)] | length' "$TARGET")
  E2E_UNRESOLVED=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence <= 0.30)] | length' "$TARGET")
  E2E_MANUAL=$(jq '[.suggestions[] | select(.kind == "e2e_scenario_fix" and .confidence > 0.30 and .confidence < 0.85)] | length' "$TARGET")

  echo "Phase 10 loop-back: $LOOPBACK_COUNT suggestions ($E2E_AUTO_CORRECTED high-confidence auto-corrected, $E2E_MANUAL medium, $E2E_UNRESOLVED low/unresolved)"

  # Anti-loop guard: KHÔNG re-trigger CD41 synth
  # CD41 chỉ chạy 1 lần / session (Phase 4 Wave 3 dispatch). E2E loop-back suggestions chỉ enrich gap-report.md
  # User có thể manual apply scenarios qua wf-implement-feature hoặc edit trực tiếp test-scenario.md

  # APPEND E2E section vào gap-report.md (sau Step 7.8 đã render)
  E2E_LOOPBACK_SECTION="
## E2E Loop-back Suggestions (từ Phase 10)

- Tổng: $LOOPBACK_COUNT suggestions kind=e2e_scenario_fix
- Auto-corrected (confidence ≥0.85): $E2E_AUTO_CORRECTED
- Manual review (0.30 < confidence < 0.85): $E2E_MANUAL
- Unresolved (confidence ≤0.30): $E2E_UNRESOLVED

Action: Xem chi tiết tại \`phase10-e2e-resolution/resolution-report.md\`. Re-run wf-cmi --exec-scenarios session sau để verify scenarios đã sửa.
"
  GAP_REPORT="$SESSION_DIR/phase7-gap-cdg/gap-report.md"
  [ -f "$GAP_REPORT" ] && echo "$E2E_LOOPBACK_SECTION" >> "$GAP_REPORT"
fi
```

**Guard rules (BẮT BUỘC — anti-loop):**
1. APPEND CHỈ `kind=e2e_scenario_fix` từ Phase 10 — không bao giờ generate kind khác (test_case/invariant_rule/contract/doc_snippet/validation_rule) từ Phase 10 source.
2. KHÔNG re-trigger CD41 synth — CD41 chỉ chạy ở Phase 4 Wave 3 nếu profile=deep|exhaustive. Phase 10 loop-back KHÔNG bao giờ re-spawn CD41.
3. Schema gap-suggestions vẫn `gap-suggestions-v1` — KHÔNG bump version (chỉ thêm value cho field `kind` enum).
4. Per-session, mỗi scenario synth 1 lần — tránh infinite loop CD41 → Phase 9 → Phase 10 → CD41 → ...

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | `gap-report.md` + `gap-suggestions.json` exist | Re-detect |
| T2 | CDG decisions log đầy đủ (mỗi suggestion có user decision OR auto-defer nếu --ci) | Re-prompt CDG (max 1), ESCALATE |
| T3 | Accepted suggestions có actionable artifact (test/contract/invariant target path) | Re-generate suggestion (E074) |
| T4 | Rejected suggestions có audit log (lý do trong cdg-decisions.jsonl) | Re-record |

```bash
post_gate_phase7() {
  local target="$SESSION_DIR/phase7-gap-cdg/gap-suggestions.json"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] && [ -f "$SESSION_DIR/phase7-gap-cdg/gap-report.md" ] \
      || { redetect_gaps; retry=$((retry+1)); continue; }

    # T2 — CDG decisions log
    if [ "$AUTO_SUGGEST" = "true" ] && [ "$CI_MODE" != "true" ]; then
      [ -f "$SESSION_DIR/phase7-gap-cdg/cdg-tokens.json" ] \
        || { reprompt_cdg; retry=$((retry+1)); continue; }
    fi

    # T3 — accepted có actionable target
    actionable_missing=$(jq '[.suggestions[] | select(.final_status == "accepted" and
                                                       (.target_path == null or .target_path == ""))] | length' "$target")
    [ "$actionable_missing" -gt 0 ] && { log_warn "E074" "$actionable_missing accepted suggestions missing target"; }

    # T4 — rejected có audit log
    rejected_count=$(jq '[.suggestions[] | select(.final_status == "rejected")] | length' "$target")
    if [ "$rejected_count" -gt 0 ]; then
      logged_count=$(jq -s 'length' "$SESSION_DIR/phase7-gap-cdg/cdg-decisions.jsonl" 2>/dev/null || echo 0)
      [ "$logged_count" -lt "$rejected_count" ] && { rerecord_audit; retry=$((retry+1)); continue; }
    fi

    return 0
  done
  die "E001" "Phase 7 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 7
2. Update `integrity-status.json`:
   - `.phases_completed += [7]`
   - `.current_phase = 8`
3. TodoWrite: Phase 7 = completed, Phase 8 = in_progress

---

## §E Phase Report Template (CORE-028)

```markdown
## Phase 7: Phát hiện GAP + đề xuất bổ sung — PASS
Thời gian: 2026-05-15T14:54:30+07:00

**Đã làm:**
- Phát hiện 23 GAP từ coverage matrix + signals + regression
- Sinh đề xuất artifact bổ sung (test, invariant, contract, doc)

**Kết quả:**
- Tổng đề xuất: 23 (Test: 12 | Invariant: 8 | Contract: 2 | Doc: 1)
- User accept: 18 | Reject: 3 | Defer: 2
- [SIDECAR_NOTE]

**Tiếp theo:**
- Phase 8 — Báo cáo cuối + sinh artifact cross-skill (30s)
```

---

## §F Error Code Quick Reference (Phase 7 namespace E070-E079)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E070 | high | Phase 5-6 outputs missing | Re-run prerequisite |
| E071 | high | CDG mode invalid trong --ci | ESCALATE user fix args |
| E072 | high | Unresolved CDG decision blocking Phase 7 | Re-prompt CDG (max 1), ESCALATE |
| E073 | medium | Suggestion generation fail (LLM error) | Retry x1, skip |
| E074 | medium | Suggestion missing actionable target | Re-generate |
| E075 | medium | User REJECT all suggestions | INFO log, no auto-fix |
| E076 | medium | Suggestion duplicate of existing | DROP, WARN |
| E077 | low | Suggestion confidence below threshold | Mark proposed, no auto-accept |
| E078 | medium | Approver chain missing | ESCALATE manual review |
| E079 | low | CDG decision log corruption | Retry write, ESCALATE |
| E094 | high | Sidecar APPEND confirm | AskUser: Confirm/HighOnly/Cancel, max 2 reject |
| E095 | medium | Multi-user dual approval (Dev B confirm) | AskUser: Approve/Defer/Reject |
| E091 | medium | Cross-domain conflict resolution (batch) | AskUser: A/B/Defer, max 2 reject |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §14 R/W Lock, §15 Agent Prompts, §17 Author, §18 CDG Token, §19 Audit Chain |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §3 Cross-skill contract, §6 Business invariants APPEND |
| `docs/04-skill-design/wf-cmi/agent-prompt.md` | §13 Triage agent prompt template |
| `templates/gap-suggestions.json`, `gap-report.md` | Templates |
| `_contract.json §outputs.working[]` | Phase 7 paths + canonical sidecar path |

---

## §H Next

Phase 7 PASS → Read `procedures/phase8-report.md` cho final report + cross-skill artifact `integrity-impact.json`.
