# Tính Năng: Chuyển tier Sales → CS & rà soát quý tier

> **Dựa trên:** REQ-SALES-005 trong `phase1-business/departments/sales/sales.md` (Phần A)
> **Phân hệ:** CRM & Lead Pipeline V6.0 (SYS-CORE-BACKEND)
> **Module:** MOD-CRM-PIPELINE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/quy-trinh-lam-viec/06_Giai_doan_5_Ket_thuc_Closed_Renew.md` (v1.1 — §8 UPSELL), `documents/quy-trinh-lam-viec/09_Phu_luc_Hang_so_Quy_trinh.md` (v1.1 — §7 Client Health Score)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/[screen-group].md`, `phase5-implementation/tasks/SYS-CORE-BACKEND/MOD-CRM-PIPELINE/FEAT-CORE-CRM-005-impl.md`
>
> **ID:** FEAT-ID từ lane `core-backend--CRM-PIPELINE`. REQ-SALES-005 fan-out 2 hệ thống — bản này là bản riêng cho SYS-CORE-BACKEND (đồng bộ tier nguyên trạng + tham số effective-dated); đối ứng SYS-BCERP-WEB là luồng đề xuất + dashboard chu trình quý.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CRM-005 |
| Module | MOD-CRM-PIPELINE |
| Yêu cầu nghiệp vụ | REQ-SALES-005 (Chuyển tier Sales → CS & rà soát quý tier) |
| Người dùng liên quan | SALES_L5 (GDKD — duyệt chuyển tier, rà quý, trình BOD), SALES_L3 (SM — đồng thuận đề xuất), OPS_AM (bên CS nhận tier — đồng thuận; registry không có vai CS riêng sau DI-006), SALES_L4, SYS_ADMIN (cấu hình phiên tham số) |
| Độ ưu tiên | Trung bình (MEDIUM — quan trọng, chu kỳ kỳ hạn) |
| Giai đoạn | Giai đoạn 1 (MVP — đồng bộ nguyên trạng + tham số + dữ liệu rà quý); luồng đề xuất chuyển tier trong kỳ đầy đủ từ Phase2 |
| Phụ thuộc | Không có phụ thuộc chéo module (cross-dependencies = không có). Trong module: đọc tier đã khóa từ FEAT-CORE-CRM-003, kết quả Gate từ FEAT-CORE-CRM-004; WON trigger từ stage machine FEAT-CORE-CRM-002 |
| Ghi chú Expert (A7) | Chưa có điều chỉnh nào từ Expert Review được ghi nhận trong `sales.md` Mục A7 tại thời điểm lập spec (12/09/2026) — giữ nguyên nội dung Phần B do sales-expert review |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Bảo đảm tier khách hàng sống trọn vòng đời, không đứt gãy tại điểm chốt: khi deal WON, tier do Sales chấm và Gate 1 khóa được **chuyển nguyên trạng sang phía CS** — không nhập lại, không "làm mới" theo cảm tính bên nhận. Đồng thời cung cấp chu trình hiệu chỉnh tier có kiểm soát (đề xuất trong kỳ dựa trên doanh thu thực tế, số TKQC active, churn risk) và **rà soát quý** bắt GDKD đối chiếu win rate theo tier + độ lệch điểm CQ vs kết quả thực; mọi thay đổi tier có lý do + audit log, mọi thay đổi tham số version hóa effective-dated, GDKD trình BOD, không chỉnh tại chỗ.

**Phạm vi:**
- Bao gồm: dịch vụ đồng bộ tier nguyên trạng tại WON; tham số tier/scoring version hóa effective-dated (không sửa quá khứ); luồng đề xuất chuyển tier trong kỳ — CS đề xuất → SM + CS đồng thuận → GDKD duyệt SLA 3 ngày làm việc (đầy đủ từ Phase2; MVP lưu dữ liệu đầu vào: doanh thu thực tế, số TKQC active, churn risk/health score); báo cáo rà quý tự động (win rate theo tier, độ chính xác scoring, gate pass rate, danh sách override); tích hợp UPSELL theo quy-trinh v1.1 file 06 §8 (cơ hội trong ONGOING quay về pipeline như project mới có `parentProjectId`).
- Không bao gồm: chấm điểm/tier ban đầu (FEAT-CORE-CRM-003); chữ ký Gate (FEAT-CORE-CRM-004); Client Health Score tính weekly phía vận hành (chỉ đọc kết quả làm đầu vào); dashboard/luồng đề xuất trên WEB (counterpart); push GDKD trên MOBILE (Phase2); quotation/tái ký bảng giá (REQ-SALES-006).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: đồng bộ và tham số là domain service — stories mô tả qua API; mọi ràng buộc enforce ở service layer với audit log + tenant isolation.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (tier sync service) | Tự chuyển tier nguyên trạng cho CS ngay khi deal WON — không nhập lại | CS vận hành đúng tier từ ngày đầu: template proposal, SLA, vòng sửa không lệch tại bàn giao |
| 2 | OPS_AM (CS nhận) | Đọc tier + lịch sử scoring khách qua API ngay sau WON | Chuẩn bị đúng định mức phục vụ (Tier D/E được ưu tiên tài nguyên) |
| 3 | OPS_AM (CS đề xuất) | Tạo đề xuất chuyển tier kèm dữ liệu tự động (doanh thu thực tế, số TKQC active, churn risk) | Đề xuất có căn cứ số học, không theo cảm tính |
| 4 | SALES_L3 (SM) | Đồng thuận/không đồng thuận đề xuất của CS qua API với lý do | Không có thay đổi tier đơn phương — cả hai bên cùng thấy hợp lý |
| 5 | SALES_L5 (GDKD) | Duyệt/từ chối đề xuất trong SLA 3 ngày làm việc, kèm lý do + audit log; chạy rà quý: win rate theo tier + độ lệch CQ vs kết quả thực | Kiểm soát tập trung thay đổi tier; scoring được kiểm chứng định kỳ |
| 6 | SALES_L5 (GDKD) | Trình BOD hiệu chỉnh ngưỡng tier/trọng số CQ bằng phiên tham số mới effective-dated | Thay đổi chính sách có version, không sửa quá khứ, không chỉnh tại chỗ |
| 7 | SALES_L3 (SM) | Ghi nhận cơ hội UPSELL từ ONGOING; hệ thống hỗ trợ opportunity record; accepted lớn tự sinh project mới nối `parentProjectId` | Cơ hội mở rộng không rơi ngoài hệ thống — đúng quy-trinh v1.1 file 06 §8 |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, enforce ở tầng service của Core Backend (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-000 | **Hard gate "không ghi nhận = không tồn tại":** đề xuất chuyển tier, đồng thuận, quyết định GDKD, rà quý, upsell record phải có bản ghi trên hệ thống trước khi phát sinh hệ quả | API không nhận thay đổi tier ngoài luồng có bản ghi; báo cáo rà quý chỉ đếm thay đổi có audit |
| BR-SALES-501 | **Chuyển tier nguyên trạng tại WON:** tier (đã khóa sau Gate 1) chuyển nguyên trạng cho CS — không nhập lại, không "đánh giá lại" tại điểm bàn giao; `qualifiedTier` là đầu vào bắt buộc của vận hành (template proposal, SLA, vòng sửa) | API sync chỉ đọc tier đã khóa; nhập tay tier phía CS bị từ chối; thiếu tier hợp lệ tại WON là lỗi dữ liệu chặn hoàn tất WON |
| BR-SALES-502 | **Đề xuất chuyển tier trong kỳ (luồng đầy đủ Phase2; MVP lưu dữ liệu đầu vào):** căn cứ (1) doanh thu thực tế của hợp đồng, (2) số TKQC active, (3) churn risk (health score); trình tự: CS đề xuất → SM + CS đồng thuận → GDKD duyệt SLA 3 ngày làm việc; **mọi thay đổi tier có lý do + audit log**. Vai CS trong registry 18 vai: `OPS_AM` (DI-006 — không có vai CX riêng) | Đề xuất thiếu 1 trong 3 căn cứ bị từ chối; GDKD duyệt không lý do bị chặn; quá SLA escalate; thiếu đồng thuận không trình duyệt được |
| BR-SALES-503 | **Rà soát quý:** GDKD rà win rate theo tier + độ lệch điểm CQ vs kết quả thực; hiệu chỉnh ngưỡng tier/trọng số CQ phải GDKD trình BOD — **không chỉnh tại chỗ**; tham số version hóa **effective-dated, không sửa quá khứ**; bản chấm lịch sử giữ snapshot phiên tham số đã dùng (nối FEAT-CORE-CRM-003) | Tham số thiếu version/effective_from không thể ghi; sửa kết quả chấm quá khứ bị chặn cứng; phiên mới chỉ tác dụng từ effective_from |
| BR-CRM-005-04 | **Dữ liệu rà quý tự động:** dashboard win rate theo tier + độ chính xác scoring theo quý tính từ dữ liệu pipeline (stage log, kết quả chấm, gate pass rate, override/escalation log) — **cấm nhập tay chỉ số rà quý** | Chỉ số nhập tay không được công nhận trong báo cáo GDKD/BOD; nguồn số liệu duy nhất là engine |
| BR-CRM-005-05 | **UPSELL theo quy-trinh v1.1 file 06 §8:** AM ghi nhận cơ hội trong ONGOING → soạn đề xuất trong 24h (SLA không gia hạn) → KH quyết: Accepted nhỏ = điều chỉnh project hiện tại (budget); Accepted lớn = tạo project mới + `parentProjectId` nối lifecycle chính như project mới; Declined = lưu lại theo dõi tín hiệu, không ép buộc; Done = opportunity đã ghi nhận + quyết định rõ + action trigger nếu accepted | Cơ hội không record trên hệ thống không tồn tại; đề xuất quá 24h breach SLA; project upsell lớn thiếu `parentProjectId` không được tạo |
| BR-CRM-005-06 | **Bối cảnh tier (thượng nguồn — đọc từ FEAT-CORE-CRM-003/004):** 5 tier A–E theo KXN-1 (A <1.5 AUTO LOST → E ≥3.5 bypass); `qualifiedTier` chốt sau Full Brief, khóa sau Gate 1 (KXN-2); khách strategic BOD-sponsored **vẫn phải có `qualifiedTier`**; trọng số CQ 30/25/20/15/10; Gate 1 SLA 1 ngày / Gate 2 nạp trước 100% NSQC + AM 4h; proposal B/C = AM 8–12 trang ≤2 vòng, D/E = Planner 15–25 trang ≤4 vòng (KXN-8) là tham số do tier service phát | Không thể tạo khách "ngoài tier"; nhãn BOD-sponsored không thay thế tier; cấm hardcode nhãn/định mức tier |
| BR-CRM-005-07 | **Tenant isolation + audit toàn phần:** tier sync, đề xuất, duyệt, tham số cách ly theo tenant; audit log bất biến WORM cho mọi thay đổi tier và phiên tham số | Truy vấn xuyên tenant bị từ chối; thao tác không audit không thể commit |

---

## 4. Phân Quyền

| Hành động | SALES_L3 (SM) | SALES_L4 (TPKD) | SALES_L5 (GDKD) | OPS_AM (CS) | SYS_ADMIN |
|-----------|----------------|------------------|------------------|--------------|-----------|
| Xem tier + lịch sử scoring khách (phạm vi mình) | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ (khách nhận bàn giao) | ✅ |
| Đọc tier nguyên trạng sau WON | ✅ | ✅ | ✅ | ✅ | ✅ |
| Nhập tay tier phía CS | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạo đề xuất / đồng thuận chuyển tier | ✅ (đồng thuận) | ❌ | ❌ | ✅ (đề xuất) | ❌ |
| Duyệt/từ chối chuyển tier (SLA 3 ngày) | ❌ | ❌ | ✅ | ❌ | ❌ |
| Chạy rà quý / xem dashboard win rate + độ chính xác scoring | ❌ (xem nhóm) | ❌ | ✅ | ❌ | ✅ (vận hành) |
| Trình BOD hiệu chỉnh ngưỡng/trọng số | ❌ | ❌ | ✅ (duy nhất) | ❌ | ❌ (thực thi sau duyệt) |
| Ghi nhận opportunity UPSELL | ✅ (phối hợp AM) | ❌ | ✅ | ✅ (AM chủ trì) | ❌ |

> Quy ước vai: GDKD (`SALES_L5`) tạm `BOD_CEO`/`BOD_CFO_CTO` kiêm nhiệm — duyệt theo mã vai, sẵn sàng tách vai; sau DI-006 registry không có vai CS/CX riêng — bên CS dùng `OPS_AM` (`OPS_PLAN` nhận trách nhiệm CX Head đã gán lại). Không dùng `OPS_CX`/`FIN_COMPL`.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách strategic BOD-sponsored:** vẫn bắt buộc có `qualifiedTier` (Tier A xử lý theo luồng tư vấn K4 hoặc exception có duyệt) — nhãn riêng không phải lý do bỏ tier.
- **Đề xuất chuyển tier ngay trong kỳ WON:** hợp lệ — chu trình trong kỳ không chờ quý; nhưng dữ liệu đầu vào phải đủ thời lượng quan sát tối thiểu `[CẦN CHỐT SỐ — chưa có chính sách; đề xuất ≥1 chu kỳ báo cáo tháng, ghi theo tag giả định]`.
- **SM và CS không đồng thuận:** đề xuất đứng ở trạng thái chờ đồng thuận, không tới GDKD; GDKD yêu cầu làm rõ được nhưng không duyệt thay hai bên đồng thuận.
- **GDKD quá SLA 3 ngày:** escalate tự động BOD + log; đề xuất không tự hiệu lực khi hết SLA — "im lặng = duyệt" bị cấm tuyệt đối ở luồng này.
- **Hiệu chỉnh tham số giữa quý:** phiên mới chỉ effective từ ngày duyệt; kết quả quá khứ không chấm lại tự động — bản chấm giữ snapshot phiên đã dùng.
- **Tier sau chuyển khác tier WON (chuyển trong kỳ):** lịch sử tier giữ đầy đủ (WON tier → tier hiện tại) với lý do từng lần; báo cáo rà quý so sánh phân phối tier theo thời gian.
- **UPSELL accepted lớn khi project gốc đang ONGOING:** project mới sinh nối `parentProjectId`; tier khởi điểm kế thừa tier hiện hành của khách (không chấm lại từ đầu) `[CẦN CHỐT SỐ — trình tự kế thừa tier chưa có quy định tường minh; suy ra như giả định từ cấu trúc parentProjectId của nguồn v2.3]`.
- **Nhiều đề xuất cùng một khách:** xử lý tuần tự theo thời gian tạo; đề xuất sau tham chiếu kết quả đề xuất trước; cấm hai đề xuất song song trái ngược.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity: TierChangeRequest (đề xuất chuyển tier trong kỳ) và TierParamSet (phiên tham số). Tier khách không phải state machine tự do — chỉ đổi qua request có phê duyệt hoặc đồng bộ nguyên trạng tại WON.*

**Entity:** TierChangeRequest

**Sơ đồ trạng thái:**
```
[WON] ──(sync tự động)──► [TIER_TRANSFERRED] (nguyên trạng)
[PROPOSED] ──(SM + CS đồng thuận)──► [CONSENSUS_REACHED] ──(GDKD duyệt · SLA 3 ngày)──► [APPROVED] ──► [TIER_UPDATED]
     │ (thiếu căn cứ)                      │ (một bên không đồng thuận)         │ (quá SLA → escalate BOD)
     ▼                                     ▼                                    ▼
[REJECTED_AT_ENTRY]                  [NO_CONSENSUS]                      [ESCALATED] ──(BOD duyệt)──► [APPROVED]
                                                                              │ (BOD không duyệt)
                                                                              ▼
                                                                          [DENIED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `WON` | Sync tự động tier | `TIER_TRANSFERRED` | Hệ thống | `qualifiedTier` ở trạng thái `LOCKED` (FEAT-CORE-CRM-003) |
| — | CS tạo đề xuất | `PROPOSED` | OPS_AM | Đủ 3 căn cứ (doanh thu thực tế + TKQC active + churn risk); lý do ban đầu ghi |
| `PROPOSED` | SM + CS đồng thuận | `CONSENSUS_REACHED` | SALES_L3 + OPS_AM | Cả hai xác nhận kèm ý kiến; thiếu một bên giữ `PROPOSED`/`NO_CONSENSUS` |
| `CONSENSUS_REACHED` | GDKD duyệt | `APPROVED` → `TIER_UPDATED` | SALES_L5, SLA 3 ngày làm việc | Lý do duyệt bắt buộc; audit log; quá SLA → `ESCALATED` |
| `CONSENSUS_REACHED` | GDKD từ chối | `DENIED` | SALES_L5 | Lý do từ chối bắt buộc |
| `ESCALATED` | BOD duyệt | `APPROVED` | BOD_CEO/BOD_CFO_CTO | Kèm nhật ký escalation; không duyệt → `DENIED` |
| `TIER_UPDATED` | — | Kết thúc (khởi điểm cho lần đề xuất sau) | — | Lịch sử tier đầy đủ WON tier → hiện tại |
| `TierParamSet` mới | BOD duyệt phiên | `ACTIVE` từ `effective_from` | GDKD trình — BOD duyệt — SYS_ADMIN áp | Version + effective_from bắt buộc; không sửa phiên cũ |

**Quy tắc:**
- Không quay về trạng thái trước; `NO_CONSENSUS` quay lại `PROPOSED` bằng bản ghi bổ sung mới (không sửa bản ghi cũ).
- `TIER_UPDATED` và `DENIED` là trạng thái kết thúc của một request; khách có nhiều request nối tiếp, mỗi request tham chiếu kết quả request trước.
- Không có cơ chế "im lặng = duyệt" — hết SLA chỉ sinh escalation, không tự hiệu lực; mọi chuyển trạng thái ghi audit log bất biến WORM, tenant isolation toàn bộ truy vấn.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `client_tier` | `client_id`, `tier` (A–E), `source` (won_sync/period_change/exception), `effective_from`, `locked_result_id` | FK → `client.id`, `scoring_result.id` | Tier hiện hành read-only cho mọi module; lịch sử đầy đủ |
| `tier_change_request` | `client_id`, `current_tier`, `proposed_tier`, `evidence` (revenue_actual, active_adaccounts, health_score), `state`, `proposed_by`, `consensus`, `decided_by`, `decided_at`, `reason` | FK → `client.id`, `users.id` ×3 | SLA GDKD 3 ngày làm việc; escalate BOD |
| `tier_param_set` | `version`, `effective_from`, `tier_thresholds` (1.5/2.0/3.0/3.5), `cq_weights` (30/25/20/15/10), `proposal_policy` (B/C: AM 8–12 trang ≤2 vòng; D/E: Planner 15–25 trang ≤4 vòng) | FK → tenant | GDKD trình — BOD duyệt — SYS_ADMIN áp; không hardcode |
| `quarterly_review_report` | `quarter`, `win_rate_by_tier`, `scoring_accuracy`, `gate_pass_rate`, `override_count`, `param_version_ref` | FK → `tier_param_set.id` | Tự tính từ dữ liệu engine — cấm nhập tay |
| `upsell_opportunity` | `client_id`, `source_project_id`, `type` (nhỏ/lớn), `proposal_due_at` (+24h), `decision`, `new_project_id` | FK → `client.id`, `project.id` ×2 | Theo file 06 §8; accepted lớn → `parentProjectId` |
| `tier_audit_log` | `entity`, `entity_id`, `actor`, `action` (sync/propose/consent/approve/deny/param_change), `before/after`, `at` | Polymorphic | WORM; bắt buộc mọi thay đổi tier/tham số |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đồng bộ tier nguyên trạng tại WON | Deal WON, `qualifiedTier` = Tier D đã khóa | Hệ thống hoàn tất WON | `client_tier` phía CS = Tier D nguyên trạng, không nhập tay; audit log ghi sync | [ ] |
| SC-002: Chặn nhập tay tier phía CS | OPS_AM muốn "đánh giá lại" tier sau nhận bàn giao | OPS_AM gọi API ghi tier | API từ chối — tier chỉ đổi qua TierChangeRequest có phê duyệt | [ ] |
| SC-003: Đề xuất thiếu căn cứ bị từ chối | Đề xuất không kèm health score | CS gửi đề xuất | API từ chối ở entry kèm danh mục căn cứ thiếu; đủ 3 căn cứ mới vào `PROPOSED` | [ ] |
| SC-004: Chu trình đề xuất đầy đủ | Đề xuất đủ căn cứ, SM + CS đồng thuận | GDKD duyệt trong 3 ngày làm việc | Tier cập nhật kèm lý do + audit; quá SLA → escalate BOD; thiếu một bên đồng thuận không trình duyệt được | [ ] |
| SC-005: Rà quý tự động | Hết quý, dữ liệu pipeline đầy đủ | GDKD mở báo cáo rà quý | Win rate theo tier + độ lệch CQ vs thực + gate pass rate + override count tự tính từ engine | [ ] |
| SC-006: Tham số effective-dated | GDKD trình BOD đổi ngưỡng Tier C 2.0 → 2.1 | BOD duyệt phiên mới | Phiên mới `ACTIVE` từ `effective_from`; kết quả quá khứ giữ snapshot phiên cũ; không sửa phiên cũ được | [ ] |
| SC-007: BOD-sponsored vẫn có tier | Khách strategic gắn nhãn BOD-sponsored | Kiểm tra dữ liệu | `qualifiedTier` tồn tại hợp lệ; nhãn không thay thế tier; vận hành đọc đúng template/SLA/vòng sửa theo tier | [ ] |
| SC-008: UPSELL accepted lớn | AM phát hiện cơ hội trong ONGOING, KH chấp nhận quy mô lớn | AM ghi nhận decision | Project mới tự sinh nối `parentProjectId`; SLA soạn đề xuất 24h được đo; Declined lưu lại theo dõi | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-SALES-005 (đồng bộ nguyên trạng, đề xuất chuyển tier 3 căn cứ, rà quý GDKD trình BOD, dashboard win rate/độ chính xác scoring, UPSELL).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) client_tier, tier_change_request, tier_param_set, upsell | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (TierSyncService, TierChangeWorkflow, QuarterlyReport, UpsellService) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (WEB luồng đề xuất/dashboard, MOBILE push GDKD P2, scoring engine) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI luồng đề xuất + dashboard rà quý (kênh WEB — counterpart) | `phase4-ux/SYS-BCERP-WEB/MOD-CRM-PIPELINE/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/sales/sales.md` (B.5), `documents/quy-trinh-lam-viec/06_Giai_doan_5_Ket_thuc_Closed_Renew.md` §8 (UPSELL), `09_Phu_luc_Hang_so_Quy_trinh.md` §1 + §7 (Health Score) |
| Tính năng nối tiếp trong module | FEAT-CORE-CRM-003 (tier khóa), FEAT-CORE-CRM-004 (gate pass rate cho rà quý) |
