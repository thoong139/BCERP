# TỔNG QUAN VÒNG ĐỜI DỰ ÁN BC AGENCY

**Mã tài liệu:** `01_Tong_quan_vong_doi_du_an.md`
**Phiên bản:** 1.0 — 12/09/2026
**Nguồn:** Lifecycle v2.3 (chuẩn trình tự) + Lifecycle V6.0 `[V6.0]` (chi tiết bổ sung) + Cơ cấu tổ chức (tài liệu 05)

---

## 1. Vòng đời 5 giai đoạn

Vòng đời dự án BC Agency đi từ **Raw Data** (lead thô) đến **CLOSED / RENEW**, chia thành 5 giai đoạn với 2 điểm bàn giao lớn:

```mermaid
flowchart LR
    subgraph GD1["GIAI ĐOẠN 1 — SALES"]
        A["RAW DATA → BRIEF → FIRST MEETING → LEAD → QUALIFIED"]
    end
    subgraph GD2["GIAI ĐOẠN 2 — ĐÁNH GIÁ & ĐỀ XUẤT"]
        B["EVALUATION → SECOND MEETING → PROPOSAL → REHEARSAL → PITCHING → QUOTATION → NEGOTIATION"]
    end
    subgraph GD3["GIAI ĐOẠN 3 — TRIỂN KHAI (D+0 → D+5)"]
        C["Thu tài nguyên ∥ Chờ tiền → D+0 → PLANNING → KICK-OFF nội bộ ×2 → KICK-OFF KH"]
    end
    subgraph GD4["GIAI ĐOẠN 4 — ONGOING (từ D+5)"]
        D["A. EXECUTING · B. OPTIMIZING · C. REPORTING — chạy song song liên tục"]
    end
    subgraph GD5["GIAI ĐOẠN 5 — KẾT THÚC"]
        E["WRAP-UP → SURVEY → FINAL REPORT → OFFBOARDING → RETRO → CLOSED / RENEW"]
    end
    A -->|"Bàn giao · Sales observe"| B
    B -->|"WON · đồng hồ D-day"| C
    C -->|"D+5"| D
    D --> E
```

### Bảng tổng hợp giai đoạn

| Giai đoạn | Stage (mã PMS) | Chủ thực thi | Bàn giao / Gate chính |
|-----------|----------------|--------------|----------------------|
| **1. Sales** | RAW_DATA → BRIEF_SENT → FIRST_MEETING (+BYPASS) → BRIEF_RECEIVED → LEAD → QUALIFIED | Sales Executive, SM | Gate bàn giao Sales → BPVH tại QUALIFIED `[KXN-1]` |
| **2. Đánh giá & Đề xuất** | EVALUATION → SECOND_MEETING → PROPOSAL_INTERNAL → REHEARSAL → PROPOSAL → PROPOSAL_REVIEW → PITCHING → QUOTATION → NEGOTIATION → **WON** | AM, Planner, AD, Accountant | WON = điểm chuyển giao Sales → Ops, khởi động đồng hồ D-day |
| **3. Triển khai** | COLLECTING ∥ WAIT_PAYMENT → **D+0** → PLANNING_DRAFT → KICKOFF_I1 (D+1) → KICKOFF_I2 (D+2) → KICKOFF_CLIENT (D+3) → **ONGOING (D+5)** | AM, Planner, toàn BPVH, Accountant | D+0 chỉ kích hoạt khi Accountant xác nhận tiền vào TK |
| **4. Vận hành ONGOING** | 3 nhánh song song: EXECUTING (Content → Design/Video → AM duyệt → Ads → Publish), OPTIMIZING (Routine ∥ Emergency), REPORTING (Daily/Weekly/Monthly) | Toàn bộ BPVH | KPI < 70% → Emergency; Exit theo 5 kịch bản |
| **5. Kết thúc** | UPSELL (bất kỳ) → WRAPUP → SURVEY → FINAL_REPORT → OFFBOARDING → INTERNAL_RETRO → **CLOSED** hoặc **RENEW** (3 luồng) | AM, SE, AD, Accountant | Offboarding xong mới được CLOSED; Renew 3 luồng A/B/C |

### Các quy trình ngang (xảy ra ở bất kỳ giai đoạn nào)

| Quy trình | Nội dung | Mục |
|-----------|----------|-----|
| **LOST Management** | 3 điểm LOST: First Meeting / Pitching / Negotiation; phân loại nhóm A/B/C/D; nurturing | Tài liệu 02 §6, 06 §6 |
| **PAUSED** | Tạm dừng bất kỳ lúc nào; AM đề xuất + SM/AD duyệt; review 2 tuần/lần; 60 ngày không hồi âm → LOST nhóm A | Tài liệu 06 §5 |
| **UPSELL** | Mini-flow cơ hội mở rộng trong ONGOING; đề xuất nhanh 24h | Tài liệu 06 §1 |

## 2. Nguyên tắc vận hành nền tảng

1. **Hard Gates — không nhảy bước `[V6.0]`:** chỉ chuyển stage khi thỏa mãn 100% Done criteria của stage hiện tại; nút chuyển stage bị vô hiệu trên UI và từ chối ở tầng API nếu thiếu điều kiện.
2. **"Không ghi nhận vào PMS = Không tồn tại" `[V6.0]`:** mọi lead, meeting, feedback, quyết định gate, vòng sửa proposal đều phải nằm trên PMS. Feedback KH nhận qua Zalo/Email **bắt buộc** được nhập lại vào PMS.
3. **Observe mode 2 chiều `[V6.0]`:** Sales Phase — Sales thực thi, Vận hành theo dõi; từ WON trở đi — Vận hành thực thi, Sales theo dõi. Sales Executive chỉ quay lại chủ động khi CLOSED (nhận nurturing list).
4. **D+0 là điều kiện duy nhất kích hoạt triển khai:** tiền vào TK + Accountant xác nhận. Hợp đồng có thể ký sau (có cảnh báo nếu trễ 3 ngày) — xem khoản `[KXN-5]`.
5. **AM là điểm chặn chất lượng duy nhất hướng khách hàng:** mọi content/creative (duyệt trong 2h) và mọi báo cáo (QC trước khi gửi) đều bắt buộc qua AM — không có ngoại lệ, kể cả khẩn cấp.
6. **Tiền và ngân sách là của KH:** mọi thay đổi budget/targeting luôn cần KH duyệt rõ ràng — Rule "Im lặng = Đồng ý" (24h) **không áp dụng** cho hai mục này.
7. **Capacity là rào chắn nhận việc:** >100% utilization → ngừng nhận dự án mới (CEO/COO quyết định); 80–100% → AD duyệt.

## 3. Mô hình Tier khách hàng `[KXN-1]`

Bản tái dựng dùng mô hình **v2.3: 4 tier A/B/C/D** làm chuẩn trình tự:

| Tier (v2.3) | Hệ quả quy trình |
|-------------|------------------|
| **A/B** (nhãn giá trị cao) | Bắt buộc First Meeting — từ chối gặp → LOST ngay; Proposal ≤2 vòng sửa; AM tự soạn proposal `[V6.0]` |
| **C/D** | Có thể BYPASS First Meeting nếu SM duyệt (nhãn lớn đấu thầu nhiều agency); Proposal ≤4 vòng sửa; Planner chủ trì soạn proposal `[V6.0]` |

⚠️ **Mâu thuẫn nguồn quan trọng nhất:** Lifecycle V6.0 dùng mô hình **5 tier A–E với ngữ nghĩa NGƯỢC chiều** (Tier A = điểm <1.5 → AUTO LOST, tệ nhất; Tier E = điểm ≥3.0 → tốt nhất, được bypass). Hai mô hình không tương thích về ký hiệu — ảnh hưởng scoring, điều kiện bypass, số vòng sửa proposal, hoa hồng. **Chưa thể chạy AUTO SCORING cho đến khi chủ dự án chốt một mô hình.** Chi tiết so sánh tại tài liệu 10 §3.1.

## 4. D+ Timeline triển khai (từ WON đến D+5)

```mermaid
flowchart TD
    WON["WON — chốt thỏa thuận<br/>(bắt đầu đồng hồ chuẩn bị)"] --> CP["Song song:<br/>① Thu thập tài nguyên (xong trước D+4)<br/>② Chờ tiền vào TK (Accountant check hàng ngày)"]
    CP -->|"Tiền vào + Accountant confirm (4h)"| D0["D+0 — Kích hoạt<br/>Planning Sơ bộ (TT→ĐH→AD) trong ngày"]
    D0 --> D1["D+1 — Kick-off Nội bộ lần 1<br/>Team Leads review feasibility"]
    D1 --> D2["D+2 — Kick-off Nội bộ lần 2<br/>Chốt plan, phân công presenter"]
    D2 --> D3["D+3 — Kick-off KH (Client Onboarding)<br/>Present plan · Portal · KÝ 6 Communication Rules"]
    D3 --> D5["D+5 — ONGOING bắt đầu<br/>(lùi nếu tài nguyên chưa đủ)"]
```

| Mốc | Điều kiện | Người gác |
|-----|-----------|-----------|
| WON → D+0 | Tiền vào TK + Accountant confirm trong 4h làm việc | Accountant (`FIN_L1`) |
| Thu thập tài nguyên | Hoàn tất **trước D+4**; thiếu → D+5 tự lùi | AM |
| D+1 / D+2 | Kick-off nội bộ **không được lùi** — vắng phải gửi feedback trước qua chat | AM |
| D+3 | KH ký 6 Communication Rules; từ chối → AD negotiate, ghi exception | AM → AD |
| D+5 | ONGOING bắt đầu khi đủ tài nguyên (pixel, quyền ad account) | AM + Media |

## 5. Hệ thống công cụ

| Hệ thống | Vai trò | Trạng thái |
|----------|---------|-----------|
| **PMS** | Xương sống quy trình — 141 tham chiếu module: Project, Task, File, Budget, Event, Notification, Audit Log, Content Post, ProposalRevision, Strategic Brief (16 sections), Media Plan, Report, Approval, Comment, KPI, Ads Report, Client Portal, Analytics, Insights Library, Capacity, Dashboard | Đang vận hành (theo thiết kế quy trình) |
| **CMS** | Track ad account/top-up, aggregate account health | Tương lai `[KXN-9]` |
| **TMS** | Capacity, KPI cá nhân Sales | Tương lai `[KXN-9]` |
| Nền tảng quảng cáo | Meta Ads Manager / Business Suite / Events Manager, Google Ads, TikTok Ads Manager, Facebook Ad Library | Đang dùng |
| Hỗ trợ | Zalo (kênh chính), Email, Zoom/Meet/Teams, Google Drive/Docs/Sheets/Slides/Forms, Typeform, Figma/Photoshop, Premiere/CapCut/DaVinci, Zapier/n8n, Pancake/Getfly (KH có CRM) | Đang dùng |
| AI | Manus AI (Meta pull), AI Agent tự pull data | Giai đoạn 2 `[KXN-9]` |

## 6. Cách đi lại trong vòng đời — 6 nhánh thoát/đổi luồng

```mermaid
flowchart TD
    P["Đang ở stage bất kỳ"] --> L["LOST — 3 điểm:<br/>First Meeting / Pitching / Negotiation<br/>→ nhóm A/B/C/D + nurturing"]
    P --> PA["PAUSED — bất kỳ lúc nào<br/>AM đề xuất + SM/AD duyệt<br/>60 ngày im lặng → LOST nhóm A"]
    P --> U["UPSELL — trong ONGOING<br/>nhỏ: điều chỉnh project<br/>lớn: project mới + parentProjectId"]
    P --> C["CLOSED — hết HĐ không renew<br/>KH vào nurturing list của SE"]
    P --> R["RENEW — 3 luồng:<br/>A: về PLANNING (cùng project ID)<br/>B: về QUOTATION (cùng project ID)<br/>C: project mới từ SECOND_MEETING"]
    P --> E["ONGOING Exit — 5 kịch bản:<br/>Normal / Early / Non-payment / KPI miss / Crisis"]
```

Chi tiết từng nhánh: LOST tại 02 §6; PAUSED tại 06 §5 và ONGOING Exit tại 06 §7; UPSELL/RENEW/CLOSED tại 06 §1–4.
