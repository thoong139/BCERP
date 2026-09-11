# Shared Protocols — wf-design-ux

> Cross-cutting protocols, state variables glossary, LEGACY context injection spec
> và agent prompt templates được sử dụng bởi nhiều Phase trong wf-design-ux.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Phase → File Mapping](#phase--file-mapping)
- [Phase Ordering by Mode](#phase-ordering-by-mode)
- [Session Isolation Protocol (ADR-OPT-02)](#session-isolation-protocol-adr-opt-02)
- [_shared Module Imports (ADR-OPT Integration)](#_shared-module-imports-adr-opt-integration)
- [Conditional Skip Handling (api-only)](#conditional-skip-handling-api-only)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Large Project Mode (LPM)](#large-project-mode-lpm)
- [Fix Rules đặc thù](#fix-rules-đặc-thù)
- [Registry Safe-Write](#registry-safe-write)
- [Token Limit Prevention](#token-limit-prevention)
- [LEGACY Context Injection](#legacy-context-injection)
- [Agent Prompt Templates](#agent-prompt-templates)
- [Checkpoint Protocol](#checkpoint-protocol)
- [LEGACY_MODE Detection](#legacy_mode-detection)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution. Phải persist vào `session-state.json.flags{}` khi có resume risk.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 | 0, 0.5, 1-5 | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$LEGACY_CONTEXT` | Phase 0 | 0.5, 1-5 (agent spawns) | Nội dung `project-context.md` (LEGACY) |
| `$UI_CONTEXT_SUMMARY` | Phase 0.5-legacy | 1-5 (agent spawns) | Tóm tắt UI hiện trạng (screens, tokens, libraries, gaps) |
| `$LEGACY_DECISIONS` | Phase 0 | 1-5 | Nội dung `legacy-decisions.json` (LEGACY) |
| `$DEPRECATED_MODULES` | Phase 0 | 2, 3 | Array module IDs có `action="DEPRECATE"` — KHÔNG design UI cho modules này |
| `$INTERFACE_TYPE` | Phase 0 | 0.5, 1-7 | `web` / `mobile` / `web+mobile` / `api-only` (api-only → EXIT tại Phase 0.5.0) |
| `$SYSTEMS_WITH_UI` | Phase 0 | 2, 3 | Array systems có `interface_type != api-only` |
| `$PHASE4_CONTRACT` | Phase 0 | 1, 2, 3 (scaffold-first) | Cached `doc-framework/phase4-ux/_contract.json` — required sections |
| `$LARGE_PROJECT` | Phase 0 | 1, 3, 5 | Boolean — `systems.length >= 5 OR features.length >= 40` |
| `$LPM_PARAMS` | Phase 0 | 1, 3, 5 | Object `{compression_threshold, digest_size, skeleton_threshold, max_parallel_agents, checkpoint_strategy}` |
| `$SESSION_DIR` | Phase 0 | ALL | Path session dir — `.mc-data/work/wf-design-ux/sessions/{YYYYMMDD-HHMMSS}-{hash4}/` |
| `$SESSION_ID` | Phase 0 | ALL | Session identifier — `YYYYMMDD-HHMMSS-{hash4}` |
| `$WORKLOAD_ESTIMATE` | Phase 0.5 workload | 1, 3, 4 | WorkloadEstimate object từ `_shared/partition/workload_gate.py` |
| `$GATE_RESULT` | Phase 0.5 workload | 1, 3 | GateResult — `dead_zone` / `warn` / `block` |
| `$SKILL_SKIPPED` | Phase 0.5.0 | Exit handler | Boolean — true nếu api-only skip; skill exit gracefully với 0 outputs |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint at 65/80% |
| `$AGENTS_SPAWNED` | Every phase | Phase 7 | Array — log agents đã spawn (name, phase, status) |
| `error_log[]` | All phases | Phase 7 | Array errors collected — dùng cho Auto-Correction Loop + report |

---

## Phase → File Mapping

| Phase | File | Vai trò |
|-------|------|---------|
| Phase 0 | `phase0-context.md` | Context loading, PRE-GATE, LEGACY detect, session init (ADR-OPT-02) |
| Phase 0.5 workload | `phase0.5-workload-gate.md` | Workload gate + api-only conditional skip (ADR-OPT-03) |
| Phase 0.5 legacy-ui | `phase0.5-legacy-ui-analysis.md` | Existing UI analysis (LEGACY only — đổi tên từ phase0-5-legacy-ui.md) |
| Phase 1 | `phase1-design-system.md` | Design System — brand/research/design |
| Phase 2 | `phase2-navigation.md` | Navigation Specs per system (SEQUENTIAL) |
| Phase 3 | `phase3-screen-groups.md` | Screen Groups — Lane Dispatch (PARALLEL per module, ADR-OPT-01) |
| Phase 4 | `phase4-crossval.md` | Signal Aggregation + Cross-Validation (ADR-OPT-04) |
| Phase 5 | `phase5-review.md` | Stakeholder Review (PARALLEL ux-designer + architect) |
| Phase 6 | `phase6-registry.md` | Registry Safe-Write — `ux_design_status = done` |
| Phase 7 | `phase7-digest-summary.md` | Template Strip + Atomic Write digest + phase-summary (ADR-OPT-05) |

---

## Phase Ordering by Mode

| Mode | Phases chạy | Mô tả |
|------|-------------|-------|
| **api-only** | 0 → 0.5 (skip-exit) | Skill exit tại Phase 0.5.0 — return success, 0 outputs |
| **NEW** | 0 → 0.5-workload → 1 → 2 → 3 → 4 → 5 → 6 → 7 | Dự án mới hoàn toàn |
| **LEGACY** | 0 → 0.5-workload → 0.5-legacy-ui → 1 → 2 → 3 → 4 → 5 → 6 → 7 | Dự án có sẵn |

**Branching logic:**
- Phase 0 → (luôn) → `phase0.5-workload-gate.md`
- Phase 0.5 workload → nếu api-only → **EXIT skill** (success)
- Phase 0.5 workload → nếu `$LEGACY_MODE` → `phase0.5-legacy-ui-analysis.md`; không → `phase1-design-system.md`
- Phase 0.5 legacy-ui → `phase1-design-system.md`
- Phase 1 → `phase2-navigation.md`
- Phase 2 → `phase3-screen-groups.md`
- Phase 3 → `phase4-crossval.md`
- Phase 4 → `phase5-review.md`
- Phase 5 → `phase6-registry.md`
- Phase 6 → `phase7-digest-summary.md`
- Phase 7 → END

---

## Session Isolation Protocol (ADR-OPT-02)

Mỗi skill invocation tạo session directory riêng để cô lập data, tránh ghi đè session cũ (CORE-030).

**Session directory structure:**

```
.mc-data/work/wf-design-ux/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
├── session-state.json          ← Runtime state + phase status flags
├── design-ux-status.json       ← Metrics, agents_spawned, cross_validation_log
├── checkpoint.json             ← Checkpoint cho resume
├── lanes/
│   ├── {module-slug}-screens/  ← Mỗi UI module là 1 lane
│   │   └── signals.json        ← Lane output từ ux-designer agent
│   └── ...
├── workload-report.md          ← Workload gate output (ADR-OPT-03)
├── aggregation-result.json     ← Kết quả Signal Aggregation (ADR-OPT-04)
├── ux-input-digest.json        ← Working copy (post-strip → sync sang _meta/)
└── phase-summary.md            ← CORE-028 summary

latest pointer: .mc-data/work/wf-design-ux/latest  (symlink/file trỏ tới session ID hiện tại)
Cleanup: giữ tối đa 5 sessions — xóa session cũ nhất khi vượt quá.
```

**Session ID format:** `YYYYMMDD-HHMMSS-{hash4}` (4 ký tự hex từ project-id hash).

**`latest` pointer:** Sau mỗi skill run, ghi `$SESSION_ID` vào `.mc-data/work/wf-design-ux/latest`.
`--resume` đọc `latest` để tìm session gần nhất.

**API-only sessions:** Vẫn tạo session dir (audit trail) — nhưng `ux-input-digest.json` KHÔNG tạo canonical copy.

---

## _shared Module Imports (ADR-OPT Integration)

Procedure files tham chiếu các `_shared` modules theo convention:

```python
# Import convention (pseudo-code trong procedure files)
from partition import plan_partitions, check_workload_gate
from lane import dispatch_lanes, LaneConfig
from aggregate import aggregate_lane_signals, dedup_by_id
from cdg import create_cdg_token, check_anti_loop
```

**Module paths:**

| Module | Import | Mục đích |
|--------|--------|----------|
| `_shared/partition/planner.py` | `plan_partitions(items, group_key, max_per_partition)` | Chia items thành partitions |
| `_shared/partition/workload_gate.py` | `estimate_workload(partitions, est_minutes_per_item)`, `check_workload_gate(estimate, threshold)` | Workload estimate + gate |
| `_shared/lane/dispatcher.py` | `dispatch_lanes(lanes, max_parallel, timeout_sec)`, `LaneConfig(key, agent_type, prompt, output_path, context)` | Lane dispatch parallel agents |
| `_shared/aggregate/aggregator.py` | `aggregate_lane_signals(lane_outputs, dedup_key_fn)`, `dedup_by_id(field)` | Gom kết quả từ lanes |
| `_shared/cdg/cdg_handler.py` | `create_cdg_token(action)`, `check_anti_loop()` | Critical Decision Gate tokens |

**Bash invocation:**

```bash
SHARED_DIR="$(cd "$(dirname "$0")/../../workflow/_shared" && pwd)"
python3 "$SHARED_DIR/partition/planner.py" --items-json "$ITEMS_JSON" --max-per-partition 5
```

---

## Conditional Skip Handling (api-only)

Khi `interface_type == "api-only"` (đọc từ `req-registry.json` tại Phase 0.5.0):

1. **Session vẫn được tạo** (audit trail) — cleanup sau 5 sessions như bình thường.
2. **Phase 0.5.0 exit gate:** Ghi `phases.P0_5.skipped = true`, `reason = "api-only interface"` vào session-state.json → return success với 0 canonical outputs.
3. **KHÔNG tạo `ux-input-digest.json` canonical** — `wf-plan-modules` PRE-GATE handle thiếu digest theo `00-core.md §4b` IF branch api-only.
4. **`phase-summary.md` vẫn viết:** "Skill skipped — project is api-only. Không có outputs UX."
5. **`$SKILL_SKIPPED = true`** — phases 1-7 không chạy.
6. **Session log entry:** Append SKIP (không phải FAIL, không phải COMPLETE) vào `_trace/session-log.json`.

**Downstream behavior:** `wf-plan-modules` sẽ đọc thẳng từ `/wf-design` outputs khi `ux-input-digest.json` không tồn tại (theo §4b conditional rule trong `00-core.md`).

---

## Cross-Phase Data Flow

```
Phase 0 (context)            → $LEGACY_MODE, $INTERFACE_TYPE, $SYSTEMS_WITH_UI,
                               $LARGE_PROJECT, $LPM_PARAMS, $PHASE4_CONTRACT,
                               $DEPRECATED_MODULES, $SESSION_DIR, $SESSION_ID,
                               design-ux-status.json, design-ux-plan.md
Phase 0.5-workload (gate)    → $WORKLOAD_ESTIMATE, $GATE_RESULT, workload-report.md
                               IF api-only → $SKILL_SKIPPED = true → EXIT
Phase 0.5-legacy (legacy UI) → $UI_CONTEXT_SUMMARY                     [CHỈ LEGACY_MODE]
Phase 1 (design system)      → design-system.md
Phase 2 (navigation)         → Navigation-[sys].md (per system)
Phase 3 (screens)            → screens-*.md (per module, Lane Dispatch parallel)
                               → $SESSION_DIR/lanes/{mod}-screens/signals.json
Phase 4 (crossval)           → aggregation-result.json, cross-validation-report.md
Phase 5 (review)             → stakeholder-review.md (Phần A-D)
Phase 6 (registry)           → registry.ux_design_status = "done"
Phase 7 (digest)             → $SESSION_DIR/ux-input-digest.json (strip) → _meta/ux-input-digest.json
                               → phase-summary.md, session log closed
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Large Project Mode (LPM)

> Protocol 6.6 — Khi `$LARGE_PROJECT = true`: áp dụng compression/skeleton sớm hơn, giảm parallel.

**Trigger:** `systems.length >= 5 OR features.length >= 40`

**Parameter overrides:**

| Tham số | Standard | LPM | Dùng tại |
|---------|----------|-----|----------|
| `compression_threshold` | > 3 files | > 2 files | Phase 1 (input compress), Phase 3 (agent input) |
| `digest_size` | ~200 từ/file | ~300 từ/file (Extended) | Phase 1 (feature-digest), Phase 5 (ux-digest) |
| `skeleton_threshold` | > 3000 từ | > 2000 từ | Phase 1 (design-system.md SKELETON-FIRST) |
| `max_parallel_agents` | 5 | 3 | Phase 3 (screen groups), Phase 5 (stakeholder review) |
| `checkpoint_strategy` | Per batch | Per system | Phase 3 |
| `output_targets` | Standard column | Large Project Mode column | Tất cả agent prompts |

---

## Fix Rules đặc thù

| Loại lỗi | Auto-Fix | Escalate nếu |
|-----------|----------|---------------|
| File UX không tồn tại | Tạo scaffold từ contract + re-run agent | Contract thiếu required_sections |
| File rỗng (size 0) | Re-run agent (max 3×) | Vẫn rỗng sau retry |
| Missing required section | Re-run agent với instruction bổ sung | Agent vẫn không điền |
| UI-ID duplicate | Đổi tên UI-ID trùng + update references | Ambiguous cấu trúc |
| Missing FEAT-ID reference | Tra ngược từ feature specs → add reference | Feature spec không match |
| Placeholder `<!-- TODO` | Điền từ context | Không có context → hỏi user |
| Design token mismatch | Chuẩn hóa theo design-system.md | Conflict với architecture |
| API endpoint không match | Sync với api-contract.md | api-contract.md chưa có endpoint |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

---

## Registry Safe-Write

> **Protocol 5 — chi tiết:** xem `.claude/skills/protocols/` §5.

`/wf-design-ux` CHỈ được update 1 field trong `req-registry.json`:
- `ux_design_status` (Phase 6) — set `"done"` sau khi Phase 5 PASS

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY field `ux_design_status` — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation cho toàn bộ JSON
4. VALIDATE sau ghi — `jq '.' registry.json` phải pass
5. Update trong MAIN conversation — KHÔNG spawn agent (Protocol 6.1)
```

---

## Token Limit Prevention

> **Protocol 6 — chi tiết:** xem `.claude/skills/protocols/` §6.

Áp dụng riêng cho wf-design-ux:

| Phase | Tình huống | Strategy |
|-------|------------|----------|
| Phase 1 | Feature files > `compression_threshold` | Grep key sections → `feature-digest` (~`digest_size` từ/file) |
| Phase 1 | Design system > `skeleton_threshold` | SKELETON-FIRST: Pass 1 headers + 1-2 câu/section, Pass 2 điền chi tiết |
| Phase 3 | Screen groups nhiều system | PARALLEL per system, SEQUENTIAL per module trong system |
| Phase 5 | Stakeholder review đọc > 5 screen files | Tạo `ux-digest` (~`digest_size` từ/screen-group) trước khi spawn agent |
| Phase 6 | Registry update | Write trực tiếp — KHÔNG spawn agent (Protocol 6.1) |

**Context thresholds:**
- < 65% → tiếp tục
- 65-80% → chuẩn bị checkpoint (finish current module, không start module mới)
- 80-90% → SAVE checkpoint NGAY, resume session mới
- > 90% → FORCE STOP, prompt `--resume`

---

## LEGACY Context Injection

> Áp dụng cho TẤT CẢ agent spawns trong Phase 1-5 khi `$LEGACY_MODE = true`.
> Mỗi agent prompt PHẢI inject block dưới đây ngay sau phần Context.

```markdown
---
## PROJECT REFERENCE MATERIAL (Dự án cũ — tham chiếu)
[$LEGACY_CONTEXT — Sections 1-6 của project-context.md]

## UI-SPECIFIC CONTEXT (từ Phase 0.5)
[$UI_CONTEXT_SUMMARY — screens, components, design tokens, libraries, gaps]

## Ý định của User
[.mc-data/work/wf-brainstorm/user_intent.md nếu có]

## Quyết định Cấu Trúc Dự Án
[$LEGACY_DECISIONS từ legacy-decisions.json]
- Modules DEPRECATE ($DEPRECATED_MODULES): KHÔNG thiết kế UI/UX cho modules này
- Scope exclusions: loại khỏi mọi screen specs và design flows

## Hướng dẫn sử dụng Reference Material
- trust_level = HIGH → ưu tiên sử dụng
- trust_level = MEDIUM → kiểm chứng với code trước khi dùng
- trust_level = LOW → chỉ tham khảo
- Thiếu/sai → xây dựng từ best practices
- TRÍCH XUẤT từ code hiện có, KHÔNG thiết kế lại từ đầu
---
```

**Graceful degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, hiển thị cảnh báo, tiếp tục bình thường.

---

## Agent Prompt Templates

> Templates dùng chung — phase files tham chiếu section này thay vì copy nội dung.

### P1-A: brand-guardian (Phase 1, conditional)

```
Bạn là Brand Guardian. Đảm bảo Design System tuân thủ brand identity.
Context: Architecture overview, Features, brand guidelines (nếu có trong .mc-data/knowledge-base/)
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task:
- Review brand colors → map vào design tokens
- Review typography → đảm bảo font choices align với brand voice
- Kiểm tra visual consistency across platforms (web/mobile)
- Đề xuất brand-specific component variants (buttons, cards, headers)
Output: Trả về brand compliance notes — ux-designer sẽ integrate vào design-system.md
Quality: Brand-consistent, actionable design token recommendations
Output mục tiêu: ~300–500 từ. Brand compliance notes súc tích, không lặp brand guidelines gốc.
```

### P1-B: ux-researcher (Phase 1)

```
Bạn là UX Researcher. Nghiên cứu user context trước khi thiết kế Design System.
Context: Architecture overview, Features, interface_type: [$INTERFACE_TYPE]
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task:
- Xác định user personas chính từ feature specs (roles, goals, pain points)
- Phân tích user journeys chính (happy paths, error paths)
- Đề xuất UX principles dựa trên domain và user base
- Ghi chú accessibility considerations (nếu phù hợp)
Output: Trả về research summary trực tiếp (không tạo file) — ux-designer sẽ sử dụng làm input
Quality: Actionable insights, persona-driven, domain-specific
Output mục tiêu: ~500–800 từ. Personas + journeys + UX principles, không lặp feature specs.
```

### P1-C: ux-designer (Phase 1 — Design System)

```
Bạn là ux-designer. Tạo Design System cho [project].
Context: Architecture overview, Features, interface_type: [$INTERFACE_TYPE]
Template: `.claude/doc-framework/phase4-ux/design-system.md`
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

6 sections BẮT BUỘC (minimum thresholds):
1. Màu Sắc (Colors): >= 8 color tokens (primary, secondary, accent, success, warning, error, neutral, background)
2. Chữ (Typography): >= 5 sizes (h1-h3/h4, body, caption/small)
3. Khoảng Cách (Spacing): >= 6 values theo lưới 8px (4, 8, 12, 16, 24, 32, 48...)
4. Thư Viện Component: >= 12 components (web) hoặc >= 10 components (mobile)
   — Mỗi component PHẢI có: variants, specs (size/padding/color tokens), usage guidelines
5. Bố Cục Trang (Layout): grid system, breakpoints, container widths
6. Quy Ước Giao Diện: naming conventions, icon library, animation/transition rules

Optional bonus sections (khuyến khích nếu phù hợp):
- Data Visualization Palette (nếu có charts/dashboards)
- Touch Targets & Gestures (nếu mobile)
- Dark Mode / Theming
- Accessibility (contrast ratios, focus states)

Web+mobile: Tổ chức design tokens theo 3 bảng — Shared (dùng chung), Web-only, Mobile-only.

Output: `.mc-data/docs/phase4-ux/design-system.md`
Scaffold: File đã được pre-tạo với 6 section headers — viết nội dung đầy đủ cho TẤT CẢ section headers hiện có. KHÔNG xóa hoặc đổi tên required section headers. Xóa comment `<!-- TODO: fill content -->` khi điền xong.
Quality: Non-empty, đủ 6 sections, đạt minimum thresholds, No placeholders
Ngôn ngữ: Viết tiếng Việt CÓ DẤU (ví dụ: "Màu Sắc", "Khoảng Cách")
Output mục tiêu: ~1500–2500 từ. Đủ 6 sections với minimum thresholds, không lặp requirements context.
```

### P2-A: ux-architect (Phase 2, per system)

```
Bạn là UX Architect. Thiết kế CSS architecture và layout framework cho system [SYS-XXX].
Context: Design system, Architecture overview, Features cho system này
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task:
- CSS architecture: naming convention (BEM/utility-first), file organization, theming strategy
- Layout framework: grid system, breakpoints, container strategy, responsive patterns
- Component boundaries: nơi nào dùng component nào, CSS isolation strategy
- Responsive strategy: mobile-first hay desktop-first, breakpoint transitions
Output: Trả về CSS/layout specs — merge vào Navigation-[sys].md (section Layout & Responsive)
Quality: Actionable CSS architecture, consistent với design-system.md tokens
Output mục tiêu: ~500–800 từ. CSS architecture + layout specs, không lặp design-system tokens.
```

### P2-B: ux-designer (Phase 2 — Navigation, per system)

```
Bạn là ux-designer. Tạo Navigation spec cho system [SYS-XXX] — [System Name].
Context: Design system, Architecture overview, Features cho system này, API contract
Template: `.claude/doc-framework/phase4-ux/[system-name]/Navigation-[system].md`
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

4 sections chính BẮT BUỘC:
1. Sơ Đồ Menu (Menu Tree) — hierarchical menu structure với routes
2. Danh Sách Screen Groups — bảng liệt kê tất cả screen groups, mỗi entry có: tên, mô tả, route, module
3. Phân Quyền & Hiển Thị Menu — role-based visibility matrix
4. UI Notes — Quick Actions, Breadcrumb Pattern, Naming Conventions, Icon Library

1 section CONDITIONAL (thêm khi phù hợp):
5. Platform-Specific Navigation — Bottom Tab Bar (mobile), Sidebar (web), Drawer (tablet)

Output: `.mc-data/docs/phase4-ux/[sys]/Navigation-[sys].md`
Scaffold: File đã được pre-tạo với section headers — viết nội dung đầy đủ cho TẤT CẢ sections hiện có. KHÔNG xóa hoặc đổi tên required section headers. Xóa comment `<!-- TODO: fill content -->` khi điền xong.
Quality: Non-empty, đủ 4 sections chính, routes khớp với api-contract,
         mỗi screen group trong Navigation PHẢI có tương ứng trong Phase 3 output, No placeholders
Ngôn ngữ: Viết tiếng Việt CÓ DẤU (ví dụ: "Sơ Đồ Menu", "Phân Quyền")
Output mục tiêu: ~800–1200 từ/system. Menu tree + screen groups + permissions, không lặp feature specs.
```

### P3: ux-designer (Phase 3 — Screen Groups, per module)

```
Bạn là ux-designer. Tạo Screen Group specs cho module [MOD-XXX] trong system [SYS-XXX].
Context: Navigation spec, Design system, Features, API contract
Template: `.claude/doc-framework/phase4-ux/[system-name]/[module-name]/[screen-group].md`
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

7 sections BẮT BUỘC:
1. Main Page Layout — ASCII wireframe (PHẢI có real content, không placeholder)
2. Tabs (T1...) — tab definitions, hoặc "N/A" nếu không có tabs
3. Dialogs/Popups (D1...) — dialog specs, hoặc "N/A" nếu không có
4. Sheets/Drawers (S1...) — sheet specs, hoặc "N/A" nếu không có
5. View Modes (M1...) — mode specs, hoặc "N/A" nếu không có
6. API Endpoints Used — PHẢI list real endpoints từ api-contract.md, không placeholder
7. UI-ID Registry — PHẢI có bảng đầy đủ với real UI-IDs, không placeholder

Minimum substantive: sections 1, 6, 7 PHẢI có nội dung thực (real wireframe, real endpoints, real UI-IDs).
Sections 2-5 có thể "N/A" nếu module không cần, nhưng PHẢI ghi lý do (vd: "N/A — module này chỉ hiển thị single-view dashboard, không cần tabs"). Không được để trống hoặc placeholder.

FEAT-ID Traceability: Mỗi screen group PHẢI reference ít nhất 1 FEAT-ID hoặc REQ-ID
từ feature specs. Ghi ở đầu file: "Implements: FEAT-XXX-001, FEAT-XXX-002"

UI-ID format: UI-[SYS]-[MOD]-[SCREEN]-NNN (sub-IDs: T/D/S/M suffix)
Tạo 1 file per screen group theo Navigation spec.
Output: `.mc-data/docs/phase4-ux/[sys]/[mod]/[screen-group].md`
Scaffold: File đã được pre-tạo với section headers (required + optional). Viết nội dung đầy đủ cho TẤT CẢ required sections. Optional sections ("Optional — xóa nếu không có"): giữ lại và điền nếu module có tính năng đó, xóa bỏ hẳn nếu không cần. KHÔNG xóa required section headers.
Quality: Non-empty, đủ 7 sections, substantive minimums met, FEAT-IDs present,
         UI-IDs unique, API endpoints khớp, No placeholders
Ngôn ngữ: Viết tiếng Việt CÓ DẤU (ví dụ: "Bố Cục Trang", "Danh Sách")
Output mục tiêu: ~800–1500 từ/screen-group. Tập trung vào layout + components + interactions.
```

### P5-A: ux-designer (Phase 5 — Review Phần B+C)

```
Bạn là ux-designer. Thực hiện Stakeholder Review (Phần B + C) cho UX Design.
Context: design-system.md + Navigation-*.md + screen groups + feature specs (hoặc ux-digest nếu > 5 files)
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Phần B (SO-01): UX Cross-Review — design system usage, navigation completeness, UI-ID uniqueness
Phần C (SO-02): Consistency Check — so với feature specs, architecture, API contract

Severity definitions cho UX findings:
- Critical: Missing core screen, broken navigation flow, accessibility violation (WCAG A)
- High: Inconsistent design system usage, missing required component, broken API integration
- Medium: Minor UX friction, suboptimal layout, partial inconsistency
- Low: Cosmetic issue, suggestion for improvement, nice-to-have enhancement

Output: `.mc-data/work/wf-design-ux/_tmp-so-bc.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD
Output mục tiêu: ~800–1200 từ. Findings súc tích, severity + recommendation, không lặp UX specs.
```

### P5-B: architect (Phase 5 — Review Phần D)

```
Bạn là architect. Thực hiện Gap Analysis (Phần D) cho UX Design.
Context: design-system.md + Navigation-*.md + screen groups + P3-01-architecture.md
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Phần D (SO-03): Gap Analysis — missing screens, accessibility gaps, responsive issues, NFR coverage
Output: `.mc-data/work/wf-design-ux/_tmp-so-d.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD
Output mục tiêu: ~500–800 từ. Gap analysis súc tích, severity + recommendation, không lặp architecture specs.
```

### P4: accessibility-auditor (Phase 4 — Cross-Validation)

```
Bạn là accessibility-auditor. Audit WCAG compliance cho UX Design.
Context: design-system.md + screen groups
Task:
- WCAG 2.1 AA compliance check: contrast ratios, focus states, keyboard navigation, ARIA labels
- Color-blind safe palette verification
- Touch target minimum (44×44 px mobile)
- Screen reader compatibility (semantic HTML/ARIA)
Output: Accessibility report với findings (severity + fix suggestion)
Output mục tiêu: ~400–700 từ. Findings súc tích, actionable.
```

---

## Checkpoint Protocol

> Mọi checkpoint PHẢI dùng template `templates/checkpoint.json` theo pattern READ → POPULATE → WRITE.

**Schema:** `$schema: design-ux-checkpoint-v1` (canonical trong template).

**Key fields cần populate:**
- `trigger` — sự kiện khởi tạo checkpoint (phase completion, context threshold, user interrupt)
- `scope` — phạm vi đã xử lý (systems, modules)
- `position` — vị trí hiện tại (current_phase, current_step)
- `progress` — progress counters (files_created, agents_spawned, errors_fixed)
- `systems_state` — array state per system
- `files_state` — array state per file output
- `next_action` — phase/step tiếp theo sau resume

**Khi nào SAVE:**
- Cuối mỗi Phase (1, 2, 3, 5 đều có step SAVE CHECKPOINT ở cuối)
- Phase 3: per batch (Standard) hoặc per system (LPM)
- Context >= 65%: chuẩn bị checkpoint (finish current unit, không start mới)
- Context >= 80%: FORCE SAVE NGAY, resume session mới với `--resume`

**Atomic Write Pattern (BẮT BUỘC):**
Khi ghi checkpoint/status JSON, dùng pattern WRITE-THEN-RENAME để tránh corrupt khi interrupt:
1. WRITE nội dung vào tmp file (ví dụ `checkpoint.json.tmp`)
2. RENAME tmp → target file (`mv checkpoint.json.tmp checkpoint.json`)
3. Pattern này đảm bảo target file luôn ở trạng thái hợp lệ (hoặc cũ hoặc mới, không bao giờ partial)

**Path:**
- Standard: `.mc-data/work/wf-design-ux/checkpoint.json`
- LEGACY_MODE: fallback sang `.mc-data/work/legacy-scan/ux-checkpoint.json` (nếu wf-design-ux/ không có)

---

## LEGACY_MODE Detection

Theo CORE-021 (BẮT BUỘC):

```bash
LEGACY_MODE=$(test -f .mc-data/work/legacy-scan/project-context.md \
  && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 \
  && echo "true" || echo "false")
```

**KHÔNG** detect bằng `ledger.json` (false positive — tồn tại từ Stage 0.5).
**KHÔNG** detect bằng check khác giữa các skills.

Khi `LEGACY_MODE = true`:
- Phase 0.5 chạy (Existing UI Context) — tạo `$UI_CONTEXT_SUMMARY`
- Mọi agent spawn trong Phase 1-5 phải inject LEGACY BLOCK (xem §LEGACY Context Injection)
- Output paths giữ nguyên như standard flow + thêm:
  - `.mc-data/docs/phase4-ux/existing-ui-analysis.md`
  - `.mc-data/docs/phase4-ux/[system]/screen-inventory.md`
  - `.mc-data/docs/phase4-ux/design-tokens-baseline.md`
  - `.mc-data/work/legacy-scan/ux-implementation-gap.md`
- Modules thuộc `$DEPRECATED_MODULES` bị loại khỏi mọi output (requirements, features, UX specs)
