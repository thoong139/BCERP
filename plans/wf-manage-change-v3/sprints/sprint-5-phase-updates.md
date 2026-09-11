# Sprint 5: Phase Files Update — Inline → Bash Delegation + Lock Integration

> **Estimate:** 2h
> **Phụ thuộc:** S1 (bash scripts), S2 (lock integration patterns), S4 (template updates)
> **Solves:** G3 (bash delegation), G7 (resume routing isolation), G8 (protocol references)
> **PR Group:** PR #2

---

## Mục tiêu

Update tất cả 10 phase files + _shared.md: thay inline bash bằng script calls, thêm protocol references, tách resume routing. Đây là sprint "large" nhất — chạm nhiều files nhất.

## Deliverables

### 5.1 procedures/phase0-intake.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| 0.0 | Thêm: `mc-acquire-lock.sh --type=session --id=$CHANGE_ID` | mc-acquire-lock |
| 0.0b | Thêm: `mc-heartbeat.sh --id=$CHANGE_ID &` | mc-heartbeat |
| 0.1 | Inline session ID gen → `mc-generate-session-id.sh` | mc-generate-session-id |
| 0.1b | Inline index update → `mc-index-append.sh` + dual-write index.json | mc-index-append |
| 0.1c | Thêm: EXIT trap `mc-release-lock.sh --type=session` | mc-release-lock |
| 0.3 | Inline registry parse → giữ nguyên (AI reasoning, không delegate) | — |
| 0.4 | LEGACY detection → giữ nguyên (single bash check) | — |
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh --file=... --type=json` | mc-postgate-check |

### 5.2 procedures/phase1-analyze.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |
| 1.5/1.6 | Giữ nguyên (AI WRITE — không delegate) | — |

### 5.3 procedures/phase2-impact.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| 2.1-2.2 | Giữ nguyên (AI READ + Grep — cần reasoning) | — |
| 2.5 | Giữ nguyên (AI classification — không delegate) | — |
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh --type=markdown --headings="..."` | mc-postgate-check |

### 5.4 procedures/phase3-plan.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.5 procedures/phase4a-registry-docs.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| 4a.1 | Inline `cp` → `mc-backup-registry.sh` | mc-backup-registry |
| Before 4a.5 | Thêm: `mc-acquire-lock.sh --type=registry --id=$CHANGE_ID` | mc-acquire-lock |
| 4a.5 | Inline jq validate → `mc-validate-registry.sh` | mc-validate-registry |
| After 4a.5 | Thêm: `mc-release-lock.sh --type=registry` | mc-release-lock |
| 4a.6 | Checkpoint save → giữ nguyên | — |
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.6 procedures/phase4b-code.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| 4b.0.5 | Giữ nguyên backup (code files, không phải registry) | — |
| 4b.3 | Mini-verify: thêm `mc-validate-registry.sh` nếu cần check registry | mc-validate-registry |
| ESCALATE | Registry rollback: giữ inline (không thường xuyên, cần AI judgment) | — |
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.7 procedures/phase4c-tests.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.8 procedures/phase5-verify.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.9 procedures/phase6-report.md — Update

| Step | Thay đổi | Script dùng |
|------|----------|-------------|
| 6.0.5 | **MỚI:** `mc-change-impact-build.sh --session-dir=$SESSION_DIR` | mc-change-impact-build |
| 6.2 | Free-form → READ template `templates/phase-summary.md` → POPULATE → WRITE | — |
| 6.4+ | Thêm: kill heartbeat + release session lock | mc-release-lock |
| 6.4+ | Thêm: `mc-index-append.sh --status=completed` | mc-index-append |
| POST-GATE | Inline T1-T4 → `mc-postgate-check.sh` | mc-postgate-check |

### 5.10 procedures/_shared.md — Trim

| Thay đổi | Chi tiết |
|----------|---------|
| Bỏ §Resume Logic & Routing Table | Tách sang `procedures/resume-routing.md` |
| Thêm lock-aware resume steps | Tham chiếu đến resume-routing.md |
| Giữ 10 sections còn lại | — |

### 5.11 procedures/resume-routing.md — MỚI (tách từ _shared.md)

~85 dòng, tách từ _shared.md §Resume Logic & Routing Table. Bổ sung:

| Thêm mới | Chi tiết |
|----------|---------|
| Lock-aware resume | Check .session.lock active → từ chối nếu heartbeat fresh |
| Stale takeover | Cho phép takeover nếu heartbeat > 60 phút |
| Re-acquire lock | Acquire session lock khi resume thành công |
| Restart heartbeat | Start heartbeat daemon mới |

### 5.12 Protocol References (SKILL.md)

Update SKILL.md Protocol list:

```
TRƯỚC: Protocol 1, 6, 7, 8, 9, 10, 10.4, 11, 14, 15, 19
SAU:   Protocol 1, 6, 7, 8, 9, 10, 10.4, 11, 14, 15, 16, 17, 18, 19
```

Thêm reference text:
- Protocol 16 (CDG) — Phase 4a.2 DELETE_FEATURE
- Protocol 17 (Agent Spot-Check) — Phase 1 DEEP Step 1.4b
- Protocol 18 (Session Isolation) — CORE-030 implementation

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | Phase 0 dùng mc-generate-session-id.sh (không inline gen) | `grep -c "mc-generate" phase0-intake.md` >= 1 |
| AC2 | Phase 4a dùng mc-backup-registry.sh (không inline cp) | `grep -c "mc-backup" phase4a-registry-docs.md` >= 1 |
| AC3 | Phase 4a có registry lock acquire/release quanh Step 4a.5 | `grep -c "mc-acquire-lock.*registry" phase4a-registry-docs.md` >= 1 |
| AC4 | Tất cả POST-GATE dùng mc-postgate-check.sh (không inline T1-T4) | `grep -c "mc-postgate-check" phase*.md` >= 7 (7 phases) |
| AC5 | resume-routing.md tồn tại, độc lập từ _shared.md | `test -f procedures/resume-routing.md` |
| AC6 | _shared.md không còn chứa Resume Logic & Routing Table section | `grep -c "Resume Logic" procedures/_shared.md` == 0 |
| AC7 | SKILL.md Protocol list có 16, 17, 18 | `grep "Protocol 16" SKILL.md` |
| AC8 | Phase 6 Step 6.0.5 build change-impact.json | `grep "change-impact" phase6-report.md` |
| AC9 | Phase 6 Step 6.2 dùng template phase-summary.md | `grep "templates/phase-summary" phase6-report.md` |

## Risks

| Risk | Mitigation |
|------|------------|
| Phase file changes gây inconsistency giữa steps | Mỗi phase file review riêng, POST-GATE verify syntax |
| resume-routing.md tách ra → reference cũ trong _shared.md die | _shared.md thêm redirect: "Xem procedures/resume-routing.md" |
| Inline → script call có thể miss arguments | Script có argument validation + error messages |

## Definition of Done

- [ ] 10 phase files + _shared.md update
- [ ] resume-routing.md tạo (tách từ _shared.md)
- [ ] SKILL.md Protocol list update (16, 17, 18)
- [ ] AC1-AC9 pass
- [ ] Mọi phase POST-GATE dùng mc-postgate-check.sh
- [ ] Phase 4a có registry lock guard
- [ ] Phase 6 build change-impact.json + dùng phase-summary template
