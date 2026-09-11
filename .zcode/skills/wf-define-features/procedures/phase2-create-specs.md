# Phase 2: Create Feature Specs (MAIN WORK)

> Tạo từng feature spec file — 1 file per feature group.
> **CHECKPOINT** sau mỗi system hoàn thành nếu context > 65%.
>
> **(Protocol 7 — PAR-06 + 6.6)** Features thuộc **KHÁC MODULE trong cùng system** chạy PARALLEL (mỗi module spawn 1 BA agent riêng, tạo feature files song song — các modules ghi vào directories riêng, không conflict). Cross-system features vẫn SEQUENTIAL (cần context từ system trước). Batch ≤ `$MAX_PARALLEL_AGENTS` đồng thời (standard: 5 / LPM: 3).

**PRE-GATE:**

```bash
test -s .mc-data/work/wf-define-features/define-features-plan.md
test -s .mc-data/work/wf-define-features/feature-briefs.json
```

> **(CORE-026)** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md §Execution Trace Protocol`).

**INPUT:** Registry + `project-intent-digest.json` (nếu có) + `phase1-handoff.json` (nếu có) + `feature-briefs.json` + toàn bộ `phase1-business/departments/[dept]/[dept].md` + `P1-02-business-workflow.md` + `deferred-issues.md` (nếu có) + feature template

**OUTPUT:** `.mc-data/docs/phase2-features/[sys]/[mod]/[feature-name].md` (per feature)

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.1  | **Lane Dispatch (ADR-OPT-01):** `mkdir -p phase2-features/[sys]/[mod]/` cho từng module (loại bỏ `$DEPRECATED_MODULES`). Build danh sách lanes — mỗi `(system, module)` pair là 1 lane với: `key="{system-slug}-{module-slug}"`, `agent_type="business-analyst"`, `prompt=BA Phase 2 template từ _shared.md`, `output_path=$SESSION_DIR/lanes/{system}-{module}/signals.json`. **THỰC HIỆN bằng Agent tool trực tiếp** (spawn 1 BA agent per lane, tối đa `$MAX_PARALLEL_AGENTS` lanes đồng thời). **KHÔNG chạy `dispatcher.py` qua Bash** — đó là utility reference framework, không executable độc lập. | Lanes dispatched, max_parallel enforced |
| 2.2  | Đọc template: `doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md` | Template loaded |
| 2.2b | **(Protocol 6.2 + 6.6)** Per feature group: ưu tiên nạp context từ `feature-briefs.json` + `phase1-handoff.json` + `project-intent-digest.json` trước. Nếu vẫn cần thêm chi tiết và tổng input files (registry + dept docs + workflow + deferred) > threshold (standard: 3 / LPM: 2) → main conversation Grep key sections (`^##\|REQ-\|Quy trình\|Yêu cầu\|→`) từ mỗi dept doc, tạo digest bổ sung (standard: ~150 từ/file / LPM: ~300 từ/file Extended). Truyền brief/handoff + digest cho agent thay vì full paths khi được | Context bundle ready (hoặc skip nếu ≤ threshold) |
| 2.3  | **TRƯỚC KHI spawn mỗi lane** — kiểm tra skip condition:<br>&nbsp;&nbsp;`test -f .mc-data/docs/phase2-features/[sys]/[mod]/[feat-slug].md && test -s [path]`<br><br>- Nếu file **đã tồn tại, non-empty, và KHÔNG có `status: stub`** → LOG "Skip [FEAT-ID] — file đã có, bỏ qua" + cộng vào `features_completed` → **KHÔNG spawn lane**<br>- Nếu file tồn tại nhưng có `status: stub` → spawn lane với flesh-out instruction (xem `_shared.md §Stub Detection & Flesh-out Rules`)<br>- Nếu chưa có → dispatch lane `business-analyst` (xem `_shared.md §Agent Context Templates → Business-Analyst Phase 2`)<br><br>**LEGACY_MODE:** thêm LEGACY Context Injection block (xem `_shared.md §LEGACY_MODE Context Injection`) + impl_status hint từ `$IMPL_STATUS_MAP` | Agent success (hoặc skipped nếu file đã có) |
| 2.4  | Per lane complete: verify `$SESSION_DIR/lanes/{sys}-{mod}/signals.json` tồn tại + non-empty. Verify feature .md files được viết vào `phase2-features/{sys}/{mod}/*.md` (no placeholders, no TODO/TBD, 9 sections đúng template). | `test -s $SESSION_DIR/lanes/{sys}-{mod}/signals.json` + grep pass |
| 2.5  | Sau MỖI lane complete: **update `$SESSION_DIR/session-state.json`** `phases.P2.batches[{sys}-{mod}].status = "completed"` (L2). Cập nhật `lanes_completed[]`. **SAVE CHECKPOINT** (dual write: session-state.json + checkpoint.json) sau mỗi system hoàn thành. | session-state.json updated, checkpoint saved |

> **Lane output schema:** `_shared/templates/lane-signal.json` (`lane_key`, `lane_type="feature"`, `items[]=[{feat_id, module, system, ...}]`, `metadata`)
>
> **Write-scope isolation:** Mỗi lane viết vào `phase2-features/{sys}/{mod}/` riêng → không lock contention (CORE-025).

## Spawn Pattern

> **(Protocol 7)** Mỗi BA agent chỉ tạo 1 feature file → không ghi cùng file → an toàn PARALLEL. Batch ≤ 5 agents (Standard) hoặc ≤ 3 agents (LPM) theo Protocol 7.5 + 6.6.

> **(Protocol 9 — PLN-03)** Context checkpoint: Khi context ≥ 65% → ưu tiên finish batch hiện tại → SAVE CHECKPOINT → dừng session. Khi ≥ 80% → KHÔNG spawn thêm agent. Khi ≥ 90% → FORCE STOP. (Xem `_shared.md §Token Budget & Checkpoint`)

> **Subagent context fallback:** Nếu Agent tool không khả dụng → thực hiện BA role inline. Ghi chú: "BA role executed inline (no Agent tool)."

## LEGACY_MODE Handling

- Module action=DEPRECATE → SKIP toàn bộ features thuộc module đó. Log: "Feature skipped: module deprecated per user decision". impl_status của feature = "skipped" (sẽ được propagate Phase 5).
- Module action=IMPROVE → spawn agent với note "Improve existing — không viết từ đầu". Truyền impl_status từ `$IMPL_STATUS_MAP`.
- Divergence resolution: khi spec feature có conflict → follow decision đã resolve trong `legacy-decisions.json`.

**POST-GATE:**

```bash
# Tất cả feature files (không thuộc DEPRECATED modules) đã tồn tại, non-empty
# Mỗi REQ-ID trong scope đã được map
# Path đúng: phase2-features/[sys]/[mod]/[feature].md
# Blockquotes metadata, no YAML front-matter, no placeholders

for feat in $FEAT_IDS_NON_DEPRECATED; do
  test -s "$(feature_path $feat)" || fail
done

# Verify không còn stub khi đã flesh-out xong
grep -l "^status: stub" .mc-data/docs/phase2-features/**/*.md
# Các files còn "status: stub" phải là features DEPRECATE/skip

# T2: Feature files có đúng 9 sections
grep -rl "## Quy Tắc Nghiệp Vụ" .mc-data/docs/phase2-features/ --include="*.md" | grep -v stakeholder | wc -l
```

**Status update:** `$SESSION_DIR/session-state.json` → `phases.P2.status = "completed"`, `completed_at = <ISO timestamp>`. `$SESSION_DIR/define-features-status.json` → `phase_2.features_completed = <count>`, `phase_2.features_skipped = <count>`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Retryable error (E003, E004) | Retry ≤ 3 lần, ghi error_log |
| Max retry reached | STOP + báo cáo → user quyết định |
| Non-retryable (E002) | STOP + dùng default scope |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:**
- Nếu `$LEGACY_MODE = true` → `phase2.5-feat-mapping.md`
- Nếu không → `phase3-cross-validation.md`
