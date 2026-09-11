# Phase 1: Design System

> Tạo design system tổng thể — nền tảng cho tất cả screen specs.
> Spawn agents SEQUENTIAL: brand-guardian (conditional) → ux-researcher → ux-designer.

**PRE-GATE:**
- [ ] Phase 0 (`phase0-context.md`) POST-GATE PASS
- [ ] Nếu LEGACY_MODE: Phase 0.5 (`phase0-5-legacy-ui.md`) POST-GATE PASS
- [ ] `$INTERFACE_TYPE != api-only`
- [ ] `$PHASE4_CONTRACT` cached

**INPUT:**
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- `.mc-data/docs/_meta/req-registry.json`
- `.mc-data/docs/phase2-features/**/*.md`
- UX template từ `.claude/doc-framework/phase4-ux/design-system.md`

**OUTPUT:** `.mc-data/docs/phase4-ux/design-system.md`

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P1-A (brand-guardian), P1-B (ux-researcher), P1-C (ux-designer)
- `_shared.md` §LEGACY Context Injection (nếu LEGACY_MODE)
- `_shared.md` §Token Limit Prevention (input compress, skeleton-first)
- `_shared.md` §Large Project Mode
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | `mkdir -p .mc-data/docs/phase4-ux/` | Directory exists |
| 1.1a | **[Protocol 6.2] INPUT COMPRESS** — xem §Input Compression | Digest ready (hoặc skip nếu <= threshold) |
| 1.1b | **Brand Check** — nếu project có brand guidelines trong `.mc-data/knowledge-base/` → spawn `brand-guardian` agent (prompt P1-A) | Agent success (hoặc skip) |
| 1.1c | **[SCAFFOLD-FIRST]** — xem §Scaffold Design System | File scaffolded (hoặc skip nếu đã tồn tại) |
| 1.2 | **SKIP-IF-EXISTS** — nếu `test -s .mc-data/docs/phase4-ux/design-system.md` → skip 1.2 + 1.3, log "design-system.md đã tồn tại — skip Phase 1". Ngược lại: spawn `ux-researcher` agent (prompt P1-B) SEQUENTIAL trước design | Agent success (hoặc skip) |
| 1.3 | **[Protocol 6.5] SKELETON-FIRST** — xem §Skeleton-First Strategy | Agent success |
| 1.4 | Verify `design-system.md` created với đủ 6 sections | `test -s design-system.md` |
| 1.5 | **LOG AGENTS** — append `brand-guardian`, `ux-researcher`, `ux-designer` vào `design-ux-status.json` → `metrics.agents_spawned[]` | Agents logged |
| 1.6 | **SAVE CHECKPOINT** — READ `templates/checkpoint.json` → POPULATE (trigger=phase1_complete, position.current_phase=1, progress.files_created+=1) → WRITE `.mc-data/work/wf-design-ux/checkpoint.json` | Checkpoint saved |

---

## Input Compression (Step 1.1a)

```
Nếu feature_files.length > $LPM_PARAMS.compression_threshold (Standard: 3, LPM: 2):
  FOR each feature_file:
    → Grep key sections: headers, REQ-IDs, interface elements
    → Tạo feature-digest entry (~$LPM_PARAMS.digest_size từ — Standard: 200, LPM: 300)
  → Cache in-memory: feature-digest (dùng làm context cho ux-researcher + ux-designer)
  → Agent đọc file gốc CHỈ KHI cần chi tiết
Ngược lại:
  → Skip compression, agent đọc trực tiếp từ file paths
```

---

## Scaffold Design System (Step 1.1c)

```
IF test -f design-system.md AND test -s design-system.md:
  → Skip scaffolding (resume case hoặc đã có)

ELSE:
  → READ $PHASE4_CONTRACT["design-system"].required_sections
  → Pre-tạo design-system.md với format:
    # Design System
    
    ## [Section 1 header]
    <!-- TODO: fill content -->
    
    ## [Section 2 header]
    <!-- TODO: fill content -->
    ...
  → Optional sections: thêm comment "Thêm section này nếu phù hợp"

IF $PHASE4_CONTRACT không tồn tại:
  → WARN log, skip scaffolding (agent sẽ tự chịu trách nhiệm cấu trúc)
```

---

## Skeleton-First Strategy (Step 1.3)

```
IF $LARGE_PROJECT = true AND estimated_output_size > $LPM_PARAMS.skeleton_threshold:
  Pass 1: spawn ux-designer → tạo SKELETON
    - 6 section headers + 1-2 câu intro/section
    - ~500 từ total
    - Không fill detail
  
  Pass 2: spawn ux-designer → ĐIỀN CHI TIẾT từ skeleton
    - Đọc skeleton, expand mỗi section theo minimum thresholds
    - Output full design-system.md (~1500-2500 từ)

ELSE (Standard mode HOẶC output <= threshold):
  → Spawn ux-designer trực tiếp (1 pass)
  → Truyền feature-digest nếu có (từ Step 1.1a)
```

**Agent prompt:** Xem `_shared.md §Agent Prompt Templates → P1-C`.

**INJECT LEGACY BLOCK** nếu `$LEGACY_MODE = true` (xem `_shared.md §LEGACY Context Injection`).

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase4-ux/design-system.md` — file non-empty
- [ ] **[Protocol 10 — T2]** Verify đủ 6 required sections:
  ```bash
  grep -c "Colors\|Typography\|Spacing\|Components\|Breakpoints\|Icons" design-system.md >= 6
  # Hoặc match tiếng Việt:
  grep -c "Màu Sắc\|Chữ\|Khoảng Cách\|Component\|Bố Cục\|Quy Ước" design-system.md >= 6
  ```
- [ ] Nếu FAIL → re-run ux-designer với instruction bổ sung missing sections (max 3 retries)
- [ ] Checkpoint đã save

**Next phase:** `phase2-navigation.md`

---

## Auto-Correction

Nếu POST-GATE FAIL sau 3 retries:
- STOP phase
- Append error_log với chi tiết (missing sections, file size)
- Escalate to user với 2 options:
  1. Manual fill design-system.md → chạy lại với `--resume`
  2. Abort skill
