# MLOps & Production Patterns

> **Domain**: Engineering / AI-ML
> **Last Updated**: 2026-03-22

---

## 1. Các Pattern Tích hợp Production

| Pattern | Mô tả | Latency | Use case |
|---------|--------|---------|----------|
| **Real-time** | API đồng bộ cho kết quả tức thì | < 100ms | User-facing API |
| **Batch** | Xử lý bất đồng bộ cho tập dữ liệu lớn | > minutes | Offline scoring |
| **Streaming** | Xử lý event-driven cho dữ liệu liên tục | < 1s | Realtime analytics |
| **Edge** | Inference trên thiết bị | Local | Privacy + latency |
| **Hybrid** | Kết hợp cloud và edge | Varies | Flexible |

---

## 2. Model Drift Detection & Automated Retraining

```yaml
drift_monitoring:
  data_drift:
    method: "PSI"           # Population Stability Index
    threshold: 0.2          # PSI > 0.2 = significant drift
    check_interval: "daily"
  concept_drift:
    method: "accuracy_degradation"
    threshold: 0.05         # 5% accuracy drop
    window: "7d"
  auto_retrain:
    trigger: "data_drift OR concept_drift"
    validation_gate: "new_model_accuracy > current_model_accuracy"
    rollback: "automatic if validation fails"
    notification: "slack:#ml-alerts"
```

---

## 3. Cost Per Prediction Tracking

| Tier | Latency | Cost Target | Use Case |
|------|---------|-------------|----------|
| Real-time | < 100ms | < $0.001/prediction | User-facing API |
| Near-real-time | < 1s | < $0.01/prediction | Internal processing |
| Batch | < 1h | < $0.0001/prediction | Offline scoring |

Tối ưu cost: model quantization (INT8/FP16), distillation, caching frequent predictions, batch inference.

---

## 4. A/B Testing & Statistical Rigor

- **Statistical significance**: p-value < 0.05 VÀ đủ sample size (power analysis trước khi chạy)
- **Minimum Detectable Effect (MDE)**: Xác định trước — không chạy test "đến khi thấy kết quả"
- **Sequential testing**: Dùng sequential analysis nếu cần early stopping, không peek at results
- **Guardrail metrics**: Ngoài primary metric, theo dõi guardrails (latency, error rate, revenue)

```python
# Power analysis trước A/B test
from scipy.stats import norm
import numpy as np

def required_sample_size(baseline_rate: float, mde: float, alpha: float = 0.05, power: float = 0.8) -> int:
    """Tính sample size cần thiết cho A/B test."""
    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)
    p1, p2 = baseline_rate, baseline_rate + mde
    pooled_var = p1 * (1 - p1) + p2 * (1 - p2)
    n = ((z_alpha + z_beta) ** 2 * pooled_var) / (mde ** 2)
    return int(np.ceil(n))
```
