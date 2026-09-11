# Phase 3: Cross-Validation (AUTO-CORRECTION LOOP)

> Kiểm tra toàn diện nhất quán giữa registry, requirements, và feature specs đã tạo.
> **Tự động lặp lại** cho đến khi KHÔNG còn lỗi — tối đa 3 iterations.

> **Auto-Correction:** Áp dụng Auto-Correction Loop Protocol (max 3 iterations) — xem `.claude/skills/protocols/`.

**PRE-GATE:**

```bash
# Phase 2 POST-GATE PASSED — verify feature files exist
feature_count=$(find .mc-data/docs/phase2-features/ -name "*.md" ! -name "stakeholder-review.md" | wc -l)
test "$feature_count" -gt 0
test -n "$FEAT_IDS"
```

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** Registry + toàn bộ `phase2-features/**/*.md` + dept docs + `deferred-issues.md`

**OUTPUT (auto-fix):** `phase2-features/**/*.md` (nếu cần fix), registry (nếu phát hiện missing FEAT-IDs), `.mc-data/work/wf-define-features/cross-validation-report.md`

## Scan Method

Xem `_shared.md §Scan Method Selection`:
- Lựa chọn A — Full Grep Scan (khuyến nghị khi ≤ 20 features)
- Lựa chọn B — Sampling (khi > 20 features và token budget tight)

> Spot-check tùy ý < 30% là KHÔNG chấp nhận được.

## Validation Checks (mỗi iteration)

| Check | Action | Khi FAIL → Auto-Fix |
|-------|--------|---------------------|
| 3.1 | Verify: mỗi REQ-ID trong registry → referenced trong ≥ 1 feature spec (loại trừ features thuộc DEPRECATED modules) | Thêm REQ-ID reference vào spec phù hợp nhất |
| 3.1b | **Signal Aggregation (ADR-OPT-04):** Import `_shared/aggregate/aggregator.py`. `aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("feat_id"))`. Dedup key: FEAT-ID normalized (uppercase, strip sys/mod prefix mismatch). Output: `$SESSION_DIR/aggregation-result.json` (`total_input`, `total_output`, `duplicates`, `conflicts[]`). IF `conflicts[]` non-empty → flag cho Phase 4 stakeholder review (thêm vào conflict log). | `test -s $SESSION_DIR/aggregation-result.json` |
| 3.2 | Verify: mỗi FEAT-ID trong files → unique, không trùng lặp. Kết hợp với kết quả aggregation-result.json (`duplicates` + `conflicts[]`). | Đổi tên FEAT-ID trùng, cập nhật references; ưu tiên lane owning module khi conflict |
| 3.3 | Verify: không có orphan features (FEAT-ID không có REQ-ID tương ứng) | Thêm REQ-ID liên kết HOẶC xoá feature nếu thừa |
| 3.4 | Verify: feature files có đủ 9 sections theo template, không có empty placeholders, **mỗi section ≥ 2 câu nội dung thực** (không tính headers/bullets rỗng) **(CQG-01)**. Skip stubs (`status: stub`) — đánh dấu "awaiting flesh-out" | Điền từ context có sẵn |
| 3.5 | Verify: business rules từ dept docs được phản ánh trong feature specs | Thêm missing BRs vào section Quy Tắc Nghiệp Vụ |
| 3.6 | Verify: permission matrix nhất quán giữa các related features (cùng module) | Chuẩn hoá permission definitions |
| 3.7 | **(CQG-03)** Verify: số lượng features + modules KHÔNG vượt quá scope Phase 1 — mỗi feature PHẢI trace về ≥ 1 REQ-ID tồn tại trong registry. Feature không có REQ-ID gốc = scope expansion | Xoá feature HOẶC escalate nếu không rõ REQ-ID gốc |
| 3.8 | **(W4.7 — Non-blocking, chạy NGOÀI auto-correction loop, SAU POST-GATE)** Cross-Module Entity Detection: quét feature specs tìm tham chiếu `MOD-[A-Z0-9-]+` từ module khác chưa khai báo trong `cross_module_dependencies[]`. **Graceful skip:** (a) registry không có `cross_module_dependencies` field → skip; (b) headless mode → deferred-findings.md. Xem §W4.7 Cross-Module Entity Detection. | Suggest only — KHÔNG block POST-GATE |

## Auto-Fix Rules

Xem `_shared.md §Fix Rules → Phase 3 Cross-Validation Fix Rules`.

## WARN Triage Decision

**BẮT BUỘC phân loại sau mỗi iteration — trước khi kết thúc Phase 3.**

Xem `_shared.md §WARN Triage Decision`.

## Auto-Correction Loop

```
iteration = 1
MAX_ITERATIONS = 3

WHILE iteration <= MAX_ITERATIONS:
  Run all validation checks (3.1 → 3.7)
  Classify errors: Fixable vs NeedsHumanReview
  IF zero errors:
    → POST-GATE PASS, break loop
  ELSE:
    Apply auto-fixes for Fixable errors
    iteration += 1

IF iteration > MAX_ITERATIONS và vẫn còn errors:
  → E007 — auto-fix loop exhausted
  → Escalate tới user, in danh sách errors còn lại
```

**Cross-validation-report PHẢI ghi (bắt buộc — nếu thiếu → POST-GATE FAIL):**

```markdown
**Phương pháp scan:** Full scan / Sampling [N/total, %]
**Số iterations:** [1–3]
**Iteration 1:** [N lỗi tìm thấy] → [N đã fix] → còn [N]
**Iteration 2 (nếu có):** [N lỗi] → [N đã fix] → còn [N]
**Verdict cuối:** PASS / PASS_WITH_WARN / FAIL
```

**POST-GATE:**

```bash
test -s .mc-data/work/wf-define-features/cross-validation-report.md
grep -q "Verdict cuối: PASS" .mc-data/work/wf-define-features/cross-validation-report.md || \
  grep -q "Verdict cuối: PASS_WITH_WARN" .mc-data/work/wf-define-features/cross-validation-report.md

# Zero Critical validation errors còn open

# T3: aggregation-result.json phải tồn tại và hợp lệ (check 3.1b bắt buộc tạo)
test -s $SESSION_DIR/aggregation-result.json
jq -e '.total_output >= 0' $SESSION_DIR/aggregation-result.json
# Nếu FAIL → check 3.1b chưa chạy hoặc aggregator import fail → re-run step 3.1b
```

> Zero validation errors (tất cả checks PASS) HOẶC user acknowledged remaining errors.

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 3.

**Status update:** `$SESSION_DIR/session-state.json` → `phases.P3.status = "completed"`, `completed_at = <ISO timestamp>`. Append aggregation metrics: `dedup_input_count`, `dedup_output_count`, `conflict_count`. `$SESSION_DIR/define-features-status.json` → `phase_3.iterations = <N>`, `phase_3.verdict = "PASS|PASS_WITH_WARN"`. **SAVE CHECKPOINT** (dual write).

## W4.7: Cross-Module Entity Detection (Non-blocking)

> Chạy SAU POST-GATE — KHÔNG block tiếp tục nếu skip hoặc fail.
> Ref: `plans/wf-fix-bugs-v9/01-waves.md §W4.7` / wf-fix-bugs v9.

**PRE-GATE (graceful skip — exit 0 không lỗi):**

```bash
# Skip nếu registry chưa có cross_module_dependencies field (W1.1 schema chưa apply)
jq -e 'has("cross_module_dependencies")' .mc-data/docs/_meta/req-registry.json \
  || { echo "W4.7 skip: cross_module_dependencies field absent"; exit 0; }
```

**Algorithm:**

| Sub-step | Action |
|----------|--------|
| A1 | Đọc `registry.cross_module_dependencies[]` (mảng, có thể rỗng) |
| A2 | Với mỗi feature spec file `phase2-features/{sys}/{mod}/feat.md`: lấy `mod_slug` từ path → tìm `module_id` trong `registry.modules[]` có slug chứa `{mod}` (heuristic — dùng field `id` hoặc `slug`) |
| A3 | `grep -oE "MOD-[A-Z0-9-]+"` trong nội dung file → collect `referenced_modules` (SET, loại bỏ own module + `$DEPRECATED_MODULES`) |
| A4 | Với mỗi `ref_module` in `referenced_modules`: kiểm tra `cross_module_dependencies[]` đã có entry `{consumer_module=own_module, provider_module=ref_module}` → skip nếu đã có |
| A5 | Gom nhóm `undeclared_pairs[]`: `{feature_file, feat_ids[], own_module, ref_module}` |

**Xử lý kết quả:**

**Interactive mode** (khi chạy trong conversation có user):

```
IF undeclared_pairs KHÔNG rỗng:
  Gom nhóm theo (own_module, ref_module) pair.
  Với mỗi pair (tối đa 4 câu hỏi 1 lần qua AskUserQuestion):
    question: "Feature(s) [feat_ids] trong module '[own_module]' reference module '[ref_module]'.
               Có cần khai báo cross_module_dependency trong registry không?"
    options:
      - "Có, thêm vào registry"  → append minimal entry (xem bên dưới)
      - "Không, bỏ qua"          → skip
      - "Ghi vào deferred-findings" → append to deferred-findings.md

    IF user chọn "Có, thêm vào registry":
      seq = len(cross_module_dependencies) + 1
      new_entry = {
        "id": "CMD-{consumer_slug}-{provider_slug}-{seq:03d}",
        "consumer_module": own_module,
        "provider_module": ref_module,
        "entity": "",            // User fill sau
        "binding_type": "api",   // Default conservative
        "required_fields": [],
        "optional_fields": []
      }
      → Safe-write registry: append new_entry vào cross_module_dependencies[]
        (đọc registry fresh → append → validate jq → ghi atomic)
      → LOG "W4.7: Added CMD-{id} ({own_module} → {ref_module})"
```

**Headless mode** (automated / non-interactive — không có user):

```
IF undeclared_pairs KHÔNG rỗng:
  Append to .mc-data/work/wf-define-features/deferred-findings.md:
  ---
  ## Cross-Module Dependencies chưa khai báo (W4.7 — {timestamp})
  Phase 3 phát hiện N (own_module → ref_module) pairs chưa có trong registry:
  [list: "{own_module} → {ref_module}" per pair, kèm feat_ids]
  → Action: Review và thêm vào registry cross_module_dependencies[] manually
             hoặc chạy /wf-define-features --resume trong interactive mode.
  ---
  LOG "W4.7: N undeclared cross-module pairs → deferred-findings.md"
```

**Quy tắc quan trọng:**
- Check 3.8 **KHÔNG ghi vào `cross-validation-report.md`** — không ảnh hưởng verdict
- Check 3.8 **KHÔNG block POST-GATE** và **KHÔNG throw error**
- Registry safe-write chỉ khi user chọn "Có" trong interactive mode (CORE-006)
- Nếu deferred-findings.md chưa tồn tại → tạo mới từ template `.claude/doc-framework/_meta/deferred-findings-template.md` (CORE-031)

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Auto-fix loop exhausted (E007) | **SAVE CHECKPOINT** (dual write: session-state.json + checkpoint.json với status="error") → STOP + escalate findings → user quyết định. Checkpoint cho phép user resume sau khi manual-fix. |
| Auto-fix regression (E010) | Restore từ `.bak` file (nếu có) → escalate với context |
| Max 3 iterations reached | **SAVE CHECKPOINT** → STOP + in danh sách errors còn lại |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase4-stakeholder-review.md`
