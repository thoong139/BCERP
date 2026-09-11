# `workload_estimator/` — Phase 0 Workload Estimation

> **Trạng thái:** B1 Skeleton (2026-04-20) · chưa implement logic thật
> **Version:** 0.1.0-skeleton
> **ADR refs:** ADR-02 (utility module), ADR-14 (Workload Gate), ADR-15 (Partition Planner), ADR-22 rule 1 (safety floor)
> **Registry role:** NONE
> **Nơi được gọi:** `/wf-fix-bugs` Lane Dispatch (trước khi ISG render)

---

## 1. Mục Đích

Trước khi `/wf-fix-bugs` chạy Phase 1 (Discovery thực sự), cần ước lượng workload để:

1. **Render ISG** với dự đoán thời gian per QD + tổng → user biết cam kết gì trước khi Go.
2. **Trigger Workload Gate** (ADR-14) khi ước lượng vượt ngưỡng (vd > 45 phút) → user phải xác nhận hoặc Partition (chia nhỏ).
3. **Input cho Partition Planner** (ADR-15) — đề xuất Plan A (chia theo module/system) hoặc Plan B (chia theo QD).

Output: `fix-workload.json` tại `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json`.

---

## 2. Model

### 2.1. Input

- `git diff --name-only` (optional — nếu có thì filter scope).
- `preflight-report.md` (optional — nếu có thì lấy file list liên quan).
- `req-registry.json` — số module/feature để biết scope rộng.
- `profile` — quick | standard | deep | exhaustive.
- `scope` — all | system | module.

### 2.2. Công thức

```
workload_per_lane = count_files_in_scope * avg_probe_time_per_file[dim] * probes_per_dim[dim]
workload_total = Σ workload_per_lane[dim ∈ selected_dims]
```

**Heuristic bảng** (được tune qua B4 empirical data):

| Dimension | Probes per dim | Avg time per file (giây) |
|-----------|----------------|--------------------------|
| QD1 (Functional) | 3 | 1.5 |
| QD2 (Business) | 2 | 2.0 |
| QD3 (Security) | 2 | 3.5 |
| QD4 (Performance) | 2 | 2.5 |
| QD5 (UX/A11y) | 3 | 2.0 |
| QD6 (Data) | 2 | 2.5 |
| QD7 (Compat) | 1 | 1.5 |
| QD8 (Observability) | 2 | 2.0 |

- Profile `quick` → x 0.5 (chỉ top file).
- Profile `standard` → x 1.0.
- Profile `deep` → x 1.5 (thêm runtime probe).
- Profile `exhaustive` → x 2.5 (full E2E flow).

---

## 3. Workload Gate (ADR-14)

Sau khi estimate:

```
IF estimated_minutes > GATE_THRESHOLD (default 45 min):
    → Render user choice:
        [1] Go as-is (chấp nhận chờ)
        [2] Partition Plan A (chia theo module/system)
        [3] Partition Plan B (chia theo QD)
        [4] Reduce scope (quay về ISG chọn lại)
    → Block execution tới khi user confirm (CORE-027 CDG).
```

Default threshold 45 phút — có thể đọc từ env `WF_FIX_BUGS_WORKLOAD_THRESHOLD_MIN`.

---

## 4. Partition Planner (ADR-15) — chỉ khi user chọn [2] hoặc [3]

**Plan A — Split by scope:**

- Detect module/system boundary từ `req-registry.json`.
- Chia files vào các batch ≈ GATE_THRESHOLD / 2 (vd 22 phút).
- User chọn batch nào chạy trước; các batch còn lại pending.

**Plan B — Split by dimension:**

- Giữ scope không đổi.
- Chạy từng QD lane tuần tự thay vì song song → total time không đổi nhưng peak memory giảm.

Trả sub-menu cho user tại ISG → user chọn partition nào → orchestrator lưu vào checkpoint + tiếp tục.

---

## 5. Output Schema

[`schemas/fix-workload.schema.json`](schemas/fix-workload.schema.json):

```json
{
  "$schema": "fix-workload-v1",
  "workload_id": "WL-20260420-001",
  "estimated_at": "2026-04-20T10:30:00+07:00",
  "profile": "standard",
  "scope": {"type": "module", "name": "sales-order"},
  "file_count": 45,
  "lanes": [
    {
      "dim": "QD1",
      "probes_count": 3,
      "files_covered": 45,
      "estimated_sec": 202
    },
    {
      "dim": "QD2",
      "probes_count": 2,
      "files_covered": 45,
      "estimated_sec": 180
    }
  ],
  "total_estimated_sec": 382,
  "gate_threshold_sec": 2700,
  "gate_triggered": false,
  "partition_plans": []
}
```

---

## 6. API

### 6.1. CLI

```bash
python3 estimator.py analyze \
    --session-dir <path> \
    --profile standard \
    --scope module:sales-order
```

### 6.2. Python import

```python
from workload_estimator import estimate

workload = estimate(
    session_dir=Path("..."),
    profile="standard",
    scope={"type": "module", "name": "sales-order"},
    selected_dims=["QD1", "QD2", "QD5"],
)
if workload.gate_triggered:
    # Trigger Workload Gate UI
    ...
```

---

## 7. Files

| File | Vai trò |
|------|---------|
| `README.md` | (file này) |
| `estimator.py` | Core logic — analyze, estimate, partition plan |
| `schemas/fix-workload.schema.json` | JSON Schema cho output |
| `_contract.json` | Module contract |

---

## 8. Safety

- **ADR-22 rule 1 (safety floor):** Estimator KHÔNG được tự drop QD1/QD2/QD5 dù workload lớn — việc skip phải do ISG + user confirm (CDG).
- **Output path contract:** `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json` — xem CORE §4b.
- **Atomic write:** tmp + rename.

---

## 9. Testing Plan

- **B1:** skeleton — NotImplementedError.
- **B3:** Wire với `/wf-fix-bugs` Lane Dispatch, verify ISG render đúng estimated_minutes.
- **B4:** Fixture:
  - `small-scope.json` (5 file) → expect gate không trigger.
  - `large-scope.json` (500 file, profile=exhaustive) → expect gate triggered + Plan A + B đề xuất.

---

## 10. Tham Chiếu

- ADR-14 / ADR-15 / ADR-22 rule 1: [`07-tradeoffs-adr.md`](../../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- Output path: `.claude/rules/00-core.md` §4b
