# Task Completion Checklist for MCV3

After completing a task in this project:

## For Documentation Changes
- [ ] Logic consistent with prior phase documents
- [ ] No conflicts with `req-registry.json`
- [ ] Clear enough for business operations
- [ ] Structured enough for AI context consumption
- [ ] Created from appropriate template (CORE-031)

## For Code Changes
- [ ] Maps to REQ-ID/FEAT-ID in registry
- [ ] No missing committed behaviors
- [ ] No logic errors, build errors, test errors, or obvious security issues
- [ ] Docs and registry synced if needed
- [ ] Run `gitnexus_detect_changes()` before committing
- [ ] Run impact analysis before editing any symbol

## For Skill Changes
- [ ] `_contract.json` updated and schema-synced
- [ ] Skill compliance audit passes
- [ ] Template usage enforced (CORE-031)
- [ ] Phase summaries created (CORE-028)

## Validation Commands
```bash
./.claude/scripts/skill-compliance-audit.sh <skill-name>
./.claude/scripts/validate-schema-sync.sh <skill-name>
```
