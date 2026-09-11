# P-QD2-business-analyst-review: Business Analyst Flow Review

> **Probe ID:** P-QD2-business-analyst-review
> **Type:** agent
> **Depth:** deep, exhaustive
> **Design ref:** P2.04

## Purpose

Spawn business-analyst agent de review business flows va verify quy trinh duoc implement day du.

## Procedure

### SENSE
1. Doc feature specs tu `.mc-data/docs/phase2-features/`
2. Doc quy trinh nghiep vu tu `.mc-data/docs/phase1-business/`
3. Scan code de tim flow implementations (services, controllers, handlers)

### THINK
1. Map feature specs → implemented flows
2. Xac dinh quy trinh buoc (step-by-step workflows)
3. So sanh spec buoc vs code buoc

### ACT
0. P1→P4 context enrichment (IMP-015): Load P1 domain-expert-review summary if available:
   ```
   P1_SUMMARY = {}
   IF file "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/p1-domain-summary.json" exists:
     P1_SUMMARY = load JSON
   ```
1. Spawn business-analyst agent (template: `wf-fix-bugs/procedures/_shared.md §16 Sub-Probe Template` — render 8 CORE-037 sections):
   ```
   Agent(
     name="ba-flow-review",
     subagent_type="business-analyst",
     model="opus",
     prompt="Review business flow completeness.
             Read feature specs + business docs + code.
             Check: missing steps, wrong order, skipped compliance checks.

             Context from P1 domain-expert-review (focus areas — IMP-015):
             {P1_SUMMARY.business_rules_flagged if P1_SUMMARY else 'none'}
             Critical areas from P1: {P1_SUMMARY.critical_areas if P1_SUMMARY else 'none'}

             IMPORTANT — Citation requirements (IMP-015):
             - Use Serena find_symbol() to locate exact flow implementation files.
             - Use GitNexus gitnexus_query() to trace step-by-step execution.
             - Every finding MUST cite file:line (format: 'src/path/file.ts:42').

             Output: JSON array [{type, description, file_path, line_range, severity, evidence, citation}]"
   )
   ```
2. Agent reviews moi quy trinh nghiep vu va so sanh voi spec

### VERIFY
1. CORE-029 spot-check: moi finding co `type` + `description` non-empty
2. Convert findings → Signals voi `dimension_id: "QD2"`
3. Priority: compliance violations → CRITICAL, missing steps → HIGH, wrong order → HIGH

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json`
- Cache policy: **skip** (agent output thay doi theo code + specs)

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Agent timeout | Retry 1 lan → fail → skip, note "ba_agent_timeout" |
| No feature specs | Skip probe, note "no_feature_specs" |
| No business docs | Proceed voi code-only review, note "no_business_docs" |
