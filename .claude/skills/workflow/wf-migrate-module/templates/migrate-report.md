---
$schema: migrate-report-v1
migrate_id: {MIGRATE_ID}
status: {passed | partial | failed}
---

# Bao cao Migration — {MIGRATE_ID}

## Thong tin chung

| Muc | Gia tri |
|-----|---------|
| Module cu | {SOURCE_MODULE} ({SOURCE_SYSTEM}) |
| Module moi | {TARGET_MODULE} ({TARGET_SYSTEM}) |
| Scan session | {SCAN_SESSION_ID} |
| Bat dau | {started_at} |
| Hoan thanh | {completed_at} |
| Tong thoi gian | {elapsed} |

## Tong ket ket qua

| Chi tieu | Gia tri |
|----------|---------|
| Tong so feature | {N} |
| Keep (da implement) | {N} |
| Redesign (da implement) | {N} |
| Merge (da merge) | {N} |
| Deprecate (da bo) | {N} |
| Feature parity PASS | {N} |
| Feature parity FAIL | {N} |

## Cac phase da chay

| Phase | Trang thai | Thoi gian | Ghi chu |
|-------|-----------|----------|---------|
| Phase 0: Intake | completed | ... | |
| Phase 1: Gap Analysis | completed | ... | |
| Phase 2: Add Scope | completed | ... | {N} features seeded |
| Phase 3: Define Features | completed | ... | {N} specs created |
| Phase 4: Design | completed | ... | |
| Phase 5: Plan Modules | completed | ... | {N} tasks created |
| Phase 6: Implement | completed | ... | {N}/{M} tasks done |
| Phase 7: Report | completed | ... | |

## CDG Decisions

<!-- POPULATE: Tat ca CDG decisions da duoc user phe duyet -->

## Feature Parity Report

<!-- POPULATE: So sanh output moi vs output cu cho cac feature Keep -->

| Feature | Parity | Response Shape | Business Rules | Edge Cases | Ghi chu |
|---------|--------|---------------|---------------|------------|---------|
| {feature} | PASS / PARTIAL / FAIL | PASS/FAIL | PASS/FAIL | PASS/FAIL | {neu FAIL: chi tiet sai lech} |

### Tong hop parity

| Ket qua | Count |
|---------|-------|
| PASS | {N} |
| PARTIAL | {N} |
| FAIL | {N} |

## Rollback Snapshots

<!-- POPULATE v1.1: Liet ke tat ca snapshot da tao -->

| # | Snapshot | Phase | Path |
|---|----------|-------|------|
| 1 | Registry pre-implement | Phase 6 | `$SESSION_DIR/snapshots/registry-phase6-pre-{ts}.json` |
| 2 | Changed files task 1 | Phase 6 | `$SESSION_DIR/snapshots/changed-files-task1-{ts}.txt` |
| ... | ... | ... | ... |

Xem chi tiet huong dan rollback: `$SESSION_DIR/rollback-guide.md`

## Registry Changes

<!-- POPULATE: Tom tat thay doi trong registry — features moi, module moi, impl_status -->

## Errors & Warnings

<!-- POPULATE: Tat ca errors tu error_log -->

## Khuyen nghi tiep theo

<!-- POPULATE: Cac buoc tiep theo cho user (preflight, deploy, testing) -->
