# Sprint 4: Template + Schema Fixes

> **Estimate:** 1h
> **Phụ thuộc:** Không (độc lập)
> **Solves:** G5 (change-plan.md thiếu change_id), G6 (phase-summary.md template), G10 (status fields)
> **PR Group:** PR #2

---

## Mục tiêu

Fix template consistency — đảm bảo CORE-031 compliance và evals chạy đúng.

## Deliverables

### 4.1 change-plan.md: thêm change_id

Update `templates/change-plan.md` header table:

```markdown
| Field | Value |
|-------|-------|
| **Change ID** | {CHANGE_ID} |
| **Change Type** | {CHANGE_TYPE} |
| **Total Tasks** | {N} |
| **Risk Level** | {LEVEL} |
| **Estimated Complexity** | {LOW/MEDIUM/HIGH} |
```

### 4.2 phase-summary.md: tạo minimal template (MỚI)

Tạo `templates/phase-summary.md`:

```markdown
---
$schema: phase-summary-v1
change_id: {CHANGE_ID}
skill: wf-manage-change
---

# Tom tat thay doi — {CHANGE_ID}

## Da thay doi gi?
<!-- POPULATE: Mo ta cu the nhung gi da thay doi -->

## Tai sao can thay doi?
<!-- POPULATE: Copy tu user prompt -->

## Ket qua kiem tra
- Preflight: [PASS/WARN/FAIL]
- Traceability: [sync_rate %]
- Cross-validation: [coverage %]

## Nhung file bi anh huong
- [N] tai lieu cap nhat
- [N] file code cap nhat
- [N] test cap nhat

## Buoc tiep theo
<!-- POPULATE: Khuyen nghi cu the -->
```

Update `procedures/phase6-report.md` Step 6.2:
- TRƯỚC: "Tạo $SESSION_DIR/phase-summary.md — free-form"
- SAU: "READ template `templates/phase-summary.md` → POPULATE → WRITE"

### 4.3 change-status.json: thêm fields

Update `templates/change-status.json`:

Thêm các fields mới:

```json
{
  ...existing...,
  "phase2_retry_count": 0,
  "intake": {
    ...existing...,
    "deprecated_modules": [],
    "legacy_mode": false,
    "referenced_artifacts": {
      "systems": [],
      "modules": [],
      "features": [],
      "req_ids": []
    }
  }
}
```

### 4.4 change-intake.json: thêm field

Thêm `classification_rationale` vào `templates/change-intake.json`:

```json
{
  ...existing...,
  "classification_rationale": null
}
```

### 4.5 _contract.json: update template references

Update `_contract.json` outputs:

```json
{
  "path": "$SESSION_DIR/phase-summary.md",
  "template": "templates/phase-summary.md",  // Đổi từ null → template path
  "required": true
},
{
  "path": "$SESSION_DIR/change-impact.json",
  "template": "templates/change-impact.json",  // MỚI
  "required": true
}
```

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | change-plan.md template có field `Change ID` | `grep "Change ID" templates/change-plan.md` |
| AC2 | phase-summary.md template tồn tại, có 5 headings bắt buộc | `grep "^## " templates/phase-summary.md \| wc -l` → 5 |
| AC3 | change-status.json template có fields mới | `jq '.phase2_retry_count' templates/change-status.json` → `0` |
| AC4 | _contract.json phase-summary.md template != null | `jq '.outputs.working[] \| select(.path \| contains("phase-summary")) \| .template' _contract.json` |
| AC5 | Eval #14 assertion "change-status.json co phase2.retry_count >= 1" sẽ pass khi field tồn tại | Manual check |

## Risks

| Risk | Mitigation |
|------|------------|
| Phase 6 code hiện tại viết phase-summary.md free-form → cần update để READ template | Sprint 5 sẽ update Phase 6 code |
| change-status.json thêm fields → breaking change cho sessions cũ | Fields mới có default values (0, false, []) → additive, không breaking |

## Definition of Done

- [ ] change-plan.md template update (thêm change_id)
- [ ] phase-summary.md template tạo (minimal, 5 sections)
- [ ] change-status.json template update (3 fields mới)
- [ ] change-intake.json template update (classification_rationale)
- [ ] _contract.json update (2 template references)
- [ ] AC1-AC5 pass
