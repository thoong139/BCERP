# P-QD1-spec-completeness-check — Spec-to-Code Completeness Verification

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-spec-completeness-check |
| **Loai** | agent |
| **Profile** | deep, exhaustive |
| **Muc dich** | Voi moi feature spec trong phase2-features, liet ke tung requirement point va xac minh co code tuong ung khong. Khac voi P-QD1-agent-feature-verify (chi kiem tra happy path) — probe nay kiem tra TOAN BO requirements (functional + non-functional) trong spec. Phat hien: missing implementation, partial implementation, va spec-code mismatch. |
| **Cache** | skip (agent probe) |
| **Migrates from** | (new in v9.1) |

---

## PRE-GATE

```
IF profile ∉ {deep, exhaustive}:
  SKIP probe — ghi note "skipped_profile_requires_deep_or_exhaustive"

Doc feature list tu req-registry.json:
  FEATURES=$(jq -r '.features // [] | .[] |
    select(.impl_status == "done" or .impl_status == "in_progress") |
    "\(.feat_id)|\(.impl_status)|\(.spec_path // "unknown")"' \
    "$REGISTRY_FILE")

IF FEATURES empty:
  SKIP probe — ghi note "skipped_no_eligible_features"
```

---

## SENSE

### B1: Build feature verification queue

```bash
FEATURE_QUEUE="$RAW_DIR/feature-verification-queue.jsonl"
> "$FEATURE_QUEUE"

# Uu tien: done features truoc (bat ngo neu thieu), in_progress sau
jq -r '.features[] |
  select(.impl_status == "done" or .impl_status == "in_progress") |
  [.feat_id, .impl_status, (.spec_path // ""), (.req_ids // [] | join(","))] | @tsv' \
  "$REGISTRY_FILE" | while IFS=$'\t' read -r feat_id impl_status spec_path req_ids; do

  # Resolve spec file path
  if [ -n "$spec_path" ] && [ -f "$spec_path" ]; then
    RESOLVED_SPEC="$spec_path"
  else
    # Try find in phase2-features
    SPEC_GLOB=$(find .mc-data/docs/phase2-features -name "*${feat_id}*.md" 2>/dev/null | head -1)
    RESOLVED_SPEC="${SPEC_GLOB:-}"
  fi

  if [ -z "$RESOLVED_SPEC" ]; then
    LOG "WARN: No spec file found for $feat_id — skip" >&2
    continue
  fi

  echo "{\"feat_id\":\"$feat_id\",\"impl_status\":\"$impl_status\",\"spec_path\":\"$RESOLVED_SPEC\",\"req_ids\":\"$req_ids\"}" >> "$FEATURE_QUEUE"
done

QUEUE_COUNT=$(wc -l < "$FEATURE_QUEUE" || echo 0)
LOG "INFO: $QUEUE_COUNT features queued for completeness check" >&2
```

### B2: Per-feature requirement extraction

Voi moi feature trong queue, parse spec file de trich xuat danh sach requirement:

```
FOR each feature IN $FEATURE_QUEUE:
  spec_content = READ feature.spec_path

  # Trich xuat requirement points tu spec
  # Cac pattern trong spec:
  #   - Danh sach danh dau: "- **REQ-XXX**: mo ta..." / "1. REQ-XXX: mo ta..."
  #   - Section "Functional Requirements", "Yeu cau chuc nang"
  #   - Bang requirement table
  #   - User stories: "As a... I want..."

  REQUIREMENTS = parse_requirements(spec_content)
  # Moi requirement: { req_id, description, type (functional|non_functional|ui|api|data), priority }

  # Build verification checklist
  VERIFICATION_PLAN = []
  FOR each req IN REQUIREMENTS:
    VERIFICATION_PLAN += {
      req_id: req.req_id,
      description: req.description,
      type: req.type,
      status: "unverified",
      code_evidence: [],
      gap: null
    }
```

### B3: Code evidence collection per requirement

Voi moi requirement trong plan, tim code evidence:

**Functional requirement:**
```bash
# Tim REQ-ID annotation trong code
grep -rn "REQ-ID: $REQ_ID" "$SOURCE_DIR" --include="*.ts" --include="*.tsx" --include="*.py" --include="*.java"

# Tim FEAT-ID reference
grep -rn "FEAT-ID: $FEAT_ID" "$SOURCE_DIR" --include="*.ts" --include="*.tsx" --include="*.py" --include="*.java"

# Neu khong co annotation, tim theo ten function/class (heuristic)
# VD: req "export invoice to PDF" → tim "exportInvoice|invoicePdf|generateInvoicePdf"
```

**API requirement:**
```bash
# Kiem tra API endpoint duoc khai bao
grep -rn "@\(Get\|Post\|Put\|Delete\)" "$SOURCE_DIR" | grep -i "$ENDPOINT_KEYWORD"

# Verify API spec trong phase3-architecture
find .mc-data/docs/phase3-architecture -name "API-*.md" | xargs grep -l "$FEAT_ID"
```

**UI requirement:**
```bash
# Kiem tra UI component
grep -rn "$COMPONENT_NAME\|$PAGE_KEYWORD" "$SOURCE_DIR" --include="*.tsx" --include="*.jsx" --include="*.vue"

# Kiem tra trong Navigation spec
find .mc-data/docs/phase4-ux -name "Navigation-*.md" | xargs grep -l "$ROUTE_KEYWORD"
```

**Data requirement:**
```bash
# Kiem tra schema/model
find "$SOURCE_DIR" -name "*schema*" -o -name "*model*" -o -name "*entity*" -o -name "*migration*" | \
  xargs grep -l "$ENTITY_NAME"
```

---

## THINK

### Requirement coverage analysis

```
FOR each feature IN verification_results:
  TOTAL_REQS = count(requirements)
  COVERED_REQS = count(requirements WHERE code_evidence.length > 0)
  MISSING_REQS = count(requirements WHERE code_evidence.length == 0)
  PARTIAL_REQS = count(requirements WHERE code_evidence suggests incomplete)

  COVERAGE_PCT = COVERED_REQS / TOTAL_REQS * 100

  # Xac dinh severity theo impl_status va coverage
  IF feature.impl_status == "done" AND MISSING_REQS > 0:
    → EMIT signal: "done_feature_missing_requirements" (severity=HIGH)
    → List missing requirements cu the

  IF feature.impl_status == "done" AND COVERAGE_PCT < 80:
    → EMIT signal: "done_feature_low_coverage" (severity=HIGH)
    → Coverage pct + danh sach requirements chua verify duoc

  IF feature.impl_status == "in_progress" AND PARTIAL_REQS > 0:
    → EMIT signal: "in_progress_feature_partial_requirements" (severity=MEDIUM)
    → List partial requirements

  IF feature.impl_status == "done" AND COVERAGE_PCT == 100:
    → PASS (no signal, feature day du)
```

### Spec-Code mismatch detection

```
FOR each REQ-ID found in BOTH spec AND code:
  # Cross-ref code ngu nghi voi spec mo ta
  SPEC_DESC = requirement.description
  CODE_IMPL = code snippet xung quanh REQ-ID annotation

  # Agent nhan xet (LLM-based):
  # - Code co implement dung what spec yeu cau khong?
  # - Co missing edge case nao khong?
  # - Co hardcoded assumption nao khac spec khong?

  IF mismatch detected:
    → EMIT signal: "spec_code_mismatch" (severity=MEDIUM)
    → Spec requirement vs code implementation diff
```

### Confidence calibration

| Loai gap | Confidence | Ghi chu |
|-----------|-----------|---------|
| REQ-ID khong tim thay trong code (done feature) | 0.90 | REQ-ID annotation la bat buoc |
| Function khong tim thay bang heuristic search | 0.65 | Co the function ten khac hoac nam trong external library |
| API endpoint khong tim thay | 0.80 | Route declarations thuong de tim |
| UI component khong tim thay | 0.70 | Component co the nam trong shared library |
| Data model khong tim thay | 0.75 | Schema/model files co cau truc ro rang |
| Spec description khong khop code | 0.60 | Can human review — agent chi flag suspicion |

---

## ACT

### Agent invocation

Spawn `general-purpose` agent:

> **Template:** `wf-fix-bugs/procedures/_shared.md §16 Sub-Probe Template` (8 CORE-037 sections bắt buộc). Render qua substitution table §16.2 trước khi gọi Agent tool.

```
Agent(name="spec-completeness-{feat_id}", subagent_type="general-purpose", model="opus",
  prompt="Verify spec-to-code completeness cho feature {feat_id}.

  DOC spec: {spec_path}
  DOC registry: .mc-data/docs/_meta/req-registry.json (filter {feat_id})

  VOI MOI requirement trong spec:
  1. Trich xuat REQ-ID va mo ta.
  2. Tim code tuong ung:
     - PRIMARY: Serena find_symbol() + find_referencing_symbols() tim REQ-ID annotation.
     - FALLBACK: grep keyword match.
     - FALLBACK: GitNexus query('{feat_id}') de trace execution flows.
  3. Xac nhan code co implement DUNG requirement khong:
     - Happy path co duoc cover?
     - Edge cases duoc xu ly?
     - Error handling co du?
     - UI/API/Data layers deu co code?
  4. Flag neu phat hien gap.

  OUTPUT: JSON
  {
    \"feat_id\": \"{feat_id}\",
    \"impl_status\": \"{impl_status}\",
    \"total_requirements\": N,
    \"covered_requirements\": N,
    \"missing_requirements\": N,
    \"partial_requirements\": N,
    \"coverage_pct\": XX.X,
    \"requirements\": [
      {
        \"req_id\": \"REQ-...\",
        \"description\": \"...\",
        \"type\": \"functional|api|ui|data\",
        \"status\": \"covered|missing|partial|mismatch\",
        \"code_evidence\": [
          {\"file\": \"...\", \"line\": N, \"symbol\": \"...\", \"match_type\": \"req_id_annotation|heuristic|ci_reference\"}
        ],
        \"gap_description\": \"... (if status != covered)\"
      }
    ],
    \"signals\": [
      {
        \"signal_type\": \"done_feature_missing_requirements|done_feature_low_coverage|in_progress_feature_partial_requirements|spec_code_mismatch\",
        \"severity\": \"high|medium\",
        \"title\": \"...\",
        \"description\": \"...\",
        \"evidence\": {...}
      }
    ]
  }")
```

### Signal emit

Parse agent output → emit signals:

**done_feature_missing_requirements:**
```json
{
  "probe_id": "P-QD1-spec-completeness-check",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "done_feature_missing_requirements",
  "target": {
    "kind": "feature_spec",
    "file_path": ".mc-data/docs/phase2-features/finance/invoicing/FEAT-FIN-INV-EXPORT.md",
    "line_range": [0, 0]
  },
  "description": "Feature FEAT-FIN-INV-EXPORT (impl_status=done) co 3/8 requirements khong tim thay code tuong ung: REQ-FIN-INV-020 (Email invoice sau khi export), REQ-FIN-INV-021 (Retry mechanism khi email fail), REQ-FIN-INV-022 (Audit log export history). Coverage = 62.5% — thap hon 80% threshold. 5 requirements da co code evidence.",
  "evidence": {
    "spec_ref": ".mc-data/docs/phase2-features/finance/invoicing/FEAT-FIN-INV-EXPORT.md",
    "registry_context": "FEAT-FIN-INV-EXPORT co impl_status=done",
    "coverage_pct": 62.5,
    "missing_requirements": [
      {"req_id": "REQ-FIN-INV-020", "description": "Email invoice sau khi export", "type": "functional"},
      {"req_id": "REQ-FIN-INV-021", "description": "Retry mechanism khi email fail", "type": "non_functional"},
      {"req_id": "REQ-FIN-INV-022", "description": "Audit log export history", "type": "data"}
    ],
    "covered_requirements": 5,
    "total_requirements": 8
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_hints": ["FEAT-FIN-INV-EXPORT", "spec-completeness"]
}
```

**spec_code_mismatch:**
```json
{
  "probe_id": "P-QD1-spec-completeness-check",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "spec_code_mismatch",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/src/invoices/invoice.controller.ts",
    "line_range": [88, 105]
  },
  "description": "REQ-FIN-INV-010 yeu cau 'Export invoice voi filter theo date range VA customer category'. Code trong invoice.controller.ts:88 chi implement filter theo date range, thieu filter customer category — spec va code khong khop.",
  "evidence": {
    "code_snippet": "@Get('export')\nasync export(@Query('start') start: string, @Query('end') end: string) {\n  // missing: @Query('category') category: string\n  return this.invoiceService.export({ start, end });\n}",
    "spec_ref": "REQ-FIN-INV-010: Export invoice voi filter theo date range VA customer category"
  },
  "suggested_severity": "medium",
  "fixability": "agent_fix",
  "dedup_hints": ["REQ-FIN-INV-010", "FEAT-FIN-INV-EXPORT"]
}
```

### Write results

```bash
cat > "$RAW_DIR/P-QD1-spec-completeness-check.json" << 'EOF'
$SPEC_COMPLETENESS_SIGNALS
EOF
```

---

## VERIFY

1. Kiem tra moi signal co `signal_type` trong tap `["done_feature_missing_requirements", "done_feature_low_coverage", "in_progress_feature_partial_requirements", "spec_code_mismatch"]`
2. Kiem tra moi signal co `dimension_id == "QD1"`
3. Kiem tra moi signal co `evidence` voi `spec_ref` (path den spec file)
4. Kiem tra `done_feature_missing_requirements` signal co danh sach `missing_requirements[]`
5. Kiem tra `coverage_pct` > 0 va <= 100
6. Kiem tra severity mapping:
   - done_feature_missing_requirements → HIGH
   - done_feature_low_coverage → HIGH
   - spec_code_mismatch → MEDIUM
   - in_progress_feature_partial_requirements → MEDIUM
7. Kiem tra moi signal co `feat_id` reference

---

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Feature done + >=1 requirement hoan toan thieu code | HIGH |
| Feature done + coverage < 80% | HIGH |
| Feature done + coverage < 100% nhung >= 80% | MEDIUM |
| Spec yeu cau X, code implement Y (mismatch) | MEDIUM |
| Feature in_progress + >=3 requirements thieu code | MEDIUM |
| Feature in_progress + 1-2 requirements thieu code | LOW |
| Requirement non-functional thieu (audit, logging, metrics) | LOW (informational) |

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile ∉ {deep, exhaustive} | SKIP probe — ghi note |
| Khong co eligible features (done hoac in_progress) | SKIP probe — ghi note |
| Spec file khong tim thay cho feature | SKIP feature do — LOG WARN |
| Spec file parse khong trich xuat duoc requirements | SKIP feature do — emit signal severity=LOW "unparseable_spec" |
| > 20 features | Sampling: chi verify features done (uu tien) + top 5 in_progress |
| Agent timeout (5 phut) | Emit partial results, ghi probe failure |
| Agent return empty | Emit signal severity=LOW "agent_no_findings" + ghi probe failure |
| Serena unavailable | Fallback grep — LOG WARN, confidence giam 0.15 |
| GitNexus unavailable | Skip execution flow trace — LOG WARN |

---

## Cache Policy

**skip** — agent probe, non-deterministic.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `done_feature_missing_requirements` | `P-QD1-spec-completeness-check:done_feature_missing_requirements:{feat_id}` |
| `done_feature_low_coverage` | `P-QD1-spec-completeness-check:done_feature_low_coverage:{feat_id}` |
| `in_progress_feature_partial_requirements` | `P-QD1-spec-completeness-check:in_progress_feature_partial:{feat_id}` |
| `spec_code_mismatch` | `P-QD1-spec-completeness-check:spec_code_mismatch:{req_id}` |

Cross-probe dedup: `done_feature_missing_requirements` tu probe nay co the overlap voi `coverage_gap` tu P-QD1-req-registry-xref. Aggregator dedup boi feat_id. Probe nay la authoritative cho spec-to-code completeness; QD1 xref la authoritative cho REQ-ID annotation coverage.
