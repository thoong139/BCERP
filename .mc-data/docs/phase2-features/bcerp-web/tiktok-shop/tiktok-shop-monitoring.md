# Tính Năng: TikTok Shop Monitoring

> **Dựa trên:** REQ-OPS-011 trong `phase1-business/departments/operations/operations.md` (A3, B.4 — BR-OPS-4.1→4.6); policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5; `P1-02-business-workflow.md` luồng 3 — B7
> **Phân hệ:** Vận hành & Marketing nội bộ — TikTok Shop Monitoring (SYS-BCERP-WEB)
> **Module:** TikTok Shop (MOD-TIKTOK-SHOP)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase0-brainstorm/policies/tiktok-shop-du-lieu-gmv-tham-dinh.md`, `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/tiktok-shop/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/tiktok-shop/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp — bản này dùng **FEAT-ERP-TIKTOK-001** theo cấp phát của lane. REQ-OPS-011 fan-out ra 4 systems — đây là bản riêng cho **SYS-BCERP-WEB** (web nội bộ responsive Next.js); counterparts: SYS-CORE-BACKEND (domain service), SYS-INTEGRATION-GW (OAuth, phiên PII TTL), SYS-MOBILE-INTERNAL (cảnh báo push).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-ERP-TIKTOK-001 |
| Module | MOD-TIKTOK-SHOP (SYS-BCERP-WEB — web nội bộ responsive, Next.js) |
| Yêu cầu nghiệp vụ | REQ-OPS-011 (TikTok Shop Monitoring) |
| Người dùng liên quan | OPS_AM, OPS_ADS, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT; FIN_L1 (đối soát Gate 1/3); SALES_L4 (TPKD/SM — ký Gate 2 — KXN-14); SYS_ADMIN (degraded/connector) |
| Độ ưu tiên | Trung bình (MEDIUM · GĐ3) |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | FEAT-CORE-TIKTOK-001 (counterpart SYS-CORE-BACKEND — API lifecycle 3 Gate + tổng hợp GMV/settlement/shop health) phải sẵn sàng trước khi mở màn hình; connector OAuth per-client tại SYS-INTEGRATION-GW; cảnh báo push dùng chung REQ-OPS-008 (SLA ticket tier×priority) |
| Ghi chú Expert (A7) | Chưa có điều chỉnh — Mục A7 `operations.md` đang "chờ review" (bảng còn trống, không có điều chỉnh riêng cho REQ-OPS-011); đối chiếu chéo REQ-OPS-002/003/007/004 được A7 flag nhưng không thuộc phạm vi feature này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
WEB nội bộ là bề mặt làm việc chính của nhân viên BC cho TikTok Shop Monitoring: dashboard GMV/đơn/settlement/shop health theo khách, workflow UI vòng đời 3 Gate (Verification → Go-live → Đối soát), theo dõi ủy quyền OAuth và vận hành degraded "manual" khi mất API. WEB gọi API core (FEAT-CORE-TIKTOK-001) và **hiển thị đúng trạng thái machine-state** do backend trả về; tách bạch GMV shop vs chi tiêu NSQC ads, mask PII và tenant isolation được enforce ở service layer — UI không tự kiểm soát nghiệp vụ hay ghi đè trạng thái.

**Phạm vi:**
- Bao gồm: dashboard nội bộ GMV/đơn/settlement/shop health theo khách kèm nhãn nguồn (`api`/`manual`), timestamp, độ trễ; workflow UI 3 Gate (checklist Gate 1, ký Gate 2 cho SM, bảng đối soát Gate 3 cho FIN_L1); form nhập tay degraded đúng schema + banner trạng thái sync; màn hình ủy quyền OAuth (scope, hạn, trạng thái) + task thu hồi 24h; cấu hình phạm vi chỉ số GMV chia sẻ khách qua Portal (phần tenant, khi HĐ quy định) kèm preview; màn hình cảnh báo SLA shop + escalate; export có kiểm soát theo tenant, mask PII, tách nhóm GMV vs NSQC.
- Không bao gồm: thực thi business rule (chặn mapping GMV vào doanh thu — SYS-CORE-BACKEND); OAuth token, phiên PII TTL, pull dữ liệu (SYS-INTEGRATION-GW); push mobile (SYS-MOBILE-INTERNAL); bề mặt Portal khách đọc báo cáo (SYS-PORTAL-WEB — WEB chỉ cấu hình và preview); quản lý đơn/fulfillment/kho — **KHÔNG làm OMS/WMS**; quản trị chiến dịch TikTok Ads thường (MOD-ADACCOUNT-CC).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản này là web nội bộ responsive (Next.js): nhân viên BC thao tác qua trình duyệt — form/list/workflow UI gọi API core; mọi điều kiện duyệt, chặn và tách bạch được xác thực lại ở service layer nên UI chỉ hiển thị kết quả trạng thái hợp lệ.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Đăng ký shop mới vào monitoring, điền checklist Gate 1 trên form có validate, và thấy rõ shop nào đang treo ở gate nào | Thẩm định chủ shop + giấy phép ngành hàng không bỏ sót bước nào |
| 2 | OPS_AM | Theo dõi trạng thái từng ủy quyền OAuth (scope, ngày hết hạn, `ACTIVE/EXPIRING/EXPIRED/REVOKED`) và nhận task "xác nhận thu hồi" khi hết HĐ | Đảm bảo revoke trong 24h và báo khách bằng văn bản đúng quy trình |
| 3 | OPS_ADS | Xem dashboard GMV/đơn/settlement/shop health của khách phụ trách, tách rõ nhóm chỉ số shop và nhóm chi tiêu NSQC, kèm nhãn nguồn + timestamp | Tối ưu campaign dựa trên số tin cậy, không nhầm GMV với chi tiêu ads |
| 4 | OPS_PLAN | Xem dashboard tổng quan trạng thái 3 Gate của toàn bộ shop (lọc theo trạng thái, SLA trượt bao lâu, ai đang giữ việc) | Điều phối nguồn lực và escalate đúng SLA 8h LV |
| 5 | OPS_CONT / OPS_DES / OPS_EDIT | Xem shop health + GMV theo ngành hàng của khách ở chế độ view-only | Soạn content/creative bám đúng tình trạng shop hiện tại |
| 6 | FIN_L1 | Chạy và theo dõi bảng đối soát Gate 3 (settlement vs đơn vs ads) theo kỳ HĐ, thấy flag chênh lệch vượt ngưỡng ngay trên màn hình | Điều tra ≤3 ngày LV với bằng chứng đối chiếu tập trung |
| 7 | SALES_L4 (TPKD/SM — KXN-14) | Ký duyệt Go-live Gate 2 trên UI — nút chỉ bật khi Gate 1 `VERIFIED` và baseline KPI đã được snapshot | Go-live có chữ ký chịu trách nhiệm và mốc baseline bất biến |
| 8 | SYS_ADMIN | Bật degraded "manual" khi mất API, mở form import/nhập tay đúng schema, và thấy đối chiếu backfill khi có lại API | Nghiệp vụ không tắc khi chưa có quyền API (DI-007) |
| 9 | OPS_AM | Cấu hình phạm vi chỉ số GMV chia sẻ cho khách qua Portal (khi HĐ quy định) và xem trước bản báo cáo khách sẽ thấy | Báo cáo cho khách qua Portal đúng phần tenant, không lộ dữ liệu nội bộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. WEB là touchpoint hiển thị/thao tác: mọi chặn cứng (tách bạch, phân quyền, tenant isolation, mapping doanh thu) do service layer của SYS-CORE-BACKEND enforce; WEB bắt buộc render đúng machine-state từ API và không cài đặt logic nghiệp vụ song song ở client.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **WEB hiển thị đúng machine-state:** mọi màn hình lifecycle/gate/ủy quyền đọc trạng thái trực tiếp từ API core (`lifecycle_state`, `oauth_status`, trạng thái đối soát) — cấm hard-code trạng thái, cấm cho phép sửa trạng thái trực tiếp trên UI; nút hành động chỉ enable khi trạng thái hiện tại hợp lệ theo machine-state. Nguồn: Notes lane (touchpoint SYS-BCERP-WEB). | API lỗi/không trả state → màn hình hiển thị "không xác định" + nút hành động khóa, không đoán trạng thái |
| BR-002 | **Tách bạch GMV shop vs NSQC ads trên bề mặt UI:** dashboard/báo cáo/export luôn hiển thị GMV, đơn, settlement (kết quả shop) ở nhóm riêng và chi tiêu NSQC (input ads) ở nhóm riêng — không có widget, cột tổng, hay biểu đồ cộng trộn hai nhóm; không có chế độ "quy đổi GMV thành chi tiêu". Nguồn: lane rule; policy §2.2; BR-OPS-4.4. | Thiết kế UI trộn nhóm → không được duyệt; số tổng trộn phát sinh → chặn ở tầng tổng hợp API, UI không render |
| BR-003 | **Sync qua GW, degraded "manual" khi mất API:** UI hiển thị nhãn nguồn (`api`/`manual`) + timestamp + độ trễ cạnh mọi con số; mất API → banner degraded bật trên dashboard, form nhập tay bắt buộc đúng schema và tự gắn nhãn `manual`; có lại API → màn hình đối chiếu backfill (`manual` vs `api`) trước khi chuyển nguồn. Nguồn: lane rule; DI-007. | Số thiếu nhãn nguồn/timestamp → UI không render (backend không trả); nhập tay sai schema → form từ chối submit |
| BR-004 | **Workflow 3 Gate trên UI:** Gate 1 — form checklist chủ shop (giấy ĐKKD/hộ kinh doanh, người đại diện pháp luật, chứng từ sở hữu shop, khớp người ký HĐ với chủ shop) + giấy phép ngành hàng với ngày hết hạn, cảnh báo trước hạn; hoàn tất cần OPS_AM + FIN_L1. Gate 2 — nút ký chỉ enable khi Gate 1 `VERIFIED` và baseline đã snapshot. Gate 3 — bảng đối soát theo tần suất HĐ (mặc định hàng tháng), flag chênh lệch kèm hạn điều tra ≤3 ngày LV. Nguồn: BR-OPS-4.5; policy §2.3–2.4. | Trạng thái chưa đủ mà nút enable (lỗi render) → click bị API từ chối + log; checklist thiếu item → không submit được Gate 1 |
| BR-005 | **Mask PII mặc định trên mọi màn hình và export:** SĐT dạng `090****123`, địa chỉ chỉ còn tỉnh/huyện, tên người mua cuối được mask; UI không có nút "xem đầy đủ" tự do — mở dữ liệu đầy đủ chỉ qua luồng phiên TTL có purpose (đối soát giao hàng/settlement) do GW cấp, có ghi nhận access log; export luôn bản mask. Nguồn: BR-OPS-4.2; policy §2.1. | Xuất hiện PII thô ngoài phiên TTL → lỗi bảo mật P0; phiên hết TTL → màn hình chi tiết tự khóa giữa phiên |
| BR-006 | **Tenant isolation trên UI:** user chỉ thấy shop/chỉ số theo tenant + client code được gán (lọc do API áp Row-Level Security; UI không gửi tham số tenant tay); đường link/deep-link sang shop khác tenant bị từ chối và ghi log; test truy cập chéo hàng quý bao gồm cả UI. Nguồn: BR-OPS-4.2; policy §2.1. | Truy vấn vượt tenant → API từ chối + audit log bảo mật; UI không được che lỗi bằng dữ liệu mặc định |
| BR-007 | **Theo dõi ủy quyền + thu hồi 24h:** màn hình ủy quyền hiển thị scope, ngày cấp, ngày hết hạn, trạng thái; OAuth sắp hết hạn → cảnh báo trước hạn; hết HĐ/khách yêu cầu → hệ thống sinh task thu hồi 24h cho OPS_AM (xác nhận văn bản cho khách) + SYS_ADMIN (thực thi kỹ thuật); UI dừng hiển thị dữ liệu mới ngay khi trạng thái chuyển `EXPIRED/REVOKED`. Nguồn: BR-OPS-4.1; policy §2.1, §4. | Task thu hồi quá 24h → escalate trên dashboard; thao tác kéo dữ liệu sau revoke → API chặn cứng |
| BR-008 | **Cảnh báo SLA shop:** cảnh báo shop bị hạn chế/khóa, GMV/settlement lệch bất thường, giấy phép & OAuth sắp hết hạn, baseline lệch hiển thị trên dashboard kèm owner + hạn xử lý theo SLA ticket khách (tier×priority — REQ-OPS-008); quá hạn → escalate hiển thị lên OPS_PLAN; tắt cảnh báo trên UI bắt buộc nhập reason và ghi audit log. Nguồn: BR-OPS-4.6. | Cảnh báo không owner/SLA → escalate; tắt tay không reason → form từ chối |
| BR-009 | **KHÔNG làm OMS/WMS trên UI:** không có màn hình quản lý đơn, fulfillment, tồn kho, in vận đơn; UI chỉ đọc hiển thị đơn ở mức monitoring (số lượng, giá trị, trạng thái do API trả); nhận thêm logistics chỉ khi HĐ quy định và có SLA riêng — khi đó mở scope UI theo change request, không tự thêm nút. Nguồn: BR-OPS-4.3; policy §2.5; P1-02 B7. | Yêu cầu thao tác đơn/fulfillment → API từ chối mã "ngoài phạm vi monitoring"; UI hiển thị thông báo ranh giới |
| BR-010 | **Báo cáo cho khách qua Portal (phần tenant) + dashboard nội bộ:** dashboard nội bộ phục vụ mọi vai OPS trên WEB; riêng báo cáo GMV/shop health cho khách qua Portal — WEB cung cấp màn hình bật/tắt theo HĐ, whitelist chỉ số trong phạm vi tenant của khách, và preview đúng những gì khách thấy (mask PII, kèm nguồn + timestamp + độ trễ); mặc định GMV không bật cho khách. Phạm vi chỉ số GMV hiển thị cho khách `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]` — ghi nhận làm assumption, KHÔNG tự quyết. Nguồn: lane rule; REQ-OPS-011. | Bật chia sẻ ngoài HĐ → API từ chối; preview lệch bản Portal → chặn phát hành |
| BR-011 | **Không ghi đè dữ liệu tài chính tham chiếu:** UI không cung cấp hành động sửa GMV/đơn/settlement/baseline/access log — các entity này read-only (append-only phía core); phát hiện số sai → luồng "báo cáo chênh lệch" tạo record điều tra, không sửa tại chỗ; baseline chỉ tồn tại từ snapshot Gate 2. Nguồn: BR-OPS-4.4/4.5; policy §2.2, §5. | Yêu cầu sửa trực tiếp → API từ chối; UI phải điều hướng về luồng điều tra thay vì form sửa |
| BR-012 | **Audit mọi thao tác UI:** đăng ký shop, submit checklist, ký Gate 2, chạy đối soát, nhập tay degraded, bật/tắt chia sẻ Portal, tắt cảnh báo, mở phiên PII TTL — tất cả ghi audit log bất biến qua API (ai, khi nào, hành động, đối tượng); UI hiển thị lịch sử thay đổi cạnh bản ghi để nhân viên đối chiếu. Nguồn: policy §5; Notes lane. | Thiếu audit → action không hoàn tất; lịch sử hiển thị lệch với log → bug độ tin cậy, chặn release |

---

## 4. Phân Quyền

> *Phân quyền thực thi ở tầng API core backend theo 18 vai registry; bảng dưới mô tả hành động trên UI web nội bộ tương ứng. SM = SALES_L4 TPKD (KXN-14 — đồng bộ stakeholder review 12/09; nhãn cũ `sales.md` ghi TNKD/SM ở SALES_L3). Không dùng OPS_CX/FIN_COMPL (DI-006 — vai bị từ chối, đã gỡ khỏi registry).*

| Hành động (trên WEB) | OPS_AM | OPS_ADS | OPS_PLAN | OPS_CONT/DES/EDIT | FIN_L1 | SALES_L4 (SM) | SYS_ADMIN |
|----------------------|--------|---------|----------|-------------------|--------|---------------|-----------|
| Xem dashboard GMV/shop health (khách phụ trách) | ✅ | ✅ | ✅ (toàn bộ shop) | ✅ (view-only) | ✅ | ✅ | ✅ |
| Đăng ký shop mới + khởi tạo checklist Gate 1 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Hoàn tất checklist Gate 1 (đối chiếu pháp lý) | ✅ | ❌ | ❌ | ❌ | ✅ (bắt buộc đồng hành) | ❌ | ❌ |
| Ký duyệt Go-live Gate 2 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (duy nhất) | ❌ |
| Chạy/xử lý đối soát Gate 3 | ✅ (phối hợp) | ❌ | ❌ | ❌ | ✅ (chủ trì) | ❌ | ❌ |
| Nhập tay degraded "manual" + import dữ liệu | ❌ | ✅ (nhập số liệu) | ❌ | ❌ | ❌ | ❌ | ✅ (bật chế độ, cấu hình connector) |
| Xác nhận thu hồi ủy quyền (task 24h) | ✅ (văn bản cho khách) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi kỹ thuật) |
| Cấu hình chia sẻ GMV cho khách qua Portal + preview | ✅ (theo HĐ khách phụ trách) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Định cấu hình ngưỡng cảnh báo/tần suất đối soát (màn hình settings) | ❌ | ❌ | ✅ (vận hành) | ❌ | ✅ (ngưỡng tài chính) | ❌ | ✅ |
| Mở phiên xem PII đầy đủ (phiên TTL, có purpose) | ❌ | ✅ (đối soát giao hàng) | ❌ | ❌ | ✅ (đối soát settlement) | ❌ | ❌ |
| Xem access log / lịch sử audit của shop | ✅ (shop phụ trách) | ✅ (shop phụ trách) | ✅ (toàn bộ) | ❌ | ✅ | ✅ | ✅ |
| Sửa/xóa chỉ số, baseline, access log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (**không vai nào — read-only, append-only**) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách tự vận hành shop, BC chỉ chạy ads:** UI chạy đường Gate 1 rút gọn (chỉ ownership + scope đọc), ẩn Gate 2 full; dashboard vẫn tách nhóm GMV vs NSQC, baseline chỉ ghi phần liên quan ads.
- **Khách từ chối cấp OAuth:** shop hiển thị "không kết nối — theo số liệu khách cung cấp"; form nhập tay degraded vẫn dùng được, báo cáo gắn nhãn nguồn tương ứng kèm chú thích "không chịu trách nhiệm đối soát".
- **OAuth hết hạn giữa chừng khi AM đang xem dashboard:** banner mất kết nối, dừng hiển thị dữ liệu mới từ thời điểm `EXPIRED`; không tự xin mở rộng scope — UI chỉ tạo task xin ủy quyền mới để AM làm với khách.
- **Chênh lệch đối soát vượt ngưỡng:** bảng Gate 3 flag dòng chênh lệch, hiển thị "Đang đối soát" + hạn điều tra ≤3 ngày LV (FIN_L1 + OPS_AM); trong thời gian điều tra UI không trình bày số này như số chính thức.
- **Mất API kéo dài (DI-007):** degraded "manual" là trạng thái vận hành chính thức — banner tồn tại lâu, dashboard đọc được số nhập tay kèm nhãn; khi có lại API, màn hình đối chiếu backfill hiển thị sai số, vượt dung sai giữ trạng thái tranh chấp chờ FIN_L1.
- **Giấy phép ngành hàng sắp/cạn hạn:** cảnh báo trước hạn theo ngày hết hạn trong checklist Gate 1; cạn hạn chưa gia hạn → shop rời nhóm "đủ điều kiện vận hành", khóa luồng go-live.
- **Test truy cập chéo hàng quý phát hiện rò rỉ qua UI:** ghi incident bảo mật theo quy trình chung, không vá im lặng; khi điều tra, màn hình liên quan hiển thị trạng thái giới hạn chức năng thay vì tắt âm thầm.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ TikTok Shop (`TikTokShop`) — WEB không sở hữu state machine, chỉ **hiển thị đúng** trạng thái do core quản lý và enable/disable nút hành động theo bảng dưới. Trạng thái OAuth (`ACTIVE/EXPIRING/EXPIRED/REVOKED`) là thuộc tính do GW cập nhật.

**Sơ đồ trạng thái (do SYS-CORE-BACKEND quản lý — WEB hiển thị):**
```
[REGISTERED] ──(Gate 1: checklist pass, AM + FIN_L1)──► [VERIFIED]
     │                  │                                     │
     │ (thẩm định fail/  │ (khách tự vận hành — rút gọn)       │ (SM ký + baseline snapshot)
     ▼  khách từ chối)   ▼                                     ▼
[SUSPENDED]        [MONITOR_ONLY] ─────────────────────► [GO_LIVE]
                                                              │     ▲
                                                              ▼     │ (khắc phục xong)
                                                          [BLOCKED]─┘
                                                              │ (hết HĐ — thu hồi 24h)
                                                              ▼
[REVOKED] ◄────────── (từ mọi trạng thái vận hành khi hết HĐ) ──┘
```

**Bảng hành động UI theo trạng thái (WEB render):**

| Trạng thái hiện tại | UI hiển thị | Nút/hành động khả dụng | Ai thấy được thao tác |
|---------------------|-------------|------------------------|----------------------|
| `REGISTERED` | "Chờ thẩm định — Gate 1" | Điền/submit checklist Gate 1; hủy hồ sơ (có lý do) | OPS_AM (submit), FIN_L1 (đối chiếu pháp lý) |
| `VERIFIED` | "Đã thẩm định — chờ go-live" | Snapshot baseline + ký Gate 2 (nút enable khi baseline có); chuyển Monitor-only | SALES_L4 (ký), OPS_AM |
| `GO_LIVE` | "Đang vận hành — Gate 3 định kỳ" | Chạy kỳ đối soát; xem baseline (read-only); tắt/bật cảnh báo (có reason) | FIN_L1 (đối soát), OPS_AM/OPS_ADS, OPS_PLAN (settings) |
| `MONITOR_ONLY` | "Giám sát rút gọn (khách tự vận hành)" | Xem dashboard; nhập tay degraded; không có Gate 2 full | OPS_AM, OPS_ADS |
| `BLOCKED` | "Bị chặn — OAuth/giấy phép/shop" | Xem nguyên nhân; task khắc phục; đánh dấu đã xử lý để quay lại trạng thái trước | SYS_ADMIN + OPS_AM |
| `SUSPENDED` | "Thẩm định fail / từ chối OAuth" | Cập nhật hồ sơ, đề xuất thẩm định lại | OPS_AM |
| `REVOKED` | "Đã thu hồi — lịch sử read-only" | Chỉ xem lịch sử; mở lại = tạo hồ sơ mới (đi lại Gate 1) | Toàn bộ vai có quyền xem |

**Quy tắc hiển thị:**
- WEB không cho nhảy cóc gate trên UI: nút ký Gate 2 chỉ enable ở `VERIFIED` có baseline — nếu lỗi render cho enable sai, API vẫn từ chối và ghi log (BR-001).
- `REVOKED` là trạng thái kết thúc: UI chỉ còn chế độ read-only; mọi số đã kéo trước đó hiển thị kèm mốc thời điểm thu hồi.
- Mọi chuyển trạng thái UI phản ánh trong ≤1 chu kỳ làm mới (realtime/poll theo chuẩn chung của web nội bộ); hiển thị sai trạng thái là bug P1.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *WEB không sở hữu DDL — entity do SYS-CORE-BACKEND quản lý (chi tiết tại `phase2-features/core-backend/tiktok-shop/tiktok-shop-monitoring.md` Mục 7 và `technical-specs/database-design.md`). Bảng dưới tóm tắt dữ liệu UI đọc/ghi để thiết kế màn hình.*

| Entity | UI đọc/ghi chính | Màn hình liên quan | Ghi chú |
|--------|------------------|--------------------|---------|
| `TikTokShop` | `lifecycle_state`, `oauth_status`, `shop_name`, `client_id` | Dashboard, danh sách shop, chi tiết shop | Hiển thị machine-state; không sửa trực tiếp |
| `TikTokShopOAuthGrant` | `scope`, `expires_at`, `status`, `revoke_reason` | Màn hình ủy quyền + task thu hồi 24h | Token không bao giờ hiển thị trên UI |
| `TikTokShopVerificationChecklist` | `item`, `doc_ref`, `status`, `expires_at` | Form Gate 1 + cảnh báo trước hạn | Submit cần AM + FIN_L1 |
| `TikTokShopBaselineKpi` | `gmv_baseline`, `ads_baseline`, `conversion_rate`, `signed_by` | Màn hình ký Gate 2 + so sánh hiệu quả | Read-only, snapshot bất biến |
| `TikTokShopDailyMetric` | `gmv`, `orders`, `settlement`, `ad_spend`, `health_score`, `data_source`, `fetched_at` | Dashboard GMV/shop health | Nhóm GMV/settlement tách riêng `ad_spend` (BR-002); nhãn nguồn + timestamp bắt buộc hiển thị |
| `TikTokShopReconciliation` | `period`, `diff_amount`, `status`, `investigated_by` | Bảng đối soát Gate 3 | Flag chênh lệch + hạn điều tra hiển thị cạnh dòng |
| `TikTokShopAccessLog` | `actor_id`, `action`, `data_object`, `timestamp` | Lịch sử audit trong chi tiết shop | Read-only, append-only |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-011 và policy `tiktok-shop-du-lieu-gmv-tham-dinh.md`.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: UI tách nhóm GMV vs NSQC (BR-002) | Shop đang `GO_LIVE` có dữ liệu GMV + ad spend | Mở dashboard và export báo cáo | GMV/đơn/settlement và chi tiêu NSQC hiển thị ở hai nhóm riêng, không có cột/widget cộng trộn ở mọi breakpoint | [ ] |
| SC-002: Nhãn nguồn + timestamp khi degraded (BR-003 — DI-007) | Mất kết nối API, OPS_ADS nhập số tay | Nhập số đúng schema, rồi có lại API và backfill | Số tay hiển thị nhãn `manual` + timestamp; backfill hiển thị đối chiếu `manual` vs `api` trước khi chuyển nguồn | [ ] |
| SC-003: Nút Gate 2 theo machine-state (BR-001/004) | Shop ở `REGISTERED` chưa qua Gate 1 | SALES_L4 mở màn hình go-live | Nút ký Gate 2 disable; ép gọi API (qua devtools) → API từ chối + audit log; sau khi `VERIFIED` + baseline, nút tự enable | [ ] |
| SC-004: Mask PII trên màn hình và export (BR-005) | Dữ liệu đơn chứa PII người mua cuối | Xem dashboard, export Excel, và mở phiên TTL đối soát | Mọi bề mặt thường chỉ thấy bản mask; export mask; phiên TTL đủ dữ liệu và tự khóa hết hạn, access log ghi đủ | [ ] |
| SC-005: Task thu hồi 24h (BR-007) | Hợp đồng khách hết hạn | Sự kiện HĐ fire và AM mở màn hình ủy quyền | Trạng thái ủy quyền `REVOKED`, dữ liệu mới dừng hiển thị, task xác nhận văn bản hiển thị cho OPS_AM; quá 24h dashboard escalate | [ ] |
| SC-006: Tenant isolation trên UI (BR-006) | User chỉ được gán tenant A | Truy cập deep-link shop khách B | API từ chối, UI hiển thị thông báo từ chối (không dữ liệu mặc định), audit log bảo mật ghi nhận | [ ] |
| SC-007: Cấu hình + preview báo cáo Portal (BR-010) | HĐ khách A quy định chia sẻ GMV qua Portal | OPS_AM bật chia sẻ trong whitelist tenant A và mở preview | Preview đúng những gì Portal hiển thị (mask PII, nguồn + timestamp + độ trễ); khách không có cấu hình không thấy mục GMV; phạm vi hiển thị chờ `[CẦN CHỐT SỐ]` — cấu hình theo whitelist, không mặc định | [ ] |
| SC-008: Chênh lệch đối soát hiển thị đúng (BR-004/011) | Kỳ đối soát có chênh lệch vượt ngưỡng | FIN_L1 mở bảng Gate 3 | Dòng chênh lệch được flag kèm hạn điều tra ≤3 ngày LV; không có hành động sửa số trực tiếp, chỉ luồng điều tra | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (entity do core sở hữu — WEB chỉ tiêu thụ qua API) |
| API Endpoints | `technical-specs/api-contract.md` (machine-state, nhãn nguồn, quyền per-action) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW pull OAuth per-client + phiên PII TTL; chặn mapping GMV vào sổ — connector kế toán vendor-agnostic tại MOD-SETTINGS-GW theo DI-004; M-INT push cảnh báo) |
| Màn hình UI (dashboard, checklist Gate, ủy quyền, đối soát) | `phase4-ux/bcerp-web/tiktok-shop/[screen-group].md` |
| Policy nghiệp vụ | `phase0-brainstorm/policies/tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5, §4–5 |
| REQ nguồn & business rules | `phase1-business/departments/operations/operations.md` (A3 REQ-OPS-011, B.4 BR-OPS-4.1→4.6), `phase1-business/P1-02-business-workflow.md` (luồng 3 — B7) |
| Feature liên quan | Counterparts cùng REQ: FEAT-CORE-TIKTOK-001 (SYS-CORE-BACKEND — enforce service layer), connector OAuth (SYS-INTEGRATION-GW), cảnh báo mobile (SYS-MOBILE-INTERNAL); bản WEB này là FEAT-ERP-TIKTOK-001; phối hợp REQ-FIN-004, REQ-OPS-008, REQ-OPS-004 |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
