<!-- From shared-protocols.md lines 9-72 (§1 + §1b) -->
# Protocol 1 — Accuracy Assurance Protocol (BẮT BUỘC — MỌI PHASE)

> Đảm bảo **độ chính xác tuyệt đối** từ đầu đến cuối. Không phase nào được "pass" khi còn lỗi.

## 1.1 POST-GATE Enforcement

```
SAU MỖI PHASE:
1. Chạy TẤT CẢ verify checks trong POST-GATE
2. Nếu BẤT KỲ check nào FAIL:
   a. Log lỗi cụ thể (file, field, expected vs actual)
   b. Auto-fix nếu có thể (xem Fix Rules của từng skill)
   c. Re-run POST-GATE checks
   d. Lặp tối đa 3 lần
   e. Nếu vẫn FAIL sau 3 lần → STOP phase, escalate to user
3. KHÔNG BAO GIỜ tiến sang phase tiếp theo khi POST-GATE chưa PASS
```

## 1.2 Fix Rules chung

| Loại lỗi | Auto-Fix | Escalate nếu |
|-----------|----------|---------------|
| File không tồn tại | Tạo file từ template/context | Không đủ context để tạo |
| File rỗng (size 0) | Re-run step tạo file | Vẫn rỗng sau retry |
| Placeholder (TODO/TBD) | Điền từ context có sẵn | Không có context → hỏi user |
| REQ-ID format sai | Chuẩn hóa theo `REQ-[DEPT]-[NNN]` | Ambiguous ID |
| JSON invalid | Fix syntax error | Structure corruption |
| Duplicate entries | Merge/deduplicate | Conflicting data |
| Missing cross-reference | Tạo reference | Không biết target |

## 1.3 Cumulative Error Tracking

```
Duy trì error_log[] xuyên suốt tất cả phases:

error_log.push({
  phase: "Phase X",
  step: "X.Y",
  check: "description",
  status: "FIXED" | "ESCALATED",
  iteration: N,
  detail: "..."
})

→ Ghi vào report cuối cùng của skill.
```

---

## 1b. Agent Status Protocol

> Mọi agents phải report một trong 4 statuses khi hoàn thành task.

| Status | Khi nào | Auto-correction? |
|--------|---------|-----------------|
| `DONE` | Task hoàn thành, mọi POST-GATE criteria đạt | N/A |
| `DONE_WITH_CONCERNS` | Task hoàn thành nhưng có warnings không blocking (flaky test, partial coverage, skipped optional check) | **KHÔNG** — log và continue |
| `BLOCKED` | Không thể tiến hành, cần external input | Escalate to user |
| `NEEDS_CONTEXT` | Thiếu thông tin cụ thể để hoàn thành | Request từ orchestrator |

**Rule**: `DONE_WITH_CONCERNS` KHÔNG trigger Auto-Correction Loop. Orchestrator log warning và advance.
**Rule**: Auto-Correction Loop (3 retries) chỉ áp dụng cho hard failures — missing files, invalid JSON, schema violations.
