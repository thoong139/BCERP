# Phase 4: Stakeholder Review (AUTO-CORRECTION LOOP)

> Spawn parallel agents kiểm tra đa chiều: feature coverage, nhất quán, gap analysis.

> **Auto-Correction:** Áp dụng Auto-Correction Loop Protocol (max 3 iterations) — xem `.claude/skills/protocols/`.
> Fix source documents (feature specs), KHÔNG fix SO docs. Regenerate ONLY affected SO docs sau mỗi iteration.

**PRE-GATE:**

```bash
# Phase 3 Cross-Validation PASSED
grep -q "Verdict cuối: PASS" .mc-data/work/wf-define-features/cross-validation-report.md || \
  grep -q "Verdict cuối: PASS_WITH_WARN" .mc-data/work/wf-define-features/cross-validation-report.md
```

**INPUT:** Registry + tất cả `phase2-features/**/*.md` + dept docs + SO template từ `doc-framework/phase2-features/stakeholder-review.md`

**OUTPUT:**
- `.mc-data/docs/phase2-features/stakeholder-review.md` (Phần A: dashboard, Phần B: SO-01, Phần C: SO-02, Phần D: SO-03)
- `.mc-data/work/wf-define-features/deferred-findings.md` (nếu có DEFERRED findings)

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.1  | Đọc tất cả Phase 2 feature docs (loại trừ DEPRECATE modules) | All loaded |
| 4.1b | **(Protocol 6.4)** Ưu tiên dùng `.mc-data/work/wf-define-features/feature-briefs.json` làm nguồn tổng hợp có sẵn. Đếm tổng input files (feature specs + dept docs + registry); nếu > 5 files → main conversation tạo thêm `_tmp-feature-digest.md`: Grep key info (`^##\|FEAT-\|REQ-\|Quy tắc\|Permission`) từ mỗi feature file (~100 từ/file) và merge với briefs. Agents nhận brief/digest làm primary input, đọc file gốc chỉ khi cần xác nhận chi tiết | Digest ready (hoặc skip nếu ≤ 5 files) |
| 4.2  | Spawn PARALLEL: `business-analyst` agent → `_tmp-so-bc.md` (Phần B + C) + `product-expert` agent → `_tmp-so-d.md` (Phần D). Xem `_shared.md §Agent Context Templates → BA Phase 4` và `→ Product-Expert Phase 4`. Truyền digest nếu 4.1b áp dụng | Agents success |
| 4.3  | **MERGE** `_tmp-so-bc.md` + `_tmp-so-d.md` → `stakeholder-review.md` theo ĐÚNG cấu trúc template `.claude/doc-framework/phase2-features/stakeholder-review.md`:<br>(1) Phần A: điền A.1–A.4 với data thực tế (status từng feature file, review status, issue tracker, confirmation checklist)<br>(2) Phần B: copy từ `_tmp-so-bc.md` section B<br>(3) Phần C: copy từ `_tmp-so-bc.md` section C<br>(4) Phần D: copy từ `_tmp-so-d.md` section D<br>**KHÔNG được rút gọn thành summary 5-section.**<br>**(Protocol 6.5 + 6.6)** Nếu merged output > `skeleton_threshold` (standard: 3000 từ / LPM: 2000 từ) → dùng skeleton-first pattern: tạo skeleton trước, điền chi tiết sau | Merge complete — 4 phần A/B/C/D đầy đủ |
| 4.4  | Xoá temp files `_tmp-so-*.md` | Temp files removed |
| 4.5  | Cập nhật Phần A (dashboard) với status + issues summary | Phần A có nội dung |
| 4.7  | **CLASSIFY FINDINGS** — phân loại mỗi finding: Fixable hoặc Deferred (xem Fix Rules + Danh giá tổng thể bên dưới) | Tất cả findings đã classified |
| 4.8  | **AUTO-CORRECTION LOOP** (max 3 iterations) — auto-fix Fixable findings. Sau mỗi iteration, regenerate ONLY affected SO docs | Zero Critical/High PENDING |
| 4.9  | Cập nhật Phần A — tổng hợp RESOLVED + DEFERRED với lý do | `test -s stakeholder-review.md` |
| 4.10 | **SAVE CHECKPOINT** từ template `.claude/skills/workflow/wf-define-features/templates/checkpoint.json` — populate position, progress, feat_id_state, validation_state, next_action. Lưu vào `.mc-data/work/wf-define-features/checkpoint.json` | Checkpoint saved |
| 4.11 | Nếu có findings DEFERRED → extract vào `.mc-data/work/wf-define-features/deferred-findings.md` từ template `.claude/doc-framework/_meta/deferred-findings-template.md` (xem Schema bên dưới) | File exists (hoặc skip nếu zero DEFERRED) |

## Agent Context

Xem `_shared.md §Agent Context Templates`:
- BA Phase 4 → `_tmp-so-bc.md` (Phần B: SO-01 + Phần C: SO-02)
- Product-Expert Phase 4 → `_tmp-so-d.md` (Phần D: SO-03)

**LEGACY_MODE:** chèn LEGACY Context Injection block (xem `_shared.md §LEGACY_MODE Context Injection`) vào đầu prompt của cả 2 agents.

## Fix Rules cho Phase 4

Xem `_shared.md §Fix Rules → Phase 4 Stakeholder Review Fix Rules`.

## Đánh giá tổng thể

| Kết quả | Điều kiện |
|---------|-----------|
| **APPROVED** | Zero Critical/High findings open (tất cả RESOLVED) |
| **APPROVED_WITH_CONDITIONS** | Có DEFERRED Critical/High — nhưng tất cả đã classified, không PENDING |
| **REJECTED** | Có PENDING Critical/High sau 3 iterations — STOP (E008) |

## Schema cho `deferred-findings.md` (step 4.11)

Extract DEFERRED items từ `phase2-features/stakeholder-review.md` Phần A → optional input cho `/wf-design` Phase 0:

```markdown
# Deferred Findings từ /wf-define-features

> Nguồn: phase2-features/stakeholder-review.md Phần A — DEFERRED items
> Ngày tạo: [date]
> Consumer: /wf-design Phase 0 (optional input)

## Danh sách Findings

| # | Finding ID | Severity | Mô tả | Lý do Defer | Phase xử lý |
|---|-----------|----------|-------|-------------|-------------|
| 1 | DF-P2-001 | Critical/High/Medium | [mô tả] | [lý do không fix tại feature phase] | /wf-design |

## Ghi chú

[Các domain gaps, architectural decisions cần xử lý tại /wf-design]
```

**POST-GATE:**

```bash
# Kiểm tra đủ 4 phần bắt buộc trong stakeholder-review.md
grep -q "## Phần A" .mc-data/docs/phase2-features/stakeholder-review.md
grep -q "## Phần B" .mc-data/docs/phase2-features/stakeholder-review.md
grep -q "## Phần C" .mc-data/docs/phase2-features/stakeholder-review.md
grep -q "## Phần D" .mc-data/docs/phase2-features/stakeholder-review.md

# Zero Critical/High findings ở trạng thái PENDING
```

> NẾU bất kỳ grep nào FAIL → Phần tương ứng bị thiếu:
> - Còn temp files → merge lại
> - Temp files đã xoá → re-spawn agent tương ứng với digest pattern (step 4.1b)

**Status update:** `define-features-status.json` → `phase_4.status = "completed"`, `phase_4.completed_at = <ISO timestamp>`, `phase_4.iterations = <N>`, `phase_4.verdict = "APPROVED|APPROVED_WITH_CONDITIONS"`.

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 4.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Auto-fix loop exhausted (E008) | **SAVE CHECKPOINT** (dual write: session-state.json + checkpoint.json với status="error") → STOP + REJECTED, báo cáo findings → user quyết định. Checkpoint giúp user resume sau khi manual-fix. |
| Auto-fix regression (E010) | Restore từ `.bak` file (nếu có) → escalate với context |
| Critical/High PENDING sau 3 iterations | **SAVE CHECKPOINT** → STOP — báo cáo chi tiết cho user |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase5-registry-update.md`
