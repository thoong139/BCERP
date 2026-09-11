# Phase 7: Report & Handoff

> Tong ket toan bo qua trinh migration. Tao migrate-report.md + phase-summary.md + rollback-guide.md.
> **v1.1:** Cross-validation truoc khi tao report + rollback guide generation.
> Hien thi output report cho user. Handoff sang buoc tiep theo.

> **Shared:** Xem `procedures/_shared.md` — CORE-026/028, Rollback Protocol, Session Isolation, Cross-Validation Protocol.

---

## PRE-GATE

```bash
test -f $SESSION_DIR/strategy-matrix.md
test -f $SESSION_DIR/gap-analysis.md
test -f $SESSION_DIR/entity-mapping.md
test -f .mc-data/docs/_meta/req-registry.json
```

---

## INPUT

| File | Mo ta |
|------|-------|
| Tat ca output tu Phase 1-6 | Strategy, entity mapping, registry, code, task plan |
| `$IMPLEMENT_RESULTS` | Ket qua implement tu Phase 6 |
| `$AUTO_ROLLBACK` | True neu --auto-rollback duoc pass |
| `$AUTO_ROLLBACK_TRIGGERED` | True neu auto-rollback da duoc kich hoat trong Phase 6 |
| `$ROLLBACK_SNAPSHOTS[]` | Danh sach snapshot da luu |
| Parity reports | `$SESSION_DIR/parity-check-*.md` |
| `error_log[]` | Tat ca errors/warnings trong qua trinh (structured format) |

---

## OUTPUT

| File | Template | Mo ta |
|------|----------|-------|
| `$SESSION_DIR/migrate-report.md` | `templates/migrate-report.md` | Bao cao tong ket — da lam gi, ket qua, next steps |
| `$SESSION_DIR/phase-summary.md` | `templates/phase-summary.md` | Tom tat tieng Viet cho non-specialist (CORE-028) |
| `$SESSION_DIR/rollback-guide.md` | `templates/rollback-guide.md` | **NEW v1.1** — Huong dan rollback neu can |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 7.0 | **Cross-Validation (NEW v1.1):** Kiem tra tinh nhat quan giua cac phase TRUOC khi tao report. Xem `_shared.md` §Cross-Validation Protocol. (a) Entity mapping vs code — doc entity-mapping.md + tim actual entity classes trong code → verify khop. (b) Feature specs vs implementation — doc registry features[] co impl_status=done → verify spec files ton tai → verify code files co REQ-ID. (c) Strategy vs parity — features Keep phai co parity-check-*.md. (d) Registry vs git — kiem tra khong co orphan files (code khong co REQ-ID trong registry). (e) Snapshot integrity — verify tat ca $ROLLBACK_SNAPSHOTS[] file con ton tai. Neu mismatch → WARNING + ghi error_log. Neu CRITICAL mismatch (>3) → STOP + hoi user. | Read/Grep/Glob | Cross-validation PASS/FAIL |
| 7.1 | **Tong hop ket qua:** Gom tat ca data tu cac phase: strategy decisions, registry changes, design, tasks, implement results, parity check results, CI analysis results, auto-approve log. | Read | Data gathered |
| 7.2 | **Tao migrate-report.md:** Doc `templates/migrate-report.md` → POPULATE voi du lieu tong hop → WRITE `$SESSION_DIR/migrate-report.md`. Bao gom: tom tat module cu → moi, so features migrated, strategy summary, entity mapping summary, implement results, parity check results (tong hop tu cac parity-check-*.md), rollback snapshots list, error_log (neu co), next steps. | Read/Write | Report created |
| 7.3 | **Tao phase-summary.md (CORE-028):** Doc `templates/phase-summary.md` → POPULATE bang tieng Viet don gian → WRITE `$SESSION_DIR/phase-summary.md`. Ngon ngu: cho nguoi khong chuyen, giai thich ro da lam gi, ket qua the nao. | Read/Write | Summary created |
| 7.4 | **Tao rollback-guide.md (NEW v1.1):** Doc `templates/rollback-guide.md` → POPULATE tu `$ROLLBACK_SNAPSHOTS[]` → WRITE `$SESSION_DIR/rollback-guide.md`. Liet ke tat ca snapshot, huong dan khoi phuc registry + code + design docs. | Read/Write | Rollback guide created |
| 7.5 | **Cap nhat index.json:** Cap nhat `index.json` — set session status="completed", completed_at=now. | Write | Index updated |
| 7.6 | **CORE-026 COMPLETE trace:** Append COMPLETE entry vao `.mc-data/work/_trace/session-log.json`. | Write | Trace logged |
| 7.7 | **Hien thi Output Report:** Hien thi bang tom tat cho user (theo template trong SKILL.md §Output Report). Neu co parity FAIL → highlight. Neu `$AUTO_APPROVE == true` → note ro cac CDG da duoc auto-approve. | — | User informed |

---

## POST-GATE (T1-T4)

**T1 — Existence:**
```bash
test -f $SESSION_DIR/migrate-report.md
test -f $SESSION_DIR/phase-summary.md
test -f $SESSION_DIR/rollback-guide.md
test -f $SESSION_DIR/gap-analysis.md
test -f $SESSION_DIR/strategy-matrix.md
test -f $SESSION_DIR/entity-mapping.md
# Kiem tra parity reports neu co feature Keep
ls $SESSION_DIR/parity-check-*.md 2>/dev/null
# Kiem tra rollback snapshots
ls $SESSION_DIR/snapshots/ 2>/dev/null
```

**T2 — Structure:** Moi file co cau truc dung nhu template.

**T3 — Content:** Moi file co noi dung y nghia (khong rong, khong placeholder).

**T4 — Cross-reference:**
- Strategy matrix khop gap analysis
- Entity mapping khop strategy matrix
- Entity mapping khop actual code entities (Cross-Validation a)
- Feature specs khop implementation (Cross-Validation b)
- Registry features[] impl_status phan anh dung thuc te
- Migrate report phan anh dung ket qua implement + parity
- Rollback guide khop snapshot thuc te trong `$SESSION_DIR/snapshots/`
- KHONG co orphan code files khong co REQ-ID (Cross-Validation d)

---

## Next Step

```
→ /status — kiem tra tien do du an
→ /wf-preflight — kiem tra chat luong code
→ /wf-verify-sync — dong bo registry voi code thuc te
```

---

## Cleanup

Sau khi POST-GATE PASS, skill hoan tat. KHONG xoa session dir — giu lai cho audit trail.
