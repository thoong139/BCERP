# Tính Năng: Dữ liệu ví read-only cho Client Portal

> **Dựa trên:** REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (Phần A — Mục REQ-FIN-017; Phần B — BR-FIN-603)
> **Phân hệ:** Client Portal (SYS-PORTAL-WEB)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md` (B.5), `phase1-business/P1-02-business-workflow.md` (Luồng 2)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/client-portal/*.md`, `phase5-implementation/tasks/portal-web/client-portal/feat-cport-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-CPORT-001 |
| Module | MOD-CLIENT-PORTAL |
| Yêu cầu nghiệp vụ | [REQ-FIN-017 (chính), REQ-OPS-010 (phụ thuộc chéo — portal share model chung)] |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER), FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình (MEDIUM) |
| Giai đoạn | Giai đoạn 3 (GĐ3) |
| Phụ thuộc | View ví lọc tenant trên SYS-CORE-BACKEND (counterpart REQ-FIN-017); tài khoản portal đã kích hoạt theo FEAT-PORTAL-CPORT-002 |
| Ghi chú Expert (A7) | A7 trong `finance.md` chưa được expert review — chưa có điều chỉnh A7 nào áp dụng tại thời điểm viết |

> **Fan-out:** REQ-FIN-017 có ở 2 systems; file này là bản riêng cho **SYS-PORTAL-WEB**, counterpart (view lọc tenant, mask tầng API, RLS) thuộc **SYS-CORE-BACKEND**.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho khách hàng (CUSTOMER) tự xem số dư ví TKQC, chi tiêu daily và trạng thái đối soát mức khách ngay trên Client Portal — trụ cột minh bạch dữ liệu, khách không phải hỏi AM mỗi lần cần con số. Tính năng chỉ hiển thị dữ liệu read-only đã được chia sẻ có chủ đích, với tenant isolation tuyệt đối: không lộ giá vốn, chiết khấu, P&L hay dữ liệu nội bộ khác.

**Phạm vi:**
- Bao gồm:
  - Trang ví read-only trên Portal Web: số dư theo TKQC, chi tiêu daily theo TK/campaign, trạng thái đối soát mức khách, lịch nạp (đã thực hiện + kế hoạch cam kết).
  - Bản rút gọn Mobile BC Portal (dùng chung view): số dư, thông báo, ticket.
  - Cơ chế hiển thị an toàn: disclaimer độ trễ + timestamp bắt buộc, mask giá vốn thành "Điều chỉnh đối soát", watermark download, log truy cập/download bất biến.
- Không bao gồm:
  - Mọi thao tác ghi lên dữ liệu tài chính (lệnh nạp/rút/điều chỉnh) — thuộc phân hệ ví nội bộ (REQ-FIN-001/002/003); Portal read-only tuyệt đối.
  - Cấp/kích hoạt tài khoản portal và monitor adoption — FEAT-PORTAL-CPORT-002 (REQ-OPS-010).
  - Xây view lọc tenant, RLS, mask tầng API — counterpart CORE; Portal chỉ tiêu thụ view qua Portal API Gateway riêng.
  - Dashboard BI/P&L nội bộ (REQ-FIN-016) — biên tin cậy nội bộ, khách không xem.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Xem số dư ví theo từng TKQC kèm thời điểm cập nhật cuối | Tự nắm tình hình tiền nạp, không phải hỏi AM |
| 2 | CUSTOMER (CLIENT_USER) | Xem chi tiêu daily theo TK/campaign với nhãn nguồn + độ trễ | Đối chiếu hiệu quả campaign với ngân sách đã nạp |
| 3 | CUSTOMER (CLIENT_ADMIN) | Xem lịch nạp gồm lần đã nạp và kế hoạch nạp cam kết | Chủ động kế hoạch dòng tiền phía khách |
| 4 | CUSTOMER (CLIENT_ADMIN) | Xuất dữ liệu ví kèm watermark (tên user + thời điểm) | Chia sẻ nội bộ khách mà vẫn truy vết được nguồn rò rỉ |
| 5 | CUSTOMER (CLIENT_USER) | Thấy giao dịch tranh chấp hiển thị "Đang đối soát" + số tham chiếu | Hiểu đó chưa phải số chính thức, chờ kết quả đối soát |
| 6 | CUSTOMER (CLIENT_USER) | Phản đối một con số bằng cách tạo ticket gắn đúng giao dịch | Vào queue hợp nhất (REQ-OPS-009), bắt đầu đối soát |
| 7 | CUSTOMER (CLIENT_ADMIN) | Mở Mobile BC Portal rút gọn xem số dư, thông báo, ticket | Theo dõi khi không có máy tính |
| 8 | FIN_L1 | Duyệt bộ trường được chia sẻ ra view portal (trên WEB nội bộ — counterpart CORE) | Kiểm soát ranh giới khách thấy/không thấy |
| 9 | FIN_L2 | Tra cứu log truy cập/download bất biến khi có khiếu nại rò rỉ | Điều tra theo quy trình Restricted data (BR-FIN-603) |
| 10 | BOD_CFO_CTO | Xem báo cáo tổng hợp chia sẻ dữ liệu portal, review ma trận hằng quý | Bảo đảm biên tin cậy đối ngoại đúng policy minh bạch — bảo mật |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — enforce chính ở service layer SYS-CORE-BACKEND (counterpart); SYS-PORTAL-WEB không chống lệnh thay backend bằng UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Portal hiển thị ví **read-only tuyệt đối**: không có endpoint ghi nào lên dữ liệu tài chính; mọi thay đổi số dư chỉ do nội bộ theo policy ví (REQ-FIN-001/002) | API trả 403 + log truy cập bất thường; UI không tồn tại nút thao tác |
| BR-002 | **Tenant isolation 2 lớp**: RLS PostgreSQL + filter `tenant_id` tầng API; Portal chỉ gọi Portal API Gateway riêng (tách network zone), chỉ đọc qua view tổng hợp đã lọc — không chạm DB nội bộ | Thiếu `tenant_id` bị từ chối ở tầng service; cố truy cập chéo tenant → khóa phiên + alert bảo mật |
| BR-003 | **Ranh giới dữ liệu**: khách THẤY số dư theo TK, chi tiêu daily, trạng thái đối soát mức khách, lịch nạp; KHÔNG THẤY giá vốn, chiết khấu, P&L, tỷ giá nội bộ, dữ liệu tenant khác, ghi chú nội bộ, health score/churn | Mask thực thi tầng API: trường giá vốn trả nhãn "Điều chỉnh đối soát" — không chỉ ẩn ở UI |
| BR-004 | **Disclaimer độ trễ + timestamp bắt buộc**: số dư 15 phút–24h ("số dư tham chiếu; số chính thức theo đối soát cuối ngày với platform"); chi tiêu daily 3–24h ("platform có thể điều chỉnh hồi tố theo timezone"); lịch nạp realtime | Component không render khi thiếu freshness metadata |
| BR-005 | **Watermark + log download**: mọi xuất/download gắn watermark tên user + thời điểm; log append-only | Không tạo được watermark → chặn xuất; log thiếu bản ghi → fail audit toàn vẹn |
| BR-006 | Dữ liệu ví/lệnh/đối soát là mức **Restricted** (BR-FIN-603, PDPA): mã hóa lưu/truyền, log truy cập bất biến, review ma trận hằng quý, offboard thu hồi quyền trong 24h | Truy cập ngoài ma trận bị từ chối; điều tra cần phê duyệt BOD_CEO + meta-log theo thời hạn phiếu |
| BR-007 | Số tranh chấp hiển thị **"Đang đối soát"** + số tham chiếu, không hiện như số chính thức | Hiện số tranh chấp như số chốt → cảnh báo FIN_L1, sửa ngay |
| BR-008 | Khách đa nhãn hàng: mỗi pháp nhân/nhãn hàng **1 tenant riêng**, không chia sẻ chéo; một user chỉ thuộc 1 tenant | Gộp tenant bị chặn ở tầng service, không chỉ ẩn menu |
| BR-009 | Số dư hiển thị theo loại tiền của lệnh nạp; snapshot tỷ giá nội bộ (hoạch định) không hiển thị | Yêu cầu tỷ giá nội bộ bị từ chối ở tầng API |
| BR-010 | Cảnh báo chậm nạp/sắp PAUSE hiển thị theo mốc đề xuất 15/30 ngày — **mức đề xuất chờ khách hàng xác nhận** `[KXN-22]`, đưa vào cấu hình, không hardcode | Sai mốc chốt → chỉnh tại cấu hình, không deploy lại |
| BR-011 | Portal là **điểm phát hiện sự cố phía khách** (BR-FIN-604): báo cáo sự cố vào incident intake CORE, timer 72h theo NĐ 13/2023 + GDPR/DPA | Không đẩy intake trong 4h đầu → vi phạm SLA nội bộ xử lý sự cố |

---

## 4. Phân Quyền

> Touchpoint **SYS-PORTAL-WEB** (khách hàng). FIN_L1/FIN_L2/BOD_CFO_CTO không dùng portal — các vai này thao tác định nghĩa view/mask và tra cứu log trên WEB nội bộ (counterpart REQ-FIN-017 của CORE/WEB).

| Hành động | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Xem số dư ví tenant mình (read-only) | ✅ | ✅ | ❌ (WEB nội bộ) | ❌ (WEB nội bộ) | ❌ (BI) |
| Xem chi tiêu daily theo TK/campaign | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem lịch nạp + kế hoạch cam kết | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xuất dữ liệu có watermark | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo ticket phản đối số liệu | ✅ | ✅ | ❌ | ❌ | ❌ |
| Thấy dữ liệu tenant khác | ❌ | ❌ | ❌ | ❌ | ❌ |
| Định nghĩa/duyệt bộ trường chia sẻ ra view | ❌ | ❌ | ✅ (WEB nội bộ) | ✅ (rà soát) | ❌ |
| Tra cứu log truy cập/download | ❌ | ❌ | ✅ (khách được gán) | ✅ (toàn bộ) | ✅ (tổng hợp) |
| Phê duyệt truy cập điều tra ngoài ma trận | ❌ | ❌ | ❌ | ❌ (đề xuất) | ✅ (BOD_CEO duyệt) |

Quy tắc bổ sung: mọi hành động xem/xuất của CUSTOMER bị chặn nếu session hết hạn hoặc 2FA chưa bật (FEAT-PORTAL-CPORT-002); FIN_L2 xem full dữ liệu khách chỉ phục vụ điều tra, mỗi lần xem bị meta-log theo BR-FIN-502.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách đa nhãn hàng/nhiều pháp nhân:** mỗi pháp nhân 1 tenant riêng, view lọc độc lập; muốn gộp xem phải đăng nhập riêng từng tenant — không gộp dữ liệu chéo.
- **Platform điều chỉnh hồi tố** (timezone khác VN): chi tiêu daily kèm disclaimer hồi tố; số đã chốt đối soát cuối ngày được ghim làm mốc tham chiếu.
- **Nguồn degraded/manual** (nền tảng chưa cấp quyền API — theo dõi DI-007): hiển thị kèm nhãn nguồn + timestamp; không hiện số cũ như số mới.
- **User bị khóa/thu hồi giữa phiên:** session vô hiệu ngay tại request kế tiếp; log ghi nhận thời điểm hết hiệu lực phục vụ điều tra.
- **Khách EU/US:** DPA phải ký trước kích hoạt; tenant chưa có cờ "DPA signed" không thấy dữ liệu ví (chặn tầng API — BR-FIN-605).
- **Hành vi bất thường** (quét dữ liệu, download hàng loạt, thử chéo tenant): rate limit + alert bảo mật; lặp lại → khóa phiên, escalate SYS_ADMIN/FIN_L2.
- **Cảnh báo chậm nạp:** mốc 15/30 ngày là đề xuất `[KXN-22]` chờ xác nhận — trước khi chốt, portal hiển thị thông báo trung tính "Ví sắp đạt ngưỡng theo lịch nạp cam kết", không cảnh báo PAUSE cứng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> Entity có trạng thái là **trạng thái đối soát của giao dịch/nhãn ví** hiển thị trên portal. Portal chỉ **hiển thị** — mọi chuyển đổi do SYS-CORE-BACKEND thực hiện theo quy trình đối soát (REQ-FIN-004); Portal không có hành động chuyển trạng thái.

**Entity:** Giao dịch ví / trạng thái đối soát (hiển thị read-only)

**Sơ đồ trạng thái:**
```
[PENDING] ──(đối soát khớp)──► [MATCHED]
    │                              │
    │ (phát hiện lệch)             │ (khách phản đối / lệch mới)
    ▼                              ▼
[DISPUTED] ◄────────────────── [DISPUTED]
    │
    │ (biên bản điều chỉnh có giá vốn → mask)
    ▼
[ADJUSTED — hiển thị "Điều chỉnh đối soát"]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Đối soát khớp statement/API | `MATCHED` | Hệ thống (CORE) | Dung sai đối soát đạt theo cấu hình |
| `PENDING` | Phát hiện lệch | `DISPUTED` | Hệ thống (CORE) / FIN_L1 | Chênh lệch vượt dung sai |
| `MATCHED` | Khách phản đối số liệu | `DISPUTED` | CUSTOMER (tạo ticket) | Ticket vào queue hợp nhất, AM khởi tạo đối soát |
| `DISPUTED` | Chốt điều tra có điều chỉnh | `ADJUSTED` | FIN_L1 xác nhận, FIN_L2 rà | Biên bản đối soát; giá vốn mask "Điều chỉnh đối soát" |
| `DISPUTED` | Xác nhận số gốc đúng | `MATCHED` | FIN_L1 | Kết luận đối soát ghi hồ sơ |

**Quy tắc:**
- Portal không thực thi chuyển đổi nào — mọi transition xảy ra ở CORE, portal nhận qua view kèm freshness metadata (BR-004).
- `DISPUTED` bắt buộc hiển thị kèm số tham chiếu đối soát (BR-007).
- `ADJUSTED` là trạng thái kết thúc của giao dịch; điều chỉnh tiếp theo phát sinh giao dịch mới (ledger append-only).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính — chi tiết DDL đầy đủ tại `database-design.md`. View portal là bản đọc; ledger/statement thuộc phân hệ ví trên CORE.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `portal_wallet_view` | `tenant_id`, `adaccount_id`, `balance`, `currency`, `spend_daily`, `recon_status`, `source_label`, `freshness_ts` | Filter bắt buộc `tenant_id` | View tổng hợp lọc — read-only, không chạm DB nội bộ |
| `tenant` | `id`, `legal_name`, `contract_no`, `dpa_signed`, `user_quota` | 1 tenant — nhiều portal user | Mỗi pháp nhân/nhãn hàng 1 tenant |
| `wallet_transaction` (nguồn CORE) | `id`, `tenant_id`, `adaccount_id`, `type`, `amount`, `currency`, `fx_snapshot`, `recon_status` | Append-only ledger | Portal chỉ đọc qua view; `fx_snapshot` không xuất portal (BR-009) |
| `portal_access_log` | `user_id`, `tenant_id`, `action`, `resource`, `ts`, `ip` | FK → `portal_user` | Append-only, hash-chain (BR-FIN-501/603) |
| `portal_download_log` | `user_id`, `tenant_id`, `resource`, `watermark_text`, `ts` | FK → `portal_user` | Ghi mọi lần xuất có watermark (BR-005) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — test được. Chi tiết hóa ở Phase 5; dưới đây là phác thảo map về REQ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tenant isolation | Khách A, B tồn tại song song | Khách A gọi API view ví | Chỉ nhận dữ liệu tenant A; thử tenant B → 403 + log cảnh báo | [ ] |
| SC-002: Mask giá vốn | Giao dịch điều chỉnh gắn giá vốn | Khách mở chi tiết giao dịch | Hiện "Điều chỉnh đối soát"; payload API không có trường giá vốn | [ ] |
| SC-003: Timestamp bắt buộc | Nguồn trễ >24h | Portal render trang ví | Mỗi chỉ số có nhãn nguồn + timestamp + disclaimer; thiếu metadata → không render số | [ ] |
| SC-004: Watermark download | Khách xuất báo cáo ví | Tải file từ portal | File có watermark user + thời điểm; `portal_download_log` có bản ghi mới | [ ] |
| SC-005: Read-only tuyệt đối | Session khách hợp lệ | Gọi endpoint ghi dữ liệu tài chính | 403 + log truy cập bất thường; UI không có nút thao tác | [ ] |
| SC-006: Số tranh chấp | Giao dịch đang `DISPUTED` | Khách xem danh sách giao dịch | Hiện "Đang đối soát" + số tham chiếu, không như số chính thức | [ ] |
| SC-007: Mobile rút gọn | Khách mở Mobile BC Portal | Vào màn ví | Thấy số dư, thông báo, ticket — dùng chung view portal | [ ] |

> **Liên kết:** SC-001/002/005 → REQ-FIN-017; SC-003/006 → REQ-FIN-017 + REQ-OPS-010 (BR-OPS-5.4); SC-004 → REQ-OPS-010 (BR-OPS-5.3); SC-007 → REQ-FIN-017 (mobile rút gọn).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/portal-web/client-portal/du-lieu-vi-read-only.md` |
| Bản counterpart CORE (view lọc tenant, RLS, mask) | `phase2-features/core-backend/wallet/` (fan-out REQ-FIN-017 — SYS-CORE-BACKEND) |
| Nguồn nghiệp vụ | `finance.md` (REQ-FIN-017, BR-FIN-603/604), `operations.md` (B.5 — BR-OPS-5.2/5.3/5.4), `P1-02-business-workflow.md` (Luồng 2 — B10) |
| Policy tham chiếu | `client-portal-minh-bach-bao-mat.md`, `bao-ve-du-lieu-ca-nhan.md` (tham chiếu trong operations.md B.6) |
