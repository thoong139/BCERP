# Phase 0.5: Existing UI Context — Legacy UI Analysis (LEGACY_MODE ONLY)

> **Chỉ chạy khi `$LEGACY_MODE = true`** (xác định ở Phase 0).
> Phát hiện frontend code + screen inventory để inject UI-specific context cho agents ở Phase 1-5.
> File này được đổi tên từ `phase0-5-legacy-ui.md` → `phase0.5-legacy-ui-analysis.md` (ADR-OPT-03 rollout v4.0.0).

**PRE-GATE:**
- [ ] Phase 0 (`phase0-context.md`) POST-GATE PASS
- [ ] `$LEGACY_MODE = true`
- [ ] `$LEGACY_CONTEXT` loaded

**INPUT:**
- `.mc-data/work/legacy-scan/project-context.md`
- `.mc-data/work/legacy-scan/classified/*.json`
- `.mc-data/work/legacy-scan/gap-report.md` (nếu có)
- `.mc-data/work/legacy-scan/inventory/ui-manifest.json` (nếu có)

**OUTPUT:**
- In-memory: `$UI_CONTEXT_SUMMARY` (sẽ inject vào TẤT CẢ agent spawns trong Phase 1-5)
- `.mc-data/docs/phase4-ux/existing-ui-analysis.md` (optional, tổng quan UI baseline)
- `.mc-data/docs/phase4-ux/[system]/screen-inventory.md` (optional, per system)
- `.mc-data/docs/phase4-ux/design-tokens-baseline.md` (optional, tokens extracted từ code)
- `.mc-data/work/legacy-scan/ux-implementation-gap.md` (optional, UX gaps)

---

## Reference Sections

- `_shared.md` §LEGACY Context Injection
- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.5.1 | Đọc `project-context.md` → extract frontend tech stack + module map | Tech stack loaded |
| 0.5.2 | Đọc `classified/*.json` → filter frontend/UI files (có patterns: `.vue`, `.tsx`, `.jsx`, `pages/`, `screens/`, `components/`). **(CORE-022)** Loại bỏ các items có `module` ∈ `$DEPRECATED_MODULES` — không bao giờ đưa UI của modules DEPRECATE vào `$UI_CONTEXT_SUMMARY`. Log count: "Filtered out N UI files từ [K] DEPRECATE modules" | UI files filtered (sau DEPRECATE filter) |
| 0.5.3 | Đọc `gap-report.md` (nếu tồn tại) → lấy UI-related gaps | Gaps loaded (hoặc skip) |
| 0.5.4 | Đọc `ui-manifest.json` (nếu tồn tại) → lấy screen inventory từ legacy-scan. **(CORE-022)** Filter screens: bỏ các entries có `system_id` hoặc `module_id` ∈ `$DEPRECATED_MODULES`. | Inventory loaded (hoặc skip), sau DEPRECATE filter |
| 0.5.5 | Xây `$UI_CONTEXT_SUMMARY` (xem §UI Summary Structure) | Summary ready (không chứa DEPRECATE modules) |
| 0.5.6 | (Optional) Ghi ra disk: `existing-ui-analysis.md`, `screen-inventory.md`, `design-tokens-baseline.md`, `ux-implementation-gap.md` | Files created (hoặc skip) |

---

## UI Summary Structure ($UI_CONTEXT_SUMMARY)

```markdown
## UI-SPECIFIC CONTEXT (từ Phase 0.5)

### Frontend Tech Stack
- Framework: [React / Vue / Angular / Svelte / ...]
- UI Library: [MUI / Ant Design / Tailwind / Bootstrap / custom / ...]
- State Management: [Redux / Zustand / Pinia / Vuex / ...]
- Routing: [React Router / Vue Router / ...]

### Screens/Components Detected
| System | Path | Type | Notes |
|--------|------|------|-------|
| SYS-XXX | `apps/web/pages/...` | Page | ... |
| SYS-XXX | `apps/web/components/...` | Component | ... |

### Design Tokens (nếu trích xuất được)
- Colors: [list hoặc "không có design tokens tập trung"]
- Typography: [list]
- Spacing: [list]

### UI Libraries đang dùng
- [library name + version]

### UI-Related Gaps (từ gap-report.md)
- [gap 1 + severity]
- [gap 2 + severity]

### Recommendations cho Phase 1-5
- TRÍCH XUẤT từ code hiện có, KHÔNG thiết kế lại từ đầu
- Ưu tiên giữ tokens hiện tại nếu consistency HIGH
- Chuẩn hóa tokens nếu consistency LOW (gap-report sẽ chỉ ra)
```

**File outputs (optional):** Nếu có đủ dữ liệu, ghi ra 4 files UX legacy. Nếu không có — skip, chỉ giữ summary in-memory.

---

## POST-GATE

- [ ] `$UI_CONTEXT_SUMMARY` non-empty (tối thiểu có tech stack + screens detected)
- [ ] Summary sẵn sàng inject vào Phase 1-5 agent spawns
- [ ] Nếu có ghi files ra disk: tất cả files tồn tại và non-empty

**Next phase:** `phase1-design-system.md`

> Tên file canonical: `phase0.5-legacy-ui-analysis.md` (renamed từ `phase0-5-legacy-ui.md` — không dùng tên cũ).

---

## Lưu ý

- Phase 0.5 KHÔNG spawn agents — chỉ đọc và xây summary.
- `$UI_CONTEXT_SUMMARY` được dùng bởi Phase 1-5 để inject vào agent prompts (xem `_shared.md §LEGACY Context Injection`).
- Nếu `gap-report.md` và `classified/` chưa sẵn sàng (legacy pipeline chưa chạy đủ) → log WARN, vẫn xây summary dựa trên `project-context.md` only.
