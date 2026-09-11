# MCV3 Project Structure (Updated 2026-05-13)

```
.claude/
├── agents/                 # 62 agent definitions (5 teams + orchestrator)
│   ├── business/           # 25 business/domain agents
│   ├── engineering/        # 14 engineering agents
│   ├── design/             # 7 UX/UI agents
│   ├── testing/            # 9 QA/testing agents
│   ├── review/             # 6 self-quality agents
│   ├── orchestrator.md     # Team coordinator
│   ├── spec/               # Agent construction specification
│   └── procedures/         # 62 agent procedure directories (HOW per task)
├── commands/               # 33 slash command definitions
├── doc-framework/          # 40 document templates (Phase 0-6) + 20 schema files
├── hooks/                  # 12 Pre/Post tool hooks + _hook-utils.sh + README
├── references/             # Domain knowledge (162 files, 29 domains)
│   └── team-expert/        # Per-domain knowledge files
├── rules/                  # 9 rule files (00-behavioral, 00-core, 01-07)
│   └── 00-core.md          # 38 CORE rules (CORE-001 → CORE-038, updated with v10.0 patterns)
├── scripts/                # 160+ utility scripts (bash + PowerShell wrapper + JS)
│   ├── wf-add-scope/       # Per-skill helper directories
│   ├── wf-fix-*.sh         # wf-fix-bugs helper scripts
│   ├── wf-implement-feature/
│   ├── wf-manage-change/
│   ├── wf-preflight/
│   ├── wf-verify-sync/
│   └── audit/              # Contract conformance scripts
├── schemas/                # Shared JSON schemas
└── skills/
    ├── workflow/           # 35 wf-* skills (main pipeline + fix lanes QD1-QD11 + standalone)
    │   ├── wf-fix-bugs/    # Orchestrator v10.0: 7-phase pipeline, lazy-load procedures
    │   ├── wf-fix-*/       # 11 dimension lane skills (QD1-QD11)
    │   ├── wf-legacy-scan/ # v5.0 with session isolation
    │   ├── _shared/        # Python utilities (isg, signal_bus, concurrency, etc.)
    │   └── ...
    ├── workflows/          # 3 orchestrator workflows (new/existing/feature)
    ├── protocols/          # 22 protocol files (21 protocols + README)
    ├── gitnexus/           # GitNexus skill files
    └── templates/          # 2 standalone templates
```

Runtime project data (created by DEVKIT on user projects):
```
.mc-data/
├── docs/                   # Documents (7 phases)
│   └── _meta/
│       └── req-registry.json  # ★ Single Source of Truth
├── work/                   # Working data per skill (session isolation)
│   └── {skill}/sessions/{SESSION_ID}/
├── sync/                   # REQ-ID sync tracking
└── knowledge-base/         # Optional supplementary notes
```

Key architecture v10.0 additions (2026-05-13):
- CORE-032: Lazy-load procedure architecture (lean SKILL.md + procedure files)
- CORE-033: CI-First integration (GitNexus/Serena auto-detect + graceful degradation)
- CORE-034: Namespaced error codes (phase-based ranges + auto-fix budget)
- CORE-035: Phase output organization (subdirectories + atomic write)
- CORE-036: Cross-skill artifact contract (produces_for/consumes_from)
- CORE-037: Agent prompt templates (8 required sections)
- CORE-038: Context budget management (tiered checkpoint thresholds)
