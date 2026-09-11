# 05 — Execution Profiles, Dimension Selection & Scope (v2.0)

> **Đọc trước:** [04-contracts-data-model.md](04-contracts-data-model.md)
> **Đọc tiếp:** [06-evolution-history.md](06-evolution-history.md)
> **Trạng thái:** v2.0 · Phản ánh skill `wf-fix-bugs v10.18.0` · 4 profiles × 11 dimensions × 3 scope + Playwright 3 modes
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/05-execution-profiles.md](../../99-archive/wf-fix-bugs-design-v1.0/05-execution-profiles.md) (4 profiles × 7 dimensions v6.0)

---

## 1. Mô Hình Quyết Định

```
                  ┌────────────────────┐
        User ───▶ │ CLI args + flags   │
                  └────────┬───────────┘
                           │
                 ┌─────────▼──────────┐
                 │ Orchestrator parse │ (Phase 1 phase1-parse-flags.sh)
                 └─────────┬──────────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
       ▼                   ▼                   ▼
    Profile         Dimension Selection      Scope
    (depth)              (breadth)         (data range)
       │                   │                   │
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                           ▼
              Plan = profile × dims × scope
                           │
                           ▼
              Orchestrator Phase 1 → Phase 7
                  + Playwright mode
                  + CI tools (auto)
                  + Multi-session safety
```

**3 trục quyết định độc lập** + 2 trục phụ trợ (Playwright mode, Multi-session). Mọi tổ hợp hợp lệ miễn không vi phạm **Safety Floor** (xem §6).

---

## 2. Profile — Trục Depth (4 profiles)

| Profile | Dim default | Time budget | Probe depth | Khi nào dùng |
|---------|-------------|-------------|-------------|---------------|
| `quick` | QD1 + QD5 | 5 phút | `quick` | Pre-commit, smoke test |
| `standard` | QD1 + QD2 + QD5 (★ LOCKED v1.0 ADR-21) | 15-20 phút | `standard` | Pre-PR (default) |
| `deep` | QD1 + QD2 + QD3 + QD5 + QD6 + QD8 + QD9 + QD10 (8 dims) | 45-90 phút | `deep` | Pre-RC, weekly quality check |
| `exhaustive` | QD1-QD11 (toàn bộ 11 dims) | 120-180 phút | `exhaustive` | Pre-GA, audit, compliance |

> **★ ADR-21 (v6.0):** Default `standard` lấy `QD1 + QD2 + QD5` thay vì `QD1 + QD3 + QD5` để ưu tiên **logic + nghiệp vụ + UI** (North Star).
> QD3 (Security) chạy khi có trigger: `--auto` phát hiện diff auth/crypto/secret/token, `--only=security`, hoặc profile `deep`/`exhaustive`.

### 2.1 Profile Trigger Lifecycle

| Moment | Profile recommended | Auto-trigger condition |
|--------|----------------------|-------------------------|
| Pre-commit hook | `quick` | Mặc định khi git pre-commit |
| Pre-PR (manual) | `standard` | User chạy `/wf-fix-bugs` không flag |
| Pre-RC (release candidate) | `deep` | Manual / CI nightly |
| Pre-GA (general availability) | `exhaustive` | Manual / audit |

### 2.2 Probe Depth Levels

Mỗi probe trong `dimension.json` khai báo array `depth[]`. Probe chỉ chạy khi profile depth ∈ `depth[]`.

| Depth | Cost target | Ví dụ probe |
|-------|-------------|-------------|
| `quick` | ≤30s, ≤2K tokens | Static regex, route scan, lint |
| `standard` | ≤2m, ≤10K tokens | + Agent review nhẹ, basic a11y audit |
| `deep` | ≤10m, ≤40K tokens | + Runtime E2E, Lighthouse, Semgrep full, QD9 Wave 1 core |
| `exhaustive` | ≤30m/probe, ≤100K tokens | + Multi-browser, load test, fuzz, QD9 Wave 1.5 deep, QD11 3-pass full |

### 2.3 Budget Guard

Orchestrator tổng hợp `estimated_cost` từ probe manifest (Phase 3 `plan-isg-partition.sh`). Nếu tổng > budget:

1. **Workload Gate CDG-11** trigger (xem §5)
2. Cảnh báo user với estimated time + cost
3. Đề xuất downgrade profile hoặc chia chunk
4. User confirm → chạy; reject → exit gracefully (E031)

---

## 3. Dimension Selection — Trục Breadth (11 dims)

### 3.0 First-Class Capability

> **NGUYÊN TẮC (P6):** Người dùng luôn có quyền chọn **một** hoặc **nhiều** QD để skill làm việc. Mọi hoạt động — từ Phase 1 → Phase 7 — **chỉ xảy ra trong phạm vi các QD đã chọn**. Đây là cam kết thiết kế cốt lõi.

### 3.1 Selection Syntax

| Flag | Behavior | Example |
|------|----------|---------|
| `--dims=<list>` | Set exact dimensions (comma-separated) | `--dims=QD1,QD3,QD5` |
| `--only=<slug>` | Shorthand cho 1 dim | `--only=security` → QD3 only |
| `--skip=<list>` | Exclude dims khỏi profile default | `--skip=QD2,QD11` |
| (no flag) | ISG (Interactive Selection Gate) hoặc default profile | — |

### 3.2 11 Dimension Slugs

| Slug | Dim | Lane Skill |
|------|-----|------------|
| `functional` | QD1 | `wf-fix-functional` |
| `business` | QD2 | `wf-fix-business` |
| `security` | QD3 | `wf-fix-security` |
| `performance` | QD4 | `wf-fix-performance` |
| `ux-a11y` | QD5 | `wf-fix-ux-a11y` |
| `data` | QD6 | `wf-fix-data` |
| `compat` | QD7 | `wf-fix-compat` |
| `observability` | QD8 | `wf-fix-observability` |
| `runtime-health` | QD9 | `wf-fix-runtime-health` |
| `integration` | QD10 | `wf-fix-integration` |
| `business-completeness` | QD11 | `wf-fix-business-completeness` |

### 3.3 Interactive Selection Gate (ISG)

Khi user chạy `/wf-fix-bugs` **không kèm** flag dim nào → orchestrator dùng **ISG fast-path** (`phase1-isg-fastpath.sh`) tự áp dụng profile default. Trong tương lai (v11), ISG sẽ trở thành interactive như draft v1.0 (xem [09-design-decisions.md §Q14](09-design-decisions.md)).

Hiện tại (v10.x): `phase1-isg-fastpath.sh` hardcoded lookup theo profile:
- `quick` → `["QD1","QD5"]`
- `standard` → `["QD1","QD2","QD5"]`
- `deep` → 8 dims
- `exhaustive` → 11 dims

Escape hatch: `MCV3_FIX_BUGS_FORCE_ISG=1` → bypass fast-path, dùng real ISG analyzer (`python -m isg`).

### 3.4 SKIP Rules (Auto Applied)

Một số dim auto SKIP dựa trên context:

| Dim | SKIP Condition | Lý do |
|-----|----------------|-------|
| QD9 Runtime Health | `interface_type=api-only` OR `--no-browser` OR `profile=quick` | Không có browser để test |
| QD10 Cross-Module | Single module project OR `profile=quick` | Không có cross-module dependency |
| QD11 Business Completeness | Single module OR `interface_type=api-only` OR `profile=quick` | LLM analysis cần multi-module pattern |

### 3.5 CDG-RELIABILITY-RISK Trigger (QD8)

Khi scope chứa `payment` / `auth` / `crypto` modules → QD8 Observability bắt buộc kể cả `profile=quick`. CDG render warning nếu user `--skip=QD8` trong các module này.

---

## 4. Scope — Trục Data Range (3 options)

| Flag | Scope | Behavior |
|------|-------|----------|
| `--scope=all` (default) | Toàn dự án | Scan tất cả `src/` hoặc `apps/` |
| `--scope=system --name=<id>` | 1 system | Scan 1 system trong monorepo (vd: `apps/erp-finance/`) |
| `--scope=module --name=<id>` | 1 module | Scan 1 module trong system (vd: `apps/erp-finance/src/invoice/`) |

### Cross-Scope với SCOPE Inheritance

| Scope | DIMS_ARRAY default | Workload estimate |
|-------|---------------------|---------------------|
| `all` (large ERP, 50+ modules) | Standard profile + extra QD10 | Trigger Workload Gate CDG-11 nếu ratio ≥1.5× budget |
| `system` | Same as `all` nhưng giới hạn 1 system | Thường trong budget |
| `module` | Same as `all` | Luôn trong budget |

---

## 5. Workload Gate CDG-11 (Phase 3 Step 3.4)

> Trigger khi `estimated_workload >= 1.5× profile_budget`. Phòng tránh job nặng vượt context/time budget.

### Dead Zone vs Soft Zone vs Hard Zone

| Zone | Ratio | Hành vi |
|------|-------|---------|
| **Dead zone** | `W < 0.8× budget` | KHÔNG prompt, chạy thẳng |
| **Soft zone** | `0.8× ≤ W < 1.5× budget` | WARNING 1 dòng, không gate |
| **Hard zone** | `W ≥ 1.5× budget` | CDG-11 mở — AskUserQuestion |

### CDG-11 Options (Hard Zone)

```
Workload Gate — Job nặng phát hiện

Profile: standard (budget 15-20 phút)
Estimated: 47 phút (3.1× budget)
Dimensions: QD1, QD2, QD5 (default)
Scope: all (52 modules)

Options:
  1) Chia thành 4 chunks (mỗi chunk ~12 phút) — recommend
  2) Downgrade profile sang quick (5 phút, QD1+QD5 only)
  3) Continue full (chấp nhận 47 phút)
  4) Cancel
```

### Partition Strategy

| Plan | Strategy | Description |
|------|----------|-------------|
| **A** (default) | Sub-menu | Chia theo module structure (mental model user) |
| **B** | By dim | Chia theo dimension (QD1 lane riêng, QD2 lane riêng, ...) |
| **C** | Downgrade | Giảm profile từ deep → standard hoặc standard → quick |

> ADR-23 (v6.0): Sub-menu là default duy nhất được recommend. Plan D "custom split" defer v11.

---

## 6. Safety Floor (Non-Negotiable, ADR-22)

> Bảo vệ correctness ở mọi tổ hợp flag. Profile ≥ `standard` KHÔNG được bỏ toàn bộ `QD1+QD2+QD5`.

### Quy Tắc Cứng

| # | Rule | Enforcement |
|---|------|-------------|
| 1 | Profile ≥ standard PHẢI có ít nhất 1 trong QD1/QD2/QD5 | Phase 3 fail E030 nếu vi phạm |
| 2 | Verification Ripple always on (cross-module impact) | QD10 auto-add khi sửa shared code |
| 3 | QD3 (Security) KHÔNG dùng scan cache | `wf-fix-security` skip cache layer |
| 4 | CDG render khi phát hiện secret (E090-like) | Phase 4 INLINE AskUserQuestion |
| 5 | POST-GATE T1-T4 mọi phase | Không skip POST-GATE bằng flag |
| 6 | SAFE-UPDATE impl_status (CORE-008) | `wf-fix-execute` enforce no-downgrade |

### Ví dụ vi phạm

```bash
# ❌ FAIL E030
/wf-fix-bugs --profile=standard --skip=QD1,QD2,QD5
# → "Safety Floor violated: profile=standard không được bỏ toàn bộ QD1+QD2+QD5"

# ✅ OK
/wf-fix-bugs --profile=standard --skip=QD2
# → DIMS_ARRAY = [QD1, QD5]
```

---

## 7. Playwright Mode (Trục Phụ Trợ)

| Mode | Flag | Behavior |
|------|------|----------|
| **Headless** (default) | — | Chromium headless, invisible. Session-isolated. |
| **Visible** | `--show-browser` | Chromium visible window for debugging + user observation. |
| **Mobile** | `--mobile` | Device emulation (iPhone 14 390×844, Pixel 7 412×915, iPad Pro 1024×1366). Auto-sets `--show-browser`. |

### Sub-flags

| Flag | Purpose |
|------|---------|
| `--url=<base_url>` | BASE_URL cho browser tests (required nếu QD9 active) |
| `--credentials=<email:password>` hoặc `cookie:NAME=VALUE` | Auth credentials cho login tests |
| `--no-browser` | SKIP toàn bộ browser-based probes (QD5/QD7/QD9) |
| `--responsive` | Trigger QD7 responsive tests |
| `--full-test` | Shorthand `--deep + --responsive` |
| `--deep` | Activate deep mode cho tất cả probes |

### Lane Affinity

| QD | Playwright |
|----|-----------|
| QD5 UX/A11y | **Required** (axe-core trên browser thật) |
| QD7 Compat | **Required** (cross-browser + responsive) |
| QD9 Runtime Health | **Required** (3 modes: console error / network / auth flow) |
| Others | Optional (LHR opt-in cho QD4) |

### Serialization (Protocol 22)

Lane có Playwright TỰ acquire writer-lock `playwright` qua `global-rw-lock.sh`. Khi acquired, các Playwright lane khác đợi. Orchestrator KHÔNG split wave.

---

## 8. Multi-Session Safety

> Cho phép N phiên `wf-fix-bugs` song song trên cùng máy cho module/hệ thống khác nhau.

| Scenario | An toàn? | Lý do |
|----------|---------|-------|
| 2 phiên, BASE_URL khác nhau (`:3000` vs `:4000`) | ✅ | Browser session-isolated qua port + user-data-dir |
| 2 phiên, cùng BASE_URL, test data isolated (multi-tenant) | ⚠️ E090b CDG | Tiếp tục nếu user chắc chắn isolated |
| 2 phiên, cùng BASE_URL, shared state | ❌ E090b BLOCK | Flaky results — dùng "Đợi" |
| 1 phiên, profile=exhaustive | ✅ | Chạy bình thường |
| N phiên parallel, profile=quick/standard | ✅ | Low CPU/RAM contention |

### E090b Workflow

```
Phase 4 Step 4.3 phát hiện peer session cùng BASE_URL:

E090b BASE_URL Conflict — 2 phiên cùng URL

Phiên hiện tại: 2026-05-16-module-payment-01 (BASE_URL=http://localhost:3000)
Phiên khác (peer):
  - ID: 2026-05-16-system-erp-02
  - PID: 12345 (alive)
  - BASE_URL: http://localhost:3000

Risk: Browser session conflict → flaky results, shared cookies, race conditions

Options:
  1) Tiếp tục (chấp nhận risk — chỉ chọn nếu isolated qua DB tenancy)
  2) Đợi peer hoàn thành (poll mỗi 30s, max 30 phút)
  3) Cancel pipeline
```

### Escape Hatches

- `MCV3_PW_ALLOW_SHARED_URL=1` — bypass E090b cho CI/CD
- `MCV3_LOCK_STALE_MINUTES=30` (default 60) — adjust lock stale timeout

---

## 9. Resume Strategy Matrix (`--resume-strategy`)

| Pipeline state | `prompt` (default) | `auto` | `force-fresh` |
|-----------------|---------------------|--------|----------------|
| `DONE` | AskUser: Re-run / Cancel | Cancel silently (INFO) | Tạo fresh session |
| `failed` | AskUser: Resume / Fresh / Cancel | **Resume** từ phase failed | Tạo fresh session |
| `in_progress` | Continue resume (R5+) | Continue resume (R5+) | Tạo fresh session |

- `auto` PHÙ HỢP cho CI/cron — không block khi gặp DONE/FAILED
- `force-fresh` cho recovery test — hiếm dùng
- Tất cả strategy TÔN TRỌNG R6 Staleness Guard và R7 Lock Check — không bypass safety rails

---

## 10. Context Budget Tiers (CORE-038)

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint (lưu state files) |
| 80-90% | Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn `--resume` |
| > 90% | **FORCE STOP** (E009) |

Phase 4 monitor mỗi 30s qua `monitor-lanes.sh`; Phase 7 check ở Step 7.5 trước khi generate 4 reports.

---

## 11. Argument Reference (Canonical)

```
/wf-fix-bugs [mô-tả-lỗi]
             [--scope=all|system|module] [--name=<id>]
             [--profile=quick|standard|deep|exhaustive]
             [--dims=QD1,QD3,QD5] [--only=<slug>] [--skip=<list>]
             [--dry-run]
             [--resume] [--status] [--migrate]
             [--session=<SESSION_ID>] [--resume-strategy=prompt|auto|force-fresh]
             [--llm-scan]
             [--show-browser] [--mobile] [--url=<app-url>]
             [--credentials=email:password|cookie:NAME=VALUE]
             [--no-browser]
             [--deep] [--full-test] [--responsive]
             [--from-preflight] [--from-cmi]
```

> **Canonical input spec:** `_contract.json §inputs`. Argument bảng `SKILL.md §Arguments` là bản rút gọn.

---

## 12. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [02-quality-dimensions.md](02-quality-dimensions.md) | 11 QDs + skip rules |
| [03-architecture.md](03-architecture.md) | Phase pipeline + Playwright integration |
| [04-contracts-data-model.md](04-contracts-data-model.md) | fix-status.json schema |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADR-21 (default profile), ADR-22 (Safety Floor) |
| [09-design-decisions.md](09-design-decisions.md) | Q14-Q23 locked decisions |
| `.claude/skills/protocols/22-cross-session-rw-lock.md` | Multi-session R/W lock |
