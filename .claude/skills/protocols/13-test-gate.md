<!-- From shared-protocols.md lines 1006-1072 (§13 — scope: wf-implement-feature) -->
# Protocol 13 — Test Gate Protocol (BẮT BUỘC — wf-implement-feature)

> Enforce test pass trước khi sang batch tiếp theo.
> Thay thế "human checkpoint review" bằng machine-executable verification.
> Non-technical users chỉ cần biết PASS/FAIL — không cần đọc code.

## 13.1 Gate Trigger

Chạy sau MỖI BATCH hoàn thành (Phase 3.4), TRƯỚC KHI checkpoint và sang batch tiếp theo.

## 13.2 Test Gate Logic

```
BATCH COMPLETION GATE:

1. Run all tests for completed batch:
   bash: [test-runner] --testPathPattern="[batch-files-pattern]"
   // Ví dụ: npm test -- --testPathPattern="orders|order-items"
   // Ví dụ: pytest tests/[module]/ -v

2. Check results:
   IF any test FAIL:
     → STOP — KHÔNG checkpoint, KHÔNG sang batch tiếp theo
     → LOG: "[GATE-FAIL] Batch N — [file] → [test name] → [error]"
     → AUTO-FIX (max 2 attempts):
         attempt 1: Analyze failure, fix obvious issues, re-run
         attempt 2: Deeper fix nếu attempt 1 fail, re-run
     → IF still fail after 2 attempts:
         → ROLLBACK batch (xem 13.3)
         → ESCALATE to user với chi tiết lỗi đầy đủ

   IF all tests PASS:
     → Type check (nếu TypeScript): npx tsc --noEmit
       IF type errors: xử lý như test fail (max 2 attempts)
     → LOG: "[GATE-PASS] Batch N — [P] passed, [S] skipped."
     → Proceed to checkpoint và batch tiếp theo
```

## 13.3 Batch Rollback Mechanism

```
SNAPSHOT (trước khi bắt đầu mỗi batch):
  1. Ghi danh sách files sẽ tạo/sửa vào checkpoint.batch_snapshot.files
  2. Ghi content hash của files hiện tại nếu MODIFY/EXTEND

ROLLBACK (khi gate fail sau 2 attempts):
  1. Xóa files mới được tạo trong batch này
  2. Restore files đã sửa về nội dung cũ (từ hash snapshot)
  3. LOG: "[ROLLBACK] Batch N rolled back. Files restored to pre-batch state."
  4. UPDATE checkpoint.json: batch_snapshot.status = "gate_failed"
  5. ASK USER:
     "Test gate fail sau 2 lần thử. Batch N đã rollback.
     Tùy chọn:
     [A] Retry với approach khác
     [B] Skip batch này (implement manually sau)
     [C] Stop và review chi tiết"
```

## 13.4 Large Project Mode (LPM)

```
Khi large_project = True:
  → Chỉ run UNIT tests (không integration tests) — tiết kiệm thời gian
  → Integration tests chạy ở Phase 5a Cross-Validation thay vì sau mỗi batch
  → LOG: "[GATE-LPM] Unit tests only — integration tests deferred to Phase 5a"
```
