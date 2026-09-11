# /wf-diagram — Phase 1: Pre-check Existing Diagrams

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.

---

## PRE-GATE

```
- [ ] Phase 0 hoàn tất (diagram-status.phases.phase_0.status == "done")
- [ ] $output_path tồn tại (test -d)
```

---

## Steps

### 1.1 — Resolve $system_dir + Check System Diagrams

```bash
# Resolve $system_dir theo $scope (v1.2.0 module-scoped layout)
if [ "$scope" = "system-only" ]; then
  system_dir="$output_path/_system"
else
  system_dir="$output_path/modules/$module/_system"
fi

system_files=("context.md" "component.md" "erd-context-map.md" "actors.md" "database.dbml")
system_missing=()
for f in "${system_files[@]}"; do
  test -f "$system_dir/$f" || system_missing+=("$f")
done
```

### 1.2 — Check Module Diagrams

```bash
# Chỉ check nếu scope có module
if [[ "$scope" =~ ^(full|module-only)$ ]]; then
  test -d "$output_path/modules/$module" && module_exists=true || module_exists=false
fi
```

### 1.3 — CDG-02 nếu module diagrams đã tồn tại (Protocol 16)

```
NẾU $module_exists == true:
  AskUserQuestion:
    "Module `$module` đã có diagram tại $output_path/modules/$module/.
     Hành động:
     (a) Ghi đè toàn bộ
     (b) Bỏ qua module này
     (c) Chỉ cập nhật phần thiếu (giữ nguyên file đã có)"
  → user_choice ∈ {overwrite, skip, update_missing}

NẾU $module_exists == false:
  user_choice = null  # Không có conflict
```

### 1.4 — Save User Decision

```
Edit diagram-status.json:
  user_decisions.module_conflict = $user_choice (or null)
  phases.phase_1.status = "done"
```

---

## POST-GATE

```
- [ ] $system_missing[] đã xác định
- [ ] $user_choice resolved (hoặc null nếu không có conflict)
- [ ] phases.phase_1.status = "done" trong diagram-status.json
```

---

## Behavior theo user_choice

| user_choice | Hành vi Phase 5+6 | Phase 4 |
|-------------|-------------------|---------|
| `overwrite` | Generate full, overwrite existing | Chạy nếu $plan.system_files có entries |
| `skip` | Skip Phase 5+6 hoàn toàn | Chạy nếu cần (system files thiếu) |
| `update_missing` | Chỉ generate file chưa tồn tại | Chỉ generate $system_missing |
| `null` | Generate full (fresh run) | Chạy nếu $plan.system_files có entries |

---

## Next Phase

→ Phase 2: `procedures/phase2-source-analysis.md` (Source Code Analysis)
