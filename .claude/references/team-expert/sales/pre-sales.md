# Sales Domain - Pre-Sales & Technical Evaluation

> **Domain**: Sales / Quản trị Bán hàng
> **Last Updated**: 2026-03-15
> **Nguồn**: Tổng hợp từ sales-engineer, sales-deal-strategist (agency-agents)

---

## 1. Technical Discovery

Structured needs analysis để hiểu architecture, integration requirements, security constraints, và real technical decision criteria.

### Checklist Technical Discovery

| Category | Thông tin cần thu thập |
|----------|----------------------|
| **Tech Stack** | Languages, frameworks, infrastructure |
| **Integration Points** | APIs, databases, middleware |
| **Security Requirements** | SSO, SOC 2, data residency, encryption |
| **Scale** | Users, data volume, transaction throughput |
| **Existing Pain** | Current workaround, manual processes |
| **Evaluation Timeline** | Decision date, go-live target |

### Technical Decision Makers Map

```
| Name | Role | Priority (họ care gì) | Disposition |
|------|------|------------------------|-------------|
| [Name] | [Title] | [Technical concern] | Favorable / Neutral / Skeptical |
```

---

## 2. Demo Engineering — Technical Storytelling

### Nguyên tắc: Lead With Impact, Not Features

Demo KHÔNG phải product tour. Demo là narrative nơi buyer thấy problem được solve real-time.

### 4-Step Demo Structure

| Bước | Mô tả | Thời gian |
|------|--------|-----------|
| 1. **Quantify the problem** | Restate buyer's pain với specifics từ discovery. "Bạn nói team mất 6 giờ/tuần manually reconciling..." | 2-3 phút |
| 2. **Show the outcome** | Lead với end state — dashboard, report, workflow result — trước khi giải thích how | 5-8 phút |
| 3. **Reverse into the how** | Khi buyer đã react ("exactly what we need"), walk back qua configuration, setup | 10-15 phút |
| 4. **Close with proof** | Customer reference hoặc benchmark mirror tình huống buyer | 2-3 phút |

### Demo Preparation Checklist

- [ ] Map buyer's top 3 pain points → specific product capabilities
- [ ] Identify audience: technical evaluators cần architecture depth; business sponsors cần outcomes
- [ ] Chuẩn bị 2 demo paths: planned narrative + flexible deep-dive
- [ ] Dùng terminology của buyer, không dùng product vocabulary
- [ ] Xác định "Aha Moment" — capability nào sẽ land hardest cho audience này

### "Aha Moment" Test

Mỗi demo phải produce ít nhất 1 khoảnh khắc buyer nghĩ "that's exactly what we need." Nếu demo kết thúc mà moment đó chưa xảy ra → demo thất bại.

---

## 3. POC (Proof of Concept) Scoping

POC KHÔNG phải free trial. Là structured evaluation với binary outcome: pass hoặc fail.

### Design Principles

| Nguyên tắc | Mô tả |
|------------|-------|
| **Problem statement first** | "POC sẽ chứng minh [product] có thể [capability] trong [buyer's env] trong [timeframe], đo bằng [criteria]" |
| **Success criteria trước khi bắt đầu** | Ambiguous criteria → ambiguous outcome → "cần thêm thời gian" → thua |
| **Scope aggressively** | Focused POC chứng minh 1 điều quan trọng > sprawling POC chứng minh không rõ ràng |
| **Hard timeline** | 2-3 tuần. Longer POC = evaluation fatigue + competitor counter-moves |
| **Checkpoints** | Midpoint review để catch misalignment sớm |

### POC Execution Template

```
# Proof of Concept: [Account Name]

## Problem Statement
[Một câu: POC này chứng minh điều gì]

## Success Criteria (agreed trước khi bắt đầu)
| Criterion              | Target          | Measurement Method     |
|------------------------|-----------------|------------------------|
| [Specific capability]  | [Quantified]    | [How to measure]       |
| [Integration req]      | [Pass/Fail]     | [Test scenario]        |
| [Performance]          | [Threshold]     | [Load test / timing]   |

## Scope
In scope: [Specific features, integrations, workflows]
Out of scope: [What we're NOT testing and why]

## Timeline
- Day 1-2: Environment setup
- Day 3-7: Core use case implementation
- Day 8: Midpoint review
- Day 9-12: Refinement and edge cases
- Day 13-14: Final readout and decision

## Decision Gate
GO / NO-GO based on success criteria above.
```

---

## 4. Competitive Technical Positioning

### FIA Framework — Fact, Impact, Act

| Component | Mô tả | Ví dụ |
|-----------|--------|-------|
| **Fact** | Sự thật khách quan về competitor. Không spin, không exaggerate. | "Competitor X cần ETL layer riêng cho data ingestion" |
| **Impact** | Tại sao fact này quan trọng cho buyer | "= team maintain thêm 1 integration point, +2-3 tuần implementation + ongoing maintenance" |
| **Act** | Talk track cụ thể, câu hỏi, hoặc demo moment | "Hỏi sớm: 'Hiện tại xử lý data consolidation across subsidiaries thế nào?'" |

### Winning / Battling / Losing Zones

| Zone | Strategy |
|------|----------|
| **Winning** | Architecture/performance demonstrably superior. Build demo moments. Make criteria weighted heavily. |
| **Battling** | Cả 2 đều adequate. Shift conversation sang implementation speed, TCO, operational overhead. |
| **Losing** | Competitor genuinely stronger. Acknowledge. Reframe: "Họ excellent ở X. Customers thường thấy Y matters hơn at scale vì..." |

### Competitive Battlecard Template

```
# Battlecard: [Competitor Name]

## Positioning: [Winning / Battling / Losing]
## Encounter Rate: [% deals xuất hiện]

### Where We Win
- [Differentiator]: [Why it matters to buyer]
- Talk Track: "[Exact language]"

### Where We Battle
- [Shared capability]: [How to create separation]
- Talk Track: "[Exact language]"

### Where We Lose
- [Their strength]: [Repositioning strategy]
- Talk Track: "[How to shrink importance without attacking]"

### Landmine Questions (cho Discovery)
- "[Câu hỏi surface requirement mình mạnh nhất]"
- "[Câu hỏi expose gap trong approach competitor]"

### Trap Handling
- Nếu buyer nói "[competitor claim]" → respond "[reframe]"
```

### Nguyên tắc: Reposition, không Attack

> Không bao giờ trash competition. Buyers respect SEs acknowledge competitor strengths while articulate differentiation rõ ràng.
> Pattern: "Họ great cho [acknowledged strength]. Customers chúng tôi thường cần [different requirement] vì [business reason], đó là nơi approach khác nhau."

---

## 5. Technical Objection Handling

| Buyer nói | Thực chất | Response Strategy |
|-----------|-----------|-------------------|
| "Có support SSO không?" | "Có pass security review không?" | Walk through full security architecture, không chỉ SSO checkbox |
| "Xử lý được scale của chúng tôi không?" | "Đã bị vendor burn trước đó" | Benchmark data từ customer equal/greater scale |
| "Cần on-prem" | Security team không approve cloud, hoặc sunk cost data center | Hiểu cái nào — conversations completely different |
| "Competitor cho xem X" | "Match được không?" hoặc "Convince tôi bạn tốt hơn" | Không react theo framing competitor. Reground requirements trước. |
| "Cần build nội bộ" | Không trust vendor dependency, hoặc engineering team muốn project | Quantify build cost (team, time, maintenance) vs buy cost. Make opportunity cost tangible. |

---

## 6. Evaluation Notes Template

```
# Evaluation Notes: [Account Name]

## Technical Environment
- Stack: [Languages, frameworks, infrastructure]
- Integration Points: [APIs, databases, middleware]
- Security: [SSO, SOC 2, data residency, encryption]
- Scale: [Users, data volume, transactions]

## Technical Decision Makers
| Name | Role | Priority | Disposition |
|------|------|----------|-------------|

## Discovery Findings
- [Key technical requirement + why matters]
- [Integration constraint → shapes solution design]
- [Performance requirement + specific threshold]

## Competitive Landscape
- [Competitor]: [Technical positioning in this deal]
- Differentiators to emphasize: [mapped to buyer priorities]

## Demo / POC Strategy
- Primary narrative: [Story arc for this buyer]
- Aha moment target: [Which capability lands hardest]
- Risk areas: [Where to prepare objection handling]
```

---

## Quick Reference: Pre-Sales Metrics

| Metric | Target | Ý nghĩa |
|--------|--------|---------|
| Technical Win Rate | 70%+ | Deals có SE engaged qua full evaluation |
| POC Conversion | 80%+ | POCs convert to commercial negotiation |
| Demo-to-Next-Step | 90%+ | Demos result in defined next action |
| Time to Technical Decision | Median 18 ngày | First discovery → technical close |
| Competitive Win Rate | 65%+ | Head-to-head evaluations |
