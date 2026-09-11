<!-- From shared-protocols.md lines 264-294 (§5) — full table synced with 00-core.md §4a after 2026-04-19 audit -->
# Protocol 5 — Registry Safe-Write Protocol

> Mỗi skill chỉ update ĐÚNG fields được phân công trong `req-registry.json`.
> **Canonical full table:** `.claude/rules/00-core.md` §4a. Protocol 5 là mirror đồng bộ — khi mâu thuẫn, §4a thắng.

## 5.1 Role column quy ước

- **PRIMARY** — skill là owner chính của field, có quyền write đầy đủ.
- **SEED** — skill được write 1 lần đầu (initial) với scope hẹp; PRIMARY sẽ override về sau.
- **APPEND** — chỉ được thêm entries mới, không modify/delete/rename existing.
- **SAFE-UPDATE** — chỉ được upgrade impl_status (`not_started`/`in_progress` → `done`), KHÔNG downgrade.
- **FIX-INVALID** — chỉ được sửa giá trị invalid về default (`not_started`).
- **UPDATE-MODE** — update dựa trên change_type (MODIFY/ADD/DELETE/CLARIFY).
- **NONE** — skill KHÔNG được update registry.

## 5.2 Bảng phân công (đồng bộ với 00-core.md §4a)

| Skill | Field | Role | Ghi chú |
|-------|-------|------|---------|
| `/wf-brainstorm` | `project`, `departments[]`, `interface_type`, `locale` | SEED | Ghi 1 lần ở Phase 5.3. `locale` default `"vi"` (auto-detect từ brainstorm language). [IMP-002 PENDING Stage 3] |
| `/wf-analyze-requirements` | `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` | PRIMARY | Owner requirement model. |
| `/wf-define-features` | `features[]` (gồm `features[].impl_status`) | PRIMARY | Owner feature catalog. |
| `/wf-define-features` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Chỉ set `"skipped"` cho features thuộc module DEPRECATE. |
| `/wf-design` | `design_status` | PRIMARY | — |
| `/wf-design-ux` | `ux_design_status` | PRIMARY | — |
| `/wf-plan-modules` | `implementation_order` | PRIMARY | — |
| `/wf-plan-modules` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Chỉ set `"skipped"` cho features thuộc `$DEPRECATED_MODULES`. |
| `/wf-implement-feature` | `impl_status` (per REQ-ID) | PRIMARY | Owner impl status lifecycle. |
| `/wf-verify-sync` | `impl_status` (per REQ-ID) | SAFE-UPDATE | KHÔNG downgrade `done`. |
| `/wf-fix-bugs` | — | NONE | Pure orchestrator. |
| `/wf-fix-triage` | — | NONE | Triage only. |
| `/wf-fix-execute` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Phase 4a only. |
| `/wf-fix-functional` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-business` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-security` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-performance` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-ux-a11y` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-data` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-fix-compat` | — | NONE | Spawned sub-skill — signals only. |
| `/wf-design` (legacy flow) | `design_status` + `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `features[]`, `interface_type` | PRIMARY | Registry build khi legacy flow thiếu seed. |
| `/wf-design` (legacy flow) | `requirements[].impl_status` | FIX-INVALID | Chỉ fix invalid → `not_started`. |
| `/wf-annotate-code` | — | NONE | Chỉ sửa REQ-ID comments trong code files. |
| `/wf-add-scope` | `modules[]`, `features[]` | APPEND | Idempotent, dedup theo ID. |
| `/wf-manage-change` | `requirements[]`, `features[]`, `impl_status` | UPDATE-MODE | Theo change_type (xem 00-core.md §4a). |

## 5.3 Quy tắc Safe-Write

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation cho toàn bộ JSON
4. VALIDATE sau ghi — `jq '.' registry.json` phải pass
```

> **Ưu tiên khi conflict:** §4a trong `.claude/rules/00-core.md` luôn là canonical. Nếu bảng trên lạc hậu, fix Protocol 5 để khớp §4a (KHÔNG đảo chiều).
