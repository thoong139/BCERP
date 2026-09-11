# Phase 2: Navigation Specs (per system, SEQUENTIAL)

> Tạo navigation spec cho từng system có UI.
> Per system: spawn `ux-designer` (navigation structure) + `ux-architect` (CSS/layout) PARALLEL, merge output.

**PRE-GATE:**
- [ ] Phase 1 (`phase1-design-system.md`) POST-GATE PASS
- [ ] `test -s .mc-data/docs/phase4-ux/design-system.md`
- [ ] `$SYSTEMS_WITH_UI` non-empty

**INPUT:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- `.mc-data/docs/phase2-features/**/*.md`
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`

**OUTPUT:** `.mc-data/docs/phase4-ux/[sys]/Navigation-[sys].md` (một file per system có UI)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P2-A (ux-architect), P2-B (ux-designer)
- `_shared.md` §LEGACY Context Injection (nếu LEGACY_MODE)
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.1 | Từ `$SYSTEMS_WITH_UI` — iterate qua từng system (SEQUENTIAL) | Systems list |
| 2.2 | Per system: `mkdir -p .mc-data/docs/phase4-ux/[sys]/` + **[SCAFFOLD-FIRST]** — xem §Scaffold Navigation | Directory + scaffold exists |
| 2.3 | **SKIP-IF-EXISTS** — nếu `test -s Navigation-[sys].md` → skip 2.3 + 2.3b cho system này. Ngược lại: spawn `ux-designer` (prompt P2-B, per system) | Agent success (hoặc skip) |
| 2.3b | Spawn `ux-architect` agent (prompt P2-A, PARALLEL với 2.3, per system) | Agent success |
| 2.4 | MERGE output: ux-designer (navigation structure) + ux-architect (CSS/layout) → `Navigation-[sys].md` | Merged |
| 2.5 | Verify `Navigation-[sys].md` non-empty với 4 required sections | `test -s Navigation-[sys].md` |
| 2.6 | **LOG AGENTS** — append `ux-designer`, `ux-architect` (per system) vào `design-ux-status.json` → `metrics.agents_spawned[]` | Agents logged |
| 2.7 | **SAVE CHECKPOINT (per system)** — READ `templates/checkpoint.json` → POPULATE (trigger=phase2_system_complete, position.current_phase=2, progress.systems_done+=1, systems_state) → WRITE checkpoint.json | Checkpoint saved |
| 2.8 | Iterate next system → quay lại Step 2.2. Nếu hết systems → POST-GATE | Loop hoặc exit |

---

## Scaffold Navigation (Step 2.2, per system)

```
IF NOT test -f Navigation-[sys].md:
  READ $PHASE4_CONTRACT["Navigation"].required_sections
  Pre-tạo Navigation-[sys].md:
    # Navigation — [System Name]
    
    ## Sơ Đồ Menu
    <!-- TODO: fill content -->
    
    ## Danh Sách Screen Groups
    <!-- TODO: fill content -->
    
    ## Phân Quyền & Hiển Thị Menu
    <!-- TODO: fill content -->
    
    ## UI Notes
    <!-- TODO: fill content -->

IF $PHASE4_CONTRACT không tồn tại:
  → Skip scaffolding, agent tự chịu trách nhiệm cấu trúc
```

---

## Parallel Spawn Pattern (Steps 2.3 + 2.3b)

```
PER SYSTEM [sys]:
  IF $LEGACY_MODE = true:
    Inject $LEGACY_CONTEXT + $UI_CONTEXT_SUMMARY + $LEGACY_DECISIONS vào cả 2 prompts

  PARALLEL:
    agent_A = spawn ux-designer (prompt P2-B, system=sys)
    agent_B = spawn ux-architect (prompt P2-A, system=sys)
  
  Wait BOTH complete (hoặc timeout)
  
  Merge output_A (navigation structure) + output_B (CSS/layout specs)
    → Navigation-[sys].md
    → ux-architect output merge vào section "Bố Cục & Responsive" của Navigation file
```

**Agent prompts:** Xem `_shared.md §Agent Prompt Templates → P2-A, P2-B`.

**Lưu ý LEGACY:** Nếu system thuộc `$DEPRECATED_MODULES` → KHÔNG spawn agents, skip system.

---

## POST-GATE

- [ ] `ls .mc-data/docs/phase4-ux/*/Navigation-*.md` trả về ít nhất 1 file
- [ ] Mỗi `Navigation-[sys].md` có đủ 4 required sections
- [ ] Mỗi `Navigation-[sys].md` non-empty (>= 800 từ)
- [ ] Routes trong menu khớp với api-contract.md (sample check)
- [ ] Checkpoint per system đã save

**Next phase:** `phase3-screen-groups.md`

---

## Auto-Correction

Nếu Navigation file fail validation:
- Re-run ux-designer cho system đó (max 3 retries)
- Nếu vẫn fail → escalate với chi tiết missing sections
- Append error_log
