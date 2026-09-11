# Playbook: Thiết kế giao thức phỏng vấn người dùng

> **Type**: Agent Skill Playbook
> **Agent**: ux-researcher
> **Triggered by**: Phase 0–1 khi cần xây dựng research protocol để hiểu người dùng trước khi design
> **Output**: `.mc-data/docs/phase1-business/ux-research/interview-guide.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements` hoặc `/wf-design-ux` khi dự án có UI
- Khi chưa có data về hành vi, mental model, pain points của người dùng thực tế
- Khi cần validate giả thuyết về nhu cầu người dùng trước khi invest vào design
- Khi stakeholder yêu cầu "hiểu người dùng" nhưng chưa có research data

---

## Procedure

### Bước 1: Đọc business context và xác định research gap

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0 (brainstorm), PHASE1 (business docs)

Cần xác định:
□ Loại sản phẩm và đối tượng người dùng mục tiêu (từ brainstorm docs)
□ Những giả thuyết về người dùng đã có — điều gì đã biết, điều gì chưa biết?
□ Quyết định design hoặc product nào đang chờ data từ research?
□ Timeline dự án — có bao nhiêu thời gian cho research phase?
□ Điểm đặc thù của domain: B2B (quyết định bởi nhiều người) vs B2C (cá nhân)?
```

LOAD KNOWLEDGE:
```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 1 (Research Method Selection Matrix) để chọn method phù hợp
      → Section 2 (User Interview Guide Template) làm nền tảng
```

### Bước 2: Xác định mục tiêu nghiên cứu

Đây là bước quan trọng nhất — research objectives quyết định toàn bộ thiết kế sau đó.

```
Với mỗi câu hỏi nghiên cứu, viết theo format:
"Chúng tôi cần hiểu [hành vi/nhu cầu/mental model CỤ THỂ] của [người dùng]
để quyết định [quyết định design/product CỤ THỂ]."

Ví dụ tốt:
"Chúng tôi cần hiểu quy trình hiện tại kế toán dùng để reconcile hóa đơn,
để quyết định có nên build automation hay chỉ cần cải thiện UI input."

Ví dụ tệ (quá mơ hồ):
"Chúng tôi muốn hiểu người dùng nghĩ gì về sản phẩm."

Giới hạn: 3–5 research questions để duy trì focus.
```

Phân loại câu hỏi nghiên cứu:

| Loại | Dùng khi | Phương pháp phù hợp |
|------|----------|---------------------|
| Khám phá (Exploratory) | Chưa biết vấn đề là gì | Interviews, Diary Studies |
| Mô tả (Descriptive) | Cần đo lường hành vi/thái độ | Surveys, Analytics |
| Kiểm định (Evaluative) | Validate design decision | Usability Testing |
| So sánh (Causal) | So sánh 2 solutions | A/B Testing |

### Bước 3: Chọn phương pháp nghiên cứu

Dựa trên câu hỏi nghiên cứu (Bước 2) và timeline, chọn method:

```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 1: Research Method Selection Matrix

Quy tắc lựa chọn:
□ Câu hỏi "TẠI SAO" và "NHƯ THẾ NÀO" → Moderated User Interviews (5–8 người/segment)
□ Câu hỏi "BAO NHIÊU" và "AI" → Surveys (100+ responses)
□ Cần validation nhanh → Unmoderated Usability Test (20–50 người)
□ Context dài hạn → Diary Studies (10–20 người, 2–4 tuần)

Phân tích trade-off khi chọn:
- User interviews: Insight sâu nhưng sample nhỏ, tốn thời gian
- Surveys: Phủ rộng nhưng không giải thích được WHY
- Usability testing: Tập trung behavior, không đo attitudes

Trong DEVKIT context: Ưu tiên thiết kế PROTOCOL khả thi trong
thời gian dự án — không cần thiết kế nghiên cứu học thuật hoàn hảo.
```

### Bước 4: Xác định tiêu chí participants và recruiting strategy

```
Participant Profile (viết cho mỗi segment):
□ Đặc điểm bắt buộc (must-have): ví dụ "Đang làm kế toán tại doanh nghiệp SME"
□ Đặc điểm mong muốn (nice-to-have): ví dụ "Có dùng phần mềm kế toán số"
□ Đặc điểm loại trừ (exclusions): ví dụ "Không tuyển nhân viên công ty nhà tuyển dụng"

Cỡ mẫu theo method:
- Interviews: 5 người/segment đủ để phát hiện 85% usability issues lớn
  → Nếu nhiều segment rất khác nhau: 5 người × số segment
- Surveys: Tối thiểu 100 responses để có ý nghĩa thống kê cơ bản

Diversity checklist (để tránh homogeneous sample):
□ Đa dạng về mức độ kinh nghiệm (mới dùng / đã dùng lâu)
□ Đa dạng về tech comfort (beginner / intermediate / power user)
□ Đa dạng về thiết bị (mobile-first vs desktop-first nếu relevant)
□ Đa dạng về context dùng (văn phòng vs di động, cá nhân vs nhóm)

Recruiting channels:
□ Nội bộ (nhanh): nhờ sales/support team giới thiệu existing customers
□ Mạng xã hội: LinkedIn, Facebook groups liên quan đến domain
□ Screener survey để filter đúng tiêu chí trước khi mời
```

### Bước 5: Xây dựng interview guide

Đây là deliverable chính của playbook này. Structure một interview 45–60 phút:

**5a. Screening questions (trước khi mời, 5 câu)**

```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 2: Screening Questions

Nguyên tắc viết screening questions:
- Câu hỏi phải phân loại được (đúng/sai tiêu chí) — không hỏi kiến thức
- Không telegraph "câu trả lời đúng" — giữ neutral
- Bao gồm 1 câu về tần suất dùng để filter casual users
```

**5b. Interview script (4 phases)**

```
Phase 1 — Warm-up (5 phút)
Mục đích: Tạo thoải mái, giải thích quy trình, xin phép ghi âm
Template:
"Hôm nay chúng tôi sẽ nói chuyện khoảng 45 phút về [domain topic].
Không có câu trả lời đúng hay sai — tôi muốn hiểu trải nghiệm thực tế của bạn.
Bạn có thể ngừng bất cứ lúc nào. Được phép ghi âm để ghi chú không?"
→ Context question: "Bạn đang làm gì gần đây? Công việc hàng ngày của bạn trông như thế nào?"

Phase 2 — Context & Background (10 phút)
Mục đích: Hiểu bối cảnh, hiện trạng, và current solutions
Template câu hỏi mở:
"Hãy kể cho tôi nghe về lần gần nhất bạn [task liên quan đến domain]."
"Bạn thường làm việc đó như thế nào? Walk me through từng bước."
"Bạn dùng công cụ/cách nào hiện tại?"

Phase 3 — Journey & Pain Points (20 phút)
Mục đích: Đây là phần cốt lõi — map hành trình và phát hiện friction
Format câu hỏi scenario-based:
"Hãy kể về một lần gần đây khi bạn gặp khó khăn với [task]. Chuyện gì đã xảy ra?"
"Ở bước đó bạn đã làm gì? Tại sao bạn chọn làm vậy?"
"Điều gì khiến bạn thất vọng nhất? Bạn đã thử giải quyết như thế nào?"
Probing questions:
"Hãy kể thêm về điều đó."
"Ý bạn là [X]?" (để clarify, không leading)
"Điều gì xảy ra tiếp theo?"

Phase 4 — Closing (10 phút)
Mục đích: Thu thập unmet needs, ước mơ, và wrap up
"Nếu có thể thay đổi một điều với [current tool/process], đó là gì?"
"Sản phẩm lý tưởng với bạn trông như thế nào?"
"Có điều gì bạn muốn chia sẻ mà tôi chưa hỏi không?"
```

**5c. Question types và kỹ thuật probing**

```
Dùng câu hỏi mở (Open-ended):
✅ "Bạn làm điều đó như thế nào?" → Mô tả hành vi thực tế
✅ "Kể cho tôi nghe về lần gần nhất..." → Retrospective, story-based
✅ "Điều gì xảy ra khi...?" → Hành trình cụ thể

Câu hỏi scenario-based (khi cần context cụ thể):
"Hãy tưởng tượng bạn đang [tình huống điển hình của công việc họ].
 Bạn sẽ làm gì đầu tiên?"

Tránh (leading questions):
❌ "Bạn có thấy tính năng X hữu ích không?" → Sẽ confirmation bias
❌ "Bạn có muốn tính năng tự động không?" → Ai cũng muốn "automatic"
❌ "Có phải X làm bạn khó chịu không?" → Leading về pain point
```

### Bước 6: Hướng dẫn tránh bias

```
Bias phổ biến và cách phòng ngừa:

1. Confirmation Bias (tìm bằng chứng cho giả thuyết có sẵn)
   → Phòng ngừa: Viết giả thuyết trước interview, sau đó chủ động hỏi điều ngược lại

2. Social Desirability Bias (participant muốn làm hài lòng interviewer)
   → Phòng ngừa: Nhấn mạnh "không có đúng sai", hỏi về hành vi trong quá khứ thay vì ý kiến
   → "Lần cuối bạn làm X là khi nào?" thay vì "Bạn có thường làm X không?"

3. Acquiescence Bias (participant đồng ý với mọi đề xuất)
   → Phòng ngừa: Tránh câu hỏi Yes/No, dùng câu hỏi mở về trade-off
   → "Giữa A và B, bạn ưu tiên điều gì hơn và tại sao?"

4. Recency Bias (chỉ nhớ trải nghiệm gần nhất)
   → Phòng ngừa: Hỏi "trung bình" và "thường xuyên nhất" thay vì "gần nhất"
```

### Bước 7: Yêu cầu về consent

```
Consent phải cover:
□ Ghi âm/video (xin phép rõ ràng trước khi bắt đầu)
□ Mục đích sử dụng data (nghiên cứu nội bộ, không public)
□ Quyền withdraw bất cứ lúc nào mà không có hậu quả
□ Anonymization: participant được anonymize trong báo cáo

Cách ghi consent form đơn giản trong DEVKIT:
Bao gồm section "Consent Statement" trong interview guide với checklist:
"Participant đã đồng ý với: [ ] ghi âm, [ ] sử dụng data, [ ] anonymization"

Lưu ý GDPR/PDPA nếu dự án có users tại EU hoặc Thái Lan.
```

### Bước 8: Kế hoạch phân tích

```
Sau khi có raw data từ interviews, dùng framework sau:

STEP 1 — Note-taking trong session:
  Format: "[Participant ID]: [Hành vi quan sát] | [Quote trực tiếp]"
  Phân biệt FACT (điều participant làm) vs INFERENCE (diễn giải của researcher)

STEP 2 — Affinity Mapping (trong vòng 24h sau session):
  READ: .claude/references/team-expert/design/ux-research-methods.md
        → Section 6: Affinity Diagram / Research Synthesis Framework
  Quy trình: Capture (1 observation = 1 note) → Cluster (nhóm theo theme) →
              Theme (đặt tên hành vi) → Insight (format chuẩn) → Opportunity (HMW)

STEP 3 — Thematic Analysis:
  Đếm frequency của mỗi theme: "X/Y participants đề cập..."
  Priority theo: Frequency (bao nhiêu người gặp) × Severity (ảnh hưởng lớn đến mục tiêu của họ)

STEP 4 — Insight Statement:
  Format: "[Segment] cần [need cụ thể] vì [reason từ research data]"
  Ví dụ: "Kế toán SME cần xem lịch sử chỉnh sửa hóa đơn vì họ thường bị
          audit và phải chứng minh thay đổi có phê duyệt."
```

### Bước 9: Viết output

```
Ghi vào: .mc-data/docs/phase1-business/ux-research/interview-guide.md
(Tạo thư mục ux-research/ nếu chưa có)

Cấu trúc file output:
1. Research Overview
   - Mục tiêu nghiên cứu (3–5 câu hỏi research)
   - Phương pháp được chọn và lý do
   - Timeline dự kiến

2. Participant Criteria
   - Profile cho từng segment
   - Cỡ mẫu và lý do
   - Recruiting strategy

3. Screening Questions (5 câu)

4. Interview Guide
   - Warm-up script
   - Context & Background questions
   - Journey & Pain Points questions (kèm probing techniques)
   - Closing questions

5. Bias Avoidance Guidelines
   - 3–4 bias phổ biến nhất với cách phòng ngừa cụ thể

6. Consent Requirements
   - Danh sách điểm cần xin consent

7. Analysis Plan
   - Note-taking format
   - Affinity mapping process
   - Insight statement format

8. Success Criteria
   - Khi nào research được coi là đủ để tiếp tục design?
```

---

## Checklist trước khi submit

```
□ Câu hỏi research objectives được viết theo format chuẩn (WHO needs to know WHAT to decide WHAT)
□ Phương pháp được chọn khớp với loại câu hỏi nghiên cứu
□ Participant criteria đủ cụ thể để screening (không phải "người dùng chung chung")
□ Interview guide có đủ 4 phases: Warm-up → Context → Journey → Closing
□ Tất cả câu hỏi là open-ended, không leading
□ Ít nhất 3 bias đã được identify với cách phòng ngừa
□ Consent requirements được liệt kê đầy đủ
□ Analysis plan rõ ràng: note-taking → affinity mapping → insights
□ REQ-ID được tham chiếu nếu research nhắm đến requirements cụ thể
```
