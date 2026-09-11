---
name: wf-fix-security
version: 2.0.0-alpha.s4
last_updated: 2026-05-15
description: |
  QD3 Security Vulnerabilities Lane — phat hien loi bao mat qua probes P-QD3-xxx (7 probes lazy-load).
  ADR-22 Rule 6: KHONG dung scan cache trong moi profile.

  TRIGGER: spawned boi /wf-fix-bugs orchestrator khi QD3 trong selected_dims. KHONG goi truc tiep.

  v2.0 (S3-S4): chuan hoa schema (lane-status-v1, signal-v2, lane-report-v1) qua _shared/lane/. Tach probes + pre-gate + post-gate ra procedures/ (lazy-load). Fix F5 (CORE-031), F8, F9, F10, F16.

argument-hint: "[--session-dir=PATH] [--profile=quick|standard|deep|exhaustive] [--base-url=URL]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__plugin_gitnexus_gitnexus__impact, mcp__plugin_gitnexus_gitnexus__query, mcp__plugin_gitnexus_gitnexus__context, mcp__plugin_gitnexus_gitnexus__detect_changes, ListMcpResourcesTool, ReadMcpResourceTool
---
# /wf-fix-security: QD3 Security Vulnerabilities Lane

> **Shared Library:** `_shared/lane/_shared.md`, `_shared/lane/{pre-gate,post-gate}.md`, `_shared/lane/profile-resolver.md`, `_shared/lane/signal-emit.md`, `_shared/lane/templates/`.
> **Special:** ADR-22 Rule 6 — QD3 KHÔNG dùng scan cache trong mọi profile.

## Overview

| Muc | Noi dung |
|-----|----------|
| **Dimension** | QD3 — Security & Privacy |
| **Muc dich** | Phat hien OWASP Top 10, injection, XSS, auth bypass, secret leakage, insecure config |
| **Entry point** | Spawned boi `/wf-fix-bugs` orchestrator |
| **Prerequisites** | `$SESSION_DIR` da tao, source code ton tai |
| **Duration** | 3-20 min tuy profile |
| **Probes** | 7 (lazy-load) |
| **Cache Policy** | NEVER (ADR-22 Rule 6 — security KHONG cache) |
| **Output** | `$SESSION_DIR/phase4-find-bugs/lanes/QD3-security/{signals.json, lane-status.json, lane-report.md, phase-summary.md}` |

### Workflow Position

```
/wf-fix-bugs (orchestrator v10.x)
  → Spawn Lane QD3 (YOU ARE HERE) ─┐ CORE-025: parallel với other lanes
  → ... (other lanes parallel)    ─┘
  → Signal Bus aggregate
  → Triage → Fix Execute (CDG-SECURITY-LIVE escalation) → Verify → Report
```

Next step: Orchestrator tiếp tục Signal Aggregation. CRITICAL signals (secret/auth/injection) → CDG escalate.

## Probe Routing Table (Lazy-Load)

| Probe ID | Loai | quick | standard | deep | exhaustive | Procedure file |
|----------|------|:-----:|:--------:|:----:|:----------:|----------------|
| P-QD3-secret-detection | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-secret-detection.md` |
| P-QD3-dependency-vuln-scan | static+runtime | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-dependency-vuln-scan.md` |
| P-QD3-dangerous-deserialize | static | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-dangerous-deserialize.md` |
| P-QD3-cors-policy-check | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-cors-policy-check.md` |
| P-QD3-security-header-audit | runtime | ❌ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-security-header-audit.md` |
| P-QD3-auth-flow-verify | runtime+agent | ❌ | ❌ | ✅ | ✅ | `procedures/probes/P-QD3-auth-flow-verify.md` |
| P-QD3-owasp-top-ten | static | ✅ | ✅ | ✅ | ✅ | `procedures/probes/P-QD3-owasp-top-ten.md` |
| P-QD3-llm-analysis | llm | ❌ | ❌ | ✅ | ✅ | `prompts/llm-probe-qd3-security.md` |

## Phase 1: PRE-GATE + SENSE

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 1 | PRE-GATE forensic + force disable cache + verify scan tools | lane skill | `lane-status.json` (in_progress, cache.enabled=false) |
| 2 | Phase SENSE — chạy static probes (secret, vuln-scan, deserialize, owasp) | lane skill | `phase4-find-bugs/lanes/QD3-security/raw/<probe>.json` |

## Phase 2: THINK + ACT + VERIFY

| Step | Action | Owner | Output |
|------|--------|-------|--------|
| 3 | Phase THINK — cross-ref OWASP/CVE database, severity assignment | lane skill | (in-memory) |
| 4 | Phase ACT — chạy runtime+agent probes (auth-flow, cors, headers) | lane skill | HTTP traces + signals |
| 5 | Phase VERIFY — validate signal-v2 + ADR-22 audit (no cache calls) | lane skill | merged `signals.json` |
| 6 | POST-GATE T1-T4 + ADR-22 audit + CDG-SECURITY-LIVE flag check | lane skill | `lane-report.md`, `phase-summary.md`, `lane-status.json=completed` |

## CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).

| Step | Action | Verify |
|------|--------|--------|
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → IF `needs_scan` → call `mcp__serena__check_onboarding_performed` + `ListMcpResourcesTool` → `ci-detect.sh --write-cache '<json>'` → read cache → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Skip nếu non-git. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Freshness level → caveat trong probe context nếu stale. | Freshness status set |
| 0.Nc | **CI Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select → inject vào probe execution context. IF no CI → exit 1 → continue với Grep/Glob (current behavior). | CI context ready |

### CI-ROUTE: Security Vulnerability Discovery (Protocol 20 §20.5)

> **Khi `$GITNEXUS_AVAILABLE == "true"` hoặc `$SERENA_AVAILABLE == "true"`:** PHẢI dùng GitNexus + Serena để trace attack surfaces. KHÔNG dùng Grep/Read thủ công khi CI tools available.
> **ADR-22 Rule 6:** Security scan KHÔNG dùng cache — nhưng CI tools (GitNexus/Serena) là code intelligence, không phải scan cache → được phép dùng.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `understand_flow` | **GitNexus** `query("auth flow, session, input sanitization")` | Grep + Read | Trace auth/session/input flows để tìm injection points |
| `find_references` | **Serena** `find_referencing_symbols` | Grep | Tìm tất cả call sites của dangerous functions (eval, innerHTML, deserialize) |
| `impact_analysis` | **GitNexus** `impact({target, direction: "upstream"})` | Manual grep | Blast radius của vulnerability — ai gọi code bị lỗi |

> **Freshness caveat:** Nếu index behind > 0 → kèm cảnh báo trong probe findings. Security signals vẫn được emit.

## PRE-GATE

**Procedure:** `procedures/pre-gate.md`. Tóm tắt: 7 steps chuẩn + Step 8 force disable cache (ADR-22 Rule 6) + Step 9 verify scan tools (semgrep/gitleaks/npm audit) + Step 10 verify --base-url + Step 11 resolve probe list QD3.

## Execution: Sense → Think → Act → Verify

Lane chạy probes theo profile-resolver. Tất cả probes RE-SCAN mỗi lần (no cache per ADR-22). Atomic emit qua `_shared/lane/signal-emit.md`. Signals critical (secret/auth bypass) tự động đính kèm CDG-SECURITY-LIVE flag.

**CI-ROUTE cho probes:** Static probes (P-QD3-secret-detection, P-QD3-dangerous-deserialize, P-QD3-owasp-top-ten) PHẢI dùng Serena `find_referencing_symbols` để trace dangerous function usage + GitNexus `query()` để trace auth/input flows. Agent probe (P-QD3-auth-flow-verify) PHẢI dùng GitNexus `query("auth")` trước khi verify. CI unavailable → fallback Grep.

## POST-GATE

**Procedure:** `procedures/post-gate.md` (T3 rules QD3: ADR-22 audit no-cache, CDG enforcement cho secret-detection, mitigation_hint required).

## Severity Rules (QD3)

| Điều kiện | Severity | CDG Flag |
|-----------|----------|----------|
| Hard-coded secret bị lộ (P-QD3-secret-detection) | CRITICAL | CDG-SECURITY-LIVE |
| Authentication bypass (P-QD3-auth-flow-verify) | CRITICAL | CDG-SECURITY-LIVE |
| SQL/Command injection xác nhận | CRITICAL | CDG-SECURITY-LIVE |
| XSS/CSRF pattern (P-QD3-owasp-top-ten) | HIGH | — |
| Unsafe deserialize / eval / innerHTML user-data | HIGH | — |
| Dependency có CVE với exploit công khai | HIGH | — |
| Missing security header (HSTS, CSP, X-Frame) | MEDIUM | — |
| Overly permissive CORS | MEDIUM | — |
| Dependency có CVE chưa có exploit | MEDIUM | — |
| Cookie flags thiếu (httpOnly, secure, sameSite) | MEDIUM (prod=HIGH) | — |

## Fix Rules

| Severity | Action | Suggested Agent |
|----------|--------|-----------------|
| critical | escalate (CDG required, KHÔNG auto-fix per CORE-027) | security |
| high | agent_fix | security / backend-developer |
| medium | auto_fix (config update) hoặc agent_fix | devops / backend-developer |
| low | skip | — |

## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/QD3-security/`

| File | Required | Template | Mô tả |
|------|----------|----------|-------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` | Static probe signals với CDG flags (signal-v2). |
| `runtime/signals.json` | yes | `_shared/lane/templates/signals.json` | Runtime probe signals với CDG flags (signal-v2). |
| `llm-scan/signals.json` | yes (nếu `--llm-scan`) | `_shared/lane/templates/signals.json` | LLM probe signals (signal-v2). |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` | Progress tracker (cache.enabled=false). |
| `QD3-security-report.md` | yes | `_shared/lane/templates/lane-report.md` | Vulnerabilities by severity + CVSS. |
| `raw/` | optional | — | Per-probe raw outputs. |
| `evidence/` | optional | — | HTTP traces. |

> `phase-summary.md` không còn được tạo — orchestrator tổng hợp vào `Phase4-report.md`.

Next step: `/wf-fix-bugs` Signal Aggregation. CRITICAL → CDG handoff.

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E041 | PRE-GATE FAIL | STOP — ghi lane-status.failed |
| E042 | Probe execution timeout | Mark probe skipped, continue |
| E043 | P-QD3-secret-detection tìm thấy secret | CDG trigger — đính kèm CDG-SECURITY-LIVE flag |
| E044 | Auth flow verify thiếu phase3-architecture | Skip probe, note "skipped_no_architecture" |
| E045 | npm audit / pip audit không có | Fallback grep known vulnerable patterns, log WARNING |
| E046 | POST-GATE T3 ADR-22 audit FAIL (cache calls detected) | STOP — return failed (security violation) |
| E047 | Runtime probe — BASE_URL không có | Skip probe, note "skipped_no_base_url" |
| E048 | Semgrep tool không cài | Fallback regex builtin, note degraded coverage |

## Registry Safe-Write

Lane KHÔNG ghi `req-registry.json`. Role: NONE. Chỉ đọc registry để cross-ref.

## Related Skills

| Skill | Relation |
|-------|----------|
| `/wf-fix-bugs` | Parent orchestrator |
| `/wf-fix-triage` | Downstream — escalate CDG-SECURITY-LIVE signals |
| `/wf-fix-execute` | Downstream — respect CDG reject tokens |
| `/wf-fix-functional` | Sibling lane QD1 (parallel) |
| `/wf-fix-business` | Sibling lane QD2 (parallel) |
| `security` agent | `.claude/agents/engineering/security.md` (spawn cho P-QD3-auth-flow-verify) |

## References

- Quality Dimensions: `docs/design/skills/wf-fix-bugs/02-quality-dimensions.md` §QD3
- ADR-22: `docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md` Rule 6
- Design Decisions: `docs/design/skills/wf-fix-bugs/09-design-decisions.md`
- Core Rules: `.claude/rules/00-core.md` (CORE-006/007/011/012/023/025/026/027/028/030/031)
