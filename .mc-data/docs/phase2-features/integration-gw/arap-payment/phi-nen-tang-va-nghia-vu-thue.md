# Tính Năng: Phí nền tảng & nghĩa vụ thuế

> **Dựa trên:** REQ-FIN-014 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Integration Gateway — Thu thập dữ liệu tài chính nền tảng (SYS-INTEGRATION-GW)
> **Module:** AR/AP Payment — Dữ liệu phí & thuế từ nền tảng (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/integration-gw/arap-payment/[screen-group].md`, `phase5-implementation/tasks/integration-gw/arap-payment/feat-gw-arap-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-ARAP-002 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-014] — liên quan: REQ-FIN-005 (statement/API 7 nền tảng — GW cấp dữ liệu), REQ-FIN-006 (Hard Stop "đã khớp tiền"), REQ-FIN-007 (AR/AP + aging + nhắc nợ), REQ-FIN-008 (duyệt chi/SoD 5/50/200 triệu + delegate), REQ-FIN-004 (snapshot tỷ giá, đối trừ 3 số), REQ-FIN-011 (HĐĐT TT78/2021 + NĐ123/2020) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (SYS_ADMIN vận hành adapter sau phê duyệt) |
| Độ ưu tiên | Trung bình (MEDIUM — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-GW-STGW-002 (API 7 nền tảng — degraded mode `manual` + backfill); counterpart FEAT-CORE-ARAP-007 (hạch toán phí/thuế); FEAT-GW-STGW-001 (GW & vault — REQ-BOD-008); statement/API sẵn sàng (REQ-FIN-005) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; A7 flag sẵn: REQ-FIN-005 phụ thuộc Business Verification API 7 nền tảng (DI-007 — chưa có quyền API developer, degraded mode bắt buộc) |

**Fan-out:** REQ-FIN-014 ở 3 systems — bản riêng cho SYS-INTEGRATION-GW; counterparts: SYS-CORE-BACKEND (FEAT-CORE-ARAP-007 — hạch toán phí, tách FCT), SYS-BCERP-WEB (màn tách bạch phí–doanh thu).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp ở tầng Integration Gateway dòng dữ liệu phí nền tảng (phí nạp, phí giao dịch, phí dịch vụ nền tảng) và dữ liệu thanh toán quốc tế phục vụ xác định nghĩa vụ thuế (VAT phí dịch vụ, thuế nhà thầu nước ngoài FCT): pull statement/API từ 7 nền tảng theo lịch, trích và chuẩn hóa từng dòng phí kèm dẫn chiếu giao dịch gốc (tx_ref), đóng gói có hash đưa về CORE hạch toán — giá vốn media và GM không bị bóp méo, mọi số liệu có nhãn nguồn (api/manual) rõ ràng.

**Phạm vi:**
- Bao gồm: pull statement/API theo lịch từ adapter 7 nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex); trích dòng phí nền tảng/phí nạp và dòng trừ phí thẳng vào ví; chuẩn hóa bản ghi phí nguyên gốc tiền tệ + amount + tx_ref (không quy đổi — quy VND do CORE theo snapshot tỷ giá REQ-FIN-004); trích dữ liệu thanh toán quốc tế phục vụ CORE hạch toán FCT theo cấu hình thuế có phê duyệt; đóng gói payload có hash + nhãn nguồn; degraded mode "manual" + backfill bắt buộc khi mất API (DI-007); log mọi lần gọi; mirror hạn thanh toán AP nền tảng phục vụ aging phía CORE; vận chuyển bút toán phí/thuế đã duyệt xuống sổ VAS qua connector dùng chung (FEAT-GW-ARAP-001).
- Không bao gồm: hạch toán phí vào giá vốn hay tách FCT (CORE — FEAT-CORE-ARAP-007); quyết định nền tảng nào chịu FCT, tỷ lệ, kỳ kê khai (cấu hình thuế có phê duyệt BOD_CFO_CTO sau xác nhận tư vấn thuế — `[CẦN CHỐT SỐ]` tại BR-FIN-602); phát hành HĐĐT và thời điểm lập hóa đơn (CORE — REQ-FIN-011, `[CẦN CHỐT SỐ]` tư vấn thuế); tính GM trên dashboard (REQ-FIN-016); lưu trữ/rotate credentials (vault REQ-BOD-008).

**Đặc thù touchpoint SYS-INTEGRATION-GW:** GW là đầu vào dữ liệu phí của toàn bộ luồng — chất lượng statement GW pull quyết định độ chính xác giá vốn/GM ở mọi tầng sau; vì Business Verification chưa cấp quyền API developer (DI-007), degraded mode "manual" là **trạng thái thiết kế bắt buộc ngay từ ngày đầu**: mọi số liệu nguồn tay gắn nhãn `manual`, khi API được cấp GW tự backfill và báo cáo chênh lệch manual vs API (>±0,1% vào báo cáo đối soát — BR-BOD-008.3); GW không hạch toán, không quy đổi tiền tệ, không phân loại thuế — chỉ thu thập, chuẩn hóa cấu trúc, đóng dấu và vận chuyển có vết.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem trạng thái pull statement/API từng nền tảng (thành công/thất bại/degraded + tuổi dữ liệu) trên console GW | Biết dữ liệu phí tươi hay đi đường tay trước khi kiểm tra bút toán |
| 2 | FIN_L1 | Nhập statement thủ công (kênh `manual`) qua luồng có validate schema khi chưa cấp API | Dữ liệu phí vẫn về đều đặn khi chưa có quyền API (DI-007) |
| 3 | FIN_L2 | Xem danh sách dòng phí chưa map giao dịch gốc (thiếu tx_ref) do GW báo về | Bắn ticket discrepancy kịp thời trước kỳ chốt |
| 4 | BOD_CFO_CTO | Duyệt tham số pull (lịch, phạm vi loại phí, phạm vi thanh toán quốc tế) và cấu hình thuế | Thu thập đúng phạm vi đã quyết, thuế không quyết miệng |
| 5 | SYS_ADMIN | Vận hành adapter: xử lý retry, kích hoạt backfill sau sự cố theo profile đã duyệt | Sự cố được khắc phục không đụng cấu hình nghiệp vụ |
| 6 | Hệ thống (scheduler GW) | Tự pull theo lịch, gắn nhãn nguồn api/manual, tự backfill khi API phục hồi | Tầng sau luôn biết số liệu đang dùng nguồn nào |
| 7 | FIN_L2 | Nhận alert khi chênh lệch manual vs API vượt >±0,1% sau backfill | Phát hiện lệch số kênh tay ngay khi có số chuẩn |
| 8 | FIN_L1 | Theo dõi mirror hạn thanh toán AP nền tảng do GW đồng bộ | Kịp nhắc duyệt chi trước hạn, không gián đoạn TKQC |

**Diễn giải luồng chính (adapter layer):** (1) scheduler GW pull statement/API theo lịch (hoặc nhận statement tay qua luồng `manual` có validate); (2) GW chuẩn hóa từng dòng phí: nguyên gốc currency + amount + tx_ref + evidence hash — không quy đổi, không phân loại; (3) dòng thiếu tx_ref gắn cờ `UNMAPPED_FEE` vẫn gửi về CORE (CORE bắn ticket discrepancy theo BR-FIN-202, GW không tự hủy dòng); (4) dòng thanh toán quốc tế (nhà thầu nước ngoài) trích riêng theo phạm vi cấu hình để CORE đối chiếu cấu hình thuế FCT hiệu lực tại thời điểm giao dịch; (5) payload có hash + nhãn nguồn, ghi `adapter_call_log`, đẩy về CORE; (6) pull fail → retry/backoff → quá ngưỡng dead-letter + alert; mất API kéo dài → degraded mode `manual`, khi phục hồi GW backfill kỳ trễ và đối soát manual vs API; (7) bút toán phí/thuế đã duyệt đi xuống sổ VAS qua connector dùng chung FEAT-GW-ARAP-001.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng adapter/gateway.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-901 | GW cấp dữ liệu phí từ statement/API theo REQ-FIN-005: mọi dòng phí giữ nguyên gốc currency + amount + tx_ref + evidence hash — **GW không quy VND, không phân loại giá vốn/doanh thu/thuế**; quy VND dùng snapshot tỷ giá chung và phân loại là việc của CORE (REQ-FIN-004/BR-FIN-203, FEAT-CORE-ARAP-007) | Quy đổi/phân loại tại GW → chặn `SCOPE_VIOLATION` + log; payload thiếu evidence → từ chối đẩy về CORE |
| BR-ARAP-902 | Dòng phí phải map về giao dịch gốc (top-up, lệnh chi, TKQC); GW gắn tx_ref khi statement cung cấp — thiếu tx_ref gắn cờ `UNMAPPED_FEE` và vẫn gửi về CORE (không tự hủy, không tự đoán); dòng trừ phí thẳng vào ví được trích như một dòng chi tiêu, không ghi thành doanh thu âm | Dòng `UNMAPPED_FEE` → CORE sinh ticket discrepancy (BR-FIN-202), không vào báo cáo GM đến khi giải trình |
| BR-ARAP-903 | Dữ liệu thanh toán quốc tế phục vụ nghĩa vụ thuế: GW trích dòng thanh toán nhà thầu nước ngoài theo phạm vi cấu hình thuế **có phê duyệt BOD_CFO_CTO** (nền tảng nào chịu FCT, tỷ lệ, kỳ kê khai — `[CẦN CHỐT SỐ]` xác nhận với tư vấn thuế theo BR-FIN-602; nền tảng có pháp nhân VN thu bằng hóa đơn VN → không áp FCT); GW không tự kết luận nghĩa vụ thuế — chỉ cung cấp dữ liệu nguyên trạng để CORE đối chiếu cấu hình | Trích ngoài phạm vi hiệu lực → từ chối `TAX_SCOPE_NOT_CONFIGURED`; cấu hình hết hạn → `PENDING_CONFIG` + alert |
| BR-ARAP-904 | **Financial Hard Stop "đã khớp tiền" của FIN_L1** (REQ-FIN-006 — xác nhận trên WEB với MFA, không vai nào override kể cả CEO) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC mà GW vận chuyển: dòng thanh toán nền tảng/quốc tế phải phát sinh từ lệnh đã qua duyệt SoD 4 vai (người tạo ≠ người duyệt ≠ người thực hiện chi) theo ngưỡng 5/50/200 triệu VND + delegate (REQ-FIN-008); GW kiểm tra dấu hiệu duyệt trên payload, không phải nơi xác nhận khớp tiền | Thiếu dấu hiệu Hard Stop/duyệt → từ chối `HARD_STOP_NOT_SATISFIED`, toàn lô giữ lại có vết |
| BR-ARAP-905 | Degraded mode "manual" bắt buộc (DI-007 — chưa có quyền API developer 7 nền tảng): mọi dữ liệu nguồn tay gắn nhãn `manual`; khi API được cấp/phục hồi, GW **backfill tự động** toàn bộ kỳ trễ và đối soát manual vs API — chênh lệch >±0,1% vào báo cáo đối soát (BR-BOD-008.3); cấm ghi dữ liệu tay đè luồng chuẩn mà không có nhãn và vết | Dữ liệu tay thiếu nhãn → `UNLABELED_SOURCE`; thiếu backfill sau phục hồi → alert leo thang FIN_L2/BOD |
| BR-ARAP-906 | Mirror công nợ AP nền tảng + aging (REQ-FIN-007): GW đồng bộ hạn thanh toán/dòng công nợ về CORE để theo dõi aging bucket 0–30/31–60/61–90/>90 ngày và nhắc thanh toán AP trước hạn — GW chỉ mirror có nhãn nguồn, không tự tính aging, không tự gửi nhắc; mốc "15 ngày → PAUSE" non-payment là `[KXN-22]` còn mở — KHÔNG tự quyết, GW chỉ vận chuyển trạng thái do CORE phát | Aging/nhắc tự tính tại GW → chặn `SOURCE_OF_TRUTH_VIOLATION`; mirror thiếu nhãn → job toàn vẹn báo lỗi |
| BR-ARAP-907 | Gói HĐĐT TT78/2021 + NĐ123/2020 và bút toán phí/thuế đi xuống sổ VAS qua **connector dùng chung** (FEAT-GW-ARAP-001 — cấu hình kết nối ngoại vi tại MOD-SETTINGS-GW theo DI-004 12/09, vendor-agnostic); GW vận chuyển nguyên vẹn có hash, chỉ từ chứng từ đã duyệt/khóa kỳ | Can thiệp XML/bút toán tại GW → chặn `PAYLOAD_TAMPERED`; lô chưa khóa kỳ bị giữ `EXPORT_HELD` |
| BR-ARAP-908 | Mọi lần pull/import/đóng gói ghi `adapter_call_log` bất biến (nguồn, thời điểm, hash, nhãn nguồn, kết quả); dữ liệu phí phân loại Restricted — không trộn tenant trong một payload; SoD: người nhập statement tay không đồng thời là người đối trừ/điều chỉnh số sau backfill | Log thiếu hash/nhãn → job toàn vẹn báo lỗi; payload trộn tenant → chặn `TENANT_MIX_BLOCKED`; vi phạm SoD → log cho BOD rà |

---

## 4. Phân Quyền

> Enforce tại tầng GW (console vận hành + API); quyền duyệt tham số pull/cấu hình thuế thuộc luồng phê duyệt trước đó (BOD_CFO_CTO); CUSTOMER không thấy bất kỳ màn GW nào — portal chỉ nhận view tài chính đã lọc (phạm vi khác).

| Hành động (GW) | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|----------------|--------|--------|-------------|-----------|
| Xem trạng thái pull + tuổi dữ liệu từng nền tảng | ✅ | ✅ | ✅ | ✅ (vận hành, không thấy giá trị) |
| Xem `adapter_call_log` | ✅ | ✅ | ✅ | ❌ (meta-only) |
| Nhập statement thủ công (kênh `manual`) | ✅ | ✅ | ❌ | ❌ |
| Đề xuất tham số pull (lịch, phạm vi loại phí, phạm vi FCT) | ❌ | ✅ | ✅ | ❌ |
| Duyệt tham số pull / cấu hình thuế (ban hành) | ❌ | ❌ | ✅ | ❌ |
| Kích hoạt tham số sau duyệt | ❌ | ❌ | ❌ | ✅ (thực thi sau duyệt) |
| Xử lý retry / dead-letter | ❌ | ✅ (nghiệp vụ) | ❌ | ✅ (kỹ thuật, sau duyệt FIN_L2) |
| Kích hoạt backfill sau sự cố/phục hồi API | ❌ | ✅ | ✅ | ✅ (thực thi sau duyệt) |
| Xem báo cáo chênh lệch manual vs API | ✅ | ✅ | ✅ | ❌ |
| Sửa/phân loại dòng phí tại GW | ❌ | ❌ | ❌ | ❌ (bất khả can thiệp — phân loại thuộc CORE) |
| Đọc credentials nền tảng dạng plaintext | ❌ | ❌ | ❌ (chỉ vault REQ-BOD-008) | ❌ (không ai đọc plaintext) |
| Xóa log pull/import | ❌ | ❌ | ❌ | ❌ (append-only) |

---

## 5. Trường Hợp Đặc Biệt

- **Nền tảng chưa cấp quyền API developer (DI-007 — trạng thái hiện tại của cả 7 nền tảng):** GW chạy degraded mode có kiểm soát: statement tải tay nhập qua luồng `manual` có validate schema, gắn nhãn nguồn `manual`; đây là trạng thái vận hành chính thức giai đoạn đầu — khi được cấp quyền, GW bật adapter API và backfill tự động, không đổi luồng.
- **Backfill phát hiện chênh lệch manual vs API >±0,1%:** GW báo cáo từng dòng lệch kèm hai giá trị và kỳ phát sinh; số chuẩn API là nguồn đối chiếu — điều chỉnh chỉ ở CORE qua reversal có reason code; GW không ghi đè dữ liệu đã gửi.
- **Nền tảng trừ phí thẳng vào số dư ví (không có dòng phí riêng trên statement):** GW trích dòng trừ phí như một dòng chi tiêu kèm tx_ref khớp statement (đối trừ 3 số REQ-FIN-004); dòng không khớp → gắn cờ để CORE sinh ticket discrepancy, không tự nhận diện im lặng.
- **Nền tảng chốt phí sau giao dịch gốc (statement đến trễ):** GW gửi dữ liệu phí bổ sung theo kỳ statement, giữ dẫn chiếu tx_ref cũ; nếu kỳ đã khóa thì CORE xử lý qua reversal có duyệt — GW không sửa payload kỳ cũ.
- **Thanh toán quốc tế cho nhà thầu có và không có pháp nhân VN lẫn trong cùng kỳ:** GW trích theo cấu hình thuế hiệu lực từng thời điểm (effective-dated); dòng nền tảng có hóa đơn VN gắn cờ `NO_FCT` theo cấu hình, không áp thuế nhà thầu — kết luận ghi trong cấu hình đã duyệt, không quyết miệng.
- **Statement trễ kéo dài vào sát kỳ chốt:** scheduler tăng tần suất retry leo thang; FIN_L2 nhận cảnh báo "tuổi dữ liệu nền tảng X đã N giờ/ngày" để quyết định chờ hay chốt kèm ghi chú nguồn chưa đủ — quyết định chốt thuộc CORE/CFO.
- **Statement định dạng đổi giữa chừng (nền tảng nâng cấp portal):** validate schema chặn bản rớt vào staging kèm báo cáo; field mapping cập nhật qua MOD-SETTINGS-GW (DI-004 — vendor-agnostic, không sửa code GW); khi chờ profile mới, kênh `manual` giữ luồng không đứt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lượt thu thập dữ liệu phí (`fee_collection_run` — lượt pull/nhận statement thủ công của một nền tảng trong một kỳ)

**Sơ đồ trạng thái:**
```
[SCHEDULED] ──(scheduler / upload manual)──► [RUNNING] ──(parse + validate OK)──► [COLLECTED] ──(CORE nhận, hash khớp)──► [DELIVERED]
                  │                      │                     │
                  │ (adapter lỗi)         │ (schema rớt)         │ (lệch backfill >±0,1%)
                  ▼                      ▼                     ▼
              [RETRY] ──(quá ngưỡng)──► [DEAD_LETTER]      [FLAGGED] ──(CORE giải trình xong)──► [DELIVERED]
                  │
                  │ (mất API kéo dài)
                  ▼
          [DEGRADED_MANUAL] ──(API phục hồi + backfill xong)──► [BACKFILLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `SCHEDULED` | Scheduler khởi chạy / nhận upload manual | `RUNNING` | Hệ thống / FIN_L1·L2 (manual) | Adapter hiệu lực hoặc luồng manual mở |
| `RUNNING` | Lỗi mạng/adapter | `RETRY` | Hệ thống | Ghi lần thử + next_retry_at (backoff) |
| `RUNNING` | Schema rớt validate | `FLAGGED` | Hệ thống | Bản rớt vào staging kèm báo cáo lỗi |
| `RETRY` | Vượt ngưỡng retry | `DEAD_LETTER` | Hệ thống | Alert FIN_L2 + BOD_CFO_CTO bắt buộc |
| `RETRY` | Mất API kéo dài | `DEGRADED_MANUAL` | Hệ thống | Nhãn `manual` áp cho kỳ bị trễ |
| `DEGRADED_MANUAL` | API phục hồi, backfill xong | `BACKFILLED` | Hệ thống | Đối soát manual vs API xong; lệch >±0,1% vào báo cáo |
| `COLLECTED` | CORE xác nhận hash khớp | `DELIVERED` | Hệ thống | Payload nguyên vẹn, có nhãn nguồn |
| `FLAGGED` | CORE giải trình xong | `DELIVERED` | Hệ thống | Ticket discrepancy đóng có lý do |

**Quy tắc:**
- Không quay về `SCHEDULED` sau khi đã `RUNNING` — lượt lỗi đi qua `RETRY`/`DEAD_LETTER` hoặc lượt mới.
- `DELIVERED`, `DEAD_LETTER`, `BACKFILLED` là trạng thái kết thúc; `DEAD_LETTER` chỉ thoát qua xử lý có vết của FIN_L2/SYS_ADMIN.
- Nhãn nguồn (api/manual) đi theo payload đến tận CORE; đổi nhãn tại GW bị cấm.

Song song, tham số pull/cấu hình thuế có vòng đời riêng tại MOD-SETTINGS-GW/CORE: `DRAFT` → `APPROVED` (BOD_CFO_CTO) → `ACTIVE` → `SUSPENDED`/`RETIRED` — GW chỉ đọc bản `ACTIVE`.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `fee_collection_run` | `platform`, `period`, `mode` (api/manual), `status`, `record_count`, `source_label` | Độc lập theo nền tảng/kỳ | Nhãn nguồn bắt buộc |
| `fee_line` | `platform`, `currency`, `amount_original`, `tx_ref`, `fee_type`, `unmapped_flag`, `evidence_hash` | FK → `fee_collection_run.id`; tx_ref → giao dịch CORE | Nguyên gốc tiền tệ — không quy đổi tại GW |
| `intl_payment_line` | `platform`, `counterparty_country`, `currency`, `amount`, `tax_config_ref`, `no_fct_flag` | FK → `fee_collection_run.id`, `tax_config` | CORE hạch toán FCT theo cấu hình duyệt |
| `manual_backfill_run` | `period`, `platform`, `manual_total`, `api_total`, `diff_pct`, `report_ref` | FK → `fee_collection_run.id` | Bắt buộc sau degraded mode; ngưỡng >±0,1% |
| `adapter_call_log` | `run_id`, `direction`, `called_at`, `payload_hash`, `result`, `profile_version` | FK → `fee_collection_run.id` | Append-only; không chứa secret |
| `staging_record_error` | `run_id`, `raw_ref`, `error_code`, `reason` | FK → `fee_collection_run.id` | Bản rớt validate — giải trình, không tự sửa |
| `connection_profile` | `id`, `adapter_type`, `field_mapping_ref`, `status`, `profile_version` | Tham chiếu MOD-SETTINGS-GW | Vendor-agnostic (DI-004); GW chỉ đọc bản `ACTIVE` |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM (REQ-FIN-012) |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Dữ liệu tay luôn có nhãn | Nền tảng chưa cấp API (DI-007) | FIN_L1 nhập statement qua luồng manual | Dữ liệu `COLLECTED`/`DELIVERED` mang nhãn `manual` mọi tầng | [ ] |
| SC-002: Backfill sau khi có API | Kỳ 07 chạy manual, tháng 08 được cấp API | Adapter bật, backfill chạy | Kỳ 07 pull lại, đối soát manual vs API, lệch >±0,1% vào báo cáo | [ ] |
| SC-003: Không quy đổi tại GW | Statement chứa USD/EUR | GW chuẩn hóa | `fee_line` giữ currency + amount gốc; quy VND chỉ ở CORE theo snapshot tỷ giá | [ ] |
| SC-004: Phí thiếu tx_ref | Dòng phí không map giao dịch | GW xử lý | Cờ `UNMAPPED_FEE`, vẫn gửi CORE, ticket discrepancy sinh ở CORE | [ ] |
| SC-005: FCT theo cấu hình | Cấu hình thuế chưa phủ nền tảng X | Dòng thanh toán quốc tế X | Từ chối `TAX_SCOPE_NOT_CONFIGURED` + alert; không tự kết luận thuế | [ ] |
| SC-006: Hard Stop trên payload | Lô chứa dòng chưa qua "đã khớp tiền" FIN_L1 | GW kiểm tra trước vận chuyển | Từ chối `HARD_STOP_NOT_SATISFIED`, toàn lô giữ lại có vết | [ ] |
| SC-007: Statement đổi định dạng | Nền tảng nâng cấp portal, schema đổi | Lượt pull mới chạy | Bản rớt vào staging kèm báo cáo; luồng manual giữ luồng không đứt | [ ] |
| SC-008: SoD kênh manual | Người nhập tay tự điều chỉnh số sau backfill | Cố thao tác | Từ chối + log vi phạm SoD cho BOD | [ ] |

> **Liên kết:** SC-001–SC-002 map REQ-FIN-014 + REQ-FIN-005/DI-007; SC-003–SC-004 map REQ-FIN-014 (BR-FIN-306); SC-005 map REQ-FIN-014 + BR-FIN-602 (`[CẦN CHỐT SỐ]` tư vấn thuế); SC-006 map REQ-FIN-014 + REQ-FIN-006/008; SC-007 map DI-004; SC-008 map REQ-FIN-004.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (pull/dispatch/backfill) | `technical-specs/api-contract.md` |
| Tích hợp (statement 7 nền tảng, luồng FCT, connector VAS) | `technical-specs/integration-map.md` |
| Màn hình UI console GW | `phase4-ux/integration-gw/arap-payment/[screen-group].md` |
| Counterpart CORE (hạch toán phí/thuế) | `phase2-features/core-backend/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` |
| Counterpart WEB (tách bạch phí–doanh thu) | `phase2-features/bcerp-web/arap-payment/phi-nen-tang-va-nghia-vu-thue.md` |
| Tính năng GW liên quan (connector VAS) | `phase2-features/integration-gw/arap-payment/tich-hop-phan-mem-ke-toan-vas-hien-huu.md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-014, BR-FIN-306, BR-FIN-601/602), `phase1-business/departments/bod/bod.md` (B8 REQ-BOD-008, BR-BOD-008.3), `phase1-business/P1-02-business-workflow.md` (Luồng 2 — pull hourly, nhãn manual khi degraded), `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (DI-007, DI-004 resolved 12/09) |
