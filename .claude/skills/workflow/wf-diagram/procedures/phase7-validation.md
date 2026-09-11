# /wf-diagram — Phase 7: Validation & Output Report

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.

---

## PRE-GATE

```
- [ ] Phase 0-6 hoàn tất theo $scope (check phases.phase_N.status == "done")
```

---

## Steps

### 7.1 — POST-GATE T1: Existence (Protocol 10)

```bash
all_pass=true

# System + module base files
FOR each file IN $plan.{system_files, module_files}:
  test -s "$file_path" || { all_pass=false; log_error "E007" "$file missing or empty"; }

# Usecase group files
FOR each group IN $plan.usecase_groups:
  slug="${group.group_slug}"
  test -s "$output_path/modules/$module/usecases/$slug.md" || {
    all_pass=false; log_error "E007" "usecases/$slug.md missing";
  }

# Detail diagram files
FOR each sm IN $plan.states:
  test -s "$output_path/modules/$module/states/$(slugify $sm.entity).md" || all_pass=false
FOR each proc IN $plan.activities:
  test -s "$output_path/modules/$module/activities/$(slugify $proc.name).md" || all_pass=false
FOR each scen IN $plan.sequences:
  test -s "$output_path/modules/$module/sequences/$(slugify $scen.name).md" || all_pass=false
```

### 7.2 — POST-GATE T2: Structure

```bash
# For each .md file generated:
bash .claude/scripts/wf-diagram-mermaid-validate.sh "$file"
# Exit code 0 = PASS, 1 = FAIL (issues listed), 2 = file not found
# FAIL → set all_pass=false; issues đã được listed bởi script

# For each .dbml file generated:
bash .claude/scripts/wf-diagram-dbml-validate.sh "$file"
# Exit code 0 = PASS or PASS_WITH_WARNINGS, 1 = FAIL
# FAIL → set all_pass=false
```

NẾU bất kỳ file nào exit 1 → T2 FAIL → kích hoạt Auto-Correction Loop (Step 7.5).

### 7.3 — POST-GATE T3: Content

```
FOR each .md file:
  - Mermaid block phải có ≥1 node/class/participant
  - KHÔNG có placeholder chưa thay: grep -E '\[[A-Z_]+\]' "$file" → count == 0
FOR each .dbml file:
  - ≥1 Table block có ≥1 column (không rỗng)
```

### 7.4 — POST-GATE T4: Cross-reference

```
- Tên entity/class/bảng nhất quán giữa class.md ↔ erd.dbml
  (normalize: lowercase + strip plural → compare)
- External refs đánh dấu rõ "// External: from <module>"
- Mismatch → log_error "E004" "name mismatch: $name"
  (WARNING — không block, nhưng hiển thị trong phase-summary.md)
```

### 7.5 — Auto-Correction Loop (Protocol 2 — max 3 retries)

```
NẾU bất kỳ T1-T3 fail:
  retry_count += 1
  Re-run phase tương ứng (4/5/6) với template
  NẾU retry_count == 3 AND vẫn FAIL:
    Set diagram-status.json.status = "failed"
    Tiếp tục Phase 7.6 (tạo phase-summary.md với STATUS="THẤT BẠI")
    # Protocol 14.1 — KHÔNG skip phase-summary.md khi FAIL
```

### 7.6 — Generate phase-summary.md (Protocol 14)

```
1. Read templates/phase-summary.md
2. Populate (tiếng Việt, ≤15 dòng):
   [GENERATED_AT] / [STATUS]  ← "HOÀN THÀNH" hoặc "THẤT BẠI"
   [SESSION_ID]
   [MODULE] / [SOURCE_PATH] / [SCOPE]
   [FILE_COUNT]               ← tổng số files sinh ra
   [MODULE_COUNT] / [ENTITY_COUNT] / [ENDPOINT_COUNT] / [ACTOR_COUNT]
   [SYSTEM_DIAGRAM_COUNT] / [MODULE_DIAGRAM_COUNT] / [DETAIL_DIAGRAM_COUNT]
   [OUTPUT_PATH]
   [STRENGTHS_AND_GAPS]       ← files bị skip + lý do (từ $plan.skipped[])
   [RECOMMENDATIONS]          ← gợi ý review/update
3. Write → $session_dir/phase-summary.md
4. Hiển thị nội dung trong conversation (Protocol 14.4)
```

### 7.7 — Append Trace COMPLETE / FAIL (Protocol 15)

```bash
event=$([ "$status" = "completed" ] && echo "COMPLETE" || echo "FAIL")

tmp=$(mktemp)
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg ev "$event" --argjson files "$files_created_json" \
   '.entries += [{"skill":"/wf-diagram","session_id":$sid,
                  "phase":"phase_7","event":$ev,"timestamp":$ts,
                  "files_created":$files}]' \
   "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"
```

### 7.8 — Save Final Checkpoint

```
Edit checkpoint.json:
  phase_states.phase_7 = "done"
  next_action = null   # DONE
  trigger.reason = "completed"
```

### 7.9 — Display Output Report

```
Hiển thị bảng tóm tắt (xem SKILL.md §Output Report):
| Module               | $module |
| Scope                | $scope |
| Session              | $session_id |
| System diagrams      | N files |
| Module diagrams      | N files |
| Detail diagrams      | states=X, activities=Y, sequences=Z |
| Skipped (filter)     | N — xem phase-summary.md |
| Verification         | T1-T4 PASS hoặc FAILED (xem errors) |

Output locations:
  - Diagrams: $output_path/
  - Metadata: $session_dir/
```

---

## POST-GATE

```
- [ ] T1-T4 PASS HOẶC status="failed" với phase-summary.md ghi rõ
- [ ] phase-summary.md tồn tại + non-empty (test -s) — Protocol 14.1
- [ ] trace COMPLETE hoặc FAIL event appended
- [ ] phases.phase_7.status = "done" / "failed"
```

---

## Next Phase

→ DONE — STOP skill execution.
