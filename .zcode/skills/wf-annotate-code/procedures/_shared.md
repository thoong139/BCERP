# Shared Protocols — wf-annotate-code

> Cross-cutting references cho mọi Phase của `wf-annotate-code`: state variables,
> comment format tables, LEGACY decisions filter, checkpoint + resume logic, fix rules.
> **KHÔNG đọc file này standalone** — chỉ load section cụ thể khi phase cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Comment Format Table](#comment-format-table)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [LEGACY Decisions Filter](#legacy-decisions-filter)
- [Annotation Existence Check](#annotation-existence-check)
- [Checkpoint Protocol](#checkpoint-protocol)
- [Resume Logic](#resume-logic)
- [Fix Rules đặc thù](#fix-rules-đặc-thù)
- [Traceability Score](#traceability-score)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 | 0, 1, 3 | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$MATURITY_LEVEL` | Phase 0 | 0, 1 | `NEAR_COMPLETE` / `DOCS_ONLY` / `CODE_ONLY` / `CODE_PLUS_*` (từ `ledger.maturity.level`) |
| `$MODULE_FILTER` | Phase 0 | 1 | Module name nếu có `--module=<name>`, mặc định `null` (tất cả modules) |
| `$DRY_RUN` | Phase 0 | 2, 3, 4 | Boolean — true nếu có `--dry-run` flag |
| `$BATCH_SIZE` | Phase 0 | 3 | Int — default 50, có thể override bằng `--batch-size=N` |
| `$RESUME` | Phase 0 | 0, 3 | Boolean — true nếu có `--resume` flag |
| `$DEPRECATED_MODULES` | Phase 0 | 1 | Array module IDs có `action="DEPRECATE"` từ `legacy-decisions.json` — KHÔNG annotate files thuộc modules này |
| `$TECH_STACK` | Phase 0 | 1, 3 | Object từ `project-profile.json` — dùng phát hiện comment format |
| `$ANNOTATION_MAP` | Phase 1 | 2, 3 | Array `{ file_path, req_ids[], feat_id, confidence, module }` — primary payload giữa phases |
| `$USER_CONFIRMED_MAP` | Phase 2 | 3 | Confirmed map sau khi user adjust (Phase 2 output) |
| `$BATCH_PROGRESS` | Phase 3 | 3, 4 | Object `{ batch_completed, files_done, files_skipped, files_error, current_batch }` |
| `$TRACEABILITY_BEFORE` | Phase 0 | 4 | % traceability tính trước khi annotate (baseline) |
| `$TRACEABILITY_AFTER` | Phase 4 | 4 | % traceability tính sau khi annotate |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint 65/80% |
| `$E046_BATCH_DECISION` | Phase 3 (first E046) | Phase 3 | Batch-level decision cho annotation conflicts: `null` \| `"UPDATE_ALL"` \| `"SKIP_ALL"` \| `"APPEND_ALL"` — tránh interrupt storm khi nhiều conflicts |
| `$FILE_BACKUP_CACHE` | Phase 3 (Step 3.2b) | Phase 3 (Step 3.7 E042) | In-memory cache: `{file_path → first_150_lines}` — dùng cho E042 rollback trước khi fallback git |
| `error_log[]` | All phases | Phase 4 | Array errors collected — dùng cho report |

---

## Cross-Phase Data Flow

```
Phase 0 (context)        → $LEGACY_MODE, $MATURITY_LEVEL, $MODULE_FILTER, $DRY_RUN,
                            $BATCH_SIZE, $RESUME, $DEPRECATED_MODULES, $TECH_STACK,
                            $TRACEABILITY_BEFORE, annotate-status.json, annotate-plan.md,
                            checkpoint init
Phase 1 (build map)      → $ANNOTATION_MAP, annotation-map.json
Phase 2 (review)         → $USER_CONFIRMED_MAP, annotation-map.json (updated)
                           [EXIT nếu $DRY_RUN = true]
Phase 3 (inject)         → $BATCH_PROGRESS, annotate-checkpoint.json,
                            annotated source files, annotate-status.json (progress)
Phase 4 (verify+report)  → $TRACEABILITY_AFTER, annotation-report.md, ledger.json updated,
                            legacy-scan-status.json updated, annotate-status.json finalized,
                            phase-summary.md, session log COMPLETE event
```

**Quy tắc:** Mỗi phase chỉ READ variables đã SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Comment Format Table

Chuẩn định dạng comment REQ-ID/FEAT-ID theo ngôn ngữ. Phase 3 dùng bảng này để inject đúng format theo file extension.

| Ngôn ngữ | File extensions | Format REQ-ID | Format FEAT-ID |
|----------|----------------|---------------|----------------|
| C#, TypeScript, JavaScript, Java | `.cs`, `.ts`, `.tsx`, `.js`, `.jsx`, `.java` | `// REQ-ID: REQ-SALES-001, REQ-SALES-002` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Python | `.py` | `# REQ-ID: REQ-SALES-001, REQ-SALES-002` | `# FEAT-ID: FEAT-ERP-CRM-001` |
| HTML | `.html`, `.htm` | `<!-- REQ-ID: REQ-SALES-001 -->` | `<!-- FEAT-ID: FEAT-ERP-CRM-001 -->` |
| Vue template | `.vue` | `<!-- REQ-ID: REQ-SALES-001 -->` | `<!-- FEAT-ID: FEAT-ERP-CRM-001 -->` |
| CSS, SCSS, LESS | `.css`, `.scss`, `.less` | `/* REQ-ID: REQ-SALES-001 */` | `/* FEAT-ID: FEAT-ERP-CRM-001 */` |
| Go | `.go` | `// REQ-ID: REQ-SALES-001` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Rust | `.rs` | `// REQ-ID: REQ-SALES-001` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Swift | `.swift` | `// REQ-ID: REQ-SALES-001` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Kotlin | `.kt`, `.kts` | `// REQ-ID: REQ-SALES-001` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Ruby | `.rb` | `# REQ-ID: REQ-SALES-001` | `# FEAT-ID: FEAT-ERP-CRM-001` |
| PHP | `.php` | `// REQ-ID: REQ-SALES-001` | `// FEAT-ID: FEAT-ERP-CRM-001` |
| Shell | `.sh`, `.bash` | `# REQ-ID: REQ-SALES-001` | `# FEAT-ID: FEAT-ERP-CRM-001` |
| SQL | `.sql` | `-- REQ-ID: REQ-SALES-001` | `-- FEAT-ID: FEAT-ERP-CRM-001` |

**Quy tắc format:**
- REQ-IDs nhiều → join bằng `, ` (dấu phẩy + space)
- FEAT-ID chỉ 1 trên mỗi file (lấy feat_id trong annotation map)
- Insert POSITION: sau file header comments (nếu có), trước block code chính (import/using/package declaration cũng được coi là "code chính")

**Language-specific INSERT POSITION exceptions (BUG-03 fix):**

| Ngôn ngữ | Rule đặc biệt |
|----------|--------------|
| **Go** | Insert AFTER `package xxx` declaration — bắt buộc (Go compiler yêu cầu package phải đứng đầu, sau shebangs/build tags). KHÔNG insert trước package declaration hay REQ-ID comment sẽ phá compile. |
| **Python** | Insert AFTER shebang (`#!/usr/bin/env python3`) và encoding declaration (`# -*- coding: utf-8 -*-`) nếu có (thường ở line 1-2). REQ-ID đặt ở line ngay sau magic comments cuối cùng. |
| **Java / Kotlin** | Insert AFTER `package xxx;` declaration nếu có, trước import block. |
| **Default** | Sau license/file header comment block, trước first import statement. Nếu không có imports → dòng 1 (hoặc sau package declaration nếu có). |

Trong Phase 3 Step 3.3, khi tìm insert position, PHẢI kiểm tra các language-specific rules trước khi apply default rule.

**Language detect rule:**
1. Ưu tiên file extension
2. Nếu extension không match → fallback theo `$TECH_STACK.primary_language` (từ project-profile.json)
3. Nếu vẫn không xác định → SKIP file, log vào `error_log[]` với code `E045` (unsupported language)

---

## LEGACY_MODE Detection

Theo CORE-021, **mọi skill detect bằng cùng mechanism**:

```bash
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && \
              [ "$(wc -c < .mc-data/work/legacy-scan/project-context.md)" -gt 500 ]
```

- KHÔNG detect bằng `ledger.json` (false positive — tồn tại từ Stage 0.5).
- KHÔNG check size qua `stat -c %s` (không portable Windows Git Bash). Dùng `wc -c`.

Nếu `$LEGACY_MODE = true`:
- Load `$LEGACY_CONTEXT` từ `project-context.md` (chỉ cache nếu phase cần — Phase 0 không cần content đầy đủ)
- Load `legacy-decisions.json` → xem §LEGACY Decisions Filter

---

## LEGACY Decisions Filter

**Chỉ áp dụng khi `$LEGACY_MODE = true`** (graceful degradation nếu file không tồn tại).

```bash
# Load DEPRECATED modules
IF test -f .mc-data/work/wf-brainstorm/legacy-decisions.json:
  $DEPRECATED_MODULES = jq -r '.modules[] | select(.action == "DEPRECATE") | .id' .mc-data/work/wf-brainstorm/legacy-decisions.json
ELSE:
  $DEPRECATED_MODULES = []
  WARN: "legacy-decisions.json không tìm thấy — bỏ qua DEPRECATE filter."
```

**Phase 1 Filter Application:**

Khi build annotation map, **loại** mọi file thuộc `$DEPRECATED_MODULES` khỏi scope:

```
FOR each module_id trong module-code-mapping.json:
  IF module_id IN $DEPRECATED_MODULES:
    LOG: "Skipped annotation for deprecated module: $module_id"
    CONTINUE  # skip toàn bộ files thuộc module này
  ELSE:
    # tiếp tục scan files bình thường
```

Ghi tổng cộng `skipped_deprecated_modules` vào `annotate-plan.md` §Notes.

---

## Annotation Existence Check

**Phase 3 BẮT BUỘC check** trước khi inject để đảm bảo idempotent (CORE-006 style safe-write cho code).

### Detection patterns per language

| Language | Grep pattern |
|----------|-------------|
| C#, TS, JS, Java, Go, Rust, Swift, Kotlin, PHP | `^\s*//\s*REQ-ID:` |
| Python, Ruby, Shell | `^\s*#\s*REQ-ID:` |
| HTML, Vue | `<!--\s*REQ-ID:` |
| CSS, SCSS, LESS | `/\*\s*REQ-ID:` |
| SQL | `^\s*--\s*REQ-ID:` |

### Decision matrix

| Existing annotation | Target annotation | Action |
|---------------------|-------------------|--------|
| Không có | Có | INJECT (normal flow Phase 3.4-3.5) |
| Có, **khớp** target REQ-IDs (exact set match) | Có | SKIP — log `"Skip [file] — annotation đúng rồi"`, tăng `files_skipped` counter |
| Có, target là **superset** (target có thêm REQ-IDs mới) | Có | E046 variant: hiển thị diff `existing: {A}` → `target: {A, B}` + offer APPEND_NEW / UPDATE / SKIP |
| Có, **khác** target (không phải superset) | Có | E046: `AskUserQuestion`: `UPDATE` (thay toàn bộ) hoặc `SKIP` (giữ nguyên). Hiển thị diff. Log quyết định. |
| Có | Không có target (file không trong map) | SKIP (file ngoài scope) |

**Quy ước match:** set so sánh `{REQ-ID set existing}` vs `{REQ-ID set target}` — thứ tự không quan trọng, dấu cách bỏ qua.

**Superset detection:** Nếu `existing_set ⊆ target_set` (existing là subset của target) → đây là APPEND_NEW case, không phải conflict thực sự.

### E046 Batch-Confirm Mechanism (BUG-05 fix)

Khi E046 xảy ra lần đầu trong một batch, **trước khi hỏi user về file đó**, kiểm tra `$E046_BATCH_DECISION`:

```
IF $E046_BATCH_DECISION is set:
  Apply decision ngay (UPDATE_ALL → UPDATE, SKIP_ALL → SKIP, APPEND_ALL → APPEND_NEW)
  Log decision applied
  CONTINUE (không hỏi user)
ELSE:
  AskUserQuestion: "File [path] có annotation conflict.
    Existing: [existing_ids]
    Target:   [target_ids]  
    Type: [APPEND_NEW | CONFLICT]
    
    Chọn:
    [U] UPDATE — thay toàn bộ bằng target
    [S] SKIP — giữ nguyên existing
    [A] APPEND — chỉ thêm IDs mới (chỉ cho APPEND_NEW type)
    [UA] UPDATE ALL remaining — áp dụng UPDATE cho tất cả conflicts còn lại trong session
    [SA] SKIP ALL remaining — áp dụng SKIP cho tất cả conflicts còn lại
    [AA] APPEND ALL remaining — áp dụng APPEND cho tất cả APPEND_NEW conflicts còn lại"
  
  IF user chọn UA → $E046_BATCH_DECISION = "UPDATE_ALL"
  IF user chọn SA → $E046_BATCH_DECISION = "SKIP_ALL"
  IF user chọn AA → $E046_BATCH_DECISION = "APPEND_ALL"
  Apply decision cho file hiện tại
```

State variable `$E046_BATCH_DECISION` được khởi tạo = null ở Phase 0, persist qua toàn bộ session. Ghi vào `annotate-status.json.phases.phase_3.annotation_conflicts_count` sau mỗi conflict.

---

## Checkpoint Protocol

Checkpoint được lưu sau **mỗi batch** Phase 3 (multi-session — LARGE projects).

### Checkpoint file

Path: `.mc-data/work/legacy-scan/annotate-checkpoint.json`

Template: `.claude/skills/workflow/wf-annotate-code/templates/annotate-checkpoint.json`

Pattern **READ template → POPULATE → WRITE** (CORE-031):

```json
{
  "trigger": {
    "reason": "batch_completed",
    "context_used_pct": 82,
    "batch_index": 2,
    "error_details": null
  },
  "position": {
    "current_phase": "phase_3",
    "current_phase_name": "Inject Annotations",
    "current_batch": 2,
    "next_batch": 3,
    "next_batch_start_index": 100,
    "next_action": "Resume from batch 3"
  },
  "progress": {
    "phases_completed": ["phase_0", "phase_1", "phase_2"],
    "batches_completed": [0, 1, 2],
    "files_annotated": [],
    "files_pending": [],
    "files_error": [],
    "files_skipped": []
  },
  "context_summary": {
    "project_name": "[PROJECT_NAME]",
    "maturity_level": "CODE_ONLY",
    "total_files_in_map": 250,
    "batch_size": 50,
    "total_batches": 5,
    "module_filter": null
  },
  "partial_state": {
    "annotation_map_path": ".mc-data/work/legacy-scan/annotation-map.json",
    "user_confirmed": true,
    "traceability_score_before": 23,
    "features_count": 47,
    "annotation_stats_snapshot": {
      "files_annotated": 100,
      "req_ids_injected": 89,
      "feat_ids_injected": 47
    }
  },
  "resume_instructions": {
    "load_files": [
      ".mc-data/work/legacy-scan/ledger.json",
      ".mc-data/work/legacy-scan/legacy-scan-status.json",
      ".mc-data/work/legacy-scan/annotation-map.json"
    ],
    "resume_from_batch": 3,
    "skip_phases": ["phase_0", "phase_1", "phase_2"],
    "next_action": "Resume annotation injection from batch 3",
    "user_message": "Đã lưu checkpoint. Chạy /wf-annotate-code --resume để tiếp tục."
  }
}
```

> **Lưu ý:** `trigger.reason` phải là string `"batch_completed"` (có chữ 'd'). Phase 4 PRE-GATE check giá trị này qua `jq -r '.trigger.reason'`.

### Trigger conditions

| Condition | Action |
|-----------|--------|
| Context < 65% | Tiếp tục, không checkpoint mid-batch |
| Context ≥ 65% và < 80% | Chuẩn bị checkpoint sau batch hiện tại |
| Context ≥ 80% và < 90% | **FORCE** checkpoint ngay sau batch hiện tại, STOP skill, prompt `--resume` |
| Context ≥ 90% | FORCE checkpoint ngay, STOP skill (kể cả giữa batch nếu cần) |
| Sau mỗi batch (normal) | Update `annotate-checkpoint.json` + `annotate-status.json` |

---

## Resume Logic

Áp dụng khi `$ARGUMENTS` chứa `--resume`.

### Decision flow

```
IF test -f .mc-data/work/legacy-scan/annotate-checkpoint.json:
  checkpoint = đọc annotate-checkpoint.json
ELSE IF test -f .mc-data/work/legacy-scan/legacy-scan-status.json:
  IF jq '.stages.annotate' legacy-scan-status.json tồn tại:
    checkpoint = reconstruct từ stages.annotate
  ELSE:
    STOP: "Không tìm thấy annotate checkpoint. Chạy /wf-annotate-code từ đầu."
ELSE:
  STOP: "Không tìm thấy checkpoint."

IF checkpoint.status == "completed":
  WARN: "Annotate đã hoàn thành trước đó."
  STOP
```

### Filesystem Reconciliation

Trước khi resume Phase 3, reconcile giữa `annotation-map.json` và filesystem thực tế:

```bash
FOR each entry trong annotation-map.json:
  detect_pattern = <grep pattern theo language — xem §Annotation Existence Check>
  IF grep -E "$detect_pattern" "$file_path" > /dev/null:
    already_annotated[].push($entry)
  ELSE:
    pending[].push($entry)

# So sánh với checkpoint
IF already_annotated.length != checkpoint.progress.files_done:
  WARN: "Reconciled: [already_annotated.length] files đã annotated trên disk, [pending.length] files cần xử lý. Checkpoint lệch [diff] files."
  Update checkpoint.progress.files_done = already_annotated.length
```

Sau reconcile: Phase 3 chỉ xử lý `pending[]`.

### Freshness check (BUG-04 fix)

Nếu registry hoặc annotation-map đã thay đổi từ lúc checkpoint:

```bash
# Lấy features count hiện tại từ registry
CURRENT_FEATURES_COUNT=$(jq '.features | length' .mc-data/docs/_meta/req-registry.json)

# So sánh với checkpoint (field partial_state.features_count — thêm vào template v2.0)
CHECKPOINT_FEATURES_COUNT=$(jq -r '.partial_state.features_count // 0' .mc-data/work/legacy-scan/annotate-checkpoint.json)

IF [ "$CURRENT_FEATURES_COUNT" != "$CHECKPOINT_FEATURES_COUNT" ]:
  WARN: "⚠️ Registry đã thay đổi (features count: checkpoint=$CHECKPOINT_FEATURES_COUNT, hiện tại=$CURRENT_FEATURES_COUNT).
         Annotation map có thể lỗi thời.
         Khuyến nghị: chạy lại từ đầu để rebuild annotation map."
  AskUserQuestion: "Tiếp tục với annotation map cũ hay chạy lại từ đầu? [CONTINUE / RESTART]"
  IF RESTART → cleanup checkpoint → Phase 0 từ đầu
```

> **Lưu ý:** Khi tạo checkpoint Phase 0 (init), POPULATE `partial_state.features_count` = `registry.features | length` tại thời điểm đó.

---

## Fix Rules đặc thù

Tham chiếu bởi mọi phase khi gặp error. Tích hợp với Protocol 2 (Auto-Correction Loop).

| Error code | Tình huống | Xử lý | Escalate |
|------------|-----------|-------|----------|
| **E001** | PRE-GATE fail (thiếu prerequisites) | STOP, thông báo user chạy skill predecessor | — (non-recoverable) |
| **E040** | Annotation map rỗng (0 files match) | WARN, `AskUserQuestion` cho manual mapping | Nếu vẫn rỗng sau manual → STOP |
| **E041** | File write fail (IO error) | RETRY ×3 với backoff, sau đó skip file, log | >30% files fail → STOP Phase 3 |
| **E042** | File corrupt sau annotation (syntax break) | ROLLBACK từ in-memory backup (`$FILE_BACKUP_CACHE`) trước, fallback git, log | — (log only) |
| **E043** | Batch checkpoint fail (ghi checkpoint file lỗi) | WARN, tiếp tục batch tiếp theo (không block) | Nếu ≥2 lần liên tiếp → STOP Phase 3 |
| **E044** | Resume checkpoint invalid/corrupt | WARN, fallback chạy từ đầu (Phase 0) sau khi xác nhận với user | — |
| **E045** | Unsupported language (file extension không match bảng) | SKIP file, log | >20% files skipped → STOP Phase 3 |
| **E046** | Annotation tồn tại nhưng khác target | Xem §E046 Batch-Confirm Mechanism: UPDATE / SKIP / APPEND_NEW. Hỗ trợ batch-decision (UPDATE_ALL / SKIP_ALL / APPEND_ALL) để tránh interrupt storm | — (user decision) |

### E042 Backup Mechanism (BUG-06 fix)

`$FILE_BACKUP_CACHE` là in-memory dictionary (key = file_path, value = first ~150 lines content).

**Trước mỗi Edit (Phase 3 Step 3.2b):** Đọc file → cache vào `$FILE_BACKUP_CACHE[file_path]` (100-200 lines đầu là đủ cho rollback vì REQ-ID luôn inject gần đầu file).

**Khi E042 xảy ra (Phase 3 Step 3.7):**
1. Restore từ `$FILE_BACKUP_CACHE[file_path]` (tốt nhất — không cần git)
2. Nếu cache miss → thử `git checkout HEAD -- <file_path>` (cần git history)
3. Nếu cả hai fail → WARN user: "Không thể rollback [file_path]. File có thể bị corrupt — backup thủ công khuyến nghị." Log E042 với `rollback_failed: true`.

---

## Traceability Score

Công thức đo lường trước/sau annotation.

### Baseline (Phase 0)

```bash
# Đếm trong mapped directories
total_mapped_files=$(find <mapped_directories> -type f \( -name "*.cs" -o -name "*.ts" -o -name "*.py" ... \) 2>/dev/null | wc -l)
files_with_reqid_before=$(grep -rlE "(//|#|<!--|/\*|--)\s*REQ-ID:" <mapped_directories> 2>/dev/null | wc -l)

# BUG-02 fix: guard division by zero
if [ "$total_mapped_files" -eq 0 ]; then
  WARN: "⚠️ Không tìm thấy code files trong mapped directories. Kiểm tra module-code-mapping.json paths."
  $TRACEABILITY_BEFORE = 0
else
  $TRACEABILITY_BEFORE = $(( files_with_reqid_before * 100 / total_mapped_files ))
fi

# QA-01 fix: warn nếu mapped scope < 70% tổng project (misleading coverage)
total_project_files=$(find <project_root> -type f \( -name "*.cs" -o -name "*.ts" -o -name "*.py" ... \) \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist 2>/dev/null | wc -l)
if [ "$total_project_files" -gt 0 ]; then
  mapped_coverage_pct=$(( total_mapped_files * 100 / total_project_files ))
  if [ "$mapped_coverage_pct" -lt 70 ]; then
    WARN: "⚠️ Mapped directories chỉ cover $mapped_coverage_pct% tổng project code files
           ($total_mapped_files/$total_project_files). Traceability score sẽ tính trên phần mapped,
           không phản ánh toàn bộ project. Kiểm tra module-code-mapping.json để tăng coverage."
  fi
fi
```

### After (Phase 4)

```bash
files_with_reqid_after=$(grep -rlE "(//|#|<!--|/\*|--)\s*REQ-ID:" <mapped_directories> 2>/dev/null | wc -l)

if [ "$total_mapped_files" -eq 0 ]; then
  $TRACEABILITY_AFTER = 0
else
  $TRACEABILITY_AFTER = $(( files_with_reqid_after * 100 / total_mapped_files ))
fi
```

### Reporting

Ghi vào `annotation-report.md` §Traceability section:

| Thời điểm | Files có REQ-ID | Files mapped | % (mapped) |
|-----------|----------------|--------------|------------|
| Trước annotation | `files_with_reqid_before` | `total_mapped_files` | `$TRACEABILITY_BEFORE%` |
| Sau annotation | `files_with_reqid_after` | `total_mapped_files` | `$TRACEABILITY_AFTER%` |
| Tăng | — | — | `+($TRACEABILITY_AFTER - $TRACEABILITY_BEFORE)%` |

> **Scope note:** Score tính trên mapped directories. Nếu `mapped_coverage_pct < 70%`, hiển thị cảnh báo trong report.

POST-GATE Phase 4 check: `$TRACEABILITY_AFTER > $TRACEABILITY_BEFORE` (phải tăng, không giảm).
