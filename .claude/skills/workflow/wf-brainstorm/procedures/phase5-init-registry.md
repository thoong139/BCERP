# Phase 5: Khởi Tạo Cấu Trúc Dự Án (TỰ ĐỘNG)

> **Giai đoạn tự động** — KHÔNG hỏi user.
> Chỉ tạo cấu trúc TỐI THIỂU cần thiết cho Phase 0 và seed `req-registry.json`.
> Các folder/file của phase sau sẽ được tạo khi skill tương ứng chạy — tránh gây loãng cấu trúc.
> _(Trước đây là skill `/wf-start-project` riêng — đã merge vào đây vì chỉ là scaffolding.)_

**PRE-GATE:**

- [ ] Phase 4 (phase4-write-docs.md) POST-GATE PASS
- [ ] `P0-01-brainstorm.md` và `P0-02-systems-users.md` đã tồn tại
- [ ] `crosscheck-report.md` đã được tạo

**INPUT:**
- Context Phase 1+2 (project_name, active_depts[], platform)
- P0-01-brainstorm.md, P0-02-systems-users.md
- Optional: legacy-decisions.json (nếu LEGACY)

**OUTPUT:**
- `.mc-data/docs/_meta/req-registry.json` (seeded)
- `.mc-data/work/wf-brainstorm/project-intent-digest.json` (handoff Phase 1)
- `.mc-data/sync/.gitkeep`

---

## Reference Sections

- `_shared.md` §3 Template Usage Rule
- `_shared.md` §13 Platform → interface_type Mapping
- `00-core.md` §4a Registry Safe-Write Protocol (chỉ seed `project`, `departments[]`, `interface_type`, metadata khởi tạo)

---

## Step 5.1: Tạo Cấu Trúc Thư Mục Tối Thiểu

> Skip dirs đã tồn tại từ Phase 3+4.

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.1 | Tạo cấu trúc thư mục tối thiểu (xem bảng bên dưới) | Bash | Tất cả dirs tồn tại |

**Cấu trúc TỐI THIỂU cần tạo (chỉ cho Phase 0):**

```
.mc-data/
├── docs/
│   ├── _meta/                          ← req-registry.json (step 5.2)
│   └── phase0-brainstorm/              ← Đã tạo ở Phase 3+4
├── work/
│   └── wf-brainstorm/                  ← Đã tạo ở Phase 3
└── sync/
    └── .gitkeep
```

**Bash command:**

```bash
mkdir -p .mc-data/docs/_meta
mkdir -p .mc-data/sync
touch .mc-data/sync/.gitkeep
```

**KHÔNG tạo trước các folder phase sau.** Mỗi skill tự tạo folder khi chạy:

| Skill                        | Tự tạo khi chạy                                                                        |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `/wf-analyze-requirements` | `phase1-business/`, `phase1-business/departments/`, `work/wf-analyze-requirements/` |
| `/wf-define-features`      | `phase2-features/`, `work/wf-define-features/`                                        |
| `/wf-design`               | `phase3-architecture/`, `phase3-architecture/technical-specs/`, `work/wf-design/`   |
| `/wf-design-ux`            | `phase4-ux/`, `phase4-ux/ux/`, `work/wf-design-ux/`                                 |
| `/wf-plan-modules`         | `phase5-implementation/`, `phase5-implementation/{sprints,tasks}/`                    |
| `/wf-implement-feature`    | `work/wf-implement-feature/`                                                            |
| `/wf-prepare-deployment`   | `phase6-deployment/`                                                                    |

---

## Step 5.2: Copy Registry Template

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.2 | Copy `req-registry.json` template từ `.claude/doc-framework/_meta/req-registry.json` → `.mc-data/docs/_meta/req-registry.json` (nếu chưa tồn tại) | Bash / Write | `test -f .mc-data/docs/_meta/req-registry.json` |

---

## Step 5.3: Seed Registry (Safe-Write — chỉ phân công field)

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.3 | Seed `req-registry.json`: thay `[PROJECT_NAME]` bằng `$project_name`, cập nhật `last_updated`, seed `departments[]` từ `active_depts[]` (Phase 2), seed `interface_type` từ `platform` (Phase 1) dùng mapping tại `_shared.md` §13 | Write | `grep -q "$project_name" .mc-data/docs/_meta/req-registry.json` |
| 5.3-SYS | **Seed `systems[]` (System Scope Matrix — BẮT BUỘC):** Với mỗi hệ thống liệt kê trong P0-02 §1 "Bản Đồ Hệ Thống" / P0-01 §3.1, tạo 1 entry trong `systems[]` với **đầy đủ fields** bên dưới. Đây là bridge giữa brainstorm declaration và downstream per-system coverage. Nếu skill quên seed → `/wf-analyze-requirements` sẽ thiếu input và các system sẽ bị bỏ qua (root cause của bug "features thiếu trên mobile-staff/mobile-customer"). | Write | `jq -e '.systems \| length > 0' .mc-data/docs/_meta/req-registry.json` |

**Schema bắt buộc cho mỗi entry `systems[]` (seed):**

```json
{
  "id": "SYS-<SLUG>",               // id ổn định — kebab-case hoặc UPPER
  "name": "<Tên hiển thị>",         // từ P0-02 §1
  "description": "<Mô tả ngắn>",    // 1 câu
  "user_roles": ["..."],            // BẮT BUỘC ≥ 1 — từ P0-02 §2 Users & Roles
  "touchpoints": ["web|mobile|api|desktop"],  // BẮT BUỘC ≥ 1 — kênh tương tác
  "related_departments": ["DEPT-..."],         // BẮT BUỘC — departments phục vụ system (từ matrix dept×system)
  "phase": "MVP|Phase2|Phase3",     // từ roadmap brainstorm
  "depends_on": [],                 // optional
  "module_ids": []                  // để rỗng — sẽ enrich ở Phase 8 analyze-requirements
}
```

**Quy tắc seed `systems[]`:**

1. **Mọi hệ thống declare trong P0-02 §1 PHẢI có entry** — không bỏ sót (vd: `mobile-staff`, `web-customer`, `mobile-customer` đều PHẢI được seed dù chung department).
2. **`touchpoints[]` không được rỗng** — giúp `/wf-define-features` fan-out đúng. Ví dụ: `web-customer` → `["web"]`, `mobile-customer` → `["mobile"]`, `mobile-staff` → `["mobile"]`, `erp` web → `["web"]`, api backend → `["api"]`.
3. **`related_departments[]` phải cross-reference với `departments[]`** — mỗi system có ≥ 1 department. Nếu một system có touchpoint tách biệt department (vd: `mobile-customer` dùng chung DEPT-CX nhưng là system riêng) → vẫn ghi `related_departments: ["DEPT-CX"]`.
4. **Gợi ý heuristic fill `user_roles[]` + `touchpoints[]`:** Đọc P0-02 §2 Users & Roles, match role với system theo mô tả. Nếu ambiguous → ghi `[Cần xác nhận]` vào P0-01 §3.1 và tiếp tục seed.

**Ví dụ seed cho dự án logistics 4 hệ thống (EUREKA-style):**

```json
[
  {"id": "erp", "name": "EUREKA ERP", "user_roles": ["Admin", "Sales", "Ops"], "touchpoints": ["web"], "related_departments": ["DEPT-SALES","DEPT-TMS","DEPT-WMS","DEPT-FINANCE"], "phase": "MVP", "module_ids": []},
  {"id": "mobile-staff", "name": "Mobile Staff App", "user_roles": ["Tài xế","Nhân viên kho","Giao nhận"], "touchpoints": ["mobile"], "related_departments": ["DEPT-TMS","DEPT-WMS"], "phase": "MVP", "module_ids": []},
  {"id": "web-customer", "name": "Customer Portal", "user_roles": ["Customer B2B","Customer B2C"], "touchpoints": ["web"], "related_departments": ["DEPT-CX","DEPT-SALES"], "phase": "MVP", "module_ids": []},
  {"id": "mobile-customer", "name": "Mobile Customer App", "user_roles": ["Customer B2C"], "touchpoints": ["mobile"], "related_departments": ["DEPT-CX"], "phase": "Phase2", "module_ids": []}
]
```

> **§13 mapping (BẮT BUỘC):**
> - Web → `"web"`
> - Mobile → `"mobile"`
> - Cả hai → `"web+mobile"`
> - API only → `"api-only"`
> - Chưa xác định → `"web"` (default + ghi chú `[Cần xác nhận]` vào P0-01 §1)

---

## Step 5.3b: Cross-Validate Registry ↔ P0-01/P0-02 (Protocol 8)

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.3b | Verify `departments[]` trong registry == phòng ban trong P0-01 §2; verify `interface_type` == platform trong P0-01 §1; verify `systems[]` trong registry == hệ thống trong P0-02 §1 (đủ số lượng, khớp tên). Nếu mismatch → fix registry (docs là source ở Phase 0) | Read + Write | Registry departments + systems khớp P0-01/P0-02 |

---

## Step 5.3c: Tạo `project-intent-digest.json` (Handoff cho Phase 1)

> Template Usage Rule (§3): READ → POPULATE → WRITE.

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.3c.1 | READ `.claude/skills/workflow/wf-brainstorm/templates/project-intent-digest.json` | Read | Template loaded |
| 5.3c.2 | POPULATE: `project_name`, `project_type`, `project_goal`, `industry`, `company_size`, `platform`, `interface_type`, `active_departments`, `systems`, `modules`, `actors`, `pain_points`, `scope_in`, `scope_out`, `assumptions`, `open_questions`, `handoff_notes`, `next_skill = "/wf-analyze-requirements"`. Nguồn sự thật: P0-01, P0-02, `legacy-decisions.json` (nếu có) | — | Fields populated |
| 5.3c.3 | WRITE `.mc-data/work/wf-brainstorm/project-intent-digest.json` | Write | `test -f project-intent-digest.json` |

---

## Step 5.4: Sync Marker

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 5.4 | Tạo `.mc-data/sync/.gitkeep` (đã tạo ở Step 5.1, idempotent) | Bash | `test -f .mc-data/sync/.gitkeep` |

---

## POST-GATE Phase 5

- T1: `test -f .mc-data/docs/_meta/req-registry.json`
- T2: `test -s .mc-data/docs/_meta/req-registry.json`
- T3: `jq -e '.project != "[PROJECT_NAME]" and (.departments | length > 0) and (.interface_type | length > 0)' .mc-data/docs/_meta/req-registry.json`
- T3-SYS: `jq -e '(.systems | length > 0) and all(.systems[]; (.user_roles // [] | length > 0) and (.touchpoints // [] | length > 0) and (.related_departments // [] | length > 0))' .mc-data/docs/_meta/req-registry.json` — **BẮT BUỘC**: mọi system phải có user_roles + touchpoints + related_departments không rỗng
- T3-SYS-MATCH: `jq -r '.systems[].id' .mc-data/docs/_meta/req-registry.json | sort -u | diff -q - <(grep -E "^\| +[a-z0-9\-]+ +\|" .mc-data/docs/phase0-brainstorm/P0-02-systems-users.md | awk -F'|' '{gsub(/ /,"",$2); print $2}' | sort -u) || WARN "systems[] mismatch với P0-02 §1 — verify hand-seeding"` (soft check — chỉ warn nếu tên không khớp)
- T4: `test -f .mc-data/work/wf-brainstorm/project-intent-digest.json`
- T5: `jq -e '.next_skill == "/wf-analyze-requirements"' .mc-data/work/wf-brainstorm/project-intent-digest.json`
- T6: `test -d .mc-data/docs/phase0-brainstorm && test -d .mc-data/sync`

> **STATUS-UPDATE(done: phase_5 → start: phase_6):** Update `brainstorm-status.json`:
> - `phases.phase_5.status = "done"`, `phases.phase_5.completed_at = NOW`
> - `current_phase = "phase_6"`, `phases.phase_6.status = "in_progress"`
> - `timestamps.last_updated = NOW`
> - `artifacts.project_intent_digest.created = true`, `artifacts.req_registry.created = true`

---

## Next Phase

→ **`phase6-generate-digest.md`** (Sinh Digest Artifact — TỰ ĐỘNG, phase cuối)
