# 04 — Parallel Lane Dispatch

> **Mức độ ràng buộc:** BẮT BUỘC xem xét khi có ≥2 dimensions/tasks độc lập có thể chạy song song an toàn (CORE-039). KHUYẾN NGHỊ trong các trường hợp khác.
> **Rule liên quan:** CORE-025 (Điều kiện cứng song song hóa), CORE-039 (Parallelization Strategy bắt buộc trong SKILL.md)
> **Khi nào dùng:** Cần phân tích N dimensions độc lập, mỗi dimension có owner + output riêng
> **Khi nào KHÔNG dùng:** Lane sau cần kết quả lane trước (linear dependency), cùng ghi 1 file không có lock, output không deterministic dưới race condition

---

## 1. Vấn đề pattern giải quyết

Khi phân tích chất lượng code, có nhiều dimensions độc lập:
- Functional correctness
- Security
- Performance
- Accessibility
- Data integrity
- Cross-module integration
- ... (nhiều khía cạnh)

**Sequential approach:** Phân tích từng dimension một → tốn 10-30 phút.

**Parallel approach (pattern này):**
- Spawn N agents song song, mỗi agent = 1 lane (1 dimension)
- Mỗi lane có owner + output path riêng (no overlap)
- Aggregate signals sau khi tất cả lanes xong
- **Điều kiện cứng:** Lane outputs **không ghi đè nhau** (CORE-025)

---

## 2. Pattern definition

### 2.1. Concept

```
Skill orchestrator:
   │
   ├─ Phase prep:
   │   ├─ Define lanes (vd: QD1-QD11)
   │   ├─ Per-lane: input, output path, owner agent type
   │   └─ Build context bundle (cùng input shared)
   │
   ├─ Dispatch (max 10 concurrent):
   │   ├─ Agent QD1 (owner: developer)        → ghi $SESSION_DIR/.../lanes/QD1/signals.json
   │   ├─ Agent QD2 (owner: business-analyst) → ghi $SESSION_DIR/.../lanes/QD2/signals.json
   │   ├─ Agent QD3 (owner: security)         → ghi $SESSION_DIR/.../lanes/QD3/signals.json
   │   ├─ Agent QD4 (owner: performance...)   → ghi $SESSION_DIR/.../lanes/QD4/signals.json
   │   └─ ... song song
   │
   ├─ Wait for all lanes complete (or timeout)
   │
   └─ Aggregate:
       └─ Read all signals.json → merge → workload gate
```

### 2.2. 5 điều kiện CORE-025 phải thỏa

| Điều kiện | Mô tả |
|-----------|-------|
| 1. Owner rõ | Mỗi lane có agent type cụ thể |
| 2. Write scope tách biệt | Mỗi lane ghi vào path riêng (lanes/QD{N}/) |
| 3. Contract ổn định | Lane prompt + signals.json schema không đổi giữa run |
| 4. Re-verification | Aggregator validate mọi signals.json sau merge |
| 5. Bounded concurrency | Max 10 agents song song (Claude practical limit) |

### 2.3. Lane signals schema

```json
{
  "$schema": "lane-signals-v1",
  "lane": "QD3-security",
  "agent_type": "security",
  "status": "completed | timeout | error",
  "execution_time_s": 145,
  "signals": [
    {
      "severity": "critical | high | medium | low",
      "category": "input_validation",
      "title": "Missing sanitization in payment endpoint",
      "evidence": {
        "file": "src/payment/handler.ts",
        "line_range": "45-78",
        "code_snippet": "..."
      },
      "fix_recommendation": "Apply sanitize() before processing"
    }
  ],
  "probe_results": {
    "owasp_a01": "pass",
    "owasp_a03": "fail",
    "...": "..."
  }
}
```

---

## 3. Case study — wf-fix-bugs Phase 4 (11 lanes QD1-QD11)

```
Phase 4: Find Bugs

Step 1: Pre-dispatch
  - Read fix-status.json → SCOPE, PROFILE, NAME
  - Read upstream artifacts (preflight-impact, registry)
  - Determine active lanes (skip rules):
    QD9 SKIP if interface_type=api-only or --no-browser
    QD10 SKIP if no cross_module_deps or profile=quick
    QD11 SKIP if single module or api-only or profile=quick

Step 2: Build context bundle (shared cho all lanes)
  - feature_spec + dependencies
  - CI_CONTEXT (Protocol 20)
  - Playwright context (nếu QD9/QD5 active)

Step 3: Dispatch lanes
  Wave 1 (parallel, max 10):
    QD1 → wf-fix-functional         (developer + architect)
    QD2 → wf-fix-business           (business-analyst + domain expert)
    QD3 → wf-fix-security           (security)
    QD4 → wf-fix-performance        (performance-benchmarker)
    QD5 → wf-fix-ux-a11y            (accessibility-auditor + ux-designer)
    QD6 → wf-fix-data               (dba + data-engineer)
    QD7 → wf-fix-compat             (frontend-developer)
    QD8 → wf-fix-observability      (sre + devops)
    QD9 → wf-fix-runtime-health     (qa-lead + frontend-developer)
    QD10 → wf-fix-integration       (architect + data-engineer)
  Wave 2 (if QD11 active):
    QD11 → wf-fix-business-completeness  (BA + domain experts + architect)

Step 4: Aggregate (Phase 4 step 1.2)
  - Read all lanes/QD*/signals.json
  - Merge into issue-registry.json (v2 schema)
  - Workload gate: if signals > N threshold → ESCALATE
  - Update fix-status.json with aggregated stats
```

**Kết quả:** Phân tích 11 dimensions trong ~10-15 phút (vs 60-90 phút sequential).

### 3.1. Skip rules quan trọng

Skip rules ngăn waste:
- QD9 cho api-only — không có browser → vô nghĩa
- QD10 cho single module — không có cross-module → vô nghĩa
- QD11 cho profile=quick — pattern matching tốn time → không phù hợp quick

---

## 4. Variations / Edge cases

### 4.1. Lane failure isolation

```
QD3 lane timeout sau 8 phút (auto-fix retry 3 lần fail)
   ↓
Lane status = "timeout"
   ↓
Aggregator vẫn nhận 9/10 signals (QD1, QD2, QD4-QD10)
   ↓
Báo lên fix-status.json: "QD3 missing — recommend re-run"
   ↓
User decide via CDG: retry QD3 / proceed without / cancel
```

KHÔNG block toàn pipeline khi 1 lane fail.

### 4.2. Workload gate

```
Tổng signals từ 10 lanes = 247 issues
Workload threshold = 100 issues
   ↓
ESCALATE: AskUserQuestion
  "247 issues phát hiện. Profile quick có thể không đủ. Tăng profile lên deep?"
  Options:
    A) Proceed with quick (top-100 critical)
    B) Upgrade to deep (re-scan, take 3x longer)
    C) Narrow scope (specific module only)
```

### 4.3. Sequential dimensions

Một số dimension PHẢI sequential (depend on previous):

```
QD11 (Business Completeness — Pass 1, 2, 3)
  - Pass 1: cross-module pattern comparison (depend on QD2 output)
  - Pass 2: domain heuristic (depend on Pass 1)
  - Pass 3: registry gap detection (depend on Pass 1 + 2)

→ Within QD11, 3 passes sequential
→ Nhưng QD11 vẫn parallel với QD1-QD10 ở wave 1
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| 2 lanes cùng ghi `lanes/QD3/signals.json` | 1 path = 1 owner |
| Lane đọc output của lane khác trong cùng wave | Wave 1 independent — depend = sequential wave |
| Spawn 20 agents song song | Max 10 (CORE-025) |
| Lane prompt sửa giữa run | Contract stable per session |
| Aggregator KHÔNG validate signals schema | T1→T4 validate mỗi signals.json |
| Skip rule không document trong _contract.json | Phải document skip conditions |
| Lane timeout → block toàn pipeline | Lane failure ISOLATED, aggregator graceful |
| KHÔNG có workload gate → user bị flood 500 issues | Threshold + ESCALATE |
| Lane output ghi vào registry trực tiếp | Lane chỉ ghi signals; aggregator update registry |

---

## 6. Checklist áp dụng

**Khi thiết kế skill có parallel lanes:**

- [ ] Định nghĩa rõ N lanes, mỗi lane: name, owner agent, output path
- [ ] Output paths không overlap (mỗi lane subfolder riêng)
- [ ] Skip rules document trong `_contract.json` (per-lane conditions)
- [ ] Max concurrency ≤10 (CORE-025)
- [ ] Lane signals schema versioned (`lane-signals-v1`)
- [ ] Aggregator validate mọi signals (T1→T4)
- [ ] Workload gate threshold define (max N signals trước ESCALATE)
- [ ] Lane failure isolation: 1 lane fail KHÔNG block aggregator
- [ ] CI_CONTEXT injected vào mọi lane agent prompt (CORE-037 §4)
- [ ] Test eval: simulate 1 lane timeout → verify aggregator still works

---

## 7. Liên kết

- **Standard:** [`../02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md) — aggregation gate logic
- **Rule:** CORE-025 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §0
- **Protocol 7 (Parallel Execution):** [`.claude/skills/protocols/07-parallel-execution.md`](../../.claude/skills/protocols/07-parallel-execution.md)
- **Case study:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md`
- **Related patterns:**
  - [`05-agent-prompt-template.md`](05-agent-prompt-template.md) — Lane agent prompt structure
  - [`03-cross-skill-artifacts.md`](03-cross-skill-artifacts.md) — Signals → aggregated artifact
