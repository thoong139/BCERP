# P-QD2-domain-expert-review: Domain Expert Agent Review

> **Probe ID:** P-QD2-domain-expert-review
> **Type:** agent
> **Depth:** standard, deep, exhaustive
> **Design ref:** P2.01
> **v2.1 (W2.5 — 2026-05-10):** Bo sung Boundary Mode — spawn cap 2 expert agents dong thoi cho cross-module dependencies; cross-merge findings + severity bump khi ca hai dong flag.

## Purpose

Spawn domain expert agents (finance-expert, hr-expert, sales-expert, etc.) de review business correctness cua code trong department scope.

**Standard Mode:** 1 agent per department — review feature correctness, calculations, flow sequences, compliance rules.

**Boundary Mode (v2.1):** Khi registry co `cross_module_dependencies[]`, spawn 2 expert agents dong thoi cho cap (modA-domain + modB-domain) de review boundary — schema match, lifecycle rules, error handling, edge cases. Findings tu ca 2 perspectives → cross-merge → severity bump khi ca 2 dong flag cung vi tri.

## Reuses from

- **Source:** QD2 P-QD2-domain-expert-review.md:36-55 (Agent spawn pattern — `Agent({name, subagent_type, prompt})`)
- **Technique:** Boundary Mode su dung cung Agent spawn pattern nhung spawn 2 agents dong thoi cho 1 cap (max 2 per 03-reuse-ci-parallelism.md §7.2)
- **Diff giu nguyen:** Agent tool call structure, citation requirements (IMP-015), CORE-029 spot-check, signal-v2 schema
- **Diff thay doi:** Standard Mode = 1 agent/dept; Boundary Mode = 2 agents/cap; cross-merge logic + severity_bump() cho overlapping findings

## Procedure

### SENSE
1. Doc `$REGISTRY_PATH` de lay `departments[]` trong scope
2. Map moi department → agent file: `.claude/agents/business/{domain}-expert.md`
3. Map moi department → reference files: `.claude/references/team-expert/{domain}/`
4. Loc ra departments co agent ton tai
5. **[Boundary Mode v2.1]** Doc `cross_module_dependencies[]` tu `$REGISTRY_PATH`:
   ```
   BOUNDARY_PAIRS = []
   IF registry.cross_module_dependencies EXISTS AND len > 0:
     FOR dep IN registry.cross_module_dependencies:
       modA = dep.consumer_module          # e.g., "MOD-QUO"
       modB = dep.provider_module          # e.g., "MOD-CRM"
       entity = dep.entity                 # e.g., "Customer"
       domainA = lookup_department(modA)   # e.g., "sales"
       domainB = lookup_department(modB)   # e.g., "finance"

       # Dieu kien Boundary Mode:
       IF domainA != domainB
          AND agent_file_exists("{domainA}-expert")
          AND agent_file_exists("{domainB}-expert"):
         BOUNDARY_PAIRS.append({
           id: "{modA}-{modB}-{entity}",
           modA, modB, entity, domainA, domainB,
           dep_meta: {
             binding_type: dep.binding_type,
             required_fields: dep.required_fields,
             optional_fields: dep.optional_fields,
             lifecycle_rules: dep.lifecycle_rules,
             events_subscribed: dep.events_subscribed
           }
         })
       ELSE IF domainA == domainB:
         LOG "boundary_same_domain:{modA}-{modB} — skip Boundary Mode, phan tich trong Standard Mode"
   ```

### THINK
1. Build review prompt per department (Standard Mode):
   - Feature specs tu `.mc-data/docs/phase2-features/{sys}/{mod}/*.md`
   - Domain reference tu `.claude/references/team-expert/{domain}/`
   - Code scope tu `src/` hoac `apps/`
2. Xac dinh specific business rules can check (calculations, flow sequences, compliance)
3. **[Boundary Mode v2.1]** Build boundary prompt per pair trong BOUNDARY_PAIRS:
   ```
   FOR pair IN BOUNDARY_PAIRS:
     BOUNDARY_PROMPT_BASE[pair.id] = """
     Phân tích cross-module boundary {pair.modA}↔{pair.modB} cho entity: {pair.entity}.

     Metadata phụ thuộc:
     - binding_type: {pair.dep_meta.binding_type}
     - required_fields: {pair.dep_meta.required_fields}
     - optional_fields: {pair.dep_meta.optional_fields}
     - lifecycle_rules: on_provider_delete={pair.dep_meta.lifecycle_rules.on_provider_delete},
                        on_provider_update={pair.dep_meta.lifecycle_rules.on_provider_update}
     - events_subscribed: {pair.dep_meta.events_subscribed}

     Tập trung 4 areas:
     1. Schema match: Consumer dung dung entity provider? Fields missing/mistyped? Types khop?
     2. Lifecycle rules: on_provider_delete/on_provider_update duoc xu ly dung khong?
     3. Error handling: Khi provider entity khong ton tai/bi xoa → consumer xu ly the nao?
     4. Edge cases: Null handling, empty list, concurrent update, cascade delete.

     QUAN TRONG — Citation requirements (IMP-015):
     - Dung Serena find_symbol() + find_referencing_symbols() de locate exact implementations.
     - Moi finding PHAI cite exact file:line — format: 'src/path/file.ts:42'.
     - Neu flow span nhieu files, list tung file:line trong evidence chain.

     Output: JSON array [{type, description, file_path, line_range, severity, evidence, citation, perspective: "{domain}"}]
     where citation = {serena_refs: ["file:line", ...]}
     """
   ```

### ACT
1. Pre-execution: Trace execution flows via code intelligence (IMP-015):
   ```
   # Use GitNexus to understand execution context before spawning agent
   IF gitnexus available:
     FLOWS = gitnexus_query(query="{dept} business logic workflow")
     EXECUTION_CONTEXT = gitnexus_context(name="{dept}_service OR {dept}Controller")
   ```
2. Spawn domain expert agent (Standard Mode — REUSE pattern :36-55; template: `wf-fix-bugs/procedures/_shared.md §16 Sub-Probe Template` — render 8 CORE-037 sections):
   ```
   Agent(
     name="domain-review-{dept}",
     subagent_type="{domain}-expert",
     model="opus",
     prompt="Review business correctness of features in {dept} department.
             Read feature specs + domain references + code.
             Check: calculations, flow sequences, compliance rules.

             IMPORTANT — Citation requirements (IMP-015):
             - Use Serena find_symbol() + find_referencing_symbols() to locate exact implementations.
             - Use GitNexus gitnexus_query() to trace execution flows for each feature.
             - Every finding MUST cite exact file:line — format: 'src/path/file.ts:42'.
             - Do NOT reference function names without file:line evidence.
             - If a flow spans multiple files, list each file:line in the evidence chain.

             Output: JSON array [{type, description, file_path, line_range, severity, evidence, citation}]
             where citation = {gitnexus_flow: string, serena_refs: [file:line, ...]}"
   )
   ```
3. Cho moi department co agent ton tai, spawn 1 agent (co the parallel)
4. P1→P4 context handoff (IMP-015): Sau khi P1 (domain-expert-review) hoan thanh:
   ```
   DOMAIN_FINDINGS_SUMMARY = {
     dept: dept,
     total_findings: len(P1_findings),
     critical_areas: [finding.file_path for finding in P1_findings if finding.severity in ("critical","high")],
     business_rules_flagged: [finding.type for finding in P1_findings]
   }
   # Luu vao session cho P4 (business-analyst-review) su dung lam enrichment context
   WRITE "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/p1-domain-summary.json" = DOMAIN_FINDINGS_SUMMARY
   ```
5. **[Boundary Mode v2.1]** Spawn boundary pair (max 2 agents dong thoi — per 03-reuse-ci-parallelism.md §7.2). Concurrency guard: throttle by depth max 3 cấp 3 (`_shared.md §16.4`). Template: `_shared.md §16 Sub-Probe Template` — render 8 CORE-037 sections per agent:
   ```
   BOUNDARY_FINDINGS = {}

   FOR pair IN BOUNDARY_PAIRS:
     # Spawn 2 agents DONG THOI (same ACT step, max 2 concurrent per §7.2)
     results_A = Agent(
       name="boundary-{pair.modA}-{pair.modB}-{pair.domainA}",
       subagent_type="{pair.domainA}-expert",
       model="opus",
       prompt=BOUNDARY_PROMPT_BASE[pair.id] +
              "\nBan dang review tu goc do {pair.modA} ({pair.domainA}) — CONSUMER perspective."
     )
     results_B = Agent(
       name="boundary-{pair.modA}-{pair.modB}-{pair.domainB}",
       subagent_type="{pair.domainB}-expert",
       model="opus",
       prompt=BOUNDARY_PROMPT_BASE[pair.id] +
              "\nBan dang review tu goc do {pair.modB} ({pair.domainB}) — PROVIDER perspective."
     )
     # Collect both outputs
     BOUNDARY_FINDINGS[pair.id] = {
       "consumer_findings": results_A,   # findings tu domainA expert
       "provider_findings": results_B,   # findings tu domainB expert
       "pair_meta": pair
     }
   ```

### VERIFY
1. CORE-029 spot-check: moi finding co `type` + `description` non-empty (>= 20 chars)
2. Moi finding co `severity` trong ["critical","high","medium","low"]
3. Convert moi finding (Standard Mode) → Signal:
   ```json
   {
     "probe_id": "P-QD2-domain-expert-review",
     "dimension_id": "QD2",
     "signal_type": "{type}",
     "description": "{description}",
     "target": {"kind": "code", "file_path": "{file_path}", "line_range": [x, y]},
     "suggested_severity": "{severity}",
     "evidence": {"code_snippet": "{evidence}"}
   }
   ```
4. **[Boundary Mode v2.1]** Cross-merge findings + severity bump:
   ```
   FOR pair_id, boundary_data IN BOUNDARY_FINDINGS:
     consumer_findings = boundary_data.consumer_findings  # list from domainA agent
     provider_findings = boundary_data.provider_findings  # list from domainB agent
     merged_set = set()

     # Pass 1: Tim overlapping findings (ca 2 agents dong flag cung vi tri)
     FOR f_A IN consumer_findings:
       FOR f_B IN provider_findings:
         IF signals_overlap(f_A, f_B):
           higher_sev = max_severity(f_A.severity, f_B.severity)
           bumped_sev = severity_bump(higher_sev)
           EMIT signal_v2({
             signal_type: f_A.type,
             description: f_A.description + " [Boundary-confirmed: consumer+provider agree]",
             file_path: f_A.file_path,
             line_range: f_A.line_range,
             suggested_severity: bumped_sev,
             evidence: {consumer: f_A.evidence, provider: f_B.evidence},
             tags: ["boundary_confirmed", "{pair_id}"]
           })
           merged_set.add(id(f_A)); merged_set.add(id(f_B))

     # Pass 2: Emit remaining non-overlapping findings at original severity
     FOR f IN consumer_findings + provider_findings:
       IF id(f) NOT IN merged_set:
         EMIT signal_v2({
           ...f as-is,
           tags: ["boundary_single_perspective", "{pair_id}", f.perspective]
         })

     # Write boundary review summary
     WRITE "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/boundary-review.json" = {
       "boundary_pairs": [
         {
           "pair_id": pair_id,
           "consumer_module": pair_meta.modA,
           "provider_module": pair_meta.modB,
           "entity": pair_meta.entity,
           "consumer_findings_count": len(consumer_findings),
           "provider_findings_count": len(provider_findings),
           "merged_count": len(merged_set) // 2,
           "bumped_signals": [signals with boundary_confirmed tag]
         }
       ]
     }

   # Severity bump logic:
   # "low"      → "medium"
   # "medium"   → "high"
   # "high"     → "critical"
   # "critical" → "critical" (no further bump)

   def signals_overlap(f_A, f_B):
     same_type = (f_A.type == f_B.type)
     same_file = (f_A.file_path == f_B.file_path)
     line_adj  = abs(f_A.line_range[0] - f_B.line_range[0]) <= 10
     RETURN same_type AND same_file AND line_adj
   ```

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json` (signal-v2 schema)
- Standard Mode context: `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/p1-domain-summary.json`
- **[v2.1]** Boundary Mode summary: `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/boundary-review.json` (probe-generated, inline schema)
- Cache policy: **skip** (agent output thay doi theo code)

## Severity Rules

### Standard Mode
| Condition | Severity |
|-----------|---------|
| Calculation error (business formula sai) | HIGH |
| Missing compliance check | HIGH |
| Flow sequence violation | MEDIUM |
| Hardcoded business value | LOW-MEDIUM |

### Boundary Mode (v2.1)
| Condition | Severity |
|-----------|---------|
| Single agent finding — domain-specific | Original agent severity |
| Ca 2 agents dong flag cung location (boundary_confirmed) | severity_bump(max(A, B)) |
| lifecycle_rule khong implement (on_provider_delete ignored) | HIGH (data integrity risk) |
| Schema field mismatch confirmed by both agents | bumped: HIGH→CRITICAL |
| Consumer ignore provider event (single agent flag) | MEDIUM |
| Consumer ignore provider event (both agents flag) | bumped: MEDIUM→HIGH |

## CI-ROUTE

| Step | Tool | Purpose |
|------|------|---------|
| ACT Step 1 pre-execution | GitNexus `gitnexus_query("{dept} business logic")` PRIMARY | Trace execution flows truoc khi spawn agent |
| ACT Step 1 fallback | Grep `$CODE_SCOPE` | Khi GitNexus unavailable |
| Agent internal | Serena `find_symbol()`, `find_referencing_symbols()` | Citation requirement (IMP-015) trong agent prompt |
| Boundary Mode: N/A | Agents tu su dung CI tools internally | Agent probes khong can outer CI-ROUTE |

## Dedup Hints

- Dedup key Standard Mode: `{signal_type}:{file_path}:{line_range[0]}`
- Dedup key Boundary Mode: `{signal_type}:{file_path}:{line_range[0]}:boundary_confirmed`
- Uu tien: `boundary_confirmed=true` signal THAY THE individual perspective signals cho cung location
- KHONG dedup across different entity types hay different pair_ids
- KHONG dedup Standard Mode findings voi Boundary Mode findings (khac probe context)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Agent timeout (>3 min) | Retry 1 lan → fail → skip, note "agent_timeout:{dept}" |
| Agent output invalid JSON | Log WARNING, skip findings, note trong lane-report |
| Khong tim thay agent cho dept | Skip department, note "no_domain_agent:{dept}" |
| Khong co feature specs | Skip review, note "no_feature_specs:{dept}" |
| cross_module_dependencies[] rong hoac khong co | Skip Boundary Mode hoan toan, chi chay Standard Mode |
| domainA == domainB (cung domain) | Skip Boundary Mode cho cap nay, phan tich trong Standard Mode |
| Ca 2 boundary agents deu timeout | Skip pair, ghi "boundary_timeout:{pair_id}" trong boundary-review.json |
| 1 boundary agent timeout | Emit findings cua agent thanh cong tai severity goc (khong bump — thieu ca 2 phia) |
| Agent output thieu `perspective` field | Assume consumer agent = modA-domain; provider = modB-domain |
| Khong co overlap giua cap findings | Emit tat ca findings tai severity goc, note "boundary_no_overlap:{pair_id}" |
| Registry khong co cross_module_dependencies schema | Skip Boundary Mode, warn "registry_no_xmod_schema" |
