# Playbook: Review Chất lượng Dữ liệu Sau Remediation

> **Type**: Agent Skill Playbook
> **Agent**: ai-data-remediation-engineer
> **Triggered by**: Review chất lượng dữ liệu sau khi pipeline remediation hoàn thành
> **Output**: Remediated data quality report

---

## Khi nào dùng playbook này

- Sau mỗi lần chạy remediation pipeline trên production data
- Trước khi bàn giao dataset cho AI/ML team để training
- Khi AI/ML team báo cáo model performance kém (có thể do data quality)
- Định kỳ review dataset đã published để detect drift

---

## Procedure

### Bước 1: Đọc context và baseline

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (remediation pipeline design)

Cần đọc:
□ .mc-data/docs/phase3-architecture/remediation-pipeline-design.md
□ Audit trail của pipeline run cần review
□ Spec của dataset: expected schema, quality thresholds
□ REQ-IDs liên quan
□ Nếu có previous run: kết quả review lần trước (để compare)
```

### Bước 2: Before/After Comparison

So sánh metrics trước và sau remediation:

```
VOLUME METRICS:
  □ Input record count: [N_in]
  □ Output record count: [N_out]
  □ Retention rate (%): N_out / N_in × 100
  □ Removed record count: N_in - N_out
  □ Removal breakdown:
    → Suppressed (too much PII): [count]
    → Removed (duplicate): [count]
    → Rejected (anomaly): [count]
    → Failed quality threshold: [count]

TARGET THRESHOLDS:
  □ Retention rate ≥ 70% (nếu < 70% → có thể pipeline quá aggressive)
  □ Retention rate ≤ 98% (nếu > 98% → có thể PII detection không đủ)
  □ Dedup removal rate ≤ 30% (nếu > 30% → dataset gốc có vấn đề nghiêm trọng)

NULL RATE COMPARISON (per critical column):
  □ Before: null_rate_before[col]
  □ After: null_rate_after[col]
  □ Nếu null_rate_after > null_rate_before → anonymization đã introduce nulls?

FIELD LENGTH DISTRIBUTION:
  □ Text fields: min/mean/max length before vs after
  □ Nếu mean length giảm đáng kể → PII removal đang cắt quá nhiều context
```

### Bước 3: PII Leak Test — Verify Không Còn Residuals

Đây là bước quan trọng nhất — phải pass 100% trước khi release dataset.

```
STRATEGY: Chạy lại PII detection pipeline trên output dataset
  → Nếu tìm thấy PII → remediation failed → không release

REGEX SCAN (tất cả pattern từ implement-pii-removal.md):
  □ Email pattern: 0 matches expected
  □ Phone pattern: 0 matches expected
  □ National ID pattern: 0 matches expected
  □ Credit card pattern: 0 matches expected
  □ SSN pattern: 0 matches expected
  □ IP address pattern: 0 matches expected

NER SCAN (chạy model offline):
  □ PERSON entity count: 0 expected (hoặc đúng với dữ liệu synthetic)
  □ Contextual patterns: 0 matches expected

EDGE CASES CẦN TEST RIÊNG:
  □ PII trong URL (vd: /users/nguyenvana@email.com)
  □ PII bị obfuscate: "nguyen dot van dot a at gmail dot com"
  □ PII partial: "email của tôi là nguyen" → flag warning
  □ PII trong JSON embedded trong text field
  □ PII trong base64 encoded strings (decode và scan)
  □ PII bị split qua nhiều fields: first_name + last_name separated

GHI KẾT QUẢ:
  □ Residual PII count per type
  □ Nếu count > 0: FAIL — không release, report về pipeline team
  □ Sample records có residual (chỉ log record_id + PII type, không log value)
```

### Bước 4: Semantic Coherence Verification

Sau deduplication, kiểm tra data còn meaningful không:

```
TEXT DATA:
  □ Sample 100 records ngẫu nhiên → manual review (hoặc automated với classifier)
  □ Kiểm tra: sau khi masking, câu văn có coherent không?
    → "Hãy liên hệ [NAME_REMOVED] qua [EMAIL_REMOVED]" — acceptable
    → "[NAME_REMOVED] [NAME_REMOVED] [NAME_REMOVED] [NAME_REMOVED]" — too destructive
  □ Average text length sau masking / trước masking > 0.5 (50% content preserved)

DEDUP COHERENCE:
  □ Sau dedup, canonical records có representative không?
    → Sample duplicate clusters → kiểm tra canonical record là record tốt nhất
  □ Không có cluster nào canonical record bị suppress nhưng duplicate còn sót

TABULAR DATA:
  □ Distribution của categorical columns sau anonymization vẫn meaningful
  □ Numeric distributions sau generalization không quá broad để vô nghĩa
  □ Relationships giữa fields vẫn hợp lý (vd: generalized_age_group và product_category có correlation?)
```

### Bước 5: Label Accuracy (ML Training Data)

Nếu dataset có labels cho supervised learning:

```
LABEL DISTRIBUTION:
  □ Class distribution trước và sau remediation
  □ Thay đổi distribution có significant không? (> 5% per class)
  □ Nếu distribution thay đổi nhiều → remediation bias?

LABEL CONSISTENCY:
  □ Removed records có phân bố đồng đều qua các classes không?
    → Nếu 1 class bị remove nhiều hơn → sẽ skew model
  □ Inter-annotator agreement (nếu có nhiều annotators):
    → Cohen's Kappa hoặc Fleiss' Kappa ≥ 0.7 là acceptable
    → < 0.5 → label noise cao → cần re-annotation

LABEL NOISE DETECTION:
  □ Train simple model → find records với high loss (potential mislabeled)
  □ Confidence-based filtering: records với low ensemble confidence → review
  □ Duplicate records có consistent labels không?
    → Nếu same content nhưng different labels → annotation error
```

### Bước 6: Class Balance Assessment

```
IMBALANCED CLASS CHECK:
  □ Tỷ lệ majority class / minority class
  □ Nếu > 10:1 → severe imbalance, cần strategy:
    → Oversampling: SMOTE cho tabular, augmentation cho text
    → Undersampling: random hoặc informed (Tomek links)
    → Class weights trong training
    → Separate metric focus: F1 / Precision-Recall thay vì accuracy

CHO NLP DATA:
  □ Sentence length distribution per class
    → Nếu một class có sentences dài hơn nhiều → model học length heuristic, không phải semantics
  □ Vocabulary overlap giữa classes
    → Quá ít overlap → too easy → model sẽ overfit
    → Quá nhiều overlap → ambiguous → cần better labeling criteria

CHO IMAGE DATA (nếu applicable):
  □ Image resolution distribution per class
  □ Color distribution per class (có bias không?)
```

### Bước 7: Data Diversity Metrics

Diversity quan trọng để tránh model bias:

```
TEXT DATA DIVERSITY:
  □ Vocabulary size (unique tokens / total tokens) — lexical diversity
  □ Sentence length variance — structural diversity
  □ Topic coverage: nếu có domain labels, mỗi topic có đủ samples không?
  □ Temporal diversity: data span bao nhiêu năm? Có bị concentration không?
  □ Source diversity: data từ bao nhiêu nguồn khác nhau?

DEMOGRAPHIC DIVERSITY (nếu applicable):
  □ Geographic distribution (nếu location available sau anonymization)
  □ Age group distribution (sau generalization)
  □ Language/dialect diversity (nếu multilingual)

ALERT KHI:
  □ Top 10% records chiếm > 50% unique vocabulary → domain too narrow
  □ Single source chiếm > 60% records → source diversity risk
  □ Date range concentrated → temporal bias
```

### Bước 8: Fingerprinting Verification

Kiểm tra deduplication fingerprinting không có false positives:

```
FALSE POSITIVE CHECK (records bị dedup không đáng):
  □ Sample 50 records từ "rejected as duplicate" list
  □ Manual verify: chúng có thực sự duplicate không?
  □ False positive rate target: < 1%
  □ Nếu false positive > 1% → threshold semantic similarity quá thấp → re-tune

FALSE NEGATIVE CHECK (duplicates không bị detect):
  □ Sample 100 records từ final dataset
  □ Chạy pairwise similarity trên sample
  □ Nếu phát hiện pairs có similarity > 0.95 còn sót → fingerprinting miss
  □ Ước tính false negative rate

HASH COLLISION CHECK:
  □ Verify không có hash collisions trong MD5/SHA256 (extremely rare nhưng cần log)
  □ Count records với duplicate hashes nhưng different content
```

### Bước 9: Sign-off Checklist

Đây là gate trước khi release dataset cho ML team:

```
QUALITY GATES (tất cả phải PASS):
  □ [PASS/FAIL] PII Leak Test: 0 residual PII detected
  □ [PASS/FAIL] Retention Rate: ≥ 70% và ≤ 98%
  □ [PASS/FAIL] K-Anonymity: k ≥ 5 (hoặc theo requirement)
  □ [PASS/FAIL] Null Rate: tất cả critical columns ≤ threshold
  □ [PASS/FAIL] Semantic Coherence: average text length ratio ≥ 0.5
  □ [PASS/FAIL] Label Distribution: thay đổi < 5% per class (nếu có labels)
  □ [PASS/FAIL] Reconciliation Delta: input/output math khớp

CONDITIONAL GATES (WARN nếu fail — không block):
  □ [PASS/WARN] Class Balance: ratio < 10:1
  □ [PASS/WARN] Source Diversity: không có source > 60%
  □ [PASS/WARN] Temporal Coverage: không quá concentrated

SIGN-OFF PROCESS:
  □ Engineer sign-off: data engineer / ai-data-remediation-engineer
  □ Privacy/Security review (nếu GDPR/HIPAA applicable)
  □ ML team pre-acceptance: sample review trước khi full training
  □ Document version: dataset_version, pipeline_version, review_date
```

### Bước 10: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/remediated-data-quality-report-[YYYYMMDD].md

Cấu trúc output:
1. Executive Summary
   - Kết quả tổng thể: PASS / PASS WITH WARNINGS / FAIL
   - Dataset version, pipeline run ID, review date
   - Số records: input → output (retention rate)

2. Before/After Comparison (bảng)
3. PII Leak Test Results (MUST be 0 residuals)
4. Semantic Coherence Assessment
5. Label Quality Report (nếu có labels)
6. Class Balance Report
7. Data Diversity Metrics
8. Fingerprinting Verification
9. Sign-off Checklist (tất cả gates với PASS/FAIL/WARN)
10. Issues Found và Remediation Plan
11. Approval Signatures (engineer + privacy review nếu cần)
```

---

## Checklist trước khi submit

```
□ PII Leak Test đã chạy đầy đủ — không skip bất kỳ PII type nào
□ Before/after comparison có đủ metrics
□ Retention rate nằm trong range acceptable
□ K-anonymity verified (không chỉ check, có số liệu cụ thể)
□ Sign-off checklist rõ PASS/FAIL/WARN cho từng gate
□ Nếu có FAIL gate: action plan và owner ghi rõ
□ Dataset version và pipeline version được ghi nhận
□ Report tự nó không chứa PII (không sample records với sensitive content)
□ Reviewers đã được identify (engineer + privacy nếu GDPR/HIPAA)
```
