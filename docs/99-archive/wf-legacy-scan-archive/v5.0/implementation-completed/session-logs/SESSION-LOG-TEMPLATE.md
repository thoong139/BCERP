# Session YYYY-MM-DD #N

> Copy this template to `YYYY-MM-DD-{N}.md` khi bắt đầu session mới.

---

## Session Metadata

**Phase:** {{PHASE_LETTER}} — {{PHASE_NAME}}
**Branch:** feat/wf-legacy-scan-v5.0-phase-{{PHASE_LETTER}}
**Start:** HH:MM
**End:** HH:MM
**Duration:** {{HOURS}}
**Implementer:** {{NAME}}
**Context budget start:** {{%}}

---

## Tasks Planned (1-3 recommended)

- [ ] Task {{ID}}: {{DESC}}
- [ ] Task {{ID}}: {{DESC}}
- [ ] Task {{ID}}: {{DESC}}

---

## Session Kickoff Checklist

- [x] Read implementation/README.md + master plan
- [x] Read phase plan hiện tại
- [x] Check last session log handoff note
- [x] Branch + working tree clean
- [x] Tasks picked
- [x] Session log file created (this file)

---

## Tasks Progress

### Task {{ID}}: {{DESC}}

**Status:** ⬜ Pending / 🟡 In Progress / ✅ Completed / ❌ Failed / ⏸️ Paused

**Start:** HH:MM
**End:** HH:MM
**Duration:** {{X}} giờ

#### Actions taken

1. ...
2. ...

#### Verify results

- `<command>` → PASS/FAIL + output excerpt

#### Issues encountered

- ...

#### Commits

- `abc1234` — Phase {{X}} {{ID}}: {{short}}
- `def5678` — ...

---

### Task {{ID_2}}: ...

(Repeat above structure)

---

## Blockers

- **[Level X]** {{description}}
  - Escalation path: ...
  - Impact: ...
  - Workaround: ...

---

## Context Usage

- Peak: {{%}}
- Avg: {{%}}
- Checkpoint triggers: {{count}}
- Tokens estimate: {{N}}K

---

## Design/ADR Issues Found

(Track any design doc updates needed — update in separate commit to design branch)

- [ ] {{issue}} → action: {{fix plan}}

---

## Handoff to Next Session

**Resume from:** Task {{ID}} at {{%}}% ({{short description of partial progress}})

**Next steps:**
1. ...
2. ...
3. ...

**Context needed for next session:**
- Read: {{files}}
- Verify state: {{checks}}

**Branch state:** {{branch}} — {{ahead}} ahead / {{behind}} behind main
**Last commit:** {{hash}}
**Files modified (pending commit):** {{list or "none"}}
**Uncommitted work:** {{describe if any}}

---

## Quick Summary

**Tasks completed:** {{N}}
**Tasks in progress:** {{N}}
**Blockers:** {{N}}
**Time spent:** {{H}}h
**Key win:** {{1 sentence}}
**Key issue:** {{1 sentence}}

---

## Updates to MIGRATION-PROGRESS.md

- [ ] Status updated
- [ ] Notes added if relevant

---

## Next Session Plan

**Target date:** {{DATE}}
**Priority tasks:**
1. ...
2. ...

**Preparation needed:**
- ...
