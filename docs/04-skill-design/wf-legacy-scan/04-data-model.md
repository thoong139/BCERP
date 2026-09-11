# 04 — Data Model & Cross-Skill Contracts

> **Đọc trước:** [03-architecture.md](03-architecture.md)
> **Đọc tiếp:** [05-profiles-ips.md](05-profiles-ips.md)

---

## 1. Unified State: `scan-state.json`

### 1.1 Schema (canonical)

```json
{
  "$schema": "scan-state-v1",
  "session": {
    "id": "2026-04-22T10-00-00",
    "created": "2026-04-22T10:00:00Z",
    "project_path": "/path/to/project",
    "profile": "standard",
    "strategy": "CODE_FIRST",
    "maturity_level": "CODE_PLUS_EXTERNAL_DOCS",
    "workload_id": null,
    "chunk_id": null
  },
  "depth_map": {
    "L1": "full",
    "L2": "full",
    "L3": "full",
    "L4": "standard",
    "L5": "standard",
    "L6": "full"
  },
  "synthesis_mode": "full",
  "config": {
    "batch_size": 100,
    "max_files_cap_api": 500,
    "max_files_cap_screens": 500,
    "concurrency": {
      "global_max": 8,
      "per_layer_max": 3,
      "per_probe_max": 4,
      "reserved_for_synthesis": 2
    },
    "cache": {
      "session_cache_enabled": true,
      "project_cache_enabled": false,
      "ttl_days": 14
    },
    "incremental": false,
    "since_ref": null
  },
  "layers": {
    "L1": {
      "name": "discovery",
      "status": "completed",
      "started": "2026-04-22T10:00:01Z",
      "completed": "2026-04-22T10:00:15Z",
      "outputs": ["project-profile.json"],
      "checkpoint": null
    },
    "L2": {
      "name": "assessment",
      "status": "completed",
      "started": "2026-04-22T10:00:16Z",
      "completed": "2026-04-22T10:00:22Z",
      "outputs": ["assessment-report.json", "domain-hints.json"],
      "checkpoint": null
    },
    "L3": {
      "name": "inventory",
      "status": "completed",
      "started": "2026-04-22T10:00:23Z",
      "completed": "2026-04-22T10:01:45Z",
      "outputs": ["inventory/screens.json", "inventory/api-endpoints.json", "..."],
      "checkpoint": null
    },
    "L4": {
      "name": "classification",
      "status": "in_progress",
      "started": "2026-04-22T10:01:46Z",
      "completed": null,
      "depth": "standard",
      "batch_progress": { "current": 2, "total": 5, "completed_batches": ["batch-001", "batch-002"] },
      "partial": "layers/L4/partial.json",
      "outputs": ["classified/batch-001.json", "classified/batch-002.json"]
    },
    "L5": {
      "name": "extraction",
      "status": "not_started",
      "depth": "standard",
      "module_progress": { "completed": 0, "total": 8, "in_progress": null },
      "partial": null,
      "outputs": []
    },
    "L6": {
      "name": "synthesis",
      "status": "not_started",
      "synthesis_mode": "full",
      "outputs": []
    }
  },
  "ips": {
    "phase_a": {
      "run_at": "2026-04-22T10:00:22Z",
      "recommended_profile": "standard",
      "profile_reasoning": "Healthy project, medium size, no strong domain signal",
      "detected_domains": [
        {"domain": "finance", "confidence": 0.65, "recommended_agent": "finance-expert"}
      ],
      "user_overrode_profile": false
    },
    "phase_b": {
      "run_at": "2026-04-22T10:01:45Z",
      "module_routing": {
        "billing": {"domain": "finance", "expert": "finance-expert", "confidence": 0.88}
      },
      "complexity_hotspots": [
        {"module": "billing", "files": 45, "priority": "high"}
      ],
      "workload_estimate": {
        "total_features_est": 68,
        "est_time_min": 32,
        "soft_cap_min": 40,
        "exceeds_cap": false
      }
    }
  },
  "workload": null,
  "last_completed": "L3",
  "status": "in_progress",
  "error_log": [],
  "resume_hint": "Resume from L4 classification, batch 3/5 (2 batches completed)",
  "legacy_ledger": {
    "generated_at": null,
    "schema_version": "legacy-v4.1",
    "note": "Generated 1x at POST Phase 4 synthesize (v2.1 — no reverse-sync). See ADR-LS04."
  }
}
```

### 1.2 State Transitions

```
Layer states:
  not_started → in_progress → completed
                           ↘ failed
                           ↘ skipped_by_profile

Session states:
  init → in_progress → completed | failed | paused (resumable)
```

### 1.3 Sub-Skill Migration (v2.1 REVISED — reverse-sync ELIMINATED)

**v2.0 approach (superseded):** Reverse-sync protocol với ledger.json ↔ scan-state.json bidirectional sync + file-lock + advisory lock + merge rules.

**v2.1 approach (current):** Sub-skills migrate đọc+ghi `scan-state.json` trực tiếp trong Phase D (ADR-LS04 revised). `ledger.json` chỉ được orchestrator generate **1 lần** tại POST Phase 4 synthesize (read-only legacy projection cho downstream skills cũ). **Zero race condition.**

**Write direction (v2.1):**

```
Orchestrator + Sub-skills:
  ┌─ All components WRITE scan-state.json qua helper `scan_state_reader.py`
  │     → Helper enforces: file-lock + atomic write (tmp → fsync → rename)
  │     → State machine validation: not_started → in_progress → completed/failed/skipped_by_profile
  │     → No direct JSON write — mọi update qua helper API
  │
  └─ Orchestrator generates ledger.json ONCE at POST Phase 4 synthesize
        → Downstream skills (wf-brainstorm legacy, wf-analyze-requirements legacy, ...) read ledger.json
        → Sub-skills DO NOT write ledger.json anymore
```

**Helper API (`scan_state_reader.py`):**

```python
# Read
state = read_scan_state(session_id=None)  # None → latest active session
layer_status = read_layer_status(state, 'L4')

# Write (atomic)
update_layer_status('L4', 'in_progress', session_id=None)
update_batch_progress('L4', {'current': 3, 'total': 8, 'completed_batches': [...]})
update_module_progress('L5', module='billing', status='completed')
append_error('L5', {'code': 'E-L5-01', 'message': '...', 'retry_count': 2})

# Standalone fallback
# Nếu user chạy /wf-legacy-classify standalone sau khi đã scan xong:
#   - Helper detect no active session → init session từ ledger.json v4.1 legacy
#   - Migrate ledger.json data → scan-state.json format
#   - Tiếp tục như thường
```

**Field mapping (orchestrator POST Phase 4 generate ledger.json):**

| scan-state.json field | ledger.json field | Notes |
|----------------------|-------------------|-------|
| `layers.L4.status` | `stages.classify.status` | Copy |
| `layers.L4.batch_progress` | `stages.classify.items_classified` | Derive total |
| `layers.L5.status` | `stages.extract.status` | Copy |
| `layers.L5.module_progress.completed` | `stages.extract.modules_completed` | Copy |
| `layers.L5.metadata.low_confidence_modules` | `summary.low_confidence_modules[]` | Copy |
| `error_log[]` | `errors[]` | Copy |
| `session.strategy` | `strategy.id` | Copy |
| `session.maturity_level` | `maturity.level` | Copy |

**Concurrent write protection (v2.1):**
- `scan-state.json` uses file-lock `.session.lock` (per-project).
- Helper enforces atomic write — không có advisory lock riêng cho ledger.
- Standalone sub-skill run: helper acquire lock → write → release → không conflict với orchestrator vì orchestrator không chạy đồng thời.

**Migration timeline:**
- Phase D: Sub-skill procedures updated to use helper.
- Phase I: E2E test standalone sub-skill run (fallback from v4.1 ledger.json).
- Phase J: Docs + user guide.
- Post-v5.0: ledger.json vẫn generate để downstream skills legacy không break. Deprecation schedule cho ledger.json sẽ trong v5.1 khi downstream skills update.

### 1.4 Migration Helper (from v4.1 ledger.json)

```
scan-state.json ← ledger.json:
  session.id ← ledger.summary.session_id (if present) else timestamp
  session.strategy ← ledger.strategy.id
  session.maturity_level ← ledger.maturity.level
  layers.L*.status ← ledger.stages.*.status
  depth_map ← derived from ledger.maturity.stage_modes
```

One-shot helper script: `scripts/migrate-ledger-to-scan-state.sh`.

---

## 2. Output Schemas

### 2.1 domain-hints.json (NEW)

```json
{
  "$schema": "domain-hints-v1",
  "detected_domains": [
    {
      "domain": "finance",
      "confidence": 0.85,
      "signals": [
        {"type": "package_dep", "value": "decimal.js", "weight": 0.3},
        {"type": "directory_name", "value": "billing/", "weight": 0.4},
        {"type": "import_pattern", "value": "invoice|payment|tax", "weight": 0.15}
      ],
      "recommended_expert": "finance-expert",
      "recommended_agent_type": "finance-expert"
    }
  ],
  "unresolved_patterns": ["erp", "custom-orm"],
  "all_signals": {
    "package_deps": ["decimal.js", "xlsx", "pdfkit"],
    "directory_names": ["billing", "invoices", "payments"],
    "import_patterns": ["invoice", "payment", "tax", "receipt"],
    "file_patterns": ["*.ledger.ts", "*.statement.ts"]
  },
  "scan_time": "2026-04-22T10:00:22Z"
}
```

**Detection sources (consolidated):**

| Source | Pattern example | Weight | Detected by |
|--------|-----------------|--------|-------------|
| Package dependency | `decimal.js`, `money.js` → finance | 0.2-0.3 | L1 bash |
| Directory name | `billing/`, `auth/` | 0.3-0.5 | L1 bash |
| Import pattern | `invoice\|payment\|tax` | 0.1-0.2 | L2 bash (grep sample) |
| File pattern | `*.ledger.ts`, `*.patient.ts` | 0.2-0.3 | L2 bash |
| Framework detect | `healthcare-fhir` → healthcare | 0.5-0.7 | L1 bash |

**Confidence thresholds (v2.1 — aligned với 09-thresholds-justification.md §2.1):**
- **≥0.75**: Strong match → auto-route domain expert (extract target confidence ≥0.8). Optional 7 expert extensions trigger tại ngưỡng này.
- **0.6-0.74**: Moderate match → route Core 7 domain expert, monitor confidence. Env var `LEGACY_SCAN_DOMAIN_MIN` (default 0.6) override.
- **<0.6**: Weak match → fallback `business-analyst` only (skip domain expert — tiết kiệm tokens + tránh wrong expert).

> **v2.1 change:** Threshold raised từ 0.4 → 0.6. Lý do: fixture test medium project phát hiện 0.4 gây 30% modules routed wrong expert (domain "operations" confidence 0.42 thực ra là "logistics"). Correctness cost > efficiency cost — xem ADR-LS16 + 09-thresholds-justification.md.
>
> **Auto-fix fallback:** Nếu domain-expert extract confidence < threshold (0.6 standard / 0.8 deep) → retry simplified prompt (max 2x) → fallback `business-analyst` only + WARN.

**Consumers (fix B5):**
- IPS Phase A (read + update confidence during assessment enrichment)
- L4 Classification (deep depth — domain expert glossary enrichment)
- L5 Extraction (module routing for domain expert spawn)
- `/wf-legacy-extract` (downstream sub-skill — read for agent selection)
- `/wf-design` (legacy flow — domain context for architecture)

### 2.2 impact-graph.json (NEW — ADR-LS14)

```json
{
  "$schema": "impact-graph-v1",
  "synthesis_mode": "full+insights",
  "generated_at": "2026-04-22T10:45:00Z",
  "nodes": [
    {
      "id": "crm/customer",
      "type": "module",
      "files_count": 12,
      "feat_ids": ["FEAT-CRM-CUST-001", "FEAT-CRM-CUST-002"],
      "domain": "sales",
      "coupling_score": 0.72
    }
  ],
  "edges": [
    {
      "from": "crm/customer",
      "to": "finance/ar",
      "relation": "data_dependency",
      "evidence": "invoice.customer_id FK → customer.id",
      "strength": 0.9,
      "probe_source": "schema_parse"
    },
    {
      "from": "crm/customer",
      "to": "reporting/sales",
      "relation": "entity_reference",
      "strength": 0.6,
      "probe_source": "import_analysis"
    }
  ],
  "circular_dependencies": [],
  "orphan_modules": [],
  "summary": {
    "total_nodes": 8,
    "total_edges": 14,
    "avg_fanout": 1.75,
    "max_fanout": 4
  }
}
```

**Relation types:**
- `code_import` — AST import/export
- `data_dependency` — FK / schema reference
- `event_subscription` — event bus / decorator
- `api_call` — REST/gRPC call (runtime trace)
- `req_cross_ref` — `USES: REQ-X` comment annotation
- `entity_reference` — entity name reference without strict FK

**Consumers:**
- `/wf-verify-sync` — cross-module REQ-ID validation (R5 ripple)
- `/wf-fix-bugs` R5 ripple verification (downstream fix impact)
- `/wf-design` (legacy flow) — gap analysis priority

### 2.3 Existing Output Schemas (unchanged)

Giữ nguyên schema:

- `project-profile.json` (+ thêm optional `domain_hints` field)
- `assessment-report.json` (+ thêm optional `stale_threshold_days`, `domain_enrichment` fields)
- `inventory/*.json` (7 files, unchanged)
- `classified/*.json` (unchanged)
- `extracted/*.json` (unchanged)
- `module-code-mapping.json` (unchanged)
- `glossary.json` (unchanged)
- `project-context.md` (unchanged format, content depth varies by synthesis_mode)
- `doc-quality-map.json` (unchanged)
- `impl-status-snapshot.json` (unchanged; skip if synthesis_mode=condensed)

---

## 3. Cross-Skill Output Path Contract Updates

### 3.1 New Paths (additions to `00-core.md §4b`)

| Producer | Output Path | Consumer |
|----------|-------------|----------|
| wf-legacy-scan L2 | `.mc-data/work/legacy-scan/domain-hints.json` | IPS, L4, L5, `/wf-legacy-extract`, `/wf-design` |
| wf-legacy-scan L6 | `.mc-data/work/legacy-scan/impact-graph.json` | `/wf-verify-sync`, `/wf-fix-bugs`, `/wf-design` |
| wf-legacy-scan (session) | `.mc-data/work/legacy-scan/sessions/{id}/scan-state.json` | wf-legacy-scan `--resume` |
| wf-legacy-scan (session) | `.mc-data/work/legacy-scan/sessions/{id}/scan-plan.md` | User observability |
| wf-legacy-scan (session) | `.mc-data/work/legacy-scan/sessions/{id}/session-log.json` | CORE-026 observability |
| wf-legacy-scan (workload) | `.mc-data/work/legacy-scan/workloads/{workload-id}/fix-workload.json` | Multi-session chunks |
| wf-legacy-scan (cache session) | `.mc-data/work/legacy-scan/sessions/{id}/cache/` | Cache hit checks |
| wf-legacy-scan (cache project) | `.mc-data/cache/wf-legacy-scan/probes/` | Team collaboration (opt-in git) |

### 3.2 Updated Paths

| Producer | Output Path | Change |
|----------|-------------|--------|
| wf-legacy-scan L1 | `.mc-data/work/legacy-scan/project-profile.json` | Add `domain_hints` field (optional) |
| wf-legacy-scan L2 | `.mc-data/work/legacy-scan/assessment-report.json` | Add `stale_threshold_days`, `domain_enrichment` fields (optional) |
| wf-legacy-scan (backward-compat) | `.mc-data/work/legacy-scan/ledger.json` | Generated ONCE bởi orchestrator at POST Phase 4 synthesize (v2.1 — no reverse-sync). Read-only legacy projection cho downstream skills. |

### 3.3 Unchanged Paths

Tất cả paths khác trong `00-core.md §4b` liên quan đến wf-legacy-scan **giữ nguyên**:
- inventory files → `.mc-data/work/legacy-scan/inventory/`
- classified files → `.mc-data/work/legacy-scan/classified/`
- extracted files → `.mc-data/work/legacy-scan/extracted/`
- project-context.md → `.mc-data/work/legacy-scan/project-context.md`
- doc-quality-map.json, impl-status-snapshot.json → unchanged
- All downstream consumer paths unchanged

---

## 4. Agent Communication Contract

### 4.1 L4 Classification Agent

**Agent type:** `code-reviewer` (spawned directly, NOT via `general-purpose` wrapper — fix PB-2).

**Input (via prompt):**
- Inventory summary (file counts, categories)
- Batch of files to classify (paths + metadata)
- Existing classification (if delta mode)
- Glossary (if exists from previous run)
- IPS domain hints (if applicable)
- Depth level (standard/deep)
- Naming convention rules (CORE-016/017)

**Output (written to disk):**
- `classified/batch-N.json` — file-to-module assignments
- Format per entry: `{path, system, module, category, confidence}`

**POST-GATE validation (main context):**

```bash
# Coverage check
TOTAL=$(jq -s '[.[].files | length] | add' classified/batch-*.json)
CLASSIFIED=$(jq -s '[.[] | .files | length] | add' classified/batch-*.json)
COVERAGE=$(awk "BEGIN {printf \"%.2f\", $CLASSIFIED / $TOTAL}")
echo "Coverage: $COVERAGE"
# Fail if < 0.95

# Naming check (CORE-016/017)
jq -r '.files[].module' classified/batch-*.json | grep -vP '^[a-z][a-z0-9-]*$' && echo "FAIL: non-kebab-case"

# Confidence check
jq '[.files[] | select(.confidence < 0.5)] | length' classified/batch-*.json
# Warn if any
```

### 4.2 L5 Extraction Agents

**Agent types:**
- Primary: `business-analyst` (always spawned for every module)
- Secondary: domain-expert matching `scan-state.ips.phase_b.module_routing` (spawned if domain confidence **≥0.6** — v2.1 raised từ 0.4) — BACKWARD-COMPAT v4.1

**Input (via prompt):**
- Module name + classified files
- Domain hints (if applicable)
- Glossary
- Dependency relationships
- Template path for output format
- Depth level (standard/deep)
- Confidence threshold

**Output (written to disk):**
- `extracted/{module-slug}.json` — requirements, features, acceptance criteria
- Format: per `extracted-module.json` template schema

**POST-GATE validation:**

```bash
# Confidence check (threshold: standard ≥0.6, deep ≥0.8)
AVG_CONF=$(jq '[.requirements[].confidence] | add / length' extracted/module-a.json)
# Fail if below threshold

# TMP-ID format check
jq -r '.requirements[].id' extracted/module-a.json | grep -vP '^TMP-REQ-' && echo "FAIL: invalid TMP-REQ format"

# Source files check (CORE-024)
jq -e '.requirements[] | select(.source_files | length == 0)' extracted/module-a.json && echo "FAIL: requirements missing source_files"
```

---

## 5. Template Paths (CORE-031)

Mọi output file phải tạo từ template. Template locations:

### 5.1 Templates — Existing (already in current templates/)

| Output File | Template Path | Status |
|-------------|---------------|--------|
| `project-profile.json` | `.claude/skills/workflow/wf-legacy-scan/templates/project-profile.json` | ✅ Existing (schema ref) |
| `assessment-report.json` | `.claude/skills/workflow/wf-legacy-scan/templates/assessment-report.json` | ✅ Existing |
| `ledger.json` | `.claude/skills/workflow/wf-legacy-scan/templates/ledger.json` | ✅ Existing (backward-compat) |
| `session-digest.md` | `.claude/skills/workflow/wf-legacy-scan/templates/session-digest.md` | ✅ Existing |
| `error-ledger.json` | `.claude/skills/workflow/wf-legacy-scan/templates/error-ledger.json` | ✅ Existing |
| `project-context.md` | `.claude/skills/workflow/wf-legacy-scan/templates/project-context.md` | ✅ Existing (update for synthesis_mode) |
| `doc-quality-map.json` | `.claude/skills/workflow/wf-legacy-scan/templates/doc-quality-map.json` | ✅ Existing |
| `impl-status-snapshot.json` | `.claude/skills/workflow/wf-legacy-scan/templates/impl-status-snapshot.json` | ✅ Existing |
| `legacy-scan-plan.md` | `.claude/skills/workflow/wf-legacy-scan/templates/legacy-scan-plan.md` | ✅ Existing (rename to scan-plan.md in v5.0) |
| `legacy-scan-status.json` | `.claude/skills/workflow/wf-legacy-scan/templates/legacy-scan-status.json` | ✅ Existing (deprecate in favor of scan-state.json) |
| `inventory/*.json` | `.claude/skills/workflow/wf-legacy-scan/templates/inventory/*.json` | ✅ Existing (8 files) |
| `legacy-scan-contract.json` | `.claude/skills/workflow/wf-legacy-scan/templates/legacy-scan-contract.json` | ✅ Existing |
| `legacy-pipeline-contract.json` | `.claude/skills/workflow/wf-legacy-scan/templates/legacy-pipeline-contract.json` | ✅ Existing |

### 5.2 Templates — NEW (to be created)

| Output File | Template Path | Status |
|-------------|---------------|--------|
| `scan-state.json` | `.claude/skills/workflow/wf-legacy-scan/templates/scan-state.json` | 🆕 NEW (§1 schema) |
| `domain-hints.json` | `.claude/skills/workflow/wf-legacy-scan/templates/domain-hints.json` | 🆕 NEW (§2.1 schema) |
| `impact-graph.json` | `.claude/skills/workflow/wf-legacy-scan/templates/impact-graph.json` | 🆕 NEW (§2.2 schema) |
| `phase-summary.md` | `.claude/skills/workflow/wf-legacy-scan/templates/phase-summary.md` | 🆕 NEW (CORE-028) |
| `scan-plan.md` | `.claude/skills/workflow/wf-legacy-scan/templates/scan-plan.md` | 🆕 NEW (replaces legacy-scan-plan.md semantically; can alias for backward-compat) |
| `fix-workload.json` | `.claude/skills/workflow/wf-legacy-scan/templates/fix-workload.json` | 🆕 NEW (tái dùng schema từ wf-fix-bugs) |
| `events.jsonl` | (no template — append-only) | 🆕 NEW (JSONL format) |

**Flow:** READ template → POPULATE session-specific data → WRITE to `$SESSION_DIR/` or standard output path → validate with `jq`.

---

## 6. Session Data Lifecycle

### 6.1 Session Creation

```bash
SESSION_ID=$(date -u +"%Y-%m-%dT%H-%M-%S")
SESSION_DIR=".mc-data/work/legacy-scan/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR/layers"
flock_acquire ".mc-data/work/legacy-scan/.session.lock" || abort "Another session active"
```

### 6.2 Session Data Matrix

| Data | Location | Lifecycle |
|------|----------|-----------|
| `scan-state.json` | `$SESSION_DIR/` | Created at init, updated per layer transition + checkpoint |
| `scan-plan.md` | `$SESSION_DIR/` | Created at init (from template) |
| `session-digest.md` | `$SESSION_DIR/` | Created at finalize |
| `phase-summary.md` | `$SESSION_DIR/` | Created at finalize (CORE-028) |
| `session-log.json` | `$SESSION_DIR/` | Append-only: START/COMPLETE/FAIL per layer (CORE-026) |
| `error-ledger.json` | `$SESSION_DIR/` | Append-only during run |
| `events.jsonl` | `$SESSION_DIR/` | Append-only: agent spawn/complete events |
| `layers/L*/partial.json` | `$SESSION_DIR/layers/L*/` | L3 checkpoint (intra-batch/intra-module) |
| Cache | `$SESSION_DIR/cache/` | Ephemeral, gitignored |
| Output data | `.mc-data/work/legacy-scan/` (standard) | Overwritten per run (backward-compat) |

### 6.3 Session Cleanup

- Sessions không tự xóa — giữ cho audit trail
- Manual cleanup: `--clean-sessions` flag xóa sessions cũ hơn N ngày
- Default retention: 30 ngày
- Compliance mode: `--retain-all` (không cleanup — cho ERP tài chính cần audit SOX)

### 6.4 Session Selection (--resume)

```
Khi --resume không chỉ định session ID:
1. List sessions/ directories by mtime descending
2. Find latest with status ∈ {in_progress, paused, failed}
3. IF completed → "Session already completed. Dùng --status để xem."
4. IF no in_progress → "No resumable session found. Start new with /wf-legacy-scan."
5. IF in_progress → Resume from that session

Khi --resume --session=ID:
1. Check session exists at sessions/{ID}/
2. Validate scan-state.json integrity (jq -e)
3. Resume from specified session
```

---

## 7. Scan Cache Schema

### 7.1 Cache Entry Format

```json
{
  "$schema": "scan-cache-entry-v1",
  "fingerprint": "sha256:ab12cd34...",
  "probe_id": "L3.inventory",
  "probe_version": "1.0",
  "input": {
    "files": ["src/billing/invoice.ts"],
    "input_hash": "sha256:ef56...",
    "dep_closure_hash": "sha256:gh78..."
  },
  "config": {
    "depth": "standard",
    "batch_size": 100
  },
  "config_hash": "sha256:ij90...",
  "output": {
    "type": "inline | file_ref",
    "data": {...},
    "file_ref": "classified/batch-003.json"
  },
  "produced_at": "2026-04-22T10:15:00Z",
  "produced_by": "user@host",
  "ttl_days": 14,
  "privacy_scope": "internal",
  "invalidation_hints": ["file_hash_change", "probe_config_change"]
}
```

### 7.2 Fingerprint Computation

```
fingerprint = SHA256(
  probe_id ||
  probe_version ||
  depth_level ||
  config_hash ||
  input_file_hashes ||
  dep_closure_hash
)
```

- `probe_id`: stable probe identifier (e.g., `L3.inventory.screens`)
- `probe_version`: bumped on probe logic change
- `config_hash`: SHA of relevant config (depth, batch_size, caps)
- `input_file_hashes`: SHA of input files (sorted, concatenated)
- `dep_closure_hash`: SHA of transitive imports (2 level max, whitelist extensions)

### 7.3 Cache Lookup Flow

```python
def cache_lookup(probe_id, input_files):
    fingerprint = compute_fingerprint(probe_id, input_files, config)
    
    # 1. Check session cache (fastest)
    if session_cache.has(fingerprint):
        return session_cache.get(fingerprint)
    
    # 2. Check project cache (git-shared)
    if project_cache_enabled and project_cache.has(fingerprint):
        entry = project_cache.get(fingerprint)
        # Validate not expired
        if not expired(entry):
            # Promote to session cache
            session_cache.set(fingerprint, entry)
            return entry
    
    # 3. Cache miss → run probe
    result = probe.run(input_files)
    session_cache.set(fingerprint, result)
    if project_cache_enabled:
        project_cache.set(fingerprint, result)
    return result
```

### 7.4 Invalidation Rules

| Rule | Trigger | Scope |
|------|---------|-------|
| File hash change | Input file SHA differs | Matching fingerprints |
| Dep closure change | Transitive import SHA differs | Matching fingerprints |
| Probe version bump | `probe_version` incremented | All for that probe |
| Config change | `config_hash` differs | Config-scoped entries |
| TTL expire | `produced_at + ttl_days` < now | Expired entries |
| User force | `--no-cache` | Current session |
| User pattern | `--invalidate-cache=<pattern>` | Matching pattern |

---

## 8. Workload Schema (fix-workload.json — NEW)

```json
{
  "$schema": "fix-workload-v1",
  "workload_id": "wl-erp-20260422-001",
  "skill": "wf-legacy-scan",
  "strategy": "by-module",
  "target_scope": {
    "project_path": "/path/to/erp"
  },
  "dims": null,
  "profile": "deep",
  "created_by": "user@erktransport.com",
  "created_at": "2026-04-22T09:30:00+07:00",
  "chunks": [
    {
      "chunk_id": "ch-001",
      "label": "billing",
      "scope": { "modules": ["billing", "invoice"] },
      "est_time_minutes": 55,
      "dependencies": [],
      "status": "pending | in_progress | done | failed | stale",
      "assigned_to": null,
      "session_dir": null,
      "started_at": null,
      "completed_at": null,
      "output_hash": null
    }
  ],
  "aggregate": {
    "status": "pending | in_progress | done",
    "started_at": null,
    "completed_at": null,
    "output_dir": null
  },
  "coverage_target": "100%",
  "dedup_key_strategy": "tmp_req_hash_v1"
}
```

**Chunk state machine:**

```
pending → in_progress (acquire lock) → done
                                    ↘ failed (retry or escalate)
                                    ↘ stale (timeout 2× est_time — release for pick)
```

---

## 9. Error Ledger Schema

```json
{
  "$schema": "error-ledger-v1",
  "session_id": "2026-04-22T10-00-00",
  "errors": [
    {
      "timestamp": "2026-04-22T10:15:30Z",
      "code": "E-L4-01",
      "layer": "L4",
      "severity": "error | warning | info",
      "message": "Classification coverage 85% (<95% threshold)",
      "context": {
        "batch": 3,
        "uncovered_files": ["src/util/helper.ts", "..."]
      },
      "retry_count": 2,
      "resolution": "auto_fix_succeeded | auto_fix_failed | escalated | skipped"
    }
  ]
}
```
