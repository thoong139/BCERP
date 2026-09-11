# Phase 3c: Checkpoint (sau Phase 2 + 3a + 3b)

> Save checkpoint SAU KHI Phase 2, 3a, 3b hoàn thành, TRƯỚC KHI spawn thêm agents cho Phase 4.
> Mục đích: Bảo vệ 3 docs đã tạo trước khi tiếp tục các phase tốn context (Phase 4-5a).

**PRE-GATE:**
- [ ] `test -s .mc-data/docs/phase6-deployment/deployment-guide.md`
- [ ] `test -s .mc-data/docs/phase6-deployment/user-guide.md`
- [ ] Muc 9 đã có trong deployment-guide.md (Phase 3b DONE)

**OUTPUT:** `.mc-data/work/wf-prepare-deployment/checkpoint.json` (đã populate)

---

## Reference Sections

- `_shared.md` §Checkpoint Protocol (§Trigger Conditions, §Checkpoint Write Protocol)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3c.1 | Check `$CONTEXT_PERCENT` hiện tại | Value captured |
| 3c.2 | Quyết định checkpoint dựa trên context + LPM flag (xem §Decision Matrix) | Decision made |
| 3c.3 | **[READ-TEMPLATE]** READ `templates/checkpoint.json` → POPULATE (xem §Checkpoint Population) → WRITE `.mc-data/work/wf-prepare-deployment/checkpoint.json` | `test -s checkpoint.json` |
| 3c.4 | Validate checkpoint: `jq '.' checkpoint.json` | JSON valid |
| 3c.5 | Update `prepare-deployment-status.json` → `metrics.checkpoints_saved += 1` + `checkpoint` object | Status updated |
| 3c.6 | Nếu `$CONTEXT_PERCENT >= 90%` → **FORCE STOP** với message resume | Skill exits |
| 3c.7 | Nếu `$CONTEXT_PERCENT >= 80%` → log warning: Phase 4 giảm parallel (chỉ 1 agent thay vì 2) | Flag set |

---

## §Decision Matrix (Step 3c.2)

| `$CONTEXT_PERCENT` | `$LARGE_PROJECT` | Action |
|--------------------|------------------|--------|
| < 65% | false (Standard) | **SKIP checkpoint** (không cần thiết) |
| < 65% | true (LPM) | **SAVE checkpoint** (LPM per-phase strategy) |
| 65% – 79% | * | **SAVE checkpoint** + log warning |
| 80% – 89% | * | **SAVE checkpoint** + giảm parallel cho Phase 4 |
| >= 90% | * | **FORCE CHECKPOINT + STOP** — user resume với `--resume` |

---

## §Checkpoint Population (Step 3c.3)

Populate từ template `templates/checkpoint.json`:

```json
{
  "checkpoint_id": "CHK-DEPLOY-{YYYYMMDD}-{NNN}",
  "skill_id": "{skill_id tu status file}",
  "timestamp": "{ISO 8601 hien tai}",
  "session_number": {current_session},

  "trigger": {
    "reason": "phase_complete" | "context_limit",
    "context_used_pct": $CONTEXT_PERCENT,
    "phase_completed": "3c",
    "error_details": null
  },

  "position": {
    "current_phase": "3c",
    "current_phase_name": "Checkpoint",
    "current_step": null,
    "next_phase": "4",
    "next_action": "Spawn devops+tech-writer for Muc 10 Maintenance"
  },

  "progress": {
    "phases_completed": ["1", "2", "3a", "3b", "3c"],
    "docs_created": [
      ".mc-data/docs/phase6-deployment/deployment-guide.md",
      ".mc-data/docs/phase6-deployment/user-guide.md"
    ],
    "so_files_created": []
  },

  "context_summary": {
    "project_name": $PROJECT_NAME,
    "scope": $SCOPE,
    "sync_rate": $SYNC_RATE,
    "architecture_loaded": true,
    "infra_loaded": true
  },

  "partial_state": {
    "current_doc_output": null,
    "pending_phases": ["4", "4a", "5", "5a"],
    "intermediate_data": {}
  },

  "context_digest": {
    "deployment_session_summary":
      "Da tao deployment-guide (Muc 1-9) + user-guide. Chuan bi Phase 4 Maintenance.",
    "deployment_decisions": [
      "[tu Phase 2 agent output — VD: 'Blue-green deploy', 'staging truoc prod']"
    ],
    "docs_generated": {
      "deployment_guide_sections": ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
      "user_guide_status": "completed",
      "runbook_status": "pending",
      "stakeholder_review_status": "pending"
    },
    "key_architecture_context": {
      "tech_stack": "[tu registry/P3-01]",
      "environments": ["dev", "staging", "prod"],
      "deployment_topology": "[tu P3-01]"
    },
    "gotchas_and_warnings": [
      "DB migration can manual approval",
      "[cac gotchas khac tu Phase 2/3a/3b agents]"
    ]
  },

  "resume_instructions": {
    "load_files": [
      ".mc-data/work/wf-prepare-deployment/prepare-deployment-status.json",
      ".mc-data/docs/phase6-deployment/deployment-guide.md",
      ".mc-data/docs/phase6-deployment/user-guide.md"
    ],
    "resume_from_phase": "4",
    "user_message":
      "Resume tu Phase 4 (Muc 10 Maintenance). Da hoan thanh: deployment-guide Muc 1-9, user-guide."
  }
}
```

---

## POST-GATE

- [ ] `test -s .mc-data/work/wf-prepare-deployment/checkpoint.json`
- [ ] `jq '.' checkpoint.json` passes (JSON valid)
- [ ] `jq -e '.context_digest.deployment_session_summary | length > 0' checkpoint.json` passes
- [ ] Status file `metrics.checkpoints_saved` incremented
- [ ] Nếu `$CONTEXT_PERCENT >= 90%` → skill đã STOP và hiển thị resume instructions

**Next phase:** `phase4-maintenance.md` (nếu chưa STOP)

---

## Force Stop Message

Khi `$CONTEXT_PERCENT >= 90%`:

```
## CHECKPOINT SAVED — Context limit reached (90%+)

**Tien do hien tai:**
- deployment-guide.md: OK (Muc 1-9)
- user-guide.md: OK
- Maintenance (Muc 10): Pending
- Runbook: Pending
- Stakeholder review: Pending

**De tiep tuc, chay:**
```
/wf-prepare-deployment --resume
```

Skill se tu dong tiep tuc tu Phase 4.
```
