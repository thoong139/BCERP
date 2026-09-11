# Playbook: Implement Model Integration

> **Type**: Agent Skill Playbook
> **Agent**: ai-engineer
> **Triggered by**: /wf-implement-feature khi integrate AI/ML model vào application
> **Output**: Model integration implementation với error handling và fallback

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi task liên quan đến gọi AI/ML model từ application code
- Khi integrate LLM API (OpenAI, Anthropic, Gemini) vào feature
- Khi integrate ML model endpoint (REST API, gRPC, SDK) vào backend service
- Khi implement RAG pipeline, embedding search, hay inference pipeline

---

## Procedure

### Bước 1: Đọc model spec và requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (ML pipeline design), PHASE2 (feature spec)

READ:
□ .mc-data/docs/phase3-architecture/ml-pipeline-design.md → model đã được chọn
□ .mc-data/docs/phase2-features/ → acceptance criteria của feature AI này
□ .mc-data/docs/_meta/req-registry.json → REQ-IDs cần implement

Xác định:
□ REQ-ID cần implement
□ Loại integration: LLM API / ML REST endpoint / embedded model / RAG pipeline
□ Input format: text / structured data / image / audio
□ Output format: text / JSON / label + confidence / embeddings
□ Latency SLA: người dùng chờ bao lâu là acceptable?
□ Cost SLA: cost per request acceptable là bao nhiêu?
```

### Bước 2: API / SDK integration

```
LLM APIs:

OpenAI (GPT-4o, GPT-4o-mini):
□ Dùng official SDK: openai Python package / openai npm package
□ Authentication: OPENAI_API_KEY từ environment variable (không hardcode)
□ Model selection: gpt-4o cho complex reasoning, gpt-4o-mini cho simpler tasks
□ Request parameters: temperature, max_tokens, response_format (JSON mode)
□ Streaming: dùng stream=True khi response dài và UX cần progressive display

Anthropic (Claude):
□ Dùng official SDK: anthropic Python / @anthropic-ai/sdk npm
□ Authentication: ANTHROPIC_API_KEY từ environment variable
□ Model: claude-3-5-sonnet cho quality, claude-3-haiku cho speed/cost
□ System prompt tách riêng khỏi user message
□ Prompt caching: cache system prompt nếu dài và tái sử dụng (giảm 90% cost)

ML REST Endpoints (custom model hoặc managed service):
□ Base URL từ environment config (không hardcode)
□ Authentication: Bearer token, API key header, hoặc AWS SigV4 (SageMaker)
□ Request/response schema validation: dùng Pydantic / Zod
□ SDK wrapper class thay vì gọi raw HTTP trong business logic

Google Vertex AI / AWS SageMaker:
□ Dùng official client libraries, không gọi REST trực tiếp
□ Service account / IAM role — không dùng personal credentials
□ Region selection: gần user để giảm latency
```

### Bước 3: Input preprocessing

```
Nguyên tắc: validate và normalize input TRƯỚC KHI gửi đến model.

Validation:
□ Input length check: LLM có token limit (context window)
  → Truncate hoặc chunk input nếu quá dài
  → Cảnh báo user nếu truncation xảy ra
□ Input type validation: string / number / image format
□ Encoding validation: UTF-8, không có null bytes
□ Empty input check: handle gracefully, không gọi model

Text preprocessing:
□ Trim whitespace, normalize Unicode
□ PII detection (nếu yêu cầu): mask email, phone, SSN trước khi gửi
□ Language detection nếu model chỉ hỗ trợ một ngôn ngữ

Image preprocessing:
□ Resize về kích thước model yêu cầu
□ Normalize pixel values (0-1 hoặc -1 to 1 theo model spec)
□ Format conversion: JPEG/PNG/WebP → model input format

Structured data:
□ Feature scaling nhất quán với training time (dùng cùng scaler artifact)
□ Categorical encoding nhất quán với training
□ Missing value handling nhất quán với training pipeline
```

### Bước 4: Output postprocessing

```
Parse và validate model output trước khi trả về business logic:

LLM output parsing:
□ JSON mode: request JSON output và parse với error handling
□ Không parse free-form text bằng regex fragile — dùng structured output
□ Validate parsed JSON schema: Pydantic / Zod
□ Extract relevant fields, bỏ qua metadata không cần

ML model output:
□ Confidence score threshold: chỉ sử dụng prediction khi confidence ≥ threshold
□ Label mapping: model output integer → human-readable label
□ Probability calibration nếu model chưa calibrated

Postprocessing logic:
□ Business rules apply sau khi có prediction
□ Ranking/sorting nếu model trả về multiple results
□ Deduplication nếu model trả về duplicates
□ Format transformation: model output → API response format
```

### Bước 5: Error handling (model unavailable, low confidence)

```
Phân loại lỗi và handling tương ứng:

Network / Infrastructure errors:
□ ConnectionError, TimeoutError → retry với exponential backoff
□ RateLimitError (429) → retry sau backoff delay, log warning
□ ServiceUnavailableError (503) → retry, sau đó fallback
□ AuthenticationError (401) → không retry, log error, alert team

Model-specific errors:
□ Context length exceeded → truncate input và retry
□ Content policy violation → return error message thân thiện với user
□ Invalid request format → log để debug, return error

Business logic errors:
□ Low confidence score (< threshold) → route to human review hoặc return "không chắc chắn"
□ Empty / null output → fallback strategy
□ Output failed validation → retry với modified prompt (LLM) hoặc flag for review

Retry strategy:
□ Max 3 retries với exponential backoff: 1s, 2s, 4s
□ Idempotency: retry chỉ safe nếu side effects không duplicate
□ Jitter: thêm random delay để tránh thundering herd
```

### Bước 6: Fallback strategy

```
Fallback là bắt buộc — không để user thấy blank screen hoặc crash khi AI unavailable.

Tier 1 — Degraded AI (same feature, lower quality):
□ Gọi model nhỏ hơn / rẻ hơn: GPT-4o → GPT-4o-mini → GPT-3.5
□ Gọi cached prediction nếu input tương tự đã có trước
□ Giảm complexity của request

Tier 2 — Rule-based fallback (same feature, no AI):
□ Keyword matching thay vì NLP classification
□ Static content thay vì generated content
□ Popularity-based recommendation thay vì ML recommendation

Tier 3 — Feature disabled (graceful degradation):
□ Hiện message "Tính năng đang tạm thời không khả dụng"
□ Ẩn AI-powered elements, hiện basic interface
□ Không crash toàn bộ page vì một AI feature fail

Circuit breaker pattern:
□ Sau N failures trong T giây → open circuit, stop gọi model
□ Sau cooldown period → half-open, thử một request
□ Nếu thành công → close circuit, normal flow
```

### Bước 7: Latency budget

```
Đo và optimize latency:

Breakdown latency:
□ Input preprocessing time
□ Network round-trip to model API
□ Model inference time (server-side, bạn không control được)
□ Output postprocessing time
□ Total: phải trong SLA

Optimization techniques:
□ Streaming response: hiển thị text ngay khi tokens được generate (LLM)
□ Parallel requests: nếu cần gọi nhiều model cùng lúc → dùng asyncio / Promise.all
□ Request batching: gom nhiều requests thành một batch (ML models)
□ Caching: cache kết quả cho identical inputs (xem Bước 9)
□ Async processing: nếu user không cần kết quả ngay → background job + webhook/polling

Timeout configuration:
□ Set timeout hợp lý: LLM simple task 10s, complex task 30s, batch 300s
□ Không dùng default timeout (thường vô cực)
□ Inform user khi đang processing (skeleton loader, progress indicator)
```

### Bước 8: Prompt engineering (LLM integration)

```
Chỉ áp dụng khi dùng LLM. Prompt là code — version control và test nó.

System prompt design:
□ Role assignment: "Bạn là..." — định hướng behavior của model
□ Task specification: rõ ràng và cụ thể
□ Output format specification: "Trả về JSON với fields: ..."
□ Constraints: "Không được...", "Chỉ sử dụng thông tin từ..."
□ Examples (few-shot): 2-3 examples cải thiện consistency đáng kể

User prompt design:
□ Tách phần static (system) và dynamic (user input)
□ Không để user input inject vào system prompt — prompt injection risk
□ Escape hoặc sanitize user content trước khi đưa vào prompt
□ Clearly delimit user content: dùng XML tags hoặc triple backticks

Prompt versioning:
□ Lưu prompts trong code (không hardcode inline trong business logic)
□ PROMPT_VERSION constant để track
□ A/B test prompts khi thay đổi để validate không regression

Tiếng Việt:
□ Test prompt bằng tiếng Việt nếu user input là tiếng Việt
□ Một số models tốt hơn với English system prompt + Vietnamese user prompt
□ Test edge cases: tiếng Việt có dấu, tiếng lóng, typo phổ biến
```

### Bước 9: Response caching strategy

```
Cache phù hợp giúp giảm cost và latency đáng kể.

Semantic caching (LLM):
□ Embed query → tìm cached response với cosine similarity > 0.95
□ Tools: GPTCache, semantic-cache library
□ Khi nào dùng: Q&A, product search, FAQ — câu hỏi thường lặp lại

Exact caching (deterministic inputs):
□ Cache key: hash(model + input + temperature=0)
□ Chỉ cache khi temperature=0 (deterministic output)
□ TTL: phụ thuộc vào freshness requirement

Prompt caching (Anthropic / OpenAI):
□ Anthropic: đánh dấu phần system prompt với cache_control
□ OpenAI: automatic caching cho prompts >1024 tokens
□ Giảm 90% cost và 80% latency cho cached portion

KHÔNG cache:
□ Personalized content có user-specific data nhạy cảm
□ Content có thời gian ngắn (tin tức, giá cả real-time)
□ Kết quả AI với temperature > 0 (non-deterministic)
```

### Bước 10: REQ-ID reference và documentation

```
Mọi file integration phải có:

# REQ-ID: REQ-[MODULE]-[NNN]
# Model integration: [mô tả ngắn]
# Model used: [provider/model name]
# WHY: [Lý do chọn approach này]
# Cost estimate: ~$[X] per 1000 requests
# Latency SLA: <[X]ms P95

Ghi document inline:
□ Contract của model: input schema, output schema
□ Known limitations: hallucination risk, language support
□ Fallback behavior khi model unavailable
□ Rate limits và handling
□ PII policy: có gửi PII đến model không? nếu có, tại sao và consent đâu?
```

---

## Output

```
Ghi code vào path do skill cung cấp.

Cấu trúc module:
src/services/ai/
├── [feature]ModelClient.ts          ← wrapper around model API
├── [feature]InputPreprocessor.ts    ← validate + transform input
├── [feature]OutputParser.ts         ← parse + validate output
├── [feature]FallbackHandler.ts      ← fallback logic
├── prompts/
│   ├── [feature]-system.txt         ← system prompt (versioned)
│   └── [feature]-user.ts            ← user prompt builder
└── __tests__/
    └── [feature]ModelClient.test.ts ← unit tests với mocked API
```

---

## Checklist trước khi submit

```
□ REQ-ID reference ở đầu file
□ API key / credentials từ environment variable (không hardcode)
□ Input validation: length, type, PII masking (nếu cần)
□ Output validation: schema, confidence threshold
□ Error handling: network, rate limit, model error
□ Retry với exponential backoff (max 3 lần)
□ Fallback: tier 1 (degraded AI) → tier 2 (rules) → tier 3 (feature off)
□ Timeout được set
□ Caching cho repeated inputs (nếu applicable)
□ Prompt injection prevention (nếu LLM)
□ Unit tests với mocked model API
□ Cost estimate documented
```
