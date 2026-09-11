# Phase 0: Flag Handlers

> Xử lý các flags `--status`, `--resume` TRƯỚC khi vào main flow.
> File này được đọc CHỈ KHI SKILL.md detect có flag tương ứng trong `$ARGUMENTS`.

**PRE-GATE:** Không có (Phase 0 là entry point).

**OUTPUT:** Terminate (`--status`) hoặc set `$RESUME_MODE` + jump đến phase tiếp theo.

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Resume Logic (bên trong §Checkpoint Protocol)

---

## `--status` Handler

| Step | Action | Verify |
|------|--------|--------|
| S.1 | Scan `.mc-data/docs/phase6-deployment/` — đếm files đã tạo (4 files expected) | `actual_count` set |
| S.2 | Check `test -f deployment-guide.md && test -s` | Phase 2 status |
| S.3 | Check `test -f user-guide.md && test -s` | Phase 3a status |
| S.4 | Check `test -f incident-response-runbook.md && test -s` | Phase 4a status |
| S.5 | Check `test -f stakeholder-review.md && test -s` | Phase 5a status |
| S.6 | Đọc `.mc-data/work/wf-prepare-deployment/prepare-deployment-status.json` nếu tồn tại | `status_data` loaded |
| S.7 | Hiển thị report (xem §Status Report Format) | User sees report |
| S.8 | **STOP** — không thực thi thêm | Skill terminates |

### Status Report Format

```
## /wf-prepare-deployment — Tien do hien tai

| File | Path | Status |
|------|------|--------|
| deployment-guide.md | phase6-deployment/ | OK / MISSING |
| user-guide.md | phase6-deployment/ | OK / MISSING |
| incident-response-runbook.md | phase6-deployment/ | OK / MISSING |
| stakeholder-review.md | phase6-deployment/ | OK / MISSING |

**Files tren disk:** [N]/4
**Current phase (tu status.json):** [phase_name]
**Started at:** [started_at]
**Last updated:** [last_updated]

[Neu actual_count != status_data.metrics.docs_created:]
(checkpoint chua dong bo — chay --resume de cap nhat)

**Next action:**
- Neu N < 4 → chay `/wf-prepare-deployment` hoac `--resume` de hoan thanh
- Neu N == 4 → Da xong. Chay `/status` de xem tong quan du an.
```

---

## `--resume` Handler

| Step | Action | Verify |
|------|--------|--------|
| R.1 | Đọc `.mc-data/work/wf-prepare-deployment/prepare-deployment-status.json` | `status_data` loaded |
| R.2 | Đọc `.mc-data/work/wf-prepare-deployment/checkpoint.json` nếu tồn tại | `checkpoint_data` loaded |
| R.2a | **Context Digest Injection (Protocol 3.4):** Nếu checkpoint có `context_digest` → inject vào context: docs đã tạo, deployment decisions, key architecture context, gotchas. Nếu checkpoint cũ không có `context_digest` → skip (backward compatible) | Digest injected |
| R.3 | **RESUME RECONCILIATION** — Scan `.mc-data/docs/phase6-deployment/` (xem §Reconciliation Logic) | `next_phase` set |
| R.4 | Set `$RESUME_MODE = true` | Variable set |
| R.5 | Log: `"Reconciled: tim thay [N]/4 files tren disk — tiep tuc tu Phase [X]"` | User sees log |
| R.6 | Jump tới phase tương ứng (xem §Phase Jump Map) | Skill continues |

### §Reconciliation Logic

```
IF test -f .mc-data/docs/phase6-deployment/deployment-guide.md AND test -s:
  phase2_done = true
ELSE:
  phase2_done = false; next_phase = "phase2"

IF phase2_done AND test -f user-guide.md AND test -s:
  phase3a_done = true
ELSE IF phase2_done:
  next_phase = "phase3a"

IF phase2_done AND phase3a_done:
  IF grep -q "^## 9\|^## Muc 9\|^## Quan ly tai khoan" deployment-guide.md:
    phase3b_done = true
  ELSE:
    next_phase = "phase3b"

IF phase3b_done:
  IF grep -q "^## 10\|^## Muc 10\|^## Bao tri" deployment-guide.md:
    phase4_done = true
  ELSE:
    next_phase = "phase4"

IF phase4_done:
  IF test -f incident-response-runbook.md AND test -s:
    phase4a_done = true
  ELSE:
    next_phase = "phase4a"

IF phase4a_done:
  next_phase = "phase5"  (luon chay lai validation tren resume)
```

### §Phase Jump Map

| next_phase | Action |
|------------|--------|
| `phase1` | READ `procedures/phase1-prereq.md` → execute |
| `phase2` | READ `procedures/phase2-deployment-guide.md` → execute (song song với phase3a nếu cần) |
| `phase3a` | READ `procedures/phase3a-user-guide.md` → execute |
| `phase3b` | READ `procedures/phase3b-account-mgmt.md` → execute |
| `phase4` | READ `procedures/phase4-maintenance.md` → execute |
| `phase4a` | READ `procedures/phase4a-runbook.md` → execute |
| `phase5` | READ `procedures/phase5-crossval.md` → execute |
| `phase5a` | READ `procedures/phase5a-review.md` → execute |

### §No Checkpoint Case

```
IF NOT test -f .mc-data/work/wf-prepare-deployment/checkpoint.json
   AND NOT test -f .mc-data/work/wf-prepare-deployment/prepare-deployment-status.json:
  → STOP + thông báo:
    "Khong tim thay checkpoint hoac status file.
     Chay `/wf-prepare-deployment` (khong co --resume) de bat dau tu dau."
```

---

## POST-GATE

- [ ] Nếu `--status`: skill đã STOP sau khi hiển thị report.
- [ ] Nếu `--resume`: `$RESUME_MODE = true` và `next_phase` được xác định đúng với filesystem thực tế.
- [ ] Context digest đã inject (nếu có).

**Next phase:** Tùy theo `next_phase` — mặc định là `phase1-prereq.md` nếu không có flag.
