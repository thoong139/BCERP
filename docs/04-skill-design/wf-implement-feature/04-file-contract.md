# 04 — File Contract

> **Mục đích file:** PRE-GATE/POST-GATE per phase, output paths (system-grouped v5), cross-skill artifacts (produces_for + consumes_from).

---

## 1. PRE-GATE per phase (forensic)

### Phase 0 — Entry

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -n "$ARGUMENTS"` | bash | E103 — missing feature name |
| T2 | Migration scripts exit 0 (v3→v4, v4→v5) | bash | E901 — migration failed |
| T3 | Per-feature lock acquired | `implement-acquire-lock.sh` | E901 — lock busy |
| T4 | `$SESSION_DIR` resolved | bash | E901 — session dir error |

### Phase 1 — Feature Context

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | bash | E102 — registry missing |
| T2 | `jq -e '.requirements'` registry | jq | E102 — schema invalid |
| T3 | Feature/REQ-ID found trong registry | jq lookup | E103 — not found |
| T4 | `test -f phase2-features/[sys]/[mod]/<feat>.md` | bash | E202 — feature design missing |

### Phase 0.7 — Safety Gate (CORE-020)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Existing code search executed | Grep/GitNexus | E901 — search failed |
| T2 | `$CONFIRMED_STRATEGY` set (VERIFY_ONLY/COMPLETE_EXISTING/IMPLEMENT_NEW) | AskUserQuestion | E901 — user cancelled |
| T3 | Env safety scan completed (5 patterns E1-E5) | Grep | (warning only) |
| T4 | LEGACY_MODE → `implementation_strategy` from task file | jq | E202 — task missing |

### Phase 3 — TDD

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Task list `$TASK_LIST` exists | bash | E203 |
| T2 | Test file created BEFORE source file (TDD order) | bash mtime check | E301 — TDD order violated |
| T3 | Tests PASS (GATE-13) | test runner | E301 |
| T4 | Source file có REQ-ID comment | Grep | E304 — auto-fix via cross-val |

---

## 2. POST-GATE per phase (tiered T1→T4)

### Phase 1 — POST-GATE

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `test -f $SESSION_DIR/impl-status.json` | Re-build từ template |
| T2 | `jq '.' impl-status.json` valid | Re-populate from template |
| T3 | `jq -e '.session_id and .feature_id and .schema_version'` | Re-generate |
| T4 | Feature spec digest loaded vào `$EXECUTABLE_SPEC` | Re-read phase2-features file |

### Phase 3 — POST-GATE

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | All source files trong batch exist | Re-run developer agent |
| T2 | All test files exist + parseable | Re-run với error context |
| T3 | Tests PASS | Debug + fix (max 3 retries) |
| T4 | Each source file có REQ-ID comment | Cross-val Phase 5a auto-fix |

### Phase 6 — POST-GATE (delegated to bash)

```bash
bash .claude/scripts/wf-implement-feature/implement-postgate.sh \
  --session-dir="$SESSION_DIR" \
  --req-ids="$REQ_IDS_IN_SCOPE" \
  --registry=".mc-data/docs/_meta/req-registry.json"
# Exit 0 = PASS (T1-T4 all pass)
# Exit 1 = FAIL → trigger auto-fix (max 3 retries) hoặc escalate (E602)
```

Logic chi tiết T1→T4: xem `procedures/phase6-finalize.md §POST-GATE`.

---

## 3. Output paths (system-grouped v5.0)

Cấu trúc working dir đổi từ v3.x flat sang v5 system-grouped:

```
.mc-data/work/wf-implement-feature/
├── $SYSTEM_SLUG/                              # System slug từ registry.features[].system_id
│   └── $FEATURE_SLUG/                         # Feature slug từ feature.title (Vietnamese-safe)
│       ├── current.txt                        # Pointer tới session active (relative)
│       ├── sessions/
│       │   └── 2026-05-15-100000-host1/      # Session ID format: YYYY-MM-DD-HHMMSS-hostshort
│       │       ├── impl-status.json           # Pipeline state SSOT (schema v2.0)
│       │       ├── impl-plan.md               # Task breakdown + batches
│       │       ├── impl-report.md             # Final report
│       │       ├── checkpoint.json            # Phase 3 batch checkpoint
│       │       ├── decision-registry.json     # Per-feature decisions (Protocol 12)
│       │       ├── existing-patterns.json     # Phase 0a output (conditional)
│       │       ├── contracts.json             # Phase 2.5 (conditional --parallel)
│       │       ├── qa-review-attempt-[N].md   # Phase 4 review reports
│       │       ├── error-ledger.json          # Errors lazy-init (≥1 error)
│       │       ├── profile.txt                # Resolved profile (quick/std/deep/exh)
│       │       └── phase-summary.md           # CORE-028 tiếng Việt
│       └── archived/                          # --fresh archive cũ vào đây
├── _orphan/                                   # Feature không có trong registry
│   └── <feature_slug>/...
├── .locks/$SYSTEM_SLUG/                       # Per-system locks
│   └── <feature_slug>.lock                    # Per-feature lock (PID + heartbeat)
├── .cache/$SYSTEM_SLUG/$MODULE_SLUG/         # Pattern scan cache
│   └── existing-patterns.<git_sha>.json       # TTL 24h + dual invalidation
└── .history/
    └── implementations-index.jsonl            # APPEND-only audit trail
```

---

## 4. Cross-skill contract

### Produces for (downstream consumers)

| Skill consumer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| `wf-preflight` | `req-registry.json` (updated `impl_status`) | `req-registry-v1` | `.mc-data/docs/_meta/req-registry.json` |
| `wf-verify-sync` | `req-registry.json` (updated `impl_status`) | `req-registry-v1` | `.mc-data/docs/_meta/req-registry.json` |
| `wf-prepare-deployment` | `impl-status.json` (consumer_hints.for_prepare_deployment) | `impl-status-v2` | `$SESSION_DIR/impl-status.json` |
| `wf-fix-bugs` | `impl-status.json` (consumer_hints.for_fix_bugs) | `impl-status-v2` | `$SESSION_DIR/impl-status.json` |
| `future-implementations` | `decision-registry.global.json` (cross-feature) | `decision-registry-v1` | `.mc-data/docs/_meta/decision-registry.global.json` |

### Consumes from (upstream producers)

| Skill producer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| `wf-plan-modules` | `module-plan.md`, `dependency-graph.md`, `tasks/.../[feat]-impl.md` | (markdown) | `.mc-data/docs/phase5-implementation/...` |
| `wf-define-features` | `phase2-features/[sys]/[mod]/[feat].md` + `feature-briefs.json` | feature-briefs-v1 | `.mc-data/docs/phase2-features/...` + `_meta/feature-briefs.json` |
| `wf-design` | `design-input-digest.json` | design-input-digest-v1 | `.mc-data/docs/_meta/design-input-digest.json` |
| `wf-brainstorm` | `legacy-decisions.json` (CORE-022) | legacy-decisions-v1 | `.mc-data/work/wf-brainstorm/legacy-decisions.json` |
| `wf-legacy-scan` | `project-context.md` (LEGACY_MODE detect) | (markdown) | `.mc-data/work/legacy-scan/project-context.md` |
| `wf-fix-bugs` | `fix-impact.json` (v5.2+ `--from-fix-bugs`) | fix-impact-v1 | `.mc-data/work/wf-fix-bugs/sessions/$ID/fix-impact.json` |

---

## 5. Artifact schemas

### `impl-status.json` (schema v2.0, pipeline state SSOT)

```json
{
  "$schema": "impl-status-v2",
  "schema_version": "2.0",
  "session_id": "2026-05-15-100000-host1",
  "feature_id": "FEAT-CRM-CUST-001",
  "feature_slug": "customer-management",
  "system_slug": "crm",
  "profile": "standard",
  "scenario": "NEW | EXTEND | MODIFY",
  "status": "not_started | in_progress | paused | error | completed",
  "current_phase": "phase_X",
  "phases_completed": ["array<string>"],
  "next_action": "string",
  "flags": { "skip_tests": false, "skip_review": false, "fresh": false, "parallel": false },
  "cache_hits": { "existing_patterns": false, "saved_tokens_estimated": 0 },
  "reviews": { "code_review": "pending|done|skipped", "qa_review": "...", "security_review": "..." },
  "consumer_hints": {
    "for_prepare_deployment": { "files_for_changelog": [], "breaking_changes": [], "migrations_required": [], "feature_summary_vi": "" },
    "for_fix_bugs": { "scope_modules": [], "test_files_added": [], "decision_ids_new": [], "implementation_strategy_used": "" },
    "for_verify_sync": { "req_ids_completed": [], "files_with_req_id": [], "session_dir": "" }
  },
  "audit_chain": {
    "source": ".mc-data/docs/_meta/req-registry.json",
    "checksum": "string (sha256)"
  }
}
```

### `fix-impact.json` (v5.2+ consume from wf-fix-bugs)

```json
{
  "$schema": "fix-impact-v1",
  "session_id": "2026-05-10-crm-customer-mgmt-01",
  "skill": "wf-fix-bugs",
  "generated_at": "2026-05-10T14:32:00+07:00",
  "scope": "FEAT-CRM-CUST-001",
  "fixed_issues": ["array<issue_id>"],
  "code_files_modified": ["src/customer.service.ts", "..."],
  "dimensions_covered": ["QD1", "QD2", "QD5"],
  "impl_status_changed": ["REQ-CRM-CUST-001"],
  "audit_chain": {
    "source": ".mc-data/work/wf-fix-bugs/sessions/2026-05-10-crm-customer-mgmt-01/fix-status.json",
    "checksum": "string (sha256)"
  }
}
```

Phase 1 step 1.10/1.11 đọc artifact này để prioritize features có `code_files_modified` trùng `$FEATURE_SLUG`.

### `decision-registry.global.json` (cross-feature, APPEND-only)

```json
{
  "$schema": "decision-registry-v1",
  "decisions": [
    {
      "id": "DEC-001",
      "scope": "project | module:crm | feature:FEAT-XXX",
      "category": "naming|architecture|error-handling|testing",
      "rule": "string (short)",
      "reason": "string (rationale)",
      "added_at": "ISO 8601",
      "added_by": "session_id"
    }
  ]
}
```

---

## 6. Registry Safe-Write (CORE-006)

**write_role:** PRIMARY
**fields_owned:** `["impl_status"]`
**safe_write_rule:** CORE-006 — narrow per-field jq update, KHÔNG replace `.requirements[]` array

```bash
# Update đúng 1 REQ-ID:
TMP=$(mktemp)
jq --arg id "$REQ_ID" \
   '(.requirements[] | select(.req_id == $id) | .impl_status) = "done"' \
   .mc-data/docs/_meta/req-registry.json > "$TMP" \
  && mv "$TMP" .mc-data/docs/_meta/req-registry.json
```

**Quy tắc bổ sung (CORE-008):** KHÔNG downgrade `impl_status` từ `done`. Nếu cross-val phát hiện code missing → WARNING, hỏi user trước khi update.

---

## 7. Atomic write pattern

Áp dụng cho mọi JSON state file:

```bash
# Step 1: build vào tmp
echo "$new_content" > "$file.tmp.$$"

# Step 2: validate JSON
jq '.' "$file.tmp.$$" > /dev/null || { rm "$file.tmp.$$"; exit 1; }

# Step 3: atomic move
mv "$file.tmp.$$" "$file"

# Step 4: verify
test -f "$file" && jq -e '.' "$file" > /dev/null
```

Source canonical: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §5.

---

## 8. Liên kết

- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md)
- Standards: [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) — Registry write roles
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) — System-grouped paths
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Source `_contract.json`: [`.claude/skills/workflow/wf-implement-feature/_contract.json`](../../../.claude/skills/workflow/wf-implement-feature/_contract.json)
