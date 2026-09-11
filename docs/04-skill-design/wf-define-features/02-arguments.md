# 02 — Arguments

> **Mục đích file:** 5 arguments — bao gồm `--auto-stub-requirements` (Referential Integrity escape hatch) và `--from-scan` (Sprint 5 cross-skill).

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `scope` | enum | `all` | Không | `all` / `[system-name]` / `[module-name]` |
| `--status` | flag | — | Không | Hiển thị tiến độ |
| `--resume` | flag | — | Không | Resume từ checkpoint |
| `--from-scan=<id\|path>` | string | — | Không | (Sprint 5) Consume `feature-inventory.md` + `target-map.json` từ wf-scan-target làm SUGGESTIONS |
| `--auto-stub-requirements` | flag | OFF | Không | (v3.1) Khi orphan REQ-IDs detected ở Phase 5, AUTO-APPEND stub entries vào `requirements[]` thay vì BLOCK với E020 |

---

## 2. `--auto-stub-requirements` (v3.1)

**Default behavior:** Phase 5 step 5.3c detect orphan REQ-IDs (features[].req_ids[] − requirements[].req_id) → BLOCK với E020 + 3 lựa chọn:
1. Pass `--auto-stub-requirements` flag (auto-append stubs)
2. Re-run `/wf-analyze-requirements` để generate đầy đủ requirements
3. Dùng `/wf-manage-change` để manual add requirements

**Khi pass flag:** APPEND stub entries vào `requirements[]` với tracking fields:
```json
{
  "req_id": "REQ-SALES-007",
  "description": "(auto-stub) Auto-generated from FEAT-CRM-CUST-001 reference",
  "department": "sales",
  "auto_generated_by": "wf-define-features --auto-stub-requirements",
  "needs_user_review": true,
  "source": "feature_reference",
  "referenced_by": ["FEAT-CRM-CUST-001"]
}
```

Output debug: `$SESSION_DIR/referential-integrity-violations.json`

**WHY:** Root cause Finding #1 từ wf-implement-feature E2E — orphan REQ-IDs gây null lookup crash. Fix tại upstream (wf-define-features) thay vì downstream.

---

## 3. `--from-scan` (Sprint 5 cross-skill)

OPTIONAL flag dành cho legacy projects. Skill load `feature-inventory.md` từ wf-scan-target session:

```bash
/wf-define-features --from-scan=20260515-100000-a1b2
```

Inject vào business-analyst agent context → BA SUGGEST features cho user review (suggest-only, user accept/reject từng cái).

**KHÔNG auto-import — chỉ suggestion.** Default behavior unchanged khi flag absent (zero regression).

---

## 4. Scope behavior

| Scope value | Phase coverage |
|-------------|---------------|
| `all` (default) | All systems + modules + Phase 2.7 (LEGACY only nếu có UI) |
| `[system-name]` | 1 system, all its modules |
| `[module-name]` | 1 module focused |

---

## 5. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--resume` + `scope` | Preserve original scope từ session-state |
| `--auto-stub-requirements` + `--resume` | Flag honored sau khi resume |
| `--from-scan` + `--auto-stub-requirements` | Cả 2 OK (independent) |
| `--status` + bất kỳ | Display only |

---

## 6. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| Registry | `test -f req-registry.json AND .requirements \| length > 0` | E001 |
| `--from-scan=<id>` | Session tồn tại với `feature-inventory.md` valid | (warning, không block) |
| `--auto-stub-requirements` | (no validation — just flag) | — |

---

## 7. Examples

```bash
# Default
/wf-define-features

# Single system
/wf-define-features SmartTax

# Legacy với scan suggestions
/wf-define-features --from-scan=20260515-100000-a1b2

# Auto-stub orphan REQ-IDs (escape hatch)
/wf-define-features --auto-stub-requirements

# Resume
/wf-define-features --resume

# Status
/wf-define-features --status
```

---

## 8. Liên kết

- Error codes: [05-error-codes.md](05-error-codes.md) §E020 referential integrity
- Cross-skill schema: [04-file-contract.md](04-file-contract.md) §consumes_from
- Phase 5 referential check: [`procedures/phase5-registry-update.md`](../../../.claude/skills/workflow/wf-define-features/procedures/phase5-registry-update.md) §5.3c
