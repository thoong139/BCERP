# Phase 0: Context Loading & Mode Detection

> Entry point — đọc NGAY KHI SKILL.md route vào `procedures/`.
> Load context, detect LEGACY_MODE + maturity, parse args, init status/plan/checkpoint.
> Handle `--status` và `--resume` special paths.

**PRE-GATE:**

```bash
# 1. Gap analysis hoàn thành trong ledger
[ "$(jq -r '.stages.gap_analysis.status' .mc-data/work/legacy-scan/ledger.json 2>/dev/null)" == "completed" ]

# 2. Registry tồn tại, valid JSON, có features (Forensic — CORE-011)
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json > /dev/null 2>&1

# 3. Module-code mapping tồn tại, non-empty
test -s .mc-data/work/legacy-scan/module-code-mapping.json
jq '.' .mc-data/work/legacy-scan/module-code-mapping.json > /dev/null 2>&1

# 4. Gap report tồn tại, non-empty
test -s .mc-data/work/legacy-scan/gap-report.md

# 5. Status file tồn tại
test -f .mc-data/work/legacy-scan/legacy-scan-status.json
```

Nếu bất kỳ check fail → **STOP (E001)**:
> "Chưa đủ prerequisites. Cần: `gap_analysis` completed trong ledger, `req-registry.json` (có features[]), `module-code-mapping.json`, `gap-report.md`. Chạy `/wf-design` (legacy flow — gap analysis) trước."

**INPUT:**
- `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/legacy-scan-status.json`
- `.mc-data/docs/_meta/req-registry.json`
- `.mc-data/work/legacy-scan/module-code-mapping.json`
- `.mc-data/work/legacy-scan/gap-report.md`
- `.mc-data/work/legacy-scan/project-profile.json` (cho tech stack)
- `.mc-data/work/wf-brainstorm/legacy-decisions.json` (optional — LEGACY)
- `.mc-data/work/legacy-scan/annotate-checkpoint.json` (nếu `--resume`)

**OUTPUT:**
- `.mc-data/work/legacy-scan/annotate-status.json` (init)
- `.mc-data/work/legacy-scan/annotate-plan.md` (init)
- `.mc-data/work/legacy-scan/annotate-checkpoint.json` (init)
- In-memory state: `$LEGACY_MODE`, `$MATURITY_LEVEL`, `$MODULE_FILTER`, `$DRY_RUN`, `$BATCH_SIZE`, `$RESUME`, `$DEPRECATED_MODULES`, `$TECH_STACK`, `$TRACEABILITY_BEFORE`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §LEGACY_MODE Detection
- `_shared.md` §LEGACY Decisions Filter
- `_shared.md` §Resume Logic
- `_shared.md` §Traceability Score (baseline calculation)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse `$ARGUMENTS` — extract `--module=<name>`, `--dry-run`, `--batch-size=N`, `--resume`, `--status` flags. Set `$MODULE_FILTER`, `$DRY_RUN`, `$BATCH_SIZE` (default 50), `$RESUME` | — | Args validated |
| 0.2 | Nếu `$ARGUMENTS` chứa `--status` → nhảy §`--status` Handler, STOP | — | Handler dispatched |
| 0.3 | Đọc `ledger.json` → lấy `stages.gap_analysis.status`, `maturity.level` → set `$MATURITY_LEVEL` | Read | Ledger loaded |
| 0.4 | Đọc `req-registry.json` → load `features[]`, `requirements[]`, `systems[]`, `modules[]` | Read | Registry loaded |
| 0.5 | Đọc `module-code-mapping.json` → cache module-to-code directory map | Read | Mappings loaded |
| 0.6 | Đọc `gap-report.md` → extract annotation gaps section (grep marker `## Annotation Gaps` hoặc tương đương) | Read | Gaps identified |
| 0.7 | Đọc `project-profile.json` → load `$TECH_STACK` (primary_language, frameworks, file_extensions) | Read | Tech stack known |
| 0.8 | Detect `$LEGACY_MODE` theo `_shared.md §LEGACY_MODE Detection` | Bash | `$LEGACY_MODE` set |
| 0.9 | Nếu `$LEGACY_MODE = true`: áp dụng `_shared.md §LEGACY Decisions Filter` → set `$DEPRECATED_MODULES`. Nếu `false`: `$DEPRECATED_MODULES = []` | Read/jq | DEPRECATE set loaded |
| 0.10 | Nếu `$MODULE_FILTER` set: validate module tồn tại trong `module-code-mapping.json`. Nếu không tồn tại → STOP: "Module '$MODULE_FILTER' không có trong mapping." | jq | Filter validated |
| 0.11 | Tính `$TRACEABILITY_BEFORE` theo `_shared.md §Traceability Score` (baseline) | Bash/Grep | Baseline tính xong |
| 0.12 | Nếu `$RESUME = true`: áp dụng `_shared.md §Resume Logic` → load checkpoint, reconcile filesystem, xác định entry phase | Read | Resume branch xong |
| 0.13 | **[READ-TEMPLATE]** READ `templates/annotate-status.json` → POPULATE (annotate_id, project, status="in_progress", timestamps, arguments, phases initial, context_sources, maturity_level, legacy_mode) → WRITE `.mc-data/work/legacy-scan/annotate-status.json` | Read → Write | File valid JSON |
| 0.14 | **[READ-TEMPLATE]** READ `templates/annotate-plan.md` → POPULATE scope overview, module breakdown, session breakdown, context sources, batch planning, LEGACY notes (deprecated modules) → WRITE `.mc-data/work/legacy-scan/annotate-plan.md` | Read → Write | Plan file created |
| 0.15 | **[BUG-01 fix — RESUME guard]** `IF $RESUME = false`: READ `templates/annotate-checkpoint.json` → POPULATE init state (trigger.reason="phase0_init", position.current_phase="phase_0", partial_state.features_count = registry.features.length) → WRITE `.mc-data/work/legacy-scan/annotate-checkpoint.json`. `IF $RESUME = true`: chỉ update `timestamps.last_updated` và `context_summary.session_number++` trong checkpoint đã có — KHÔNG ghi đè toàn bộ. | Read → Edit/Write | Checkpoint init (hoặc preserved cho resume) |
| 0.16 | **[CORE-026]** Nếu `.mc-data/work/_trace/session-log.json` chưa tồn tại → READ template `.claude/doc-framework/_meta/session-log.template.json` → tạo file. Append START event: `{ skill: "wf-annotate-code", event: "START", arguments, timestamp }` | Read → Write | Trace logged |

---

## --status Handler (Step 0.2)

```
IF $ARGUMENTS chứa "--status":
  (1) Đọc ledger.json → annotate stage status + legacy-scan-status.json → pipeline_status
  (2) Đọc annotate-status.json (nếu tồn tại) → hiển thị chi tiết:
      - status, progress_pct
      - phases.phase_0..phase_4 status
      - annotation_stats (files_annotated, REQ-IDs injected)
      - modules_processed_count vs total
  (3) Check output files tồn tại:
      - annotation-report.md
      - annotation-map.json
      - annotate-status.json
      - annotate-plan.md
      Hiển thị ✅/❌ cho mỗi file
  (4) Nếu có annotate-checkpoint.json:
      Hiển thị last checkpoint: batch, files_done/total, timestamp
  (5) STOP — KHÔNG chạy annotate
```

---

## Mode Check (Maturity-Aware)

Sau khi load `$MATURITY_LEVEL` (Step 0.3), áp dụng:

| Maturity Level | Hành động |
|----------------|-----------|
| `NEAR_COMPLETE` | Kiểm tra `gap-categories.json` (BUG-08 fix — xem bên dưới). Nếu tồn tại → chỉ annotate `diverged` items từ đó (ghi vào `$ANNOTATION_MODE = "diverged_only"`). |
| `DOCS_ONLY` | **SKIP toàn bộ** — không có code để annotate. Update `annotate-status.json.status = "skipped"`, `reason = "docs_only"`. STOP với message: "Dự án chỉ có docs, không có code để annotate." |
| Standard (`CODE_ONLY`, `CODE_PLUS_*`) | Annotate tất cả files có mapping (`$ANNOTATION_MODE = "full"`) |

**BUG-08 fix — NEAR_COMPLETE gap-categories.json check:**

```
IF $MATURITY_LEVEL = "NEAR_COMPLETE":
  IF NOT test -s .mc-data/work/legacy-scan/gap-categories.json:
    STOP (E001): "gap-categories.json không tìm thấy hoặc rỗng.
                  File này bắt buộc để chạy NEAR_COMPLETE/diverged_only mode.
                  Kiểm tra wf-legacy-classify đã tạo gap-categories.json chưa.
                  Hoặc chạy lại wf-design (legacy flow) với --mode=near-complete."
  ELSE:
    $ANNOTATION_MODE = "diverged_only"
```

Lưu `$ANNOTATION_MODE` vào `annotate-status.json` để Phase 1 biết scope.

---

## POST-GATE

- [ ] `annotate-status.json` tồn tại, valid JSON, có fields: `status`, `arguments`, `phases`, `maturity_level`, `legacy_mode`
- [ ] `annotate-plan.md` tồn tại, non-empty
- [ ] `annotate-checkpoint.json` tồn tại (init state)
- [ ] `$LEGACY_MODE`, `$MATURITY_LEVEL`, `$MODULE_FILTER`, `$DRY_RUN`, `$BATCH_SIZE`, `$DEPRECATED_MODULES`, `$TECH_STACK`, `$TRACEABILITY_BEFORE` đã set
- [ ] Nếu `$MATURITY_LEVEL = "DOCS_ONLY"` → skill đã STOP với status=skipped

**Next phase:**
- Nếu `$RESUME = true` → jump tới phase trong `annotate-checkpoint.json.position.current_phase`
- Ngược lại → `phase1-build-map.md`
