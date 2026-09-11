# 00 — Bối Cảnh Khách Hàng: BC Agency

> **Mức độ ràng buộc:** BẮT BUỘC đọc trước khi brainstorm/phân tích nghiệp vụ (Phase 0-1)
> **Nguồn:** [bcagency.vn](http://bcagency.vn/) (khảo sát 2026-09-11) + thông tin do chủ dự án cung cấp
> **Mục đích:** Cho AI agent (Claude Code, Codex, zCode, Google Antigravity, ...) hiểu đúng khách hàng THẬT của dự án BCERP trước khi đề xuất module/tính năng — tránh suy diễn sai ngành nghề.

---

## 1. Dự án này xây dựng ERP cho ai?

**BCERP** là hệ thống ERP nội bộ do **BC Agency** đặt hàng, dùng nền tảng DEVKIT (MCV3) để phát triển. Toàn bộ phân tích nghiệp vụ, thiết kế tính năng, và domain expert được huy động PHẢI bám sát mô hình kinh doanh thật của BC Agency — không phải một doanh nghiệp sản xuất/bán lẻ thông thường.

## 2. Hồ sơ công ty

| Trường | Giá trị |
|--------|---------|
| Tên pháp lý | Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam |
| Tên thương mại | BC Agency |
| Mã số thuế | 0109354342 |
| Trụ sở | Hà Nội, Việt Nam |
| Văn phòng đại diện | 2+ (đa quốc gia) |
| Hotline | +84 838 586 166 · +84 368 718 680 |
| Website | http://bcagency.vn/ |
| Kinh nghiệm | 8+ năm trong lĩnh vực digital marketing |
| Quy mô khách hàng | 1.000+ khách hàng toàn cầu, 2.600+ tài khoản quảng cáo đang hoạt động |

## 3. Ngành nghề & mô hình kinh doanh

**BC Agency là một digital marketing agency**, đóng vai trò **trung gian (agency/reseller)** kết nối doanh nghiệp với các nền tảng quảng cáo lớn — cung cấp **tài khoản quảng cáo agency** (agency ad accounts) ít bị giới hạn hơn, hạn mức chi tiêu (spend limit) cao hơn tài khoản cá nhân thông thường.

**Dịch vụ chính:**

| Nhóm dịch vụ | Chi tiết |
|--------------|----------|
| Quản lý tài khoản quảng cáo (Agency Accounts) | Meta, Google, TikTok, Bing, X (Twitter), Pinterest, Yandex, và các nền tảng khác |
| Facebook Marketing | Quản lý fanpage, chạy quảng cáo Facebook |
| TikTok | Phát triển TikTok Shop, chạy TikTok Ads |
| Google | Google Ads, dịch vụ SEO |
| Web/Design | Thiết kế website, landing page, thiết kế đồ họa |

**Đối tác chính thức:** Google, TikTok, Yandex và các nền tảng quảng cáo lớn khác.

**Khách hàng mục tiêu (của BC Agency, tức là "khách hàng của khách hàng" trong ERP):** doanh nghiệp thuộc FMCG, F&B, Retail (bán lẻ), Beauty (làm đẹp), và dịch vụ B2B.

## 4. Hàm ý cho thiết kế ERP (BCERP)

Vì BC Agency vận hành như một **agency trung gian quảng cáo đa nền tảng**, các module ERP cần phản ánh đúng nghiệp vụ đặc thù — KHÔNG áp khuôn mẫu ERP sản xuất/bán lẻ truyền thống một cách máy móc:

| Nghiệp vụ đặc thù | Gợi ý phạm vi module (cần xác nhận qua `/wf-brainstorm` + `/wf-analyze-requirements`, KHÔNG tự chốt trước) |
|--------------------|---|
| CRM khách hàng quảng cáo | Quản lý thông tin doanh nghiệp thuê dịch vụ, lịch sử tương tác, pipeline sales theo gói dịch vụ (Facebook Ads, Google Ads, TikTok Ads, SEO, Web...) |
| Quản lý tài khoản quảng cáo (Ad Account Management) | Theo dõi tài khoản agency theo từng nền tảng (Meta/Google/TikTok/Bing/X/Pinterest/Yandex), hạn mức chi tiêu, trạng thái tài khoản, phân bổ cho từng khách hàng |
| Sales & Báo giá | Báo giá theo gói dịch vụ, hợp đồng, chiết khấu, hoa hồng sales/đối tác |
| Finance & Đối soát | Đối soát chi tiêu quảng cáo thực tế vs. nạp tiền, công nợ khách hàng, thanh toán cho nền tảng quảng cáo, hóa đơn |
| Vận hành & Dự án | Phân công nhân sự triển khai chiến dịch, tiến độ theo từng khách hàng/nền tảng, SLA |
| Báo cáo hiệu suất | ROAS, chi phí/hiệu quả theo chiến dịch, theo khách hàng, theo nền tảng |
| Quan hệ đối tác | Theo dõi quan hệ với Google/TikTok/Yandex (đối tác chính thức), chính sách nền tảng |

> **Lưu ý bắt buộc:** Bảng trên chỉ là gợi ý định hướng ban đầu để domain expert không đi lạc hướng. Phạm vi module CHÍNH THỨC phải chốt qua `/wf-brainstorm` (Phase 0) và `/wf-analyze-requirements` (Phase 1), ghi vào `req-registry.json` — tuân thủ CORE-004 (không thêm tính năng ngoài registry).

## 5. Domain expert nên ưu tiên huy động

Khi phân tích nghiệp vụ hoặc thiết kế tính năng cho BCERP, ưu tiên các agent sau (ngoài `business-analyst` mặc định):

| Agent | Vai trò với BC Agency |
|-------|------------------------|
| `paid-media-expert` | Chính sách nền tảng quảng cáo (Google/Meta/TikTok), ROAS, attribution, quản lý chi tiêu quảng cáo — **agent trung tâm nhất** cho ngành nghề này |
| `marketing-expert` | Chiến dịch, demand gen, content, SEO |
| `sales-expert` | Pipeline bán gói dịch vụ, báo giá, hoa hồng |
| `finance-expert` | Đối soát công nợ, thanh toán nền tảng, hóa đơn |
| `customer-expert` | Trải nghiệm khách hàng thuê dịch vụ, CX |
| `compliance-expert` | Tuân thủ chính sách quảng cáo (Google/Meta Ads Policy), bảo mật thanh toán nếu có xử lý payment (PCI-DSS) |
| `ecommerce-expert` | Khi liên quan TikTok Shop / thương mại điện tử |

Domain knowledge liên quan đã có sẵn tại `.claude/references/team-expert/paid-media/` (channels, attribution, platform-optimization) và `.claude/references/team-expert/marketing/`.

## 6. Điều CHƯA xác nhận — cần hỏi khách hàng qua `/wf-brainstorm`

Tài liệu này chỉ tổng hợp thông tin công khai trên website. Các điểm sau PHẢI xác nhận trực tiếp với BC Agency trước khi thiết kế, KHÔNG suy diễn:

- Quy trình vận hành nội bộ thực tế (ai làm gì, công cụ hiện tại đang dùng)
- Cấu trúc phòng ban, số lượng nhân sự, phân quyền
- Mô hình thu phí dịch vụ cụ thể (phí quản lý, markup chi tiêu quảng cáo, gói trọn gói...)
- Yêu cầu tích hợp (API nền tảng quảng cáo, kế toán, thanh toán)
- Phạm vi ERP đợt đầu (MVP) vs. roadmap dài hạn
- Ngôn ngữ/thị trường vận hành (chỉ VN hay đa quốc gia — công ty có 2+ văn phòng đại diện)

---

## 7. Liên kết

- [`01-project-description.md`](01-project-description.md) — DEVKIT/MCV3 là gì
- [`02-positioning-priorities.md`](02-positioning-priorities.md) — Thứ tự ưu tiên vận hành
- **AGENTS.md** (root) — Tham chiếu nhanh cho AI coding agents
- **CLAUDE.md** (root) — Hướng dẫn đầy đủ cho Claude Code
- **README.md** (root) — Tổng quan dự án BCERP
