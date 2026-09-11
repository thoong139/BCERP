# Playbook: Audit vòng đời mô hình ML

> **Type**: Agent Skill Playbook
> **Agent**: model-qa
> **Triggered by**: Pre-production deployment của ML model mới hoặc model được retrain
> **Output**: Model Lifecycle Audit Report tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Trước khi deploy ML model lên production lần đầu
- Khi model được retrain với dữ liệu mới (major version update)
- Khi có yêu cầu periodic audit theo governance schedule
- Khi `ai-engineer` hoàn thành model development và cần independent validation
- Khi stakeholder yêu cầu chứng nhận model fit-for-purpose

---

## Procedure

### Bước 1: Đọc tài liệu model và xác định scope audit

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3, PHASE2

READ: .claude/references/team-expert/testing/model-validation-tools.md

Thu thập tài liệu bắt buộc:
□ Model card / model specification document
□ Training data description (nguồn, thời gian, size)
□ Feature engineering documentation
□ Hyperparameters và training configuration
□ Evaluation metrics report từ team phát triển
□ Deployment architecture (inference endpoint, batch vs. real-time)
□ Monitoring plan

Nếu tài liệu thiếu → ghi nhận là DOCUMENTATION GAP và rate theo severity:
- Thiếu model card = HIGH severity gap (không thể audit đầy đủ)
- Thiếu feature docs = MEDIUM severity gap
- Thiếu monitoring plan = HIGH severity gap (production risk)

Xác định REQ-IDs liên quan đến model performance, accuracy, fairness
```

### Bước 2: Audit chất lượng dữ liệu training

```
READ: .claude/references/team-expert/testing/model-validation-tools.md (PSI, data quality sections)

Phân tích training data:
□ Kích thước dataset có đủ để generalize không?
   (classification: >= 10 × feature count × classes; regression tùy context)
□ Class imbalance có được xử lý không? Phương pháp nào? (oversampling, undersampling, class weights)
□ Missing values có được impute hợp lý không? Có tạo bias không?
□ Leakage detection — có feature nào "biết tương lai" không?
   (ví dụ: dùng outcome variable làm input; timestamp leakage)
□ Train/validation/test split có stratified không? Có temporal leak không?
□ Data provenance — dữ liệu có được track nguồn gốc không?
□ PII trong training data — có được anonymize đúng không?

Feature drift analysis:
□ So sánh distribution của features giữa training set và production data
□ PSI (Population Stability Index) cho mỗi feature:
   PSI < 0.1 = STABLE
   PSI 0.1-0.2 = MINOR DRIFT (monitor)
   PSI > 0.2 = SIGNIFICANT DRIFT (retrain cần thiết)
□ SHAP global feature importance — top 10 features có hợp lý về business không?
```

### Bước 3: Đánh giá hiệu năng mô hình

```
READ: .claude/references/team-expert/testing/model-validation-tools.md (metrics sections)

Classification metrics (nếu model là classifier):
□ Precision — trong số dự đoán positive, bao nhiêu đúng?
□ Recall (Sensitivity) — trong số thực sự positive, model bắt được bao nhiêu?
□ F1-score — harmonic mean của precision và recall
□ AUC-ROC — khả năng phân biệt class, > 0.7 là acceptable
□ AUC-PR (Precision-Recall curve) — quan trọng khi class imbalanced
□ Calibration — predicted probability có phản ánh actual probability không?
   (Hosmer-Lemeshow test, Brier Score, reliability diagram)

Regression metrics (nếu model là regressor):
□ MAE, RMSE, MAPE
□ Residual distribution — có pattern không? (heteroscedasticity)
□ Prediction interval coverage

Evaluation trên TẤT CẢ data splits:
□ Training set metrics (expected: tốt nhất, kiểm tra overfitting)
□ Validation set metrics (dùng để tune hyperparameters)
□ Test set metrics (SSOT cho performance — chỉ đọc 1 lần)
□ OOT (Out-of-Time) metrics — QUAN TRỌNG NHẤT: performance trên data tương lai

So sánh với baseline:
□ Baseline = model đơn giản nhất (logistic regression, mean predictor, current business rule)
□ Model mới có improvement thực sự > baseline không?
□ Improvement có statistically significant không? (confidence intervals)
```

### Bước 4: Kiểm tra calibration và confidence

```
Calibration = predicted probability có align với actual frequency không?
Ví dụ: trong tất cả cases model predict 80% probability, thực tế 80% có xảy ra không?

□ Vẽ reliability diagram (calibration curve)
□ Hosmer-Lemeshow test: p-value > 0.05 là calibrated
□ Brier Score: càng thấp càng tốt (0 = perfect, 0.25 = baseline no-skill)
□ Nếu model poorly calibrated → Platt scaling hoặc isotonic regression

Confidence assessment:
□ Model có cung cấp uncertainty estimate không? (prediction intervals, dropout-based uncertainty)
□ Model có biết "không biết" không? (out-of-distribution detection)
□ Extreme predictions (0% hoặc 100%) có nhiều quá không?
```

### Bước 5: Kiểm tra inference latency

```
Đây là production readiness check — model tốt nhưng chậm = không dùng được.

□ Inference latency p50 là bao nhiêu?
□ Inference latency p95 là bao nhiêu? (đây là số quan trọng với real users)
□ Inference latency p99 là bao nhiêu? (tail latency)
□ Latency khi batch inference so với single inference?
□ Memory footprint của model đã load?
□ Cold start time (nếu serverless inference)?
□ GPU vs CPU inference — decision có justified không?

SLA thresholds (điều chỉnh theo use case):
Real-time: p95 < 100ms (user-facing), p95 < 500ms (internal API)
Batch: throughput quan trọng hơn latency
```

### Bước 6: Thiết lập monitoring cho production

```
Mô hình production không có monitoring = time bomb.

□ Data drift monitoring — có alert khi PSI > 0.2 không?
□ Prediction drift — distribution của predictions có thay đổi không?
□ Model performance monitoring — có ground truth feedback loop không?
   (nếu không có ground truth → ít nhất monitor proxy metrics)
□ Latency monitoring — alert khi p95 > SLA
□ Error rate monitoring — prediction errors, timeouts, OOM
□ Model version tracking — biết version nào đang chạy trên production

Dashboard bắt buộc:
□ Feature drift over time (PSI per feature)
□ Prediction distribution over time
□ Actual vs predicted (khi có ground truth)
□ Inference latency percentiles
□ Error rates
```

### Bước 7: Thiết kế A/B test cho rollout

```
Không deploy 100% traffic ngay — dù model tốt trên test set cũng cần A/B validation.

□ Xác định traffic split: challenger (new) vs champion (current/baseline)
   - Conservative: 5-10% challenger traffic ban đầu
   - Normal: 20-30% challenger traffic
□ Xác định success metrics business (không chỉ ML metrics)
   - Ví dụ: conversion rate, revenue per session, customer satisfaction
□ Xác định guardrail metrics — nếu vượt thì auto-rollback
□ Thời gian A/B test tối thiểu đủ statistical power
□ Randomization unit: user-level hay session-level?
□ Có bias trong assignment không? (holdback contamination)
```

### Bước 8: Kiểm tra kế hoạch rollback

```
□ Có cơ chế rollback về previous model version không?
□ Thời gian rollback ước tính là bao nhiêu?
□ Rollback triggers đã được define không? (performance drop, error rate spike)
□ Ai có quyền trigger rollback? (approval process)
□ Shadow mode deployment đã được test chưa? (run new model in parallel, không dùng output)
□ Model registry có version control không?
```

### Bước 9: Output Model Lifecycle Audit Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/model-lifecycle-audit.md

Cấu trúc output:
1. Audit Decision: APPROVED / CONDITIONAL / NOT APPROVED
   - APPROVED: tất cả checks pass, sẵn sàng deploy
   - CONDITIONAL: có issues nhỏ, cần fix với timeline cụ thể trước/sau deploy
   - NOT APPROVED: có critical issues cần giải quyết trước khi deploy
2. Model Summary (tên, version, type, use case, REQ-IDs)
3. Data Quality Findings (table: check | result | severity | evidence)
4. Performance Metrics Summary (table: metric | training | validation | test | OOT | threshold | pass/fail)
5. Calibration Assessment
6. Inference Latency Results (p50/p95/p99)
7. Monitoring Setup Status
8. A/B Test Design
9. Rollback Plan
10. Critical Findings (phải fix trước deploy)
11. Recommendations (cải thiện trong tương lai)
```

---

## Checklist trước khi submit

```
□ OOT validation đã được thực hiện (KHÔNG skip)
□ Mọi metric reported trên test set, không phải training set
□ Calibration đã được kiểm tra (không chỉ AUC/F1)
□ Inference latency đã được đo thực tế (không estimate)
□ Monitoring plan tồn tại và được review
□ A/B test design có statistical power analysis
□ REQ-IDs được reference trong performance requirements check
□ Documentation gaps được ghi nhận với severity
□ Audit decision có evidence cụ thể — không claim APPROVED chung chung
```
