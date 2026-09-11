# Phase 3b: Account Management — Muc 9

> Viết Muc 9 (Account Management) vào `deployment-guide.md`.
> **SEQUENTIAL** — phải chạy sau Phase 2 + Phase 3a vì:
> - Ghi vào cùng file với Phase 2 (cần tránh write conflict)
> - Cần context từ user-guide.md (Phase 3a)

**PRE-GATE:**
- [ ] `test -s .mc-data/docs/phase6-deployment/deployment-guide.md` (Phase 2 DONE)
- [ ] `test -s .mc-data/docs/phase6-deployment/user-guide.md` (Phase 3a DONE)
- [ ] `$PROJECT_NAME` set

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | Context Muc 1-8 |
| Auth feature specs | `.mc-data/docs/phase2-features/[sys]/auth/*.md` | Login flow, password policy |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Muc 8.1 RBAC roles |
| Project overview | `.mc-data/docs/phase1-business/P1-01-project-overview.md` | Muc 5 actors |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Departments, roles |
| Template | `.claude/doc-framework/phase6-deployment/deployment-guide.md` | Muc 9 format |

**OUTPUT:** `.mc-data/docs/phase6-deployment/deployment-guide.md` — append Muc 9 (không ghi đè Muc 1-8).

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P3b-TECHWRITER
- `_shared.md` §Cross-File Write Conflict Avoidance

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3b.0 | **[SKIP-IF-EXISTS]** Grep `deployment-guide.md` — nếu đã chứa `"## 9\|## Muc 9\|## Quan ly tai khoan"` → SKIP Phase 3b, log `"Muc 9 da ton tai trong deployment-guide.md — skip."` | Skip flag set hoặc continue |
| 3b.1 | Đọc `deployment-guide.md` (tu Phase 2) + auth specs + P3-01 Muc 8.1 + P1-01 Muc 5 | Context loaded |
| 3b.2 | Spawn `tech-writer` agent với prompt P3b-TECHWRITER | Agent success |
| 3b.3 | Verify Muc 9 được append vào `deployment-guide.md` (KHÔNG ghi đè Muc 1-8) | Section 9 present |
| 3b.4 | Log agent vào `$AGENTS_SPAWNED` | Counter updated |

---

## §Agent Spawn (Step 3b.2)

**Prompt:** Xem `_shared.md §Agent Prompt Templates → P3b-TECHWRITER`.

**Tool instruction BẮT BUỘC:** Agent phải dùng `Edit` tool (append) thay vì `Write` (ghi đè) để preserve Muc 1-8.

**Agent hướng dẫn đặc biệt:**
```
WARNING: deployment-guide.md da chua Muc 1-8 tu Phase 2.
Ban PHAI dung Edit tool de APPEND Muc 9 vao cuoi file,
KHONG dung Write (se ghi de mat Muc 1-8).

Dung pattern:
  old_string: [last 2-3 lines hien tai cua file]
  new_string: [last 2-3 lines] + "\n\n## 9. Quan ly tai khoan\n\n[noi dung Muc 9]"
```

---

## POST-GATE

- [ ] `test -s deployment-guide.md` (file vẫn non-empty)
- [ ] **[Protocol 10 — T2]** Muc 9 present:
  ```bash
  grep -qE "^## (9\.|Muc 9|Quan ly tai khoan|Account Management)" deployment-guide.md
  ```
- [ ] Muc 1-8 vẫn còn nguyên (không bị ghi đè):
  ```bash
  grep -cE "^## (Muc |)[1-8][\.\b]" deployment-guide.md >= 8
  ```
- [ ] Muc 9 có >= 500 từ:
  ```bash
  awk '/^## 9/,/^## 10|^$/' deployment-guide.md | wc -w >= 500
  ```
- [ ] Nếu Muc 1-8 bị mất → ROLLBACK (restore từ checkpoint hoặc re-run Phase 2)
- [ ] Nếu Muc 9 thiếu nội dung → re-run agent (max 3 retries)

**Next phase:** `phase3c-checkpoint.md`

---

## Auto-Correction / Rollback

**Trường hợp CRITICAL — Muc 1-8 bị ghi đè:**
1. Log error: `{type: "write_conflict", phase: "3b", severity: "critical"}`
2. Check `.mc-data/work/wf-prepare-deployment/checkpoint.json` — nếu có backup của deployment-guide.md → restore
3. Nếu không có backup → re-run Phase 2 từ đầu, sau đó chạy lại Phase 3b với Edit-only instruction
4. Sau 3 lần thất bại → E009, escalate

**Trường hợp Muc 9 thiếu nội dung:**
- Tương tự Phase 2 auto-correction (3 iterations với instruction bổ sung)

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E005 | Agent timeout | Retry ×3, escalate |
| E009 | POST-GATE fail sau 3 retries | STOP phase, escalate |
| **E012** | **Muc 1-8 bị ghi đè** | **ROLLBACK, re-run Phase 2 + 3b** |
