# 04 — Contracts & Data Model

> **Đọc trước:** [03-architecture.md](03-architecture.md)
> **Đọc tiếp:** [05-execution-profiles.md](05-execution-profiles.md)

Tài liệu này định nghĩa tất cả **schema**, **contract** và **path** mà pipeline dimension-based (v6) đọc/ghi. Mọi implementer phải tôn trọng những contract này. Mọi thay đổi schema đều phải bump `schema_version` và cập nhật `.claude/rules/00-core.md §4b`.

---

## 0. Quy Ước Chung

| Khái niệm | Quy ước |
|-----------|---------|
| Encoding | UTF-8, LF (không CRLF) |
| JSON style | 2-space indent, trailing newline, UTF-8 không BOM |
| Markdown | CommonMark; dùng headings có rỗng dòng sau (xem `00-core.md §5`) |
| Path convention | Tất cả path relative to project root (bắt đầu `.mc-data/`) |
| SESSION_DIR | Biến môi trường resolve theo [§6](#6-session_dir-layout-v6) — giống v5 |
| ID generation | Lowercase-kebab-case, không có space/diacritics |
| Timestamp | ISO 8601 UTC, ví dụ `2026-04-20T08:00:00Z` |
| Schema version | Semantic — major bump khi breaking; minor khi thêm optional field |

---

## 1. Signal — Đơn vị phát hiện

**Định nghĩa:** Một `Signal` là dấu hiệu bất thường được emit bởi **đúng một probe** trong **đúng một lane**. Signal chưa được dedup. Signal là pre-Issue.

### 1.1 Path

```
$SESSION_DIR/lanes/<dim>/signals.json          # canonical: array Signal đã normalize
$SESSION_DIR/lanes/<dim>/raw/<probe_id>.json   # raw output per probe (optional)
```

`signals.json` là **append-only trong lane**. Signal Bus chỉ đọc, không ghi.

### 1.2 Schema

```json
{
  "$schema": "signal-v1",
  "signal_id": "SIG-20260420-QD3-0001",
  "dimension": "QD3",
  "probe_id": "P3.02",
  "probe_source": {
    "type": "static|runtime|llm|external",
    "tool": "regex|playwright|semgrep|lighthouse|agent:security-engineer|...",
    "version": "semgrep@1.45.0"
  },
  "location": {
    "kind": "code|route|db_table|ui_page|config_file|artifact",
    "path": "apps/backend/src/admin/reset-password.ts",
    "range": { "start_line": 42, "end_line": 58 },
    "symbol": "resetPassword",
    "url": "https://app.local/admin/reset-password",
    "selector": "button[name='reset']"
  },
  "symptom_summary": "Route /admin/reset-password không kiểm tra role ADMIN trước khi reset",
  "evidence": {
    "code_ref": "apps/backend/src/admin/reset-password.ts:42-58",
    "http_trace": "$SESSION_DIR/lanes/QD3/raw/P3.02-trace.har",
    "screenshot": "$SESSION_DIR/evidence/reset-no-auth.png",
    "log": "lack of authGuard in router chain"
  },
  "severity_hint": "HIGH",
  "confidence": 0.85,
  "tags": ["auth", "privilege-escalation"],
  "req_ids": ["REQ-SEC-014"],
  "feat_ids": ["FEAT-AUTH-ADMIN-002"],
  "detected_at": "2026-04-20T08:01:23Z",
  "lane_run_id": "QD3-run-001"
}
```

### 1.3 Ràng buộc

- `signal_id` = `SIG-<YYYYMMDD>-<dim>-<4-digit-seq>` — unique trong session.
- `dimension` ∈ {`QD1`, `QD2`, `QD3`, `QD4`, `QD5`, `QD6`, `QD7`}.
- `probe_id` phải khớp `probes[].id` trong `dimension.json` của lane tương ứng.
- `confidence` ∈ [0.0, 1.0]:
  - `≥0.9` — static code match chắc chắn / runtime reproducible.
  - `0.7 — 0.89` — LLM review + code_ref khớp.
  - `<0.7` — heuristic / external tool low-quality rule.
- Tối thiểu 1 field trong `evidence.*` phải có giá trị (không empty).
- `severity_hint` là gợi ý của lane; **Signal Bus có quyền override** khi aggregate (xem [02 §Severity Aggregation](02-quality-dimensions.md)).

---

## 2. Issue — Đơn vị fix

**Định nghĩa:** Một `Issue` = một hoặc nhiều Signal đã dedup cùng root cause, đã được Triage gán `severity` + `fixability`. Issue là đơn vị tham chiếu xuyên Triage → Planner → Fixer → Verifier.

### 2.1 Path

```
$SESSION_DIR/issue-registry.json       # canonical Issue registry
```

Chủ sở hữu ghi:
- **Signal Bus** → ghi mới (create) + `dedup_sources`.
- **Triage** → enrich `severity`, `fixability`, `fix_strategy`, `batch_group`.
- **Fixer** → enrich `fix_attempts[]`, `fix_status`.
- **Verifier** → enrich `verify_status`, `verify_evidence`, `regression_signals[]`.

### 2.2 Schema (extended — backward-compat)

```json
{
  "$schema": "issue-v2",
  "issue_id": "ISSUE-0042",
  "title": "Route /admin/reset-password thiếu kiểm tra quyền ADMIN",
  "dimension": ["QD3", "QD1"],
  "primary_dimension": "QD3",
  "probe_sources": [
    { "signal_id": "SIG-20260420-QD3-0001", "probe_id": "P3.02", "confidence": 0.85 },
    { "signal_id": "SIG-20260420-QD1-0013", "probe_id": "P1.02", "confidence": 0.70 }
  ],
  "location": {
    "kind": "code",
    "path": "apps/backend/src/admin/reset-password.ts",
    "range": { "start_line": 42, "end_line": 58 },
    "symbol": "resetPassword"
  },
  "evidence": {
    "primary": "apps/backend/src/admin/reset-password.ts:42-58",
    "artifacts": [
      "$SESSION_DIR/evidence/reset-no-auth.png",
      "$SESSION_DIR/lanes/QD3/raw/P3.02-trace.har"
    ]
  },
  "symptom_summary": "Endpoint reset password không check role ADMIN → privilege escalation",
  "impact_summary": "Mọi user đăng nhập có thể reset password của tài khoản khác",
  "req_ids": ["REQ-SEC-014"],
  "feat_ids": ["FEAT-AUTH-ADMIN-002"],
  "severity": "HIGH",
  "severity_source": "aggregated_max",
  "confidence": 0.85,
  "fixability": "AGENT_FIX",
  "fix_strategy": {
    "approach": "add-authz-guard",
    "agent": "security-engineer",
    "template": null,
    "cdg_required": false
  },
  "batch_group": "auth-hardening-batch-1",
  "fix_attempts": [
    {
      "attempt": 1,
      "at": "2026-04-20T09:12:00Z",
      "by": "security-engineer",
      "patches": ["apps/backend/src/admin/reset-password.ts"],
      "result": "applied"
    }
  ],
  "fix_status": "applied",
  "verify_status": "passed",
  "verify_evidence": {
    "probe_re_run": { "probe_id": "P3.02", "result": "clean" },
    "regression_check": { "probes": ["P3.01", "P3.05"], "result": "clean" },
    "after_screenshot": "$SESSION_DIR/evidence/reset-with-auth.png"
  },
  "regression_signals": [],
  "tags": ["auth", "critical-path"],
  "first_seen_at": "2026-04-20T08:01:23Z",
  "last_updated_at": "2026-04-20T09:14:10Z"
}
```

### 2.3 Backward-compat với `issue-v1` (v5.x)

Các trường v1 được **giữ nguyên semantics**:

| v1 field | v2 mapping | Ghi chú |
|----------|------------|---------|
| `issue_id` | `issue_id` | Giữ |
| `title`, `symptom_summary`, `impact_summary` | Giữ | — |
| `location`, `evidence` | `location`, `evidence.primary` + `artifacts` | v2 chuẩn hoá — v1 được migrate auto |
| `severity` | Giữ | Nhưng `severity_source` là mới |
| `fixability` | Giữ | Thêm giá trị `ESCALATE_SECURITY`, `ESCALATE_SCHEMA` (xem [§2.5](#25-enum-fixability)) |
| `category` (v1) | `primary_dimension` + `dimension[]` | Migration map: 12 category → 7 dimension (xem [02 §Mapping](02-quality-dimensions.md)) |
| `fix_status`, `verify_status` | Giữ | — |

**Migration helper:** `_shared/signal_bus/migrate-v1-to-v2.md` sẽ định nghĩa script chuyển đổi (viết sau trong phase implement).

### 2.4 Enum `severity`

| Value | Ngữ nghĩa |
|-------|-----------|
| `CRITICAL` | Chặn vận hành / lộ dữ liệu / lỗi tài chính. Fix ngay trước release. |
| `HIGH` | Ảnh hưởng tính năng chính hoặc security. Fix trước release. |
| `MEDIUM` | Cải thiện quality; có thể defer 1 release. |
| `LOW` | Code smell / minor UX. Backlog. |
| `INFO` | Ghi nhận, không fix. |

### 2.5 Enum `fixability`

| Value | Ý nghĩa | Ai thực thi |
|-------|---------|-------------|
| `AUTO_FIX` | Pattern deterministic, có template | Fixer theo template |
| `AGENT_FIX` | Cần reasoning domain | Domain agent (security-engineer, ux-designer, ...) |
| `ESCALATE` | Vượt quyền tự động | User / manual |
| `ESCALATE_SECURITY` | CDG — secrets, auth bypass hard | User confirm bắt buộc (CORE-027) |
| `ESCALATE_SCHEMA` | Thay đổi schema DB | Phải qua migration flow riêng |

### 2.6 Enum `fix_status` / `verify_status`

```
fix_status   ∈ { "pending", "applied", "failed", "skipped", "escalated" }
verify_status ∈ { "pending", "passed", "failed", "skipped", "escalated" }
```

Transition matrix:

```
pending → applied → (verify) → passed | failed (retry) | escalated
pending → failed (apply error) → escalated
pending → skipped (user skip or dry-run)
```

---

## 3. Dimension Manifest — `dimension.json`

Mỗi lane (`wf-fix-<dim>`) phải có file manifest tại root skill folder.

### 3.1 Path

```
.claude/skills/workflow/wf-fix-<dim>/dimension.json
```

### 3.2 Schema

```json
{
  "$schema": "dimension-v1",
  "dimension_id": "QD3",
  "name": "Security & Compliance",
  "short_name": "Security",
  "owner_agent": "security-engineer",
  "version": "1.0.0",
  "description": "Phát hiện vấn đề bảo mật, quyền, secrets, và compliance.",
  "probes": [
    {
      "id": "P3.01",
      "name": "Hard-coded secrets scan",
      "type": "static",
      "depth": ["quick", "standard", "deep", "exhaustive"],
      "tool": { "kind": "regex", "config": "probes/P3.01-secrets.md" },
      "required_inputs": ["code"],
      "outputs": ["signal"],
      "severity_default": "HIGH",
      "cdg": false,
      "estimated_cost": { "time_seconds": 30, "tokens": 2000 }
    },
    {
      "id": "P3.02",
      "name": "Missing authorization check",
      "type": "static",
      "depth": ["standard", "deep", "exhaustive"],
      "tool": { "kind": "agent", "agent": "security-engineer" },
      "required_inputs": ["code", "req-registry"],
      "outputs": ["signal"],
      "severity_default": "HIGH",
      "cdg": false,
      "estimated_cost": { "time_seconds": 120, "tokens": 12000 }
    }
  ],
  "exit_criteria": {
    "quick":       { "probes_required": ["P3.01"],                         "max_signals_per_probe": 50 },
    "standard":    { "probes_required": ["P3.01", "P3.02", "P3.05"],       "max_signals_per_probe": 100 },
    "deep":        { "probes_required": ["P3.01", "P3.02", "P3.05", "P3.06", "P3.08"], "max_signals_per_probe": 200 },
    "exhaustive":  { "probes_required": "ALL",                              "max_signals_per_probe": 500 }
  },
  "severity_rules": {
    "critical_probes": ["P3.01", "P3.06"],
    "max_aggregation": true
  },
  "dependencies": {
    "optional_tools": ["semgrep", "trufflehog"],
    "agents": ["security-engineer", "devops-engineer"]
  },
  "outputs": {
    "signals_file": "$SESSION_DIR/lanes/QD3/signals.json",
    "lane_report":  "$SESSION_DIR/lanes/QD3/lane-report.md",
    "phase_summary": "$SESSION_DIR/lanes/QD3/phase-summary.md"
  }
}
```

### 3.3 Ràng buộc

- `probes[].id` unique trong lane; format `P<dim_number>.<NN>`.
- `probes[].depth[]` khớp với [05 §Profile](05-execution-profiles.md).
- `exit_criteria` phải define đủ 4 profile — `quick`, `standard`, `deep`, `exhaustive`.
- `cdg: true` kích hoạt CORE-027 flow trước khi probe chạy.

---

## 4. Profile Config — `profiles.json`

### 4.1 Path

```
.claude/skills/workflow/wf-fix-bugs/config/profiles.json
```

### 4.2 Schema

```json
{
  "$schema": "profiles-v1",
  "profiles": {
    "quick": {
      "description": "Nhanh, smoke-level, trước commit.",
      "default_dimensions": ["QD1", "QD3"],
      "max_parallel_lanes": 2,
      "time_budget_minutes": 5,
      "depth": "quick"
    },
    "standard": {
      "description": "Cân bằng, trước PR.",
      "default_dimensions": ["QD1", "QD3", "QD5"],
      "max_parallel_lanes": 3,
      "time_budget_minutes": 15,
      "depth": "standard"
    },
    "deep": {
      "description": "Đầy đủ, trước release candidate.",
      "default_dimensions": ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6"],
      "max_parallel_lanes": 3,
      "time_budget_minutes": 45,
      "depth": "deep"
    },
    "exhaustive": {
      "description": "Pre-GA / audit, chạy tất cả probe.",
      "default_dimensions": ["QD1", "QD2", "QD3", "QD4", "QD5", "QD6", "QD7"],
      "max_parallel_lanes": 3,
      "time_budget_minutes": 120,
      "depth": "exhaustive"
    }
  },
  "flag_mapping": {
    "__default__": "standard",
    "--deep": { "profile": "deep" },
    "--full-test": { "profile": "exhaustive" },
    "--responsive": { "profile_override": { "dimensions_add": ["QD5"], "probe_tags": ["responsive"] } },
    "--no-browser": { "disable_probes_tagged": ["runtime-browser"] },
    "--browser-only": { "enable_only_probes_tagged": ["runtime-browser"] }
  }
}
```

### 4.3 Ràng buộc

- `default_dimensions` ⊆ `{QD1..QD7}`.
- `max_parallel_lanes` ≤ 3 mặc định (xem [03 §4.2](03-architecture.md)).
- `flag_mapping` là source duy nhất để orchestrator map CLI flag → profile/selection.

---

## 5. Dimension Registry — `dimensions.json`

### 5.1 Path

```
.claude/skills/workflow/wf-fix-bugs/config/dimensions.json
```

### 5.2 Schema

```json
{
  "$schema": "dimensions-v1",
  "registered": [
    {
      "dimension_id": "QD1",
      "slug": "functional",
      "skill_name": "wf-fix-functional",
      "manifest_path": ".claude/skills/workflow/wf-fix-functional/dimension.json",
      "enabled": true,
      "plugin": false
    },
    {
      "dimension_id": "QD3",
      "slug": "security",
      "skill_name": "wf-fix-security",
      "manifest_path": ".claude/skills/workflow/wf-fix-security/dimension.json",
      "enabled": true,
      "plugin": false
    }
  ]
}
```

Orchestrator scan file này khi khởi động. Lane có `enabled: false` bị bỏ qua hoàn toàn.

---

## 6. SESSION_DIR Layout v6

### 6.1 Resolve rule (giữ nguyên v5)

```
scope=all:
  SESSION_DIR=.mc-data/work/wf-fix-bugs/run-<NNN>--<YYYYMMDD>/

scope=system:
  SESSION_DIR=.mc-data/work/wf-fix-bugs/sessions/<sys-id>/run-<NNN>--<YYYYMMDD>/

scope=module:
  SESSION_DIR=.mc-data/work/wf-fix-bugs/sessions/<sys-id>/<mod-id>/run-<NNN>--<YYYYMMDD>/
```

> CORE-030 session isolation: không ghi đè run cũ. Resume dùng `--resume` + latest `run-NNN` hoặc explicit `--run=NNN`.

### 6.2 Folder tree chuẩn

```
$SESSION_DIR/
├── fix-status.json                # ★ Orchestrator state (xem §7)
├── checkpoint.json                # Orchestrator resume hint
├── issue-registry.json            # ★ Unified Issue registry (xem §2)
├── signal-bus-checkpoint.json     # Signal Bus resume hint
├── bug-triage.md                  # User-facing triage doc
├── fix-plan.md                    # User-facing fix plan
├── fix-batches.json               # Planner output (xem §8)
├── fix-log.json                   # Fixer + Verifier append log (xem §9)
├── fix-report.md                  # Post-fix summary
├── coverage-report.md             # Coverage by dimension (xem §10)
├── phase-summary.md               # CORE-028 ≤15 dòng tiếng Việt
├── orchestrator-summary.md        # Observability, chi tiết hơn phase-summary
├── escalations.md                 # Issue không fix được
│
├── lanes/
│   ├── QD1/
│   │   ├── signals.json
│   │   ├── lane-report.md
│   │   ├── phase-summary.md
│   │   ├── checkpoint.json
│   │   └── raw/
│   │       ├── P1.01-req-coverage.json
│   │       └── ...
│   ├── QD3/
│   │   └── ... (cùng cấu trúc)
│   └── QD<n>/...
│
└── evidence/
    ├── <signal_id>-*.png           # Screenshots
    ├── <signal_id>-*.har           # HTTP traces
    └── <signal_id>-*.log           # Runtime logs
```

### 6.3 Quy tắc write scope (CORE-025)

| Writer | Được phép write | Không được phép |
|--------|-----------------|-----------------|
| Orchestrator | `fix-status.json`, `checkpoint.json`, `orchestrator-summary.md`, `coverage-report.md`, `phase-summary.md` | Không ghi trực tiếp `lanes/**` hoặc `issue-registry.json` |
| Lane `wf-fix-<dim>` | `lanes/<dim>/**`, `evidence/<signal_id>-*` | Không ghi cross-lane hoặc root files |
| Signal Bus | `issue-registry.json`, `signal-bus-checkpoint.json` | Không ghi `lanes/**` |
| Triage | `issue-registry.json` (enrich), `bug-triage.md`, `fix-plan.md`, `fix-log.json` (init) | Không ghi `lanes/**`, không ghi code |
| Planner | `fix-batches.json` | — |
| Fixer | Code patches trong repo, `fix-log.json` (APPEND), `issue-registry.json` (enrich `fix_*`) | Không ghi `lanes/**`, không ghi `verify_*` |
| Verifier | `issue-registry.json` (enrich `verify_*`), `fix-log.json` (APPEND), `evidence/<signal_id>-after-*` | Không ghi code |

---

## 7. `fix-status.json` — Orchestrator State

### 7.1 Schema

```json
{
  "$schema": "fix-status-v6",
  "run_id": "run-017--20260420",
  "session_dir": ".mc-data/work/wf-fix-bugs/run-017--20260420",
  "scope": { "kind": "all", "sys_id": null, "mod_id": null },
  "profile": "standard",
  "dimensions_selected": ["QD1", "QD3", "QD5"],
  "max_parallel_lanes": 3,
  "flags": {
    "dry_run": false,
    "resume": false,
    "no_browser": false,
    "browser_only": false,
    "responsive": false
  },
  "active_phase": "fixer",
  "phases": {
    "parsing":       { "status": "done",        "started_at": "...", "ended_at": "..." },
    "pre_gate":      { "status": "done",        "started_at": "...", "ended_at": "..." },
    "init_session":  { "status": "done",        "started_at": "...", "ended_at": "..." },
    "lanes_running": {
      "status": "done",
      "lanes": {
        "QD1": { "status": "done",   "signals_count": 42, "started_at": "...", "ended_at": "..." },
        "QD3": { "status": "done",   "signals_count": 11, "started_at": "...", "ended_at": "..." },
        "QD5": { "status": "partial", "signals_count": 5,  "error": "probe P5.03 timeout" }
      }
    },
    "signal_bus":    { "status": "done",        "issues_count": 38 },
    "triage":        { "status": "done",        "cdg_pending": 0 },
    "planner":       { "status": "done",        "batches_count": 6 },
    "fixer":         { "status": "in_progress", "batches_done": 3, "batches_total": 6 },
    "verifier":      { "status": "pending" },
    "coverage":      { "status": "pending" },
    "post_gate":     { "status": "pending" }
  },
  "started_at": "2026-04-20T08:00:00Z",
  "last_checkpoint_at": "2026-04-20T09:20:10Z"
}
```

### 7.2 Resume routing

`active_phase` xác định entry point khi resume:

```
parsing | pre_gate | init_session → restart từ đầu
lanes_running                     → orchestrator re-spawn lanes có status != "done"
signal_bus                        → re-ingest signals.json còn thiếu
triage | planner | fixer          → resume từ phase đó
verifier                          → resume phase verifier, skip fixer
coverage | post_gate              → chạy tiếp
```

---

## 8. `fix-batches.json` — Planner Output

### 8.1 Schema

```json
{
  "$schema": "fix-batches-v1",
  "generated_at": "2026-04-20T09:00:00Z",
  "total_issues": 38,
  "batches": [
    {
      "batch_id": "B01",
      "name": "auth-hardening",
      "primary_dimension": "QD3",
      "issues": ["ISSUE-0042", "ISSUE-0043", "ISSUE-0051"],
      "dependencies": [],
      "parallel_safe": false,
      "estimated_duration_minutes": 8,
      "fix_strategy_hint": "AGENT_FIX"
    },
    {
      "batch_id": "B02",
      "name": "ui-labels-a11y",
      "primary_dimension": "QD5",
      "issues": ["ISSUE-0054", "ISSUE-0055"],
      "dependencies": [],
      "parallel_safe": true,
      "estimated_duration_minutes": 4,
      "fix_strategy_hint": "AUTO_FIX"
    }
  ]
}
```

### 8.2 Ràng buộc

- `batches` đã sort: severity desc → dependency → dimension grouping.
- `dependencies` là mảng `batch_id` phải done trước khi batch này chạy.
- Fixer chạy tuần tự mặc định (`parallel_safe: false`). Chỉ cho song song khi cả batch có `parallel_safe: true` VÀ không chạm cùng file.

---

## 9. `fix-log.json` — Audit Trail

### 9.1 Schema (append-only)

```json
{
  "$schema": "fix-log-v1",
  "run_id": "run-017--20260420",
  "entries": [
    {
      "seq": 1,
      "at": "2026-04-20T09:12:00Z",
      "actor": "fixer",
      "action": "apply_patch",
      "issue_id": "ISSUE-0042",
      "batch_id": "B01",
      "patches": ["apps/backend/src/admin/reset-password.ts"],
      "result": "applied",
      "notes": "Added authGuard middleware"
    },
    {
      "seq": 2,
      "at": "2026-04-20T09:13:45Z",
      "actor": "verifier",
      "action": "re_run_probe",
      "issue_id": "ISSUE-0042",
      "probe_id": "P3.02",
      "result": "passed",
      "evidence": "$SESSION_DIR/evidence/reset-with-auth.png"
    },
    {
      "seq": 3,
      "at": "2026-04-20T09:14:00Z",
      "actor": "verifier",
      "action": "regression_check",
      "issue_id": "ISSUE-0042",
      "probes": ["P3.01", "P3.05"],
      "result": "passed"
    }
  ]
}
```

### 9.2 Ràng buộc

- Append-only — không rewrite entries cũ.
- `seq` monotonic.
- `actor` ∈ {`orchestrator`, `lane`, `signal_bus`, `triage`, `planner`, `fixer`, `verifier`, `user`}.
- Mỗi `apply_patch` phải có `patches[]` (file paths) — để rollback khi cần.

---

## 10. `coverage-report.md` — Template

### 10.1 Cấu trúc

```markdown
# Coverage Report — run-<NNN>--<YYYYMMDD>

## Tóm tắt

- Profile: <quick|standard|deep|exhaustive>
- Dimensions selected: QD1, QD2, QD5   ← ★ default v1.0 — logic + nghiệp vụ + UI
- Total issues: 38 (CRITICAL: 2, HIGH: 7, MEDIUM: 18, LOW: 11)
- Fix applied: 31 | Escalated: 5 | Skipped (dry-run): 2

## Coverage theo dimension

| Dim | Tên | Probes chạy | Probes required | Trạng thái | Issues phát hiện | Ghi chú |
|-----|-----|-------------|-----------------|-----------|------------------|---------|
| QD1 | Functional | 5/7 | 5/5 | ✅ đủ exit | 12 | — |
| QD2 | Business   | 4/5 | 3/3 | ✅ đủ exit | 11 | Domain expert agent review |
| QD5 | UX/A11y    | 4/6 | 3/3 | ⚠️ partial | 15 | P5.03 Lighthouse timeout |

## Probe skipped

- P3.05 (Semgrep) — tool không có trong PATH.
- P5.03 (Lighthouse) — timeout > 120s, bỏ qua ở run này.

## Tool availability

| Tool | Available | Version | Dùng trong probe |
|------|-----------|---------|-------------------|
| Playwright | ✅ | 1.41.0 | P5.01, P5.04 |
| Semgrep | ❌ | — | P3.05 (skipped) |
| Lighthouse | ⚠️ timeout | 11.3.0 | P5.03 |

## Khuyến nghị cho run tiếp theo

- Cài Semgrep để tăng coverage QD3 từ 75% → 100%.
- Tăng Lighthouse timeout hoặc bỏ `--responsive` nếu không cần.
```

### 10.2 Ràng buộc

- Luôn viết tiếng Việt (CORE-005).
- Số liệu lấy trực tiếp từ `fix-status.json` + lane manifests + `issue-registry.json`.
- Không copy số cứng — mọi số phải trace được.

---

## 11. `phase-summary.md` — CORE-028

### 11.1 Template

```markdown
# Phase Summary — wf-fix-bugs run-<NNN>--<YYYYMMDD>

- Chế độ: <profile> (<dimensions>)
- Số bug phát hiện: <N> (Critical <a> / High <b> / Medium <c> / Low <d>)
- Đã fix: <X>, Chờ xác nhận: <Y>, Cần escalate: <Z>
- Thời gian chạy: <mm> phút
- Tool ngoài: <list hoặc "đầy đủ">
- Điểm nổi bật: <1-2 câu>
- Cần người quyết định: <có/không — lý do>
- File quan trọng cần xem: <coverage-report.md, escalations.md, ...>
- Lời khuyên cho lần chạy tiếp theo: <1 câu>
```

### 11.2 Ràng buộc

- ≤15 dòng (CORE-028).
- Tiếng Việt, từ ngữ dành cho người không chuyên.
- Không copy raw JSON — chỉ số và câu chốt.

---

## 12. AggregationStats v2 — Dimension Coverage Metrics

### 12.1 Schema (Signal Bus aggregation output)

```json
{
  "AggregationStats": {
    "total_signals": "int — tổng signals trước dedup",
    "total_issues": "int — issues sau dedup",
    "by_dimension": "dict[str, int] — issues per dimension",
    "errors": "list[str] — aggregation errors",
    "dimensions_run": "list[str] — (v2) dimensions đã chạy",
    "dimensions_with_issues": "list[str] — (v2) dimensions có issues",
    "dimensions_without_issues": "list[str] — (v2) dimensions không có issues",
    "coverage_rate_pct": "float — (v2) % dimensions có issues",
    "dedup_ingested": "int — (v2) signals ingested vào bus",
    "dedup_deduplicated": "int — (v2) signals removed by dedup"
  }
}
```

### 12.2 Ràng buộc

- `coverage_rate_pct = len(dimensions_with_issues) / len(dimensions_run) * 100`
- `by_dimension` keys phải khớp `dimensions_run` entries
- Dùng cho `coverage-report.md` generation (xem [§10](#10-coverage-reportmd--template))

---

## 13. WorkloadPlan — Partition Planner Output

### 13.1 Schema

```json
{
  "WorkloadPlan": {
    "id": "str — workload ID (W01, W02, ...)",
    "dimensions": "list[str] — dimension IDs trong workload",
    "estimated_probes": "int — tổng probes estimate",
    "estimated_minutes": "float — thời gian estimate (minutes)"
  }
}
```

### 13.2 Ràng buộc

- `dimensions` ⊆ `{QD1..QD7}` đã registered
- Mỗi dimension xuất hiện tối đa 1 lần trên tất cả workloads (non-overlapping partition)
- Partition strategy: ISG-guided (ADR-23) — ưu tiên ISG recommendation khi có, fallback priority-based (core dims QD1+QD2+QD5 trước)
- `estimated_minutes` phải ≤ `profile.time_budget_minutes` (ADR-15 Workload Gate)

---

## 14. Registry Ownership — CORE-006

Toàn bộ pipeline v6 giữ nguyên role **NONE** cho `/wf-fix-bugs`:

| Skill | Field | Role | Ghi chú |
|-------|-------|------|---------|
| `/wf-fix-bugs` | — | **NONE** | Pure orchestrator, không chạm `req-registry.json` |
| `/wf-fix-<dim>` (7 lane) | — | **NONE** | Discovery-only; chỉ đọc registry để cross-ref REQ-ID |
| Signal Bus (utility) | — | **NONE** | Inline, không phải skill |
| Triage (service) | — | **NONE** | Không write registry |
| Planner (service) | — | **NONE** | Không write registry |
| Fixer (service) | `impl_status` | **SAFE-UPDATE** | CHỈ khi fix thay đổi behavior Feature → giữ quy tắc `/wf-fix-execute` v5 (không downgrade `done`) |
| Verifier (service) | — | **NONE** | Chỉ write `issue-registry.json`, không `req-registry.json` |

> **Kết luận:** Orchestrator và tất cả lane không ghi `req-registry.json`. Chỉ Fixer (khi cần) được SAFE-UPDATE `impl_status`, giống role của `/wf-fix-execute` trong v5.

---

## 15. Cross-Skill Output Path Contract — Đề xuất cập nhật `.claude/rules/00-core.md §4b`

### 15.1 Các dòng v5 cần **giữ** (không break backward-compat)

Các path hiện có dành cho `/wf-fix-bugs`, `/wf-fix-discover`, `/wf-fix-triage`, `/wf-fix-execute` **vẫn hợp lệ trong thời gian chuyển tiếp** (xem [06-migration-plan.md](06-migration-plan.md)). Không xoá ở PR kiến trúc; chỉ xoá sau khi migration hoàn tất.

### 15.2 Các dòng **mới cần thêm** khi v6 được triển khai

| Producer Skill | Output Path | Consumer Skill |
|----------------|-------------|----------------|
| `/wf-fix-bugs` Orchestrator (Init) | `$SESSION_DIR/fix-status.json` (schema `fix-status-v6`) | Tất cả lane + shared services + `--resume` |
| `/wf-fix-bugs` Orchestrator (Init) | `$SESSION_DIR/checkpoint.json` | `/wf-fix-bugs --resume` |
| `/wf-fix-<dim>` Lane (Sense/Think) | `$SESSION_DIR/lanes/<dim>/raw/<probe_id>.json` | Lane nội bộ, Signal Bus (optional) |
| `/wf-fix-<dim>` Lane (Verify) | `$SESSION_DIR/lanes/<dim>/signals.json` (schema `signal-v1`) | Signal Bus |
| `/wf-fix-<dim>` Lane (Verify) | `$SESSION_DIR/lanes/<dim>/lane-report.md` | Coverage Reporter |
| `/wf-fix-<dim>` Lane (POST-GATE) | `$SESSION_DIR/lanes/<dim>/phase-summary.md` (CORE-028) | Orchestrator summary, user |
| `/wf-fix-<dim>` Lane (checkpoint) | `$SESSION_DIR/lanes/<dim>/checkpoint.json` | Lane `--resume` |
| Signal Bus (utility) | `$SESSION_DIR/issue-registry.json` (schema `issue-v2`) | Triage, Planner, Fixer, Verifier, user |
| Signal Bus (utility) | `$SESSION_DIR/signal-bus-checkpoint.json` | Signal Bus resume |
| Triage Service | `$SESSION_DIR/issue-registry.json` (enrich: severity, fixability, fix_strategy, batch_group) | Planner, Fixer |
| Triage Service | `$SESSION_DIR/bug-triage.md`, `$SESSION_DIR/fix-plan.md` | User, Planner |
| Triage Service | `$SESSION_DIR/fix-log.json` (init empty) | Fixer, Verifier (APPEND) |
| Planner Service | `$SESSION_DIR/fix-batches.json` (schema `fix-batches-v1`) | Fixer |
| Fixer Service | `$SESSION_DIR/fix-log.json` (APPEND `apply_patch`) | Verifier, Report Phase |
| Fixer Service | `$SESSION_DIR/issue-registry.json` (enrich: fix_attempts[], fix_status) | Verifier |
| Fixer Service | `<code files repo>` (với Safety Gate CORE-020) | Repo |
| Verifier Service | `$SESSION_DIR/issue-registry.json` (final: verify_status, verify_evidence, regression_signals) | Coverage Reporter, user |
| Verifier Service | `$SESSION_DIR/fix-log.json` (APPEND `re_run_probe` + `regression_check`) | Report Phase |
| Verifier Service | `$SESSION_DIR/evidence/<issue_id>-after-*.png` (nếu có UI) | Report Phase, user |
| Coverage Reporter | `$SESSION_DIR/coverage-report.md` | User, `wf-prepare-deployment` Phase 0 (inform) |
| Orchestrator (POST-GATE) | `$SESSION_DIR/phase-summary.md` (CORE-028, ≤15 dòng tiếng Việt) | User |
| Orchestrator (POST-GATE) | `$SESSION_DIR/orchestrator-summary.md` | User (chi tiết) |
| Orchestrator (POST-GATE) | `.mc-data/work/wf-fix-bugs/fix-history.md` (APPEND) | Lịch sử chạy |

> Implementer sẽ propose patch `.claude/rules/00-core.md §4b` trong PR migration. Không tự sửa rules trước khi pipeline v6 được approve.

---

## 16. Template Versioning & Tương thích

### 16.1 Quy tắc bump

| Thay đổi | Bump |
|----------|------|
| Thêm optional field | minor (ví dụ `signal-v1.1`) |
| Thêm required field, đổi semantic | major (ví dụ `signal-v2`) |
| Sửa format path | major |
| Rename field | major |

### 16.2 Schema registry

Tất cả schema được liệt kê trong `.claude/skills/workflow/wf-fix-bugs/config/schema-registry.json`:

```json
{
  "schemas": {
    "fix-status-v6":    ".../schema/fix-status-v6.json",
    "issue-v2":         ".../schema/issue-v2.json",
    "signal-v1":        ".../schema/signal-v1.json",
    "fix-batches-v1":   ".../schema/fix-batches-v1.json",
    "fix-log-v1":       ".../schema/fix-log-v1.json",
    "dimension-v1":     ".../schema/dimension-v1.json",
    "profiles-v1":      ".../schema/profiles-v1.json",
    "dimensions-v1":    ".../schema/dimensions-v1.json"
  }
}
```

### 16.3 CORE-031 Template Usage

Tất cả file sinh ra phải có template tương ứng trong folder skill:

- Working templates: `wf-fix-bugs/templates/{fix-status.json, orchestrator-summary.md, coverage-report.md, phase-summary.md}`.
- Lane-level: `wf-fix-<dim>/templates/{signals.json, lane-report.md, phase-summary.md}`.
- Shared: `_shared/signal_bus/templates/{issue-registry.json, signal-bus-checkpoint.json}`.

Mỗi entry trong `_contract.json outputs.working[]` phải có `"template": "<path>"` — không được để `null` trừ khi đi kèm `"notes"` giải thích.

---

## 17. Checklist Cho Implementer

Khi bắt đầu implement một lane mới (hoặc shared service), tick từng ô:

- [ ] Tạo `dimension.json` tuân thủ schema §3.2.
- [ ] Định nghĩa ≥ 1 probe cho từng profile (`quick`, `standard`, `deep`, `exhaustive`).
- [ ] Tạo `templates/signals.json`, `templates/lane-report.md`, `templates/phase-summary.md` (CORE-031).
- [ ] Mỗi probe emit Signal đúng schema §1.2 — tối thiểu 1 evidence field non-empty.
- [ ] Viết golden fixtures trong `evals/golden/` (tối thiểu 1 case pass + 1 case edge).
- [ ] `_contract.json outputs.working[]` phải có `"template": "<path>"`.
- [ ] Đăng ký lane vào `config/dimensions.json` với `enabled: true`.
- [ ] Viết `phase-summary.md` ≤15 dòng tiếng Việt (CORE-028).
- [ ] Verify write scope: lane KHÔNG ghi ra ngoài `$SESSION_DIR/lanes/<dim>/` hoặc `evidence/<signal_id>-*`.
- [ ] PRE-GATE check forensic (CORE-011): content-level, không chỉ file-exists.
- [ ] POST-GATE T1-T4 (CORE-012) pass trước khi mark phase=done.

---

## 18. Liên kết

- Vision + Principles: [01-vision-principles.md](01-vision-principles.md)
- 7 Quality Dimensions: [02-quality-dimensions.md](02-quality-dimensions.md)
- Architecture: [03-architecture.md](03-architecture.md)
- Execution Profiles: [05-execution-profiles.md](05-execution-profiles.md)
- Migration Plan: [06-migration-plan.md](06-migration-plan.md)
- Tradeoffs & ADR: [07-tradeoffs-adr.md](07-tradeoffs-adr.md)
