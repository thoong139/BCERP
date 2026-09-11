# Phase 3 — Invariant Artifact (3-pass LLM Infer)

> **Đầu vào:** 6 graphs từ Phase 2, `phase1-business/*.md`, `phase2-features/`, `req-registry.json` (read-only), `team-expert/{domain}/rules.md`
> **Đầu ra:** `business-invariants.json` (per-session DRAFT, status="proposed"), `invariants-diff.json` (optional), `Phase3-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate (standard profile):** 2-5 min
> **Required:** ✅ (Phase 4 cần business-invariants.json để dispatch CD1)

---

## §A Header

Phase 3 suy luận business invariants liên module qua **3-pass LLM inference** (kế thừa pattern QD11 trong wf-fix-bugs):

| Pass | Mục đích | Agent | Input |
|------|---------|-------|-------|
| **Pass 1** | Cross-module pattern compare — tìm FK A.field → B.field thiếu validation ở B | `architect` | `entity-graph.json` + `module-graph.json` |
| **Pass 2** | Domain heuristic — apply industry standards (HS Code, GAAP, GDPR) | `{domain}-experts` (parallel) | Pass 1 candidates + `team-expert/{domain}/rules.md` |
| **Pass 3** | Registry gap detection — invariant đã có trong docs nhưng chưa có code/test | `business-analyst` | Pass 2 + `req-registry.json` + `phase1-business/*.md` |

**Mode:** PARALLEL (max 5 domain experts concurrent — leave 5 budget cho Phase 4 retry).

**Profile rules:**
- `quick` — Heuristic only (skip Pass 2 + 3 LLM)
- `standard` — Pass 1 LLM, Pass 2 + 3 heuristic
- `deep` — 3-pass LLM đầy đủ
- `exhaustive` — 3-pass + cross-domain conflict resolution + LLM enhance per signal

**Shared sections cần load:**
- `_shared.md §1, §3, §14, §15, §18`

**Variant note:** Phase 3 đổi tên từ `phase3-invariant-registry.md` → `phase3-invariant-artifact.md` (ADR-cmi-002 Revised — sidecar artifact, KHÔNG bump registry).

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | 6 graphs từ Phase 2 exist + non-empty | bash + jq | **E030** — Discovery incomplete → re-run Phase 2 |
| T2 | `jq -e '.modules \| length > 0'` mỗi graph (entity, module, api) | jq | **E031** — Graphs empty → ESCALATE scope too narrow |
| T3 | Domain experts knowledge available: `.claude/references/team-expert/{domain}/rules.md` tồn tại cho domains in registry | bash | **E032** — Knowledge file missing → fallback business-analyst, WARN |
| T4 | Profile allows Phase 3 LLM (skip nếu quick + heuristic-only) | composite | **E033** — Profile-phase mismatch (auto-skip 3-pass LLM, info only) |

```bash
# T1
for g in entity-graph module-graph workflow-graph api-graph event-graph rbac-matrix; do
  [ -f "$SESSION_DIR/phase2-discovery/${g}.json" ] || die "E030" "Missing ${g}.json"
done

# T2
for g in entity-graph module-graph api-graph; do
  count=$(jq '[.nodes, .modules, .endpoints] | map(length // 0) | max' \
          "$SESSION_DIR/phase2-discovery/${g}.json")
  [ "$count" -lt 1 ] && die "E031" "${g}.json empty"
done

# T3 — Domain knowledge availability per registry department
ACTIVE_DEPTS=$(jq -r '.modules[].department' .mc-data/docs/_meta/req-registry.json | sort -u)
for dept in $ACTIVE_DEPTS; do
  knowledge=".claude/references/team-expert/${dept}/rules.md"
  [ -f "$knowledge" ] || log_warn "E032" "Domain expert knowledge missing: $dept"
done
```

---

## §C Steps

### Step 3.1 — Load 6 graphs into memory

```bash
ENTITY_GRAPH=$(cat "$SESSION_DIR/phase2-discovery/entity-graph.json")
MODULE_GRAPH=$(cat "$SESSION_DIR/phase2-discovery/module-graph.json")
WORKFLOW_GRAPH=$(cat "$SESSION_DIR/phase2-discovery/workflow-graph.json")
API_GRAPH=$(cat "$SESSION_DIR/phase2-discovery/api-graph.json")
EVENT_GRAPH=$(cat "$SESSION_DIR/phase2-discovery/event-graph.json")
RBAC_MATRIX=$(cat "$SESSION_DIR/phase2-discovery/rbac-matrix.json")
```

### Step 3.2 — Detect active domains từ registry

```bash
# Departments với ≥1 module trong scope hiện tại
if [ "$SCOPE_TYPE" = "system" ]; then
  ACTIVE_DEPTS=$(jq -r '.modules[].department' .mc-data/docs/_meta/req-registry.json | sort -u)
elif [ "$SCOPE_TYPE" = "module" ]; then
  ACTIVE_DEPTS=$(jq -r --arg m "$SCOPE_NAME" '.modules[] | select(.name == $m) | .department' \
                 .mc-data/docs/_meta/req-registry.json)
else
  # scope=feat → derive department từ FEAT-ID
  FEAT_DEPT=$(jq -r --arg f "$SCOPE_NAME" '.features[] | select(.id == $f) | .department' \
              .mc-data/docs/_meta/req-registry.json)
  ACTIVE_DEPTS="$FEAT_DEPT"
fi
export ACTIVE_DEPTS
log_phase_event "phase3" "INFO" "{\"active_depts\":\"$ACTIVE_DEPTS\"}"
```

### Step 3.3 — Heuristic invariant extraction (no LLM)

> Pattern match: FK references, FluentValidation rules, Result<T> Error codes — chạy luôn cho mọi profile.

```bash
HEURISTIC_INVARIANTS="[]"

# Pattern 1: FK in entity-graph → invariant "B.id must exist + active"
FK_CANDIDATES=$(echo "$ENTITY_GRAPH" | jq '[
  .edges[] | select(.kind == "fk") | {
    id: ("INV-" + (.from | ascii_upcase) + "-" + ((.to // "REF") | ascii_upcase) + "-FK"),
    kind: "invariant",
    expression: ("\(.from) → \(.to) FK enforced + target active"),
    severity: "MUST",
    modules_involved: [.from_module, .to_module] | unique,
    source: "heuristic-fk-pattern"
  }
]')

# Pattern 2: FluentValidation rules → invariant từ rules đã có
VALIDATOR_INVARIANTS=$(grep -rE 'RuleFor\(.*\).*\.(NotEmpty|MustAsync|Must)\(' apps/backend --include='*Validator.cs' 2>/dev/null \
  | jq -R 'capture("(?<f>[^:]+):.*RuleFor\\((?<r>[^)]+)\\)\\.(?<m>NotEmpty|MustAsync|Must)\\(")
            | {id: ("INV-VAL-" + (.r | gsub("[^a-zA-Z0-9]";""))),
               kind: "validation",
               expression: ("\(.r) \(.m)"),
               severity: "SHOULD",
               source: ("code:" + .f)}' \
  | jq -s '.')

HEURISTIC_INVARIANTS=$(jq -n --argjson fk "$FK_CANDIDATES" --argjson v "$VALIDATOR_INVARIANTS" \
                      '$fk + $v')
```

### Step 3.4 — Pass 1 LLM (Cross-Module Pattern Compare)

> Skip nếu `profile=quick`.

```
IF profile != quick:
  Spawn architect agent với prompt (CORE-037 8-section — xem agent-prompt.md §13):
    Task: "Tìm cross-module pattern A.field → B.field FK in entity-graph,
            phát hiện missing validation tại B (FK target not enforced).
            Output JSON list invariant candidates với confidence ∈ [0,1]."

  Agent({
    subagent_type: "architect",
    model: "opus",
    prompt: <rendered §13>
  })

  Pass1_output: candidates với fields {id, kind, expression, severity, modules_involved, confidence, source: "llm-pass1"}
```

**Concurrency:** 1 architect agent. Timeout 5 min (E034).

### Step 3.5 — Pass 2 LLM (Domain Heuristic — parallel domain experts)

> Skip nếu `profile=quick`. Concurrency max 5 (leave 5 budget cho Phase 4 retry).

```
FOR EACH dept in ACTIVE_DEPTS (max 5 parallel):
  Spawn {dept}-expert agent với prompt:
    Task: "Đọc Pass 1 candidates + team-expert/{dept}/rules.md.
            Lọc + bổ sung invariants theo domain compliance:
            - Logistics: HS Code accuracy, customs clearance, Incoterms
            - Finance: GAAP/IFRS, tax compliance, journal entry
            - Sales: customer ownership, commission integrity
            - HRM: employee active, tax code unique
            - Customs (EUREKA-specific): HS Code validation, customs declaration link

            Output JSON list candidates filtered + new domain-specific candidates."

  Agent({
    subagent_type: "{dept}-expert",  # business-analyst fallback nếu missing
    model: "opus",
    prompt: <rendered §3 agent-prompt with domain context>
  })
```

**Aggregate:**
```bash
PASS2_OUTPUT="[]"
for dept in $ACTIVE_DEPTS; do
  dept_result=$(cat "$SESSION_DIR/phase3-invariants/.pass2-${dept}.json" 2>/dev/null || echo "[]")
  PASS2_OUTPUT=$(jq -n --argjson p "$PASS2_OUTPUT" --argjson d "$dept_result" '$p + $d')
done
```

**Error handling:**
- E034 LLM timeout → retry x1 với scope thu hẹp
- E032 Domain knowledge missing → fallback `business-analyst` agent, WARN

### Step 3.6 — Pass 3 LLM (Registry Gap Detection)

```
Spawn business-analyst agent:
  Task: "Cross-check Pass 1 + 2 với existing req-registry.json + phase1-business/*.md.
          Mục tiêu:
          1. Lọc invariant đã có trong docs (mark as `documented`)
          2. Detect invariant thiếu trong docs (status="proposed", confidence=high)
          3. Detect invariant đã commit nhưng chưa có code/test verification (verified_by gaps)

          Output JSON merged list với prioritized + status."

  Agent({
    subagent_type: "business-analyst",
    model: "opus",
    prompt: <rendered §3 agent-prompt with full context>
  })
```

### Step 3.7 — Cross-domain conflict detection (E036)

> Phát hiện ≥2 domain experts có opinion lệch nhau về cùng invariant.

```bash
# Detect conflict: same invariant.id but different severity/expression across Pass 2 dept outputs
CONFLICTS=$(echo "$PASS2_OUTPUT" | jq '[
  group_by(.id) |
  map(select(length > 1)) |
  map({id: .[0].id, opinions: [.[] | {dept: .source_dept, severity, expression}]})
]')

CONFLICT_COUNT=$(echo "$CONFLICTS" | jq 'length')
if [ "$CONFLICT_COUNT" -gt 0 ]; then
  log_warn "E036" "Cross-domain conflict detected: $CONFLICT_COUNT invariants"
  echo "$CONFLICTS" > "$SESSION_DIR/phase3-invariants/conflicts.json"

  # If >3 conflicts/session → CDG E091 batch
  if [ "$CONFLICT_COUNT" -gt 3 ]; then
    # Trigger CDG E091 — user resolve trong Phase 7, defer ngay tại đây
    log_info "Conflicts deferred to Phase 7 CDG E091 batch"
  fi
fi
```

### Step 3.8 — Build candidate invariants với confidence + populate template

```bash
TARGET="$SESSION_DIR/phase3-invariants/business-invariants.json"
TPL=".claude/skills/workflow/wf-cmi/templates/business-invariants.json"

# READ template + strip metadata
strip_template_metadata "$TPL" "$TARGET"

# Merge all passes
ALL_INVARIANTS=$(jq -n \
  --argjson h "$HEURISTIC_INVARIANTS" \
  --argjson p1 "${PASS1_OUTPUT:-[]}" \
  --argjson p2 "$PASS2_OUTPUT" \
  --argjson p3 "${PASS3_OUTPUT:-[]}" \
  '$h + $p1 + $p2 + $p3 | unique_by(.id)')

# Populate output
jq --argjson invs "$ALL_INVARIANTS" \
   --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   --arg scope_type "$SCOPE_TYPE" --arg scope_name "$SCOPE_NAME" \
   '. + {
      session_id: $sid,
      generated_at: $ts,
      generated_by: "wf-cmi",
      scope: {type: $scope_type, name: $scope_name},
      invariants: $invs,
      audit_chain: {source: "phase2-discovery/entity-graph.json+module-graph.json", checksum: ""}
    }' "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"

# Validate
jq '.' "$TARGET" >/dev/null || die "E044" "business-invariants.json invalid"
```

**Confidence rules (E038):**
- Confidence ≥ 0.7 → status `proposed`
- Confidence < 0.5 → mark `proposed` only, KHÔNG `accepted` auto (E038 WARN)

### Step 3.9 — (Optional) Build invariants-diff.json

> So sánh per-session draft với canonical sidecar trước đó (nếu tồn tại).

```bash
CANONICAL=".mc-data/work/wf-cmi/business-invariants.json"
if [ -f "$CANONICAL" ]; then
  acquire_read_lock business-invariants
  DIFF_FILE="$SESSION_DIR/phase3-invariants/invariants-diff.json"

  # New: trong draft nhưng không trong canonical
  NEW=$(jq -n --slurpfile draft "$TARGET" --slurpfile canon "$CANONICAL" \
        '($draft[0].invariants // []) - ($canon[0].invariants // []) | map(.id) | unique')

  # Removed: trong canonical nhưng không trong draft
  REMOVED=$(jq -n --slurpfile draft "$TARGET" --slurpfile canon "$CANONICAL" \
            '($canon[0].invariants // []) - ($draft[0].invariants // []) | map(.id) | unique')

  jq -n --argjson new "$NEW" --argjson rm "$REMOVED" \
        '{new: $new, removed: $rm, total_draft: 0, total_canonical: 0}' \
        > "$DIFF_FILE"

  release_read_lock business-invariants "$READER_ID"
fi
```

### Step 3.10 — Write Phase3-report.md (CORE-028)

```bash
TOTAL_INV=$(jq '.invariants | length' "$TARGET")
HEUR_COUNT=$(jq '[.invariants[] | select(.source | startswith("heuristic"))] | length' "$TARGET")
LLM_COUNT=$(jq '[.invariants[] | select(.source | startswith("llm"))] | length' "$TARGET")
HIGH_CONF=$(jq '[.invariants[] | select(.inferred_by.confidence >= 0.7)] | length' "$TARGET")
CONFLICT_NOTE=""
[ "${CONFLICT_COUNT:-0}" -gt 0 ] && CONFLICT_NOTE="- Xung đột giữa các domain expert: $CONFLICT_COUNT (sẽ giải quyết trong Phase 7)"

sed -e "s|\[TOTAL_INVARIANTS\]|$TOTAL_INV|g" \
    -e "s|\[HEURISTIC_COUNT\]|$HEUR_COUNT|g" \
    -e "s|\[LLM_COUNT\]|$LLM_COUNT|g" \
    -e "s|\[HIGH_CONFIDENCE_COUNT\]|$HIGH_CONF|g" \
    -e "s|\[ACTIVE_DEPTS\]|$(echo "$ACTIVE_DEPTS" | tr '\n' ',' | sed 's/,$//')|g" \
    -e "s|\[CONFLICT_NOTE\]|$CONFLICT_NOTE|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|PASS|g" \
    ".claude/skills/workflow/wf-cmi/templates/Phase3-report.md" \
    > "$SESSION_DIR/phase3-invariants/Phase3-report.md"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | `business-invariants.json` exists | Re-run inference Step 3.3-3.8 |
| T2 | Schema `business-invariants-v1` valid + có `invariants[]` array | Re-build từ template |
| T3 | ≥1 invariant per active domain (heuristic minimum: FK pattern OR validator) | Re-prompt domain expert (E045) |
| T4 | No invariant với `severity=MUST` thiếu `source_doc` AND `source` (heuristic OR llm-passN) | Re-link source docs (E046) |

```bash
post_gate_phase3() {
  local target="$SESSION_DIR/phase3-invariants/business-invariants.json"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] || { rebuild_invariants; retry=$((retry+1)); continue; }
    # T2
    jq -e '."$schema" == "business-invariants-v1" and (.invariants | type == "array")' "$target" >/dev/null \
      || { rebuild_from_template; retry=$((retry+1)); continue; }
    # T3 — ≥1 invariant per active dept (heuristic OK)
    for dept in $ACTIVE_DEPTS; do
      count=$(jq --arg d "$dept" \
              '[.invariants[] | select(.modules_involved | any(. == $d) or (.source | contains($d)))] | length' \
              "$target")
      if [ "$count" -lt 1 ]; then
        log_warn "E045" "0 invariants for dept=$dept"
      fi
    done
    # T4 — MUST severity requires source
    orphan_count=$(jq '[.invariants[] | select(.severity == "MUST" and (.source_doc == null or .source_doc == "")
                                              and (.source == null or .source == ""))] | length' "$target")
    [ "$orphan_count" -gt 0 ] && { fix_orphan_sources; retry=$((retry+1)); continue; }

    return 0
  done
  die "E001" "Phase 3 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 3
2. Update `integrity-status.json`:
   - `.phases_completed += [3]`
   - `.current_phase = 4`
   - `.next_action = "phase4-coverage-dispatch"`
3. TodoWrite: Phase 3 = completed, Phase 4 = in_progress

---

## §E Phase Report Template (CORE-028)

```markdown
## Phase 3: Suy luận quy tắc nghiệp vụ — PASS
Thời gian: 2026-05-15T14:39:50+07:00

**Đã làm:**
- Phân tích 6 bản đồ từ Phase 2 → suy luận quy tắc liên module
- Spawn chuyên gia domain: sales, finance, customs, hrm, customer
- 3-pass: pattern → domain rule → registry gap

**Kết quả:**
- Tổng quy tắc nghiệp vụ phát hiện: 47
- Pattern heuristic: 28 | LLM suy luận: 19
- Độ tin cậy cao (≥0.7): 35
- [CONFLICT_NOTE]

**Tiếp theo:**
- Phase 4 — Dispatch 8 lanes đo coverage song song (5-12 phút)
```

---

## §F Error Code Quick Reference (Phase 3 namespace E030-E039)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E030 | high | Phase 2 outputs incomplete | Re-run Phase 2 |
| E031 | high | Graphs empty | ESCALATE scope too narrow |
| E032 | medium | Domain expert knowledge missing | Fallback business-analyst, WARN |
| E033 | medium | Profile-phase mismatch (skip 3-pass) | Auto-skip (info) |
| E034 | high | LLM timeout (>5 min) | Retry x1, ESCALATE |
| E035 | medium | LLM output schema invalid | Re-prompt clarified contract |
| E036 | medium | Cross-domain conflict (>3) | CDG E091 batch escalate |
| E037 | medium | Source_doc broken link | Re-link or DROP candidate |
| E038 | low | Confidence too low (<0.5) | Status `proposed` only |
| E039 | high | Sidecar schema migration fail | ESCALATE manual |
| E091 | medium | Cross-domain CDG (Phase 7 batch) | AskUser: A/B/Defer, max 2 reject |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §14 R/W Lock, §15 Agent Prompts, §18 CDG Token |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | §1 Phase 3 routing |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §6 Business invariants + §6.5 3-pass inference workflow |
| `docs/04-skill-design/wf-cmi/agent-prompt.md` | §13 Triage prompt template |
| `templates/business-invariants.json` | Per-session draft template |
| `_contract.json §outputs.working[]` | business-invariants.json paths |

---

## §H Next

Phase 3 PASS → Read `procedures/phase4-coverage-dispatch.md` để spawn 5-10 lane agents parallel.
