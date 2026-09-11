# Phase 6: Registry Update & Finalize (Compressed Spec)

> Update registry `design_status = "completed"` và tạo compressed spec (`design-summary.json`)
> cho `/wf-implement-feature` — bước cuối trước `/wf-design-ux` hoặc `/wf-plan-modules`.

> **Token Limit Prevention:** xem `_shared.md` §Registry Safe-Write.
> Tất cả steps: Main conversation trực tiếp (Read → modify in memory → Write → Validate).
> KHÔNG spawn agent cho registry update — agent chỉ dùng cho step 6.5 (report generation).

**PRE-GATE:**

```bash
# Phase 5 POST-GATE PASSED (stakeholder-review.md tồn tại, zero PENDING Critical)
test -s .mc-data/docs/phase3-architecture/stakeholder-review.md
test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md
```

**INPUT:**
- `req-registry.json` (fresh read)
- `P3-01-architecture.md` + `technical-specs/{api-contract,database-design,integration-map}.md`
- `phase2-features/**/*.md`
- `stakeholder-review.md`

**OUTPUT:**
- `req-registry.json` (safe-write `design_status`)
- `.mc-data/work/wf-design/design-report.md`
- `.mc-data/work/wf-design/deferred-findings.md` (conditional)
- `.mc-data/work/wf-design/design-summary.json` (compressed spec)

---

## Sub-Phase 6A: Registry Update + Design Report

**Registry Safe-Write Protocol (BẮT BUỘC):**

```
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY field `design_status` — giữ nguyên mọi fields khác
3. NEVER MODIFY: systems[], modules[], departments[], requirements[], features[],
   interface_type, implementation_order, impl_status, ux_design_status
4. GHI ATOMIC — single write operation cho toàn bộ JSON
5. VALIDATE sau ghi — `jq '.' registry.json` phải pass
```

> **Legacy flow extension:** cũng được phép update `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `features[]`, `interface_type` và `requirements[].impl_status` (CHỈ fix invalid values → `not_started`, CORE-010).

| Step | Action | Verify |
|------|--------|--------|
| 6.1 | ĐỌC registry JSON hiện tại (fresh read) | Content loaded |
| 6.2 | MODIFY chỉ field `design_status: "completed"` — giữ nguyên mọi fields khác | Field updated |
| 6.3 | GHI ATOMIC — single Write operation toàn bộ JSON | `jq '.design_status' registry.json` |
| 6.4 | VALIDATE JSON — `jq '.' registry.json` pass | JSON valid |
| 6.5 | Generate `.mc-data/work/wf-design/design-report.md` (design completion + cross-validation summary) | `test -s design-report.md` |
| 6.6 | Nếu có DEFERRED findings → ĐỌC template `_meta/deferred-findings-template.md` → POPULATE findings từ `stakeholder-review.md` Phần A → GHI `.mc-data/work/wf-design/deferred-findings.md` | File exists (hoặc skip nếu zero DEFERRED) |
| 6.7 | Cập nhật `design-status.json` với finding counts (pending/resolved/deferred per SO) | JSON valid |

### Schema cho `deferred-findings.md`

Trích xuất DEFERRED items từ `stakeholder-review.md` Phần A → output cho `/wf-plan-modules` Phase 0:

```markdown
# Deferred Findings từ /wf-design

> Nguồn: phase3-architecture/stakeholder-review.md Phần A — DEFERRED items
> Ngày tạo: [date]
> Consumer: /wf-plan-modules Phase 0 (optional input)

## Danh sách Findings

| # | Finding ID | Severity | Mô tả | Lý do Defer | Phase/Sprint xử lý |
|---|-----------|----------|--------|-------------|---------------------|
| 1 | DF-001 | Critical/High/Medium | [mô tả finding] | [lý do không fix tại design] | [pre-launch / sprint N] |

## Tác động đến Implementation

[Ghi chú về cách deferred findings ảnh hưởng đến thứ tự implement hoặc sprint planning]
```

---

## Sub-Phase 6B: Compressed Spec (`design-summary.json`)

> Tạo compressed spec cho `/wf-implement-feature` — giảm context load từ ~3300 words → ~200 tokens/module.
> Consumer: `wf-implement-feature` Phase 1 step 1.9.

| Step | Action | Verify |
|------|--------|--------|
| 6.8 | Đọc `req-registry.json` → lấy danh sách modules với key `[sys]-[mod]` | Module list ready |
| 6.9 | Với mỗi module: Grep `api-contract.md` → extract endpoints (method + path + handler) | API refs extracted |
| 6.10 | Với mỗi module: Grep `database-design.md` → extract table names | DB tables extracted |
| 6.11 | Với mỗi module: Grep `integration-map.md` → extract integration calls + key constraints | Constraints extracted |
| 6.12 | Từ `req-registry.json` modules[].folder_hint (hoặc derive từ module name): điền `folder_map` | Folder map ready |
| 6.13 | Assemble và Write `$SESSION_DIR/design-summary.json` theo schema dưới (working copy). Template strip nếu dùng template: `jq 'del(._template_notes)' data.json > stripped.json`. | `test -s $SESSION_DIR/design-summary.json` |
| 6.14 | Validate JSON valid: `jq '.' $SESSION_DIR/design-summary.json` | JSON valid |

**Schema `design-summary.json`:**

```json
{
  "generated_at": "[YYYY-MM-DD]",
  "version": "1.0",
  "modules": {
    "[sys]-[mod]": {
      "api_quick_ref": [
        { "method": "POST", "path": "/orders", "handler": "OrderService.createOrder()" }
      ],
      "db_tables": ["orders", "order_items"],
      "key_constraints": ["soft_delete", "optimistic_locking", "uuid_pk"],
      "integration_calls": ["inventory.reserve on create"],
      "folder_map": {
        "entity": "src/[module]/entities/",
        "service": "src/[module]/[module].service.ts",
        "controller": "src/[module]/[module].controller.ts",
        "tests": "src/[module]/__tests__/"
      }
    }
  }
}
```

> **Fallback:** Nếu file specs chưa đầy đủ → tạo `design-summary.json` với fields hiện có, để `[]` cho fields thiếu. `wf-implement-feature` sẽ fallback về đọc full specs khi thấy array rỗng.

---

## POST-GATE

```bash
# Registry check
jq -e '.design_status == "completed"' .mc-data/docs/_meta/req-registry.json

# Design report
test -s .mc-data/work/wf-design/design-report.md

# Compressed spec (session working copy)
test -s $SESSION_DIR/design-summary.json
jq '.' $SESSION_DIR/design-summary.json
jq 'has("_template_notes") | not' $SESSION_DIR/design-summary.json

# session-state updated
jq -e '.phases.P6.status == "completed"' $SESSION_DIR/session-state.json
```

> **Lưu ý:** Canonical sync của `design-summary.json` sang `.mc-data/work/wf-design/design-summary.json` được thực hiện tại Phase 8 (sau Template Strip đầy đủ).

**Checkpoint:** UPDATE session-state.json: SET `phases.P6.status = "completed"`, `next_action = "phase7-gap"` (LEGACY) hoặc `"phase8-digest-summary"` (new). Sync → checkpoint.json backward-compat. Nếu `$LARGE_PROJECT = true` → SAVE ngay sau Phase 6.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E003 | Output file write fail | Retry 3 lần, sau đó escalate to user |
| E005 | Registry JSON validation fail | Rollback → re-read → retry write |

---

## Next Phase

- Nếu `$LEGACY_MODE = true` → Read `procedures/phase7-gap.md` — Gap Analysis
- Nếu `$LEGACY_MODE = false` → Read `procedures/phase8-digest-summary.md` — Digest + Phase Summary
