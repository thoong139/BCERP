# 01 — Session Protocol: Cách Làm Việc Mỗi Phiên

> **Đọc trước:** [00-master-plan.md](00-master-plan.md)
> **Đọc tiếp:** [phases/phase-A-design-closure.md](phases/phase-A-design-closure.md)
> **Áp dụng cho:** Mỗi phiên làm việc triển khai wf-legacy-scan v5.0.

---

## 1. Nguyên Tắc

1. **Small batches** — 1-3 tasks per session để tránh context overflow.
2. **Always checkpoint** — ghi session log + update phase plan status trước khi kết thúc.
3. **Verify before advance** — mỗi task phải pass verify command trước khi mark completed.
4. **Rollback ready** — mỗi commit phải atomic để dễ revert.
5. **Handoff-friendly** — session log đủ chi tiết để người khác (hoặc bạn ngày mai) tiếp tục.

---

## 2. Quy Trình Bắt Đầu Session

### 2.1 Context Load (5 phút)

```bash
# 1. Check current phase + progress
cat docs/design/skills/wf-legacy-scan/implementation/README.md | head -60

# 2. Đọc master plan nếu có thay đổi
git log --oneline docs/design/skills/wf-legacy-scan/implementation/00-master-plan.md

# 3. Đọc phase plan hiện tại
cat docs/design/skills/wf-legacy-scan/implementation/phases/phase-<X>-*.md

# 4. Check last session log
ls -t docs/design/skills/wf-legacy-scan/implementation/session-logs/ | head -3
```

### 2.2 Chọn Tasks (2 phút)

- Ưu tiên task `🟡 In Progress` từ session trước (nếu có).
- Nếu tất cả completed → pick 1-3 `⬜ Pending` tasks theo thứ tự trong phase plan.
- Tránh pick task blocked bởi dependency chưa done.

### 2.3 Verify Prerequisites (3 phút)

- Check branch đúng (`git branch` → `feat/wf-legacy-scan-v5.0-phase-<X>`).
- Check working tree clean (`git status`).
- Check `_contract.json` latest (nếu phase touch contract).
- Check design doc không có update mới mâu thuẫn (`git log docs/design/skills/wf-legacy-scan/`).

### 2.4 Khai Báo Session

Tạo file `session-logs/YYYY-MM-DD-{N}.md`:

```markdown
# Session 2026-04-22 #1

**Phase:** B — Foundation
**Tasks chọn:**
- B.1.2 — Tạo template scan-state.json
- B.1.3 — Tạo template phase-summary.md
- B.2.1 — Implement file-lock helper

**Branch:** feat/wf-legacy-scan-v5.0-phase-b
**Start time:** 10:00
**Context budget:** ~40K

---

## Progress
...
```

---

## 3. Quy Trình Trong Session

### 3.1 Per-Task Flow

```
1. Read task description trong phase plan
2. Execute actions theo bảng tasks
3. Run verify commands (listed per task)
4. Update task status: ⬜ → 🟡 → ✅
5. Commit atomic (1 task = 1 commit nếu có thể)
6. Append vào session log
```

### 3.2 Context Management

Check context budget mỗi 15-20 phút:

| Context % | Hành động |
|-----------|-----------|
| < 50% | Normal — continue |
| 50-65% | Prepare handoff — tránh start task mới |
| 65-80% | STOP task mới — chỉ close task đang dở |
| > 80% | IMMEDIATE checkpoint + handoff + end session |

### 3.3 When Blocked

Nếu gặp blocker:

1. Ghi vào session log: `**BLOCKER:** <description>`.
2. Check blocker level (theo master-plan §9):
   - Level 1 design conflict → tạo issue + update ADR
   - Level 2 timeline slip → escalate
   - Level 3 backward-compat break → STOP + revert
3. Skip task, pick task khác nếu independent.
4. Không force workaround vi phạm CORE rules.

---

## 4. Quy Trình Kết Thúc Session

### 4.1 Cleanup (10 phút)

```
1. Finish task đang dở (hoặc checkpoint + mark 🟡 with progress %)
2. Run full verify suite cho tasks completed:
   - jq empty <output files>
   - compliance audit nếu phase touch SKILL.md
   - unit tests nếu phase touch Python module
3. Commit với message: "Phase <X> task <id>: <short desc>"
4. Push branch (không merge main)
```

### 4.2 Update Progress

```
1. Update phase plan: status ⬜ → ✅ (hoặc 🟡 với % progress)
2. Update implementation/README.md status table nếu phase progress thay đổi
3. Append session log với summary:
   - Tasks completed
   - Tasks in progress (với % + next steps)
   - Blockers
   - Time spent
   - Commits created
```

### 4.3 Handoff Note

Ghi ở cuối session log:

```markdown
## Handoff to Next Session

**Resume from:** Task B.2.1 at 40% (file-lock helper — đã xong acquire, chưa xong release + stale detection)
**Next steps:**
1. Finish release() function với stale detection (>1h mtime)
2. Unit test cho file-lock
3. Start B.2.2 — session directory creation

**Context needed:**
- Read templates/scan-state.json
- Check 03-architecture.md §3 Session Layout

**Branch state:** feat/wf-legacy-scan-v5.0-phase-b (pushed)
**Last commit:** abc1234
```

---

## 5. Commit Convention

### 5.1 Message Format

```
<phase-id> <task-id>: <short description>

- <detail 1>
- <detail 2>

Verify: <command run + pass>
Refs: <ADR-LS##>, <design doc section>
```

**Ví dụ:**
```
Phase B B.1.2: Add templates/scan-state.json

- Schema v1 from 04-data-model.md §1.1
- Includes 6 layer states, depth_map, ips, config
- Populated với default values cho fresh run

Verify: jq empty templates/scan-state.json — PASS
Refs: ADR-LS04, 04-data-model.md §1.1
```

### 5.2 Atomic Commit Rules

- 1 task = 1 commit (nếu có thể).
- KHÔNG mix nhiều phases trong 1 commit.
- KHÔNG commit broken state (tests fail, JSON invalid).
- KHÔNG commit WIP cuối session — checkpoint vào session log thay vì commit.

### 5.3 Branch Strategy

```
main (protected)
  └── feat/wf-legacy-scan-v5.0-phase-A
  └── feat/wf-legacy-scan-v5.0-phase-B
      └── (merge A first, rebase)
  └── ...
```

Không push main cho đến Phase J complete.

---

## 6. Session Log Template

File: `session-logs/YYYY-MM-DD-{N}.md`

```markdown
# Session YYYY-MM-DD #N

**Phase:** <phase name>
**Branch:** <branch>
**Start:** HH:MM
**End:** HH:MM
**Duration:** <hours>
**Implementer:** <name/handle>

---

## Tasks Planned

- [ ] Task <id>: <desc>
- [ ] Task <id>: <desc>
- [ ] Task <id>: <desc>

---

## Tasks Progress

### Task <id>: <desc>
**Status:** ✅ / 🟡 / ❌
**Start:** HH:MM
**End:** HH:MM

**Actions taken:**
- ...

**Verify results:**
- `<command>` → <result>

**Issues encountered:**
- ...

**Commits:**
- abc1234 — <message>

---

## Blockers

- **[Level X]** <description> → escalation path

---

## Context Usage

- Peak: <%>
- Avg: <%>
- Tokens ~: <estimate>

---

## Handoff to Next Session

**Resume from:** <task + % progress>
**Next steps:**
1. ...
2. ...

**Branch state:** <branch>
**Last commit:** <hash>
**Files modified (pending commit):** <list>
```

---

## 7. Verification Commands (Quick Reference)

### 7.1 JSON Validation
```bash
jq empty <file.json>  # exit 0 if valid
```

### 7.2 Template Usage (CORE-031)
```bash
grep -l "from templates/" .claude/skills/workflow/wf-legacy-scan/procedures/*.md
# Should find ≥ 1 file per output
```

### 7.3 Compliance Audit
```bash
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-scan
```

### 7.4 Schema Sync
```bash
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/validate-schema-sync.sh wf-legacy-scan
```

### 7.5 Python Unit Tests (Phase C+)
```bash
python -m pytest .claude/skills/workflow/_shared/ips/tests/ -v
```

### 7.6 Bash Scripts Cross-Platform (Phase G)
```bash
# Git Bash
bash .claude/scripts/legacy-scan-detect.sh /tmp/fixture /tmp/out
# WSL (nếu có)
wsl bash .claude/scripts/legacy-scan-detect.sh /tmp/fixture /tmp/out
```

### 7.7 Backward-Compat Golden Test (Phase D, I)
```bash
# Run v4.1 baseline
git checkout legacy-scan-v4.1.0-baseline
/wf-legacy-scan fixtures/medium-vn/ --profile=standard  # v4.1
cp -r .mc-data/work/legacy-scan /tmp/v4.1-output

# Run v5.0 standard
git checkout feat/wf-legacy-scan-v5.0-phase-d
/wf-legacy-scan fixtures/medium-vn/ --profile=standard
diff -r /tmp/v4.1-output .mc-data/work/legacy-scan/
# Expected: output structure identical, values ±5% acceptable
```

---

## 8. Emergency Procedures

### 8.1 Accidental Main Branch Commit
```bash
git reset --soft HEAD~1  # preserve changes
git checkout -b feat/wf-legacy-scan-v5.0-phase-<X>
git commit -m "..."
```

### 8.2 Broken State After Commit
```bash
git revert <broken-commit>
# Investigate root cause trong session log
# Fix in new commit (NEVER amend published commits)
```

### 8.3 Context Overflow Mid-Task
```
1. STOP current task
2. Append session log: [CONTEXT OVERFLOW]
3. Commit partial work với flag "WIP" trong message
4. Write detailed handoff note cho next session
5. End session
```

### 8.4 Rollback Entire Phase
```bash
git checkout main
git branch -D feat/wf-legacy-scan-v5.0-phase-<X>
git tag -d v5.0-phase-<X>  # nếu đã tag

# Start over from design docs
```

---

## 9. Anti-Patterns (TRÁNH LÀM)

1. ❌ Skip verify command vì "tin tưởng code"
2. ❌ Batch nhiều tasks rồi commit 1 lần (khó rollback)
3. ❌ Continue task khi context > 80%
4. ❌ Merge phase branch vào main trước Phase J
5. ❌ Skip session log vì "session ngắn"
6. ❌ Modify ADR trong implementation phase mà không bump design version
7. ❌ Fix backward-compat bug bằng shortcut (VD: giảm threshold để pass) — phải fix root cause
8. ❌ Ignore cross-platform failures ("chỉ fix cho Linux")

---

## 10. Session Kickoff Checklist

Trước mỗi session, tick đủ 6 item:

- [ ] Đọc README.md + master plan
- [ ] Đọc phase plan hiện tại
- [ ] Check last session log handoff note
- [ ] Pick 1-3 tasks (không quá)
- [ ] Verify branch + working tree clean
- [ ] Tạo session log file với header

Nếu bất kỳ item nào chưa xong → chưa bắt đầu session.
