# Phase 4 Find Bugs — Thiết kế lại v10.1

> **Mục tiêu:** Phase 4 chạy song song nhiều luồng (lanes), mỗi luồng = 1 sub-skill phụ trách 1 QD dimension.
> Mỗi sub-skill thực hiện 2 track song song: **Static Scripts** (bash/Python) + **LLM Analysis** (AI agent).
> Kết quả ghi độc lập vào `lanes/QD{n}/` và báo cáo về orchestrator.

**Ngày:** 2026-05-14 | **Phiên bản:** v10.1 | **Trạng thái:** Đã phê duyệt — đang triển khai

---

## 1. Kiến trúc tổng quan

```
┌──────────────────────────────────────────────────────────────┐
│                 ORCHESTRATOR (wf-fix-bugs)                    │
│                                                              │
│  Phase 4: Find Bugs                                          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Step 4.1-4.4: PRE-GATE + Init lane dirs + Playwright │    │
│  │                                                      │    │
│  │ Step 4.5: DISPATCH PARALLEL (max 10 agents)          │    │
│  │   ┌──────────┐  ┌──────────┐      ┌──────────┐      │    │
│  │   │ Lane QD1 │  │ Lane QD2 │ ...  │ Lane QD11│      │    │
│  │   │ Agent    │  │ Agent    │      │ Agent    │      │    │
│  │   └────┬─────┘  └────┬─────┘      └────┬─────┘      │    │
│  │        │              │                 │            │    │
│  │        │  Mỗi agent ĐỌC sub-skill SKILL.md           │    │
│  │        │  → THỰC THI pipeline PRE-GATE→SENSE→        │    │
│  │        │     THINK→ACT→VERIFY→POST-GATE              │    │
│  │        │  → GHI output vào lanes/QD{n}/              │    │
│  │        │  → BÁO CÁO kết quả về orchestrator          │    │
│  │        ▼              ▼                 ▼            │    │
│  │   lanes/QD1/    lanes/QD2/      lanes/QD11/          │    │
│  │                                                      │    │
│  │ Step 4.6-4.7: Monitor + Collect + Validate           │    │
│  │ Step 4.8-4.10: Phase4-report + Update status + TRACE │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Nguyên tắc cốt lõi

| # | Nguyên tắc | Cơ sở |
|---|-----------|-------|
| P1 | **1 lane = 1 agent = 1 sub-skill = 1 write scope** | CORE-025 |
| P2 | **Static Scripts + LLM Analysis chạy song song trong cùng lane** | Thiết kế mới |
| P3 | **Mỗi probe ghi output riêng → merge cuối lane** | Anti-overwrite contract |
| P4 | **Lane agent tự POST-GATE validate trước khi báo cáo** | CORE-012 T1-T4 |
| P5 | **Orchestrator chỉ aggregate, không can thiệp vào lane internals** | Isolation |
| P6 | **Hỗ trợ --resume: lane đã completed → skip** | CORE-038 |

---

## 2. Mô hình thực thi 2-Track trong mỗi Lane

Mỗi sub-skill chạy **2 track song song**:

```
LANE AGENT (sub-skill, vd: wf-fix-functional)
│
├── TRACK A: STATIC SCRIPTS (bash/Python)
│   ├── Probe P-QD1-req-registry-xref → bash wf-fix-probe-static-xref.sh
│   ├── Probe P-QD1-stub-todo-aggregate → bash wf-fix-probe-static-*.sh + grep
│   ├── Probe P-QD1-route-config-parse → bash wf-fix-probe-static-route.sh
│   └── ...
│   │
│   └── Output: raw/P-QD1-*.json → merge → static-scan/signals.json
│
├── TRACK B: LLM ANALYSIS (AI agent context)
│   ├── Probe P-QD1-agent-feature-verify → Agent subagent_type=developer
│   ├── Probe P-QD1-spec-completeness-check → Agent subagent_type=business-analyst
│   ├── Probe P-QD1-llm-analysis → LLM scan (nếu --llm-scan)
│   └── ...
│   │
│   └── Output: raw/P-QD1-*.json → merge → runtime/signals.json + llm-scan/signals.json
│
└── VERIFY + MERGE
    ├── Validate signal-v2 schema
    ├── Dedup fingerprint
    ├── Ghi static-scan/signals.json + runtime/signals.json + llm-scan/signals.json
    ├── Ghi lane-status.json = completed
    ├── Ghi QD{n}-report.md (từ template)
    └── Báo cáo về orchestrator
```

### 2.1 Track A: Static Scripts

**Mục đích:** Chạy bash/Python scripts để quét code tĩnh, tìm pattern, cross-ref registry.

**Cơ chế:**
1. Profile resolver xác định danh sách static probes cần chạy
2. Với mỗi probe, đọc procedure file `procedures/probes/{PROBE_ID}.md`
3. Chạy bash script được chỉ định → output ghi vào `raw/{PROBE_ID}.json`
4. Nếu script fail → retry x3 (E040) → fallback: emit empty signals với `skip_reason`

**Script inventory (24 scripts có sẵn):**

| Script | Dùng cho | Output |
|--------|----------|--------|
| `wf-fix-probe-static-xref.sh` | P-QD1-req-registry-xref | REQ-ID coverage gaps |
| `wf-fix-probe-static-route.sh` | P-QD1-route-config-parse | Route config mismatches |
| `wf-fix-probe-static-sast.sh` | P-QD3-security | SAST patterns |
| `wf-fix-probe-static-secret.sh` | P-QD3-secret-detection | Secret leakage |
| `wf-fix-probe-static-depvuln.sh` | P-QD3-dependency-vuln-scan | CVE checks |
| `wf-fix-probe-static-perf.sh` | P-QD4-performance | Performance patterns |
| `wf-fix-probe-static-a11y.sh` | P-QD5-ux-a11y | Accessibility violations |
| `wf-fix-probe-static-data.sh` | P-QD6-data | Schema drift |
| `wf-fix-probe-static-compat.sh` | P-QD7-compat | Deprecated API usage |
| `wf-fix-probe-static-business.sh` | P-QD2-business | Business rule violations |
| `wf-fix-probe-static-orm.sh` | QD6/QD10 | ORM query patterns |
| `wf-fix-probe-static-react.sh` | QD5/QD7 | React anti-patterns |
| `wf-fix-probe-static-vue.sh` | QD5/QD7 | Vue anti-patterns |
| `wf-fix-probe-static-go.sh` | QD1/QD4 | Go patterns |
| `wf-fix-probe-static-python.sh` | QD1/QD4 | Python patterns |
| `wf-fix-probe-static-cta.sh` | QD5-ux-a11y | CTA detection |
| `wf-fix-probe-static-deprecated.sh` | QD7-compat | Deprecated API |
| `wf-fix-probe-static-signal-validate.sh` | All lanes | Signal schema validation |
| `wf-fix-probe-static-infra-preflight.sh` | P-QD1-infra-preflight | Infrastructure checks |
| `wf-fix-probe-static-api-smoke.sh` | P-QD1-api-smoke | API endpoint tests |
| `wf-fix-probe-static-schema-drift.sh` | P-QD6-data | DB schema drift |
| `wf-fix-probe-contract-drift.sh` | QD10 | API contract drift |
| `wf-fix-probe-cross-module-ref.sh` | QD10 | Cross-module references |
| `wf-detect-cross-module-deps.sh` | QD10 | Cross-module dependencies |

### 2.2 Track B: LLM Analysis

**Mục đích:** Sử dụng AI agent để phân tích chuyên sâu, phát hiện bug không thể bắt bằng pattern tĩnh.

**Cơ chế:**
1. Profile resolver xác định danh sách agent/LLM probes cần chạy
2. Với mỗi probe, agent chính của lane (đã có context) thực hiện phân tích
3. Hoặc spawn sub-agent chuyên biệt (vd: `subagent_type=business-analyst` cho P-QD2-domain-expert-review)
4. Output ghi vào `raw/{PROBE_ID}.json` cùng format signal-v2

**Probe types:**
- **agent**: Spawn sub-agent chuyên biệt (business-analyst, security, developer, v.v.)
- **llm**: Phân tích bằng LLM trực tiếp (cần `--llm-scan` + profile deep/exhaustive)
- **runtime+agent**: Kết hợp runtime test + agent analysis

---

## 3. Hợp đồng đầu ra (Output Contract)

### 3.1 Cấu trúc thư mục mỗi lane

```
$SESSION_DIR/phase4-find-bugs/lanes/QD{n}-{name}/
├── raw/                              ← Per-probe raw outputs (1 file/probe)
│   ├── P-QD{n}-{probe1}.json
│   ├── P-QD{n}-{probe2}.json
│   └── ...
├── evidence/                         ← Screenshots, HTTP traces, logs
│   ├── screenshot-001.png
│   └── trace-001.har
├── static-scan/
│   └── signals.json                  ← MERGED từ raw/ static probes (signal-v2)
├── runtime/
│   └── signals.json                  ← MERGED từ raw/ runtime probes (signal-v2)
├── llm-scan/
│   └── signals.json                  ← MERGED từ raw/ LLM probes (signal-v2)
├── lane-status.json                  ← lane-status-v1 schema
└── QD{n}-{name}-report.md            ← Từ template QD-report.md
```

### 3.2 Schema contracts

**signals.json** — Mỗi file tuân thủ `signal-v2` schema ([_shared/lane/_shared.md §1](D:\Working\MCV3\.claude\skills\workflow\_shared\lane\_shared.md)):
```json
{
  "$schema": "signal-v2",
  "scan_type": "static-scan|runtime|llm-scan",
  "dimension_id": "QD1",
  "dimension_name": "Functional Correctness",
  "session_id": "2026-05-14-module-settings-01",
  "generated_at": "2026-05-14T10:45:00+07:00",
  "agent_id": "W1-QD1-functional",
  "signals": [
    {
      "id": "SIG-QD1-001",
      "dimension_id": "QD1",
      "probe_id": "P-QD1-req-registry-xref",
      "severity": "high",
      "fixability": "agent_fix",
      "title": "...",
      "description": "...",
      "location": {"file": "...", "line": 42},
      "evidence": [{"type": "code", "path": "raw/P-QD1-xxx.json"}],
      "fingerprint": "sha256:...",
      "detected_at": "2026-05-14T10:30:00Z",
      "detected_by": "wf-fix-functional/P-QD1-req-registry-xref"
    }
  ]
}
```

**lane-status.json** — Tuân thủ `lane-status-v1` schema:
```json
{
  "dimension_id": "QD1",
  "dimension_name": "Functional Correctness",
  "session_id": "2026-05-14-module-settings-01",
  "status": "pending|in_progress|completed|failed|skipped",
  "started_at": "ISO-8601",
  "completed_at": "ISO-8601",
  "agent_id": "W1-QD1-functional",
  "signals_static": 0,
  "signals_runtime": 0,
  "signals_llm": 0,
  "probe_failures": 0,
  "probes_executed": [],
  "probes_failed": [],
  "playwright_used": false,
  "errors": []
}
```

---

## 4. Agent Prompt Template — Thiết kế lại

### 4.1 Orchestrator → Lane Agent Prompt

Đây là prompt mà orchestrator (Phase 4 Step 4.5) gửi cho mỗi lane agent:

```
Bạn là lane agent cho dimension {DIM_ID} — {DIM_NAME}.
Nhiệm vụ của bạn: thực thi TOÀN BỘ pipeline của sub-skill {SUB_SKILL_NAME}
để tìm bugs trong phạm vi dimension này.

───────────────────────────────────────────
THÔNG TIN PHIÊN LÀM VIỆC
───────────────────────────────────────────
Session Dir:  {SESSION_DIR}
Dự án:        {PROJECT_NAME}
Profile:      {PROFILE}
Scope:        {SCOPE} / {NAME}
Interface:    {INTERFACE_TYPE}
LLM Scan:     {LLM_SCAN}

───────────────────────────────────────────
CI TOOLS (Protocol 20)
───────────────────────────────────────────
GitNexus:     {GITNEXUS_AVAILABLE}
Serena:       {SERENA_AVAILABLE}
Index freshness: {INDEX_FRESHNESS}

{CI_CONTEXT}

───────────────────────────────────────────
PLAYWRIGHT (nếu applicable)
───────────────────────────────────────────
{PLAYWRIGHT_CONTEXT}

───────────────────────────────────────────
QUY TRÌNH BẮT BUỘC
───────────────────────────────────────────

BƯỚC 1 — ĐỌC SUB-SKILL
  Đọc file: .claude/skills/workflow/{SUB_SKILL_NAME}/SKILL.md
  Đọc file: .claude/skills/workflow/_shared/lane/_shared.md (schema signal-v2)
  Đọc file: .claude/skills/workflow/_shared/lane/pre-gate.md (PRE-GATE procedure)
  Đọc file: .claude/skills/workflow/_shared/lane/profile-resolver.md (profile → probe mapping)

BƯỚC 2 — PRE-GATE (bắt buộc)
  a. Verify SESSION_DIR và fix-status.json tồn tại + hợp lệ
  b. Verify req-registry.json tồn tại + có requirements non-empty
  c. Verify source code tồn tại (src/ hoặc apps/)
  d. Xác định probe subset từ PROFILE (dùng profile-resolver.md)
  e. Tạo lane-status.json với status="in_progress" TỪ TEMPLATE:
     Đọc templates/phase4-find-bugs/lane-status.json → populate → write

BƯỚC 3 — TẠO CẤU TRÚC THƯ MỤC
  mkdir -p {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/raw/
  mkdir -p {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/evidence/
  mkdir -p {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/static-scan/
  mkdir -p {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/runtime/
  mkdir -p {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/llm-scan/

BƯỚC 4 — CHẠY SONG SONG 2 TRACK

  TRACK A — STATIC SCRIPTS:
    Với mỗi static probe trong probe subset:
    a. Đọc procedure file: procedures/probes/{PROBE_ID}.md
    b. Nếu procedure có bash script → chạy script đó:
       bash .claude/scripts/{script}.sh \
         --session-dir "{SESSION_DIR}" \
         --lane {SUB_SKILL_NAME} \
         --probe {PROBE_ID} \
         --profile "{PROFILE}" \
         --source-dir "{SOURCE_DIR}" \
         > {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/raw/{PROBE_ID}.json
    c. Nếu script fail (exit != 0) → timeout = 5 phút (300s, override qua MCV3_PROBE_SCRIPT_TIMEOUT). Nếu fail (exit != 0 hoặc timeout) → retry x1 → nếu vẫn fail:
       Ghi raw/{PROBE_ID}.json với signals=[] + skip_reason="script_failed"
       Ghi probe-failures.log
    d. Nếu procedure dùng grep/serena/gitnexus → thực thi theo CI-ROUTE matrix

  TRACK B — LLM/AGENT ANALYSIS (chạy SONG SONG với Track A):
    Với mỗi agent/llm probe trong probe subset:
    a. Đọc procedure file: procedures/probes/{PROBE_ID}.md (hoặc prompts/llm-probe-*.md)
    b. Thực hiện phân tích chuyên sâu bằng AI:
       - Dùng context CI tools (GitNexus query, Serena find_symbol) để trace code
       - Dùng domain knowledge từ .claude/references/team-expert/
       - Nếu probe yêu cầu spawn sub-agent → spawn với subagent_type tương ứng
    c. Emit signals theo signal-v2 schema → ghi raw/{PROBE_ID}.json
    d. Thu thập evidence (code snippets, screenshots, HTTP traces)

BƯỚC 5 — MERGE & VALIDATE
  a. Merge tất cả raw/*.json → phân loại theo scan_type:
     - static probes → static-scan/signals.json
     - runtime probes → runtime/signals.json
     - llm probes → llm-scan/signals.json
  b. Mỗi file signals.json PHẢI tạo TỪ TEMPLATE:
     Đọc templates/phase4-find-bugs/lane-signals.json → populate → write
     Strip _template_notes, _schema_notes trước khi write
  c. Dedup signals theo fingerprint (sha256 của dim+file+line+probe)
  d. Validate từng signal có đủ required fields (signal-v2 schema)
  e. Validate severity ∈ {critical,high,medium,low,info}
  f. Validate fixability ∈ {auto_fix,agent_fix,escalate,skip}

BƯỚC 6 — TẠO LANE REPORT
  a. Đọc templates/phase4-find-bugs/QD-report.md
  b. Populate với:
     - signals_static, signals_runtime, signals_llm counts
     - Probe failures (nếu có)
     - Top signals by severity
     - Observations
  c. Write {DIM_DIR}/QD{n}-{name}-report.md

BƯỚC 7 — CẬP NHẬT LANE STATUS
  a. Đọc lane-status.json hiện tại
  b. Cập nhật:
     - status = "completed" (hoặc "failed" nếu có lỗi không recover)
     - signals_static, signals_runtime, signals_llm = count tương ứng
     - probe_failures = số probe bị fail
     - probes_executed = [danh sách probe đã chạy]
     - completed_at = ISO-8601
  c. Write atomic (tmp → mv)

BƯỚC 8 — BÁO CÁO VỀ ORCHESTRATOR
  Output cho orchestrator biết lane đã hoàn thành:
  - lane-status.json đã được cập nhật
  - Tổng số signals tìm thấy
  - Đường dẫn đến QD-report.md

───────────────────────────────────────────
QUY TẮC BẮT BUỘC
───────────────────────────────────────────
1. KHÔNG bỏ qua bất kỳ probe nào trong profile
2. KHÔNG gộp tất cả signals vào 1 file — phải tách static-scan/runtime/llm-scan
3. MỌI JSON file phải tạo từ TEMPLATE (CORE-031): READ → POPULATE → WRITE
4. MỌI JSON file phải strip _template_notes, _schema_notes
5. KHÔNG ghi đè file của lane khác (1 file = 1 writer)
6. Dùng CI-ROUTE matrix: GitNexus/Serena primary → Grep fallback
7. Nếu không thể hoàn thành → ghi lane-status.json status="failed" + errors[]
8. Nếu PROFILE không có probe nào → ghi status="skipped" + lý do

───────────────────────────────────────────
SIGNAL EMIT PATTERN (mỗi khi phát hiện bug)
───────────────────────────────────────────
1. Tạo evidence file trước (code snippet, screenshot, trace)
2. Build signal JSON theo signal-v2 schema
3. Tính fingerprint = sha256(dimension_id|file|line|probe_id|signal_type)
4. Kiểm tra fingerprint chưa tồn tại trong signals[]
5. APPEND signal vào raw/{PROBE_ID}.json (atomic: tmp → mv)
```

### 4.2 Sub-agent Prompt (cho agent probes)

Khi probe yêu cầu spawn sub-agent (vd: P-QD2-domain-expert-review spawn business-analyst):

```
Bạn là {AGENT_TYPE} cho probe {PROBE_ID} của lane {DIM_ID}.
Đọc procedure file: .claude/skills/workflow/{SUB_SKILL}/procedures/probes/{PROBE_ID}.md

Session Dir: {SESSION_DIR}
Scope: {SCOPE} / {NAME}

CI CONTEXT:
{CI_CONTEXT}

Nhiệm vụ:
1. Phân tích code trong phạm vi {SCOPE} / {NAME}
2. Tìm bugs theo tiêu chí trong procedure file
3. Với mỗi bug phát hiện → emit 1 signal (format signal-v2)
4. Ghi signals vào: {SESSION_DIR}/phase4-find-bugs/lanes/{DIM_DIR}/raw/{PROBE_ID}.json

QUY TẮC:
- Mỗi signal PHẢI có evidence (code reference, screenshot, hoặc trace)
- KHÔNG fantasy bug — mỗi bug phải có location.file cụ thể
- Dùng CI tools (GitNexus/Serena) nếu available
- Output JSON phải validate qua signal-v2 schema
```

---

## 5. Cơ chế giám sát và thu thập (Orchestrator)

### 5.1 Monitor loop (Step 4.6)

```bash
# Orchestrator định kỳ check lane-status.json
MONITOR_INTERVAL=30  # giây

while true; do
  COMPLETED=0
  FAILED=0
  RUNNING=0
  
  for dim in $DIMS_ARRAY; do
    LANE_STATUS="$SESSION_DIR/phase4-find-bugs/lanes/${dim}/lane-status.json"
    if [ -f "$LANE_STATUS" ]; then
      STATUS=$(jq -r '.status' "$LANE_STATUS")
      case "$STATUS" in
        completed|skipped) COMPLETED=$((COMPLETED + 1)) ;;
        failed) FAILED=$((FAILED + 1)) ;;
        in_progress) RUNNING=$((RUNNING + 1)) ;;
      esac
    fi
  done
  
  echo "[Phase 4 Monitor] Completed: $COMPLETED | Failed: $FAILED | Running: $RUNNING"
  
  TOTAL=$((COMPLETED + FAILED))
  if [ "$TOTAL" -eq "${#DIMS_ARRAY[@]}" ]; then
    break  # Tất cả lanes đã kết thúc
  fi
  
  # Timeout check: nếu agent không respond sau 15 phút → E043
  # (kiểm tra started_at so với thời gian hiện tại)
  
  sleep $MONITOR_INTERVAL
done
```

### 5.2 Collect & Validate (Step 4.7)

```bash
# Sau khi tất cả lanes complete → validate
ERRORS=0

for dim in $DIMS_ARRAY; do
  LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/${dim}"
  
  # T1: File existence
  test -f "$LANE_DIR/lane-status.json" || { echo "E043: Missing lane-status.json for $dim"; ERRORS=$((ERRORS + 1)); continue; }
  
  # T2: Schema validation
  jq -e '.dimension_id and .status and .signals_static >= 0' "$LANE_DIR/lane-status.json" || {
    echo "E043: Invalid lane-status.json schema for $dim"; ERRORS=$((ERRORS + 1));
  }
  
  # T3: Content check
  for sub in static-scan runtime llm-scan; do
    SIGNALS_FILE="$LANE_DIR/${sub}/signals.json"
    if [ -f "$SIGNALS_FILE" ]; then
      SIGNAL_COUNT=$(jq '.signals | length' "$SIGNALS_FILE")
      echo "  $dim/$sub: $SIGNAL_COUNT signals"
      
      # Validate mỗi signal có required fields
      jq -e '.signals[] | .id and .dimension_id and .probe_id and .severity and .location.file and .fingerprint' \
        "$SIGNALS_FILE" > /dev/null || {
        echo "  WARN: $dim/$sub has signals missing required fields"
      }
    fi
  done
  
  # T4: Cross-ref — QD-report.md exists
  QD_REPORT=$(find "$LANE_DIR" -maxdepth 1 -name "QD*-report.md" | head -1)
  if [ -z "$QD_REPORT" ]; then
    echo "E043: Missing QD-report.md for $dim — generating stub"
    # Tạo stub từ template
    cp "$TEMPLATES_DIR/phase4-find-bugs/QD-report.md" "$LANE_DIR/${dim}-report.md"
    # Populate với dữ liệu có sẵn
  fi
  
  # Cross-check: lane-status counts vs actual signal counts
  CLAIMED_STATIC=$(jq -r '.signals_static // 0' "$LANE_DIR/lane-status.json")
  ACTUAL_STATIC=$(jq -s '[.[].signals | length] | add' "$LANE_DIR"/static-scan/signals.json 2>/dev/null || echo 0)
  if [ "$CLAIMED_STATIC" != "$ACTUAL_STATIC" ]; then
    echo "DATA INCONSISTENCY: $dim claims $CLAIMED_STATIC static signals but files have $ACTUAL_STATIC"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo "Phase 4 POST-GATE: $ERRORS errors found"
  # Ghi error-ledger.json
fi
```

---

## 6. Cơ chế Resume

### 6.1 Per-lane resume

```bash
# Khi orchestrator gọi --resume:
# 1. Đọc fix-status.json → xác định phase hiện tại
# 2. Nếu phase = 4 (in_progress hoặc partial):
#    - Đọc lane-status.json cho từng dim
#    - Skip lanes có status = "completed"
#    - Re-run lanes có status = "failed" hoặc "in_progress" (stale lock)
#    - Re-run lanes có status = "pending"

for dim in $DIMS_ARRAY; do
  LANE_STATUS="$SESSION_DIR/phase4-find-bugs/lanes/${dim}/lane-status.json"
  
  if [ -f "$LANE_STATUS" ]; then
    STATUS=$(jq -r '.status' "$LANE_STATUS")
    case "$STATUS" in
      completed|skipped)
        echo "  $dim: $STATUS — SKIP (resume)"
        continue
        ;;
      failed|in_progress)
        # Check stale: nếu started_at > 30 phút → reset về pending
        STARTED=$(jq -r '.started_at' "$LANE_STATUS")
        if [ -n "$STARTED" ] && [ "$STARTED" != "null" ]; then
          AGE_MIN=$(( ($(date +%s) - $(date -d "$STARTED" +%s)) / 60 ))
          if [ "$AGE_MIN" -gt 30 ]; then
            echo "  $dim: stale lock ($AGE_MIN min) — reset to pending"
            # Reset status
            TMP="${LANE_STATUS}.tmp.$$"
            jq '.status = "pending" | .started_at = "" | .completed_at = ""' "$LANE_STATUS" > "$TMP" \
              && mv "$TMP" "$LANE_STATUS"
          fi
        fi
        ;;
    esac
  fi
  
  # Dispatch lại lane
  DISPATCH_LANE "$dim"
done
```

### 6.2 Per-probe resume

Mỗi probe ghi `raw/{PROBE_ID}.json` — nếu file đã tồn tại và valid:
- Check `jq -e '.signals' raw/{PROBE_ID}.json` → skip probe
- Nếu file rỗng hoặc corrupt → re-run probe

```bash
# Trong lane agent:
for PROBE_ID in $PROBE_LIST; do
  RAW_OUTPUT="$SESSION_DIR/phase4-find-bugs/lanes/${DIM_DIR}/raw/${PROBE_ID}.json"
  
  if [ -f "$RAW_OUTPUT" ] && jq -e '.signals' "$RAW_OUTPUT" > /dev/null 2>&1; then
    echo "  $PROBE_ID: already completed — SKIP (resume)"
    continue
  fi
  
  # Chạy probe
  run_probe "$PROBE_ID"
done
```

---

## 7. Xử lý lỗi

### 7.1 Error codes (Phase 4 namespace: E040-E049)

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E040 | Static probe script fail | Retry x1 → fallback empty signals |
| E041 | Runtime probe fail | Record probe-failures.log → continue |
| E042 | LLM probe fail | Record probe-failures.log → continue |
| E043 | Agent report/QD-report missing | Generate stub từ template |
| E044 | Playwright launch fail | Retry x2 → escalate |
| E045 | Mobile emulation not supported | WARN → fallback desktop |
| E046 | Lane timeout (>15 min no response) | Mark failed → continue lanes khác |
| E047 | POST-GATE validation fail | Retry fix x1 → escalate AskUserQuestion |
| E048 | Signal schema validation fail | Drop invalid signal → log warning |
| E049 | Fingerprint collision (duplicate signal) | Keep first → skip duplicate |

### 7.2 Error ledger pattern

```json
{
  "phase": 4,
  "error_code": "E040",
  "lane": "QD1-functional",
  "probe_id": "P-QD1-req-registry-xref",
  "message": "Script wf-fix-probe-static-xref.sh exited with code 1",
  "timestamp": "2026-05-14T10:30:00+07:00",
  "retry_count": 2
}
```

---

## 8. So sánh hiện tại vs thiết kế mới

| Khía cạnh | Hiện tại (v10.0) | Thiết kế mới (v10.1) |
|-----------|-----------------|---------------------|
| Agent Prompt | 8 dòng ngắn gọn | ~100 dòng với 8 bước bắt buộc |
| Track A (Scripts) | Không thực thi | Bash scripts chạy đầy đủ, timeout 5 phút, retry x1 |
| Track B (LLM) | Gộp chung với manual | Tách riêng, song song với Track A |
| Output structure | 1 file signals.json | 3 subdirectories + raw/ + evidence/ |
| Schema compliance | Ad-hoc fields | Bắt buộc READ template → POPULATE → WRITE |
| Resume | Chỉ phase-level | Per-lane + per-probe |
| Monitor | Không có loop | 30s polling + timeout detection |
| Validation | Không có schema check | POST-GATE T1-T4 + signal-v2 validation + cross-check counts |
| QD report | Không tạo | Bắt buộc tạo từ template (stub nếu fail) |

---

## 9. Danh sách file cần sửa đổi

| # | File | Thay đổi |
|---|------|----------|
| 1 | `procedures/_shared.md` §15 | Viết lại Lane Agent Prompt Template (mục 4.1) |
| 2 | `procedures/phase4-find-bugs.md` | Thêm monitor loop, collect+validate script, resume logic |
| 3 | `wf-fix-bugs/SKILL.md` | Cập nhật phase routing map, output table |
| 4 | `wf-fix-functional/SKILL.md` | Cập nhật output paths (đã đúng, cần verify) |
| 5 | 10 sub-skills còn lại | Verify output path contracts khớp với thiết kế mới |
| 6 | `_shared/lane/_shared.md` | Đã đúng signal-v2 schema — không cần sửa |
| 7 | `templates/phase4-find-bugs/lane-signals.json` | Đã đúng — không cần sửa |
| 8 | `templates/phase4-find-bugs/lane-status.json` | Đã đúng — không cần sửa |

---

## 10. Quyết định thiết kế (ĐÃ CHỐT)

### Q1: Track A + Track B — 1 agent hay 2?

**Quyết định: 1 agent/lane làm cả 2 track.**

- Agent đan xen Track A (bash script) và Track B (LLM analysis) trong cùng luồng
- Script chạy nhanh (10-30s), agent có thể phân tích LLM probe khác trong lúc đợi script
- Merge đơn giản: 1 writer sở hữu toàn bộ `raw/`, `static-scan/`, `runtime/`, `llm-scan/`
- 11 lane = tối đa 11 agents = vừa khít max 10 concurrent (2 đợt: 10 + 1)
- Ngoại lệ: probe yêu cầu domain expertise (security, business-analyst) → spawn sub-agent chuyên biệt (xem Q3)

### Q2: Script timeout

**Quyết định: 5 phút (300 giây) / script.**

- Đủ cho script nặng (SAST, cross-module deps) trên repo lớn
- Có thể override qua biến môi trường `MCV3_PROBE_SCRIPT_TIMEOUT`
- Hết timeout → fallback empty signals + log E040 + retry x1

### Q3: LLM probe — tự làm hay spawn sub-agent?

**Quyết định: Hybrid — lane agent tự làm probe đơn giản, spawn sub-agent cho probe chuyên sâu.**

- Probe `run_mode: inline` (đọc code, check pattern, grep) → lane agent tự xử lý
- Probe `run_mode: agent:{type}` (domain-expert-review, security-deep-scan) → spawn sub-agent với `subagent_type={type}`
- Cơ sở: procedure file của probe đã có field `run_mode` — lane agent chỉ cần tuân thủ

### Q4: Resume — per-lane hay per-probe?

**Quyết định: Per-probe resume.**

- Mỗi probe đã ghi `raw/{PROBE_ID}.json` → nếu file tồn tại và valid (`signals[]` field) → skip
- Infrastructure có sẵn vì mỗi probe đã có output file riêng
- Lợi ích lớn khi profile=exhaustive: resume sau 80% probes chỉ chạy nốt 20%
- Implementation: 1 dòng check `[ -f "$RAW_OUT" ] && jq -e '.signals' "$RAW_OUT" >/dev/null 2>&1 && continue`

### Q5: Hard timeout cho Phase 4?

**Quyết định: 30 phút hard timeout.**

- Đợt 1 (10 lanes): ~8 phút | Đợt 2 (1 lane): ~5 phút
- Buffer retry (E040-E042): ~10 phút
- Monitor + collect + validate (Step 4.6-4.10): ~5 phút
- Vượt 30 phút → lane đang chạy bị mark `failed` E046, orchestrator thu thập kết quả đã có và tiếp tục
