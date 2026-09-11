# Phase 3 — Dry-Run Preview

> **Self-contained phase file.** Hiển thị diff preview cho user REVIEW trước khi apply.
> BẮT BUỘC chạy — kể cả không có `--dry-run` flag, dry-run vẫn tạo và hiển thị để user confirm.

---

## PRE-GATE

- `scope-spec.json` non-empty (ít nhất có 1 module OR 1 feature để add)
- Phase 1 (và Phase 2 nếu LEGACY) đã POST-GATE PASS

**Warning path E006:**

```
IF modules_to_add.length == 0 AND features_to_add.length == 0:
  WARNING E006: "All modules đã tồn tại. Nothing to do."
  → Jump to phase6-report.md với empty summary
  EXIT skill cleanly
```

---

## 📥 INPUT

- `$SESSION_DIR/scope-spec.json`
- `.mc-data/docs/_meta/req-registry.json` (current state — cho before/after counts)

---

## 📤 OUTPUT

| File | Template |
|---|---|
| `$SESSION_DIR/dry-run-diff.md` | — (generate inline — no template) |

---

## Steps

### Step 3.1 — Build diff markdown

**Sections bắt buộc:**

1. **Header** — system target + summary counts
2. **Will ADD** — modules + features to be added
3. **Will SKIP** — existing conflicts + deprecated
4. **Registry Impact** — before/after counts
5. **Next Actions Sau Apply**

**Format template (inline generation):**

```markdown
# Add-Scope Dry-Run Diff — $SYSTEM_ID

## Will ADD ([N] modules + ~[M] features)

### Modules ([N] mới)

| ID | Name | Depends On | Code Refs |
|----|------|-----------|-----------|
| MOD-ERPWEB-CRM | ERP Web — CRM UI | MOD-BACKEND-CRM | apps/erp-web/.../crm/ |
| ... | ... | ... | ... |

### Features (sample 5 đầu — tổng [M])

| FEAT-ID | Name | Module | Req IDs inherited |
|---------|------|--------|-------------------|
| FEAT-ERPWEB-CRM-001 | Quản lý Hoạt động CRM (UI) | MOD-ERPWEB-CRM | REQ-SALES-001, REQ-SALES-002 |
| ... | ... | ... | ... |

## Will SKIP (already exist OR deprecated)

| Entry ID | Entry Type | Reason | Action |
|----------|------------|--------|--------|
| MOD-XYZ | module | Already exists in registry | skip |
| MOD-ABC | module | Marked DEPRECATED per legacy-decisions.json | skip |

## Registry Impact

- Systems: [count] → [count] (unchanged)
- Current modules:  [before] → [after] (+[added])
- Current features: [before] → [after] (+[added])
- No existing entries modified or deleted

## Next Actions Sau Apply

1. Review `phase2-features/[sys-slug]/**/*.md` stubs (flagged `[STUB]`)
2. Tùy chọn: chạy `/wf-define-features $SYSTEM_ID` để flesh-out feature specs
3. Chạy `/wf-plan-modules` để regenerate Phase 5 planning
```

---

### Step 3.2 — Write + Display

```
WRITE $SESSION_DIR/dry-run-diff.md
DISPLAY nội dung đầy đủ cho user (không truncate)
```

**Verify:** File non-empty, có đủ 5 sections.

---

### Step 3.3 — Confirm or Stop

```
IF $DRY_RUN == true:
  UPDATE add-scope-status.json:
    phase_3.diff_generated = true
    phase_3.status         = "completed"
    phase_4.status         = "pending (--dry-run — user review required)"
  → Jump to phase6-report.md (in report tóm tắt dry-run, không apply registry)
  EXIT skill

ELSE:
  AskUserQuestion: "Xác nhận apply changes? (Y/N)"
  IF user denies (N):
    LOG: "User denied apply. Registry KHÔNG modified."
    UPDATE add-scope-status.json:
      phase_3.diff_generated = true
      phase_4.status         = "cancelled by user"
    → Jump to phase6-report.md (report cancellation)
    EXIT skill

  IF user accepts (Y):
    UPDATE add-scope-status.json: phase_3.status = "completed"
    CONTINUE to phase4-append.md
```

---

## CDG Gate (Critical Decision Gate — CORE-027)

> **LƯU Ý:** Registry modification là irreversible action (dù có backup) — đây là CDG point.
> User confirmation ở Step 3.3 là CDG-required gate trước Phase 4.

Backup được tạo ở Phase 4.1 — user có thể rollback qua path trong Phase 6 report.

---

## POST-GATE

- `dry-run-diff.md` tồn tại, non-empty, có đủ sections
- User đã review (displayed)
- Decision tracking: `$DRY_RUN` → STOP, user `Y` → continue, user `N` → cancel
- `add-scope-status.json.phases.phase_3.status` = `"completed"`

---

## Next Phase

- **IF `$DRY_RUN == true` OR user denied:** → Jump `phase6-report.md` (cancellation report)
- **IF user accepted:** → Load `phase4-append.md`
