# 04 — Contracts & Data Model (v2.0)

> **Đọc trước:** [03-architecture.md](03-architecture.md)
> **Đọc tiếp:** [05-execution-profiles.md](05-execution-profiles.md)
> **Trạng thái:** v2.0 · Phản ánh `_contract.json v10.18.0` (43 outputs + 50 error codes + 38 templates + 6 cross-skill consumers)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/04-contracts-data-model.md](../../99-archive/wf-fix-bugs-design-v1.0/04-contracts-data-model.md) (Signal v1, Issue v2 cho v6.0)

Tài liệu này định nghĩa **tất cả schema, contract, path** mà skill v10.18.0 đọc/ghi. Mọi implementer PHẢI tôn trọng các contract này. Thay đổi schema → bump `$schema` version + cập nhật `_contract.json` + chạy `validate-schema-sync.sh`.

---

## 0. Quy Ước Chung

| Khái niệm | Quy ước |
|-----------|---------|
| Encoding | UTF-8, LF (không CRLF) |
| JSON style | 2-space indent, trailing newline, UTF-8 không BOM |
| Markdown | CommonMark; headings có rỗng dòng sau (CORE-005) |
| Path convention | Tất cả path relative to project root (bắt đầu `.mc-data/`) |
| `$SESSION_DIR` | `.mc-data/work/wf-fix-bugs/sessions/{SESSION_ID}/` |
| ID generation | lowercase-kebab-case, không có space/diacritics (CORE-015, CORE-017) |
| Timestamp | ISO 8601 UTC (vd: `2026-05-16T08:00:00Z`) |
| Schema version | Semantic — major bump khi breaking; minor khi thêm optional field |
| Atomic write | `tmp.$$ → jq validate → mv tmp target` (CORE-035) |

---

## 1. Session Layout (`$SESSION_DIR`)

```
.mc-data/work/wf-fix-bugs/
├── _index/
│   └── sessions.jsonl                   # APPEND-only JSONL session index
├── fix-history.md                       # Cross-session history (CORE-026 read-only)
└── sessions/
    └── 2026-05-16-ALL-fix-bugs-01/      # SESSION_ID format: YYYY-MM-DD-{scope}-{slug}-{NN}
        ├── .lock                         # JSON {pid, host, started_at}, heartbeat daemon
        ├── fix-status.json               # SSOT pipeline state
        ├── session-log.json              # Execution trace (CORE-026, APPEND-only)
        ├── error-ledger.json             # Error tracking (CORE-034, APPEND-only)
        ├── bug-dashboard.md              # Cross-phase shared state (1/5/6/7 writers, version counter)
        ├── cdg-tokens.json               # CDG decisions persist (Phase 1/4/5)
        ├── phase1-init/                  # Output per phase
        ├── phase2-scan/
        ├── phase3-plan/
        ├── phase4-find-bugs/
        ├── phase5-triage/
        ├── phase6-execute/
        └── phase7-verify/
```

### SESSION_ID Format

`YYYY-MM-DD-{scope}-{slug}-{NN}`

- `YYYY-MM-DD` — ngày bắt đầu session
- `scope` — `all`/`system`/`module`
- `slug` — kebab-case slug (vd: `fix-bugs`, `payment-flow`)
- `NN` — counter 2-digit để tránh collision cùng ngày

Ví dụ: `2026-05-16-module-payment-flow-03`

### Lock File Format

```json
{
  "pid": 12345,
  "host": "DEV-MACHINE-01",
  "started_at": "2026-05-16T08:00:00Z",
  "heartbeat": "2026-05-16T08:15:32Z"
}
```

Heartbeat daemon update mỗi 30s. R7 lock check: same host → `kill -0 $pid`; different host → mtime fallback (stale > 60min auto-release E008).

---

## 2. Output Files Canonical Table (43 outputs)

> **Source of truth:** `_contract.json §outputs.working[]`. Bảng dưới đây là human-readable summary.

### Session-Root Outputs (5)

| # | Path | Template | Schema | Mục đích |
|---|------|----------|--------|---------|
| 1 | `$SESSION_DIR/fix-status.json` | `templates/phase1-init/fix-status.json` | (no schema) | SSOT pipeline state, atomic update sau mỗi POST-GATE |
| 2 | `$SESSION_DIR/session-log.json` | `templates/_common/session-log.json` | (no schema) | Execution trace APPEND-only (CORE-026) |
| 3 | `$SESSION_DIR/error-ledger.json` | `templates/_common/error-ledger.json` | (no schema) | Error tracking APPEND-only (CORE-034) |
| 4 | `$SESSION_DIR/.lock` | — | — | Lock + heartbeat daemon |
| 5 | `$SESSION_DIR/bug-dashboard.md` | `templates/phase5-triage/bug-dashboard.md` | (no schema) | Cross-phase shared state, version counter `<!-- bug-dashboard-version: N -->` (CORE-025 conflict detect) |

### Phase 1 Init Outputs (1)

| # | Path | Template |
|---|------|----------|
| 6 | `$SESSION_DIR/phase1-init/Phase1-report.md` | `templates/phase1-init/Phase1-report.md` |

### Phase 2 Scan Outputs (4)

| # | Path | Template | Schema |
|---|------|----------|--------|
| 7 | `$SESSION_DIR/phase2-scan/scope-analysis.json` | `templates/phase2-scan/scope-analysis.json` | scope-analysis-v2 |
| 8 | `$SESSION_DIR/phase2-scan/code-inventory.json` | `templates/phase2-scan/code-inventory.json` | code-inventory-v1 |
| 9 | `$SESSION_DIR/phase2-scan/doc-inventory.json` | `templates/phase2-scan/doc-inventory.json` | doc-inventory-v1 |
| 10 | `$SESSION_DIR/phase2-scan/Phase2-report.md` | `templates/phase2-scan/Phase2-report.md` | (no schema) |

### Phase 3 Plan Outputs (4)

| # | Path | Template |
|---|------|----------|
| 11 | `$SESSION_DIR/phase3-plan/work-plan.json` | `templates/phase3-plan/work-plan.json` |
| 12 | `$SESSION_DIR/phase3-plan/dimension-plan.json` | `templates/phase3-plan/dimension-plan.json` |
| 13 | `$SESSION_DIR/phase3-plan/workloads/W{N}/fix-workload.json` | `templates/phase3-plan/fix-workload.json` |
| 14 | `$SESSION_DIR/phase3-plan/Phase3-report.md` | `templates/phase3-plan/Phase3-report.md` |

### Phase 4 Find Bugs Outputs (9, scaling N per lane)

| # | Path | Template | Schema |
|---|------|----------|--------|
| 15 | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/static-scan/signals.json` × N | `templates/phase4-find-bugs/lane-signals.json` | signal-v2 |
| 16 | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/runtime/signals.json` × N | `templates/phase4-find-bugs/lane-signals.json` | signal-v2 |
| 17 | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/llm-scan/signals.json` × N | `templates/phase4-find-bugs/lane-signals.json` | signal-v2 |
| 18 | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/lane-status.json` × N | `templates/phase4-find-bugs/lane-status.json` | lane-status-v1 |
| 19 | `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/QD{n}-{name}-report.md` × N | `templates/phase4-find-bugs/QD-report.md` | (no schema) |
| 20 | `$SESSION_DIR/phase4-find-bugs/Phase4-report.md` | `templates/phase4-find-bugs/Phase4-report.md` | (no schema, CORE-028 ≤15 dòng) |
| 21 | `$SESSION_DIR/phase4-find-bugs/phase4-summary.json` | `templates/phase4-find-bugs/phase4-summary.json` | **phase4-summary-v1** (CORE-036 cross-skill) |
| 22 | `$SESSION_DIR/phase4-find-bugs/probe-failures.log` | `templates/phase4-find-bugs/probe-failures-log.json` | probe-failure-v1 (JSONL APPEND-only) |
| 22b | (agent-spawn) prompt rendered inline | `templates/phase4-find-bugs/lane-agent-prompt.md` | **lane-agent-prompt-v10.2** |

### Phase 5 Triage Outputs (11)

| # | Path | Template | Schema |
|---|------|----------|--------|
| 23 | `$SESSION_DIR/phase5-triage/issue-registry.json` | `templates/phase5-triage/issue-registry.json` | issue-registry-v2 |
| 24 | `$SESSION_DIR/phase5-triage/bug-triage.md` | `templates/phase5-triage/bug-triage.md` | — |
| 25 | `$SESSION_DIR/phase5-triage/fix-plan.md` | `templates/phase5-triage/fix-plan.md` | — |
| 26 | `$SESSION_DIR/phase5-triage/fix-log.json` | `templates/phase5-triage/fix-log.json` | fix-log-v1 |
| 27 | `$SESSION_DIR/phase5-triage/cdg-tokens.json` | `templates/phase5-triage/cdg-tokens.json` | cdg-tokens-v1 |
| 28 | `$SESSION_DIR/phase5-triage/safety-check.json` | `templates/phase5-triage/safety-check.json` | safety-check-v1 |
| 29 | `$SESSION_DIR/phase5-triage/process-violations.json` | `templates/phase5-triage/process-violations.json` | process-violations-v1 (PI1-PI5) |
| 30 | `$SESSION_DIR/phase5-triage/coverage-report.md` | `templates/phase5-triage/coverage-report.md` | — |
| 31 | `$SESSION_DIR/phase5-triage/coverage-report.json` | `templates/phase5-triage/coverage-report.json` | **coverage-report-v1** (cross-skill opt-in) |
| 32 | `$SESSION_DIR/phase5-triage/Phase5-report.md` | `templates/phase5-triage/Phase5-report.md` | (CORE-028 ≤15 dòng) |

### Phase 6 Execute Outputs (4)

| # | Path | Template | Schema |
|---|------|----------|--------|
| 33 | `$SESSION_DIR/phase6-execute/fix-report.md` | `templates/phase6-execute/fix-report.md` | — |
| 34 | `$SESSION_DIR/phase6-execute/docs-sync-report.json` | `templates/phase6-execute/docs-sync-report.json` | **docs-sync-report-v2** |
| 35 | `$SESSION_DIR/phase6-execute/fix-execution-result.json` | `templates/phase6-execute/fix-execution-result.json` | **fix-execution-result-v2** |
| 36 | `$SESSION_DIR/phase6-execute/Phase6-report.md` | `templates/phase6-execute/Phase6-report.md` | (CORE-028 ≤15 dòng) |

### Phase 7 Verify Outputs (4)

| # | Path | Template | Schema |
|---|------|----------|--------|
| 37 | `$SESSION_DIR/phase7-verify/orchestrator-summary.md` | `templates/phase7-verify/orchestrator-summary.md` | (CORE-028 tiếng Việt ≤40 dòng) |
| 38 | `$SESSION_DIR/phase7-verify/fix-impact.json` | `templates/phase7-verify/fix-impact.json` | **fix-impact-v1** (CORE-036 cross-skill) |
| 39 | `$SESSION_DIR/phase7-verify/phase-summary.md` | `templates/phase7-verify/phase-summary.md` | (gộp head 8 dòng × 7 phase) |
| 40 | `$SESSION_DIR/phase7-verify/Phase7-report.md` | `templates/phase7-verify/Phase7-report.md` | (CORE-028 ≤15 dòng) |

### Cross-Session Outputs (3)

| # | Path | Template | Mục đích |
|---|------|----------|---------|
| 41 | `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` | — | APPEND-only JSONL index |
| 42 | `.mc-data/work/wf-fix-bugs/fix-history.md` | — | Cross-session human-readable history |
| 43 | `cdg-tokens.json` (Phase 1/4/5) | `templates/phase5-triage/cdg-tokens.json` | CDG decisions persist |

---

## 3. Schema Definitions

### 3.1 Signal v2 (`signals.json`)

**Path:** `$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/{static-scan|runtime|llm-scan}/signals.json`
**Template:** `templates/phase4-find-bugs/lane-signals.json`
**Writer:** Lane agent (1 file = 1 writer per stream)

```json
{
  "$schema": "signal-v2",
  "lane": "QD3-security",
  "stream": "static-scan",
  "generated_at": "2026-05-16T08:30:00Z",
  "signals": [
    {
      "signal_id": "SIG-20260516-QD3-0001",
      "fingerprint": "<sha256 of location+probe>",
      "dimension": "QD3",
      "probe_id": "P3.02",
      "probe_source": {
        "type": "static|runtime|llm|external",
        "tool": "regex|playwright|semgrep|axe-core|agent:security",
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
        "http_trace": "$SESSION_DIR/.../P3.02-trace.har",
        "screenshot": "$SESSION_DIR/.../reset-no-auth.png",
        "log": "lack of authGuard in router chain"
      },
      "severity_hint": "HIGH",
      "confidence": 0.85,
      "tags": ["auth", "privilege-escalation"],
      "req_ids": ["REQ-SEC-014"],
      "feat_ids": ["FEAT-AUTH-ADMIN-002"],
      "detected_at": "2026-05-16T08:01:23Z",
      "lane_run_id": "QD3-run-001"
    }
  ]
}
```

**Ràng buộc:**
- `fingerprint` = sha256(location.path + probe_id + location.range) — dùng cho dedup
- `dimension` ∈ {QD1, QD2, QD3, QD4, QD5, QD6, QD7, QD8, QD9, QD10, QD11}
- `confidence` ∈ [0.0, 1.0]: ≥0.9 static chắc chắn, 0.7-0.89 LLM, <0.7 heuristic
- Tối thiểu 1 field `evidence.*` non-empty
- `severity_hint` chỉ là gợi ý — Triage agent có quyền override

### 3.2 Lane Status v1 (`lane-status.json`)

```json
{
  "$schema": "lane-status-v1",
  "lane": "QD3-security",
  "status": "completed|in_progress|failed|skipped|pending",
  "started_at": "2026-05-16T08:00:00Z",
  "completed_at": "2026-05-16T08:15:00Z",
  "duration_seconds": 900,
  "probe_results": {
    "P3.01": { "status": "ok", "signals": 2 },
    "P3.02": { "status": "ok", "signals": 1 },
    "P3.03": { "status": "skipped", "reason": "no SQL queries detected" }
  },
  "evidence_index": [
    { "path": "...", "type": "screenshot|har|log|artifact", "size_bytes": 12345 }
  ],
  "errors": [
    { "code": "E044", "message": "...", "probe_id": "P3.04" }
  ]
}
```

### 3.3 Issue Registry v2 (`issue-registry.json`)

```json
{
  "$schema": "issue-registry-v2",
  "session_id": "...",
  "issues": [
    {
      "id": "ISSUE-001",
      "fingerprint": "<dedup key>",
      "dimensions": ["QD3", "QD6"],
      "probe_ids": ["P3.02", "P6.01"],
      "severity": "CRITICAL|HIGH|MEDIUM|LOW|INFO",
      "fixability": "auto|guided|manual|deferred",
      "title": "...",
      "location": { ... },
      "source": "static|runtime|llm|external",
      "req_ids": ["REQ-..."],
      "feat_ids": ["FEAT-..."],
      "cdg_flags": [],
      "recommended_action": "...",
      "evidence_paths": ["..."]
    }
  ]
}
```

### 3.4 fix-impact.json v1 (CORE-036 cross-skill)

**Path:** `$SESSION_DIR/phase7-verify/fix-impact.json`
**Writer:** `generate-phase7-reports.sh`
**Consumers:** `wf-verify-sync`, `wf-prepare-deployment`, `wf-implement-feature`, `wf-cmi`

```json
{
  "$schema": "fix-impact-v1",
  "session_id": "2026-05-16-ALL-fix-bugs-01",
  "skill": "wf-fix-bugs",
  "version": "10.18.0",
  "generated_at": "2026-05-16T10:30:00Z",
  "scope": "all|system|module",
  "scope_name": "...",
  "profile": "standard",
  "summary": {
    "total_issues": 25,
    "fixed": 18,
    "deferred": 5,
    "failed": 2,
    "by_dimension": {
      "QD1": { "found": 8, "fixed": 7 },
      "QD3": { "found": 5, "fixed": 4 }
    },
    "by_severity": { "CRITICAL": 2, "HIGH": 8, "MEDIUM": 10, "LOW": 5 }
  },
  "registry_changes": {
    "impl_status_updates": [
      { "req_id": "REQ-SEC-014", "old": "not_started", "new": "done" }
    ]
  },
  "files_changed": ["apps/backend/src/admin/reset-password.ts", "..."],
  "docs_synced": [".mc-data/docs/phase3-architecture/REQ-SEC-014.md"],
  "regression_risk": "LOW|MEDIUM|HIGH",
  "next_action": "/wf-verify-sync --from-fix-bugs",
  "audit_chain": {
    "source_file": "$SESSION_DIR/phase6-execute/fix-report.md",
    "checksum_sha256": "abc123...64-char...",
    "generated_at": "2026-05-16T10:30:00Z",
    "generated_by": "generate-phase7-reports.sh"
  }
}
```

### 3.5 phase4-summary.json v1 (CORE-036 cross-skill)

**Path:** `$SESSION_DIR/phase4-find-bugs/phase4-summary.json`
**Writer:** `generate-phase4-report.sh`
**Consumers:** Phase 5 fast-path aggregation, Phase 7 CQG-2 severity check, external audit/compliance

```json
{
  "$schema": "phase4-summary-v1",
  "session_id": "...",
  "per_dim_breakdown": {
    "QD1-functional": {
      "status": "completed",
      "duration_seconds": 480,
      "playwright": false,
      "signals": { "static": 5, "runtime": 12, "llm": 0 },
      "by_severity": { "HIGH": 3, "MEDIUM": 8, "LOW": 6 },
      "by_fixability": { "auto": 5, "guided": 8, "manual": 4 },
      "probe_failures": 0,
      "evidence_count": 17
    }
  },
  "rollup": {
    "total_signals": 87,
    "by_source": { "static": 32, "runtime": 45, "llm": 10 },
    "by_severity": { "CRITICAL": 2, "HIGH": 8, "MEDIUM": 50, "LOW": 27 },
    "by_dimension": { "QD1": 17, "QD3": 12 },
    "top_fingerprints": [ ... ]
  },
  "registry_coverage": {
    "REQ-SEC-014": 3,
    "FEAT-AUTH-ADMIN-002": 5
  },
  "cdg_decisions": {
    "E090": "ACCEPT",
    "E090b": "WAIT"
  },
  "evidence_index": [ ... ],
  "audit_chain": {
    "checksum_sha256": "..."
  }
}
```

### 3.6 coverage-report.json v1 (CORE-036 opt-in cross-skill)

```json
{
  "$schema": "coverage-report-v1",
  "dimensions": [ "QD1", "QD2", "QD5", "QD9" ],
  "distribution": {
    "by_severity": {
      "critical": { "count": 2, "pct": 8 },
      "high": { "count": 8, "pct": 32 },
      "medium": { "count": 10, "pct": 40 },
      "low": { "count": 5, "pct": 20 }
    }
  },
  "totals": {
    "dims_covered": 4,
    "dims_total": 11,
    "dims_skipped": 7,
    "probe_success_rate": 0.95,
    "total_signals": 87,
    "total_issues": 25
  }
}
```

### 3.7 cdg-tokens.json v1

```json
{
  "$schema": "cdg-tokens-v1",
  "tokens": [
    {
      "code": "E090",
      "phase": "phase4",
      "step": "4.3",
      "question": "Missing URL ...",
      "options_shown": ["Nhập URL", "SKIP QD9", "Cancel"],
      "user_decision": "Nhập URL",
      "user_input": "http://localhost:3000",
      "decided_at": "2026-05-16T08:05:23Z"
    }
  ]
}
```

---

## 4. Cross-Skill Contracts (CORE-036)

### 4.1 Produces (6 consumers)

| Consumer | Artifact(s) | When Consumed |
|----------|-------------|---------------|
| `wf-verify-sync` | `fix-impact.json`, `fix-report.md`, `issue-registry.json`, `fix-history.md` | `--from-fix-bugs` flag |
| `wf-prepare-deployment` | `fix-impact.json` | `--from-fix-bugs` flag |
| `wf-implement-feature` | `fix-impact.json` (Pre-Implementation Safety enhanced) | `--from-fix-bugs` flag |
| `wf-define-features` | `.mc-data/docs/phase2-features/` stubs | Khi `wf-fix-bugs --deep` tạo stubs |
| `wf-design-ux` | `.mc-data/docs/phase4-ux/` stubs | Khi `wf-fix-bugs --deep` tạo stubs |
| `wf-cmi` | `fix-impact.json` | `--from-fix-bugs` opt-in |

### 4.2 Consumes (4 producers)

| Producer | Artifact | When Read |
|----------|----------|-----------|
| `wf-brainstorm` | `legacy-decisions.json` (CORE-022) | Phase 1 LEGACY_MODE PRE-GATE |
| `wf-legacy-scan` | `project-context.md`, `ledger.json` | Phase 1 LEGACY_MODE detect (CORE-021) |
| `wf-preflight` | `preflight-impact.json` | Phase 1 health hint (`--from-preflight`) |
| `wf-cmi` | `integrity-impact.json` | Phase 3 ISG hint (`--from-cmi` opt-in) |

### 4.3 Orchestrates (2 sub-skills)

| Sub-skill | Trigger | Role |
|-----------|---------|------|
| `wf-fix-triage` | Phase 4 POST-GATE pass (N>0) + CDG handoff accepted | Phase 5 delegate — classify + triage bugs |
| `wf-fix-execute` | Phase 5 POST-GATE pass + Safety Check passed | Phase 6 delegate — execute fixes |

**Lane skills** (11) — spawned bởi Phase 4 via PARALLEL Agent({subagent_type:"claude"}) ≤10:

| Lane | Skill |
|------|-------|
| QD1 | `wf-fix-functional` |
| QD2 | `wf-fix-business` |
| QD3 | `wf-fix-security` |
| QD4 | `wf-fix-performance` |
| QD5 | `wf-fix-ux-a11y` |
| QD6 | `wf-fix-data` |
| QD7 | `wf-fix-compat` |
| QD8 | `wf-fix-observability` |
| QD9 | `wf-fix-runtime-health` |
| QD10 | `wf-fix-integration` |
| QD11 | `wf-fix-business-completeness` |

---

## 5. Templates Canonical List (38 files)

```
templates/
├── _common/
│   ├── error-ledger.json
│   └── session-log.json
├── phase1-init/
│   ├── fix-status.json
│   └── Phase1-report.md
├── phase2-scan/
│   ├── code-inventory.json
│   ├── doc-inventory.json
│   ├── Phase2-report.md
│   └── scope-analysis.json
├── phase3-plan/
│   ├── dimension-plan.json
│   ├── fix-workload.json
│   ├── Phase3-report.md
│   └── work-plan.json
├── phase4-find-bugs/
│   ├── lane-agent-prompt.md        # schema lane-agent-prompt-v10.2
│   ├── lane-signals.json
│   ├── lane-status.json
│   ├── Phase4-report.md
│   ├── phase4-summary.json         # schema phase4-summary-v1
│   ├── probe-failures-log.json
│   └── QD-report.md
├── phase5-triage/
│   ├── bug-dashboard.md
│   ├── bug-triage.md
│   ├── cdg-tokens.json
│   ├── coverage-report.md
│   ├── coverage-report.json        # schema coverage-report-v1
│   ├── fix-log.json
│   ├── fix-plan.md
│   ├── issue-registry.json
│   ├── Phase5-report.md
│   ├── process-violations.json
│   └── safety-check.json
├── phase6-execute/
│   ├── docs-sync-report.json       # schema docs-sync-report-v2
│   ├── fix-execution-result.json   # schema fix-execution-result-v2
│   ├── fix-report.md
│   └── Phase6-report.md
└── phase7-verify/
    ├── fix-impact.json              # schema fix-impact-v1
    ├── orchestrator-summary.md
    ├── phase-summary.md
    └── Phase7-report.md
```

**Quy tắc CORE-031:**
- Mọi output PHẢI tạo từ template: READ → POPULATE → WRITE
- NẾU SKIP bước READ template → STOP skill
- `_contract.json §outputs.working[]` PHẢI có field `template`
- Template metadata stripping: xóa `_template_notes`, `_schema_notes` trước khi write

---

## 6. Error Codes Canonical (50 codes, 10 ranges)

> **Namespace convention (CORE-034):**
> - E001-E009 → Pipeline/session/lock (shared)
> - E010-E019 → Phase 1 Init
> - E020-E029 → Phase 2 Scan
> - E030-E039 → Phase 3 Plan
> - E040-E049 → Phase 4 Find Bugs
> - E050-E059 → Phase 5 Triage
> - E060-E069 → Phase 6 Execute
> - E070-E079 → Phase 7 Verify
> - E090-E099 → CDG User-Facing Gates
> - E100-E109 → Recommendations/Warnings

### Pipeline/Session (E001-E009)

| Code | Severity | Tình huống | Xử lý |
|------|----------|-----------|------|
| E001 | critical | POST-GATE fail sau 3 retries | DỪNG, escalate |
| E002 | medium | (reserved) | — |
| E003 | critical | Registry thiếu/rỗng | STOP — chạy `/wf-brainstorm` |
| E004 | critical | Sub-skill SKILL.md không tồn tại | STOP |
| E005 | info | N=0 issues sau Phase 5 | "Healthy!" → jump Phase 7 |
| E008 | medium | Stale lock auto-release | WARN, continue |
| E009 | medium | Context > 90% | FORCE checkpoint, STOP |

### Phase 1 (E010-E019)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E010 | medium | Flag dispatch `--status`/`--resume`/`--migrate` |
| E011 | medium | `--status` handler |
| E012 | medium | `--resume` handler |
| E013 | high | Legacy deprecation block / Staleness check |
| E014 | high | CI detection fail (Wave 1 Worker 1) |
| E015 | high | Registry validation fail |
| E016 | high | Session create fail |
| E019 | high | Phase 1 catch-all |

### Phase 2 (E020-E029)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E020 | high | Code scan empty |
| E021 | high | Doc scan empty |

### Phase 3 (E030-E039)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E030 | high | Profile fail |
| E031 | high | Partition fail / Session lock conflict |
| E035 | high | Atomic write fail |

### Phase 4 (E040-E049)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E040 | high | Lane dispatch fail |
| E041 | high | Probe fail |
| E042 | high | Playwright launch fail |
| E043 | high | Lane stub generation (validate fail) |
| E044 | high | Agent timeout |
| E045 | high | Mobile coverage gap |
| E046 | high | Lane timeout 15min |
| E047 | high | Inconsistency detection |
| E048 | high | Invalid signal logging |
| E049 | high | Phase 4 catch-all |

### Phase 5 (E050-E059)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E050 | high | Aggregate fail |
| E051 | high | Dedup fail |
| E052 | high | Triage agent fail |
| E053 | high | Re-spawn x1 fail |
| E054 | high | CDG REJECT 2 lần |
| E055 | high | Safety check fail |

### Phase 6 (E060-E069)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E060 | high | Execute agent spawn fail |
| E061 | high | Fix-report empty |

### Phase 7 (E070-E079)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E070 | high | CQG-1 numeric fail (deviation > 5%) |
| E071 | high | CQG-2 browser/integration fail (CDG REJECT 2 lần) |
| E073 | high | Mobile gate fail |
| E074 | high | Report generation fail |
| E075 | high | fix-impact audit_chain integrity fail |

### CDG (E090-E099)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E090 | info | Missing URL (Phase 4) |
| E090b | info | BASE_URL multi-session conflict (Phase 4) |
| E091 | info | (reserved) Scope CDG |
| E092 | info | (reserved) Cost CDG |
| E093 | info | (reserved) Mobile CDG |

### Recommendations (E100-E109)

| Code | Severity | Tình huống |
|------|----------|-----------|
| E100 | low | Recommendation warning (QD9/QD10/QD11) |

### Special

| Code | Severity | Tình huống |
|------|----------|-----------|
| EDLG | high | Sub-skill incomplete (deadlock detection) |
| E_LEGACY_BLOCK | fatal | Legacy v6.x paths (exit 78) |

---

## 7. Auto-Fix Budget Model (CORE-034)

- Max **3 retries / phase** (tất cả tier gộp chung budget)
- Auto-fix strategies per error type:
  - T1 fail (file missing) → re-run step tạo file
  - T2 fail (structure wrong) → re-read template + populate lại
  - T3 fail (content too short) → re-generate với more context
  - T4 fail (cross-ref mismatch) → re-read source + re-write target
- Budget hết → ESCALATE: AskUserQuestion "Re-run phase / Skip (risky) / Cancel"
- Reset budget khi POST-GATE PASS

---

## 8. POST-GATE T1-T4/T5 (CORE-012 + Protocol 10)

Mọi POST-GATE PHẢI có tiered validation:

| Tier | Check | Ví dụ |
|------|-------|-------|
| **T1** | File exists + non-empty | `test -s "$SESSION_DIR/.../file.json"` |
| **T2** | Structure valid (JSON parse / required fields) | `jq -e '.required_field' file` |
| **T3** | Content depth (non-trivial — không stub) | `jq -e '.issues | length > 0'` |
| **T4** | Cross-reference (link với upstream output) | `grep -q "$INTERFACE_TYPE" Phase2-report.md` |
| **T5** | (chỉ Phase 6/7) Schema version + audit_chain | `jq -e '."$schema" == "fix-impact-v1"'` + sha256 verify |

Fail → retry x1 verbose → vẫn fail → E001 escalate.

---

## 9. Registry Safe-Write Delegation (CORE-006)

**wf-fix-bugs là ORCHESTRATOR** — `registry_scope.fields_owned = []`, `write_role = "NONE"`. KHÔNG ghi `req-registry.json` trực tiếp.

- Registry write delegate sang **`wf-fix-execute`** (Phase 6 sub-skill)
- Fields được phép update (SAFE-UPDATE role): `impl_status` (chỉ upgrade not_started → in_progress → done, KHÔNG downgrade per CORE-008), `last_modified`
- Atomic write: build tmp → validate jq → mv atomic
- Verification: `jq '.' req-registry.json` PASS + check `impl_status ∈ {not_started, in_progress, done, skipped}` (CORE-010)
- Audit chain: registry write log vào `fix-log.json` với `action:"registry_update"`. Cross-skill verify qua `wf-verify-sync --from-fix-bugs`

> Chi tiết: `.claude/skills/protocols/05-registry-safe-write.md`

---

## 10. PRE-GATE / POST-GATE File Contract

| # | Transition | PRE-GATE (files must exist) | POST-GATE (T1-T4 validate) | Error |
|---|------------|------------------------------|------------------------------|-------|
| 1→2 | Init → Scan | `fix-status.json`, `Phase1-report.md`, session dir + lock active | T1-T4: fix-status.json structure valid, session-log.json writable | E010 |
| 2→3 | Scan → Plan | `scope-analysis.json`, `code-inventory.json`, `doc-inventory.json`, `Phase2-report.md` | T1-T4: all 3 inventory non-empty + interface_type detected | E020 |
| 3→4 | Plan → Find Bugs | `work-plan.json`, `dimension-plan.json`, `Phase3-report.md` | T1-T4: ≥1 fix-workload.json valid, dimension→lane routing complete | E030 |
| 4→5 | Find Bugs → Triage | ≥1 lane `signals.json` non-empty, all lane `lane-status.json` | T1-T4: signal count > 0, per-lane status COMPLETE/FAIL | E040 |
| 5→6 | Triage → Execute | `issue-registry.json`, `bug-triage.md`, `fix-plan.md`, `cdg-tokens.json` (CDG ACCEPT) | T1-T4: issue-registry ≥1 entry, fix-plan non-empty, safety-check PASS | E050 |
| 6→7 | Execute → Verify | `fix-report.md`, `docs-sync-report.json`, `Phase6-report.md` | T1-T5: fix-report ≥1 fix recorded, docs-sync valid, fix-execution-result-v2 schema OK | E060 |
| 7→DONE | Verify → Complete | `orchestrator-summary.md`, `fix-impact.json`, `phase-summary.md`, `Phase7-report.md` | T1-T5 + CQG-1 numeric + CQG-2 browser/integration + fix-impact-v1 audit_chain sha256 verify | E070 |

---

## 11. Liên Kết

| Tài liệu | Lý do |
|----------|-------|
| [02-quality-dimensions.md](02-quality-dimensions.md) | 11 QDs ↔ signal/issue schema |
| [03-architecture.md](03-architecture.md) | Session layout + agent dispatch |
| [05-execution-profiles.md](05-execution-profiles.md) | Profile × dim selection |
| `.claude/skills/workflow/wf-fix-bugs/_contract.json` | Canonical contract (43 outputs + 50 errors) |
| `.claude/skills/protocols/10-post-gate-schema.md` | POST-GATE T1-T4/T5 schema |
| `.claude/skills/protocols/19-template-usage.md` | Template Usage Rule (CORE-031) |
| `.claude/skills/protocols/05-registry-safe-write.md` | Safe-Write Protocol (CORE-006) |
