# 12 — Decisions Log

> **Mục đích:** Ghi lại các quyết định kiến trúc của plan, tránh tái-discuss + giúp future audit hiểu rationale.
> **Format:** Mỗi decision có ID, ngày, options, choice, rationale, impact.

---

## Quyết định đã chốt

### DEC-001 — Phương án thực thi plan

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | Cách triển khai plan: hoàn thành audit trước rồi mới fix? Tách roadmap 2 lớp + parallel? Reduce scope? Phased với gates? |
| **Options** | A. Hoàn thành audit đủ rồi mới fix · B. Tách 2 lớp + audit/fix parallel · C. Reduce scope · **D. Phased Plan with Evidence Gates** ✅ |
| **Choice** | **D** |
| **Rationale** | A trì hoãn không cần thiết QD1 verified findings. B vi phạm CORE-024 (fix dựa evidence chưa đủ). C mất giá trị audit toàn diện. D cân bằng: gate evidence-based + parallel-ready cho audit, không trì hoãn. |
| **Impact** | Tạo files [11-stages-and-gates.md](./11-stages-and-gates.md), [13-definition-of-done.md](./13-definition-of-done.md). Restructure files 00, 09, 10. |

### DEC-002 — Số lượng owner audit

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | 1 owner sequential (~12 tuần) hay 3-4 người parallel (~8 tuần)? |
| **Options** | **1 owner sequential, parallel-ready** ✅ · 3-4 người parallel · 1 owner không parallel-ready |
| **Choice** | **1 owner sequential, parallel-ready architecture** |
| **Rationale** | Repo MCV3 git history chỉ có 1 author (`hanoibanhcuon`). Plan thiết kế parallel-ready (mỗi dim có contract isolated theo CORE-025) để scale khi có thêm người mà không cần refactor. |
| **Impact** | Default execution thứ tự `QD1 → QD3 → QD6 → QD2 → QD4 → QD5 → QD7`. Không cần infra coordination. Tổng effort: ~14 tuần (1 owner) hoặc ~9 tuần (3 owners). |

### DEC-003 — Performance benchmark per-probe

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | Có benchmark performance cho từng probe không? Yes (all 43 probes) / No / Selective? |
| **Options** | Yes (all) · No · **Selective** ✅ |
| **Choice** | **Selective** |
| **Criteria** | Probes có `estimated_cost ≥ 60s` HOẶC `type=agent` (~15-18 probes) |
| **Rationale** | Cheap probes (grep+jq, 30s) không cần benchmark. Expensive probes là nơi cost overrun đáng kể. Selective tránh over-engineering. |
| **Impact** | Thêm `audit-perf-qd<N>.json` deliverable cho mỗi dim ở Stage 1. Output schema: `{probe_id, expected_cost_s, measured_cost_s, delta_pct}`. |

### DEC-004 — Regression test suite tự động

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | Yes (pytest) / No (manual)? |
| **Options** | **Yes (pytest)** ✅ · No (manual) |
| **Choice** | **Yes (pytest)** |
| **Rationale** | MCV3 đã có pytest infra (`_shared/run-tests.sh`, ≥80% coverage gate). Stage 4 (re-audit) cần automated comparison — manual không scale. Test fixtures + expected signals = regression test tự nhiên. |
| **Impact** | Tạo `tests/` với conftest.py + `test_qd<N>_probes.py` cho 7 dim. Run via `tests/run-audit-tests.sh`. |

### DEC-005 — Output format roadmap

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | MD / JSON / Both? |
| **Options** | MD only · JSON only · Both (MD+JSON sidecar) · **MD primary với YAML frontmatter per IMP** ✅ |
| **Choice** | **MD primary với YAML frontmatter per IMP** |
| **Rationale** | Single source of truth, vừa human-readable vừa machine-parseable bằng `yq`. Tránh duplicate maintenance / drift risk của Both option. |
| **Impact** | Refactor `10-improvement-roadmap.md` IMP entries với YAML frontmatter chuẩn (xem [13-DoD §IMP](./13-definition-of-done.md)). Helper script `scripts/extract-roadmap-status.sh`. |

### DEC-006 — Sync findings vào MCV3 evals/

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | Yes / No? |
| **Options** | **Yes** ✅ · No |
| **Choice** | **Yes** |
| **Rationale** | `evals/evals.json` convention đã có sẵn cho mỗi lane skill (xem `.claude/scripts/audit/EVAL-SCHEMA.md`). Findings + fixtures + expected signals = eval test cases tự nhiên. Cần cho regression detection sau Sprint fix. |
| **Impact** | Stage 2 thêm step "sync to evals/". Script `scripts/sync-audit-to-evals.sh` chạy ở Gate G2. |

### DEC-007 — Cross-session execution protocol

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-08 |
| **Question** | Plan cần nhiều phiên Claude để hoàn thành. Cách persist state giữa các phiên? |
| **Options** | A. Chỉ dựa vào progress.md · B. **EXECUTION-PROMPT.md stateful** ✅ · C. External tool (Notion/Linear) |
| **Choice** | **B — EXECUTION-PROMPT.md stateful** |
| **Rationale** | A không đủ operational (chỉ track high-level). C external tool tốn overhead + lock-in. B self-contained trong plan folder, Claude tự đọc/update, dễ resume. |
| **Impact** | Tạo `EXECUTION-PROMPT.md` với 5 phases (Context Loading, Confirm, Execute, Update, Handoff). Pair với progress.md (canonical) + EXECUTION-PROMPT (operational). User invoke bằng `Continue plan execution: @plans/.../EXECUTION-PROMPT.md`. |

### DEC-008 — IMP-002 cross-skill registry schema coordination (project.locale)

| Trường | Giá trị |
|---|---|
| **Date** | 2026-05-09 |
| **Question** | IMP-002 (i18n locale-aware probes) ghi trong notes "Cần thêm `project.locale` vào req-registry.json". Ai là SEED owner? wf-fix-* có cần write permission không? Schema thay đổi như thế nào? |
| **Options** | A. Change `project` string → object `{name, locale}` (BREAKING schema v4→v5) · **B. Add top-level `"locale"` field** ✅ · C. Add `"project_settings": {"locale": ...}` (extensible object) |
| **Choice** | **B — Top-level `"locale"` field** |
| **Rationale** | (1) Schema analysis: `req-registry.json` template có `"project": "[PROJECT_NAME]"` là **plain string** — `project.locale` dotpath notation trong IMP-002 spec là aspirational/incorrect. Thay đổi `project` từ string → object sẽ BREAK mọi consumer dùng `jq '.project'` (wf-brainstorm, wf-analyze-requirements, wf-design, wf-plan-modules, wf-implement-feature, v.v.). Option A cần schema migration v4→v5 — out of scope cho 1 field. (2) Safe-write ownership: wf-brainstorm là SEED owner của `project`, `departments[]`, `interface_type` (Protocol 5 §5.2). `locale` là project metadata → natural fit cho wf-brainstorm Phase 5.3 seed. (3) wf-fix-* role = NONE (pure orchestrator/signals-only per Protocol 5). Chúng chỉ cần READ, không write. `jq -r '.locale // "en"'` cung cấp backward-compat fallback cho registries cũ không có field này. (4) Top-level field đơn giản hơn, trực tiếp, không tạo premature nesting (BHV-002). |
| **Impact** | **Stage 3 Sprint 3 (IMP-002 implementation) — 6 file changes:** (1) `.claude/doc-framework/_meta/req-registry.json`: thêm top-level `"locale": "vi"` (default VN per CORE-005). (2) `wf-brainstorm/procedures/phase5-init-registry.md` Step 5.3: thêm seed logic — detect locale từ Phase 1 language cues (nếu user mô tả bằng VI → `"vi"`, EN → `"en"`, JP → `"ja"`, ZH → `"zh"`; default `"vi"`). (3) `.claude/skills/protocols/05-registry-safe-write.md`: update wf-brainstorm SEED row — thêm `"locale"` vào fields list. (4) `wf-fix-functional/SKILL.md` PRE-GATE: thêm `LOCALE=$(jq -r '.locale // "en"' registry.json)`. (5) `wf-fix-ux-a11y/SKILL.md` PRE-GATE: tương tự (QD5 label-consistency). (6) `wf-fix-compat/SKILL.md` PRE-GATE: tương tự (QD7 i18n-locale-check). Cũng cần update IMP-002 notes để sửa `project.locale` → `.locale` top-level notation. |

**Cross-skill coordination plan (tóm tắt):**

| Skill | Locale Role | Ghi chú |
|---|---|---|
| `/wf-brainstorm` | **SEED** — ghi 1 lần Phase 5.3 | Auto-detect từ brainstorm language; default `"vi"` |
| `/wf-fix-functional` (QD1) | **READ-ONLY** — `jq -r '.locale // "en"'` | PRE-GATE; dùng cho CTA keyword dict selection |
| `/wf-fix-ux-a11y` (QD5) | **READ-ONLY** — `jq -r '.locale // "en"'` | PRE-GATE; dùng để skip i18n message file orphan check |
| `/wf-fix-compat` (QD7) | **READ-ONLY** — `jq -r '.locale // "en"'` | PRE-GATE; dùng cho i18n-locale-check probe |
| Tất cả wf-fix-* khác | **NONE** — không liên quan | Protocol 5 role không thay đổi |

**Backward compatibility:** Registry không có `locale` field → `jq -r '.locale // "en"'` trả `"en"` — probe chạy ở EN mode (safe default).

---

## Decision Template (cho future decisions)

```yaml
### DEC-NNN — <Title>

| Trường | Giá trị |
|---|---|
| **Date** | YYYY-MM-DD |
| **Question** | ... |
| **Options** | A · B ✅ · C |
| **Choice** | B |
| **Rationale** | ... |
| **Impact** | ... |
```

## Quy tắc Decision Log

1. **Ghi ngay khi quyết định** — không trì hoãn để tránh quên rationale
2. **KHÔNG sửa decision đã chốt** — nếu thay đổi → tạo decision mới override (vd `DEC-007` override `DEC-005`)
3. **Mỗi decision phải có Impact section** — describe cụ thể file nào affected
4. **Cross-link với artifacts** — link tới files / commits liên quan

---

## Open questions (chưa cần quyết)

(Hiện tại không có. Thêm khi xuất hiện trong audit Stage 1.)
