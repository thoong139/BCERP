# API Test Report — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID}
> Backend URL: http://localhost:5048 | Status: {RUNNING / NOT_RUNNING}

## 1. Happy Path Tests

| # | Endpoint | Payload | Expected Status | Actual Status | Response | Pass/Fail |
|---|----------|---------|-----------------|---------------|----------|-----------|
| 1 | POST /api/v1/{route} | {valid data} | 201 | {actual} | `{"success":true,...}` | - |
| 2 | GET /api/v1/{route} | - | 200 | | | - |
| 3 | PUT /api/v1/{route}/{id} | {valid data} | 200 | | | - |
| 4 | DELETE /api/v1/{route}/{id} | - | 200/204 | | | - |

## 2. Validation Error Tests

| # | Endpoint | Invalid Input | Expected Status | Expected Error | Actual | Pass/Fail |
|---|----------|--------------|-----------------|----------------|--------|-----------|
| 1 | POST /api/v1/{route} | Thiếu {required field} | 400 | "{field} bắt buộc" | | - |
| 2 | POST /api/v1/{route} | {field} > max length | 400 | "Tối đa {N} ký tự" | | - |

## 3. Auth Tests

| # | Endpoint | Token | Expected | Actual | Pass/Fail |
|---|----------|-------|----------|--------|-----------|
| 1 | GET /api/v1/{route} | No token | 401 | | - |
| 2 | POST /api/v1/{route} | Wrong permission | 403 | | - |

## 4. Business Rule / Edge Case Tests

| # | Endpoint | Scenario | Expected | Actual | Pass/Fail |
|---|----------|----------|----------|--------|-----------|
| 1 | GET /api/v1/{route}/{invalid-id} | ID không tồn tại | 404 | | - |
| 2 | {endpoint} | {BR violation} | 400 / 409 | | - |

## 5. curl Evidence

```bash
# Test #1 — Happy path Create
curl -s -X POST http://localhost:5048/api/v1/{route} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fieldA":"test","fieldB":1}' | jq .

# Output:
{paste actual output}
```

## 6. Issues Found

| # | Severity | Endpoint | Vấn đề | Action |
|---|----------|----------|--------|--------|
| 1 | HIGH/MED/LOW | | | |

## 7. Summary

- Backend status: {RUNNING} (BẮT BUỘC sau auto-start; NOT_RUNNING → ESCALATE Nhóm 2, KHÔNG fallback code analysis)
- Happy path: {N}/{M} PASS
- Validation: {N}/{M} PASS
- Auth: {N}/{M} PASS
- Overall: ✅ PASS / ⚠️ WARN / ❌ FAIL
