# Playbook: Thiết kế và phân tích Usability Test

> **Type**: Agent Skill Playbook
> **Agent**: ux-researcher
> **Triggered by**: Phase 4 sau khi có design/prototype, hoặc post-implementation để validate sản phẩm thực tế
> **Output**: `.mc-data/docs/phase4-ux/usability-test-report.md`

---

## Khi nào dùng playbook này

- Phase 4: Prototype hoặc design đã đủ interactive để test được critical flows
- Post-implementation: Sản phẩm đã build — cần validate trước launch hoặc sau sprint
- Khi có specific usability concerns từ stakeholders hoặc từ `/wf-verify-sync`
- Khi task completion rate hoặc support ticket volume cho thấy vấn đề cụ thể

**Trong DEVKIT context**: Playbook này tạo ra TEST PROTOCOL và phân tích framework.
Phiên test thực tế do team dự án tổ chức với users thực — không phải AI simulate.

---

## Procedure

### Bước 1: Đọc design context và xác định test scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra paths theo thứ tự:
  - .mc-data/docs/phase4-ux/ (design specs, wireframes, prototypes)
  - .mc-data/docs/phase3-architecture/ (technical constraints)
  - .mc-data/docs/phase2-features/ (feature specs với acceptance criteria)
  - .mc-data/docs/phase1-business/ux-research/ (personas, interview data)

Cần xác định:
□ Đây là test loại gì? (prototype / staging environment / production)
□ Những flows nào là critical path của sản phẩm?
□ Có concerns cụ thể nào từ design review không?
□ Personas nào là target participants?
□ Timeline: khi nào cần kết quả để unblock next decision?
```

LOAD KNOWLEDGE:
```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 4: Usability Test Plan Template
      → Section 8: Quantitative Metrics Reference (SUS, task metrics)
```

### Bước 2: Xác định test objectives

```
Mỗi test phải có mục tiêu SMART — không phải "test xem usability tốt không":

Format chuẩn cho test objective:
"Xác định xem [persona cụ thể] có thể [task cụ thể] trong [thời gian mục tiêu]
 mà không cần hỗ trợ, để quyết định [design decision cụ thể]."

Ví dụ tốt:
"Xác định xem Kế toán SME có thể tạo và gửi invoice cho khách hàng mới
 trong < 3 phút mà không cần hướng dẫn, để quyết định xem onboarding flow
 hiện tại có đủ không hay cần tooltip."

Số objectives: 2–4 (nhiều hơn thì không đủ thời gian test)

Phân loại objectives:
□ PRIMARY — must answer, test thất bại nếu không trả lời được
□ SECONDARY — valuable nhưng có thể defer sang round test tiếp theo
```

### Bước 3: Thiết kế task scenarios

```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 4: Task Scenarios Format

Nguyên tắc thiết kế task scenarios:

REALISTIC — đặt vào bối cảnh thực tế của công việc người dùng:
✅ "Bạn vừa nhận được đơn hàng #1234 từ công ty Minh Long.
    Hãy tạo invoice cho đơn hàng này và gửi cho họ qua email."
❌ "Hãy tạo một invoice." (quá generic, thiếu context)

NON-LEADING — không reveal cách làm hoặc terms trong UI:
✅ "Tìm cách xem lại các giao dịch của tháng trước."
❌ "Click vào menu 'Lịch sử giao dịch' và lọc theo tháng." (chỉ đường luôn)

SPECIFIC — có end state rõ ràng để biết khi nào task complete:
✅ "Bạn hoàn thành khi thấy màn hình xác nhận invoice đã được gửi."
❌ "Hãy thử gửi invoice và xem kết quả." (không rõ success looks like what)

---

Format đầy đủ cho mỗi task scenario:

## Task [N]: [Task name ngắn gọn]

**Scenario:**
"[Mô tả tình huống — 2–4 câu đặt participant vào context thực tế]"

**Completion criteria (participant đạt khi):**
- [Endpoint cụ thể participant phải đến được]

**Time target:** < [X] phút

**Observer focus:**
- Chú ý: [Hành vi cụ thể cần ghi nhận]
- Common errors expected: [Những chỗ hay bị nhầm dựa trên design review]
- Không can thiệp trừ khi: [Participant kẹt > 3 phút VÀ có risk tổn hại data]

**Neutral hint (chỉ dùng nếu bị kẹt > 3 phút):**
"[Gợi ý không reveal answer — ví dụ: "Bạn đang cố gắng làm gì?" hoặc
"Hãy thử nghĩ xem thông tin đó thường nằm ở đâu trong ứng dụng tương tự."]"

---

Số tasks: 3–5 (nhiều hơn gây user fatigue, ảnh hưởng data quality)
Thứ tự: từ đơn giản → phức tạp để build confidence, không warm-up bằng core task khó
```

### Bước 4: Xác định metrics và success thresholds

```
READ: .claude/references/team-expert/design/ux-research-methods.md
      → Section 8: Quantitative Metrics Reference

METRICS CHUẨN cho mỗi usability test:

1. Task Completion Rate
   Đo: % participants hoàn thành task KHÔNG cần hint hoặc hỗ trợ
   Target: ≥ 80% (nếu <60% → critical issue, phải fix trước launch)
   Cách đo: Pass / Fail / Completed with assist (3 levels)

2. Time on Task
   Đo: Thời gian trung bình để hoàn thành (tính giây, start khi đọc xong scenario)
   Target: Xác định dựa trên business context (ví dụ: <3 phút cho core task)
   Note: Outliers (>2× median) thường là signal có confusion point

3. Error Rate
   Đo: Số lần click/input sai trung bình mỗi task
   Target: <2 errors per task (>5 → serious usability issue)
   Categories: Navigation errors / Input errors / Understanding errors

4. SUS Score (System Usability Scale)
   Đo: 10-item questionnaire, scale 0–100
   Target: ≥ 68 (industry average); ≥ 80 = good; ≥ 90 = excellent
   Thời điểm: Sau KHI participant hoàn thành tất cả tasks

   SUS Score interpretation:
   ≥ 90 : Xuất sắc ("Best Imaginable")
   80–89: Tốt
   68–79: Trên trung bình (acceptable)
   51–67: Dưới trung bình — cần cải thiện rõ ràng
   ≤ 50 : Không chấp nhận được

5. Qualitative Severity Rating (cho mỗi issue phát hiện)
   Critical  : Blocks task completion — phải fix trước launch
   Serious   : Gây confusion hoặc delay lớn — fix trong sprint này
   Minor     : Gây khó chịu nhỏ — backlog
   Enhancement: Cải thiện tốt nhưng không phải issue

THIẾT LẬP success criteria TRƯỚC KHI test (để tránh moving goalposts):

| Metric | Target | Fail threshold | Action if fail |
|--------|--------|----------------|----------------|
| Task completion rate | ≥ 80% | < 60% | Block launch, redesign |
| Time on task (core task) | < [X] phút | > 2× target | Review IA và labels |
| Error rate | < 2/task | > 5/task | Simplify flow |
| SUS Score | ≥ 68 | < 51 | Major redesign needed |
```

### Bước 5: Xây dựng test protocol

```
Test session structure (60 phút — điều chỉnh theo số tasks):

[00:00–05:00] Giới thiệu và consent
  Script:
  "Chào [tên], cảm ơn bạn đã dành thời gian hôm nay.
   Hôm nay chúng tôi sẽ nhờ bạn thử một số tác vụ với [app/prototype].
   Chúng tôi đang test sản phẩm, KHÔNG phải test bạn — không có đúng sai.
   Nếu bạn gặp khó khăn, đó là feedback quý giá cho chúng tôi.
   Bạn có đồng ý để chúng tôi ghi âm màn hình và giọng nói không?
   Bạn có thể dừng bất cứ lúc nào."

[05:00–10:00] Warm-up và background
  "Hãy kể cho tôi nghe về công việc của bạn — bạn thường làm gì hàng ngày?"
  "Bạn có dùng phần mềm gì tương tự không? Trải nghiệm của bạn thế nào?"
  → Mục đích: calibrate tech comfort, tạo thoải mái, không phải collect data

[10:00–45:00] Task scenarios (3–5 tasks)
  Cho mỗi task:
  a. Đọc scenario to cho participant nghe (không để họ đọc một mình)
  b. Confirm họ hiểu: "Bạn có câu hỏi gì về tình huống này không?"
  c. Start timer
  d. Observe và note-take — KHÔNG guide (dù khó kìm)
  e. Think-aloud prompt nếu im lặng: "Bạn đang nghĩ gì lúc này?"
  f. Stop timer khi complete hoặc abandoned
  g. Post-task questions: "Task này bạn thấy dễ hay khó? Scale 1–7?"

[45:00–55:00] SUS questionnaire
  10 câu, thang Likert 1–5. Participant tự điền.
  (Xem SUS items trong references knowledge file)

[55:00–60:00] Debrief interview
  "Điều gì khiến bạn khó khăn nhất hôm nay?"
  "Nếu thay đổi một điều, bạn muốn thay đổi gì?"
  "Tổng thể bạn cảm thấy thế nào về [app/product]?"

---

Think-aloud protocol:
"Trong khi làm task, hãy nói to những gì bạn đang nghĩ —
bạn đang cố làm gì, bạn đang tìm gì, bạn cảm thấy thế nào.
Không cần giải thích, chỉ cần nói to."

Khi participant im lặng > 10 giây:
✅ "Bạn đang nghĩ gì lúc này?"
✅ "Bạn đang cố làm gì?"
❌ "Bạn có muốn thử click vào [button] không?" (leading)
❌ "Chức năng đó ở [location]." (reveal answer)
```

### Bước 6: Observation và note-taking guide

```
PHÂN CÔNG ROLES trong test session:
- Moderator (1): Chạy session, đọc scenarios, probe
- Observer/Note-taker (1–2): Ghi notes, KHÔNG can thiệp vào session

NOTE-TAKING FORMAT trong session:

Mỗi observation note:
[TASK N] [TIMESTAMP] [TYPE]: [Observation]

Types:
[BEHAVIOR] → Participant làm gì thực sự
[ERROR]    → Participant click sai, hiểu nhầm
[QUOTE]    → Participant nói gì đáng chú ý
[CONFUSION]→ Participant có biểu hiện bối rối (dừng lại, nhìn xung quanh, cau mày)
[SUCCESS]  → Moment participant "gets it" — "Ah, tôi hiểu rồi"

Ví dụ notes:
[T2] [03:45] [ERROR]: Participant click "Settings" tìm invoice — expect ở nav chính
[T2] [04:12] [QUOTE]: "Tôi cứ nghĩ nút tạo mới ở đây chứ" (chỉ vào top bar)
[T2] [05:20] [CONFUSION]: Dừng 40 giây, scroll lên xuống, không tìm được FAB button

KHÔNG ghi:
❌ "Participant không biết cách dùng app" (đây là interpretation, không phải observation)
✅ "Participant click vào 3 menu khác nhau trước khi tìm được 'Tạo invoice'" (fact)
```

### Bước 7: Phân tích kết quả

```
Sau khi hoàn thành tất cả sessions, phân tích theo thứ tự:

BƯỚC 7a — Tổng hợp metrics định lượng

Với mỗi task, tính:
- Completion rate: X/N participants completed without assistance
- Average time: [minutes:seconds]
- Error count average: [N errors/task]

Tổng hợp SUS scores:
SUS calculation:
  Odd items (1,3,5,7,9): score = response - 1
  Even items (2,4,6,8,10): score = 5 - response
  Sum all scores × 2.5 = SUS score (0–100)
  Average SUS across all participants

BƯỚC 7b — Affinity mapping của qualitative data

Từ all observation notes:
1. Mỗi observation = 1 note
2. Nhóm theo chủ đề: "Navigation confusion", "Label clarity", "Flow expectations"
3. Đếm: bao nhiêu participants xuất hiện mỗi theme?
4. Priority matrix: Frequency × Severity

BƯỚC 7c — Issue list với severity ratings

Với mỗi issue phát hiện:

| Issue | Location | Severity | Evidence | N participants |
|-------|----------|----------|----------|----------------|
| [Mô tả] | [Màn hình/flow] | Critical/Serious/Minor | [Quote/observation] | X/N |

Severity decision:
Critical  : Participant không thể hoàn thành task VÀ không biết tiếp tục thế nào
Serious   : Participant hoàn thành nhưng mất > 2× target time hoặc cần hint
Minor     : Participant hoàn thành nhưng express frustration hoặc mắc small errors
Enhancement: Participant suggest improvement nhưng không gặp vấn đề thực sự

BƯỚC 7c — Root cause analysis

Với mỗi Critical/Serious issue, tìm root cause:
□ Navigation/IA issue: Element đúng nhưng khó tìm
□ Label/terminology issue: Tên không match mental model của user
□ Flow issue: Thứ tự bước không match expectation
□ Visual hierarchy issue: Quan trọng nhưng không nổi bật
□ Missing feedback issue: User không biết action đã succeed/fail
```

### Bước 8: Recommendation priorities

```
Sắp xếp recommendations theo ma trận Impact × Effort:

P0 — Phải fix trước launch (Critical issues):
  Impact: Blocks task completion
  Timeframe: Current sprint

P1 — Fix trong sprint tiếp theo (Serious issues):
  Impact: Significantly hurts UX nhưng có workaround
  Timeframe: Next sprint

P2 — Backlog (Minor issues + Enhancements):
  Impact: Polish và UX improvements
  Timeframe: Future sprints

Format recommendation:

### [P0/P1/P2] [Issue title]

**Vấn đề**: [Mô tả issue cụ thể]
**Evidence**: X/N participants gặp; quote: "[..."
**Root cause**: [Navigation / Label / Flow / Visual / Feedback]
**Đề xuất**: [Action cụ thể — đủ actionable cho designer implement]
**Metric để đo improvement**: [Metric nào sẽ improve sau khi fix]
**REQ-ID liên quan**: [Nếu issue liên quan đến specific requirement]
```

### Bước 9: Viết output

```
Ghi vào: .mc-data/docs/phase4-ux/usability-test-report.md

Cấu trúc file output:

1. Executive Summary
   - Số participants, method, dates
   - 3 key findings (most critical)
   - Overall SUS score và interpretation
   - Go/No-go recommendation cho launch (nếu pre-launch test)

2. Test Setup
   - Objectives
   - Method (moderated/unmoderated, in-person/remote)
   - Participant profile và số lượng
   - Test environment (prototype/staging/production)

3. Task Results Summary

| Task | Completion Rate | Avg Time | Errors | Status |
|------|----------------|----------|--------|--------|
| Task 1: [Name] | X% | Xm Ys | X | ✅ / ⚠️ / ❌ |

4. SUS Score
   - Overall score: [X]/100 — [Grade/Interpretation]
   - Per-item breakdown nếu cần deeper analysis

5. Key Findings (Detailed)
   - Mỗi finding: description + evidence + severity

6. Recommendations
   - P0 issues (phải fix)
   - P1 issues (nên fix sớm)
   - P2 issues (backlog)

7. Methodology Notes
   - Limitations của test này
   - Điều gì không được test — cần round tiếp theo
   - Sample biases nếu có

8. Next Steps
   - Design changes cần thực hiện
   - Timeline đề xuất
   - Follow-up test nếu cần (khi nào, scope gì)
```

---

## Checklist trước khi submit

```
□ Test objectives được viết theo format SMART với decision-link
□ Mỗi task scenario: realistic context, non-leading language, clear success criteria
□ Metrics table có target và fail thresholds được định trước
□ Test protocol đủ chi tiết cho moderator mới chạy được
□ Think-aloud prompt được include trong protocol
□ Note-taking guide phân biệt Behavior / Quote / Error / Confusion / Success
□ Phân tích có đủ: quantitative metrics + qualitative themes + severity ratings
□ Mỗi recommendation có root cause và action cụ thể
□ P0/P1/P2 priority được phân loại rõ ràng
□ REQ-ID được tham chiếu cho issues liên quan đến specific requirements
□ Executive summary có go/no-go recommendation (nếu pre-launch test)
□ File được ghi đúng path: .mc-data/docs/phase4-ux/usability-test-report.md
```
