# Tính Năng: Quotation & Deal Desk — Định Mức, Chiết Khấu Phân Cấp, Duyệt GM (Mobile Nội Bộ)

> **Dựa trên:** REQ-SALES-006 trong `phase1-business/departments/sales/sales.md` (Phần A §REQ-SALES-006, Phần B §B.6)
> **Phân hệ:** Hệ Mobile Nội Bộ (SYS-MOBILE-INTERNAL)
> **Module:** Quotation & Deal Desk (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/quotation-dealdesk/*.md`, `phase5-implementation/tasks/mobile-internal/quotation-dealdesk/feat-mbi-qdd-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID sinh từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-SALES-006 fan-out trên 3 hệ thống; bản spec này là slice riêng cho SYS-MOBILE-INTERNAL (counterparts: SYS-CORE-BACKEND — engine GM/SLA clock/audit WORM, SYS-BCERP-WEB — soạn quotation).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-QDD-001 |
| Module | MOD-QUOTATION-DEALDESK |
| Yêu cầu nghiệp vụ | REQ-SALES-006 |
| Người dùng liên quan | SALES_L2 (NVKD), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — KXN-14), SALES_L5 (GDKD), BOD_CEO/BOD_CFO_CTO (duyệt >20%); FIN_L1/L2 phối hợp định mức nhưng không lập quotation trên mobile |

> **Chú thích phân biệt (P4 — KXN-14):** `SALES_L3` là vai TNKD (trưởng nhóm kinh doanh) theo `sales.md`; chức danh **SM** ánh xạ **SALES_L4 (TPKD)** — người ký/duyệt các mốc gate theo KXN-14, không còn gắn với SALES_L3.
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase 2 — kênh mobile duyệt chiết khấu/GM/exception; engine tính giá và định mức version nằm ở SYS-CORE-BACKEND từ MVP) |
| Phụ thuộc | Engine Quotation & Deal Desk của REQ-SALES-006 tại SYS-CORE-BACKEND (API duyệt, ma trận chiết khấu, SLA clock, audit log WORM); không có cross-dependency FEAT ngoài lane |
| Ghi chú Expert (A7) | `sales.md` có mục A7 nhưng chưa ghi điều chỉnh cụ thể cho REQ-SALES-006; chuyên môn đã phản ánh tại Phần B (BR-SALES-601–604) và được đưa vào spec này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép cấp duyệt kinh doanh (TPKD, GDKD, BOD) xử lý yêu cầu chiết khấu, duyệt GM và duyệt exception ngay trên điện thoại qua push kèm MFA step-up. Tính năng giúp SLA duyệt (8 giờ làm việc với TPKD, 1 ngày với GDKD, 2 ngày với BOD) không bị trễ vì người duyệt vắng văn phòng, đồng thời giữ nguyên mọi ràng buộc ma trận phân cấp và audit trail từ engine tại SYS-CORE-BACKEND.

**Phạm vi:**
- Bao gồm: nhận push yêu cầu duyệt theo ma trận; xem tóm tắt quotation (giá bán, chiết khấu đề xuất, GM so ngưỡng nhóm dịch vụ — theo đúng mức dữ liệu Mật được phép); duyệt/từ chối kèm lý do và nhận định chiến lược với MFA step-up (TOTP gắn device theo P0-02 §2.4); offline-capable (đọc hồ sơ offline, hành động duyệt xếp hàng đồng bộ một lần ghi nhận); cảnh báo quá SLA duyệt và quá 2 ngày làm việc chưa gửi khách; dashboard SLA duyệt theo cấp; audit log mọi hành động từ mobile.
- Không bao gồm: soạn quotation và tính giá từ định mức (WEB soạn, trace version định mức hiệu lực); engine GM, version control bản gửi khách, khóa read-only, đồng hồ hiệu lực (CORE enforce); gửi quotation cho khách; nhập liệu hàng loạt trên mobile (sales.md B.0: MOBILE là kênh ký duyệt và cảnh báo, không phải mặt làm việc); chuyển tier khách và các luồng pipeline khác.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L4 (TPKD) | Nhận push chiết khấu 5–15% chờ duyệt, xem GM so ngưỡng và duyệt/từ chối kèm lý do với MFA step-up | Không để deal trễ SLA 8 giờ làm việc khi tôi đi công tác |
| 2 | SALES_L5 (GDKD) | Duyệt GM, chiết khấu 15–20% và exception trên di động, nhập nhận định chiến lược bắt buộc | Tuân thủ SLA 1 ngày, quyết định có căn cứ ngay khi xem số |
| 3 | BOD_CEO / BOD_CFO_CTO | Nhận push quotation chiết khấu >20%, xem hồ sơ và ghi quyết (kèm văn bản sau) trong SLA 2 ngày | Quyết bằng văn bản đúng quy định nhưng không trễ vì chờ lịch gặp |
| 4 | SALES_L3 (TNKD) | Xem dashboard hàng đợi duyệt nhóm: mục sắp/quá SLA, mục đã duyệt GM quá 2 ngày chưa gửi khách | Chủ động đôn đốc và escalate trước khi deal chết trong queue |
| 5 | SALES_L2 (NVKD) | Nhận push kết quả duyệt (kèm lý do cấp trên) và xem trạng thái từng version quotation của mình | Nắm tiến độ deal ngay, không hỏi lại qua chat; không thấy GM/giá vốn (dữ liệu Mật) |
| 6 | SALES_L4 (TPKD) | Xem báo cáo GM phòng và cảnh báo version điều chỉnh do tỷ giá/phí nền tảng >5% | Kiểm soát chất lượng deal phòng theo chính sách định mức hiện hành |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Engine enforce ở service layer của SYS-CORE-BACKEND; mobile là kênh tác động, không tự quyết.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MBI-QDD-101 | Chiết khấu phân cấp: SALES_L2 tự duyệt ≤5% (GM đạt ngưỡng, tức thời); >5–15% SALES_L4 duyệt (SLA 8 giờ LV); >15–20% SALES_L5 (SLA 1 ngày, kèm nhận định chiến lược); >20% BOD (SLA 2 ngày, quyết bằng văn bản) | API từ chối duyệt ngoài thẩm quyền; UI ẩn nút; quá SLA → escalate push cấp trên + cảnh báo SM/GDKD |
| BR-MBI-QDD-102 | GM engine theo nhóm dịch vụ, ngưỡng cảnh báo đỏ: agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%; media pass-through giá vốn 0 GM nhưng tính đủ phí dịch vụ; GM dưới ngưỡng chỉ SALES_L5 (đến 20%) hoặc BOD duyệt | Quotation GM dưới ngưỡng bị chặn gửi khách; mobile hiển thị cảnh báo đỏ; nút duyệt chỉ bật cho cấp đủ thẩm quyền ngoại lệ |
| BR-MBI-QDD-103 | Mọi duyệt/từ chối giá trị cao trên mobile bắt buộc MFA step-up (TOTP gắn device, P0-02 §2.4) | Từ chối hành động, yêu cầu xác thực lại; ghi log lần từ chối |
| BR-MBI-QDD-104 | Offline-capable: duyệt offline được ký local, xếp hàng đồng bộ; server đối chiếu trạng thái + version hiện hành; một yêu cầu chỉ ghi nhận đúng một lần | Trạng thái đã đổi (người khác xử lý, hết hạn) → trả "đã xử lý bởi người khác — không áp dụng", không tạo bản ghi thứ hai |
| BR-MBI-QDD-105 | Bản gửi khách khóa vĩnh viễn read-only; sửa = version mới + duyệt lại; vòng sửa theo tier (sales.md B.6: D/E ≤2, B/C ≤4 — vượt chặn, SALES_L5 mở exception có lý do). Giả định: số vòng cần đối chiếu chiều V6.0 đã chốt tại `[KXN-8]` (proposal: B/C ≤2, D/E ≤4) khi cấu hình — không tự quyết, cấu hình effective-dated | Nút sửa vô hiệu khi vượt vòng chưa có exception; mở exception do SALES_L5, ghi audit log |
| BR-MBI-QDD-106 | Tỷ giá/phí nền tảng biến động >5% → version điều chỉnh không tính vào vòng sửa tier; hiển thị nhãn "version điều chỉnh" riêng | Tính nhầm vào vòng sửa → API đối chiếu nguyên nhân version, từ chối trừ vòng, alert SYS_ADMIN |
| BR-MBI-QDD-107 | Hiệu lực 30 ngày (tối đa 60 cho HĐ năm/đa giai đoạn); hết hạn tự chuyển "Hết hạn" → tiếp bán phải re-quote theo định mức hiện hành; sau duyệt GM tối đa 2 ngày LV phải gửi khách, quá hạn cảnh báo SM + GDKD | Hết hạn: nút duyệt treo bị thu hồi, hàng đợi làm sạch; quá hạn 2 ngày: push cảnh báo SALES_L4/SALES_L5 (SM/GDKD — KXN-14) kèm link hồ sơ |
| BR-MBI-QDD-108 | Giá vốn/GM dữ liệu Mật: mobile chỉ SALES_L4 trở lên (và FIN/BOD trong phạm vi nhiệm vụ) xem GM; SALES_L1/L2 chỉ thấy giá bán và kết quả duyệt. Cấm chiết khấu ẩn — tặng giờ/tài nguyên không ghi giá phải qua duyệt như chiết khấu | API không trả GM cho vai không đủ quyền; dòng "tặng kèm" không định giá → chặn gửi, yêu cầu bổ sung duyệt |
| BR-MBI-QDD-109 | Mọi version, người duyệt, lý do chiết khấu, device, IP, thời điểm ghi audit log bất biến (WORM) tại CORE | Thiếu lý do khi duyệt/từ chối exception → từ chối ghi nhận hành động |
| BR-MBI-QDD-110 | Ngoại lệ: pilot 1 tháng GM dưới ngưỡng tối đa một kỳ, ≤60 ngày (SALES_L5 duyệt kèm mục tiêu chuyển đổi); tái ký trong 12 tháng giữ bảng giá cũ tối đa 1 lần; khách BOD-sponsored ngoài ma trận phải có văn bản; định mức theo tier chốt theo V6.0 (`[KXN-8]`) | Thiếu điều kiện ngoại lệ → chặn duyệt; mobile hiển thị loại ngoại lệ và giấy tờ đính kèm bắt buộc |
| BR-MBI-QDD-111 | Quotation đủ duyệt là đầu vào luồng hợp đồng: trước khi ký bắt buộc Brand Safety 7/7 (FEAT-MBI-QDD-002); HĐ giữ 1 serviceType bất biến — RENTAL phí 1–8% trên chi tiêu, MANAGED phí 10–20% theo NSQC — bảng giá quotation phải khớp serviceType | Thiếu điều kiện luồng sau → không chuyển sang soạn hợp đồng; hệ thống ghi rõ mục còn thiếu |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry. Mobile không cung cấp hành động soạn thảo/cấu hình — các hành động đó thuộc WEB theo spec counterparts.*

| Hành động (trên mobile) | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | BOD (CEO/CFO_CTO) | SYS_ADMIN |
|---------------------------|----------|----------|----------|----------|----------|--------------------|-----------|
| Nhận push + xem quotation/kết quả duyệt gắn deal của mình | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem GM/giá vốn (dữ liệu Mật) | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Duyệt chiết khấu ≤5% (tự duyệt) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duyệt chiết khấu >5–15% (SLA 8h LV) | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Duyệt >15–20% + GM dưới ngưỡng + exception (SLA 1 ngày) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Duyệt chiết khấu >20% (SLA 2 ngày, văn bản) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Mở exception vòng sửa (có lý do) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Xem dashboard SLA duyệt | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ | ❌ |
| Cấu hình ma trận/định mức/SLA | ❌ | ❌ | ❌ | ❌ | ❌ | Ban hành (WEB) | Kỹ thuật (WEB) |
| Sửa/xóa audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Ghi chú: SALES_L5 (GDKD) là vị trí quy hoạch, tạm do BOD kiêm nhiệm — khi một người giữ thẩm quyền 2 cấp liên tiếp, hệ thống vẫn cấm tự duyệt cả 2 cấp cho cùng một quotation; ma trận tạm thời phải có phê duyệt và audit log riêng. SYS_ADMIN chỉ cấu hình kỹ thuật (device enrollment, kênh push), không duyệt nghiệp vụ, không xem dữ liệu Mật.

---

## 5. Trường Hợp Đặc Biệt

- **Mất mạng giữa lúc bấm duyệt:** hành động được ký local (timestamp + thiết bị), xếp hàng đồng bộ; khi có mạng, server đối chiếu trạng thái hiện hành — nếu yêu cầu đã được xử lý hoặc quotation hết hạn thì kết quả là "không áp dụng", không tạo bản ghi thứ hai.
- **Hai cấp mở cùng yêu cầu đồng thời:** first-writer-wins theo đúng cấp ma trận; người còn lại nhận thông báo "đã xử lý bởi [vai] lúc [thời điểm]" kèm tham chiếu bản ghi.
- **Vai kiêm nhiệm tạm thời (GDKD do BOD kiêm nhiệm):** ma trận tạm effective-dated do BOD phê duyệt; một người không tự duyệt 2 cấp liên tiếp trên cùng quotation — cần cấp khác hoặc luồng văn bản thay thế.
- **Push không tới được (app tắt, thiết bị offline lâu):** SLA clock vẫn chạy phía CORE; quá nửa SLA hệ thống lặp cảnh báo trong app và dashboard cấp trên — trách nhiệm fallback theo dõi thuộc SM/GDKD.
- **Quotation hết hiệu lực khi đang chờ duyệt:** mọi yêu cầu duyệt treo tự hủy kèm thông báo; tiếp tục bán buộc re-quote theo định mức hiện hành, không có "duyệt bù".
- **Thiết bị mới hoặc người duyệt nghỉ dài ngày:** MFA TOTP phải re-enroll theo P0-02 §2.4 trước khi nút duyệt bật lại; SM phân quyền thay thế cùng cấp trở lên qua WEB — không chấp nhận duyệt hộ chéo cấp hay chia sẻ thiết bị.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Quotation (và các version) — trạng thái quản lý phía CORE; mobile chỉ kích hoạt chuyển đổi khi ma trận cho phép.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit, WEB)──► [PENDING_APPROVAL] ──(đủ cấp duyệt)──► [APPROVED] ──(gửi khách, WEB)──► [SENT — khóa vĩnh viễn]
                                │        │                          │             │
                                │        │ (reject)                 │             │ (sửa = version mới)
                                │        ▼                          │             ▼
                                │    [REJECTED]                     │       [SUPERSEDED]
                                └──(quá hiệu lực)──► [EXPIRED] ◄────┘
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit đề xuất duyệt | `PENDING_APPROVAL` | SALES_L2 chủ deal (WEB) | Đủ nội dung bắt buộc, trace đúng version định mức hiệu lực |
| `PENDING_APPROVAL` | Approve theo ma trận | `APPROVED` | SALES_L2 (≤5%), SALES_L4 (5–15%), SALES_L5 (15–20%/GM dưới ngưỡng/exception), BOD (>20%) | MFA step-up trên mobile; lý do/nhận định bắt buộc với exception |
| `PENDING_APPROVAL` | Reject | `REJECTED` | Cấp duyệt có thẩm quyền | Phải nhập lý do — không lý do API từ chối |
| `PENDING_APPROVAL` / `APPROVED` | Tự hết hạn | `EXPIRED` | Hệ thống | Vượt 30/60 ngày kể từ phát hành |
| `APPROVED` | Gửi khách (chỉ WEB) | `SENT` | SALES_L2 chủ deal | Đủ duyệt chiết khấu + GM; ≤2 ngày LV sau duyệt GM, quá hạn cảnh báo SM + GDKD |
| `SENT` | Sửa → version mới | `SUPERSEDED` + `DRAFT` mới | SALES_L2 (WEB) + duyệt lại toàn cấp | Vòng sửa theo tier chưa vượt hoặc có exception SALES_L5; version điều chỉnh >5% không tính vòng |
| `EXPIRED` / `REJECTED` | Re-quote | `DRAFT` mới | SALES_L2 (WEB) | Theo định mức hiện hành; trừ tái ký 12 tháng giữ bảng giá cũ tối đa 1 lần |

**Quy tắc:** `SENT` khóa vĩnh viễn read-only, không quay lại trạng thái nào; `EXPIRED`/`REJECTED` là trạng thái kết thúc của version, phải qua re-quote/version mới. Mobile chỉ kích hoạt chuyển đổi từ `PENDING_APPROVAL`; mọi chuyển đổi ghi audit log bất biến kèm người, thiết bị, IP, thời điểm.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `QuotationVersion` | `id`, `deal_id`, `version_no`, `service_type` (RENTAL/MANAGED), `selling_price`, `discount_percent`, `gm_value`, `effective_from/to`, `status`, `adjustment_reason` | FK → `deal.id`; snapshot định mức hiệu lực tại thời điểm phát hành | Bản `SENT` khóa read-only; version điều chỉnh >5% có nhãn riêng |
| `DiscountApprovalRequest` | `id`, `quotation_version_id`, `discount_percent`, `required_level`, `sla_deadline`, `state`, `strategy_note` | FK → `QuotationVersion.id` | SLA clock chạy phía CORE kể cả khi mobile offline |
| `ApprovalMatrixConfig` | `id`, `min_percent`, `max_percent`, `gm_floor_by_service`, `required_role`, `sla_hours`, `effective_from/to` | Cấu hình effective-dated, version hóa | BOD/GDKD ban hành trên WEB; mobile chỉ đọc; gồm enum ngoại lệ (pilot, tái ký, BOD-sponsored) |
| `ApprovalAction` | `id`, `request_id`, `actor_id`, `action`, `reason`, `device_id`, `ip`, `mfa_verified`, `acted_at` | FK → `DiscountApprovalRequest.id` | WORM; nguồn sự thật audit và đối soát SLA |
| `PushAlert` | `id`, `recipient_role`, `entity_ref`, `alert_type` (pending/escalation/expiry/overdue-send), `sent_at`, `read_at` | FK → entity liên quan | Kênh cảnh báo mobile; không thay thế SLA clock CORE |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-SALES-006.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: TPKD duyệt chiết khấu 12% trên mobile | GM đạt ngưỡng ads ≥20%, yêu cầu chờ SALES_L4 | SALES_L4 mở push, MFA step-up, bấm duyệt | `APPROVED` đủ cấp, SLA clock dừng trước 8h LV, audit log ghi device/IP/thời điểm | [ ] |
| SC-002: Chặn duyệt GM dưới ngưỡng sai cấp | GM 16% (dưới ngưỡng ads), chiết khấu 4% | SALES_L2 bấm "tự duyệt" | API từ chối: "GM dưới ngưỡng — yêu cầu SALES_L5/BOD duyệt"; không tạo `ApprovalAction` | [ ] |
| SC-003: Duyệt offline đồng bộ đúng một lần | SALES_L4 đã bấm duyệt khi mất mạng | Trong lúc offline, SALES_L5 đã reject | Đồng bộ trả "đã xử lý bởi người khác — không áp dụng"; chỉ một bản ghi hành động tồn tại | [ ] |
| SC-004: Escalate quá SLA duyệt | Yêu cầu 5–15% chờ SALES_L4 quá 8 giờ LV | Job kiểm tra SLA chạy | Push escalate GDKD, dashboard SM hiển thị đỏ, bản ghi cảnh báo lưu audit | [ ] |
| SC-005: Ẩn dữ liệu Mật theo vai | SALES_L2 mở chi tiết quotation của mình | Client request dữ liệu giá vốn/GM | API không trả GM; UI hiển thị "dữ liệu Mật — chỉ cấp TPKD trở lên"; không rò rỉ qua log client | [ ] |
| SC-006: Cảnh báo quá 2 ngày chưa gửi khách | Quotation `APPROVED` đủ GM đã 3 ngày LV, chưa `SENT` | Job kiểm tra chạy | Push cảnh báo SALES_L4 + SALES_L5 (SM/GDKD — KXN-14) kèm link hồ sơ; sự kiện lưu `PushAlert` | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (API duyệt mobile, push, đồng bộ offline) | `technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (CORE engine ↔ MOBILE, MFA step-up P0-02 §2.4) | `technical-specs/integration-map.md` |
| Màn hình UI (hàng đợi duyệt, chi tiết quotation, dashboard SLA) | `phase4-ux/mobile-internal/quotation-dealdesk/approval-queue.md` |
| Domain nguồn (RENTAL/MANAGED, định mức dịch vụ) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1) |
| Spec cùng REQ tại hệ khác | `phase2-features/core-backend/quotation-dealdesk/*.md`, `phase2-features/bcerp-web/quotation-dealdesk/*.md`, cùng lane `hop-dong-loi-nda-va-brand-safety-e-sign.md` (FEAT-MBI-QDD-002) |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
