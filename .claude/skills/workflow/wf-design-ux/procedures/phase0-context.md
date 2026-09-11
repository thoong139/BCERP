# Phase 0: Context Loading & UI Check

> Load context, kiểm tra interface_type, detect LEGACY_MODE, setup LPM, cache contract.
> EXIT sớm nếu `interface_type = api-only`.
> Entry point của flow — đọc file này NGAY KHI SKILL.md route vào procedures/.

**PRE-GATE:**
- `test -f .mc-data/docs/_meta/req-registry.json`
- `test -f .mc-data/docs/phase3-architecture/P3-01-architecture.md`

> **Forensic validation (Protocol 10.4):** P3-01-architecture.md phải có >= 7 headings và >= 500 words.
> Nếu FAIL → "P3-01-architecture.md không đạt yêu cầu nội dung. Chạy `/wf-design` để hoàn thiện."

**INPUT:** Registry + P3-01-architecture.md + checkpoint (nếu `--resume`) + project-context.md (nếu LEGACY)

**OUTPUT:**
- `$SESSION_DIR/session-state.json` (init)
- `$SESSION_DIR/design-ux-status.json`
- `.mc-data/work/wf-design-ux/design-ux-plan.md`
- `$SESSION_DIR/checkpoint.json` (init)
- `.mc-data/work/wf-design-ux/latest` (pointer tới `$SESSION_ID`)
- In-memory state: `$LEGACY_MODE`, `$INTERFACE_TYPE`, `$SYSTEMS_WITH_UI`, `$LARGE_PROJECT`, `$LPM_PARAMS`, `$PHASE4_CONTRACT`, `$DEPRECATED_MODULES`, `$SESSION_DIR`, `$SESSION_ID`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Large Project Mode (LPM)
- `_shared.md` §LEGACY_MODE Detection
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Parse `$ARGUMENTS` — check `--status`, `--resume`, `all`, `[system-name]` flags | Args validated |
| 0.2 | `mkdir -p .mc-data/work/wf-design-ux/sessions/` | `test -d .mc-data/work/wf-design-ux/sessions` |
| 0.2b | **Session Creation (ADR-OPT-02):** Generate `$SESSION_ID = YYYYMMDD-HHMMSS-{hash4}` (4 ký tự hex từ timestamp hash). `$SESSION_DIR = .mc-data/work/wf-design-ux/sessions/$SESSION_ID`. `mkdir -p $SESSION_DIR/lanes`. Ghi `$SESSION_ID` vào `.mc-data/work/wf-design-ux/latest`. Init `$SESSION_DIR/session-state.json`: `{session_id, created_at, skill: "wf-design-ux", phases: {}, flags: {}}`. Cleanup: xóa sessions cũ nếu > 5. | `test -d $SESSION_DIR/lanes && test -s $SESSION_DIR/session-state.json` |
| 0.3 | **[READ-TEMPLATE]** READ `templates/design-ux-status.json` → POPULATE fields (skill_id, scope, target, interface_type=UNKNOWN, context_sources) → WRITE `$SESSION_DIR/design-ux-status.json` | `test -s $SESSION_DIR/design-ux-status.json` |
| 0.4 | Đọc `req-registry.json` → extract `$INTERFACE_TYPE`, `features[]`, `systems[]` | Values loaded |
| 0.5 | **UI GUARD** — xem §UI Guard Block bên dưới | Skill EXIT hoặc tiếp tục |
| 0.6 | Detect `$LEGACY_MODE` theo `_shared.md §LEGACY_MODE Detection` | `$LEGACY_MODE` set |
| 0.7 | Nếu `$LEGACY_MODE = true`: load `$LEGACY_CONTEXT` + `$LEGACY_DECISIONS` + extract `$DEPRECATED_MODULES` | Legacy state loaded |
| 0.8 | Load feature specs từ `phase2-features/[sys]/[mod]/[feat].md` (metadata only — paths + IDs) | Feature list ready |
| 0.9 | Load `phase3-architecture/technical-specs/api-contract.md` (reference — không cache toàn bộ) | File tồn tại |
| 0.10 | Load `phase3-architecture/stakeholder-review.md` — extract deferred findings từ `/wf-design` | Findings ready |
| 0.11 | **RESUME BRANCH** — nếu `--resume`: xem §Resume Logic | Checkpoint loaded + reconciled |
| 0.12 | **[PLN-09] System Batching Plan** — xem §Execution Plan Population | `design-ux-plan.md` ready |
| 0.13 | **[Protocol 6.6] LPM DETECT** — xem §LPM Detection | `$LARGE_PROJECT`, `$LPM_PARAMS` set |
| 0.14 | **[SCAFFOLD-FIRST] LOAD CONTRACT** — Đọc `.claude/doc-framework/phase4-ux/_contract.json` → cache `$PHASE4_CONTRACT`. Log: "design-system: N, navigation: N, screen-group: N". Nếu file không tồn tại → WARN và tiếp tục. | `$PHASE4_CONTRACT` cached |
| 0.15 | **SAVE CHECKPOINT (init)** — READ `templates/checkpoint.json` → POPULATE (trigger=phase0_init, position.current_phase=0, progress={}, session_id=$SESSION_ID) → WRITE `$SESSION_DIR/checkpoint.json` | Checkpoint saved |

---

## UI Guard Block (Step 0.5)

```
Nếu $INTERFACE_TYPE == "api-only":
  (a) mkdir -p .mc-data/docs/phase4-ux/
  (b) Tạo .mc-data/docs/phase4-ux/stakeholder-review.md với nội dung:
      # Phase 4 UX — Skipped (API-Only)
      > interface_type=api-only. Phase 4 UX không áp dụng.
      > Ngày: [current date]
  (c) Update design-ux-status.json: {status: "skipped", reason: "api-only"}
  (d) Hiển thị: "Dự án không có UI, skip /wf-design-ux. Placeholder created. Chạy /wf-plan-modules tiếp theo."
  (e) EXIT skill

Nếu $INTERFACE_TYPE không xác định:
  → AskUserQuestion: web / mobile / web+mobile / api-only
  → Set $INTERFACE_TYPE theo câu trả lời
  → Nếu api-only → về nhánh trên
```

**Sau guard:** `$SYSTEMS_WITH_UI` = array systems có `interface_type != "api-only"` từ registry.

---

## Resume Logic (Step 0.11 — chỉ khi `--resume`)

```
# Đọc latest session ID
IF test -f .mc-data/work/wf-design-ux/latest:
  LATEST_SESSION_ID = cat .mc-data/work/wf-design-ux/latest
  LATEST_SESSION_DIR = .mc-data/work/wf-design-ux/sessions/$LATEST_SESSION_ID
ELSE:
  LATEST_SESSION_DIR = ""

IF LATEST_SESSION_DIR != "" AND test -f $LATEST_SESSION_DIR/session-state.json:
  primary_checkpoint = đọc $LATEST_SESSION_DIR/checkpoint.json
  $SESSION_DIR = $LATEST_SESSION_DIR
  $SESSION_ID = $LATEST_SESSION_ID
ELSE IF test -f .mc-data/work/legacy-scan/ux-checkpoint.json:
  primary_checkpoint = đọc ux-checkpoint.json  [LEGACY fallback — v3.x sessions]
ELSE:
  STOP: "Không tìm thấy checkpoint. Chạy /wf-design-ux từ đầu."
```

**Freshness check:** re-read registry, so sánh `features[]` count + `$INTERFACE_TYPE` với checkpoint data.
Nếu registry đã thay đổi → CẢNH BÁO user: "Registry đã thay đổi từ lúc checkpoint. Tiếp tục có thể gây unexpected behavior. Có muốn tiếp tục không?"

**Filesystem reconciliation:**
```bash
actual_ux_files=$(find .mc-data/docs/phase4-ux/ -name "*.md" ! -name "stakeholder-review.md" | wc -l)
```
So sánh `actual_ux_files` với `checkpoint.files_created` → nếu lệch → cập nhật checkpoint, log:
"Reconciled: tìm thấy [N] file phase4 trên disk — tiếp tục từ phase [P]".

**Jump target:** Xác định phase/step tiếp theo từ `checkpoint.position.current_phase` → trả về SKILL.md để route.

---

## --status Handler

```
IF $ARGUMENTS chứa "--status":
  IF test -f .mc-data/work/wf-design-ux/checkpoint.json:
    checkpoint = đọc wf-design-ux/checkpoint.json
  ELSE IF test -f .mc-data/work/legacy-scan/ux-checkpoint.json:
    checkpoint = đọc ux-checkpoint.json

  IF checkpoint loaded:
    actual_ux_files = find .mc-data/docs/phase4-ux/ -name "*.md" ! -name "stakeholder-review.md" | wc -l
    → Hiển thị trạng thái theo project_type (legacy hoặc new)
    → Bao gồm: "Files phase4 trên disk: [actual_ux_files]"
    → Nếu lệch checkpoint → "(checkpoint chưa đồng bộ — chạy --resume để reconcile)"
    → STOP
  ELSE IF test -f .mc-data/work/wf-design-ux/design-ux-status.json:
    → Hiển thị từ design-ux-status.json
    → STOP
  ELSE:
    → "Chưa có design-ux session nào."
    → STOP
```

---

## LPM Detection (Step 0.13)

```
$LARGE_PROJECT = (systems.length >= 5) OR (features.length >= 40)

IF $LARGE_PROJECT:
  $LPM_PARAMS = {
    compression_threshold: 2,
    digest_size: 300,
    skeleton_threshold: 2000,
    max_parallel_agents: 3,
    checkpoint_strategy: "per_system",
    output_targets: "LPM"
  }
  Log: "Large Project Mode: ON"
ELSE:
  $LPM_PARAMS = {
    compression_threshold: 3,
    digest_size: 200,
    skeleton_threshold: 3000,
    max_parallel_agents: 5,
    checkpoint_strategy: "per_batch",
    output_targets: "Standard"
  }
  Log: "Large Project Mode: OFF"
```

Ghi `large_project_mode: true/false` vào `design-ux-status.json`.

---

## Execution Plan Population (Step 0.12)

**[READ-TEMPLATE]** READ `templates/design-ux-plan.md` → POPULATE 9 sections → WRITE `.mc-data/work/wf-design-ux/design-ux-plan.md`.

| Template Section | Nội dung điền |
|-----------------|---------------|
| §1 Meta Information | Design UX ID, scope, `$INTERFACE_TYPE`, timestamps |
| §1.1 Systems có UI | Bảng systems + modules có UI + priority (từ `$SYSTEMS_WITH_UI`) |
| §1.2 Screen Groups dự kiến | Bảng screen groups dự kiến (extract từ features) |
| §1.3 Context Budget Allocation | Bảng `System / Est. Screens / Est. Tokens / % Budget` |
| §2 Session Breakdown | Multi-session plan với phases per session |
| §3 File-Level Progress | Bảng output files + status (khởi tạo = pending) |
| §4 Context Sources | Input file paths + found/not_found status |
| §5 Agent Assignment | Agent per phase (xem `_shared.md §Agent Prompt Templates`) + Parallel Strategy |
| §6 Expected Outputs | UX docs + review + registry |
| §7 Checkpoint Strategy | Thresholds + trigger conditions + LPM flag (nếu active) |
| §8 Validation Plan | 10 checks Phase 4 (8 + 2 CQG) |
| §9 Notes | Ghi chú LPM, LEGACY_MODE, deferred findings |

**Parallel Strategy (§5):**
- Phase 3: Spawn 1 ux-designer per system (max `$LPM_PARAMS.max_parallel_agents` đồng thời)
- Trong cùng system: modules SEQUENTIAL (chia sẻ design context)

**Checkpoint Strategy (§7):**
- Standard: Checkpoint sau mỗi batch Phase 3
- LPM: Checkpoint sau mỗi system Phase 3
- Context >= 65% → chuẩn bị checkpoint
- Context >= 80% → FORCE checkpoint ngay

---

## POST-GATE

- [ ] `$SESSION_DIR/session-state.json` tồn tại và có `session_id`, `created_at` fields
- [ ] `$SESSION_DIR/design-ux-status.json` tồn tại và có `interface_type`, `large_project_mode`, `project_type` fields
- [ ] `design-ux-plan.md` tồn tại và đủ 9 sections
- [ ] `$SESSION_DIR/checkpoint.json` tồn tại (init state)
- [ ] `.mc-data/work/wf-design-ux/latest` tồn tại và chứa `$SESSION_ID`
- [ ] `$SESSION_DIR`, `$SESSION_ID` set (không rỗng)
- [ ] `$INTERFACE_TYPE` xác định (web / mobile / web+mobile / api-only)
- [ ] `$PHASE4_CONTRACT` cached (hoặc WARN log nếu contract file không tồn tại)
- [ ] Nếu `$LEGACY_MODE = true`: `$LEGACY_CONTEXT` và `$DEPRECATED_MODULES` loaded

**Next phase:** `phase0.5-workload-gate.md` (Phase 0.5.0 sẽ handle api-only skip)
