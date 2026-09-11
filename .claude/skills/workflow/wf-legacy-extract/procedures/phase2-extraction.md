# Phase 2: Parallel Extraction

> Main extraction loop — spawn agents (max 3 parallel) per module.
> Mỗi module: business-analyst + domain expert (nếu có) → extract requirements/features/acceptance criteria.
> Checkpoint sau mỗi module. Token-heavy phase — đặc biệt chú ý context budget.

**PRE-GATE:**
- [ ] Phase 1 POST-GATE PASS
- [ ] `$MODULE_MAP`, `$TOPOLOGICAL_ORDER`, `$PARALLEL_GROUPS`, `$DOMAIN_EXPERTS`, `$MODULE_DIGESTS` đã set
- [ ] `$MATURITY_MODE != "skip"`
- [ ] `mkdir -p .mc-data/work/legacy-scan/extracted/` thành công

**INPUT:**
- `$MODULE_MAP`, `$TOPOLOGICAL_ORDER`, `$PARALLEL_GROUPS`, `$DOMAIN_EXPERTS`, `$MODULE_DIGESTS` (in-memory từ Phase 1)
- `classified/glossary.json` (Phase 0)
- `$UI_MANIFEST` (optional — LEGACY_MODE)
- `extracted/*.json` cũ (chỉ khi `$MATURITY_MODE = "delta"`)

**OUTPUT:**
- `.mc-data/work/legacy-scan/extracted/{module}.json` — per module
- In-memory: `$EXTRACTED_MODULES`, `$LOW_CONFIDENCE_MODULES`
- Updated: `extract-checkpoint.json` (per module), `extract-status.json` (progress)

---

## Reference Sections

- `_shared.md` §Confidence Score Tiers
- `_shared.md` §Checkpoint Protocol
- `_shared.md` §Template Usage Rule
- `_shared.md` §Scan-State Integration (v5.0 Phase D)
- `_shared.md` §Error Code Reference (E004, E007)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | **Delta mode handling:** Nếu `$MATURITY_MODE = "delta"`: Load `extracted/*.json` cũ, so sánh mtime của source files với `extracted_at` timestamp → chỉ re-extract modules có files thay đổi. Lưu `$SKIP_DELTA_MODULES[]` cho các module không cần re-extract | Read | Delta analysis done |
| 2.2 | **Main extraction loop:** Xem §Extraction Loop (bên dưới) — iterate `$PARALLEL_GROUPS`, spawn agents max 3 parallel trong mỗi group | Agent | All modules processed |
| 2.3 | **Aggregate results:** Sau khi xong toàn bộ loop, collect `$EXTRACTED_MODULES` và `$LOW_CONFIDENCE_MODULES` | — | Arrays ready |
| 2.4 | **Final checkpoint:** Update `extract-checkpoint.json` với `position.current_phase = 2`, `position.phase_complete = true`, `progress.modules_completed = N_total` | Write | Checkpoint saved |

---

## Extraction Loop (Step 2.2)

```
FOR group IN $PARALLEL_GROUPS (theo thứ tự):
  # Spawn up to 3 agents đồng thời trong group
  parallel_agents = []
  FOR module IN group:
    # Skip nếu delta mode và module không thay đổi
    IF module IN $SKIP_DELTA_MODULES: continue
    
    # SKIP-IF-EXISTS check (resume support)
    IF test -f .mc-data/work/legacy-scan/extracted/{module}.json \
       && test -s .mc-data/work/legacy-scan/extracted/{module}.json:
      Log: "Skip [module] — extracted file đã có (resume/skip-if-exists)"
      $EXTRACTED_MODULES.append(module)
      # [PHASE D] ensure scan-state reflects pre-existing output
      append_layer_output("L5", "extracted/{module}.json")
      update_module_progress("L5", module, "completed")
      continue
    
    # [PHASE D — Domain expert routing via IPS Phase B]
    # get_domain_expert_for_module enforces ADR-LS06 confidence ≥ 0.6 threshold.
    # Returns None khi không có entry hoặc confidence < 0.6 → BA-only fallback.
    # Prefer helper over $DOMAIN_EXPERTS[module] (Phase 1 compute) — helper
    # is authoritative nguồn (ips.phase_b.module_routing).
    ips_expert = get_domain_expert_for_module(module)
    chosen_expert = ips_expert or $DOMAIN_EXPERTS.get(module)
    
    # Build agent prompt — xem §Agent Prompt Template
    prompt = build_prompt(module, $MODULE_DIGESTS[module], chosen_expert, ...)
    
    # Spawn business-analyst (always) + domain-expert (if chosen_expert != null)
    # Deep depth (Phase D D.7): sequential BA → DE cross-validation.
    # Standard/surface: parallel spawn.
    IF $DEPTH_L5 == "deep" AND chosen_expert:
      result_ba = spawn_sequential Agent(
        subagent_type = "business-analyst",
        prompt = prompt + "[DEEP] Initial extraction pass."
      )
      result_de = spawn_with_context Agent(
        subagent_type = chosen_expert,
        prompt = prompt + "[DEEP] Cross-validate + enrich with domain expertise.",
        context = result_ba
      )
      agent_task = {"ba": result_ba, "de": result_de}
    ELSE:
      agent_task = spawn Agent(
        subagent_type = chosen_expert or "business-analyst",
        prompt = prompt
      )
    parallel_agents.append((module, agent_task))
  
  # Đợi tất cả agents trong group hoàn thành (max 3 parallel)
  wait_for_all(parallel_agents)
  
  # Process results per module
  FOR (module, task) IN parallel_agents:
    result = task.result()
    
    # Retry logic (E007)
    IF result.failed:
      retry_count = 0
      WHILE retry_count < 3 AND result.failed:
        result = spawn Agent(...)  # re-spawn
        retry_count += 1
      IF result.failed after 3 retries:
        Log E007: "Module [module] failed after 3 retries — skipping"
        error_log.append({code: "E007", module: module})
        continue
    
    # [READ-TEMPLATE] Write extracted/{module}.json
    READ templates/extracted-module.json (JSON Schema draft-07)
    POPULATE với result.requirements[], result.features[], stats, extracted_at
    WRITE .mc-data/work/legacy-scan/extracted/{module}.json
    VALIDATE: jq '.' extracted/{module}.json (phải pass)
    
    # [PHASE D — CORE-029 spot-check: sample 3 random requirements per module]
    # Min 1 if < 20 reqs. Checks: TMP-ID format, source_files exist,
    # confidence ∈ [0,1], description ≥ 20 chars. Fail → log + attempt 1 retry.
    run_core029_spotcheck(extracted/{module}.json)
    
    # [PHASE D] Sync scan-state: append output + mark module completed.
    append_layer_output("L5", "extracted/{module}.json")
    update_module_progress("L5", module, "completed")
    
    IF write fail:
      E004 — RETRY x3 với exponential backoff
    
    # Confidence warning
    avg_conf = mean(r.confidence for r in result.requirements)
    IF avg_conf < 0.85:
      $LOW_CONFIDENCE_MODULES.append({module: module, avg_conf: avg_conf})
      WARN: "[module] LOW CONFIDENCE [avg_conf] — manual review recommended"
    
    # Update status + checkpoint per module
    Update extract-status.json: progress_pct, extraction_stats, module_status[module] = "done"
    
    # Checkpoint (MEDIUM/LARGE)
    IF $PROJECT_SIZE >= MEDIUM:
      READ templates/extract-checkpoint.json
      POPULATE (trigger.reason="module_complete", position.current_module,
                progress.modules_completed, progress.files_created)
      WRITE .mc-data/work/legacy-scan/extract-checkpoint.json
    
    # Context budget check
    IF $CONTEXT_PERCENT >= 80:
      FORCE STOP after current module — prompt user --resume
    
    $EXTRACTED_MODULES.append(module)
```

---

## Agent Prompt Template

Agent nhận prompt với các phần sau (business-analyst hoặc domain-expert đều dùng chung template):

```
## Task: Extract requirements & features từ module [module_name]

### Context
- Maturity Level: [$MATURITY_LEVEL]
- Source files count: [N]
- Domain: [domain hoặc "generic"]
- Glossary: [trích các terms liên quan từ classified/glossary.json]
- UI Manifest: [JSON nếu $UI_MANIFEST có; otherwise null]

### Input — Module Digest (pre-compressed)
[$MODULE_DIGESTS[module_name]]

### Procedure
Follow: .claude/agents/procedures/business-analyst/legacy-scan-extract.md

### Special modes
- IF $MATURITY_LEVEL == "DOCS_ONLY":
  → Bước 0B: extract TỪ DOCS ONLY (không có source code)
  → Cap confidence tối đa 0.7
  → Tất cả requirements có source = "doc" và notes chứa [DERIVED FROM DOCS]
- IF $UI_MANIFEST có:
  → Bước 2U: UI Screen Analysis — map requirements với screens từ manifest
  → Thêm field `ui_screens[]` vào mỗi requirement liên quan UI

### Acceptance Criteria Generation (bắt buộc)
Cho mỗi requirement:
- Có source code/tests → derive criteria từ test assertions, endpoint behavior
- Chỉ có docs → derive từ business rules trong doc
- Format: "GIVEN [context] WHEN [action] THEN [expected]"
- Minimum 2 criteria per requirement

### Output format
Return JSON matching schema trong templates/extracted-module.json:
- module, system, requirements[], features[], stats, extracted_at
- Mỗi requirement: id (TMP-[MODULE]-NNN), title, description, confidence,
  confidence_reason, source_files, keywords_matched, glossary_terms,
  acceptance_criteria

### Limits (để tránh context overflow)
- Max 50 requirements per module
- Max 30 features per module
- Nếu vượt → trim low-confidence items (< 0.5) trước
- Nếu vẫn vượt → REPORT BACK cho skill để xem xét tách sub-module
```

---

## Temporary ID Convention

Requirements trong extract output dùng **TMP-[MODULE]-[NNN]** (vd: `TMP-AUTH-001`).

**Lý do:** REQ-IDs chính thức được gán ở Stage 4d (build registry) khi đã biết đầy đủ context toàn hệ thống. Tránh conflict giữa các modules extract song song.

---

## extracted/{module}.json Required Fields

| Field | Bắt buộc | Mô tả |
|-------|----------|-------|
| `module` | ✓ | Normalized module name |
| `system` | ✓ | System chứa module (từ classified data) |
| `requirements[]` | ✓ | Array requirements (có thể rỗng) |
| `features[]` | ✓ | Array features (có thể rỗng) |
| `stats` | ✓ | `{total_requirements, total_features, high_confidence_count, inferred_count, guessed_count}` |
| `extracted_at` | ✓ | ISO 8601 timestamp |

**Per-requirement required fields:**

| Field | Bắt buộc | Mô tả |
|-------|----------|-------|
| `id` | ✓ | `TMP-[MODULE]-[NNN]` |
| `title` | ✓ | Ngắn gọn |
| `description` | ✓ | Chi tiết |
| `confidence` | ✓ | 0.0 - 1.0 |
| `confidence_reason` | ✓ | Giải thích score |
| `source_files` | ✓ | Array file paths |
| `keywords_matched` | ✓ | Array keywords |
| `glossary_terms` | — | Array terms (default [] nếu không có) |
| `acceptance_criteria` | — | Array criteria (default [] nếu không suy ra được) |

> **JSON Schema:** `templates/extracted-module.json` là JSON Schema chính xác cho output.
> **BẮT BUỘC** READ template trước khi ghi output (CORE-031).

---

## Error Handling trong Loop

| Error | Xử lý |
|-------|-------|
| Agent timeout | Retry x3 với exponential backoff; sau 3 lần → log E007, continue |
| Write fail (E004) | Retry x3; check disk space/permissions |
| Agent trả về invalid JSON | Log schema violation, retry 1 lần với schema hint; nếu vẫn fail → E007 |
| Module không có requirements | Vẫn ghi file với `requirements: []`, warn trong log |
| Context > 90% | FORCE STOP ngay sau module hiện tại, prompt `--resume` |

---

## POST-GATE

- [ ] `$EXTRACTED_MODULES.length > 0` (ít nhất 1 module extracted)
- [ ] Mỗi module trong `$EXTRACTED_MODULES` có file `extracted/{module}.json`
- [ ] Mỗi file: `test -s` pass (non-empty)
- [ ] Mỗi file: `jq '.' extracted/{module}.json` pass (valid JSON)
- [ ] Mỗi file có required fields: `module`, `system`, `requirements`, `features`, `stats`, `extracted_at`
- [ ] Filename khớp normalized module name (lowercase-kebab-case, CORE-017)
- [ ] Nếu `$MODULE_FILTER` set: chỉ có 1 file extracted
- [ ] Checkpoint được update với `position.current_phase = 2`

**Next phase:** `phase3-dedup.md`
