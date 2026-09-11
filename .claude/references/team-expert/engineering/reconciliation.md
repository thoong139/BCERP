# Engineering - Reconciliation Math & Success Metrics

> **Domain**: Engineering / Data Remediation
> **Last Updated**: 2026-03-22

---

## Reconciliation Math

Đảm bảo data integrity bằng reconciliation checkpoints sau mỗi pipeline run:

```python
class ReconciliationReport:
    def __init__(self, input_stats: dict, output_stats: dict):
        self.input_count = input_stats["row_count"]
        self.output_count = output_stats["row_count"]
        self.removed_duplicates = input_stats["duplicate_count"]
        self.removed_pii = input_stats["pii_record_count"]

    def validate(self) -> dict:
        """Kiểm tra tính nhất quán của pipeline."""
        expected_output = (
            self.input_count
            - self.removed_duplicates
            - self.removed_pii
        )
        # Cho phép sai lệch ≤ 0.1% do edge cases
        tolerance = self.input_count * 0.001
        is_valid = abs(self.output_count - expected_output) <= tolerance

        return {
            "valid": is_valid,
            "input_count": self.input_count,
            "output_count": self.output_count,
            "expected_output": expected_output,
            "delta": abs(self.output_count - expected_output),
            "compression_ratio": f"{(1 - self.output_count / self.input_count) * 100:.1f}%"
        }
```

### Công thức reconciliation

```
expected_output = input_count - removed_duplicates - removed_pii
delta = |output_count - expected_output|
tolerance = input_count × 0.001   (0.1%)

is_valid = delta ≤ tolerance
```

### Ví dụ reconciliation report

```json
{
    "valid": true,
    "input_count": 100000,
    "output_count": 41950,
    "expected_output": 42000,
    "delta": 50,
    "compression_ratio": "58.1%"
}
```

Trong ví dụ trên:
- Input: 100,000 records
- Removed duplicates: 45,000
- Removed PII records: 13,000
- Expected output: 100,000 - 45,000 - 13,000 = 42,000
- Actual output: 41,950
- Delta: 50 records (0.05% < 0.1% tolerance) → VALID

---

## Collecting Pipeline Stats

```python
def collect_pipeline_stats(df_input, df_output) -> tuple[dict, dict]:
    """Thu thập thống kê để tạo reconciliation report."""
    input_stats = {
        "row_count": len(df_input),
        "duplicate_count": df_input.duplicated().sum(),
        "pii_record_count": count_pii_records(df_input),
        "null_rate": df_input.isnull().mean().to_dict(),
    }
    output_stats = {
        "row_count": len(df_output),
        "null_rate": df_output.isnull().mean().to_dict(),
        "schema_valid": validate_output_schema(df_output),
    }
    return input_stats, output_stats


def run_reconciliation(input_stats: dict, output_stats: dict) -> dict:
    """Chạy reconciliation và log kết quả."""
    report = ReconciliationReport(input_stats, output_stats)
    result = report.validate()

    if not result["valid"]:
        raise ValueError(
            f"Reconciliation FAILED: delta={result['delta']} exceeds tolerance. "
            f"Input={result['input_count']}, Output={result['output_count']}, "
            f"Expected={result['expected_output']}"
        )

    return result
```

---

## Audit Trail

Mỗi pipeline run tạo audit trail để compliance review:

```python
import json
from datetime import datetime, timezone

def write_audit_trail(run_id: str, reconciliation_result: dict, output_path: str):
    """Ghi audit trail ra file — không chứa PII, chỉ chứa statistics."""
    audit = {
        "run_id": run_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "reconciliation": reconciliation_result,
        "pipeline_version": "1.0.0",
    }
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(audit, f, indent=2, ensure_ascii=False)
```

Audit trail chứa:
- Run ID và timestamp
- Reconciliation result (counts, delta, compression ratio)
- Pipeline version

Audit trail không chứa:
- Raw data hoặc sample data
- PII hoặc sensitive content
- Intermediate states

---

## Chỉ số Thành công

| Chỉ số | Mục tiêu | Ghi chú |
|--------|----------|---------|
| PII removal completeness | 100% | Zero tolerance — audit fail nếu còn PII |
| Reconciliation accuracy | Delta ≤ 0.1% | Input/output phải khớp sau khi trừ removals |
| Semantic dedup precision | ≥ 95% | Không loại nhầm records khác ý nghĩa |
| Processing throughput | ≥ 10K records/s | Cho batch pipeline |
| Zero data leakage | 0 incidents | Air-gapped + lambda-only |

---

## Xử lý khi Reconciliation Fail

| Nguyên nhân phổ biến | Cách kiểm tra | Hành động |
|---------------------|---------------|-----------|
| Pipeline bỏ sót records | So sánh input IDs vs output IDs | Debug từng stage |
| Duplicate count sai | Re-run duplicate detection độc lập | Calibrate threshold |
| PII count sai | Re-run PII scan độc lập | Kiểm tra PII patterns |
| Edge cases (encoding, null) | Kiểm tra null/malformed records | Thêm exception handling |
| Tolerance quá chặt | Xem xét lại ngưỡng 0.1% với dataset cụ thể | Điều chỉnh có ghi lại lý do |
