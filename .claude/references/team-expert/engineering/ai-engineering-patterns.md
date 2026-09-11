# AI/ML Engineering Patterns

> **Domain:** AI/ML Engineering
> **Last Updated:** 2026-03-22
> **Sources:** Industry best practices, MLOps community standards

---

## ML Frameworks — Selection Matrix

| Framework | Strengths | Best For | Ecosystem |
|-----------|-----------|----------|-----------|
| PyTorch | Dynamic graphs, research-friendly, debugging | Research → production, NLP, CV | TorchServe, ONNX, HuggingFace |
| TensorFlow | Static graphs, production-ready, TPU support | Large-scale serving, mobile (TFLite) | TF Serving, TF.js, TFX |
| HuggingFace Transformers | Pre-trained models, easy fine-tuning | NLP, LLM integration, transfer learning | Datasets, Tokenizers, Accelerate |
| JAX | Functional, auto-differentiation, XLA | High-performance research, TPU | Flax, Optax, Haiku |
| scikit-learn | Simple API, classical ML | Tabular data, prototyping, baselines | Pipeline, GridSearchCV |

---

## Code Templates

### Model Training Pipeline

```
Data Ingestion → Validation → Preprocessing → Feature Engineering →
Training → Evaluation → Model Registry → Serving
```

| Stage | Key Artifact | Validation |
|-------|-------------|------------|
| Data Ingestion | Raw dataset | Schema validation, row counts |
| Preprocessing | Transformed dataset | Distribution checks, null rates |
| Feature Engineering | Feature store entries | Feature importance, correlation |
| Training | Model checkpoint | Loss curves, convergence |
| Evaluation | Metrics report | Threshold checks vs baseline |
| Registry | Versioned model | Metadata, lineage, approval |
| Serving | Endpoint | Latency p99, throughput |

### Inference Serving Patterns

| Pattern | Latency | Throughput | Use Case |
|---------|---------|------------|----------|
| Synchronous REST | Low (p99 <100ms) | Medium | Real-time predictions |
| Batch inference | High (minutes) | Very high | Offline scoring |
| Streaming | Medium | High | Event-driven predictions |
| Edge inference | Very low | Low | IoT, mobile |
| Ensemble | Medium-high | Medium | Multi-model voting |

---

## Bias Testing

### Demographic Parity Metrics

| Metric | Formula | Threshold | When to Use |
|--------|---------|-----------|-------------|
| Demographic Parity | P(ŷ=1\|A=0) ≈ P(ŷ=1\|A=1) | Ratio ≥ 0.8 | Equal selection rates |
| Equalized Odds | TPR and FPR equal across groups | Diff ≤ 0.1 | Equal error rates |
| Calibration | P(Y=1\|ŷ=p, A=a) ≈ p | Deviation ≤ 0.05 | Probability accuracy |
| Individual Fairness | Similar inputs → similar outputs | Distance-based | Case-by-case fairness |

### Testing Protocol

1. Define protected attributes (gender, age, ethnicity, location)
2. Measure baseline metrics per demographic group
3. Apply bias mitigation (pre/in/post-processing)
4. Re-measure and document delta
5. Generate model card with fairness section

---

## A/B Testing for ML Models

### Experiment Design

| Component | Specification |
|-----------|--------------|
| Control | Current production model |
| Treatment | Candidate model |
| Randomization unit | User ID (consistent hashing) |
| Sample size | Power analysis: 80% power, α=0.05 |
| Duration | Minimum 2 business cycles |
| Primary metric | Business KPI (conversion, revenue) |
| Guardrail metrics | Latency p99, error rate, engagement |

### Traffic Allocation

| Phase | Traffic Split | Duration | Gate |
|-------|--------------|----------|------|
| Shadow | 0% live (shadow scoring) | 1 week | Latency ≤ 1.2x baseline |
| Canary | 1-5% | 2-3 days | Error rate ≤ baseline |
| Ramp | 5% → 25% → 50% | 1-2 weeks | Primary metric ≥ baseline |
| Full rollout | 100% | — | Statistical significance |

---

## Drift Detection

### Types of Drift

| Type | What Changes | Detection Method | Alert Threshold |
|------|-------------|-----------------|-----------------|
| Data drift | Input distribution | KS test, PSI, KL divergence | PSI > 0.2 |
| Concept drift | P(Y\|X) relationship | Performance monitoring | Accuracy drop > 5% |
| Feature drift | Individual feature stats | Z-score monitoring | Z > 3 |
| Label drift | Target distribution | Chi-square test | p < 0.01 |

### Monitoring Cadence

| Check | Frequency | Action on Alert |
|-------|-----------|-----------------|
| Input schema validation | Every request | Block + alert |
| Feature distribution | Hourly aggregate | Warning → investigate |
| Model performance | Daily | Retrain if sustained |
| Full drift report | Weekly | Review in model standup |

---

## RAG (Retrieval-Augmented Generation) Patterns

### Architecture Components

| Component | Options | Key Metric |
|-----------|---------|------------|
| Document ingestion | Chunking (fixed, semantic, recursive) | Chunk coherence |
| Embedding model | OpenAI ada-002, Cohere, sentence-transformers | Recall@10 |
| Vector store | Pinecone, Weaviate, Qdrant, pgvector, Chroma | Query latency |
| Retriever | Dense, sparse (BM25), hybrid | MRR, nDCG |
| Reranker | Cross-encoder, Cohere Rerank | Precision@K |
| Generator | GPT-4, Claude, Llama | Faithfulness, relevance |

### Chunking Strategy

| Strategy | Chunk Size | Overlap | Best For |
|----------|-----------|---------|----------|
| Fixed-size | 512-1024 tokens | 10-20% | General documents |
| Semantic | Variable | Sentence boundary | Technical docs |
| Recursive | 256-512 tokens | Parent-child | Hierarchical content |
| Document-level | Full document | None | Short documents |

### Evaluation Metrics

| Metric | Measures | Target |
|--------|----------|--------|
| Faithfulness | Answer grounded in retrieved context | ≥ 0.9 |
| Answer relevance | Answer addresses the question | ≥ 0.85 |
| Context precision | Retrieved chunks are relevant | ≥ 0.8 |
| Context recall | All needed info was retrieved | ≥ 0.8 |

---

## Cost Tracking

### Compute Cost Components

| Component | Unit | Optimization |
|-----------|------|-------------|
| Training compute | GPU-hours | Spot instances, mixed precision |
| Inference compute | Requests/second/GPU | Batching, quantization, distillation |
| Storage | GB/month | Model pruning, checkpoint cleanup |
| Data transfer | GB transferred | Edge caching, compression |
| API calls (external) | Per 1K tokens | Prompt optimization, caching |

### Cost Optimization Techniques

| Technique | Savings | Trade-off |
|-----------|---------|-----------|
| Mixed precision (FP16/BF16) | 40-60% training time | Minimal accuracy loss |
| Model quantization (INT8) | 2-4x inference speedup | <1% accuracy loss typically |
| Knowledge distillation | 5-10x smaller model | 1-3% accuracy loss |
| Spot/preemptible instances | 60-90% compute cost | Interruption risk |
| Request batching | 2-5x throughput | Added latency |
| Prompt caching | 50-80% API cost | Stale responses risk |

### Budget Template

| Item | Monthly Budget | Alert at |
|------|---------------|----------|
| Training | Based on experiment plan | 80% |
| Inference | Based on traffic forecast | 90% |
| Storage | Based on model count × size | 80% |
| External APIs | Based on request volume | 75% |
