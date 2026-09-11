# 03 — Kiến Trúc Adaptive Scan

> **Đọc trước:** [02-scan-layers.md](02-scan-layers.md)
> **Đọc tiếp:** [04-data-model.md](04-data-model.md)

---

## 1. Component Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    wf-legacy-scan SKILL.md                            │
│                    (Orchestrator — Main Context)                      │
│                                                                      │
│  ┌─────────┐  ┌──────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  IPS    │  │ Profile  │  │   Resume     │  │   Workload      │   │
│  │ Engine  │  │ Resolver │  │   Router     │  │     Gate        │   │
│  │ (2-phase)│ │          │  │ (4-level)    │  │                 │   │
│  └────┬────┘  └────┬─────┘  └──────┬───────┘  └────────┬────────┘   │
│       │            │               │                    │            │
│  ┌────▼────────────▼───────────────▼────────────────────▼────────┐  │
│  │              Scan Execution Engine                              │  │
│  │                                                                │  │
│  │  L1 ──bash──► L2+IPS-A ──bash──► L3+IPS-B ──bash──►            │  │
│  │                                          L4 ──agent──►         │  │
│  │                                          L5 ──agent──►         │  │
│  │                                          L6 ──main──►          │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │         Concurrency Controller (3-tier token bucket)         │    │
│  │  global_max=8 · per_layer=3 · per_probe=4 · reserve=2        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │         State Manager                                        │    │
│  │  scan-state.json (canonical) ── generate ledger.json (1x POST-P4)  │    │
│  │  sessions/{id}/ ◄── file-lock isolation                     │    │
│  │  4-level checkpoint (phase/layer/batch/intra-batch)         │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │         Scan Cache Manager                                   │    │
│  │  Session cache (ephemeral) + Project cache (git-friendly)   │    │
│  │  Content-addressable fingerprint + invalidation rules       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.1 Components

| Component | Vai trò | Chạy trong | Mới/Tái dùng |
|-----------|---------|-----------|------------|
| **Orchestrator** | SKILL.md — điều phối layers, enforce POST-GATE | Main context | Tái dùng v4.1 (upgrade) |
| **IPS Engine** | Intelligent Pre-Scan 2-phase — phase A sau L2, phase B sau L3 | Main context | **MỚI** (tương tự wf-fix-bugs ISG) |
| **Profile Resolver** | Map profile + user flags → depth_map | Main context Phase 0 | **MỚI** |
| **Resume Router** | Đọc scan-state.json → route đến resumption point (4 cấp) | Main context `--resume` | Tái dùng (upgrade 4-level) |
| **Workload Gate** | Ước lượng workload, đề xuất chia chunks | Main context sau IPS-A | **MỚI** (tương tự wf-fix-bugs Workload Gate) |
| **State Manager** | scan-state.json canonical transitions + generate ledger.json 1x POST-Phase 4 (v2.1 — no reverse-sync) | Main context | **MỚI** (thay 3-file fragmented) |
| **Concurrency Controller** | Token bucket 3-tier cho parallel agents | Main context | **MỚI** (tương tự wf-fix-bugs controller) |
| **Scan Cache Manager** | Content-addressable cache + invalidation | Main context + bash helper | **MỚI** (tương tự wf-fix-bugs scan cache) |
| **Bash Scripts** | L1 (detect), L2 (assess), L3 (inventory) | Sub-process | Tái dùng v4.1 (refactor với shared library) |
| **Agent Delegation** | L4 (classify), L5 (extract) | Agent tool | Tái dùng v4.1 (upgrade — truyền domain + depth context) |

---

## 2. Execution Flow

### 2.1 Normal Flow (không --resume, không --workload)

```
Phase 0: Init
  ├── Parse arguments (--profile, --layers, --depth, --status, --resume, --incremental, ...)
  ├── Acquire file-lock: .mc-data/work/legacy-scan/.session.lock
  │   └── IF lock busy → WARN + hiển thị session owner + AskUserQuestion: wait/kill/abort
  ├── Create session: sessions/{timestamp-id}/
  ├── Initialize scan-state.json (from template)
  ├── Resolve profile → depth_map {L1-L3: full, L4: depth, L5: depth, L6: synthesis_mode}
  └── Load strategy routing (if previous scan exists → verify consistency)

Phase 1: L1 Discovery (deterministic)
  ├── Invoke legacy-scan-detect.sh → project-profile.json (preliminary domain-hints embedded)
  ├── POST-GATE L1 (T1-T4)
  └── Update scan-state.layers.L1 = completed + Write layer checkpoint

Phase 2: L2 Assessment + IPS-A (deterministic + inline)
  ├── Invoke legacy-scan-assess.sh → assessment-report.json (enriched domain-hints)
  ├── POST-GATE L2 (T1-T4)
  ├── IPS-A inline: analyze signals → scan-state.ips.phase_a {recommended_profile, detected_domains}
  ├── IF --profile not specified:
  │   ├── AskUserQuestion with IPS-A recommendation (CORE-027 CDG)
  │   └── User selects profile → update depth_map
  ├── Workload Gate:
  │   ├── IF estimated_workload > threshold → hiển thị Workload Gate (CORE-027 CDG)
  │   └── User chooses: continue / partition / downgrade profile / abort
  └── Update scan-state.layers.L2 = completed + checkpoint

Phase 3: L3 Inventory + IPS-B (deterministic + inline)
  ├── Invoke legacy-scan-inventory.sh → inventory/*.json (with scan cache check)
  ├── POST-GATE L3 (T1-T4 with tolerance)
  ├── IPS-B inline: analyze inventory → scan-state.ips.phase_b {module_routing, complexity_hotspots}
  └── Update scan-state.layers.L3 = completed + checkpoint

Phase 4: L4 Classification (adaptive depth)
  ├── IF depth_map.L4 == "surface" → heuristic grouping inline (main context)
  ├── IF depth_map.L4 == "standard":
  │   ├── Batch files (batch_size from scan-state.config)
  │   ├── Concurrency Controller.acquire(per_layer=3)
  │   ├── Per batch:
  │   │   ├── Spawn code-reviewer agent (subagent_type="code-reviewer" — NOT general-purpose)
  │   │   ├── Agent prompt includes IPS domain hints + depth context (§5)
  │   │   ├── Main context POST-GATE validate (không trust agent)
  │   │   ├── Checkpoint L2 (batch N/total)
  │   │   └── Intra-batch checkpoint L3 (files processed per batch)
  │   └── Concurrency Controller.release
  ├── IF depth_map.L4 == "deep": same + domain-expert review step
  ├── POST-GATE L4 (T1-T4 coverage ≥95%)
  └── Update scan-state.layers.L4 = completed + checkpoint

Phase 5: L5 Extraction (adaptive depth)
  ├── IF depth_map.L5 == "skip" → mark L5 skipped_by_profile + jump to Phase 6
  ├── IF depth_map.L5 in ["standard", "deep"]:
  │   ├── Prepare module list from L4 classification
  │   ├── Sort topological (from dependency-graph)
  │   ├── Group independent modules (max 3 parallel groups)
  │   ├── Concurrency Controller.acquire(per_layer=3, per_probe=4)
  │   ├── Per group (parallel):
  │   │   ├── Per module:
  │   │   │   ├── Resolve domain-expert from scan-state.ips.phase_b.module_routing
  │   │   │   ├── Spawn business-analyst agent (primary)
  │   │   │   ├── IF domain match ≥0.6: spawn domain-expert agent (secondary) — BACKWARD-COMPAT v4.1
  │   │   │   ├── Agent prompts include IPS hints + depth context (§5)
  │   │   │   ├── Main context POST-GATE validate
  │   │   │   ├── Intra-module checkpoint L3 (feature N/total)
  │   │   │   └── Checkpoint L2 (module done)
  │   │   └── Sync between groups
  │   └── Concurrency Controller.release
  ├── POST-GATE L5 (avg_confidence ≥ threshold)
  └── Update scan-state.layers.L5 = completed + checkpoint

Phase 6: L6 Synthesis (main context)
  ├── Generate project-context.md per synthesis_mode
  ├── Generate doc-quality-map.json
  ├── Generate impl-status-snapshot.json (skip if synthesis_mode=condensed)
  ├── Build impact-graph.json (skip if synthesis_mode=condensed)
  ├── POST-GATE L6 (T1-T4)
  └── Update scan-state.status = completed

Phase 7: Finalize
  ├── Generate phase-summary.md (CORE-028)
  ├── Generate session-digest.md (~300 words)
  ├── Update session-log.json (CORE-026 — START/COMPLETE events)
  ├── Reverse-sync scan-state.json → ledger.json (backward-compat sub-skills)
  ├── Release file-lock
  └── Display summary to user
```

### 2.2 Resume Flow (4-Level Routing)

```
/wf-legacy-scan --resume
  ├── Find latest session: sessions/ → sort by mtime → pick latest in_progress
  ├── Read scan-state.json
  ├── Acquire file-lock (should be unlocked after previous session crash)
  ├── 4-Level Resume Router:
  │   ├── L0 Phase: đọc scan-state.last_completed
  │   ├── L1 Layer: if status=in_progress, load layer checkpoint
  │   ├── L2 Batch/Module: load batch_progress or module_progress
  │   └── L3 Intra-batch/module: load partial.json
  ├── Restore depth_map + strategy from state
  ├── Skip completed layers
  └── Resume from first incomplete unit (finest granularity)
```

**Resume routing table:**

| scan-state.last_completed | Resume strategy |
|--------------------------|-----------------|
| `init` | Start L1 từ đầu |
| `L1` | Start L2 (re-run IPS-A) |
| `L2` | Start L3 |
| `L3` | Start L4 (re-run IPS-B if missing) |
| `L4` (status=in_progress, batch=N) | Resume L4 batch N (L2 checkpoint) |
| `L4` (status=in_progress, batch=N, partial=file-M) | Resume L4 batch N file M+1 (L3 checkpoint) |
| `L4` (status=completed) | Start L5 |
| `L5` (status=in_progress, module=X) | Resume L5 module X (L2 checkpoint) |
| `L5` (status=in_progress, module=X, partial=feature-Y) | Resume L5 module X feature Y+1 (L3 checkpoint) |
| `L5` (status=completed) | Start L6 |
| `L6` | Resume L6 (regenerate from L1-L5 data) |
| `completed` | "Session already completed. Use --status to view." |

---

## 3. Session Layout

```
.mc-data/work/legacy-scan/
├── .session.lock                          ← File-lock (concurrent protection)
├── sessions/
│   ├── 2026-04-22T10-00-00/              ← Session 1
│   │   ├── scan-state.json               ← Unified state (canonical)
│   │   ├── scan-plan.md                  ← Execution plan per session
│   │   ├── session-digest.md             ← ~300 word summary
│   │   ├── phase-summary.md              ← CORE-028
│   │   ├── session-log.json              ← CORE-026 START/COMPLETE events
│   │   ├── error-ledger.json             ← Error tracking per session
│   │   └── layers/
│   │       ├── L4/partial.json          ← L3 checkpoint (intra-batch)
│   │       └── L5/partial.json          ← L3 checkpoint (intra-module)
│   ├── 2026-04-22T14-30-00/              ← Session 2 (re-scan)
│   │   └── ...
│   └── ...
├── inventory/                             ← Output data (standard location)
│   ├── screens.json
│   ├── api-endpoints.json
│   ├── source-files.json
│   ├── dependency-graph.json
│   ├── doc-files.json
│   ├── external-docs.json
│   ├── ui-manifest.json                   (conditional)
│   └── doc-classified.json                (DOCS_ONLY)
├── classified/                            ← Output data
│   ├── batch-*.json
│   ├── auto-grouped.json                  (surface profile only)
│   ├── glossary.json
│   ├── classify-naming-fixes.json
│   └── module-review.json                 (deep profile only)
├── extracted/                             ← Output data
│   ├── {module-slug}.json
│   ├── {module-slug}-divergences.json    (exhaustive profile)
│   ├── dedup-report.json
│   └── module-code-mapping.json
├── project-profile.json                   ← Output data (shared)
├── assessment-report.json                 ← Output data (shared)
├── domain-hints.json                      ← Output data (NEW)
├── ledger.json                            ← Legacy compat (generated 1x from scan-state at POST Phase 4 — v2.1)
├── project-context.md                     ← LEGACY_MODE anchor (CORE-021)
├── doc-quality-map.json                   ← Output data
├── impl-status-snapshot.json              ← Output data
└── impact-graph.json                      ← Output data (NEW)
```

**Key design decisions:**
- **Session directories** chỉ chứa runtime state (scan-state, plan, digest, log, error) + partial.json L3 checkpoints.
- **Output data** tại standard location (backward compat với downstream skills).
- **ledger.json** generate từ scan-state.json **1 lần** bởi orchestrator tại POST Phase 4 synthesize (v2.1 change — ADR-LS04 revised). Sub-skills KHÔNG ghi ledger.json — đọc+ghi scan-state.json trực tiếp qua helper. Chi tiết xem [04-data-model.md §1.3](04-data-model.md).
- **File-lock** ngăn concurrent session corrupt state.
- **Scan cache** lưu riêng: `.mc-data/work/legacy-scan/sessions/{id}/cache/` (ephemeral) + `.mc-data/cache/wf-legacy-scan/` (opt-in git).

---

## 4. IPS Engine Design (2-Phase)

### 4.1 IPS Phase A (sau L2)

**Purpose:** Recommend profile + detect domains từ aggregate signals.

**Signals:**

| Signal Source | Dữ liệu | Hints |
|--------------|---------|-------|
| `project-profile.json` | Languages, frameworks, file counts | Tech stack, project size |
| `assessment-report.json` | Maturity, scores | Strategy routing, complexity |
| `project-profile.json` | Package dependencies | Domain detection |
| Directory top-level | `/billing/`, `/auth/`, `/inventory/` | Domain, module boundaries |
| Import patterns (sampled L1) | Top imports | Domain, architecture pattern |
| File naming patterns | `*.controller.ts`, `*.service.ts` | Architecture pattern |

**Output:** `scan-state.ips.phase_a`

```json
{
  "recommended_profile": "deep",
  "profile_reasoning": "Large project (1,200 files) + 2 domains detected (finance 0.85, logistics 0.72)",
  "detected_domains": [
    {"domain": "finance", "confidence": 0.85, "recommended_agent": "finance-expert"},
    {"domain": "logistics", "confidence": 0.72, "recommended_agent": "logistics-expert"}
  ],
  "unresolved_patterns": ["erp", "custom-orm"],
  "warnings": ["Circular dep suspect in finance ↔ invoice modules"]
}
```

### 4.2 IPS Phase B (sau L3)

**Purpose:** Refine module routing + complexity hotspots từ file-level data.

**Signals:**

| Signal Source | Dữ liệu | Hints |
|--------------|---------|-------|
| `inventory/source-files.json` | File list per directory | Module size estimate |
| `inventory/dependency-graph.json` | Import edges | Coupling estimate |
| `inventory/screens.json` | UI screen list | UI complexity |
| `inventory/api-endpoints.json` | API route list | API surface area |

**Steps:**

```
1. Cluster files by directory → estimate module count
2. Count files per module → size tiers (SMALL/MEDIUM/LARGE)
3. Compute import density per module → coupling score
4. Identify hotspots (top 20% files by size or coupling)
5. Refine module → domain routing:
   - Match file contents against domain keywords
   - Confidence boost for modules with multiple strong signals
6. Workload estimate:
   - total_features ≈ Σ(module_files × feature_density_factor)
   - estimated_time_min = f(total_features, depth)
7. IF estimated_time > soft_cap(profile) → flag Workload Gate
```

**Output:** `scan-state.ips.phase_b`

```json
{
  "module_routing": {
    "billing": {"domain": "finance", "expert": "finance-expert", "confidence": 0.88},
    "customer": {"domain": "sales", "expert": "sales-expert", "confidence": 0.72},
    "shipment": {"domain": "logistics", "expert": "logistics-expert", "confidence": 0.81}
  },
  "complexity_hotspots": [
    {"module": "billing", "files": 45, "reason": "high file count + high coupling", "priority": "high"}
  ],
  "workload_estimate": {
    "total_features_est": 127,
    "est_time_min": 75,
    "soft_cap_min": 40,
    "exceeds_cap": true,
    "ratio": 1.87
  }
}
```

### 4.3 IPS User Interaction (sau phase A)

Khi `--profile` không được chỉ định:

```
📊 Phân tích ban đầu hoàn tất

Dự án: <name>
Kích thước: 1,200 files (TypeScript, .NET, React)
Maturity: CODE_PLUS_EXTERNAL_DOCS
Domain phát hiện: finance (0.85), logistics (0.72)

Khuyến nghị: deep profile
  Lý do: Dự án lớn + 2 domain phức tạp + code quality trung bình

Chọn profile scan:
  [ ] surface — Overview nhanh (~8 min, không extraction)
  [ ] standard — Onboarding chuẩn (~35 min)
  [x] deep — Phân tích chuyên sâu (~75 min, domain experts) ← Khuyến nghị
  [ ] exhaustive — Audit toàn diện (~150 min + divergence)
  [ ] Partition workload (chia thành chunks)

[Enter]=xác nhận | [p]=đổi profile | [s]=skip (dùng standard default) | [q]=huỷ
```

---

## 5. Agent Delegation Architecture

### 5.1 L4 Classification Agent Flow

```
Main Context
  ├── Resolve depth_map.L4 from profile
  ├── Load IPS domain hints + module routing
  ├── IF surface: run heuristic grouping inline (no agent)
  ├── IF standard:
  │   ├── Prepare batches (batch_size default 100)
  │   ├── Concurrency Controller.acquire(per_layer_slots=3)
  │   ├── Per batch (up to 3 parallel):
  │   │   ├── Build prompt (§5.3 template)
  │   │   ├── Spawn code-reviewer agent (subagent_type="code-reviewer")
  │   │   │   │   NOT "general-purpose" — this is the fix for PB-2
  │   │   ├── Agent writes classified/batch-N.json
  │   │   ├── Main context POST-GATE validate:
  │   │   │   ├── Coverage ≥95%
  │   │   │   ├── Naming convention (CORE-016/017)
  │   │   │   └── Confidence >0.5 per file
  │   │   ├── IF POST-GATE fail → retry 3x with refined prompt
  │   │   └── Checkpoint L2 (batch complete)
  │   └── Concurrency Controller.release
  ├── IF deep:
  │   ├── Same as standard
  │   ├── + Spawn domain-expert per detected_domain for glossary enrichment
  │   └── + Cross-validate module boundaries
  └── Update scan-state.json
```

### 5.2 L5 Extraction Agent Flow

```
Main Context
  ├── Resolve depth_map.L5 from profile
  ├── IF skip: mark scan-state.layers.L5.status = "skipped_by_profile"
  ├── IF standard OR deep:
  │   ├── Prepare module list from L4
  │   ├── Sort topological (from dependency-graph)
  │   ├── Group independent modules (max 3 per group)
  │   ├── Concurrency Controller.acquire(global=8, per_layer=3)
  │   ├── Per group (parallel):
  │   │   ├── Per module:
  │   │   │   ├── Resolve domain-expert from IPS.phase_b.module_routing
  │   │   │   ├── Build prompts (§5.3):
  │   │   │   │   ├── business-analyst prompt (primary extraction)
  │   │   │   │   └── domain-expert prompt (secondary — BACKWARD-COMPAT v4.1)
  │   │   │   ├── Spawn agents:
  │   │   │   │   ├── Agent 1: business-analyst (subagent_type matches domain)
  │   │   │   │   └── Agent 2 (if domain match ≥0.6 — v2.1): <domain>-expert
  │   │   │   ├── IF depth=deep: add domain review + cross-validation pass
  │   │   │   ├── Main context POST-GATE:
  │   │   │   │   ├── avg_confidence ≥ threshold (standard=0.6, deep=0.8)
  │   │   │   │   ├── source_files per REQ present
  │   │   │   │   └── TMP-ID format (TMP-REQ-*)
  │   │   │   ├── IF POST-GATE fail → retry 3x simplified
  │   │   │   ├── Intra-module checkpoint L3 (per feature)
  │   │   │   └── Checkpoint L2 (module complete)
  │   │   └── Sync between groups
  │   └── Concurrency Controller.release
  └── Update scan-state.json
```

### 5.3 Agent Prompt Template

Agent prompts chứa đầy đủ context (thay vì general-purpose wrapper mù domain):

```
CONTEXT:
- Project: {project_name}
- Tech stack: {languages}, {frameworks}
- Module: {module_name} ({file_count} files)
- Domain: {detected_domain} (confidence: {domain_confidence})
- Classification summary: {module_classification_summary}
- Depth: {depth_level} (surface|standard|deep)
- Scan profile: {profile}

TASK:
{depth-specific task description from templates}

INPUT FILES:
{list of classified files for this module, with paths relative to project root}

GLOSSARY (if available):
{glossary entries relevant to this module}

DEPENDENCIES:
{modules this module depends on, for context}

OUTPUT FORMAT:
- Use template: {template_path}
- Output to: {output_path}
- Required fields: {schema_requirements}

CONSTRAINTS:
- Assign TMP-IDs (TMP-REQ-{MODULE}-{NNN})
- Include source_files for every extracted requirement (non-empty array)
- Include confidence score (0.0-1.0) for every extraction
- Language: Vietnamese for descriptions, English for IDs/names
- Depth {depth_level} specific:
  - surface: heuristic only, no AI required
  - standard: single-pass extraction, confidence ≥0.6
  - deep: multi-pass with cross-validation, confidence ≥0.8

REMINDERS:
- This is delegation from orchestrator; main context will POST-GATE validate your output.
- Do not write outside your designated output_path.
- Report any ambiguity as WARNING in output `notes` field.
```

---

## 6. Concurrency Controller Design

### 6.1 3-Tier Token Bucket

```yaml
# config/concurrency.yaml (future, currently inline in SKILL)
global_max: 8           # hard cap — tổng concurrent agents
per_layer_max: 3        # mỗi layer tối đa 3 parallel (L4 batches, L5 modules)
per_probe_max: 4        # mỗi probe fanout (if spawned)
reserved_for_synthesis: 2  # luôn giữ 2 slot cho L6 synthesis + POST-GATE
```

**Allocation:** `usable = global_max - reserved_for_synthesis = 6`.

### 6.2 Spawn Contract (CORE-025)

Một agent được phép spawn parallel CHỈ khi:

1. **Parallel-safe declared**: agent type có trong whitelist cho parallel.
2. **Write scope tách biệt**: agent ghi vào path riêng biệt (`classified/batch-N.json` unique per agent).
3. **No read-after-write cross-agent**: agent không đọc output của agent khác trong cùng group.
4. **Aggregator verify**: main context POST-GATE validate sau merge.

**Agent parallelization:**
- L4 code-reviewer: parallel-safe (mỗi batch độc lập)
- L5 business-analyst: parallel-safe giữa modules khác nhau
- L5 domain-expert: parallel-safe giữa modules khác nhau
- Agent trong cùng module (business + domain): sequential (share context)

### 6.3 Progress Events

Mỗi spawn/complete event append vào `sessions/{id}/events.jsonl`:

```
{"ts":"2026-04-22T10:15:00Z","event":"agent_spawn","layer":"L4","batch":3,"agent":"code-reviewer"}
{"ts":"2026-04-22T10:18:12Z","event":"agent_complete","layer":"L4","batch":3,"duration_ms":192000}
```

User có thể tail file này để xem tiến độ real-time.

---

## 7. Workload Gate Design

### 7.1 Trigger Conditions (từ IPS)

```
Workload Gate triggered khi bất kỳ điều kiện nào:
- estimated_time_min > 1.5 × profile.time_budget_minutes
- total_features_est > 100
- largest_module_files > 50
- modules_count > 30
- total_files > 1,000 AND profile ∈ {deep, exhaustive}
```

### 7.2 Gate UI

```
⚠️  Workload lớn phát hiện

Ước tính: 145 features × 5 modules × deep profile ≈ 150 phút
Profile budget: 75 phút (deep)
Tỷ lệ vượt budget: 2.0×

Chi tiết module:
  - billing (45 files, hotspot) — ~40 min
  - customer (32 files) — ~25 min
  - shipment (28 files) — ~22 min
  - invoice (22 files) — ~18 min
  - reporting (18 files) — ~15 min

Đề xuất phân chia:
  [ ] Plan A — Partition theo module (5 chunks, mỗi chunk ~25 min)
        Phù hợp: chạy tuần tự qua nhiều phiên
  [ ] Plan B — Partition theo domain (2 chunks: finance+billing, logistics+shipment)
        Phù hợp: chia việc cho 2 người
  [ ] Plan C — Downgrade profile deep → standard (~60 min)
        Phù hợp: chấp nhận coverage nông hơn, 1 phiên
  [x] Plan D — Giữ nguyên (chạy >2.5h một phiên — KHÔNG khuyến nghị cho ERP)
  [ ] Plan E — Huỷ (quyết định lại)

Chọn: [A] [B] [C] [D] [E]
```

### 7.3 Partition Planner Output

Nếu user chọn Plan A/B, orchestrator sinh `fix-workload.json` (tái dùng schema từ wf-fix-bugs):

```json
{
  "workload_id": "wl-erp-20260422-001",
  "skill": "wf-legacy-scan",
  "strategy": "by-module",
  "target_scope": { "project_path": "/path/to/erp" },
  "profile": "deep",
  "chunks": [
    {
      "chunk_id": "ch-001",
      "label": "billing",
      "scope": { "modules": ["billing", "invoice"] },
      "est_time_minutes": 55,
      "dependencies": [],
      "status": "pending",
      "assigned_to": null,
      "session_dir": null
    }
  ],
  "dedup_key_strategy": "tmp_req_hash_v1",
  "coverage_target": "100%"
}
```

### 7.4 Multi-Session Execution

```bash
# Terminal 1 hoặc máy A
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=ch-001

# Terminal 2 hoặc máy B (song song)
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=ch-002

# Auto-pick next available
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=next

# Sau khi tất cả chunks done:
/wf-legacy-scan --workload=wl-erp-20260422-001 --aggregate
```

**Chunk coordination:**
- Chunk start → acquire `workload.lock` để set status=in_progress atomic
- Chunk complete → release lock + update chunk.status=done
- Chunk timeout (>2× est_time) → status=stale → cho phép session khác pick lại
- Aggregate step merge all chunks' output → build unified `project-context.md` + `impact-graph.json`

---

## 8. Error Handling Architecture

### 8.1 Error Categories

| Category | Example | Recovery |
|----------|---------|----------|
| **Deterministic Error** | Bash script crash, invalid JSON | Retry script (max 2x) → STOP + suggest `--resume` |
| **Agent Error** | Agent timeout, wrong format | Retry simplified prompt (max 3x) → skip module → report gap |
| **Validation Error** | POST-GATE T1-T4 fail | Auto-fix 3x → STOP + report specific failures |
| **Context Overflow** | >90% context usage | Force checkpoint → STOP + suggest `--resume` |
| **User Abort** | User declines continuation at CDG | Save state → suggest `--resume` |
| **Lock Conflict** | Session lock held by another process | WARN + AskUserQuestion: wait/kill/abort |
| **Cache Corruption** | Scan cache invalid JSON | Invalidate cache + re-run probe |

### 8.2 Error Propagation

```
Agent failure → Main context detect (POST-GATE fail)
  → Retry (max 3x with simplified/refined context)
  → If still fail:
      → Mark layer as "failed" in scan-state.json
      → Log error in sessions/{id}/error-ledger.json
      → AskUserQuestion: continue without / abort / retry manually
```

### 8.3 Error Codes (unified — cross-layer reference xem [02-scan-layers.md §8](02-scan-layers.md))

---

## 9. Scan Cache Integration

### 9.1 Cache Check (before probe run)

```
Phase-level:
  ├── Before L1: skip cache (always re-run)
  ├── Before L3: check cache for each file's inventory entry (by content hash)
  ├── Before L4 batch: check cache for batch fingerprint
  └── Before L5 module: check cache for module fingerprint

Fingerprint:
  SHA256(probe_id || probe_version || input_file_hashes || dep_closure_hash || depth_level)
```

### 9.2 Cache Tiers

| Tier | Location | Git | Default |
|------|----------|-----|---------|
| Session cache | `sessions/{id}/cache/` | Ignored (gitignore) | Auto-created |
| Project cache | `.mc-data/cache/wf-legacy-scan/` | Commit opt-in via `--cache-publish` | Not in git by default (OQ-F recommendation) |

### 9.3 Invalidation Rules

- File hash change → invalidate matching fingerprints
- Probe version bump → invalidate all for that probe
- Probe config change (depth/threshold) → invalidate config-scoped
- TTL expire (default 14 days) → invalidate
- `--no-cache` flag → skip cache entirely
- `--invalidate-cache=<pattern>` → manual invalidate

### 9.4 Git-Friendly Artifacts

Cache files:
- 1 file per fingerprint (small diffs)
- No timestamps in filename (in content)
- Relative paths from project root
- Deterministic JSON key order (stable sort)
- `privacy_scope: public|internal|secret` (secrets never cached)

---

## 10. Orchestrator Load Balancing

### 10.1 Context Budget Monitoring

```
<65%:  Normal operation
65-80%: Prepare checkpoint, start reducing context
80-90%: Save checkpoint immediately, consider --resume suggest
>90%:  Force checkpoint + STOP + suggest --resume
```

Each layer transition checks `$CONTEXT_PERCENT` and triggers checkpoint if threshold crossed.

### 10.2 Multi-Session Handoff

Khi context >90% giữa một layer:
```
1. Save current scan-state.json + layers/{L}/partial.json
2. Generate phase-summary.md with "Paused at layer L4 batch 3/8"
3. Release file-lock
4. Display: "Context budget reached. Dùng /wf-legacy-scan --resume để tiếp tục."
```

User resume → Phase 0 acquire lock → Resume Router → continue từ L4 batch 3.
