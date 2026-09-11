# wf-fix-bugs v6.x → v7.0+ Migration Guide

> **Ap dng:** Moi du an da dung wf-fix-bugs v6.x (legacy `run-NNN-*` layout)
> **v7.1 update:** Soft warn → BLOCK voi CDG override (V71-D02)
> **v7.2 preview:** Remove hoan toan legacy support

---

## TL;DR

1 lenh:

```bash
bash .claude/scripts/wf-fix-migrate-sessions.sh --apply
```

Done. Skip xuong [§4 Edge cases](#4-edge-cases) neu gap issue.

---

## 1. Pre-migration checklist

### 1.1 Backup recommended

Mac dinh archive intact tai: `.mc-data/work/wf-fix-bugs/_archive/{YYYY-MM}/migration-backup/`

Neu can backup them:

```bash
tar -czf wf-fix-bugs-pre-migration-$(date +%Y%m%d).tar.gz .mc-data/work/wf-fix-bugs/
```

### 1.2 Lock check

Kiem tra khong co active sessions:

```bash
bash .claude/scripts/wf-fix-session.sh list
```

Neu co session dang `locked` → doi xong hoac force release:

```bash
bash .claude/scripts/wf-fix-session.sh release <session_id>
```

### 1.3 Disk space

Migration can khoang 2× dung luong hien tai (archive + new layout):

```bash
du -sh .mc-data/work/wf-fix-bugs/
```

---

## 2. Workflow: Dry-run → Apply

### 2.1 Script modes

| Mode | Lenh | Muc dich |
|------|------|----------|
| dry-run | `--dry-run` (default) | Preview changes, khong modify |
| apply | `--apply` | Execute migration that + archive legacy |
| status | `--status` | Hien thi current state (legacy count, new count) |
| base-dir | `--base-dir=<path>` | Override default base dir |

### 2.2 Recommended workflow

```bash
# Buoc 1: Status — kiem tra so luong legacy sessions
bash .claude/scripts/wf-fix-migrate-sessions.sh --status

# Buoc 2: Dry-run — xem truoc nhung gi se thay doi
bash .claude/scripts/wf-fix-migrate-sessions.sh --dry-run

# Buoc 3: Apply — chay migration that
bash .claude/scripts/wf-fix-migrate-sessions.sh --apply

# Buoc 4: Verify — kiem tra ket qua
bash .claude/scripts/wf-fix-migrate-sessions.sh --status
# Expect: legacy_count = 0, new_sessions_count = N
```

### 2.3 Idempotency guarantee

- Chay `--apply` nhieu lan deu safe
- Skip neu session da migrate (target dir ton tai)
- Chi migrate sessions con legacy layout

### 2.4 Exit codes

| Code | Nghia |
|------|-------|
| 0 | Thanh cong (hoac dry-run) |
| 1 | Loi args / base-dir khong ton tai |
| 2 | Partial migration (mot so session fail nhung khong mat du lieu) |
| 3 | Critical error (data loss prevented — can thao tac thu cong) |

---

## 3. Rollback strategy

### 3.1 Archive intact tai

```
.mc-data/work/wf-fix-bugs/_archive/{YYYY-MM}/migration-backup/
├── run-001--20260415/          ← original legacy session (v6.0 pattern)
├── run-002-module-auth--20260416/  ← original legacy session (v6.1+ pattern)
└── ...
```

Script archive bang `mv` (move, khong delete) — legacy dirs van nguyen ven trong `_archive/`.

### 3.2 Manual restore

```bash
# Restore 1 session cu the
ARCHIVE_DIR=".mc-data/work/wf-fix-bugs/_archive/2026-04/migration-backup/run-001--20260415"
mv "$ARCHIVE_DIR" .mc-data/work/wf-fix-bugs/

# Restore toan bo (full rollback)
cp -r .mc-data/work/wf-fix-bugs/_archive/2026-04/migration-backup/* .mc-data/work/wf-fix-bugs/
```

### 3.3 Khi rollback kho khan

- Sessions da duoc modify sau migration → rollback se overwrite thay doi
- Khuyen nghi: restore vao dir tam truoc, manual diff, roi moi ghi de

---

## 4. Edge cases

### 4.1 Nested legacy layout (v6.1+ scope-aware)

**Pattern:** `sessions/{scope}/run-NNN-{scope}-{name}--YYYYMMDD/`

Script handle tu dong qua `find -maxdepth 2` trong `sessions/` — khong can action thu cong. Sau khi migrate, empty parent scope dirs duoc auto-cleanup.

### 4.2 Legacy patterns khong nhan dien

Script chi nhan dien 2 pattern:
- `run-NNN--YYYYMMDD` (v6.0)
- `run-NNN-{scope}-{name}--YYYYMMDD` (v6.1+)

Cac pattern khac (vd `run-001-custom-name` khong co `--YYYYMMDD`) bi skip voi warning. Can xu ly thu cong.

### 4.3 File count mismatch

Script verify so luong file truoc khi archive legacy. Neu mismatch → session bi bo qua (data giu nguyen o ca 2 ben). Kiem tra log de tim nguyen nhan.

### 4.4 Cross-host concerns

- Lock heartbeat dua tren file mtime (single host)
- Multi-host (NFS shared): co the co race window — khuyen nghi KHONG migrate tren NFS shared trong khi co active session

### 4.5 Permissions

Script can write access vao `.mc-data/work/wf-fix-bugs/`:

```bash
chmod -R u+w .mc-data/work/wf-fix-bugs/
```

### 4.6 Windows (Git Bash)

Script tuong thich Git Bash. Neu gap loi `stat` hoac `find` — dam bao Git Bash version >= 4.0.

---

## 5. Worked examples

### 5.1 Full migration

```bash
# Trang thai ban dau
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --status
=== wf-fix-bugs Migration Status (v6.x → v7.0) ===
Base dir: .mc-data/work/wf-fix-bugs

Legacy sessions (run-*):
  Recognized (migratable): 5
  Unrecognized pattern:    0

New sessions (sessions/{id}/): 0

Status: ⚠ MIGRATION NEEDED

# Dry-run preview
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --dry-run
=== wf-fix-bugs Migration (dry-run) ===
  PLAN: run-001--20260415 → sessions/2026-04-15-all-01/
  PLAN: run-002-module-auth--20260416 → sessions/2026-04-16-module-auth-02/
  PLAN: run-003-all-payment--20260417 → sessions/2026-04-17-all-payment-03/
  ...
Summary:
  Total legacy dirs found:    5
  To migrate:                 5
  Skip (already migrated):    0
  Skip (unrecognized):        0

DRY-RUN: no changes made. Run with --apply to commit.

# Apply
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --apply
  Migrating: run-001--20260415 → sessions/2026-04-15-all-01/
    OK
  Migrating: run-002-module-auth--20260416 → sessions/2026-04-16-module-auth-02/
    OK
  ...
Migration complete:
  Migrated successfully:  5 / 5
  Failed:                 0

Run --status to verify.

# Verify
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --status
Status: ✓ NO LEGACY SESSIONS — migration not needed.
```

### 5.2 Re-run (idempotent)

```bash
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --apply
=== wf-fix-bugs Migration (apply) ===
  SKIP already migrated: run-001--20260415 → sessions/2026-04-15-all-01/
  ...
Summary:
  To migrate:                 0

Nothing to migrate. ✓
```

### 5.3 Partial failure

```bash
$ bash .claude/scripts/wf-fix-migrate-sessions.sh --apply
  Migrating: run-001--20260415 → sessions/2026-04-15-all-01/
    OK
  Migrating: run-002--20260416 → sessions/2026-04-16-all-02/
    ERROR: file count mismatch (legacy=12, target=10)
  ...
Migration complete:
  Migrated successfully:  4 / 5
  Failed:                 1

Failures (data preserved at target where possible):
  - run-002--20260416: file count mismatch (12 vs 10)
```

Exit code 2 (partial). Session fail giu nguyen o vi tri cu — khong mat du lieu.

---

## 6. FAQ

### Q1: Co the skip migration khong?

| Version | Behavior |
|---------|----------|
| **v7.0** | Co (soft warn) |
| **v7.1** | **KHONG** — BLOCK voi CDG. 3 choices: `migrate_now` (auto-invoke script), `force_continue` (1-shot bypass), `abort` |
| **v7.2** | Se remove hoan toan — bat buoc migrate |

### Q2: Migration anh huong hieu suat khong?

- ~0.3s/session (cp + verify + mv)
- 100 sessions ≈ 30 giay
- Khong anh huong runtime sau migration

### Q3: CI/CD integration

**Option A — Escape hatch (quick bypass):**

```yaml
# .github/workflows/ci.yml
env:
  MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK: "1"  # Bypass BLOCK trong CI
```

**Option B — Chay migration truoc (recommended):**

```yaml
- name: Migrate wf-fix-bugs sessions
  run: bash .claude/scripts/wf-fix-migrate-sessions.sh --apply
```

### Q4: Sao toi khong thay migration script?

- Path: `.claude/scripts/wf-fix-migrate-sessions.sh`
- Yeu cau: bash >= 4, jq, coreutils (find, stat)
- Neu thieu: re-clone repo hoac upgrade DEVKIT len v7.0+

### Q5: Schema legacy co khac new sessions?

- **Legacy:** `run-NNN--YYYYMMDD/` hoac `run-NNN-{scope}-{name}--YYYYMMDD/` (flat hoac nested)
- **New:** `sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/` (namespaced + dated)
- **Noi dung file COMPATIBLE** — script chi rename + reorganize, khong transform

### Q6: CDG "force_continue" la gi?

Trong v7.1, khi phat hien legacy paths, SKILL.md render Critical Decision Gate voi 3 lua chon:

1. **migrate_now** — auto-invoke script `--apply`, sau do tiep tuc
2. **force_continue** — 1-shot bypass, legacy paths van visible, khong migrate
3. **abort** — dung lai voi exit code 78 (`E_LEGACY_BLOCK`)

Lua chon nay chi xuat hien khi chay `/wf-fix-bugs` truc tiep (khong anh huong sub-skills).

---

## Cross-references

- **SKILL.md current:** `.claude/skills/workflow/wf-fix-bugs/SKILL.md` (v7.1.0+)
- **Migration script:** `.claude/scripts/wf-fix-migrate-sessions.sh`
- **Session CLI:** `.claude/scripts/wf-fix-session.sh`
- **D1 roadmap:** v7.0 dual → v7.1 deprecate → v7.2 remove
- **V71-D02 BLOCK behavior:** SKILL.md Phase 0 step 2a
- **Env var escape hatch:** `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1`
