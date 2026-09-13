# Tính Năng: Campaign & Deliverable Management

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Vận hành — OPS (SYS-MOBILE-INTERNAL — mobile nội bộ BCERP, React Native, offline-capable)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
>
> **Fan-out:** REQ-OPS-006 xuất hiện ở 6 systems — đây là bản riêng cho SYS-MOBILE-INTERNAL. Counterparts: SYS-CORE-BACKEND (BR enforce ở service layer), SYS-INTEGRATION-GW, SYS-BCERP-WEB (nơi thao tác chính), SYS-PORTAL-WEB, SYS-MOBILE-PORTAL (khách confirm nghiệm thu).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-006 (Campaign & Deliverable Management) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER (không dùng app nội bộ — confirm nghiệm thu trên PORTAL/M-PORTAL, xem Phần 4) |
| Độ ưu tiên | Cao (HIGH — Bắt buộc) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency trong lane; bản counterpart REQ-OPS-006 tại SYS-CORE-BACKEND là điều kiện chạy end-to-end |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa vận hành campaign/deliverable lên mobile nội bộ để nhân sự OPS không phải ngồi máy trạm: duyệt creative on-the-go, duyệt thay đổi ngân sách vượt hạn mức khi di chuyển, xem dashboard tiến độ WBS/editorial calendar và nhận push phản hồi nghiệm thu của khách realtime. Touchpoint này không thay thế SYS-BCERP-WEB — nơi soạn thảo chính (WBS, calendar, form thay đổi); mobile là bề mặt duyệt nhanh, xem và cảnh báo, hoạt động được offline.

**Phạm vi:**
- Bao gồm: xem dashboard tiến độ theo dự án được gán; duyệt nhanh creative đa vai (approve/request changes có comment); nhận push deadline và trượt mốc editorial calendar; gửi và duyệt thay đổi ngân sách/bid/target vượt hạn mức (kèm reason, giá trị cũ/mới); đề xuất nghiệm thu milestone và nhận push phản hồi của khách; hàng đợi hành động offline đồng bộ có kiểm soát.
- Không bao gồm: soạn WBS và editorial calendar (WEB); thực thi thay đổi xuống platform (GW); bề mặt khách confirm nghiệm thu (PORTAL/M-PORTAL — counterpart); ghi timesheet/capacity engine (REQ-OPS-007, module khác); lưu change log bất biến làm nguồn sự thật (CORE — mobile chỉ đọc).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN (TL) | Xem dashboard tiến độ campaign: % WBS node Approved, deliverable trễ, hàng chờ duyệt | Điều phối phòng ngay khi không ngồi máy |
| 2 | OPS_CONT | Nhận push bài đăng hôm nay và cảnh báo deadline trượt mốc | Xử lý đúng hạn, biết bài trễ để báo TL/AM |
| 3 | OPS_CONT, OPS_DES, OPS_EDIT | Duyệt nhanh bước creative được gán (approve/request changes kèm comment) trên điện thoại | Pipeline không kẹt khi tôi ngoài giờ hoặc đi công tác |
| 4 | OPS_AM | Nhận push khi khách confirm/từ chối nghiệm thu trên portal, kèm milestone liên quan | Phản hồi khách trong SLA |
| 5 | OPS_AM | Theo dõi bộ đếm "chờ khách confirm" (ngày 2 nhắc, ngày 4 escalate) | Không để nghiệm thu treo im lặng |
| 6 | OPS_ADS | Gửi yêu cầu tăng ngân sách vượt hạn mức kèm reason, nhận kết quả duyệt trên di động | Không bỏ lỡ cơ hội tối ưu campaign đang hiệu quả |
| 7 | OPS_PLAN (TL) | Duyệt vượt hạn mức trên di động với đủ ngữ cảnh: cũ/mới, người đề xuất, reason | Quyết định nhanh nhưng vẫn tuân thủ change log |
| 8 | OPS_PLAN (TL) | Nhận push escalate khi bước duyệt chậm quá SLA hoặc 2 bước liên tiếp trễ | Can thiệp trước khi pipeline đứt gãy |
| 9 | CUSTOMER | (Trên PORTAL/M-PORTAL — counterpart) Confirm nghiệm thu và xem tiến độ phần đã share | Minh bạch tiến độ không cần nhắn tin hỏi AM |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Mã BR-OPS-7.x là nguồn gốc tại `operations.md` B.7; số liệu theo resolution DI-005 (12/09/2026, `wf-analyze-requirements/deferred-issues.md`).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-CAMP-001 | Campaign & deliverable tổ chức theo WBS: mỗi deliverable map ≥1 WBS node; task mồ côi (không gắn WBS node) không được tính công. Mobile chỉ đọc cây WBS + trạng thái, không soạn WBS trên touchpoint này (BR-OPS-7.1) | Task mồ côi không hiển thị trong dashboard tiến độ; server từ chối hành động trên task không hợp lệ |
| BR-CAMP-002 | Editorial calendar có pipeline bắt buộc: Ý tưởng → Soạn → Duyệt nội dung → Sản xuất → Duyệt xuất bản → Đã xuất bản; deadline trượt → cảnh báo TL + AM (AM cập nhật khách). Mobile nhận push deadline hôm nay/trượt mốc (BR-OPS-7.2) | Hệ thống phải phát event trượt ngay khi vượt mốc — bài trễ không có cảnh báo là lỗi push |
| BR-CAMP-003 | Duyệt creative đa vai: OPS_CONT (nội dung) → OPS_DES/OPS_EDIT (sản xuất) → OPS_PLAN/OPS_AM (duyệt nghiệp vụ); ý kiến khách đi qua AM. Cấm tự duyệt task của mình (approver ≠ creator, chặn tầng API — áp cả khi sync từ mobile); reject bắt buộc comment; SLA duyệt theo loại deliverable (DI-005): chuẩn 2h LV, video 4h LV, creative bám trend 1h LV; quá SLA nhắc, chậm 2 bước liên tiếp escalate TL (BR-OPS-7.3) | Nút duyệt ẩn khi người duyệt trùng người tạo; approve không cần comment, reject thiếu comment bị từ chối tầng API |
| BR-CAMP-004 | Vòng sửa creative tối đa 3 vòng/deliverable (DI-005); quá 3 vòng → escalate TL chốt phạm vi bằng văn bản với khách (qua AM) (BR-OPS-7.3) | App chặn vòng sửa thứ 4; chỉ TL mở lại sau khi chốt phạm vi, có audit log |
| BR-CAMP-005 | Chiến lược campaign theo mục tiêu khách đã chốt (REQ-OPS-012): cấu trúc campaign và KPI vận hành bám mục tiêu khách (conversion/traffic/awareness); mobile hiển thị mục tiêu trên dashboard; thay đổi chiến lược lớn đi qua đăng ký thí nghiệm (FEAT-MBI-CAMP-002) | Dashboard không cấu hình được KPI ngoài bộ mục tiêu khách; đề xuất đổi chiến lược bị điều hướng sang luồng A/B testing |
| BR-CAMP-006 | Campaign change log bất biến: mọi thay đổi ngân sách/bid/target/audience/creative chính bắt buộc nhập reason; lưu giá trị cũ/mới, ai, khi nào — append-only (BR-OPS-7.4). Phân bậc duyệt: buyer tự quyết trong hạn mức ngày theo % ngân sách tháng campaign (DI-005: Junior 20% / Mid 50% / Senior 100%; mức VND tuyệt đối cấu hình theo profile campaign, FIN đối soát); vượt hạn mức ngày → TL (OPS_PLAN) duyệt; vượt hạn mức dự án → AM (OPS_AM) duyệt | CORE từ chối request thiếu reason ở tầng API — cả từ mobile; mobile chỉ là kênh duyệt, không sửa log |
| BR-CAMP-007 | Khẩn cấp dừng chiến dịch (die account, brand safety): pause trước, bổ sung reason vào change log trong 4h LV (BR-OPS-7.4). Mobile cho phép pause khẩn một chạm và nhắc bổ sung reason | Quá 4h LV chưa có reason → cảnh báo đỏ TL + push; ghi nhận vi phạm tuân thủ riêng |
| BR-CAMP-008 | Nghiệm thu theo milestone: milestone sẵn sàng khi 100% WBS node thuộc milestone ở Approved nội bộ; AM đề xuất → khách confirm trên PORTAL/M-PORTAL (tenant mình, realtime). Chờ confirm tối đa 3 ngày LV — hệ thống nhắc khách ngày 2, escalate AD (Account Director — đầu mối AM phụ trách khách, vai `OPS_AM` trong registry) ngày 4; KHÔNG áp "im lặng = đồng ý": milestone chỉ đóng khi khách confirm tường minh (DI-005, thay mốc 5 ngày LV cũ tại B.7.5). Milestone onboarding bắt buộc gắn Gate Day 14 (BR-OPS-7.5) | App không tự đóng milestone vì hết hạn chờ; quá hạn chỉ chuyển kênh escalate, trạng thái giữ nguyên |
| BR-CAMP-009 | Khách theo dõi tiến độ deliverable qua portal/mobile portal chỉ ở phần đã share; nhân sự trên mobile chỉ thấy tenant/dự án được gán; cache offline trên thiết bị chỉ chứa dữ liệu thuộc phạm vi được phép — tenant isolation | Request vượt phạm vi tenant bị chặn tầng API; phần chưa share không xuất hiện trên touchpoint khách nào |
| BR-CAMP-010 | TikTok Shop tách bạch GMV: khi campaign liên quan TikTok Shop, GMV/settlement chỉ là chỉ số tham chiếu — cấm map vào doanh thu, không cộng vào KPI nghiệm thu (khớp REQ-OPS-011) | GMV hiển thị nhóm riêng "tham chiếu"; server chặn mọi aggregate gộp GMV vào doanh thu |
| BR-CAMP-011 | Hai project type chạy cùng engine: Client Billable và Internal Non-billable — cùng WBS, calendar, duyệt creative, change log; khác người duyệt thay khách (nội bộ: TL/OPS_PLAN), nguồn ngân sách và tập nhãn timesheet hợp lệ (BR-OPS-7.6) | Ghi nhãn Client Billable vào dự án nội bộ (và ngược lại) bị chặn theo cặp project type × nhãn |
| BR-CAMP-012 | Campaign không gắn dự án tự pause trong 4h LV ("campaign không gắn dự án = không tồn tại" — REQ-OPS-001); mobile nhận push cảnh báo cho owner | Push gửi ngay khi phát hiện; quá 4h chưa xử lý → hệ thống pause + audit |
| BR-CAMP-013 | Offline queue: hành động duyệt/gửi reason khi mất mạng vào hàng đợi cục bộ; khi sync server kiểm version — bản stale bị từ chối, app bắt xem lại; SLA tính server-side theo timestamp event, không phụ thuộc thiết bị | Sync xung đột không ghi đè mù: hành động stale trả về kèm trạng thái mới; thời gian offline không giúp "vượt" SLA |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry (DI-006: không tồn tại OPS_CX/FIN_COMPL). CUSTOMER không truy cập mobile nội bộ — hành động của khách trên PORTAL/M-PORTAL (counterpart), kết quả phản xạ về app qua push.*

| Hành động | OPS_CONT | OPS_DES | OPS_EDIT | OPS_ADS | OPS_AM | OPS_PLAN (TL) | CUSTOMER |
|-----------|----------|---------|----------|---------|--------|---------------|----------|
| Xem dashboard campaign/dự án được gán | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (portal) |
| Xem toàn bộ dự án phòng OPS | ❌ | ❌ | ❌ | ❌ | ✅ (khách mình) | ✅ | ❌ |
| Duyệt bước creative theo pipeline được gán (approve/request changes có comment) | ✅ (bước nội dung) | ✅ (sản xuất) | ✅ (sản xuất) | ❌ | ✅ (nghiệp vụ) | ✅ (nghiệp vụ) | ❌ |
| Đề xuất nghiệm thu milestone | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Confirm nghiệm thu | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (chỉ PORTAL/M-PORTAL) |
| Gửi yêu cầu đổi ngân sách/bid/target (có reason) | ❌ | ❌ | ❌ | ✅ (trong hạn mức cấp buyer) | ✅ | ✅ | ❌ |
| Duyệt vượt hạn mức | ❌ | ❌ | ❌ | ❌ | ✅ (vượt hạn mức dự án) | ✅ (vượt hạn mức ngày) | ❌ |
| Pause khẩn cấp campaign | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Mở lại vòng sửa sau khi quá 3 vòng | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xem change log bất biến | ❌ | ❌ | ❌ | ✅ (campaign mình) | ✅ | ✅ | ❌ |
| Cấu hình hạn mức buyer / push theo vai | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (đề xuất) | ❌ |
| Xóa/sửa bản ghi change log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (append-only, mọi vai) | ❌ |

**Ghi chú:** hạn mức buyer gắn với người dùng OPS_ADS theo cấp (Junior/Mid/Senior), không gắn với thiết bị; SYS_ADMIN vận hành hạ tầng nhưng không có quyền nghiệp vụ duyệt creative/ngân sách.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Mất mạng khi đang duyệt: hành động vào offline queue với timestamp cục bộ; khi sync, nếu deliverable đã đổi trạng thái (ai đó duyệt trên WEB) → hành động bị trả về, app bắt xác nhận lại; SLA tính theo event hợp lệ đầu tiên trên server.
- Khách từ chối nghiệm thu: milestone quay lại chuỗi sản xuất, vòng sửa đếm tiếp vào quota 3 vòng; bộ đếm nhắc ngày 2/escalate ngày 4 vẫn chạy độc lập với việc từ chối.
- Người duyệt nghỉ ốm/đi phép: không có "duyệt hộ" ngầm — TL gán lại bước duyệt cho người khác trên WEB, mobile nhận push nhiệm vụ mới; reassignment ghi audit log.
- Mất/thay thiết bị: thu hồi phiên đăng nhập từ xa, cache offline mã hóa theo thiết bị; dữ liệu đã sync nằm trên server; hành động kẹt trong queue thiết bị cũ bị bỏ khi version không khớp.
- Die account ngoài giờ: OPS_ADS pause khẩn một chạm (BR-CAMP-007), app đếm ngược 4h LV và nhắc đến khi reason được bổ sung.
- Dự án nội bộ song song: cùng engine nhưng không có khách trong luồng nghiệm thu — người duyệt thay khách là TL/OPS_PLAN; exception một phần giờ chuyển Client Billable (case study có approval khách) do AM đề xuất, TL duyệt, có log.
- Khách chậm thanh toán ảnh hưởng campaign đang chạy: hướng PAUSE campaign sau 15 ngày non-payment là đề xuất chờ khách hàng xác nhận `[KXN-22]` — mobile chỉ hiển thị cảnh báo, chưa tự động pause theo mốc này.
- Ma trận RACI chi tiết Luồng 3 chờ xác nhận chính thức `[KXN-19]` — bảng phân quyền Phần 4 dựa trên operations.md hiện hành, đối chiếu lại khi RACI được phê chuẩn.
- Push quá tải đầu giờ: hệ thống gộp (digest) thông báo cùng loại theo vai; riêng escalate SLA, breach và phản hồi nghiệm thu của khách gửi tức thời, không gộp.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Deliverable (đơn vị sản phẩm gắn WBS node; milestone là tập hợp deliverable phục vụ nghiệm thu).

**Sơ đồ trạng thái:**
```
[Ý TƯỞNG] ──(bắt đầu soạn)──► [SOẠN] ──(gửi duyệt nội dung)──► [DUYỆT NỘI DUNG]
                                  ▲                                  │
                                  │ (request changes + comment)      │ (approved)
                                  └──────────────────────────────────┘
                                                                     ▼
                              [SẢN XUẤT] ◄──(request changes)── [DUYỆT NGHIỆP VỤ]
                                  │                                  │
                                  │ (approved)                       │ (approved)
                                  ▼                                  ▼
                              [SOẠN] ◄────────────────────  [APPROVED NỘI BỘ]
                                                                        │
                                                       (AM đề xuất, milestone 100% Approved)
                                                                        ▼
                                                 [CHỜ KHÁCH CONFIRM] ──(khách confirm)──► [ĐÃ NGHIỆM THU]
                                                                        │
                                                        (khách từ chối — vòng +1)
                                                                        ▼
                                                                  [SẢN XUẤT]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `SOẠN` | Gửi duyệt nội dung | `DUYỆT NỘI DUNG` | OPS_CONT | Đủ tài liệu theo checklist |
| `DUYỆT NỘI DUNG` | Approve | `SẢN XUẤT` | OPS_CONT (≠ creator) | Trong SLA 2h/4h/1h theo loại |
| `DUYỆT NỘI DUNG` | Request changes | `SOẠN` | OPS_CONT | Comment bắt buộc; vòng sửa +1 |
| `SẢN XUẤT` | Gửi duyệt nghiệp vụ | `DUYỆT NGHIỆP VỤ` | OPS_DES/OPS_EDIT | Bản production hoàn chỉnh |
| `DUYỆT NGHIỆP VỤ` | Approve | `APPROVED NỘI BỘ` | OPS_PLAN/OPS_AM (≠ creator) | Approve không cần comment |
| `DUYỆT NGHIỆP VỤ` | Request changes | `SẢN XUẤT` | OPS_PLAN/OPS_AM | Comment bắt buộc; vòng +1 |
| `APPROVED NỘI BỘ` | Đề xuất nghiệm thu | `CHỜ KHÁCH CONFIRM` | OPS_AM | 100% WBS node milestone Approved; onboarding gắn Gate Day 14 |
| `CHỜ KHÁCH CONFIRM` | Khách confirm | `ĐÃ NGHIỆM THU` | CUSTOMER (PORTAL/M-PORTAL) | Confirm tường minh — không tự động |
| `CHỜ KHÁCH CONFIRM` | Khách từ chối | `SẢN XUẤT` | CUSTOMER | Lý do trên portal; vòng +1; quá 3 vòng escalate TL |

**Quy tắc:**
- Không quay về trạng thái trước tùy ý — mọi chuyển ngược qua request changes có comment và tăng vòng sửa.
- `ĐÃ NGHIỆM THU` là trạng thái kết thúc; milestone hoàn thành khi toàn bộ deliverable thành viên đạt trạng thái này.
- Bộ đếm nhắc ngày 2/escalate ngày 4 và SLA từng bước chạy trên server (CORE) — app chỉ hiển thị; offline không dừng hay reset bộ đếm.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `campaign_project` | `id`, `name`, `project_type`, `client_id`, `status` | FK → `clients.id` | Tenant scope; gốc validation nhãn |
| `wbs_node` | `id`, `project_id`, `parent_id`, `done_criteria`, `status` | FK → `campaign_project.id` | Cây; mobile chỉ đọc |
| `deliverable` | `id`, `wbs_node_id`, `type` (content/visual/video/trend), `state`, `review_rounds`, `version` | FK → `wbs_node.id` | State machine Phần 6; `version` cho offline sync |
| `editorial_entry` | `id`, `deliverable_id`, `channel`, `publish_at`, `pipeline_state` | FK → `deliverable.id` | Nguồn push deadline/trượt mốc |
| `review_step` | `id`, `deliverable_id`, `stage`, `assignee_id`, `creator_id`, `decision`, `comment`, `sla_deadline` | FK → `deliverable.id` | Ràng buộc approver ≠ creator |
| `campaign_change_log` | `id`, `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `actor_id`, `at` | FK → `campaign_project.id` | Append-only; nguồn hiển thị cho mobile |
| `milestone_acceptance` | `id`, `milestone_id`, `proposed_by`, `client_confirm_at`, `deadline_3d`, `reminder_d2`, `escalate_d4` | FK → `campaign_project.id` | Không tự đóng; escalate AD ngày 4 |
| `offline_sync_queue` | `id`, `device_id`, `action`, `payload`, `local_ts`, `sync_state` | FK → `users.id` | Chỉ trên thiết bị; server thắng xung đột |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ Phase 2; chi tiết hoàn thiện ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Không tự duyệt | Deliverable ở `DUYỆT NỘI DUNG`, creator là OPS_CONT | OPS_CONT bấm Approve trên task mình tạo | Nút duyệt bị chặn/ẩn; tầng API cũng từ chối nếu gọi trực tiếp | [ ] |
| SC-002: Quá 3 vòng sửa | Deliverable đã qua 3 vòng request changes | Tạo vòng sửa thứ 4 | App chặn; chỉ OPS_PLAN mở lại sau khi chốt phạm vi, có audit log | [ ] |
| SC-003: Không "im lặng = đồng ý" | Milestone ở `CHỜ KHÁCH CONFIRM` quá 3 ngày LV | Hết hạn chờ, khách không phản hồi | Không tự chuyển `ĐÃ NGHIỆM THU`; ngày 2 đã nhắc, ngày 4 escalate AD | [ ] |
| SC-004: Duyệt vượt hạn mức trên mobile | OPS_ADS gửi yêu cầu tăng ngân sách vượt hạn mức, có reason | OPS_PLAN duyệt trên điện thoại | Yêu cầu vào change log bất biến cũ/mới; GW được kích hoạt đẩy xuống platform | [ ] |
| SC-005: Offline sync xung đột | App offline, deliverable bị duyệt trên WEB | App sync hành động duyệt cục bộ | Server từ chối do version stale; app hiển thị trạng thái mới, bắt xác nhận lại | [ ] |

> **Liên kết:** SC-001/002/004 map REQ-OPS-006 (duyệt creative đa vai, change log); SC-003 map nghiệm thu milestone; SC-005 map đặc thù touchpoint offline-capable.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (gồm offline sync contract) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (GW đẩy thay đổi, portal callback nghiệm thu) | `technical-specs/integration-map.md` |
| Màn hình UI mobile nội bộ | `phase4-ux/mobile-internal/campaign-deliverable/[screen-group].md` |
| Bản counterpart cùng REQ-OPS-006 | `phase2-features/{core-backend,integration-gw,bcerp-web,portal-web,mobile-portal}/campaign-deliverable/` |
| Tính năng liên quan cùng module | `phase2-features/mobile-internal/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` (FEAT-MBI-CAMP-002) |
| Nguồn business rules gốc | `phase1-business/departments/operations/operations.md` B.7; `phase1-business/P1-02-business-workflow.md` §3.3 |
