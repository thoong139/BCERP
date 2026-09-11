# Phase 0: Context Loading & Resume Check

> Khởi tạo working files, parse arguments, detect LEGACY_MODE, load digests.
> Đầu tiên trong wf-plan-modules execution flow.
> **Khi `--resume`:** SKIP init steps (0.6-0.7) → jump tới Resume Reconciliation.

> **Shared context:** xem `_shared.md` — State Variables Glossary, LEGACY_MODE Detection.

---

## PRE-GATE

```bash
# CORE-011 forensic: kiểm tra content, không chỉ file existence
jq -e '.modules | length > 0' .mc-data/docs/_meta/req-registry.json 2>/dev/null
```
Nếu fail → STOP: "req-registry.json không tồn tại hoặc chưa có modules. Chạy `/wf-brainstorm` hoặc `/wf-analyze-requirements` trước."

---

## 📥 INPUT

| File | Đường dẫn | Điều kiện |
|------|-----------|-----------|
| Deferred findings từ /wf-design | `.mc-data/work/wf-design/deferred-findings.md` | Optional — nếu tồn tại, check blocking items |
| UX stakeholder review | `.mc-data/docs/phase4-ux/stakeholder-review.md` | Optional — nếu interface_type != api-only |
| Status file | `.mc-data/work/wf-plan-modules/planmod-status.json` | Chỉ khi `--resume` |
| Checkpoint | `.mc-data/work/wf-plan-modules/checkpoint.json` | Chỉ khi `--resume` |
| Project context | `.mc-data/work/legacy-scan/project-context.md` | Chỉ LEGACY_MODE |
| Gap report | `.mc-data/work/legacy-scan/gap-report.md` | Chỉ LEGACY_MODE |
| Action items | `.mc-data/work/legacy-scan/action-items.json` | Chỉ LEGACY_MODE — consumed Phase 5 (MVP priority) + Phase 6 (impact) |
| Annotation report | `.mc-data/work/legacy-scan/annotation-report.md` | Chỉ LEGACY_MODE — consumed Phase 1.5 (coverage context) |
| Legacy decisions | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | Chỉ LEGACY_MODE |

## 📤 OUTPUT

| File | Template |
|------|---------|
| `.mc-data/work/wf-plan-modules/planmod-status.json` | `templates/planmod-status.json` |
| `.mc-data/work/wf-plan-modules/planmod-plan.md` | `templates/planmod-plan.md` |
| `.mc-data/work/wf-plan-modules/checkpoint.json` | `templates/checkpoint.json` |
| `.mc-data/work/_trace/session-log.json` (append) | `doc-framework/_meta/session-log.template.json` |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | `mkdir -p .mc-data/work/wf-plan-modules/sessions/` | Directory exists |
| 0.2 | Kiểm tra `--status` → đọc status file, hiển thị (xem §Status Display), STOP | — |
| 0.2c | **[RESUME PATH — CHỈ KHI `--resume`]** Đọc `latest` pointer TRƯỚC KHI tạo session mới: `EXISTING=$(cat .mc-data/work/wf-plan-modules/latest 2>/dev/null)`. IF `$EXISTING` tồn tại và `$EXISTING/session-state.json` có nội dung → set `$SESSION_DIR = $EXISTING`, `$SESSION_ID` từ file. SKIP step 0.2b (không tạo session mới). Nhảy sang 0.3b (Resume Reconciliation). ELSE (latest không tìm thấy) → Fallback: đọc root `checkpoint.json` + `planmod-status.json`. Nếu vẫn không có → STOP + emit FAIL log (CORE-026): `"Không tìm thấy session để resume. Chạy /wf-plan-modules từ đầu."` | `$SESSION_DIR` set + session-state.json đọc được |
| 0.2b | **[FRESH START PATH — CHỈ KHI KHÔNG `--resume`] Session Creation (ADR-OPT-02):** Tạo session ID: `SESSION_ID=$(date +%Y%m%d-%H%M%S)-$(head -c4 /dev/urandom \| xxd -p)`. Tạo `$SESSION_DIR = .mc-data/work/wf-plan-modules/sessions/$SESSION_ID/`. `mkdir -p $SESSION_DIR/lanes/`. READ `_shared/templates/session-state.json` → POPULATE (`session_id`, `skill="wf-plan-modules"`, `created_at`) → WRITE `$SESSION_DIR/session-state.json`. Ghi `$SESSION_DIR` vào `.mc-data/work/wf-plan-modules/latest`. Cleanup: nếu sessions/ có > 5 entries → xóa session cũ nhất. | `test -f $SESSION_DIR/session-state.json` |
| 0.3 | (Dành cho fresh start) Parse arguments: `--mvp` → `$HAS_MVP_FLAG=true`; `--skip-sprints` → `$HAS_SKIP_SPRINTS_FLAG=true`; `--impact=<module>` → `$IMPACT_MODULE=<module>` | Flags parsed |
| 0.3b | **(CHỈ KHI `--resume`) RESUME RECONCILIATION:** Sau khi load session từ Step 0.2c, scan `phase5-implementation/tasks/` để reconcile actual files với expected features (xem §Resume Logic) | Checkpoint reconciled |
| 0.4 | Đọc `.mc-data/work/wf-design/deferred-findings.md` (nếu tồn tại) → check có BLOCKING items không | Blocking items logged |
| 0.5 | Đọc `.mc-data/docs/phase4-ux/stakeholder-review.md` (nếu tồn tại) → load UX context | UX context loaded |
| 0.5a | **LEGACY_MODE Detection (CORE-021)** — xem §LEGACY Context Loading | `$LEGACY_MODE` set + context loaded |
| 0.5b | **Feature files validation:** `.mc-data/docs/phase2-features/` tồn tại + có ít nhất 1 `.md` | Feature files exist |
| 0.6 | **Template Usage Rule — Khởi tạo working files:** (1) READ `templates/planmod-status.json` → populate placeholders (planmod_id, project, mode, timestamps, arguments) → WRITE `.mc-data/work/wf-plan-modules/planmod-status.json` (2) READ `templates/planmod-plan.md` → populate placeholders → WRITE `.mc-data/work/wf-plan-modules/planmod-plan.md` | `test -s planmod-status.json && test -s planmod-plan.md` |
| 0.7 | **Template Usage Rule — Khởi tạo checkpoint:** READ `templates/checkpoint.json` → populate (checkpoint_id, planmod_id, timestamp, session_number=1, trigger.reason="fresh_start", position.current_phase="phase_0.5") → WRITE `.mc-data/work/wf-plan-modules/checkpoint.json` | `test -s checkpoint.json` |
| 0.8 | **Session Log (CORE-026):** Nếu `.mc-data/work/_trace/session-log.json` chưa tồn tại → READ template `.claude/doc-framework/_meta/session-log.template.json` → tạo file. Append entry: `{event: "START", skill: "wf-plan-modules", timestamp, arguments}` | Entry appended |

---

## §LEGACY Context Loading (Step 0.5a chi tiết)

```bash
LEGACY_MODE=$(test -f .mc-data/work/legacy-scan/project-context.md \
  && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 \
  && echo "true" || echo "false")
```

**Khi `$LEGACY_MODE = true`:**

1. Đọc `project-context.md` → load vào `$LEGACY_CONTEXT`
2. Đọc `gap-report.md` (nếu có) → load vào `$LEGACY_GAP_CONTEXT`
3. Đọc `action-items.json` (nếu có) → parse JSON → `$LEGACY_ACTION_ITEMS`. Lọc theo `severity ∈ {CRITICAL, HIGH}` → `$PRIORITY_ACTION_ITEMS` để dùng ở Phase 5 (MVP prioritization) và Phase 6 (impact analysis). Log: "Loaded [N] action items (Y CRITICAL, Z HIGH) từ wf-design gap analysis"
4. Đọc `legacy-decisions.json` (nếu tồn tại) → load vào `$LEGACY_DECISIONS`:
   - Extract modules có `action = "DEPRECATE"` → `$DEPRECATED_MODULES[]`
5. Đọc `annotation-report.md` (nếu tồn tại) → load vào `$ANNOTATION_COVERAGE` làm coverage context cho Phase 1.5 (CORE-007 §4b declared)
6. Trong Phase 7.5: KHÔNG tạo task file cho features thuộc `$DEPRECATED_MODULES`
7. Nếu registry còn features của DEPRECATED modules với `impl_status != "skipped"` → set `impl_status = "skipped"` (Phase 7)

> **Downstream usage của `$PRIORITY_ACTION_ITEMS`:**
> - **Phase 5 (MVP prioritization):** Items `severity=CRITICAL` → priority=`P0`; `severity=HIGH` → priority=`P1`. Items có `type=gap` hoặc `type=missing_req` được merge vào MVP scope đầu tiên.
> - **Phase 6 (impact analysis):** Mỗi action item reference `module_id`/`feature_id` — dùng để tính blast radius và dependency impact.
> - Graceful degradation: Nếu `action-items.json` không tồn tại → `$PRIORITY_ACTION_ITEMS = []`, skip prioritization enrichment nhưng không fail.

**Graceful degradation (CORE-022):**
- Nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, tiếp tục bình thường

**Khi `$LEGACY_MODE = false`:** SKIP toàn bộ legacy context loading.

---

## §Resume Logic (Steps 0.2 + 0.3 + 0.3b chi tiết)

### --status handler

```
IF --status:
  Read planmod-status.json → display
  actual_task_files = $(find .mc-data/docs/phase5-implementation/tasks/ -name "*-impl.md" 2>/dev/null | wc -l)
  Hiển thị thêm dòng: "Task files trên disk: [actual_task_files] / [total_features]"
  Nếu checkpoint.json tồn tại VÀ actual_task_files != checkpoint.tasks_completed:
    Hiển thị cảnh báo: "(checkpoint chưa đồng bộ — chạy --resume để cập nhật)"
  → STOP
```

### --resume handler

```
IF --resume:
  # Đọc session state từ latest pointer (ADR-OPT-02)
  LATEST=$(cat .mc-data/work/wf-plan-modules/latest 2>/dev/null)
  IF [ -z "$LATEST" ] OR [ ! -f "$LATEST/session-state.json" ]:
    → Fallback: đọc checkpoint.json + planmod-status.json ở root-level (backward-compat)
  ELSE:
    Read $LATEST/session-state.json → set $SESSION_DIR = $LATEST, $SESSION_ID
    Read planmod-status.json + checkpoint.json
  → Xác định phase đang dở từ session-state.json.position.current_phase
    (fallback: checkpoint.position.current_phase nếu session-state không có)
  → Thông báo: "Resuming from Phase [N], Step [X]"

  → RESUME RECONCILIATION (Step 0.3b):
       actual_files = find .mc-data/docs/phase5-implementation/tasks/ -name "*-impl.md" 2>/dev/null | sort
       expected = từ registry + planmod-plan.md, build danh sách expected task paths (mỗi feature → 1 path)
       tasks_done      = [feat ∈ expected WHERE file exists AND size > 0]
       tasks_remaining = [feat ∈ expected WHERE file NOT exists HOẶC size == 0]
       checkpoint.tasks_completed = len(tasks_done)
       checkpoint.next_feature    = first item in tasks_remaining (format: "[sys]/[mod]/[feat]")
       Log: "Reconciled: [N] task files trên disk — tiếp tục từ [sys/mod/feat]"
  → Nhảy đến phase tương ứng, KHÔNG chạy lại phases đã xong

ELSE: Fresh start → khởi tạo status + plan files (steps 0.6, 0.7, 0.8)
```

---

## Phase 0.5: PRE-GATE Digest Loading (Phiên 6 — Digest Pipeline)

> Đọc `design-input-digest.json` + `ux-input-digest.json` (nếu có UI) từ upstream.
> Fallback: đọc full Phase 3/4 docs nếu digests không tồn tại.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.1 | Kiểm tra `design-input-digest.json` tồn tại ở `.mc-data/docs/_meta/` | Bash | Nếu tồn tại → đọc; nếu không → fallback read full phase3 docs |
| 0.5.2 | Nếu `interface_type != "api-only"` → kiểm tra `ux-input-digest.json` | Bash | Nếu tồn tại → đọc; nếu không → fallback read full phase4 docs |
| 0.5.3 | Inject context vào `$ARCH_DIGEST`, `$UX_DIGEST` | Read | Context sẵn sàng |

> **Fallback rule:** Nếu digest không khả dụng → đọc trực tiếp Phase 3 docs từ `.mc-data/docs/phase3-architecture/` (và Phase 4 UX docs nếu có) thay vì fail PRE-GATE.

---

## POST-GATE

```bash
test -f .mc-data/work/wf-plan-modules/planmod-status.json \
  && test -f .mc-data/work/wf-plan-modules/checkpoint.json \
  && jq -e '.planmod_id' .mc-data/work/wf-plan-modules/planmod-status.json
```

Sau Phase 0 hoàn tất (fresh start), set checkpoint position → `phase_0.5`, return về SKILL.md để route sang Phase 0.5.
Sau Phase 0 hoàn tất (resume path từ Step 0.2c), checkpoint position đã được load từ existing session — nhảy thẳng tới phase trong checkpoint không qua Phase 0.5.

---

## Next

→ Checkpoint: position → `phase_0.5`
→ Read `procedures/phase0.5-workload-gate.md` (Phase 0.5 Workload Gate)
