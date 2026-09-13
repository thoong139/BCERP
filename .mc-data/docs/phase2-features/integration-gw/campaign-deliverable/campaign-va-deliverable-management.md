# Tính Năng: Campaign & Deliverable Management (Integration Gateway)

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A, Phần B.7 — BR-OPS-7.1…7.6)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 3 — Campaign Delivery), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-006 — Campaign & Deliverable Management (HIGH, GĐ2); fan-out 6 systems (CORE, GW, WEB, M-INT, PORTAL, M-PORTAL) — bản này là riêng SYS-INTEGRATION-GW |
| Người dùng liên quan | OPS_PLAN (soạn WBS — qua WEB), OPS_AM (đề xuất nghiệm thu, duyệt vượt hạn mức), OPS_CONT/OPS_DES/OPS_EDIT (pipeline creative — qua WEB), OPS_ADS (vận hành campaign, ghi nhận thay đổi manual), SYS_ADMIN (cấu hình adapter), BOD_CFO_CTO (CTO điều hành degraded), CUSTOMER (chỉ qua PORTAL/M-PORTAL — GW không có kênh cho khách) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-GW-STGW-001 — connection profile, credentials vault, sync scheduler, cơ chế degraded/backfill của gateway; FEAT-GW-STGW-002 — luồng pull hourly 7 nền tảng dùng chung hạ tầng pull + nhãn nguồn `api`/`manual`; REQ-OPS-001 — naming/UTM chuẩn dùng để map campaign platform ↔ dự án |
| Ghi chú Expert (A7) | operations.md Mục A7: chưa có đánh giá expert chính thức tại thời điểm viết (chờ review); business rules B.7 do marketing-expert viết call-2; các con số SLA duyệt creative, vòng sửa creative, chờ confirm nghiệm thu đã chốt theo DI-005 (12/09/2026) — ghi nhận DI-007: Business Verification 7 nền tảng chưa có quyền API nên degraded mode `manual` là trạng thái khởi điểm |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là bề mặt Integration Gateway của REQ-OPS-006: đẩy mọi thay đổi campaign đã duyệt (ngân sách, bid, target, audience, creative chính) xuống đúng campaign trên 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), và kéo chi tiêu thực tế theo campaign về hệ thống để CORE đối chiếu hiệu quả và báo cáo chi tiêu theo dự án/milestone. Khi mất quyền API (DI-007 — Business Verification chưa xong), gateway vẫn phải sống: thay đổi được áp dụng trực tiếp trên platform rồi ghi nhận qua kênh manual có cấu trúc, chi tiêu nhập từ statement chuẩn, và khi API sống lại hệ thống backfill + reconcile phát hiện mọi lệch pha giữa platform và change log.

**Phạm vi:**
- Bao gồm: adapter push thay đổi campaign xuống platform — chỉ nhận payload đã `APPROVED` ở change log của CORE, có tham chiếu change log entry + reason; retry/backoff khi push fail; lưu raw payload phản hồi của platform.
- Bao gồm: pull chi tiêu (spend) theo campaign hourly, map campaign platform ID ↔ dự án qua naming/UTM chuẩn REQ-OPS-001; campaign không map được bị treo trạng thái `UNMAPPED` và không được đưa vào báo cáo theo khách.
- Bao gồm: degraded mode `manual` bắt buộc — kênh ghi nhận thay đổi đã áp tay trên platform (field, giá trị cũ/mới, reason, evidence, người áp, nhãn `manual` + nguồn + timestamp) và kênh nhận chi tiêu manual theo schema statement chuẩn; backfill + reconcile khi API được cấp.
- Bao gồm: feed chi tiêu theo campaign/milestone phục vụ nghiệm thu và báo cáo hiệu quả cho CORE; tách bạch dữ liệu hiệu suất QC TikTok (TikTok for Business) với GMV TikTok Shop (REQ-OPS-011) ngay ở tầng dữ liệu gateway.
- Không bao gồm: WBS, editorial calendar, pipeline duyệt creative đa vai, change log engine, phân bậc duyệt hạn mức — thuộc SYS-CORE-BACKEND (workflow) và SYS-BCERP-WEB (nơi thao tác); gateway chỉ nhận kết quả đã duyệt.
- Không bao gồm: màn hình khách confirm nghiệm thu — thuộc bản counterpart SYS-PORTAL-WEB/SYS-MOBILE-PORTAL; gateway không phục vụ trực tiếp bất kỳ request nào của khách.
- Không bao gồm: capacity check khi gán task (REQ-OPS-007), SLA ticket engine (REQ-OPS-008), dữ liệu hiệu quả theo variant A/B (FEAT-GW-CAMP-002), connector phần mềm kế toán VAS (REQ-FIN-013 tại MOD-SETTINGS-GW).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-INTEGRATION-GW là tầng gateway/adapter headless: không có màn hình, mọi thao tác con người đi qua web nội bộ (SYS-BCERP-WEB) hoặc mobile nội bộ (SYS-MOBILE-INTERNAL) rồi gọi API gateway; các luồng push/pull chạy tự động do scheduler điều phối. Gateway chịu trách nhiệm thực thi ràng buộc ở biên giới hệ thống: không đẩy gì lên platform mà thiếu change log entry, không nhận gì về mà thiếu nhãn nguồn.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (gateway adapter) | Nhận change log entry trạng thái `APPROVED` của CORE và tự động push giá trị mới xuống đúng campaign platform ID | Thay đổi ngân sách/bid/target/audience/creative đã duyệt được áp dụng ngoài platform mà không ai phải thao tác tay lần thứ hai |
| 2 | OPS_ADS | Bị chặn ngay nếu cố đẩy thay đổi không có reason/tham chiếu change log | Mọi thay đổi trên platform đều truy vết được người quyết định và lý do — không có thay đổi "ma" |
| 3 | OPS_ADS | Khi mất API, ghi nhận thay đổi tôi đã áp tay trên platform theo form có cấu trúc kèm evidence (chụp màn hình platform) | Change log vẫn đầy đủ giá trị cũ/mới và platform không bị lệch so với hệ thống khi API sống lại |
| 4 | Hệ thống (gateway adapter) | Pull chi tiêu theo campaign hourly, map về dự án qua naming/UTM, gắn nhãn nguồn `api`/`manual` | CORE có số chi tiêu tươi ≤1h để đối chiếu hiệu quả và báo cáo theo khách, biết rõ từng con số đến từ đâu |
| 5 | OPS_AM | Nhận feed chi tiêu thực tế theo milestone khi đề xuất nghiệm thu cho khách | Quyết định nghiệm thu dựa trên số đã chi thực tế, không đoán |
| 6 | OPS_PLAN | Khi API nền tảng sống lại, hệ thống backfill và reconcile hiện trạng platform với change log | Mọi thay đổi phát sinh ngoài hệ thống trong thời gian mất API bị phát hiện và buộc giải trình |
| 7 | BOD_CFO_CTO | Nhìn thấy trạng thái từng adapter campaign feed (api/manual/degraded), tuổi dữ liệu và các push fail | Biết nguồn nào đang stale để điều hành hạ tầng, không để dữ liệu đứt lặng lẽ |
| 8 | CUSTOMER | (qua PORTAL/M-PORTAL counterpart) Xem tiến độ deliverable đã share và confirm nghiệm thu theo milestone | Gateway không phục vụ request nào của khách — mọi dữ liệu khách thấy đi qua CORE theo cơ chế share có tenant isolation |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Các BR-OPS-7.x gốc được thực thi chính ở CORE/WEB; bảng dưới ghi rõ phần gateway phải cứng hoá ở biên API.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-7.1-gw | **Campaign/deliverable theo WBS:** mọi campaign được push hay được feed chi tiêu phải tham chiếu `project_ref` + `wbs_node_ref` hợp lệ (khớp nguyên tắc "campaign không gắn dự án = không tồn tại" của REQ-OPS-001); campaign platform không map được dự án bị đánh dấu `UNMAPPED` | Push/feed từ chối với payload thiếu tham chiếu; dữ liệu chi tiêu `UNMAPPED` bị treo "chờ gắn" và KHÔNG được đưa vào bất kỳ báo cáo theo khách nào cho tới khi có người map + duyệt |
| BR-OPS-7.3-gw | **Duyệt creative đa vai + SLA theo tier:** pipeline bắt buộc OPS_CONT → OPS_DES/OPS_EDIT → OPS_PLAN/AM, cấm tự duyệt (approver ≠ creator); SLA duyệt nội bộ chốt theo DI-005 — AM duyệt 2h (video dài 4h, trend gấp 1h), content self-QC + Lead review 4h; khi HĐ khách cam kết cao hơn ma trận tier×priority của REQ-OPS-008 thì áp theo profile khách (ghi đè); tối đa 3 vòng sửa/deliverable, vòng 4 escalate AM chốt phạm vi bằng văn bản với khách | Gateway chỉ đẩy creative chính đã ở trạng thái `Approved` đầy đủ pipeline; payload creative chưa duyệt đủ hoặc do chính người tạo duyệt bị từ chối ở tầng API + audit log; SLA/escalate thực thi ở CORE — gateway không bơm lại creative chờ duyệt lên platform |
| BR-OPS-7.4-gwa | **Push chỉ khi có change log entry:** mọi thay đổi ngân sách/bid/target/audience/creative chính phải tồn tại change log entry `APPROVED` (append-only, có reason, giá trị cũ/mới, ai, khi nào) trước khi gateway push; gateway validate tham chiếu `change_log_id` trước mỗi push | Push không có tham chiếu hoặc tham chiếu trạng thái chưa duyệt bị từ chối ở tầng API; attempt ghi audit log bất biến |
| BR-OPS-7.4-gwb | **Phân bậc duyệt hạn mức:** buyer tự quyết trong hạn mức ngày theo khung % ngân sách tháng 20/50/100% (Junior/Senior/Lead — số cụ thể FIN chốt khi cấu hình); vượt hạn mức ngày → TL duyệt; vượt hạn mức dự án → AM duyệt; khẩn cấp (die account, brand safety) pause trước — bổ sung reason vào change log trong 4h làm việc | Gateway không tự duyệt gì cả — chỉ nhận payload đã qua đủ bậc duyệt ở CORE; payload trạng thái chưa `APPROVED` bị chặn; push khẩn cấp không reason bị hoàn tác bằng push giá trị cũ khi quá 4h LV chưa bổ sung reason |
| BR-OPS-7.4-gwc | **Degraded mode manual + backfill (DI-007):** khi mất quyền API/connector lỗi, OPS áp thay đổi trực tiếp trên platform rồi ghi nhận qua kênh manual có cấu trúc (field, giá trị cũ/mới, reason, evidence, người áp) gắn nhãn `manual` + nguồn + timestamp; khi API sống lại, gateway backfill khoảng đứt và reconcile hiện trạng platform với change log, báo mọi chênh lệch cho OPS_ADS/TL | Không được phép dừng vận hành chờ API; thay đổi áp tay không ghi nhận trong 4h LV bị escalate TL; backfill không ghi đè bản ghi manual — chênh lệch reconcile phát sinh yêu cầu giải trình trước khi tiếp tục push |
| BR-OPS-7.5-gw | **Nghiệm thu theo WBS:** milestone sẵn sàng nghiệm thu khi 100% WBS node thuộc milestone ở trạng thái Approved nội bộ; AM đề xuất nghiệm thu → khách confirm trên PORTAL/M-PORTAL (tenant của mình, realtime); milestone onboarding bắt buộc gắn Gate Day 14; chờ confirm tối đa 3 ngày làm việc: ngày 2 hệ thống nhắc khách, ngày 4 escalate AM (biên bản DI-005 ghi ký hiệu "AD" — registry không có vai AD chuyên trách nên quy về OPS_AM phụ trách khách); KHÔNG áp "im lặng = đồng ý" — hết hạn không confirm không tự coi là đạt; feed chi tiêu theo milestone do gateway cung cấp cho CORE phục vụ quyết định nghiệm thu | Hệ thống chỉ nhắc và escalate, không tự chuyển milestone thành đã nghiệm thu — hành vi tự đạt khi hết hạn là vi phạm riêng; gateway từ chối phát hành dữ liệu nghiệm thu cho milestone chưa đủ 100% WBS Approved |
| BR-OPS-7.5-gwb | **Portal share + tenant isolation:** khách chỉ thấy tiến độ deliverable ở phần đã share (milestone đã đề xuất nghiệm thu/được bật share flag) qua PORTAL/M-PORTAL; gateway không cung cấp bất kỳ endpoint public nào cho khách; mọi payload gateway mang `tenant_id` để CORE enforce tenant isolation tuyệt đối | Request tới gateway từ kênh khách bị từ chối toàn bộ; payload thiếu `tenant_id` bị core reject; dữ liệu chưa share không được đưa vào bề mặt nào nhìn thấy bởi tenant khách |
| BR-GW-CAMP-011 | **Pull chi tiêu theo campaign gắn nhãn nguồn:** pull hourly qua batch/queue chống rate limit, lưu raw payload trước chuẩn hóa; dữ liệu chuẩn hóa mang nhãn `api` hoặc `manual` + nguồn + timestamp, freshness ≤1h hiển thị ở bản counterpart WEB; map campaign qua fingerprint naming/UTM chuẩn REQ-OPS-1.2 | Dữ liệu không nhãn bị core từ chối đưa vào đối chiếu; job fail → retry/backoff + alert, fail vượt ngưỡng → adapter degraded, không để dữ liệu đứt lặng lẽ |
| BR-GW-CAMP-012 | **Tách bạch GMV TikTok Shop:** dữ liệu hiệu suất QC (TikTok for Business) và dữ liệu GMV TikTok Shop (REQ-OPS-011) là 2 `data_domain` riêng (`ads_perf` vs `tiktok_shop_gmv`) ngay ở tầng gateway; GMV không được trộn vào chi tiêu campaign, không map vào WBS node dịch vụ, không hạch toán vào doanh thu agency | Payload gộp domain hoặc map GMV vào chi tiêu campaign bị reject; red line kiểm soát tài chính — vi phạm ghi audit + escalate BOD |
| BR-GW-CAMP-013 | **Cấu hình vendor-agnostic (DI-004):** endpoint, field mapping, schema import statement của adapter campaign là cấu hình tại MOD-SETTINGS-GW — không hardcode nền tảng trong logic; thêm nền tảng mới = thêm profile + mapping | Payload không khớp mapping cấu hình bị đẩy vào hàng lỗi; không có lối nhập tự do dạng text ngoài schema chuẩn |
| BR-GW-CAMP-014 | **Tham số luồng chỉ ADMIN/BOD sửa:** tần suất pull, ngưỡng freshness, cửa sổ retry, ngưỡng fail degraded là tham số quản trị versioned + audit; chỉ BOD_CEO/BOD_CFO_CTO duyệt thay đổi | OPS roles chỉ xem và nhận alert; attempt sửa tham số bị RBAC chặn + log |

---

## 4. Phân Quyền

> *Gateway là API headless: bảng này là hợp đồng quyền cho các API gateway cung cấp — web/mobile nội bộ gọi hộ người dùng, phân quyền thực thi ở tầng service của gateway; khách hàng (CUSTOMER) không gọi trực tiếp gateway bao giờ.*

| Hành động | OPS_ADS | OPS_PLAN | OPS_AM | SYS_ADMIN | BOD_CFO_CTO | CUSTOMER |
|-----------|---------|----------|--------|-----------|-------------|----------|
| Xem trạng thái push/pull + lỗi + tuổi dữ liệu của campaign khách mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (qua PORTAL counterpart, chỉ phần đã share) |
| Ghi nhận thay đổi manual (degraded) + evidence | ✅ | ❌ | ✅ (khi AM vận hành thay) | ❌ | ❌ | ❌ |
| Xác nhận/nhận xét thay đổi manual trước khi chốt vào change log | ❌ | ✅ (TL) | ✅ | ❌ | ❌ | ❌ |
| Đề xuất map/unmap campaign platform ↔ dự án (`UNMAPPED`) | ✅ | ✅ (duyệt) | ❌ | ❌ | ❌ | ❌ |
| Kích hoạt reconcile/backfill thủ công cho một nền tảng | ✅ (đề xuất) | ❌ | ❌ | ✅ (thực thi sau phê duyệt CTO) | ✅ (phê duyệt) | ❌ |
| Xem chi tiêu theo campaign + nhãn nguồn | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (chỉ milestone đã share, qua portal) |
| Đề xuất nghiệm thu milestone | ❌ | ✅ (Planner khi AM vắng — có log) | ✅ | ❌ | ❌ | ❌ |
| Confirm nghiệm thu milestone | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (qua PORTAL/M-PORTAL — không qua gateway) |
| Bật/tắt degraded mode cho adapter campaign feed | ❌ | ❌ | ❌ | ✅ (thực thi sau phê duyệt CTO) | ✅ (duyệt) | ❌ |
| Sửa endpoint/field mapping/schema import adapter | ❌ | ❌ | ❌ | ✅ (thực thi) | ✅ (duyệt) | ❌ |
| Sửa tham số sync (tần suất, freshness, retry, ngưỡng fail) | ❌ | ❌ | ❌ | ❌ (chỉ xem) | ✅ (versioned + audit) | ❌ |
| Xem audit log push/pull/reconcile | ❌ (chỉ của mình) | ✅ | ✅ | ✅ | ✅ | ❌ |

> Ranh giới: OPS_CONT/OPS_DES/OPS_EDIT không thao tác trực tiếp gateway — pipeline creative của họ kết thúc ở duyệt nội bộ (WEB/CORE); chỉ sản phẩm `Approved` mới đi tới gateway để push. Bậc duyệt buyer → TL → AM nằm ở CORE change log engine; gateway chỉ là điểm thực thi ra ngoài platform. Chuỗi đề xuất → duyệt → thực thi ở bảng trên dựng theo ma trận RACI file 08 hiện dùng — ma trận chưa được xác nhận chính thức `[KXN-19]`, khi chốt sẽ rà lại cột quyền mà không đổi cơ chế enforce ở gateway.

---

## 5. Trường Hợp Đặc Biệt

- **Khẩn cấp pause chiến dịch (die account, sự cố brand safety):** OPS_ADS pause trực tiếp trên platform trước, sau đó bổ sung reason vào change log trong 4h làm việc; gateway khi API có mặt sẽ đối chiếu trạng thái pause và đóng vòng change log — không phạt hành động cứu cháy, nhưng cấm im lặng quá hạn.
- **Campaign tạo tay trên platform, không qua hệ thống:** pull chi tiêu phát hiện campaign platform ID không khớp naming chuẩn → đánh dấu `UNMAPPED`, tạo task gắn dự án 4h làm việc (khớp BR-OPS-1.3); trong thời gian chưa map, chi tiêu không vào báo cáo theo khách — số không bị mất nhưng không được "hợp pháp hoá" im lặng.
- **Thay đổi phát sinh ngoài hệ thống trong thời gian mất API (drift):** reconcile sau backfill phát hiện giá trị platform khác change log — gateway đánh dấu campaign `DRIFT`, chặn push mới cho tới khi OPS_ADS tạo entry change log giải thích hoặc hoàn tác; drift chưa giải trình quá 1 ngày LV escalate TL.
- **Push fail lặp trên một nền tảng:** retry/backoff theo cấu hình; hết ngưỡng → adapter chuyển degraded và cảnh báo gộp; OPS_ADS chuyển sang áp tay + kênh manual, không để chiến dịch của khách đứng im vì lỗi kỹ thuật.
- **Nhiều ad account/campaign cùng dự án:** mapping nhiều-nhiều giữa campaign platform và WBS node được cho phép qua bảng mapping; chi tiêu feed gộp theo WBS node ở CORE, gateway chỉ bảo đảm từng dòng có `tenant_id` + tham chiếu đầy đủ.
- **Khách không confirm nghiệm thu trong hạn:** hết 3 ngày làm việc hệ thống nhắc (ngày 2) và escalate AM (ngày 4); milestone giữ nguyên trạng thái chờ — không tự đạt, không tự hủy; AM chủ động liên hệ khách theo kênh chính thức và ghi nhận kết quả liên hệ; trường hợp kéo dài AM báo cáo trong weekly review khách.
- **Backfill chạm kỳ đã chốt báo cáo:** gateway chỉ bù dữ liệu gốc gắn nhãn `api`; chênh lệch với số đã báo cáo xử lý ở CORE theo quy trình chỉnh sửa báo cáo có audit — gateway không tự đè số cũ.
- **Rate limit/quota nền tảng biến động:** batch/queue điều chỉnh theo quota từng nền tảng; nếu nền tảng siết API giữa chừng, adapter hạ tần suất theo profile và cảnh báo — không cố dùng sai chính sách platform. Bộ cờ cảnh báo đi kèm (trượt deadline, drift, degraded) dùng tạm tập cờ hiện có — danh sách đầy đủ cờ K6–K12 chưa chốt `[KXN-20]`, cấu trúc cờ thiết kế mở rộng được.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** CampaignChangePush — yêu cầu đẩy một thay đổi campaign (tạo từ change log entry `APPROVED` của CORE) xuống platform; riêng nhánh degraded dùng ManualChangeRecord cùng state machine rút gọn.

**Sơ đồ trạng thái:**
```
[QUEUED] ──(push OK)──► [PUSHED] ──(platform confirm)──► [CONFIRMED]
    │                      │                                │
    │ (degraded: mất API)  │ (retry hết ngưỡng)             │ (reconcile lệch)
    ▼                      ▼                                ▼
[MANUAL_APPLIED] ◄──── [FAILED]                       [DRIFT]
    │                      │
    └──(API sống lại + reconcile khớp)──► [CONFIRMED]
                           │ (hủy có lý do)
                           ▼
                      [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED` | Push xuống platform | `PUSHED` | Hệ thống | Change log entry `APPROVED`, đủ `tenant_id` + `wbs_node_ref`, adapter không degraded |
| `QUEUED` | Chuyển kênh manual | `MANUAL_APPLIED` | Hệ thống (khi adapter degraded) hoặc OPS_ADS | Đã ghi nhận bản ghi manual có cấu trúc + evidence + nhãn `manual` |
| `PUSHED` | Platform xác nhận | `CONFIRMED` | Hệ thống | Phản hồi platform thành công; raw payload lưu |
| `PUSHED` | Push fail hết retry | `FAILED` | Hệ thống | Vượt ngưỡng retry; alert gộp theo nền tảng |
| `FAILED` | Retry / chuyển manual | `PUSHED` / `MANUAL_APPLIED` | Hệ thống / OPS_ADS | Adapter phục hồi hoặc bản ghi manual đầy đủ |
| `CONFIRMED` | Reconcile phát hiện lệch | `DRIFT` | Hệ thống | Giá trị platform ≠ change log sau backfill; chặn push mới tới khi giải trình |
| `DRIFT` | Giải trình/hoàn tác | `CONFIRMED` | OPS_ADS (tạo) + TL (duyệt) | Change log entry bổ sung hoặc push hoàn tác thành công |
| `QUEUED`/`FAILED` | Hủy yêu cầu | `CANCELLED` | TL/AM qua CORE | Nhập lý do; change log entry gốc bị đánh dấu hủy kèm lý do |

**Quy tắc:**
- `CONFIRMED` và `CANCELLED` là trạng thái kết thúc của một push; thay đổi tiếp theo luôn tạo push mới, không sửa push cũ.
- `MANUAL_APPLIED` chưa được reconcile khớp sau khi API sống lại thì không tính là đóng vòng — campaign vẫn còn vết cảnh báo cho tới khi khớp.
- Mọi chuyển trạng thái ghi audit log bất biến (job id, mã lỗi, người thao tác, timestamp) — gateway không có hành động nào không để lại vết.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| CampaignChangePush | `change_log_id`, `campaign_ref`, `wbs_node_ref`, `tenant_id`, `platform`, `old_value`, `new_value`, `push_status`, `attempt`, `error_code` | FK logic → change log (CORE), Campaign registry (REQ-OPS-001) | Chỉ tạo từ entry `APPROVED`; audit bất biến |
| ManualChangeRecord | `campaign_ref`, `tenant_id`, `field`, `old_value`, `new_value`, `reason`, `applied_by`, `evidence_ref`, `source_label` = `manual`, `reconcile_status` | FK logic → CampaignChangePush (cùng thay đổi) | Degraded mode; quá 4h LV không ghi nhận → escalate TL |
| CampaignPlatformMapping | `campaign_ref`, `platform`, `platform_campaign_id`, `naming_code`, `match_status` (AUTO/MANUAL/UNMAPPED), `tenant_id`, `mapped_by`, `approved_by` | FK → project/WBS node (CORE) | `UNMAPPED` không vào báo cáo theo khách |
| CampaignSpendFeed | `platform`, `platform_campaign_id`, `campaign_ref`, `date`, `spend`, `currency`, `source_label` (`api`/`manual`), `data_domain` (`ads_perf`/`tiktok_shop_gmv`), `freshness_at` | FK → CampaignPlatformMapping | Pull hourly; raw payload lưu trước chuẩn hóa |
| RawPushPayload | `push_id`, `platform`, `requested_at`, `payload_blob`, `response_blob`, `status` | FK → CampaignChangePush.id | Căn cứ đối chiếu khi platform restatement/drift |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push sau APPROVED | Change log entry ngân sách đã `APPROVED`, adapter `api` | CORE phát yêu cầu push | Giá trị mới xuất hiện trên platform đúng campaign ID; push `CONFIRMED`; raw payload lưu; audit ghi đầy đủ | [ ] |
| SC-002: Chặn push thiếu tham chiếu | Payload push không có `change_log_id`/reason | Gateway nhận push | Từ chối ở tầng API + audit log; platform không bị thay đổi | [ ] |
| SC-003: Degraded manual đầy đủ vết | Mất quyền API nền tảng | OPS_ADS áp thay đổi tay và ghi nhận manual | Bản ghi có field, old/new, reason, evidence, người áp, nhãn `manual` + timestamp; SLA 4h LV được đo | [ ] |
| SC-004: Pull chi tiêu + map tự động | Campaign platform đặt naming chuẩn | Job hourly chạy | Chi tiêu về với nhãn `api`, map AUTO về đúng dự án qua fingerprint, freshness ≤1h | [ ] |
| SC-005: UNMAPPED không vào báo cáo khách | Pull phát hiện campaign không khớp naming | Chuẩn hóa dữ liệu | Campaign `UNMAPPED`, treo "chờ gắn", tạo task 4h LV; báo cáo theo khách không chứa chi tiêu chưa map | [ ] |
| SC-006: Reconcile bắt drift | Trong lúc mất API, platform bị đổi bid ngoài hệ thống | Backfill + reconcile chạy | Campaign `DRIFT`, chặn push mới, yêu cầu giải trình; drift quá 1 ngày LV escalate TL | [ ] |
| SC-007: Nghiệm thu không tự đạt | Milestone 100% WBS Approved, đã đề xuất nghiệm thu | Khách không confirm qua 3 ngày LV | Ngày 2 có nhắc khách, ngày 4 escalate AM; milestone vẫn ở trạng thái chờ — không tự chuyển thành đạt | [ ] |
| SC-008: GMV tách bạch | Khách có cả campaign TikTok Ads và TikTok Shop | Feed dữ liệu về | `ads_perf` và `tiktok_shop_gmv` tách domain; GMV không xuất hiện trong chi tiêu campaign hay báo cáo doanh thu agency | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-006 (Mục 2 — push theo change log, degraded manual, pull chi tiêu theo campaign, UNMAPPED, drift, nghiệm thu theo milestone, tách bạch GMV).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/campaign-deliverable/` (duyệt creative, change log, lịch nội dung — thuộc counterpart WEB; gateway không có UI) |
| Bản fan-out counterpart | `phase2-features/core-backend/campaign-deliverable/` (WBS, change log engine, capacity check), `phase2-features/bcerp-web/campaign-deliverable/`, `phase2-features/mobile-internal/campaign-deliverable/`, `phase2-features/portal-web/campaign-deliverable/`, `phase2-features/mobile-portal/campaign-deliverable/` (khách confirm nghiệm thu, tenant isolation) — REQ-OPS-006 xuất hiện ở 6 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane | `phase2-features/integration-gw/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` (FEAT-GW-CAMP-002 — dữ liệu hiệu quả theo variant dùng chung hạ tầng pull/push này) |
| Hạ tầng gateway dùng chung | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001), `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-002) |
| Nguồn nghiệp vụ | REQ-OPS-001 (naming/UTM), REQ-OPS-011 (tách bạch TikTok Shop), REQ-OPS-008 (ma trận SLA tier), `work/wf-analyze-requirements/deferred-issues.md` (DI-005 — SLA/đếm vòng/nghiệm thu đã chốt; DI-007 — degraded mode bắt buộc) |
