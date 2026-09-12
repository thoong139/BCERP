# Tính Năng: Chuyển tier Sales → CS & rà soát quý tier

> **Dựa trên:** REQ-SALES-005 trong `phase1-business/departments/sales/sales.md` (Phần A + Phần B — Sales Expert Review)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-BCERP-WEB)
> **Module:** CRM Pipeline (MOD-CRM-PIPELINE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/quy-trinh-lam-viec/06_Giai_doan_5_Ket_thuc_Closed_Renew.md` (v1.1 §8 — UPSELL), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §1, §7)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/crm-pipeline/tier-review.md`, `phase5-implementation/tasks/bcerp-web/crm-pipeline/feat-erp-crm-005-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CRM-005 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-005 |
| Người dùng liên quan | SALES_L2 (NVKD/SE — phối hợp upsell), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — đồng thuận đề xuất), SALES_L5 (GDKD — duyệt chuyển tier, rà quý, trình BOD), OPS_AM (bên vận hành tiếp nhận tier, đề xuất chuyển tier) |
| Độ ưu tiên | Trung bình (MEDIUM — MVP) |
| Giai đoạn | Giai đoạn 1 (tier chuyển nguyên trạng tại WON + tham số effective-dated); chu trình đề xuất chuyển tier với bên vận hành hoàn thiện từ Phase2 |
| Phụ thuộc | Không có cross-dependency chặn; đồng bộ tier và tham số effective-dated thực thi tại SYS-CORE-BACKEND (counterpart cùng REQ-ID); nhận qualifiedTier từ FEAT-ERP-CRM-003 (cùng module) |
| Ghi chú Expert (A7) | Mục A7 của sales.md đang chờ điền; spec kế thừa Sales Expert Review Phần B (12/09/2026): tier chuyển nguyên trạng không nhập lại; tham số version hóa effective-dated không sửa quá khứ; hiệu chỉnh ngưỡng GDKD trình BOD — không chỉnh tại chỗ |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng bảo đảm tier của khách hàng sống sót qua điểm chuyển giao: khi deal WON, tier chuyển nguyên trạng cho bên vận hành (CS/AM) để template proposal, SLA, vòng sửa tiếp tục đúng tier đã chốt — không nhập lại, không sai lệch; đồng thời cung cấp luồng rà soát theo quý để GDKD đối chiếu win rate theo tier và độ lệch giữa điểm CQ chấm ban đầu với kết quả thực tế, từ đó hiệu chỉnh ngưỡng/trọng số qua GDKD trình BOD. Tier không phải nhãn tĩnh: thiếu cơ chế chuyển giao nguyên trạng và rà quý thì hệ quả tier (proposal B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng — KXN-8) sẽ bị áp sai ngay từ dự án đầu tiên sau WON.

**Phạm vi:**
- Bao gồm: đồng bộ tier nguyên trạng Sales → CS tại WON; luồng đề xuất chuyển tier trong kỳ dựa trên doanh thu thực tế của hợp đồng, số TKQC active và churn risk (health score); quy trình đồng thuận (bên đề xuất → SM + đầu mối vận hành đồng thuận → GDKD duyệt SLA 3 ngày làm việc); dashboard win rate theo tier + độ chính xác scoring theo quý cho GDKD/BOD; quản lý tham số ngưỡng/trọng số CQ version hóa effective-dated; luồng UPSELL mini-flow trong ONGOING theo file 06 §8.
- Không bao gồm: chấm điểm và xếp tier ban đầu (FEAT-ERP-CRM-003); ký Gate 1 khóa qualifiedTier (FEAT-ERP-CRM-004); tính health score chi tiết và QBR vận hành (phân hệ OPS — tham chiếu 09 §7: Client Health Score 0–100, vạch ≥80 xanh / 60–79 vàng / <60 đỏ); tính hoa hồng theo tier (REQ-SALES-009).

**Đặc thù touchpoint SYS-BCERP-WEB:**
Web nội bộ responsive (Next.js) chạy toàn bộ chu trình: form đề xuất chuyển tier (tự điền sẵn doanh thu thực tế, số TKQC active, health score đọc từ CORE), luồng đồng thuận nhiều bước với trạng thái machine-state rõ (nháp → đã đề xuất → đã đồng thuận → GDKD duyệt/từ chối → hiệu lực), dashboard rà quý và màn quản lý phiên bản tham số. Hiệu chỉnh ngưỡng được thể hiện như đề xuất version có hiệu lực tương lai — web vô hiệu hóa mọi nút "sửa tại chỗ" trên tham số đang chạy và hiển thị đối chiếu cũ/mới trước khi GDKD gửi BOD. Ký duyệt qua MOBILE (Phase2) dùng chung approval engine của CORE.

**Fan-out:**
REQ-SALES-005 xuất hiện ở 2 systems — đây là bản riêng cho SYS-BCERP-WEB; counterpart: SYS-CORE-BACKEND (primary — đồng bộ tier, tham số effective-dated, health score làm đầu vào). Spec này mô tả luồng đề xuất, duyệt và dashboard thuộc web nội bộ.

**Nguồn quy trình:** `documents/quy-trinh-lam-viec/` v1.1 — UPSELL stage tái dựng tại file 06 §8 (AM/SE phát hiện cơ hội, đề xuất trong 24h, Accepted nhỏ điều chỉnh budget / Accepted lớn tạo project mới + `parentProjectId` / Declined lưu theo dõi); 11 KXN còn mở (6, 7, 9, 15–22) ghi assumption có tag, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

Tại WON, hệ thống tự đồng bộ tier sang bên nhận — không ai phải nhập lại. Trong kỳ vận hành, khi dữ liệu thực tế lệch khỏi tier ban đầu (doanh thu tăng nhanh, khách ký thêm nhiều TKQC, health score báo churn risk), bên vận hành đề xuất chuyển tier; đề xuất phải qua đồng thuận hai phía rồi GDKD duyệt. Mỗi quý, GDKD mở dashboard rà win rate và độ chính xác scoring để quyết định có trình BOD hiệu chỉnh ngưỡng hay không.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM (bên nhận tier) | Nhận đúng tier nguyên trạng khi deal WON, không phải nhập lại hay đoán | Áp đúng template proposal, SLA và vòng sửa theo tier ngay từ ngày đầu vận hành |
| 2 | OPS_AM | Đề xuất chuyển tier trong kỳ kèm dữ liệu tự điền (doanh thu thực tế, số TKQC active, health score) | Đề xuất có căn cứ số liệu thay vì cảm tính, đúng quy trình có vết |
| 3 | SALES_L4 (TPKD/SM) | Đồng thuận/không đồng thuận đề xuất chuyển tier với một thao tác có ghi nhận | Giữ quyền quản pipeline nhưng không bị kẹt trong vòng duyệt dài |
| 4 | SALES_L5 (GDKD) | Duyệt/từ chối chuyển tier trong SLA 3 ngày làm việc với đối chiếu cũ/mới | Quyết nhanh, nhất quán, có lý do lưu vết cho mọi thay đổi tier |
| 5 | SALES_L5 (GDKD) | Xem dashboard quý: win rate theo tier, độ lệch điểm CQ vs kết quả thực | Phát hiện ngưỡng scoring lệch thực tế và chuẩn bị hồ sơ trình BOD |
| 6 | SALES_L2 (NVKD/SE) | Ghi nhận cơ hội upsell phát hiện trong ONGOING và soạn đề xuất trong 24h | Không để mất cơ hội doanh thu từ khách hiện hữu (chi phí acquisition = 0) |
| 7 | SALES_L5 (GDKD) | Quản lý phiên bản tham số scoring effective-dated và gửi BOD phê duyệt | Thay đổi chính sách có hiệu lực tương lai rõ ràng, không đụng vào dữ liệu quá khứ |

---

## 3. Quy Tắc Nghiệp Vụ

Sáu nhóm quy tắc bắt buộc của lane áp dụng đầy đủ; nhóm trọng tâm là chuyển tier nguyên trạng (BR-SALES-501), luồng đề xuất có đồng thuận (BR-SALES-502) và rà quý với tham số version hóa (BR-SALES-503). Mọi thay đổi tier có audit log + lý do; tham số version hóa effective-dated.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | Hard gate "không ghi nhận = không tồn tại" (KXN-1): mọi thay đổi tier phải có bản ghi + lý do + audit log; pipeline 5 tier A–E (A <1.5 AUTO LOST → E ≥3.5 bypass) là chuẩn duy nhất được chuyển giao | Thay đổi tier ngoài luồng bị từ chối; tier "miệng" không có giá trị vận hành |
| BR-SALES-501 | WON → tier chuyển nguyên trạng cho CS (đồng bộ máy tại CORE) — không nhập lại; qualifiedTier đã khóa sau Gate 1 là tier được chuyển | Phát hiện sai lệch tier giữa Sales và CS là lỗi đồng bộ — chặn WON hoàn tất cho đến khi khớp |
| BR-SALES-502 | Đề xuất chuyển tier trong kỳ theo: doanh thu thực tế của hợp đồng + số TKQC active + churn risk (health score); trình tự: bên vận hành đề xuất → SM (SALES_L4) + đầu mối vận hành đồng thuận → GDKD (SALES_L5) duyệt SLA 3 ngày làm việc; mọi thay đổi có lý do + audit log. Lưu ý vai: `[KXN-13]` đã chốt bỏ vai CS — trách nhiệm đề xuất gán cho AM phụ trách khách (OPS_AM); "CS TL" trong nguồn quy về AM Lead, ghi assumption chờ tổ chức thực tế xác nhận | Đề xuất thiếu đồng thuận không tới được GDKD; quá SLA 3 ngày escalate tự động |
| BR-SALES-503 | Rà soát quý: GDKD rà win rate theo tier + độ lệch điểm CQ vs kết quả thực; hiệu chỉnh ngưỡng/trọng số phải GDKD trình BOD — không chỉnh tại chỗ; tham số version hóa effective-dated, không sửa quá khứ; hệ quả tier giữ theo KXN-8 (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng; CQ 30/25/20/15/10) | Sửa tham số tại chỗ bị chặn máy; version mới không hồi áp cho deal/lead đã chấm |
| BR-SALES-402/501 | Gate 2 (nạp trước 100% NSQC, SLA 4h) là điều kiện đi kèm điểm WON; khách strategic BOD-sponsored vẫn phải có qualifiedTier để phục vụ vận hành (template, SLA, vòng sửa) — nhãn riêng không thay tier | WON thiếu Gate 2 không kích hoạt đồng bộ tier; khách BOD-sponsored thiếu tier bị chặn ở Gate 1 |
| BR-SALES-203/301 | Anti-duplicate và scoring 2 lần (FEAT-ERP-CRM-001/003) bảo đảm tier gốc đáng tin trước khi chuyển giao; UPSELL theo file 06 §8: AM/SE phát hiện cơ hội → AM soạn đề xuất trong 24h → Accepted nhỏ điều chỉnh project hiện tại (budget) / Accepted lớn tạo project mới + `parentProjectId` / Declined lưu lại theo dõi, không ép buộc | Cơ hội upsell không ghi nhận trên hệ thống trong 24h không được theo dõi; Accepted lớn không có parent link bị chặn |

**Quy tắc bổ sung:** luồng hoàn thiện chu trình đề xuất chuyển tier với bên vận hành là phạm vi Phase2 (theo A0 sales.md) — MVP bắt buộc có đồng bộ nguyên trạng + tham số effective-dated; lead cũ quay lại ≤180 ngày giữ lịch sử scoring (BR-SALES-103) để rà quý có dữ liệu so sánh liên tục.

---

## 4. Phân Quyền

Chuyển tier là thay đổi dữ liệu có hệ quả thương mại (template, SLA, hoa hồng theo cấp) nên quyền chỉnh nằm ở GDKD, quyền đề xuất nằm ở hai phía làm việc với khách; không ai tự đổi tier của khách trong kỳ.

| Hành động | SALES_L2 | SALES_L3 | SALES_L4 (SM) | SALES_L5 (GDKD) | OPS_AM | SYS_ADMIN |
|-----------|----------|----------|---------------|-----------------|--------|-----------|
| Xem tier khách (phạm vi của mình) | ✅ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ (khách phụ trách) | ❌ |
| Đề xuất chuyển tier trong kỳ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Đồng thuận/không đồng thuận đề xuất | ❌ | ❌ | ✅ | ❌ | ✅ (đầu mối vận hành) | ❌ |
| Duyệt/từ chối chuyển tier (SLA 3 ngày) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Ghi nhận cơ hội upsell | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Soạn đề xuất upsell (SLA 24h) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xem dashboard win rate + độ chính xác scoring | ❌ | ❌ | ✅ (phòng) | ✅ | ❌ | ❌ |
| Xem dashboard cho BOD | ❌ | ❌ | ❌ | ✅ (chuẩn bị hồ sơ trình BOD) | ❌ | ❌ |
| Sửa tham số ngưỡng/trọng số tại chỗ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ GDKD tạo version mới trình BOD; SYS_ADMIN triển khai cấu hình đã duyệt) |

**Lưu ý:** GDKD là vị trí quy hoạch tạm BOD kiêm nhiệm — quyền thực thi theo mã vai; khi GDKD đồng thời là người trình BOD (kiêm nhiệm), hệ thống ghi nhận cả hai hành động với hai audit entry tách biệt để bảo đảm vết phê duyệt.

---

## 5. Trường Hợp Đặc Biệt

- **Khách BOD-sponsored với tier thấp bất thường:** vẫn phải có qualifiedTier và được chuyển nguyên trạng cho CS; nhãn strategic hiển thị song song để vận hành ưu tiên tài nguyên nhưng không tự nâng tier — nâng tier vẫn phải qua luồng đề xuất đầy đủ.
- **Đề xuất nâng tier ngay sau WON vì doanh thu bùng nổ:** cho phép đề xuất trong kỳ (không chờ quý); dữ liệu tự điền từ CORE (doanh thu thực tế, số TKQC active); nếu SM đồng thuận và GDKD duyệt sớm hơn SLA 3 ngày thì hiệu lực áp dụng từ thời điểm duyệt.
- **Churn risk (health score) <60 đỏ:** health score là đầu vào đề xuất (nguồn tham chiếu 09 §7 — hệ số thành phần và quy tắc hiệu chỉnh "không dùng portal" thuộc phân hệ OPS); luồng tier chỉ đọc giá trị, không tính lại — nếu nguồn chưa sẵn sàng, form hiển thị "chưa có dữ liệu health score" và GDKD vẫn duyệt được kèm ghi chú rủi ro `[KXN-9]` phạm vi TMS/tương lai còn mở.
- **Upsell Accepted lớn:** tạo project mới với `parentProjectId` trỏ về project gốc — nối về lifecycle chính như project mới (Initial Brief rút gọn nếu khách tái ký, không bỏ Gate 1/Gate 2); Accepted nhỏ chỉ điều chỉnh budget project hiện tại.
- **Upsell Declined:** lưu opportunity + lý do + thời điểm, theo dõi tín hiệu sau (re-check khi health score/KPI thay đổi), không ép buộc khách; SM review danh sách Declined trong kỳ rà quý để đánh giá cơ hội bị bỏ lỡ.
- **Thay đổi tham số giữa kỳ có deal đang chấm:** deal tiếp tục dùng version tại thời điểm kích hoạt chấm (effective-dated); version mới chỉ áp cho lead kích hoạt chấm sau thời điểm hiệu lực — dashboard ghi rõ ranh giới version khi so win rate hai kỳ.
- **GDKD kiêm nhiệm BOD duyệt chính sách do chính mình trình:** cho phép (cơ chế kiêm nhiệm vai) nhưng hai bước trình/duyệt phải hai audit entry tách biệt với thời điểm khác nhau; kiểm toán quý đọc được chuỗi quyết định đầy đủ.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu chuyển tier (`tier_change_requests`); kèm vòng đời tham số (`scoring_param_versions`) và cơ hội upsell (`upsell_opportunities`).

**Sơ đồ trạng thái:**
```
Tier request: [DRAFT] ──(gửi)──► [PROPOSED] ──(SM + AM Lead đồng thuận)──► [CO_SIGNED]
   CO_SIGNED ──(GDKD duyệt, SLA 3 ngày)──► [APPROVED] ──(hiệu lực)──► [EFFECTIVE]
   CO_SIGNED ──(GDKD từ chối)──► [REJECTED]           PROPOSED ──(quá hạn không đồng thuận)──► [EXPIRED]
Param version: [DRAFT] ──(GDKD trình)──► [SUBMITTED_TO_BOD] ──(BOD duyệt)──► [EFFECTIVE (effective_from)] | [REJECTED]
Upsell: [OPEN] ──(đề xuất 24h)──► [SENT_TO_CLIENT] ──► [ACCEPTED_SMALL | ACCEPTED_LARGE | DECLINED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Gửi đề xuất | `PROPOSED` | OPS_AM | Đủ 3 căn cứ: doanh thu thực tế, số TKQC active, churn risk (hoặc ghi chú thiếu) |
| `PROPOSED` | Đồng thuận 2 phía | `CO_SIGNED` | SALES_L4 + AM Lead | Cả 2 ghi nhận trên hệ thống, không đồng thuận miệng |
| `CO_SIGNED` | GDKD duyệt | `APPROVED` → `EFFECTIVE` | SALES_L5 | SLA 3 ngày làm việc; lý do bắt buộc; audit log |
| `CO_SIGNED` | GDKD từ chối | `REJECTED` | SALES_L5 | Lý do bắt buộc; đề xuất lưu lịch sử |
| `PROPOSED` | Quá hạn đồng thuận | `EXPIRED` | Hệ thống | SLA clock hết; cảnh báo hai phía |
| `DRAFT` (param) | GDKD trình BOD | `SUBMITTED_TO_BOD` | SALES_L5 | Đối chiếu cũ/mới đính kèm; không sửa tham số đang chạy |
| `SUBMITTED_TO_BOD` | BOD duyệt | `EFFECTIVE` | BOD_CEO | `effective_from` phải là tương lai; không hồi áp quá khứ |
| `OPEN` (upsell) | AM soạn + gửi KH | `SENT_TO_CLIENT` | OPS_AM | SLA 24h từ khi phát hiện cơ hội |
| `SENT_TO_CLIENT` | KH quyết | `ACCEPTED_SMALL` / `ACCEPTED_LARGE` / `DECLINED` | OPS_AM ghi nhận | Accepted lớn → project mới + `parentProjectId`; Declined lưu theo dõi |

**Quy tắc:** `EFFECTIVE`, `REJECTED`, `EXPIRED`, `DECLINED` là trạng thái kết thúc của từng yêu cầu (có thể mở yêu cầu mới); tier hiện hành tại bất kỳ thời điểm nào truy được qua chuỗi version; mọi chuyển trạng thái có audit log bất biến.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `client_tiers` | `client_id`, `tier` (A–E), `tier_source` (sales/adjusted), `effective_from`, `won_deal_id` | FK → `clients`, `deals` | Tier hiện hành; chuyển nguyên trạng từ qualifiedTier tại WON |
| `tier_change_requests` | `client_id`, `current_tier`, `proposed_tier`, `revenue_actual`, `active_adaccounts`, `health_score_ref`, `state`, `co_signers[]`, `decided_by`, `decision_reason` | FK → `clients`, `users` | SLA 3 ngày GDKD; lý do bắt buộc |
| `scoring_param_versions` | `version`, `thresholds` (1.5/2.0/3.0/3.5), `cq_weights` (30/25/20/15/10), `effective_from`, `submitted_by`, `bod_decision` | — | Effective-dated; GDKD trình BOD; dùng chung với FEAT-ERP-CRM-003 |
| `quarterly_reviews` | `quarter`, `win_rate_by_tier`, `cq_accuracy_deviation`, `prepared_by`, `bod_submission_ref` | FK → `scoring_param_versions` | Chu trình quý GDKD; nguồn dashboard |
| `upsell_opportunities` | `client_id`, `detected_by`, `type`, `proposal_sent_at`, `outcome`, `parent_project_id`, `notes` | FK → `clients`, `projects` | Theo file 06 §8; Accepted lớn → project mới + parent link |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết ở Phase 5. Mỗi scenario map về REQ-SALES-005.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đồng bộ nguyên trạng tại WON | Deal WON với qualifiedTier = D (đã khóa) | WON hoàn tất (đủ Gate 2) | `client_tiers` ghi tier D cho khách, không có bước nhập lại; OPS_AM thấy đúng tier D | [ ] |
| SC-002: Đề xuất thiếu đồng thuận | AM gửi đề xuất nâng tier | SM chưa đồng thuận | Yêu cầu ở `PROPOSED`, không tới GDKD; SLA clock hiển thị | [ ] |
| SC-003: GDKD duyệt đúng SLA | Đề xuất đã CO_SIGNED | GDKD duyệt trong 3 ngày làm việc kèm lý do | Tier mới `EFFECTIVE` từ thời điểm duyệt; audit log đầy đủ | [ ] |
| SC-004: Tham số không hồi áp | Version ngưỡng mới hiệu lực 01/10 | Lead chấm ngày 20/09 và deal đang chạy | Vẫn dùng version cũ tại thời điểm chấm; dashboard ghi ranh giới version | [ ] |
| SC-005: Upsell đúng SLA 24h | AM phát hiện cơ hội mở rộng 10:00 ngày 01 | AM soạn đề xuất | Đề xuất gửi khách trước 10:00 ngày 02; accepted lớn tạo project mới với `parentProjectId` | [ ] |
| SC-006: Rà quý trình BOD | Kết thúc Q3 với win rate lệch theo tier | GDKD xem dashboard, tạo version mới | Version ở `SUBMITTED_TO_BOD` với đối chiếu cũ/mới; không có sửa tại chỗ nào được ghi | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (đồng bộ tier, health score đầu vào) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (luồng đề xuất tier, dashboard rà quý) | `phase4-ux/bcerp-web/crm-pipeline/tier-review.md` |
| Nguồn quy trình UPSELL | `documents/quy-trinh-lam-viec/06_Giai_doan_5_Ket_thuc_Closed_Renew.md` (v1.1 §8) |
| Hằng số (tier, health score tham chiếu) | `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 §1, §7) |
