# Architecture Draft — SYS-MOBILE-INTERNAL (Mobile App BCERP Internal)

> Session 20260913-053848-f4d7 | Lane: mobile-internal | Nguồn: business-context.md v4.1 + feature-digest §SYS-MOBILE-INTERNAL (30 FEAT touchpoints, 16 module trong registry).
> Scope guard CORE-006: KHÔNG tạo business module mới — mobile chỉ touch các module đã có. Push channel là thành phần kỹ thuật, không phải module.

## 1. Vai trò execution surface + biên giới (KHÔNG chứa business logic)

SYS-MOBILE-INTERNAL là **thin client** của BCERP: app di động nội bộ cho nhân viên BC Agency, không phải một domain system. Registry không có module mobile riêng — 30 FEAT touchpoint của lane này là **bản mobile của logic feature thuộc SYS-CORE-BACKEND / SYS-BCERP-WEB** (module owner giữ nguyên). Mobile chỉ là **execution surface**: xem (read), nhập (submit), quyết định (approve/reject), nhận báo (push).

Biên giới:

- **Có ở mobile:** UI theo vai, approval inbox, nhập liệu ESS (chấm công/đơn/timesheet), hiển thị dashboard/alert, push notification, local cache + outbox offline.
- **Không có ở mobile:** tính ngưỡng duyệt 5/50/200 triệu, SoD 4 vai, dual approval ví, số dư nghỉ phép tự động, scoring K1–K12, SLA timer, escalation, hard stop "đã khớp tiền" — tất cả nằm ở module owner phía SYS-CORE-BACKEND. Mobile không tự tính, không cache logic, không bypass (server-side enforcement tuyệt đối).
- **Mobile KHÔNG gọi trực tiếp SYS-INTEGRATION-GW**: dữ liệu 7 nền tảng (Meta/TikTok/...) do backend tổng hợp; mobile chỉ đọc kết quả.

## 2. Components & trách nhiệm

20 components, prefix COMP-MBI-NNN (chi tiết đầy đủ trong `signals.json`):

| Component | Loại | Module touch | Trách nhiệm chính |
|---|---|---|---|
| COMP-MBI-001 App Shell | app | — | Navigation role-aware, SSO/MFA bootstrap, đăng ký device + push token, offline/online strategy, versioning/force-update |
| COMP-MBI-002 Offline Sync & Cache | app | — | Outbox queue + idempotency (chỉ ESS), local cache mã hóa TTL, purge/remote wipe |
| COMP-MBI-003 Mobile BFF | bff | — | Tổng hợp view-model, shaping, pagination 20/100, dẫn state-transition endpoint về backend — không business logic |
| COMP-MBI-004 Push Consumer | push-worker | MOD-SLA-NOTIF | Nhận sự kiện SLA-NOTIF worker (BCERP-WEB) + alert center + cảnh báo ví → FCM/APNs → deep-link inbox |
| COMP-MBI-005 Approval Inbox | app | MOD-ARAP-PAYMENT | Duyệt vượt ngưỡng (REQ-BOD-001), duyệt chi/giải ngân ngưỡng + SoD + delegate (REQ-FIN-008) |
| COMP-MBI-006 Wallet Surface | app | MOD-WALLET-RECON | Sổ phụ ví, dual approval, hard stop FIN_L1, AML T1–T6, cảnh báo số dư (REQ-FIN-001/002/003/006/010, REQ-OPS-003) |
| COMP-MBI-007 BI Dashboard Mobile | app | MOD-DATAHUB-BI | P&L, BI dashboard, alert center, dashboard TC nội bộ — read-only (REQ-BOD-003/004/006, REQ-FIN-015/016) |
| COMP-MBI-008 Sales Gate Surface | app | MOD-CRM-PIPELINE | Gate 1/Gate 2 Go/No-Go (REQ-SALES-004) |
| COMP-MBI-009 Deal Desk Approval | app | MOD-QUOTATION-DEALDESK | Duyệt chiết khấu GM, e-sign HĐ/LOI/NDA (REQ-SALES-006/007) |
| COMP-MBI-010 Handoff Ack | app | MOD-HANDOFF-ONBOARD | OPS_AM ký nhận handoff, checkpoint Day 1/7/14/30 (REQ-SALES-008/REQ-OPS-004) |
| COMP-MBI-011 Commission View | app | MOD-COMMISSION-QUOTA | Xem hoa hồng/clawback/quota (REQ-SALES-009) |
| COMP-MBI-012 Ad Account Quick View | app | MOD-ADACCOUNT-CC | Tra cứu registry TKQC, alert die account (REQ-OPS-001) |
| COMP-MBI-013 Proposal Approve | app | MOD-PROPOSAL-PLANNING | Duyệt stage-gate V6.0 (REQ-OPS-005) |
| COMP-MBI-014 Campaign Checklist | app | MOD-CAMPAIGN-DELIVERABLE | Tick deliverable, nghiệm thu, nhắc SLA creative (REQ-OPS-006/012) |
| COMP-MBI-015 Timesheet Entry | app | MOD-CAPACITY-TIMESHEET | Nhập/submit timesheet (REQ-OPS-007) |
| COMP-MBI-016 ESS Mobile | app | MOD-HR-CORE | Chấm công, nghỉ phép, hồ sơ cá nhân (REQ-HR-003/004/005) [NEEDS_REVIEW] |
| COMP-MBI-017 Ticket Surface | app | MOD-TICKET-CSKH | Ticket queue + escalation (REQ-OPS-009) |
| COMP-MBI-018 Shop Alert Surface | app | MOD-TIKTOK-SHOP | Alert anomaly shop, trạng thái monitoring (REQ-OPS-011) |
| COMP-MBI-019 Portal Ops View | app | MOD-CLIENT-PORTAL | Trạng thái tài khoản portal, monitor (REQ-OPS-010) |
| COMP-MBI-020 RBAC/MFA Surface | app | MOD-RBAC-AUDIT | SSO/MFA client, biometric, MFA step-up, device binding, biên vai CFO kiêm CTO (REQ-BOD-002/011) |

## 3. Business layer: mobile phục vụ ai, làm gì

Theo role matrix baseline §1:

- **BOD_CEO:** duyệt vượt ngưỡng — escalation cuối cùng (REQ-BOD-001); xem P&L/BI dashboard/alert center read-only. CEO duyệt trên mobile vẫn đi qua cùng state machine ngưỡng phía backend.
- **BOD_CFO_CTO / FIN_L1 / FIN_L2:** duyệt chi/giải ngân (REQ-FIN-008), dual approval điều chỉnh ví/tỷ giá/hoàn tiền (REQ-FIN-003), xác nhận Financial Hard Stop "đã khớp tiền" (REQ-FIN-006), xem AML T1–T6, nhận cảnh báo số dư SLA đỏ 2h. Kiêm nhiệm CFO-CTO hiển thị đúng biên vai, không gộp quyền ở client.
- **Nhân viên ESS (mọi phòng):** chấm công, xin nghỉ phép (số dư tự động do HR-CORE kiểm tra), nhập timesheet, xem hồ sơ (REQ-HR-003/004/005 + REQ-OPS-007). Duyệt timesheet OPS∥HR và duyệt nghỉ phép phân cấp L1→L2 vẫn phía backend.
- **OPS (PLAN/AM/CONT):** ticket, ký nhận handoff, checklist deliverable, shop alert, ad account quick view, portal ops.
- **SALES (L2/L3/GM):** Gate 1/2 Go/No-Go, duyệt chiết khấu vượt định mức, e-sign hợp đồng.

**Nguyên tắc cứng:** mọi hành động mobile = gọi một **state-transition endpoint** xuống backend (approve/reject/submit/check-in). Backend tự thực thi lại toàn bộ quy tắc (ngưỡng, SoD 4 vai, dual approval, delegate, escalation timeout, balance check) — kể cả khi request đến từ mobile hay web, kết quả nhất quán. Mobile KHÔNG tự tính và không thể bypass.

## 4. Data ownership

Mobile **chỉ sở hữu**: (1) device registration + push token (đồng bộ với backend qua BFF, gắn device binding); (2) local cache read-only mã hóa, có TTL, purge khi logout/remote wipe; (3) outbox queue offline (giới hạn ESS). Mọi dữ liệu nghiệp vụ — ví, lệnh chi, timesheet, ticket, lead, campaign — thuộc module owner ở SYS-CORE-BACKEND; mobile không phải SSOT của bất kỳ object nào trong lifecycle §2 baseline. PII lương (Confidential/Restricted) không cache trên thiết bị, chỉ render theo field-level security backend.

## 5. Giao tiếp

- **SSO/MFA từ CORE-BACKEND (FEAT-CORE-RBAC-005):** mobile là client của SSO tập trung; mở app hằng ngày bằng biometric/PIN thiết bị (unlock local), còn MFA step-up (OTP) bắt buộc khi ký lệnh nhạy cảm (duyệt tiền, hard stop, vượt ngưỡng). Token ngắn hạn + refresh; device lạ bị từ chối.
- **REST qua Mobile BFF → backend:** state-transition endpoints + list server-side (limit 20/max 100); BFF chỉ shaping.
- **Push channel:** COMP-MBI-004 nhận từ SLA-NOTIF worker của BCERP-WEB (SLA sắp vỡ/vỡ, escalation AM→AD→BOD, cảnh báo ví 2h, alert center) → FCM/APNs → deep-link. Mất push **không** làm vỡ SLA — escalation timer chạy phía backend, push chỉ là kênh báo.
- **Offline strategy (ESS chấm công):** check-in/out ghi local outbox + idempotency key, sync khi online; **server timestamp là trọng tài**, backend validate chống chấm hộ. Offline queue bị cấm cho lệnh tiền và phê duyệt tài chính.

## 6. Quy ước kỹ thuật đề xuất

- **Runtime:** React Native + TypeScript (1 codebase iOS/Android, OTA patch UI); BFF Node.js/NestJS.
- **App versioning:** minimum supported version, force-update khi API breaking change.
- **Biometric + device binding:** 1 user — thiết bị đã đăng ký; revoke token khi thiết bị lạ; remote wipe cache khi mất máy; cert pinning; screenshot-blur màn PII/tiền.
- **Audit:** mọi action mobile được backend ghi vào audit log WORM ≥10 năm (REQ-FIN-012); mobile chỉ log kỹ thuật.

## 7. Rủi ro & trade-offs + [NEEDS_REVIEW]

**Rủi ro / trade-offs:**

| Rủi ro | Đánh giá |
|---|---|
| Offline replay chấm công trùng/leech giờ | Idempotency key + server timestamp + backend validation; vẫn cần quy chế HR chốt biên |
| Duyệt tài chính "mù" trên màn hình nhỏ | Bắt buộc hiển thị context tối thiểu (số tiền, ngưỡng, chứng từ) trước khi enable nút duyệt; trường hợp phức tạp deep-link sang web |
| Phụ thuộc push để hành động kịp SLA 2h | Chấp nhận: SLA escalation không phụ thuộc mobile; push là kênh tăng tốc |
| Mất thiết bị có token | Device binding + revoke + remote wipe; rủi ro còn lại thấp |
| 20 surface nhỏ tăng chi phí maintain | Gom shared UI (inbox pattern, list pattern) trong app shell; chấp nhận đổi lấy traceability 1-1 với FEAT registry |

**[NEEDS_REVIEW]:**

1. **Registry gap HR-CORE:** REQ-HR-003 (chấm công), REQ-HR-004 (nghỉ phép), REQ-HR-005 (ESS) không có FEAT touchpoint cho SYS-MOBILE-INTERNAL trong registry, nhưng baseline §1 gán actor "Nhân viên (ESS)" dùng MOBILE-INTERNAL với module HR-CORE + CAPTS. Thiết kế giữ ESS Mobile (COMP-MBI-016) theo baseline — cần xác nhận bổ sung touchpoint registry.
2. **Chọn nền tảng mobile** (React Native vs Flutter vs native) chưa có quyết định kiến trúc trong baseline — đề xuất React Native, chờ phê duyệt.
3. **Quy tắc offline chấm công** (giới hạn giờ offline, yêu cầu định vị, chống chấm hộ) chưa định nghĩa trong baseline — cần quy chế HR xác nhận trước khi harden.
4. **Mức MFA step-up trên mobile** cho lệnh tài chính (biometric đủ hay bắt buộc OTP) chưa chốt trong REQ-BOD-011 — đề xuất OTP bắt buộc, chờ xác nhận.
5. **Phạm vi dashboard mobile** (mức rút gọn P&L/BI cho màn hình nhỏ) chưa spec — đề xuất read-only rút gọn, full trên BCERP-WEB.
