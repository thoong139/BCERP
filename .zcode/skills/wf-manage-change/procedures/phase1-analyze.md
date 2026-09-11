# Phase 1: Analyze

> Phân tích yêu cầu với chuyên gia (DEEP) hoặc trực tiếp (QUICK).
> Mục tiêu: hiểu rõ ý người dùng, xác định chính xác cần thay đổi gì.

> **Shared:** Xem `procedures/_shared.md` — Expert Selection Map, Agent Prompt Templates, Fix Rules.

---

## PRE-GATE

- Phase 0 đã PASSED
- `$SESSION_DIR/change-intake.json` tồn tại và non-empty
- `$CHANGE_TYPE` đã được set (preliminary, có thể UNCLEAR)
- `$ANALYSIS_MODE` đã được set (`quick` hoặc `deep`)

---

## INPUT

- `$SESSION_DIR/change-intake.json` — parsed prompt + classification
- `.mc-data/docs/_meta/req-registry.json` — registry
- Docs tương ứng với `$REFERENCED_ARTIFACTS` (phase1/phase2/phase3 docs)

---

## OUTPUT

| File | Template |
|------|----------|
| `$SESSION_DIR/change-analysis.md` | `templates/change-analysis.md` |
| `$SESSION_DIR/affected-artifacts.json` | `templates/affected-artifacts.json` |

---

## QUICK Mode

Sử dụng khi thay đổi rõ ràng, ảnh hưởng ≤ 1 artifact, không cần chuyên gia.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Phân tích trực tiếp: đọc registry + referenced docs | Read | Context loaded |
| 1.2 | Xác định affected artifacts — docs + code files | Grep | Artifacts found |
| 1.3 | Brainstorm với user qua AskUserQuestion — hỏi làm rõ các điểm chưa rõ | AskUserQuestion | Clarified |
| 1.4 | Chốt scope: xác nhận với user phạm vi thay đổi | AskUserQuestion | Confirmed |
| 1.5 | **Tạo output files:** READ template `templates/change-analysis.md` → POPULATE analysis → WRITE `$SESSION_DIR/change-analysis.md`. READ template `templates/affected-artifacts.json` → POPULATE artifacts → WRITE `$SESSION_DIR/affected-artifacts.json` | Write | Files created |

---

## DEEP Mode

Sử dụng khi thay đổi phức tạp, cross-system, hoặc cần nhiều domain expertise.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Đọc registry + referenced docs → build context digest | Read | Context loaded |
| 1.2 | **Determine relevant experts** từ `$REFERENCED_ARTIFACTS`: map departments → expert agents (xem `_shared.md` §Expert Selection Map) | — | Experts determined |
| 1.3 | **[PAR] Spawn experts (max 3 đồng thời):** Mỗi expert phân tích từ góc nhìn domain. Luôn include `architect` để đánh giá technical impact. | Agent | Analyses received |
| 1.4 | **Aggregate** expert analyses → tổng hợp góp ý | — | Aggregated |
| 1.4b | **CORE-029 Agent Output Spot-Check** (xem §Spot-Check Protocol dưới) | — | Spot-check done |
| 1.5 | **Brainstorm với user:** Present phân tích, hỏi làm rõ, chốt giải pháp | AskUserQuestion | Scope confirmed |
| 1.6 | **Tạo output files:** READ template `templates/change-analysis.md` → POPULATE → WRITE. READ template `templates/affected-artifacts.json` → POPULATE → WRITE | Write | Files created |

---

## CORE-029 Agent Output Spot-Check (DEEP mode Step 1.4b)

Trước khi ghi `change-analysis.md`, verify từng expert response.

**Checks:**

1. Phần phân tích domain **không rỗng**, không phải placeholder text
2. Có ít nhất 1 **risk** hoặc **recommendation** được identify
3. Nội dung **liên quan đến domain** của expert đó

**Status handling:**

| Status | Hành động |
|--------|-----------|
| `DONE` | Dùng response bình thường |
| `DONE_WITH_CONCERNS` (thiếu một phần nhỏ) | Log warning + ghi chú trong section tương ứng, tiếp tục |
| `BLOCKED` (response hoàn toàn rỗng hoặc không liên quan) | SKIP expert đó + WARNING |

**Edge case:** Nếu **TẤT CẢ experts BLOCKED** → STOP, hỏi user có muốn chuyển sang QUICK mode.

---

## Change Type Confirmation

Sau khi brainstorm với user (Step 1.3/1.5), UPDATE `$CHANGE_TYPE` từ preliminary → confirmed trong `change-intake.json`:

```
intake.change_type_confirmed = $CHANGE_TYPE
intake.confirmed_at = NOW
```

Nếu user chỉnh change type (VD: từ UNCLEAR → MODIFY_FEATURE) — ghi lại lịch sử trong `intake.classification_history[]`.

---

## `affected-artifacts.json` Schema (tóm tắt)

```json
{
  "change_id": "CHG-YYYYMMDD-NNN",
  "docs_affected": [
    {"path": ".mc-data/docs/phase2-features/[sys]/[mod]/[feat].md", "reason": "...", "priority": "HIGH|MEDIUM|LOW"}
  ],
  "code_affected": [
    {"path": "src/...", "type": "controller|service|repository|...", "reason": "..."}
  ],
  "tests_affected": [
    {"path": "tests/...", "reason": "..."}
  ],
  "registry_changes": {
    "requirements": ["REQ-..."],
    "features": ["FEAT-..."],
    "impl_status_updates": {}
  },
  "cross_systems": ["SYS-..."]
}
```

Full schema: xem `templates/affected-artifacts.json`.

---

## POST-GATE

- `$SESSION_DIR/change-analysis.md` tồn tại, non-empty
- `$SESSION_DIR/affected-artifacts.json` tồn tại, **với điều kiện sau (GAP-5 fix):**
  ```
  IF $CHANGE_TYPE == "CLARIFY_REQ":
    → docs_affected VÀ code_affected ĐƯỢC PHÉP đều rỗng
      (CLARIFY_REQ thuần túy chỉ update registry notes/description — không cần docs/code)
    → Nhưng BẮT BUỘC phải có: registry_changes.requirements non-empty (có ít nhất 1 REQ-ID được clarify)
  ELSE:
    → docs_affected HOẶC code_affected phải non-empty
  ```
- User đã confirm scope thay đổi
- `intake.change_type_confirmed != null`

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-analysis.md \
  --type=markdown \
  --headings="## Change Type,## Confirmed Scope,## Proposed Solution"
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/affected-artifacts.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase1.status = "completed"` → tiếp tục `procedures/phase2-impact.md`.
