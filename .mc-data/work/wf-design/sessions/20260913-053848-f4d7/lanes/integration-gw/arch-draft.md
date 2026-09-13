# Architecture Draft — SYS-INTEGRATION-GW (API Integration Gateway)

> Session 20260913-053848-f4d7 | Lane: system/integration-gw | Modules: MOD-SETTINGS-GW + MOD-TIKTOK-SHOP | REQ nền: REQ-BOD-008, REQ-FIN-005, REQ-FIN-013, REQ-OPS-011
> Baseline tuân thủ: business-context.md v4.1; spec gốc: quan-tri-integration-gateway-va-credentials-vault-vai-cto.md, api-7-nen-tang-degraded-mode-manual.md, tiktok-shop-monitoring.md

## 1. Vai trò cổng integration duy nhất + biên giới

SYS-INTEGRATION-GW là **cổng ra bên ngoài duy nhất** của BCERP. 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), phần mềm kế toán VAS (REQ-FIN-013 theo DI-004), và TikTok Shop (REQ-OPS-011) đều đi qua gateway — **SYS-CORE-BACKEND và SYS-BCERP-WEB không bao giờ gọi trực tiếp API nền tảng**. Gateway là tầng **headless data plane**: không có UI riêng, mọi thao tác quản trị phát từ console web nội bộ (counterpart SYS-BCERP-WEB), thực thi và enforce tại service layer của gateway.

Biên giới rõ ràng 3 phía:

- **Không sở hữu business logic tài chính**: đối trừ 3 số, ledger ví, financial hard stop, khóa kỳ, ticket discrepancy — thuộc SYS-CORE-BACKEND (MOD-WALLET-RECON, MOD-ADACCOUNT-CC). Gateway chỉ cung cấp dữ liệu **đã gắn nhãn nguồn `api`/`manual`** + raw payload + freshness.
- **Không sở hữu màn hình thao tác**: kênh import/nhập tay của FIN_L1, dashboard OPS, màn duyệt kết nối SALES_L4 — thuộc SYS-BCERP-WEB; cảnh báo push — thuộc SYS-MOBILE-INTERNAL.
- **Không tự dựng hạ tầng chung**: RBAC engine, MFA TOTP, immutable audit store — gọi và tuân thủ SYS-CORE-BACKEND (REQ-BOD-011, REQ-FIN-012). Gateway không serve trực tiếp Client Portal — feed portal đi qua Portal API Gateway của core (BR-GW-TT-002).
- **Ràng buộc touchpoint**: quản trị vault **cấm trên mobile** (A0 bod.md, BR-GW-STGW-005) — không tồn tại endpoint vault cho MOBILE-INTERNAL; request từ mobile bị từ chối tầng gateway + log cảnh báo bảo mật.

Đặc thù khởi điểm (DI-007): Business Verification chưa có quyền developer ở cả 7 nền tảng lẫn TikTok Shop → **degraded mode `manual` là trạng thái khởi điểm của toàn hệ thống**, không phải nhánh ngoại lệ. Gateway phải vận hành full luồng manual từ ngày đầu và chấm dứt đối soát bằng ảnh chụp màn hình.

## 2. Components & trách nhiệm (bảng)

| Component | Loại | Module | Trách nhiệm chính | Dependencies |
|---|---|---|---|---|
| COMP-GW-001 Connector Registry & Adapter Framework | gateway | MOD-SETTINGS-GW | Registry connection profile vendor-agnostic (DI-004); adapter interface chuẩn; state machine ConnectionProfile; chặn connector ngoài registry | COMP-GW-002, COMP-GW-007, SYS-CORE-BACKEND |
| COMP-GW-002 Credentials Vault | vault | MOD-SETTINGS-GW | Mã hóa at rest/in transit; mask-only; MFA TOTP step-up; độc quyền CTO; rotate ≥90d + T-7; thu hồi khẩn; cấm mobile | SYS-CORE-BACKEND, COMP-GW-007 |
| COMP-GW-003 Sync Scheduler & Rate-Limited Job Queue | worker | MOD-SETTINGS-GW | Pull hourly 2.600+ TKQC qua batch/queue chống rate limit; retry/backoff; ưu tiên TKQC active; fail → degraded + alert gộp | COMP-GW-001, COMP-GW-002, SYS-CORE-BACKEND |
| COMP-GW-004 Ingest & Normalization Pipeline | worker | MOD-SETTINGS-GW | Lưu raw payload trước parse; chuẩn hóa qua FieldMapping; gắn nhãn `api`/`manual` bất biến; kênh import schema 8 trường chặn lỗi theo dòng | COMP-GW-001, SYS-BCERP-WEB, SYS-CORE-BACKEND |
| COMP-GW-005 Degraded Mode & Backfill Engine | worker | MOD-SETTINGS-GW | State luồng MANUAL ↔ API ↔ BACKFILL; backfill theo thời gian, không ghi đè manual đã đối soát; kích hoạt đối soát lại về core | COMP-GW-003, COMP-GW-004, SYS-CORE-BACKEND |
| COMP-GW-006 Gateway Health & Policy Config Service | gateway | MOD-SETTINGS-GW | Sức khỏe 7 adapter + freshness; PolicyConfigVersion effective-dated chỉ BOD sửa; cảnh báo rotate T-7 / job fail; báo cáo oversight CEO | COMP-GW-003, SYS-CORE-BACKEND, SYS-BCERP-WEB |
| COMP-GW-007 Gateway Audit & API Call Log | gateway | MOD-SETTINGS-GW | Audit bất biến hash-chain mọi thao tác vault + mọi lần gọi API ra ngoài; xem log cũng bị log | SYS-CORE-BACKEND |
| COMP-GW-008 VAS Accounting Connector | connector | MOD-SETTINGS-GW | Connector kế toán VAS như 1 profile (DI-004): api_adapter hoặc import/export file chuẩn schema; đổi phần mềm = thêm profile, không sửa code | COMP-GW-001, COMP-GW-004, SYS-CORE-BACKEND |
| COMP-GW-009 Wallet & TKQC Feed Dispatcher | worker | MOD-SETTINGS-GW | Đẩy PlatformStatement gắn nhãn vào fact tables core (đối trừ 3 số); feed REQ-OPS-001/003; event `wallet.sync.completed`; không tự quy đổi tỷ giá | COMP-GW-004, SYS-CORE-BACKEND |
| COMP-GW-010 TikTok Shop Connection Manager | connector | MOD-TIKTOK-SHOP | OAuth per-client từng shop; scope ghi rõ; access log bất biến; thu hồi ≤24h; phản chiếu gate stage từ workflow 3 Gate của core | COMP-GW-001, COMP-GW-002, SYS-CORE-BACKEND, SYS-BCERP-WEB |
| COMP-GW-011 TikTok Shop Metrics Sync Worker | worker | MOD-TIKTOK-SHOP | Pull GMV/đơn/settlement/shop health; `reference_only=true` luôn bật; tách bạch GMV vs NSQC ads; không OMS/WMS; degraded manual + backfill | COMP-GW-004, COMP-GW-005, COMP-GW-010, SYS-CORE-BACKEND |
| COMP-GW-012 PII Guard & Tenant Isolation Service | gateway | MOD-TIKTOK-SHOP | Mask PII mặc định; phiên PII TTL không persist; RLS tenant isolation; chặn cứng tầng API mapping GMV vào doanh thu | COMP-GW-011, SYS-CORE-BACKEND |
| COMP-GW-013 Shop Alert & Portal Feed Emitter | worker | MOD-TIKTOK-SHOP | Event `shop.alert` (shop khóa, settlement lệch, giấy phép/OAuth hết hạn); PortalReportFeed tenant-scoped đã mask; feed dashboard nội bộ | COMP-GW-011, COMP-GW-012, SYS-CORE-BACKEND, SYS-MOBILE-INTERNAL |

## 3. Business layer: connection lifecycle, degraded mode manual, TikTok shop monitoring flow

**Connection lifecycle (ConnectionProfile — MOD-SETTINGS-GW).** Baseline chuẩn hóa: `configured → credentials_vaulted → active → degraded / revoked` (spec gốc đặt tên DRAFT/ACTIVE/DEGRADED/DISABLED/REVOKED — cùng ngữ nghĩa). Người đổi trạng thái: BOD_CFO_CTO activate (điều kiện: credential đã nạp vault + MFA + health check đầu tiên OK); hệ thống **tự động** mark degraded khi mất quyền API/job fail vượt ngưỡng (lỗi P1 nếu fail câm); BOD_CFO_CTO disable/revoke; hệ thống backfill rồi trả về active. `REVOKED` là trạng thái an toàn bắt buộc trước khi nạp credential mới — cấm "thay token tại chỗ" khi nghi ngờ rò rỉ. Mọi transition ghi audit bất biến kèm trigger truy vết (job id, mã lỗi, người thao tác). Trạng thái là machine-state gateway giữ — web/mobile chỉ hiển thị.

**Degraded mode manual workflow (BR-FIN-205, BR-FIN-301).** Luồng dữ liệu per-platform chạy state riêng: `MANUAL` (khởi điểm) ↔ `API`, kèm `BACKFILL`. Khi degraded:
1. Hệ thống tự gắn nhãn nguồn `manual` cho mọi dữ liệu mới; **nhãn gắn tại thời điểm ghi trên từng bản ghi, immutable** — một kỳ có thể chứa hỗn hợp api/manual, đối soát lọc theo bản ghi.
2. **Ai nhập tay**: FIN_L1 (statement 7 nền tảng) qua 2 kênh duy nhất trên BCERP-WEB — import statement schema chuẩn 8 trường (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) hoặc nhập tay có cấu trúc; **không có lối nhập tự do dạng text**. Với TikTok Shop: OPS_ADS nạp (OPS_AM bổ trợ) schema 6 trường (shop, ngày, loại chỉ số, số tiền gốc, tiền tệ, mã tham chiếu). Gateway là điểm nhận, validate và lưu — màn hình thuộc web counterpart.
3. **Dấu vết thủ công**: bản ghi `manual` bắt buộc `entered_by` + `evidence_ref` (statement file/ảnh chứng từ tham chiếu); thiếu → không được đưa vào đối soát. Sai schema bị chặn **theo dòng** — dòng hợp lệ vẫn nhận, không nhận batch mù; khóa tự nhiên chống trùng (platform + TKQC + ngày + loại + mã tham chiếu).
4. **Backfill**: khi API được cấp, gateway backfill tự động theo thứ tự thời gian, gắn lại nhãn `api`, **không xóa/ghi đè bản ghi manual đã đối soát** (giữ làm vết), kích hoạt đối soát lại kỳ nhập tay — chênh lệch thành ticket discrepancy của core; nếu kỳ đã bị FIN_L2 khóa, gateway chỉ ghi dữ liệu gốc, core quyết định xử lý. Nền tảng không có API statement → đối soát hạ tuần, bù khớp tích lũy khi có API.

**TikTok Shop monitoring flow (REQ-OPS-011).** `PROPOSED` (OPS_AM đề xuất OAuth per-client, scope ghi rõ) → SALES_L4 duyệt → `VERIFYING` (Gate 1: checklist chủ shop + giấy phép ngành hàng, lưu ngày hết hạn) → Gate 2 ký Go-live + baseline KPI → `OPERATING` (gateway chỉ bật pull sau tín hiệu Gate 2 từ core, tự gate-check trước mỗi job) → `DEGRADED_MANUAL` khi mất OAuth (dừng pull mới, không retry bằng credential cũ) → `OPERATING` sau backfill; hoặc `REVOKED` ≤24h theo sự kiện hợp đồng/khách yêu cầu (AM xác nhận văn bản), `REJECTED` kết thúc. Shop bị platform khóa chỉ gắn cờ health + alert, không đổi trạng thái kết nối. Dữ liệu ShopMetricDaily luôn mang `reference_only=true` — GMV/settlement là chỉ số tham chiếu thuộc khách, **tuyệt đối không map vào doanh thu agency**; chi tiêu NSQC ads nằm ở luồng TKQC quảng cáo riêng, chỉ join qua mã tham chiếu ở lớp tổng hợp core.

## 4. Data ownership

**Gateway sở hữu** (data plane integration): ConnectionProfile, CredentialVersion (metadata + encrypted blob), SyncSchedule, SyncJob, AdapterHealthCheck, PolicyConfigVersion, FieldMapping/ImportExportTemplate, GatewayAuditLog (tầng gateway), RawPayload, PlatformStatement/ImportBatch (bản ghi thô gắn nhãn), BackfillRun; riêng MOD-TIKTOK-SHOP: ShopConnection, ShopAccessLog, ShopMetricDaily, PiiAccessSession, PortalReportFeed (phát hành), SettlementReconPeriod (khởi tạo kỳ, kết quả đối soát thuộc core).

**Gateway KHÔNG sở hữu business objects**: ví và lệnh tiền giữ hộ, kết quả đối trừ 3 số, kỳ khóa — thuộc MOD-WALLET-RECON (FIN); TKQC registry và vòng đời — thuộc MOD-ADACC-CC (OPS); hóa đơn/chi/giải ngân — thuộc MOD-ARAP-PAYMENT; workflow 3 Gate TikTok — thuộc core. Gateway giao dữ liệu gắn nhãn qua fact tables/event, nhận lại tín hiệu trạng thái (gate stage, kết quả đối soát) để điều khiển pull. Truy vấn đối soát của FIN_L2 lọc theo nhãn trên từng bản ghi do gateway ghi — nhãn không ai sửa tay kể cả FIN.

## 5. Giao tiếp

**Outbound (per-platform)**: pull scheduled hourly qua batch/queue; giới hạn tốc độ theo quota từng nền tảng; retry + exponential backoff; circuit breaker per-platform — fail liên tục mở mạch, adapter chuyển degraded, các nguồn còn lại hoạt động độc lập không dây chuyền; alert gộp theo nguồn tránh ngập người nhận. Mọi lần gọi API ra ngoài ghi log bất biến.

**Events xuất**: `wallet.sync.completed` (platform, cửa sổ, số bản ghi, nhãn nguồn — core feed cảnh báo số dư SLA đỏ 2h và Ad Account CC); `shop.alert` (shop, loại cảnh báo, timestamp, giá trị lệch — alert center + push M-INT); `adapter.health.changed` / `adapter.degraded` (CTO + oversight BOD); `backfill.completed` (kích hoạt đối soát lại).

**Inbound**: nhận config từ Settings UI (connection profile, field mapping, template, scheduler, tham số policy) — mọi thay đổi qua phê duyệt CTO/BOD, effective-dated; nhận kênh import/manual từ BCERP-WEB; nhận tín hiệu gate stage từ core; nhận sự kiện hợp đồng để kích hoạt thu hồi ủy quyền shop. **Không mở webhook receiver** — cả 3 spec đều pull-based [NEEDS_REVIEW].

## 6. Quy ước kỹ thuật đề xuất

- **Secret rotation**: rotate ≥90 ngày, cảnh báo T-7, quá hạn >7 ngày adapter tự degraded; rotate tạo CredentialVersion mới giữ lịch sử; thu hồi khẩn vô hiệu token tức thì ở mức khả thi; offboarding rotate ≤24h theo checklist CTO xác nhận, gắn quarterly access review (REQ-BOD-007).
- **Vault security**: envelope encryption (KMS master + per-credential data key); plaintext chỉ tồn tại trong vault — mọi API trả mask + metadata; MFA TOTP step-up cho mọi ghi; SYS_ADMIN chỉ thực thi sau phê duyệt CTO.
- **Idempotency**: khóa tự nhiên trên mọi bản ghi ingest; job sync có job_id riêng; backfill dùng cửa sổ thời gian phủ khoảng đứt; import re-nạp chỉ dòng lỗi.
- **Payload archival cho audit tiền**: raw payload lưu object storage trước parse (job_id, parse_status), đủ để reprocess khi mapping đổi và đối chiếu khi cảnh báo nghi giả; giữ `amount_original` + `currency` nguyên vẹn — gateway không tự quy đổi tỷ giá (snapshot tỷ giá ở core).
- **Audit bất biến**: GatewayAuditLog append-only hash-chain, dùng hạ tầng WORM chung REQ-FIN-012 (≥10 năm); bất thường hash-chain alert BOD.
- **Nhãn nguồn là hợp đồng dữ liệu**: record thiếu nhãn/entered_by/evidence_ref bị reject ở tầng gateway — core từ chối đưa vào đối trừ 3 số (BR-FIN-205a).

## 7. Rủi ro & trade-offs + [NEEDS_REVIEW]

**Rủi ro & trade-offs**:
- **Khởi điểm 100% manual (DI-007)**: giá trị tự động hóa bằng zero lúc đầu; chi phí nhập tay FIN_L1/OPS_ADS cao và sai sót con người là rủi ro chính — bù bằng schema chặn lỗi theo dòng + evidence bắt buộc + raw payload đối chiếu khi backfill. Trade-off được chấp nhận vì đây là hiện trạng bắt buộc, không phải lựa chọn.
- **Circuit breaker tự động có thể degraded oan** khi nền tảng lỗi tạm thời kéo dài — chấp nhận an toàn hơn (manual vẫn chạy nghiệp vụ), reset lại sau health check OK.
- **Backfill chồng kỳ đã khóa**: gateway chỉ ghi dữ liệu gốc, xử lý chênh lệch dồn về core — ranh giới trách nhiệm rõ nhưng tạo latency giải trình FIN_L2.
- **OAuth per-client từng shop** tốn công vận hành ủy quyền so với gom chung — bắt buộc theo BR-OPS-4.1a để giới hạn trách nhiệm pháp lý và thu hồi sạch theo hợp đồng.
- **Vault tập trung một chỗ** = điểm tấn công giá trị cao; bù bằng MFA, cấm mobile, mask-only, hash-chain audit, rotate bắt buộc.
- **Single gateway** là single point of failure cho mọi dữ liệu nền tảng — cần HA cho worker/queue; but degraded manual cho phép nghiệp vụ sống khi gateway sự cố kéo dài.

**[NEEDS_REVIEW]**:
1. **E-sign provider**: baseline nêu e-sign ở QDD (REQ-SALES-007) nhưng không feature nào của GW chỉ định connector e-sign; nếu cần, thêm connection profile "nguồn khác khai báo tương tự" theo DI-004 — chưa có căn cứ thiết kế riêng.
2. **Webhook receiver**: task gợi ý nhưng cả 3 spec đều pull-based; nếu nền tảng hỗ trợ push (vd TikTok Shop event feed), cần quyết định bổ sung component nhận webhook — chưa có spec.
3. **Cơ chế kết nối chính xác của VAS** (API hay import file) chưa xác định [KXN-9] — profile thiết kế tổng quát cho cả 2.
4. **Phạm vi chỉ số GMV hiển thị cho khách trên Portal** chưa chốt số [CẦN CHỐT SỐ] — thiết kế cơ chế cấu hình theo tenant (visibility_config_version) để không đổi code khi chốt.
5. **Mốc thời gian cấp quyền API từng nền tảng** chưa xác định (DI-007) — backfill thiết kế theo sự kiện, không đặt lịch.
