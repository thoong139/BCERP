# Phase 5 Group D — Spawn wf-fix-triage Agent (Step 5.5)

> **Entry condition:** Group C POST-GATE PASS (violations evaluated, pipeline not aborted).
> **Exit condition:** `bug-triage.md` + `fix-plan.md` + `fix-log.json` written bởi spawned agent.
> **Next:** [phase5-triage/E-validate-handoff.md](E-validate-handoff.md) (POST-GATE + CDG Pre-Execute).
>
> **Shared protocols cần thiết:**
> - [`_shared/15-agent-prompts.md`](../_shared/15-agent-prompts.md) — Triage Agent prompt template (8 sections CORE-037)
> - [`_shared/12-ci-detection.md`](../_shared/12-ci-detection.md) — CI context injection

> **⚠ GIỮ ORCHESTRATOR-SIDE — KHÔNG extract sang script:** Agent tool call (CORE-037). KHÔNG script được.

## Input contract (env vars từ Group C)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$CI_CONTEXT`, `$PROFILE`, `$SCOPE`, `$LEGACY_MODE` | Pipeline state |
| `$TOTAL_ISSUES` | Từ Group B |
| `phase5-triage/issue-registry.json` | Source cho triage analysis |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase5-triage/bug-triage.md` | 5.5 | Bảng severity + fixability per issue |
| `phase5-triage/fix-plan.md` | 5.5 | Execution plan với thứ tự ưu tiên |
| `phase5-triage/fix-log.json` | 5.5 | Init từ template (entries array) |

---

## Step 5.5 — Spawn wf-fix-triage Agent

**Mục đích:** Dispatch triage agent để phân loại severity, đánh giá fixability, tạo fix-plan.

**Điều kiện:** Step 5.4 PASS — violations evaluated, pipeline not aborted.

**v10.10.0 — Context Budget Check (CORE-038):** Triage agent là 1 trong 2 điểm spike context cao nhất pipeline (read full issue-registry + generate fix-plan).

```bash
. .claude/scripts/wf-fix-common.sh
_context_budget_check 5 "5.5" || rc=$?
case "${rc:-0}" in
  3) exit 9 ;;       # E009 FORCE STOP — không spawn
  2) echo "WARN: Context 80-90% — chạy Step 5.5 xong sẽ STOP, dùng --resume" >&2
     STOP_AFTER_PHASE5=true ;;
  1) echo "INFO: Context 65-80% — checkpoint sẽ được lưu sau Step 5.5" >&2 ;;
esac
```

**Agent Prompt Template (CORE-037 — 8 sections):**

```
Bạn là wf-fix-triage agent cho Phase 5 của wf-fix-bugs pipeline.

1. **Role:** Classify và triage bugs từ aggregated issue registry. Phân loại severity
   (critical/high/medium/low), đánh giá fixability (easy/medium/hard/complex/impossible),
   tạo fix-plan với execution order.

2. **Task:** Đọc issue-registry.json → phân loại từng issue → generate 2 output files.

3. **Session Context:**
   - SESSION_DIR: $SESSION_DIR
   - PROFILE: $PROFILE
   - SCOPE: $SCOPE
   - LEGACY_MODE: $LEGACY_MODE
   - TOTAL_ISSUES: $TOTAL_ISSUES

4. **CI Context:** $CI_CONTEXT (nếu available, dùng GitNexus impact analysis cho severity)

5. **Playwright Context:** KHÔNG áp dụng (wf-fix-triage không launch browser — chỉ classify).
   Nếu cần re-verify runtime trong tương lai, delegate qua re-spawn QD9/QD5.

6. **Output Contract:**
   - bug-triage.md: Bảng severity + fixability per issue, executive summary
   - fix-plan.md: Execution plan với thứ tự ưu tiên, dependencies, estimated effort
   - fix-log.json: Init từ template templates/phase5-triage/fix-log.json

7. **Ownership Rules:** CHỈ ghi vào $SESSION_DIR/phase5-triage/. KHÔNG ghi đè
   issue-registry.json (Phase 4 output). KHÔNG ghi vào lanes/. KHÔNG ghi vào phase6-execute/.
   1 file = 1 writer (CORE-025).

8. **Completion Criteria:**
   - bug-triage.md tồn tại + không rỗng + có severity distribution
   - fix-plan.md có Execution Plan section
   - fix-log.json valid JSON với .entries array
```

```javascript
Agent({
  subagent_type: "claude",
  model: "opus",
  description: "Triage bugs per issue-registry.json",
  prompt: "<rendered prompt above with substituted vars>"
})
```

> **Lưu ý:** Substitute `$SESSION_DIR`, `$PROFILE`, `$SCOPE`, `$LEGACY_MODE`, `$TOTAL_ISSUES`, `$CI_CONTEXT` vào prompt trước khi gọi Agent tool.

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase5-triage/bug-triage.md"
test -s "$SESSION_DIR/phase5-triage/fix-plan.md"
test -s "$SESSION_DIR/phase5-triage/fix-log.json"
jq -e '.entries' "$SESSION_DIR/phase5-triage/fix-log.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E053 | Agent spawn fail (timeout > 15 phút) | Re-spawn x1 với model=opus → ESCALATE |
| E053 | bug-triage.md rỗng | Generate stub từ template + ESCALATE |
| E053 | fix-plan.md không có Execution Plan | Re-spawn x1 |
| E053 | fix-log.json parse fail | Init từ template + retry |

**Cross-ref:** CORE-037 (Agent Templates), CORE-025 (1 file = 1 writer), CORE-033 (CI Context), CORE-038 (Context Budget).

---

## Group D POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase5-triage/bug-triage.md" && \
test -s "$SESSION_DIR/phase5-triage/fix-plan.md" && \
test -s "$SESSION_DIR/phase5-triage/fix-log.json" && \
jq -e '.entries' "$SESSION_DIR/phase5-triage/fix-log.json" >/dev/null && \
  echo "Group D PASS" || echo "Group D FAIL"
```

## Next Group

→ Group E Validate + CDG Pre-Execute Handoff — đọc [`phase5-triage/E-validate-handoff.md`](E-validate-handoff.md)
