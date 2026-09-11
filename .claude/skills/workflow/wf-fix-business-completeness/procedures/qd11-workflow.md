# QD11 Workflow — 3-Pass LLM Analysis

> Procedure này mô tả flow chi tiết 3-pass LLM execution cho QD11 Business Completeness & Enhancement.
> Spawned bởi wf-fix-bugs orchestrator Phase 1 Lane Dispatch.

## PRE-GATE: Skip Check

1. Đọc `dimension.json` → check `skip_conditions`
2. Gọi `bash .claude/scripts/wf-fix-qd11-skip-check.sh --project-root <root> --profile <profile>`
3. Nếu skip → ghi `lane-status.json` với `status=skipped`, `reason=<skip_reason>` → DỪNG
4. Nếu eligible → tiếp tục

## Phase 1: Context Loading

1. Đọc `req-registry.json` → lấy danh sách modules, features, cross_module_dependencies
2. Đọc domain references từ `.claude/references/team-expert/` (nếu có)
3. Xác định module pairs cho cross-module comparison (cùng domain)
4. Load source code cho các module được chọn

## Phase 2: 3-Pass LLM Execution

### Pass 1: Cross-Module Pattern Comparison (HIGH confidence, auto)

**Probe:** `P-QD11-cross-module-comparison`
**Prompt:** `prompts/llm-probe-qd11-cross-module.md`
**Agent:** `business-analyst`
**Confidence:** HIGH (direct code comparison)

1. Spawn Agent với prompt cross-module comparison
2. So sánh entity forms, lists, workflows giữa các module cùng domain
3. Emit signals: MISSING_FIELD, MISSING_FEATURE, TYPE_MISMATCH, VALIDATION_GAP
4. APPEND signals vào `phase4-find-bugs/lanes/QD11-business-completeness/signals.json`

### Pass 3: Registry Gap Detection (HIGHEST confidence, auto)

**Probe:** `P-QD11-registry-gap`
**Prompt:** `prompts/llm-probe-qd11-registry-gap.md`
**Agent:** `business-analyst`
**Confidence:** HIGHEST (registry SSOT)

> Pass 2 (domain heuristic) chạy sau Pass 3.

1. Spawn Agent với prompt registry gap detection
2. Cross-reference req-registry.json requirements vs code implementation
3. Emit signals: UNIMPLEMENTED_REQ, ORPHAN_REQ_ID, GAP_REQ_TO_FEAT
4. APPEND signals vào `phase4-find-bugs/lanes/QD11-business-completeness/signals.json`

> **Pass 1 + Pass 3 có thể chạy PARALLEL** (không phụ thuộc lẫn nhau)

### Pass 2: Domain Heuristic Analysis (MEDIUM confidence, deep+ only)

**Probe:** `P-QD11-domain-heuristic`
**Prompt:** `prompts/llm-probe-qd11-domain-heuristic.md`
**Agent:** `business-analyst` + domain expert
**Confidence:** MEDIUM (best practice, not hard requirement)

> Chỉ chạy khi profile ∈ {deep, exhaustive}

1. Spawn Agent với prompt domain heuristic
2. Tham chiếu domain rules từ `.claude/references/team-expert/{domain}/`
3. Emit signals: MISSING_DOMAIN_FIELD, MISSING_COMPLIANCE_CHECK, MISSING_AUDIT_TRAIL, MISSING_BUSINESS_RULE
4. APPEND signals vào `phase4-find-bugs/lanes/QD11-business-completeness/signals.json`

## Phase 3: Signal Validation

1. Validate signals.json schema qua `bash .claude/scripts/wf-fix-qd11-signals-validate.sh`
2. Dedup signals theo fingerprint (dimension + file_path + signal_type + title)
3. Ghi `lane-status.json` với `status=completed`, `probes_executed`, `signals_count`

## POST-GATE: CDG Gate

> Full procedure: `procedures/qd11-cdg-gate.md`

1. Nếu có signals với severity HIGH hoặc CRITICAL → render CDG gate
2. User ACCEPT: ghi enhancement-suggestions.json, mark signals `accepted`
3. User REJECT: mark signals `rejected`, ghi reason
4. MEDIUM/LOW signals: auto-accept (không cần CDG)

## Output Files

| File | Path | Mô tả |
|------|------|-------|
| signals.json | `$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/signals.json` | QD11 signals (lane-signals-v1) |
| lane-status.json | `$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/lane-status.json` | Lane execution status |
| enhancement-suggestions.json | `$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/enhancement-suggestions.json` | CDG gate results |
| lane-report.md | `$SESSION_DIR/phase4-find-bugs/lanes/QD11-business-completeness/lane-report.md` | Lane summary report |
