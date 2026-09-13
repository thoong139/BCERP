# Tính Năng: Proposal & Planning Workspace — Stage-Gate V6.0 (Góc Mobile Nội Bộ)

> **Dựa trên:** REQ-OPS-005 trong `phase1-business/departments/operations/operations.md` (Phần A, B.6)
> **Phân hệ:** Mobile nội bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Proposal & Planning Workspace (MOD-PROPOSAL-PLANNING)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `documents/quy-trinh-lam-viec/` (01 Tổng quan, 03 Giai đoạn 2, 08 RACI/Gate/SLA, 09 Hằng số, 10 Khoản cần xác nhận), `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-PROPLN-001 |
| Module | MOD-PROPOSAL-PLANNING |
| Yêu cầu nghiệp vụ | REQ-OPS-005 — Proposal & Planning Workspace (stage-gate V6.0) (HIGH, Phase2) |
| Người dùng liên quan | OPS_PLAN (chính — duyệt concept, nhận escalate quá SLA gate), OPS_AM (duyệt creative, giá, nhận escalate vòng sửa), OPS_CONT, OPS_DES, OPS_EDIT (nhận push request changes, vòng sửa creative), OPS_ADS (A/B testing thông báo + đề xuất dừng variant), SALES_L4 (SM — quyết escalation vòng sửa), SALES_L5 (GDKD — duyệt Gross Margin trước khi gửi khách), FIN_L1 (Accountant — tham chiếu duyệt margin Quotation, bản counterpart) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2 — touchpoint mobile nội bộ: duyệt-on-the-go, xem dashboard stage-gate khi di chuyển) |
| Phụ thuộc | Gate engine + audit log bất biến thực thi tại SYS-CORE-BACKEND (counterpart FEAT-MBI-PROPLN-002 cùng REQ); workspace soạn proposal + checklist Brand Safety trên SYS-BCERP-WEB (counterpart FEAT-MBI-PROPLN-003 cùng REQ); tier profile từ MOD-CRM-PIPELINE; capacity check từ REQ-OPS-007 (MOD-CAPACITY-TIMESHEET); Quotation chi tiết thuộc MOD-QUOTATION-DEALDESK |
| Ghi chú Expert (A7) | Operations.md Mục A7: chưa có điều chỉnh cụ thể từ Expert Review (bảng đánh giá đang để trống); REQ-OPS-005 fan-out 3 systems — bản này là bản riêng SYS-MOBILE-INTERNAL, counterparts tại SYS-CORE-BACKEND và SYS-BCERP-WEB |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Trên mobile nội bộ (React Native, offline-capable), tính năng biến chiếc điện thoại thành "bộ điều khiển từ xa" của stage-gate V6.0 cho team OPS: OPS_PLAN và SALES_L5 duyệt concept, duyệt Gross Margin và xử lý escalate quá SLA gate ngay khi không ngồi văn phòng; OPS_AM duyệt creative trong SLA 2h/4h/1h và duyệt thay đổi vượt hạn mức khi di chuyển; toàn đội nhận push cảnh báo gate, vòng sửa, deadline editorial calendar và kết quả A/B test. Tính năng bảo đảm nguyên tắc nền *"Không ghi nhận vào PMS = Không tồn tại"* được giữ trọn trên kênh mobile: mọi hành động duyệt/từ chối đều đi qua approval engine và audit log bất biến của core, mobile không tự quyết trạng thái.

**Phạm vi:**
- Bao gồm: dashboard stage-gate 30 stage theo V6.0 dạng chỉ-đọc (machine-state đồng bộ từ core): dự án đang ở stage nào, done-criteria nào đã đạt/thiếu, đồng hồ SLA từng gate còn bao lâu — kèm phân biệt tiêu chí "hệ thống tự kiểm" và "thuần phán đoán con người".
- Bao gồm: hành động duyệt-on-the-go với MFA step-up — OPS_PLAN duyệt concept proposal; SALES_L5 duyệt Gross Margin trước khi gửi khách (SLA 1 ngày làm việc, quá hạn tự escalate); OPS_PLAN duyệt đăng ký thí nghiệm A/B; OPS_AM duyệt vượt hạn mức change log khi di chuyển.
- Bao gồm: push escalation tự động khi quá SLA gate (chuỗi assignee → OPS_PLAN → cấp quản lý), khi proposal chạm giới hạn vòng sửa (B/C ≤2, D/E ≤4), khi vòng sửa creative nội bộ vượt 3 vòng (vòng 4 escalate AM), và khi có Brand Safety fail 1/7 tiêu chí ở khách đang vận hành.
- Bao gồm: duyệt creative đa vai trên mobile theo pipeline CONT → DES/EDIT → PLAN/AM với SLA từng bước: AM 2h, video dài 4h, trend gấp 1h; content self-QC + Lead review 4h; comment bắt buộc khi reject; hiển thị số vòng sửa còn lại của proposal/quotation/deliverable.
- Bao gồm: thông báo A/B testing — duyệt/từ chối đăng ký, kết quả theo variant, đề xuất dừng variant khi đạt ngưỡng khai thắng (≥50 clicks hoặc ≥10 conversions, winner chênh ≥20%); mọi thay đổi trong thử nghiệm đi qua campaign change log bất biến.
- Bao gồm: chế độ offline — chỉ đọc dữ liệu cached (dashboard, checklist, lịch); mọi hành động giá trị cao cấm thực hiện khi không có kết nối.
- Không bao gồm: gate engine kiểm done-criteria, chặn tầng API, đếm vòng, SLA clock, tự sinh dự án sau WON — toàn bộ thực thi ở service layer SYS-CORE-BACKEND; mobile chỉ gửi hành động và hiển thị kết quả machine-state.
- Không bao gồm: soạn proposal từ template theo tier, checklist Brand Safety gắn hợp đồng, validator số trang — bề mặt soạn chính thuộc SYS-BCERP-WEB (counterpart).
- Không bao gồm: soạn WBS đầy đủ, editorial calendar board, nghiệm thu milestone theo WBS, change log engine — thuộc REQ-OPS-006 (MOD-CAMPAIGN-DELIVERABLE); bản này chỉ phủ bề mặt mobile (theo dõi, push, duyệt nhanh) của các quy tắc đó theo yêu cầu lane.
- Không bao gồm: trải nghiệm khách hàng (portal/mobile portal) — khách không dùng SYS-MOBILE-INTERNAL.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-MOBILE-INTERNAL — ứng dụng React Native offline-capable cho staff cần di động (duyệt-on-the-go, xem dashboard). Mobile là kênh phụ trợ của workspace: nơi xem machine-state và phát hành quyết định giá trị cao qua approval engine của core với MFA step-up; khi offline, người dùng chỉ đọc được dữ liệu cached và không thể duyệt.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN | Xem dashboard stage-gate 30 stage của mọi dự án (stage hiện tại, done-criteria thiếu gì, đồng hồ SLA từng gate) trên mobile | Nắm trạng thái toàn phòng khi đang di chuyển, không phải gọi hỏi từng AM |
| 2 | OPS_PLAN | Duyệt concept proposal (strategy, định hướng nội dung) ngay trên điện thoại với MFA step-up | Luồng proposal không bị treo chờ tôi về văn phòng |
| 3 | OPS_PLAN | Nhận push đỏ khi một gate quá SLA và được tự động escalate đến tôi | Xử lý trượt mốc ngay trong ngày thay vì phát hiện khi deal đã chết |
| 4 | OPS_AM | Duyệt creative (content/ảnh/video) theo SLA 2h — 4h với video dài — 1h với trend gấp, kèm comment bắt buộc khi reject | Luồng sản xuất không tắc dù tôi đang ngoài giờ họp khách |
| 5 | OPS_AM | Xem số vòng sửa còn lại của proposal/quotation và nhận cảnh báo khi sắp chạm giới hạn theo tier | Không vô tình vượt hạn mức B/C ≤2 hay D/E ≤4 và bị chặn giữa chừng |
| 6 | OPS_AM | Đề xuất thay đổi ngân sách/bid vượt hạn mức ngày của tôi và được TL/AM duyệt ngay trên mobile | Khẩn cấp (die account, CPL tăng đột biến) không phải chờ về máy tính |
| 7 | SALES_L5 | Duyệt Gross Margin của proposal trên mobile trong SLA 1 ngày làm việc, quá hạn có escalate | Proposal đúng hạn gửi khách, doanh thu không lỡ nhịp pitching |
| 8 | OPS_ADS | Nhận thông báo đăng ký thí nghiệm A/B được duyệt/từ chối và đề xuất dừng variant khi đạt ngưỡng ≥50 clicks hoặc ≥10 conversions, chênh ≥20% | Khai thắng đúng evidence, không dừng sớm cảm tính |
| 9 | OPS_CONT / OPS_DES / OPS_EDIT | Nhận push khi creative bị "Request changes" kèm comment của reviewer và xem vòng sửa còn lại (tối đa 3 vòng nội bộ) | Sửa đúng ý ngay vòng đầu, tránh lặp lại vòng 4 phải escalate AM |
| 10 | OPS_AM | Nhận alert Brand Safety khi 1/7 tiêu chí fail ở khách đang vận hành kèm luồng "Từ chối vận hành" | Kích hoạt quy trình dừng khẩn cấp (legal xác nhận + TP OPS duyệt 24h) kịp thời |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Engine enforce tại service layer SYS-CORE-BACKEND; mobile là bề mặt phát hành quyết định và hiển thị machine-state.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MBI-PP-001 | Stage-gate V6.0 gồm 30 stage, mỗi stage có entry/done criteria **machine-checkable**: hệ thống tự chuyển stage khi đủ criteria; phần thuần phán đoán con người (chất lượng notes, quyết định Go/No-Go, nội dung plan) chỉ bắt buộc **có bản ghi trên hệ thống**. Done-criteria stage DEPLOY đã phê chuẩn chính thức theo `[KXN-10]` (stage-gate lifecycle v1.2, bảng 2.1: D+0 cần tiền vào + LOI/HĐ; Planning trong ngày D+0; checklist tài nguyên trước D+4; 6 Communication Rules ký tại D+3; ONGOING D+5). Nguyên tắc "Không ghi nhận vào PMS = Không tồn tại" áp cả kênh mobile. | Chuyển stage thiếu criteria bị chặn cứng cả UI lẫn API (hard block); mobile hiển thị lý do chặn và link tới mục criteria chưa đạt; mọi chuyển stage/override/escalation ghi audit log bất biến |
| BR-MBI-PP-002 | Gate EVALUATION: Brand Safety **7/7 tiêu chí pass** (1 fail = dừng ngay, không có ngoại lệ) + Weighted Scoring ≥3,5; borderline 3,0–3,49 vào hàng đợi thẩm định do SM chỉ định người, SLA 4h, kết luận kèm lý do ghi trên hệ thống. Mobile: OPS_PLAN/AM nhận alert khi có fail hoặc có item vào hàng đợi thẩm định. Bộ tiêu chí V6.0 đang dùng làm chuẩn chờ xác nhận chính thức `[KXN-6]`. | Fail 1/7 → chặn sang PROPOSAL, không có nút bỏ qua ở bất kỳ touchpoint nào; mobile hiển thị trạng thái "đã dừng — chờ xử lý pháp lý" và push cho TP OPS/legal theo luồng từ chối vận hành |
| BR-MBI-PP-003 | Proposal theo tier (KXN-8 đã chốt 12/09 theo chiều V6.0, nguồn `phan-loai-khach-hang-tier.md` §2.2 bản 1.1): **Tier B/C — 8–12 trang, OPS_AM soạn, ≤2 vòng sửa; Tier D/E — 15–25 trang, OPS_PLAN soạn, ≤4 vòng sửa**. Hệ thống đọc tier từ profile khách (cấm hardcode nhãn tier), validator đếm số trang và chặn gửi/xuất bản khi sai định mức. Mobile hiển thị định mức áp dụng cho từng dự án. | Gửi proposal sai định mức bị API từ chối; mobile hiện cảnh báo "định mức không khớp tier" kèm giá trị yêu cầu |
| BR-MBI-PP-004 | Đếm vòng review trên proposal và quotation: mỗi vòng = reviewer chuyển "Request changes" + comment bắt buộc; chạm giới hạn (B/C ≤2, D/E ≤4) → chặn tạo vòng mới, escalate: AM/Planner + SM quyết 1 trong 3 — chốt gửi bản hiện có / gia hạn vòng có lý do (GM duyệt, tối đa 1 lần/proposal, log bất biến) / dừng deal. Mobile: push escalation và hiển thị số vòng còn lại theo thời gian thực. | Tạo vòng sửa thứ (giới hạn+1) bị chặn tầng API; mobile không cho thao tác tiếp ngoài 3 lựa chọn escalation |
| BR-MBI-PP-005 | Duyệt nội bộ trước gửi khách: SALES_L5 (GDKD) duyệt Gross Margin bằng e-approval trong SLA 1 ngày làm việc, quá hạn tự escalate; chưa qua duyệt không tồn tại trạng thái "đã gửi khách" — nút gửi khóa và API từ chối. Điều kiện kèm: Rehearsal xác nhận hoàn thành trước Pitching; Quotation chỉ phát hành sau Pitching, gắn proposal đã duyệt. Mobile: SALES_L5 duyệt nhanh, nhận escalate quá hạn. | Gửi khách thiếu duyệt bị chặn cả UI lẫn API; audit log chữ ký duyệt là bằng chứng duy nhất được chấp nhận |
| BR-MBI-PP-006 | WBS sinh từ approved proposal sau WON: mỗi deliverable trong proposal map ≥1 WBS node; task bắt buộc gắn WBS node; gán tài nguyên qua capacity check bắt buộc (SLA 4h → escalate TL 8h → HR_L2). Mobile: chỉ theo dõi tiến độ WBS, nhận push deadline hôm nay/trượt mốc của editorial calendar; thao tác soạn/gán chính thực hiện trên WEB. | Gán task không qua capacity check bị core từ chối; mobile hiển thị kết quả capacity check (đạt/từ chối + lý do) nhưng không cho ghi đè |
| BR-MBI-PP-007 | Duyệt creative đa vai theo pipeline bắt buộc: **OPS_CONT (nội dung) → OPS_DES/OPS_EDIT (sản xuất visual/video) → OPS_PLAN/OPS_AM (duyệt nghiệp vụ)**; ý kiến khách đi qua AM. **Cấm tự duyệt task của mình** — approver ≠ creator, chặn tầng API. SLA từng bước: **AM duyệt 2h (video dài 4h, trend gấp 1h); content self-QC + Lead review 4h**; quá SLA nhắc, chậm 2 bước liên tiếp escalate TL. **Tối đa 3 vòng sửa nội bộ trên 1 deliverable; vòng 4 escalate OPS_AM** chốt phạm vi bằng văn bản với khách (qua AM). Comment bắt buộc khi reject. Mobile: kênh duyệt nhanh + push khi có việc chờ; hiển thị vòng sửa còn lại. | Tự duyệt bị từ chối API với thông báo vai không hợp lệ; reject không comment không lưu được; vòng 4 không có escalate record thì deliverable bị khóa chuyển trạng thái |
| BR-MBI-PP-008 | Campaign change log **bất biến (append-only)**: mọi thay đổi ngân sách/bid/target/audience/creative chính (kể cả trong A/B test) bắt buộc nhập reason; hệ thống lưu giá trị cũ/mới, ai, khi nào — cấm sửa/xóa bản ghi. Phân bậc duyệt: buyer tự quyết trong hạn mức ngày do TL cấu hình → vượt hạn mức ngày TL duyệt → vượt hạn mức dự án AM duyệt. Exception khẩn cấp: pause trước, bổ sung reason trong 4h làm việc. Mobile: duyệt vượt hạn mức khi di chuyển (push cho TL/AM). | Request thiếu reason bị engine từ chối ở tầng API; cố sửa/xóa bản ghi change log bị chặn và ghi audit log của chính hành vi đó |
| BR-MBI-PP-009 | A/B testing: đăng ký trước khi chạy (giả thuyết, metric chính duy nhất, variant, audience, thời lượng, ngân sách, sample size dự kiến — thiếu trường không lưu được), OPS_PLAN duyệt trước khi chi ngân sách. Khai thắng chỉ khi đạt **sample ≥50 clicks hoặc ≥10 conversions và winner chênh ≥20%** trên metric chính; kết luận (win/lose/no signal) bắt buộc tạo entry change log gắn evidence; hết duration chưa đủ sample → "no signal" + quyết định gia hạn/dừng có lý do. Mobile: nhận thông báo duyệt/kết quả, đề xuất dừng variant khi đạt ngưỡng. | Chi ngân sách cho thí nghiệm chưa đăng ký bị core chặn theo campaign; nút kết luận trên mọi touchpoint yêu cầu evidence, cảm tính không khai thắng được |
| BR-MBI-PP-010 | Chế độ offline của mobile: chỉ đọc dữ liệu cached (dashboard stage-gate, checklist, lịch, kết quả A/B); mọi hành động duyệt/từ chối/escalate **cấm thực hiện khi không có kết nối** — mọi quyết định phải có timestamp server và chữ ký e-approval do core cấp. Hành động giá trị cao bắt buộc MFA step-up. | Nút duyệt bị vô hiệu ở trạng thái offline với thông báo "cần kết nối để ghi nhận quyết định"; không có cơ chế ghi đệm quyết định offline rồi sync sau |

**Giả định gắn khoản chờ xác nhận (không tự quyết):**
- `[KXN-6]` Bộ tiêu chí EVALUATION (Brand Safety 7 + Weighted ≥3,5 của V6.0) đang dùng làm chuẩn vận hành, chưa được xác nhận chính thức là bộ duy nhất — spec dựng checklist theo cấu hình, không hardcode.
- `[KXN-7]` 16 sections Strategic Brief chưa có định nghĩa nội dung — điều kiện "điền ≥80%" được cấu hình theo template, mobile chỉ hiển thị % hoàn thành.
- `[KXN-19]` Ma trận RACI tổng hợp chưa được xác nhận — bảng phân quyền dưới dựng theo nguồn hiện có, phải rà lại khi KXN-19 chốt.
- `[KXN-20]` Danh sách đầy đủ cờ cảnh báo K6–K12 chưa liệt kê tường minh — mobile hiển thị flag theo cấu hình.
- `[KXN-21]` Danh sách 4 lý do LOST là enum đề xuất — dựng dropdown cấu hình được, chờ khách hàng xác nhận.
- Các khoản mở `[KXN-9]` (phạm vi "tương lai"), `[KXN-15]` (Client Survey), `[KXN-16]` (node retro trùng), `[KXN-17]` (4 nhóm LOST chi tiết), `[KXN-18]` (quy trình HR), `[KXN-22]` (mốc non-payment 15 ngày) không chạm logic lõi của feature mobile này — chỉ ảnh hưởng cấu hình hiển thị khi chốt.

---

## 4. Phân Quyền

| Hành động | OPS_PLAN | OPS_AM | OPS_CONT/DES/EDIT | OPS_ADS | SALES_L4 (SM) | SALES_L5 (GDKD) | SYS_ADMIN |
|-----------|----------|--------|-------------------|---------|---------------|-----------------|-----------|
| Xem dashboard stage-gate (tất cả dự án phòng) | ✅ | ✅ | ✅ (dự án của mình) | ✅ (dự án của mình) | ✅ | ✅ | ✅ |
| Duyệt concept proposal | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt Gross Margin trước gửi khách | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Duyệt creative (bước nghiệp vụ cuối) | ✅ | ✅ | ❌ (cấm tự duyệt bài của mình) | ❌ (cấm tự duyệt) | ❌ | ❌ | ❌ |
| Request changes + comment | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem vòng sửa còn lại | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Quyết escalation vượt vòng sửa (chốt gửi/gia hạn/dừng) | ✅ (đề xuất) | ✅ (đề xuất) | ❌ | ❌ | ✅ (quyết định) | ✅ (duyệt gia hạn) | ❌ |
| Duyệt thay đổi vượt hạn mức ngày (change log) | ✅ (vượt hạn mức dự án) | ✅ (vượt hạn mức dự án) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt đăng ký thí nghiệm A/B | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Khai thắng/thua A/B có evidence | ✅ | ✅ (declare) | ❌ | ✅ (đề xuất dừng variant) | ❌ | ❌ | ❌ |
| Xử lý escalate quá SLA gate | ✅ (đích escalate) | ✅ (đích escalate cấp 1) | ❌ | ❌ | ✅ (cấp 2) | ✅ | ❌ |
| Cấu hình SLA/ngưỡng/định mức gate | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

Quy tắc xuyên: approver bắt buộc khác creator trên mọi bước duyệt (chặn tầng API, không chỉ ẩn nút); vai AD trong quy trình gốc (duyệt giá cuối Rehearsal, vượt giới hạn revision) được ánh xạ tạm về OPS_PLAN (kiêm nhiệm trưởng phòng) và SALES_L5 theo tính chất quyết định — khi mã vai OPS_AD được bổ sung chính thức vào registry sẽ ánh xạ lại; câu hỏi "Quản lý GM (V6.0) = AD hay BOD/CFO?" còn mở, gắn `[KXN-12]`.

---

## 5. Trường Hợp Đặc Biệt

- **Mất kết nối giữa lúc duyệt:** hành động duyệt chỉ ghi nhận khi core trả về xác nhận (timestamp server + audit ID); nếu mạng đứt giữa chừng, mobile hiển thị "chưa ghi nhận" và người dùng phải thực hiện lại khi có mạng — không có hàng đợi quyết định offline để tránh tranh chấp thời điểm duyệt.
- **Deal chiến lược override knockout K1–K5:** SM override phải có GM phê duyệt lại, lý do bằng văn bản, log bất biến; trên mobile chỉ hiển thị trạng thái "đang chờ GM phê duyệt override" — thao tác override đầy đủ thực hiện trên WEB, không cho phép ký override trên màn hình nhỏ.
- **Khách tái ký (renew):** được rút gọn Initial Brief nhưng **không bỏ Gate 1/Gate 2**; mobile hiển thị luồng rút gọn kèm ghi chú "gate vẫn bắt buộc" để tránh nhầm rằng renew đi tắt gate.
- **Emergency pause chiến dịch khẩn cấp (die account, sự cố brand safety):** buyer pause trước qua mobile (nếu trong hạn mức), bổ sung reason vào change log trong 4h làm việc; quá 4h không có reason → cảnh báo TL và ghi vi phạm riêng vào audit.
- **Vòng sửa creative chạm vòng 3:** hệ thống khóa tạo vòng mới trên mobile, chỉ cho phép OPS_AM mở escalate record (chốt phạm vi bằng văn bản với khách); editorial calendar giữ buffer 20% cho trend content — trend gấp vẫn phải tuân thủ SLA 1h của AM.
- **Thí nghiệm trùng audience:** đăng ký A/B mới trùng segment với thí nghiệm đang chạy bị core chặn; mobile hiển thị bản đồ thí nghiệm active theo khách để OPS_ADS chọn audience loại trừ hoặc chờ kết thúc; trường hợp platform khác nhau cùng tệp mục tiêu phải có OPS_PLAN đánh giá rủi ro giao thoa rồi mới duyệt.
- **Brand Safety fail ở khách đang vận hành:** mobile chỉ là kênh alert và theo dõi — nút "Từ chối vận hành" (khóa trạng thái HĐ, notify legal + ops) cần legal-expert xác nhận + TP OPS duyệt trong 24h; quy trình 2 chặng này hiển thị trạng thái từng chặng trên mobile nhưng thao tác ký thực hiện trên WEB với MFA đầy đủ.
- **Tier borderline khó phân loại:** khi điểm CQ rơi vùng biên (D 3,0–3,49), định mức proposal (số trang, số vòng) theo tier chờ thẩm định 4h của SM; trong thời gian chờ, mobile khóa các hành động phụ thuộc tier và hiển thị "đang thẩm định".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Dự án (Project) trên stage-gate V6.0 — 30 stage, ở đây thể hiện đoạn Giai đoạn 2 "Đánh giá & Đề xuất" là phạm vi vận hành chính của workspace (mobile theo dõi cả 30 stage nhưng các stage Sales/Deploy/ONGOING/Kết thúc có bản spec counterpart riêng).

**Sơ đồ trạng thái:**
```
[EVALUATION] ──(pass BS 7/7 + Weighted ≥3.5)──► [SECOND_MEETING] ──(brief 16 sections ≥80%)──►
[PROPOSAL_INTERNAL] ──(≤3 vòng nội bộ + AD confirm giá sơ bộ)──► [REHEARSAL] ──(pass, giá cuối chốt)──►
[PROPOSAL] ──(GM duyệt + gửi khách ≤1 ngày)──► [PROPOSAL_REVIEW] ──(≤2/≤4 vòng theo tier)──►
[PITCHING] ──(KH chọn)──► [QUOTATION] ──(AD duyệt margin)──► [NEGOTIATION] ──(HĐ/LOI ký)──► [WON]
     │                    │                        │
     │ (BS fail → LOST chủ động)                   │ (KH từ chối / im lặng)
     ▼                                             ▼
   [LOST]                                        [LOST]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc (machine-checkable) |
|---------------------|-----------|----------------|-------------|----------------------------------------|
| `EVALUATION` | Pass gate | `SECOND_MEETING` | Hệ thống tự chuyển | Brand Safety 7/7 pass + Weighted ≥3,5; borderline 3,0–3,49: bản ghi thẩm định 4h có kết luận kèm lý do |
| `SECOND_MEETING` | Pass gate | `PROPOSAL_INTERNAL` | Hệ thống tự chuyển | Strategic Brief 16 sections điền ≥80% `[KXN-7]` + 5 output bắt buộc có bản ghi trên PMS |
| `PROPOSAL_INTERNAL` | Pass gate | `REHEARSAL` | OPS_AM/OPS_PLAN đề xuất, hệ thống kiểm | ≥1 vòng review nội bộ đã ghi; ≤3 vòng sửa; giá sơ bộ được AD xác nhận (bản ghi duyệt) |
| `REHEARSAL` | Pass gate | `PROPOSAL` | Hệ thống kiểm checklist | Toàn team pitch thử ≥1 lần (attendance); giá + điều khoản được AD confirm; v1.0 có link trên PMS; Q&A script đã lưu |
| `PROPOSAL` | Gửi khách | `PROPOSAL_REVIEW` | OPS_AM | SALES_L5 đã e-approval Gross Margin (SLA 1 ngày LV); số trang đúng định mức tier; ProposalRevision log timestamp |
| `PROPOSAL_REVIEW` | Hết vòng review | `PITCHING` | OPS_AM | Feedback KH đã nhập PMS (dù kênh nào); revision count chưa vượt giới hạn (B/C ≤2, D/E ≤4); vượt giới hạn phải có quyết định SM + GM duyệt gia hạn (nếu chọn gia hạn) |
| `PITCHING` | KH chọn agency | `QUOTATION` | OPS_AM cập nhật | Bản ghi phản hồi KH + ghi chú buổi pitch; SLA tổ chức 5 ngày LV (+3) |
| `QUOTATION` | Pass gate | `NEGOTIATION` | Hệ thống kiểm | Báo giá chi tiết từng hạng mục; AD duyệt margin (bản ghi); KH đã nhận (timestamp gửi) |
| `NEGOTIATION` | Chốt thỏa thuận | `WON` | OPS_AM + SM xác nhận | HĐ hoặc LOI ký 2 bên (file + timestamp); reporting frequency đã set; cập nhật PMS + notify team trong 24h |
| Bất kỳ điểm LOST (Pitching/Negotiation) | Ghi nhận LOST | `LOST` | OPS_AM/SALES | `lostStage` + `lostReason` trong 24h — enum 4 lý do là đề xuất `[KXN-21]` |

**Quy tắc:**
- Hard gate — không nhảy bước: chỉ chuyển stage khi 100% done criteria thỏa; chặn cả UI lẫn API, kể cả trên mobile (mobile chỉ gửi yêu cầu, engine quyết).
- `WON` và `LOST` là trạng thái kết thúc đoạn Giai đoạn 2 — WON mở đồng hồ D-day (D+0 cần tiền vào + LOI/HĐ theo `[KXN-5]` đã chốt); LOST đi vào nurturing theo nhóm.
- Mọi chuyển stage, chữ ký e-approval, override, escalation đều ghi audit log bất biến (ai, khi nào, giá trị cũ/mới) — không có đường ghi đè tay.
- Trên mobile không hiển thị nút chuyển stage thủ công; trạng thái luôn là machine-state đọc từ core.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| Project | `stage`, `clientTier`, `qualifiedTier`, `servicePackage`, `reportingFrequency`, `project_type` | FK → `clients.id` | 30 stage V6.0; tier đọc từ profile, cấm hardcode |
| EvaluationScore | `brand_safety_1..7`, `weighted_total`, `borderline_flag`, `reviewer_id` | FK → `projects.id` | 1 fail = hard stop; borderline 4h `[KXN-6]` |
| ProposalVersion | `project_id`, `version_no`, `page_count`, `tier_template`, `status` | FK → `projects.id` | Validator số trang theo tier; trạng thái bản ghi trên core |
| ProposalRevision | `proposal_id`, `round_no`, `reviewer_id`, `comment`, `requested_at` | FK → `proposal_versions.id` | Comment bắt buộc; đếm vòng B/C ≤2, D/E ≤4 |
| GateApprovalRecord | `gate_id`, `approver_id`, `decision`, `signed_at`, `sla_deadline` | FK → `projects.id`, `users.id` | E-approval + audit bất biến; approver ≠ creator |
| EscalationRecord | `source_type`, `source_id`, `from_role`, `to_role`, `escalated_at`, `resolved_at` | FK → đa hình | Push xuống mobile; chuỗi SLA theo gate |
| ChangeLogEntry | `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `actor_id`, `changed_at` | FK → `campaigns.id` | Append-only, cấm sửa/xóa |
| ABTest | `campaign_id`, `hypothesis`, `primary_kpi`, `variants`, `sample_size`, `status`, `winner_variant` | FK → `campaigns.id` | Khai thắng: ≥50 clicks hoặc ≥10 conversions, chênh ≥20% |
| WBSTask | `project_id`, `wbs_node`, `assignee_id`, `capacity_check`, `status` | FK → `projects.id`, `users.id` | Mobile chỉ đọc + push; gán chính trên WEB |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ; chi tiết đầy đủ điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: GM duyệt gửi khách trên mobile | Proposal v1.0 đủ định mức tier, chờ duyệt GM trong SLA 1 ngày LV | SALES_L5 mở app, e-approval với MFA step-up | Core ghi GateApprovalRecord + audit log; trạng thái proposal chuyển "được phép gửi"; nút gửi mở trên WEB | [ ] |
| SC-002: Quá SLA gate tự escalate | Một gate quá hạn mà assignee chưa hành động | Đồng hồ SLA chạm 100% | Core tạo EscalationRecord theo chuỗi; OPS_PLAN nhận push đỏ trên mobile trong vài giây; log bất biến | [ ] |
| SC-003: Cấm tự duyệt creative | OPS_CONT submit bài viết cho chính pipeline mà OPS_PLAN là người soạn strategy cùng deliverable | OPS_PLAN thử duyệt task do mình tạo | API từ chối với thông báo approver ≠ creator; mobile hiển thị lý do và gợi ý chọn approver khác | [ ] |
| SC-004: Khai thắng A/B đúng ngưỡng | Thí nghiệm đạt 55 clicks, variant B chênh 21% so với A | OPS_ADS đề xuất dừng variant A trên mobile | Hệ thống cho phép kết luận "win" bắt buộc kèm entry change log gắn evidence; thiếu evidence không lưu được | [ ] |
| SC-005: Offline chỉ đọc | Thiết bị mất kết nối | Người dùng mở dashboard stage-gate | Dữ liệu cached hiển thị kèm nhãn "dữ liệu tại thời điểm sync"; mọi nút duyệt vô hiệu với thông báo cần kết nối | [ ] |

> **Liên kết:** SC-001/002 map REQ-OPS-005 (SLA gate + e-approval, Mục 2); SC-003/004 map REQ-OPS-005 qua BR-MBI-PP-007/009 (duyệt creative đa vai, A/B testing); SC-005 map yêu cầu offline-capable của touchpoint SYS-MOBILE-INTERNAL.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (push notification, offline sync, MFA step-up) | `technical-specs/integration-map.md` |
| Màn hình UI (mobile: dashboard stage-gate, hàng đợi duyệt, A/B result) | `phase4-ux/mobile-internal/proposal-planning/[screen-group].md` |
| Counterpart CORE (gate engine, đếm vòng, hard block API, audit log) | `phase2-features/core-backend/proposal-planning/` |
| Counterpart WEB (soạn proposal theo tier, checklist Brand Safety) | `phase2-features/bcerp-web/proposal-planning/` |
