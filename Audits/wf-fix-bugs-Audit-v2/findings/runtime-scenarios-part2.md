# Runtime Scenarios Part 2 — C.7 đến C.12

> **Task:** 4.2 — Analyze runtime scenarios C7-C12: classify each as "needs actual runtime" vs "can verify statically".
> **Date:** 2026-05-12 (Phiên 22)
> **Classification result:** 4 STATIC-VERIFIABLE, 2 NEEDS_RT.

---

## Classification Summary

| Scenario | CP | Description | Classification | Rationale |
|----------|-----|-------------|----------------|-----------|
| C.7 | C1.9.2 | Nested Component Drill-Down | STATIC-VERIFIABLE | Procedure logic defines linear page→click→back traversal; no recursive drill-down instruction. Behavior fully defined, gap known (WARN). |
| C.8 | C1.9.3 | Feature Boundary Completeness | STATIC-VERIFIABLE | Registry-based feature discovery + pattern-based probes fully defined. Sub-flow enumeration gap known (WARN). |
| C.9 | C1.9.7 | Module/System Boundary Coverage | STATIC-VERIFIABLE | Scope logic defined via session args + route enumeration. No file-tree comparison; gap known (WARN). |
| C.10 | C1.10.1 | QD11 Cross-Module Pattern Comparison | **NEEDS_RT** | LLM prompt structure verifiable statically, but cross-module detection QUALITY requires actual LLM execution with multi-module codebase. Non-deterministic output. |
| C.11 | C1.10.6 | QD11 Domain Field Requirements | **NEEDS_RT** | LLM prompt covers 11 domains, but domain rule application + reference file resolution requires actual LLM execution. Non-existent reference paths only fully testable at runtime. |
| C.12 | C1.10.10 | QD11 Skip Conditions | STATIC-VERIFIABLE | Skip logic fully deterministic in bash script (wf-fix-qd11-skip-check.sh): 3 conditions, exit codes 0/2, JSON output. |

**2 of 6 scenarios need actual runtime execution.** C.10 and C.11 involve LLM inference where output quality (pattern detection accuracy, hallucination rate, counter-example adherence) cannot be verified through static procedure analysis alone.

---

## C.7 — Nested Component Drill-Down (C1.9.2)

### Classification: STATIC-VERIFIABLE

### Verification Method: Static trace of runtime probe procedures

### Analysis

**What the scenario tests:** Whether popup/sheet/modal/dialog contents are recursively scanned — form fields inside popups, tables inside sheets, nested dialogs (dialog→form→dialog), tabs/accordions inside popups.

**Procedure coverage (from Stage 1 C1.9.2 findings):**

| Probe | Nested component behavior | Evidence |
|-------|--------------------------|----------|
| Static probes (grep) | Scan ALL source files recursively → inherently find nested components at any depth | N/A (grep-based) |
| P-QD1-deep-ui-traversal A2 | Clicks primary CTAs, checks "Modal/dialog xuất hiện?" → detects opened modals | `:138-142` |
| P-QD9-interactive-smoke A2.5 | After clicking CTA, captures AFTER_SNAPSHOT, checks MODAL_COUNT | `:274-278` |
| P-QD5-ui-traversal-deep (exhaustive) | Clicks up to 5 buttons/page, 500ms wait → post-click snapshot | `:116-131` |

**The procedure logic is FULLY DEFINED:**
1. Visit page → capture snapshot
2. Extract CTAs (buttons, links)
3. Click CTA → wait → capture post-click snapshot
4. Compare DOM/URL/Modal count
5. **Navigate BACK to original page** (`P-QD9:310-315`)
6. Next CTA

**The gap (known from Stage 1):** No recursive drill-down instruction. After clicking a CTA that opens a modal, the probe navigates BACK to the original page rather than drilling into the newly-opened modal to find its child CTAs. A modal containing a form with a "Configure" button that opens a third-level dialog would have innermost components untested.

**Why STATIC-VERIFIABLE:** The procedure logic is fully traceable — the probe visits pages linearly, clicks CTAs, navigates back. There is no recursive drill-down loop, by design. The behavior is well-defined and the gap (no recursion) is known. No runtime execution would reveal anything the static analysis hasn't already found.

---

## C.8 — Feature Boundary Completeness (C1.9.3)

### Classification: STATIC-VERIFIABLE

### Verification Method: Static trace of registry enumeration + probe patterns

### Analysis

**What the scenario tests:** Whether each feature in scope is scanned with ALL sub-flows: list screen, add flow, edit flow, delete flow, empty state, loading state, error state.

**Feature discovery chain (from Stage 1 C1.9.3 findings):**

```
Registry (impl_status=done, has routes)
  → P-QD9-feature-checklist-smoke S1 (jq filter)
  → Navigation specs (.mc-data/docs/phase4-ux/Navigation-*.md)
  → Feature specs (.mc-data/docs/phase2-features/*.md)
  → Code grep (route patterns)
  → CI augmentation (GitNexus query)
  → Build NAV_ROUTES queue
  → Navigate each route → check CTA + state change
```

**Pattern-based coverage (applies to ALL features):**
- QD1 LLM probe: 14 functional bug categories (edge cases, null deref, race conditions)
- QD5 LLM probe: 18 UX/a11y patterns (loading, error, empty states)
- QD2 LLM probe: Business rule detection
- Static probes: REQ-ID xref, calculation checks

**The procedure logic is FULLY DEFINED:** Feature discovery is registry-based (jq filter on impl_status + routes), route navigation is defined in P-QD9-feature-checklist-smoke, and pattern-based LLM probes apply across all discovered routes. 

**The gap (known from Stage 1):** No systematic per-feature sub-flow enumeration. The system doesn't construct "for User Management: list→add→edit→delete→empty→loading→error" and verify each. Instead, it checks patterns globally — "does any feature have a missing loading state?" This means a feature could have 4/5 sub-flows verified, miss 1, and no probe would flag it.

**Why STATIC-VERIFIABLE:** The feature discovery + route navigation logic is fully defined in procedures and prompts. The sub-flow enumeration gap is structural (not a missing procedure) — it's by design that the system uses pattern-based global checking rather than per-feature flow diagrams. Runtime execution would confirm the gap but wouldn't reveal anything the static analysis hasn't already identified.

---

## C.9 — Module/System Boundary Coverage (C1.9.7)

### Classification: STATIC-VERIFIABLE

### Verification Method: Static trace of scope determination + route enumeration

### Analysis

**What the scenario tests:** Whether 100% files in scope are scanned, and every route/endpoint in scope is probed. Compare file tree of scope with scanned files list.

**Scope determination (from Stage 1 C1.9.7 findings):**

| Mechanism | Source | What it covers |
|-----------|--------|----------------|
| Session args | SKILL.md:78-80 | `--scope=all|system|module` + `--name` |
| Incremental scope | phase1-engine.md:139-181 | `git diff --name-only <ref> HEAD` → maps files to modules → SCOPE_MODULES |
| Homepage links | P-QD9-interactive-smoke B1/B2 | Parse `<a href>` → NAV_ROUTES queue (MAX 20/50/100) |
| Registry routes | P-QD9-feature-checklist-smoke S1 | `jq '.requirements[] | select(.impl_status=="done")'` → routes |
| Navigation specs | P-QD9-feature-checklist-smoke S2 | Parse Navigation-*.md → route paths |
| Feature specs | P-QD9-feature-checklist-smoke S3 | Parse phase2-features/*.md → route hints |
| Code grep | P-QD5-ui-traversal-deep B1 | `grep -rnE '(path:|href=|to=|navigate\()...)' src/` |
| CI augmentation | GitNexus query | "navigation, route, link" |

**The procedure logic is FULLY DEFINED:** Route discovery is multi-source (7 mechanisms). File-level coverage is through static grep probes that scan ALL source files in scope. Route-level coverage is through the combined NAV_ROUTES queue.

**The gap (known from Stage 1):** No systematic file-tree-to-scan-results comparison. There is no mechanism that enumerates ALL files in the scope directory, then cross-references with files actually scanned by probes, and reports coverage percentage. The system relies on implicit coverage: if a file is in the scope, grep-based static probes will scan it, and if a route exists, one of the 7 discovery mechanisms will find it. But there's no verification gate.

**Why STATIC-VERIFIABLE:** The 7-mechanism route discovery chain and static grep scan coverage are fully defined in procedures. The gap (no explicit coverage comparison/verification gate) is a design choice, not a missing procedure. Runtime execution would show routes visited and files scanned, but the gap (no TOTAL vs SCANNED comparison) is structural.

---

## C.10 — QD11 Cross-Module Pattern Comparison (C1.10.1)

### Classification: NEEDS_RT

### Verification Method: Static for prompt structure; Runtime for output quality

### Static Analysis (what CAN be verified without runtime)

**Prompt structure (llm-probe-qd11-cross-module.md) — FULLY DEFINED:**

1. **4 comparison areas covered:**
   - §1.1 Entity Form Comparison: MISSING_FIELD, TYPE_MISMATCH, VALIDATION_GAP — with detection criteria
   - §1.2 List/Table Comparison: search, filter, sort, pagination, export
   - §1.3 Action Button Comparison: Save/Cancel/Reset/Delete/Export/Import/Duplicate/Archive
   - §1.4 Workflow Step Comparison: approval, notifications, status transitions

2. **Severity calibration table** — 4 signal types with default severity + bump conditions

3. **5 DO-NOT-EMIT rules:**
   - Naming convention differences → don't emit
   - UI styling differences → don't emit
   - Single-module features → don't emit (no reference)
   - Cross-domain differences → don't emit
   - Library/framework version differences → don't emit

4. **CI tool integration** — Serena + GitNexus instructions for entity inventory, route mapping, validation counting

5. **Examples:** 2 positive (MISSING_FEATURE export, TYPE_MISMATCH discount) + 1 counter-example (CRM vs HR cross-domain)

6. **Infrastructure wiring verified (Stage 1 Task 1.13):**
   - ISG recommender: QD11 weak weight (0.9) for shared/utils + registry changes
   - Lane dispatch: P-QD11-llm-business-completeness probe defined
   - Profile resolver: QD11 activated at standard+ (not quick)
   - Skip check script: 3 conditions, proper exit codes
   - Signal aggregator: QD11 merge path verified

**Known gap (from Stage 1 C1.10.1):** Reliance on `cross_module_dependencies[]` without auto-detection fallback. E116 gracefully skips Pass 1 when array is empty.

### Why NEEDS_RT

Despite the well-structured prompt, **cross-module pattern comparison is inherently an LLM inference task.** The following aspects CANNOT be verified statically:

1. **Pattern detection accuracy:** Does the LLM reliably detect that Module A has `export PDF` but Module B doesn't? This requires running against a real codebase with known differences and checking recall/precision.

2. **Hallucination rate:** Does the LLM invent differences that don't exist (e.g., claiming Module B lacks pagination when it's just implemented differently)? Static analysis can't predict hallucination behavior.

3. **Counter-example adherence:** The prompt has 5 DO-NOT-EMIT rules. Does the LLM actually follow them? For example, will it incorrectly emit a MISSING_FIELD signal when comparing CRM (customer.industry) vs HR (employee.department)? Only runtime testing with a carefully constructed test case can verify this.

4. **Cross-domain boundary enforcement:** The prompt's §3.4 says "Differences do domain khac nhau → KHONG emit." The LLM must correctly identify which modules belong to the same domain. With only `cross_module_dependencies[]` as input (no domain auto-detection), the LLM may compare incorrectly paired modules.

5. **Evidence quality:** The prompt requires `evidence.code_snippet`, `evidence.confidence`, and `evidence.ci_citation`. Does the LLM consistently provide real code snippets (not fabricated), realistic confidence scores (not always 0.95), and valid CI citations?

**Recommended runtime test setup:**
- Create a fixture project with 2 same-domain modules (e.g., Sales + Invoice, both finance)
- Intentionally omit features in Module B (export, pagination, approval workflow)
- Include intentional red herrings (naming convention differences, cross-domain modules)
- Run QD11 Pass 1 → verify: correct MISSING_FEATURE/MISSING_FIELD signals emitted, no false positives from DO-NOT-EMIT rules, evidence contains real code snippets

---

## C.11 — QD11 Domain Field Requirements (C1.10.6)

### Classification: NEEDS_RT

### Verification Method: Static for prompt structure; Runtime for output quality + reference resolution

### Static Analysis (what CAN be verified without runtime)

**Prompt structure (llm-probe-qd11-domain-heuristic.md) — FULLY DEFINED:**

1. **11 domains covered with mandatory fields:**
   - E-commerce/Retail: SKU, price, inventory, category, supplier
   - HR: employee_id, department, position, start_date, salary
   - Finance: amount, currency, date, category, account
   - Logistics: tracking_number, origin, destination, status, weight
   - Healthcare: medical_record_number, dob, blood_type, diagnosis, treatment
   - Insurance: policy_number, coverage_amount, premium, beneficiary
   - Real Estate: property_id, address, area, price, owner
   - Manufacturing: product_code, BOM, production_date, batch_number
   - Procurement: supplier, po_number, delivery_date, payment_terms
   - Legal: contract_number, parties, effective_date, expiration_date
   - Education: student_id, course_code, enrollment_date, grade

2. **Compliance checks** — HIPAA, SOX, PCI-DSS, FERPA, COSO ERM 2017, ISO 31000

3. **Audit trail requirements** — Finance (ledger), Healthcare (access log), Legal (document history), HR (personnel changes)

4. **Domain-specific business rules** — IFRS 15 revenue recognition, HS code classification, 3-bid procurement

5. **4 DO-NOT-EMIT rules** — including "Domain rules not in references → don't emit. Don't invent domain rules."

6. **Severity calibration** — 4 signal types with default severity + bump conditions

**Known gaps (from Stage 1 C1.10.6):**
- References non-existent `domain-rules.md` (positive example §5.1 mentions `.claude/references/team-expert/healthcare/domain-rules.md §2.1` — file doesn't exist)
- Counter-example manufacturing threshold ">50 employees" not found in actual reference files (OBS-038)

### Why NEEDS_RT

1. **Reference file resolution:** The prompt instructs the LLM to read `.claude/references/team-expert/[domain]/` files. The actual files vary by domain (compliance.md, operations.md, controls.md, personas.md, processes.md — NOT domain-rules.md). Only runtime testing can verify whether the LLM:
   - Correctly discovers the right reference files per domain
   - Gracefully handles missing files (the non-existent domain-rules.md)
   - Doesn't fabricate rules when references are ambiguous

2. **Domain rule application quality:** Does the LLM correctly identify that a Healthcare module missing `medical_record_number` is a MISSING_DOMAIN_FIELD, but a Logistics module missing `blood_type` is NOT? This requires domain knowledge reasoning that static analysis can't evaluate.

3. **Compliance framework accuracy:** The prompt mentions SOX, PCI-DSS, HIPAA, FERPA, COSO ERM 2017, ISO 31000. Does the LLM know what fields each framework requires? Will it incorrectly flag PCI-DSS requirements on a non-payment module?

4. **Scale-appropriate judgment (counter-example):** The prompt's §5.3 counter-example teaches "small warehouse doesn't need ISO 9001." Does the LLM actually apply this scale-appropriate reasoning, or does it either flag everything (false positives) or nothing (false negatives)?

5. **Evidence provenance:** Domain rules must come from reference files, not LLM training data. Does the LLM cite actual reference file locations, or does it fabricate evidence? The prompt says "KHONG tu nghi ra domain rule" but there's no structural enforcement.

**Recommended runtime test setup:**
- Use a project with Healthcare domain (has compliance.md, operations.md, personas.md — comprehensive references)
- Intentionally omit mandatory fields (e.g., Patient entity missing blood_type, diagnosis)
- Include intentional non-missing fields (e.g., Patient has medical_record_number — should NOT emit)
- Test with a domain that has sparse references (e.g., Education has only personas.md, processes.md — limited references) → verify LLM gracefully handles limited reference data
- Verify the LLM doesn't emit for the non-existent domain-rules.md path

---

## C.12 — QD11 Skip Conditions (C1.10.10)

### Classification: STATIC-VERIFIABLE

### Verification Method: Static trace of bash script + dimension.json + SKILL.md

### Analysis

**Skip logic is FULLY DETERMINISTIC** — defined in `wf-fix-qd11-skip-check.sh`:

| Check | Line | Condition | Exit Code | JSON Output |
|-------|------|-----------|-----------|-------------|
| 1 | 28-31 | `$PROFILE == "quick"` | 2 (skip) | `{"skip":true,"reason":"profile_quick","detail":"..."}` |
| 2 | 34-39 | `interface_type == "api-only"` | 2 (skip) | `{"skip":true,"reason":"api_only","detail":"..."}` |
| 3 | 41-46 | `module_count < 2` | 2 (skip) | `{"skip":true,"reason":"single_module","detail":"..."}` |
| — | 49-51 | All passed | 0 (run) | `{"skip":false,"reason":"eligible","detail":"..."}` |

**Consistency across all sources:**

| Source | single_module | api_only | profile_quick |
|--------|:---:|:---:|:---:|
| wf-fix-qd11-skip-check.sh | ✓ (jq modules\|length < 2) | ✓ (jq interface_type) | ✓ (bash string match) |
| SKILL.md §Skip Conditions | ✓ (line 44) | ✓ (line 45) | ✓ (line 46) |
| dimension.json:skip_conditions | ✓ (line 173) | ✓ (line 174) | ✓ (line 175) |
| qd11-workflow.md PRE-GATE.2 | ✓ (references script) | ✓ (references script) | ✓ (references script) |
| Audit checklist C1.10.10 | ✓ | ✓ | ✓ |

**Graceful sub-pass degradation (beyond hard skips):**

| Code | Condition | Behavior |
|------|-----------|----------|
| E116 | No `cross_module_dependencies[]` | Skip Pass 1 only, continue Pass 2+3 |
| E117 | No domain references (`team-expert/`) | Skip Pass 2 only, continue Pass 1+3 |
| E118 | No registry (`req-registry.json`) | Skip Pass 3 only, continue Pass 1+2 |

**Error handling:**
- All 3 hard skips emit `lane-status.json` with `status=skipped` + `reason=<reason>`
- Exit code 2 = skip (not error), exit code 0 = run
- Atomic JSON output for consistent parsing

**Why STATIC-VERIFIABLE:** The skip logic is entirely deterministic bash code with SQL-like conditions (string match, jq field extraction, numeric comparison). Every possible input/output combination is traceable:
- quick profile → exit 2, JSON skip
- api-only interface → exit 2, JSON skip
- 1 module → exit 2, JSON skip
- 2+ modules, web UI, standard/deep/exhaustive → exit 0, JSON run
- Missing registry → graceful (modules count = 0 < 2 → skip)
- Empty registry → graceful (jq returns 0 → skip)

The edge case identified in Stage 1 (no explicit "same domain" eligibility check — QD11 runs even with cross-domain modules) is documented but is a prompt-level guardrail (LLM instructed not to compare cross-domain), not a skip logic issue.

---

## Observations

| ID | Scenario | Observation |
|----|----------|-------------|
| OBS-C7-1 | C.7 | Procedure defines linear traversal (page→click→back), not recursive drill-down. Post-modal CTA re-scan would miss buttons inside newly-opened modals. Gap previously documented as C1.9.2 WARN. |
| OBS-C8-1 | C.8 | Feature discovery depends on registry quality (impl_status=done + has routes). Features without route metadata are skipped. Gap previously documented as C1.9.3 WARN. |
| OBS-C9-1 | C.9 | 7 route discovery mechanisms provide good coverage, but no TOTAL_FILES vs SCANNED_FILES comparison gate exists. Gap previously documented as C1.9.7 WARN. |
| OBS-C10-1 | C.10 | Prompt structure is comprehensive (4 areas, severity, examples, counter-examples) but LLM output quality is inherently non-deterministic. cross_module_dependencies[] is sole source for module pairing (no auto-detection). |
| OBS-C10-2 | C.10 | Evidence quality (real code snippets vs fabricated) can only be verified at runtime. The prompt requires evidence.code_snippet but there's no structural validation that the snippet actually exists in source. |
| OBS-C11-1 | C.11 | Positive example references non-existent `domain-rules.md` — only runtime testing can confirm whether the LLM gracefully handles this (skips or fabricates). |
| OBS-C11-2 | C.11 | Domain reference files vary by domain (compliance.md, operations.md, controls.md, personas.md, processes.md). The prompt doesn't specify which file types to look for per domain — LLM must discover. Runtime testing needed to verify this works across all 11 domains. |
| OBS-C12-1 | C.12 | Skip logic is correct and fully deterministic. Minor edge case: modules could be in different domains (HR + Logistics) and QD11 would still run, wasting LLM tokens on meaningless cross-domain comparison. Handled by prompt DO-NOT-EMIT guardrail. |

---

## Overall Assessment

**4/6 scenarios STATIC-VERIFIABLE, 2/6 NEEDS_RT.**

- **C.7, C.8, C.9:** Scan coverage scenarios — procedures fully define the linear/pattern-based discovery logic. Gaps documented as WARNs in Stage 1. Runtime execution would confirm these gaps but wouldn't reveal new findings.
- **C.10, C.11:** LLM-probe quality scenarios — prompt structure is well-defined and verifiable statically, but LLM output quality (pattern detection accuracy, hallucination, counter-example adherence, evidence provenance) is inherently runtime-dependent. These require a multi-module fixture project with known differences for proper validation.
- **C.12:** Skip conditions — fully deterministic bash logic, traceable through all code paths. Previously evaluated as PASS in Stage 1.

**Recommendation:** Before signing off G4, C.10 and C.11 should be validated with runtime testing against a controlled multi-module fixture (at minimum: 2 same-domain modules with intentional feature gaps + counter-example red herrings).
