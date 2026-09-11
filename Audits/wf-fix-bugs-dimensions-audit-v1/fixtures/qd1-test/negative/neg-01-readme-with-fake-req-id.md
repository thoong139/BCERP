# neg-01: REQ-ID trong file Markdown (FP-001 reproduction target)

> **FP target:** FP-001 — Annotation REQ-ID nằm trong README/test fixture/config file
> **Probe:** P-QD1-req-registry-xref
> **Expected probe behavior:** KHÔNG emit signal — probe grep theo extension whitelist
> (`*.ts *.tsx *.js *.jsx *.py *.java *.cs *.go *.rs`), file `.md` KHÔNG match.
> **Audit reference:** 02-qd1-functional-audit.md §4 FP-001

## Cách dùng

File này cố tình chứa REQ-ID giả `REQ-FAKE-DOC-001` (KHÔNG có trong registry)
để kiểm tra: liệu probe có nhầm tưởng đây là "orphan annotation" trong source code?

```typescript
// REQ-ID: REQ-FAKE-DOC-001
// FEAT-ID: FEAT-FAKE-DOC-002
class FakeServiceInDocBlock {}
```

Trên đây là 1 đoạn code block trong markdown — `find` với extension filter sẽ KHÔNG
include file này vào tập grep. Nếu probe vẫn flag → FP-001 reproduce ✅ (cần fix).
Nếu probe ignore → KHÔNG có signal cho REQ-FAKE-DOC-001 → FP-001 not reproduced
(probe correctly skip .md files).
