# Phase 0: Context Loading & Approach Selection

> Load registry + features, detect LEGACY_MODE, evaluate Large Project Mode,
> determine design approach, reconcile checkpoint (nếu `--resume`), tạo execution plan.
> Self-contained phase — tham chiếu `_shared.md` cho state variables, LEGACY injection, checkpoint protocol, token limit.

**PRE-GATE:**

```bash
test -f .mc-data/docs/_meta/req-registry.json
test -d .mc-data/docs/phase2-features
# Forensic validation (Protocol 10.4): phase2-features/**/*.md: >= 6 headings, >= 400 words
# Nếu FAIL → "Feature specs không đạt yêu cầu nội dung. Chạy `/wf-define-features` để hoàn thiện."
```

### CI-ROUTE: Architecture Review (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus + Serena de kham pha kien truc hien co thay vi doc tung file thu cong.
> **Graceful:** CI unavailable → fallback Read/Grep (current behavior, zero regression).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `api_routes` | **GitNexus** `route_map()` | Grep | Tu dong map toan bo API routes + consumers |
| `understand_flow` | **GitNexus** `query({core_domain})` | Grep + Read | Tim execution flows cho core domain concepts (auth, orders, etc.) |
| `project_structure` | **GitNexus** `clusters` / **Serena** `onboarding` | Glob | Hieu functional areas + cau truc du an |

> **Freshness caveat:** Neu index behind > 0 → "Results based on index N commits behind HEAD."

**GUARD:** Nếu registry có `requirements[]` rỗng VÀ `modules[]` không rỗng →
**STOP** với thông báo: "Registry có modules nhưng chưa có requirements. Chạy `/wf-analyze-requirements` trước khi `/wf-design`." (E001)

**INPUT:**
- `.mc-data/docs/_meta/req-registry.json`
- `.mc-data/docs/phase2-features/**/*.md`
- `.mc-data/docs/_meta/feature-briefs.json` (optional — digest từ upstream)
- `.mc-data/work/wf-define-features/deferred-findings.md` (optional)
- `.mc-data/work/legacy-scan/project-context.md` (nếu LEGACY)
- `.mc-data/work/wf-brainstorm/legacy-decisions.json` (nếu LEGACY)
- `.mc-data/work/legacy-scan/domain-hints.json` (v5.0 OPTIONAL — nếu LEGACY; inject vào architect agent context)
- `.mc-data/work/wf-design/checkpoint.json` (nếu `--resume`)

**OUTPUT:**
- `.mc-data/work/wf-design/design-status.json`
- `.mc-data/work/wf-design/design-plan.md`
- `.mc-data/work/wf-design/execution-plan.md` (Protocol 9 — PLN-08)
- `.mc-data/work/wf-design/feature-digest.md` (conditional)

---

## Sub-Phase 0.1: Prerequisite Check & LEGACY Detection

| Step | Action | Verify |
|------|--------|--------|
| 0.1.1 | Check `--status`, `--resume` flags | Args validated |
| 0.1.2 | **ONBOARD GUARD:** Kiểm tra `requirements[]` rỗng + `modules[]` không rỗng → STOP nếu true | Guard passed |
| 0.1.3 | `mkdir -p .mc-data/work/wf-design/` | `test -d .mc-data/work/wf-design` |
| 0.1.4 | Detect LEGACY_MODE (xem `_shared.md` §LEGACY_MODE Detection). Nếu true: load `$LEGACY_CONTEXT` + `$LEGACY_DECISIONS` + `$DEPRECATED_MODULES` | `$LEGACY_MODE` set |
| 0.1.4b | (v5.0 OPTIONAL) Nếu `$LEGACY_MODE = true` VÀ `.mc-data/work/legacy-scan/domain-hints.json` tồn tại → load `$DOMAIN_HINTS` (per-module domain suggestions với confidence score). Graceful skip khi vắng. | `$DOMAIN_HINTS` loaded hoặc empty |

---

## Sub-Phase 0.2: Digest Loading (PRE-GATE — Phiên 6)

> Đọc `feature-briefs.json` từ upstream để nhanh nắm spec; fallback đọc full docs.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.2.1 | Kiểm tra `.mc-data/docs/_meta/feature-briefs.json` tồn tại | Bash | File exists? |
| 0.2.2 | Nếu có → đọc feature-briefs.json để bootstrap context; nếu không → fallback read full `phase2-features/**/*.md` | Read | Context loaded |

---

## Sub-Phase 0.2b: Session Init (ADR-OPT-02)

> Tạo session directory riêng biệt cho lần chạy này. CORE-030 Session Isolation.

| Step | Action | Verify |
|------|--------|--------|
| 0.2b.1 | Tạo `$SESSION_ID = YYYYMMDD-HHMMSS-{hash4}` (timestamp + 4-char sha1 hash của timestamp). Tạo `$SESSION_DIR = .mc-data/work/wf-design/sessions/$SESSION_ID/` | `test -d $SESSION_DIR` |
| 0.2b.2 | `mkdir -p $SESSION_DIR/lanes/` | Directories tồn tại |
| 0.2b.3 | Tạo `$SESSION_DIR/session-state.json` với schema `design-session-state-v1`: `{ "session_id": "$SESSION_ID", "created_at": "[now]", "next_action": "phase0-context", "phases": { "P0": { "status": "in_progress" } } }` | `jq '.' $SESSION_DIR/session-state.json` pass |
| 0.2b.4 | Ghi `$SESSION_ID` vào `.mc-data/work/wf-design/latest` (latest pointer) | `test -f .mc-data/work/wf-design/latest` |
| 0.2b.5 | **Session Cleanup:** Đếm sessions trong `.mc-data/work/wf-design/sessions/`. Nếu > 5 → xoá session cũ nhất (oldest by name prefix). KHÔNG xoá session hiện tại. | Số sessions ≤ 5 |

---

## Sub-Phase 0.3: Registry & Features Loading

| Step | Action | Verify |
|------|--------|--------|
| 0.3.1 | ĐỌC `templates/design-status.json` → POPULATE `skill_id`, `project`, `scope`, `target`, `context` từ registry + args → GHI `$SESSION_DIR/design-status.json` + SYNC → `.mc-data/work/wf-design/design-status.json` | `test -s $SESSION_DIR/design-status.json && jq '.' $SESSION_DIR/design-status.json` |
| 0.3.2 | Đọc `req-registry.json` → `$REGISTRY_DATA` | Content loaded |
| 0.3.3 | Đọc `phase2-features/**/*.md` (nếu chưa làm ở 0.2) | Features loaded |
| 0.3.4 | Đọc `.mc-data/work/wf-define-features/deferred-findings.md` (nếu tồn tại) | Deferred findings loaded (hoặc empty) |
| 0.3.5 | Compute `$ACTIVE_SYSTEMS = $TARGET_SYSTEMS minus $DEPRECATED_MODULES` (set sau Phase 0.6) | — (populated sau Step 0.6.1) |

---

## Sub-Phase 0.4: Large Project Mode Detection (Protocol 6.6)

| Step | Action | Verify |
|------|--------|--------|
| 0.4.1 | Evaluate: `$LARGE_PROJECT = (systems >= 5) OR (departments >= 10) OR (requirements >= 50) OR (features >= 40)` | Flag set |
| 0.4.2 | Nếu `$LARGE_PROJECT = true`: log "Large Project Mode ACTIVE", set `$LPM_PARAMS` theo `_shared.md` §Large Project Mode | Params set |
| 0.4.3 | Nếu `$LARGE_PROJECT = false`: dùng Standard params (compression >3, digest 200 từ, skeleton >3000, max 5 parallel) | Params set |

---

## Sub-Phase 0.5: Feature Digest Generation (conditional)

> Nếu số feature files > `$LPM_PARAMS.compression_threshold`: tạo digest để tiết kiệm context.

| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Đếm số feature files trong `phase2-features/**/*.md` | Count obtained |
| 0.5.2 | Nếu > threshold: Grep key sections (endpoints, entities, constraints, `^##`, `REQ-`) → tạo `$SESSION_DIR/feature-digest.md` (~`digest_size` từ/file). Backward-compat: copy → `.mc-data/work/wf-design/feature-digest.md` | `test -s $SESSION_DIR/feature-digest.md` |
| 0.5.3 | Nếu > 5 files: dùng dept-digest format (Protocol 6.4) | Dept digest created |
| 0.5.4 | Set `$FEATURE_DIGEST_PATH = $SESSION_DIR/feature-digest.md` cho các phase sau. Agent prompts nhận digest thay vì full files — agent đọc file gốc CHỈ khi cần xác nhận chi tiết | Variable set |

---

## Sub-Phase 0.6: Approach Selection

> Xác định design approach dựa trên registry structure.

| Step | Action | Verify |
|------|--------|--------|
| 0.6.1 | Parse registry: extract `$TARGET_SYSTEMS`, `$TARGET_MODULES` (loại bỏ `$DEPRECATED_MODULES` nếu LEGACY_MODE) | Data extracted |
| 0.6.2 | Parse `$ARGUMENTS` (target argument: `platform` / `system` / `[module-name]`) | — |
| 0.6.3 | Set `$APPROACH` theo bảng dưới | Approach set |
| 0.6.4 | Detect conditional agents: `$HAS_AI_ML`, `$HAS_DATA_PIPELINE`, `$HAS_AUTOMATION` (theo domain từ registry) | Flags set |

**Approach selection:**

| Điều kiện | `$APPROACH` |
|-----------|-------------|
| 1 system, 1–2 modules | `Module` Design |
| 1 system, > 2 modules | `System` Design |
| > 1 system | `Platform` Design |

---

## Sub-Phase 0.7: Design Plan + Execution Plan

| Step | Action | Verify |
|------|--------|--------|
| 0.7.1 | ĐỌC `templates/design-plan.md` → POPULATE `Design ID`, `Scope`, `Target`, `Context`, `Target Systems/Modules`, `Session Breakdown` từ registry + approach → GHI `.mc-data/work/wf-design/design-plan.md` | `test -s design-plan.md` |
| 0.7.2 | **(Protocol 9 — PLN-08)** Tạo `.mc-data/work/wf-design/execution-plan.md`:<br>(a) Architecture approach decision (Module/System/Platform)<br>(b) Conditional agent selection (ai-engineer / data-engineer / automation-architect theo `$HAS_*` flags)<br>(c) Execution order: Phase 1 architect → Phase 2a+2b+2d PARALLEL → Phase 2c SEQUENTIAL → Phase 4a-4c<br>(d) Token estimate theo Protocol 9.3 | `test -s execution-plan.md` |

---

## Sub-Phase 0.7b: TodoWrite Init (Protocol 9 — PLN-08)

| Step | Action | Verify |
|------|--------|--------|
| 0.7b.1 | `TodoWrite` init với items cho 9 phases (Phase 0–8), mỗi item có `content` và `status: pending` | Todo list created |
| 0.7b.2 | Set Phase 0 thành `completed` sau khi Phase 0 POST-GATE PASS | Todo updated |

---

## Sub-Phase 0.8: Resume Reconciliation (chỉ khi `--resume`)

> Scan filesystem thật, reconcile với session-state để xác định phase/step tiếp theo.

| Step | Action | Verify |
|------|--------|--------|
| 0.8.1 | Đọc `$SESSION_ID` từ `.mc-data/work/wf-design/latest`. Tạo `$SESSION_DIR` từ `SESSION_ID`. | SESSION_DIR resolved |
| 0.8.2 | Đọc `$SESSION_DIR/session-state.json` nếu tồn tại → lấy `next_action`. Fallback: đọc `.mc-data/work/wf-design/checkpoint.json` (pre-v4.0 backward-compat). | next_action obtained |
| 0.8.3 | `actual_arch_files = $(find .mc-data/docs/phase3-architecture/ -name "*.md" ! -name "stakeholder-review.md" \| wc -l)` | Count obtained |
| 0.8.4 | So sánh với session-state. Nếu lệch → cập nhật session-state.json, log: "Reconciled: tìm thấy [N] file phase3 trên disk — tiếp tục từ phase [P]" | State reconciled |
| 0.8.5 | Dispatch tới phase trong `next_action` | Phase dispatched |

**--status handler (nếu `$ARGUMENTS` chứa `--status`):**

```
LATEST_SESSION = cat .mc-data/work/wf-design/latest 2>/dev/null
IF LATEST_SESSION tồn tại AND test -f sessions/{LATEST_SESSION}/session-state.json:
  → Đọc session-state.json → hiển thị phases[] + next_action
  → actual_arch_files = find .mc-data/docs/phase3-architecture/ -name "*.md" ! -name "stakeholder-review.md" | wc -l
  → Hiển thị trạng thái theo project_type (legacy hoặc new)
  → Nếu legacy: thêm hiển thị gap_analysis_done, gap_mode
  → Bao gồm dòng: "Files phase3 trên disk: [actual_arch_files]"
  → Nếu actual_arch_files lệch với state → "(state chưa đồng bộ — chạy --resume để reconcile)"
  → STOP
ELSE IF test -f .mc-data/work/wf-design/checkpoint.json (pre-v4.0 fallback):
  → Đọc checkpoint.json, hiển thị trạng thái
  → STOP
ELSE:
  → "Chưa có design session nào."
  → STOP
```

---

## POST-GATE

```bash
test -s $SESSION_DIR/design-status.json
test -s .mc-data/work/wf-design/design-plan.md
test -s .mc-data/work/wf-design/execution-plan.md
jq '.' $SESSION_DIR/design-status.json              # valid JSON
jq -e '.phases.P0.status == "completed"' $SESSION_DIR/session-state.json
test -n "$REGISTRY_DATA"                            # state var set
test -n "$APPROACH"                                 # approach determined
test -n "$SESSION_DIR"                              # session isolation init
test -n "$ACTIVE_SYSTEMS"                           # active systems resolved
```

**Checkpoint (LPM only):** Nếu `$LARGE_PROJECT = true` → SAVE session-state.json + checkpoint.json sau Phase 0.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E000 | `req-registry.json` không tìm thấy | STOP → chạy `/wf-analyze-requirements` |
| E001 | Registry có modules nhưng chưa có requirements | STOP → chạy `/wf-analyze-requirements` |
| E002 | Phase2-features forensic fail (< 6 headings hoặc < 400 words) | STOP → chạy `/wf-define-features` |
| E006 | User cancel giữa workflow | Lưu checkpoint, hướng dẫn dùng `--resume` |

---

## Next Phase

→ Read `procedures/phase0.5-workload-gate.md` — Workload Gate (ADR-OPT-03)
