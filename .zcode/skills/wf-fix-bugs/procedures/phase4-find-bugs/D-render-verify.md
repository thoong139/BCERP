# Phase 4 Group D — Render Lane Prompts + Pre-Dispatch Verify (Steps 4.5 render + 4.6)

> **Entry condition:** Group C POST-GATE PASS (N × 5 subdirs + lane-status.json created).
> **Exit condition:** N rendered prompts pass 6 check points + ready for parallel dispatch.
> **Next:** [phase4-find-bugs/E-dispatch.md](E-dispatch.md) (**CRITICAL: PARALLEL N×Agent({...}) trong 1 response**).
>
> **Shared protocols cần thiết:**
> - [`_shared/15-agent-prompts.md`](../_shared/15-agent-prompts.md) — Lane Agent Prompt template (8 sections CORE-037)
> - [`_shared/16-sub-probe-template.md`](../_shared/16-sub-probe-template.md) — Sub-probe template cross-skill cho lane skills
> - [`_shared/18-playwright.md`](../_shared/18-playwright.md) — Playwright mode placeholders

> **⚠ Lưu ý:** Group D = **ORCHESTRATOR-SIDE rendering**. KHÔNG gọi `Agent` tool — chỉ render + verify prompts. Dispatch xảy ra ở Group E (must be PARALLEL trong 1 response).

## Input contract (env vars từ Group C)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID`, `$DIMS_ARRAY`, `$DIMS_COUNT`, `$PW_LANE_COUNT` | Pipeline state |
| `$PROFILE`, `$SCOPE`, `$NAME`, `$INTERFACE_TYPE`, `$LLM_SCAN` | CLI/Phase 2 |
| `$URL` (= BASE_URL nếu PW lanes) | Group B |
| `$CI_CONTEXT`, `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$INDEX_FRESHNESS` | Phase 1 PRE-GATE Nc |
| `phase3-plan/dimension-plan.json` | `needs_playwright`, `sub_skill`, `playwright_priority` per dim |
| `templates/phase4-find-bugs/lane-agent-prompt.md` | Canonical template (CORE-031 + CORE-037) |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| N rendered prompts (in-memory hoặc tmp files) | 4.5 | Per-dim prompt với `{{...}}` substituted, comment block stripped |
| Each prompt passed 6 check points | 4.6 | Verified bởi `verify-lane-prompt.sh` — exit 0 |

---

## Step 4.5 (Render Flow) — Substitute Template + Strip Comment

**Mục đích:** Render N prompts từ canonical template `templates/phase4-find-bugs/lane-agent-prompt.md` — KHÔNG viết ad-hoc, KHÔNG paraphrase, KHÔNG dịch.

**Hợp đồng spawn (BẮT BUỘC — phase E thực thi):**

- `subagent_type="claude"` — chỉ "claude" có đủ MCP tools (GitNexus, Serena, Playwright, Context7). KHÔNG dùng `developer`, `qa-lead`, `frontend-developer`, hoặc bất kỳ domain agent type nào.
- Prompt render từ template canonical `templates/phase4-find-bugs/lane-agent-prompt.md` (CORE-031 + CORE-037).
- Mỗi agent ghi vào directory riêng `lanes/QD{n}-{name}/` — 1 file = 1 writer (CORE-025).
- Orchestrator KHÔNG can thiệp internal pipeline của agent — chỉ spawn (Group E) và monitor (Group F).

### Render Flow per dim

```text
1. READ      templates/phase4-find-bugs/lane-agent-prompt.md
2. SUBSTITUTE {{...}} placeholders theo Bảng Substitution bên dưới
   ({{NEEDS_PLAYWRIGHT}} đọc từ dimension-plan.json, KHÔNG hardcode)
3. STRIP     HTML comment block (<!-- ... -->) ở đầu file
4. VERIFY    rendered prompt theo Step 4.6 (verify-lane-prompt.sh)
5. (Group E) CALL Agent(subagent_type="claude", prompt=<rendered_text>)
   → MỌI Agent calls (PW + non-PW) phải nằm trong CÙNG 1 response
```

### Bảng Substitution — Lane Agent Prompt placeholders

| Placeholder | Nguồn giá trị | Ví dụ |
|-------------|---------------|-------|
| `{{DIM_ID}}` | `dimension-plan.json .dimensions[].id` | `QD1` |
| `{{DIM_NAME}}` | `dimension-plan.json .dimensions[].name` | `Functional Correctness` |
| `{{DIM_DIR}}` | `<DIM_ID>-<slug>` (xem template DIM_DIR MAPPING) | `QD1-functional` |
| `{{SUB_SKILL_NAME}}` | `dimension-plan.json .dimensions[].sub_skill` | `wf-fix-functional` |
| `{{SESSION_ID}}` / `{{SESSION_DIR}}` | state vars | `2026-05-16-module-hrm-01` |
| `{{PROJECT_NAME}}` | `fix-status.json .project_name` hoặc `$(basename $(pwd))` | `EUREKA-2026` |
| `{{PROFILE}}` / `{{SCOPE}}` / `{{NAME}}` | state vars | `exhaustive` / `module` / `hrm` |
| `{{INTERFACE_TYPE}}` | `phase2-scan/scope-analysis.json .interface_type` | `web` |
| `{{LLM_SCAN}}` | `$LLM_SCAN` (true nếu `--llm-scan`) | `true` |
| `{{SOURCE_DIR}}` | `.source_dir` hoặc `$(pwd)` | `z:\Working\EUREKA-2026` |
| `{{GITNEXUS_AVAILABLE}}` / `{{SERENA_AVAILABLE}}` | `.mc-data/work/_meta/code-intelligence.json` | `true` / `false` |
| `{{INDEX_FRESHNESS}}` | từ `ci-freshness-check.sh` (ok/light/strong/severe) | `ok` |
| `{{CI_CONTEXT}}` | từ `ci-inject-context.sh` (multi-line text) | (block tools + tips) |
| `{{NEEDS_PLAYWRIGHT}}` | `dimension-plan.json` `true`→`"CÓ"`, `false`→`"KHÔNG cần"` | `KHÔNG cần` |
| `{{PLAYWRIGHT_REASON}}` | Giải thích lý do (từ priority/PW flag) | `QD1 là static + LLM probes` |
| `{{PLAYWRIGHT_MODE}}` | `headless` / `visible` / `mobile` | `headless` |
| `{{PLAYWRIGHT_DEVICES}}` | `desktop` hoặc `iPhone 14, Pixel 7, iPad Pro` | `desktop` |
| `{{BASE_URL}}` | `--url` flag hoặc `fix-status.json .base_url` | `http://localhost:3000` |

> Markers `<PROBE_ID>`, `<script>`, `<type>`, `<dim>`, `<ISO>` trong template là **runtime placeholders** mà lane agent tự thay khi thực thi probe — orchestrator KHÔNG cần substitute trước dispatch.

### ⛔ FORBIDDEN PATTERNS — Verify rendered prompt KHÔNG có

| Pattern SAI | Pattern ĐÚNG |
|-------------|--------------|
| `subagent_type="developer"` (hoặc role khác) | `subagent_type="claude"` |
| `"You are a developer agent"` (English) | `"Bạn là lane agent cho dimension {{DIM_ID}}"` |
| Prompt dịch sang English | Tiếng Việt (CORE-005) |
| `static-scan/findings.json` | `static-scan/signals.json` |
| `evidence/signals.json` (gộp 3 track) | 3 file tách: `static-scan/`, `runtime/`, `llm-scan/` |
| `Phase4-lane-report.md` | `{{DIM_DIR}}-report.md` |
| `fingerprint = sha256(title + file)` | `fingerprint = sha256(dim_id\|file\|line\|probe_id\|type)` |
| Prompt chỉ liệt kê 1 file | Đủ 5 file shared protocol (BƯỚC 1.a-e) |
| PRE-GATE rút gọn | Đủ 5 check (BƯỚC 2.a-e) |
| Bỏ qua `raw/<PROBE_ID>.json` | Mỗi probe ghi 1 file với `probe_complete:true` |
| Còn `{{...}}` chưa substitute | Mọi `{{...}}` đã thay |

Match BẤT KỲ pattern sai nào → STOP, re-render từ template (đừng "sửa tay" prompt đã render).

---

## Step 4.6 — Pre-Dispatch Verify (verify-lane-prompt.sh, 6 check points)

**Mục đích:** Bắt lỗi render prompt TRƯỚC khi tốn quota spawn agent — chống "fantasy prompt" (v10.2 critical guard). Verify 6 check points BẮT BUỘC; bất kỳ FAIL nào → STOP, re-render, KHÔNG gọi `Agent`.

**Cách dùng:**

Cho MỖI rendered prompt (trước khi gọi `Agent` tool ở Group E):

```bash
echo "$RENDERED_PROMPT" > /tmp/lane-prompt-$DIM_ID.txt
if ! bash .claude/scripts/wf-fix-bugs/verify-lane-prompt.sh /tmp/lane-prompt-$DIM_ID.txt; then
  echo "E046: Prompt verify fail cho $DIM_ID — re-render từ template, KHÔNG sửa tay"
  exit 46
fi
rm -f /tmp/lane-prompt-$DIM_ID.txt
```

**6 check points (script enforce):**

| Check | Mô tả | Exit code |
|-------|-------|-----------|
| C1 | Role declaration `^Bạn là lane agent cho dimension QD<n>` | 1 |
| C2 | KHÔNG còn `{{...}}` placeholder unsubstituted | 2 |
| C3 | Đủ 8 `BƯỚC N` sections | 3 |
| C4 | 5 file shared protocol references (`/SKILL.md`, `_shared/lane/_shared.md`, `pre-gate.md`, `signal-emit.md`, `profile-resolver.md`) | 4 |
| C5 | `signals.json` reference + KHÔNG `findings.json` hoặc `Phase4-lane-report.md` | 5 |
| C6 | Tiếng Việt — KHÔNG English role text (`you are a .*agent`, `developer agent`) | 6 |

**Quy tắc:**

- KHÔNG "sửa tay" prompt đã render — luôn re-render từ template
- Verify TỪNG prompt riêng biệt trước khi gửi `Agent` tool call
- Verify TRƯỚC dispatch — KHÔNG gộp với dispatch
- Auto-fix budget max 3 retries/lane (CORE-034). Hết → ESCALATE.

**v10.6 note:** Trước v10.6 logic 6 check points inline trong Step 4.6 (~70 dòng heredoc). v10.6 delegate sang `verify-lane-prompt.sh` — PRESERVE 6 check semantics, chỉ delegate execution.

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E046 | Verify exit 1-6 | Re-render từ template, KHÔNG sửa tay (max 3 retry/lane) |
| E001 | Script missing | Verify `.claude/scripts/wf-fix-bugs/verify-lane-prompt.sh` |

**Cross-ref:** CORE-011 (Forensic PRE-GATE), CORE-031 (Template Usage Rule), CORE-037 (Agent Prompt Templates).

---

## Group D POST-GATE Verify

```bash
# Tất cả N rendered prompts đã pass verify-lane-prompt.sh
# (orchestrator tự track per-dim verify status)
[ "$VERIFIED_PROMPTS" = "$DIMS_COUNT" ] \
  && echo "Group D PASS ($VERIFIED_PROMPTS/$DIMS_COUNT prompts verified)" \
  || echo "Group D FAIL ($VERIFIED_PROMPTS/$DIMS_COUNT verified — check error-ledger)"
```

## Next Group

→ Group E PARALLEL Dispatch — đọc [`phase4-find-bugs/E-dispatch.md`](E-dispatch.md)

**⚠ CRITICAL:** Group E phải spawn TẤT CẢ N agents trong **MỘT response duy nhất** (multiple `Agent` tool calls). Gửi riêng lẻ → agents chạy tuần tự, KHÔNG song song (vi phạm CORE-025).
