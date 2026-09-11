# Phase 1: Registry Validation + Phase 1.7: Upstream Coverage Validation

> Validate registry, xác định mode (Simple/Lite/Full), kiểm tra upstream coverage.

> **Shared context:** xem `_shared.md` — State Variables Glossary (`$MODULE_COUNT`, `$MODE`, `$SYSTEM_COVERAGE_MAP`, `$COVERAGE_STRATEGY`).

---

## Phase 1: Registry Validation

**PRE-GATE:** `test -f ".mc-data/docs/_meta/req-registry.json"`

> **Forensic validation (Protocol 10.4):** P3-01-architecture.md: >= 7 headings, >= 500 words.
> Nếu FAIL → "P3-01-architecture.md không đạt yêu cầu nội dung. Chạy `/wf-design` để hoàn thiện."

**📥 INPUT:** `.mc-data/docs/_meta/req-registry.json` (danh sách systems, modules, departments)

> Phase này xử lý in-memory — không tạo/cập nhật file nào.

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | Đọc `req-registry.json` → parse JSON → extract modules | `test $MODULE_COUNT -gt 0` |
| 1.2 | Parse arguments | — |
| 1.3 | Xác định chế độ dựa trên số modules | `$MODE` set |

**Chế độ theo số modules:**

| Modules | `$MODE` | Hành vi |
|---------|---------|---------|
| 1 | **Simple** | Roadmap đơn giản, 1 sprint, bỏ qua dependency graph |
| 2 | **Lite** | Roadmap + dependency check giữa 2 modules, 1-2 sprints |
| 3+ | **Full** | Full dependency graph, topological sort, multi-sprint |

### [PLN] Task Planning (Full mode only, >= 3 modules)

```
IF $MODULE_COUNT >= 3 (Full mode):
  Tạo brief execution plan và ghi vào planmod-status.json:
  - module_count: N
  - estimated_complexity: Simple/Medium/Complex (dựa trên module count + dependency density)
  - dependency_analysis_scope: "full graph + topological sort + cycle detection"
  - estimated_phases: Phase 2-7 + 7.5 + 7a + 7b
  - token_budget:
      read_files: N * 2K (feature files per module)
      agents: 2 * 10K (architect + qa-lead ở Phase 7b)
      output_files: (N + sprints + task_files) * 5K
      validations: 2 * 4K (Phase 7a + 7b loops)
      estimated_total: Σ trên
      context_verdict: "✅ Đủ budget" | "⚠️ Cần checkpoint" | "⛔ Chia sessions"

ELSE (Simple/Lite mode):
  SKIP planning — quy trình đủ nhỏ để xử lý trực tiếp
```

**POST-GATE:** `test $MODULE_COUNT -ge 1`

---

## Phase 1.7: Upstream Coverage Validation (BẮT BUỘC — mọi mode)

> Kiểm tra tính đầy đủ của registry upstream: mỗi system đăng ký có ít nhất 1 module,
> mỗi module có ít nhất 1 feature. Phát hiện "orphan systems" và "orphan modules".
>
> Lý do: Tôn trọng CORE-023 (Priority Order) + CORE-024 (downstream grounded). Im lặng
> bỏ qua orphan systems sẽ gây mâu thuẫn nội bộ Phase 5 (overview liệt kê 5 systems
> nhưng planning chỉ có 3) — gây hiểu lầm nghiêm trọng cho stakeholder.

**PRE-GATE:** `test $MODULE_COUNT -ge 1` (đã pass Phase 1)

**📥 INPUT:** `req-registry.json` (in-memory từ Phase 1)

> Output là `$SYSTEM_COVERAGE_MAP` (in-memory) + ghi summary vào `planmod-status.json`.

| Step | Action | Verify |
|------|--------|--------|
| 1.7.1 | Build `$SYSTEM_COVERAGE_MAP` (xem §Build Coverage Map) | Map built |
| 1.7.2 | Phân loại systems: `covered[]`, `orphan_systems[]`, `modules_without_features[]` | Categorization done |
| 1.7.3 | Hiển thị System Coverage table cho user | User reviewed |
| 1.7.4 | Nếu có orphan → ESCALATE user (xem §Escalation Logic) | Decision captured |
| 1.7.5 | Ghi `system_coverage` section vào `planmod-status.json` | Status updated |

---

### §Build Coverage Map (Step 1.7.1 chi tiết)

```
// Chấp nhận cả 3 field name conventions:
//   sys_id (EUREKA-style), system_id (verify-sync-style), system (template-style)
get_sys_field(module) = module.sys_id // module.system_id // module.system // null

// Group modules by system
modules_by_system = {}
FOR each module IN registry.modules:
  sys = get_sys_field(module)
  IF sys != null:
    modules_by_system[sys] = modules_by_system[sys] ++ [module.id]

// Group features by module
features_by_module = {}
FOR each feature IN registry.features:
  mod = feature.module_id
  IF mod != null:
    features_by_module[mod] = features_by_module[mod] ++ [feature.id]

// Build coverage map
$SYSTEM_COVERAGE_MAP = []
FOR each system IN registry.systems:
  modules_in_sys = modules_by_system[system.id] // []
  features_count = Σ len(features_by_module[m]) for m in modules_in_sys
  entry = {
    sys_id: system.id,
    name: system.name,
    modules_count: len(modules_in_sys),
    features_count: features_count,
    status: (modules_count == 0) ? "ORPHAN_SYSTEM"
            : (features_count == 0) ? "NO_FEATURES"
            : "COVERED"
  }
  $SYSTEM_COVERAGE_MAP ++= [entry]
```

---

### §System Coverage Display (Step 1.7.3 chi tiết)

```
📊 System Coverage (Registry Upstream Check)
────────────────────────────────────────────────────
| System            | Modules | Features | Status       |
|-------------------|---------|----------|--------------|
| SYS-BACKEND       | 13      | 38       | ✅ COVERED   |
| SYS-WEB-CUSTOMER  | 1       | 5        | ✅ COVERED   |
| SYS-MOBILE-CUSTOMER| 1      | 2        | ✅ COVERED   |
| SYS-ERP-WEB       | 0       | 0        | ⚠️ ORPHAN    |
| SYS-MOBILE-STAFF  | 0       | 0        | ⚠️ ORPHAN    |
────────────────────────────────────────────────────
Coverage: 3/5 systems planned (60%)
```

---

### §Escalation Logic (Step 1.7.4 chi tiết)

```
IF len(orphan_systems) > 0 OR len(modules_without_features) > 0:
  Hiển thị cảnh báo:
    "⚠️ UPSTREAM GAP phát hiện:
     - [N] systems trong registry KHÔNG có modules tương ứng: [sys_ids]
     - [M] modules trong registry KHÔNG có features tương ứng: [mod_ids]

     Nguyên nhân có thể:
     (a) /wf-analyze-requirements chưa tạo modules cho system này
     (b) /wf-define-features chưa được chạy với scope đầy đủ
     (c) System/module là thin client của system khác — không cần features riêng

     Lựa chọn của bạn:
     [1] STOP — dừng để chạy lại /wf-analyze-requirements hoặc /wf-define-features
     [2] CONTINUE with placeholders — tạo _NO-FEATURES.md placeholder cho orphan systems
         (Phase 5 docs sẽ ghi rõ systems nào orphan + nguyên nhân)
     [3] MARK as thin-clients — ghi decision vào planmod-status.json.thin_client_systems
         (Phase 5 docs sẽ loại bỏ orphan systems khỏi overview)"

  Chờ user chọn → ghi vào $USER_COVERAGE_DECISION
  IF choice == STOP → exit skill với E012 (xem Error Handling SKILL.md)
  IF choice == CONTINUE → set $COVERAGE_STRATEGY = "placeholders"
  IF choice == MARK → set $COVERAGE_STRATEGY = "thin_clients" + yêu cầu user
                      nhập lý do cho từng orphan system
ELSE:
  $COVERAGE_STRATEGY = "full"  // Tất cả systems đều có modules
```

---

## POST-GATE (Phase 1.7)

- `$SYSTEM_COVERAGE_MAP` non-empty
- `$COVERAGE_STRATEGY` ∈ {"full", "placeholders", "thin_clients"}
- Nếu có orphan → user decision được log vào `planmod-status.json`

---

## Next

→ Checkpoint: position → `phase_1.5` (legacy) hoặc `phase_2`
→ Nếu `$LEGACY_MODE = true` → Read `procedures/phase1.5-legacy-impl.md`
→ Else → Read `procedures/phase2-deps.md`
