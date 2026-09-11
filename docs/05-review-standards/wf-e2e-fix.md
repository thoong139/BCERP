# Tiêu chuẩn rà soát — `wf-e2e-fix` (v?.?.?)

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-e2e-fix/`
> **Phiên bản rà soát:** 0.1 (SCAFFOLD — chưa hoàn thiện)

> ⚠️ **TRẠNG THÁI:** SCAFFOLD ONLY. Cần review skill thực tế để populate các sections.

File này chỉ viết **Skill Profile** và **Extension section**. Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Auto-fix E2E test failures |
| **Entry point** | TODO |
| **Kiến trúc** | TODO |
| **Execution mode** | TODO (SEQUENTIAL / PARALLEL / HYBRID) |
| **Branching** | TODO |
| **Đặc trưng** | TODO |
| **Output** | TODO |
| **Cross-skill** | TODO (X producer, Y consumer) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-e2e-fix
  version: TODO
  review_version: 0.1
  path: .claude/skills/workflow/wf-e2e-fix/

profile:
  # TODO: điền sau khi đọc SKILL.md + _contract.json
  is_orchestrator: false
  has_procedures: true
  has_templates: true
  has_phases: true

  has_state_machine: false
  has_resume: false
  has_status: false
  is_multi_run: false

  spawns_agents: false
  has_strategy_routing: false

  writes_registry: false
  registry_role: NONE  # PRIMARY|SEED|APPEND|SAFE-UPDATE|FIX-INVALID|UPDATE-MODE|NONE
```

---

## 2. Nhóm tiêu chuẩn áp dụng

| Nhóm | Tên | Áp dụng | Ghi chú |
|------|-----|---------|---------|
| A | Common Core | ✅ | Luôn áp dụng |
| B | Conditional (state/resume) | TODO | Theo profile |
| C | Templates & Output | TODO | Theo profile |
| D | Quality Gates | ✅ | Luôn áp dụng |
| E | Error Handling | ✅ | Luôn áp dụng |
| F | Cross-Skill | TODO | Nếu có cross-skill artifacts |
| H | Documentation | ✅ | Luôn áp dụng |
| I | Compliance Audit | ✅ | Luôn áp dụng |
| J | Performance | TODO | Theo profile |

---

## 3. Extension section (NHÓM G — skill-specific)

> TODO: liệt kê tiêu chuẩn đặc thù không nằm trong common template.
>
> Ví dụ:
> - Strategy routing (nếu có): S1-S7 evaluation
> - Cross-skill contracts đặc biệt: paths ownership riêng
> - Constraint đặc biệt: READ-ONLY output, exclusive ownership

---

## 4. Quick-check đặc thù

> TODO: bổ sung quick-check ngoài common §6 nếu có.

---

## 5. Liên kết

- Skill source: [`.claude/skills/workflow/wf-e2e-fix/`](../../.claude/skills/workflow/wf-e2e-fix/)
- Skill design: [`../04-skill-design/wf-e2e-fix/`](../04-skill-design/wf-e2e-fix/) (nếu có)
- User guide: [`../06-user-guides/per-skill/`](../06-user-guides/per-skill/) (nếu có)
- Common template: [`_template-common.md`](./_template-common.md)
