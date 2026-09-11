# Phase 4: Maintenance Guide — Muc 10

> Viết Muc 10 (Maintenance) vào `deployment-guide.md`.
> **SEQUENTIAL** — chạy sau Phase 3c (checkpoint đã save).

**PRE-GATE:**
- [ ] `test -s .mc-data/docs/phase6-deployment/deployment-guide.md`
- [ ] Muc 9 đã có (Phase 3b DONE)
- [ ] Checkpoint đã save (Phase 3c DONE — implicit nếu skill không STOP)

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | Context Muc 1-9 |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Kiến trúc cần bảo trì |
| Infra spec | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Backup, monitoring |
| Template | `.claude/doc-framework/phase6-deployment/deployment-guide.md` | Muc 10 format |

**OUTPUT:** `.mc-data/docs/phase6-deployment/deployment-guide.md` — append Muc 10.

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P4-DEVOPS+TECHWRITER
- `_shared.md` §Token Limit Prevention
- `_shared.md` §Cross-File Write Conflict Avoidance

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.0 | **[SKIP-IF-EXISTS]** Grep `deployment-guide.md` — nếu đã chứa `"## 10\|## Muc 10\|## Bao tri"` → SKIP Phase 4, log | Skip flag set hoặc continue |
| 4.1 | Đọc `deployment-guide.md` (Muc 1-9) tập trung vào Muc 7 (Monitoring) để context Muc 10 | Context loaded |
| 4.1b | Nếu `$CONTEXT_PERCENT >= 80%` (từ Phase 3c): spawn **1 agent duy nhất** (devops only, không spawn tech-writer) | Parallel mode decided |
| 4.2 | Spawn `devops` + `tech-writer` agents (hoặc chỉ `devops` nếu context cao) với prompt P4-DEVOPS+TECHWRITER | Agents success |
| 4.3 | Verify Muc 10 được append vào `deployment-guide.md` | Section 10 present |
| 4.4 | **LPM CHECKPOINT** — Nếu `$LARGE_PROJECT=true`: SAVE CHECKPOINT sau Phase 4 | Checkpoint saved |

---

## §Agent Spawn (Step 4.2)

**Prompt:** Xem `_shared.md §Agent Prompt Templates → P4-DEVOPS+TECHWRITER`.

**Tool instruction:** Tương tự Phase 3b — agent PHẢI dùng `Edit` (append) thay vì `Write` để preserve Muc 1-9.

**Single-agent fallback (khi context cao):**
```
IF $CONTEXT_PERCENT >= 80%:
  Spawn CHỈ `devops` agent (bỏ tech-writer)
  Prompt: sử dụng cùng P4-DEVOPS+TECHWRITER nhưng ghi "Ban la devops..." thay vì "devops + tech-writer"
  Lưu ý: Tốc độ nhanh hơn nhưng có thể ngôn ngữ technical hơn (thiếu tech-writer polish)
```

---

## POST-GATE

- [ ] `test -s deployment-guide.md` (file vẫn non-empty)
- [ ] **[Protocol 10 — T2]** Muc 10 present:
  ```bash
  grep -qE "^## (10\.|Muc 10|Bao tri|Maintenance)" deployment-guide.md
  ```
- [ ] Muc 1-9 vẫn còn nguyên:
  ```bash
  grep -cE "^## (Muc |)[1-9][\.\b]|^## 9[\.\b]" deployment-guide.md >= 9
  ```
- [ ] Muc 10 có >= 800 từ:
  ```bash
  awk '/^## 10/,EOF' deployment-guide.md | wc -w >= 800
  ```
- [ ] Nếu Muc 1-9 bị mất → ROLLBACK (restore từ checkpoint Phase 3c)
- [ ] Nếu Muc 10 thiếu nội dung → re-run agent (max 3 retries)

**Next phase:** `phase4a-runbook.md`

---

## Error Codes

Kế thừa từ `phase3b-account-mgmt.md`:
- E005: Agent timeout
- E009: POST-GATE fail sau 3 retries
- E012: Muc 1-9 bị ghi đè → ROLLBACK

---

## Auto-Correction

Iteration 1-3: re-run với instruction bổ sung về Muc 10 sections thiếu.
Sau 3 lần → E009, escalate.
