# Tính Năng: Campaign & Deliverable Management (WBS, Duyệt Creative, Change Log Bất Biến, Nghiệm Thu — Core Backend)

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A3, Phần B.7 — BR-OPS-7.1 đến BR-OPS-7.6); `phase1-business/P1-02-business-workflow.md` Luồng 3 (Campaign Delivery B1–B7); số liệu SLA/nghiệm thu đã chốt theo DI-005 (`work/wf-analyze-requirements/deferred-issues.md`)
> **Phân hệ:** Vận hành — Quản lý campaign & deliverable trên domain service (SYS-CORE-BACKEND)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 3), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-006)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/campaign-deliverable/[screen-group].md`, `phase5-implementation/tasks/core-backend/campaign-deliverable/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp: **FEAT-CORE-CAMP-001**. REQ-OPS-006 fan-out ra 6 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (headless API/domain service); counterparts: SYS-INTEGRATION-GW (đẩy thay đổi xuống platform, kéo chi tiêu theo campaign), SYS-BCERP-WEB (lịch nội bộ, pipeline creative, form thay đổi), SYS-MOBILE-INTERNAL (duyệt nhanh, push), SYS-PORTAL-WEB / SYS-MOBILE-PORTAL (khách theo dõi và confirm nghiệm thu). Cross-dependency: không có. Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-006 (Campaign & Deliverable Management); tham chiếu REQ-OPS-012 (A/B Testing — thay đổi ngân sách trong thử nghiệm vẫn qua change log), REQ-OPS-001 (naming/UTM, "không gắn dự án = không tồn tại"), REQ-OPS-007 (capacity check), REQ-OPS-010 (portal share), REQ-OPS-011 (TikTok Shop GMV tách bạch) |
| Người dùng liên quan | OPS_PLAN (tạo WBS, duyệt nghiệp vụ, duyệt vượt hạn mức ngày), OPS_AM (duyệt nghiệp vụ, share cho khách, đề xuất nghiệm thu, duyệt vượt hạn mức dự án), OPS_CONT (soạn nội dung, editorial calendar), OPS_DES, OPS_EDIT (sản xuất visual/video), OPS_ADS (chạy campaign, thay đổi ngân sách/bid), CUSTOMER (theo dõi tiến độ đã share, confirm nghiệm thu qua PORTAL/M-PORTAL), SYS_ADMIN (hạ tầng, không có quyền nghiệp vụ) |
| Độ ưu tiên | Cao (HIGH · Phase 2 · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Dự án + approved proposal đã qua gate EVALUATION/PROPOSAL (REQ-OPS-005) làm đầu vào sinh WBS; capacity engine của REQ-OPS-007 (capacity check bắt buộc trước mọi gán); naming/UTM convention (REQ-OPS-001); share scope portal (REQ-OPS-010) |
| Ghi chú Expert (A7) | Mục A7 trong `operations.md` đang "chờ đánh giá" — chưa có điều chỉnh chính thức. Vai đã gán lại sau DI-006 (không có OPS_CX) trong danh sách actor của lane. Escalation nghiệm thu ngày 4 trỏ **AD (Account Director)** theo DI-005 — mã vai `OPS_AD` đã chốt theo KXN-12 nhưng chưa đồng bộ vào registry 18 vai, nên trong ma trận Phân Quyền của spec này không mở cột riêng cho AD, escalation được thể hiện ở quy tắc BR-011 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Feature này là **domain service quản trị campaign và deliverable của core backend**, hiện thực hóa chuỗi "proposal thắng → WBS → sản xuất creative đa vai → chạy campaign có kiểm soát → khách nghiệm thu theo milestone" theo đúng Luồng 3 Campaign Delivery. Mọi business rule (WBS bắt buộc, cấm tự duyệt, change log bất biến có reason, phân bậc duyệt ngân sách, nghi thức nghiệm thu 3 ngày) đều được **enforce tại tầng service** — client (WEB/M-INT/PORTAL) chỉ gọi API và phản chiếu kết quả, không có đường đi nào vượt qua validation ở tầng UI.

**Phạm vi:**
- Bao gồm: API tạo WBS từ approved proposal (mỗi deliverable map ≥1 WBS node, project type bắt buộc, dependency finish-to-start); editorial calendar với pipeline 6 trạng thái (Ý tưởng → Đã xuất bản) và cảnh báo trượt deadline; pipeline duyệt creative đa vai (CONT → DES/EDIT → PLAN/AM) với cấm tự duyệt, comment bắt buộc khi reject, SLA từng bước theo tier và đếm vòng sửa (tối đa 3 vòng nội bộ); campaign change log bất biến append-only với reason bắt buộc và phân bậc duyệt buyer → TL → AM theo hạn mức ngày/dự án; trạng thái nghiệm thu milestone (READY khi 100% WBS node Approved) với clock khách 3 ngày làm việc — nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý"; expose API đọc tiến độ deliverable cho portal khách theo share scope với tenant isolation.
- Không bao gồm: đăng ký/kết luận thí nghiệm A/B (FEAT-CORE-CAMP-002 — REQ-OPS-012 trên cùng module); màn hình lịch/board/pipeline (SYS-BCERP-WEB), app mobile duyệt nhanh (SYS-MOBILE-INTERNAL), bề mặt portal khách (SYS-PORTAL-WEB/SYS-MOBILE-PORTAL — counterpart tiêu thụ cùng API); engine capacity và phễu duyệt timesheet (REQ-OPS-007 — FEAT-CORE-CAPTS-001/002); kéo/đẩy dữ liệu platform và OAuth (SYS-INTEGRATION-GW); đối soát chi tiêu FIN (DEPT-FINANCE).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản spec này là **core backend headless**: OPS thao tác qua WEB nội bộ hoặc M-INT, khách qua PORTAL/M-PORTAL, nhưng mọi ràng buộc (gắn WBS, cấm tự duyệt, reason bắt buộc, share scope, tenant isolation) đều được service layer kiểm tra lại trên từng request. Đặc thù hệ thống: WEB nội bộ là responsive browser UI, M-INT là React Native offline-capable, portal là read-only phần đã share — dù qua kênh nào, luật chơi chỉ tồn tại ở một chỗ: service layer, kèm audit log và tenant isolation trên mọi endpoint.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN | Gọi API tạo WBS từ approved proposal, mỗi deliverable map ≥1 WBS node, chọn project type (Client Billable / Internal Non-billable) ngay lúc tạo | Khung triển khai khớp cam kết với khách và khóa đúng tập nhãn timesheet từ nguồn (BR-OPS-7.1) |
| 2 | OPS_CONT | Lập editorial calendar gắn WBS node + kênh phát hành (Meta/TikTok/Google/web), bài viết đi qua pipeline 6 trạng thái | Tiến độ nội dung được đo bằng trạng thái máy đọc được, trượt deadline tự động cảnh báo TL + AM |
| 3 | OPS_CONT | Nộp nội dung vào pipeline duyệt đa vai và bị chặn khi gán chính mình làm approver | Không còn cơ hội "tự duyệt task của mình" — approver ≠ creator chặn ngay tầng API |
| 4 | OPS_DES / OPS_EDIT | Nhận brief visual/video từ task đã qua capacity check, trả kết quả kèm vòng sửa được đếm tự động | Việc sản xuất gắn số liệu tải thật, vòng sửa minh bạch không phụ thuộc trí nhớ |
| 5 | OPS_AM / OPS_PLAN | Duyệt nghiệp vụ creative với comment bắt buộc khi reject; SLA từng bước nhắc đúng hạn, chậm 2 bước liên tiếp escalate TL | Chất lượng đầu ra có người chịu trách nhiệm từng chặng, không kẹt ùn tắc vô danh |
| 6 | OPS_ADS | Thay đổi ngân sách/bid/target/audience qua API bắt buộc nhập reason, hệ thống tự định tuyến duyệt theo hạn mức (buyer → TL → AM) | Mọi biến động campaign để lại dấu vết cũ/mới, ai, khi nào — không thể chối cãi khi đối chiếu hiệu quả |
| 7 | OPS_AM | Share deliverable/milestone cho khách theo đúng phạm vi đã chọn và đề xuất nghiệm thu khi 100% WBS node Approved | Khách thấy đủ để quyết mà không thấy giá vốn, chiết khấu, P&L hay ghi chú nội bộ |
| 8 | CUSTOMER | Theo dõi tiến độ deliverable realtime trên portal/mobile của tenant mình và confirm nghiệm thu milestone bằng 1 thao tác có timestamp | Tiến độ minh bạch hai chiều — quyết định của tôi được ghi nhận có dấu vết, không ai quyết hộ |
| 9 | OPS_PLAN | Khi khách không phản hồi nghiệm thu, hệ thống tự nhắc ngày 2 và escalate AD ngày 4 — không tự động coi là đã duyệt | Tránh cả hai rủi ro: quên đuổi khách và bị "im lặng = đồng ý" sinh tranh chấp sau này |
| 10 | OPS_ADS | Chi tiêu campaign bị chặn khi campaign không gắn dự án (tự pause trong 4h làm việc) | Tiền không chảy vào campaign mồ côi ngoài kiểm soát WBS và P&L |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ rule enforce tại tầng service/domain engine của core backend; các client (WEB, M-INT, PORTAL, M-PORTAL) chỉ gọi API và hiển thị; audit log append-only + hash-chain; tenant isolation trên mọi endpoint. Nguồn chính: `operations.md` B.7 (BR-OPS-7.1–7.6), P1-02 Luồng 3, DI-005 (số đã chốt 12/09/2026).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **WBS sinh từ approved proposal:** OPS_PLAN/AM tạo WBS sau WON; service sinh khung từ template theo loại dịch vụ; mỗi deliverable trong proposal map ≥1 WBS node; task bắt buộc gắn WBS node (task mồ côi không được tính công — khớp "không gắn project = không tồn tại" của REQ-OPS-001); dependency mặc định finish-to-start — task không start khi predecessor chưa done, trừ TL duyệt overlap có lý do (log). **Project type bắt buộc lúc tạo:** "Dự án Khách hàng" (Client Billable) hoặc "Dự án Nội bộ" (Internal Non-billable). Nguồn: BR-OPS-7.1; P1-02 B1. | Tạo task không gắn node → từ chối "TASK_MO_COI"; overlap không duyệt → chặn start; thiếu project type → không tạo được dự án |
| BR-002 | **Campaign không gắn dự án = không tồn tại:** mọi campaign phải gắn project/WBS node và tuân naming/UTM convention (REQ-OPS-001); campaign mất gắn kết (project đóng, node hủy) tự pause trong 4h làm việc. Nguồn: BR-OPS-7.1; P1-02 B1; REQ-OPS-001. | Campaign mồ côi bị pause tự động + alert OPS_ADS/AM; chi tiêu mới bị chặn cho tới khi gắn lại hợp lệ |
| BR-003 | **Editorial calendar pipeline 6 trạng thái:** mỗi bài/ấn phẩm đi qua Ý tưởng → Soạn → Duyệt nội dung → Sản xuất → Duyệt xuất bản → Đã xuất bản, gắn WBS node + kênh phát hành; deadline trượt → cảnh báo TL + AM (AM chủ động cập nhật khách). Nguồn: BR-OPS-7.2; P1-02 B2. | Bước nhảy trái pipeline (VD Soạn → Đã xuất bản) từ chối "SAI_PIPELINE"; trượt mốc sinh event cảnh báo cho TL + AM |
| BR-004 | **Duyệt creative đa vai, cấm tự duyệt:** pipeline bắt buộc OPS_CONT (nội dung) → OPS_DES/OPS_EDIT (sản xuất) → OPS_PLAN/OPS_AM (duyệt nghiệp vụ); ý kiến khách đi qua AM; mỗi bước có trạng thái Approved / Request changes — **comment bắt buộc khi reject**; **cấm tự duyệt task của mình** (approver ≠ creator) chặn tầng API. Nguồn: BR-OPS-7.3; P1-02 B4. | Tự duyệt → chặn "CAM_TU_DUYET"; reject thiếu comment → từ chối "THIEU_COMMENT" |
| BR-005 | **Creative SLA theo tier và từng bước (DI-005):** duyệt nội bộ chuẩn — content self-QC + Lead review 4h làm việc; AM duyệt 2h (video dài 4h, trend gấp 1h); toàn bộ đặt trong khung tier × priority của khách theo `sla-khach-hang.md` (cam kết HĐ cao hơn ghi đè theo profile); quá SLA tự nhắc, chậm 2 bước liên tiếp escalate TL. Nguồn: BR-OPS-7.3; DI-005 mục (2); BR-OPS-9.1. | Quá SLA sinh nhắc tự động; chậm 2 bước liên tiếp tự escalate TL kèm log timestamp; clock tính giờ làm việc GMT+7 |
| BR-006 | **Vòng sửa creative tối đa 3 vòng nội bộ:** mỗi deliverable đếm vòng sửa tự động; vòng sửa thứ 4 escalate AM/TL — TL chốt phạm vi sửa bằng văn bản với khách (qua AM), có log; không có chế độ sửa vô tận. Nguồn: BR-OPS-7.3; DI-005 mục (3). | Vòng 4 không có escalate → chặn nộp mới "VUOT_VONG_SUA" cho tới khi có chốt phạm vi |
| BR-007 | **Capacity check bắt buộc trước mọi gán:** không task nào trên WBS được gán ngoài capacity engine (REQ-OPS-007 — FEAT-CORE-CAPTS-002): vàng >90% TL duyệt, đỏ ≥100% chặn cứng; SLA check 4h → TL, 8h → HR_L2. Nguồn: BR-OPS-7.1; BR-OPS-8.3; P1-02 B3. | Gán không qua check không thể tạo; kết quả check không tái sử dụng cho lần gán sau |
| BR-008 | **Campaign change log bất biến:** mọi thay đổi ngân sách/bid/target/audience/creative chính trên campaign (kể cả trong A/B test — REQ-OPS-012) bắt buộc nhập **reason**; service lưu giá trị cũ/mới, ai, khi nào — **append-only, cấm sửa/xóa** ở mọi vai. Nguồn: BR-OPS-7.4; P1-02 B5. | Request thiếu reason → từ chối "THIEU_REASON" ngay tầng API; không tồn tại endpoint sửa/xóa log cho bất kỳ vai nào |
| BR-009 | **Phân bậc duyệt thay đổi theo hạn mức:** buyer tự quyết trong hạn mức ngày do TL cấu hình (khung % ngân sách tháng 20/50/100% theo cấp Junior/Senior/Lead — số cụ thể FIN chốt khi cấu hình `[CẦN CHỐT SỐ — SO3-09]`); vượt hạn mức ngày → TL duyệt; vượt hạn mức dự án → AM duyệt. Nguồn: BR-OPS-7.4; P1-02 Luồng 3; DI-005 mục (4). | Thay đổi vượt hạn mức thiếu duyệt ở tầng tương ứng → treo `PENDING_APPROVAL`, không đẩy xuống platform |
| BR-010 | **Exception khẩn cấp pause-trước-log-sau:** khẩn cấp dừng chiến dịch (die account, sự cố brand safety) — pause ngay không cần reason trước, nhưng phải bổ sung reason vào change log trong 4h làm việc; quá hạn sinh vi phạm riêng báo TL. Nguồn: BR-OPS-7.4 exception. | Quá 4h không bổ sung reason → cảnh báo TL + đánh dấu entry "KHẨN CẤP THIẾU LOG" trong audit |
| BR-011 | **Nghiệm thu milestone — nghi thức 3 ngày (DI-005, ghi đè draft 5 ngày cũ):** milestone sẵn sàng nghiệm thu khi 100% WBS node thuộc milestone ở trạng thái Approved nội bộ; AM đề xuất nghiệm thu → khách **confirm trên PORTAL/M-PORTAL** (tenant của mình, realtime); chờ tối đa **3 ngày làm việc — hệ thống nhắc khách ngày 2, escalate AD (Account Director) ngày 4**; **KHÔNG áp "im lặng = đồng ý"** — không tồn tại auto-accept; milestone onboarding bắt buộc gắn Gate Day 14 (REQ-OPS-010). Nguồn: BR-OPS-7.5; DI-005 mục (6); P1-02 B6. | Đề xuất nghiệm thu khi chưa 100% Approved → từ chối "MILESTONE_CHUA_DU"; khách im lặng không bao giờ chuyển ACCEPTED — chỉ nhắc/escalate và clock tiếp tục chạy có log |
| BR-012 | **Portal khách chỉ thấy phần đã share + tenant isolation:** khách theo dõi tiến độ deliverable theo đúng share scope AM thiết lập; mặc định không thấy giá vốn, chiết khấu, P&L, ghi chú nội bộ; mọi endpoint portal scope cứng theo tenant, watermark mọi download (REQ-OPS-010); ghi chú nội bộ của WBS/creative không bao giờ nằm trong payload portal. Nguồn: BR-OPS-7.5; REQ-OPS-010; Notes lane. | Truy vấn chéo tenant → từ chối + audit log bảo mật; field nội bộ lọt payload → coi là lỗi bảo mật P0 |
| BR-013 | **Hai project type chạy cùng một engine:** WBS, editorial calendar, duyệt creative, change log dùng chung cho Dự án Khách hàng và Dự án Nội bộ; khác nhau ở người duyệt thay khách (nội bộ: TL/OPS_PLAN), nguồn ngân sách và tập nhãn timesheet hợp lệ; campaign của chính BC gắn project nội bộ, vẫn áp naming/UTM. Nguồn: BR-OPS-7.6. | Giờ nội bộ gắn nhãn Client Billable vào dự án khách (và ngược lại) → chặn theo cặp project type × nhãn (BR-OPS-8.1) |
| BR-014 | **TikTok Shop tách bạch GMV khi liên quan:** khi campaign gắn TikTok Shop, GMV/đơn/settlement là chỉ số tham chiếu thuộc về khách — service chặn mọi mapping GMV vào doanh thu agency; doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ (REQ-OPS-011); dữ liệu GMV hiển thị portal chỉ khi hợp đồng cấu hình `[KXN — REQ-OPS-011: phạm vi GMV khách thấy chờ chốt]`. Nguồn: BR-OPS-7.5 góc dữ liệu; REQ-OPS-011. | Mapping GMV → sổ doanh thu bị validation chặn "GMV_KHONG_VAO_DOANH_THU" |
| BR-015 | **Chiến lược campaign theo mục tiêu khách (REQ-OPS-012):** campaign gắn objective theo mục tiêu khách đã đăng ký (conversion/traffic/awareness); thay đổi ngân sách phát sinh trong thí nghiệm A/B vẫn đi qua change log bất biến BR-008; chi tiết đăng ký/kết luận thí nghiệm thuộc FEAT-CORE-CAMP-002 trên cùng module. Nguồn: REQ-OPS-012; BR-OPS-10.3. | Thay đổi ngân sách trong thử nghiệm không qua change log → không được GW đẩy xuống platform |
| BR-016 | **Audit bất biến + enforce một điểm:** mọi event (tạo WBS, gán, duyệt, reject, thay đổi campaign, share, đề xuất/confirm nghiệm thu, escalate) ghi append-only + hash-chain; role re-check mỗi request tại service layer — client hiển thị chứ không quyết; review A7 hiện chưa có điều chỉnh — business rules áp nguyên tắc "không tin UI" làm mặc định kiến trúc. Nguồn: Notes lane touchpoint; P1-02 §5 (Luồng 3). | Đứt hash hoặc request vượt tenant → alert bảo mật + khóa endpoint liên quan tới khi điều tra xong |

---

## 4. Phân Quyền

> Quyền enforce bằng vai tại tầng API core backend (role re-check mỗi request); counterpart WEB/M-INT/PORTAL chỉ phản chiếu kết quả tra quyền — không tạo quyền riêng ở tầng UI. CUSTOMER chỉ tương tác qua phần API portal đã share (tenant isolation tuyệt đối).

| Hành động | OPS_CONT | OPS_DES / OPS_EDIT | OPS_ADS | OPS_AM | OPS_PLAN (TL) | CUSTOMER (portal) | SYS_ADMIN |
|-----------|----------|--------------------|---------|--------|----------------|--------------------|-----------|
| Tạo/sửa WBS, chọn project type | ❌ | ❌ | ❌ | ✅ (của khách mình) | ✅ | ❌ | ❌ |
| Lập editorial calendar, soạn nội dung | ✅ | ❌ (xem brief) | ❌ | ❌ | ✅ (xem tất cả) | ❌ | ❌ |
| Sản xuất visual/video trên task được gán | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nộp duyệt / trả kết quả từng bước | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt nghiệp vụ creative (Approve / Request changes có comment) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Tự duyệt task của mình | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chặn cứng mọi vai) |
| Chạy campaign / thay đổi ngân sách-bid trong hạn mức ngày (có reason) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt thay đổi vượt hạn mức ngày | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt thay đổi vượt hạn mức dự án | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình hạn mức buyer theo cấp (khung % — số FIN chốt) | ❌ | ❌ | ❌ | ❌ | ✅ (cấu hình, log) | ❌ | ❌ |
| Share deliverable/milestone cho khách (đặt share scope) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Đề xuất nghiệm thu milestone | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Xem tiến độ deliverable đã share | ❌ | ❌ | ❌ | ✅ (tất cả phần của mình) | ✅ | ✅ (chỉ phần đã share, tenant mình) | ❌ |
| Confirm nghiệm thu milestone | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (CLIENT_ADMIN/USER được ủy quyền) | ❌ |
| Xem change log campaign | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ (không thấy log nội bộ) | ❌ (đọc audit khi điều tra) |
| Sửa/xóa change log hoặc audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |

> Ghi chú touchpoint: escalation nghiệm thu ngày 4 trỏ AD (Account Director — `OPS_AD` theo KXN-12, chờ đồng bộ registry) nên cột phân quyền không mở vai riêng; AD nhận escalate như một listener của luồng, không thêm quyền thao tác. SYS_ADMIN vận hành hạ tầng, không can thiệp dữ liệu nghiệp vụ; mọi quyền thực thi tại service layer.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý — mọi xử lý qua service layer, có log, không sửa tay trên dữ liệu.*

- **Khách có SLA cam kết hợp đồng cao hơn chuẩn:** profile khách ghi đè SLA từng bước duyệt creative và lịch nhắc nghiệm thu — service đọc profile theo tenant trước khi khởi tạo clock; không hardcode chuẩn nội bộ thành bất biến cho mọi khách.
- **Milestone onboarding gắn Gate Day 14:** milestone thuộc onboarding bắt buộc gắn Gate "khách kích hoạt portal thành công" (REQ-OPS-010) — đề xuất nghiệm thu bị chặn nếu gate chưa đạt, kể cả khi 100% WBS node đã Approved.
- **Khách khai báo lịch làm việc riêng trên portal:** clock nghiệm thu và nhắc ngày 2 theo lịch đó cho mức High/Medium/Low; riêng escalations loại Critical vẫn chạy 24/7 — service lưu hai tham số lịch (chuẩn BC và lịch khách) tách bạch.
- **Dự án nội bộ phục vụ trực tiếp 1 khách (case study có approval khách):** AM đề xuất, TL duyệt chuyển một phần giờ thành Client Billable, có log — luồng exception duy nhất của BR-013, phải qua correction timesheet chứ không sửa trực tiếp.
- **Campaign đa nền tảng dùng chung deliverable:** một deliverable sản xuất một lần có thể phát hành nhiều kênh (Meta/TikTok/Google/web) — mỗi kênh là một editorial item con gắn cùng WBS node; trạng thái xuất bản theo từng kênh, nghiệm thu theo deliverable cha.
- **Thay đổi ngân sách phát sinh từ thí nghiệm A/B (FEAT-CORE-CAMP-002):** vẫn đi qua change log bất biến với reason trỏ thí nghiệm; service không cho phép "kênh thử nghiệm" đứng ngoài phân bậc buyer → TL → AM.
- **Khách im lặng quá nghi thức 3 ngày:** không auto-accept (BR-011) — sau escalate AD ngày 4, clock tiếp tục hiển thị "quá hạn chờ khách" và AM chịu trách nhiệm chốt hướng xử lý bằng văn bản; mọi việc tự ý đánh dấu ACCEPTED thay khách bị coi là gian lận dữ liệu, chặn tầng API vì chỉ CLIENT_USER/ADMIN của tenant mới có endpoint confirm.
- **Import/WBS legacy khi migrate PMS cũ (DI-004 — migrate chọn lọc):** WBS/dự án active nhập về trạng thái `PLANNED` bắt buộc bổ sung mapping deliverable-proposal trong 30 ngày; dữ liệu legacy read-only, không tự sinh task mồ côi — task nhập thiếu node bị gắn cờ "chờ map" thay vì bị xóa.
- **Múi giờ khách đa quốc gia:** timestamp lưu chuẩn GMT+7, hiển thị song song giờ địa phương khách trên portal; phép tính "ngày làm việc" của nghi thức 3 ngày dùng lịch người nhận nhắc (khách hoặc BC) theo cấu hình profile.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Deliverable/WBS node — đơn vị trung tâm quản trạng thái của feature; editorial item và milestone kế thừa các trạng thái phái sinh. Hai state machine phụ: editorial pipeline (BR-003) và milestone acceptance (BR-011).

**Sơ đồ trạng thái:**
```
[PLANNED] ──(gán qua capacity check)──► [IN_PROGRESS] ──(nộp duyệt)──► [IN_REVIEW]
                                             ▲                           │
                                             │ (Request changes +        │ (Approved)
                                             │  comment; vòng +1)        ▼
                                             └────────────────────── [APPROVED]
[PLANNED] ──(hủy scope có lý do)──► [CANCELLED]
[Vòng sửa >3] ──► escalate AM/TL chốt phạm vi (điều kiện mở lại IN_PROGRESS)

Milestone: [M_IN_PROGRESS] ──(100% node Approved)──► [READY_FOR_ACCEPTANCE]
           ──(AM đề xuất + share)──► [PENDING_CUSTOMER]
           ──(khách confirm ≤3 ngày LV)──► [ACCEPTED]
           [PENDING_CUSTOMER] ──(khách từ chối)──► [M_IN_PROGRESS] (kèm lý do, quay lại WBS)
           Nhắc ngày 2 / escalate AD ngày 4 — không đổi trạng thái, chỉ clock + log
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PLANNED` | Gán thực hiện | `IN_PROGRESS` | OPS_PLAN (hệ thống check) | Capacity check pass (vùng xanh/vàng có duyệt TL); task gắn WBS node |
| `IN_PROGRESS` | Nộp duyệt | `IN_REVIEW` | OPS_CONT / OPS_DES / OPS_EDIT | Đủ sản phẩm gắn task; approver ≠ creator |
| `IN_REVIEW` | Approve | `APPROVED` | OPS_AM / OPS_PLAN | Comment không bắt buộc; SLA từng bước BR-005 chạy |
| `IN_REVIEW` | Request changes | `IN_PROGRESS` | OPS_AM / OPS_PLAN | **Comment bắt buộc**; revision_count +1; vòng >3 → escalate chốt phạm vi trước khi nộp lại |
| `PLANNED` | Hủy scope | `CANCELLED` | OPS_AM / OPS_PLAN | Lý do bắt buộc; ghi change log nếu ảnh hưởng ngân sách đã phân bổ |
| `M_IN_PROGRESS` | Milestone ready | `READY_FOR_ACCEPTANCE` | Hệ thống | 100% WBS node thuộc milestone ở `APPROVED` (tự tính, không khai tay) |
| `READY_FOR_ACCEPTANCE` | Đề xuất nghiệm thu | `PENDING_CUSTOMER` | OPS_AM | Share scope portal đã thiết lập; gate Day 14 đạt nếu là milestone onboarding |
| `PENDING_CUSTOMER` | Confirm nghiệm thu | `ACCEPTED` | **CUSTOMER** (CLIENT_ADMIN/USER tenant) | Timestamp + danh tính; clock ≤3 ngày LV hay sau đó đều hợp lệ — không auto-accept |
| `PENDING_CUSTOMER` | Từ chối nghiệm thu | `M_IN_PROGRESS` | CUSTOMER | Lý do bắt buộc; quay lại WBS node liên quan với comment của khách (qua AM) |

**Quy tắc:**
- Không có đường từ `PENDING_CUSTOMER` sang `ACCEPTED` mà thiếu event confirm của tenant khách — kể cả escalate AD hay timeout; `ACCEPTED` chỉ do khách tạo.
- `CANCELLED` và `ACCEPTED` là trạng thái kết thúc của node/milestone; mở lại tạo bản ghi vòng mới, không đè lịch sử.
- Editorial pipeline (Ý tưởng → Đã xuất bản) không cho bước nhảy trái thứ tự; `Đã xuất bản` là terminal và chỉ ghi được từ trạng thái `Duyệt xuất bản`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Project` | `id`, `name`, `project_type` (`CLIENT_BILLABLE/INTERNAL_NON_BILLABLE`), `proposal_id`, `status` | FK → `proposals` | Project type khóa tập nhãn timesheet; bắt buộc lúc tạo |
| `WbsNode` | `project_id`, `parent_id`, `deliverable_ref`, `dependency_type` (mặc định `FINISH_TO_START`), `state` (`PLANNED/IN_PROGRESS/IN_REVIEW/APPROVED/CANCELLED`), `revision_count` | FK → `projects` | Task mồ côi không được tính công; dependency overlap cần TL duyệt có log |
| `EditorialItem` | `wbs_node_id`, `channel` (`META/TIKTOK/GOOGLE/WEB/...`), `pipeline_state` (Ý tưởng → Đã xuất bản), `deadline`, `published_at` | FK → `wbs_nodes` | 6 trạng thái, không bước nhảy; trượt deadline sinh cảnh báo TL + AM |
| `CreativeReview` | `wbs_node_id`, `step` (`CONTENT_SELF_QC/LEAD_REVIEW/AM_PLAN_APPROVAL`), `reviewer_id`, `result` (`APPROVED/REQUEST_CHANGES`), `comment`, `sla_due_at`, `escalated_at` | FK → `wbs_nodes`, `users` | Approver ≠ creator; comment bắt buộc khi reject; SLA theo DI-005 |
| `Campaign` | `id`, `project_id`, `wbs_node_id`, `platform`, `external_id`, `naming_utm`, `objective`, `status` | FK → `projects`, `wbs_nodes` | Không gắn project → tự pause 4h LV; naming/UTM theo REQ-OPS-001 |
| `CampaignChangeLog` | `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `actor_id`, `actor_role`, `approval_level` (`BUYER/TL/AM`), `created_at`, `prev_hash` | FK → `campaigns` | Append-only + hash-chain; không có endpoint sửa/xóa mọi vai |
| `BudgetLimitPolicy` | `buyer_level` (`JUNIOR/SENIOR/LEAD`), `daily_limit`, `month_budget_pct` (20/50/100), `effective_from/to` | — | Khung % chốt, số VND FIN cấu hình `[CẦN CHỐT SỐ — SO3-09]` |
| `Milestone` | `project_id`, `name`, `ready_condition` (100% node Approved), `state` (`M_IN_PROGRESS/READY_FOR_ACCEPTANCE/PENDING_CUSTOMER/ACCEPTED`), `gate_day14_ref` | FK → `projects`, `wbs_nodes` | Milestone onboarding bắt buộc gắn Gate Day 14 |
| `AcceptanceEvent` | `milestone_id`, `type` (`PROPOSED/REMINDER_D2/ESCALATE_D4/CONFIRMED/REJECTED`), `actor_id`, `portal_tenant_id`, `occurred_at`, `note` | FK → `milestones` | CONFIRMED chỉ do tenant khách tạo; không có auto-accept |
| `ShareScope` | `milestone_id`/`wbs_node_id`, `tenant_id`, `granted_by` (OPS_AM), `fields_allowed`, `watermark`, `revoked_at` | FK → `milestones`, `tenants` | Payload portal lọc theo scope; mặc định ẩn tài chính nội bộ |
| `AuditLog` | `actor_id`, `role`, `action`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | — | Append-only + hash-chain; đứt hash → alert |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-006 (`operations.md` A3/B.7 — BR-OPS-7.1 đến 7.6) và P1-02 Luồng 3.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Task mồ côi bị chặn (REQ-OPS-006) | Dự án có WBS hợp lệ | Gọi API tạo task không gắn WBS node | Từ chối "TASK_MO_COI"; không có đường tạo qua kênh nào (WEB/M-INT) | [ ] |
| SC-002: Project type bắt buộc (REQ-OPS-006) | Tạo dự án mới | Gọi API thiếu project type | Từ chối tạo; sau khi chọn, tập nhãn timesheet hợp lệ được khóa theo type | [ ] |
| SC-003: Cấm tự duyệt creative (REQ-OPS-006) | OPS_CONT vừa soạn xong bài | Gọi API đặt chính mình làm approver bước nội dung | Chặn "CAM_TU_DUYET" tại service; pipeline buộc bước tiếp theo do vai khác giữ | [ ] |
| SC-004: Reject thiếu comment bị chặn (REQ-OPS-006) | Creative đang `IN_REVIEW` | OPS_AM gọi Request changes không kèm comment | Từ chối "THIEU_COMMENT"; trạng thái giữ nguyên; revision_count không tăng | [ ] |
| SC-005: Vòng sửa thứ 4 escalate (REQ-OPS-006) | Deliverable đã qua 3 vòng sửa nội bộ | Nộp duyệt lần thứ 4 | Bắt buộc escalate AM/TL chốt phạm vi bằng văn bản trước khi mở `IN_PROGRESS`; có log | [ ] |
| SC-006: Change log chặn thiếu reason (REQ-OPS-006) | OPS_ADS đổi ngân sách campaign | Gọi API không nhập reason | Từ chối "THIEU_REASON" tầng API; không có entry mới; GW không nhận thay đổi | [ ] |
| SC-007: Phân bậc duyệt vượt hạn mức (REQ-OPS-006) | Thay đổi vượt hạn mức ngày của buyer | Gọi API thay đổi ngân sách | Entry vào `PENDING_APPROVAL` tầng TL; vượt cả hạn mức dự án → chuyển AM; chưa duyệt không đẩy platform | [ ] |
| SC-008: Khẩn cấp pause + bổ sung reason 4h (REQ-OPS-006) | Die account ngoài giờ | Pause campaign ngay, bổ sung reason sau 2h | Hợp lệ; quá 4h LV → vi phạm riêng báo TL với dấu "KHẨN CẤP THIẾU LOG" | [ ] |
| SC-009: Nghiệm thu chưa đủ điều kiện (REQ-OPS-006) | Milestone còn 1 node `IN_REVIEW` | AM gọi đề xuất nghiệm thu | Từ chối "MILESTONE_CHUA_DU"; READY chỉ tự tính khi 100% `APPROVED` | [ ] |
| SC-010: Không áp im lặng = đồng ý (REQ-OPS-006) | Milestone `PENDING_CUSTOMER` quá 4 ngày LV, khách không phản hồi | Job nhắc/escalate chạy | Ngày 2 nhắc khách, ngày 4 escalate AD (log); trạng thái vẫn `PENDING_CUSTOMER` — không auto-accept | [ ] |
| SC-011: Tenant isolation portal (REQ-OPS-006) | Khách tenant A | Gọi API portal đọc tiến độ tenant B | Từ chối + audit log bảo mật; payload không chứa giá vốn/chiết khấu/P&L/ghi chú nội bộ | [ ] |
| SC-012: Confirm nghiệm thu chỉ do khách (REQ-OPS-006) | Milestone `PENDING_CUSTOMER` | OPS_AM cố gọi endpoint confirm thay khách | Từ chối "CHI_KHACH_CONFIRM"; endpoint chỉ nhận phiên CLIENT_USER/ADMIN của tenant | [ ] |
| SC-013: Campaign mồ côi tự pause (REQ-OPS-006 × REQ-OPS-001) | Campaign mất gắn dự án | Job quét 4h LV | Campaign pause tự động + alert OPS_ADS/AM; chi tiêu mới chặn tới khi gắn lại | [ ] |
| SC-014: GMV không vào doanh thu (REQ-OPS-006 × REQ-OPS-011) | Campaign gắn TikTok Shop có GMV | Gọi mapping GMV vào doanh thu agency | Validation chặn "GMV_KHONG_VAO_DOANH_THU"; GMV chỉ tồn tại như chỉ số tham chiếu | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (bao gồm endpoint portal read-only theo share scope) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW đẩy thay đổi xuống platform + kéo chi tiêu theo campaign; portal share; event nhắc/escalate) |
| Màn hình UI (WEB — lịch nội dung, pipeline creative, form thay đổi) | `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md` |
| Màn hình khách (PORTAL/M-PORTAL — tiến độ, confirm nghiệm thu) | `phase4-ux/portal-web/campaign-deliverable/[screen-group].md` |
| Feature liên quan cùng module | `a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` (FEAT-CORE-CAMP-002 — đăng ký thí nghiệm, evidence, learning log trên cùng core backend) |
| Capacity engine | `../capacity-timesheet/capacity-va-timesheet.md` (FEAT-CORE-CAPTS-002 — capacity check trước mọi gán) |
| Policy nghiệp vụ | `policies/kiem-soat-vi-tkqc-giao-dich-tien.md` §2.4 (hạn mức theo bậc); `policies/sla-khach-hang.md` §2.1 (tier × priority) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 3 B1–B7, ma trận RACI, handoff SLA) |
