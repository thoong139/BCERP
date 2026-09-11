# Engineering - PII Detection & Lambda-Only Output Pattern

> **Domain**: Engineering / Data Remediation
> **Last Updated**: 2026-03-22

---

## Lambda-Only Output Pattern

Chỉ xuất dữ liệu đã transform — intermediate states chứa sensitive data không được persist xuống disk hoặc bất kỳ storage nào:

```python
# Lambda-only: transform → output, không lưu intermediate
def remediation_pipeline(source_path: str, output_path: str):
    """
    Đọc source → transform in-memory → ghi output.
    Intermediate data không được persist.
    """
    for batch in read_batches(source_path, batch_size=1000):
        cleaned = (
            batch
            .pipe(remove_pii)
            .pipe(normalize_text)
            .pipe(deduplicate)
            .pipe(validate_schema)
        )
        append_output(cleaned, output_path)
        del batch, cleaned  # Explicit memory cleanup
```

### Nguyên tắc hoạt động

- Mỗi batch được đọc → transform → ghi output → xóa khỏi memory
- Không có checkpoint files chứa raw hoặc partially-cleaned data
- Output path chỉ chứa dữ liệu đã qua toàn bộ pipeline

### Các bước transform trong pipeline

| Bước | Hàm | Mục đích |
|------|-----|----------|
| 1 | `remove_pii` | Xóa hoặc mask toàn bộ PII fields |
| 2 | `normalize_text` | Chuẩn hóa encoding, whitespace, format |
| 3 | `deduplicate` | Loại bỏ duplicate records |
| 4 | `validate_schema` | Kiểm tra output schema trước khi ghi |

---

## PII Detection Patterns

### Pattern Matching cơ bản

```python
import re

PII_PATTERNS = {
    "email":       r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}",
    "phone_vn":    r"(0|\+84)[3|5|7|8|9][0-9]{8}",
    "phone_intl":  r"\+?[1-9]\d{1,14}",
    "cccd_vn":     r"\b\d{9}|\d{12}\b",
    "credit_card": r"\b(?:\d[ -]?){13,19}\b",
    "ip_address":  r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
}

def detect_pii(text: str) -> dict:
    """Phát hiện PII bằng regex patterns."""
    findings = {}
    for pii_type, pattern in PII_PATTERNS.items():
        matches = re.findall(pattern, text)
        if matches:
            findings[pii_type] = matches
    return findings
```

### NER-based PII Detection

```python
# Dùng spaCy hoặc model NER local — không gọi external API với sensitive data
import spacy

NER_PII_LABELS = {"PERSON", "ORG", "GPE", "LOC", "DATE"}

def detect_pii_ner(text: str, nlp) -> list[dict]:
    """Phát hiện PII bằng Named Entity Recognition."""
    doc = nlp(text)
    return [
        {"text": ent.text, "label": ent.label_, "start": ent.start_char, "end": ent.end_char}
        for ent in doc.ents
        if ent.label_ in NER_PII_LABELS
    ]
```

### PII Removal / Masking

```python
def remove_pii(df):
    """
    Xóa hoặc mask PII trong DataFrame.
    Áp dụng cả pattern matching lẫn column-level rules.
    """
    # Column-level: xóa hoàn toàn các cột PII đã biết
    pii_columns = ["email", "phone", "full_name", "address", "ssn", "dob"]
    df = df.drop(columns=[c for c in pii_columns if c in df.columns])

    # Field-level: mask PII trong text columns
    text_columns = df.select_dtypes(include="object").columns
    for col in text_columns:
        df[col] = df[col].apply(mask_pii_in_text)

    return df


def mask_pii_in_text(text: str) -> str:
    """Thay thế PII bằng placeholder."""
    if not isinstance(text, str):
        return text
    for pii_type, pattern in PII_PATTERNS.items():
        text = re.sub(pattern, f"[{pii_type.upper()}_REDACTED]", text)
    return text
```

---

## Chỉ số PII Removal

| Chỉ số | Mục tiêu | Ghi chú |
|--------|----------|---------|
| PII removal completeness | 100% | Zero tolerance — audit fail nếu còn PII trong output |
| Zero data leakage | 0 incidents | Air-gapped + lambda-only kết hợp |
| False negative rate | 0% | Không được bỏ sót PII đã biết |
