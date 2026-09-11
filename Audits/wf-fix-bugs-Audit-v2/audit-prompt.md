# Audit Execution Prompt — wf-fix-bugs

> **Dùng với:** Agent tool (subagent_type="general-purpose") hoặc trực tiếp trong Claude Code
> **Checklist tham chiếu:** [audit-checklist.md](audit-checklist.md) — 97 checkpoints / 20 nhóm / 3 tầng
> **Output:** Báo cáo audit tại `.mc-data/work/wf-fix-bugs/audit-reports/audit-{date}-{version}.md`

---

## Mục Tiêu

Bạn là **auditor** chịu trách nhiệm rà soát toàn bộ skill `wf-fix-bugs` theo bộ tiêu chuẩn tại `audit-checklist.md`. Nhiệm vụ của bạn:

1. **Đọc và hiểu** toàn bộ audit checklist
2. **Thực hiện kiểm tra** từng checkpoint theo thứ tự ưu tiên (P1 → P2 → P3)
3. **Ghi nhận findings** cho mọi checkpoint FAIL hoặc WARN
4. **Tạo báo cáo audit** với kết quả chi tiết

---

## Nguyên Tắc Thực Hiện

```
QUY TẮC AUDIT:
1. P1 CORRECTNESS LÀ BẤT KHẢ XÂM PHẠM — bất kỳ FAIL P1 nào = BLOCK release
2. Kiểm tra dựa trên CODE HIỆN TẠI — không dựa trên memory hoặc giả định
3. Mỗi FAIL phải có BẰNG CHỨNG cụ thể (file path + line number + đoạn code)
4. Không suy diễn — nếu checkpoint cần runtime test, ghi rõ "CẦN RUNTIME TEST"
5. Ưu tiên P1 trước — hoàn thành P1 mới chuyển sang P2/P3
```

---

## Phases Audit

### Phase A: Structural Scan (Static Analysis)

**Mục tiêu:** Kiểm tra cấu trúc files, schema, references mà không cần chạy runtime.

#### A.1 — File Inventory

```bash
# Kiểm tra tất cả files tồn tại và không rỗng
ls -la .claude/skills/workflow/wf-fix-bugs/SKILL.md
ls -la .claude/skills/workflow/wf-fix-bugs/_contract.json
ls -la .claude/skills/workflow/wf-fix-bugs/procedures/*.md
ls -la .claude/skills/workflow/wf-fix-bugs/prompts/*.md
ls -la .claude/skills/workflow/wf-fix-bugs/templates/*.json
ls -la .claude/scripts/wf-fix-*.sh
ls -la .claude/skills/workflow/_shared/lane_dispatch.py
ls -la .claude/skills/workflow/_shared/signal_aggregator.py
ls -la .claude/skills/workflow/_shared/profile_resolver.py
ls -la .claude/skills/workflow/_shared/partition/partition_planner.py
ls -la .claude/skills/workflow/_shared/isg/isg_recommender.py
```

**Checklist mapping:** C1.1.5 (dependency chain files), C1.2.12 (sub-skill SKILL.md validation)

#### A.2 — Schema Validation

```bash
# Validate _contract.json schema
jq -e '.skill == "wf-fix-bugs"' .claude/skills/workflow/wf-fix-bugs/_contract.json
jq -e '.version != null' .claude/skills/workflow/wf-fix-bugs/_contract.json

# Validate outputs.working[] references
jq -e '.outputs.working | length > 0' .claude/skills/workflow/wf-fix-bugs/_contract.json

# Validate fix-impact.json template
jq -e '.schema == "fix-impact-v1"' .claude/skills/workflow/wf-fix-bugs/templates/fix-impact.json
jq -e '.fix_summary.deferred != null' .claude/skills/workflow/wf-fix-bugs/templates/fix-impact.json
jq -e '.audit_chain.checksum_sha256 != null' .claude/skills/workflow/wf-fix-bugs/templates/fix-impact.json
```

**Checklist mapping:** C1.2.12, C3.4.3

#### A.3 — Hardcoded Pattern Detection

```bash
# C1.4.7 — Không hardcode QD[1-8] (regression v9.0.0)
grep -rn 'QD\[1-8\]' .claude/skills/workflow/wf-fix-bugs/SKILL.md \
  .claude/skills/workflow/wf-fix-bugs/procedures/ \
  .claude/skills/workflow/_shared/lane_dispatch.py \
  .claude/skills/workflow/_shared/signal_aggregator.py \
  .claude/skills/workflow/_shared/profiles.json 2>/dev/null

# Nếu có kết quả → FAIL C1.4.7
```

```bash
# C3.1.1 — Không có changelog/version history trong procedure
grep -rnE '(Changelog|Version history|## [0-9]+\.[0-9]+\.[0-9]+)' \
  .claude/skills/workflow/wf-fix-bugs/procedures/*.md 2>/dev/null

# C3.1.2 — Không có historical context
grep -rnE '(đã fix|đã thay đổi từ|trước đây|trong version|cũ hơn)' \
  .claude/skills/workflow/wf-fix-bugs/procedures/*.md 2>/dev/null

# C3.1.3 — Không có TODO/FIXME chưa resolve
grep -rnE '\b(TODO|FIXME|HACK|XXX)\b' \
  .claude/skills/workflow/wf-fix-bugs/procedures/*.md \
  .claude/skills/workflow/wf-fix-bugs/prompts/*.md 2>/dev/null

# C1.2.11 — T5 Anti-Invention forbidden terms trong SKILL.md & procedures
grep -rnE '(FIX NOW|FIX IF BUDGET|DEFER MANUAL|DEFER BACKLOG|TODO LATER|FOLLOW-UP|POSTPONE)' \
  .claude/skills/workflow/wf-fix-bugs/SKILL.md \
  .claude/skills/workflow/wf-fix-bugs/procedures/*.md 2>/dev/null
```

**Checklist mapping:** C1.4.7, C3.1.1, C3.1.2, C3.1.3, C1.2.11

#### A.4 — State Machine Trace

Đọc `procedures/resume-routing.md` và `procedures/post-gate-completion.md`. Vẽ state machine diagram:

```
states: in_progress, paused, completed
transitions:
  in_progress → paused     (trigger: CDG prompt chưa có token / Workload Gate menu)
  paused → in_progress     (trigger: user resume + cung cấp token)
  in_progress → completed  (trigger: POST-GATE pass, CQG counts REMAINING=0)
```

Kiểm tra từng `next_action` value trong procedure có khớp với routing table không:

```
next_action hợp lệ: workload_gate, cdg_pending, phase_2_triage,
                    safety_check_pending, phase_3_execute,
                    phase3_regression_fix, done
next_action null → E_RESUME_CORRUPT
```

**Checklist mapping:** C1.3.1, C1.3.2

#### A.5 — Atomic Write Pattern Check

Grep tất cả vị trí write `fix-status.json`:

```bash
grep -rn 'fix-status.json' .claude/skills/workflow/wf-fix-bugs/procedures/*.md \
  .claude/skills/workflow/wf-fix-bugs/SKILL.md \
  .claude/scripts/wf-fix-*.sh 2>/dev/null
```

Mỗi vị trí write PHẢI dùng pattern:
```bash
jq '...' "$SESSION_DIR/fix-status.json" > "$SESSION_DIR/.fix-status.tmp.$$" \
  && mv "$SESSION_DIR/.fix-status.tmp.$$" "$SESSION_DIR/fix-status.json"
```

**Checklist mapping:** C1.3.3, C1.6.7

#### A.6 — Lock Acquisition Pattern Check

Grep tất cả vị trí `acquire_lock`:

```bash
grep -rn 'acquire_lock\|\.lock/' .claude/skills/workflow/wf-fix-bugs/procedures/*.md \
  .claude/skills/workflow/wf-fix-bugs/SKILL.md \
  .claude/scripts/wf-fix-common.sh 2>/dev/null
```

- Lock PHẢI được acquire TRƯỚC khi bắt đầu phase (không phải sau)
- PHẢI có `start_heartbeat_daemon` sau khi acquire
- PHẢI có `trap cleanup_session EXIT INT TERM`

**Checklist mapping:** C1.7.1, C1.7.2, C1.7.4

#### A.7 — Cross-Language Lock Check

Kiểm tra `lane_dispatch.py` và bash scripts dùng chung lock convention:

```bash
# Python side
grep -n '\.lock' .claude/skills/workflow/_shared/lane_dispatch.py 2>/dev/null

# Bash side
grep -rn '\.lock/' .claude/scripts/wf-fix-probe-static-*.sh 2>/dev/null
```

Cả 2 PHẢI dùng `.lock/` directory (POSIX mkdir atomic), không dùng `flock` hoặc cơ chế khác.

**Checklist mapping:** C1.7.3

#### A.8 — Probe Coverage Check

Đọc `_contract.json` → `procedures` → đếm số lượng probes cho mỗi dimension:

```bash
jq '.procedures.phase_1.lane_dispatch.dimensions | to_entries[] | "\(.key): \(.value.probes | length) probes"' \
  .claude/skills/workflow/wf-fix-bugs/_contract.json 2>/dev/null
```

Mỗi dimension phải có ≥ 5 probes. QD9/QD10 phải có ≥ 7 probes.

**Checklist mapping:** C1.4.1, C1.4.2

#### A.9 — Resume Routing Completeness

Đọc `procedures/resume-routing.md`. Kiểm tra routing table có đủ case:

- [ ] `STATUS == "in_progress"` với từng NEXT_ACTION
- [ ] `STATUS == "paused"` với từng NEXT_ACTION
- [ ] `STATUS == "completed"` → cross-skill suggest
- [ ] `STATUS == null` / khác → E_RESUME_CORRUPT
- [ ] `cdg_reject_counts >= 2` → force ESCALATE (anti-loop)

**Checklist mapping:** C1.6.1, C1.6.2, C1.6.5

#### A.10 — Graceful Degradation Paths

Grep các fallback patterns trong procedures:

```bash
grep -rn 'fallback\|skip_reason\|graceful\|unavailable\|KHONG block' \
  .claude/skills/workflow/wf-fix-bugs/procedures/*.md 2>/dev/null
```

Mỗi external dependency (Playwright, GitNexus, Serena, registry, source dir) PHẢI có fallback path.

**Checklist mapping:** C1.8.1 → C1.8.5

#### A.11 — Parallel Execution Safety Check

Đọc `procedures/phase1-engine.md` và `_shared/lane_dispatch.py`. Kiểm tra:

- [ ] `max_parallel=3` được hardcode/config
- [ ] Mỗi lane ghi vào `lanes/{DIM}/` riêng (write scope tách biệt)
- [ ] Token bucket + backpressure được import từ `concurrency/`
- [ ] Static probes chạy trước, non-static sau (Pass 1 → Pass 2)

**Checklist mapping:** C2.1.1, C2.1.2, C2.1.3, C2.2.1

#### A.12 — Bash Delegation Audit

Với mỗi static probe, kiểm tra:

1. Có bash script tương ứng trong `.claude/scripts/` không?
2. Probe procedure có gọi bash script không (≤ 6 dòng call)?
3. Có inline fallback nếu bash script fail không?

```bash
# Liệt kê tất cả static probes
grep -rn 'probe-static' .claude/skills/workflow/wf-fix-bugs/procedures/phase1-engine.md 2>/dev/null

# Đối chiếu với scripts
ls .claude/scripts/wf-fix-probe-static-*.sh
```

**Checklist mapping:** C3.3.1, C3.3.2

#### A.13 — Deep Scan Coverage & Component Exhaustiveness Audit

**Mục tiêu:** Kiểm tra skill có khả năng quét toàn bộ và phát hiện lỗi trong MỌI thành phần, kể cả các thành phần lồng nhau.

##### A.13.1 — UI Component Discovery Check

```bash
# Kiểm tra probes có pattern phát hiện tất cả loại UI component không
grep -rnE 'button|Button|popup|sheet|modal|dialog|drawer|menu|dropdown|combobox|tabs|accordion|toast|tooltip|carousel|pagination|form|input|select|textarea' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd1-functional.md \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd5-ux-a11y.md \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd9-runtime-health.md 2>/dev/null
```

- [ ] Mỗi loại UI component có ít nhất 1 probe pattern
- [ ] Các component phổ biến (button, form, popup/sheet, dialog/modal, table/list, pagination) có probe coverage ≥ 2 patterns
- [ ] Các component ẩn (tooltip, carousel, accordion, drawer) có ít nhất 1 probe

##### A.13.2 — Nested Component Drill-Down Check

```bash
# Kiểm tra probes có yêu cầu drill-down vào nested components không
grep -rnE 'nested|drill.down|bên trong|inside|recursive|đệ quy|child component|sub.component|content of' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md \
  .claude/skills/workflow/wf-fix-bugs/procedures/phase1-engine.md 2>/dev/null
```

- [ ] Prompt QD1/QD5/QD9 có hướng dẫn drill-down vào popup/sheet/modal
- [ ] Có logic phát hiện nested dialog (dialog trong dialog)
- [ ] Có hướng dẫn scan form bên trong popup, table bên trong sheet

##### A.13.3 — Feature Boundary Completeness Check

```bash
# Kiểm tra probes có yêu cầu quét đầy đủ sub-flows của feature không
grep -rnE 'sub.flow|flow.complete|feature.boundary|toàn bộ|đầy đủ|all states|every state' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md 2>/dev/null
```

- [ ] Mỗi feature probe yêu cầu xác định đầy đủ các sub-flows
- [ ] Có check list: Add → Edit → Delete → View cho mỗi CRUD feature
- [ ] Có check empty/loading/error states cho mỗi list

##### A.13.4 — Dynamic Content Discovery Check

```bash
# Kiểm tra probes có phát hiện conditional/lazy-loaded content không
grep -rnE 'conditional|v-if|ngIf|\{.*&&|hidden|display.none|lazy.load|dynamic.import|code.split|suspense|Suspense' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md 2>/dev/null
```

- [ ] Prompt có hướng dẫn phát hiện conditional renders
- [ ] Prompt có hướng dẫn phát hiện lazy-loaded modules
- [ ] Prompt có hướng dẫn phát hiện permission-gated content

##### A.13.5 — Interactive State Coverage Check

```bash
# Kiểm tra probes có yêu cầu test đủ trạng thái
grep -rnE 'enabled|disabled|loading|error state|empty state|success state|hover|focus|active|pending' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md 2>/dev/null
```

- [ ] Prompt QD1/QD5 yêu cầu test ít nhất: enabled, disabled, loading, error
- [ ] Prompt QD9 yêu cầu test form validation states
- [ ] Prompt có yêu cầu test empty state cho lists/tables

##### A.13.6 — Cross-Component State Flow Check

```bash
# Kiểm tra probes có phát hiện cross-component interactions
grep -rnE 'cross.component|inter.component|state flow|refresh after|update after|trigger|cascade|propagate' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd10-integration.md 2>/dev/null
```

- [ ] Prompt QD10 có hướng dẫn phát hiện cross-component state flow
- [ ] Có check: popup submit → parent refresh
- [ ] Có check: filter change → table reload

##### A.13.7 — Module Boundary Coverage Check

```bash
# Kiểm tra probes có cơ chế đảm bảo quét hết scope
grep -rnE 'scope|boundary|file tree|route list|toàn bộ file|mọi file|all files|every route|coverage' \
  .claude/skills/workflow/wf-fix-bugs/procedures/phase1-engine.md \
  .claude/skills/workflow/wf-fix-bugs/prompts/_shared.md 2>/dev/null
```

- [ ] Phase 1 engine có bước liệt kê toàn bộ files trong scope
- [ ] Có cơ chế so sánh files scanned vs files in scope
- [ ] Có cơ chế phát hiện file bị bỏ sót

##### A.13.8 — Pagination & Infinite Scroll Probe Check

```bash
grep -rnE 'pagination|infinite.scroll|page.[0-9]|next.page|load.more|scroll' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md 2>/dev/null
```

- [ ] Prompt có yêu cầu test page 2+ (không chỉ page 1)
- [ ] Prompt có yêu cầu test infinite scroll (scroll đến khi hết)
- [ ] Prompt có yêu cầu test page size change

##### A.13.9 — Hidden/Implicit UI Pattern Check

```bash
grep -rnE 'onClick|onSubmit|onChange|onBlur|onFocus|onKeyDown|onKeyPress|setTimeout|setInterval|requestAnimationFrame|WebSocket|EventSource|addEventListener' \
  .claude/skills/workflow/wf-fix-bugs/prompts/llm-probe-qd*.md 2>/dev/null
```

- [ ] Prompt có hướng dẫn phát hiện event handlers
- [ ] Prompt có hướng dẫn phát hiện timer-based behaviors
- [ ] Prompt có hướng dẫn phát hiện real-time update listeners

##### A.13.10 — Post-Scan Coverage Audit Check

```bash
# Kiểm tra có script post-scan audit không
grep -rn 'coverage\|scan.depth\|post.scan\|audit' \
  .claude/scripts/wf-fix-*.sh 2>/dev/null | grep -i 'coverage\|depth\|audit'
```

- [ ] Có cơ chế tính % components được scan
- [ ] Có cảnh báo nếu coverage < 85%
- [ ] Coverage report được ghi vào file riêng

**Checklist mapping:** C1.9.1 → C1.9.10

---

#### A.14 — QD11 Business Completeness & Enhancement Audit

**Mục tiêu:** Kiểm tra QD11 lane skill được định nghĩa đầy đủ và đúng cấu trúc.

##### A.14.1 — QD11 Lane Skill Definition Check

```bash
# Kiểm tra SKILL.md tồn tại và không rỗng
ls -la .claude/skills/workflow/wf-fix-business-completeness/SKILL.md 2>/dev/null || echo "MISSING: QD11 lane skill"
# Kiểm tra _contract.json
ls -la .claude/skills/workflow/wf-fix-business-completeness/_contract.json 2>/dev/null || echo "MISSING: QD11 contract"
# Kiểm tra dimension.json
ls -la .claude/skills/workflow/wf-fix-business-completeness/dimension.json 2>/dev/null || echo "MISSING: QD11 dimension.json"
```

- [ ] QD11 SKILL.md tồn tại, không rỗng, có đủ PRE-GATE → EXECUTION → POST-GATE
- [ ] `_contract.json` có `"$schema": "skill-contract-v1"`, fields `skill`, `version`, `registry_scope`
- [ ] `dimension.json` có `dimension_id: "QD11"`, `dimension_name`, `probes[]`, `skip_conditions`

##### A.14.2 — QD11 3-Pass Probe Structure Check

```bash
# Kiểm tra 3 probe prompt files
ls -la .claude/skills/workflow/wf-fix-business-completeness/prompts/llm-probe-qd11-cross-module.md 2>/dev/null || echo "MISSING: pass-1 cross-module prompt"
ls -la .claude/skills/workflow/wf-fix-business-completeness/prompts/llm-probe-qd11-domain-heuristic.md 2>/dev/null || echo "MISSING: pass-2 domain heuristic prompt"
ls -la .claude/skills/workflow/wf-fix-business-completeness/prompts/llm-probe-qd11-registry-gap.md 2>/dev/null || echo "MISSING: pass-3 registry gap prompt"
```

- [ ] Pass 1 (Cross-Module Pattern Comparison): prompt yêu cầu so sánh entity forms, lists, workflows giữa các module cùng domain
- [ ] Pass 2 (Domain Heuristic Analysis): prompt tham chiếu `.claude/references/team-expert/` domain rules
- [ ] Pass 3 (Business Rule Gap Detection): prompt yêu cầu cross-reference với `req-registry.json`

##### A.14.3 — QD11 Infrastructure Wiring Check

```bash
# Kiểm tra lane_dispatch.py có reference tới QD11
grep -n 'QD11\|qd11\|business.completeness' .claude/skills/workflow/_shared/lane_dispatch.py 2>/dev/null || echo "MISSING: QD11 in lane_dispatch.py"
# Kiểm tra signal_aggregator.py
grep -rn 'QD11\|qd11' .claude/skills/workflow/_shared/signal_aggregator.py 2>/dev/null || echo "MISSING: QD11 in signal_aggregator.py"
# Kiểm tra profile_resolver.py
grep -rn 'QD11\|qd11\|business.completeness' .claude/skills/workflow/_shared/profile_resolver.py 2>/dev/null || echo "MISSING: QD11 in profile_resolver.py"
# Kiểm tra profiles.json
grep -n 'QD11\|qd11\|business.completeness' .claude/skills/workflow/wf-fix-bugs/templates/profiles.json 2>/dev/null || echo "MISSING: QD11 in profiles.json"
```

- [ ] `lane_dispatch.py` includes QD11 in dimension lane list with `max_parallel` routing
- [ ] `signal_aggregator.py` handles QD11 signal types (MISSING_FIELD, TYPE_MISMATCH, etc.)
- [ ] `profile_resolver.py` maps QD11 to profiles (skip quick, include standard/deep/exhaustive)
- [ ] `profiles.json` has QD11 entry with correct probe count and weight

##### A.14.4 — QD11 Orchestrator Integration Check

```bash
# Kiểm tra SKILL.md orchestrator reference tới QD11
grep -n 'QD11\|qd11\|business.completeness\|QD1[0-1]' .claude/skills/workflow/wf-fix-bugs/SKILL.md 2>/dev/null | head -20
# Kiểm tra phase1-engine.md reference
grep -n 'QD11\|qd11\|business.completeness' .claude/skills/workflow/wf-fix-bugs/procedures/phase1-engine.md 2>/dev/null || echo "MISSING: QD11 in phase1-engine.md"
# Kiểm tra _contract.json orchestrator reference
grep -n 'QD11\|qd11\|business.completeness\|QD1[0-1]' .claude/skills/workflow/wf-fix-bugs/_contract.json 2>/dev/null || echo "MISSING: QD11 in _contract.json"
```

- [ ] SKILL.md orchestrator lists QD11 in dimension lane table
- [ ] `phase1-engine.md` includes QD11 in ISG → partition → dimension routing
- [ ] `_contract.json` orchestrator lists QD11 in `dimensions[]`
- [ ] `post-gate-completion.md` references QD11 output paths

##### A.14.5 — QD11 Bash Scripts Check

```bash
# Kiểm tra static probe scripts
ls -la .claude/scripts/wf-fix-qd11-*.sh 2>/dev/null || echo "MISSING: QD11 bash scripts"
# Đếm số lượng scripts
ls .claude/scripts/wf-fix-qd11-*.sh 2>/dev/null | wc -l
```

- [ ] Có ít nhất 3 bash scripts (mỗi pass 1 script tối thiểu)
- [ ] Scripts có shebang, error handling (`set -euo pipefail`), output JSON schema

##### A.14.6 — QD11 CDG Gate Check

```bash
# Kiểm tra CDG definition có reference QD11
grep -rn 'QD11\|qd11\|business.completeness' .claude/skills/workflow/_shared/cdg/ 2>/dev/null || echo "MISSING: QD11 in CDG definitions"
# Kiểm tra CDG gate trong procedure
grep -rn 'QD11\|BUSINESS_COMPLETENESS' .claude/skills/workflow/wf-fix-bugs/procedures/ 2>/dev/null || echo "MISSING: QD11 in procedures"
```

- [ ] CDG gate định nghĩa cho QD11: user phải ACCEPT/REJECT từng HIGH/MEDIUM suggestion
- [ ] Enhancement suggestions có severity classification (CRITICAL/HIGH/MEDIUM/LOW/INFO)

##### A.14.7 — QD11 Skip Conditions Check

```bash
# Kiểm tra skip conditions trong lane_dispatch.py
grep -A20 'QD11\|qd11' .claude/skills/workflow/_shared/lane_dispatch.py 2>/dev/null | grep -i 'skip\|condition\|api.only\|single.module\|quick'
```

- [ ] QD11 bị skip nếu project chỉ có 1 module
- [ ] QD11 bị skip nếu `interface_type=api-only`
- [ ] QD11 bị skip nếu `profile=quick`
- [ ] Skip reason được ghi vào signal với `skip_reason` hợp lệ

**Checklist mapping:** C1.10.1 → C1.10.10

---

### Phase B: Regression Test Suite

**Mục tiêu:** Chạy toàn bộ regression test suite. Mọi test phải pass.

#### B.1 — Chạy Regression Tests

```bash
cd .claude/skills/workflow/wf-fix-bugs/evals
bash regression-tests/run-all.sh
```

**Pass khi:** Toàn bộ tests exit 0.

#### B.2 — Chạy E2E Large Codebase Test

```bash
cd .claude/skills/workflow/wf-fix-bugs/evals
bash e2e-large-codebase.test.sh
```

**Pass khi:** Test exit 0, fixtures được tạo và dọn dẹp đúng cách.

#### B.3 — Chạy Python Unit Tests

```bash
cd .claude/skills/workflow/_shared
./run-tests.sh  # full + coverage gate ≥ 80%
```

**Pass khi:** Coverage ≥ 80%, mọi test pass.

**Checklist mapping:** C1.1.x, C1.4.x, C1.5.x (toàn bộ correctness được verify qua tests)

---

### Phase C: Runtime Scenario Tests

**Mục tiêu:** Chạy skill trên test fixtures để verify các scenario cụ thể.

> **LƯU Ý:** Phase này yêu cầu runtime thực tế. Nếu không thể chạy, ghi rõ "CẦN RUNTIME TEST" trong báo cáo.

#### C.1 — Scenario: N=0 Issues (E005 path)

```bash
# Tạo project sạch không có lỗi
# Chạy: /wf-fix-bugs "test-empty" --scope=all --profile=quick
```

**Kiểm tra:**
- [ ] Không crash
- [ ] `fix-impact.json` tồn tại với `fix_summary.fixed: 0`
- [ ] `orchestrator-summary.md` tồn tại
- [ ] `fix-status.json` có `status: "completed"`, `next_action: "done"`

**Checklist mapping:** C1.1.6

#### C.2 — Scenario: Workload Gate Block

```bash
# Tạo project lớn (>5000 symbols, 8+ dimensions)
# Chạy: /wf-fix-bugs "test-large" --scope=all --profile=deep
```

**Kiểm tra:**
- [ ] Workload Gate hiển thị Plan A/B menu khi ratio > 1.5
- [ ] Menu có 5 options
- [ ] User chọn option → workflow tiếp tục đúng hướng

**Checklist mapping:** C1.2.7, C2.5.2

#### C.3 — Scenario: CQG-2 Browser Gate BLOCKED

```bash
# Tạo project có QD9 console errors
# Chạy: /wf-fix-bugs "test-browser" --scope=module --name=webapp --dims=QD9
```

**Kiểm tra:**
- [ ] CQG-2 gate BLOCKED (không auto-pass)
- [ ] Hiển thị danh sách blocking signals
- [ ] Accept ghi `cdg-tokens.json`; Reject tạo `cqg2-regression-entries.json`
- [ ] Reject 3 lần → E001 ESCALATE

**Checklist mapping:** C1.2.9, C1.2.10

#### C.4 — Scenario: Resume After Interruption

```bash
# Chạy workflow → kill giữa Phase 2 → resume
# /wf-fix-bugs --resume
```

**Kiểm tra:**
- [ ] Pick đúng session
- [ ] Tiếp tục từ `next_action` chính xác
- [ ] Không chạy lại Phase 1
- [ ] `cdg_reject_counts` giữ nguyên

**Checklist mapping:** C1.6.1 → C1.6.7

#### C.5 — Scenario: Concurrent Lock Protection

```bash
# Terminal 1: /wf-fix-bugs "test-lock" --scope=all
# Terminal 2 (trong khi T1 đang chạy): /wf-fix-bugs --resume --session=<same-id>
```

**Kiểm tra:**
- [ ] Terminal 2 bị từ chối với message "lock held"
- [ ] Terminal 1 tiếp tục bình thường

**Checklist mapping:** C1.7.1, C1.7.5

#### C.6 — Scenario: Graceful Degradation (không Playwright)

```bash
# Trên môi trường không có npx playwright
# Chạy: /wf-fix-bugs "test-no-browser" --dims=QD9
```

**Kiểm tra:**
- [ ] QD9 skip với `skip_reason: "playwright_unavailable"`
- [ ] `lane-status.json` ghi rõ lý do
- [ ] Workflow không crash

**Checklist mapping:** C1.8.1

#### C.7 — Scenario: Nested Component Drill-Down Test

```bash
# Tạo project với cấu trúc: popup chứa form, form chứa table (pagination),
# table row có nút mở nested dialog
# Chạy: /wf-fix-bugs "test-nested" --scope=module --name=user-management --dims=QD1,QD5,QD9
```

**Kiểm tra:**
- [ ] Tất cả popup/sheet/modal trong module được phát hiện
- [ ] Form bên trong mỗi popup được scan (validation, submit, error)
- [ ] Table/list bên trong mỗi sheet được scan (pagination, sort, filter)
- [ ] Nested dialog (dialog trong dialog) được phát hiện và scan
- [ ] Không có component lồng nào bị bỏ qua

**Checklist mapping:** C1.9.1, C1.9.2, C1.9.3

#### C.8 — Scenario: Feature Coverage Completeness Test

```bash
# Tạo project với 1 module CRUD đầy đủ:
# - List (pagination, search, filter, sort)
# - Add (popup với form multi-field, validation)
# - Edit (popup pre-filled form)
# - Delete (confirm dialog → loading → refresh)
# - Empty state, loading state, error state
# - Conditional content (role-based buttons, permission-gated tabs)
# Chạy: /wf-fix-bugs "test-coverage" --scope=module --name=crud-module --profile=standard
```

**Kiểm tra:**
- [ ] Tất cả 4 CRUD operations được phát hiện
- [ ] Tất cả UI states được test (empty, loading, error, success)
- [ ] Form validation được test cho từng field
- [ ] Pagination được test qua các page
- [ ] Conditional content (role-based) được phát hiện
- [ ] Cross-component flow: add → list refresh; delete → item removed
- [ ] Không có feature/sub-flow nào bị bỏ sót

**Checklist mapping:** C1.9.3, C1.9.4, C1.9.5, C1.9.6, C1.9.8

#### C.9 — Scenario: Module Boundary Coverage Test

```bash
# Tạo project 5 modules, chạy với scope từng module
# So sánh kết quả scan với file tree thực tế
for module in module-a module-b module-c module-d module-e; do
  /wf-fix-bugs "test-boundary-$module" --scope=module --name=$module --profile=quick
done
```

**Kiểm tra:**
- [ ] 100% files trong scope được scan
- [ ] 100% routes/endpoints trong scope được probe
- [ ] File bị skip có `skip_reason` hợp lệ (test/config/doc)
- [ ] Không có file bị bỏ qua không lý do

**Checklist mapping:** C1.9.7

#### C.10 — Scenario: QD11 Business Completeness Cross-Module Test

```bash
# Tạo project 3 modules cùng domain (Sales), 1 module incomplete
# Module A (CRM Customers): đầy đủ - có search, filter, export, validation
# Module B (CRM Contacts): thiếu - thiếu export, search, 1 field so với A
# Module C (CRM Deals): thiếu - thiếu approval flow step so với pattern
# Chạy: /wf-fix-bugs "test-qd11-completeness" --scope=all --profile=standard --dims=QD11
```

**Kiểm tra:**
- [ ] QD11 phát hiện Module B thiếu `export` button (cross-module pattern)
- [ ] QD11 phát hiện Module B thiếu `search` field (cross-module pattern)
- [ ] QD11 phát hiện Module B thiếu 1 form field so với Module A reference
- [ ] QD11 phát hiện Module C thiếu approval step (workflow completeness)
- [ ] Mỗi finding có severity chính xác (MISSING_FEATURE=HIGH, MISSING_FIELD=MEDIUM)
- [ ] Mỗi finding có evidence (reference module + specific diff)
- [ ] Enhancement suggestions có confidence score
- [ ] CDG gate yêu cầu user ACCEPT/REJECT trước khi implement
- [ ] Không có false positive: Module A không bị flag (đã đầy đủ)

**Checklist mapping:** C1.10.1, C1.10.2, C1.10.3, C1.10.4, C1.10.5, C1.10.8, C1.10.9

#### C.11 — Scenario: QD11 Domain Heuristic & Registry Gap Test

```bash
# Tạo project với domain=healthcare, thiếu mandatory fields theo domain rules
# Chạy: /wf-fix-bugs "test-qd11-domain" --scope=all --profile=deep --dims=QD11
```

**Kiểm tra:**
- [ ] QD11 Pass 2 phát hiện thiếu field theo domain rules (vd: healthcare thiếu patient_id)
- [ ] QD11 Pass 3 phát hiện requirement trong registry không có code implementation
- [ ] QD11 Pass 3 phát hiện REQ-ID trong registry không map tới bất kỳ feature nào
- [ ] Domain heuristic suggestions có tham chiếu cụ thể tới `.claude/references/team-expert/`
- [ ] Registry gap findings có confidence=HIGH (registry là SSOT)

**Checklist mapping:** C1.10.6, C1.10.7

#### C.12 — Scenario: QD11 Skip Conditions Test

```bash
# Test 1: Single module → QD11 should skip
# Test 2: api-only project → QD11 should skip
# Test 3: profile=quick → QD11 should skip
```

**Kiểm tra:**
- [ ] Single module: QD11 skip với reason "single_module"
- [ ] API-only: QD11 skip với reason "api_only"
- [ ] Profile quick: QD11 skip với reason "profile_quick"
- [ ] Skip không gây crash — orchestrator tiếp tục với các dimension khác

**Checklist mapping:** C1.10.10

---

### Phase D: Reference Integrity Check

#### D.1 — Cross-Reference Check

Mọi reference trong SKILL.md và procedures đến:
- Procedure khác (vd: "xem `procedures/lock-management.md`")
- Script (vd: "gọi `bash .claude/scripts/wf-fix-common.sh`")
- Protocol (vd: "Protocol 16")
- Rule (vd: "CORE-020")

```bash
# Trích xuất tất cả references từ procedures
grep -rnE 'procedures/[a-z-]+\.md' .claude/skills/workflow/wf-fix-bugs/procedures/*.md \
  .claude/skills/workflow/wf-fix-bugs/SKILL.md 2>/dev/null

# Trích xuất tất cả script references
grep -rnE 'scripts/wf-fix-[a-z-]+\.sh' .claude/skills/workflow/wf-fix-bugs/procedures/*.md \
  .claude/skills/workflow/wf-fix-bugs/SKILL.md 2>/dev/null

# Verify từng reference tồn tại
for ref in $(grep -rohE 'scripts/wf-fix-[a-z-]+\.sh' .claude/skills/workflow/wf-fix-bugs/ | sort -u); do
  test -f ".claude/$ref" || echo "MISSING: .claude/$ref"
done
```

**Checklist mapping:** C1.2.12 (sub-skill path validation mở rộng)

#### D.2 — Consumer Contract Check

Verify consumer skills có parse được `fix-impact.json`:

```bash
# Kiểm tra wf-verify-sync có reference tới fix-impact.json schema
grep -rn 'fix-impact' .claude/skills/workflow/wf-verify-sync/ 2>/dev/null

# Kiểm tra wf-prepare-deployment có reference tới fix-impact.json schema
grep -rn 'fix-impact' .claude/skills/workflow/wf-prepare-deployment/ 2>/dev/null
```

**Checklist mapping:** C3.5.1

---

## Output: Báo Cáo Audit

Sau khi hoàn thành cả 4 phases, tạo báo cáo:

```markdown
# Audit Report — wf-fix-bugs v[X.Y.Z]

**Ngày:** [YYYY-MM-DD]
**Auditor:** [tên agent]
**Phạm vi:** Static Analysis (Phase A) + Regression Tests (Phase B) + Runtime Scenarios (Phase C) + Reference Check (Phase D)

---

## 1. Tổng Quan

| Tier | PASS | FAIL | WARN | N/A | CẦN RUNTIME | Tổng |
|------|------|------|------|-----|-------------|------|
| P1 — Correctness | XX | XX | XX | XX | XX | 74 |
| P2 — Performance | XX | XX | XX | XX | XX | 12 |
| P3 — Efficiency | XX | XX | XX | XX | XX | 11 |
| **Tổng** | XX | XX | XX | XX | XX | **97** |

**Kết quả:** PASS | WARN | FAIL | BLOCK

## 2. Failures (Blocking)

| Code | Checkpoint | Mô tả | Evidence |
|------|-----------|-------|----------|
| F001 | C1.X.X | ... | [file:line] |

## 3. Warnings

| Code | Checkpoint | Mô tả | Evidence |
|------|-----------|-------|----------|
| W001 | C1.X.X | ... | [file:line] |

## 4. Cần Runtime Test

| Code | Checkpoint | Lý do không test được |
|------|-----------|----------------------|
| R001 | C1.X.X | Yêu cầu project có UI + Playwright |

## 5. Khuyến Nghị

1. ...
2. ...
```

---

## Hướng Dẫn Sử Dụng Prompt Này

### Cách 1: Audit toàn diện (dùng Agent)

```
Spawn Agent (subagent_type="general-purpose") với prompt này.
Agent sẽ tự động thực hiện Phase A, B, D (static) và báo cáo.
Phase C (runtime) sẽ được đánh dấu "CẦN RUNTIME TEST" nếu không thực hiện được.
```

### Cách 2: Audit nhanh (chỉ static)

```
Đọc prompt này → thực hiện Phase A + Phase D → báo cáo.
Dùng cho pre-commit check hoặc quick review.
```

### Cách 3: Audit đầy đủ (có runtime)

```
Đọc prompt này → thực hiện Phase A → Phase B → Phase C → Phase D → báo cáo.
Dùng trước khi release hoặc sau khi sửa lớn.
```

---

## Liên Kết

- Checklist đầy đủ: [audit-checklist.md](audit-checklist.md)
- SKILL.md: [SKILL.md](SKILL.md)
- Contract: [_contract.json](_contract.json)
- Evals: [evals/](evals/)
- CORE rules: [../../../../.claude/rules/00-core.md](../../../../.claude/rules/00-core.md)
