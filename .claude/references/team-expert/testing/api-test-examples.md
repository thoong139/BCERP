# Testing - API Test Examples & OWASP Checklist

> **Domain**: Testing / API Testing
> **Last Updated**: 2026-03-15

---

## 1. Ví dụ Bộ kiểm thử API Toàn diện

```javascript
// REQ-ID: [REQ-ID tương ứng]
import { test, expect } from '@playwright/test';
import { performance } from 'perf_hooks';

describe('Kiểm thử Toàn diện API Người dùng', () => {
  let authToken;
  let baseURL = process.env.API_BASE_URL;

  beforeAll(async () => {
    const response = await fetch(`${baseURL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test@example.com',
        password: 'mat_khau_an_toan'
      })
    });
    const data = await response.json();
    authToken = data.token;
  });

  describe('Kiểm thử Chức năng', () => {
    test('tạo người dùng thành công với dữ liệu hợp lệ', async () => {
      const userData = { name: 'Test User', email: 'new@example.com', role: 'user' };
      const response = await fetch(`${baseURL}/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
        body: JSON.stringify(userData)
      });
      expect(response.status).toBe(201);
      const user = await response.json();
      expect(user.email).toBe(userData.email);
      expect(user.password).toBeUndefined();
    });

    test('xử lý dữ liệu không hợp lệ', async () => {
      const invalidData = { name: '', email: 'invalid', role: 'unknown' };
      const response = await fetch(`${baseURL}/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
        body: JSON.stringify(invalidData)
      });
      expect(response.status).toBe(400);
    });
  });

  describe('Kiểm thử Bảo mật', () => {
    test('từ chối yêu cầu không xác thực', async () => {
      const response = await fetch(`${baseURL}/users`);
      expect(response.status).toBe(401);
    });

    test('ngăn chặn SQL injection', async () => {
      const response = await fetch(`${baseURL}/users?search=${"'; DROP TABLE users; --"}`, {
        headers: { 'Authorization': `Bearer ${authToken}` }
      });
      expect(response.status).not.toBe(500);
    });

    test('áp dụng rate limiting', async () => {
      const requests = Array(100).fill(null).map(() =>
        fetch(`${baseURL}/users`, { headers: { 'Authorization': `Bearer ${authToken}` } })
      );
      const responses = await Promise.all(requests);
      expect(responses.some(r => r.status === 429)).toBe(true);
    });
  });

  describe('Kiểm thử Hiệu năng', () => {
    test('phản hồi trong giới hạn SLA', async () => {
      const start = performance.now();
      const response = await fetch(`${baseURL}/users`, {
        headers: { 'Authorization': `Bearer ${authToken}` }
      });
      expect(response.status).toBe(200);
      expect(performance.now() - start).toBeLessThan(200);
    });
  });
});
```

---

## 2. OWASP API Security Top 10

| # | Lỗ hổng | Kiểm tra | Mức độ |
|---|---------|---------|--------|
| API1 | Broken Object Level Authorization | Truy cập object của user khác bằng ID manipulation | Critical |
| API2 | Broken Authentication | Brute force, token reuse, weak JWT, credential stuffing | Critical |
| API3 | Broken Object Property Level Authorization | Mass assignment, excessive data exposure qua response | High |
| API4 | Unrestricted Resource Consumption | Không có rate limit, pagination abuse, file upload size | High |
| API5 | Broken Function Level Authorization | Truy cập admin endpoints bằng user role, HTTP method tampering | Critical |
| API6 | Unrestricted Access to Sensitive Business Flows | Automated abuse (ticket scalping, coupon stuffing) | Medium |
| API7 | Server Side Request Forgery (SSRF) | URL parameter injection để truy cập internal services | High |
| API8 | Security Misconfiguration | CORS wildcard, verbose errors, unnecessary HTTP methods | Medium |
| API9 | Improper Inventory Management | Shadow APIs, deprecated endpoints vẫn accessible | Medium |
| API10 | Unsafe Consumption of APIs | Third-party API response không validated, SSRF qua redirects | Medium |

---

## 3. HTTP Method Checklist

| Method | Test Cases |
|--------|-----------|
| GET | Happy path, not found (404), unauthorized (401), forbidden (403), pagination, filtering, sorting |
| POST | Valid creation (201), duplicate (409), invalid data (400), unauthorized, missing required fields |
| PUT | Full update, partial update fallback, not found, unauthorized, concurrent update (409) |
| PATCH | Partial update, invalid field, not found, unauthorized |
| DELETE | Success (204), not found (404), unauthorized, cascade effects |

---

## 4. Contract Testing Checklist

| Kiểm tra | Chi tiết |
|----------|---------|
| Schema validation | Response match OpenAPI/JSON Schema spec |
| Required fields | Tất cả required fields có trong response |
| Data types | Fields đúng type (string, number, array) |
| Enum values | Fields chỉ chứa giá trị hợp lệ |
| Backward compatibility | Không breaking changes cho consumers |
| Error format | Error responses tuân theo chuẩn (RFC 7807) |

---

## 5. Performance SLA Targets cho API

| Metric | Target | Đo lường |
|--------|--------|----------|
| Response time (p95) | < 200ms | Tất cả endpoints |
| Response time (p99) | < 500ms | Tất cả endpoints |
| Error rate | < 0.1% | Dưới tải bình thường |
| Throughput | 10x current load | Capacity headroom |
