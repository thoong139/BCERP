# Code Style & Conventions for MCV3

## Languages
- **Documentation & comments:** Tiếng Việt (Vietnamese)
- **File names, variables, functions:** English or Vietnamese without diacritics

## File Naming
- lowercase-kebab-case for files and directories (CORE-016/017)
- Skill files: `SKILL.md` (uppercase)
- Contract files: `_contract.json`
- Agent files: named by `subagent_type` value, no `.md` extension in reference

## REQ-ID Tracking (Mandatory)
Every code file must reference requirements:
```
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
```

## Rule System
8 rule files in `.claude/rules/` with path-scoped auto-loading:
- `00-behavioral.md`, `00-core.md` — always loaded
- `01-coding.md` — source code files
- `02-api.md` — API controllers
- `03-security.md` — source code
- `04-i18n.md` — UI files
- `05-database.md` — DB files
- `06-domain.md` — always
- `07-project.md` — always

## Registry Safe-Write Protocol
- Each skill only updates its assigned fields in `req-registry.json`
- Roles: PRIMARY, SEED, APPEND, SAFE-UPDATE, FIX-INVALID, UPDATE-MODE, NONE
- Never downgrade `impl_status` from `done`
- impl_status only: `not_started`, `in_progress`, `done`, `skipped`

## Template Usage (CORE-031)
Every output file must be created from a template: READ → POPULATE → WRITE
