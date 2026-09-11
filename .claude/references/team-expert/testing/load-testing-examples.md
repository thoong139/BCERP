# Testing - Load Testing Examples & Performance Benchmarks

> **Domain**: Testing / Performance Engineering
> **Last Updated**: 2026-03-15

---

## 1. k6 Load Testing Suite

```javascript
// REQ-ID: REQ-XXX — Performance testing suite
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTimeTrend = new Trend('response_time');
const throughputCounter = new Counter('requests_per_second');

export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Warm up
    { duration: '5m', target: 50 },   // Normal load
    { duration: '2m', target: 100 },  // Peak load
    { duration: '5m', target: 100 },  // Sustained peak
    { duration: '2m', target: 200 },  // Stress test
    { duration: '3m', target: 0 },    // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
    'response_time': ['p(95)<200'],
  },
};

export default function () {
  const baseUrl = __ENV.BASE_URL || 'http://localhost:3000';

  const loginResponse = http.post(`${baseUrl}/api/auth/login`, {
    email: 'test@example.com', password: 'password123'
  });

  check(loginResponse, {
    'login successful': (r) => r.status === 200,
    'login response time OK': (r) => r.timings.duration < 200,
  });

  errorRate.add(loginResponse.status !== 200);
  responseTimeTrend.add(loginResponse.timings.duration);
  throughputCounter.add(1);

  if (loginResponse.status === 200) {
    const token = loginResponse.json('token');
    const apiResponse = http.get(`${baseUrl}/api/dashboard`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    check(apiResponse, {
      'dashboard load successful': (r) => r.status === 200,
      'dashboard response time OK': (r) => r.timings.duration < 300,
    });
  }

  sleep(1);
}
```

---

## 2. Load Test Scenarios

| Scenario | Mục đích | Cấu hình |
|----------|---------|----------|
| Baseline | Đo performance bình thường | 10-50 VUs, 10 phút |
| Peak | Kiểm tra tải cao điểm | 2-5x baseline VUs |
| Stress | Tìm breaking point | Tăng dần đến fail |
| Spike | Kiểm tra burst traffic | 0 → max → 0 trong 1 phút |
| Soak/Endurance | Phát hiện memory leaks | Baseline VUs, 2-4 giờ |

---

## 3. Core Web Vitals Optimization Checklist

### LCP (Largest Contentful Paint) — Target: < 2.5s
- [ ] Hero image optimize (WebP/AVIF, responsive sizes)
- [ ] Critical CSS inline, non-critical deferred
- [ ] Server response time (TTFB) < 800ms
- [ ] Preload critical resources
- [ ] CDN configured cho static assets

### FID (First Input Delay) — Target: < 100ms
- [ ] JavaScript bundle size tối ưu (code splitting, tree shaking)
- [ ] Long tasks break up (< 50ms per task)
- [ ] Third-party scripts deferred hoặc lazy loaded
- [ ] Web Workers cho heavy computation

### CLS (Cumulative Layout Shift) — Target: < 0.1
- [ ] Dimensions set cho images và videos
- [ ] Fonts preloaded với font-display: swap
- [ ] Không inject content above existing content
- [ ] Animations dùng transform thay vì layout properties

---

## 4. Performance SLA Defaults

| Metric | Target | Good | Needs Work | Poor |
|--------|--------|------|------------|------|
| Response time (p95) | < 200ms | <200ms | 200-500ms | >500ms |
| Response time (p99) | < 500ms | <500ms | 500ms-1s | >1s |
| Error rate | < 0.1% | <0.1% | 0.1-1% | >1% |
| Throughput | 10x current | ≥10x | 5-10x | <5x |
| LCP | < 2.5s | <2.5s | 2.5-4s | >4s |
| FID | < 100ms | <100ms | 100-300ms | >300ms |
| CLS | < 0.1 | <0.1 | 0.1-0.25 | >0.25 |
| TTFB | < 800ms | <800ms | 800ms-1.8s | >1.8s |

---

## 5. Bottleneck Analysis Categories

| Layer | Kiểm tra | Tools |
|-------|----------|-------|
| Database | Slow queries, missing indexes, connection pool | EXPLAIN ANALYZE, pg_stat |
| Application | CPU hotspots, memory leaks, blocking I/O | Profiler, heap dumps |
| Network | Latency, bandwidth, DNS resolution | curl timing, traceroute |
| CDN | Cache hit ratio, edge locations | CDN analytics |
| Third-party | External API latency, timeout handling | Dependency monitoring |

---

## 6. Capacity Planning Formula

```
Required capacity = (Peak traffic × Growth factor × Safety margin) / Single instance throughput

Ví dụ:
- Peak: 1000 req/s
- Growth 6 tháng: 2x
- Safety margin: 1.5x
- Single instance: 200 req/s
→ Need: (1000 × 2 × 1.5) / 200 = 15 instances
```
