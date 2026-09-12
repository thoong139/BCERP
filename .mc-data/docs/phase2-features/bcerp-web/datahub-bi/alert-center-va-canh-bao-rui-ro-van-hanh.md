# Tính Năng: Alert Center & Cảnh Báo Rủi Ro Vận Hành

> **Dựa trên:** REQ-BOD-006 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** DataHub & BI — Data Integration Hub, BI/BOD Dashboard, Alert Center (SYS-BCERP-WEB)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/datahub-bi/alert-center.md`, `phase5-implementation/tasks/bcerp-web/datahub-bi/feat-erp-dhub-003-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-DHUB-003 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-006 (Alert center & cảnh báo rủi ro vận hành) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP: sync/hard stop/backup alerts) → Giai đoạn 2 (SLA, khiếu nại) → Giai đoạn 3 (alert center BI tổng hợp) |
| Phụ thuộc | Rule engine + delivery đa kênh của SYS-CORE-BACKEND; nền tảng alert của FEAT-ERP-DHUB-001/002 (trạng thái nguồn dữ liệu); REQ-BOD-005 (alert đứt hash-chain audit) |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-006 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-006 fan-out ra 3 hệ thống; bản này là bản riêng cho **SYS-BCERP-WEB** — trung tâm tổng hợp, phân tích và xử lý alert. Theo phân vai đã chốt ở dept doc: MOBILE là kênh chính cảnh báo khẩn (push ≤5 phút), còn **WEB là nơi phân tích/xử lý đầy đủ** (drill về nguồn, ghi nhận người xử lý + resolution). Counterparts: SYS-CORE-BACKEND, SYS-MOBILE-INTERNAL.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp alert center trên web nội bộ — một màn hình duy nhất nơi toàn bộ cảnh báo rủi ro vận hành của BCERP được tổng hợp theo trạng thái đã/chưa xử lý, mức nghiêm trọng và loại rủi ro, để BOD_CEO và BOD_CFO_CTO nhận trách nhiệm xử lý đúng alert, khoan về đúng nguồn sự cố và chốt resolution có bằng chứng. Tính năng biến các tín hiệu rủi ro rải rác (ví sắp cạn, die account, SLA breach, backup fail, job sync fail, stale dữ liệu) thành hàng đợi trách nhiệm có truy xuất được thay vì tin nhắn phân tán.

**Phạm vi:**
- Bao gồm:
  - Alert center tổng hợp: danh sách alert theo trạng thái (chưa xử lý / đã acknowledge / đang xử lý / đã đóng), bộ lọc theo mức nghiêm trọng, loại, nguồn, thời gian.
  - Chi tiết alert: ngữ cảnh sự kiện, drill-down/deep-link về nguồn (widget dashboard, giao dịch, job, nền tảng), lịch sử re-push.
  - Luồng acknowledge bắt buộc nhập lý do + người nhận trách nhiệm; ghi resolution khi đóng alert.
  - Gộp alert theo nguồn (grouping/dedup) khi connector outage sinh cảnh báo hàng loạt; ưu tiên hiển thị theo mức.
  - Bảng cấu hình ngưỡng cảnh báo (xem + đề xuất chỉnh; duyệt thuộc luồng chính sách REQ-BOD-009).
  - Thống kê vi phạm SoD bị chặn gửi CFO rà định kỳ; thống kê khiếu nại nghiêm trọng leo thang BOD theo SLA.
- Không bao gồm:
  - Đánh giá sự kiện theo ngưỡng và quyết định phát alert (rule engine) — thực thi ở SYS-CORE-BACKEND; WEB tiêu thụ kết quả.
  - Push notification khẩn trên mobile (kênh chính cảnh báo khẩn, ≤5 phút) — thuộc SYS-MOBILE-INTERNAL; web nhận deep-link từ mobile và ngược lại.
  - Tự động pause TKQC khi rủi ro (hard stop) — thuộc phân hệ OPS/FIN tương ứng; alert chỉ thông báo và dẫn đường xử lý.
  - Tra cứu audit log chi tiết (REQ-BOD-005) — alert đứt hash-chain chỉ deep-link sang màn hình tra cứu audit của phân hệ đó.

---

## 2. Luồng Người Dùng (User Stories)

Alert center là hàng đợi trách nhiệm của BOD: mỗi alert đỏ phải có chủ; mỗi lần tắt alert phải để lại dấu vết có lý do. WEB là nơi "giải quyết chuyện lớn", mobile chỉ là còi báo động.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở alert center thấy mọi cảnh báo chưa xử lý xếp theo mức nghiêm trọng | Xử lý cái nguy hiểm nhất trước, không bỏ sót alert nào |
| 2 | BOD_CEO | Nhận cảnh báo đứt hash-chain audit log và khoan thẳng sang màn hình tra cứu audit | Xác minh ngay hệ thống ghi chép có bị can thiệp không |
| 3 | BOD_CFO_CTO | Nhận alert số dư ví dưới ngưỡng đủ chi, vượt hạn mức tuần nạp, die/spike/checkpoint TKQC | Phản ứng kịp thời với rủi ro dòng tiền và tài khoản quảng cáo trước khi khách mất tiền |
| 4 | BOD_CFO_CTO | Tắt alert bằng acknowledge + lý do, tên mình thành người nhận trách nhiệm | Trách nhiệm rõ ràng, không ai chối trách nhiệm alert đã "biến mất" |
| 5 | BOD_CFO_CTO | Khi connector outage sinh 200 alert cùng lúc, thấy chúng gộp theo nguồn theo mức | Không bị ngập thông tin, xử lý gốc rễ thay vì tắt từng cái |
| 6 | SYS_ADMIN | Nhận alert kỹ thuật (job sync fail, backup thất bại quá 30 phút, stale dữ liệu) và xử lý vận hành | Sự cố hạ tầng được xử lý bởi đúng người, không trộn vào alert tài chính của BOD |
| 7 | SYS_ADMIN | Xem lịch sử re-push: alert đỏ đã kêu bao nhiêu lần, lúc nào, cho ai | Chứng minh được cảnh báo đã phát đúng kênh đúng hạn khi soát xét sự cố |
| 8 | BOD_CEO | Xem báo cáo thống kê: vi phạm SoD bị chặn theo tháng, khiếu nại leo thang có đạt SLA không | Đánh giá xu hướng rủi ro vận hành trong họp điều hành định kỳ |

---

## 3. Quy Tắc Nghiệp Vụ

Rule engine và phân mức do CORE enforce; WEB buộc phải phản ánh đúng ràng buộc acknowledge và không cung cấp cách nào đóng alert mà không để lại dấu vết.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Danh mục cảnh báo BOD bắt buộc**: đứt hash-chain audit log; số dư ví dưới ngưỡng đủ chi (mức mặc định đề xuất ≥3 ngày chi bình quân — mức số chính thức chờ chủ dự án xác nhận); die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại quá 30 phút; job sync fail; stale dữ liệu nghiêm trọng (chi QC >8h, ví >2h, timesheet >24h) | Nguồn rủi ro thuộc danh mục mà không cấu hình rule → thiếu sót cấu hình, đưa vào review cấu hình alert định kỳ |
| BR-002 | **Tắt alert chỉ bằng acknowledge + reason** — không có nút "bỏ qua" trống; cảnh báo mức đỏ bắt buộc có người nhận trách nhiệm (BOD hoặc delegate nhận) | Thử đóng alert không reason → chặn ở tầng API, UI không cho submit |
| BR-003 | Alert đỏ **re-push đến khi có người nhận trách nhiệm** — chu kỳ đề xuất 15 phút với mức đỏ (mốc chờ chủ dự án chốt số chính thức) | Alert đỏ không ai nhận → tiếp tục re-push và nổi lên đầu alert center; không tự hủy theo thời gian |
| BR-004 | **Connector outage → gộp alert theo nguồn, ưu tiên theo mức, không ngập người nhận**: các alert cùng nguồn/cùng root cause hợp thành một đợt (batch) có số đếm con | Gửi riêng lẻ hàng trăm alert → vi phạm anti-flood; hệ thống gộp tự động trước khi phân phối |
| BR-005 | **Khiếu nại nghiêm trọng từ khách leo thang BOD theo SLA** (khiếu nại 24h; breach đỏ ≤5 phút vào alert center theo P1-02 Luồng 5) | Khiếu nại quá hạn leo thang → alert vi phạm SLA riêng cho việc leo thang trễ |
| BR-006 | **Thống kê vi phạm SoD bị chặn gửi CFO rà định kỳ** — alert center tổng hợp số liệu, không dùng để trừng phạt tự động | Số liệu SoD không tổng hợp được theo kỳ → lỗi dữ liệu đầu vào, báo cáo trống có nhãn giải thích |
| BR-007 | Phân kênh trách nhiệm: **SYS_ADMIN nhận alert kỹ thuật, không tự đóng alert đỏ của BOD**; người vắng cho delegate nhận (nhận, không delegate xử lý) | SYS_ADMIN đóng alert đỏ tài chính → chặn, chỉ BOD/delegate nhận được phép |
| BR-008 | Dữ liệu lương/PII chỉ aggregate khi được phép: alert về nhân sự (nếu phát sinh) hiển thị ở mức vai/nhóm; alert chi tiết lương cá nhân không phát qua kênh chung | Rule sinh alert chứa PII → chặn ở tầng sinh alert, chỉ aggregate được phép đi tiếp |
| BR-009 | Mỗi alert ghi audit truy xuất đầy đủ: ai nhận, acknowledge lúc nào, reason, resolution; BOD truy xuất lịch sử alert cũng bị log (meta-log) | Alert mất lịch sử xử lý → vi phạm append-only; không được phép xóa/alert record chỉ đóng, không xóa |
| BR-010 | Data Integration Hub là nguồn tín hiệu: alert stale nguồn dữ liệu sinh từ trạng thái nguồn (DEGRADED/STALE) của DataHub; degraded mode hiển thị nhãn "manual" trên alert và trên đích deep-link | Alert stale hiển thị trong khi nguồn thực sự FRESH → lệch trạng thái, kiểm tra đồng bộ trạng thái nguồn |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Xem alert center (tất cả mức, tất cả loại) | ✅ | ✅ | ✅ (alert kỹ thuật đầy đủ; alert tài chính đỏ xem trạng thái, xử lý thuộc BOD) |
| Acknowledge + reason alert mức đỏ | ✅ | ✅ | ❌ (chỉ alert kỹ thuật mức thấp/trung bình) |
| Ghi resolution, đóng alert | ✅ | ✅ | ✅ (riêng alert kỹ thuật; alert đỏ BOD không tự đóng) |
| Đăng ký delegate nhận alert khi vắng | ✅ | ✅ | ❌ |
| Xem/đề xuất cấu hình ngưỡng cảnh báo | ✅ (duyệt chính sách) | ✅ (đề xuất) | ✅ (vận hành kỹ thuật) |
| Xem thống kê SoD bị chặn, khiếu nại leo thang | ✅ | ✅ (CFO rà định kỳ) | ❌ (không xem nội dung rủi ro nghiệp vụ ngoài scope) |
| Xem chi tiết T3/T4 trong ngữ cảnh alert | ✅ | ✅ | ❌ (alert chứa giá trị nhạy cảm mask với vai không phép) |
| Xóa bản ghi alert | ❌ | ❌ | ❌ (chỉ đóng, không xóa — append-only) |

---

## 5. Trường Hợp Đặc Biệt

- **Danh mục cờ cảnh báo còn mở:** bộ cờ K6–K12 đầy đủ trong tài liệu quy trình chưa được khách hàng xác nhận (`[KXN-20]`) — cấu hình rule engine dựng theo danh mục bắt buộc BR-001 trước, các cờ bổ sung thêm sau khi KXN chốt, qua luồng cấu hình có version.
- **Mốc non-payment chưa chốt:** mốc "15 ngày → PAUSE" do nợ thanh toán là đề xuất 2 bậc 15/30 ngày chờ khách hàng xác nhận (`[KXN-22]`); alert aging công nợ/alert ví cấu hình ngưỡng tạm theo đề xuất, đánh dấu phiên bản ngưỡng "chờ chuẩn hóa".
- **Connector outage kéo dài:** GW mất quyền API nền tảng (DI-007) → nguồn rơi DEGRADED, alert stale gộp theo nguồn; người nhận thấy một alert "nguồn Meta degraded — 47 widget phụ thuộc" thay vì 47 alert riêng.
- **Cả hai BOD vắng đồng thời:** alert đỏ re-push không tìm thấy người nhận → chuyển sang delegate đã đăng ký; nếu vẫn không có người nhận, alert nổi bật ở màn hình đăng nhập của mọi vai BOD khi quay lại + ghi sự cố "alert đỏ không người nhận" vào báo cáo quarterly review.
- **Alert trùng nguồn trùng nguyên nhân trong ngày:** die account của cùng một khách do cùng root cause (nợ thanh toán) → gộp batch, không sinh alert mới nếu batch đang mở; đếm số sự kiện con trong batch.
- **Người liên quan đến sự cố cố đóng alert của mình:** SoD — người sinh ra sự kiện (ví dụ người duyệt giao dịch bị cảnh báo) không được là người acknowledge alert đó; hệ thống chặn và ghi vi phạm.
- **Alert nhầm (false positive):** đóng alert kèm reason "false positive"; thống kê false positive theo rule đưa vào review ngưỡng định kỳ để tinh chỉnh, không xóa lịch sử.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chính là **Alert** — vòng đời từ khi phát sinh đến khi đóng có trách nhiệm; đây là state machine mà web render trực tiếp ở dạng cột trạng thái và nút hành động.

**Entity:** Alert (cảnh báo rủi ro vận hành)

**Sơ đồ trạng thái:**
```
[OPEN] ──(acknowledge + reason)──► [ACKNOWLEDGED] ──(bắt đầu xử lý)──► [IN_PROGRESS] ──(ghi resolution)──► [RESOLVED]
   │                                      │                                │
   │ (re-push khi chưa có người nhận đỏ)   │ (escalate khi quá SLA xử lý)   │ (xác minh lại thất bại — tái mở)
   ▼                                      ▼                                ▼
[OPEN] (re-push chu kỳ)               [ESCALATED] ──(cấp trên nhận)──► [IN_PROGRESS]            [ACKNOWLEDGED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Acknowledge | `ACKNOWLEDGED` | BOD (alert đỏ) / SYS_ADMIN (alert kỹ thuật); delegate nhận được phép | Nhập reason bắt buộc; mức đỏ ghi người nhận trách nhiệm |
| `OPEN` | Re-push (hệ thống) | `OPEN` (chu kỳ lại) | Hệ thống | Mức đỏ chưa có người nhận; chu kỳ theo cấu hình (đề xuất 15 phút) |
| `ACKNOWLEDGED` | Bắt đầu xử lý | `IN_PROGRESS` | Người nhận trách nhiệm | Ghi kế hoạch/đầu xử lý |
| `IN_PROGRESS` | Đóng với resolution | `RESOLVED` | Người nhận trách nhiệm; alert đỏ BOD không do SYS_ADMIN đóng | Nhập resolution + bằng chứng (link giao dịch/job) |
| `IN_PROGRESS` | Escalate quá SLA | `ESCALATED` | Hệ thống | SLA xử lý của mức alert vượt hạn |
| `RESOLVED` | Tái mở khi tái diễn | `ACKNOWLEDGED` | BOD | Sự kiện lặp trong cửa sổ thời gian cấu hình; alert cũ giữ nguyên lịch sử |

**Quy tắc:**
- Không có đường nào từ `OPEN`/`ACKNOWLEDGED` đến "đã xóa" — alert record append-only, đóng là trạng thái kết thúc có đầy đủ dấu vết.
- `RESOLVED` không phải điểm kết thúc tuyệt đối: tái diễn trong cửa sổ thời gian cho phép tái mở có kiểm soát, tránh sinh alert mới làm nhiễu thống kê.
- Chuyển `ACKNOWLEDGED` → `ESCALATED` do hệ thống theo SLA, không cần ai bấm; escalate luôn đi kèm thông báo lên cấp duyệt trên.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `alert` | `code`, `type` (hash_chain/ví_balance/die_account/sla_breach/weekly_limit/backup/sync_fail/stale), `severity` (đỏ/vàng/xanh), `state`, `source_ref`, `raised_at` | FK → `alert_rule`, nguồn sự kiện | Append-only |
| `alert_rule` | `code`, `metric_ref`, `threshold_json`, `severity`, `channel_policy`, `version` | 1-N → `alert` | Version theo luồng cấu hình chính sách |
| `alert_event_log` | `alert_id`, `event` (raised/re-push/ack/escalate/resolve), `actor_id`, `reason`, `at` | FK → `alert` | Immutable; meta-log khi BOD truy xuất |
| `alert_delegate` | `principal_role`, `delegate_role`, `from_date`, `to_date` | FK → vai registry | Nhận thay, không xử lý thay |
| `sod_violation_stat` | `period`, `rule_code`, `blocked_count`, `by_role` | FK → `alert_rule` | Nguồn báo cáo gửi CFO định kỳ |
| `data_source` | `code`, `state`, `last_valid_at` | 1-N → `alert` | Tín hiệu stale từ DataHub (dùng chung FEAT-001/002) |

---

## 8. Acceptance Criteria

> Phác thảo Phase 2, chi tiết hóa ở Phase 5. Map về REQ-BOD-006.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Alert đỏ bắt buộc acknowledge + reason | Alert đỏ "số dư ví dưới ngưỡng đủ chi" phát sinh | BOD_CFO_CTO mở alert center và acknowledge | Không nhập reason không thể submit; sau acknowledge alert ghi người nhận trách nhiệm và dừng re-push | [ ] |
| SC-002: Re-push khi không ai nhận | Alert đỏ phát lúc 22:00, không ai acknowledge | Sau chu kỳ đề xuất (15 phút) | Hệ thống re-push; lịch sử re-push ghi đầy đủ; alert nổi đầu danh sách | [ ] |
| SC-003: Gộp alert khi connector outage | Nguồn Meta rơi DEGRADED sinh nhiều tín hiệu | Mở alert center | Thấy 1 alert batch "nguồn Meta degraded" với đếm sự kiện con; không có hàng chục alert riêng lẻ | [ ] |
| SC-004: SYS_ADMIN không tự đóng alert đỏ BOD | SYS_ADMIN đăng nhập | Mở alert đỏ tài chính, bấm đóng | Bị chặn với thông báo chỉ BOD/delegate được phép; hành vi thử đóng ghi audit | [ ] |
| SC-005: Khiếu nại leo thang đúng SLA | Khiếu nại nghiêm trọng từ khách phát sinh | 24h trôi qua chưa xử lý xong | Alert leo thang BOD phát theo SLA; breach đỏ vào alert center ≤5 phút từ lúc phát hiện | [ ] |
| SC-006: Thống kê SoD gửi CFO | Một tháng có N lần vi phạm SoD bị chặn | CFO mở báo cáo định kỳ | Thấy thống kê theo rule × vai × tháng, truy xuất được từng sự kiện gốc | [ ] |
| SC-007: Mask dữ liệu nhạy cảm trong alert | Alert liên quan ngữ cảnh có giá trị T3/T4 | SYS_ADMIN xem alert | Giá trị nhạy cảm bị mask; BOD xem được đầy đủ | [ ] |
| SC-008: Cờ K6–K12 bổ sung sau khi chốt | `[KXN-20]` được khách hàng xác nhận | Thêm rule mới theo cờ chốt | Rule lên hệ thống qua luồng cấu hình có version; alert sinh đúng từ rule mới | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu alert, rule engine, event log | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (alert feed, acknowledge, delegate, thống kê) | `phase3-architecture/technical-specs/api-contract.md` |
| Delivery đa kênh CORE ↔ GW ↔ MOBILE; anti-flood grouping | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI alert center (web nội bộ responsive) | `phase4-ux/bcerp-web/datahub-bi/alert-center.md` |
| Counterpart MOBILE (push khẩn ≤5 phút, deep-link) | `phase2-features/mobile-internal/datahub-bi/` (FEAT tương ứng REQ-BOD-006) |
| Luồng nghiệp vụ nguồn alert SLA/khiếu nại | `phase1-business/P1-02-business-workflow.md` (Luồng 5, Bước B4/B6) |
