# Define Features Report — /wf-define-features

> **Ngày:** 2026-09-12 (session 20260912-112934-6bcf, resume sau dừng chủ động 12/09)
> **Scope:** all (Plan B full scope — CDG-A02)
> **Version SKILL:** wf-define-features (procedures v2.1, CF6/W4.7)

## Kết Quả

| Mục | Giá trị |
|-----|---------|
| Feature files tạo mới | 170 (6 systems × 19 modules, 72 lanes) |
| FEAT-IDs đăng ký | 170 (registry features[] = 170, counters.FEAT = 170) |
| REQ-IDs đã map | 59 / 59 (fan-out per-system theo requirements[].systems[]) |
| Cross-validation iterations | 1 (full scan 170/170 — 0 lỗi) |
| Findings RESOLVED | 5 (H-01 SM→SALES_L4 9 file/40+ vị trí; M-03; M-04 SoD; F-D3-1; F-D3-3 triage) |
| Findings DEFERRED | 7 (đã ghi deferred-findings.md — không chặn) |
| Stakeholder Review | APPROVED_WITH_CONDITIONS |

### Điều kiện APPROVED đã thực thi tại Phase 5
1. ✅ Safe-Write 170 features[] vào req-registry.json (atomic write, schema-guard + referential integrity PASS).
2. ✅ Nạp vai OPS_AD vào registry: SYS-BCERP-WEB.user_roles 18→19, SYS-MOBILE-INTERNAL.user_roles 10→11 (theo KXN-12 đã chốt 12/09; append-only).

## Outputs

| File | Trạng thái |
|------|-----------|
| `docs/phase2-features/` | 170 files + stakeholder-review.md |
| `docs/phase2-features/stakeholder-review.md` | ✅ Created (4 phần A/B/C/D, 14 findings đã classified) |
| `work/wf-define-features/cross-validation-report.md` | ✅ PASS_WITH_WARN (full scan, 1 iteration) |
| `work/wf-define-features/deferred-findings.md` | ✅ 7 DEFERRED + CF6 378 cross-refs + W4.7 skip |
| `docs/_meta/req-registry.json` (features[]) | ✅ Updated — 170 entries + OPS_AD |
| `docs/_meta/feature-briefs.json` (digest) | ✅ Created (170 briefs, schema _digests v1.0, stripped) |
| `work/wf-define-features/aggregation-result.json` | ✅ 170→170, 0 dup/conflict |
| `work/wf-define-features/define-features-plan.md` | ✅ (Phase 1) |

## WARNs Còn Mở

| Mã | Mô tả | Cần hành động trước |
|----|-------|---------------------|
| WARN-OPSAD | Specs dùng OPS_AD (13 file) + OPS_ADS (75 file) — hai mã vai khác nhau (AD=Account Director vs Ads Specialist); OPS_AD mới được nạp registry | /wf-design rà các chỗ map AD tạm OPS_AM/OPS_PLAN/SALES_L5 để gán lại OPS_AD |
| WARN-SM | SM=SALES_L4 (KXN-14) đã đồng bộ; sales.md gốc vẫn ghi SALES_L3 (TNKD) | owner bộ tài liệu quy trình rà lại sales.md A1 |
| KXN còn mở | 11 khoản (6,7,9,15–22) = assumption có tag trong specs; nhóm ưu tiên: KXN-12/14/19 (vai&RACI), KXN-22/9 (ví/CMS), KXN-20 (cảnh báo K6–K12) | Chủ dự án chốt khi tiện — không chặn /wf-design |

## Next Step

`/wf-design` — Thiết kế architecture. Đọc `deferred-findings.md` ở Phase 0. Digest: `.mc-data/docs/_meta/feature-briefs.json`.
