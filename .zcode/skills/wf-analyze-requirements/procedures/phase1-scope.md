# Phase 1: Registry Validation & Scope

> Xử lý dữ liệu in-memory — không tạo/cập nhật file nào.
> Parse registry, extract departments, xác định scope từ arguments.

**PRE-GATE:** `test -n "$REGISTRY_DATA"` (từ Phase 0)

**INPUT:** `$REGISTRY_DATA` + `$BRAINSTORM_CONTEXT` + arguments

**OUTPUT:** In-memory — `$ACTIVE_DEPTS`, `$DETECTED_INDUSTRIES`, `$SCOPE`, `$HAS_EXISTING_DOCS`

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 1.1  | Parse registry: extract `systems`, `modules` | Data extracted |
| 1.2  | Extract `active_depts[]` từ `P0-01-brainstorm.md` Section 2 (Phòng Ban Nào Tham Gia). Detect `detected_industries[]` từ company_name + industry keywords. Lưu `$DOMAIN` là tên ngành tổng quát (vẫn cần cho context). | Departments + domain identified |
| 1.3  | Parse scope từ arguments | — |
| 1.4  | Xác định scope (user input ưu tiên hơn auto-detect) | — |
| 1.5  | Detect `$HAS_EXISTING_DOCS`: `test -f .mc-data/work/legacy-scan/doc-mapping.json` → true nếu có onboarding docs | `$HAS_EXISTING_DOCS` set |

## Scope Behavior

| Scope | Output | Phases chạy |
| ----- | ------ | ----------- |
| `all` | `departments/*.md` + P1-01 + P1-02 + stakeholder-review + deferred-issues | 0→1→2→3→3.5(L)→4→5(C)→6→6b→6c→6d→8→8b→8c |
| `business` | `departments/*.md` + P1-01 (skip P1-02, stakeholder-review, conflict resolution) | 0→1→2→3→3.5(L)→4→5(C)→6→8→8b→8c |
| `[module]` | Targeted dept docs cho 1 module + P1-01 | 0→1→2→3→3.5(L)→4→5(C)→6→8→8b→8c |

> `(L)` = chỉ chạy nếu `$LEGACY_MODE = true`. `(C)` = chỉ chạy nếu `$HAS_EXISTING_DOCS = true`.

**POST-GATE:** `test -n "$SCOPE" && test -n "$ACTIVE_DEPTS"`

> **(Protocol 6.6 — LPM-05)** Nếu `$LARGE_PROJECT = true`: **SAVE CHECKPOINT** sau Phase 1.

**Status update:** `analyze-status.json` → `phase_1.status = "completed"`, `phase_1.completed_at = <ISO timestamp>`, `phase_1.scope = "$SCOPE"`, `phase_1.active_depts = [...]`

**Next phase:** `phase2-plan.md`
