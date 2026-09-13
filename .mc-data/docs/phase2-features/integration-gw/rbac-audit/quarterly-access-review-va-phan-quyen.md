# Tính Năng: Quarterly Access Review & Phân Quyền

> **Dựa trên:** REQ-BOD-007 trong `phase1-business/departments/bod/bod.md` (Phần A, Phần B — Mục B7)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/P1-02-business-workflow.md` (§8 — nền dùng chung), `work/wf-analyze-requirements/deferred-issues.md` (DI-006, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/integration-gw/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/integration-gw/rbac-audit/feat-gw-rbac-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-GW-RBAC-001` — bản riêng của touchpoint SYS-INTEGRATION-GW (các bản counterpart: SYS-CORE-BACKEND `FEAT-CORE-RBAC-003`, SYS-BCERP-WEB `FEAT-ERP-RBAC-003`). REQ-BOD-007 xuất hiện ở 3 systems — bản này chỉ mô tả phần của gateway.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-RBAC-001 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-007 — Quarterly access review & quản trị phân quyền (HIGH, MVP — RBAC nền GĐ1, chu kỳ review từ go-live); fan-out 3 systems: CORE (primary — RBAC engine, báo cáo user × role × level), WEB (workspace review + ký CEO), GW (bản này — inventory credentials + thực thi thu hồi/rotate) |
| Người dùng liên quan | BOD_CEO (chủ trì, ký review), BOD_CFO_CTO (xuất báo cáo inventory, bị review), SYS_ADMIN (thực thi sau phê duyệt) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — inventory credentials là đầu vào bắt buộc của chu kỳ review đầu tiên sau go-live) |
| Phụ thuộc | FEAT-CORE-RBAC-005 — RBAC & SSO/MFA tập trung (GW không tự xác thực, không tự gán vai); FEAT-CORE-RBAC-003 — chu kỳ review + báo cáo user × role × level (counterpart CORE); FEAT-GW-STGW-001 — credentials vault & adapter (inventory lấy từ vault, rotate thực thi trên vault); REQ-BOD-002 — compensating control kiêm nhiệm CFO/CTO |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh expert chính thức tại thời điểm viết; điều chỉnh đã chốt qua stakeholder review 12/09 được đưa thẳng vào spec: DI-006 — chủ dự án TỪ CHỐI 2 vai OPS_CX/FIN_COMPL, registry chốt 18 vai (CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight) nên toàn bộ phân quyền trong spec KHÔNG có dòng cho 2 vai bị từ chối |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp phần đóng góp của gateway (GW) vào chu trình quarterly access review bắt buộc của REQ-BOD-007: GW là nguồn dữ liệu **inventory credentials/token + ngày rotate** cho báo cáo review kỳ quý và là điểm **thực thi** các quyết định thu hồi/rotate phát sinh từ chu kỳ review và offboarding. RBAC và audit trên gateway tuân thủ nền tảng phân quyền tập trung 18 vai ở SYS-CORE-BACKEND — gateway không dựng hệ phân quyền riêng, mọi thao tác ghi có actor + timestamp + lý do trên audit log bất biến hash-chain.

**Phạm vi:**
- Bao gồm: API inventory credentials/token (đọc từ vault của FEAT-GW-STGW-001) — nền tảng, trạng thái, ngày rotate cuối/đến hạn, người rotate cuối — nạp cho báo cáo review kỳ quý tại counterpart CORE/WEB.
- Bao gồm: cảnh báo token đến hạn rotate (T-7); credential quá hạn rotate >7 ngày kéo adapter sang degraded mode gắn nhãn `manual` (nối DI-007 và FEAT-GW-STGW-002).
- Bao gồm: thực thi revoke + rotate credentials ≤24h khi có sự kiện offboarding, kèm checklist CTO xác nhận; hỗ trợ offboarding khẩn 24h cho nghỉ đột xuất.
- Bao gồm: enforcement RBAC 18 vai registry tại service layer gateway — mọi endpoint quản trị check quyền từ registry tập trung, không check cục bộ, không định nghĩa vai mới.
- Bao gồm: audit log bất biến (hash-chain — hạ tầng REQ-FIN-012) cho mọi thao tác credential và lần gọi API ra nền tảng; xem log cũng bị log.
- Không bao gồm: workspace review (đối chiếu, đánh dấu giữ/thu hồi từng dòng, CEO ký) — thuộc counterpart SYS-BCERP-WEB; chu kỳ quý chạy trên WEB, GW không có giao diện review.
- Không bao gồm: sinh báo cáo user × role × level, duyệt gán/thu hồi role (độc quyền CEO), tự vô hiệu quyền không review 2 quý liên tiếp — thuộc counterpart SYS-CORE-BACKEND; GW chỉ nhận kết quả enforcement (token phiên bị thu hồi → gateway từ chối request).
- Không bao gồm: hạ tầng RBAC engine, SSO/MFA TOTP, immutable audit store — thuộc SYS-CORE-BACKEND (FEAT-CORE-RBAC-005, REQ-FIN-012); gateway gọi và tuân thủ.
- Không bao gồm: console thêm/sửa/rotate credentials — thuộc FEAT-GW-STGW-001; tính năng này tiêu thụ vault và bổ sung góc nhìn chu kỳ review.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-INTEGRATION-GW — tầng gateway/adapter headless: không có UI riêng, hành động được phát từ console web nội bộ responsive (counterpart SYS-BCERP-WEB) nhưng enforce tại service layer gateway. Chu kỳ review quý **không có touchpoint mobile** (BR-BOD-007.3); MOBILE-INTERNAL cấm toàn bộ thao tác vault (REQ-BOD-008); portal khách không liên quan REQ nội bộ này.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO | Xuất nộp inventory credentials/token + ngày rotate từ gateway vào báo cáo review kỳ quý trên WEB | CEO đối chiếu được cả quyền người dùng lẫn bí mật tích hợp trong cùng một kỳ, không sót tài sản "tương đương tiền" nào |
| 2 | BOD_CEO | Xem tổng quan inventory credentials (mask + trạng thái + hạn rotate) do gateway tổng hợp, kèm thay đổi credential phát sinh trong quý | Giữ oversight độc lập với người vận hành vault trước khi ký review |
| 3 | BOD_CEO | Ra quyết định giữ/thu hồi từng credential trong kỳ review và phê duyệt gán/thu hồi vai liên quan gateway | Mọi thay đổi quyền lực đều có người ký chịu trách nhiệm, không ủy quyền |
| 4 | SYS_ADMIN | Thực thi revoke/rotate credential đúng theo quyết định đã được CEO duyệt, với lý do bắt buộc nhập | Phân tách bậc duyệt — thực thi (SoD): tôi không tự quyết, chỉ chạy lệnh có căn cứ |
| 5 | SYS_ADMIN | Nhận việc rotate credential khi adapter ở degraded mode `manual` mà vẫn đúng hạn rotate | Kênh nhập tay/backfill vẫn dùng credential nên bí mật tích hợp không vì mất API mà bị bỏ mặc đến hạn |
| 6 | Hệ thống (GW service) | Tự động cảnh báo token đến hạn rotate T-7 và kéo adapter quá hạn >7 ngày sang degraded `manual` | Không credential nào "sống" vô thời hạn mà không ai biết |
| 7 | Hệ thống (GW service) | Tự động thu hồi + rotate toàn bộ credential liên quan nhân sự offboarding trong ≤24h, sinh checklist cho CTO xác nhận | Khe hở bảo mật sau khi người rời công ty bị đóng trong ngày, có bằng chứng xác nhận |
| 8 | BOD_CEO | Tra cứu audit log bất biến mọi thao tác credential + mọi lần gọi API nền tảng của gateway | Điều tra được "ai làm gì, khi nào, vì lý do gì" ngay cả khi người thực hiện là CTO hay SYS_ADMIN |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-GW-RBAC-001 | **RBAC 18 vai registry, không vai riêng của gateway:** service layer gateway chỉ nhận vai từ registry tập trung 18 vai (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal/mobile-portal). KHÔNG tồn tại OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight. Gateway không định nghĩa, không alias vai ngoài registry | Request mang vai ngoài 18 vai bị từ chối + log cảnh báo; vai tự tạo trong cấu hình gateway là lỗi cấu hình phải vá ngay |
| BR-GW-RBAC-002 | **SYS_ADMIN không tự gán quyền kể cả cho chính mình:** gán/thu hồi vai chỉ hiệu lực sau phê duyệt BOD_CEO (thực thi tại CORE); SYS_ADMIN trên gateway chỉ thực thi thao tác credential đã được duyệt. Mọi thao tác ghi (rotate, revoke, đổi cấu hình) bắt buộc có actor + timestamp + lý do — request thiếu lý do bị từ chối ở tầng API | Thiếu phê duyệt → từ chối + log nỗ lực; thiếu lý do → từ chối, không có nhánh "bỏ trống cho nhanh" |
| BR-GW-RBAC-003 | **Audit bất biến hash-chain, WORM ≥10 năm:** mọi thao tác credential và mọi lần gọi API ra nền tảng ghi audit log append-only hash-chain (dùng chung hạ tầng REQ-FIN-012); các log liên quan tiền/credential lưu tối thiểu 10 năm theo WORM, không ai (kể cả ADMIN/BOD) sửa hay xóa được; việc truy xuất xem log cũng bị log | Không tồn tại API sửa/xóa audit entry; đứt hash-chain kích hoạt alert BOD theo REQ-BOD-005 |
| BR-GW-RBAC-004 | **Quarterly access review bắt buộc có inventory gateway:** trong 10 ngày đầu quý, gateway nạp inventory credentials + ngày rotate (kèm snapshot timestamp — độ tươi dữ liệu) vào chu kỳ review; kỳ review thiếu phần inventory gateway không được coi là hoàn tất. Credential phải được đối chiếu mỗi kỳ — không xuất hiện trong review 2 kỳ liên tiếp → tự đánh dấu `ORPHANED` chờ quyết định thu hồi | Gateway không nạp được inventory → alert CTO + CEO, chu kỳ không đóng; `ORPHANED` quá 1 kỳ không quyết định → escalation BOD |
| BR-GW-RBAC-005 | **Kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002):** BOD_CFO_CTO vừa quản trị vault vừa bị review — toàn bộ thao tác vault của CTO được log immutable và nằm trong phạm vi đối chiếu của CEO mỗi kỳ; CEO ký review không ủy quyền; CEO vắng dài ngày thì quyền không được review tự vô hiệu (an toàn theo thiết kế của CORE) | Thao tác vault của CTO thiếu log hoặc log bị can thiệp → alert đỏ BOD; không tồn tại cơ chế "CTO duyệt chính mình" |
| BR-GW-RBAC-006 | **SSO/MFA tập trung:** gateway không tự xác thực — mọi request đi qua phiên SSO của nền tảng tập trung (FEAT-CORE-RBAC-005); MFA TOTP bắt buộc cho mọi thao tác ghi lên vault/credential (step-up); MOBILE-INTERNAL không có endpoint thao tác vault; portal khách không có đường tới gateway | Thiếu MFA hợp lệ → từ chối + log; request vault từ mobile → từ chối ở tầng gateway + cảnh báo bảo mật |
| BR-GW-RBAC-007 | **PII nhân sự (lương) ở mức Confidential/Restricted:** inventory gateway KHÔNG trộn dữ liệu lương/PII nhân sự; gateway chỉ trả định danh vai/username, không trả thông tin thù lao; báo cáo review chứa PII chỉ phát hành theo phân mức cho BOD và người liên quan | Endpoint gateway trả trường lương/PII → chặn ở review API; phát hiện lộ PII qua log gateway → sự cố P1 + redact ngay |
| BR-GW-RBAC-008 | **Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation thẩm quyền:** quyền duyệt tài chính gắn vai theo ngưỡng 5/50/200 triệu VND (mặc định đã chốt DI-001), vượt thẩm quyền phải escalation lên cấp trên — enforcement hard stop nằm ở SYS-CORE-BACKEND; trên gateway, các vai nắm quyền duyệt chi là đối tượng bắt buộc đối chiếu trong inventory review (vai nào duyệt được tiền phải có người ký giữ lại mỗi quý) | Gateway không có nút duyệt tiền — endpoint gateway can thiệp luồng duyệt tiền là lỗi kiến trúc; vai nắm quyền duyệt chi không được review → phải được CEO quyết giữ/thu hồi trước khi đóng kỳ |
| BR-GW-RBAC-009 | **Rotate/thu hồi gắn vòng đời nhân sự:** offboarding → revoke + rotate credential liên quan ≤24h kèm checklist CTO xác nhận; nghỉ đột xuất → offboarding khẩn 24h, lệch chuẩn ghi nhận vào kỳ review; thử việc/freelancer không có quyền phê duyệt; guest tối đa 90 ngày (gia hạn phải duyệt) — enforce ở CORE, gateway hỗ trợ bằng cách liệt kê credential theo chủ sở hữu vai để quét sạch khi offboarding | Offboarding không rotate trong 24h → escalation CEO + alert đỏ; credential của nhân sự đã offboarding còn `ACTIVE` sau 24h là sự cố bảo mật P1 |
| BR-GW-RBAC-010 | **Cảnh báo T-7 và degraded khi quá hạn:** credential còn 7 ngày đến hạn rotate → alert CTO; quá hạn >7 ngày → adapter tự chuyển degraded gắn nhãn `manual` (nối FEAT-GW-STGW-002) cho đến khi rotate xong; rotate trong degraded vẫn thực hiện bình thường vì kênh manual vẫn dùng credential | Quá hạn không degraded → adapter vi phạm chính sách, tự sửa bởi job reconcile + log; rotate xong → quay lại trạng thái trước |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem inventory credentials (mask + trạng thái + hạn rotate) | ✅ | ✅ | ✅ |
| Nạp/xuất inventory vào chu kỳ review | ✅ (xem kết quả) | ✅ (xuất nộp — người bị review) | ❌ |
| Ra quyết định giữ/thu hồi credential trong kỳ review | ✅ (độc quyền — ký không ủy quyền) | ❌ | ❌ |
| Rotate credentials định kỳ (theo lịch ≥90 ngày) | ❌ | ✅ | ✅ (thực thi sau phê duyệt) |
| Thu hồi khẩn credentials (nghi rò rỉ/offboarding khẩn) | ❌ (phê duyệt khẩn) | ✅ | ❌ (chỉ thực thi sau duyệt CTO/CEO) |
| Thực thi revoke/rotate theo quyết định review | ❌ | ❌ | ✅ (chỉ sau phê duyệt CEO) |
| Xác nhận checklist offboarding | ❌ | ✅ (CTO xác nhận) | ❌ |
| Gán/thu hồi vai 18 vai registry | ✅ (duyệt — độc quyền) | ❌ (đề xuất) | ❌ (không tự gán kể cả chính mình) |
| Kích hoạt/tắt degraded mode `manual` | ❌ | ✅ | ✅ (thực thi sau phê duyệt) |
| Quản trị vault/thao tác credential từ touchpoint mobile | ❌ (cấm) | ❌ (cấm — REQ-BOD-008) | ❌ (cấm) |
| Xem audit log thao tác credential + API calls | ✅ | ✅ (bị review — xem được, thao tác của chính mình vẫn bị log) | ❌ (bị log khi xem qua luồng chung) |
| Sửa/xóa audit log | ❌ | ❌ | ❌ (không tồn tại API — BR-GW-RBAC-003) |

> Quy ước: các vai OPS/FIN/SALES/HR không có đường tới quản trị credential gateway — chỉ tiêu thụ dữ liệu nền tảng qua luồng nghiệp vụ tương ứng; CUSTOMER (portal/mobile-portal) hoàn toàn tách khỏi REQ nội bộ này. Enforcement vai nằm ở CORE; gateway chỉ kiểm tra lại (defense in depth) và từ chối khi registry trả "không có quyền".

---

## 5. Trường Hợp Đặc Biệt

- **Chưa có quyền API developer (DI-007 — trạng thái hiện tại):** Business Verification 7 nền tảng chưa hoàn tất nên adapter khởi điểm ở degraded `manual`, nhưng credential vault vẫn đầy đủ và rotate vẫn chạy đúng hạn vì kênh nhập tay/import vẫn dùng credential; `[KXN-7]` — thời điểm cấp quyền API từng nền tảng chưa xác định nên spec không gắn mốc, job reconcile phải xử lý được cả hai trạng thái.
- **CEO vắng dài ngày trong kỳ review:** CEO ký review không ủy quyền (compensating control); trong khi chờ, các quyền không được review tự vô hiệu theo thiết kế CORE — gateway đồng bộ trạng thái thu hồi nên request mang token phiên của quyền đã vô hiệu bị từ chối tức thì; an toàn theo thiết kế, không có nhánh "ký hộ".
- **Nghỉ đột xuất của người nắm credential:** chạy offboarding khẩn 24h — revoke + rotate toàn bộ credential theo chủ sở hữu vai; lệch chuẩn (quá 24h, thiếu checklist) được gateway ghi nhận và tự nộp vào kỳ review gần nhất để CEO đối chiếu.
- **SYS_ADMIN là người thực thi và cũng là đối tượng bị review:** mọi thao tác của SYS_ADMIN chỉ hợp lệ khi trỏ tới một quyết định đã duyệt (quyết định review hoặc change được CTO duyệt); hành vi thực thi bị log immutable và đối chiếu ngược với quyết định gốc trong kỳ — lệnh thực thi không khớp quyết định nào bị đánh dấu `UNBOUND` và escalation.
- **Credential của nền tảng đang nghi ngờ rò rỉ giữa chu kỳ:** thu hồi khẩn tức thì (CTO duyệt, SYS_ADMIN thực thi hoặc CTO trực tiếp), adapter chuyển degraded `manual`, rotate tạo version mới; toàn bộ chuỗi hành động ghi audit kèm lý do — sau rotate, backfill lấy lại dữ liệu đứt quãng theo FEAT-GW-STGW-002.
- **Kỳ review trùng lúc gateway outage:** báo cáo review vẫn phải đóng — gateway nộp snapshot inventory gần nhất kèm nhãn độ tươi (timestamp + "snapshot, không realtime"); snapshot quá cũ (>7 ngày) → kỳ review ghi nhận bất thường và gateway bổ sung inventory ngay khi phục hồi.
- **Các khoản [KXN] còn mở (6, 7, 9, 15–22):** chưa chặn Phase 2 — spec viết theo assumption an toàn hiện hành, chỉ gắn tag tại điểm phụ thuộc cụ thể (`[KXN-7]` ở trên); các khoản còn lại không chạm trực tiếp phạm vi gateway của REQ-BOD-007, không tự quyết thay chủ dự án.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** CredentialInventoryItem — mỗi credential/token trong inventory gateway (view trên vault của FEAT-GW-STGW-001, bổ sung góc nhìn chu kỳ review)

**Sơ đồ trạng thái:**
```
                 ┌────────────(còn <7 ngày đến hạn)────────────┐
                 ▼                                              │
[ACTIVE] ──(rotate đúng hạn)──► [ACTIVE]                [DUE_SOON]
   │                              ▲                          │
   │                              └──(rotate xong)───────────┤
   │                                                         ▼ (quá hạn >7 ngày)
   │                                                     [OVERDUE] ──(adapter auto degraded `manual`)
   │ (CEO quyết thu hồi / offboarding / thu hồi khẩn)        │
   ▼                                                         ▼
[REVOKED] ◄────────────────(revoke)──────────────────────────┘
   │
   └──(nạp credential mới + duyệt + health check OK)──► [ACTIVE]
[ORPHANED]: nhánh phụ của ACTIVE — không xuất hiện trong review 2 kỳ liên tiếp
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Đến hạn T-7 | `DUE_SOON` | Hệ thống (job tự động) | Job kiểm tra hạn chạy đúng lịch; alert CTO phát ra |
| `DUE_SOON` | Rotate | `ACTIVE` | BOD_CFO_CTO hoặc SYS_ADMIN (sau duyệt) | MFA hợp lệ; credential mới nạp vault; ngày rotate mới ghi nhận; audit có actor + lý do |
| `DUE_SOON` | Quá hạn >7 ngày | `OVERDUE` | Hệ thống (job tự động) | Adapter tự chuyển degraded `manual`; escalation CTO |
| `OVERDUE` | Rotate | `ACTIVE` | BOD_CFO_CTO hoặc SYS_ADMIN (sau duyệt) | Như rotate trên; adapter quay lại trạng thái health bình thường |
| `ACTIVE`/`DUE_SOON`/`OVERDUE` | Revoke | `REVOKED` | BOD_CEO (quyết review) hoặc BOD_CFO_CTO (khẩn) | Lý do bắt buộc (review decision / nghi rò rỉ / offboarding); token vô hiệu tức thì |
| `ACTIVE` | Đánh dấu orphan | `ORPHANED` | Hệ thống (đối chiếu chu kỳ) | Không xuất hiện trong review 2 kỳ liên tiếp; chờ quyết định thu hồi trước khi đóng kỳ tiếp theo |
| `ORPHANED` | Revoke hoặc xác nhận giữ | `REVOKED` / `ACTIVE` | BOD_CEO | Quyết định có ký; giữ lại phải có căn cứ nghiệp vụ ghi trong review record |
| `REVOKED` | Reissue | `ACTIVE` | BOD_CFO_CTO (duyệt) + SYS_ADMIN (thực thi) | Credential mới + health check thành công + audit ghi căn cứ |

**Quy tắc:**
- `REVOKED` là trạng thái kết thúc bắt buộc trước khi nạp credential mới khi nghi ngờ rò rỉ — không "thay token tại chỗ".
- Mọi chuyển trạng thái ghi audit log bất biến kèm actor + timestamp + lý do; chuyển do hệ thống tự động phải truy vết được trigger (job id, rule id).
- Trạng thái là machine-state của gateway; workspace review trên WEB và báo cáo CORE chỉ hiển thị, không tự tính trạng thái.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| CredentialInventoryItem | `credential_id`, `platform` (enum 7 nền tảng + OTHER), `masked_value`, `owner_role`, `issued_at`, `last_rotated_at`, `rotate_due_at`, `status` (ACTIVE/DUE_SOON/OVERDUE/ORPHANED/REVOKED), `snapshot_at` | FK logic → vault của FEAT-GW-STGW-001 | View inventory cho chu kỳ review; không chứa plaintext, không chứa PII lương (BR-GW-RBAC-007) |
| RotationTask | `credential_id`, `type` (scheduled/emergency/offboarding/review_decision), `requested_by`, `approved_by`, `approved_decision_ref`, `executed_by`, `executed_at`, `reason`, `cto_checklist_confirmed` | FK → `CredentialInventoryItem.credential_id` | Thiếu `approved_decision_ref` hoặc `reason` → task không chạy được (BR-GW-RBAC-002) |
| ReviewCycleFeed | `cycle_id`, `quarter` (vd 2026-Q4), `source_system` = GW, `payload_summary`, `item_count`, `snapshot_at`, `freshness_flag` | Gửi cho counterpart CORE/WEB theo `cycle_id` | Kỳ review thiếu feed GW → chu kỳ không đóng (BR-GW-RBAC-004) |
| OrphanTracking | `credential_id`, `first_missed_cycle`, `consecutive_missed`, `escalated` | FK → `CredentialInventoryItem.credential_id` | 2 kỳ liên tiếp không review → `ORPHANED`; quá 1 kỳ không quyết định → escalation BOD |
| GatewayAuditLog | `actor_id`, `actor_role`, `action`, `object_type`, `object_id`, `timestamp`, `reason`, `before/after`, `hash_prev`, `source` (vault_op/api_call/read_log) | Append-only, hash-chain — hạ tầng dùng chung REQ-FIN-012 | WORM ≥10 năm với log tiền/credential; không có API sửa/xóa |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Inventory nạp đủ vào kỳ review | Chu kỳ review Q mở trong 10 ngày đầu quý | CORE/WEB gọi feed inventory từ gateway | Feed trả đủ inventory (mask + hạn rotate + snapshot_at); kỳ thiếu feed GW không thể đóng | [ ] |
| SC-002: Thực thi có căn cứ duyệt | SYS_ADMIN đăng nhập | Thực thi revoke không trỏ tới quyết định đã duyệt, hoặc thiếu lý do | Từ chối ở tầng gateway; task đánh dấu `UNBOUND` + escalation; nỗ lực ghi log | [ ] |
| SC-003: Offboarding 24h | HR phát sự kiện offboarding nhân sự sở hữu credential | Service xử lý sự kiện | Toàn bộ credential liên quan revoke + rotate ≤24h; checklist CTO xác nhận có bằng chứng; quá hạn → alert đỏ + escalation CEO | [ ] |
| SC-004: Cảnh báo T-7 và tự degraded quá hạn | Credential còn 7 ngày đến hạn | Job kiểm tra hạn chạy | `DUE_SOON` + alert CTO; quá hạn >7 ngày → `OVERDUE` + adapter degraded `manual` + escalation; rotate xong quay lại `ACTIVE` | [ ] |
| SC-005: MFA và cấm mobile | Người dùng có vai quản trị | Gọi API credential không kèm MFA, hoặc từ touchpoint mobile nội bộ | Cả hai bị từ chối ở tầng gateway + log cảnh báo bảo mật | [ ] |
| SC-006: Audit bất biến + WORM | Đã có thao tác rotate/revoke và API calls | Truy xuất audit; thử sửa/xóa entry | Truy xuất được đủ actor + timestamp + lý do; không tồn tại API sửa/xóa; log tiền/credential cấu hình lưu ≥10 năm WORM; đứt hash-chain → alert BOD | [ ] |
| SC-007: Kiêm nhiệm bị review đầy đủ | BOD_CFO_CTO kiêm nhiệm, đã thao tác vault trong quý | CEO mở báo cáo review | Toàn bộ thao tác CTO hiện ra trong phạm vi đối chiếu; CEO ký không ủy quyền; quyền không review 2 kỳ → `ORPHANED` chờ quyết định | [ ] |

> **Liên kết:** SC-001→002 map REQ-BOD-007 (chu kỳ + SoD duyệt/thực thi); SC-003 map REQ-BOD-007 (offboarding ≤24h); SC-004 map REQ-BOD-007/REQ-BOD-008 (T-7, degraded); SC-005→006 map REQ-BOD-007/REQ-BOD-011/REQ-FIN-012 (SSO/MFA tập trung, audit bất biến WORM); SC-007 map REQ-BOD-002 (compensating control kiêm nhiệm CFO/CTO).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (inventory feed, rotation task, orphan tracking) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (SSO/MFA từ CORE, feed chu kỳ review, sự kiện offboarding từ HR) | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/integration-gw/rbac-audit/[screen-group].md` (workspace review + ký thuộc bản counterpart SYS-BCERP-WEB) |
| Bản fan-out counterpart | `phase2-features/core-backend/rbac-audit/quarterly-access-review-va-phan-quyen.md` (FEAT-CORE-RBAC-003 — RBAC engine, báo cáo, tự vô hiệu 2 quý), `phase2-features/bcerp-web/rbac-audit/quarterly-access-review-va-phan-quyen.md` (FEAT-ERP-RBAC-003 — workspace review, ký CEO) — REQ-BOD-007 xuất hiện ở 3 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001 — vault/adapter là hạ tầng mà inventory của tính năng này đối chiếu) |
| Nguồn cross-dependency | REQ-BOD-002 — compensating control kiêm nhiệm CFO/CTO (`phase1-business/departments/bod/bod.md`); REQ-BOD-008/REQ-FIN-012/REQ-BOD-011 — vault, audit store, SSO/MFA; `work/wf-analyze-requirements/deferred-issues.md` (DI-006 — gỡ OPS_CX/FIN_COMPL; DI-007 — degraded mode; `[KXN-7]`) |
