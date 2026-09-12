# Tính Năng: Campaign & Deliverable Management

> **Dựa trên:** REQ-OPS-006 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục A3/B.7)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (§3.3 — Luồng 3 Campaign Delivery), `phase0-brainstorm/policies/kiem-soat-vi-tkqc-giao-dich-tien.md` (§2.4 — hạn mức ngân sách theo bậc), `phase0-brainstorm/policies/sla-khach-hang.md` (§2.1 — ma trận tier × priority)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/campaign-deliverable/feat-erp-camp-001-impl.md`
>
> **Fan-out:** REQ-OPS-006 xuất hiện ở 6 systems (SYS-CORE-BACKEND, SYS-INTEGRATION-GW, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL, SYS-PORTAL-WEB, SYS-MOBILE-PORTAL) — đây là bản riêng cho SYS-BCERP-WEB (WEB nội bộ là touchpoint chính: lịch nội dung, pipeline duyệt creative, form change log, đề xuất nghiệm thu). Counterparts: SYS-CORE-BACKEND (workflow duyệt, change log bất biến, trạng thái nghiệm thu), SYS-INTEGRATION-GW (chi tiêu thực tế theo campaign để đối chiếu hiệu quả), SYS-MOBILE-INTERNAL (TL/AM duyệt creative và duyệt tăng ngân sách vượt hạn mức khi di động), SYS-PORTAL-WEB + SYS-MOBILE-PORTAL (khách xem tiến độ nghiệm thu theo milestone — realtime, chỉ tenant của mình). Business rule enforce ở tầng service layer của CORE; WEB render form/list/workflow UI và hiển thị đúng trạng thái machine-state.
>
> **Hướng dẫn ID:** FEAT-ERP-CAMP-001 là ID lane cấp cho REQ-OPS-006 trên module MOD-CAMPAIGN-DELIVERABLE (tra `req-registry.json` để xác nhận).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CAMP-001 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-006 — Campaign & Deliverable Management |
| Người dùng liên quan | OPS_PLAN (TL/Planner — soạn WBS, duyệt vượt hạn mức ngày), OPS_AM (duyệt nghiệp vụ, duyệt vượt hạn mức dự án, đề xuất nghiệm thu), OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (sản xuất — vận hành campaign); CUSTOMER (xem tiến độ + confirm nghiệm thu qua PORTAL/M-PORTAL — counterpart) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | REQ-OPS-005 (WBS sinh từ approved proposal đã qua gate EVALUATION/PROPOSAL); REQ-OPS-007 (capacity check bắt buộc trước gán task); REQ-OPS-001 (naming/UTM + campaign bắt buộc gắn dự án); REQ-OPS-010 (cấp tài khoản portal — điều kiện khách confirm nghiệm thu) |
| Ghi chú Expert (A7) | A7 của `operations.md` đang chờ Team Expert review; spec này giữ nguyên ranh giới liên REQ đã khai báo ở Phần B: engine duyệt/change log/nghiệm thu nằm ở CORE, GW kéo chi tiêu theo campaign, khách confirm trên PORTAL/M-PORTAL, WEB là workspace vận hành của nhân viên BC — không tự ý dời trách nhiệm giữa các system. |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là workspace vận hành chính trên BCERP Web nội bộ (Next.js, responsive) để phòng OPS **quản trị campaign và deliverable theo WBS**: soạn WBS và lịch nội dung từ approved proposal, chạy pipeline duyệt creative đa vai, thực hiện mọi thay đổi chiến dịch qua campaign change log bất biến, và điều phối nghiệm thu milestone với khách. Mọi trạng thái hiển thị trên WEB là machine-state do CORE validate — WEB không tự quyết trạng thái, chỉ khóa/mở thao tác theo kết quả tầng service.

**Phạm vi:**
- Bao gồm:
  - Soạn/chỉnh WBS gắn approved proposal: mỗi deliverable map ≥1 WBS node, dependency mặc định finish-to-start; form gán task hiển thị kết quả capacity check bắt buộc (engine ở CORE — REQ-OPS-007).
  - Editorial calendar (lịch nội dung tháng/quý) gắn WBS node + kênh phát hành (Meta/TikTok/Google/web...), pipeline trạng thái từ Ý tưởng đến Đã xuất bản, cảnh báo trượt deadline cho TL + AM.
  - Pipeline duyệt creative đa vai: OPS_CONT soạn → OPS_DES/OPS_EDIT sản xuất → OPS_AM/OPS_PLAN duyệt nghiệp vụ; vòng sửa, comment reject, SLA từng bước, đếm vòng — hiển thị đúng vòng còn lại và escalate.
  - Form thay đổi chiến dịch (ngân sách/bid/target/audience/creative chính) bắt buộc reason, ghi vào campaign change log bất biến; hiển thị luồng phân bậc duyệt theo hạn mức (buyer → TL → AM).
  - Đề xuất nghiệm thu milestone: điều kiện 100% WBS node Approved nội bộ; theo dõi vòng đời confirm của khách (3 ngày làm việc, nhắc ngày 2, escalate ngày 4 — không áp "im lặng = đồng ý").
  - Cấu hình phạm vi share portal: AM chọn deliverable/milestone chia cho khách; khách chỉ thấy phần đã share trong tenant của mình.
  - Liên kết TikTok Shop: khi campaign thuộc dịch vụ TikTok Shop, hiển thị GMV/settlement như chỉ số tham chiếu tách bạch khỏi doanh thu agency.
- Không bao gồm:
  - Workflow engine duyệt, change log engine, chặn tự duyệt, validation hạn mức — thực thi ở SYS-CORE-BACKEND; WEB chỉ phản ánh kết quả và trạng thái.
  - Đẩy thay đổi ngân sách xuống platform API và kéo chi tiêu thực tế theo campaign — thuộc SYS-INTEGRATION-GW (nhãn `manual` khi degraded — DI-007).
  - Duyệt creative/duyệt ngân sách trên di động, push deadline — thuộc SYS-MOBILE-INTERNAL (counterpart cùng REQ).
  - Bề mặt khách xem tiến độ + confirm nghiệm thu — thuộc SYS-PORTAL-WEB/SYS-MOBILE-PORTAL; spec này định nghĩa dữ liệu share và trạng thái mà portal consume.
  - Đăng ký thử nghiệm A/B và dashboard kết quả theo variant — thuộc FEAT-ERP-CAMP-002 (cùng module); thay đổi ngân sách phát sinh từ thử nghiệm vẫn đi qua change log của tính năng này.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN | Sinh khung WBS từ template theo loại dịch vụ rồi chỉnh trực tiếp trên WEB, map từng deliverable trong proposal vào WBS node | Không deliverable nào rơi ngoài phạm vi theo dõi và tính công |
| 2 | OPS_CONT | Lập lịch nội dung tháng/quý dạng board/calendar gắn WBS node và kênh phát hành | Nhóm thấy rõ bài nào đến hạn trên kênh nào, không trùng lịch |
| 3 | OPS_CONT | Nhận trạng thái pipeline từng ấn phẩm (Ý tưởng → Đã xuất bản) và cảnh báo trượt deadline | Chủ động xử lý trước khi AM phải báo khách tin xấu |
| 4 | OPS_DES / OPS_EDIT | Nhận task sản xuất visual/video từ task đã qua capacity check, nộp bảncreative kèm attachment | Việc gán đúng người còn capacity, nộp bài có dấu vết phiên bản |
| 5 | OPS_AM | Duyệt creative với đầy đủ ngữ cảnh (bản cũ/mới, comment các vòng trước, vòng sửa còn lại) và reject có comment bắt buộc | Vòng sửa có căn cứ, người làm biết chính xác phải sửa gì |
| 6 | OPS_ADS | Thay đổi ngân sách/bid/target qua form bắt buộc nhập lý do, thấy ngay ai duyệt tiếp | Mỗi thay đổi chiến dịch để lại dấu vết đối chiếu được với chi tiêu GW |
| 7 | OPS_PLAN (TL) | Có hàng đợi duyệt thay đổi vượt hạn mức ngày của buyer kèm giá trị cũ/mới | Chốt vượt hạn mức trong vài phút thay vì tra chuyện trò |
| 8 | OPS_AM | Đề xuất nghiệm thu milestone khi 100% WBS node đã Approved và theo dõi đồng hồ chờ confirm của khách | Biết chính xác ngày nào phải escalate thay vì chờ khách "lặng lẽ" |
| 9 | CUSTOMER | Xem tiến độ deliverable/milestone đã được chia và confirm nghiệm thu trên portal/mobile portal | Minh bạch tiến độ mà không cần hỏi AM qua chat |
| 10 | OPS_PLAN (TL) | Chạy dự án nội bộ của chính BC trên cùng engine (WBS, calendar, duyệt creative) với người duyệt thay khách | Dự án nội bộ và dự án khách nhất quán quy trình, số liệu không tráo nhãn |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (validation cứng ở tầng service CORE; WEB khóa thao tác theo kết quả). Nguồn: `operations.md` B.7; số liệu SLA/nghiệm thu đã chốt theo DI-005 (12/09/2026) — ưu tiên hơn mốc `[CẦN CHỐT SỐ]` cũ trong B.7.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Campaign & deliverable theo WBS:** WBS sinh từ approved proposal (đã qua gate EVALUATION/PROPOSAL); task/deliverable bắt buộc gắn WBS node — task mồ côi không được tính công (khớp "không gắn project = không tồn tại" của REQ-OPS-001); dependency mặc định finish-to-start, task không start khi predecessor chưa done trừ khi TL duyệt overlap có lý do (log); project type (Client Billable / Internal Non-billable) bắt buộc lúc tạo dự án. | Không tạo được task thiếu WBS node; API từ chối payload thiếu `wbs_node_id`; overlap không duyệt bị chặn tầng API |
| BR-002 | **Capacity check bắt buộc trước mọi gán task:** kết quả do CORE capacity engine trả về (vàng >90% phải TL duyệt, đỏ ≥100% chặn cứng — chi tiết FEAT-ERP-CAPTS-002). | WEB vô hiệu nút gán khi chưa có kết quả check; gán vùng đỏ bị từ chối với mã lỗi băng màu |
| BR-003 | **Editorial calendar pipeline:** mỗi bài/ấn phẩm có trạng thái pipeline Ý tưởng → Soạn → Duyệt nội dung → Sản xuất → Duyệt xuất bản → Đã xuất bản; deadline trượt → cảnh báo TL + AM (AM chủ động cập nhật khách). | Không cho phép nhảy cóc trạng thái; cảnh báo trượt tự sinh job, hiển thị badge trên calendar |
| BR-004 | **Duyệt creative đa vai + cấm tự duyệt:** pipeline bắt buộc OPS_CONT → OPS_DES/OPS_EDIT → OPS_AM/OPS_PLAN; approver ≠ creator (chặn tầng API); Request changes bắt buộc comment; ý kiến khách đi qua AM, khách không can thiệp task nội bộ. | Nút duyệt ẩn với chính người tạo; API duyệt chính mình trả 403 + audit log; reject thiếu comment không lưu được |
| BR-005 | **Creative SLA theo tier:** SLA duyệt creative đã chốt (DI-005): duyệt nghiệp vụ AM 2h (video dài 4h, trend gấp 1h); content self-QC + Lead review 4h; áp trong khung giờ làm việc theo ma trận tier × priority của khách (`sla-khach-hang.md` §2.1) — hợp đồng cam kết cao hơn ma trận thì ghi đè theo profile khách; quá SLA nhắc, chậm 2 bước liên tiếp escalate TL. | Đếm ngược SLA hiển thị trên từng bước; quá nhắc và escalate tự sinh, không phụ thuộc thao tác tay |
| BR-006 | **Vòng sửa creative:** tối đa 3 vòng nội bộ trên 1 deliverable; vòng thứ 4 escalate AM chốt phạm vi sửa bằng văn bản với khách (qua AM) — chốt DI-005, tránh sửa vô tận. | Form nộp vòng 4 bị chặn nếu chưa có escalation record; đếm vòng hiển thị "còn X vòng" trên deliverable |
| BR-007 | **Campaign change log bất biến:** mọi thay đổi ngân sách/bid/target/audience/creative chính (kể cả trong A/B test — FEAT-ERP-CAMP-002) bắt buộc nhập reason; hệ thống lưu giá trị cũ/mới, ai, khi nào — append-only, cấm sửa/xóa. | CORE change log engine từ chối request thiếu reason ở tầng API; UI không có đường sửa/xóa entry |
| BR-008 | **Phân bậc duyệt thay đổi theo hạn mức:** buyer (OPS_ADS) tự quyết trong hạn mức ngày do TL cấu hình — khung đề xuất theo % ngân sách tháng: 20% (Junior) / 50% (Senior) / 100% (Lead), số cụ thể FIN chốt khi cấu hình `[CẦN CHỐT SỐ — FIN]`; vượt hạn mức ngày → TL duyệt; vượt hạn mức dự án → AM duyệt. Exception khẩn cấp (die account, sự cố brand safety): pause trước, bổ sung reason vào change log trong 4h làm việc. | Thay đổi vượt hạn mức tự route sang hàng đợi đúng bậc; chưa duyệt không đẩy xuống platform qua GW |
| BR-009 | **Nghiệm thu theo milestone:** milestone sẵn sàng nghiệm thu khi 100% WBS node thuộc milestone ở trạng thái Approved nội bộ; AM đề xuất → khách confirm trên PORTAL/M-PORTAL (tenant của mình, realtime). Chờ confirm tối đa **3 ngày làm việc**; **nhắc khách ngày 2**; **ngày 4 escalate AD** (Account Director — ngoài 18 vai registry, hệ thống route quản lý tuyến OPS_PLAN theo ma trận RACI `[KXN-19]`); **KHÔNG áp "im lặng = đồng ý"** — quá hạn không confirm là trạng thái ESCALATED, không tự chuyển ACCEPTED. | Nút đề xuất nghiệm thu vô hiệu khi chưa đủ 100% Approved; hết 3 ngày LV không tự nghiệm thu — milestone đứng ở ESCALATED chờ con người quyết |
| BR-010 | **Share portal có phạm vi:** khách chỉ thấy deliverable/milestone đã được AM bật share, trong tenant của mình (tenant isolation tuyệt đối); không thấy giá vốn, chiết khấu, P&L, ghi chú nội bộ; download có watermark (khớp REQ-OPS-010). | Truy vấn portal lọc bắt buộc theo `tenant_id` + `share_scope`; lỗi isolation là lỗi nghiêm trọng P0 |
| BR-011 | **TikTok Shop tách bạch GMV:** khi campaign liên quan TikTok Shop, GMV/settlement chỉ hiển thị như chỉ số tham chiếu thuộc về khách — chặn mọi mapping vào doanh thu agency; doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ. | Không có đường nhập GMV vào trường doanh thu; báo cáo tách bạch hai nhóm chỉ số |
| BR-012 | **Dự án nội bộ chạy cùng engine:** WBS, calendar, duyệt creative, change log như dự án khách; khác ở người duyệt thay khách (TL/OPS_PLAN) và nguồn ngân sách; cấm tráo nhãn timesheet theo cặp project type × nhãn (REQ-OPS-007); exception dự án nội bộ phục vụ trực tiếp 1 khách — AM đề xuất, TL duyệt, có log. | Validation cặp project type × nhãn chặn ở CORE; exception không log không được chấp nhận |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry + CUSTOMER (portal/mobile-portal counterpart). AD (Account Director) không có trong registry — bậc escalate nghiệm thu ngày 4 hiển thị cho quản lý tuyến OPS_PLAN `[KXN-19]` (ma trận RACI chưa được xác nhận chính thức — không tự quyết tổ chức).

| Hành động | OPS_CONT/DES/EDIT | OPS_ADS | OPS_AM | OPS_PLAN (TL) | CUSTOMER (portal) | SYS_ADMIN |
|-----------|-------------------|---------|--------|---------------|-------------------|-----------|
| Soạn/chỉnh WBS dự án phụ trách | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Lập/chỉnh editorial calendar | ✅ | ❌ | ✅ (xem + chỉnh hạn mức khách) | ✅ | ❌ | ❌ |
| Soạn nội dung / nộp creative | ✅ (theo task được gán) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt creative (bước nghiệp vụ) | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Tự duyệt task của mình | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thay đổi ngân sách/bid/target trong hạn mức | ❌ | ✅ (có reason) | ❌ | ❌ | ❌ | ❌ |
| Duyệt thay đổi vượt hạn mức ngày | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt thay đổi vượt hạn mức dự án | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Đề xuất nghiệm thu milestone | ❌ | ❌ | ✅ | ✅ (dự án nội bộ) | ❌ | ❌ |
| Confirm nghiệm thu (phần đã share) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Cấu hình phạm vi share portal | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Xem tiến độ deliverable đã share | ✅ (dự án mình) | ✅ (dự án mình) | ✅ (khách mình) | ✅ (toàn nhóm) | ✅ (chỉ phần share, tenant mình) | ❌ |
| Sửa/xóa entry change log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ truy cập kỹ thuật có audit) |
| Xóa deliverable đã có hoạt động | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ghi chú:** SYS_ADMIN không có quyền nghiệp vụ trên dữ liệu campaign/deliverable — chỉ truy cập kỹ thuật, mọi thao tác ghi audit log. Quyền "dự án mình" là row-level scoping theo membership do CORE enforce. CUSTOMER thao tác trên PORTAL/M-PORTAL (counterpart); ma trận này ghi nhận phạm vi dữ liệu mà WEB cho phép share sang portal.

---

## 5. Trường Hợp Đặc Biệt

- **Khẩn cấp dừng chiến dịch (die account, sự cố brand safety):** OPS_ADS pause ngay qua WEB mà không kịp nhập reason — hệ thống cho phép pause trước, mở yêu cầu bổ sung reason trong 4h làm việc; quá hạn change log tự tạo entry "thiếu reason" gắn cảnh báo TL.
- **Customer không phản hồi nghiệm thu:** hết 3 ngày làm việc hệ thống không tự nghiệm thu (không "im lặng = đồng ý") — milestone chuyển ESCALATED, AM chịu trách nhiệm liên hệ kênh khác; kết quả cuối cùng (ACCEPTED / REWORK) do con người nhập, kèm bằng chứng trao đổi.
- **Khách yêu cầu thay đổi sau khi creative đã Approved:** yêu cầu đi qua AM, tách thành vòng sửa mới (đếm lại theo vòng sửa của deliverable); nếu vượt 3 vòng nội bộ → escalate AM chốt phạm vi bằng văn bản trước khi sản xuất tiếp.
- **Dự án nội bộ phục vụ trực tiếp một khách (case study có approval khách):** AM đề xuất, TL duyệt chuyển một phần giờ sang Client Billable, có log — không phải tách dự án mới.
- **GW degraded (chưa có quyền API platform):** thay đổi ngân sách vẫn ghi change log đầy đủ ở CORE, nhưng mục "đã đẩy xuống platform" hiển thị `manual` — OPS_ADS cập nhật tay trên platform và đính evidence; trạng thái phân biệt rõ trên WEB (DI-007).
- **Milestone gắn onboarding:** milestone onboarding bắt buộc gắn Gate Day 14 (BR-OPS-3.2/5.1) — điều kiện nghiệm thu giai đoạn onboarding; trượt Gate 14 escalate CS TL trong 24h theo REQ-OPS-010.
- **Campaign chưa gắn dự án phát hiện bởi job quét:** WEB hiển thị cảnh báo "campaign không gắn dự án — tự pause trong 4h LV" và form gắn nhanh; trong thời gian chưa gắn, chi tiêu không được report/hạch toán về khách.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Deliverable (creative/ấn phẩm trong WBS) và Milestone (nghiệm thu) — trạng thái lưu/validate ở CORE; WEB hiển thị machine-state và khóa thao tác theo trạng thái.

**Sơ đồ trạng thái (Deliverable):**
```
[IDEA] ──(lên lịch)──► [WRITING] ──(nộp)──► [CONTENT_REVIEW] ──(approved)──► [PRODUCING]
                            ▲                      │ (request changes — comment)        │ (nộp bản)
                            └──────────────────────┘                                     ▼
                                                                                  [BUSINESS_REVIEW] ──(approved)──► [PUBLISHED]
                                                                                          │ (request changes)
                                                                                          ▼
                                                                                  [PRODUCING] (vòng +1; vòng >3 → ESCALATED_AM)
```

**Sơ đồ trạng thái (Milestone — nghiệm thu):**
```
[IN_PROGRESS] ──(100% WBS node Approved)──► [READY_FOR_ACCEPTANCE] ──(AM đề xuất)──► [PENDING_CUSTOMER_CONFIRM]
                                                 │                                        │           │
                                                 │ (thiếu node — quay lại)               │ ngày 2     │ ngày 4
                                                 ▼                                        ▼           ▼
                                           [IN_PROGRESS]                            [REMINDED]   [ESCALATED]
                                                                                          │           │
                                                                                          │ confirm   │ confirm sau escalate
                                                                                          ▼           ▼
                                                                                     [ACCEPTED]   [ACCEPTED] / [REWORK]
```

**Bảng chuyển đổi (Milestone):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `IN_PROGRESS` | Đề xuất nghiệm thu | `READY_FOR_ACCEPTANCE` → `PENDING_CUSTOMER_CONFIRM` | OPS_AM | 100% WBS node thuộc milestone ở `APPROVED` nội bộ |
| `PENDING_CUSTOMER_CONFIRM` | Nhắc khách (tự động) | `REMINDED` | Hệ thống | Đến ngày làm việc thứ 2 kể từ khi đề xuất |
| `PENDING_CUSTOMER_CONFIRM` / `REMINDED` | Escalate (tự động) | `ESCALATED` | Hệ thống | Hết 3 ngày làm việc không confirm — escalate AD (route OPS_PLAN) |
| `PENDING_CUSTOMER_CONFIRM` / `REMINDED` / `ESCALATED` | Khách confirm | `ACCEPTED` | CUSTOMER (portal, tenant mình) | Xác nhận trên PORTAL/M-PORTAL; có timestamp + audit |
| `ESCALATED` | Khách yêu cầu sửa | `REWORK` | OPS_AM (nhập kết quả liên hệ) | Bằng chứng trao đổi đính kèm; tạo vòng sửa mới cho deliverable liên quan |

**Quy tắc:**
- Không có chuyển tiếp tự động nào dẫn tới `ACCEPTED` — chỉ có hai nguồn: confirm của khách trên portal hoặc quyết định có bằng chứng của OPS_AM sau escalate.
- `ACCEPTED` là trạng thái kết thúc của milestone; `REWORK` mở vòng sửa mới nhưng lịch sử các vòng giữ nguyên (append-only).
- Deliverable không nhảy cóc bước: bỏ qua bước duyệt nào là lỗi — CORE từ chối chuyển trạng thái không đúng thứ tự pipeline.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `wbs_node` | `id`, `project_id`, `parent_id`, `deliverable_ref`, `dependency_type`, `status` | FK → `projects.id` | Sinh từ template theo loại dịch vụ; project type khóa nhãn timesheet |
| `deliverable` | `id`, `wbs_node_id`, `name`, `channel`, `round_count`, `status`, `assignee_id` | FK → `wbs_node.id`, `users.id` | Pipeline 6 trạng thái; đếm vòng sửa tối đa 3 |
| `creative_review` | `id`, `deliverable_id`, `step`, `reviewer_id`, `decision`, `comment`, `sla_due_at`, `decided_at` | FK → `deliverable.id`, `users.id` | approver ≠ creator; comment bắt buộc khi reject |
| `editorial_entry` | `id`, `deliverable_id`, `channel`, `publish_at`, `pipeline_status` | FK → `deliverable.id` | Deadline trượt sinh cảnh báo TL + AM |
| `campaign_change_log` | `id`, `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `changed_by`, `changed_at`, `approval_level` | FK → `campaigns.id`, `users.id` | Append-only; phân bậc buyer → TL → AM |
| `milestone` | `id`, `project_id`, `name`, `status`, `proposed_at`, `reminder_at`, `escalated_at` | FK → `projects.id` | Điều kiện 100% Approved; 3 ngày LV / nhắc ngày 2 / escalate ngày 4 |
| `portal_share_scope` | `id`, `project_id`, `milestone_id`, `deliverable_id`, `shared_by`, `shared_at` | FK → `projects.id`, `milestone.id` | Khách chỉ thấy bản ghi có trong scope; tenant isolation |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn task mồ côi | Form tạo task mở | Người dùng lưu task không gắn WBS node | API từ chối; hiển thị bắt buộc chọn WBS node | [ ] |
| SC-002: Cấm tự duyệt | OPS_CONT vừa nộp creative | Chính người đó bấm duyệt bước của mình | Nút ẩn trên UI; API trả 403 + audit log | [ ] |
| SC-003: Change log thiếu reason | Form thay đổi ngân sách mở | OPS_ADS lưu mà không nhập lý do | Không lưu được; CORE từ chối request thiếu `reason` | [ ] |
| SC-004: Phân bậc hạn mức | Thay đổi vượt hạn mức ngày của buyer | Hệ thống xử lý yêu cầu | Yêu cầu vào hàng đợi TL; vượt hạn mức dự án → hàng đợi AM; chưa duyệt không đẩy platform | [ ] |
| SC-005: Nghiệm thu không im lặng = đồng ý | Milestone đã đề xuất, khách không phản hồi | Hết 3 ngày làm việc | Nhắc ngày 2, ngày 4 chuyển ESCALATED; không tự chuyển ACCEPTED | [ ] |
| SC-006: Tenant isolation portal | Khách A đăng nhập portal | Khách A truy vấn danh sách deliverable | Chỉ thấy phần đã share của tenant A; không thấy ghi chú nội bộ/giá vốn | [ ] |
| SC-007: Vòng sửa chặn vòng 4 | Deliverable đã qua 3 vòng sửa | Người làm nộp vòng 4 chưa có escalation | Bị chặn; escalate AM sinh yêu cầu chốt phạm vi bằng văn bản | [ ] |

> **Liên kết:** SC-001/002/007 map REQ-OPS-006 (B.7 — BR-OPS-7.1/7.3); SC-003/004 map BR-OPS-7.4 + policy `kiem-soat-vi-tkqc-giao-dich-tien.md` §2.4; SC-005/006 map BR-OPS-7.5 + REQ-OPS-010 (portal minh bạch, tenant isolation).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (workflow CORE, chi tiêu campaign từ GW, share portal, counterpart M-INT) |
| Màn hình UI | `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md` |
| Policy nguồn | `phase0-brainstorm/policies/kiem-soat-vi-tkqc-giao-dich-tien.md` §2.4, `phase0-brainstorm/policies/sla-khach-hang.md` §2.1 |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` §3.3 (Luồng 3 Campaign Delivery) |
| Feature cùng module | `phase2-features/bcerp-web/campaign-deliverable/a-b-testing-va-chien-luoc-campaign-theo-muc-tieu-khach.md` |
