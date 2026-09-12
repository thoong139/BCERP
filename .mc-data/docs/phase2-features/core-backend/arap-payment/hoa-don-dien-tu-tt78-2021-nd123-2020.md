# Tính Năng: Hóa đơn điện tử TT78/2021 + NĐ123/2020

> **Dựa trên:** REQ-FIN-011 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Hóa đơn điện tử (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-005-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-005 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-011] — liên quan: REQ-FIN-004 (đối soát/khóa kỳ làm dữ liệu nguồn), REQ-FIN-013 (dùng chung luồng kết nối với phần mềm kế toán VAS), REQ-FIN-012 (lưu trữ WORM), REQ-FIN-001 (ranh giới tiền giữ hộ) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Đối soát + khóa kỳ (REQ-FIN-004) và FEAT-CORE-ARAP-003 (công nợ/thanh toán thực nhận) phải sẵn sàng trước; FEAT-CORE-ARAP-006 (luồng kết nối dùng chung với VAS/cơ quan thuế) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; business rules lấy từ BR-FIN-601 (call-2 compliance-expert); thời điểm lập hóa đơn từng loại dịch vụ chốt với tư vấn thuế khi triển khai — không ảnh hưởng kiến trúc XML/kết nối |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Phát hành hóa đơn điện tử đúng pháp lý (TT78/2021/TT-BTC + NĐ 123/2020) cho doanh thu phí dịch vụ/markup của BCAgency qua domain service sinh XML chuẩn có mã cơ quan thuế, sử dụng chứng từ đã đối soát/khóa kỳ làm dữ liệu nguồn duy nhất — tách bạch tuyệt đối khỏi dòng tiền giữ hộ của khách, và quản lý điều chỉnh/thay thế/hủy qua nghiệp vụ chuẩn có log bất biến.

**Phạm vi:**
- Bao gồm: service sinh HĐĐT chuẩn XML theo NĐ123/2020; gửi/kết nối cơ quan thuế qua luồng kết nối dùng chung với connector VAS (cấu hình kết nối ngoại vi trong Settings — DI-004 12/09, vendor-agnostic); kiểm tra điều kiện phát hành (chứng từ đã đối soát/khóa kỳ, gắn hợp đồng và thanh toán thực nhận); xác định thời điểm lập theo NĐ123/2020 (hoàn thành cung cấp dịch vụ); API điều chỉnh/thay thế/hủy theo nghiệp vụ chuẩn; lưu trữ HĐĐT theo quy định retention (≥10 năm WORM theo BR-FIN-503); API tra cứu danh mục HĐ và trạng thái mã cơ quan thuế.
- Không bao gồm: màn phát hành/tra cứu/điều chỉnh trên web (counterpart SYS-BCERP-WEB); chứng từ đối soát và khóa kỳ (REQ-FIN-004); quản lý vận hành kết nối/vault credentials của GW (REQ-BOD-008 — cross-dependency của FEAT-CORE-ARAP-006); hạch toán thuế FCT chi tiết (FEAT-CORE-ARAP-007).

**Đặc thù touchpoint SYS-CORE-BACKEND:** phát hành HĐĐT là luồng service-to-service — counterpart web chỉ trình nút phát hành khi API xác nhận điều kiện; toàn bộ ràng buộc pháp lý (dữ liệu nguồn khóa kỳ, ranh giới doanh thu, nghiệp vụ điều chỉnh) enforce ở tầng service; file XML và metadata hóa đơn là bản ghi bất biến (không UPDATE/DELETE — chỉ nghiệp vụ điều chỉnh/thay thế/hủy có log); mọi tương tác với cơ quan thuế ghi audit log hai chiều (request/response payload hash); dữ liệu hóa đơn phân loại Restricted, tenant isolation theo khách.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Gọi API phát hành hàng loạt cho danh mục chứng từ đã khóa kỳ của tháng | Xuất hóa đơn đúng lúc không phải nhập liệu tay từ Sheets |
| 2 | FIN_L1 | Tra cứu trạng thái HĐ (đã gửi, đã được cấp mã, bị từ chối) qua API | Nắm kịp thời hóa đơn lỗi để xử lý theo hướng dẫn cơ quan thuế |
| 3 | FIN_L2 | Rà soát danh mục HĐ trước chốt kỳ qua API kiểm tra chéo (HĐ vs chứng từ vs thanh toán thực nhận) | Đảm bảo không phát hành thiếu/thừa trước khi khóa kỳ |
| 4 | BOD_CFO_CTO | Duyệt ngoại lệ phát hành qua API (danh mục ngoài lô chuẩn) | Mọi hóa đơn đi qua đúng thẩm quyền với vết duyệt |
| 5 | FIN_L2 | Tạo hóa đơn điều chỉnh/thay thế qua API chuẩn TT78 (kèm hóa đơn gốc bị thay thế) | Sửa sai sót mà không phá vỡ tính pháp lý và lịch sử hồ sơ |
| 6 | Hệ thống (service) | Từ chối phát hành khi dữ liệu nguồn chưa đối soát/khóa kỳ hoặc dòng tiền là tiền giữ hộ | Không sinh hóa đơn sai pháp lý ngay từ nguồn |
| 7 | Hệ thống (job) | Lưu XML + metadata vào WORM storage và ghi hash vào audit log | Đáp ứng lưu trữ ≥10 năm phục vụ thanh tra (REQ-FIN-012) |
| 8 | BOD_CFO_CTO | Nhận báo cáo tổng hợp HĐ phát hành/điều chỉnh/hủy theo kỳ qua API tổng hợp | Giám sát tuân thủ thuế ở cấp quản trị |

**Diễn giải luồng chính (service layer):** (1) nhận yêu cầu phát hành theo kỳ/khách → kiểm tra chứng từ nguồn đã đối soát + khóa kỳ + gắn hợp đồng + thanh toán thực nhận; (2) kiểm tra ranh giới doanh thu — chỉ phí dịch vụ/markup, từ chối mọi dòng tiền giữ hộ; (3) xác định thời điểm lập theo NĐ123/2020 và sinh XML theo mẫu thông tư; (4) gửi qua luồng kết nối (dùng chung connector Settings) đến cơ quan thuế, nhận mã; (5) lưu XML + receipt + hash vào WORM; (6) thất bại → xử lý theo hướng dẫn, không phát hành lại đè hồ sơ cũ.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-501 | CORE sinh HĐĐT chuẩn XML theo NĐ 123/2020, mã cơ quan thuế theo TT 78/2021; kết nối gửi cơ quan thuế dùng chung luồng kết nối của REQ-FIN-013 (connection profile cấu hình tại Settings, DI-004 12/09 — vendor-agnostic: adapter API hoặc import/export chuẩn theo khả năng dịch vụ trung gian); không hardcode tên nhà cung cấp dịch vụ HĐĐT | Thiếu profile kết nối → từ chối phát hành `CONNECTION_NOT_CONFIGURED` |
| BR-ARAP-502 | Dữ liệu nguồn bắt buộc là chứng từ đã đối soát/khóa kỳ, gắn hợp đồng và thanh toán thực nhận; chứng từ nháp/chưa đối soát không được làm nguồn hóa đơn | Từ chối phát hành `SOURCE_NOT_LOCKED`, log attempt |
| BR-ARAP-503 | Ranh giới bắt buộc: HĐĐT chỉ phát hành trên doanh thu phí dịch vụ/markup — tuyệt đối không xuất hóa đơn cho dòng tiền giữ hộ (khớp BR-FIN-101: tiền giữ hộ là nợ phải trả) | Cố phát hành trên tiền giữ hộ bị chặn hard `DISALLOWED_REVENUE_LINE` + alert |
| BR-ARAP-504 | Thời điểm lập hóa đơn theo NĐ 123/2020 (hoàn thành cung cấp dịch vụ); ánh xạ từng loại dịch vụ (phí quản lý, markup, dịch vụ nội dung...) được cấu hình effective-dated; cấu hình ban đầu chốt với tư vấn thuế trước go-live | Dịch vụ chưa cấu hình thời điểm lập → không phát hành được, cảnh báo cấu hình |
| BR-ARAP-505 | Điều chỉnh/thay thế/hủy chỉ qua nghiệp vụ chuẩn (hóa đơn điều chỉnh, hóa đơn thay thế, biên bản) có log bất biến — không xóa/sửa XML đã phát hành; hóa đơn thay thế phải dẫn chiếu hóa đơn gốc; cơ quan thuế từ chối mã → xử lý theo hướng dẫn, không phát hành lại đè lên hồ sơ cũ | Cố UPDATE/DELETE XML → chặn ở tầng service + dữ liệu (`IMMUTABLE_INVOICE`), chỉ ghi nhận nghiệp vụ mới |
| BR-ARAP-506 | HĐĐT lưu trữ theo quy định (retention ≥10 năm WORM theo BR-FIN-503); mọi request/response với cơ quan thuế ghi audit log kèm hash payload; việc xem/truy xuất hóa đơn cũng bị meta-log | Thiếu hash/meta-log → transaction bị đánh dấu lỗi, job kiểm tra toàn vẹn báo cáo hằng ngày |
| BR-ARAP-507 | Hóa đơn chỉ phát hành cho khách đã qua đối soát công nợ của FEAT-CORE-ARAP-003; thanh toán thực nhận đối chiếu số dư AR; Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006) thỏa trên dòng tiền tương ứng — không hóa đơn trên tiền "chờ khách chuyển" | Dòng tiền chưa khớp → từ chối `HARD_STOP_NOT_RELEASED` |
| BR-ARAP-508 | Thuế trên hóa đơn (VAT phí dịch vụ) và nghĩa vụ thuế liên quan thanh toán nền tảng quốc tế (FCT — FEAT-CORE-ARAP-007) hạch toán theo cấu hình thuế có phê duyệt; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) — dữ liệu hóa đơn legacy chỉ read-only, không phát hành bù từ legacy | Thiếu cấu hình thuế → từ chối phát hành `TAX_CONFIG_MISSING`; ghi dữ liệu vào legacy bị chặn |

---

## 4. Phân Quyền

> Enforce tại tầng service; counterpart web hiển thị nút phát hành/tra cứu/điều chỉnh theo kết quả check tập trung.

| Hành động (API) | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------------|--------|--------|-------------|
| Xem danh mục HĐ + trạng thái mã | ✅ | ✅ | ✅ |
| Phát hành lô HĐ theo kỳ chuẩn | ✅ | ✅ (phê duyệt lô) | ❌ |
| Phát hành ngoại lệ (ngoài lô chuẩn) | ❌ | ✅ (đề xuất + lý do) | ✅ (duyệt) |
| Tạo hóa đơn điều chỉnh/thay thế | ❌ | ✅ (kèm dẫn chiếu gốc) | ✅ |
| Hủy hóa đơn (trước gửi CQT) | ❌ | ✅ (lý do bắt buộc) | ✅ |
| Hủy/điều chỉnh sau khi có mã CQT | ❌ | ✅ (đề xuất theo nghiệp vụ chuẩn) | ✅ (duyệt) |
| Cấu hình ánh xạ thời điểm lập/thuế theo loại dịch vụ | ❌ | ❌ (đề xuất) | ✅ (duyệt ban hành) |
| Tải XML gốc (tra cứu đầy đủ) | ✅ (theo phạm vi) | ✅ | ✅ |
| Xuất báo cáo HĐ theo kỳ | ✅ | ✅ | ✅ |
| Xóa/sửa XML đã phát hành | ❌ | ❌ | ❌ (không ai — chỉ nghiệp vụ chuẩn) |

---

## 5. Trường Hợp Đặc Biệt

- **Cơ quan thuế từ chối cấp mã (lỗi dữ liệu):** service đánh dấu hóa đơn `REJECTED_BY_TAX_AUTHORITY` kèm mã lỗi, FIN_L2 xử lý theo hướng dẫn và phát hành lại trên hồ sơ mới dẫn chiếu hồ sơ lỗi — bản XML lỗi giữ nguyên trong WORM.
- **Hóa đơn cho khách nước ngoài không có MST VN:** phát hành theo quy định cho tổ chức không có mã số thuế VN (dùng mã định danh nước ngoài theo mẫu thông tư); ánh xạ trường trong XML cấu hình theo profile khách.
- **Doanh thu phát sinh xuyên kỳ (dịch vụ hoàn thành cuối tháng, khách xác nhận chậm):** thời điểm lập theo NĐ123/2020 vẫn ghi theo ngày hoàn thành cung cấp dịch vụ; hệ thống cho phép phát hành trước sau trong kỳ theo cấu hình, mọi ngoại lệ có log.
- **Hóa đơn sai sót phát hiện sau khi khách nhận:** điều chỉnh/thay thế theo nghiệp vụ chuẩn TT78 (hóa đơn điều chỉnh + hóa đơn mới thay thế) — hóa đơn gốc bị thay thế vẫn tồn tại và dẫn chiếu hai chiều.
- **Dịch vụ trung gian HĐĐT gián đoạn:** hàng đợi phát hành retry + alert; trong thời gian gián đoạn, không cho phát hành "ngoài luồng" — các lô chờ giữ trạng thái `QUEUED` có timestamp.
- **Dữ liệu hóa đơn từ legacy PMS:** trong phạm vi migrate chọn lọc, hóa đơn 12 tháng payment history chỉ import để đối chiếu và tra cứu read-only — không tái sử dụng làm nguồn phát hành mới.
- **Multi-tenant:** mỗi hóa đơn gắn tenant của khách; dải số hóa đơn và kỳ kê khai theo pháp nhân BC trên tenant tương ứng — không có hóa đơn xuyên tenant.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hóa đơn điện tử (`einvoice`)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(validate nguồn khóa kỳ + ranh giới doanh thu)──► [READY] ──(gửi CQT)──► [SENT] ──(cấp mã)──► [ISSUED]
             │                                                  │
             │ (thiếu điều kiện)                                │ (CQT từ chối)
             ▼                                                  ▼
         [BLOCKED]                                          [REJECTED_BY_TAX]
[ISSUED] ──(điều chỉnh/thay thế theo nghiệp vụ chuẩn)──► [ADJUSTED] / [REPLACED]
[ISSUED] ──(hủy theo nghiệp vụ chuẩn)──► [CANCELLED]
[SENT] ──(hủy trước cấp mã)──► [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Validate nguồn | `READY` | Service tự động | Chứng từ đã đối soát/khóa kỳ; gắn hợp đồng + thanh toán thực nhận; không phải dòng giữ hộ |
| `DRAFT` | Chặn thiếu điều kiện | `BLOCKED` | Service tự động | Ghi lý do (`SOURCE_NOT_LOCKED`/`DISALLOWED_REVENUE_LINE`/...) |
| `READY` | Gửi cơ quan thuế | `SENT` | FIN_L1 (lô chuẩn) / CFO duyệt (ngoại lệ) | Profile kết nối hợp lệ; XML theo mẫu NĐ123 |
| `SENT` | Nhận mã CQT | `ISSUED` | Service tự động | Mã hợp lệ từ CQT; lưu receipt + hash |
| `SENT` | CQT từ chối | `REJECTED_BY_TAX` | Service tự động | Lưu mã lỗi; xử lý theo hướng dẫn, phát hành lại trên hồ sơ mới |
| `ISSUED` | Điều chỉnh/thay thế | `ADJUSTED`/`REPLACED` | FIN_L2 (CFO duyệt ngoại lệ) | Nghiệp vụ chuẩn TT78; dẫn chiếu gốc hai chiều; log bất biến |
| `ISSUED`/`SENT` | Hủy | `CANCELLED` | FIN_L2/CFO theo phạm vi | Nghiệp vụ chuẩn; lý do bắt buộc; trước/sau cấp mã theo quy định |

**Quy tắc:**
- Không quay về trạng thái trước; `CANCELLED`, `REPLACED`, `ADJUSTED` là trạng thái kết thúc của hồ sơ gốc — hồ sơ mới tạo riêng có dẫn chiếu.
- XML đã tạo là bản ghi bất biến — mọi thay đổi qua hồ sơ nghiệp vụ mới.
- Mọi chuyển trạng thái ghi audit log bất biến; tương tác CQT lưu request/response hash hai chiều.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `einvoice` | `id`, `tenant_id`, `legal_entity`, `customer_id`, `source_settlement_ids[]`, `revenue_lines[]` (chỉ phí dịch vụ/markup), `vat_amount`, `xml_file_id`, `status`, `tax_code`, `issued_at` | FK → `tenants.id`, `customers.id`, `settlements.id` | XML immutable; WORM ≥10 năm |
| `einvoice_adjustment` | `original_invoice_id`, `type` (ADJUST/REPLACE/CANCEL), `new_invoice_id`, `reason`, `approved_by` | FK → `einvoice.id` ×2 | Nghiệp vụ chuẩn TT78 |
| `tax_authority_receipt` | `invoice_id`, `request_hash`, `response_hash`, `tax_code`, `received_at`, `error_code` | FK → `einvoice.id` | Log hai chiều với CQT |
| `invoice_timing_config` | `service_type`, `timing_rule`, `effective_from`, `effective_to`, `approved_by` | Độc lập | Effective-dated; chốt với tư vấn thuế |
| `connection_profile` (tham chiếu Settings/GW) | `profile_id`, `purpose` (VAS/tax authority), `adapter_type`, `status` | Tham chiếu MOD-SETTINGS-GW | Vendor-agnostic (DI-004) |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Phát hành lô chuẩn | Chứng từ tháng đã đối soát + khóa kỳ | FIN_L1 gọi API phát hành | XML sinh đúng mẫu, gửi CQT, nhận mã, lưu receipt + hash | [ ] |
| SC-002: Chặn nguồn chưa khóa kỳ | Chứng từ chưa đối soát | Gọi API phát hành | Từ chối `SOURCE_NOT_LOCKED`, hóa đơn ở `BLOCKED` | [ ] |
| SC-003: Chặn dòng tiền giữ hộ | Dòng doanh thu chứa tiền giữ hộ | Validate ranh giới | Chặn hard `DISALLOWED_REVENUE_LINE` + alert | [ ] |
| SC-004: Điều chỉnh chuẩn | HĐ `ISSUED` sai số tiền | FIN_L2 tạo điều chỉnh | HĐ gốc `ADJUSTED`, hồ sơ mới dẫn chiếu gốc, XML gốc nguyên vẹn | [ ] |
| SC-005: CQT từ chối | CQT trả mã lỗi | Nhận phản hồi | `REJECTED_BY_TAX`, lưu mã lỗi; phát hành lại trên hồ sơ mới | [ ] |
| SC-006: Lưu trữ WORM | HĐ `ISSUED` | Job lưu trữ | XML + metadata vào WORM, job toàn vẹn hằng ngày kiểm hash | [ ] |
| SC-007: Tenant isolation | Token tenant A truy vấn hóa đơn tenant B | Truy vấn API | Rỗng/403, meta-log ghi attempt | [ ] |

> **Liên kết:** SC-001–SC-005 map REQ-FIN-011; SC-006 map REQ-FIN-012; SC-007 map REQ-FIN-011 + BR-FIN-603.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (einvoice lifecycle) | `technical-specs/api-contract.md` |
| Tích hợp (luồng kết nối CQT dùng chung REQ-FIN-013) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-011, B.6 — BR-FIN-601, BR-FIN-503 retention), `phase1-business/P1-02-business-workflow.md` (bên ngoài #4 cơ quan thuế & DV HĐĐT; nguyên tắc #1 tiền giữ hộ) |
