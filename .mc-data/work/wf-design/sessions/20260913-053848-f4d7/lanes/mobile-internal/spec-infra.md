# Infrastructure Specification — SYS-MOBILE-INTERNAL

> READS: `P3-01-architecture.md` (§1, §3, §7), `lanes/mobile-internal/arch-draft.md`, `lanes/mobile-internal/spec-api.md`, `spec-db.md`
> OUTPUT: Môi trường, container specs, networking, push gateway, app distribution, cert pinning, min-version gating, monitoring
> USED BY: `phase6-deployment/deployment-guide.md`
> DATE: 2026-09-13

---

## 1. Environments

| Env | URL (BFF) | Branch | Auto-deploy | Mục đích |
|-----|-----------|--------|-------------|----------|
| Development | `localhost:8084` | any | No | Dev BFF + push gateway (push dùng sandbox FCM/APNs) |
| Staging | `staging.bcerp.bcagency.vn/mbi` | `develop` | Yes (on push) | QA app build qua TestFlight / Play internal track |
| Production | `bcerp.bcagency.vn/mbi` | `main` | Manual approval | Live cho toàn bộ nhân viên nội bộ |

> [NEEDS_REVIEW] P3-01 §7 ghi production `bcerp.bcagency.vn` là môi trường nội bộ, nhưng mobile app cần truy cập ngoài văn phòng (chấm công offline-sync, push, duyệt từ xa). Cần chốt chính sách truy cập BFF: (a) public endpoint + device binding + cert pinning + MFA, hoặc (b) VPN-only. Đề xuất (a).

---

## 2. Required Environment Variables

| Variable | Mô tả | Required |
|----------|-------|----------|
| `PORT` / `NODE_ENV` / `LOG_LEVEL` / `TZ` | Port 8084, env, logging, UTC | ✅ |
| `DATABASE_URL_MBI` | PostgreSQL schema `mbi_device` | ✅ |
| `REDIS_URL` | Rate limit + cache + push queue | ✅ |
| `CORE_BACKEND_URL` | SYS-CORE-BACKEND (IdP/PDP/BI serving) | ✅ |
| `ERP_BACKEND_URL` | SYS-BCERP-WEB (target state-transition) | ✅ |
| `INTERNAL_SERVICE_TOKEN` | Auth service-to-service (push dispatch) | ✅ |
| `JWKS_URL` | JWKS core IdP — BFF verify JWT, không giữ secret | ✅ |
| `FCM_CREDENTIALS_JSON` | Service account FCM (file path) | ✅ |
| `APNS_KEY_PATH` / `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_ENV` | APNs token auth + sandbox/production | ✅ (iOS) |
| `MBI_BUNDLE_ID` | Bundle id app internal | ✅ |
| `MIN_APP_VERSION` / `PINSET_VERSION` | Min-version gating + pinset hiện hành | ✅ |

---

## 3. Server / Container Specs

| Service (INFRA-ID) | CPU | RAM | Replicas (prod) | Ghi chú |
|--------------------|-----|-----|-----------------|---------|
| Mobile BFF (INFRA-MBI-001) | 1 vCPU | 512MB | 2 | NestJS stateless; proxy + shaping; không queue lâu |
| Push Gateway (INFRA-MBI-002) | 1 vCPU | 512MB | 2 | Consumer SLA-NOTIF/alert/shop → FCM/APNs; queue Redis + retry + DLQ |
| PostgreSQL `mbi_device` (INFRA-MBI-006) | dùng chung cụm platform | — | 1 primary + 1 replica | Volume nhỏ (≈ số nhân viên), không instance riêng |
| Redis | dùng chung | — | 1 | Rate limit, idempotency cache, push queue |

Docker image theo CI/CD chung platform (build, test, Git SHA tag, rolling update, health check).

---

## 4. Networking

```
Mobile app (internet) ── HTTPS 443 ──► Reverse proxy ──► Mobile BFF :8084
Mobile BFF ──► SYS-CORE-BACKEND :8080 · SYS-BCERP-WEB :8081   [internal network]
Push Gateway ──► FCM + APNs (outbound 443, không mở inbound)
COMP-ERP-006 / COMP-CORE-011 / COMP-GW-013 ──► /internal/mbi/push/dispatch [internal]
```

Firewall: chỉ 443 public cho BFF qua reverse proxy — không expose endpoint module backend nào ra ngoài; DB/Redis/backend trong internal network; APNs/FCM outbound-only. Kênh app distribution không đi qua BFF.

---

## 5. App Distribution (INFRA-MBI-003)

| Hạng mục | Đề xuất |
|----------|---------|
| CI build | Fastlane/GitHub Actions: build React Native, sign, upload — secrets trong CI secrets manager, không vào repo |
| iOS | TestFlight Internal Testing theo phòng ban; không App Store public [NEEDS_REVIEW: xác nhận kênh Apple — Enterprise Program hay TestFlight] |
| Android | Google Play Internal Testing; production qua Managed Google Play/MDM hoặc APK ký nội bộ [NEEDS_REVIEW: chọn MDM — chưa có căn cứ] |
| OTA patch | OTA chỉ cho JS bundle UI — không OTA thay đổi native/permission |

Kênh distribution không đi qua BFF.

---

## 6. Cert Pinning & Min-Version Gating (INFRA-MBI-004, INFRA-MBI-005)

**Cert pinning (INFRA-MBI-004):** pin SPK leaf + 1 backup pin (khóa khác CA) cho `bcerp.bcagency.vn`; pinset phân phối qua `GET /api/v1/mbi/app-config` (ký số) + hard-code pin khởi điểm trong build. Rotation: thêm pin mới trước, bỏ pin cũ sau khi 100% app active chứa pin mới (`PINSET_VERSION` tracking). Fail pinning → chặn request + telemetry (không fallback non-pinned).

**Min-version gating (INFRA-MBI-005):** nguồn chân lý là cấu hình `MIN_APP_VERSION` + `platform → min_version` + `force_update` tại BFF app-config. App dưới minimum nhận `426 VERSION_UNSUPPORTED` + URL cài đặt → màn force-update. Thứ tự bắt buộc khi breaking change API: publish min-version mới → chờ adoption → mới deploy v2.

---

## 7. Health Check Endpoints

| Endpoint | Checks | Expected |
|----------|--------|----------|
| `GET /health` (BFF) | App running | `{ "status": "ok" }` |
| `GET /health/ready` (BFF) | JWKS core + ERP reachable | `{ "status": "ready" }` |
| `GET /health/db` | PostgreSQL `mbi_device` | `{ "status": "ok", "latency": "Xms" }` |
| `GET /health` (Push Gateway) | Running + queue depth | `{ "status": "ok", "queue": N }` |

---

## 8. Monitoring & Alerting

| Metric | Threshold Alert | Severity |
|--------|----------------|---------|
| BFF error rate | > 1% / 5 min | HIGH |
| BFF P95 response | > 2s | HIGH |
| Push delivery success (FCM/APNs) | < 95% / 15 min | HIGH |
| Push queue depth / DLQ > 0 | Bất kỳ | HIGH |
| Spike `DEVICE_NOT_BOUND`/revoke | > 5% login thất bại device | MEDIUM (báo hiệu mất máy/tấn công) |
| Cert pinning failure telemetry | > 1% session | HIGH |
| `VERSION_UNSUPPORTED` responses | > 5% request | MEDIUM (tín hiệu cần rollout) |
| Outbox ESS sync fail rate | > 2% replay rejected_invalid | MEDIUM |

Kênh alert + dashboard dùng chung platform (COMP-CORE-011 dispatch; cảnh báo tiền vẫn thuộc backend, push chỉ là kênh).

---

## 9. Non-Functional Requirements (trích — mobile-specific)

| Metric | Target | Đo bằng |
|--------|--------|---------|
| BFF proxy P95 | < 500ms | APM |
| Push latency event → thiết bị | < 30s (p95) | Push Gateway metric |
| Offline replay | 50 bản ghi/thiết bị < 10s | Load test |
| Availability BFF | 99,5% (mất BFF không vỡ SLA — escalation chạy phía backend) | Uptime monitor |
| Backup | `mbi_device` theo backup chung hàng ngày; cache thiết bị không backup | Backup job |
