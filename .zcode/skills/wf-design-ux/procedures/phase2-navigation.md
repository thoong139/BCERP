# Phase 2: Navigation Specs (per system, SEQUENTIAL)

> Tạo navigation spec cho từng system có UI.
> **(v4.1) Step 2.0 — Workflow Context + Screen Inventory + Consolidation** chạy TRƯỚC trong main conversation: chốt "minimum necessary screen set" theo luồng nghiệp vụ xuyên phòng ban, KHÔNG đẻ màn hình theo feature.
> Per system: spawn `ux-designer` (navigation structure) + `ux-architect` (CSS/layout) PARALLEL, merge output.

**PRE-GATE:**
- [ ] Phase 1 (`phase1-design-system.md`) POST-GATE PASS
- [ ] `test -s .mc-data/docs/phase4-ux/design-system.md`
- [ ] `$SYSTEMS_WITH_UI` non-empty

**INPUT:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md` (kể cả §9 Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ nếu wf-design v4.1 tạo)
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md` (v4.1 — cross-module data needs + propagation rules)
- `.mc-data/docs/phase2-features/**/*.md`

**OUTPUT:**
- `$SESSION_DIR/workflow-context.md` (Step 2.0 — v4.1)
- `.mc-data/docs/phase4-ux/[sys]/Navigation-[sys].md` (một file per system có UI)

---

## Reference Sections

- `_shared.md` §ERP Working-Context Design Rules (v4.1)
- `_shared.md` §Agent Prompt Templates → P2-A (ux-architect), P2-B (ux-designer)
- `_shared.md` §LEGACY Context Injection (nếu LEGACY_MODE)
- `_shared.md` §Checkpoint Protocol

---

## Step 2.0: Workflow Context + Screen Inventory + Consolidation (v4.1 — BẮT BUỘC, main conversation, TRƯỚC agent spawn)

> Trước khi vẽ menu/màn hình: hiểu luồng vận hành. Đơn vị thiết kế cấp cao hơn Page là **Workspace** (theo phòng ban/nhóm công việc).
> Nguồn suy luận: P3-01 (systems + phòng ban + roles), integration-map (cross-module deps), features (user stories + workflows).

**Guards:**
- Scope guard (CORE-006): chỉ screen cho modules/features có trong registry. Thiếu thông tin → `[NEEDS_REVIEW]`.
- KHÔNG tạo screen chỉ vì 1 action nhỏ — xét reuse: tab/drawer/modal/inline edit/view mode/master-detail/split view.
- Consolidation KHÔNG máy móc: chỉ gộp khi cùng nghiệp vụ, user hiểu được, không quá tải, permission vẫn rõ, workflow không phức tạp hơn.

| Step | Action | Verify |
|------|--------|--------|
| 2.0.1 | **Workflow map** — với mỗi business object chính: stages → role/phòng ban sở hữu → state do bộ phận nào tạo → ai chỉ xem/được sửa/được approve. Nguồn: P3-01 §3/§5/§9 + integration-map | Bảng object × stage × owner × state |
| 2.0.2 | **Workspace mapping** — mỗi phòng ban/nhóm công việc chính → workspace (VD: Sales Workspace, Finance Workspace). Trong workspace: công việc cần xử lý, alerts/exceptions, task queues, KPIs phục vụ hành động, quick actions, cross-department dependencies. Dashboard = operational/action-oriented khi phù hợp, KHÔNG chỉ xem số | Bảng workspace → vai trò → nội dung |
| 2.0.3 | **Screen inventory** — liệt kê mọi proposed screen: Purpose \| Primary role \| Business object \| Workspace \| Main actions \| Related screens \| FEAT-IDs. Bao gồm cả màn hình hiện có nếu LEGACY | Bảng inventory đầy đủ |
| 2.0.4 | **Shared object mapping** — objects dùng chung (Customer, Order, Invoice...) → MỘT shared working surface, role/permission-aware presentation — KHÔNG nhân bản màn hình gần giống nhau per phòng ban | Bảng shared object → surface → role views |
| 2.0.5 | **Consolidation pass** — với từng màn hình hỏi: trùng màn hình nào? merge được không? thành tab/drawer/inline được không? Create/View/Edit/Review/Approve có cần tách page không (mặc định: chung 1 surface đa mode)? Bỏ màn hình này thì workflow có hỏng không? Mỗi màn hình GIỮ LẠI phải trả lời được: ai dùng, làm gì, tần suất, quyết định gì, tại sao cần page riêng | Bảng screen → quyết định (KEEP/MERGE→TAB/MERGE→DRAWER/INLINE/DROP) + lý do |
| 2.0.6 | Ghi `$SESSION_DIR/workflow-context.md` (5 sections trên). Set `$WORKFLOW_MAP`, `$SCREEN_INVENTORY`, `$WORKSPACE_MAP`. Verify `test -s` + đủ 5 headings | File + state vars set |

**Đầu ra cho agent prompts:** P2-B (navigation) PHẢI tuân theo screen inventory đã consolidate — KHÔNG tự thêm screen group ngoài inventory. Phát hiện thiếu → ghi `[NEEDS_REVIEW]` + đề xuất cho user, KHÔNG tự thêm.

**Lite heuristic (dự án nhỏ — KHÔNG hỏi user):** nếu registry có **< 2 phòng ban** VÀ **không có business object nào đi qua > 1 phòng ban** (kiểm tra từ workflow map 2.0.1) → chạy Step 2.0 ở chế độ rút gọn:
- Chỉ làm 2.0.3 (Screen Inventory) + 2.0.5 (Consolidation); workspace mapping (2.0.2) gọn thành 1 bảng nhỏ (workspace = module group); bỏ 2.0.4 nếu không có shared object.
- `workflow-context.md` khi đó chỉ cần 2-3 sections (~50 dòng) — đủ dấu vết quyết định consolidate, không ép đầy đủ form ERP.
- Dự án ERP nhiều phòng ban (như BCERP) luôn chạy đủ 5 steps.

**Resume:** nếu `workflow-context.md` tồn tại + non-empty → skip Step 2.0 (SKIP-IF-EXISTS).

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.0 | **(v4.1)** Workflow Context + Screen Inventory + Consolidation — main conversation, XEM §Step 2.0 ở trên. Set `$WORKFLOW_MAP`, `$SCREEN_INVENTORY`, `$WORKSPACE_MAP` | `test -s $SESSION_DIR/workflow-context.md` |
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

- [ ] `test -s $SESSION_DIR/workflow-context.md` + đủ 5 sections (hoặc 2-3 sections nếu Lite heuristic — xem §Step 2.0)
- [ ] `ls .mc-data/docs/phase4-ux/*/Navigation-*.md` trả về ít nhất 1 file
- [ ] Mỗi `Navigation-[sys].md` có đủ 4 required sections
- [ ] Mỗi `Navigation-[sys].md` non-empty (>= 800 từ)
- [ ] Routes trong menu khớp với api-contract.md (sample check)
- [ ] **(v4.1)** Mỗi screen group trong Navigation có justification tương ứng trong `$SCREEN_INVENTORY` — KHÔNG có screen ngoài inventory
- [ ] Checkpoint per system đã save

**Next phase:** `phase3-screen-groups.md`

---

## Auto-Correction

Nếu Navigation file fail validation:
- Re-run ux-designer cho system đó (max 3 retries)
- Nếu vẫn fail → escalate với chi tiết missing sections
- Append error_log
