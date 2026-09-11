# Phase 1: Scope & Feature Mapping

> Phân tích scope, nhóm requirements, và gán FEAT-IDs trước khi tạo files.

**PRE-GATE:**

```bash
test -n "$REGISTRY_DATA"
jq '.requirements | length' .mc-data/docs/_meta/req-registry.json  # > 0
```

**INPUT:** Registry (`$REGISTRY_DATA`) + `phase1-handoff.json` (nếu có) + dept docs

**OUTPUT:**
- `.mc-data/work/wf-define-features/define-features-plan.md`
- `.mc-data/work/wf-define-features/feature-briefs.json`

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1  | Parse `$SCOPE` argument (`all` / `[system-name]` / `[module-name]`). Lưu `$SCOPE` vào `define-features-status.json.flags.scope` | Scope set |
| 1.1-SYS | **Load brainstorm systems[]** (BẮT BUỘC cho per-system coverage): `$SYSTEMS = jq '.systems' registry.json`. Nếu `$SYSTEMS` length > 0 → `$MULTI_SYSTEM_PROJECT = true`. Đây là input cho fan-out logic ở Step 1.2. | `$SYSTEMS` loaded |
| 1.2  | **Per-system Fan-out (ADR thay cross_system):** Với mỗi REQ trong `registry.requirements[]`: đọc `REQ.systems[]` (array BẮT BUỘC đã set bởi wf-analyze-requirements Phase 8). Với mỗi `system_id` trong `REQ.systems[]` → tạo 1 feature group riêng `(system_id, module_id)`. Ví dụ: REQ-CX-001 với `systems: ["web-customer","mobile-customer"]` → 2 feature groups: `(web-customer, cx)` và `(mobile-customer, cx)`. Dùng `$LEGACY_DECISIONS` để loại modules DEPRECATE khỏi scope. Dùng `$SCOPE` để filter nếu scope=system/module cụ thể. | Groupings defined, multi-system REQs fan-out đúng |
| 1.2b | **Fallback** (backward-compat): Nếu REQ không có `systems[]` field (registry cũ) → derive từ `REQ.primary_module` → `modules[primary_module].system`. Log WARNING: "REQ {id} thiếu systems[] — dùng fallback 1-system. Khuyến nghị chạy lại /wf-analyze-requirements." | Warning logged |
| 1.3  | Gán FEAT-ID scheme: `FEAT-[SYS]-[MOD]-NNN` (zero-padded, e.g. 001). [SYS] lấy từ system slug (erp/mobile-staff/web-customer/mobile-customer). Kiểm tra registry `features[]` hiện tại để tránh trùng lặp. Lưu `$FEAT_IDS`. | FEAT-IDs assigned |
| 1.4  | Tạo `define-features-plan.md` từ template `.claude/skills/workflow/wf-define-features/templates/define-features-plan.md` (Template Usage Rule) | `test -s define-features-plan.md` |
| 1.4-COV | **System coverage preview (BẮT BUỘC):** Bổ sung vào `define-features-plan.md` bảng `per-system feature count preview`: `\| system_id \| feature_count \| req_ids contributing \|`. Nếu có system declared trong brainstorm với count=0 trong scope hiện tại → log WARNING và fail nếu `$SCOPE == "all"` với severity BLOCKING (vì `/wf-analyze-requirements` Phase 8.6-COV đã pass nên chắc chắn có REQ cho mọi system). | Preview written |
| 1.5  | **(Protocol 9 — PLN-07)** Bổ sung vào `define-features-plan.md`: (a) Feature→file mapping table (FEAT-ID → output path), (b) Batch strategy nếu > 10 features (batch per module, mỗi batch ≤ `$MAX_PARALLEL_AGENTS`), (c) Token estimate theo Protocol 9.3 (read files + agents + output files + validations), (d) Ghi rõ `large_project_mode` flag và overrides nếu `$LARGE_PROJECT = true` | Plan updated |
| 1.5b | Tạo `.mc-data/work/wf-define-features/feature-briefs.json` từ template `.claude/skills/workflow/wf-define-features/templates/feature-briefs.json` — mỗi brief gồm các fields theo template: `feat_id`, `feature_name`, `system` (tên system), `module` (tên module), `req_ids`, `actors`, `business_rules`, `cross_dependencies`, `output_path`, `notes`. Nguồn ưu tiên: `phase1-handoff.json` + dept docs + registry. **Với REQ fan-out multi-system** → mỗi system có 1 brief riêng (cùng REQ-ID nhưng khác `system`). **BẮT BUỘC loại trừ features thuộc `$DEPRECATED_MODULES`** — không tạo brief cho features thuộc module DEPRECATE. | `test -s feature-briefs.json` |
| 1.6  | **Stub Detection** (xem `_shared.md §Stub Detection & Flesh-out Rules`): `grep -l "^status: stub" .mc-data/docs/phase2-features/**/*.md 2>/dev/null` → ghi `$STUB_FILES`. Hiển thị "Found N stub files — will be fleshed-out at Phase 2" nếu có | `$STUB_FILES` populated |

## FEAT-ID Assignment Rules

- Format: `FEAT-[SYS]-[MOD]-NNN` (ví dụ: `FEAT-CRM-CUST-001`)
- 1 feature group = 1 FEAT-ID = 1 file output
- Một feature group có thể tham chiếu nhiều REQ-IDs
- Không tạo FEAT-ID trùng lặp; kiểm tra registry trước khi gán
- **Multi-system fan-out:** 1 REQ-ID có thể map vào N feature groups (N = len(REQ.systems[])). Mỗi group ở 1 system → FEAT-ID khác nhau theo prefix system. Ví dụ REQ-CX-001 → `FEAT-WC-CX-001` (web-customer) + `FEAT-MC-CX-001` (mobile-customer).

## Cross-system REQ Handling (v2 — via requirements[].systems[])

**Nguồn sự thật:** `requirements[].systems[]` do `/wf-analyze-requirements` Phase 8 set. KHÔNG dùng field `cross_system` cũ (deprecated).

Quy tắc:
- `len(REQ.systems[]) == 1` → tạo 1 feature ở system đó. Feature entry trong registry KHÔNG cần `cross_system` field.
- `len(REQ.systems[]) >= 2` → fan-out: tạo 1 feature RIÊNG cho MỖI system. Mỗi feature có `cross_system: [<các systems khác>]` để tham chiếu các counterparts (helpful cho /wf-design và /wf-implement-feature sau này).
- KHÔNG gộp multiple systems vào 1 feature duy nhất (root cause của bug EUREKA: 10 REQ-CX dồn thành 9 feature cho web và 1 feature cho mobile — phải là 10 feature cho web + 10 feature cho mobile).

## File Naming Convention

- Directory: dùng **viết tắt thường** từ System/Module ID — vd: `SYS-CRM` → `crm/`, `MOD-CRM-CUST` → `customer-management/`
- File: dùng **tiếng Việt không dấu**, kebab-case — vd: `quan-ly-thong-tin-khach-hang.md` (không dùng English name như `customer-management.md`)
- Ví dụ đầy đủ: `phase2-features/crm/customer-management/quan-ly-thong-tin-khach-hang.md`

**POST-GATE:**

```bash
test -s .mc-data/work/wf-define-features/define-features-plan.md
test -s .mc-data/work/wf-define-features/feature-briefs.json
jq '. | length' .mc-data/work/wf-define-features/feature-briefs.json  # > 0

# T-COV: khi $SCOPE=all, mỗi system declared (phase=MVP) trong brainstorm phải có ≥ 1 feature brief
# (tính dựa trên fan-out từ requirements[].systems[])
# Dùng field "system" (khớp với templates/feature-briefs.json template field)
if [ "$SCOPE" = "all" ]; then
  jq -e --slurpfile reg .mc-data/docs/_meta/req-registry.json '
    ($reg[0].systems | map(select(.phase == "MVP") | .id)) as $mvp
    | ([.features[] | .system // .system_id] | unique) as $covered
    | all($mvp[]; . as $s | ($covered | index($s)))
  ' .mc-data/work/wf-define-features/feature-briefs.json
fi
```

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true` → **SAVE CHECKPOINT** sau Phase 1.

**Status update:** `define-features-status.json` → `phase_1.status = "completed"`, `phase_1.completed_at = <ISO timestamp>`, `phase_1.feat_ids_assigned = <count>`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Retryable error (E002 scope invalid) | Dùng default `all` + log warning |
| FEAT-ID trùng (E005) | Re-run Phase 1 FEAT-ID mapping |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `.mc-data/work/wf-define-features/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase2-create-specs.md`
