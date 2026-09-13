# Stakeholder Review — Phase 2 Feature Specifications

> Tổng hợp 3 góc đánh giá: Feature Cross-Review (SO-01), Consistency Check (SO-02), Gap Analysis (SO-03).
> Mục tiêu: Đảm bảo feature specs đầy đủ, nhất quán với requirements, xác nhận coverage trước khi chuyển Phase 3 (Architecture).
>
> READS: `phase2-features/[sys]/[mod]/[feat].md`, `_meta/req-registry.json`, `feature-briefs.json`, `cross-validation-report.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`
> **Tổng hợp bởi:** business-analyst (DEVKIT MCV3) | **Ngày:** 12/09/2026
> **Verdict: APPROVED_WITH_CONDITIONS** — 0 Critical, 0 High PENDING (chi tiết tại phần Xác Nhận & Sign-Off).

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 2
> **Cập nhật bởi:** business-analyst (DEVKIT MCV3)
> **Ngày cập nhật:** 12/09/2026

**Quy trình:**
1. Hoàn thành tất cả feature specs trong `phase2-features/[sys]/[mod]/`
2. Stakeholder thực hiện review theo 3 góc độ (Phần B, C, D bên dưới)
3. Ghi lại kết quả → Quay lại sửa tài liệu gốc nếu cần
4. Xác nhận Phase 2 hoàn thành → Chuyển sang Phase 3 (Architecture)

### A.1. Trạng Thái Tài Liệu Đầu Vào

> *Kiểm tra tất cả feature specs đã hoàn thành chưa trước khi bắt đầu review.*

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Feature specs CORE | `core-backend/[mod]/[feat].md` | ✅ Xong | 59 specs — headless enforce-rule cho mọi REQ |
| Feature specs ERP-WEB | `bcerp-web/[mod]/[feat].md` | ✅ Xong | 58 specs |
| Feature specs MBI | `mobile-internal/[mod]/[feat].md` | ✅ Xong | 30 specs |
| Feature specs GW | `integration-gw/[mod]/[feat].md` | ✅ Xong | 11 specs |
| Feature specs PORTAL | `portal-web/[mod]/[feat].md` | ✅ Xong | 7 specs |
| Feature specs MPO | `mobile-portal/[mod]/[feat].md` | ✅ Xong | 5 specs |
| Registry | `_meta/req-registry.json` | ✅ Xong (59 REQ) / ⏳ features[] chờ Phase 5 | `requirements[]`, `systems[]` (6 SYS / 19 MOD) đầy đủ; `features[]` + `counters.FEAT` sẽ Safe-Write ở Phase 5 (F-D4-1) |
| Briefs | `.mc-data/work/wf-define-features/feature-briefs.json` | ✅ Xong | 170 briefs — nguồn populate `features[]` |

**Tổng thể:** **170/170 feature specs đã tạo** — 6 systems, 19 modules, 59 REQ (fan-out per-system: 23 REQ × 2 systems, 28 × 3, 3 × 4, 3 × 5, 2 × 6). Cross-validation: **PASS_WITH_WARN (0 lỗi blocking)** — các cảnh báo WARN-1..3 + W4.7 đã triage hết tại mục A.3.

**Sẵn sàng review:** ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên features (SO-01 — Phần B) | business-analyst | ✅ | 1 (H-01) |
| Kiểm tra nhất quán (SO-02 — Phần C) | business-analyst | ✅ | 6 (M-01, M-02, M-03, M-04, L-01, L-02) |
| Phân tích thiếu sót (SO-03 — Phần D) | product-expert | ✅ | 7 (F-D1-1, F-D2-1, F-D3-1, F-D3-2, F-D3-3, F-D4-1, F-D4-2) |

**Tổng 14 findings: 0 Critical / 3 High (2 trùng nội dung SM + 1 registry-pending) / 6 Medium / 5 Low.**

### A.3. Tổng Hợp Vấn Đề & Hành Động

> Trạng thái phản ánh **auto-correction iteration 1 — ĐÃ CHẠY XONG (12/09/2026)**.

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | **H-01:** SM ánh xạ **SALES_L3 (TNKD)** mâu thuẫn KXN-14 đã chốt SM = **SALES_L4 (TPKD)** — sai chủ thể ký Gate 2, duyệt GM, duyệt quota | Phần B (B.3) + Phần C (C.3) | High | Chuẩn hóa SM = SALES_L4, đồng bộ sales.md A1 | 9 file: commission-quota ×2, quotation-dealdesk ×4, tiktok-shop ×3 (40+ vị trí) | business-analyst (auto-correction iteration 1) | ✅ Xong (RESOLVED) — đã sửa 9 file / 40+ vị trí; verify grep sạch; mỗi file có ghi chú "Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14" |
| 2 | **F-D3-1:** SM = SALES_L3 trên lane Handoff / Commission / TikTok (WARN-3) | Phần D (D.3) | High | Cùng nội dung H-01 — sửa theo cùng đợt | Phủ trong đợt sửa 9 file của H-01 | business-analyst | ✅ Xong (RESOLVED) — trùng nội dung H-01; grep sạch toàn corpus |
| 3 | **F-D4-1:** `req-registry.json` `features[] = []`, `counters.FEAT = 0` dù 170 spec đã viết | Phần D (D.4) | High | Safe-Write 170 `features[]` + `counters` từ `feature-briefs.json` | `_meta/req-registry.json` | Phase 5 (wf-define-features — cùng run) | ✅ Xong (RESOLVED — chờ thực thi Phase 5) — việc của phase kế tiếp trong cùng run; không phải gap của specs |
| 4 | **M-01:** `PortalBalanceView` vs `PortalWalletView` + snake_case vs camelCase + tên enum giao dịch | Phần C (C.2) | Medium | Chuẩn hóa naming SSOT — quyết định kiến trúc | `technical-specs/database-design.md` | /wf-design | ⏸ DEFERRED → /wf-design |
| 5 | **M-02:** Vai OPS_AD (Account Director) chưa có trong registry 18 vai — chuỗi escalation AM→AD có thể gãy | Phần C (C.3) | Medium | Nạp OPS_AD vào registry theo KXN-12 (đã chốt 12/09) | `_meta/req-registry.json` | Phase 5 (wf-define-features) | ✅ Xong (chờ Phase 5) — specs đã dùng kỷ luật + ghi chú `[KXN-12]`; Phase 5 nạp registry |
| 6 | **F-D3-3:** Triage WARN-2 — nghi vấn 170 spec "dùng lẫn" OPS_AD / OPS_ADS | Phần D (D.3) | Medium | Xác minh triage | — | business-analyst | ✅ Xong (RESOLVED) — specs dùng nhất quán (OPS_AD = AD, OPS_ADS = Ads Specialist) + tag `[KXN-12]`; phần nạp registry theo dõi tại M-02 (chờ Phase 5) |
| 7 | **M-03:** FEAT-CORE-RBAC-005 — typo "tin quyết quyền", câu ghép sai; state `AUTO_DISABLED` thiếu trong bảng chuyển đổi | Phần C (C.6) | Medium | Sửa typo + bổ sung state vào bảng chuyển đổi | `core-backend/rbac/FEAT-CORE-RBAC-005.md` | business-analyst | ✅ Xong (RESOLVED) — đã sửa |
| 8 | **M-04:** SoD — FIN_L1 tự duyệt lệnh do chính mình tạo khi mode SINGLE | Phần C (C.3) | Medium | Bổ sung BR-W08a: approver ≠ creator, áp dụng cả SINGLE | `core-backend/wallet/FEAT-CORE-WALLET-001.md` | business-analyst | ✅ Xong (RESOLVED) — đã thêm BR-W08a |
| 9 | **F-D3-2:** 114 marker `[CẦN CHỐT SỐ]` + `[KXN]` chờ xác nhận nằm trong BR load-bearing | Phần D (D.3) | Medium | Checklist trình stakeholder chốt; nhóm KXN ưu tiên: KXN-12/14/19 (Vai & RACI), KXN-5/8/10/11/20 (Sales gates), KXN-22/9 (ví/CMS) | — | stakeholder / chủ dự án | ⏸ DEFERRED (by-design) — assumption có tag theo nguyên tắc "không tự quyết" |
| 10 | **L-01 / F-D4-2:** 378 cross-FEAT refs (CF6) chờ stakeholder accept; registry thiếu field `cross_module_dependencies` | Phần C (C.5) + Phần D (D.4) | Low | Stakeholder accept → Phase 5 ghi `cross_feat_refs[]` khi populate | `_meta/req-registry.json` | stakeholder + Phase 5 | ⏸ DEFERRED — chờ user/stakeholder accept; đã ghi `deferred-findings.md` |
| 11 | **L-02:** Mã BR tự đặt không thống nhất giữa module (BR-W01 vs BR-SALES-301 vs BR-001) | Phần C (C.6) | Low | Quy ước chung trace BR nguồn (dạng BR-FIN-101) | Convention toàn corpus | /wf-design | ⏸ DEFERRED — convention cần quyết định ở /wf-design |
| 12 | **F-D1-1:** REQ-FIN-015 `phase=Phase2` nhưng `primary_module` MOD-DATAHUB-BI `phase=Phase3` | Phần D (D.1) | Low | Ghi chú lệch phase khi populate `features[]` | `_meta/req-registry.json` (`requirements[]`) | /wf-add-scope hoặc owner registry | ⏸ DEFERRED — dữ liệu nguồn registry (`requirements[]` không thuộc quyền sửa của specs); đã ghi chú cho phase kế tiếp |
| 13 | **F-D2-1:** Vòng đời phiên M-PORTAL trên app store riêng (device binding, mất thiết bị, rotate push token) | Phần D (D.2) | Low | Đặc tả auth/session riêng trong integration-map | — | /wf-design | ⏸ DEFERRED → /wf-design |

> Ghi chú đếm: dòng 10 hợp nhất L-01 và F-D4-2 (cùng nội dung) — tổng đếm thô **14 findings**. Khối NFR domain (D.5) và checklist tính năng ngầm định (D.6) đã DEFER sang `/wf-design` qua `deferred-findings.md`, không tính là finding riêng.

**Phân bổ trạng thái: RESOLVED 5 (H-01, F-D3-1, F-D3-3, M-03, M-04) · RESOLVED — chờ Phase 5: 2 (F-D4-1, M-02) · DEFERRED 7 (M-01, F-D3-2, L-01, L-02, F-D1-1, F-D2-1, F-D4-2).**

### A.4. Xác Nhận Phase 2 Hoàn Thành

```
[x] Tất cả feature specs đã hoàn thành — 170/170 (6 systems / 19 modules)
[x] Mỗi REQ-ID trong registry có ít nhất 1 feature spec tương ứng — 59/59, fan-out đúng systems[]
[x] Phần B (Feature Cross-Review) — hoàn thành
[x] Phần C (Consistency Check) — hoàn thành
[x] Phần D (Gap Analysis) — hoàn thành
[x] Tổng hợp vấn đề (mục A.3) — 0 PENDING Critical/High; 5 RESOLVED + 2 RESOLVED chờ Phase 5 + 7 DEFERRED (đã ghi deferred-findings.md)
[ ] req-registry.json đã cập nhật features[] — chờ Safe-Write Phase 5 (F-D4-1) — điều kiện bắt buộc trước khi P3-01 đọc registry
```

**Ngày xác nhận Phase 2 hoàn thành:** 12/09/2026 — APPROVED_WITH_CONDITIONS (điều kiện: Phase 5 Safe-Write `features[]` + nạp vai OPS_AD theo KXN-12 thực thi trong cùng run trước khi chuyển `/wf-design`).

---

## Phần B: Rà Soát Xuyên Features (Feature Cross-Review)

> Người thực hiện: business-analyst | Ngày: 12/09/2026
> **Cập nhật 12/09/2026 sau auto-correction iteration 1:** bảng finding giữ nguyên văn kết quả review; trạng thái hiện hành của H-01 tổng hợp tại mục A.3 (đã RESOLVED).

### B.1. Ma Trận REQ → FEAT Coverage

> *Kiểm tra mỗi REQ-ID có ít nhất 1 FEAT-ID tương ứng.* Kết quả scan: **59/59 REQ được cover bởi 170 FEAT-ID duy nhất** — khớp tuyệt đối với `systems[]` trong registry (không REQ nào thiếu system, không spec nào dư system so với registry; ví dụ REQ-FIN-017 chỉ registry 2 systems và đúng chỉ có 2 spec). Không có FEAT nào orphan (mọi spec tham chiếu ≥1 REQ-ID).

Phân bố fan-out: 23 REQ × 2 systems · 28 REQ × 3 · 3 REQ × 4 (BOD-011, OPS-001, OPS-011) · 3 REQ × 5 (OPS-008/009/010) · 2 REQ × 6 (OPS-003, OPS-006). Theo hệ thống: CORE 59 (mọi REQ đều có bản headless enforce rule ở service), ERP-WEB 58, MBI 30, GW 11, PORTAL 7, MPO 5.

Bảng tra vết gộp theo module (mỗi REQ thuộc đúng 1 `primary_module` nên bảng này là phân hoạch đầy đủ của 59 REQ; "n×" = số bản fan-out):

| REQ-ID(s) | Mô tả (module) | FEAT-ID(s) | Coverage | Ghi chú |
|-----------|----------------|-----------|----------|---------|
| BOD-002/005/007/009/011, HR-010, FIN-012 | RBAC & Audit Log | `*-RBAC-001..007` — CORE 7, ERP 7, MBI 2, GW 1, PORTAL 1 (18) | ✅ Đầy đủ | Nền móng cross-cutting, mọi module phụ thuộc ngược |
| BOD-003/004/006, FIN-015/016 | DataHub & BI | `*-DHUB-001..005` × CORE/ERP/MBI (15) | ✅ Đầy đủ | |
| BOD-008, FIN-005 | Settings & Integration GW | `*-STGW-001..002` × GW/CORE/ERP (6) | ✅ Đầy đủ | |
| HR-001..006 | HR Core | `*-HRCORE-001..006` × CORE/ERP (12) | ✅ Đầy đủ | MBI không có — khớp registry (chỉ WEB+CORE) |
| SALES-001..005 | CRM Pipeline V6.0 | `*-CRM-001..005` × CORE/ERP (10) + MBI 1 (11) | ✅ Đầy đủ | MBI chỉ Gate 1/2 — khớp `systems[]` |
| SALES-006/007 | Quotation & Deal Desk | `*-QDD-001..002` × CORE/ERP/MBI (6) | ✅ Đầy đủ | |
| FIN-009, OPS-001/002 | Ad Account Command Center | `*-ADACC-001..003` × CORE/ERP (6) + GW 1 + MBI 1 (8) | ✅ Đầy đủ | |
| FIN-001/002/003/004/006/010, OPS-003 | Wallet & Đối soát | `*-WALLET-001..007` × CORE 7, ERP 7, MBI 6, GW 2, PORTAL 1, MPO 1 (24) | ✅ Đầy đủ | Module dày nhất; REQ-OPS-003 fan-out 6/6 systems |
| BOD-001/010, FIN-007/008/011/013/014 | AR/AP & Giải ngân | `*-ARAP-001..007` × CORE 7, ERP 7, MBI 2, GW 2 (18) | ✅ Đầy đủ | |
| SALES-008, OPS-004 | Handoff & Onboarding | `*-HONB-001..002` × CORE/ERP/MBI (6) | ✅ Đầy đủ | |
| OPS-005 | Proposal & Planning | `*-PROPLN-001` × CORE/ERP/MBI (3) | ✅ Đầy đủ | |
| OPS-006/012 | Campaign & Deliverable | `*-CAMP-001..002` × CORE/ERP/GW/MBI (8) + PORTAL 1 + MPO 1 (10) | ✅ Đầy đủ | |
| HR-009, OPS-007 | Capacity & Timesheet | `*-CAPTS-001..002` × CORE/ERP (4) + MBI 1 (5) | ✅ Đầy đủ | |
| OPS-008 | SLA & Notification | `*-SLANOT-001` × 5 systems (5) | ✅ Đầy đủ | |
| OPS-009 | Ticket & CSKH | `*-CSKH-001` × 5 systems (5) | ✅ Đầy đủ | |
| SALES-009 | Commission & Quota | `*-COMM-001` × CORE/ERP/MBI (3) | ✅ Đầy đủ | |
| HR-007/008 | KPI & Performance | `*-KPI-001..002` × CORE/ERP (4) | ✅ Đầy đủ | |
| FIN-017, OPS-010 | Client Portal | `*-CPORT-001..002` × CORE 2, ERP 1, PORTAL 2, MPO 1 (7) | ✅ Đầy đủ | REQ-FIN-017 đúng 2 spec theo registry |
| OPS-011 | TikTok Shop Monitoring | `*-TIKTOK-001` × CORE/GW/ERP/MBI (4) | ✅ Đầy đủ | |

**Đủ user stories/AC:** toàn bộ 170 file có đủ 5 section bắt buộc (`## 2. Luồng Người Dùng`, `## 3. Quy Tắc Nghiệp Vụ`, `## 4. Phân Quyền`, `## 6. Trạng Thái`, `## 8. Acceptance Criteria`); 6 spec spot-check có 6–9 user stories và 5–9 AC testable, có dòng map SC → REQ. Không phát hiện REQ nào chỉ có backend mà thiếu UI trái với `systems[]` — các REQ 2-system (chỉ CORE+ERP) đúng chuẩn headless + web thao tác.

### B.2. Kiểm Tra Trùng Lặp Feature

| Feature A | Feature B | Điểm trùng lặp | Đánh giá | Hành động |
|-----------|-----------|----------------|----------|-----------|
| FEAT-ERP-HRCORE-003 (chấm công) | FEAT-*-CAPTS-002 (timesheet dự án) | Đều ghi giờ làm của nhân viên | Tương tự nhưng **đã tách bạch tường minh** (HR: BR-008 "chấm công không tự suy ra chi phí"; phạm vi loại trừ ghi đối ứng) | Giữ riêng — không gộp |
| FEAT-CORE-WALLET-001 (ledger) | 6 counterpart cùng REQ khác system | Cùng domain ví | Không trùng — mỗi bản đúng 1 touchpoint, phạm vi loại trừ trỏ đúng counterpart (CORE: "không bao gồm UI"; PORTAL: "read-only tuyệt đối") | Giữ riêng |
| FEAT-ERP-CPORT-001 / FEAT-PORTAL-CPORT-001..002 | CPORT CORE 001..002 | Portal account & view | Phân vai đúng: CORE cấp view/API, ERP cấp tài khoản OPS, PORTAL/MPO bề mặt khách | Giữ riêng |

Kết luận: **0 trùng lặp thật**. Fan-out đa system là thiết kế chủ đích, ranh giới scope được mỗi spec tự khai ở mục "Không bao gồm".

### B.3. Kiểm Tra Business Rules Xung Đột

| Business Rule | Feature A | Feature B | Điểm xung đột | Đề xuất |
|---------------|-----------|-----------|---------------|---------|
| Ánh xạ vai SM (ký Gate, duyệt GM, dashboard nhóm) | CRM specs (6 file): SM = **SALES_L4 (TPKD)** theo KXN-14 chốt 12/09 | Commission-quota, Quotation-DealDesk, TikTok Shop (6 file): SM = **SALES_L3 (TNKD)** | **Xung đột quyền duyệt giữa 2 mức L3/L4** — ai ký Gate 2 TikTok, ai duyệt quota/clawback | **H-01 — Sửa 6 file về SM = SALES_L4; đồng bộ sales.md A1** *(→ đã thực hiện, mở rộng thành 9 file — xem A.3)* |
| Dual approval DUAL tuần tự FIN_L1 → FIN_L2, cấm 1 người cả 2 bước | CORE-WALLET-001 | PORTAL/MPO-WALLET-001 | Không xung đột — mô tả đồng nhất | Không cần |
| Dung sai đối trừ 3 số (0/dòng; ≤0,5%/10 USD; ≤1%/20 USD), công thức k, SLA đỏ 2h + escalation owner→TL→AM, ngưỡng duyệt 5/50/200 triệu | CORE-WALLET/ARAP | PORTAL, MPO, ERP counterparts | Không xung đột — số liệu copy nhất quán từ DI-001 | Không cần |

---

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

> Người thực hiện: business-analyst | Ngày: 12/09/2026
> **Cập nhật 12/09/2026 sau auto-correction iteration 1:** bảng finding giữ nguyên văn kết quả review; trạng thái hiện hành của H-01, M-01..M-04, L-01, L-02 tổng hợp tại mục A.3.

### C.1. Nhất Quán Với Phase 1 Requirements

| FEAT-ID | REQ-IDs tham chiếu | Dept docs mô tả khớp? | Ghi chú |
|---------|--------------------|-----------------------|---------|
| FEAT-CORE-WALLET-001 | REQ-FIN-001 | ✅ | Tiền giữ hộ = liability, vòng lệnh 5 bước, công tắc SINGLE/DUAL, công thức k 2 chiều — bám finance.md + CMS §3.5/3.6/§5 |
| FEAT-ERP-CRM-003 | REQ-SALES-003 | ✅ | Knockout K1–K5 tuyệt đối, flag K6–K12, ngưỡng 1.5/2.0/3.0/3.5, trọng số 30/25/20/15/10 — khớp sales.md + phụ lục 09 v1.1 |
| FEAT-CORE-RBAC-005 | REQ-BOD-011 | ✅ logic / ⚠️ văn bản | SSO 2 realms, MFA TOTP, 18 vai registry đúng — nhưng có ≥5 câu lỗi từ ngữ (M-03) |
| FEAT-ERP-HRCORE-003 | REQ-HR-003 | ✅ | Trần 48h/200h BLLĐ 2019, OT duyệt trước, retro 24h, chế tài §8 — khớp hr.md; "mobile ghi công ngoài scope" khớp registry |
| FEAT-PORTAL-WALLET-001 | REQ-OPS-003 (+FIN-002/017) | ✅ | Read-only, mask giá vốn, watermark, disclaimer độ trễ — đúng biên REQ-FIN-017 |
| FEAT-MPO-WALLET-001 | REQ-OPS-003 (+FIN-002/017) | ✅ | Bản rút gọn nhất quán với PORTAL; push ≤5 phút, không số dư trên lock screen |

**Đánh giá assumptions `[KXN-n]`** — mọi spec có kỷ luật tagging tốt (kèm mệnh đề "không tự quyết, cấu hình hóa"), không phát hiện KXN nào bị spec tự ý chốt hộ. Tần suất nhắc (gồm câu disclaimer chuẩn cuối spec) và nhóm cần chủ dự án chốt sớm:

| Nhóm | Mã (số nhắc) | Chặn điều gì | Ưu tiên chốt |
|------|--------------|--------------|--------------|
| Vai & RACI | KXN-12 AD (14), KXN-14 SM (4 + 6 file lệch), KXN-19 RACI (46) | Ma trận phân quyền Phase 5; đã gây H-01 | **Cao** |
| Sales gates/proposal | KXN-5 (36, P0), KXN-8 (25, P0), KXN-6 (30), KXN-7 (25), KXN-20 (41), KXN-17/21 (26) | Cấu hình rule engine scoring, template proposal, knockout bổ sung | **Cao** (KXN-5/8 là P0 còn mở; KXN-1/2 đã chốt) |
| Ví & vận hành | KXN-22 PAUSE 15/30 (44), KXN-9 scope hiện tại/tương lai (37), KXN-10 (29, P0), KXN-11 (24, P0) | Hành động tự động khi non-payment; biên scope CMS | **Cao** (đã có safe-guard "chỉ cảnh báo nội bộ khi chưa chốt") |
| HR | KXN-18 (23), KXN-DTS delegate TL (6 file hr-core) | Luồng delegate duyệt timesheet/phép | Trung bình |

### C.2. Nhất Quán Về Entity & Data Types

| Entity | Feature A gọi là | Feature B gọi là | Thống nhất? | Tên chuẩn |
|--------|-----------------|-----------------|------------|-----------|
| View số dư cho khách | `PortalBalanceView` (CORE-WALLET-001: `wallet_balance`, `daily_spend`, `as_of`) | `PortalWalletView` (PORTAL/MPO/GW-WALLET-001: `balance_by_currency`, `days_of_runway`, `alert_level`, `data_source`) | ❌ | **M-01** — chuẩn hóa tại `technical-specs/database-design.md` Phase 3 |
| Trường số dư Wallet | `available_balance`/`frozen_balance` (CORE — snake_case) | `availableBalance`/`frozenBalance` (PORTAL/MPO — camelCase) | ❌ | Gộp vào M-01 |
| `WalletTransaction.type` | NẠP/CHI TIÊU/PHÍ/ĐIỀU CHỈNH/HOÀN | recharge/topup/reduction/adjustment/refund | ❌ (đặt tên, không lệch ngữ nghĩa) | Gộp vào M-01 |
| State machine lệnh ví (`PENDING→STEP1_APPROVED→APPROVED/REJECTED/DISPUTED`) | CORE-WALLET-001 | PORTAL/MPO-WALLET-001 | ✅ | Đồng nhất từng trạng thái và điều kiện |
| Dung sai đối trừ, công thức k, Rebate TẮT, UBO ≥25% | CORE | PORTAL/MPO/GW | ✅ | Số liệu đồng nhất tuyệt đối |

### C.3. Nhất Quán Về Permissions

| Vai trò | Feature A cho phép | Feature B cho phép | Khớp? | Ghi chú |
|---------|-------------------|--------------------|-------|---------|
| SM | CRM specs: ký Gate 1/Gate 2, duyệt bypass = **SALES_L4** (KXN-14) | TikTok Shop: "SALES_L3 (SM — ký Gate 2)"; Commission: dashboard nhóm của SM ở L3; Quotation: "SALES_L3 (SM/TNKD)" | ❌ | **H-01** — 6 file cần sửa; rủi ro cao nhất: ai có chữ ký Gate 2 go-live TikTok *(→ đã sửa 9 file, xem A.3)* |
| OPS_AD vs OPS_ADS vs OPS_AM | 13 file dùng `OPS_AD` (Account Director — WARN-2) làm escalation cuối khi AM vắng; quy ước OPS_ADS = Ads Specialist được tôn trọng nhất quán | Registry 18 vai **không có** OPS_AD; các spec đều tự tag `[KXN-12]` "chờ đồng bộ registry" và giới hạn AD là listener, không cấp quyền mới | ⚠️ | **M-02** — specs có kỷ luật nhưng là "vai ma": nếu Phase 5 quên nạp OPS_AD, chuỗi escalation AM→AD gãy; cần chốt KXN-12 + nạp registry trước Phase 5 |
| 18 vai registry (WARN-1) | Không spec nào gán quyền cho OPS_CX/FIN_COMPL — 4 chỗ grep chỉ là câu "KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006)" | Xác nhận triage: FALSE POSITIVE | ✅ | Không cần sửa |
| FIN_L1 tự duyệt lệnh do chính mình tạo (mode SINGLE) | CORE-WALLET-001 ma trận: FIN_L1 ✅ "Tạo lệnh" + ✅ "Duyệt — SINGLE" + ✅ "Đối chiếu/ghi sổ" | BR-W08 SoD chỉ ràng buộc gián tiếp ("một người không giữ ≥2 vai trong chuỗi"); bảng trạng thái chỉ cấm tự duyệt 2 bước DUAL | ⚠️ | **M-04** — bổ sung dòng ❌ "tự duyệt lệnh do chính mình tạo (kể cả SINGLE)" vào ma trận + bảng chuyển đổi *(→ đã thêm BR-W08a, xem A.3)* |
| CUSTOMER trên portal/mobile | ❌ mọi quyền ghi (read-only tuyệt đối, nút duyệt không tồn tại) | PORTAL, MPO, RBAC-005 (realm riêng, không role nội bộ) | ✅ | |

### C.4. Nhất Quán Về FEAT-ID Format

| FEAT-ID | Format đúng? | Ghi chú |
|---------|-------------|---------|
| 170/170 FEAT-ID | ✅ | Đúng `FEAT-[SYS]-[MOD]-[NNN]`, 0 trùng lặp; prefix hệ thống nhất quán (CORE/ERP/GW/MBI/PORTAL/MPO) |
| Ánh xạ prefix ↔ system | ✅ | ERP = SYS-BCERP-WEB, MBI = SYS-MOBILE-INTERNAL, MPO = SYS-MOBILE-PORTAL — cần ghi 1 dòng vào `_meta` để Phase 3 tra nhanh (không phải lỗi) |

### C.5. Phụ Thuộc Xuyên Feature (Cross-Feature Dependencies)

| Feature | Phụ thuộc vào | Mô tả phụ thuộc | Đã ghi trong spec? | Ghi chú |
|---------|--------------|-----------------|-------------------|---------|
| FEAT-CORE-WALLET-001..007 | 001 là nền ledger | 002–007 đều đọc ledger 001 | ✅ (mục Phụ thuộc + phạm vi) | |
| FEAT-MPO-WALLET-001 | FEAT-PORTAL-WALLET-001 | Dùng chung view; deep-link tải PDF | ✅ | |
| FEAT-CORE-RBAC-005 | (được phụ thuộc ngược) | RBAC-001/002/003/006/007 + mọi phân hệ | ✅ (BR-012 cấm dựng RBAC riêng) | |
| 147 feature (tổng 378 cross-FEAT refs) | — | Suggestions CF6 headless | ⚠️ Chưa ghi registry | **L-01** — stakeholder accept để Phase 5 ghi `cross_feat_refs[]`; hiện nằm `deferred-findings.md` |

### C.6. Tổng Kết Consistency Check

**Số vấn đề phát hiện:**

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Không khớp Phase 1 requirements (kể cả ánh xạ vai lệch nguồn sales.md) | 1 | — | 1 (H-01) | — | — |
| Entity / Data type không nhất quán | 1 | — | — | 1 (M-01) | — |
| Permissions không nhất quán / vai ngoài registry / gap SoD | 2 | — | — | 2 (M-02, M-04) | — |
| FEAT-ID format sai | 0 | — | — | — | — |
| Cross-feature dependencies chưa chấp nhận (CF6) | 1 | — | — | — | 1 (L-01) |
| Chất lượng văn bản spec (lỗi từ ngữ/câu ghép sai) | 2 | — | — | 1 (M-03: FEAT-CORE-RBAC-005 "tin quyết quyền", "cho duyệt mobile", "cung cấp realm + policy", "liên quan ≤24h", state `AUTO_DISABLED` không có trong bảng chuyển đổi; BR-011 mobile-portal "screenshot app switcher lộ số dư") | 1 (L-02: mã BR tự đặt không thống nhất giữa module — BR-W01 vs BR-SALES-301 vs BR-001 — nên quy ước chung để trace về BR nguồn dạng BR-FIN-101) |
| **Tổng** | **7** | **0** | **1** | **4** | **2** |

**Kết luận:** Bộ 170 spec **nhất quán tốt ở mức nền tảng** — coverage 59/59 tuyệt đối, các con số kinh doanh nhạy cảm (công thức k, dung sai đối trừ, ngưỡng 5/50/200 triệu, SLA 2h, DUAL FIN_L1→FIN_L2, tier A–E, Gate 1/2, "tiền giữ hộ", Hard Stop) đồng nhất xuyên counterparts. Rủi ro duy nhất mức High là **ánh xạ vai SM (H-01)** — lỗi kế thừa từ sales.md A1, lan vào 6 file thuộc 3 module khác nhau, chạm tới quyền ký Gate và duyệt tài chính; đợt sửa nhỏ (sửa actor line + bảng phân quyền của 6 file, đồng bộ sales.md A1), không đụng cấu trúc spec. *(Cập nhật: H-01 đã sửa xong ở đợt auto-correction iteration 1 — mở rộng thành 9 file, xem A.3.)*

**Đề xuất verdict:** **APPROVED_WITH_CONDITIONS** — với điều kiện bắt buộc: (1) sửa xong H-01 trước khi Phase 3 khởi tạo kiến trúc phân hệ SALES/OPS; (2) chủ dự án chốt nhóm KXN ưu tiên Cao (KXN-12/14/19 + P0 còn mở: KXN-5/8/10/11) trước Phase 5 nạp vai; (3) M-01..M-04, L-01..L-02 ghi DEFERRED vào `deferred-findings.md` với consumer tương ứng (M-01 → Phase 3 database-design; M-02 → Phase 5 registry; L-01 → stakeholder accept CF6). Nếu H-01 chưa sửa khi chuyển Phase 3 → verdict rơi về REJECTED theo quy tắc "PENDING High". *(Cập nhật: H-01 đã RESOLVED — điều kiện (1) thỏa.)*

**Hành động ưu tiên cao nhất:**

1. **H-01:** chuẩn hóa SM = SALES_L4 trong 6 file (bcerp-web/commission-quota, mobile-internal/commission-quota, mobile-internal/quotation-dealdesk ×2, bcerp-web/quotation-dealdesk, core-backend/tiktok-shop) + cập nhật sales.md A1. *(→ ĐÃ XONG — thực thi mở rộng 9 file, grep sạch.)*
2. **M-02:** chốt KXN-12 và nạp/quyết định không nạp OPS_AD vào registry 18 vai trước Phase 5. *(→ KXN-12 đã chốt 12/09; nạp registry thực thi tại Phase 5.)*
3. **M-01:** Phase 3 chốt tên chuẩn view số dư portal + quy ước đặt tên trường (snake_case hay camelCase) trong `database-design.md`.

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Người thực hiện: product-expert (DEVKIT MCV3) | Ngày: 12/09/2026
> **Cập nhật 12/09/2026 sau auto-correction iteration 1:** bảng finding giữ nguyên văn kết quả review; trạng thái hiện hành của F-D1-1..F-D4-2 tổng hợp tại mục A.3 (F-D3-1 RESOLVED cùng H-01; F-D4-1 chờ thực thi Phase 5; F-D3-3 RESOLVED ở mức spec; F-D3-2 DEFERRED by-design).
> **Cơ sở đánh giá:** `feature-briefs.json` (170 briefs — nguồn chính), `req-registry.json` (59 REQ / 19 MOD / 6 SYS), `phase1-handoff.json` (dept summaries + 16 business_rule_keywords + cross_department_dependencies), `cross-validation-report.md` (PASS_WITH_WARN). Spot-check nguyên văn 5 spec đại diện khác module/system: FEAT-PORTAL-CPORT-001 (`portal-web/client-portal/du-lieu-vi-read-only-cho-client-portal.md`), FEAT-GW-STGW-002 (`integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md`), FEAT-CORE-CAPTS-001 (`core-backend/capacity-timesheet/duyet-timesheet-va-capacity-phoi-hop-ops.md`), `bcerp-web/crm-pipeline/auto-scoring-k1-k12-va-tier-a-e.md`, `bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md`; kèm trích verbatim `mobile-portal/wallet-recon/`, `commission-quota`, `sla-notif`.

### D.1. Gap Về Requirements Coverage

Kết quả quét: **59/59 REQ đều có ≥1 FEAT** (khớp check 3.1 của cross-validation); fan-out đúng theo `systems[]` của registry: 170 = 58 WEB + 59 CORE + 11 GW + 30 M-INT + 5 M-PORTAL + 7 PORTAL. Độ sâu spot-check đồng đều (mỗi spec 180–200 dòng, đủ 9 section, mỗi BR có cột "Khi vi phạm thì...", AC map về REQ) — không có spec "vỏ rỗng". Không phát hiện REQ nào bị map nhưng spec bỏ trống phạm vi chính. Gap phạm vi duy nhất mang tính ghi chú:

| REQ-ID | Mô tả | Priority | Hành động |
|--------|-------|----------|-----------|
| REQ-FIN-015 | Dashboard & báo cáo TC nội bộ: `REQ.phase=Phase2` nhưng `primary_module` MOD-DATAHUB-BI `phase=Phase3` | Low | Ghi chú lệch phase khi populate `features[]` (spec đã tự xử lý đúng: GĐ2, star schema mở rộng để dành GĐ3) — F-D1-1, Auto-fixable |

### D.2. Gap Về User Stories

| FEAT-ID | Thiếu gì | Mức ảnh hưởng | Hành động |
|---------|---------|--------------|-----------|
| Spec M-PORTAL (5 file) | Vòng đời phiên trên app store riêng: device binding, mất thiết bị, rotate push token — hiện kế thừa OTP realm của portal-web (FEAT portal RBAC đã đặc tả OTP qua kênh đã KYC) | Low | DEFER sang `/wf-design` (integration-map auth) — F-D2-1 |

Đã xác minh **tốt, không phải gap** (3 nhóm đặc biệt trong phạm vi nhiệm vụ):
- **CUSTOMER trên portal:** FEAT-PORTAL-CPORT-001 có 7/10 user story là CUSTOMER (CLIENT_USER/CLIENT_ADMIN) kèm ma trận phân quyền riêng; các spec portal ticket/SLA/campaign/ví tương tự. Lưu ý: `actors[]` của phase1-handoff chỉ có 18 vai nội bộ — vai khách được specs lấy đúng từ `systems[].user_roles` của registry, không tự chế vai.
- **Mobile offline:** 30/30 spec M-INT có offline-capable có kiểm soát (snapshot gắn nhãn thời điểm; ký đã qua MFA xếp hàng đồng bộ, máy chủ đối chiếu version — chặn ghi 2 lần). M-PORTAL chủ đích **không** offline-capable đầy đủ (cache read-only gắn nhãn "dữ liệu cũ", cấm ghi từ cache — BR-MP-013/BR-MPO-CAMP-007); đây là quyết định thiết kế đã ghi rõ, không phải thiếu sót.
- **Degraded mode:** FEAT-GW-STGW-002 đặc tả khởi điểm `manual` toàn 7 nền tảng (DI-007), 2 kênh nhập chuẩn chặn schema, backfill không ghi đè bản ghi manual, hạ tuần nguồn không có API statement.

### D.3. Gap Về Business Rules

**16/16 business_rule_keywords của handoff đều xuất hiện đúng chỗ** (kiểm tra placement trên nguyên văn, không chỉ đếm thô): Financial Hard Stop (50 file — wallet + adaccount-cc, không override); tiền giữ hộ (43); SoD 4 vai (24 — định nghĩa chuẩn "đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ" trong spec duyệt chi); hash-chain/WORM (65/80); tier A–E (18 — **nhất quán A thấp nhất/E cao nhất, khớp operations.md dòng 187; không phải lỗi đảo chiều với CRM**); Gate 1/Gate 2 + nạp trước 100% NSQC + SLA 1 ngày/4h (30); SLA 4h (42); clawback (8 — đúng chỗ: commission + cờ AR >90 ngày); Brand Safety 7 tiêu chí (19); degraded manual (64); billable tại nguồn (10 — đúng FEAT ghi nhận tại nguồn, FEAT duyệt chỉ đọc gate); cost rate version (31 — SCD2, duyệt 3 chặn HR_L2 → FIN_L2 → BOD); tenant isolation (93); pre-alert 80% + GMT+7 (4/5 sla-notif, M-PORTAL nhận hiển thị).

| Business Rule | Nguồn | Feature liên quan | Hành động |
|---------------|-------|-------------------|-----------|
| F-D3-1 (High, Auto-fixable): **SM = SALES_L3 trong 5 spec, mâu thuẫn KXN-14 đã chốt SM = SALES_L4 (TPKD)** — sai chủ thể ký tại Gate 2/Handoff (BR-HONB-103/202, state machine `SUBMITTED→SM ký`, BR-SALES-904 quota). File: `bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md`, `bcerp-web/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md`, `core-backend/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md`, `bcerp-web/commission-quota/commission-va-quota-...md`, `core-backend/tiktok-shop/tiktok-shop-monitoring.md` | KXN-14; sales.md | MOD-HANDOFF-ONBOARD, MOD-COMMISSION-QUOTA, MOD-TIKTOK-SHOP | **WARN-3 của cross-validation xác nhận LÀ THỰC — sửa ngay Phase 2** (thay SALES_L3 → SALES_L4, rà đoạn ghi chú lệch), không chờ Phase 4 vì dính quyền ký *(→ ĐÃ SỬA cùng đợt H-01, grep sạch — xem A.3)* |
| F-D3-2 (Medium, Auto-fixable): **114 marker [CẦN CHỐT SỐ] + nhiều [KXN] chờ xác nhận nằm trong BR load-bearing**: người duyệt timesheet cấp TL (SO3-09/DI-006), danh sách K6–K12 (KXN-20), knockout AML/FATF/UBO, mốc cảnh báo 15/30 ngày portal (KXN-22), giờ chuẩn §8 vs JD | phase1 + dept docs | Nhiều module | Biên soạn checklist tổng hợp (grep được) trình stakeholder chốt trước sign-off Phase 2 *(→ DEFERRED by-design: assumption có tag theo nguyên tắc "không tự quyết"; nhóm KXN ưu tiên chốt sớm: KXN-12/14/19, KXN-5/8/10/11/20, KXN-22/9 — xem A.3)* |
| F-D3-3 (Medium, DEFERRED): **WARN-2 OPS_AD vs OPS_ADS** — 170 spec dùng lẫn 2 vai | cross-validation 3.6 | Toàn lane | Giữ triage gốc: chờ quyết định registry (có nạp thêm vai OPS_AD không) tại Phase 5 rồi chuẩn hóa *(→ Kết quả triage: specs dùng nhất quán + tag `[KXN-12]` — RESOLVED ở mức spec; nạp registry theo M-02 tại Phase 5 — xem A.3)* |

### D.4. Gap Về REQ → FEAT Mapping Completeness

| REQ-ID | Mô tả | FEAT-ID tương ứng | Ánh xạ đầy đủ? | Hành động |
|--------|-------|------------------|---------------|-----------|
| 59/59 REQ | Mỗi REQ có ≥1 FEAT trong briefs | Theo `feature-briefs.json` | ✅ | — |
| F-D4-1 (High, Auto-fixable) | **`req-registry.json` chưa nhận mapping: `features[] = []`, `counters.FEAT = 0`** dù 170 spec đã viết — checklist "req-registry.json đã cập nhật features[]" chưa thỏa; P3-01 đọc registry để lập kiến trúc | Toàn bộ 170 FEAT | ❌ (ở mức registry) | Populate `features[]` từ `feature-briefs.json` (feat_id/system/module/req_ids/output_path đã đủ) *(→ RESOLVED — chờ thực thi Phase 5 trong cùng run, xem A.3)* |
| F-D4-2 (Low, Auto-fixable) | 378 cross-FEAT refs nằm `deferred-findings.md` chờ stakeholder accept (CF6); W4.7 skip do registry thiếu field `cross_module_dependencies` | — | ⚠️ | Khi populate, nhập các ref đã accept + bổ sung field *(→ DEFERRED — chờ stakeholder accept, xem A.3)* |

### D.5. Gap Về Edge Cases & Error Handling

Spot-check cho thấy lớp edge case mạnh: xung đột sync offline (đối chiếu version, kết quả "không áp dụng" thay vì ghi đè); backfill chồng kỳ đã chốt (không tự sửa số chốt → ticket discrepancy `[KXN-15]`); đa tiền tệ (gateway lưu gốc, core snapshot quy đổi); đa nhãn hàng = tenant riêng; import nhận dòng hợp lệ + báo lỗi từng dòng. Không phát hiện edge case nghiệp vụ thiếu ở mức Phase 2.

| FEAT-ID | Edge case thiếu | Mức ảnh hưởng | Hành động |
|---------|----------------|--------------|-----------|
| Spec M-PORTAL | Xem F-D2-1 (auth/session mobile) | Low | DEFER `/wf-design` |
| Nhóm NFR domain — **DEFER sang `/wf-design`** (liệt kê rõ): hiệu năng/scale (registry 2.600+ TKQC, latency P&L realtime, freshness SLA kỹ thuật); availability/DR (RPO/RTO); WORM ≥10 năm là hạ tầng storage; RLS + mã hóa at rest/in transit; cấu hình Keycloak 2 realms + MFA step-up; idempotency/exactly-once cho ledger ví; cơ chế hash-chain + key rotation; sync protocol mobile (backoff/conflict); hạ tầng push notification; e-sign provider; connector VAS; OAuth per-client TikTok; rate-limit quota từng nền tảng; PDPA/GDPR data-residency chi tiết | Medium (khối) | `P3-01-architecture.md` + `technical-specs/` |

### D.6. Checklist Tính Năng Ngầm Định

| STT | Tính năng | Đã có feature spec? | Ghi chú |
|-----|----------|--------------------|---------|
| 1 | Phân quyền truy cập per feature | ✅ | Mọi spec có mục Phân quyền + role re-check tại service layer |
| 2 | Validation đầu vào & thông báo lỗi | ✅ | Cột "Khi vi phạm thì..." trên mọi BR |
| 3 | Empty state (danh sách trống) | 🔄 N/A Phase 2 | Thuộc Phase 4 UX |
| 4 | Loading / skeleton state | 🔄 N/A Phase 2 | Thuộc Phase 4 UX |
| 5 | Audit trail / lịch sử thay đổi | ✅ | Append-only + hash-chain; không ai xóa/sửa kể cả SYS_ADMIN |
| 6 | Export / Import data | ✅ / N/A | Portal watermark + log; GW import schema; còn lại N/A |

### D.7. Tổng Kết Gap Analysis

**Tổng số gap phát hiện: 7**

| Loại gap | Số lượng | Critical | High | Medium | Low |
|----------|----------|----------|------|--------|-----|
| REQ chưa cover | 0 | 0 | 0 | 0 | 0 |
| Thiếu user stories / AC | 1 | 0 | 0 | 0 | 1 |
| Thiếu business rules | 3 | 0 | 1 | 2 | 0 |
| REQ → FEAT mapping thiếu | 2 | 0 | 1 | 0 | 1 |
| Thiếu edge cases / error handling (domain DEFER) | 1 | 0 | 0 | 0 | 1 |
| Tính năng ngầm định | 0 | 0 | 0 | 0 | 0 |
| **Tổng** | **7** | **0** | **2** | **2** | **3** |

Phân bổ xử lý: **5 Auto-fixable** (F-D3-1, F-D3-2 phần biên soạn, F-D4-1, F-D4-2, F-D1-1) — **2 DEFERRED** (F-D3-3, F-D2-1) cộng khối NFR domain ở D.5 ghi `deferred-findings.md` cho `/wf-design`. *(Cập nhật trạng thái sau iteration 1: xem A.3 — F-D3-1 đã sửa cùng H-01; F-D4-1 chờ thực thi Phase 5; F-D3-3 RESOLVED ở mức spec.)*

**Kết luận:** Không có gap Critical; coverage REQ→FEAT đạt 59/59 và chất lượng BR placement tốt (16/16 keyword đúng chỗ). Phần D đạt mức **APPROVED_WITH_CONDITIONS**: 2 High đều auto-fixable và bắt buộc hoàn thành trước sign-off Phase 2. *(Cập nhật: F-D3-1 đã sửa xong; F-D4-1 nằm trong Safe-Write Phase 5 cùng run.)*

**Hành động ưu tiên cao nhất:**

1. **F-D4-1** — Populate `features[]` + `counters.FEAT` vào `req-registry.json` từ `feature-briefs.json` (điều kiện để P3-01 chạy; kèm F-D4-2 nhập cross-FEAT refs đã accept và F-D1-1 ghi chú lệch phase REQ-FIN-015). *(→ Chờ thực thi Phase 5.)*
2. **F-D3-1** — Chuẩn hóa SM = SALES_L4 (theo KXN-14) tại 5 file liệt kê ở D.3; rà lại mọi câu "SM (SALES_L3)" còn sót trong lane Handoff/Commission/TikTok. *(→ ĐÃ XONG cùng đợt H-01.)*
3. **F-D3-2** — Biên soạn checklist 114 [CẦN CHỐT SỐ] + các [KXN] chờ xác nhận (ưu tiên: người duyệt timesheet cấp TL, danh sách K6–K12, knockout AML/FATF/UBO, mốc 15/30 ngày portal) trình stakeholder chốt trước khi chuyển Phase 3. *(→ DEFERRED by-design; nhóm KXN ưu tiên liệt kê tại A.3.)*

---

## Xác Nhận & Sign-Off

### Thống Kê Severity

| Mức độ | PENDING | RESOLVED | RESOLVED — chờ Phase 5 | DEFERRED | Tổng |
|--------|---------|----------|------------------------|----------|------|
| Critical | 0 | 0 | 0 | 0 | 0 |
| High | 0 | 2 (H-01, F-D3-1) | 1 (F-D4-1 — Safe-Write registry) | 0 | 3 |
| Medium | 0 | 3 (M-03, M-04, F-D3-3) | 1 (M-02 — nạp OPS_AD) | 2 (M-01, F-D3-2) | 6 |
| Low | 0 | 0 | 0 | 5 (L-01, L-02, F-D1-1, F-D2-1, F-D4-2) | 5 |
| **Tổng** | **0** | **5** | **2** | **7** | **14** |

> F-D4-1 và M-02 đã hoàn tất phần việc thuộc specs/iteration 1; hành động còn lại (Safe-Write `features[]`, nạp vai OPS_AD vào registry 18 vai theo KXN-12 đã chốt 12/09) là việc của Phase 5 trong cùng run — không phải gap của specs, không tính PENDING.

### Đánh Giá Tổng Thể

| Kết quả | Điều kiện | Hành động tiếp theo |
|---------|-----------|---------------------|
| **APPROVED** | Zero Critical/High open (PENDING) | Chuyển sang Phase 3 |
| **APPROVED_WITH_CONDITIONS** | Zero PENDING Critical/High, nhưng có DEFERRED | Chuyển Phase 3, DEFERRED ghi vào `deferred-findings.md` |
| **REJECTED** | Có PENDING Critical hoặc High | DỪNG — phải fix trước khi chuyển Phase 3 |

**Kết quả đánh giá:** ☑ **APPROVED_WITH_CONDITIONS**

**Điều kiện kèm verdict:**
1. **0 Critical, 0 High PENDING** — H-01 (và F-D3-1 trùng nội dung) đã RESOLVED qua auto-correction iteration 1 (9 file / 40+ vị trí, grep sạch); F-D4-1 resolves tại Phase 5 (Safe-Write 170 `features[]` trước khi P3-01 đọc registry).
2. **Phase 5 (cùng run) bắt buộc thực thi:** Safe-Write 170 `features[]` + `counters` (F-D4-1); nạp vai OPS_AD vào registry 18 vai theo KXN-12 đã chốt 12/09 (M-02); nhập cross-FEAT refs đã accept (L-01/F-D4-2); ghi chú lệch phase REQ-FIN-015 khi populate (F-D1-1).
3. **7 DEFERRED đã ghi `deferred-findings.md`** với consumer tương ứng: M-01, L-02, F-D2-1 (+ khối NFR domain D.5) → `/wf-design`; L-01/F-D4-2 → chờ stakeholder accept; F-D3-2 → checklist KXN trình stakeholder; F-D1-1 → /wf-add-scope hoặc owner registry.
4. **Nhóm KXN ưu tiên chốt sớm trước Phase 5:** KXN-12/14/19 (Vai & RACI), KXN-5/8/10/11/20 (Sales gates), KXN-22/9 (ví/CMS).

### Checklist Xác Nhận Phase 2 Hoàn Thành

```
[x] Tất cả feature specs đã hoàn thành (170/170)
[x] Mỗi REQ-ID trong registry có ít nhất 1 feature spec tương ứng (59/59)
[x] Phần B (Feature Cross-Review) — hoàn thành
[x] Phần C (Consistency Check) — hoàn thành, đã sửa tất cả inconsistency sửa được ở Phase 2 (H-01, M-03, M-04)
[x] Phần D (Gap Analysis) — hoàn thành, không còn gap nghiêm trọng
[x] Tổng hợp vấn đề (mục A.3) — 0 PENDING Critical/High; 5 RESOLVED + 2 chờ Phase 5 + 7 DEFERRED
[x] Tài liệu gốc đã được cập nhật theo kết quả review (auto-correction iteration 1)
[ ] req-registry.json đã cập nhật features[] — chờ Safe-Write Phase 5 (F-D4-1, M-02) trong cùng run
[x] DEFERRED items (7) đã ghi vào deferred-findings.md
```

**Ngày xác nhận Phase 2 hoàn thành:** 12/09/2026 (APPROVED_WITH_CONDITIONS — điều kiện Phase 5 thực thi Safe-Write registry trong cùng run trước khi `/wf-design` khởi động).

**Người xác nhận:**

| Vai trò | Họ tên | Chữ ký / Xác nhận | Ngày | Trạng thái |
|---------|--------|-------------------|------|------------|
| Product Owner | Chờ stakeholder ký | | | ☐ Approved / ☐ Rejected |
| Tech Lead | Chờ stakeholder ký | | | ☐ Approved / ☐ Rejected |

> **Quy tắc:** Tất cả reviewers PHẢI approve trước khi chuyển sang `/wf-design`.
