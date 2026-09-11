# Shared Protocols — wf-legacy-extract

> Cross-cutting protocols, state variables glossary, domain expert selection table,
> normalization spec và agent prompt templates được sử dụng bởi nhiều Phase trong wf-legacy-extract.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Quick Links

- See also `§Scan-State Integration (v5.0 Phase D)` for helper API used throughout Phase 0, 2, 5.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Module Name Normalization](#module-name-normalization)
- [Domain Expert Selection](#domain-expert-selection)
- [Confidence Score Tiers](#confidence-score-tiers)
- [Registry Safe-Write](#registry-safe-write)
- [Checkpoint Protocol](#checkpoint-protocol)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [Error Code Reference](#error-code-reference)
- [Template Usage Rule](#template-usage-rule)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$MATURITY_MODE` | Phase 0 | 1, 2 | `full` / `delta` / `skip` từ `ledger.maturity.stage_modes.extract` |
| `$MATURITY_LEVEL` | Phase 0 | 2 (agent) | `CODE_FULL` / `CODE_PLUS_EXTERNAL_DOCS` / `CODE_PLUS_DEVKIT_PARTIAL` / `DOCS_ONLY` |
| `$STRATEGY_ID` | Phase 0 | 3 | `ledger.strategy.id` — xác định S5 để chạy divergence detection |
| `$MODULE_FILTER` | Phase 0 | 1, 2, 5 | Tên module khi `--module` chỉ định (hoặc empty = all) |
| `$RESUME_MODE` | Phase 0 | 1, 2 | Boolean — true nếu `--resume` |
| `$PROJECT_SIZE` | Phase 0 | 0, 2 | `SMALL` / `MEDIUM` / `LARGE` từ project-profile.json |
| `$MODULE_MAP` | Phase 1 | 2, 3, 4, 5 | Object `{normalized_name: [file_paths...]}` từ classified batches |
| `$TOPOLOGICAL_ORDER` | Phase 1 | 2 | Array module names theo thứ tự dependency (parent trước child) |
| `$PARALLEL_GROUPS` | Phase 1 | 2 | Array groups — mỗi group chứa modules độc lập có thể chạy song song |
| `$MODULE_DIGESTS` | Phase 1 | 2 | Object `{module: digest_summary}` từ pre-compression |
| `$DOMAIN_EXPERTS` | Phase 1 | 2 | Object `{module: expert_agent_name}` |
| `$EXTRACTED_MODULES` | Phase 2 | 3, 4, 5 | Array modules đã hoàn thành (có file extracted/{module}.json) |
| `$LOW_CONFIDENCE_MODULES` | Phase 2 | 5 | Array modules có `avg_confidence < 0.85` |
| `$DEDUP_STATS` | Phase 3 | 5 | Object `{merged_count, ambiguous_count, kept_count}` |
| `$MODULE_CODE_MAPPING` | Phase 4 | 5 | Object từ `module-code-mapping.json` |
| `$UI_MANIFEST` | Phase 0 | 2 (agent) | Nội dung `inventory/ui-manifest.json` (optional, LEGACY_MODE) |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget — trigger checkpoint at 65/80% |
| `error_log[]` | All phases | Phase 5 | Array errors — dùng cho report + auto-correction |

---

## Cross-Phase Data Flow

```
Phase 0 (context)      → $MATURITY_MODE, $STRATEGY_ID, $MODULE_FILTER,
                         $PROJECT_SIZE, $UI_MANIFEST, extract-status.json,
                         extract-plan.md (init), extract-checkpoint.json (init)
Phase 1 (resolution)   → $MODULE_MAP, $TOPOLOGICAL_ORDER, $PARALLEL_GROUPS,
                         $MODULE_DIGESTS, $DOMAIN_EXPERTS, extract-plan.md (updated)
Phase 2 (extraction)   → extracted/{module}.json (per module), $EXTRACTED_MODULES,
                         $LOW_CONFIDENCE_MODULES, extract-checkpoint.json (progress)
Phase 3 (dedup)        → extracted/dedup-report.json, $DEDUP_STATS,
                         extracted/{module}-divergences.json (S5 only)
Phase 4 (alignment)    → module-code-mapping.json, $MODULE_CODE_MAPPING,
                         extracted data (updated sau user confirmation)
Phase 5 (verify)       → Ledger + legacy-scan-status.json updated, phase-summary.md,
                         session-log entry (CORE-026)
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Module Name Normalization

> Áp dụng tại Phase 1 Step 1.1 — TRƯỚC KHI build `$MODULE_MAP`.

**Thuật toán:**

```
FOR each module_name trong classified batches:
  1. Lowercase toàn bộ: "CRM" → "crm", "AUTH" → "auth"
  2. Trim whitespace: " sales " → "sales"
  3. Replace spaces/underscores với hyphens: "customer_management" → "customer-management",
     "customer management" → "customer-management"
  4. Output = kebab-case lowercase
```

**Case-insensitive dedup:**
- Sau normalize, 2 modules có cùng normalized name → MERGE thành 1
- Ví dụ: `CRM`, `crm`, `Crm` → tất cả merge thành `crm`
- Log merge event vào `warnings[]` của extract-status.json

**Apply naming fixes từ classify:**
- Nếu `classified/classify-naming-fixes.json` tồn tại → apply fixes TRƯỚC khi build module_map
- Format: `{original_name: normalized_name}` — thay thế original → normalized

**Circular dependencies:**
- Nếu phát hiện circular refs trong dependency graph → WARN E015
- Phá vỡ circular bằng cách break edge có weight thấp nhất
- Log vào `error_log[]`

---

## Domain Expert Selection

| Module domain | Agent bổ sung | Signal để detect |
|--------------|--------------|-----------------|
| Tài chính, kế toán | `finance-expert` | invoice, payment, ledger, vat, tax |
| Thu mua, nhà cung cấp | `procurement-expert` | purchase order, PO, vendor, supplier, sourcing, RFQ |
| Bán hàng, CRM | `sales-expert` | order, cart, customer, deal, pipeline |
| Nhân sự, lương | `hr-expert` | employee, payroll, leave, attendance |
| E-commerce, giỏ hàng | `ecommerce-expert` | product, cart, checkout, fulfillment |
| Vận hành, kho | `operations-expert` | inventory, warehouse, dispatch, stock |
| Pháp lý, tuân thủ | `compliance-expert` | audit, gdpr, regulation, compliance |
| API-only, không rõ domain | Chỉ `business-analyst` | Không có signal rõ ràng |

**Quy tắc khi nhiều domain match:**

1. Đếm số keywords match cho mỗi domain trong classified files của module
2. Chọn domain có **nhiều keywords match nhất** làm primary expert
3. Nếu 2 domains có số match bằng nhau → ưu tiên domain **đặc thù hơn** (vd: `procurement-expert` > `operations-expert` cho module có PO + vendor)
4. Chỉ spawn **1 domain expert bổ sung** (ngoài `business-analyst`) — KHÔNG spawn nhiều experts cho 1 module

---

## Confidence Score Tiers

Mỗi requirement phải có confidence score từ 0.0 đến 1.0.

| Tier | Score | Ý nghĩa |
|------|-------|---------|
| Chắc chắn | >= 0.8 | Trích xuất trực tiếp từ code + doc |
| Suy luận | 0.5 - 0.79 | Suy ra từ tên hàm, tên biến, flow |
| Suy đoán | < 0.5 | Đặt placeholder, WARNING trong report |

**Low-confidence warning:**
- Module có `avg_confidence < 0.85` → log vào `$LOW_CONFIDENCE_MODULES` + `summary.low_confidence_modules[]` trong ledger
- `avg_confidence < 0.6` across all modules → WARNING E022 (Phase 5)
- `avg_confidence < 0.4` across all modules → ESCALATE

---

## Registry Safe-Write

Skill này KHÔNG ghi vào `req-registry.json`. Chỉ ghi vào:
- `.mc-data/work/legacy-scan/extracted/` (extracted module JSON files)
- `.mc-data/work/legacy-scan/module-code-mapping.json`
- `.mc-data/work/legacy-scan/ledger.json` (modify `stages.extract.*` fields only)
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (modify `stages.extract.*`, `current_stage`, `next_action` only)

**Ledger safe-update rules:**
- ĐỌC ledger.json NGAY TRƯỚC KHI GHI — không cache từ đầu session
- CHỈ MODIFY `stages.extract.*`, `summary.by_stage.extracted`, `summary.reqs_extracted`, `summary.features_extracted`, `summary.low_confidence_modules[]`
- Giữ nguyên mọi fields khác
- GHI ATOMIC — single write operation
- VALIDATE: `jq '.' ledger.json` phải pass

---

## Checkpoint Protocol

Multi-session skill — checkpoint sau mỗi module (Phase 2).

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint, STOP sau module hiện tại |
| > 90% | FORCE STOP |

**Resume Process (`--resume`):**

1. READ `legacy-scan-status.json` từ `.mc-data/work/legacy-scan/`
2. LOAD `ledger.json` — extract stage, modules_completed
3. **RECONCILIATION:** List `extracted/*.json` thực tế (loại trừ `dedup-report.json` và `*-divergences.json`).
   So sánh với module list từ classified data → tính `completed_modules[]` (đã có file non-empty) và
   `remaining_modules[]` (chưa có file). Cập nhật `ledger.stages.extract.modules_completed` +
   `legacy-scan-status.json`.
4. Log: "Reconciled: [N]/[total] modules đã extracted, tiếp tục từ module [next_module]"
5. CONTINUE từ `remaining_modules[0]` (theo topological order)

**Checkpoint file template:** `templates/extract-checkpoint.json`

---

## Scan-State Integration (v5.0 Phase D)

> **Áp dụng:** khi skill chạy trong orchestrator mode (có scan-state.json session) HOẶC
> chạy standalone sau khi v5.0 đã migrate (helper auto-detect).
> Legacy mode (chỉ có ledger.json v4.1) — helper tự migrate → scan-state qua 1 call.

### Helper Module

```
Module:  .claude/skills/workflow/_shared/ips/scan_state_reader.py
Public API dùng trong skill này:
- init_or_load_session(project_path) → session_id
  • Active session → return luôn
  • Chỉ có ledger.json v4.1 → migrate + init session mới
  • Không có gì → RuntimeError("No prior scan")
- update_layer_status("L5", status)  # state machine: not_started→in_progress→completed|failed
- update_module_progress("L5", module_name, "completed")  # APPEND + dedup
- append_layer_output("L5", "extracted/{module}.json")  # dedup idempotent
- append_error("L5", {code, message, context})
- get_domain_expert_for_module(module) → str | None
  (respects ADR-LS06 confidence ≥ 0.6 threshold; None → fallback BA-only)
- read_depth_map() → {L5: "surface"|"standard"|"deep"|"skip"}
```

### Usage Pattern trong Phase 0 (context)

```
# Pseudo-code — gọi trong phase0-context.md Steps
SESSION_ID = init_or_load_session(project_path=".")
update_layer_status("L5", "in_progress")
DEPTH_L5 = read_depth_map().get("L5", "standard")  # cho depth-dependent prompts

# Nếu DEPTH_L5 == "skip" → JUMP thẳng Phase 5 mark skipped.
```

### Usage Pattern trong Phase 2 (per module)

```
# Before spawn agent:
expert = get_domain_expert_for_module(module)  # None hoặc "finance-expert", etc.
# Spawn business-analyst + (expert if not None)

# After successful write extracted/{module}.json:
append_layer_output("L5", "extracted/{module}.json")
update_module_progress("L5", module, "completed")
```

### Usage Pattern trong Phase 5 (verify + finalize)

```
# Normal completion (POST-GATE pass):
update_layer_status("L5", "completed")

# Skip mode (maturity):
update_layer_status("L5", "skipped_by_profile")

# Failure after retry exhaust:
update_layer_status("L5", "failed")
append_error("L5", {code: "E022", message: "Avg confidence < 0.4"})
```

### Backward Compat (Dual-write Transition)

- Sub-skill TIẾP TỤC ghi `extracted/{module}.json` + `extract-status.json` + `extract-checkpoint.json`
  trong transition period để không break v4.1 consumer scripts.
- Khi scan-state.json có mặt: dual-write (scan-state + ledger).
- Khi chỉ có ledger.json (standalone sau v4.1 scan): helper tự migrate → scan-state xong rồi dual-write.

### Khi KHÔNG Gọi Helper

- Khi skill kết thúc bằng E001 (PRE-GATE fail) trước khi biết session.
- Khi `--status` handler chỉ đọc (không mutate state).
- Khi hoàn toàn không có scan-state.json VÀ không có ledger.json (trường hợp orphan).

---

## LEGACY_MODE Detection

Tất cả skills detect LEGACY_MODE bằng cùng 1 mechanism (CORE-021):

```
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
```

> wf-legacy-extract LUÔN chạy trong legacy context (part of legacy pipeline).
> Tuy nhiên, Phase 0 Step 0.4u chỉ load `ui-manifest.json` khi file tồn tại VÀ `total_screens > 0`.

---

## Error Code Reference

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | PRE-GATE fail — classify chưa completed | STOP, hướng dẫn chạy `/wf-legacy-classify` |
| E004 | File write fail (extracted/{module}.json) | RETRY x3, check permissions |
| E007 | Extract fail 1 module | RETRY x3, tiếp tục modules khác |
| E008 | Dedup ambiguous (70-85% similarity) | Giữ cả hai, WARNING |
| E015 | Circular dependencies trong dependency graph | WARN, phá vỡ circular ref |
| E020 | Post-Stage verification: missing extracted modules | Auto-fix x3, ASK user |
| E022 | Avg confidence < 0.6 across modules | WARNING, log low-confidence modules |

---

## Template Usage Rule

Mọi file output có template PHẢI tuân theo **READ → POPULATE → WRITE** (CORE-031):

1. **READ** template file từ `templates/` directory
2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
3. **WRITE** output file

> **NẾU SKIP bước READ template → STOP skill.** Không viết từ đầu khi template tồn tại.
> Template files nằm tại: `.claude/skills/workflow/wf-legacy-extract/templates/`

| Template | Output | Khi nào |
|----------|--------|---------|
| `templates/extract-status.json` | `.mc-data/work/legacy-scan/extract-status.json` | Phase 0 init |
| `templates/extract-plan.md` | `.mc-data/work/legacy-scan/extract-plan.md` | Phase 0 init + Phase 1 update |
| `templates/extract-checkpoint.json` | `.mc-data/work/legacy-scan/extract-checkpoint.json` | Phase 0 init + Phase 2 per-module (MEDIUM/LARGE) |
| `templates/extracted-module.json` | `.mc-data/work/legacy-scan/extracted/{module}.json` | Phase 2 — mỗi module |
| `.claude/doc-framework/_meta/phase-summary.template.md` | `.mc-data/work/wf-legacy-extract/phase-summary.md` | Phase 5 (CORE-028) |
