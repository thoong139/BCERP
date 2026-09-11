# QD2 Test Fixture — Business Correctness

> **Status:** ⬜ Skeleton (Stage 0 — chưa build cases)
> **Lane skill:** `wf-fix-business` v2.0.0-alpha.s4
> **Số probes:** 5
> **Owner agent:** `business-analyst` + domain experts (finance/HR/sales/...)
> **Audit report:** [03-qd2-business-audit.md](../../03-qd2-business-audit.md)

## Mục đích

Đo precision/recall của 5 probes Business Correctness — formula errors, hardcoded business rules, approval flow, audit trail, currency/rate consistency. Tập trung vào agent hallucination risk khi cross-check domain rules.

## Expected signals per probe

| Probe ID | Signal type(s) | Severity | Positive cases | Negative cases | Notes |
|---|---|:-:|:-:|:-:|---|
| `P-QD2-probe-01` | TBD | TBD | TBD | TBD | Sẽ fill ở Stage 1 Phase 3 (probe IDs từ audit Phase 1) |
| `P-QD2-probe-02` | TBD | TBD | TBD | TBD | Sẽ fill ở Stage 1 Phase 3 |
| `P-QD2-probe-03` | TBD | TBD | TBD | TBD | Sẽ fill ở Stage 1 Phase 3 |
| `P-QD2-probe-04` | TBD | TBD | TBD | TBD | Sẽ fill ở Stage 1 Phase 3 |
| `P-QD2-probe-05` | TBD | TBD | TBD | TBD | Sẽ fill ở Stage 1 Phase 3 |

> **Note:** Probe IDs placeholder — sẽ thay bằng IDs thực ở Stage 1 Phase 1 (Static Review). Bảng sẽ được fill khi build cases (Stage 1 Phase 3 — xem [13-DoD §Phase 3](../../13-definition-of-done.md)).

## Cases

### Positive (≥5, code có known bugs)

TBD — Stage 1 Phase 3. Theo pre-seed [fixtures/README.md §QD2 Business](../README.md): tính % quên `/100`, hardcoded VAT 10%, skip approval, audit trail thiếu actor, currency rate cũ.

### Negative (≥5, code legit, không nên flag)

TBD — Stage 1 Phase 3. Pre-seed: HTTP status magic 200, UI indexing constant, legit calculation, correct approval flow.

### Advanced (optional)

Optional — không bắt buộc cho dim này. Tuỳ Stage 1 Phase 3 quyết định.

## Run

```bash
cd plans/wf-fix-bugs-dimensions-audit-v1/fixtures/qd2-test
./run.sh
```

> **Stub:** `run.sh` hiện chỉ in stub message + exit 0. Implementation ở Stage 1 Phase 3 — spec [fixtures/README.md §Run](../README.md#run).

## Liên quan

- Audit report: [03-qd2-business-audit.md](../../03-qd2-business-audit.md)
- Lane skill: `.claude/skills/workflow/wf-fix-business/`
- Fixture catalog: [fixtures/README.md](../README.md)
- DoD per fixture: [13-definition-of-done.md §Phase 3](../../13-definition-of-done.md)
