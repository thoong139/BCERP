# Phase 1: Architecture Overview

> Architect agent thiết kế high-level architecture — làm nền cho tất cả specs sau.
> Conditional agents (ai-engineer, data-engineer, automation-architect) append sections nếu domain có AI/ML, data pipeline, hoặc workflow automation.

**PRE-GATE:**

```bash
test -n "$APPROACH"
test -n "$REGISTRY_DATA"
test -s .mc-data/work/wf-design/execution-plan.md
test -n "$SESSION_DIR"
jq -e '.phases.P0_5.status == "completed"' $SESSION_DIR/session-state.json
```

**INPUT:**
- `$REGISTRY_DATA` + `$TARGET_SYSTEMS` + `$TARGET_MODULES`
- `phase2-features/**/*.md` (hoặc `$FEATURE_DIGEST_PATH` nếu có)
- `.mc-data/work/wf-define-features/deferred-findings.md` (nếu có)
- Template `.claude/doc-framework/phase3-architecture/P3-01-architecture.md`

**OUTPUT:** `.mc-data/docs/phase3-architecture/P3-01-architecture.md`

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | `mkdir -p .mc-data/docs/phase3-architecture/technical-specs/` + `mkdir -p $SESSION_DIR/lanes/` | Directories exist |
| 1.2 | **Lane Dispatch (ADR-OPT-01):** Import `_shared/lane` → Build `LaneConfig` list — mỗi system trong `$ACTIVE_SYSTEMS` tạo 1 lane:<br>`LaneConfig(key="{system-slug}", agent_type="architect", prompt=P1-A template từ _shared.md, output_path=$SESSION_DIR/lanes/{system-slug}/signals.json, context={system features, feature-briefs digest, legacy context nếu LEGACY})`.<br>**SKIP-IF-EXISTS:** Nếu `$SESSION_DIR/lanes/{sys}/signals.json` tồn tại + non-empty → skip lane đó, log "Lane {sys} đã có signals — skip".<br>`dispatch_lanes(lanes, max_parallel=$LPM_PARAMS.max_parallel_agents, timeout_sec=600)`.<br>**(v5.0)** Nếu `$DOMAIN_HINTS` non-empty → inject vào agent prompt section "Domain Context Hints" — modules với confidence >= 0.5. | Lanes dispatched, all `signals.json` non-empty |
| 1.3 | Conditional agents (ai-engineer / data-engineer / automation-architect) theo `$HAS_AI_ML`, `$HAS_DATA_PIPELINE`, `$HAS_AUTOMATION` — spawn trong **cùng lane** của system tương ứng (child process trong lane), KHÔNG tách lane riêng. **LPM override:** nếu tổng conditional agents >= 3 → SEQUENTIAL sau architect lane. **SKIP-IF-EXISTS:** grep section heading trong P3-01-architecture.md nếu đã có → skip. | Conditional agents appended (hoặc skip) |
| 1.4 | **Assemble P3-01-architecture.md:** Merge outputs từ tất cả lane signals → ghi `.mc-data/docs/phase3-architecture/P3-01-architecture.md` theo template `doc-framework/phase3-architecture/P3-01-architecture.md`. Nếu multi-system: tổng hợp architecture section chung + per-system subsections. | `test -s P3-01-architecture.md` |
| 1.5 | **Verify lane outputs:** Mỗi lane: `test -s $SESSION_DIR/lanes/{sys}/signals.json` | Tất cả signals.json tồn tại + non-empty |
| 1.6 | **SAVE CHECKPOINT (session-state.json):** SET `phases.P1.status = "completed"`, `phases.P1.batches[{sys}].status = "completed"` cho mỗi system. SET `next_action = "phase2-specs-parallel"`. Sync → `checkpoint.json` backward-compat. | `jq '.phases.P1.status' session-state.json → "completed"` |

---

## Execution Strategy

```
Lane Dispatch (ADR-OPT-01):
  System A lane ──┬→ architect (P1-A) ──┬→ signals.json (sys-a)
                  ├── ai-engineer (conditional, cùng lane)
                  ├── data-engineer (conditional, cùng lane)
                  └── automation-architect (conditional, cùng lane)

  System B lane ──→ architect (P1-A) ──→ signals.json (sys-b)

  max_parallel = $LPM_PARAMS.max_parallel_agents (Standard: 5, LPM: 3)

LPM override (nếu tổng conditionals >= 3 VÀ LPM = true):
  Architect (1.2) → sequential conditionals trong mỗi lane
```

**Lane output schema** (`signals.json`):
```json
{
  "lane_type": "system",
  "system_slug": "{system-slug}",
  "items": [
    { "component_id": "COMP-SYS-001", "name": "...", "type": "service/module/...", "dependencies": [] }
  ],
  "conditional_sections": ["ML Pipeline Architecture", "Data Pipeline Architecture"]
}
```

Tham khảo agent prompts: `_shared.md` §Agent Prompt Templates (P1-A / P1-B / P1-C / P1-D).
Nếu `$LEGACY_MODE = true`: inject LEGACY BLOCK vào mọi agent prompt (xem `_shared.md` §LEGACY Context Injection).

---

## POST-GATE

```bash
# T1: File existence + non-empty
test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md

# T2: Content quality — >= 7 headings và >= 500 words
HEADINGS=$(grep -c '^#' .mc-data/docs/phase3-architecture/P3-01-architecture.md)
WORDS=$(wc -w < .mc-data/docs/phase3-architecture/P3-01-architecture.md)
[ "$HEADINGS" -ge 7 ] && [ "$WORDS" -ge 500 ]
```

Nếu FAIL → retry tạo lại P3-01-architecture.md (tối đa 3 lần). Nếu vẫn fail sau 3 retries → E010, STOP với báo cáo chi tiết.

**(Protocol 8 — CQG-08) Content Quality Checks:**
1. Architecture sections đầy đủ: Quyết Định, Sơ Đồ, Danh Sách Phân Hệ, Phân Quyền Dữ Liệu, Giao Tiếp, Quy Ước, Môi Trường (7 required)
2. Modules trong architecture khớp `$TARGET_MODULES` (không có module ngoài registry)
3. REQ-IDs referenced trong ít nhất section Quyết Định Kiến Trúc

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E003 | Agent timeout / không trả output | Re-spawn 1 lần; nếu vẫn fail → escalate |
| E004 | Architecture conflict giữa agent outputs | Flag conflict, present cả hai options cho user quyết định |
| E005 | Output file write fail | Retry 3 lần, sau đó escalate to user |
| E010 | POST-GATE fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |

---

## Next Phase

→ Read `procedures/phase2-specs-parallel.md` — Technical Specs PARALLEL (API + DB + Infra)
