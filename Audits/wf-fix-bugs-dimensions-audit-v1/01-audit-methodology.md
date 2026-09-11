# 01 — Audit Methodology: 5-Phase Framework

> **Áp dụng cho:** Mọi dimension trong audit (QD1-QD7).
> **Mục đích:** Đảm bảo audit có hệ thống, lặp lại được, output có thể so sánh giữa các dim.

## Phase 1 — Static Review (đọc spec)

**Input:**
- `dimension.json` của dim đang audit
- `SKILL.md` của lane skill tương ứng
- Tất cả probe files trong `procedures/probes/`
- `procedures/pre-gate.md` + `procedures/post-gate.md`

**Hành động:**
1. Đọc `dimension.json` — extract:
   - `dimension_id`, `dimension_name`, `owner_agent`
   - List probes với `id`, `type`, `depth`, `severity_default`, `cdg`, `cache_policy`, `estimated_cost`
   - `exit_criteria` per profile
   - `severity_rules.{critical,high,medium}_triggers`
2. Đọc `SKILL.md` — extract:
   - Workflow position
   - Probe routing table
   - Severity rules (lane-level)
   - Fix rules (suggested agents)
3. Đọc mỗi probe file — extract:
   - SENSE: cách thu thập data (grep patterns, curl, playwright commands)
   - THINK: logic phân tích, build sets, cross-ref
   - ACT: cách emit signals (schema fields)
   - VERIFY: validation rules (evidence non-empty, schema, dedup)
   - Fallback table

**Output:** Bảng tóm tắt 4 cột (probe_id × {SENSE, THINK, ACT, VERIFY}) cho dim.

## Phase 2 — Code Trace (đọc implementation)

**Input:**
- Bash scripts được probe gọi: `.claude/scripts/wf-fix-probe-static-*.sh`
- Python modules: `.claude/skills/workflow/_shared/`
- Lane dispatcher: `_shared/lane/dispatcher.py`
- Signal aggregator: `_shared/signal_aggregator.py`

**Hành động:**
1. Trace từng probe spec → script thực thi:
   - Probe declares `tool: { kind: "grep+jq" }` → tìm script tương ứng
   - Verify regex patterns trong script khớp với spec
   - Verify output format khớp với schema `lane-signals-v1`
2. Trace bash → Python:
   - Lane dispatcher gọi static probes thế nào (sequential / parallel)
   - Signal aggregator dedup ra sao (fingerprint generation)
3. Note discrepancy giữa **spec (probe.md) và code (script.sh)**:
   - Spec nói grep pattern X, code grep Y → bug
   - Spec nói emit field A, code không emit → bug

**Output:** Diff list `spec ↔ implementation` với severity (CRITICAL/HIGH/MEDIUM).

## Phase 3 — Test Fixture & Accuracy Measurement

**Input:**
- Sample project có known bugs (controlled environment)
- EUREKA-2026 module thực tế (real-world)

**Hành động:**

### 3.1 Build test fixture
Tạo project nhỏ `plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd<N>-test/` với:
- 5 known bugs cho dim đang test (positive cases)
- 5 non-bug cases (negative cases — không nên flag)
- README liệt kê expected signals

### 3.2 Chạy probe trên fixture
```bash
cd <fixture>
/wf-fix-bugs --dims=QD<N> --profile=exhaustive --full-test --url=http://localhost:<port>
# Hoặc invoke probe trực tiếp qua bash script
```

### 3.3 So sánh actual vs expected
- **True Positive (TP):** signal đúng = bug thực
- **False Positive (FP):** signal nhưng không phải bug
- **True Negative (TN):** không signal cho non-bug case
- **False Negative (FN):** không signal cho bug thực

### 3.4 Tính metrics
```
Precision = TP / (TP + FP)   — % signals đúng
Recall    = TP / (TP + FN)   — % bugs phát hiện được
F1        = 2*P*R / (P+R)
```

**Output:** Bảng confusion matrix per probe + danh sách FP/FN cụ thể.

## Phase 4 — Cross-Probe Interaction Analysis

**Input:**
- Output Phase 1 + 2 của 7 dim

**Hành động:**
1. **Cascade dependency:** vẽ DAG probe dependencies
   - Vd: `infra-preflight` → gating cho `api-smoke` + `deep-ui-traversal`
   - Vd: `deep-ui-traversal` → produce catalog → `orphan-ui-detect` consume
2. **Severity conflict:** 2 probes flag same code, severity khác nhau → quy tắc max_aggregation đúng?
3. **Dedup collision:** 2 probes emit signals cùng fingerprint → có drop nhầm không?
4. **Cache policy contradiction:** dim có probe `cache: allowed` next to probe `cache: never` → lock file conflict?

**Output:** Sơ đồ dependency + danh sách interaction issues.

## Phase 5 — Synthesize Findings

**Input:** Output Phase 1-4

**Hành động:** Cho mỗi dim, build 1 audit report với 8 sections (xem template bên dưới).

---

## Audit Report Template (per dimension)

```markdown
# QD<N> — <Dimension Name>: Audit Report

## 1. Tổng quan
| Trường | Giá trị |
|---|---|
| Dimension ID | QD<N> |
| Tên | ... |
| Owner agent | ... |
| Số probes | ... |
| Profile chạy | quick / standard / deep / exhaustive |

## 2. Liệt kê probes
| Probe ID | Type | Depth | Severity | Tool | Cost (s/tokens) |
|---|---|---|---|---|---|

## 3. Per-probe Analysis

### Probe 1: <id>
**SENSE:** ...
**THINK:** ...
**ACT:** ...
**VERIFY:** ...

**Spec ↔ Implementation discrepancy:** (từ Phase 2)
| # | Spec nói | Code làm | Severity |
|---|---|---|---|

### Probe 2: ... (lặp cho mọi probe)

## 4. False Positive Scenarios
| # | Scenario | Probe affected | Reproduce |
|---|---|---|---|
| FP-001 | ... | P-QD<N>-... | Test fixture step ... |

## 5. False Negative Scenarios
| # | Scenario | Probe affected | Test case |
|---|---|---|---|
| FN-001 | ... | P-QD<N>-... | ... |

## 6. Tech Stack & i18n Bias
### Tech stack support
| Stack | Probe support | Notes |
|---|:-:|---|
| Node.js (Express/NestJS/Next) | ✅ | |
| .NET (ASP.NET Core) | ❌ | Miss route detection |
| Java (Spring Boot) | ? | Cần verify |
| Python (Django/Flask/FastAPI) | ? | |

### i18n bias
| Probe | Hardcoded text | Impact |
|---|---|---|

## 7. Edge Cases bị miss
| # | Edge case | Probe | Severity |
|---|---|---|---|
| EC-001 | ... | ... | ... |

## 8. Recommendations
| ID | Title | Priority | Effort | Owner |
|---|---|:-:|:-:|---|
| IMP-QD<N>-001 | ... | P0 | M | skill-author |
```

---

## Quality Checklist (gate trước khi mark audit "completed")

- [ ] Phase 1 — đã đọc dimension.json + tất cả probe files
- [ ] Phase 2 — đã trace ≥ 50% probes vào script implementation
- [ ] Phase 3 — đã có test fixture với ≥ 5 positive + 5 negative cases
- [ ] Phase 3 — đã đo precision/recall cho ≥ 3 probes core
- [ ] Phase 4 — đã vẽ DAG cross-probe + identify ≥ 1 interaction issue
- [ ] Phase 5 — audit report đầy đủ 8 sections
- [ ] Đã có ≥ 5 findings (FP + FN + EC) per dim
- [ ] Đã có ≥ 3 recommendations với priority + effort + owner
- [ ] Update progress.md

## Tools hỗ trợ

| Task | Tool |
|---|---|
| Read probe spec | `Read`, `Glob` |
| Trace bash scripts | `Read .claude/scripts/wf-fix-probe-*.sh` |
| Trace Python modules | `Read .claude/skills/workflow/_shared/**/*.py` |
| Test fixture run | `Bash` + `/wf-fix-bugs --dims=QD<N>` |
| Compare actual vs expected | `jq` để đọc signals.json |
| Diff spec ↔ code | Manual review + grep |

## Anti-patterns (KHÔNG làm)

- ❌ Audit qua loa, chỉ đọc dimension.json không đọc probe files
- ❌ Tin "documentation reflects code" — luôn verify implementation
- ❌ Bỏ qua false positive vì "ít gặp" — log lại để tracking
- ❌ Recommend rewrite thay vì incremental improvement
- ❌ Quên link findings ↔ test fixtures (không reproducible)
- ❌ Mix severity với priority (severity = bug nặng đến đâu, priority = fix khi nào)

## Dependencies

- Skill `wf-fix-bugs` v7.4.0 (current)
- Lane skills phải tồn tại đầy đủ
- Bash + jq + Python 3 trên môi trường audit
- (Optional) Playwright cho runtime probe test
