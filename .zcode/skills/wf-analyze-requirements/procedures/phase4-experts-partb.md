# Phase 4: Domain Experts — Phần B (PARALLEL)

> Mỗi expert phụ trách Phần B cho các departments thuộc Primary role của mình (từ `$EXPERT_DEPT_MAP` — Phase 2).
> Heavyweight depts (>= 4 domain areas) dùng Split Strategy: 2 expert calls tuần tự.

**PRE-GATE:** `test -s .mc-data/docs/phase1-business/departments/[dept]/[dept].md` cho TẤT CẢ departments (từ Phase 3)

**INPUT:** `[dept].md (Phần A)` + workflow template + `.claude/references/team-expert/[domain]/`

**OUTPUT:** `phase1-business/departments/[dept]/[dept].md` (Phần B thêm vào file hiện có, per dept)

```
BA Output ──┬→ Expert A: [dept-a].md (Phần B)
            ├→ Expert B: [dept-b].md (Phần B)
            └→ Expert C: [dept-c].md (Phần B)
```

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 4.1  | **Lane Dispatch (ADR-OPT-01):** Import `_shared/lane/dispatcher.py` theo `_shared.md §_shared Module Imports`. Build `LaneConfig` list cho mỗi dept ∈ `$ACTIVE_DEPTS`:<br>— `key = dept-slug` (lowercase-kebab-case)<br>— `agent_type = $EXPERT_DEPT_MAP[dept]` (domain-expert subagent name)<br>— `prompt = Template Expert Phần B` (xem `_shared.md §Agent Context Templates`) + LEGACY Context Injection (nếu `$LEGACY_MODE`)<br>— `output_path = $SESSION_DIR/lanes/{dept-slug}/signals.json`<br>— `context = {dept BA output path, legacy_context if any, deprecated_modules}`<br>**TRƯỚC KHI dispatch mỗi lane:** kiểm tra `grep -l "## Phần B" .mc-data/docs/phase1-business/departments/[dept]/[dept].md`. Nếu Phần B **đã tồn tại** → LOG "Skip [dept] — Phần B đã có" → **KHÔNG add vào lanes list** (giữ nguyên skip-if-exists logic). Call `dispatch_lanes(lanes, max_parallel=$MAX_PARALLEL_AGENTS, timeout_sec=300)`. | Lanes dispatched, `max_parallel <= 3` enforced (LPM) hoặc `<= 5` (Standard) |
| 4.1b | **Split Strategy cho Heavyweight Depts** (từ `$HEAVYWEIGHT_DEPTS` — Phase 2.3b): Nếu dept có `heavyweight=true` → lane agent spawn 2 calls tuần tự TRONG lane: call-1 viết sections primary (B1–B3), call-2 viết sections secondary (B4–B6) vào file `[dept]-b2.md`. Lane agent merge sau khi cả 2 hoàn thành: append nội dung `[dept]-b2.md` vào cuối `[dept].md`, xóa file tạm `[dept]-b2.md`. (Split logic không thoát ra khỏi lane — giữ write-scope isolation). | Split + merge success trong lane |
| 4.2  | Mỗi lane: verify `$SESSION_DIR/lanes/{dept-slug}/signals.json` tồn tại + non-empty (theo schema `_shared/templates/lane-signal.json` — `lane_key`, `lane_type="department"`, `items[]`, `metadata`) | `test -s $SESSION_DIR/lanes/{dept-slug}/signals.json` |
| 4.3  | Mỗi lane: verify `[dept].md` Phần B non-empty + no placeholders | `test -s [dept].md && grep -rL "TODO\|TBD" [dept].md` |
| 4.4  | **Sau MỖI lane complete: SAVE CHECKPOINT L2** — update `$SESSION_DIR/session-state.json`:<br>— `phases.P4.batches[{dept-slug}].status = "completed"`<br>— `phases.P4.batches[{dept-slug}].completed_at = <ISO>`<br>— `phases.P4.batches[{dept-slug}].signals_file = "lanes/{dept-slug}/signals.json"`<br>— `lanes_completed[]` append `{dept-slug}`<br>Mirror sang legacy `checkpoint.json` (dual-write). Cập nhật `analyze-status.json`: `phase_4.experts[expert_name].status = "completed"` | `jq -e '.phases.P4.batches["{dept-slug}"].status == "completed"' session-state.json` |
| 4.5  | **Post-batch artifact cleanup:** Sau khi TẤT CẢ lanes hoàn thành, scan thư mục `phase1-business/departments/` — xóa mọi file tạm (`*-b2.md`, `merge.sh`, `*.tmp`, `*.bak`) không phải output chính thức (`[dept].md`). Log danh sách file đã xóa vào `analyze-status.json` (`phase_4.cleanup_log`). | No artifacts remain |

## Agent Context

Xem `_shared.md §Agent Context Templates → Template Expert Phần B (Phase 4, per dept)`.

> **Subagent context fallback:** Nếu Agent tool không khả dụng → thực hiện `[domain-expert]` role inline. Ghi chú: "[domain-expert] role executed inline (no Agent tool)."

## ADR-OPT-01 Notes

- **Lane output schema:** `_shared/templates/lane-signal.json` — các field bắt buộc: `lane_key` (dept-slug), `lane_type="department"`, `items[]` (REQ entries), `metadata` (agent_type, duration_ms, profile).
- **Write-scope isolation (CORE-025):** Mỗi lane ghi vào `$SESSION_DIR/lanes/{dept-slug}/` riêng → không lock contention, song song hợp lệ theo priority order rule của 00-core §0.
- **Template Strip (ADR-OPT-05):** Trước khi ghi `signals.json`, strip `_template_notes` theo `_shared/_shared.md §1`.
- **Atomic Write (ADR-OPT-05):** tmp → validate → mv theo `_shared/_shared.md §2`.

**POST-GATE:**

```bash
# Tất cả expert files tồn tại, không có placeholders
test -s .mc-data/docs/phase1-business/departments/*/[dept].md
# Tất cả lane signals.json tồn tại
for dept in $ACTIVE_DEPTS; do test -s $SESSION_DIR/lanes/$dept/signals.json; done
# Tất cả lanes marked completed trong session-state
jq -e '.phases.P4.batches | to_entries | all(.value.status == "completed")' $SESSION_DIR/session-state.json
```

**Status update:**
- `analyze-status.json` → `phase_4.status = "completed"`, `phase_4.completed_at = <ISO timestamp>`, `phase_4.lanes_count = len($ACTIVE_DEPTS)`
- `$SESSION_DIR/session-state.json` → `phases.P4.status = "completed"`, `next_action = "phase5-existing-docs"` hoặc `"phase6-consolidate"`.

**Next phase:**
- Nếu `$HAS_EXISTING_DOCS = true` → `phase5-existing-docs.md`
- Nếu không → `phase6-consolidate.md`
