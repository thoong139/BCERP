# 05 — Execution Profiles & Flag Mapping

> **Đọc trước:** [04-contracts-data-model.md](04-contracts-data-model.md)
> **Đọc tiếp:** [06-migration-plan.md](06-migration-plan.md)

Tài liệu này định nghĩa **cách pipeline v6 quyết định chạy cái gì** với ngân sách thời gian/token bao nhiêu. Ba trục quyết định: **Profile** (depth), **Dimension Selection** (breadth), **Scope** (phạm vi dữ liệu).

---

## 1. Mô Hình Quyết Định

```
          ┌────────────────────┐
User ───▶ │ CLI args + flags   │
          └────────┬───────────┘
                   │
         ┌─────────▼──────────┐
         │ Orchestrator parse │
         └─────────┬──────────┘
                   │
   ┌───────────────┼───────────────┐
   ▼               ▼               ▼
 Profile      Dimension        Scope
 (depth)      Selection       (breadth)
   │             │                │
   │             │                │
   └─────────────┴────────────────┘
                 │
                 ▼
       Plan = profile × dims × scope
                 │
                 ▼
         Orchestrator dispatch
```

3 trục độc lập; **mọi tổ hợp đều hợp lệ** miễn chúng không mâu thuẫn runtime budget.

---

## 2. Profile — Trục Depth

4 profile standard, được định nghĩa trong `config/profiles.json` (xem [04 §4](04-contracts-data-model.md)).

| Profile | Dim default (★ LOCKED v1.0) | Time budget | Probe depth | Khi nào dùng |
|---------|----------------------------|-------------|-------------|--------------|
| `quick` | **QD1, QD5** | 5 phút | `quick` | Pre-commit, smoke |
| `standard` | **QD1, QD2, QD5** | 15 phút | `standard` | Pre-PR (mặc định) |
| `deep` | **QD1, QD2, QD5, QD6, QD3** (5 dim) | 45 phút | `deep` | Pre-RC, weekly quality check |
| `exhaustive` | **QD1-7** | 120 phút | `exhaustive` | Pre-GA, audit, compliance |

> **★ Quyết định khoá (09-design-decisions.md §4 + ADR-21):** Default profile `standard` lấy `QD1 + QD2 + QD5` thay vì `QD1 + QD3 + QD5` để ưu tiên **logic + nghiệp vụ + UI** — theo nguyên tắc user (North Star). QD3 (Security) chạy khi có trigger: `--auto` phát hiện diff auth/crypto/secret/token, `--only=security`, hoặc profile `deep`/`exhaustive`.
>
> **Safety floor:** Với profile `standard` và cao hơn, nếu user dùng `--skip` để loại bỏ **toàn bộ** QD1 + QD2 + QD5, orchestrator từ chối (exit với lỗi) — không cho phép một run "standard" mà không kiểm tra correctness + nghiệp vụ + UI. Xem [09-design-decisions.md §8](09-design-decisions.md).

### 2.1 Probe Depth Levels

Mỗi probe trong `dimension.json` khai báo array `depth[]`. Probe chỉ chạy khi profile depth ∈ `depth[]`.

| Depth | Cost | Ví dụ probe chạy |
|-------|------|------------------|
| `quick` | ≤30s, ≤2K tokens | Static regex, route scan |
| `standard` | ≤2m, ≤10K tokens | + Agent review nhẹ, basic a11y audit |
| `deep` | ≤10m, ≤40K tokens | + Runtime E2E, Lighthouse, Semgrep full |
| `exhaustive` | ≤30m per probe, ≤100K tokens | + Multi-browser, load test nhẹ, fuzz |

### 2.2 Budget Guard

Orchestrator tổng hợp `estimated_cost` từ probe manifest. Nếu tổng > budget:

1. Cảnh báo user với estimated time.
2. Đề xuất downgrade profile hoặc bỏ bớt dimension.
3. User confirm → chạy; reject → exit gracefully.

---

## 3. Dimension Selection — Trục Breadth

### 3.0 First-class capability — chọn một hoặc nhiều QD để giới hạn phạm vi

> **NGUYÊN TẮC:** Người dùng luôn có quyền chọn **một** hoặc **nhiều** QD (Quality Dimension) để skill làm việc. Mọi hoạt động của `/wf-fix-bugs` — từ Discovery → Triage → Fix → Verify → Report — **chỉ xảy ra trong phạm vi các QD đã chọn**. Đây là cam kết thiết kế cốt lõi, không phải tuỳ chọn phụ.

**Quy tắc áp dụng toàn pipeline:**

| Thành phần | Hành vi khi `selected_dims = [QD_a, QD_b, ...]` |
|------------|--------------------------------------------------|
| **Orchestrator** | Chỉ spawn lane cho dim ∈ `selected_dims`. Lane khác không khởi chạy (không tốn budget). |
| **Signal Bus** | Chỉ nhận Signal có `dimension ∈ selected_dims`. Signal ngoài phạm vi bị drop + log `filtered_out_of_scope`. |
| **Triage** | Chỉ phân loại Issue có `primary_dimension ∈ selected_dims`. Issue cross-dim được giữ nếu **primary** nằm trong scope. |
| **Fixer** | Chỉ sửa Issue trong scope. Issue ngoài scope được liệt kê "not_in_scope" trong report (không block). |
| **Verifier** | Chỉ re-run probe thuộc dim ∈ `selected_dims`. Không regress test ngoài phạm vi. |
| **Report** | `fix-report.md` có mục **"Phạm vi đã xử lý"** (dims + scope) và **"Ngoài phạm vi (chưa kiểm)"** để user biết rõ coverage. |
| **Phase-summary** | CORE-028 phase-summary.md của mỗi lane + orchestrator đều ghi rõ `selected_dims`. |

**Invariant quan trọng:**
1. `selected_dims.length ≥ 1` — không cho phép chạy 0 dim (phải có ít nhất 1).
2. `selected_dims ⊆ dimensions.enabled_dimensions` từ `dimensions.json`.
3. Profile default cung cấp `selected_dims` mặc định — nhưng **mọi flag dim-related override profile default** (xem §3.1).
4. Khi chạy với subset dims, `fix-status.json v6` ghi:
   ```json
   {
     "selected_dimensions": ["QD3", "QD5"],
     "excluded_dimensions": ["QD1", "QD2", "QD4", "QD6", "QD7"],
     "scope_note": "user_requested_subset"
   }
   ```
5. `--resume` bắt buộc load đúng `selected_dimensions` từ session cũ — không bao giờ auto-mở rộng scope khi resume.

**Ý nghĩa vận hành:**
- Một lần chạy `/wf-fix-bugs --only=security` **không** để lại "debt" cho các dim khác — đó là quyết định có chủ đích của user, không phải bỏ sót.
- Muốn full coverage → chạy nhiều session lần lượt (xem §8 Multi-Session) hoặc 1 session `--profile=exhaustive`.
- User nhìn report biết ngay: **đã xử lý gì + chưa xử lý gì** — không có vùng mờ.

---

### 3.1 Cách chọn

| Cách | Ví dụ | Kết quả |
|------|-------|---------|
| Theo profile default | `/wf-fix-bugs` (không flag) | Dim = profiles.standard.default_dimensions |
| Explicit via `--dims` | `/wf-fix-bugs --dims=QD3,QD5` | Chỉ chạy QD3 + QD5 |
| Only một dim | `/wf-fix-bugs --only=security` | Alias → `--dims=QD3` |
| Skip một dim | `/wf-fix-bugs --skip=QD7` | Chạy profile default trừ QD7 |
| Auto-detect | `/wf-fix-bugs --auto` | Đọc preflight report → chọn dim có issue |

### 3.2 Dim Alias (user-friendly)

| Alias | Map tới | Cho phép trong CLI |
|-------|---------|---------------------|
| `functional` | QD1 | ✅ |
| `business` | QD2 | ✅ |
| `security` | QD3 | ✅ |
| `performance` | QD4 | ✅ |
| `ux` / `a11y` | QD5 | ✅ |
| `data` | QD6 | ✅ |
| `compat` | QD7 | ✅ |

### 3.3 Auto-detect Heuristics

`--auto` đọc các nguồn theo thứ tự ưu tiên (tuân theo nguyên tắc North Star — logic + nghiệp vụ + UI):

1. **Baseline luôn bật (tick mặc định):** `QD1 + QD2 + QD5` — correctness + nghiệp vụ + UI. Không bao giờ bỏ nếu profile ≥ `standard`.
2. **Domain trigger → QD6 (🟢 recommend):** `req-registry.json.departments[]` chứa `finance | healthcare | banking | logistics | accounting` → tick thêm QD6 (Data Integrity).
3. **Git diff trigger → QD3 (🟢 recommend):** diff 24h touch file match pattern `auth | crypto | secret | token | password | jwt | session | permission | role` → tick thêm QD3 (Security).
4. **Preflight trigger:** `.mc-data/work/wf-preflight/preflight-report.md` có WARN/FAIL theo dim nào → tick thêm dim đó.
5. **Branch/sprint trigger → QD4 (🟡 suggest):** branch name chứa `perf | speed | optimization` hoặc sprint tag `performance` → suggest QD4 (user quyết định).
6. **Mobile/responsive trigger → QD7 (🟡 suggest):** diff touch `responsive | mobile | media-query` hoặc `--responsive` flag → suggest QD7.
7. **Fallback:** Nếu không có trigger nào khác → dùng đúng `profiles.<current>.default_dimensions`.

**Legend:** 🟢 = tick sẵn (user có thể untick nếu muốn); 🟡 = suggest (không tick sẵn, user chủ động chọn).

Kết quả `--auto` luôn hiển thị cho user trong **Interactive Selection Gate (ISG)** + ask confirm trước khi chạy. Xem [08 §3](08-user-scenarios-solutions.md) về ISG layout và [09 §5](09-design-decisions.md) về heuristics đã chốt.

---

## 4. Scope — Trục Data Breadth

Scope quyết định **bao nhiêu code/feature** được probe. Giữ nguyên semantic v5.

| Scope | Flag | SESSION_DIR | Dữ liệu input |
|-------|------|-------------|---------------|
| `all` (default) | — | `run-NNN--YYYYMMDD/` | Toàn repo |
| `system` | `--scope=system --name=<sys-id>` | `sessions/<sys-id>/run-NNN--YYYYMMDD/` | Chỉ system trong registry |
| `module` | `--scope=module --name=<sys-id>/<mod-id>` | `sessions/<sys-id>/<mod-id>/run-NNN--YYYYMMDD/` | Chỉ module |
| `file` (mới v6) | `--scope=file --name=<path>` | `sessions/file-<hash>/run-NNN--YYYYMMDD/` | Chỉ 1-N file (comma-separated) |

Scope `file` là tiện ích cho dev iteration — chỉ cho phép `quick` hoặc `standard` profile.

---

## 5. Flag Mapping — Tương thích v5

Orchestrator v6 **giữ lại toàn bộ flag v5** và map sang profile/dim/scope mới.

### 5.1 Bảng map

| v5 flag | v6 hành vi | Ghi chú |
|---------|-----------|---------|
| `/wf-fix-bugs` (no flag) | profile=standard, dims=**[QD1, QD2, QD5]**, scope=all | ★ Mặc định v1.0 — LOCKED (ADR-21) |
| `--deep` | profile=deep, dims=**[QD1, QD2, QD5, QD6, QD3]** | ★ v1.0 — thêm QD4 nếu kết hợp `--responsive` |
| `--full-test` | profile=exhaustive, dims=[QD1..QD7] | Full probe set (không đổi) |
| `--responsive` | Thêm probes tagged `responsive` vào lane QD5 | Không đổi profile |
| `--dry-run` | Fixer + Verifier skip; Triage chạy bình thường | Như v5 |
| `--resume` | Load `fix-status.json` → route theo `active_phase` | Mở rộng: per-lane resume |
| `--status` | Chỉ in `fix-status.json` + latest `phase-summary.md`, không chạy | Như v5 |
| `--scope=all\|system\|module` | Như §4 | Như v5 |
| `--name=<id>` | Bắt buộc với `--scope=system\|module\|file` | Như v5 |
| `--url=<url>` | Override base URL cho runtime probe | Như v5 |
| `--credentials=<file>` | Inject auth cho runtime probe | Như v5 |
| `--no-browser` | Disable probes tagged `runtime-browser` | Lane vẫn chạy static probes |
| `--browser-only` | Enable ONLY probes tagged `runtime-browser` | Skip static |

### 5.2 Flag mới (v6)

| Flag | Hành vi |
|------|---------|
| `--profile=<quick\|standard\|deep\|exhaustive>` | Explicit profile |
| `--dims=QD1,QD2,QD5` | Explicit dim list (ví dụ — user có thể chọn bất kỳ tổ hợp ∈ enabled_dimensions) |
| `--only=<alias>` | Alias cho `--dims=<one>` |
| `--skip=QD7` | Remove khỏi profile default |
| `--auto` | Auto-detect dim từ preflight + git diff |
| `--max-parallel-lanes=N` | Override default 3 |
| `--time-budget=<minutes>` | Override budget; orchestrator enforce cắt probe dài |
| `--explain` | Không chạy, in plan (profile × dims × scope × ước lượng cost) |

### 5.3 Conflict Resolution

Khi flag mâu thuẫn:

```
Explicit > Profile > Default
--dims > profile.default_dimensions
--profile > implicit từ --deep/--full-test (cảnh báo)
--no-browser + --browser-only → ERROR, exit
--scope=file + profile=deep|exhaustive → downgrade tới standard + warn
```

Orchestrator phải in bảng "Plan trước khi chạy" (xem `--explain`) để user confirm khi conflict.

---

## 6. Plan Composition — Ví Dụ

### 6.1 Ví dụ A — Pre-commit dev (default, không flag)

```
$ /wf-fix-bugs
→ profile=standard
→ dims=[QD1, QD2, QD5]   # ★ default mới — logic + nghiệp vụ + UI
→ scope=all
→ max_parallel=3, budget=15m
→ ISG tick sẵn: QD1, QD2, QD5
→ ISG 🟢 suggest thêm: QD6 (nếu domain=finance|healthcare|banking|logistics),
                       QD3 (nếu git diff touch auth/crypto/secret/token)
```

### 6.2 Ví dụ B — Security audit

```
$ /wf-fix-bugs --only=security --profile=exhaustive
→ profile=exhaustive
→ dims=[QD3]
→ scope=all
→ max_parallel=1 (chỉ 1 lane), budget=30m
→ Phase: Lane QD3 → Signal Bus → Triage (CDG enabled cho secrets)
```

### 6.3 Ví dụ C — UI regression sau merge

```
$ /wf-fix-bugs --only=ux --responsive --browser-only
→ profile=standard (kế thừa default)
→ dims=[QD5]
→ probes filter: chỉ runtime-browser + responsive-tagged
→ scope=all
```

### 6.4 Ví dụ D — Deep audit một module

```
$ /wf-fix-bugs --deep --scope=module --name=crm/customer
→ profile=deep
→ dims=[QD1, QD2, QD5, QD6, QD3]   # ★ 5 dim — không auto-bật QD4/QD7
→ scope=module, SESSION_DIR=sessions/crm/customer/run-018--20260420/
→ budget=45m, max_parallel=3
→ Thêm --responsive → QD7; thêm perf flag → QD4
```

### 6.5 Ví dụ E — Dry-run plan preview

```
$ /wf-fix-bugs --explain --profile=deep
→ KHÔNG chạy
→ In bảng:
    ┌──────┬─────────┬──────────┬────────────┐
    │ Dim  │ Probes  │ Est time │ Est tokens │
    ├──────┼─────────┼──────────┼────────────┤
    │ QD1  │ 7       │ 8m       │ 25K        │
    │ QD2  │ 4       │ 5m       │ 18K        │
    │ ...  │ ...     │ ...      │ ...        │
    └──────┴─────────┴──────────┴────────────┘
    Tổng: 45m, 150K tokens — OK trong budget.
```

---

## 7. Resume Routing (Per-Lane)

Khác với v5 (resume cả workflow), v6 cho phép resume **đến từng lane**.

```
$ /wf-fix-bugs --resume
→ Đọc latest $SESSION_DIR/fix-status.json
→ active_phase=lanes_running
→ Với mỗi lane:
    - status=done    → skip
    - status=partial → resume từ last probe
    - status=failed  → user confirm re-run / skip
    - status=pending → chạy từ đầu
```

Orchestrator **không bao giờ resume sang phase mới** mà không user confirm khi có lane partial/failed.

---

## 8. Multi-Session & ERP

Dự án lớn (ERP 20+ module) thường không thể chạy `scope=all` profile=exhaustive một lần. Workflow khuyến nghị:

1. Chạy `profile=quick --scope=all` — smoke toàn repo (5-10m).
2. Theo kết quả, chạy `--scope=system` per system với `profile=standard` — song song nhiều session nếu máy đủ mạnh.
3. Cuối cùng chạy `--profile=exhaustive --only=security` toàn repo cho security sweep.

Mỗi session có `SESSION_DIR` riêng, không ghi đè. `fix-history.md` gộp high-level summary per run.

---

## 9. Runtime Budget Calculation

Orchestrator tính budget theo công thức:

```
total_est_time    = Σ (probe.estimated_cost.time_seconds) / min(lane_count, max_parallel_lanes)
total_est_tokens  = Σ (probe.estimated_cost.tokens)
budget_hard_cap   = profile.time_budget_minutes × 60

IF total_est_time > budget_hard_cap:
  IF --time-budget explicit → reject probe dài, chạy best-effort
  ELSE → cảnh báo user, offer downgrade profile
```

### 9.1 Mặc định max_parallel_lanes = 3

Dự án lớn có thể muốn chạy 5+ lane song song. Không khuyến nghị vì:

- Agent concurrency giới hạn.
- Context/memory pressure.
- Debug log trộn lẫn khó đọc.

Cho phép override `--max-parallel-lanes=5` với cảnh báo runtime warning.

---

## 10. Profile × Legacy Mode

Pipeline v6 phải nhận biết LEGACY_MODE (CORE-021) khi chạy:

```
IF LEGACY_MODE == true:
  - QD1 probes phải dùng module-code-mapping.json thay vì giả định file layout chuẩn.
  - QD2 probes phải soft (tránh false positive với business rule đặc biệt của legacy).
  - QD6 probes phải cross-ref với DB schema thực (không chỉ migration).
  - Orchestrator note "LEGACY_MODE detected" trong phase-summary.md.
```

Legacy mode KHÔNG đổi profile default — chỉ ảnh hưởng cách từng probe diễn giải kết quả.

---

## 11. Interaction với CDG (CORE-027)

Một số probe được mark `cdg: true` trong `dimension.json`:

- P3.01 Secrets (nếu found + auto-fix requested) → CDG.
- P6.04 Destructive migration detection → CDG.
- P4.07 Schema change suggestion → CDG.

CDG flow:

1. Probe phát hiện → mark Issue `fixability=ESCALATE_*`.
2. Triage KHÔNG auto fix.
3. User confirm trong `bug-triage.md` → Fixer chạy; reject → ESCALATE.

Xem [03 §7.3 CORE-027 CDG points](03-architecture.md).

---

## 12. Profile Extension Policy

Muốn thêm profile mới (ví dụ `nightly`, `prod-incident`)?

1. Thêm entry vào `profiles.json`.
2. Bump schema `profiles-v1` → `profiles-v1.1` nếu thêm required field.
3. Thêm flag mapping trong `profiles.json.flag_mapping`.
4. Cập nhật `docs/design/skills/wf-fix-bugs/05-execution-profiles.md` §2.

Không hardcode profile trong SKILL.md orchestrator — luôn đọc từ config.

---

## 13. Checklist Implementer

Khi viết orchestrator v6 hoặc thay đổi profile:

- [ ] Đọc profile từ `config/profiles.json`, không hardcode.
- [ ] Map flag → profile × dim × scope trong `flag_mapping` section.
- [ ] Hỗ trợ `--explain` để user preview plan.
- [ ] Budget guard chạy trước khi spawn lane.
- [ ] PRE-GATE content-level (CORE-011).
- [ ] Resume routing đọc đúng `active_phase` + per-lane status.
- [ ] LEGACY_MODE detect qua `project-context.md` (CORE-021).
- [ ] Conflict resolution rule rõ + in bảng khi conflict.
- [ ] `--dry-run` không chạm Fixer/Verifier.
- [ ] `--status` không chạy, chỉ in.

---

## 14. Liên kết

- Quality Dimensions chi tiết: [02-quality-dimensions.md](02-quality-dimensions.md)
- Architecture + Components: [03-architecture.md](03-architecture.md)
- Schemas + Contracts: [04-contracts-data-model.md](04-contracts-data-model.md)
- Migration: [06-migration-plan.md](06-migration-plan.md)
- ADRs: [07-tradeoffs-adr.md](07-tradeoffs-adr.md)
