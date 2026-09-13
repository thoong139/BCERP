# Architecture Draft — SYS-CORE-BACKEND (Core Backend)

> Session 20260913-053848-f4d7 | Lane: core-backend | $APPROACH = Platform Design, LEGACY_MODE=false (greenfield)
> Baseline: business-context.md v4.1 + feature-digest.md §SYS-CORE-BACKEND. Scope guard CORE-006: chỉ thiết kế MOD-RBAC-AUDIT + MOD-DATAHUB-BI.

## 1. Vai trò nền tảng trong platform + biên giới

SYS-CORE-BACKEND là **nền tảng của platform BCERP** gồm 6 systems. Nó giữ 2 trách nhiệm nền:

1. **MOD-RBAC-AUDIT — lớp Identity & Trust**: identity provider + RBAC/SSO/MFA tập trung (REQ-BOD-011), policy enforcement cho mọi system, audit log WORM 10 năm (REQ-FIN-012), quarterly access review (REQ-BOD-007), bảo vệ PII lương Confidential/Restricted (REQ-HR-010). Đây là cross-cutting concern: BCERP-WEB, MOBILE-INTERNAL, PORTAL-WEB, MOBILE-PORTAL, INTEGRATION-GW đều là Relying Party.
2. **MOD-DATAHUB-BI — lớp Data & Insight**: Data Integration Hub ingest ETL/CDC từ **mọi** business module (19 modules, gồm cả dữ liệu platform qua GW), P&L realtime (REQ-BOD-003, REQ-FIN-016 — FIN là nguồn số, BOD tiêu thụ), BI dashboard điều hành (REQ-BOD-004, REQ-FIN-015), alert center (REQ-BOD-006).

**Biên giới (không làm gì):** Core Backend KHÔNG sở hữu business object nào (lead, hợp đồng, TKQC, ví, hóa đơn, campaign...) — các object đó thuộc module gốc ở các lane khác. Trong 59 feature touchpoints của system này, 47 touchpoint thuộc 15 business module chỉ là điểm Neo để RBAC enforce + DataHub ingest; thiết kế canonical của chúng do lane của module đó chịu trách nhiệm. Core Backend cũng KHÔNG quản lý credentials kết nối ngoài (thuộc MOD-SETTINGS-GW) và KHÔNG điều phối notification đa kênh (thuộc MOD-SLA-NOTIF).

## 2. Components & trách nhiệm

| component_id | Module | Type | Trách nhiệm chính | Dependencies |
|---|---|---|---|---|
| COMP-CORE-001 | RBAC-AUDIT | service | Identity & SSO/MFA: OIDC/OAuth2 provider, token lifecycle, MFA step-up, session revoke tập trung | 002, 004 |
| COMP-CORE-002 | RBAC-AUDIT | service | RBAC & Policy Engine (PDP): ma trận role×permission×dept×data-scope, SoD, ngưỡng duyệt, compensating control kiêm nhiệm | 001, 004, 006 |
| COMP-CORE-003 | RBAC-AUDIT | worker | Quarterly access review + recertification tự động, đóng gói bằng chứng | 001, 002, 004, GW |
| COMP-CORE-004 | RBAC-AUDIT | service | Audit Log Service append-only: hash-chain, truy xuất có kiểm soát, activity timeline | 002, 005 |
| COMP-CORE-005 | RBAC-AUDIT | store | WORM Evidence Store: bất biến ≥10 năm cho log tiền + chứng từ (REQ-FIN-012) | — |
| COMP-CORE-006 | RBAC-AUDIT | service | PII Field Protection: field-level encryption, masking theo vai, classification registry | 002, 004 |
| COMP-CORE-007 | DATAHUB-BI | pipeline | CDC/ETL Ingest: CDC + event + pull qua GW, contract-first, degraded manual import | 008, 006, GW |
| COMP-CORE-008 | DATAHUB-BI | store | Analytics Warehouse: raw → staged → marts + reconcile trước publish | 007 |
| COMP-CORE-009 | DATAHUB-BI | worker | Realtime P&L Compute: stream aggregation, rule timesheet-chưa-duyệt, snapshot kỳ | 007, 008 |
| COMP-CORE-010 | DATAHUB-BI | service | BI Serving API: dashboard P&L/BI/báo cáo tài chính, export, authorization theo scope | 002, 008, 009 |
| COMP-CORE-011 | DATAHUB-BI | service | Alert Engine: rule-based alert center, lifecycle alert, dispatch ủy quyền cho SLANOT | 008, 009 |

## 3. Business layer

### 3.1 RBAC model

Mô hình 4 chiều **Role × Permission × Dept × Data-scope**:

- **Role:** 18 vai chuẩn hóa theo registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1/L2, FIN_L1/L2, SALES_L1–L3/L5, OPS_PLAN/OPS_AM/OPS_AD/OPS_CONT, ESS...). Không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2. [NEEDS_REVIEW: danh sách đủ 18 vai cần rút từ req-registry, digest chỉ liệt kê một phần.]
- **Permission:** dạng `resource:action` theo verb nghiệp vụ (view/approve/adjust/lock/export...), gắn state machine của object (VD approve lệnh chi chỉ hợp lệ ở state draft/dual_approval).
- **Dept:** ràng buộc phòng ban (DEPT-BOD/HR/FIN/SALES/OPS) cho vai; permission cross-dept phải khai báo tường minh.
- **Data-scope:** all / own-dept / own-objects, triển khai row-level filter cho mọi list API server-side (limit mặc định 20, max 100).

**Compensating control kiêm nhiệm CFO kiêm CTO (REQ-BOD-002):** một người giữ cả quyền tài chính độc quyền (REQ-BOD-010) lẫn quyền hạ tầng/credentials vault (REQ-BOD-008) là rủi ro SoD lớn nhất platform. Controls bắt buộc trong policy engine: (1) cờ `combined_role` kích hoạt chế độ **dual approval cứng** — mọi lệnh tiền/điều chỉnh ví cần 2 nấc duyệt khác người, người khởi tạo không bao giờ tự duyệt; (2) chi vượt 200 triệu leo lên CEO (REQ-BOD-001); (3) mọi thao tác CTO trên connections/credentials ghi audit WORM và nằm trong phạm vi quarterly access review (COMP-CORE-003); (4) BOD_CEO giám sát audit log (REQ-BOD-005). [NEEDS_REVIEW: delegate khi CFO kiêm CTO vắng — CEO thay nấc duyệt hay defer?]

**SoD chuẩn:** duyệt chi SoD 4 vai theo ngưỡng 5/50/200 triệu + delegate map; financial hard stop "đã khớp tiền" của FIN_L1 là rule policy (COMP-CORE-002) mà ADACC gọi kiểm tra trước khi active TKQC. Policy engine fail-closed với mọi action tài chính.

### 3.2 Audit/PII policy

- Mọi state transition + mọi lượt đọc PII phải sinh audit record (who/what/object/before-after/when) qua đường ghi duy nhất COMP-CORE-004; log tiền + chứng từ đẩy WORM (COMP-CORE-005) giữ ≥10 năm.
- PII lương (REQ-HR-010): classification Confidential/Restricted — field-level encryption, masking theo vai (chỉ HR_L1/L2 thấy rõ; ESS chỉ thấy thông tin cá nhân); PII không vào Analytics Warehouse dạng clear.

### 3.3 DataHub: nguồn ingest × Schedule × SLA (đề xuất)

| Nguồn (module chủ) | Kiểu ingest | Schedule đề xuất | SLA freshness đề xuất |
|---|---|---|---|
| WALLET, ARAP (FIN) | CDC/event stream | realtime | ≤5 phút (P&L) |
| CRM, QDD, HONB, COMM | CDC/event | 1–5 phút | ≤15 phút |
| CAMP, CAPTS, HR-CORE, KPI, CSKH, PROPLN, ADACC | CDC | 5–15 phút | ≤1 giờ |
| Platform API 7 nền tảng + VAS kế toán (qua INTEGRATION-GW) | pull batch | hourly | ≤4 giờ; degraded → manual import hàng ngày, đánh dấu nguồn thủ công |
| TIKTOK Shop (qua GW) | pull | 15–60 phút | ≤2 giờ cho anomaly |
| PORTAL / SLANOT events | event | realtime | ≤15 phút |

[NEEDS_REVIEW: toàn bộ cột Schedule/SLA là mặc định đề xuất — registry không định nghĩa con số; cần FIN/OPS xác nhận, đặc biệt freshness P&L cho REQ-FIN-016.]

## 4. Data ownership

**Core Backend SỞ HỮU:** identity store (user/credential/session), role/permission/policy catalog, audit log store + WORM evidence store, analytics warehouse (raw/staged/marts), alert registry, access-review campaign data.

**KHÔNG sở hữu:** mọi business object (Lead, Deal, TKQC, Ví, Lệnh tiền, AR/AP, Timesheet, Campaign, Ticket...). Warehouse chỉ giữ **bản sao phân tích**; nguồn sự thật luôn ở module gốc. Điều này tránh double-write và đảm bảo reconcile của DataHub có nghĩa (đối chiếu ngược nguồn). Audit log ghi **sự kiện** về business object chứ không thay thế bảng nghiệp vụ.

## 5. Giao tiếp

- **SSO/OIDC/OAuth2:** COMP-CORE-001 là IdP duy nhất; BCERP-WEB, MOBILE-INTERNAL, PORTAL-WEB, MOBILE-PORTAL, INTEGRATION-GW là Relying Party; token chứa claims role/dept/data-scope; MFA step-up bắt buộc cho action tài chính/vault.
- **Policy enforcement point (PEP):** middleware/gateway ở mọi service gọi COMP-CORE-002 (PDP) trước business logic; quyết định deny + mọi lượt access đặc quyền đều ghi audit. Business module không tự kiểm tra quyền rời rạc.
- **Ingest:** CDC từ DB các business module trong CORE-BACKEND + event stream + pull định kỳ qua INTEGRATION-GW (dữ liệu platform API, VAS, TikTok). Không gọi API đồng bộ ngược module nghiệp vụ trong request path dashboard.
- **Serving:** COMP-CORE-010 phục vụ dashboard cho BCERP-WEB + MOBILE-INTERNAL (BOD/FIN). PORTAL không dùng BI serving — ví read-only của client portal do module FIN/CLIENT-PORTAL cung cấp theo share model riêng (REQ-FIN-017).
- **Alert → notification:** COMP-CORE-011 sinh alert + quản lifecycle, đẩy dispatch qua MOD-SLA-NOTIF (kênh đa kênh + on-call DI-005).

## 6. Quy ước kỹ thuật đề xuất cho system này

- **Realtime vs batch:** luồng tiền/ví/P&L đi stream (freshness ≤5 phút); báo cáo quản trị tính batch nightly trên marts rồi reconcile với stream; lệch quá ngưỡng → alert. Dữ liệu degraded (manual import) luôn gắn cờ nguồn thủ công, không trộn vào số realtime khi reconcile.
- **Retention/WORM:** audit log tiền + chứng từ ≥10 năm WORM (REQ-FIN-012, legal hold); audit vận hành đề xuất ≥3 năm [NEEDS_REVIEW: chưa có yêu cầu trong registry]; warehouse: raw 2 năm, marts 5 năm [NEEDS_REVIEW].
- **PII:** envelope encryption field-level + KMS; masking theo vai ở API layer; tokenize/mask trước khi vào warehouse; audit mọi lượt đọc.
- **API convention chung:** list server-side pagination limit 20/max 100, filter/sort chuẩn, activity endpoint cho object có timeline — áp cho cả audit query và BI serving API.
- **Recommendation platform-level (ngoài scope 2 module):** (1) message broker dùng chung (Kafka) làm infra platform cho event/CDC — cần lane hạ tầng platform chốt; (2) mọi dispatch notification đi qua MOD-SLA-NOTIF; (3) secrets kết nối ngoài dùng credentials vault của MOD-SETTINGS-GW, kho key nội bộ (KMS) của identity/PII tách biệt.

## 7. Rủi ro & trade-offs + [NEEDS_REVIEW]

- **Kiêm nhiệm CFO+CTO:** điểm rủi ro kiểm soát nội bộ lớn nhất; compensating control (dual approval, access review, giám sát audit của CEO) giảm nhưng không loại bỏ rủi ro thông đồng một người — chấp nhận có chủ đích theo REQ-BOD-002.
- **Policy engine tập trung là single point of failure:** mitigate bằng cache quyết định TTL ngắn + replica; fail-closed với action tài chính, có thể fail-open read-only cho đọc phi nhạy cảm [NEEDS_REVIEW: chốt fail-open/closed cho luồng đọc].
- **Realtime P&L:** chi phí vận hành streaming cao; chọn freshness ≤5 phút thay vì sub-second là trade-off đủ cho điều hành và rẻ hơn đáng kể.
- **WORM 10 năm chứa PII:** audit log có dữ liệu nhạy cảm — phải mã hóa cả WORM và kiểm soát truy xuất; chi phí lưu trữ dài hạn cần dự toán.
- **Schema drift của 15 module nguồn phá vỡ ingest:** contract-first + schema registry + compatibility gate trong CI module nguồn.
- **Alert dispatch phụ thuộc SLANOT:** nếu SLANOT trễ, alert vẫn lưu state + retry ở COMP-CORE-011 — chấp nhận coupling theo scope guard.
- **[NEEDS_REVIEW] tổng hợp:** (1) danh mục đủ 18 vai; (2) phương pháp MFA (TOTP/hardware key/passkey); (3) các con số schedule/SLA ingest; (4) chốt stack hạ tầng (Kafka/ClickHouse/Keycloak/S3 object-lock) phụ thuộc quyết định platform; (5) retention audit vận hành và các lớp warehouse; (6) cơ chế delegate khi CFO kiêm CTO vắng; (7) tên stage proposal V6.0 không thuộc scope lane này nhưng DataHub ingest theo stage cần mapping khi lane OPS chốt.
