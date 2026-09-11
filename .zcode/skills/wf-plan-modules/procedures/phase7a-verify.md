# Phase 7a: Output Verification (AUTO-CORRECTION LOOP)

> Kiểm tra toàn diện: output files nhất quán với registry và dependency analysis.
> Tự động lặp lại cho đến khi không còn lỗi — tối đa 3 iterations.

> **Protocol:** Xem `.claude/skills/protocols/` — Auto-Correction Loop Protocol.
> **Shared context:** xem `_shared.md` — Fix Rules đặc thù, Error Tracking.

---

## PRE-GATE

Phase 7 + Phase 7.5 (+ Phase 7.5.0 nếu áp dụng) output files đã được tạo.
`$SESSION_DIR/lanes/` có ít nhất 1 `signals.json` non-empty.

---

## 📥 INPUT (cross-validate)

- `module-plan.md`, `dependency-graph.md`, `roadmap`, `sprint plans`, `impl task files`, `registry`
- `$SESSION_DIR/lanes/*/*/signals.json` (glob tất cả levels)
- `$SYSTEM_COVERAGE_MAP`, `$COVERAGE_STRATEGY` (in-memory từ Phase 1.7)
- `$DEPRECATED_MODULES` (in-memory từ Phase 0)

> **Tham khảo:** `.claude/doc-framework/_meta/dependency-detail-map.md` — Bản đồ phụ thuộc field-level giữa các tài liệu, dùng để kiểm tra xung đột nội dung cross-phase.

## 📤 OUTPUT

| File | Mô tả |
|------|-------|
| Các files input | Được fix nếu có lỗi (auto-fix in-place) |
| `$SESSION_DIR/aggregation-result.json` | Aggregated signals từ tất cả lanes — **Template Usage Rule:** READ `_shared/templates/aggregation-result.json` → POPULATE → WRITE |

---

## Signal Aggregation (Đầu Phase 7a — trước Validation Checks)

| Step | Action | Verify |
|------|--------|--------|
| 7a.0 | **Signal Aggregation (ADR-OPT-04):** Import `_shared/aggregate/aggregator.py`. `aggregate_lane_signals(lane_outputs=glob("$SESSION_DIR/lanes/*/*/signals.json"), dedup_key_fn=dedup_by_id("task_id"))`. **Template Usage Rule:** READ `_shared/templates/aggregation-result.json` → POPULATE kết quả → WRITE `$SESSION_DIR/aggregation-result.json`. | `test -s $SESSION_DIR/aggregation-result.json` |
| 7a.0b | **[BLOCKING GATE] Signal Conflict Check:** Đọc `$SESSION_DIR/aggregation-result.json`. IF `conflicts[]` non-empty: **BLOCK** — không tiếp tục validation checks. Hiển thị chi tiết từng conflict: `task_id`, modules liên quan, loại conflict (shared_infrastructure / duplicate_work). `AskUserQuestion`: *(a) Resolve manually — tôi sẽ chỉnh sửa task files rồi chạy lại Phase 7a; (b) Auto-merge — áp dụng rule: ưu tiên module ở layer thấp hơn (closer to foundation); (c) Bỏ qua — tiếp tục với cả hai entries (có thể duplicate work)*. Ghi quyết định vào `$SESSION_DIR/aggregation-result.json` field `conflict_resolution`. IF user chọn (a) → STOP + hướng dẫn; IF (b) → apply auto-merge rule + log; IF (c) → log warning + tiếp tục. | Conflicts resolved hoặc user acknowledged |
| 7a.0a | **CORE-019 cross-check:** Với mỗi task_id trong `aggregation-result.json`, verify: nếu `implementation_strategy != "IMPLEMENT_NEW"` → `existing_code_refs[]` PHẢI non-empty. Nếu vi phạm → log ERROR + cờ để 7a verify loop xử lý. | All tasks verified |

---

## Validation Checks (mỗi iteration)

| Check | Action | Khi FAIL → Auto-Fix |
|-------|--------|----------------------|
| 7a.1 | Module IDs trong `implementation_order` tồn tại trong `modules[]` | Fix module ID hoặc remove invalid entry |
| 7a.2 | Tất cả nodes trong dependency-graph là defined modules | Remove orphan nodes hoặc add missing module |
| 7a.3 | Topological order — không có module depend on module ở layer cao hơn | Re-sort theo dependencies |
| 7a.4 | Sprint plans reference valid module IDs (skip nếu `--skip-sprints`) | Fix module references trong sprint files |
| 7a.5 | Registry `implementation_order` field đã được cập nhật | Update registry field |
| 7a.6 | Registry JSON valid (`jq '.'` pass) | Fix JSON syntax |
| 7a.6b | `implementation_order` đúng canonical schema (xem `_shared.md` §Implementation Order Schema) | Reformat theo schema ở Phase 7 |
| 7a.7 | Mỗi feature trong registry có file `-impl.md` tồn tại trong `phase5-implementation/tasks/` | Tạo file thiếu từ template |
| CQG-10.1 | **[CQG-10] Completeness:** `implementation_order.layers[].modules` chứa TẤT CẢ modules từ `registry.modules[]` — không thiếu, không thừa | Thêm module thiếu vào layer phù hợp / xóa module thừa |
| CQG-10.2 | **[CQG-10] Orphan Check:** Dependency graph không có orphan nodes — mọi node trong graph tồn tại trong `registry.modules[]` VÀ mọi module trong registry tồn tại trong graph | Remove orphan nodes / thêm missing nodes |
| CQG-05.1 | **[CQG-05] Inter-Phase Count:** Số modules trong Phase 5 docs (module-plan, roadmap, sprints) = số modules trong `registry.modules[]` | Thêm/xóa module trong P5 docs cho khớp registry |
| CQG-05.2 | **[CQG-05] Inter-Phase Names:** Tên modules trong P5 docs khớp với tên trong registry (case-insensitive) — không đổi tên, không viết tắt | Fix tên module trong P5 docs theo registry |
| CQG-05.3 | **[CQG-05] Inter-Phase Scope:** Phase 5 KHÔNG chứa modules/features ngoài scope Phase 2-3 — kiểm tra mọi module ID trong P5 tồn tại trong registry | Xóa module ngoài scope / escalate nếu ambiguous |
| CQG-10.3 | **[CQG-10] System Coverage:** Mỗi `system_id` trong `registry.systems[]` XUẤT HIỆN ở ít nhất 1 module trong `implementation_order.layers[].modules[]` (dựa trên `sys_id`/`system_id`/`system` field của module). Nếu `$COVERAGE_STRATEGY == "thin_clients"` → skip check cho systems trong `thin_client_systems[]`. Nếu `$COVERAGE_STRATEGY == "placeholders"` → cho phép orphan nhưng BẮT BUỘC có placeholder file (xem 7a.10). | KHÔNG auto-fix (cần upstream fix) → log WARNING vào error_log với action "escalate_user", gợi ý chạy `/wf-define-features` |
| 7a.10 | **Placeholder Check (khi `$COVERAGE_STRATEGY == "placeholders"`):** Mỗi orphan system trong `$SYSTEM_COVERAGE_MAP` có file `.mc-data/docs/phase5-implementation/tasks/[sys-slug]/_NO-FEATURES.md` tồn tại và non-empty | Tạo lại placeholder từ Phase 7.5.0 template |
| 7a.11 | **Module-plan Coverage Section Check:** `module-plan.md` có section `## System Coverage` liệt kê tất cả systems (covered + orphan + thin_client) | Regenerate section từ `$SYSTEM_COVERAGE_MAP` |
| 7a.12 | **A6-EXT Quality Gate (BẮT BUỘC — bù trừ R1+R2):** Với mỗi task file `tasks/[sys]/[mod]/[feat]-impl.md` (skip DEPRECATED/orphan), verify A6-EXT depth (xem §A6-EXT Quality Checks). Mục tiêu: đảm bảo wf-implement-feature `$EXECUTABLE_SPEC` non-empty và đủ chi tiết để developer agent KHÔNG cần fallback đọc Phase 2/3 docs. | Re-spawn architect agent cho feature đó, max 1 retry. Vẫn fail → log WARNING vào `error_log[]` với `severity=HIGH`, `action="downstream_fallback_required"`, gợi ý user re-run `/wf-plan-modules --resume` |
| 7a.13 | **A2.4 Scope Files Quality Gate (BẮT BUỘC — parallel safety):** Với mỗi task file, verify section A2.4 tồn tại + có ≥1 row file với mode hợp lệ + có `Parallel-Safe Verdict`. Verify `parallel-safe-groups.md` tồn tại + chứa mọi active features (trừ DEPRECATED). Xem §A2.4 Scope Files Quality Checks. | Re-spawn architect cho feature thiếu A2.4. Nếu `parallel-safe-groups.md` thiếu → re-run Step 7.5.7. Max 1 retry. Vẫn fail → log WARNING `severity=HIGH`, `action="parallel_unsafe"`, user phải chạy sequential |

---

---

## §A6-EXT Quality Checks (Step 7a.12 chi tiết)

> **Mục đích:** Bù trừ rủi ro R1+R2 (A6-EXT chất lượng không đồng đều) — đảm bảo downstream
> wf-implement-feature đọc được spec đầy đủ, không phải fallback đọc full Phase 2/3 docs.

```bash
# Iterate qua mọi task file (skip DEPRECATED + orphan systems)
FOR each TASK_FILE in glob ".mc-data/docs/phase5-implementation/tasks/*/*/*-impl.md":

  # Bỏ qua nếu module thuộc $DEPRECATED_MODULES hoặc system thuộc orphan_systems
  IF module_of(TASK_FILE) IN $DEPRECATED_MODULES → CONTINUE
  IF system_of(TASK_FILE) IN orphan_systems → CONTINUE

  # T1: A6-EXT section tồn tại
  if ! grep -q "^### A6-EXT\." "$TASK_FILE"; then
    log "ERROR 7a.12.T1: $TASK_FILE thiếu section A6-EXT"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T2: Coverage Summary section non-empty
  if ! grep -q "^### A6-EXT.0 Coverage Summary" "$TASK_FILE" \
     || ! grep -q "\*\*Total files\*\*" "$TASK_FILE"; then
    log "ERROR 7a.12.T2: $TASK_FILE thiếu Coverage Summary đầy đủ"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T3: Có ≥1 file spec với Imports table
  FILE_COUNT=$(grep -c "^#### File [0-9]" "$TASK_FILE")
  if [ "$FILE_COUNT" -lt 1 ]; then
    log "ERROR 7a.12.T3: $TASK_FILE không có file spec nào"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T4: Word count A6-EXT ≥ 200 từ
  A6EXT_WC=$(awk '/^### A6-EXT\./,/^### A7-EXT\.|^### A7\./' "$TASK_FILE" | wc -w)
  if [ "$A6EXT_WC" -lt 200 ]; then
    log "ERROR 7a.12.T4: $TASK_FILE A6-EXT chỉ $A6EXT_WC từ (<200)"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T5: KHÔNG còn placeholder `[...]` trong A6-EXT (escape lowercase + uppercase brackets)
  PLACEHOLDER_COUNT=$(awk '/^### A6-EXT\./,/^### A7-EXT\.|^### A7\./' "$TASK_FILE" \
                      | grep -cE '\*\[[a-zA-Z][^]]*\]\*|\[FEAT-XXX|\[REQ-XXX|\[fieldName\]|\[methodName\]')
  if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    log "WARNING 7a.12.T5: $TASK_FILE A6-EXT còn $PLACEHOLDER_COUNT placeholder chưa POPULATE"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  log "PASS 7a.12: $TASK_FILE A6-EXT đạt quality gate ($A6EXT_WC từ, $FILE_COUNT files)"
DONE
```

**Auto-Fix Strategy (max 1 retry per task file):**

```
FOR each TASK_FILE flagged:
  1. Re-spawn architect agent với prompt nhấn mạnh:
     - "POPULATE template a6-ext-fragment.md đầy đủ — lần trước fail check 7a.12.T[X]"
     - "Tổng word count A6-EXT PHẢI ≥200 từ"
     - "KHÔNG để placeholder `[...]` còn lại"
  2. Re-run T1-T5 checks
  3. Nếu vẫn fail → log error_log entry:
     {
       "phase": "7a", "step": "7a.12",
       "severity": "HIGH",
       "code": "E_A6EXT_QUALITY",
       "message": "Task file [PATH] A6-EXT không đạt depth — wf-implement-feature sẽ fallback đọc Phase 2/3 docs",
       "auto_fix_applied": "Re-spawn architect failed",
       "action": "downstream_fallback_required",
       "user_action": "Re-run `/wf-plan-modules --resume` hoặc manual edit task file"
     }
  4. KHÔNG block Phase 7a — A6-EXT quality issue là HIGH nhưng wf-implement-feature có
     fallback (đọc A1-A6 nếu A6-EXT thiếu/sơ sài), nên cho phép skill complete với WARNING.
```

**Aggregate metric (ghi vào error_log summary):**

```
total_features_with_a6ext = N
features_passing_7a_12    = M
a6ext_coverage_ratio      = M / N

LOG: "[A6-EXT Quality] $M/$N features ($a6ext_coverage_ratio%) đạt quality gate.
      $((N - M)) features sẽ fallback Phase 2/3 reads trong wf-implement-feature."
```

---

## §A2.4 Scope Files Quality Checks (Step 7a.13 chi tiết)

> **Mục đích:** Bảo đảm wf-implement-feature có thể đọc A2.4 để detect cross-feature file conflict
> trước khi spawn developer agent (parallel safety).

```bash
VALID_MODES="EXCLUSIVE_WRITE|EXCLUSIVE_CREATE|SHARED_APPEND|SHARED_READ"

FOR each TASK_FILE in glob ".mc-data/docs/phase5-implementation/tasks/*/*/*-impl.md":
  IF module_of(TASK_FILE) IN $DEPRECATED_MODULES → CONTINUE
  IF system_of(TASK_FILE) IN orphan_systems → CONTINUE

  # T1: Section A2.4 tồn tại
  if ! grep -q "^#### A2.4 Scope Files" "$TASK_FILE"; then
    log "ERROR 7a.13.T1: $TASK_FILE thiếu section A2.4 Scope Files"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T2: ≥1 row với mode hợp lệ
  ROWS=$(awk '/^#### A2.4 Scope Files/,/^---|^####/' "$TASK_FILE" \
         | grep -cE "\| ($VALID_MODES) \|")
  if [ "$ROWS" -lt 1 ]; then
    log "ERROR 7a.13.T2: $TASK_FILE A2.4 không có row file nào với mode hợp lệ"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  # T3: Parallel-Safe Verdict tồn tại với value hợp lệ
  if ! grep -qE "Parallel-Safe Verdict.*?(SAFE_PARALLEL|REQUIRES_SEQUENTIAL_WITH:)" "$TASK_FILE"; then
    log "ERROR 7a.13.T3: $TASK_FILE thiếu Parallel-Safe Verdict hợp lệ"
    flag_for_retry "$TASK_FILE"; CONTINUE
  fi

  log "PASS 7a.13: $TASK_FILE A2.4 đạt quality gate ($ROWS files)"
DONE

# T4: parallel-safe-groups.md tồn tại + chứa mọi active features
GROUPS_FILE=".mc-data/docs/phase5-implementation/parallel-safe-groups.md"
if [ ! -s "$GROUPS_FILE" ]; then
  log "ERROR 7a.13.T4: parallel-safe-groups.md thiếu hoặc rỗng"
  flag_global_fix "regenerate_parallel_safe_groups"
fi

# Aggregate metric
total_a24 = N
passing_7a_13 = M
LOG: "[A2.4 Scope Files] $M/$N features ($((M*100/N))%) parallel-safe.
      $((N-M)) features REQUIRES_SEQUENTIAL — user phải chạy tuần tự."
```

**Auto-Fix Strategy:**
- T1-T3 fail → re-spawn architect cho feature đó (1 retry)
- T4 fail → re-run Step 7.5.7 aggregation
- Vẫn fail → log WARNING `severity=HIGH`, không block skill (parallel-safe-groups.md là enhancement, không phải blocker)

---

## Loop Execution

| Step | Action | Verify |
|------|--------|--------|
| 7a.LOOP | Iterate qua tất cả checks. Sau mỗi check FAIL → apply Auto-Fix theo bảng + log vào `error_log[]` + retry check | Loop counter < 3 |
| 7a.8 | Log validation results (mỗi iteration) | Report updated |
| 7a.9 | Ghi tổng kết: iterations count, errors fixed, errors remaining | Summary logged |

**Termination:**
- Zero validation errors → PASS
- Vẫn còn errors sau 3 iterations → ESCALATE user (E009)
- User acknowledge remaining errors → CONDITIONAL PASS

**Registry Safe-Write (impl_status — LEGACY DEPRECATED modules):**
- Giữ nguyên CORE-006 SAFE-UPDATE logic (từ Phase 7 §Registry Update).
- CDG token flow khi downgrade `done → skipped` (LEGACY + deprecated modules): xem `phase7-outputs.md §Registry Update`. Phase 7a KHÔNG tự trigger CDG riêng — chỉ kiểm tra `cdg-tokens.json` đã được ghi ở Phase 7 (nếu CDG đã diễn ra).
- Nếu phát hiện thêm deprecated features chưa được set `skipped` (edge case) → escalate user, KHÔNG tự downgrade.

---

## POST-GATE

Zero validation errors HOẶC user acknowledged remaining errors

---

## Next

→ Checkpoint: position → `phase_7b`
→ Read `procedures/phase7b-review.md`
