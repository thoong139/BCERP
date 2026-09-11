---
name: status
version: 1.4.0
last_updated: 2026-05-07
description: |
  Xem tiến độ triển khai dự án — tổng quan dashboard, sprint progress, feature completion.
  Đọc từ roadmap và registry, hiển thị ngay không cần tính toán phức tạp.
  Read-only utility skill, không sửa files hay registry.

  TRIGGER khi:
  - User hỏi: "tiến độ", "progress", "status", "trạng thái", "xem tiến độ"
  - User hỏi: "show status", "tình hình dự án", "đang làm đến đâu rồi"
  - Sau khi /wf-implement-feature để kiểm tra tổng thể

  LUÔN trigger khi user muốn biết tiến độ dự án — dù không dùng từ "status".

  KHÔNG trigger khi:
  - Chỉ hỏi trạng thái một feature cụ thể → dùng `/wf-implement-feature --status`
  - Muốn chi tiết một task → đọc trực tiếp tasks file

argument-hint: "[--sprint=S0X] [--system=XXX] [--detailed]"
allowed-tools: Read, Grep, Glob, Bash
---

# /status: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Hiển thị project progress dashboard từ registry, roadmap và work data |
| **Prerequisites** | `.mc-data/docs/_meta/req-registry.json` (tối thiểu) |
| **Duration** | Quick (single-pass, read-only) |
| **Phases** | 2 phases — thu thập data → hiển thị dashboard |
| **Input** | `req-registry.json`, `P5-00-implementation-roadmap.md`, `work/`, `sync/` |
| **Output** | Dashboard text (không tạo file) |

**Cũng được định nghĩa tại:** `.claude/skills/status/SKILL.md` (v1.4.0) — file gốc, tham chiếu từ `.claude/commands/status.md`. File này là bản sao đồng bộ theo quy ước thư mục `workflow/`.

### Workflow Position

```
/wf-plan-modules → /wf-implement-feature → /status ← YOU ARE HERE
                                              ↓
                                       /wf-implement-feature (tiếp tục)
```

Next: `/wf-implement-feature` (tiếp tục implement) hoặc `/wf-verify-sync` (kiểm tra trước release)

**Read-Only Skill** — Sequential execution, không spawn agents, không modify files. Retry max 3 lần nếu data parse error. Không có checkpoint/resume (single-pass).

**Observability (CORE-026):** Append START/COMPLETE/FAIL entries vào `.mc-data/work/_trace/session-log.json`. KHÔNG đọc lại file này (output-only). Vì `status` là read-only utility skill, KHÔNG tạo `phase-summary.md` (CORE-028 áp dụng cho workflow skills sản sinh artifacts).

---

## Accuracy Assurance Protocol

> **Protocol:** Xem `.claude/skills/protocols/`

### Fix Rules theo loại lỗi

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `json_parse_error` | Re-read file, try partial parse | File corrupted |
| `calculation_mismatch` | Recalculate từ raw data | Source data inconsistent |
| `file_not_found` | Graceful degrade (skip section) | Registry missing (E002) |
| `status_value_invalid` | Map to `not_started` (safe default) | N/A |

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| (none) | Tổng quan project: overview + systems + current work | — |
| `--sprint=S0X` | Chi tiết một sprint cụ thể (VD: `--sprint=S01`) | — |
| `--system=XXX` | Lọc theo system (VD: `--system=CRM`) | — |
| `--detailed` | Hiển thị tất cả features với chi tiết tasks | — |

---

## Status Value Convention

> Đồng bộ với CORE-010 — `impl_status` chỉ có 4 giá trị canonical.
> Đồng bộ với `/wf-implement-feature` Phase 6 và `/wf-verify-sync` Phase 4.

**Canonical `impl_status` trong `req-registry.json` (CORE-010):**

| Value | Icon | Mô tả | Set bởi |
|-------|------|-------|---------|
| `done` | -- | Feature hoàn thành, đã qua review | `/wf-implement-feature` Phase 6 |
| `in_progress` | -- | Đang triển khai | `/wf-implement-feature` Phase 1 |
| `not_started` | -- | Chưa bắt đầu (default) | Default |
| `skipped` | -- | User chủ động bỏ qua | `/wf-define-features`, `/wf-plan-modules` |

**Derived states (skill `status` tự suy ra cho dashboard, KHÔNG ghi vào registry):**

| Derived | Icon | Suy ra từ | Mục đích hiển thị |
|---------|------|-----------|-------------------|
| `paused` | -- | `impl_status=in_progress` VÀ có checkpoint trong `work/wf-implement-feature/.../sessions/` | Phân biệt feature đang chạy vs. đang tạm dừng |
| `blocked` | -- | Có CRITICAL/HIGH issues trong `fix-status.json` chưa resolved cho REQ-ID đó | Gợi ý ưu tiên cho user |

> **Lưu ý:** `paused` và `blocked` là derived states do skill này tự tính — không phải giá trị `impl_status`. KHÔNG ghi ngược vào registry (CORE-006: status là read-only, NONE role).

---

## Phase 1: Thu thập Status Data

> Đọc các files status để lấy dữ liệu — chọn files phù hợp theo arguments.

**PRE-GATE:** `test -f .mc-data/docs/_meta/req-registry.json`

| Step | Action | Verify |
|------|--------|--------|
| 1.0 | **LEGACY_MODE detection (CORE-021):** `LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes`. KHÔNG dùng `ledger.json` (false positive — tồn tại từ Stage 0.5) | Context check |
| 1.0a | Nếu LEGACY_MODE = true VÀ `ledger.json` tồn tại: đọc `pipeline_status` từ `ledger.json` để hiển thị Phase 2L. Nếu `pipeline_status == "COMPLETE"` → coi như đã thoát legacy pipeline, skip Phase 2L | Ledger optional read |
| 1.1 | Đọc `req-registry.json` (**bắt buộc**) | File read |
| 1.2 | Nếu tồn tại: đọc `P5-00-implementation-roadmap.md` | File read hoặc skip |
| 1.3 | Nếu `--sprint=S0X`: đọc sprint file tương ứng trong `phase5-implementation/sprints/` | Sprint file read |
| 1.4 | Nếu `--detailed`: scan task files trong `phase5-implementation/tasks/` | Task files read |
| 1.5 | Nếu `--system=XXX`: lọc features theo system | Filter applied |
| 1.6 | **Scan v4.0 session-isolated impl-status (wf-implement-feature v4.0+):**<br>- List feature dirs: `.mc-data/work/wf-implement-feature/*/` (mỗi dir = 1 `$FEATURE_SLUG`)<br>- Resolve active session qua `current.txt`: đọc relative path → đường dẫn `sessions/{$SESSION_ID}/impl-status.json`<br>- Fallback v3.x flat layout: nếu không có `current.txt` → thử đọc trực tiếp `.mc-data/work/wf-implement-feature/{slug}/impl-status.json` (backward compat) | Work data loaded |
| 1.7 | Nếu tồn tại: đọc `.mc-data/docs/_meta/verify-sync.md` (output của /wf-verify-sync) → extract sync rate | Sync rate loaded |
| 1.8 | **Scan fix-status (wf-fix-bugs session-based):** đọc tất cả `.mc-data/work/wf-fix-bugs/sessions/*/fix-status.json` (canonical path). Nếu có root `.mc-data/work/wf-fix-bugs/fix-status.json` (legacy v6 trở về trước) → đọc thêm cho backward compat | Fix status loaded |
| 1.9 | Nếu tồn tại: đọc `.mc-data/work/wf-preflight/preflight-report.md` → extract preflight score | Preflight score loaded |
| 1.10 | Consolidate: registry + roadmap + work/ + sync/ + fix/ + preflight/ → unified status | Status consolidated |

**POST-GATE:** `test -n "$PROJECT_DATA"`

### Graceful Degradation

| Scenario | Data Available | Output |
|----------|---------------|--------|
| **Full setup** | registry + roadmap + work/ + sync/ | Complete dashboard (Overview + Systems + Sprints + Current Work + Sync Coverage) |
| **No roadmap** | registry only | Limited dashboard (Overview metrics + feature list) |
| **No sync data** | registry + roadmap | Dashboard không có "Implementation Coverage" section |
| **No registry** | none | ERROR E002: Run `/wf-analyze-requirements` first |

---

## Phase 2L: Legacy Pipeline Dashboard (Conditional)

> Hiển thị khi LEGACY_MODE = true (ledger.json tồn tại, pipeline chưa COMPLETE).

**PRE-GATE:** `LEGACY_MODE == true`

| Step | Action | Verify |
|------|--------|--------|
| 2L.1 | Đọc `ledger.json` → extract stage progress | Data loaded |
| 2L.2 | Hiển thị Legacy Pipeline Dashboard | Output |

**Output Legacy Dashboard:**

```
## Legacy Scan Pipeline

| Stage | Status | Progress |
|-------|--------|----------|
| 0. Detection | done/in_progress/pending | — |
| 1. Inventory | done/in_progress/pending | [total_items] items |
| 2. Classify | done/in_progress/pending | [completed_batches]/[total_batches] batches |
| 3. Extract | done/in_progress/pending | [modules_completed]/[modules_total] modules |
| 4. Normalize | done/in_progress/pending | [sub_phases status] |
| 5. Gap Analysis | done/in_progress/pending | — |

Sessions used: [count]
Next: /wf-legacy-scan --resume
```

**Icon mapping:** done=done_icon, in_progress=in_progress_icon, pending=pending_icon

**POST-GATE:** Legacy Pipeline Dashboard hiển thị thành công.

---

## Phase 2: Hiển thị Dashboard

> Format và hiển thị progress dashboard theo arguments.

**PRE-GATE:** `test -n "$PROJECT_DATA"`

### Output mặc định (no flags)

```
# Project Status: [Project Name]

## Overview
| Metric | Value | Progress |
|--------|-------|----------|
| **Total Features** | X | 100% |
| Done | X | X% |
| In Progress | X | X% |
| Not Started | X | X% |
| Paused | X | X% |
| Blocked | X | X% |

## Systems Progress
| System | Features | Done | Progress |
|--------|----------|------|----------|
| [SYS-1] | X | X | X% |

## Sprint Status
| Sprint | Focus | Features | Progress |
|--------|-------|----------|----------|
| S01 | Foundation | X | X% |

## Current Work
| Feature | System | Status | Current Task |
|---------|--------|--------|--------------|
| [FEAT-XXX] | [SYS] | in_progress | [Task ID] |
| [FEAT-YYY] | [SYS] | paused | [Checkpoint info] |

## Implementation Coverage (nếu /wf-verify-sync đã chạy)
| Metric | Value |
|--------|-------|
| Sync Rate | X% |
| Readiness | >=80% / 60-79% / <60% |

## Recommended Next Action
[Logic tự động chọn 1 action phù hợp nhất dựa trên trạng thái dự án]

---
Quick commands:
- Resume: /wf-implement-feature [feature] --resume
- Start: /wf-implement-feature [REQ-ID]
- Fix bugs: /wf-fix-bugs
- Health check: /wf-preflight
- Verify: /wf-verify-sync
```

### Output `--sprint=S0X`

```
# Sprint [S0X]: [Sprint Name]

| Metric | Value |
|--------|-------|
| Features | X |
| Done | X (X%) |
| In Progress | X |
| Not Started | X |

## Features trong Sprint
| # | Feature | REQ-ID | Status | Tasks Done |
|---|---------|--------|--------|------------|
| 1 | [name] | REQ-XXX-001 | done | 5/5 |
| 2 | [name] | REQ-XXX-002 | in_progress | 2/4 |
```

### Output `--system=XXX`

```
# System: [System Name]

| Module | Features | Done | Progress |
|--------|----------|------|----------|
| [MOD-1] | X | X | X% |

## All Features
| Feature | Module | REQ-ID | Status |
|---------|--------|--------|--------|
| [name] | [mod] | REQ-XXX-001 | done |
```

### Output `--detailed`

```
# Project Status (Detailed): [Project Name]

## Overview
| Metric | Value | Progress |
|--------|-------|----------|
| **Total Features** | X | 100% |
| Done | X | X% |
| In Progress | X | X% |
| Not Started | X | X% |

## [System Name]

### [Module Name]

#### FEAT-XXX-001: [Feature Name]
| Field | Value |
|-------|-------|
| REQ-ID | REQ-XXX-001 |
| Status | done |
| Sprint | S01 |
| Tasks | 5/5 |

**Tasks:**
| # | Task | Status |
|---|------|--------|
| 1 | [task description] | done |
| 2 | [task description] | done |

#### FEAT-XXX-002: [Feature Name]
| Field | Value |
|-------|-------|
| REQ-ID | REQ-XXX-002 |
| Status | in_progress |
| Sprint | S01 |
| Tasks | 2/4 |

**Tasks:**
| # | Task | Status |
|---|------|--------|
| 1 | [task description] | done |
| 2 | [task description] | in_progress |
| 3 | [task description] | not_started |
```

**POST-GATE:** Dashboard hiển thị thành công, metrics tính toán đúng (tổng = sum các status), không có placeholder. Skill không tạo file — output dashboard text trực tiếp.

---

## Recommended Next Action Logic

> Tự động phân tích trạng thái dự án và đề xuất hành động phù hợp nhất cho user.
> Hiển thị trong MỌI dashboard output (default, sprint, system, detailed).

### Detection Rules (ưu tiên từ trên xuống — chọn rule đầu tiên match)

| # | Điều kiện | Action | Command |
|---|-----------|--------|---------|
| 0 | Ledger tồn tại VÀ `pipeline_status != "COMPLETE"` | Tiếp tục legacy scan pipeline | `/wf-legacy-scan --resume` |
| 1 | Có features với `impl_status=blocked` | Sửa lỗi blocking features | `/wf-fix-bugs` |
| 2 | `fix-status.json` tồn tại VÀ `status=paused` | Tiếp tục fix bugs | `/wf-fix-bugs --resume` |
| 3 | `preflight-report.md` tồn tại VÀ score < 70% | Chạy fix bugs để cải thiện | `/wf-fix-bugs` |
| 4 | Có features với `impl_status=paused` | Tiếp tục implement feature | `/wf-implement-feature [feature] --resume` |
| 5 | Có features với `impl_status=in_progress` | Feature đang triển khai — tiếp tục | `/wf-implement-feature [feature] --resume` |
| 6 | Có features với `impl_status=not_started` VÀ roadmap tồn tại | Bắt đầu implement feature tiếp theo | `/wf-implement-feature [next-feature]` |
| 7 | Tất cả features `done` VÀ chưa có verify-sync | Kiểm tra đồng bộ trước release | `/wf-verify-sync` |
| 8 | Tất cả features `done` VÀ sync rate >= 80% | Chuẩn bị triển khai | `/wf-prepare-deployment` |
| 9 | Tất cả features `done` VÀ sync rate < 80% | Fix lỗi đồng bộ | `/wf-fix-bugs` |
| 10 | Không có roadmap | Lập kế hoạch triển khai | `/wf-plan-modules` |
| 11 | Default (không match rule nào) | Kiểm tra sức khỏe dự án | `/wf-preflight` |

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|------------|-------|
| E001 | Roadmap không tìm thấy | Hiển thị limited dashboard (chỉ từ registry) |
| E002 | Registry không tìm thấy | STOP → Hiển thị: "Run `/wf-analyze-requirements` first" |
| E003 | Parse error (JSON invalid) | Hiển thị warning, show partial data |
| E004 | Không có features trong registry | Hiển thị: "No features found. Run `/wf-analyze-requirements` first" |
| E005 | `legacy_scan_incomplete` — LEGACY_MODE detected nhưng project-context.md không đủ dữ liệu (< 500 bytes) | Hiển thị partial status với cảnh báo: "Legacy context không đủ — chạy /wf-legacy-scan để cập nhật" |
| E006 | Sprint ID không hợp lệ | Hiển thị: "Sprint S0X not found. Available: S01, S02..." |
| E007 | System ID không hợp lệ | Hiển thị: "System XXX not found. Available: CRM, AUTH..." |
| E008 | POST-GATE fail sau 3 retries | Hiển thị partial dashboard + warning cho user |

---

## References

| File | Purpose |
|------|---------|
| `.mc-data/docs/_meta/req-registry.json` | SSOT — features, systems, modules, impl_status |
| `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | Sprint plan + implementation order |
| `.mc-data/docs/phase5-implementation/sprints/S0X-*.md` | Chi tiết từng sprint |
| `.mc-data/work/wf-implement-feature/{feature-slug}/current.txt` | v4.0+ pointer trỏ tới active session (relative path) |
| `.mc-data/work/wf-implement-feature/{feature-slug}/sessions/{session-id}/impl-status.json` | v4.0+ session-isolated per-feature implementation progress (resolve qua `current.txt`) |
| `.mc-data/work/wf-implement-feature/{feature-slug}/impl-status.json` | v3.x flat layout fallback (backward compat — auto-migrated) |
| `.mc-data/work/legacy-scan/project-context.md` | LEGACY_MODE detection sentinel (size > 500 bytes) |
| `.mc-data/work/legacy-scan/ledger.json` | Legacy pipeline orchestrator state (đọc `pipeline_status` cho Phase 2L) |
| `.mc-data/docs/_meta/verify-sync.md` | Sync rate + gaps report |
| `.mc-data/work/wf-fix-bugs/sessions/{session-id}/fix-status.json` | Bug fix session status (per-scope, multi-session, canonical) |
| `.mc-data/work/wf-preflight/preflight-report.md` | Preflight health check report |

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-plan-modules` | Tạo implementation roadmap (input chính) |
| `/wf-implement-feature` | Cập nhật impl_status khi hoàn thành |
| `/wf-verify-sync` | Tạo sync coverage data |
| `/wf-fix-bugs` | Fix bugs — recommended khi có blocked features hoặc preflight score thấp |
| `/wf-preflight` | Health check — recommended khi cần kiểm tra sức khỏe dự án |
| `/wf-prepare-deployment` | Cần sync rate >= 80% từ dashboard |
