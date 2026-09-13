# Tính Năng: Tích hợp phần mềm kế toán VAS hiện hữu

> **Dựa trên:** REQ-FIN-013 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Integration Gateway — Kết nối hệ thống ngoài (SYS-INTEGRATION-GW)
> **Module:** AR/AP Payment — Connector kế toán VAS (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/integration-gw/arap-payment/[screen-group].md`, `phase5-implementation/tasks/integration-gw/arap-payment/feat-gw-arap-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-ARAP-001 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-013] — liên quan: REQ-BOD-008 (cross-dependency: credentials vault & quản trị GW cho connector VAS), REQ-FIN-006 (Hard Stop "đã khớp tiền"), REQ-FIN-007 (công nợ AR/AP + aging + nhắc nợ), REQ-FIN-008 (duyệt chi/SoD/delegate), REQ-FIN-011 (HĐĐT dùng chung luồng kết nối) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (SYS_ADMIN thực thi vận hành sau phê duyệt) |
| Độ ưu tiên | Trung bình (MEDIUM — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | **Cross-dependency: REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS**; counterpart FEAT-CORE-ARAP-006 (xuất bút toán chuẩn phía CORE), FEAT-GW-STGW-001 (quản trị GW & vault), FEAT-GW-STGW-002 (API 7 nền tảng — degraded mode `manual`); cấu hình kết nối ngoại vi đặt tại MOD-SETTINGS-GW (DI-004 12/09) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa review tại thời điểm viết; theo DI-004 (12/09) chủ dự án không chốt tên vendor — connector vendor-agnostic, tên phần mềm cụ thể cấu hình khi triển khai, không chặn thiết kế |

**Fan-out:** REQ-FIN-013 xuất hiện ở 3 systems — đây là bản riêng cho SYS-INTEGRATION-GW; counterparts: SYS-CORE-BACKEND (FEAT-CORE-ARAP-006 — nguồn bút toán, luồng đối chiếu), SYS-BCERP-WEB (màn đối chiếu sổ).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Vận hành ở tầng Integration Gateway các connector/adapter nối BCERP với phần mềm kế toán VAS hiện hữu: nhận lô bút toán/chứng từ/HĐĐT đã được CORE chuẩn hóa từ chứng từ đã duyệt/khóa kỳ, vận chuyển qua adapter API hoặc cơ chế import/export file chuẩn schema đến VAS, chạy job đối chiếu sổ và job migrate legacy PMS chọn lọc — sao cho sổ kế toán pháp lý nằm trên VAS mà số liệu hai bên khớp nhau, mọi lượt kết nối đều có log và có degraded mode "manual" khi mất kết nối.

**Phạm vi:**
- Bao gồm: thực thi connection profile do MOD-SETTINGS-GW cấu hình (vendor-agnostic — adapter API cắm được hoặc sinh/nhận file chuẩn schema); transport job đưa lô xuất từ CORE xuống VAS với retry/backoff/dead-letter; nhận và validate dữ liệu phản hồi từ VAS; job đối chiếu sổ VAS ↔ BCERP hàng tháng (trích dữ liệu hai bên đưa về báo cáo chênh lệch cho CORE/WEB xử lý giải trình); job migrate chọn lọc từ legacy PMS (master data + dự án active + payment history 12 tháng) một chiều vào BCERP, sau đó chuyển legacy read-only; vận chuyển gói dữ liệu HĐĐT chuẩn XML (TT78/2021 + NĐ123/2020) qua cùng luồng kết nối VAS tới cơ quan thuế; gắn nhãn `manual` + backfill khi mất kết nối; log mọi lần gọi adapter.
- Không bao gồm: quyết định xuất dữ liệu nào (thuộc CORE — chỉ xuất chứng từ đã duyệt/khóa kỳ); màn hình đối chiếu và luồng giải trình chênh lệch (counterpart SYS-BCERP-WEB); hạch toán bút toán, aging công nợ và phát hành HĐĐT (thuộc CORE); lưu trữ/rotate credentials (vault thuộc REQ-BOD-008 — GW chỉ tham chiếu); cấu hình connection profile (MOD-SETTINGS-GW).

**Đặc thù touchpoint SYS-INTEGRATION-GW:** đây là feature cầu nối vận chuyển — GW là data plane phía ngoài (P1-02: "GW — data plane 7 nền tảng + connector VAS"); GW không có nút duyệt, không sửa số liệu, chỉ vận chuyển payload đã đóng dấu ở CORE; khi API bên VAS không khả dụng, connector rơi vào degraded mode có kiểm soát (hàng chờ + nhãn `manual` cho dữ liệu đi đường tay) và bắt buộc backfill tự động khi kết nối phục hồi; mọi lần gọi adapter ghi log (thời điểm, hướng, hash payload, kết quả) phục vụ audit và đối soát độ trễ.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem trạng thái sức khỏe connector VAS (thành công/thất bại/degraded, tuổi dữ liệu từng nguồn) trên giao diện console GW | Biết ngay khi luồng số liệu xuống sổ bị trễ, không phải hỏi tay từng người |
| 2 | FIN_L2 | Nhận alert khi lô xuất fail quá ngưỡng retry hoặc rơi vào dead-letter | Chủ động xử lý trước kỳ chốt sổ thay vì phát hiện muộn khi đối chiếu |
| 3 | BOD_CFO_CTO | Kích hoạt/vô hiệu connector theo connection profile đã duyệt tại MOD-SETTINGS-GW | Đổi vendor hoặc cơ chế kết nối mà không sửa code, luôn có vết duyệt |
| 4 | FIN_L1 | Tải file chuẩn schema do connector sinh ra (khi VAS chỉ hỗ trợ import/export file) và nhập file phản hồi từ VAS qua luồng có validate | Vẫn chạy được connector khi bên VAS không mở API |
| 5 | SYS_ADMIN | Xử lý hàng chờ retry và kích hoạt backfill sau sự cố, theo đúng profile đã duyệt | Sự cố được vận hành dứt điểm mà không tự ý thay đổi cấu hình |
| 6 | Hệ thống (scheduler GW) | Tự chạy job vận chuyển theo lịch, tự retry với backoff, tự gắn nhãn `manual` khi degraded | Luồng chuẩn không phụ thuộc thao tác tay, có nhãn nguồn cho mọi số liệu |
| 7 | BOD_CFO_CTO | Duyệt và kích hoạt job migrate legacy PMS theo phạm vi chọn lọc (master data + dự án active + payment history 12 tháng) | Dữ liệu quá khứ đủ dùng mà không kéo rác vào BCERP, legacy chuyển read-only rõ ràng |
| 8 | FIN_L2 | Theo dõi tiến trình vận chuyển gói HĐĐT XML qua luồng kết nối VAS tới cơ quan thuế | Hóa đơn pháp lý có đường đi có vết từ CORE đến cơ quan thuế |

**Diễn giải luồng chính (adapter layer):** (1) CORE đẩy lô xuất đã duyệt vào hàng đợi GW (kèm hash payload và tham chiếu kỳ); (2) GW đọc connection profile `ACTIVE` từ MOD-SETTINGS-GW, map transport tương ứng (adapter API hoặc sinh/nhận file chuẩn schema); (3) GW gọi VAS theo lịch/profile — credentials lấy từ vault REQ-BOD-008, không ghi plaintext vào log; (4) thành công → ghi `adapter_call_log` + xác nhận lô; thất bại → retry backoff, quá ngưỡng → dead-letter + alert FIN_L2/BOD_CFO_CTO; (5) mất kết nối kéo dài → degraded mode: gắn nhãn `manual` cho dữ liệu đi đường tay, khi phục hồi GW tự backfill đối soát manual vs API; (6) hàng tháng GW trích số dư/bút toán hai bên đưa về báo cáo đối chiếu; (7) job migrate legacy chạy theo phạm vi đã duyệt, ghi id mapping legacy → mới, sau go-live GW chặn mọi ghi vào legacy (read-only).

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng adapter/gateway.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-801 | BCERP tích hợp, không thay thế VAS: GW chỉ vận chuyển dữ liệu, **không có nút duyệt, không sửa payload** — lô xuất phải kèm chữ ký/hash từ CORE và chỉ tạo từ chứng từ đã duyệt/khóa kỳ; GW không ghi ngược số liệu nghiệp vụ vào CORE ngoài luồng import có validate | Payload thiếu hash/mảnh mổ từ CORE → từ chối vận chuyển `UNTRUSTED_PAYLOAD` + log |
| BR-ARAP-802 | Mọi giải ngân liên quan TKQC mà GW vận chuyển dữ liệu (lệnh chi, bút toán thanh toán nền tảng) phải đã qua **Financial Hard Stop "đã khớp tiền" của FIN_L1** (REQ-FIN-006 — điều kiện tiên quyết, không vai nào override kể cả CEO) và luồng duyệt SoD 4 vai (người tạo ≠ người duyệt ≠ người thực hiện chi) theo ngưỡng 5/50/200 triệu VND + delegate (REQ-FIN-008); GW không phải nơi xác nhận khớp tiền — chỉ kiểm tra dấu hiệu duyệt trên payload | Lô chứa dòng giải ngân chưa qua Hard Stop/duyệt → từ chối cả lô `HARD_STOP_NOT_SATISFIED`, không xuất một phần im lặng |
| BR-ARAP-803 | Dữ liệu công nợ AR/AP + aging + nhắc nợ (REQ-FIN-007) được GW đồng bộ sang VAS để hai bên cùng nhìn một nguồn: aging theo bucket 0–30/31–60/61–90/>90 ngày, nhắc nợ do CORE sinh — GW chỉ mirror kèm nhãn nguồn, không tự tính lại aging, không tự gửi nhắc ngoài lịch CORE. Assumption `[KXN-22]` (còn mở — KHÔNG tự quyết): mốc "15 ngày → PAUSE" non-payment do khách hàng chốt; nếu áp, GW chỉ vận chuyển trạng thái PAUSE do CORE phát, không tự khóa TKQC | Phát hiện aging tự tính tại GW → chặn `SOURCE_OF_TRUTH_VIOLATION`; mirror thiếu nhãn nguồn → job toàn vẹn báo lỗi |
| BR-ARAP-804 | Connector vendor-agnostic theo DI-004 (12/09): GW thực thi connection profile + field mapping được cấu hình tại MOD-SETTINGS-GW (kết nối ngoại vi) — adapter API cắm được hoặc import/export chuẩn schema; không hardcode tên vendor trong code; credentials chỉ lấy runtime từ vault REQ-BOD-008, không bao giờ hiển thị plaintext ở log/UI/payload | Không có profile `ACTIVE` → từ chối `CONNECTION_NOT_CONFIGURED`; phát hiện secret trong log → chặn + alert bảo mật |
| BR-ARAP-805 | Gói HĐĐT chuẩn XML theo TT78/2021 + NĐ123/2020 đi qua **cùng luồng kết nối VAS** (kết nối gửi cơ quan thuế dùng chung REQ-FIN-013); GW chỉ vận chuyển nguyên vẹn có hash, không sinh/sửa nội dung hóa đơn; phí nền tảng & nghĩa vụ thuế trong bút toán vận chuyển giữ nguyên dẫn chiếu giao dịch gốc để CORE/VAS hạch toán đúng | Gói XML bị sửa tại GW → chặn `PAYLOAD_TAMPERED` + đối soát hash fail |
| BR-ARAP-806 | Connector fail → hàng chờ retry (backoff) → dead-letter + alert FIN_L2/BOD_CFO_CTO; mất kết nối kéo dài → **degraded mode "manual" bắt buộc**: dữ liệu đi đường tay phải gắn nhãn `manual`, khi API phục hồi GW tự backfill và báo cáo chênh lệch manual vs API (ngưỡng >±0,1% vào báo cáo đối soát theo BR-BOD-008.3); cấm "ghi sổ tay" đè lên luồng chuẩn mà không có vết | Ghi ngoài luồng không vết → từ chối `BYPASS_BLOCKED`; thiếu backfill sau phục hồi → job giám sát alert leo thang |
| BR-ARAP-807 | Legacy PMS migrate chọn lọc **một chiều**: phạm vi chỉ gồm master data + dự án active + payment history 12 tháng, phải có phê duyệt BOD_CFO_CTO; sau go-live legacy chuyển **read-only** — GW chặn mọi thao tác ghi vào legacy, chỉ giữ tra cứu qua tham chiếu; mọi bản ghi migrate giữ id mapping legacy → mới để truy vết | Cố ghi vào legacy sau go-live → chặn `LEGACY_READONLY` + log attempt; job migrate ngoài phạm vi duyệt bị từ chối |
| BR-ARAP-808 | Mọi lần gọi adapter ghi `adapter_call_log` bất biến (hướng, thời điểm, hash payload, kết quả, profile version); dữ liệu trao đổi với VAS phân loại Restricted — không trộn tenant trong một lô vận chuyển; SoD vận hành: người xử lý retry/dead-letter (SYS_ADMIN) không đồng thời là người duyệt profile (BOD_CFO_CTO) | Log thiếu hash → job toàn vẹn báo lỗi; lô trộn tenant → chặn `TENANT_MIX_BLOCKED`; vi phạm SoD → log vi phạm cho BOD |

---

## 4. Phân Quyền

> Enforce tại tầng GW; quyền duyệt nghiệp vụ (profile, phạm vi migrate) đã diễn ra trước đó tại MOD-SETTINGS-GW/CORE — bảng dưới là quyền thao tác trên touchpoint GW (console vận hành + API). Không áp dụng cho CUSTOMER — portal/mobile portal không thấy connector nội bộ.

| Hành động (GW) | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|----------------|--------|--------|-------------|-----------|
| Xem sức khỏe connector + trạng thái job | ✅ | ✅ | ✅ | ✅ (vận hành, không thấy chi tiết giá trị) |
| Xem `adapter_call_log` | ✅ | ✅ | ✅ | ❌ (meta-only, tránh lộ payload) |
| Tải file chuẩn schema đã sinh (kênh `manual`) | ✅ | ✅ | ❌ | ❌ |
| Nhập file phản hồi từ VAS (validate schema) | ✅ | ✅ | ❌ | ❌ |
| Xử lý retry / dead-letter | ❌ | ✅ (dòng nghiệp vụ) | ❌ | ✅ (kỹ thuật, sau duyệt FIN_L2 khi có giá trị) |
| Kích hoạt backfill sau sự cố | ❌ | ✅ | ✅ | ✅ (thực thi sau duyệt) |
| Duyệt phạm vi migrate legacy PMS | ❌ | ❌ | ✅ | ❌ |
| Thực thi job migrate theo phạm vi đã duyệt | ❌ | ✅ | ❌ | ✅ (vận hành) |
| Ghi/xóa/sửa payload lô xuất tại GW | ❌ | ❌ | ❌ | ❌ (GW bất khả can thiệp — chỉ CORE tạo lại) |
| Đọc credentials VAS dạng plaintext | ❌ | ❌ | ❌ (chỉ vault REQ-BOD-008) | ❌ (không ai đọc plaintext) |
| Xóa `adapter_call_log` | ❌ | ❌ | ❌ | ❌ (append-only) |

---

## 5. Trường Hợp Đặc Biệt

- **VAS chỉ hỗ trợ import/export file (không có API):** adapter dạng file chuẩn schema — GW sinh file + log lượt sinh + hash; file phản hồi từ VAS nhập qua validate schema, bản rớt vào staging kèm báo cáo, không tự sửa im lặng; kênh file được gắn nhãn và vẫn là luồng chuẩn (không phải degraded mode).
- **Mất kết nối tới VAS kéo dài (bảo trì, lỗi nhà cung cấp):** GW chuyển degraded mode — gắn nhãn `manual` cho mọi số liệu đi đường tay trong thời gian mất kết nối; hàng chờ giữ timestamp gốc; khi phục hồi, backfill tự động theo thứ tự kỳ và báo cáo chênh lệch manual vs API; FIN không được tự xuất file thay thế ngoài luồng không có vết.
- **Đổi vendor kế toán giữa chừng:** profile mới cấu hình song song tại MOD-SETTINGS-GW; GW chạy cross-check một kỳ trên hai connector trước khi cắt; connector cũ chuyển nghỉ hưu (không xóa) — lịch sử call log giữ nguyên truy vết.
- **Dữ liệu legacy không khớp cấu trúc mới (thiếu mã dự án, trùng id khách):** job migrate ghi bản rớt vào staging kèm lý do, chỉ bản ghi qua validate vào hệ thống chính; báo cáo migrate liệt kê tỉ lệ thành công/rớt cho BOD_CFO_CTO nghiệm thu trước khi chuyển legacy read-only.
- **Khóa kỳ trong khi lô đang ở hàng chờ retry:** lô giữ tham chiếu kỳ tại thời điểm tạo từ CORE; nếu kỳ bị mở lại (chỉ CFO theo REQ-BOD-010), GW không tự xuất lại — chờ CORE phát hành lô mới có hash mới, lô cũ triệt tiêu có vết.
- **Giờ cao điểm và hạn thanh toán AP:** scheduler GW chạy lô lớn ngoài giờ cao điểm; lô liên quan thanh toán AP nền tảng (tránh gián đoạn TKQC theo REQ-FIN-007) được ưu tiên trước hạn, vẫn tuân thủ điều kiện duyệt ở BR-ARAP-802.
- **Nghi ngờ rò rỉ credentials VAS:** thu hồi khẩn theo quy trình REQ-BOD-008 (revoke + rotate ≤24h); GW tạm chuyển connector sang degraded mode `manual` đến khi rotate xong — không cache secret ở bất kỳ tầng nào.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lô vận chuyển connector VAS (`export_transport_job` — thực thể phía GW; lô nghiệp vụ `export_batch` do CORE sở hữu)

**Sơ đồ trạng thái:**
```
[QUEUED] ──(scheduler lấy lô)──► [RUNNING] ──(VAS xác nhận / file ghi thành công)──► [SENT] ──(đối chiếu phản hồi khớp)──► [ACKNOWLEDGED]
                    │                     │
                    │ (profile không ACTIVE)│ (lỗi adapter/mạng)
                    ▼                     ▼
               [BLOCKED]             [RETRY] ──(quá ngưỡng)──► [DEAD_LETTER] + alert
                                             │
                                             │ (kết nối phục hồi + backfill xong)
                                             ▼
                                          [SENT]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED` | Scheduler lấy lô | `RUNNING` | Hệ thống | Profile `ACTIVE`; payload có hash CORE; qua kiểm tra BR-ARAP-801/802/805 |
| `QUEUED` | Chặn trước khi chạy | `BLOCKED` | Hệ thống | Thiếu profile/hard-stop dấu duyệt — kèm reason code |
| `RUNNING` | Adapter lỗi/mạng fail | `RETRY` | Hệ thống | Ghi lần thử + next_retry_at (backoff) |
| `RETRY` | Vượt ngưỡng retry | `DEAD_LETTER` | Hệ thống | Alert FIN_L2 + BOD_CFO_CTO bắt buộc |
| `RETRY` | Thử lại thành công | `SENT` | Hệ thống | Log call kèm hash |
| `SENT` | Phản hồi VAS khớp / backfill xong | `ACKNOWLEDGED` | Hệ thống | Đối chiếu hash/phản hồi pass |
| `DEAD_LETTER` | Xử lý xong, đưa vào lại | `SENT` | FIN_L2 (nghiệp vụ) / SYS_ADMIN (kỹ thuật) | Đã ghi lý do xử lý; không sửa payload |

**Quy tắc:**
- Không quay về `QUEUED` sau khi đã `RUNNING` — lô lỗi phải phát hành lại từ CORE (lô mới, hash mới); GW không tự sửa payload.
- `ACKNOWLEDGED` và `DEAD_LETTER` là trạng thái kết thúc phía GW; `DEAD_LETTER` chỉ thoát qua xử lý có vết.
- Trong degraded mode, mọi lô `SENT` qua kênh `manual` mang nhãn nguồn `manual` cho đến khi backfill đối soát xong.

Song song, job migrate legacy có vòng đời: `PENDING_APPROVAL` → `APPROVED` → `RUNNING` → `COMPLETED`/`COMPLETED_WITH_ERRORS` → legacy chuyển `READ_ONLY`; mọi chuyển trạng thái ghi audit log bất biến.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `export_transport_job` | `export_batch_ref`, `profile_id`, `status`, `attempts`, `next_retry_at`, `source_label` (api/manual) | FK → `export_batch` (CORE), `connection_profile` (MOD-SETTINGS-GW) | Chỉ vận chuyển lô có hash CORE |
| `connection_profile` | `id`, `adapter_type` (API/FILE), `profile_version`, `status` | Tham chiếu MOD-SETTINGS-GW | GW chỉ đọc bản `ACTIVE`; vendor-agnostic (DI-004) |
| `adapter_call_log` | `job_id`, `direction`, `called_at`, `payload_hash`, `result`, `profile_version` | FK → `export_transport_job.id` | Append-only; không chứa secret |
| `retry_queue_entry` | `job_id`, `attempt_count`, `last_error`, `dead_lettered_at` | FK → `export_transport_job.id` | Backoff; quá ngưỡng → dead-letter + alert |
| `manual_backfill_run` | `period`, `manual_records`, `api_records`, `diff_flag` (>±0,1%) | Độc lập theo kỳ | Bắt buộc sau degraded mode (DI-007, BR-BOD-008.3) |
| `legacy_migration_job` | `scope` (master data/active projects/payment history 12M), `approved_by`, `stats`, `status`, `id_mapping_ref` | Độc lập | Một chiều; legacy read-only sau go-live |
| `legacy_id_mapping` | `legacy_id`, `bcerp_id`, `entity_type` | FK → thực thể đích | Truy vết legacy → mới cho mọi bản ghi migrate |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM (dùng chung REQ-FIN-012) |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Lô thiếu dấu Hard Stop | Lô chứa dòng giải ngân TKQC chưa qua "đã khớp tiền" FIN_L1 | GW nhận lô | Từ chối cả lô `HARD_STOP_NOT_SATISFIED`, không xuất một phần | [ ] |
| SC-002: Không có profile ACTIVE | Connection profile chưa kích hoạt tại Settings-GW | Scheduler lấy lô | Lô `BLOCKED` `CONNECTION_NOT_CONFIGURED` + alert | [ ] |
| SC-003: Retry và dead-letter | Adapter trả lỗi mạng liên tục | Job xử lý qua ngưỡng retry | Lô vào `DEAD_LETTER`, alert FIN_L2 + BOD_CFO_CTO | [ ] |
| SC-004: Degraded mode + backfill | Mất kết nối VAS 3 ngày, dữ liệu đi đường tay | Kết nối phục hồi | Backfill tự động chạy, nhãn `manual` cập nhật, chênh lệch >±0,1% vào báo cáo đối soát | [ ] |
| SC-005: Secret không lộ | Credentials trong vault REQ-BOD-008 | Xem log/DBG mọi tầng | Không có plaintext ở log/UI/payload bất kỳ đâu | [ ] |
| SC-006: Legacy read-only | Migration `COMPLETED`, legacy chuyển read-only | Cố ghi vào legacy qua GW | Chặn `LEGACY_READONLY`, log attempt | [ ] |
| SC-007: HĐĐT nguyên vẹn qua luồng | Gói XML TT78/2021 từ CORE | GW vận chuyển tới VAS/cơ quan thuế | Hash đầu-cuối khớp; mọi can thiệp bị chặn `PAYLOAD_TAMPERED` | [ ] |
| SC-008: Tenant isolation | Lô chứa dòng của 2 tenant | Validate trước chạy | Chặn `TENANT_MIX_BLOCKED`, bắt tách lô theo tenant | [ ] |

> **Liên kết:** SC-001–SC-003 map REQ-FIN-013 + REQ-FIN-006/008; SC-004 map REQ-FIN-013 + DI-007/REQ-BOD-008; SC-005 map REQ-BOD-008 (cross-dependency); SC-006 map REQ-FIN-013 + DI-004; SC-007 map REQ-FIN-013 + REQ-FIN-011; SC-008 map REQ-FIN-013 + REQ-FIN-012.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (transport/retry/migrate) | `technical-specs/api-contract.md` |
| Tích hợp (adapter VAS, vault REQ-BOD-008, luồng HĐĐT dùng chung) | `technical-specs/integration-map.md` |
| Màn hình UI console GW | `phase4-ux/integration-gw/arap-payment/[screen-group].md` |
| Counterpart CORE (nguồn bút toán, đối chiếu) | `phase2-features/core-backend/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| Counterpart WEB (màn đối chiếu sổ) | `phase2-features/bcerp-web/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-013, BR-FIN-305, BR-FIN-601), `phase1-business/departments/bod/bod.md` (B8 REQ-BOD-008), `phase1-business/P1-02-business-workflow.md` (bên ngoài #6 VAS — hằng tháng; GW data plane), `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (DI-004 resolved 12/09, DI-007 theo dõi) |
