# Phase 0.5: Workload Gate (ADR-OPT-03)

> Ước lượng khối lượng phân tích requirements dựa trên `$ACTIVE_DEPTS` + registry counts.
> Đưa ra gate decision (dead_zone / warn / block) trước khi spawn BA + experts ở Phase 3-4.
> **BẮT BUỘC** cho mọi scope (`all`, `business`, `[module-name]`).

**PRE-GATE:**

```bash
# Phase 0 POST-GATE PASS
test -f .mc-data/work/wf-analyze-requirements/analyze-status.json
test -f .mc-data/work/wf-analyze-requirements/sessions/$SESSION_ID/session-state.json
jq -e '.phases.P0.status == "completed"' $SESSION_DIR/session-state.json
```

> **Forensic validation (Protocol 10.4):** `session-state.json` phải có `session_id` non-empty + `phases.P0.status = "completed"`. `$REGISTRY_DATA` phải load được trước khi tính partition.

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` với `$SESSION_ID`.

**INPUT:** `$REGISTRY_DATA` (systems, modules, departments, requirements) + `$ACTIVE_DEPTS` (từ Phase 0) + `$LEGACY_MODE` + project metadata

**OUTPUT:**
- `$SESSION_DIR/workload-report.md`
- `$SESSION_DIR/session-state.json` (phases.P0_5 updated)
- CDG token (nếu override gate BLOCK)

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 0.5.1 | Import `_shared/partition/planner.py` → `plan_partitions(items=$ACTIVE_DEPTS, group_key="department", max_per_partition=5)`. Input: list department objects từ `$REGISTRY_DATA.departments[]` (hoặc `$ACTIVE_DEPTS` nếu scope narrow). Output: `partitions` list. | Partitions generated, `len(partitions) >= 1` |
| 0.5.2 | Import `_shared/partition/workload_gate.py` → `estimate_workload(partitions, est_minutes_per_item=3.0, factor=$FACTOR)`. **Factor rules:** `1.0` normal, `1.5` nếu `$LEGACY_MODE=true`, `2.0` nếu multi-system (`systems.length >= 2`) + compliance domain (healthcare / finance / legal / insurance). | `WorkloadEstimate` object có `total_minutes`, `partition_count`, `items_count` |
| 0.5.3 | `check_workload_gate(estimate, threshold_minutes=45)`. Ratio = `total_minutes / 45`. | `GateResult` có `status ∈ {dead_zone, warn, block}` + `ratio` |
| 0.5.4 | **Gate decision routing:**<br>— `status = dead_zone` (ratio < 0.8) → silent continue, không prompt user.<br>— `status = warn` (0.8 ≤ ratio ≤ 1.5) → `AskUserQuestion` theo `_shared/partition/workload-gate-procedure.md §5` — 4 options (narrow scope / downgrade profile / Plan B partition / override+CDG).<br>— `status = block` (ratio > 1.5) → **BẮT BUỘC** hiện Plan A/B menu, không cho silent continue. Nếu user chọn "Override + CDG" → import `_shared/cdg/cdg_handler.py` → `create_cdg_token(cdg_id="CDG-A02-workload-override", decision="accept", context={...})` → ghi `$SESSION_DIR/cdg-tokens.json` (append). | User decision recorded trong `session-state.json.cdg_decisions[]` |
| 0.5.5 | **Tạo workload-report.md** (Template Usage Rule CORE-031):<br>1. READ template `_shared/templates/workload-report.md`<br>2. FILL placeholders: `{skill_name}=wf-analyze-requirements`, `{profile_used}=$PROFILE`, `{timestamp}=<ISO>`, `{items_count}`, `{partition_count}`, `{total_minutes}`, `{threshold_minutes}=45`, `{gate_status}`, `{ratio}`, `{gate_recommendation}` (theo table §2 của workload-gate-procedure), `{partition_rows}` (generate `\| # \| group_key \| items \| minutes \|` cho mỗi partition)<br>3. WRITE atomic: `$SESSION_DIR/workload-report.md.tmp` → validate → `mv` → `$SESSION_DIR/workload-report.md` (xem `_shared/_shared.md §2 Atomic Write`). | `test -s $SESSION_DIR/workload-report.md` |
| 0.5.6 | Update `$SESSION_DIR/session-state.json` (atomic):<br>— `phases.P0_5.status = "completed"`<br>— `phases.P0_5.completed_at = <ISO>`<br>— `phases.P0_5.workload_estimate = {total_minutes, partition_count, items_count, gate_status, ratio}`<br>— `next_action = "phase1-scope"`<br>— Nếu có CDG → `cdg_decisions[]` append entry | `jq -e '.phases.P0_5.status == "completed"' session-state.json` |

## Gate Status → Behavior

| Gate Status | Ratio | Behavior | CDG Required |
|-------------|-------|----------|--------------|
| `dead_zone` | < 0.8 | Silent continue → Phase 1 | No |
| `warn` | 0.8 – 1.5 | Prompt user với Plan A options (optional override) | Only if override |
| `block` | > 1.5 | **BẮT BUỘC** prompt user → chọn Plan A/B → override chỉ khi CDG accept | **Yes** (CDG-A02) |

## Variable Setters

- `$WORKLOAD_ESTIMATE` = WorkloadEstimate object (Step 0.5.2)
- `$GATE_RESULT` = GateResult object (Step 0.5.3)

## POST-GATE

```bash
test -s $SESSION_DIR/workload-report.md
jq -e '.phases.P0_5.status == "completed"' $SESSION_DIR/session-state.json
# Nếu gate_status = "block" và không có CDG token → FAIL
jq -e '.phases.P0_5.workload_estimate.gate_status != "block" or (.cdg_decisions | map(select(.cdg_id == "CDG-A02-workload-override")) | length > 0)' $SESSION_DIR/session-state.json
```

**Status update:** `analyze-status.json` → `phase_0_5.status = "completed"`, `phase_0_5.gate_status`, `phase_0_5.ratio`.

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: `phase_id=0.5`, `status=completed`, `items_processed` ({items_count} items, {partition_count} partitions), `key_findings` (ước lượng {total_minutes} phút, gate {gate_status}, ratio {ratio}), `next_action` (Phase 1 scope)
3. WRITE: `.mc-data/work/wf-analyze-requirements/phase-summary.md` (append, không ghi đè phase 0)

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

## Fix Rules

| Lỗi | Auto-Fix | Escalate nếu |
|-----|----------|--------------|
| `plan_partitions` return rỗng | Re-run với `$ACTIVE_DEPTS` từ registry.departments thay vì P0 Section 2 | Vẫn rỗng → E005 |
| `estimate_workload` trả `total_minutes = 0` | Check `est_minutes_per_item > 0` + partitions non-empty | Struct sai → E007 |
| User từ chối gate block 2 lần liên tiếp | Anti-loop (xem `_shared/cdg/cdg-handoff-procedure.md §4`) → escalate | — |
| `workload-report.md` không ghi được | Retry atomic write 1 lần | Permission issue → STOP |

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E020 | `plan_partitions` raise exception | Check input shape (items phải có key `department`) |
| E021 | Gate block + CDG reject | STOP — user phải chạy lại với narrower scope |
| E022 | `workload-report.md` write fail | Retry 1 lần → escalate |

**Next phase:** `phase1-scope.md`
