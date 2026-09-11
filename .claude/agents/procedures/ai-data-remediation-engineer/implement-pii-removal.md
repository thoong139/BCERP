# Playbook: Implement PII Removal

> **Type**: Agent Skill Playbook
> **Agent**: ai-data-remediation-engineer
> **Triggered by**: Khi cần implement PII removal/anonymization trong dataset
> **Output**: PII removal implementation code + audit report

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature` khi feature liên quan đến PII handling
- Khi cần implement cụ thể code xử lý PII trong dataset
- Khi cần thiết lập air-gapped processing environment cho sensitive data

---

## Procedure

### Bước 1: Đọc design và xác định requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (remediation pipeline design), PHASE5 (tasks)

Cần đọc:
□ .mc-data/docs/phase3-architecture/remediation-pipeline-design.md
□ PII taxonomy đã define trong design
□ Anonymization techniques đã chọn per PII type
□ Air-gapped requirement (yes/no)
□ Compliance framework áp dụng (GDPR / HIPAA / PDPA / internal)
□ REQ-IDs liên quan

Không implement trước khi đọc design — tránh chọn wrong technique cho wrong context.
```

### Bước 2: PII Taxonomy — Direct Identifiers

Implement detection cho từng loại direct identifier:

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Regex patterns cho Vietnamese + international formats
import re
from typing import NamedTuple

class PiiMatch(NamedTuple):
    entity_type: str; value: str; start: int; end: int

# Direct identifier patterns
EMAIL_PATTERN = re.compile(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Z|a-z]{2,}\b')
PHONE_VN_PATTERN = re.compile(r'(?:(?:\+|00)84|0)(?:3[2-9]|5[6-9]|7[0|6-9]|8[0-6|8-9]|9[0-4|6-9])\d{7}\b')
VIET_ID_PATTERN = re.compile(r'\b(?:CMND|CCCD|số:?\s*)?\d{9}(?:\d{3})?\b')
CREDIT_CARD_PATTERN = re.compile(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b')
SSN_PATTERN = re.compile(r'\b\d{3}-\d{2}-\d{4}\b')
IP_PATTERN = re.compile(r'\b(?:25[0-5]|2[0-4]\d|[01]?\d\d?)(?:\.(?:25[0-5]|2[0-4]\d|[01]?\d\d?)){3}\b')
```

### Bước 3: PII Taxonomy — Quasi-Identifiers

```python
# Quasi-identifiers: generalize thay vì remove để giữ utility cho ML
# Age → nhóm 10 năm (under_18, 18-29, 30-39, ...)
# Zipcode → prefix 2-3 ký tự + wildcard
# Occupation → industry group mapping
def generalize_age(age: int) -> str:
    brackets = [(18,"under_18"),(30,"18-29"),(40,"30-39"),(50,"40-49"),(60,"50-59")]
    return next((label for threshold, label in brackets if age < threshold), "60_plus")

def generalize_zipcode(zipcode: str, precision: int = 3) -> str:
    return zipcode[:precision] + "*" * (len(zipcode) - precision)
```

### Bước 4: Detection Methods — NER Model (Offline)

```python
# NER model offline (air-gapped) — bổ sung regex cho free text detection
import spacy

def load_ner_model_offline(model_path: str):
    """Load từ local path, không download — đảm bảo air-gapped."""
    if not Path(model_path).exists():
        raise FileNotFoundError(f"NER model không tìm thấy: {model_path}")
    return spacy.load(model_path)

def detect_pii_with_ner(text: str, nlp_model) -> list[PiiMatch]:
    """Extract PERSON, PHONE từ NER + contextual patterns (tên:, sdt:, email:)"""
    doc = nlp_model(text)
    return [PiiMatch("PERSON_NAME", e.text, e.start_char, e.end_char)
            for e in doc.ents if e.label_ in ("PERSON", "PER")]
```

### Bước 5: Anonymization Techniques

Implement từng technique cho từng PII type:

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# WHY: Mỗi technique có trade-off khác nhau giữa privacy và utility.
# Chọn technique phù hợp với mục đích sử dụng data.

import hashlib
import secrets

# MASKING: thay thế bằng placeholder — giữ context, mất value
def mask_pii(text: str, entity_type: str) -> str:
    """Dùng cho: email, phone, ID — khi chỉ cần biết 'có PII ở đây'."""
    masks = {
        "EMAIL": "[EMAIL_REMOVED]",
        "PHONE": "[PHONE_REMOVED]",
        "PERSON_NAME": "[NAME_REMOVED]",
        "NATIONAL_ID": "[ID_REMOVED]",
        "CREDIT_CARD": "[CARD_REMOVED]",
        "IP_ADDRESS": "[IP_REMOVED]",
        "SSN": "[SSN_REMOVED]",
    }
    return masks.get(entity_type, "[PII_REMOVED]")

# PSEUDONYMIZATION: thay thế bằng consistent fake value — giữ được referential integrity
def pseudonymize_pii(value: str, entity_type: str, salt: str) -> str:
    """
    WHY: Pseudonymization cho phép join records cùng entity mà không lộ value thực.
    Salt phải là secret và rotate định kỳ — không hardcode.
    Dùng cho: user_id, customer_id — khi cần track cùng user qua records.
    """
    hashed = hashlib.sha256(f"{salt}:{entity_type}:{value}".encode()).hexdigest()
    prefix_map = {
        "PERSON_NAME": "USER",
        "EMAIL": "MAIL",
        "PHONE": "PHONE",
    }
    prefix = prefix_map.get(entity_type, "PII")
    return f"{prefix}_{hashed[:12].upper()}"

# GENERALIZATION: giảm precision thay vì xóa — giữ utility thống kê
def generalize_value(value: str, entity_type: str) -> str:
    """
    WHY: Generalization giữ được phân phối thống kê — quan trọng cho ML training.
    Dùng cho: age → age group, zipcode → region, date → year/month.
    """
    # Implement theo entity_type (age, zipcode, date, etc.)
    pass

# SUPPRESSION: xóa hoàn toàn record hoặc field
def should_suppress_record(pii_entities: list[PiiMatch], policy: dict) -> tuple[bool, str]:
    """
    WHY: Một số records quá nhiều PII không thể anonymize mà giữ được utility.
    Ví dụ: medical note chứa họ tên + DOB + diagnosis → suppress toàn record.
    """
    high_risk_types = {"NATIONAL_ID", "SSN", "CREDIT_CARD", "BIOMETRIC"}
    high_risk_count = sum(1 for e in pii_entities if e.entity_type in high_risk_types)
    if high_risk_count >= policy.get("max_high_risk_entities", 1):
        return True, f"Suppressed: {high_risk_count} high-risk PII entities"
    return False, ""
```

### Bước 6: Re-identification Risk Assessment

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# WHY: Sau anonymization, cần verify risk thực sự đã giảm.
# K-anonymity là baseline minimum — L-diversity cho sensitive attributes.

def check_k_anonymity(df, quasi_identifier_columns: list, k: int = 5) -> dict:
    """
    WHY: K-anonymity đảm bảo mỗi record không thể phân biệt với ít nhất k-1 records khác
    trên tập quasi-identifiers. K=5 là minimum thực tế cho hầu hết use cases.

    Trả về: {'violating_groups': int, 'min_group_size': int, 'k_satisfied': bool}
    """
    group_counts = df.groupby(quasi_identifier_columns).size()
    violating = group_counts[group_counts < k]
    return {
        "violating_groups": len(violating),
        "min_group_size": int(group_counts.min()),
        "k_satisfied": len(violating) == 0,
        "k_value_used": k,
    }

# Nếu k-anonymity không satisfied → có thể cần:
# 1. Generalize thêm (zipcode 5 digit → 3 digit)
# 2. Suppress nhóm nhỏ (< k records trong nhóm)
# 3. Tăng k threshold nếu domain yêu cầu cao hơn
```

### Bước 7: K-Anonymity Verification

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Verify k-anonymity đạt yêu cầu trước khi release dataset

def verify_and_remediate_k_anonymity(df, quasi_id_cols: list, k: int = 5):
    """
    WHY: Nếu có groups < k records, cần remediate trước khi release.
    Thứ tự ưu tiên: generalize thêm → suppress nhóm nhỏ.
    """
    result = check_k_anonymity(df, quasi_id_cols, k)

    if not result["k_satisfied"]:
        # Option 1: Suppress records trong nhóm quá nhỏ
        group_sizes = df.groupby(quasi_id_cols).transform("size")
        df_suppressed = df[group_sizes >= k].copy()
        suppressed_count = len(df) - len(df_suppressed)

        # Log suppressed records count (không log content)
        print(f"K-anonymity remediation: suppressed {suppressed_count} records "
              f"từ {result['violating_groups']} groups nhỏ hơn k={k}")
        return df_suppressed, suppressed_count
    return df, 0
```

### Bước 8: Air-Gapped Processing Setup

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# WHY: Sensitive data không được rời môi trường isolated trong quá trình xử lý.
# Mọi inference (NER, embedding, classification) phải chạy local.

import os
import subprocess

def verify_air_gapped_environment():
    """
    Kiểm tra môi trường đáp ứng air-gapped requirements.
    Chạy trước khi bắt đầu xử lý sensitive data.
    """
    checks = {}

    # Check 1: Không có outbound network (kiểm tra bằng attempt kết nối)
    try:
        import socket
        socket.setdefaulttimeout(2)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 80))
        checks["network_isolated"] = False  # Có network → FAIL
    except (socket.error, OSError):
        checks["network_isolated"] = True  # Không có network → PASS

    # Check 2: Model files tồn tại local
    required_models = [
        os.environ.get("NER_MODEL_PATH", ""),
        os.environ.get("EMBEDDING_MODEL_PATH", ""),
    ]
    checks["models_available"] = all(
        os.path.exists(p) for p in required_models if p
    )

    # Check 3: Không có cloud credentials active (tránh accidental upload)
    checks["no_cloud_credentials"] = not any([
        os.environ.get("AWS_ACCESS_KEY_ID"),
        os.environ.get("AZURE_CLIENT_SECRET"),
        os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
    ])

    all_pass = all(checks.values())
    if not all_pass:
        raise EnvironmentError(
            f"Air-gapped verification FAILED: {checks}. "
            "Không được xử lý sensitive data trong môi trường này."
        )
    return checks

# Lambda-only output: không persist intermediate
def process_record_lambda(raw_record: dict, ner_model, salt: str) -> dict | None:
    """
    WHY: Lambda-only — process in memory, không write intermediate to disk.
    Nếu pipeline crash, không có PII nào bị persist trên storage.
    """
    # Detect PII
    pii_entities = detect_all_pii(raw_record, ner_model)

    # Check nếu nên suppress toàn record
    should_suppress, reason = should_suppress_record(pii_entities, policy={})
    if should_suppress:
        # Chỉ log metadata, không log content gốc
        log_suppression(record_id=raw_record.get("id"), reason=reason)
        return None

    # Anonymize
    clean_record = anonymize_record(raw_record, pii_entities, salt)

    # Không return intermediate — chỉ return final clean record
    return clean_record
```

### Bước 9: Audit Trail of Removals

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# WHY: Audit trail cần đủ thông tin để compliance report mà không expose PII.
# KHÔNG log giá trị PII gốc — chỉ log metadata về removal actions.

from datetime import datetime, timezone
import json

def create_removal_audit_entry(
    record_id: str,
    pii_types_removed: list[str],  # Chỉ types, không values
    anonymization_techniques: list[str],
    run_id: str,
) -> dict:
    """
    WHY: GDPR Article 30 yêu cầu record of processing activities.
    Audit trail phải có đủ để chứng minh compliance, không chứa PII gốc.
    """
    return {
        "audit_id": f"AUDIT-{run_id}-{record_id}",
        "record_id": record_id,
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "pii_types_removed": sorted(pii_types_removed),  # e.g., ["EMAIL", "PHONE"]
        "anonymization_techniques": sorted(set(anonymization_techniques)),
        "pii_count_removed": len(pii_types_removed),
        # KHÔNG include: original values, position trong text nếu context sensitive
    }

def write_audit_trail(audit_entries: list[dict], output_path: str):
    """Ghi audit trail vào separate store — không cùng file với clean data."""
    with open(output_path, "w", encoding="utf-8") as f:
        for entry in audit_entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
```

### Bước 10: Output

```
Cấu trúc output:
  src/
  ├── pii_removal/
  │   ├── __init__.py
  │   ├── detectors.py          # Regex + NER detection
  │   ├── anonymizers.py        # Masking, pseudonymization, generalization
  │   ├── k_anonymity.py        # K-anonymity check + remediation
  │   ├── air_gapped.py         # Air-gapped setup + lambda-only processor
  │   └── audit.py              # Audit trail creation
  ├── tests/
  │   ├── test_detectors.py
  │   ├── test_anonymizers.py
  │   └── test_k_anonymity.py
  └── run_pii_removal.py        # Entry point

Ghi documentation (inline code comment + README):
  □ Mô tả từng technique đã chọn và lý do (WHY)
  □ Environment variables cần set (không hardcode)
  □ Cách verify air-gapped environment
  □ Cách rotate salt cho pseudonymization
```

---

## Checklist trước khi submit

```
□ REQ-ID reference trong tất cả code files
□ Không có hardcoded secrets, salt values, hoặc credentials
□ Air-gapped verification chạy trước khi process sensitive data
□ Lambda-only: không có intermediate PII persist trên disk
□ Audit trail: log PII types removed, không log values gốc
□ K-anonymity verification với k đã define trong design
□ Unit tests: test từng regex pattern, test anonymization function
□ Re-identification risk assessment included
□ Contextual PII patterns (không chỉ regex standalone)
□ NER model path từ environment variable — không hardcode
□ Test với edge cases: empty string, null, mixed language text
```
