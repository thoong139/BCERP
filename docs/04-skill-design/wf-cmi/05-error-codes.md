# 05 — Error Codes (wf-cmi)

> **Mục đích file:** Catalog error codes — registry/severity/auto-fix budget cho skill wf-cmi.

---

## 1. Namespace allocation

| Range | Phase / Category | Số codes claimed | Note |
|-------|-----------------|----------------|------|
| E001-E009 | Shared (pipeline, session, lock) | 9 | Theo registry chuẩn — KHÔNG override semantic |
| E010-E019 | Phase 1 (Init + CI PRE-GATE) | 10 | E010-E013 args/registry; E014-E019 CI/lock |
| E020-E029 | Phase 2 (Discovery) | 10 | Per-graph build errors |
| E030-E039 | Phase 3 (Invariant Registry) | 10 | LLM inference + domain expert |
| E040-E049 | Phase 4 (Coverage Dispatch — 10 lanes) | 10 | Lane spawn + signal validation |
| E050-E059 | Phase 5 (Aggregate) | 10 | Signal aggregation + coverage compute |
| E060-E069 | Phase 6 (Regression Map) | 10 | GitNexus impact + git diff |
| E070-E079 | Phase 7 (GAP + CDG) | 10 | Suggestion generation + CDG decisions |
| E080-E089 | Phase 8 (Report) | 10 | Cross-skill artifact write |
| E090-E099 | CDG user-facing gates | 10 | Coverage threshold, dual-approval, conflict |
| E100-E109 | Warnings / Recommendations (non-blocking) | 10 | CI degradation, stale cache, predictive low-confidence |

**Đăng ký:** Phải khớp 100% với [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §4 (sẽ update khi PR skill).

---

## 2. Error codes detail

### Shared (E001-E009)

| Code | Phase | Severity | Ý nghĩa | Auto-fix strategy |
|------|-------|---------|---------|-------------------|
| E001 | Any | CRITICAL | POST-GATE fail sau 3 retries — budget hết | STOP phase, ESCALATE AskUserQuestion |
| E002 | Any | MEDIUM | User REJECT CDG decision | Checkpoint, thông báo `--resume` |
| E003 | Any | CRITICAL | Registry thiếu/rỗng (Phase 1 T1-T3 fail) | STOP, hướng dẫn `/wf-brainstorm` |
| E004 | Any | CRITICAL | Sub-skill/lane procedure file không tồn tại | STOP workflow |
| E005 | Phase 5/7/8 | INFO | 0 violations + 100% coverage — system healthy | Early exit OK, không phải lỗi |
| E008 | Any | MEDIUM | Stale lock detected (≥30 min) | Auto-release, WARN, continue |
| E009 | Any | CRITICAL | Context budget >90% — FORCE STOP (CORE-038) | Checkpoint bắt buộc, hướng dẫn `--resume` |

### Phase 1 — Init + CI PRE-GATE (E010-E019)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E010 | CRITICAL | Registry missing (`req-registry.json` không tồn tại) | ESCALATE → `/wf-brainstorm` hoặc `/existing-project` |
| E011 | CRITICAL | Registry schema invalid (jq parse fail) | ESCALATE → user fix manual |
| E012 | HIGH | Registry empty (`requirements[].length == 0`) | ESCALATE — không thể chạy với registry rỗng |
| E013 | HIGH | Phase 3 architecture docs missing | ESCALATE — chạy `/wf-design` trước |
| E014 | HIGH | `--since=<ref>` invalid (git rev-parse fail) | ESCALATE — user fix ref |
| E015 | MEDIUM | `--session-id` format invalid | Re-generate auto session ID, WARN |
| E016 | MEDIUM | Args conflict (vd `--auto-suggest` + `--ci`) | ESCALATE — user fix args |
| E017 | HIGH | Session dir creation fail (disk full / permission) | Retry (max 3), ESCALATE |
| E018 | HIGH | Lock acquire fail (another session running) | Retry x3 với 5s delay, ESCALATE |
| E019 | HIGH | Heartbeat daemon spawn fail | Retry x1, ESCALATE |

### Phase 2 — Discovery (E020-E029)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E020 | HIGH | Phase 1 state missing (integrity-status.json) | Re-run Phase 1 |
| E021 | HIGH | State inconsistency (current_phase ≠ 2) | Re-reset state |
| E022 | HIGH | Code unreachable (CI fail + Grep fallback fail) | ESCALATE — user check permissions |
| E023 | HIGH | Module-code drift (CORE-013) — registry modules ≠ folder structure | ESCALATE → `/wf-legacy-scan` Stage 3.5 |
| E024 | MEDIUM | Entity graph build fail (parser error) | Retry x2, fallback heuristic Grep |
| E025 | MEDIUM | Workflow graph build fail (no CQRS pattern detected) | Skip workflow graph, WARN |
| E026 | MEDIUM | API graph build fail (Endpoints pattern not recognized) | Try alternative parsers (FastAPI, Express) |
| E027 | MEDIUM | Event graph build fail (no message broker config) | Skip event graph, WARN |
| E028 | MEDIUM | RBAC matrix build fail | Try alternative auth patterns |
| E029 | LOW | Graph empty (≥1 graph có 0 nodes) | WARN, mark dim as N/A |

### Phase 3 — Invariant Registry (E030-E039)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E030 | HIGH | Phase 2 outputs incomplete (graphs missing) | Re-run Phase 2 |
| E031 | HIGH | Graphs empty (no nodes) | ESCALATE — scope quá hẹp hoặc code chưa scannable |
| E032 | MEDIUM | Domain expert knowledge file missing (`team-expert/{domain}/`) | Fallback business-analyst only, WARN |
| E033 | MEDIUM | Profile-phase mismatch (vd profile=quick → skip 3-pass LLM) | Auto-skip (info), không error |
| E034 | HIGH | LLM API call timeout (>5 min for 1 domain) | Retry x1, ESCALATE |
| E035 | MEDIUM | LLM output schema invalid (cannot parse invariant) | Re-prompt với clarified output contract |
| E036 | MEDIUM | Cross-domain conflict detected (>3 conflicts/session) | CDG E091 escalate batch |
| E037 | MEDIUM | Invariant source_doc broken link | Re-link or DROP candidate |
| E038 | LOW | Confidence too low (<0.5) — không enter `accepted` state | Status = `proposed` only, WARN |
| E039 | MEDIUM | Registry v3 migration fail (existing v1/v2 has incompatible structure) | ESCALATE — manual migration required |

### Phase 4 — Coverage Dispatch (E040-E049)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E040 | HIGH | Lane dispatch fail — agent spawn error | Retry per-agent x1, ESCALATE batch |
| E041 | MEDIUM | Probe timeout (>3 min per lane) | Mark lane TIMEOUT, continue others |
| E042 | HIGH | System resource limit (cannot spawn 10 agents concurrently) | Reduce concurrency to 5, WARN |
| E043 | MEDIUM | Lane activation mismatch (profile expected X lanes, got Y) | Re-validate profile config |
| E044 | HIGH | Schema mismatch (sidecar artifact `business-invariants.json` expected, got v1/v2) | ESCALATE — user run Phase 3 to bump |
| E045 | MEDIUM | Invariant incomplete (missing required fields) | Re-prompt agent |
| E046 | MEDIUM | Orphan invariant (source_doc path not found) | Re-link or DROP |
| E047 | HIGH | DATA INCONSISTENCY — claimed signal count ≠ actual files | ESCALATE — possible agent corruption |
| E048 | MEDIUM | Signal schema validation fail | Re-validate, drop invalid signals |
| E049 | LOW | Fingerprint collision (duplicate signals) | Dedupe, INFO log |

### Phase 5 — Aggregate (E050-E059)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E050 | HIGH | Lane outputs missing (≥1 active lane không có signals.json) | Re-spawn missing lane (max 1) |
| E051 | HIGH | Signal schema invalid | Skip invalid, log |
| E052 | MEDIUM | Invalid dim value (not in CD1-CD10) | DROP signal, WARN |
| E053 | LOW | Fingerprint collision cross-lane | Dedupe |
| E054 | MEDIUM | Coverage compute fail (division by zero — no entities) | Mark dim = N/A |
| E055 | MEDIUM | Matrix template fill error | Re-build từ template |
| E056 | MEDIUM | `coverage-report.md` vi phạm ≤15 dòng | Re-format, truncate |
| E057 | LOW | Phase 4 lane SKIPPED, Phase 5 cannot aggregate dim | Mark dim = SKIPPED |
| E058 | MEDIUM | Cross-lane signal aggregation conflict (same fingerprint, different severity) | Pick HIGHER severity, log |
| E059 | LOW | Workload estimator overflow (>10K signals total) | Truncate per dim, WARN |

### Phase 6 — Regression Map (E060-E069)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E060 | HIGH | Aggregation missing | Re-run Phase 5 |
| E061 | HIGH | `--since` ref invalid | ESCALATE |
| E062 | MEDIUM | GitNexus impact unavailable + git fallback only | Downgrade predictive → diff-aware, WARN |
| E063 | MEDIUM | Scope mismatch (changed files ngoài scope) | Filter, WARN |
| E064 | MEDIUM | Predictive confidence too low cho >50% predictions | Downgrade to diff-aware, WARN |
| E065 | LOW | No changed files since ref | EXIT 0 với "no changes detected" report |
| E066 | MEDIUM | Test plan generation fail (no test files discovered) | Skip test plan, WARN |
| E067 | LOW | Cross-module prediction confidence threshold not met | Filter low-confidence predictions |
| E068 | MEDIUM | Affected module count > 10 (system-wide impact) | WARN, log all but cap report |
| E069 | LOW | Git log history limited (<5 commits) | Use partial history, WARN |

### Phase 7 — GAP + CDG (E070-E079)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E070 | HIGH | Phase 5-6 outputs missing | Re-run prerequisite phases |
| E071 | HIGH | CDG mode invalid in --ci context | ESCALATE — user fix args |
| E072 | HIGH | Unresolved CDG decision blocking Phase 7 | Re-prompt CDG (max 1), ESCALATE |
| E073 | MEDIUM | Suggestion generation fail (LLM error) | Retry x1, skip |
| E074 | MEDIUM | Suggestion missing actionable target (no test/contract/invariant defined) | Re-generate |
| E075 | MEDIUM | User REJECT all suggestions in session | INFO log, no auto-fix |
| E076 | MEDIUM | Suggestion duplicate of existing artifact | DROP, WARN |
| E077 | LOW | Suggestion confidence below threshold | Mark `proposed`, KHÔNG `accepted` auto |
| E078 | MEDIUM | Approver chain missing (multi-user collaboration) | ESCALATE — manual review |
| E079 | LOW | CDG decision log corruption (cannot append) | Retry write, ESCALATE |

### Phase 8 — Report (E080-E089)

| Code | Severity | Ý nghĩa | Auto-fix |
|------|---------|---------|----------|
| E080 | HIGH | Pipeline incomplete (Phase 1-7 chưa PASS hết) | Re-validate, ESCALATE |
| E081 | HIGH | Template file missing | Re-locate templates path, ESCALATE |
| E082 | HIGH | Matrix schema invalid for downstream | Re-build matrix |
| E083 | HIGH | Cannot write `integrity-impact.json` (permission/disk) | Retry x3, ESCALATE |
| E084 | MEDIUM | `integrity-report.md` >30 dòng | Re-format, truncate |
| E085 | MEDIUM | `audit_chain.checksum` compute fail | Retry x1 |
| E086 | MEDIUM | Cross-skill artifact path mismatch contract | Re-validate paths |
| E087 | LOW | Phase report `Phase{N}-report.md` vi phạm ≤15 dòng | Re-format |
| E088 | MEDIUM | `--show-graphs` Mermaid render fail | Skip diagrams, WARN |
| E089 | LOW | CI mode JSON output unparsable | Re-format JSON |

### CDG gates (E090-E099, user-facing)

| Code | Severity | Trigger | User question | Default action |
|------|---------|---------|--------------|----------------|
| E090 | MEDIUM | Coverage below threshold per profile | "Coverage X% < threshold Y%. Chọn: accept gap / generate artifacts / cancel?" | ABORT |
| E090b | MEDIUM | Parallel session conflict (BASE_URL or write lock) | "Phiên Y đang chạy. Wait / Cancel / Force release?" | WAIT |
| E091 | MEDIUM | Cross-domain invariant conflict (2 experts opinion lệch) | "Logistics expert says A, Finance expert says B. Choose A / B / Defer?" | DEFER |
| E092 | MEDIUM | System integrity degraded (>3 cross-module dependencies missing) | "3 cross-module FK chưa enforce. Continue / Generate artifacts / Cancel?" | CONTINUE WITH WARN |
| E093 | MEDIUM | Domain compliance check fail (GDPR/HS Code/GAAP) | "Mobile-customer endpoint collect PII không có audit log. GDPR risk. Continue?" | ABORT |
| E094 | HIGH | Auto-suggest will modify registry — confirm | "Sẽ APPEND 12 invariants vào sidecar artifact `business-invariants.json`. Confirm?" | ABORT |
| E095 | MEDIUM | Multi-user dual approval required | "Dev A approved invariant X. Dev B (you) approve to commit?" | DEFER |
| E096 | MEDIUM | Profile auto-upgrade recommended | "Scope=system với profile=quick có thể miss coverage. Upgrade → standard?" | CONTINUE QUICK |
| E097 | LOW | Stale CDG decision (>7 days, registry changed since) | "CDG decision X cũ 10 ngày, registry đã thay đổi. Re-confirm?" | DEFER |
| E098 | MEDIUM | Cost estimate exceeds budget (LLM > $5) | "Deep profile sẽ tốn ~$8 LLM. Continue / downgrade / cancel?" | CONFIRM |
| E099 | MEDIUM | Destructive op (drop existing invariants) | "Sẽ REJECT 5 invariants existing. Confirm destructive?" | ABORT |

### Warnings (E100-E109, non-blocking)

| Code | Severity | Ý nghĩa | Action |
|------|---------|---------|-------|
| E100 | INFO | CI tool absent — fallback Grep | Log, continue |
| E101 | INFO | CI index stale (light/strong) | Log, suggest `gitnexus analyze`, continue |
| E102 | INFO | Invariant unverified (no code/test ref found) | Log, mark `verified_by: []` |
| E103 | INFO | Predictive scoring low confidence | Log, downgrade to diff-aware |
| E104 | INFO | Lane SKIPPED (profile activation) | Log per-lane |
| E105 | INFO | Domain expert knowledge file partial | Fallback business-analyst, log |
| E106 | INFO | Cache stale (>TTL) | Refresh, log |
| E107 | INFO | Multi-user collaboration — peer session detected | Log peer session_id + author |
| E108 | INFO | Profile auto-downgrade applied (vd CI mode + deep → standard) | Log reason |
| E109 | INFO | Sidecar artifact business-invariants regenerated | Log migration_from version |

---

## 3. Error ledger pattern

File: `$SESSION_DIR/error-ledger.json` (JSONL, APPEND-only)

```json
{"phase": 4, "error_code": "E041", "severity": "medium", "message": "Lane CD3 timeout >3 min", "timestamp": "2026-05-15T14:35:00+07:00", "retry_count": 1, "context": {"lane": "CD3", "agent": "architect", "duration_sec": 185}}
{"phase": 4, "error_code": "E041", "severity": "medium", "message": "Lane CD3 timeout >3 min (retry 2)", "timestamp": "2026-05-15T14:38:00+07:00", "retry_count": 2}
{"phase": 4, "error_code": "E001", "severity": "critical", "message": "POST-GATE Phase 4 fail sau 3 retries — auto-fix budget hết", "timestamp": "2026-05-15T14:41:00+07:00", "retry_count": 3}
```

**Quy tắc:**
- APPEND-only, không đọc lại làm input context (CORE-026)
- File reset chỉ khi tạo session mới
- ISO-8601 timestamp bắt buộc

---

## 4. Auto-fix budget

| Phase | Max retries | Strategy ordering |
|-------|-------------|-------------------|
| Phase 1 | 3 | T1 fail → re-write → T2 fail → re-build từ template → T3 fail → re-generate ID |
| Phase 2 | 3 (per-graph) | Each graph build retry independent; if 2/6 graphs fail → mark dim N/A, continue |
| Phase 3 | 3 (per-domain) | LLM call retry; if domain expert fail → fallback business-analyst |
| Phase 4 | 3 (per-lane) + 1 batch-retry | Each lane has 1 retry; batch retry triggers nếu ≥3 lanes fail |
| Phase 5 | 3 | Aggregate retry với cleaned signals |
| Phase 6 | 3 | GitNexus retry x1, fallback git diff x1, partial scan x1 |
| Phase 7 | 3 (per-suggestion) | CDG prompt retry x1, suggestion regen x2 |
| Phase 8 | 3 | Report regen x3 |

**Budget reset:** sau POST-GATE PASS của phase.

**Budget hết → ESCALATE format:**
```
Phase {N} không thể tự fix sau {budget} retries.
Lỗi cuối: E0{XX} — {message}.

Bạn muốn:
  1. Re-run phase từ đầu (reset budget)
  2. Skip phase này (risky — coverage giảm, audit chain ghi)
  3. Cancel skill (checkpoint, dùng --resume sau)
  4. Switch profile (vd: deep → standard)
```

---

## 5. Escalation policy

Khi auto-fix budget exhausted, skill dừng và chạy `AskUserQuestion`:

```python
AskUserQuestion({
  questions: [{
    question: "Phase {N} ({phase_name}) không thể tự sửa sau 3 lần. Bạn muốn?",
    header: "Phase {N} fail",
    multiSelect: false,
    options: [
      {"label": "Re-run phase từ đầu", "description": "Reset budget, có thể fix nếu nguyên nhân tạm thời (rate limit, network)"},
      {"label": "Skip phase (rủi ro)", "description": "Tiếp tục, ghi audit chain. Phù hợp nếu phase optional theo profile."},
      {"label": "Cancel skill", "description": "Checkpoint, exit. Dùng --resume sau khi user fix manual."},
      {"label": "Switch profile", "description": "Downgrade profile (vd deep → standard) để giảm load."}
    ]
  }]
})
```

User chọn → skill route theo lựa chọn (update `integrity-status.json.next_action`).

---

## 6. Severity → action mapping

| Severity | POST-GATE behavior | Auto-fix | User confirmation |
|---------|-------------------|---------|-------------------|
| CRITICAL | FAIL ngay, không retry | Không | Bắt buộc (CDG hoặc ESCALATE) |
| HIGH | FAIL, retry max 3 | Có | Bắt buộc khi budget hết |
| MEDIUM | WARN, retry max 1-2 | Có | Optional (CDG nếu user-facing) |
| LOW | Continue | Skip | Không |
| INFO | Continue | Skip | Không |

---

## 7. User-facing error message format

```
⚠️ Lỗi [E041]: Lane CD3 (Workflow coverage) vượt thời gian (3 phút).

Lý do: Module Orders có 50+ workflow paths phức tạp, agent timeout khi trace.

AI sẽ thử lại 1 lần nữa với scope thu hẹp (chỉ Orders core flow).
Nếu vẫn fail, sẽ hỏi bạn: tăng timeout / skip lane CD3 / downgrade profile.
```

**Quy tắc CORE-028 (Phase report user-friendly):**
- Có code (vd `[E041]`) cho user reference
- Tiếng Việt, KHÔNG jargon kỹ thuật thô (vd "agent timeout" → "vượt thời gian")
- Giải thích nguyên nhân + cách xử lý
- KHÔNG ép user fix code — AI tự xử lý hoặc gợi ý options

---

## 8. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md) §auto-fix budget
- Rules: CORE-034 (Namespaced error codes), CORE-026 (Execution trace), CORE-027 (CDG)
- Pattern: [`../../03-design-patterns/04-cdg-decision-gate.md`](../../03-design-patterns/04-cdg-decision-gate.md)
- Real example: [`../wf-fix-bugs/05-error-codes.md`](../wf-fix-bugs/05-error-codes.md) (canonical reference)
