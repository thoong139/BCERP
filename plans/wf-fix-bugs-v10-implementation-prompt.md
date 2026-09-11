# wf-fix-bugs v10.0 — Implementation Prompt

## Context

You are implementing a complete architectural redesign of the `wf-fix-bugs` skill from v9.2.0 to v10.0.

**Design document:** `docs/architect-skill/wf-fix-bugs-redesign-v10.md` (1130 dòng, 11 sections) — READ THIS FIRST before starting any work.

**Reference architecture:** `.claude/skills/workflow/wf-legacy-scan/SKILL.md` + `procedures/_shared.md` — the gold standard for SKILL.md and _shared.md structure.

**Key principles:**
1. **SKILL.md chỉ chứa:** overview, arguments, phase routing map, condensed summaries (1 dòng/step), output files list, error quick-lookup. **KHÔNG chứa code thực thi.**
2. **All execution logic nằm trong `procedures/phase*.md`** — mỗi phase self-contained: PRE-GATE → INPUT → OUTPUT → Steps → POST-GATE (T1-T4) → Phase Report → Next Phase
3. **CI-First:** Mọi phase dùng GitNexus + Serena qua CI-ROUTE matrix (Protocol 20 §20.5). Graceful degradation Grep/Glob.
4. **CORE-031:** Mọi output file tạo từ template (READ → POPULATE → WRITE)
5. **Atomic Write:** Mọi shared state file dùng `jq edit > tmp && mv tmp target`
6. **Playwright:** Headless default, `--show-browser` cho visible, `--mobile` cho device emulation
7. **Giữ nguyên:** bash scripts (`scripts/wf-fix-*.sh`), Python modules (`_shared/`), prompts (`prompts/`), evals, sub-skills. Chỉ thay đổi: SKILL.md + procedures/ + templates/ + _contract.json.

## Implementation Order (13 Sprints)

### S0: Create Templates (32 files)

Create the directory: `.claude/skills/workflow/wf-fix-bugs/templates/`

Create subdirectories: `phase1-init/`, `phase2-scan/`, `phase3-plan/`, `phase4-find-bugs/`, `phase5-triage/`, `phase6-execute/`, `phase7-verify/`, `_common/`

Create ALL template files listed in §5.1 of the design document. For each template:
- JSON templates: use `{{VAR_NAME}}` placeholder pattern
- Markdown templates: use `[VAR_NAME]` placeholder pattern
- Include `_template_notes` field in JSON templates (stripped on populate — see wf-legacy-scan _shared.md §Template Metadata Stripping)
- Reference existing v9.2.0 schemas where applicable (e.g., `fix-impact.json` already exists)

**Priority templates (block other work):**
1. `templates/phase1-init/fix-status.json` — SSOT for the entire pipeline
2. `templates/_common/session-log.json` — CORE-026 execution trace
3. `templates/_common/error-ledger.json` — Error tracking
4. `templates/phase4-find-bugs/lane-signals.json` — Signal schema (lane-signals-v1)
5. `templates/phase5-triage/issue-registry.json` — Issue registry (issue-registry-v2)

### S1: Create `procedures/_shared.md` (17 sections)

Follow the exact structure from wf-legacy-scan's `_shared.md` (721 lines, well-organized sections).

Sections to create:
1. §1 State Variables Glossary — 20+ variables with Set by/Read by columns
2. §2 Cross-Phase Data Flow
3. §3 Atomic Write Pattern
4. §4 Error Handling Canonical (10 namespace ranges)
5. §5 Auto-Fix & Escalation Protocol (per-phase retry budget max 3)
6. §6 On Failure Standard Format
7. §7 Execution Trace (CORE-026) — dual-write (global + session)
8. §8 Phase Summary (CORE-028) — tiếng Việt ≤15 dòng
9. §9 Context & Checkpoint (65/80/90% thresholds)
10. §10 Template Usage Rule (CORE-031) — 3 placeholder patterns
11. §11 Task Planning (Protocol 9) — TodoWrite init 7 items
12. §12 CI Detection Pattern (Protocol 20) — Na/Nb/Nc + CI-ROUTE
13. §13 Lock/Heartbeat Pattern
14. §14 Bash Delegation Pattern
15. §15 Agent Prompt Templates — for triage + execute + lane agents
16. §16 Session Isolation Protocol
17. §17 Playwright Integration Pattern — headless/visible/mobile modes, session isolation, SEQUENTIAL scheduling

**Study before writing:** `wf-legacy-scan/procedures/_shared.md` for exact format, tone, and detail level.

### S2: Create `procedures/phase1-init.md`

23 steps. Key points:
- CI PRE-GATE 3-step: Na (Load CI Capabilities) → Nb (Index Freshness) → Nc (Agent Context Injection). Follow Protocol 20 §20.8 exactly.
- Flag dispatch: --status → resume-status.md, --resume → resume-status.md, --migrate → delegate script
- CDG gates: Browser (E090), Scope (E091), Cost (E092), Mobile (E093 — NEW)
- New flags: --show-browser (Playwright visible), --mobile (device emulation)
- Session init: SESSION_ID generation, phase subdirectories, lock acquisition, heartbeat

### S3: Create `procedures/phase2-scan.md`

NEW phase — scan code + docs for context. Key points:
- interface_type detection: web / mobile / api-only / hybrid
- CI-ROUTE: project_structure (Serena onboarding + GitNexus clusters), understand_flow (GitNexus query), find_by_annotation (both)
- Code inventory + doc inventory
- Mobile detection: check for mobile/ dir, React Native, Flutter, Capacitor, Expo, Swift/Kotlin

### S4: Create `procedures/phase3-plan.md`

ISG + partition + workload gate. Key points:
- ISG Recommender → refined dimensions
- Partition planner → workloads
- Workload Gate: dead_zone (<0.8), warn (0.8-1.5), block (>1.5) with CDG-11
- Agent Dispatch Threshold
- Playwright planning: reserve 1 slot if web/mobile interface

### S5: Create `procedures/phase4-find-bugs.md`

PARALLEL max 10 agents. Key points:
- Signal Directory Structure with 3 subdirectories (anti-overwrite)
- Playwright SEQUENTIAL across lanes (max 1 browser instance)
- Playwright modes: headless (default), visible (--show-browser), mobile (--mobile)
- Agent prompt template with CI context injection
- Mobile device defaults: iPhone 14 (390×844), Pixel 7 (412×915), iPad Pro (1024×1366)

### S6: Create `procedures/phase5-triage.md`

Aggregate + triage + CDG + safety. Key points:
- Signal aggregation → dedup (fingerprint collision)
- CORE-029 spot-check (sample 3 random signals)
- Process integrity check C1-C5 → process-violations.json
- E029 bridge: severity evaluation
- Spawn wf-fix-triage with CI context
- CDG Pre-Execute Handoff
- Safety Check (CORE-020)
- Early exit: N=0 → E005 → jump Phase 7

### S7: Create `procedures/phase6-execute.md`

Execute spawn. Key points:
- CI-ROUTE: pre-execution impact analysis (GitNexus impact)
- Dry-run support
- Spawn wf-fix-execute with CI context

### S8: Create `procedures/phase7-verify.md`

CQG + summaries. Key points:
- CQG-1 Numeric Metric Verification
- CQG-2 Browser + Integration Gate
- Mobile Gate (if --mobile)
- orchestrator-summary.md (CORE-028, tiếng Việt)
- fix-impact.json (cross-skill artifact)
- Completion display

### S9: Create `procedures/resume-status.md`

Merge resume + status handlers. Key points:
- --status: read fix-status.json, display all phase states
- --resume: find last completed phase, check staleness, route to next phase

### S10: Rewrite `SKILL.md`

Currently 730 lines with Phase 0 inline. Rewrite to ~350 lines with:
- CI PRE-GATE section (Na/Nb/Nc)
- Phase Routing Map table (7 phases)
- Condensed phase summaries (1 dòng/step)
- Error Handling quick lookup
- Output Files table with template references
- Playwright Integration section
- NO execution code — everything is "Xem `procedures/phase{N}-{name}.md`"

**Study before writing:** `wf-legacy-scan/SKILL.md` for exact format, section ordering, and detail level.

### S11: Update `_contract.json`

Update:
- `version` → "10.0.0"
- `procedures` array → new 9 file paths
- `outputs.working[]` → new phase subdirectory paths + template references
- `arguments[]` → add `--show-browser`, `--mobile`
- `flags` → update descriptions

### S12: Cleanup

Delete 17 old procedure files:
- `ci-pre-gate.md`, `session-dir.md`, `lock-management.md`, `bash-delegation.md`
- `step-verification.md`, `process-integrity-check.md`, `workload-gate.md`
- `agent-dispatch.md`, `cdg-handoff.md`, `status-display.md`, `resume-routing.md`
- `examples.md`, `phase1-engine.md`, `phase2-triage.md`, `phase3-execute.md`
- `post-gate-completion.md`

Update any script references to old paths (check `scripts/wf-fix-*.sh`).

### S13: Validate

Run validation:
```bash
# Compliance audit
./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs

# Schema sync
./.claude/scripts/validate-schema-sync.sh wf-fix-bugs

# Python tests
cd .claude/skills/workflow/_shared && ./run-tests.sh --fast

# Regression tests
cd .claude/skills/workflow/wf-fix-bugs/evals/regression-tests && bash run-all.sh
```

## Critical Rules

1. **BHV-003 Surgical Changes:** Chỉ thay đổi những gì trong scope. KHÔNG "improve" code/comments xung quanh.
2. **CORE-031 Template Usage:** Mọi output file PHẢI tạo từ template.
3. **Atomic Write:** Mọi shared state file dùng `jq > tmp && mv tmp target`.
4. **Keep backward compatibility:** Giữ nguyên bash scripts, Python modules, prompts, evals, sub-skills.
5. **Reference before writing:** When writing each phase file, read the corresponding section in the design document FIRST.
6. **wf-legacy-scan is the pattern:** When unsure about format, check wf-legacy-scan's equivalent file.

## Phase File Template

Every phase file MUST follow this structure:

```markdown
# Phase {N}: {Name} — wf-fix-bugs v10.0

> Procedure này thực thi Phase {N} của wf-fix-bugs pipeline.

## PRE-GATE
## INPUT
## OUTPUT
## Steps (table: Step | Action | Tool | Verify)
## POST-GATE (T1-T4)
## Phase Report
## On Failure
## Next Phase
```

## Context Budget

- Each procedure file: target 200-400 lines (not 870 like phase1-engine.md)
- SKILL.md: target ~350 lines (not 730)
- _shared.md: target ~700 lines (like wf-legacy-scan's 721)
- Use lazy-loading: Read procedure files ONLY when reaching that phase
