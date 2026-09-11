# Phase 6 Group D — Spawn wf-fix-execute Agent (Step 6.4)

> **Entry condition:** Group C POST-GATE PASS (CI impact done, user accepted nếu có HIGH/CRITICAL).
> **Exit condition:** `fix-report.md` + `docs-sync-report.json` written bởi spawned agent.
> **Next:** [phase6-execute/E-validate-dashboard.md](E-validate-dashboard.md) (Validate + Dashboard).
>
> **Shared protocols cần thiết:**
> - [`_shared/15-agent-prompts.md`](../_shared/15-agent-prompts.md) — Execute Agent prompt template (8 sections CORE-037)
> - [`_shared/12-ci-detection.md`](../_shared/12-ci-detection.md) — CI context injection

> **⚠ GIỮ ORCHESTRATOR-SIDE — KHÔNG extract sang script:** Agent tool call (CORE-037). KHÔNG script được.

## Input contract (env vars từ Group C HOẶC Loop-back từ Step 6.5b)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$CI_CONTEXT`, `$PROFILE`, `$SCOPE`, `$NAME` | Pipeline state |
| `phase5-triage/{fix-plan.md, issue-registry.json, fix-log.json}` | Inputs cho execute agent |
| `phase6-execute/ci-impact-report.json` | CI impact (consumed bởi agent) |
| **v11 Loop-back context (nếu re-spawned từ Step 6.5b):** | |
| `$LOOP_ITERATION` | Iteration number (1, 2, 3) — 0 nếu first-spawn |
| `$UNSANCTIONED_FOCUS` | "true" → agent CHỈ fix items trong unsanctioned-defers.json |
| `$EXPERT_OVERRIDE` | "true" → spawn domain expert agent (architect/security/...) cho scope thu hẹp (sau CDG E095) |
| `phase6-execute/unsanctioned-defers.json` | Danh sách items cần focus khi UNSANCTIONED_FOCUS=true |
| `phase6-execute/fix-iterations.json` | History prior iterations (read-only, prior agent_decisions) |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase6-execute/fix-report.md` | 6.4 | Execute agent output (Fixed/Deferred/Failed) |
| `phase6-execute/docs-sync-report.json` | 6.4 | Docs/registry sync log |
| Code edits in repo | 6.4 | Per fix-plan scope |

---

## Step 6.4 — Spawn wf-fix-execute Agent

**Mục đích:** Spawn execute agent để thực hiện fix code, sync docs, verify kết quả.

**v10.10.0 — Context Budget Check (CORE-038):** Execute agent là điểm context spike cao nhất pipeline (read fix-plan + edit nhiều files + sync docs).

```bash
. .claude/scripts/wf-fix-common.sh
_context_budget_check 6 "6.4" || rc=$?
case "${rc:-0}" in
  3) exit 9 ;;       # E009 FORCE STOP
  2) echo "WARN: Context 80-90% — Step 6.4 sẽ chạy nhưng STOP sau Step 6.5, dùng --resume từ Phase 7" >&2
     STOP_AFTER_PHASE6=true ;;
  1) echo "INFO: Context 65-80% — checkpoint sẽ lưu sau Phase 6 finalize" >&2 ;;
esac
```

**Agent Prompt Template (CORE-037 — 8 sections):**

```
Bạn là wf-fix-execute agent cho Phase 6 của wf-fix-bugs pipeline.

1. **Role:** Thực hiện fix code theo fix-plan.md, sync docs + registry, emit
   fix-report.md + docs-sync-report.json. Tuân thủ CDG markers, KHÔNG sửa ngoài scope.
   ${LOOP_ITERATION > 0 ? "**v11 LOOP MODE iter $LOOP_ITERATION**: ĐÂY LÀ RE-SPAWN do Phase 6 Step 6.5b phát hiện unsanctioned defers. PHẢI FORCE-FIX hoặc ghi blocker rationale CỤ THỂ — KHÔNG silent defer." : ""}

2. **Task:** Đọc .claude/skills/workflow/wf-fix-execute/SKILL.md và thực thi đầy đủ.

3. **Session Context:**
   - SESSION_DIR: $SESSION_DIR
   - Fix plan: $SESSION_DIR/phase5-triage/fix-plan.md
   - Issue registry: $SESSION_DIR/phase5-triage/issue-registry.json
   - Fix log: $SESSION_DIR/phase5-triage/fix-log.json
   - PROFILE: $PROFILE, SCOPE: $SCOPE, NAME: $NAME, DRY_RUN: false
   ${LOOP_ITERATION > 0 ? "- LOOP_ITERATION: $LOOP_ITERATION (max 3)" : ""}
   ${UNSANCTIONED_FOCUS == "true" ? "- UNSANCTIONED_FOCUS: true → CHỈ fix items có id trong unsanctioned-defers.json" : ""}
   ${EXPERT_OVERRIDE == "true" ? "- EXPERT_OVERRIDE: true → user đã chấp nhận force-fix với expert agent (qua CDG E095)" : ""}

4. **CI Context:** $CI_CONTEXT
   (Nếu available — GitNexus impact analysis TRƯỚC khi sửa mỗi file để xác định
   blast radius; Serena find_referencing_symbols để verify không phá callers.)

5. **Playwright Context:** KHÔNG áp dụng (chỉ sửa code/docs/registry).
   Re-verify runtime sẽ được trigger ở Phase 7 verify loop nếu QD9/QD5/QD7 cần.

6. **Output Contract:**
   - fix-report.md: Danh sách fixes + kết quả per issue, summary statistics (Fixed/Deferred/Failed counts)
   - docs-sync-report.json: Records docs/registry updates (REQ-ID annotations, impl_status)
   - Mỗi file code sửa → kiểm tra REQ-ID annotation (CORE-003)
   - Sau khi sửa → chạy git diff --stat để liệt kê files changed
   - **v11 Loop mode (nếu LOOP_ITERATION > 0):**
     · Mỗi item KHÔNG fix được PHẢI ghi entry vào `phase6-execute/fix-blockers.md`
       với issue_id + technical_reason + suggested_action
     · APPEND entry vào `phase6-execute/fix-iterations.json[].agent_decisions[]` với
       {issue_id, action: "fixed|deferred|blocked", rationale}
     · KHÔNG ghi đè fix-report.md cũ — APPEND section "## Loop Iteration $LOOP_ITERATION"

7. **Ownership Rules:** CHỈ ghi vào $SESSION_DIR/phase6-execute/. KHÔNG ghi đè
   fix-plan.md hoặc issue-registry.json. KHÔNG ghi vào phase7-verify/.
   Code edit trong repo OK theo fix-plan scope. 1 file = 1 writer (CORE-025).
   Tuân thủ Registry Safe-Write (CORE-006).

   **FORBIDDEN DEFERS (v11 — Wave 2 G3):**
   - KHÔNG được defer items có fixability ∈ {AUTO_FIX, AGENT_FIX, auto_fix,
     agent_fix} trong fix-report.md hoặc fix-log.json. Triage ĐÃ quyết
     những items này có thể fix → execute agent phải HONORS quyết định đó.
   - Nếu KHÔNG THỂ fix (technical blocker, env issue, missing dependency,
     etc.) → ghi vào `$SESSION_DIR/phase6-execute/fix-blockers.md` với
     rationale rõ ràng + đề xuất escalation path. KHÔNG silently defer.
   - Agent ghi `result="deferred"` trong fix-log CHỈ KHI fixability ∈
     {MANUAL_FIX, ESCALATE, SKIP, manual_fix, escalate, skip} — đây là
     deferred LEGITIMATE.
   - Vi phạm sẽ bị detect bởi `verify-defer-reasons.sh` (Step 6.5 Wave 2
     loop) → trigger re-spawn iteration để fix lại scope thu hẹp.

8. **Completion Criteria:**
   - fix-report.md tồn tại + không rỗng + có ## Summary section + Fixed/Deferred/Failed counts
   - docs-sync-report.json valid JSON với .files_synced + .registry_updated fields
   - Outputs phải pass POST-GATE T1-T4 validation
   - Mọi fix tuân thủ CDG markers từ fix-plan.md
   - **v11 contract:** Mọi item trong fix-plan.md với action="fix" và
     fixability=auto_fix/agent_fix PHẢI có fix-log entry với
     `result ∈ {fixed, resolved, verified_resolved}` HOẶC bằng chứng
     blocker trong `fix-blockers.md`. Items với `result="deferred"` MUST
     kèm `notes` field giải thích lý do deferred trong fix-log entry.
```

```javascript
Agent({
  subagent_type: "claude",
  model: "opus",
  description: "Execute bug fixes per fix-plan.md",
  prompt: "<rendered prompt above with substituted vars>"
})
```

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase6-execute/fix-report.md"
test -s "$SESSION_DIR/phase6-execute/docs-sync-report.json"
jq -e '.files_synced >= 0' "$SESSION_DIR/phase6-execute/docs-sync-report.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E060 | Agent spawn fail (timeout) | Re-spawn x1 với fallback model → escalate |
| E061 | fix-report.md trống | Re-spawn x1 với prompt nhấn mạnh output contract |
| E061 | docs-sync-report.json trống | Re-spawn x1 → escalate |
| EDLG | Sub-skill execution error | Ghi error-ledger, re-spawn x1 scope thu hẹp |

**Cross-ref:** CORE-037 (Agent Prompt), CORE-033 (CI Context), CORE-034 (Auto-Fix Budget), CORE-025.

---

## Group D POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase6-execute/fix-report.md" && \
test -s "$SESSION_DIR/phase6-execute/docs-sync-report.json" && \
jq -e '.files_synced >= 0' "$SESSION_DIR/phase6-execute/docs-sync-report.json" >/dev/null && \
  echo "Group D PASS" || echo "Group D FAIL"
```

## Next Group

→ Group E Validate + Dashboard — đọc [`phase6-execute/E-validate-dashboard.md`](E-validate-dashboard.md)
