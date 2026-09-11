# Business Analysis - Stakeholder Management

> **Domain**: Business Analysis / Stakeholder Engagement
> **Last Updated**: 2026-03-15
> **Nguồn**: IIBA BABOK v3, PMI Stakeholder Engagement Guide, Change Management Institute

---

## 1. Stakeholder Identification Checklist

### Theo Phòng Ban

| Phòng Ban | Vai Trò Điển Hình | Quan Tâm Chính |
|-----------|-----------------|----------------|
| Ban lãnh đạo (C-Level) | Sponsor, Decision Maker | ROI, chiến lược, rủi ro tổng thể |
| Quản lý trung cấp (Manager) | Approver, Subject Matter Expert | Quy trình phòng ban, KPI của team |
| Người dùng cuối (End User) | User, Tester | Ease of use, workflow phù hợp |
| IT / Technical Team | Implementer, Architect | Feasibility, integration, security |
| Finance | Approver, Auditor | Budget, compliance, reporting |
| Legal / Compliance | Reviewer | Regulatory, data privacy, contracts |
| HR | Impacted | Change management, training needs |
| Operations | SME, Process Owner | Efficiency, SLA, downtime risk |
| External Vendors | Provider, Integrator | Contract terms, SLA |
| Khách hàng (nếu áp dụng) | End User, Tester | Functionality, user experience |

### Câu Hỏi Để Tìm Stakeholder Bị Bỏ Sót

- Ai sẽ sử dụng output của hệ thống này?
- Ai cần approve decisions trong quy trình này?
- Ai sẽ bị ảnh hưởng nếu dự án fail?
- Ai có quyền dừng dự án?
- Ai là nguồn thông tin quan trọng nhất?

---

## 2. Power/Interest Grid (Stakeholder Matrix)

```
         HIGH POWER
              │
  ┌───────────┼───────────┐
  │           │           │
  │  MANAGE   │  MANAGE   │
  │ SATISFIED │ CLOSELY   │
  │           │           │
  │ (Keep     │ (Active   │
  │ satisfied │ engagement│
  │ but not   │ & regular │
  │ overload) │ updates)  │
  │           │           │
──┼───────────┼───────────┼── HIGH INTEREST
  │           │           │
  │  MONITOR  │   KEEP    │
  │           │ INFORMED  │
  │ (Minimal  │           │
  │ effort;   │ (Regular  │
  │ watch for │ updates,  │
  │ changes)  │ no deep   │
  │           │ involvement│
  └───────────┼───────────┘
              │
         LOW POWER
```

### Chiến Lược Theo Quadrant

| Quadrant | Stakeholder Type | Engagement Strategy | Tần Suất |
|----------|-----------------|---------------------|---------|
| **Manage Closely** | CEO, Sponsor, Key Decision Maker | Weekly sync, steering committee, co-create solutions | Hàng tuần |
| **Keep Satisfied** | CFO, Compliance Manager | Milestone updates, key risk flags | 2 tuần/lần |
| **Keep Informed** | End Users, Team Members | Status emails, demo sessions | Hàng tháng |
| **Monitor** | External vendors, regulators | Quarterly check-in, relevant news | Hàng quý |

---

## 3. Communication Plan Template

| Stakeholder | Nhóm | Nội Dung | Tần Suất | Kênh | Người Gửi | Format |
|-------------|------|----------|----------|------|-----------|--------|
| CEO | Sponsor | Progress, risks, budget status | Hàng tháng | Email + meeting | PM | Executive summary (1 trang) |
| IT Director | Technical Lead | Architecture decisions, technical blockers | Hàng tuần | Slack + weekly meeting | Tech Lead | Kanban board + meeting notes |
| End Users | Department | Feature updates, training schedule | Milestone | Email | BA | Newsletter + demo video |
| Finance Manager | Approver | Budget consumption, change requests | Khi phát sinh | Email | PM | Budget report |
| All Stakeholders | Everyone | Major milestones, go-live date | Milestone | Email | PM | Announcement |

### Nguyên Tắc Communication

- **Right information, right person, right time**: Không gửi technical detail cho C-Level; không gửi tóm tắt quá cao cho technical team.
- **Actionable messages**: Mỗi communication phải rõ ràng "Next step là gì" hoặc "Cần decision gì".
- **Escalation path rõ ràng**: Mọi người đều biết khi nào và ai để escalate.

---

## 4. Conflict Resolution Framework

```
┌─────────────────────────────────────────────────────────────┐
│                CONFLICT RESOLUTION STEPS                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Step 1: IDENTIFY                                           │
│    Xác định loại conflict:                                  │
│    - Requirements conflict (hai phòng ban muốn khác nhau)   │
│    - Priority conflict (ai được làm trước)                  │
│    - Resource conflict (dùng chung resource)                │
│    - Expectation conflict (hiểu nhầm scope)                 │
│                                                             │
│  Step 2: UNDERSTAND                                         │
│    Họp riêng với từng bên để hiểu:                         │
│    - Underlying need (không phải stated position)           │
│    - Business justification của yêu cầu                    │
│    - Impact nếu không được đáp ứng                         │
│                                                             │
│  Step 3: FACILITATE                                         │
│    Tổ chức buổi joint meeting:                             │
│    - BA làm trọng tài, không chọn phe                      │
│    - Tập trung vào business value, không phải personal      │
│    - Đưa ra options, để các bên chọn                       │
│                                                             │
│  Step 4: ESCALATE (nếu cần)                                 │
│    Khi không tự giải quyết được:                           │
│    - Document clearly: vấn đề, positions, options           │
│    - Escalate đến Sponsor / Steering Committee              │
│    - BA không tự quyết định, chỉ trình bày và khuyến nghị  │
│                                                             │
│  Step 5: DOCUMENT                                           │
│    Ghi lại quyết định + rationale vào meeting minutes       │
│    Cập nhật requirements document và registry               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Change Management Basics — ADKAR Model

| Bước | Ý Nghĩa | BA Có Thể Làm |
|------|---------|---------------|
| **A — Awareness** | Nhận thức về sự cần thay đổi | Trình bày why change, business case rõ ràng |
| **D — Desire** | Muốn tham gia và ủng hộ | Engage key influencers; giải quyết lo ngại cá nhân |
| **K — Knowledge** | Biết cách thay đổi | Tài liệu, training materials, demo sessions |
| **A — Ability** | Có khả năng thực hiện | Hands-on training, practice environment, support desk |
| **R — Reinforcement** | Củng cố thay đổi bền vững | Success metrics, quick wins communication, recognition |

### Dấu Hiệu Resistance và Cách Xử Lý

| Dấu Hiệu | Nguyên Nhân Thường Gặp | Cách Xử Lý |
|----------|----------------------|------------|
| Stakeholder không tham gia meeting | Không thấy liên quan hoặc quá bận | Rescheduling; gửi tóm tắt để review async |
| Liên tục thay đổi yêu cầu | Chưa rõ ràng về need; lo ngại chưa được giải quyết | Deep-dive session; re-confirm business goals |
| Im lặng trong workshop | Không an toàn để nói; không hiểu câu hỏi | Anonymous survey; 1-on-1 trước workshop |
| Phàn nàn với cấp trên | Cảm thấy không được lắng nghe | Escalate chủ động; thêm vào steering committee |

---

## 6. Workshop Facilitation Guide

### Pre-Workshop (Trước Buổi Họp)

| Việc Cần Làm | Timeframe | Output |
|-------------|-----------|--------|
| Xác định mục tiêu cụ thể của workshop | 1 tuần trước | Objective statement |
| Chuẩn bị agenda và gửi cho participants | 3 ngày trước | Agenda document |
| Chuẩn bị materials (templates, data, printouts) | 1 ngày trước | Workshop kit |
| Xác nhận attendance và vai trò của từng người | 1 ngày trước | Confirmed list |
| Test công cụ (Miro, Zoom, projector) | Buổi sáng workshop | Setup confirmed |

### During Workshop (Trong Buổi Họp)

```
[00:00] — Welcome & Objective Setting (5 phút)
  → Nhắc lại mục tiêu, agenda, ground rules

[00:05] — Context Setting (10 phút)
  → Trình bày current state, dữ liệu nền

[00:15] — Main Activity (60–90 phút)
  → Requirements elicitation, process mapping, prioritization
  → Chia nhóm nếu cần để tăng participation

[01:15] — Synthesis (15 phút)
  → Tổng hợp kết quả, check đồng thuận

[01:30] — Next Steps & Wrap-up (10 phút)
  → Action items, owner, deadline rõ ràng
```

**Ground Rules Nên Thiết Lập:**
- 1 người nói tại một thời điểm
- Tắt điện thoại hoặc để silent
- Không có câu trả lời sai khi brainstorm
- Quyết định cần Quorum (đủ người có thẩm quyền)

### Post-Workshop (Sau Buổi Họp)

| Việc Cần Làm | Deadline | Owner |
|-------------|----------|-------|
| Gửi meeting notes trong vòng 24 giờ | T+1 ngày | BA |
| Follow up action items với từng owner | T+3 ngày | BA |
| Cập nhật requirements vào registry | T+5 ngày | BA |
| Gửi draft requirements để review | T+7 ngày | BA |
