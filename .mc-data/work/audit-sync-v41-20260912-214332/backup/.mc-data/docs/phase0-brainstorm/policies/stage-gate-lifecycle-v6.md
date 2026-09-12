# Stage-Gate & Điều Kiện Chuyển Pha Lifecycle V6.0 — BCERP

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Bán hàng / Vận hành
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** marketing-expert (CMO / Strategic Planner OPS_PLAN — kiêm quyền Trưởng phòng Vận hành)
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `00-company-context.md` (bối cảnh BC Agency)
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design)

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Toàn bộ lead/deal đi qua đủ 10 stage Lifecycle V6.0 (Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → EVALUATION → PROPOSAL → WON → DEPLOY); mọi vai trò SDR/AM, SM, Planner, GM.
- **Không áp dụng cho:** Lead demo nội bộ; deal hủy trước Gate 1 (chỉ lưu hồ sơ).
- **Effective từ:** Ngày go-live module Sales & PMS của BCERP.
- **Nguyên tắc nền tảng:** *"Không ghi nhận vào PMS = Không tồn tại"* — mọi lead, deal, meeting, chữ ký, quyết định gate phải nằm trên PMS.

---

## 2. Nội Dung Chính Sách

### 2.1. Bảng Stage-Gate — Entry/Done Criteria (machine-checkable)

| Stage | Điều kiện chuyển tiếp (Done criteria) | Trách nhiệm |
|-------|--------------------------------------|--------------|
| **Raw Data** | Lead nhập PMS đủ trường tối thiểu (tên công ty, người liên hệ, email/SĐT, nguồn lead) + qua anti-duplicate (email/SĐT/website/MST không trùng lead đang mở) | SDR/AM |
| **Initial Brief** | Trong **2h** từ Raw Data: đủ 3 trường bắt buộc — **Ngân sách, Sản phẩm/dịch vụ, Nhu cầu** | SDR/AM |
| **AUTO SCORING** | Hệ thống tự chạy khi đủ Initial Brief: **K1–K5 knockout** (fail bất kỳ → tự loại), **K6–K12 flag** (cảnh báo, không chặn), **CQ**; điểm hiển thị trên PMS | Hệ thống |
| **First Meeting** | Meeting notes đã ghi vào PMS (không notes = meeting không được công nhận) | AM |
| **QUALIFIED (Gate 1)** | AM chấm **qualifiedTier** + **SM ký Go/No-Go**; SLA **1 ngày làm việc** | AM + SM |
| **LEAD (Gate 2)** | **Handoff Package 5 nhóm đủ 100%** + SM ký + **AM xác nhận trong SLA 4h** | SM + AM |
| **EVALUATION** | Brand Safety **7/7 pass** (fail bất kỳ → dừng) + **Weighted ≥3.5**; có Internal Quick Meeting và Second Meeting đủ **5 output** | Planner |
| **PROPOSAL** | Tier B/C: **8–12 trang, AM soạn, vòng sửa ≤2**; Tier D/E: **15–25 trang, Planner soạn, vòng sửa ≤4**; Rehearsal xong trước Pitching; **GM duyệt** trước khi gửi; sau Pitching có Quotation | AM/Planner + GM |
| **WON** | HĐ/LOI ký; cập nhật PMS trong **24h**; hệ thống sinh dự án + **AM xác nhận capacity** | AM + Hệ thống |
| **DEPLOY** | **✅ Đã chốt 12/09 (KXN-10 — theo Lifecycle v2.3):** D+0 timestamp (`dStartDate`/`paymentConfirmedAt`) set sau tiền vào TK + **LOI hoặc HĐ đã ký** (HĐ đầy đủ ≤7 ngày, cảnh báo ngày 3); checklist tài nguyên hoàn tất **trước D+4**; Planning TT→ĐH→AD hoàn tất trong ngày D+0; Kick-off nội bộ D+1/D+2 không lùi; **6 Communication Rules được KH ký tại Kick-off D+3** (Hard Gate); đủ tài nguyên (pixel, quyền ad account) trước ONGOING **D+5** | Accountant + AM |

### 2.2. Quy Tắc Cứng

1. **Hard block chuyển pha:** Cấm chuyển stage khi thiếu bất kỳ điều kiện trên; nút chuyển bị vô hiệu trên UI và bị từ chối ở tầng API.
2. **SLA từng gate + escalation tự động:** Quá SLA bất kỳ gate → hệ thống tự escalate lên cấp trên trực tiếp và ghi log.
3. **Một nguồn sự thật:** Trạng thái, điểm scoring, chữ ký, vòng sửa chỉ ghi nhận trên PMS; mọi thay đổi lưu audit log bất biến.

### 2.3. Ghi Chú — Deploy Phase — ✅ ĐÃ CHỐT 12/09/2026 (KXN-10)

> **Cập nhật 12/09/2026 (bản 1.1):** đã tìm thấy nguồn đầy đủ cho Deploy — `documents/BC_Agency_Project_Lifecycle (1).html` (Project Lifecycle **v2.3**) mô tả chi tiết D+0→D+5; nội dung tái dựng tại **`documents/quy-trinh-lam-viec/04_Giai_doan_3_Trien_khai_Deploy.md`**.
>
> **Cập nhật 12/09/2026 (bản 1.2 — quyết định chủ dự án):** **KXN-10 ĐÃ CHỐT — phê chuẩn Deploy tái dựng từ v2.3 làm quy định chính thức** (kèm KXN-5: D+0 cần LOI/HĐ đã ký; KXN-11: 4 Communication Rules còn lại có bản dự thảo duyệt nội bộ). Tiêu chí DEPLOY ở bảng 2.1 **đã thay bằng done-criteria từ v2.3** (đợt cập nhật này). **DI-003/SO3-04 đã đóng.** Chi tiết: `documents/quy-trinh-lam-viec/10_...md` §8.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Deal chiến lược do CEO/GM chỉ định:** SM được override knockout K1–K5, bắt buộc ghi lý do bằng văn bản + GM phê duyệt lại; log bất biến.
- **Borderline scoring (Weighted 3.0–3.49):** Không tự động pass; chỉ tiếp tục sau **thẩm định thủ công 4h** có kết luận trên PMS.
- **Khách hàng hiện hữu tái ký:** Được rút gọn Initial Brief nhưng không bỏ Gate 1 và Gate 2.
- **Ngoài giờ/lễ:** SLA tính theo giờ làm việc cấu hình trên hệ thống.
- **Fail Brand Safety:** Không có ngoại lệ — dừng ngay, không sang PROPOSAL.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn (SLA) |
|-----------|----------------|----------------|
| Gate 1 QUALIFIED — Go/No-Go | Sales Manager (SM) | 1 ngày làm việc |
| Gate 2 LEAD — xác nhận nhận Handoff Package | AM (sau khi SM ký) | 4h |
| Borderline Weighted 3.0–3.49 | Người thẩm định do SM chỉ định | 4h |
| Proposal duyệt gửi khách hàng | GM | 1 ngày làm việc |
| Override knockout K1–K5 | GM (xác nhận đề nghị của SM) | 1 ngày làm việc |
| WON — xác nhận capacity & sinh dự án | AM | 24h |
| Mọi gate quá SLA | Escalation tự động lên cấp trên trực tiếp | Tức thời |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Hard block chuyển stage khi chưa thỏa done criteria (chặn cả UI và API) | Validation | PMS Pipeline | MUST |
| Anti-duplicate khi tạo lead (so khớp email/SĐT/website/MST với lead đang mở) | Validation | CRM Lead | MUST |
| Đồng hồ SLA 2h Initial Brief, cảnh báo và escalate tự động quá hạn | Notification | PMS | MUST |
| Engine auto-scoring K1–K5 knockout, K6–K12 flag, CQ, hiển thị điểm trên PMS | Business Rule | Scoring Engine | MUST |
| Bắt buộc meeting notes trước khi mở stage QUALIFIED | Validation | PMS Activity | MUST |
| E-approval cho chữ ký SM (Gate 1, Gate 2) và GM (Proposal) | Approval Workflow | PMS | MUST |
| Checklist Handoff Package 5 nhóm — chặn Gate 2 nếu <100% | Validation | PMS Handoff | MUST |
| Brand Safety 7 tiêu chí (all-pass) + Weighted ≥3.5, route borderline 3.0–3.49 sang hàng đợi thẩm định 4h | Business Rule | Evaluation | MUST |
| Kiểm soát số trang theo tier (8–12 / 15–25) và vòng sửa (≤2 / ≤4), chặn vượt hạn | Validation | Proposal/Document | MUST |
| WON cập nhật 24h + tự sinh dự án + capacity check + xác nhận AM | Automation | Sales → Delivery | MUST |
| Audit log bất biến mọi chuyển stage, chữ ký, override, escalation | Audit Trail | PMS | MUST |
| Deploy: launch checklist + deliverable plan + reporting frequency dạng checklist bắt buộc | Checklist | Delivery | SHOULD |
| Dashboard SLA compliance và gate pass rate theo stage/nhân sự | Reporting | PMS | SHOULD |

**Cross-policy dependencies:** Phụ thuộc và cần triển khai cùng: policy **Lead Scoring & Qualification** (K1–K12, CQ, qualifiedTier), policy **Brand Safety & Evaluation Criteria** (7 tiêu chí + weighted), chuẩn **Handoff Package 5 nhóm**, chuẩn **Proposal Tier & Template** (tier B–E, số trang, vòng sửa), **SLA & Escalation Matrix** chung. Nguyên tắc PMS single-source-of-truth là điều kiện tiên quyết.

---

## 6. Xác Nhận

> **📝 User xác nhận** — Chính sách này có phản ánh đúng thực tế doanh nghiệp không?

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách (Stage-Gate + quy tắc cứng) | Đúng / Cần sửa | |
| Tiêu chí DEPLOY | Đúng / Cần sửa | ✅ Đã chốt 12/09 (KXN-10) theo v2.3 — bảng 2.1 bản 1.2 |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | marketing-expert | Khởi tạo — 10 stage, hard gate, SLA + escalation, đề xuất tiêu chí DEPLOY |
| 1.1 | 12/09/2026 | main-conversation (documents-rebuild) | Ghi chú §2.3 cập nhật: tìm thấy nguồn Deploy (Lifecycle v2.3) — tham chiếu `documents/quy-trinh-lam-viec/`; tiêu chí DEPLOY chưa đổi, chờ chủ dự án chốt KXN-10 |
| 1.2 | 12/09/2026 | main-conversation (post-audit decisions) | **KXN-10 chốt: Deploy v2.3 phê chuẩn chính thức** — bảng 2.1 DEPLOY thay bằng done-criteria từ v2.3 (D+0 cần LOI/HĐ theo KXN-5; 6 Rules ký tại D+3 theo KXN-11). DI-003 đóng |
