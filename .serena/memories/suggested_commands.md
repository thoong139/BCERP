# Suggested Commands for MCV3 Development

## Validation & Auditing
```bash
# Audit skill compliance (requires jq)
./.claude/scripts/skill-compliance-audit.sh [skill-name]
./.claude/scripts/skill-compliance-audit.sh --all

# Validate _contract.json schema sync
./.claude/scripts/validate-schema-sync.sh [skill-name | --all]
```

## Git Operations
```bash
git status
git diff
git log --oneline -20
git add <specific-files>
git commit -m "message"
```

## Navigation (Windows - use Git Bash or WSL)
```bash
ls
cd <dir>
find . -name "*.md" | head -20
```

## DEVKIT Self-Audit
```
/audit-devkit        # Full self-audit: scan → verify → fix
/audit-devkit-scan   # Scan components
/audit-devkit-verify # Cross-validate references
/audit-devkit-fix    # Auto-fix with per-fix verification
/audit-agents        # Audit agent definitions
/audit-skill-output  # Check output quality vs SKILL.md
```

## Project Status
```
/status              # View project progress
```

## Key Paths
- Agent definitions: `.claude/agents/`
- Skills: `.claude/skills/workflow/`
- Rules: `.claude/rules/`
- Hooks: `.claude/hooks/`
- Templates: `.claude/doc-framework/`
- Scripts: `.claude/scripts/`
- Shared protocols: `.claude/skills/protocols/`
- Project data: `.mc-data/docs/`
- SSOT registry: `.mc-data/docs/_meta/req-registry.json`
