# Phase 5b: Cross-Validation (AUTO-CORRECTION LOOP)

> **Protocol:** Xem `.claude/skills/protocols/` — Auto-Correction Loop Protocol (Protocol 2)
> **Shared:** Xem `procedures/_shared.md` — State Variables

Kiểm tra nhất quán kết quả từ tất cả checks. Phát hiện contradictions. Max 3 iterations.

---

## PRE-GATE

Phases 2, 3, 4, 5 đều đã chạy (hoặc skip hợp lệ).

```
test -n "$REGISTRY_ISSUES" && test -n "$DOC_ISSUES"
# $SYNC_ISSUES và $QUALITY_ISSUES có thể = [] nếu skip hợp lệ
```

> **Lưu ý:** Xử lý in-memory. Không tạo file.

---

## Structural Consistency Checks

| Check | Action | Verify |
|-------|--------|--------|
| 5b.1 | Verify: tất cả target IDs từ Phase 1 (`$TARGET_*`) đã được check trong Phases 2-5 | Complete coverage |
| 5b.2 | Verify: không có contradiction giữa `registry.impl_status` và code scan kết quả | Consistent |
| 5b.3 | Verify: `$SCORES.registry`, `.docs`, `.sync`, `.quality` đều có giá trị (hoặc null nếu skip hợp lệ) | All scores set |
| 5b.4 | Verify: `error_log` không có duplicate entries | No dupes |
| 5b.5 | Verify: tất cả file paths trong issues list thực sự tồn tại trên disk | Paths valid |
| 5b.6 | Recalculate `overall_score` từ component scores (preview — final ở Phase 7) | Score consistent |
| 5b.7a | Nếu `$HAS_FIX_FLAG = true`: capture `$PRE_FIX_SCORES = {registry, docs, sync, quality}` — dùng cho Phase 6.5 delta | Scores saved |

---

## Content Quality Check (Protocol 8)

> Bổ sung cho structural checks ở trên — kiểm tra DATA sẽ ghi vào `preflight-report.md` (chưa ghi file, đang xử lý in-memory). Xác nhận data đầy đủ và nhất quán TRƯỚC khi populate template ở Phase 7.

| Check | Action | Verify |
|-------|--------|--------|
| 5b.7 | **Completeness:** Mỗi section trong report có findings thực tế (không chỉ "No issues" cho TẤT CẢ sections — ít nhất 1 section phải có data cụ thể) | Sections have content |
| 5b.8 | **Consistency:** Issue IDs cross-ref khớp giữa sections (vd: issue #3 trong Critical list phải match issue #3 trong detail section) | IDs consistent |
| 5b.9 | **Traceability:** Mỗi issue trong report map ngược được về phase phát hiện (Phase 2/3/4/5) | All issues traced |
| 5b.10 | **Coherence:** Score calculations khớp với issue counts (vd: 0 CRITICAL issues nhưng `registry_score = 0` → contradiction) | Scores match issues |

---

## Inter-Phase Consistency Check (Protocol 8.3)

> Preflight là cross-phase validator — kiểm tra nhất quán GIỮA các phases của workflow (không chỉ nội bộ).

| Check | Action | Verify |
|-------|--------|--------|
| 5b.11 | **Số lượng:** Số modules/features (có `impl_status != "skipped"`) trong registry khớp với số feature docs trong `phase2-features/` và số impl plans trong `phase5-implementation/tasks/`. **Loại trừ features có `impl_status = "skipped"` khỏi expected count.** | Counts match (skipped excluded) |
| 5b.12 | **Tên:** System/module/feature names trong registry khớp (case-insensitive) với folder/file names trong docs | Names consistent |
| 5b.13 | **Scope creep:** Nếu có feature doc hoặc impl plan cho module/feature KHÔNG tồn tại trong registry → log **MEDIUM** severity (không phải HIGH), ghi NOTE "Orphan doc — chạy /wf-add-scope nếu muốn track chính thức." Không block PASS. | Orphan docs noted |
| 5b.14 | **References:** Cross-refs trong Phase 3 docs (architecture → feature docs, API contract → REQ-IDs) trỏ đến paths thực tế tồn tại | Refs valid |

> Nếu phát hiện mismatch ở 5b.11/5b.12: log chi tiết (expected vs actual), phân loại HIGH severity, ghi vào report section "Inter-Phase Consistency" để user biết phase nào cần re-run.
> 5b.13 (orphan docs) chỉ là MEDIUM — không block PASS, không force WARN.

---

## Auto-Correction Loop

> Xem `.claude/skills/protocols/` Protocol 2.

```
iteration = 0
WHILE iteration < 3 AND contradictions_found:
  fix_contradictions_in_place (vd: recalculate score, de-dup issues, remove invalid paths)
  iteration += 1

IF iteration == 3 AND still contradictions:
  log E009 → escalate to user with detailed report
```

---

## Null Coverage Disclaimer Check

Sau khi tất cả validations hoàn thành, tính số dimensions có giá trị:

```
non_null_count = count(scores WHERE score != null)
  IN: registry_score, docs_score, sync_score, quality_score

IF non_null_count < 2:
  → Set flag $COVERAGE_DISCLAIMER = "low_coverage"
  → Note: "Chỉ [non_null_count]/4 dimensions được đo — verdict có độ tin cậy thấp"

IF sync_score = null AND quality_score = null:
  → Set flag $CODE_NOT_CHECKED = true
  → Note: "Code chưa được kiểm tra (không có src/ hoặc tooling không khả dụng)"
```

> Flags này được đọc bởi Phase 7 để thêm disclaimer vào report.

---

## POST-GATE

Zero cross-validation contradictions VÀ zero inter-phase mismatches, HOẶC đã escalated to user.

- `$PRE_FIX_SCORES` = snapshot scores (chỉ khi `$HAS_FIX_FLAG = true`)
- `$COVERAGE_DISCLAIMER` = flag nếu < 2 dimensions có giá trị
- `$CODE_NOT_CHECKED` = flag nếu sync + quality đều null
- Status file `preflight-status.json`: `phases.phase_5b.status = "completed"`

---

## Output → Next Phase

- Validated issues lists (đã được reconcile)
- `$PRE_FIX_SCORES` — đọc bởi Phase 6.5 nếu `--fix`

**Next:** Nếu `$HAS_FIX_FLAG = true` → Phase 6 (Auto-fix). Ngược lại → Phase 7 (Report).
