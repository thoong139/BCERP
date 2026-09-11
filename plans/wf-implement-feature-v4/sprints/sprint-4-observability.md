# Sprint 4 — Observability

**Goal:** error-ledger.json + namespaced error codes (E1xx-E9xx) + phase summary v2 + (optional) phase rename
**Estimated effort:** 2h
**Dependencies:** Sprint 3 complete (consumer_hints + global registry)
**Output:** v4.0.0-rc2 — observable, debuggable

---

## Mục tiêu cụ thể

1. **G5 fix:** Per-session `error-ledger.json` (replace + extend `impl-status.warnings[]`)
2. **G5 fix:** Namespaced error codes E1xx (Phase 1) → E9xx (cross-cutting)
3. Backward compat alias E001-E014 → E1xx-E9xx trong `_shared.md`
4. phase-summary.md v2 thêm "Errors & Warnings" section
5. (D4=A only) Phase file rename phase01..phase10

---

## Steps chi tiết

### Step 4.1 — Tạo templates/error-ledger.json

**File:** `.claude/skills/workflow/wf-implement-feature/templates/error-ledger.json`

```json
{
  "schema_version": "1.0",
  "session_id": "",
  "feature_slug": "",
  "errors": []
}
```

**Entry schema:**
```json
{
  "code": "E101",
  "phase": "phase01-pattern-scan",
  "severity": "info | warning | error | critical",
  "message": "Pattern cache miss — full scan triggered",
  "context": {},
  "ts": "2026-04-28T10:35:00Z",
  "auto_resolved": true,
  "escalated_to_user": false,
  "resolution": ""
}
```

---

### Step 4.2 — Tạo helper `log_error()` trong implement-common.sh

```bash
# Append to error-ledger.json
log_error() {
  local code="$1"      # e.g. E101
  local phase="$2"     # e.g. phase01-pattern-scan
  local severity="$3"  # info | warning | error | critical
  local message="$4"
  local context="${5:-{}}"  # JSON object
  local auto_resolved="${6:-false}"

  local ledger_file="$SESSION_DIR/error-ledger.json"

  # Init if missing
  if [[ ! -f "$ledger_file" ]]; then
    jq -nc --arg sid "$SESSION_ID" --arg fs "$FEATURE_SLUG" \
      '{schema_version:"1.0",session_id:$sid,feature_slug:$fs,errors:[]}' \
      > "$ledger_file"
  fi

  local entry
  entry="$(jq -nc --arg c "$code" --arg p "$phase" --arg s "$severity" \
    --arg m "$message" --argjson ctx "$context" \
    --arg ts "$(date -u +%FT%TZ)" --argjson ar "$auto_resolved" \
    '{code:$c,phase:$p,severity:$s,message:$m,context:$ctx,ts:$ts,auto_resolved:$ar,escalated_to_user:false,resolution:""}')"

  local tmp
  tmp="$(mktemp)"
  jq --argjson e "$entry" '.errors += [$e]' "$ledger_file" > "$tmp" && mv "$tmp" "$ledger_file"

  # Trace event
  trace_event "ERROR_LOGGED" "$FEATURE_SLUG" "$SESSION_ID" "{\"code\":\"$code\",\"severity\":\"$severity\"}"
}
```

---

### Step 4.3 — Update _shared.md error codes namespace + alias

**Replace `## Error Codes Reference` section với:**

```markdown
## Error Codes Reference (v4.0+ namespaced)

### Namespace

| Range | Phase | Examples |
|-------|-------|----------|
| E1xx | Phase 1 (context, registry) | E101 (cache miss), E102 (registry inconsistent), E103 (req-id not found) |
| E2xx | Phase 2 (planning, populate-spec, contracts) | E201 (task file missing), E202 (A6-EXT stub), E203 (task list gen failed) |
| E3xx | Phase 3 (TDD, test gate, decisions) | E301 (test gate fail), E302 (decision conflict), E303 (source file gen failed), E304 (REQ-ID missing), E305 (auto-fix regression) |
| E4xx | Phase 4 (review) | E401 (agent timeout), E402 (critical/security issues unfixed) |
| E5xx | Phase 5a (cross-validation) | E501 (validation auto-correction loop > 3) |
| E6xx | Phase 6 (registry write, finalize) | E601 (registry mutex timeout), E602 (POST-GATE T1-T4 fail) |
| E9xx | Cross-cutting | E901 (per-feature lock busy / lifecycle), E902 (history index append fail) |

### Severity → Action

| Severity | Behavior |
|----------|----------|
| `info` | Log only, no user notification |
| `warning` | Log + display in phase-summary.md |
| `error` | Log + retry up to 3 times, then escalate |
| `critical` | Log + immediate escalate (no retry) |

### Backward Compatibility (v3.x → v4.0)

| Old (v3.x) | New (v4.0) | Description |
|-----------|-----------|-------------|
| E001 | E101 | Missing feature/REQ-ID |
| E002 | E102 | Registry not found |
| E003 | E103 | Cannot determine feature |
| E004a | E202 | Feature design missing |
| E004b | E201 | Task file missing |
| E005 | E203 | Task list generation failed |
| E006 | E303 | Source file creation failed |
| E007 | E304 | REQ-ID missing |
| E008 | E301 | Tests failing |
| E009 | E402 | Critical/Security issues |
| E010 | E401 | Agent timeout |
| E011 | E602 | POST-GATE fail |
| E012 | E305 | Auto-fix regression |
| E013 | E901 | Session lifecycle (fresh) |
| E014 | E102 | Re-run without flag |

Skill code uses NEW codes. User-facing messages reference both for clarity:
> "Error E301 (was E008): Tests failing"
```

---

### Step 4.4 — Update mỗi phase file: replace E0xx → E1xx-E9xx

**Files:** Tất cả phase*.md trong `procedures/`

**Search & replace với context:**
- E001 → E101
- E002 → E102
- E003 → E103
- E004a → E202
- E004b → E201
- E005 → E203
- E006 → E303
- E007 → E304
- E008 → E301
- E009 → E402
- E010 → E401
- E011 → E602
- E012 → E305
- E013 → E901
- E014 → E102

**Verify:** `grep -rn 'E00[0-9]' .claude/skills/workflow/wf-implement-feature/procedures/` should return 0 (chỉ trong _shared.md backward-compat table).

---

### Step 4.5 — Update phase-summary.md template

**Add new section:**

```markdown
## Errors & Warnings

[Đếm errors/warnings từ error-ledger.json, format theo severity]

### Critical (chặn implementation)
[List]

### Errors (auto-resolved hoặc escalated)
[List với code + phase + message]

### Warnings (info, không chặn)
[Count]

[Nếu zero errors/warnings → "✅ Không có lỗi/cảnh báo"]
```

**Phase 6 step 6.7 (CORE-028 phase-summary):** Populate section này từ `error-ledger.json`:

```bash
ERRORS=$(jq -r '[.errors[] | select(.severity == "error")] | length' error-ledger.json)
WARNINGS=$(jq -r '[.errors[] | select(.severity == "warning")] | length' error-ledger.json)
CRITICAL=$(jq -r '[.errors[] | select(.severity == "critical")] | length' error-ledger.json)

# Render section based on counts
```

---

### Step 4.6 — (CONDITIONAL D4=A) Phase file rename

**ONLY if user chọn D4=A trong decisions-pending.md.**

**Renames:**
| Old | New |
|-----|-----|
| phase0-existing-analysis.md | phase01-pattern-scan.md |
| phase0-5-context-setup.md | phase02-context-setup.md |
| phase1-feature-context.md | phase03-feature-context.md |
| phase0-7-safety-gate.md | phase04-safety-gate.md |
| phase2-planning.md | phase05-planning.md |
| phase2-4-populate-spec.md | phase05a-populate-spec.md |
| phase2-5-contracts.md | phase06-contracts.md |
| phase3-tdd.md | phase07-tdd.md |
| phase4-5-review-fix.md | phase08-review-fix.md |
| phase5a-crossval.md | phase09-crossval.md |
| phase6-finalize.md | phase10-finalize.md |

**Steps:**
1. `git mv` từng file
2. Update SKILL.md Phase File Structure table
3. Update SKILL.md Phase Orchestration table
4. Update _contract.json `procedure[]` array
5. Update internal cross-references trong procedure files (grep -l)
6. Update CLAUDE.md / docs / plan files nếu có ref cụ thể (grep)

**ELSE (D4=B hoặc C):** Skip Step 4.6 entirely.

---

### Step 4.7 — Smoke test error scenario

**Trigger E301 (test fail):**

```bash
# Setup feature with intentional broken test
# Run skill
claude /wf-implement-feature TEST-BROKEN-001 --profile=quick

# Verify error ledger populated
jq -e '.errors[] | select(.code == "E301")' .mc-data/work/wf-implement-feature/test-broken/sessions/$ID/error-ledger.json

# Verify phase-summary has Errors section
grep -q "## Errors & Warnings" .mc-data/work/wf-implement-feature/test-broken/sessions/$ID/phase-summary.md
```

---

## Definition of Done — Sprint 4

- [ ] `templates/error-ledger.json` exists với schema v1.0
- [ ] `log_error()` helper trong implement-common.sh works
- [ ] Tất cả phase files use namespaced codes (E1xx-E9xx) — grep no E001-E014
- [ ] `_shared.md` có namespace + alias table
- [ ] `phase-summary.md` template có "Errors & Warnings" section
- [ ] Phase 6 step 6.7 populate Errors & Warnings từ error-ledger
- [ ] (Optional D4=A) Phase files renamed to phase01..phase10
- [ ] Smoke test: trigger E301 → verify ledger entry + phase-summary section

---

## Risks Sprint 4

| Risk | Mitigation |
|------|-----------|
| Bulk find-replace E0xx → E1xx miss edge case | grep verify post-replace + alias table cho user-facing messages |
| Phase rename break git history blame | git mv preserves history. Optional D4=A only if user chấp nhận |
| error-ledger.json grow too large | Cap entries: 100 errors max. Truncate oldest if exceeded. |
| Concurrent write to error-ledger từ parallel agents | log_error() uses jq atomic write (tmp → mv) — safe |

---

## Output cho Sprint 5

- error-ledger established → Sprint 5 evals có thể assert specific error codes
- All sprints complete → Sprint 5 final validation
