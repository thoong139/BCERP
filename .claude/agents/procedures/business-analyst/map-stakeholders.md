# Playbook: Map Stakeholders

> **Type**: Agent Procedure
> **Agent**: business-analyst
> **Triggered by**: /wf-brainstorm hoặc /wf-analyze-requirements — Phase 0/1, khi cần xác định stakeholders và user personas
> **Output**: `.mc-data/docs/phase1-business/stakeholder-map.md`

---

## Khi nào dùng playbook này

- Được gọi khi skill yêu cầu stakeholder analysis
- Khi dự án cần xác định rõ "ai là người dùng, ai là người quyết định"
- Khi cần input cho requirements analysis (thường chạy trước `analyze-business-requirements.md`)
- Khi có conflict giữa các stakeholders và cần hiểu dynamics
- Khi onboard team mới cần nắm bức tranh toàn cảnh về các bên liên quan

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, KNOWLEDGE_BASE

READ: .claude/references/team-expert/business-analysis/stakeholder-management.md
      (Toàn bộ file — dùng mục 1, 2, 3, 4)

Cần xác định từ context:
□ Loại hình tổ chức (Startup / SME / Enterprise / NGO / Government)
□ Lĩnh vực hoạt động
□ Quy mô (số nhân viên, phòng ban)
□ Các phòng ban chính đã đề cập trong brainstorm
□ Đối tượng khách hàng cuối (nếu có)
```

### Bước 2: Phân loại stakeholders theo nhóm

Dùng Stakeholder Identification Checklist (stakeholder-management.md mục 1):

**Internal Stakeholders — Nội bộ tổ chức:**

| Nhóm | Cần Xác Định |
|------|-------------|
| Ban lãnh đạo (C-Level) | CEO, CTO, CFO, COO — ai là Sponsor? Ai là Decision Maker? |
| Quản lý trung cấp | Manager từng phòng ban liên quan — ai là Subject Matter Expert? |
| Người dùng cuối | Nhân viên trực tiếp dùng hệ thống hàng ngày |
| IT / Technical Team | Người vận hành và bảo trì hệ thống |
| Finance | Người approve budget, kiểm toán, báo cáo tài chính |
| Legal / Compliance | Người review hợp đồng, tuân thủ pháp lý |

**External Stakeholders — Bên ngoài tổ chức:**

| Nhóm | Cần Xác Định |
|------|-------------|
| Khách hàng / End Users | Ai dùng sản phẩm/dịch vụ cuối cùng? |
| Đối tác / Vendor | Ai cung cấp dịch vụ/hàng hóa cho doanh nghiệp? |
| Cơ quan quản lý | Có compliance requirement nào không? |
| Investor / Board | Ai cần báo cáo kết quả kinh doanh? |

### Bước 3: Phỏng vấn nhanh từng stakeholder group (qua tài liệu)

Với mỗi stakeholder group đã xác định:

```
□ Tên/chức danh điển hình
□ Vai trò trong dự án: Actor / Approver / Reviewer / Informed / Sponsor
□ Mối quan tâm chính (Concern): Họ muốn gì từ hệ thống này?
□ Pain points hiện tại: Họ đang khổ vì điều gì?
□ Success criteria: Họ coi dự án thành công khi nào?
□ Rủi ro với họ: Điều gì có thể gây ra resistance?
□ Mức độ ảnh hưởng lên dự án (Power: High/Medium/Low)
□ Mức độ quan tâm đến dự án (Interest: High/Medium/Low)
```

Câu hỏi phát hiện stakeholder bị bỏ sót (stakeholder-management.md mục 1):
- Ai sẽ sử dụng output của hệ thống?
- Ai cần approve decisions trong quy trình?
- Ai sẽ bị ảnh hưởng nếu dự án fail?
- Ai có quyền dừng dự án?

### Bước 4: Map Power/Interest Grid

Dùng Power/Interest Grid (stakeholder-management.md mục 2):

```
Với mỗi stakeholder group → Assign:
- Power (Quyền lực): High / Medium / Low
- Interest (Quan tâm): High / Medium / Low

→ Xác định quadrant:
  - High Power + High Interest → MANAGE CLOSELY (update hàng tuần)
  - High Power + Low Interest  → KEEP SATISFIED (update 2 tuần/lần)
  - Low Power  + High Interest → KEEP INFORMED (update hàng tháng)
  - Low Power  + Low Interest  → MONITOR (check hàng quý)
```

### Bước 5: Xác định Decision Makers và Approval Chain

```
□ Ai có quyền approve requirements change? (thay đổi scope)
□ Ai sign-off final requirements document?
□ Ai approve budget nếu có change request?
□ Quy trình escalation khi có conflict?
□ Steering Committee gồm ai? (nếu dự án lớn)
```

RACI Matrix — gán cho các hoạt động chính:
```
Elicit requirements: R=BA, A=Manager, C=SME, I=C-Level
Write requirements doc: R=BA, A=Manager, C=IT, I=All
Sign-off requirements: R=BA, A=C-Level, C=Manager, I=Team
```

### Bước 6: Document Influence & Interest Matrix

Với mỗi stakeholder có Power cao hoặc Interest cao:

```
□ Motivations: Điều gì thúc đẩy họ ủng hộ dự án?
□ Concerns: Điều gì khiến họ lo ngại hoặc chống đối?
□ Engagement strategy: Cách tiếp cận phù hợp nhất
□ Preferred communication channel: Email / Meeting / Demo / Report
□ Key messages cần truyền đạt cho họ
```

Nhận diện dấu hiệu resistance và cách xử lý (stakeholder-management.md mục 5):
- Không tham gia meeting → Reschedule + async summary
- Liên tục thay đổi yêu cầu → Deep-dive session, re-confirm business goals
- Im lặng trong workshop → Anonymous survey hoặc 1-on-1

### Bước 7: Ghi output stakeholder map

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/stakeholder-map.md

Cấu trúc output:
1. Stakeholder Overview — Tổng quan số lượng và phân loại
2. Stakeholder Register — Bảng đầy đủ tất cả stakeholders
3. Power/Interest Grid — Visual hoặc bảng phân loại 4 quadrant
4. Decision Makers & Approval Chain
5. RACI Matrix cho các hoạt động chính
6. Engagement Strategy — Chiến lược tiếp cận từng nhóm
7. Communication Plan Template — Ai, nội dung gì, tần suất nào
8. Identified Risks — Stakeholders có khả năng gây trở ngại
```

---

## Checklist trước khi submit

```
□ Tất cả phòng ban liên quan đã được identify (Internal + External)
□ Mỗi stakeholder group có Power/Interest assignment
□ Decision Makers và approval chain đã rõ ràng
□ Đã sử dụng câu hỏi phát hiện stakeholder bị bỏ sót
□ Engagement strategy cho từng quadrant đã được plan
□ Resistance risks đã được identify với cách xử lý
□ Communication plan có channel, tần suất, format cụ thể
□ Output stakeholder map link được đến requirements document tiếp theo
```
