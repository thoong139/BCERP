# Wave 1 — SSOT Counts + Status Honesty (G1 + G7)

> **Mục tiêu**: Số liệu chính xác + status report trung thực. Đây là nền tảng cho Wave 2 (loop logic cần counts đúng để biết khi nào dừng).
>
> **ETA**: 6-9h
> **Đầu vào**: Hiện trạng v10.18.0
> **Đầu ra**: v10.19.0 (intermediate release sau Wave 1)

## Tasks chi tiết

### Task W1-T1: `verify-execute-outputs.sh` — Derive counts từ fix-log.json (G1)

**File**: `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh`

**Thay đổi**:
- **Line 99-107** (hiện tại regex extract FIXED/DEFERRED/FAILED từ fix-report.md):
  ```bash
  # BEFORE
  FIXED_COUNT=$(grep -oiE 'fixed[:= ]*[0-9]+|...' "$FIX_REPORT" | head -1 | ... || echo 0)
  ```
  → Đổi thành đọc từ ISSUES_JSON đã build ở line 233-253:
  ```bash
  # AFTER (extract from fix-log.json structured entries — SSOT)
  if [ -s "$FIX_LOG" ]; then
    FIXED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and (.result == "fixed" or .result == "resolved"))] | length' "$FIX_LOG" 2>/dev/null || echo 0)
    DEFERRED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and .result == "deferred")] | length' "$FIX_LOG" 2>/dev/null || echo 0)
    FAILED_COUNT=$(jq '[.entries[]? | select(.issue_id != null and .result == "failed")] | length' "$FIX_LOG" 2>/dev/null || echo 0)
  else
    # Fallback regex chỉ khi fix-log không có (legacy support)
    FIXED_COUNT=$(grep -oiE 'fixed[:= ]*[0-9]+|...' "$FIX_REPORT" | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
    # ... tương tự cho DEFERRED + FAILED
    echo "WARN: fix-log.json missing — fallback regex extraction (deprecated)" >&2
  fi
  ```

**Tác động**: Counts giờ đến từ fix-log structured entries (mỗi entry có issue_id duy nhất + result enum). Không còn double-count, không regex sai.

**Risk**: Nếu agent không write fix-log entries đúng format → counts = 0. Cần verify agent prompt yêu cầu append fix-log per fix.

**Acceptance**:
```bash
# Re-run trên session test
cd "D:/Working/EUREKA-2026"
SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/2026-05-16-module-settings-01" \
  bash .claude/scripts/wf-fix-bugs/verify-execute-outputs.sh | jq '.fixed_count'
# Expected: 45 (matches fix-status.json), not 35 (regex artifact)
```

---

### Task W1-T2: `cqg1-numeric.sh` — Strict mode (G1)

**File**: `.claude/scripts/wf-fix-bugs/cqg1-numeric.sh`

**Thay đổi**:
- **Line 82-99** (fast-path JSON v2 với fallback regex):
  - Bỏ fallback regex Markdown (line 102-106)
  - Nếu `fix-execution-result.json` thiếu hoặc invalid schema v2 → FAIL E070 với message rõ ràng
  - Bỏ fallback regex extract từ `fix-plan.md` (line 72-74) — đọc từ `fix-plan-counts.json` (file mới do Task W1-T3 tạo)

**Pseudo-code mới**:
```bash
# Strict EXPECTED from fix-plan-counts.json
FIX_PLAN_COUNTS="$SESSION_DIR/phase5-triage/fix-plan-counts.json"
[ -s "$FIX_PLAN_COUNTS" ] || { echo "ERROR: fix-plan-counts.json missing (run derive-fix-plan-counts.sh first)" >&2; exit 1; }
EXPECTED_FIXED=$(jq -r '.expected.fixed // 0' "$FIX_PLAN_COUNTS")
EXPECTED_DEFERRED=$(jq -r '.expected.deferred // 0' "$FIX_PLAN_COUNTS")
EXPECTED_FAILED=$(jq -r '.expected.failed // 0' "$FIX_PLAN_COUNTS")

# Strict ACTUAL from fix-execution-result.json v2
[ -s "$FIX_EXEC_RESULT" ] || { echo "ERROR: fix-execution-result.json missing" >&2; exit 1; }
SCHEMA=$(jq -r '."$schema" // ""' "$FIX_EXEC_RESULT")
[ "$SCHEMA" = "fix-execution-result-v2" ] || [ "$SCHEMA" = "fix-execution-result-v1" ] \
  || { echo "ERROR: fix-execution-result.json schema invalid (expected v1 or v2, got: $SCHEMA)" >&2; exit 1; }

ACTUAL_FIXED=$(jq -r '.aggregated.fixed_total // .fixed_total // 0' "$FIX_EXEC_RESULT")
ACTUAL_DEFERRED=$(jq -r '.aggregated.deferred_total // .deferred_total // 0' "$FIX_EXEC_RESULT")
ACTUAL_FAILED=$(jq -r '.aggregated.failed_total // .failed_total // 0' "$FIX_EXEC_RESULT")
ACTUAL_SOURCE="json_v2"
```

**Backward-compat**:
- Sessions v10.x không có `fix-plan-counts.json` → script đầu chạy `derive-fix-plan-counts.sh` để tạo trên-the-fly (graceful migration)
- Env var escape hatch: `MCV3_FIX_CQG1_ALLOW_REGEX=1` cho phép fallback regex (debug only, WARN log)

**Acceptance**:
- CQG-1 FAIL nếu deviation thực > 5% (no "substance-based bypass")
- Sessions v10.x vẫn pass nếu numbers thực sự khớp

---

### Task W1-T3: Script mới `derive-fix-plan-counts.sh` (G1)

**File mới**: `.claude/scripts/wf-fix-bugs/derive-fix-plan-counts.sh`

**Mục đích**: Đếm chính xác expected counts từ `fix-plan.md` (Phase 5 output). Lưu vào JSON deterministic thay vì regex sai.

**Logic**:
```bash
#!/usr/bin/env bash
# derive-fix-plan-counts.sh — Derive expected counts từ fix-plan.md execution table
# Run trong Phase 5 (sau khi triage hoàn tất) HOẶC Phase 7 fallback nếu thiếu
set -eu

[ -n "${SESSION_DIR:-}" ] || { echo "ERROR: SESSION_DIR required" >&2; exit 1; }

FIX_PLAN="$SESSION_DIR/phase5-triage/fix-plan.md"
ISSUE_REG="$SESSION_DIR/phase5-triage/issue-registry.json"
TARGET="$SESSION_DIR/phase5-triage/fix-plan-counts.json"

[ -s "$FIX_PLAN" ] || { echo "ERROR: fix-plan.md missing" >&2; exit 1; }

# Count items by Action column trong markdown table
# Table format: | Priority | Issue ID | Action | File(s) | Est. Time | [CDG] Markers |
# Actions: fix | manual_review | escalate | skip
FIX_COUNT=$(grep -cE '^\| (CRITICAL|HIGH|MEDIUM|LOW) \|.*\| fix \|' "$FIX_PLAN" 2>/dev/null || echo 0)
MANUAL_COUNT=$(grep -cE '^\| (CRITICAL|HIGH|MEDIUM|LOW) \|.*\| manual_review \|' "$FIX_PLAN" 2>/dev/null || echo 0)
ESCALATE_COUNT=$(grep -cE '^\| (CRITICAL|HIGH|MEDIUM|LOW) \|.*\| escalate \|' "$FIX_PLAN" 2>/dev/null || echo 0)
SKIP_COUNT=$(grep -cE '^\| (CRITICAL|HIGH|MEDIUM|LOW) \|.*\| skip \|' "$FIX_PLAN" 2>/dev/null || echo 0)

# Cross-validate với issue-registry.json (nếu có)
REG_FIX=0
REG_DEFERRED=0
if [ -s "$ISSUE_REG" ]; then
  REG_FIX=$(jq '[.issues[]? | select(.fixability == "auto_fix" or .fixability == "agent_fix" or .fixability == "AUTO_FIX" or .fixability == "AGENT_FIX")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
  REG_DEFERRED=$(jq '[.issues[]? | select(.fixability == "manual_fix" or .fixability == "escalate" or .fixability == "skip" or .fixability == "MANUAL_FIX" or .fixability == "ESCALATE" or .fixability == "SKIP")] | length' "$ISSUE_REG" 2>/dev/null || echo 0)
fi

# Atomic write
TMP="$TARGET.tmp.$$"
jq -n \
  --argjson plan_fix "$FIX_COUNT" \
  --argjson plan_manual "$MANUAL_COUNT" \
  --argjson plan_escalate "$ESCALATE_COUNT" \
  --argjson plan_skip "$SKIP_COUNT" \
  --argjson reg_fix "$REG_FIX" \
  --argjson reg_def "$REG_DEFERRED" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    "$schema": "fix-plan-counts-v1",
    "generated_at": $ts,
    "source": "fix-plan.md + issue-registry.json cross-validation",
    "expected": {
      "fixed": $plan_fix,
      "deferred": ($plan_manual + $plan_escalate + $plan_skip),
      "failed": 0
    },
    "breakdown": {
      "plan_action_fix": $plan_fix,
      "plan_action_manual_review": $plan_manual,
      "plan_action_escalate": $plan_escalate,
      "plan_action_skip": $plan_skip,
      "registry_fixability_auto_or_agent": $reg_fix,
      "registry_fixability_manual_escalate_skip": $reg_def
    }
  }' > "$TMP" \
  && jq '.' "$TMP" >/dev/null \
  && mv "$TMP" "$TARGET" \
  || { rm -f "$TMP"; echo "ERROR: write fail" >&2; exit 3; }

echo "OK: $TARGET written (expected_fixed=$FIX_COUNT, expected_deferred=$((MANUAL_COUNT + ESCALATE_COUNT + SKIP_COUNT)))"
```

**Integration points**:
- `phase5-triage/G-reports-finalize.md` (hoặc tương đương): Thêm step "Derive fix-plan-counts.json" cuối Phase 5
- `phase7-verify/B-cqg1.md`: PRE-GATE check `fix-plan-counts.json` tồn tại; nếu không → chạy derive-fix-plan-counts.sh (graceful migration cho v10.x sessions)

---

### Task W1-T4: `generate-phase7-reports.sh` — Read counts từ SSOT (G1)

**File**: `.claude/scripts/wf-fix-bugs/generate-phase7-reports.sh`

**Thay đổi**:
- **Line 75-77** (env vars defaults):
  ```bash
  # BEFORE
  FIXED_COUNT="${FIXED_COUNT:-0}"
  DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
  FAILED_COUNT="${FAILED_COUNT:-0}"
  ```
  → Đổi thành đọc từ fix-execution-result.json:
  ```bash
  # AFTER
  FIX_EXEC_RESULT="$SESSION_DIR/phase6-execute/fix-execution-result.json"
  if [ -s "$FIX_EXEC_RESULT" ]; then
    FIXED_COUNT_SSOT=$(jq -r '.aggregated.fixed_total // .fixed_total // 0' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
    DEFERRED_COUNT_SSOT=$(jq -r '.aggregated.deferred_total // .deferred_total // 0' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
    FAILED_COUNT_SSOT=$(jq -r '.aggregated.failed_total // .failed_total // 0' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
    # Override env vars nếu SSOT có valid data (env vars có thể stale từ phase 6 first run)
    [ "$FIXED_COUNT_SSOT" -gt 0 ] && FIXED_COUNT="$FIXED_COUNT_SSOT"
    [ "$DEFERRED_COUNT_SSOT" -gt 0 ] && DEFERRED_COUNT="$DEFERRED_COUNT_SSOT"
    [ "$FAILED_COUNT_SSOT" -gt 0 ] && FAILED_COUNT="$FAILED_COUNT_SSOT"
  else
    FIXED_COUNT="${FIXED_COUNT:-0}"
    DEFERRED_COUNT="${DEFERRED_COUNT:-0}"
    FAILED_COUNT="${FAILED_COUNT:-0}"
  fi
  ```

**Tác động**: orchestrator-summary.md, fix-impact.json, Phase7-report.md đều dùng SSOT values → đảm bảo 3 file này nhất quán với fix-status.json + fix-execution-result.json.

---

### Task W1-T5: Pipeline status enum mở rộng (G7)

**File 1**: `.claude/skills/workflow/wf-fix-bugs/templates/phase1-init/fix-status.json`

Thêm `_schema_notes` hoặc field doc cho `pipeline_status` enum:
```jsonc
{
  "pipeline_status": "init",  // init | in_progress | DONE | DONE_CLEAN | DONE_WITH_DEFERRED | DONE_NEEDS_FOLLOWUP | FAILED
  ...
}
```

**File 2**: `.claude/scripts/wf-fix-bugs/finalize-phase7.sh`

Sau khi pre-finalize `pipeline_status=DONE`, đọc fix-execution-result.json + unsanctioned-defers.json (W2 sẽ tạo, hiện chưa có nên skip) để decide enum value:
```bash
# Determine pipeline_status nuance
PIPELINE_STATUS_FINAL="DONE"

# Wave 1 logic (basic):
DEFERRED_TOTAL=$(jq -r '.aggregated.deferred_total // 0' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)
FIXED_TOTAL=$(jq -r '.aggregated.fixed_total // 0' "$FIX_EXEC_RESULT" 2>/dev/null || echo 0)

if [ "$DEFERRED_TOTAL" -eq 0 ]; then
  PIPELINE_STATUS_FINAL="DONE_CLEAN"
elif [ "$DEFERRED_TOTAL" -gt 0 ]; then
  PIPELINE_STATUS_FINAL="DONE_WITH_DEFERRED"
fi

# Wave 3 sẽ add: nếu queue file có entries → DONE_NEEDS_FOLLOWUP

# Update fix-status.json
jq --arg ps "$PIPELINE_STATUS_FINAL" '.pipeline_status = $ps' "$FIX_STATUS" > "$TMP" && mv "$TMP" "$FIX_STATUS"
```

**File 3**: `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md`

Thêm section đầu sau "Tổng Quan":
```markdown
## Trạng Thái Pipeline

[PIPELINE_STATUS_BANNER]
```

Script populate `[PIPELINE_STATUS_BANNER]`:
- `DONE_CLEAN` → `✅ **Hoàn thành sạch** — Tất cả issues đã được xử lý.`
- `DONE_WITH_DEFERRED` → `⚠️ **Hoàn thành có deferred** — [N] issues còn lại cần xử lý thủ công (MANUAL/ESCALATE/SKIP). Xem deferred-issues.md.`
- `DONE_NEEDS_FOLLOWUP` → `🔄 **Cần follow-up** — [N] issues out-of-scope đã ghi vào queue. Chạy /wf-fix-bugs --resume-followup để xử lý.`
- `DONE` (legacy) → giữ nguyên không banner

---

## Smoke Tests cho Wave 1

### Test W1-S1: Counts consistency
```bash
cd "D:/Working/EUREKA-2026"
SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/2026-05-16-module-settings-01"

# After Wave 1 changes applied:
# Re-run Phase 6 verify (no actual fix execution, just regenerate counts)
bash .claude/scripts/wf-fix-bugs/verify-execute-outputs.sh > /tmp/verify-output.json
FIXED_VERIFY=$(jq '.fixed_count' /tmp/verify-output.json)

# Compare với fix-status.json
FIXED_STATUS=$(jq '.fixed' "$SESSION_DIR/fix-status.json")

# Compare với fix-execution-result.json
FIXED_EXEC=$(jq '.aggregated.fixed_total' "$SESSION_DIR/phase6-execute/fix-execution-result.json")

# All 3 must match
[ "$FIXED_VERIFY" = "$FIXED_STATUS" ] && [ "$FIXED_STATUS" = "$FIXED_EXEC" ] \
  && echo "PASS: counts consistent ($FIXED_VERIFY)" \
  || echo "FAIL: counts mismatch (verify=$FIXED_VERIFY, status=$FIXED_STATUS, exec=$FIXED_EXEC)"
```

### Test W1-S2: CQG-1 strict mode
```bash
# Manufacture bad fix-execution-result.json (deviation > 5%)
TMP_EXEC=$(mktemp)
jq '.aggregated.fixed_total = 5' "$SESSION_DIR/phase6-execute/fix-execution-result.json" > "$TMP_EXEC"
cp "$TMP_EXEC" "$SESSION_DIR/phase6-execute/fix-execution-result.json"

# CQG-1 must FAIL E070
SESSION_DIR="$SESSION_DIR" bash .claude/scripts/wf-fix-bugs/cqg1-numeric.sh
RC=$?
[ "$RC" -eq 4 ] && echo "PASS: CQG-1 strict mode triggered" || echo "FAIL: CQG-1 should have failed with RC=4, got $RC"

# Restore
git checkout "$SESSION_DIR/phase6-execute/fix-execution-result.json" 2>/dev/null
```

### Test W1-S3: Pipeline status enum
```bash
# After Wave 1, fix-status.json should have pipeline_status = "DONE_WITH_DEFERRED"
PIPELINE_STATUS=$(jq -r '.pipeline_status' "$SESSION_DIR/fix-status.json")
[ "$PIPELINE_STATUS" = "DONE_WITH_DEFERRED" ] && echo "PASS: status enum applied" || echo "INFO: status = $PIPELINE_STATUS (might be legacy DONE if pre-Wave 1)"
```

### Test W1-S4: Backward-compat
```bash
# Run existing smoke tests
bash .claude/scripts/wf-fix-bugs/phase6-routing-smoke-test.sh
bash .claude/scripts/wf-fix-bugs/phase7-routing-smoke-test.sh
# Both must pass 100%
```

---

## Files thay đổi (Wave 1 summary)

| File | Loại | Mô tả |
|------|------|------|
| `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh` | MODIFY | Counts từ fix-log.json structured |
| `.claude/scripts/wf-fix-bugs/cqg1-numeric.sh` | MODIFY | Strict mode, bỏ regex fallback |
| `.claude/scripts/wf-fix-bugs/derive-fix-plan-counts.sh` | CREATE | Đếm expected từ fix-plan.md |
| `.claude/scripts/wf-fix-bugs/generate-phase7-reports.sh` | MODIFY | Read counts từ SSOT |
| `.claude/scripts/wf-fix-bugs/finalize-phase7.sh` | MODIFY | Decide pipeline_status enum |
| `.claude/skills/workflow/wf-fix-bugs/templates/phase1-init/fix-status.json` | MODIFY | Enum doc |
| `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md` | MODIFY | Status banner section |
| `.claude/skills/workflow/wf-fix-bugs/procedures/phase5-triage/G-reports-finalize.md` | MODIFY | Call derive-fix-plan-counts.sh |
| `.claude/skills/workflow/wf-fix-bugs/procedures/phase7-verify/B-cqg1.md` | MODIFY | Doc PRE-GATE strict mode |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | MODIFY | Version bump v10.18.0 → v10.19.0, update description |
| `.claude/skills/workflow/wf-fix-bugs/_contract.json` | MODIFY | Add fix-plan-counts.json output entry |
| `CHANGELOG.md` | MODIFY | Wave 1 release notes |

**Total**: 12 files (5 script changes, 1 new script, 4 template/SKILL updates, 2 metadata)
