# Phase 2: Scan Scope — wf-fix-bugs v10.4

> Procedure thực thi Phase 2 — scan code + docs để tạo context cho Phase 3 Planning.
> Phát hiện `interface_type`. Orchestrator TỰ thực thi (không spawn agents).
>
> **Shared protocols (lazy-load):**
> - [`_shared/07-execution-trace.md`](_shared/07-execution-trace.md) — dùng ở TRACE START/COMPLETE
>
> **KHÔNG đọc toàn bộ `_shared/` folder.**
>
> **v10.4 (2026-05-16):** Steps 2.3-2.7 **GỘP** thành Step 2.3 "Scan & Analyze" — delegate sang
> `scripts/wf-fix-bugs/scan-and-analyze.sh` (1 atomic call: Interface Detection + Code Inventory
> + Doc Inventory + Scope Analysis + 3 atomic writes). Step 2.4 delegate sang
> `scripts/wf-fix-bugs/generate-phase2-report.sh`. Step 2.8 (TRACE CHECKPOINT) DELETED — dead code.
> **10 → 5 steps (-50%)**, ~8.4K → ~3K tokens (-65%). Step numbering giữ gaps (2.4-2.8) tránh churn cross-refs.

---

## INPUT

| Input | Source | Purpose |
|-------|--------|---------|
| `$SESSION_DIR/fix-status.json` | Phase 1 | Verify phase1.completed, extract scope/dims/profile |
| `$SCOPE`, `$NAME`, `$DIMS_ARRAY`, `$PROFILE` | Phase 1 / CLI args | Phạm vi + độ sâu scan |
| `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` | CI PRE-GATE Na | CI-ROUTE selection |
| `req-registry.json` (optional) | Project SSOT | REQ/FEAT inventory |
| `.mc-data/docs/` (optional) | Project | Document inventory |

## OUTPUT

| Output | Template | Schema |
|--------|----------|--------|
| `phase2-scan/scope-analysis.json` | `templates/phase2-scan/scope-analysis.json` | scope-analysis-v2 |
| `phase2-scan/code-inventory.json` | `templates/phase2-scan/code-inventory.json` | code-inventory-v1 |
| `phase2-scan/doc-inventory.json` | `templates/phase2-scan/doc-inventory.json` | doc-inventory-v1 |
| `phase2-scan/Phase2-report.md` | `templates/phase2-scan/Phase2-report.md` | — (CORE-028 tiếng Việt ≤15 dòng) |

**In-memory state (truyền sang Phase 3-7):** `$INTERFACE_TYPE`, `$MOBILE_MODE`, `$TOTAL_FILES`, `$REQ_COUNT`, `$FEAT_COUNT`, `$DEP_LEVEL`, `$DETECTION_METHOD`, `$FRAMEWORKS`.

## Directory Structure

```
$SESSION_DIR/phase2-scan/
├── scope-analysis.json
├── code-inventory.json
├── doc-inventory.json
└── Phase2-report.md
```

---

## CI-ROUTE Matrix (Protocol 20 §20.5)

| CI Task | Primary | Secondary | Fallback |
|---------|---------|-----------|----------|
| `project_structure` | Serena `onboarding` | GitNexus `clusters` | Glob |
| `understand_flow` | GitNexus `query` | Serena `get_symbols_overview` | Grep+Read |
| `api_routes` | GitNexus `route_map` | — | Grep |
| `find_by_annotation` | GitNexus `cypher` + Serena `find_refs` | — | Grep REQ-ID |

Graceful degradation: Primary → Secondary → Fallback. KHÔNG hỏi user — auto-detect + degrade. `scan-and-analyze.sh` tự routing dựa trên `$GITNEXUS_AVAILABLE` + `$SERENA_AVAILABLE`.

---

## Step Dependency Chain (v10.4 — 5 steps)

```
Step 2.1 (PRE-GATE) ─── Phase 1 completed? NO → E010 STOP
  │
  ▼
Step 2.2 (TRACE START)
  │
  ▼
Step 2.3 (Scan & Analyze — scan-and-analyze.sh)
  │   ├── Interface Type Detection → $INTERFACE_TYPE
  │   ├── Code Inventory (CI-ROUTE)
  │   ├── Doc Inventory (req-registry + .mc-data/docs/)
  │   ├── Scope Analysis (aggregate)
  │   └── WRITE 3 JSON outputs (atomic, CORE-031)
  │
  ▼
Step 2.4 (Phase Report — generate-phase2-report.sh — CORE-028 tiếng Việt)
  │
  ▼
Step 2.5 (TRACE COMPLETE) → POST-GATE T1-T4 → Phase 3
```

**v10.4 step numbering:** Giữ gaps 2.4-2.8 (đã merge vào 2.3, hoặc deleted) — tránh churn cross-refs trong _shared.md, SKILL.md, các phase khác.

---

## Orchestrator Role Boundary

Phase 2 KHÔNG spawn agents. Orchestrator chạy `scan-and-analyze.sh` + `generate-phase2-report.sh`.

| LÀM | KHÔNG LÀM |
|-----|-----------|
| CI-ROUTE detection (qua script) | Spawn lane agents (Phase 4) |
| Enumeration via find/Glob (qua script) | Phân tích code sâu / tìm bug |
| Parse `req-registry.json` (qua script) | Tạo/sửa req-registry.json |
| Detect `$INTERFACE_TYPE` (qua script) | Chạy Playwright |
| Write 3 JSON + Phase2-report.md (qua script) | Tạo dimension-plan.json (Phase 3) |

Phase 2 = **thu thập dữ liệu**, không phải **phân tích**. Kết quả là input cho Phase 3.

---

## Orchestrator Execution Steps

> **BẮT BUỘC:** Mỗi step hoàn thành + verify được TRƯỚC KHI sang step tiếp.
> Step fail → dừng, ghi error-ledger (CORE-034), KHÔNG advance.

---

### Step 2.1 — PRE-GATE: Verify Phase 1 Complete

**Mục đích:** Forensic PRE-GATE (CORE-011) — verify Phase 1 đã completed + fix-status.json hợp lệ.

**Thực thi:**

```bash
# Verify content (không chỉ existence)
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase1.status == "completed"' "$SESSION_DIR/fix-status.json"
test -s "$SESSION_DIR/phase1-init/Phase1-report.md"

# Extract session vars (v10.10.0 fix: null-safe jq với // fallback cho mọi field —
# tránh crash khi Phase 1 bị interrupt sau Step 1.14 nhưng trước 1.15)
SCOPE=$(jq -r '.scope // "all"' "$SESSION_DIR/fix-status.json")
DIMS_ARRAY=$(jq -r '(.dimensions // []) | join(" ")' "$SESSION_DIR/fix-status.json")
PROFILE=$(jq -r '.profile // "standard"' "$SESSION_DIR/fix-status.json")
```

**VERIFY:** All `jq -e` PASS + 2 test -s PASS.

**On Failure:** E010 — Phase 1 chưa hoàn thành. Dừng, hướng dẫn chạy Phase 1.

**Cross-ref:** CORE-011, CORE-033.

---

### Step 2.2 — TRACE START (delegated to shared script v10.15.0)

**Mục đích:** Ghi START event vào session-log.json (CORE-026).

**Thực thi (v10.15.0 — dùng shared `phase-trace-start.sh`):**

```bash
SESSION_DIR="$SESSION_DIR" PHASE_NUM=2 bash .claude/scripts/wf-fix-bugs/phase-trace-start.sh
```

**Pattern canonical:** [_shared/07-execution-trace.md](_shared/07-execution-trace.md). Script reusable cross-phase (2-7).

**VERIFY:** `jq -e '.events[-1].event == "START"' "$SESSION_DIR/session-log.json"`.

**On Failure:** E001 — kiểm tra disk + permissions.

---

### Step 2.3 — Scan & Analyze (gộp v10.4 — Interface + Code + Doc + Scope + WRITE)

**Mục đích:** Thực hiện **5 logical phases trong 1 atomic call** qua `scripts/wf-fix-bugs/scan-and-analyze.sh`:

1. **Interface Type Detection** → `$INTERFACE_TYPE` ∈ `{web, mobile, hybrid, api-only}` từ package.json + pubspec.yaml + capacitor + expo + native files. Edge case: không detect → default `web` nếu có HTML/CSS, `api-only` nếu không (E023 auto-resolve).
2. **Code Inventory** (CI-ROUTE: Serena `onboarding` > GitNexus `clusters` > Glob): enumerate files theo SCOPE, language breakdown top 5, LOC estimate, modules detection (`apps/*` hoặc `src/`), API routes count. → `code-inventory.json` (schema code-inventory-v1).
3. **Doc Inventory:** parse `req-registry.json` (REQ + FEAT), scan `.mc-data/docs/phase*/`, đếm READMEs, REQ-ID annotation tracking. → `doc-inventory.json` (schema doc-inventory-v1).
4. **Scope Analysis** (aggregate): build scope-analysis-v2 với `interface_type + mobile_mode + source_dir + scope + code{} + docs{} + ci_coverage{}`. Includes `source_dir` cho lane-agent-prompt substitution v10.2.1.
5. **WRITE 3 JSON outputs** (CORE-031 READ→POPULATE→WRITE + CORE-035 Atomic Write Pattern): atomic write từ templates.

**Thực thi:**

```bash
# Pre-populate env vars cho script
export SESSION_DIR SESSION_ID SCOPE PROFILE
export GITNEXUS_AVAILABLE SERENA_AVAILABLE
export SOURCE_DIR="${SOURCE_DIR:-src}"

# 1 atomic call — gộp 5 logical phases
PHASE2_DATA=$(bash .claude/scripts/wf-fix-bugs/scan-and-analyze.sh)
EXIT_CODE=$?

# Eval values vào orchestrator in-memory state
INTERFACE_TYPE=$(echo "$PHASE2_DATA" | jq -r '.interface_type')
MOBILE_MODE=$(echo "$PHASE2_DATA" | jq -r '.mobile_mode')
DETECTION_METHOD=$(echo "$PHASE2_DATA" | jq -r '.detection_method')
TOTAL_FILES=$(echo "$PHASE2_DATA" | jq -r '.total_files')
TOTAL_LOC=$(echo "$PHASE2_DATA" | jq -r '.total_loc')
REQ_COUNT=$(echo "$PHASE2_DATA" | jq -r '.req_count')
FEAT_COUNT=$(echo "$PHASE2_DATA" | jq -r '.feat_count')
FRAMEWORKS=$(echo "$PHASE2_DATA" | jq -r '.frameworks')
DEP_LEVEL=$(echo "$PHASE2_DATA" | jq -r '.dep_level')

# Verify all 3 outputs ok
echo "$PHASE2_DATA" | jq -e '.status.scope_analysis == "ok" and .status.code_inventory == "ok" and .status.doc_inventory == "ok"'
```

**VERIFY (POST-GATE T1-T3 phần scan):**

```bash
test -s "$SESSION_DIR/phase2-scan/scope-analysis.json"
test -s "$SESSION_DIR/phase2-scan/code-inventory.json"
test -s "$SESSION_DIR/phase2-scan/doc-inventory.json"
jq -e '.interface_type and .scope and .code and .docs' "$SESSION_DIR/phase2-scan/scope-analysis.json"
jq -e '.code.total_files >= 0' "$SESSION_DIR/phase2-scan/scope-analysis.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E020 | 0 source files | WARN, continue docs-only |
| E021 | Không có docs | INFO, continue code-only |
| E023 | interface_type undetectable | Script auto-default `web`/`api-only` (no escalate) |
| E024 | Template không tồn tại | Script exit 2 → STOP, kiểm tra `templates/phase2-scan/` |
| E024 | JSON write fail | Script exit 3 → Re-run x1, escalate nếu vẫn fail |
| E035 | Atomic mv fail | Script tự retry với tmp file → escalate E001 |
| E001 | jq không available | STOP — required dependency |

**v10.4 note:** Trước v10.4 đây là **5 steps riêng biệt** (2.3 Interface, 2.4 Code, 2.5 Doc, 2.6 Scope, 2.7 Write). Cả 5 steps đều làm cùng 1 việc "thu thập + ghi data" → gộp thành 1 atomic call match pattern Phase 1 v10.3 `init-session-state.sh` (4 file populates → 1 script).

**Cross-ref:** CORE-031 (Template Usage), CORE-035 (Atomic Write), CORE-012 (POST-GATE T1-T4), CORE-033 (CI-ROUTE).

---

### Step 2.4 — Phase Report (qua generate-phase2-report.sh)

**Mục đích:** Tạo `Phase2-report.md` bằng tiếng Việt ≤15 dòng (CORE-028). Đọc từ `scope-analysis.json` + `doc-inventory.json`, populate template.

**Thực thi:**

```bash
export SESSION_DIR SESSION_ID
export DETECTION_METHOD FRAMEWORKS   # set bởi Step 2.3 (Scan & Analyze)
export STATUS_PASS="PASS"             # update FAIL nếu POST-GATE T1-T4 fail

bash .claude/scripts/wf-fix-bugs/generate-phase2-report.sh
```

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase2-scan/Phase2-report.md"
test "$(wc -l < "$SESSION_DIR/phase2-scan/Phase2-report.md")" -le 20  # margin cho CORE-028 ≤15
```

**On Failure:** Script exit 3 → Re-run x1, escalate nếu vẫn fail (E024).

**Cross-ref:** CORE-028, CORE-031.

---

### Step 2.5 — TRACE COMPLETE + Update fix-status.json (delegated v10.15.0)

**Mục đích:** Ghi COMPLETE event + mark phase2.completed + update top-level `interface_type` (Atomic Write).

**Thực thi (v10.15.0 — dùng shared `phase-finalize.sh`):**

```bash
SESSION_DIR="$SESSION_DIR" PHASE_NUM=2 \
PHASE_TOP_FIELDS="{\"interface_type\":\"$INTERFACE_TYPE\"}" \
  bash .claude/scripts/wf-fix-bugs/phase-finalize.sh
```

**Pattern canonical:** [_shared/07-execution-trace.md](_shared/07-execution-trace.md) + CORE-035 Atomic Write. Script reusable cross-phase (2-7).

**VERIFY:**

```bash
jq -e '.events[-1].phase == "phase2" and .events[-1].event == "COMPLETE"' "$SESSION_DIR/session-log.json"
jq -e '.phases.phase2.status == "completed"' "$SESSION_DIR/fix-status.json"
```

**On Failure:** E035 — Retry x1, escalate E001.

**Cross-ref:** CORE-026, CORE-035.

---

## POST-GATE (T1-T4)

```bash
# T1: Files exist + non-empty
test -s "$SESSION_DIR/phase2-scan/scope-analysis.json" || echo "FAIL T1: scope-analysis.json"
test -s "$SESSION_DIR/phase2-scan/code-inventory.json"  || echo "FAIL T1: code-inventory.json"
test -s "$SESSION_DIR/phase2-scan/doc-inventory.json"   || echo "FAIL T1: doc-inventory.json"
test -s "$SESSION_DIR/phase2-scan/Phase2-report.md"     || echo "FAIL T1: Phase2-report.md"

# T2: scope-analysis.json structure (interface_type + scope + code + docs)
jq -e '.interface_type and .scope and .code and .docs' "$SESSION_DIR/phase2-scan/scope-analysis.json" \
  || echo "FAIL T2"

# T3: Content depth (interface_type + code.total_files)
jq -e '.interface_type and .code.total_files' "$SESSION_DIR/phase2-scan/scope-analysis.json" \
  || echo "FAIL T3"

# T4: Cross-reference — Phase2-report.md mentions $INTERFACE_TYPE
grep -q "$INTERFACE_TYPE" "$SESSION_DIR/phase2-scan/Phase2-report.md" \
  || echo "FAIL T4: missing interface_type reference"
```

---

## On Failure Quick Reference

| Code | Lỗi | Auto-Fix | Max Retry | Escalate |
|------|-----|----------|-----------|----------|
| E010 | Phase 1 chưa hoàn thành | — | 0 | Dừng, chạy Phase 1 |
| E020 | Code scan empty | WARN, docs-only | 0 | Non-blocking |
| E021 | Doc scan empty | INFO, continue | 0 | Non-blocking |
| E022 | CI stale >50 commits | WARN, fallback Grep | 0 | Non-blocking |
| E023 | interface_type undetectable | Default `web`/`api-only` | 0 | Non-blocking |
| E024 | Template/output write fail | Re-run script | 2 | AskUserQuestion Skip/Retry/Cancel |
| E035 | Atomic write fail | Re-attempt mv | 1 | E001 escalate |
| E001 | Disk/session error | Check disk space | 1 | AskUserQuestion Retry/Cancel |

**Auto-fix budget Phase 2:** Max 3 retries tổng (CORE-034). Reset khi POST-GATE PASS.

---

## Resume Logic

Khi `--resume` được gọi và `fix-status.json` có `phases.phase2.status == "completed"`:

```bash
# Verify POST-GATE outputs còn nguyên vẹn
for f in scope-analysis.json code-inventory.json doc-inventory.json Phase2-report.md; do
  [ -s "$SESSION_DIR/phase2-scan/$f" ] || { echo "WARN: $f missing — re-run Phase 2"; exit 1; }
done

# Stale lock check (v10.10.0 fix: portable stat Linux/macOS)
LOCK_MTIME=$(stat -c '%Y' "$SESSION_DIR/.lock" 2>/dev/null \
             || stat -f '%m' "$SESSION_DIR/.lock" 2>/dev/null \
             || echo 0)
[ "$(($(date +%s) - ${LOCK_MTIME:-0}))" -gt 1800 ] && rm -f "$SESSION_DIR/.lock"

echo "Phase 2 already completed — skip to Phase 3"
```

---

## Next Phase

Phase 3 — `procedures/phase3-plan.md` (ISG + Partition → dimension-plan.json + work-plan.json)
