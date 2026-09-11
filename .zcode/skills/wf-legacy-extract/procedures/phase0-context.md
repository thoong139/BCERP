# Phase 0: Context Loading & Routing

> Load context, kiểm tra prerequisites, determine maturity mode, init working files.
> Entry point của flow — đọc file này NGAY KHI SKILL.md route vào procedures/.

**PRE-GATE (dual-mode — v5.0 Phase D):**

Chấp nhận 2 nguồn state (theo thứ tự ưu tiên):

1. **v5.0 scan-state.json** — active session có `layers.L4.status == "completed"` hoặc `"skipped_by_profile"`.
2. **v4.1 ledger.json** (fallback): `jq -r '.stages.classify.status' ledger.json == "completed"` (hoặc `skipped_maturity`).

Nếu cả 2 đều fail → STOP (E001): "Chưa có classified data. Chạy `/wf-legacy-classify` trước."

> Helper `init_or_load_session()` tự động xử lý fallback.
> Xem `_shared.md §Scan-State Integration (v5.0 Phase D)`.

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/project-profile.json`
- `.mc-data/work/legacy-scan/inventory/dependency-graph.json`
- `.mc-data/work/legacy-scan/classified/glossary.json`
- `.mc-data/work/legacy-scan/classified/classify-naming-fixes.json` (optional)
- `.mc-data/work/legacy-scan/inventory/ui-manifest.json` (optional — LEGACY_MODE)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (khi `--resume`)

**OUTPUT:**
- `.mc-data/work/legacy-scan/extract-status.json` (init)
- `.mc-data/work/legacy-scan/extract-plan.md` (init skeleton)
- `.mc-data/work/legacy-scan/extract-checkpoint.json` (init — MEDIUM/LARGE only)
- In-memory state: `$MATURITY_MODE`, `$MATURITY_LEVEL`, `$STRATEGY_ID`, `$MODULE_FILTER`, `$RESUME_MODE`, `$PROJECT_SIZE`, `$UI_MANIFEST`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §LEGACY_MODE Detection
- `_shared.md` §Scan-State Integration (v5.0 Phase D)
- `_shared.md` §Template Usage Rule
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse `$ARGUMENTS` — check `--status`, `--resume`, `--module=<name>` flags | — | Args validated |
| 0.2 | `mkdir -p .mc-data/work/legacy-scan/extracted/` | Bash | Directory exists |
| 0.3 | **PRE-GATE:** Đọc `ledger.json` → verify `stages.classify.status == "completed"`. Nếu fail → STOP E001 | Read | Classify completed |
| 0.4 | Đọc `ledger.json` — extract `$MATURITY_MODE` (`.maturity.stage_modes.extract`), `$MATURITY_LEVEL` (`.maturity.level`), `$STRATEGY_ID` (`.strategy.id`) | Read | All fields loaded |
| 0.5 | Đọc `project-profile.json` — extract `$PROJECT_SIZE`, tech stack | Read | Profile loaded |
| 0.6 | Đọc `inventory/dependency-graph.json` — cache cho Phase 1 | Read | Graph loaded |
| 0.7 | Đọc `classified/glossary.json` — business terminology | Read | Glossary loaded |
| 0.8 | **Optional:** Đọc `inventory/ui-manifest.json` CHỈ KHI file tồn tại VÀ `total_screens > 0` → cache `$UI_MANIFEST` | Read | `$UI_MANIFEST` set or null |
| 0.9 | Nếu `--module=<name>` chỉ định: set `$MODULE_FILTER = <name>` (validation tại Phase 1) | — | Filter stored |
| 0.10 | **`--status` handler** — xem §Status Handler. Nếu chạy, STOP sau hiển thị | Read | N/A hoặc STOP |
| 0.11 | **`--resume` handler** — xem §Resume Logic. Load checkpoint, reconcile filesystem | Read | Resume point determined |
| 0.12 | **[READ-TEMPLATE]** Status init: READ `templates/extract-status.json` → POPULATE (extract_id=EXTRACT-$(date +%Y%m%d)-NNN, project, arguments, timestamps, maturity_mode=$MATURITY_MODE, strategy_id=$STRATEGY_ID) → WRITE `.mc-data/work/legacy-scan/extract-status.json`. Nếu file đã tồn tại và `--resume`: UPDATE thay vì overwrite | Read/Write | `test -s extract-status.json` |
| 0.13 | **[READ-TEMPLATE]** Plan init: READ `templates/extract-plan.md` → POPULATE (EXTRACT ID, project name, maturity mode, placeholder cho Phase 1 sẽ update module breakdown) → WRITE `.mc-data/work/legacy-scan/extract-plan.md` | Read/Write | `test -s extract-plan.md` |
| 0.14 | **[READ-TEMPLATE]** Checkpoint init (chỉ MEDIUM/LARGE): Nếu `$PROJECT_SIZE >= MEDIUM`: READ `templates/extract-checkpoint.json` → POPULATE (extract_id, session_number=1, trigger.reason="fresh_start", context_summary) → WRITE `.mc-data/work/legacy-scan/extract-checkpoint.json` | Read/Write | Checkpoint saved or skipped |
| 0.15 | Log session-log entry (CORE-026): START event → `.mc-data/work/_trace/session-log.json` | Write | Entry appended |
| 0.16 | **[PHASE D — Scan-state init]** Gọi `init_or_load_session(project_path)` từ helper scan_state_reader; lưu `$SESSION_ID`. Nếu helper raise `RuntimeError("No prior scan")` → STOP E001. Sau đó gọi `update_layer_status("L5", "in_progress")`. **Note:** idempotent fail (L5 đã completed) → WARN và tiếp tục. Xem `_shared.md §Scan-State Integration` | Bash (Python helper) | `$SESSION_ID` set, L5 marked in_progress |
| 0.17 | **[PHASE D — Depth map]** `$DEPTH_L5 = read_depth_map().get("L5", "standard")`. Nếu `$DEPTH_L5 == "skip"` → mark `update_layer_status("L5", "skipped_by_profile")` + JUMP Phase 5 (skip extraction). Otherwise cache cho Phase 2 prompts | Bash (Python helper) | `$DEPTH_L5` set |

---

## Status Handler (Step 0.10)

Khi `$ARGUMENTS` chứa `--status`:

```
IF test -f .mc-data/work/legacy-scan/extract-status.json:
  extract_status = đọc extract-status.json
  actual_files = find .mc-data/work/legacy-scan/extracted/ -name "*.json" \
                 ! -name "dedup-report.json" ! -name "*-divergences.json" | wc -l
  Hiển thị theo format:
```

```markdown
## Extract Status

| Mục | Giá trị |
|-----|---------|
| Stage | 3 — Extract |
| Status | [in_progress/completed] |
| Modules | [done]/[total] ([percentage]%) |
| Extracted files trên disk | [actual] / [total] |
| Modules error | [count] |
| Requirements extracted | [count] |
| Features extracted | [count] |
| Avg confidence | [score] |
| Current module | [name] (nếu in_progress) |
```

```
  STOP (không thực thi extraction)
ELSE:
  "Chưa có extract session nào."
  STOP
```

---

## Resume Logic (Step 0.11 — chỉ khi `--resume`)

```
IF $RESUME_MODE = true:
  IF test -f .mc-data/work/legacy-scan/extract-checkpoint.json:
    checkpoint = đọc extract-checkpoint.json
    
    # Filesystem reconciliation
    actual_extracted = find extracted/ -name "*.json" \
                      ! -name "dedup-report.json" ! -name "*-divergences.json" | wc -l
    
    So sánh actual_extracted với checkpoint.progress.modules_completed:
    - Nếu lệch → cập nhật checkpoint, log:
      "Reconciled: tìm thấy [N] file extracted trên disk — tiếp tục từ module [next_module]"
    
    # Freshness check
    classify_mtime = mtime của ledger.json khi classify completed
    IF classify_mtime > checkpoint.created_at:
      WARN: "Classify đã thay đổi sau checkpoint. Tiếp tục có thể gây kết quả không đồng bộ."
      AskUserQuestion: "Tiếp tục? (Y/N)"
    
    Jump target = checkpoint.position.current_phase (Phase 1, 2, 3, 4, 5)
  ELSE:
    STOP: "Không tìm thấy checkpoint. Chạy /wf-legacy-extract từ đầu (không có --resume)."
```

---

## Maturity Mode Handling (Step 0.4)

| Mode | Hành động |
|------|-----------|
| `skip` | Phase 5 sẽ mark `stages.extract.status = "completed"` ngay, ghi note `skipped_maturity`, skip toàn bộ Phase 1-4 |
| `delta` | Phase 2 sẽ load `extracted/*.json` cũ, so sánh file mtimes với `extracted_at` → chỉ re-extract modules có files thay đổi |
| `full` | Phase 1-4 chạy bình thường |

**`$MATURITY_LEVEL` propagation:**
- Nếu `DOCS_ONLY` → Phase 2 truyền cho agent → agent chạy Bước 0B (extract từ docs only)
- Nếu `CODE_PLUS_EXTERNAL_DOCS` hoặc `CODE_PLUS_DEVKIT_PARTIAL` → Phase 3 chạy divergence detection (strategy S5 equivalent)

---

## POST-GATE

- [ ] `extract-status.json` tồn tại, non-empty, valid JSON (Step 0.12)
- [ ] `extract-plan.md` tồn tại, non-empty (Step 0.13)
- [ ] `extract-checkpoint.json` tồn tại (hoặc SKIP nếu SMALL project)
- [ ] `$MATURITY_MODE` set (`full` / `delta` / `skip`)
- [ ] `$STRATEGY_ID` set
- [ ] `$PROJECT_SIZE` set
- [ ] Ledger đã đọc thành công (cache cho downstream)
- [ ] Session-log START entry appended

**Next phase:**
- Nếu `$MATURITY_MODE == "skip"` → JUMP thẳng Phase 5 (skip extraction)
- Ngược lại → `phase1-resolution.md`
