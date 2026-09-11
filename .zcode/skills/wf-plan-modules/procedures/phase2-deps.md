# Phase 2: Thu thập Dependencies (PARALLEL)

> Đọc tất cả feature files song song để extract dependency data → build `$DEP_MATRIX`.

> **Shared context:** xem `_shared.md` — Token Limit Prevention, Cross-Phase Data Flow.

---

## PRE-GATE

`test $MODULE_COUNT -ge 3`

> **Simple/Lite mode shortcut (MODULE_COUNT < 3):** Nếu 1-2 modules → Phase 2-3 bị SKIP hoàn toàn (routing quyết định tại SKILL.md Phase Routing Map). Set `$HAS_CYCLE = "false"`, set `$DEP_MATRIX = {}` (empty) → nhảy thẳng Phase 4 (assign Layer 0) → Phase 7. PRE-GATE `>= 3` đảm bảo không vào Phase 2 với dự án nhỏ.

---

## 📥 INPUT

- Registry (in-memory từ Phase 1)
- Feature files từng module: `phase2-features/[sys]/[mod]/*.md`

> Output là `$DEP_MATRIX` (in-memory) — không tạo file.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.1 | **[PAR] PARALLEL per module:** Glob feature files per module → chọn strategy theo tổng file count (xem §Parallel Pattern) | All deps collected |
| 2.2 | Extract dependencies từng feature | Dependencies extracted |
| 2.3 | Build dependency matrix | Matrix created |
| 2.4 | Validate dependencies trỏ đến modules tồn tại | No orphan deps |

---

## §Parallel Pattern (Step 2.1 chi tiết)

```
[PAR] Parallel Dependency Collection — Phase 2:

modules = registry.modules[]
total_files = Σ Glob("phase2-features/[sys]/[mod]/*.md") for all modules

IF total_files <= 5:
  // Ít files — đọc trực tiếp OK
  PARALLEL FOR each module IN modules:
    files = Glob("phase2-features/[sys]/[mod]/*.md")
    Read ALL files in batch
    Extract dependencies per file

ELSE:
  // >5 files — dùng Grep để extract dependency info, không load full content
  PARALLEL FOR each module IN modules:
    files = Glob("phase2-features/[sys]/[mod]/*.md")
    FOR each file IN files:
      dep_info = Grep(file, pattern="depends_on|requires|imports|uses_module|phụ thuộc|gọi API|tham chiếu")
      summaries[file] = dep_info  // chỉ lấy dòng chứa dependency keywords
    Extract dependencies từ grep results
    // Chỉ Read full file nếu grep results ambiguous hoặc không đủ context

→ Merge ALL dependency data vào $DEP_MATRIX
```

---

## Dependency Rule

Module A phụ thuộc Module B khi:

- A cần lấy dữ liệu từ B
- A cần gọi API/Services của B
- A tham chiếu Entity của B

---

## POST-GATE

`test -n "$DEP_MATRIX"`

---

## Next

→ Checkpoint: position → `phase_3`
→ Read `procedures/phase3-cycles.md`
