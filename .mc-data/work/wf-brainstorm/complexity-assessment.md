# Đánh Giá Mức Phức Tạp Dự Án — BCERP

**Ngày:** 2026-09-11
**Dự án:** BCERP — Hệ thống ERP nội bộ cho BC Agency
**Verdict:** `project_complexity = ENTERPRISE`

---

## 1. Kết Luận

Dự án BCERP được phân loại ở mức **ENTERPRISE** — mức cao nhất theo thang 3 mức chuẩn của DEVKIT (`SIMPLE / STANDARD / ENTERPRISE`).

## 2. Lý Do Phân Loại

### 2.1. Keyword ENTERPRISE match (nguồn scan: `project_name`, `industry`, `business_model`, `pain_points[]`)

| Keyword | Nguồn |
|---------|-------|
| **ERP** | `project_name` = "BCERP" (BC Agency ERP) — theo §7 `_shared.md`, có BẤT KỲ keyword ENTERPRISE → override thành ENTERPRISE bất kể số phòng ban |
| **quản trị / quản lý doanh nghiệp** | `industry` — "trung gian quản lý tài khoản quảng cáo đa nền tảng" |
| **kế toán** | `existing_systems` (phần mềm kế toán riêng), pain points (đối soát, công nợ) |
| **nhân sự** | `pain_points[]` — "Quá tải & KPI nhân sự cảm tính" |

→ **Enterprise override rule kích hoạt:** ≥1 keyword ENTERPRISE trong nguồn scan.

### 2.2. Số phòng ban (`active_depts[]`)

**5 phòng ban** theo cơ cấu chính thức tài liệu `05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md` (≥5 ngưỡng ENTERPRISE):

1. Ban Điều Hành (BOD) — CEO, CFO kiêm CTO (CMO, COO/GDKD quy hoạch)
2. Phòng Hành chính Nhân sự (HR) — NVHR (L1), TPHR (L2)
3. Phòng Tài chính - Kế toán — Kế toán viên (FIN_L1), Kế toán trưởng (FIN_L2)
4. Phòng Kinh Doanh (Sales) — 5 cấp bậc SALES_L1 → SALES_L5
5. Phòng Vận Hành Dự Án & Marketing Nội Bộ — 6 vai trò OPS (Planner, AM, Content, Designer, Editor, Ads), khung năng lực L1–L5

### 2.3. Bối cảnh nghiệp vụ

- **Ràng buộc chéo phòng ban dạng cứng (Hard Gate):** Financial Hard Stop "đã khớp tiền" đòi hỏi luồng Kế toán → TKQC → Dự án nhất quán liên phòng; handoff Sales → Vận hành với SLA + ký duyệt Go/No-Go.
- **Đa hệ thống:** ERP nội bộ + Client Portal (bên ngoài) + mobile; pattern "ERP + CRM + Website B2B" trong `domain-experts.md` §2.
- **Tích hợp ngoài đa nguồn:** Meta Graph API, Google Ads API, TikTok Business API (+ Bing/X/Pinterest/Yandex), module Settings quản lý credentials.
- **Yêu cầu phi chức năng cao:** Immutable Audit Log cho mọi giao dịch tiền & hợp đồng; P&L realtime theo dự án; cảnh báo ngưỡng số dư TKQC theo giờ; SLA breach alert.
- **Quy mô giao dịch:** 2.600+ TKQC active, 1.000+ khách hàng toàn cầu, đa tiền tệ/múi giờ.

### 2.4. Ghi chú cân bằng

Quy mô nhân sự 31–50 là vừa nhỏ — độ phức tạp nằm ở **độ sâu quy trình, số tích hợp và ràng buộc chéo**, không phải khối lượng user nội bộ. Chủ dự án đã chốt **phát triển đầy đủ (không MVP)**, không đặt mốc go-live cứng — downstream phases cần bám quyết định này khi đề xuất thứ tự triển khai.

## 3. Hệ Quả Đối Với Quy Trình

| Hệ quả | Giá trị |
|--------|---------|
| Phân tích chính sách Phase 3 | **ĐẦY ĐỦ** — full policy analysis + proactive recommendation (12/12 nhóm chính sách user trả lời "Chưa có") |
| Legal + Compliance expert | **Spawn** — phân tích P0-01 §5.1 (tuân thủ pháp lý) |
| Policy gap analysis | `final_policy_gaps[] = user_gaps ∪ expert_recommended_gaps` |
| Output docs | P0-01 đầy đủ 6 sections + P0-02 4 sections + policy files trong `policies/` |
| Complexity khả dĩ khác | KHÔNG — không áp SIMPLE (có keyword SIMPLE? Không) hay STANDARD (số depts + keywords vượt ngưỡng) |
