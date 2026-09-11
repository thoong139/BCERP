# Phase 3 — ADR-OPT Rollout: Design Principles (4 Linear Skills)

> **Tạo:** 2026-04-23
> **Mục đích:** Chốt nguyên tắc thiết kế chung cho 4 skills (`wf-define-features`, `wf-design`, `wf-design-ux`, `wf-plan-modules`) — tránh drift khi triển khai Phase 3.
> **Prerequisite:** Đọc `ADR-downstream-skills-optimization.md` + `phase2-analyze-req-remaining-steps.md` + `phase2-validation-tests.md`.
> **Hướng dẫn sử dụng:** Các phiên rollout từng skill (Task 2-5 của `phase3-rollout-remaining-skills.md`) PHẢI tuân thủ bảng **Shared Constraints** bên dưới. Chỉ **Variable Map** được tuỳ biến per-skill.

---

## 1. Context

Phase 2 đã validate thành công pattern ADR-OPT trên `wf-analyze-requirements` v3.0.0 (Sign-off ngày 2026-04-23). Phase 3 áp dụng **cùng pattern** cho 4 skills linear còn lại:

| Skill | Current version | Target version (plan) | Current phase count | Ghi chú |
|-------|-----------------|-----------------------|---------------------|---------|
| `wf-define-features` | 2.1.0 | → **3.0.0** | 10 procedure files | Bump major do thay đổi phase structure |
| `wf-design` | 3.0.0 | → **4.0.0** (revised) | 9 procedure files (+_shared) | Current đã 3.0.0 do refactor. Bump MAJOR tiếp do thêm Lane Dispatch + Phase 0.5 |
| `wf-design-ux` | 3.0.0 | → **4.0.0** (revised) | 10 procedure files | Như `wf-design` |
| `wf-plan-modules` | 1.7.1 | → **3.0.0** (skip 2.x) | 14 procedure files | Skip 2.x theo plan gốc để align minor band với các skill khác |

> **Quyết định versioning:** Plan gốc `phase3-rollout-remaining-skills.md` nêu "→ v3.0.0" cho cả 4, nhưng `wf-design` + `wf-design-ux` hiện đã v3.0.0. Áp dụng quy tắc SemVer: thay đổi phase structure + thêm ADR-OPT = breaking change → bump MAJOR. Do đó 2 skill này bump lên v4.0.0. Phiên rollout từng skill phải ghi rõ lựa chọn này trong changelog.

---

## 2. Pattern Tổng Quát (áp dụng cho mọi skill)

### 2.1. SKILL.md bump

Checklist tối thiểu (copy từ `wf-analyze-requirements` v3.0.0):

- [ ] Changelog entry mô tả 5 ADR-OPT (01-05) — nêu rõ phase nào thêm mới, phase nào refactor.
- [ ] Row **Phases** trong Overview table: thêm `0.5` vào phase ordering (ví dụ `0 → 0.5 → 1 → 2 → ...`).
- [ ] Row **Session** trong Overview hoặc section mới: mô tả `sessions/{id}/` + `latest` pointer.
- [ ] Row **_shared imports** trong Protocols section: liệt kê 6 module (`profiles`, `lane`, `partition`, `aggregate`, `cdg`, `cache`).
- [ ] Template Usage Rule table (CORE-031): thêm 4 row cho `_shared/templates/*`:
  - `_shared/templates/session-state.json`
  - `_shared/templates/workload-report.md`
  - `_shared/templates/lane-signal.json`
  - `_shared/templates/aggregation-result.json`

### 2.2. `_contract.json` bump

Checklist tối thiểu:

- [ ] `version` bump (xem bảng §1 ở trên).
- [ ] `procedure_files[]`: thêm `procedures/phase0.5-workload-gate.md`.
- [ ] `outputs.working[]`: thêm 4 session artifacts (session-state.json, workload-report.md, lane-signal.json, aggregation-result.json) + `latest` pointer.
- [ ] `registry_scope.fields_owned`: **KHÔNG thay đổi** — bảo toàn CORE-006 Safe-Write contract.
- [ ] `cross_skill_contracts.produces_for` / `consumes_from`: review — nếu digest output path giữ nguyên thì không cần sửa; nếu thêm digest mới thì phải sync với `.claude/rules/00-core.md §4b`.

### 2.3. `procedures/` updates

Mỗi skill có 6 loại thay đổi procedures:

| Loại | File | Nội dung | Shared module |
|------|------|----------|---------------|
| **NEW** | `procedures/phase0.5-workload-gate.md` | Workload estimation + gate evaluation (ADR-OPT-03). Steps 0.5.1-0.5.6 như `wf-analyze-requirements`. | `_shared/partition/` + `_shared/cdg/` |
| **UPDATE** | `procedures/_shared.md` | +4 session variables + Session Isolation Protocol section + _shared Module Imports section + Phase→File Mapping row cho Phase 0.5 + Phase Ordering by Scope update | (meta — references all modules) |
| **UPDATE** | `procedures/phase0-context.md` | Step 0.2b session init + latest pointer + cleanup (giữ 5 sessions) + `--resume` dispatch từ `session-state.json` | — |
| **UPDATE** | Phase "expert dispatch" (tên khác nhau per-skill) | Lane Dispatch (ADR-OPT-01) thay thế logic parallel spawn hiện tại | `_shared/lane/` |
| **UPDATE** | Phase "consolidate/cross-validation" | Signal Aggregation (ADR-OPT-04) — dedup theo ID type | `_shared/aggregate/` |
| **UPDATE** | Phase "handoff/digest output" | Template Strip + Atomic Write (ADR-OPT-05) | `_shared/_shared.md` §1-2 |

---

## 3. Variable Map (per-skill — các phiên rollout tuỳ biến)

### 3.1. `wf-define-features`

| Field | Value |
|-------|-------|
| Lane type | **feature-lane per module** — mỗi module trong `modules[]` spawn 1 lane viết feature specs |
| Lane key format | `{system-slug}-{module-slug}` |
| Partition grouping | `group_key="module"`, `max_per_partition = 5` (≤5 modules/partition) |
| Workload `est_minutes_per_item` | `5.0` (feature spec nặng hơn BA analysis) |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu trung bình `>3 features/module` |
| Dedup key | `feat_id` (FEAT-ID) |
| Aggregation conflict | 2 lanes cùng produce FEAT-ID → flag, fallback priority = lane owning module |
| Conditional phases | — |
| Expert dispatch phase | `phase2-create-specs.md` + `phase2.5-feat-mapping.md` |
| Consolidate phase | `phase3-cross-validation.md` |
| Handoff phase | `phase5-registry-update.md` + digest output (Phiên 6 — cuối Phase 5) |

### 3.2. `wf-design`

| Field | Value |
|-------|-------|
| Lane type | **system-lane per system** — mỗi system trong `systems[]` spawn 1 lane viết architecture + API + DB |
| Lane key format | `{system-slug}` |
| Partition grouping | `group_key="system"`, `max_per_partition = 3` (system nặng) |
| Workload `est_minutes_per_item` | `15.0` (design toàn diện) |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu multi-tier (microservices / event-driven) |
| Dedup key | `component_id` (COMPONENT-ID) hoặc `api_id` nếu phase đang xử lý API contracts |
| Aggregation conflict | Cross-system dependency conflicts → flag, defer cho stakeholder review (Phase 5) |
| Conditional phases | Phase 7 gap analysis — LEGACY_MODE only |
| Expert dispatch phase | `phase1-architecture.md` + `phase2-specs-parallel.md` |
| Consolidate phase | `phase3-integration.md` + `phase4-crossval.md` |
| Handoff phase | `phase6-finalize.md` + `phase8-digest-summary.md` |

### 3.3. `wf-design-ux`

| Field | Value |
|-------|-------|
| Lane type | **screen-lane per module (non-api-only)** — chỉ module có UI components |
| Lane key format | `{module-slug}-screens` |
| Partition grouping | `group_key="module"`, `max_per_partition = 5` |
| Workload `est_minutes_per_item` | `4.0` |
| Workload factor | 1.0 normal, 1.5 LEGACY, 1.5 nếu có >3 screen groups trung bình/module |
| Dedup key | `screen_id` (SCREEN-ID) |
| Aggregation conflict | Reuse component cross-module → aggregate vào shared design system (không flag) |
| Conditional phases | **Toàn skill skip nếu `interface_type == "api-only"`** — Phase 0.5 check trước khi chạy |
| Expert dispatch phase | `phase3-screen-groups.md` (primary lane phase) |
| Consolidate phase | `phase4-crossval.md` |
| Handoff phase | `phase6-registry.md` + `phase7-digest-summary.md` |

### 3.4. `wf-plan-modules`

| Field | Value |
|-------|-------|
| Lane type | **module-lane theo dependency DAG** — chạy topological order |
| Lane key format | `{module-slug}` |
| Partition grouping | `group_key="topological_level"`, `max_per_partition = 5` per level |
| Workload `est_minutes_per_item` | `8.0` (task breakdown + sprint planning) |
| Workload factor | 1.0 normal, 1.5 LEGACY, 2.0 nếu có cross-module dependencies phức tạp |
| Dedup key | `task_id` (TASK-ID) |
| Aggregation conflict | Shared task across modules → flag, defer for dependency review (Phase 7a verify) |
| Conditional phases | Phase 1.5 legacy-impl — LEGACY_MODE only (giữ nguyên, chỉ lane-ify) |
| Expert dispatch phase | `phase7.5-tasks.md` (task generation — primary lane phase) |
| Consolidate phase | `phase7a-verify.md` (verify + impact analysis) |
| Handoff phase | `phase7-outputs.md` + digest output Phiên 6 |

---

## 4. Shared Constraints (BẤT BIẾN giữa 4 skills)

> Các hằng số sau KHÔNG được tuỳ biến per-skill. Nếu skill có lý do chính đáng để lệch (ví dụ threshold cao hơn cho design nặng), phải mở ADR amendment.

| Constraint | Giá trị | Nguồn |
|------------|---------|-------|
| Workload gate threshold | **45 phút** | ADR-OPT-03 |
| Workload gate dead_zone | `ratio < 0.8` — silent continue | ADR-OPT-03 |
| Workload gate warn | `0.8 ≤ ratio < 1.5` — AskUserQuestion | ADR-OPT-03 |
| Workload gate block | `ratio ≥ 1.5` — Plan A/B menu + CDG-A02 override | ADR-OPT-03 |
| `max_parallel` (LPM profile) | **3** | ADR-OPT-01 |
| `max_parallel` (Standard profile) | **5** | ADR-OPT-01 |
| Session cleanup policy | **Giữ 5 sessions mới nhất** per skill | ADR-OPT-02 |
| Session dir pattern | `sessions/{YYYYMMDD-HHMMSS}-{hash4}/` | ADR-OPT-02 |
| `latest` pointer | Text file = session dir absolute path | ADR-OPT-02 |
| Atomic write pattern | `tmp → jq validate → mv` (`_shared/_shared.md §2`) | ADR-OPT-05 |
| Template strip fields | `_template_notes`, `_comments`, `_examples`, `_placeholder`, `_description` | ADR-OPT-05 |
| CDG-A02 workload override | Trigger khi user chọn "Override + proceed" tại gate BLOCK | ADR-OPT-03 + Protocol 16 |
| Import convention | `sys.path.insert(0, ".claude/skills/workflow/_shared")` + `from {module} import {fn}` | `_shared/_shared.md §3` |
| `registry_scope.fields_owned` | **UNCHANGED** vs version trước — bảo toàn CORE-006 | CORE-006 |
| L1/L2/L3 checkpoint | Phase / Batch / Item tracked trong `session-state.json` | ADR-OPT-02 + protocols/10-post-gate-schema.md |

---

## 5. Decision Log Template (dùng trong 4 phiên rollout sau)

Mỗi phiên rollout Task 2-5 của `phase3-rollout-remaining-skills.md` phải mở một decision log ngắn ở đầu spec, format sau:

```markdown
## Decision Log — Skill: wf-XXX

| Field | Value | Rationale |
|-------|-------|-----------|
| Current version | x.y.z | Từ _contract.json |
| Target version | x+1.0.0 | SemVer MAJOR (phase structure change) |
| Lane type | ... | Match Variable Map §3.X |
| Lane key format | ... | Match Variable Map §3.X |
| Partition grouping | `max_per_partition = N` | Match Variable Map §3.X |
| Workload `est_minutes_per_item` | `X.X` | Match Variable Map §3.X |
| Workload factor special | LEGACY ×1.5, multi-tier ×2.0, ... | Match Variable Map §3.X |
| Dedup key | `xxx_id` | Match Variable Map §3.X |
| Conditional phases (skip triggers) | ... | Từ _contract.json prerequisites hoặc behavior |
| Expert dispatch phase file | `phaseN-xxx.md` | Ghép Variable Map + procedures/ listing |
| Consolidate phase file | `phaseN-xxx.md` | — |
| Handoff phase file | `phaseN-xxx.md` | — |
| Breaking change risk | LOW / MEDIUM / HIGH | Dựa trên số downstream skills bị ảnh hưởng |
```

Rationale phải ghi **tại sao** (vd: "module nặng hơn department → est_minutes ×1.67"), không chỉ copy value.

---

## 6. Non-Goals (các thứ KHÔNG làm trong Phase 3)

1. **KHÔNG refactor logic nghiệp vụ của 4 skills** — chỉ lane-ify + session-isolate + workload-gate. Nội dung feature spec / architecture / UX / task breakdown giữ nguyên.
2. **KHÔNG đổi `registry_scope.fields_owned`** — sẽ phá vỡ CORE-006 contract với downstream skills.
3. **KHÔNG bump version của shared modules** (`_shared/*`) trong phiên rollout skill — nếu shared module cần fix thì tách phiên riêng (ảnh hưởng cả 5 linear skills).
4. **KHÔNG cập nhật digest schema** — chỉ strip metadata trước khi ghi. Nếu schema cần thay đổi, mở ADR amendment.
5. **KHÔNG chạy rollout 2 skills song song** — mỗi skill 1 phiên riêng (xem `phase3-rollout-order.md`).

---

## 7. Tham chiếu

| Nguồn | Vai trò |
|-------|---------|
| `docs/design/skills/ADR-downstream-skills-optimization.md` | ADR đầy đủ 5 kỹ thuật |
| `docs/design/skills/phase1-prereq-shared-infrastructure.md` | Hạ tầng _shared/ (đã xong Phase 1) |
| `docs/design/skills/phase2-analyze-req-remaining-steps.md` | Reference format cho 4 spec files sau |
| `docs/design/skills/phase2-validation-tests.md` | Reference format cho validation phase (F1-F10) |
| `.claude/skills/workflow/_shared/README.md` §4-5 | Module map cho linear skills |
| `.claude/skills/workflow/_shared/_shared.md` | Protocol template strip + atomic write + import convention |
| `.claude/rules/00-core.md` §4a + §4b | Safe-Write Protocol + Cross-Skill Output Path Contract |
| `.claude/skills/protocols/10-post-gate-schema.md` | T1-T4 validation mọi POST-GATE |
| `.claude/skills/protocols/16-critical-decision-gate.md` | CDG-A02 workload override point |
| `.claude/skills/protocols/19-template-usage.md` | CORE-031 Template Usage Rule |

---

## 8. Sign-off Trigger

Tài liệu này PASS khi:

- [ ] 4 Variable Map bảng đã chốt (không mâu thuẫn với Shared Constraints §4).
- [ ] Section §5 decision log template được reference bởi cả 4 spec files Task 2-5.
- [ ] Section §6 non-goals rõ ràng — 4 phiên rollout không vượt scope.
- [ ] Phase 2 sign-off doc (`ADR-downstream-skills-optimization-signoff.md`) có dẫn link đến file này.
