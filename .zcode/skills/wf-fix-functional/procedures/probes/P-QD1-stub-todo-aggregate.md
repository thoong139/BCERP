# P-QD1-stub-todo-aggregate — Stub/TODO/Coming-Soon Aggregation

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-stub-todo-aggregate |
| **Version** | 2.0.0 |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Quet toan bo codebase tim stub/fake implementations, TODO/FIXME/HACK markers, placeholder returns, empty functions, dead conditionals, "Coming soon" UI, incomplete integration flows. Cross-ref voi `impl_status` trong registry de phan biet incomplete-by-design vs incomplete-by-oversight. |
| **Cache** | allowed (--use-cache) |
| **Migrates from** | v1.0.0 (EUREKA-2026) + P-QD1-stub-todo-scan (MCV3 v9.1). v2.0.0 merge: them registry cross-ref, stub throw/placeholder/empty_func/dead_cond patterns, signal types done_feature_has_todo + in_progress_feature_stub + spec_code_mismatch tu MCV3. |

---

## CI-ROUTE: Stub Detection + Registry Cross-Ref (Protocol 20 §20.5)

> **PRIMARY:** Serena find_symbol tim stub class + find_referencing_symbols tim injection. GitNexus impact() trace blast radius. Registry cross-ref xac dinh incomplete-by-design vs incomplete-by-oversight.

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `find_stub_classes` | **Serena** `find_symbol({name_path_pattern: "Stub*"})` + Grep | Grep only | Tim class/interface co prefix Stub/Mock/Fake |
| `trace_stub_injection` | **GitNexus** `impact({target: "StubClass", direction: "upstream"})` | Grep `import.*Stub\|@Inject.*Stub` | Xac dinh stub bi inject vao production path khong |
| `find_todo_markers` | Grep patterns | — | Tim TODO/FIXME/HACK/Coming soon |
| `cross_ref_registry` | jq parse `req-registry.json` | Skip — emit MEDIUM without context | Map TODO/Stub → impl_status |

**Khi Serena available:** Dung `find_symbol` tim chinh xac stub class + `find_referencing_symbols` tim noi inject.
**Khi GitNexus available:** Trace blast radius cua stub → xac dinh CRITICAL neu stub nam trong production flow.

---

## SENSE

### B1: Phat hien Stub/Fake/Mock classes

```bash
# Tim class/interface co prefix stub (case-insensitive)
grep -rn -i "^[[:space:]]*\(public\|internal\|private\|export\)\s*\(class\|interface\|function\)\s\+\(Stub\|Mock\|Fake\)[A-Za-z]*" \
  src/ apps/ --include="*.cs" --include="*.ts" --include="*.tsx" 2>/dev/null || true

# Tim file co ten stub
find src/ apps/ -iname "*stub*" -o -iname "*fake*" -o -iname "*mock*" 2>/dev/null | \
  grep -iv "test\|spec\|__test__\|__mocks__\|node_modules" || true

# Tim class ke thua tu base class nhung ten co Stub
grep -rn "class\s\+\w*Stub\w*\s*:" apps/backend/ --include="*.cs" 2>/dev/null || true
```

Parse ra `$STUB_CLASSES[]` voi: `{class_name, file_path, line_number, base_class, is_stub: true}`

### B2: Phat hien hardcoded fake values trong stub

```bash
# Tim pattern return gia tri co dinh trong stub class
for FILE in $STUB_FILES; do
  grep -n "return\s\+\(new\|await\|Task\.FromResult\)" "$FILE" 2>/dev/null | \
    grep -v "return\s\+await\s\+_" | head -20
done

# Tim confidence/score/probability hardcoded
grep -rn "confidence\s*[=:]\s*0\.[0-9]\|score\s*[=:]\s*0\.[0-9]\|cost\s*[=:]\s*\$?0\." \
  src/ apps/ --include="*.cs" --include="*.ts" --include="*.tsx" 2>/dev/null || true
```

### B3: Quet TODO/FIXME/HACK markers

```bash
EXCLUDE_DIRS='(node_modules|\.git|dist|build|\.next|coverage|__pycache__|\.mc-data|vendor|generated)'
EXCLUDE_FILES='(\.test\.|\.spec\.|__tests__|__mocks__|\.d\.ts$)'

# TODO comments (tat ca loai file code)
grep -rn "TODO\|FIXME\|HACK\|XXX\|WORKAROUND\|TEMP\|TBD\|@stub\|@incomplete" \
  src/ apps/ --include="*.cs" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
  2>/dev/null | grep -vE "$EXCLUDE_DIRS" | grep -vE "$EXCLUDE_FILES" || true

# TODO co REQ-ID context (quan trong hon)
grep -rn "TODO.*REQ-\|TODO.*ISS-\|TODO.*FEAT-" \
  src/ apps/ --include="*.cs" --include="*.ts" --include="*.tsx" 2>/dev/null || true

# TODO lien quan security/auth/data isolation
grep -rn -i "TODO.*\(auth\|security\|filter\|isolation\|company\|tenant\|permission\|validate\)" \
  src/ apps/ --include="*.cs" --include="*.ts" --include="*.tsx" 2>/dev/null || true
```

Parse ra `$TODO_ENTRIES[]` voi: `{file_path, line_number, content, marker, has_req_id, category}`

### B4: Scan stub implementations (throw/placeholder/empty/dead)

```bash
STUB_RAW="$RAW_DIR/P-QD1-stub-todo-stub.jsonl"
> "$STUB_RAW"

# Pattern 1: throw new Error('Not implemented') / raise NotImplementedError
grep -rn 'throw new Error.*[Nn]ot [Ii]mplemented\|raise NotImplementedError\|NotImplementedException\|unimplemented!\|@NotImplemented' \
  "$SOURCE_DIR" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.py" --include="*.java" --include="*.cs" --include="*.go" --include="*.rs" \
  2>/dev/null | grep -vE "$EXCLUDE_DIRS" | grep -vE "$EXCLUDE_FILES" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  CONTENT=$(echo "$line" | cut -d: -f3- | head -c 200)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"type\":\"stub_throw\",\"content\":\"$(echo "$CONTENT" | sed 's/"/\\"/g')\"}" >> "$STUB_RAW"
done

# Pattern 2: return null/undefined/[] placeholder with TODO comment
grep -rn 'return null;\s*//\|return undefined;\s*//\|return \[\]\s*; //\|return {}\s*; //\|pass\s*#' \
  "$SOURCE_DIR" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
  2>/dev/null | grep -vE "$EXCLUDE_DIRS" | grep -vE "$EXCLUDE_FILES" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  CONTENT=$(echo "$line" | cut -d: -f3- | head -c 200)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"type\":\"placeholder_return\",\"content\":\"$(echo "$CONTENT" | sed 's/"/\\"/g')\"}" >> "$STUB_RAW"
done

# Pattern 3: Empty function bodies with comment suggesting incomplete
grep -rn 'function\s\+\w\+.*{\s*$' \
  "$SOURCE_DIR" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  2>/dev/null | grep -vE "$EXCLUDE_DIRS" | grep -vE "$EXCLUDE_FILES" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  NEXT_LINES=$(sed -n "$((LINENO+1)),$((LINENO+3))p" "$FILE" 2>/dev/null)
  if echo "$NEXT_LINES" | grep -q '^\s*}\s*$'; then
    CONTENT=$(echo "$line" | cut -d: -f3- | head -c 200)
    echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"type\":\"empty_function\",\"content\":\"$(echo "$CONTENT" | sed 's/"/\\"/g')\"}" >> "$STUB_RAW"
  fi
done

# Pattern 4: Dead conditional feature flags
grep -rn 'if\s*(\s*false\s*)\s*{\|if\s*(\s*true\s*)\s*return\s*;' \
  "$SOURCE_DIR" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  2>/dev/null | grep -vE "$EXCLUDE_DIRS" | grep -vE "$EXCLUDE_FILES" | while read -r line; do
  FILE=$(echo "$line" | cut -d: -f1)
  LINENO=$(echo "$line" | cut -d: -f2)
  CONTENT=$(echo "$line" | cut -d: -f3- | head -c 200)
  echo "{\"file\":\"$FILE\",\"line\":$LINENO,\"type\":\"dead_conditional\",\"content\":\"$(echo "$CONTENT" | sed 's/"/\\"/g')\"}" >> "$STUB_RAW"
done

STUB_COUNT=$(wc -l < "$STUB_RAW" || echo 0)
LOG "INFO: Found $STUB_COUNT stub/placeholder implementations" >&2
```

### B5: Phat hien "Coming soon" UI pages

```bash
# Tim "Coming Soon" / "Dang phat trien" / "Chua ho tro" trong page/component
grep -rn -i "coming\s*soon\|dang\s*phat\s*trien\|chua\s*ho\s*tro\|under\s*construction\|placeholder\|chua\s*co\s*du\s*lieu" \
  apps/erp-web/src/ --include="*.tsx" --include="*.ts" 2>/dev/null || true

# Tim page return null hoac empty div
grep -rn "return\s*(\s*<div[^>]*>\s*</div>\s*)\|return\s*null\|return\s*<>\s*</>" \
  apps/erp-web/src/app/ --include="*.tsx" 2>/dev/null || true
```

Parse ra `$COMING_SOON_PAGES[]` voi: `{file_path, line_number, text}`

### B6: Phat hien incomplete OAuth/integration flows

```bash
# Tim TODO trong OAuth/integration code
grep -rn -i "TODO.*\(oauth\|token\|exchange\|callback\|appid\|appsecret\|client.*secret\|refresh_token\)" \
  apps/backend/ --include="*.cs" 2>/dev/null || true

# Tim "chua" + "config" / "chua" + "set" pattern trong comment
grep -rn -i "chưa\|chua.*\(config\|set\|wire\|implement\|build\|create\|register\|add\|map\)" \
  apps/backend/ apps/erp-web/ --include="*.cs" --include="*.ts" --include="*.tsx" 2>/dev/null || true
```

### B7: Cross-ref voi registry de co impl_status context

```bash
REGISTRY_FILE=".mc-data/docs/_meta/req-registry.json"
REQ_ID_MAP="$RAW_DIR/req-id-to-impl-status.json"

# Build map: REQ-ID → { feat_id, impl_status, feature_name }
jq '[.requirements[] | {
  req_id: .req_id,
  feat_id: (.feat_ids // [])[0],
  impl_status: .impl_status // "not_started",
  feature_name: .feature_name // .title // "unknown"
}] | INDEX(.req_id)' "$REGISTRY_FILE" > "$REQ_ID_MAP" 2>/dev/null || echo '{}' > "$REQ_ID_MAP"

# For each TODO/STUB file, try to find REQ-ID annotation nearby
for RAW_FILE in "$TODO_RAW" "$STUB_RAW"; do
  while IFS= read -r entry; do
    FILE=$(echo "$entry" | jq -r '.file')
    LINE=$(echo "$entry" | jq -r '.line')

    # Search 20 lines around the marker for REQ-ID annotation
    START=$((LINE - 20))
    [ "$START" -lt 1 ] && START=1
    END=$((LINE + 5))

    REQ_ID=$(sed -n "${START},${END}p" "$FILE" 2>/dev/null | grep -oE 'REQ-[A-Z]+-[A-Z0-9-]+' | head -1)
    if [ -n "$REQ_ID" ]; then
      IMPL_STATUS=$(jq -r ".[\"$REQ_ID\"].impl_status // \"unknown\"" "$REQ_ID_MAP" 2>/dev/null)
      FEAT_ID=$(jq -r ".[\"$REQ_ID\"].feat_id // \"unknown\"" "$REQ_ID_MAP" 2>/dev/null)
    else
      IMPL_STATUS="unknown"
      FEAT_ID="unknown"
    fi

    echo "$entry" | jq --arg status "$IMPL_STATUS" --arg feat "$FEAT_ID" --arg req "$REQ_ID" \
      '. + {impl_status: $status, feat_id: $feat, req_id: $req}' >> "${RAW_FILE%.jsonl}-enriched.jsonl"
  done < "$RAW_FILE"
done
```

### B8: Scan Cache check (khi --use-cache)

```bash
for FILE in $SCAN_FILES; do
  FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD1-stub-todo-aggregate --probe-version 2.0.0 --file "$FILE")
  HIT=$(python -m _shared.scan_cache.cache_lookup --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP")
  if [ -n "$HIT" ]; then
    cat "$HIT" >> "$ACCUMULATED_SIGNALS"
    continue
  fi
  SCAN_FILES+=("$FILE")
done
```

---

## THINK

### Phan loai stub/TODO theo muc do nguy hiem

1. **CRITICAL — Stub trong production path:**
   - Stub class duoc inject qua DI container
   - Stub class duoc import trong file production (khong phai test)
   - Stub tra ve du lieu gia nhung khong co flag "STUB" / "FAKE" trong response

2. **HIGH — Feature done nhung code con TODO/Stub:**
   - impl_status=done + code co TODO/FIXME/stub → khong nhat quan
   - Feature in_progress + code co stub (throw/placeholder) → gap uu tien
   - TODO lien quan security/auth/data isolation

3. **MEDIUM — TODO/Stub trong feature in_progress:**
   - Feature dang trien khai, TODO la binh thuong nhung can track
   - FIXME/HACK markers khong xac dinh duoc feature
   - Orphan stub khong co REQ-ID → co the la dead code
   - "Coming soon" page da deployed

4. **LOW — Informational:**
   - Empty function body (co the intentional placeholder)
   - Dead conditional feature flag (co the feature flag chua active)
   - TODO co REQ-ID (da duoc track)

### Classification logic

```
FOR each entry IN enriched_entries[]:
  SEVERITY = classify(entry)

  IF entry.impl_status == "done" AND entry has TODO/STUB:
    → HIGH — feature da danh dau done nhung code con TODO/stub
    → Signal type: "done_feature_has_todo"

  ELIF entry.impl_status == "in_progress" AND entry has STUB (throw/placeholder):
    → HIGH — stub code trong feature in_progress la gap can uu tien
    → Signal type: "in_progress_feature_stub"

  ELIF entry.impl_status == "in_progress" AND entry has TODO:
    → MEDIUM — feature dang trien khai, TODO la binh thuong
    → Signal type: "in_progress_feature_todo"

  ELIF entry.impl_status == "unknown" AND entry.type == "stub_throw":
    → MEDIUM — stub throw khong xac dinh duoc feature
    → Signal type: "orphan_stub_implementation"

  ELIF entry.impl_status == "unknown" AND entry.marker IN {FIXME, HACK}:
    → MEDIUM — FIXME/HACK can uu tien fix
    → Signal type: "code_quality_marker"

  ELIF entry.type == "empty_function":
    → LOW — empty function co the la intentional placeholder
    → Signal type: "empty_function_body"

  ELIF entry.type == "dead_conditional":
    → LOW — dead conditional co the la feature flag chua active
    → Signal type: "dead_conditional_feature_flag"

  ELSE:
    → LOW — informational
```

### Exclusion list (KHONG flag)

- TODO/FIXME trong test files (`*.test.ts`, `*.spec.ts`, `*Test.cs`, `*Tests.cs`)
- TODO trong node_modules, .next, dist, .turbo, generated code
- Stub/Mock classes chi nam trong test projects
- "Coming soon" trong marketing/landing page (intentional)
- TODO lien quan performance optimization ("TODO: optimize later")
- Dead conditional co comment "feature flag" hoac "FF_" prefix
- Empty function la arrow function inline (React component placeholders)

### Confidence mapping

| Loai signal | Confidence | Ghi chu |
|-------------|-----------|---------|
| Stub inject qua DI vao production | 0.95 | CRITICAL — chac chan fake data |
| Feature done + code co TODO/Stub | 0.90 | Registry va code khong nhat quan |
| Feature in_progress + code co stub throw | 0.85 | Stub code trong feature dang lam la gap |
| TODO + security/auth keyword | 0.85 | HIGH — co the security gap |
| Coming soon page deployed | 0.80 | MEDIUM — UX gap |
| Orphan stub khong REQ-ID | 0.70 | MEDIUM — co the dead code |
| FIXME/HACK marker | 0.65 | MEDIUM — code quality issue |
| TODO co REQ-ID | 0.60 | MEDIUM — da duoc track |
| Dead conditional (feature flag) | 0.40 | LOW — co the intentional |

---

## ACT

### Tao Signals

**Stub trong production path (CRITICAL/HIGH):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "stub_in_production",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Modules.Marketing/Infrastructure/Services/StubAIClient.cs",
    "line_range": [1, 50],
    "symbol": "StubAIClient"
  },
  "description": "StubAIClient trien khai IAIClient nhung tra ve du lieu gia lap co dinh (confidence=0.65, cost=$0.01). Tat ca AI features (content draft, score, send-time, forecast) dang dung stub thay vi provider thuc te. Can wire AI provider that.",
  "evidence": {
    "code_snippet": "public class StubAIClient : IAIClient { ... return new AIContentDraft { Confidence = 0.65m, Cost = 0.01m }; }",
    "stub_class": "StubAIClient",
    "implements": "IAIClient",
    "hardcoded_values": ["confidence=0.65", "cost=0.01"]
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_hints": ["stub:StubAIClient:IAIClient"]
}
```

**Feature done + code co TODO/Stub (HIGH):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "done_feature_has_todo",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/src/invoices/invoice.service.ts",
    "line_range": [142, 145]
  },
  "description": "Feature FEAT-FIN-INV-EXPORT co impl_status=done nhung trong invoice.service.ts:142 co TODO 'xu ly PDF generation sau'. Feature da duoc danh dau done nhung chuc nang PDF export chua hoan thien — khong nhat quan giua registry status va code thuc te.",
  "evidence": {
    "code_snippet": "// TODO: xu ly PDF generation sau khi co thu vien pdf-lib\nasync exportToPdf(invoiceId: string): Promise<Buffer> {\n  throw new Error('Not implemented');\n}",
    "spec_ref": "FEAT-FIN-INV-EXPORT trong req-registry.json co impl_status=done",
    "registry_context": "REQ-FIN-INV-012 co impl_status=done nhung code con throw NotImplemented"
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_hints": ["FEAT-FIN-INV-EXPORT", "invoice.service.ts:142"]
}
```

**Feature in_progress + stub code (HIGH):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "in_progress_feature_stub",
  "target": {
    "kind": "code",
    "file_path": "apps/web/src/hooks/useAnalytics.ts",
    "line_range": [28, 32]
  },
  "description": "Feature FEAT-DASH-ANALYTICS (impl_status=in_progress) co stub code trong useAnalytics.ts:28 — ham fetchAnalytics() chi return [](placeholder). Stub nay can duoc implement de feature hoat dong.",
  "evidence": {
    "code_snippet": "async function fetchAnalytics(filter: Filter): Promise<Metric[]> {\n  // FIXME: replace with real API call\n  return []; // placeholder\n}",
    "spec_ref": "FEAT-DASH-ANALYTICS trong registry co impl_status=in_progress"
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_hints": ["FEAT-DASH-ANALYTICS", "useAnalytics.ts:28"]
}
```

**TODO marker quan trong (HIGH):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "todo_security_gap",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Modules.Marketing/Infrastructure/Jobs/ZaloBirthdayCampaignJob.cs",
    "line_range": [117, 117]
  },
  "description": "TODO filter CompanyId per-campaign — multi-tenant data isolation chua duoc enforce. Campaign data co the bi leak giua cac company.",
  "evidence": {
    "code_snippet": "// TODO: filter CompanyId per-campaign",
    "category": "security",
    "has_req_id": false
  },
  "suggested_severity": "high",
  "fixability": "agent_fix",
  "dedup_hints": ["todo:ZaloBirthdayCampaignJob.cs:117:CompanyId"]
}
```

**Coming soon page (MEDIUM):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "coming_soon_page",
  "target": {
    "kind": "ui_page",
    "file_path": "apps/erp-web/src/app/[locale]/(dashboard)/marketing/loyalty/page.tsx",
    "line_range": [64, 64]
  },
  "description": "Page loyalty hien thi 'Coming soon' — tinh nang chua duoc implement. Nguoi dung thay placeholder thay vi chuc nang thuc.",
  "evidence": {
    "code_snippet": "<p>Coming soon</p>",
    "page_route": "/marketing/loyalty"
  },
  "suggested_severity": "medium",
  "fixability": "agent_fix",
  "dedup_hints": ["coming-soon:/marketing/loyalty"]
}
```

**Orphan stub khong REQ-ID (MEDIUM):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "orphan_stub_implementation",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/src/utils/report-generator.ts",
    "line_range": [55, 58]
  },
  "description": "Ham generateMonthlyReport() trong report-generator.ts:55 throw 'Not implemented' — stub code khong lien ket duoc voi REQ-ID nao. Function duoc export va import boi 3 files khac nhung chua hoan thien.",
  "evidence": {
    "code_snippet": "export function generateMonthlyReport(month: string): Report {\n  throw new Error('Not implemented yet');\n}",
    "serena_refs_count": 3
  },
  "suggested_severity": "medium",
  "fixability": "agent_fix",
  "dedup_hints": ["report-generator.ts:55", "generateMonthlyReport"]
}
```

**TODO khong REQ-ID (MEDIUM):**
```json
{
  "probe_id": "P-QD1-stub-todo-aggregate",
  "probe_version": "2.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "signal_type": "todo_untracked",
  "target": {
    "kind": "code",
    "file_path": "apps/backend/Eureka.Api/Endpoints/MarketingEndpoints.cs",
    "line_range": [848, 848]
  },
  "description": "TODO: chua exchange Zalo OAuth code lay access_token — OAuth flow chua hoan thien. Zalo OA connection khong thuc su hoat dong.",
  "evidence": {
    "code_snippet": "// TODO: exchange code for access_token",
    "category": "integration",
    "has_req_id": false
  },
  "suggested_severity": "medium",
  "fixability": "agent_fix",
  "dedup_hints": ["todo:MarketingEndpoints.cs:848:zalo_oauth"]
}
```

### Scan Cache store

```bash
for FILE in $SCAN_FILES; do
  python -m _shared.scan_cache.cache_store store \
    --probe-id P-QD1-stub-todo-aggregate --probe-version 2.0.0 \
    --file "$FILE" --signals-file "$TMP" \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/
done
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-stub-todo-aggregate.json" << 'EOF'
$STUB_TODO_SIGNALS
EOF
```

---

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
   - `code_snippet` min 10 chars
   - `stub_class`, `category`, hoac `page_route` tuy signal_type
2. Kiem tra moi Signal co `signal_type` trong ["stub_in_production","done_feature_has_todo","in_progress_feature_stub","in_progress_feature_todo","orphan_stub_implementation","code_quality_marker","todo_security_gap","todo_untracked","coming_soon_page","empty_function_body","dead_conditional_feature_flag","incomplete_integration"]
3. Kiem tra stub signals co `implements` hoac `base_class` de xac nhan la stub cua interface that
4. Kiem tra severity mapping dung:
   - `done_feature_has_todo` → HIGH
   - `in_progress_feature_stub` → HIGH
   - `stub_in_production` → HIGH
   - `todo_security_gap` → HIGH
   - `orphan_stub_implementation` → MEDIUM
   - `code_quality_marker` → MEDIUM
   - `in_progress_feature_todo` → MEDIUM
   - `coming_soon_page` → MEDIUM
   - `todo_untracked` → MEDIUM
   - `empty_function_body` → LOW
   - `dead_conditional_feature_flag` → LOW
5. Loai bo signals trong test files, node_modules, dist, excluded categories
6. Drop signals voi confidence < 0.5

---

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Stub class duoc inject vao production path | **HIGH** |
| Feature done + code co TODO/FIXME/stub | **HIGH** |
| Feature in_progress + code co stub (throw/placeholder) | **HIGH** |
| TODO lien quan security/auth/data-isolation | **HIGH** |
| OAuth/integration flow chua hoan thien (thieu exchange code) | **HIGH** |
| Feature not_started + code co stub | **MEDIUM** |
| FIXME/HACK marker khong xac dinh duoc feature | **MEDIUM** |
| Orphan stub khong co REQ-ID | **MEDIUM** |
| "Coming soon" page da deployed | **MEDIUM** |
| TODO marker + feature in_progress | **MEDIUM** |
| TODO khong co REQ-ID | **MEDIUM** |
| TODO co REQ-ID (da track) | **LOW** |
| Empty function body | **LOW** |
| Dead conditional (feature flag) | **LOW** |
| Stub chi trong test file | (excluded) |

---

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay stub/fake class nao | Skip B1-B2, chi chay TODO + Coming soon + Stub patterns scan |
| Khong tim thay TODO nao | Ghi note "no_todos_found" — co the la healthy codebase |
| Qua nhieu TODO (>500) | Cap max_signals = 100, uu tien security + integration category |
| Registry khong parse duoc | Van chay probe nhung khong co impl_status context — tat ca signals severity giam 1 cap, LOG WARN |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
| Serena unavailable | Fallback grep toan bo cho stub prefix |
| GitNexus unavailable | Skip injection path trace — chi flag stub existence |
| File bi xoa giua SENSE va ACT | Bo qua file do, LOG WARN |

---

## Cache Policy

**allowed** — static scan. Cache TTL: 24h.
Key: `{PROJECT_ROOT_SHA}:{marker_count}:{stub_count}:{version}`.
