# Phase 4 Group G — Generate Phase 4 Report + Finalize (Steps 4.8+4.9)

> **Entry condition:** Group F POST-GATE PASS (all lanes terminal, T1-T4 validated, signals_total quantified).
> **Exit condition:** `Phase4-report.md` + `phase4-summary.json` written + `fix-status.phases.phase4.status="completed"` + TRACE COMPLETE.
> **Next:** [phase4-find-bugs/POST-GATE.md](POST-GATE.md) (T1-T4 final validation → Phase 5).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E035, E043
> - [`_shared/07-execution-trace.md`](../_shared/07-execution-trace.md) — TRACE COMPLETE pattern

> **⚠ Phase 4 finalize SPECIAL CASE:** Step 4.9 GIỮ `finalize-phase4.sh` (KHÔNG migrate sang shared `phase-finalize.sh`). **Lý do:** aggregation logic specific (signals_total từ 3 stream × N lanes, lanes_completed/failed từ filesystem scan, probe_failures từ log) — generic phase-finalize.sh chỉ hỗ trợ static PHASE_TOP_FIELDS merge. Pattern giống Phase 7 finalize-phase7.sh.

## Input contract (env vars từ Group F)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID`, `$DIMS_ARRAY` | Pipeline state |
| `$LANES_COMPLETED`, `$LANES_FAILED`, `$SIGNALS_TOTAL`, `$PROBE_FAILURES` | Từ Group F |
| `$STATUS_PASS_FAIL` (set bởi orchestrator) | "PASS" mặc định, "FAIL" nếu POST-GATE T1-T4 fail |
| `$PROFILE`, `$SCOPE`, `$INTERFACE_TYPE` (optional) | Cho summary metadata |
| `phase4-find-bugs/lanes/QD*/{lane-status,signals,probe-failures}.json/log` | Aggregation source |
| `phase4-find-bugs/cdg-tokens.json` (nếu E090/E090b fired) | CDG decisions cho summary |

## Output contract (env vars truyền sang POST-GATE)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `phase4-find-bugs/Phase4-report.md` | 4.8 | Tiếng Việt ≤15 dòng (CORE-028) |
| `phase4-find-bugs/phase4-summary.json` | 4.8 | Cross-skill artifact CORE-036 (schema `phase4-summary-v1` + audit_chain sha256) |
| `fix-status.phases.phase4.status = "completed"` | 4.9 | Atomic update |
| `fix-status.signals_total` | 4.9 | Top-level aggregate |
| `session-log.json` | 4.9 | APPEND `{phase:4, event:"COMPLETE"}` |

---

## Step 4.8 — Generate Phase 4 Report + Summary (generate-phase4-report.sh, CORE-028 + CORE-036)

**Mục đích:** Tạo HAI artifacts từ aggregated data (lane-status, signals.json per stream, probe-failures.log, cdg-tokens.json):

1. **`Phase4-report.md`** — tiếng Việt ≤15 dòng (CORE-028) cho non-specialist. Tóm tắt + pointer đến summary.
2. **`phase4-summary.json`** (v10.10, schema `phase4-summary-v1`) — machine-readable cross-lane rollup cho downstream phases (5/6/7). Bao gồm:
   - per-dim breakdown (severity/fixability/duration)
   - aggregated rollup (by_severity, by_fixability, by_dimension, by_probe, top_fingerprints)
   - `registry_coverage` (REQ-ID/FEAT-ID/MODULE → signal count)
   - `cdg_decisions` (E090/E090b structured)
   - `evidence_index` cross-lane
   - `audit_chain` (sha256 của signals.json + lane-status.json — CORE-036 cross-skill integrity)

Cả 2 file đều populate từ template qua jq/sed (CORE-031). Script là 1 writer (CORE-025) — KHÔNG ghi đè lane outputs.

**Thực thi:**

```bash
export SESSION_DIR SESSION_ID DIMS_ARRAY
export STATUS_PASS_FAIL="${STATUS_PASS_FAIL:-PASS}"  # orchestrator set FAIL nếu POST-GATE fail
export PROFILE SCOPE INTERFACE_TYPE  # cho summary metadata (optional)

bash .claude/scripts/wf-fix-bugs/generate-phase4-report.sh
```

**VERIFY:**

```bash
# T1: Phase4-report.md
test -s "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
grep -q "Phase 4" "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
grep -q "lane" "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
grep -q "signal" "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"
# Verify no placeholders left
! grep -qE '\[[A-Z_]+\]' "$SESSION_DIR/phase4-find-bugs/Phase4-report.md"

# T2: phase4-summary.json (v10.10 cross-skill artifact CORE-036)
test -s "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
jq -e '."$schema" == "phase4-summary-v1"' "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
jq -e '.dimensions | length > 0' "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
jq -e '.aggregated.by_severity and .aggregated.by_fixability' "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
jq -e '.audit_chain.signals_sha256 and .audit_chain.lane_status_sha256' "$SESSION_DIR/phase4-find-bugs/phase4-summary.json"
```

**Downstream consumption (opt-in fast-path, defer):**

- **Phase 5** (`aggregate-and-spot-check.sh`): có thể đọc `aggregated.top_fingerprints` + `registry_coverage` để skip một số bước aggregation. Hiện tại VẪN scan signals.json để giữ tương thích ngược.
- **Phase 7 CQG-2**: có thể đọc `dimensions[QD9/QD10].by_severity` để check còn critical chưa fix thay vì chỉ đếm tổng signals. Hiện tại VẪN dùng count cũ.
- **External tools** (audit, compliance, dashboards): query `phase4-summary.json` 1 lần thay vì duyệt toàn bộ `lanes/`.

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E043 | Template Phase4-report.md / phase4-summary.json không tồn tại (script exit 2) | Kiểm tra `templates/phase4-find-bugs/` |
| E043 | Atomic write fail (script exit 3) | Retry x1 — kiểm tra quyền ghi |

**Cross-ref:** CORE-028 (Phase Report tiếng Việt), CORE-031 (Template Usage Rule), CORE-036 (Cross-Skill Artifact Contract — schema versioned + audit_chain).

---

## Step 4.9 — Finalize: Update fix-status + TRACE COMPLETE (finalize-phase4.sh — SPECIAL CASE)

**Mục đích:** Atomic update `fix-status.json` (mark `phase4.status="completed"` + aggregate `signals_total`) + APPEND COMPLETE event vào session-log.json.

**⚠ SPECIAL CASE — KHÔNG migrate sang shared `phase-finalize.sh`:**

Lý do GIỮ `finalize-phase4.sh`:
- Aggregation logic specific: scan 3 streams (static-scan/runtime/llm-scan) × N lanes → SIGNALS_TOTAL
- Count lanes_completed/failed từ `lane-status.json` files (filesystem scan)
- Count probe_failures từ `probe-failures.log` lines
- Output JSON cho orchestrator parse (signals_total, lanes_completed, lanes_failed, probe_failures)
- Generic `phase-finalize.sh` chỉ hỗ trợ static `PHASE_TOP_FIELDS`/`PHASE_EXTRA_FIELDS` JSON merge — không scan filesystem

Pattern giống Phase 7 `finalize-phase7.sh` (cũng special case do pre-finalize pipeline_status=DONE + dual-write global trace).

**Thực thi:**

```bash
export SESSION_DIR DIMS_ARRAY
export LANES_COMPLETED LANES_FAILED PROBE_FAILURES  # từ Group F output

bash .claude/scripts/wf-fix-bugs/finalize-phase4.sh
```

**VERIFY:**

```bash
jq -e '.phases.phase4.status == "completed"' "$SESSION_DIR/fix-status.json"
jq -e '.signals_total >= 0' "$SESSION_DIR/fix-status.json"
jq -e '.events[-1].phase == 4 and .events[-1].event == "COMPLETE"' "$SESSION_DIR/session-log.json" \
  2>/dev/null || true  # Best-effort (session-log có thể bị thiếu events array nếu JSONL)
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E035 | Atomic write fail (script exit 3) | Retry x1 — kiểm tra lock + quyền |
| E001 | Env vars thiếu (script exit 1) | Re-export SESSION_DIR, DIMS_ARRAY |

**v10.6 note:** Trước v10.6 đây là **2 steps riêng biệt** (4.9 Update fix-status, 4.10 TRACE COMPLETE). Gộp vì cả 2 đều atomic finalize, không có gate giữa (match Phase 3 Step 3.7 Finalize).

**Cross-ref:** CORE-026 (Execution Trace), CORE-035 (Atomic Write), CORE-006 (Registry Safe-Write).

---

## Group G POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase4-find-bugs/Phase4-report.md" \
  && test -s "$SESSION_DIR/phase4-find-bugs/phase4-summary.json" \
  && jq -e '."$schema" == "phase4-summary-v1"' "$SESSION_DIR/phase4-find-bugs/phase4-summary.json" >/dev/null \
  && jq -e '.phases.phase4.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null \
  && echo "Group G PASS" \
  || echo "Group G FAIL"
```

## Next

→ POST-GATE T1-T4 final validation — đọc [`phase4-find-bugs/POST-GATE.md`](POST-GATE.md)
