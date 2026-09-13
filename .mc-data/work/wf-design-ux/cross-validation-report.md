# Cross-Validation Report — wf-design-ux (BCERP)

> Session `20260913-080222-df29` | Phase 4 | 13 checks (8 chính + 2 CQG + 3 ERP working-context v4.1)

## Tổng quan
- Total iterations: 2 (iteration 1 = 12 programmatic checks + aggregation; iteration 2 = 4.8 accessibility audit + auto-fixes)
- Total errors found: 3 (1 script false-negative resolved → 4.3/4.7 path bug; 1 High a11y + 7 Medium a11y)
- Total errors fixed: 3 nhóm (nav-sync xác nhận PASS; a11y fixes áp dụng vào specs)
- Errors remaining: 0 Critical/High sau fix
- Status: **PASSED**

## Aggregation (ADR-OPT-04)
- Lanes: 22 | Screens aggregated: 42 | Dedup key: `screen_id`
- Duplicates: 0 | Conflicts: 0 | Merged-to-shared-design: 0 cần thiết (component reuse đã nằm trong design-system Phase 1)
- Output: `sessions/20260913-080222-df29/aggregation-result.json`

## Iteration 1 — programmatic checks

| Check | Kết quả | Ghi chú |
|-------|---------|---------|
| 4.1 Feature-Screen Coverage | PASSED | 19/19 module UI có ≥1 screen group; mobile/portal phủ qua feature touchpoints |
| 4.2 UI-ID Uniqueness | PASSED | 413 owned IDs, 0 trùng (1 reference row S1→S2 đã relabel `(ref)`) |
| 4.3 Navigation→File sync | PASSED | 39/39 refs khớp (sau khi sửa path bug của script kiểm tra, không phải của docs) |
| 4.4 API Endpoint Validity | PASSED | 0 endpoint bịa — mọi ref API-* tồn tại trong api-contract.md; endpoint thiếu đã được lanes ghi [NEEDS_REVIEW] thay vì bịa |
| 4.5 Design Token Consistency | PASSED | 0 raw hex trong screen specs — mọi màu qua token |
| 4.6 Permission Matrix Sync | PASSED (2 ghi chú) | Vai khớp registry/P3-01; 2 lệch nhỏ do lanes ghi nhận: thẩm định rate card (FIN_L1 vs FIN_L2), duyệt vòng 1 (HR_L1 vs TL) → đã ghi [NEEDS_REVIEW] trong files |
| 4.7 File→Navigation bidirectional | PASSED | 39/39, 0 orphan |
| CQG-09.1 All UI Features Covered | PASSED | 170/170 FEAT touchpoints thuộc module có screens |
| CQG-09.2 Design System Match | PASSED | Token-only colors |
| 4.11 Screen Justification Coverage | PASSED | 4/4 Navigation có bảng "Cơ Sở Giữ Lại Màn Hình"; 0 screen ngoài inventory (M6 NEEDS_REVIEW không tạo file) |
| 4.12 Tab Completeness (R7) | PASSED | 0 placeholder tab ("tương tự"/"same pattern") |
| 4.13 Cross-Module Context (R5) | PASSED | Sample 5 detail screens cross-module: ADACC↔WALLET hard stop, WALLET↔TKQC, CAPTS→KPI/COMM feed, CSKH↔CAMP/CRM, COMM←ARAP thực nhận — đều có |

## Iteration 2 — 4.8 Accessibility audit (accessibility-auditor agent)

Verdict gốc: FIXES NEEDED (1 High, 7 Medium, 2 Low). **Auto-fixes đã áp dụng:**

| Finding | Mức | Fix |
|---------|-----|-----|
| Character Key Shortcuts (2.1.4) — A/R bind toàn cục | **High** | Ghi ràng buộc vào approval-inbox (bind container-level, vô hiệu trong input, toggle Settings) + quy tắc hệ thống A1 |
| Tabs thiếu ARIA pattern | Medium | design-system §8.1 A2 |
| DataGrid thiếu table semantics | Medium | §8.1 A3 |
| Split view focus (F6, aria-controls) + owner chỉ-màu | Medium | Sửa screens-pipeline.md trực tiếp |
| Form disabled-only + thiếu aria-describedby | Medium | approval-inbox note + §8.1 A5 |
| Executive BI: nhãn uppercase có dấu vi phạm rule §2 + chart thiếu a11y | Medium | Sửa labels trực tiếp + chart a11y note |
| Thiếu skip-link + landmarks | Medium | §8.1 A4 |
| Swipe gesture không có nút tương đương | Medium | Đã có sẵn trong Navigation-mobile-internal §4.5 (sticky footer fallback) → xác nhận PASS, chuẩn hóa thành A6 |
| Border contrast 1.35:1 | Low | §8.1 A7 — token mới `--color-border-control` |
| lang="vi", toast aria-live, icon-only label | Low | §8.1 A8; sửa lỗi ký tự "异常" trong executive-bi |

## Deferred Findings (chuyển Phase 5)
- ~70 mục [NEEDS_REVIEW] endpoint/role do 22 lanes ghi nhận trung thực (không bịa endpoint) — tính chất: gap giữa UI spec và api-contract v1, không phải lỗi UX design. Phase 5 tổng hợp thành danh sách DEFERRED cho `/wf-plan-modules`.
- F-C-02 (TikTok lifecycle 3 nguồn) — DEFERRED từ /wf-design, đã chú thích trong screens-tiktok-monitor.md.

## Agents Spawned
- accessibility-auditor: 1 invocation (iteration 2)
