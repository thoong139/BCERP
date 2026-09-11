# LLM Probe Agent Protocol v1

> **Phase C cua wf-fix-bugs Coverage Improvement v8.**
> Chuc nang: cho phep LLM agents phat hien bugs ma static probes khong bat duoc.

---

## Muc dich

Giai quyet ~30-35% blind spot con lai cua static analysis:
- Race conditions / concurrency bugs
- Cross-component integration bugs
- Business-rule edge cases (state machine inconsistencies)
- Subtle UX flow inconsistencies
- Domain-specific compliance gaps

**Tradeoff:**
- Cost cao (~$0.50-2.00+ / run, không có hard cap mac dinh)
- Non-deterministic
- Yeu cau opt-in qua `--llm-scan`

**Quality-first mode (mac dinh):** Budget caps = 0 (UNLIMITED) — uu tien
correctness/completeness hon cost. Module track cost cumulative cho visibility
nhung KHONG block execution. Caller có thể opt-in to caps bằng cách pass
non-zero values khi construct `LLMBudget`.

---

## Schema: `llm-probe-invocation-v1`

Invocation contract de LLM agent biet phai do gi:

```json
{
  "$schema": "llm-probe-invocation-v1",
  "probe_id": "P-QD2-llm-business-rules",
  "dimension": "QD2",
  "lane": "wf-fix-business",
  "scope": {
    "files": [
      {"path": "src/marketing/leads.ts", "lines": "1-450", "purpose": "lead routing logic"}
    ],
    "focus": "business rule consistency - phat hien khi promotion/discount overlap, customer status transitions invalid",
    "context_files_optional": [
      ".mc-data/docs/phase2-features/marketing/lead-management.md"
    ]
  },
  "budget": {
    "max_tokens_in": 50000,
    "max_tokens_out": 8000,
    "timeout_seconds": 180,
    "max_signals": 20
  },
  "output_schema": "lane-signals-v1",
  "self_check_rules": [
    "Neu khong chac chan → severity=info hoac SKIP, KHONG doan.",
    "Moi finding PHAI co code_snippet trong evidence.",
    "Moi finding PHAI co reproduction_steps cu the.",
    "Khong duplicate signals da co tu static probes."
  ]
}
```

## Schema: `llm-probe-output-v1`

Same as `lane-signals-v1` nhung them metadata block:

```json
{
  "$schema": "lane-signals-v1",
  "lane": "wf-fix-business",
  "dimension": "QD2",
  "probe_id": "P-QD2-llm-business-rules",
  "probe_version": "v1.0-llm",
  "profile": "deep",
  "generated_at": "2026-05-09T10:30:00Z",
  "signals": [...],
  "llm_metadata": {
    "model_used": "claude-sonnet-4-6",
    "tokens_in": 42150,
    "tokens_out": 6890,
    "duration_seconds": 124,
    "confidence": "medium",
    "signals_dropped_low_confidence": 3
  }
}
```

---

## Execution Flow

```
1. Orchestrator (lane_dispatch) detect: probe_id ∈ LLM_PROBE_AGENTS + --llm-scan flag set
2. Budget guard check (pre-flight):
   - Estimated cost = chunks * avg_tokens * model_cost
   - If > cap → halt + ask user confirmation
   - If user confirms → proceed
3. Chunk planner: split source files into chunks ≤ max_tokens_in
4. For each chunk:
   a. Build prompt: load .claude/skills/workflow/{lane_skill}/prompts/llm-probe-{dim}.md
      + scope (chunk files + content)
      + self_check_rules
      + few-shot examples
   b. Invoke agent qua Task tool subagent_type=general-purpose, model=sonnet
   c. Parse output JSON → validate schema
   d. Update budget tracker (tokens_in + tokens_out)
   e. If budget exceeded → halt, return partial results
5. Merge signals across chunks → dedup by fingerprint
6. Write signals to $SESSION_DIR/lanes/{DIM}/llm-signals.json
7. Lane aggregator merges static-signals.json + llm-signals.json
```

---

## Cost Model

| Component | Estimated cost (Sonnet 4.6) |
|-----------|------------------------------|
| Input tokens (~50K avg) | $0.15 / probe |
| Output tokens (~8K avg) | $0.12 / probe |
| 7 dimensions × 1 probe each | ~$1.89 |
| Cap (configurable, mac dinh OFF) | 0 (unlimited) |

**Budget guard (quality-first defaults — caller có thể override):**
```python
class LLMBudget:
    max_total_tokens_in: int = 0       # 0 = unlimited
    max_total_tokens_out: int = 0      # 0 = unlimited
    estimated_cost_usd_cap: float = 0.0  # 0.0 = unlimited
    require_user_confirmation: bool = False
    max_chunks_per_probe: int = 0      # 0 = unlimited
    max_signals_per_probe: int = 0     # 0 = unlimited
```

**Vi sao khong cap mac dinh:** Cap $1.50 cu chat hon cost expected $1.89
cho 7 dims → mathematically guarantee KHONG du chay het dimensions.
Vi pham CORE-023 (chat luong/completeness > cost). Quality-first mode
uu tien cover toan bo blind spots; caller opt-in cap khi can guard rail.

---

## Failure Modes

| Failure | Handling |
|---------|----------|
| Agent timeout (>180s) | Skip chunk, log warning, continue with next chunk |
| Malformed JSON output | Try to repair (regex extract `{...}`), if fail → skip + log |
| Hallucinated file paths | Validator checks `Path(file).exists()` — drop signal if false |
| Hallucinated line numbers | Drop signal if line > file_line_count |
| Low confidence (< 0.5) | Auto-downgrade severity to "info" |
| Duplicate of static signal | Drop (compare fingerprint) |
| Budget exceeded mid-run (caller set cap) | Halt, return partial, mark probe as `partial`. Default mode: never triggers |

---

## Probe Catalog (7 dimensions)

| Probe ID | Dimension | Focus |
|----------|-----------|-------|
| `P-QD1-llm-functional-audit` | QD1 | Function correctness — null checks, off-by-one, edge cases |
| `P-QD2-llm-business-rules` | QD2 | **Quan trong nhat**: business rule consistency, state machine, calculations |
| `P-QD3-llm-security-review` | QD3 | OWASP Top 10 sau static SAST — auth bypass, IDOR, deserialization |
| `P-QD4-llm-performance-audit` | QD4 | N+1 queries, memory leaks, blocking I/O |
| `P-QD5-llm-ux-review` | QD5 | UX flow inconsistencies, error states, loading states |
| `P-QD6-llm-data-integrity` | QD6 | Schema drift, migration safety, transaction boundaries |
| `P-QD7-llm-compatibility` | QD7 | i18n completeness, browser/runtime compat |

Profile gating:
- Quick: KHONG run LLM probes
- Standard: KHONG run (mac dinh)
- Deep: Run khi `--llm-scan` opt-in
- Exhaustive: Run khi `--llm-scan` opt-in

---

## Backward Compatibility

- KHONG `--llm-scan` → Phase B & static probes only (zero regression).
- Missing `Task` tool → graceful fallback: log warning, KHONG fail lane.
- Budget exceeded → return partial results, mark `partial=true` trong output.
