# MCV3 (DEVKIT) Overview — Updated 2026-05-13

DEVKIT is a Claude Code-based development toolkit that helps non-technical users build complete software products through 62 AI expert agents. It transforms vague ideas into complete software products via multi-agent orchestration.

**Core layers:**
- **Skills (`.claude/skills/`):** 35 user-facing `/commands` that orchestrate development phases. Each has SKILL.md + _contract.json + procedures/ + templates/ + evals/.
- **Agents (`.claude/agents/`):** 62 AI experts across 5 teams (Business, Engineering, Design, Testing, Review) + 62 procedure directories.
- **Rules (`.claude/rules/`):** 9 rule files, including 00-core.md with 38 CORE rules (CORE-001 through CORE-038) governing all skills and agents.
- **Hooks (`.claude/hooks/`):** 12 Pre/Post tool hooks for validation.
- **Protocols (`.claude/skills/protocols/`):** 21 shared quality gate protocols.
- **Scripts (`.claude/scripts/`):** 160+ bash/PS1/JS utility scripts.

**Key workflows:**
- Standard path: idea → brainstorm → requirements → features → design → UX → plan modules → implement → preflight → verify → deploy
- Existing path: legacy scan → classify → extract → brainstorm → ... → deploy
- Fix path: wf-fix-bugs (7-phase pipeline: Init → Scan → Plan → Find Bugs → Triage → Execute → Verify)

**v10.0 Architecture (2026-05-13):**
- Lazy-load procedure architecture (CORE-032): SKILL.md as lean routing hub, logic in separate procedure files
- CI-First integration (CORE-033): Auto-detect GitNexus/Serena, graceful degradation
- Namespaced error codes (CORE-034): Phase-based ranges E001-E109, auto-fix budget max 3 retries
- Phase output organization (CORE-035): Subdirectories phase{N}-{name}/, atomic write JSON
- Cross-skill artifact contracts (CORE-036): produces_for/consumes_from in _contract.json
- Agent prompt templates (CORE-037): 8 required sections per agent prompt
- Context budget management (CORE-038): Tiered checkpoint thresholds

**Important:** Output quality must be sufficient for both business operations AND AI context for further development. Quality > Speed always.
