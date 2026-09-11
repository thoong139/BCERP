# Playbook: Thiết kế Data Remediation Pipeline

> **Type**: Agent Skill Playbook
> **Agent**: ai-data-remediation-engineer
> **Triggered by**: Khi cần thiết kế data remediation/cleaning pipeline cho AI/ML training data
> **Output**: Remediation pipeline design document

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` khi dự án có yêu cầu chuẩn bị data cho AI/ML training
- Khi cần thiết kế pipeline làm sạch dữ liệu: PII removal, deduplication semantic, anomaly detection
- Khi data source chứa sensitive data cần xử lý trước khi đưa vào training

---

## Procedure

### Bước 1: Đọc requirements và xác định scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (functional requirements), PHASE3 (architecture)

Cần xác định:
□ REQ-IDs liên quan đến data preparation / AI training
□ Loại dữ liệu: structured (tabular) / unstructured (text, image, audio) / semi-structured (JSON, XML)
□ Volume: số records, kích thước tổng
□ Nguồn gốc dữ liệu: thu thập từ đâu? internal / external / scraping?
□ Mục đích sử dụng: training / fine-tuning / RAG / evaluation?
□ Model sẽ dùng data: LLM / classification / regression / image?
□ Compliance requirements: GDPR? HIPAA? PDPA? internal data policy?
□ Air-gapped requirement: dữ liệu có được phép rời khỏi môi trường không?
```

### Bước 2: Quality Assessment — Đánh giá toàn diện dữ liệu đầu vào

Trước khi thiết kế pipeline, phải hiểu "sức khỏe" của data nguồn:

```
COMPLETENESS (Đầy đủ):
  □ % records có đủ required fields
  □ Null rate per column
  □ Missing mandatory context (label, ground truth, metadata)
  □ Incomplete sequences (nếu là time-series hoặc conversation data)

CONSISTENCY (Nhất quán):
  □ Encoding: UTF-8? BOM issues? mixed encoding?
  □ Date format: ISO 8601 hay nhiều formats hỗn hợp?
  □ Label consistency: cùng concept có nhiều cách gọi không? (vd: "Vietnam", "VN", "Viet Nam")
  □ Schema consistency: fields có tên khác nhau qua các versions?

ACCURACY (Chính xác):
  □ Ground truth labels: có noise không? inter-annotator agreement là bao nhiêu?
  □ Factual accuracy: nếu là knowledge base, facts có outdated không?
  □ Numeric ranges: giá trị có nằm trong khoảng hợp lý không?

TIMELINESS (Kịp thời):
  □ Data age: dữ liệu từ bao giờ? có outdated với domain đang target không?
  □ Concept drift: behavior của nguồn có thay đổi theo thời gian không?
```

### Bước 3: PII Detection Strategy

Thiết kế chiến lược phát hiện PII TRƯỚC khi xử lý:

```
TAXONOMY PII CẦN DETECT:

DIRECT IDENTIFIERS (nhận diện trực tiếp):
  □ Full name (họ tên đầy đủ)
  □ Email address
  □ Phone number (mobile, landline, international format)
  □ National ID / CMND / CCCD / SSN / Passport number
  □ Credit card / bank account number
  □ IP address (considered PII dưới GDPR)
  □ Biometric data (fingerprint hash, face encoding)

QUASI-IDENTIFIERS (khi kết hợp có thể nhận diện):
  □ Age + Gender + ZIP/City combination
  □ Job title + Organization + Location
  □ Date of birth (not full DOB alone, but in combination)
  □ Ethnicity, religion, political opinion (sensitive categories)
  □ Medical conditions, diagnoses

INDIRECT CONTEXT:
  □ User-generated content có chứa PII embedded trong text
  □ File metadata: author, geolocation trong EXIF
  □ URLs chứa user IDs, session tokens

DETECTION METHODS:
  Tầng 1 — Regex patterns: email, phone, ID number formats
  Tầng 2 — NER model: person name, organization, location
    → Dùng model offline nếu air-gapped requirement
    → Ví dụ: spaCy vi_core_news_lg, Hugging Face NER model local
  Tầng 3 — Contextual: tìm patterns như "tên tôi là X", "số điện thoại: Y"
  Tầng 4 — ML-based: fine-tuned classifier cho domain-specific PII
```

### Bước 4: Deduplication Approach

Thiết kế 3 tầng dedup:

```
TẦNG 1 — SYNTACTIC DEDUP (exact match):
  □ MD5/SHA256 hash của normalized record
  □ Normalize trước khi hash: lowercase, strip whitespace, unicode normalize
  □ Detect exact duplicates với cost O(n)
  □ Tool: pandas drop_duplicates, Spark dropDuplicates

TẦNG 2 — NEAR-DUPLICATE DEDUP (MinHash/LSH):
  □ Shingling: tạo n-gram (3-5 grams) từ text content
  □ MinHash signature: 128-256 hash functions
  □ Locality-Sensitive Hashing: nhóm candidates có similarity > threshold
  □ Threshold đề xuất: 0.85 Jaccard similarity cho text data
  □ Tool: datasketch library, Spark với LSH

TẦNG 3 — SEMANTIC DEDUP (embedding-based):
  □ Embed records thành dense vectors
  □ Model embedding: sentence-transformers local (air-gapped)
    → paraphrase-multilingual-mpnet-base-v2 cho multilingual
    → Chạy offline hoàn toàn nếu sensitive data
  □ Cosine similarity threshold: 0.92-0.95 tùy domain
  □ Clustering: FAISS index cho nearest neighbor search
  □ QUAN TRỌNG: semantic dedup bảo toàn diversity — không over-deduplicate

QUYẾT ĐỊNH GIỮ RECORD NÀO KHI DUPLICATE:
  □ Prefer record với label đã verified
  □ Prefer record mới hơn nếu content tương đương
  □ Prefer record có metadata đầy đủ hơn
  □ Document selection logic — reproducible
```

### Bước 5: Anomaly Detection

```
STRUCTURAL ANOMALIES:
  □ Record quá ngắn: text < 10 tokens → likely noise
  □ Record quá dài: text > 10,000 tokens → có thể merged incorrectly
  □ Boilerplate content: "Lorem ipsum", placeholder text
  □ Encoding garbage: ????????, □□□□

CONTENT ANOMALIES:
  □ Language detection: nếu pipeline expect Vietnamese nhưng detect English/other → flag
  □ Toxicity score: nếu dùng cho LLM training, lọc harmful content
  □ Repetitive content: nhiều đoạn lặp lại trong cùng record (copy-paste artifact)

LABEL ANOMALIES (nếu là supervised data):
  □ Label out of distribution: class label không thuộc expected set
  □ Label vs content mismatch: text về technology nhưng label là "cooking"
  □ Low confidence labels: nếu có confidence score < threshold

TOOLS:
  □ Lingua (language detection, offline)
  □ Detoxify (toxicity classification)
  □ Custome regex patterns cho boilerplate
  □ IQR-based outlier detection cho numeric features
```

### Bước 6: Air-Gapped Inference Consideration

```
KỊCH BẢN CẦN AIR-GAPPED:
  □ Data chứa PII cần xử lý (NER, embedding)
  □ Data là confidential IP (source code, internal docs)
  □ Compliance mandate: HIPAA, GDPR Article 44 (transfer restriction)

AIR-GAPPED SETUP:
  □ SLM (Small Language Model) chạy hoàn toàn local:
    → NER: spaCy với model local, Hugging Face model offline
    → Embedding: sentence-transformers với cached model
    → Inference: CPU-only hoặc local GPU, không outbound network
  □ Network isolation: Firewall rules, no internet access trong processing environment
  □ Artifact verification: checksum model files trước khi load
  □ Log inference: không log input text (chứa PII), chỉ log metrics

LAMBDA-ONLY OUTPUT:
  □ Không persist intermediate results chứa PII
  □ Process in-memory: load → transform → output → discard
  □ Output: chỉ lưu anonymized/cleaned records + audit metrics
  □ If pipeline crashes: không có PII data còn lại trên disk
```

### Bước 7: Remediation Workflow Design

Thiết kế workflow tổng thể theo stages:

```
STAGE 0: DATA INTAKE
  → Input: raw dataset (file/stream/DB)
  → Action: schema validation, volume check
  → Decision: proceed / reject if critical schema mismatch
  → Output: validated intake record, intake_report

STAGE 1: PII DETECTION
  → Input: validated records
  → Action: regex scan + NER scan + contextual scan
  → Decision: flag PII-containing records
  → Output: records với pii_detected=true/false + pii_entities list

STAGE 2: PII REMOVAL
  → Input: PII-flagged records
  → Action: anonymization per entity type
  → Decision: record usable? (nếu sau removal còn meaningful context)
  → Output: anonymized records HOẶC rejected records (context destroyed)

STAGE 3: DEDUPLICATION
  → Input: anonymized records
  → Action: hash → MinHash → semantic clustering theo thứ tự
  → Decision: keep canonical record, discard duplicates
  → Output: deduplicated set + dedup_report

STAGE 4: ANOMALY FILTERING
  → Input: deduplicated records
  → Action: structural + content + label anomaly detection
  → Decision: keep / quarantine / reject
  → Output: clean records + anomaly_report

STAGE 5: QUALITY SCORING
  → Input: clean records
  → Action: tính quality_score tổng hợp per record
  → Decision: final accept / reject dựa trên threshold
  → Output: scored records + quality_distribution

STAGE 6: OUTPUT & AUDIT
  → Input: scored records
  → Action: format output, generate audit trail
  → Output: final dataset + full audit report + reconciliation metrics
```

### Bước 8: Output Schema Definition

Định nghĩa schema output dataset sau remediation:

```
REQUIRED FIELDS trong output record:
  □ record_id: unique ID (không phải original PK nếu PK chứa PII)
  □ [content fields]: các fields sau khi đã anonymized
  □ quality_score: 0.0 - 1.0 (tổng hợp từ completeness, consistency, accuracy)
  □ pii_removed: boolean — có PII bị remove không
  □ dedup_cluster_id: UUID của cluster (để trace canonical record)
  □ remediation_version: version của pipeline xử lý
  □ processed_at: timestamp xử lý (UTC)

METADATA (lưu riêng, không trong record):
  □ original_record_hash: để verify không thể reverse-engineer PII
  □ removal_actions: list các PII types đã remove (không log giá trị gốc)
  □ anomaly_flags: list các anomaly types detected

AUDIT TABLE (separate store):
  □ run_id, stage, input_count, output_count, rejected_count, rejection_reasons
  □ Không chứa content gốc — chỉ metrics
```

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/remediation-pipeline-design.md

Cấu trúc output:
1. Executive Summary (scope, sensitivity level, air-gapped needed?)
2. Data Quality Assessment kết quả sơ bộ
3. PII Taxonomy và Detection Strategy
4. Deduplication Strategy (3 tầng)
5. Anomaly Detection Rules
6. Air-Gapped Processing Design (nếu applicable)
7. Remediation Workflow (stage-by-stage)
8. Output Schema Definition
9. Reconciliation Checkpoints
10. Compliance Summary (GDPR/HIPAA/PDPA checklist)
11. Open Questions cho stakeholders
```

---

## Checklist trước khi submit

```
□ PII taxonomy đã liệt kê đủ cho domain cụ thể
□ Air-gapped requirement đã xác định rõ (yes/no + lý do)
□ Dedup threshold đã define với rationale (không để default)
□ Lambda-only output: không có stage nào persist PII intermediate
□ Audit trail design: đủ thông tin compliance nhưng không log PII values
□ Output schema có quality_score, pii_removed, dedup_cluster_id
□ Reconciliation checkpoints tại mỗi stage
□ REQ-ID reference trong design document
□ Compliance checklist (GDPR Article 5, 25 — data minimization, privacy by design)
```
