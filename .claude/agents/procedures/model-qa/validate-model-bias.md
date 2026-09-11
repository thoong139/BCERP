# Playbook: Kiểm định thiên kiến mô hình ML

> **Type**: Agent Skill Playbook
> **Agent**: model-qa
> **Triggered by**: Bias audit cho ML model — trước production deployment hoặc định kỳ
> **Output**: Model Bias Validation Report

---

## Khi nào dùng playbook này

- Bắt buộc với mọi model ảnh hưởng đến quyết định liên quan con người (credit scoring, hiring, medical, pricing)
- Khi có yêu cầu từ legal/compliance về fairness audit
- Sau khi model được retrain với dữ liệu mới
- Khi monitoring phát hiện performance gap giữa các nhóm dân số
- Khi `legal-expert` hoặc `security` raise fairness concerns

---

## Procedure

### Bước 1: Xác định protected attributes và context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2, PHASE3

READ: .claude/references/team-expert/testing/model-validation-tools.md (fairness metrics sections)

Protected attributes phổ biến (theo context và jurisdiction):
□ Giới tính (gender) — hầu hết các domain
□ Tuổi (age) — tín dụng, tuyển dụng, bảo hiểm
□ Chủng tộc/dân tộc (race/ethnicity)
□ Tôn giáo (religion)
□ Khuyết tật (disability status)
□ Tình trạng hôn nhân (marital status) — tín dụng, bảo hiểm
□ Quốc tịch/xuất xứ
□ Proxy variables — mã bưu chính, tên, ngôn ngữ có thể là proxy cho race/ethnicity

Xác định:
- Use case của model là gì? (credit, hiring, medical, insurance, recommendation, pricing)
- Jurisdiction nào áp dụng? (EU AI Act, ECOA, EEOC, GDPR requirements)
- Protected attributes nào relevant với context này?
- Ground truth labels có bias không? (ví dụ: lịch sử tuyển dụng bị biased → label bị biased)
```

### Bước 2: Đo fairness metrics — demographic parity

```
Demographic Parity (Statistical Parity):
Định nghĩa: Tỷ lệ positive predictions phải bằng nhau giữa các nhóm.
P(Y_hat = 1 | A = 0) = P(Y_hat = 1 | A = 1)

Cách đo:
□ Tính selection rate (% predicted positive) cho mỗi nhóm
□ Disparate Impact Ratio = min_group_rate / max_group_rate
   DI > 0.8 = generally acceptable (80% rule)
   DI 0.7-0.8 = concerning, cần justify
   DI < 0.7 = significant disparity

Ví dụ: Nếu model approve 60% application của nhóm A nhưng chỉ 40% của nhóm B
→ DI = 40/60 = 0.67 → dưới ngưỡng 0.8 → cần giải thích

Ghi nhận cho mỗi protected attribute:
ATTRIBUTE | GROUP | SELECTION_RATE | DI_RATIO | STATUS
```

### Bước 3: Đo fairness metrics — equalized odds

```
Equalized Odds:
Định nghĩa: True Positive Rate VÀ False Positive Rate phải bằng nhau giữa các nhóm.
TPR_A = TPR_B và FPR_A = FPR_B

Cách đo:
□ TPR (Recall) cho mỗi nhóm — model "bắt" được bao nhiêu actual positives?
□ FPR cho mỗi nhóm — model "sai" bao nhiêu actual negatives?
□ Equal Opportunity = chỉ require TPR bằng nhau (relaxed version)

WHY quan trọng: Demographic parity alone không đủ.
Ví dụ: Loan model có TPR 90% cho nhóm giàu nhưng TPR 60% cho nhóm nghèo
→ Model "bỏ sót" 40% deserving applicants từ nhóm nghèo

Thresholds quan tâm:
TPR gap > 10 percentage points = significant
FPR gap > 5 percentage points = significant

Ghi nhận:
ATTRIBUTE | GROUP | TPR | FPR | TPR_GAP | FPR_GAP | STATUS
```

### Bước 4: Phân tích hiệu năng theo subgroup

```
Không chỉ so sánh 2 nhóm — phân tích granular theo subgroups:

□ Tính metrics (precision, recall, F1, AUC) cho TỪ ĐIỀU KIỆN subgroup
□ Intersection analysis — ví dụ: phụ nữ + cao tuổi + thu nhập thấp
   (intersectional bias thường bị bỏ qua khi chỉ phân tích từng attribute riêng lẻ)
□ Confidence intervals cho mỗi subgroup (nhóm nhỏ → uncertainty cao hơn)
□ Minimum subgroup size để kết quả có ý nghĩa thống kê

Cảnh báo: Subgroup quá nhỏ (< 50 samples) → kết quả không đáng tin cậy
Giải pháp: Ghi nhận limitation, đề xuất collect thêm data

Tạo heatmap: metric × subgroup để visualize gaps
```

### Bước 5: Adversarial testing

```
Kiểm tra xem model có bị trick bởi bias không:

□ Counterfactual fairness test:
   Lấy 1 sample → thay đổi CHỈ protected attribute → prediction có thay đổi không?
   Nếu prediction thay đổi khi chỉ đổi gender/race → direct discrimination

□ Stereotype test:
   Tạo synthetic samples với stereotype profiles → model có reinforce stereotypes không?
   Ví dụ: "engineer" → model assign male? "nurse" → model assign female?

□ Name test:
   Dùng tên điển hình của các nhóm dân tộc khác nhau → outcome có khác không?
   (Classic test cho hiring bias)

□ Proxy variable test:
   Loại protected attribute khỏi features → performance gap có giảm không?
   Nếu không giảm → proxy variables đang mang bias

Ghi nhận mỗi adversarial test:
TEST_TYPE | SETUP | EXPECTED | ACTUAL | BIAS_DETECTED | SEVERITY
```

### Bước 6: Phân tích nguồn gốc bias

```
Sau khi xác định bias tồn tại, cần hiểu NGUỒN GỐC để fix đúng:

[Historical bias — dữ liệu training phản ánh bất bình đẳng lịch sử]
□ Label có bị biased không? (ví dụ: hiring data từ thời kỳ discrimination)
□ Representation bias — một nhóm có underrepresented trong training data không?
□ Measurement bias — cách đo ground truth có consistent giữa nhóm không?

[Aggregation bias — model treat tất cả như nhau khi không thể]
□ Một mô hình fit cho tất cả nhóm có phù hợp không?
□ Cần separate models hay subgroup-specific thresholds không?

[Evaluation bias — benchmark không representative]
□ Test set có representative distribution không?
□ Metric có phù hợp với tất cả subgroups không?

[Deployment bias — use case shift]
□ Model được dùng đúng mục đích thiết kế không?
□ Distribution shift giữa training và production có tạo bias mới không?

Với mỗi bias source tìm thấy → ghi severity và mitigation approach
```

### Bước 7: Đề xuất biện pháp giảm thiểu bias

```
Pre-processing techniques (trên dữ liệu, trước training):
□ Resampling: oversample underrepresented groups
□ Reweighting: assign higher weight cho underrepresented samples
□ Fair representation learning: học feature representation không chứa protected info
□ Data augmentation: tạo synthetic samples để balance

In-processing techniques (trong quá trình training):
□ Fairness constraints: thêm penalty term vào loss function
□ Adversarial debiasing: train model predict outcome + adversarial predict protected attr
□ Prejudice remover: regularization term dựa trên mutual information với protected attr

Post-processing techniques (sau khi model đã train):
□ Threshold adjustment per group: mỗi nhóm có threshold khác nhau để equalize TPR
□ Calibration per group
□ Reject option: model phải confident để make decision, uncertain cases → human review

Recommendation format:
BIAS_TYPE | SEVERITY | TECHNIQUE | TRADE-OFF | ESTIMATED_EFFORT
```

### Bước 8: Output Model Bias Validation Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/model-bias-validation.md

Cấu trúc output:
1. Bias Audit Decision: PASS / CONDITIONAL PASS / FAIL
   - PASS: không có significant disparity (DI > 0.8, gaps trong threshold)
   - CONDITIONAL PASS: disparity tồn tại nhưng có justify + mitigation plan
   - FAIL: significant bias không thể justify, cần mitigate trước deploy
2. Protected Attributes Analyzed
3. Fairness Metrics Summary (demographic parity, equalized odds, per subgroup)
4. Adversarial Test Results
5. Bias Source Analysis
6. Mitigation Recommendations (prioritized)
7. Monitoring Recommendations (ongoing fairness tracking)
8. Legal/Compliance Notes (relevant regulations cho jurisdiction)
9. REQ-IDs compliance check
```

---

## Checklist trước khi submit

```
□ Tất cả relevant protected attributes đã được test (không bỏ qua vì "không có data")
□ Cả demographic parity VÀ equalized odds đã được đo (không chỉ 1 metric)
□ Intersectional analysis đã được thực hiện
□ Adversarial testing đã được chạy
□ Bias source đã được identify (không chỉ nói "có bias" mà không giải thích tại sao)
□ Mitigation recommendations có trade-off analysis (fairness vs. accuracy)
□ Jurisdiction-specific requirements đã được noted
□ Subgroup sample sizes đã được verified (kết quả nhỏ < 50 mẫu có disclaimer)
```
