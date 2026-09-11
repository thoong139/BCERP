# Guard Rails — Compliance Matrix

> Mỗi cải tiến trong plan này PHẢI bảo toàn 10 chuẩn MCV3 sau. File này là **checklist enforce**, dùng khi review PR.

---

## Compliance Matrix Per Wave

| Guard Rail | Source | W1.1 | W1.2 | W1.3 | W2.1 | W2.2 | W3.1 | W3.2 | W3.3 |
|------------|--------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| POST-GATE T1-T4 (CORE-012) | rules/00-core.md §4 | ✅ | ✅ | ⚙️ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Forensic PRE-GATE (CORE-011) | rules/00-core.md §4 | ⚙️ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CDG CORE-027 (Protocol 16) | rules/00-core.md §4 | ⚙️ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚙️ | ✅ |
| CORE-029 Spot-Check (Protocol 17) | rules/00-core.md §4 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚙️ |
| CORE-037 Agent Prompt 8 sections | rules/00-core.md §4n | ✅ | ✅ | ✅ | ✅ | ⚙️ | ✅ | ✅ | ✅ |
| CQG hard-enforce (E001) | wf-fix-cqg-verify.sh | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CORE-031 Template Usage (Protocol 19) | rules/00-core.md §4h | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CORE-026 Execution Trace | rules/00-core.md §4g | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CORE-006 Registry Safe-Write | rules/00-core.md §4a | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CI Tool Usage Logging (Protocol 20 §20.11) | protocols/20-code-intelligence.md | ✅ | ⚙️ | ✅ | ✅ | ✅ | ✅ | ⚙️ | ✅ |
| Scope Boundary Rule | _shared.md §Scope Boundary | ✅ | ✅ | ✅ | ✅ | ⚙️ | ✅ | ✅ | ✅ |
| CORE-035 Atomic Write Pattern | rules/00-core.md §4l | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Legend:**
- ✅ = Preserved as-is (không thay đổi behavior)
- ⚙️ = Touched but enforced (cải tiến sửa scope nhưng bảo toàn semantics, có acceptance criteria xác minh)

---

## Per-Task Enforcement Details

### W1.1 — Phase 6 Wrapper De-dup CI

**Touched guard rails:**
- ⚙️ **Forensic PRE-GATE (CORE-011):** Read `blast_radius` content (không chỉ check existence). Fast path PHẢI verify `blast_radius` non-empty + risk field valid.
- ⚙️ **CDG CORE-027:** Render `AskUserQuestion` cảnh báo HIGH/CRITICAL theo cùng template Phase 6 hiện tại. Data source khác (Phase 5 triage thay vì rerun) nhưng user-facing message IDENTICAL.

**Enforcement:**
```bash
# Smoke test sau implementation
test "$(jq '[.tokens[]] | length' "$SESSION_DIR/phase5-triage/cdg-tokens.json")" -ge 0  # CDG tokens still possible
test -s "$SESSION_DIR/phase6-execute/ci-impact-report.json"  # Output present
jq -e '.tool == "blast_radius_reused" or .tool == "gitnexus_fresh" or .tool == "grep_fallback"' "$SESSION_DIR/phase6-execute/ci-impact-report.json"
```

---

### W1.2 — CI Impact Caching

**Touched guard rails:**
- ⚙️ **CI Tool Usage Logging (Protocol 20 §20.11):** Mọi cache hit/miss PHẢI log entry. Schema extension:
  ```json
  {
    "event": "CI_TOOL_USED",
    "task": "impact_analysis",
    "primary": "gitnexus_impact",
    "fallback_used": false,
    "cache_hit": true | false,           // NEW
    "cache_source": "session_tier" | null,  // NEW
    "duration_ms": 12,
    "result_count": 8,
    "freshness_behind_commits": 0,
    "freshness_level": "ok"
  }
  ```

**Enforcement:**
```bash
# Verify mỗi CI_TOOL_USED entry có cache_hit field
jq -e '.entries | map(select(.event == "CI_TOOL_USED")) | all(has("cache_hit"))' "$SESSION_DIR/fix-log.json"

# Verify freshness=severe → cache bypass
# Test: set fixture với freshness=severe, run W1.2 → expect cache_hit=false cho all calls

# Verify escape hatch
MCV3_FIX_CI_CACHE_DISABLED=1 bash .claude/scripts/wf-fix-ci-cache.sh ... | jq -e '.cache_hit == false'
```

---

### W1.3 — POST-GATE T1-T4 Consolidation

**Touched guard rails:**
- ⚙️ **POST-GATE T1-T4 (CORE-012):** Số tier không đổi (4), semantics không đổi, chỉ giảm subprocess overhead.

**Enforcement:**
```bash
# Parity test: chạy POST-GATE cũ + mới trên cùng input, expect same result
OLD=$(bash legacy_post_gate.sh "$input1" "$input2"; echo $?)
NEW=$(bash new_post_gate.sh "$input1" "$input2"; echo $?)
test "$OLD" = "$NEW"

# Tier output preserved
NEW_OUTPUT=$(validate_post_gate_tiered "$input1" "$input2")
echo "$NEW_OUTPUT" | grep -E "T1=ok|T1=fail"
echo "$NEW_OUTPUT" | grep -E "T2=ok|T2=fail"
echo "$NEW_OUTPUT" | grep -E "T3=ok|T3=fail"
echo "$NEW_OUTPUT" | grep -E "T4=ok|T4=fail"
```

---

### W2.1 — Playwright Parallel Routes

**Touched guard rails:**
- ⚙️ **Evidence collection per route:** Phải verify mỗi route có file riêng biệt:
  - `evidence/console-{slug}.txt`
  - `evidence/snapshot-{slug}.yml`
  - `evidence/screenshot-{slug}.png`

**Enforcement:**
```bash
# Verify per-route evidence
for route in $ROUTES_TO_VERIFY; do
  slug=$(slugify "$route")
  test -s "$SESSION_DIR/phase5-verify/evidence/console-$slug.txt"
  test -s "$SESSION_DIR/phase5-verify/evidence/snapshot-$slug.yml"
done

# Verify auth routes still sequential (log timestamps)
AUTH_TIMES=$(grep -E "auth|login|admin|profile" "$SESSION_DIR/session-log.json" | jq -r '.timestamp')
# Adjacent times >0.5s apart → sequential
```

---

### W2.2 — Batch 1 Sub-Parallel

**Touched guard rails:**
- ⚙️ **CORE-037 Agent Prompt:** Mỗi agent spawn PHẢI có 8 sections — verify trong prompt template.
- ⚙️ **Scope Boundary Rule:** Mỗi agent vẫn enforce `$TARGET_DIRS`. 2 agents khác group KHÔNG được modify cùng file.

**Enforcement:**
```bash
# Verify dep-graph correctness
jq -e '.groups | length >= 1' "$SESSION_DIR/phase3-batch1/dep-groups.json"

# Verify no 2 agents modified same file (post Batch 1)
DUPS=$(jq -r '[.entries[] | select(.batch == 1) | .files_modified[]] | group_by(.) | map(select(length > 1))' "$SESSION_DIR/fix-log.json")
test "$DUPS" = "[]"

# Verify spot-check ran per agent
SPOT_CHECKS=$(jq -r '.entries | map(select(.event == "SPOT_CHECK")) | length' "$SESSION_DIR/fix-log.json")
AGENTS_SPAWNED=$(jq -r '.entries | map(select(.event == "AGENT_SPAWNED" and .batch == 1)) | length' "$SESSION_DIR/fix-log.json")
test "$SPOT_CHECKS" -ge "$AGENTS_SPAWNED"
```

---

### W3.1 — Verify Loop Smart Rescan

**Touched guard rails:**
- ⚙️ **Cross-module regression detection:** Iter cuối LUÔN full scan để bảo toàn detection.

**Enforcement:**
```bash
# Verify iter 1 full scan
jq -e '.phases.phase_5.loop_state.iteration_history[0].scan_mode == "full"' fix-status.json

# Verify iter cuối (terminate state) full scan
LAST_ITER=$(jq -r '.phases.phase_5.loop_state.iteration_history | last | .iteration' fix-status.json)
jq -e ".phases.phase_5.loop_state.iteration_history[-1].scan_mode == \"full\"" fix-status.json

# Mid-iters có thể delta
ALL_MODES=$(jq -r '.phases.phase_5.loop_state.iteration_history[].scan_mode' fix-status.json)
echo "$ALL_MODES" | grep -E "full|delta"
```

---

### W3.2 — CI Batching Per File

**Touched guard rails:**
- ⚙️ **CI Tool Usage Logging:** 1 entry/issue (không bỏ bước log), nhưng có field `source=batch_lookup` + `parent_file`.
- ⚙️ **CDG HIGH/CRITICAL:** Render theo file (nếu 1 file → multiple issues, file đó HIGH/CRITICAL → render 1 CDG cho file đó, không 1 CDG/issue).

**Enforcement:**
```bash
# Verify entry per issue
PER_ISSUE_ENTRIES=$(jq '[.entries[] | select(.event == "CI_TOOL_USED" and has("issue_id"))] | length' "$SESSION_DIR/fix-log.json")
FIXED_ISSUES=$(jq '[.issues[] | select(.status == "fixed")] | length' "$SESSION_DIR/issue-registry.json")
test "$PER_ISSUE_ENTRIES" -ge "$FIXED_ISSUES"

# Verify parent_file ref
jq -e '.entries | map(select(.event == "CI_TOOL_USED" and .cache_source == "batch_lookup")) | all(has("parent_file"))' "$SESSION_DIR/fix-log.json"
```

---

### W3.3 — Spot-Check Pattern Cache

**Touched guard rails:**
- ⚙️ **CORE-029 Spot-Check Protocol 17:** 3/4 checks luôn chạy (file existence, scope, content sanity). Chỉ schema check có pattern cache.

**Enforcement:**
```bash
# Verify file existence + scope checks ran for every agent output
SCOPE_CHECKS=$(jq -r '.entries | map(select(.event == "SCOPE_CHECK")) | length' fix-log.json)
FILE_EXISTS_CHECKS=$(jq -r '.entries | map(select(.event == "FILE_EXISTS_CHECK")) | length' fix-log.json)
test "$SCOPE_CHECKS" -ge "$AGENT_OUTPUTS_COUNT"
test "$FILE_EXISTS_CHECKS" -ge "$AGENT_OUTPUTS_COUNT"

# Verify cache size ≤ 50
python -c "from _shared.spot_check_cache import inspector; print(inspector.size() <= 50)" | grep "True"
```

---

## Universal Acceptance Criteria (Apply to ALL Tasks)

Trước khi mark task COMPLETED, verify:

1. **Compliance audit pass:**
   ```bash
   bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs
   bash .claude/scripts/skill-compliance-audit.sh wf-fix-execute
   ```

2. **Schema sync pass:**
   ```bash
   bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs
   bash .claude/scripts/validate-schema-sync.sh wf-fix-execute
   ```

3. **Python tests pass (cho _shared changes):**
   ```bash
   cd .claude/skills/workflow/_shared && ./run-tests.sh --fast
   ```

4. **No fantasy code:** Mọi diff phải reference existing files / functions. Không invent files / agents / functions không tồn tại.

5. **Documentation language:** Comments + procedure docs tiếng Việt (CORE-005).

6. **Naming convention:** File kebab-case (CORE-016, CORE-017).

---

## Escape Hatches (Rollback Without Code Change)

| Wave | Env Variable | Effect |
|------|-------------|--------|
| W1.2 | `MCV3_FIX_CI_CACHE_DISABLED=1` | Bypass cache, direct gitnexus_impact |
| W2.1 | `MCV3_PW_MAX_CONTEXTS=1` | Sequential Playwright |
| W2.2 | `MCV3_FIX_BATCH1_PARALLEL_DISABLED=1` | Sequential Batch 1 |
| W3.1 | `MCV3_FIX_VERIFY_DELTA_DISABLED=1` | Mọi iter full scan |
| W3.2 | `MCV3_FIX_CI_BATCH_DISABLED=1` | Per-issue CI calls |
| W3.3 | `MCV3_FIX_SPOTCHECK_CACHE_DISABLED=1` | Mọi check fresh |

> Mọi env có thể set trong session để emergency rollback mà KHÔNG cần git revert.

---

## Final Review Checklist (Pre-Merge)

- [ ] All 8 tasks PASS acceptance criteria
- [ ] Compliance matrix 100% (mọi ✅ và ⚙️ verified)
- [ ] Benchmark report: speedup ≥50%, no regression
- [ ] CHANGELOG entry added (Vietnamese, ≤15 lines, non-specialist)
- [ ] Version bump correct (10.0.1 → 10.1.0 minor)
- [ ] `_contract.json` consistent với SKILL.md
- [ ] All escape hatches documented in CHANGELOG
- [ ] Smoke test với `--resume` (multi-session) PASS
