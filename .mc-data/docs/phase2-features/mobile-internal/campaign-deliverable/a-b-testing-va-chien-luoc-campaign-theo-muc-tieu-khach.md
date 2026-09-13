# Tính Năng: A/B Testing & Chiến Lược Campaign Theo Mục Tiêu Khách

> **Dựa trên:** REQ-OPS-012 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Vận hành — OPS (SYS-MOBILE-INTERNAL — mobile nội bộ BCERP, React Native, offline-capable)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
>
> **Fan-out:** REQ-OPS-012 xuất hiện ở 4 systems — đây là bản riêng cho SYS-MOBILE-INTERNAL. Counterparts: SYS-CORE-BACKEND (đối tượng thử nghiệm, tổng hợp KPI, chặn chi khi chưa đăng ký), SYS-INTEGRATION-GW (dữ liệu variant, nhãn `manual` khi degraded), SYS-BCERP-WEB (form đăng ký + dashboard kết quả — nơi thao tác chính).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CAMP-002 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-012 (A/B Testing & chiến lược campaign theo mục tiêu khách) |
| Người dùng liên quan | OPS_ADS, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT (sản xuất creative variant) |
| Độ ưu tiên | Trung bình (MEDIUM — Quan trọng) |
| Giai đoạn | Giai đoạn 2 (thiết kế thử nghiệm gắn campaign) → Giai đoạn 3 (phân tích chéo đầy đủ) |
| Phụ thuộc | Không có cross-dependency trong lane; phụ thuộc chức năng change log bất biến của FEAT-MBI-CAMP-001 (cùng module) và dữ liệu chi tiêu/hiệu quả theo campaign từ SYS-INTEGRATION-GW (counterpart REQ-OPS-012) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho đội OPS chạy thí nghiệm A/B có kỷ luật gắn với mục tiêu khách: đăng ký trước khi chạy, OPS_PLAN duyệt trước khi chi ngân sách, chống giao thoa audience, kết luận chỉ dựa trên evidence đủ ngưỡng — đồng thời đưa các điểm chạm di động cần thiết (thông báo duyệt, đề xuất dừng variant, theo dõi trạng thái) lên mobile nội bộ. Chiến lược campaign thiết kế theo mục tiêu khách đã chốt (conversion / traffic / awareness) chứ không theo cảm tính, và bài học thí nghiệm quay lại playbook dùng chung.

**Phạm vi:**
- Bao gồm: xem trên mobile trạng thái đăng ký thí nghiệm (duyệt/từ chối) và thí nghiệm đang chạy theo khách; nhận push khi đăng ký được duyệt và khi hệ thống đề xuất dừng variant do đạt ngưỡng; OPS_PLAN duyệt/từ chối đăng ký trên di động; xem tóm tắt kết quả theo variant (nhãn rõ nguồn GW realtime hoặc `manual` khi degraded); ghi learning log nhanh sau kết luận; nhắc lịch review quý.
- Không bao gồm: form đăng ký đầy đủ và dashboard phân tích chi tiết (WEB — nơi thiết kế chính); check overlap audience và tổng hợp KPI theo variant (CORE — chặn tầng API); kéo dữ liệu hiệu quả từ platform (GW); kết luận chính thức có evidence gắn change log (thao tác chính trên WEB, mobile chỉ đề xuất); cam kết KPI trong hợp đồng (SALES/FIN).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Nhận push ngay khi đăng ký thí nghiệm được duyệt hoặc bị từ chối kèm lý do | Triển khai đúng lúc, không chờ mò mẫm |
| 2 | OPS_ADS | Nhận đề xuất dừng variant khi variant đã đạt ngưỡng đủ tin cậy | Chốt sớm variant thắng, tiết kiệm ngân sách cho phần đã biết kết quả |
| 3 | OPS_ADS | Xem danh sách thí nghiệm đang chạy theo từng khách và trạng thái variant trên di động | Biết vùng đã có thí nghiệm active để tránh đăng ký chồng audience |
| 4 | OPS_PLAN | Duyệt/từ chối đăng ký thí nghiệm trên điện thoại với đủ tóm tắt: giả thuyết, KPI chính, variant, sample size dự kiến, ngân sách | Không chặn tiến độ đội chạy quảng cáo khi tôi vắng máy |
| 5 | OPS_PLAN | Nhắc lịch và xem tổng hợp learning log theo quý trên mobile | Đúng chu kỳ cập nhật playbook |
| 6 | OPS_AM | Xem tóm tắt kết quả theo variant (ngôn ngữ không kỹ thuật) | Cập nhật khách dựa trên số đo được, không hứa KPI ngoài hợp đồng |
| 7 | OPS_CONT, OPS_DES, OPS_EDIT | Nhận brief variant creative gắn thí nghiệm với nhãn variant rõ ràng | Sản xuất đúng khác biệt từng variant |
| 8 | OPS_ADS | Ghi learning log nhanh (win/lose/no signal + takeaway) ngay trên điện thoại sau khi thí nghiệm có kết luận | Ghi nhận bài học khi còn nóng, không đợi ngồi lại máy |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Mã BR-OPS-10.x là nguồn gốc tại `operations.md` B.10; số liệu theo resolution DI-005 (12/09/2026).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ABT-001 | Đăng ký thí nghiệm trước khi chạy: đăng ký gắn campaign, bắt buộc đủ — giả thuyết, metric chính duy nhất (primary KPI theo mục tiêu khách: conversion / traffic / awareness), variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến; thiếu trường → không lưu được đăng ký. OPS_PLAN duyệt trước khi triển khai (BR-OPS-10.1) | CORE chặn chi ngân sách cho campaign gắn thử nghiệm chưa đăng ký/chưa duyệt — mobile chỉ nhận push thông báo, không có cơ chế bỏ qua |
| BR-ABT-002 | Chống chồng chéo audience: trên cùng một audience/tenant khách, mỗi thời điểm chỉ 1 thí nghiệm active; đăng ký mới trùng segment với thí nghiệm đang chạy → chặn, bắt buộc chọn audience loại trừ (exclusion) hoặc chờ kết thúc. Exception: thí nghiệm trên platform khác nhau nhưng cùng tệp mục tiêu → OPS_PLAN đánh giá rủi ro giao thoa rồi mới duyệt, ghi lý do (BR-OPS-10.2) | Kiểm tra overlap do CORE thực hiện tầng API trước khi cho duyệt; mobile hiển thị bản đồ thí nghiệm đang chạy để người dùng tự tránh trước khi đăng ký |
| BR-ABT-003 | Ngưỡng kết luận chốt (DI-005): variant đủ tin cậy khi đạt tối thiểu 50 clicks/variant hoặc 10 conversions/variant, và chênh lệch hiệu suất giữa các variant ≥20% trên KPI chính; dừng variant/khai thắng chỉ khi đạt ngưỡng; kết thúc duration mà chưa đủ sample → kết luận "no signal" + quyết định gia hạn/dừng có lý do (BR-OPS-10.3) | Nút kết luận không cho phép ghi "win" khi chưa đạt ngưỡng — hệ thống đối chiếu số liệu trước khi nhận kết luận |
| BR-ABT-004 | Kết luận phải có evidence trên change log: kết luận (win/lose/no signal) bắt buộc tạo entry change log gắn evidence — số KPI theo variant, thời gian chạy, sample đạt; cảm tính/"có vẻ tốt" không là căn cứ khai thắng; mọi thay đổi ngân sách trong thử nghiệm đi qua campaign change log bất biến (BR-OPS-7.4 — BR-CAMP-005 của FEAT-MBI-CAMP-001) (BR-OPS-10.3) | Không có evidence → entry kết luận bị từ chối tầng API; mobile chỉ gửi đề xuất dừng, kết luận chính thức thực hiện trên WEB |
| BR-ABT-005 | Không cam kết KPI cứng cho khách ngoài hợp đồng — chỉ cam kết đầu vào (khớp `hop-dong-loi-nda-brand-safety.md` §2.5). Ngôn ngữ kết quả cho AM ở dạng "kết quả đo được", không phải "cam kết đạt" (BR-OPS-10.3) | Template kết quả chia sẻ khách không chứa trường cam kết KPI; cam kết riêng (nếu có) quản lý ở module hợp đồng |
| BR-ABT-006 | Học hỏi quay lại playbook: OPS_ADS ghi learning log theo khách/ngành ngay khi kết luận; mỗi quý OPS_PLAN rà learning log → cập nhật playbook/template chiến lược (content brief, cấu trúc campaign, audience playbook); cập nhật template là thay đổi chính sách nội bộ — có log + OPS_PLAN duyệt (BR-OPS-10.4) | Learning log thiếu gắn thí nghiệm/change log entry không tính vào báo cáo quý; sửa playbook không có log bị từ chối |
| BR-ABT-007 | Chiến lược campaign thiết kế theo mục tiêu khách đã chốt ở giai đoạn bán hàng: primary KPI của mọi thí nghiệm phải khớp mục tiêu dịch vụ của khách (conversion / traffic / awareness); đổi mục tiêu giữa chừng coi như thí nghiệm mới, đăng ký lại | Đăng ký có KPI không khớp mục tiêu khách bị OPS_PLAN từ chối với lý do ghi trên hệ thống |
| BR-ABT-008 | TikTok Shop tách bạch GMV: khi thí nghiệm liên quan TikTok Shop, GMV/settlement chỉ là chỉ số tham chiếu — không được chọn làm primary KPI doanh thu, không map vào sổ doanh thu (khớp REQ-OPS-011) | CORE chặn cấu hình KPI chính là GMV; dashboard mobile hiển thị GMV nhóm riêng kèm nhãn "tham chiếu" |
| BR-ABT-009 | Dữ liệu hiệu quả theo variant lấy từ GW; khi degraded mode dữ liệu mang nhãn `manual` — mọi bề mặt (WEB, mobile) phải hiển thị nhãn nguồn để người đọc biết độ tươi và độ tin cậy của số liệu (BR-OPS-10.1/10.3) | Số liệu nhãn `manual` dùng trong kết luận → evidence bắt buộc ghi rõ nguồn manual |
| BR-ABT-010 | Tenant isolation và phạm vi chia sẻ: khách không thấy chi tiết thí nghiệm mặc định; nếu khách yêu cầu hiển thị theo hợp đồng → cấu hình share riêng, chỉ phần tổng hợp được share, tách theo tenant; nhân sự trên mobile chỉ thấy thí nghiệm của tenant được gán | Request vượt tenant bị chặn tầng API; phần share chưa bật không xuất hiện trên PORTAL/M-PORTAL |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry (DI-006: không tồn tại vai OPS_CX/FIN_COMPL). Điểm chạm của mobile nội bộ: thông báo, duyệt nhanh, đề xuất dừng — các thao tác thiết kế chính nằm trên SYS-BCERP-WEB.*

| Hành động | OPS_ADS | OPS_PLAN (TL/Planner) | OPS_AM | OPS_CONT | OPS_DES / OPS_EDIT | CUSTOMER |
|-----------|---------|----------------------|--------|----------|--------------------|----------|
| Đăng ký thí nghiệm (form đầy đủ) | ✅ (trên WEB) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt/từ chối đăng ký thí nghiệm | ❌ (không tự duyệt đăng ký của mình — approver ≠ creator) | ✅ (cả trên mobile) | ❌ | ❌ | ❌ | ❌ |
| Xem danh sách/bản đồ thí nghiệm đang chạy | ✅ | ✅ | ✅ (khách mình) | ❌ | ❌ | ❌ |
| Xem kết quả chi tiết theo variant | ✅ | ✅ | ✅ (tóm tắt) | ❌ | ❌ | ❌ (chỉ phần tổng hợp nếu được share theo hợp đồng) |
| Đề xuất dừng variant khi đạt ngưỡng | ✅ (trên mobile) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo kết luận chính thức có evidence | ✅ (trên WEB) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ghi learning log | ✅ (cả trên mobile) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Review quý + cập nhật playbook | ❌ | ✅ (duyệt + soạn) | ❌ | ❌ | ❌ | ❌ |
| Nhận brief variant creative | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Xóa đăng ký đã duyệt / sửa kết luận đã ghi | ❌ | ❌ (bất biến — chỉ hủy có lý do tạo entry mới, mọi vai) | ❌ | ❌ | ❌ | ❌ |

**Ghi chú:** OPS_ADS đăng ký nhưng không tự duyệt đăng ký của mình (approver ≠ creator, khớp BR-OPS-7.3); OPS_AM chỉ đọc tóm tắt để cập nhật khách, không can thiệp cấu hình thí nghiệm.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Thí nghiệm chéo platform cùng tệp mục tiêu (VD Meta và TikTok cùng audience): không chặn cứng — OPS_PLAN đánh giá rủi ro giao thoa, duyệt kèm lý do ghi trên hệ thống (BR-ABT-002 exception).
- Variant hết ngân sách sớm trước khi đủ sample: thí nghiệm chuyển `CHỜ KẾT LUẬN` với trạng thái "ngân sách cạn"; nếu sample chưa đạt ngưỡng → kết luận mặc định "no signal", quyết định gia hạn/dừng ghi lý do.
- Platform outage / sự cố nền tảng giữa chừng: thí nghiệm pause, thời lượng được kéo dài tương ứng phần thời gian dừng, có log khoảng pause; dữ liệu thiếu giai đoạn được đánh dấu trên biểu đồ kết quả.
- Dữ liệu GW degraded (mất kết nối API platform): số liệu chuyển nhãn `manual` (nhập tay từ giao diện platform); kết luận dựa trên số manual phải ghi rõ nguồn manual trong evidence — không chặn kết luận nhưng bắt buộc minh bạch.
- Khách yêu cầu xem kết quả thí nghiệm: AM chỉ chia sẻ phần tổng hợp đã được cấu hình share theo hợp đồng; mặc định kết quả A/B không hiển thị cho khách (BR-ABT-010); yêu cầu share mới là cấu hình theo tenant, không phải thao tác ad-hoc.
- Đổi mục tiêu khách giữa vòng đời thí nghiệm: thí nghiệm đang chạy theo KPI cũ được cho chạy hết và kết luận trên KPI cũ; thí nghiệm mới theo mục tiêu mới phải đăng ký lại và qua duyệt (BR-ABT-007).
- Tự động hóa pull dữ liệu bằng AI Agent là phạm vi "tương lai" chờ xác nhận `[KXN-9]` — giai đoạn này dữ liệu variant chỉ qua GW theo chu kỳ cấu hình.
- Ma trận RACI chi tiết Luồng 3 chờ xác nhận chính thức `[KXN-19]` — phân quyền Phần 4 theo operations.md B.10 hiện hành, đối chiếu lại khi RACI được phê chuẩn.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Thí nghiệm A/B (`ab_experiment`).

**Sơ đồ trạng thái:**
```
[NHÁP] ──(gửi đăng ký đủ trường)──► [CHỜ DUYỆT] ──(OPS_PLAN duyệt)──► [ĐÃ DUYỆT]
                                        │                                  │
                                        │ (từ chối + lý do)                │ (bật chạy)
                                        ▼                                  ▼
                                   [BỊ TỪ CHỐI]                      [ĐANG CHẠY] ──(pause platform)──► [TẠM DỪNG]
                                                                          │    ▲                            │
                                                                          │    └──────────(resume)──────────┘
                                                                          │ (đạt ngưỡng / hết duration / dừng sớm có lý do)
                                                                          ▼
                                                                  [CHỜ KẾT LUẬN] ──(kết luận + evidence gắn change log)──► [ĐÃ KẾT LUẬN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NHÁP` | Gửi đăng ký | `CHỜ DUYỆT` | OPS_ADS | Đủ mọi trường bắt buộc (BR-ABT-001); qua check overlap audience (BR-ABT-002) |
| `CHỜ DUYỆT` | Duyệt | `ĐÃ DUYỆT` | OPS_PLAN (≠ người đăng ký) | Bản ghi thí nghiệm hoàn chỉnh; không trùng segment thí nghiệm active |
| `CHỜ DUYỆT` | Từ chối | `BỊ TỪ CHỐI` | OPS_PLAN | Lý do bắt buộc |
| `ĐÃ DUYỆT` | Bật chạy | `ĐANG CHẠY` | OPS_ADS | CORE mở khóa chi ngân sách cho campaign gắn thí nghiệm |
| `ĐANG CHẠY` | Pause (sự cố platform) | `TẠM DỪNG` | OPS_ADS/OPS_PLAN | Ghi log khoảng pause để kéo dài duration |
| `TẠM DỪNG` | Resume | `ĐANG CHẠY` | OPS_ADS | Platform đã phục hồi |
| `ĐANG CHẠY` | Dừng variant khi đạt ngưỡng / hết duration / dừng sớm | `CHỜ KẾT LUẬN` | OPS_ADS (đề xuất từ mobile) / OPS_PLAN | Dừng sớm phải có lý do; đề xuất dừng từ mobile chỉ khởi tạo, chờ xử lý |
| `CHỜ KẾT LUẬN` | Ghi kết luận | `ĐÃ KẾT LUẬN` | OPS_ADS/OPS_PLAN (trên WEB) | Result ∈ {win, lose, no signal}; evidence gắn entry change log bất biến (BR-ABT-004); thiếu sample → "no signal" bắt buộc |

**Quy tắc:**
- `BỊ TỪ CHỐI` và `ĐÃ KẾT LUẬN` là trạng thái kết thúc — muốn chạy lại tạo thí nghiệm mới, không sửa trạng thái cũ.
- Chi ngân sách chỉ hợp lệ trong khoảng `ĐANG CHẠY` (CORE khóa theo trạng thái); đổi ngân sách trong `ĐANG CHẠY` vẫn phải qua change log bất biến với reason.
- Kết luận "no signal" bắt buộc kèm quyết định gia hạn hoặc dừng có lý do, gắn learning log.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ab_experiment` | `id`, `campaign_id`, `hypothesis`, `primary_kpi` (conversion/traffic/awareness), `duration`, `budget`, `state` | FK → `campaign_project.id` | State machine Phần 6; khóa chi ngân sách theo trạng thái |
| `ab_variant` | `id`, `experiment_id`, `label` (A/B/...), `description`, `is_control` | FK → `ab_experiment.id` | Variant control đánh dấu để so sánh |
| `experiment_audience` | `id`, `experiment_id`, `definition`, `exclusions`, `platform` | FK → `ab_experiment.id` | Nguồn check overlap; audience size từ GW |
| `kpi_snapshot` | `id`, `variant_id`, `metric`, `value`, `captured_at`, `source` (gw_realtime/manual) | FK → `ab_variant.id` | Nhãn nguồn bắt buộc hiển thị mọi bề mặt |
| `experiment_conclusion` | `id`, `experiment_id`, `result` (win/lose/no_signal), `evidence_change_log_id`, `concluded_by`, `at` | FK → `ab_experiment.id`, `campaign_change_log.id` | Bất biến; không có evidence không tồn tại |
| `learning_log` | `id`, `experiment_id`, `client_id`, `industry`, `outcome`, `takeaway` | FK → `ab_experiment.id` | Tra cứu theo khách/ngành; nguồn báo cáo quý |
| `playbook_template` | `id`, `name`, `scope` (content brief/cấu trúc campaign/audience playbook), `version`, `approved_by` | — | Thay đổi = thay đổi chính sách nội bộ, có log + OPS_PLAN duyệt |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ Phase 2; chi tiết hoàn thiện ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chi ngân sách chặn khi chưa đăng ký | Campaign gắn thí nghiệm ở `NHÁP`/`CHỜ DUYỆT` | OPS_ADS bật chi ngân sách | CORE từ chối ở tầng API; mobile nhận push lý do chặn | [ ] |
| SC-002: Chồng audience bị chặn | Đã có thí nghiệm active trên segment X của khách | Đăng ký thí nghiệm mới trùng segment X | Đăng ký bị chặn; hệ thống đề xuất exclusion hoặc chờ; chỉ OPS_PLAN có thể duyệt exception có lý do | [ ] |
| SC-003: Kết luận thiếu evidence bị từ chối | Thí nghiệm ở `CHỜ KẾT LUẬN`, sample chưa đạt 50 clicks/10 conversions và chênh <20% | Người dùng ghi kết luận "win" | Hệ thống từ chối; chỉ chấp nhận "no signal" kèm quyết định gia hạn/dừng có lý do | [ ] |
| SC-004: Đề xuất dừng variant từ mobile | Variant đạt ngưỡng DI-005 trong lúc đang chạy | OPS_ADS nhận đề xuất dừng trên mobile và bấm đề xuất | Đề xuất ghi nhận vào hàng chờ; kết luận chính thức vẫn thực hiện trên WEB kèm evidence | [ ] |
| SC-005: GMV không làm KPI chính | Thí nghiệm liên quan TikTok Shop | Người dùng chọn GMV làm primary KPI | CORE chặn cấu hình; GMV chỉ hiển thị nhóm "tham chiếu" | [ ] |

> **Liên kết:** SC-001/SC-002 map REQ-OPS-012 (đăng ký trước khi chạy, chống giao thoa — Mục 2); SC-003/SC-004 map REQ-OPS-012 (kết luận có evidence, đề xuất dừng); SC-005 map quy tắc TikTok Shop tách bạch GMV (REQ-OPS-011 áp dụng khi liên quan).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (gồm mobile push, đề xuất dừng) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (GW dữ liệu variant, nhãn degraded `manual`) | `technical-specs/integration-map.md` |
| Màn hình UI mobile nội bộ | `phase4-ux/mobile-internal/campaign-deliverable/[screen-group].md` |
| Bản counterpart cùng REQ-OPS-012 | `phase2-features/core-backend/campaign-deliverable/`, `phase2-features/integration-gw/campaign-deliverable/`, `phase2-features/bcerp-web/campaign-deliverable/` |
| Tính năng liên quan cùng module | `phase2-features/mobile-internal/campaign-deliverable/campaign-va-deliverable-management.md` (FEAT-MBI-CAMP-001 — change log bất biến, duyệt creative) |
| Nguồn business rules gốc | `phase1-business/departments/operations/operations.md` B.10; `phase1-business/P1-02-business-workflow.md` §3.3 (B7) |
