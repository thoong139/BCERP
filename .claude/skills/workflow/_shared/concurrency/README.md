# `concurrency/` — 3-Tier Token Bucket + Backpressure

> **Trạng thái:** B1 Skeleton (2026-04-20) · chưa implement logic thật
> **Version:** 0.1.0-skeleton
> **ADR refs:** ADR-02 (utility module), ADR-17 (concurrency model), ADR-22 rule 3 (token bucket defaults)
> **Registry role:** NONE
> **Nơi được gọi:** `/wf-fix-bugs` Lane Dispatch (điều phối probe song song), `/wf-fix-execute` (điều phối fix batches)

---

## 1. Mục Đích

Module `concurrency/` quản lý **song song hóa có kiểm soát** trong `wf-fix-*` stack, tuân thủ CORE-025 (song song an toàn):

1. **Giới hạn resource** — tránh overloading local machine (CPU, mem, file descriptor).
2. **Giới hạn API rate** — tránh trigger rate limit của external services (LSP, browser driver, test runner).
3. **Cân bằng fairness** — không để 1 lane (vd QD3 SAST) chiếm toàn bộ budget, làm đói các lane khác.
4. **Backpressure** — khi downstream (Signal Bus, issue-registry) quá tải → producer phải chờ, không drop work.

---

## 2. 3-Tier Token Bucket (ADR-22 rule 3)

Mặc định hardcoded trong `token_bucket.py`:

| Tier | Bucket size | Refill rate | Scope |
|------|-------------|-------------|-------|
| **Global** | 12 | 12 tokens / 60s | Tổng số probe đang chạy đồng thời trên toàn session |
| **Inter-lane** | 4 | 4 tokens / 60s | Số probe cùng 1 lane (wf-fix-functional, ...) chạy song song |
| **Intra-probe** | 6 | 6 tokens / 60s | Số file đang scan song song trong 1 probe |

**Hành vi:**

- Mỗi request thực thi phải acquire token từ **cả 3 tier** (global + inter-lane + intra-probe). Nếu bất kỳ tier nào cạn token → chờ.
- Token được refill theo thời gian (token-bucket algorithm cổ điển): `tokens_available = min(capacity, tokens_available + elapsed * refill_rate)`.
- Khi bị throttle → producer call `await bucket.acquire(n=1, timeout_ms=30000)`.

**Tại sao 12 / 4 / 6?**

- **12 global:** Cân bằng throughput vs OOM — test trên 16GB RAM machine với nodejs/java probe nặng.
- **4 inter-lane:** Giữ fairness 3 lane (QD1, QD2, QD5) cùng chạy — mỗi lane max 4/12 ≈ 33%.
- **6 intra-probe:** Probe SAST có thể scan 6 file song song; lớn hơn sẽ bottleneck ở LSP server.

> **Không được override** những giá trị này bằng `--max-concurrency=N` flag (ADR-22 rule 3 — non-negotiable).
> Nếu user cần tune → phải sửa code trong `concurrency/token_bucket.py` + thêm comment ADR justification.

---

## 3. Backpressure

Khi Signal Bus đang ghi `issue-registry.json` (atomic write có lock ~50ms), các probe đang emit Signal phải pause.

`backpressure.py` expose 2 primitive:

- `SemaphoreBackpressure(max_inflight)` — chặn producer khi có ≥N operation đang chờ flush.
- `AdaptiveBackpressure(registry_path)` — tự đo latency của last `SignalBus.ingest()` call → nếu > threshold → pause producer exponentially.

---

## 4. API

### 4.1. CLI (testing only)

```bash
python3 token_bucket.py stress --global=12 --lane=4 --intra=6 --duration=60
```

### 4.2. Python import

```python
from concurrency import TokenBucket3Tier, AdaptiveBackpressure

tokens = TokenBucket3Tier(global_cap=12, lane_cap=4, intra_cap=6)

async def run_probe(lane_id, probe_id, file_path):
    async with tokens.acquire(lane_id=lane_id, probe_id=probe_id):
        await execute_probe(file_path)
```

---

## 5. Files

| File | Vai trò |
|------|---------|
| `README.md` | (file này) |
| `token_bucket.py` | Core — TokenBucket3Tier class |
| `backpressure.py` | SemaphoreBackpressure + AdaptiveBackpressure |
| `_contract.json` | Module contract |

---

## 6. Safety

Module concurrency là **cổng gác resource**. Không được:

- Drop operation khi bucket cạn → phải block hoặc raise `TimeoutError` cho caller.
- Cho phép bypass (vd `--force-no-throttle`) — ADR-22 rule 3 cấm tuyệt đối.
- Log token state vào stdout ở production run — chỉ log khi `--debug-concurrency`.

---

## 7. Testing Plan

- **B1 (phiên này):** skeleton — raise NotImplementedError.
- **B3:** Wire với lane wf-fix-functional + wf-fix-business, verify 3-tier enforcement.
- **B4:** Stress test: 20 probe đồng thời → đo throughput + tail latency, verify không OOM.

---

## 8. Tham Chiếu

- ADR-02 / ADR-17 / ADR-22 rule 3: [`07-tradeoffs-adr.md`](../../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- CORE-025: `.claude/rules/00-core.md` §0 Priority Order
