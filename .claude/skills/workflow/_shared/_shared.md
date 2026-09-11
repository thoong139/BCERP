# Shared Protocol — Template Strip + Atomic Write

> Dùng bởi tất cả linear workflow skills khi ghi output files.

## 1. Template Metadata Stripping

Trước khi ghi digest/output file, xoá metadata fields:

```bash
jq 'del(._template_notes, ._comments, ._examples, ._placeholder, ._description)' input.json > output.json
```

Applied cho: mọi digest file trong Cross-Skill Output Path Contract (§4b CORE rules),
mọi JSON output từ `_shared/` modules.

**Quy tắc:** Templates có thể chứa `_template_notes` để hướng dẫn điền. Trước khi ghi
output cuối cùng (file consumed bởi downstream skill), PHẢI strip các metadata fields
này để không "nhiễu" context của downstream consumer.

## 2. Atomic Write Pattern

```bash
# Write to temp, validate, then atomic rename
jq '.' data.json > data.json.tmp && mv data.json.tmp data.json
```

- tmp file trên cùng filesystem → `mv` atomic (POSIX)
- Nếu jq fail → tmp không move → data cũ nguyên vẹn
- Downstream đọc data.json → luôn thấy state consistent

**Python equivalent:**

```python
import os, tempfile, json

tmp_fd, tmp_name = tempfile.mkstemp(
    prefix=f".{filename}.",
    suffix=".tmp",
    dir=str(parent_dir),
)
try:
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp_name, target_path)
except Exception:
    os.unlink(tmp_name)
    raise
```

## 3. Import Convention

Linear skills import _shared modules:

```bash
# Trong SKILL.md inline script
SHARED_DIR="$(cd "$(dirname "$0")/../../workflow/_shared" && pwd)"
python3 "$SHARED_DIR/profiles/profile_resolver.py" --skill=wf-analyze-requirements --profile=standard
```

```python
# Trong Python
import sys
sys.path.insert(0, ".claude/skills/workflow/_shared")
from profiles import resolve_profile, validate_safety_floor
from lane import dispatch_lanes, LaneConfig
from partition import plan_partitions, check_workload_gate
from aggregate import aggregate_lane_signals, dedup_by_id
from cdg import create_cdg_token, check_anti_loop
from cache import get_cached, set_cached, compute_content_hash
```

## 4. Module Map

| Module | Import | Mục đích chính |
|--------|--------|----------------|
| `profiles` | `from profiles import resolve_profile` | Profile 3 cấp (quick/standard/deep) |
| `lane` | `from lane import dispatch_lanes, LaneConfig` | Generic lane dispatch |
| `partition` | `from partition import plan_partitions, check_workload_gate` | Partition + workload gate |
| `aggregate` | `from aggregate import aggregate_lane_signals` | Signal aggregation + dedup |
| `cdg` | `from cdg import create_cdg_token, check_anti_loop` | CDG handoff + anti-loop |
| `cache` | `from cache import get_cached, set_cached` | Content-hash cache (2-tier) |
