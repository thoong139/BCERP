# 01 — Findings Chi Tiết (G1-G10)

> **Phiên bản:** v0.1 — 2026-04-29
> **Phạm vi:** `/wf-manage-change` v2.0.3 (1 skill, ~2,800 dòng + 0 scripts)
> **Mục đích:** Cung cấp evidence-based findings để biện minh cho từng thay đổi trong v3.0
> **Quy ước severity:**
> - **P0** — Phải fix, ảnh hưởng correctness/security/concurrent safety
> - **P1** — Nên fix, ảnh hưởng consistency/UX/cross-skill integration
> - **P2** — Có thể fix, polish/minor

---

## P0 — Critical (3 findings)

### G1 — KHÔNG có Lock/Heartbeat Mechanism

**Severity:** P0
**Files:** SKILL.md (toàn bộ), procedures/_shared.md, procedures/phase4a-registry-docs.md, procedures/phase4b-code.md

**Evidence so sánh:**

| Cơ chế | wf-fix-bugs v7.1 | wf-implement-feature v4.0 | wf-manage-change v2.0.3 |
|--------|-------------------|---------------------------|--------------------------|
| Per-session `.lock` file | Có (PID/host/user/heartbeat) | Có (PID/host/user/scope_files) | **KHÔNG** |
| Heartbeat daemon | Có (30s interval) | Không (có acquire/release) | **KHÔNG** |
| Stale detection | Có (60min default) | Có (timestamp-based) | **KHÔNG** |
| Cross-host detection | Có (hostname + PID) | Có (hostname + PID) | **KHÔNG** |
| EXIT/INT/TERM trap | Có (cleanup lock) | Có (cleanup lock) | **KHÔNG** |
| Registry lock | Không (không ghi registry) | Không (impl_status only) | **KHÔNG** (nhưng ghi registry ở Phase 4a.5) |

**Tác động correctness:**
- Developer A chạy `/wf-manage-change "Thay doi cach tinh phi..."` → Phase 4a.5 đang update registry
- Developer B chạy `/wf-manage-change "Them tinh nang..."` cùng lúc → Phase 4a.5 đọc registry cũ → ghi đè changes của A
- Kết quả: registry mất changes của A, features bị inconsistent
- Trên GitHub: merge conflict khi push, hoặc silent overwrite nếu không pull trước

**wf-manage-change ĐẶC BIỆT cần registry lock** vì:
1. Phase 4a.5 ghi registry (update requirements/features/impl_status)
2. Phase 4b.6 ghi lại impl_status = "done" sau code update
3. Multiple changes cùng lúc → data loss

**Đề xuất:**
```
.mc-data/work/wf-manage-change/
├── .locks/
│   └── registry.lock    # Cross-session lock cho registry updates
└── $CHANGE_ID/
    └── .session.lock    # Per-session lock
```

Script: `mc-acquire-lock.sh --type=session --id=$CHANGE_ID` và `mc-acquire-lock.sh --type=registry`.

---

### G2 — index.json KHÔNG concurrent-safe

**Severity:** P0
**Files:** procedures/phase0-intake.md:49-51, procedures/_shared.md:69-71, templates/index.json

**Evidence:**

```json
// templates/index.json — full JSON object
{
  "active_session": "CHG-20260429-001",
  "sessions": [
    {"change_id": "CHG-20260429-001", "status": "in_progress", ...}
  ]
}
```

**Vấn đề:**
1. Full JSON `index.json` không append-only → phải read toàn bộ → modify → write toàn bộ
2. 2 process đọc cùng lúc → cùng thấy sessions.length = 1 → cùng generate `CHG-20260429-002` → cùng write → 1 ghi đè cái kia
3. Anti-collision check (GAP-1 fix, Step 0.1) chỉ re-read 1 lần → vẫn race giữa read và write
4. Git merge conflict: 2 máy cùng thêm session mới → JSON conflict khó resolve

**So sánh với wf-fix-bugs v7.1:**
```
.mc-data/work/wf-fix-bugs/_index/sessions.jsonl  (append-only)
{"session_id":"2026-04-28-module-payment-001","status":"completed",...}
{"session_id":"2026-04-28-module-order-002","status":"in_progress",...}
```
- JSONL: mỗi dòng 1 entry → `echo >> file` atomic trên Unix → concurrent-safe
- Git merge: 2 máy cùng append → auto-merge (không conflict)
- Lookup: `grep` thay vì parse JSON

**Đề xuất:**
- Thêm `_index/sessions.jsonl` (append-only) làm primary index
- Giữ `index.json` cho `--status` display (dual-write)
- Session lookup dùng `grep sessions.jsonl` (atomic, fast)

---

### G3 — KHÔNG có Bash Script Delegation

**Severity:** P0 (ưu tiên 3 — token waste ảnh hưởng trực tiếp cost và speed)
**Files:** Tất cả 10 phase files + _shared.md

**Evidence so sánh:**

| Metric | wf-fix-bugs v7.1 | wf-implement-feature v4.0 | wf-manage-change v2.0.3 |
|--------|-------------------|---------------------------|--------------------------|
| Bash scripts | 16 scripts | 10 scripts | **0 scripts** |
| Common helpers | wf-fix-common.sh | implement-common.sh | **Không có** |
| Lock management | acquire-lock.sh, heartbeat.sh | implement-acquire-lock.sh | **Không có** |
| Validation | validate-gate.sh, cqg-verify.sh | implement-postgate.sh | **Không có** |
| Session mgmt | session.sh, migrate-sessions.sh | implement-migrate-v3-to-v4.sh | **Không có** |
| Report builder | report-builder.sh, impact-builder.sh | — | **Không có** |

**Tác động token waste:**

Mỗi lần chạy, AI phải generate inline bash thay vì gọi 1 script:

| Task | Inline (tokens) | Script call (tokens) | Saving |
|------|-----------------|---------------------|--------|
| Generate session ID (with retry) | ~150 | ~40 | **73%** |
| Registry backup + validate | ~100 | ~30 | **70%** |
| Lock acquire (PID/host/user) | ~80 | ~25 | **69%** |
| T1→T4 POST-GATE validation | ~200 | ~50 | **75%** |
| Registry safe-write (read→modify→jq validate) | ~180 | ~45 | **75%** |
| **Total per run (Phase 0-6)** | ~710 | ~190 | **73%** |

**Tác động chất lượng:**
- Inline bash không có error handling đồng nhất
- Không có shared helpers → mỗi phase file tự viết riêng → inconsistency
- Không test được riêng biệt (không có unit test cho inline bash)

**Đề xuất:** 10 scripts trong `.claude/scripts/wf-manage-change/` — xem `02-architecture-design.md` §Bash Scripts.

---

## P1 — High (4 findings)

### G4 — Không có machine-readable cross-skill artifact

**Severity:** P1
**Files:** _contract.json:147-165 (cross_skill_contracts)

**Evidence:**

wf-fix-bugs v7.1 sản xuất `fix-impact.json`:
```json
{
  "$schema": "fix-impact-v1",
  "session_id": "...",
  "fix_summary": { "total_issues": N, "fixed": N, ... },
  "affected_artifacts": { "code_files": [...], "registry_changes": [...] },
  "verify_evidence": { "preflight_status": "PASS", ... },
  "audit_chain": { "checksum_pre": "sha256:...", "checksum_post": "sha256:..." }
}
```

wf-manage-change chỉ sản xuất `change-report.md` (markdown). Skills downstream muốn consume phải parse markdown → fragile.

**Tác động:**
- `/wf-verify-sync` muốn cross-check registry changes → phải đọc `change-report.md` section "Registry Updated" → regex parsing, dễ break khi format thay đổi
- `/wf-implement-feature` muốn biết files nào vừa thay đổi → phải parse "Changes Made" section
- Không có checksum/audit_chain → không verify được integrity

**Đề xuất:** Tạo `change-impact.json` (schema `change-impact-v1`) — xem `02-architecture-design.md` §change-impact.json.

---

### G5 — change-plan.md thiếu `change_id`

**Severity:** P1
**Files:** `templates/change-plan.md`, `procedures/phase3-plan.md:66-93`

**Evidence:**

Phase 3 Plan Structure (procedures/phase3-plan.md:66):
```json
{
  "change_id": "CHG-YYYYMMDD-NNN",  // ← procedure expects field này
  ...
}
```

Template `templates/change-plan.md` header:
```markdown
| Field | Value |
|-------|-------|
| **Change Type** | [TYPE] |
| **Total Tasks** | [N] |
| **Risk Level** | [LEVEL] |
| **Estimated Complexity** | [LOW/MEDIUM/HIGH] |
```

→ **Không có `change_id`** trong template header. AI phải tự biết thêm vào → ambiguity, có thể quên.

**Đề xuất:** Thêm dòng `| **Change ID** | $CHANGE_ID |` vào template header.

---

### G6 — phase-summary.md không có template (CORE-031 violation)

**Severity:** P1
**Files:** `_contract.json:119-122`, `procedures/phase6-report.md:70-95`

**Evidence:**

`_contract.json:119-122`:
```json
{
  "path": "$SESSION_DIR/phase-summary.md",
  "template": null,
  "required": true,
  "note": "CORE-028: ... Free-form — khong co template file."
}
```

CORE-031 quy định: "Mọi output file PHẢI được tạo từ template: READ template → POPULATE data → WRITE output."

`phase-summary.md` là output file required nhưng `template = null` → **violation CORE-031**.

**So sánh với skills khác:**
- wf-fix-bugs: phase-summary.md cũng free-form (CORE-028) → cũng template=null → cũng violation
- wf-implement-feature: phase-summary.md cũng free-form
- Nhưng skill mới nên有机会 fix trước khi release

**Đề xuất:** Tạo `templates/phase-summary.md` — minimal template với required sections (tiêu đề, Đã thay đổi gì, Tại sao, Kết quả kiểm tra, File ảnh hưởng, Bước tiếp theo) + placeholder instructions. Giữ "free-form population" nhưng tuân thủ READ→POPULATE→WRITE.

---

### G7 — Resume routing nhúng trong _shared.md

**Severity:** P1
**Files:** `procedures/_shared.md:283-368` (~85 dòng)

**Evidence:**

_shared.md chứa 11 sections (~430 dòng tổng):
1. State Variables Glossary
2. Cross-Phase Data Flow
3. Session Isolation
4. LEGACY Detection
5. Expert Selection Map
6. Registry Safe-Write Rules
7. Agent Prompt Templates
8. **Checkpoint Protocol** (~30 dòng)
9. **Resume Logic & Routing Table** (~85 dòng) ← phân tán
10. CORE-026/028
11. Fix Rules

**Vấn đề:**
- Resume logic là functionality riêng biệt, không phải "shared" cross-cutting
- wf-fix-bugs tách riêng `procedures/resume-routing.md` → dễ maintain, dễ test
- _shared.md đã 430 dòng → thêm resume logic làm nó phình to

**Đề xuất:** Tách `procedures/resume-routing.md` (80-90 dòng), giữ reference trong _shared.md.

---

## P2 — Medium (3 findings)

### G8 — Protocol references chưa đầy đủ

**Severity:** P2
**Files:** SKILL.md:114

**Evidence:**

SKILL.md Protocol list: "Protocol 1, 6, 7, 8, 9, 10, 10.4, 11, 14, 15, 19"

**Protocol được dùng nhưng KHÔNG được reference:**

| Protocol | Sử dụng tại | Reference hiện tại |
|----------|------------|-------------------|
| 16 (CDG) | Phase 4a.2 DELETE_FEATURE CDG | Không có trong list |
| 17 (Agent Spot-Check) | Phase 1 DEEP Step 1.4b | Không có trong list |
| 18 (Session Isolation) | CORE-030 implementation | Không có trong list |

**Đề xuất:** Thêm "Protocol 16, 17, 18" vào SKILL.md Protocol list.

---

### G9 — Session ID generation không có retry loop

**Severity:** P2
**Files:** `procedures/phase0-intake.md:49`

**Evidence:**

Step 0.1 hiện tại:
```
... → NNN = count + 1 → $CHANGE_ID = CHG-$CHANGE_DATE-$(printf "%03d" $NNN)
→ Đọc lại index.json → kiểm tra $CHANGE_ID chưa tồn tại
→ nếu đã tồn tại → tăng NNN thêm 1 → lặp lại check (tối đa 10 lần)
```

So sánh wf-fix-bugs v7.1:
```bash
# scripts/wf-fix-common.sh:generate_session_id
for attempt in $(seq 1 $MAX_RETRIES); do
  session_id="${prefix}-$(printf '%03d' $attempt)"
  if ! grep -q "\"session_id\":\"${session_id}\"" "$INDEX_FILE"; then
    echo "$session_id"
    return 0
  fi
  sleep 0.05  # 50ms backoff
done
```

**Vấn đề:**
- Inline logic không có sleep/backoff giữa retry
- Không extract thành function → khó test riêng
- wf-fix-bugs có 50ms backoff giữa mỗi retry → giảm race window

**Đề xuất:** Delegate sang `mc-generate-session-id.sh` với retry loop + 50ms backoff.

---

### G10 — change-status.json thiếu fields cho eval coverage

**Severity:** P2
**Files:** `templates/change-status.json`

**Evidence:**

Eval #14 (phase2-user-reject-rescopes-then-approves) test assertion:
```json
{"type": "content_check", "text": "change-status.json co phase2.retry_count >= 1 hoac error_log co entry phase=phase2 action=user_rejected"}
```

Nhưng template `change-status.json` không có field:
- `phase2_retry_count` — missing
- `phases.phase2.retry_count` — missing

Cũng thiếu fields được populate ở resume nhưng không có trong template:
- `intake.deprecated_modules` (set at Step 0.4b, re-bind at Resume Step 4)
- `intake.legacy_mode` (set at Step 0.4)
- `intake.referenced_artifacts` (set at Step 0.7)

**Đề xuất:** Thêm các fields vào template:
```json
"phase2_retry_count": 0,
"intake": {
  ...existing fields...,
  "deprecated_modules": [],
  "legacy_mode": false,
  "referenced_artifacts": { "systems": [], "modules": [], "features": [], "req_ids": [] }
}
```

---

## Tóm tắt severity

| Severity | Count | Findings |
|----------|-------|----------|
| P0 | 3 | G1 (Lock), G2 (JSONL), G3 (Bash scripts) |
| P1 | 4 | G4 (change-impact), G5 (change-plan), G6 (phase-summary template), G7 (resume routing) |
| P2 | 3 | G8 (Protocol refs), G9 (Session ID retry), G10 (Status fields) |
| **Total** | **10** | |
