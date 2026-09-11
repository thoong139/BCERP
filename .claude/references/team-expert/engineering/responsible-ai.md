# AI Ethics & Responsible AI

> **Domain**: Engineering / AI-ML
> **Last Updated**: 2026-03-22

---

## 1. Năng lực AI Chuyên biệt (Non-LLM)

- **Computer Vision**: Phát hiện đối tượng, phân loại ảnh, OCR, nhận diện khuôn mặt
- **Recommendation Systems**: Collaborative filtering, content-based recommendations
- **Time Series**: Dự báo, phát hiện anomaly, phân tích xu hướng
- **Reinforcement Learning**: Tối ưu hóa quyết định, multi-armed bandits
- **MLOps**: Versioning mô hình, A/B testing, monitoring, automated retraining

---

## 2. AI Ethics & Bias Testing

Các metric cần kiểm tra trước khi deploy production:

| Metric | Đo gì | Ngưỡng từ chối |
|--------|--------|----------------|
| **Demographic Parity** | P(ŷ=1\|A=a) ≈ P(ŷ=1\|A=b) cho mọi nhóm | Delta > 10% |
| **Equalized Odds** | TPR và FPR tương đương giữa các nhóm | Delta > 10% |
| **Calibration** | P(Y=1\|ŷ=p) ≈ p cho mọi nhóm | Delta > 10% |

Nếu bất kỳ metric nào vượt ngưỡng, model cần được remediate trước khi deploy.

---

## 3. Các Kỹ thuật Bảo vệ

- Differential privacy và federated learning để bảo vệ quyền riêng tư
- Adversarial robustness testing và cơ chế phòng thủ
- Explainable AI (XAI) để diễn giải quyết định của mô hình
- Fairness-aware machine learning và chiến lược giảm thiểu bias
