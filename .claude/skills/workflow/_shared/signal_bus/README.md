# `signal_bus/` — Signal → Issue Normalization Bus

> **Trạng thái:** B1 Skeleton (2026-04-20) · chưa implement logic thật
> **Version:** 0.1.0-skeleton
> **ADR refs:** ADR-02 (utility module), ADR-04 (Issue schema v2 extend v1), ADR-09 (evidence bắt buộc)
> **Registry role:** NONE
> **Nơi được gọi:** Mọi QD lane (`wf-fix-functional`, `wf-fix-business`, …) sau khi probe emit Signal

---

## 1. Mục Đích

Signal Bus là **điểm tập trung** để:

1. **Nhận Signal thô** từ các probe của mọi lane.
2. **Validate** Signal — bắt buộc có ≥1 evidence non-empty (ADR-09).
3. **Dedup** Signal giống nhau (cùng `probe_id` + `file_path` + `line_range` ≈ cùng bug).
4. **Normalize** Signal → **Issue** (schema v2) — tagged với 1-N Quality Dimension.
5. **Emit** Issue vào `$SESSION_DIR/issue-registry.json` (append, không ghi đè).

Signal Bus **không phân loại severity** — đó là việc của `/wf-fix-triage`. Signal Bus chỉ làm normalization + dedup.

---

## 2. Data Model

### 2.1. Signal (input)

Signal là finding thô, schema đơn giản để các probe dễ emit:

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD1-service-logic-check",
  "probe_version": "0.1.0",
  "emitted_at": "2026-04-20T10:35:12+07:00",
  "lane": "wf-fix-functional",
  "dimension_id": "QD1",
  "target": {
    "kind": "code",
    "file_path": "src/features/order/service.ts",
    "line_range": [42, 58],
    "symbol": "createOrder"
  },
  "description": "Hàm createOrder không validate trường customer_id trước khi gọi repo",
  "evidence": {
    "code_snippet": "if (!order) throw ...",
    "screenshot_path": null,
    "log_excerpt": null,
    "stacktrace": null,
    "spec_ref": "phase2-features/sales/order/FEAT-SALES-CREATE.md"
  },
  "suggested_severity": "high",
  "dedup_hints": []
}
```

Đầy đủ schema: [`schemas/signal.v2.schema.json`](schemas/signal.v2.schema.json).

### 2.2. Issue (output)

Issue là Signal đã được normalized + deduped + tagged:

```json
{
  "$schema": "issue-v2",
  "issue_id": "ISS-20260420-001",
  "created_at": "2026-04-20T10:35:30+07:00",
  "dimensions": ["QD1", "QD6"],
  "target": {
    "kind": "code",
    "file_path": "src/features/order/service.ts",
    "line_range": [42, 58],
    "symbol": "createOrder"
  },
  "title": "createOrder thiếu validation customer_id",
  "description_md": "…",
  "probe_sources": [
    {"probe_id": "P-QD1-service-logic-check", "probe_version": "0.1.0"},
    {"probe_id": "P-QD6-input-validation", "probe_version": "0.1.0"}
  ],
  "evidence": [
    {
      "kind": "code_snippet",
      "content": "if (!order) throw ...",
      "source_signal_id": "SIG-001"
    },
    {
      "kind": "spec_ref",
      "content": "phase2-features/sales/order/FEAT-SALES-CREATE.md",
      "source_signal_id": "SIG-001"
    }
  ],
  "dedup_key": "sha256(QD1+src/features/order/service.ts+42-58+createOrder)",
  "severity": null,
  "fixability": null,
  "triage_status": "pending"
}
```

**Các field do Signal Bus điền:** `issue_id`, `dimensions` (union của `dimension_id` từ Signal dup), `probe_sources`, `evidence[]`, `dedup_key`.

**Các field để pending cho Triage:** `severity`, `fixability`, `triage_status`.

Đầy đủ schema: [`schemas/issue.v2.schema.json`](schemas/issue.v2.schema.json).

---

## 3. Dedup Key

Dedup key là sha256 của tuple các field "định danh bug":

```
dedup_key = sha256(
    dimension_id + "|" +
    target.file_path + "|" +
    target.line_range[0] + "-" + target.line_range[1] + "|" +
    (target.symbol or "")
)
```

**Hành vi khi dedup hit:**

- Merge `probe_sources[]` (union).
- Merge `evidence[]` (append, mark source signal).
- Merge `dimensions[]` (union) — 1 bug có thể thuộc nhiều QD.
- Giữ `title` + `description_md` từ Signal có `suggested_severity` cao nhất.

---

## 4. Evidence Validation (ADR-09)

Mọi Signal **phải** có ≥1 evidence field non-empty. Danh sách field evidence hợp lệ:

- `code_snippet` — string, ≥ 10 ký tự
- `screenshot_path` — file tồn tại trong `$SESSION_DIR/evidence/`
- `log_excerpt` — string ≥ 20 ký tự
- `stacktrace` — string ≥ 50 ký tự
- `spec_ref` — path tới doc trong `.mc-data/docs/phase2-features/**`
- `test_failure_ref` — path tới test report

Signal không có evidence → **reject** với exit code 1 + log lỗi `missing-evidence: <signal_id>`.

---

## 5. POST-GATE T1-T4 (ADR-22 rule 5)

Trước khi emit `issue-registry.json`, Signal Bus phải pass:

- **T1 Existence:** File `issue-registry.json` tồn tại và non-empty sau write.
- **T2 Structure:** JSON parse thành công + có top-level `$schema` + `issues[]`.
- **T3 Content:** Mỗi Issue có `issue_id` + `dimensions` ≥ 1 + `evidence` ≥ 1 + `dedup_key`.
- **T4 Cross-reference:** Mỗi `dimensions` ∈ {QD1..QD11}; mỗi `probe_sources[].probe_id` khớp với probe đã declare trong lane `_contract.json`.

Fail T1-T4 → ESCALATE orchestrator, không emit partial state.

---

## 6. API

Module expose 2 entry point:

### 6.1. CLI

```bash
python3 signal_bus.py ingest \
    --signal-file <path-to-signal.json> \
    --session-dir <path> \
    [--dry-run]
```

Nhận 1 Signal, validate + dedup + merge vào `issue-registry.json`.

```bash
python3 signal_bus.py flush \
    --session-dir <path>
```

Forc flush pending buffer (nếu có) + chạy POST-GATE T1-T4.

### 6.2. Python import

```python
from signal_bus import SignalBus

bus = SignalBus(session_dir=Path("..."))
bus.ingest(signal_dict)
bus.flush()  # ghi issue-registry.json + T1-T4
```

---

## 7. Files Trong Module Này

| File | Vai trò |
|------|---------|
| `README.md` | (file này) Tài liệu tổng thể |
| `signal_bus.py` | Core module — validate, dedup, merge, emit (bao gồm evidence validation theo ADR-09) |
| `schemas/signal.v2.schema.json` | JSON Schema cho Signal input |
| `schemas/issue.v2.schema.json` | JSON Schema cho Issue output |
| `_contract.json` | Module contract |

---

## 8. Safety

Signal Bus phải enforce 3 rule liên quan ADR-22:

1. **Rule 2 (Ripple always on):** Signal Bus không drop Issue chỉ vì không có neighbor hoặc impact-graph chưa build. Impact Graph là input cho `/wf-fix-execute` Phase 5, không phải điều kiện filter ở bus.
2. **Rule 4 (CDG secrets-in-code):** Nếu Signal chứa hint "secret" / "credential" / "api_key" trong `evidence.code_snippet`, Signal Bus **flag** thành Issue với `triage_status=cdg_required`. Orchestrator sẽ escalate cho Triage làm CDG prompt.
3. **Rule 5 (POST-GATE T1-T4):** như §5.

---

## 9. Testing Plan

- **B1 (phiên này):** skeleton — hàm raise NotImplementedError.
- **B3:** `wf-fix-functional` + `wf-fix-business` emit Signal thật, validate end-to-end.
- **B4:** Fixture:
  - `missing-evidence.signal.json` → expect reject.
  - `duplicate-signals.json` → expect 1 Issue sau dedup.
  - `multi-dim-same-target.json` → expect 1 Issue với dimensions = union.
  - `secrets-in-code.signal.json` → expect `triage_status=cdg_required`.

---

## 10. Tham Chiếu

- ADR-02 / ADR-04 / ADR-09: [`07-tradeoffs-adr.md`](../../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- ADR-22 rule 2/4/5: [`09-design-decisions.md §8`](../../../../../docs/design/skills/wf-fix-bugs/09-design-decisions.md)
- Signal/Issue data flow: [`04-contracts-data-model.md`](../../../../../docs/design/skills/wf-fix-bugs/04-contracts-data-model.md)
- Protocol 10 (POST-GATE): `.claude/skills/protocols/10-post-gate-schema.md`
