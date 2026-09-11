# Lane Shared Library — `_shared/lane/`

> **Phien ban:** v2.0 (v10.0 wf-fix-bugs, 2026-05-13)
> **Pham vi:** 11 lane skills QD1-QD11: `wf-fix-functional`, `wf-fix-business`, `wf-fix-security`, `wf-fix-performance`, `wf-fix-ux-a11y`, `wf-fix-data`, `wf-fix-compat`, `wf-fix-observability`, `wf-fix-runtime-health`, `wf-fix-integration`, `wf-fix-business-completeness`
> **Muc dich:** Schemas + cross-cutting procedures dung chung cho 11 lanes — tranh drift, dam bao orchestrator (`wf-fix-bugs` v10.0) aggregate output dong nhat.
> **Khong load lazy:** lane skill PHAI doc file nay khi PRE-GATE/POST-GATE de bam schema.
>
> **SESSION DIRECTORY CONTRACT (v10.0):** Output paths duoc dinh nghia tai §12 — DAY LA SSOT. Moi lane skill PHAI tham chieu §12 thay vi hardcode path trong SKILL.md.

> **CHU Y — DUAL PURPOSE DIRECTORY:**
> Folder `_shared/lane/` chua HAI thanh phan doc lap, KHONG xung dot:
> 1. **Python lane dispatch module** (pre-existing): `__init__.py`, `dispatcher.py`, `_contract.json` (shared-module-contract-v1), `schemas/`, `tests/`, `templates/lane-signal.json`. Dung cho linear workflow skills (department/system/feature-group dispatch). KHONG lien quan QD lane.
> 2. **QD lane shared library** (S3, file nay): `_shared.md`, `pre-gate.md`, `post-gate.md`, `profile-resolver.md`, `signal-emit.md`, `templates/{lane-status.json, lane-report.md, signals.json, phase-summary.md, fix-plan.md, fix-log.json}`. Dung cho 7 wf-fix-{dim} lane skills.
>
> Hai thanh phan SHARING directory nhung **schema doc lap, file names khong overlap** (`lane-signal.json` vs `signals.json`).

---

## 1. Signal Schema (signal-v2)

Mot signal la 1 issue duoc lane probe phat hien. Ghi vao `$SESSION_DIR/phase4-find-bugs/lanes/$DIM-$NAME/{source}/signals.json` (lane-local, 1 file per scan type). Path convention canonical: xem §12 (Session Directory Contract v10.0). Orchestrator sau do dedup + aggregate vao `issue-registry.json` (root). 3 subdirectories: `static-scan/`, `runtime/`, `llm-scan/` — moi loai scan ghi vao file rieng, chong overwrite cross-source.

### 1.1 Schema

```json
{
  "$schema": "signal-v2",
  "id": "SIG-QDx-NNN",                           // duy nhat trong lane: SIG-{dimension}-{counter}
  "dimension_id": "QD1|QD2|QD3|QD4|QD5|QD6|QD7|QD8|QD9|QD10|QD11", // lane dimension
  "probe_id": "P-QDx-{name}",                    // probe sinh ra signal
  "probe_version": "v1.0",                       // version probe (de aggregator hieu schema)

  "severity": "critical|high|medium|low|info",   // 5 muc — xem §3
  "fixability": "auto_fix|agent_fix|escalate|skip", // 4 muc — xem §4
  "domain": "general|security|database|frontend|backend|mobile|devops|embedded|business",

  "title": "[<=80 ky tu, mo ta ngan]",
  "description": "[<=500 ky tu, chi tiet]",

  "location": {
    "file": "apps/backend/src/payment/refund.ts",  // path tuong doi tu repo root
    "line": 42,                                     // null neu khong xac dinh
    "column": null,                                 // null neu khong xac dinh
    "selector": null,                               // CSS selector cho UI bugs (QD5)
    "url": null                                     // URL cho runtime probes
  },

  "evidence": [                                     // xem §2
    {
      "type": "code|screenshot|trace|log|http_response|stdout",
      "path": "lanes/QD1-functional/raw/P-QD1-route-config-parse.json",
      "description": "Route config parse output co 3 routes thieu component"
    }
  ],

  "cdg_flags": [],                                  // xem §6 — empty hoac danh sach CDG codes

  "fingerprint": "sha256:abc123...",                // sha256(location.file + location.line + dimension_id + probe_id) — dedup key

  "registry_refs": {                                // optional cross-ref voi req-registry.json
    "req_ids": ["REQ-PAY-005"],
    "feat_ids": ["FEAT-CRM-PAY-003"],
    "module_ids": ["MOD-PAYMENT"]
  },

  "remediation": {                                  // optional — goi y fix
    "suggested_action": "Update route config",
    "suggested_agent": "developer|frontend-developer|security|dba|...",
    "estimated_effort": "trivial|small|medium|large"
  },

  "detected_at": "2026-04-28T10:30:00Z",
  "detected_by": "wf-fix-functional/P-QD1-route-config-parse"
}
```

### 1.2 Required vs Optional

**Required (BAT BUOC):**
- `$schema`, `id`, `dimension_id`, `probe_id`, `severity`, `fixability`, `title`, `location.file`, `fingerprint`, `detected_at`

**Optional (co thi tot):**
- `description`, `evidence`, `cdg_flags`, `registry_refs`, `remediation`, `domain`, `probe_version`

### 1.3 Validation

- `severity` PHAI thuoc `[critical, high, medium, low, info]`
- `fixability` PHAI thuoc `[auto_fix, agent_fix, escalate, skip]`
- `dimension_id` PHAI khop `lane.dimension` cua lane chu
- `fingerprint` PHAI duy nhat trong cung lane (dedup key)
- `id` PHAI tang tuyen tinh `SIG-QDx-001`, `SIG-QDx-002`, ...

---

## 2. Evidence Rules

Evidence la "bang chung vat ly" cho signal — KHONG duoc fantasy. Lane probe PHAI:

1. **Tao file evidence thuc te** truoc khi emit signal — KHONG emit signal khong evidence (tru `severity=info` voi `description` du)
2. **Path tuong doi** tu `$SESSION_DIR` — vi du `lanes/QD1-functional/raw/P-QD1-xxx.json`, `lanes/QD1-functional/evidence/screenshot-123.png`
3. **Description** mo ta noi dung evidence (KHONG copy-paste path)

### 2.1 Loai evidence

| Type | Mo ta | Vi du path |
|------|-------|------------|
| `code` | Code snippet trich tu file source | `lanes/QD1-functional/raw/P-QD1-deep-ui-traversal.json` (snippet trong) |
| `screenshot` | Anh chup man hinh tu Playwright/runtime probe | `lanes/QD1-functional/evidence/screenshot-route-404.png` |
| `trace` | HTTP trace / debug trace | `lanes/QD1-functional/evidence/trace-api-smoke-001.har` |
| `log` | Log output | `lanes/QD3-security/evidence/dependency-vuln-scan.log` |
| `http_response` | Raw HTTP response | `lanes/QD1-functional/evidence/api-smoke-response-500.json` |
| `stdout` | Output cua tool/script | `lanes/QD3-security/raw/P-QD3-secret-detection.json` |

### 2.2 Evidence integrity

- Evidence files la APPEND-only trong session (KHONG modify sau khi tao)
- Lane skill KHONG xoa evidence cua probe khac
- Orchestrator co the audit chain qua sha256 evidence files

---

## 3. Severity Matrix

| Severity | Y nghia | Vi du QD1 | Vi du QD3 (security) | Vi du QD4 (perf) |
|----------|---------|-----------|---------------------|------------------|
| `critical` | Block release — phai fix ngay | Feature missing routes/components | SQL injection, auth bypass | LCP > 4s, page crash |
| `high` | Should fix — anh huong UX/business | Form khong validate, broken redirect | XSS, missing CSP | LCP 2.5-4s, query > 5s |
| `medium` | Should fix neu co thoi gian | Validation message thieu | Outdated dependency (medium CVE) | LCP 2.5-2.5s, bundle > 500KB |
| `low` | Polish | Spacing/typo trong UI | Outdated dependency (low CVE) | Bundle > 250KB |
| `info` | Notification — KHONG can fix | "Da kiem tra X thanh cong" | "Co 0 vulnerability" | "LCP < 2.5s" |

### 3.1 Severity rules per dimension

Severity rules CHI TIET nam trong moi lane skill `_shared.md` hoac probe file. Default:

- `info` chi cho probe thanh cong (no issue)
- `critical/high/medium/low` cho probe phat hien issue

### 3.2 Khi nao escalate severity

- Code collision voi compliance (PCI-DSS, GDPR, HIPAA) → bump len `critical`
- Production-impacting (data loss, security breach) → bump len `critical`
- Affected feature/module trong DEPRECATED list → giam xuong `info` hoac SKIP

---

## 4. Fixability

| Fixability | Y nghia | wf-fix-execute behavior |
|------------|---------|-------------------------|
| `auto_fix` | Fix tu dong (lint, format, type) — khong can agent | Phase 3 Batch 1/3 inline |
| `agent_fix` | Spawn domain agent (developer, security, frontend-developer, dba) | Phase 3 Batch 2 parallel |
| `escalate` | Khong fix duoc — recommend skill khac (vi du: `/wf-design-ux`, `/wf-plan-modules`) | Log + skip + recommend |
| `skip` | Informational — KHONG fix | Log only |

### 4.1 Fixability heuristic

```
IF severity == "info" → fixability = "skip"
ELSE IF probe = static-checker (lint/type/format) → fixability = "auto_fix"
ELSE IF issue can be resolved with code change in scope → fixability = "agent_fix"
ELSE → fixability = "escalate"
```

---

## 5. Lane Status Schema (lane-status-v1)

Tracker tien do lane — tao o PRE-GATE, update sau moi probe, finalize o POST-GATE.

```json
{
  "$schema": "lane-status-v1",
  "lane": "wf-fix-functional",                     // ten skill
  "dimension": "QD1",                               // QD1-QD11
  "session_dir": "[ABS_PATH]",                      // resolved $SESSION_DIR
  "session_id": "2026-04-28-module-payment-01",
  "profile": "standard",                            // quick|standard|deep|exhaustive
  "status": "pending|in_progress|completed|partial|failed",
  "started_at": "2026-04-28T10:30:00Z",
  "completed_at": null,                             // null neu chua xong
  "duration_total_ms": null,

  "probes": [
    {
      "id": "P-QD1-req-registry-xref",
      "version": "v1.0",
      "status": "pending|running|done|skipped|failed",
      "started_at": "2026-04-28T10:30:00Z",
      "completed_at": "2026-04-28T10:30:45Z",
      "duration_ms": 45000,
      "signals_emitted": 4,
      "evidence_count": 4,
      "cache_hit": false,
      "skip_reason": null,                          // string neu status=skipped
      "error_message": null                         // string neu status=failed
    }
  ],

  "totals": {
    "probes_run": 0,
    "probes_skipped": 0,
    "probes_failed": 0,
    "signals_emitted": 0,
    "signals_by_severity": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0,
      "info": 0
    },
    "evidence_files": 0
  },

  "cache": {
    "enabled": false,
    "cache_hits": 0,
    "cache_misses": 0
  },

  "errors": []                                      // array of error objects neu lane gap loi
}
```

### 5.1 Trang thai lane

- `pending`: lane duoc create nhung chua bat dau probe
- `in_progress`: dang chay probes
- `completed`: tat ca probes done (khong fail)
- `partial`: 1+ probe fail nhung lane van ghi signals tu probes thanh cong
- `failed`: PRE-GATE fail hoac >50% probes fail

---

## 6. CDG Flags (Critical Decision Gate)

Signals co the carry CDG flags — khi orchestrator thay flag → cho user xac nhan truoc khi auto-fix.

| CDG Code | Y nghia | Khi nao emit |
|----------|---------|--------------|
| `CDG-DELETE-DATA` | Fix se xoa data | Migration drop column, schema change |
| `CDG-OVERWRITE-CODE` | Fix overwrite working code | Code collision detected |
| `CDG-SECURITY-LIVE` | Fix vao production-live security path | Auth, payment, PII |
| `CDG-COMPLIANCE` | Fix touch compliance scope | PCI/GDPR/HIPAA path |
| `CDG-SCHEMA-BREAK` | Fix break API/DB schema | Backward compat break |
| `CDG-LARGE-DIFF` | Fix tao diff > 500 lines | Major refactor |
| `CDG-DEPS-DOWN` | Fix downgrade dependency | Avoid silent regression |

### 6.1 CDG behavior

Lane probe set `cdg_flags` array tren signal. Orchestrator (`wf-fix-bugs`) detect → render CDG to user → user accept/reject token store o `cdg-tokens.json`. wf-fix-execute respect reject tokens (skip fix).

---

## 7. Profile → Probe Selection

Profile (`--profile`) quyet dinh probes nao chay. Mapping per-lane nam o `_shared/lane/profile-resolver.md`. Nguyen tac chung:

| Profile | Probe Coverage | Use Case |
|---------|---------------|----------|
| `quick` | 30-50% probes (only static + cheap) | Pre-commit, CI fast lane |
| `standard` | 70-80% probes (static + agent + light runtime) | Default — chay hang ngay |
| `deep` | 90% probes (full agent + runtime) | Pre-release, weekly audit |
| `exhaustive` | 100% probes + extra checks | Pre-Go-Live, audit |

---

## 8. Cross-Lane Coordination (v10.0)

Lanes chay parallel — KHONG goi nhau truc tiep. Coordination qua orchestrator:

1. Orchestrator (`wf-fix-bugs` v10.0) spawn lanes parallel voi cung `$SESSION_DIR`
2. Moi lane ghi signals vao 3 subdirectories theo loai scan (xem §12 Session Directory Contract):
   - `phase4-find-bugs/lanes/$DIM-$NAME/static-scan/signals.json` — static probes (bash scripts)
   - `phase4-find-bugs/lanes/$DIM-$NAME/runtime/signals.json` — runtime probes (agent/fixture)
   - `phase4-find-bugs/lanes/$DIM-$NAME/llm-scan/signals.json` — LLM probes (opt-in `--llm-scan`)
3. Moi file chi co 1 writer — KHONG merge-write, KHONG append cross-source
4. Orchestrator (signal_aggregator) doc tu ca 3 subdirectories + merge → `issue-registry.json` (root, dedup theo fingerprint)
5. Lane KHONG doc signals cua lane khac (avoid coupling)

### 8.1 Boundary

✅ Lane CO QUYEN:
- Tao file trong `$LANE_OUTPUT_BASE` (xem §12) — bao gom `static-scan/`, `runtime/`, `llm-scan/`
- Doc registry, docs, source code (read-only)
- Spawn agents cho probe agent-based
- Read shared profiles + schemas

❌ Lane KHONG DUOC:
- Ghi vao lane directory khac
- Modify `req-registry.json` (registry_scope.fields_owned = [])
- Ghi `issue-registry.json` (root) — orchestrator owner
- Goi sub-skill khac (KHONG dispatch tu lane)

### 8.2 Write Ownership Contract for `signals.json` (v10.0)

`$LANE_OUTPUT_BASE` signals duoc tach thanh 3 file rieng biet theo loai scan. Moi file chi co **1 writer** — khong can lock, khong can R-M-W, khong overwrite cross-source.

| File | Writer | Quy tac |
|------|--------|---------|
| `$LANE_OUTPUT_BASE/static-scan/signals.json` | Static probes (bash scripts) | WRITE toan bo: ghi signals cua `probe_id ∈ STATIC_PROBES`. KHONG ghi non-static hoac LLM signals. |
| `$LANE_OUTPUT_BASE/runtime/signals.json` | Runtime/fixture probes (agents) | APPEND-only: them signals voi `probe_id ∉ STATIC_PROBES ∪ LLM_PROBES`. KHONG ghi static hoac LLM signals. |
| `$LANE_OUTPUT_BASE/llm-scan/signals.json` | LLM probes (opt-in) | WRITE toan bo: ghi LLM signals (dedup internally). KHONG ghi static hoac runtime signals. |
| `issue-registry.json` (root) | `signal_aggregator.py` (Python) | READ-ONLY cho signals.json — doc tu ca 3 subdirectories + backward-compat fallback. Owner cho `issue-registry.json`. |

**Nguyen tac cot loi (v10.0):**

1. **1 file = 1 writer** — moi signals.json chi co DUNG 1 writer. KHONG can MERGE-write, KHONG can lock.
2. **Tach biet hoan toan** — static-scan, runtime, llm-scan la 3 file doc lap. KHONG writer nao ghi de file cua writer khac.
3. **Aggregator la reader duy nhat** — `signal_aggregator.py` doc tu ca 3 subdirectories + legacy fallback.
4. **Backward compat** — neu subdirectory thieu (session cu) → aggregator fallback doc `lanes/QDx/signals.json` cu.
5. **File trong (0 signals) van phai ghi** — `{"signals": []}` de xac nhan scan da chay.

Chi tiet: `wf-fix-bugs/procedures/phase4-find-bugs.md` § "Signal Directory Structure".

---

## 9. Cross-Reference

| Topic | File |
|-------|------|
| Session Directory Contract (v10.0) — CANONICAL OUTPUT PATHS | `_shared/lane/_shared.md` §12 |
| PRE-GATE template (forensic CORE-011) | `_shared/lane/pre-gate.md` |
| POST-GATE template (T1-T4 schema) | `_shared/lane/post-gate.md` |
| Profile → probe selection | `_shared/lane/profile-resolver.md` |
| Signal emit pattern (atomic + dedup) | `_shared/lane/signal-emit.md` |
| Lane status template | `_shared/lane/templates/lane-status.json` |
| Lane report template | `_shared/lane/templates/lane-report.md` |
| Lane signals template | `_shared/lane/templates/signals.json` |
| Orchestrator Phase 4 (Find Bugs) | `wf-fix-bugs/procedures/phase4-find-bugs.md` |

---

## 10. Versioning

- Schema v1 = current (wf-fix-bugs v7.0-v9.x)
- Schema v2 = v10.0+ (Session Directory Contract §12)
- Schema bump v3 khi:
  - Add/remove required fields tren signal-v2
  - Change semantic cua existing field
- Backward compat: aggregator (Python `_shared/signal_bus`) nen handle v1+v2 trong cung session

---

## 11. Output File Naming Convention (v10.0)

Moi lane skill tao cac file theo naming convention thong nhat:

| Output File | Name Pattern | Vi du (QD2) |
|-------------|-------------|-------------|
| Static signals | `static-scan/signals.json` | `static-scan/signals.json` |
| Runtime signals | `runtime/signals.json` | `runtime/signals.json` |
| LLM signals | `llm-scan/signals.json` | `llm-scan/signals.json` |
| Lane status | `lane-status.json` | `lane-status.json` |
| Lane report | `$DIM-$NAME-report.md` | `QD2-business-report.md` |

> `phase-summary.md` khong con duoc tao boi lane skill. Orchestrator tao `Phase4-report.md` tong hop.

---

## 12. Session Directory Contract (v10.0) — SSOT CHO OUTPUT PATHS

> **DAY LA CANONICAL DEFINITION.** Moi lane skill QD1-QD11 PHAI tham chieu section nay thay vi hardcode path trong SKILL.md hoac _contract.json.

### 12.1 Base path

```
$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/$DIM-$NAME/
```

Trong do:
- `$SESSION_DIR` = `.mc-data/work/wf-fix-bugs/sessions/{SESSION_ID}/` (set boi orchestrator Phase 1)
- `$DIM` = dimension ID (QD1..QD11) — tu `dimension.json`
- `$NAME` = short_name lowercase + dash-separated (functional, business, security, performance, accessibility, drift, compatibility, observability, runtime-health, integration, business-completeness)

### 12.2 Directory layout per lane

```
$LANE_OUTPUT_BASE/                  # Vd: phase4-find-bugs/lanes/QD2-business/
├── static-scan/
│   └── signals.json                # Static probes (bash scripts) — WRITE toan bo
├── runtime/
│   └── signals.json                # Runtime/fixture probes — APPEND-only
├── llm-scan/
│   └── signals.json                # LLM probes (opt-in --llm-scan) — WRITE toan bo
├── lane-status.json                # Lane progress tracker (lane-status-v1)
├── $DIM-$NAME-report.md            # Vd: QD2-business-report.md
├── raw/                            # Per-probe raw outputs (optional)
└── evidence/                       # Screenshots, HTTP traces (optional)
```

### 12.3 Mapping table (QD → directory name)

| Dimension | short_name | Lane Directory (canonical = `QD{N}-{lane_skill minus wf-fix-}`) |
|-----------|-----------|----------------|
| QD1 | Functional | `QD1-functional` |
| QD2 | Business | `QD2-business` |
| QD3 | Security | `QD3-security` |
| QD4 | Bottlenecks | `QD4-performance` |
| QD5 | Accessibility | `QD5-ux-a11y` |
| QD6 | Drift | `QD6-data` |
| QD7 | Compatibility | `QD7-compat` |
| QD8 | Observability | `QD8-observability` |
| QD9 | Runtime Health | `QD9-runtime-health` |
| QD10 | Integration | `QD10-integration` |
| QD11 | Business Completeness | `QD11-business-completeness` |

> **Quy ước SSOT:** Lane directory được derive từ lane skill name (bỏ prefix `wf-fix-`), KHÔNG từ `short_name`. Logic này nằm trong `route-and-write.sh` (Phase 3): `OUTPUT_DIR="lanes/${dim}-${LANE#wf-fix-}"`.

### 12.4 Cach su dung trong lane skill

Lane skill KHONG hardcode path. Thay vao do, reference contract nay:

```markdown
## Output

> **Path convention:** Theo `_shared/lane/_shared.md` §12 (Session Directory Contract v10.0).
> Base: `$LANE_OUTPUT_BASE = $SESSION_DIR/phase4-find-bugs/lanes/[DIM]-[NAME]/`

| File | Required | Template |
|------|----------|----------|
| `static-scan/signals.json` | yes | `_shared/lane/templates/signals.json` |
| `lane-status.json` | yes | `_shared/lane/templates/lane-status.json` |
| `[DIM]-[NAME]-report.md` | yes | `_shared/lane/templates/lane-report.md` |
```

Path trong `_contract.json` su dung `$SESSION_DIR/phase4-find-bugs/lanes/[DIM]-[NAME]/...`.

---

## 13. References

- CORE-006: Registry Safe-Write (lanes KHONG ghi registry)
- CORE-007: Cross-Skill Output Path Contract (lanes provide `signals.json`, `lane-status.json`, `lane-report.md`, `phase-summary.md`)
- CORE-011: Forensic PRE-GATE Validation (xem `pre-gate.md`)
- CORE-012: POST-GATE Schema Validation (xem `post-gate.md`)
- CORE-026: Execution Trace (lane KHONG dung session-log lam input)
- CORE-028: Phase Summary tieng Viet (xem `templates/phase-summary.md`)
- CORE-031: Template Usage Rule (lane outputs PHAI dung shared templates)
