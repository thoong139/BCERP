# Sprint 7: E2E Test + Evals + Compliance Audit

> **Estimate:** 2h
> **Phụ thuộc:** Tất cả sprints trước (S1-S6)
> **Solves:** Final verification
> **PR Group:** PR #3

---

## Mục tiêu

End-to-end test trên project EUREKA-2026 (hoặc project test), chạy toàn bộ 18 evals, compliance audit, smoke test multi-dev safety.

## Deliverables

### 7.1 E2E Test Scenario

**Scenario:** Thay đổi logic tính chiết khấu trên EUREKA-2026

```
Test: /wf-manage-change "Thay doi muc chiet khau cho khach hang VIP —
       hien tai ap dung cho don > 10 trieu, muon doi thanh ap dung cho tat ca don hang"

Verify:
1. Phase 0: session lock acquired, sessions.jsonl appended, session ID generated
2. Phase 1: DEEP mode (cross-system), experts spawned
3. Phase 2: impact report with risk level, user gate
4. Phase 3: plan approved, change_id in plan
5. Phase 4a: registry backup created, lock around registry write, docs updated
6. Phase 4b: code backup, REQ-IDs preserved, mini-verify pass
7. Phase 4c: tests updated
8. Phase 5: preflight + verify-sync invoked
9. Phase 6: change-report.md + phase-summary.md + change-impact.json created,
            session lock released, heartbeat stopped
```

### 7.2 Multi-Dev Concurrent Test

```
Terminal 1: /wf-manage-change "Thay doi cach tinh phi..."
Terminal 2: /wf-manage-change "Bo sung xac thuc 2 lop..." (cùng lúc)

Verify:
1. Terminal 2 bị từ chối nếu Terminal 1 đang hold registry lock
2. Hoặc Terminal 2 chạy OK nếu không chạm registry cùng lúc
3. sessions.jsonl có 2 entries, không corruption
4. index.json có 2 sessions, valid JSON
5. Registry consistent sau cả 2 complete
```

### 7.3 Resume Test

```
1. Start /wf-manage-change "..."
2. Ctrl+C ở giữa Phase 4a (sau registry backup, trước registry update)
3. /wf-manage-change --resume
4. Verify: continue từ Phase 4a, không repeat Phase 0-3
5. Verify: session lock re-acquired, heartbeat restarted
```

### 7.4 Dry-Run Test

```
/wf-manage-change "Xoa tinh nang xuat Excel" --dry-run

Verify:
1. Phase 0-3 chạy bình thường
2. Phase 4a DRY-RUN STOP GATE → STOP
3. change-impact.json KHÔNG tạo (dry-run)
4. phase-summary.md mô tả kế hoạch, không phải thực hiện
5. Session lock released
```

### 7.5 All Evals Run

```bash
# Chạy 18 evals
# Kiểm tra pass rate
# Flag failing evals → fix → re-run
```

### 7.6 Compliance Audit

```bash
# Skill compliance
./.claude/scripts/skill-compliance-audit.sh wf-manage-change

# Schema sync
./.claude/scripts/validate-schema-sync.sh wf-manage-change

# Verify output:
# - PASS cho tất cả checks
# - Template coverage 100% (CORE-031)
# - _contract.json fields valid
# - No cross-reference errors
```

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | E2E test scenario PASS — 9 phases complete, all files created | Manual test trên EUREKA-2026 |
| AC2 | Multi-dev test: concurrent sessions không gây data corruption | Manual test 2 terminals |
| AC3 | Resume test: tiếp tục từ Phase 4a sau Ctrl+C | Manual test |
| AC4 | Dry-run test: STOP tại Phase 4a, không modify files | Manual test |
| AC5 | 18/18 evals PASS | `jq '.evals \| map(.assertions) \| flatten \| map(select(.type == "behavior")) \| length' evals.json` |
| AC6 | skill-compliance-audit.sh PASS | Script output: "PASS" |
| AC7 | validate-schema-sync.sh PASS | Script output: "PASS" |
| AC8 | change-impact.json valid JSON, có đầy đủ fields | `jq '.' $SESSION_DIR/change-impact.json` |
| AC9 | sessions.jsonl có entries cho mọi session | `wc -l sessions.jsonl` >= 1 |
| AC10 | Token usage giảm so với v2.0.3 | So sánh token count giữa 2 version |

## Token Usage Comparison

Chạy E2E scenario trên cả v2.0.3 và v3.0, so sánh:

| Metric | v2.0.3 (baseline) | v3.0 | Target improvement |
|--------|-------------------|------|-------------------|
| Total tokens | TBD | TBD | -35% |
| Phase 0 tokens | TBD | TBD | -30% |
| Phase 4a tokens | TBD | TBD | -25% |
| Phase 6 tokens | TBD | TBD | -20% |

## Risks

| Risk | Mitigation |
|------|------------|
| E2E test fail do EUREKA-2026 chưa có đủ data | Dùng fallback: tạo mock data hoặc test trên project khác |
| Eval #16 (lock) khó test tự động | Test thủ công, ghi result vào progress.md |
| Token comparison không chính xác | Chạy 3 lần, lấy median |

## Definition of Done

- [ ] E2E test PASS (AC1)
- [ ] Multi-dev concurrent test PASS (AC2)
- [ ] Resume test PASS (AC3)
- [ ] Dry-run test PASS (AC4)
- [ ] 18/18 evals PASS (AC5)
- [ ] skill-compliance-audit.sh PASS (AC6)
- [ ] validate-schema-sync.sh PASS (AC7)
- [ ] Token usage comparison documented (AC10)
- [ ] CHANGELOG entry
- [ ] CLAUDE.md skill table refreshed
- [ ] Memory: update project progress
