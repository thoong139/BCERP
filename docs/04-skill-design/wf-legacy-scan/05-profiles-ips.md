# 05 — Execution Profiles, IPS, Workload & Incremental

> **Đọc trước:** [04-data-model.md](04-data-model.md)
> **Đọc tiếp:** [06-bash-scripts.md](06-bash-scripts.md)

---

## 1. Profiles Overview

### 1.1 Four Profiles (Canonical)

| Profile | Mục đích | Use case | Est. Time (500 files) | Est. Time (1,500 files) | Tokens estimate¹ |
|---------|---------|----------|----------------------|------------------------|------------------|
| **surface** | Overview nhanh, không AI | "Cho tôi xem dự án này có gì" | 5-10 min | 10-15 min | ~15K orchestrator, 0 agent |
| **standard** ★ | Onboarding chuẩn (DEFAULT) — = v4.1 behaviour | "Đưa dự án này vào DEVKIT" | 20-40 min | 40-90 min | ~25K orchestrator, ~50K agent |
| **deep** | Phân tích chuyên sâu domain experts | "Dự án phức tạp, cần hiểu kỹ" | 45-90 min | 90-180 min | ~30K orchestrator, ~100K agent |
| **exhaustive** | Audit toàn diện + divergence | "Kiểm tra mọi thứ, kể divergence" | 90-180 min | 180-360 min | ~35K orchestrator, ~150K agent |

¹ *Token estimates indicative cho project có 10 modules avg complexity. Thực tế ±50% tuỳ domain.*

★ **standard = v4.1 backward-compat lock** (business-analyst + 1 domain-expert per module). KHÔNG giảm capability.

### 1.2 Profile → Depth Map (CANONICAL — fix B1, A2)

```
Profile      L1    L2    L3    L4         L5         L6 synthesis_mode    Notes
─────────────────────────────────────────────────────────────────────────────────
surface      full  full  full  surface    skip       condensed            No AI L4/L5
standard ★   full  full  full  standard   standard   full                 = v4.1 behaviour
deep         full  full  full  deep       deep       full+insights        Domain experts enriched
exhaustive   full  full  full  deep       deep       full+divergence      + divergence detection
```

★ Standard profile **luôn** spawn business-analyst + 1 domain-expert per module nếu domain match ≥0.6 (v2.1 raised từ 0.4 — xem [09-thresholds-justification.md](09-thresholds-justification.md) §2.1). Fallback: business-analyst only khi confidence < 0.6. v4.1 backward-compat lock (spawn pattern unchanged, chỉ threshold tighten).

### 1.3 Profile Selection Logic

```
IF --profile specified:
  → Use specified profile (skip IPS recommendation)
  → IF detected_domain.confidence ≥0.85 AND specified=surface → WARN "Surface skip extraction nhưng domain mạnh được detect"
  → IF size > 1,000 files AND specified=surface → WARN "Surface không full coverage cho dự án lớn"

ELIF IPS-A đã chạy AND có recommendation:
  → AskUserQuestion với IPS recommendation + 4 options + reasoning
  → CDG (CORE-027) — user phải explicit confirm

ELSE (chưa chạy IPS hoặc IPS không recommend):
  → Default = standard
```

---

## 2. Profile Details

### 2.1 Surface Profile

**Mục tiêu:** Overview nhanh, không AI cho L4/L5.

**Khi nào dùng:**
- User muốn "xem trước" dự án trước khi commit full scan
- Re-check sau khi đã deep scan trước đó (chỉ cần overview update)
- Dự án nhỏ + đơn giản (≤100 files, 1-2 modules) — chỉ cần basic context

**Hành vi:**
- L1-L3: Full bash scan (15-180 giây)
- L4 (surface): Heuristic grouping (xem [02-scan-layers.md §4.4.1](02-scan-layers.md))
- L5: SKIP hoàn toàn
- L6 (condensed): `project-context.md` ~2,000 tokens
  - Overview + tech stack + module map (heuristic)
  - KHÔNG features/requirements
  - KHÔNG impl-status-snapshot
  - KHÔNG impact-graph

**Output files:**
- ✅ project-profile.json
- ✅ assessment-report.json
- ✅ domain-hints.json (preliminary)
- ✅ inventory/*.json
- ✅ classified/auto-grouped.json (heuristic)
- ❌ extracted/ — empty
- ✅ project-context.md (condensed)
- ✅ doc-quality-map.json
- ❌ impl-status-snapshot.json — skip
- ❌ impact-graph.json — skip

**User messaging:**

```
✓ Surface scan hoàn tất (~7 phút)

Tổng quan: <project name>
- Tech: TypeScript, React, Node.js
- Size: 847 files, 12 modules (heuristic grouping)
- Maturity: CODE_PLUS_EXTERNAL_DOCS
- Domain phát hiện: finance (confidence 0.85)

⚠️  Surface profile KHÔNG extract requirements/features.
  → Dùng cho overview only.
  → Để có đầy đủ context cho downstream (brainstorm, design, ...):
    chạy lại với --profile=standard hoặc --profile=deep.

Next: Xem .mc-data/work/legacy-scan/project-context.md
```

### 2.2 Standard Profile (DEFAULT — BACKWARD-COMPAT v4.1 LOCK)

**Mục tiêu:** Onboarding chuẩn vào DEVKIT. **= v4.1 hành vi**.

**Khi nào dùng:**
- DEFAULT cho mọi dự án mới
- Dự án 50-500 files
- User cần đủ context cho downstream skills (brainstorm, analyze-req, ...)

**Hành vi:**
- L1-L3: Full bash scan
- L4 (standard): AI classification — code-reviewer per batch
  - Batching: 100 files/batch (configurable `--batch-size`)
  - Glossary generation: business-analyst agent (1 lần)
  - Naming verification (CORE-016/017)
- L5 (standard): AI extraction — **business-analyst + 1 domain-expert per module** (BACKWARD-COMPAT v4.1)
  - Topological ordering từ dependency-graph
  - Max 3 parallel groups
  - Per module: business-analyst (primary) + domain-expert (secondary, nếu domain match ≥0.6 — v2.1 raised từ 0.4)
  - Confidence threshold ≥0.6
- L6 (full): Synthesis ~4,000 tokens (như v4.1)

**So với v4.1 (chi tiết):**

| Aspect | v4.1 | v5.0 standard | Thay đổi |
|--------|------|---------------|---------|
| L4 agent | code-reviewer (qua general-purpose wrapper) | code-reviewer (direct, có depth context) | ✅ Bỏ wrapper, thêm context |
| L5 agent | business-analyst + 1 domain-expert | business-analyst + 1 domain-expert | ✅ **GIỮ NGUYÊN** (BACKWARD-COMPAT) |
| Domain detection | Sub-skill internal | IPS routing (better signal) | ✅ Improve quality |
| Session isolation | None | Yes | ✅ Add audit trail |
| Resume | Phase-level | 4-level | ✅ Improve resilience |
| Cache | None | Optional | ✅ Improve re-scan speed |
| Output | inventory + classified + extracted + project-context.md | Same + impact-graph.json | ✅ Add impact graph |

> **Lock guarantee:** Standard profile **không giảm** capability so với v4.1. Bug bất kỳ trong standard profile mà v4.1 không có → blocking issue cho release.

### 2.3 Deep Profile

**Mục tiêu:** Phân tích chuyên sâu với domain expertise enrichment.

**Khi nào dùng:**
- Dự án >500 files hoặc phức tạp (multiple domains)
- Domain-specific project (finance, healthcare, logistics, ERP)
- User cần high-confidence extraction (≥0.8) cho compliance/audit

**Hành vi (thêm so với standard):**
- L4 (deep): code-reviewer + domain-expert per detected_domain
  - Domain expert reviews module boundaries
  - Domain expert enriches glossary với domain terminology
  - Cross-validate naming với domain conventions
- L5 (deep): business-analyst + domain-expert (enriched prompt)
  - Enriched prompt: include IPS hotspots + domain hints + complexity signals
  - Cross-validation pass: business-analyst extracts → domain-expert reviews → main context validates
  - Confidence threshold ≥0.8
  - Module-code-mapping enriched với domain annotations
- L6 (full+insights): Synthesis ~5,000 tokens
  - Sections: Full + Domain Insights + Gap Analysis + Complexity Hotspots + Impact Graph Summary

**Domain Expert Routing (deep profile triggers full domain matrix):**

```
IPS detects: finance (0.85), logistics (0.72)
  → L4 deep: spawn code-reviewer + finance-expert + logistics-expert (glossary enrichment)
  → L5 deep:
       For modules in finance domain → spawn business-analyst + finance-expert
       For modules in logistics domain → spawn business-analyst + logistics-expert
       For modules in unknown domain → spawn business-analyst only
  → Glossary: enriched với finance + logistics terminology
```

### 2.4 Exhaustive Profile

**Mục tiêu:** Audit toàn diện, bao gồm divergence analysis.

**Khi nào dùng:**
- Dự án có docs + code cần alignment check
- Pre-audit trước khi migrate/refactor lớn
- Compliance requirement (SOX, ISO) cần full coverage report
- ERP module review

**Hành vi (thêm so với deep):**
- L5: divergence detection (code vs docs comparison)
  - Classification: synced / diverged / undocumented / unimplemented
  - Per-module divergence report
- L6 (full+divergence): Synthesis ~6,000 tokens
  - Sections: full+insights + Divergence Notes per module + Risk Summary
  - Additional output: `extracted/{module}-divergences.json`

**So với strategy S5 (DIVERGENCE-RESOLVE) v4.1:**
- Exhaustive profile **tự động** chạy divergence analysis (không cần explicit S5)
- Strategy S5 routing logic vẫn hoạt động độc lập (cho user override)
- Strategy × Profile compose orthogonally (xem §2.5)

### 2.5 Strategy × Profile Interaction Matrix

Strategies quyết định **routing** (phases nào chạy, source ưu tiên), profiles quyết định **depth** (độ sâu mỗi phase). Hai trục **độc lập** (ADR-LS08).

| Strategy | Routing semantic | Source-priority | Surface | Standard | Deep | Exhaustive |
|----------|-----------------|-----------------|---------|----------|------|------------|
| **S1: FAST-TRACK** | Skip non-critical phases | balanced | L4 surface, L5 skip, L6 condensed | L4 standard, L5 standard, L6 full | L4 deep, L5 deep, L6 full+insights | L4 deep, L5 deep+div, L6 full+div |
| **S2: CODE-FIRST** | Prioritize code source | code-priority | Surface | Standard (L5 code-priority) | Deep (L5 code-priority) | Exhaustive (L5 code-priority + div) |
| **S3: DOCS-BRAINSTORM** | Prioritize doc source | doc-priority | Surface | Standard (L5 doc-priority) | Deep (L5 doc-priority) | Exhaustive (L5 doc-priority + div) |
| **S4: CODE-PLUS-DOCS** | Both sources, balanced | balanced | Surface | Standard | Deep | Exhaustive |
| **S5: DIVERGENCE-RESOLVE** | Force divergence detection | balanced + diverge | Surface | Standard + div | Deep + div | Exhaustive (already div) |
| **S6: DOCS-PLUS-CODE** | Doc-first but no skip | doc-first | Surface | Standard (L5 doc-first) | Deep (L5 doc-first) | Exhaustive (L5 doc-first + div) |
| **S7: NEAR-COMPLETE** | Delta-only mode | n/a | Surface | Standard delta | Deep delta | Exhaustive delta + div |

**Source-priority semantics (formal — fix B6):**

| Source-priority | Behavior |
|-----------------|----------|
| **balanced** | L5 extraction xét cả code và docs, weighted equally. Modules có cả 2 → confidence cao hơn. |
| **code-priority** | L5 extraction ưu tiên code, docs làm validation. Modules chỉ có docs → vẫn extract nhưng confidence trừ 0.1. Modules chỉ có code → extract đầy đủ. |
| **doc-priority** | L5 extraction ưu tiên docs, code làm validation. Modules chỉ có code → vẫn extract nhưng confidence trừ 0.1. Modules chỉ có docs → extract đầy đủ. |
| **doc-first** | Giống doc-priority NHƯNG không trừ confidence cho modules chỉ có code. Cả 2 source extract đầy đủ, doc làm primary reference khi conflict. |
| **diverge** | Bật divergence detection regardless of profile. Output thêm `{module}-divergences.json`. |

**Delta mode (S7) vs incremental mode — fix B8:**

```
S7 (NEAR-COMPLETE strategy) = strategy routing flag
  → Sets default behavior: chỉ re-process changes
  → User KHÔNG cần explicit --incremental

--incremental flag = operational flag
  → Standalone từ strategy
  → Có thể combine với bất kỳ strategy nào
  → Override default behavior

Combinations:
  S7 alone → delta mode by default
  S7 + --incremental --since=HEAD~5 → delta + git diff scope
  S2 + --incremental → CODE-FIRST + delta (chỉ re-process changed code)
  S5 + --incremental → DIVERGENCE + delta (chỉ verify divergence trên changed)
```

**Key observations:**
- **L1-L3 luôn full** — deterministic layers không bị ảnh hưởng bởi strategy hay profile.
- **Profile surface luôn skip L5** — bất kể strategy. Surface = overview only.
- **Strategy S5** tự động bật divergence ở standard+ profiles.
- **Profile exhaustive** bật divergence cho mọi strategy.
- **S7** bật delta mode by default; user có thể explicit `--incremental` để override.

---

## 3. Intelligent Pre-Scan (IPS) Design — 2 Phases (v2.1 REVISED)

> **v2.1 change:** IPS logic chuyển từ inline trong SKILL.md / procedure files sang **Python module `.claude/skills/workflow/_shared/ips/`** — tái dùng pattern từ wf-fix-bugs v6 ISG. Chi tiết: [08-tradeoffs-adr.md ADR-LS03](08-tradeoffs-adr.md).
>
> **Module structure:**
> ```
> .claude/skills/workflow/_shared/ips/
> ├── __init__.py
> ├── ips_recommender.py          ← Main API: run_phase_a(), run_phase_b()
> ├── domain_scorer.py            ← Score domains từ signals (EN + VN)
> ├── vietnamese_keywords.py      ← Load + match VN keyword pool (ADR-LS15)
> ├── workload_estimator.py       ← Estimate features + time + workload gate thresholds
> └── tests/
>     ├── test_domain_scorer.py
>     ├── test_vietnamese_keywords.py
>     ├── test_workload_estimator.py
>     └── fixtures/
>         ├── small_en/           ← English project fixture
>         ├── medium_vn/          ← VN project fixture (qlkh, hoadon, qlns, ...)
>         └── mixed_en_vn/        ← Mixed fixture
> ```
>
> **Orchestrator calls:**
> ```bash
> # Sau L2 Assessment
> python -m workflow._shared.ips.ips_recommender phase_a \
>   --project-profile .mc-data/work/legacy-scan/project-profile.json \
>   --assessment .mc-data/work/legacy-scan/assessment-report.json \
>   --output .mc-data/work/legacy-scan/sessions/{id}/ips-phase-a.json
>
> # Sau L3 Inventory
> python -m workflow._shared.ips.ips_recommender phase_b \
>   --inventory .mc-data/work/legacy-scan/inventory/ \
>   --ips-a .mc-data/work/legacy-scan/sessions/{id}/ips-phase-a.json \
>   --output .mc-data/work/legacy-scan/sessions/{id}/ips-phase-b.json
> ```

### 3.1 IPS Execution Points (fix B2)

```
Phase 0 Init
  ↓
L1 Discovery (bash)
  ↓
L2 Assessment (bash)
  ↓
► IPS Phase A (inline) ◄  ← Recommend profile + initial domain hints
  ↓
[User AskUserQuestion if --profile not specified — CDG]
  ↓
L3 Inventory (bash)
  ↓
► IPS Phase B (inline) ◄  ← Refine module routing + complexity hotspots
  ↓
[Workload Gate if estimate exceeds soft cap — CDG]
  ↓
L4 → L5 → L6
```

**Why 2-phase?**
- L2 only has aggregate data (counts, scores) → đủ recommend profile + initial domain
- L3 has file-level data → đủ refine module routing + identify hotspots
- Tách 2 phase tránh IPS chạy với insufficient data

### 3.2 IPS-A Algorithm (sau L2)

```python
def ips_phase_a():
    profile_data = read('project-profile.json')
    assessment = read('assessment-report.json')
    
    # 1. Extract signals
    signals = {
        'package_deps': profile_data['dependencies'],
        'directory_names': profile_data['top_level_dirs'],
        'import_patterns': sample_imports(profile_data, n=100),
        'frameworks': profile_data['frameworks'],
        'scores': assessment['scores'],
        'maturity': assessment['maturity_level']
    }
    
    # 2. Score domains
    detected = score_domains(signals)  # returns [{domain, confidence, signals[]}]
    
    # 3. Recommend profile
    if assessment['maturity_level'] == 'NEAR_COMPLETE':
        rec_profile = 'surface'
        reasoning = 'Project well-documented, only need overview'
    elif profile_data['file_counts']['total'] > 1000 or len(detected) >= 2:
        rec_profile = 'deep'
        reasoning = f'Large/complex project ({total} files, {len(detected)} domains)'
    elif any(d['confidence'] >= 0.75 for d in detected):
        rec_profile = 'deep'
        reasoning = f'Strong domain match: {top_domain.domain} ({confidence})'
    elif assessment['scores']['code_quality'] >= 70 and assessment['scores']['doc_quality'] >= 50:
        rec_profile = 'standard'
        reasoning = 'Healthy project, standard onboarding'
    else:
        rec_profile = 'standard'
        reasoning = 'Default'
    
    # 4. Write to scan-state.ips.phase_a
    update_scan_state('ips.phase_a', {
        'recommended_profile': rec_profile,
        'profile_reasoning': reasoning,
        'detected_domains': detected,
        'unresolved_patterns': find_unresolved(signals),
        'user_overrode_profile': False
    })
    
    # 5. Trigger user interaction (CDG)
    if cli_args.profile is None:
        ask_user_profile_selection(rec_profile, detected, reasoning)
```

### 3.3 IPS-B Algorithm (sau L3)

```python
def ips_phase_b():
    inventory = read_all('inventory/*.json')
    profile_data = read('project-profile.json')
    
    # 1. Cluster files by directory → modules
    module_files = cluster_by_directory(inventory['source-files'])
    
    # 2. Compute coupling per module
    coupling = compute_coupling(module_files, inventory['dependency-graph'])
    
    # 3. Identify hotspots (top 20% by size or coupling)
    hotspots = find_hotspots(module_files, coupling)
    
    # 4. Refine module → domain routing
    routing = {}
    for module, files in module_files.items():
        domain_scores = score_module_domain(module, files)  # match against domain keywords
        if domain_scores:
            top = max(domain_scores, key=lambda x: x['confidence'])
            if top['confidence'] >= 0.4:
                routing[module] = {
                    'domain': top['domain'],
                    'expert': domain_to_agent[top['domain']],
                    'confidence': top['confidence']
                }
    
    # 5. Workload estimate
    total_features_est = sum(len(files) * feature_density(profile, depth) 
                             for module, files in module_files.items())
    est_time = estimate_time(total_features_est, depth)
    soft_cap = profile.time_budget_minutes * 1.5
    
    workload = {
        'total_features_est': total_features_est,
        'est_time_min': est_time,
        'soft_cap_min': soft_cap,
        'exceeds_cap': est_time > soft_cap,
        'ratio': est_time / profile.time_budget_minutes
    }
    
    # 6. Write to scan-state.ips.phase_b
    update_scan_state('ips.phase_b', {
        'module_routing': routing,
        'complexity_hotspots': hotspots,
        'workload_estimate': workload
    })
    
    # 7. Trigger Workload Gate if needed (CDG)
    if workload['exceeds_cap']:
        trigger_workload_gate(workload, routing, hotspots)
```

### 3.4 IPS Domain Detection Rules (consolidated)

| Signal | Domain | Weight | Detection Method |
|--------|--------|--------|-----------------|
| `decimal.js`, `money.js`, `currency.js` | finance | 0.3 | package.json |
| `billing/`, `invoice/`, `payment/`, `tax/` | finance | 0.4 | directory names |
| `procurement/`, `sourcing/`, `vendor/` | procurement | 0.4 | directory names |
| `sales/`, `crm/`, `pipeline/` | sales | 0.4 | directory names |
| `hr/`, `payroll/`, `leave/` | hr | 0.4 | directory names |
| `cart/`, `checkout/`, `catalog/` | ecommerce | 0.4 | directory names |
| `inventory/`, `warehouse/`, `stock/` | operations | 0.4 | directory names |
| `audit/`, `compliance/`, `regulatory/` | compliance | 0.4 | directory names |
| `fhir`, `hl7`, `openemr` | healthcare | 0.5-0.7 | package.json + imports |
| `patient/`, `clinical/`, `prescription/`, `bhyt/` | healthcare | 0.4 | directory names |
| `shipping/`, `customs/`, `tms/`, `wms/` | logistics | 0.4 | directory names |
| `bom/`, `production/`, `mrp/` | manufacturing | 0.4 | directory names |
| `pos/`, `store/`, `cashier/` | retail | 0.4 | directory names |
| `contract/`, `legal/` | legal | 0.4 | directory names |
| `policy/`, `claim/`, `underwriting/` | insurance | 0.4 | directory names |
| `course/`, `student/`, `lms/` | education | 0.4 | directory names |

**Aggregation:** weighted sum per domain. ≥0.75 strong, 0.4-0.74 moderate, <0.4 weak.

### 3.5 IPS User Interaction (sau Phase A)

Khi `--profile` không được chỉ định:

```
📊 IPS Analysis — Kết quả phân tích ban đầu

Dự án: Eureka XNK & Thương Mại
Kích thước: 847 files (TypeScript, .NET, React)
Maturity: CODE_PLUS_EXTERNAL_DOCS
Domain phát hiện:
  - finance (0.85) — billing, invoice, tax dirs detected
  - logistics (0.72) — shipping, customs, tms dirs detected

Khuyến nghị: deep profile
  Lý do: Dự án lớn (847 files) + 2 domain mạnh (finance, logistics) + code quality medium (62/100)

Chọn profile scan:
  ○ surface — Overview nhanh (~8 min, không extraction)
  ○ standard — Onboarding chuẩn (~35 min, business-analyst + domain experts)
  ● deep — Phân tích chuyên sâu (~75 min, domain experts enriched) ← Khuyến nghị
  ○ exhaustive — Audit toàn diện (~150 min, + divergence)

[Enter]=xác nhận khuyến nghị | [s]=surface | [t]=standard | [e]=exhaustive | [c]=tuỳ chỉnh layers | [q]=huỷ
```

### 3.6 IPS Override

User có thể override IPS recommendation:

| User input | Behavior |
|-----------|----------|
| `--profile=standard` khi IPS recommend deep | Proceed + WARN "Standard profile có thể miss domain-specific requirements (detected: finance, logistics)" |
| `--profile=deep` khi IPS recommend surface | Proceed (overhead acceptable) |
| `--layers=L4,L5 --depth=deep` | Override specific layers; L1-L3 vẫn full |
| `--no-interactive` | Skip CDG, dùng default profile |

---

## 4. Workload Gate (sau IPS-B)

### 4.1 Trigger Conditions

```
Workload Gate triggered nếu bất kỳ:
  - estimated_time_min > 1.5 × profile.time_budget_minutes
  - total_features_est > 100
  - largest_module_files > 50
  - modules_count > 30
  - total_files > 1,000 AND profile ∈ {deep, exhaustive}
```

### 4.2 Gate UI

```
⚠️  Workload lớn phát hiện

Ước tính: 145 features × 5 modules × deep profile ≈ 150 phút
Profile budget: 75 phút (deep)
Tỷ lệ vượt budget: 2.0×

Chi tiết module (sorted by complexity):
  - billing (45 files, 32 features est.) — ~40 min — HOTSPOT
  - customer (32 files, 22 features est.) — ~25 min
  - shipment (28 files, 19 features est.) — ~22 min
  - invoice (22 files, 16 features est.) — ~18 min
  - reporting (18 files, 12 features est.) — ~15 min

Đề xuất phân chia:
  [A] Plan A — Partition theo module (5 chunks, mỗi chunk ~25-40 min)
        Phù hợp: chạy tuần tự qua nhiều phiên (vài ngày)
  [B] Plan B — Partition theo domain (2 chunks: finance+billing+invoice, logistics+shipment)
        Phù hợp: chia việc cho 2 người (multi-machine parallel)
  [C] Plan C — Downgrade profile deep → standard (~60 min)
        Phù hợp: chấp nhận confidence thấp hơn (0.6 vs 0.8), 1 phiên
  [D] Plan D — Giữ nguyên (chạy >2.5h một phiên — KHÔNG khuyến nghị cho ERP)
  [E] Plan E — Huỷ (quyết định lại)

Chọn: [A] [B] [C] [D] [E]
```

### 4.3 Partition Planner Output

Nếu user chọn A/B → orchestrator sinh `fix-workload.json` (xem [04-data-model.md §8](04-data-model.md)).

### 4.4 Multi-Session Execution

```bash
# Session 1 (Terminal 1 hoặc máy A)
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=ch-001

# Session 2 (Terminal 2 hoặc máy B — song song)
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=ch-002

# Auto-pick next available
/wf-legacy-scan --workload=wl-erp-20260422-001 --chunk=next

# Sau khi tất cả chunks done:
/wf-legacy-scan --workload=wl-erp-20260422-001 --aggregate
```

**Coordination:**
- Chunk start → acquire `workload.lock` để set status=in_progress atomic
- Chunk complete → release lock + update chunk.status=done + output_hash
- Chunk timeout (>2× est_time) → status=stale → cho phép session khác pick lại
- Aggregate step:
  - Read all chunks' output
  - Dedup theo `dedup_key_strategy` (default: `tmp_req_hash_v1`)
  - Build unified `project-context.md` (synthesis_mode = max của các chunks)
  - Build unified `impact-graph.json` (merge edges)
  - Generate `workload-report.md` (coverage 100%, dedup stats)

---

## 5. Multi-Session Resilience

### 5.1 Khi nào cần multi-session

| Condition | Multi-session needed? |
|-----------|----------------------|
| Profile surface | Không (bash-only, nhanh) |
| Profile standard, <200 files | Không |
| Profile standard, 200-500 files | Có thể (monitor context) |
| Profile deep, >300 files | Có khả năng |
| Profile deep, >800 files | Có (Workload Gate triggered) |
| Profile exhaustive | Có khả năng cao |
| Workload Gate Plan A/B chosen | Định nghĩa nhiều session từ đầu |

### 5.2 Context Budget Monitoring

```
<65%:  Normal operation
65-80%: Prepare checkpoint, start reducing context (drop verbose logging)
80-90%: Save L2/L3 checkpoint immediately, suggest --resume hint
>90%:  Force checkpoint + STOP gracefully + suggest --resume
```

### 5.3 Multi-Session Flow Example

```
Session 1:
  L1-L3 (bash, ~2 min)
  L4 (classify, batches 1-3 of 5) — Context 80% reached
  → Checkpoint L2: scan-state.layers.L4.batch_progress = {current: 3, total: 5, completed: [001, 002, 003]}
  → Checkpoint L3: layers/L4/partial.json saved
  → Generate phase-summary.md "Paused at L4 batch 3/5"
  → Release file-lock
  → STOP: "Classification 60% complete. Dùng --resume để tiếp tục."

Session 2 (--resume):
  → Acquire file-lock
  → Read scan-state.json → last_completed=L3, layer L4 in_progress batch 3/5
  → Resume L4 batch 4-5
  → L5 extraction → L6 synthesis → COMPLETE
  → Generate final phase-summary, session-digest, etc.
```

### 5.4 Agent Context Budget per Layer

| Layer | Agent | Tokens per batch/module | Max per session (single agent) |
|-------|-------|-------------------------|--------------------------------|
| L4 | code-reviewer | ~3K | ~5 batches |
| L4 | domain-expert (glossary, deep) | ~5K | 1 session |
| L5 | business-analyst | ~8K | ~3 modules |
| L5 | domain-expert | ~12K | ~2 modules |
| L5 | business-analyst + domain-expert (paired) | ~20K | ~1.5 modules |

---

## 6. Incremental Scan + Cache

### 6.1 Staleness Detection

Mở rộng `legacy-scan-staleness.sh` hiện tại:

```
--incremental [--since=<git-ref>]:
  1. Read previous scan-state.json (latest completed session)
  2. Detect changes:
     - IF --since specified AND git: git diff --name-only <ref> HEAD
     - ELSE: file mtime + content hash compare with previous scan-cache fingerprints
  3. Classify staleness:
     - <10% files stale: delta processing only (cache hit majority)
     - 10-30% files stale: partial rescan (L3 partial + L4/L5 delta)
     - >30% files stale: WARN + recommend full rescan + AskUserQuestion
  4. Execute delta processing per layer (xem [02-scan-layers.md §7](02-scan-layers.md))
```

### 6.2 Delta Processing

```
DELTA = {modified_files + new_files}
UNCHANGED = existing_files - modified - deleted
DELETED = files_in_previous_scan - files_now

L3 (Inventory):
  - Re-inventory only DELTA files
  - Merge with existing UNCHANGED entries
  - Remove DELETED entries

L4 (Classification):
  - Re-classify only DELTA files (batch them)
  - Merge module assignments (preserve UNCHANGED files' assignments)
  - Regenerate glossary if >20% terms affected

L5 (Extraction):
  - Identify affected modules (modules containing DELTA or DELETED files)
  - Re-extract only affected modules (full module re-extract for affected)
  - Keep UNAFFECTED module extractions unchanged (cache hit)
  - IF renames detected → full re-extract affected modules (delta merge unreliable)

L6 (Synthesis):
  - Always re-synthesize from updated data
  - Re-build impact-graph.json (relations may have changed)
```

### 6.3 Scan Cache Effectiveness

```
Re-scan với 20% files changed:
  - L1: full re-run (fast bash, ~10s)
  - L2: full re-run (fast bash, ~5s)
  - L3: 80% files cache hit, 20% re-process (~20s for 500 files)
  - L4: ~80% batch fingerprints cache hit (skip 4 of 5 batches)
       ~20% re-classify changed files (one batch)
  - L5: identify ~3 of 10 modules affected → re-extract 3 modules (~15 min)
       ~7 modules cache hit (skip extraction)
  - L6: always re-synthesize (~3 min)

Total time: 20-25 min (vs 35 min full scan) = ~30% time savings
```

### 6.4 Cache Publish (Team Collaboration)

```bash
# Dev A:
/wf-legacy-scan --profile=deep
  → cache filled at sessions/{id}/cache/

# Dev A optionally publish:
/wf-legacy-scan --cache-publish
  → copy session cache → .mc-data/cache/wf-legacy-scan/probes/
  → git add .mc-data/cache/wf-legacy-scan/
  → git commit -m "scan cache: project /erp deep scan 2026-04-22"
  → git push

# Dev B:
git pull
/wf-legacy-scan --incremental --since=HEAD~5
  → orchestrator detects project cache exists
  → cache hits cho code chưa đổi (~70% probe calls)
  → re-process chỉ phần git diff
  → ~20% thời gian full scan
```

**Privacy guard:**
- Files với `privacy_scope: secret` → never cached
- Files với `privacy_scope: internal` → only session cache (not project)
- Files với `privacy_scope: public` → both tiers
- Default: `internal` (safe default)

---

## 7. Profile + Strategy + Workload Compose Examples

### Example 1: Dự án nhỏ healthy

```
Project: 80 files, 3 modules, healthy code+docs
IPS-A: code_quality=78, doc_quality=65, no strong domain
Recommended: standard
User accepts: standard

Result:
  - L1-L3 full bash (~30s)
  - L4 standard: 1 batch code-reviewer (~3 min)
  - L5 standard: 3 modules × business-analyst + business-analyst fallback (~10 min)
  - L6 full: ~2 min
  Total: ~16 min
```

### Example 2: Dự án ERP lớn

```
Project: 1,500 files, 35 modules estimated, finance + logistics domains
IPS-A: detect finance (0.85), logistics (0.72)
Recommended: deep
IPS-B (sau L3): 145 features, est 150 min, exceeds 75 min cap (2.0×)
Workload Gate: User chooses Plan B (split by domain, 2 chunks)

Chunk 1 (finance, 18 modules, 80 min):
  - L4 deep: code-reviewer + finance-expert (~25 min)
  - L5 deep: business-analyst + finance-expert per module (~50 min)
  - L6 partial synthesis (~5 min)
  
Chunk 2 (logistics, 17 modules, 70 min):
  - L4 deep: code-reviewer + logistics-expert (~22 min)
  - L5 deep: business-analyst + logistics-expert per module (~45 min)
  - L6 partial synthesis (~3 min)

Aggregate (after both done):
  - Merge chunks (~5 min)
  - Build unified project-context.md + impact-graph.json
```

### Example 3: Re-scan sau 2 ngày

```
Project: 500 files, dev đã sửa 50 files (10%)
User: /wf-legacy-scan --incremental --since=HEAD~3

Result:
  - Staleness detect: 50/500 files (10%) → delta mode
  - L1: re-run (~10s)
  - L2: re-run + IPS-A (~5s)
  - L3: 90% cache hit, re-process 50 files (~5s)
  - IPS-B: refine routing for affected modules
  - L4: ~3 of 5 batches cache hit, re-classify 50 files (~5 min)
  - L5: 3 of 10 modules affected → re-extract 3 modules (~15 min)
       7 modules cache hit
  - L6: re-synthesize (~3 min)
  Total: ~24 min (vs ~35 min full scan = 31% savings)
```
