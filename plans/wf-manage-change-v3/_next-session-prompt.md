# Next Session Prompt — Sprint 7: E2E Test + Audit

> **Cập nhật:** 2026-04-29 (sau khi Sprint 6 DONE)
> **Sprint trước đã hoàn thành:** S1 → S6 (scripts + lock/heartbeat + change-impact.json + template fixes + phase files + contract/wiring)
> **Sprint kế tiếp:** S7 — E2E Test + Audit (2h estimate, phụ thuộc tất cả S1-S6)
>
> Copy toàn bộ block dưới đây vào phiên mới để tiếp tục triển khai.

---

## Prompt copy-paste vào session sau

```
Tiếp tục triển khai /wf-manage-change v3.0 Overhaul — Sprint 7.

**Bối cảnh:**
- Sprint 1 DONE (~45min): 11 bash scripts tại `.claude/scripts/wf-manage-change/`
- Sprint 2 DONE (~30min): lock/heartbeat/sessions.jsonl/EXIT trap wired vào 4 procedures
- Sprint 3 DONE (~25min): change-impact.json template + builder + Phase 6 Steps 6.0.5/6.0.5b
- Sprint 4 DONE (~15min): change-plan.md, phase-summary.md (NEW template), change-status.json fields,
  change-intake.json, _contract.json template path, phase6-report.md READ→POPULATE→WRITE
- Sprint 5 DONE (~30min): 9 phase files wired mc-postgate-check.sh, resume-routing.md tách riêng
  (tách từ _shared.md), SKILL.md Protocol list thêm 16/17/18
- Sprint 6 DONE (~35min): SKILL.md 3.0.0 + Steps table + 3 design principles. _contract.json 3.0.0
  + produces_for wf-implement-feature. 00-core.md §4b 3 entries. evals.json 18 entries. AC1-AC8 PASS.
- Plan hoàn chỉnh tại `plans/wf-manage-change-v3/` (13 files)
- Progress tracking: `plans/wf-manage-change-v3/progress.md` (S1-S6 DONE, S7 PENDING;
  G1-G10 tất cả → DONE)

**Thứ tự đọc trước khi triển khai:**
1. `plans/wf-manage-change-v3/sprints/sprint-7-e2e-test.md` — Sprint 7 spec đầy đủ
2. `.claude/skills/workflow/wf-manage-change/SKILL.md` — phiên bản 3.0.0 (317 dòng)
3. `.claude/skills/workflow/wf-manage-change/_contract.json` — version 3.0.0
4. `.claude/skills/workflow/wf-manage-change/evals/evals.json` — 18 evals (id 1-18)
5. `plans/wf-manage-change-v3/progress.md` — trạng thái S1-S6 DONE

**Sprint 7: E2E Test + Audit (2h estimate)**

Solves: Final verification — E2E test, multi-dev concurrent test, resume test, dry-run test,
18 evals validation, compliance audit + token usage comparison. Sau S7 DONE → v3.0.0 RELEASED.

---

### DELIVERABLE 1: E2E Test Scenario

**Test command:**
```
/wf-manage-change "Thay doi muc chiet khau cho khach hang VIP —
hien tai ap dung cho don > 10 trieu, muon doi thanh ap dung cho tat ca don hang"
```

**Verify 9 phases:**
1. Phase 0: session lock acquired, sessions.jsonl appended, session ID generated (CHG-YYYYMMDD-NNN)
2. Phase 1: DEEP mode, experts spawned (≥1 expert agent)
3. Phase 2: impact report với risk level, user gate hiển thị đúng
4. Phase 3: plan approved, change_id trong plan header table
5. Phase 4a: registry backup tạo, lock xung quanh registry write, docs updated
6. Phase 4b: code backup (.pre-change-*), REQ-IDs preserved, mini-verify pass
7. Phase 4c: tests updated hoặc skip với warning
8. Phase 5: preflight + verify-sync invoked với change context
9. Phase 6: change-report.md + phase-summary.md + change-impact.json tạo, session lock released

---

### DELIVERABLE 2: Multi-Dev Concurrent Test

```
Terminal 1: /wf-manage-change "Thay doi cach tinh phi van chuyen..."
Terminal 2: /wf-manage-change "Bo sung xac thuc 2 lop..." (cùng lúc)
```

Verify: sessions.jsonl không corruption, registry consistent, lock mechanism hoạt động.

---

### DELIVERABLE 3: Resume Test

1. Start `/wf-manage-change "..."`, Ctrl+C ở giữa Phase 4a
2. `/wf-manage-change --resume`
3. Verify: tiếp tục từ Phase 4a, không repeat Phase 0-3

---

### DELIVERABLE 4: Dry-Run Test

```
/wf-manage-change "Xoa tinh nang xuat Excel" --dry-run
```

Verify: Phase 0-3 chạy, Phase 4a STOP, change-impact.json KHÔNG tạo.

---

### DELIVERABLE 5: Compliance Final Audit

```bash
./.claude/scripts/skill-compliance-audit.sh wf-manage-change   # → PASS
./.claude/scripts/validate-schema-sync.sh wf-manage-change      # → PASS
```

---

**Sprint 7 AC:**
- AC1: E2E test PASS — 9 phases complete, change-impact.json valid JSON
- AC2: Multi-dev test — sessions.jsonl không corrupt, registry consistent
- AC3: Resume test PASS — tiếp tục từ đúng phase
- AC4: Dry-run test PASS — STOP tại Phase 4a, không modify files
- AC5: 18 evals conceptually reviewed (hành vi đúng spec)
- AC6: `skill-compliance-audit.sh wf-manage-change` → PASS (hiện đã PASS)
- AC7: `validate-schema-sync.sh wf-manage-change` → PASS (hiện đã PASS)
- AC8: `jq '.' $SESSION_DIR/change-impact.json` → valid JSON, có đủ 8 fields
- AC9: `wc -l .mc-data/work/wf-manage-change/_index/sessions.jsonl` ≥ 1
- AC10: Ghi nhận token usage comparison (v2.0.3 vs v3.0.0)

**Sau khi Sprint 7 xong:**
- Update `plans/wf-manage-change-v3/progress.md`: S7 → DONE
- Trạng thái: "Sprint 1+2+3+4+5+6+7 DONE — v3.0.0 RELEASED"
- Update memory: project_wf-manage-change-v3-improvement-plan.md → COMPLETED
- Update CLAUDE.md skill table: wf-manage-change entry với v3.0.0 features

**Ưu tiên:** 1. Accuracy > 2. Speed > 3. Token saving.
```

---

## Checklist sau khi Sprint 7 xong

- [ ] E2E test PASS (AC1)
- [ ] Multi-dev concurrent test PASS (AC2)
- [ ] Resume test PASS (AC3)
- [ ] Dry-run test PASS (AC4)
- [ ] 18 evals reviewed (AC5)
- [ ] `skill-compliance-audit.sh` PASS (AC6)
- [ ] `validate-schema-sync.sh` PASS (AC7)
- [ ] change-impact.json valid JSON (AC8)
- [ ] sessions.jsonl có entries (AC9)
- [ ] Token usage comparison documented (AC10)
- [ ] `progress.md` update: S7 DONE + v3.0.0 RELEASED
- [ ] Memory updated

---

## Sprint kế tiếp sau S7

Không có sprint tiếp theo — v3.0.0 sẽ RELEASED sau S7.
