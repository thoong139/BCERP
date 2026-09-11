# Phase 6: Implement Code

> Goi `/wf-implement-feature` de implement code cho tung feature.
> Code phai tuan thu chuan EUREKA: DDD + CQRS + Minimal API + REQ-ID annotation.
> **v1.1:** Pre-flight check + per-task rollback snapshot + Automated Parity Check.

> **Shared:** Xem `procedures/_shared.md` — Sub-Skill Invocation Pattern, CI-ROUTE, Automated Feature Parity, Rollback Protocol.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
test -f $SESSION_DIR/preflight-results.json
jq -e '.implementation_order | length > 0' .mc-data/docs/_meta/req-registry.json
```

Neu fail → Phase 5 chua hoan thanh. Kiem tra lai.

---

## INPUT

| File | Mo ta |
|------|-------|
| Task files | Tu Phase 5 — danh sach task can implement |
| `$SESSION_DIR/strategy-matrix.md` | Strategy per feature — anh huong cach implement |
| `$SESSION_DIR/entity-mapping.md` | Entity mapping — data model tham chieu |
| `$SESSION_DIR/gap-analysis.md` | Gap analysis — logic cu can giu lai |
| `$SCAN_SESSION_DIR/target-map.json` | API/entity cu — parity check baseline |
| `$CI_CAPABILITIES` | GitNexus/Serena available flags |
| `$PREFLIGHT_RESULTS["wf-implement-feature"]` | Pre-flight check result |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 6.0 | **Pre-flight check wf-implement-feature:** Doc `$PREFLIGHT_RESULTS["wf-implement-feature"]`. Neu status=fail → hoi user (E016). Neu pass → tiep tuc. | Read | Pre-flight verified |
| 6.0a | **Snapshot registry truoc implement (NEW v1.1):** Copy toan bo registry → `$SESSION_DIR/snapshots/registry-phase6-pre-{timestamp}.json`. Ghi metadata vao `$ROLLBACK_SNAPSHOTS[]`. | Read/Write | Pre-implement snapshot |
| 6.0b | **--resume-task routing (NEW v1.1):** NEU `$RESUME_TASK != null`: (a) Doc checkpoint.json `partial_state.phase6` → verify task n ton tai trong `tasks_remaining[]`. Neu khong → E021. (b) Khoi phuc registry tu `registry-phase6-task{n}-pre-{ts}.json` (neu co). (c) Skip tasks 0..n-1. (d) Bat dau implement tu task n. (e) Ghi log: `"RESUME: Phase 6 resumed tu task [n]."` | Read/Bash | Resume position set |
| 6.1 | **CI impact analysis cho tung task:** Voi moi task, chay `gitnexus_impact` + `serena_find_referencing_symbols` (neu CI available) de kiem tra code hien co truoc khi viet moi. Tuan thu CORE-020 — khong silent overwrite. Neu CI khong available → fallback Grep + Glob. | MCP | Impact analyzed |
| 6.2 | **Invoke `/wf-implement-feature` cho tung task:** Skill tool voi skill=`wf-implement-feature`, args=`--task=<task-id>`. Chay tuan tu theo `implementation_order`. | Skill | Sub-skill invoked per task |
| 6.2a | **Snapshot sau moi task (NEW v1.1):** Sau moi task hoan thanh → ghi `$SESSION_DIR/snapshots/changed-files-task{n}-{ts}.txt` (danh sach file da thay doi tu `git diff --name-only`). Neu CI available → `gitnexus_detect_changes` de verify scope anh huong. Ghi per-task checkpoint vao `checkpoint.json` `partial_state.phase6` (current_task, tasks_completed, tasks_remaining). | Bash/MCP/Write | Per-task snapshot + checkpoint |
| 6.3 | **Verify code:** Sau moi task, verify: code compile? REQ-ID annotation dung? Tuan thu pattern DDD + CQRS? | Read/Bash | Code verified |
| 6.4 | **Automated Feature Parity Check (NEW v1.1):** Voi moi feature co strategy = "Keep": chay Automated Parity theo `_shared.md` §Automated Feature Parity. So sanh response shape (GitNexus `shape_check`), entity fields, business rules, edge cases. Populate `templates/parity-check.md` → WRITE `$SESSION_DIR/parity-check-{feature}.md`. | MCP/Read/Write | Parity report created |
| 6.4a | **Parity evaluation:** Dem PASS/PARTIAL/FAIL. Neu FAIL > 3 → STOP + hoi user (E009). Neu FAIL > 5 → CRITICAL (E017) → trigger rollback protocol → Step 6.4b. | — | Parity evaluated |
| 6.4b | **Auto-Rollback (NEW v1.1):** NEU E017 triggered VA `$AUTO_ROLLBACK == true`: Tu dong revert registry + code theo `_shared.md` §Auto-Rollback Protocol. Ghi error_log voi action_taken="auto_rollback". Thong bao user. → STOP. NEU revert fail → E020 (thu tung file, log chi tiet). NEU `$AUTO_ROLLBACK == false` → hoi user revert hoac tiep tuc. | Bash | Auto-rollback executed |
| 6.5 | **CI detect_changes:** Chay `gitnexus_detect_changes` de xac nhan code changes chi anh huong den expected symbols. Neu CI khong available → fallback `git diff --stat`. | MCP | Changes verified |
| 6.6 | **Cap nhat status + checkpoint:** Cap nhat `migrate-status.json`. Set `$IMPLEMENT_RESULTS` (tasks completed, parity results). Set `$CODE_SNAPSHOTS[]` (danh sach snapshot per task). Luu checkpoint (next_phase="phase7", rollback_snapshot_ids, partial_state.phase6). | Write | Status updated |

---

## POST-GATE

**Feature Parity Gate (cho feature Keep):**
- Output moi == output cu cho cung input
- Edge cases duoc xu ly dung
- Neu parity fail > 3 test cases → STOP, hoi user
- Neu parity fail > 5 → CRITICAL — trigger rollback protocol

**Rollback Readiness Gate (NEW v1.1):**
- Moi task co snapshot `changed-files-task{n}-*.txt`
- Registry pre-implement snapshot ton tai
- Neu `$AUTO_ROLLBACK == true`: verify auto-rollback protocol ready (snapshots accessible)

**Auto-Rollback Gate (NEW v1.1):**
- NEU E017 + `$AUTO_ROLLBACK == true`: verify registry restored, code reverted, error_log ghi nhan
- NEU rollback fail (E020): verify tung file da duoc thu hoi, log chi tiet

```bash
# Verify impl_status da duoc cap nhat
jq -e '.features | map(select(.module_id == "$TARGET_MODULE" and .impl_status == "done")) | length > 0' .mc-data/docs/_meta/req-registry.json
# Verify parity reports cho tat ca feature Keep
ls $SESSION_DIR/parity-check-*.md 2>/dev/null | wc -l
# Verify rollback snapshots ton tai
ls $SESSION_DIR/snapshots/registry-phase6-*.json 2>/dev/null | wc -l
ls $SESSION_DIR/snapshots/changed-files-*.txt 2>/dev/null | wc -l
# Verify auto-rollback log neu duoc kich hoat
jq -e '.rollback.auto_triggered' $SESSION_DIR/migrate-status.json
```

---

## Next Phase

→ `procedures/phase7-report.md`
