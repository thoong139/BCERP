# Tính Năng: A/B Testing & Chiến Lược Campaign Theo Mục Tiêu Khách (Core Backend — Đăng Ký Thí Nghiệm, Evidence, Learning Log)

> **Dựa trên:** REQ-OPS-012 trong `phase1-business/departments/operations/operations.md` (Phần A3, Phần B.10 — BR-OPS-10.1 đến BR-OPS-10.4); `phase1-business/P1-02-business-workflow.md` Luồng 3 (B5, B7); ngưỡng sample size đã chốt theo DI-005 (`work/wf-analyze-requirements/deferred-issues.md`)
> **Phân hệ:** Vận hành — Thử nghiệm A/B và chiến lược campaign trên domain service (SYS-CORE-BACKEND)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 3), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/campaign-deliverable/[screen-group].md`, `phase5-implementation/tasks/core-backend/campaign-deliverable/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp: **FEAT-CORE-CAMP-002**. REQ-OPS-012 fan-out ra 4 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (headless API/domain service); counterparts: SYS-INTEGRATION-GW (kéo dữ liệu hiệu quả theo variant từ platform, nhãn `manual` khi degraded), SYS-BCERP-WEB (form đăng ký, dashboard kết quả, nút kết luận), SYS-MOBILE-INTERNAL (thông báo duyệt, đề xuất dừng variant). Cross-dependency: không có. Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CAMP-002 |
| Module | MOD-CAMPAIGN-DELIVERABLE (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-012 (A/B Testing & chiến lược campaign theo mục tiêu khách); tham chiếu REQ-OPS-006 (campaign change log bất biến — FEAT-CORE-CAMP-001 cùng module), REQ-OPS-011 (TikTok Shop GMV tách bạch) |
| Người dùng liên quan | OPS_ADS (đăng ký, thực hiện, kết luận đề xuất), OPS_PLAN (duyệt chiến lược, đánh giá giao thoa audience, review playbook quý), OPS_AM (theo dõi, cập nhật khách bằng learning), OPS_CONT, OPS_DES, OPS_EDIT (cung cấp variant creative, đọc kết quả variant thắng), SYS_ADMIN (hạ tầng, không có quyền nghiệp vụ) |
| Độ ưu tiên | Trung bình (MEDIUM · Phase 2 · GĐ2 thiết kế thử nghiệm gắn campaign → GĐ3 phân tích chéo đầy đủ) |
| Giai đoạn | Giai đoạn 2 (GĐ2) — mở rộng phân tích chéo ở Giai đoạn 3 |
| Phụ thuộc | Campaign + change log bất biến của REQ-OPS-006 (FEAT-CORE-CAMP-001 — mọi thay đổi ngân sách trong thử nghiệm đi qua change log); dữ liệu hiệu quả theo variant từ SYS-INTEGRATION-GW; objective khách từ hồ sơ khách |
| Ghi chú Expert (A7) | Mục A7 trong `operations.md` đang "chờ đánh giá" — chưa có điều chỉnh chính thức. Số sample size/ngưỡng khai thắng đã chốt theo DI-005 (nguồn v2.3); khung confidence 95% là mức đề xuất kèm theo. Các khoản KXN còn mở liên quan ghi ở Trường Hợp Đặc Biệt dưới tag `[KXN-n]` — không tự quyết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Feature này là **domain service quản trị vòng đời thí nghiệm A/B gắn campaign** trên core backend, ép chuỗi kỷ luật "đăng ký trước — duyệt trước — chạy có kiểm soát — kết luận phải có evidence — học hỏi quay lại playbook": thí nghiệm không đăng ký không được chi ngân sách, kết luận không dựa trên cảm tính mà trên ngưỡng significance chốt sẵn, và mọi learning thắng/thua được thư viện hóa theo khách/ngành để tái sử dụng thành chiến lược campaign theo đúng mục tiêu khách (conversion/traffic/awareness). Toàn bộ ràng buộc (đủ trường đăng ký, chống chồng chéo audience, evidence gắn change log) được **enforce tại tầng service** — WEB chỉ là bề mặt thao tác.

**Phạm vi:**
- Bao gồm: đối tượng đăng ký thí nghiệm (giả thuyết, metric chính duy nhất theo mục tiêu khách, variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến — thiếu trường không lưu được) với phễu duyệt OPS_PLAN trước khi triển khai; engine chặn chi ngân sách cho campaign gắn thí nghiệm chưa đăng ký/được duyệt; kiểm tra overlap audience giữa các thí nghiệm active cùng khách (1 thí nghiệm active/segment, bắt buộc exclusion hoặc chờ); tổng hợp KPI theo variant từ dữ liệu GW (đánh dấu nguồn `manual` khi degraded) và đề xuất dừng/khai thắng khi đạt ngưỡng DI-005 (chênh ≥20% + ≥50 clicks hoặc ≥10 conversions, khung confidence 95%); tạo kết luận (win/lose/no signal) bắt buộc gắn evidence vào change log bất biến; thư viện learning log theo khách/ngành + vòng review quý cập nhật playbook.
- Không bao gồm: state machine campaign, WBS, duyệt creative, nghi thức nghiệm thu và change log engine (FEAT-CORE-CAMP-001 — cùng module, được service này gọi tới); kéo dữ liệu platform/OAuth và xử lý PII (SYS-INTEGRATION-GW); form đăng ký/dashboard kết quả (SYS-BCERP-WEB), thông báo di động (SYS-MOBILE-INTERNAL); đối soát chi tiêu tài chính (DEPT-FINANCE); chạy A/B ngoài nền tảng quảng cáo (email/landing page — ngoài phạm vi REQ-OPS-012).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản spec này là **core backend headless**: OPS_ADS thiết kế và kết luận qua WEB nội bộ (responsive browser UI), nhận đề xuất dừng variant qua M-INT (React Native), dữ liệu hiệu quả chảy từ GW — nhưng tính hợp lệ của thí nghiệm (đủ trường, không overlap, đủ evidence khi kết luận) do service layer duy nhất quyết định. Khách hàng không thấy thí nghiệm nội bộ theo mặc định: chỉ phần AM chủ động share theo hợp đồng, qua API portal có tenant isolation.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Gọi API đăng ký thí nghiệm gắn campaign với đầy đủ giả thuyết, metric chính duy nhất, variant, audience, thời lượng, ngân sách, sample size dự kiến — thiếu trường thì hệ thống không lưu | Buộc mình tư duy thiết kế thử nghiệm nghiêm túc trước khi tiêu đồng nào |
| 2 | OPS_ADS | Bị chặn chi ngân sách cho campaign gắn thí nghiệm chưa qua duyệt | Không có cơ hội "chạy trước xin sau" làm loạn dữ liệu và ngân sách |
| 3 | OPS_PLAN | Duyệt/từ chối đăng ký với SLA, và bị hệ thống cảnh báo ngay khi thí nghiệm mới trùng segment với thí nghiệm đang chạy | Mỗi audience chỉ mang 1 thí nghiệm tại một thời điểm — kết quả không nhiễm giao thoa |
| 4 | OPS_PLAN | Khi exception (thí nghiệm trên platform khác nhưng cùng tệp mục tiêu), được đánh giá rủi ro giao thoa rồi mới duyệt kèm lý do bắt buộc | Cửa exception có kiểm soát, không phải lỗ hổng mặc định |
| 5 | OPS_ADS | Nhận đề xuất dừng/khai thắng variant khi metric chính đạt ngưỡng đã chốt (chênh ≥20% + ≥50 clicks hoặc ≥10 conversions) | Quyết định dựa trên dữ liệu đến sớm thay vì chờ hết duration vô ích |
| 6 | OPS_ADS | Nút kết luận (win/lose/no signal) chỉ mở khi có evidence: số KPI theo variant, thời gian chạy, sample đạt — gắn thẳng vào change log | Mỗi kết luận để lại bằng chứng không thể bịa lại, đủ để bất kỳ ai tra lại sau nửa năm |
| 7 | OPS_AM | Đọc learning log của khách/ngành và được dùng lại làm câu chuyện chiến lược khi cập nhật khách | Cam kết với khách chỉ dừng ở đầu vào (budget, content, thời lượng) — không hứa KPI cứng ngoài hợp đồng |
| 8 | OPS_CONT / OPS_DES / OPS_EDIT | Xem variant nào thắng để nhân bản format/tone cho deliverable kế tiếp | Sản xuất creative dựa trên bằng chứng thay vì thị hiếu |
| 9 | OPS_PLAN | Review learning log theo quý và duyệt cập nhật playbook/template chiến lược thành mặc định cho proposal mới | Bài học từng thí nghiệm biến thành năng lực tổ chức, không mất theo lần nghỉ việc |
| 10 | OPS_ADS | Khi GW degraded (thiếu quyền API platform), dữ liệu variant được gắn nhãn `manual` và hệ thống chặn khai thắng trên dữ liệu thiếu | Không khai thắng trên con số nhập tay chưa được đối chiếu |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ rule enforce tại tầng service/domain engine của core backend; audit log append-only + hash-chain; tenant isolation trên mọi endpoint. Nguồn chính: `operations.md` B.10 (BR-OPS-10.1–10.4), DI-005 (ngưỡng chốt 12/09/2026), DI-007 (degraded mode).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Đăng ký thí nghiệm bắt buộc trước khi chạy:** đăng ký gắn campaign, bắt buộc đủ: giả thuyết, **metric chính duy nhất** (primary KPI theo mục tiêu khách: conversion/traffic/awareness), variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến; thiếu trường → không lưu được đăng ký; **OPS_PLAN duyệt trước khi triển khai**. Nguồn: BR-OPS-10.1. | API lưu đăng ký thiếu trường → từ chối "THIEU_TRUONG_DANG_KY"; chưa duyệt → trạng thái không cho phép chi |
| BR-002 | **Không đăng ký = không chi ngân sách:** thí nghiệm không đăng ký (hoặc chưa được duyệt) không được chi ngân sách — service chặn ở tầng campaign gắn thử nghiệm, độc lập với kênh client. Nguồn: BR-OPS-10.1. | Chi tiêu phát sinh trên campaign thí nghiệm chưa duyệt → chặn + alert OPS_PLAN; entry bị đánh dấu vi phạm trong audit |
| BR-003 | **Chống chồng chéo audience:** trên cùng một audience/tenant khách, mỗi thời điểm chỉ **1 thí nghiệm active**; đăng ký mới trùng segment với thí nghiệm đang chạy → chặn, bắt buộc chọn audience loại trừ (exclusion) hoặc chờ kết thúc; service kiểm overlap trước khi cho duyệt. Nguồn: BR-OPS-10.2. | Đăng ký trùng segment → chặn "OVERLAP_AUDIENCE"; chuyển tiếp chỉ mở khi thí nghiệm cũ `CONCLUDED` hoặc exclusion hợp lệ |
| BR-004 | **Exception giao thoa có kiểm soát:** thí nghiệm trên platform khác nhau nhưng cùng tệp mục tiêu → OPS_PLAN đánh giá rủi ro giao thoa rồi mới duyệt, **ghi lý do bắt buộc** vào đăng ký. Nguồn: BR-OPS-10.2 exception. | Duyệt exception thiếu lý do → từ chối "THIEU_LY_DO_EXCEPTION"; mọi exception nằm trong dashboard bản đồ thí nghiệm |
| BR-005 | **Ngưỡng khai thắng chốt theo DI-005:** winner chỉ được khai khi metric chính **chênh ≥20%** so với variant đối chứng **và** đạt **≥50 clicks hoặc ≥10 conversions**; khung **confidence 95%** là mức nội bộ áp dụng (đề xuất kèm DI-005). Hết duration mà chưa đủ sample → kết luận **"no signal"** + quyết định gia hạn/dừng có lý do. Nguồn: BR-OPS-10.3; DI-005 mục (1). | Khai thắng dưới ngưỡng → từ chối "CHUA_DAT_NGUONG"; không thể kết luận win/lose trên sample chưa đạt |
| BR-006 | **Kết luận phải có evidence trên change log:** dừng variant/khai thắng chỉ khi đạt ngưỡng; kết luận (win/lose/no signal) bắt buộc tạo **entry change log gắn evidence**: số KPI theo variant, thời gian chạy, sample đạt; cảm tính/"có vẻ tốt" không là căn cứ. Nguồn: BR-OPS-10.3; P1-02 B5. | Kết luận thiếu evidence → nút kết luận khóa "THIEU_EVIDENCE"; entry change log tự sinh với giá trị cũ/mới theo chuẩn BR-OPS-7.4 |
| BR-007 | **Mọi thay đổi ngân sách trong thử nghiệm qua change log bất biến:** tăng/giảm ngân sách variant, kéo dài thời lượng, đổi audience giữa chừng — tất cả đi qua campaign change log (FEAT-CORE-CAMP-001) với reason, phân bậc duyệt buyer → TL → AM. Nguồn: BR-OPS-10.3; BR-OPS-7.4. | Thay đổi không qua change log → không được GW đẩy xuống platform; entry lệch bị hoàn tác logic và báo lệch dữ liệu |
| BR-008 | **Không cam kết KPI cứng cho khách:** thí nghiệm và kết quả không tạo cam kết KPI đầu ra ngoài hợp đồng — chỉ cam kết đầu vào (ngân sách, nội dung, thời lượng) theo `hop-dong-loi-nda-brand-safety.md` §2.5; trường "cam kết KPI" không tồn tại trong đăng ký. Nguồn: BR-OPS-10.3; REQ-OPS-012. | Nhập cam kết KPI vào bất kỳ entity thí nghiệm nào → schema không có field; tài liệu share khách bị lọc theo quy tắc này |
| BR-009 | **Chiến lược bám mục tiêu khách:** objective của thí nghiệm bắt buộc trùng họ mục tiêu khách đã đăng ký trên hồ sơ (conversion/traffic/awareness); đổi objective giữa chừng = hủy thí nghiệm + đăng ký mới, không sửa lụa. Nguồn: REQ-OPS-012; BR-OPS-10.1. | Đổi objective trực tiếp → từ chối "OBJECTIVE_BAT_BIEN"; phải kết luận/dừng thí nghiệm cũ trước |
| BR-010 | **Dữ liệu degraded có nhãn `manual`:** khi GW thiếu quyền API platform (DI-007), dữ liệu hiệu quả theo variant được nhập/nhãn `manual`; kết luận khai thắng trên dữ liệu `manual` bị chặn — chỉ cho phép ghi nhận "no signal/chờ đối chiếu" kèm lý do. Nguồn: DI-007; BR-OPS-10.3 góc dữ liệu. | Khai thắng trên dữ liệu manual → chặn "DU_LIEU_THU_CONG"; entry đánh dấu nguồn để đối chiếu khi API sẵn sàng |
| BR-011 | **TikTok Shop tách bạch GMV khi thí nghiệm liên quan:** thí nghiệm trên TikTok Shop dùng GMV/đơn/settlement như chỉ số tham chiếu thuộc về khách — chặn mọi mapping GMV vào doanh thu agency; metric chính của thí nghiệm không được đặt là GMV-agency. Nguồn: REQ-OPS-011; BR-OPS-7.5 góc dữ liệu. | Mapping GMV vào doanh thu → validation chặn "GMV_KHONG_VAO_DOANH_THU" |
| BR-012 | **Learning log + review quý:** OPS_ADS ghi learning (thắng/thua) gắn thí nghiệm + change log entry ngay khi kết luận; OPS_PLAN review theo quý → cập nhật playbook/template chiến lược (content brief, cấu trúc campaign, audience playbook) thành mặc định cho proposal mới; cập nhật template là **thay đổi chính sách nội bộ — có log + OPS_PLAN duyệt**. Nguồn: BR-OPS-10.4. | Learning không gắn thí nghiệm → từ chối lưu; cập nhật playbook không qua duyệt → không trở thành mặc định |
| BR-013 | **Deliverable trong thử nghiệm vẫn theo nghi thức REQ-OPS-006:** variant creative sản xuất qua WBS, duyệt đa vai với SLA theo tier, tối đa 3 vòng sửa, nghiệm thu 3 ngày (nhắc ngày 2, escalate AD ngày 4, không im lặng = đồng ý) — service này không tạo luồng sản xuất riêng. Nguồn: FEAT-CORE-CAMP-001; BR-OPS-7.3/7.5. | Tạo variant ngoài WBS → từ chối "TASK_MO_COI"; luồng sản xuất song song không hợp lệ |
| BR-014 | **Audit bất biến + tenant isolation + enforce một điểm:** mọi event (đăng ký, duyệt, exception, kết luận, learning, cập nhật playbook) ghi append-only + hash-chain; endpoint scope cứng theo tenant; portal khách không có endpoint đọc thí nghiệm nội bộ trừ phần được share tường minh. Nguồn: Notes lane touchpoint; REQ-OPS-010 góc share. | Request chéo tenant → từ chối + audit log bảo mật; đứt hash → alert BOD_CEO |

---

## 4. Phân Quyền

> Quyền enforce bằng vai tại tầng API core backend (role re-check mỗi request); counterpart WEB/M-INT chỉ phản chiếu kết quả tra quyền — không tạo quyền riêng ở tầng UI. REQ-OPS-012 không có portal trong fan-out: CUSTOMER không có quyền nào trên thí nghiệm nội bộ (chỉ nhận phần AM share ngoài phạm vi feature này).

| Hành động | OPS_ADS | OPS_PLAN | OPS_AM | OPS_CONT / OPS_DES / OPS_EDIT | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|----------|--------|-------------------------------|------------------------|-----------|
| Đăng ký thí nghiệm (đủ trường bắt buộc) | ✅ | ✅ (giúp soạn) | ❌ | ❌ | ❌ | ❌ |
| Duyệt / từ chối đăng ký thí nghiệm | ❌ | ✅ (duyệt duy nhất) | ❌ | ❌ | ❌ | ❌ |
| Duyệt exception giao thoa (kèm lý do) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Thay đổi ngân sách/thời lượng giữa chừng (qua change log) | ✅ (trong hạn mức) | ❌ | ✅ (vượt hạn mức dự án) | ❌ | ❌ | ❌ |
| Xem KPI theo variant + dashboard kết quả | ✅ | ✅ | ✅ (theo khách mình) | ✅ (variant creative liên quan) | ✅ (tổng hợp) | ❌ |
| Đề xuất dừng/khai thắng khi đạt ngưỡng | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Chốt kết luận (win/lose/no signal) có evidence | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Khai thắng trên dữ liệu `manual` (degraded) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chặn mọi vai — chỉ ghi no signal/chờ đối chiếu) |
| Ghi learning log | ✅ | ✅ | ✅ (ghi chú góc khách) | ✅ (learning sản xuất) | ❌ | ❌ |
| Review learning log theo quý, cập nhật playbook | ❌ | ✅ (duyệt + log) | ❌ | ❌ | ❌ | ❌ |
| Sửa kết luận đã chốt / xóa evidence | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |
| Xem audit log thí nghiệm | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ (đọc — xem log cũng bị log) |

> Ghi chú touchpoint: OPS_CONT/DES/EDIT tham gia với vai cung cấp variant và đọc kết quả để nhân bản format — không có quyền duyệt hay kết luận; OPS_PLAN giữ toàn bộ "cửa ải" chiến lược (duyệt đăng ký, exception, playbook). Mọi quyền thực thi tại service layer của core backend.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý — mọi xử lý qua service layer, có log, không sửa tay trên dữ liệu.*

- **Hết duration chưa đủ sample:** thí nghiệm chuyển `NO_SIGNAL` thay vì bị khai thắng tùy tiện — OPS_ADS chọn gia hạn (có lý do, qua change log, ngân sách tương ứng) hoặc dừng; gia hạn không tái sử dụng sample cũ để "gộp ngẫu nhiên" vượt ngưỡng, sample tính lại theo thời gian chạy cộng dồn có log.
- **GW degraded kéo dài (DI-007):** thí nghiệm vẫn chạy trên platform nhưng KPI tự động gắn nhãn `manual` — dashboard hiển thị rõ "chờ đối chiếu"; khi API quyền được cấp, job backfill đối chiếu số manual vs số API và báo lệch; kết luận chỉ hợp lệ trên dữ liệu đã đối chiếu.
- **Khách có nhiều brand/tệp audience trong cùng tenant:** overlap check tính theo segment cụ thể (audience definition), không chặn oan 2 thí nghiệm trên 2 tệp rời nhau — nhưng cùng tệp mục tiêu qua platform khác nhau vẫn rơi vào exception BR-004.
- **Thí nghiệm hủy giữa chừng vì die account/sự cố platform:** kết luận bắt buộc "no signal" (nguyên nhân ghi rõ), không cho phép khai thắng trên dữ liệu đứt quãng; ngân sách đã chi vẫn nằm trong change log để đối chiếu hiệu quả.
- **Variant creative trùng với deliverable đang nghiệm thu:** variant là WBS node bình thường — nếu khách đã nghiệm thu nội dung cũ, thay đổi variant tạo deliverable mới, không đè nội dung đã nghiệm thu (nghi thức 3 ngày của REQ-OPS-006 không bị vòng đời thí nghiệm phá vỡ).
- **Learning log chéo khách/ngành:** tra cứu theo ngành cho phép đọc learning của khách khác trong nội bộ, nhưng share ra ngoài tenant khác bị chặn tuyệt đối; template rút ra từ learning (playbook) là tài sản nội bộ không gắn tenant.
- **Cập nhật playbook đổi mặc định proposal:** là thay đổi chính sách nội bộ — phiên playbook effective-dated, có log + OPS_PLAN duyệt; proposal đang soạn không tự đổi template giữa chừng, áp từ bản tiếp theo.
- **Phạm vi "tương lai" chưa chốt:** gợi ý thiết kế thí nghiệm bằng AI/CMS hoặc auto-optimize nằm ngoài scope feature này theo phân loại trạng thái nguồn `[KXN-9 — phạm vi CMS/TMS/AI Agent còn mở]`; bộ cờ cảnh báo K6–K12 nếu gắn vào dashboard thí nghiệm thì chờ danh sách đầy đủ `[KXN-20 — cờ cảnh báo K6–K12 còn mở]`; RACI chi tiết các bước duyệt chờ xác nhận ma trận chính thức `[KXN-19 — ma trận RACI còn mở]` — ba khoản này ghi nhận như assumption, không tự quyết.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Thí nghiệm A/B (`Experiment`) — đối tượng trung tâm quản trạng thái; variant và kết luận kế thừa trạng thái phái sinh. Ngân sách của thí nghiệm không có state riêng mà đi qua change log của campaign (BR-007).

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đủ trường bắt buộc)──► [PENDING_APPROVAL]
[PENDING_APPROVAL] ──(OPS_PLAN duyệt; overlap check pass)──► [RUNNING]
[PENDING_APPROVAL] ──(từ chối / trùng segment không exclusion)──► [REJECTED]
[RUNNING] ──(đạt ngưỡng DI-005: chênh ≥20% + ≥50 clicks hoặc ≥10 conversions)──► [CONCLUDED] (win/lose + evidence)
[RUNNING] ──(hết duration chưa đủ sample)──► [NO_SIGNAL] ──(gia hạn có lý do)──► [RUNNING]
                                      └──────────────(dừng có lý do)──► [CONCLUDED]
[RUNNING] ──(hủy: die account / đổi objective)──► [CONCLUDED] (no signal — nguyên nhân ghi rõ)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit đăng ký | `PENDING_APPROVAL` | OPS_ADS | Đủ 7 trường bắt buộc: giả thuyết, metric chính duy nhất, variant, audience, thời lượng, ngân sách, sample size dự kiến |
| `PENDING_APPROVAL` | Duyệt | `RUNNING` | OPS_PLAN | Overlap check pass (hoặc exception có lý do); campaign gắn thí nghiệm hợp lệ |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | OPS_PLAN | Lý do bắt buộc; sửa xong tạo đăng ký mới, không sửa lụa bản cũ |
| `RUNNING` | Khai thắng / chốt thua | `CONCLUDED` | OPS_ADS / OPS_PLAN | Đạt ngưỡng BR-005; evidence (KPI theo variant, thời gian, sample) gắn change log; dữ liệu không phải nhãn `manual` chưa đối chiếu |
| `RUNNING` | Hết duration đủ sample, kết luận | `CONCLUDED` | OPS_ADS | Giống trên; hệ thống sinh đề xuất trước, người chốt sau |
| `RUNNING` | Hết duration thiếu sample | `NO_SIGNAL` | Hệ thống | Tự chuyển theo job hết hạn; yêu cầu quyết định gia hạn/dừng |
| `NO_SIGNAL` | Gia hạn | `RUNNING` | OPS_ADS (đề xuất) + phân bậc duyệt ngân sách | Lý do bắt buộc qua change log; thời lượng + ngân sách mới ghi rõ |
| `NO_SIGNAL` | Dừng | `CONCLUDED` | OPS_ADS / OPS_PLAN | Kết luận "no signal" + evidence sample thực đạt |
| `RUNNING` | Hủy (die account, sự cố) | `CONCLUDED` | OPS_ADS / OPS_PLAN | Nguyên nhân ghi rõ; kết luận cố định "no signal", cấm khai thắng |

**Quy tắc:**
- Không có đường từ `DRAFT`/`PENDING_APPROVAL` sang `RUNNING` ngoài phễu duyệt OPS_PLAN — không tồn tại auto-start theo lịch.
- `CONCLUDED` và `REJECTED` là trạng thái kết thúc — không chuyển tiếp; thí nghiệm lại tạo entity mới và check lại overlap.
- Kết luận gắn `LearningLog` bắt buộc trong vòng sống thí nghiệm (BR-012) — `CONCLUDED` không có learning entry được job quý đánh dấu thiếu.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Experiment` | `campaign_id`, `hypothesis`, `primary_metric` (`CONVERSION/TRAFFIC/AWARENESS`), `audience_def`, `duration_days`, `budget`, `expected_sample`, `state` (`DRAFT/PENDING_APPROVAL/RUNNING/NO_SIGNAL/CONCLUDED/REJECTED`), `approved_by/at` | FK → `campaigns`, `users` | 7 trường bắt buộc; không đăng ký/không duyệt → chặn chi ngân sách |
| `ExperimentVariant` | `experiment_id`, `variant_key` (A/B/C...), `creative_ref` (WBS node), `is_control`, `status` (`RUNNING/STOPPED/WINNER/LOSE`) | FK → `experiments`, `wbs_nodes` | Variant creative sinh qua WBS — không ngoài nghi thức REQ-OPS-006 |
| `AudienceOverlapCheck` | `experiment_id`, `segment_hash`, `conflict_experiment_id`, `result` (`PASS/EXCLUSION/BLOCKED/EXCEPTION`), `reason` | FK → `experiments` | 1 thí nghiệm active/segment; exception phải có lý do OPS_PLAN |
| `VariantKpiSnapshot` | `variant_id`, `metric_date`, `clicks`, `conversions`, `conv_rate`, `spend`, `data_source` (`API/MANUAL`), `reconciled` | FK → `experiment_variants` | Nguồn GW; `MANUAL` (degraded) không đủ điều kiện khai thắng |
| `ExperimentConclusion` | `experiment_id`, `result` (`WIN/LOSE/NO_SIGNAL`), `evidence_ref` (KPI snapshots + thời gian + sample), `change_log_entry_id`, `concluded_by/at` | FK → `experiments`, `campaign_change_logs` | Bắt buộc gắn evidence + change log; cảm tính không là căn cứ |
| `LearningLog` | `experiment_id`, `industry`, `tenant_scope`, `lesson` (thắng/thua), `author_id`, `created_at` | FK → `experiments` | Thư viện tra cứu theo khách/ngành; không share chéo tenant |
| `PlaybookVersion` | `version`, `effective_from`, `changes_summary`, `approved_by` (OPS_PLAN), `source_learnings` | — | Effective-dated; cập nhật = thay đổi chính sách nội bộ có log |
| `AuditLog` | `actor_id`, `role`, `action`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | — | Append-only + hash-chain; đứt hash → alert |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-012 (`operations.md` A3/B.10 — BR-OPS-10.1 đến 10.4) và P1-02 Luồng 3 B5/B7.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đăng ký thiếu trường bị chặn (REQ-OPS-012) | OPS_ADS tạo đăng ký thiếu sample size dự kiến | Gọi API lưu | Từ chối "THIEU_TRUONG_DANG_KY"; không có lưu nháp không đủ trường từ kênh nào | [ ] |
| SC-002: Chưa duyệt không được chi (REQ-OPS-012) | Thí nghiệm đang `PENDING_APPROVAL` | Campaign gắn thí nghiệm phát sinh chi tiêu | Chặn chi + alert OPS_PLAN; entry vi phạm trong audit log | [ ] |
| SC-003: Trùng segment bị chặn (REQ-OPS-012) | Đã có thí nghiệm `RUNNING` trên segment X | Đăng ký thí nghiệm mới trùng segment X, không exclusion | Chặn "OVERLAP_AUDIENCE"; chỉ mở khi exclusion hợp lệ hoặc thí nghiệm cũ `CONCLUDED` | [ ] |
| SC-004: Exception giao thoa có lý do (REQ-OPS-012) | Thí nghiệm Meta + Google cùng tệp mục tiêu | OPS_PLAN duyệt exception | Chỉ hợp lệ kèm lý do bắt buộc; hiển thị trên bản đồ thí nghiệm theo khách | [ ] |
| SC-005: Đề xuất dừng khi đạt ngưỡng (REQ-OPS-012) | Variant B chênh 25% conversion, 60 clicks, 12 conversions | Job tổng hợp KPI chạy | Hệ thống sinh đề xuất dừng/khai thắng cho OPS_ADS qua API + push M-INT | [ ] |
| SC-006: Khai thắng dưới ngưỡng bị chặn (REQ-OPS-012) | Variant chênh 10%, 30 clicks | Gọi kết luận WIN | Từ chối "CHUA_DAT_NGUONG"; chỉ ghi nhận chờ thêm sample | [ ] |
| SC-007: Kết luận bắt buộc evidence (REQ-OPS-012) | Thí nghiệm đạt ngưỡng | Gọi kết luận không kèm evidence | Nút kết luận khóa "THIEU_EVIDENCE"; entry change log chỉ sinh khi đủ KPI + thời gian + sample | [ ] |
| SC-008: Hết duration thiếu sample → no signal (REQ-OPS-012) | Thí nghiệm hết 14 ngày, sample 35 clicks | Job hết hạn chạy | Tự chuyển `NO_SIGNAL`; yêu cầu gia hạn/dừng có lý do; cấm khai thắng | [ ] |
| SC-009: Thay đổi ngân sách qua change log (REQ-OPS-012 × REQ-OPS-006) | OPS_ADS tăng ngân sách variant giữa chừng | Gọi API tăng ngân sách | Entry change log bất biến (reason + phân bậc buyer/TL/AM); không qua log → GW không đẩy platform | [ ] |
| SC-010: Không có field cam kết KPI (REQ-OPS-012) | Thiết kế đăng ký thí nghiệm | Rà soát schema + API | Không tồn tại trường "cam kết KPI đầu ra" — chỉ cam kết đầu vào; tài liệu share khách đã lọc | [ ] |
| SC-011: Khai thắng trên dữ liệu manual bị chặn (REQ-OPS-012 × DI-007) | GW degraded, KPI nhãn `MANUAL` | Gọi kết luận WIN | Chặn "DU_LIEU_THU_CONG"; chỉ ghi no signal/chờ đối chiếu; backfill đối chiếu khi API sẵn sàng | [ ] |
| SC-012: Objective bất biến (REQ-OPS-012) | Thí nghiệm `RUNNING` objective conversion | Gọi API đổi objective thành traffic | Từ chối "OBJECTIVE_BAT_BIEN"; buộc hủy có nguyên nhân + đăng ký mới | [ ] |
| SC-013: Learning gắn thí nghiệm (REQ-OPS-012) | OPS_ADS ghi learning sau kết luận | Lưu learning không gắn `experiment_id` | Từ chối lưu; learning hợp lệ nằm trong thư viện tra cứu theo khách/ngành | [ ] |
| SC-014: Cập nhật playbook có duyệt (REQ-OPS-012) | OPS_PLAN rà learning quý | Cập nhật template chiến lược | Phiên playbook effective-dated + log; không qua duyệt không trở thành mặc định proposal mới | [ ] |
| SC-015: Tenant isolation (Notes lane) | Tenant A (khách A) | Truy vấn thí nghiệm/KPI tenant B qua API | Từ chối + audit log bảo mật; learning chéo tenant chỉ đọc trong nội bộ, không share ngoài | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (đăng ký, duyệt, overlap check, KPI snapshot, kết luận, learning) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW kéo dữ liệu hiệu quả theo variant + nhãn manual khi degraded; change log → GW đẩy platform; đề xuất dừng → M-INT) |
| Màn hình UI (WEB — form đăng ký, dashboard kết quả, nút kết luận) | `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md` |
| Feature liên quan cùng module | `campaign-va-deliverable-management.md` (FEAT-CORE-CAMP-001 — campaign change log bất biến, WBS, nghi thức nghiệm thu trên cùng core backend) |
| Policy nghiệp vụ | `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (hằng số quy trình); `policies/hop-dong-loi-nda-brand-safety.md` §2.5 (chỉ cam kết đầu vào) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 3 B5 change log, B7 dữ liệu nền tảng; ma trận RACI B5) |
