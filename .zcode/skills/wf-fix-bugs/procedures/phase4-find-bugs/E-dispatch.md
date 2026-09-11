# Phase 4 Group E — PARALLEL Lane Agent Dispatch (Step 4.5 — INLINE Agent spawn)

> **Entry condition:** Group D POST-GATE PASS (N rendered prompts verified by `verify-lane-prompt.sh`).
> **Exit condition:** N × `Agent({subagent_type:"claude", ...})` dispatched trong **MỘT response duy nhất**.
> **Next:** [phase4-find-bugs/F-monitor-validate.md](F-monitor-validate.md) (Monitor Loop + POST-GATE T1-T4).
>
> **Shared protocols cần thiết:**
> - [`_shared/15-agent-prompts.md`](../_shared/15-agent-prompts.md) — Lane Agent Prompt template (8 sections CORE-037)
> - [`_shared/18-playwright.md`](../_shared/18-playwright.md) — Lock-based serialization Protocol 22
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E044, E045, E046

> **⚠ GIỮ ORCHESTRATOR-SIDE — KHÔNG extract sang script:** Agent tool calls (CORE-025 + CORE-037). KHÔNG script được. **SINGLE-RESPONSE PARALLEL DISPATCH bắt buộc.**

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$DIMS_ARRAY`, `$DIMS_COUNT`, `$PW_LANE_COUNT`, `$PW_DIMS` | Pipeline state |
| N rendered prompts (per dim) | Verified bởi Group D |
| `phase3-plan/dimension-plan.json` | `needs_playwright` per dim |

## Output contract (env vars truyền sang Group F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| N spawned agents (async, running) | 4.5 | Mỗi agent ghi `lanes/QD{n}-{slug}/` |
| `lane-status.json` (updated bởi lane agent) | 4.5 → terminal | `pending` → `in_progress` → `completed`/`failed` |

---

## Step 4.5 (Dispatch Phase) — PARALLEL Lane Agent Spawn

**Mục đích:** Spawn TẤT CẢ N lane agents PARALLEL (max 10 concurrent) trong **MỘT response duy nhất** (multiple `Agent` tool calls). Playwright contention được lane agent tự xử lý qua writer-lock (Protocol 22) — orchestrator KHÔNG split Wave.

### ⚠️ MANDATORY DISPATCH PROTOCOL

> **Orchestrator PHẢI dùng `Agent` tool để spawn mỗi lane. KHÔNG tự thực hiện công việc.**
>
> **Single-Response Parallel Dispatch (BẮT BUỘC):** Tất cả `Agent` tool calls (PW + non-PW) PHẢI ở **MỘT response duy nhất** (multiple tool use blocks). Gửi riêng lẻ → agents chạy tuần tự, KHÔNG song song.
>
> **KHÔNG còn Wave 1/Wave 2 split (loại bỏ v10.3):** Spawn TẤT CẢ parallel. Playwright lane TỰ acquire writer-lock `playwright` qua `global-rw-lock.sh` trước khi launch browser.
>
> **Nếu orchestrator tự phân tích code / chạy probe / tạo signals.json** → vi phạm CORE-025 + CORE-037. Dừng ngay, restart Step 4.5.

### Dispatch Example (DIMS_ARRAY 11 dims — full pipeline)

```
Agent(subagent_type="claude", model="opus", description="QD1 Functional Correctness lane",
      prompt=<RENDER với DIM_ID=QD1,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD2 Business Correctness lane",
      prompt=<RENDER với DIM_ID=QD2,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD3 Security lane",
      prompt=<RENDER với DIM_ID=QD3,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD4 Performance lane",
      prompt=<RENDER với DIM_ID=QD4,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD5 UX-A11y lane",
      prompt=<RENDER với DIM_ID=QD5,  NEEDS_PLAYWRIGHT="CÓ">)
Agent(subagent_type="claude", model="opus", description="QD6 Data Integrity lane",
      prompt=<RENDER với DIM_ID=QD6,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD7 Compatibility lane",
      prompt=<RENDER với DIM_ID=QD7,  NEEDS_PLAYWRIGHT="CÓ">)  ← khi --responsive
Agent(subagent_type="claude", model="opus", description="QD8 Observability lane",
      prompt=<RENDER với DIM_ID=QD8,  NEEDS_PLAYWRIGHT="KHÔNG cần">)
Agent(subagent_type="claude", model="opus", description="QD9 Runtime Health lane",
      prompt=<RENDER với DIM_ID=QD9,  NEEDS_PLAYWRIGHT="CÓ">)
Agent(subagent_type="claude", model="opus", description="QD10 Integration lane",
      prompt=<RENDER với DIM_ID=QD10, NEEDS_PLAYWRIGHT="KHÔNG cần">) ← nếu có cross_module_dependencies
Agent(subagent_type="claude", model="opus", description="QD11 Business Completeness lane",
      prompt=<RENDER với DIM_ID=QD11, NEEDS_PLAYWRIGHT="KHÔNG cần">) ← nếu multi-module + !quick
```

**Concurrency Contract (CORE-025):**

| Aspect | Value | Rationale |
|--------|-------|-----------|
| `Agent` tool harness max concurrent | **10** | Hardcoded harness limit |
| N > 10 lanes | Queue tự nhiên (FIFO) | Harness scheduler manage queue |
| Single-response dispatch | **BẮT BUỘC** | Multiple Agent calls trong 1 message = parallel; gửi riêng = sequential |
| After dispatch | WAIT cho toàn bộ agents hoàn thành | Group F Monitor Loop |
| Playwright lanes (PW=true) | TỰ acquire writer-lock `playwright` | Protocol 22 — chỉ 1 browser global tại 1 thời điểm |
| Non-PW lanes | Chạy probe ngay, KHÔNG đụng lock | Parallel với PW lanes |

### Playwright — Lock-Based Serialization (Protocol 22)

> Orchestrator KHÔNG quản lý slot. Thông tin "lane nào cần Playwright" nằm trong **metadata** của `dimension-plan.json` (field `needs_playwright` + `playwright_priority`, do Phase 3 emit).
>
> **Serialization** qua **writer-lock trên resource `playwright`** của `global-rw-lock.sh` (Protocol 22). Lane agent TỰ acquire/release lock trước/sau khi launch browser — orchestrator KHÔNG can thiệp.

**Quy tắc kích hoạt (do Phase 3 đã quyết định):**
- QD5/QD9 → `needs_playwright=true` (trừ `interface_type=api-only`)
- QD7 → `needs_playwright=true` chỉ khi `--responsive` hoặc `--mobile`
- Còn lại → `needs_playwright=false`
- `interface_type=api-only` → ép TẤT CẢ về false

**Lock semantics:** writer-lock cho `playwright` resource — chỉ 1 lane giữ lock tại 1 thời điểm. FIFO acquire-time + cleanup_stale_locks (heartbeat 30s, stale 2 phút). `playwright_priority` chỉ là **hint**.

**Cross-ref:** `templates/phase4-find-bugs/lane-agent-prompt.md` BƯỚC 4 Track B (acquire lock), `.claude/scripts/wf-e2e-shared/global-rw-lock.sh`, [`_shared/18-playwright.md`](../_shared/18-playwright.md) (browser modes/devices), SKILL.md của lane (wf-fix-runtime-health, wf-fix-ux-a11y, wf-fix-compat).

### Agent Isolation (CORE-025 — 1 file = 1 writer)

```
MAX_CONCURRENT = 10 (harness limit)
PLAYWRIGHT_CONCURRENCY = 1 (writer-lock trên resource "playwright" — Protocol 22)

subagent_type = "claude" cho TẤT CẢ lane agents
Prompt source = templates/phase4-find-bugs/lane-agent-prompt.md (CORE-031)
  Render: READ → SUBSTITUTE {{...}} → STRIP comment → VERIFY (Group D) → Agent tool (Group E)

DISPATCH MODEL (v10.3+):
  - Spawn TẤT CẢ lanes (PW + non-PW) trong MỘT response duy nhất
  - Non-PW lanes: chạy probe ngay, KHÔNG đụng lock
  - PW lanes: tự acquire writer-lock playwright trước launch browser
    → tại mỗi thời điểm chỉ 1 lane PW có lock → 1 browser global

  Field nguồn: dimension-plan.json .dimensions[*].needs_playwright (Phase 3 emit)

Agent isolation:
  - Mỗi agent write vào directory riêng (lanes/QD{n}-{name}/)
  - 1 file = 1 writer contract

Output naming contract:
  - static-scan/signals.json   (KHÔNG findings.json)
  - runtime/signals.json
  - llm-scan/signals.json
  - {{DIM_DIR}}-report.md      (KHÔNG Phase4-lane-report.md)
  - evidence/                  (screenshots/HAR/console)
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E046 | Agent không spawn được | Retry x1 → mark lane failed |
| E046 | Lane timeout (>15 phút) | Mark lane failed (Group F monitor handle), continue khác |
| E044 | Playwright launch fail | Retry x2 → escalate |
| E044 | Lock acquire timeout (>10 phút chờ) | Lane exit RC=2, mark failed |
| E045 | Mobile emulation không hỗ trợ | WARN, fallback desktop viewport |

**Cross-ref:** CORE-025 (Parallel Safety + 1-file-1-writer), CORE-037 (Agent Prompt Templates), `templates/phase4-find-bugs/lane-agent-prompt.md`, Protocol 22 (R/W lock writer `playwright`), [`_shared/18-playwright.md`](../_shared/18-playwright.md).

---

## Group E POST-GATE Verify

```bash
# All N agents dispatched (verified by lane-status.json transitions sang in_progress)
# Note: Lane completion verified ở Group F Monitor Loop — Group E chỉ verify dispatched
for dim in $DIMS_ARRAY; do
  jq -e '.status == "in_progress" or .status == "pending"' \
    "$SESSION_DIR/phase4-find-bugs/lanes/$dim/lane-status.json" 2>/dev/null \
    || echo "WARN: $dim chưa kích hoạt"
done
echo "Group E PASS (dispatched $DIMS_COUNT lanes — monitor at Group F)"
```

## Next Group

→ Group F Monitor + Validate — đọc [`phase4-find-bugs/F-monitor-validate.md`](F-monitor-validate.md)
