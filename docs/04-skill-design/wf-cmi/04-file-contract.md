# 04 — File Contract

> **Mục đích file:** Định nghĩa rõ contracts (PRE-GATE/POST-GATE/cross-skill/business invariants) cho wf-cmi — căn cứ để reviewer verify skill tuân thủ CORE-007, CORE-012, CORE-036, và Engine #4 upgrade.

---

## 1. PRE-GATE per phase (forensic — T1→T4)

### Phase 1 — Init + CI PRE-GATE

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | bash | E010 — registry missing → ESCALATE `/wf-brainstorm` hoặc `/existing-project` |
| T2 | `jq -e '.requirements' registry.json` không null | jq | E011 — registry schema invalid |
| T3 | `jq -e '.requirements \| length > 0'` | jq | E012 — registry empty |
| T4 | `test -f .mc-data/docs/phase3-architecture/*.md` | bash | E013 — architecture docs missing (skill chạy sau Phase 3 Architecture, không phải Phase 0) |
| T1b | CI tools detected (GitNexus + Serena, optional) | `ci-detect.sh` | E100 (non-blocking WARN) — fallback Grep |
| T2b | CI index freshness check | `ci-freshness-check.sh` | E100/E101 — light/strong/severe stale (WARN, không block) |

### Phase 2 — Discovery (6 graphs)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f $SESSION_DIR/integrity-status.json` | bash | E020 — Phase 1 state missing |
| T2 | `jq -e '.current_phase == 2'` | jq | E021 — state inconsistency |
| T3 | Code paths scannable (CI route worked OR Grep fallback OK) | composite | E022 — code unreachable |
| T4 | Module list từ registry khớp folder structure | bash | E023 — module-code drift (CORE-013) |

### Phase 3 — Business Invariant Registry

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | 6 graphs từ Phase 2 đầy đủ | bash | E030 — discovery incomplete |
| T2 | `jq -e '.modules \| length > 0'` mỗi graph | jq | E031 — graphs empty |
| T3 | Domain experts available (knowledge files tồn tại) | bash | E032 — team-expert/ missing |
| T4 | Profile cho phép Phase 3 (skip nếu `quick` không LLM) | composite | E033 — profile-phase mismatch (auto-skip, không error) |

### Phase 4 — Coverage Dispatch

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `business-invariants.json` + 6 graphs exist | bash | E040 — phase 3 outputs missing |
| T2 | Lane subdirectory structure ready (`$SESSION_DIR/phase4-coverage/lanes/`) | bash | E041 — session structure invalid |
| T3 | Max concurrency budget (10 agents) available | composite | E042 — system resource limit |
| T4 | Active lanes match profile (vd quick = 5 lanes) | composite | E043 — lane activation mismatch |

### Phase 5 — Aggregate

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Mọi active lane đã produce `signals.json` | bash loop | E050 — lane outputs missing |
| T2 | `jq '.signals \| length >= 0'` mỗi `signals.json` (empty OK, malformed fail) | jq | E051 — signal schema invalid |
| T3 | `signals[].dim` ∈ {CD1..CD10} | jq | E052 — invalid dim |
| T4 | Fingerprint uniqueness (no duplicate signal cross-lane) | bash+sort | E053 — fingerprint collision |

### Phase 6 — Regression Map

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Coverage matrix từ Phase 5 exists | bash | E060 — aggregation missing |
| T2 | `--since` ref valid (nếu set) | git | E061 — invalid ref |
| T3 | GitNexus impact graph available OR fallback git log | composite | E062 — regression intelligence unavailable (downgrade từ predictive → diff-aware, WARN) |
| T4 | Cross-ref: changed files thuộc scope của session | bash | E063 — scope mismatch |

### Phase 7 — GAP + CDG

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | Coverage matrix + invariants + signals đầy đủ | bash | E070 — phase 5-6 outputs missing |
| T2 | CDG protocol available (`/wf-cmi --ci` mode bypass CDG) | composite | E071 — CDG mode invalid in --ci context |
| T3 | Auto-suggest enabled? (check flag) | bash | — (info only, không fail) |
| T4 | Cross-domain conflict resolved (nếu Phase 3 raise CDG E091) | bash | E072 — unresolved CDG decision blocking Phase 7 |

### Phase 8 — Report

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | All previous phases PASS | bash | E080 — pipeline incomplete |
| T2 | All template files exist | bash | E081 — template missing |
| T3 | Coverage matrix consumer-ready | jq | E082 — matrix schema invalid for downstream |
| T4 | Cross-skill artifact path writable | bash | E083 — cannot write `integrity-impact.json` |

---

## 2. POST-GATE per phase (tiered T1→T4 + auto-fix)

### Phase 1 — Init

| Tier | Check | Auto-fix retry |
|------|-------|----------------|
| T1 | `test -f $SESSION_DIR/integrity-status.json` | Retry write (max 3) |
| T2 | `jq '.' integrity-status.json` valid | Re-build từ template `templates/integrity-status.json` |
| T3 | `jq -e '.session_id != null and .current_phase == 1'` | Re-generate session ID + reset state |
| T4 | Lock acquired + heartbeat daemon started | Re-acquire lock (kill stale daemon) |

### Phase 2 — Discovery

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | 6 graph files exist | Re-run individual graph build |
| T2 | Mỗi graph có schema valid (`$schema`, `nodes[]`, `edges[]`) | Re-build từ template |
| T3 | Mỗi graph có ≥1 node (không rỗng) | Re-scan code với CI fallback Grep |
| T4 | Cross-graph consistency: module-graph nodes appear trong entity-graph | Re-aggregate |

### Phase 3 — Invariant Registry

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `business-invariants.json` exists | Re-run inference |
| T2 | Schema `business-invariants-v1` valid | Re-build từ template |
| T3 | ≥1 invariant per active domain | Re-prompt domain expert |
| T4 | No invariant với `severity=MUST` thiếu `source_doc` | Re-link source docs |

### Phase 4 — Coverage Dispatch

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | Mọi active lane có `signals.json` + `Phase4-report.md` | Re-spawn lane agent (max 1 retry per-lane) |
| T2 | Schema `signals-v1` valid mỗi lane | Re-prompt agent với clarified output contract |
| T3 | Signal count claimed = actual file count | Re-validate (vi phạm = E047 data inconsistency) |
| T4 | Mỗi signal có fingerprint unique | Dedupe |

### Phase 5 — Aggregate

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `coverage-matrix.json` + `coverage-report.md` exist | Re-aggregate |
| T2 | Matrix có đủ 10 dims (kể cả dim skip với value=null) | Re-build từ template |
| T3 | Mỗi dim có `coverage_pct` ∈ [0, 100] | Re-compute |
| T4 | `coverage-report.md` ≤15 dòng tiếng Việt (CORE-028) | Re-format |

### Phase 6 — Regression Map

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `regression-map.json` exists | Re-build |
| T2 | Schema valid (predicted_modules[], confidence_scores[]) | Re-build từ template |
| T3 | Mỗi `predicted_module` có `confidence ∈ [0, 1]` | Re-score |
| T4 | Cross-ref với git diff: scanned_files khớp `--since` scope | Re-scope |

### Phase 7 — GAP + CDG

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `gap-report.md` + `gap-suggestions.json` exist | Re-detect |
| T2 | CDG decisions log đầy đủ (mỗi suggestion có user decision) | Re-prompt CDG (max 1 retry, sau đó ESCALATE) |
| T3 | Accepted suggestions có actionable artifact (test/contract/invariant) | Re-generate suggestion |
| T4 | Rejected suggestions có audit log (lý do) | Re-record |

### Phase 8 — Report

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `integrity-report.md` + `integrity-impact.json` exist | Re-write |
| T2 | `integrity-impact.json` có `$schema`, `audit_chain.source`, `audit_chain.checksum` | Re-build từ template |
| T3 | `integrity-report.md` ≤30 dòng tiếng Việt | Re-format |
| T4 | Cross-skill artifact paths khớp `_contract.json.produces_for{}` | Re-validate paths |

---

## 3. Cross-skill contract

### Produces for (downstream consumers)

| Skill consumer | Artifact | Schema | Path | Flag để consume |
|---------------|---------|--------|------|----------------|
| wf-verify-sync | `integrity-impact.json` | `integrity-impact-v1` | `$SESSION_DIR/phase8-report/integrity-impact.json` | `--from-cmi` |
| wf-fix-bugs | `integrity-impact.json` (seed Phase 1) | `integrity-impact-v1` | (same path) | `--from-cmi` |
| wf-implement-feature | `integrity-impact.json` (warn nếu touch invariant đang violate) | `integrity-impact-v1` | (same path) | `--from-cmi` |
| wf-prepare-deployment | `integrity-impact.json` (block release nếu deep+exhaustive coverage < threshold) | `integrity-impact-v1` | (same path) | `--from-cmi` |
| wf-design (NEW projects) | `business-invariants.json` (read-only — design module mới không vi phạm invariant cũ) | `business-invariants-v1` | `$SESSION_DIR/phase3-invariants/business-invariants.json` | implicit (luôn đọc) |
| wf-add-scope | `business-invariants.json` (validate module/feature mới) | `business-invariants-v1` | (same path) | implicit |

### Consumes from (upstream producers)

| Skill producer | Artifact | Schema | Path | Bắt buộc / Optional |
|---------------|---------|--------|------|---------------------|
| wf-brainstorm | `req-registry.json` (v3 nếu đã bump) | `req-registry-v1`/`v3` | `.mc-data/docs/_meta/req-registry.json` | BẮT BUỘC |
| wf-analyze-requirements | `phase1-business/*.md` + `dept-digests.json` | `req-registry-v1` + markdown | `.mc-data/docs/phase1-business/` + `_meta/` | BẮT BUỘC |
| wf-define-features | `phase2-features/[sys]/[mod]/[feat].md` | markdown | `.mc-data/docs/phase2-features/` | BẮT BUỘC |
| wf-design | `phase3-architecture/*.md` + `design-input-digest.json` | markdown + JSON | `.mc-data/docs/phase3-architecture/` + `_meta/` | BẮT BUỘC |
| wf-implement-feature | `impl-status.json` (per FEAT) | `impl-status-v2` | `.mc-data/work/wf-implement-feature/{sys}/{feat}/sessions/{id}/impl-status.json` | OPTIONAL (`--from-impl`) |
| wf-fix-bugs | `fix-impact.json` | `fix-impact-v1` | `.mc-data/work/wf-fix-bugs/sessions/{id}/phase7-verify/fix-impact.json` | OPTIONAL (`--from-fix-bugs`) |
| wf-verify-sync | `verify-sync-impact.json` | TBD | `.mc-data/work/wf-verify-sync/sessions/{id}/verify-sync-impact.json` | OPTIONAL (`--from-verify-sync`) |
| wf-e2e-finding | `cross-module-gaps.md` (per FEAT) | markdown | `.mc-data/work/wf-e2e-verify/sessions/{id}/cross-module-gaps.md` | OPTIONAL |
| wf-legacy-scan | `module-code-mapping.json` (LEGACY mode) | TBD | `.mc-data/work/legacy-scan/module-code-mapping.json` | OPTIONAL (auto-detect LEGACY_MODE qua CORE-021) |

---

## 4. Artifact schemas

### 4.1 `integrity-status.json` (pipeline state SSOT)

Xem [03-phase-routing.md](03-phase-routing.md) §5 cho schema đầy đủ.

### 4.2 `business-invariants.json` (Engine #4 producer)

```json
{
  "$schema": "business-invariants-v1",
  "session_id": "string",
  "generated_at": "string (ISO 8601)",
  "scope": {"type": "system|module|feat", "modules": ["array<string>"]},
  "invariants": [
    {
      "id": "INV-CRM-001",
      "kind": "precondition|postcondition|invariant",
      "expression": "customer.sales_owner.id IS NOT NULL AND HRM.Employee[id=customer.sales_owner.id].is_active = true",
      "severity": "MUST|SHOULD|MAY",
      "modules_involved": ["crm", "hrm", "settings"],
      "source_doc": "phase1-business/sales.md#L42",
      "source_docs_extended": ["phase2-features/crm/customer-mgmt/feat-create-cust.md#L23"],
      "verified_by": [
        "code:apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommandValidator.cs:L15",
        "unit-test:tests/backend/Eureka.UnitTests/CRM/CreateCustomerValidatorTests.cs:L42"
      ],
      "inferred_by": {
        "pass": 3,
        "agent": "business-analyst",
        "domain": "sales",
        "confidence": 0.92,
        "evidence": ["pattern_match:CRM_Customer_has_FK_to_Employee", "domain_rule:sales_owner_active_required"]
      },
      "status": "proposed|accepted|rejected|stale",
      "cdg_decision_at": "2026-05-15T14:35:00+07:00",
      "approver": "dev.a@erktransport.com"
    }
  ],
  "audit_chain": {
    "source": "$SESSION_DIR/phase2-discovery/entity-graph.json",
    "checksum": "sha256:abc123..."
  }
}
```

### 4.3 `coverage-matrix.json` (Engine #5 + #6 + #7)

```json
{
  "$schema": "coverage-matrix-v1",
  "session_id": "string",
  "profile": "standard",
  "threshold_per_dim_pct": 80,
  "coverage_kind": "full|partial",
  "since_ref": "main",
  "dimensions": {
    "CD1": {
      "name": "Business domain coverage",
      "coverage_pct": 85,
      "violations_count": 3,
      "severity_breakdown": {"MUST": 1, "SHOULD": 2, "MAY": 0},
      "modules_below_threshold": [],
      "status": "PASS",
      "signals_file": "$SESSION_DIR/phase4-coverage/lanes/CD1/signals.json"
    },
    "CD2": {"name": "Entity coverage", "coverage_pct": 92, "status": "PASS", "..."},
    "CD3": {"name": "Workflow coverage", "coverage_pct": 75, "status": "FAIL_THRESHOLD", "..."},
    "CD4": "...",
    "CD5": "...",
    "CD6": "...",
    "CD7": "...",
    "CD8": {"name": "Observability", "coverage_pct": null, "status": "SKIPPED", "reason": "profile=standard"},
    "CD9": "...",
    "CD10": "..."
  },
  "overall_status": "PASS|WARN|FAIL",
  "audit_chain": {"source": "...", "checksum": "..."}
}
```

### 4.4 `regression-map.json` (Engine #6 upgrade)

```json
{
  "$schema": "regression-map-v1",
  "session_id": "string",
  "since_ref": "main",
  "changed_files": ["apps/backend/Eureka.Modules.Orders/Application/Commands/CreateOrderCommand.cs"],
  "predicted_impact": {
    "direct_callers": [{"file": "...", "confidence": 0.95}],
    "transitive_callers": [{"file": "...", "confidence": 0.70, "hops": 2}],
    "affected_modules": [{"module": "finance", "confidence": 0.85, "reason": "Order.Total → Finance.Journal"}],
    "affected_workflows": [{"workflow": "order-to-cash", "confidence": 0.90}],
    "test_plan": [
      {"test_id": "TC-CRM-001", "priority": "HIGH", "reason": "FK Customer.Order touched"},
      {"test_id": "TC-FIN-007", "priority": "MEDIUM", "reason": "Journal entry triggered by Order"}
    ]
  },
  "confidence_threshold": 0.7,
  "audit_chain": {"source": "...", "checksum": "..."}
}
```

### 4.5 `integrity-impact.json` (cross-skill output — chính)

```json
{
  "$schema": "integrity-impact-v1",
  "skill": "wf-cmi",
  "session_id": "2026-05-15-system-eureka-erp-01",
  "scope": {"type": "system", "modules": ["..."]},
  "profile": "standard",
  "generated_at": "2026-05-15T15:10:00+07:00",
  "coverage_matrix_summary": {
    "overall_pct": 82.5,
    "below_threshold_dims": ["CD3"],
    "status": "WARN"
  },
  "violations": [
    {
      "id": "CMI-V-001",
      "dim": "CD1",
      "invariant_id": "INV-CRM-001",
      "severity": "MUST",
      "rule": "customer.sales_owner must exist and active",
      "affected_modules": ["crm", "sales", "hrm"],
      "affected_files": ["apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommand.cs"],
      "suggested_fix_ref": "$SESSION_DIR/phase7-gap-cdg/suggestions/CMI-V-001-fix.md"
    }
  ],
  "regression_scope": {
    "changed_files_count": 12,
    "predicted_affected_modules": ["orders", "finance"],
    "test_plan_count": 8
  },
  "gap_artifacts_suggested": [
    {"kind": "test_case", "id": "CMI-S-001", "path": "...", "status": "pending_user_accept", "target": "tests/backend/Eureka.UnitTests/CRM/"},
    {"kind": "invariant_rule", "id": "INV-CRM-001", "status": "accepted", "target": "req-registry.json#requirements[REQ-CRM-001].invariants[]"},
    {"kind": "contract", "id": "CMI-S-003", "status": "rejected", "reason": "duplicate of existing FluentValidator"}
  ],
  "consumers_recommended_actions": {
    "wf-verify-sync": "Re-run --from-cmi to validate impl status vs new invariants",
    "wf-fix-bugs": "Seed Phase 1 với 1 MUST violation (CMI-V-001)",
    "wf-implement-feature": "Warn nếu touch customer.sales_owner trong upcoming work",
    "wf-prepare-deployment": "CD3 coverage 75% < deep threshold 95% — không recommend release"
  },
  "audit_chain": {
    "source": "$SESSION_DIR/integrity-status.json",
    "checksum": "sha256:def456...",
    "git_commit": "abc12345",
    "git_branch": "feature/order-mgmt",
    "author": {"email": "dev.a@erktransport.com", "name": "Developer A"}
  }
}
```

### 4.6 Lane signal schema (`lanes/CD{N}/signals.json`)

```json
{
  "$schema": "signals-v1",
  "lane": "CD1",
  "agent_subagent_type": "business-analyst",
  "scope": {"type": "system", "modules": ["..."]},
  "scan_duration_sec": 45,
  "signals": [
    {
      "fingerprint": "sha256:...",
      "dim": "CD1",
      "severity": "MUST|SHOULD|MAY|INFO",
      "category": "MISSING_INVARIANT|VIOLATION|GAP|RECOMMENDATION",
      "rule_id": "INV-CRM-001",
      "message": "Customer thiếu sales_owner check trong CreateCustomerCommand",
      "affected_files": ["..."],
      "evidence": [
        {"file": "...", "line": 42, "snippet": "..."}
      ],
      "suggested_action": "Thêm FluentValidator rule customer.SalesOwnerId.NotEmpty()"
    }
  ]
}
```

---

## 5. Atomic write pattern

```bash
# Pattern dùng cho mọi JSON state file trong wf-cmi
atomic_write_json() {
  local file="$1"
  local content="$2"
  local tmp="${file}.tmp.$$"

  # Step 1: build vào tmp
  echo "$content" > "$tmp"

  # Step 2: validate JSON
  if ! jq '.' "$tmp" > /dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi

  # Step 3: atomic move
  mv "$tmp" "$file"

  # Step 4: verify
  test -f "$file" && jq -e '.' "$file" > /dev/null
}
```

Source canonical: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §5.

---

## 6. Business invariants (Engine #4 upgrade — wf-cmi là producer chính)

> **wf-cmi BUMP `req-registry.json` schema v1→v3** (bỏ qua v2 đã planned trong roadmap). Đây là quyết định kiến trúc lớn — xem [ADR-cmi-002 trong 08-tradeoffs-adr.md](08-tradeoffs-adr.md#adr-cmi-002).

### 6.1 Invariants consumed (đọc làm input)

| Source | Field/Section | Skill action (Phase 3) |
|--------|--------------|-----------------------|
| `req-registry.json` v1/v2 | `requirements[].description` + `acceptance_criteria` | Parse heuristic + LLM extract invariant candidates |
| `req-registry.json` v3 (existing) | `requirements[].invariants[]` | Load existing, merge với new inference |
| `phase1-business/[dept].md` | §Business rules, §Constraints, §Postconditions | Inject vào agent prompt §3 cho 3-pass LLM |
| `phase2-features/[sys]/[mod]/[feat].md` | §Invariants, §Postconditions, §Acceptance criteria | Cross-check + extract |
| `phase3-architecture/*.md` | §Cross-module dependencies, §Integration patterns | Build cross-module invariant candidates |
| `.claude/references/team-expert/{domain}/rules.md` | Domain compliance rules (HS Code, GDPR, GAAP, ...) | Enforce trong agent reasoning Pass 2 (domain heuristic) |

### 6.2 Invariants produced/updated (ghi làm output)

| Target | Field/Section | Update mode | Conflict policy |
|--------|--------------|-------------|----------------|
| `.mc-data/work/wf-cmi/business-invariants.json` (CANONICAL — sidecar artifact, KHÔNG registry) | `invariants[]`, `cross_module_dependencies[]` | APPEND-only sau CDG ACCEPT (wf-cmi PRIMARY) | KHÔNG ghi đè existing — CDG E091 nếu conflict |
| `$SESSION_DIR/phase3-invariants/business-invariants.json` | (per-session draft) | PRIMARY this skill | — |
| `$SESSION_DIR/phase3-invariants/invariants-diff.json` | (per-session diff, optional) | PRIMARY this skill | — |
| `req-registry.json` | KHÔNG TOUCH (read-only consumer) | — | wf-cmi KHÔNG bump registry schema (ADR-cmi-002 Revised) |
| Existing phase docs | KHÔNG ghi vào (read-only) | — | — |

**Sidecar workflow:**
1. Phase 3 produces per-session draft tại `$SESSION_DIR/phase3-invariants/business-invariants.json`
2. Phase 7 CDG ACCEPT → sync sang canonical `.mc-data/work/wf-cmi/business-invariants.json` (APPEND mode)
3. Canonical artifact có `audit_chain.source_registry_checksum` ghi sha256 của registry tại session time (detect stale)
4. Consumers đọc canonical qua flag `--from-cmi`, validate `audit_chain.source_registry_checksum` còn match registry hiện tại

### 6.3 Invariant schema (sidecar artifact — `business-invariants-v1`)

```json
{
  "$schema": "business-invariants-v1",
  "artifact_version": "1.0.0",
  "generated_at": "2026-05-15T14:32:00+07:00",
  "generated_by": "wf-cmi",
  "scope": {"type": "system|module|feat", "modules": ["array<string>"]},
  "invariants": [
    {
      "id": "INV-SALES-001-01",
      "req_id_ref": "REQ-SALES-001",
      "kind": "precondition|postcondition|invariant",
      "expression": "customer.sales_owner.id IS NOT NULL AND HRM.Employee[id=customer.sales_owner.id].is_active = true",
      "severity": "MUST|SHOULD|MAY",
      "modules_involved": ["crm", "hrm", "settings"],
      "source_doc": "phase1-business/sales.md#L42",
      "verified_by": [
        "unit-test:tests/backend/Eureka.UnitTests/CRM/CreateCustomerValidatorTests.cs:L42",
        "code:apps/backend/Eureka.Modules.CRM/Application/Commands/CreateCustomerCommandValidator.cs:L15"
      ],
      "inferred_by": {
        "skill": "wf-cmi",
        "session_id": "2026-05-15-system-eureka-erp-01",
        "pass": 3,
        "confidence": 0.92
      },
      "status": "proposed|accepted|rejected|stale",
      "approver": "dev.a@erktransport.com",
      "approved_at": "2026-05-15T14:35:00+07:00"
    }
  ],
  "cross_module_dependencies": [
    {
      "id": "CMD-CRM-HRM-001",
      "type": "FK|event|api-call|cache-shared",
      "from_module": "crm",
      "to_module": "hrm",
      "from_entity": "Customer.SalesOwnerId",
      "to_entity": "Employee.Id",
      "inferred_by": "wf-cmi"
    }
  ],
  "audit_chain": {
    "source_registry_checksum": "sha256:abc123...",
    "source_registry_path": ".mc-data/docs/_meta/req-registry.json",
    "checksum": "sha256:def456..."
  }
}
```

**Note (sidecar pattern):**
- Artifact KHÔNG có `requirements[]` wrapper (vì KHÔNG bump registry schema)
- Mỗi invariant có `req_id_ref` để cross-link với `req-registry.json` qua REQ-ID (lookup khi cần)
- `audit_chain.source_registry_checksum` để detect stale (registry đã thay đổi sau khi artifact produce → consumer warn)

### 6.4 Validation rules (Phase 4 POST-GATE T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `jq '.requirements[].invariants'` không null khi `$schema=business-invariants-v1` | jq | E044 — schema mismatch |
| T2 | Mỗi invariant có `id`, `kind`, `expression`, `source_doc`, `severity` | jq | E045 — invariant incomplete |
| T3 | `source_doc` path tồn tại + line ref valid (relative to project root) | bash | E046 — orphan invariant |
| T4 | Cross-check: invariant referenced bởi ≥1 code/test (qua REQ-ID grep hoặc GitNexus query) | Grep / GitNexus | E102 — unverified invariant (WARN, không block) |
| T5 | `modules_involved` ⊆ registry `modules[]` | jq | E047 — invalid module ref |

### 6.5 Inference workflow (Phase 3 — 3-pass LLM kế thừa QD11)

```
Pass 1 — Cross-module pattern compare:
  Input: entity-graph.json (Phase 2 output)
  Logic: Tìm pattern A.field → B.field FK ở module A nhưng thiếu validation ở module B
  Output: invariant candidates với confidence từ pattern strength

Pass 2 — Domain heuristic (spawn {domain}-expert):
  Input: pattern candidates + team-expert/{domain}/rules.md
  Logic: Ask "rule nào BẮT BUỘC theo industry standard?"
  Output: filtered candidates với domain compliance evidence

Pass 3 — Registry gap detection:
  Input: invariant candidates + req-registry.json + phase1-business/*.md
  Logic: Lọc invariant đã có trong docs nhưng chưa có code/test verification
  Output: prioritized invariant list với verified_by gaps

OUTPUT → CDG (Phase 7):
  Trình bày 5-15 candidate invariants per session
  User ACCEPT (commit vào sidecar artifact `business-invariants.json`) / REJECT (log lý do) / DEFER (chờ session sau)
  ACCEPTED → APPEND vào registry qua Safe-Write
  REJECTED → log audit (không trigger lại trong session sau trừ khi `--force`)
```

### 6.6 Cross-domain conflict resolution

| Tình huống | Action |
|-----------|--------|
| Logistics expert + Finance expert opinion lệch nhau về 1 invariant | CDG E091 — Dual-approval required |
| GDPR (compliance) vs UX (customer-expert) — mobile-customer collect data | CDG E091 — Compliance ưu tiên, UX wrap context |
| Vietnam tax law (finance) vs e-invoice standard (legal) | CDG E091 — Reference Nghị định cụ thể |

### 6.7 Anti-patterns (business invariants)

❌ **Skill tự ghi invariants vào registry KHÔNG qua CDG** — vi phạm BHV-001 + CORE-027
❌ **Inferred invariant không có `source_doc` reference** — không truy vết được nguồn gốc
❌ **Override `invariants[]` cũ thay vì APPEND** — vi phạm CORE-006 Safe-Write
❌ **3-pass LLM run với cùng prompt cho 24 domain experts** — vi phạm CORE-025 max 10 concurrency; phải route theo `department` trong registry
❌ **Confidence score thấp (<0.5) commit vào registry** — chỉ đưa vào `proposed`, KHÔNG `accepted` qua CDG

---

## 7. Liên kết

- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md)
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Engines overview: [`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) (#4, #5, #15)
- Real example: [`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) §QD11 (3-pass inference pattern)
- ADR: [08-tradeoffs-adr.md](08-tradeoffs-adr.md) ADR-cmi-002 (sidecar artifact (no registry bump) decision)
