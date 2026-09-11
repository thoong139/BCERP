# UX Research - Methods, Templates & Metrics Reference

> **Domain**: Design / UX Research
> **Last Updated**: 2026-03-15
> **Nguồn**: Nielsen Norman Group, IDEO Design Kit, Steve Krug "Rocket Surgery Made Easy", SUS/NPS methodology

---

## 1. Research Method Selection Matrix

| Method | Khi nào dùng | Sample size | Thời gian | Output chính |
|--------|-------------|:-----------:|:---------:|-------------|
| **User Interviews** | Hiểu mental model, pain points, context | 5–8 per segment | 3–4 tuần | Insights, quotes, themes |
| **Surveys** | Validate giả thuyết, đo lường rộng | 100–500+ | 1–2 tuần | Quantitative data, distributions |
| **Usability Testing (moderated)** | Phát hiện usability issues cụ thể | 5 per segment | 2–3 tuần | Task completion rate, issues list |
| **Usability Testing (unmoderated)** | Nhanh, nhiều participants hơn | 20–50 | 1 tuần | Videos, completion rates |
| **Card Sorting (open)** | Xây dựng information architecture | 15–30 | 1–2 tuần | Category clusters, mental models |
| **Card Sorting (closed)** | Validate IA hiện tại | 20–40 | 1 tuần | Match rates, confusion points |
| **Tree Testing** | Test navigation structure | 30–50 | 1–2 tuần | Findability rates, directness |
| **A/B Testing** | So sánh 2 solutions với traffic thực | 100–10,000+ | 2–4 tuần | Statistical significance, conversion |
| **Diary Studies** | Longitudinal behavior, long-term use | 10–20 | 2–4 tuần | Behavioral patterns over time |
| **Heuristic Evaluation** | Quick expert review, không cần users | 3–5 evaluators | 3–5 ngày | Violations list, severity ratings |
| **Competitive Analysis** | Benchmark, inspiration, gaps | N/A | 1–2 tuần | Feature matrix, opportunity areas |
| **Analytics Review** | Understand actual usage patterns | N/A (data driven) | 1 tuần | Funnel drop-offs, usage heatmaps |

**Quy tắc chọn method:**
- **Khám phá vấn đề mới** → Interviews, Diary Studies
- **Validate design** → Usability Testing, A/B Testing
- **Đo lường baseline** → Surveys, SUS, Analytics
- **Thiết kế IA** → Card Sorting → Tree Testing

---

## 2. User Interview Guide Template

### Screening Questions (trước khi mời)

```markdown
1. Bạn có thường xuyên sử dụng [product category] không? (loại nếu: Không)
2. Tần suất sử dụng của bạn là? (loại nếu: <1 lần/tuần đối với core use case)
3. Bạn thuộc nhóm tuổi nào? [18-25 / 26-35 / 36-45 / 46+]
4. Công việc hiện tại của bạn là gì?
5. Bạn có sử dụng [specific competitor] không? (để đa dạng sample)
```

### Interview Script Structure

**1. Warm-up (5 phút)**
```
"Cảm ơn bạn đã dành thời gian hôm nay. Buổi hôm nay kéo dài khoảng 45 phút.
Tôi sẽ hỏi về trải nghiệm của bạn với [domain], không phải test kiến thức.
Không có câu trả lời đúng hay sai. Bạn có thể nói thoải mái.
Bạn đang làm gì gần đây? (tạo không khí thoải mái)"
```

**2. Context & Background (10 phút)**
```
"Hãy kể cho tôi nghe về công việc/cuộc sống hàng ngày của bạn liên quan đến [domain]."
"Lần gần nhất bạn [task liên quan] là khi nào? Bạn đang làm gì?"
"Bạn thường sử dụng công cụ/cách nào để [task]?"
```

**3. Task & Journey (20 phút)**
```
"Hãy walk me through lần cuối bạn [specific task]. Bạn bắt đầu từ đâu?"
"Điều gì xảy ra tiếp theo?"
"Bạn cảm thấy thế nào ở bước đó?"
"Điều gì khiến bạn khó khăn nhất?"
"Bạn đã thử giải quyết khó khăn đó bằng cách nào?"
```

**4. Pain Points & Needs (10 phút)**
```
"Điều gì khiến bạn thất vọng nhất với [current solution]?"
"Nếu bạn có thể thay đổi một điều, đó là gì?"
"Bạn ước mình có thể làm gì mà hiện tại chưa thể?"
```

**5. Wrap-up (5 phút)**
```
"Còn điều gì bạn muốn chia sẻ mà tôi chưa hỏi không?"
"Nếu bạn phải mô tả trải nghiệm lý tưởng trong một câu, đó là gì?"
"Cảm ơn bạn rất nhiều!"
```

### Note-taking Template

```markdown
## Interview Notes: [Participant ID] — [Date]

**Background:** [Job, demographics, tech comfort]
**Current tools:** [What they use now]

### Key Quotes
- "[Direct quote]" — context: [when/why they said this]

### Behaviors Observed
- [What they do, not what they say they do]

### Pain Points
- [Pain 1]: Severity (Low/Med/High)
- [Pain 2]: Severity

### Unmet Needs
- [Need 1]

### Surprising Insights
- [Anything unexpected]

### Follow-up Questions
- [Questions to clarify in next round]
```

---

## 3. Persona Template

```markdown
## Persona: [Name] — "[Tagline describing their main goal]"

### Demographics
- Tuổi: [Range]
- Nghề nghiệp: [Job title, industry]
- Địa điểm: [Urban/suburban, city]
- Tech comfort: [Beginner / Intermediate / Power user]
- Thiết bị chính: [Mobile / Desktop / Both]

### Goals
1. [Primary goal — điều họ cố gắng đạt được]
2. [Secondary goal]
3. [Personal/emotional goal]

### Frustrations
1. [Pain point 1 với current solution]
2. [Pain point 2]
3. [Broader frustration với domain]

### Behaviors
- Thói quen: [Thường xuyên làm gì liên quan đến domain]
- Kênh ưa thích: [Email, SMS, App notification, phone call]
- Tần suất sử dụng: [Daily / Weekly / Monthly]
- Decision style: [Rational / Emotional / Social proof-driven]

### Quote
> "Một câu quote thực tế từ research, phản ánh mental model của persona này."

### Scenario
[Một đoạn văn ngắn mô tả một ngày/tình huống điển hình của persona,
cho thấy khi nào và tại sao họ sẽ dùng sản phẩm.]
```

---

## 4. Usability Test Plan Template

### Test Objectives

```markdown
Mục tiêu buổi test:
1. Xác định xem users có thể [primary task] mà không cần hỗ trợ không
2. Đo lường mức độ khó khăn khi [secondary task]
3. Thu thập feedback về [specific design decision]
```

### Task Scenarios Format

```markdown
## Task [N]: [Task name]

**Scenario:** Đặt người dùng vào context thực tế
"Bạn vừa nhận được email từ quản lý yêu cầu bạn [situation].
Hãy sử dụng ứng dụng này để hoàn thành việc đó."

**Success criteria:**
- Hoàn thành: User đến được [specific endpoint]
- Thời gian mục tiêu: < [X] phút
- Không cần gợi ý: [Yes/No]

**Observer notes:**
- Critical path: [Bước 1 → Bước 2 → Bước 3]
- Common errors to watch: [Known potential mistakes]
- Gợi ý nếu bị kẹt: "[Neutral hint without revealing answer]"
```

### Success Metrics

| Metric | Đo bằng | Target | Fail threshold |
|--------|---------|:------:|:--------------:|
| Task completion rate | % users hoàn thành không có gợi ý | >80% | <60% |
| Time on task | Trung bình tính giây/phút | Baseline | >2× baseline |
| Error rate | Số lỗi trung bình / task | <2 | >5 |
| SUS Score | System Usability Scale (0–100) | ≥68 | <51 |

### Think-Aloud Protocol

```
Hướng dẫn cho participant:
"Trong khi làm task, hãy nói to những gì bạn đang nghĩ —
những gì bạn thấy, đang cố gắng làm, và những gì đang xảy ra.
Không cần giải thích, chỉ cần nói to suy nghĩ của bạn."

Khi participant im lặng quá 10 giây:
"Bạn đang nghĩ gì lúc này?"

KHÔNG BAO GIỜ nói: "Bạn có muốn click vào [button] không?"
THAY VÀO ĐÓ: "Bạn sẽ làm gì tiếp theo?"
```

---

## 5. Journey Map Template

```
Persona: [Persona Name]
Scenario: [Tình huống cụ thể, ví dụ: "Lần đầu đăng ký tài khoản"]
Goal: [Mục tiêu của persona trong journey này]

STAGES:   [Awareness]    [Consideration]    [Decision]    [Onboarding]    [Retention]
          ──────────     ───────────────    ──────────    ────────────    ───────────

ACTIONS:  Thấy quảng    So sánh với        Đăng ký       Setup profile   Dùng lần 2
          cáo FB        competitors        tài khoản     và preferences

THOUGHTS: "Cái này      "Giá có hợp        "Nhập thông   "Phần này       "Mình cần
          trông ổn"     lý không?"         tin mãi"      để làm gì?"     tính năng X"

EMOTIONS: 😐 Tò mò      🤔 Phân vân        😤 Mệt mỏi    😕 Bối rối      😊 Hài lòng
          (Neutral)     (Uncertain)        (Frustrated)  (Confused)      (Positive)

PAIN      Chưa rõ      Khó tìm info       Form quá      Onboarding      Thiếu
POINTS:   giá trị      pricing            dài           unclear         tính năng

OPPORT-   Clear value   Pricing page       Progressive   Guided          Feature
UNITIES:  proposition   improvement        disclosure    onboarding      request flow
```

---

## 6. Affinity Diagram / Research Synthesis Framework

**Quy trình từ raw data → insights:**

```
1. CAPTURE (Raw data)
   Mỗi observation/quote = 1 sticky note
   Format: "[Participant ID]: [Observation]"
   Ví dụ: "P3: Tìm nút submit mất 30 giây vì không nổi bật"

2. CLUSTER (Grouping)
   Nhóm các sticky notes có chủ đề tương tự
   Đặt tên nhóm = hành vi, không phải feature

3. THEME (Abstraction)
   Nhóm các clusters → Higher-level themes
   Ví dụ cluster: "Tìm nút lâu", "Không biết đang ở đâu", "Bỏ lỡ bước quan trọng"
   → Theme: "Navigation và orientation"

4. INSIGHT (So what?)
   Mỗi theme → 1 insight statement
   Format: "[User segment] cần [need] vì [reason revealed by research]"
   Ví dụ: "Người dùng mới cần visual progress indicators vì họ không biết
           quy trình có bao nhiêu bước và mất phương hướng."

5. OPPORTUNITY (How might we?)
   Mỗi insight → 1+ HMW question
   "How might we giúp người dùng biết họ đang ở bước nào trong quy trình?"
```

---

## 7. Research Reporting Template

```markdown
# UX Research Report: [Project Name]
**Date:** YYYY-MM-DD | **Researcher:** [Name] | **Method:** [Method used]

## Executive Summary
[2-3 câu tóm tắt key findings và recommendation quan trọng nhất]

## Objectives
1. [Objective 1]
2. [Objective 2]

## Methodology
- Method: [Usability testing / Interviews / ...]
- Participants: [N participants, segments, screening criteria]
- Duration: [Date range, session length]
- Tools: [Zoom, Maze, UserTesting, ...]

## Key Findings

### Finding 1: [Title]
- **Severity:** Critical / Major / Minor
- **Evidence:** [N/N participants gặp vấn đề này]
- **Quote:** > "[Representative quote]"
- **Impact:** [Business/user impact nếu không giải quyết]

### Finding 2: [Title]
[Same structure]

## Metrics Summary
| Metric | Result | Benchmark | Status |
|--------|--------|-----------|--------|
| Task completion rate | 72% | >80% | ⚠️ Below target |
| SUS Score | 74 | >68 | ✅ Above average |
| Time on task (T1) | 3m 20s | <2m | ⚠️ Too slow |

## Recommendations

| Priority | Recommendation | Effort | Finding |
|----------|---------------|--------|---------|
| P0 | [Action item] | Low | Finding 1 |
| P1 | [Action item] | Medium | Finding 2 |
| P2 | [Action item] | High | Finding 3 |

## Next Steps
1. [ ] Share với design team — [deadline]
2. [ ] Prioritize P0 fixes trong sprint [N]
3. [ ] Schedule follow-up test sau khi fix — [date]
```

---

## 8. Quantitative Metrics Reference

### System Usability Scale (SUS)

SUS gồm 10 câu hỏi, thang 1–5. Score cuối từ 0–100.

| Score | Grade | Interpretation |
|-------|:-----:|----------------|
| ≥ 90 | A+ | Xuất sắc — "Best Imaginable" |
| 85–89 | A | Xuất sắc |
| 80–84 | B | Tốt |
| 68–79 | C | Trên trung bình (industry average = 68) |
| 51–67 | D | Dưới trung bình, cần cải thiện |
| ≤ 50 | F | Không chấp nhận được |

**Industry average:** 68 (acceptable minimum cho sản phẩm thương mại)

### NPS (Net Promoter Score)

```
Câu hỏi: "Bạn có khả năng recommend [product] cho người khác không?" (0–10)

Promoters (9–10): Rất hài lòng, sẽ giới thiệu
Passives   (7–8):  Hài lòng nhưng không nhiệt tình
Detractors (0–6): Không hài lòng, có thể nói xấu

NPS = % Promoters − % Detractors

Interpretation:
< 0    : Rất tệ
0–30   : Cần cải thiện
30–70  : Tốt
> 70   : Xuất sắc (World class)
```

### CSAT (Customer Satisfaction Score)

```
Câu hỏi: "Bạn hài lòng với [experience] như thế nào?" (1–5 hoặc 1–10)

CSAT = (Số phản hồi tích cực / Tổng phản hồi) × 100%

Benchmark:
> 80% : Tốt
70–80%: Trung bình
< 70% : Cần cải thiện
```

### Task Success Metrics

| Metric | Formula | When to use |
|--------|---------|-------------|
| Completion rate | Completed / Total attempts | Primary usability KPI |
| Time on task | Avg seconds to complete | Efficiency measurement |
| Error rate | Total errors / Total tasks | Learnability |
| Lostness | Based on page visits vs optimal path | Navigation effectiveness |
| Confidence rating | Self-reported 1–7 scale | Subjective ease |

---

## 9. Research Cadence Recommendation

| Phase | Research Activity | Timing |
|-------|-----------------|--------|
| Discovery | User interviews, competitive analysis | Sprint 0 / Pre-project |
| Design | Concept testing, prototype testing | Midway through design |
| Pre-launch | Usability testing (near-final prototype) | 4–6 tuần trước launch |
| Post-launch | Analytics review, surveys, interviews | 4–8 tuần sau launch |
| Continuous | Unmoderated testing, feedback collection | Ongoing |

**Minimum research cho một feature quan trọng:** 5 usability test sessions + post-launch analytics review sau 30 ngày.
