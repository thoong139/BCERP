# Phân loại khách hàng theo Tier A–E — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Bán hàng / Khách hàng
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** sales-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), policies: `bang-gia-chiet-khau-gross-margin.md`, `hoa-hong-sales-quota.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** mọi lead/khách hàng đi qua Pipeline V6.0 (Raw Data → Initial Brief → AUTO SCORING → First Meeting → QUALIFIED → LEAD → Pitching → Quotation → WON); mọi NVKD, SM, AM, Planner liên quan đến xử lý lead.
- **Không áp dụng cho:** khách hàng hiện hữu đã ký hợp đồng (chuyển sang cơ chế chuyển tier CS — mục 2.5); đối tác nhà mạng/đại lý (Google, TikTok, Yandex); lead spam/junk bị loại ở bước Knockout K1–K5.
- **Effective từ:** *(chờ user xác nhận)*

---

## 2. Nội Dung Chính Sách

### 2.1. Bộ tiêu chí CQ (Client Quality) — 5 tiêu chí, trọng số 30/25/20/15/10, thang điểm 1–5

Điểm tier do **AUTO SCORING** tính tự động từ dữ liệu brief; SM không được sửa điểm trực tiếp — chỉ bổ sung dữ liệu rồi cho chấm lại (mọi thay đổi ghi audit log).

| # | Tiêu chí | Trọng số | Thang 1 (thấp) → 5 (cao) |
|---|---------|---------|--------------------------|
| CQ1 | Quy mô ngân sách quảng cáo/dịch vụ | 30 | < 30 triệu/tháng → ≥ 500 triệu/tháng |
| CQ2 | Tiềm năng dài hạn (số TKQC tiềm năng, đa nhãn hàng, đa thị trường) | 25 | 1 TK đơn lẻ → mở rộng đa tài khoản đa nền tảng |
| CQ3 | Độ khớp ICP (FMCG, F&B, Retail, Beauty, B2B) với trục dịch vụ BC | 20 | Ngoài ICP → đúng trục dịch vụ chủ lực |
| CQ4 | Chất lượng thông tin & tính sẵn sàng hợp tác (brief, POC phản hồi) | 15 | Không liên hệ được → POC cấp quyết định, tài liệu đầy đủ |
| CQ5 | Uy tín & rủi ro thương hiệu (sản phẩm hợp pháp, gắn Knockout K1/K3) | 10 | Rủi ro cao → doanh nghiệp uy tín |

**Điểm CQ = Σ(trọng số × điểm) / 100** → thang 1.0–5.0. Thang tier **nghịch trực giác (A = tệ nhất, E = tốt nhất)** — hệ thống phải khóa logic bằng bộ dữ liệu test, cấm hardcode nhãn tier.

### 2.2. Thang Tier và hệ quả vận hành

| Tier | Điểm CQ | Hệ quả tự động |
|------|---------|----------------|
| A | < 1.5 | **AUTO LOST** — không vào First Meeting (trừ trường hợp tư vấn theo K4) |
| B | 1.5 – 1.99 | First Meeting **bắt buộc**; **AM soạn proposal 8–12 trang**; vòng sửa ≤ 2 |
| C | 2.0 – 2.99 | First Meeting **bắt buộc**; AM soạn proposal 8–12 trang; vòng sửa ≤ 2 |
| D | 3.0 – 3.49 | First Meeting **có thể bypass**; vùng borderline — SM thẩm định trước khi chốt (mục 2.4); **Planner chủ trì proposal 15–25 trang**; vòng sửa ≤ 4 |
| E | ≥ 3.5 | SM **được bypass** First Meeting (thẳng Gate 1 QUALIFIED nếu đủ điều kiện); ưu tiên tài nguyên; **Planner chủ trì proposal 15–25 trang** (+ Team Bios, quy trình Brand Safety, rà soát điều khoản HĐ cho Big Corp); vòng sửa ≤ 4 |

> **Cập nhật 12/09/2026 (phiên bản 1.1 — DI-002/KXN-8 RESOLVED):** bảng cũ ghi **đảo chiều** định mức proposal (B/C = Planner 15–25 trang ≤4 vòng; D/E = AM 8–12 trang) — mâu thuẫn với Lifecycle V6.0 §GĐ2-3, `stage-gate-lifecycle-v6.md` §2.1 và tài liệu gốc `documents/01_Quy_trinh_MKT_Tong_the.md`. **Chủ dự án chốt theo hướng V6.0** (AUD-01 = KXN-8; nhật ký: `documents/quy-trinh-lam-viec/10_...md` §8): khách tier cao nhất (D/E) được đầu tư proposal lớn nhất do Planner chủ trì. `BR-OPS-6.3/6.4` trong operations.md đã đồng bộ cùng chiều.

### 2.3. Chấm 2 lần

1. **Sơ bộ (autoScore):** chấm ngay tại Initial Brief — quyết định First Meeting bắt buộc hay được bypass.
2. **qualifiedTier:** chấm lại sau **Full Brief 8 sections** — tier chốt cho toàn bộ vận hành (template proposal, SLA, vòng sửa, credit). Ghi nhận một lần, là đầu vào bắt buộc của Gate 1 (SM Go/No-Go, SLA 1 ngày).

### 2.4. Thẩm định borderline 3.0–3.49

Deal vùng 3.0–3.49 (Tier D) do **SM thẩm định** trong SLA 4h trước khi chốt tier/bypass; quá SLA tự escalate GDKD; kết quả kèm lý do ghi audit log.

### 2.5. Chuyển tier Sales → CS

Khi hợp đồng WON, tier Sales chuyển nguyên trạng cho CS. CS được đề xuất chuyển tier trong kỳ theo: doanh thu thực tế của hợp đồng, số TKQC active, churn risk (health score). Đề xuất cần SM + CS TL đồng thuận, GDKD phê duyệt.

### 2.6. Rà soát quý theo win rate

Mỗi quý GDKD rà win rate theo tier và độ lệch điểm CQ vs kết quả thực; hiệu chỉnh ngưỡng/trọng số phải qua đề xuất chính sách (GDKD trình BOD), không chỉnh tại chỗ.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Khách do đối tác chính thức (Google/TikTok/Yandex) giới thiệu: được bổ sung dữ liệu và chấm lại, nhưng không được bypass scoring.
- Khách strategic theo chỉ đạo BOD: bypass scoring, gắn nhãn "BOD-sponsored"; vẫn phải chấm qualifiedTier sau Full Brief để phục vụ vận hành.
- Lead cũ quay lại trong 180 ngày: giữ nguyên lịch sử scoring, cho phép chấm lại đúng một lần với dữ liệu mới.
- Thiếu dữ liệu ≥ 2/5 tiêu chí: hệ thống chặn chấm sơ bộ, trạng thái "Thiếu dữ liệu" — cấm đoán điểm thủ công.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Thẩm định borderline 3.0–3.49 (chốt Tier D/E) | SM (quá SLA escalate GDKD) | SLA 4h |
| Bypass First Meeting cho Tier E (Go/No-Go Gate 1) | SM | SLA 1 ngày |
| Nhận khách strategic / BOD-sponsored | BOD | Theo từng trường hợp |
| Chuyển tier Sales → CS giữa kỳ | GDKD (đồng thuận SM + CS TL) | SLA 3 ngày làm việc |
| Hiệu chỉnh ngưỡng tier / trọng số CQ | GDKD trình BOD | Theo chu kỳ rà soát quý |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Tự động tính điểm CQ theo trọng số 30/25/20/15/10 và map tier theo ngưỡng 1.5/2.0/3.0/3.5; Tier A tự chuyển AUTO LOST | Validation | CRM & Lead Pipeline V6.0 | MUST |
| Chặn chuyển sang QUALIFIED khi Tier B/C chưa qua First Meeting | Validation | CRM & Lead Pipeline V6.0 | MUST |
| Chặn chấm sơ bộ khi thiếu dữ liệu ≥ 2/5 tiêu chí CQ | Validation | CRM & Lead Pipeline V6.0 | MUST |
| Audit log bất biến mọi lần chấm, chấm lại, bypass, thẩm định borderline (ai, khi nào, lý do) | Audit Trail | CRM & Lead Pipeline V6.0 | MUST |
| Lưu tách biệt điểm sơ bộ và qualifiedTier; khóa qualifiedTier sau khi Gate 1 ký | Audit Trail | CRM & Lead Pipeline V6.0 | MUST |
| Cảnh báo SM khi có deal chờ thẩm định borderline; quá SLA 4h escalate GDKD | Notification | SLA & Notification Engine | MUST |
| Cảnh báo quá SLA Gate 1 (1 ngày) tới GDKD/BOD | Notification | SLA & Notification Engine | MUST |
| Đề xuất chuyển tier CS khi doanh thu HĐ/số TK/health score vượt ngưỡng | Notification | Onboarding & Customer Success | SHOULD |
| Dashboard win rate theo tier + độ chính xác scoring theo quý | Reporting | Dashboard BOD/GDKD | SHOULD |
| Báo cáo phân bổ tài nguyên theo tier (workload AM vs Planner) | Reporting | Dashboard GDKD | NICE |

**Cross-policy dependencies:** Policy này là nguồn sự thật cho Tier A–E: `bang-gia-chiet-khau-gross-margin.md` (giới hạn vòng sửa ≤2/≤4), SLA khách hàng (ma trận tier×priority), `hoa-hong-sales-quota.md` (credit chỉ cho deal có qualifiedTier hợp lệ), P1 Phân quyền RBAC (phân quyền dữ liệu theo tier).

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | sales-expert | Khởi tạo |
| 1.1 | 12/09/2026 | main-conversation (post-audit decisions) | §2.2: sửa định mức proposal theo tier về **chiều V6.0** (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng) — giải quyết DI-002/AUD-01/KXN-8 theo quyết định chủ dự án 12/09 (kèm KXN-1 chốt mô hình 5 tier A–E); đồng bộ BR-OPS-6.3/6.4 |
