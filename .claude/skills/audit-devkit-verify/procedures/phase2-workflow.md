# Phase 2: Workflow Integrity

> `workflow-auditor` kiểm tra Cross-Skill Output Path Contract (rules/00-core.md §4b),
> phase prerequisites, và REQ-ID continuity.
> Áp dụng khi `$SCOPE` ∈ { `workflow`, `all`, `skill` }.

## PRE-GATE

- Phase 0 POST-GATE pass
- (nếu `$SCOPE = all`) Phase 1 POST-GATE pass — 4 crossref findings files valid
- (nếu `$SCOPE = skill`) Phase 1.F POST-GATE pass — focused crossref file valid
- (nếu `$SCOPE = workflow`) Phase 1 không chạy — dùng chỉ index + scan result

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Đọc `$SCAN_DIR/audit-index.json` (ground truth) | Read | loaded |
| 2.2 | Đọc 4 `$VERIFY_DIR/findings-crossref-*.json` (verified refs) — **skip nếu `$SCOPE = workflow`** (files chưa tạo); **nếu `$SCOPE = skill`** chỉ đọc `findings-crossref-$FOCUSED_SKILL.json` | Read | loaded (hoặc empty) |
| 2.3 | Đọc `.claude/rules/00-core.md` §4b (Cross-Skill Output Path Contract) | Read | contract table loaded |
| 2.4 | Spawn `workflow-auditor` với: index + crossref findings + §4b contract | Agent | Agent started |
| 2.5 | Agent trace TỪNG handoff trong §4b: | Agent | Checked |
|      | — Producer skill có output path trong POST-GATE? | | |
|      | — Consumer skill có input path trong PRE-GATE? | | |
|      | — Paths khớp CHÍNH XÁC (string match)? | | |
| 2.6 | Agent kiểm tra phase prerequisites: Phase N+1 PRE-GATE có check Phase N output? | Agent | Checked |
| 2.7 | Agent kiểm tra REQ-ID continuity: registry safe-write fields đúng per skill (§4a) | Agent | Checked |
| 2.8 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 2.9 | Write `$VERIFY_DIR/findings-workflow.json` (schema `audit-findings-v1`) | Write | File created |

## Focused filter (chỉ khi `$SCOPE = skill`)

Agent chỉ check handoffs liên quan đến `$FOCUSED_SKILL`:
- Rows trong §4b với producer = `$FOCUSED_SKILL` hoặc consumer = `$FOCUSED_SKILL`
- Downstream skill PRE-GATE (consumer)
- Upstream skill POST-GATE (producer)

Skip handoffs không liên quan → giảm tải cho agent.

## Auditor Prompt

Xem `_shared.md §Auditor Prompt Templates → Template workflow integrity`.
Finding id prefix: `F-WFL-`.

## POST-GATE

- `$VERIFY_DIR/findings-workflow.json` tồn tại
- JSON valid, schema `audit-findings-v1`
- Update `verify-status.json`: mark `phase2-workflow` completed

## Routing sau Phase 2

- Nếu `$SCOPE == "workflow"` → chuyển `phase4-merge.md` (partial scope verdict)
- Nếu `$SCOPE == "skill"` → tiếp tục `phase3-consistency.md`
- Nếu `$SCOPE == "all"` → tiếp tục `phase3-consistency.md`

## Errors liên quan

- **E006** — Agent timeout → re-spawn 1 lần
- **E007** — Agent trả text thay vì JSON → fallback parse
- **E012** — §4b contract table parse fail → fallback Read + regex extract

Chi tiết: `_shared.md §Error Handling Reference`.
