# Tính Năng: A/B Testing & Chiến Lược Campaign Theo Mục Tiêu Khách (Integration Gateway)

> **Dựa trên:** REQ-OPS-012 trong `phase1-business/departments/operations/operations.md` (Phần A, Phần B.10 — BR-OPS-10.1…10.4)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (Luồng 3 — bước GUIMAU), `work/wf-analyze-requirements/deferred-issues.md` (DI-005, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-CAMP-002 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-012 — A/B Testing & chiến lược campaign theo mục tiêu khách (MEDIUM, GĐ2 thiết kế thử nghiệm gắn campaign → GĐ3 phân tích chéo đầy đủ); fan-out 4 systems (CORE, GW, WEB, M-INT) — bản này là riêng SYS-INTEGRATION-GW |
| Người dùng liên quan | OPS_ADS (thực hiện thí nghiệm, nhận đề xuất dừng variant), OPS_PLAN (duyệt chiến lược/đăng ký — qua WEB), OPS_AM (cập nhật khách theo kết quả), OPS_CONT/OPS_DES/OPS_EDIT (variant creative đi qua pipeline duyệt chung), SYS_ADMIN (cấu hình metric mapping), BOD_CFO_CTO (điều hành degraded adapter) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (feed dữ liệu variant gắn campaign) — phần phân tích chéo đầy đủ dời GĐ3 |
| Phụ thuộc | FEAT-GW-CAMP-001 — change log push engine và chi tiêu theo campaign (mọi thay đổi ngân sách trong thử nghiệm đi qua đây); FEAT-GW-STGW-001 — connection profile, vault, scheduler, degraded/backfill; FEAT-GW-STGW-002 — hạ tầng pull hourly 7 nền tảng + nhãn nguồn |
| Ghi chú Expert (A7) | operations.md Mục A7: chưa có đánh giá expert chính thức tại thời điểm viết (chờ review); business rules B.10 do marketing-expert viết call-2; chuẩn sample size/ngưỡng kết luận đã chốt theo DI-005 (winner chênh ≥20% + ≥50 clicks hoặc ≥10 conversions); ghi nhận DI-007 — degraded `manual` là trạng thái khởi điểm của mọi nguồn dữ liệu variant |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là bề mặt Integration Gateway của REQ-OPS-012: cung cấp dữ liệu hiệu quả theo variant (KPI, sample size) từ API 7 nền tảng quảng cáo cho từng thí nghiệm A/B đã đăng ký, cung cấp audience size phục vụ kiểm soát chống giao thoa, và map metric của từng platform về bộ KPI chuẩn theo mục tiêu khách (conversion/traffic/awareness). Gateway không thiết kế, không duyệt và không kết luận thí nghiệm — nó bảo đảm mọi kết luận win/lose/no signal ở CORE đều đứng trên số liệu có nhãn nguồn rõ ràng, và khi mất API thì kênh manual có cấu trúc + backfill vẫn giữ thí nghiệm sống.

**Phạm vi:**
- Bao gồm: mở luồng pull dữ liệu hiệu quả theo variant chỉ cho thí nghiệm đã đăng ký và được OPS_PLAN duyệt (tham chiếu `experiment_ref` hợp lệ); VariantMetricFeed theo ngày/variant với nhãn nguồn `api`/`manual`.
- Bao gồm: AudienceSizeFeed — estimated audience size từ platform, đầu vào cho CORE kiểm overlap "1 thí nghiệm active mỗi segment".
- Bao gồm: MetricMapping theo mục tiêu khách (conversion/traffic/awareness) — cấu hình vendor-agnostic tại MOD-SETTINGS-GW theo DI-004; metric platform thiếu mapping bị đẩy vào hàng lỗi, không suy diễn.
- Bao gồm: kênh nhập kết quả manual có cấu trúc khi degraded (DI-007), backfill + restatement khi số platform thay đổi sau này, và tín hiệu đề xuất dừng variant khi đạt ngưỡng DI-005 (đẩy qua counterpart M-INT cho OPS_ADS).
- Bao gồm: tách bạch `data_domain` — KPI thí nghiệm QC (`ads_perf`) không trộn GMV TikTok Shop (`tiktok_shop_gmv`).
- Không bao gồm: đăng ký thí nghiệm, validation trường bắt buộc, chặn chi ngân sách khi chưa đăng ký, kiểm overlap, chốt win/lose/no signal, learning log/playbook — thuộc SYS-CORE-BACKEND (engine) và SYS-BCERP-WEB (nơi thao tác).
- Không bao gồm: bề mặt hiển thị kết quả/dashboard — thuộc counterpart WEB; mobile nội bộ chỉ nhận thông báo (M-INT).
- Không bao gồm: bất kỳ kênh nào cho CUSTOMER — REQ-OPS-012 không có bản portal; dữ liệu thí nghiệm là tài sản nội bộ, chỉ ra khỏi hệ thống qua báo cáo AM khi hợp đồng quy định.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-INTEGRATION-GW là tầng gateway/adapter headless: thí nghiệm được đăng ký và duyệt ở WEB/CORE, còn gateway là điểm phát dữ liệu nền tảng về và đẩy thay đổi ra. Toàn bộ ràng buộc biên giới (không feed thí nghiệm chưa đăng ký, không nhận số không nhãn nguồn, không trộn GMV) cứng hoá ở service layer của gateway.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (gateway adapter) | Chỉ mở luồng pull KPI cho thí nghiệm mang `experiment_ref` đã REGISTERED + APPROVED | Thí nghiệm chưa đăng ký không thể chạy ngầm có dữ liệu — khớp cơ chế CORE chặn ngân sách |
| 2 | OPS_ADS | Nhận KPI theo từng variant mỗi ngày với nhãn nguồn và sample size (clicks, conversions) | Theo dõi thí nghiệm bằng số platform gốc, biết khi nào sample đã đủ để tính ngưỡng DI-005 |
| 3 | OPS_ADS | Khi nền tảng mất API, nhập kết quả variant theo form có cấu trúc (variant, KPI, giá trị, sample, evidence) gắn nhãn `manual` | Thí nghiệm đang chạy không đứt số giữa duration; sau này backfill được đối soát |
| 4 | OPS_PLAN | Xem estimated audience size theo platform trước khi duyệt thí nghiệm mới | Đánh giá trùng segment với thí nghiệm đang chạy và độ đại diện của sample trước khi ký duyệt |
| 5 | Hệ thống (gateway adapter) | Khi một variant đạt ngưỡng DI-005 (chênh ≥20% + ≥50 clicks hoặc ≥10 conversions trên KPI chính), phát tín hiệu đề xuất dừng | OPS_ADS nhận qua M-INT và xử lý kịp thời, không để thí nghiệm đội ngân sách sau khi đã rõ thắng thua |
| 6 | OPS_AM | Xem (qua WEB counterpart) tổng hợp KPI variant có nhãn nguồn để báo cáo khách theo kết quả có evidence | Cam kết với khách chỉ dựa trên số truy vết được — không "có vẻ tốt" |
| 7 | BOD_CFO_CTO | Nhìn thấy trạng thái từng feed thí nghiệm (feeding/degraded/backfill) và tuổi dữ liệu | Điều hành hạ tầng khi nguồn stale, quyết định hạ tần suất hoặc chuyển manual có chủ đích |
| 8 | SYS_ADMIN | Bổ sung metric mapping cho một platform mới trong Settings không sửa code | Onboarding nền tảng mới là cấu hình, không phải release |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. BR-OPS-10.x gốc thực thi chính ở CORE/WEB; bảng dưới cứng hoá phần gateway ở biên API và nhắc lại các quy tắc chung của module áp dụng cho mọi luồng dữ liệu thí nghiệm.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-10.1-gwa | **Chỉ feed thí nghiệm đã đăng ký + duyệt:** đăng ký thí nghiệm gắn campaign bắt buộc đủ giả thuyết, metric chính duy nhất theo mục tiêu khách (conversion/traffic/awareness), variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến — OPS_PLAN duyệt trước khi triển khai; gateway chỉ mở luồng pull cho `experiment_ref` ở trạng thái REGISTERED/APPROVED do CORE xác nhận (thí nghiệm không đăng ký bị CORE chặn chi ngân sách, gateway đồng bộ không cấp dữ liệu) | Request feed cho experiment không tồn tại/chưa duyệt bị từ chối ở tầng API + audit log |
| BR-OPS-10.1-gwb | **Metric map theo mục tiêu khách:** KPI chính của thí nghiệm map từ metric platform về bộ chuẩn theo objective qua MetricMapping cấu hình tại MOD-SETTINGS-GW (DI-004 — vendor-agnostic, không hardcode); mỗi variant đo trên cùng một định nghĩa KPI trong suốt duration | Dòng metric không có mapping → hàng lỗi, không suy diễn "metric gần giống"; đổi định nghĩa KPI giữa duration phải tạo đăng ký lại, không được vá qua mapping |
| BR-OPS-10.1-gwc | **Sample size + ngưỡng kết luận (DI-005):** winner chỉ công nhận khi chênh lệch ≥20% trên KPI chính và đạt tối thiểu ≥50 clicks hoặc ≥10 conversions; khung confidence nội bộ 95%; gateway cung cấp số sample đạt theo variant để CORE đánh giá ngưỡng | Gateway không tự đánh dấu variant thắng/thua — kết luận chỉ có ý nghĩa khi CORE xác nhận ngưỡng; đề xuất dừng khi ngưỡng chưa đạt là tín hiệu lỗi |
| BR-OPS-10.2-gw | **Chống giao thoa audience:** trên cùng một audience/tenant khách, mỗi thời điểm chỉ 1 thí nghiệm active; gateway cung cấp estimated audience size làm đầu vào cho CORE kiểm overlap trước khi duyệt; thí nghiệm trên platform khác nhau nhưng cùng tệp mục tiêu → OPS_PLAN đánh giá rủi ro giao thoa rồi mới duyệt, ghi lý do | Gateway không duyệt hay chặn overlap thay CORE — dữ liệu audience sai/thiếu bị đánh dấu độ tin cậy thấp; push audience mới xuống platform khi CORE chưa clear overlap bị chặn |
| BR-OPS-10.3-gwa | **Kết luận có evidence:** dừng variant/khai thắng chỉ khi đạt ngưỡng BR-OPS-10.1-gwc; kết luận win/lose/no signal bắt buộc entry change log gắn evidence — số KPI theo variant, thời gian chạy, sample đạt; hết duration mà chưa đủ sample → kết luận "no signal" + quyết định gia hạn/dừng có lý do | Gateway cung cấp trọn bộ số làm evidence, không phát sinh bất kỳ kênh kết luận nào ngoài change log của CORE; kết luận thiếu evidence ref bị CORE từ chối lưu |
| BR-OPS-10.3-gwb | **Ngân sách trong thử nghiệm qua change log bất biến:** mọi thay đổi ngân sách/bid/target trên campaign thí nghiệm đi qua change log engine của CORE và push theo cơ chế FEAT-GW-CAMP-001 (chỉ nhận entry APPROVED, phân bậc buyer → TL → AM theo hạn mức); khẩn cấp pause trước — bổ sung reason trong 4h làm việc | Push thay đổi trong thí nghiệm thiếu tham chiếu change log bị từ chối; số chi tiêu thí nghiệm không khớp change log bị đánh dấu `DRIFT` và chặn kết luận cho tới khi giải trình |
| BR-OPS-10.4-gw | **Learning log về playbook:** gateway cung cấp evidence_ref cho từng kết luận; thư viện learning log theo khách/ngành và cập nhật playbook/template chiến lược (review quý bởi OPS_PLAN) thuộc CORE/WEB — gateway không lưu nội dung học hỏi | Không có ghi chú học hỏi nào được "giấu" trong metadata gateway; mọi nội dung chiến lược đi qua lớp nội dung của CORE |
| BR-GW-CAMP-021 | **Degraded manual + backfill + restatement (DI-007):** khi mất quyền API, OPS_ADS nhập kết quả variant theo form có cấu trúc (variant, KPI, giá trị, sample, evidence, nguồn), gắn nhãn `manual` + timestamp; khi API sống lại gateway backfill khoảng đứt; platform restatement (số thay đổi retro) được nhận như dữ liệu mới có phiên bản, giữ bản cũ làm vết | Không được phép dừng thí nghiệm chỉ vì mất API; kết luận đứng trên số manual phải mang nhãn để CORE trừ hao độ tin cậy; restatement không ghi đè im lặng — chênh lệch vượt ngưỡng cảnh báo OPS_ADS/TL |
| BR-GW-CAMP-022 | **Tách bạch GMV TikTok Shop:** KPI thí nghiệm thuộc `data_domain` = `ads_perf`; GMV TikTok Shop là `tiktok_shop_gmv` riêng (REQ-OPS-011) — chỉ dùng làm KPI khi thí nghiệm đăng ký riêng phạm vi shop và vẫn tách bạch khỏi P&L agency | Payload gộp domain bị reject ở tầng API; GMV không tự động trở thành evidence khai thắng thí nghiệm ads |
| BR-GW-CAMP-023 | **Không cam kết KPI cứng cho khách:** mọi kết luận chỉ phục vụ vận hành nội bộ và báo cáo theo hợp đồng — không cam kết KPI đầu ra cho khách ngoài hợp đồng, chỉ cam kết đầu vào (khớp `hop-dong-loi-nda-brand-safety.md` §2.5); gateway không phát hành bề mặt cam kết nào | Bất kỳ endpoint/export nào của gateway không được dùng làm văn bản cam kết kết quả cho khách |
| BR-GW-CAMP-024 | **Quy tắc chung module (tham chiếu FEAT-GW-CAMP-001):** campaign thí nghiệm theo WBS — payload bắt buộc `project_ref` + `wbs_node_ref` + `tenant_id`, campaign không map không vào báo cáo; creative variant đi qua pipeline duyệt đa vai + SLA DI-005 (AM 2h/video 4h/trend 1h, self-QC + Lead review 4h, tối đa 3 vòng sửa, vòng 4 escalate AM), chỉ push creative đã Approved; khách theo dõi deliverable chỉ phần đã share qua PORTAL counterpart với tenant isolation — REQ-OPS-012 không có bề mặt portal | Payload thiếu tham chiếu/tenant bị reject; creative chưa duyệt không được đẩy làm variant; dữ liệu thí nghiệm không xuất hiện trên bất kỳ kênh khách nào |
| BR-GW-CAMP-025 | **Tham số và cấu hình chỉ ADMIN/BOD sửa:** ngưỡng sample/đề xuất dừng là cấu hình versioned đọc từ policy (DI-005); metric mapping sửa tại Settings theo quyền SYS_ADMIN thực thi + BOD_CFO_CTO duyệt | OPS roles không sửa được ngưỡng; attempt sửa bị RBAC chặn + audit log |

---

## 4. Phân Quyền

> *Gateway là API headless: bảng này là hợp đồng quyền cho các API gateway cung cấp; mọi thao tác người dùng đi qua web nội bộ (SYS-BCERP-WEB) hoặc mobile nội bộ (SYS-MOBILE-INTERNAL). REQ-OPS-012 không có bản portal — CUSTOMER không có bất kỳ quyền nào trên luồng thí nghiệm.*

| Hành động | OPS_ADS | OPS_PLAN | OPS_AM | SYS_ADMIN | BOD_CFO_CTO | CUSTOMER |
|-----------|---------|----------|--------|-----------|-------------|----------|
| Xem KPI theo variant + nhãn nguồn + sample của thí nghiệm khách mình | ✅ | ✅ | ✅ (tổng hợp báo cáo khách) | ✅ | ✅ | ❌ (chỉ khi HĐ quy định — qua báo cáo AM) |
| Nhập kết quả variant manual (degraded) + evidence | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem estimated audience size theo platform | ✅ | ✅ (phục vụ duyệt) | ❌ | ✅ | ✅ | ❌ |
| Duyệt đăng ký thí nghiệm (CORE quyết định — gateway nhận trạng thái) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Nhận tín hiệu đề xuất dừng variant khi đạt ngưỡng | ✅ (qua M-INT counterpart) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Kích hoạt backfill/reconcile thủ công cho feed thí nghiệm | ✅ (đề xuất) | ❌ | ❌ | ✅ (thực thi sau phê duyệt CTO) | ✅ (phê duyệt) | ❌ |
| Thêm/sửa MetricMapping (objective ↔ metric platform) | ❌ | ❌ | ❌ | ✅ (thực thi) | ✅ (duyệt) | ❌ |
| Sửa ngưỡng sample/đề xuất dừng (policy versioned) | ❌ | ❌ | ❌ | ❌ (chỉ xem) | ✅ (duyệt theo DI-005) | ❌ |
| Ghi learning log / cập nhật playbook | ✅ (ghi — qua CORE/WEB) | ✅ (review quý) | ❌ | ❌ | ❌ | ❌ |
| Xem audit log feed thí nghiệm | ❌ (chỉ của mình) | ✅ | ❌ | ✅ | ✅ | ❌ |

> Ranh giới: OPS_CONT/OPS_DES/OPS_EDIT sản xuất variant creative và duyệt trong pipeline chung (FEAT-GW-CAMP-001) — không thao tác API gateway. Quyết định dừng/khai thắng thuộc CORE (evidence check) + OPS_ADS thực hiện + OPS_PLAN phê duyệt ở bản WEB; gateway chỉ là nguồn số và kênh tín hiệu.

---

## 5. Trường Hợp Đặc Biệt

- **Platform không có split test native:** gateway tính KPI theo variant bằng quy ước variant code trong naming/UTM của adset/ad (khớp chuẩn REQ-OPS-1.2); variant không tách được ở mức adset → thí nghiệm bị đánh dấu không đủ điều kiện, OPS_ADS phải tái cấu trúc trước khi chạy.
- **Kết quả lấp lánh giữa các thí nghiệm cùng khách:** nếu OPS_PLAN duyệt ngoại lệ đa platform cùng tệp mục tiêu (có lý do), gateway vẫn feed đủ các nguồn nhưng gắn cùng `cohort_tag` để CORE tổng hợp có lưu ý giao thoa — số từng nguồn không được gộp mù.
- **Platform restatement giữa duration:** số clicks/conversions platform sửa retro — gateway nhận phiên bản mới, giữ bản cũ làm vết, cảnh báo khi chênh vượt 5%; kết luận đã chốt trước restatement không tự đảo — CORE quyết định mở lại với audit log.
- **Mất API kéo dài trọn duration thí nghiệm:** toàn bộ số là `manual`; hệ thống vẫn cho kết thúc và kết luận nhưng evidence mang nhãn manual, báo cáo kèm độ tin cậy giảm — không cấm kết luận (đứt vận hành còn hại), nhưng không được ngụy trang thành số API.
- **Die account giữa thí nghiệm:** campaign bị pause theo quy trình die account (BR-OPS-1.6); feed thí nghiệm chuyển `PAUSED` giữ ngữ cảnh; khi chuyển sang TK dự phòng, variant mới tiếp tục dưới cùng `experiment_ref` kèm annotation đổi tài khoản — CORE quyết định gia hạn duration.
- **Ngân sách cạn sớm hơn duration:** chi tiêu feed về 0 trong khi duration còn lại; gateway không tự kết thúc thí nghiệm — phát tín hiệu cho OPS_ADS quyết định top-up (qua change log) hoặc kết thúc sớm có lý do.
- **KPI platform đổi định nghĩa (policy/API version mới):** mapping cũ trả số lệch chuẩn — hàng lỗi tăng đột biến kích hoạt cảnh báo; SYS_ADMIN cập nhật MetricMapping có version; số trước/sau mốc đổi được tách phiên để so sánh công bằng.
- **Khách yêu cầu chia sẻ kết quả thí nghiệm:** mặc định nội bộ; chỉ xuất qua báo cáo AM khi hợp đồng quy định, dữ liệu đã mask phần ngân sách/chi phí nội bộ — không cấp tài khoản xem trực tiếp gateway hay dashboard nội bộ. Định dạng báo cáo nghiệm thu/kết quả dựng theo khung Report hiện dùng — cấu trúc chi tiết 9 sections Report chưa chốt `[KXN-7]`, gateway chỉ phát dữ liệu thô có nhãn, việc dựng template báo cáo thuộc counterpart WEB/CORE nên không chặn thiết kế.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** ExperimentFeed — luồng dữ liệu gateway cho một thí nghiệm A/B đã đăng ký (một thí nghiệm có thể gồm nhiều feed khi chạy đa nền tảng).

**Sơ đồ trạng thái:**
```
[REGISTERED] ──(CORE xác nhận APPROVED + platform sẵn sàng)──► [FEEDING]
     │                                                             │
     │ (CORE chưa duyệt / hủy đăng ký)                             │──(mất API / fail vượt ngưỡng)──► [DEGRADED]
     ▼                                                             │                                     │
 [CANCELLED]                                                       │◄──(API sống lại + backfill xong)────┘
                                                                   │──(pause tay / die account)──► [PAUSED]
                                                                   │                                      │
                                                                   │◄──(resume)───────────────────────────┘
                                                                   │──(duration hết + CORE kết luận)──► [CONCLUDED]
                                                                   │──(số nền tảng sửa retro)──► [BACKFILL] ──(xong)──► [CONCLUDED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `REGISTERED` | Mở luồng feed | `FEEDING` | Hệ thống | CORE xác nhận đăng ký APPROVED; MetricMapping đủ KPI chính; campaign đã map WBS |
| `REGISTERED` | Hủy đăng ký | `CANCELLED` | OPS_PLAN (qua CORE) | Nhập lý do; không feed; không chi ngân sách |
| `FEEDING` | Mất API / fail vượt ngưỡng | `DEGRADED` | Hệ thống | Alert gộp; OPS_ADS chuyển nhập manual có cấu trúc |
| `DEGRADED` | API sống lại | `BACKFILL` | Hệ thống | Có khoảng đứt dữ liệu; backfill theo thứ tự thời gian |
| `BACKFILL` | Backfill + đối soát xong | `FEEDING` | Hệ thống | Bản ghi manual giữ làm vết; chênh lệch đã báo cáo |
| `FEEDING` | Pause | `PAUSED` | OPS_ADS / Hệ thống (die account) | Ghi reason vào change log trong 4h LV nếu pause tay |
| `PAUSED` | Resume | `FEEDING` | OPS_ADS (TL duyệt nếu đổi phạm vi) | Change log entry APPROVED cho việc resume |
| `FEEDING`/`PAUSED` | Kết luận | `CONCLUDED` | CORE (tự động khi duration hết) | Evidence đầy đủ: KPI variant, sample, thời gian chạy; entry change log win/lose/no signal |

**Quy tắc:**
- `CONCLUDED` và `CANCELLED` là trạng thái kết thúc; mở lại chỉ khi platform restatement đáng kể — khi đó CORE tạo phiên kết luận mới tham chiếu bản cũ, không sửa bản cũ.
- Thí nghiệm `CONCLUDED` ngừng cấp KPI mới nhưng evidence_ref vẫn truy vấn được cho learning log và báo cáo.
- Mọi chuyển trạng thái ghi audit log bất biến kèm trigger (job id, mã lỗi, người thao tác).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ExperimentFeed | `experiment_ref`, `campaign_ref`, `wbs_node_ref`, `tenant_id`, `platform`, `cohort_tag`, `status` (REGISTERED/FEEDING/PAUSED/DEGRADED/BACKFILL/CONCLUDED/CANCELLED), `duration_from/to` | FK logic → đăng ký thí nghiệm (CORE), CampaignPlatformMapping | Chỉ tồn tại khi CORE xác nhận đăng ký APPROVED |
| VariantMetricFeed | `experiment_ref`, `variant_code`, `platform`, `date`, `kpi_name`, `kpi_value`, `clicks`, `conversions`, `source_label` (`api`/`manual`), `metric_map_version`, `restatement_of` | FK → ExperimentFeed | KPI chính duy nhất theo objective; restatement giữ phiên bản cũ làm vết |
| AudienceSizeFeed | `experiment_ref`, `audience_ref`, `platform`, `estimated_size`, `pulled_at` | FK → ExperimentFeed | Đầu vào CORE kiểm overlap "1 thí nghiệm active/segment" |
| ManualResultRecord | `experiment_ref`, `variant_code`, `kpi_name`, `value`, `sample_clicks`, `sample_conversions`, `evidence_ref`, `entered_by`, `source_label` = `manual` | FK → ExperimentFeed | Degraded mode; evidence bắt buộc (ảnh/platform report) |
| MetricMapping | `platform`, `objective` (CONVERSION/TRAFFIC/AWARENESS), `platform_metric`, `standard_kpi`, `transform_rule`, `map_version` | Cấu hình tại MOD-SETTINGS-GW (DI-004) | Vendor-agnostic; thiếu mapping → hàng lỗi |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chỉ feed thí nghiệm đã duyệt | Thí nghiệm đăng ký thiếu duyệt OPS_PLAN | Gateway nhận request feed | Từ chối ở tầng API + audit; không cấp dữ liệu; CORE đồng bộ chặn ngân sách campaign | [ ] |
| SC-002: Metric không có mapping vào hàng lỗi | Platform đổi tên metric, mapping chưa cập nhật | Pull dữ liệu về | Dòng metric vào hàng lỗi kèm cảnh báo; không suy diễn sang KPI chuẩn; SYS_ADMIN thêm mapping version mới | [ ] |
| SC-003: Sample đạt ngưỡng phát tín hiệu dừng | Variant B đạt chênh ≥20% và ≥50 clicks so với A trên KPI chính | Giờ pull nhận số vượt ngưỡng | Tín hiệu đề xuất dừng đẩy qua M-INT cho OPS_ADS; gateway không tự kết luận | [ ] |
| SC-004: Kết luận gắn evidence từ feed | OPS_ADS khai thắng variant B | CORE kiểm evidence | Entry change log chứa số KPI variant + sample + thời gian chạy lấy từ feed; thiếu evidence không lưu được | [ ] |
| SC-005: Duration hết thiếu sample → no signal | Thí nghiệm hết duration, sample < ngưỡng | CORE tổng kết | Kết luận "no signal" có lý do; feed `CONCLUDED`; quyết định gia hạn/dừng ghi change log | [ ] |
| SC-006: Degraded manual + backfill không mất số | Mất API giữa duration, OPS_ADS nhập manual 5 ngày | API sống lại | Backfill bù đủ khoảng đứt, bản ghi manual giữ làm vết, chênh lệch báo cáo; feed trở lại `FEEDING` | [ ] |
| SC-007: Restatement không ghi đè im lặng | Platform sửa retro số conversions sau khi kết luận | Gateway nhận số mới | Phiên bản mới gắn `restatement_of`, bản cũ giữ; CORE quyết định mở lại kết luận có audit log | [ ] |
| SC-008: GMV không thành evidence ads | Thí nghiệm ads khách TikTok có cả GMV shop | Tổng hợp KPI | GMV nằm riêng `tiktok_shop_gmv`; không xuất hiện trong evidence khai thắng thí nghiệm `ads_perf` | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-012 (Mục 2 — đăng ký trước chạy, metric theo mục tiêu khách, sample/ngưỡng DI-005, evidence kết luận, degraded manual + backfill, restatement, tách bạch GMV).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/campaign-deliverable/` (đăng ký thí nghiệm, dashboard kết quả — thuộc counterpart WEB; gateway không có UI) |
| Bản fan-out counterpart | `phase2-features/core-backend/campaign-deliverable/` (đối tượng thí nghiệm, chặn ngân sách, tổng hợp KPI, learning log), `phase2-features/bcerp-web/campaign-deliverable/` (thiết kế + dashboard), `phase2-features/mobile-internal/campaign-deliverable/` (thông báo kết quả/đề xuất dừng) — REQ-OPS-012 xuất hiện ở 4 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane | `phase2-features/integration-gw/campaign-deliverable/campaign-va-deliverable-management.md` (FEAT-GW-CAMP-001 — change log push + chi tiêu theo campaign mà thí nghiệm dùng cho mọi thay đổi ngân sách) |
| Hạ tầng gateway dùng chung | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001), `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-002) |
| Nguồn nghiệp vụ | REQ-OPS-001 (naming/UTM variant code), REQ-OPS-011 (tách bạch TikTok Shop GMV), `hop-dong-loi-nda-brand-safety.md` §2.5 (không cam kết KPI cứng), `work/wf-analyze-requirements/deferred-issues.md` (DI-005 — sample size/ngưỡng đã chốt; DI-007 — degraded mode bắt buộc) |
