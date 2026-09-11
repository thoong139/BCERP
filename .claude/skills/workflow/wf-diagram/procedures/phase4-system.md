# /wf-diagram — Phase 4: System-wide Diagrams (Conditional)

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.
> Xem SKILL.md §Mermaid 8.8.0 Safety Rules và §DBML Conventions — BẮT BUỘC khi populate.

---

## PRE-GATE

```
- [ ] $plan.system_files có ≥1 entry
- [ ] analysis.json đầy đủ (test -s)
```

---

## Steps (PARALLEL — 5 file độc lập)

> Theo CORE-025: 5 files có isolated write scope → có thể spawn 5 sub-tasks song song.

### 4.0 — Resolve $system_dir + mkdir

```bash
# v1.2.0 module-scoped layout
if [ "$scope" = "system-only" ]; then
  system_dir="$output_path/_system"
else
  system_dir="$output_path/modules/$module/_system"
fi
mkdir -p "$system_dir"
```

### 4.1 — Generate context.md

```
1. Read templates/system-context.md
2. Populate placeholders:
   [SYSTEM_NAME]            ← root project name từ analysis
   [ACTOR_NODES]            ← analysis.actors[] → "U1([\"Actor Name\"])"
   [EXTERNAL_SYSTEM_NODES]  ← analysis.external_systems[]
   [DATA_FLOWS]             ← actor → SYS, SYS → externals
   [CONTEXT_DESCRIPTION] / [ACTORS_LIST] / [EXTERNAL_SYSTEMS_LIST]
3. Apply Mermaid 8.8.0 Safety Rules (xem SKILL.md §Mermaid 8.8.0 Safety Rules)
4. Write → $system_dir/context.md
5. Verify: test -s + grep "flowchart"
```

### 4.2 — Generate component.md

```
1. Read templates/system-component.md
2. Populate:
   [PRESENTATION_MODULES] / [BUSINESS_MODULES] / [DATA_MODULES]
     ← analysis.modules[] grouped by detected layer
   [MODULE_DEPENDENCIES] ← analysis.modules[].depends_on[]
3. Apply Mermaid 8.8.0 Safety Rules
4. Write → $system_dir/component.md
5. Verify: test -s + grep "flowchart\|graph"
```

### 4.3 — Generate erd-context-map.md

```
1. Read templates/system-erd-context-map.md
2. Populate:
   [MODULE_ERD_NODES]   ← cho mỗi module có entity
   [CROSS_MODULE_REFS]  ← FK xuyên module
   [CROSS_REFS_TABLE]   ← bảng Markdown
3. Apply Mermaid 8.8.0 Safety Rules
4. Write → $system_dir/erd-context-map.md
5. Verify: test -s + grep "flowchart\|graph"
```

### 4.4 — Generate actors.md

```
1. Read templates/system-actors.md
2. Populate:
   [ACTORS_TABLE_ROWS]   ← analysis.actors[]
   [INTERNAL_ACTORS] / [EXTERNAL_ACTORS] / [SYSTEM_ACTORS]
   [AUTH_PATTERNS]        ← analysis.actors[].auth_pattern
3. Write → $system_dir/actors.md
   (Markdown thuần — không cần Mermaid safety rules)
4. Verify: test -s
```

### 4.5 — Generate database.dbml

```
1. Read templates/system-database.dbml
2. Populate (xem SKILL.md §DBML Conventions):
   [PROJECT_NAME] / [DB_TYPE]  ← analysis.tech_stack
   [TABLE_BLOCKS]               ← mỗi entity → Table block với columns + Note
   [TABLE_GROUPS]               ← group theo module (TableGroup {module} {...})
   [REFERENCES]                 ← Ref: cho mỗi FK (KHÔNG inline)
3. Write → $system_dir/database.dbml
4. Verify: grep "Project " AND grep "Table " (count >= 1)
```

### 4.6 — Save Checkpoint

```
save_checkpoint "phase_4" "phase_5"
Edit checkpoint.json: intermediate_outputs.system_files_done = ["context.md",...]
```

---

## POST-GATE

```
- [ ] Mỗi file trong $plan.system_files: test -s pass
- [ ] .md files có Mermaid block (grep '```mermaid')
- [ ] .dbml file có Project + Table block
- [ ] KHÔNG có placeholder chưa thay ([ACTOR_NODES], v.v.)
- [ ] phases.phase_4.status = "done"
```

---

## Next Phase Routing

```
NẾU $plan.module_files có ≥1 entry:
  → Phase 5: procedures/phase5-module.md

NẾU $plan.module_files rỗng AND ($plan.states OR activities OR sequences có entries):
  → Phase 6: procedures/phase6-detail.md

ELSE:
  → Phase 7: procedures/phase7-validation.md
```
