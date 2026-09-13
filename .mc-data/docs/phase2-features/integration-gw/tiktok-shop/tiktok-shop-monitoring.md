# Tính Năng: TikTok Shop Monitoring

> **Dựa trên:** REQ-OPS-011 trong `phase1-business/departments/operations/operations.md` (Phần A — REQ-OPS-011; Phần B.4 — BR-OPS-4.1…4.6)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** TikTok Shop Monitoring (MOD-TIKTOK-SHOP)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (B7), `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-005, DI-006, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID của bản này do lane phát hành cố định là `FEAT-GW-TIKTOK-001` (map trực tiếp từ REQ-OPS-011 — tra `req-registry.json` xác nhận SYS=SYS-INTEGRATION-GW, MOD=MOD-TIKTOK-SHOP).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-TIKTOK-001 |
| Module | MOD-TIKTOK-SHOP |
| Yêu cầu nghiệp vụ | REQ-OPS-011 — TikTok Shop Monitoring (Quan trọng/MEDIUM, GĐ3); quy tắc nguồn: BR-OPS-4.1…4.6 (`operations.md` Phần B.4, paid-media-expert Call 1/2), policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5 |
| Người dùng liên quan | OPS_AM (đề xuất kết nối, đối soát settlement), OPS_ADS (vận hành, nạp số liệu manual, xử lý cảnh báo), OPS_PLAN (xem tổng hợp portfolio), OPS_CONT/OPS_DES/OPS_EDIT (xem chỉ số shop của khách phụ trách làm căn cứ sản xuất nội dung), SALES_L4 — SM/TPKD (duyệt kết nối/Gate 2 Go-live — KXN-14), FIN_L1 (đối soát settlement — phối hợp theo BR-OPS-4.5 Gate 3), SYS_ADMIN (thực thi thu hồi ủy quyền), CUSTOMER (nhận báo cáo qua Portal — read-only, phần tenant) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | FEAT-GW-STGW-001 (REQ-BOD-008) — ConnectionProfile, credentials vault, sync scheduler, cơ chế degraded/backfill dùng chung của gateway; luồng NSQC ads nền đối soát (REQ-OPS-001/REQ-OPS-003 — feed số dư/chi tiêu TKQC gắn nhãn nguồn); workflow 3 Gate thuộc bản counterpart SYS-CORE-BACKEND |
| Ghi chú Expert (A7) | `operations.md` Mục A7: team expert chưa đánh giá chính thức tại thời điểm viết (bảng đánh giá đang chờ review) — chưa phát sinh điều chỉnh nào đối với REQ-OPS-011; BR-OPS-4.1…4.6 giữ nguyên trạng thái do paid-media-expert biên soạn ở Call 1/2 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Bản SYS-INTEGRATION-GW của REQ-OPS-011 vận hành tầng kết nối dữ liệu TikTok Shop cho toàn hệ thống: thiết lập ủy quyền OAuth per-client với từng shop của khách (cấm ủy quyền gom chung), kéo định kỳ các chỉ số GMV/đơn/settlement/shop health về hệ thống gắn nhãn nguồn, xử lý dữ liệu nhạy cảm người mua cuối theo cơ chế phiên TTL không lưu vết, và bảo đảm luồng monitoring không bao giờ đứt khi chưa được cấp hoặc bị mất quyền API — khi đó hạ xuống degraded mode `manual` (import/nhập có cấu trúc) kèm backfill tự động khi API sống lại. Điểm cốt lõi nghiệp vụ là **tách bạch tuyệt đối** giữa dữ liệu GMV/settlement của shop (thuộc về khách, chỉ là chỉ số tham chiếu) và ngân sách quảng cáo NSQC ads mà BC điều phối (tiền giữ hộ, đối soát qua luồng TKQC riêng) — hai luồng dữ liệu này không bao giờ được trộn record, và GMV tuyệt đối không được map vào doanh thu agency.

**Phạm vi:**
- Bao gồm: thực thi OAuth per-client từng shop (lưu scope, access log bất biến, phiên TTL cho dữ liệu PII), pull định kỳ GMV/đơn/settlement/shop health theo khách, lưu raw payload phục vụ đối chiếu.
- Bao gồm: degraded mode `manual` cho TikTok Shop API — schema import chuẩn (shop, ngày, loại chỉ số, số tiền gốc, tiền tệ, mã tham chiếu) + nhập tay có cấu trúc, sai schema bị chặn tầng gateway; backfill tự động khi được cấp quyền API, đối soát lại kỳ đã nhập tay (cùng cơ chế nhãn nguồn `api`/`manual` với DI-007).
- Bao gồm: cung cấp feed dữ liệu báo cáo đã tổng hợp và mask cho báo cáo khách trên Portal (phần của tenant, read-only, qua Portal API Gateway của core — gateway không serve trực tiếp portal) và cho dashboard nội bộ GMV/shop health trên web; ranh giới chỉ số GMV hiển thị cho khách theo hợp đồng `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]`.
- Bao gồm: đẩy tín hiệu cảnh báo (shop bị hạn chế/khóa, GMV/settlement lệch bất thường, giấy phép ngành hàng và OAuth sắp hết hạn, baseline lệch) cho hệ thống cảnh báo và push M-INT tiêu thụ.
- Không bao gồm: workflow 3 Gate (Verification → Go-live → Đối soát định kỳ) và validation chặn mapping GMV vào sổ doanh thu — thuộc bản counterpart SYS-CORE-BACKEND; gateway nhận tín hiệu trạng thái gate từ core để bật/tắt pull.
- Không bao gồm: dashboard GMV/shop health cho OPS trên web nội bộ, màn hình import/nhập tay, màn hình duyệt kết nối — thuộc bản counterpart SYS-BCERP-WEB; cảnh báo push cho OPS_ADS/OPS_AM thuộc bản SYS-MOBILE-INTERNAL.
- Không bao gồm: quản lý đơn hàng, fulfillment, tồn kho — **KHÔNG làm OMS/WMS** (BR-OPS-4.3); gateway chỉ monitoring, mọi yêu cầu nhận fulfillment phải có phụ lục HĐ phạm vi/trách nhiệm/phí riêng và nằm ngoài module này.
- Không bao gồm: ghi nhận doanh thu từ phí dịch vụ/phí ads thu hộ/phí vận hành shop và phần share theo GMV — thuộc tài chính core; gateway chỉ cung cấp số settlement đối chiếu làm căn cứ.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-INTEGRATION-GW — tầng gateway/adapter headless: việc kéo dữ liệu chạy tự động do scheduler của FEAT-GW-STGW-001 điều phối, con người không thao tác trực tiếp trên gateway mà qua các hệ thống gọi API của nó — web nội bộ (responsive browser UI) gọi kênh import/nhập tay khi degraded, core (headless API/domain service, BR enforce ở service layer) tiêu thụ dữ liệu vào fact tables và workflow 3 Gate, Portal (khách hàng, read-only phần tài chính, tenant isolation) hiển thị báo cáo từ feed đã mask tổng hợp, mobile nội bộ (React Native offline-capable) nhận cảnh báo. Trạng thái kết nối và nhãn nguồn `api`/`manual` là machine-state do gateway giữ; mọi vai người dùng chỉ xem trạng thái hoặc thao tác qua touchpoint trên.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Đề xuất kết nối ủy quyền OAuth riêng cho từng shop của khách với scope đọc ghi rõ, chờ SM duyệt | Dữ liệu GMV/settlement/shop health về đúng theo khách, truy vết được căn cứ pháp lý của từng ủy quyền |
| 2 | SALES_L4 (TPKD/SM — KXN-14) | Duyệt/từ chối yêu cầu kết nối shop và ký Gate 2 Go-live kèm baseline KPI chốt lúc bàn giao | Kiểm soát ranh giới trách nhiệm pháp lý trước khi hệ thống bắt đầu kéo dữ liệu của khách |
| 3 | Hệ thống (scheduler gateway) | Pull định kỳ GMV/đơn/settlement/shop health theo từng shop qua OAuth per-client, lưu raw payload, gắn nhãn `api` | Dashboard nội bộ và báo cáo Portal luôn có dữ liệu tươi, nguồn gốc rõ ràng, đối chiếu được về gốc |
| 4 | OPS_ADS | Khi chưa có quyền TikTok Shop API (degraded), nạp số liệu GMV/đơn/settlement theo schema chuẩn qua kênh import có gắn người nạp + căn cứ | Monitoring tiếp diễn như luồng API, không dừng chờ Business Verification (DI-007) |
| 5 | OPS_ADS | Nhận tín hiệu cảnh báo shop health bất thường, settlement lệch, giấy phép/OAuth sắp hết hạn qua hệ thống push | Xử lý theo SLA ticket của khách trước khi shop bị khóa hoặc ủy quyền đứt giữa chừng |
| 6 | OPS_AM | Khi HĐ kết thúc hoặc khách yêu cầu, hệ thống tự thu hồi ủy quyền trong 24h và tôi xác nhận bằng văn bản với khách | Không còn trạng thái "quên thu hồi" gây rủi ro truy cập dữ liệu khách ngoài thời gian hợp đồng |
| 7 | OPS_PLAN | Xem tổng hợp GMV/shop health theo portfolio khách và theo ngành | Lập kế hoạch nguồn lực và nhận diện khách có shop tăng trưởng cần mở rộng dịch vụ |
| 8 | OPS_CONT/OPS_DES/OPS_EDIT | Xem chỉ số GMV theo sản phẩm/danh mục của shop khách mình phụ trách (đã tổng hợp, mask PII) | Ưu tiên sản xuất content/livestream cho nhóm sản phẩm đang tăng trưởng, căn cứ vào số thực thay vì cảm tính |
| 9 | FIN_L1 | Lấy dữ liệu settlement/đơn/ads đã gắn nhãn nguồn theo kỳ đối soát của từng shop | Chạy Gate 3 đối soát settlement vs đơn vs ads định kỳ theo tần suất HĐ (mặc định hàng tháng) |
| 10 | CUSTOMER (Portal) | Xem báo cáo GMV/đơn/settlement tổng hợp của tenant mình trên Portal, chỉ số hiển thị theo đúng phạm vi hợp đồng | Minh bạch kết quả shop mà không lộ bất kỳ dữ liệu nội bộ hay dữ liệu tenant khác |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-4.1a | **OAuth per-client bắt buộc:** mỗi shop 1 ủy quyền OAuth riêng từng khách, scope đọc ghi rõ trên bản ghi kết nối; cấm ủy quyền gom chung nhiều shop, cấm đăng nhập chủ shop chia sẻ; gateway lưu scope + access log bất biến (ai, khi nào, API/đối tượng dữ liệu, scope) | Kết nối không có scope ghi rõ hoặc gom nhiều shop bị từ chối thiết lập; mọi truy cập không qua ủy quyền hợp lệ bị chặn và ghi audit log |
| BR-OPS-4.1b | **OAuth hết hạn giữa chừng → dừng kéo dữ liệu mới + cảnh báo:** gateway không tự xin mở rộng scope thiếu đồng ý của khách; dữ liệu đã kéo giữ nguyên gắn nhãn nguồn và mốc thời gian | Pull sau thời điểm hết hạn không được thực hiện; hệ thống bắn cảnh báo và đưa kết nối sang trạng thái treo chờ làm mới ủy quyền |
| BR-OPS-4.1c | **Thu hồi ủy quyền trong 24h khi hết HĐ/khách yêu cầu:** tự động theo sự kiện hợp đồng + AM xác nhận bằng văn bản cho khách; sau thu hồi, mọi pull bị vô hiệu, dữ liệu lịch sử giữ nguyên để đối chiếu | Job thu hồi quá 24h là sự cố nghiêm trọng — alert BOD_CFO_CTO; pull sau thu hồi bị chặn tầng gateway và ghi log vi phạm |
| BR-OPS-4.2a | **Mask PII người mua cuối mặc định + phiên TTL:** SĐT dạng `090****123`, địa chỉ chỉ còn tỉnh/huyện, tên người mua cuối được mask; dữ liệu đầy đủ chỉ tồn tại trong phiên có TTL, không persist vào DB — gateway xử lý phiên, core mask ở tầng API | Dữ liệu PII đầy đủ xuất hiện ngoài phiên TTL hoặc được ghi DB là lỗi P0 — tính năng phải bảo đảm cấu trúc không cho phép ghi; attempt mở phiên không có lý do bị từ chối |
| BR-OPS-4.2b | **Tenant isolation giữa shops:** dữ liệu shop A không bao giờ xuất hiện trong báo cáo/API/export của shop B (tách theo tenant + client code); test truy cập chéo hàng quý | Truy vấn chéo tenant bị Row-Level Security chặn tầng API; kết quả test rò rỉ chéo là lỗi nghiêm trọng phải xử lý trước mọi release |
| BR-OPS-4.3a | **Sync qua GW + tách bạch GMV shop vs NSQC ads:** GMV/đơn/settlement/shop health kéo từ luồng TikTok Shop riêng theo OAuth per-client; chi tiêu NSQC ads nằm ở luồng TKQC quảng cáo (REQ-OPS-001/REQ-OPS-003) — hai luồng giữ key dữ liệu và nguồn riêng, không trộn record; khi đối soát, số ads chỉ được join qua mã tham chiếu ở lớp tổng hợp core | Dữ liệu GMV và dữ liệu chi tiêu ads ghi đè/lẫn vào cùng một record bị reject tầng gateway; báo cáo nào hiển thị GMV trộn chung chi tiêu NSQC không được chấp nhận |
| BR-OPS-4.3b | **Ranh giới KHÔNG làm OMS/WMS:** gateway chỉ monitoring — không quản lý đơn/fulfillment/tồn kho, không gửi lệnh vận hành về shop | Mọi endpoint ghi thao tác đơn/fulfillment không được phép tồn tại; yêu cầu phát sinh phải đi lộ trình phụ lục HĐ và module riêng |
| BR-OPS-4.4 | **Tách bạch tuyệt đối GMV khỏi P&L agency:** GMV/settlement là chỉ số tham chiếu thuộc về khách — mọi bản ghi đều mang cờ `reference_only`; doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ (+ phí vận hành shop nếu HĐ quy định); HĐ chia share theo GMV (nếu có) chỉ ghi nhận phần share sau khi settlement đối soát khớp, không bao giờ ghi nhận toàn bộ GMV | Mapping GMV/settlement vào tài khoản doanh thu bị chặn tầng API (không chỉ UI); báo cáo nào hàm ý GMV là doanh thu BC bị coi là vi phạm red line tài chính |
| BR-OPS-4.5 | **Lifecycle 3 Gate:** Gate 1 Verification — checklist chủ shop + giấy phép ngành hàng hợp lệ, lưu ngày hết hạn + cảnh báo trước hạn, AM + FIN_L1 đối chiếu pháp lý; Gate 2 Go-live — SM ký + baseline KPI chốt lúc bàn giao; Gate 3 Đối soát định kỳ — settlement vs đơn vs ads theo tần suất HĐ (mặc định hàng tháng), chênh lệch vượt ngưỡng điều tra ≤3 ngày làm việc (FIN_L1 + AM). Gateway chỉ bật pull sau tín hiệu Gate 2 từ core | Kết nối chưa qua Gate 2 không được phép pull dữ liệu sản xuất; pull trước gate bị chặn và ghi log — gate check thực thi ở core nhưng gateway phải tự kiểm tra trạng thái trước mỗi job |
| BR-OPS-4.6 | **Cảnh báo SLA shop:** shop bị hạn chế/khóa, GMV/settlement lệch bất thường, giấy phép & OAuth sắp hết hạn, baseline lệch → gateway phát tín hiệu, hệ thống cảnh báo push M-INT cho OPS_ADS/OPS_AM; xử lý theo SLA ticket của khách (ma trận tier×priority — REQ-OPS-008); không SLA riêng cho fulfillment (ngoài phạm vi) | Tín hiệu cảnh báo phải kèm shop, loại cảnh báo, timestamp và giá trị lệch; cảnh báo mất/giả do gateway lỗi sync được đối chiếu qua raw payload |
| BR-GW-TT-001 | **Degraded mode `manual` khi mất API + backfill (DI-007):** Business Verification chưa có quyền developer nên khởi điểm luồng shop là manual — import/nhập tay theo schema chuẩn (shop, ngày, loại chỉ số, số tiền gốc, tiền tệ, mã tham chiếu) gắn nhãn `manual` + người nạp + căn cứ; khi được cấp API, gateway backfill toàn bộ khoảng đứt, gắn lại nhãn `api`, kích hoạt đối soát lại kỳ đã nhập tay, bản ghi manual giữ làm vết | Batch sai schema bị chặn theo dòng (dòng hợp lệ vẫn nhận); backfill không được ghi đè/xóa bản ghi manual; dữ liệu manual thiếu người nạp/căn cứ bị từ chối đưa vào đối soát |
| BR-GW-TT-002 | **Báo cáo khách qua Portal (tenant-scoped, read-only) + dashboard nội bộ:** gateway cung cấp feed chỉ số đã tổng hợp và mask theo tenant cho báo cáo khách trên Portal — read-only, hiển thị theo cấu hình phạm vi hợp đồng từng tenant, tách network zone qua Portal API Gateway của core, không chạm DB nội bộ; dashboard nội bộ GMV/shop health tiêu thụ cùng dữ liệu gốc có nhãn nguồn | Feed portal thiếu filter tenant hoặc chứa trường chưa được cấu hình cho tenant đó bị chặn; dữ liệu đưa lên portal phải qua lớp tổng hợp đã mask — bản raw PII không bao giờ xuất hiện trên bất kỳ touchpoint khách |

---

## 4. Phân Quyền

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT | SALES_L4 (SM) | FIN_L1 | SYS_ADMIN |
|-----------|---------|--------|----------|-------------------|---------------|--------|-----------|
| Đề xuất kết nối OAuth / mở scope | ✅ | ✅ (đề xuất chính) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt kết nối / ký Gate 2 Go-live | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Xem dashboard GMV/shop health nội bộ (khách phụ trách) | ✅ | ✅ | ✅ (toàn portfolio) | ✅ (chỉ số shop gắn dự án mình) | ✅ (khách của mình) | ✅ | ✅ |
| Nạp số liệu degraded `manual` qua kênh import/nhập có cấu trúc | ✅ | ✅ (bổ trợ) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem trạng thái kết nối, scope, nhãn nguồn, tuổi dữ liệu từng shop | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| Xác nhận thu hồi ủy quyền khi hết HĐ | ❌ | ✅ (xác nhận văn bản với khách) | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi sau sự kiện HĐ) |
| Mở phiên dữ liệu PII đầy đủ (có TTL, có lý do) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Đối soát settlement vs đơn vs ads (Gate 3) | ❌ | ✅ (cùng điều tra chênh lệch) | ❌ | ❌ | ❌ | ✅ (chủ trì) | ❌ |
| Cấu hình phạm vi chỉ số GMV hiển thị trên Portal cho tenant | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (theo cấu hình HĐ, có audit log) |
| Xem báo cáo GMV/settlement trên Portal | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ CUSTOMER của tenant — read-only) |

> Ranh quyền theo touchpoint: gateway là tầng adapter — không có màn hình thao tác riêng cho người dùng; OPS_ADS/OPS_AM thao tác nạp manual và xem trạng thái qua web nội bộ (bản counterpart SYS-BCERP-WEB), CUSTOMER chỉ đọc báo cáo trên Portal qua feed tenant-scoped read-only, không có bất kỳ quyền thao tác nào trên gateway; BOD_CEO/BOD_CFO_CTO sở hữu hạ tầng gateway chung qua FEAT-GW-STGW-001 nhưng không can thiệp dữ liệu shop theo tenant.

---

## 5. Trường Hợp Đặc Biệt

- **Khách từ chối cấp OAuth:** BC không truy cập dữ liệu shop; báo cáo ghi rõ nguồn "theo số liệu khách cung cấp" và BC không chịu trách nhiệm đối soát — gateway không có cơ chế nhập bù trong trường hợp này, kết nối dừng ở trạng thái không ủy quyền.
- **Khởi điểm chưa có quyền TikTok Shop API (DI-007):** toàn bộ các shop khởi động ở degraded `manual` — import/nhập tay theo schema là trạng thái vận hành chính thức chứ không phải nhánh ngoại lệ; mốc được cấp quyền API của TikTok Shop chưa xác định nên spec không đặt giả định thời gian, backfill chỉ kích hoạt khi sự kiện xảy ra.
- **Khách tự vận hành shop, BC chỉ chạy ads:** Gate 1 rút gọn còn ownership + scope đọc, không cần Gate 2 full (theo BR-OPS-4.5); gateway cấu hình profile kết nối rút gọn tương ứng, không kéo các chỉ số ngoài scope đã duyệt.
- **OAuth hết hạn giữa phiên kéo dữ liệu:** cửa sổ pull đang chạy bị ngưng tại thời điểm hết hạn — phần dữ liệu đã về giữ nguyên gắn nhãn `api` kèm timestamp, phần còn lại không tự ý kéo tiếp; gateway bắn cảnh báo và chờ làm mới ủy quyền, không retry bằng credential cũ.
- **Shop bị platform hạn chế/khóa giữa chu kỳ:** shop health phản ánh trạng thái bất thường, tín hiệu cảnh báo đẩy ngay cho OPS_ADS/OPS_AM xử lý theo SLA ticket của khách; gateway không tự can thiệp hay "sửa" dữ liệu các kỳ trước — số lệch do shop khóa xử lý ở Gate 3 đối soát.
- **Nhiều shop cùng một khách (đa nhãn hàng/multi-tenant):** mỗi pháp nhân/nhãn hàng là một tenant riêng — không tổng hợp chéo tenant ngay cả cùng chủ sở hữu; báo cáo gộp (nếu HĐ yêu cầu) chỉ thực hiện ở lớp tổng hợp core trên các số liệu đã mask, không bao giờ ở lớp raw của gateway.
- **HĐ chia share theo GMV:** gateway cung cấp số settlement đối chiếu; phần share chỉ được ghi nhận doanh thu ở core sau khi settlement đối soát khớp — nếu Gate 3 phát hiện chênh lệch vượt ngưỡng, việc ghi nhận share tạm dừng đến khi điều tra xong (≤3 ngày làm việc).
- **Khách yêu cầu hiển thị GMV trên Portal:** mặc định GMV không thuộc nhóm dữ liệu khách thấy; hiển thị chỉ bật khi HĐ quy định và qua cấu hình phạm vi riêng — phạm vi chỉ số cụ thể `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]` chờ chốt, spec thiết kế cơ chế cấu hình theo tenant để không phải đổi code khi chốt số.
- **Các KXN còn mở (KXN-6, 7, 9, 15–22):** đã rà — không khoản nào trực tiếp điều chỉnh REQ-OPS-011 (các khoản thuộc Evaluation, Strategic Brief/Report, phạm vi "tương lai", Client Survey, node trùng, LOST, HR, RACI, cờ K6–K12, mốc PAUSE); spec này không tự quyết thay khoản nào và giữ các giả định nêu trên ở trạng thái chờ xác nhận.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kết nối ủy quyền shop (ShopConnection) — trạng thái kết nối OAuth và lifecycle gate của từng shop; workflow 3 Gate sở hữu ở core (counterpart SYS-CORE-BACKEND), gateway phản chiếu trạng thái để điều khiển pull.

**Sơ đồ trạng thái:**
```
[PROPOSED] ──(SM duyệt)──► [VERIFYING — Gate 1] ──(checklist đạt + OAuth cấp + Gate 2 ký)──► [OPERATING]
     │                            │                                                                │        │
     │ (từ chối)                  │ (checklist fail / giấy phép không hợp lệ)                       │        │(OAuth hết hạn/mất quyền)
     ▼                            ▼                                                                │        ▼
 [REJECTED]                  [VERIFYING — khắc phục]                                        [DEGRADED_MANUAL]◄─┘
                                                                                                  │
                                                                            (API sống lại + backfill xong) → [OPERATING]
                                                                                                  │
                                                                                  (hết HĐ / khách yêu cầu, ≤24h)
                                                                                                  ▼
                                                                                             [REVOKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PROPOSED` | SM duyệt | `VERIFYING` | SALES_L4 | Bản ghi đề xuất có scope ghi rõ, đúng 1 shop/1 khách |
| `PROPOSED` | Từ chối | `REJECTED` | SALES_L4 | Ghi lý do — trạng thái kết thúc |
| `VERIFYING` | Checklist đạt + OAuth cấp + Gate 2 ký | `OPERATING` | Core (workflow gate) + SALES_L4 | Checklist chủ shop + giấy phép ngành hàng hợp lệ; baseline KPI chốt; gateway nhận tín hiệu Gate 2 |
| `VERIFYING` | Checklist fail | `VERIFYING` (khắc phục) | OPS_AM cập nhật hồ sơ | Lý do thiếu được ghi; cảnh báo ngày hết hạn giấy phép đã lưu |
| `OPERATING` | Mất OAuth / mất quyền API | `DEGRADED_MANUAL` | Hệ thống (tự động) | Dừng pull mới; các kỳ thiếu nhận dữ liệu nhãn `manual` qua import schema chuẩn |
| `DEGRADED_MANUAL` | API sống lại + backfill | `OPERATING` | Hệ thống | Backfill phủ đủ khoảng đứt, gắn nhãn `api`; bản ghi manual giữ làm vết; đối soát lại kỳ manual kích hoạt |
| `OPERATING`/`DEGRADED_MANUAL` | Thu hồi ủy quyền (hết HĐ/khách yêu cầu) | `REVOKED` | Hệ thống (theo sự kiện HĐ) + SYS_ADMIN | Hoàn tất ≤24h; AM xác nhận văn bản với khách; pull bị vô hiệu vĩnh viễn |
| `OPERATING` | Shop bị platform hạn chế/khóa | `OPERATING` (giữ, gắn cờ health) | Hệ thống | Chỉ gắn cờ shop health + bắn cảnh báo; không chuyển trạng thái kết nối |

**Quy tắc:**
- `REJECTED` và `REVOKED` là trạng thái kết thúc — không chuyển tiếp; sau `REVOKED` không có bất kỳ pull nào kể cả backfill, dữ liệu lịch sử giữ nguyên phục vụ đối chiếu và truy vết.
- Chỉ trạng thái `OPERATING` cho phép pull nhãn `api`; `DEGRADED_MANUAL` chỉ nhận kênh import/nhập có cấu trúc — hai trạng thái quyết định nhãn nguồn gắn trên từng bản ghi tại thời điểm ghi.
- Mọi chuyển trạng thái ghi audit log bất biến kèm trigger (job id, sự kiện HĐ, người thao tác, mã lỗi).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ShopConnection | `shop_id`, `tenant_id`, `client_code`, `oauth_scope`, `status` (PROPOSED/VERIFYING/OPERATING/DEGRADED_MANUAL/REJECTED/REVOKED), `gate_stage`, `authorized_at`, `expires_at`, `revoked_at` | FK logic → tenant/client registry (core) | 1 shop — 1 ủy quyền — 1 khách; access log bất biến kèm theo |
| ShopAccessLog | `connection_id`, `actor`, `action`, `api_object`, `scope_used`, `occurred_at` | FK → ShopConnection.id | Append-only, không sửa/xóa hậu kiểm (BR-OPS-4.1a) |
| ShopMetricDaily | `shop_id`, `metric_date`, `gmv`, `order_count`, `settlement_amount`, `shop_health_flags`, `source_label` (`api`/`manual`), `reference_only` (luôn true), `entered_by`, `evidence_ref` | FK → ShopConnection.id | `reference_only` chặn mọi mapping doanh thu (BR-OPS-4.4); raw payload lưu riêng trước chuẩn hóa |
| SettlementReconPeriod | `shop_id`, `period`, `settlement_total`, `order_total`, `ads_spend_ref` (luồng NSQC riêng), `diff_status`, `investigated_by`, `closed_at` | FK → ShopConnection.id; join qua mã tham chiếu tới fact ads (core) | Đầu vào Gate 3 — kỳ đối soát theo tần suất HĐ, mặc định hàng tháng |
| PiiAccessSession | `session_id`, `shop_id`, `requested_by`, `reason`, `ttl_expires_at`, `closed_at` | FK → ShopConnection.id | Dữ liệu PII đầy đủ không persist — chỉ tồn tại trong TTL phiên (BR-OPS-4.2a) |
| PortalReportFeed | `tenant_id`, `report_period`, `metrics_payload` (đã mask, đã tổng hợp), `visibility_config_version` | FK → tenant; nguồn từ ShopMetricDaily đã lọc | Chỉ chứa trường theo cấu hình phạm vi HĐ từng tenant (BR-GW-TT-002, `[CẦN CHỐT SỐ]` phạm vi) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: OAuth per-client + isolation | 2 shop thuộc 2 tenant khác nhau, cả hai đã `OPERATING` | Truy vấn dữ liệu shop A với ngữ cảnh tenant B | Row-Level Security chặn — không trả bản ghi nào của shop A; test truy cập chéo hàng quý ghi nhận PASS | [ ] |
| SC-002: Pull định kỳ gắn nhãn `api` | Kết nối shop ở `OPERATING`, OAuth còn hạn | Scheduler chạy cửa sổ pull | GMV/đơn/settlement/shop health về hệ thống, raw payload lưu, bản ghi gắn nhãn `api` + `reference_only`, dashboard nội bộ hiển thị kèm freshness | [ ] |
| SC-003: Degraded manual theo schema | Chưa có quyền TikTok Shop API (DI-007) | OPS_ADS nạp import GMV/đơn/settlement theo schema chuẩn | Bản ghi nhận với nhãn `manual`, `entered_by` + `evidence_ref` bắt buộc; dòng sai schema bị trả lỗi theo dòng, không tạo record hỏng | [ ] |
| SC-004: OAuth hết hạn giữa chừng | Kết nối đang pull, token hết hạn tại thời điểm t | Cửa sổ pull hiện tại chạy | Pull ngưng tại thời điểm hết hạn; dữ liệu đã về giữ nhãn `api` + timestamp; cảnh báo đẩy cho OPS_ADS/OPS_AM; không retry bằng credential cũ | [ ] |
| SC-005: Thu hồi ủy quyền ≤24h khi hết HĐ | HĐ của khách kết thúc — sự kiện HĐ phát sinh | Job thu hồi chạy theo sự kiện | Kết nối chuyển `REVOKED` trong 24h; mọi pull sau đó bị chặn và ghi log; SYS_ADMIN/OPS_AM xác nhận hoàn tất; dữ liệu lịch sử giữ nguyên | [ ] |
| SC-006: Mask PII + phiên TTL | Dữ liệu đơn chứa SĐT/địa chỉ/tên người mua cuối | Đọc dữ liệu ngoài phiên, rồi mở phiên TTL có lý do | Ngoài phiên: mọi trường PII hiển thị dạng mask (`090****123`, tỉnh/huyện); trong phiên TTL: dữ liệu đầy đủ, hết TTL tự đóng, không có bản ghi PII đầy đủ nào được persist | [ ] |
| SC-007: Chặn mapping GMV vào doanh thu | Có bản ghi ShopMetricDaily `reference_only=true` | Attempt mapping GMV/settlement vào tài khoản doanh thu ở tầng API | Bị chặn cứng tầng API (không chỉ UI), attempt ghi audit log; báo cáo không có bất kỳ view nào hiển thị GMV như doanh thu BC | [ ] |
| SC-008: Feed Portal tenant-scoped read-only | Tenant có `visibility_config` theo HĐ | Portal khách truy vấn báo cáo GMV kỳ hiện tại | Chỉ trả chỉ số thuộc phạm vi cấu hình, đã mask + tổng hợp, qua Portal API Gateway zone riêng; tenant không thấy dữ liệu tenant khác; không có hành động ghi nào trên portal feed | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-011 (Mục 2 — OAuth per-client + thu hồi 24h + cảnh báo hết hạn; mask PII + phiên TTL; tách bạch GMV; sync qua GW + degraded manual; lifecycle 3 Gate/đối soát; báo cáo khách qua Portal tenant + dashboard nội bộ).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/tiktok-shop/` (dashboard GMV/shop health, kênh import manual, duyệt kết nối — bản counterpart SYS-BCERP-WEB), `phase4-ux/mobile-internal/tiktok-shop/` (cảnh báo push — bản counterpart SYS-MOBILE-INTERNAL) |
| Bản fan-out counterpart | `phase2-features/core-backend/tiktok-shop/` (workflow 3 Gate, validation chặn mapping GMV, tổng hợp đối soát), `phase2-features/bcerp-web/tiktok-shop/` (dashboard + màn hình OPS), `phase2-features/mobile-internal/tiktok-shop/` (cảnh báo) — REQ-OPS-011 xuất hiện ở 4 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane gateway | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` + `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-001/002 — hạ tầng ConnectionProfile, vault, scheduler, cơ chế nhãn nguồn `api`/`manual` + backfill dùng chung) |
| Nguồn cross-dependency | REQ-OPS-001/REQ-OPS-003 — luồng NSQC ads tách bạch với GMV shop (BR-OPS-4.3a); REQ-OPS-008 — SLA ticket xử lý cảnh báo shop; policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5; `phase1-business/P1-02-business-workflow.md` B7 (GMV/settlement chỉ tham chiếu — chặn mapping doanh thu, không OMS/WMS); `work/wf-analyze-requirements/deferred-issues.md` (DI-004/005/006 đã resolve; DI-007 degraded mode; KXN 6,7,9,15–22 còn mở — không đụng trực tiếp REQ này) |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
