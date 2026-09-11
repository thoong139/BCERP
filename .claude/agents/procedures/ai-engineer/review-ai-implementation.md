# Playbook: Review AI Implementation

> **Type**: Agent Skill Playbook
> **Agent**: ai-engineer
> **Triggered by**: Code review cho AI-powered features (từ code-reviewer hoặc /wf-implement-feature)
> **Output**: AI implementation review report

---

## Khi nào dùng playbook này

- Khi review code của feature có tích hợp AI/ML model
- Khi code-reviewer gọi ai-engineer để assess AI-specific risks
- Khi cần validate security, cost, latency, fallback của AI integration trước khi merge
- Khi review ML pipeline code trước khi deploy lên production

---

## Procedure

### Bước 1: Xác định scope review

```
INPUT: File paths hoặc PR diff cần review
FALLBACK: tra .claude/references/path-registry.md → code implement gần đây

Xác định:
□ Loại AI integration: LLM API / ML endpoint / embedded model / RAG pipeline
□ Provider: OpenAI / Anthropic / Google Vertex / AWS SageMaker / custom
□ REQ-ID tương ứng
□ Input/output data types
□ Môi trường deploy: production / staging
```

### Bước 2: Prompt injection risks (LLM)

```
CHỈ áp dụng khi code dùng LLM. Prompt injection là lỗ hổng nghiêm trọng.

Direct prompt injection:
□ User input có được đưa TRỰC TIẾP vào system prompt không?
  → Xấu: f"You are helpful. User question: {user_input}"
  → Tốt: system_prompt = "You are helpful." + user_message = user_input (tách riêng)
□ Có delimiter rõ ràng giữa trusted instructions và untrusted user content?
  → Dùng XML tags: <user_input>{sanitized_input}</user_input>
  → Dùng triple backticks cho code/data

Indirect prompt injection:
□ Nếu model đọc external content (web scraping, document, DB records) → content đó có thể chứa injected instructions
□ Có sanitize external content trước khi đưa vào context không?
□ Có instruction hierarchy rõ ràng: system > user > retrieved content?

Jailbreak prevention:
□ Model có được instructed để từ chối out-of-scope requests không?
□ Output có được validate trước khi execute (nếu model generate code/SQL)?
□ Không execute model-generated code trực tiếp mà không sandbox

Checklist:
□ User content được tách khỏi system prompt → SAFE / RISK
□ External content được sanitize → SAFE / RISK / N/A
□ Model output không được execute trực tiếp → SAFE / RISK / N/A
```

### Bước 3: Hallucination handling

```
LLM có thể bịa thông tin ("hallucinate"). Code phải handle điều này.

Patterns phát hiện hallucination risk:
□ Có yêu cầu model đưa ra facts cụ thể (giá cả, dates, tên người, pháp lý) không?
  → Nếu có: phải ground model với external data (RAG) — không để model tự bịa
□ Có citation/source reference được yêu cầu không?
  → Verify sources tồn tại và match với nội dung
□ Model output có được sử dụng cho quyết định high-stakes không?
  → Phải có human-in-the-loop review

Mitigation trong code:
□ RAG pipeline: model CHỈ được sử dụng thông tin từ retrieved context
□ System prompt có instruction "Nếu không biết, nói không biết" không?
□ Confidence scoring: model có trả về confidence không? Có threshold không?
□ Output validation: facts trong output có được verify ngược lại với known data?

High-stakes use cases cần human review:
□ Legal / medical / financial advice
□ Credit decisions, hiring decisions
□ Content với regulatory implications
```

### Bước 4: Bias risks

```
AI models thừa hưởng bias từ training data. Review cần identify potential harm.

Phân loại bias cần check:

Demographic bias:
□ Feature có đưa ra quyết định ảnh hưởng đến người dùng theo demographic không?
  (hiring, credit, healthcare, content recommendation)
□ Có test output trên các nhóm khác nhau (gender, age, ethnicity, location)?
□ Kết quả có khác nhau đáng kể giữa các nhóm không?

Language bias:
□ Model được train chủ yếu trên tiếng Anh — performance có đảm bảo với tiếng Việt không?
□ Test cases có cover cả nội dung tiếng Việt không?
□ Có bias với content từ một vùng địa lý/văn hóa cụ thể không?

Data bias (ML models):
□ Training data có representative cho production distribution không?
□ Có documentation về bias testing results trong model card không?
□ Có monitoring để detect bias drift trong production không?

Actionable checks:
□ Bias test report đã được run trước khi integrate model → có / không / N/A
□ Fairness metrics documented (demographic parity, equal opportunity) → có / không / N/A
□ Human review process cho sensitive decisions → có / không / N/A
```

### Bước 5: Cost per request estimate

```
AI inference cost có thể tăng đột biến nếu không được kiểm soát.

LLM cost calculation:
□ Xác định model đang dùng và pricing hiện tại (USD/1M tokens)
□ Estimate input tokens: system prompt + user input + retrieved context
□ Estimate output tokens: expected response length
□ Cost = (input_tokens * input_price + output_tokens * output_price) / 1M

Ví dụ rough estimate:
- GPT-4o: ~$2.5/1M input, ~$10/1M output
- GPT-4o-mini: ~$0.15/1M input, ~$0.6/1M output
- Claude 3.5 Sonnet: ~$3/1M input, ~$15/1M output
- Claude 3 Haiku: ~$0.25/1M input, ~$1.25/1M output

Red flags trong code:
□ Không có max_tokens limit → output có thể rất dài và đắt
□ System prompt rất dài (>2000 tokens) và không có prompt caching
□ Gọi expensive model (GPT-4o) cho task đơn giản có thể dùng mini
□ Không có caching cho repeated identical requests
□ Loop gọi model nhiều lần khi có thể gộp thành một request

Cost controls:
□ max_tokens được set cho mọi request → có / không
□ Prompt caching implement khi system prompt dài → có / không / N/A
□ Response caching cho repeated requests → có / không
□ Budget alert / circuit breaker khi cost spike → có / không
□ Cost monitoring dashboard → có / không
```

### Bước 6: Latency impact

```
□ Gọi AI model synchronously trong request path? → Latency tăng đáng kể
□ Timeout được set hợp lý? (không dùng default = vô cực)
□ Streaming được dùng khi user cần see response progressively?
□ Parallel model calls khi có thể (thay vì sequential)?
□ Có async/background processing cho non-critical AI tasks?

Latency budget check:
□ Measure baseline: P50, P95, P99 latency của endpoint
□ AI component chiếm bao % total latency?
□ Nếu >50% là do AI → evaluate: async? cache? smaller model?

User experience:
□ Loading indicator khi AI đang process?
□ Skeleton/placeholder trong khi chờ AI response?
□ Timeout message thân thiện khi AI quá chậm?
□ Partial results được hiển thị progressively (streaming)?
```

### Bước 7: Fallback logic

```
□ Có fallback khi model unavailable không?
□ Fallback có được test không hay chỉ có trên paper?
□ Circuit breaker pattern được implement?
□ Timeout → fallback, không phải timeout → crash

Tier của fallback:
□ Tier 1 (degraded AI): gọi model nhỏ hơn / cheaper → implemented / missing
□ Tier 2 (rule-based): logic không dùng AI → implemented / missing
□ Tier 3 (feature off): graceful degradation → implemented / missing

Test scenarios:
□ Model API returns 500 → behavior?
□ Model API timeout → behavior?
□ Rate limit hit → behavior?
□ Low confidence output → behavior?
□ Empty/null model response → behavior?
```

### Bước 8: Privacy — PII sent to model

```
Privacy là critical: gửi PII lên third-party LLM có thể vi phạm GDPR/PDPA.

Checklist:
□ Input data có chứa PII không? (tên, email, phone, CCCD, địa chỉ, sức khỏe, tài chính)
□ Nếu có PII: có được mask/redact trước khi gửi không?
□ Data processing agreement (DPA) với AI provider đã có chưa?
□ User consent cho việc data được gửi đến third-party AI?
□ Dữ liệu có được retain bởi provider không? (OpenAI API: không train theo default, nhưng cần verify)

On-device / local model để tránh PII risk:
□ Nếu data quá nhạy cảm → evaluate self-hosted LLM (Llama, Mistral)
□ On-device inference (Core ML, TFLite) cho mobile apps

Logging:
□ Input và output của model request có bị log không?
□ Nếu có log → PII trong log có được mask không?
□ Log retention policy đã define chưa?
```

### Bước 9: Model versioning

```
□ Model version được pin cụ thể hay dùng "latest"?
  → Xấu: model="gpt-4o" (có thể thay đổi behavior khi provider update)
  → Tốt: model="gpt-4o-2024-11-20" (pinned version)
□ Khi provider deprecate model version → có migration plan không?
□ Model artifacts (ML models) có versioning trong registry không?
□ Có thể rollback về model version cũ nếu new version kém hơn không?
□ Changelog khi upgrade model version: test lại regressions?
```

### Bước 10: Monitoring hooks

```
□ Có logging cho mọi model request và response không?
  → Log: timestamp, model, input_tokens, output_tokens, latency, success/error
□ Cost per request được track không?
□ Error rate của model calls được monitor không?
□ Latency P95 dashboard được setup không?
□ Alerts khi:
  → Error rate > X%
  → Latency P95 > threshold
  → Cost spike bất thường
  → Model output quality drop (nếu có feedback loop)
□ Distributed tracing: request ID được propagate để trace full path?
```

### Bước 11: Output — Review Report

```markdown
# AI Implementation Review: [Feature Name]

**REQ-ID**: REQ-[MODULE]-[NNN]
**AI Type**: [LLM API / ML Endpoint / RAG Pipeline / Embedded Model]
**Provider / Model**: [OpenAI GPT-4o / Anthropic Claude / custom endpoint]
**Reviewer**: ai-engineer

---

## Tổng quan: ✅ APPROVE / ❌ REQUEST CHANGES / ⚠️ APPROVE WITH NOTES

---

## Critical Issues (block merge)
- [ ] [Vấn đề]: [File + line] → [Fix cụ thể]

## Important Issues (fix trong sprint này)
- [ ] [Vấn đề]: [File + line] → [Khuyến nghị]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

---

## AI-Specific Checklist

| Hạng mục | Kết quả | Ghi chú |
|----------|---------|---------|
| Prompt injection prevention | ✅ / ⚠️ / ❌ / N/A | |
| Hallucination handling | ✅ / ⚠️ / ❌ | |
| Bias risks identified | ✅ / ⚠️ / ❌ | |
| Cost per request estimate | ✅ / ⚠️ / ❌ | ~$X per 1000 req |
| Latency impact acceptable | ✅ / ⚠️ / ❌ | P95: Xms |
| Fallback logic (3 tiers) | ✅ / ⚠️ / ❌ | |
| Privacy / PII handling | ✅ / ⚠️ / ❌ | |
| Model version pinned | ✅ / ⚠️ / ❌ | |
| Monitoring hooks | ✅ / ⚠️ / ❌ | |

---

## Cost Analysis
- Estimated cost/request: ~$[X]
- Estimated monthly cost tại [N] requests/day: ~$[Y]
- Optimization opportunities: [list]

## Security Notes
[Prompt injection, PII risks cụ thể]

## Bias Assessment
[Bias risks được identify, mitigation plan]
```

---

## Checklist trước khi submit review

```
□ Đã check tất cả 9 hạng mục AI-specific
□ Critical issues có file path và line number cụ thể
□ Cost estimate đã tính
□ Prompt injection risk đã assess (LLM)
□ Privacy/PII risk đã assess
□ Fallback behavior đã verify (không chỉ code exists mà còn tested)
□ Distinction rõ ràng: critical (block merge) vs. important vs. suggestion
```
