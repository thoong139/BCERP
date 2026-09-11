<!--
_template_notes:
  purpose: Outline cấu trúc procedures/ — _shared.md + phase{N}-*.md.
  populate:
    - §1 Layout procedures/ với mục đích từng file
    - §2 _shared.md content: state vars, atomic write helpers, error handling, CI detection
    - §3 phase{N}-*.md template (4 sections: Header, PRE-GATE, Steps, POST-GATE, Report)
    - §4 resume-status.md outline
    - §5 SKILL.md routing → procedures (lazy-load contract)
  độ dài tham khảo: 200-400 dòng
-->

# 07 — Procedures Structure

> **Mục đích file:** Outline thư mục `procedures/` — kiến trúc lazy-load tuân thủ CORE-032.

---

## 1. Layout

```
.claude/skills/workflow/{skill-name}/procedures/
├── _shared.md              ← Cross-cutting concerns
├── phase1-init.md          ← PRE-GATE → Steps → POST-GATE → Report
├── phase2-{name}.md
├── phase3-{name}.md
├── ...
├── phaseN-report.md
└── resume-status.md        ← --resume + --status handlers
```

**Quy tắc:** Mỗi procedure file CHỈ đọc khi tới phase tương ứng. KHÔNG load tất cả ở đầu.

---

## 2. `_shared.md` content

| Section | Mục đích |
|---------|---------|
| State variables | `$SESSION_DIR`, `$PROFILE`, `$SCOPE`, `$NAME`, `$CI_CONTEXT` |
| Atomic write helpers | `atomic_write_json()`, `atomic_append_jsonl()` bash functions |
| Error handling | `escalate()`, `auto_fix()`, `record_error()` bash functions |
| CI detection | Wrappers cho `ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh` |
| Logging | `log_phase_start()`, `log_phase_complete()`, `log_phase_fail()` |

---

## 3. `phase{N}-*.md` template (4 sections)

### Section A — Header

```markdown
# Phase {N}: {Tên phase}

**Đầu vào:** {file/state cần có}
**Đầu ra:** {file/state tạo ra}
**Auto-fix budget:** 3 retries
**Time estimate:** {X} min
```

### Section B — PRE-GATE

```markdown
## PRE-GATE (T1→T4 forensic)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | {exists} | `test -f` | E0{N}0 |
| T2 | {structure} | `jq` | E0{N}1 |
| T3 | {content} | `jq` | E0{N}2 |
| T4 | {cross-ref} | bash | E0{N}3 |
```

### Section C — Steps

```markdown
## Steps

| # | Mô tả | Tool | Output |
|---|------|------|--------|
| {N}.1 | Read template | Read | content |
| {N}.2 | Populate | Edit | tmp |
| {N}.3 | Validate | Bash (jq) | pass/fail |
| {N}.4 | Atomic write | Bash | output file |

### {N}.1. {Step name}
{detail}

### {N}.2. {Step name}
{detail}
```

### Section D — POST-GATE

```markdown
## POST-GATE (T1→T4)

| Tier | Check | Auto-fix retry |
|------|-------|----------------|
| T1 | {exists} | Re-run step {N}.4 |
| T2 | {structure} | Re-build từ template |
| T3 | {content depth} | Re-generate |
| T4 | {cross-ref upstream} | Re-read source |
```

### Section E — Phase Report (CORE-028)

```markdown
## Phase Report Template

```markdown
## Phase {N}: {Tên} — PASS|FAIL
Thời gian: {ISO 8601}
**Đã làm:** {1-2 câu tiếng Việt}
**Kết quả:** {Số liệu chính} + {File đầu ra}
**Tiếp theo:** {Phase kế tiếp / hành động user}
```
```

---

## 4. `resume-status.md`

| Mode | Behavior |
|------|----------|
| `--resume` | Đọc `fix-status.json` → xác định last completed phase → re-validate PRE-GATE phase tiếp theo → route |
| `--status` | Đọc `fix-status.json` → in summary (current phase, % done, context budget, lock owner) → exit 0 |

Stale check: lock age >30 min → auto-release.

---

## 5. SKILL.md routing → procedures (lazy-load contract)

`SKILL.md` (lean routing hub, ≤500 dòng) chứa bảng routing:

```markdown
## Phase Routing

| Phase | Procedure file | Trigger |
|-------|---------------|---------|
| 1 | `procedures/phase1-init.md` | Always (entry) |
| 2 | `procedures/phase2-*.md` | After Phase 1 PASS |
| ... | ... | ... |
```

**Quy tắc:** `SKILL.md` KHÔNG chứa execution logic — chỉ routing + summaries + contracts. Logic chi tiết LIVE trong `procedures/phase{N}-*.md`.

---

## 6. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-032 (Lazy-Load Procedures), CORE-035 (Phase Output Organization)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §3-4
