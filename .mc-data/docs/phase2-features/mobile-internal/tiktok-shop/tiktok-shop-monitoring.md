# Tính Năng: TikTok Shop Monitoring — Mobile Nội Bộ

> **Dựa trên:** REQ-OPS-011 trong `phase1-business/departments/operations/operations.md` (Phần A — REQ-OPS-011; Phần B.4 — BR-OPS-4.1…4.6)
> **Phân hệ:** Mobile nội bộ (SYS-MOBILE-INTERNAL)
> **Module:** TikTok Shop Monitoring (MOD-TIKTOK-SHOP)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (B7), `deferred-issues.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
>
> **Fan-out:** REQ-OPS-011 ở 4 systems; đây là bản riêng SYS-MOBILE-INTERNAL (React Native, offline-capable — duyệt-on-the-go, xem dashboard). Counterparts: SYS-CORE-BACKEND (workflow 3 Gate, validation tách bạch GMV), SYS-INTEGRATION-GW (OAuth per-client, pull, phiên TTL, degraded manual), SYS-BCERP-WEB (dashboard, kênh import).
>
> **Hướng dẫn ID:** FEAT-ID do lane phát hành cố định `FEAT-MBI-TIKTOK-001` (REQ-OPS-011 — `req-registry.json`: SYS=SYS-MOBILE-INTERNAL, MOD=MOD-TIKTOK-SHOP).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-TIKTOK-001 |
| Module | MOD-TIKTOK-SHOP |
| Yêu cầu nghiệp vụ | REQ-OPS-011 — TikTok Shop Monitoring (Quan trọng/MEDIUM, GĐ3); nguồn: BR-OPS-4.1…4.6 (`operations.md` B.4), policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5 |
| Người dùng liên quan | OPS_AM (cảnh báo ủy quyền/giấy phép; phối hợp FIN_L1 qua counterpart), OPS_ADS (cảnh báo shop health, theo dõi GMV), OPS_PLAN (tổng hợp portfolio), OPS_CONT/OPS_DES/OPS_EDIT (chỉ số shop khách phụ trách) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | FEAT-MBI-SLANOT-001 (hợp đồng push CORE → M-INT, offline queue/idempotency); FEAT-GW-TIKTOK-001 (nhãn nguồn `api`/`manual` + freshness, phiên TTL); FEAT-CORE-TIKTOK-001 (workflow 3 Gate, engine cảnh báo); FEAT-ERP-TIKTOK-001 (dashboard đầy đủ, kênh import trên web) |
| Ghi chú Expert (A7) | `operations.md` Mục A7 đang chờ expert review — chưa có điều chỉnh chốt cho REQ-OPS-011; BR-OPS-4.1…4.6 giữ nguyên theo paid-media-expert Call 1/2 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Bản SYS-MOBILE-INTERNAL của REQ-OPS-011 đưa monitoring TikTok Shop lên mobile nội bộ: staff OPS nhận push cảnh báo shop health bất thường, ủy quyền OAuth/giấy phép ngành hàng sắp hết hạn, GMV/settlement lệch, baseline lệch — và xác nhận xử lý ngay trên di động kể cả ngoài giờ hay mất mạng. Kèm dashboard rút gọn GMV/shop health theo khách với nhãn nguồn và độ tươi dữ liệu. Hai nguyên tắc cốt lõi: **tách bạch GMV shop (chỉ số tham chiếu của khách) với chi tiêu NSQC ads** — không bao giờ gộp hai luồng; và **mobile không có kênh nào đưa dữ liệu shop ra ngoài cho khách**.

**Phạm vi:**
- Bao gồm: nhận push 5 nhóm cảnh báo shop (bị hạn chế/khóa, GMV/settlement lệch, giấy phép hết hạn, OAuth sắp hết hạn, baseline lệch); acknowledge + handling + escalate trên di động, gắn ticket theo SLA khách (REQ-OPS-008); dashboard rút gọn GMV/đơn/settlement/shop health đã mask, kèm nhãn nguồn `api`/`manual` + timestamp bắt buộc; xem trạng thái kết nối và hạn ủy quyền/giấy phép; offline-capable (cache chỉ đọc, hành động xếp hàng sync khi online).
- Không bao gồm: kéo dữ liệu OAuth/pull/phiên TTL PII — thuộc GW; workflow 3 Gate, validation chặn mapping GMV, đối soát Gate 3 — thuộc CORE (mobile chỉ phản chiếu và gửi hành động); dashboard đầy đủ, kênh import manual, duyệt kết nối — thuộc WEB, mobile không có kênh nạp số liệu; báo cáo khách qua Portal — thuộc counterpart PORTAL/M-PORTAL (mobile staff-only); quản lý đơn/fulfillment — **KHÔNG làm OMS/WMS** (BR-OPS-4.3).

---

## 2. Luồng Người Dùng (User Stories)

Luồng theo touchpoint SYS-MOBILE-INTERNAL — ứng dụng React Native offline-capable cho staff cần di động (duyệt-on-the-go, xem dashboard): dữ liệu shop chỉ đọc từ nguồn đã tổng hợp/mask của CORE qua GW; quyết định nghiệp vụ nặng (duyệt kết nối, Gate 2, nạp manual, chốt đối soát) thực hiện trên web/CORE. Trạng thái cảnh báo và kết nối là machine-state do CORE/GW giữ — mobile phản chiếu và gửi lại hành động qua API có idempotency.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Nhận push ngay khi shop khách bị hạn chế/khóa hoặc GMV/settlement lệch bất thường | Xử lý theo SLA khách trước khi ảnh hưởng lan sang vận hành và phí dịch vụ |
| 2 | OPS_AM | Nhận cảnh báo trước hạn khi ủy quyền OAuth/giấy phép ngành hàng sắp hết hạn | Nhắc khách làm mới kịp thời, tránh đứt dữ liệu và rủi ro pháp lý |
| 3 | OPS_AM | Xác nhận đã xử lý cảnh báo ngay trên mobile khi đang ngoài văn phòng | Mốc xử lý ghi đúng thời điểm thực tế |
| 4 | OPS_ADS | Xem dashboard rút gọn GMV/shop health kèm nhãn nguồn `api`/`manual` và "chỉ số tham chiếu" | Tra số thực khi gặp khách mà không nhầm GMV với chi tiêu ads hay doanh thu BC |
| 5 | OPS_PLAN | Xem tổng hợp cảnh báo và chỉ số shop theo portfolio | Điều phối nguồn lực, nhận diện khách tăng trưởng |
| 6 | OPS_CONT/OPS_DES/OPS_EDIT | Xem GMV theo sản phẩm/danh mục (đã mask) của shop gắn dự án mình | Ưu tiên content/livestream theo số thực |
| 7 | OPS_ADS / OPS_AM | Acknowledge cảnh báo khi mất mạng, app tự sync khi online | Việc xử lý không chặn khi di chuyển |
| 8 | OPS_AM | Bị chặn mở bất kỳ dữ liệu PII người mua cuối đầy đủ nào trên mobile | Dữ liệu nhạy cảm không rò rỉ qua thiết bị dễ mất |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn: operations.md B.4 (BR-OPS-4.1…4.6) + phần bắt buộc của lane brief.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-4.3a | **Tách bạch GMV shop vs NSQC ads (bắt buộc lane):** dashboard hiển thị GMV/đơn/settlement (luồng TikTok Shop qua GW) và chi tiêu NSQC ads (luồng TKQC quảng cáo — REQ-OPS-001/003) ở hai khối riêng, không gộp một record/biểu đồ; GMV luôn gắn nhãn "chỉ số tham chiếu của khách"; hai luồng chỉ ghép qua mã tham chiếu ở lớp tổng hợp CORE | View gộp hai luồng là lỗi block — chặn ở tầng dữ liệu CORE |
| BR-OPS-4.4 | **Red line tài chính:** mọi bản ghi GMV/settlement mang cờ `reference_only`; mobile không hiển thị view nào hàm ý GMV là doanh thu agency; doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ (+ phí vận hành shop nếu HĐ quy định); share theo GMV (nếu có) chỉ ghi nhận ở CORE sau khi settlement đối soát khớp | Giao diện nào gọi GMV là "doanh thu" là lỗi P0 |
| BR-MBI-TT-001 | **Sync qua GW + degraded mode `manual` khi mất API (bắt buộc lane):** mobile chỉ tiêu thụ dữ liệu CORE tổng hợp từ GW (nhãn `api`) hoặc từ kênh import có cấu trúc trên web (nhãn `manual` — DI-007: chưa có quyền developer nên khởi điểm nhiều shop chạy manual); mọi chỉ số kèm nhãn nguồn + thời điểm cập nhật, cấm hiển thị số thiếu timestamp; shop degraded hiển thị rõ "số liệu nạp tay"; mobile không có kênh nạp manual | Thiếu nhãn nguồn/timestamp không render; `manual` hiển thị như `api` là lỗi nghiêm trọng |
| BR-MBI-TT-002 | **Báo cáo khách qua Portal (phần của tenant) + dashboard nội bộ (bắt buộc lane):** báo cáo GMV/settlement cho khách chỉ phát hành qua Portal theo cấu hình phạm vi HĐ từng tenant `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]` — mặc định GMV là tham chiếu nội bộ, không thuộc nhóm khách thấy; mobile chỉ phục vụ dashboard nội bộ, không gửi/export dữ liệu shop cho khách; khách không đăng nhập được mobile nội bộ | Attempt export bị chặn tầng API + audit log; app không có route phục vụ khách |
| BR-OPS-4.6 | **Cảnh báo SLA shop:** 5 nhóm cảnh báo push cho OPS_ADS/OPS_AM theo portfolio; xử lý theo SLA ticket của khách (tier×priority — REQ-OPS-008); không SLA riêng cho fulfillment; quá SLA không ai nhận tự escalate AM → OPS_PLAN | Thiếu shop/loại/timestamp/giá trị lệch không phát push |
| BR-MBI-TT-003 | **Mask PII + cấm phiên đầy đủ trên mobile:** chỉ nhận dữ liệu đã mask tầng API (SĐT `090****123`, địa chỉ còn tỉnh/huyện, tên mask); không có chức năng mở phiên PII đầy đủ (phiên TTL chỉ qua web; credential/vault chỉ trên WEB có MFA); local cache không persist PII | Request mở phiên PII từ mobile bị từ chối tầng API; PII trong cache là lỗi P0 |
| BR-MBI-TT-004 | **Offline-capable & chống trùng sync:** ack/handling/escalate offline xếp hàng cục bộ có idempotency-key, sync khi online theo thứ tự; mốc thời gian theo timestamp server; resolve bắt buộc kèm bằng chứng (ticket ref + đối chiếu) | Sync trùng bị chặn bởi idempotency; hai người ack cùng cảnh báo → bản đến trước hợp lệ |
| BR-OPS-4.1 (mảng mobile) | **Cảnh báo ủy quyền/giấy phép + trạng thái kết nối:** mobile hiển thị hạn OAuth/giấy phép từng shop với ngưỡng cảnh báo trước hạn do CORE cấu hình; thu hồi ủy quyền khi hết HĐ (≤24h) tự động theo sự kiện HĐ ở GW/CORE — mobile chỉ nhận push kết quả và task xác nhận thông báo khách của AM, không thao tác credential | Push hết hạn phải đến trước thời điểm hết hạn; `REVOKED` chỉ đọc — mọi pull đã vô hiệu ở GW |

---

## 4. Phân Quyền

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT | SYS_ADMIN |
|-----------|---------|--------|----------|-------------------|-----------|
| Nhận push cảnh báo shop theo portfolio | ✅ | ✅ | ✅ (tổng hợp) | ❌ | ❌ |
| Xem dashboard GMV/shop health rút gọn | Khách phụ trách | Khách phụ trách | Toàn portfolio | Shop gắn dự án mình | ❌ |
| Xem trạng thái kết nối + hạn OAuth/giấy phép | ✅ | ✅ | ✅ | ❌ | ✅ (kỹ thuật) |
| Acknowledge / handling / escalate cảnh báo | ✅ | ✅ | Nhận escalate cuối | ❌ | ❌ |
| Resolve cảnh báo kèm bằng chứng | ✅ | ✅ | ❌ | ❌ | ❌ |
| Nạp số liệu degraded `manual` | ❌ (chỉ web nội bộ) | ❌ (chỉ web nội bộ) | ❌ | ❌ | ❌ |
| Mở phiên dữ liệu PII đầy đủ | ❌ (mobile cấm) | ❌ (mobile cấm) | ❌ | ❌ | ❌ |
| Gửi/export dữ liệu shop cho khách | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình đăng ký nhận push cá nhân | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xóa cảnh báo/audit log | ❌ | ❌ | ❌ | ❌ | ❌ (bất biến) |

> Ranh quyền theo touchpoint: mobile nội bộ là bề mặt nhận sự kiện + tra cứu + phản hồi nhanh của staff OPS; quyết định nghiệp vụ nặng (SM duyệt kết nối/Gate 2, nạp manual, chốt Gate 3 với FIN_L1) thực hiện trên web/CORE theo bản counterpart; CUSTOMER không dùng mobile nội bộ — báo cáo khách chỉ qua Portal tenant-scoped (BR-MBI-TT-002).

---

## 5. Trường Hợp Đặc Biệt

- **Mất mạng khi xử lý cảnh báo:** ack/handling lưu hàng đợi offline nhãn "chờ đồng bộ"; khi sync nếu cảnh báo đã được người khác xử lý thì app hiển thị "đã được xử lý", không ghi đè.
- **Push tới người đã đổi portfolio:** re-assign khiến push nhầm người hết phạm vi → fallback AM hiện tại của khách; phạm vi hiển thị đánh giá lại theo token khi mở app.
- **OAuth hết hạn trong lúc xem dashboard:** cache giữ nguyên nhãn nguồn + freshness cũ, app gắn cảnh báo "dữ liệu không còn cập nhật"; kéo mới chỉ tiếp tục sau khi ủy quyền được làm mới ở GW.
- **Cảnh báo tự hết hiệu lực:** cảnh báo giấy phép/OAuth tự chuyển `OBSOLETE` khi khách gia hạn xong (CORE cập nhật điều kiện); cảnh báo lệch số liệu không tự hết — phải qua Gate 3.
- **Shop bị khóa giữa chu kỳ:** GMV/settlement các kỳ gần lệch do shop ngừng hoạt động — app đẩy cảnh báo ngay; điều chỉnh số kỳ trước chỉ xử lý ở Gate 3 trên CORE.
- **Khách từ chối cấp OAuth:** không phát cảnh báo số liệu — app chỉ hiển thị kết nối "không ủy quyền" kèm ghi chú nguồn "theo số liệu khách cung cấp" (BR-OPS-4.1); không có nhập bù từ mobile.
- **Khách yêu cầu hiển thị GMV trên Portal:** mặc định GMV là tham chiếu nội bộ; chỉ bật khi HĐ quy định qua cấu hình phạm vi riêng ở counterpart Portal — `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]` chờ chốt; mobile không có kênh phục vụ việc đó.
- **Giả định chưa chốt (không tự quyết):** 11 khoản KXN còn mở — `[KXN-6]`, `[KXN-7]`, `[KXN-9]`, `[KXN-15]`…`[KXN-22]` (`documents/quy-trinh-lam-viec/10 §4`) — đã rà, không khoản nào tác động trực tiếp tới REQ-OPS-011 (thuộc Evaluation, Strategic Brief/Report, Client Survey, RACI, LOST, HR, cờ K6–K12, mốc PAUSE); spec giữ trạng thái chờ xác nhận theo tag, không tự quyết thay khoản nào.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity trạng thái trên touchpoint mobile là **Cảnh báo shop (ShopAlert)** — state machine chạy trên CORE (counterpart), mobile phản chiếu và gửi lại hành động. Trạng thái kết nối shop thuộc bản GW/CORE — mobile chỉ xem.*

**Entity:** Cảnh báo shop (ShopAlert) — sinh từ engine cảnh báo CORE theo BR-OPS-4.6

**Sơ đồ trạng thái:**
```
[NEW] ──(ack)──► [ACKNOWLEDGED] ──(gắn ticket xử lý)──► [HANDLING] ──(xong + bằng chứng)──► [RESOLVED]
   │                    │                                    │
   │(quá SLA không ack) │(escalate)                          │(escalate)
   ▼                    ▼                                    ▼
[ESCALATED] ◄────────────────── (xử lý xong kèm bằng chứng) ─┘
   └─(điều kiện hết hiệu lực: OAuth/giấy phép được gia hạn)─► [OBSOLETE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NEW` | Acknowledge | `ACKNOWLEDGED` | OPS_ADS / OPS_AM (khách phụ trách) | Ghi người ack + timestamp server; offline queue sync đúng 1 lần |
| `NEW` | Quá SLA không ai ack | `ESCALATED` | Hệ thống (theo SLA REQ-OPS-008) | Escalate AM → OPS_PLAN theo tier×priority |
| `ACKNOWLEDGED` | Bắt đầu xử lý | `HANDLING` | OPS_ADS / OPS_AM | Đã gắn ticket SLA của khách |
| `ACKNOWLEDGED` / `HANDLING` | Escalate | `ESCALATED` | OPS_ADS / OPS_AM | Bắt buộc lý do; Tier D/E leo thang BOD theo SLA |
| `HANDLING` / `ESCALATED` | Resolve | `RESOLVED` | OPS_ADS / OPS_AM | Kèm bằng chứng: ticket ref + ghi chú đối chiếu; kết thúc |
| `NEW` / `ACKNOWLEDGED` | Điều kiện mất hiệu lực (OAuth/giấy phép gia hạn, baseline chốt lại) | `OBSOLETE` | Hệ thống (CORE) | Ghi vết lý do tự hết hiệu lực; kết thúc |

**Quy tắc:**
- `RESOLVED` và `OBSOLETE` là trạng thái kết thúc — không chuyển tiếp; cảnh báo đã escalate vẫn phải đi đến một trạng thái kết thúc.
- Resolve lệch GMV/settlement không thực hiện trước khi Gate 3 có kết luận — mobile chỉ đánh dấu "chờ đối soát", việc chốt về CORE.
- Mọi chuyển trạng thái do CORE xác nhận; CORE từ chối (ack trùng, resolve thiếu bằng chứng) thì app rollback hiển thị; mobile không tự sinh/hủy cảnh báo.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *CORE/GW là nguồn sự thật; mobile cache chỉ đọc, chỉ chứa dữ liệu đã mask/tổng hợp. DDL tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `shop_alert` (mirror) | `alert_id`, `shop_id`, `tenant_id`, `alert_type` (shop_restricted/gmv_settlement_anomaly/license_expiry/oauth_expiry/baseline_drift), `severity`, `state`, `fired_at`, `ack_by`, `ticket_ref` | FK logic → ShopConnection (GW), ticket SLA (CORE) | State machine Mục 6; nguồn sự thật trên CORE |
| `shop_metric_cache` | `shop_id`, `metric_date`, `gmv_ref`, `order_count`, `settlement_ref`, `source_label` (`api`/`manual`), `freshness_at`, `cached_at` | FK logic → ShopMetricDaily (GW/CORE) | Read-only; luôn hiển thị kèm `source_label` + `freshness_at` (BR-MBI-TT-001); auto-expire theo TTL |
| `mobile_action_queue` | `action_id`, `alert_id`, `action_type` (ack/handling/escalate/resolve), `payload`, `idempotency_key`, `created_offline_at`, `sync_status` | FK → `shop_alert.alert_id` | Hàng đợi offline; server chống ghi trùng theo idempotency (BR-MBI-TT-004) |
| `push_subscription` | `user_id`, `topic` (shop_alert theo portfolio), `channel`, `enabled` | FK → `users.id` | Đăng ký cá nhân; phạm vi portfolio do CORE phân quyền |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push shop health bất thường | Shop khách Tier C `OPERATING` bị platform khóa | CORE phát cảnh báo `shop_restricted` | OPS_ADS/OPS_AM nhận push ≤5 phút kèm shop/loại/timestamp; OPS_PLAN thấy trên tổng hợp | [ ] |
| SC-002: Cảnh báo trước hạn OAuth/giấy phép | Giấy phép shop hết hạn sau 14 ngày | Engine chạy kiểm tra hạn | OPS_AM nhận cảnh báo trước hạn theo ngưỡng CORE, kèm hạn + shop + khách | [ ] |
| SC-003: Tách bạch GMV vs NSQC ads | Khách có cả shop TikTok và TKQC quảng cáo | Mở dashboard rút gọn | GMV/settlement khối riêng nhãn "chỉ số tham chiếu của khách"; chi tiêu ads khối riêng; không view gộp | [ ] |
| SC-004: Nhãn nguồn + freshness bắt buộc | Shop `DEGRADED_MANUAL`, kỳ này nạp tay qua web | Mở chỉ số kỳ tương ứng | Hiển thị nhãn `manual` + thời điểm nạp; không bản ghi nào render thiếu nhãn/timestamp | [ ] |
| SC-005: Acknowledge offline + sync | Mất mạng, có cảnh báo lệch settlement | Ack kèm ghi chú khi offline | Xếp hàng cục bộ; sync đúng 1 lần (idempotency); CORE ghi ack theo timestamp server | [ ] |
| SC-006: Chặn PII + export trên mobile | Dữ liệu đơn chứa SĐT/địa chỉ/tên người mua cuối | Duyệt mọi màn hình + attempt export | Chỉ thấy dạng mask; không route mở phiên PII; export bị từ chối tầng API + audit log | [ ] |
| SC-007: Escalate theo SLA | Cảnh báo `NEW` quá ngưỡng SLA tier×priority | Hết hạn mức ack | Tự chuyển `ESCALATED`; push AM → OPS_PLAN; timestamp đầy đủ | [ ] |
| SC-008: Isolation tenant | 2 user khác portfolio | User A truy vấn dashboard khách B | Không trả dữ liệu; truy cập chéo bị chặn tầng service (không chỉ ẩn UI) | [ ] |

> **Liên kết:** SC-001/002/007 → REQ-OPS-011 (cảnh báo shop + ủy quyền/giấy phép + SLA); SC-003/004 → BR-OPS-4.3a/BR-MBI-TT-001 (tách bạch GMV vs NSQC ads, degraded manual); SC-006 → BR-OPS-4.2/BR-MBI-TT-002/TT-003 (mask PII, cấm kênh khách); SC-005/008 → offline + isolation.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/mobile-internal/tiktok-shop/` (inbox cảnh báo shop, dashboard rút gọn, chi tiết trạng thái kết nối) |
| Bản fan-out counterpart | `phase2-features/core-backend/tiktok-shop/` (FEAT-CORE-TIKTOK-001), `phase2-features/integration-gw/tiktok-shop/` (FEAT-GW-TIKTOK-001), `phase2-features/bcerp-web/tiktok-shop/` (FEAT-ERP-TIKTOK-001) — bản này là riêng SYS-MOBILE-INTERNAL |
| Tính năng liền kề trong lane mobile | `phase2-features/mobile-internal/sla-notif/sla-va-notification-engine.md` (FEAT-MBI-SLANOT-001 — hợp đồng push, offline queue/idempotency, escalation dùng chung) |
| Nguồn cross-dependency | REQ-OPS-008 (SLA ticket cảnh báo shop); REQ-OPS-001/003 (luồng NSQC ads tách bạch GMV — BR-OPS-4.3a); policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5; `phase1-business/P1-02-business-workflow.md` B7 (GMV chỉ tham chiếu — chặn mapping doanh thu, không OMS/WMS); `deferred-issues.md` (DI-004/005/006 resolve; DI-007 degraded mode theo dõi; KXN 6,7,9,15–22 còn mở — giả định `[KXN-n]`) |
