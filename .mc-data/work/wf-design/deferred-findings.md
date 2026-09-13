# Deferred Findings

> Template cho các phát hiện được hoãn lại từ skill trước sang skill sau.
> Producer: `/wf-design` (Phase 5 stakeholder review — APPROVED_WITH_CONDITIONS)
> Consumer: `/wf-plan-modules` (Phase 0) + `/wf-design-ux` (optional)

## Metadata

| Field | Value |
|-------|-------|
| **Producer Skill** | `/wf-design` |
| **Created** | 2026-09-13 |
| **Total Findings** | 13 |
| **Blocking Count** | 0 |

## Mô tả

Kết quả Stakeholder Review Phase 5: 33 findings (0 Critical / 6 High / 19 Medium / 8 Low) — 20 đã RESOLVED trực tiếp vào specs, 13 còn lại DEFERRED vì là security/NFR gap cần feature design riêng hoặc capability hạ tầng, không thể fix bằng sửa doc ở design phase. Zero PENDING. Verdict: APPROVED_WITH_CONDITIONS.

---

## Phát hiện

### DF-001: F-D-02 — Thiếu MFA recovery/lost-device

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Category** | dependency_gap |
| **Related IDs** | REQ-BOD-011, COMP-CORE-001, API-CORE (auth group) |
| **Description** | Chưa có flow recovery khi mất thiết bị MFA (khóa tài khoản không lối thoát) |
| **Impact** | Người dùng bị khóa vĩnh viễn nếu mất device; rủi ro support |
| **Suggested Action** | Feature design flow xác minh danh tính recovery riêng (không phải endpoint đơn lẻ) |
| **Resolution** | PENDING — pre-launch, sprint bảo mật, CORE owner |

### DF-002: F-D-09 — Secrets scanning + SAST trong CI

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Category** | technical_debt |
| **Related IDs** | INFRA-CORE, pipeline CI |
| **Description** | Pipeline CI chưa có secrets scanning + SAST |
| **Impact** | Rò rỉ secret/ vulnerabilities đi vào production |
| **Suggested Action** | Bổ sung pipeline CI (gitleaks/trufflehog + SAST) sprint DevOps đầu |
| **Resolution** | PENDING — pre-launch, DevOps |

### DF-003: F-D-10 — KMS DR/key escrow

| Field | Value |
|-------|-------|
| **Severity** | HIGH |
| **Category** | dependency_gap |
| **Related IDs** | COMP-GW-002, COMP-CORE-006, INFRA (KMS) |
| **Description** | Thiết kế DR cho KMS + key escrow chưa có; phụ thuộc chốt provider (NEEDS_REVIEW #11) |
| **Impact** | Mất KMS = mất toàn bộ encrypted data |
| **Suggested Action** | Thiết kế DR KMS riêng sau khi chốt provider |
| **Resolution** | PENDING — pre-launch, DevOps/Security |

### DF-004: F-C-02 — Lifecycle TikTok Shop lệch 3 nguồn

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | design_conflict |
| **Related IDs** | MOD-TIKTOK-SHOP, TBL-GW-014, business-context §2, P3-01 §9.2 |
| **Description** | Baseline §2 ≠ P3-01 §9.2 (3-Gate KXN-14) ≠ DB CHECK constraint cho lifecycle TikTok Shop |
| **Impact** | Nhầm state khi implement GW pull |
| **Suggested Action** | Owner GW/OPS xác nhận lifecycle chính thống (3-Gate) trước khi implement |
| **Resolution** | PENDING — pre-launch, sprint chốt NEEDS_REVIEW trước GW pull |

### DF-005: F-D-03 — KMS rotation + re-encrypt migration

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | technical_debt |
| **Related IDs** | COMP-CORE-006, COMP-GW-002 |
| **Description** | Rotation job + API trigger re-encrypt chưa thiết kế |
| **Impact** | Key cũ bị lộ không thu hồi được dữ liệu |
| **Suggested Action** | Thiết kế rotation job + re-encrypt migration |
| **Resolution** | PENDING — pre-launch, DevOps |

### DF-006: F-D-04 — Thiếu rate limit per-tenant

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | performance_risk |
| **Related IDs** | COMP-PORTAL-002, API-PORTAL, API-MPO |
| **Description** | Chưa enforce quota/rate limit theo tenant (phụ thuộc ma trận tier #20) |
| **Impact** | 1 tenant spam ảnh hưởng tenant khác |
| **Suggested Action** | Enforce sau khi chốt ma trận tier→quota |
| **Resolution** | PENDING — pre-launch, PORTAL/GW owner |

### DF-007: F-D-05 — Backup encryption + region chưa spec

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | dependency_gap |
| **Related IDs** | INFRA toàn platform |
| **Description** | Ràng buộc backup encrypted + data region chưa ghi vào infra-spec |
| **Impact** | Rủi ro compliance + DR |
| **Suggested Action** | Bổ sung ràng buộc vào infra spec khi chốt hosting |
| **Resolution** | PENDING — pre-launch, DevOps |

### DF-008: F-D-07 — Retention log vận hành chưa đồng đều

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | technical_debt |
| **Related IDs** | COMP-CORE-004/005, NEEDS_REVIEW #12 |
| **Description** | Retention log vận hành (không phải tiền) chưa chốt đồng bộ giữa specs |
| **Impact** | Chi phí lưu trữ + compliance không kiểm soát |
| **Suggested Action** | Chốt policy trong NEEDS_REVIEW #12 |
| **Resolution** | PENDING — pre-launch, CORE owner |

### DF-009: F-D-08 — WAF/DDoS cho BFF mobile

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | dependency_gap |
| **Related IDs** | COMP-MBI-003, COMP-MPO-002 |
| **Description** | Chưa chốt BFF mobile public hay VPN-only; WAF edge chưa có |
| **Impact** | Bề mặt tấn công mobile BFF |
| **Suggested Action** | Chốt kiến trúc truy cập rồi bổ sung WAF edge |
| **Resolution** | PENDING — pre-launch, DevOps |

### DF-010: F-D-11 — Log tamper protection app logs

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | technical_debt |
| **Related IDs** | COMP-CORE-004 |
| **Description** | Application logs (khác audit hash-chain) chưa forward về store append-only |
| **Impact** | Kẻ tấn công xóa dấu vết qua app log |
| **Suggested Action** | Forward log về store append-only |
| **Resolution** | PENDING — pre-launch, DevOps |

### DF-011: F-D-17 — Mobile root/jailbreak detection

| Field | Value |
|-------|-------|
| **Severity** | LOW |
| **Category** | technical_debt |
| **Related IDs** | COMP-MBI-001, COMP-MPO-001 |
| **Description** | Chưa có root/jailbreak detection trên mobile apps |
| **Impact** | Rủi ro thiết bị can thiệp |
| **Suggested Action** | Đưa vào thiết kế mobile chi tiết |
| **Resolution** | PENDING — sprint mobile |

### DF-012: F-D-20 — Availability critical path + SLO luồng tiền

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | performance_risk |
| **Related IDs** | COMP-CORE-002 (PDP), luồng ví/hard stop |
| **Description** | Chưa định nghĩa SLO cho luồng tiền + kịch bản cache PDP khi core chậm |
| **Impact** | Hard stop/duyệt tiền chậm = chặn vận hành |
| **Suggested Action** | Định nghĩa SLO + kịch bản cache PDP fail-safe |
| **Resolution** | PENDING — pre-launch, DevOps/Security |

### DF-013: F-D-21 — Data residency/DPIA/DPA lifecycle

| Field | Value |
|-------|-------|
| **Severity** | MEDIUM |
| **Category** | integration_concern |
| **Related IDs** | MOD-CLIENT-PORTAL, REQ-FIN-017, NĐ13/2023 + GDPR/DPA |
| **Description** | Compliance DPIA + vòng đời DPA (ký/cập nhật/hết hạn) cần feature design riêng |
| **Impact** | Portal xử lý dữ liệu khách hàng EU/VN |
| **Suggested Action** | Feature design compliance riêng |
| **Resolution** | PENDING — pre-launch, Compliance/CTO |

---

## Khuyến nghị

| # | Khuyến nghị | Ưu tiên | Ghi chú |
|---|------------|---------|---------|
| 1 | Sprint bảo mật đầu pre-launch: xử lý DF-001 (MFA recovery) + DF-002 (SAST) | HIGH | Điều kiện Phase 3 trong stakeholder-review Phần A |
| 2 | Chốt NEEDS_REVIEW #11 (KMS provider) trước khi thiết kế DF-003 | HIGH | Phụ thuộc chuỗi |
| 3 | Chốt ma trận tier→quota (#20) trước DF-006 | MEDIUM | |
| 4 | Xác nhận lifecycle TikTok Shop (DF-004) trước implement GW pull | MEDIUM | Liên quan KXN-14 |

---

## Trạng thái

| Trạng thái | Số lượng |
|-----------|---------|
| PENDING | 13 |
| Resolved | 0 |
| Escalated | 0 |

---

## Summary

| Severity | Count | Resolved |
|----------|-------|----------|
| BLOCKING | 0 | 0 |
| HIGH | 3 | 0 |
| MEDIUM | 9 | 0 |
| LOW | 1 | 0 |

## Consumer Notes

> `/wf-plan-modules` Phase 0: dùng 13 findings này làm optional input cho sprint planning — 3 HIGH là điều kiện ngầm của verdict APPROVED_WITH_CONDITIONS.
> `/wf-design-ux`: DF-006 (rate limit) + DF-013 (DPA) ảnh hưởng UX portal/mobile.
