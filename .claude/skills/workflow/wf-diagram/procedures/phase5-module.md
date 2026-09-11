# /wf-diagram — Phase 5: Module-scoped Diagrams (Conditional)

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.
> Xem SKILL.md §Mermaid 8.8.0 Safety Rules và §DBML Conventions — BẮT BUỘC khi populate.

---

## PRE-GATE

```
- [ ] $plan.module_files có ≥1 entry
- [ ] $user_choice ≠ "skip"
- [ ] analysis.json có data về $module
- [ ] $plan.usecase_groups[] có ≥1 entry
```

---

## Steps (PARALLEL — N+2 files độc lập)

> Theo CORE-025: class.md + erd.dbml + N usecase files có isolated write scope
> → có thể spawn N+2 sub-tasks song song.

### 5.1 — Generate usecases/{group}.md (PARALLEL per group)

```
mkdir -p "$output_path/modules/$module/usecases"

FOR each group IN $plan.usecase_groups:
  1. Read templates/module-usecase.md
  2. Populate:
     [MODULE_NAME]            ← $module
     [GROUP_NAME]             ← group.group_name
     [GROUP_DESCRIPTION]      ← group.description
     [ACTOR_NODES]            ← group.actors[] → nodes actor
     [USECASE_NODES]          ← group.use_cases[] → mỗi use case là 1 oval node
     [ACTOR_USECASE_LINKS]    ← actor → use case theo permissions
     [INCLUDE_EXTEND_RELS]    ← helper calls: UC1 -. include .-> UC2
     [USECASES_DESCRIPTION]   ← bảng Markdown:
                                (Use Case | Actor | Mô tả | Source handler | Include | Extend)
     [RELATED_GROUPS]         ← link sang group khác: "- [Name](./{slug}.md) — mô tả"
                                (rỗng nếu module chỉ có 1 group)
     [USECASE_NOTES]          ← grouping_basis + use case nào primary/secondary + // TODO nếu chưa rõ
  3. Apply Mermaid 8.8.0 Safety Rules (xem SKILL.md §Mermaid 8.8.0 Safety Rules)
  4. Write → $output_path/modules/$module/usecases/{group.group_slug}.md
  5. Verify: test -s + grep "flowchart"

# Module luôn có ≥1 file usecase (kể cả khi chỉ 1 group)
```

### 5.2 — Generate class.md

```
1. Read templates/module-class.md
2. Populate:
   [MAIN_CLASSES]          ← analysis.classes[where module == $module]
                              Chỉ show field/method chính (KHÔNG show all)
   [EXTERNAL_CLASSES]      ← analysis.cross_module_refs[] với <<external from {mod}>>
   [CLASS_RELATIONSHIPS]   ← inheritance (--|>), composition (*--), aggregation (o--), association (-->)
   [CLASSES_TABLE] / [EXTERNAL_REFS] / [DESIGN_PATTERNS]
3. Apply Mermaid 8.8.0 Safety Rules
4. Write → $output_path/modules/$module/class.md
5. Verify: test -s + grep "classDiagram"
```

### 5.3 — Generate erd.dbml

```
1. Read templates/module-erd.dbml
2. Populate (xem SKILL.md §DBML Conventions):
   [MODULE_NAME] / [DB_TYPE]
   [MODULE_TABLE_BLOCKS]    ← entities thuộc $module: full columns + Note
   [EXTERNAL_TABLE_BLOCKS]  ← entities ngoài $module: "// External: from <mod>", chỉ show PK
   [MODULE_REFERENCES]      ← Ref: cho FK trong scope module
3. Write → $output_path/modules/$module/erd.dbml
4. Verify: grep "Project " AND grep "Table "
```

### 5.4 — Save Checkpoint

```
save_checkpoint "phase_5" "phase_6"
Edit checkpoint.json:
  intermediate_outputs.module_files_done = ["class.md", "erd.dbml"]
  intermediate_outputs.usecase_groups_done = [<list of group slugs>]
```

---

## POST-GATE

```
- [ ] class.md tồn tại + non-empty + có "classDiagram"
- [ ] erd.dbml tồn tại + non-empty + có Project + Table block
- [ ] usecases/ có ≥1 file = len($plan.usecase_groups)
- [ ] Mỗi usecases/{slug}.md non-empty + có "flowchart"
- [ ] KHÔNG có placeholder chưa thay trong bất kỳ file nào
- [ ] phases.phase_5.status = "done"
```

---

## Next Phase

→ Phase 6: `procedures/phase6-detail.md` (Detail Diagrams)
