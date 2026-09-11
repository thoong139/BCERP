# Sprint 3: change-impact.json Schema + Builder

> **Estimate:** 1.5h
> **Phụ thuộc:** S1 (mc-change-impact-build.sh, mc-common.sh)
> **Solves:** G4 (machine-readable cross-skill artifact)
> **PR Group:** PR #2

---

## Mục tiêu

Tạo machine-readable artifact `change-impact.json` — consumed bởi wf-verify-sync, wf-preflight, wf-implement-feature. Giải quyết việc skills downstream phải parse markdown.

## Deliverables

### 3.1 Schema definition

Tạo template `templates/change-impact.json` — schema `change-impact-v1`.

Full schema → xem [`02-architecture-design.md`](../02-architecture-design.md) §4.

### 3.2 Builder script integration

Script `mc-change-impact-build.sh` đã tạo ở S1. Sprint này:

1. Test script hoạt động với session data thực
2. Verify output khớp schema
3. Handle edge cases (CLARIFY_REQ — files_modified rỗng, dry-run — verify_evidence null)

### 3.3 Phase 6 integration

Update `procedures/phase6-report.md`:

| Step | Thay đổi |
|------|----------|
| Before 6.1 | Thêm Step 6.0.5: **Build change-impact.json** — gọi `mc-change-impact-build.sh --session-dir=$SESSION_DIR` |
| After 6.0.5 | Thêm: populate `verify_evidence` và `regression_check` từ Phase 5 results |
| 6.1 | Giữ nguyên (change-report.md) |
| Output list | Thêm `$SESSION_DIR/change-impact.json` vào output files table |

### 3.4 Verify evidence population

Trong Phase 6 Step 6.0.5, sau khi builder tạo initial change-impact.json:

```bash
# Populate verify_evidence từ Phase 5 results
jq --argjson preflight "$PREFLIGHT_STATUS" \
   --argjson sync_rate "$SYNC_RATE" \
   --argjson coverage "$CROSS_VALIDATION_COVERAGE" \
   '.verify_evidence = {
     preflight_status: $preflight,
     sync_rate: $sync_rate,
     cross_validation_coverage: $coverage
   }' $SESSION_DIR/change-impact.json > $SESSION_DIR/change-impact.json.tmp
mv $SESSION_DIR/change-impact.json.tmp $SESSION_DIR/change-impact.json
```

### 3.5 Cross-skill wiring spec

Chuẩn bị spec cho Sprint 6 (chưa update 00-core.md):

**wf-verify-sync consumption:**
```
# /wf-verify-sync --from-manage-change=CHG-20260429-001
# Phase 0 Step 0.18-0.22:
  Load $SESSION_DIR/change-impact.json
  Cross-check registry_changes vs current registry
  Phase 5 Check 5.11: cross-check với actual registry state
  Phase 6 Section 14: "Change Impact Cross-Reference"
```

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | `templates/change-impact.json` tồn tại với schema `change-impact-v1` | `jq '.' templates/change-impact.json` pass |
| AC2 | `mc-change-impact-build.sh` tạo change-impact.json từ session data | Chạy script → output valid JSON |
| AC3 | change-impact.json có đầy đủ 8 base fields ($schema, change_id, change_type, risk_level, registry_changes, files_modified, docs_modified, generated_at) | `jq 'keys | length >= 8' change-impact.json` |
| AC4 | CLARIFY_REQ edge case: files_modified=[], docs_modified=[] → builder không fail | Test với change-type=CLARIFY_REQ session |
| AC5 | Dry-run edge case: verify_evidence=null, regression_check=null → builder không fail | Test với dry-run session |
| AC6 | audit_chain có checksum_pre/post (nếu backup tồn tại) | `jq '.audit_chain | has("checksum_pre")' change-impact.json` |

## Risks

| Risk | Mitigation |
|------|------------|
| Builder script fail khi session data thiếu fields | Graceful: `jq` fallback sang default values, log WARNING |
| change-impact.json không được consumer skills dùng (chưa wired) | Sprint 6 sẽ wire. v3.0 tạo sẵn artifact, consumer skills update riêng. |

## Definition of Done

- [ ] templates/change-impact.json tạo
- [ ] mc-change-impact-build.sh hoạt động với session data thực
- [ ] Phase 6 Step 6.0.5 thêm builder call
- [ ] AC1-AC6 pass
- [ ] Cross-skill consumption spec sẵn cho Sprint 6
