# `scan_cache/` — Content-Addressable Probe Result Cache

> **Trạng thái:** B1 Skeleton (2026-04-20) · chưa implement logic thật
> **Version:** 0.1.0-skeleton
> **ADR refs:** ADR-02 (utility module), ADR-19 (scan cache), ADR-22 rule 6 (QD3 never cached)
> **Registry role:** NONE
> **Nơi được gọi:** `/wf-fix-bugs` Lane Dispatch (opt-in qua flag `--use-cache`)

---

## 1. Mục Đích

Probe scan có thể rất đắt (LSP invoke, parser bootstrap, E2E driver). `scan_cache/` lưu kết quả probe × file × version để lần run kế tiếp skip nếu:

1. **Probe version** giống hệt,
2. **File content hash** giống hệt (sha256 toàn file),
3. **Entry còn trong TTL** (14 ngày).

Tiết kiệm 30-60% thời gian scan cho run thứ 2 trở đi khi codebase ít thay đổi.

---

## 2. Fingerprint (Cache Key)

```
fingerprint = sha256(
    probe_id + "|" +
    probe_version + "|" +
    file_path + "|" +
    sha256(file_content) + "|" +
    config_hash (optional)
)
```

- `probe_id` — vd `P-QD1-service-logic-check`.
- `probe_version` — bump mỗi lần probe thay đổi behavior → invalidate toàn bộ entry cũ của probe đó.
- `file_path` — path tương đối dự án (normalized).
- `file_content` — sha256 của file raw bytes.
- `config_hash` — optional, nếu probe phụ thuộc config (vd tsconfig.json) → hash thêm để invalidate khi config đổi.

**Tại sao dùng sha256 toàn file thay vì mtime?**
Mtime không đáng tin khi checkout git hoặc copy file. Sha256 chính xác tuyệt đối, cost ~10ms cho file 100KB — chấp nhận được so với cost re-scan.

---

## 3. Cache Entry Schema

Lưu tại `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json`:

```json
{
  "$schema": "cache-entry-v1",
  "fingerprint": "sha256(...)",
  "probe_id": "P-QD1-service-logic-check",
  "probe_version": "0.1.0",
  "file_path": "src/features/order/service.ts",
  "file_content_sha": "abc123...",
  "cached_at": "2026-04-20T10:35:00+07:00",
  "ttl_expires_at": "2026-05-04T10:35:00+07:00",
  "signals_emitted": [
    {
      "$schema": "signal-v2",
      "probe_id": "P-QD1-service-logic-check",
      "...": "..."
    }
  ],
  "metadata": {
    "elapsed_ms": 125,
    "probe_exit_code": 0
  }
}
```

Đầy đủ schema: [`schemas/cache-entry.schema.json`](schemas/cache-entry.schema.json).

---

## 4. ADR-22 Rule 6: QD3 Never Cached

**Probe ∈ dimension QD3 (Security/Privacy) KHÔNG được cache.** Lý do:

- Vulnerability DB được update hàng ngày (CVE, Snyk, etc.).
- Cùng code nhưng hôm nay có thể có lỗ hổng mới được công bố.
- Cache-hit có thể tạo ra cảm giác an toàn sai lệch → rủi ro nghiêm trọng.

Enforce tại `cache_store.py:set()`:

```python
if signal.dimension_id == "QD3":
    raise ValueError("ADR-22 rule 6: QD3 never cached")
```

---

## 5. TTL & Eviction

- **TTL mặc định:** 14 ngày kể từ `cached_at`.
- **Eviction policy:** Lazy — khi `cache_lookup.py` check entry expired → xóa file + miss.
- **Manual clear:** `python3 cache_store.py clear --older-than=7d` để prune.
- **Total size cap:** Không giới hạn cứng — expect < 500MB cho dự án typical (10k file × 50KB entry avg).

---

## 6. API

### 6.1. CLI

```bash
# Check cache hit
python3 cache_lookup.py \
    --probe-id=P-QD1-foo \
    --probe-version=0.1.0 \
    --file=src/a.ts

# Store result
python3 cache_store.py set \
    --probe-id=... --probe-version=... --file=... \
    --signals-file=signals.json

# Prune
python3 cache_store.py clear --older-than=14d
```

### 6.2. Python import

```python
from scan_cache import ScanCache

cache = ScanCache(cache_root=Path(".mc-data/cache/wf-fix-bugs/probes/"))

# Check before running probe
cached = cache.get(probe_id="P-QD1-...", probe_version="0.1.0", file_path="src/a.ts")
if cached is not None:
    return cached.signals_emitted  # cache hit — skip scan

# Run probe, then cache
signals = run_probe(...)
cache.set(probe_id=..., probe_version=..., file_path=..., signals=signals)
```

---

## 7. Files

| File | Vai trò |
|------|---------|
| `README.md` | (file này) |
| `fingerprint.py` | Compute cache key (sha256 chaining) |
| `cache_lookup.py` | Read entry, check TTL, validate content hash |
| `cache_store.py` | Write entry, enforce ADR-22 rule 6, prune |
| `schemas/cache-entry.schema.json` | JSON Schema cho cache entry |
| `_contract.json` | Module contract |

---

## 8. Safety

- **Rule 6 (QD3 no-cache):** `cache_store.py:set()` raise ValueError.
- **Content hash verify:** `cache_lookup.py` re-compute file sha → nếu khác entry.file_content_sha → treat as miss + xóa entry (file đã thay đổi, entry stale).
- **Atomic write:** tmp + rename, tránh reader đọc entry dở.
- **Opt-in only:** `/wf-fix-bugs` Lane Dispatch chỉ dùng cache khi có flag `--use-cache`, default OFF.

---

## 9. Testing Plan

- **B1:** skeleton — NotImplementedError.
- **B3:** `wf-fix-functional` chạy với `--use-cache` 2 lần → second run fast.
- **B4:** Fixture:
  - `qd3-should-not-cache.signal.json` → expect exception.
  - `file-changed-invalidate.test` → modify file → cache miss.
  - `ttl-expired.test` → touch entry cached_at = 15 ngày trước → cache miss.

---

## 10. Tham Chiếu

- ADR-02 / ADR-19 / ADR-22 rule 6: [`07-tradeoffs-adr.md`](../../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- Output path: `.claude/rules/00-core.md` §4b bảng cross-skill paths
