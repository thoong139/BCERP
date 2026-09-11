# Engineering - Air-Gapped SLM Inference

> **Domain**: Engineering / Data Remediation
> **Last Updated**: 2026-03-22

---

## Air-Gapped SLM Inference

Xử lý dữ liệu nhạy cảm bằng Small Language Model chạy hoàn toàn local, không kết nối mạng:

```yaml
air_gapped_slm:
  model: "phi-3-mini"      # Hoặc Mistral-7B, Llama-3-8B
  runtime: "ollama"         # Local inference only
  network: "disabled"       # Không có outbound connections
  tasks:
    - pii_detection
    - entity_extraction
    - classification
    - summarization
  constraints:
    max_tokens: 512
    temperature: 0.0         # Deterministic output
    batch_size: 100
  security:
    input_sanitization: true
    output_validation: true
    no_data_persistence: true  # Input/output không được lưu lại
```

---

## Model Selection

| Model | Size | Phù hợp khi | RAM yêu cầu |
|-------|------|-------------|-------------|
| `phi-3-mini` | 3.8B | Classification, PII detection, short extraction | ~4GB |
| `Mistral-7B` | 7B | Entity extraction, summarization, NER | ~8GB |
| `Llama-3-8B` | 8B | Complex reasoning, multi-label classification | ~10GB |

Tiêu chí chọn model:
- Dataset nhỏ, latency quan trọng → `phi-3-mini`
- Cần accuracy cao hơn, có đủ RAM → `Mistral-7B` hoặc `Llama-3-8B`
- Sensitive data yêu cầu air-gapped → bất kỳ model nào trong danh sách trên (tránh API calls)

---

## Ollama Setup (Local Runtime)

```bash
# Cài đặt Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull model về local
ollama pull phi3:mini

# Tắt outbound network sau khi pull (firewall rule hoặc network namespace)
# Chạy inference hoàn toàn offline từ đây
```

```python
import ollama

def run_air_gapped_inference(prompt: str, model: str = "phi3:mini") -> str:
    """
    Chạy SLM inference local.
    Ollama server phải đang chạy trên localhost.
    Không có outbound network connection.
    """
    response = ollama.chat(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        options={
            "temperature": 0.0,    # Deterministic
            "num_predict": 512,    # max_tokens
        }
    )
    return response["message"]["content"]
```

---

## Network Isolation

### Linux (network namespace)

```bash
# Tạo isolated network namespace cho inference process
ip netns add air-gapped-ns

# Chạy inference trong namespace (không có route ra ngoài)
ip netns exec air-gapped-ns python remediation_pipeline.py
```

### Docker (no network)

```bash
docker run --network none \
  -v /data/input:/input:ro \
  -v /data/output:/output \
  ai-remediation:latest python pipeline.py
```

### Kiểm tra isolation

```bash
# Trong air-gapped environment — lệnh này phải fail
curl --max-time 5 https://api.openai.com/v1/models
# Expected: curl: (6) Could not resolve host
```

---

## Input Sanitization

```python
def sanitize_input_for_slm(text: str, max_length: int = 2048) -> str:
    """
    Làm sạch input trước khi đưa vào SLM.
    Tránh prompt injection và truncation issues.
    """
    # Truncate để tránh context overflow
    text = text[:max_length]

    # Loại bỏ control characters
    text = "".join(ch for ch in text if ord(ch) >= 32 or ch in "\n\t")

    # Escape delimiter characters có thể gây prompt injection
    text = text.replace("```", "'''")

    return text.strip()
```

---

## Output Validation

```python
def validate_slm_output(output: str, expected_format: str) -> bool:
    """
    Kiểm tra output của SLM trước khi dùng.
    SLM đôi khi sinh ra format không mong muốn.
    """
    if expected_format == "json":
        try:
            import json
            json.loads(output)
            return True
        except json.JSONDecodeError:
            return False

    if expected_format == "label":
        valid_labels = {"PII_FOUND", "NO_PII", "UNCERTAIN"}
        return output.strip().upper() in valid_labels

    return len(output.strip()) > 0
```

---

## Constraints

| Tham số | Giá trị | Lý do |
|---------|---------|-------|
| `temperature` | `0.0` | Deterministic output — reproducible results |
| `max_tokens` | `512` | Giới hạn response size, tránh hallucination dài |
| `batch_size` | `100` | Cân bằng throughput và memory |
| `no_data_persistence` | `true` | Input/output của SLM không lưu lại |
