# Phase 5: Update Registry (MAIN CONVERSATION — NO AGENT)

> Cập nhật registry trực tiếp. **KHÔNG delegate cho agent** để tránh token limit.

> **Token Limit Prevention:** xem `.claude/skills/protocols/` — Registry Safe-Write Protocol.

**PRE-GATE:**

```bash
# Phase 4 POST-GATE PASSED
test -s .mc-data/docs/phase2-features/stakeholder-review.md
grep -q "## Phần A" .mc-data/docs/phase2-features/stakeholder-review.md
grep -q "## Phần D" .mc-data/docs/phase2-features/stakeholder-review.md
```

**INPUT:** Registry hiện tại + tất cả feature spec files + `$IMPL_STATUS_MAP` (từ Phase 0.5 nếu LEGACY_MODE) + `$DEPRECATED_MODULES`

**OUTPUT:**
- Registry UPDATED (`features[]` only + `impl_status` per REQ-ID)
- `.mc-data/work/wf-define-features/define-features-report.md`

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.1  | ĐỌC registry JSON hiện tại (ngay trước khi ghi) | Content loaded |
| 5.1b | **(CQG-05)** So sánh registry `requirements[]` với feature docs — warn nếu registry đã thay đổi sau khi feature docs được tạo (requirements mới/sửa chưa được phản ánh) | Freshness verified |
| 5.2  | Extract FEAT-IDs + metadata từ tất cả `phase2-features/**/*.md`. **Bao gồm `impl_status` từ `$IMPL_STATUS_MAP`** (LEGACY_MODE) hoặc default "not_started" (NEW project). Nếu feature thuộc `$DEPRECATED_MODULES` → override `impl_status = "skipped"`. **Lưu ý dual-schema:** Nếu đọc từ `feature-briefs.json` (working), field tên là `feat_id` (không phải `id`) và `system`/`module` (không phải `system_id`/`module_id`). Khi ghi vào registry, PHẢI rename đúng theo schema (xem `_shared.md §Field Name Aliases`). | FEAT list built with impl_status |
| 5.3  | Update `features[]` — upsert by `id`, giữ nguyên tất cả fields khác. **BẮT BUỘC dùng ĐÚNG field names theo schema** (xem `_shared.md §Registry Schema — features[]`). **BẮT BUỘC thêm `impl_status` cho mỗi feature:**<br>(a) LEGACY_MODE: dùng giá trị từ Phase 0.5 pre-population (done/in_progress/not_started)<br>(b) NEW project: default "not_started"<br>(c) Features thuộc DEPRECATE module: "skipped"<br>**BẮT BUỘC bảo vệ impl_status = "done":** Khi upsert feature đã tồn tại trong registry với `impl_status = "done"` (từ wf-implement-feature trước đó) → KHÔNG overwrite `impl_status` — chỉ update các fields khác (name, file, req_ids, dependencies, etc.). Rule: `IF existing.impl_status == "done" THEN preserve ELSE use_new`. | features[] updated |
| 5.3b | **(Schema Guard)** TRƯỚC KHI GHI — validate mỗi entry trong features[]:<br>(1) field names đúng schema (`id` KHÔNG PHẢI `feat_id`, `module_id` KHÔNG PHẢI `module`, `file` KHÔNG PHẢI `file_path`)<br>(2) `dependencies` tồn tại ([] nếu không có)<br>(3) `phase` là NUMBER (1/2/3) KHÔNG PHẢI string ("MVP"/"PHASE_2")<br>(4) `impl_status` tồn tại và là một trong: `not_started` / `in_progress` / `done` / `skipped`<br>Nếu sai → RENAME/FIX theo `_shared.md §Field Name Aliases` trước khi ghi | Schema validated |
| 5.3c | **[Referential Integrity Check v3.1+ — Root cause Finding #1 từ wf-implement-feature E2E]** PRE-WRITE check: mỗi REQ-ID trong `features[].req_ids[]` PHẢI tồn tại trong `requirements[].req_id`. <br><br>**Compute:** <br>```bash<br>REFERENCED=$(jq -r '[.features[].req_ids[]?] \| unique \| .[]' /tmp/registry-staged.json \| sort -u)<br>EXISTING=$(jq -r '[.requirements[].req_id] \| unique \| .[]' .mc-data/docs/_meta/req-registry.json \| sort -u)<br>MISSING=$(comm -23 <(echo "$REFERENCED") <(echo "$EXISTING"))<br>```<br><br>**IF `$MISSING` rỗng** → PASS, tiếp tục step 5.4. <br><br>**ELSE (có orphan REQ-IDs):** <br>1. Log mỗi orphan với context: REQ-ID, FEAT-IDs reference nó, suggested description (từ feature.title + ". " + feature.notes). <br>2. Check flag `--auto-stub-requirements`: <br>&nbsp;&nbsp;• **NẾU SET** → AUTO-FIX path: append stub entries vào `requirements[]` với schema: `{req_id, description: "<from feature title+notes>", priority: "P2", source: "auto-generated", auto_generated_by: "wf-define-features", needs_user_review: true, created_at: "<ISO timestamp>", referenced_by: [<FEAT-IDs>]}`. WARN log mỗi entry: `"AUTO-STUB: REQ-ID [X] — cần user xác nhận description bằng /wf-manage-change hoặc /wf-analyze-requirements --refine-req=[X]"`. Tiếp tục step 5.4. <br>&nbsp;&nbsp;• **NẾU KHÔNG SET** → BLOCK với E020 (Referential Integrity Failure): <br>&nbsp;&nbsp;&nbsp;&nbsp;```<br>&nbsp;&nbsp;&nbsp;&nbsp;ERROR E020: features[].req_ids[] reference REQ-IDs không tồn tại trong requirements[]:<br>&nbsp;&nbsp;&nbsp;&nbsp;  - [X] (referenced by FEAT-A, FEAT-B)<br>&nbsp;&nbsp;&nbsp;&nbsp;  - [Y] (referenced by FEAT-C)<br>&nbsp;&nbsp;&nbsp;&nbsp;Lựa chọn:<br>&nbsp;&nbsp;&nbsp;&nbsp;  (a) Chạy lại với --auto-stub-requirements để auto-create stub requirement entries (cần user review sau)<br>&nbsp;&nbsp;&nbsp;&nbsp;  (b) Chạy /wf-analyze-requirements để bổ sung requirement entries thật<br>&nbsp;&nbsp;&nbsp;&nbsp;  (c) Chạy /wf-manage-change CLARIFY_REQ để add missing entries<br>&nbsp;&nbsp;&nbsp;&nbsp;```<br>&nbsp;&nbsp;&nbsp;&nbsp;STOP — ghi `referential-integrity-violations.json` vào `$SESSION_DIR/` rồi return E020. <br>3. **CORE-006 exception:** APPEND-ONLY path qua `--auto-stub-requirements` chỉ được phép append entries có `auto_generated_by: "wf-define-features"`. KHÔNG modify/delete entries existing. KHÔNG tạo stubs trùng req_id với existing. | Referential integrity verified hoặc auto-stub appended |
| 5.4  | GHI ATOMIC — single write toàn bộ JSON | `jq '.' registry.json` pass |
| 5.5  | VALIDATE: `count features[]` == expected feat count | Counts match |
| 5.5b | **Template Strip + Atomic Write digest (ADR-OPT-05):** Tạo `$SESSION_DIR/feature-briefs.json` từ template `.claude/doc-framework/_digests/feature-briefs.template.json`. Strip metadata: `jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' digest.json > digest-stripped.json`. **Atomic Write** (xem `_shared/_shared.md §1-2`): ghi `$SESSION_DIR/feature-briefs.json.tmp` → validate `jq '.'` → `mv` → final. | `test -s $SESSION_DIR/feature-briefs.json` + `jq -e 'has("_template_notes") | not' $SESSION_DIR/feature-briefs.json` |
| 5.5c | **Sync sang canonical path:** `cp $SESSION_DIR/feature-briefs.json .mc-data/docs/_meta/feature-briefs.json`. Canonical file là source cho downstream skills. | `test -s .mc-data/docs/_meta/feature-briefs.json` |
| 5.6  | Generate `.mc-data/work/wf-define-features/define-features-report.md` theo schema bên dưới | `test -s report` |

## Registry Safe-Write

Xem `_shared.md §Registry Safe-Write`.

**Fields được phép update:** `features[]`, `impl_status` (per REQ-ID).

**Fields TUYỆT ĐỐI KHÔNG modify:** `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type`, `design_status`, `ux_design_status`, `implementation_order`.

## Schema cho `define-features-report.md` (step 5.6 — BẮT BUỘC tạo)

```markdown
# Define Features Report — /wf-define-features

> **Ngày:** [date]
> **Scope:** [all / system-name]
> **Version SKILL:** [version]

## Kết Quả

| Mục | Giá trị |
|-----|---------|
| Feature files tạo mới | [count] |
| FEAT-IDs đăng ký | [count] |
| REQ-IDs đã map | [count] / [total] |
| Cross-validation iterations | [N] |
| Findings RESOLVED | [count] |
| Findings DEFERRED | [count] |
| Stakeholder Review | APPROVED / APPROVED_WITH_CONDITIONS |

## Outputs

| File | Trạng thái |
|------|-----------|
| `docs/phase2-features/` | [count] files |
| `docs/phase2-features/stakeholder-review.md` | ✅ Created |
| `work/wf-define-features/cross-validation-report.md` | ✅ [verdict] |
| `work/wf-define-features/deferred-findings.md` | [count] findings / N/A |
| `docs/_meta/req-registry.json` (features[]) | ✅ Updated — [count] entries |

## UI Coverage (LEGACY_MODE only — chỉ khi Phase 2.7 chạy)

> Bỏ qua section này nếu Phase 2.7 bị SKIP (không có screens hoặc không LEGACY_MODE).

| Mục | Giá trị |
|-----|---------|
| Tổng UI screens | [total_screens] |
| Business screens (trừ infrastructure) | [total_business_screens] |
| Screens đã cover bởi features | [covered] |
| Coverage % | [coverage_pct]% |
| UI gaps (orphan screens) | [gaps count] |
| Ambiguous matches | [ambiguous count] |
| UI coverage report | `.mc-data/work/wf-define-features/ui-coverage-gaps.json` |

### Orphan Screens (nếu có)

| Screen path | Route | Module hint | Gap reason |
|-------------|-------|-------------|------------|
| [screen_path] | [route] | [module_hint] | [gap_reason] |

## WARNs Còn Mở

> (Chỉ liệt kê nếu có WARN sau Phase 3/4 — bỏ qua section này nếu không có)

| Mã | Mô tả | Cần hành động trước |
|----|-------|---------------------|
| [WARN-XX] | [mô tả] | Phase 3 / Stakeholder |

## Next Step

`/wf-design` — Thiết kế architecture. Đọc `deferred-findings.md` ở Phase 0.
```

**POST-GATE:**

```bash
jq '.features | length' .mc-data/docs/_meta/req-registry.json  # phải > 0
jq '.' .mc-data/docs/_meta/req-registry.json > /dev/null       # JSON valid
test -s .mc-data/work/wf-define-features/define-features-report.md
test -s .mc-data/docs/phase2-features/stakeholder-review.md

# T4-SYS-COV: Per-system feature coverage (BẮT BUỘC — NGĂN BUG EUREKA)
# Mỗi system declared phase=MVP trong brainstorm PHẢI có ≥ 1 feature trong registry
# (trừ modules trong $DEPRECATED_MODULES đã bị skipped)
# Approach: lookup qua module_id → modules[].system_id (không parse FEAT-ID string — fragile với multi-segment slug)
jq -e '
  ([.systems[] | select(.phase == "MVP") | .id] | sort) as $mvp_systems
  | (.modules | map({(.id): .system_id}) | add // {}) as $mod_to_sys
  | ([.features[] | select(.impl_status != "skipped") | .module_id as $m | $mod_to_sys[$m]] | unique) as $covered_systems
  | all($mvp_systems[]; . as $s | ($covered_systems | index($s) != null))
' .mc-data/docs/_meta/req-registry.json
# Nếu FAIL → log systems thiếu coverage, STOP với E012
# Root cause bug EUREKA: mobile-staff (MVP) = 0 features bị bỏ qua ở POST-GATE cũ (chỉ check global count)
# Fix approach: dùng module_id lookup thay vì regex trên FEAT-ID (tránh false-negative với slug 'WEB-CUST' vs 'web-customer')

# Schema field validation (BẮT BUỘC — catch sai field names trước khi kết thúc)
jq '.features[0] | has("id","module_id","dependencies","file","impl_status")' \
  .mc-data/docs/_meta/req-registry.json
# Phải trả về true — nếu false → features[] dùng sai field names → quay lại step 5.3b fix

jq '.features[0].phase | type' .mc-data/docs/_meta/req-registry.json
# Phải trả về "number" — nếu "string" → đang dùng label ("MVP") thay vì numeric (1) → fix

jq '[.features[] | select(.dependencies == null or (.dependencies | type) != "array")] | length' \
  .mc-data/docs/_meta/req-registry.json
# Phải trả về 0 — nếu > 0 → có features thiếu dependencies field → thêm [] cho mỗi entry thiếu

# Template strip validation (ADR-OPT-05 — BẮT BUỘC)
jq -e 'has("_template_notes") | not' .mc-data/docs/_meta/feature-briefs.json
# Phải trả về true — nếu false → digest chưa được strip → chạy lại step 5.5b

jq -e '.features | length > 0' .mc-data/docs/_meta/feature-briefs.json
# Phải trả về true — nếu false → feature-briefs rỗng → kiểm tra step 5.5b

# impl_status validation (BẮT BUỘC — CORE-010)
jq '[.features[] | select(.impl_status == null or (.impl_status | IN("not_started","in_progress","done","skipped")) | not)] | length' \
  .mc-data/docs/_meta/req-registry.json
# Phải trả về 0 — nếu > 0 → có features thiếu impl_status hoặc giá trị không hợp lệ → fix

# Referential Integrity validation (BẮT BUỘC v3.1+ — Finding #1 root cause fix)
# Mỗi REQ-ID trong features[].req_ids[] PHẢI tồn tại trong requirements[].req_id
jq -e '
  ([.requirements[].req_id] | unique) as $existing
  | ([.features[].req_ids[]?] | unique) as $referenced
  | ($referenced - $existing) as $orphans
  | $orphans | length == 0
' .mc-data/docs/_meta/req-registry.json
# Phải trả về true — nếu false → có orphan REQ-IDs trong features[].req_ids[] không có trong
# requirements[]. Quay lại step 5.3c — chạy với --auto-stub-requirements hoặc fix manually
# qua /wf-analyze-requirements / /wf-manage-change.
# (Đảm bảo /wf-implement-feature không gặp upstream registry inconsistency — Finding #1)
```

> NẾU FAIL bất kỳ check nào → hoàn thành step còn thiếu trước khi kết thúc.
> Schema validation FAIL → error E011 → fix ngay tại step 5.3b, KHÔNG kết thúc skill.

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 5.

## Content Quality Checks (CQG-07)

Xem `_shared.md §Content Quality Checks (CQG-07)`:

```
1. TRACEABILITY: Mỗi FEAT-ID trong registry có ít nhất 1 REQ-ID mapped
2. CONSISTENCY: features[] count trong registry = số actual feature files trong phase2-features/
3. NẾU FAIL: Auto-fix — bổ sung missing mappings, tạo missing feature files, hoặc xoá orphan entries
```

**Status update:** `$SESSION_DIR/session-state.json` → `phases.P5.status = "completed"`, `completed_at = <ISO timestamp>`. `$SESSION_DIR/define-features-status.json` → `phase_5.status = "completed"`, `status = "completed"`, `progress_pct = 100`, `timestamps.completed_at = <ISO timestamp>`. **SAVE CHECKPOINT** (dual write).

## Output Report

Xem `_shared.md §Output Report Template`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Schema validation fail (E011) | Quay lại step 5.3b — rename fields, retry |
| JSON invalid sau write (E006) | Fix JSON syntax, retry Phase 5 |
| POST-GATE fail sau 3 retries (E009) | STOP — báo cáo chi tiết → user quyết định |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next:** END — print Output Report cho user. Gợi ý `/wf-design` là next step.
