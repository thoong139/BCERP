# Cache Types — 2-Tier Cache cho Linear Skills

## Session Tier (in-memory)

- **Storage:** Python dict trong process memory
- **Lifetime:** Chỉ tồn tại trong 1 Claude Code session
- **Speed:** Nhanh nhất — dict lookup O(1)
- **Use case:** Caching intermediate results trong 1 skill run
- **Limitations:** Mất khi session kết thúc; không share giữa processes

## Project Tier (disk-based)

- **Storage:** `.mc-data-cache/linear/{skill_name}/{hash}.json`
- **Lifetime:** TTL 14 ngày mặc định
- **Speed:** Chậm hơn session tier — file I/O
- **Use case:** Caching kết quả phân tích giữ các lần chạy skill
- **Cleanup:** Tự động xoá khi expired; manual qua `invalidate_cache()`

## Lookup Order

```
get_cached() → Session tier → Project tier → Cache miss
```

## Cache Key Composition

```
content_hash = sha256(file1_content | file2_content | ...)
cache_key = sha256(content_hash + ":" + output_key)[:16]
```

## Import Convention

```python
from cache import get_cached, set_cached, compute_content_hash

# Compute hash từ input files
content_hash = compute_content_hash(
    Path(".mc-data/docs/_meta/req-registry.json"),
    Path(".mc-data/docs/phase1-business/dept-sales.md"),
)

# Tra cache
cached = get_cached("wf-analyze-requirements", content_hash, "dept-analysis")
if cached:
    # Dùng cached data
    pass
else:
    # Chạy analysis, ghi cache
    result = analyze_department(...)
    set_cached("wf-analyze-requirements", content_hash, "dept-analysis", result)
```
