# Phase 0.5: Context Setup (LEGACY_MODE + Decision Registry)

> Gộp 2 sub-phases:
> - **Phase 0.5a:** LEGACY_MODE Detection (CORE-021) — dùng cho Safety Gate ở phase0-7
> - **Phase 0.5b:** Load Decision Registry (Protocol 12) — ngăn Decision Drift giữa sessions
>
> **LUÔN chạy** (không có điều kiện skip).

---

## Phase 0.5a: LEGACY_MODE Detection (CORE-021)

**PRE-GATE:** (luôn chạy)

| Step | Action | Verify |
|------|--------|--------|
| 0.5a.1 | `test -f .mc-data/work/legacy-scan/project-context.md && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500` | Check done |
| 0.5a.2 | **IF TRUE:** `LEGACY_MODE = true`. Đọc `project-context.md` → load vào `$LEGACY_CONTEXT` | LEGACY_MODE set |
| 0.5a.3 | **IF FALSE:** `LEGACY_MODE = false` | LEGACY_MODE set |
| 0.5a.4 | Đọc `.mc-data/work/wf-brainstorm/legacy-decisions.json` (nếu có) → extract modules có `action = "DEPRECATE"` → load vào `$DEPRECATED_MODULES[]` | $DEPRECATED_MODULES set (hoặc [] nếu file không tồn tại) |

**POST-GATE:** `LEGACY_MODE` variable set (true hoặc false), `$DEPRECATED_MODULES` set.

> **Graceful Degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, hiển thị cảnh báo cho user, tiếp tục bình thường.

---

## Phase 0.5b: Load Decision Registry (Protocol 12)

> Đọc các quyết định kiến trúc từ session trước để đảm bảo consistency.
> **Protocol 12:** Xem `.claude/skills/protocols/` — Decision Registry Protocol

**PRE-GATE:** (luôn chạy)

**📥 INPUT:**
- `$SESSION_DIR/decision-registry.json` (per-feature, nếu tồn tại)
- `.mc-data/docs/_meta/decision-registry.global.json` (cross-feature, **v4.0 Sprint 3**, nếu tồn tại)

> **Lưu ý:** `$FEATURE_SLUG` đã được derive ở SKILL.md Phase 0.2b — available tại thời điểm này.

**📤 OUTPUT:** `$CONSTRAINT_LIST` trong state (merge: project + module + feature scopes)

| Step | Action | Verify |
|------|--------|--------|
| 0.5b.1 | Check `$SESSION_DIR/decision-registry.json` tồn tại | Check done |
| 0.5b.1.5 | **[v4.0 Sprint 3]** Read global registry: `GLOBAL_REG=".mc-data/docs/_meta/decision-registry.global.json"`; `IF [[ -f "$GLOBAL_REG" ]]; then GLOBAL_DECISIONS=$(jq -c '[.decisions[] \| select(.scope == "project" or (.scope \| startswith("module:'$MODULE_SLUG'")))]' "$GLOBAL_REG"); else GLOBAL_DECISIONS="[]"; fi`. Graceful: file missing → empty array, không block. | `$GLOBAL_DECISIONS` set |
| 0.5b.2 | **IF EXISTS:** đọc toàn bộ `decisions[]` từ per-feature registry → build `$FEATURE_DECISIONS` | Constraints loaded |
| 0.5b.3 | **IF NOT EXISTS:** **[Template Rule]** READ `templates/decision-registry.json` → populate `feature_slug`, `created_at` → WRITE `$SESSION_DIR/decision-registry.json`. `$FEATURE_DECISIONS = []` | File created |
| 0.5b.4 | **[v4.0 Sprint 3]** Merge: `CONSTRAINT_LIST = $GLOBAL_DECISIONS + $FEATURE_DECISIONS`. Format thành text rules: `[scope] category: rule (reason)`. Inject vào Phase 3 Developer Agent context. | Context prepared, count logged |

> **Lưu ý Resume:** Khi `--resume`, Phase 0.5b vẫn chạy để reload decisions mới nhất (cả global lẫn per-feature).
>
> **Precedence khi conflict (Protocol 12.2):**
> 1. `feature:<slug>` (per-feature) override `module:<slug>`
> 2. `module:<slug>` override `project`
> 3. Khi conflict trong cùng scope → developer agent escalate user (Phase 3 Step 3.5)

**POST-GATE:** `test -f $SESSION_DIR/decision-registry.json` AND (`$GLOBAL_DECISIONS` set, có thể là `[]`)

---

## Output State Variables

| Variable | Value | Consumed by |
|----------|-------|-------------|
| `$LEGACY_MODE` | `true` / `false` | phase1 (1.7a), phase3 |
| `$LEGACY_CONTEXT` | Full text của project-context.md (nếu LEGACY_MODE) | phase1 |
| `$DEPRECATED_MODULES` | Array of module IDs (hoặc []) | phase1 (1.7a) |
| `$GLOBAL_DECISIONS` | JSON array — decisions có scope `project` hoặc `module:$MODULE_SLUG` từ global registry (v4.0 Sprint 3) | phase3 (agent context) |
| `$FEATURE_DECISIONS` | JSON array — decisions từ `$SESSION_DIR/decision-registry.json` (per-feature) | phase3 (agent context) |
| `$CONSTRAINT_LIST` | Merged: `$GLOBAL_DECISIONS + $FEATURE_DECISIONS` (cross-feature consistency) | phase3 (agent context), phase5a (5a.D) |
