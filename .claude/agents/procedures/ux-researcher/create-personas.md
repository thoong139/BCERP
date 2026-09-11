# Playbook: Tạo User Personas

> **Type**: Agent Skill Playbook
> **Agent**: ux-researcher
> **Triggered by**: Phase 1 khi cần tổng hợp research data thành personas để định hướng design
> **Output**: `.mc-data/docs/phase1-business/ux-research/user-personas.md`

---

## Khi nào dùng playbook này

- Sau khi đã có research data (interviews, surveys, analytics) từ `design-user-interview.md`
- Được gọi trong `/wf-analyze-requirements` hoặc `/wf-design-ux`
- Khi team design cần reference point để đưa ra quyết định "design cho ai"
- Khi stakeholders không đồng thuận về target user — personas cung cấp shared language

**Lưu ý quan trọng**: Personas phải được xây dựng từ data thực tế, không phải từ giả thuyết.
Nếu chưa có research data, chạy `design-user-interview.md` trước, hoặc ghi rõ
"Provisional persona — cần validate bằng research" trong output.

---

## Procedure

### Bước 1: Thu thập và kiểm kê research data đầu vào

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: .mc-data/docs/phase1-business/ux-research/

Kiểm kê data có sẵn:
□ Interview notes/transcripts — nguồn qualitative chính
□ Survey responses — quantitative data về behaviors và attitudes
□ Analytics data — actual usage patterns (nếu dự án là existing product)
□ Support ticket themes — pain points người dùng đã report
□ Sales call notes — objections và use cases thực tế
□ Diary study logs (nếu có) — longitudinal behavioral data

Đánh giá chất lượng data:
- Số participants đã phỏng vấn: [N] (≥5 để có basic patterns)
- Diversity của sample: có đại diện nhiều segment không?
- Data recency: data có <6 tháng không? (nếu cũ hơn → flag cần refresh)
```

LOAD KNOWLEDGE:
```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 3: Persona Template
      → Section 6: Affinity Diagram / Research Synthesis Framework
```

### Bước 2: Phân tích patterns hành vi trong data

```
Quy trình synthesis từ raw data → behavioral patterns:

BƯỚC 2a — Đọc và tag raw data
Đọc toàn bộ interview notes. Với mỗi observation, tag:
  [GOAL]      → Mục tiêu người dùng muốn đạt
  [BEHAVIOR]  → Hành vi thực tế họ làm
  [PAIN]      → Điểm khó khăn, friction
  [WORKAROUND] → Cách họ tự giải quyết khi bị chặn
  [QUOTE]     → Câu trực tiếp đáng trích dẫn
  [CONTEXT]   → Điều kiện môi trường ảnh hưởng hành vi

BƯỚC 2b — Cluster theo behavioral patterns
Nhóm participants không phải theo demographics mà theo:
  - "Người dùng ưu tiên [tốc độ / chính xác / đơn giản]"
  - "Người dùng quyết định [cá nhân / theo nhóm / theo quy định]"
  - "Người dùng có kinh nghiệm [cao / trung / thấp] với domain"

QUAN TRỌNG — Tại sao dùng behaviors thay vì demographics:
  Hai người cùng tuổi, cùng ngành có thể có mental model hoàn toàn khác nhau.
  Hành vi và mục tiêu là predictor tốt hơn của "họ cần gì từ sản phẩm."

BƯỚC 2c — Identify key differentiators
Với mỗi cluster, trả lời:
  "Điều gì khác biệt nhất giữa cluster này và cluster kia?"
  → Đây là key dimensions để phân biệt personas.
```

### Bước 3: Phân đoạn người dùng thành personas

```
Quy tắc số lượng personas:
- 2–4 personas là lý tưởng cho hầu hết sản phẩm
- >5 personas: thường là triệu chứng chưa synthesis đủ — merge các personas tương đồng
- 1 persona: chỉ phù hợp khi sản phẩm THỰC SỰ chỉ có 1 loại người dùng

Cho mỗi persona, xác định:

1. PRIMARY PERSONA — người dùng chính, thiết kế phải serve họ trước tiên
   → Chiếm nhiều nhất trong user base hoặc có impact lớn nhất đến business
   → "Nếu chỉ có thể phục vụ 1 nhóm, đó là nhóm này"

2. SECONDARY PERSONA (0–2) — nhóm quan trọng nhưng có nhu cầu khác
   → Thiết kế không cần optimize hoàn toàn cho họ, nhưng không được block họ

3. NEGATIVE/ANTI-PERSONA — ai KHÔNG phải target user
   → Quan trọng để team không bị phân tâm bởi edge cases
   → Ví dụ: "Power users muốn customize mọi thứ" nếu sản phẩm nhắm SME
```

### Bước 4: Xây dựng chi tiết từng persona

Cho mỗi persona, điền đầy đủ các mục sau. MỌI thông tin phải có evidence từ data:

```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 3: Persona Template

ĐIỀN THEO FORMAT:

---
## Persona [N]: [Tên] — "[Tagline: một câu mô tả mục tiêu chính]"

### Nguồn gốc từ data
Dựa trên: [N] phỏng vấn, [N] survey responses, [data source khác]
Đại diện cho: [%] hoặc [loại] người dùng

### Nhân khẩu học và bối cảnh
[Điền các thông tin demographics — nhưng chỉ những điều ảnh hưởng đến hành vi với sản phẩm]
- Tuổi: [Range từ data, ví dụ: 28–42]
- Nghề nghiệp & vị trí: [Job title, cấp độ, ngành]
- Địa điểm & môi trường làm việc: [Văn phòng / Remote / Di động]
- Tech comfort: [Beginner / Intermediate / Power User] — dựa trên observation
- Thiết bị chính: [Mobile / Desktop / Both] — dựa trên data, không đoán

### Mục tiêu (Goals)
Phân biệt 3 level:
1. PRACTICAL GOAL — muốn hoàn thành gì với sản phẩm này
   Ví dụ: "Approve hóa đơn trước 5pm để kế toán đóng sổ"
2. EXPERIENTIAL GOAL — muốn cảm thấy gì khi dùng sản phẩm
   Ví dụ: "Tự tin rằng không bỏ sót bước nào quan trọng"
3. LIFE GOAL — mục tiêu lớn hơn trong công việc/cuộc sống
   Ví dụ: "Được nhận xét là người quản lý tài chính chắc chắn"

### Frustrations (Pain Points)
[3–5 pain points, sắp xếp từ nghiêm trọng nhất đến nhỏ nhất]
Mỗi pain point phải có evidence:
- [Pain]: "[Quote trực tiếp hỗ trợ]" — N/M participants đề cập

### Behaviors (Hành vi quan sát được)
[Những gì họ THỰC SỰ LÀM, không phải những gì họ NÓI họ làm]
- Tần suất sử dụng: [Daily / Weekly / As-needed]
- Workarounds hiện tại: [Cách họ tự giải quyết friction hiện tại]
- Decision style: [Quyết định nhanh / cần nhiều thông tin / cần approval]
- Kênh liên lạc ưa thích: [Phù hợp cho notifications, support]

### Tech Comfort Level
[Chi tiết hơn — quan trọng cho UI complexity decisions]
- Comfort với: [Mobile apps / Desktop software / Web tools]
- Ứng dụng đang dùng tương tự: [Tên apps — cho benchmark expectations]
- Learning style: [Prefer exploring / Prefer tutorials / Prefer asking colleagues]

### Key Quote
> "[Một quote thực tế từ interview, phản ánh mental model hoặc pain point điển hình nhất]"
— [Participant ID], [Job title]

### Một ngày điển hình (Scenario)
[1–2 đoạn mô tả context cụ thể khi persona sẽ dùng sản phẩm]
Ví dụ: "Vào mỗi sáng thứ Hai, Minh mở laptop và đầu tiên là kiểm tra..."
→ Scenario phải cho thấy WHEN, WHERE, và WITH WHOM họ dùng sản phẩm.

### Ảnh hưởng đến design
[2–3 bullet points: implications cụ thể cho UX/UI dựa trên persona này]
- Vì [trait/goal], design cần [specific design direction]
- Vì [frustration], tránh [design anti-pattern]
---
```

### Bước 5: Validate personas với data

```
Checklist validation — không submit nếu chưa qua:

□ Mỗi persona có thể "đối chiếu" với ít nhất 2 participants thực trong data?
  (Nếu không → persona đó là fictional, không phải research-based)

□ Các personas đủ KHÁC NHAU để cần design decisions khác nhau?
  (Nếu giống nhau → merge thành 1)

□ Có ít nhất 1 quote thực từ participant cho mỗi key trait?
  (Quote không nhất thiết hoàn hảo — tốt hơn là authentic)

□ Goals được viết từ góc nhìn người dùng, không phải từ góc nhìn sản phẩm?
  ✅ "Muốn finish task trước khi họp" (user's perspective)
  ❌ "Muốn dùng tính năng batch processing" (product feature, không phải goal)

□ Pain points là điều họ thực sự gặp, không phải assumptions của team?
```

### Bước 6: Xây dựng Anti-Persona

```
Anti-persona là người KHÔNG phải target — quan trọng để set boundaries cho design.

Anti-persona template:
---
## Anti-Persona: [Tên mô tả loại người này]

**Đặc điểm**: [Mô tả ngắn]
**Tại sao họ KHÔNG phải target**:
- [Lý do 1 — liên quan đến business model]
- [Lý do 2 — nhu cầu khác biệt hoàn toàn]

**Rủi ro nếu design cho họ**:
[Điều gì sẽ xảy ra với primary persona nếu optimize cho anti-persona?]

**Cách xử lý**:
[Sản phẩm có support họ ở mức nào? Edge cases nào được chấp nhận?]
---

Ví dụ anti-persona tốt:
- Sản phẩm HR tool → Anti-persona: IT Admin muốn access full database
- Sản phẩm SME accounting → Anti-persona: Big4 auditor cần IFRS compliance
```

### Bước 7: Persona Application Guidelines

```
Hướng dẫn cách team dùng personas trong design decisions:

FRAMEWORK ra quyết định bằng personas:
1. "Design này phục vụ [Primary Persona] như thế nào?"
2. "Design này có block [Secondary Persona] không?"
3. "Nếu [Primary Persona] và [Secondary Persona] muốn điều khác nhau,
    ưu tiên ai? Tại sao?"

Khi nào invoke personas:
□ Khi viết user stories: "As [Persona Name], I want..."
□ Khi design information architecture: "Persona nào tìm thông tin này đầu tiên?"
□ Khi quyết định progressive disclosure: "Persona nào cần detail, persona nào cần simplicity?"
□ Khi prioritize features: "Feature này giải quyết pain point của primary persona không?"

Khi nào KHÔNG dùng personas như argument duy nhất:
- Quyết định kỹ thuật (personas không biết về trade-offs implementation)
- Business model decisions (personas không biết về unit economics)
- Legal/compliance requirements (không thể negotiate dựa trên personas)
```

### Bước 8: Viết output

```
Ghi vào: .mc-data/docs/phase1-business/ux-research/user-personas.md
(Tạo thư mục ux-research/ nếu chưa có)

Cấu trúc file output:
1. Research Foundation
   - Data sources đã sử dụng (N interviews, N surveys, etc.)
   - Methodology note: Personas được tạo từ behavioral clustering, không demographics

2. Persona Overview Map
   - Table tóm tắt tất cả personas: Tên | Tagline | % User Base | Priority
   - Anti-persona(s)

3. Chi tiết từng Primary + Secondary Persona
   (Theo format Bước 4)

4. Anti-Persona
   (Theo format Bước 6)

5. Persona Application Guidelines
   (Theo format Bước 7)

6. REQ-ID Mapping
   - Liên kết personas với requirements: "Persona [X] là primary user cho REQ-[...]"
```

---

## Checklist trước khi submit

```
□ Mọi claim về persona đều có evidence từ research data
□ Personas phân đoạn theo behavioral patterns, không chỉ demographics
□ 2–4 personas (không nhiều hơn để maintain focus)
□ Primary persona được xác định rõ ràng
□ Anti-persona được include để set scope boundaries
□ Mỗi persona có key quote thực từ participant
□ Goals được viết từ góc nhìn người dùng (không phải tính năng sản phẩm)
□ Persona Application Guidelines giúp team đưa ra decisions
□ REQ-ID được liên kết với personas liên quan
□ File được ghi đúng path: .mc-data/docs/phase1-business/ux-research/user-personas.md
```
