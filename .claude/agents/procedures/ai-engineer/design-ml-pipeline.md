# Playbook: Design ML/AI Pipeline

> **Type**: Agent Skill Playbook
> **Agent**: ai-engineer
> **Triggered by**: Phase 3 (/wf-design) khi dự án có AI/ML requirements
> **Output**: `.mc-data/docs/phase3-architecture/ml-pipeline-design.md`

---

## Khi nào dùng playbook này

- Trong `/wf-design` khi requirements có AI, ML, recommendation, prediction, classification, NLP, LLM, computer vision
- Khi cần thiết kế pipeline từ data ingestion đến model serving
- Khi cần chọn approach: ML truyền thống vs. LLM vs. hybrid

---

## Procedure

### Bước 1: Đọc requirements và feature specs

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (feature specs), PHASE1 (business requirements)

READ:
□ .mc-data/docs/_meta/req-registry.json → xác định AI-related REQ-IDs
□ .mc-data/docs/phase2-features/ → feature specs liên quan đến AI

Cần xác định:
□ Danh sách REQ-IDs cần AI solution
□ Business problem cụ thể: predict / classify / recommend / generate / detect / extract
□ Data hiện có: structured, unstructured, images, text, time-series
□ Performance constraints: latency, throughput, accuracy threshold
□ Scale: số users, số requests/giây, volume dữ liệu
□ Privacy constraints: PII trong data, on-device vs. cloud processing
□ Budget constraints: inference cost/request acceptable
```

### Bước 2: Problem framing

```
Phân loại bài toán để chọn đúng approach:

SUPERVISED LEARNING (có labeled data):
□ Binary classification: spam detection, fraud detection, churn prediction
□ Multi-class classification: category assignment, intent detection
□ Regression: price prediction, demand forecasting, rating prediction
□ Multi-label: content tagging, recommendation relevance

UNSUPERVISED LEARNING (không có labels):
□ Clustering: customer segmentation, anomaly detection
□ Dimensionality reduction: feature extraction, visualization
□ Association rules: market basket analysis, recommendation

REINFORCEMENT LEARNING:
□ Sequential decisions: recommendation ranking, A/B test optimization
□ Resource allocation, pricing optimization
□ CHÚ Ý: RL phức tạp và dài để converge — chỉ dùng khi supervised không được

GENERATIVE AI / LLM:
□ Text generation: content writing, summarization, translation
□ Q&A / Chatbot: RAG-based knowledge retrieval
□ Code generation, data extraction, classification with explanations
□ Document processing: OCR + structure extraction
□ CHÚ Ý: LLM = higher cost + latency — luôn evaluate simple ML trước

Decision framework:
1. Bài toán có thể giải bằng rule-based không? → dùng rules trước
2. Có labeled data không? → supervised trước
3. LLM thực sự cần không hay overkill? → đánh giá cost/benefit

Ghi lý do chọn approach: "Chọn [X] thay vì [Y] vì [lý do cụ thể]"
```

### Bước 3: Data pipeline design

```
3a. Data sources:
□ Liệt kê nguồn dữ liệu: production DB, event streams, third-party APIs, user uploads
□ Volume: bao nhiêu records, bao nhiêu GB, tốc độ tăng trưởng
□ Freshness requirement: real-time / near-real-time / daily batch

3b. Data ingestion:
□ Batch ingestion: cron jobs, Airflow DAGs, scheduled exports
□ Streaming ingestion: Kafka, Kinesis, Pub/Sub
□ Change Data Capture (CDC): Debezium cho production DB

3c. Data validation:
□ Schema validation: Great Expectations, Pandera
□ Data quality checks: null rates, distribution drift, outliers
□ Alerting khi data quality drop dưới threshold

3d. Feature engineering:
□ Numerical: normalization, log transform, binning
□ Categorical: one-hot, target encoding, embedding
□ Text: TF-IDF, sentence embeddings (sentence-transformers)
□ Time-series: lag features, rolling windows, seasonality decomposition
□ Feature store: Feast / Hopsworks — nếu features được share across models

3e. Train/val/test split:
□ Tránh data leakage: split theo time (time-series), theo user (user-based)
□ Class imbalance: SMOTE, class weights, stratified sampling
□ Offline vs. online feature consistency (training-serving skew)
```

### Bước 4: Feature engineering strategy

```
□ Xác định features nào raw từ data, features nào cần compute
□ Features cần real-time update vs. batch recompute
□ Feature dependencies: feature A cần feature B trước
□ Feature importance baseline: domain knowledge trước khi training

Text features (nếu có NLP):
□ Embeddings model: sentence-transformers, OpenAI embeddings, Cohere
□ Vector dimension: 384 / 768 / 1536 → tradeoff speed vs. quality
□ Vector database: Pinecone, Weaviate, Qdrant, pgvector (PostgreSQL)

Image features (nếu có CV):
□ Pretrained backbone: ResNet, EfficientNet, ViT → fine-tune hoặc feature extraction
□ Data augmentation: rotation, flip, color jitter → giảm overfitting

Time-series features:
□ Lookback window phù hợp với business cycle
□ Seasonal decomposition nếu có seasonality rõ
```

### Bước 5: Model selection rationale

```
Nguyên tắc: đơn giản → phức tạp. Không dùng deep learning nếu XGBoost đủ tốt.

Bảng tham khảo:

| Bài toán | Model khuyến nghị | Fallback |
|----------|------------------|---------|
| Tabular classification | XGBoost / LightGBM | Logistic Regression |
| Tabular regression | XGBoost / LightGBM | Linear Regression |
| Text classification | Fine-tuned BERT | TF-IDF + XGBoost |
| Text generation / Q&A | LLM với RAG | Fine-tuned smaller LLM |
| Image classification | Fine-tuned EfficientNet | ResNet |
| Recommendation | Two-tower model | Collaborative filtering |
| Anomaly detection | Isolation Forest | Statistical (z-score) |
| Time-series forecast | Temporal Fusion Transformer | Prophet / ARIMA |

LLM selection (nếu dùng LLM):
□ GPT-4o / Claude 3.5 Sonnet → complex reasoning, higher cost
□ GPT-4o-mini / Claude Haiku → lower cost, faster, đủ cho most tasks
□ Self-hosted (Llama, Mistral) → privacy requirement, cost control
□ Fine-tuning vs. prompt engineering: thử prompt engineering trước

Ghi rõ trong document: "Chọn [model] vì [lý do]. Trade-off: [cost/latency/accuracy]."
```

### Bước 6: Training infrastructure

```
Compute requirements:
□ CPU training đủ không? (XGBoost, linear models, small datasets)
□ GPU cần không? (deep learning, large language models, >1M samples)
□ Distributed training cần không? (dataset > 100GB)

Infrastructure options:
□ On-demand: Google Colab, Kaggle Kernels (prototype)
□ Cloud: AWS SageMaker, GCP Vertex AI, Azure ML
□ Self-hosted: On-premise GPU cluster nếu có

Experiment tracking (bắt buộc):
□ MLflow: open source, self-hosted
□ Weights & Biases: hosted, tốt cho teams
□ Neptune: alternative W&B

Tracking cần log:
□ Hyperparameters
□ Training metrics per epoch
□ Validation metrics
□ Model artifacts (checkpoint, serialized model)
□ Dataset version (hash/tag)
□ Code version (git commit)
```

### Bước 7: Evaluation metrics selection

```
Chọn metrics phù hợp với business goal, không chỉ optimize accuracy:

Classification:
□ Balanced accuracy nếu class imbalance
□ Precision-Recall curve khi false positive vs. false negative cost khác nhau
□ F1-score khi cần balance precision và recall
□ AUC-ROC cho ranking tasks
□ Business metric: conversion rate uplift, revenue impact

Regression:
□ RMSE / MAE tùy tolerance với outliers
□ MAPE khi cần percentage error
□ Pinball loss cho quantile regression

Recommendation:
□ NDCG@K, Precision@K, Recall@K
□ Coverage, diversity, novelty

NLP / Text Generation:
□ BLEU, ROUGE cho generation
□ Human evaluation (A/B test hoặc annotation)
□ Task-specific: EM (exact match) cho Q&A

LLM Evaluation:
□ LLM-as-judge (dùng strong model để evaluate output)
□ RAGAS cho RAG pipeline (faithfulness, answer relevancy, context recall)
□ Định kỳ human spot-check

Bias và fairness metrics:
□ Demographic parity
□ Equal opportunity
□ Calibration across groups
```

### Bước 8: Model registry

```
□ Dùng MLflow Model Registry hoặc Vertex AI Model Registry
□ Model versioning: major (breaking API change), minor (retrain), patch (bug fix)
□ Stage transitions: Staging → Production → Archived (không xóa model cũ)
□ Model card bắt buộc cho mọi model: intended use, training data, limitations, bias test results
□ Approval workflow: ai approve model lên Production?
□ Rollback procedure: nếu model mới kém hơn, switch về version cũ trong <5 phút
```

### Bước 9: Serving architecture

```
Chọn serving pattern dựa trên requirements:

BATCH SERVING (latency không quan trọng, cost thấp):
□ Precompute predictions và lưu vào database
□ Dùng cho: email recommendations, weekly reports, batch scoring
□ Tools: Spark, Beam, dbt

REAL-TIME SERVING (latency <200ms):
□ REST API với model server: TorchServe, TF Serving, FastAPI
□ ONNX Runtime để speed up inference
□ Caching layer: Redis/Memcached cho repeated inputs
□ Auto-scaling: Kubernetes HPA dựa trên inference queue depth

STREAMING SERVING (event-driven):
□ Kafka Streams / Flink cho real-time feature computation
□ Trigger inference khi event xảy ra

EDGE / ON-DEVICE:
□ Model quantization: INT8, FP16 để giảm size
□ Core ML (iOS) / TFLite (Android) / ONNX Mobile
□ Dùng khi: offline requirement, privacy, latency <50ms

LLM Serving:
□ OpenAI API / Anthropic API cho managed service
□ vLLM / TGI (Text Generation Inference) cho self-hosted
□ Prompt caching để giảm cost (Anthropic Prompt Caching, OpenAI cached tokens)
□ Structured output (JSON mode) để parse dễ hơn

Latency budget (ví dụ):
□ Feature fetch: <10ms
□ Model inference: <50ms
□ Post-processing: <5ms
□ Total API response: <200ms
```

### Bước 10: Monitoring và retraining triggers

```
Production monitoring (bắt buộc):

Data drift detection:
□ Input feature distribution thay đổi so với training data
□ Tools: Evidently AI, WhyLogs, Great Expectations
□ Alert khi drift score > threshold

Model performance monitoring:
□ Prediction distribution shift (ví dụ: average confidence drop)
□ Business metric degradation (conversion rate, revenue per recommendation)
□ Ground truth labels (nếu có delayed feedback)
□ A/B test comparison với previous model version

Infrastructure monitoring:
□ Inference latency P50 / P95 / P99
□ Error rate (model server failures)
□ GPU/CPU utilization
□ Queue depth cho async inference

Retraining triggers (chọn phù hợp):
□ Schedule-based: weekly / monthly retrain (simple, predictable)
□ Performance-based: retrain khi metric xuống dưới threshold
□ Data-based: retrain khi training dataset size tăng X%
□ Drift-based: retrain khi data drift detected

Automated retraining pipeline:
□ Data validation → feature engineering → training → evaluation → staging deploy → A/B test → production
□ Rollback automatic nếu new model kém hơn baseline
```

### Bước 11: Ghi output

```
WRITE: .mc-data/docs/phase3-architecture/ml-pipeline-design.md

Cấu trúc output:

# ML/AI Pipeline Design

## 1. Problem Framing
- Bài toán: [supervised/unsupervised/LLM]
- Lý do chọn approach: [WHY]

## 2. Data Pipeline
- Sources: [list]
- Ingestion: [batch/streaming]
- Feature engineering: [key features]

## 3. Model Selection
- Model: [tên + version]
- Alternatives considered: [và lý do không chọn]
- Trade-offs: [cost, latency, accuracy]

## 4. Training Infrastructure
- Compute: [CPU/GPU, cloud/on-premise]
- Experiment tracking: [MLflow/W&B]

## 5. Evaluation Metrics
- Primary: [metric + threshold]
- Secondary: [metrics]
- Bias testing: [groups + fairness metrics]

## 6. Serving Architecture
- Pattern: [batch/real-time/streaming/edge]
- Latency budget: [ms breakdown]
- Scaling strategy: [horizontal/vertical]

## 7. Monitoring Plan
- Drift detection: [tool + frequency]
- Retraining trigger: [condition]
- Rollback procedure: [steps]

## 8. REQ-ID Mapping
[REQ-ID → ML component mapping]

## 9. Open Questions
[Câu hỏi cần confirm với stakeholders hoặc data team]
```

---

## Checklist trước khi submit

```
□ Mọi AI REQ-IDs đã được map vào pipeline components
□ Problem framing đã giải thích WHY chọn approach này
□ LLM cost estimate đã tính (nếu dùng LLM)
□ Latency budget đã define rõ
□ Bias testing plan đã có
□ Monitoring + retraining strategy đã define
□ Model card placeholder đã mention
□ Privacy: PII trong training data đã được address
```
