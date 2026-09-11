# Testing - Performance Testing & Benchmarks

> **Domain**: Testing / Performance Engineering
> **Last Updated**: 2026-03-15
> **Nguồn**: Google Web Vitals, k6 docs, DORA metrics, AWS Well-Architected Framework

---

## 1. Core Web Vitals — Targets

Tiêu chuẩn Google đánh giá trải nghiệm người dùng trên web. Ảnh hưởng trực tiếp đến SEO ranking.

| Metric | Mô tả | Good | Needs Improvement | Poor |
|--------|-------|------|-------------------|------|
| LCP (Largest Contentful Paint) | Thời gian render phần tử lớn nhất | ≤ 2.5s | 2.5s – 4.0s | > 4.0s |
| FID (First Input Delay) | Độ trễ phản hồi tương tác đầu tiên | ≤ 100ms | 100ms – 300ms | > 300ms |
| INP (Interaction to Next Paint) | Thay thế FID từ 2024 — đo mọi tương tác | ≤ 200ms | 200ms – 500ms | > 500ms |
| CLS (Cumulative Layout Shift) | Độ ổn định layout (không giật) | ≤ 0.1 | 0.1 – 0.25 | > 0.25 |
| TTFB (Time to First Byte) | Thời gian nhận byte đầu tiên từ server | ≤ 800ms | 800ms – 1800ms | > 1800ms |
| FCP (First Contentful Paint) | Thời gian hiển thị nội dung đầu tiên | ≤ 1.8s | 1.8s – 3.0s | > 3.0s |
| TBT (Total Blocking Time) | Tổng thời gian main thread bị block | ≤ 200ms | 200ms – 600ms | > 600ms |

**Công cụ đo:** Lighthouse (lab), Chrome UX Report (field), PageSpeed Insights, WebPageTest.

---

## 2. API Performance SLA Reference

| Endpoint Type | P50 | P95 | P99 | Max |
|---------------|-----|-----|-----|-----|
| CRUD đơn giản (read/write 1 record) | < 50ms | < 100ms | < 200ms | < 500ms |
| List/Search (có pagination) | < 100ms | < 300ms | < 500ms | < 1000ms |
| Report/Aggregation (phức tạp) | < 500ms | < 2000ms | < 5000ms | < 10s |
| File Upload (< 10MB) | < 1000ms | < 3000ms | < 5000ms | < 30s |
| File Download (streaming) | TTFB < 200ms | TTFB < 500ms | — | — |
| Webhook delivery | < 200ms | < 500ms | < 1000ms | < 2000ms |
| Authentication (login/token) | < 100ms | < 300ms | < 500ms | < 1000ms |
| Real-time (WebSocket, SSE) | < 50ms | < 100ms | — | — |

**Định nghĩa percentile:**
- P50: 50% request hoàn thành trong thời gian này (median)
- P95: 95% request hoàn thành — standard SLA measurement
- P99: 99% request hoàn thành — tail latency, ảnh hưởng outlier users

---

## 3. Load Testing Methodology

### 3a. Load Profiles

```
RAMP-UP (Kiểm tra khởi động dần dần)
VUs │           ________
    │          /
    │         /
    │        /
    └────────────────── Time
    Mục tiêu: Tìm breaking point theo cách có kiểm soát

STEADY STATE (Kiểm tra tải ổn định)
VUs │    _________________
    │   /                 \
    │  /                   \
    └──────────────────────── Time
    Mục tiêu: Verify SLA ở tải bình thường

SPIKE (Đột biến tải)
VUs │         |||
    │         |||
    │    _____|‾‾|_____
    └──────────────────── Time
    Mục tiêu: Kiểm tra auto-scaling, graceful degradation

SOAK (Tải kéo dài)
VUs │    __________________
    │   /                  \
    └───────────────────────── Time (2–24 giờ)
    Mục tiêu: Memory leak, resource exhaustion, drift

STRESS (Vượt quá ngưỡng)
VUs │                  /
    │                 /
    │                /
    │_______________/
    └──────────────────── Time
    Mục tiêu: Tìm điểm hệ thống bắt đầu fail
```

### 3b. Think Time và Pacing

- **Think time:** Thời gian user "suy nghĩ" giữa các request — simulate realistic behavior
- Realistic think time: 1–5 giây cho web app thông thường
- Formula tính throughput thực tế:
  ```
  Throughput = VUs / (avg_response_time + think_time)
  ```

### 3c. Virtual User Calculation

```
VUs cần thiết = Target RPS × (avg_response_time_giây + think_time_giây)

Ví dụ:
  Target: 500 RPS
  Avg response: 200ms = 0.2s
  Think time: 1s
  VUs = 500 × (0.2 + 1.0) = 600 VUs
```

---

## 4. Performance Testing Tools Comparison

| Tool | Ngôn ngữ script | Protocol | Strengths | Weaknesses | Best for |
|------|----------------|----------|-----------|------------|----------|
| k6 | JavaScript/Go | HTTP, WS, gRPC | Developer-friendly, CI/CD native, cloud support | Không có built-in browser engine | API load testing, CI integration |
| JMeter | XML (GUI) | HTTP, JDBC, LDAP, JMS | Mature, nhiều plugin, GUI | Resource-heavy, verbose, old UX | Enterprise, legacy systems |
| Locust | Python | HTTP, custom | Pythonic, distributed native | Không có native browser | Python shops, custom protocols |
| Artillery | YAML/JS | HTTP, WS, Socket.io | Đơn giản, CI-friendly | Ít feature nâng cao | Quick API tests, microservices |
| Gatling | Scala/DSL | HTTP, WS, JMS | High performance recorder, elegant DSL | Scala learning curve | High-throughput scenarios |

**Khuyến nghị mặc định:** k6 cho API, Playwright + k6 cho browser performance.

---

## 5. Database Performance Checklist

### Slow Query Identification

- [ ] Enable slow query log (threshold: > 100ms)
- [ ] Chạy `EXPLAIN ANALYZE` cho mọi query trong hotpath
- [ ] Kiểm tra query không dùng index (seq scan trên bảng lớn)
- [ ] Phát hiện N+1 query bằng APM hoặc query log

### Connection Pool Sizing Formula

```
Pool size = ((core_count × 2) + effective_spindle_count)

Ví dụ:
  Server 4 cores, SSD (spindle ≈ 1):
  Pool size = (4 × 2) + 1 = 9 connections
  Thực tế thêm 10 connections dự phòng → pool = 10–20
```

### Index Usage Verification

| Kiểm tra | Query PostgreSQL | Dấu hiệu vấn đề |
|----------|-----------------|-----------------|
| Bảng lớn không có index | `EXPLAIN SELECT ...` | "Seq Scan" trên > 10K rows |
| Index không được dùng | `pg_stat_user_indexes` | `idx_scan = 0` sau 1 tuần |
| Bloated index | `pgstatindex()` | `leaf_fragmentation > 30%` |
| Missing index candidate | `pg_stat_user_tables` | `seq_scan >> idx_scan` |

---

## 6. Frontend Performance Checklist

### Bundle Size Budget

| Asset Type | Target | Warning | Block |
|------------|--------|---------|-------|
| Initial JS (critical path) | < 150KB | > 200KB | > 300KB |
| Total JS per route | < 400KB | > 600KB | > 1MB |
| CSS per page | < 50KB | > 100KB | > 150KB |
| Image per page (total) | < 1MB | > 2MB | > 5MB |
| Web font | < 100KB | > 200KB | > 300KB |

### Image Optimization

- [ ] Dùng WebP/AVIF với fallback PNG/JPG (`<picture>` element)
- [ ] Lazy load ảnh below-the-fold (`loading="lazy"` hoặc Intersection Observer)
- [ ] Responsive images với `srcset` và `sizes`
- [ ] Nén lossless cho PNG, lossy quality 80–85% cho JPEG
- [ ] Kích thước ảnh không lớn hơn display size (2x max cho Retina)

### Caching Strategy

| Loại Resource | Cache-Control Header | Ghi chú |
|---------------|---------------------|---------|
| HTML | `no-cache` | Luôn check freshness |
| JS/CSS (hashed filename) | `max-age=31536000, immutable` | 1 năm, hash đảm bảo versioning |
| Images tĩnh | `max-age=604800` | 1 tuần |
| API response (dynamic) | `no-store` hoặc `max-age=60` | Tùy use case |
| Service Worker | Stale-while-revalidate | Offline-first |

---

## 7. Capacity Planning Formula

```
Required capacity = (Peak concurrent users × Avg requests/user/sec × Growth factor) / Server throughput

Ví dụ:
  Peak users:         10,000
  Requests/user/sec:  0.5
  Growth factor:      1.5 (50% growth margin)
  Server throughput:  1,000 RPS/node

  Required nodes = (10,000 × 0.5 × 1.5) / 1,000 = 7.5 → 8 nodes minimum
```

**Growth factor khuyến nghị:**
- Startup / unpredictable traffic: 2.0–3.0
- Established product, seasonal peak: 1.5–2.0
- Stable enterprise: 1.2–1.5

---

## 8. Performance Budget Template per Page Type

| Page Type | LCP | TBT | CLS | JS Bundle | Images |
|-----------|-----|-----|-----|-----------|--------|
| Landing / Marketing | ≤ 2.0s | ≤ 150ms | ≤ 0.05 | ≤ 120KB | ≤ 800KB |
| Dashboard / App | ≤ 2.5s | ≤ 200ms | ≤ 0.1 | ≤ 300KB | ≤ 500KB |
| Product / Detail page | ≤ 2.5s | ≤ 200ms | ≤ 0.1 | ≤ 250KB | ≤ 1.5MB |
| Search Results | ≤ 3.0s | ≤ 300ms | ≤ 0.1 | ≤ 250KB | ≤ 1MB |
| Checkout / Forms | ≤ 2.0s | ≤ 150ms | ≤ 0.05 | ≤ 200KB | ≤ 300KB |
| Admin / Internal tools | ≤ 3.5s | ≤ 400ms | ≤ 0.15 | ≤ 500KB | ≤ 500KB |
