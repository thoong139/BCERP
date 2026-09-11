# 02 — Scan Layers: Định Nghĩa, Depth Levels, Probes & Exit Criteria

> **Đọc trước:** [01-vision-principles.md](01-vision-principles.md)
> **Đọc tiếp:** [03-architecture.md](03-architecture.md)

---

## 1. Tổng Quan

wf-legacy-scan v5 chia pipeline thành **6 Scan Layers (L1-L6)**. Mỗi layer có mục tiêu độc lập, depth control riêng, và exit criteria đo được qua T1-T4 framework (CORE-012).

```
┌─────────────────────────────────────────────────────────────┐
│  DETERMINISTIC (bash)    │  INTELLIGENT (AI)                │
│  ─────────────────────   │  ─────────────────────────       │
│  L1 Discovery            │  L4 Classification               │
│  L2 Assessment + IPS-A   │  L5 Extraction                   │
│  L3 Inventory  + IPS-B   │                                  │
│                          │  SYNTHESIS (AI main context)     │
│  (always full depth)     │  L6 Synthesis                    │
│                          │  (synthesis_mode varies)         │
└─────────────────────────────────────────────────────────────┘
```

**Depth control:**
- L1-L3 **luôn full** (deterministic, không có depth control).
- L4-L5 có **3 depth levels**: `surface` / `standard` / `deep`. L5 thêm `skip`.
- L6 dùng **synthesis_mode**: `condensed` / `full` / `full+insights` / `full+divergence`.

**IPS (Intelligent Pre-Scan):**
- **IPS-A** chạy **sau L2** — analyze aggregate signals (file counts, scores, package deps) → recommend profile + domain hints.
- **IPS-B** chạy **sau L3** — analyze file-level data (inventory) → refine complexity hotspots + module routing hints.

---

## 2. Depth Levels (L4, L5 only)

Mỗi intelligent layer (L4, L5) có 3 depth levels:

| Depth | Mô tả | Agent | Confidence kỳ vọng | Token ước lượng¹ |
|-------|-------|-------|-------------------|-----------------|
| **surface** | Heuristic/rule-based, không AI | Không | N/A (facts only) | ~2K |
| **standard** | AI basic analysis, single pass | 1 agent per batch/module | ≥0.65 | ~8K-15K |
| **deep** | AI + domain expert, multi-pass, enrichment | Agent + domain-expert | ≥0.80 | ~15K-30K |

**L5 thêm depth `skip`:** L5 không chạy, không extraction.

¹ *Token estimates là indicative cho project 500 files, 10 modules. Thực tế ±50% tuỳ domain complexity.*

---

## 3. synthesis_mode (L6 only)

L6 dùng `synthesis_mode` thay vì depth level vì L6 **luôn chạy** (không skip) và luôn trong main context (không agent):

| synthesis_mode | Nội dung `project-context.md` | Target tokens | Khi nào |
|----------------|------------------------------|---------------|---------|
| **condensed** | Overview + tech stack + module map (from L4 surface). Không features/requirements/impl-status. | ≤2,000 | Profile surface |
| **full** | Overview + systems + tech stack + module map + docs status + features summary + impl status. Như v4.1. | ≤4,000 | Profile standard |
| **full+insights** | Full + domain-specific insights + gap analysis + complexity hotspots + impact graph summary. | ≤5,000 | Profile deep |
| **full+divergence** | Full+insights + divergence notes (code vs docs mismatch) + risk summary per module. | ≤6,000 | Profile exhaustive |

---

## 4. Chi Tiết Từng Layer

### L1 — Discovery

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Phát hiện tech stack, structure, file metrics, frameworks, preliminary domain hints |
| **Phương thức** | Bash deterministic — `legacy-scan-detect.sh` |
| **Depth** | Luôn full (không depth control) |
| **Agent** | Không |
| **Input** | `<project-path>` |
| **Output** | `project-profile.json`, preliminary `domain-hints.json` |
| **Thời gian ước lượng** | 10-30 giây (scale với file count, max ~2 min cho 10,000 files) |

**Probes:**
- **P1.01** — Tech stack detection (package.json, requirements.txt, go.mod, ...)
- **P1.02** — File extension census
- **P1.03** — Directory structure analysis
- **P1.04** — Framework detection (React/Vue/Angular/Next/Django/Rails/...)
- **P1.05** — Preliminary domain hint from package dependencies + top-level directories

**Exit Criteria (POST-GATE T1-T4):**

| Tier | Check | Lệnh | Fail → |
|------|-------|------|--------|
| **T1 Existence** | File tồn tại, non-empty | `test -s project-profile.json` | ESCALATE |
| **T2 Structure** | Required fields present | `jq -e '.file_counts.total >= 0' project-profile.json` | Auto-fix script re-run |
| **T3 Content** | Tech stack detected hoặc warn | `jq -e '.tech_stack_verified != null' project-profile.json` | WARN continue |
| **T4 Cross-ref** | Preliminary domain hints nếu applicable | `jq -e '.domain_hints // []' project-profile.json` (always pass, is advisory) | Skip |

**Key improvements so với v4.1:**
- Thêm preliminary `domain_hints` field (populated by L2 enrichment)
- Complexity hotspot detection (files >500 lines flagged)
- Cross-platform path normalization (Windows Git Bash + WSL + Linux + macOS)

---

### L2 — Assessment + IPS Phase A

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Maturity scoring, complexity, risk scoring, domain hint enrichment, profile recommendation |
| **Phương thức** | Bash deterministic — `legacy-scan-assess.sh` + IPS-A inline logic trong orchestrator |
| **Depth** | Luôn full |
| **Agent** | Không |
| **Input** | `<project-path>`, `project-profile.json` |
| **Output** | `assessment-report.json`, enriched `domain-hints.json`, scan-state.ips.phase_a |
| **Thời gian ước lượng** | 5-15 giây (bash) + 2-5 giây (IPS-A inline) |

**Probes:**
- **P2.01** — Doc maturity scoring (code_quality, doc_quality, test_quality)
- **P2.02** — Strategy selection (S1-S7 — xem [08-tradeoffs-adr.md ADR-LS08](08-tradeoffs-adr.md))
- **P2.03** — Staleness threshold check
- **P2.04** — Domain hints enrichment (dir names + import patterns)
- **P2.05** — Complexity indicator (file size distribution, nesting depth)

**IPS-A (Intelligent Pre-Scan Phase A) Steps:**

```
1. Read project-profile.json + assessment-report.json
2. Extract signals:
   - package dependencies (from L1 P1.01)
   - directory names (from L1 P1.03)
   - import patterns (sampled from L1 P1.05)
   - assessment scores (from L2 P2.01)
3. Score domains (weighted sum of signals per domain)
4. Recommend profile:
   - IF file_counts.total > 1,000 OR modules_estimated > 30 → suggest "deep" + trigger Workload Gate
   - IF detected_domain max_confidence ≥0.75 → suggest "deep"
   - IF maturity = NEAR_COMPLETE → suggest "surface"
   - IF code_quality ≥70 AND doc_quality ≥50 AND size ≤500 → suggest "standard"
   - ELSE → suggest "standard" (safe default)
5. Write to scan-state.ips.phase_a
6. IF --profile not specified → AskUserQuestion với recommendation (CORE-027 CDG)
```

**Exit Criteria (POST-GATE T1-T4):**

| Tier | Check | Fail → |
|------|-------|--------|
| **T1** | `test -s assessment-report.json` | ESCALATE |
| **T2** | `jq -e '.scores.code_quality' assessment-report.json` | Retry script 2x |
| **T3** | `jq -e '.maturity_level' assessment-report.json` | Retry script 2x |
| **T4** | Strategy assigned + IPS-A written to scan-state | ESCALATE |

**Key improvements so với v4.1:**
- Scoring overflow fix (clamp per-component, không chỉ total) — xem [06-bash-scripts.md §3.3](06-bash-scripts.md)
- `domain-hints.json` output với detection sources + confidence
- Configurable staleness threshold (thay vì hardcoded 180 days)
- IPS-A profile recommendation (new)

---

### L3 — Inventory + IPS Phase B

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Enumerate screens, APIs, source files, docs, deps, UI manifest, external docs |
| **Phương thức** | Bash deterministic — `legacy-scan-inventory.sh` + IPS-B inline logic |
| **Depth** | Luôn full |
| **Agent** | Không |
| **Input** | `<project-path>`, `project-profile.json`, `assessment-report.json` |
| **Output** | 7 inventory files + enriched `scan-state.ips.phase_b` |
| **Thời gian ước lượng** | 30-120 giây (scale với file count) |

**Inventory files:**
1. `inventory/source-files.json` — source code file list
2. `inventory/screens.json` — UI screens detected
3. `inventory/api-endpoints.json` — API routes extracted
4. `inventory/doc-files.json` — docs classification
5. `inventory/dependency-graph.json` — import/export graph
6. `inventory/external-docs.json` — external doc references
7. `inventory/ui-manifest.json` — UI routes + framework manifest (conditional: screens.count > 0)

**IPS-B (Intelligent Pre-Scan Phase B) Steps:**

```
1. Read all inventory files
2. Estimate module complexity:
   - File count per directory cluster → module size
   - Import density (from dependency-graph) → coupling estimate
   - Top 20% largest files → hotspots
3. Refine module → domain routing:
   - Files matching domain keywords (billing, patient, shipment, ...) → assign domain
   - Update scan-state.ips.phase_b.module_routing {module → domain_expert}
4. Workload check:
   - IF total_features_estimated > 100 OR largest_module_files > 50 → suggest Workload Gate
5. Write scan-state.ips.phase_b
```

**Exit Criteria (POST-GATE T1-T4):**

| Tier | Check | Fail → |
|------|-------|--------|
| **T1** | `test -s inventory/source-files.json` | ESCALATE |
| **T2** | `jq -e '.files | length >= 0' inventory/source-files.json` | Retry script |
| **T3** | Source count consistency — tolerate ±5% | Log WARN if `\|inventory_count - profile_count\| / profile_count > 0.05`; fail only if >20% drift | Retry script then ESCALATE |
| **T4** | UI manifest consistency (if applicable) | `jq -e '.coverage.total_screens >= .coverage.screens_with_routes' inventory/ui-manifest.json` | Auto-fix then WARN |

**Key improvements so với v4.1:**
- Configurable caps (`LEGACY_SCAN_MAX_API`, `LEGACY_SCAN_MAX_SCREENS`, `--max-files` CLI override)
- jq validation sau mỗi file write (atomic_write_json pattern)
- Shared library dedup với `ui-coverage-scan.sh` (~300 dòng)
- Dependency graph: implement basic circular detection (thay vì stub trong v4.1)
- JSON schema validation sau write
- **T3 tolerance** — tránh false negative khi filter divergence (fix B7 từ review v1.0)

---

### L4 — Classification

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Phân loại files vào systems/modules, tạo glossary, naming normalization |
| **Phương thức** | Adaptive depth |
| **Agent** | surface: không / standard: code-reviewer / deep: code-reviewer + domain-expert |
| **Input** | inventory files, project-profile, assessment-report, scan-state.ips |
| **Output** | classified/*.json, glossary.json, classify-naming-fixes.json |
| **Thời gian ước lượng** | surface: 5-10s / standard: 8-20 min / deep: 20-40 min |

#### 4.4.1 Depth Behavior

**Depth `surface` (heuristic, không AI):**

```
Heuristic grouping algorithm:
1. Skip known non-module directories: src/, lib/, app/, tests/, config/, public/, static/, dist/, build/, scripts/, node_modules/, vendor/, .git/, target/
2. Tại first meaningful directory level dưới non-module dirs:
   - Mỗi directory = 1 module candidate (VD: src/billing/ → module "billing")
   - Files trực tiếp trong module dir thuộc module đó
3. Nếu files flat (không subdirs):
   - Group theo file naming pattern (VD: billing-*.ts → module "billing")
4. Naming normalization: lowercase-kebab-case (CORE-016/017)
5. Files unknown → module "uncategorized"
6. Output: classified/auto-grouped.json
7. Không tạo glossary (surface skip glossary)
```

**Depth `standard` (AI basic, khớp v4.1 classify):**

```
1. Batch files theo batch_size (default 100, configurable --batch-size)
2. Per batch:
   - Spawn code-reviewer agent với prompt từ templates
   - Agent classify files → {path, system, module, category, confidence}
   - Write classified/batch-N.json
   - Checkpoint sau mỗi batch (L2 checkpoint)
3. Sau tất cả batches:
   - Generate glossary.json (business-analyst agent 1 lần)
   - Apply naming normalization → classify-naming-fixes.json
4. POST-GATE coverage ≥95%
```

**Depth `deep` (AI + domain expert enrichment):**

```
1. Same as standard, thêm:
2. Domain expert review (1 agent per detected_domain):
   - Review module boundaries (có module nào bị split/merge sai không?)
   - Enrich glossary với domain-specific terminology
3. Cross-validate naming convention với domain conventions
4. Output: classified/batch-N.json + glossary.json (enriched) + module-review.json
```

#### 4.4.2 Exit Criteria (POST-GATE T1-T4)

| Tier | Check | surface | standard | deep |
|------|-------|---------|----------|------|
| **T1** | Classified files tồn tại | ✅ auto-grouped.json | ✅ batch-*.json | ✅ batch-*.json |
| **T2** | Coverage ≥95% | N/A (heuristic — all files grouped) | ✅ | ✅ |
| **T3** | Naming consistency (CORE-016) | ✅ | ✅ | ✅ |
| **T4** | Glossary non-empty | N/A (skip) | ✅ ≥20 terms | ✅ ≥30 terms + domain terms |

**Auto-fix (max 3 iterations):**
- Coverage <95% → re-prompt agent với uncovered files
- Naming violation → apply normalization rules
- Glossary empty → retry agent with explicit prompt

**ESCALATE khi:**
- Auto-fix fail 3 lần
- Agent timeout 3 lần
- POST-GATE T2 vẫn <80% sau 3 attempts

---

### L5 — Extraction

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Trích xuất requirements, features, acceptance criteria, domain knowledge từ code+docs |
| **Phương thức** | Adaptive depth |
| **Agent** | surface: skip / standard: business-analyst + 1 domain-expert / deep: business-analyst + 1 domain-expert (enriched prompt) |
| **Input** | classified files, glossary, project-profile, dependency-graph, scan-state.ips.phase_b.module_routing |
| **Output** | extracted/*.json (per module), dedup-report.json, module-code-mapping.json |
| **Thời gian ước lượng** | surface: 0 (skip) / standard: 15-30 min / deep: 30-60 min |

#### 4.5.1 Depth Behavior

**Depth `skip` (surface profile only):**

```
L5 không chạy. scan-state.layers.L5.status = "skipped_by_profile"
L6 synthesis tạo condensed context từ L1-L4 only.
```

**Depth `standard` (= v4.1 behaviour, BACKWARD-COMPAT LOCKED):**

```
Per module (topological order, max 3 parallel):
1. Read classified files for module + glossary + dependencies
2. Resolve domain-expert cho module (from scan-state.ips.phase_b.module_routing)
3. Spawn:
   - business-analyst agent (primary) — extract requirements/features
   - 1 domain-expert agent (secondary) — domain-specific validation/enrichment
4. Agents write to extracted/{module}.json
5. Confidence threshold ≥0.6 per requirement
6. Checkpoint sau mỗi module (L2 checkpoint) + intra-module (L3 checkpoint per feature)
```

> **Important:** Standard profile **giữ nguyên v4.1 behaviour** — spawn business-analyst + 1 domain-expert. ADR-LS06 backward-compat lock.

**Depth `deep` (enriched prompt + cross-validation):**

```
Same as standard, thêm:
1. Enriched prompt:
   - Include IPS-detected complexity hotspots
   - Include domain hint signals (package deps, directory names)
   - Request high-confidence extraction (threshold ≥0.8)
2. Cross-validation pass:
   - business-analyst extracts first
   - domain-expert reviews (not just complements)
   - Main context validates convergence
3. Divergence detection (if strategy S5 or profile exhaustive):
   - Compare extracted code REQ vs docs REQ
   - Flag {synced, diverged, undocumented, unimplemented}
   - Output: extracted/{module}-divergences.json
```

#### 4.5.2 Domain Expert Routing Matrix

**Core 7 (bám v4.1 — ADR-LS06 backward-compat lock):**

| Domain | Domain Expert Agent | Signals để detect |
|--------|---------------------|-------------------|
| Finance | `finance-expert` | `decimal.js`, `money.js`; dirs: `billing/`, `invoice/`, `payment/`, `tax/`; imports: invoice\|payment\|tax\|ledger\|vat |
| Procurement | `procurement-expert` | dirs: `procurement/`, `sourcing/`, `vendor/`; keywords: PO, RFQ, supplier, purchase order |
| Sales | `sales-expert` | dirs: `sales/`, `crm/`, `pipeline/`; keywords: quote, deal, opportunity, lead |
| HR | `hr-expert` | dirs: `hr/`, `payroll/`, `leave/`, `recruitment/`; keywords: employee, salary, attendance |
| E-commerce | `ecommerce-expert` | dirs: `cart/`, `checkout/`, `catalog/`, `product/`; keywords: cart, SKU, fulfillment |
| Operations | `operations-expert` | dirs: `inventory/`, `warehouse/`, `stock/`; keywords: stock, dispatch, SKU |
| Compliance | `compliance-expert` | dirs: `audit/`, `compliance/`, `regulatory/`; keywords: GDPR, audit trail, regulation |

**Optional extensions (v5.0 — trigger khi IPS detect mạnh ≥0.75):**

| Domain | Agent | Signals |
|--------|-------|---------|
| Healthcare | `healthcare-expert` | `fhir`, `hl7`; dirs: `patient/`, `clinical/`, `prescription/`, `bhyt/` |
| Logistics | `logistics-expert` | dirs: `shipping/`, `customs/`, `warehouse/`, `tms/`, `wms/`; keywords: HS code, Incoterms |
| Manufacturing | `manufacturing-expert` | dirs: `bom/`, `production/`, `mrp/`; keywords: BOM, work order, routing |
| Retail | `retail-expert` | dirs: `pos/`, `store/`, `cashier/`; keywords: POS, loyalty, cashier |
| Legal | `legal-expert` | dirs: `contract/`, `legal/`; keywords: NDA, MSA, clause |
| Insurance | `insurance-expert` | dirs: `policy/`, `claim/`, `underwriting/`; keywords: premium, deductible |
| Education | `education-expert` | dirs: `course/`, `student/`, `lms/`; keywords: enrollment, curriculum |

**Fallback:** Không có domain match confidence ≥0.6 (v2.1 raised từ 0.4 — xem [09-thresholds-justification.md](09-thresholds-justification.md) §2.1) → dùng `business-analyst` only (không spawn domain expert — tiết kiệm tokens + tránh wrong expert).

> **ADR-LS06 backward-compat guarantee:** Standard profile **luôn** spawn business-analyst + 1 domain-expert per module (nếu match). Nếu không match → business-analyst only. **Không giảm** capability so với v4.1.

#### 4.5.3 Parallel Groups (concurrency)

- Topological sort theo dependency-graph
- Group independent modules (không cross-dependency)
- Max 3 parallel groups per time (ADR-LS12 concurrency cap)
- Max 3 agents per group (business-analyst + 1 domain + 1 synthesis reserved)
- Total concurrent agents ≤ `global_max=8`

#### 4.5.4 Exit Criteria (POST-GATE T1-T4)

| Tier | Check | standard | deep |
|------|-------|----------|------|
| **T1** | Extracted files tồn tại (≥1 module per classified module) | ✅ | ✅ |
| **T2** | avg_confidence per module ≥ threshold | ≥0.6 | ≥0.8 |
| **T3** | Module-code-mapping.json tồn tại + TMP-ID format đúng (`TMP-REQ-*`) | ✅ | ✅ |
| **T4** | Dedup-report.json tồn tại + source_files present per REQ | ✅ | ✅ (+ divergence if S5/exhaustive) |

**Auto-fix (max 3 iterations):**
- avg_confidence < threshold → re-extract với simplified prompt
- Missing source_files → re-prompt với explicit requirement
- TMP-ID format wrong → apply normalization regex

**ESCALATE khi:**
- avg_confidence < threshold sau 3 attempts
- Agent timeout 3 lần
- Domain expert spawn fail + business-analyst fallback cũng fail

---

### L6 — Synthesis

| Thuộc tính | Chi tiết |
|-----------|----------|
| **Mục tiêu** | Tổng hợp L1-L5 thành `project-context.md` + companions + impact graph |
| **Phương thức** | Main context (AI) — luôn chạy, không agent |
| **synthesis_mode** | `condensed` / `full` / `full+insights` / `full+divergence` theo profile |
| **Agent** | Không (main context) |
| **Input** | Tất cả output từ L1-L5 + scan-state.ips |
| **Output** | `project-context.md`, `doc-quality-map.json`, `impl-status-snapshot.json`, `impact-graph.json` (NEW) |
| **Thời gian ước lượng** | 2-5 min (scale với module count) |

#### 4.6.1 Output Structure per synthesis_mode

**`condensed` (≤2,000 tokens):**
```
Sections: Overview, Tech Stack, Module Map (heuristic), Maturity, Domain Hints
Companions: doc-quality-map.json only (no impl-status-snapshot, no impact-graph)
```

**`full` (≤4,000 tokens — = v4.1):**
```
Sections: Overview, Systems, Tech Stack, Module Map, Docs Status, Features Summary, Impl Status
Companions: doc-quality-map.json, impl-status-snapshot.json
Impact graph: basic (dependency-graph re-formatted)
```

**`full+insights` (≤5,000 tokens):**
```
Sections: Full + Domain Insights + Gap Analysis + Complexity Hotspots + Impact Graph Summary
Companions: full + impact-graph.json (enriched with data flow)
```

**`full+divergence` (≤6,000 tokens):**
```
Sections: full+insights + Divergence Notes per module + Risk Summary
Companions: full+insights + divergence-report.md per module
```

#### 4.6.2 Impact Graph (NEW — ADR-LS14)

`impact-graph.json` kế thừa pattern từ wf-fix-bugs v6 (R5 ripple):

```json
{
  "$schema": "impact-graph-v1",
  "nodes": [
    { "id": "crm/customer", "type": "module", "files_count": 12, "feat_ids": ["FEAT-CRM-CUST-001"] }
  ],
  "edges": [
    {
      "from": "crm/customer",
      "to": "finance/ar",
      "relation": "data_dependency",
      "evidence": "invoice.customer_id FK → customer.id",
      "strength": 0.9
    }
  ],
  "synthesis_mode": "full+insights",
  "generated_at": "2026-04-22T10:00:00Z"
}
```

**Relations detected:**
- `code_import` — AST import/export
- `data_dependency` — FK / schema reference
- `event_subscription` — event bus / decorator
- `api_call` — REST/gRPC call (from runtime trace if available)
- `req_cross_ref` — `USES: REQ-X` comment annotation

**Downstream consumers:**
- `/wf-verify-sync` — cross-module REQ-ID validation
- `/wf-fix-bugs` R5 ripple verification
- `/wf-design` (legacy flow) — gap analysis priority

#### 4.6.3 Exit Criteria (POST-GATE T1-T4)

| Tier | Check | Lệnh |
|------|-------|------|
| **T1** | `project-context.md` tồn tại, >500 bytes | CORE-021 anchor |
| **T2** | `doc-quality-map.json` tồn tại | `test -s doc-quality-map.json` |
| **T3** | `impl-status-snapshot.json` tồn tại (skip if synthesis_mode=condensed) | Conditional |
| **T4** | `project-context.md` có ≥6 sections (full+) hoặc ≥4 sections (condensed) | `grep -c "^## " project-context.md` |

---

## 5. Layer Interaction Matrix

```
        L1      L2+IPS-A  L3+IPS-B  L4      L5      L6
L1      ─       │         │         │       │       │
L2      ◄───    ─         │         │       │       │
L3      ◄───    ◄───      ─         │       │       │
L4              ◄────     ◄───      ─       │       │
L5              ◄────     ◄───      ◄───    ─       │
L6      ◄───────◄────     ◄───      ◄───    ◄───    ─

◄─── = "consumes output from"
```

**Data flow:**
- L1 → L2, L3: profile feeds assessment + inventory
- L2 IPS-A → L4, L5: profile recommendation + domain hints
- L3 IPS-B → L4, L5: module routing refinement + complexity hotspots
- L3 → L4, L5: inventory feeds classification + extraction
- L4 → L5: classified modules guide extraction targets
- L1-L5 → L6: synthesis consumes all + builds impact graph

---

## 6. Profile → Depth Mapping (CANONICAL TABLE)

| Profile | L1 | L2 | L3 | L4 | L5 | L6 synthesis_mode | Est. Time (500 files) |
|---------|----|----|----|----|----|-------------------|----------------------|
| **surface** | full | full | full | surface | skip | condensed | 5-10 min |
| **standard** ★ | full | full | full | standard | standard | full | 20-40 min |
| **deep** | full | full | full | deep | deep | full+insights | 45-90 min |
| **exhaustive** | full | full | full | deep | deep | full+divergence | 90-180 min |

★ **standard = v4.1 backward-compat lock** (business-analyst + 1 domain-expert per module).

---

## 7. Incremental Processing

Khi re-scan (staleness check phát hiện changes):

| Layer | Incremental support | Hành vi |
|-------|-------------------|---------|
| L1 | Partial | Re-detect only changed file types. Profile metadata update. |
| L2 | Full | Re-assess từ updated L1 data. Fast. |
| L3 | Partial | Re-inventory changed/new files. Keep unchanged entries. |
| L4 | Delta | Re-classify only changed files. Keep existing module assignments (unless affected by deletion). |
| L5 | Selective | Re-extract only modules with changed files. Use scan cache for unchanged modules. |
| L6 | Full | Re-synthesize từ updated L1-L5. Re-build impact graph. |

**Delta flow:**

```
Staleness check → classify files:
  - UNCHANGED → keep L3/L4/L5 data (cache hit)
  - MODIFIED → re-process L3, mark L4/L5 delta
  - NEW → add to L3, mark L4/L5 delta
  - DELETED → remove from L3, mark affected L4/L5 modules
  - RENAMED → detect via git diff --diff-filter=R (if git) or content hash; treat as DELETE+ADD; trigger full re-classify affected module

Delta L4:
  - Re-classify MODIFIED+NEW files → merge existing
  - Verify no duplicate (same file in multiple modules)
  - IF >20% files affected → auto-upgrade to full re-classify (avoid merge complexity)

Delta L5:
  - Re-extract affected modules (modules containing MODIFIED+NEW+DELETED files)
  - Keep unaffected module extractions
  - IF renames detected → full re-extract affected modules (delta merge unreliable)
```

**Scan cache interaction:** xem [05-profiles-ips.md §6](05-profiles-ips.md) — Scan Cache + Incremental.

---

## 8. Layer-Level Error Handling

| Error Code | Layer | Mô tả | Recovery |
|------------|-------|-------|----------|
| **E-L1-01** | L1 | Detect script crash | Retry 2x → ESCALATE |
| **E-L1-02** | L1 | Invalid project path | ESCALATE (user fix) |
| **E-L2-01** | L2 | Assess script crash | Retry 2x → ESCALATE |
| **E-L2-02** | L2 | IPS-A insufficient data | WARN, use default profile |
| **E-L3-01** | L3 | Inventory script crash | Retry 2x → ESCALATE |
| **E-L3-02** | L3 | Source count drift >20% (T3 fail) | Retry → ESCALATE |
| **E-L3-03** | L3 | IPS-B insufficient data | WARN, skip refinement |
| **E-L4-01** | L4 | Classification coverage <95% | Auto-fix 3x → ESCALATE |
| **E-L4-02** | L4 | Naming convention violation | Auto-fix (CORE-016/017) |
| **E-L4-03** | L4 | Agent timeout | Retry simplified 3x → ESCALATE |
| **E-L4-04** | L4 | Glossary generation fail | Retry 2x → WARN (empty glossary with note) |
| **E-L5-01** | L5 | Agent timeout | Retry simplified → skip module → WARN |
| **E-L5-02** | L5 | avg_confidence < threshold | Retry → ESCALATE (user decides continue/retry) |
| **E-L5-03** | L5 | Domain expert spawn fail | Fallback business-analyst only + WARN |
| **E-L5-04** | L5 | Missing source_files | Re-prompt → ESCALATE |
| **E-L6-01** | L6 | project-context.md generation fail | Retry 3x → ESCALATE |
| **E-L6-02** | L6 | Impact graph build fail | WARN, skip impact graph (non-blocking) |

**Auto-fix loop (Protocol 2):** Tối đa 3 iterations per error. Fail → ESCALATE với specific error message + suggested action.

**ESCALATE flow:** STOP + `phase-summary.md` ghi FAILED state + user quyết định `--resume` hoặc `--retry-layer=L4`.
